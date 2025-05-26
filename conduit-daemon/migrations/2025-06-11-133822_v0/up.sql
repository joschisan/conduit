-- Your SQL goes here

CREATE TABLE users (
    username TEXT NOT NULL PRIMARY KEY,
    password_hash TEXT NOT NULL,
    created_at BIGINT NOT NULL
);

CREATE TABLE bolt11_invoice (
    payment_hash TEXT NOT NULL PRIMARY KEY,
    username TEXT NOT NULL,
    amount_msat BIGINT NOT NULL,
    description TEXT NOT NULL,
    invoice TEXT NOT NULL,
    expires_at BIGINT NOT NULL,
    created_at BIGINT NOT NULL
);

CREATE TABLE bolt11_receive (
    payment_hash TEXT NOT NULL PRIMARY KEY,
    username TEXT NOT NULL,
    amount_msat BIGINT NOT NULL,
    description TEXT NOT NULL,
    invoice TEXT NOT NULL,
    created_at BIGINT NOT NULL
);

CREATE TABLE bolt11_send (
    payment_hash TEXT NOT NULL PRIMARY KEY,
    username TEXT NOT NULL,
    amount_msat BIGINT NOT NULL,
    fee_msat BIGINT NOT NULL,
    description TEXT NOT NULL,
    invoice TEXT NOT NULL,
    status TEXT NOT NULL,
    ln_address TEXT,
    created_at BIGINT NOT NULL
);

CREATE INDEX idx_bolt11_invoice_username ON bolt11_invoice(username);
CREATE INDEX idx_bolt11_receive_username ON bolt11_receive(username);
CREATE INDEX idx_bolt11_send_username ON bolt11_send(username);
