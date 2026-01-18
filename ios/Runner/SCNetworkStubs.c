// Stubs for macOS-only SystemConfiguration APIs
// These functions don't exist on iOS but are referenced by netwatch crate
// Providing empty implementations to satisfy the linker

#include <TargetConditionals.h>

#if TARGET_OS_IOS || TARGET_OS_SIMULATOR

#include <CoreFoundation/CoreFoundation.h>

// Stub: Returns NULL (no network interfaces on iOS via this API)
CFArrayRef SCNetworkInterfaceCopyAll(void) {
    return NULL;
}

// Stub: Returns NULL
CFStringRef SCNetworkInterfaceGetBSDName(void *interface) {
    return NULL;
}

// Stub: Returns NULL
CFStringRef SCNetworkInterfaceGetInterfaceType(void *interface) {
    return NULL;
}

// Stub: Returns NULL
CFStringRef SCNetworkInterfaceGetLocalizedDisplayName(void *interface) {
    return NULL;
}

#endif
