#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "Generating Rust bridge code..."
flutter_rust_bridge_codegen generate

cd "$ROOT/rust"

# Set minimum iOS version to avoid linker warnings
export IPHONEOS_DEPLOYMENT_TARGET=12.0

echo "Building Rust library for iOS (device)..."
cargo rustc --target aarch64-apple-ios --release --crate-type=staticlib

echo "Building Rust library for iOS Simulator (arm64)..."
cargo rustc --target aarch64-apple-ios-sim --release --crate-type=staticlib

echo "Creating XCFramework..."
rm -rf "$ROOT/ios/Frameworks/conduit.xcframework"
mkdir -p "$ROOT/ios/Frameworks"

# Create the XCFramework with both device and simulator
xcodebuild -create-xcframework \
    -library "$ROOT/rust/target/aarch64-apple-ios/release/libconduit.a" \
    -library "$ROOT/rust/target/aarch64-apple-ios-sim/release/libconduit.a" \
    -output "$ROOT/ios/Frameworks/conduit.xcframework"

echo "Build complete! Now open ios/Runner.xcworkspace in Xcode and add the framework."
