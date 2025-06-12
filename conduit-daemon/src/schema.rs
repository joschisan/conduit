// @generated automatically by Diesel CLI.

diesel::table! {
    bolt11_invoice (payment_hash) {
        payment_hash -> Text,
        username -> Text,
        amount_msat -> BigInt,
        description -> Text,
        invoice -> Text,
        created_at -> BigInt,
    }
}

diesel::table! {
    bolt11_receive (payment_hash) {
        payment_hash -> Text,
        username -> Text,
        amount_msat -> BigInt,
        description -> Text,
        invoice -> Text,
        created_at -> BigInt,
    }
}

diesel::table! {
    bolt11_send (payment_hash) {
        payment_hash -> Text,
        username -> Text,
        amount_msat -> BigInt,
        fee_msat -> BigInt,
        description -> Text,
        invoice -> Text,
        created_at -> BigInt,
        status -> Text,
        lightning_address -> Nullable<Text>,
    }
}

diesel::table! {
    users (username) {
        username -> Text,
        password_hash -> Text,
    }
}

diesel::allow_tables_to_appear_in_same_query!(bolt11_invoice, bolt11_receive, bolt11_send, users,);
