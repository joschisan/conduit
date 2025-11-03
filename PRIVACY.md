# Privacy Policy

Conduit is a self-hosted Fedimint wallet. We do not collect any data whatsoever. We don't run any servers. We don't have analytics.

## How the app works

All your data stays on your device. Your wallet, your transactions, your settings - everything is stored locally on your phone. The seedphrase to access your funds is generated locally and never leaves the device. We do not have access to your funds nor can we help you with recovery. It is your responsibility to backup your seedphrase.

In order to use Conduit, you have connect to Fedimint Federations and Lightning Gateways that you choose. These are usually run by yourself or friends and family.

## What federations and gateways can see

Fedimint uses a privacy technology called Chaumian ecash. This means:

- **Federations cannot see your balance.** They issue and redeem ecash tokens, but they cannot link them to you or track how much you hold.
- **Federations cannot track your transactions over time.** Each ecash token is unlinkable - they cannot tell if two transactions came from the same person.
- **Lightning gateways see payment requests** when you send or receive over Lightning, but they cannot see your ecash balance or history.

In short: even the infrastructure you connect to cannot build a profile of your activity.

## Network connections

The app connects to:

- Federation servers you choose to join
- Lightning gateways you select for payments
- mempool.space for on-chain deposit monitoring
- Optional price feed for currency conversion

We do not operate any of these services.

## Contact

If you have questions about this policy, open an issue at https://github.com/joschisan/conduit/issues.

---

Last updated: December 2025
