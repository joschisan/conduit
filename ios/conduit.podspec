Pod::Spec.new do |s|
  s.name             = 'conduit'
  s.version          = '0.1.0'
  s.summary          = 'Rust library for Conduit'
  s.homepage         = 'https://github.com/joschisan/conduit'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Author' => 'author@example.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '13.0'

  s.vendored_frameworks = 'Frameworks/conduit.xcframework'
  s.static_framework = true

  # Stubs for macOS-only SystemConfiguration APIs (not available on iOS)
  s.source_files = 'SCNetworkStubs.c'

  # Link required system libraries
  s.libraries = 'c++'
  s.frameworks = 'Security', 'SystemConfiguration'

  # Force linker to keep all symbols from the static library (needed for FFI)
  # Also disable dead stripping for these symbols since they're called via FFI
  # Use conditional paths for device vs simulator builds
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS[sdk=iphoneos*]' => '-force_load "${PODS_ROOT}/../Frameworks/conduit.xcframework/ios-arm64/libconduit.a"',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '-force_load "${PODS_ROOT}/../Frameworks/conduit.xcframework/ios-arm64-simulator/libconduit.a"',
    'DEAD_CODE_STRIPPING' => 'NO'
  }
end
