use fedimint_core::base32::{FEDIMINT_PREFIX, decode_prefixed, encode_prefixed};
use fedimint_fountain::{FountainDecoder, FountainEncoder};
use fedimint_mint_client::OOBNotes;
use fedimint_mintv2_client::ECash;
use flutter_rust_bridge::frb;

use crate::{EcashToken, ECashWrapper};

#[frb(opaque)]
pub struct ECashEncoder(FountainEncoder);

impl ECashEncoder {
    #[frb(sync)]
    pub fn new(notes: &ECashWrapper) -> Self {
        match &notes.0 {
            EcashToken::V1(oob) => Self(FountainEncoder::new(oob, 512)),
            EcashToken::V2(ecash) => Self(FountainEncoder::new(ecash, 512)),
        }
    }

    #[frb]
    pub fn next_fragment(&mut self) -> String {
        encode_prefixed(FEDIMINT_PREFIX, &self.0.next_fragment())
    }
}

#[frb(opaque)]
pub struct ECashDecoder {
    v1: FountainDecoder<OOBNotes>,
    v2: FountainDecoder<ECash>,
}

impl ECashDecoder {
    #[frb(sync)]
    pub fn new() -> Self {
        Self {
            v1: FountainDecoder::default(),
            v2: FountainDecoder::default(),
        }
    }

    #[frb(sync)]
    pub fn add_fragment(&mut self, fragment: &str) -> Option<ECashWrapper> {
        let fragment_bytes = decode_prefixed(FEDIMINT_PREFIX, fragment).ok()?;

        if let Some(v1) = self.v1.add_fragment(&fragment_bytes) {
            return Some(ECashWrapper(EcashToken::V1(v1)));
        }

        if let Some(v2) = self.v2.add_fragment(&fragment_bytes) {
            return Some(ECashWrapper(EcashToken::V2(v2)));
        }

        None
    }
}
