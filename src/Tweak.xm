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

#define AD_VERSION "v7.156-search-regression-fix-probe"
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
@interface GlowIngressView : UIView @end

// v7.129: exact UIKit transition / WebKit text-selection surfaces proven by the
// v7.128 held-row probe. These remain Amazon-process-local through the tweak filter.
@interface UILayoutContainerView : UIView @end
@interface UITransitionView : UIView @end
@interface UINavigationTransitionView : UIView @end
@interface UIViewControllerWrapperView : UIView @end
@interface _UIPlatterContainerView : UIView @end
@interface _UIPlatterView : UIView @end
@interface _UIPlatterSoftShadowView : UIView @end
@interface _UIPlatterShadowView : UIView @end

// v7.130: exact owners proven by the v7.129 transition probe.
@interface AWLoadingIndicatorFullScreenModalBar : UIView @end
@interface AWLoadingIndicatorWidgets_BkgView : UIView @end
@interface AWLoadingIndicatorWidgets_LoadingText : UILabel @end
@interface UIInputSetHostView : UIView @end
@interface _UIRemoteKeyboardPlaceholderView : UIView @end

// OledKeyboard-derived UIKit owners. Kept local to the Amazon process by AmazonDark.plist.
@interface UIKeyboard : UIView
+ (instancetype)activeKeyboard;
@end
@interface UIPredictionViewController : UIViewController @end
@interface UIKeyboardDockView : UIView @end
@interface UIKBVisualEffectView : UIVisualEffectView
@property (nonatomic, copy, readwrite) NSArray *backgroundEffects;
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
// Privacy Mode. Production keeps only the blocking path; probe-only counters and
// request bookkeeping are intentionally absent.
// -----------------------------------------------------------------------------
static BOOL gADPrivacyProtocolRegistered7117=NO;
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
    NSURL *url=self.request.URL;
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
static const void *kADHomeAdProbeUS7144=&kADHomeAdProbeUS7144;
static NSHashTable *gADWebViews=nil;
// v7.0.68 production: no diagnostic touch probe is installed.

static NSString *ADFloorJS(void){
    // v7.0.14: static v185-style palette. CSS only: no Dark Reader, no observer,
    // no computed-style repair walker. Own known structural shells; preserve media/art.
    return @"(function(){try{var host='';try{host=String(location.hostname||'').toLowerCase();}catch(_){}if(host==='flashtalking.com'||/\\.flashtalking\\.com$/.test(host))return;var child=0;try{child=window.top!==window;}catch(_){child=1;}if(child&&document.documentElement){document.documentElement.setAttribute('data-ad7-child-frame','1');try{var ref=String(document.referrer||'').toLowerCase();var productish=/\\/dp\\/|\\/gp\\/product\\/|\\/gp\\/aw\\/d\\/|\\/s(?:[\\/?]|$)|[?&]k=/.test(ref);if(!productish)document.documentElement.setAttribute('data-ad7-standalone-candidate','1');}catch(__){}}"
            /* v7.154 performance: proven standalone child ads use the compact child palette; productish child frames retain the general theme. */
            "if(child&&document.documentElement&&document.documentElement.hasAttribute('data-ad7-standalone-candidate')){var cid='ad7-child-floor-min',cs=document.getElementById(cid);if(!cs){cs=document.createElement('style');cs.id=cid;(document.head||document.documentElement||document).appendChild(cs);}cs.textContent='html,body{background:#000!important;background-color:#000!important;color-scheme:dark!important;}';return;}"
            /* v7.154 zero-delay Search lane: /s never parses the 54 KB cross-surface
             * theme. Search gets a compact exact-owner sheet with no :has(), no :where(),
             * and no broad class-substring ancestry chains. This attacks the residual v7.149
             * style-recalculation cost that remained even after probe removal. */
            "var ad7p='';try{ad7p=String(location.pathname||'');}catch(_){}"
            "if(!child&&(ad7p==='/s'||ad7p.indexOf('/s/')===0)){var sid='ad7-search-fast-theme',ss=document.getElementById(sid);if(!ss){ss=document.createElement('style');ss.id=sid;(document.head||document.documentElement||document).appendChild(ss);}ss.textContent='"
            "html,body,#a-page,#search,.s-main-slot,.s-result-item,[data-component-type=s-search-result],.s-card-container,.puis-card-container,.puisg-row,.puisg-col,.puisg-col-inner{background:#000!important;background-color:#000!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;box-shadow:none!important;}#search :is(.a-color-base,.a-text-normal,.a-size-base,.a-size-base-plus,.a-size-medium,.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen,.s-title-instructions-style,h1,h2,h3,h4,h5,h6,p,label,strong,b){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#search :is(.a-color-secondary,.a-size-small){color:#b1b5b5!important;-webkit-text-fill-color:#b1b5b5!important;}#search :is(.s-result-item,.s-card-container,.puis-card-container,[data-component-type=s-search-result]){border-color:#494d4d!important;outline-color:#494d4d!important;}#search "
            ":is(.a-divider-inner)::before,#search :is(.a-divider-inner)::after,#search hr{border-color:#494d4d!important;background-color:#494d4d!important;}.ufs_tiles_card_widget-suggestion{background:#000!important;background-color:#000!important;color:#e8e6e3!important;}.ufs_tiles_card_widget-suggestion :is(.ufs_tiles_card_widget-sug-container-top,.ufs_tiles_card_widget-sug-column,.ufs_tiles_card_widget-sug-card,.ufs_tiles_card_widget-sug-link,.ufs_tiles_card_widget-sug-image-container,.ufs_tiles_card_widget-sug-image-background){background-color:transparent!important;border-color:#494d4d!important;}.ufs_tiles_card_widget-suggestion :is(h1,h2,h3,h4,h5,h6,p,span,a,div){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}.ufs_tiles_card_widget-suggestion .ufs_tiles_card_widget-sug-text{background:#000!important;background-color:#000!important;color:#fff!important;-webkit-text-fill-co"
            "lor:#fff!important;}.ufs_tiles_card_widget-suggestion .ufs_tiles_card_widget-sug-text *{color:#fff!important;-webkit-text-fill-color:#fff!important;}#search :is(.puis-product-insight-prompt-group,#rufus-overviews-pills-carousel,#rufus-mobile-overviews-expandable-pills-carousel-container,#rufus-overviews-category-cards-carousel){background-color:#000!important;border-color:#494d4d!important;box-shadow:none!important;}#nav-global-location-slot,#glow-ingress-block{background:#000!important;background-color:#000!important;background-image:none!important;border-color:#000!important;color:#f2f2f2!important;-webkit-text-fill-color:#f2f2f2!important;box-shadow:none!important;}#nav-global-location-slot :is(span,a,p,div,label,strong,b),#glow-ingress-block :is(span,a,p,div,label,strong,b){color:#f2f2f2!important;-webkit-text-fill-color:#f2f2f2!important;}#nav-global-location-slot :is(svg,i),#glow-i"
            "ngress-block :is(svg,i){background-color:transparent!important;color:#f2f2f2!important;fill:#f2f2f2!important;stroke:#f2f2f2!important;}#a-page :is(.s-mobile-toolbar,.sf-rib30-toolbar,.sf-rib30-panel,.sf-rib30-content){background-color:#000!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;border-color:#494d4d!important;}#a-page :is(.s-rib-toggle-container,.sf-rib30-dropdown-title,a.sf-rib30-dropdown-pill-option){background-color:#202324!important;border-color:#747a7c!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;box-shadow:none!important;}#a-page :is(.sf-mobile-rib-filter-icon,.sf-rib30-dropdown-arrow-icon){background-color:transparent!important;filter:brightness(0) invert(1) brightness(.88)!important;-webkit-filter:brightness(0) invert(1) brightness(.88)!important;}#a-page .sf-rib30-dropdown-pill-icon,#a-page i.a-icon-prime{filter"
            ":none!important;-webkit-filter:none!important;}#search :is(.puis-status-badge-container,.puis-status-badge-container .a-section,.puis-status-badge-container .rush-component,.puis-status-badge-container .a-badge,.puis-status-badge-container .a-badge-label,.puis-status-badge-container .a-badge-label-inner){background:#000!important;background-color:#000!important;background-image:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;box-shadow:none!important;}#search .puis-status-badge-container :is(i,svg,[class*=icon]){background-color:transparent!important;color:#d6d9d9!important;fill:#d6d9d9!important;stroke:#d6d9d9!important;filter:brightness(0) invert(1) brightness(.88)!important;-webkit-filter:brightness(0) invert(1) brightness(.88)!important;}#search#search .more-like-this-container{background:transparent!important;background-color:transparent!important;ba"
            "ckground-image:none!important;box-shadow:none!important;}#search#search .nile-ingress-pill-button,#search#search .nile-ingress-pill-button .a-button-inner{background:#4a4f51!important;background-color:#4a4f51!important;background-image:none!important;border-color:#747a7c!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search .nile-ingress-pill-button :is(span,div){color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search .haul-puis-widget-faceout-container{background:#000!important;background-color:#000!important;border-color:#000!important;outline-color:#000!important;box-shadow:none!important;}#search#search .haul-puis-widget-faceout-container > :not(.haul-puis-image-container):not(.haul-puis-widget-action-button){border-color:#000!important;outline-color:#000!important;box-shadow:none!important;}#search#search "
            ".haul-puis-widget-faceout-container > :not(.haul-puis-image-container):not(.haul-puis-widget-action-button){background:#000!important;background-color:#000!important;border-color:#000!important;outline-color:#000!important;box-shadow:none!important;}#search#search .s-coupon-tile,#search#search .s-coupon-tile-price-content,#search#search .s-coupon-unclipped,#search#search .s-coupon-highlight-color{background:#405a4a!important;background-color:#405a4a!important;background-image:none!important;border-color:#587161!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search .s-coupon-tile-text-content,#search#search .s-coupon-checkbox-label,#search#search .s-coupon-tile-price-content,#search#search .s-coupon-unclipped,#search#search .s-coupon-highlight-color{color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search :is(vid"
            "eo.sbv-video-player-ecx,video._c2Itd_video_17g-f){color-scheme:light!important;accent-color:auto!important;filter:none!important;-webkit-filter:none!important;}#search#search :is(.sbv-video-pause-button-container,.sbv-video-mute-button-container,.sbv-mobile-video-play-click-region,._c2Itd_playClickRegion_87ZZa){background-color:transparent!important;border-color:transparent!important;outline-color:transparent!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;}#search#search .puis-card-container.mobile-video-product-view.puis-card-border{background:#000!important;background-color:#000!important;border:1px solid #494d4d!important;border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!important;}#search#search .sbv-video-single-product .sbv-product-container,#search#search .sbv-video-single-product .sbv-product-container :is(.pui"
            "sg-row,.puisg-col,.puisg-col-inner,.faceout-product-title,.faceout-product-review,.faceout-product-price,.puis-delivery-recipe,.udm-delivery-block){background-color:#000!important;border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!important;}#search#search ._c2Itd_container_ut_MN.sb-video-creative{background:#000!important;background-color:#000!important;border:1px solid #494d4d!important;border-color:#494d4d!important;border-radius:4px!important;outline-color:#494d4d!important;box-shadow:none!important;overflow:hidden!important;}#search#search ._c2Itd_cardContent_3OGkG.sbv-ad-content-container,#search#search ._c2Itd_content_2L-a5,#search#search ._c2Itd_singleAsin_fHkKv{background:#000!important;background-color:#000!important;background-image:none!important;border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!important;}#search#searc"
            "h ._c2Itd_singleAsin_fHkKv{border:1px solid #494d4d!important;}#search#search ._c2Itd_singleAsin_fHkKv :is(._c2Itd_pdCntr_2lxVH,._c2Itd_pdRowCntr_1SQrE,._c2Itd_pdImgCol_3WO1V,._c2Itd_pdcol_3gSOx,.productDetailsContainer){background-color:#000!important;border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!important;}#search#search ._c2Itd_singleAsin_fHkKv :is(.productDetailsContainer,._c2Itd_productTitle_1rGyG,._c2Itd_reviewStars_1pJ4C,._c2Itd_badgeContainer_3rI4l,._c2Itd_dealMessage_1qaio,._c2Itd_priceLinkContainer_6y-Wc,._c2Itd_savingPercentage_3sw1C){background-color:transparent!important;box-shadow:none!important;}#search#search ._c2Itd_singleAsin_fHkKv :is(._c2Itd_singleProductImageContainer_1xhVQ,._c2Itd_productImageLinkContainer_3novt,a._c2Itd_productImageLink_2cbWY){background-color:transparent!important;box-shadow:none!important;}#search#search ._c2Itd_s"
            "ingleAsin_fHkKv img._c2Itd_image_pQREQ{display:block!important;visibility:visible!important;position:relative!important;z-index:6!important;background-color:transparent!important;mix-blend-mode:normal!important;}#search :is(.sf-mobile-rib-filter-icon,.sf-rib30-dropdown-arrow-icon,.rufus-expandable-pills-chevron){background-color:transparent!important;color:#d6d9d9!important;fill:#d6d9d9!important;stroke:#d6d9d9!important;}#search#search .s-rib-toggle-icon{background:transparent!important;background-color:transparent!important;filter:none!important;-webkit-filter:none!important;mix-blend-mode:normal!important;opacity:1!important;}#search#search .s-rib-toggle-container{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;}#searc"
            "h#search .sf-rib30-dropdown-pill-icon{background-color:#202324!important;border-color:#747a7c!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;mix-blend-mode:normal!important;opacity:1!important;}#search#search .sf-rib30-review-star{filter:none!important;-webkit-filter:none!important;mix-blend-mode:normal!important;opacity:1!important;}#search#search .sf-rib30-dropdown-pill-icon .sf-rib30-review-content,#search#search .sf-rib30-dropdown-pill-icon .sf-rib30-review-stars-group{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;}#search#search .sf-rib30-dropdown-title > .a-declarative > .sf-rib30-title-content-container,#search#search .sf-rib30-dropdown-title .sf-rib30-title-content-contai"
            "ner .sf-rib30-dropdown-pill-content,#search#search .sf-rib30-dropdown-title .sf-rib30-title-content-container .sf-rib30-dropdown-pill-text{background:transparent!important;background-color:transparent!important;background-image:none!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;}#search#search .sf-rib30-dropdown-title{background:#202324!important;background-color:#202324!important;border-color:#747a7c!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;box-shadow:none!important;}#search#search .sf-rib30-dropdown-title .sf-rib30-dropdown-arrow-icon{background:transparent!important;background-color:transparent!important;background-image:none!important;filter:none!important;-webkit-filter:none!important;box-shadow:none!important;position:relative!important;}#search#search .sf-rib30-dropdown-title .sf-rib30-dropdown-arrow-icon"
            "::before{content:\"\"!important;display:block!important;position:absolute!important;left:1px!important;top:-1px!important;width:5px!important;height:5px!important;background:transparent!important;background-color:transparent!important;border:0!important;border-right:1.5px solid #d6d9d9!important;border-bottom:1.5px solid #d6d9d9!important;box-sizing:border-box!important;transform:rotate(45deg)!important;-webkit-transform:rotate(45deg)!important;filter:none!important;-webkit-filter:none!important;}#search#search .sf-rib30-dropdown-title .sf-rib30-dropdown-arrow-icon::after{content:none!important;}#search#search .rufus-expandable-pills-chevron{background:transparent!important;background-color:transparent!important;border-color:transparent!important;box-shadow:none!important;}#search#search .rufus-expandable-pills-chevron img{background-color:transparent!important;filter:none!important;-web"
            "kit-filter:none!important;mix-blend-mode:normal!important;opacity:1!important;}#search#search :is(#rufus-overviews-pills-carousel,#rufus-mobile-overviews-expandable-pills-carousel-container) .a-carousel-card{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;}#search#search :is(#rufus-overviews-pills-carousel,#rufus-mobile-overviews-expandable-pills-carousel-container) :is(.nile-inline-pill-button,.nile-inline-ingress-pill-button,.a-button,[role=button],.a-carousel-card>a){background:#4a4f51!important;background-color:#4a4f51!important;background-image:none!important;border:1px solid #34383a!important;border-color:#34383a!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search :is(#rufus-overviews-pills-carousel,#rufus-m"
            "obile-overviews-expandable-pills-carousel-container) :is(.nile-inline-pill-button,.nile-inline-ingress-pill-button,.a-button,[role=button],.a-carousel-card>a) .a-button-inner{background:#4a4f51!important;background-color:#4a4f51!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search :is(#rufus-overviews-pills-carousel,#rufus-mobile-overviews-expandable-pills-carousel-container) :is(.nile-inline-pill-button,.nile-inline-ingress-pill-button,.a-button,[role=button],.a-carousel-card>a) .a-button-text{background:transparent!important;background-color:transparent!important;background-image:none!important;border:0!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search :is(#rufus-overviews-pills-carousel,#rufus-mobile"
            "-overviews-expandable-pills-carousel-container) :is(.nile-inline-pill-button,.nile-inline-ingress-pill-button,.a-button,[role=button],.a-carousel-card>a) :is(.a-button-text,span,p,strong,b,div){color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search :is(#rufus-overviews-pills-carousel,#rufus-mobile-overviews-expandable-pills-carousel-container) :is(.nile-inline-pill-button,.nile-inline-ingress-pill-button,.a-button,[role=button],.a-carousel-card>a)::before,#search#search :is(#rufus-overviews-pills-carousel,#rufus-mobile-overviews-expandable-pills-carousel-container) :is(.nile-inline-pill-button,.nile-inline-ingress-pill-button,.a-button,[role=button],.a-carousel-card>a)::after{background:transparent!important;background-color:transparent!important;background-image:none!important;box-shadow:none!important;}#search #rufus-overviews-category-cards-carousel .a-carousel-ca"
            "rd,#search #rufus-overviews-category-cards-carousel .a-carousel-card > .a-box,#search #rufus-overviews-category-cards-carousel .a-carousel-card > .a-box > .a-box-inner{background:#000!important;background-color:#000!important;border-color:#494d4d!important;box-shadow:none!important;}#search #rufus-overviews-category-cards-carousel .a-carousel-card :is(span,a,p,strong,b,div){color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search .puis-atcb-button{background:#000!important;background-color:#000!important;border:1px solid #747a7c!important;box-shadow:inset 0 0 0 1px #747a7c!important;filter:none!important;-webkit-filter:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#search#search .puis-atcb-button .a-button-inner{background:transparent!important;background-color:transparent!important;border-color:transparent!important;box-shadow:none!"
            "important;}#search#search .puis-atcb-button .a-button-text{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}.puis-mab-chevron :is(i.a-icon-dropdown,.a-icon.a-icon-dropdown),.puis-mab-chevron-glyph :is(i.a-icon-dropdown,.a-icon.a-icon-dropdown){filter:brightness(0) invert(1)!important;opacity:1!important;}#search [data-a-badge-color=\"sx-cloud\"],#search [data-a-badge-color=\"sx-cloud\"] :is(.a-badge-label,.a-badge-label-inner,.a-badge-text){background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;color:#ffd814!important;-webkit-text-fill-color:#ffd814!important;}#search [data-a-badge-color=\"sx-cloud\"]::before,#search [data-a-badge-color=\"sx-cloud\"]::after,#search [data-a-badge-color=\"sx-cloud\"] :is(.a-badge-label,.a-badge-label-inner)::before,#search [data-a"
            "-badge-color=\"sx-cloud\"] :is(.a-badge-label,.a-badge-label-inner)::after{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;}#search .a-color-success{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;color:#00a650!important;-webkit-text-fill-color:#00a650!important;}#search .a-badge[data-a-badge-type=\"deal\"]{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search .a-badge[data-a-badge-type=\"deal\"]>.a-badge-label{background:#cc0c39!important;background-color:#cc0c39!important;backgro"
            "und-image:none!important;border-color:#cc0c39!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search .a-badge[data-a-badge-type=\"deal\"] .a-badge-label-inner{background:transparent!important;background-color:transparent!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search .puis-ad-feedback-info-icon{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;background-color:transparent!important;}#search .puis-ad-feedback-info-icon b[class*=\"ad-feedback-sprite\"]{color:#b1aaa0!important;background-color:#b1aaa0!important;filter:none!important;-webkit-filter:none!important;}"
            /* v7.156: restore cheap direct Search structural owners omitted by the v7.154 fast lane. */
            "#search>div,#search>section,#search>article,#search .s-main-slot>div,#search .s-main-slot>section,#search .s-main-slot>article{background-color:#000!important;background-image:none!important;box-shadow:none!important;}"
            "#search :is(div,section,article)[class*=rufus],#search :is(div,section,article)[id*=rufus],#search :is(div,section,article)[class*=alexa],#search :is(div,section,article)[id*=alexa],#search :is(div,section,article)[class*=research],#search :is(div,section,article)[id*=research]{background:#000!important;background-color:#000!important;border-color:#494d4d!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            /* Search focus/autocomplete first-paint floor: exact known roots only. */
            "#attach-to-me,.s-suggestion-container,.s-suggestion,.autocomplete-results-container{background:#000!important;background-color:#000!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            "#attach-to-me :is(.s-suggestion-container,.s-suggestion,.s-query-row,.s-query-row-container,.s-query-row-link),#a-page :is([id^=sac-query-row-].s-query-row,.s-query-row-container,.s-query-row-link){background:#000!important;background-color:#000!important;-webkit-tap-highlight-color:transparent!important;box-shadow:none!important;}"
            /* Expanded ribbon footer actions match the established medium-gray controls. */
            "#search .sf-rib30-panel .a-button,#search .sf-rib30-panel .a-button-inner,#search .sf-rib30-panel button{background:#202324!important;background-color:#202324!important;background-image:none!important;border-color:#747a7c!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#search .sf-rib30-panel .a-button-text{background:transparent!important;background-color:transparent!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            /* Exact deal ownership wins after sx-cloud/Natural so Limited time deal stays white. */
            "#search .a-badge[data-a-badge-type=\"deal\"],#search .a-badge[data-a-badge-type=\"deal\"] *,#search .a-badge[id^=DEAL_],#search .a-badge[id^=DEAL_] *{color:#fff!important;-webkit-text-fill-color:#fff!important;}"
            /* Stock white two-cards shell; blacken only inner artwork. */
            "#search .mlt-icon-container :is(img,svg,i,[class*=glyph],[class*=icon]){color:#0f1111!important;fill:#0f1111!important;stroke:#0f1111!important;filter:brightness(0)!important;-webkit-filter:brightness(0)!important;opacity:1!important;mix-blend-mode:normal!important;}"
            "';function ad7RelinkSearch(){try{if(ss&&!ss.isConnected)(document.head||document.documentElement).appendChild(ss)}catch(_){}}if(document.readyState==='loading')window.addEventListener('load',ad7RelinkSearch,{once:true});else ad7RelinkSearch();return;}"
            "var id='ad7-static-theme',s=document.getElementById(id);"
            "if(!s){s=document.createElement('style');s.id=id;(document.head||document.documentElement||document).appendChild(s);}"
            "s.textContent='"
            "html,body,#a-page,#gwm-PageContent,#dp,main,[role=main],#search,#cart-page,#sc-active-cart,#sc-saved-cart{background:#000!important;background-color:#000!important;}.s-result-item,[data-component-type=s-search-result],.s-card-container,.s-main-slot,#sc-active-cart .sc-list-item,#sc-saved-cart .sc-list-item,[class*=sc-][class*=content],[class*=sc-][class*=container],#dp [class*=a-box],#dp [class*=a-expander],#dp [class*=celwidget]:not([class*=image]):not([class*=media]),#authportal-main-section,#auth-footer,.auth-footer,[id*=auth-footer],[class*=variation],[class*=swatch-container],[class*=status-shell],[class*=badge-message],[class*=puis-card]:not([class*=creative]):not([class*=image]),[class*=product-card]:not([class*=image]){background-color:#181a1b!important;}.s-suggestion-container,.s-suggestion,.autocomplete-results-container,[class*=autocomplete],[class*=suggestion]:not([class*=ico"
            "n]):not([class*=glyph]),[class*=recentSearch]:not([class*=icon]):not([class*=glyph]),[class*=search-suggestion]:not([class*=icon]):not([class*=glyph]){background:#000!important;background-color:#000!important;color:#e8e6e3!important;}:is(.s-suggestion-container,.s-suggestion,.autocomplete-results-container,[class*=autocomplete],[class*=recentSearch],[class*=search-suggestion]) :is(h1,h2,h3,h4,h5,h6,p,span,a,div){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}.s-suggestion-section-heading,.sac-header-component-single-line-header{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#a-page :is([id^=sac-query-row-].s-query-row,.s-query-row-container,.s-query-row-link){background:#000!important;background-color:#000!important;-webkit-tap-highlight-color:transparent!important;}#a-page :is([id^=sac-query-row-].s-query-row,.s-query-row-container,.s-query-row-li"
            "nk):is(:active,:focus,:focus-visible,:focus-within){background:#000!important;background-color:#000!important;-webkit-tap-highlight-color:transparent!important;box-shadow:none!important;}#attach-to-me :is([class*=location],[class*=delivery],[id*=location],[id*=delivery],[class*=glow],[id*=glow],[class*=ship-to],[id*=ship-to],[class*=shipto],[id*=shipto]):not(img):not(svg):not(i):not([class*=icon]):not([class*=glyph]):not([id*=icon]){background-color:#000!important;border-color:#494d4d!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#attach-to-me :is(div,section,a):has(:is([class*=location],[class*=delivery],[id*=location],[id*=delivery],[class*=glow],[id*=glow],[class*=ship-to],[id*=ship-to],[class*=shipto],[id*=shipto])){background-color:#000!important;border-color:#494d4d!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#attach-t"
            "o-me :is([class*=location],[class*=delivery],[id*=location],[id*=delivery],[class*=glow],[id*=glow],[class*=ship-to],[id*=ship-to],[class*=shipto],[id*=shipto]) :is(span,a,p,div,label,strong,b){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#attach-to-me :is([class*=location],[class*=delivery],[id*=location],[id*=delivery],[class*=glow],[id*=glow],[class*=ship-to],[id*=ship-to],[class*=shipto],[id*=shipto]) :is(img,svg,i,[class*=icon],[class*=glyph],[id*=icon]){background-color:transparent!important;color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;}:is(.a-color-base,.a-text-normal,.a-size-base,.a-size-base-plus,.a-size-medium,.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen,.s-title-instructions-style,.a-link-normal h2,[class*=product-"
            "title],[class*=heading],[class*=title]:not([class*=badge])):not(:where(#search *)):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-]):not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)):not(:where(html[data-ad7-child-frame] *)):not(:where(#gwm-Deck *)):not(:where([class*=hero] *)):not(:where([class*=single-creative] *)):not(:where([class*=single-video] *)):not(:where([class*=theming-card] *)){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}:is(.a-color-secondary,.a-size-small,[class*=secondary]):not(:where(#search *)):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-]):not(:where([cl"
            "ass*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)):not(:where(html[data-ad7-child-frame] *)):not(:where(#gwm-Deck *)):not(:where([class*=hero] *)):not(:where([class*=single-creative] *)):not(:where([class*=single-video] *)):not(:where([class*=theming-card] *)){color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;}.s-result-item,.s-card-container,[data-component-type=s-search-result],#sc-active-cart .sc-list-item,#sc-saved-cart .sc-list-item,#dp .a-box,#dp .a-divider,#dp [class*=card],.s-suggestion-container,#auth-footer .a-divider,.auth-footer .a-divider,[class*=swatch-outer-circle],[class*=puis-card]{border-color:#494d4d!important;outline-color:#494d4d!important;}.a-divider-inner:after,.a-divider-inner:before,hr,[class*=separator]{border-color:#494d4d!important;backgroun"
            "d-color:#494d4d!important;}#wd-backdrop-gradient,.wd-backdrop-gradient,[class*=wd-backdrop-gradient],[class*=a-reactive-container],[class*=reactive-contain],#auth-footer,.auth-footer,[id*=auth-footer]{background-image:none!important;box-shadow:none!important;}#auth-footer .a-divider-inner,.auth-footer .a-divider-inner{background-image:none!important;box-shadow:none!important;}.s-color-swatch-container,.s-color-swatch-outer-circle{background-color:transparent!important;}.s-color-swatch-outer-circle{border-color:#494d4d!important;outline-color:#494d4d!important;}[class*=nav-search] img,[class*=searchbar] img,[class*=search-bar] img,[role=search] img,[class*=nav-] img[class*=icon],[class*=header] img[class*=icon]{background-color:transparent!important;}.s-suggestion-container :is(img[class*=icon],img[alt*=search],img[alt*=arrow],svg,i.a-icon,[class*=glyph]),.s-suggestion :is(img[class*=icon"
            "],img[alt*=search],img[alt*=arrow],svg,i.a-icon,[class*=glyph]){color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;}.s-suggestion-container i.icon-past-search-suggestion.s-suggestion-icon-left{background-color:transparent!important;color:#9da3a3!important;fill:#9da3a3!important;stroke:#9da3a3!important;filter:brightness(0) invert(1) brightness(0.65)!important;-webkit-filter:brightness(0) invert(1) brightness(0.65)!important;opacity:1!important;box-shadow:none!important;}.s-suggestion-container i.icon-close.s-suggestion-icon-left{background-color:transparent!important;color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;opacity:1!important;box-shadow:none!important;}.s-que"
            "ry-row i.icon-search-suggestion.s-query-row-search-icon,.s-suggestion-container i:is([class*=icon-search],[class*=search-icon]),.s-suggestion i:is([class*=icon-search],[class*=search-icon]),.s-suggestion-container i.s-suggestion-icon-right{background-color:transparent!important;color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;filter:brightness(0) invert(1) brightness(0.91)!important;-webkit-filter:brightness(0) invert(1) brightness(0.91)!important;opacity:1!important;box-shadow:none!important;}.puis-mab-overlay-row-share .puis-mab-overlay-icon-share{background-color:#e8e6e3!important;color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;filter:none!important;}:is(#gwm-PageContent,#gwm-Deck-btf) :is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf],[class*=hp-mosaic-container_style_container],[class*=_mosaic-container_style_wi"
            "dgetContainer]){background-color:#000!important;border-color:#494d4d!important;mix-blend-mode:normal!important;isolation:auto!important;}.gwm-dashboard-container :is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]){background-color:#000!important;border-color:#494d4d!important;mix-blend-mode:normal!important;isolation:auto!important;}:is(#gwm-PageContent,#gwm-Deck-btf,#gwm-Deck,.gwm-dashboard-container) :is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]) img:not([class*=logo]):not([class*=avatar]):not([class*=profile]):not([class*=merchant]):not([class*=seller]):not([class*=brand]):not([class*=store]):not([class*=rating]):not([class*=star]):not([class*=sprite]):not([class*=pixel]):not([class*=icon]):not([class*=glyph]):not([class*=badge]):not([class*=checkbox]):not([class*=heart]):not([class*=wishlist]):not(:where([class*=sponsored] *)):no"
            "t(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)){mix-blend-mode:normal!important;isolation:auto!important;background-color:transparent!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]) :is(picture,[class*=image-wrapper],[class*=img-wrapper],[class*=image-container]){mix-blend-mode:normal!important;isolation:auto!important;background-color:transparent!important;}:is(#gwm-PageContent,#gwm-Deck-btf,#gwm-Deck,.gwm-dashboard-container) :is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]) [class*=asin-metadata]{mix-blend-mode:normal!important;isolation:auto!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) [class*=multi-category-card] img{mix-blend-mode:normal!important;isolation:auto!important;backgr"
            "ound-color:transparent!important;}:is(#gwm-PageContent,#gwm-Deck-btf,#gwm-Deck,.gwm-dashboard-container) [class*=badgeMessage]{background-color:transparent!important;box-shadow:none!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]) :is(h1,h2,h3,h4,h5,h6,p,span,a):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-]):not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)):not([class*=badge]):not([class*=deal]):not([class*=coupon]):not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=hero] *)):not(:where([class*=single-creative] *)):not(:where([class*=single-v"
            "ideo] *)):not(:where([class*=theming-card] *)):not(:where([class*=creative-card] *)):not(:where([class*=ad-card] *)):not(:where([class*=canvas-card] *)):not(:where([class*=mobile-mshop-ad] *)):not(:where([class*=mobile-ad-container] *)):not(:where([class*=ape-wrapper] *)):not(:where([class*=ape-placement] *)){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is(.a-color-base,.a-text-normal,.a-size-base,.a-size-base-plus,.a-size-medium,.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen,[class*=product-title],[class*=product-name],[class*=item-title]):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-]):not([class*=badge]):not([class*=deal]):not([class*=coupon]):not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:"
            "where([class*=coupon] *)):not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)):not(:where([class*=hero] *)):not(:where([class*=single-creative] *)):not(:where([class*=single-video] *)):not(:where([class*=theming-card] *)):not(:where([class*=creative-card] *)):not(:where([class*=ad-card] *)):not(:where([class*=canvas-card] *)):not(:where([class*=mobile-mshop-ad] *)):not(:where([class*=mobile-ad-container] *)):not(:where(#mobile-third-party-ad *)):not(:where([class*=ape-wrapper] *)):not(:where([class*=ape-placement] *)){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) .a-cardui-header :is(h1,h2,h3,h4,h5,h6,a,span,p):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([id^=ad-feedback-tex"
            "t-]):not([id^=af-label-primary-link-]){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) .a-cardui :is([class*=wpTitle],[class*=windowPaneHeaderContainer]){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is(h1,h2,h3,h4,h5,h6):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-]):not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)):not([class*=badge]):not([class*=deal]):not([class*=coupon]):not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=hero] *)):not(:where([class*=single-creative] *)):not(:where([class*=sin"
            "gle-video] *)):not(:where([class*=theming-card] *)):not(:where([class*=creative-card] *)):not(:where([class*=ad-card] *)):not(:where([class*=canvas-card] *)):not(:where([class*=mobile-mshop-ad] *)):not(:where([class*=mobile-ad-container] *)):not(:where([class*=ape-wrapper] *)):not(:where([class*=ape-placement] *)){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}:is(#gwm-PageContent,#gwm-Deck-btf,.gwm-dashboard-container) :is([class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer]) :is(div,section,article,ul,ol,li,a,p,span,h1,h2,h3,h4,h5,h6):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-]){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}:is(#gwm-PageContent,#gwm-Deck-btf,.gwm-dashboard-container) :is([class*=hp-mosaic-container],[class*=_mosa"
            "ic-container_style_widgetContainer]) :is([class*=next],[class*=prev],[class*=chevron],[class*=arrow]){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;}.puis-mab-chevron :is(i.a-icon-dropdown,.a-icon.a-icon-dropdown),.puis-mab-chevron-glyph :is(i.a-icon-dropdown,.a-icon.a-icon-dropdown){filter:brightness(0) invert(1)!important;opacity:1!important;}:is(#gwm-PageContent,#gwm-Deck,#gwm-Deck-btf,.gwm-dashboard-container) i.a-icon.a-icon-dropdown,:is(#gwm-PageContent,#gwm-Deck-btf,.gwm-dashboard-container) :is([class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer],[class*=_npack-asin-card_style_theming-background-override__]) :is([class*=next],[class*=prev],[class*=chevron],[class*=arrow]) :is(i.a-icon,.a-icon,[class*=glyph]),:is(#gwm-PageContent,#gwm-Deck-btf,.gwm-dashboard-container) :is([class*=hp-mosai"
            "c-container],[class*=_mosaic-container_style_widgetContainer],[class*=_npack-asin-card_style_theming-background-override__]) :is(i.a-icon-dropdown,i[class*=chevron],i[class*=arrow]){filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;opacity:1!important;}i.a-icon.a-icon-dropdown,.a-icon.a-icon-dropdown,i[class*=chevron],i[class*=arrow],[class*=chevron-glyph],[class*=puis-mab-chevron] :is(i.a-icon-dropdown,.a-icon.a-icon-dropdown){filter:brightness(0) invert(1) brightness(0.91)!important;-webkit-filter:brightness(0) invert(1) brightness(0.91)!important;opacity:1!important;visibility:visible!important;mix-blend-mode:normal!important;}:is([class*=a-cardui],[class*=npack-asin-card],[class*=gwm-asin-tile],[class*=gwm-window-layout],[class*=window-container],[class*=gwm-dashboard-container],[class*=wd-backdrop],[class*=theming-card],[class*=a-unordered-lis"
            "t],[class*=mosaic-container],[class*=puis-card],[class*=gwm-tile],[class*=_container_]):not([class*=deal]):not([class*=badge]):not([class*=prime]):not([class*=error]):not([class*=alert]):not([class*=warning]){border-color:#3b4043!important;outline-color:#3b4043!important;}:is([class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer]) :is(div,section,article,ul,ol,li){border-color:#3b4043!important;outline-color:#3b4043!important;}[data-csa-c-painter=amazon-shopping-guides-quad-card-cards] [class*=_colored-background_],[data-csa-c-painter=amazon-shopping-guides-quad-card-cards] [class*=_product-image_],[data-csa-c-painter=amazon-shopping-guides-quad-card-cards] [class*=_image_]{mix-blend-mode:normal!important;isolation:auto!important;}[data-csa-c-painter=amazon-shopping-guides-quad-card-cards] [class*=_colored-background_]{background:#000!important;background-color:#00"
            "0!important;border-color:#000!important;outline-color:#000!important;box-shadow:none!important;transition-property:none!important;}@media (max-height:260px) and (min-aspect-ratio:5/3){html[data-ad7-standalone-candidate],html[data-ad7-standalone-candidate] body{background:#000!important;background-color:#000!important;color:#e8e6e3!important;}html[data-ad7-standalone-candidate] :is(div,section,article,main,header,footer,ul,ol,li){background-color:transparent!important;border-color:#3b4043!important;}html[data-ad7-standalone-candidate] :is(h1,h2,h3,h4,h5,h6,p,span,a,strong,small,b,em,label):not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-]):not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):n"
            "ot(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}html[data-ad7-standalone-candidate] :is(img,picture,video,canvas,svg){background-color:transparent!important;}}html[data-ad7-standalone-candidate] :is(body,#ad,section[data-is-ad=true],[data-testid=ad-background-container]){background:#000!important;background-color:#000!important;color:#e8e6e3!important;}html[data-ad7-standalone-candidate] [data-testid=ad-background-container]{background:#000!important;background-color:#000!important;background-image:none!important;border-color:#3b4043!important;outline-color:#3b4043!important;box-shadow:none!important;}html[data-ad7-standalone-candidate] [data-testid=ad-background-container] > div{background:#000!important;background-color:#000!important;background-image:none!important;}html[data-ad7-standalone-candidate] #"
            "ad[data-html-dimensions=\"300x250\"]{background:#000!important;background-color:#000!important;}html[data-ad7-standalone-candidate] #ad[data-html-dimensions=\"300x250\"] [data-testid=gridContainer]{background:#000!important;background-color:#000!important;background-image:none!important;}html[data-ad7-standalone-candidate] #ad[data-html-dimensions=\"300x250\"] :is(div,section,article,main,header,footer,ul,ol,li):not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=prime]):not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=prime] *)){background-color:transparent!important;}html[data-ad7-standalone-candidate] #ad[data-html-dimensions=\"300x250\"] .swiper-slide > [class*=border-gray-]{border-color:#3b4043!important;outline-color:#3b4043!important;box-shadow:none!important;}html[data-ad7-standalone-candidate] #ad[da"
            "ta-html-dimensions=\"300x250\"] :is(h1,h2,h3,h4,h5,h6,p,span,a,strong,small,b,em,label,div):not(div:has([class*=prime],[data-testid*=prime],[class*=star],[data-testid*=star])):not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=prime]):not([class*=star]):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([data-testid*=prime]):not([data-testid*=star]):not(:where([data-testid*=prime] *)):not(:where([data-testid*=star] *)):not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=prime] *)):not(:where([class*=star] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}html[data-ad7-standalone-candidate] #ad[data-html-dimensions=\"300x250\"] :is(div,span,p,a,small,strong,b)[class*=sponsored],html[data-ad7-st"
            "andalone-candidate] #ad[data-html-dimensions=\"300x250\"] :is(div,span,p,a,small,strong,b)[data-testid*=sponsored]{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}html[data-ad7-standalone-candidate] [data-testid=renderer-factory-ad-container] [data-testid^=modern-][data-testid$=-layout-container]{background:#000!important;background-color:#000!important;border-color:#3b4043!important;outline-color:#3b4043!important;box-shadow:none!important;}html[data-ad7-standalone-candidate] [data-testid=renderer-factory-ad-container] [data-testid=content]{background:#000!important;background-color:#000!important;}html[data-ad7-standalone-candidate] #dynamic-bb [data-testid=deal-badge] > div[style*=\"background-color: rgb(255, 255, 255)\"]{background-color:transparent!important;box-shadow:none!important;}html[data-ad7-standalone-candidate] [data-testid=renderer-fa"
            "ctory-ad-container] :is([data-id=brand-name-text],[data-id=product-name-text],[data-testid=ratings-value],[data-testid=formatted-price],[data-testid=formatted-price] *){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}html[data-ad7-standalone-candidate] [data-testid=renderer-factory-ad-container] :is([data-testid=ratings-review-count],[data-testid=full-price]){color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;}html[data-ad7-standalone-candidate] [data-testid=brand-product-description] p,html[data-ad7-standalone-candidate] [data-testid=ratings-value],html[data-ad7-standalone-candidate] [data-testid=price-container] :is(div,span):not([data-testid=full-price]):not([data-testid=prime-badge]):not(:where([data-testid=prime-badge] *)),html[data-ad7-standalone-candidate] [data-testid=sns-coupon-badge-container] :is(div,span,p),html[data-ad7-standalone-candidate]"
            " [data-testid=ad-background-container] :is(p,span,div,a,small,strong,b)[style*=\"color: rgb(15, 17, 17)\"]:not(:where([data-testid=ratings-stars] *)):not(:where([data-testid=prime-badge] *)),html[data-ad7-standalone-candidate] [data-testid=ad-background-container] :is(p,span,div,a,small,strong,b)[style*=\"color: black\"]:not(:where([data-testid=ratings-stars] *)):not(:where([data-testid=prime-badge] *)){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}html[data-ad7-standalone-candidate] [data-testid=ratings-review-count],html[data-ad7-standalone-candidate] [data-testid=full-price],html[data-ad7-standalone-candidate] [data-testid=ad-background-container] :is(p,span,div,a,small,strong,b)[style*=\"color: rgb(86, 89, 89)\"],html[data-ad7-standalone-candidate] [data-testid=ad-background-container] :is(p,span,div,a,small,strong,b)[style*=\"color:#565959\"]{color:#b1aaa0!impor"
            "tant;-webkit-text-fill-color:#b1aaa0!important;}html[data-ad7-standalone-candidate] :is([data-testid*=product-picture],[data-testid*=product-image],[data-testid*=asin-image],picture){background-color:transparent!important;box-shadow:none!important;}picture,img,video,canvas,#imgTagWrapperId,.s-product-image-container,[data-component-type=s-product-image],[class*=image-wrapper],[class*=img-wrapper],[class*=image-container],[class*=product-image],[class*=asin-image]{background-color:transparent!important;}[class*=ape-wrapper],[class*=ape-placement],[class*=ape-feedback]:not(:where(#gwm-window *)):not(:where([class*=single-creative-card] *)):not(:where([class*=single-video-card] *)):not([id*=mobile-wd-]){background-color:transparent!important;border-color:transparent!important;outline-color:transparent!important;box-shadow:none!important;}iframe[id*=ape_],iframe[class*=ape_]{background-color"
            ":transparent!important;border-color:transparent!important;outline-color:transparent!important;}.ape-wrapper[style*=\"--ad-height:50\"] > .ape-placement[style*=\"aspect-ratio: 320 / 50\"]{border-color:#3b4043!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is([class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data-testid*=carousel])){background:#000!important;background-color:#000!important;border-color:#3b4043!important;outline-color:#3b4043!important;box-shadow:none!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is([class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data-testid*=carousel])) :is(div,section,article,main,header,footer,ul,ol,li):not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=prime]):not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):"
            "not(:where([class*=prime] *)){background-color:transparent!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is([class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data-testid*=carousel])) :is(h1,h2,h3,h4,h5,h6,p,span,a,strong,small,b,em,label):not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=prime]):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([data-testid=prime-badge]):not(:where([data-testid=prime-badge] *)):not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=prime] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is([class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data"
            "-testid*=carousel])) :is(span,p,a,small,strong,b)[class*=sponsored],:is(#gwm-Deck-btf,.gwm-dashboard-container) :is([class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data-testid*=carousel])) :is(span,p,a,small,strong,b)[data-testid*=sponsored]{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}:is([class*=ad-feedback-text],[class*=ad-feedback-text-desktop],[id^=ad-feedback-text-],[id^=af-label-primary-link-],[aria-label^=\"Leave feedback on Sponsored\"]):not(:where(#gwm-window [id^=wd-shoppable-] *)):not(:where([id*=mobile-wd-] *)):not(:where([class*=single-creative-card] *)):not(:where([class*=single-video-card] *)):is(:focus,:focus-visible){outline:none!important;box-shadow:none!important;-webkit-tap-highlight-color:transparent!important;}body:has([id^=adFeedbackBottomSheet_]) :is(.a-sheet-web-container,.a-sheet-web,.a"
            "-sheet-content-container),body:has([id^=adFeedbackBottomSheet_]) [class*=ad-feedback-bottom-sheet-container],body:has([id^=adFeedbackBottomSheet_]) :is(#af-form-top-container,#mobile-ad-feedback-container){background:#000!important;background-color:#000!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}body:has([id^=adFeedbackBottomSheet_]) :is(#af-form-top-container,#mobile-ad-feedback-container) :is(div,section,article,form,fieldset,header,footer){background-color:transparent!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}body:has([id^=adFeedbackBottomSheet_]) :is(#af-form-top-container,#mobile-ad-feedback-container) :is(h1,h2,h3,h4,h5,h6,p,span,label,legend,small,strong,b,a){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container textarea{background:"
            "#303335!important;background-color:#303335!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;border-color:#6f6f6f!important;box-shadow:none!important;}body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container input[type=checkbox]{background-color:#000!important;border-color:#b1aaa0!important;accent-color:#303335!important;color-scheme:dark!important;}body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container :is(.a-icon-checkbox,i.a-icon-checkbox){filter:invert(1)!important;-webkit-filter:invert(1)!important;opacity:1!important;}body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container :is(.a-button,.a-button-inner,button,input[type=button],input[type=submit]){background:#181a1b!important;background-color:#181a1b!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;border-color:#6f6f6f!important;box-shadow:n"
            "one!important;}body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container :is(button,input[type=button],input[type=submit]):disabled,body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container .a-button-disabled{background:#181a1b!important;background-color:#181a1b!important;color:#8a8a8a!important;-webkit-text-fill-color:#8a8a8a!important;border-color:#494d4d!important;}input:not([type=button]):not([type=submit]),textarea,select{background-color:#181a1b!important;color:#e8e6e3!important;border-color:#494d4d!important;}::placeholder{color:#b1aaa0!important;opacity:1!important;}[class*=header-icon],[class*=header-icon] path,[class*=header-icon] use,[class*=header-link] svg path,[class*=cardui-header] svg path,a[class*=header-link] path,[class*=see-more] path,[class*=view-all] path{fill:#e8e6e3!important;stroke:#e8e6e3!important;color:#e8e6e3!important;opacity:1!importan"
            "t;}[class*=hp-mosaic-container] .a-icon-next-rounded,[class*=hp-mosaic-container] .a-icon-previous-rounded,[class*=hp-mosaic-container] [class*=chevron],[class*=hp-mosaic-container] [class*=arrow],[class*=_mosaic-container_style_widgetContainer] .a-icon-next-rounded,[class*=_mosaic-container_style_widgetContainer] .a-icon-previous-rounded,[class*=_mosaic-container_style_widgetContainer] [class*=chevron],[class*=_mosaic-container_style_widgetContainer] [class*=arrow],.a-icon-next-rounded,.a-icon-previous-rounded{filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;opacity:1!important;color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;}:is([class*=_npack-asin-card_style_ad-feedback-spr],[class*=_npack-asin-card_style_ad-feedback-sprite],[class*=_cXVhZ_ad-feedback-spr],[class*=_cXVhZ_ad-feedback-sprite],[class*=_sponsored-products-mo"
            "]):not(:where(#gwm-window [id^=wd-shoppable-] *)):not(:where([id*=mobile-wd-] *)):not(:where([class*=single-creative-card] *)):not(:where([class*=single-video-card] *)){color:#e8e6e3!important;background-color:#e8e6e3!important;filter:none!important;-webkit-filter:none!important;opacity:1!important;}html body [data-ad-feedback-label-id] b[class*=ad-feedback-sprite-mobile][class*=labelThemeStyle_ad-feedback-sprite-mobile]:not(:where(#gwm-window [id^=wd-shoppable-] *)):not(:where([id*=mobile-wd-] *)):not(:where([class*=single-creative-card] *)):not(:where([class*=single-video-card] *)),html body [data-ad-feedback-label-id] b[class*=ad-feedback-sprite-mobile]:not(:where(#gwm-window [id^=wd-shoppable-] *)):not(:where([id*=mobile-wd-] *)):not(:where([class*=single-creative-card] *)):not(:where([class*=single-video-card] *)){color:inherit!important;background-color:currentColor!important;backg"
            "round-image:none!important;-webkit-mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;-webkit-mask-size:contain!important;mask-size:contain!important;-webkit-mask-repeat:no-repeat!important;mask-repeat:no-repeat!important;-webkit-mask-position:center!important;mask-position:center!important;filter:none!important;-webkit-filter:none!important;opacity:1!important;}html body :is([class*=widget-sponsored-badge-container],[class*=asin-sponsored-badge-container]) [data-ad-feedback-label-id] [class*=ad-feedback-text]{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}html body :is([class*=widget-sponsored-badge-container],[class*=asin-sponsored-badge-container]) [data-ad-feedback-label-id] [class*=ad-feedback-text] >"
            " b[class*=ad-feedback-sprite-mobile]{color:#b1aaa0!important;background-color:#b1aaa0!important;background-image:none!important;-webkit-mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;-webkit-mask-size:contain!important;mask-size:contain!important;-webkit-mask-repeat:no-repeat!important;mask-repeat:no-repeat!important;-webkit-mask-position:center!important;mask-position:center!important;filter:none!important;-webkit-filter:none!important;opacity:1!important;}html body :is(.ape-feedback,[id^=ape_][id*=\"_Feedback\"]):not(:where(#gwm-window [id^=wd-shoppable-] *)):not(:where([id*=mobile-wd-] *)):not(:where([class*=single-creative-card] *)):not(:where([class*=single-video-card] *)) [id^=ad-feedback-text-]{color:#b1aaa0!important;-webkit-text-fil"
            "l-color:#b1aaa0!important;opacity:1!important;}html body :is(.ape-feedback,[id^=ape_][id*=\"_Feedback\"]):not(:where(#gwm-window [id^=wd-shoppable-] *)):not(:where([id*=mobile-wd-] *)):not(:where([class*=single-creative-card] *)):not(:where([class*=single-video-card] *)) [id^=ad-feedback-sprite-]{color:#b1aaa0!important;background-color:#b1aaa0!important;background-image:none!important;-webkit-mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;-webkit-mask-size:contain!important;mask-size:contain!important;-webkit-mask-repeat:no-repeat!important;mask-repeat:no-repeat!important;-webkit-mask-position:center!important;mask-position:center!important;filter:none!important;-webkit-filter:none!important;opacity:1!important;}[class*=_hp-mosaic-container"
            "_style_loadingSpinner]::after{background:#000!important;background-color:#000!important;box-shadow:none!important;}#gwm-CardLoadingIndicator.gwm-LoadingIndicator::after{background:#000!important;background-color:#000!important;box-shadow:none!important;}::-webkit-scrollbar{background-color:transparent!important;}::-webkit-scrollbar-track{background-color:transparent!important;}::-webkit-scrollbar-thumb{background-color:#6f6f6f!important;border-radius:8px!important;border:2px solid transparent!important;background-clip:content-box!important;}::-webkit-scrollbar-thumb:hover{background-color:#8a8a8a!important;}"
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
        @"(function(){try{if(window.top===window)return;var host='';try{host=String(location.hostname||'').toLowerCase();}catch(_){}if(host==='flashtalking.com'||/\\.flashtalking\\.com$/.test(host))return;var h=document.documentElement;if(!h)return;"
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
         /* v7.144: host-name-independent compact fallback. If Amazon moves the full-raster
          * creative out of lfstyl-img/prod-img, keep TWB on visible media inside the exact
          * dynamic-bb compact renderer while protecting Prime/rating/Sponsored control art. */
         "html[data-ad7104-standalone] #ad:has(#dynamic-bb) :is(img,video,canvas)"
         ":not([class*=prime]):not([class*=rating]):not([class*=star]):not([class*=icon]):not([class*=glyph]):not([class*=sprite]):not([class*=pixel]):not([class*=badge])"
         ":not(:where([data-testid=prime-badge] *)):not(:where([data-testid=ratings-stars] *)):not(:where([data-ad-feedback-label-id] *)):not(:where([class*=ad-feedback] *)),"
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
         /* v7.135: do not filter the entire #mobile-third-party-ad subtree.
          * Current AT&T video keeps the 430x358 APE SafeFrame mounted but paints black;
          * whole-subtree CSS filter ownership is removed so WebKit can composite the
          * nested third-party video/iframe natively. */
         "';"
         "function black(){try{h=document.documentElement||h;if(!h)return;h.setAttribute('data-ad7104-standalone','1');h.style.setProperty('background-color','#000','important');h.style.setProperty('color-scheme','dark','important');if(document.body){document.body.style.setProperty('background-color','#000','important');document.body.style.setProperty('color-scheme','dark','important')}}catch(_){}}"
         "function own(){try{h=document.documentElement||h;if(!h)return false;black();if(!(document.adoptedStyleSheets&&window.CSSStyleSheet&&CSSStyleSheet.prototype&&CSSStyleSheet.prototype.replaceSync))return false;var sh=window[KEY];if(!sh){sh=new CSSStyleSheet();sh.replaceSync(CSS);window[KEY]=sh;}var a=document.adoptedStyleSheets||[],found=false;for(var i=0;i<a.length;i++)if(a[i]===sh){found=true;break;}if(!found)document.adoptedStyleSheets=a.concat([sh]);return true}catch(e){return false}}"
         "window.__ad7106StandaloneState=function(){try{var sh=window[KEY]||null,a=document.adoptedStyleSheets||[],found=false;for(var i=0;i<a.length;i++)if(a[i]===sh){found=true;break;}return{adoptedSupported:!!(document.adoptedStyleSheets&&window.CSSStyleSheet&&CSSStyleSheet.prototype&&CSSStyleSheet.prototype.replaceSync),sheet:!!sh,adopted:found,rules:sh&&sh.cssRules?sh.cssRules.length:0,htmlSame:(document.documentElement===h),attr:!!(document.documentElement&&document.documentElement.hasAttribute('data-ad7104-standalone'))}}catch(e){return{error:String(e)}}};"
         "own();document.addEventListener('readystatechange',function(){own()},false);window.addEventListener('pageshow',function(){own()},false);"
         "}catch(e){}})();",factor,factor,factor,factor];
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
        @"(function(){try{var host='';try{host=String(location.hostname||'').toLowerCase();}catch(_){}if(host==='flashtalking.com'||/\\.flashtalking\\.com$/.test(host))return;var child=0;try{child=window.top!==window;}catch(_){child=1;}if(child&&document.documentElement)document.documentElement.setAttribute('data-ad7-twb-child','1');"
         /* v7.154 performance: standalone child ads use ADStandalonePaintJS7104; productish
          * child frames get one compact media rule instead of the full main TWB sheet. */
         "if(child&&document.documentElement&&document.documentElement.hasAttribute('data-ad7-standalone-candidate'))return;"
         "if(child){var cid='ad7-twb-child-min',cs=document.getElementById(cid);if(!cs){cs=document.createElement('style');cs.id=cid;(document.head||document.documentElement||document).appendChild(cs);}cs.textContent='html[data-ad7-twb-child=\"1\"] :is(img,video,canvas):not([class*=logo]):not([class*=avatar]):not([class*=profile]):not([class*=merchant]):not([class*=seller]):not([class*=rating]):not([class*=star]):not([class*=checkbox]):not([class*=heart]):not([class*=wishlist]):not([class*=icon]):not([class*=glyph]):not([class*=badge]){filter:brightness(%.3f)!important;}';return;}"
         /* v7.154 zero-delay Search TWB: /s receives only the proven positive media lanes.
          * No global product-image selectors, background-image substring scans or :has() rules
          * are parsed in the live Search result document. */
         "var ad7tp='';try{ad7tp=String(location.pathname||'');}catch(_){}"
         "if(!child&&(ad7tp==='/s'||ad7tp.indexOf('/s/')===0)){var sid='ad7-search-twb-fast',ss=document.getElementById(sid);if(!ss){ss=document.createElement('style');ss.id=sid;(document.head||document.documentElement||document).appendChild(ss);}ss.textContent='"
         "#search img.s-image,#search img.s-product-image,#search [data-component-type=s-product-image] img,#search img.ufs_tiles_card_widget-sug-image,#search img.nice-cat-card_image,#search img.haul-puis-portrait-img,#search img._c2Itd_image_pQREQ{filter:none!important;-webkit-filter:none!important;opacity:%.3f!important;}"
         "#search video.sbv-video-player-ecx,#search video._c2Itd_video_17g-f{filter:none!important;-webkit-filter:none!important;}"
         "#search .sbv-video-overlay{background-color:rgba(0,0,0,%.3f)!important;}"
         "#search ._c2Itd_videoOverlay_1H_Jm{background-color:rgba(0,0,0,%.3f)!important;}"
         "';function ad7RelinkSearchTWB(){try{if(ss&&!ss.isConnected)(document.head||document.documentElement).appendChild(ss)}catch(_){}}if(document.readyState==='loading')window.addEventListener('load',ad7RelinkSearchTWB,{once:true});else ad7RelinkSearchTWB();return;}"
         "var id='ad7-twb-static',s=document.getElementById(id);"
         "if(!s){s=document.createElement('style');s.id=id;(document.head||document.documentElement||document).appendChild(s);}"
         "s.textContent='"
         /* Ordinary/product imagery. */
         /* v7.154 performance: Search TWB is positive ownership only. The former
          * `#search img` selector made every image in the large recycled feed evaluate
          * twenty-plus substring/ancestor exclusions. Stable product/media classes cover
          * the observed Search families without that hot path. */
         "#search img.s-image,#search img.s-product-image,"
         "#search [data-component-type=s-product-image] img,"
         "#search img.ufs_tiles_card_widget-sug-image,#search img.nice-cat-card_image,"
         "#search img.haul-puis-portrait-img,#search img._c2Itd_image_pQREQ,"
         /* v7.125 Search Deals-for-you image tiles from the exact ufs probe family. */
         "img.ufs_tiles_card_widget-sug-image,"
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
         /* v7.144: host-name-independent compact fallback; exact dynamic-bb scope only. */
         "html[data-ad7-standalone-candidate] #ad:has(#dynamic-bb) :is(img,video,canvas)"
         ":not([class*=prime]):not([class*=rating]):not([class*=star]):not([class*=icon]):not([class*=glyph]):not([class*=sprite]):not([class*=pixel]):not([class*=badge])"
         ":not(:where([data-testid=prime-badge] *)):not(:where([data-testid=ratings-stars] *)):not(:where([data-ad-feedback-label-id] *)):not(:where([class*=ad-feedback] *)),"
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
         /* v7.135: third-party Flashtalking/video creatives are intentionally absent
          * from TWB selector ownership. They render as stock opaque creatives so a
          * compositor filter cannot turn the nested video surface black. */
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
         /* v7.144: exact Home Window Display full-raster fallback. The v7.143
          * capture proves wd-shoppable-1 owns the 298.5x477.6 single-creative raster.
          * Keep the creative media on TWB even if Amazon changes the hashed image class,
          * while leaving Sponsored feedback control art fully Amazon-owned. */
         "#gwm-window [id^=wd-shoppable-] :is(img,video,canvas)"
         ":not([class*=icon]):not([class*=glyph]):not([class*=sprite]):not([class*=pixel]):not([class*=logo]):not([class*=badge])"
         ":not(:where([data-ad-feedback-label-id] *)):not(:where([class*=ad-feedback] *)),"
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
         /* v7.154 Search TWB compositor optimization. Over an OLED-black product plate,
          * opacity=factor is pixel-equivalent to brightness(factor) for raster media but avoids
          * WebKit's expensive CSS filter pipeline on dozens of scrolling result images. */
         "#search img.s-image,#search img.s-product-image,#search [data-component-type=s-product-image] img,"
         "#search img.ufs_tiles_card_widget-sug-image,#search img.nice-cat-card_image,"
         "#search img.haul-puis-portrait-img,#search img._c2Itd_image_pQREQ"
         "{filter:none!important;-webkit-filter:none!important;opacity:%.3f!important;}"
         /* v7.145: Search sponsored-video repair. The probe shows VIDEO.sbv-video-player-ecx
          * is alive/visible with filter:none while a same-size DIV.sbv-video-overlay sits above
          * it at computed opaque black. Keep the accelerated VIDEO surface unfiltered so WebKit
          * can render frames, then use only the overlay's own background as the TWB shade. Child
          * controls remain above that background and retain Amazon's stock artwork. */
         "#search#search video.sbv-video-player-ecx"
         "{filter:none!important;-webkit-filter:none!important;}"
         "#search#search .sbv-video-overlay"
         "{background-color:rgba(0,0,0,%.3f)!important;}"
         /* v7.151: alternate _c2Itd video stays compositor-unfiltered; tame it through
          * its own same-size overlay so playback cannot regress to a black video surface. */
         "#search#search ._c2Itd_videoOverlay_1H_Jm"
         "{background-color:rgba(0,0,0,%.3f)!important;}"
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
         "}catch(e){}})();",factor,factor,shade,shade,factor,factor,shade,shade,shade];
}


static NSString *ADPrivacyModeJS7117(void){
    return
        @"(function(){try{"
        @"if(window.__adPrivacy7117Installed){window.__adPrivacy7117Enabled=true;return;}"
        @"window.__adPrivacy7117Installed=1;window.__adPrivacy7117Enabled=true;var xhrMeta=new WeakMap();"
        @"function parse(u){try{return new URL(String(u&&u.url?u.url:u||''),location.href)}catch(_){return null}}"
        @"function blockedHost(h){h=String(h||'').toLowerCase();return h==='unagi.amazon.com'||h==='unagi-na.amazon.com'||h==='fls-na.amazon.com'||h==='api.mshop.bdtelemetry.amazon'||h==='session.mshopbugsnag.irm.amazon.dev'||h==='trace.mshopbugsnag.irm.amazon.dev'||h==='vfw.amazon-adsystem.com'||h.endsWith('.service.minerva.devices.a2z.com')||/^api\\.stores\\.[^.]+\\.prod\\.paets\\.advertising\\.amazon\\.dev$/.test(h)||/^aes\\..*\\.amazon-adsystem\\.com$/.test(h)}"
        @"function info(u){var x=parse(u),h=x?x.hostname.toLowerCase():'';return{blocked:!!(x&&blockedHost(h)),url:x?(x.protocol+'//'+x.host+(x.pathname||'/')):String(u||'')}}"
        @"function fakeResponse(url){try{return new Response(null,{status:204,statusText:'No Content',headers:{'Cache-Control':'no-store','X-AmazonDark-Privacy':'1'}})}catch(_){return{ok:true,status:204,statusText:'No Content',url:String(url||''),text:function(){return Promise.resolve('')},json:function(){return Promise.resolve({})},arrayBuffer:function(){return Promise.resolve(new ArrayBuffer(0))}}}}"
        @"try{var osb=navigator.sendBeacon;if(typeof osb==='function')navigator.sendBeacon=function(url,data){var i=info(url);if(window.__adPrivacy7117Enabled&&i.blocked)return true;return osb.apply(this,arguments)}}catch(_){}"
        @"try{var of=window.fetch;if(typeof of==='function')window.fetch=function(input,init){var i=info(input);if(window.__adPrivacy7117Enabled&&i.blocked)return Promise.resolve(fakeResponse(i.url));return of.apply(this,arguments)}}catch(_){}"
        @"try{var xo=XMLHttpRequest.prototype.open,xs=XMLHttpRequest.prototype.send;XMLHttpRequest.prototype.open=function(method,url){try{xhrMeta.set(this,info(url))}catch(_){}return xo.apply(this,arguments)};XMLHttpRequest.prototype.send=function(){var m=null;try{m=xhrMeta.get(this)}catch(_){};if(window.__adPrivacy7117Enabled&&m&&m.blocked){var self=this;try{Object.defineProperty(self,'readyState',{configurable:true,get:function(){return 4}})}catch(_){}try{Object.defineProperty(self,'status',{configurable:true,get:function(){return 204}})}catch(_){}try{Object.defineProperty(self,'statusText',{configurable:true,get:function(){return 'No Content'}})}catch(_){}try{Object.defineProperty(self,'responseURL',{configurable:true,get:function(){return m.url}})}catch(_){}try{Object.defineProperty(self,'responseText',{configurable:true,get:function(){return ''}})}catch(_){}try{Object.defineProperty(self,'response',{configurable:true,get:function(){return ''}})}catch(_){}Promise.resolve().then(function(){try{self.dispatchEvent(new Event('readystatechange'));self.dispatchEvent(new Event('load'));self.dispatchEvent(new Event('loadend'))}catch(_){}});return}return xs.apply(this,arguments)}}catch(_){}"
        @"function broadcast(msg){try{var a=document.getElementsByTagName('iframe');for(var i=0;i<a.length&&i<32;i++)try{a[i].contentWindow.postMessage(msg,'*')}catch(_){}}catch(_){}}"
        @"window.__adPrivacy7117Broadcast=broadcast;window.addEventListener('message',function(e){try{var d=e.data;if(d&&d.__adPrivacy7117Toggle===1){window.__adPrivacy7117Enabled=!!d.enabled;broadcast(d)}}catch(_){}},false);"
        @"}catch(e){}})();";
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


// v7.152 production: probe-only all-frame bridge removed; only theme scripts remain.

static NSString *ADHomeAdFrameProbeJS7144(void){
    return @"(function(){try{\nif(window.__ad7144FrameProbeInstalled)return;\nwindow.__ad7144FrameProbeInstalled=1;\nfunction st(e,p){try{var s=getComputedStyle(e,p||null);return {display:s.display,vis:s.visibility,op:s.opacity,bg:s.backgroundColor,bgi:s.backgroundImage,color:s.color,fill:s.fill,stroke:s.stroke,filter:s.webkitFilter||s.filter||'none',border:s.border,radius:s.borderRadius,shadow:s.boxShadow,outline:s.outline,font:s.fontFamily,fontSize:s.fontSize,fontWeight:s.fontWeight,lineHeight:s.lineHeight,textShadow:s.textShadow,webkitTextStroke:s.webkitTextStroke||'',transform:s.transform,overflow:s.overflow,clipPath:s.clipPath||s.webkitClipPath||'',z:s.zIndex,position:s.position,mask:s.webkitMaskImage||s.maskImage||'none',objectFit:s.objectFit||'',mix:s.mixBlendMode||''};}catch(x){return {err:String(x)}}}\nfunction nd(e){if(!e)return null;var r=e.getBoundingClientRect(),o={tag:e.tagName||'',id:e.id||'',cls:String(e.className||'').slice(0,280),r:[+r.x.toFixed(1),+r.y.toFixed(1),+r.width.toFixed(1),+r.height.toFixed(1)],style:st(e),before:st(e,'::before'),after:st(e,'::after'),a:{testid:e.getAttribute&&e.getAttribute('data-testid')||'',acei:e.getAttribute&&e.getAttribute('data-acei-id')||'',htmlDim:e.getAttribute&&e.getAttribute('data-html-dimensions')||'',role:e.getAttribute&&e.getAttribute('role')||'',feedback:e.hasAttribute&&e.hasAttribute('data-ad-feedback-label-id')?1:0,ariaSponsored:/sponsored/i.test(e.getAttribute&&e.getAttribute('aria-label')||'')?1:0}};if(e.tagName==='IMG')o.natural=[e.naturalWidth||0,e.naturalHeight||0];if(e.tagName==='VIDEO'){o.natural=[e.videoWidth||0,e.videoHeight||0];o.media={muted:e.muted?1:0,volume:+(+e.volume||0).toFixed(3),paused:e.paused?1:0,controls:e.controls?1:0,readyState:e.readyState||0,currentTime:+(+e.currentTime||0).toFixed(2)};o.ua={mute:st(e,'::-webkit-media-controls-mute-button'),play:st(e,'::-webkit-media-controls-play-button'),panel:st(e,'::-webkit-media-controls-panel')};}return o;}\nfunction ch(e,n){var a=[];for(var x=e;x&&a.length<(n||8);x=x.parentElement)a.push(nd(x));return a;}\nfunction vis(e,min){try{var r=e.getBoundingClientRect(),s=getComputedStyle(e),a=Math.max(0,Math.min(innerWidth,r.right)-Math.max(0,r.left))*Math.max(0,Math.min(innerHeight,r.bottom)-Math.max(0,r.top));return s.display!=='none'&&s.visibility!=='hidden'&&+s.opacity>0.01&&a>=(min||1);}catch(_){return false}}\nfunction q(sel,lim,min){var out=[];try{var a=document.querySelectorAll(sel);for(var i=0;i<a.length&&out.length<(lim||60);i++)if(vis(a[i],min||1))out.push({self:nd(a[i]),chain:ch(a[i],8)});}catch(e){out.push({err:String(e),sel:sel})}return out;}\nfunction media(){var out=[];try{var a=document.querySelectorAll('img,video,canvas');for(var i=0;i<a.length&&out.length<100;i++){var e=a[i];if(!vis(e,1200))continue;out.push({self:nd(e),chain:ch(e,9)});}}catch(e){out.push({err:String(e)})}return out;}\nfunction bgmedia(){var out=[];try{var a=document.getElementsByTagName('*'),n=Math.min(a.length,2600);for(var i=0;i<n&&out.length<70;i++){var e=a[i];if(!vis(e,6000))continue;var b=getComputedStyle(e).backgroundImage;if(b&&b!=='none')out.push({self:nd(e),chain:ch(e,7)});}}catch(e){out.push({err:String(e)})}return out;}\nfunction hits(){var out=[],xs=[.18,.5,.82],ys=[.18,.38,.58,.76,.9];try{for(var i=0;i<xs.length;i++)for(var j=0;j<ys.length;j++){var x=Math.round(innerWidth*xs[i]),y=Math.round(innerHeight*ys[j]),a=(document.elementsFromPoint?document.elementsFromPoint(x,y):[document.elementFromPoint(x,y)]).filter(Boolean).slice(0,10);out.push({p:[x,y],stack:a.map(nd)});}}catch(e){out.push({err:String(e)})}return out;}\nfunction safeAttr(e,n){try{return String(e.getAttribute&&e.getAttribute(n)||'').slice(0,360)}catch(_){return ''}}\nfunction controlNode(e){var o=nd(e)||{};try{o.ctrl={aria:(/mute|unmute|sound|volume|speaker|audio/i.test(safeAttr(e,'aria-label'))?safeAttr(e,'aria-label'):''),title:(/mute|unmute|sound|volume|speaker|audio/i.test(safeAttr(e,'title'))?safeAttr(e,'title'):''),role:safeAttr(e,'role'),testid:safeAttr(e,'data-testid'),name:safeAttr(e,'name'),type:safeAttr(e,'type'),viewBox:safeAttr(e,'viewBox'),href:(e.tagName==='USE'?safeAttr(e,'href')||safeAttr(e,'xlink:href'):''),d:(e.tagName==='PATH'?safeAttr(e,'d'):'')};var cs=getComputedStyle(e);o.ctrl.font={family:cs.fontFamily,size:cs.fontSize,weight:cs.fontWeight,lineHeight:cs.lineHeight,textShadow:cs.textShadow,webkitTextStroke:cs.webkitTextStroke||'',transform:cs.transform,overflow:cs.overflow,clipPath:cs.clipPath||cs.webkitClipPath||'',outline:cs.outline,z:cs.zIndex,position:cs.position};}catch(_){}return o;}\nfunction subTree(root){var budget=180;function walk(e,d){if(!e||budget--<=0)return null;var o=controlNode(e);if(d<10){var kids=[];for(var c=e.firstElementChild;c&&kids.length<40;c=c.nextElementSibling){var z=walk(c,d+1);if(z)kids.push(z);}if(kids.length)o.children=kids;}return o;}return walk(root,0);}\nfunction videoControlTrees(){var out=[];try{var roots=document.querySelectorAll('#search .sbv-video-overlay,.sbv-video-overlay,#search video.sbv-video-player-ecx,video.sbv-video-player-ecx,#search video._c2Itd_video_17g-f,#search ._c2Itd_videoOverlay_1H_Jm,#search ._c2Itd_playClickRegion_87ZZa,[class*=single-video-card],[class*=singleVideoCard],.video-js');for(var r=0;r<roots.length&&out.length<24;r++){var root=roots[r];if(!vis(root,1))continue;var cand=[];try{cand=[].slice.call(root.querySelectorAll('button,[role=button],[aria-label],[title],svg,use,path,i,span,div')).filter(function(e){var k=(String(e.id||'')+' '+String(e.className&&e.className.baseVal||e.className||'')+' '+safeAttr(e,'aria-label')+' '+safeAttr(e,'title')+' '+safeAttr(e,'data-testid')).toLowerCase();return /mute|unmute|sound|volume|speaker|audio/.test(k);});}catch(_){}var buttons=[];try{buttons=[].slice.call(root.querySelectorAll('button,[role=button]')).filter(function(e){return vis(e,1)});}catch(_){}var uniq=[];cand.concat(buttons).forEach(function(e){if(e&&uniq.indexOf(e)<0&&uniq.length<16)uniq.push(e);});out.push({root:controlNode(root),rootTree:subTree(root),controls:uniq.map(function(e){return {ancestors:ch(e,10),tree:subTree(e)}})});} }catch(e){out.push({err:String(e)})}return out;}\nfunction snap(){var h=document.documentElement||{},state=null;try{state=window.__ad7106StandaloneState?window.__ad7106StandaloneState():null}catch(_){}return {frame:{top:window===top?1:0,host:String(location.hostname||''),path:String(location.pathname||''),viewport:[innerWidth,innerHeight,devicePixelRatio]},markers:{child:h.getAttribute&&h.getAttribute('data-ad7-child-frame')||'',standaloneCandidate:h.getAttribute&&h.getAttribute('data-ad7-standalone-candidate')||'',standaloneSurvivor:h.getAttribute&&h.getAttribute('data-ad7104-standalone')||'',twbChild:h.getAttribute&&h.getAttribute('data-ad7-twb-child')||''},standaloneState:state,heroFeedback:q('#gwm-window [id^=wd-shoppable-] [data-ad-feedback-label-id],#gwm-window [id^=wd-shoppable-] .ape-feedback,#gwm-window [id^=wd-shoppable-] [class*=ad-feedback],#gwm-window [id^=wd-shoppable-] [id^=ad-feedback-],#gwm-window [id^=wd-shoppable-] [aria-label*=\"Sponsored\"],[class*=single-creative-card] [data-ad-feedback-label-id],[class*=single-creative-card] [class*=ad-feedback],[id*=mobile-wd-][class*=ape-feedback]',90,1),shells:q('#gwm-window,[id^=wd-shoppable-],[class*=single-creative-card],[class*=single-video-card],[class*=ape-wrapper],[class*=ape-placement],[class*=ape-feedback],[data-testid=renderer-factory-ad-container],#ad,#dynamic-bb,[data-testid=image],[data-acei-id=lfstyl-img],[data-acei-id=prod-img]',100,1),media:media(),bgMedia:bgmedia(),videoControlTrees:videoControlTrees(),hit:hits()};}\nfunction fan(token){var z=snap();if(window===top){window.__ad7144ProbeToken=token;window.__ad7144ProbeFrames=[z];}else{try{top.postMessage({__ad7144ProbeFrame:1,token:token,snap:z},'*')}catch(_){}}try{var fs=document.getElementsByTagName('iframe');for(var i=0;i<fs.length&&i<24;i++)if(fs[i].contentWindow)fs[i].contentWindow.postMessage({__ad7144ProbeRequest:1,token:token},'*');}catch(_){}}\nwindow.addEventListener('message',function(ev){try{var d=ev.data||{};if(d.__ad7144ProbeRequest&&d.token)fan(String(d.token));if(window===top&&d.__ad7144ProbeFrame&&d.token===window.__ad7144ProbeToken&&d.snap){var a=window.__ad7144ProbeFrames||(window.__ad7144ProbeFrames=[]);if(a.length<48)a.push(d.snap);}}catch(_){}},false);\nif(window===top){window.__ad7144StartProbe=function(t){try{fan(String(t||Date.now()));return 'STARTED';}catch(e){return 'START_ERR '+e}};window.__ad7144DumpProbe=function(t){try{return JSON.stringify({token:String(t||''),frames:window.__ad7144ProbeFrames||[]},null,2);}catch(e){return 'DUMP_ERR '+e}};}\n}catch(e){}})();";
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
        if(!objc_getAssociatedObject(ucc,kADHomeAdProbeUS7144)){
            WKUserScript *us=[[WKUserScript alloc] initWithSource:ADHomeAdFrameProbeJS7144() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
            [ucc addUserScript:us];
            objc_setAssociatedObject(ucc,kADHomeAdProbeUS7144,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
        // v7.129: own the backing before attachment as well as after it. The v7.128
        // probe caught a destination/search WKWebView still stock-white while loading.
        // This is constant-time UIKit/WebKit property ownership only; no JS retry lane.
        UIColor *black=ADOLED();
        wv.opaque=NO;
        wv.backgroundColor=black;
        wv.layer.backgroundColor=black.CGColor;
        wv.scrollView.opaque=NO;
        wv.scrollView.backgroundColor=black;
        wv.scrollView.layer.backgroundColor=black.CGColor;
        if(@available(iOS 15.0,*)) wv.underPageBackgroundColor=black;
    } @catch(...) {}
}


static BOOL ADPrimaryAmazonWindow713(UIWindow *w, UIViewController *candidate);

// -----------------------------------------------------------------------------
static void ADApplyAllFloors(void){
    if(!gP.enabled)return;
    @try {
        // v6.0.160-era lesson: a destination WebView is transition-live as soon as
        // it has a superview, before UIWindow attachment. Prime that state too.
        for(WKWebView *wv in ADTrackedWebViews()) if(wv.window || wv.superview) ADApplyWebFloor(wv);
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
- (void)didMoveToSuperview {
    %orig;
    if(gP.enabled && self.superview){ ADAttachWebScripts(self); ADApplyWebFloor(self); }
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled && self.window){ ADAttachWebScripts(self); ADApplyWebFloor(self); ADConsiderLaunchReady706(); }
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        return;
    }
    %orig(color);
}
- (void)setOpaque:(BOOL)opaque {
    if(gP.enabled){
        %orig(NO);
        return;
    }
    %orig(opaque);
}
- (void)setUnderPageBackgroundColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    %orig(color);
}
%end

%hook WKScrollView
- (void)didMoveToSuperview {
    %orig;
    if(gP.enabled && strcmp(object_getClassName(self), "WKScrollView")==0){
        UIColor *black=ADOLED();
        self.opaque=NO;
        self.backgroundColor=black;
        self.layer.backgroundColor=black.CGColor;
    }
}
- (void)didMoveToWindow {
    %orig;
    /* Keep the proven white native scrollbar while refusing to style
     * WKChildScrollView carousel descendants. */
    if(gP.enabled && self.window && strcmp(object_getClassName(self), "WKScrollView")==0){
        UIColor *black=ADOLED();
        self.opaque=NO;
        self.backgroundColor=black;
        self.layer.backgroundColor=black.CGColor;
        self.indicatorStyle=UIScrollViewIndicatorStyleWhite;
    }
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled && strcmp(object_getClassName(self), "WKScrollView")==0){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        return;
    }
    %orig(color);
}
- (void)setOpaque:(BOOL)opaque {
    if(gP.enabled && strcmp(object_getClassName(self), "WKScrollView")==0){
        %orig(NO);
        return;
    }
    %orig(opaque);
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
    if(!gP.enabled||!iv||!iv.window)return;
    CGFloat iw=iv.bounds.size.width, ih=iv.bounds.size.height;
    if(iw<2.0||ih<2.0||iw>100.0||ih>100.0)return;
    if(!ADANXTabRoot724(iv))return;
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

// v7.130: the v7.129 platter fix missed because UIKit's selection platter is
// portal-mounted alongside WebKit compositing views rather than necessarily being
// a descendant of WKContentView/WKWebView.  Gate the actual bright child by exact
// platter ancestry + AppCXWindow + row-sized geometry instead.
static BOOL ADBrightNeutral7130(UIColor *c){
    if(!c)return NO;
    @try {
        CGFloat r=0,g=0,b=0,a=0,w=0;
        if([c getRed:&r green:&g blue:&b alpha:&a]){
            CGFloat hi=MAX(r,MAX(g,b)),lo=MIN(r,MIN(g,b));
            return a>0.20 && ((r+g+b)/3.0)>0.72 && (hi-lo)<0.12;
        }
        if([c getWhite:&w alpha:&a])return a>0.20 && w>0.72;
    } @catch(...) {}
    return NO;
}
// v7.133: The Search/autocomplete probe shows one exact full-screen plain UIView
// under the already-owned transition wrapper remains stock white after steady state.
// The existing v7.129 shallow transition pass can identify this plane correctly,
// but Amazon later assigns white again. Mark only plain UIViews that have already
// passed that exact bounded transition-candidate gate, then preserve their OLED
// floor through the existing UIView lifecycle/setBackgroundColor hook.
static const void *kADTransitionBacking7133=&kADTransitionBacking7133;
static const void *kADPrimaryWindow713=&kADPrimaryWindow713;
static BOOL ADMarkedTransitionBacking7133(UIView *v){
    return v && objc_getAssociatedObject(v,kADTransitionBacking7133)!=nil;
}

// v7.138: Search results sometimes mount the delivery/location strip as native
// UIKit chrome rather than DOM. Own only a full-width warm Amazon delivery band
// in the upper content region; ordinary buttons/cards cannot pass this geometry.
static const void *kADSearchDeliveryBand7139=&kADSearchDeliveryBand7139;
static const void *kADSearchDeliveryDescendant7139=&kADSearchDeliveryDescendant7139;
static BOOL ADWarmDeliveryColor7139(UIColor *c){
    if(!c)return NO;
    @try {
        CGFloat r=0,g=0,b=0,a=0;
        if(![c getRed:&r green:&g blue:&b alpha:&a]||a<0.20)return NO;
        return r>0.72 && g>0.58 && b>0.30 && (r-b)>0.14 && (g-b)>0.07;
    } @catch(...) {}
    return NO;
}
static BOOL ADInMarkedSearchDeliveryBand7139(UIView *v){
    if(!v)return NO;
    @try {
        return objc_getAssociatedObject(v,kADSearchDeliveryBand7139)!=nil ||
               objc_getAssociatedObject(v,kADSearchDeliveryDescendant7139)!=nil;
    } @catch(...) {}
    return NO;
}
static inline void ADMarkSearchDeliveryDescendant7139(UIView *v){
    if(!v)return;
    @try { objc_setAssociatedObject(v,kADSearchDeliveryDescendant7139,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC); } @catch(...) {}
}

// v7.140: the screenshot-triggered v7.139 native probe names the visible 430x44
// Search delivery painter directly: GlowIngressView at y=119. Its computed paint
// is translucent white rather than the warm color used by the old heuristic, so
// the old detector can never claim it. Own only this exact private class in the
// compact top-nav geometry and mark it for the existing light glyph path.
static BOOL ADExactGlowIngress7140(UIView *v){
    if(!gP.enabled||!v||!v.window||!ADPrimaryAmazonWindow713(v.window,nil))return NO;
    @try {
        if(![NSStringFromClass(v.class) isEqualToString:@"GlowIngressView"])return NO;
        CGRect r=[v convertRect:v.bounds toView:v.window], wb=v.window.bounds;
        if(wb.size.width<1.0)return NO;
        return r.size.width>=wb.size.width*0.88 && r.size.height>=28.0 && r.size.height<=72.0 &&
               CGRectGetMinY(r)>=90.0 && CGRectGetMinY(r)<=220.0;
    } @catch(...) {}
    return NO;
}

// v7.139: v7.138's Web probe proves the yellow strip is outside the /s DOM (the
// WebView starts directly on the sf-rib30 filter ribbon). Historical Search captures
// consistently expose the 47pt native ANX sub-navigation controllers. Own only the
// compact, primary-window instance so full-screen/hidden subnav controller variants
// cannot be swept into this lane.
static void ADTintSearchDeliveryGlyph7139(UIImageView *iv);

// v7.141: v7.140 proves GlowIngressView.backgroundColor and layer.backgroundColor are
// already OLED while the 430x44 strip is still visibly yellow. Therefore the warm floor
// is being painted by layer contents / an internal decoration layer, not UIView background
// color. Place one OLED CALayer above each exact-band decoration stack but below that
// view's subview layers, so the white pin/text children remain intact.
static const void *kADGlowFloorLayer7141=&kADGlowFloorLayer7141;
static BOOL ADGlowFloorHost7141(UIView *v,UIView *root){
    if(!v||!root)return NO;
    if(v==root)return YES;
    if([v isKindOfClass:[UILabel class]]||[v isKindOfClass:[UIImageView class]]||[v isKindOfClass:[UIControl class]])return NO;
    @try {
        CGRect r=[v convertRect:v.bounds toView:root], rb=root.bounds;
        if(rb.size.width<1.0||rb.size.height<1.0)return NO;
        return r.size.width>=rb.size.width*0.90 && r.size.height>=rb.size.height*0.72 &&
               CGRectGetMinY(r)<=rb.size.height*0.20 && CGRectGetMaxY(r)>=rb.size.height*0.80;
    } @catch(...) {}
    return NO;
}
static void ADInstallGlowFloorLayer7141(UIView *v){
    if(!v)return;
    @try {
        CALayer *floor=(CALayer *)objc_getAssociatedObject(v,kADGlowFloorLayer7141);
        if(!floor){
            floor=[CALayer layer]; floor.name=@"AmazonDarkGlowFloor7141";
            floor.actions=@{ @"bounds":[NSNull null], @"position":[NSNull null], @"backgroundColor":[NSNull null], @"opacity":[NSNull null] };
            objc_setAssociatedObject(v,kADGlowFloorLayer7141,floor,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        floor.frame=v.bounds; floor.backgroundColor=ADOLED().CGColor; floor.opacity=1.0; floor.hidden=NO;
        [floor removeFromSuperlayer];
        NSArray<CALayer *> *layers=v.layer.sublayers?:@[]; NSUInteger idx=layers.count;
        for(UIView *sv in v.subviews?:@[]){
            NSUInteger n=[layers indexOfObjectIdenticalTo:sv.layer];
            if(n!=NSNotFound&&n<idx)idx=n;
        }
        if(idx<=(v.layer.sublayers?:@[]).count)[v.layer insertSublayer:floor atIndex:(unsigned)idx];
        else [v.layer addSublayer:floor];
    } @catch(...) {}
}
static void ADInstallGlowFloorTree7141(UIView *root){
    if(!ADExactGlowIngress7140(root))return;
    @try {
        NSMutableArray *q=[NSMutableArray arrayWithObject:root]; NSUInteger seen=0;
        while(q.count&&seen++<96){
            UIView *x=q.firstObject; [q removeObjectAtIndex:0]; if(!x)continue;
            if(ADGlowFloorHost7141(x,root))ADInstallGlowFloorLayer7141(x);
            if(q.count<96&&x.subviews.count)[q addObjectsFromArray:x.subviews];
        }
    } @catch(...) {}
}

static void ADOwnGlowIngress7140(UIView *root){
    if(!ADExactGlowIngress7140(root))return;
    @try {
        UIColor *black=ADOLED(), *light=ADLightText706();
        objc_setAssociatedObject(root,kADSearchDeliveryBand7139,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        root.backgroundColor=black;
        root.layer.backgroundColor=black.CGColor;
        root.tintColor=light;
        // One bounded event-driven pass catches descendants that were mounted before
        // the exact root was marked. Later image/background writes are handled by hooks.
        NSMutableArray *q=[NSMutableArray arrayWithArray:root.subviews?:@[]]; NSUInteger seen=0;
        while(q.count && seen++<96){
            UIView *x=q.firstObject; [q removeObjectAtIndex:0]; if(!x)continue;
            ADMarkSearchDeliveryDescendant7139(x);
            if([x isKindOfClass:[UIImageView class]]) ADTintSearchDeliveryGlyph7139((UIImageView *)x);
            else if([x isKindOfClass:[UILabel class]]) ((UILabel *)x).textColor=light;
            else if(ADWarmDeliveryColor7139(x.backgroundColor)||ADBrightNeutral7130(x.backgroundColor)){
                x.backgroundColor=black; x.layer.backgroundColor=black.CGColor;
            }
            x.tintColor=light;
            if(q.count<96 && x.subviews.count)[q addObjectsFromArray:x.subviews];
        }
        ADInstallGlowFloorTree7141(root);
    } @catch(...) {}
}
static BOOL ADSearchSubNavControllerClass7139(UIViewController *vc){
    if(!vc)return NO;
    NSString *cn=NSStringFromClass(vc.class);
    return [cn isEqualToString:@"ANXVisualSubNavViewController"] || [cn isEqualToString:@"ANXSubNavContainer"];
}
static BOOL ADCompactSearchSubNavView7139(UIView *v){
    if(!v||!v.window||!ADPrimaryAmazonWindow713(v.window,nil))return NO;
    @try {
        CGRect r=[v convertRect:v.bounds toView:v.window], wb=v.window.bounds;
        if(wb.size.width<1.0)return NO;
        return r.size.width>=wb.size.width*0.88 && r.size.height>=24.0 && r.size.height<=96.0 &&
               CGRectGetMinY(r)>=80.0 && CGRectGetMinY(r)<=260.0;
    } @catch(...) {}
    return NO;
}
static void ADOwnCompactSearchSubNav7139(UIViewController *vc){
    if(!gP.enabled||!ADSearchSubNavControllerClass7139(vc)||!vc.isViewLoaded)return;
    @try {
        UIView *root=vc.view; if(!ADCompactSearchSubNavView7139(root))return;
        UIColor *black=ADOLED();
        if(objc_getAssociatedObject(root,kADSearchDeliveryBand7139)){
            root.backgroundColor=black; root.layer.backgroundColor=black.CGColor; root.tintColor=ADLightText706();
            return;
        }
        objc_setAssociatedObject(root,kADSearchDeliveryBand7139,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        root.backgroundColor=black; root.layer.backgroundColor=black.CGColor; root.tintColor=ADLightText706();
        // One bounded event-driven pass handles descendants that were already mounted before
        // the controller was marked. Later background/image writes are owned by existing hooks.
        NSMutableArray *q=[NSMutableArray arrayWithArray:root.subviews?:@[]]; NSUInteger seen=0;
        while(q.count && seen++<96){
            UIView *x=q.firstObject; [q removeObjectAtIndex:0]; if(!x)continue;
            ADMarkSearchDeliveryDescendant7139(x);
            if([x isKindOfClass:[UIImageView class]]) ADTintSearchDeliveryGlyph7139((UIImageView *)x);
            else if([x isKindOfClass:[UILabel class]]) ((UILabel *)x).textColor=ADLightText706();
            else if(ADWarmDeliveryColor7139(x.backgroundColor)){ x.backgroundColor=black; x.layer.backgroundColor=black.CGColor; }
            if(q.count<96 && x.subviews.count)[q addObjectsFromArray:x.subviews];
        }
    } @catch(...) {}
}

static BOOL ADSelectionPlatterChild7130(UIView *v, UIColor *candidate){
    if(!gP.enabled||!v||!v.window||!candidate)return NO;
    @try {
        if(strcmp(object_getClassName(v),"UIView")!=0)return NO;
        if(![NSStringFromClass(v.window.class) isEqualToString:@"AppCXWindow"])return NO;
        CGRect r=[v convertRect:v.bounds toView:v.window];
        CGFloat sw=v.window.bounds.size.width;
        if(sw<1.0||r.size.width<sw*0.60||r.size.height<18.0||r.size.height>130.0)return NO;
        if(!ADBrightNeutral7130(candidate))return NO;
        UIView *n=v.superview;
        for(int d=0;n&&d<8;d++,n=n.superview){
            NSString *cn=NSStringFromClass(n.class);
            if([cn hasPrefix:@"_UIPlatter"])return YES;
            if([n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return NO;
}

static inline BOOL ADWebKitInternalView7154(UIView *v){
    if(!v)return NO;
    const char *cn=object_getClassName(v);
    return cn && ((cn[0]=='W'&&cn[1]=='K')||(cn[0]=='_'&&cn[1]=='W'&&cn[2]=='K'));
}

%hook UIView
- (void)didMoveToWindow {
    %orig;
    // v7.154: WKWebView/WKScrollView/WKContentView have exact owners above. Do not
    // run generic UIKit floor heuristics on WebKit's large compositing-view tree.
    if(ADWebKitInternalView7154(self))return;
    if(gP.enabled && self.window && ADInMarkedSearchDeliveryBand7139(self) && ![self isKindOfClass:[UIImageView class]]){
        UIColor *black=ADOLED(); self.backgroundColor=black; self.layer.backgroundColor=black.CGColor;
        return;
    }
    if(gP.enabled && self.window && ADMarkedTransitionBacking7133(self) && ADPrimaryAmazonWindow713(self.window,nil)){
        UIColor *black=ADOLED();
        self.backgroundColor=black;
        self.layer.backgroundColor=black.CGColor;
        return;
    }
    if(gP.enabled && self.window && ADSelectionPlatterChild7130(self,self.backgroundColor)){
        UIColor *black=ADOLED();
        self.backgroundColor=black;
        self.layer.backgroundColor=black.CGColor;
        return;
    }
    if(gP.enabled && self.window && ADNativeFloorCandidate(self)) ADOwnNativeFloor(self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADWebKitInternalView7154(self)){
        %orig(color);
        return;
    }
    if(gP.enabled && self.window && ADInMarkedSearchDeliveryBand7139(self) && ![self isKindOfClass:[UIImageView class]]){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        return;
    }
    if(gP.enabled && ADMarkedTransitionBacking7133(self) && (!self.window || ADPrimaryAmazonWindow713(self.window,nil))){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        return;
    }
    if(gP.enabled && self.window && ADSelectionPlatterChild7130(self,color)){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        return;
    }
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
        if(objc_getAssociatedObject(w,kADPrimaryWindow713))return YES;
        if(fabs(w.windowLevel-UIWindowLevelNormal)>0.1)return NO;
        UIViewController *vc=candidate?:w.rootViewController;
        BOOL primary=ADPrimaryAmazonController713(vc);
        if(!primary){
            NSString *n=NSStringFromClass(vc.class).lowercaseString?:@"";
            primary=[n containsString:@"splash"]||[n containsString:@"launchscreen"];
        }
        if(primary)objc_setAssociatedObject(w,kADPrimaryWindow713,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return primary;
    } @catch(...) {}
    return NO;
}

static BOOL ADPrimaryLargeFloor7129(UIView *v){
    if(!gP.enabled||!v||!v.window||!ADPrimaryAmazonWindow713(v.window,nil))return NO;
    @try {
        CGRect wb=v.window.bounds;
        CGRect r=[v convertRect:v.bounds toView:v.window];
        if(wb.size.width<1.0||wb.size.height<1.0)return NO;
        return r.size.width>=wb.size.width*0.80 && r.size.height>=wb.size.height*0.30;
    } @catch(...) {}
    return NO;
}
static void ADPaintPrimaryLargeFloor7129(UIView *v){
    if(!ADPrimaryLargeFloor7129(v))return;
    @try {
        UIColor *black=ADOLED();
        v.backgroundColor=black;
        v.layer.backgroundColor=black.CGColor;
    } @catch(...) {}
}
static BOOL ADTransitionShell7129(UIView *v){
    if(!v)return NO;
    const char *cn=object_getClassName(v);
    return (cn&&strcmp(cn,"UIView")==0)||
           [v isKindOfClass:%c(UILayoutContainerView)]||
           [v isKindOfClass:%c(UITransitionView)]||
           [v isKindOfClass:%c(UINavigationTransitionView)]||
           [v isKindOfClass:%c(UIViewControllerWrapperView)];
}
static void ADPaintTransitionCandidate7129(UIView *v, UIColor *black){
    if(!ADTransitionShell7129(v)||!ADPrimaryLargeFloor7129(v))return;
    const char *cn=object_getClassName(v);
    if(cn&&strcmp(cn,"UIView")==0){
        objc_setAssociatedObject(v,kADTransitionBacking7133,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    v.backgroundColor=black;
    v.layer.backgroundColor=black.CGColor;
}
static void ADPaintWrapperChildren7129(UIView *root){
    if(!ADPrimaryLargeFloor7129(root))return;
    @try {
        UIColor *black=ADOLED();
        // Probe V#30/V#73 are plain-UIView backing planes below the wrapper.
        // Walk only two shallow levels and only large transition-shell classes.
        for(UIView *a in (root.subviews.copy?:@[])){
            ADPaintTransitionCandidate7129(a,black);
            for(UIView *b in (a.subviews.copy?:@[])) ADPaintTransitionCandidate7129(b,black);
        }
    } @catch(...) {}
}
static BOOL ADBrightNeutral7129(UIColor *c){
    if(!c)return NO;
    @try {
        CGFloat r=0,g=0,b=0,a=0,w=0;
        if([c getRed:&r green:&g blue:&b alpha:&a]){
            CGFloat hi=MAX(r,MAX(g,b)), lo=MIN(r,MIN(g,b));
            return a>0.20 && ((r+g+b)/3.0)>0.72 && (hi-lo)<0.12;
        }
        if([c getWhite:&w alpha:&a]) return a>0.20 && w>0.72;
    } @catch(...) {}
    return NO;
}
static BOOL ADWebPlatter7129(UIView *v){
    if(!v||!v.window||!gP.enabled)return NO;
    @try {
        // Text-selection platters are portal-mounted siblings of WebKit content on
        // this iOS build, so WK ancestor testing is wrong.  The exact private
        // platter class + primary AppCXWindow + row-sized geometry is sufficient.
        NSString *cn=NSStringFromClass(v.class);
        if(![cn hasPrefix:@"_UIPlatter"])return NO;
        if(![NSStringFromClass(v.window.class) isEqualToString:@"AppCXWindow"])return NO;
        CGRect r=[v convertRect:v.bounds toView:v.window];
        CGFloat sw=v.window.bounds.size.width;
        return sw>0.0 && r.size.width>=sw*0.55 && r.size.height>=18.0 && r.size.height<=140.0;
    } @catch(...) {}
    return NO;
}
static void ADPaintWebPlatter7129(UIView *root){
    if(!gP.enabled||!root||!ADWebPlatter7129(root))return;
    @try {
        UIColor *black=ADOLED();
        root.backgroundColor=black;
        root.layer.backgroundColor=black.CGColor;
        root.layer.shadowOpacity=0.0f;
        root.layer.shadowColor=black.CGColor;

        // The current platter subtree is tiny. Walk at most five levels so the
        // exact V#210/V#213 plain-UIView plates are caught regardless of which
        // _UIPlatter* node Amazon lays out first. Portal/raster content is not
        // recolored; only bright-neutral plain UIView backplates are changed.
        NSMutableArray *stack=[NSMutableArray array];
        for(UIView *c in (root.subviews.copy?:@[])) [stack addObject:@{ @"v":c, @"d":@1 }];
        while(stack.count){
            NSDictionary *it=stack.lastObject; [stack removeLastObject];
            UIView *v=it[@"v"]; int d=[it[@"d"] intValue];
            if(!v||d>5)continue;
            v.layer.shadowOpacity=0.0f;
            v.layer.shadowColor=black.CGColor;
            const char *vc=object_getClassName(v);
            if(vc&&strcmp(vc,"UIView")==0&&v.layer.contents==nil&&ADBrightNeutral7129(v.backgroundColor)){
                v.backgroundColor=black;
                v.layer.backgroundColor=black.CGColor;
            }
            for(UIView *c in (v.subviews.copy?:@[])) [stack addObject:@{ @"v":c, @"d":@(d+1) }];
        }
    } @catch(...) {}
}

%hook UILayoutContainerView
- (void)didMoveToWindow {
    %orig;
    ADPaintPrimaryLargeFloor7129((UIView *)self);
    ADPaintWrapperChildren7129((UIView *)self);
}
- (void)didAddSubview:(UIView *)subview {
    %orig;
    if(gP.enabled&&self.window){
        ADPaintPrimaryLargeFloor7129((UIView *)self);
        ADPaintTransitionCandidate7129(subview,ADOLED());
        ADPaintWrapperChildren7129((UIView *)self);
    }
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADPrimaryLargeFloor7129((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        return;
    }
    %orig(color);
}
%end

%hook UITransitionView
- (void)didMoveToWindow {
    %orig;
    ADPaintPrimaryLargeFloor7129((UIView *)self);
    ADPaintWrapperChildren7129((UIView *)self);
}
- (void)didAddSubview:(UIView *)subview {
    %orig;
    if(gP.enabled&&self.window){
        ADPaintPrimaryLargeFloor7129((UIView *)self);
        ADPaintTransitionCandidate7129(subview,ADOLED());
        ADPaintWrapperChildren7129((UIView *)self);
    }
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADPrimaryLargeFloor7129((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        return;
    }
    %orig(color);
}
%end

%hook UINavigationTransitionView
- (void)didMoveToWindow {
    %orig;
    ADPaintPrimaryLargeFloor7129((UIView *)self);
    ADPaintWrapperChildren7129((UIView *)self);
}
- (void)didAddSubview:(UIView *)subview {
    %orig;
    if(gP.enabled&&self.window){
        ADPaintPrimaryLargeFloor7129((UIView *)self);
        ADPaintTransitionCandidate7129(subview,ADOLED());
        ADPaintWrapperChildren7129((UIView *)self);
    }
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADPrimaryLargeFloor7129((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        return;
    }
    %orig(color);
}
%end

%hook UIViewControllerWrapperView
- (void)didMoveToWindow {
    %orig;
    ADPaintPrimaryLargeFloor7129((UIView *)self);
    ADPaintWrapperChildren7129((UIView *)self);
}
- (void)didAddSubview:(UIView *)subview {
    %orig;
    if(gP.enabled&&self.window){
        ADPaintPrimaryLargeFloor7129((UIView *)self);
        ADPaintTransitionCandidate7129(subview,ADOLED());
        ADPaintWrapperChildren7129((UIView *)self);
    }
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADPrimaryLargeFloor7129((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        return;
    }
    %orig(color);
}
%end

%hook _UIPlatterContainerView
- (void)didMoveToWindow {
    %orig;
    ADPaintWebPlatter7129((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADPaintWebPlatter7129((UIView *)self);
}
%end

%hook _UIPlatterView
- (void)didMoveToWindow {
    %orig;
    ADPaintWebPlatter7129((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADPaintWebPlatter7129((UIView *)self);
}
%end

%hook _UIPlatterSoftShadowView
- (void)didMoveToWindow {
    %orig;
    ADPaintWebPlatter7129((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADPaintWebPlatter7129((UIView *)self);
}
%end

%hook _UIPlatterShadowView
- (void)didMoveToWindow {
    %orig;
    ADPaintWebPlatter7129((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADPaintWebPlatter7129((UIView *)self);
}
%end

// v7.130 — probe-proven cart/Home transition owner.  Every generic transition
// shell and the destination WKWebView is already OLED black in v7.129.  The
// visible white frame is Amazon's own full-screen loading overlay:
// AWLoadingIndicatorFullScreenModalBar -> AWLoadingIndicatorWidgets_BkgView.
// A dedicated black backing sublayer also covers any class-owned drawRect/layer
// contents while keeping Amazon's yellow progress bar and child labels above it.
static const void *kADLoadingBacking7130=&kADLoadingBacking7130;
static const void *kADKeyboardBacking7130=&kADKeyboardBacking7130;
static CALayer *ADBlackBackingLayer7130(UIView *v,const void *key){
    if(!v)return nil;
    CALayer *back=objc_getAssociatedObject(v,key);
    if(!back){
        back=[CALayer layer];
        back.name=@"AmazonDarkOLEDBacking7130";
        back.zPosition=-1000.0;
        [v.layer insertSublayer:back atIndex:0];
        objc_setAssociatedObject(v,key,back,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    back.frame=v.bounds;
    back.backgroundColor=ADOLED().CGColor;
    back.hidden=NO;
    return back;
}
static BOOL ADAppLoadingSurface7130(UIView *v){
    if(!gP.enabled||!v||!v.window)return NO;
    @try {
        if(![NSStringFromClass(v.window.class) isEqualToString:@"AppCXWindow"])return NO;
        CGRect r=[v convertRect:v.bounds toView:v.window];
        CGFloat sw=v.window.bounds.size.width;
        return sw>0.0 && r.size.width>=sw*0.85 && r.size.height>=120.0;
    } @catch(...) {}
    return NO;
}
static void ADOwnAppLoadingSurface7130(UIView *v){
    if(!ADAppLoadingSurface7130(v))return;
    @try {
        UIColor *black=ADOLED();
        v.opaque=YES;
        v.backgroundColor=black;
        v.layer.backgroundColor=black.CGColor;
        ADBlackBackingLayer7130(v,kADLoadingBacking7130);
    } @catch(...) {}
}

%hook AWLoadingIndicatorFullScreenModalBar
- (void)didMoveToWindow {
    %orig;
    ADOwnAppLoadingSurface7130((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADOwnAppLoadingSurface7130((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADAppLoadingSurface7130((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        ADBlackBackingLayer7130((UIView *)self,kADLoadingBacking7130);
        return;
    }
    %orig(color);
}
%end

%hook AWLoadingIndicatorWidgets_BkgView
- (void)didMoveToWindow {
    %orig;
    ADOwnAppLoadingSurface7130((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADOwnAppLoadingSurface7130((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADAppLoadingSurface7130((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        ADBlackBackingLayer7130((UIView *)self,kADLoadingBacking7130);
        return;
    }
    %orig(color);
}
%end

%hook AWLoadingIndicatorWidgets_LoadingText
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window) self.textColor=ADLightText706();
}
- (void)layoutSubviews {
    %orig;
    if(gP.enabled&&self.window) self.textColor=ADLightText706();
}
- (void)setTextColor:(UIColor *)color {
    if(gP.enabled&&self.window){
        UIColor *light=ADLightText706();
        %orig(light);
        return;
    }
    %orig(color);
}
%end

// v7.130 — fill only the lower remote-keyboard host/placeholder exposed while
// the real OLED UIKeyboardDockView is hidden during WebKit selection.  Unlike
// v7.121/v7.122 this does NOT touch UIInputSetContainerView and applies NO
// Core Animation color-matrix/compositor filter.  A black backing sublayer sits
// behind the remote placeholder only while the real UIKeyboardDockView is hidden.
// Normal keyboard presentation therefore remains on the v7.126 OledKeyboard path.
static BOOL ADHiddenKeyboardDock7130(UIView *v){
    if(!v)return NO;
    @try {
        UIView *host=v;
        if(![host isKindOfClass:%c(UIInputSetHostView)]) host=v.superview;
        if(!host||![host isKindOfClass:%c(UIInputSetHostView)])return NO;
        for(UIView *child in (host.subviews.copy?:@[])){
            if([NSStringFromClass(child.class) isEqualToString:@"UIKeyboardDockView"])
                return child.hidden||child.alpha<=0.01;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADLowerKeyboardSurface7130(UIView *v){
    if(!gP.enabled||!v||!v.window||!ADHiddenKeyboardDock7130(v))return NO;
    @try {
        if(![NSStringFromClass(v.window.class) isEqualToString:@"UITextEffectsWindow"])return NO;
        CGRect r=[v convertRect:v.bounds toView:v.window];
        CGRect wb=v.window.bounds;
        return wb.size.width>0.0 && r.size.width>=wb.size.width*0.85 &&
               r.size.height>=120.0 && r.size.height<=460.0 && CGRectGetMinY(r)>=wb.size.height*0.35;
    } @catch(...) {}
    return NO;
}
static void ADOwnLowerKeyboardSurface7130(UIView *v){
    if(!ADLowerKeyboardSurface7130(v))return;
    @try {
        UIColor *black=ADOLED();
        v.opaque=YES;
        v.backgroundColor=black;
        v.layer.backgroundColor=black.CGColor;
        ADBlackBackingLayer7130(v,kADKeyboardBacking7130);
    } @catch(...) {}
}

%hook UIInputSetHostView
- (void)didMoveToWindow {
    %orig;
    ADOwnLowerKeyboardSurface7130((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADOwnLowerKeyboardSurface7130((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADLowerKeyboardSurface7130((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        ADBlackBackingLayer7130((UIView *)self,kADKeyboardBacking7130);
        return;
    }
    %orig(color);
}
%end

%hook _UIRemoteKeyboardPlaceholderView
- (void)didMoveToWindow {
    %orig;
    ADOwnLowerKeyboardSurface7130((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADOwnLowerKeyboardSurface7130((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADLowerKeyboardSurface7130((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        ADBlackBackingLayer7130((UIView *)self,kADKeyboardBacking7130);
        return;
    }
    %orig(color);
}
%end

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

static UIColor *ADLightText706(void){
    static UIColor *c=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ c=[UIColor colorWithRed:232.0/255.0 green:230.0/255.0 blue:227.0/255.0 alpha:1.0]; });
    return c;
}
static UIColor *ADBorderGray706(void){
    static UIColor *c=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ c=[UIColor colorWithRed:73.0/255.0 green:77.0/255.0 blue:77.0/255.0 alpha:1.0]; });
    return c;
}
static BOOL ADNeutralCGColor706(CGColorRef c){
    if(!c)return NO;
    @try {
        CGFloat a=CGColorGetAlpha(c); if(a<=0.05)return NO;
        CGColorSpaceRef cs=CGColorGetColorSpace(c);
        CGColorSpaceModel model=cs?CGColorSpaceGetModel(cs):kCGColorSpaceModelUnknown;
        const CGFloat *v=CGColorGetComponents(c); size_t n=CGColorGetNumberOfComponents(c);
        if(model==kCGColorSpaceModelMonochrome && n>=1)return YES;
        if(model==kCGColorSpaceModelRGB && n>=3){
            CGFloat r=v[0],g=v[1],b=v[2];
            return (MAX(r,MAX(g,b))-MIN(r,MIN(g,b)))<0.16;
        }
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
    static UIColor *c=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ c=[UIColor colorWithRed:48.0/255.0 green:51.0/255.0 blue:53.0/255.0 alpha:1.0]; });
    return c;
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
    CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
    if(w<3||h<3||w>64||h>64)return;
    BOOL search=ADInSearchChrome706(iv), location=ADIsLocationGlyph709(iv), back=ADIsSearchBackGlyph7120(iv);
    if(!search&&!location&&!back)return;
    @try {
        UIImage *im=iv.image;
        if(im.renderingMode!=UIImageRenderingModeAlwaysTemplate && !gADSearchImageWrite706){
            UIImage *tpl=[im imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            if(tpl){ gADSearchImageWrite706=YES; iv.image=tpl; gADSearchImageWrite706=NO; }
        }
        iv.tintColor=ADLightText706();
    } @catch(...) { gADSearchImageWrite706=NO; }
}

static void ADTintSearchDeliveryGlyph7139(UIImageView *iv){
    if(!gP.enabled||!iv||!iv.image||!ADInMarkedSearchDeliveryBand7139(iv))return;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height; if(w<3||h<3||w>70||h>70)return;
        UIImage *im=iv.image;
        if(im.renderingMode!=UIImageRenderingModeAlwaysTemplate && !gADSearchImageWrite706){
            UIImage *tpl=[im imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            if(tpl){ gADSearchImageWrite706=YES; iv.image=tpl; gADSearchImageWrite706=NO; }
        }
        iv.tintColor=ADLightText706();
    } @catch(...) { gADSearchImageWrite706=NO; }
}

static void ADPrepareSearchKeyboard7120(UIView *v){
    if(!gP.enabled||!v||!ADInSearchChrome706(v))return;
    @try {
        SEL sel=NSSelectorFromString(@"setKeyboardAppearance:");
        if([v respondsToSelector:sel]) ((void(*)(id,SEL,NSInteger))objc_msgSend)(v,sel,(NSInteger)UIKeyboardAppearanceDark);
    } @catch(...) {}
}

// v7.126 — port the stable OledKeyboard ownership model instead of tinting the
// full UITextEffectsWindow/UIInputSet compositor.  The donor tweak has been
// tested by its author through iOS 17.4.1.  We independently mirror the small
// set of UIKit owners it uses: the keyboard floor, prediction panel, notched
// dock, emoji/autofill input surfaces, and keyboard visual-effect backing.
// AmazonDark's bundle filter already confines these hooks to com.amazon.Amazon.
static BOOL ADKeyboardDark7126(UIView *view){
    if(!gP.enabled || !view) return NO;
    @try {
        SEL darkSel=NSSelectorFromString(@"_mapkit_isDarkModeEnabled");
        if([view respondsToSelector:darkSel]){
            return ((BOOL(*)(id,SEL))objc_msgSend)(view,darkSel);
        }
        UIViewController *vc=nil;
        SEL vcSel=NSSelectorFromString(@"_viewControllerForAncestor");
        if([view respondsToSelector:vcSel]) vc=((id(*)(id,SEL))objc_msgSend)(view,vcSel);
        UITraitCollection *traits=vc.traitCollection ?: view.traitCollection;
        if(@available(iOS 12.0,*)) return traits.userInterfaceStyle==UIUserInterfaceStyleDark;
    } @catch(...) {}
    return NO;
}

static void ADSetKeyboardFloor7126(UIView *view){
    if(!view) return;
    @try {
        if(!gP.enabled) return;
        view.backgroundColor=ADKeyboardDark7126(view) ? ADOLED() : [UIColor clearColor];
    } @catch(...) {}
}

%hook UIKeyboard
- (void)displayLayer:(id)layer {
    %orig;
    ADSetKeyboardFloor7126((UIView *)self);
}
%end

%hook UIPredictionViewController
- (id)_currentTextSuggestions {
    if(gP.enabled){
        @try {
            UIKeyboard *keyboard=[%c(UIKeyboard) activeKeyboard];
            BOOL dark=keyboard ? ADKeyboardDark7126(keyboard) : ADKeyboardDark7126(self.view);
            if(dark){
                self.view.backgroundColor=ADOLED();
                keyboard.backgroundColor=ADOLED();
            } else {
                self.view.backgroundColor=[UIColor clearColor];
                keyboard.backgroundColor=[UIColor clearColor];
            }
        } @catch(...) {}
    }
    return %orig;
}
%end

%hook UIKeyboardDockView
- (void)layoutSubviews {
    %orig;
    ADSetKeyboardFloor7126((UIView *)self);
}
%end

// v7.129: all v7.127/v7.128 microphone/dock-item geometry ownership is removed.
// The keyboard below is intentionally the v7.126 OledKeyboard-derived port only.

%hook UIInputView
- (void)layoutSubviews {
    %orig;
    if(!gP.enabled) return;
    @try {
        Class emoji=NSClassFromString(@"TUIEmojiSearchInputView");
        Class autofill=NSClassFromString(@"_SFAutoFillInputView");
        if((emoji && [self isKindOfClass:emoji]) || (autofill && [self isKindOfClass:autofill]))
            ADSetKeyboardFloor7126((UIView *)self);
    } @catch(...) {}
}
%end

%hook UIKBVisualEffectView
- (void)layoutSubviews {
    %orig;
    if(!gP.enabled) return;
    @try {
        if(ADKeyboardDark7126((UIView *)self)){
            self.backgroundEffects=nil;
            self.backgroundColor=ADOLED();
        }
    } @catch(...) {}
}
%end

static NSAttributedString *ADLightAttributedText708(NSAttributedString *in){
    if(!gP.enabled || !in || in.length==0) return in;
    @try {
        NSMutableAttributedString *m=[in mutableCopy];
        [m addAttribute:NSForegroundColorAttributeName value:ADLightText706() range:NSMakeRange(0,m.length)];
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

// v7.154 performance: tab repainting belongs only to Amazon's actual bottom-tab button.
// Do not intercept every UIControl interaction in the app's input hot path.
%hook ANXTabBarButton
- (void)setSelected:(BOOL)selected {
    %orig;
    UIView *v=(UIView *)self;
    if(gP.enabled&&v.window)ADRepaintNearestANXTab724(v);
}
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    BOOL r=%orig;
    UIView *v=(UIView *)self;
    if(gP.enabled&&v.window)ADRepaintNearestANXTab724(v);
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
    ADOwnFocusedSearchSurface7120((UIView *)self);
    ADPrepareSearchKeyboard7120((UIView *)self);
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
        // v7.127: probe/screenshot put the stray bright hairline exactly on this
        // 60pt widget's top edge (y=526). Own the root edge itself instead of
        // touching Search-row separators in WebKit. A black 1pt border is
        // invisible on the OLED body but covers Amazon's stock top seam.
        root.layer.borderWidth=1.0;
        root.layer.borderColor=ADOLED().CGColor;
        root.layer.shadowOpacity=0.0f;
        root.layer.shadowColor=ADOLED().CGColor;
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

// v7.140 exact Search delivery root proven by the current device probe.
%hook GlowIngressView
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window)ADOwnGlowIngress7140(self);
}
- (void)layoutSubviews {
    %orig;
    if(gP.enabled&&self.window)ADOwnGlowIngress7140(self);
}
- (void)didAddSubview:(UIView *)subview {
    %orig;
    if(gP.enabled&&self.window)ADOwnGlowIngress7140(self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled&&self.window&&ADExactGlowIngress7140(self)){
        UIColor *black=ADOLED();
        %orig(black);
        self.layer.backgroundColor=black.CGColor;
        objc_setAssociatedObject(self,kADSearchDeliveryBand7139,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    %orig;
}
%end

// v7.139 exact compact Search delivery/subnav ownership. These controller hooks are
// event-driven and geometry-gated; no hierarchy polling or recurring timer is used.
%hook ANXVisualSubNavViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    ADOwnCompactSearchSubNav7139((UIViewController *)self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    ADOwnCompactSearchSubNav7139((UIViewController *)self);
}
%end

%hook ANXSubNavContainer
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    ADOwnCompactSearchSubNav7139((UIViewController *)self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    ADOwnCompactSearchSubNav7139((UIViewController *)self);
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
static const void *kADTWBEligibility=&kADTWBEligibility;
static const void *kADTWBEligibilityImage=&kADTWBEligibilityImage;
static UIColor *ADNativeTWBOverlayColor7146(void){
    static long cachedStrength=-1; static UIColor *cached=nil;
    long strength=MAX(0,MIN(100,gP.whiteTameStrength));
    if(!cached || cachedStrength!=strength){
        cachedStrength=strength;
        CGFloat shade=0.10+(0.48*(strength/100.0));
        cached=[UIColor colorWithWhite:0 alpha:shade];
    }
    return cached;
}
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
static BOOL ADNativeMediaBlockedCached7146(UIImageView *iv){
    if(!iv||!iv.image)return YES;
    CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
    if(w<52||h<52)return YES; // geometry can still settle; do not cache this early rejection.
    @try {
        UIImage *last=objc_getAssociatedObject(iv,kADTWBEligibilityImage);
        NSNumber *cached=objc_getAssociatedObject(iv,kADTWBEligibility);
        if(last==iv.image&&cached)return cached.boolValue;
        BOOL blocked=ADNativeMediaBlocked(iv);
        objc_setAssociatedObject(iv,kADTWBEligibilityImage,iv.image,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(iv,kADTWBEligibility,@(blocked),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return blocked;
    } @catch(...) { return ADNativeMediaBlocked(iv); }
}
static void ADApplyNativeTWB(UIImageView *iv){
    if(!iv)return;
    @try {
        CALayer *ov=objc_getAssociatedObject(iv,kADTWBOverlay);
        if(!gP.enabled || !gP.whiteTame || !iv.window || ADNativeMediaBlockedCached7146(iv)){
            if(ov){ [ov removeFromSuperlayer]; objc_setAssociatedObject(iv,kADTWBOverlay,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        if(!ov){ ov=[CALayer layer]; ov.name=@"AmazonDarkTWB7"; ov.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"backgroundColor":[NSNull null]}; [iv.layer addSublayer:ov]; objc_setAssociatedObject(iv,kADTWBOverlay,ov,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        ov.frame=iv.bounds; ov.backgroundColor=ADNativeTWBOverlayColor7146().CGColor; ov.zPosition=FLT_MAX;
    } @catch(...) {}
}


%hook UIImageView
- (void)setImage:(UIImage *)image {
    if(gADTabImageWriting724){
        %orig;
        return;
    }
    %orig;
    objc_setAssociatedObject(self,kADTWBEligibility,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,kADTWBEligibilityImage,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(gP.enabled&&self.window){ ADTabImageWhite724(self); ADTintSearchGlyph706(self); ADTintSearchDeliveryGlyph7139(self); }
    if(gP.whiteTame)ADApplyNativeTWB(self);
}
- (void)didMoveToWindow {
    %orig;
    objc_setAssociatedObject(self,kADTWBEligibility,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,kADTWBEligibilityImage,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(gP.enabled&&self.window){ ADTabImageWhite724(self); ADTintSearchGlyph706(self); ADTintSearchDeliveryGlyph7139(self); }
    ADApplyNativeTWB(self);
}
- (void)setTintColor:(UIColor *)color {
    if(gP.enabled&&self.window){
        CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
        if(w>1.0&&h>1.0&&w<=100.0&&h<=100.0){
            if(ADANXTabRoot724(self)){
                UIColor *white=ADLightText706();
                %orig(white);
                return;
            }
            if(ADInMarkedSearchDeliveryBand7139(self)||ADInSearchChrome706(self)||ADIsLocationGlyph709(self)||ADIsSearchBackGlyph7120(self)){
                UIColor *light=ADLightText706();
                %orig(light);
                return;
            }
        }
    }
    %orig;
}
- (void)layoutSubviews {
    %orig;
    if(gP.enabled&&self.window){
        ADTabImageWhite724(self);
        ADTintSearchGlyph706(self);
        ADTintSearchDeliveryGlyph7139(self);
    }
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
    ADPrivacyInstallProtocolOnConfig7117(configuration);
    return %orig;
}
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    ADPrivacyInstallProtocolOnConfig7117(configuration);
    return %orig;
}
- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    ADPrivacyInstallProtocolOnConfig7117(configuration);
    return %orig;
}
%end


// v7.116 production: v7.115 event-driven app handoff retained; SpringBoard owns a
// bounded 0.40 s post-ready settle guard so Amazon's final white loading composite
// cannot peek through the cover fade.
// v7.0.68 production: v7.0.65 chevron diagnostic runtime removed.
static NSUInteger gADSearchResultsProbeRun7139=0;
static dispatch_source_t gADSearchResultsProbeSignal7139=nil;

static NSString *ADSearchResultsProbePath7139(void){
    @try {
        NSString *docs=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject];
        if(docs.length)return [docs stringByAppendingPathComponent:@"AmazonDark-v7.156-search-regression-fix-probe.txt"];
    } @catch(...) {}
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"AmazonDark-v7.156-search-regression-fix-probe.txt"];
}
static void ADSearchResultsProbeAppend7139(NSString *s){
    if(!s.length)return;
    @try {
        NSString *p=ADSearchResultsProbePath7139(); NSFileManager *fm=[NSFileManager defaultManager];
        [fm createDirectoryAtPath:[p stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        NSData *d=[s dataUsingEncoding:NSUTF8StringEncoding];
        if(![fm fileExistsAtPath:p]){ [d writeToFile:p atomically:YES]; return; }
        NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:p];
        if(h){ [h seekToEndOfFile]; [h writeData:d]; [h closeFile]; }
    } @catch(...) {}
}
static NSString *ADSearchResultsProbeColor7139(UIColor *c){
    if(!c)return @"nil";
    @try {
        CGFloat r=0,g=0,b=0,a=0,w=0;
        if([c getRed:&r green:&g blue:&b alpha:&a])return [NSString stringWithFormat:@"rgba(%.3f,%.3f,%.3f,%.3f)",r,g,b,a];
        if([c getWhite:&w alpha:&a])return [NSString stringWithFormat:@"white(%.3f,%.3f)",w,a];
        return c.description?:@"?";
    } @catch(...) { return @"?"; }
}
static NSString *ADSearchResultsProbeCG7139(CGColorRef cg){
    if(!cg)return @"nil";
    @try { return ADSearchResultsProbeColor7139([UIColor colorWithCGColor:cg]); } @catch(...) { return @"?"; }
}
static NSString *ADSearchResultsProbeNative7139(void){
    NSMutableString *m=[NSMutableString string];
    @try {
        CGRect screen=UIScreen.mainScreen.bounds; NSUInteger visited=0,logged=0;
        NSArray *pts=@[[NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(screen),125)],
                       [NSValue valueWithCGPoint:CGPointMake(28,140)],
                       [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(screen),150)],
                       [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(screen),180)]];
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.01)continue;
            [m appendFormat:@"WINDOW cls=%@ key=%d level=%.1f r=(%.1f,%.1f %.1fx%.1f) bg=%@\n",NSStringFromClass(w.class),w.isKeyWindow?1:0,w.windowLevel,w.frame.origin.x,w.frame.origin.y,w.frame.size.width,w.frame.size.height,ADSearchResultsProbeColor7139(w.backgroundColor)];
            NSMutableArray *q=[NSMutableArray arrayWithObject:w];
            while(q.count&&visited++<420&&logged<180){
                UIView *v=q.firstObject; [q removeObjectAtIndex:0]; if(!v||v.hidden||v.alpha<0.01)continue;
                CGRect r=CGRectZero; @try { r=[v convertRect:v.bounds toView:nil]; } @catch(...) {}
                NSString *cn=NSStringFromClass(v.class),*lo=cn.lowercaseString;
                BOOL band=CGRectIntersectsRect(r,CGRectMake(0,80,screen.size.width,150)) && r.size.width>=screen.size.width*0.45 && r.size.height>=10;
                BOOL sem=[lo containsString:@"subnav"]||[lo containsString:@"delivery"]||[lo containsString:@"location"]||[lo containsString:@"topnav"]||[lo containsString:@"ingress"];
                if(band||sem){
                    [m appendFormat:@"N cls=%@ r=(%.1f,%.1f %.1fx%.1f) bg=%@ layerBg=%@ tint=%@ marked=%d aid=\"%@\"\n",cn,r.origin.x,r.origin.y,r.size.width,r.size.height,ADSearchResultsProbeColor7139(v.backgroundColor),ADSearchResultsProbeCG7139(v.layer.backgroundColor),ADSearchResultsProbeColor7139(v.tintColor),ADInMarkedSearchDeliveryBand7139(v)?1:0,v.accessibilityIdentifier?:@""]; logged++;
                }
                if(q.count<420&&v.subviews.count)[q addObjectsFromArray:v.subviews];
            }
            for(NSValue *pv in pts){ CGPoint p=pv.CGPointValue; UIView *h=[w hitTest:p withEvent:nil]; NSMutableArray *c=[NSMutableArray array]; for(UIView *x=h;x&&c.count<12;x=x.superview)[c addObject:NSStringFromClass(x.class)]; [m appendFormat:@"HIT (%.0f,%.0f) %@\n",p.x,p.y,c.count?[c componentsJoinedByString:@" <- "]:@"nil"]; }
        }
    } @catch(NSException *e){ [m appendFormat:@"NATIVE_EXCEPTION %@\n",e]; }
    return m;
}

static NSString *ADSearchResultsProbeGlowLayers7141(void){
    NSMutableString *m=[NSMutableString string];
    @try {
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.01)continue;
            NSMutableArray *q=[NSMutableArray arrayWithObject:w]; NSUInteger seen=0;
            while(q.count&&seen++<420){
                UIView *v=q.firstObject; [q removeObjectAtIndex:0]; if(!v)continue;
                if(ADExactGlowIngress7140(v)){
                    NSMutableArray *lq=[NSMutableArray arrayWithObject:@{ @"l":v.layer,@"d":@0 }]; NSUInteger ln=0;
                    while(lq.count&&ln++<120){
                        NSDictionary *it=lq.firstObject; [lq removeObjectAtIndex:0]; CALayer *l=it[@"l"]; NSUInteger d=[it[@"d"] unsignedIntegerValue]; if(!l)continue;
                        NSUInteger chars=MIN((NSUInteger)40,d*2); NSString *pad=[@"                                        " substringToIndex:chars];
                        [m appendFormat:@"%@L cls=%@ name=\"%@\" f=(%.1f,%.1f %.1fx%.1f) bg=%@ contents=%d hidden=%d op=%.2f z=%.2f\n",pad,NSStringFromClass(l.class),l.name?:@"",l.frame.origin.x,l.frame.origin.y,l.frame.size.width,l.frame.size.height,ADSearchResultsProbeCG7139(l.backgroundColor),l.contents?1:0,l.hidden?1:0,l.opacity,l.zPosition];
                        for(CALayer *c in l.sublayers?:@[])if(lq.count<120)[lq addObject:@{ @"l":c,@"d":@(d+1) }];
                    }
                }
                if(q.count<420&&v.subviews.count)[q addObjectsFromArray:v.subviews];
            }
        }
    } @catch(NSException *e){ [m appendFormat:@"LAYER_EXCEPTION %@\n",e]; }
    return m;
}

static NSString *ADSearchResultsProbeSafeURL7139(WKWebView *wv){
    @try {
        NSURL *u=wv.URL; if(!u)return @"";
        return [NSString stringWithFormat:@"%@://%@%@",u.scheme?:@"https",u.host?:@"",u.path?:@""];
    } @catch(...) { return @""; }
}
static NSString *ADSearchResultsProbeWebList7139(void){
    NSMutableString *m=[NSMutableString string]; NSUInteger n=0;
    @try {
        for(WKWebView *wv in ADTrackedWebViews()){
            if(!wv)continue; CGRect r=CGRectZero; @try { r=[wv convertRect:wv.bounds toView:nil]; } @catch(...) {}
            CGRect ir=CGRectIntersection(r,UIScreen.mainScreen.bounds); CGFloat area=MAX(0,ir.size.width)*MAX(0,ir.size.height);
            [m appendFormat:@"WEB #%lu aid=\"%@\" path=\"%@\" visible=%d loading=%d r=(%.1f,%.1f %.1fx%.1f) visibleArea=%.0f bg=%@ scrollBg=%@\n",
                (unsigned long)n++,wv.accessibilityIdentifier?:@"",ADSearchResultsProbeSafeURL7139(wv),(wv.window&&!wv.hidden&&wv.alpha>0.01&&area>1)?1:0,wv.loading?1:0,
                r.origin.x,r.origin.y,r.size.width,r.size.height,area,ADSearchResultsProbeColor7139(wv.backgroundColor),ADSearchResultsProbeColor7139(wv.scrollView.backgroundColor)];
        }
    } @catch(NSException *e){ [m appendFormat:@"WEBLIST_EXCEPTION %@\n",e]; }
    return m;
}
static NSString *ADSearchResultsProbeJS7139(void){
    return @"(function(){try{"
    "function S(e,p){try{var s=getComputedStyle(e,p||null);return {content:s.content||'none',display:s.display,vis:s.visibility,op:s.opacity,bg:s.backgroundColor,bgi:s.backgroundImage,bgp:s.backgroundPosition,bgs:s.backgroundSize,bgr:s.backgroundRepeat,mask:s.webkitMaskImage||s.maskImage||'none',color:s.color,fill:s.fill,stroke:s.stroke,filter:s.webkitFilter||s.filter||'none',border:s.border,radius:s.borderRadius,shadow:s.boxShadow,outline:s.outline,font:s.fontFamily,fontSize:s.fontSize,fontWeight:s.fontWeight,lineHeight:s.lineHeight,textShadow:s.textShadow,webkitTextStroke:s.webkitTextStroke||'',transform:s.transform,overflow:s.overflow,clipPath:s.clipPath||s.webkitClipPath||'',z:s.zIndex,position:s.position};}catch(_){return {err:String(_)}}}"
    "function P(e){if(!e)return null;var r=e.getBoundingClientRect(),o={tag:e.tagName,id:e.id||'',cls:String(e.className||'').slice(0,260),r:[+r.x.toFixed(1),+r.y.toFixed(1),+r.width.toFixed(1),+r.height.toFixed(1)],attrs:{badgeType:A(e,'data-a-badge-type'),badgeColor:A(e,'data-a-badge-color'),testid:A(e,'data-testid'),component:A(e,'data-component-type')},style:S(e),before:S(e,'::before'),after:S(e,'::after')};if(e.tagName==='VIDEO'){o.media={muted:e.muted?1:0,volume:+(+e.volume||0).toFixed(3),paused:e.paused?1:0,controls:e.controls?1:0,readyState:e.readyState||0,currentTime:+(+e.currentTime||0).toFixed(2)};o.ua={mute:S(e,'::-webkit-media-controls-mute-button'),play:S(e,'::-webkit-media-controls-play-button'),panel:S(e,'::-webkit-media-controls-panel')};}return o;}"
    "function C(e,n){var a=[];for(var x=e;x&&a.length<(n||6);x=x.parentElement)a.push(P(x));return a;}"
    "function Q(sel){return [].slice.call(document.querySelectorAll(sel));}"
    "function G(sel,n){var a=Q(sel);return {count:a.length,items:a.slice(0,n||48).map(P)};}"
    "function GC(sel,n){var a=Q(sel);return {count:a.length,items:a.slice(0,n||32).map(function(e){return {self:P(e),chain:C(e,7)}})};}"
    "function A(e,n){try{return String(e.getAttribute&&e.getAttribute(n)||'').slice(0,360)}catch(_){return ''}}"
    "function CP(e){var o=P(e)||{};try{o.ctrl={aria:(/mute|unmute|sound|volume|speaker|audio/i.test(A(e,'aria-label'))?A(e,'aria-label'):''),title:(/mute|unmute|sound|volume|speaker|audio/i.test(A(e,'title'))?A(e,'title'):''),role:A(e,'role'),testid:A(e,'data-testid'),name:A(e,'name'),type:A(e,'type'),viewBox:A(e,'viewBox'),href:(e.tagName==='USE'?A(e,'href')||A(e,'xlink:href'):''),d:(e.tagName==='PATH'?A(e,'d'):'')};}catch(_){}return o;}"
    "function TREE(root){var budget=220;function W(e,d){if(!e||budget--<=0)return null;var o=CP(e);if(d<12){var kids=[];for(var c=e.firstElementChild;c&&kids.length<50;c=c.nextElementSibling){var z=W(c,d+1);if(z)kids.push(z);}if(kids.length)o.children=kids;}return o;}return W(root,0);}"
    "function VCTRL(){var out=[];try{var roots=Q('#search .sbv-video-overlay,.sbv-video-overlay,#search video.sbv-video-player-ecx,video.sbv-video-player-ecx,#search video._c2Itd_video_17g-f,#search ._c2Itd_videoOverlay_1H_Jm,#search ._c2Itd_playClickRegion_87ZZa,[class*=single-video-card],[class*=singleVideoCard],.video-js');for(var r=0;r<roots.length&&out.length<24;r++){var root=roots[r],cand=[];try{cand=[].slice.call(root.querySelectorAll('button,[role=button],[aria-label],[title],svg,use,path,i,span,div')).filter(function(e){var k=(String(e.id||'')+' '+String(e.className&&e.className.baseVal||e.className||'')+' '+A(e,'aria-label')+' '+A(e,'title')+' '+A(e,'data-testid')).toLowerCase();return /mute|unmute|sound|volume|speaker|audio/.test(k);});}catch(_){}var buttons=[];try{buttons=[].slice.call(root.querySelectorAll('button,[role=button]'));}catch(_){}var uniq=[];cand.concat(buttons).forEach(function(e){if(e&&uniq.indexOf(e)<0&&uniq.length<20)uniq.push(e);});out.push({root:CP(root),rootTree:TREE(root),controls:uniq.map(function(e){return {ancestors:C(e,12),tree:TREE(e)}})});} }catch(e){out.push({err:String(e)})}return {count:out.length,items:out};}"
        "var w=innerWidth,h=innerHeight,ys=[.03,.08,.14,.22,.31,.42,.56,.72,.86];"
    "var hit=ys.map(function(y){var x=Math.round(w*.5),py=Math.round(h*y),a=(document.elementsFromPoint?document.elementsFromPoint(x,py):[document.elementFromPoint(x,py)]).filter(Boolean).slice(0,10);return {p:[x,py],stack:a.map(P)};});"
    "var o={path:location.pathname,ready:document.readyState,viewport:[w,h,devicePixelRatio],scroll:[document.documentElement.scrollWidth,document.documentElement.scrollHeight],body:P(document.body),doc:P(document.documentElement),"
    "root:G('#search,#a-page',12),"
    "ribbon:G('[class*=sf-rib],[class*=sf-mobile-rib],[class*=filter]',64),"
    "ribbonArt:GC('.s-rib-toggle-container,.s-rib-toggle-icon,.sf-rib30-dropdown-pill-icon,.sf-rib30-review-content,.sf-rib30-review-stars-group,.sf-rib30-review-star,i.a-icon-prime.a-icon-small,.sf-mobile-rib-filter-icon,.sf-rib30-dropdown-arrow-icon',56),"
    "ribbonDropdowns:GC('.sf-rib30-dropdown-title,.sf-rib30-title-content-container,.sf-rib30-dropdown-title .sf-rib30-dropdown-pill-content,.sf-rib30-dropdown-title .sf-rib30-dropdown-pill-text,.sf-rib30-dropdown-title .sf-rib30-dropdown-arrow-icon,a[id^=dynamic-picker-].sf-rib30-dropdown-pill-option,a[id^=dynamic-picker-] .sf-rib30-dropdown-pill-content,a[id^=dynamic-picker-] .sf-rib30-dropdown-pill-text',72),"
    "ribbonPanel:GC('#search .sf-rib30-panel,#search .sf-rib30-content,#search .sf-rib30-panel .a-button,#search .sf-rib30-panel .a-button-inner,#search .sf-rib30-panel .a-button-text,#search .sf-rib30-panel button',96),"
    "autocomplete:GC('#attach-to-me,#attach-to-me .s-suggestion-container,#attach-to-me .s-suggestion,#attach-to-me .s-query-row,#attach-to-me .s-query-row-container,#attach-to-me .s-query-row-link,.autocomplete-results-container',100),"
    "searchDirect:GC('#search>div,#search>section,#search>article,#search .s-main-slot>div,#search .s-main-slot>section,#search .s-main-slot>article',120),"
    "heroSponsored:GC('#gwm-window [id^=wd-shoppable-] [data-ad-feedback-label-id],#gwm-window [id^=wd-shoppable-] .ape-feedback,#gwm-window [id^=wd-shoppable-] [class*=ad-feedback],#gwm-window [id^=wd-shoppable-] [id^=ad-feedback-],[class*=single-creative-card] [data-ad-feedback-label-id],[class*=single-creative-card] [class*=ad-feedback],[id*=mobile-wd-][class*=ape-feedback]',80),"
    "homeAdShells:GC('#gwm-window,[id^=wd-shoppable-],[class*=single-creative-card],[class*=single-video-card],[class*=ape-wrapper],[class*=ape-placement],[class*=ape-feedback],[data-testid=renderer-factory-ad-container],#ad,#dynamic-bb,[data-acei-id=lfstyl-img],[data-acei-id=prod-img]',90),"
    "homeAdMedia:GC('#gwm-window [id^=wd-shoppable-] img,#gwm-window [id^=wd-shoppable-] video,#gwm-window [id^=wd-shoppable-] canvas,[class*=single-creative-card] img,[class*=single-video-card] img,#ad:has(#dynamic-bb) img,#ad:has(#dynamic-bb) video,#ad:has(#dynamic-bb) canvas,[data-testid=renderer-factory-ad-container] img,[data-acei-id=lfstyl-img] img,[data-acei-id=prod-img] img',100),"
    "location:G('#nav-global-location-slot,#glow-ingress-block,[id*=glow-ingress],[class*=glow-ingress],[id*=delivery-location],[class*=delivery-location],[id*=ship-to],[class*=ship-to]',48),"
    "ai:GC('#search [class*=alexa],#search [id*=alexa],#search [class*=research],#search [id*=research],#search [class*=rufus],#search [id*=rufus],#search [class*=query-understanding],#search [class*=shopping-assistant],#search [class*=ai-overview],#search [class*=search-guidance],#search [class*=guided-search]',96),"
    "aiLogo:GC('#search [class*=alexa-plus-logo],#search [class*=rufus][class*=icon],#search img[class*=alexa],#search img[class*=rufus]',32),"
    "aiControls:GC('#search .rufus-expandable-pills-toggle-button,#search .rufus-expandable-pills-chevron,#search .rufus-expandable-pills-chevron img',32),"
    "aiPills:GC('#search #rufus-overviews-pills-carousel,#search #rufus-mobile-overviews-expandable-pills-carousel-container,#search #rufus-overviews-pills-carousel .a-carousel-card,#search #rufus-mobile-overviews-expandable-pills-carousel-container .a-carousel-card,#search .nile-inline-pill-button,#search .nile-inline-ingress-pill-button,#search #rufus-overviews-pills-carousel .a-button-inner,#search #rufus-mobile-overviews-expandable-pills-carousel-container .a-button-inner',72),"
    "tiles:GC('#search #rufus-overviews-category-cards-carousel .a-carousel-card,#search #rufus-overviews-category-cards-carousel .a-carousel-card > .a-box,#search #rufus-overviews-category-cards-carousel .nice-cat-card_box,#search #rufus-overviews-category-cards-carousel img.nice-cat-card_image',64),"
    "atc:GC('#search .puis-atcb-button,#search .puis-atcb-button .a-button-inner,#search .puis-atcb-button .a-button-text',48),"
    "results:G('#search .s-result-item,#search .s-card-container,#search [data-component-type=s-search-result],#search .puisg-row,#search .puisg-col,#search .puisg-col-inner',72),"
    "badges:G('#search .puis-status-badge-container,#search .puis-status-badge-container .a-badge,#search .puis-status-badge-container .a-badge-label',32),"
    "microBadges:GC('#search .puis-card-container .a-badge,#search .puis-card-container .a-badge-label,#search .puis-card-container .a-badge-label-inner,#search .puis-card-container [data-a-badge-type],#search .puis-card-container [data-a-badge-color],#search .puis-card-container .a-color-success,#search .puis-card-container [class*=success],#search .puis-card-container [class*=saving],#search .puis-card-container [class*=savings],#search .puis-card-container [class*=natural],#search .puis-card-container [class*=attribute],#search .puis-card-container [class*=variation]',140),"
    "actions:GC('#search .more-like-this-container,#search .mlt-icon-container,#search .mlt-icon-container *,#search .lists-framework-action-button.puis-heart-icon-container,#search .lists-framework-heart-background',64),"
    "videoAd:GC('#search .sbv-video-overlay,#search video.sbv-video-player-ecx,#search .sbv-video,#search .sbv-video-container,#search .sbv-mobile-video-link',64),"
    "videoControls:GC('#search .sbv-video-overlay,#search .sbv-video-overlay *',180),"
    "videoControlTrees:VCTRL(),"
    "videoCard:GC('#search .sbv-video-single-product,#search .s-card-container:has(.sbv-video-single-product),#search .sbv-video-single-product :is(div,section,article,span,img,video,canvas)',220),"
    "altVideoCard:GC('#search ._c2Itd_container_ut_MN,#search ._c2Itd_cardContent_3OGkG,#search ._c2Itd_content_2L-a5,#search ._c2Itd_videoSectionContainer_Ot6Fs,#search ._c2Itd_videoOverlay_1H_Jm,#search ._c2Itd_playClickRegion_87ZZa,#search video._c2Itd_video_17g-f,#search ._c2Itd_singleAsin_fHkKv,#search ._c2Itd_singleAsin_fHkKv *,#search img._c2Itd_image_pQREQ',260),"
    "coupon:GC('#search [data-component-type=s-coupon-component],#search .s-coupon-tile-content-container,#search .s-coupon-tile,#search .s-coupon-tile-text-content,#search .s-coupon-checkbox-label,#search .s-coupon-tile-price-content,#search .s-coupon-unclipped,#search .s-coupon-highlight-color,#search [class*=coupon][class*=price],#search [class*=coupon][class*=highlight]',96),"
    "nile:GC('#search .nile-ingress-pill-button,#search .nile-ingress-pill-button .a-button-inner',64),"
    "haul:GC('#search [class*=haul-puis],#search [class*=haul-asin-recommendation]',160),"
    "accents:G('#search i.a-icon-prime,#search [class*=prime],#search i[class*=a-icon-star],#search [class*=star],#search [class*=rating]',48),"
    "media:G('#search img,#search picture,#search video,#search canvas',64),hit:hit};"
    "return JSON.stringify(o,null,2);}catch(e){return 'SEARCH_RESULTS_DOM_ERR '+e;}})();";
}
static void ADCaptureSearchResultsProbe7139(NSString *trigger){
    if(!gP.enabled)return; NSUInteger run=++gADSearchResultsProbeRun7139;
    NSString *head=[NSString stringWithFormat:@"\n\n================ AMAZON DARK v7.156 SEARCH REGRESSION FIX PROBE RUN %lu ================\ndate=%@\npid=%d\nversion=%s\ntrigger=%@\npolicy=no typed query text, element text, outerHTML, clipboard data, request bodies or headers captured\n\n===== TOP NATIVE =====\n%@\n===== LOCATION LAYERS =====\n%@\n===== TRACKED WEBVIEWS =====\n%@\n",
        (unsigned long)run,[NSDate date],getpid(),AD_VERSION,trigger?:@"unknown",ADSearchResultsProbeNative7139(),ADSearchResultsProbeGlowLayers7141(),ADSearchResultsProbeWebList7139()];
    ADSearchResultsProbeAppend7139(head);
    NSMutableArray *home=[NSMutableArray array],*search=[NSMutableArray array],*fallback=[NSMutableArray array];
    @try {
        for(WKWebView *wv in ADTrackedWebViews()){
            if(!wv||!wv.window||wv.hidden||wv.alpha<0.01)continue;
            CGRect r=[wv convertRect:wv.bounds toView:nil],ir=CGRectIntersection(r,UIScreen.mainScreen.bounds); CGFloat a=MAX(0,ir.size.width)*MAX(0,ir.size.height); if(a<1000)continue;
            NSDictionary *it=@{ @"wv":wv,@"a":@(a) }; NSString *path=wv.URL.path?:@"";
            if([path containsString:@"/gp/gw/ajax/mshop.html"])[home addObject:it];
            else if([path isEqualToString:@"/s"]||[path hasPrefix:@"/s/"])[search addObject:it];
            else [fallback addObject:it];
        }
        NSComparator cmp=^NSComparisonResult(NSDictionary *a,NSDictionary *b){ return [b[@"a"] compare:a[@"a"]]; };
        [home sortUsingComparator:cmp]; [search sortUsingComparator:cmp]; [fallback sortUsingComparator:cmp];
    } @catch(...) {}
    NSMutableArray *chosen=[NSMutableArray array];
    for(NSDictionary *it in home)if(chosen.count<2)[chosen addObject:it];
    for(NSDictionary *it in search)if(chosen.count<3)[chosen addObject:it];
    for(NSDictionary *it in fallback)if(chosen.count<3)[chosen addObject:it];
    if(!chosen.count){ ADSearchResultsProbeAppend7139(@"\nNO_VISIBLE_TRACKED_WKWEBVIEW\n================ END RUN ================\n"); return; }
    NSUInteger lim=MIN((NSUInteger)3,chosen.count); __block NSUInteger pending=lim*2;
    void (^done)(void)=^{ if(--pending==0)ADSearchResultsProbeAppend7139(@"================ END RUN ================\n"); };
    for(NSUInteger i=0;i<lim;i++){
        WKWebView *wv=chosen[i][@"wv"];
        NSString *tok=[NSString stringWithFormat:@"%lu-%lu-%llu",(unsigned long)run,(unsigned long)i,(unsigned long long)([[NSDate date] timeIntervalSince1970]*1000.0)];
        ADSearchResultsProbeAppend7139([NSString stringWithFormat:@"\n===== WEB DOM #%lu =====\naid=\"%@\" path=\"%@\"\n",(unsigned long)i,wv.accessibilityIdentifier?:@"",ADSearchResultsProbeSafeURL7139(wv)]);
        NSString *startJS=[NSString stringWithFormat:@"(function(){try{return window.__ad7144StartProbe?window.__ad7144StartProbe('%@'):'NO_ALL_FRAME_PROBE';}catch(e){return 'START_ERR '+e;}})();",tok];
        @try { [wv evaluateJavaScript:startJS completionHandler:nil]; } @catch(...) {}
        [wv evaluateJavaScript:ADSearchResultsProbeJS7139() completionHandler:^(id v,NSError *e){
            NSString *body=e?[NSString stringWithFormat:@"EVAL_ERROR %@",e]:([v isKindOfClass:[NSString class]]?v:[v description]);
            ADSearchResultsProbeAppend7139([NSString stringWithFormat:@"%@\n",body?:@"NO_DOM_DATA"]); done();
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.65*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            NSString *dumpJS=[NSString stringWithFormat:@"(function(){try{return window.__ad7144DumpProbe?window.__ad7144DumpProbe('%@'):'NO_ALL_FRAME_DUMP';}catch(e){return 'DUMP_ERR '+e;}})();",tok];
            @try {
                [wv evaluateJavaScript:dumpJS completionHandler:^(id v,NSError *e){
                    NSString *body=e?[NSString stringWithFormat:@"ALL_FRAME_EVAL_ERROR %@",e]:([v isKindOfClass:[NSString class]]?v:[v description]);
                    ADSearchResultsProbeAppend7139([NSString stringWithFormat:@"\n===== HOME AD ALL-FRAME #%lu =====\n%@\n",(unsigned long)i,body?:@"NO_ALL_FRAME_DATA"]); done();
                }];
            } @catch(...) { ADSearchResultsProbeAppend7139(@"\nALL_FRAME_EXCEPTION\n"); done(); }
        });
    }
}
static void ADInstallSearchResultsProbe7139(void){
    static dispatch_once_t once; dispatch_once(&once,^{
        signal(SIGUSR2,SIG_IGN);
        gADSearchResultsProbeSignal7139=dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,SIGUSR2,0,dispatch_get_main_queue());
        if(gADSearchResultsProbeSignal7139){ dispatch_source_set_event_handler(gADSearchResultsProbeSignal7139,^{ ADCaptureSearchResultsProbe7139(@"SIGUSR2"); }); dispatch_resume(gADSearchResultsProbeSignal7139); }
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationUserDidTakeScreenshotNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *n){ ADCaptureSearchResultsProbe7139(@"screenshot"); }];
    });
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

    ADInstallSearchResultsProbe7139();

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
