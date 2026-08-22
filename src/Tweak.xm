/*
 * AmazonDark v7.0.3 — clean whole-app inversion baseline
 *
 * Retained from v7.0.0 / the v6.0.185 feature base:
 *   - Settings bundle/preferences and preference domain
 *   - Force 120 Hz preference path
 *   - Dopamine per-app JIT request path
 *   - Tame Light Backgrounds preference
 *   - SpringBoard launch cover / transition / custom artwork (AmazonDarkSB)
 *   - Sileo/package metadata and artwork
 *
 * Visual architecture:
 *   - One UIWindow-level Core Animation colorInvert filter owns the entire app.
 *   - Product-photo media receives exactly one local counter-invert so its pixels
 *     remain photographic/stock while every other UI pixel stays inverted.
 *   - No Dark Reader, color engine, broad recolor pass, DOM MutationObserver,
 *     scroll recovery, recurring timer, nav/search special-case painter, or probe.
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

#define AD_VERSION "v7.0.3"
#define AD_PREF_DOMAIN "com.colindavidr.amazondark"

extern char *__progname;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wobjc-method-access"

@interface CAFilter : NSObject
+ (id)filterWithType:(NSString *)type;
@end
@interface ANXFastImageView : UIImageView @end
@interface RCTUIImageViewAnimated : UIImageView @end

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
// Whole-app inversion + product-photo exception.
//
// The root UIWindow filter is the single generic theme owner.  We do not repaint
// native backgrounds, nav bars, text, glyphs, borders, cards, or WebKit floors.
// Product-photo media is the only exception and receives one local colorInvert,
// cancelling the root inversion for that layer/element only.
// -----------------------------------------------------------------------------
static void ADPostReadyOnce(void);
static const void *kADRootInvert701=&kADRootInvert701;
static const void *kADMediaInvert701=&kADMediaInvert701;
static const void *kADTWBOverlay701=&kADTWBOverlay701;
static const void *kADWebScript701=&kADWebScript701;
static NSHashTable *gADWebViews701=nil;

static id ADInvertFilter701(void){
    static id f=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ @try { f=[NSClassFromString(@"CAFilter") filterWithType:@"colorInvert"]; } @catch(...) { f=nil; } });
    return f;
}
static BOOL ADHasInvert701(NSArray *filters){
    id inv=ADInvertFilter701(); if(!inv)return NO;
    for(id f in filters) if(f==inv)return YES;
    return NO;
}
static void ADSetInvert701(CALayer *layer,const void *ownedKey,BOOL on){
    if(!layer)return;
    @try {
        id inv=ADInvertFilter701(); if(!inv)return;
        NSNumber *owned=objc_getAssociatedObject(layer,ownedKey);
        NSMutableArray *cur=[layer.filters mutableCopy]?:[NSMutableArray array];
        if(on){
            if(!ADHasInvert701(cur))[cur addObject:inv];
            layer.filters=cur;
            if(!owned)objc_setAssociatedObject(layer,ownedKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(owned){
            [cur removeObjectIdenticalTo:inv];
            layer.filters=cur;
            objc_setAssociatedObject(layer,ownedKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } @catch(...) {}
}
static void ADApplyWindowInvert701(UIWindow *w){
    if(!w)return;
    ADSetInvert701(w.layer,kADRootInvert701,gP.enabled);
}

// Native product-photo classification.  This is deliberately photo-oriented,
// not "all UIImageViews": small/template artwork, chrome, controls, logos,
// avatars, glyphs, badges and navigation imagery remain in the root inversion.
static BOOL ADTemplateImage701(UIImage *im){
    if(!im)return YES;
    if(im.renderingMode==UIImageRenderingModeAlwaysTemplate)return YES;
    CGImageRef cg=im.CGImage;
    if(cg && (CGImageIsMask(cg)||CGImageGetAlphaInfo(cg)==kCGImageAlphaOnly))return YES;
    if(im.symbolConfiguration)return YES;
    return NO;
}
static BOOL ADPhotoBlockWord701(NSString *s){
    if(!s.length)return NO; NSString *q=s.lowercaseString;
    static NSArray *bad=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ bad=@[@"icon",@"glyph",@"logo",@"avatar",@"profile",@"badge",@"rating",@"star",@"checkbox",@"heart",@"arrow",@"chevron",@"button",@"search",@"camera",@"microphone",@"menu",@"hamburger",@"sprite",@"nav",@"tabbar",@"brand",@"seller",@"store-logo",@"flag",@"swatch"]; });
    for(NSString *x in bad)if([q containsString:x])return YES;
    return NO;
}
static BOOL ADProductWord701(NSString *s){
    if(!s.length)return NO; NSString *q=s.lowercaseString;
    static NSArray *good=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ good=@[@"product",@"asin",@"buyagain",@"buy-again",@"recommend",@"item-image",@"itemimage",@"offer-image",@"offerimage",@"pdp",@"detail-image",@"detailimage"]; });
    for(NSString *x in good)if([q containsString:x])return YES;
    return NO;
}
static BOOL ADNativeProductPhoto701(UIImageView *iv){
    if(!iv||!iv.image||!iv.window||ADTemplateImage701(iv.image))return NO;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<1)w=iv.image.size.width; if(h<1)h=iv.image.size.height;
        CGImageRef cg=iv.image.CGImage; if(!cg)return NO;
        size_t pw=CGImageGetWidth(cg),ph=CGImageGetHeight(cg);
        if(w<52||h<52||pw<80||ph<80)return NO;

        NSMutableString *meta=[NSMutableString stringWithFormat:@"%@ %@ %@ ",NSStringFromClass(iv.class),iv.accessibilityIdentifier?:@"",iv.accessibilityLabel?:@""];
        BOOL productContext=ADProductWord701(meta);
        UIView *n=iv;
        for(int i=0;i<7&&n;i++,n=n.superview){
            if([n isKindOfClass:[UIButton class]]||[n isKindOfClass:[UITabBar class]]||[n isKindOfClass:[UINavigationBar class]])return NO;
            NSString *piece=[NSString stringWithFormat:@"%@ %@ %@ ",NSStringFromClass(n.class),n.accessibilityIdentifier?:@"",n.accessibilityLabel?:@""];
            if(ADPhotoBlockWord701(piece))return NO;
            if(ADProductWord701(piece))productContext=YES;
            [meta appendString:piece];
        }
        if(ADPhotoBlockWord701(meta))return NO;

        // Amazon's native product grids/galleries frequently use these raster
        // containers without useful accessibility metadata.  Large images in
        // those classes are treated as photographic product media; icons were
        // already rejected above by size/template/semantic gates.
        BOOL knownPhotoClass=[iv isKindOfClass:NSClassFromString(@"ANXFastImageView")]||
                             [iv isKindOfClass:NSClassFromString(@"RCTUIImageViewAnimated")];
        return productContext||knownPhotoClass;
    } @catch(...) { return NO; }
}
static void ADRemoveTWB701(UIImageView *iv){
    CALayer *ov=objc_getAssociatedObject(iv,kADTWBOverlay701);
    if(ov){[ov removeFromSuperlayer];objc_setAssociatedObject(iv,kADTWBOverlay701,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
}
static void ADApplyNativeMedia701(UIImageView *iv){
    if(!iv)return;
    @try {
        BOOL product=gP.enabled&&ADNativeProductPhoto701(iv);
        ADSetInvert701(iv.layer,kADMediaInvert701,product);
        if(!product||!gP.whiteTame){ADRemoveTWB701(iv);return;}
        CALayer *ov=objc_getAssociatedObject(iv,kADTWBOverlay701);
        if(!ov){
            ov=[CALayer layer]; ov.name=@"AmazonDarkTWB701";
            ov.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"backgroundColor":[NSNull null],@"cornerRadius":[NSNull null]};
            [iv.layer addSublayer:ov]; objc_setAssociatedObject(iv,kADTWBOverlay701,ov,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        CGFloat alpha=MAX(0,MIN(100,gP.whiteTameStrength))/100.0;
        ov.frame=iv.bounds; ov.backgroundColor=[UIColor colorWithWhite:0 alpha:alpha].CGColor;
        ov.cornerRadius=iv.layer.cornerRadius; ov.masksToBounds=YES; ov.zPosition=FLT_MAX;
    } @catch(...) {}
}

// Web first-paint protection is declarative and product-specific.  The selectors
// cover Amazon's stable product identities/links instead of v6.0.208's blanket
// `img,video,canvas` rule, which unintentionally preserved every Web image.
static NSString *ADWebMediaJS701(void){
    CGFloat strength=MAX(0,MIN(100,gP.whiteTameStrength));
    CGFloat bright=MAX(0.05,1.0-strength/100.0);
    return [NSString stringWithFormat:
        @"(function(){try{var ID='ad701-product-media',s=document.getElementById(ID);if(!s){s=document.createElement('style');s.id=ID;(document.head||document.documentElement||document).appendChild(s);}"
         "var P='img[data-a-dynamic-image],img.a-dynamic-image,img[data-old-hires],#landingImage,#imgTagWrapperId img,[data-asin] img,[data-csa-c-asin] img,a[href*=\\\"/dp/\\\"] img,a[href*=\\\"/gp/product/\\\"] img,[class*=\\\"product-image\\\"] img,[class*=\\\"productImage\\\"] img,[id*=\\\"product-image\\\"] img,[data-ad701-product=\\\"1\\\"]';"
         "s.textContent=P+'{filter:invert(1)!important;}'+(%.0f?P+'{filter:brightness(%.3f) invert(1)!important;}':'');"
         "var bad=/icon|glyph|logo|avatar|profile|badge|rating|star|checkbox|heart|arrow|chevron|button|search|camera|microphone|menu|hamburger|sprite|nav|tabbar|brand|seller|store-logo|flag|swatch/i;"
         "var good=/product|asin|buy.?again|recommend|item.?image|offer.?image|pdp|detail.?image/i;"
         "function mark(e){try{if(!e||e.tagName!=='IMG')return;var n=e,ok=good.test((e.className||'')+' '+(e.id||'')+' '+(e.alt||''));for(var i=0;i<6&&n;i++,n=n.parentElement){var z=((n.className&&n.className.baseVal)||n.className||'')+' '+(n.id||'')+' '+(n.getAttribute&&((n.getAttribute('data-asin')||'')+' '+(n.getAttribute('data-csa-c-asin')||'')+' '+(n.getAttribute('aria-label')||''))||'');if(bad.test(String(z)))return;if(good.test(String(z)))ok=true;if(n.tagName==='A'){var h=n.getAttribute('href')||'';if(h.indexOf('/dp/')>=0||h.indexOf('/gp/product/')>=0)ok=true;}}var r=e.getBoundingClientRect(),w=r.width||e.width||0,h=r.height||e.height||0,nw=e.naturalWidth||0,nh=e.naturalHeight||0;if(ok&&w>=48&&h>=48&&nw>=64&&nh>=64)e.setAttribute('data-ad701-product','1');}catch(x){}}"
         "document.addEventListener('load',function(ev){mark(ev.target);},true);function once(){try{document.querySelectorAll('img').forEach(mark);}catch(x){}}if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',once,{once:true});else once();window.addEventListener('pageshow',once,{passive:true});"
         "}catch(e){}})();",(gP.whiteTame?1.0:0.0),bright];
}
static void ADTrackWebView701(WKWebView *wv){
    if(!wv)return; @try { @synchronized([WKWebView class]) { if(!gADWebViews701)gADWebViews701=[NSHashTable weakObjectsHashTable]; [gADWebViews701 addObject:wv]; } } @catch(...) {}
}
static NSArray *ADTrackedWebViews701(void){
    @try { @synchronized([WKWebView class]) { return gADWebViews701?gADWebViews701.allObjects:@[]; } } @catch(...) {}
    return @[];
}
static void ADInstallWeb701(WKUserContentController *ucc){
    if(!ucc||objc_getAssociatedObject(ucc,kADWebScript701))return;
    @try {
        WKUserScript *us=[[WKUserScript alloc] initWithSource:ADWebMediaJS701() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
        [ucc addUserScript:us]; objc_setAssociatedObject(ucc,kADWebScript701,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}
static void ADRefreshWeb701(WKWebView *wv){
    if(!wv)return; ADTrackWebView701(wv);
    @try { [wv evaluateJavaScript:ADWebMediaJS701() completionHandler:nil]; } @catch(...) {}
}
static void ADApplyAllVisualState701(void){
    dispatch_async(dispatch_get_main_queue(),^{
        @try {
            for(UIWindow *w in UIApplication.sharedApplication.windows)ADApplyWindowInvert701(w);
            for(WKWebView *wv in ADTrackedWebViews701())if(wv.window)ADRefreshWeb701(wv);
        } @catch(...) {}
    });
}

%hook UIWindow
- (void)didMoveToWindow {
    %orig;
    ADApplyWindowInvert701(self);
}
- (void)layoutSubviews {
    %orig;
    ADApplyWindowInvert701(self);
}
- (void)makeKeyAndVisible {
    ADApplyWindowInvert701(self);
    %orig;
    ADApplyWindowInvert701(self);
}
- (void)setRootViewController:(UIViewController *)vc {
    %orig;
    ADApplyWindowInvert701(self);
}
%end

%hook UIImageView
- (void)setImage:(UIImage *)image {
    %orig;
    ADApplyNativeMedia701(self);
}
- (void)didMoveToWindow {
    %orig;
    ADApplyNativeMedia701(self);
}
- (void)layoutSubviews {
    %orig;
    if(objc_getAssociatedObject(self,kADMediaInvert701)||objc_getAssociatedObject(self,kADTWBOverlay701)||gP.enabled)ADApplyNativeMedia701(self);
}
%end

%hook WKWebView
- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    if(gP.enabled&&configuration.userContentController)ADInstallWeb701(configuration.userContentController);
    id wv=%orig;
    ADTrackWebView701(wv);
    return wv;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    id wv=%orig;
    if(gP.enabled)ADInstallWeb701(((WKWebView*)wv).configuration.userContentController);
    ADTrackWebView701(wv);
    return wv;
}
- (void)didMoveToWindow {
    %orig;
    if(self.window){ADInstallWeb701(self.configuration.userContentController);ADRefreshWeb701(self);}
}
%end

// -----------------------------------------------------------------------------
// Launch transition handoff. The SpringBoard side retains v6.0.185's 1.40 s
// minimum presentation and 0.55 s fade; Amazon only tells it that the inverted root
// is mounted. Cached light launch snapshots are cleared exactly as in v6.0.185.
// -----------------------------------------------------------------------------
static void ADPostReadyOnce(void){
    static BOOL posted=NO; if(posted)return; posted=YES; @try { notify_post("com.colindavidr.amazondark.ready"); } @catch(...) {}
}

static void ADPrefsChanged(CFNotificationCenterRef c,void *o,CFStringRef n,const void *obj,CFDictionaryRef ui){
    ADLoadPrefs(); ADRefreshPromotionState611(); ADApplyAllVisualState701();
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
        ADApplyAllVisualState701();
        ADRefreshPromotionState611();
        ADApplyJIT622();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.20*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ ADPostReadyOnce(); });
    });
}

#pragma clang diagnostic pop
