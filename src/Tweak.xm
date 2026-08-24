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
 *   - contrast scanners, repair queues, probes and theme MutationObservers
 *
 * The only always-on visual owner is an OLED-black FLOOR. It targets root/backing
 * surfaces, not text, glyphs, cards, borders, buttons or images.
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

#define AD_VERSION "v7.81-sponsor-inventory-probe"
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

// -----------------------------------------------------------------------------
// Preferences — same public keys/domain as v6.0.185.
// -----------------------------------------------------------------------------
typedef struct {
    BOOL enabled;
    BOOL whiteTame;
    BOOL force120Hz;
    BOOL enableJIT;
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
        gP.whiteTameStrength=ADPrefLong(d,@"whiteTameStrength",gP.whiteTameStrength);
    } @catch(...) {}
}

static inline UIColor *ADOLED(void){ return [UIColor blackColor]; }

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
static void ADScheduleLaunchReadyCheck706(void);
static const void *kADFloorUS=&kADFloorUS;
static const void *kADTWBUS=&kADTWBUS;
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
            ".s-suggestion,.s-suggestion-container,[class*=recentSearch],[class*=search-suggestion],"
            "#authportal-main-section,#auth-footer,.auth-footer,[id*=auth-footer],"
            "[class*=variation],[class*=swatch-container],[class*=status-shell],[class*=badge-message],"
            "[class*=puis-card]:not([class*=creative]):not([class*=image]),[class*=product-card]:not([class*=image])"
            "{background-color:#181a1b!important;}"
            /* First-paint Search surface. Search overlay content must remain visible. */
            ".s-suggestion-container,.s-suggestion,.autocomplete-results-container,[class*=autocomplete],[class*=suggestion]"
            "{background:#181a1b!important;color:#e8e6e3!important;}"
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
            /* Known mask glyphs from v5/v6 Search history; preserve the mask, own only its ink. */
            ".s-suggestion-container [class*=icon-past-search-sugge],"
            ".s-suggestion-container .icon-close.s-suggestion-icon-left"
            "{background-color:#e8e6e3!important;filter:none!important;opacity:1!important;}"
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
            /* v7.0.50: Sponsored TEXT remains Amazon-owned. Glyph paint is synced
             * separately from the label's computed color by a tiny event-driven JS
             * helper below; no fixed Sponsored text color exists in this sheet. */
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
            /* v7.0.72 Sponsored feedback semantic completion.
             * Keeps the v7.0.70 static Amazon-class renderer lock, but fixes the
             * upstream miss shown by the v7.0.71 tap probe. Some Amazon feedback
             * controls expose the row semantically as aria-label="Leave feedback
             * on Sponsored" even when the visible text host does not use the
             * ad-feedback-text/sponsored-label class families. Treat that semantic
             * feedback control as a Sponsor seed, then resolve at most 16 local
             * descendants to the exact visible Sponsored text leaf before reading
             * its computed color. The existing tiny-glyph finder and static CSS
             * lock then own only the adjacent glyph. No observer, timer, scroll
             * listener, interval or RAF is used. Sponsored text is never written. */
            "try{(function(){"
            "if(window.__ADSPG7070__)return;window.__ADSPG7070__=1;"
            "var LS='[class*=ad-feedback-text],[class*=sponsored-label],[id^=ad-feedback-text-],[id^=af-label-primary-link-],[aria-label^=\"Leave feedback on Sponsored\"]';"
            "var GS='[class*=ad-feedback-spr],[class*=ad-feedback-sprite],[class*=adFeedback],[id*=feedbackIcon],[id*=feedback-icon],[class*=_sponsored-products-mo]';"
            "var REG=window.__ADSPGR7070__||(window.__ADSPGR7070__={});"
            "function sheet(){try{var st=document.getElementById('ad-spg-lock7070');if(st)return st;st=document.createElement('style');st.id='ad-spg-lock7070';(document.head||document.documentElement).appendChild(st);return st}catch(_){return null}}"
            "function txt(e){try{return String(e.textContent||'').replace(/\\s+/g,' ').trim().toLowerCase()}catch(_){return ''}}"
            "function cls(e){try{var c=e&&e.className;if(c&&c.baseVal!==undefined)c=c.baseVal;return String(c||'')}catch(_){return ''}}"
            "function esc(v){try{return window.CSS&&CSS.escape?CSS.escape(String(v)):String(v).replace(/[^a-zA-Z0-9_-]/g,function(ch){return '\\\\'+ch})}catch(_){return String(v||'')}}"
            "function isL(e){if(!e||e.nodeType!==1)return false;try{var ar=String((e.getAttribute&&e.getAttribute('aria-label'))||'').toLowerCase();return e.matches(LS)&&(txt(e)==='sponsored'||txt(e)==='sponsored ad'||txt(e)==='advertisement'||ar.indexOf('leave feedback on sponsored')===0||/ad-feedback|sponsored/i.test(cls(e)+' '+String(e.id||'')))}catch(_){return false}}"
            "function near(a,b){try{var ar=a.getBoundingClientRect(),br=b.getBoundingClientRect(),acy=ar.top+ar.height/2,bcy=br.top+br.height/2,dx=Math.max(0,Math.max(br.left-ar.right,ar.left-br.right));return dx<=30&&Math.abs(acy-bcy)<=22}catch(_){return false}}"
            "function tinyPainter(e,l){try{if(!e||e===l||e.nodeType!==1)return false;var r=e.getBoundingClientRect();if(r.width<5||r.height<5||r.width>36||r.height>36||!near(e,l))return false;var cs=getComputedStyle(e),bi=String(cs.backgroundImage||'none'),mi=String(cs.webkitMaskImage||cs.maskImage||'none'),tg=String(e.tagName||'').toLowerCase();return (bi&&bi!=='none')||(mi&&mi!=='none')||tg==='svg'||tg==='img'||/ad-feedback|feedback|sponsor|spr|info|icon/i.test(cls(e)+' '+String(e.id||''))}catch(_){return false}}"
            "function glyph(l){try{var q=l.querySelector(GS+', [class*=spr]');if(q&&tinyPainter(q,l))return q;var p=l.parentElement;for(var i=0;p&&i<3;i++,p=p.parentElement){q=p.querySelector(GS);if(q&&tinyPainter(q,l))return q;var a=p.querySelectorAll('[class*=spr],[class*=_sponsored-products-mo],span,div,i,b,svg,img');for(var j=0;j<a.length&&j<40;j++)if(tinyPainter(a[j],l))return a[j]}}catch(_){}return null}"
            "function rgba(v){var m=String(v||'').match(/rgba?\\(([^)]+)\\)/i);if(!m)return null;var a=m[1].split(',');if(a.length<3)return null;return [parseFloat(a[0]),parseFloat(a[1]),parseFloat(a[2]),a.length>3?parseFloat(a[3]):1]}"
            "function toks(e,rex){try{var a=cls(e).trim().split(/\\s+/),o=[];for(var i=0;i<a.length&&o.length<2;i++)if(a[i]&&(!rex||rex.test(a[i])))o.push(a[i]);if(!o.length&&a[0])o.push(a[0]);return o}catch(_){return []}}"
            "function atom(e,scope){try{if(!e||e.nodeType!==1)return '';var tag=String(e.tagName||'*').toLowerCase(),id=String(e.id||'');if(/feedbackicon/i.test(id))return tag+'[id*=feedbackIcon]';if(/feedback-icon/i.test(id))return tag+'[id*=feedback-icon]';if(scope&&/^af-label-primary-link-/.test(id))return tag+'[id^=af-label-primary-link-]';if(scope&&/^ad-feedback-/.test(id))return tag+'[id^=ad-feedback-]';var r=scope?/adfeedback|ad-feedback|sponsor|ape|gwm|npack|cxvhz|puis|asin|widget/i:/ad-feedback|feedback|sponsor|spr|icon/i,a=toks(e,r),z=tag;for(var i=0;i<a.length;i++)z+='.'+esc(a[i]);return z}catch(_){return ''}}"
            "function common(l,g){try{var p=l.parentElement||l,b=l.parentElement||l;for(var i=0;p&&i<6;i++,p=p.parentElement){if(p.contains(g)){b=p;var sem=cls(p)+' '+String(p.id||'');if(/adfeedback|ad-feedback|sponsor|ape-feedback|gwm|npack|cxvhz|puis|asin/i.test(sem))return p}}return b}catch(_){return l.parentElement||l}}"
            "function nthPath(h,g){try{var a=[],n=g;while(n&&n!==h&&a.length<5){var par=n.parentElement;if(!par)return '';var ix=1,c=par.firstElementChild;while(c&&c!==n){ix++;c=c.nextElementSibling}a.unshift(String(n.tagName||'*').toLowerCase()+':nth-child('+ix+')');n=par}return n===h&&a.length?' > '+a.join(' > '):''}catch(_){return ''}}"
            "function selector(l,g){try{var h=common(l,g),hs=atom(h,true),gs=atom(g,false);if(h&&g&&h!==g&&hs){var gc=cls(g);if(gc||/feedbackicon|feedback-icon/i.test(String(g.id||'')))return hs+' '+gs;var np=nthPath(h,g);if(np)return hs+np}return gs||GS}catch(_){return GS}}"
            "function lock(l,g,c,rv,cs,svg){try{var sel=selector(l,g),mi=String(cs.webkitMaskImage||cs.maskImage||'none'),bi=String(cs.backgroundImage||'none'),mode='color',img='',pos='0% 0%',size='auto',rep='no-repeat',flt='none';if(mi&&mi!=='none'){mode='mask';img=mi;pos=cs.webkitMaskPosition||cs.maskPosition||'0% 0%';size=cs.webkitMaskSize||cs.maskSize||'auto';rep=cs.webkitMaskRepeat||cs.maskRepeat||'no-repeat'}else if(svg){mode='svg'}else if(bi&&bi!=='none'){mode='mask';img=bi;pos=cs.backgroundPosition||'0% 0%';size=cs.backgroundSize||'auto';rep=cs.backgroundRepeat||'no-repeat'}else{var spread=Math.max(rv[0],rv[1],rv[2])-Math.min(rv[0],rv[1],rv[2]);if(spread<=8){mode='filter';var gray=(rv[0]+rv[1]+rv[2])/3/255;flt='brightness(0) invert('+gray.toFixed(5)+')'}}var key=sel+'|'+mode+'|'+c+'|'+img+'|'+pos+'|'+size+'|'+rep+'|'+flt;if(REG[key])return;REG[key]=1;var st=sheet();if(!st)return;var base=sel+'{color:'+c+'!important;opacity:'+String(isFinite(rv[3])?rv[3]:1)+'!important;visibility:visible!important;mix-blend-mode:normal!important;position:relative!important;z-index:2!important;';if(mode==='mask')base+='background-image:none!important;background-color:'+c+'!important;-webkit-mask-image:'+img+'!important;mask-image:'+img+'!important;-webkit-mask-position:'+pos+'!important;mask-position:'+pos+'!important;-webkit-mask-size:'+size+'!important;mask-size:'+size+'!important;-webkit-mask-repeat:'+rep+'!important;mask-repeat:'+rep+'!important;filter:none!important;-webkit-filter:none!important;';else if(mode==='filter')base+='filter:'+flt+'!important;-webkit-filter:'+flt+'!important;';else base+='filter:none!important;-webkit-filter:none!important;';base+='}';if(mode==='svg')base+=sel+' svg,'+sel+' path,'+sel+' use,'+sel+' circle,'+sel+' rect,'+sel+' polygon,'+sel+' polyline,'+sel+' line{color:'+c+'!important;fill:'+c+'!important;stroke:'+c+'!important;}';st.textContent+=base}catch(_){}}"
            "function ink(l){try{if(txt(l)==='sponsored'||txt(l)==='sponsored ad')return l;var a=l.querySelectorAll('span,a,div,small');for(var i=0;i<a.length&&i<16;i++){var t=txt(a[i]);if(t==='sponsored'||t==='sponsored ad')return a[i]}}catch(_){}return l}function paint(l){try{if(!isL(l))return;var li=ink(l),lc=getComputedStyle(li),c=lc.color,rv=rgba(c),g=glyph(li);if(!g||!rv)return;var cs=getComputedStyle(g),svg=g.matches('svg')?g:g.querySelector('svg');lock(li,g,c,rv,cs,svg)}catch(_){}}"
            "function all(root){try{var a=(root||document).querySelectorAll(LS),n=Math.min(a.length,64);for(var i=0;i<n;i++)paint(a[i])}catch(_){}}"
            "function local(n){try{var p=n&&n.nodeType===1?n:n&&n.parentElement;for(var i=0;p&&i<5;i++,p=p.parentElement){if(isL(p)){paint(p);return}var l=p.querySelector&&p.querySelector(LS);if(l){paint(l);return}}}catch(_){}}"
            "if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',function(){all(document)},{once:true});else all(document);window.addEventListener('load',function(){all(document)},{once:true});window.addEventListener('pageshow',function(){all(document)},false);document.addEventListener('load',function(e){local(e.target)},true);"
            "})();}catch(__){}"
            "document.documentElement.style.setProperty('background-color','#000','important');"
            "document.documentElement.style.setProperty('color-scheme','dark','important');"
            "if(document.body){document.body.style.setProperty('background-color','#000','important');document.body.style.setProperty('color-scheme','dark','important');}"
            "}catch(e){}})();";
}

static NSString *ADTWBJS(void){
    // Pure CSS TWB owner: no load listener, no querySelectorAll, no observer.
    // v7.0.29 restores the proven Home media families from the streamlined 6.x
    // owner without reviving its runtime scanner/classifier.
    CGFloat strength=MAX(0,MIN(100,gP.whiteTameStrength));
    CGFloat factor=MAX(0.50,1.0-0.50*strength/100.0);
    CGFloat shade=0.50*strength/100.0;
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
         "html[data-ad7-twb-child=\"1\"] :is(img,video,canvas)"
         ":not([class*=logo]):not([class*=avatar]):not([class*=profile]):not([class*=merchant]):not([class*=seller])"
         ":not([class*=rating]):not([class*=star]):not([class*=checkbox]):not([class*=heart]):not([class*=wishlist])"
         ":not([class*=search-icon]):not([class*=microphone]):not([class*=camera]):not([class*=location])"
         ":not([class*=chevron]):not([class*=nav-icon]):not([class*=tab-icon]):not([class*=header-icon]):not([class*=ad-feedback]):not([class*=sponsored]):not([class*=spr]):not([class*=sprite]):not([class*=pixel])"
         ":not([class*=icon]):not([class*=glyph]):not([class*=badge])"
         ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *))"
         ":not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)),"
         /* Main-document standalone ad media if Amazon renders it outside the iframe. */
         "#gwm-Deck-btf :is([class*=mobile-mshop-ad],[class*=mobile-ad-container],[class*=ape-wrapper],[class*=ape-placement]) "
         ":is(img,video,canvas)"
         ":not([class*=logo]):not([class*=icon]):not([class*=glyph]):not([class*=badge])"
         ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *))"
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
         "';}catch(e){}})();",factor,shade];
}


static void ADTrackWebView(WKWebView *wv){
    if(!wv)return; @try { @synchronized([WKWebView class]) { if(!gADWebViews)gADWebViews=[NSHashTable weakObjectsHashTable]; [gADWebViews addObject:wv]; } } @catch(...) {}
}
static NSArray *ADTrackedWebViews(void){
    @try { @synchronized([WKWebView class]) { return gADWebViews?gADWebViews.allObjects:@[]; } } @catch(...) {}
    return @[];
}
static void ADAttachScriptsToUCC710(WKUserContentController *ucc){
    if(!ucc || !gP.enabled)return;
    @try {
        if(!objc_getAssociatedObject(ucc,kADFloorUS)){
            WKUserScript *us=[[WKUserScript alloc] initWithSource:ADFloorJS() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
            [ucc addUserScript:us];
            objc_setAssociatedObject(ucc,kADFloorUS,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if(gP.whiteTame && !objc_getAssociatedObject(ucc,kADTWBUS)){
            WKUserScript *us=[[WKUserScript alloc] initWithSource:ADTWBJS() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
            [ucc addUserScript:us];
            objc_setAssociatedObject(ucc,kADTWBUS,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
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
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            for(WKWebView *wv in ADTrackedWebViews()) if(wv.window) ADApplyWebFloor(wv);
        } @catch(...) {}
    });
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
        ADAttachScriptsToUCC710(self);
    }
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
    if(gP.enabled && self.window){ ADAttachWebScripts(self); ADApplyWebFloor(self); ADScheduleLaunchReadyCheck706(); }
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
        if([c containsString:@"sbsearchbar"]||[c containsString:@"sbsearchfield"]||[c containsString:@"searchbar"]||[c containsString:@"searchfield"]) return YES;
    }} @catch(...) {}
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
    BOOL search=ADInSearchChrome706(iv), location=ADIsLocationGlyph709(iv);
    if(!search&&!location)return;
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

%hook UITextField
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
        if(ADPrimaryAmazonController713(self) && self.isViewLoaded){
            self.view.backgroundColor=ADOLED();
            self.view.layer.backgroundColor=ADOLED().CGColor;
        }
    }
}
%end


// -----------------------------------------------------------------------------
// v7.81 probe: screenshot-triggered full Sponsored renderer inventory.
// One-shot only when the user takes a screenshot.  No observer, timer, interval,
// RAF, scroll listener, or recurring DOM scan.
// -----------------------------------------------------------------------------
static NSString *ADSponsorInventoryProbePath781(void){
    @try {
        NSArray *dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
        NSString *base=dirs.firstObject;
        if(base.length)return [base stringByAppendingPathComponent:@"AmazonDark-sponsored-inventory-probe-v7.81.txt"];
    } @catch(...) {}
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"AmazonDark-sponsored-inventory-probe-v7.81.txt"];
}
static WKWebView *ADLargestVisibleWeb781(void){
    WKWebView *best=nil; CGFloat area=0;
    @try {
        for(WKWebView *wv in ADTrackedWebViews()){
            if(!wv.window||wv.hidden||wv.alpha<0.01)continue;
            CGRect r=[wv convertRect:wv.bounds toView:wv.window];
            CGRect ir=CGRectIntersection(r,wv.window.bounds);
            CGFloat a=MAX(0,ir.size.width)*MAX(0,ir.size.height);
            if(a>area){area=a;best=wv;}
        }
    } @catch(...) {}
    return best;
}
static void ADCaptureSponsorInventory781(void){
    if(!gP.enabled)return;
    WKWebView *wv=ADLargestVisibleWeb781();
    if(!wv)return;
    NSString *js=@"(function(){try{"
      "function C(e){try{var x=e.className;if(x&&x.baseVal!==undefined)x=x.baseVal;return typeof x==='string'?x:''}catch(_){return ''}}"
      "function T(e){try{return String(e.textContent||'').replace(/\\s+/g,' ').trim().slice(0,180)}catch(_){return ''}}"
      "function X(e){try{return String(e.outerHTML||'').replace(/\\s+/g,' ').slice(0,1400)}catch(_){return ''}}"
      "function V(e){try{var r=e.getBoundingClientRect(),c=getComputedStyle(e);return r.width>0&&r.height>0&&r.bottom>=0&&r.top<=innerHeight&&r.right>=0&&r.left<=innerWidth&&c.display!=='none'&&c.visibility!=='hidden'&&parseFloat(c.opacity||1)>0}catch(_){return false}}"
      "function O(e){try{var r=e.getBoundingClientRect(),c=getComputedStyle(e),b=getComputedStyle(e,'::before'),a=getComputedStyle(e,'::after');return [String(e.tagName||'?').toLowerCase(),e.id?'#'+e.id:'',C(e)?'.'+C(e).trim().replace(/\\s+/g,'.'):'',' rect='+[r.x,r.y,r.width,r.height].map(function(v){return Math.round(v*10)/10}).join(','),' visible='+V(e),' text='+JSON.stringify(T(e)),' aria='+JSON.stringify(e.getAttribute('aria-label')||''),' role='+(e.getAttribute('role')||''),' color='+c.color,' bg='+c.backgroundColor,' bgimg='+String(c.backgroundImage||'').slice(0,500),' bgpos='+c.backgroundPosition,' bgsize='+c.backgroundSize,' bgrep='+c.backgroundRepeat,' mask='+String(c.webkitMaskImage||c.maskImage||'').slice(0,500),' maskpos='+(c.webkitMaskPosition||c.maskPosition||''),' masksize='+(c.webkitMaskSize||c.maskSize||''),' filter='+c.filter,' opacity='+c.opacity,' display='+c.display,' visibility='+c.visibility,' fill='+c.fill,' stroke='+c.stroke,' outline='+c.outline,' boxshadow='+c.boxShadow,' before='+[b.content,b.color,b.backgroundColor,b.backgroundImage,b.webkitMaskImage||b.maskImage,b.filter,b.opacity,b.display,b.visibility].join('|').slice(0,700),' after='+[a.content,a.color,a.backgroundColor,a.backgroundImage,a.webkitMaskImage||a.maskImage,a.filter,a.opacity,a.display,a.visibility].join('|').slice(0,700)].join('')}catch(z){return 'ERR '+z}}"
      "function semantic(e){var z=(C(e)+' '+String(e.id||'')+' '+String(e.getAttribute('aria-label')||'')+' '+T(e)).toLowerCase();return z.indexOf('sponsor')>=0||z.indexOf('ad-feedback')>=0||z.indexOf('feedbackicon')>=0||z.indexOf('feedback-icon')>=0||z.indexOf('ape-feedback')>=0}"
      "function tiny(e){try{var r=e.getBoundingClientRect();return r.width>=4&&r.height>=4&&r.width<=48&&r.height<=48}catch(_){return false}}"
      "var W=innerWidth||0,H=innerHeight||0,o=['AmazonDark v7.81 Sponsored inventory','href='+location.href,'title='+document.title,'ready='+document.readyState,'viewport='+W+'x'+H];"
      "var all=document.querySelectorAll('*'),rels=[],labs=[],glyphs=[];"
      "for(var i=0;i<all.length;i++){var e=all[i],tx=T(e).toLowerCase(),ar=String(e.getAttribute('aria-label')||'').toLowerCase();if(semantic(e)){rels.push(e);if((tx==='sponsored'||tx.indexOf('sponsored')===0||ar.indexOf('sponsored')>=0)&&!tiny(e))labs.push(e);if(tiny(e))glyphs.push(e)}}"
      "o.push('COUNTS related='+rels.length+' labels='+labs.length+' tinyGlyphCandidates='+glyphs.length);"
      "for(var i=0,k=0;i<labs.length&&k<40;i++){var l=labs[i];if(!V(l))continue;var lr=l.getBoundingClientRect();o.push('\\nPAIR '+k+' LABEL '+O(l));o.push('PAIR '+k+' LABEL_HTML '+X(l));var p=l;for(var d=0;p&&d<5;d++,p=p.parentElement){o.push('PAIR '+k+' ANCESTOR'+d+' '+O(p));var q=p.querySelectorAll('*');for(var j=0,n=0;j<q.length&&n<80;j++){var g=q[j];if(g===l||!tiny(g)||!V(g))continue;var gr=g.getBoundingClientRect(),cy=Math.abs((gr.top+gr.height/2)-(lr.top+lr.height/2)),dx=Math.max(0,Math.max(gr.left-lr.right,lr.left-gr.right));var gc=getComputedStyle(g),hasPaint=(String(gc.backgroundImage||'none')!=='none'||String(gc.webkitMaskImage||gc.maskImage||'none')!=='none'||String(g.tagName||'').toLowerCase()==='svg'||String(g.tagName||'').toLowerCase()==='img'||semantic(g));if(hasPaint&&cy<=40&&dx<=70){o.push('PAIR '+k+' GLYPH_CAND '+O(g));o.push('PAIR '+k+' GLYPH_HTML '+X(g));n++;}}}k++;}"
      "o.push('\\n-- ALL VISIBLE SPONSOR-RELATED NODES --');for(var i=0,n=0;i<rels.length&&n<160;i++){if(!V(rels[i]))continue;o.push('REL '+n+' '+O(rels[i]));o.push('REL_HTML '+X(rels[i]));n++;}"
      "o.push('\\n-- ALL VISIBLE TINY PAINTERS WITHIN SPONSOR CARDS --');for(var i=0,n=0;i<glyphs.length&&n<160;i++){if(!V(glyphs[i]))continue;var p=glyphs[i],hit=false;for(var d=0;p&&d<6;d++,p=p.parentElement){if(semantic(p)||T(p).toLowerCase().indexOf('sponsored')>=0){hit=true;break}}if(hit){o.push('GLYPH '+n+' '+O(glyphs[i]));o.push('GLYPH_HTML '+X(glyphs[i]));n++;}}"
      "return o.join('\\n')}catch(e){return 'JSERR '+e}})();";
    [wv evaluateJavaScript:js completionHandler:^(id value,NSError *error){
        @try {
            NSString *out=error?[NSString stringWithFormat:@"WEB_ERROR %@",error]:([value isKindOfClass:[NSString class]]?value:[value description]);
            NSMutableString *m=[NSMutableString stringWithFormat:@"AmazonDark %@ full Sponsored glyph inventory probe\ndate=%@\n\n%@\n",[NSString stringWithUTF8String:AD_VERSION],[NSDate date],out?:@"NO_RESULT"];
            [m writeToFile:ADSponsorInventoryProbePath781() atomically:YES encoding:NSUTF8StringEncoding error:nil];
        } @catch(...) {}
    }];
}

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
        ov.frame=iv.bounds; ov.backgroundColor=[UIColor colorWithWhite:0 alpha:0.50*MAX(0,MIN(100,gP.whiteTameStrength))/100.0].CGColor; ov.zPosition=FLT_MAX;
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
        if(ADInSearchChrome706(self)||ADIsLocationGlyph709(self)){
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
    if(gP.enabled&&self.window&&(ADInSearchChrome706(self)||ADIsLocationGlyph709(self)))ADTintSearchGlyph706(self);
    if(objc_getAssociatedObject(self,kADTWBOverlay)||gP.whiteTame)ADApplyNativeTWB(self);
}
%end

// -----------------------------------------------------------------------------
// Launch transition handoff. The SpringBoard side retains v6.0.185's 1.40 s
// minimum presentation and 0.55 s fade; Amazon only tells it that the black root
// is mounted. Cached light launch snapshots are cleared exactly as in v6.0.185.
// -----------------------------------------------------------------------------
static BOOL gADReadyPosted706=NO;
static BOOL gADReadyScheduled706=NO;
static NSInteger gADReadyAttempts706=0;
static NSInteger gADReadyStable706=0;
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
static void ADRunLaunchReadyCheck706(void){
    if(gADReadyPosted706||!gP.enabled){gADReadyScheduled706=NO;return;}
    gADReadyAttempts706++;
    if(ADVisibleSplashController706()){ gADReadyStable706=0; }
    else {
        __block BOOL anyReady=NO;
        NSArray *webs=ADTrackedWebViews();
        for(WKWebView *wv in webs){
            if(!wv.window)continue;
            NSString *js=@"(function(){try{var d=document;if(!(d.readyState==='interactive'||d.readyState==='complete'))return 0;var x=d.querySelector('#gwm-PageContent,#a-page main,main,[role=main]');if(!x)return 0;var r=x.getBoundingClientRect(),c=getComputedStyle(x),bg=c&&c.backgroundColor||'',txt=(x.innerText||x.textContent||'').trim();var media=!!x.querySelector('img,video,canvas');return ((bg==='rgb(0, 0, 0)'||bg==='rgba(0, 0, 0, 1)')&&r.height>260&&(txt.length>80||media))?1:0;}catch(e){return 0;}})();";
            [wv evaluateJavaScript:js completionHandler:^(id value,NSError *error){
                if(!error&&[value respondsToSelector:@selector(boolValue)]&&[value boolValue]){
                    anyReady=YES; gADReadyStable706++;
                    if(gADReadyStable706>=3 && !ADVisibleSplashController706()){
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.25*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ if(!ADVisibleSplashController706())ADPostReadyOnce(); });
                    }
                }
            }];
        }
        (void)anyReady;
    }
    if(!gADReadyPosted706 && gADReadyAttempts706<64){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.125*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ ADRunLaunchReadyCheck706(); });
    } else gADReadyScheduled706=NO;
}
static void ADScheduleLaunchReadyCheck706(void){
    if(gADReadyPosted706||gADReadyScheduled706||!gP.enabled)return;
    gADReadyScheduled706=YES; dispatch_async(dispatch_get_main_queue(),^{ ADRunLaunchReadyCheck706(); });
}


// v7.0.68 production: v7.0.65 chevron diagnostic runtime removed.
static void ADPrefsChanged(CFNotificationCenterRef c,void *o,CFStringRef n,const void *obj,CFDictionaryRef ui){
    ADLoadPrefs(); ADRefreshPromotionState611(); ADApplyAllFloors();
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

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationUserDidTakeScreenshotNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note){ (void)note; ADCaptureSponsorInventory781(); }];


    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,ADPrefsChanged,
        CFSTR("com.colindavidr.amazondark/prefs-changed"),NULL,CFNotificationSuspensionBehaviorCoalesce);
    dispatch_async(dispatch_get_main_queue(), ^{
        ADApplyAllFloors();
        ADRefreshPromotionState611();
        ADApplyJIT622();
        ADScheduleLaunchReadyCheck706();
    });
}

#pragma clang diagnostic pop
