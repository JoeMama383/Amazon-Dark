/*
 * AmazonDark v7.0.5 — static OLED theme / cheap CSS architecture
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
 *   - contrast scanners, repair queues, probes and theme MutationObservers
 *
 * Always-on visual ownership is deliberately static and assignment-driven:
 *   - OLED-black structural/control surfaces
 *   - light text for contrast on the black surfaces
 *   - neutral #494D4D borders/dividers
 *   - cheap documentStart CSS/compositing fixes from the proven pre-Dark-Reader rules
 * Images, video, canvas and glyph/icon artwork remain outside the broad paint path.
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

#define AD_VERSION "v7.0.5-static-oled"
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
static void ADScheduleLaunchReadyCheck(void);
static const void *kADFloorUS=&kADFloorUS;
static const void *kADTWBUS=&kADTWBUS;
static NSHashTable *gADWebViews=nil;

static NSString *ADFloorJS(void){
    // v7.0.5: direct static OLED theme. This is intentionally declarative and installed
    // at documentStart: no Dark Reader, no TreeWalker, no MutationObserver and no
    // computed-style census. Media/artwork is kept transparent so product/creative pixels
    // remain Amazon-owned; structural surfaces, text contrast and neutral borders are ours.
    return @"(function(){try{var id='ad7-static-theme',s=document.getElementById(id);"
            "if(!s){s=document.createElement('style');s.id=id;(document.head||document.documentElement||document).appendChild(s);}"
            "s.textContent='"
            ":root{color-scheme:dark!important;}"
            "html,body,#a-page,#gwm-PageContent,main,#dp,#ppd,#dp-container,#search,#search-main-wrapper,[role=main],"
            "section,article,aside,header,footer,nav,div,ul,ol,li,table,thead,tbody,tfoot,tr,td,th,form,fieldset,details,summary,dialog,"
            "[class*=a-section],[class*=a-container],[class*=a-row],[class*=a-box],[class*=a-box-inner],[class*=a-cardui],"
            "[class*=card-container],[class*=cardContainer],[class*=recommendation-container],[class*=recommendations-container],"
            "[class*=widget-container],[class*=widgetContainer],[class*=panel],[class*=sheet],[class*=modal],[class*=popover],[class*=drawer],"
            "[class*=npack-asin-card],[class*=gwm-asin-tile],[class*=gwm-tile],[class*=puis-card],[class*=cXVhZ],"
            "[class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer],"
            "[class*=asin-container-white],[class*=gwmWindowPaneTile],[class*=gwm-window-layout],[class*=window-container],[class*=gwm-dashboard-container],"
            "[data-component-type=s-search-result],[class*=s-result-item],[class*=s-card-container],"
            "#sc-active-cart,#sc-saved-cart,#sc-buy-box,.sc-list-body,.sc-list-item,.sc-list-item-content,.sc-item-content-group,.sc-item-product-content,"
            "[class*=sc-list-item],[class*=sc-card],[class*=sc-buy-box],"
            ".a-sheet-web-container,.a-sheet-web[role=dialog],.a-sheet-content-container,.a-sheet-heading-container,"
            "[class*=ssf-customize-container],[class*=ssf-two-row-custom-channels-container],"
            ".s-suggestion-container,.s-suggestion-container .s-suggestion,[class*=suggestion-container],[class*=autocomplete],[class*=recentSearch],"
            "[class*=page-container],[class*=pageContent],[class*=page-content],[class*=content-container],[class*=contentContainer],"
            "[class*=screen-container],[class*=screenContainer],[class*=root-container],[class*=rootContainer],"
            "[class*=background-container],[class*=backgroundContainer],[class*=surface-container],[class*=surfaceContainer]"
            "{background-color:#000!important;}"
            "html::before,html::after,body::before,body::after,#a-page::before,#a-page::after,#gwm-PageContent::before,#gwm-PageContent::after,main::before,main::after,[role=main]::before,[role=main]::after{background-color:#000!important;}"
            "input:not([type=image]),textarea,select,option,button,[role=button],[role=dialog],[role=list],[role=listitem],[role=menu],[role=menuitem]{background-color:#000!important;}"
            "picture,img,video,canvas,svg,#imgTagWrapperId,.s-product-image-container,[data-component-type=s-product-image],"
            "[class*=image-wrapper],[class*=img-wrapper],[class*=image-container],[class*=product-image],[class*=asin-image],[class*=thumbnail-conta],"
            "[class*=single-creative],[class*=single-video],[class*=theming-card-background],[class*=vjs-poster],[class*=media-wrapper]"
            "{background-color:transparent!important;mix-blend-mode:normal!important;isolation:auto!important;}"
            "[class*=single-creative-card] :is(.a-box,.a-box-inner,.a-section,.a-row),[class*=single-video-card] :is(.a-box,.a-box-inner,.a-section,.a-row),"
            "[class*=theming-card] :is(.a-box,.a-box-inner,.a-section,.a-row),[class*=canvas-card] :is(.a-box,.a-box-inner,.a-section,.a-row)"
            "{background-color:transparent!important;box-shadow:none!important;}"
            "body,#a-page,main,p,span,a,label,h1,h2,h3,h4,h5,h6,strong,b,em,i,small,sup,sub,blockquote,legend,dt,dd,caption,time,"
            ".a-color-base,.a-text-normal,.a-size-base,.a-size-base-plus,.a-size-medium,.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen,"
            "[class*=title],[class*=price],[class*=text],[class*=heading],[class*=label],[class*=description],[class*=truncate]"
            "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            ".a-color-secondary,.a-size-small,[class*=secondary],[class*=sponsored-label],[class*=ad-feedback-text]"
            "{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;}"
            "input,textarea,select,option,button,[role=button]{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
            "::placeholder{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}"
            "*{border-color:#494d4d!important;outline-color:#494d4d!important;}"
            "hr,.a-divider-inner:after,.a-divider-inner:before,[class*=divider],[class*=separator]{border-color:#494d4d!important;}"
            "hr,[class*=divider][class*=line],[class*=separator][class*=line]{background-color:#494d4d!important;color:#494d4d!important;}"
            "[class*=npack],[class*=npack] *,[class*=gwm-asin],[class*=gwm-asin] *,[class*=gwm-tile],[class*=gwm-tile] *,[class*=cXVhZ],[class*=cXVhZ] *"
            "{mix-blend-mode:normal!important;isolation:auto!important;}"
            "#wd-backdrop-gradient,.wd-backdrop-gradient,[class*=wd-backdrop-gradient]{background:#000!important;background-image:none!important;box-shadow:none!important;}"
            "[class*=wd-backdrop]:not([style*=background-image]){background-color:#000!important;}"
            "[class*=a-reactive-container],[class*=reactive-contain]{background-color:#000!important;background-image:none!important;box-shadow:none!important;}"
            "#auth-footer,.auth-footer,[id*=auth-footer],#auth-footer .a-divider,#auth-footer .a-divider-inner,.auth-footer .a-divider,.auth-footer .a-divider-inner"
            "{background-color:#000!important;background-image:none!important;box-shadow:none!important;}"
            "[class*=_c2Itb_brandCard_],[class*=_bW9ia_suggestion_]{background-image:none!important;background-color:#000!important;}"
            "[data-csa-c-content-id=variation-options-link],[class*=s-variations-options-justify-content],[class*=s-variation-options-text],"
            "[class*=s-variation-options-link],[class*=s-color-swatch-container-list-view],[class*=puis-csi-with-label-container],"
            "[data-component-type=s-status-badge-component]>.a-row.a-badge-region{background:#000!important;background-image:none!important;box-shadow:none!important;}"
            "[class*=badgeMessage],[class*=badgeMessage] *{background:#000!important;background-image:none!important;box-shadow:none!important;}"
            "';"
            "document.documentElement.style.backgroundColor='#000';if(document.body)document.body.style.backgroundColor='#000';"
            "}catch(e){}})();";
}

static NSString *ADTWBJS(void){
    CGFloat strength=MAX(0,MIN(100,gP.whiteTameStrength));
    CGFloat factor=MAX(0.05,1.0-strength/100.0);
    return [NSString stringWithFormat:
        @"(function(){try{if(window.__AD7TWB)return;window.__AD7TWB=1;var f='brightness(%.3f)';"
         "var bad=/icon|glyph|logo|avatar|profile|badge|star|rating|checkbox|heart|arrow|chevron|button|search|menu|microphone|camera|cart|location|nav|tab|sprite|brand|seller|store/i;"
         "function blocked(e){try{var n=e;for(var i=0;i<4&&n;i++,n=n.parentElement){var s=((n.className&&n.className.baseVal)||n.className||'')+' '+(n.id||'')+' '+(n.getAttribute&&((n.getAttribute('aria-label')||'')+' '+(n.getAttribute('alt')||'')+' '+(n.getAttribute('role')||''))||'');if(bad.test(String(s)))return true;if(n.tagName==='BUTTON'||n.getAttribute&&n.getAttribute('role')==='button')return true;}}catch(x){}return false;}"
         "function tame(e){try{if(!e||!/^(IMG|VIDEO|CANVAS)$/.test(e.tagName)||blocked(e))return;var r=e.getBoundingClientRect();var w=r.width||e.width||0,h=r.height||e.height||0;if(w<52||h<52)return;e.style.setProperty('filter',f,'important');e.setAttribute('data-ad7twb','1');}catch(x){}}"
         "document.addEventListener('load',function(ev){tame(ev.target);},true);document.addEventListener('loadedmetadata',function(ev){tame(ev.target);},true);"
         "function once(){try{document.querySelectorAll('img,video,canvas').forEach(tame);}catch(x){}}"
         "if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',once,{once:true});else once();window.addEventListener('pageshow',once,{passive:true});"
         "}catch(e){}})();",factor];
}

static void ADTrackWebView(WKWebView *wv){
    if(!wv)return; @try { @synchronized([WKWebView class]) { if(!gADWebViews)gADWebViews=[NSHashTable weakObjectsHashTable]; [gADWebViews addObject:wv]; } } @catch(...) {}
}
static NSArray *ADTrackedWebViews(void){
    @try { @synchronized([WKWebView class]) { return gADWebViews?gADWebViews.allObjects:@[]; } } @catch(...) {}
    return @[];
}
static void ADAttachWebScripts(WKWebView *wv){
    if(!wv || !gP.enabled)return; ADTrackWebView(wv);
    @try {
        WKUserContentController *ucc=wv.configuration.userContentController;
        if(ucc && !objc_getAssociatedObject(ucc,kADFloorUS)){
            WKUserScript *us=[[WKUserScript alloc] initWithSource:ADFloorJS() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
            [ucc addUserScript:us]; objc_setAssociatedObject(ucc,kADFloorUS,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if(gP.whiteTame && ucc && !objc_getAssociatedObject(ucc,kADTWBUS)){
            WKUserScript *us=[[WKUserScript alloc] initWithSource:ADTWBJS() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
            [ucc addUserScript:us]; objc_setAssociatedObject(ucc,kADTWBUS,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } @catch(...) {}
}
static void ADApplyWebFloor(WKWebView *wv){
    if(!wv || !gP.enabled)return; ADTrackWebView(wv);
    @try {
        wv.opaque=YES; wv.backgroundColor=ADOLED(); wv.scrollView.backgroundColor=ADOLED();
        if(@available(iOS 15.0,*)) wv.underPageBackgroundColor=ADOLED();
        [wv evaluateJavaScript:ADFloorJS() completionHandler:nil];
        if(gP.whiteTame)[wv evaluateJavaScript:ADTWBJS() completionHandler:nil];
    } @catch(...) {}
}
static void ADApplyAllFloors(void){
    if(!gP.enabled)return;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            for(UIWindow *w in UIApplication.sharedApplication.windows){ if(w){ w.backgroundColor=ADOLED(); UIViewController *vc=w.rootViewController; if(vc && vc.isViewLoaded)vc.view.backgroundColor=ADOLED(); } }
            for(WKWebView *wv in ADTrackedWebViews()) if(wv.window)ADApplyWebFloor(wv);
        } @catch(...) {}
    });
}

%hook WKWebView
- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    id wv = %orig;
    if (gP.enabled) { ADAttachWebScripts(wv); ADApplyWebFloor(wv); }
    return wv;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    id wv = %orig;
    if (gP.enabled) { ADAttachWebScripts(wv); ADApplyWebFloor(wv); }
    return wv;
}
- (void)didMoveToWindow {
    %orig;
    if (gP.enabled && self.window) { ADAttachWebScripts(self); ADApplyWebFloor(self); ADScheduleLaunchReadyCheck(); }
}
- (void)setBackgroundColor:(UIColor *)color {
    if (gP.enabled) {
        UIColor *black = ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
%end

%hook WKScrollView
- (void)didMoveToWindow {
    %orig;
    if (gP.enabled && self.window) self.backgroundColor=ADOLED();
}
- (void)setBackgroundColor:(UIColor *)color {
    if (gP.enabled) {
        UIColor *black = ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
%end

%hook WKContentView
- (void)didMoveToWindow {
    %orig;
    if (gP.enabled && self.window) { self.backgroundColor=ADOLED(); self.layer.backgroundColor=ADOLED().CGColor; }
}
- (void)layoutSubviews {
    %orig;
    if (gP.enabled) { self.backgroundColor=ADOLED(); self.layer.backgroundColor=ADOLED().CGColor; }
}
- (void)setBackgroundColor:(UIColor *)color {
    if (gP.enabled) {
        UIColor *black = ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
%end

static BOOL ADNativeArtworkView(UIView *v){
    if(!v)return YES;
    @try {
        if([v isKindOfClass:[UIImageView class]] || [v isKindOfClass:[UILabel class]]) return YES;
        NSString *n=NSStringFromClass(v.class).lowercaseString ?: @"";
        for(NSString *x in @[@"image",@"icon",@"glyph",@"avatar",@"logo",@"star",@"rating",@"badge",@"symbol",@"artwork"])
            if([n containsString:x]) return YES;
    } @catch(...) { return YES; }
    return NO;
}
static BOOL ADNativeSurfaceCandidate(UIView *v){
    if(!v || ADNativeArtworkView(v))return NO;
    @try {
        if([v isKindOfClass:[UIVisualEffectView class]]) return YES;
        // Text renderers keep transparent/stock backing; their foreground is owned separately.
        if([v isKindOfClass:[UITextView class]] || [v isKindOfClass:[UITextField class]]) return YES;
        return YES;
    } @catch(...) {}
    return NO;
}
static void ADOwnNativeSurface(UIView *v){
    if(!gP.enabled || !v || !ADNativeSurfaceCandidate(v))return;
    @try { v.backgroundColor=ADOLED(); v.layer.backgroundColor=ADOLED().CGColor; } @catch(...) {}
}
static UIColor *ADLightText(void){ return [UIColor colorWithRed:232.0/255.0 green:230.0/255.0 blue:227.0/255.0 alpha:1.0]; }
static UIColor *ADBorderGray(void){ return [UIColor colorWithRed:73.0/255.0 green:77.0/255.0 blue:77.0/255.0 alpha:1.0]; }
static BOOL ADNeutralCGColor(CGColorRef c){
    if(!c)return NO;
    @try {
        UIColor *u=[UIColor colorWithCGColor:c]; CGFloat r=0,g=0,b=0,a=0,w=0;
        if([u getRed:&r green:&g blue:&b alpha:&a]) return a>0.05 && (MAX(r,MAX(g,b))-MIN(r,MIN(g,b)))<0.16;
        if([u getWhite:&w alpha:&a]) return a>0.05;
    } @catch(...) {}
    return NO;
}
%hook UIView
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled && self.window && ADNativeSurfaceCandidate(self)) ADOwnNativeSurface(self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(gP.enabled && self.window && ADNativeSurfaceCandidate(self)){
        UIColor *black = ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
%end

%hook UILabel
- (void)setTextColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *light=ADLightText();
        %orig(light);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled && self.window) self.textColor=ADLightText();
}
%end

%hook UITextView
- (void)setTextColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *light=ADLightText();
        %orig(light);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled && self.window){ self.backgroundColor=ADOLED(); self.textColor=ADLightText(); }
}
%end

%hook UITextField
- (void)setTextColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *light=ADLightText();
        %orig(light);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled && self.window){ self.backgroundColor=ADOLED(); self.textColor=ADLightText(); }
}
%end

%hook UIButton
- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state {
    if(gP.enabled){
        UIColor *light=ADLightText();
        %orig(light,state);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled && self.window){ self.backgroundColor=ADOLED(); [self setTitleColor:ADLightText() forState:UIControlStateNormal]; }
}
%end

%hook CALayer
- (void)setBorderColor:(CGColorRef)color {
    if(gP.enabled && color && ADNeutralCGColor(color)){
        UIColor *grayColor=ADBorderGray();
        CGColorRef gray=grayColor.CGColor;
        %orig(gray);
        return;
    }
    %orig;
}
%end

%hook CAShapeLayer
- (void)setStrokeColor:(CGColorRef)color {
    if(gP.enabled && color && ADNeutralCGColor(color)){
        CGRect b=self.bounds;
        if(b.size.width>24.0 || b.size.height>24.0){
            UIColor *grayColor=ADBorderGray();
            CGColorRef gray=grayColor.CGColor;
            %orig(gray);
            return;
        }
    }
    %orig;
}
%end

%hook UIViewController
- (void)viewDidLoad {
    %orig;
    ADOwnNativeSurface(self.view);
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    ADOwnNativeSurface(self.view);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    ADOwnNativeSurface(self.view);
    if (gP.enabled) ADScheduleLaunchReadyCheck();
}
%end

%hook UIWindow
- (void)setRootViewController:(UIViewController *)vc {
    %orig;
    if (gP.enabled) { self.backgroundColor=ADOLED(); if (vc && vc.isViewLoaded) vc.view.backgroundColor=ADOLED(); }
}
- (void)makeKeyAndVisible {
    if (gP.enabled) self.backgroundColor=ADOLED();
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
        for(NSString *tok in @[@"icon",@"glyph",@"logo",@"avatar",@"profile",@"badge",@"star",@"rating",@"checkbox",@"heart",@"arrow",@"chevron",@"button",@"search",@"menu",@"microphone",@"camera",@"cart",@"location",@"nav",@"tab",@"sprite",@"brand",@"seller",@"store"])
            if([q containsString:tok])return YES;
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
        ov.frame=iv.bounds; ov.backgroundColor=[UIColor colorWithWhite:0 alpha:MAX(0,MIN(100,gP.whiteTameStrength))/100.0].CGColor; ov.zPosition=FLT_MAX;
    } @catch(...) {}
}

%hook UIImageView
- (void)setImage:(UIImage *)image {
    %orig;
    if (gP.whiteTame) ADApplyNativeTWB(self);
}
- (void)didMoveToWindow {
    %orig;
    ADApplyNativeTWB(self);
}
- (void)layoutSubviews {
    %orig;
    if (objc_getAssociatedObject(self,kADTWBOverlay) || gP.whiteTame) ADApplyNativeTWB(self);
}
%end

// -----------------------------------------------------------------------------
// Launch transition handoff. The SpringBoard side retains v6.0.185's 1.40 s
// minimum presentation and 0.55 s fade; Amazon only tells it that the black root
// is mounted. Cached light launch snapshots are cleared exactly as in v6.0.185.
// -----------------------------------------------------------------------------
static BOOL gADLaunchReadyPosted=NO;
static BOOL gADLaunchReadyCheckScheduled=NO;
static NSInteger gADLaunchReadyAttempts=0;
static void ADPostReadyOnce(void){
    if(gADLaunchReadyPosted)return;
    gADLaunchReadyPosted=YES;
    @try { notify_post("com.colindavidr.amazondark.ready"); } @catch(...) {}
}
static void ADRunLaunchReadyCheck(void){
    if(gADLaunchReadyPosted || !gP.enabled){ gADLaunchReadyCheckScheduled=NO; return; }
    gADLaunchReadyAttempts++;
    __block BOOL submitted=NO;
    for(WKWebView *wv in ADTrackedWebViews()){
        if(!wv.window)continue;
        submitted=YES;
        NSString *js=@"(function(){try{var d=document,r=d.readyState,b=d.body,x=d.querySelector('#a-page,#gwm-PageContent,main,[role=main]');if(!b||!(r==='interactive'||r==='complete'))return 0;var e=x||b,c=getComputedStyle(e),bg=c&&c.backgroundColor||'';return (bg==='rgb(0, 0, 0)'||bg==='rgba(0, 0, 0, 1)')?1:0;}catch(e){return 0;}})();";
        [wv evaluateJavaScript:js completionHandler:^(id value,NSError *error){
            if(!error && [value respondsToSelector:@selector(boolValue)] && [value boolValue]) ADPostReadyOnce();
        }];
    }
    if(gADLaunchReadyPosted){ gADLaunchReadyCheckScheduled=NO; return; }
    // Keep this launch-only and bounded. SpringBoard still owns the 8.5 s / 10 s safety caps.
    if(gADLaunchReadyAttempts<24){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.125*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ ADRunLaunchReadyCheck(); });
    } else {
        gADLaunchReadyCheckScheduled=NO;
        (void)submitted;
    }
}
static void ADScheduleLaunchReadyCheck(void){
    if(gADLaunchReadyPosted || gADLaunchReadyCheckScheduled || !gP.enabled)return;
    gADLaunchReadyCheckScheduled=YES;
    dispatch_async(dispatch_get_main_queue(),^{ ADRunLaunchReadyCheck(); });
}

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

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,ADPrefsChanged,
        CFSTR("com.colindavidr.amazondark/prefs-changed"),NULL,CFNotificationSuspensionBehaviorCoalesce);

    dispatch_async(dispatch_get_main_queue(), ^{
        ADApplyAllFloors();
        ADRefreshPromotionState611();
        ADApplyJIT622();
        ADScheduleLaunchReadyCheck();
    });
}

#pragma clang diagnostic pop
