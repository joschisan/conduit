use fedimint_core::encoding::{Decodable, DecodeError, Encodable};
use fedimint_core::module::registry::ModuleDecoderRegistry;
use flutter_rust_bridge::frb;

/// One of a mint's balances. The federation cannot tell accounts apart: all
/// five live inside the mint's one fedimint client, each as its own branch of
/// the module secrets and its own slice of the note and address tables, so
/// they exist only to keep money in separate piles. The set is fixed — there
/// is nothing to create or delete, and removing a mint removes all of them.
///
/// Mirrors fedimint's `Account` variant for variant, so it can cross the
/// bridge as a plain enum. Variant order is load-bearing: the position is the
/// account's index in fedimint's derivation tree and a component of the
/// stored selection, so reordering would silently re-key every wallet.
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

    pub(crate) fn index(self) -> u8 {
        self as u8
    }

    fn from_index(index: u8) -> Option<Account> {
        Account::ALL.get(usize::from(index)).copied()
    }
}

impl From<Account> for fedimint_core::core::Account {
    fn from(account: Account) -> Self {
        match account {
            Account::Primary => Self::Primary,
            Account::Secondary => Self::Secondary,
            Account::Tertiary => Self::Tertiary,
            Account::Quaternary => Self::Quaternary,
            Account::Quinary => Self::Quinary,
        }
    }
}

impl From<fedimint_core::core::Account> for Account {
    fn from(account: fedimint_core::core::Account) -> Self {
        match account {
            fedimint_core::core::Account::Primary => Self::Primary,
            fedimint_core::core::Account::Secondary => Self::Secondary,
            fedimint_core::core::Account::Tertiary => Self::Tertiary,
            fedimint_core::core::Account::Quaternary => Self::Quaternary,
            fedimint_core::core::Account::Quinary => Self::Quinary,
        }
    }
}

/// Keyed by the index itself, one byte, so what the database holds is what
/// fedimint's derivation tree says.
impl Encodable for Account {
    fn consensus_encode<W: std::io::Write>(&self, writer: &mut W) -> Result<(), std::io::Error> {
        self.index().consensus_encode(writer)
    }
}

impl Decodable for Account {
    fn consensus_decode_partial<R: std::io::Read>(
        reader: &mut R,
        modules: &ModuleDecoderRegistry,
    ) -> Result<Self, DecodeError> {
        Account::from_index(u8::consensus_decode_partial(reader, modules)?)
            .ok_or_else(|| DecodeError::from_str("Unknown account"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The stored selection and fedimint's derivation hop are the same byte.
    #[test]
    fn index_matches_fedimint() {
        for account in Account::ALL {
            assert_eq!(
                account.index(),
                fedimint_core::core::Account::from(account).index()
            );
            assert_eq!(
                Account::from(fedimint_core::core::Account::from(account)),
                account
            );
        }
    }
}
