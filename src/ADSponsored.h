#pragma once
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Large sponsored-content payload is implemented in ADSponsored.m as a C-linkage
// Objective-C function so the Logos-generated Objective-C++ caller resolves the
// same unmangled symbol on arm64/arm64e.
NSString *ADKillerSponsoredJS7384(void);

#ifdef __cplusplus
}
#endif
