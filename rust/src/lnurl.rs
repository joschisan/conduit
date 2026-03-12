use std::str::FromStr;

use flutter_rust_bridge::frb;
use lightning_invoice::Bolt11Invoice;
use lnurl_pay::{LightningAddress, LnUrl};
use regex::Regex;
use serde::Deserialize;
use url::Url;

use crate::Bolt11InvoiceWrapper;

#[frb]
pub struct LnurlWrapper(pub(crate) String);

impl LnurlWrapper {
    #[frb(sync)]
    pub fn encode(&self) -> String {
        LnUrl::new(&self.0).encode().expect("Failed to encode lnurl")
    }
}

/// Strict URI encode adhering to RFC 3986
fn strict_uri_encode(input: &str) -> String {
    input
        .bytes()
        .map(|byte| match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                (byte as char).to_string()
            }
            _ => format!("%{:02X}", byte),
        })
        .collect()
}

/// Merchant patterns following blink-client approach (MoneyBadger)
const MERCHANT_PATTERNS: &[&str] = &[
    r"(?i)za\.co\.electrum\.picknpay",
    r"(?i)za\.co\.ecentric",
    r"(wigroup\.co|yoyogroup\.co)",
    r"(zapper\.com|\d+\.zap\.pe)",
    r"payat\.io",
    r"paynow\.netcash\.co\.za",
    r"paynow\.sagepay\.co\.za",
    r"^SK-\d{1,}-\d{23}$",
    r"transactionjunction\.co\.za",
    r"^CRSTPC-\d+-\d+-\d+-\d+-\d+$",
    r"scantopay\.io",
    r"snapscan",
    r"^\d{10}$",
    r"^.{2}/.{4}/.{20}$",
];

#[frb(sync)]
pub fn parse_lnurl(request: &str) -> Option<LnurlWrapper> {
    if let Some(stripped) = request.strip_prefix("lnurl:") {
        return parse_lnurl(stripped);
    }

    // Try to parse as URL and extract LNURL from query parameters
    if let Ok(url) = Url::parse(&request.to_lowercase()) {
        for (key, value) in url.query_pairs() {
            if key == "lightning" || key == "lnurl" {
                if let Some(result) = parse_lnurl(&value) {
                    return Some(result);
                }
            }
        }
    }

    if let Ok(lnurl) = LnUrl::from_str(request) {
        return Some(LnurlWrapper(lnurl.endpoint()));
    }

    if let Ok(lightning_address) = LightningAddress::from_str(request) {
        return Some(LnurlWrapper(lightning_address.endpoint()));
    }

    // Check if input matches MoneyBadger merchant pattern
    if MERCHANT_PATTERNS
        .iter()
        .any(|pattern| Regex::new(pattern).unwrap().is_match(request))
    {
        let address = format!("{}@cryptoqr.net", strict_uri_encode(request));

        return LightningAddress::from_str(&address)
            .ok()
            .map(|addr| LnurlWrapper(addr.endpoint()));
    }

    None
}

#[frb]
pub struct LnurlPayInfo {
    pub callback: String,
    pub min_sats: i64,
    pub max_sats: i64,
}

#[derive(Deserialize)]
struct LnUrlPayResponse {
    callback: String,
    #[serde(alias = "minSendable")]
    min_sendable: i64,
    #[serde(alias = "maxSendable")]
    max_sendable: i64,
}

#[derive(Deserialize)]
struct LnUrlPayInvoiceResponse {
    pr: Bolt11Invoice,
}

#[frb]
pub async fn lnurl_fetch_limits(lnurl: &LnurlWrapper) -> Result<LnurlPayInfo, String> {
    let response = reqwest::get(&lnurl.0)
        .await
        .map_err(|_| "Failed to fetch LNURL".to_string())?
        .json::<LnUrlPayResponse>()
        .await
        .map_err(|_| "Failed to parse LNURL response".to_string())?;

    if response.min_sendable > response.max_sendable {
        return Err("Invalid LNURL: min_sendable > max_sendable".to_string());
    }

    Ok(LnurlPayInfo {
        callback: response.callback,
        min_sats: response.min_sendable / 1000,
        max_sats: response.max_sendable / 1000,
    })
}

#[frb]
pub async fn lnurl_resolve(
    pay_info: &LnurlPayInfo,
    amount_sats: i64,
) -> Result<Bolt11InvoiceWrapper, String> {
    if amount_sats < pay_info.min_sats {
        return Err(format!("Minimum amount is {} sats", pay_info.min_sats));
    }

    if amount_sats > pay_info.max_sats {
        return Err(format!("Maximum amount is {} sats", pay_info.max_sats));
    }

    let callback_url = format!("{}?amount={}", pay_info.callback, amount_sats * 1000);

    let response = reqwest::get(callback_url)
        .await
        .map_err(|_| "Failed to fetch LNURL callback".to_string())?
        .json::<LnUrlPayInvoiceResponse>()
        .await
        .map_err(|_| "Failed to parse LNURL callback response".to_string())?;

    if response.pr.amount_milli_satoshis() != Some((amount_sats * 1000) as u64) {
        return Err("Invoice response amount mismatch".to_string());
    }

    Ok(Bolt11InvoiceWrapper(response.pr))
}
