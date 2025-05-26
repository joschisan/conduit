use conduit_core::Balance;
use conduit_core::Notification;
use conduit_core::Payment;
use conduit_core::user::AppEvent;
use futures::StreamExt;
use tokio::sync::broadcast;
use tokio_stream::wrappers::errors::BroadcastStreamRecvError;
use tokio_stream::{Stream, wrappers::BroadcastStream};

#[derive(Clone)]
pub struct EventBus {
    tx: broadcast::Sender<(String, AppEvent)>,
}

impl EventBus {
    pub fn new(capacity: usize) -> Self {
        Self {
            tx: broadcast::channel(capacity).0,
        }
    }

    pub fn send_balance_event(&self, user_id: String, balance: Balance) {
        self.tx.send((user_id, AppEvent::Balance(balance))).ok();
    }

    pub fn send_payment_event(&self, user_id: String, payment: Payment) {
        self.tx.send((user_id, AppEvent::Payment(payment))).ok();
    }

    #[allow(dead_code)]
    pub fn send_notification_event(&self, user_id: String, message: String) {
        self.tx
            .send((user_id, AppEvent::Notification(Notification { message })))
            .ok();
    }

    pub fn subscribe_to_events(
        &self,
        user_id: String,
    ) -> impl Stream<Item = Result<AppEvent, String>> + Send + 'static {
        BroadcastStream::new(self.tx.subscribe()).filter_map(move |r| filter(user_id.clone(), r))
    }
}

async fn filter<T>(
    user_id: String,
    result: Result<(String, T), BroadcastStreamRecvError>,
) -> Option<Result<T, String>> {
    match result {
        Ok((event_user_id, event)) => {
            if event_user_id == user_id {
                Some(Ok(event))
            } else {
                None
            }
        }
        Err(e) => Some(Err(e.to_string())),
    }
}
