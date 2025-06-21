use anyhow::{Context, Result};
use bitcoin::hashes::Hash;
use bitcoin::hex::DisplayHex;
use conduit_core::admin::UserInfo;
use diesel::prelude::*;
use diesel::r2d2::{ConnectionManager, Pool};
use diesel::sqlite::SqliteConnection;
use diesel_migrations::{EmbeddedMigrations, MigrationHarness, embed_migrations};
use lightning_invoice::Bolt11Invoice;
use rand::Rng;
use std::path::PathBuf;

use crate::models::*;
use crate::schema::*;

pub type DbConnection = Pool<ConnectionManager<SqliteConnection>>;

const MIGRATIONS: EmbeddedMigrations = embed_migrations!("migrations");

fn dummy_hash() -> String {
    rand::thread_rng().r#gen::<[u8; 32]>().as_hex().to_string()
}

fn get_payment_hash_hex(invoice: &Bolt11Invoice) -> String {
    invoice.payment_hash().as_byte_array().as_hex().to_string()
}

pub fn unix_time() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .expect("Time went backwards")
        .as_millis() as i64
}

pub fn setup_database(conduit_data_dir: PathBuf) -> Result<DbConnection> {
    let database_url = format!(
        "sqlite://{}",
        conduit_data_dir.join("conduit_data.sqlite").display()
    );

    let manager = ConnectionManager::<SqliteConnection>::new(&database_url);

    let pool = Pool::builder()
        .max_size(10) // Maximum 10 connections in the pool
        .build(manager)
        .context("Error creating connection pool")?;

    let mut conn = pool
        .get()
        .expect("Failed to get connection from pool for migrations");

    conn.run_pending_migrations(MIGRATIONS)
        .map_err(|e| anyhow::anyhow!("Migration failed: {}", e))?;

    Ok(pool)
}

pub async fn count_users_created(db: &DbConnection, seconds: i64) -> i64 {
    let mut conn = db.get().expect("Failed to get connection from pool");

    tokio::task::spawn_blocking(move || {
        users::table
            .filter(users::created_at.gt(unix_time() - seconds * 1000))
            .count()
            .first::<i64>(&mut *conn)
            .expect("Failed to count users")
    })
    .await
    .expect("Failed to join task")
}

pub async fn register_user(
    db: &DbConnection,
    username: String,
    password_hash: String,
) -> Result<String> {
    let mut conn = db.get().expect("Failed to get connection from pool");

    tokio::task::spawn_blocking(move || {
        let existing = users::table
            .filter(users::username.eq(&username))
            .select(users::username)
            .first::<String>(&mut *conn)
            .optional()?;

        anyhow::ensure!(existing.is_none(), "Username already exists");

        let new_user = User {
            username: username.clone(),
            password_hash,
            created_at: unix_time(),
        };

        diesel::insert_into(users::table)
            .values(&new_user)
            .execute(&mut *conn)?;

        Ok(username)
    })
    .await
    .expect("Failed to join task")
}

pub async fn validate_credentials(
    db: &DbConnection,
    username: String,
    password_hash: String,
) -> Result<()> {
    let mut conn = db.get().expect("Failed to get connection from pool");

    let ph = tokio::task::spawn_blocking(move || {
        users::table
            .filter(users::username.eq(username))
            .select(users::password_hash)
            .first::<String>(&mut *conn)
            .optional()
    })
    .await
    .expect("Failed to join task")
    .expect("Failed to select user")
    .context("User not found")?;

    anyhow::ensure!(ph == password_hash, "Invalid credentials");

    Ok(())
}

pub async fn credit_user(db: &DbConnection, username: String, amount_msat: i64) {
    let mut conn = db.get().expect("Failed to get connection from pool");

    tokio::task::spawn_blocking(move || {
        let new_receive = Bolt11Receive {
            payment_hash: dummy_hash(),
            username,
            amount_msat,
            description: "Admin credit".to_string(),
            invoice: "Admin credit".to_string(),
            created_at: unix_time(),
        };

        diesel::insert_into(bolt11_receive::table)
            .values(&new_receive)
            .execute(&mut *conn)
            .expect("Failed to insert receive payment");
    })
    .await
    .expect("Failed to join task");
}

pub async fn create_bolt11_send_payment(
    db: &DbConnection,
    username: String,
    invoice: Bolt11Invoice,
    amount_msat: i64,
    fee_msat: i64,
    ln_address: Option<String>,
    status: String,
) -> Bolt11Send {
    let mut conn = db.get().expect("Failed to get connection from pool");

    let new_send = Bolt11Send {
        payment_hash: get_payment_hash_hex(&invoice),
        username,
        amount_msat,
        fee_msat,
        description: invoice.description().to_string(),
        invoice: invoice.to_string(),
        created_at: unix_time(),
        status,
        ln_address,
    };

    tokio::task::spawn_blocking(move || {
        diesel::insert_into(bolt11_send::table)
            .values(&new_send)
            .execute(&mut *conn)
            .expect("Failed to insert send payment");

        new_send
    })
    .await
    .expect("Failed to join task")
}

pub async fn update_bolt11_send_payment_status(
    db: &DbConnection,
    payment_hash: [u8; 32],
    status: String,
) -> Bolt11Send {
    let mut conn = db.get().expect("Failed to get connection from pool");

    tokio::task::spawn_blocking(move || {
        diesel::update(bolt11_send::table.find(&payment_hash.as_hex().to_string()))
            .set(bolt11_send::status.eq(&status))
            .execute(&mut *conn)
            .expect("Failed to update payment status");

        bolt11_send::table
            .filter(bolt11_send::payment_hash.eq(payment_hash.as_hex().to_string()))
            .first::<Bolt11Send>(&mut *conn)
            .expect("Failed to fetch updated payment")
    })
    .await
    .expect("Failed to join task")
}

pub async fn create_bolt11_invoice(
    db: &DbConnection,
    username: String,
    invoice: Bolt11Invoice,
    amount_msat: i64,
    description: String,
    expiry_secs: u32,
) {
    let mut conn = db.get().expect("Failed to get connection from pool");

    let new_invoice = Bolt11InvoiceRecord {
        payment_hash: get_payment_hash_hex(&invoice),
        username,
        amount_msat,
        description,
        invoice: invoice.to_string(),
        expires_at: unix_time() + expiry_secs as i64 * 1000,
        created_at: unix_time(),
    };

    tokio::task::spawn_blocking(move || {
        diesel::insert_into(bolt11_invoice::table)
            .values(&new_invoice)
            .execute(&mut *conn)
            .expect("Failed to create invoice");
    })
    .await
    .expect("Failed to join task");
}

pub async fn count_pending_invoices(db: &DbConnection, username: String) -> i64 {
    let mut conn = db.get().expect("Failed to get connection from pool");

    tokio::task::spawn_blocking(move || {
        bolt11_invoice::table
            .filter(bolt11_invoice::username.eq(username))
            .filter(bolt11_invoice::expires_at.gt(unix_time()))
            .left_join(
                bolt11_receive::table
                    .on(bolt11_invoice::payment_hash.eq(bolt11_receive::payment_hash)),
            )
            .filter(bolt11_receive::payment_hash.is_null())
            .count()
            .first::<i64>(&mut *conn)
            .expect("Failed to count pending invoices")
    })
    .await
    .expect("Failed to join task")
}

pub async fn get_bolt11_invoice(
    db: &DbConnection,
    payment_hash: [u8; 32],
) -> Option<Bolt11InvoiceRecord> {
    let mut conn = db.get().expect("Failed to get connection from pool");

    tokio::task::spawn_blocking(move || {
        bolt11_invoice::table
            .filter(bolt11_invoice::payment_hash.eq(payment_hash.as_hex().to_string()))
            .first::<Bolt11InvoiceRecord>(&mut *conn)
            .optional()
            .expect("Failed to query invoice")
    })
    .await
    .expect("Failed to join task")
}

pub async fn create_bolt11_receive_payment(db: &DbConnection, record: Bolt11Receive) {
    let mut conn = db.get().expect("Failed to get connection from pool");

    tokio::task::spawn_blocking(move || {
        diesel::replace_into(bolt11_receive::table)
            .values(&record)
            .execute(&mut *conn)
            .expect("Failed to create receive payment");
    })
    .await
    .expect("Failed to join task");
}

pub async fn get_user_by_username(db: &DbConnection, username: String) -> Option<User> {
    let mut conn = db.get().expect("Failed to get connection from pool");

    tokio::task::spawn_blocking(move || {
        users::table
            .filter(users::username.eq(username))
            .first::<User>(&mut *conn)
            .optional()
            .expect("Failed to query user by username")
    })
    .await
    .expect("Failed to join task")
}

pub async fn get_user_balance(db: &DbConnection, username: String) -> conduit_core::Balance {
    let mut conn = db.get().expect("Failed to get connection from pool");

    tokio::task::spawn_blocking(move || {
        let receive_sum: i64 = bolt11_receive::table
            .filter(bolt11_receive::username.eq(username.clone()))
            .select(bolt11_receive::amount_msat)
            .load::<i64>(&mut *conn)
            .unwrap_or_default()
            .into_iter()
            .sum();

        let send_sum: i64 = bolt11_send::table
            .filter(bolt11_send::username.eq(username))
            .filter(bolt11_send::status.eq("successful"))
            .select((bolt11_send::amount_msat, bolt11_send::fee_msat))
            .load::<(i64, i64)>(&mut *conn)
            .unwrap_or_default()
            .into_iter()
            .map(|(amount, fee)| amount + fee)
            .sum();

        let balance_msat = receive_sum
            .checked_sub(send_sum)
            .expect("Balance underflow");

        conduit_core::Balance {
            msat: balance_msat.max(0) as u64,
        }
    })
    .await
    .expect("Failed to join task")
}

pub async fn get_user_payments(db: &DbConnection, username: String) -> Vec<conduit_core::Payment> {
    let mut conn = db.get().expect("Failed to get connection from pool");

    tokio::task::spawn_blocking(move || {
        // Load full Bolt11Receive records and convert using Into<Payment>
        let receive_payments: Vec<conduit_core::Payment> = bolt11_receive::table
            .filter(bolt11_receive::username.eq(username.clone()))
            .load::<Bolt11Receive>(&mut *conn)
            .unwrap_or_default()
            .into_iter()
            .map(|record| record.into())
            .collect();

        // Load full Bolt11Send records and convert using Into<Payment>
        let send_payments: Vec<conduit_core::Payment> = bolt11_send::table
            .filter(bolt11_send::username.eq(username))
            .load::<Bolt11Send>(&mut *conn)
            .unwrap_or_default()
            .into_iter()
            .map(|record| record.into())
            .collect();

        let mut all_payments = [receive_payments, send_payments].concat();

        all_payments.sort_by_key(|payment| payment.created_at);

        all_payments
    })
    .await
    .expect("Failed to join task")
}

pub async fn list_users(db: &DbConnection) -> Vec<UserInfo> {
    let mut conn = db.get().expect("Failed to get connection from pool");

    let user_records = tokio::task::spawn_blocking(move || {
        users::table
            .load::<User>(&mut *conn)
            .expect("Failed to load users")
    })
    .await
    .expect("Failed to join task");

    let mut user_infos = Vec::new();

    for user_record in user_records {
        user_infos.push(UserInfo {
            username: user_record.username.clone(),
            balance: get_user_balance(db, user_record.username).await,
            created_at: user_record.created_at,
        });
    }

    user_infos
}

pub async fn count_pending_bolt11_sends(db: &DbConnection, username: String) -> i64 {
    let mut conn = db.get().expect("Failed to get connection from pool");

    tokio::task::spawn_blocking(move || {
        bolt11_send::table
            .filter(bolt11_send::username.eq(username))
            .filter(bolt11_send::status.eq("pending"))
            .count()
            .first::<i64>(&mut *conn)
            .expect("Failed to count pending invoices")
    })
    .await
    .expect("Failed to join task")
}
