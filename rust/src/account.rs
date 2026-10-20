use fedimint_client::RootSecret;
use fedimint_core::config::FederationId;
use fedimint_core::encoding::{Decodable, DecodeError, Encodable};
use fedimint_core::module::registry::ModuleDecoderRegistry;
use fedimint_derive_secret::{ChildId, DerivableSecret};
use flutter_rust_bridge::frb;

/// One of a mint's balances. The federation cannot tell accounts apart: each
/// is its own fedimint client, keyed by its own branch of the seed, so they
/// exist only to keep money in separate piles. The set is fixed — there is
/// nothing to create or delete, and removing a mint removes all of them.
///
/// Variant order is load-bearing: the position is the wallet number in the
/// derivation path and a component of every account-scoped key, so reordering
/// would silently re-key every wallet.
#[frb]
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Account {
    Primary,
    Secondary,
    Tertiary,
    Quaternary,
    Quinary,
}

impl Account {
    pub(crate) const ALL: [Account; 5] = [
        Account::Primary,
        Account::Secondary,
        Account::Tertiary,
        Account::Quaternary,
        Account::Quinary,
    ];

    pub(crate) fn wallet_number(self) -> u8 {
        self as u8
    }

    fn from_wallet_number(number: u8) -> Option<Account> {
        Account::ALL.get(usize::from(number)).copied()
    }

    /// The account's client secret: fedimint's default per-federation path,
    /// `root/0/<federation-id>/<wallet-number>/0`, with the wallet number set
    /// to the account. Primary is wallet number zero, which is exactly what
    /// `RootSecret::StandardDoubleDerive` derives, so wallets from before
    /// accounts open as Primary unchanged.
    pub(crate) fn root_secret(
        self,
        root: &DerivableSecret,
        federation_id: FederationId,
    ) -> RootSecret {
        RootSecret::Custom(
            root.child_key(ChildId(0))
                .federation_key(&federation_id)
                .child_key(ChildId(self.wallet_number().into()))
                .child_key(ChildId(0)),
        )
    }
}

/// Keyed by the wallet number itself, one byte, so what the database holds is
/// what the derivation path says.
impl Encodable for Account {
    fn consensus_encode<W: std::io::Write>(&self, writer: &mut W) -> Result<(), std::io::Error> {
        self.wallet_number().consensus_encode(writer)
    }
}

impl Decodable for Account {
    fn consensus_decode_partial<R: std::io::Read>(
        reader: &mut R,
        modules: &ModuleDecoderRegistry,
    ) -> Result<Self, DecodeError> {
        Account::from_wallet_number(u8::consensus_decode_partial(reader, modules)?)
            .ok_or_else(|| DecodeError::from_str("Unknown account"))
    }
}

#[cfg(test)]
mod tests {
    use fedimint_client_module::secret::get_default_client_secret;
    use fedimint_core::BitcoinHash;

    use super::*;

    fn inner(secret: RootSecret) -> [u8; 32] {
        match secret {
            RootSecret::Custom(secret) => secret.to_random_bytes(),
            RootSecret::StandardDoubleDerive(_) => unreachable!(),
        }
    }

    #[test]
    fn primary_is_the_default_client_secret() {
        let root = DerivableSecret::new_root(b"root", b"salt");
        let federation_id = FederationId(BitcoinHash::hash(b"federation"));

        let default = get_default_client_secret(&root, &federation_id).to_random_bytes::<32>();

        assert_eq!(
            inner(Account::Primary.root_secret(&root, federation_id)),
            default
        );

        for account in &Account::ALL[1..] {
            assert_ne!(inner(account.root_secret(&root, federation_id)), default);
        }
    }
}
