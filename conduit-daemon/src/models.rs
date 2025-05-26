use crate::db::unix_time;
use conduit_core::Payment;
use conduit_core::user::InvoiceInfo;
use diesel::prelude::*;

#[derive(Queryable, Selectable, Insertable, Debug, Clone)]
#[diesel(table_name = crate::schema::users)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct User {
    pub username: String,
    pub password_hash: String,
}

#[derive(Queryable, Selectable, Insertable, Debug, Clone)]
#[diesel(table_name = crate::schema::bolt11_invoice)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct Bolt11InvoiceRecord {
    pub payment_hash: String,
    pub username: String,
    pub amount_msat: i64,
    pub description: String,
    pub invoice: String,
    pub created_at: i64,
}

impl Into<InvoiceInfo> for Bolt11InvoiceRecord {
    fn into(self) -> InvoiceInfo {
        InvoiceInfo {
            invoice: self.invoice,
            payment_hash: self.payment_hash,
            amount_msat: self.amount_msat,
            description: self.description,
            created_at: self.created_at,
        }
    }
}

impl Into<Bolt11Receive> for Bolt11InvoiceRecord {
    fn into(self) -> Bolt11Receive {
        Bolt11Receive {
            payment_hash: self.payment_hash,
            username: self.username,
            amount_msat: self.amount_msat,
            description: self.description,
            invoice: self.invoice,
            created_at: unix_time(),
        }
    }
}

#[derive(Queryable, Selectable, Insertable, Debug, Clone)]
#[diesel(table_name = crate::schema::bolt11_receive)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct Bolt11Receive {
    pub payment_hash: String,
    pub username: String,
    pub amount_msat: i64,
    pub description: String,
    pub invoice: String,
    pub created_at: i64,
}

impl Into<Payment> for Bolt11Receive {
    fn into(self) -> Payment {
        Payment {
            id: self.payment_hash,
            payment_type: "receive".to_string(),
            amount_msat: self.amount_msat,
            fee_msat: 0,
            description: self.description,
            bolt11_invoice: self.invoice,
            lightning_address: None,
            status: "successful".to_string(),
            created_at: self.created_at,
        }
    }
}

#[derive(Queryable, Selectable, Insertable, Debug, Clone)]
#[diesel(table_name = crate::schema::bolt11_send)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct Bolt11Send {
    pub payment_hash: String,
    pub username: String,
    pub amount_msat: i64,
    pub fee_msat: i64,
    pub description: String,
    pub invoice: String,
    pub created_at: i64,
    pub status: String,
    pub lightning_address: Option<String>,
}

impl Into<Payment> for Bolt11Send {
    fn into(self) -> Payment {
        Payment {
            id: self.payment_hash,
            payment_type: "send".to_string(),
            amount_msat: self.amount_msat,
            fee_msat: self.fee_msat,
            description: self.description,
            bolt11_invoice: self.invoice,
            lightning_address: self.lightning_address,
            status: self.status,
            created_at: self.created_at,
        }
    }
}
