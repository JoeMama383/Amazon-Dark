/*
 * AmazonDark v7.0.14 — static v185-style theme / persistent OLED floors
 *
 * Retained from v6.0.185:
 *   - Settings bundle/preferences and preference domain
 *   - Force 120 Hz preference path
 *   - Dopamine per-app JIT request path
 *   - Tame Light Backgrounds preference (rewritten as a small generic media owner)
 *   - SpringBoard launch cover / transition / custom artwork (AmazonDarkSB)
 *   - Sileo/package metadata and artwork
 *
 * Removed:
 *   - Dark Reader and its runtime bundle
 *   - Amazon native-dark weblab forcing
 *   - nav/search/symbol/border/card/Person/PDP/Home special-case theming
 *   - broad contrast scanners, repair queues and document-wide theme MutationObservers
 *
 * The core visual owner is an OLED-black FLOOR. Later v7.x releases add only
 * narrowly scoped renderer-specific owners where device probes establish exact targets.
 */

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>
#import <dlfcn.h>
#import <sys/types.h>
#import <unistd.h>
#import <stdint.h>
#import <errno.h>
#import <string.h>
#import <float.h>
#import <signal.h>

#define AD_VERSION "v7.121-search-ui"
#define AD_PREF_DOMAIN "com.colindavidr.amazondark"

extern char *__progname;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wobjc-method-access"

@interface AXUSplashScreenViewController : UIViewController @end
@interface TezBaseSplashScreenViewController : UIViewController @end
@interface WKScrollView : UIScrollView @end
@interface WKContentView : UIView @end
@interface RCTRootView : UIView @end
@interface RCTRootContentView : UIView @end
@interface RCTScrollView : UIScrollView @end
@interface RCTParagraphComponentView : UIView @end
@interface RCTTextView : UIView @end
@interface _UIBarBackground : UIView @end
@interface CXIStoreModesBottomNavToolbar : UIView @end
@interface CXIStoreModesTabBarView : UIView @end
@interface ANPRetailTabBar : UIView @end
@interface ANXTabBarView : UIView @end
@interface ANXTopNavBackgroundView : UIView @end
@interface SBMultilineSearchView : UIView @end
@interface A9VSScanItSearchWidget : UIView @end
@interface UIInputSetContainerView : UIView @end
@interface UIInputSetHostView : UIView @end
@interface _UIRemoteKeyboardPlaceholderView : UIView @end

/* v7.121: Search keyboard is remotely rendered. Keep ownership on the local
 * input host only; no keyboard-process injection or hierarchy scanner. */
typedef struct {
    float m11,m12,m13,m14,m15;
    float m21,m22,m23,m24,m25;
    float m31,m32,m33,m34,m35;
    float m41,m42,m43,m44,m45;
} ADCAColorMatrix7121;
@interface NSValue (AmazonDarkCAColorMatrix7121)
+ (NSValue *)valueWithCAColorMatrix:(ADCAColorMatrix7121)matrix;
@end

// -----------------------------------------------------------------------------
// Preferences — same public keys/domain as v6.0.185.
// -----------------------------------------------------------------------------
typedef struct {
    BOOL enabled;
    BOOL whiteTame;
    BOOL force120Hz;
    BOOL enableJIT;
    BOOL privacyMode;
    long whiteTameStrength;
} ADPrefs;

static ADPrefs gP;

static long ADPrefLong(NSDictionary *d, NSString *k, long def){
    id v=d[k]; return (v && [v respondsToSelector:@selector(longValue)]) ? [v longValue] : def;
}
static BOOL ADPrefBool(NSDictionary *d, NSString *k, BOOL def){
    id v=d[k]; return (v && [v respondsToSelector:@selector(boolValue)]) ? [v boolValue] : def;
}

static void ADLoadPrefs(void){
    gP.enabled=YES;
    gP.whiteTame=NO;
    gP.force120Hz=NO;
    gP.enableJIT=NO;
    gP.privacyMode=NO;
    gP.whiteTameStrength=45;
    @try {
        NSUserDefaults *u=[[NSUserDefaults alloc] initWithSuiteName:@(AD_PREF_DOMAIN)];
        NSDictionary *d=[u dictionaryRepresentation] ?: @{};
        NSMutableArray *paths=[NSMutableArray arrayWithObjects:
            [NSString stringWithFormat:@"/var/jb/var/mobile/Library/Preferences/%s.plist",AD_PREF_DOMAIN],
            [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%s.plist",AD_PREF_DOMAIN],nil];
        @try {
            Dl_info pi;
            if(dladdr((const void *)&ADLoadPrefs,&pi) && pi.dli_fname){
                NSString *img=[NSString stringWithUTF8String:pi.dli_fname];
                NSRange jb=[img rangeOfString:@"/jb/"];
                if(jb.location!=NSNotFound){
                    NSString *root=[img substringToIndex:jb.location+jb.length-1];
                    [paths addObject:[NSString stringWithFormat:@"%@/var/mobile/Library/Preferences/%s.plist",root,AD_PREF_DOMAIN]];
                }
            }
        } @catch(...) {}
        for(NSString *pp in paths){
            NSDictionary *f=[NSDictionary dictionaryWithContentsOfFile:pp];
            if(f.count){ NSMutableDictionary *m=[d mutableCopy]; [m addEntriesFromDictionary:f]; d=m; }
        }
        gP.enabled=ADPrefBool(d,@"enabled",gP.enabled);
        gP.whiteTame=ADPrefBool(d,@"whiteTame",gP.whiteTame);
        gP.force120Hz=ADPrefBool(d,@"force120Hz",gP.force120Hz);
        gP.enableJIT=ADPrefBool(d,@"enableJIT",gP.enableJIT);
        gP.privacyMode=ADPrefBool(d,@"privacyMode",gP.privacyMode);
        gP.whiteTameStrength=ADPrefLong(d,@"whiteTameStrength",gP.whiteTameStrength);
    } @catch(...) {}
}

static inline UIColor *ADOLED(void){ return [UIColor blackColor]; }

// -----------------------------------------------------------------------------
// v7.117 experimental Privacy Mode.
// Conservative telemetry sink: exact analytics / diagnostics / ad-measurement
// destinations are answered locally with HTTP 204 while shopping, media, ad
// creative, account, cart, search and configuration traffic is left untouched.
// No request bodies, headers, typed text, clipboard contents or coordinates are
// recorded. Counters exist only so the manual SIGUSR2 probe can verify coverage.
// -----------------------------------------------------------------------------
static NSObject *gADPrivacyLock7117=nil;
static NSMutableDictionary<NSString *,NSNumber *> *gADPrivacyNativeRequested7117=nil;
static NSMutableDictionary<NSString *,NSNumber *> *gADPrivacyNativeBlocked7117=nil;
static NSUInteger gADPrivacyNativeRequestedTotal7117=0;
static NSUInteger gADPrivacyNativeBlockedTotal7117=0;
static NSUInteger gADPrivacyRun7117=0;
static BOOL gADPrivacyProtocolRegistered7117=NO;
static NSUInteger gADPrivacyConfigInsertions7118=0;
static NSUInteger gADPrivacyLateProtocolRewrites7118=0;
static NSUInteger gADPrivacySessionCtorChecks7118=0;

static void ADPrivacyInit7117(void){
    static dispatch_once_t once; dispatch_once(&once,^{
        gADPrivacyLock7117=[NSObject new];
        gADPrivacyNativeRequested7117=[NSMutableDictionary dictionary];
        gADPrivacyNativeBlocked7117=[NSMutableDictionary dictionary];
    });
}
static NSString *ADPrivacyCategoryForHost7117(NSString *host){
    NSString *h=host.lowercaseString?:@"";
    if([h isEqualToString:@"unagi.amazon.com"]||[h isEqualToString:@"unagi-na.amazon.com"])return @"unagi";
    if([h isEqualToString:@"fls-na.amazon.com"])return @"fls";
    if([h isEqualToString:@"api.mshop.bdtelemetry.amazon"])return @"bdtelemetry";
    if([h isEqualToString:@"session.mshopbugsnag.irm.amazon.dev"]||[h isEqualToString:@"trace.mshopbugsnag.irm.amazon.dev"])return @"bugsnag";
    if([h isEqualToString:@"vfw.amazon-adsystem.com"])return @"ad-viewability";
    if([h hasSuffix:@".service.minerva.devices.a2z.com"])return @"minerva";
    if([h hasPrefix:@"api.stores."]&&[h hasSuffix:@".prod.paets.advertising.amazon.dev"])return @"ad-event";
    if([h hasPrefix:@"aes."]&&[h hasSuffix:@".amazon-adsystem.com"])return @"ad-instrumentation";
    return nil;
}
static NSString *ADPrivacyCategoryForURL7117(NSURL *url){ return url?ADPrivacyCategoryForHost7117(url.host):nil; }
static BOOL ADPrivacyShouldBlockURL7117(NSURL *url){ return gP.enabled&&gP.privacyMode&&ADPrivacyCategoryForURL7117(url).length; }
static NSString *ADPrivacyCounterKey7117(NSURL *url){
    NSString *cat=ADPrivacyCategoryForURL7117(url)?:@"unknown",*host=url.host.lowercaseString?:@"(no-host)";
    return [NSString stringWithFormat:@"%@|%@",cat,host];
}
static void ADPrivacyCount7117(NSMutableDictionary<NSString *,NSNumber *> *dict,NSURL *url,BOOL blocked){
    if(!url)return; ADPrivacyInit7117(); NSString *key=ADPrivacyCounterKey7117(url);
    @synchronized(gADPrivacyLock7117){
        dict[key]=@([dict[key] unsignedIntegerValue]+1);
        if(blocked)gADPrivacyNativeBlockedTotal7117++; else gADPrivacyNativeRequestedTotal7117++;
    }
}

@interface ADPrivacyURLProtocol7117 : NSURLProtocol @end
@implementation ADPrivacyURLProtocol7117
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return ADPrivacyShouldBlockURL7117(request.URL);
}
+ (BOOL)canInitWithTask:(NSURLSessionTask *)task {
    NSURLRequest *request=task.currentRequest?:task.originalRequest;
    return ADPrivacyShouldBlockURL7117(request.URL);
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b { return [super requestIsCacheEquivalent:a toRequest:b]; }
- (void)startLoading {
    NSURL *url=self.request.URL; ADPrivacyCount7117(gADPrivacyNativeBlocked7117,url,YES);
    @try {
        NSHTTPURLResponse *r=[[NSHTTPURLResponse alloc] initWithURL:url statusCode:204 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Cache-Control":@"no-store",@"X-AmazonDark-Privacy":@"1",@"Content-Length":@"0"}];
        [self.client URLProtocol:self didReceiveResponse:r cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocolDidFinishLoading:self];
    } @catch(...) {
        NSError *e=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
        [self.client URLProtocol:self didFailWithError:e];
    }
}
- (void)stopLoading {}
@end

static void ADRegisterPrivacyProtocol7117(void){
    if(gADPrivacyProtocolRegistered7117||!gP.enabled||!gP.privacyMode)return;
    @try { gADPrivacyProtocolRegistered7117=[NSURLProtocol registerClass:[ADPrivacyURLProtocol7117 class]]; } @catch(...) { gADPrivacyProtocolRegistered7117=NO; }
}

static void ADPrivacyInstallProtocolOnConfig7117(NSURLSessionConfiguration *cfg){
    if(!cfg||!gP.enabled||!gP.privacyMode)return;
    @try {
        NSMutableArray *a=[cfg.protocolClasses mutableCopy]?:[NSMutableArray array];
        if(![a containsObject:[ADPrivacyURLProtocol7117 class]]){
            [a insertObject:[ADPrivacyURLProtocol7117 class] atIndex:0];
            gADPrivacyConfigInsertions7118++;
        }
        cfg.protocolClasses=a;
    } @catch(...) {}
}


// -----------------------------------------------------------------------------
// Retained v6.0.185 Dopamine per-app JIT client.
// -----------------------------------------------------------------------------
// ── DOPAMINE PER-APP JIT (v6.0.22) ──────────────────────────────────────────
// Production path: JIT is launch-time only. Settings changes already use the
// tweak's normal respring workflow, so there is no live CS_DEBUGGED revocation.
// Amazon asks the existing SpringBoard component to make one platform-authorized
// Dopamine request for Amazon's own PID, then verifies raw kernel CS_DEBUGGED.
#ifndef CS_OPS_STATUS
#define CS_OPS_STATUS 0
#endif
#ifndef CS_DEBUGGED
#define CS_DEBUGGED 0x10000000
#endif
#ifndef SYS_csops
#define SYS_csops 169
#endif

#define AD_JIT_REQ_NOTIFY_622 "com.colindavidr.amazondark/jit-request-622"
#define AD_JIT_RES_NOTIFY_622 "com.colindavidr.amazondark/jit-result-622"
#define AD_JIT_RC_NO_BACKEND_622 (-1001)
#define AD_JIT_RC_EXCEPTION_622  (-1002)
#define AD_JIT_RC_BAD_PID_622    (-1003)

typedef struct {
    uint32_t flags;
    int err;
    BOOL debugged;
} ADJITState622;

static ADJITState622 ADReadJITState622(void){
    ADJITState622 st = {0, 0, NO};
    errno = 0;
    long rc = syscall(SYS_csops, getpid(), CS_OPS_STATUS, &st.flags, sizeof(st.flags));
    st.err = (rc == 0 ? 0 : errno);
    st.debugged = (rc == 0 && (st.flags & CS_DEBUGGED) != 0);
    return st;
}

// 64-bit Darwin-notify state: pid[63:32], nonce[31:16], signed rc[15:0].
static uint64_t ADJITWireState622(pid_t pid, uint16_t nonce, int rc){
    return (((uint64_t)(uint32_t)pid) << 32) |
           (((uint64_t)nonce) << 16) |
           ((uint16_t)(int16_t)rc);
}
static pid_t ADJITWirePID622(uint64_t state){ return (pid_t)(uint32_t)(state >> 32); }
static uint16_t ADJITWireNonce622(uint64_t state){ return (uint16_t)((state >> 16) & 0xffffU); }
static int ADJITWireRC622(uint64_t state){ return (int)(int16_t)(state & 0xffffU); }

static uint16_t ADNextJITNonce622(void){
    static volatile uint32_t seq = 0;
    uint16_t n = (uint16_t)__sync_add_and_fetch(&seq, 1);
    return n ? n : 1;
}

static BOOL ADSendJITBrokerRequest622(int *brokerRCOut){
    int reqToken = 0, resToken = 0;
    BOOL got = NO;
    int rc = AD_JIT_RC_EXCEPTION_622;
    uint16_t nonce = ADNextJITNonce622();
    pid_t pid = getpid();

    if (notify_register_check(AD_JIT_RES_NOTIFY_622, &resToken) != NOTIFY_STATUS_OK) goto done;
    if (notify_register_check(AD_JIT_REQ_NOTIFY_622, &reqToken) != NOTIFY_STATUS_OK) goto done;
    if (notify_set_state(reqToken, ADJITWireState622(pid, nonce, 0)) != NOTIFY_STATUS_OK) goto done;
    if (notify_post(AD_JIT_REQ_NOTIFY_622) != NOTIFY_STATUS_OK) goto done;

    // Runs on a utility queue. Normal broker responses arrive almost immediately.
    for (int i = 0; i < 35; i++){
        uint64_t res = 0;
        if (notify_get_state(resToken, &res) == NOTIFY_STATUS_OK &&
            ADJITWirePID622(res) == pid && ADJITWireNonce622(res) == nonce){
            rc = ADJITWireRC622(res);
            got = YES;
            break;
        }
        usleep(10000);
    }

done:
    if (reqToken) notify_cancel(reqToken);
    if (resToken) notify_cancel(resToken);
    if (brokerRCOut) *brokerRCOut = rc;
    return got;
}

static void ADWriteJITReport622(NSString *status, BOOL responded, int backendRC,
                                ADJITState622 pre, ADJITState622 post){
    @try {
        NSString *p = [NSTemporaryDirectory() stringByAppendingPathComponent:@"AmazonDark-jit.txt"];
        NSString *s = [NSString stringWithFormat:
            @"AmazonDark %@\n"
             "enableJIT=%d\n"
             "status=%@\n"
             "backend=%@\n"
             "brokerResponded=%d\n"
             "backendRC=%d\n"
             "pid=%d\n"
             "preCsopsErr=%d\n"
             "preCsFlags=0x%08x\n"
             "preCS_DEBUGGED=%d\n"
             "postCsopsErr=%d\n"
             "postCsFlags=0x%08x\n"
             "postCS_DEBUGGED=%d\n"
             "amazonDarkTransitionedOn=%d\n",
             [NSString stringWithUTF8String:AD_VERSION], (gP.enabled && gP.enableJIT) ? 1 : 0,
             status ?: @"-",
             (gP.enabled && gP.enableJIT) ? @"SpringBoard-Dopamine-jbclient_platform_set_process_debugged" : @"none",
             responded ? 1 : 0, backendRC, getpid(),
             pre.err, pre.flags, pre.debugged ? 1 : 0,
             post.err, post.flags, post.debugged ? 1 : 0,
             (!pre.debugged && post.debugged && responded && backendRC == 0) ? 1 : 0];
        [s writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } @catch(...) {}
}

static void ADPerformJITRequest622(BOOL requestedOn){
    ADJITState622 pre = ADReadJITState622();

    // OFF is intentionally passive. The preference UI resprings, so a clean launch
    // simply makes no JIT request and starts without AmazonDark-owned CS_DEBUGGED.
    if (!requestedOn){
        ADWriteJITReport622(pre.debugged ? @"off-baseline-debugged" : @"off-clean",
                            NO, 0, pre, pre);
        return;
    }

    if (pre.debugged){
        ADWriteJITReport622(@"on-already-debugged", NO, 0, pre, pre);
        return;
    }

    int backendRC = AD_JIT_RC_EXCEPTION_622;
    BOOL responded = ADSendJITBrokerRequest622(&backendRC);
    ADJITState622 post = ADReadJITState622();
    NSString *status = @"on-failed-verification";

    if (!responded) status = @"on-broker-timeout";
    else if (backendRC == AD_JIT_RC_NO_BACKEND_622) status = @"broker-backend-unavailable";
    else if (backendRC == AD_JIT_RC_BAD_PID_622) status = @"broker-pid-rejected";
    else if (backendRC != 0) status = @"on-backend-error";
    else if (post.debugged) status = @"on-enabled-by-amazondark";

    ADWriteJITReport622(status, responded, backendRC, pre, post);
}

static void ADApplyJIT622(void){
    BOOL requestedOn = gP.enabled && gP.enableJIT;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool { ADPerformJITRequest622(requestedOn); }
    });
}


// -----------------------------------------------------------------------------
// Retained v6.0.185 Force 120 Hz implementation.
// -----------------------------------------------------------------------------
// ── PROMOTION + PRIVATE CADISPLAY 120 HZ FORCE (v6.0.10) ──────────────────────
// Public ProMotion ranges are advisory and v6.0.9 proved Core Animation was
// normalising Amazon back to 60 Hz even with both bundle opt-ins visible. On a
// jailbreak we can move one layer lower: CADisplay exposes a private
// overrideMinimumFrameDuration: policy selector. v6.0.10 experimentally clamps
// that integer policy to 2 on the 120-Hz device and verifies the resulting
// minimumFrameDuration/actual timing on-device rather than assuming success. We
// install a process-local runtime interpose so later CoreAnimation calls cannot
// silently restore the previous value while the preference is enabled.
//
// This affects only Amazon: AmazonDark.plist still injects this target solely into
// com.amazon.Amazon. We intentionally do NOT inject into backboardd or globally
// force SpringBoard; that would add system-wide battery/thermal cost and a daemon
// crash would be much more disruptive. If this private CADisplay path is absent on
// a future OS, every call is capability-checked and becomes a no-op.
static NSString * const ADPromotionInfoKey607 = @"CADisableMinimumFrameDurationOnPhone";
static NSString * const ADPromotionLegacyInfoKey609 = @"CADisableMinimumFrameDuration";

static BOOL ADIsPromotionInfoKey609(NSString *key){
    return [key isEqualToString:ADPromotionInfoKey607] || [key isEqualToString:ADPromotionLegacyInfoKey609];
}

static inline BOOL ADPromotionPreferenceOn611(void){ return gP.enabled && gP.force120Hz; }

%hook NSBundle
- (id)objectForInfoDictionaryKey:(NSString *)key {
    @try {
        if (ADPromotionPreferenceOn611() && self == [NSBundle mainBundle] && ADIsPromotionInfoKey609(key)) return @YES;
    } @catch(...) {}
    return %orig;
}
- (NSDictionary *)infoDictionary {
    NSDictionary *d = %orig;
    @try {
        if (!ADPromotionPreferenceOn611() || self != [NSBundle mainBundle]) return d;
        if ([d[ADPromotionInfoKey607] boolValue] && [d[ADPromotionLegacyInfoKey609] boolValue]) return d;
        NSMutableDictionary *m = [d mutableCopy];
        m[ADPromotionInfoKey607] = @YES;
        m[ADPromotionLegacyInfoKey609] = @YES;
        return m;
    } @catch(...) {}
    return d;
}
%end

%hookf(CFTypeRef, CFBundleGetValueForInfoDictionaryKey, CFBundleRef bundle, CFStringRef key) {
    if (ADPromotionPreferenceOn611() && bundle == CFBundleGetMainBundle() && key &&
        (CFEqual(key, CFSTR("CADisableMinimumFrameDurationOnPhone")) ||
         CFEqual(key, CFSTR("CADisableMinimumFrameDuration")))) return kCFBooleanTrue;
    return %orig;
}

%hookf(CFDictionaryRef, CFBundleGetInfoDictionary, CFBundleRef bundle) {
    CFDictionaryRef d = %orig;
    if (!ADPromotionPreferenceOn611() || bundle != CFBundleGetMainBundle() || !d) return d;
    static CFDictionaryRef promoted = NULL;
    if (promoted) return promoted;
    CFMutableDictionaryRef m = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, d);
    if (!m) return d;
    CFDictionarySetValue(m, CFSTR("CADisableMinimumFrameDurationOnPhone"), kCFBooleanTrue);
    CFDictionarySetValue(m, CFSTR("CADisableMinimumFrameDuration"), kCFBooleanTrue);
    promoted = m;
    return promoted;
}

static NSInteger ADPreferredMaxHz362(void){
    @try { return MIN((NSInteger)120, MAX((NSInteger)60, UIScreen.mainScreen.maximumFramesPerSecond)); } @catch(...) {}
    return 60;
}

// Weak registry of live links lets the Settings toggle take effect immediately in
// both directions. v6.0.10 only gated future setter calls; links already forced to
// 120 stayed forced until relaunch. Weak storage adds no ownership/lifetime cost.
static NSHashTable *gADDisplayLinks611 = nil;
static void ADTrackDisplayLink611(CADisplayLink *d){
    if (!d) return;
    @try {
        @synchronized([CADisplayLink class]) {
            if (!gADDisplayLinks611) gADDisplayLinks611 = [NSHashTable weakObjectsHashTable];
            [gADDisplayLinks611 addObject:d];
        }
    } @catch(...) {}
}
static NSArray *ADTrackedDisplayLinks611(void){
    @try {
        @synchronized([CADisplayLink class]) { return gADDisplayLinks611 ? gADDisplayLinks611.allObjects : @[]; }
    } @catch(...) {}
    return @[];
}

// Private CADisplay policy interpose. method_setImplementation keeps the hook local
// to Amazon and chains whatever implementation was present before AmazonDark.
typedef void (*ADCADisplayOverrideIMP610)(id, SEL, NSInteger);
static ADCADisplayOverrideIMP610 gADCADisplayOverrideOrig610 = NULL;
static BOOL gADCADisplayOverrideInstallTried610 = NO;
static BOOL gADCADisplayOverrideInstalled610 = NO;
static void ADForceOverrideMinimumFrameDuration610(id self, SEL _cmd, NSInteger duration){
    NSInteger forced = duration;
    @try { if (gP.enabled && gP.force120Hz && ADPreferredMaxHz362() >= 120) forced = 2; } @catch(...) {}
    if (gADCADisplayOverrideOrig610) gADCADisplayOverrideOrig610(self, _cmd, forced);
}
static void ADInstallPrivateDisplayForce610(void){
    if (gADCADisplayOverrideInstallTried610) return;
    gADCADisplayOverrideInstallTried610 = YES;
    @try {
        Class c = NSClassFromString(@"CADisplay");
        SEL sel = NSSelectorFromString(@"overrideMinimumFrameDuration:");
        Method m = c ? class_getInstanceMethod(c, sel) : NULL;
        if (!m) return;
        IMP old = method_getImplementation(m);
        if (!old || old == (IMP)ADForceOverrideMinimumFrameDuration610) return;
        gADCADisplayOverrideOrig610 = (ADCADisplayOverrideIMP610)old;
        method_setImplementation(m, (IMP)ADForceOverrideMinimumFrameDuration610);
        gADCADisplayOverrideInstalled610 = YES;
    } @catch(...) {}
}

static id ADDisplayForLink610(CADisplayLink *d){
    @try {
        SEL s = NSSelectorFromString(@"display");
        if (d && [d respondsToSelector:s]) return ((id(*)(id,SEL))objc_msgSend)(d,s);
    } @catch(...) {}
    return nil;
}

static const void *kADOrigLinkState611 = &kADOrigLinkState611;
static const void *kADOrigDisplayMin611 = &kADOrigDisplayMin611;
static void ADRememberPromotionState611(CADisplayLink *d){
    if (!d || objc_getAssociatedObject(d,kADOrigLinkState611)) return;
    @try {
        NSMutableDictionary *st=[NSMutableDictionary dictionary];
        st[@"fps"] = @(d.preferredFramesPerSecond);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ([d respondsToSelector:@selector(frameInterval)]) st[@"interval"] = @(d.frameInterval);
#pragma clang diagnostic pop
        if (@available(iOS 15.0,*)){
            CAFrameRateRange r=d.preferredFrameRateRange;
            st[@"range"]=[NSValue value:&r withObjCType:@encode(CAFrameRateRange)];
        }
        objc_setAssociatedObject(d,kADOrigLinkState611,st,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        id display=ADDisplayForLink610(d);
        if (display && !objc_getAssociatedObject(display,kADOrigDisplayMin611)){
            SEL minSel=NSSelectorFromString(@"minimumFrameDuration");
            if ([d respondsToSelector:minSel]){
                NSInteger v=((NSInteger(*)(id,SEL))objc_msgSend)(d,minSel);
                if (v>0) objc_setAssociatedObject(display,kADOrigDisplayMin611,@(v),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
    } @catch(...) {}
}
static void ADRestorePromotionState611(CADisplayLink *d){
    if (!d) return;
    @try {
        id display=ADDisplayForLink610(d);
        NSNumber *origMin=display ? objc_getAssociatedObject(display,kADOrigDisplayMin611) : nil;
        SEL forceSel=NSSelectorFromString(@"overrideMinimumFrameDuration:");
        if (origMin && display && [display respondsToSelector:forceSel])
            ((void(*)(id,SEL,NSInteger))objc_msgSend)(display,forceSel,(NSInteger)origMin.integerValue);
        SEL reasonSel=NSSelectorFromString(@"setHighFrameRateReason:");
        if ([d respondsToSelector:reasonSel])
            ((void(*)(id,SEL,uint32_t))objc_msgSend)(d,reasonSel,(uint32_t)0);
        NSDictionary *st=objc_getAssociatedObject(d,kADOrigLinkState611);
        if (st){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSNumber *interval=st[@"interval"];
            if (interval && [d respondsToSelector:@selector(setFrameInterval:)]) d.frameInterval=interval.integerValue;
#pragma clang diagnostic pop
            NSNumber *fps=st[@"fps"];
            if (fps) d.preferredFramesPerSecond=fps.integerValue;
            NSValue *rv=st[@"range"];
            if (rv){
                if (@available(iOS 15.0,*)){
                    CAFrameRateRange r; [rv getValue:&r]; d.preferredFrameRateRange=r;
                }
            }
        }
        objc_setAssociatedObject(d,kADOrigLinkState611,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (display) objc_setAssociatedObject(display,kADOrigDisplayMin611,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}

static BOOL ADForcePrivateDisplay610(CADisplayLink *d){
    if (!d || !gP.enabled || !gP.force120Hz || ADPreferredMaxHz362() < 120) return NO;
    ADInstallPrivateDisplayForce610();
    @try {
        id display = ADDisplayForLink610(d);
        SEL forceSel = NSSelectorFromString(@"overrideMinimumFrameDuration:");
        if (display && [display respondsToSelector:forceSel]){
            ((void(*)(id,SEL,NSInteger))objc_msgSend)(display, forceSel, (NSInteger)2);
            return YES;
        }
    } @catch(...) {}
    return NO;
}

static BOOL ADSetHighFrameRateReason610(CADisplayLink *d){
    @try {
        SEL s = NSSelectorFromString(@"setHighFrameRateReason:");
        if (d && [d respondsToSelector:s]){
            // Private CoreAnimation SPI; non-zero reason keeps this link classified
            // as high-frame-rate work rather than an idle/ordinary 60-Hz client.
            ((void(*)(id,SEL,uint32_t))objc_msgSend)(d,s,(uint32_t)0x41440001); // "AD" + 1
            return YES;
        }
    } @catch(...) {}
    return NO;
}

static CAFrameRateRange ADForcedRange610(void){
    // CAHighFPS' proven jailbreak pattern: leave a usable low bound but pin the
    // preferred + maximum values to the panel maximum. A rigid 120/120/120 range
    // was normalized back to 60 on this device in v6.0.9.
    float hz = (float)ADPreferredMaxHz362();
    return CAFrameRateRangeMake(30.0f, hz, hz);
}

static void ADApplyPromotion610(CADisplayLink *d){
    if (!d) return;
    ADTrackDisplayLink611(d);
    if (!gP.enabled || !gP.force120Hz) return;
    ADRememberPromotionState611(d);
    @try {
        ADForcePrivateDisplay610(d);       // policy first
        ADSetHighFrameRateReason610(d);    // classify link as high-rate
        // CAHighFPS does frameInterval first because Apple's implementation can
        // rewrite preferredFramesPerSecond as a side effect. Its proven fix is to
        // immediately force preferredFramesPerSecond back to 0 (= highest available).
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ([d respondsToSelector:@selector(setFrameInterval:)]) d.frameInterval = 1;
#pragma clang diagnostic pop
        d.preferredFramesPerSecond = 0;
        // Put the iOS 15+ range last so frameInterval's legacy setter cannot claw
        // the range back to 60 after we have selected the 120-Hz ceiling.
        if (@available(iOS 15.0,*)) d.preferredFrameRateRange = ADForcedRange610();
    } @catch(...) {}
}

%hook CADisplayLink
+ (CADisplayLink *)displayLinkWithTarget:(id)target selector:(SEL)sel {
    CADisplayLink *d = %orig;
    ADApplyPromotion610(d);
    return d;
}
- (instancetype)initWithTarget:(id)target selector:(SEL)sel {
    id d = %orig;
    ADApplyPromotion610((CADisplayLink *)d);
    return d;
}
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    @try {
        if (gP.enabled && gP.force120Hz){
            ADForcePrivateDisplay610(self);
            ADSetHighFrameRateReason610(self);
            // Match CAHighFPS: zero means "highest available" and avoids an app-
            // side numeric cap being re-normalized to 60 by Core Animation.
            NSInteger highest610 = 0;
            %orig(highest610);
            return;
        }
    } @catch(...) {}
    %orig;
}
- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    @try {
        if (gP.enabled && gP.force120Hz){
            ADForcePrivateDisplay610(self);
            ADSetHighFrameRateReason610(self);
            CAFrameRateRange range610 = ADForcedRange610();
            %orig(range610);
            return;
        }
    } @catch(...) {}
    %orig;
}
- (void)setFrameInterval:(NSInteger)interval {
    @try {
        if (gP.enabled && gP.force120Hz){
            ADForcePrivateDisplay610(self);
            NSInteger one610 = 1;
            %orig(one610);
            // Exact load-bearing CAHighFPS behavior: setFrameInterval: can impose
            // a 60-FPS preference internally, so clear that cap immediately after.
            if ([self respondsToSelector:@selector(setPreferredFramesPerSecond:)])
                self.preferredFramesPerSecond = 0;
            return;
        }
    } @catch(...) {}
    %orig;
}
- (void)addToRunLoop:(NSRunLoop *)runloop forMode:(NSRunLoopMode)mode {
    ADApplyPromotion610(self);
    %orig;
}
%end

// Reconfigure links immediately when the preference changes. Before forcing a
// link we snapshot its original public range/FPS/interval and its display's private
// minimum-frame-duration policy. OFF restores those exact values; ON reapplies the
// proven v6.0.10 force. No guessed "stock" frame rate is written.
static void ADRefreshPromotionState611(void){
    NSArray *links = ADTrackedDisplayLinks611();
    BOOL on = ADPromotionPreferenceOn611();
    for (CADisplayLink *d in links){
        if (!d) continue;
        @try {
            if (on){ ADApplyPromotion610(d); continue; }
            ADRestorePromotionState611(d);
        } @catch(...) {}
    }
}


// -----------------------------------------------------------------------------
// OLED floor — no Dark Reader, no DOM observer, no visual-component classifier.
// -----------------------------------------------------------------------------
static void ADPostReadyOnce(void);
static void ADConsiderLaunchReady706(void);
static const void *kADFloorUS=&kADFloorUS;
static const void *kADTWBUS=&kADTWBUS;
static const void *kADStandalonePaintUS7104=&kADStandalonePaintUS7104;
static const void *kADPrivacyUS7117=&kADPrivacyUS7117;
static const void *kADPrivacyRule7117=&kADPrivacyRule7117;
static NSHashTable *gADWebViews=nil;
// v7.0.68 production: no diagnostic touch probe is installed.

static NSString *ADFloorJS(void){
    // v7.0.14: static v185-style palette. CSS only: no Dark Reader, no observer,
    // no computed-style repair walker. Own known structural shells; preserve media/art.
    return @"(function(){try{var child=0;try{child=window.top!==window;}catch(_){child=1;}if(child&&document.documentElement){document.documentElement.setAttribute('data-ad7-child-frame','1');try{var ref=String(document.referrer||'').toLowerCase();var productish=/\\/dp\\/|\\/gp\\/product\\/|\\/gp\\/aw\\/d\\/|\\/s(?:[\\/?]|$)|[?&]k=/.test(ref);if(!productish)document.documentElement.setAttribute('data-ad7-standalone-candidate','1');}catch(__){}}var id='ad7-static-theme',s=document.getElementById(id);"
            "if(!s){s=document.createElement('style');s.id=id;(document.head||document.documentElement||document).appendChild(s);}"
            "s.textContent='"
            /* Root/page floors: immediate OLED canvas. */
            "html,body,#a-page,#gwm-PageContent,#dp,main,[role=main],#search,#cart-page,#sc-active-cart,#sc-saved-cart"
            "{background:#000!important;background-color:#000!important;}"
            /* Known structural panels/cards. Deliberately excludes generic section/div/a-cardui on Home creative trees. */
            ".s-result-item,[data-component-type=s-search-result],.s-card-container,.s-main-slot,"
            "#sc-active-cart .sc-list-item,#sc-saved-cart .sc-list-item,[class*=sc-][class*=content],[class*=sc-][class*=container],"
            "#dp [class*=a-box],#dp [class*=a-expander],#dp [class*=celwidget]:not([class*=image]):not([class*=media]),"
            "#authportal-main-section,#auth-footer,.auth-footer,[id*=auth-footer],"
            "[class*=variation],[class*=swatch-container],[class*=status-shell],[class*=badge-message],"
            "[class*=puis-card]:not([class*=creative]):not([class*=image]),[class*=product-card]:not([class*=image])"
            "{background-color:#181a1b!important;}"
            /* First-paint Search surface. Search overlay content must remain visible. */
            ".s-suggestion-container,.s-suggestion,.autocomplete-results-container,[class*=autocomplete],[class*=suggestion],"
            "[class*=recentSearch],[class*=search-suggestion]"
            "{background:#000!important;background-color:#000!important;color:#e8e6e3!important;}"
            /* Search is rendered inside a Home-deck WebView, so the general Home-text exclusion
             * can intentionally skip these leaves. Give only the Search/autocomplete family its
             * own neutral text owner; no traversal or runtime repair is needed. */
            ":is(.s-suggestion-container,.s-suggestion,.autocomplete-results-container,[class*=autocomplete],"
            "[class*=recentSearch],[class*=search-suggestion]) :is(h1,h2,h3,h4,h5,h6,p,span,a,div)"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            /* Primary/secondary v185-style text.
             * Do not let generic ink leak into Amazon-owned Sponsored feedback or
             * top-Home hero/creative trees. */
            ":is(.a-color-base,.a-text-normal,.a-size-base,.a-size-base-plus,.a-size-medium,"
            ".a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen,"
            ".s-title-instructions-style,.a-link-normal h2,[class*=product-title],"
            "[class*=heading],[class*=title]:not([class*=badge]))"
            ":not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback])"
            ":not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-])"
            ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *))"
            ":not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *))"
            ":not(:where([id^=af-label-] *))"
            ":not(:where(html[data-ad7-child-frame] *))"
            ":not(:where(#gwm-Deck *)):not(:where([class*=hero] *))"
            ":not(:where([class*=single-creative] *)):not(:where([class*=single-video] *))"
            ":not(:where([class*=theming-card] *))"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            ":is(.a-color-secondary,.a-size-small,[class*=secondary])"
            ":not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback])"
            ":not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-])"
            ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *))"
            ":not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *))"
            ":not(:where([id^=af-label-] *))"
            ":not(:where(html[data-ad7-child-frame] *))"
            ":not(:where(#gwm-Deck *)):not(:where([class*=hero] *))"
            ":not(:where([class*=single-creative] *)):not(:where([class*=single-video] *))"
            ":not(:where([class*=theming-card] *))"
            "{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;}"
            /* Neutral borders/dividers. Exact structural families only; no global * border rewrite. */
            ".s-result-item,.s-card-container,[data-component-type=s-search-result],"
            "#sc-active-cart .sc-list-item,#sc-saved-cart .sc-list-item,"
            "#dp .a-box,#dp .a-divider,#dp [class*=card],"
            ".s-suggestion-container,#auth-footer .a-divider,.auth-footer .a-divider,"
            "[class*=swatch-outer-circle],[class*=puis-card]"
            "{border-color:#494d4d!important;outline-color:#494d4d!important;}"
            ".a-divider-inner:after,.a-divider-inner:before,hr,[class*=separator]"
            "{border-color:#494d4d!important;background-color:#494d4d!important;}"
            /* Established cheap fixes / gradients. */
            "#wd-backdrop-gradient,.wd-backdrop-gradient,[class*=wd-backdrop-gradient],"
            "[class*=a-reactive-container],[class*=reactive-contain],"
            "#auth-footer,.auth-footer,[id*=auth-footer]"
            "{background-image:none!important;box-shadow:none!important;}"
            "#auth-footer .a-divider-inner,.auth-footer .a-divider-inner{background-image:none!important;box-shadow:none!important;}"
            ".s-color-swatch-container,.s-color-swatch-outer-circle{background-color:transparent!important;}"
            ".s-color-swatch-outer-circle{border-color:#494d4d!important;outline-color:#494d4d!important;}"
            /* v7.121 Search glyph correction. Search/nav IMG chrome stays transparent, but
             * the proven autocomplete I-elements are CSS MASK leaves: their background-color IS
             * the glyph ink. v7.120 made those exact mask leaves transparent and therefore hid
             * them. Keep generic image/SVG glyph treatment separate, then own only the exact mask
             * ink leaves after it so no square host is created. */
            "[class*=nav-search] img,[class*=searchbar] img,[class*=search-bar] img,[role=search] img,"
            "[class*=nav-] img[class*=icon],[class*=header] img[class*=icon]"
            "{background-color:transparent!important;}"
            ".s-suggestion-container :is(img[class*=icon],img[alt*=search],img[alt*=arrow],svg,i.a-icon,[class*=glyph],[class*=icon-search],[class*=search-icon]),"
            ".s-suggestion :is(img[class*=icon],img[alt*=search],img[alt*=arrow],svg,i.a-icon,[class*=glyph],[class*=icon-search],[class*=search-icon])"
            "{color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;"
            "filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;}"
            /* Current + donor-proven mask leaves. These are 20px I-elements, not rectangular
             * backdrop hosts. Background-color is mask ink and filter must remain none. */
            ".s-suggestion-container [class*=icon-past-search-sugge]"
            "{background-color:#9da3a3!important;color:#9da3a3!important;fill:#9da3a3!important;"
            "stroke:#9da3a3!important;filter:none!important;-webkit-filter:none!important;"
            "opacity:1!important;box-shadow:none!important;}"
            ".s-suggestion-container .icon-close.s-suggestion-icon-left"
            "{background-color:#e8e6e3!important;color:#e8e6e3!important;fill:#e8e6e3!important;"
            "stroke:#e8e6e3!important;filter:none!important;-webkit-filter:none!important;"
            "opacity:1!important;box-shadow:none!important;}"
            /* The left You-May-Be-Interested magnifier is also an icon-search/search-icon mask
             * family on this autocomplete lineage. Restrict mask-ink ownership to I elements so
             * image-backed icons retain transparent backdrops. */
            ".s-suggestion-container i:is([class*=icon-search],[class*=search-icon]),"
            ".s-suggestion i:is([class*=icon-search],[class*=search-icon])"
            "{background-color:#e8e6e3!important;color:#e8e6e3!important;fill:#e8e6e3!important;"
            "stroke:#e8e6e3!important;filter:none!important;-webkit-filter:none!important;"
            "opacity:1!important;box-shadow:none!important;}"
            /* Share/overflow exact leaves from probe history. */
            ".puis-mab-overlay-row-share .puis-mab-overlay-icon-share"
            "{background-color:#e8e6e3!important;color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;filter:none!important;}"
            /* v7.0.28 Home floor ownership.
             *
             * Probe correction: generated NPACK/GWM bundle-family prefixes occur
             * on descendants such as badgeLabel and ad-feedback-text, so those
             * prefixes are never used as floor selectors. */
            ":is(#gwm-PageContent,#gwm-Deck-btf) :is("
            ".a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf],"
            "[class*=hp-mosaic-container_style_container],[class*=_mosaic-container_style_widgetContainer])"
            "{background-color:#000!important;border-color:#494d4d!important;"
            "mix-blend-mode:normal!important;isolation:auto!important;}"
            /* Exact ordinary carousel below the hero. Historical/current probes
             * expose gwm-dashboard-container here; hero theming/creative cards are
             * outside this parent and retain Amazon's original color/media paint. */
            ".gwm-dashboard-container :is("
            ".a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf])"
            "{background-color:#000!important;border-color:#494d4d!important;"
            "mix-blend-mode:normal!important;isolation:auto!important;}"
            /* Product-media blend correction.
             * v7.0.39 completes the old generic-Home-media coverage without a
             * classifier: any real IMG inside a proven ordinary Home card gets
             * leaf-local blend normalization. UI/identity/ad-chrome leaves are
             * explicitly rejected. */
            ":is(#gwm-PageContent,#gwm-Deck-btf,#gwm-Deck,.gwm-dashboard-container) "
            ":is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]) "
            "img"
            ":not([class*=logo]):not([class*=avatar]):not([class*=profile])"
            ":not([class*=merchant]):not([class*=seller]):not([class*=brand]):not([class*=store])"
            ":not([class*=rating]):not([class*=star]):not([class*=sprite]):not([class*=pixel])"
            ":not([class*=icon]):not([class*=glyph]):not([class*=badge])"
            ":not([class*=checkbox]):not([class*=heart]):not([class*=wishlist])"
            ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *))"
            ":not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *))"
            "{mix-blend-mode:normal!important;isolation:auto!important;background-color:transparent!important;}"
            /* Some Home cards put the destructive blend on PICTURE/image
             * wrappers instead of the IMG. Normalize those media-only wrappers
             * too, but never apply TWB brightness to the wrapper itself. */
            ":is(#gwm-Deck-btf,.gwm-dashboard-container) "
            ":is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]) "
            ":is(picture,[class*=image-wrapper],[class*=img-wrapper],[class*=image-container])"
            "{mix-blend-mode:normal!important;isolation:auto!important;background-color:transparent!important;}"
            ":is(#gwm-PageContent,#gwm-Deck-btf,#gwm-Deck,.gwm-dashboard-container) "
            ":is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]) "
            "[class*=asin-metadata]"
            "{mix-blend-mode:normal!important;isolation:auto!important;}"
            /* v7.0.38 probe-confirmed multi-category media.
             * Disney/Pet wellness/Jewelry/Smart Home cards use direct IMG leaves
             * named _multi-category-card_image_* rather than asin/product-image.
             * Normalize the IMG leaf only; never the card or its live text. */
            ":is(#gwm-Deck-btf,.gwm-dashboard-container) [class*=multi-category-card] img"
            "{mix-blend-mode:normal!important;isolation:auto!important;"
            "background-color:transparent!important;}"
            /* Exact deal-message host only: remove the white plate, but never
             * repaint %off badgeLabel or Limited time deal text. */
            ":is(#gwm-PageContent,#gwm-Deck-btf,#gwm-Deck,.gwm-dashboard-container) [class*=badgeMessage]"
            "{background-color:transparent!important;box-shadow:none!important;}"
            /* v7.0.33: text-only Home correction on the v7.0.29 baseline.
             * Keep v7.0.29 hero/TWB isolation intact and only light ordinary
             * below-fold card/mosaic captions and headers. Sponsored/ad-feedback
             * plus badge/deal/coupon chrome remain Amazon-owned. */
            ":is(#gwm-Deck-btf,.gwm-dashboard-container) "
            ":is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]) "
            ":is(h1,h2,h3,h4,h5,h6,p,span,a)"
            ":not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback])"
            ":not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-])"
            ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *))"
            ":not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *))"
            ":not(:where([id^=af-label-] *))"
            ":not([class*=badge]):not([class*=deal]):not([class*=coupon])"
            ":not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *))"
            ":not(:where([class*=hero] *)):not(:where([class*=single-creative] *)):not(:where([class*=single-video] *))"
            ":not(:where([class*=theming-card] *)):not(:where([class*=creative-card] *)):not(:where([class*=ad-card] *)):not(:where([class*=canvas-card] *))"
            ":not(:where([class*=mobile-mshop-ad] *)):not(:where([class*=mobile-ad-container] *))"
            ":not(:where([class*=ape-wrapper] *)):not(:where([class*=ape-placement] *))"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            /* v7.107: below-fold neutral Home ink fallback. The Outlet recommendation
             * pane can place otherwise-standard Amazon neutral text leaves outside
             * the historical a-cardui/asin/mosaic/p13n roots, leaving product names
             * and prices at stock #0f1111/#111 on our OLED floor. Match only known
             * neutral Amazon text/price semantics and reject ad/creative/deal chrome. */
            ":is(#gwm-Deck-btf,.gwm-dashboard-container) "
            ":is(.a-color-base,.a-text-normal,.a-size-base,.a-size-base-plus,.a-size-medium,"
            ".a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen,"
            "[class*=product-title],[class*=product-name],[class*=item-title])"
            ":not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback])"
            ":not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-])"
            ":not([class*=badge]):not([class*=deal]):not([class*=coupon])"
            ":not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *))"
            ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *))"
            ":not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *))"
            ":not(:where([class*=hero] *)):not(:where([class*=single-creative] *)):not(:where([class*=single-video] *))"
            ":not(:where([class*=theming-card] *)):not(:where([class*=creative-card] *)):not(:where([class*=ad-card] *)):not(:where([class*=canvas-card] *))"
            ":not(:where([class*=mobile-mshop-ad] *)):not(:where([class*=mobile-ad-container] *)):not(:where(#mobile-third-party-ad *))"
            ":not(:where([class*=ape-wrapper] *)):not(:where([class*=ape-placement] *))"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            /* v7.0.39 exact card-header ink.
             * The dashboard carousel can hydrate one header with Amazon's dark
             * inline foreground even while sibling cards are already light.
             * Own only the a-cardui header text lane; Sponsored lives outside it. */
            ":is(#gwm-Deck-btf,.gwm-dashboard-container) .a-cardui-header "
            ":is(h1,h2,h3,h4,h5,h6,a,span,p)"
            ":not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback])"
            ":not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-])"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            /* v7.0.42: exact dashboard title leaves seen by the current probe.
             * Some APE-backed cards use windowPaneHeaderContainer instead of wpTitle.
             * Own only the title link/leaf; Sponsored remains in a separate badge row. */
            ":is(#gwm-Deck-btf,.gwm-dashboard-container) .a-cardui :is([class*=wpTitle],[class*=windowPaneHeaderContainer])"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            /* Bare Home section headers can live outside the inner card shell. */
            ":is(#gwm-Deck-btf,.gwm-dashboard-container) :is(h1,h2,h3,h4,h5,h6)"
            ":not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback])"
            ":not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-])"
            ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *))"
            ":not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *))"
            ":not([class*=badge]):not([class*=deal]):not([class*=coupon])"
            ":not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *))"
            ":not(:where([class*=hero] *)):not(:where([class*=single-creative] *)):not(:where([class*=single-video] *))"
            ":not(:where([class*=theming-card] *)):not(:where([class*=creative-card] *)):not(:where([class*=ad-card] *)):not(:where([class*=canvas-card] *))"
            ":not(:where([class*=mobile-mshop-ad] *)):not(:where([class*=mobile-ad-container] *))"
            ":not(:where([class*=ape-wrapper] *)):not(:where([class*=ape-placement] *))"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            /* v7.0.40: restore the cheap v185/v7.0.16 seasonal mosaic ink contract.
             * v7.0.39 had accidentally narrowed this to headings/captions only, so
             * category labels such as Laundry / Beauty / Water bottles inherited
             * Amazon's dark foreground on our OLED seasonal shell. */
            ":is(#gwm-PageContent,#gwm-Deck-btf,.gwm-dashboard-container) "
            ":is([class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer]) "
            ":is(div,section,article,ul,ol,li,a,p,span,h1,h2,h3,h4,h5,h6)"
            ":not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback])"
            ":not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-])"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            /* Seasonal navigation host ink. */
            ":is(#gwm-PageContent,#gwm-Deck-btf,.gwm-dashboard-container) "
            ":is([class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer]) "
            ":is([class*=next],[class*=prev],[class*=chevron],[class*=arrow])"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;"
            "fill:#e8e6e3!important;stroke:#e8e6e3!important;}"
            /* v7.0.42 restores the proven v5.440/v5.449 MAB sprite leaf directly.
             * The visible chevron is an I.a-icon.a-icon-dropdown background sprite;
             * it is not reliably nested under the seasonal family wrapper. */
            ".puis-mab-chevron :is(i.a-icon-dropdown,.a-icon.a-icon-dropdown),"
            ".puis-mab-chevron-glyph :is(i.a-icon-dropdown,.a-icon.a-icon-dropdown)"
            "{filter:brightness(0) invert(1)!important;opacity:1!important;}"
            /* v7.0.45: College/seasonal chevron completion. The v7.0.43 native
             * probe found no UIKit seasonal/college control, so this glyph is web
             * chrome. Current Amazon layouts can detach the historical MAB wrapper
             * from the newer seasonal/NPACK family names, leaving the exact
             * i.a-icon.a-icon-dropdown sprite dark. Own that sprite leaf anywhere
             * inside the Home deck; keep the narrower semantic fallbacks too. */
            ":is(#gwm-PageContent,#gwm-Deck,#gwm-Deck-btf,.gwm-dashboard-container) i.a-icon.a-icon-dropdown,"
            ":is(#gwm-PageContent,#gwm-Deck-btf,.gwm-dashboard-container) "
            ":is([class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer],[class*=_npack-asin-card_style_theming-background-override__]) "
            ":is([class*=next],[class*=prev],[class*=chevron],[class*=arrow]) :is(i.a-icon,.a-icon,[class*=glyph]),"
            ":is(#gwm-PageContent,#gwm-Deck-btf,.gwm-dashboard-container) "
            ":is([class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer],[class*=_npack-asin-card_style_theming-background-override__]) "
            ":is(i.a-icon-dropdown,i[class*=chevron],i[class*=arrow])"
            "{filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;opacity:1!important;}"
            /* v7.0.49 current-head behavior retained: broad unscoped dropdown/
             * chevron sprite fallbacks. The remaining dark chevron therefore is
             * not assumed to be one of these leaves; v7.0.50 probes the actual tap. */
            "i.a-icon.a-icon-dropdown,.a-icon.a-icon-dropdown,"
            "i[class*=chevron],i[class*=arrow],[class*=chevron-glyph],"
            "[class*=puis-mab-chevron] :is(i.a-icon-dropdown,.a-icon.a-icon-dropdown)"
            "{filter:brightness(0) invert(1) brightness(0.91)!important;"
            "-webkit-filter:brightness(0) invert(1) brightness(0.91)!important;"
            "opacity:1!important;visibility:visible!important;mix-blend-mode:normal!important;}"
            /* v7.0.46: cheap v6.0.185 Web border parity. v185's final visible
             * card/section outline was #3b4043 after its palette path. Own color only:
             * no width, radius, layout, shadow, or hit-target changes. */
            ":is([class*=a-cardui],[class*=npack-asin-card],[class*=gwm-asin-tile],[class*=gwm-window-layout],"
            "[class*=window-container],[class*=gwm-dashboard-container],[class*=wd-backdrop],"
            "[class*=theming-card],[class*=a-unordered-list],[class*=mosaic-container],"
            "[class*=puis-card],[class*=gwm-tile],[class*=_container_])"
            ":not([class*=deal]):not([class*=badge]):not([class*=prime]):not([class*=error])"
            ":not([class*=alert]):not([class*=warning])"
            "{border-color:#3b4043!important;outline-color:#3b4043!important;}"
            /* v185 also owned the actual nested seasonal/mosaic border-bearing shells,
             * not just the outer mosaic root. This is what keeps those visible card
             * outlines from falling back to Amazon white. */
            ":is([class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer]) "
            ":is(div,section,article,ul,ol,li)"
            "{border-color:#3b4043!important;outline-color:#3b4043!important;}"
            /* v7.95: Disney / Amazon Shopping Guides quad-card media parity.
             * The v7.94 current-viewport probe exposed this renderer as
             * data-csa-c-painter=amazon-shopping-guides-quad-card-cards. Its own
             * _YW1he_colored-background_* shell uses mix-blend-mode:darken and
             * the product IMG uses mix-blend-mode:multiply. Against our OLED card
             * floor those blend modes collapse the artwork into black until the
             * pressed state changes compositing. Normalize compositing only. */
            "[data-csa-c-painter=amazon-shopping-guides-quad-card-cards] [class*=_colored-background_],"
            "[data-csa-c-painter=amazon-shopping-guides-quad-card-cards] [class*=_product-image_],"
            "[data-csa-c-painter=amazon-shopping-guides-quad-card-cards] [class*=_image_]"
            "{mix-blend-mode:normal!important;isolation:auto!important;}"
            /* v7.96: give Shopping Guides product tiles the same v185/hero
             * product-photo plate treatment used by the seasonal NPACK hero.
             * Amazon's _colored-background_ shell is the light #f7f7f7 contain
             * plate visible around the actual product raster. Replace only that
             * leftover plate with OLED black; the existing image sizing/contain,
             * padding, radius, position and TWB raster filter are left untouched. */
            "[data-csa-c-painter=amazon-shopping-guides-quad-card-cards] [class*=_colored-background_]"
            "{background:#000!important;background-color:#000!important;border-color:#000!important;"
            "outline-color:#000!important;box-shadow:none!important;transition-property:none!important;}"
            /* v7.0.46: standalone ad dark surface. Classification is O(1) at
             * documentStart from child-frame/referrer state; viewport geometry is
             * handled declaratively by the media query, so there is no DOM scan,
             * observer, timer, or per-node classifier. Product/Search child frames
             * are excluded by the referrer gate. */
            "@media (max-height:260px) and (min-aspect-ratio:5/3){"
            "html[data-ad7-standalone-candidate],html[data-ad7-standalone-candidate] body"
            "{background:#000!important;background-color:#000!important;color:#e8e6e3!important;}"
            "html[data-ad7-standalone-candidate] :is(div,section,article,main,header,footer,ul,ol,li)"
            "{background-color:transparent!important;border-color:#3b4043!important;}"
            "html[data-ad7-standalone-candidate] :is(h1,h2,h3,h4,h5,h6,p,span,a,strong,small,b,em,label)"
            ":not([class*=badge]):not([class*=deal]):not([class*=coupon])"
            ":not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback])"
            ":not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-])"
            ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *))"
            ":not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *))"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            "html[data-ad7-standalone-candidate] :is(img,picture,video,canvas,svg)"
            "{background-color:transparent!important;}"
            "}"
            /* v7.93: standalone dynamic-product ad ownership from the v7.92
             * current-viewport probe. These APE child creatives are a separate
             * m.media-amazon.com frame and the captured 430x358 renderer is not
             * covered by the old wide/short @media lane above. Anchor only to the
             * ad renderer's own data-is-ad/data-testid semantics so ordinary child
             * documents stay untouched. Structural floor becomes OLED black;
             * neutral primary copy becomes v185 primary ink and Amazon's genuinely
             * secondary neutral copy becomes subdued gray. Blue/colored accents,
             * Prime artwork and rating stars are intentionally not recolored. */
            "html[data-ad7-standalone-candidate] :is(body,#ad,section[data-is-ad=true],[data-testid=ad-background-container])"
            "{background:#000!important;background-color:#000!important;color:#e8e6e3!important;}"
            "html[data-ad7-standalone-candidate] [data-testid=ad-background-container]"
            "{background:#000!important;background-color:#000!important;background-image:none!important;"
            "border-color:#3b4043!important;outline-color:#3b4043!important;box-shadow:none!important;}"
            /* The captured renderer owns a left text gradient and a right product
             * plate as the two direct children. Kill only those floor paints; do
             * not blanket-clear nested badges or accent components. */
            "html[data-ad7-standalone-candidate] [data-testid=ad-background-container] > div"
            "{background:#000!important;background-color:#000!important;background-image:none!important;}"
            /* v7.108: exact first-party 300x250 Swiper standalone carousel from
             * the v7.107 device capture. v7.107 looked for the literal word
             * "carousel", but this renderer never exposes it: the child is
             * #ad[data-html-dimensions=300x250] -> data-testid=gridContainer ->
             * .swiper-wrapper/.swiper-slide. Own that proven signature directly.
             * The gridContainer is the one surviving #fff light plane; slide
             * structure is otherwise transparent. Prime/rating-star/deal/badge
             * accents stay Amazon-owned. */
            "html[data-ad7-standalone-candidate] #ad[data-html-dimensions=\"300x250\"]"
            "{background:#000!important;background-color:#000!important;}"
            "html[data-ad7-standalone-candidate] #ad[data-html-dimensions=\"300x250\"] [data-testid=gridContainer]"
            "{background:#000!important;background-color:#000!important;background-image:none!important;}"
            "html[data-ad7-standalone-candidate] #ad[data-html-dimensions=\"300x250\"] "
            ":is(div,section,article,main,header,footer,ul,ol,li)"
            ":not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=prime])"
            ":not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=prime] *))"
            "{background-color:transparent!important;}"
            "html[data-ad7-standalone-candidate] #ad[data-html-dimensions=\"300x250\"] .swiper-slide > [class*=border-gray-]"
            "{border-color:#3b4043!important;outline-color:#3b4043!important;box-shadow:none!important;}"
            "html[data-ad7-standalone-candidate] #ad[data-html-dimensions=\"300x250\"] "
            ":is(h1,h2,h3,h4,h5,h6,p,span,a,strong,small,b,em,label,div)"
            ":not(div:has([class*=prime],[data-testid*=prime],[class*=star],[data-testid*=star]))"
            ":not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=prime]):not([class*=star])"
            ":not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback])"
            ":not([data-testid*=prime]):not([data-testid*=star])"
            ":not(:where([data-testid*=prime] *)):not(:where([data-testid*=star] *))"
            ":not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=prime] *)):not(:where([class*=star] *))"
            ":not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *))"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            "html[data-ad7-standalone-candidate] #ad[data-html-dimensions=\"300x250\"] "
            ":is(div,span,p,a,small,strong,b)[class*=sponsored],"
            "html[data-ad7-standalone-candidate] #ad[data-html-dimensions=\"300x250\"] "
            ":is(div,span,p,a,small,strong,b)[data-testid*=sponsored]"
            "{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}"
            /* v7.95: compact REC/renderer-factory lane from the v7.94 probe.
             * The captured 430x130 child frame uses modern-414x125-layout-container
             * with an Amazon #d5d9d9 border and dark navy product copy. Own paint
             * only: no width/height/margin/padding/radius/display/flex changes. */
            "html[data-ad7-standalone-candidate] [data-testid=renderer-factory-ad-container] "
            "[data-testid^=modern-][data-testid$=-layout-container]"
            "{background:#000!important;background-color:#000!important;border-color:#3b4043!important;"
            "outline-color:#3b4043!important;box-shadow:none!important;}"
            /* v7.110: 430x67 compact renderer-factory variant. The device probe
             * shows renderer-factory + main-content are already black, but the
             * deeper data-testid=content surface retains an inline #fff floor.
             * Own only that proven structural surface; its existing radius/layout,
             * Sponsored row geometry and text remain Amazon-owned. */
            "html[data-ad7-standalone-candidate] [data-testid=renderer-factory-ad-container] [data-testid=content]"
            "{background:#000!important;background-color:#000!important;}"
            /* v7.110: dynamic-bb deal copy uses a classless white direct child
             * inside data-testid=deal-badge rather than message-container. Clear
             * only the inline-white label plate; the red % badge and red
             * `Limited time deal` text keep their authored color. */
            "html[data-ad7-standalone-candidate] #dynamic-bb [data-testid=deal-badge] > "
            "div[style*=\"background-color: rgb(255, 255, 255)\"]"
            "{background-color:transparent!important;box-shadow:none!important;}"
            "html[data-ad7-standalone-candidate] [data-testid=renderer-factory-ad-container] "
            ":is([data-id=brand-name-text],[data-id=product-name-text],[data-testid=ratings-value],"
            "[data-testid=formatted-price],[data-testid=formatted-price] *)"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            "html[data-ad7-standalone-candidate] [data-testid=renderer-factory-ad-container] "
            ":is([data-testid=ratings-review-count],[data-testid=full-price])"
            "{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;}"
            /* Primary standalone-ad copy. */
            "html[data-ad7-standalone-candidate] [data-testid=brand-product-description] p,"
            "html[data-ad7-standalone-candidate] [data-testid=ratings-value],"
            "html[data-ad7-standalone-candidate] [data-testid=price-container] :is(div,span)"
            ":not([data-testid=full-price]):not([data-testid=prime-badge])"
            ":not(:where([data-testid=prime-badge] *)),"
            "html[data-ad7-standalone-candidate] [data-testid=sns-coupon-badge-container] :is(div,span,p),"
            "html[data-ad7-standalone-candidate] [data-testid=ad-background-container] "
            ":is(p,span,div,a,small,strong,b)[style*=\"color: rgb(15, 17, 17)\"]"
            ":not(:where([data-testid=ratings-stars] *)):not(:where([data-testid=prime-badge] *)),"
            "html[data-ad7-standalone-candidate] [data-testid=ad-background-container] "
            ":is(p,span,div,a,small,strong,b)[style*=\"color: black\"]"
            ":not(:where([data-testid=ratings-stars] *)):not(:where([data-testid=prime-badge] *))"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            /* Secondary neutral metadata: review count and struck list price. */
            "html[data-ad7-standalone-candidate] [data-testid=ratings-review-count],"
            "html[data-ad7-standalone-candidate] [data-testid=full-price],"
            "html[data-ad7-standalone-candidate] [data-testid=ad-background-container] "
            ":is(p,span,div,a,small,strong,b)[style*=\"color: rgb(86, 89, 89)\"],"
            "html[data-ad7-standalone-candidate] [data-testid=ad-background-container] "
            ":is(p,span,div,a,small,strong,b)[style*=\"color:#565959\"]"
            "{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;}"
            /* Keep the product-photo lane structurally black; TWB owns only the
             * actual raster leaf in ADTWBJS below. */
            "html[data-ad7-standalone-candidate] :is([data-testid*=product-picture],[data-testid*=product-image],[data-testid*=asin-image],picture)"
            "{background-color:transparent!important;box-shadow:none!important;}"
            /* v7.106: Sponsored TEXT remains Amazon-owned. Known Sponsored glyph
             * families are owned declaratively below; the old semantic DOM learner
             * has been retired, so there is no Sponsored runtime selector scan. */
            /* Creative/media protection: only true media/product-image wrappers are
             * normalized. Hero/single-creative/theming/ad-card containers are excluded so
             * Amazon keeps their own campaign floor and text contrast. */
            "picture,img,video,canvas,#imgTagWrapperId,.s-product-image-container,[data-component-type=s-product-image],"
            "[class*=image-wrapper],[class*=img-wrapper],[class*=image-container],[class*=product-image],[class*=asin-image]"
            "{background-color:transparent!important;}"
            /* Narrow standalone APE structural owner retained by the later 6.x/v185 lineage.
             * Placement chrome only; no Sponsored text/glyph/media ownership. */
            "[class*=ape-wrapper],[class*=ape-placement],[class*=ape-feedback]"
            "{background-color:transparent!important;border-color:transparent!important;"
            "outline-color:transparent!important;box-shadow:none!important;}"
            "iframe[id*=ape_],iframe[class*=ape_]"
            "{background-color:transparent!important;border-color:transparent!important;"
            "outline-color:transparent!important;}"
            /* v7.112: the compact 320x50 SafeFrame already owns the correct
             * 1px rounded boundary on the MAIN-FRAME .ape-placement. v7.111
             * proved a child #ad::after overlay is clipped at the SafeFrame's
             * terminal compositor edge. Recolor only Amazon's existing parent
             * border; width/radius/overflow/geometry remain Amazon-owned and the
             * separate Sponsored feedback row remains outside the boundary. */
            ".ape-wrapper[style*=\"--ad-height:50\"] > .ape-placement[style*=\"aspect-ratio: 320 / 50\"]"
            "{border-color:#3b4043!important;}"
            /* v7.107: same rare sponsored carousel when Amazon renders the shell
             * directly in the mshop document instead of wholly inside a child
             * safe-frame. Scope to the already-known standalone mobile ad roots
             * and require carousel semantics so ordinary Home carousels are not
             * affected. */
            ":is(#gwm-Deck-btf,.gwm-dashboard-container) "
            ":is([class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data-testid*=carousel]))"
            "{background:#000!important;background-color:#000!important;border-color:#3b4043!important;"
            "outline-color:#3b4043!important;box-shadow:none!important;}"
            ":is(#gwm-Deck-btf,.gwm-dashboard-container) "
            ":is([class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data-testid*=carousel])) "
            ":is(div,section,article,main,header,footer,ul,ol,li)"
            ":not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=prime])"
            ":not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=prime] *))"
            "{background-color:transparent!important;}"
            ":is(#gwm-Deck-btf,.gwm-dashboard-container) "
            ":is([class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data-testid*=carousel])) "
            ":is(h1,h2,h3,h4,h5,h6,p,span,a,strong,small,b,em,label)"
            ":not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=prime])"
            ":not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback])"
            ":not([data-testid=prime-badge]):not(:where([data-testid=prime-badge] *))"
            ":not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=prime] *))"
            ":not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *))"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            ":is(#gwm-Deck-btf,.gwm-dashboard-container) "
            ":is([class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data-testid*=carousel])) "
            ":is(span,p,a,small,strong,b)[class*=sponsored],"
            ":is(#gwm-Deck-btf,.gwm-dashboard-container) "
            ":is([class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data-testid*=carousel])) "
            ":is(span,p,a,small,strong,b)[data-testid*=sponsored]"
            "{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}"
            /* v7.0.73: suppress Amazon's persistent keyboard-focus ring on the
             * Sponsored feedback trigger. Amazon's own ad-feedback CSS applies a
             * rounded 3px outline to the focused Sponsored text control; after the
             * feedback sheet closes that control remains focused, leaving the gray
             * box seen on Home. Own only the focus decoration, not text/glyph ink. */
            ":is([class*=ad-feedback-text],[class*=ad-feedback-text-desktop],[id^=ad-feedback-text-],[id^=af-label-primary-link-],[aria-label^=\"Leave feedback on Sponsored\"]):is(:focus,:focus-visible)"
            "{outline:none!important;box-shadow:none!important;-webkit-tap-highlight-color:transparent!important;}"
            /* v7.0.72 pre-release: Amazon ad-feedback bottom sheet.
             * The v7.0.71 tap capture exposed the exact AUI sheet and
             * adFeedbackBottomSheet/mobile-ad-feedback hierarchy. Theme this
             * declaratively only when that feedback sheet exists: OLED structural
             * floor, light copy, search-field gray textarea, and dark controls.
             * No observer, timer, traversal, or runtime lifecycle owner. */
            "body:has([id^=adFeedbackBottomSheet_]) :is(.a-sheet-web-container,.a-sheet-web,.a-sheet-content-container),"
            "body:has([id^=adFeedbackBottomSheet_]) [class*=ad-feedback-bottom-sheet-container],"
            "body:has([id^=adFeedbackBottomSheet_]) :is(#af-form-top-container,#mobile-ad-feedback-container)"
            "{background:#000!important;background-color:#000!important;color:#e8e6e3!important;"
            "-webkit-text-fill-color:#e8e6e3!important;}"
            "body:has([id^=adFeedbackBottomSheet_]) :is(#af-form-top-container,#mobile-ad-feedback-container) "
            ":is(div,section,article,form,fieldset,header,footer)"
            "{background-color:transparent!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            "body:has([id^=adFeedbackBottomSheet_]) :is(#af-form-top-container,#mobile-ad-feedback-container) "
            ":is(h1,h2,h3,h4,h5,h6,p,span,label,legend,small,strong,b,a)"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            "body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container textarea"
            "{background:#303335!important;background-color:#303335!important;color:#e8e6e3!important;"
            "-webkit-text-fill-color:#e8e6e3!important;border-color:#6f6f6f!important;box-shadow:none!important;}"
            "body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container input[type=checkbox]"
            "{background-color:#000!important;border-color:#b1aaa0!important;accent-color:#303335!important;color-scheme:dark!important;}"
            "body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container :is(.a-icon-checkbox,i.a-icon-checkbox)"
            "{filter:invert(1)!important;-webkit-filter:invert(1)!important;opacity:1!important;}"
            "body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container :is(.a-button,.a-button-inner,button,input[type=button],input[type=submit])"
            "{background:#181a1b!important;background-color:#181a1b!important;color:#e8e6e3!important;"
            "-webkit-text-fill-color:#e8e6e3!important;border-color:#6f6f6f!important;box-shadow:none!important;}"
            "body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container :is(button,input[type=button],input[type=submit]):disabled,"
            "body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container .a-button-disabled"
            "{background:#181a1b!important;background-color:#181a1b!important;color:#8a8a8a!important;"
            "-webkit-text-fill-color:#8a8a8a!important;border-color:#494d4d!important;}"
            /* Keep actual form controls readable without overriding Amazon yellow/accent buttons. */
            "input:not([type=button]):not([type=submit]),textarea,select"
            "{background-color:#181a1b!important;color:#e8e6e3!important;border-color:#494d4d!important;}"
            "::placeholder{color:#b1aaa0!important;opacity:1!important;}"
            "[class*=header-icon],[class*=header-icon] path,[class*=header-icon] use,"
            "[class*=header-link] svg path,[class*=cardui-header] svg path,"
            "a[class*=header-link] path,[class*=see-more] path,[class*=view-all] path"
            "{fill:#e8e6e3!important;stroke:#e8e6e3!important;color:#e8e6e3!important;"
            "opacity:1!important;}"
            "[class*=hp-mosaic-container] .a-icon-next-rounded,"
            "[class*=hp-mosaic-container] .a-icon-previous-rounded,"
            "[class*=hp-mosaic-container] [class*=chevron],"
            "[class*=hp-mosaic-container] [class*=arrow],"
            "[class*=_mosaic-container_style_widgetContainer] .a-icon-next-rounded,"
            "[class*=_mosaic-container_style_widgetContainer] .a-icon-previous-rounded,"
            "[class*=_mosaic-container_style_widgetContainer] [class*=chevron],"
            "[class*=_mosaic-container_style_widgetContainer] [class*=arrow],"
            ".a-icon-next-rounded,.a-icon-previous-rounded"
            "{filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;"
            "opacity:1!important;color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;}"
            /* v7.0.79: deterministic Sponsored glyph ownership for the late-hydrating
             * NPACK / sponsored-products renderer families.  v7.0.73 could win the
             * race on-device, but later lifecycle work exposed that the element can
             * be replaced after the one-shot JS pass.  Own only the masked glyph
             * paint declaratively so replacement nodes stay light without observers. */
            ":is([class*=_npack-asin-card_style_ad-feedback-spr],[class*=_npack-asin-card_style_ad-feedback-sprite],[class*=_cXVhZ_ad-feedback-spr],[class*=_cXVhZ_ad-feedback-sprite],[class*=_sponsored-products-mo])"
            "{color:#e8e6e3!important;background-color:#e8e6e3!important;filter:none!important;-webkit-filter:none!important;opacity:1!important;}"
            /* v7.86: Hybrid GWM/NPACK carousel Sponsor glyphs are owned per instance,
             * not by the old class-level color learner. The Amazon bundle reuses the
             * same hashed sprite classes across sibling cards, so a learned literal
             * color from one card can contaminate another after hydration/refresh.
             * Rebuild only the 12x12 Hybrid info glyph as the stock mask and let
             * currentColor inherit from its own adjacent Amazon-owned Sponsor text.
             * No Sponsored text rule is written. */
            "html body [data-ad-feedback-label-id] b[class*=ad-feedback-sprite-mobile][class*=labelThemeStyle_ad-feedback-sprite-mobile],"
            "html body [data-ad-feedback-label-id] b[class*=ad-feedback-sprite-mobile]"
            "{color:inherit!important;background-color:currentColor!important;background-image:none!important;"
            "-webkit-mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;"
            "mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;"
            "-webkit-mask-size:contain!important;mask-size:contain!important;"
            "-webkit-mask-repeat:no-repeat!important;mask-repeat:no-repeat!important;"
            "-webkit-mask-position:center!important;mask-position:center!important;"
            "filter:none!important;-webkit-filter:none!important;opacity:1!important;}"
            /* v7.91: Home product-carousel Sponsored parity. The v7.89 current-frame
             * capture proved these card families can hydrate through multiple Amazon
             * renderers while reusing the Grey ad-feedback theme. In the failing
             * states the visible text is driven by -webkit-text-fill-color while the
             * 12x12 info mask is driven independently by background-color, producing
             * white/gray text beside a dark glyph. Own both inks only inside the
             * carousel badge shells captured by the probe; other Sponsored surfaces
             * remain Amazon-owned. v7.91 uses the app's subdued secondary gray for
             * both inks rather than pure white. This is declarative CSS only. */
            "html body :is([class*=widget-sponsored-badge-container],[class*=asin-sponsored-badge-container]) "
            "[data-ad-feedback-label-id] [class*=ad-feedback-text]"
            "{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}"
            "html body :is([class*=widget-sponsored-badge-container],[class*=asin-sponsored-badge-container]) "
            "[data-ad-feedback-label-id] [class*=ad-feedback-text] > b[class*=ad-feedback-sprite-mobile]"
            "{color:#b1aaa0!important;background-color:#b1aaa0!important;background-image:none!important;"
            "-webkit-mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;"
            "mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;"
            "-webkit-mask-size:contain!important;mask-size:contain!important;"
            "-webkit-mask-repeat:no-repeat!important;mask-repeat:no-repeat!important;"
            "-webkit-mask-position:center!important;mask-position:center!important;"
            "filter:none!important;-webkit-filter:none!important;opacity:1!important;}"
            /* v7.93: standalone APE Sponsored label parity. The v7.92 viewport
             * capture identified a separate main-frame renderer under .ape-feedback:
             * ad-feedback-text-* is inline #555 and ad-feedback-sprite-* is a
             * new_info_icon_3x.png background that our dark palette converts into a
             * mask. Match the same subdued #b1aaa0 contrast used by the carousel
             * Sponsored badges, but scope it only to the standalone APE feedback
             * chrome so every other Sponsored surface keeps its existing owner. */
            "html body :is(.ape-feedback,[id^=ape_][id*=\"_Feedback\"]) [id^=ad-feedback-text-]"
            "{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}"
            "html body :is(.ape-feedback,[id^=ape_][id*=\"_Feedback\"]) [id^=ad-feedback-sprite-]"
            "{color:#b1aaa0!important;background-color:#b1aaa0!important;background-image:none!important;"
            "-webkit-mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;"
            "mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;"
            "-webkit-mask-size:contain!important;mask-size:contain!important;"
            "-webkit-mask-repeat:no-repeat!important;mask-repeat:no-repeat!important;"
            "-webkit-mask-position:center!important;mask-position:center!important;"
            "filter:none!important;-webkit-filter:none!important;opacity:1!important;}"
            /* v7.0.79: the screenshot probe identified the actual Home load-more
             * wheel as _hp-mosaic-container_style_loadingSpinner__JXI3z. Amazon's
             * ::after pseudo is the opaque white center disc; match it to the OLED
             * floor while preserving the light rotating ::before/ring artwork. */
            "[class*=_hp-mosaic-container_style_loadingSpinner]::after"
            "{background:#000!important;background-color:#000!important;box-shadow:none!important;}"
            /* Retain the current v7.0.47-v7.0.49 system-control parity. */
            "::-webkit-scrollbar{background-color:transparent!important;}"
            "::-webkit-scrollbar-track{background-color:transparent!important;}"
            "::-webkit-scrollbar-thumb{background-color:#6f6f6f!important;border-radius:8px!important;"
            "border:2px solid transparent!important;background-clip:content-box!important;}"
            "::-webkit-scrollbar-thumb:hover{background-color:#8a8a8a!important;}"
            "';"
            /* v7.95: compact REC child frames can discard the early style
             * node while their document parser/renderer finishes. Re-attach the
             * same sheet once at load; no scan, timer, observer or geometry work. */
            "function ad7RelinkStatic(){try{if(s&&!s.isConnected)(document.head||document.documentElement).appendChild(s)}catch(_){}}"
            "if(document.readyState==='loading')window.addEventListener('load',ad7RelinkStatic,{once:true});else ad7RelinkStatic();"
            /* v7.106 performance: retire the legacy semantic Sponsored glyph learner.
             * Every currently-proven Sponsored family now has a deterministic static
             * CSS owner above (NPACK, Hybrid, product-carousel and APE feedback).
             * Removing the learner eliminates its document/local selector scans while
             * preserving those current renderer-specific owners. */
            "document.documentElement.style.setProperty('background-color','#000','important');"
            "document.documentElement.style.setProperty('color-scheme','dark','important');"
            "if(document.body){document.body.style.setProperty('background-color','#000','important');document.body.style.setProperty('color-scheme','dark','important');}"
            "}catch(e){}})();";
}

// v7.106: standalone-ad shell-survival owner migrated from a DOM <style> node to
// a document-adopted constructable stylesheet. v7.104 proved Amazon replaces HEAD/BODY
// while preserving the Document/HTML object and also proved adoptedStyleSheets support.
// The standalone theme therefore survives that shell swap without MutationObserver,
// descendant scanning, polling, or geometry work.
static NSString *ADStandalonePaintJS7104(void){
    CGFloat strength=MAX(0,MIN(100,gP.whiteTameStrength));
    CGFloat t=strength/100.0;
    CGFloat shade=0.10+(0.48*t);
    CGFloat factor=1.0-shade;
    return [NSString stringWithFormat:
        @"(function(){try{if(window.top===window)return;var h=document.documentElement;if(!h)return;"
         "var ref=String(document.referrer||'').toLowerCase();"
         "var productish=/\\/dp\\/|\\/gp\\/product\\/|\\/gp\\/aw\\/d\\/|\\/s(?:[\\/?]|$)|[?&]k=/.test(ref);"
         "if(productish)return;h.setAttribute('data-ad7104-standalone','1');"
         "var KEY='__ad7StandaloneSheet7106';"
         "var CSS='"
         "html[data-ad7104-standalone],html[data-ad7104-standalone] body,"
         "html[data-ad7104-standalone] #ad,html[data-ad7104-standalone] #ad > div,"
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container],"
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container] [data-testid=main-content],"
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container] [data-testid=content],"
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container] [data-testid^=modern-][data-testid$=-layout-container],"
         "html[data-ad7104-standalone] [data-testid=ad-background-container]"
         "{background:#000!important;background-color:#000!important;}"
         /* Exact 320x50 AdaptiveRenderer negative-z white backplane. */
         "html[data-ad7104-standalone] #ad [style*=\\\"z-index:-2\\\"]"
         "{background:#000!important;background-color:#000!important;}"
         /* Medium/large existing outlines only; geometry remains Amazon-owned. */
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container] [data-testid^=modern-][data-testid$=-layout-container],"
         "html[data-ad7104-standalone] [data-testid=ad-background-container]"
         "{border-color:#3b4043!important;outline-color:#3b4043!important;}"
         /* Large dynamic-product structural planes. */
         "html[data-ad7104-standalone] [data-testid=ad-background-container] > div"
         "{background:#000!important;background-color:#000!important;background-image:none!important;}"
         /* Exact standalone deal-message host. The device capture exposes the
          * white `Limited time deal` plate as data-testid=message-container.
          * Mirror the existing Home badgeMessage fix: clear only the structural
          * plate/shadow and leave the discount badge + label ink Amazon-owned. */
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container] [data-testid=message-container],"
         "html[data-ad7104-standalone] #dynamic-bb [data-testid=deal-badge] > "
         "div[style*=\\\"background-color: rgb(255, 255, 255)\\\"]"
         "{background-color:transparent!important;box-shadow:none!important;}"
         /* v7.108: exact first-party 300x250 Swiper standalone carousel. The
          * v7.107 probe proves why the prior rule missed: this renderer has no
          * class/data-testid containing "carousel". Its stable signature is
          * #ad[data-html-dimensions=300x250] with data-testid=gridContainer and
          * .swiper-wrapper/.swiper-slide descendants. The gridContainer is the
          * sole surviving white plane, so make it OLED and leave slide structure
          * transparent; own the existing slide border only. */
         "html[data-ad7104-standalone] #ad[data-html-dimensions=\"300x250\"]"
         "{background:#000!important;background-color:#000!important;}"
         "html[data-ad7104-standalone] #ad[data-html-dimensions=\"300x250\"] [data-testid=gridContainer]"
         "{background:#000!important;background-color:#000!important;background-image:none!important;}"
         "html[data-ad7104-standalone] #ad[data-html-dimensions=\"300x250\"] "
         ":is(div,section,article,main,header,footer,ul,ol,li)"
         ":not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=prime])"
         ":not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=prime] *))"
         "{background-color:transparent!important;}"
         "html[data-ad7104-standalone] #ad[data-html-dimensions=\"300x250\"] .swiper-slide > [class*=border-gray-]"
         "{border-color:#3b4043!important;outline-color:#3b4043!important;box-shadow:none!important;}"
         "html[data-ad7104-standalone] #ad[data-html-dimensions=\"300x250\"] "
         ":is(h1,h2,h3,h4,h5,h6,p,span,a,strong,small,b,em,label,div)"
         ":not(div:has([class*=prime],[data-testid*=prime],[class*=star],[data-testid*=star]))"
         ":not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=prime]):not([class*=star])"
         ":not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback])"
         ":not([data-testid*=prime]):not([data-testid*=star])"
         ":not(:where([data-testid*=prime] *)):not(:where([data-testid*=star] *))"
         ":not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=prime] *)):not(:where([class*=star] *))"
         ":not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *))"
         "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
         "html[data-ad7104-standalone] #ad[data-html-dimensions=\"300x250\"] "
         ":is(div,span,p,a,small,strong,b)[class*=sponsored],"
         "html[data-ad7104-standalone] #ad[data-html-dimensions=\"300x250\"] "
         ":is(div,span,p,a,small,strong,b)[data-testid*=sponsored],"
         "html[data-ad7104-standalone] #ad[data-html-dimensions=\"300x250\"] "
         ":is([data-ad-feedback-label-id] [class*=ad-feedback-text],[id^=ad-feedback-text-])"
         "{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}"
         "html[data-ad7104-standalone] #ad[data-html-dimensions=\"300x250\"] "
         ":is([data-ad-feedback-label-id] [class*=ad-feedback-sprite],[id^=ad-feedback-sprite-])"
         "{color:#b1aaa0!important;background-color:#b1aaa0!important;background-image:none!important;"
         "-webkit-mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;"
         "mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;"
         "-webkit-mask-size:contain!important;mask-size:contain!important;"
         "-webkit-mask-repeat:no-repeat!important;mask-repeat:no-repeat!important;"
         "-webkit-mask-position:center!important;mask-position:center!important;"
         "filter:none!important;-webkit-filter:none!important;opacity:1!important;}"
         /* Compact 320x50 neutral copy. */
         "html[data-ad7104-standalone] #dynamic-bb [data-testid=product-description]"
         "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
         "html[data-ad7104-standalone] #dynamic-bb [data-acei-id=sns-disc]"
         "{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;}"
         /* 414x125 + large primary neutral copy. */
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container] "
         ":is([data-id=brand-name-text],[data-id=product-name-text],[data-testid=ratings-value],[data-testid=formatted-price],[data-testid=formatted-price] *),"
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container] "
         ":is(div,span,p,a,small,strong,b)[style*=\\\"color: rgb(0, 0, 17)\\\"],"
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container] "
         ":is(div,span,p,a,small,strong,b)[style*=\\\"color: rgb(15, 17, 17)\\\"],"
         "html[data-ad7104-standalone] [data-testid=brand-product-description] p,"
         "html[data-ad7104-standalone] [data-testid=price-container] :is(div,span)"
         ":not([data-testid=full-price]):not([data-testid=prime-badge]):not(:where([data-testid=prime-badge] *)),"
         "html[data-ad7104-standalone] [data-testid=ad-background-container] "
         ":is(p,span,div,a,small,strong,b)[style*=\\\"color: rgb(15, 17, 17)\\\"]"
         ":not(:where([data-testid=ratings-stars] *)):not(:where([data-testid=prime-badge] *))"
         "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
         /* Secondary neutral metadata only. */
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container] "
         ":is([data-testid=ratings-review-count],[data-testid=full-price]),"
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container] "
         ":is(div,span,p,a,small,strong,b)[style*=\\\"color: rgb(86, 89, 89)\\\"],"
         "html[data-ad7104-standalone] [data-testid=ad-background-container] "
         ":is(div,span,p,a,small,strong,b)[style*=\\\"color: rgb(86, 89, 89)\\\"]"
         "{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;}"
         /* Preserve current TWB strength on the exact standalone product-raster lanes even
          * if Amazon's shell replacement deletes the global ad7-twb-static sheet. */
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container] "
         ":is([data-testid=image],[data-acei-id=lfstyl-img]) :is(img,video,canvas),"
         "html[data-ad7104-standalone] :is([data-testid*=product-picture],[data-testid*=product-image],[data-testid*=asin-image]) :is(img,video,canvas),"
         /* v7.112: exact compact 320x50 media ownership. The live v7.111
          * capture identifies lfstyl-img as the Image grid host; keep prod-img as
          * the known A/B fallback. Require compact #dynamic-bb so medium/large
          * standalone renderers stay untouched except for the exact store-logo lane added below. */
         "html[data-ad7104-standalone] #ad:has(#dynamic-bb) "
         ":is([data-acei-id=lfstyl-img],[data-acei-id=prod-img]) :is(img,video,canvas),"
         /* v7.114: store/brand identity raster parity. Repeated device captures
          * expose the store image as data-acei-id=brnd-logo -> IMG alt=Brand logo
          * (with data-testid=logo as the renderer wrapper on 414x125). Add only
          * this exact standalone identity lane to TWB; do not widen the generic
          * logo exclusions that protect Prime, stars, badges and UI glyphs. */
         "html[data-ad7104-standalone] [data-acei-id=brnd-logo] img,"
         "html[data-ad7104-standalone] [data-testid=logo] img[alt=\"Brand logo\"]"
         "{filter:brightness(%.4f)!important;-webkit-filter:brightness(%.4f)!important;}"
         /* v7.108: exact first-party 300x250 Swiper carousel media. Both the
          * active product tile and the neighboring custom-image tile expose the
          * actual raster as data-testid=pictureHighQuality. Tame only those leaves,
          * which keeps Prime blue, orange rating stars, unrelated logos/badges and glyphs at
          * their authored colors/intensity. */
         "html[data-ad7104-standalone] #ad[data-html-dimensions=\"300x250\"] "
         ".swiper-slide [data-testid=pictureHighQuality]"
         "{filter:brightness(%.4f)!important;-webkit-filter:brightness(%.4f)!important;}"
         /* v7.107: third-party 300x250 display/video creative TWB. The device
          * probe exposes this lane as #mobile-third-party-ad -> Flashtalking
          * creative container -> nested iframe. Dim the one outer ad host once;
          * this reaches canvas/HTML5/video internals without scanning or touching
          * Amazon's separate Sponsored feedback row. */
         "html[data-ad7104-standalone] #mobile-third-party-ad"
         "{filter:brightness(%.4f)!important;-webkit-filter:brightness(%.4f)!important;}"
         "';"
         "function black(){try{h=document.documentElement||h;if(!h)return;h.setAttribute('data-ad7104-standalone','1');h.style.setProperty('background-color','#000','important');h.style.setProperty('color-scheme','dark','important');if(document.body){document.body.style.setProperty('background-color','#000','important');document.body.style.setProperty('color-scheme','dark','important')}}catch(_){}}"
         "function own(){try{h=document.documentElement||h;if(!h)return false;black();if(!(document.adoptedStyleSheets&&window.CSSStyleSheet&&CSSStyleSheet.prototype&&CSSStyleSheet.prototype.replaceSync))return false;var sh=window[KEY];if(!sh){sh=new CSSStyleSheet();sh.replaceSync(CSS);window[KEY]=sh;}var a=document.adoptedStyleSheets||[],found=false;for(var i=0;i<a.length;i++)if(a[i]===sh){found=true;break;}if(!found)document.adoptedStyleSheets=a.concat([sh]);return true}catch(e){return false}}"
         "window.__ad7106StandaloneState=function(){try{var sh=window[KEY]||null,a=document.adoptedStyleSheets||[],found=false;for(var i=0;i<a.length;i++)if(a[i]===sh){found=true;break;}return{adoptedSupported:!!(document.adoptedStyleSheets&&window.CSSStyleSheet&&CSSStyleSheet.prototype&&CSSStyleSheet.prototype.replaceSync),sheet:!!sh,adopted:found,rules:sh&&sh.cssRules?sh.cssRules.length:0,htmlSame:(document.documentElement===h),attr:!!(document.documentElement&&document.documentElement.hasAttribute('data-ad7104-standalone'))}}catch(e){return{error:String(e)}}};"
         "own();document.addEventListener('readystatechange',function(){own()},false);window.addEventListener('pageshow',function(){own()},false);"
         "}catch(e){}})();",factor,factor,factor,factor,factor,factor];
}


// v7.114 production: compact standalone diagnostic WKUserScript removed.
static NSString *ADTWBJS(void){
    // Pure CSS TWB owner: no load listener, no querySelectorAll, no observer.
    // v7.0.29 restores the proven Home media families from the streamlined 6.x
    // owner without reviving its runtime scanner/classifier.
    CGFloat strength=MAX(0,MIN(100,gP.whiteTameStrength));
    /* v7.91: map the full 0..100 slider onto a useful dimming envelope.
     * The toggle is the true off switch, so slider 0 is intentionally a subtle
     * minimum treatment rather than "no effect". Old range: 1.00..0.50.
     * New range: 0.90..0.42 (10%%..58%% black equivalent), making the low end
     * visibly functional and the high end slightly darker than the old maximum. */
    CGFloat t=strength/100.0;
    CGFloat shade=0.10+(0.48*t);
    CGFloat factor=1.0-shade;
    return [NSString stringWithFormat:
        @"(function(){try{var child=0;try{child=window.top!==window;}catch(_){child=1;}if(child&&document.documentElement)document.documentElement.setAttribute('data-ad7-twb-child','1');var id='ad7-twb-static',s=document.getElementById(id);"
         "if(!s){s=document.createElement('style');s.id=id;(document.head||document.documentElement||document).appendChild(s);}"
         "s.textContent='"
         /* Ordinary/product imagery. */
         "img.s-image,img.s-product-image,#landingImage,#imgBlkFront,#imgTagWrapperId img,"
         "img[data-a-dynamic-image],img.a-dynamic-image,[data-component-type=s-product-image] img,"
         "[class*=product-image] img,[class*=asin-image] img,.p13n-sc-uncoverable-faceout img,"
         "[data-asin] img.s-image,[data-csa-c-asin] img.s-image,"
         /* v7.0.39 generic ordinary Home-card media.
          * v6.0.29's old coverage showed that large Home/category media often
          * has no product-image semantic class. Restrict the broad IMG rule to
          * proven ordinary card roots, then reject UI/identity/chrome leaves.
          * This covers dashboard cards, Trending, Smart Home, Keep Shopping,
          * multi-category cards, and similar ordinary Home panes without a scan. */
         ":is(#gwm-Deck-btf,.gwm-dashboard-container) "
         ":is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]) "
         "img"
         ":not([class*=logo]):not([class*=avatar]):not([class*=profile])"
         ":not([class*=merchant]):not([class*=seller]):not([class*=brand]):not([class*=store])"
         ":not([class*=rating]):not([class*=star]):not([class*=sprite]):not([class*=pixel])"
         ":not([class*=icon]):not([class*=glyph]):not([class*=badge])"
         ":not([class*=checkbox]):not([class*=heart]):not([class*=wishlist])"
         ":not([class*=search-icon]):not([class*=microphone]):not([class*=camera]):not([class*=location])"
         ":not([class*=chevron]):not([class*=nav-icon]):not([class*=tab-icon]):not([class*=header-icon]):not([class*=ad-feedback]):not([class*=sponsored]):not([class*=spr])"
         ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *))"
         ":not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)),"
         /* v7.0.43: persistent v185-style child-frame media ownership.
          * A recycled hero can hydrate from IMG into VIDEO/CANVAS after the first
          * viewport visit. Keep the lane declarative so any replacement leaf is
          * tamed immediately with no observer, scan or scroll repair. */
         "html[data-ad7-twb-child=\"1\"]:not([data-ad7-standalone-candidate]) :is(img,video,canvas)"
         ":not([class*=logo]):not([class*=avatar]):not([class*=profile]):not([class*=merchant]):not([class*=seller])"
         ":not([class*=rating]):not([class*=star]):not([class*=checkbox]):not([class*=heart]):not([class*=wishlist])"
         ":not([class*=search-icon]):not([class*=microphone]):not([class*=camera]):not([class*=location])"
         ":not([class*=chevron]):not([class*=nav-icon]):not([class*=tab-icon]):not([class*=header-icon]):not([class*=ad-feedback]):not([class*=sponsored]):not([class*=spr]):not([class*=sprite]):not([class*=pixel])"
         ":not([class*=icon]):not([class*=glyph]):not([class*=badge])"
         ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *))"
         ":not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)),"
         /* v7.93: standalone dynamic-product ads get TWB on the product raster
          * only. The v7.92 probe exposed simple-product-picture as the dedicated
          * product-photo host; excluding the generic child-frame lane above keeps
          * logos, Prime artwork, orange stars and all other creative accents at
          * stock intensity. */
         "html[data-ad7-standalone-candidate] "
         ":is([data-testid*=product-picture],[data-testid*=product-image],[data-testid*=asin-image]) "
         ":is(img,video,canvas)"
         ":not([class*=logo]):not([class*=icon]):not([class*=glyph]):not([class*=badge])"
         ":not(:where([data-testid=ratings-stars] *)):not(:where([data-testid=prime-badge] *)),"
         /* v7.95: compact renderer-factory ads expose the actual creative raster
          * under data-testid=image / data-acei-id=lfstyl-img rather than the
          * large renderer's product-picture names. Filter only that media leaf;
          * the surrounding REC geometry and text remain untouched. */
         "html[data-ad7-standalone-candidate] [data-testid=renderer-factory-ad-container] "
         ":is([data-testid=image],[data-acei-id=lfstyl-img]) :is(img,video,canvas)"
         ":not([class*=logo]):not([class*=icon]):not([class*=glyph]):not([class*=badge]),"
         /* v7.112: exact compact AdaptiveRenderer media hosts. The current
          * device capture uses data-acei-id=lfstyl-img; prod-img is retained as
          * the known A/B fallback. Keep this behind compact #dynamic-bb so only
          * the 320x50 creative raster is tamed. */
         "html[data-ad7-standalone-candidate] #ad:has(#dynamic-bb) "
         ":is([data-acei-id=lfstyl-img],[data-acei-id=prod-img]) :is(img,video,canvas),"
         /* v7.114: exact store/brand image lane shared by the standalone
          * AdaptiveRenderer / renderer-factory variants. This is deliberately
          * positive ownership: generic logo/icon exclusions stay in place, while
          * only the captured brnd-logo raster receives the current TWB factor. */
         "html[data-ad7-standalone-candidate] [data-acei-id=brnd-logo] img,"
         "html[data-ad7-standalone-candidate] [data-testid=logo] img[alt=\"Brand logo\"],"
         /* v7.108: exact first-party 300x250 Swiper carousel media. The probe
          * identifies data-testid=pictureHighQuality on both product and custom
          * slide rasters, so this lane no longer depends on nonexistent
          * "carousel" semantics and cannot touch Prime/star accent painters. */
         "html[data-ad7-standalone-candidate] #ad[data-html-dimensions=\"300x250\"] "
         ".swiper-slide [data-testid=pictureHighQuality],"
         /* v7.107: exact third-party standalone creative host captured by the
          * Flashtalking 300x250 probe. Filtering the outer host once tames the
          * entire HTML5/canvas/video creative while avoiding generic standalone
          * child media and its logos/deal artwork. */
         "html[data-ad7-standalone-candidate] #mobile-third-party-ad,"
         /* Main-document standalone ad media if Amazon renders it outside the iframe. */
         "#gwm-Deck-btf :is([class*=mobile-mshop-ad],[class*=mobile-ad-container],[class*=ape-wrapper],[class*=ape-placement]) "
         ":is(img,video,canvas)"
         ":not([class*=logo]):not([class*=prime]):not([class*=rating]):not([class*=star])"
         ":not([class*=icon]):not([class*=glyph]):not([class*=badge])"
         ":not(:where([class*=logo] *)):not(:where([class*=prime] *)):not(:where([class*=rating] *)):not(:where([class*=star] *))"
         ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *))"
         ":not(:where([data-testid=prime-badge] *)):not(:where([data-testid=ratings-stars] *))"
         ":not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)),"
         /* Seasonal mosaic media + image/SVG artwork.
          * Navigation chevrons/arrows are control ink, not TWB media. */
         "[class*=hp-mosaic-container] :is(img,svg)"
         ":not([class*=next]):not([class*=prev]):not([class*=chevron]):not([class*=arrow])"
         ":not(:where([class*=next] *)):not(:where([class*=prev] *))"
         ":not(:where([class*=chevron] *)):not(:where([class*=arrow] *)):not([class*=header-icon]):not([class*=ad-feedback]):not([class*=sponsored]):not([class*=spr]),"
         "[class*=_mosaic-container_style_widgetContainer] :is(img,svg)"
         ":not([class*=next]):not([class*=prev]):not([class*=chevron]):not([class*=arrow])"
         ":not(:where([class*=next] *)):not(:where([class*=prev] *))"
         ":not(:where([class*=chevron] *)):not(:where([class*=arrow] *)):not([class*=header-icon]):not([class*=ad-feedback]):not([class*=sponsored]):not([class*=spr]),"
         /* Historical single-creative / single-video / canvas Home media. */
         "img[class*=_single-creative-card],img[class*=_single-video-card],"
         "[class*=single-creative-card] img,[class*=single-video-card] img,"
         "[class*=single-video-card] video,[class*=canvas-card] canvas,video.vjs-tech,"
         /* v7.0.44: the NPACK seasonal hero swaps its dimmed JPEG backdrop for a
          * real background VIDEO about a second after hydration. The probe caught
          * that VIDEO at readyState=4 with filter:none while its theming-card
          * backdrop still carried the TWB shade. Own the replacement media leaf
          * declaratively so playback cannot visually escape TWB. */
         "video[class*=_npack-asin-card_style_background-video__],"
         "[class*=_npack-asin-card_style_background-video-container__] > video[class*=_npack-asin-card_style_motion-content__]"
         "{filter:brightness(%.3f)!important;}"
         /* v7.0.45: exact v185-style NPACK product-photo plate. The probe shows
          * each product IMG is already TWB-filtered, but its 133x117
          * _asin-container-white__ shell still owns rgb(255,255,255). v185's
          * appearance comes from that leftover contain/padding space being OLED
          * black while the product raster itself remains intact. Own the shell
          * directly rather than merely shading white to gray. */
         ":is([class*=theming-card-background],[class*=_npack-asin-card_style_theming-background-override__]) "
         "[class*=_npack-asin-card_style_asin-container-white__]"
         "{background:#000!important;background-color:#000!important;border-color:#000!important;outline-color:#000!important;"
         "box-shadow:none!important;transition-property:none!important;}"
         /* v7.0.44 persistence lock for CSS-background hero artwork.
          * The v185-derived inventory names four direct empty background leaves.
          * Also match a late inline background-image inside only proven creative
          * families; CSS automatically follows recycler/style changes. */
         "[class*=theming-card-background],"
         "[class*=vjs-poster],"
         "[class*=single-creative-card-background],"
         "[class*=single-video-card-background],"
         "[class*=single-creative-card] [class*=theming-card-background],"
         "[class*=single-video-card] [class*=theming-card-background],"
         "[class*=single-video-card] [class*=vjs-poster],"
         ":is([class*=single-creative-card],[class*=single-video-card],[class*=theming-card],[class*=_npack-asin-card],[class*=npack-asin-card],[class*=canvas-card],[class*=canvas-container])"
         ":is([style*=\"background-image\"],[style*=\"backgroundImage\"])"
         ":not([class*=logo]):not([class*=icon]):not([class*=glyph]):not([class*=sprite]):not([class*=pixel]):not([class*=badge]):not([class*=chevron]),"
         ":is([class*=single-creative-card],[class*=single-video-card],[class*=theming-card],[class*=_npack-asin-card],[class*=npack-asin-card],[class*=canvas-card],[class*=canvas-container]) "
         ":is([style*=\"background-image\"],[style*=\"backgroundImage\"])"
         ":not([class*=logo]):not([class*=icon]):not([class*=glyph]):not([class*=sprite]):not([class*=pixel]):not([class*=badge]):not([class*=chevron]),"
         "html[data-ad7-twb-child=\"1\"] :is([class*=theming-card-background],[class*=vjs-poster],[class*=single-creative-card-background],[class*=single-video-card-background])"
         "{box-shadow:inset 0 0 0 9999px rgba(0,0,0,%.3f)!important;transition-property:none!important;}"
         "';"
         /* v7.95: the same compact REC frame retained data-ad7-twb-child but
          * lost the early ad7-twb-static node. Re-attach it once at load. */
         "function ad7RelinkTWB(){try{if(s&&!s.isConnected)(document.head||document.documentElement).appendChild(s)}catch(_){}}"
         "if(document.readyState==='loading')window.addEventListener('load',ad7RelinkTWB,{once:true});else ad7RelinkTWB();"
         "}catch(e){}})();",factor,shade];
}


static NSString *ADPrivacyModeJS7117(void){
    return
        @"(function(){\n"
        @"try{\n"
        @"  if(window.__adPrivacy7117Installed){window.__adPrivacy7117Enabled=true;return;}\n"
        @"  window.__adPrivacy7117Installed=1;\n"
        @"  window.__adPrivacy7117Enabled=true;\n"
        @"  var MAX=320, ev=[], counts=Object.create(null), dropped=0, t0=Date.now(), xhrMeta=new WeakMap();\n"
        @"  function clean(v,n){try{return String(v==null?'':v).replace(/\\s+/g,' ').slice(0,n||180)}catch(_){return ''}}\n"
        @"  function parse(u){try{return new URL(String(u&&u.url?u.url:u||''),location.href)}catch(_){return null}}\n"
        @"  function catHost(h){\n"
        @"    h=String(h||'').toLowerCase();\n"
        @"    if(h==='unagi.amazon.com'||h==='unagi-na.amazon.com')return 'unagi';\n"
        @"    if(h==='fls-na.amazon.com')return 'fls';\n"
        @"    if(h==='api.mshop.bdtelemetry.amazon')return 'bdtelemetry';\n"
        @"    if(h==='session.mshopbugsnag.irm.amazon.dev'||h==='trace.mshopbugsnag.irm.amazon.dev')return 'bugsnag';\n"
        @"    if(h==='vfw.amazon-adsystem.com')return 'ad-viewability';\n"
        @"    if(h.endsWith('.service.minerva.devices.a2z.com'))return 'minerva';\n"
        @"    if(/^api\\.stores\\.[^.]+\\.prod\\.paets\\.advertising\\.amazon\\.dev$/.test(h))return 'ad-event';\n"
        @"    if(/^aes\\..*\\.amazon-adsystem\\.com$/.test(h))return 'ad-instrumentation';\n"
        @"    return '';\n"
        @"  }\n"
        @"  function info(u){var x=parse(u),h=x?x.hostname.toLowerCase():'',c=catHost(h),p=x?(x.pathname||'/'):'';if(p.length>140)p=p.slice(0,140)+'…';return {blocked:!!c,category:c,host:h,path:p,url:x?(x.protocol+'//'+x.host+p):clean(u,180)}}\n"
        @"  function sizeOf(v){try{if(v==null)return null;if(typeof v==='string')return v.length;if(typeof v.size==='number')return v.size;if(typeof v.byteLength==='number')return v.byteLength;if(typeof URLSearchParams!=='undefined'&&v instanceof URLSearchParams)return String(v).length}catch(_){}return null}\n"
        @"  function inc(k){counts[k]=(counts[k]||0)+1}\n"
        @"  function rec(kind,i,extra){try{inc(kind);if(i&&i.category)inc('category.'+i.category);if(i&&i.host)inc('host.'+i.host);if(ev.length<MAX){var d={ms:Date.now()-t0,kind:kind,category:i&&i.category||'',host:i&&i.host||'',path:i&&i.path||''};if(extra)for(var k in extra)d[k]=extra[k];ev.push(d)}else dropped++}catch(_){}}\n"
        @"  function fakeResponse(url){try{return new Response(null,{status:204,statusText:'No Content',headers:{'Cache-Control':'no-store','X-AmazonDark-Privacy':'1'}})}catch(_){return {ok:true,status:204,statusText:'No Content',url:String(url||''),text:function(){return Promise.resolve('')},json:function(){return Promise.resolve({})},arrayBuffer:function(){return Promise.resolve(new ArrayBuffer(0))}}}}\n"
        @"\n"
        @"  try{\n"
        @"    var osb=navigator.sendBeacon;\n"
        @"    if(typeof osb==='function')navigator.sendBeacon=function(url,data){\n"
        @"      var i=info(url); if(window.__adPrivacy7117Enabled&&i.blocked){var n=null;try{if(typeof data==='string')n=data.length;else if(data&&typeof data.size==='number')n=data.size;else if(data&&typeof data.byteLength==='number')n=data.byteLength}catch(_){}rec('blocked.sendBeacon',i,{payloadBytes:n});return true;} return osb.apply(this,arguments);\n"
        @"    };\n"
        @"  }catch(_){}\n"
        @"\n"
        @"  try{\n"
        @"    var of=window.fetch;\n"
        @"    if(typeof of==='function')window.fetch=function(input,init){var i=info(input);if(window.__adPrivacy7117Enabled&&i.blocked){rec('blocked.fetch',i,{method:clean(init&&init.method||input&&input.method||'GET',16),payloadBytes:sizeOf(init&&init.body)});return Promise.resolve(fakeResponse(i.url));}return of.apply(this,arguments)};\n"
        @"  }catch(_){}\n"
        @"\n"
        @"  try{\n"
        @"    var xo=XMLHttpRequest.prototype.open, xs=XMLHttpRequest.prototype.send;\n"
        @"    XMLHttpRequest.prototype.open=function(method,url){try{xhrMeta.set(this,{method:clean(method||'GET',16),i:info(url)})}catch(_){}return xo.apply(this,arguments)};\n"
        @"    XMLHttpRequest.prototype.send=function(){var m=null;try{m=xhrMeta.get(this)}catch(_){};if(window.__adPrivacy7117Enabled&&m&&m.i&&m.i.blocked){\n"
        @"      rec('blocked.xhr',m.i,{method:m.method,payloadBytes:sizeOf(arguments[0])}); var self=this;\n"
        @"      try{Object.defineProperty(self,'readyState',{configurable:true,get:function(){return 4}})}catch(_){}\n"
        @"      try{Object.defineProperty(self,'status',{configurable:true,get:function(){return 204}})}catch(_){}\n"
        @"      try{Object.defineProperty(self,'statusText',{configurable:true,get:function(){return 'No Content'}})}catch(_){}\n"
        @"      try{Object.defineProperty(self,'responseURL',{configurable:true,get:function(){return m.i.url}})}catch(_){}\n"
        @"      try{Object.defineProperty(self,'responseText',{configurable:true,get:function(){return ''}})}catch(_){}\n"
        @"      try{Object.defineProperty(self,'response',{configurable:true,get:function(){return ''}})}catch(_){}\n"
        @"      Promise.resolve().then(function(){try{self.dispatchEvent(new Event('readystatechange'));self.dispatchEvent(new Event('load'));self.dispatchEvent(new Event('loadend'))}catch(_){}});\n"
        @"      return;\n"
        @"    }return xs.apply(this,arguments)};\n"
        @"  }catch(_){}\n"
        @"\n"
        @"  function residual(){var m=Object.create(null),a=[];try{a=performance.getEntriesByType('resource')||[]}catch(_){};for(var j=0;j<a.length;j++){try{var i=info(a[j].name);if(!i.blocked)continue;var key=i.category+'|'+i.host+'|'+String(a[j].initiatorType||'other');m[key]=(m[key]||0)+1}catch(_){}}var o=[];Object.keys(m).sort(function(a,b){return m[b]-m[a]}).forEach(function(k){var z=k.split('|');o.push({category:z[0],host:z[1],initiator:z[2],count:m[k]})});return o}\n"
        @"  function report(){return JSON.stringify({frame:{href:(function(){var i=info(location.href);return i.url})(),child:(function(){try{return top!==window}catch(_){return true}})(),ready:document.readyState},installed:!!window.__adPrivacy7117Installed,enabled:!!window.__adPrivacy7117Enabled,sinceMs:Date.now()-t0,dropped:dropped,counts:counts,blockedEvents:ev,residualTelemetryResources:residual()},null,2)}\n"
        @"  function frames(){var out=[];try{var a=document.getElementsByTagName('iframe');for(var i=0;i<a.length&&out.length<32;i++)out.push(a[i])}catch(_){}return out}\n"
        @"  window.__adPrivacy7117Report=report;\n"
        @"  window.__adPrivacy7117Broadcast=function(msg){try{var a=frames();for(var i=0;i<a.length;i++)try{a[i].contentWindow.postMessage(msg,'*')}catch(_){}}catch(_){}};\n"
        @"  window.addEventListener('message',function(e){try{var d=e.data;if(!d)return;if(d.__adPrivacy7117Toggle===1){window.__adPrivacy7117Enabled=!!d.enabled;try{window.__adPrivacy7117Broadcast(d)}catch(_){}return;}if(d.__adPrivacy7117!==1||!d.nonce)return;try{top.postMessage({__adPrivacy7117Result:1,nonce:d.nonce,href:location.href,report:report()},'*')}catch(_){}try{window.__adPrivacy7117Broadcast(d)}catch(_){}}catch(_){}},false);\n"
        @"}catch(e){}\n"
        @"})();\n"
        ;
}


static void ADTrackWebView(WKWebView *wv){
    if(!wv)return; @try { @synchronized([WKWebView class]) { if(!gADWebViews)gADWebViews=[NSHashTable weakObjectsHashTable]; [gADWebViews addObject:wv]; } } @catch(...) {}
}
static NSArray *ADTrackedWebViews(void){
    @try { @synchronized([WKWebView class]) { return gADWebViews?gADWebViews.allObjects:@[]; } } @catch(...) {}
    return @[];
}

static WKContentRuleList *gADPrivacyRuleList7117=nil;
static NSString *gADPrivacyRuleError7117=nil;
static BOOL gADPrivacyRuleCompilePending7117=NO;

static NSString *ADPrivacyContentRules7117(void){
    // v7.118: keep the Content Blocker regexes deliberately simple. The v7.117
    // list used several compound host expressions and failed compilation on the
    // target WebKit with WKErrorContentRuleListStoreCompileFailed. These filters
    // use only the documented WebKit Content Blocker regex subset.
    return @"["
    @"{\"trigger\":{\"url-filter\":\"unagi\\\\.amazon\\\\.com/\"},\"action\":{\"type\":\"block\"}},"
    @"{\"trigger\":{\"url-filter\":\"unagi-na\\\\.amazon\\\\.com/\"},\"action\":{\"type\":\"block\"}},"
    @"{\"trigger\":{\"url-filter\":\"fls-na\\\\.amazon\\\\.com/\"},\"action\":{\"type\":\"block\"}},"
    @"{\"trigger\":{\"url-filter\":\"service\\\\.minerva\\\\.devices\\\\.a2z\\\\.com/\"},\"action\":{\"type\":\"block\"}},"
    @"{\"trigger\":{\"url-filter\":\"mshopbugsnag\\\\.irm\\\\.amazon\\\\.dev/\"},\"action\":{\"type\":\"block\"}},"
    @"{\"trigger\":{\"url-filter\":\"api\\\\.mshop\\\\.bdtelemetry\\\\.amazon/\"},\"action\":{\"type\":\"block\"}},"
    @"{\"trigger\":{\"url-filter\":\"prod\\\\.paets\\\\.advertising\\\\.amazon\\\\.dev/\"},\"action\":{\"type\":\"block\"}},"
    @"{\"trigger\":{\"url-filter\":\"aes\\\\..*\\\\.amazon-adsystem\\\\.com/\"},\"action\":{\"type\":\"block\"}},"
    @"{\"trigger\":{\"url-filter\":\"vfw\\\\.amazon-adsystem\\\\.com/\"},\"action\":{\"type\":\"block\"}}"
    @"]";
}
static void ADAttachPrivacyContentRule7117(WKUserContentController *ucc){
    if(!ucc||!gP.enabled||!gP.privacyMode||!gADPrivacyRuleList7117)return;
    @try {
        if(!objc_getAssociatedObject(ucc,kADPrivacyRule7117)){
            [ucc addContentRuleList:gADPrivacyRuleList7117];
            objc_setAssociatedObject(ucc,kADPrivacyRule7117,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } @catch(...) {}
}
static void ADCompilePrivacyContentRules7117(void){
    if(!gP.enabled||!gP.privacyMode||gADPrivacyRuleList7117||gADPrivacyRuleCompilePending7117)return;
    gADPrivacyRuleCompilePending7117=YES;
    [[WKContentRuleListStore defaultStore] compileContentRuleListForIdentifier:@"AmazonDarkPrivacy7118" encodedContentRuleList:ADPrivacyContentRules7117() completionHandler:^(WKContentRuleList *list,NSError *error){
        gADPrivacyRuleCompilePending7117=NO;
        if(!list){
            gADPrivacyRuleError7117=[NSString stringWithFormat:@"code=%ld %@ userInfo=%@",(long)error.code,error.localizedDescription?:@"compile failed",error.userInfo?:@{}];
            return;
        }
        gADPrivacyRuleList7117=list; gADPrivacyRuleError7117=nil;
        dispatch_async(dispatch_get_main_queue(),^{
            for(WKWebView *wv in ADTrackedWebViews()){
                @try { ADAttachPrivacyContentRule7117(wv.configuration.userContentController); } @catch(...) {}
            }
        });
    }];
}
static void ADSetLoadedWebPrivacyEnabled7117(BOOL on){
    NSString *js=[NSString stringWithFormat:@"(function(){try{window.__adPrivacy7117Enabled=%@;if(window.__adPrivacy7117Broadcast)window.__adPrivacy7117Broadcast({__adPrivacy7117Toggle:1,enabled:%@});}catch(e){}})();",on?@"true":@"false",on?@"true":@"false"];
    for(WKWebView *wv in ADTrackedWebViews()){
        if(!wv)continue;
        @try { [wv evaluateJavaScript:js completionHandler:nil]; } @catch(...) {}
        if(!on&&gADPrivacyRuleList7117){
            @try { [wv.configuration.userContentController removeContentRuleList:gADPrivacyRuleList7117]; objc_setAssociatedObject(wv.configuration.userContentController,kADPrivacyRule7117,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); } @catch(...) {}
        }
    }
}


// v7.91: preference changes immediately refresh the currently loaded main
// documents. This is a one-shot settings action, not an observer/scan loop.
// A respring/relaunch still gives document-start coverage to all future frames.
static NSString *ADTWBClearJS791(void){
    return @"(function(){try{var s=document.getElementById('ad7-twb-static');if(s)s.remove();if(document.documentElement)document.documentElement.removeAttribute('data-ad7-twb-child');}catch(e){}})();";
}
static void ADRefreshWebTWBPrefs791(void){
    NSString *js=(gP.enabled&&gP.whiteTame)?ADTWBJS():ADTWBClearJS791();
    for(WKWebView *wv in ADTrackedWebViews()){
        if(!wv)continue;
        @try { [wv evaluateJavaScript:js completionHandler:nil]; } @catch(...) {}
    }
}

static void ADAttachScriptsToUCC710(WKUserContentController *ucc){
    if(!ucc || !gP.enabled)return;
    @try {
        if(!objc_getAssociatedObject(ucc,kADFloorUS)){
            WKUserScript *us=[[WKUserScript alloc] initWithSource:ADFloorJS() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
            [ucc addUserScript:us];
            objc_setAssociatedObject(ucc,kADFloorUS,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if(!objc_getAssociatedObject(ucc,kADStandalonePaintUS7104)){
            WKUserScript *us=[[WKUserScript alloc] initWithSource:ADStandalonePaintJS7104() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
            [ucc addUserScript:us];
            objc_setAssociatedObject(ucc,kADStandalonePaintUS7104,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if(gP.whiteTame && !objc_getAssociatedObject(ucc,kADTWBUS)){
            WKUserScript *us=[[WKUserScript alloc] initWithSource:ADTWBJS() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
            [ucc addUserScript:us];
            objc_setAssociatedObject(ucc,kADTWBUS,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if(gP.privacyMode && !objc_getAssociatedObject(ucc,kADPrivacyUS7117)){
            WKUserScript *us=[[WKUserScript alloc] initWithSource:ADPrivacyModeJS7117() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
            [ucc addUserScript:us];
            objc_setAssociatedObject(ucc,kADPrivacyUS7117,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        ADAttachPrivacyContentRule7117(ucc);
    } @catch(...) {}
}
static void ADAttachWebScripts(WKWebView *wv){
    if(!wv || !gP.enabled)return; ADTrackWebView(wv);
    @try { ADAttachScriptsToUCC710(wv.configuration.userContentController); } @catch(...) {}
}
static void ADApplyWebFloor(WKWebView *wv){
    if(!wv || !gP.enabled)return;
    ADTrackWebView(wv);
    @try {
        // Prime only the outer WebKit backing. Do not intercept WebKit's later background
        // assignments and do not repeatedly evaluate theme JS during view recycling/snapshots.
        wv.opaque=NO;
        wv.backgroundColor=ADOLED();
        wv.scrollView.opaque=NO;
        wv.scrollView.backgroundColor=ADOLED();
        if(@available(iOS 15.0,*)) wv.underPageBackgroundColor=ADOLED();
    } @catch(...) {}
}


static BOOL ADPrimaryAmazonWindow713(UIWindow *w, UIViewController *candidate);

// -----------------------------------------------------------------------------
static void ADApplyAllFloors(void){
    if(!gP.enabled)return;
    @try {
        for(WKWebView *wv in ADTrackedWebViews()) if(wv.window) ADApplyWebFloor(wv);
    } @catch(...) {}
}

// v7.115: one main-thread handoff owns launch/prefs refresh work. At process
// startup Logos normally enters on the main thread, so this runs inline; a
// Darwin prefs callback arriving off-main uses the single guarded dispatch.
static void ADRefreshRuntimeState7115(BOOL refreshTWB){
    void (^work)(void)=^{
        ADApplyAllFloors();
        ADRefreshPromotionState611();
        if(refreshTWB) ADRefreshWebTWBPrefs791();
    };
    if([NSThread isMainThread]) work();
    else dispatch_async(dispatch_get_main_queue(),work);
}

%hook WKWebViewConfiguration
- (instancetype)init {
    id cfg=%orig;
    if(gP.enabled && cfg){
        @try { ADAttachScriptsToUCC710(((WKWebViewConfiguration *)cfg).userContentController); } @catch(...) {}
    }
    return cfg;
}
%end

// Amazon replaces/clears its WKUserContentController during cold navigation.
// v5/v6 explicitly restored AmazonDark's documentStart scripts after removeAllUserScripts;
// without this, cold Home/Search can miss the OLED sheet until a warm lifecycle reapply.
%hook WKUserContentController
- (void)removeAllUserScripts {
    %orig;
    if(gP.enabled){
        objc_setAssociatedObject(self,kADFloorUS,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self,kADTWBUS,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self,kADStandalonePaintUS7104,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self,kADPrivacyUS7117,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADAttachScriptsToUCC710(self);
    }
}
- (void)removeAllContentRuleLists {
    %orig;
    objc_setAssociatedObject(self,kADPrivacyRule7117,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(gP.enabled&&gP.privacyMode){ ADCompilePrivacyContentRules7117(); ADAttachPrivacyContentRule7117(self); }
}
%end

%hook WKWebView
- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    if(gP.enabled && configuration){
        @try { ADAttachScriptsToUCC710(configuration.userContentController); } @catch(...) {}
    }
    id wv=%orig;
    if(gP.enabled){ ADAttachWebScripts(wv); ADApplyWebFloor(wv); }
    return wv;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    id wv=%orig;
    if(gP.enabled){ ADAttachWebScripts(wv); ADApplyWebFloor(wv); }
    return wv;
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled && self.window){ ADAttachWebScripts(self); ADApplyWebFloor(self); ADConsiderLaunchReady706(); }
}
%end

%hook WKScrollView
- (void)didMoveToWindow {
    %orig;
    /* v7.0.79: keep the proven white native scrollbar while refusing to style
     * WKChildScrollView carousel descendants. Sponsor glyph ownership above is
     * now declarative, so it no longer depends on hydration timing. */
    if(gP.enabled && self.window && strcmp(object_getClassName(self), "WKScrollView")==0){
        self.opaque=NO;
        self.backgroundColor=ADOLED();
        self.indicatorStyle=UIScrollViewIndicatorStyleWhite;
    }
}
- (void)setIndicatorStyle:(UIScrollViewIndicatorStyle)style {
    if(gP.enabled && strcmp(object_getClassName(self), "WKScrollView")==0){
        %orig(UIScrollViewIndicatorStyleWhite);
        return;
    }
    %orig(style);
}
%end

%hook WKContentView
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled && self.window){
        self.opaque=YES;
        self.backgroundColor=ADOLED();
        self.layer.backgroundColor=ADOLED().CGColor;
    }
}
- (void)layoutSubviews {
    %orig;
    if(gP.enabled && self.window){
        self.opaque=YES;
        self.backgroundColor=ADOLED();
        self.layer.backgroundColor=ADOLED().CGColor;
    }
}
%end

static const void *kADReactCard708=&kADReactCard708;
static BOOL ADNativeFloorCandidate(UIView *v){
    if(!v)return NO;
    @try { return objc_getAssociatedObject(v,kADReactCard708)!=nil; } @catch(...) {}
    return NO;
}
static void ADOwnNativeFloor(UIView *v){
    if(!gP.enabled || !v)return; @try { v.backgroundColor=ADOLED(); v.layer.backgroundColor=ADOLED().CGColor; } @catch(...) {}
}


static UIColor *ADLightText706(void);

// v7.0.24 — v6.0.185 tab-rendering mechanism, narrowed to the current ANX tab bar.
// Current requested palette: all tab glyphs white + selected indicator white.
static const void *kADTabIndicator724=&kADTabIndicator724;
static BOOL gADTabImageWriting724=NO;

static UIView *ADANXTabRoot724(UIView *v){
    if(!v)return nil;
    @try {
        UIView *n=v;
        for(int d=0;n&&d<12;d++,n=n.superview){
            NSString *c=NSStringFromClass(n.class);
            if([c containsString:@"ANXTabBarView"])return n;
        }
    } @catch(...) {}
    return nil;
}
static BOOL ADTabImageTemplateish724(UIImage *im){
    if(!im)return NO;
    if(im.renderingMode==UIImageRenderingModeAlwaysTemplate)return YES;
    @try {
        CGImageRef cg=im.CGImage;
        if(cg && (CGImageIsMask(cg)||CGImageGetAlphaInfo(cg)==kCGImageAlphaOnly))return YES;
        if(im.symbolConfiguration!=nil)return YES;
    } @catch(...) {}
    return NO;
}
static void ADTabImageWhite724(UIImageView *iv){
    if(!gP.enabled||!iv||!iv.window||!ADANXTabRoot724(iv))return;
    @try {
        UIImage *im=iv.image;
        if(im && !ADTabImageTemplateish724(im) && !gADTabImageWriting724){
            UIImage *tpl=[im imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            if(tpl){
                gADTabImageWriting724=YES;
                iv.image=tpl;
                gADTabImageWriting724=NO;
            }
        }
        UIColor *white=ADLightText706();
        [UIView performWithoutAnimation:^{ iv.tintColor=white; }];
    } @catch(...) { gADTabImageWriting724=NO; }
}
static void ADPaintANXTabTree724(UIView *v,int depth){
    if(!gP.enabled||!v||depth>10||v.hidden||v.alpha<0.02)return;
    @try {
        if([v isKindOfClass:[UIImageView class]]){
            ADTabImageWhite724((UIImageView *)v);
        } else {
            CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
            if(h>0.0&&h<8.0&&w>12.0&&w<160.0&&
               ![v isKindOfClass:[UIControl class]]&&
               ![v isKindOfClass:[UILabel class]]){
                objc_setAssociatedObject(v,kADTabIndicator724,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                UIColor *white=ADLightText706();
                v.backgroundColor=white;
                v.layer.backgroundColor=white.CGColor;
            }
            if(w>2&&h>2&&w<100&&h<100){
                UIColor *white=ADLightText706();
                v.tintColor=white;
            }
        }
        for(UIView *child in v.subviews)ADPaintANXTabTree724(child,depth+1);
    } @catch(...) {}
}
static void ADPaintANXTabBar724(UIView *root){
    if(!gP.enabled||!root||!root.window)return;
    @try {
        root.backgroundColor=ADOLED();
        root.layer.backgroundColor=ADOLED().CGColor;
        ADPaintANXTabTree724(root,0);
    } @catch(...) {}
}
static void ADRepaintNearestANXTab724(UIView *v){
    UIView *root=ADANXTabRoot724(v);
    if(root)ADPaintANXTabBar724(root);
}

%hook UIView
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled && self.window && ADNativeFloorCandidate(self)) ADOwnNativeFloor(self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled && objc_getAssociatedObject(self,kADTabIndicator724)){
        UIColor *white=ADLightText706();
        %orig(white);
        return;
    }
    if(gP.enabled && self.window && ADNativeFloorCandidate(self)){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
%end

static BOOL ADTopChromeClass713(UIView *v){
    if(!v)return NO;
    @try {
        UIView *n=v;
        for(int d=0;n&&d<10;d++,n=n.superview){
            NSString *c=NSStringFromClass(n.class).lowercaseString?:@"";
            if([c containsString:@"anxtopnav"]||[c containsString:@"topmainbar"]||[c containsString:@"statusbarinset"]||[c containsString:@"topnav"]) return YES;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADBarGeometry713(UIView *v, BOOL *isBottom){
    if(isBottom)*isBottom=NO; if(!v||!v.window)return NO;
    @try {
        CGRect r=[v convertRect:v.bounds toView:v.window]; CGRect b=v.window.bounds;
        if(b.size.width<1||r.size.width<b.size.width*0.82||r.size.height<1||r.size.height>190)return NO;
        if(CGRectGetMinY(r)<190)return YES;
        if(CGRectGetMaxY(r)>b.size.height-150){ if(isBottom)*isBottom=YES; return YES; }
    } @catch(...) {}
    return NO;
}
static BOOL ADPrimaryAmazonController713(UIViewController *vc){
    if(!vc)return NO;
    @try {
        NSString *n=NSStringFromClass(vc.class).lowercaseString?:@"";
        return [n containsString:@"anpdockedtabbar"]||[n containsString:@"anxtabroot"]||
               [n containsString:@"anxtopmainbar"]||[n containsString:@"anxsubnav"]||
               [n containsString:@"anxvisualsubnav"]||[n containsString:@"sxwebresults"]||
               [n containsString:@"anptopnav"]||[n containsString:@"cxistatusbarinset"];
    } @catch(...) {}
    return NO;
}
static BOOL ADPrimaryAmazonWindow713(UIWindow *w, UIViewController *candidate){
    if(!w)return NO;
    @try {
        if(fabs(w.windowLevel-UIWindowLevelNormal)>0.1)return NO;
        UIViewController *vc=candidate?:w.rootViewController;
        if(ADPrimaryAmazonController713(vc))return YES;
        NSString *n=NSStringFromClass(vc.class).lowercaseString?:@"";
        return [n containsString:@"splash"]||[n containsString:@"launchscreen"];
    } @catch(...) {}
    return NO;
}

static NSMutableDictionary *gADStatusOrig713;
static UIStatusBarStyle ADStatusLightIMP713(id self, SEL _cmd){
    if(gP.enabled)return UIStatusBarStyleLightContent;
    @try {
        NSValue *v=gADStatusOrig713[NSStringFromClass([self class])];
        IMP imp=NULL;
        if(v) [v getValue:&imp];
        if(imp)return ((UIStatusBarStyle(*)(id,SEL))imp)(self,_cmd);
    } @catch(...) {}
    return UIStatusBarStyleDefault;
}
static void ADClaimStatusController713(UIViewController *vc){
    if(!vc)return;
    @try {
        Class cls=vc.class; NSString *key=NSStringFromClass(cls);
        if(!gADStatusOrig713)gADStatusOrig713=[NSMutableDictionary dictionary];
        @synchronized(gADStatusOrig713){
            if(!gADStatusOrig713[key]){
                SEL sel=@selector(preferredStatusBarStyle); Method m=class_getInstanceMethod(cls,sel);
                IMP orig=m?method_getImplementation(m):NULL;
                if(orig==(IMP)ADStatusLightIMP713)return;
                const char *types=m?method_getTypeEncoding(m):"q@:";
                gADStatusOrig713[key]=[NSValue value:&orig withObjCType:@encode(IMP)];
                if(!class_addMethod(cls,sel,(IMP)ADStatusLightIMP713,types)) class_replaceMethod(cls,sel,(IMP)ADStatusLightIMP713,types);
            }
        }
        [vc setNeedsStatusBarAppearanceUpdate];
    } @catch(...) {}
}

static UIColor *ADLightText706(void){ return [UIColor colorWithRed:232.0/255.0 green:230.0/255.0 blue:227.0/255.0 alpha:1.0]; }
static UIColor *ADBorderGray706(void){ return [UIColor colorWithRed:73.0/255.0 green:77.0/255.0 blue:77.0/255.0 alpha:1.0]; }
static BOOL ADNeutralCGColor706(CGColorRef c){
    if(!c)return NO;
    @try { UIColor *u=[UIColor colorWithCGColor:c]; CGFloat r=0,g=0,b=0,a=0,w=0;
        if([u getRed:&r green:&g blue:&b alpha:&a]) return a>0.05 && (MAX(r,MAX(g,b))-MIN(r,MIN(g,b)))<0.16;
        if([u getWhite:&w alpha:&a]) return a>0.05;
    } @catch(...) {}
    return NO;
}
static BOOL ADInBottomNav706(UIView *v){
    @try { UIView *n=v; for(int d=0;n&&d<12;d++,n=n.superview){
        NSString *c=NSStringFromClass(n.class).lowercaseString ?: @"";
        if([c containsString:@"bottomnav"]||[c containsString:@"tabbar"]||[c containsString:@"navtoolbar"]||[c containsString:@"storemodestab"]) return YES;
    }} @catch(...) {}
    return NO;
}
static BOOL ADInSearchChrome706(UIView *v){
    @try { UIView *n=v; for(int d=0;n&&d<10;d++,n=n.superview){
        NSString *c=NSStringFromClass(n.class).lowercaseString ?: @"";
        if([c containsString:@"sbsearchbar"]||[c containsString:@"sbsearchfield"]||
           [c containsString:@"sbmultilinesearchview"]||[c containsString:@"searchbar"]||
           [c containsString:@"searchfield"]||[c containsString:@"scanitsearchwidget"]) return YES;
    }} @catch(...) {}
    return NO;
}
static BOOL ADIsSearchBackGlyph7120(UIView *v){
    if(!v)return NO;
    @try {
        UIView *n=v;
        for(int d=0;n&&d<7;d++,n=n.superview){
            NSString *aid=(n.accessibilityIdentifier?:@"").lowercaseString;
            NSString *lab=(n.accessibilityLabel?:@"").lowercaseString;
            if([aid isEqualToString:@"nav_back_button"] ||
               ([aid containsString:@"back"]&&[aid containsString:@"nav"]) ||
               ([lab isEqualToString:@"back"]&&[NSStringFromClass(n.class).lowercaseString containsString:@"button"])) return YES;
        }
    } @catch(...) {}
    return NO;
}
static BOOL gADSearchImageWrite706=NO;
static UIColor *ADSearchChromeFill7045(void){
    // One dark neutral for both the search pill and location circle.
    return [UIColor colorWithRed:48.0/255.0 green:51.0/255.0 blue:53.0/255.0 alpha:1.0];
}
static BOOL ADIsLocationGlyph709(UIImageView *iv){
    if(!iv)return NO;
    @try {
        NSMutableString *q=[NSMutableString string];
        if(iv.accessibilityLabel)[q appendFormat:@" %@",iv.accessibilityLabel];
        if(iv.accessibilityIdentifier)[q appendFormat:@" %@",iv.accessibilityIdentifier];
        UIView *n=iv;
        for(int d=0;n&&d<5;d++,n=n.superview){
            [q appendFormat:@" %@ %@ %@",NSStringFromClass(n.class),n.accessibilityLabel?:@"",n.accessibilityIdentifier?:@""];
        }
        NSString *l=q.lowercaseString;
        return [l containsString:@"location"] || [l containsString:@"delivery"] || [l containsString:@"address"] || [l containsString:@"map pin"] || [l containsString:@"pin icon"];
    } @catch(...) {}
    return NO;
}
static void ADTintSearchGlyph706(UIImageView *iv){
    if(!gP.enabled||!iv||!iv.image)return;
    BOOL search=ADInSearchChrome706(iv), location=ADIsLocationGlyph709(iv), back=ADIsSearchBackGlyph7120(iv);
    if(!search&&!location&&!back)return;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height; if(w<3||h<3||w>64||h>64)return;
        UIImage *im=iv.image;
        if(im.renderingMode!=UIImageRenderingModeAlwaysTemplate && !gADSearchImageWrite706){
            UIImage *tpl=[im imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            if(tpl){ gADSearchImageWrite706=YES; iv.image=tpl; gADSearchImageWrite706=NO; }
        }
        iv.tintColor=ADLightText706();
    } @catch(...) { gADSearchImageWrite706=NO; }
}

static BOOL gADSearchKeyboardActive7121=NO;
static BOOL gADKeyboardBGWrite7121=NO;
static __weak UIView *gADKeyboardContainer7121=nil;
static __weak UIView *gADKeyboardHost7121=nil;
static __weak UIView *gADKeyboardPlaceholder7121=nil;
static const void *kADKeyboardOrigBG7121=&kADKeyboardOrigBG7121;
static NSString *const kADKeyboardFilterName7121=@"AmazonDarkOLEDKeyboard7121";

static id ADKeyboardOLEDFilter7121(void){
    static id filter=nil; static dispatch_once_t once;
    dispatch_once(&once,^{
        @try {
            Class c=NSClassFromString(@"CAFilter");
            SEL make=NSSelectorFromString(@"filterWithType:");
            if(!c||![c respondsToSelector:make])return;
            id f=((id(*)(id,SEL,id))objc_msgSend)(c,make,@"colorMatrix");
            if(!f)return;
            [f setValue:kADKeyboardFilterName7121 forKey:@"name"];
            /* Stock dark keyboard: floor ~= 0.17, keys ~= 0.35. This affine map
             * sends the floor to black while retaining separated gray keys and
             * clipping light labels back to white. */
            ADCAColorMatrix7121 m={
                1.70f,0,0,0,-0.29f,
                0,1.70f,0,0,-0.29f,
                0,0,1.70f,0,-0.29f,
                0,0,0,1,0
            };
            if([NSValue respondsToSelector:@selector(valueWithCAColorMatrix:)]){
                [f setValue:[NSValue valueWithCAColorMatrix:m] forKey:@"inputColorMatrix"];
            }
            filter=f;
        } @catch(...) { filter=nil; }
    });
    return filter;
}
static BOOL ADKeyboardLayerHasFilter7121(CALayer *layer){
    if(!layer)return NO;
    @try {
        NSArray *fs=[layer valueForKey:@"filters"];
        for(id f in fs){ NSString *n=nil; @try { n=[f valueForKey:@"name"]; } @catch(...) {} if([n isEqualToString:kADKeyboardFilterName7121])return YES; }
    } @catch(...) {}
    return NO;
}
static void ADKeyboardSaveBG7121(UIView *v){
    if(!v||objc_getAssociatedObject(v,kADKeyboardOrigBG7121))return;
    @try { objc_setAssociatedObject(v,kADKeyboardOrigBG7121,v.backgroundColor?:[NSNull null],OBJC_ASSOCIATION_RETAIN_NONATOMIC); } @catch(...) {}
}
static void ADKeyboardPaintLocal7121(UIView *v,BOOL addFilter){
    if(!v||!gP.enabled||!gADSearchKeyboardActive7121)return;
    @try {
        ADKeyboardSaveBG7121(v);
        UIColor *black=ADOLED();
        gADKeyboardBGWrite7121=YES;
        v.backgroundColor=black;
        v.layer.backgroundColor=black.CGColor;
        gADKeyboardBGWrite7121=NO;
        if(addFilter&&!ADKeyboardLayerHasFilter7121(v.layer)){
            id f=ADKeyboardOLEDFilter7121();
            if(f){
                NSMutableArray *a=[NSMutableArray array];
                NSArray *old=[v.layer valueForKey:@"filters"]; if(old)[a addObjectsFromArray:old];
                [a addObject:f]; [v.layer setValue:a forKey:@"filters"];
            }
        }
    } @catch(...) { gADKeyboardBGWrite7121=NO; }
}
static void ADKeyboardRestoreLocal7121(UIView *v){
    if(!v)return;
    @try {
        NSMutableArray *a=[NSMutableArray array]; NSArray *old=[v.layer valueForKey:@"filters"];
        for(id f in old){ NSString *n=nil; @try { n=[f valueForKey:@"name"]; } @catch(...) {} if(![n isEqualToString:kADKeyboardFilterName7121])[a addObject:f]; }
        [v.layer setValue:(a.count?a:nil) forKey:@"filters"];
        id orig=objc_getAssociatedObject(v,kADKeyboardOrigBG7121);
        UIColor *bg=(orig&&orig!=[NSNull null])?orig:nil;
        gADKeyboardBGWrite7121=YES; v.backgroundColor=bg; v.layer.backgroundColor=bg.CGColor; gADKeyboardBGWrite7121=NO;
        objc_setAssociatedObject(v,kADKeyboardOrigBG7121,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) { gADKeyboardBGWrite7121=NO; }
}
static void ADKeyboardReassert7121(void){
    if(!gP.enabled||!gADSearchKeyboardActive7121)return;
    ADKeyboardPaintLocal7121(gADKeyboardContainer7121,NO);
    ADKeyboardPaintLocal7121(gADKeyboardHost7121,YES);
    ADKeyboardPaintLocal7121(gADKeyboardPlaceholder7121,NO);
}
static void ADKeyboardDeactivate7121(void){
    gADSearchKeyboardActive7121=NO;
    ADKeyboardRestoreLocal7121(gADKeyboardContainer7121);
    ADKeyboardRestoreLocal7121(gADKeyboardHost7121);
    ADKeyboardRestoreLocal7121(gADKeyboardPlaceholder7121);
}
static void ADPrepareSearchKeyboard7120(UIView *v){
    if(!gP.enabled||!v||!ADInSearchChrome706(v))return;
    gADSearchKeyboardActive7121=YES;
    @try {
        SEL sel=NSSelectorFromString(@"setKeyboardAppearance:");
        if([v respondsToSelector:sel]) ((void(*)(id,SEL,NSInteger))objc_msgSend)(v,sel,(NSInteger)UIKeyboardAppearanceDark);
    } @catch(...) {}
    ADKeyboardReassert7121();
}

static NSAttributedString *ADLightAttributedText708(NSAttributedString *in){
    if(!gP.enabled || !in || in.length==0) return in;
    @try {
        NSMutableAttributedString *m=[in mutableCopy];
        NSRange full=NSMakeRange(0,m.length);
        UIColor *light=ADLightText706();
        [m enumerateAttribute:NSForegroundColorAttributeName inRange:full options:0 usingBlock:^(id value,NSRange range,BOOL *stop){
            [m addAttribute:NSForegroundColorAttributeName value:light range:range];
        }];
        return m;
    } @catch(...) { return in; }
}
static BOOL ADBrightNeutralUIView708(UIView *v){
    if(!v)return NO;
    @try {
        UIColor *u=v.backgroundColor; if(!u)return NO;
        CGFloat r=0,g=0,b=0,a=0,w=0;
        if([u getRed:&r green:&g blue:&b alpha:&a]){
            CGFloat mx=MAX(r,MAX(g,b)),mn=MIN(r,MIN(g,b));
            return a>0.15 && mx>0.72 && (mx-mn)<0.18;
        }
        if([u getWhite:&w alpha:&a]) return a>0.15 && w>0.72;
    } @catch(...) {}
    return NO;
}
static void ADDarkenReactCardNearText708(UIView *textView){
    if(!gP.enabled||!textView||!textView.window)return;
    @try {
        UIView *n=textView.superview;
        for(int d=0;n&&d<7;d++,n=n.superview){
            CGFloat w=n.bounds.size.width,h=n.bounds.size.height;
            if(w>=150&&w<=430&&h>=170&&h<=700&&ADBrightNeutralUIView708(n)){
                objc_setAssociatedObject(n,kADReactCard708,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                n.backgroundColor=ADOLED();
                n.layer.backgroundColor=ADOLED().CGColor;
                n.layer.borderColor=ADBorderGray706().CGColor;
                if(n.layer.borderWidth<0.5)n.layer.borderWidth=1.0;
                break;
            }
        }
    } @catch(...) {}
}

%hook RCTParagraphComponentView
- (void)setAttributedText:(NSAttributedString *)attributedText {
    NSAttributedString *r=ADLightAttributedText708(attributedText);
    %orig(r);
    ADDarkenReactCardNearText708((UIView *)self);
}
- (void)_setAttributedString:(NSAttributedString *)attributedString {
    NSAttributedString *r=ADLightAttributedText708(attributedString);
    %orig(r);
    ADDarkenReactCardNearText708((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled && ((UIView *)self).window) ADDarkenReactCardNearText708((UIView *)self);
}
%end

%hook RCTTextView
- (void)setTextStorage:(NSTextStorage *)textStorage {
    if(gP.enabled && textStorage.length){
        @try { [textStorage addAttribute:NSForegroundColorAttributeName value:ADLightText706() range:NSMakeRange(0,textStorage.length)]; } @catch(...) {}
    }
    %orig;
    ADDarkenReactCardNearText708((UIView *)self);
}
%end

%hook UILabel
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if(gP.enabled && ADInSearchChrome706((UIView *)self) && attributedText.length){
        NSMutableAttributedString *m=[attributedText mutableCopy];
        [m addAttribute:NSForegroundColorAttributeName value:ADLightText706() range:NSMakeRange(0,m.length)];
        %orig(m);
        return;
    }
    NSAttributedString *r=ADLightAttributedText708(attributedText);
    %orig(r);
}
- (void)setTextColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *want=ADLightText706();
        %orig(want);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window) self.textColor=ADLightText706();
}
%end

%hook UITextView
- (BOOL)becomeFirstResponder {
    if(gP.enabled)ADPrepareSearchKeyboard7120((UIView *)self);
    return %orig;
}
- (void)setKeyboardAppearance:(UIKeyboardAppearance)appearance {
    if(gP.enabled&&ADInSearchChrome706((UIView *)self)){
        UIKeyboardAppearance dark=UIKeyboardAppearanceDark;
        %orig(dark);
        return;
    }
    %orig;
}
- (void)setTextColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *want=ADLightText706();
        %orig(want);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window){ self.textColor=ADLightText706(); ADPrepareSearchKeyboard7120((UIView *)self); }
}
%end

%hook UITextField
- (BOOL)becomeFirstResponder {
    if(gP.enabled)ADPrepareSearchKeyboard7120((UIView *)self);
    return %orig;
}
- (void)setKeyboardAppearance:(UIKeyboardAppearance)appearance {
    if(gP.enabled&&ADInSearchChrome706((UIView *)self)){
        UIKeyboardAppearance dark=UIKeyboardAppearanceDark;
        %orig(dark);
        return;
    }
    %orig;
}
- (void)setTextColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *want=ADLightText706();
        %orig(want);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window){
        BOOL search=ADInSearchChrome706((UIView *)self);
        ADPrepareSearchKeyboard7120((UIView *)self);
        self.textColor=ADLightText706();
        if(search && self.placeholder.length){
            self.attributedPlaceholder=[[NSAttributedString alloc] initWithString:self.placeholder attributes:@{NSForegroundColorAttributeName:ADLightText706()}];
        }
    }
}
%end

%hook UIButton
- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state {
    if(gP.enabled){
        UIColor *light=ADLightText706();
        %orig(light,state);
        return;
    }
    %orig;
}
%end

%hook CALayer
- (void)setBorderColor:(CGColorRef)color {
    if(gP.enabled&&color&&ADNeutralCGColor706(color)){
        UIColor *g=ADBorderGray706();
        CGColorRef cg=g.CGColor;
        %orig(cg);
        return;
    }
    %orig;
}
%end

%hook CAShapeLayer
- (void)setStrokeColor:(CGColorRef)color {
    if(gP.enabled&&color&&ADNeutralCGColor706(color)&&(self.bounds.size.width>24||self.bounds.size.height>24)){
        UIColor *g=ADBorderGray706();
        CGColorRef cg=g.CGColor;
        %orig(cg);
        return;
    }
    %orig;
}
%end

%hook UIControl
- (void)setSelected:(BOOL)selected {
    %orig;
    if(gP.enabled&&self.window)ADRepaintNearestANXTab724((UIView *)self);
}
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    BOOL r=%orig;
    if(gP.enabled&&self.window)ADRepaintNearestANXTab724((UIView *)self);
    return r;
}
%end

%hook SBSearchBar
- (void)didMoveToWindow {
    %orig;
    UIView *v=(UIView *)self;
    if(gP.enabled&&v.window){
        v.backgroundColor=[UIColor clearColor];
        v.layer.backgroundColor=[UIColor clearColor].CGColor;
        v.layer.borderWidth=0;
    }
}
%end

static void ADOwnSearchSurface7045(UIView *v, BOOL ownBorder){
    if(!gP.enabled||!v||!v.window)return;
    @try {
        UIColor *fill=ADSearchChromeFill7045();
        v.backgroundColor=fill;
        v.layer.backgroundColor=fill.CGColor;
        if(ownBorder){
            v.layer.borderColor=ADBorderGray706().CGColor;
            if(v.layer.borderWidth<0.5)v.layer.borderWidth=1.0;
        }
        v.tintColor=ADLightText706();
    } @catch(...) {}
}

%hook SBSearchField
- (void)didMoveToWindow {
    %orig;
    ADOwnSearchSurface7045((UIView *)self,YES);
}
- (void)layoutSubviews {
    %orig;
    ADOwnSearchSurface7045((UIView *)self,YES);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled&&((UIView *)self).window){
        UIColor *fill=ADSearchChromeFill7045();
        %orig(fill);
        return;
    }
    %orig;
}
%end

static void ADOwnFocusedSearchSurface7120(UIView *v){
    if(!gP.enabled||!v||!v.window)return;
    @try {
        UIColor *fill=ADSearchChromeFill7045();
        v.backgroundColor=fill;
        v.layer.backgroundColor=fill.CGColor;
        v.layer.borderColor=ADBorderGray706().CGColor;
        if(v.layer.borderWidth<0.5)v.layer.borderWidth=1.0;
        // Do not force v.tintColor here: the focused editor uses the user's existing
        // accent tint for its insertion caret. Search glyphs are owned independently.
    } @catch(...) {}
}

%hook SBMultilineSearchView
- (BOOL)becomeFirstResponder {
    ADPrepareSearchKeyboard7120((UIView *)self);
    return %orig;
}
- (void)didMoveToWindow {
    %orig;
    if(((UIView *)self).window){
        ADOwnFocusedSearchSurface7120((UIView *)self);
        ADPrepareSearchKeyboard7120((UIView *)self);
    } else {
        ADKeyboardDeactivate7121();
    }
}
- (void)layoutSubviews {
    %orig;
    ADOwnFocusedSearchSurface7120((UIView *)self);
    ADPrepareSearchKeyboard7120((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled&&((UIView *)self).window){
        UIColor *fill=ADSearchChromeFill7045();
        %orig(fill);
        return;
    }
    %orig;
}
%end

static void ADPaintScanItSearchWidget7120(UIView *root){
    if(!gP.enabled||!root||!root.window)return;
    @try {
        root.backgroundColor=ADOLED();
        root.layer.backgroundColor=ADOLED().CGColor;
        UIView *ancestor=root.superview;
        CGFloat screenW=UIScreen.mainScreen.bounds.size.width;
        for(int ad=0;ancestor&&ad<7;ad++,ancestor=ancestor.superview){
            if(ancestor.bounds.size.width>=screenW*0.85 && ADBrightNeutralUIView708(ancestor)){
                ancestor.backgroundColor=ADOLED();
                ancestor.layer.backgroundColor=ADOLED().CGColor;
            }
        }
        NSMutableArray *stack=[NSMutableArray arrayWithObject:@{ @"v":root, @"d":@0 }];
        while(stack.count){
            NSDictionary *it=stack.lastObject; [stack removeLastObject];
            UIView *v=it[@"v"]; int d=[it[@"d"] intValue];
            if(!v||d>7)continue;
            CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
            BOOL control=[v isKindOfClass:[UIControl class]];
            BOOL plate=(d>0 && w>=120.0 && h>=32.0 && h<=70.0 && ADBrightNeutralUIView708(v));
            if(control||plate){
                v.backgroundColor=ADOLED();
                v.layer.backgroundColor=ADOLED().CGColor;
                v.layer.borderColor=ADBorderGray706().CGColor;
                if(v.layer.borderWidth<0.5)v.layer.borderWidth=1.0;
            } else if(d>0 && ADBrightNeutralUIView708(v)){
                v.backgroundColor=ADOLED();
                v.layer.backgroundColor=ADOLED().CGColor;
            }
            v.tintColor=ADLightText706();
            if([v isKindOfClass:[UILabel class]])((UILabel *)v).textColor=ADLightText706();
            if([v isKindOfClass:[UIImageView class]])ADTintSearchGlyph706((UIImageView *)v);
            for(UIView *c in v.subviews)if(c)[stack addObject:@{ @"v":c, @"d":@(d+1) }];
        }
    } @catch(...) {}
}

/* v7.121: Search-only local keyboard compositor owner. The actual keyboard is
 * remote; these hooks keep its local backing OLED and apply one color-matrix
 * filter to the host composite. No keyboard-process injection, timer or scan. */
%hook UIInputSetContainerView
- (void)didMoveToWindow {
    %orig;
    gADKeyboardContainer7121=(UIView *)self;
    if(gADSearchKeyboardActive7121)ADKeyboardPaintLocal7121((UIView *)self,NO);
}
- (void)layoutSubviews {
    %orig;
    gADKeyboardContainer7121=(UIView *)self;
    if(gADSearchKeyboardActive7121)ADKeyboardPaintLocal7121((UIView *)self,NO);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled&&gADSearchKeyboardActive7121&&!gADKeyboardBGWrite7121){
        UIColor *b=ADOLED();
        %orig(b);
        return;
    }
    %orig;
}
%end

%hook UIInputSetHostView
- (void)didMoveToWindow {
    %orig;
    gADKeyboardHost7121=(UIView *)self;
    if(gADSearchKeyboardActive7121)ADKeyboardPaintLocal7121((UIView *)self,YES);
}
- (void)layoutSubviews {
    %orig;
    gADKeyboardHost7121=(UIView *)self;
    if(gADSearchKeyboardActive7121)ADKeyboardPaintLocal7121((UIView *)self,YES);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled&&gADSearchKeyboardActive7121&&!gADKeyboardBGWrite7121){
        UIColor *b=ADOLED();
        %orig(b);
        return;
    }
    %orig;
}
%end

%hook _UIRemoteKeyboardPlaceholderView
- (void)didMoveToWindow {
    %orig;
    gADKeyboardPlaceholder7121=(UIView *)self;
    if(gADSearchKeyboardActive7121)ADKeyboardPaintLocal7121((UIView *)self,NO);
}
- (void)layoutSubviews {
    %orig;
    gADKeyboardPlaceholder7121=(UIView *)self;
    if(gADSearchKeyboardActive7121)ADKeyboardPaintLocal7121((UIView *)self,NO);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled&&gADSearchKeyboardActive7121&&!gADKeyboardBGWrite7121){
        UIColor *b=ADOLED();
        %orig(b);
        return;
    }
    %orig;
}
%end

%hook A9VSScanItSearchWidget
- (void)didMoveToWindow {
    %orig;
    ADPaintScanItSearchWidget7120((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADPaintScanItSearchWidget7120((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled&&((UIView *)self).window){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
%end

%hook ANPSearchBarRightButton
- (void)didMoveToWindow {
    %orig;
    ADOwnSearchSurface7045((UIView *)self,NO);
}
- (void)layoutSubviews {
    %orig;
    ADOwnSearchSurface7045((UIView *)self,NO);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled&&((UIView *)self).window){
        UIColor *fill=ADSearchChromeFill7045();
        %orig(fill);
        return;
    }
    %orig;
}
%end


static void ADOwnBottomBar708(UIView *v){
    if(!gP.enabled||!v||!v.window)return;
    @try {
        // Background-only ownership. Do not touch tab item images, renderingMode,
        // selected/unselected tint colors, labels, or selection state.
        v.backgroundColor=ADOLED();
        v.layer.backgroundColor=ADOLED().CGColor;
    } @catch(...) {}
}
%hook UIVisualEffectView
- (void)didMoveToWindow {
    %orig;
    BOOL bottom=NO; BOOL bar=ADBarGeometry713(self,&bottom);
    if(gP.enabled && self.window && (ADInBottomNav706(self)||ADTopChromeClass713(self)||bar)){
        self.effect=nil;
        self.backgroundColor=ADOLED();
        self.layer.backgroundColor=ADOLED().CGColor;
    }
}
- (void)layoutSubviews {
    %orig;
    BOOL bottom=NO; BOOL bar=ADBarGeometry713(self,&bottom);
    if(gP.enabled && self.window && (ADInBottomNav706(self)||ADTopChromeClass713(self)||bar)){
        self.effect=nil;
        self.backgroundColor=ADOLED();
        self.layer.backgroundColor=ADOLED().CGColor;
    }
}
%end

%hook UITabBar
- (void)didMoveToWindow {
    %orig;
    ADOwnBottomBar708((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADOwnBottomBar708((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
%end

%hook _UIBarBackground
- (void)didMoveToWindow {
    %orig;
    ADOwnBottomBar708((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADOwnBottomBar708((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
%end

%hook CXIStoreModesBottomNavToolbar
- (void)didMoveToWindow {
    %orig;
    ADOwnBottomBar708((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADOwnBottomBar708((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
%end

%hook CXIStoreModesTabBarView
- (void)didMoveToWindow {
    %orig;
    ADOwnBottomBar708((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADOwnBottomBar708((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
%end

%hook ANPRetailTabBar
- (void)didMoveToWindow {
    %orig;
    ADOwnBottomBar708((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADOwnBottomBar708((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
%end

// v7.0.24: probe-proven ANXTabBarView fill + v185 tab rendering mechanics.
%hook ANXTabBarView
- (void)didMoveToWindow {
    %orig;
    ADOwnBottomBar708((UIView *)self);
    ADPaintANXTabBar724((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADOwnBottomBar708((UIView *)self);
    ADPaintANXTabBar724((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
%end

// v7.0.14: exact v6.0.28-style adaptive top-nav owner.
%hook ANXTopNavBackgroundView
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window){ self.backgroundColor=ADOLED(); self.layer.backgroundColor=ADOLED().CGColor; }
}
- (void)layoutSubviews {
    %orig;
    if(gP.enabled&&self.window){ self.backgroundColor=ADOLED(); self.layer.backgroundColor=ADOLED().CGColor; }
}
%end

// Status-bar ownership from the v5.446/v6.0.5 lineage. This generic lifecycle hook
// does NOT paint controller views; it only installs a cached per-class light-content claim.
%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if(gP.enabled){
        ADClaimStatusController713(self);
        if(ADPrimaryAmazonController713(self) && self.isViewLoaded){
            self.view.backgroundColor=ADOLED();
            self.view.layer.backgroundColor=ADOLED().CGColor;
        }
    }
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if(gP.enabled){
        ADClaimStatusController713(self);
        BOOL primary=ADPrimaryAmazonController713(self);
        if(primary && self.isViewLoaded){
            self.view.backgroundColor=ADOLED();
            self.view.layer.backgroundColor=ADOLED().CGColor;
        }
        if(primary) ADConsiderLaunchReady706();
    }
}
%end


%hook UIApplication
- (void)setStatusBarStyle:(UIStatusBarStyle)style {
    if(gP.enabled){
        UIStatusBarStyle want=UIStatusBarStyleLightContent;
        %orig(want);
        return;
    }
    %orig;
}
- (void)setStatusBarStyle:(UIStatusBarStyle)style animated:(BOOL)animated {
    if(gP.enabled){
        UIStatusBarStyle want=UIStatusBarStyleLightContent;
        %orig(want,animated);
        return;
    }
    %orig;
}
%end

// Do not black every UIWindow. Screenshot/share/input windows are intentionally excluded;
// only Amazon's primary navigation window receives the OLED backing.
%hook UIWindow
- (void)setRootViewController:(UIViewController *)vc {
    %orig;
    if(gP.enabled && ADPrimaryAmazonWindow713(self,vc)) self.backgroundColor=ADOLED();
}
- (void)makeKeyAndVisible {
    if(gP.enabled && ADPrimaryAmazonWindow713(self,nil)) self.backgroundColor=ADOLED();
    %orig;
}
%end

%hook UITableView
- (void)didMoveToWindow {
    %orig;
    if (gP.enabled && self.window) self.backgroundColor=ADOLED();
}
%end

%hook UICollectionView
- (void)didMoveToWindow {
    %orig;
    if (gP.enabled && self.window) self.backgroundColor=ADOLED();
}
%end

%hook RCTRootView
- (void)didMoveToWindow {
    %orig;
    if (gP.enabled && self.window) self.backgroundColor=ADOLED();
}
%end

%hook RCTRootContentView
- (void)didMoveToWindow {
    %orig;
    if (gP.enabled && self.window) self.backgroundColor=ADOLED();
}
%end

%hook RCTScrollView
- (void)didMoveToWindow {
    %orig;
    if (gP.enabled && self.window) self.backgroundColor=ADOLED();
}
%end

static void ADDarkenSplash(UIViewController *vc){ if(gP.enabled) @try { if(vc.view)vc.view.backgroundColor=ADOLED(); } @catch(...) {} }
%hook AXUSplashScreenViewController
- (void)viewDidLayoutSubviews {
    %orig;
    ADDarkenSplash(self);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    ADDarkenSplash(self);
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    ADConsiderLaunchReady706();
}
%end
%hook TezBaseSplashScreenViewController
- (void)viewDidLayoutSubviews {
    %orig;
    ADDarkenSplash(self);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    ADDarkenSplash(self);
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    ADConsiderLaunchReady706();
}
%end

// -----------------------------------------------------------------------------
// Lightweight native TWB owner retained because the v6.0.185 Settings pane keeps
// the Tame Light Backgrounds preference. No hierarchy scan or observer is used.
// -----------------------------------------------------------------------------
static const void *kADTWBOverlay=&kADTWBOverlay;
static BOOL ADNativeMediaBlocked(UIImageView *iv){
    if(!iv)return YES;
    @try {
        UIImage *im=iv.image; if(!im)return YES;
        if(im.renderingMode==UIImageRenderingModeAlwaysTemplate)return YES;
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height; if(w<52||h<52)return YES;
        if(im.CGImage && CGImageGetWidth(im.CGImage)<=80 && CGImageGetHeight(im.CGImage)<=80)return YES;
        NSMutableString *s=[NSMutableString string];
        UIView *n=iv;
        for(int i=0;i<4&&n;i++,n=n.superview){
            [s appendFormat:@" %@ %@",NSStringFromClass(n.class),n.accessibilityIdentifier?:@""];
            if([n isKindOfClass:[UIButton class]] || [n isKindOfClass:[UITabBar class]] || [n isKindOfClass:[UINavigationBar class]])return YES;
        }
        [s appendFormat:@" %@",iv.accessibilityLabel?:@""];
        NSString *q=s.lowercaseString;
        for(NSString *tok in @[@"icon",@"glyph",@"logo",@"avatar",@"profile",@"badge",@"star",@"rating",@"checkbox",@"heart",@"arrow",@"chevron",@"button",@"search",@"menu",@"microphone",@"camera",@"cart",@"location",@"nav",@"tab",@"sprite",@"brand",@"seller",@"store",@"screenshot",@"snapshot",@"screen shot",@"share preview",@"preview"])
            if([q containsString:tok])return YES;
        CGSize screen=UIScreen.mainScreen.bounds.size;
        if(screen.width>0 && screen.height>0 && w>=screen.width*0.72&&h>=screen.height*0.48)return YES;
        BOOL semanticProduct=NO;
        for(NSString *tok in @[@"product",@"asin",@"item",@"offer",@"recommend",@"reorder",@"buy again",@"keep shopping",@"shopping for",@"retail image"])
            if([q containsString:tok]){ semanticProduct=YES; break; }
        NSString *cn=NSStringFromClass(iv.class).lowercaseString?:@"";
        BOOL knownAmazonRaster=([cn containsString:@"rctuiimageviewanimated"]||[cn containsString:@"anxfastimageview"]);
        if(!semanticProduct && !knownAmazonRaster)return YES;
    } @catch(...) { return YES; }
    return NO;
}
static void ADApplyNativeTWB(UIImageView *iv){
    if(!iv)return;
    @try {
        CALayer *ov=objc_getAssociatedObject(iv,kADTWBOverlay);
        if(!gP.enabled || !gP.whiteTame || !iv.window || ADNativeMediaBlocked(iv)){
            if(ov){ [ov removeFromSuperlayer]; objc_setAssociatedObject(iv,kADTWBOverlay,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        if(!ov){ ov=[CALayer layer]; ov.name=@"AmazonDarkTWB7"; ov.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"backgroundColor":[NSNull null]}; [iv.layer addSublayer:ov]; objc_setAssociatedObject(iv,kADTWBOverlay,ov,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        CGFloat strength=MAX(0,MIN(100,gP.whiteTameStrength));
        CGFloat shade=0.10+(0.48*(strength/100.0));
        ov.frame=iv.bounds; ov.backgroundColor=[UIColor colorWithWhite:0 alpha:shade].CGColor; ov.zPosition=FLT_MAX;
    } @catch(...) {}
}


%hook UIImageView
- (void)setImage:(UIImage *)image {
    if(gADTabImageWriting724){
        %orig;
        return;
    }
    %orig;
    if(gP.enabled&&self.window&&ADANXTabRoot724(self))ADTabImageWhite724(self);
    if(gP.enabled&&self.window)ADTintSearchGlyph706(self);
    if(gP.whiteTame)ADApplyNativeTWB(self);
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window&&ADANXTabRoot724(self))ADTabImageWhite724(self);
    if(gP.enabled&&self.window)ADTintSearchGlyph706(self);
    ADApplyNativeTWB(self);
}
- (void)setTintColor:(UIColor *)color {
    if(gP.enabled&&self.window){
        if(ADANXTabRoot724(self)){
            UIColor *white=ADLightText706();
            %orig(white);
            return;
        }
        if(ADInSearchChrome706(self)||ADIsLocationGlyph709(self)||ADIsSearchBackGlyph7120(self)){
            UIColor *light=ADLightText706();
            %orig(light);
            return;
        }
    }
    %orig;
}
- (void)layoutSubviews {
    %orig;
    if(gP.enabled&&self.window&&ADANXTabRoot724(self))ADTabImageWhite724(self);
    if(gP.enabled&&self.window&&(ADInSearchChrome706(self)||ADIsLocationGlyph709(self)||ADIsSearchBackGlyph7120(self)))ADTintSearchGlyph706(self);
    if(objc_getAssociatedObject(self,kADTWBOverlay)||gP.whiteTame)ADApplyNativeTWB(self);
}
%end

// -----------------------------------------------------------------------------
// Launch transition handoff. The SpringBoard side retains v6.0.185's 1.40 s
// minimum presentation and 0.55 s fade; Amazon only tells it that the black root
// is mounted. Cached light launch snapshots are cleared exactly as in v6.0.185.
// -----------------------------------------------------------------------------
static BOOL gADReadyPosted706=NO;
static BOOL ADVisibleSplashController706(void){
    @try {
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w || w.hidden || w.alpha<0.01)continue;
            UIViewController *vc=w.rootViewController;
            NSMutableArray *q=[NSMutableArray array]; if(vc)[q addObject:vc];
            for(NSUInteger i=0;i<q.count&&i<24;i++){
                UIViewController *x=q[i]; NSString *n=NSStringFromClass(x.class).lowercaseString?:@"";
                if(([n containsString:@"splash"]||[n containsString:@"launchscreen"]||[n containsString:@"loading"]) && x.isViewLoaded && x.view.window && !x.view.hidden && x.view.alpha>0.01) return YES;
                if(x.presentedViewController)[q addObject:x.presentedViewController];
                for(UIViewController *c in x.childViewControllers) if(c)[q addObject:c];
            }
        }
    } @catch(...) {}
    return NO;
}
static void ADPostReadyOnce(void){
    if(gADReadyPosted706)return; gADReadyPosted706=YES;
    @try { notify_post("com.colindavidr.amazondark.ready"); } @catch(...) {}
}
// v7.115: launch-cover release is event-driven. Visible primary controller /
// WebView lifecycle events and the known Amazon splash controllers' disappearance
// are enough to signal readiness; there is no DOM polling, delayed retry loop or
// JavaScript readiness query. The tiny splash-tree check only runs until the first
// successful signal and prevents an underneath-splash view event from releasing
// the SpringBoard cover early. SpringBoard still owns the 1.40 s minimum and
// 0.55 s fade, so presentation timing remains unchanged.
static void ADConsiderLaunchReady706(void){
    if(gADReadyPosted706||!gP.enabled)return;
    if(ADVisibleSplashController706())return;
    ADPostReadyOnce();
}






%hook NSURLSessionConfiguration
+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *c=%orig;
    ADPrivacyInstallProtocolOnConfig7117(c);
    return c;
}
+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
    NSURLSessionConfiguration *c=%orig;
    ADPrivacyInstallProtocolOnConfig7117(c);
    return c;
}
+ (NSURLSessionConfiguration *)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier {
    NSURLSessionConfiguration *c=%orig;
    ADPrivacyInstallProtocolOnConfig7117(c);
    return c;
}
- (void)setProtocolClasses:(NSArray *)protocolClasses {
    if(gP.enabled&&gP.privacyMode){
        @try {
            NSMutableArray *a=[protocolClasses mutableCopy]?:[NSMutableArray array];
            if(![a containsObject:[ADPrivacyURLProtocol7117 class]]){
                [a insertObject:[ADPrivacyURLProtocol7117 class] atIndex:0];
                gADPrivacyLateProtocolRewrites7118++;
            }
            %orig(a);
            return;
        } @catch(...) {}
    }
    %orig(protocolClasses);
}
%end

%hook NSURLSession
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration {
    if(gP.enabled&&gP.privacyMode)gADPrivacySessionCtorChecks7118++;
    ADPrivacyInstallProtocolOnConfig7117(configuration);
    return %orig;
}
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    if(gP.enabled&&gP.privacyMode)gADPrivacySessionCtorChecks7118++;
    ADPrivacyInstallProtocolOnConfig7117(configuration);
    return %orig;
}
- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    if(gP.enabled&&gP.privacyMode)gADPrivacySessionCtorChecks7118++;
    ADPrivacyInstallProtocolOnConfig7117(configuration);
    return %orig;
}
%end

%hook NSURLSessionTask
- (void)resume {
    if(gP.enabled&&gP.privacyMode){
        @try { NSURLRequest *r=self.currentRequest?:self.originalRequest; if(ADPrivacyShouldBlockURL7117(r.URL))ADPrivacyCount7117(gADPrivacyNativeRequested7117,r.URL,NO); } @catch(...) {}
    }
    %orig;
}
%end

static NSString *ADPrivacyNativeSnapshot7117(void){
    ADPrivacyInit7117(); __block NSDictionary *requested=nil,*blocked=nil; __block NSUInteger rq=0,bl=0;
    @synchronized(gADPrivacyLock7117){ requested=[gADPrivacyNativeRequested7117 copy]; blocked=[gADPrivacyNativeBlocked7117 copy]; rq=gADPrivacyNativeRequestedTotal7117; bl=gADPrivacyNativeBlockedTotal7117; }
    NSMutableString *m=[NSMutableString string];
    [m appendFormat:@"privacy_pref=%d\nurlprotocol_registered=%d\ncontent_rule_compiled=%d\ncontent_rule_pending=%d\ncontent_rule_error=%@\nconfig_protocol_insertions=%lu\nlate_protocol_rewrites=%lu\nsession_ctor_checks=%lu\nnative_candidate_resumes=%lu\nnative_protocol_blocks=%lu\n",(gP.enabled&&gP.privacyMode)?1:0,gADPrivacyProtocolRegistered7117?1:0,gADPrivacyRuleList7117?1:0,gADPrivacyRuleCompilePending7117?1:0,gADPrivacyRuleError7117?:@"none",(unsigned long)gADPrivacyConfigInsertions7118,(unsigned long)gADPrivacyLateProtocolRewrites7118,(unsigned long)gADPrivacySessionCtorChecks7118,(unsigned long)rq,(unsigned long)bl];
    [m appendString:@"\n--- NATIVE CANDIDATE RESUMES ---\n"];
    for(NSString *k in [[requested allKeys] sortedArrayUsingSelector:@selector(compare:)])[m appendFormat:@"%@ = %@\n",k,requested[k]];
    [m appendString:@"\n--- NATIVE SYNTHETIC-204 BLOCKS ---\n"];
    for(NSString *k in [[blocked allKeys] sortedArrayUsingSelector:@selector(compare:)])[m appendFormat:@"%@ = %@\n",k,blocked[k]];
    return m;
}
static NSString *ADPrivacyProbePath7117(void){
    @try { NSString *docs=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject]; if(docs.length)return [docs stringByAppendingPathComponent:@"AmazonDark-v7.121-search-ui-probe.txt"]; } @catch(...) {}
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"AmazonDark-v7.121-search-ui-probe.txt"];
}
static void ADAppendPrivacy7117(NSString *s){
    if(!s.length)return; @try { NSString *p=ADPrivacyProbePath7117(); NSFileManager *fm=[NSFileManager defaultManager]; [fm createDirectoryAtPath:[p stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil]; NSData *d=[s dataUsingEncoding:NSUTF8StringEncoding]; if(![fm fileExistsAtPath:p]){[d writeToFile:p atomically:YES];return;} NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:p]; if(h){[h seekToEndOfFile];[h writeData:d];[h closeFile];} } @catch(...) {}
}
static WKWebView *ADLargestTrackedWeb7117(void){
    WKWebView *best=nil; CGFloat area=0; @try { for(WKWebView *wv in ADTrackedWebViews()){ if(!wv||!wv.window||wv.hidden||wv.alpha<0.01)continue; CGRect rr=[wv convertRect:wv.bounds toView:nil],ir=CGRectIntersection(rr,UIScreen.mainScreen.bounds); CGFloat a=MAX(0,ir.size.width)*MAX(0,ir.size.height); if(a>area){area=a;best=wv;} } } @catch(...) {} return best;
}
static void ADCapturePrivacy7117(void){
    if(!gP.enabled)return; NSUInteger run=++gADPrivacyRun7117; NSString *native=ADPrivacyNativeSnapshot7117(); WKWebView *wv=ADLargestTrackedWeb7117();
    NSMutableString *prefix=[NSMutableString stringWithFormat:@"\n\n================ AMAZON DARK v7.121 SEARCH UI PROBE RUN %lu ================\ndate=%@\npid=%d\nversion=%s\npolicy=metadata only; no request bodies/headers/content, typed text, clipboard contents or coordinates\nmode=known telemetry endpoints receive local synthetic success; shopping/media/creative hosts remain untouched\n\n===== NATIVE =====\n%@\n",(unsigned long)run,[NSDate date],getpid(),AD_VERSION,native?:@"NO_NATIVE_DATA"];
    if(!wv){ [prefix appendString:@"\n===== WEB =====\nNO_VISIBLE_TRACKED_WKWEBVIEW\n================ END RUN ================\n"]; ADAppendPrivacy7117(prefix); return; }
    NSString *trigger=@"(function(){try{if(typeof window.__adPrivacy7117Report!=='function')return 'HELPER_MISSING privacyMode may be off or this document predates enable';var nonce='priv7117-'+Date.now()+'-'+Math.random().toString(36).slice(2),c={nonce:nonce,main:window.__adPrivacy7117Report(),children:[]};window.__adPrivacy7117Collection=c;window.__adPrivacy7117Collector=function(ev){try{var d=ev.data;if(!d||d.__adPrivacy7117Result!==1||d.nonce!==nonce)return;if(c.children.length<64)c.children.push({href:String(d.href||''),report:String(d.report||'')})}catch(_){}};addEventListener('message',window.__adPrivacy7117Collector,false);window.__adPrivacy7117Broadcast({__adPrivacy7117:1,nonce:nonce});return 'STARTED '+nonce}catch(e){return 'TRIGGER_ERR '+e}})();";
    [wv evaluateJavaScript:trigger completionHandler:^(id v,NSError *e){
        NSString *start=e?[NSString stringWithFormat:@"TRIGGER_ERROR %@",e]:([v isKindOfClass:[NSString class]]?v:[v description]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.65*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            NSString *collect=@"(function(){try{var c=window.__adPrivacy7117Collection;if(!c)return 'NO_COLLECTION';try{if(window.__adPrivacy7117Collector)removeEventListener('message',window.__adPrivacy7117Collector,false)}catch(_){}var o=['===== MAIN FRAME =====\\n'+String(c.main||'')];for(var i=0;i<c.children.length;i++)o.push('\\n===== CHILD FRAME '+i+' '+String(c.children[i].href||'')+' =====\\n'+String(c.children[i].report||''));o.push('\\nCHILD_COUNT '+c.children.length);return o.join('\\n')}catch(e){return 'COLLECT_ERR '+e}})();";
            [wv evaluateJavaScript:collect completionHandler:^(id v2,NSError *e2){ NSString *body=e2?[NSString stringWithFormat:@"COLLECT_ERROR %@",e2]:([v2 isKindOfClass:[NSString class]]?v2:[v2 description]); [prefix appendFormat:@"\n===== WEB =====\ntrigger=%@\n%@\n================ END RUN ================\n",start?:@"",body?:@"NO_WEB_DATA"]; ADAppendPrivacy7117(prefix); }];
        });
    }];
}

// -----------------------------------------------------------------------------
// Privacy-mode manual SIGUSR2 verification retained from v7.118.
// -----------------------------------------------------------------------------
static dispatch_source_t gADPrivacySignal7117=nil;
static void ADInstallPrivacySignal7117(void){
    static dispatch_once_t once; dispatch_once(&once,^{ signal(SIGUSR2,SIG_IGN); gADPrivacySignal7117=dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,SIGUSR2,0,dispatch_get_main_queue()); if(!gADPrivacySignal7117)return; dispatch_source_set_event_handler(gADPrivacySignal7117,^{ ADCapturePrivacy7117(); }); dispatch_resume(gADPrivacySignal7117); });
}


// v7.116 production: v7.115 event-driven app handoff retained; SpringBoard owns a
// bounded 0.40 s post-ready settle guard so Amazon's final white loading composite
// cannot peek through the cover fade.
// v7.0.68 production: v7.0.65 chevron diagnostic runtime removed.
static void ADPrefsChanged(CFNotificationCenterRef c,void *o,CFStringRef n,const void *obj,CFDictionaryRef ui){
    BOOL wasPrivacy=gP.privacyMode;
    ADLoadPrefs();
    ADRefreshRuntimeState7115(YES);
    if(gP.enabled&&gP.privacyMode){
        ADRegisterPrivacyProtocol7117();
        ADCompilePrivacyContentRules7117();
        for(WKWebView *wv in ADTrackedWebViews()){
            @try { ADAttachScriptsToUCC710(wv.configuration.userContentController); [wv evaluateJavaScript:ADPrivacyModeJS7117() completionHandler:nil]; } @catch(...) {}
        }
        ADSetLoadedWebPrivacyEnabled7117(YES);
    } else if(wasPrivacy){
        ADSetLoadedWebPrivacyEnabled7117(NO);
    }
}

%ctor {
    if(strcmp(__progname,"Amazon")!=0)return;
    ADLoadPrefs();

    // v6.0.185 launch-transition behavior: discard stale light SplashBoard snapshots.
    @try {
        NSString *lib=[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES) firstObject];
        NSString *snap=[lib stringByAppendingPathComponent:@"SplashBoard/Snapshots"];
        NSFileManager *fm=[NSFileManager defaultManager];
        for(NSString *k in [fm contentsOfDirectoryAtPath:snap error:nil]){
            NSString *sub=[snap stringByAppendingPathComponent:k];
            for(NSString *f in [fm contentsOfDirectoryAtPath:sub error:nil]) [fm removeItemAtPath:[sub stringByAppendingPathComponent:f] error:nil];
        }
    } @catch(...) {}

    %init;

    /* Event-only reassertion for the retained Search keyboard across background/foreground. */
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *n){ ADKeyboardReassert7121(); }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *n){ ADKeyboardReassert7121(); }];

    ADPrivacyInit7117();
    ADInstallPrivacySignal7117();
    if(gP.enabled&&gP.privacyMode){
        ADRegisterPrivacyProtocol7117();
        ADCompilePrivacyContentRules7117();
    }

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,ADPrefsChanged,
        CFSTR("com.colindavidr.amazondark/prefs-changed"),NULL,CFNotificationSuspensionBehaviorCoalesce);
    ADRefreshRuntimeState7115(NO);
    ADApplyJIT622();
}

#pragma clang diagnostic pop
