# Conduit

A self-hosted custodial Lightning wallet daemon with integrated LDK node. Designed as a Lightning backend for the [Conduit Flutter app](https://github.com/joschisan/conduit-app), providing Lightning payments and Lightning Address support for your users.

## Features

- **Single Binary**: Easy to deploy with Docker - no complex setup required
- **Lightning Addresses**: Users get `username@yourdomain.com` Lightning addresses
- **Multi-user**: Custodial wallet supporting multiple users with JWT authentication
- **LDK Integration**: Built-in Lightning Development Kit node
- **REST API**: Complete API for account management, payments, and node administration
- **CLI Tools**: Comprehensive command-line interface for all operations

⚠️ **Beta Status**: Not recommended for use with significant amounts

## Deploy with Docker

Download our reference docker-compose.yml with

```bash
curl -O https://raw.githubusercontent.com/joschisan/conduit/main/docker-compose.yml
```

and substitute you api secrets and domain or public ip. 

Testing does not require to setup TLS and users can simply connect via raw ip. However, most lightning wallets in production will refuse to send to your users lightning address until you do configure TLS.

## Daemon Configuration

### Required Environment Variables

| Env | Description |
|-----|-------------|
| `ADMIN_AUTH` | Bearer token for admin API access, used to authenticate administrative operations |
| `JWT_SECRET` | Secret key for signing and verifying user JWT tokens |
| `CONDUIT_DATA_DIR` | Directory path for storing user account data in a SQLite database |
| `LDK_DATA_DIR` | Directory path for storing LDK node data in a SQLite database |
| `BITCOIN_NETWORK` | Bitcoin network to operate on, determines address formats and chain validation rules |
| `PUBLIC_BASE_URL` | Base public URL for the daemon, used to generate LNURL callback URLs |
| `BITCOIN_RPC_URL` | Bitcoin Core RPC URL for chain data access |
| `ESPLORA_RPC_URL` | Esplora API URL for chain data access |

*Note: Either `BITCOIN_RPC_URL` or `ESPLORA_RPC_URL` must be provided, but not both.*

### Optional Environment Variables

| Env | Default | Description |
|-----|---------|-------------|
| `FEE_PPM` | 10000 | Fee rate in parts per million (PPM) applied to outgoing Lightning payments |
| `BASE_FEE_MSAT` | 50000 | Fixed base fee in millisatoshis added to all outgoing Lightning payments |
| `INVOICE_EXPIRY_SECS` | 3600 | Expiration time in seconds for all generated Lightning invoices |
| `API_BIND` | 0.0.0.0:8080 | Network address and port for the HTTP API server to bind to |
| `LDK_BIND` | 0.0.0.0:9735 | Network address and port for the Lightning node to listen for peer connections |
| `MIN_AMOUNT_SAT` | 1 | Minimum amount in satoshis enforced across all incoming and outgoing payments |
| `MAX_AMOUNT_SAT` | 100000 | Maximum amount in satoshis enforced across all incoming and outgoing payments |
| `MAX_PENDING_PAYMENTS_PER_USER` | 10 | Maximum number of pending invoices and outgoing payments each user can have simultaneously |
| `MAX_DAILY_NEW_USERS` | 20 | Maximum number of new user registrations allowed per 24-hour period |

## Install Conduit CLI

The Conduit CLI allows you to manage your conduit dameon. You can install the cli with:

```bash
cargo install --git https://github.com/joschisan/conduit conduit-cli
```

## CLI Commands

Get your node ID (share this with LSPs for inbound channels):

```bash
conduit-cli --api-url <URL> --auth <TOKEN> \
  ldk \
  node-id
```

Inspect your balances:

```bash
conduit-cli --api-url <URL> --auth <TOKEN> \
  ldk \
  balances
```

Generate receiving address:

```bash
conduit-cli --api-url <URL> --auth <TOKEN> \
  ldk \
  onchain \
  receive
```

Send on-chain payment:

```bash
conduit-cli --api-url <URL> --auth <TOKEN> \
  ldk \
  onchain \
  send --address bc1q... --amount-sats 100000 --fee-rate 10
```

Open channel to peer:

```bash
conduit-cli --api-url <URL> --auth <TOKEN> \
  ldk \
  channel \
  open --node-id 03abc... --address 127.0.0.1:9735 --channel-amount-sats 1000000
```

Close a channel:

```bash
conduit-cli --api-url <URL> --auth <TOKEN> \
  ldk \
  channel \
  close --channel-id <CHANNEL_ID>
```

List channels:

```bash
conduit-cli --api-url <URL> --auth <TOKEN> \
  ldk \
  channel \
  list
```

Connect to peer:

```bash
conduit-cli --api-url <URL> --auth <TOKEN> \
  ldk \
  peer \
  connect --node-id 03abc... --address 127.0.0.1:9735
```

Disconnect from peer:

```bash
conduit-cli --api-url <URL> --auth <TOKEN> \
  ldk \
  peer \
  disconnect --node-id <NODE_ID>
```

List connected peers:

```bash
conduit-cli --api-url <URL> --auth <TOKEN> \
  ldk \
  peer \
  list
```

