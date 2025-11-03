# Conduit

A minimal Fedimint wallet built with Flutter and Rust.

## Features

- Lightning payments
- eCash transactions
- Multi-federation support
- Biometric authentication
- Seed phrase backup & recovery

## Setup

### Prerequisites

1. **Install Flutter**
   ```bash
   # Follow: https://docs.flutter.dev/get-started/install
   ```

2. **Install Rust**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   rustup target add aarch64-linux-android
   ```

3. **Install Android Studio**
   - Download from: https://developer.android.com/studio
   - Install Android SDK and NDK via SDK Manager
   - Set `ANDROID_SDK_ROOT` (usually auto-detected at `~/Library/Android/sdk`)

4. **Install cargo-ndk**
   ```bash
   cargo install cargo-ndk
   ```

5. **Install flutter_rust_bridge_codegen**
   ```bash
   cargo install flutter_rust_bridge_codegen
   ```

### Building

1. **Build Rust library for Android**
   ```bash
   ./build-arm-android.sh
   ```

2. **Run the app**
   ```bash
   flutter run
   ```

### Development

- Edit Dart code in `lib/`
- Edit Rust code in `rust/src/`
- After Rust changes, run `./build-arm-android.sh` to rebuild
- Use `flutter run` for hot reload during Dart development