use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

use serde::Deserialize;
use tokio::sync::Mutex;

#[derive(Deserialize)]
struct FediPriceResponse {
    prices: BTreeMap<String, ExchangeRate>,
}

#[derive(Deserialize)]
struct ExchangeRate {
    rate: f64,
}

/// Cached exchange rate: BTC price in user's currency (e.g., 94000.0 for $94k)
pub(crate) type ExchangeRateCache = Arc<Mutex<Option<(f64, Instant)>>>;

pub(crate) async fn fetch_exchange_rate(
    cache: ExchangeRateCache,
    currency_code: String,
) -> Result<f64, String> {
    let mut guard = cache.lock().await;

    if let Some((rate, timestamp)) = guard.as_ref() {
        if timestamp.elapsed() < Duration::from_secs(600) {
            return Ok(*rate);
        }
    }

    let response = reqwest::get("https://price-feed.dev.fedibtc.com/latest")
        .await
        .map_err(|_| "Failed to fetch exchange rates".to_string())?
        .json::<FediPriceResponse>()
        .await
        .map_err(|_| "Failed to parse exchange rates".to_string())?;

    let btc_to_usd = response
        .prices
        .get("BTC/USD")
        .ok_or("BTC/USD rate not found")?
        .rate;

    let btc_to_currency = if currency_code == "USD" {
        btc_to_usd
    } else {
        let currency_to_usd = response
            .prices
            .get(&format!("{currency_code}/USD"))
            .ok_or("Currency not supported")?
            .rate;
        btc_to_usd / currency_to_usd
    };

    *guard = Some((btc_to_currency, Instant::now()));

    Ok(btc_to_currency)
}
