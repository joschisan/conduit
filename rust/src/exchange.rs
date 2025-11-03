use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

use serde::Deserialize;
use tokio::sync::Mutex;

#[derive(Deserialize, Clone)]
pub(crate) struct FediPriceResponse {
    pub(crate) prices: BTreeMap<String, ExchangeRate>,
}

#[derive(Deserialize, Clone)]
pub(crate) struct ExchangeRate {
    pub(crate) rate: f64,
}

pub(crate) type ExchangeRateCache = Arc<Mutex<Option<(FediPriceResponse, Instant)>>>;

pub(crate) async fn fetch_exchange_rate(
    cache: ExchangeRateCache,
) -> Result<FediPriceResponse, String> {
    let mut guard = cache.lock().await;

    #[allow(clippy::collapsible_if)]
    if let Some((value, timestamp)) = guard.as_ref() {
        if timestamp.elapsed() < Duration::from_secs(600) {
            return Ok(value.clone());
        }
    }

    let value = reqwest::get("https://price-feed.dev.fedibtc.com/latest")
        .await
        .map_err(|_| "Failed to fetch exchange rates".to_string())?
        .json::<FediPriceResponse>()
        .await
        .map_err(|_| "Failed to parse exchange rates".to_string())?;

    *guard = Some((value.clone(), Instant::now()));

    Ok(value)
}
