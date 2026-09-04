/*
 * AmazonDark v7.336 — process-scoped launch readiness
 *
 * Architecture:
 *   - document-start, route-exclusive web CSS/JS owners
 *   - exact native lifecycle/setter owners backed by device probes
 *   - retained v6.0.185 preferences, 120 Hz path, TWB, and minimal cold first-frame shim
 *
 * Production invariants:
 *   - no Dark Reader, native-dark weblab forcing, MutationObserver, polling loop,
 *     recurring hierarchy scanner, RAF loop, or web scroll listener
 *   - Cart Share / Saved / related-item text and Person AppCX sheet ownership are probe-scoped
 *   - the v7.255 Hamburger ownership remains exact to the #scrolled-hamburger React surface
 *   - all seven forensics probes remain dormant until screenshot/SIGUSR2
 *   - the Cart lifecycle recorder exists only during an explicitly armed probe window
 */

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>
#import <unistd.h>
#import <stdint.h>
#import <string.h>
#import <float.h>
#import <signal.h>

#define AD_VERSION "v7.336-v7330-cold-v6185-warm-switcher"
#define AD_PREF_DOMAIN "com.colindavidr.amazondark"

extern char *__progname;
@interface RNSVGSvgView : UIView @end

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
@interface SNPRootView : UIView @end
@interface RCTView : UIView @end
@interface RCTScrollView : UIScrollView @end
@interface RCTParagraphComponentView : UIView @end
@interface RCTTextView : UIView @end
@interface RNCEKVExternalKeyboardView : UIView @end
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
    gP.privacyMode=NO;
    gP.whiteTameStrength=45;
    @try {
        NSString *path=[NSString stringWithFormat:@"/var/jb/var/mobile/Library/Preferences/%s.plist",AD_PREF_DOMAIN];
        NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:path];
        if(!d.count)return;
        gP.enabled=ADPrefBool(d,@"enabled",gP.enabled);
        gP.whiteTame=ADPrefBool(d,@"whiteTame",gP.whiteTame);
        gP.force120Hz=ADPrefBool(d,@"force120Hz",gP.force120Hz);
        gP.privacyMode=ADPrefBool(d,@"privacyMode",gP.privacyMode);
        gP.whiteTameStrength=ADPrefLong(d,@"whiteTameStrength",gP.whiteTameStrength);
    } @catch(...) {}
}

static inline UIColor *ADOLED(void){ return [UIColor blackColor]; }

// v7.226 stability contract: every AmazonDark-initiated UIView background write goes
// through one guarded, idempotent writer.  Hooks may observe Amazon/React writes, but
// they must never recursively re-enter AmazonDark while AmazonDark is committing paint.
static __thread NSUInteger gADPaintWriteDepth7226=0;
static inline BOOL ADInternalPaintWrite7226(void){ return gADPaintWriteDepth7226>0; }
static void ADSetViewBackground7226(UIView *v, UIColor *color, BOOL syncLayer){
    if(!v||!color)return;
    BOOL entered=NO;
    @try {
        CGColorRef cg=color.CGColor;
        BOOL sameView=v.backgroundColor && [v.backgroundColor isEqual:color];
        BOOL sameLayer=!syncLayer || (v.layer.backgroundColor && CGColorEqualToColor(v.layer.backgroundColor,cg));
        if(sameView&&sameLayer)return;
        gADPaintWriteDepth7226++; entered=YES;
        if(!sameView)v.backgroundColor=color;
        // UIKit normally synchronizes CALayer.backgroundColor itself. Re-read after
        // the UIView setter and only repair the layer when a custom renderer did not.
        if(syncLayer){
            CGColorRef now=v.layer.backgroundColor;
            if(!now||!CGColorEqualToColor(now,cg))v.layer.backgroundColor=cg;
        }
    } @catch(...) {
    } @finally {
        if(entered&&gADPaintWriteDepth7226)gADPaintWriteDepth7226--;
    }
}
static inline UIColor *ADHomeChipGray7226(void){
    static UIColor *c=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ c=[UIColor colorWithRed:74.0/255.0 green:79.0/255.0 blue:81.0/255.0 alpha:1.0]; });
    return c;
}

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
static BOOL ADIsPromotionInfoKey609(NSString *key){
    return [key isEqualToString:ADPromotionInfoKey607];
}

static inline BOOL ADPromotionPreferenceOn611(void){ return gP.enabled && gP.force120Hz; }

%group ADPromotionBundleHooks7271
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
        if ([d[ADPromotionInfoKey607] boolValue]) return d;
        NSMutableDictionary *m = [d mutableCopy];
        m[ADPromotionInfoKey607] = @YES;
        return m;
    } @catch(...) {}
    return d;
}
%end

%hookf(CFTypeRef, CFBundleGetValueForInfoDictionaryKey, CFBundleRef bundle, CFStringRef key) {
    if (ADPromotionPreferenceOn611() && bundle == CFBundleGetMainBundle() && key &&
        CFEqual(key, CFSTR("CADisableMinimumFrameDurationOnPhone"))) return kCFBooleanTrue;
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
    promoted = m;
    return promoted;
}
%end

static NSInteger ADPreferredMaxHz362(void){
    static NSInteger hz=60; static dispatch_once_t once;
    dispatch_once(&once,^{ @try { hz=MIN((NSInteger)120,MAX((NSInteger)60,UIScreen.mainScreen.maximumFramesPerSecond)); } @catch(...) {} });
    return hz;
}

// Weak registry of live links lets the Settings toggle take effect immediately in
// both directions. v6.0.10 only gated future setter calls; links already forced to
// 120 stayed forced until relaunch. Weak storage adds no ownership/lifetime cost.
static NSHashTable *gADDisplayLinks611 = nil;
static const void *kADTrackedDisplayLink7271=&kADTrackedDisplayLink7271;
static void ADTrackDisplayLink611(CADisplayLink *d){
    if (!d) return;
    @try {
        if(objc_getAssociatedObject(d,kADTrackedDisplayLink7271))return;
        @synchronized([CADisplayLink class]) {
            if(objc_getAssociatedObject(d,kADTrackedDisplayLink7271))return;
            if (!gADDisplayLinks611) gADDisplayLinks611 = [NSHashTable weakObjectsHashTable];
            [gADDisplayLinks611 addObject:d];
            objc_setAssociatedObject(d,kADTrackedDisplayLink7271,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
static void ADForceOverrideMinimumFrameDuration610(id self, SEL _cmd, NSInteger duration){
    NSInteger forced = duration;
    @try { if (gP.enabled && gP.force120Hz && ADPreferredMaxHz362() >= 120) forced = 2; } @catch(...) {}
    if (gADCADisplayOverrideOrig610) gADCADisplayOverrideOrig610(self, _cmd, forced);
}
static void ADInstallPrivateDisplayForce610(void){
    if (gADCADisplayOverrideInstallTried610) return;
    gADCADisplayOverrideInstallTried610 = YES;
    @try {
        Class c=objc_getClass("CADisplay");
        SEL sel=@selector(overrideMinimumFrameDuration:);
        Method m = c ? class_getInstanceMethod(c, sel) : NULL;
        if (!m) return;
        IMP old = method_getImplementation(m);
        if (!old || old == (IMP)ADForceOverrideMinimumFrameDuration610) return;
        gADCADisplayOverrideOrig610 = (ADCADisplayOverrideIMP610)old;
        method_setImplementation(m, (IMP)ADForceOverrideMinimumFrameDuration610);
    } @catch(...) {}
}

static id ADDisplayForLink610(CADisplayLink *d){
    @try {
        SEL s=@selector(display);
        if (d && [d respondsToSelector:s]) return ((id(*)(id,SEL))objc_msgSend)(d,s);
    } @catch(...) {}
    return nil;
}

static const void *kADOrigLinkState611 = &kADOrigLinkState611;
static const void *kADOrigDisplayMin611 = &kADOrigDisplayMin611;
typedef struct {
    NSInteger fps,interval;
    CAFrameRateRange range;
    BOOL hasInterval,hasRange;
} ADLinkState7271;
static void ADRememberPromotionState611(CADisplayLink *d){
    if (!d || objc_getAssociatedObject(d,kADOrigLinkState611)) return;
    @try {
        ADLinkState7271 st={0}; st.fps=d.preferredFramesPerSecond;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ([d respondsToSelector:@selector(frameInterval)]){ st.interval=d.frameInterval; st.hasInterval=YES; }
#pragma clang diagnostic pop
        if (@available(iOS 15.0,*)){
            st.range=d.preferredFrameRateRange; st.hasRange=YES;
        }
        objc_setAssociatedObject(d,kADOrigLinkState611,[NSValue value:&st withObjCType:@encode(ADLinkState7271)],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        id display=ADDisplayForLink610(d);
        if (display && !objc_getAssociatedObject(display,kADOrigDisplayMin611)){
            SEL minSel=@selector(minimumFrameDuration);
            if ([display respondsToSelector:minSel]){
                NSInteger v=((NSInteger(*)(id,SEL))objc_msgSend)(display,minSel);
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
        SEL forceSel=@selector(overrideMinimumFrameDuration:);
        if (origMin && display && [display respondsToSelector:forceSel])
            ((void(*)(id,SEL,NSInteger))objc_msgSend)(display,forceSel,(NSInteger)origMin.integerValue);
        SEL reasonSel=@selector(setHighFrameRateReason:);
        if ([d respondsToSelector:reasonSel])
            ((void(*)(id,SEL,uint32_t))objc_msgSend)(d,reasonSel,(uint32_t)0);
        NSValue *saved=objc_getAssociatedObject(d,kADOrigLinkState611);
        if (saved){
            ADLinkState7271 st={0}; [saved getValue:&st];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            if(st.hasInterval&&[d respondsToSelector:@selector(setFrameInterval:)])d.frameInterval=st.interval;
#pragma clang diagnostic pop
            d.preferredFramesPerSecond=st.fps;
            if(st.hasRange)if(@available(iOS 15.0,*))d.preferredFrameRateRange=st.range;
        }
        objc_setAssociatedObject(d,kADOrigLinkState611,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (display) objc_setAssociatedObject(display,kADOrigDisplayMin611,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}

static void ADForcePrivateDisplay610(CADisplayLink *d){
    if (!d || !gP.enabled || !gP.force120Hz || ADPreferredMaxHz362() < 120) return;
    ADInstallPrivateDisplayForce610();
    @try {
        id display = ADDisplayForLink610(d);
        SEL forceSel=@selector(overrideMinimumFrameDuration:);
        if (display && [display respondsToSelector:forceSel])
            ((void(*)(id,SEL,NSInteger))objc_msgSend)(display, forceSel, (NSInteger)2);
    } @catch(...) {}
}

static void ADSetHighFrameRateReason610(CADisplayLink *d){
    @try {
        SEL s=@selector(setHighFrameRateReason:);
        if (d && [d respondsToSelector:s]){
            // Private CoreAnimation SPI; non-zero reason keeps this link classified
            // as high-frame-rate work rather than an idle/ordinary 60-Hz client.
            ((void(*)(id,SEL,uint32_t))objc_msgSend)(d,s,(uint32_t)0x41440001); // "AD" + 1
        }
    } @catch(...) {}
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

static BOOL gADPromotionHooksInstalled7271=NO;
static void ADInstallPromotionHooks7271(void){
    if(gADPromotionHooksInstalled7271)return;
    gADPromotionHooksInstalled7271=YES;
    %init(ADPromotionBundleHooks7271);
}

// Reconfigure links immediately when the preference changes. Before forcing a
// link we snapshot its original public range/FPS/interval and its display's private
// minimum-frame-duration policy. OFF restores those exact values; ON reapplies the
// proven v6.0.10 force. No guessed "stock" frame rate is written.
static BOOL gADPromotionWasForced611=NO;
static void ADRefreshPromotionState611(void){
    BOOL on = ADPromotionPreferenceOn611();
    if(!on&&!gADPromotionWasForced611)return;
    NSArray *links = ADTrackedDisplayLinks611();
    for (CADisplayLink *d in links){
        if (!d) continue;
        @try {
            if (on){ ADApplyPromotion610(d); continue; }
            ADRestorePromotionState611(d);
        } @catch(...) {}
    }
    gADPromotionWasForced611=on;
}


static void ADConsiderLaunchReady706(void);

// -----------------------------------------------------------------------------
// OLED floor — no Dark Reader, no DOM observer, no visual-component classifier.
// -----------------------------------------------------------------------------
static const void *kADCoreWebUS7271=&kADCoreWebUS7271;
static const void *kADTWBUS=&kADTWBUS;
static const void *kADPrivacyUS7117=&kADPrivacyUS7117;
static const void *kADPrivacyRule7117=&kADPrivacyRule7117;
static const void *kADTrackedWebView7191=&kADTrackedWebView7191;
static NSHashTable *gADWebViews=nil;
// v7.0.68 production: no diagnostic touch probe is installed.

static NSString *ADFloorJS(void){
    // v7.162: preserve the proven v7.159 three-lane Search behavior and transition fix.
    // Add only exact Search/product-feed polish: light /s scrollbar and Alexa inline-slot floor ownership.
    return
        @"(function(){try{var host='';try{host=String(location.hostname||'').toLowerCase();}catch(_){}if(host==='flashtalking.com'||/\\.flashtalking\\.com$/.test(host))return;var child=0;try{c"
        @"hild=window.top!==window;}catch(_){child=1;}if(child&&document.documentElement)document.documentElement.setAttribute('data-ad7-child-frame','1');function put(id,css){var s=document.getElementById(id);if(!s){s=document.createElement('style');s.id=id;(document.head||document.documentElement||doc"
        @"ument).appendChild(s);}s.textContent=css;return s;}function relink(s){try{if(s&&!s.isConnected)(document.head||document.documentElement).appendChild(s)}catch(_){}}function rootBlac"
        @"k(){try{var h=document.documentElement;if(h){h.style.setProperty('background-color','#000','important');h.style.setProperty('color-scheme','dark','important');}if(document.body){do"
        @"cument.body.style.setProperty('background-color','#000','important');document.body.style.setProperty('color-scheme','dark','important');}}catch(_){}}if(child&&document.documentElement&&document.documentElement.hasAttribute('data-ad7104-standalone'))return;var p='';try{p=String(location.pathname||'');}catch(_){}var s=null;if(!child&&(p==='/autocomplete'||p.indexOf('/autocomplete/')===0)){s="
        @"put('ad7-search-pane-theme',\"html,body,#a-page,#attach-to-me{background:#000!important;background-color:#000!important;color:#e8e6e3!important;color-scheme:dark!important;}.s-sugge"
        @"stion-container,.s-suggestion,.autocomplete-results-container,[class*=autocomplete],[class*=suggestion]:not([class*=icon]):not([class*=glyph]),[class*=recentSearch]:not([class*=ico"
        @"n]):not([class*=glyph]),[class*=search-suggestion]:not([class*=icon]):not([class*=glyph]){background:#000!important;background-color:#000!important;color:#e8e6e3!important;}:is(.s-"
        @"suggestion-container,.s-suggestion,.autocomplete-results-container,[class*=autocomplete],[class*=recentSearch],[class*=search-suggestion]) :is(h1,h2,h3,h4,h5,h6,p,span,a,div){color"
        @":#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}.s-suggestion-section-heading,.sac-header-component-single-line-header{color:#e8e6e3!important;-webkit-text-fill-color"
        @":#e8e6e3!important;}#a-page :is([id^=sac-query-row-].s-query-row,.s-query-row-container,.s-query-row-link){background:#000!important;background-color:#000!important;-webkit-tap-hig"
        @"hlight-color:transparent!important;}#a-page :is([id^=sac-query-row-].s-query-row,.s-query-row-container,.s-query-row-link):is(:active,:focus,:focus-visible,:focus-within){backgroun"
        @"d:#000!important;background-color:#000!important;-webkit-tap-highlight-color:transparent!important;box-shadow:none!important;}#attach-to-me :is([class*=location],[class*=delivery],"
        @"[id*=location],[id*=delivery],[class*=glow],[id*=glow],[class*=ship-to],[id*=ship-to],[class*=shipto],[id*=shipto]):not(img):not(svg):not(i):not([class*=icon]):not([class*=glyph]):"
        @"not([id*=icon]){background-color:#000!important;border-color:#494d4d!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#attach-to-me :is(div,section,a):h"
        @"as(:is([class*=location],[class*=delivery],[id*=location],[id*=delivery],[class*=glow],[id*=glow],[class*=ship-to],[id*=ship-to],[class*=shipto],[id*=shipto])){background-color:#00"
        @"0!important;border-color:#494d4d!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#attach-to-me :is([class*=location],[class*=delivery],[id*=location],["
        @"id*=delivery],[class*=glow],[id*=glow],[class*=ship-to],[id*=ship-to],[class*=shipto],[id*=shipto]) :is(span,a,p,div,label,strong,b){color:#e8e6e3!important;-webkit-text-fill-color"
        @":#e8e6e3!important;}#attach-to-me :is([class*=location],[class*=delivery],[id*=location],[id*=delivery],[class*=glow],[id*=glow],[class*=ship-to],[id*=ship-to],[class*=shipto],[id*"
        @"=shipto]) :is(img,svg,i,[class*=icon],[class*=glyph],[id*=icon]){background-color:transparent!important;color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;filt"
        @"er:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;}:is(.a-color-base,.a-text-normal,.a-size-base,.a-size-base-plus,.a-size-medium,.a-price,.a-pr"
        @"ice-whole,.a-price-symbol,.a-price-fraction,.a-offscreen,.s-title-instructions-style,.a-link-normal h2,[class*=product-title],[class*=heading],[class*=title]:not([class*=badge])):n"
        @"ot([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-]):not(:where([class*=sponsored] *)):not(:wher"
        @"e([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)):not(:where(html[data-ad7-child-frame] *)):not(:where("
        @"#gwm-Deck *)):not(:where([class*=hero] *)):not(:where([class*=single-creative] *)):not(:where([class*=single-video] *)):not(:where([class*=theming-card] *)){color:#e8e6e3!important"
        @";-webkit-text-fill-color:#e8e6e3!important;}:is(.a-color-secondary,.a-size-small,[class*=secondary]):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not("
        @"[id^=ad-feedback-text-]):not([id^=af-label-primary-link-]):not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([id^="
        @"ad-feedback-] *)):not(:where([id^=af-label-] *)):not(:where(html[data-ad7-child-frame] *)):not(:where(#gwm-Deck *)):not(:where([class*=hero] *)):not(:where([class*=single-creative]"
        @" *)):not(:where([class*=single-video] *)):not(:where([class*=theming-card] *)){color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;}.s-result-item,.s-card-container,["
        @"data-component-type=s-search-result],#sc-active-cart .sc-list-item,#sc-saved-cart .sc-list-item,#dp .a-box,#dp .a-divider,#dp [class*=card],.s-suggestion-container,#auth-footer .a-"
        @"divider,.auth-footer .a-divider,[class*=swatch-outer-circle],[class*=puis-card]{border-color:#494d4d!important;outline-color:#494d4d!important;}.a-divider-inner:after,.a-divider-in"
        @"ner:before,hr,[class*=separator]{border-color:#494d4d!important;background-color:#494d4d!important;}#wd-backdrop-gradient,.wd-backdrop-gradient,[class*=wd-backdrop-gradient],[class"
        @"*=a-reactive-container],[class*=reactive-contain],#auth-footer,.auth-footer,[id*=auth-footer]{background-image:none!important;box-shadow:none!important;}#auth-footer .a-divider-inn"
        @"er,.auth-footer .a-divider-inner{background-image:none!important;box-shadow:none!important;}.s-color-swatch-container,.s-color-swatch-outer-circle{background-color:transparent!impo"
        @"rtant;}.s-color-swatch-outer-circle{border-color:#494d4d!important;outline-color:#494d4d!important;}[class*=nav-search] img,[class*=searchbar] img,[class*=search-bar] img,[role=sea"
        @"rch] img,[class*=nav-] img[class*=icon],[class*=header] img[class*=icon]{background-color:transparent!important;}.s-suggestion-container :is(img[class*=icon],img[alt*=search],img[a"
        @"lt*=arrow],svg,i.a-icon,[class*=glyph]),.s-suggestion :is(img[class*=icon],img[alt*=search],img[alt*=arrow],svg,i.a-icon,[class*=glyph]){color:#e8e6e3!important;fill:#e8e6e3!import"
        @"ant;stroke:#e8e6e3!important;filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;}.s-suggestion-container i.icon-past-search-suggestion.s-sugg"
        @"estion-icon-left{background-color:transparent!important;color:#9da3a3!important;fill:#9da3a3!important;stroke:#9da3a3!important;filter:brightness(0) invert(1) brightness(0.65)!impo"
        @"rtant;-webkit-filter:brightness(0) invert(1) brightness(0.65)!important;opacity:1!important;box-shadow:none!important;}.s-suggestion-container i.icon-close.s-suggestion-icon-left{b"
        @"ackground-color:transparent!important;color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) "
        @"invert(1)!important;opacity:1!important;box-shadow:none!important;}.s-query-row i.icon-search-suggestion.s-query-row-search-icon,.s-suggestion-container i:is([class*=icon-search],["
        @"class*=search-icon]),.s-suggestion i:is([class*=icon-search],[class*=search-icon]),.s-suggestion-container i.s-suggestion-icon-right{background-color:transparent!important;color:#e"
        @"8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;filter:brightness(0) invert(1) brightness(0.91)!important;-webkit-filter:brightness(0) invert(1) brightness(0.91)!im"
        @"portant;opacity:1!important;box-shadow:none!important;}.ufs_tiles_card_widget-suggestion{background:#000!important;background-color:#000!important;color:#e8e6e3!important;}.ufs_til"
        @"es_card_widget-suggestion :is(.ufs_tiles_card_widget-sug-container-top,.ufs_tiles_card_widget-sug-column,.ufs_tiles_card_widget-sug-card,.ufs_tiles_card_widget-sug-link,.ufs_tiles_"
        @"card_widget-sug-image-container,.ufs_tiles_card_widget-sug-image-background){background-color:transparent!important;border-color:#494d4d!important;}.ufs_tiles_card_widget-suggestio"
        @"n :is(h1,h2,h3,h4,h5,h6,p,span,a,div){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}.ufs_tiles_card_widget-suggestion .ufs_tiles_card_widget-sug-text{backgroun"
        @"d:#000!important;background-color:#000!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}.ufs_tiles_card_widget-suggestion .ufs_tiles_card_widget-sug-text *{co"
        @"lor:#fff!important;-webkit-text-fill-color:#fff!important;}.s-entity-pd-carousel-tile-suggestion,.s-entity-pd-carousel-tile-container,.s-entity-pd-carousel-tile-element-container,.s-entity-pd-carousel-tile-element-image-container{background:#000!important;background-color:#000!important;}.s-entity-pd-carousel-tile-element-title-container{background:#000!important;background-color:#000!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}.s-entity-pd-carousel-tile-element-title-container :is(span,a,p,div){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}\");}else if(!child&&(p==='/s'||p.indexOf('/s/')===0)){s=put('ad7-product-feed-theme',\"::-webkit-scrollbar{background-color:transparent!important;}::-webkit-scrollbar-track{background-color:transparent!important;}::-webkit-scrollbar-thumb{background-color:#d5d9d9!important;border-radius:8px!important;border:2px solid transparent!important;background-clip:content-box!important;}::-webkit-scrollbar-thumb:hover{background-color:#e8e6e3!important;}html,body,#a-page,#search,.s-main-s"
        @"lot,.s-result-item,[data-component-type=s-search-result],.s-card-container,.puis-card-container,.puisg-row,.puisg-col,.puisg-col-inner{background:#000!important;background-color:#0"
        @"00!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;box-shadow:none!important;}#search :is(.a-color-base,.a-text-normal,.a-size-base,.a-size-base-plus,.a"
        @"-size-medium,.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen,.s-title-instructions-style,h1,h2,h3,h4,h5,h6,p,label,strong,b){color:#e8e6e3!important;-webkit-"
        @"text-fill-color:#e8e6e3!important;}#search :is(.a-color-secondary,.a-size-small){color:#b1b5b5!important;-webkit-text-fill-color:#b1b5b5!important;}#search :is(.s-result-item,.s-ca"
        @"rd-container,.puis-card-container,[data-component-type=s-search-result]){border-color:#494d4d!important;outline-color:#494d4d!important;}#search :is(.a-divider-inner)::before,#sear"
        @"ch :is(.a-divider-inner)::after,#search hr{border-color:#494d4d!important;background-color:#494d4d!important;}.ufs_tiles_card_widget-suggestion{background:#000!important;background"
        @"-color:#000!important;color:#e8e6e3!important;}.ufs_tiles_card_widget-suggestion :is(.ufs_tiles_card_widget-sug-container-top,.ufs_tiles_card_widget-sug-column,.ufs_tiles_card_widg"
        @"et-sug-card,.ufs_tiles_card_widget-sug-link,.ufs_tiles_card_widget-sug-image-container,.ufs_tiles_card_widget-sug-image-background){background-color:transparent!important;border-co"
        @"lor:#494d4d!important;}.ufs_tiles_card_widget-suggestion :is(h1,h2,h3,h4,h5,h6,p,span,a,div){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}.ufs_tiles_card_widg"
        @"et-suggestion .ufs_tiles_card_widget-sug-text{background:#000!important;background-color:#000!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}.ufs_tiles_card"
        @"_widget-suggestion .ufs_tiles_card_widget-sug-text *{color:#fff!important;-webkit-text-fill-color:#fff!important;}#search :is(.puis-product-insight-prompt-group,#rufus-overviews-pi"
        @"lls-carousel,#rufus-mobile-overviews-expandable-pills-carousel-container,#rufus-overviews-category-cards-carousel){background-color:#000!important;border-color:#494d4d!important;bo"
        @"x-shadow:none!important;}#search .nice-widget-container.nice-widget-container-inline-slot{background:#000!important;background-color:#000!important;background-image:none!important;box-shadow:none!important;}#search .nice-widget-container.nice-widget-container-inline-slot::before,#search .nice-widget-container.nice-widget-container-inline-slot::after{background:transparent!important;background-color:transparent!important;background-image:none!important;box-shadow:none!important;}#nav-global-location-slot,#glow-ingress-block{background:#000!important;background-color:#000!important;background-image:none!important;border-color:#000!i"
        @"mportant;color:#f2f2f2!important;-webkit-text-fill-color:#f2f2f2!important;box-shadow:none!important;}#nav-global-location-slot :is(span,a,p,div,label,strong,b),#glow-ingress-block"
        @" :is(span,a,p,div,label,strong,b){color:#f2f2f2!important;-webkit-text-fill-color:#f2f2f2!important;}#nav-global-location-slot :is(svg,i),#glow-ingress-block :is(svg,i){background-"
        @"color:transparent!important;color:#f2f2f2!important;fill:#f2f2f2!important;stroke:#f2f2f2!important;}#a-page :is(.s-mobile-toolbar,.sf-rib30-toolbar,.sf-rib30-panel,.sf-rib30-conte"
        @"nt){background-color:#000!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;border-color:#494d4d!important;}#a-page .sf-rib30-dropdown-main-container{border-left-color:#747a7c!important;}#a-page :is(.s-rib-toggle-container,.sf-rib30-"
        @"dropdown-title,a.sf-rib30-dropdown-pill-option){background-color:#202324!important;border-color:#747a7c!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;"
        @"box-shadow:none!important;}#a-page :is(.sf-mobile-rib-filter-icon,.sf-rib30-dropdown-arrow-icon){background-color:transparent!important;filter:brightness(0) invert(1) brightness(.8"
        @"8)!important;-webkit-filter:brightness(0) invert(1) brightness(.88)!important;}#a-page .sf-rib30-dropdown-pill-icon,#a-page i.a-icon-prime{filter:none!important;-webkit-filter:none"
        @"!important;}#search :is(.puis-status-badge-container,.puis-status-badge-container .a-section,.puis-status-badge-container .rush-component,.puis-status-badge-container .a-badge,.pui"
        @"s-status-badge-container .a-badge-label,.puis-status-badge-container .a-badge-label-inner){background:#000!important;background-color:#000!important;background-image:none!important"
        @";color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;box-shadow:none!important;}#search .puis-status-badge-container :is(i,svg,[class*=icon]){background-color:transpa"
        @"rent!important;color:#d6d9d9!important;fill:#d6d9d9!important;stroke:#d6d9d9!important;filter:brightness(0) invert(1) brightness(.88)!important;-webkit-filter:brightness(0) invert("
        @"1) brightness(.88)!important;}#search#search .more-like-this-container{background:transparent!important;background-color:transparent!important;background-image:none!important;box-s"
        @"hadow:none!important;}#search#search .nile-ingress-pill-button,#search#search .nile-ingress-pill-button .a-button-inner{background:#4a4f51!important;background-color:#4a4f51!import"
        @"ant;background-image:none!important;border-color:#747a7c!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search .nile-ingre"
        @"ss-pill-button :is(span,div){color:#fff!important;-webkit-text-fill-color:#fff!important;}"
        // v7.175 r3: current Amazon Haul renderer. Preserve its authored animated background image
        // so the emoji/art remains stock; replace only the purple base and white structural planes.
        @"#search#search .haul-asin-recommendation-styled-widget-container-override,#search#search .haul-asin-recommendation-styled-widget-container{background-color:#000!important;color:#fff!important;-webkit-text-fill-color:#fff!important;border-color:#000!important;outline-color:#000!important;box-shadow:none!important;}#search#search :is(.haul-asin-recommendation-styled-header-container,.haul-asin-recommendation-styled-subtitle,.haul-asin-recommendation-styled-carousel-container,.haul-puis-product-info,.haul-puis-widget-product-info-container){background:#000!important;background-color:#000!important;background-image:none!important;border-color:#000!important;outline-color:#000!important;box-shadow:none!important;}#search#search .haul-puis-image-container{background-color:#000!important;border-color:#000!important;outline-color:#000!important;box-shadow:none!important;}"
        @"#search#search .haul-puis-widget-faceout-container{background:#000!important;background-color:#000!important;border-color:#000!important;outline-color:#000!important;box-shadow:none!important;}#search#search .haul-puis-widget-faceout-container > :not(.haul-puis-widget-action-button){border-color:#000!important;outline-color:#000!important;box-shadow:none!important;}"
        @"#search#search :is(.haul-asin-recommendation-styled-widget-container-override,.haul-asin-recommendation-styled-widget-container) :is(h1,h2,h3,h4,h5,h6,p,a,span,div):not(.haul-puis-image-container){color:#fff!important;-webkit-text-fill-color:#fff!important;}"
        // Same Add-to-cart palette as normal product cards; Amazon keeps geometry and radius.
        @"#search#search .haul-puis-widget-action-button .a-button.a-button-primary{background:#000!important;background-color:#000!important;background-image:none!important;border:1px solid #747a7c!important;border-color:#747a7c!important;box-shadow:inset 0 0 0 1px #747a7c!important;filter:none!important;-webkit-filter:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#search#search .haul-puis-widget-action-button .a-button.a-button-primary .a-button-inner{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;}#search#search .haul-puis-widget-action-button .a-button.a-button-primary .a-button-text{background:transparent!important;background-color:transparent!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;filter:none!important;-webkit-filter:none!important;}"
        @"#search#search .s-coupon-tile,#search#search .s-coupon-tile-price-content,#search#search .s-coupon-unclipped,#search#search .s-coupon-highlight-c"
        @"olor{background:#008000!important;background-color:#008000!important;background-image:none!important;border-color:#008000!important;box-shadow:none!important;color:#fff!important;-"
        @"webkit-text-fill-color:#fff!important;}#search#search .s-coupon-tile-text-content,#search#search .s-coupon-checkbox-label,#search#search .s-coupon-tile-price-content,#search#search"
        @" .s-coupon-unclipped,#search#search .s-coupon-highlight-color{color:#fff!important;-webkit-text-fill-color:#fff!important;}"
        // v7.192: the unclaimed Search coupon label carries its own a-color-base gray.
        // Own that exact small label leaf without changing the green tile or discounted price.
        @"#search#search .s-coupon-tile .s-coupon-tile-text-content .a-size-small.a-color-base.a-text-normal{color:#fff!important;-webkit-text-fill-color:#fff!important;}"
        // v7.175 r5: claimed coupon state. Keep the true-green root; change only selected-state details.
        @"#search#search .s-coupon-tile.claimed .s-coupon-tile-content > span.a-size-small.a-color-base.a-text-normal{color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search .s-coupon-tile.claimed svg.s-coupon-success path.s-coupon-icon-background{fill:#000!important;stroke:none!important;}#search#search .s-coupon-tile.claimed svg.s-coupon-success path:not(.s-coupon-icon-background){fill:#fff!important;}#search#search .s-coupon-tile.claimed svg.s-coupon-success{filter:none!important;-webkit-filter:none!important;}"
        @"#search#search :is(video.sbv-video-player-ecx,video._c2It"
        @"d_video_17g-f){color-scheme:light!important;accent-color:auto!important;filter:none!important;-webkit-filter:none!important;}#search#search :is(.sbv-video-pause-button-container,.s"
        @"bv-video-mute-button-container,.sbv-mobile-video-play-click-region,._c2Itd_playClickRegion_87ZZa){background-color:transparent!important;border-color:transparent!important;outline-"
        @"color:transparent!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;}#search#search .puis-card-container.mobile-video-product-view.puis-card-b"
        @"order{background-color:#000!important;border:1px solid #494d4d!important;border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!im"
        @"portant;}#search#search .sbv-video-single-product .sbv-product-container,#search#search .sbv-video-single-product .sbv-product-container :is(.puisg-row,.puisg-col,.puisg-col-inner,"
        @".faceout-product-title,.faceout-product-review,.faceout-product-price,.puis-delivery-recipe,.udm-delivery-block){background-color:#000!important;border-color:#494d4d!important;outl"
        @"ine-color:#494d4d!important;box-shadow:none!important;}#search#search ._c2Itd_container_ut_MN.sb-video-creative{background-color:#000!important;border:1px"
        @" solid #494d4d!important;border-color:#494d4d!important;border-radius:4px!important;outline-color:#494d4d!important;box-shadow:none!important;overflow:hidden!important;}#search#sea"
        @"rch ._c2Itd_cardContent_3OGkG.sbv-ad-content-container,#search#search ._c2Itd_content_2L-a5,#search#search ._c2Itd_singleAsin_fHkKv{background:#000!important;background-color:#000!"
        @"important;background-image:none!important;border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!important;}#search#search ._c2Itd_singleAsin_fHkKv{border:1"
        @"px solid #494d4d!important;}#search#search ._c2Itd_singleAsin_fHkKv :is(._c2Itd_pdCntr_2lxVH,._c2Itd_pdRowCntr_1SQrE,._c2Itd_pdImgCol_3WO1V,._c2Itd_pdcol_3gSOx,.productDetailsConta"
        @"iner){background-color:#000!important;border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!important;}#search#search ._c2Itd_singleAsin_fHkKv :is(.product"
        @"DetailsContainer,._c2Itd_productTitle_1rGyG,._c2Itd_reviewStars_1pJ4C,._c2Itd_badgeContainer_3rI4l,._c2Itd_dealMessage_1qaio,._c2Itd_priceLinkContainer_6y-Wc,._c2Itd_savingPercenta"
        @"ge_3sw1C){background-color:transparent!important;box-shadow:none!important;}#search#search ._c2Itd_singleAsin_fHkKv :is(._c2Itd_singleProductImageContainer_1xhVQ,._c2Itd_productIma"
        @"geLinkContainer_3novt,a._c2Itd_productImageLink_2cbWY){background-color:transparent!important;box-shadow:none!important;}#search#search ._c2Itd_singleAsin_fHkKv img._c2Itd_image_pQ"
        @"REQ{display:block!important;visibility:visible!important;position:relative!important;z-index:6!important;background-color:transparent!important;mix-blend-mode:normal!important;}"
        // v7.208: exact _c2Itd vertical-video standalone ownership.  The probe proves the card is one
        // 428x365 content shell with a 176x313 video, brand/product raster cells, and a 40pt footer.
        // Own only structural colors here; never erase background-image on media-capable descendants.
        @"#search#search ._c2Itd_cardContent_3OGkG.sbv-ad-content-container :is([class*=_c2Itd_videoSectionContainer_],[class*=_c2Itd_videoContainer_],[class*=_c2Itd_videoBackgroundContainer_],[class*=_c2Itd_brandContainer_],[class*=_c2Itd_brand_],[class*=_c2Itd_logoContainer_],[class*=_c2Itd_pdCntr_],[class*=_c2Itd_pdRowCntr_],[class*=_c2Itd_pdImgCol_],[class*=_c2Itd_pdImgCntr_],[class*=_c2Itd_singleProductImageContainer_],[class*=_c2Itd_productImageLinkContainer_],[class*=_c2Itd_footer_],[class*=_c2Itd_contentStores_],[class*=_c2Itd_footerSponsoredLabel_],[class*=_c2Itd_ctaTextContainer_],[class*=_c2Itd_ctaLinkContainer_]){background-color:#000!important;border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!important;}"
        @"#search#search ._c2Itd_cardContent_3OGkG.sbv-ad-content-container :is([class*=_c2Itd_footer_],[class*=_c2Itd_ctaTextContainer_],[class*=_c2Itd_ctaLinkContainer_]) :is(a,span,div){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
        @"#search#search ._c2Itd_cardContent_3OGkG.sbv-ad-content-container :is([class*=_c2Itd_footerSponsoredLabel_],[class*=_c2Itd_contentStores_],[class*=ad-feedback]) :is(a,span,div){color:#b1b5b5!important;-webkit-text-fill-color:#b1b5b5!important;}"
        @"#search#search ._c2Itd_cardContent_3OGkG.sbv-ad-content-container :is([class*=_c2Itd_ad-feedback-sprite-mobile_],[class*=_c2Itd_ad-feedback-sprite-mobile-grey_]){filter:brightness(0) invert(1) brightness(.68)!important;-webkit-filter:brightness(0) invert(1) brightness(.68)!important;}"
        @"#search :is(.sf-mobile-rib-filter-icon,.sf-rib30-dropdown-arrow-icon,.rufus-expandable-pills-chevron){background-color:transparent!important;color:#d6d9d9!important;fill:#d6d9d9!impor"
        @"tant;stroke:#d6d9d9!important;}#search#search .s-rib-toggle-icon{background:transparent!important;background-color:transparent!important;filter:none!important;-webkit-filter:none!i"
        @"mportant;mix-blend-mode:normal!important;opacity:1!important;}#search#search .s-rib-toggle-container{background:transparent!important;background-color:transparent!important;backgro"
        @"und-image:none!important;border-color:transparent!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;}#search#search .sf-rib30-dropdown-pill-ic"
        @"on{background-color:#202324!important;border-color:#747a7c!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;mix-blend-mode:normal!important;o"
        @"pacity:1!important;}#search#search .sf-rib30-review-star{filter:none!important;-webkit-filter:none!important;mix-blend-mode:normal!important;opacity:1!important;}#search#search .sf"
        @"-rib30-dropdown-pill-icon .sf-rib30-review-content,#search#search .sf-rib30-dropdown-pill-icon .sf-rib30-review-stars-group{background:transparent!important;background-color:transp"
        @"arent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;}#search#search .sf"
        @"-rib30-dropdown-title > .a-declarative > .sf-rib30-title-content-container,#search#search .sf-rib30-dropdown-title .sf-rib30-title-content-container .sf-rib30-dropdown-pill-content"
        @",#search#search .sf-rib30-dropdown-title .sf-rib30-title-content-container .sf-rib30-dropdown-pill-text{background:transparent!important;background-color:transparent!important;back"
        @"ground-image:none!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;}#search#search .sf-rib30-dropdown-title{background:#202324!important;back"
        @"ground-color:#202324!important;border-color:#747a7c!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;box-shadow:none!important;}#search#search .sf-rib30-"
        @"dropdown-title .sf-rib30-dropdown-arrow-icon{background:transparent!important;background-color:transparent!important;background-image:none!important;filter:none!important;-webkit-f"
        @"ilter:none!important;box-shadow:none!important;position:relative!important;}#search#search .sf-rib30-dropdown-title .sf-rib30-dropdown-arrow-icon::before{content:\\\"\\\"!important;dis"
        @"play:block!important;position:absolute!important;left:1px!important;top:-1px!important;width:5px!important;height:5px!important;background:transparent!important;background-color:tr"
        @"ansparent!important;border:0!important;border-right:1.5px solid #d6d9d9!important;border-bottom:1.5px solid #d6d9d9!important;box-sizing:border-box!important;transform:rotate(45deg"
        @")!important;-webkit-transform:rotate(45deg)!important;filter:none!important;-webkit-filter:none!important;}#search#search .sf-rib30-dropdown-title .sf-rib30-dropdown-arrow-icon::af"
        @"ter{content:none!important;}#search#search .rufus-expandable-pills-chevron{background:transparent!important;background-color:transparent!important;border-color:transparent!importan"
        @"t;box-shadow:none!important;}#search#search .rufus-expandable-pills-chevron img{background-color:transparent!important;filter:none!important;-webkit-filter:none!important;mix-blend"
        @"-mode:normal!important;opacity:1!important;}#search#search :is(#rufus-overviews-pills-carousel,#rufus-mobile-overviews-expandable-pills-carousel-container) .a-carousel-card{backgro"
        @"und:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;}#search#search :is(#r"
        @"ufus-overviews-pills-carousel,#rufus-mobile-overviews-expandable-pills-carousel-container) :is(.nile-inline-pill-button,.nile-inline-ingress-pill-button,.a-button,[role=button],.a-"
        @"carousel-card>a){background:#4a4f51!important;background-color:#4a4f51!important;background-image:none!important;border:1px solid #34383a!important;border-color:#34383a!important;b"
        @"ox-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search :is(#rufus-overviews-pills-carousel,#rufus-mobile-overviews-expandable-pills-ca"
        @"rousel-container) :is(.nile-inline-pill-button,.nile-inline-ingress-pill-button,.a-button,[role=button],.a-carousel-card>a) .a-button-inner{background:#4a4f51!important;background-"
        @"color:#4a4f51!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#s"
        @"earch#search :is(#rufus-overviews-pills-carousel,#rufus-mobile-overviews-expandable-pills-carousel-container) :is(.nile-inline-pill-button,.nile-inline-ingress-pill-button,.a-butto"
        @"n,[role=button],.a-carousel-card>a) .a-button-text{background:transparent!important;background-color:transparent!important;background-image:none!important;border:0!important;box-sh"
        @"adow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search :is(#rufus-overviews-pills-carousel,#rufus-mobile-overviews-expandable-pills-carouse"
        @"l-container) :is(.nile-inline-pill-button,.nile-inline-ingress-pill-button,.a-button,[role=button],.a-carousel-card>a) :is(.a-button-text,span,p,strong,b,div){color:#fff!important;"
        @"-webkit-text-fill-color:#fff!important;}#search#search :is(#rufus-overviews-pills-carousel,#rufus-mobile-overviews-expandable-pills-carousel-container) :is(.nile-inline-pill-button"
        @",.nile-inline-ingress-pill-button,.a-button,[role=button],.a-carousel-card>a)::before,#search#search :is(#rufus-overviews-pills-carousel,#rufus-mobile-overviews-expandable-pills-ca"
        @"rousel-container) :is(.nile-inline-pill-button,.nile-inline-ingress-pill-button,.a-button,[role=button],.a-carousel-card>a)::after{background:transparent!important;background-color"
        @":transparent!important;background-image:none!important;box-shadow:none!important;}#search #rufus-overviews-category-cards-carousel .a-carousel-card,#search #rufus-overviews-categor"
        @"y-cards-carousel .a-carousel-card > .a-box,#search #rufus-overviews-category-cards-carousel .a-carousel-card > .a-box > .a-box-inner{background:#000!important;background-color:#000"
        @"!important;border-color:#494d4d!important;box-shadow:none!important;}#search #rufus-overviews-category-cards-carousel .a-carousel-card :is(span,a,p,strong,b,div){color:#fff!importa"
        @"nt;-webkit-text-fill-color:#fff!important;}#search#search .puis-atcb-button{background:#000!important;background-color:#000!important;border:1px solid #747a7c!important;box-shadow:"
        @"inset 0 0 0 1px #747a7c!important;filter:none!important;-webkit-filter:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#search#search .puis-atcb-b"
        @"utton .a-button-inner{background:transparent!important;background-color:transparent!important;border-color:transparent!important;box-shadow:none!important;}#search#search .puis-atc"
        @"b-button .a-button-text{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
        @"#search#search .puis-card-container .puis-variations-block{background:transparent!important;background-color:transparent!important;background-image:none!important;box-shadow:none!important;}#search#search .puis-card-container :is([data-csa-c-content-id=variation-options-link],[class*=s-variations-options-justify-content],[class*=s-variation-options-text],[class*=s-variation-options-link],.s-color-swatch-container-list-view,.puis-csi-with-label-container,.s-color-swatch-container,.s-color-swatch-outer-circle){background:transparent!important;background-color:transparent!important;background-image:none!important;box-shadow:none!important;}#search#search .puis-card-container :is([data-csa-c-content-id=variation-options-link],[class*=s-variations-options-justify-content],[class*=s-variation-options-text],[class*=s-variation-options-link],.s-color-swatch-container-list-view,.puis-csi-with-label-container,.s-color-swatch-container,.s-color-swatch-outer-circle)::before,#search#search .puis-card-container :is([data-csa-c-content-id=variation-options-link],[class*=s-variations-options-justify-content],[class*=s-variation-options-text],[class*=s-variation-options-link],.s-color-swatch-container-list-view,.puis-csi-with-label-container,.s-color-swatch-container,.s-color-swatch-outer-circle)::after{background:transparent!important;background-color:transparent!important;background-image:none!important;box-shadow:none!important;}"
        @"#search#search .puis-card-container :is(.a-button.a-button-primary,.a-button-stack>.a-button){background:#000!important;background-color:#000!important;background-image:none!important;border:1px solid #747a7c!important;border-color:#747a7c!important;box-shadow:inset 0 0 0 1px #747a7c!important;filter:none!important;-webkit-filter:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#search#search .puis-card-container :is(.a-button.a-button-primary,.a-button-stack>.a-button) .a-button-inner{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;}#search#search .puis-card-container :is(.a-button.a-button-primary,.a-button-stack>.a-button) .a-button-text{background:transparent!important;background-color:transparent!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;filter:none!important;-webkit-filter:none!important;}"
        @"#search#search .puis-status-badge-container :is(span,div,a){color:#fff!important;-webkit-text-fill-color:#fff!important;}"
        @"#search#search .puis-card-container .s-background-color-platinum{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;outline-color:transparent!important;box-shadow:none!important;color:#ffd814!important;-webkit-text-fill-color:#ffd814!important;}#search#search .puis-card-container .s-background-color-platinum::before,#search#search .puis-card-container .s-background-color-platinum::after{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;outline-color:transparent!important;box-shadow:none!important;}#search#search .puis-card-container .s-background-color-platinum :is(span,strong,b){background:transparent!important;background-color:transparent!important;color:#ffd814!important;-webkit-text-fill-color:#ffd814!important;}"
        // v7.174 probe r5: exact lime Save-% painter.
        @"#search#search .puis-card-container span.s-highlighted-text-padding.s-promotion-highlight-color{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;outline-color:transparent!important;box-shadow:none!important;color:#008000!important;-webkit-text-fill-color:#008000!important;}#search#search .puis-card-container span.s-highlighted-text-padding.s-promotion-highlight-color :is(span,a,strong,b,em){background:transparent!important;background-color:transparent!important;background-image:none!important;color:#008000!important;-webkit-text-fill-color:#008000!important;}"
        @"#search#search .puis-card-container :is(.a-color-success,[class*=saving],[class*=savings],[id*=saving],[id*=savings]):not([class*=coupon]):not(:where([class*=coupon] *)):not([class*=deal]):not(:where([class*=deal] *)):not([id^=DEAL_]):not(:where([id^=DEAL_] *)){background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;outline-color:transparent!important;box-shadow:none!important;color:#008000!important;-webkit-text-fill-color:#008000!important;}#search#search .puis-card-container :is(.a-color-success,[class*=saving],[class*=savings],[id*=saving],[id*=savings]) :is(.a-badge,.a-badge-label,.a-badge-label-inner,span,a,div,strong,b){background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;outline-color:transparent!important;box-shadow:none!important;color:#008000!important;-webkit-text-fill-color:#008000!important;}"
        @"#search#search .puis-card-container .a-badge:not([id]):not(:where(.puis-status-badge-container *)):not(:where([class*=coupon] *)):not(:where([class*=deal] *)):has(:is(.a-color-success,[class*=saving],[class*=savings],[id*=saving],[id*=savings])){background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;outline-color:transparent!important;box-shadow:none!important;color:#008000!important;-webkit-text-fill-color:#008000!important;}#search#search .puis-card-container .a-badge:not([id]):not(:where(.puis-status-badge-container *)):not(:where([class*=coupon] *)):not(:where([class*=deal] *)):has(:is(.a-color-success,[class*=saving],[class*=savings],[id*=saving],[id*=savings])) :is(.a-badge-label,.a-badge-label-inner,.a-badge-text,.a-color-success,span,a,div,strong,b){background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;outline-color:transparent!important;box-shadow:none!important;color:#008000!important;-webkit-text-fill-color:#008000!important;}"
        // v7.170: the v7.169 exact hashed class guesses did not survive the live Search renderer.
        // Keep ownership on the proven module families, but match their stable module prefixes so a hash
        // revision cannot recreate the lime Prime-Savings plate or the white multi-brand carousel shell.
        @"#search#search :is([class*=_bGlmZ_couponSns_],[class*=_bGlmZ_couponBadge_]){background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;outline-color:transparent!important;box-shadow:none!important;}#search#search [class*=_bGlmZ_couponBadge_],#search#search [class*=_bGlmZ_couponBadge_] :is(span,a,div,strong,b){background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;outline-color:transparent!important;box-shadow:none!important;color:#008000!important;-webkit-text-fill-color:#008000!important;}#search#search [class*=_bGlmZ_couponBadge_]::before,#search#search [class*=_bGlmZ_couponBadge_]::after{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;outline-color:transparent!important;box-shadow:none!important;}"

        // v7.172: the screenshot probe identifies the current More-to-explore renderer exactly as
        // .smart-refinements-content > .smart-refinements-pills > .smart-refinements-row >
        // a.smart-refinement-pill[role=button]. Retire the broad .s-widget-container button rule
        // entirely so unrelated Search/video controls cannot be painted. Keep the older proven Nile
        // lane above for the alternate renderer. The current pill retains Amazon geometry/radius,
        // receives the established header-button gray palette, and the two existing content dividers
        // are recolored to the standard neutral border without changing their width/style.
        @"#search#search .smart-refinements-content a.smart-refinement-pill[role=button]{background:#4a4f51!important;background-color:#4a4f51!important;background-image:none!important;border-color:#34383a!important;outline-color:#34383a!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;filter:none!important;-webkit-filter:none!important;}#search#search .smart-refinements-content a.smart-refinement-pill[role=button] :is(span,p,strong,b,em){background:transparent!important;background-color:transparent!important;background-image:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;filter:none!important;-webkit-filter:none!important;}#search#search .smart-refinements-content{border-top-color:#494d4d!important;border-bottom-color:#494d4d!important;}"

        // v7.171: do not clear filter on IMG/PICTURE here. v7.170 overrode the proven /s TWB owners
        // for the Brands-related _bXVsd raster/logo family. Only authored vector/icon/star art is reset.
        // Explore-key-features / multi-brand ad: own both the hashed module and the enclosing Search widget.
        // This closes the outer white plane that v7.169 missed. Raster media and blue sparkle/icon art are
        // explicitly released; only neutral floors/copy and the established Sponsored lane are themed.
        @"#search#search :is(.s-widget-container,.celwidget):has([class*=_bXVsd_]),#search#search :is(div,section,article):has(> [class*=_bXVsd_]),#search#search :is(div,section,article):has(> * > [class*=_bXVsd_]){background-color:#000!important;border-color:#494d4d!important;box-shadow:none!important;}#search#search [class*=_bXVsd_]:is(div,section,article,main,header,footer,ul,ol,li),#search#search [class*=_bXVsd_] :is(div,section,article,main,header,footer,ul,ol,li,.a-carousel-card,.a-box,.a-box-inner){background-color:#000!important;border-color:#494d4d!important;border-left-color:#000!important;border-right-color:#000!important;box-shadow:none!important;}"
        @"#search#search :is(.s-widget-container,.celwidget):has([class*=_bXVsd_]) :is(h1,h2,h3,h4,h5,h6,p,a,strong,small,b,em,label,.a-color-base,.a-color-secondary,.a-text-normal,.a-size-base,.a-size-small,.a-size-medium,span):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([class*=icon]):not([class*=star]):not([class*=sparkle]):not(:where([class*=icon] *)):not(:where([class*=star] *)):not(:where([class*=sparkle] *)){color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search :is(.s-widget-container,.celwidget):has([class*=_bXVsd_]) :is(svg,i,[class*=icon],[class*=star],[class*=sparkle]){filter:none!important;-webkit-filter:none!important;mix-blend-mode:normal!important;}"
        @"#search#search :is(.s-widget-container,.celwidget):has([class*=_bXVsd_]) :is([data-ad-feedback-label-id],[class*=ad-feedback],[class*=adFeedback],[id^=ad-feedback-text-],[id^=af-label-primary-link-]){background:transparent!important;background-color:transparent!important;background-image:none!important;color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}#search#search :is(.s-widget-container,.celwidget):has([class*=_bXVsd_]) [data-ad-feedback-label-id] b[class*=ad-feedback-sprite]{color:#b1aaa0!important;background-color:#b1aaa0!important;background-image:none!important;-webkit-mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;-webkit-mask-size:contain!important;mask-size:contain!important;-webkit-mask-repeat:no-repeat!important;mask-repeat:no-repeat!important;-webkit-mask-position:center!important;mask-position:center!important;filter:none!important;-webkit-filter:none!important;opacity:1!important;}"

        // v7.174 probe r4: exact Explore key features renderer.
        @"#search#search .s-widget-container[class*=\\\"template=PROMPTS_BENEFITS_CAROUSEL\\\"] .spt-benefits-carousel-container,#search#search .s-widget-container[class*=\\\"template=PROMPTS_BENEFITS_CAROUSEL\\\"] .spt-benefits-carousel-card,#search#search .s-widget-container[class*=\\\"template=PROMPTS_BENEFITS_CAROUSEL\\\"] .spt-benefit-chip{background:#000!important;background-color:#000!important;background-image:none!important;border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search .s-widget-container[class*=\\\"template=PROMPTS_BENEFITS_CAROUSEL\\\"] .spt-benefits-carousel-card :is(span,p,a,strong,b,em,label,div,.a-color-base,.a-color-secondary,.a-text-normal),#search#search .s-widget-container[class*=\\\"template=PROMPTS_BENEFITS_CAROUSEL\\\"] .spt-benefit-chip :is(span,p,a,strong,b,em,label,div,.a-color-base,.a-color-secondary,.a-text-normal),#search#search .s-widget-container[class*=\\\"template=PROMPTS_BENEFITS_CAROUSEL\\\"] :is(h1,h2,h3,h4,h5,h6){color:#fff!important;-webkit-text-fill-color:#fff!important;}#search#search .s-widget-container[class*=\\\"template=PROMPTS_BENEFITS_CAROUSEL\\\"] img.spt-benefit-chip-sparkle{background:transparent!important;background-color:transparent!important;filter:none!important;-webkit-filter:none!important;mix-blend-mode:normal!important;opacity:1!important;}"

        // Search APE/standalone wrapper: the creative iframe can already be dark while Amazon's main-frame
        // placement/feedback strip remains white. Own that route-local shell exactly as Home standalone does.
        @":is(.mobile-ad-container,.ape-wrapper,.ape-placement,.ape-feedback),[id^=ape_][id*=_wrapper],[id^=ape_][id*=_Feedback]{background:#000!important;background-color:#000!important;background-image:none!important;box-shadow:none!important;}:is(.ape-feedback,[id^=ape_][id*=_Feedback]) :is([data-ad-feedback-label-id],[id^=ad-feedback-text-],[id^=af-label-primary-link-],[class*=ad-feedback],[class*=adFeedback]){background:transparent!important;background-color:transparent!important;color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}"
        // v7.175 r2: exact Search medium APE shell; Sponsored feedback is a separate sibling below it.
        @"#search#search [id^=ape_search_][id$=_placement][style*='414 / 125']:not(.is-image-oo){border:1px solid #3b4043!important;border-color:#3b4043!important;outline-color:#3b4043!important;box-shadow:none!important;box-sizing:border-box!important;}"
        // v7.176: exact Search SBS filter family captured by the v7.175 screenshot probe.
        // Keep it route-local/declarative: OLED floors, light copy, dark pills, light scrollbar,
        // and a true color inversion on the authored image-glyph raster only.
        @"#search#search :is(.s-sbs-widget,.s-sbs-widget-content,.s-sbs-widget-header,.s-sbs-widget-footer,.s-sbs-refinement-bin-content,.sbs-refinement-bin-grid,.sbs-refinement-bin,.sbs-refinement-bin-header,.sbs-refinement-bin-heading-container,.sbs-refinement-bin-cell,.sbs-refinement-bin-list,.sbs-refinement-bin-list-item){background:#000!important;background-color:#000!important;background-image:none!important;border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
        @"#search#search .s-sbs-widget :is(h1,h2,h3,h4,h5,h6,p,span,a,label,strong,b,em,small,div,button):not([class*=a-icon]){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
        @"#search#search .s-sbs-widget :is(.sbs-pill,.sbs-tag-pill,.sbs-refinement-pill,.sbs-reset-filters){background:#202324!important;background-color:#202324!important;background-image:none!important;border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
        @"#search#search .s-sbs-widget :is(.sbs-pill,.sbs-tag-pill,.sbs-refinement-pill).sbs-pill--selected{background:#30383a!important;background-color:#30383a!important;border-color:#6f979d!important;outline-color:#6f979d!important;}"
        @"#search#search .s-sbs-widget .sbs-pill-image-container{background-color:#000!important;border-color:#494d4d!important;box-shadow:none!important;}"
        @"#search#search .s-sbs-widget img.sbs-pill-image{background:transparent!important;background-color:transparent!important;filter:invert(1)!important;-webkit-filter:invert(1)!important;opacity:1!important;mix-blend-mode:normal!important;}"
        @"#search#search :is(.sbs-refinement-bin,.sbs-refinement-bin-grid){color-scheme:dark!important;scrollbar-width:auto!important;-webkit-overflow-scrolling:touch!important;}"
        @".puis-mab-chevron :is(i.a-icon-dropdown,.a-icon.a-icon-dropdown),.puis-mab-chevron-glyph "
        @":is(i.a-icon-dropdown,.a-icon.a-icon-dropdown){filter:brightness(0) invert(1)!important;opacity:1!important;}#search [data-a-badge-color=\\\"sx-cloud\\\"],#search [data-a-badge-color=\\"
        @"\"sx-cloud\\\"] :is(.a-badge-label,.a-badge-label-inner,.a-badge-text){background:transparent!important;background-color:transparent!important;background-image:none!important;border-c"
        @"olor:transparent!important;box-shadow:none!important;color:#ffd814!important;-webkit-text-fill-color:#ffd814!important;}#search [data-a-badge-color=\\\"sx-cloud\\\"]::before,#search [d"
        @"ata-a-badge-color=\\\"sx-cloud\\\"]::after,#search [data-a-badge-color=\\\"sx-cloud\\\"] :is(.a-badge-label,.a-badge-label-inner)::before,#search [data-a-badge-color=\\\"sx-cloud\\\"] :is(.a-b"
        @"adge-label,.a-badge-label-inner)::after{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;b"
        @"ox-shadow:none!important;}#search .a-color-success{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!"
        @"important;box-shadow:none!important;color:#008000!important;-webkit-text-fill-color:#008000!important;}#search .a-badge[data-a-badge-type=\\\"deal\\\"]{background:transparent!important"
        @";background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#f"
        @"ff!important;}#search .a-badge[data-a-badge-type=\\\"deal\\\"]>.a-badge-label{background:#cc0c39!important;background-color:#cc0c39!important;background-image:none!important;border-col"
        @"or:#cc0c39!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search .a-badge[data-a-badge-type=\\\"deal\\\"] .a-badge-label-inner{backgr"
        @"ound:transparent!important;background-color:transparent!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}#search .puis-ad-feedback-info-icon{color:#b1aaa0!imp"
        @"ortant;-webkit-text-fill-color:#b1aaa0!important;background-color:transparent!important;}#search .puis-ad-feedback-info-icon b[class*=\\\"ad-feedback-sprite\\\"]{color:#b1aaa0!importan"
        @"t;background-color:#b1aaa0!important;filter:none!important;-webkit-filter:none!important;}#search>div,#search>section,#search>article,#search .s-main-slot>div,#search .s-main-slot>"
        @"section,#search .s-main-slot>article{background-color:#000!important;box-shadow:none!important;}#search :is(div,section,article)[class*=rufus],#sear"
        @"ch :is(div,section,article)[id*=rufus],#search :is(div,section,article)[class*=alexa],#search :is(div,section,article)[id*=alexa],#search :is(div,section,article)[class*=research],"
        @"#search :is(div,section,article)[id*=research]{background:#000!important;background-color:#000!important;border-color:#494d4d!important;box-shadow:none!important;color:#e8e6e3!impo"
        @"rtant;-webkit-text-fill-color:#e8e6e3!important;}#search .sf-rib30-panel .a-button,#search .sf-rib30-panel .a-button-inner,#search .sf-rib30-panel button{background:#202324!importa"
        @"nt;background-color:#202324!important;background-image:none!important;border-color:#747a7c!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6"
        @"e3!important;}#search .sf-rib30-panel .a-button-text{background:transparent!important;background-color:transparent!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3"
        @"!important;}#search .a-badge[data-a-badge-type=\\\"deal\\\"],#search .a-badge[data-a-badge-type=\\\"deal\\\"] *,#search .a-badge[id^=DEAL_],#search .a-badge[id^=DEAL_] *{color:#fff!importa"
        @"nt;-webkit-text-fill-color:#fff!important;}#search .mlt-icon-container :is(img,svg,i,[class*=glyph],[class*=icon]){color:#0f1111!important;fill:#0f1111!important;stroke:#0f1111!imp"
        @"ortant;filter:brightness(0)!important;-webkit-filter:brightness(0)!important;opacity:1!important;mix-blend-mode:normal!important;}#search .scx-stt-image-container{background-color:#000!i"
        @"mportant;box-shadow:none!important;}#search img.scx-stt-image{background-color:transparent!important;mix-blend-mode:"
        @"normal!important;}#search [class^=\\\"scx-stt-\\\"]:not(img),#search [class*=\\\" scx-stt-\\\"]:not(img){color:#fff!important;-webkit-text-fill-color:#fff!important;}\");}else{s=put('ad7-me"
        @"nu-theme',\"html,body,#a-page,#gwm-PageContent,#dp,main,[role=main],#cart-page,#sc-active-cart,#sc-saved-cart{background:#000!important;background-color:#000!important;}.s-main-slot"
        @",#sc-active-cart .sc-list-item,#sc-saved-cart .sc-list-item,[class*=sc-][class*=content],[class*=sc-][class*=container],#dp [class*=a-box],#dp [class*=a-expander],#dp [class*=celwi"
        @"dget]:not([class*=image]):not([class*=media]),#authportal-main-section,#auth-footer,.auth-footer,[id*=auth-footer],[class*=variation],[class*=swatch-container],[class*=status-shell"
        @"],[class*=badge-message],[class*=puis-card]:not([class*=creative]):not([class*=image]),[class*=product-card]:not([class*=image]){background-color:#181a1b!important;}[class*=suggest"
        @"ion]:not([class*=icon]):not([class*=glyph]){background:#000!important;background-color:#000!important;color:#e8e6e3!important;}#sc-active-cart .sc-list-item,#sc-saved-cart .sc-list"
        @"-item,#dp .a-box,#dp .a-divider,#dp [class*=card],#auth-footer .a-divider,.auth-footer .a-divider,[class*=swatch-outer-circle],[class*=puis-card]{border-color:#494d4d!important;out"
        @"line-color:#494d4d!important;}.a-divider-inner:after,.a-divider-inner:before,hr,[class*=separator]{border-color:#494d4d!important;background-color:#494d4d!important;}#wd-backdrop-g"
        @"radient,.wd-backdrop-gradient,[class*=wd-backdrop-gradient],[class*=a-reactive-container],[class*=reactive-contain],#auth-footer,.auth-footer,[id*=auth-footer]{background-image:non"
        @"e!important;box-shadow:none!important;}#auth-footer .a-divider-inner,.auth-footer .a-divider-inner{background-image:none!important;box-shadow:none!important;}.s-color-swatch-contai"
        @"ner,.s-color-swatch-outer-circle{background-color:transparent!important;}.s-color-swatch-outer-circle{border-color:#494d4d!important;outline-color:#494d4d!important;}[class*=nav-se"
        @"arch] img,[class*=searchbar] img,[class*=search-bar] img,[role=search] img,[class*=nav-] img[class*=icon],[class*=header] img[class*=icon]{background-color:transparent!important;}."
        @"puis-mab-overlay-row-share .puis-mab-overlay-icon-share{background-color:#e8e6e3!important;color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;filter:none!impor"
        @"tant;}:is(#gwm-PageContent,#gwm-Deck-btf) :is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf],[class*=hp-mosaic-container_style_container],[class*=_mosaic-c"
        @"ontainer_style_widgetContainer]){background-color:#000!important;border-color:#494d4d!important;mix-blend-mode:normal!important;isolation:auto!important;}.gwm-dashboard-container :"
        @"is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]){background-color:#000!important;border-color:#494d4d!important;mix-blend-mode:normal!important;isolation"
        @":auto!important;}:is(#gwm-PageContent,#gwm-Deck-btf,#gwm-Deck,.gwm-dashboard-container) :is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]) img:not([class*"
        @"=logo]):not([class*=avatar]):not([class*=profile]):not([class*=merchant]):not([class*=seller]):not([class*=brand]):not([class*=store]):not([class*=rating]):not([class*=star]):not(["
        @"class*=sprite]):not([class*=pixel]):not([class*=icon]):not([class*=glyph]):not([class*=badge]):not([class*=checkbox]):not([class*=heart]):not([class*=wishlist]):not(:where([class*="
        @"sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)){mix-blend-mode:normal!importa"
        @"nt;isolation:auto!important;background-color:transparent!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p"
        @"13n-uf]) :is(picture,[class*=image-wrapper],[class*=img-wrapper],[class*=image-container]){mix-blend-mode:normal!important;isolation:auto!important;background-color:transparent!imp"
        @"ortant;}:is(#gwm-PageContent,#gwm-Deck-btf,#gwm-Deck,.gwm-dashboard-container) :is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]) [class*=asin-metadata]{m"
        @"ix-blend-mode:normal!important;isolation:auto!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) [class*=multi-category-card] img{mix-blend-mode:normal!important;isolation:auto"
        @"!important;background-color:transparent!important;}:is(#gwm-PageContent,#gwm-Deck-btf,#gwm-Deck,.gwm-dashboard-container) [class*=badgeMessage]{background-color:transparent!importa"
        @"nt;box-shadow:none!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]) :is(h1,h2,h3,h4,h5,h6,p,span,"
        @"a):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-]):not(:where([class*=sponsored] *)):not(:"
        @"where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)):not([class*=badge]):not([class*=deal]):not([class"
        @"*=coupon]):not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=hero] *)):not(:where([class*=single-creative] *)):not(:where"
        @"([class*=single-video] *)):not(:where([class*=theming-card] *)):not(:where([class*=creative-card] *)):not(:where([class*=ad-card] *)):not(:where([class*=canvas-card] *)):not(:where"
        @"([class*=mobile-mshop-ad] *)):not(:where([class*=mobile-ad-container] *)):not(:where([class*=ape-wrapper] *)):not(:where([class*=ape-placement] *)){color:#e8e6e3!important;-webkit-"
        @"text-fill-color:#e8e6e3!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is(.a-color-base,.a-text-normal,.a-size-base,.a-size-base-plus,.a-size-medium,.a-price,.a-price-whol"
        @"e,.a-price-symbol,.a-price-fraction,.a-offscreen,[class*=product-title],[class*=product-name],[class*=item-title]):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adF"
        @"eedback]):not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-]):not([class*=badge]):not([class*=deal]):not([class*=coupon]):not(:where([class*=badge] *)):not(:where([class"
        @"*=deal]:not([class*=csm-strategy-id]) *)):not(:where([class*=coupon] *)):not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *)"
        @"):not(:where([id^=af-label-] *)):not(:where([class*=hero] *)):not(:where([class*=single-creative] *)):not(:where([class*=single-video] *)):not(:where([class*=theming-card] *)):not("
        @":where([class*=creative-card] *)):not(:where([class*=ad-card] *)):not(:where([class*=canvas-card] *)):not(:where([class*=mobile-mshop-ad] *)):not(:where([class*=mobile-ad-container"
        @"] *)):not(:where(#mobile-third-party-ad *)):not(:where([class*=ape-wrapper] *)):not(:where([class*=ape-placement] *)){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!import"
        @"ant;}:is(#gwm-Deck-btf,.gwm-dashboard-container) .a-cardui-header :is(h1,h2,h3,h4,h5,h6,a,span,p):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([id"
        @"^=ad-feedback-text-]):not([id^=af-label-primary-link-]){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) .a-cardui :is"
        @"([class*=wpTitle],[class*=windowPaneHeaderContainer]){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is(h1,h2,h3,h4"
        @",h5,h6):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([id^=ad-feedback-text-]):not([id^=af-label-primary-link-]):not(:where([class*=sponsored] *)):"
        @"not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)):not([class*=badge]):not([class*=deal]):not(["
        @"class*=coupon]):not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=hero] *)):not(:where([class*=single-creative] *)):not(:"
        @"where([class*=single-video] *)):not(:where([class*=theming-card] *)):not(:where([class*=creative-card] *)):not(:where([class*=ad-card] *)):not(:where([class*=canvas-card] *)):not(:"
        @"where([class*=mobile-mshop-ad] *)):not(:where([class*=mobile-ad-container] *)):not(:where([class*=ape-wrapper] *)):not(:where([class*=ape-placement] *)){color:#e8e6e3!important;-we"
        @"bkit-text-fill-color:#e8e6e3!important;}:is(#gwm-PageContent,#gwm-Deck-btf,.gwm-dashboard-container) :is([class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContaine"
        @"r]) :is(div,section,article,ul,ol,li,a,p,span,h1,h2,h3,h4,h5,h6):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([id^=ad-feedback-text-]):not([id^=af"
        @"-label-primary-link-]){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}:is(#gwm-PageContent,#gwm-Deck-btf,.gwm-dashboard-container) :is([class*=hp-mosaic-contain"
        @"er],[class*=_mosaic-container_style_widgetContainer]) :is([class*=next],[class*=prev],[class*=chevron],[class*=arrow]){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!impor"
        @"tant;fill:#e8e6e3!important;stroke:#e8e6e3!important;}.puis-mab-chevron :is(i.a-icon-dropdown,.a-icon.a-icon-dropdown),.puis-mab-chevron-glyph :is(i.a-icon-dropdown,.a-icon.a-icon-"
        @"dropdown){filter:brightness(0) invert(1)!important;opacity:1!important;}:is(#gwm-PageContent,#gwm-Deck,#gwm-Deck-btf,.gwm-dashboard-container) i.a-icon.a-icon-dropdown,:is(#gwm-Pag"
        @"eContent,#gwm-Deck-btf,.gwm-dashboard-container) :is([class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer],[class*=_npack-asin-card_style_theming-background"
        @"-override__]) :is([class*=next],[class*=prev],[class*=chevron],[class*=arrow]) :is(i.a-icon,.a-icon,[class*=glyph]),:is(#gwm-PageContent,#gwm-Deck-btf,.gwm-dashboard-container) :is"
        @"([class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer],[class*=_npack-asin-card_style_theming-background-override__]) :is(i.a-icon-dropdown,i[class*=chevron"
        @"],i[class*=arrow]){filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;opacity:1!important;}i.a-icon.a-icon-dropdown,.a-icon.a-icon-dropdown,i"
        @"[class*=chevron],i[class*=arrow],[class*=chevron-glyph],[class*=puis-mab-chevron] :is(i.a-icon-dropdown,.a-icon.a-icon-dropdown){filter:brightness(0) invert(1) brightness(0.91)!imp"
        @"ortant;-webkit-filter:brightness(0) invert(1) brightness(0.91)!important;opacity:1!important;visibility:visible!important;mix-blend-mode:normal!important;}:is([class*=a-cardui],[cl"
        @"ass*=npack-asin-card],[class*=gwm-asin-tile],[class*=gwm-window-layout],[class*=window-container],[class*=gwm-dashboard-container],[class*=wd-backdrop],[class*=theming-card],[class"
        @"*=a-unordered-list],[class*=mosaic-container],[class*=puis-card],[class*=gwm-tile],[class*=_container_]):not([class*=deal]):not([class*=badge]):not([class*=prime]):not([class*=erro"
        @"r]):not([class*=alert]):not([class*=warning]){border-color:#3b4043!important;outline-color:#3b4043!important;}:is([class*=hp-mosaic-container],[class*=_mosaic-container_style_widge"
        @"tContainer]) :is(div,section,article,ul,ol,li){border-color:#3b4043!important;outline-color:#3b4043!important;}[data-csa-c-painter=amazon-shopping-guides-quad-card-cards] [class*=_"
        @"colored-background_],[data-csa-c-painter=amazon-shopping-guides-quad-card-cards] [class*=_product-image_],[data-csa-c-painter=amazon-shopping-guides-quad-card-cards] [class*=_image"
        @"_]{mix-blend-mode:normal!important;isolation:auto!important;}[data-csa-c-painter=amazon-shopping-guides-quad-card-cards] [class*=_colored-background_]{background:#000!important;bac"
        @"kground-color:#000!important;border-color:#000!important;outline-color:#000!important;box-shadow:none!important;transition-property:none!important;}"
        @"picture,img,video,canvas,"
        @"#imgTagWrapperId,.s-product-image-container,[data-component-type=s-product-image],[class*=image-wrapper],[class*=img-wrapper],[class*=image-container],[class*=product-image],[class"
        @"*=asin-image]{background-color:transparent!important;}[class*=ape-wrapper],[class*=ape-placement],[class*=ape-feedback]:not(:where(#gwm-window *)):not(:where([class*=single-creativ"
        @"e-card] *)):not(:where([class*=single-video-card] *)):not([id*=mobile-wd-]){background-color:transparent!important;border-color:transparent!important;outline-color:transparent!impo"
        @"rtant;box-shadow:none!important;}iframe[id*=ape_],iframe[class*=ape_]{background-color:transparent!important;border-color:transparent!important;outline-color:transparent!important;"
        @"}.ape-wrapper[style*=\\\"--ad-height:50\\\"] > .ape-placement[style*=\\\"aspect-ratio: 320 / 50\\\"]{border-color:#3b4043!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is([class*"
        @"=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data-testid*=carousel])){background:#000!important;background-color:#000!important;border-color:#3b4043!i"
        @"mportant;outline-color:#3b4043!important;box-shadow:none!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is([class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is(["
        @"class*=carousel],[data-testid*=carousel])) :is(div,section,article,main,header,footer,ul,ol,li):not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=prime]):not("
        @":where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=prime] *)){background-color:transparent!important;}:is(#gwm-Deck-btf,.gwm-d"
        @"ashboard-container) :is([class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data-testid*=carousel])) :is(h1,h2,h3,h4,h5,h6,p,span,a,strong,small,b,em,"
        @"label):not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=prime]):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([data-testid=p"
        @"rime-badge]):not(:where([data-testid=prime-badge] *)):not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=prime] *)):not(:w"
        @"here([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}:is(#gwm-Deck-btf,.gwm-dashboard-container) :is("
        @"[class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data-testid*=carousel])) :is(span,p,a,small,strong,b)[class*=sponsored],:is(#gwm-Deck-btf,.gwm-das"
        @"hboard-container) :is([class*=mobile-mshop-ad],[class*=mobile-ad-container]):has(:is([class*=carousel],[data-testid*=carousel])) :is(span,p,a,small,strong,b)[data-testid*=sponsored"
        @"]{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}:is([class*=ad-feedback-text],[class*=ad-feedback-text-desktop],[id^=ad-feedback-text-],[id"
        @"^=af-label-primary-link-],[aria-label^=\\\"Leave feedback on Sponsored\\\"]):not(:where(#gwm-window [id^=wd-shoppable-] *)):not(:where([id*=mobile-wd-] *)):not(:where([class*=single-cr"
        @"eative-card] *)):not(:where([class*=single-video-card] *)):is(:focus,:focus-visible){outline:none!important;box-shadow:none!important;-webkit-tap-highlight-color:transparent!import"
        @"ant;}body:has([id^=adFeedbackBottomSheet_]) :is(.a-sheet-web-container,.a-sheet-web,.a-sheet-content-container),body:has([id^=adFeedbackBottomSheet_]) [class*=ad-feedback-bottom-sh"
        @"eet-container],body:has([id^=adFeedbackBottomSheet_]) :is(#af-form-top-container,#mobile-ad-feedback-container){background:#000!important;background-color:#000!important;color:#e8e"
        @"6e3!important;-webkit-text-fill-color:#e8e6e3!important;}body:has([id^=adFeedbackBottomSheet_]) :is(#af-form-top-container,#mobile-ad-feedback-container) :is(div,section,article,fo"
        @"rm,fieldset,header,footer){background-color:transparent!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}body:has([id^=adFeedbackBottomSheet_]) :is(#af-"
        @"form-top-container,#mobile-ad-feedback-container) :is(h1,h2,h3,h4,h5,h6,p,span,label,legend,small,strong,b,a){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}bod"
        @"y:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container textarea{background:#303335!important;background-color:#303335!important;color:#e8e6e3!important;-webkit-text-fill"
        @"-color:#e8e6e3!important;border-color:#6f6f6f!important;box-shadow:none!important;}body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container input[type=checkbox]{backgro"
        @"und-color:#000!important;border-color:#b1aaa0!important;accent-color:#303335!important;color-scheme:dark!important;}body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-conta"
        @"iner :is(.a-icon-checkbox,i.a-icon-checkbox){filter:invert(1)!important;-webkit-filter:invert(1)!important;opacity:1!important;}body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-fe"
        @"edback-container :is(.a-button,.a-button-inner,button,input[type=button],input[type=submit]){background:#181a1b!important;background-color:#181a1b!important;color:#e8e6e3!important"
        @";-webkit-text-fill-color:#e8e6e3!important;border-color:#6f6f6f!important;box-shadow:none!important;}body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container :is(button"
        @",input[type=button],input[type=submit]):disabled,body:has([id^=adFeedbackBottomSheet_]) #mobile-ad-feedback-container .a-button-disabled{background:#181a1b!important;background-col"
        @"or:#181a1b!important;color:#8a8a8a!important;-webkit-text-fill-color:#8a8a8a!important;border-color:#494d4d!important;}input:not([type=button]):not([type=submit]),textarea,select{b"
        @"ackground-color:#181a1b!important;color:#e8e6e3!important;border-color:#494d4d!important;}::placeholder{color:#b1aaa0!important;opacity:1!important;}[class*=header-icon],[class*=he"
        @"ader-icon] path,[class*=header-icon] use,[class*=header-link] svg path,[class*=cardui-header] svg path,a[class*=header-link] path,[class*=see-more] path,[class*=view-all] path{fill"
        @":#e8e6e3!important;stroke:#e8e6e3!important;color:#e8e6e3!important;opacity:1!important;}[class*=hp-mosaic-container] .a-icon-next-rounded,[class*=hp-mosaic-container] .a-icon-prev"
        @"ious-rounded,[class*=hp-mosaic-container] [class*=chevron],[class*=hp-mosaic-container] [class*=arrow],[class*=_mosaic-container_style_widgetContainer] .a-icon-next-rounded,[class*"
        @"=_mosaic-container_style_widgetContainer] .a-icon-previous-rounded,[class*=_mosaic-container_style_widgetContainer] [class*=chevron],[class*=_mosaic-container_style_widgetContainer"
        @"] [class*=arrow],.a-icon-next-rounded,.a-icon-previous-rounded{filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;opacity:1!important;color:#"
        @"e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;}:is([class*=_npack-asin-card_style_ad-feedback-spr],[class*=_npack-asin-card_style_ad-feedback-sprite],[class*=_cX"
        @"VhZ_ad-feedback-spr],[class*=_cXVhZ_ad-feedback-sprite],[class*=_sponsored-products-mo]):not(:where(#gwm-window [id^=wd-shoppable-] *)):not(:where([id*=mobile-wd-] *)):not(:where(["
        @"class*=single-creative-card] *)):not(:where([class*=single-video-card] *)){color:#e8e6e3!important;background-color:#e8e6e3!important;filter:none!important;-webkit-filter:none!impo"
        @"rtant;opacity:1!important;}html body [data-ad-feedback-label-id] b[class*=ad-feedback-sprite-mobile][class*=labelThemeStyle_ad-feedback-sprite-mobile]:not(:where(#gwm-window [id^=w"
        @"d-shoppable-] *)):not(:where([id*=mobile-wd-] *)):not(:where([class*=single-creative-card] *)):not(:where([class*=single-video-card] *)),html body [data-ad-feedback-label-id] b[cla"
        @"ss*=ad-feedback-sprite-mobile]:not(:where(#gwm-window [id^=wd-shoppable-] *)):not(:where([id*=mobile-wd-] *)):not(:where([class*=single-creative-card] *)):not(:where([class*=single"
        @"-video-card] *)){color:inherit!important;background-color:currentColor!important;background-image:none!important;-webkit-mask-image:url(https://m.media-amazon.com/images/G/01/ad-fe"
        @"edback/new_info_icon_3x.png)!important;mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;-webkit-mask-size:contain!important;mask-si"
        @"ze:contain!important;-webkit-mask-repeat:no-repeat!important;mask-repeat:no-repeat!important;-webkit-mask-position:center!important;mask-position:center!important;filter:none!impor"
        @"tant;-webkit-filter:none!important;opacity:1!important;}html body :is([class*=widget-sponsored-badge-container],[class*=asin-sponsored-badge-container]) [data-ad-feedback-label-id]"
        @" [class*=ad-feedback-text]{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}html body :is([class*=widget-sponsored-badge-container],[class*=as"
        @"in-sponsored-badge-container]) [data-ad-feedback-label-id] [class*=ad-feedback-text] > b[class*=ad-feedback-sprite-mobile]{color:#b1aaa0!important;background-color:#b1aaa0!importan"
        @"t;background-image:none!important;-webkit-mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;mask-image:url(https://m.media-amazon.co"
        @"m/images/G/01/ad-feedback/new_info_icon_3x.png)!important;-webkit-mask-size:contain!important;mask-size:contain!important;-webkit-mask-repeat:no-repeat!important;mask-repeat:no-rep"
        @"eat!important;-webkit-mask-position:center!important;mask-position:center!important;filter:none!important;-webkit-filter:none!important;opacity:1!important;}html body :is(.ape-feed"
        @"back,[id^=ape_][id*=\\\"_Feedback\\\"]):not(:where(#gwm-window [id^=wd-shoppable-] *)):not(:where([id*=mobile-wd-] *)):not(:where([class*=single-creative-card] *)):not(:where([class*=s"
        @"ingle-video-card] *)) [id^=ad-feedback-text-]{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}html body :is(.ape-feedback,[id^=ape_][id*=\\\"_F"
        @"eedback\\\"]):not(:where(#gwm-window [id^=wd-shoppable-] *)):not(:where([id*=mobile-wd-] *)):not(:where([class*=single-creative-card] *)):not(:where([class*=single-video-card] *)) [i"
        @"d^=ad-feedback-sprite-]{color:#b1aaa0!important;background-color:#b1aaa0!important;background-image:none!important;-webkit-mask-image:url(https://m.media-amazon.com/images/G/01/ad-"
        @"feedback/new_info_icon_3x.png)!important;mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;-webkit-mask-size:contain!important;mask-"
        @"size:contain!important;-webkit-mask-repeat:no-repeat!important;mask-repeat:no-repeat!important;-webkit-mask-position:center!important;mask-position:center!important;filter:none!imp"
        @"ortant;-webkit-filter:none!important;opacity:1!important;}[class*=_hp-mosaic-container_style_loadingSpinner]::after{background:#000!important;background-color:#000!important;box-sh"
        @"adow:none!important;}#gwm-CardLoadingIndicator.gwm-LoadingIndicator::after{background:#000!important;background-color:#000!important;box-shadow:none!important;}::-webkit-scrollbar{"
        @"background-color:transparent!important;}::-webkit-scrollbar-track{background-color:transparent!important;}::-webkit-scrollbar-thumb{background-color:#6f6f6f!important;border-radius"
        @":8px!important;border:2px solid transparent!important;background-clip:content-box!important;}::-webkit-scrollbar-thumb:hover{background-color:#8a8a8a!important;}"
        // v7.245: Cart-probe-backed first-paint ownership. Exact Cart selectors only.
        // Product/media filters are intentionally not touched here; TWB remains in ADTWBJS.
        @"#sc-page-container,#sc-page-content,#sc-buy-box,#sc-mini-buy-box,#sc-active-cart,#sc-saved-cart,#sc-page-container .sc-list-item,#sc-page-container .sc-list-item-content,#sc-page-container .swipe-item-content,#sc-page-container [class*=sc-][class*=content],#sc-page-container [class*=sc-][class*=container],#sc-page-container .a-cardui.sc-card-style,#sc-page-container .a-cardui-deck.sc-background-dark,#sc-page-container .sc-cart-overwrap,#sc-page-container .sc-undo-slide-reveal,#sc-page-container .swipe-button,#sc-page-container .sc-returns-are-easy-container,#sc-page-container .maple-banner__container,#sc-page-container .p13n-sc-shoveler,#sc-page-container .a-carousel-container.p13n-sc-shoveler{background:#000!important;background-color:#000!important;background-image:none!important;box-shadow:none!important;}#sc-page-content>*{background-color:#000!important;}#sc-buy-box *,#sc-buy-box *::before,#sc-buy-box *::after,#sc-mini-buy-box *,#sc-mini-buy-box *::before,#sc-mini-buy-box *::after{background-color:transparent!important;box-shadow:none!important;transition-property:none!important;}#sc-buy-box :not(.a-spinner):not(.a-icon),#sc-mini-buy-box :not(.a-spinner):not(.a-icon),#sc-buy-box *::before,#sc-buy-box *::after,#sc-mini-buy-box *::before,#sc-mini-buy-box *::after{background-image:none!important;}#sc-saved-cart{border-top-color:#000!important;border-bottom-color:#000!important;}#sc-page-container>.sc-cart-spinner{background:#000!important;background-color:#000!important;box-shadow:none!important;top:0!important;right:0!important;bottom:0!important;left:0!important;width:auto!important;height:auto!important;}#sc-page-container>.sc-cart-spinner>.a-spinner{background-color:transparent!important;}"
        // v7.293: Cart refresh-transition anti-flash. The current probe shows the visible
        // p13n recommendation carousel at #p13n-uf-anchor with 150x249-269 slots;
        // its hydrated cards contain .p13n-uf, while Amazon's empty slots use
        // .a-carousel-card-empty > .a-loading-static. During refresh there is a third,
        // non-empty/pre-.p13n-uf state that can briefly expose Amazon's white skeleton.
        // Own only that slot/shell at document start. Final .p13n-uf contents are untouched.
        @"#sc-page-container #p13n-uf-anchor li.a-carousel-card{background:#000!important;background-color:#000!important;background-image:none!important;box-shadow:none!important;transition:none!important;}#sc-page-container #p13n-uf-anchor li.a-carousel-card:not(.a-carousel-card-empty):not(:has(.p13n-uf))>*{background:#303335!important;background-color:#303335!important;background-image:none!important;box-shadow:none!important;transition:none!important;}"
        // v7.326: retain v7.311's saved-cart band and non-empty pre-product shell,
        // but stop its higher-specificity selectors from matching Amazon's established
        // .a-carousel-card-empty loader. v7.312 began painting the loader's inner sprite
        // host opaque gray, which hid the stock Amazon "A" restored by the v7.251 rule.
        // The explicit :not(.a-carousel-card-empty) restores the confirmed v7.280-v7.300
        // behavior without exposing the separate pre-product white shell.
        // The 430x26 #sc-saved-cart hydration band gets higher-specificity all-edge ownership.
        // The p13n pre-product lane previously styled only descendants *inside* the direct
        // temporary shell (">* :is(div,span)"), allowing that shell itself to remain white.
        // Own the direct shell dark-neutral too; hydrated .p13n-uf / real IMG states remain out.
        @"html body #sc-page-container #sc-saved-cart{background:#000!important;background-color:#000!important;background-image:none!important;border-color:#000!important;outline-color:#000!important;box-shadow:none!important;transition:none!important;}html body #sc-page-container #sc-saved-cart::before,html body #sc-page-container #sc-saved-cart::after,html body #sc-page-container #sc-saved-cart>*{background:#000!important;background-color:#000!important;background-image:none!important;border-color:#000!important;outline-color:#000!important;box-shadow:none!important;transition:none!important;}#sc-page-container #p13n-uf-anchor li.a-carousel-card:not(.a-carousel-card-empty):not(:has(.p13n-uf)):not(:has(img[src]))>*{background:#181a1b!important;background-color:#181a1b!important;background-image:none!important;border-color:#494d4d!important;box-shadow:none!important;transition:none!important;}#sc-page-container #p13n-uf-anchor li.a-carousel-card:not(.a-carousel-card-empty):not(:has(.p13n-uf)):not(:has(img[src]))>* :is(div,span){background-color:#303335!important;border-color:#494d4d!important;box-shadow:none!important;transition:none!important;}"
        // v7.251: Cart probe identifies the actual white loading boxes as Amazon's
        // li.a-carousel-card.a-carousel-card-empty > .a-loading-static (120x120),
        // not the eventual product IMG/compositor. Own that transient card directly.
        @":is(#cart-atf-recommendations,#sc-recs-atf-widget,#sc-recs-btf-widget) li.a-carousel-card.a-carousel-card-empty>.a-loading-static{background:#303335!important;background-color:#303335!important;background-image:none!important;border:1px solid #494d4d!important;border-color:#494d4d!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;transition:none!important;}:is(#cart-atf-recommendations,#sc-recs-atf-widget,#sc-recs-btf-widget) li.a-carousel-card.a-carousel-card-empty>.a-loading-static>.a-loading-static-inner{background-color:transparent!important;filter:brightness(0) invert(1) brightness(.62)!important;-webkit-filter:brightness(0) invert(1) brightness(.62)!important;opacity:.72!important;box-shadow:none!important;transition:none!important;}"
        // Match every Cart primary action, including checkout and recommendation Add-to-cart,
        // to the established Search-result Add-to-cart contract.
        @"#sc-page-container .a-button.a-button-primary{background:#000!important;background-color:#000!important;background-image:none!important;border:1px solid #747a7c!important;border-color:#747a7c!important;box-shadow:inset 0 0 0 1px #747a7c!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;filter:none!important;-webkit-filter:none!important;}#sc-page-container .a-button.a-button-primary .a-button-inner{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;filter:none!important;-webkit-filter:none!important;}#sc-page-container .a-button.a-button-primary .a-button-text,#sc-page-container .a-button.a-button-primary .sc-proceed-to-checkout-button-label{background:transparent!important;background-color:transparent!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;filter:none!important;-webkit-filter:none!important;}"
        // Cart item action controls: one medium-neutral family; preserve authored child images/logos.
        @"#sc-page-container .sc-item-actions .a-button.a-button-base{background:#303335!important;background-color:#303335!important;background-image:none!important;border:1px solid #747a7c!important;border-color:#747a7c!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#sc-page-container .sc-item-actions .a-button.a-button-base .a-button-inner{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;}#sc-page-container .sc-item-actions .a-button.a-button-base .a-button-text{background:transparent!important;background-color:transparent!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#sc-page-container .sc-item-actions .a-stepper-expanding-fieldset{background:transparent!important;background-color:transparent!important;background-image:none!important;border:0!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#sc-page-container .sc-item-actions .a-stepper-inner-container,#sc-page-container .sc-item-actions .a-input-text-addon,#sc-page-container .sc-item-actions .a-input-text-wrapper.sc-quantity-textfield{background:#303335!important;background-color:#303335!important;background-image:none!important;border-color:#747a7c!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#sc-page-container .sc-item-actions .a-stepper-inner-container{border:1px solid #747a7c!important;}#sc-page-container .sc-item-actions .a-stepper-controls,#sc-page-container .sc-item-actions .a-stepper-controls :is(span,div,button),#sc-page-container .sc-item-actions .a-input-text-wrapper.sc-quantity-textfield input{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#sc-page-container .sc-item-actions :is(.a-icon-small-trash,.a-icon-small-add){filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;}"
        // Probe-captured Cart primary text. Saturated authored accents stay on their own direct classes.
        @"#sc-buy-box :is(h3,#sc-subtotal-label-buybox,#sc-subtotal-label,#sc-subtotal-amount-buybox,#sc-subtotal-amount,#sc-subtotal-amount .a-price,#sc-subtotal-amount .a-price-whole,#sc-subtotal-amount .a-price-symbol,#sc-subtotal-amount .a-price-fraction),#sc-gift .a-checkbox-label,#sc-active-cart .sc-list-item .sc-product-title h3,#sc-active-cart .sc-list-item .sc-product-title .a-truncate,#sc-active-cart .sc-list-item .a-col-right,#sc-active-cart .sc-list-item .sc-delivery-messaging,#sc-active-cart .sc-list-item .udm-primary-delivery-message,#sc-active-cart .sc-list-item #cart-return-policy-message{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#sc-active-cart .sc-list-item :is(.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.sc-product-price){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#sc-page-container :is(h1,h2,h3,h4,h5,h6,.a-color-base,.a-text-normal):not(:where(a *)):not(.a-color-secondary):not(.a-color-success):not(.a-color-price):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=prime] *)){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
        // Returns and Prime Business rows: black floors, light primary text, preserve link blue/secondary hierarchy.
        @"#sc-page-container .sc-returns-are-easy-container :is(h1,h2,h3,h4,h5,h6,p,.a-color-base){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#sc-page-container #sc-upsell .maple-banner__text,#sc-page-container #sc-upsell .maple-banner__text strong{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#sc-page-container #sc-upsell .maple-banner__text .a-color-secondary{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;}#sc-page-container #sc-upsell .maple-banner__text .a-color-link{color:rgb(33,98,161)!important;-webkit-text-fill-color:rgb(33,98,161)!important;}"
        // Recommendation shells and the exact section heading only. Product title blue, star orange,
        // price red, success green and Prime blue remain Amazon-authored.
        @"#cart-atf-recommendations,#sc-recs-atf-widget,#sc-recs-btf-widget,#cart-atf-recommendations .a-cardui-deck,#cart-atf-recommendations .a-cardui,#sc-recs-atf-widget .a-cardui-deck,#sc-recs-atf-widget .a-cardui,#sc-recs-btf-widget .a-cardui-deck,#sc-recs-btf-widget .a-cardui,#cart-atf-recommendations .p13n-sc-shoveler,#sc-recs-atf-widget .p13n-sc-shoveler,#sc-recs-btf-widget .p13n-sc-shoveler{background:#000!important;background-color:#000!important;background-image:none!important;box-shadow:none!important;}#cart-atf-recommendations .p13n-flex-container-edit-recs-bottom-sheet>h2.a-size-medium,#sc-recs-atf-widget .p13n-flex-container-edit-recs-bottom-sheet>h2.a-size-medium,#sc-recs-btf-widget .p13n-flex-container-edit-recs-bottom-sheet>h2.a-size-medium{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
        // v7.252 Cart probe: the recommendation delivery/history lane adjacent to Prime is
        // span.a-size-mini.a-color-base and is stock near-black. Recolor only that neutral
        // base lane; authored Prime blue, prices, stars, links, success/deal colors remain untouched.
        @":is(#cart-atf-recommendations,#sc-recs-atf-widget,#sc-recs-btf-widget) .p13n-sc-uncoverable-faceout span.a-size-mini.a-color-base{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}:is(#cart-atf-recommendations,#sc-recs-atf-widget,#sc-recs-btf-widget) .p13n-sc-uncoverable-faceout span.a-size-mini.a-color-base>b{color:inherit!important;-webkit-text-fill-color:inherit!important;}"
        // v7.253 Cart probe: exact remaining control/sheet owners.
        // Undo and Clip-to-Save join the existing medium-neutral Cart action family.
        @"#sc-page-container .sc-list-item-removed-msg .sc-undo-delete-btn,#sc-page-container .sc-clipcoupon-container .sc-coupon-wrapper>.a-button.a-button-base{background:#303335!important;background-color:#303335!important;background-image:none!important;border:1px solid #747a7c!important;border-color:#747a7c!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#sc-page-container .sc-list-item-removed-msg .sc-undo-delete-btn>.a-button-inner,#sc-page-container .sc-clipcoupon-container .sc-coupon-wrapper>.a-button.a-button-base>.a-button-inner{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;}#sc-page-container .sc-list-item-removed-msg .sc-undo-delete-btn .a-button-text,#sc-page-container .sc-clipcoupon-container .sc-coupon-wrapper>.a-button.a-button-base .a-button-text{background:transparent!important;background-color:transparent!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
        // Subscribe & Save: own only the surrounding Cart card. The switch itself keeps Amazon's
        // probe-captured stock OFF gray and ON blue states, with the stock white thumb.
        @"#sc-page-container .sns-mobile-cart-improvements-container>.a-box{background:#303335!important;background-color:#303335!important;background-image:none!important;border:1px solid #747a7c!important;border-color:#747a7c!important;box-shadow:none!important;}#sc-page-container .sns-mobile-cart-improvements-container>.a-box>.a-box-inner{background:transparent!important;background-color:transparent!important;background-image:none!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#sc-page-container .sns-mobile-cart-improvements-container .a-switch-row:not(.a-active) .a-switch{background:rgb(136,140,140)!important;background-color:rgb(136,140,140)!important;border-color:rgb(136,140,140)!important;box-shadow:none!important;}#sc-page-container .sns-mobile-cart-improvements-container .a-switch-row.a-active .a-switch{background:rgb(33,98,161)!important;background-color:rgb(33,98,161)!important;border-color:rgb(33,98,161)!important;box-shadow:none!important;}#sc-page-container .sns-mobile-cart-improvements-container .a-switch-control{background:#fff!important;background-color:#fff!important;box-shadow:none!important;}"
        // The quantity decrement is the sprite-backed a-icon-small-remove leaf. It needs the same
        // white sprite transform already applied to a-icon-small-add.
        @"#sc-page-container .sc-item-actions .a-icon-small-remove{filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;opacity:1!important;}"
        // Long-press recommendation sheet: the probe proves this is an AUI/WebKit a-sheet, not the
        // native AppCX bottom sheet. Own only the p13n Cart sheet floor and action buttons.
        @"body:has(#sc-page-container) .a-sheet-web:has([id^=p13n-uf-bottom-sheet_]),body:has(#sc-page-container) .a-sheet-web:has([id^=p13n-uf-bottom-sheet_])>.a-sheet-content-container{background:#000!important;background-color:#000!important;background-image:none!important;box-shadow:none!important;}body:has(#sc-page-container) .a-sheet-web [id^=p13n-uf-bottom-sheet_],body:has(#sc-page-container) .a-sheet-web [id^=p13n-uf-bottom-sheet_] :is(div,section,ul,li){background-color:transparent!important;background-image:none!important;box-shadow:none!important;}body:has(#sc-page-container) .a-sheet-web [id^=p13n-uf-bottom-sheet_] .p13n-uf-action-options,body:has(#sc-page-container) .a-sheet-web [id^=p13n-uf-bottom-sheet_] :is(.p13n-uf-undo-record-feedback,.p13n-uf-reasons-option){background:#000!important;background-color:#000!important;background-image:none!important;border:1px solid #747a7c!important;border-color:#747a7c!important;box-shadow:inset 0 0 0 1px #747a7c!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;filter:none!important;-webkit-filter:none!important;}body:has(#sc-page-container) .a-sheet-web [id^=p13n-uf-bottom-sheet_] .p13n-uf-action-options .a-button-inner,body:has(#sc-page-container) .a-sheet-web [id^=p13n-uf-bottom-sheet_] :is(.p13n-uf-undo-record-feedback,.p13n-uf-reasons-option) .a-button-inner{background:transparent!important;background-color:transparent!important;background-image:none!important;border-color:transparent!important;box-shadow:none!important;}body:has(#sc-page-container) .a-sheet-web [id^=p13n-uf-bottom-sheet_] .p13n-uf-action-options .a-button-text,body:has(#sc-page-container) .a-sheet-web [id^=p13n-uf-bottom-sheet_] :is(.p13n-uf-undo-record-feedback,.p13n-uf-reasons-option) .a-button-text{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;background:transparent!important;background-color:transparent!important;}body:has(#sc-page-container) .a-sheet-web [id^=p13n-uf-bottom-sheet_] .p13n-uf-bottom-sheet-faceout a,body:has(#sc-page-container) .a-sheet-web [id^=p13n-uf-bottom-sheet_] .p13n-uf-bottom-sheet-faceout a *{color:rgb(33,98,161)!important;-webkit-text-fill-color:rgb(33,98,161)!important;}"

        // v7.294: the Cart probe shows the Saved-for-later swipe-right reveal action
        // still carries stock rgb(17,17,17) text on our black swipe floor. The normal
        // Move-to-cart AUI button is already light; own only the separate swipe-right label.
        @"#sc-page-container form#savedCartViewForm .sc-list-item .swipe-button.swipe-right-button,#sc-page-container form#savedCartViewForm .sc-list-item .swipe-button.swipe-right-button>div{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
        // v7.255: finish Cart neutral text ownership without flattening Amazon-authored accents.
        // Saved-for-later and the newer _sp-cart-mobile-carousel renderer expose separate
        // stock-black lanes that were outside the earlier p13n selectors. Dynamic success,
        // link, deal, price-accent and Prime colors are explicitly left to Amazon.
        @"#sc-saved-cart .sc-list-item .sc-product-title :is(span,h1,h2,h3,h4,h5,h6),#sc-saved-cart .sc-list-item .sc-apex-cart-price :is(.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-price-decimal,.apex-price-to-pay-value),#sc-saved-cart .sc-list-item .sc-delivery-messaging,#sc-saved-cart .sc-list-item .sc-delivery-messaging :is(span,div,b,strong){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#sc-saved-cart .sc-list-item .a-color-success,#sc-saved-cart .sc-list-item .a-color-success *{color:rgb(11,123,60)!important;-webkit-text-fill-color:rgb(11,123,60)!important;}#sc-saved-cart .sc-list-item #howToReturn.sc-free-returns-bottomSheetTrigger,#sc-saved-cart .sc-list-item #howToReturn.sc-free-returns-bottomSheetTrigger *{color:rgb(33,98,161)!important;-webkit-text-fill-color:rgb(33,98,161)!important;}#sc-page-container [class*=_sp-cart-mobile-carousel_style_spMobileCarousel__] .sp-mobile-faceout .a-row.a-size-small.a-color-base:not(:has(.a-icon-prime)),#sc-page-container [class*=_sp-cart-mobile-carousel_style_spMobileCarousel__] .sp-mobile-faceout .a-row.a-size-small.a-color-base:not(:has(.a-icon-prime)) :is(span,b,strong,div),#sc-page-container [class*=_sp-cart-mobile-carousel_style_spMobileCarousel__] .sp-mobile-faceout .a-size-small.a-color-secondary,#sc-page-container [class*=_sp-cart-mobile-carousel_style_spMobileCarousel__] .sp-mobile-faceout .a-size-small.a-color-secondary :is(span,b,strong,div),#sc-page-container [class*=_sp-cart-mobile-carousel_style_spMobileCarousel__] .sp-mobile-faceout .udm-badge-block .a-icon-text,#sc-page-container [class*=_sp-cart-mobile-carousel_style_spMobileCarousel__] .sp-mobile-faceout .udm-badge-block .a-text-bold{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}#sc-page-container [class*=_sp-cart-mobile-carousel_style_spMobileCarousel__] .sp-mobile-faceout .a-price:not(:where(.a-color-price *)),#sc-page-container [class*=_sp-cart-mobile-carousel_style_spMobileCarousel__] .sp-mobile-faceout .a-price:not(:where(.a-color-price *)) :is(.a-price-whole,.a-price-symbol,.a-price-fraction,.a-price-decimal){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
        // Active Cart delivery accents: the broad primary-text rule intentionally owns the
        // surrounding sentence, but these exact Amazon semantic leaves must keep their stock
        // success green / returns-link blue rather than inheriting our light text-fill.
        @"#sc-active-cart .sc-list-item .a-color-success,#sc-active-cart .sc-list-item .a-color-success *{color:rgb(11,123,60)!important;-webkit-text-fill-color:rgb(11,123,60)!important;}#sc-active-cart .sc-list-item #howToReturn.sc-free-returns-bottomSheetTrigger,#sc-active-cart .sc-list-item #howToReturn.sc-free-returns-bottomSheetTrigger *{color:rgb(33,98,161)!important;-webkit-text-fill-color:rgb(33,98,161)!important;}"
        // Cart Share sheet (SSF): exact AUI web sheet captured by the v7.254 Cart probe.
        // Floors go OLED, neutral black copy becomes light, blue/dynamic authored colors stay
        // untouched, and the preview/channel imagery is handled by TWB below.
        @"body:has(#sc-page-container) .a-sheet-web:has(.ssf-customize-container-one),body:has(#sc-page-container) .a-sheet-web:has(.ssf-customize-container-one) .a-sheet-content-container,body:has(#sc-page-container) .a-sheet-web:has(.ssf-customize-container-one) .a-sheet-heading-container,body:has(#sc-page-container) .a-sheet-web:has(.ssf-customize-container-one) .ssf-customize-container-one,body:has(#sc-page-container) .a-sheet-web:has(.ssf-customize-container-one) .ssf-two-row-custom-channels-container,body:has(#sc-page-container) .a-sheet-web:has(.ssf-customize-container-one) .a-padding-base:not(#ssf-preview-container),body:has(#sc-page-container) .a-sheet-web:has(.ssf-customize-container-one) .ssf-product-title-text{background:#000!important;background-color:#000!important;background-image:none!important;box-shadow:none!important;}body:has(#sc-page-container) .a-sheet-web:has(.ssf-customize-container-one) .ssf-preview-box{background:#000!important;background-color:#000!important;border-color:#747a7c!important;box-shadow:none!important;}body:has(#sc-page-container) .a-sheet-web:has(.ssf-customize-container-one) :is(.a-sheet-heading,#ssf-title-label,.ssf-product-title-text,.ssf-custom-share-option .label,h1,h2,h3,h4,h5,h6){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"

        // v7.268: the current Home probe shows Amazon owns two separate hero-derived color
        // planes. #wd-backdrop-overscroll is the pull-past-top plane, while
        // #wd-color-image-backdrop is the large flat average-color surface exposed when the
        // Home window/hero area extends beyond the active card. Both are decorative backdrops,
        // not hero artwork, so lock both to OLED black without touching hero images/video/cards.
        @"#wd-backdrop-overscroll,.wd-backdrop-overscroll,#wd-color-image-backdrop,.wd-color-image-backdrop{background:#000!important;background-color:#000!important;background-image:none!important;box-shadow:none!important;}"

        // v7.269: current Home probe proof shows the 414x125 structured renderer already
        // owns the correct rounded gray edge on modern-414x125-layout-container. The outer
        // APE placement is duplicate renderer chrome, so keep that parent frameless too.
        // Structurally proven full-raster hosts remain frameless through the existing path.
        @".ape-placement.is-image-oo,[id^=ape_][id*=\\\"_placement\\\"].is-image-oo,[id^=ape_gateway_dynamic-][id$=_mshop_placement].is-image-oo,[data-ad7266-full-raster-host=\\\"1\\\"]{border:0!important;border-width:0!important;border-color:transparent!important;outline:0!important;outline-width:0!important;box-shadow:none!important;}.ape-placement.is-image-oo>iframe,[id^=ape_][id*=\\\"_placement\\\"].is-image-oo>iframe,[id^=ape_gateway_dynamic-][id$=_mshop_placement].is-image-oo>iframe,iframe[data-ad7266-full-raster-host=\\\"1\\\"]{border:0!important;border-width:0!important;border-color:transparent!important;outline:0!important;box-shadow:none!important;}[id^=ape_gateway_dynamic-][id$=_mshop_placement][style*=\\\"414 / 125\\\"]:not(.is-image-oo):not([data-ad7266-full-raster-host=\\\"1\\\"]){border:0!important;border-width:0!important;border-color:transparent!important;outline:0!important;outline-width:0!important;box-shadow:none!important;box-sizing:border-box!important;}"

        // The historical 430x2 DIV.border-enforcement is renderer chrome, not raster
        // content. Setting only its color black was insufficient on the live medium
        // creative because the authored 1px border still participates in paint. Remove
        // the border entirely and leave its structural strip OLED black.
        @"html[data-ad7-child-frame] .border-enforcement,html[data-ad7-child-frame] .border-enforcement::before,html[data-ad7-child-frame] .border-enforcement::after{display:none!important;content:none!important;background:#000!important;background-color:#000!important;border:0!important;border-width:0!important;border-color:transparent!important;outline:0!important;outline-width:0!important;box-shadow:none!important;height:0!important;min-height:0!important;max-height:0!important;margin:0!important;padding:0!important;overflow:hidden!important;}"
        // v7.268: the XL/300x250 full-raster APE renderer captured by the Home probe lives
        // directly in the main Home document (no child iframe), so the child-frame rule above
        // cannot reach its identical 430x2 #ccc DIV.border-enforcement. The raster-only renderer
        // shape is structurally proven by creative-container owning a direct
        // IMG.ad-background-image.mrc-btr-creative. Remove only that renderer chrome.
        @":is(#gwm-Deck,#gwm-Deck-atf,#gwm-Deck-btf,.gwm-dashboard-container) .creative-container:has(>img.ad-background-image.mrc-btr-creative) .border-enforcement,:is(#gwm-Deck,#gwm-Deck-atf,#gwm-Deck-btf,.gwm-dashboard-container) .creative-container:has(>img.ad-background-image.mrc-btr-creative) .border-enforcement::before,:is(#gwm-Deck,#gwm-Deck-atf,#gwm-Deck-btf,.gwm-dashboard-container) .creative-container:has(>img.ad-background-image.mrc-btr-creative) .border-enforcement::after{display:none!important;content:none!important;background:#000!important;background-color:#000!important;border:0!important;border-width:0!important;border-color:transparent!important;outline:0!important;outline-width:0!important;box-shadow:none!important;height:0!important;min-height:0!important;max-height:0!important;margin:0!important;padding:0!important;overflow:hidden!important;}"

        // v7.169: /s product-referrer ad iframes are child frames but intentionally are not
        // standalone-candidates. Reuse the proven Home 414x125 renderer contract by exact
        // renderer identity, without touching layout/geometry or unrelated child frames.
        @"html[data-ad7-child-frame] [data-testid=renderer-factory-ad-container],html[data-ad7-child-frame] [data-testid=renderer-factory-ad-container] :is([data-testid=main-content],[data-testid=content],[data-testid^=modern-][data-testid$=-layout-container]){background:#000!important;background-color:#000!important;background-image:none!important;border-color:#3b4043!important;outline-color:#3b4043!important;box-shadow:none!important;}html[data-ad7-child-frame] [data-testid=renderer-factory-ad-container] :is(div,section,article,main,header,footer):not([class*=badge]):not([class*=deal]):not([class*=coupon]):not([class*=prime]):not([class*=star]):not(:where([class*=badge] *)):not(:where([class*=deal] *)):not(:where([class*=coupon] *)):not(:where([class*=prime] *)):not(:where([class*=star] *)){background-color:transparent!important;box-shadow:none!important;}html[data-ad7-child-frame] [data-testid=renderer-factory-ad-container] :is([data-id=brand-name-text],[data-id=product-name-text],[data-testid=ratings-value],[data-testid=formatted-price],[data-testid=formatted-price] *,.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen),html[data-ad7-child-frame] [data-testid=renderer-factory-ad-container] [data-testid=price-container] :is(div,span):not([data-testid=full-price]):not([data-testid=prime-badge]):not(:where([data-testid=prime-badge] *)){color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}html[data-ad7-child-frame] [data-testid=renderer-factory-ad-container] :is([data-testid=ratings-review-count],[data-testid=full-price]){color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;}html[data-ad7-child-frame] [data-testid=renderer-factory-ad-container] :is([data-ad-feedback-label-id],[class*=ad-feedback],[class*=adFeedback],[class*=sponsored],[data-testid*=sponsored],[id^=ad-feedback-text-],[id^=af-label-primary-link-]){background-color:transparent!important;color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;opacity:1!important;}html[data-ad7-child-frame] [data-testid=renderer-factory-ad-container] :is([data-ad-feedback-label-id] b[class*=ad-feedback-sprite],b[class*=ad-feedback-sprite-mobile],[id^=ad-feedback-sprite-]){color:#b1aaa0!important;background-color:#b1aaa0!important;background-image:none!important;-webkit-mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;mask-image:url(https://m.media-amazon.com/images/G/01/ad-feedback/new_info_icon_3x.png)!important;-webkit-mask-size:contain!important;mask-size:contain!important;-webkit-mask-repeat:no-repeat!important;mask-repeat:no-repeat!important;-webkit-mask-position:center!important;mask-position:center!important;filter:none!important;-webkit-filter:none!important;opacity:1!important;}"
        @"\");}if(document.rea"
        @"dyState==='loading')window.addEventListener('load',function(){relink(s);rootBlack();},{once:true});else relink(s);rootBlack();}catch(e){}})();";
}

// v7.191: cache the large strength-dependent TWB payloads. They are identical
// for every WKUserContentController at a given preference value and are rebuilt
// automatically only when Tame Light Background strength changes.
static long gADStandaloneJSStrength7191=-1;
static NSString *gADStandaloneJSCached7191=nil;
static long gADTWBJSStrength7191=-1;
static NSString *gADTWBJSCached7191=nil;

static NSString *ADStandalonePaintJS7104(void){
    long strengthKey=MAX(0,MIN(100,gP.whiteTameStrength));
    if(gADStandaloneJSCached7191 && gADStandaloneJSStrength7191==strengthKey) return gADStandaloneJSCached7191;
    CGFloat strength=(CGFloat)strengthKey;
    CGFloat t=strength/100.0;
    CGFloat shade=0.10+(0.48*t);
    CGFloat factor=1.0-shade;
    NSString *built=[NSString stringWithFormat:
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
         /* v7.266: restore the established gray edge for structured medium/large
          * standalone renderers. A structurally proven full-raster frame opts out below. */
         "html[data-ad7104-standalone]:not([data-ad7144-full-raster-frame]) [data-testid=renderer-factory-ad-container] [data-testid^=modern-][data-testid$=-layout-container],"
         "html[data-ad7104-standalone]:not([data-ad7144-full-raster-frame]) [data-testid=ad-background-container]"
         "{border-color:#3b4043!important;outline-color:#3b4043!important;}"
         /* v7.266: full-raster standalone frames are frameless. Exact full-raster
          * child frames are marked by the bounded dominant-raster classifier below;
          * remove renderer/container chrome only after that structural proof exists. */
         "html[data-ad7104-standalone][data-ad7144-full-raster-frame] [data-testid=renderer-factory-ad-container],"
         "html[data-ad7104-standalone][data-ad7144-full-raster-frame] [data-testid=renderer-factory-ad-container] [data-testid^=modern-][data-testid$=-layout-container],"
         "html[data-ad7104-standalone][data-ad7144-full-raster-frame] [data-testid=ad-background-container],"
         "html[data-ad7104-standalone][data-ad7144-full-raster-frame] .creative-container,"
         "html[data-ad7104-standalone][data-ad7144-full-raster-frame] :is(html,body,#ad,div,section,article,main,figure,picture)"
         "{border:0!important;border-width:0!important;border-color:transparent!important;outline:0!important;outline-width:0!important;box-shadow:none!important;}"
         /* Medium full-raster separator is renderer chrome, never raster content. */
         "html[data-ad7104-standalone] .border-enforcement,"
         "html[data-ad7104-standalone] .border-enforcement::before,"
         "html[data-ad7104-standalone] .border-enforcement::after"
         "{display:none!important;content:none!important;background:#000!important;background-color:#000!important;border:0!important;border-width:0!important;border-color:transparent!important;outline:0!important;outline-width:0!important;box-shadow:none!important;height:0!important;min-height:0!important;max-height:0!important;margin:0!important;padding:0!important;overflow:hidden!important;}"
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
         /* v7.268: the compact structured renderer does not expose the medium/large
          * price-container/testid contract. The live probe shows its current price is
          * instead the exact data-acei-id=prc lane, with symbolOne/price-integer/
          * price-fraction carrying authored rgb(15,17,17) inline color. Own only those
          * three current-price leaves; discount red and struck list-price gray are siblings. */
         "html[data-ad7104-standalone] #dynamic-bb [data-acei-id=prc] > :is(#symbolOne,#price-integer,#price-fraction)"
         "{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}"
         "html[data-ad7104-standalone] #dynamic-bb [data-acei-id=sns-disc]"
         "{color:#b1aaa0!important;-webkit-text-fill-color:#b1aaa0!important;}"
         /* 414x125 + large primary neutral copy. */
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container] "
         ":is([data-id=brand-name-text],[data-id=product-name-text],[data-testid=ratings-value],[data-testid=formatted-price],[data-testid=formatted-price] *,.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen),"
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
         /* v7.190: probe-proven Home hero state parity. The same Video.js hero keeps
          * VIDEO.vjs-tech at brightness(factor) in both carousel states; off-center/paused
          * shows vjs-poster over it, while front/playing hides the poster. Give both visual
          * surfaces the exact same TWB factor instead of clearing background paint by raster presence. */
         "html[data-ad7104-standalone] :is(img,video,canvas)"
         ":not([class*=logo]):not([class*=avatar]):not([class*=profile]):not([class*=merchant]):not([class*=seller])"
         ":not([class*=prime]):not([class*=rating]):not([class*=star]):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback])"
         ":not([class*=icon]):not([class*=glyph]):not([class*=sprite]):not([class*=pixel]):not([class*=badge]):not([class*=chevron]):not([class*=arrow])"
         ":not(:where([class*=logo] *)):not(:where([class*=prime] *)):not(:where([class*=rating] *)):not(:where([class*=star] *)):not(:where([class*=badge] *))"
         ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *))"
         ":not(:where([data-testid*=logo] *)):not(:where([data-testid=prime-badge] *)):not(:where([data-testid=ratings-stars] *)):not(:where([data-ad-feedback-label-id] *))"
         "{filter:brightness(%.4f)!important;-webkit-filter:brightness(%.4f)!important;transition:none!important;}"
         /* Keep declarative preload/background coverage for static creative artwork. */
         "html[data-ad7104-standalone] :is(div,section,article,main):is([style*=background-image],[style*=backgroundImage])"
         ":not([class*=logo]):not([class*=prime]):not([class*=rating]):not([class*=star]):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback])"
         ":not([class*=icon]):not([class*=glyph]):not([class*=sprite]):not([class*=pixel]):not([class*=badge]):not([class*=chevron]):not([class*=arrow])"
         ":not(:where([class*=logo] *)):not(:where([class*=prime] *)):not(:where([class*=rating] *)):not(:where([class*=star] *)):not(:where([class*=badge] *))"
         ":not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([data-ad-feedback-label-id] *))"
         "{box-shadow:inset 0 0 0 9999px rgba(0,0,0,%.3f)!important;transition-property:none!important;}"
         /* Video.js poster is the visible paused/off-center hero surface. Use brightness, not
          * an additional shadow, so poster -> playing VIDEO is a one-factor-to-one-factor swap. */
         "html[data-ad7104-standalone] .video-js .vjs-poster[style*=background-image],"
         "html[data-ad7104-standalone] .vjs-poster.vjs-poster[style*=background-image]"
         "{box-shadow:none!important;filter:brightness(%.4f)!important;-webkit-filter:brightness(%.4f)!important;transition:none!important;}"
         /* Preserve current TWB strength on the exact standalone product-raster lanes even
          * if Amazon's shell replacement deletes the global TWB sheet. */
         "html[data-ad7104-standalone] [data-testid=renderer-factory-ad-container] "
         "[data-testid=image] :is(img,video,canvas),"
         "html[data-ad7104-standalone] :is([data-testid*=product-picture],[data-testid*=product-image],[data-testid*=asin-image]) :is(img,video,canvas),"
         /* Current v7.267/v7.268 frame probes identify the compact 320x50 product
          * raster exactly as data-acei-id=prod-img under #dynamic-bb. Keep this one
          * renderer owner only; no host-independent media sweep or legacy lane. */
         "html[data-ad7104-standalone] #ad:has(#dynamic-bb) [data-acei-id=prod-img] :is(img,video,canvas),"
         /* v7.114: store/brand identity raster parity. Repeated device captures
          * expose the store image as data-acei-id=brnd-logo -> IMG alt=Brand logo
          * (with data-testid=logo as the renderer wrapper on 414x125). Add only
          * this exact standalone identity lane to TWB; do not widen the generic
          * logo exclusions that protect Prime, stars, badges and UI glyphs. */
         "html[data-ad7104-standalone] [data-acei-id=brnd-logo] img,"
         "html[data-ad7104-standalone] [data-testid=logo] img[alt=\"Brand logo\"],"
         /* v7.309: current XL/large 430x358 standalone probe exposes the authored
          * company identity raster as data-testid=simple-brand-logo-picture -> IMG.
          * Extend only the existing standalone brand-identity TWB lane. */
         "html[data-ad7104-standalone] [data-testid=simple-brand-logo-picture] img"
         "{filter:brightness(%.4f)!important;-webkit-filter:brightness(%.4f)!important;}"
         /* v7.108: exact first-party 300x250 Swiper carousel media. Both the
          * active product tile and the neighboring custom-image tile expose the
          * actual raster as data-testid=pictureHighQuality. Tame only those leaves,
          * which keeps Prime blue, orange rating stars, unrelated logos/badges and glyphs at
          * their authored colors/intensity. */
         "html[data-ad7104-standalone] #ad[data-html-dimensions=\"300x250\"] "
         ".swiper-slide [data-testid=pictureHighQuality]"
         "{filter:brightness(%.4f)!important;-webkit-filter:brightness(%.4f)!important;}"
         /* v7.170 addendum: compact standalone complete-raster creative. The live
          * banner is a single authored raster, so there is no product-image leaf to target.
          * The bounded classifier below marks only the dominant media/background inside a
          * short, wide standalone child frame; the separate Sponsored feedback row is not
          * inside that child and is therefore never filtered. */
         "[data-ad7144-full-raster=\"1\"]"
         "{filter:brightness(%.4f)!important;-webkit-filter:brightness(%.4f)!important;}"
         "[data-ad7144-full-raster-bg=\"1\"]"
         "{background-color:rgba(0,0,0,%.3f)!important;background-blend-mode:multiply!important;}"
         /* v7.135: do not filter the entire #mobile-third-party-ad subtree.
          * Current AT&T video keeps the 430x358 APE SafeFrame mounted but paints black;
          * whole-subtree CSS filter ownership is removed so WebKit can composite the
          * nested third-party video/iframe natively. */
         "';"
         /* v7.170 addendum: port the proven v7.144 dominant-raster classifier into the
          * standalone survivor path, because current ADTWBJS intentionally exits early
          * for standalone-candidate child frames. Use stricter dominant-raster coverage outside compact frames and reject proven
          * structured product-ad semantics before declaring a medium/large frame full-raster. */
         "function ad7144VisibleRect(e){try{var r=e.getBoundingClientRect(),cs=getComputedStyle(e);if(r.width<2||r.height<2||cs.display==='none'||cs.visibility==='hidden'||parseFloat(cs.opacity||'1')<.02)return null;return r}catch(_){return null}}"
         "function ad7144MediaKind(e){try{var t=(e.tagName||'').toLowerCase();if(t==='img'||t==='video'||t==='canvas')return t;var bg=getComputedStyle(e).backgroundImage||'none';return bg&&bg!=='none'?'background':''}catch(_){return ''}}"
         "function ad7144Pick(root,rr){try{if(!root||!rr)return null;var best=null,score=0,all=root.getElementsByTagName('*'),ad=document.getElementById('ad'),is300=!!(ad&&ad.getAttribute('data-html-dimensions')==='300x250'),compact=rr.height<=180,minW=compact?0.76:0.88,minH=compact?0.60:0.80,minA=compact?0.56:0.72;for(var i=0;i<all.length;i++){var e=all[i],tid=e.getAttribute&&e.getAttribute('data-testid')||'',did=e.getAttribute&&e.getAttribute('data-id')||'',ace=e.getAttribute&&e.getAttribute('data-acei-id')||'';if(e.id==='dynamic-bb'||tid==='ratings-stars'||tid==='prime-badge'||tid==='price-container'||tid==='formatted-price'||tid==='ratings-review-count'||tid==='brand-product-description'||tid==='product-description'||tid==='deal-badge'||did==='brand-name-text'||did==='product-name-text'||ace==='brnd-logo'||ace==='prod-img'||/product-(?:picture|image)/i.test(tid)||(is300&&ad.contains(e)&&String(e.className||'').indexOf('swiper-wrapper')>=0))return null;var tag=(e.tagName||'').toLowerCase();if(tag!=='img'&&tag!=='video'&&tag!=='canvas')continue;var r=ad7144VisibleRect(e);if(!r)continue;var ar=r.width*r.height/(rr.width*rr.height),wr=r.width/rr.width,hr=r.height/rr.height;if(wr>=minW&&hr>=minH&&ar>=minA&&ar>score){best=e;score=ar}}if(!best){var lim=Math.min(all.length,360);for(var j=0;j<lim;j++){var x=all[j],r2=ad7144VisibleRect(x);if(!r2||ad7144MediaKind(x)!=='background')continue;var ar2=r2.width*r2.height/(rr.width*rr.height),wr2=r2.width/rr.width,hr2=r2.height/rr.height;if(wr2>=minW&&hr2>=minH&&ar2>=minA&&ar2>score){best=x;score=ar2}}}return best?{e:best,score:score,kind:ad7144MediaKind(best)}:null}catch(_){return null}}"
         "function ad7144Mark(e,score,kind,mode){try{if(!e)return;var attr=kind==='background'?'data-ad7144-full-raster-bg':'data-ad7144-full-raster';e.setAttribute(attr,'1')}catch(_){}}"
         "function ad7266KillRasterChrome(){try{var hh=document.documentElement;if(!hh||!hh.hasAttribute('data-ad7144-full-raster-frame'))return;var xs=document.getElementsByClassName('border-enforcement');for(var i=0;i<xs.length&&i<12;i++){var e=xs[i],st=e.style;if(!st)continue;st.setProperty('display','none','important');st.setProperty('height','0','important');st.setProperty('min-height','0','important');st.setProperty('max-height','0','important');st.setProperty('margin','0','important');st.setProperty('padding','0','important');st.setProperty('border','0','important');st.setProperty('outline','0','important');st.setProperty('box-shadow','none','important');st.setProperty('background','#000','important')}var all=document.getElementsByTagName('*'),lim=Math.min(all.length,360),done=0;for(var j=0;j<lim&&done<20;j++){var q=all[j],tid=q.getAttribute&&q.getAttribute('data-testid')||'',cl=String(q.className||'');if(tid!=='renderer-factory-ad-container'&&tid!=='ad-background-container'&&!(/^modern-/.test(tid)&&/-layout-container$/.test(tid))&&cl.indexOf('creative-container')<0)continue;var z=q.style;if(!z)continue;z.setProperty('border','0','important');z.setProperty('outline','0','important');z.setProperty('box-shadow','none','important');done++}}catch(_){}}"
         "function ad7144Classify(){try{var hh=document.documentElement;if(!hh)return;var vw=Math.max(1,innerWidth,hh.clientWidth||0),vh=Math.max(1,innerHeight,hh.clientHeight||0);if(vw<220||vh<35||vh>520)return;var root=document.body||hh,p=ad7144Pick(root,{width:vw,height:vh});if(p){hh.setAttribute('data-ad7144-full-raster-frame','1');ad7144Mark(p.e,p.score,p.kind,'standalone-full-raster');ad7266KillRasterChrome();try{parent.postMessage({__adFullRaster7266:1},'*')}catch(_){}}}catch(_){}}"
         "ad7144Classify();if(document.readyState==='loading'){document.addEventListener('DOMContentLoaded',ad7144Classify,{once:true});window.addEventListener('load',ad7144Classify,{once:true});}else ad7144Classify();"
         "function black(){try{h=document.documentElement||h;if(!h)return;h.setAttribute('data-ad7104-standalone','1');h.style.setProperty('background-color','#000','important');h.style.setProperty('color-scheme','dark','important');if(document.body){document.body.style.setProperty('background-color','#000','important');document.body.style.setProperty('color-scheme','dark','important')}}catch(_){}}"
         "function own(){try{h=document.documentElement||h;if(!h)return false;black();if(!(document.adoptedStyleSheets&&window.CSSStyleSheet&&CSSStyleSheet.prototype&&CSSStyleSheet.prototype.replaceSync))return false;var sh=window[KEY];if(!sh){sh=new CSSStyleSheet();sh.replaceSync(CSS);window[KEY]=sh;}var a=document.adoptedStyleSheets||[],found=false;for(var i=0;i<a.length;i++)if(a[i]===sh){found=true;break;}if(!found)document.adoptedStyleSheets=a.concat([sh]);return true}catch(e){return false}}"
         "own();window.addEventListener('pageshow',function(){own()},{passive:true});"
         "}catch(e){}})();",factor,factor,shade,factor,factor,factor,factor,factor,factor,factor,factor,shade];
    gADStandaloneJSStrength7191=strengthKey;
    gADStandaloneJSCached7191=built;
    return built;
}


// v7.114 production: compact standalone diagnostic WKUserScript removed.
static NSString *ADTWBJS(void){
    long strengthKey=MAX(0,MIN(100,gP.whiteTameStrength));
    if(gADTWBJSCached7191 && gADTWBJSStrength7191==strengthKey) return gADTWBJSCached7191;
    // v7.190: probe-proven Home hero state parity. Off-center paused Video.js heroes
    // expose vjs-poster; the same front card hides it and exposes VIDEO.vjs-tech.
    // Both surfaces get one identical TWB factor. No active-slide/state repair.
    // Route-exclusive TWB: normal child frames get the compact child sheet; exact
    // standalone ad child frames return immediately because ADStandalonePaintJS7104
    // is their sole floor/media owner.
    CGFloat strength=(CGFloat)strengthKey;
    CGFloat t=strength/100.0;
    CGFloat shade=0.10+(0.48*t);
    CGFloat factor=1.0-shade;
    NSString *built=[NSString stringWithFormat:
        @"(function(){try{var host='';try{host=String(location.hostname||'').toLowerCase();}catch(_){}if(host==='flashtalking.com'||/\\.flashtalking\\.com$/.test(host))return;var child=0;try{child=window.top!==window;}catch(_){child=1;}if(child&&document.documentElement)document.documentElement.setAttribute('data-ad7-twb-child','1');if(child&&document.documentElement&&document.documentElement.hasAttribute('data-ad7104-standalone'))return;function put(id,css){var s=document.getElementById(id);if(!s){s=document.createElement('style');s.id=id;(document.head||document.documentElement||document).appendChild(s);}s.textContent=css;return s;}function relink(s){try{if(s&&!s.isConnected)(document.head||document.documentElement).appendChild(s)}catch(_){}}if(child){put('ad7-twb-child-min',\"html[data-ad7-twb-child=\\\"1\\\"] :is(img,video,canvas):not([class*=logo]):not([class*=avatar]):not([class*=profile]):not([class*=merchant]):not([class*=seller]):not([class*=prime]):not([class*=rating]):not([class*=star]):not([class*=sponsored]):not([class*=ad-feedback]):not([class*=adFeedback]):not([class"
        @"*=checkbox]):not([class*=heart]):not([class*=wishlist]):not([class*=icon]):not([class*=glyph]):not([class*=badge]):not(:where([data-testid=prime-badge] *)):not(:where([data-testid=ratings-stars] *)):not(:where([data-ad-feedback-label-id] *)):not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)),html[data-ad7-twb-child=\\\"1\\\"] [data-testid=simple-brand-logo-picture] img{filter:brightness(%.3f)!important;}\");return;}var p='';try{p=String(location.pathname||'');}catch(_){}var s=null;if(p==='/autocomplete'||p.indexOf('/autocomplete/')===0){s=put('ad7-search-pane-twb',\"img.ufs_tiles_card_widget-sug-image,img.s-entity-pd-carousel-tile-element-image,#attach-to-me img.s-image,#attach-to-me img.s-product-image,.s-suggestion-container img.s-image,.s-suggestion-container img.s-product-image{filter:none!important;-webkit-filter:none!important;opacity:%.3f!important;}\");}else if(p==='/s'||p.indexOf('/s/')===0){s=put('ad7-product-feed-twb',\"#search img.scx-stt-image,#search img._c2Itd_image_3UiYm,#search [class*=_bXVsd_image_],#search [class*=_bXVsd_lifestyleImage_],#search [class*=_bXVsd_lifestyleimage_],#search img.s-image,#search img.s-product-image,#search [data-component-type=s-product-image] img,#search img.ufs_tiles_card_widget-sug-image,#search img.haul-puis-portrait-img,#search img._c2Itd_image_pQREQ,#search ._c2Itd_cardContent_3OGkG.sbv-ad-content-container img:not([class*=_trackingPixel_]):not([class*=ad-feedback]):not([class*=sprite]){filter:brightness(%.3f)!important;-webkit-filter:brightness(%.3f)!important;opacity:1!important;mix-blend-mode:normal!important;}#search video.sbv-video-player-ecx,#search video._"
        @"c2Itd_video_17g-f{filter:none!important;-webkit-filter:none!important;}#search .sbv-video-overlay{background-color:rgba(0,0,0,%.3f)!important;}#search ._c2Itd_videoOverlay_1H_Jm{top:0!important;left:0!important;right:0!important;bottom:0!important;width:100%%!important;height:100%%!important;pointer-events:none!important;z-index:6!important;background-color:rgba(0,0,0,%.3f)!important;}#search .s-widget-container[class*=\\\"template=FEATURED_ASINS_VIDEO_LIST\\\"] video[class*=_video_1m98b_]{filter:none!important;-webkit-filter:none!important;}#search .s-widget-container[class*=\\\"template=FEATURED_ASINS_VIDEO_LIST\\\"] [class*=_videoOverlay_1m98b_],#search [class*=_videoPlayerContainer_8wyx7_] [class*=_videoWrapper_8wyx7_] [class*=_videoContainer_1m98b_] [class*=_videoLink_1m98b_] > [class*=_videoOverlay_1m98b_]{background-color:rgba(0,0,0,%.3f)!important;}#search [class*=_navigationWrapper_8wyx7_] > [class*=_container_avw36_][class*=_Horizontal_avw36_]{background:#4a4f51!important;background-color:#4a4f51!important;}\");}else{s=put('ad7-menu-twb',\".ape-placement.is-image-oo[style*=\\\"aspect-ratio: 300 / 250\\\"]>iframe,[id^=ape_gateway_dynamic-][id$=_mshop_placement].is-image-oo[style*=\\\"aspect-ratio: 300 / 250\\\"]>iframe{filter:brightness(%.3f)!important;-webkit-filter:brightness(%.3f)!important;}body:has(#sc-page-container) .a-sheet-web:has(.ssf-customize-container-one) #ssf-preview-container,body:has(#sc-page-container) .a-sheet-web:has(.ssf-customize-container-one) img[id^=ssf-share-channel-],body:has(#sc-page-container) .a-sheet-web [id^=p13n-uf-bottom-sheet_] img.p13n-product-image,#sc-page-container [class*=_sp-cart-mobile-carousel_style_spMobileCarousel__] [class*=_sp-cart-mobile-carousel_style_imageContainer__] img.sp-dynamic-image,img.ufs_tiles_card_widget-sug-image,img.s-image,img.s-product-image,#landingImage,#imgBlkFront,#imgTagWrapperId img,img[data-a-dynamic-image],img.a-dynamic-image,[data-component-type=s-product-image] img,[class*=product-image] img,[class*=asin-image] img,.p13n-sc-uncoverable-faceout img,[data-asin] img.s-image,[data-csa-c-asin] img.s-image,#sc-page-container .sc-returns-are-easy-container img,#sc-page-container .maple-banner__image img,:is(#gwm-Deck-btf,.gwm-dashboard-container) :is(.a-cardui,[class*=asin-container],[class*=mosaic-card],[class*=p13n-uf]) img:not([class*=logo]):not([class*=avatar]):not([class*=profile]):not([class*=merchant]):not([class*=seller]):not([class*=brand]):not([class*=store]):not([class*=rating]):not([class*=star]):not([class*=sprite]):not([class*=pixel]):not([class*=icon]):not([class*=glyph]):not([class*"
        @"=badge]):not([class*=checkbox]):not([class*=heart]):not([class*=wishlist]):not([class*=search-icon]):not([class*=microphone]):not([class*=camera]):not([class*=location]):not([class*=chevron]):not([class*=nav-icon]):not([class*=tab-icon]):not([class*=header-icon]):not([class*=ad-feedback]):not([class*=sponsored]):not([class*=spr]):not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)),"
        @"#gwm-Deck-btf :is([class*=mobile-mshop-ad],[class*=mobile-ad-container],[class*=ape-wrapper],[class*=ape-placement]) :is(img,video,canvas):not([class*=logo]):not([class*=prime]):not([class*=rating]):not([class*=star]):not([class*=icon]):not([class*=glyph]):not([class*=badge]):not(:where([class*=logo] *)):not(:whe"
        @"re([class*=prime] *)):not(:where([class*=rating] *)):not(:where([class*=star] *)):not(:where([class*=sponsored] *)):not(:where([class*=ad-feedback] *)):not(:where([class*=adFeedback] *)):not(:where([data-testid=prime-badge] *)):not(:where([data-testid=ratings-stars] *)):not(:where([id^=ad-feedback-] *)):not(:where([id^=af-label-] *)),[class*=hp-mosaic-container] :is(img,svg):not([class*=next]):not([class*=prev]):not([class*=chevron]):not([class*=arrow]):not(:where([class*=next] *)):not(:where([class*=prev] *)):not(:where([class*=chevron] *)):not(:where([class*=arrow] *)):not([class*=header-icon]):not([class*=ad-feedback]):not([class*=sponsored]):not([class*=spr]),[class*=_mosaic-container_style_widgetContainer] :is(img,svg):not([class*=next]):not([class*=prev]):not([class*=chevron]):not([class*=arrow]):not(:where([class*=next] *)):not(:where([class*=prev] *)):not(:where([class*=chevron] *)):not(:where([class*=arrow] *)):not([class*=header-icon]):not([class*=ad-feedback]):not([class*=sp"
        @"onsored]):not([class*=spr]),#gwm-window [id^=wd-shoppable-] :is(img,video,canvas):not([class*=icon]):not([class*=glyph]):not([class*=sprite]):not([class*=pixel]):not([class*=logo]):not([class*=badge]):not(:where([data-ad-feedback-label-id] *)):not(:where([class*=ad-feedback] *)),#gwm-Deck-atf [id^=ape_][id$=_mshop_placement][style*=\\\"320 / 50\\\"] img.ad-background-image.mrc-btr-creative,img[class*=_single-creative-card],img[class*=_single-video-card],[class*=single-creative-card] img,[class*=single-video-card] img,[class*=single-video-card] video,[class*=canvas-card] canvas,video.vjs-tech,video[class*=_npack-asin-card_style_background-video__],[class*=_npack-asin-card_style_background-video-container__] > video[class*=_npack-asin-card_style_motion-content__]{filter:brightness(%.3f)!important;}:is([class*=theming-card-background],[class*=_npack-asin-card_style_theming-background-override__]) [class*=_npack-asin-card_style_asin-container-white__]{background:#000!important;background-color:#000!important;border-color:#000!important;outline-color:#000!important;box-shadow:none!important;transition"
        @"-property:none!important;}[class*=theming-card-background],[class*=vjs-poster],[class*=single-creative-card-background],[class*=single-video-card-background],[class*=single-creative-card] [class*=theming-card-background],[class*=single-video-card] [class*=theming-card-background],[class*=single-video-card] [class*=vjs-poster],:is([class*=single-creative-card],[class*=single-video-card],[class*=theming-card],[class*=_npack-asin-card],[class*=npack-asin-card],[class*=canvas-card],[class*=canvas-container]):is([style*=background-image],[style*=backgroundImage]),:is([class*=single-creative-card],[class*=single-video-card],[class*=theming-card],[class*=_npack-asin-card],[class*=npack-asin-card],[class*=canvas-card],[class*=canvas-container]) :is([style*=background-image],[style*=backgroundImage]){box-shadow:inset 0 0 0 9999px rgba(0,0,0,%.3f)!important;transition-property:none!important;}.video-js .vjs-poster[style*=background-image],.vjs-poster.vjs-poster[style*=background-image]{box-shadow:none!important;filter:brightness(%.3f)!important;-webkit-filter:brightness(%.3f)!important;transition:none!important;}\");}if(document.readyState==='loading')window.addEventListener('load',function(){relink(s);},{once:true});else relink(s);}catch(e){}})();",
        factor,factor,factor,factor,factor,factor,factor,factor,factor,factor,shade,factor,factor];
    gADTWBJSStrength7191=strengthKey;
    gADTWBJSCached7191=built;
    return built;
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
    if(!wv)return;
    @try {
        if(objc_getAssociatedObject(wv,kADTrackedWebView7191)) return;
        @synchronized([WKWebView class]) {
            if(!gADWebViews)gADWebViews=[NSHashTable weakObjectsHashTable];
            [gADWebViews addObject:wv];
            objc_setAssociatedObject(wv,kADTrackedWebView7191,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } @catch(...) {}
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
    return @"(function(){try{var ids=['ad7-twb-child-min','ad7-search-pane-twb','ad7-product-feed-twb','ad7-menu-twb'];for(var i=0;i<ids.length;i++){var s=document.getElementById(ids[i]);if(s)s.remove();}if(document.documentElement)document.documentElement.removeAttribute('data-ad7-twb-child');}catch(e){}})();";
}
static void ADRefreshWebTWBPrefs791(void){
    NSString *js=(gP.enabled&&gP.whiteTame)?ADTWBJS():ADTWBClearJS791();
    for(WKWebView *wv in ADTrackedWebViews()){
        if(!wv)continue;
        @try { [wv evaluateJavaScript:js completionHandler:nil]; } @catch(...) {}
    }
}


// v7.266: one-shot parent proof for full-raster standalone children. No observer,
// timer, RAF, or scroll hook; it acts only on a classifier postMessage.
static NSString *ADFullRasterHostBridgeJS7266(void){
    return @"(function(){try{if(window.__adFullRasterHostBridge7266)return;window.__adFullRasterHostBridge7266=1;window.addEventListener('message',function(ev){try{var x=ev.data;if(!x||x.__adFullRaster7266!==1)return;var a=document.getElementsByTagName('iframe'),f=null;for(var i=0;i<a.length&&i<64;i++){if(a[i].contentWindow===ev.source){f=a[i];break}}if(f){function clear(e){try{if(!e)return;e.setAttribute('data-ad7266-full-raster-host','1');var s=e.style;if(s){s.setProperty('border','0','important');s.setProperty('border-width','0','important');s.setProperty('border-color','transparent','important');s.setProperty('outline','0','important');s.setProperty('box-shadow','none','important')}}catch(_){}}clear(f);var p=f;for(var d=0;d<5&&p;d++,p=p.parentElement){var id=String(p.id||''),cl=String(p.className||'');if(cl.indexOf('ape-placement')>=0||(id.indexOf('ape_')===0&&id.indexOf('_placement')>0)){clear(p);var b=p.getElementsByClassName('border-enforcement');for(var j=0;j<b.length&&j<8;j++){clear(b[j]);b[j].style.setProperty('display','none','important');b[j].style.setProperty('height','0','important');b[j].style.setProperty('margin','0','important');b[j].style.setProperty('padding','0','important')}break}}}if(window!==top)try{parent.postMessage({__adFullRaster7266:1},'*')}catch(_){}}catch(_){}} ,false)}catch(_){}})();";
}

// v7.266: dormant current-frame Home forensics bridge. It installs one message
// listener per frame and performs no DOM walk until the explicit Home probe trigger.
static NSString *ADHomeFrameProbeBridgeJS7265(void){
    return
        @"(function(){try{if(window.__adHomeProbeBridge7265)return;window.__adHomeProbeBridge7265=1;function clean(v,n){v=String(v==null?'':v).replace(/[\\r\\n\\t]+/g,' ').replace(/\\|"
        @"/g,'¦').replace(/\\\\/g,'/');n=n||180;return v.length>n?v.slice(0,n)+'…':v}function hash(s){s=String(s||'');var h=2166136261>>>0;for(var i=0;i<s.length;i++){h^=s.charCodeAt"
        @"(i);h=Math.imul(h,16777619)}return (h>>>0).toString(16)}function cls(e){try{var c=typeof e.className==='string'?e.className:(e.className&&e.className.baseVal)||'';return "
        @"clean(c,220)}catch(_){return ''}}function attrs(e){var names=['role','data-testid','data-acei-id','data-html-dimensions','data-csa-c-type','data-csa-c-content-id','data-c"
        @"sa-c-slot-id','data-csa-c-painter','data-cel-widget','cel_widget_id','name','type','aria-hidden'],o={};for(var i=0;i<names.length;i++){try{var v=e.getAttribute(names[i]);"
        @"if(v!=null&&v!=='')o[names[i]]=clean(v,180)}catch(_){}}try{var st=e.getAttribute('style');if(st)o.style=clean(st,320)}catch(_){}return o}function ownText(e){var x='';try{"
        @"for(var i=0;i<e.childNodes.length;i++){var n=e.childNodes[i];if(n.nodeType===3)x+=n.nodeValue||''}}catch(_){}x=x.trim();return {len:x.length,hash:hash(x)}}function pseudo"
        @"(e,p){try{var c=getComputedStyle(e,p),ct=String(c.content||''),bt=parseFloat(c.borderTopWidth||0)||0,w=parseFloat(c.width||0)||0,h=parseFloat(c.height||0)||0;if((!ct||ct="
        @"=='none'||ct==='normal')&&c.backgroundColor==='rgba(0, 0, 0, 0)'&&c.backgroundImage==='none'&&bt===0&&w===0&&h===0)return null;return {contentLen:ct.length,contentHash:ha"
        @"sh(ct),display:clean(c.display,24),bg:clean(c.backgroundColor,52),bgImg:clean(c.backgroundImage,100),borderTop:clean(c.borderTop,100),width:clean(c.width,30),height:clean"
        @"(c.height,30),position:clean(c.position,20),z:clean(c.zIndex,20)}}catch(_){return null}}function media(e){try{var t=String(e.tagName||'').toUpperCase();if(t==='IMG')retur"
        @"n {kind:'img',natural:[Number(e.naturalWidth||0),Number(e.naturalHeight||0)],complete:e.complete?1:0};if(t==='VIDEO')return {kind:'video',natural:[Number(e.videoWidth||0)"
        @",Number(e.videoHeight||0)],paused:e.paused?1:0};if(t==='CANVAS')return {kind:'canvas',natural:[Number(e.width||0),Number(e.height||0)]};if(t==='SVG')return {kind:'svg',vi"
        @"ewBox:clean(e.getAttribute('viewBox')||'',80)}}catch(_){}return null}function snap(){try{var d=document,de=d.documentElement||{},vw=Math.max(1,innerWidth||de.clientWidth|"
        @"|0),vh=Math.max(1,innerHeight||de.clientHeight||0),MAX=700,out=[],visited=0,trunc=0;function state(e){try{var r=e.getBoundingClientRect(),c=getComputedStyle(e),struct=e=="
        @"=d.documentElement||e===d.body,hit=struct||(r.width>.1&&r.height>.1&&r.right>=-1&&r.bottom>=-1&&r.left<=vw+1&&r.top<=vh+1),zero=r.width<=.1||r.height<=.1;return {r:r,c:c,"
        @"struct:struct,hit:hit,zero:zero}}catch(_){return null}}function emit(e,st,depth){if(out.length>=MAX){trunc=1;return}var r=st.r,c=st.c,a=attrs(e),o={depth:depth,tag:String"
        @"(e.tagName||e.nodeName||'?').toLowerCase(),id:clean(e.id||'',120),cls:cls(e),rect:[+r.left.toFixed(1),+r.top.toFixed(1),+r.width.toFixed(1),+r.height.toFixed(1)],children"
        @":Number(e.childElementCount||0),display:clean(c.display,24),visibility:clean(c.visibility,24),opacity:clean(c.opacity,16),position:clean(c.position,20),z:clean(c.zIndex,2"
        @"0),overflow:[clean(c.overflowX,20),clean(c.overflowY,20)],pointer:clean(c.pointerEvents,20),fg:clean(c.color,52),textFill:clean(c.webkitTextFillColor,52),bg:clean(c.backg"
        @"roundColor,52),bgImg:clean(c.backgroundImage,120),border:[clean(c.borderTop,100),clean(c.borderRight,100),clean(c.borderBottom,100),clean(c.borderLeft,100)],outline:clean"
        @"(c.outline,100),radius:clean(c.borderRadius,60),shadow:clean(c.boxShadow,140),filter:clean(c.filter,100),transform:clean(c.transform,120),attrs:a,text:ownText(e)};var m=m"
        @"edia(e),b=pseudo(e,'::before'),af=pseudo(e,'::after');if(m)o.media=m;if(b)o.before=b;if(af)o.after=af;out.push(o)}function walk(e,depth){if(!e||depth>36||out.length>=MAX)"
        @"return;visited++;var st=state(e);if(!st)return;if(st.c.display==='none'||st.c.visibility==='hidden'||parseFloat(st.c.opacity||1)<=0.001)return;if(st.hit)emit(e,st,depth);"
        @"var descend=st.struct||st.hit||st.zero||st.c.position==='fixed'||st.c.position==='sticky';if(!descend)return;var ch=e.children;for(var i=0;ch&&i<ch.length&&out.length<MAX"
        @";i++)walk(ch[i],depth+1)}walk(d.documentElement,0);return {ready:String(d.readyState||''),viewport:[vw,vh],scroll:[Number(scrollX||0),Number(scrollY||0)],scrollSize:[Numb"
        @"er((d.scrollingElement||de||d.body).scrollWidth||0),Number((d.scrollingElement||de||d.body).scrollHeight||0)],visited:visited,emitted:out.length,truncated:trunc,nodes:out"
        @"}}catch(e){return {error:String(e&&e.message||e)}}}window.__adHomeProbeSnap7265=snap;function frames(){try{return document.getElementsByTagName('iframe')}catch(_){return "
        @"[]}}function frameHit(f){try{var r=f.getBoundingClientRect(),c=getComputedStyle(f),vw=Math.max(1,innerWidth||0),vh=Math.max(1,innerHeight||0);return c.display!=='none'&&c"
        @".visibility!=='hidden'&&parseFloat(c.opacity||1)>.001&&r.width>.1&&r.height>.1&&r.right>=-1&&r.bottom>=-1&&r.left<=vw+1&&r.top<=vh+1}catch(_){return false}}function broad"
        @"cast(req){var a=frames();for(var i=0;i<a.length&&i<24;i++){if(!frameHit(a[i]))continue;try{a[i].contentWindow.postMessage(req,'*')}catch(_){}}}window.__adHomeProbeBroadca"
        @"st7265=broadcast;function sourceIndex(src){var a=frames();for(var i=0;i<a.length&&i<24;i++)try{if(a[i].contentWindow===src)return i}catch(_){}return -1}window.addEventLis"
        @"tener('message',function(ev){try{var x=ev.data;if(!x)return;if(x.__adHomeProbeReq7265===1){var res={__adHomeProbeRes7265:1,token:x.token,path:'',snap:snap()};if(window==="
        @"top){var c=window.__adHomeProbeCollector7265;if(c&&c.token===x.token)c.responses.push(res)}else parent.postMessage(res,'*');broadcast(x);return}if(x.__adHomeProbeRes7265="
        @"==1){var idx=sourceIndex(ev.source);x.path='f'+idx+(x.path?'/'+x.path:'');if(window===top){var c2=window.__adHomeProbeCollector7265;if(c2&&c2.token===x.token&&c2.response"
        @"s.length<48)c2.responses.push(x)}else parent.postMessage(x,'*')}}catch(_){}},false);}catch(_){}})();";
}

// v7.311 Cart transition recorder.  The bridge itself is inert: it installs no
// observer, listener, timer, or RAF until the user explicitly arms the Cart probe.
// While armed it keeps a bounded privacy-safe ring across same-origin reloads so
// the white strip/skeleton owners are captured during their real paint lifetime,
// rather than inferred from a settled page after the transition has disappeared.
static NSString *ADCartTransitionBridgeJS7310(void){
    return
        @"(function(){try{if(window.top!==window||window.__adCartTransitionBridge7310)return;window.__adCartTransitionBridge7310=1;"
        @"var ARM='__adCartTransitionArm7310',STORE='__adCartTransitionLog7310',MAX=3200000;"
        @"function clean(v,n){v=String(v==null?'':v).replace(/[\\r\\n\\t]+/g,' ').replace(/\\|/g,'¦').replace(/\\\\/g,'/').replace(/url\\([^)]*\\)/ig,'url(redacted)');n=n||220;return v.length>n?v.slice(0,n)+'…':v}"
        @"function hash(s){s=String(s||'');var h=2166136261>>>0;for(var i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619)}return (h>>>0).toString(16)}"
        @"function cls(e){try{var c=typeof e.className==='string'?e.className:(e.className&&e.className.baseVal)||'';return clean(c,240)}catch(_){return ''}}"
        @"function sig(e){if(!e)return '?';var t=String(e.tagName||e.nodeName||'?').toLowerCase(),id='';try{id=e.id||''}catch(_){}var c=cls(e).trim().split(/\\s+/).filter(Boolean).slice(0,4).join('.');return t+(id?'#'+clean(id,100):'')+(c?'.'+clean(c,140):'')}"
        @"function chain(e){var a=[],x=e;for(var i=0;x&&i<10;i++,x=x.parentElement)a.push(sig(x));return a.join('<-')}"
        @"function attr(e,n){try{return clean(e.getAttribute(n)||'',160)}catch(_){return ''}}function rect(e){try{var r=e.getBoundingClientRect();return [+r.left.toFixed(1),+r.top.toFixed(1),+r.width.toFixed(1),+r.height.toFixed(1)]}catch(_){return [0,0,0,0]}}"
        @"function rgba(v){var m=/rgba?\\(([^)]+)\\)/i.exec(String(v||''));if(!m)return null;var q=m[1].split(',').map(parseFloat);return {l:(q[0]*.2126+q[1]*.7152+q[2]*.0722)/255,a:q.length>3?q[3]:1}}function bright(v){var q=rgba(v);return !!q&&q.a>.04&&q.l>.62}"
        @"function pseudo(e,p){try{var c=getComputedStyle(e,p);return {content:String(c.content||'').length,bg:clean(c.backgroundColor,60),bgImg:clean(c.backgroundImage,100),border:clean(c.borderTop,100),outline:clean(c.outline,100),shadow:clean(c.boxShadow,130),opacity:clean(c.opacity,18),display:clean(c.display,24)}}catch(_){return {err:1}}}"
        @"function technical(e){var ns=['role','data-testid','data-component-type','data-csa-c-type','data-csa-c-content-id','data-csa-c-slot-id','data-csa-c-painter','data-cel-widget','cel_widget_id','name','type','aria-hidden','aria-busy'],o={};for(var i=0;i<ns.length;i++){var v=attr(e,ns[i]);if(v)o[ns[i]]=v}try{var a=e.getAttribute('data-asin');if(a)o['data-asin']=String(a).length+'/'+hash(a);if(e.hasAttribute('src'))o.src=1;if(e.hasAttribute('href'))o.href=1;var al=e.getAttribute('aria-label');if(al!=null)o.ariaLabel=String(al).length+'/'+hash(al);var alt=e.getAttribute('alt');if(alt!=null)o.alt=String(alt).length+'/'+hash(alt)}catch(_){}return o}"
        @"function state(e){try{var c=getComputedStyle(e),r=rect(e),b=pseudo(e,'::before'),a=pseudo(e,'::after'),id=String(e.id||''),cl=cls(e),semantic=/(skeleton|shimmer|loading|placeholder|carousel-card|p13n|sc-saved-cart|sc-cart-spinner|spinner)/i.test(id+' '+cl);var paints=[c.backgroundColor,c.borderTopColor,c.borderRightColor,c.borderBottomColor,c.borderLeftColor,c.outlineColor,b.bg,b.border,a.bg,a.border],isBright=false;for(var i=0;i<paints.length;i++)if(bright(paints[i])){isBright=true;break}if(!isBright&&!semantic)return null;var inline='';try{inline=clean(e.getAttribute('style')||'',360)}catch(_){}var tag=String(e.tagName||'').toUpperCase(),media=null;if(tag==='IMG')media={kind:'img',natural:[Number(e.naturalWidth||0),Number(e.naturalHeight||0)],complete:e.complete?1:0};else if(tag==='CANVAS')media={kind:'canvas',size:[Number(e.width||0),Number(e.height||0)]};else if(tag==='SVG')media={kind:'svg',viewBox:clean(attr(e,'viewBox'),80)};return {key:hash(sig(e)+'|'+r.join(',')+'|'+c.backgroundColor+'|'+c.backgroundImage+'|'+c.borderTop+'|'+c.borderBottom+'|'+c.boxShadow+'|'+c.opacity+'|'+b.bg+'|'+a.bg),sig:sig(e),chain:clean(chain(e),760),rect:r,bright:isBright?1:0,semantic:semantic?1:0,display:clean(c.display,24),visibility:clean(c.visibility,24),opacity:clean(c.opacity,18),position:clean(c.position,24),z:clean(c.zIndex,24),overflow:[clean(c.overflowX,20),clean(c.overflowY,20)],bg:clean(c.backgroundColor,60),bgImg:clean(c.backgroundImage,150),border:[clean(c.borderTop,100),clean(c.borderRight,100),clean(c.borderBottom,100),clean(c.borderLeft,100)],radius:clean(c.borderRadius,70),outline:clean(c.outline,110),shadow:clean(c.boxShadow,150),filter:clean(c.filter,100),transform:clean(c.transform,120),inline:inline,attrs:technical(e),before:b,after:a,media:media,el:e}}catch(_){return null}}"
        @"function rules(e){var out=[],seen=0;function walk(rs,owner){if(!rs||seen>7000||out.length>=24)return;for(var i=0;i<rs.length&&seen++<7000&&out.length<24;i++){var r=rs[i];try{if(r.selectorText&&e.matches(r.selectorText)){var d=String(r.style&&r.style.cssText||'');if(/background|border|outline|box-shadow|filter|opacity|display|visibility/i.test(d))out.push({owner:owner,selector:clean(r.selectorText,260),decl:clean(d,520)})}if(r.cssRules)walk(r.cssRules,owner)}catch(_){}}}var ss=document.styleSheets;for(var i=0;i<ss.length&&i<180&&out.length<24;i++){var owner='sheet'+i;try{var n=ss[i].ownerNode;if(n)owner=sig(n);walk(ss[i].cssRules,owner)}catch(_){out.push({owner:owner,inaccessible:1})}}return out}"
        @"function sheets(){var o=[],ss=document.styleSheets;for(var i=0;i<ss.length&&i<220;i++){var x={index:i};try{var n=ss[i].ownerNode;x.owner=n?sig(n):'none';x.media=clean(ss[i].media&&ss[i].media.mediaText||'',100);x.disabled=ss[i].disabled?1:0;x.rules=ss[i].cssRules?ss[i].cssRules.length:0}catch(_){x.inaccessible=1}o.push(x)}return o}"
        @"function animations(){var o=[];try{var a=document.getAnimations?document.getAnimations():[];for(var i=0;i<a.length&&i<100;i++){var x=a[i],ef=x.effect,t=ef&&ef.target;o.push({target:sig(t),playState:clean(x.playState,30),current:Math.round(Number(x.currentTime||0)),rate:Number(x.playbackRate||0),delay:Math.round(Number(ef&&ef.getTiming?ef.getTiming().delay||0:0)),duration:Math.round(Number(ef&&ef.getTiming?ef.getTiming().duration||0:0))})}}catch(_){}return o}"
        @"function start(cfg,why){try{var old=sessionStorage.getItem(STORE)||'',st={active:1,cfg:cfg,buf:old,chars:old.length,frame:0,dirty:1,mut:0,seen:{},lastPersist:0,lastDigest:'',raf:0};window.__adCartTransitionState7310=st;function log(kind,obj){if(!st.active)return;var line='T '+(Date.now()-cfg.at)+' '+kind+' '+clean(JSON.stringify(obj||{}),12000)+'\\n';st.buf+=line;st.chars+=line.length;if(st.chars>MAX){st.buf=st.buf.slice(st.chars-MAX);st.chars=st.buf.length}if(Date.now()-st.lastPersist>350){st.lastPersist=Date.now();try{sessionStorage.setItem(STORE,st.buf)}catch(_){}}}"
        @"function add(set,e){for(var n=0;e&&n<4;n++,e=e.parentElement)try{if(!set.has(e))set.add(e)}catch(_){}}function collect(){var set=new Set(),vw=Math.max(1,innerWidth||0),vh=Math.max(1,innerHeight||0);for(var y=4;y<vh;y+=12)for(var x=8;x<vw;x+=40)try{var es=document.elementsFromPoint(x,y);for(var z=0;z<es.length&&z<8;z++)add(set,es[z])}catch(_){}if(st.dirty||st.frame%8===0){var root=document.getElementById('sc-page-container')||document.body||document.documentElement,all=root?root.querySelectorAll('*'):[];for(var i=0;i<all.length&&i<7500;i++){var e=all[i],id=String(e.id||''),cl=cls(e);if(/skeleton|shimmer|loading|placeholder|carousel-card|p13n|sc-saved-cart|sc-cart-spinner|spinner/i.test(id+' '+cl))add(set,e)}}var out=[];set.forEach(function(e){var q=state(e);if(q)out.push(q)});out.sort(function(a,b){return a.rect[1]-b.rect[1]||a.rect[0]-b.rect[0]});return out}"
        @"function snap(reason){if(!st.active)return;st.dirty=0;var cs=collect(),keys=[];for(var i=0;i<cs.length;i++)keys.push(cs[i].key);var digest=hash(keys.join('|')+'|'+String(document.readyState||'')+'|'+document.getElementsByTagName('*').length);if(digest!==st.lastDigest||reason!=='frame'){st.lastDigest=digest;log('FRAME',{reason:reason,frame:st.frame,ready:String(document.readyState||''),viewport:[innerWidth,innerHeight,devicePixelRatio],scroll:[Number(scrollX||0),Number(scrollY||0)],nodes:document.getElementsByTagName('*').length,styles:document.styleSheets.length,ad7:document.getElementById('ad7-static-theme')?1:0,candidates:cs.length,digest:digest,animations:animations()});for(var i=0;i<cs.length;i++){var q=cs[i],el=q.el;delete q.el;log('OWNER',q);if(q.bright&&!st.seen[q.sig]){st.seen[q.sig]=1;log('RULES',{sig:q.sig,matches:rules(el)})}}}}"
        @"function event(ev){var o={type:ev.type,target:sig(ev.target)};if('animationName'in ev)o.animationName=clean(ev.animationName,100);if('propertyName'in ev)o.propertyName=clean(ev.propertyName,100);if('elapsedTime'in ev)o.elapsed=Number(ev.elapsedTime||0);log('EVENT',o);st.dirty=1}var evs=['animationstart','animationiteration','animationend','animationcancel','transitionrun','transitionstart','transitionend','transitioncancel'];for(var i=0;i<evs.length;i++)document.addEventListener(evs[i],event,true);"
        @"document.addEventListener('readystatechange',function(){log('READY',{state:document.readyState});st.dirty=1},true);document.addEventListener('DOMContentLoaded',function(){log('DOM_CONTENT_LOADED',{nodes:document.getElementsByTagName('*').length});st.dirty=1},true);window.addEventListener('load',function(){log('LOAD',{nodes:document.getElementsByTagName('*').length});st.dirty=1},true);window.addEventListener('pageshow',function(e){log('PAGESHOW',{persisted:e.persisted?1:0});st.dirty=1},true);window.addEventListener('pagehide',function(e){log('PAGEHIDE',{persisted:e.persisted?1:0});try{sessionStorage.setItem(STORE,st.buf)}catch(_){}},true);document.addEventListener('visibilitychange',function(){log('VISIBILITY',{state:document.visibilityState})},true);"
        @"try{var mo=new MutationObserver(function(ms){st.mut+=ms.length;var sample=[];for(var i=0;i<ms.length&&i<24;i++){var m=ms[i],x={type:m.type,target:sig(m.target)};if(m.type==='attributes')x.attribute=clean(m.attributeName,80);else{x.added=m.addedNodes?m.addedNodes.length:0;x.removed=m.removedNodes?m.removedNodes.length:0}sample.push(x)}log('MUTATION',{batch:ms.length,total:st.mut,sample:sample});st.dirty=1});mo.observe(document,{subtree:true,childList:true,attributes:true,attributeFilter:['class','style','hidden','aria-busy','aria-hidden']});st.mo=mo}catch(e){log('MUTATION_ERROR',{name:String(e&&e.name||'error')})}"
        @"try{var po=new PerformanceObserver(function(ls){var es=ls.getEntries(),o=[];for(var i=0;i<es.length&&i<80;i++){var e=es[i],x={type:clean(e.entryType,40),start:+Number(e.startTime||0).toFixed(2),duration:+Number(e.duration||0).toFixed(2)};if(e.entryType==='paint')x.name=clean(e.name,50);if(e.entryType==='layout-shift'){x.value=Number(e.value||0);x.hadRecentInput=e.hadRecentInput?1:0}if(e.element)x.element=sig(e.element);o.push(x)}if(o.length)log('PERFORMANCE',{entries:o})});po.observe({entryTypes:['paint','largest-contentful-paint','layout-shift','longtask']});st.po=po}catch(_){}"
        @"st.snap=snap;log('DOC_START',{why:why,ready:String(document.readyState||''),viewport:[innerWidth,innerHeight,devicePixelRatio],nodes:document.getElementsByTagName('*').length,styleSheets:sheets()});function tick(){if(!st.active)return;st.frame++;if(Date.now()>cfg.until||st.frame>3600){snap('deadline');log('STOP',{reason:'deadline',frame:st.frame});st.active=0;try{sessionStorage.setItem(STORE,st.buf)}catch(_){}return}if(st.frame<=4||st.frame%2===0||st.dirty)snap(st.dirty?'mutation':'frame');st.raf=requestAnimationFrame(tick)}st.raf=requestAnimationFrame(tick);return 'ARMED token='+clean(cfg.token,80)+' until='+cfg.until}catch(e){return 'ARM_ERROR '+String(e&&e.name||'error')}}"
        @"window.__adCartTransitionArm7310=function(token){try{sessionStorage.removeItem(STORE);var now=Date.now(),cfg={token:String(token||''),at:now,until:now+45000};sessionStorage.setItem(ARM,JSON.stringify(cfg));localStorage.setItem(ARM,JSON.stringify(cfg));return start(cfg,'explicit-arm')}catch(e){return 'ARM_ERROR '+String(e&&e.name||'error')}};"
        @"window.__adCartTransitionExport7310=function(){try{var st=window.__adCartTransitionState7310;if(st&&st.active){st.dirty=1;st.lastDigest='';if(st.snap)st.snap('export');try{sessionStorage.setItem(STORE,st.buf)}catch(_){}}var x=(st&&st.buf)||sessionStorage.getItem(STORE)||'';return 'TRANSITION_LOG_BEGIN\\n'+x+'TRANSITION_LOG_END\\n'}catch(e){return 'EXPORT_ERROR '+String(e&&e.name||'error')}};"
        @"window.__adCartTransitionClear7310=function(){try{var st=window.__adCartTransitionState7310;if(st){st.active=0;if(st.mo)st.mo.disconnect();if(st.po)st.po.disconnect();if(st.raf)cancelAnimationFrame(st.raf)}sessionStorage.removeItem(ARM);sessionStorage.removeItem(STORE);localStorage.removeItem(ARM);return 'CLEARED'}catch(e){return 'CLEAR_ERROR '+String(e&&e.name||'error')}};"
        @"var raw=null;try{raw=sessionStorage.getItem(ARM)||localStorage.getItem(ARM)}catch(_){}if(raw){try{var cfg=JSON.parse(raw);if(cfg&&Date.now()<Number(cfg.until||0))start(cfg,'document-start-reload');else{sessionStorage.removeItem(ARM);localStorage.removeItem(ARM)}}catch(_){}}}catch(_){}})();";
}

// One immutable document-start program per strength replaces four separately
// allocated/compiled WKUserScripts while preserving their proven execution order.
static long gADCoreWebJSStrength7271=-1;
static NSString *gADCoreWebJSCached7271=nil;
static NSString *ADCoreWebJS7271(void){
    long strength=MAX(0,MIN(100,gP.whiteTameStrength));
    if(gADCoreWebJSCached7271&&gADCoreWebJSStrength7271==strength)return gADCoreWebJSCached7271;
    gADCoreWebJSStrength7271=strength;
    gADCoreWebJSCached7271=[NSString stringWithFormat:@"%@%@%@%@%@",ADFullRasterHostBridgeJS7266(),
        ADHomeFrameProbeBridgeJS7265(),ADStandalonePaintJS7104(),ADFloorJS(),
        ADCartTransitionBridgeJS7310()];
    return gADCoreWebJSCached7271;
}

static void ADAttachScriptsToUCC710(WKUserContentController *ucc){
    if(!ucc || !gP.enabled)return;
    @try {
        if(!objc_getAssociatedObject(ucc,kADCoreWebUS7271)){
            WKUserScript *us=[[WKUserScript alloc] initWithSource:ADCoreWebJS7271() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
            [ucc addUserScript:us];
            objc_setAssociatedObject(ucc,kADCoreWebUS7271,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
static void ADPaintWrapperChildren7129(UIView *root);
static void ADApplyWebFloor(WKWebView *wv){
    if(!wv || !gP.enabled)return;
    ADTrackWebView(wv);
    @try {
        // v7.129: own the backing before attachment as well as after it. The v7.128
        // probe caught a destination/search WKWebView still stock-white while loading.
        // This is constant-time UIKit/WebKit property ownership only; no JS retry lane.
        UIColor *black=ADOLED();
        if(wv.isOpaque) wv.opaque=NO;
        ADSetViewBackground7226(wv,black,YES);
        UIScrollView *sv=wv.scrollView;
        if(sv.isOpaque) sv.opaque=NO;
        ADSetViewBackground7226(sv,black,YES);
        if(@available(iOS 15.0,*)) if(![wv.underPageBackgroundColor isEqual:black]) wv.underPageBackgroundColor=black;
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

// Amazon replaces/clears its WKUserContentController during cold navigation.
// v5/v6 explicitly restored AmazonDark's documentStart scripts after removeAllUserScripts;
// without this, cold Home/Search can miss the OLED sheet until a warm lifecycle reapply.
%hook WKUserContentController
- (void)removeAllUserScripts {
    %orig;
    if(gP.enabled){
        objc_setAssociatedObject(self,kADCoreWebUS7271,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self,kADTWBUS,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
    if(gP.enabled)ADApplyWebFloor(wv);
    return wv;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    id wv=%orig;
    if(gP.enabled&&wv){
        @try { ADAttachScriptsToUCC710(((WKWebView *)wv).configuration.userContentController); } @catch(...) {}
        ADApplyWebFloor(wv);
    }
    return wv;
}
- (void)didMoveToSuperview {
    %orig;
    if(gP.enabled && self.superview) ADApplyWebFloor(self);
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled && self.window)ADConsiderLaunchReady706();
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(gP.enabled){
        UIColor *black=ADOLED();
        %orig(black);
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
    // One mount owner is enough: prime the real WKScrollView before UIWindow
    // attachment and set the indicator style in the same event.
    if(gP.enabled && self.superview && strcmp(object_getClassName(self), "WKScrollView")==0){
        self.opaque=NO;
        ADSetViewBackground7226(self,ADOLED(),YES);
        self.indicatorStyle=UIScrollViewIndicatorStyleWhite;
    }
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(gP.enabled && strcmp(object_getClassName(self), "WKScrollView")==0){
        UIColor *black=ADOLED();
        %orig(black);
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
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
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
        ADSetViewBackground7226(self,ADOLED(),YES);
    }
}
%end

static UIColor *ADLightText706(void);
static UIColor *ADBorderGray706(void);

static inline BOOL ADClassNameHas7183(id obj,const char *needle){
    if(!obj||!needle)return NO;
    const char *cn=object_getClassName(obj);
    return cn&&strstr(cn,needle)!=NULL;
}
static inline char ADAsciiLower7183(char c){ return (c>='A'&&c<='Z')?(char)(c+('a'-'A')):c; }
static inline BOOL ADClassNameHasFold7183(id obj,const char *needleLower){
    if(!obj||!needleLower||!*needleLower)return NO;
    const char *cn=object_getClassName(obj); if(!cn)return NO;
    size_t nl=strlen(needleLower);
    for(const char *p=cn;*p;p++){
        size_t i=0; while(i<nl&&p[i]&&ADAsciiLower7183(p[i])==needleLower[i])i++;
        if(i==nl)return YES;
    }
    return NO;
}
static inline BOOL ADClassNameIs7183(id obj,const char *exact){
    if(!obj||!exact)return NO;
    const char *cn=object_getClassName(obj);
    return cn&&strcmp(cn,exact)==0;
}
static inline BOOL ADClassNamePrefix7183(id obj,const char *prefix){
    if(!obj||!prefix)return NO;
    const char *cn=object_getClassName(obj); if(!cn)return NO;
    size_t n=strlen(prefix);
    return strncmp(cn,prefix,n)==0;
}

// v7.0.24 — v6.0.185 tab-rendering mechanism, narrowed to the current ANX tab bar.
// Current requested palette: all tab glyphs white + selected indicator white.
static const void *kADTabIndicator724=&kADTabIndicator724;
static BOOL gADTabImageWriting724=NO;

static UIView *ADANXTabRoot724(UIView *v){
    if(!v)return nil;
    @try {
        UIView *n=v;
        for(int d=0;n&&d<12;d++,n=n.superview){
            if(ADClassNameHas7183(n,"ANXTabBarView"))return n;
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
                ADSetViewBackground7226(v,white,YES);
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
        ADSetViewBackground7226(root,ADOLED(),YES);
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
    if(!gP.enabled||!v||!v.window)return NO;
    @try {
        if(!ADClassNameIs7183(v,"GlowIngressView"))return NO;
        // v7.171: v7.169 rendered this exact Search delivery strip correctly. v7.170's
        // longer launch handoff can change controller timing, so do not make the proven
        // GlowIngress owner depend on primary-controller classification. Keep the exact
        // class, normal window level and compact top-band geometry gates instead.
        if(fabs(v.window.windowLevel-UIWindowLevelNormal)>0.1)return NO;
        CGRect r=[v convertRect:v.bounds toView:v.window], wb=v.window.bounds;
        if(wb.size.width<1.0)return NO;
        // v7.207: current device truth shows the same exact 430x44 Glow owner at y=75.
        // The old y>=90 gate made ownership launch-order dependent: a root first seen at
        // y~119 was marked, while one first laid out at y~75 could remain yellow. Keep the
        // exact private class/full-width/compact-height/normal-window contract, but accept
        // the complete observed top-nav travel range.
        return r.size.width>=wb.size.width*0.88 && r.size.height>=28.0 && r.size.height<=72.0 &&
               CGRectGetMinY(r)>=55.0 && CGRectGetMinY(r)<=220.0;
    } @catch(...) {}
    return NO;
}

// v7.139: v7.138's Web probe proves the yellow strip is outside the /s DOM (the
// WebView starts directly on the sf-rib30 filter ribbon). Historical Search captures
// consistently expose the 47pt native ANX sub-navigation controllers. Own only the
// compact, primary-window instance so full-screen/hidden subnav controller variants
// cannot be swept into this lane.
static void ADTintSearchDeliveryGlyph7139(UIImageView *iv);

// v7.192: the current Search probe again shows the exact 430x44 GlowIngressView
// while the yellow painter itself reports no UIView/layer background. Amazon is drawing
// that warm band into host contents/internal decoration. A CALayer floor can be lost or
// reordered by that renderer. Use one noninteractive OLED backing UIView inside each
// full-size painter host: it sits above the host's custom-drawn contents but below its
// label/image/control subviews, and is reasserted only on existing Glow lifecycle events.
static const void *kADGlowFloorView7192=&kADGlowFloorView7192;
static const void *kADGlowFloorSentinel7192=&kADGlowFloorSentinel7192;
static BOOL ADGlowFloorHost7141(UIView *v,UIView *root){
    if(!v||!root)return NO;
    if(objc_getAssociatedObject(v,kADGlowFloorSentinel7192))return NO;
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
static void ADInstallGlowFloorView7192(UIView *host){
    if(!host)return;
    @try {
        UIView *floor=(UIView *)objc_getAssociatedObject(host,kADGlowFloorView7192);
        if(!floor){
            floor=[[UIView alloc] initWithFrame:host.bounds];
            floor.userInteractionEnabled=NO;
            floor.accessibilityElementsHidden=YES;
            floor.opaque=YES;
            floor.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            objc_setAssociatedObject(floor,kADGlowFloorSentinel7192,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(host,kADGlowFloorView7192,floor,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        UIColor *black=ADOLED();
        floor.frame=host.bounds;
        if(![floor.backgroundColor isEqual:black])ADSetViewBackground7226(floor,black,YES);
        floor.hidden=NO;
        floor.alpha=1.0;
        if(floor.superview!=host)[host insertSubview:floor atIndex:0];
        else if(host.subviews.count && host.subviews.firstObject!=floor)[host insertSubview:floor atIndex:0];
    } @catch(...) {}
}
static void ADInstallGlowFloorTree7141(UIView *root){
    if(!ADExactGlowIngress7140(root))return;
    @try {
        NSMutableArray *q=[NSMutableArray arrayWithObject:root]; NSUInteger seen=0;
        while(seen<q.count&&seen<96){
            UIView *x=q[seen++]; if(!x)continue;
            BOOL sentinel=objc_getAssociatedObject(x,kADGlowFloorSentinel7192)!=nil;
            if(!sentinel && ADGlowFloorHost7141(x,root))ADInstallGlowFloorView7192(x);
            if(!sentinel && q.count-seen<96&&x.subviews.count)[q addObjectsFromArray:x.subviews];
        }
    } @catch(...) {}
}

static void ADOwnGlowIngress7140(UIView *root){
    if(!ADExactGlowIngress7140(root))return;
    @try {
        UIColor *black=ADOLED(), *light=ADLightText706();
        objc_setAssociatedObject(root,kADSearchDeliveryBand7139,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADSetViewBackground7226(root,black,YES);
        root.tintColor=light;
        // One bounded event-driven pass catches descendants that were mounted before
        // the exact root was marked. Later image/background writes are handled by hooks.
        NSMutableArray *q=[NSMutableArray arrayWithArray:root.subviews?:@[]]; NSUInteger seen=0;
        while(seen<q.count&&seen<96){
            UIView *x=q[seen++]; if(!x)continue;
            ADMarkSearchDeliveryDescendant7139(x);
            if([x isKindOfClass:[UIImageView class]]) ADTintSearchDeliveryGlyph7139((UIImageView *)x);
            else if([x isKindOfClass:[UILabel class]]) ((UILabel *)x).textColor=light;
            else if(ADWarmDeliveryColor7139(x.backgroundColor)||ADBrightNeutral7130(x.backgroundColor)){
                ADSetViewBackground7226(x,black,YES);
            }
            x.tintColor=light;
            if(q.count-seen<96&&x.subviews.count)[q addObjectsFromArray:x.subviews];
        }
        ADInstallGlowFloorTree7141(root);
    } @catch(...) {}
}
// Home visual-category cells are Amazon-authored stock UI and stay isolated from
// Search delivery-band ownership so the global UILabel owner cannot recolor them.
static BOOL ADInAuthoredVisualSubNav7175(UIView *v){
    if(!v)return NO;
    @try {
        for(UIView *n=v;n;n=n.superview){
            if(ADClassNameIs7183(n,"ANXVisualSubNavTextCollectionViewCell"))return YES;
            if([n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return NO;
}
// Home visual-category text/icon ink stays authored, while the exact cell owns one\n// uniform medium-gray floor. No generic UIKit/Search owner is allowed in this subtree.
static UIView *ADHomeVisualSubNavCell7211(UIView *v){
    if(!v)return nil;
    @try {
        for(UIView *n=v;n;n=n.superview){
            if(ADClassNameIs7183(n,"ANXVisualSubNavTextCollectionViewCell"))return n;
            if([n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return nil;
}
static void ADOwnHomeVisualSubNavCell7211(UIView *v){
    if(!gP.enabled||!v||!v.window)return;
    UIView *cell=ADHomeVisualSubNavCell7211(v);
    if(!cell)return;
    // One exact owner, one exact color.  Do not preserve Amazon's per-chip stock
    // fill and do not let generic UIKit floor logic touch this subtree.
    ADSetViewBackground7226(cell,ADHomeChipGray7226(),YES);
}
static BOOL ADSelectionPlatterChild7130(UIView *v, UIColor *candidate){
    if(!gP.enabled||!v||!v.window||!candidate)return NO;
    @try {
        if(strcmp(object_getClassName(v),"UIView")!=0)return NO;
        if(!ADClassNameIs7183(v.window,"AppCXWindow"))return NO;
        CGRect r=[v convertRect:v.bounds toView:v.window];
        CGFloat sw=v.window.bounds.size.width;
        if(sw<1.0||r.size.width<sw*0.60||r.size.height<18.0||r.size.height>130.0)return NO;
        if(!ADBrightNeutral7130(candidate))return NO;
        UIView *n=v.superview;
        for(int d=0;n&&d<8;d++,n=n.superview){
            if(ADClassNamePrefix7183(n,"_UIPlatter"))return YES;
            if([n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return NO;
}

// Search delivery ownership is singular: current device probes name GlowIngressView
// as the visible 430x44 painter. Alternate controller/Packard owners were removed.
static inline BOOL ADWebKitInternalView7154(UIView *v){
    if(!v)return NO;
    const char *cn=object_getClassName(v);
    return cn && ((cn[0]=='W'&&cn[1]=='K')||(cn[0]=='_'&&cn[1]=='W'&&cn[2]=='K'));
}
static inline BOOL ADReactNativeView7226(UIView *v){
    if(!v)return NO;
    const char *cn=object_getClassName(v);
    return cn && ((cn[0]=='R'&&cn[1]=='C'&&cn[2]=='T')||(cn[0]=='R'&&cn[1]=='N'));
}

// Classes with their own exact floor policy are excluded from the generic UIView
// owner. This prevents inherited/super setBackgroundColor: calls from taking a
// second AmazonDark paint path for the same object.
static const void *kADExactBackgroundOwnerClass7271=&kADExactBackgroundOwnerClass7271;
static BOOL ADExactBackgroundOwner7226(UIView *v){
    if(!v)return NO;
    Class cls=object_getClass(v); if(!cls)return NO;
    NSNumber *cached=objc_getAssociatedObject(cls,kADExactBackgroundOwnerClass7271);
    if(cached)return cached.boolValue;
    const char *cn=class_getName(cls); if(!cn)return NO;
    static const char *names[]={
        "UILayoutContainerView","UITransitionView","UINavigationTransitionView","UIViewControllerWrapperView",
        "AWLoadingIndicatorFullScreenModalBar","AWLoadingIndicatorWidgets_BkgView",
        "UIInputSetHostView","_UIRemoteKeyboardPlaceholderView",
        "SBSearchField","SBMultilineSearchView","A9VSScanItSearchWidget","ANPSearchBarRightButton",
        "UITabBar","_UIBarBackground","CXIStoreModesBottomNavToolbar","CXIStoreModesTabBarView",
        "ANPRetailTabBar","ANXTabBarView","ANXTopNavBackgroundView","GlowIngressView",
        "ANXVisualSubNavTextCollectionViewCell"
    };
    BOOL exact=NO;
    for(size_t i=0;i<sizeof(names)/sizeof(names[0]);i++)if(strcmp(cn,names[i])==0){ exact=YES; break; }
    objc_setAssociatedObject(cls,kADExactBackgroundOwnerClass7271,@(exact),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return exact;
}

// Location-sheet owners are defined with the React helpers below.
static BOOL ADLocationSheetFloor7196(UIView *v, UIColor *candidate);
static void ADLocationSheetOwnText7196(UIView *v);
static void ADPaintLocationSheetStable7196(UIView *outer);
// Person-tab and Search Packard owners live with the React/text helpers below.
enum { ADReactSurfaceNone7226=0, ADReactSurfacePerson7226=1, ADReactSurfaceLocation7226=2, ADReactSurfaceMenu7255=3 };
static const void *kADReactSurfaceCache7232=&kADReactSurfaceCache7232;
static int ADReactSurface7226(UIView *v);
static BOOL ADInPersonTab7206(UIView *v);
static BOOL ADInMenuTab7255(UIView *v);
static int ADMenuViewRole7255(UIView *v);
static void ADMenuOwnView7255(UIView *v);
static NSAttributedString *ADMenuLightString7255(NSAttributedString *in);
static void ADMenuLightStorage7255(NSTextStorage *ts);
static void ADMenuOwnText7255(UIView *v);
static BOOL ADPersonFloorCandidate7206(UIView *v, UIColor *candidate);
static void ADPersonOwnView7206(UIView *v);
static void ADPersonOwnText7206(UIView *v);
static void ADApplyNativeTWBCached7183(UIImageView *iv,BOOL authoredSubNav);
static void ADResetNativeTWBCache7214(UIImageView *iv);
static UIColor *ADNativeTWBOverlayColor7146(void);
static void ADPersonObserveSectionAnchor7212(UIView *v);
static BOOL ADPersonHighlightPlate7212(UIView *v);
static void ADPersonOwnHighlightPlate7212(UIView *v);
static BOOL ADPersonRightArrow7231(UIImageView *iv);
static BOOL ADPersonSectionChevron7217(UIImageView *iv);
static BOOL ADPersonHighlightImageContext7224(UIView *v);
static int ADPersonSectionKind7218(UIView *v);
static BOOL ADPersonBuyAgainItem7218(UIView *v);
static void ADPersonOwnBuyAgainItem7218(UIView *v);
static BOOL ADPersonBuyAgainOccluder7235(UIView *v);
static BOOL ADPersonAncestorAid7235(UIView *v,NSString *wanted,int maxDepth);
static BOOL ADPersonSubscribeOccluder7237(UIView *v);
static BOOL ADPersonKeepShoppingText7237(UIView *v);
static BOOL ADPersonAvatarImage7237(UIImageView *iv);
static BOOL ADPersonNotificationBadge7237(UIImageView *iv);
static BOOL ADPersonCountryFlag7237(UIImageView *iv);
static BOOL ADPersonInterestBorderPlate7235(UIView *v);
static void ADPersonOwnInterestBorderPlate7235(UIView *v);
static BOOL ADPersonListCard7235(UIView *v);
static void ADPersonOwnListCard7235(UIView *v);
static BOOL ADPersonNestedListBorder7239(UIView *v);
static void ADPersonSuppressNestedListBorder7239(UIView *v);

// v7.255: Amazon's native/RN bottom-sheet host used by Person savings and other
// in-app sheets. This is exact-context lifecycle ownership: no polling or hierarchy
// observer. Only neutral near-white floors and neutral near-black text are changed;
// saturated Amazon accents remain authored.
static BOOL ADNeutralNearWhite7255(UIColor *c){
    if(!c)return NO;
    @try {
        CGFloat r=0,g=0,b=0,a=0,w=0;
        if([c getRed:&r green:&g blue:&b alpha:&a]){
            CGFloat hi=MAX(r,MAX(g,b)),lo=MIN(r,MIN(g,b));
            return a>0.15 && ((r+g+b)/3.0)>0.78 && (hi-lo)<0.10;
        }
        if([c getWhite:&w alpha:&a])return a>0.15&&w>0.78;
    } @catch(...) {}
    return NO;
}
static BOOL ADNeutralNearBlack7255(UIColor *c){
    if(!c)return YES;
    @try {
        CGFloat r=0,g=0,b=0,a=0,w=0;
        if([c getRed:&r green:&g blue:&b alpha:&a]){
            CGFloat hi=MAX(r,MAX(g,b)),lo=MIN(r,MIN(g,b));
            return a>0.15 && ((r+g+b)/3.0)<0.24 && (hi-lo)<0.10;
        }
        if([c getWhite:&w alpha:&a])return a>0.15&&w<0.24;
    } @catch(...) {}
    return NO;
}

// v7.301: Amazon's native connectivity/error surface is the exact CNMErrorView
// family. The v7.300 Cart probe proves the bright screen is not Cart/WebKit: the
// 430pt CNMErrorView itself is white, its action buttons own white/near-white
// fills, while labels and the standard gray button border are already in the
// normal light/gray contracts. Own this class by ancestry so the same native
// error renderer is dark in Cart, Home, Person, Menu, Search, or any other route.
// This is event-driven setter/mount ownership only; no scan or recurring work.
static BOOL ADInCNMErrorView7301(UIView *v){
    if(!v)return NO;
    @try {
        UIView *n=v;
        for(int d=0;n&&d<18;d++,n=n.superview){
            if(ADClassNameIs7183(n,"CNMErrorView"))return YES;
            if([n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return NO;
}
// v7.309: the probe identifies the no-internet dog uniquely as a 640x524
// raster on the direct UIStackView UIImageView inside CNMErrorView. Apply the
// existing native TWB shade to that image only. Preserve the source pixels and
// authored white field; do not crop, key, rewrite, or broaden image eligibility.
static const void *kADCNMDogTWB7309=&kADCNMDogTWB7309;
static BOOL ADCNMExactDog7309(UIImageView *iv,UIImage *im){
    if(!iv||!im)return NO;
    @try {
        CGImageRef cg=im.CGImage;
        if(!cg||CGImageGetWidth(cg)!=640||CGImageGetHeight(cg)!=524)return NO;
        UIView *p=iv.superview;
        return p&&ADClassNameIs7183(p,"UIStackView")&&ADInCNMErrorView7301((UIView *)iv);
    } @catch(...) {}
    return NO;
}
static void ADApplyCNMExactDogTWB7309(UIImageView *iv){
    if(!iv)return;
    @try {
        CALayer *ov=objc_getAssociatedObject(iv,kADCNMDogTWB7309);
        BOOL own=gP.enabled&&gP.whiteTame&&iv.window&&ADCNMExactDog7309(iv,iv.image);
        if(!own){
            if(ov){
                [ov removeFromSuperlayer];
                objc_setAssociatedObject(iv,kADCNMDogTWB7309,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            return;
        }
        if(!ov){
            ov=[CALayer layer];
            ov.name=@"AmazonDarkCNMExactDogTWB7309";
            ov.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"backgroundColor":[NSNull null],@"zPosition":[NSNull null]};
            [iv.layer addSublayer:ov];
            objc_setAssociatedObject(iv,kADCNMDogTWB7309,ov,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(ov.superlayer!=iv.layer){
            [iv.layer addSublayer:ov];
        }
        ov.frame=iv.bounds;
        ov.backgroundColor=ADNativeTWBOverlayColor7146().CGColor;
        ov.zPosition=FLT_MAX;
    } @catch(...) {}
}
static void ADOwnCNMErrorView7301(UIView *v,UIColor *candidate){
    if(!gP.enabled||!v||!ADInCNMErrorView7301(v))return;
    @try {
        BOOL root=ADClassNameIs7183(v,"CNMErrorView"),button=[v isKindOfClass:[UIButton class]];
        UIColor *bg=candidate?:v.backgroundColor,*layerBG=v.layer.backgroundColor?[UIColor colorWithCGColor:v.layer.backgroundColor]:nil;
        if(root||button||ADNeutralNearWhite7255(bg)||ADNeutralNearWhite7255(layerBG))ADSetViewBackground7226(v,ADOLED(),YES);
        if(button){
            v.layer.borderWidth=1.0;
            v.layer.borderColor=ADBorderGray706().CGColor;
            v.layer.shadowOpacity=0.0;
            v.layer.shadowColor=[UIColor clearColor].CGColor;
        }
        if([v isKindOfClass:[UILabel class]]){
            UILabel *l=(UILabel *)v;
            UIColor *light=ADLightText706(); if(![l.textColor isEqual:light])l.textColor=light;
        }
    } @catch(...) {}
}
// v7.256: the AppCX sheet also owns two ordinary UIView safe-area/chrome strips
// as siblings of AppCXBottomSheet.  Gate them through the exact passthrough root so
// unrelated native sheets are never painted.
static BOOL ADInAppCXPassthrough7256(UIView *v){
    if(!v)return NO;
    @try {
        for(UIView *n=v;n;n=n.superview){
            if([n.accessibilityIdentifier isEqualToString:@"AppCXTouchPassthroughView"])return YES;
            if([n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADInAppCXBottomSheet7255(UIView *v){
    if(!v)return NO;
    @try {
        for(UIView *n=v;n;n=n.superview){
            NSString *aid=n.accessibilityIdentifier?:@"";
            NSString *cn=NSStringFromClass([n class])?:@"";
            if([aid isEqualToString:@"AppCXBottomSheet"]||[aid isEqualToString:@"AppCXBottomSheetContentView"]||
               [cn rangeOfString:@"ABSTopChromeView" options:NSCaseInsensitiveSearch].location!=NSNotFound) return YES;
            if([n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return NO;
}
typedef BOOL (*ADNeutralTextPredicate7271)(UIColor *);
static NSAttributedString *ADLightNeutralString7271(NSAttributedString *in,ADNeutralTextPredicate7271 predicate){
    if(!in.length||!predicate)return in;
    @try {
        UIColor *light=ADLightText706(); __block NSMutableAttributedString *m=nil;
        [in enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0,in.length) options:0 usingBlock:^(id value,NSRange range,BOOL *stop){
            UIColor *c=[value isKindOfClass:[UIColor class]]?value:nil;
            if(!predicate(c)||[c isEqual:light])return;
            if(!m)m=[in mutableCopy];
            [m addAttribute:NSForegroundColorAttributeName value:light range:range];
        }];
        return m?:in;
    } @catch(...) { return in; }
}
static void ADLightNeutralStorage7271(NSTextStorage *ts,ADNeutralTextPredicate7271 predicate){
    if(!ts.length||!predicate)return;
    @try {
        UIColor *light=ADLightText706(); __block NSMutableArray<NSValue *> *ranges=nil;
        [ts enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0,ts.length) options:0 usingBlock:^(id value,NSRange range,BOOL *stop){
            UIColor *c=[value isKindOfClass:[UIColor class]]?value:nil;
            if(!predicate(c)||[c isEqual:light])return;
            if(!ranges)ranges=[NSMutableArray array];
            [ranges addObject:[NSValue valueWithRange:range]];
        }];
        if(!ranges.count)return;
        [ts beginEditing];
        for(NSValue *range in ranges)[ts addAttribute:NSForegroundColorAttributeName value:light range:range.rangeValue];
        [ts endEditing];
    } @catch(...) {}
}
static NSAttributedString *ADAppCXSheetLightString7255(NSAttributedString *in){
    return ADLightNeutralString7271(in,ADNeutralNearBlack7255);
}
static void ADAppCXSheetLightStorage7255(NSTextStorage *ts){
    ADLightNeutralStorage7271(ts,ADNeutralNearBlack7255);
}
static void ADOwnAppCXSheetFloor7255(UIView *v){
    if(!gP.enabled||!v||!v.window||!ADInAppCXBottomSheet7255(v))return;
    @try {
        UIColor *bg=v.backgroundColor; UIColor *layerBG=nil;
        if(v.layer.backgroundColor)layerBG=[UIColor colorWithCGColor:v.layer.backgroundColor];
        if(ADNeutralNearWhite7255(bg)||ADNeutralNearWhite7255(layerBG)){
            ADSetViewBackground7226(v,ADOLED(),YES);
        }
    } @catch(...) {}
}

// v7.260: the corrected v7.258 Person probe finally captures the visible savings
// sheet.  It is not the hidden AppCXBottomSheet tree: it is a foreground React
// `sheet-view` / `sheet-inset-view` surface in AppCXWindow, uniquely identified
// by the `cvm-metab-bottomsheet-titlettl` descendant.  Keep ownership exact to
// that hydrated sheet.  Only neutral light floors and neutral dark text change;
// authored orange/yellow/blue and other saturated Amazon semantics remain stock.
static const void *kADPersonSavingsSheet7259=&kADPersonSavingsSheet7259;
static BOOL ADDarkNeutral7259(UIColor *color,BOOL nilIsDark){
    if(!color)return nilIsDark;
    @try {
        CGFloat r=0,g=0,b=0,a=0,w=0; UIColor *probe=color;
        if([probe respondsToSelector:@selector(resolvedColorWithTraitCollection:)])
            probe=[probe resolvedColorWithTraitCollection:UIScreen.mainScreen.traitCollection];
        if([probe getRed:&r green:&g blue:&b alpha:&a]){
            if(a<0.08)return NO;
            CGFloat hi=MAX(r,MAX(g,b)),lo=MIN(r,MIN(g,b));
            return (hi-lo)<=0.16&&hi<0.50;
        }
        if([probe getWhite:&w alpha:&a])return a>=0.08&&w<0.50;
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonSavingsDarkNeutral7259(UIColor *color){ return ADDarkNeutral7259(color,NO); }
static UIView *ADPersonSavingsSheetRoot7259(UIView *v){
    if(!v||!v.window||!ADClassNameIs7183(v.window,"AppCXWindow"))return nil;
    @try {
        UIView *root=nil;
        for(UIView *n=v;n;n=n.superview){
            if(ADClassNameIs7183(n,"RCTView")&&[n.accessibilityIdentifier isEqualToString:@"sheet-view"]){ root=n; break; }
            if([n isKindOfClass:[UIWindow class]])break;
        }
        if(!root)return nil;
        if([objc_getAssociatedObject(root,kADPersonSavingsSheet7259) boolValue])return root;
        NSMutableArray *q=[NSMutableArray arrayWithObject:root]; NSUInteger seen=0; BOOL inset=NO,title=NO;
        while(seen<q.count&&seen<96){
            UIView *x=q[seen++]; if(!x)continue;
            NSString *aid=x.accessibilityIdentifier?:@"";
            if([aid isEqualToString:@"sheet-inset-view"])inset=YES;
            if([aid isEqualToString:@"cvm-metab-bottomsheet-titlettl"])title=YES;
            if(inset&&title)break;
            if(x.subviews.count)[q addObjectsFromArray:x.subviews];
        }
        if(inset&&title){
            objc_setAssociatedObject(root,kADPersonSavingsSheet7259,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return root;
        }
    } @catch(...) {}
    return nil;
}
static BOOL ADInPersonSavingsSheet7259(UIView *v){ return ADPersonSavingsSheetRoot7259(v)!=nil; }
static NSAttributedString *ADPersonSavingsLightString7259(NSAttributedString *in){
    return ADLightNeutralString7271(in,ADPersonSavingsDarkNeutral7259);
}
static void ADPersonSavingsLightStorage7259(NSTextStorage *ts){
    ADLightNeutralStorage7271(ts,ADPersonSavingsDarkNeutral7259);
}
static void ADOwnPersonSavingsFloor7259(UIView *v){
    if(!gP.enabled||!v||!v.window||!ADInPersonSavingsSheet7259(v))return;
    @try {
        UIColor *bg=v.backgroundColor,*layerBG=nil;
        if(v.layer.backgroundColor)layerBG=[UIColor colorWithCGColor:v.layer.backgroundColor];
        if(ADNeutralNearWhite7255(bg)||ADNeutralNearWhite7255(layerBG))ADSetViewBackground7226(v,ADOLED(),YES);
    } @catch(...) {}
}

%hook UIView
- (void)didMoveToWindow {
    %orig;
    if(!gP.enabled||!self.window)return;
    // Exact universal native error owner gets first refusal. Avoid even React/AppCX
    // classification on the CNM subtree; this surface is probe-proven UIKit.
    if(ADInCNMErrorView7301(self)){ ADOwnCNMErrorView7301(self,self.backgroundColor); return; }
    BOOL react=ADReactNativeView7226(self);
    if(ADClassNameIs7183(self.window,"AppCXWindow")){
        if(!react&&ADInAppCXPassthrough7256(self)&&ADNeutralNearWhite7255(self.backgroundColor))ADSetViewBackground7226(self,ADOLED(),YES);
        if(ADInAppCXBottomSheet7255(self))ADOwnAppCXSheetFloor7255(self);
        if(ADInPersonSavingsSheet7259(self))ADOwnPersonSavingsFloor7259(self);
    }
    // Exact owners win. Generic UIView never repaints WebKit, React Native, or
    // Amazon's authored Home category subtree.
    if(ADWebKitInternalView7154(self)||ADReactNativeView7226(self)||ADExactBackgroundOwner7226(self)||ADInAuthoredVisualSubNav7175(self))return;
    if(ADInMarkedSearchDeliveryBand7139(self)&&![self isKindOfClass:[UIImageView class]]){
        ADSetViewBackground7226(self,ADOLED(),YES); return;
    }
    if(ADMarkedTransitionBacking7133(self)&&ADPrimaryAmazonWindow713(self.window,nil)){
        ADSetViewBackground7226(self,ADOLED(),YES); return;
    }
    if(ADSelectionPlatterChild7130(self,self.backgroundColor)){
        ADSetViewBackground7226(self,ADOLED(),YES); return;
    }
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(!gP.enabled){
        %orig(color);
        return;
    }
    // Keep CNM ownership ahead of generic React/AppCX classification.
    if(ADInCNMErrorView7301(self)){
        BOOL root=ADClassNameIs7183(self,"CNMErrorView"),button=[self isKindOfClass:[UIButton class]];
        if(root||button||ADNeutralNearWhite7255(color)){
            UIColor *black=ADOLED(); %orig(black);
            if(button){ self.layer.borderWidth=1.0; self.layer.borderColor=ADBorderGray706().CGColor; self.layer.shadowOpacity=0.0; self.layer.shadowColor=[UIColor clearColor].CGColor; }
            return;
        }
    }
    BOOL react=ADReactNativeView7226(self);
    if(self.window&&ADClassNameIs7183(self.window,"AppCXWindow")){
        if(!react&&ADInAppCXPassthrough7256(self)&&ADNeutralNearWhite7255(color)){
            UIColor *black=ADOLED();
            %orig(black);
            return;
        }
        if((ADInAppCXBottomSheet7255(self)||ADInPersonSavingsSheet7259(self))&&ADNeutralNearWhite7255(color)){
            UIColor *black=ADOLED();
            %orig(black);
            return;
        }
    }
    if(ADWebKitInternalView7154(self)||react||ADExactBackgroundOwner7226(self)||ADInAuthoredVisualSubNav7175(self)){
        %orig(color);
        return;
    }
    if(gP.enabled&&self.window&&ADInMarkedSearchDeliveryBand7139(self)&&![self isKindOfClass:[UIImageView class]]){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    if(ADMarkedTransitionBacking7133(self)&&(!self.window||ADPrimaryAmazonWindow713(self.window,nil))){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    if(self.window&&ADSelectionPlatterChild7130(self,color)){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    if(objc_getAssociatedObject(self,kADTabIndicator724)){
        UIColor *light=ADLightText706();
        %orig(light);
        return;
    }
    %orig(color);
}
%end

static BOOL ADTopChromeClass713(UIView *v){
    if(!v)return NO;
    @try {
        UIView *n=v;
        for(int d=0;n&&d<10;d++,n=n.superview){
            if(ADClassNameHasFold7183(n,"anxtopnav")||ADClassNameHasFold7183(n,"topmainbar")||
               ADClassNameHasFold7183(n,"statusbarinset")||ADClassNameHasFold7183(n,"topnav")) return YES;
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
        return ADClassNameHasFold7183(vc,"anpdockedtabbar")||ADClassNameHasFold7183(vc,"anxtabroot")||
               ADClassNameHasFold7183(vc,"anxtopmainbar")||ADClassNameHasFold7183(vc,"anxsubnav")||
               ADClassNameHasFold7183(vc,"anxvisualsubnav")||ADClassNameHasFold7183(vc,"sxwebresults")||
               ADClassNameHasFold7183(vc,"anptopnav")||ADClassNameHasFold7183(vc,"cxistatusbarinset");
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
            primary=ADClassNameHasFold7183(vc,"splash")||ADClassNameHasFold7183(vc,"launchscreen");
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
        ADSetViewBackground7226(v,black,YES);
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
    ADSetViewBackground7226(v,black,YES);
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
static BOOL ADWebPlatter7129(UIView *v){
    if(!v||!v.window||!gP.enabled)return NO;
    @try {
        // Text-selection platters are portal-mounted siblings of WebKit content on
        // this iOS build, so WK ancestor testing is wrong.  The exact private
        // platter class + primary AppCXWindow + row-sized geometry is sufficient.
        if(!ADClassNamePrefix7183(v,"_UIPlatter"))return NO;
        if(!ADClassNameIs7183(v.window,"AppCXWindow"))return NO;
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
        ADSetViewBackground7226(root,black,YES);
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
            if(vc&&strcmp(vc,"UIView")==0&&v.layer.contents==nil&&ADBrightNeutral7130(v.backgroundColor)){
                ADSetViewBackground7226(v,black,YES);
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
- (void)layoutSubviews {
    %orig;
    ADPaintPrimaryLargeFloor7129((UIView *)self);
    ADPaintWrapperChildren7129((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(ADPrimaryLargeFloor7129((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
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
- (void)layoutSubviews {
    %orig;
    ADPaintPrimaryLargeFloor7129((UIView *)self);
    ADPaintWrapperChildren7129((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(ADPrimaryLargeFloor7129((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
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
- (void)layoutSubviews {
    %orig;
    ADPaintPrimaryLargeFloor7129((UIView *)self);
    ADPaintWrapperChildren7129((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(ADPrimaryLargeFloor7129((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
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
- (void)layoutSubviews {
    %orig;
    ADPaintPrimaryLargeFloor7129((UIView *)self);
    ADPaintWrapperChildren7129((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(ADPrimaryLargeFloor7129((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
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
        if(!ADClassNameIs7183(v.window,"AppCXWindow"))return NO;
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
        ADSetViewBackground7226(v,black,YES);
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
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(ADAppLoadingSurface7130((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
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
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(ADAppLoadingSurface7130((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
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
            if(ADClassNameIs7183(child,"UIKeyboardDockView"))
                return child.hidden||child.alpha<=0.01;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADLowerKeyboardSurface7130(UIView *v){
    if(!gP.enabled||!v||!v.window||!ADHiddenKeyboardDock7130(v))return NO;
    @try {
        if(!ADClassNameIs7183(v.window,"UITextEffectsWindow"))return NO;
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
        ADSetViewBackground7226(v,black,YES);
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
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(ADLowerKeyboardSurface7130((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
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
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(ADLowerKeyboardSurface7130((UIView *)self)){
        UIColor *black=ADOLED();
        %orig(black);
        ADBlackBackingLayer7130((UIView *)self,kADKeyboardBacking7130);
        return;
    }
    %orig(color);
}
%end

static const void *kADStatusOrig713=&kADStatusOrig713;
static const void *kADStatusClaimed713=&kADStatusClaimed713;
static UIStatusBarStyle ADStatusLightIMP713(id self, SEL _cmd){
    if(gP.enabled)return UIStatusBarStyleLightContent;
    @try {
        for(Class cls=object_getClass(self);cls;cls=class_getSuperclass(cls)){
            NSValue *value=objc_getAssociatedObject(cls,kADStatusOrig713);
            IMP imp=NULL;
            if(value)[value getValue:&imp];
            if(imp)return ((UIStatusBarStyle(*)(id,SEL))imp)(self,_cmd);
        }
    } @catch(...) {}
    return UIStatusBarStyleDefault;
}
static void ADClaimStatusController713(UIViewController *vc){
    if(!vc)return;
    @try {
        Class cls=object_getClass(vc);
        if(!objc_getAssociatedObject(cls,kADStatusClaimed713))@synchronized(cls){
            if(!objc_getAssociatedObject(cls,kADStatusClaimed713)){
                SEL sel=@selector(preferredStatusBarStyle); Method m=class_getInstanceMethod(cls,sel);
                IMP orig=m?method_getImplementation(m):NULL;
                if(orig!=(IMP)ADStatusLightIMP713){
                    const char *types=m?method_getTypeEncoding(m):"q@:";
                    if(orig)objc_setAssociatedObject(cls,kADStatusOrig713,[NSValue value:&orig withObjCType:@encode(IMP)],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    if(!class_addMethod(cls,sel,(IMP)ADStatusLightIMP713,types))class_replaceMethod(cls,sel,(IMP)ADStatusLightIMP713,types);
                }
                objc_setAssociatedObject(cls,kADStatusClaimed713,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
static BOOL ADStringHasAny7226(NSString *s,NSArray<NSString *> *tokens){
    if(!s.length||!tokens.count)return NO;
    @try {
        for(NSString *t in tokens)
            if([s rangeOfString:t options:NSCaseInsensitiveSearch].location!=NSNotFound)return YES;
    } @catch(...) {}
    return NO;
}
static NSArray<NSString *> *ADLocationMetadataTokens7226(void){
    static NSArray *a=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ a=@[@"location",@"delivery",@"address",@"map pin",@"pin icon"]; });
    return a;
}
static NSArray<NSString *> *ADPersonControlTokens7226(void){
    static NSArray *a=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ a=@[@"avatar",@"profile",@"logo",@"badge",@"star",@"rating",@"checkbox",@"heart",@"camera",@"microphone",@"nav",@"tab"]; });
    return a;
}
static NSArray<NSString *> *ADPersonGlyphTokens7226(void){
    static NSArray *a=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ a=@[@"icon",@"glyph",@"arrow",@"chevron",@"prime"]; });
    return a;
}
static NSArray<NSString *> *ADNativeControlTokens7226(void){
    static NSArray *a=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ a=@[@"icon",@"glyph",@"logo",@"avatar",@"profile",@"badge",@"star",@"rating",@"checkbox",@"heart",@"arrow",@"chevron",@"button",@"search",@"menu",@"microphone",@"camera",@"cart",@"location",@"nav",@"tab",@"sprite",@"brand",@"seller",@"store",@"screenshot",@"snapshot",@"screen shot",@"share preview",@"preview"]; });
    return a;
}
static NSArray<NSString *> *ADNativeProductTokens7226(void){
    static NSArray *a=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ a=@[@"product",@"asin",@"item",@"offer",@"recommend",@"reorder",@"buy again",@"keep shopping",@"shopping for",@"retail image"]; });
    return a;
}

static BOOL ADInBottomNav706(UIView *v){
    @try { UIView *n=v; for(int d=0;n&&d<12;d++,n=n.superview){
        if(ADClassNameHasFold7183(n,"bottomnav")||ADClassNameHasFold7183(n,"tabbar")||
           ADClassNameHasFold7183(n,"navtoolbar")||ADClassNameHasFold7183(n,"storemodestab")) return YES;
    }} @catch(...) {}
    return NO;
}
static BOOL ADInSearchChrome706(UIView *v){
    @try { UIView *n=v; for(int d=0;n&&d<10;d++,n=n.superview){
        if(ADClassNameHasFold7183(n,"sbsearchbar")||ADClassNameHasFold7183(n,"sbsearchfield")||
           ADClassNameHasFold7183(n,"sbmultilinesearchview")||ADClassNameHasFold7183(n,"searchbar")||
           ADClassNameHasFold7183(n,"searchfield")||ADClassNameHasFold7183(n,"scanitsearchwidget")) return YES;
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
               ([lab isEqualToString:@"back"]&&ADClassNameHasFold7183(n,"button"))) return YES;
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
        NSArray *tokens=ADLocationMetadataTokens7226();
        for(UIView *n=iv;n&&n!=iv.window;n=n.superview){
            if(ADStringHasAny7226(NSStringFromClass(n.class),tokens)||
               ADStringHasAny7226(n.accessibilityLabel,tokens)||
               ADStringHasAny7226(n.accessibilityIdentifier,tokens))return YES;
            if(n!=iv&&ADClassNameIs7183(n,"SNPRootView"))break;
        }
    } @catch(...) {}
    return NO;
}
static void ADTintSearchGlyph706(UIImageView *iv){
    if(!gP.enabled||!iv||!iv.image)return;
    CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
    if(w<3||h<3||w>64||h>64)return;
    BOOL search=ADInSearchChrome706(iv), location=NO, back=NO;
    if(!search){
        location=ADIsLocationGlyph709(iv);
        if(!location)back=ADIsSearchBackGlyph7120(iv);
    }
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

// v7.243: make the already-proven v7.126 OLED keyboard contract universal inside
// Amazon instead of trying to recognize individual input surfaces.  AmazonDark.plist
// already filters these hooks to com.amazon.Amazon, so every native text responder in
// this process can safely request UIKeyboardAppearanceDark.  This is cheaper and more
// robust than maintaining Search/Person/Cart ancestry predicates, and it exactly ports
// the working Search-panel behavior to React Native fields such as Person > Search orders.
static void ADPrepareSearchKeyboard7120(UIView *v){
    if(!gP.enabled||!v)return;
    @try {
        SEL sel=@selector(setKeyboardAppearance:);
        if([v respondsToSelector:sel]) ((void(*)(id,SEL,NSInteger))objc_msgSend)(v,sel,(NSInteger)UIKeyboardAppearanceDark);
    } @catch(...) {}
}

// v7.126 — port the stable OledKeyboard ownership model instead of tinting the
// full UITextEffectsWindow/UIInputSet compositor.  The donor tweak has been
// tested by its author through iOS 17.4.1.  We independently mirror the small
// set of UIKit owners it uses: the keyboard floor, prediction panel, notched
// dock, emoji/autofill input surfaces, and keyboard visual-effect backing.
// AmazonDark's bundle filter already confines these hooks to com.amazon.Amazon.
static void ADSetKeyboardFloor7126(UIView *view){
    if(!gP.enabled||!view)return;
    @try {
        // Keep the actual keyboard hierarchy in dark appearance even though Amazon's
        // application trait is light.  This complements keyboardAppearance=Dark on
        // the responder and makes the existing v7.126 floor/dock owner universal.
        if(@available(iOS 13.0,*))view.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
        ADSetViewBackground7226(view,ADOLED(),YES);
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
            ADSetViewBackground7226(self.view,ADOLED(),YES);
            ADSetViewBackground7226(keyboard,ADOLED(),YES);
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
        static Class emoji=nil,autofill=nil; static dispatch_once_t once;
        dispatch_once(&once,^{ emoji=objc_getClass("TUIEmojiSearchInputView"); autofill=objc_getClass("_SFAutoFillInputView"); });
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
        self.backgroundEffects=nil;
        ADSetViewBackground7226((UIView *)self,ADOLED(),YES);
    } @catch(...) {}
}
%end

static NSAttributedString *ADLightAttributedText708(NSAttributedString *in){
    if(!gP.enabled || !in || in.length==0) return in;
    @try {
        UIColor *light=ADLightText706(); NSRange whole=NSMakeRange(0,in.length),range=NSMakeRange(0,0);
        id c=[in attribute:NSForegroundColorAttributeName atIndex:0 longestEffectiveRange:&range inRange:whole];
        if(range.location==0 && NSMaxRange(range)==in.length && [c isKindOfClass:[UIColor class]] && [(UIColor *)c isEqual:light]) return in;
        NSMutableAttributedString *m=[in mutableCopy];
        [m addAttribute:NSForegroundColorAttributeName value:light range:whole];
        return m;
    } @catch(...) { return in; }
}
static BOOL ADBrightNeutralColor708(UIColor *u){
    if(!u)return NO;
    @try {
        CGFloat r=0,g=0,b=0,a=0,w=0;
        if([u getRed:&r green:&g blue:&b alpha:&a]){
            CGFloat mx=MAX(r,MAX(g,b)),mn=MIN(r,MIN(g,b));
            return a>0.15 && mx>0.72 && (mx-mn)<0.18;
        }
        if([u getWhite:&w alpha:&a]) return a>0.15 && w>0.72;
    } @catch(...) {}
    return NO;
}
static BOOL ADBrightNeutralUIView708(UIView *v){ return v&&ADBrightNeutralColor708(v.backgroundColor); }


// v7.196: Search's "Choose your location" React Native sheet.
// v7.195 proved final-layout ownership for the main lower sheet floor. The remaining
// white pieces are two different lifecycle families: the 18pt seam is a sibling of
// the vertical scroller, while the three 140x130 address cards live inside a separate
// horizontal RCTScrollView. Own those exact local structures from their own layout
// events instead of relying on a one-shot traversal of the outer sheet.
//
// No global scan, timer, observer, scroll callback, or recurring document work.
static BOOL ADColorLinkBlue7196(UIColor *c){
    if(!c)return NO;
    @try {
        CGFloat r=0,g=0,b=0,a=0;
        if(![c getRed:&r green:&g blue:&b alpha:&a]||a<0.20)return NO;
        return b>0.48 && b>r+0.24 && b>g+0.08;
    } @catch(...) {}
    return NO;
}
static UIView *ADLocationSheetRoot7196(UIView *v){
    if(!v||!v.window)return nil;
    @try {
        CGRect wb=v.window.bounds;
        for(UIView *n=v;n;n=n.superview){
            if(ADClassNameIs7183(n,"SNPRootView")){
                CGRect r=[n convertRect:n.bounds toView:v.window];
                if(r.size.width>=wb.size.width*0.90&&r.size.height>=wb.size.height*0.85)return n;
                return nil;
            }
            if([n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return nil;
}
static UIView *ADLocationSheetOuterScroll7196(UIView *v){
    if(!v||!v.window||!ADLocationSheetRoot7196(v))return nil;
    @try {
        CGRect wb=v.window.bounds;
        for(UIView *n=v;n;n=n.superview){
            if(ADClassNameIs7183(n,"RCTScrollView")){
                CGRect r=[n convertRect:n.bounds toView:v.window];
                if(r.size.width>=wb.size.width*0.80&&r.size.width<=wb.size.width*0.98&&
                   r.size.height>=wb.size.height*0.25&&r.size.height<=wb.size.height*0.50&&
                   CGRectGetMinY(r)>=wb.size.height*0.50&&CGRectGetMinY(r)<=wb.size.height*0.70)
                    return n;
            }
            if(ADClassNameIs7183(n,"SNPRootView")||[n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return nil;
}
static UIView *ADLocationSheetCardScroll7196(UIView *v){
    if(!v||!v.window||!ADLocationSheetRoot7196(v))return nil;
    @try {
        CGRect wb=v.window.bounds;
        for(UIView *n=v;n;n=n.superview){
            if(ADClassNameIs7183(n,"RCTScrollView")){
                CGRect r=[n convertRect:n.bounds toView:v.window];
                if(r.size.width>=wb.size.width*0.80&&r.size.width<=wb.size.width*0.98&&
                   r.size.height>=100.0&&r.size.height<=180.0&&
                   CGRectGetMinY(r)>=wb.size.height*0.62&&CGRectGetMinY(r)<=wb.size.height*0.78)
                    return n;
            }
            if(ADClassNameIs7183(n,"SNPRootView")||[n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return nil;
}
// v7.202: first-paint location-sheet ownership.
// v7.199-v7.201 proved that the three 140x130 address wrappers exist while the
// visible card RCTViews and one duplicate 18pt seam can still carry Amazon's
// stock bright colors.  Do not key this path to screen Y or to one panel copy.
// Mark the full-screen SNPRootView as soon as an exact address wrapper exists,
// then own every matching location panel/card copy inside that root.
static const void *kADLocationRootFirstPaint7202=&kADLocationRootFirstPaint7202;
static const void *kADLocationRootPrimed7226=&kADLocationRootPrimed7226;
static UIView *ADLocationRootAny7202(UIView *v){
    if(!v)return nil;
    @try {
        CGRect sb=[UIScreen mainScreen].bounds;
        for(UIView *n=v;n;n=n.superview){
            if(ADClassNameIs7183(n,"SNPRootView")){
                CGRect b=n.bounds;
                if(b.size.width>=sb.size.width*0.90&&b.size.height>=sb.size.height*0.85)return n;
                return nil;
            }
            if([n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return nil;
}
static BOOL ADLocationEarlyWrapper7202(UIView *v, UIView **rootOut){
    if(rootOut)*rootOut=nil;
    if(!v||!ADClassNameIs7183(v,"RNCEKVExternalKeyboardView"))return NO;
    @try {
        CGRect b=v.bounds;
        if(b.size.width<118.0||b.size.width>165.0||b.size.height<108.0||b.size.height>155.0)return NO;

        // v7.204: do not require the card RCTScrollView to have its final 130pt
        // height before accepting the wrapper.  The lifecycle probe proved the
        // exact wrapper mounts ~20ms before that ancestor receives final layout,
        // so the old 100..180pt height gate rejected every valid first-paint event.
        // Qualify by the stable React hierarchy instead:
        // RNCEKV -> cell RCTView -> RCTScrollContentView -> RCTCustomScrollView
        // -> RCTScrollView -> ... -> full-screen SNPRootView.
        NSInteger stage=0; BOOL cardScrollStructure=NO; UIView *root=nil;
        for(UIView *n=v.superview;n;n=n.superview){
            if(stage==0 && ADClassNameIs7183(n,"RCTScrollContentView")){ stage=1; continue; }
            if(stage==1 && ADClassNameIs7183(n,"RCTCustomScrollView")){ stage=2; continue; }
            if(stage==2 && ADClassNameIs7183(n,"RCTScrollView")){ stage=3; cardScrollStructure=YES; }
            if(ADClassNameIs7183(n,"SNPRootView")){ root=ADLocationRootAny7202(n); break; }
            if([n isKindOfClass:[UIWindow class]])break;
        }
        if(root&&cardScrollStructure){ if(rootOut)*rootOut=root; return YES; }
    } @catch(...) {}
    return NO;
}
static BOOL ADLocationRootActive7202(UIView *v, UIView **rootOut){
    if(rootOut)*rootOut=nil;
    UIView *root=ADLocationRootAny7202(v); if(!root)return NO;
    if(!objc_getAssociatedObject(root,kADLocationRootFirstPaint7202))return NO;
    if(rootOut)*rootOut=root;
    return YES;
}

// Location-sheet lifecycle diagnostics removed from production in v7.226.
static BOOL ADLocationEarlyCard7202(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGRect b=v.bounds;
        if(b.size.width<118.0||b.size.width>165.0||b.size.height<108.0||b.size.height>155.0)return NO;
        for(UIView *n=v.superview;n;n=n.superview){
            if(ADClassNameIs7183(n,"RNCEKVExternalKeyboardView")){
                UIView *root=nil;
                if(ADLocationEarlyWrapper7202(n,&root)){
                    CGRect nb=n.bounds;
                    return fabs(nb.size.width-b.size.width)<=4.0&&fabs(nb.size.height-b.size.height)<=4.0;
                }
            }
            if(ADClassNameIs7183(n,"SNPRootView")||[n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADInsideLocationEarlyCard7202(UIView *v){
    if(!v)return NO;
    @try {
        for(UIView *n=v;n;n=n.superview){
            if(ADLocationEarlyCard7202(n))return YES;
            if(ADClassNameIs7183(n,"SNPRootView")||[n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADLocationPanelShape7202(UIView *p, UIView *root){
    if(!p||!root||!ADClassNameIs7183(p,"RCTView"))return NO;
    @try {
        CGRect pb=p.bounds,rb=root.bounds;
        if(pb.size.width<rb.size.width*0.95||pb.size.width>rb.size.width*1.05||pb.size.height<150.0||pb.size.height>470.0)return NO;
        BOOL seam=NO,floor=NO;
        for(UIView *x in p.subviews){
            if(!ADClassNameIs7183(x,"RCTView"))continue;
            CGRect f=x.frame;
            if(f.size.width<pb.size.width*0.95||f.origin.x<-3.0||f.origin.x>3.0)continue;
            if(f.origin.y>=-3.0&&f.origin.y<=6.0&&f.size.height>=10.0&&f.size.height<=28.0)seam=YES;
            if(f.origin.y>=8.0&&f.origin.y<=36.0&&f.size.height>=pb.size.height*0.55&&CGRectGetMaxY(f)>=pb.size.height-6.0)floor=YES;
        }
        return seam||floor;
    } @catch(...) {}
    return NO;
}
static BOOL ADLocationEarlySeam7202(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return NO;
    UIView *root=nil; if(!ADLocationRootActive7202(v,&root))return NO;
    @try {
        CGRect b=v.bounds,rb=root.bounds;
        if(b.size.width<rb.size.width*0.95||b.size.height<10.0||b.size.height>28.0)return NO;
        return ADLocationPanelShape7202(v.superview,root);
    } @catch(...) {}
    return NO;
}
static BOOL ADLocationEarlyOuterFloor7202(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return NO;
    UIView *root=nil; if(!ADLocationRootActive7202(v,&root))return NO;
    @try {
        CGRect b=v.bounds,rb=root.bounds;
        if(b.size.width<rb.size.width*0.95||b.size.height<120.0||b.size.height>460.0)return NO;
        return ADLocationPanelShape7202(v.superview,root);
    } @catch(...) {}
    return NO;
}
static BOOL ADLocationEarlyFloor7202(UIView *v){
    return ADLocationEarlyCard7202(v)||ADLocationEarlySeam7202(v)||ADLocationEarlyOuterFloor7202(v);
}
// v7.205: location first-paint must not interpolate Amazon's stock white/cream
// background into our OLED target.  The v7.204 lifecycle probe proved the model
// layer is already black while the user can still see the bright transition, which
// is consistent with an in-flight Core Animation backgroundColor animation.
// Kill only backgroundColor animation on exact location floors; keep the sheet's
// position/bounds animation intact.
static void ADSetLocationBlack7202(UIView *v){
    if(!v)return;
    @try {
        UIColor *black=ADOLED();
        CALayer *layer=v.layer;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        if(layer)[layer removeAnimationForKey:@"backgroundColor"];
        ADSetViewBackground7226(v,black,YES);
        [CATransaction commit];
    } @catch(...) {}
}

// Once an exact address wrapper has marked this SNPRootView, a bright full-width
// RCTView below 470pt is part of the location sheet's moving floor/seam family.
// This intentionally does not require the old panel-shape height to mature: the
// v7.204 probe shows the same white floor growing 18 -> 39 -> 72 -> 103 -> ...
// while the address-card root is already marked.  The full-screen dimming overlay
// and root itself are excluded by the height cap.
static BOOL ADLocationMarkedWideBrightFloor7205(UIView *v, UIColor *candidate){
    if(!v||!ADClassNameIs7183(v,"RCTView")||!candidate||!ADBrightNeutralColor708(candidate))return NO;
    UIView *root=nil; if(!ADLocationRootActive7202(v,&root)||!root)return NO;
    @try {
        CGRect b=v.bounds,rb=root.bounds;
        if(rb.size.width<=0.0)return NO;
        return b.size.width>=rb.size.width*0.95 && b.size.width<=rb.size.width*1.05 &&
               b.size.height>=1.0 && b.size.height<=470.0;
    } @catch(...) {}
    return NO;
}
static void ADPaintLocationRoot7202(UIView *root){
    if(!gP.enabled||!root||!objc_getAssociatedObject(root,kADLocationRootFirstPaint7202)||
       objc_getAssociatedObject(root,kADLocationRootPrimed7226))return;
    @try {
        NSMutableArray *q=[NSMutableArray arrayWithObject:root]; NSUInteger seen=0;
        while(seen<q.count&&seen<512){
            UIView *x=q[seen++]; if(!x)continue;
            BOOL floor=ADLocationEarlyFloor7202(x)||ADLocationMarkedWideBrightFloor7205(x,x.backgroundColor);
            if(floor)ADSetLocationBlack7202(x);
            ADLocationSheetOwnText7196(x);
            if(x.subviews.count)[q addObjectsFromArray:x.subviews];
        }
        // Later React hydration is handled by the exact RCTView setter hooks; never
        // rescan the full SNPRootView on every layout pass.
        objc_setAssociatedObject(root,kADLocationRootPrimed7226,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}
static void ADPrimeLocationWrapper7202(UIView *wrapper){
    if(!gP.enabled||!wrapper)return;
    UIView *root=nil; BOOL ok=ADLocationEarlyWrapper7202(wrapper,&root);
    if(!ok||!root)return;
    objc_setAssociatedObject(root,kADLocationRootFirstPaint7202,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        NSMutableArray *q=[NSMutableArray arrayWithObject:wrapper]; NSUInteger seen=0;
        while(seen<q.count&&seen<64){
            UIView *x=q[seen++]; if(!x)continue;
            if(ADLocationEarlyCard7202(x))ADSetLocationBlack7202(x);
            ADLocationSheetOwnText7196(x);
            if(x.subviews.count)[q addObjectsFromArray:x.subviews];
        }
    } @catch(...) {}
    ADPaintLocationRoot7202(root);
}

static BOOL ADLocationSheetExactCard7198(UIView *v);
static BOOL ADInsideLocationSheetExactCard7198(UIView *v);
static BOOL ADInLocationSheetContent7196(UIView *v){
    if(ADInsideLocationEarlyCard7202(v))return YES;
    return ADLocationSheetOuterScroll7196(v)!=nil || ADLocationSheetCardScroll7196(v)!=nil || ADInsideLocationSheetExactCard7198(v);
}
static BOOL ADInLocationSheetCard7196(UIView *v){
    if(ADInsideLocationEarlyCard7202(v))return YES;
    return ADLocationSheetCardScroll7196(v)!=nil || ADInsideLocationSheetExactCard7198(v);
}
static BOOL ADLocationSheetPreserveBlueGeometry7196(UIView *v){
    if(!v||!v.window)return NO;
    @try {
        CGRect r=[v convertRect:v.bounds toView:v.window], wb=v.window.bounds;
        if(CGRectGetMinX(r)>=wb.size.width*0.68 && CGRectGetMinY(r)>=wb.size.height*0.64)return YES;
        if(CGRectGetMinY(r)>=wb.size.height*0.83)return YES;
    } @catch(...) {}
    return NO;
}
static UIColor *ADLocationSheetTextColor7196(UIView *v){
    return ADInLocationSheetCard7196(v) ? [UIColor whiteColor] : ADLightText706();
}
static BOOL ADLocationSheetExactCard7198(UIView *v){
    if(!v||!v.window||!ADLocationSheetRoot7196(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGRect r=[v convertRect:v.bounds toView:v.window], wb=v.window.bounds;
        if(r.size.width<118.0||r.size.width>165.0||r.size.height<108.0||r.size.height>155.0||
           CGRectGetMinY(r)<wb.size.height*0.62||CGRectGetMinY(r)>wb.size.height*0.84)return NO;
        for(UIView *n=v.superview;n&&n!=v.window;n=n.superview){
            if(ADClassNameIs7183(n,"RNCEKVExternalKeyboardView")){
                CGRect nr=[n convertRect:n.bounds toView:v.window];
                if(fabs(nr.origin.x-r.origin.x)<=3.0&&fabs(nr.origin.y-r.origin.y)<=3.0&&
                   fabs(nr.size.width-r.size.width)<=4.0&&fabs(nr.size.height-r.size.height)<=4.0)return YES;
            }
            if(ADClassNameIs7183(n,"SNPRootView"))break;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADInsideLocationSheetExactCard7198(UIView *v){
    if(!v||!v.window||!ADLocationSheetRoot7196(v))return NO;
    @try {
        for(UIView *n=v;n;n=n.superview){
            if(ADLocationSheetExactCard7198(n))return YES;
            if(ADClassNameIs7183(n,"SNPRootView")||[n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADLocationSheetExactSeam7198(UIView *v){
    if(!v||!v.window||!ADLocationSheetRoot7196(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGRect r=[v convertRect:v.bounds toView:v.window], wb=v.window.bounds;
        return r.size.width>=wb.size.width*0.95&&r.size.height>=10.0&&r.size.height<=28.0&&
               CGRectGetMinY(r)>=wb.size.height*0.54&&CGRectGetMinY(r)<=wb.size.height*0.61;
    } @catch(...) {}
    return NO;
}
static BOOL ADLocationSheetFloor7196(UIView *v, UIColor *candidate){
    if(!gP.enabled||!v)return NO;
    if(ADLocationEarlyFloor7202(v))return YES;
    if(!v.window||!ADLocationSheetRoot7196(v))return NO;
    if(ADLocationSheetExactCard7198(v)||ADLocationSheetExactSeam7198(v))return YES;
    if(!candidate||!ADBrightNeutralColor708(candidate)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGRect r=[v convertRect:v.bounds toView:v.window], wb=v.window.bounds;
        if(r.size.width>=wb.size.width*0.90&&
           CGRectGetMinY(r)>=wb.size.height*0.54&&CGRectGetMinY(r)<=wb.size.height*0.66&&
           r.size.height>=12.0&&CGRectGetMaxY(r)>wb.size.height*0.58)return YES;
        if(ADLocationSheetCardScroll7196(v)&&
           r.size.width>=wb.size.width*0.25&&r.size.width<=wb.size.width*0.42&&
           r.size.height>=90.0&&r.size.height<=180.0&&
           CGRectGetMinY(r)>=wb.size.height*0.60&&CGRectGetMinY(r)<=wb.size.height*0.86)return YES;
    } @catch(...) {}
    return NO;
}
static NSTextStorage *ADLocationSheetTextStorage7196(UIView *v){
    if(!v)return nil;
    @try {
        SEL tsSel=NSSelectorFromString(@"textStorage");
        if([v respondsToSelector:tsSel]){
            id ts=((id(*)(id,SEL))objc_msgSend)(v,tsSel);
            if([ts isKindOfClass:[NSTextStorage class]])return (NSTextStorage *)ts;
        }
        Ivar iv=class_getInstanceVariable([v class],"_textStorage");
        if(iv){
            id ts=object_getIvar(v,iv);
            if([ts isKindOfClass:[NSTextStorage class]])return (NSTextStorage *)ts;
        }
    } @catch(...) {}
    return nil;
}
static void ADLocationSheetLightStorage7196(UIView *v, NSTextStorage *ts){
    if(!gP.enabled||!v||!ts||!ts.length||!ADInLocationSheetContent7196(v))return;
    @try {
        if(ADLocationSheetPreserveBlueGeometry7196(v))return;
        UIColor *light=ADLocationSheetTextColor7196(v); NSRange whole=NSMakeRange(0,ts.length);
        __block NSMutableArray<NSValue *> *ranges=nil;
        [ts enumerateAttribute:NSForegroundColorAttributeName inRange:whole options:0 usingBlock:^(id value,NSRange range,BOOL *stop){
            UIColor *c=[value isKindOfClass:[UIColor class]]?(UIColor *)value:nil;
            if(ADColorLinkBlue7196(c)||[c isEqual:light])return;
            if(!ranges)ranges=[NSMutableArray array];
            [ranges addObject:[NSValue valueWithRange:range]];
        }];
        if(!ranges.count)return;
        [ts beginEditing];
        for(NSValue *rv in ranges)[ts addAttribute:NSForegroundColorAttributeName value:light range:rv.rangeValue];
        [ts endEditing];
        [v setNeedsDisplay];
    } @catch(...) {}
}
static NSAttributedString *ADLocationSheetLightString7196(UIView *v, NSAttributedString *in){
    if(!in||!in.length||!v||!ADInLocationSheetContent7196(v))return in;
    @try {
        if(ADLocationSheetPreserveBlueGeometry7196(v))return in;
        UIColor *light=ADLocationSheetTextColor7196(v); NSRange whole=NSMakeRange(0,in.length);
        __block NSMutableAttributedString *m=nil;
        [in enumerateAttribute:NSForegroundColorAttributeName inRange:whole options:0 usingBlock:^(id value,NSRange range,BOOL *stop){
            UIColor *c=[value isKindOfClass:[UIColor class]]?(UIColor *)value:nil;
            if(ADColorLinkBlue7196(c)||[c isEqual:light])return;
            if(!m)m=[in mutableCopy];
            [m addAttribute:NSForegroundColorAttributeName value:light range:range];
        }];
        return m?:in;
    } @catch(...) { return in; }
}
static NSAttributedString *ADLocationSheetAttributedString7196(UIView *v){
    if(!v)return nil;
    @try {
        SEL getSel=NSSelectorFromString(@"attributedText");
        if([v respondsToSelector:getSel]){
            id a=((id(*)(id,SEL))objc_msgSend)(v,getSel);
            if([a isKindOfClass:[NSAttributedString class]])return (NSAttributedString *)a;
        }
        const char *names[]={"_attributedText","_attributedString"};
        for(size_t i=0;i<sizeof(names)/sizeof(names[0]);i++){
            Ivar iv=class_getInstanceVariable([v class],names[i]);
            if(iv){
                id a=object_getIvar(v,iv);
                if([a isKindOfClass:[NSAttributedString class]])return (NSAttributedString *)a;
            }
        }
    } @catch(...) {}
    return nil;
}
static void ADLocationSheetOwnText7196(UIView *v){
    if(!gP.enabled||!v||!ADInLocationSheetContent7196(v))return;
    const char *cn=object_getClassName(v);
    BOOL possible=[v isKindOfClass:[UILabel class]]||(cn&&(strstr(cn,"Text")||strstr(cn,"Paragraph")))||[v respondsToSelector:NSSelectorFromString(@"textStorage")];
    if(!possible)return;
    @try {
        BOOL preserve=ADLocationSheetPreserveBlueGeometry7196(v);
        if([v isKindOfClass:[UILabel class]]){
            UILabel *l=(UILabel *)v;
            if(preserve)return;
            if(l.attributedText.length){
                NSAttributedString *r=ADLocationSheetLightString7196(v,l.attributedText);
                if(r&&![r isEqualToAttributedString:l.attributedText])l.attributedText=r;
            }
            if(!ADColorLinkBlue7196(l.textColor))l.textColor=ADLocationSheetTextColor7196(v);
            return;
        }
        NSTextStorage *ts=ADLocationSheetTextStorage7196(v);
        if(ts){ ADLocationSheetLightStorage7196(v,ts); return; }
        if(!preserve){
            NSAttributedString *a=ADLocationSheetAttributedString7196(v);
            SEL setSel=[v respondsToSelector:NSSelectorFromString(@"setAttributedText:")]?NSSelectorFromString(@"setAttributedText:"):NSSelectorFromString(@"_setAttributedString:");
            if(a&&[v respondsToSelector:setSel]){
                NSAttributedString *r=ADLocationSheetLightString7196(v,a);
                if(r&&![r isEqualToAttributedString:a])((void(*)(id,SEL,id))objc_msgSend)(v,setSel,r);
            }
        }
    } @catch(...) {}
}
static void ADOwnLocationSheetFloor7196(UIView *v){
    if(!gP.enabled||!v)return;
    @try {
        UIColor *bg=v.backgroundColor;
        if(!ADLocationSheetFloor7196(v,bg))return;
        UIColor *black=ADOLED();
        ADSetViewBackground7226(v,black,YES);
    } @catch(...) {}
}
static const void *kADLocationExactPaint7198=&kADLocationExactPaint7198;
static void ADPaintLocationSheetExactContent7198(UIView *outer){
    if(!gP.enabled||!outer||!outer.window||ADLocationSheetOuterScroll7196(outer)!=outer)return;
    UIView *root=ADLocationSheetRoot7196(outer);
    if(root&&objc_getAssociatedObject(root,kADLocationExactPaint7198))return;
    @try {
        NSUInteger cards=0,seams=0;
        NSMutableArray *q=[NSMutableArray arrayWithObject:outer]; NSUInteger seen=0;
        while(seen<q.count&&seen<512){
            UIView *x=q[seen++]; if(!x)continue;
            if(ADLocationSheetExactCard7198(x)){
                cards++;
                ADSetViewBackground7226(x,ADOLED(),YES);
            }
            ADLocationSheetOwnText7196(x);
            if(x.subviews.count)[q addObjectsFromArray:x.subviews];
        }
        if(root){
            NSMutableArray *rq=[NSMutableArray arrayWithObject:root]; NSUInteger rn=0;
            while(rn<rq.count&&rn<512){
                UIView *x=rq[rn++]; if(!x)continue;
                if(ADLocationSheetExactSeam7198(x)){
                    seams++;
                    ADSetViewBackground7226(x,ADOLED(),YES);
                }
                if(x.subviews.count)[rq addObjectsFromArray:x.subviews];
            }
            if(cards>=3&&seams>=1)objc_setAssociatedObject(root,kADLocationExactPaint7198,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } @catch(...) {}
}
static void ADPaintLocationSheetStable7196(UIView *scroll){
    if(!gP.enabled||!scroll||!scroll.window||!ADClassNameIs7183(scroll,"RCTScrollView"))return;
    UIView *root=nil;
    if(ADLocationRootActive7202(scroll,&root)&&root)ADPaintLocationRoot7202(root);
    if(ADLocationSheetOuterScroll7196(scroll)==scroll)ADPaintLocationSheetExactContent7198(scroll);
}
// v7.263: Person refresh hydration can remount Buy Again product raster leaves at
// depth 31 below the exact RCTScrollView#me root.  The old 24-ancestor budget
// therefore misclassified those known ANXFastImageView leaves as non-Person media
// after Retry/Refresh and removed TWB. Keep this a finite ancestry walk (48 max)
// with no global sweep, observer, timer, or recurring hierarchy scan.
static UIView *ADPersonRoot7206(UIView *v){
    if(!v)return nil;
    @try {
        UIView *n=v;
        for(int d=0;n&&d<48;d++,n=n.superview){
            if([n.accessibilityIdentifier isEqualToString:@"me"] && ADClassNameIs7183(n,"RCTScrollView"))return n;
        }
    } @catch(...) {}
    return nil;
}
static BOOL ADInPersonTab7206(UIView *v){
    if(!v)return NO;
    NSNumber *surface=objc_getAssociatedObject(v,kADReactSurfaceCache7232);
    if(surface)return surface.intValue==ADReactSurfacePerson7226;
    UIView *root=ADPersonRoot7206(v);
    if(root)objc_setAssociatedObject(v,kADReactSurfaceCache7232,@(ADReactSurfacePerson7226),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return root!=nil;
}
static UIColor *ADPersonSecondary7206(void){
    static UIColor *c=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ c=[UIColor colorWithRed:177.0/255.0 green:181.0/255.0 blue:181.0/255.0 alpha:1.0]; });
    return c;
}
static BOOL ADPersonAccent7206(UIColor *c){
    if(!c)return NO;
    @try {
        CGFloat r=0,g=0,b=0,a=0,w=0;
        if([c getRed:&r green:&g blue:&b alpha:&a]){
            if(a<0.08)return NO;
            CGFloat hi=MAX(r,MAX(g,b)),lo=MIN(r,MIN(g,b));
            return (hi-lo)>0.20; // preserve Prime/links/teal/orange/green authored accents
        }
        if([c getWhite:&w alpha:&a])return NO;
    } @catch(...) {}
    return NO;
}
// v7.208 Person hardening: React Native draws many rounded borders through RCTView's
// own per-edge border properties rather than CALayer.borderColor.  The v7.207 probe
// shows the four BAC pills with layer borderWidth=0 while a bright rounded edge is
// still visible, so reassert both paint paths.  This remains exact-Person only.
static BOOL ADPersonTopMenuPill7208(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        NSString *aid=v.accessibilityIdentifier;
        return [aid isEqualToString:@"bac_yo"]||[aid isEqualToString:@"bac_ya"]||
               [aid isEqualToString:@"bac_wl"]||[aid isEqualToString:@"bac_aiwl"];
    } @catch(...) { return NO; }
}
static BOOL ADPersonBuyAgain7208(UIView *v){
    if(!v)return NO;
    @try {
        UIView *n=v;
        for(int d=0;n&&d<24;d++,n=n.superview){
            NSString *aid=n.accessibilityIdentifier;
            if([aid isEqualToString:@"buy-again-flow-card"]||
               [aid isEqualToString:@"CardWrapperView"]||
               [aid isEqualToString:@"tmpWrapperView"])return YES;
        }
    } @catch(...) {}
    return NO;
}
static SEL ADPersonRCTBorderWidthSEL7232(void){
    static SEL s=NULL; static dispatch_once_t once;
    dispatch_once(&once,^{ s=sel_registerName("borderWidth"); });
    return s;
}
static SEL ADPersonRCTBorderRadiusSEL7232(void){
    static SEL s=NULL; static dispatch_once_t once;
    dispatch_once(&once,^{ s=sel_registerName("borderRadius"); });
    return s;
}
static SEL ADPersonRCTSetBorderRadiusSEL7232(void){
    static SEL s=NULL; static dispatch_once_t once;
    dispatch_once(&once,^{ s=sel_registerName("setBorderRadius:"); });
    return s;
}
static CGFloat ADPersonRCTBorderWidth7208(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return 0.0;
    @try {
        SEL q=ADPersonRCTBorderWidthSEL7232();
        if([v respondsToSelector:q])return ((CGFloat(*)(id,SEL))objc_msgSend)(v,q);
    } @catch(...) {}
    return 0.0;
}
static CGFloat ADPersonRCTBorderRadius7212(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return 0.0;
    @try {
        SEL q=ADPersonRCTBorderRadiusSEL7232();
        if([v respondsToSelector:q])return ((CGFloat(*)(id,SEL))objc_msgSend)(v,q);
    } @catch(...) {}
    return 0.0;
}
static void ADPersonSetRCTRadius7212(UIView *v,CGFloat radius){
    if(!v||!ADClassNameIs7183(v,"RCTView")||radius<0.0)return;
    @try {
        SEL s=ADPersonRCTSetBorderRadiusSEL7232();
        if([v respondsToSelector:s])((void(*)(id,SEL,CGFloat))objc_msgSend)(v,s,radius);
    } @catch(...) {}
}
// v7.209 crash hotfix retained: RCTView border-color setters take UIColor *, not CGColorRef.
// v7.212 keeps React's border renderer as the sole Person RCT border owner; CALayer borders
// are not stacked on top of it. This removes the square + rounded double-edge regression.
static void ADPersonSetRCTBorder7208(UIView *v,CGFloat width){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return;
    @try {
        static SEL colorSetters[7]={NULL};
        static SEL widthSetters[7]={NULL};
        static dispatch_once_t once;
        dispatch_once(&once,^{
            const char *colors[]={"setBorderColor:","setBorderTopColor:","setBorderRightColor:",
                                  "setBorderBottomColor:","setBorderLeftColor:","setBorderStartColor:",
                                  "setBorderEndColor:"};
            const char *widths[]={"setBorderWidth:","setBorderTopWidth:","setBorderRightWidth:",
                                  "setBorderBottomWidth:","setBorderLeftWidth:","setBorderStartWidth:",
                                  "setBorderEndWidth:"};
            for(size_t i=0;i<7;i++){
                colorSetters[i]=sel_registerName(colors[i]);
                widthSetters[i]=sel_registerName(widths[i]);
            }
        });
        UIColor *gray=ADBorderGray706();
        for(size_t i=0;i<7;i++){
            SEL sel=colorSetters[i];
            if([v respondsToSelector:sel])((void(*)(id,SEL,UIColor *))objc_msgSend)(v,sel,gray);
        }
        for(size_t i=0;i<7;i++){
            SEL sel=widthSetters[i];
            if([v respondsToSelector:sel])((void(*)(id,SEL,CGFloat))objc_msgSend)(v,sel,width);
        }
        [v setNeedsDisplay];
        [v.layer setNeedsDisplay];
    } @catch(...) {}
}

// v7.242: expanded Your Orders search field. The v7.240 probe shows two
// concentric React borders: 364x54 @ 2pt and 360x50 @ 1pt.  Retire both stock
// border rasters and let only the persistent outer shell own one 1pt gray path.
static const void *kADPersonOrderSearchOutline7242=&kADPersonOrderSearchOutline7242;
static BOOL ADPersonDescendantClass7242(UIView *root,const char *wanted,int maxNodes){
    if(!root||!wanted)return NO;
    @try {
        NSMutableArray<UIView *> *q=[NSMutableArray arrayWithArray:root.subviews];
        int seen=0;
        while(q.count&&seen++<maxNodes){
            UIView *v=q.firstObject; [q removeObjectAtIndex:0];
            if(ADClassNameIs7183(v,wanted))return YES;
            for(UIView *c in v.subviews)if(q.count<(NSUInteger)maxNodes)[q addObject:c];
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonOrderSearchOuter7242(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<362.0||w>366.0||h<52.0||h>56.0)return NO;
        return ADPersonDescendantClass7242(v,"RNCEKVTextInputFocusWrapper",12);
    } @catch(...) { return NO; }
}
static BOOL ADPersonOrderSearchInner7242(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<358.0||w>362.0||h<48.0||h>52.0)return NO;
        return v.superview&&ADPersonOrderSearchOuter7242(v.superview)&&
               ADPersonDescendantClass7242(v,"RNCEKVTextInputFocusWrapper",8);
    } @catch(...) { return NO; }
}
static void ADPersonOwnOrderSearch7242(UIView *v){
    if(!v)return;
    @try {
        BOOL outer=gP.enabled&&ADPersonOrderSearchOuter7242(v);
        BOOL inner=gP.enabled&&ADPersonOrderSearchInner7242(v);
        CAShapeLayer *ol=objc_getAssociatedObject(v,kADPersonOrderSearchOutline7242);
        if(!outer&&!inner){
            if(ol){ [ol removeFromSuperlayer]; objc_setAssociatedObject(v,kADPersonOrderSearchOutline7242,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        // The text and magnifier live in child views, so these exact shell
        // contents are only React's cached border renderer and are safe to retire.
        v.layer.contents=nil;
        v.layer.borderWidth=0.0;
        ADPersonSetRCTBorder7208(v,0.0);
        if(inner){
            if(ol){ [ol removeFromSuperlayer]; objc_setAssociatedObject(v,kADPersonOrderSearchOutline7242,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        if(!ol){
            ol=[CAShapeLayer layer];
            ol.name=@"AmazonDarkPersonOrderSearchOutline7242";
            ol.fillColor=[UIColor clearColor].CGColor;
            ol.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"path":[NSNull null],@"strokeColor":[NSNull null],@"zPosition":[NSNull null]};
            [v.layer addSublayer:ol];
            objc_setAssociatedObject(v,kADPersonOrderSearchOutline7242,ol,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(ol.superlayer!=v.layer){ [v.layer addSublayer:ol]; }
        ol.frame=v.bounds;
        ol.fillColor=[UIColor clearColor].CGColor;
        ol.strokeColor=ADBorderGray706().CGColor;
        ol.lineWidth=1.0;
        ol.path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(v.bounds,0.5,0.5) cornerRadius:6.0].CGPath;
        ol.zPosition=FLT_MAX;
        ol.hidden=v.hidden||v.alpha<0.01;
    } @catch(...) {}
}
static void ADPersonRepairOrderSearchAncestors7242(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v))return;
    @try {
        for(UIView *n=v;n&&n!=v.window;n=n.superview){
            if(ADPersonOrderSearchOuter7242(n)||ADPersonOrderSearchInner7242(n)||objc_getAssociatedObject(n,kADPersonOrderSearchOutline7242))
                ADPersonOwnOrderSearch7242(n);
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
    } @catch(...) {}
}

// v7.243: the v7.240 Person probe identifies the Search-orders magnifier exactly:
// RCTUIImageViewAnimated 20x20 <- RCTImageView 20x20, where the RCTImageView is a
// direct child of the already-proven 360x50 inner Search-orders shell and is the
// sibling of RNCEKVTextInputFocusWrapper.  Own only this glyph; do not touch the
// v7.242 border implementation above.
static BOOL ADPersonOrderSearchMagnifierWrapper7243(UIView *v){
    if(!gP.enabled||!v||!v.window||!ADClassNameIs7183(v,"RCTImageView"))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<18.0||w>22.0||h<18.0||h>22.0)return NO;
        UIView *host=v.superview;
        return host&&ADPersonOrderSearchInner7242(host)&&ADPersonDescendantClass7242(host,"RNCEKVTextInputFocusWrapper",8);
    } @catch(...) { return NO; }
}
static BOOL ADPersonOrderSearchMagnifierLeaf7243(UIImageView *iv){
    if(!gP.enabled||!iv||!iv.window||!iv.image)return NO;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<18.0||w>22.0||h<18.0||h>22.0)return NO;
        return iv.superview&&ADPersonOrderSearchMagnifierWrapper7243(iv.superview);
    } @catch(...) { return NO; }
}
static BOOL gADPersonOrderMagnifierWrite7243=NO;
static void ADPersonOwnOrderSearchMagnifierLeaf7243(UIImageView *iv){
    if(!ADPersonOrderSearchMagnifierLeaf7243(iv))return;
    @try {
        UIImage *im=iv.image;
        if(im&&im.renderingMode!=UIImageRenderingModeAlwaysTemplate&&!gADPersonOrderMagnifierWrite7243){
            UIImage *tpl=[im imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            if(tpl){ gADPersonOrderMagnifierWrite7243=YES; iv.image=tpl; gADPersonOrderMagnifierWrite7243=NO; }
        }
        iv.tintColor=ADLightText706();
    } @catch(...) { gADPersonOrderMagnifierWrite7243=NO; }
}
static const void *kADPersonInternalMedia7213=&kADPersonInternalMedia7213;
// v7.213 Person card hardening: inner carousel/product-media plates are content,
// not cards.  They may own an OLED floor, but never a border.  This keeps one
// rounded gray frame on the outer card while removing duplicated image/pane frames.
static BOOL ADPersonHasNestedScroll7213(UIView *v){
    if(!v)return NO;
    @try {
        for(UIView *n=v.superview;n;n=n.superview){
            if(ADClassNameIs7183(n,"RCTScrollView")){
                if([n.accessibilityIdentifier isEqualToString:@"me"])return NO;
                return YES;
            }
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonContainsMedia7213(UIView *v){
    if(!v)return NO;
    @try {
        NSMutableArray<UIView *> *stack=[NSMutableArray arrayWithArray:v.subviews];
        int seen=0;
        while(stack.count&&seen<28){
            UIView *n=stack.lastObject; [stack removeLastObject]; seen++;
            if([n isKindOfClass:[UIImageView class]])return YES;
            for(UIView *c in n.subviews)[stack addObject:c];
        }
    } @catch(...) {}
    return NO;
}
static const void *kADPersonCarouselOuter7214=&kADPersonCarouselOuter7214;
static const void *kADPersonCarouselInner7214=&kADPersonCarouselInner7214;
// v7.214: Person commerce carousels use one rounded outer frame only.  Their
// recycled page/content views are structural content and must never manufacture
// a second border.  This is geometry + nested-scroll scoped under the exact me root.
static BOOL ADPersonCarouselOuter7214(UIView *v){
    if(!v||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        if(objc_getAssociatedObject(v,kADPersonCarouselOuter7214))return YES;
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<370.0||w>415.0||h<88.0||h>136.0)return NO;
        NSMutableArray<UIView *> *q=[NSMutableArray arrayWithArray:v.subviews];
        int seen=0;
        while(q.count&&seen<18){
            UIView *n=q.firstObject; [q removeObjectAtIndex:0]; seen++;
            if(ADClassNameIs7183(n,"RCTScrollView")){
                CGFloat sw=n.bounds.size.width,sh=n.bounds.size.height;
                if(sw>=w-8.0&&sw<=w+8.0&&sh>=h-12.0&&sh<=h+4.0){
                    objc_setAssociatedObject(v,kADPersonCarouselOuter7214,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    return YES;
                }
            }
            if(seen<10)for(UIView *c in n.subviews)[q addObject:c];
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonInsideCarouselOuter7214(UIView *v){
    if(!v||!ADInPersonTab7206(v))return NO;
    @try {
        if(objc_getAssociatedObject(v,kADPersonCarouselInner7214))return YES;
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        // Preserve authored 8-10pt carousel indicators exactly as Amazon paints them.
        if(w<=18.0&&h<=18.0)return NO;
        UIView *n=v.superview;
        for(int d=0;n&&d<7;d++,n=n.superview){
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
            if(ADPersonCarouselOuter7214(n)){
                objc_setAssociatedObject(v,kADPersonCarouselInner7214,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                return YES;
            }
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonInternalMediaPlate7213(UIView *v){
    if(!v||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        NSString *aid=(v.accessibilityIdentifier?:@"").lowercaseString;
        // v7.235 probe: these exact React views are physical cards, not media plates.
        if([aid isEqualToString:@"yhw_healthai_0"]||[aid isEqualToString:@"yhw_pharmacy_1"]||
           [aid isEqualToString:@"yo_btn"])return NO;
        if(objc_getAssociatedObject(v,kADPersonInternalMedia7213))return YES;
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<=18.0&&h<=18.0)return NO;
        if(ADPersonInsideCarouselOuter7214(v)){
            objc_setAssociatedObject(v,kADPersonInternalMedia7213,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return YES;
        }
        if(w<92.0||w>235.0||h<76.0||h>215.0)return NO;
        // The Project Hail Mary / Shop previously watched card is the actual outer pane.
        // Its image descendants are media; the card itself must retain one rounded frame.
        if([aid isEqualToString:@"carousel-item-view"])return NO;
        if([aid isEqualToString:@"carouselimagecontainer"]){
            // Buy Again / Person commerce image wells are never card borders.
            if(ADPersonBuyAgain7208(v)||ADPersonHasNestedScroll7213(v)){
                objc_setAssociatedObject(v,kADPersonInternalMedia7213,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                return YES;
            }
        }
        if(!ADPersonHasNestedScroll7213(v))return NO;
        if([aid hasPrefix:@"tile-widget-"]||[aid isEqualToString:@"ya0"]||[aid isEqualToString:@"ya1"]||
           [aid isEqualToString:@"ya2"]||[aid isEqualToString:@"gc0"]||[aid isEqualToString:@"gc1"])return NO;
        if(ADPersonContainsMedia7213(v)){
            objc_setAssociatedObject(v,kADPersonInternalMedia7213,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return YES;
        }
        return NO;
    } @catch(...) { return NO; }
}
static BOOL ADPersonVisibleColor7213(UIColor *c){
    if(!c)return NO;
    @try {
        CGFloat r=0,g=0,b=0,a=0,w=0;
        if([c getRed:&r green:&g blue:&b alpha:&a])return a>=0.015;
        if([c getWhite:&w alpha:&a])return a>=0.015;
    } @catch(...) {}
    return NO;
}
static UIColor *ADPersonBackground7213(UIView *v){
    if(!v)return nil;
    @try {
        if(v.backgroundColor)return v.backgroundColor;
        if(v.layer.backgroundColor)return [UIColor colorWithCGColor:v.layer.backgroundColor];
    } @catch(...) {}
    return nil;
}
static BOOL ADPersonBuyAgainWrapper7218(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        NSString *aid=(v.accessibilityIdentifier?:@"").lowercaseString;
        return [aid isEqualToString:@"buy-again-flow-card"]||[aid isEqualToString:@"cardwrapperview"]||
               [aid isEqualToString:@"tmpwrapperview"];
    } @catch(...) { return NO; }
}
// v7.236: the v7.235 probe plus the on-device screenshot identify two different
// Buy Again contours. The 296x418.7 direct CardWrapper child is only an outer padding
// shell (our old gray outline was therefore too large). The stock white contour with
// the correct geometry is the anonymous ~286x416.7 direct child of tmpWrapperView.
// Own that exact physical host, suppress its stock white raster edge, and redraw the
// same bounds in the standard gray. This leaves exactly one correctly-sized contour.
static BOOL ADPersonBuyAgainItem7218(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView")||!ADPersonBuyAgain7208(v))return NO;
    if(ADPersonBuyAgainWrapper7218(v))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        NSString *aid=(v.accessibilityIdentifier?:@"").lowercaseString;
        if(aid.length)return NO;
        if(!(w>=250.0&&w<=325.0&&h>=300.0&&h<=500.0))return NO;
        NSString *parentAid=(v.superview.accessibilityIdentifier?:@"").lowercaseString;
        return [parentAid isEqualToString:@"tmpwrapperview"];
    } @catch(...) { return NO; }
}
// v7.238: the follow-up probe finally isolates the remaining jangled Buy Again
// contour. Each card has an anonymous 296x418.7 RCT border-raster shell directly
// under a 294x416.7 CardWrapperView, while the desired corrected contour is the
// separate 286x416.7 child of tmpWrapperView. Retire only that exact outer shell;
// the dedicated 286x416.7 AmazonDarkPersonBuyAgainOutline7218 remains the sole
// visible card outline. Positive ownership is revalidated through local Buy Again
// ancestry, so recycled/unresolved views are never globally cached as this shell.
static const void *kADPersonBuyAgainOuterShell7238=&kADPersonBuyAgainOuterShell7238;
static BOOL ADPersonBuyAgainOuterBorderShell7238(UIView *v){
    if(!v||!v.window||!ADClassNameIs7183(v,"RCTView")||!ADPersonBuyAgain7208(v))return NO;
    if(ADPersonBuyAgainWrapper7218(v)||ADPersonBuyAgainItem7218(v))return NO;
    @try {
        NSString *aid=(v.accessibilityIdentifier?:@"").lowercaseString;
        if(aid.length)return NO;
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<292.0||w>300.0||h<414.0||h>422.0)return NO;
        NSString *parentAid=(v.superview.accessibilityIdentifier?:@"").lowercaseString;
        if(![parentAid isEqualToString:@"cardwrapperview"])return NO;
        if(objc_getAssociatedObject(v,kADPersonBuyAgainOuterShell7238))return YES;
        CGFloat rw=ADPersonRCTBorderWidth7208(v);
        if(rw<0.5&&v.layer.borderWidth<0.5&&v.layer.contents==nil)return NO;
        objc_setAssociatedObject(v,kADPersonBuyAgainOuterShell7238,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return YES;
    } @catch(...) { return NO; }
}
static void ADPersonSuppressBuyAgainOuterBorder7238(UIView *v){
    if(!v||!ADPersonBuyAgainOuterBorderShell7238(v))return;
    @try {
        // The probe proves this exact layer.contents is React's oversized border
        // raster; child product content is hosted below it in a separate 286pt view.
        v.layer.contents=nil;
        v.layer.borderWidth=0.0;
        ADPersonSetRCTBorder7208(v,0.0);
        ADSetViewBackground7226(v,[UIColor clearColor],YES);
        v.layer.backgroundColor=[UIColor clearColor].CGColor;
    } @catch(...) {}
}

static BOOL ADPersonBuyAgainOccluder7235(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView")||!ADPersonBuyAgain7208(v))return NO;
    @try {
        if(![(v.accessibilityIdentifier?:@"").lowercaseString isEqualToString:@"undefined-overlay"])return NO;
        if(v.subviews.count||v.layer.contents)return NO;
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        return w>=110.0&&w<=140.0&&h>=95.0&&h<=185.0;
    } @catch(...) { return NO; }
}
// v7.224: the v7.223 native truth shows each real Highlights tile-widget has the
// correct React border, but an opaque same-geometry rounded child sits above that
// renderer.  The child covers the straight edges and leaves only the parent corners
// peeking through.  Give only the exact tile-widget one topmost physical outline and
// disable its hidden React/CALayer border so there is still exactly one visible edge.
static const void *kADPersonHighlightTileOutline7224=&kADPersonHighlightTileOutline7224;
static BOOL ADPersonHighlightTile7224(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        NSString *aid=(v.accessibilityIdentifier?:@"").lowercaseString;
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        return [aid hasPrefix:@"tile-widget-"]&&w>=280.0&&w<=360.0&&h>=88.0&&h<=140.0;
    } @catch(...) { return NO; }
}
static void ADPersonOwnHighlightTile7224(UIView *v){
    if(!v)return;
    @try {
        CAShapeLayer *ol=objc_getAssociatedObject(v,kADPersonHighlightTileOutline7224);
        BOOL own=gP.enabled&&ADPersonHighlightTile7224(v);
        if(!own){
            if(ol){ [ol removeFromSuperlayer]; objc_setAssociatedObject(v,kADPersonHighlightTileOutline7224,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        v.layer.borderWidth=0.0;
        ADPersonSetRCTBorder7208(v,0.0);
        ADSetViewBackground7226(v,ADOLED(),YES);
        if(!ol){
            ol=[CAShapeLayer layer]; ol.name=@"AmazonDarkPersonHighlightTileOutline7224";
            ol.fillColor=[UIColor clearColor].CGColor; ol.lineWidth=1.0;
            ol.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"path":[NSNull null],@"strokeColor":[NSNull null],@"zPosition":[NSNull null]};
            [v.layer addSublayer:ol];
            objc_setAssociatedObject(v,kADPersonHighlightTileOutline7224,ol,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(ol.superlayer!=v.layer)[v.layer addSublayer:ol];
        ol.frame=v.bounds; ol.strokeColor=ADBorderGray706().CGColor; ol.lineWidth=1.0;
        CGRect rr=CGRectInset(v.bounds,0.5,0.5);
        CGFloat radius=MAX(8.0,MAX(v.layer.cornerRadius,ADPersonRCTBorderRadius7212(v)));
        ol.path=[UIBezierPath bezierPathWithRoundedRect:rr cornerRadius:radius].CGPath;
        ol.zPosition=FLT_MAX; ol.hidden=v.hidden||v.alpha<0.01;
    } @catch(...) {}
}

// v7.231: Reviews still uses the two-sibling card stack identified in v7.225.
// The content-bearing 160x160 view sits under an empty 160x160 RCT border plate.
// React's cached border raster is bright and is not controlled by CALayer.borderColor,
// so retire only that empty raster and replace it with the same gray physical outline
// used by the neighboring Person cards.
static const void *kADPersonReviewOutline7231=&kADPersonReviewOutline7231;
static BOOL ADPersonReviewBorderPlate7231(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<145.0||w>175.0||h<145.0||h>175.0)return NO;
        if(ADPersonSectionKind7218(v)!=3)return NO;
        if(objc_getAssociatedObject(v,kADPersonReviewOutline7231))return YES;
        if(v.subviews.count!=0)return NO;
        return ADPersonRCTBorderWidth7208(v)>=0.5||v.layer.borderWidth>=0.5;
    } @catch(...) { return NO; }
}
static void ADPersonOwnReviewBorderPlate7231(UIView *v){
    if(!v)return;
    @try {
        CAShapeLayer *ol=objc_getAssociatedObject(v,kADPersonReviewOutline7231);
        BOOL own=gP.enabled&&ADPersonReviewBorderPlate7231(v);
        if(!own){
            if(ol){ [ol removeFromSuperlayer]; objc_setAssociatedObject(v,kADPersonReviewOutline7231,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        ADSetViewBackground7226(v,[UIColor clearColor],YES);
        v.layer.borderWidth=0.0;
        ADPersonSetRCTBorder7208(v,0.0);
        // This exact view is an empty border plate. Its contents are only React's
        // stale fill/border raster, never review imagery or text.
        v.layer.contents=nil;
        if(!ol){
            ol=[CAShapeLayer layer]; ol.name=@"AmazonDarkPersonReviewOutline7231";
            ol.fillColor=[UIColor clearColor].CGColor; ol.lineWidth=1.0;
            ol.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"path":[NSNull null],
                         @"strokeColor":[NSNull null],@"zPosition":[NSNull null]};
            [v.layer addSublayer:ol];
            objc_setAssociatedObject(v,kADPersonReviewOutline7231,ol,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(ol.superlayer!=v.layer)[v.layer addSublayer:ol];
        ol.frame=v.bounds;
        ol.strokeColor=ADBorderGray706().CGColor;
        ol.lineWidth=1.0;
        ol.path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(v.bounds,0.5,0.5) cornerRadius:8.0].CGPath;
        ol.zPosition=FLT_MAX;
        ol.hidden=v.hidden||v.alpha<0.01;
    } @catch(...) {}
}

// v7.235: Your Interests has an empty, raster-backed 178x163 border plate
// directly under aiwl_widget0/1. Its cached stock border stays bright even when
// the semantic parent already carries our gray color, so replace only that plate.
static const void *kADPersonInterestOutline7235=&kADPersonInterestOutline7235;
static BOOL ADPersonInterestBorderPlate7235(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<170.0||w>185.0||h<155.0||h>170.0)return NO;
        NSString *parentAid=(v.superview.accessibilityIdentifier?:@"").lowercaseString;
        if(!([parentAid isEqualToString:@"aiwl_widget0"]||[parentAid isEqualToString:@"aiwl_widget1"]))return NO;
        if(objc_getAssociatedObject(v,kADPersonInterestOutline7235))return YES;
        // v7.237 first-paint hardening: parent ID + exact 178x163 geometry already
        // uniquely identify the empty stock border plate. Do not wait for React to
        // populate its bright raster/border state; that wait caused the white flash.
        return v.subviews.count==0;
    } @catch(...) { return NO; }
}
static void ADPersonOwnInterestBorderPlate7235(UIView *v){
    if(!v)return;
    @try {
        CAShapeLayer *ol=objc_getAssociatedObject(v,kADPersonInterestOutline7235);
        BOOL own=gP.enabled&&ADPersonInterestBorderPlate7235(v);
        if(!own){
            if(ol){ [ol removeFromSuperlayer]; objc_setAssociatedObject(v,kADPersonInterestOutline7235,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        ADSetViewBackground7226(v,[UIColor clearColor],YES);
        v.layer.contents=nil; v.layer.borderWidth=0.0; ADPersonSetRCTBorder7208(v,0.0);
        if(!ol){
            ol=[CAShapeLayer layer]; ol.name=@"AmazonDarkPersonInterestOutline7235";
            ol.fillColor=[UIColor clearColor].CGColor; ol.lineWidth=1.0;
            ol.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"path":[NSNull null],@"strokeColor":[NSNull null],@"zPosition":[NSNull null]};
            [v.layer addSublayer:ol];
            objc_setAssociatedObject(v,kADPersonInterestOutline7235,ol,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(ol.superlayer!=v.layer)[v.layer addSublayer:ol];
        ol.frame=v.bounds; ol.strokeColor=ADBorderGray706().CGColor; ol.lineWidth=1.0;
        ol.path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(v.bounds,0.5,0.5) cornerRadius:6.0].CGPath;
        ol.zPosition=FLT_MAX; ol.hidden=v.hidden||v.alpha<0.01;
    } @catch(...) {}
}

static BOOL ADPersonOuterCardFloor7213(UIView *v){
    if(!v||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView")||ADPersonInternalMediaPlate7213(v))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<145.0||h<50.0)return NO;
        NSString *aid=(v.accessibilityIdentifier?:@"").lowercaseString;
        if(ADPersonCarouselOuter7214(v))return YES;
        if(ADPersonTopMenuPill7208(v))return YES;
        if(ADPersonBuyAgainItem7218(v))return YES;
        if([aid isEqualToString:@"carousel-item-view"])return YES;
        if([aid isEqualToString:@"yhw_healthai_0"]||[aid isEqualToString:@"yhw_pharmacy_1"]||[aid isEqualToString:@"yo_btn"])return YES;
        if([aid hasPrefix:@"tile-widget-"]||[aid isEqualToString:@"ya0"]||[aid isEqualToString:@"ya1"]||
           [aid isEqualToString:@"ya2"]||[aid isEqualToString:@"gc0"]||[aid isEqualToString:@"gc1"]||
           [aid isEqualToString:@"cvmlink"]||[aid isEqualToString:@"emptyordersstring_btn_0"])return YES;
        if(ADPersonRCTBorderWidth7208(v)>0.05||v.layer.borderWidth>0.05)return YES;
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonSemanticRoundedOwner7212(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView")||!ADInPersonTab7206(v))return NO;
    @try {
        NSString *aid=(v.accessibilityIdentifier?:@"").lowercaseString;
        if(ADPersonCarouselOuter7214(v))return YES;
        if(ADPersonTopMenuPill7208(v))return YES;
        if(ADPersonBuyAgainItem7218(v))return YES;
        if([aid isEqualToString:@"carousel-item-view"])return YES;
        if([aid isEqualToString:@"yhw_healthai_0"]||[aid isEqualToString:@"yhw_pharmacy_1"]||[aid isEqualToString:@"yo_btn"])return YES;
        if([aid hasPrefix:@"tile-widget-"])return YES;
        if([aid isEqualToString:@"cvmlink"]||[aid isEqualToString:@"emptyordersstring_btn_0"]||
           [aid isEqualToString:@"ya0"]||[aid isEqualToString:@"ya1"]||[aid isEqualToString:@"ya2"]||
           [aid isEqualToString:@"gc0"]||[aid isEqualToString:@"gc1"])return YES;
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonSameGeometrySemanticParent7212(UIView *v){
    if(!v)return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        UIView *n=v.superview;
        for(int d=0;n&&d<3;d++,n=n.superview){
            if(!ADClassNameIs7183(n,"RCTView"))continue;
            CGFloat nw=n.bounds.size.width,nh=n.bounds.size.height;
            if(fabs(nw-w)<=2.5&&fabs(nh-h)<=2.5&&ADPersonSemanticRoundedOwner7212(n))return YES;
        }
    } @catch(...) {}
    return NO;
}
// v7.218: React frequently stacks two wrappers with the same physical contour.
// Keep the ancestor/outer authored frame and clear the same-geometry child stroke.
static BOOL ADPersonSameGeometryBorderParent7218(UIView *v){
    if(!v||!ADInPersonTab7206(v))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        UIView *n=v.superview;
        for(int d=0;n&&d<3;d++,n=n.superview){
            if(!ADClassNameIs7183(n,"RCTView"))continue;
            CGFloat nw=n.bounds.size.width,nh=n.bounds.size.height;
            if(fabs(nw-w)>2.5||fabs(nh-h)>2.5)continue;
            CGFloat pw=ADPersonRCTBorderWidth7208(n);
            if(ADPersonSemanticRoundedOwner7212(n)||pw>0.05||n.layer.borderWidth>0.05)return YES;
        }
    } @catch(...) {}
    return NO;
}
static CGFloat ADPersonDesiredRadius7212(UIView *v,CGFloat authored){
    CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
    if(ADPersonTopMenuPill7208(v))return MAX(6.0,MIN(h*0.5,30.0));
    if(authored>=3.0)return authored;
    NSString *aid=(v.accessibilityIdentifier?:@"").lowercaseString;
    if([aid isEqualToString:@"carouselimagecontainer"])return 8.0;
    if([aid hasPrefix:@"tile-widget-"])return 10.0;
    if([aid isEqualToString:@"ya0"]||[aid isEqualToString:@"ya1"]||[aid isEqualToString:@"ya2"]||
       [aid isEqualToString:@"gc0"]||[aid isEqualToString:@"gc1"])return 10.0;
    if(w>=380.0&&w<=410.0&&h>=90.0&&h<=135.0)return 8.0;
    return 8.0;
}
static void ADPersonReassertBorder7206(UIView *v,BOOL wasBright){
    if(!v)return;
    @try {
        BOOL isRCT=ADClassNameIs7183(v,"RCTView");
        CGFloat layerW=v.layer.borderWidth;
        if(isRCT){
            if(ADPersonBuyAgainOuterBorderShell7238(v)){
                ADPersonSuppressBuyAgainOuterBorder7238(v);
                return;
            }
            CGFloat rctW=ADPersonRCTBorderWidth7208(v);
            CGFloat rctR=ADPersonRCTBorderRadius7212(v);
            CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
            if(w<=18.0&&h<=18.0)return; // authored carousel dots
            if(ADPersonBuyAgainWrapper7218(v)){
                // Structural Buy Again wrappers are not visible card frames.
                v.layer.borderWidth=0.0; ADPersonSetRCTBorder7208(v,0.0); return;
            }
            if(ADPersonHighlightTile7224(v)){
                v.layer.borderWidth=0.0; ADPersonSetRCTBorder7208(v,0.0); return;
            }
            if(ADPersonListCard7235(v)){
                v.layer.borderWidth=0.0; ADPersonSetRCTBorder7208(v,0.0); return;
            }
            if(ADPersonInternalMediaPlate7213(v)){
                v.layer.borderWidth=0.0; ADPersonSetRCTBorder7208(v,0.0); return;
            }
            BOOL semantic=ADPersonSemanticRoundedOwner7212(v);
            BOOL duplicateInner=ADPersonSameGeometrySemanticParent7212(v)||ADPersonSameGeometryBorderParent7218(v);
            if(duplicateInner){
                v.layer.borderWidth=0.0; ADPersonSetRCTBorder7208(v,0.0); return;
            }
            // Radius/fill is not border ownership. Only an authored border or an exact
            // semantic physical card receives a stroke. This is the v6.185 contract.
            BOOL own=(rctW>0.05||layerW>0.05||semantic);
            if(!own)return;
            if(ADPersonBuyAgainItem7218(v)){
                // Exact Buy Again uses its dedicated v6.185-style outline owner below.
                v.layer.borderWidth=0.0; ADPersonSetRCTBorder7208(v,0.0); return;
            }
            CGFloat wantW=MAX(1.0,rctW);
            CGFloat wantR=ADPersonDesiredRadius7212(v,MAX(rctR,v.layer.cornerRadius));
            v.layer.borderWidth=0.0;
            v.layer.borderColor=ADBorderGray706().CGColor;
            ADPersonSetRCTRadius7212(v,wantR);
            ADPersonSetRCTBorder7208(v,wantW);
            return;
        }
        if(layerW>0.05){
            v.layer.borderColor=ADBorderGray706().CGColor;
            if(v.layer.cornerRadius<3.0&&wasBright)v.layer.cornerRadius=8.0;
        }
    } @catch(...) {}
}
// v7.227: a border-only React shell owns only its outline.  Several Person
// media sections place this empty shell above separately-rendered image/text siblings;
// filling the shell OLED black covers otherwise healthy content.  Keep the parent's
// OLED floor visible through it instead of creating another paint layer.
static BOOL ADPersonBorderOnlyShell7227(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<72.0||h<52.0||w>430.5||h>700.0)return NO;
        if(v.subviews.count!=0||v.layer.contents!=nil)return NO;
        CGFloat rw=ADPersonRCTBorderWidth7208(v);
        return rw>0.05||v.layer.borderWidth>0.05;
    } @catch(...) { return NO; }
}

static BOOL ADPersonFloorCandidate7206(UIView *v,UIColor *candidate){
    if(!gP.enabled||!v||!(ADInPersonTab7206(v)||ADPersonBuyAgain7208(v))||!ADBrightNeutral7130(candidate))return NO;
    if([v isKindOfClass:[UIImageView class]]||[v isKindOfClass:[UILabel class]]||[v isKindOfClass:[UIControl class]])return NO;
    if(ADClassNameIs7183(v,"RCTScrollView")||ADClassNameIs7183(v,"RCTCustomScrollView")||ADClassNameIs7183(v,"RCTScrollContentView"))return NO;
    CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
    // Preserve the Shopping List carousel indicators (8-10pt) and other authored dots/glyph plates.
    if(w<24.0||h<24.0)return NO;
    return YES;
}
// v7.218 Person OLED contract: meaningful RCT card/floor colors become #000, while
// tiny authored accent plates and carousel dots stay authored. This catches the blue
// Buy Again card seen in r8 without repainting image leaves.
static BOOL ADPersonOLEDPlane7218(UIView *v,UIColor *candidate){
    if(!gP.enabled||!v||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView")||!ADPersonVisibleColor7213(candidate))return NO;
    if([v isKindOfClass:[UIImageView class]]||[v isKindOfClass:[UILabel class]]||[v isKindOfClass:[UIControl class]])return NO;
    if(ADClassNameIs7183(v,"RCTScrollView")||ADClassNameIs7183(v,"RCTCustomScrollView")||ADClassNameIs7183(v,"RCTScrollContentView"))return NO;
    CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
    if(w<=18.0&&h<=18.0)return NO;
    if(ADPersonHighlightPlate7212(v))return NO;
    if(w<=60.0&&h<=60.0&&ADPersonAccent7206(candidate))return NO;
    return w>=24.0&&h>=24.0;
}
static const void *kADPersonBuyAgainOutline7218=&kADPersonBuyAgainOutline7218;
static const void *kADPersonListCardOutline7235=&kADPersonListCardOutline7235;
static const void *kADPersonHighlightPlateOverlay7212=&kADPersonHighlightPlateOverlay7212;
static void ADPersonOwnBuyAgainItem7218(UIView *v){
    if(!v)return;
    @try {
        CAShapeLayer *ol=objc_getAssociatedObject(v,kADPersonBuyAgainOutline7218);
        if(!gP.enabled){
            if(ol){ [ol removeFromSuperlayer]; objc_setAssociatedObject(v,kADPersonBuyAgainOutline7218,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        // Preserve an existing claim across a transient Person-tab detach, matching
        // v6.185's re-entry correction. Revalidate only after the host mounts again.
        if(!v.window){ if(ol)return; return; }
        if(!ADPersonBuyAgainItem7218(v)){
            if(ol){ [ol removeFromSuperlayer]; objc_setAssociatedObject(v,kADPersonBuyAgainOutline7218,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        // v6.185 proved the white Buy Again edge is a small stretchable raster on the
        // exact card host. Clear contents ONLY on this proven host; all child media lives
        // in separate views and remains untouched.
        v.layer.contents=nil;
        v.layer.borderWidth=0.0; ADPersonSetRCTBorder7208(v,0.0);
        ADSetViewBackground7226(v,ADOLED(),YES);
        if(!ol){
            ol=[CAShapeLayer layer]; ol.name=@"AmazonDarkPersonBuyAgainOutline7218";
            ol.fillColor=[UIColor clearColor].CGColor; ol.lineWidth=1.0;
            ol.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"path":[NSNull null],@"strokeColor":[NSNull null]};
            [v.layer addSublayer:ol];
            objc_setAssociatedObject(v,kADPersonBuyAgainOutline7218,ol,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(ol.superlayer!=v.layer)[v.layer addSublayer:ol];
        ol.frame=v.bounds; ol.strokeColor=ADBorderGray706().CGColor; ol.lineWidth=1.0;
        CGRect rr=CGRectInset(v.bounds,0.5,0.5);
        ol.path=[UIBezierPath bezierPathWithRoundedRect:rr cornerRadius:8.0].CGPath;
        ol.zPosition=9998.0; ol.hidden=v.hidden||v.alpha<0.01;
    } @catch(...) {}
}
// v7.232: the full Person probe shows that most RCTView instances are transparent
// layout wrappers.  Keep exact semantic and renderer owners eligible, but let inert
// wrappers leave before the ancestry/card classifiers and border writers run.
static BOOL ADPersonNeedsVisualOwnership7232(UIView *v){
    if(!v)return NO;
    @try {
        if(v.accessibilityIdentifier.length||v.layer.contents)return YES;
        if(ADPersonVisibleColor7213(v.backgroundColor))return YES;
        if(v.layer.backgroundColor&&CGColorGetAlpha(v.layer.backgroundColor)>=0.015)return YES;
        if(v.layer.borderWidth>0.05||ADPersonRCTBorderWidth7208(v)>0.05)return YES;
        if(objc_getAssociatedObject(v,kADPersonInternalMedia7213)||
           objc_getAssociatedObject(v,kADPersonCarouselOuter7214)||
           objc_getAssociatedObject(v,kADPersonCarouselInner7214)||
           objc_getAssociatedObject(v,kADPersonHighlightTileOutline7224)||
           objc_getAssociatedObject(v,kADPersonReviewOutline7231)||
           objc_getAssociatedObject(v,kADPersonInterestOutline7235)||
           objc_getAssociatedObject(v,kADPersonListCardOutline7235)||
           objc_getAssociatedObject(v,kADPersonBuyAgainOutline7218)||
           objc_getAssociatedObject(v,kADPersonHighlightPlateOverlay7212))return YES;
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w>=250.0&&w<=325.0&&h>=300.0&&h<=500.0)return YES; // Buy Again host
        if(w>=370.0&&w<=415.0&&h>=88.0&&h<=136.0)return YES;  // carousel owner
        if(w>=40.0&&w<=60.0&&h>=40.0&&h<=60.0&&fabs(w-h)<=4.0&&
           MAX(v.layer.cornerRadius,ADPersonRCTBorderRadius7212(v))>=6.0)return YES;
    } @catch(...) {}
    return NO;
}
static void ADPersonOwnView7206(UIView *v){
    if(!gP.enabled||!v||!v.window||!(ADInPersonTab7206(v)||ADPersonBuyAgain7208(v)))return;
    @try {
        ADPersonObserveSectionAnchor7212(v);
        BOOL orderSearchOuter=ADPersonOrderSearchOuter7242(v);
        BOOL orderSearchInner=ADPersonOrderSearchInner7242(v);
        if(orderSearchOuter||orderSearchInner||objc_getAssociatedObject(v,kADPersonOrderSearchOutline7242)){
            ADPersonOwnOrderSearch7242(v);
            if(orderSearchOuter||orderSearchInner)return;
        }
        // Final exact first-paint owners run before the
        // generic visual-ownership early return. Their bad stock state can begin
        // transparent/unbordered and only become bright later in the same mount.
        BOOL interestPlate=ADPersonInterestBorderPlate7235(v);
        if(interestPlate||objc_getAssociatedObject(v,kADPersonInterestOutline7235)){
            ADPersonOwnInterestBorderPlate7235(v);
            if(interestPlate)return;
        }
        BOOL listCard=ADPersonListCard7235(v);
        if(listCard||objc_getAssociatedObject(v,kADPersonListCardOutline7235)){
            ADPersonOwnListCard7235(v);
            if(listCard)return;
        }
        if(ADPersonNestedListBorder7239(v)){
            ADPersonSuppressNestedListBorder7239(v);
            return;
        }
        if(ADPersonSubscribeOccluder7237(v)){
            ADSetViewBackground7226(v,[UIColor clearColor],YES);
            v.layer.backgroundColor=[UIColor clearColor].CGColor;
            return;
        }
        if(ADPersonBuyAgainOuterBorderShell7238(v)){
            ADPersonSuppressBuyAgainOuterBorder7238(v);
            return;
        }
        if(!ADPersonNeedsVisualOwnership7232(v))return;
        BOOL reviewPlate=ADPersonReviewBorderPlate7231(v);
        if(reviewPlate||objc_getAssociatedObject(v,kADPersonReviewOutline7231)){
            ADPersonOwnReviewBorderPlate7231(v);
            if(reviewPlate)return;
        }
        if(ADPersonBuyAgainOccluder7235(v)){
            ADSetViewBackground7226(v,[UIColor clearColor],YES);
            v.layer.backgroundColor=[UIColor clearColor].CGColor;
            return;
        }
        if(ADPersonBorderOnlyShell7227(v)){
            ADSetViewBackground7226(v,[UIColor clearColor],YES);
            return;
        }
        UIColor *bg=ADPersonBackground7213(v); BOOL bright=ADPersonFloorCandidate7206(v,bg);
        BOOL internalMedia=ADPersonInternalMediaPlate7213(v);
        BOOL outerCard=ADPersonOuterCardFloor7213(v);
        BOOL oledPlane=ADPersonOLEDPlane7218(v,bg);
        if(bright||oledPlane||((internalMedia||outerCard)&&ADPersonVisibleColor7213(bg))){
            ADSetViewBackground7226(v,ADOLED(),YES);
        }
        ADPersonReassertBorder7206(v,bright||outerCard);
        ADPersonOwnBuyAgainItem7218(v);
        ADPersonOwnHighlightTile7224(v);
        ADPersonOwnHighlightPlate7212(v);
    } @catch(...) {}
}
static BOOL ADPersonPrimaryFont7206(UIFont *font){
    if(!font||![font isKindOfClass:[UIFont class]])return NO;
    @try {
        if(font.pointSize>=17.0)return YES;
        UIFontDescriptorSymbolicTraits t=font.fontDescriptor.symbolicTraits;
        if(t&UIFontDescriptorTraitBold)return YES;
    } @catch(...) {}
    return NO;
}
static NSAttributedString *ADPersonLightString7206(NSAttributedString *in){
    if(!gP.enabled||!in||!in.length)return in;
    @try {
        NSRange whole=NSMakeRange(0,in.length); __block NSMutableAttributedString *m=nil;
        [in enumerateAttributesInRange:whole options:0 usingBlock:^(NSDictionary *attrs,NSRange range,BOOL *stop){
            UIColor *old=attrs[NSForegroundColorAttributeName];
            if(old&&ADPersonAccent7206(old))return;
            UIFont *font=attrs[NSFontAttributeName];
            UIColor *want=ADPersonPrimaryFont7206(font)?ADLightText706():ADPersonSecondary7206();
            if([old isEqual:want])return;
            if(!m)m=[in mutableCopy];
            [m addAttribute:NSForegroundColorAttributeName value:want range:range];
        }];
        return m?:in;
    } @catch(...) { return in; }
}
static void ADPersonLightStorage7206(NSTextStorage *ts){
    if(!gP.enabled||!ts||!ts.length)return;
    @try {
        NSRange whole=NSMakeRange(0,ts.length);
        __block NSMutableArray<NSValue *> *ranges=nil;
        __block NSMutableArray<UIColor *> *colors=nil;
        [ts enumerateAttributesInRange:whole options:0 usingBlock:^(NSDictionary *attrs,NSRange range,BOOL *stop){
            UIColor *old=attrs[NSForegroundColorAttributeName]; if(old&&ADPersonAccent7206(old))return;
            UIFont *font=attrs[NSFontAttributeName]; UIColor *want=ADPersonPrimaryFont7206(font)?ADLightText706():ADPersonSecondary7206();
            if([old isEqual:want])return;
            if(!ranges){ ranges=[NSMutableArray array]; colors=[NSMutableArray array]; }
            [ranges addObject:[NSValue valueWithRange:range]];
            [colors addObject:want];
        }];
        if(!ranges.count)return;
        [ts beginEditing];
        for(NSUInteger i=0;i<ranges.count;i++)
            [ts addAttribute:NSForegroundColorAttributeName value:colors[i] range:[ranges[i] rangeValue]];
        [ts endEditing];
    } @catch(...) {}
}
static NSTextStorage *ADPersonTextStorage7206(UIView *v){
    if(!v)return nil;
    @try {
        SEL sel=NSSelectorFromString(@"textStorage");
        if([v respondsToSelector:sel]){ id ts=((id(*)(id,SEL))objc_msgSend)(v,sel); if([ts isKindOfClass:[NSTextStorage class]])return ts; }
        Ivar iv=class_getInstanceVariable([v class],"_textStorage");
        if(iv){ id ts=object_getIvar(v,iv); if([ts isKindOfClass:[NSTextStorage class]])return ts; }
    } @catch(...) {}
    return nil;
}
// v7.222: the v7.217 native truth proves the visible Person section headings are
// drawn by wide RCTTextView leaves at x~=16, width 374/390 and height ~=30.7pt.
// Their RCTView/RCTTextView tint is already white while the glyphs remain visibly
// dark, proving tint / *ttl ownership is not the painter.  Own the actual text
// renderer directly by its stable heading geometry and force NSTextStorage at paint.
static BOOL ADPersonHeadingBandGeometry7221(UIView *v){
    if(!v||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        NSString *aid=(v.accessibilityIdentifier?:@"").lowercaseString;
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        // v7.299: offline/error rehydration widens Buy Again / Interests / Lists
        // title bands from 374/390pt to 414pt. Keep the exact *ttl semantic gate and
        // only widen the existing tolerance enough to cover that probe-proven variant.
        return [aid hasSuffix:@"ttl"]&&w>=300.0&&w<=420.0&&h>=20.0&&h<=46.0;
    } @catch(...) { return NO; }
}
static BOOL ADPersonHeaderLeaf7221(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v))return NO;
    @try {
        const char *cn=object_getClassName(v);
        if(!(cn&&(strstr(cn,"Text")||strstr(cn,"Paragraph"))))return NO;
        // v7.300: Gift Card Balance is the one Person heading that is not a
        // full-width ~30pt leaf. The v7.299 probe shows its 25pt bold text leaf
        // directly under exact RCTView#gctitlettl at 181x50.7 beside a reload
        // raster. Own only that direct semantic relationship, then keep the
        // established geometry owner for every ordinary Person heading.
        UIView *parent=v.superview;
        if(parent&&[parent.accessibilityIdentifier isEqualToString:@"gctitlettl"])return YES;
        CGRect r=[v convertRect:v.bounds toView:v.window];
        // Probe-proven current renderer: normal headers are 374/390pt wide;
        // offline/error rehydration mounts the same 25pt heading leaves at 414pt.
        // The x/height gates remain unchanged, so this does not become a generic
        // wide-text owner.
        return r.origin.x>=8.0&&r.origin.x<=24.0&&
               r.size.width>=360.0&&r.size.width<=420.0&&
               r.size.height>=26.0&&r.size.height<=36.0;
    } @catch(...) {}
    return NO;
}
static NSAttributedString *ADPersonHeaderString7221(NSAttributedString *in){
    if(!in||!in.length)return in;
    @try {
        UIColor *light=ADLightText706();
        NSRange whole=NSMakeRange(0,in.length),range=NSMakeRange(0,0);
        id c=[in attribute:NSForegroundColorAttributeName atIndex:0 longestEffectiveRange:&range inRange:whole];
        if(range.location==0&&NSMaxRange(range)==in.length&&[c isKindOfClass:[UIColor class]]&&[(UIColor *)c isEqual:light])return in;
        NSMutableAttributedString *m=[in mutableCopy];
        [m addAttribute:NSForegroundColorAttributeName value:light range:whole];
        return m;
    } @catch(...) { return in; }
}
static void ADPersonHeaderStorage7221(NSTextStorage *ts){
    if(!ts||!ts.length)return;
    @try {
        UIColor *light=ADLightText706(); NSRange whole=NSMakeRange(0,ts.length),range=NSMakeRange(0,0);
        id c=[ts attribute:NSForegroundColorAttributeName atIndex:0 longestEffectiveRange:&range inRange:whole];
        if(range.location==0&&NSMaxRange(range)==ts.length&&[c isKindOfClass:[UIColor class]]&&[(UIColor *)c isEqual:light])return;
        [ts beginEditing];
        [ts addAttribute:NSForegroundColorAttributeName value:light range:whole];
        [ts endEditing];
    } @catch(...) {}
}
static void ADPersonOwnText7206(UIView *v){
    if(!gP.enabled||!v||!v.window||!(ADInPersonTab7206(v)||ADPersonBuyAgain7208(v)))return;
    const char *cn=object_getClassName(v);
    BOOL textish=[v isKindOfClass:[UILabel class]]||(cn&&(strstr(cn,"Text")||strstr(cn,"Paragraph")));
    if(!textish)return;
    @try {
        BOOL header=ADPersonHeaderLeaf7221(v);
        if([v isKindOfClass:[UILabel class]]){
            UILabel *l=(UILabel *)v;
            if(header){ l.textColor=ADLightText706(); if(l.attributedText.length)l.attributedText=ADPersonHeaderString7221(l.attributedText); return; }
            if(ADPersonAccent7206(l.textColor))return;
            UIColor *want=(l.font.pointSize>=17.0||ADPersonPrimaryFont7206(l.font))?ADLightText706():ADPersonSecondary7206();
            l.textColor=want;
            if(l.attributedText.length){ NSAttributedString *r=ADPersonLightString7206(l.attributedText); if(r)l.attributedText=r; }
            return;
        }
        NSTextStorage *ts=ADPersonTextStorage7206(v); if(ts){ if(header)ADPersonHeaderStorage7221(ts); else ADPersonLightStorage7206(ts); }
        if(header){
            SEL setColor=NSSelectorFromString(@"setTextColor:");
            if([v respondsToSelector:setColor])((void(*)(id,SEL,UIColor *))objc_msgSend)(v,setColor,ADLightText706());
            [v setNeedsDisplay]; [v.layer setNeedsDisplay];
        }
    } @catch(...) {}
}
// Exact section-chevron locator; shares the same probe-proven header-band gate.
static BOOL ADPersonHeadingBand7217(UIView *v){ return ADPersonHeadingBandGeometry7221(v); }
static const void *kADPersonListSection7212=&kADPersonListSection7212;
static const void *kADPersonReviewSection7212=&kADPersonReviewSection7212;
static UIView *ADPersonCompactSectionRoot7212(UIView *v,CGFloat minH,CGFloat maxH){
    if(!v)return nil;
    @try {
        for(UIView *n=v.superview;n;n=n.superview){
            if(!ADInPersonTab7206(n))break;
            CGFloat w=n.bounds.size.width,h=n.bounds.size.height;
            if(w>=320.0&&w<=430.5&&h>=minH&&h<=maxH)return n;
        }
    } @catch(...) {}
    return nil;
}
static BOOL ADPersonUnderMarker7212(UIView *v,const void *key){
    @try {
        for(UIView *n=v;n;n=n.superview){
            if(objc_getAssociatedObject(n,key))return YES;
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonInHighlightTile7212(UIView *v){
    if(!v)return NO;
    @try {
        for(UIView *n=v;n;n=n.superview){
            NSString *aid=(n.accessibilityIdentifier?:@"").lowercaseString;
            if([aid hasPrefix:@"tile-widget-"]||[aid hasPrefix:@"tile-image-iconsection-"])return YES;
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
    } @catch(...) {}
    return NO;
}
static void ADPersonPrimeMarkedMedia7212(UIView *root){
    if(!root||!root.window)return;
    @try {
        NSMutableArray<UIView *> *stack=[NSMutableArray arrayWithObject:root];
        int seen=0;
        while(stack.count&&seen<120){
            UIView *v=stack.lastObject; [stack removeLastObject]; seen++;
            if([v isKindOfClass:[UIImageView class]]){
                // The same recycled UIImage can have been cached as blocked before the
                // Lists/Reviews section marker existed.  Invalidate that stale answer
                // before forcing the newly-positive section media through TWB.
                ADResetNativeTWBCache7214((UIImageView *)v);
                ADApplyNativeTWBCached7183((UIImageView *)v,NO);
            }
            for(UIView *c in v.subviews)if(c.window==root.window)[stack addObject:c];
        }
    } @catch(...) {}
}
static void ADPersonMarkSection7212(UIView *source,const void *key,CGFloat minH,CGFloat maxH){
    UIView *root=ADPersonCompactSectionRoot7212(source,minH,maxH);
    if(!root||objc_getAssociatedObject(root,key))return;
    objc_setAssociatedObject(root,key,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ADPersonPrimeMarkedMedia7212(root);
}
static void ADPersonObserveSectionAnchor7212(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v))return;
    @try {
        NSString *aid=v.accessibilityIdentifier;
        if(aid.length&&([aid isEqualToString:@"wl_titlettl"]||[aid caseInsensitiveCompare:@"wl_titlettl"]==NSOrderedSame))
            ADPersonMarkSection7212(v,kADPersonListSection7212,145.0,235.0);
    } @catch(...) {}
}
// v7.235: Lists & Registries reports an authored 8pt radius but its final
// 400x108 border/fill raster is square. Replace only the marker-scoped physical card.
static BOOL ADPersonListCard7235(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        if(objc_getAssociatedObject(v,kADPersonListCardOutline7235))return YES;
        // v7.239: the probe separates the persistent Lists viewport (400x108) from
        // recycled 400x106 carousel pages. Only the persistent viewport owns a frame.
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        return w>=398.0&&w<=402.0&&h>=107.5&&h<=110.0;
    } @catch(...) { return NO; }
}
static BOOL ADPersonNestedListBorder7239(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<340.0||w>402.0||h<90.0||h>107.0)return NO;
        UIView *n=v.superview;
        for(int d=0;n&&d<8;d++,n=n.superview){
            if(ADPersonListCard7235(n))return YES;
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
    } @catch(...) {}
    return NO;
}
static void ADPersonSuppressNestedListBorder7239(UIView *v){
    if(!ADPersonNestedListBorder7239(v))return;
    @try {
        CAShapeLayer *old=objc_getAssociatedObject(v,kADPersonListCardOutline7235);
        if(old){ [old removeFromSuperlayer]; objc_setAssociatedObject(v,kADPersonListCardOutline7235,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        ADSetViewBackground7226(v,ADOLED(),YES);
        v.layer.contents=nil;
        v.layer.borderWidth=0.0;
        ADPersonSetRCTBorder7208(v,0.0);
    } @catch(...) {}
}
static void ADPersonOwnListCard7235(UIView *v){
    if(!v)return;
    @try {
        CAShapeLayer *ol=objc_getAssociatedObject(v,kADPersonListCardOutline7235);
        BOOL own=gP.enabled&&ADPersonListCard7235(v);
        if(!own){
            if(ol){ [ol removeFromSuperlayer]; objc_setAssociatedObject(v,kADPersonListCardOutline7235,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        ADSetViewBackground7226(v,ADOLED(),YES);
        v.layer.contents=nil; v.layer.borderWidth=0.0; ADPersonSetRCTBorder7208(v,0.0);
        if(!ol){
            ol=[CAShapeLayer layer]; ol.name=@"AmazonDarkPersonListCardOutline7235";
            ol.fillColor=[UIColor clearColor].CGColor; ol.lineWidth=1.0;
            ol.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"path":[NSNull null],@"strokeColor":[NSNull null],@"zPosition":[NSNull null]};
            [v.layer addSublayer:ol]; objc_setAssociatedObject(v,kADPersonListCardOutline7235,ol,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(ol.superlayer!=v.layer)[v.layer addSublayer:ol];
        ol.frame=v.bounds; ol.strokeColor=ADBorderGray706().CGColor; ol.lineWidth=1.0;
        ol.path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(v.bounds,0.5,0.5) cornerRadius:8.0].CGPath;
        ol.zPosition=FLT_MAX; ol.hidden=v.hidden||v.alpha<0.01;
    } @catch(...) {}
}

static BOOL ADPersonForcedMedia7212(UIImageView *iv){
    if(!iv||!ADInPersonTab7206(iv))return NO;
    @try {
        NSString *aid=(iv.accessibilityIdentifier?:@"").lowercaseString;
        if([aid isEqualToString:@"avr_image"]){
            ADPersonMarkSection7212(iv,kADPersonReviewSection7212,145.0,260.0);
            return YES;
        }
        if([aid hasPrefix:@"tile-image-iconsection-"])return YES;
        if(ADPersonUnderMarker7212(iv,kADPersonListSection7212)||ADPersonUnderMarker7212(iv,kADPersonReviewSection7212))return YES;
        if(ADPersonInHighlightTile7212(iv))return YES;
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonHighlightPlate7212(UIView *v){
    if(!v||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<40.0||w>60.0||h<40.0||h>60.0||fabs(w-h)>4.0)return NO;
        CGFloat rr=MAX(v.layer.cornerRadius,ADPersonRCTBorderRadius7212(v));
        // v7.228: Highlights now also ships this exact iconSection plate as a rounded
        // square. The semantic descendant gate below is exact, so accept either the
        // older circle or the current rounded-square plate without broadening ownership.
        if(rr<6.0)return NO;
        NSString *selfAid=(v.accessibilityIdentifier?:@"").lowercaseString;
        if([selfAid hasPrefix:@"tile-image-iconsection-"])return YES;
        NSMutableArray<UIView *> *stack=[NSMutableArray arrayWithArray:v.subviews]; int seen=0;
        while(stack.count&&seen<16){
            UIView *n=stack.lastObject; [stack removeLastObject]; seen++;
            NSString *aid=(n.accessibilityIdentifier?:@"").lowercaseString;
            if([aid hasPrefix:@"tile-image-iconsection-"])return YES;
            for(UIView *c in n.subviews)[stack addObject:c];
        }
    } @catch(...) {}
    return NO;
}
static void ADPersonOwnHighlightPlate7212(UIView *v){
    if(!ADPersonHighlightPlate7212(v))return;
    @try {
        CALayer *ov=objc_getAssociatedObject(v,kADPersonHighlightPlateOverlay7212);
        // This is an authored control plate, not product media. Shading the plate or
        // its 24x24 arrow leaf creates the visible black square captured in v7.229.
        // Preserve the blue circle and let the arrow owner paint its glyph light.
        if(ov){
            [ov removeFromSuperlayer];
            objc_setAssociatedObject(v,kADPersonHighlightPlateOverlay7212,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } @catch(...) {}
}

// v7.218: image leaves are classified by exact Person section anchors; do not overlay
// arbitrary RCTView raster plates or clear their contents.
// v7.218: compact, identifier-driven version of the first working Person media pass.
// It uses exact section title identifiers from the v7.217 probes, not a global semantic scan.
// 0 unknown, 1 authored/no-TWB (Medical Care), 2 commerce/product, 3 Reviews, 4 Highlights.
static int ADPersonTitleKind7218(NSString *aid){
    NSString *a=(aid?:@"").lowercaseString;
    if([a isEqualToString:@"yhwttl"])return 1;
    if([a isEqualToString:@"cm_yc-titlettl"])return 3;
    if([a isEqualToString:@"gpw-title-idttl"])return 4;
    if([a isEqualToString:@"yo_titlettl"]||[a isEqualToString:@"bya-titlettl"]||
       [a isEqualToString:@"aiwl_widget_titlettl"]||[a isEqualToString:@"aiwl_widget_title_errttl"]||
       [a isEqualToString:@"msp_sns_title_successttl"]||
       [a isEqualToString:@"shop-previously-watched-header-titlettl"]||[a isEqualToString:@"wl_titlettl"]||
       [a isEqualToString:@"mcttl"])return 2;
    return 0;
}
static int ADPersonSectionKind7218(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v))return 0;
    @try {
        NSString *selfAid=(v.accessibilityIdentifier?:@"").lowercaseString;
        if([selfAid isEqualToString:@"avr_image"])return 3;
        if([selfAid hasPrefix:@"tile-image-url-"]||[selfAid hasPrefix:@"tile-image-iconsection-"])return 4;
        if([selfAid containsString:@"product-image"]||[selfAid containsString:@"carousel-item-image"])return 2;
        UIView *p=v;
        for(int up=0;p&&up<8&&ADInPersonTab7206(p);up++,p=p.superview){
            NSString *aid=(p.accessibilityIdentifier?:@"").lowercaseString;
            int direct=ADPersonTitleKind7218(aid); if(direct)return direct;
            if([aid isEqualToString:@"yhw_healthai_0"]||[aid isEqualToString:@"yhw_pharmacy_1"])return 1;
            if([aid isEqualToString:@"carousel-item-view"]||[aid isEqualToString:@"buy-again-flow-card"]||
               [aid isEqualToString:@"cardwrapperview"]||[aid isEqualToString:@"tmpwrapperview"])return 2;
            if([aid hasPrefix:@"tile-widget-"])return 4;
            CGFloat w=p.bounds.size.width,h=p.bounds.size.height;
            if(w<80.0||w>430.5||h<40.0||h>650.0)continue;
            // Search only the nearest section-sized ancestor. If it contains exactly one
            // recognized title band, that title defines its image leaves.
            NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:p];
            int seen=0,found=0,mixed=0;
            while(q.count&&seen++<72){
                UIView *x=q.firstObject; [q removeObjectAtIndex:0];
                int k=ADPersonTitleKind7218(x.accessibilityIdentifier);
                if(k){ if(!found)found=k; else if(found!=k){mixed=1;break;} }
                if(seen<30)for(UIView *c in x.subviews){ if(q.count<72)[q addObject:c]; else break; }
            }
            if(found&&!mixed)return found;
        }
    } @catch(...) {}
    return 0;
}
// v7.229 probe-backed Person corrections.  These gates are derived only from the
// captured frame: Medical Care text reports pSec=1, Reviews text reports pSec=3
// (with avr_title as the one direct leaf that reports pSec=0), Gift Card buttons
// sit under exact gc0/gc1 wrappers, and the bottom Customer Service row is the
// unique 398x58 rounded/bordered row with a 40x40 leading image and 20x20 trailing image.
static BOOL ADPersonCustomerServiceRow7229(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v))return NO;
    @try {
        for(UIView *n=v;n;n=n.superview){
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
            CGFloat w=n.bounds.size.width,h=n.bounds.size.height;
            if(w<380.0||w>410.0||h<52.0||h>64.0)continue;
            CGFloat bw=MAX(n.layer.borderWidth,ADPersonRCTBorderWidth7208(n));
            CGFloat rr=MAX(n.layer.cornerRadius,ADPersonRCTBorderRadius7212(n));
            if(bw<0.5||rr<6.0||rr>14.0)continue;
            int lead40=0,trail20=0,textish=0;
            NSMutableArray<UIView *> *q=[NSMutableArray arrayWithArray:n.subviews]; int seen=0;
            while(q.count&&seen++<28){
                UIView *x=q.firstObject; [q removeObjectAtIndex:0];
                CGRect xr=[x convertRect:x.bounds toView:n];
                CGFloat xw=x.bounds.size.width,xh=x.bounds.size.height;
                if([x isKindOfClass:[UIImageView class]]){
                    if(xw>=36.0&&xw<=44.0&&xh>=36.0&&xh<=44.0&&CGRectGetMidX(xr)<70.0)lead40++;
                    if(xw>=16.0&&xw<=24.0&&xh>=16.0&&xh<=24.0&&CGRectGetMidX(xr)>350.0)trail20++;
                }
                const char *cn=object_getClassName(x);
                if([x isKindOfClass:[UILabel class]]||(cn&&(strstr(cn,"Text")||strstr(cn,"Paragraph"))))textish++;
                if(seen<18)for(UIView *c in x.subviews)[q addObject:c];
            }
            if(lead40>=1&&trail20>=1&&textish>=1)return YES;
        }
    } @catch(...) {}
    return NO;
}
// v7.237: Keep Shopping product copy is rendered by text leaves whose local
// 128x171 card also owns an exact `carouselImageContainer`. The first rows could
// retain Amazon's darker pre-theme text until recycling/refresh. Own only those
// local text leaves at final draw; no section-wide text sweep is introduced.
static BOOL ADPersonKeepShoppingText7237(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v))return NO;
    @try {
        const char *cn=object_getClassName(v);
        if(!(cn&&(strstr(cn,"Text")||strstr(cn,"Paragraph"))))return NO;
        CGFloat tw=v.bounds.size.width,th=v.bounds.size.height;
        if(tw<70.0||tw>155.0||th<12.0||th>56.0)return NO;
        UIView *card=v.superview;
        for(int up=0;card&&up<3;up++,card=card.superview){
            CGFloat w=card.bounds.size.width,h=card.bounds.size.height;
            if(w<118.0||w>145.0||h<150.0||h>185.0)continue;
            NSMutableArray<UIView *> *q=[NSMutableArray arrayWithArray:card.subviews]; int seen=0;
            while(q.count&&seen++<14){
                UIView *x=q.firstObject; [q removeObjectAtIndex:0];
                NSString *aid=(x.accessibilityIdentifier?:@"").lowercaseString;
                if([aid isEqualToString:@"carouselimagecontainer"])return YES;
                if(seen<8)for(UIView *c in x.subviews)if(q.count<14)[q addObject:c];
            }
        }
    } @catch(...) {}
    return NO;
}

// v7.240: probe-proven Your Interests title leaves are the top text lane
// inside aiwl_widget0/1. Match that local lane, not the whole card, so the authored
// teal item-count copy near the bottom remains untouched.
static BOOL ADPersonInterestTitle7240(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v))return NO;
    @try {
        const char *cn=object_getClassName(v);
        if(!(cn&&(strstr(cn,"Text")||strstr(cn,"Paragraph"))))return NO;
        UIView *widget=nil;
        UIView *n=v.superview;
        for(int d=0;n&&d<4&&n!=v.window;d++,n=n.superview){
            NSString *aid=(n.accessibilityIdentifier?:@"").lowercaseString;
            if([aid isEqualToString:@"aiwl_widget0"]||[aid isEqualToString:@"aiwl_widget1"]){ widget=n; break; }
            if([aid isEqualToString:@"me"])break;
        }
        if(!widget)return NO;
        CGRect r=[v convertRect:v.bounds toView:widget];
        if(r.size.height<19.0||r.size.height>28.0||CGRectGetMinY(r)<-1.0||CGRectGetMinY(r)>16.0)return NO;
        if(CGRectGetMinX(r)<4.0||CGRectGetMinX(r)>18.0||r.size.width<135.0||r.size.width>170.0)return NO;
        NSTextStorage *ts=ADPersonTextStorage7206(v);
        if(!ts||!ts.length)return NO;
        __block BOOL primary=NO;
        [ts enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0,ts.length) options:0 usingBlock:^(id value,NSRange range,BOOL *stop){
            if(ADPersonPrimaryFont7206(value)){ primary=YES; *stop=YES; }
        }];
        return primary;
    } @catch(...) { return NO; }
}

static BOOL ADPersonTopRowText7239(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v))return NO;
    @try {
        const char *cn=object_getClassName(v);
        if(!(cn&&(strstr(cn,"Text")||strstr(cn,"Paragraph"))))return NO;
        // Probe-proven primary text leaves: greeting under xopufnv and language
        // label beside the authored flag under calv. Both are stock 17pt primary text.
        return ADPersonAncestorAid7235(v,@"xopufnv",2)||ADPersonAncestorAid7235(v,@"calv",3);
    } @catch(...) { return NO; }
}

// v7.250: the v7.238 Person probe identifies each top oval as an exact RCTView
// (bac_yo / bac_ya / bac_wl / bac_aiwl) with one direct 15pt RCTTextView child.
// That text is intentionally forced to the normal light foreground instead of the
// generic 15pt Person-secondary gray. Border/floor ownership remains untouched.
static BOOL ADPersonTopMenuPillText7250(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTTextView"))return NO;
    @try {
        UIView *p=v.superview;
        return p&&ADPersonTopMenuPill7208(p);
    } @catch(...) { return NO; }
}
static void ADPersonTopMenuPillWhiteStorage7250(NSTextStorage *ts){
    if(!gP.enabled||!ts||!ts.length)return;
    @try { [ts addAttribute:NSForegroundColorAttributeName value:ADLightText706() range:NSMakeRange(0,ts.length)]; } @catch(...) {}
}

// v7.265: Your Orders refresh/retry remounts the probe-proven card header as
// RCTTextView#ImageWithTextViewTextComponent under yo_btn/YoAsinCarouselItem*.
// Assignment-time Person recoloring can occur before the leaf has final Person ancestry,
// so reassert this exact card-header lane at draw time. No generic Person text scan.
static BOOL ADPersonOrderCardHeaderText7265(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTTextView"))return NO;
    @try {
        if(![(v.accessibilityIdentifier?:@"") isEqualToString:@"ImageWithTextViewTextComponent"])return NO;
        int depth=0;
        for(UIView *n=v.superview;n&&n!=v.window&&depth++<8;n=n.superview){
            NSString *aid=(n.accessibilityIdentifier?:@"").lowercaseString;
            if([aid isEqualToString:@"yo_btn"])return YES;
            if([aid isEqualToString:@"me"])break;
        }
    } @catch(...) {}
    return NO;
}

// v7.299: offline/error rehydration mounts the Buy Again / Interests fallback
// action labels under one exact technical owner, and Lists under a second one.
// Their cards/borders already match the working Keep-shopping fallback; only the
// final RCTTextView foreground survives as Amazon's dark authored color.
static BOOL ADPersonOfflineFallbackButtonText7299(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTTextView"))return NO;
    @try {
        for(UIView *n=v.superview;n&&n!=v.window;n=n.superview){
            NSString *aid=(n.accessibilityIdentifier?:@"").lowercaseString;
            if([aid isEqualToString:@"error-message-container_btn"]||
               [aid isEqualToString:@"errorliststring_btn"])return YES;
            if([aid isEqualToString:@"me"])break;
        }
    } @catch(...) {}
    return NO;
}
// Match the probe-proven working Keep-shopping fallback action exactly rather than
// inventing a new contrast color. Its 17pt action leaf finishes at rgb(55,62,62).
static UIColor *ADPersonOfflineFallbackAction7299(void){
    static UIColor *c=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ c=[UIColor colorWithRed:55.0/255.0 green:62.0/255.0 blue:62.0/255.0 alpha:1.0]; });
    return c;
}
static NSAttributedString *ADPersonOfflineFallbackButtonString7299(NSAttributedString *in){
    if(!in||!in.length)return in;
    @try {
        NSMutableAttributedString *m=[in mutableCopy];
        [m addAttribute:NSForegroundColorAttributeName value:ADPersonOfflineFallbackAction7299() range:NSMakeRange(0,m.length)];
        return m;
    } @catch(...) { return in; }
}
static void ADPersonOfflineFallbackButtonStorage7299(NSTextStorage *ts){
    if(!ts||!ts.length)return;
    @try {
        [ts addAttribute:NSForegroundColorAttributeName value:ADPersonOfflineFallbackAction7299() range:NSMakeRange(0,ts.length)];
    } @catch(...) {}
}

static BOOL ADPersonFinalTextOwner7239(UIView *v){
    if(!v||!v.window)return NO;
    BOOL buyAgain=ADPersonBuyAgain7208(v);
    if(!ADInPersonTab7206(v)&&!buyAgain)return NO;
    @try {
        int kind=ADPersonSectionKind7218(v);
        if(kind==1||kind==3)return YES;
        if(ADPersonOrderCardHeaderText7265(v)||ADPersonKeepShoppingText7237(v)||ADPersonTopRowText7239(v)||
           ADPersonInterestTitle7240(v)||ADPersonOfflineFallbackButtonText7299(v))return YES;
        // v7.236 first-paint repair: the v7.235 probe captured dark primary text
        // surviving in Buy Again and under the Subscribe & Save delivery wrapper.
        // Reuse the existing font-aware storage recolor at final draw: bold/primary
        // runs become light while regular secondary copy stays secondary gray.
        if(buyAgain)return YES;
        if(ADPersonAncestorAid7235(v,@"me_tab_delivery_name_a11y_id",14))return YES;
        NSString *aid=(v.accessibilityIdentifier?:@"").lowercaseString;
        if([aid isEqualToString:@"avr_title"])return YES;
        for(UIView *n=v;n;n=n.superview){
            NSString *a=(n.accessibilityIdentifier?:@"").lowercaseString;
            if([a isEqualToString:@"gc0"]||[a isEqualToString:@"gc1"]||[a isEqualToString:@"cvmlink"])return YES;
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
        if(ADPersonCustomerServiceRow7229(v))return YES;
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonMedicalAuthoredIcon7231(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||!ADInPersonTab7206(iv))return NO;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<32.0||w>60.0||h<32.0||h>60.0)return NO;
        for(UIView *n=iv.superview;n&&n!=iv.window;n=n.superview){
            NSString *aid=(n.accessibilityIdentifier?:@"").lowercaseString;
            if([aid isEqualToString:@"yhw_healthai_0"]||[aid isEqualToString:@"yhw_pharmacy_1"])return YES;
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonReviewCompactImage7229(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||!ADInPersonTab7206(iv))return NO;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<36.0||w>44.0||h<36.0||h>44.0||fabs(w-h)>3.0)return NO;
        for(UIView *n=iv.superview;n&&n!=iv.window;n=n.superview){
            if(ADPersonSectionKind7218(n)==3)return YES;
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonCustomerServiceLeadingImage7229(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||!ADPersonCustomerServiceRow7229(iv))return NO;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<36.0||w>44.0||h<36.0||h>44.0)return NO;
        UIView *row=nil;
        for(UIView *n=iv.superview;n;n=n.superview){ if(ADPersonCustomerServiceRow7229(n)){ row=n; break; } }
        if(!row)return NO;
        CGRect r=[iv convertRect:iv.bounds toView:row];
        return CGRectGetMidX(r)<70.0;
    } @catch(...) { return NO; }
}
static BOOL ADPersonAncestorAid7235(UIView *v,NSString *wanted,int maxDepth){
    if(!v||!wanted.length)return NO;
    @try {
        NSString *want=wanted.lowercaseString; UIView *n=v.superview;
        for(int d=0;n&&d<maxDepth;d++,n=n.superview){
            NSString *aid=(n.accessibilityIdentifier?:@"").lowercaseString;
            if([aid isEqualToString:want])return YES;
            if([aid isEqualToString:@"me"])break;
        }
    } @catch(...) {}
    return NO;
}
// v7.237 probe-backed top-row authored rasters. These images all contain real
// CGImage pixels but were reaching final paint as AlwaysTemplate. Restore their
// stock pixels instead of hardcoding replacement art/colors.
static BOOL ADPersonAvatarImage7237(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||!ADInPersonTab7206(iv))return NO;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        return w>=24.0&&w<=32.0&&h>=24.0&&h<=32.0&&fabs(w-h)<=3.0&&
               ADPersonAncestorAid7235(iv,@"user_avatar",5);
    } @catch(...) { return NO; }
}
static BOOL ADPersonNotificationBadge7237(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||!ADInPersonTab7206(iv))return NO;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        return w>=6.0&&w<=10.0&&h>=6.0&&h<=10.0&&fabs(w-h)<=2.0&&
               ADPersonAncestorAid7235(iv,@"notification-icon",5);
    } @catch(...) { return NO; }
}
static BOOL ADPersonCountryFlag7237(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||!ADInPersonTab7206(iv))return NO;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        return w>=20.0&&w<=30.0&&h>=12.0&&h<=22.0&&
               ADPersonAncestorAid7235(iv,@"calv",6);
    } @catch(...) { return NO; }
}

// The Subscribe & Save raster itself is already real/AlwaysOriginal/TWB in the
// v7.235 probe. An empty opaque 60x64 sibling sits above that 48x52 raster inside
// me_tab_delivery_asin0_a11y_id. Remove only that exact occluder.
static BOOL ADPersonSubscribeOccluder7237(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<56.0||w>64.0||h<60.0||h>68.0||v.subviews.count||v.layer.contents)return NO;
        if(!ADPersonAncestorAid7235(v,@"me_tab_delivery_asin0_a11y_id",4))return NO;
        UIView *p=v.superview; if(!p)return NO;
        CGFloat pw=p.bounds.size.width,ph=p.bounds.size.height;
        return pw>=56.0&&pw<=64.0&&ph>=60.0&&ph<=68.0;
    } @catch(...) { return NO; }
}

static BOOL ADPersonSubscribeImage7235(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||!ADInPersonTab7206(iv))return NO;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<38.0||w>68.0||h<38.0||h>68.0)return NO;
        return ADPersonAncestorAid7235(iv,@"me_tab_delivery_asin0_a11y_id",12)||ADPersonAncestorAid7235(iv,@"me_tab_delivery_name_a11y_id",14);
    } @catch(...) { return NO; }
}
static BOOL ADPersonPreviouslyWatchedImage7235(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||!ADInPersonTab7206(iv))return NO;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<38.0||w>62.0||h<38.0||h>62.0)return NO;
        BOOL product=NO,widget=NO; UIView *n=iv.superview;
        for(int d=0;n&&d<14;d++,n=n.superview){
            NSString *aid=(n.accessibilityIdentifier?:@"").lowercaseString;
            if([aid hasPrefix:@"product-image-"])product=YES;
            if([aid isEqualToString:@"shop-previously-watched-widget"]){ widget=YES; break; }
            if([aid isEqualToString:@"me"])break;
        }
        return product&&widget;
    } @catch(...) { return NO; }
}
// v7.240: the Highlights explore-all arrow is an 8pt authored glyph inside a
// 24x24 `tile-image-iconSection-*` wrapper under the exact `tile-widget-explore-all`
// owner. Horizontal carousel recycling can place it thousands of points outside the
// Person root, so trailing-edge geometry is not reliable here. Use the two semantic
// owners instead, which also avoids touching authored iconSection artwork elsewhere.
static BOOL ADPersonHighlightIconArrow7240(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||!ADInPersonTab7206(iv))return NO;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<18.0||w>30.0||h<18.0||h>30.0)return NO;
        BOOL iconSection=NO,exploreAll=NO; UIView *n=iv.superview;
        for(int d=0;n&&d<10&&n!=iv.window;d++,n=n.superview){
            NSString *aid=(n.accessibilityIdentifier?:@"").lowercaseString;
            if([aid hasPrefix:@"tile-image-iconsection-"])iconSection=YES;
            else if([aid isEqualToString:@"tile-widget-explore-all"])exploreAll=YES;
            if(iconSection&&exploreAll)return YES;
            if([aid isEqualToString:@"me"])break;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonHighlightArrowLeaf7235(UIImageView *iv){
    return iv&&iv.window&&iv.image&&ADPersonHighlightImageContext7224(iv)&&
           (ADPersonHighlightIconArrow7240(iv)||ADPersonRightArrow7231(iv));
}
// v7.299: Your Orders' offline error row contains a real authored 18x20 raster
// inside a 20x20 RCTImageView. The v7.297 probe shows it being misclassified as
// section commerce media (forced18=1), ending AlwaysTemplate with TWB and appearing
// as a blank square. Recognize only that compact two-child error row so the authored
// pixels can remain AlwaysOriginal with no TWB.
static BOOL ADPersonOfflineErrorRaster7299(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||!ADInPersonTab7206(iv)||!ADClassNameIs7183(iv,"RCTUIImageViewAnimated"))return NO;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<18.0||w>22.0||h<18.0||h>22.0)return NO;
        if(ADPersonSectionKind7218(iv)!=2)return NO;
        UIView *imageWrap=iv.superview;
        if(!imageWrap||!ADClassNameIs7183(imageWrap,"RCTImageView"))return NO;
        CGFloat ww=imageWrap.bounds.size.width,wh=imageWrap.bounds.size.height;
        if(ww<18.0||ww>22.0||wh<18.0||wh>22.0)return NO;
        UIView *row=imageWrap.superview;
        if(!row||!ADClassNameIs7183(row,"RCTView")||row.subviews.count!=2)return NO;
        CGRect rr=[row convertRect:row.bounds toView:iv.window];
        if(rr.origin.x<10.0||rr.origin.x>20.0||rr.size.width<390.0||rr.size.width>410.0||
           rr.size.height<18.0||rr.size.height>26.0)return NO;
        BOOL textSibling=NO;
        for(UIView *c in row.subviews){
            if(c==imageWrap)continue;
            if(ADClassNameIs7183(c,"RCTTextView")){
                CGFloat cw=c.bounds.size.width,ch=c.bounds.size.height;
                if(cw>=240.0&&ch>=18.0&&ch<=30.0){ textSibling=YES; break; }
            }
        }
        if(!textSibling)return NO;
        CGSize is=iv.image.size;
        return is.width>=16.0&&is.width<=20.5&&is.height>=18.0&&is.height<=22.0;
    } @catch(...) { return NO; }
}
static BOOL ADPersonForcedMedia7218(UIImageView *iv){
    if(ADPersonOfflineErrorRaster7299(iv))return NO;
    int k=ADPersonSectionKind7218(iv); return k==2||k==3||k==4;
}
static const void *kADPersonHighlightImageOverlay7221=&kADPersonHighlightImageOverlay7221;
// v7.224: RCTImageView is only the semantic wrapper for current Highlights images.
// The actual pixels are painted by an anonymous RCTUIImageViewAnimated child.  The old
// exact-aid overlay therefore landed on the wrapper while the blue raster could remain
// above/outside that paint.  Resolve the semantic context through ancestors and own only
// the deepest UIImageView that actually carries image pixels.
static BOOL ADPersonHighlightImageContext7224(UIView *v){
    if(!v||!ADInPersonTab7206(v))return NO;
    @try {
        for(UIView *n=v;n;n=n.superview){
            NSString *aid=(n.accessibilityIdentifier?:@"").lowercaseString;
            if([aid hasPrefix:@"tile-image-url-"]||[aid hasPrefix:@"tile-image-iconsection-"])return YES;
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonHasRasterDescendant7229(UIView *root){
    if(!root)return NO;
    @try {
        NSMutableArray<UIView *> *q=[NSMutableArray arrayWithArray:root.subviews]; int seen=0;
        while(q.count&&seen++<18){
            UIView *v=q.firstObject; [q removeObjectAtIndex:0];
            if([v isKindOfClass:[UIImageView class]]&&((UIImageView *)v).image)return YES;
            if(seen<10)for(UIView *c in v.subviews)[q addObject:c];
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonImageHasRasterDescendant7224(UIImageView *iv){ return ADPersonHasRasterDescendant7229(iv); }
static const void *kADPersonHighlightWrapperOverlay7229=&kADPersonHighlightWrapperOverlay7229;
static BOOL ADPersonHighlightWrapperOwner7229(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTImageView"))return NO;
    @try {
        NSString *aid=(v.accessibilityIdentifier?:@"").lowercaseString;
        if(!([aid hasPrefix:@"tile-image-url-"]||[aid hasPrefix:@"tile-image-iconsection-"]))return NO;
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<40.0||w>120.0||h<40.0||h>120.0)return NO;
        return !ADPersonHasRasterDescendant7229(v);
    } @catch(...) { return NO; }
}
static void ADPersonOwnHighlightWrapper7229(UIView *v){
    if(!v)return;
    @try {
        CALayer *ov=objc_getAssociatedObject(v,kADPersonHighlightWrapperOverlay7229);
        BOOL own=gP.enabled&&gP.whiteTame&&ADPersonHighlightWrapperOwner7229(v);
        if(!own){ if(ov){ [ov removeFromSuperlayer]; objc_setAssociatedObject(v,kADPersonHighlightWrapperOverlay7229,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); } return; }
        if(!ov){
            ov=[CALayer layer]; ov.name=@"AmazonDarkPersonHighlightWrapperTWB7229";
            ov.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"backgroundColor":[NSNull null],@"cornerRadius":[NSNull null],@"zPosition":[NSNull null]};
            [v.layer addSublayer:ov];
            objc_setAssociatedObject(v,kADPersonHighlightWrapperOverlay7229,ov,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(ov.superlayer!=v.layer)[v.layer addSublayer:ov];
        ov.frame=v.bounds; ov.cornerRadius=MAX(v.layer.cornerRadius,12.0);
        ov.backgroundColor=ADNativeTWBOverlayColor7146().CGColor; ov.zPosition=FLT_MAX;
    } @catch(...) {}
}
static BOOL ADPersonExactHighlightImage7221(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||!ADPersonHighlightImageContext7224(iv))return NO;
    if(ADPersonRightArrow7231(iv)||ADPersonHighlightIconArrow7240(iv))return NO;
    return !ADPersonImageHasRasterDescendant7224(iv);
}
static void ADPersonApplyExactHighlightTWB7221(UIImageView *iv){
    if(!iv)return;
    @try {
        CALayer *ov=objc_getAssociatedObject(iv,kADPersonHighlightImageOverlay7221);
        BOOL own=gP.enabled&&gP.whiteTame&&iv.window&&ADPersonExactHighlightImage7221(iv);
        if(!own){ if(ov){ [ov removeFromSuperlayer]; objc_setAssociatedObject(iv,kADPersonHighlightImageOverlay7221,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); } return; }
        if(!ov){
            ov=[CALayer layer]; ov.name=@"AmazonDarkPersonHighlightImageTWB7221";
            ov.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"backgroundColor":[NSNull null],@"cornerRadius":[NSNull null],@"zPosition":[NSNull null]};
            [iv.layer addSublayer:ov];
            objc_setAssociatedObject(iv,kADPersonHighlightImageOverlay7221,ov,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(ov.superlayer!=iv.layer) [iv.layer addSublayer:ov];
        ov.frame=iv.bounds;
        ov.cornerRadius=iv.layer.cornerRadius;
        ov.backgroundColor=ADNativeTWBOverlayColor7146().CGColor;
        ov.zPosition=FLT_MAX;
    } @catch(...) {}
}
static BOOL gADPersonOriginalImageWriting7218=NO;
static void ADPersonRestoreOriginalImage7218(UIImageView *iv){
    if(!iv||gADPersonOriginalImageWriting7218)return;
    int kind=ADPersonSectionKind7218(iv);
    if(kind==0)return;
    @try {
        // Person content media must render its authored raster.  Several RN recycled
        // leaves in v7.217 arrived in template mode, producing the blank/white
        // Prescriptions, Reviews, Interests and Subscribe thumbnails.  Restore the
        // original pixels first; TWB then shades only the positive media sections.
        UIImage *im=iv.image;
        if(im&&im.renderingMode!=UIImageRenderingModeAlwaysOriginal){
            UIImage *orig=[im imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            if(orig){ gADPersonOriginalImageWriting7218=YES; iv.image=orig; gADPersonOriginalImageWriting7218=NO; }
        }
    } @catch(...) { gADPersonOriginalImageWriting7218=NO; }
}
static void ADPersonRestoreProbeBackedOriginal7229(UIImageView *iv){
    if(!iv||gADPersonOriginalImageWriting7218||!iv.image)return;
    if(!(ADPersonMedicalAuthoredIcon7231(iv)||ADPersonReviewCompactImage7229(iv)||ADPersonCustomerServiceLeadingImage7229(iv)))return;
    @try {
        UIImage *im=iv.image;
        if(im.renderingMode!=UIImageRenderingModeAlwaysOriginal){
            UIImage *orig=[im imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            if(orig){ gADPersonOriginalImageWriting7218=YES; iv.image=orig; gADPersonOriginalImageWriting7218=NO; }
        }
    } @catch(...) { gADPersonOriginalImageWriting7218=NO; }
}
static BOOL ADPersonExplicitProductMedia7206(UIImageView *iv){
    if(!iv)return NO;
    NSString *aid=(iv.accessibilityIdentifier?:@"").lowercaseString;
    return [aid containsString:@"product-image"]||[aid containsString:@"carousel-item-image"]||
           [aid containsString:@"tile-image-url"]||[aid isEqualToString:@"avr_image"]||
           [aid hasPrefix:@"tile-image-iconsection-"];
}
static BOOL ADPersonMediaBlocked7206(UIImageView *iv){
    if(!iv||!iv.image||!ADInPersonTab7206(iv))return YES;
    @try {
        // Right arrows and authored Medical Care artwork are controls, never Person media.
        // Customer Service is deliberately treated as a tiny image lane below so its stock
        // raster can be restored first and then receive the requested image-only TWB.
        if(ADPersonSectionChevron7217(iv)||ADPersonHighlightIconArrow7240(iv)||ADPersonMedicalAuthoredIcon7231(iv)||
           ADPersonOfflineErrorRaster7299(iv))return YES;
        UIImage *im=iv.image; int kind=ADPersonSectionKind7218(iv);
        BOOL forced=ADPersonForcedMedia7212(iv)||ADPersonForcedMedia7218(iv)||ADPersonReviewCompactImage7229(iv)||
                    ADPersonCustomerServiceLeadingImage7229(iv)||ADPersonSubscribeImage7235(iv)||ADPersonPreviouslyWatchedImage7235(iv);
        if(kind==1)return YES; // Medical Care remains fully authored.
        if(im.renderingMode==UIImageRenderingModeAlwaysTemplate&&!forced)return YES;
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height; BOOL explicitMedia=ADPersonExplicitProductMedia7206(iv)||forced;
        if((w<40.0||h<40.0)&&!explicitMedia)return YES;
        if(im.CGImage&&CGImageGetWidth(im.CGImage)<=80&&CGImageGetHeight(im.CGImage)<=80&&!explicitMedia)return YES;
        BOOL controlMeta=ADStringHasAny7226(iv.accessibilityIdentifier,ADPersonControlTokens7226())||
                         ADStringHasAny7226(iv.accessibilityLabel,ADPersonControlTokens7226());
        BOOL glyphMeta=!forced&&(ADStringHasAny7226(iv.accessibilityIdentifier,ADPersonGlyphTokens7226())||
                                ADStringHasAny7226(iv.accessibilityLabel,ADPersonGlyphTokens7226()));
        for(UIView *n=iv.superview;n&&!controlMeta&&(!glyphMeta||forced);n=n.superview){
            controlMeta=ADStringHasAny7226(NSStringFromClass(n.class),ADPersonControlTokens7226())||
                        ADStringHasAny7226(n.accessibilityIdentifier,ADPersonControlTokens7226());
            if(!forced)glyphMeta=ADStringHasAny7226(NSStringFromClass(n.class),ADPersonGlyphTokens7226())||
                                 ADStringHasAny7226(n.accessibilityIdentifier,ADPersonGlyphTokens7226());
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
        if(controlMeta&&!explicitMedia)return YES;
        // Do not reject highlight image/glyph leaves merely because their aid contains icon/glyph/arrow.
        if(glyphMeta)return YES;
        CGSize screen=UIScreen.mainScreen.bounds.size;
        if(screen.width>0&&screen.height>0&&w>=screen.width*0.72&&h>=screen.height*0.48)return YES;
        if(explicitMedia)return NO;
        if(ADClassNameHasFold7183(iv,"anxfastimageview")||ADClassNameHasFold7183(iv,"rctuiimageviewanimated")||ADClassNameIs7183(iv,"RCTImageView"))return NO;
    } @catch(...) { return YES; }
    return YES;
}

// v7.255: probe-backed hamburger ownership. Amazon's menu is a self-contained
// React surface rooted at #scrolled-hamburger. Keep every correction inside that
// exact subtree and use only lifecycle/final-paint hooks; there is no observer,
// hierarchy sweep, timer, or scroll callback in the production paint path.
static UIView *ADMenuRoot7255(UIView *v){
    if(!v)return nil;
    @try {
        for(UIView *n=v;n;n=n.superview){
            NSString *aid=n.accessibilityIdentifier;
            if(([aid isEqualToString:@"scrolled-hamburger"]&&ADClassNameIs7183(n,"RCTScrollView"))||
               [aid isEqualToString:@"scrolled-hamburger-view"])return n;
            if([n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return nil;
}
static BOOL ADInMenuTab7255(UIView *v){
    if(!v)return NO;
    @try {
        NSNumber *surface=objc_getAssociatedObject(v,kADReactSurfaceCache7232);
        if(surface)return surface.intValue==ADReactSurfaceMenu7255;
        UIView *root=ADMenuRoot7255(v);
        if(root)objc_setAssociatedObject(v,kADReactSurfaceCache7232,@(ADReactSurfaceMenu7255),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return root!=nil;
    } @catch(...) {}
    return NO;
}
static UIView *ADMenuAncestorMatching7255(UIView *v,BOOL (^match)(NSString *),int maxDepth){
    if(!v||!match)return nil;
    @try {
        UIView *n=v;
        for(int d=0;n&&d<maxDepth;d++,n=n.superview){
            if(match(n.accessibilityIdentifier?:@""))return n;
            if([n.accessibilityIdentifier isEqualToString:@"scrolled-hamburger"])break;
        }
    } @catch(...) {}
    return nil;
}
static BOOL ADMenuDirectChildAid7255(UIView *v,NSString *wanted){
    if(!v||!wanted.length)return NO;
    @try { for(UIView *c in v.subviews)if([c.accessibilityIdentifier isEqualToString:wanted])return YES; } @catch(...) {}
    return NO;
}
// v7.280 temporary diagnostics: retain a bounded in-memory lifecycle ring for only
// footer-sized RCTView/RNCEKV neighborhoods. This is probe-only evidence capture: no
// visual writes, timers, observers, polling, disk I/O, or hierarchy scans are performed.
static NSMutableArray<NSString *> *gADMenuLifecycleRing7280=nil;
static NSString *ADMenuTraceColor7280(UIColor *c){
    if(!c)return @"nil";
    @try {CGFloat r=0,g=0,b=0,a=0,w=0;if([c getRed:&r green:&g blue:&b alpha:&a])return [NSString stringWithFormat:@"rgba(%.3f,%.3f,%.3f,%.3f)",r,g,b,a];if([c getWhite:&w alpha:&a])return [NSString stringWithFormat:@"white(%.3f,%.3f)",w,a];} @catch(...) {}
    return @"?";
}
static NSString *ADMenuTraceCG7280(CGColorRef c){if(!c)return @"nil";@try{return ADMenuTraceColor7280([UIColor colorWithCGColor:c]);}@catch(...){return @"?";}}
static NSString *ADMenuTraceChain7280(UIView *v){
    NSMutableArray *a=[NSMutableArray array];
    @try {for(UIView *n=v;n&&a.count<10;n=n.superview){NSString *cn=NSStringFromClass(n.class)?:@"?",*aid=n.accessibilityIdentifier?:@"";[a addObject:aid.length?[NSString stringWithFormat:@"%@#%@",cn,aid]:cn];}} @catch(...) {}
    return [a componentsJoinedByString:@"<-"];
}
static BOOL ADMenuTraceCandidate7280(UIView *v){
    if(!v)return NO;
    @try {
        NSString *cn=NSStringFromClass(v.class)?:@"",*aid=v.accessibilityIdentifier?:@"";
        if([aid isEqualToString:@"account_switcher"]||[aid isEqualToString:@"so"]||[aid isEqualToString:@"cs"])return YES;
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if([cn isEqualToString:@"RCTView"]&&w>=396.0&&w<=414.5&&h>=42.0&&h<=59.5)return YES;
        if([cn isEqualToString:@"RNCEKVExternalKeyboardView"]&&w>=300.0&&w<=420.0&&h>=36.0&&h<=70.0)return YES;
    } @catch(...) {}
    return NO;
}
static void ADMenuLifecycleTrace7280(UIView *v,NSString *event,NSString *extra){
    if(!gP.enabled||!ADMenuTraceCandidate7280(v)||!event.length)return;
    @try {
        static dispatch_once_t once;dispatch_once(&once,^{gADMenuLifecycleRing7280=[NSMutableArray arrayWithCapacity:1600];});
        CGFloat bw=-999,br=-999;SEL qbw=sel_registerName("borderWidth"),qbr=sel_registerName("borderRadius");
        if([v respondsToSelector:qbw])bw=((CGFloat(*)(id,SEL))objc_msgSend)(v,qbw);
        if([v respondsToSelector:qbr])br=((CGFloat(*)(id,SEL))objc_msgSend)(v,qbr);
        CGRect b=v.bounds,f=v.frame;NSString *line=[NSString stringWithFormat:@"T t=%.6f ev=%@ ptr=%p parent=%p window=%p cls=%@ aid=\"%@\" frame=(%.1f,%.1f %.1fx%.1f) bounds=(%.1fx%.1f) bg=%@ layerBg=%@ layerBorder=%.2f/%@ layerRadius=%.2f rctBW=%.2f rctR=%.2f internal=%d chain=\"%@\" %@",CACurrentMediaTime(),event,v,v.superview,v.window,NSStringFromClass(v.class)?:@"?",v.accessibilityIdentifier?:@"",f.origin.x,f.origin.y,f.size.width,f.size.height,b.size.width,b.size.height,ADMenuTraceColor7280(v.backgroundColor),ADMenuTraceCG7280(v.layer.backgroundColor),v.layer.borderWidth,ADMenuTraceCG7280(v.layer.borderColor),v.layer.cornerRadius,bw,br,ADInternalPaintWrite7226()?1:0,ADMenuTraceChain7280(v),extra?:@""];
        @synchronized(gADMenuLifecycleRing7280){if(gADMenuLifecycleRing7280.count>=1800)[gADMenuLifecycleRing7280 removeObjectsInRange:NSMakeRange(0,300)];[gADMenuLifecycleRing7280 addObject:line];}
    } @catch(...) {}
}
static NSString *ADMenuLifecycleSnapshot7280(NSString *phase){
    @try {static dispatch_once_t once;dispatch_once(&once,^{if(!gADMenuLifecycleRing7280)gADMenuLifecycleRing7280=[NSMutableArray arrayWithCapacity:1600];});@synchronized(gADMenuLifecycleRing7280){return [NSString stringWithFormat:@"===== MENU LIFECYCLE RING %@ count=%lu =====\n%@\n===== END MENU LIFECYCLE RING =====\n",phase?:@"?",(unsigned long)gADMenuLifecycleRing7280.count,[gADMenuLifecycleRing7280 componentsJoinedByString:@"\n"]];}} @catch(...) {return @"MENU_LIFECYCLE_RING_ERROR\n";}
}
static void ADMenuLifecycleClear7280(void){@try{@synchronized(gADMenuLifecycleRing7280){[gADMenuLifecycleRing7280 removeAllObjects];}}@catch(...) {}}

static inline BOOL ADMenuFooterActionAid7255(NSString *aid){
    return [aid isEqualToString:@"account_switcher"]||[aid isEqualToString:@"so"]||[aid isEqualToString:@"cs"];
}
// v7.289: duplicate compatibility copies removed; canonical v7.280 Menu helpers above remain authoritative.
static UIView *ADMenuAncestorAid7255(UIView *v,NSString *wanted,BOOL prefix,int maxDepth){
    if(!v)return nil;
    @try {
        UIView *n=v;
        for(int d=0;n&&d<maxDepth;d++,n=n.superview){
            NSString *aid=n.accessibilityIdentifier;
            BOOL match=wanted?(prefix?[aid hasPrefix:wanted]:[aid isEqualToString:wanted]):ADMenuFooterActionAid7255(aid);
            if(match)return n;
            if([aid isEqualToString:@"scrolled-hamburger"])break;
        }
    } @catch(...) {}
    return nil;
}
// v7.262: exact footer actions live under a nested rounded React footer surface.
// Find only those three known action IDs and keep this finite/local to the candidate row.
static UIView *ADMenuFooterActionDescendant7261(UIView *v,int maxDepth){
    if(!v||maxDepth<0)return nil;
    @try {
        NSString *aid=v.accessibilityIdentifier?:@"";
        if(ADMenuFooterActionAid7255(aid))return v;
        if(maxDepth==0)return nil;
        for(UIView *c in v.subviews){
            UIView *hit=ADMenuFooterActionDescendant7261(c,maxDepth-1);
            if(hit)return hit;
        }
    } @catch(...) {}
    return nil;
}
// v7.277: footer ownership is locally authoritative from the three exact action IDs.
// Do not depend on #scrolled-hamburger-view being identified first: React can finish
// this footer subtree before the Menu root receives its identity. The geometry below
// is probe-proven and only accepted when an exact footer action is already inside it.
static int ADMenuLocalFooterRole7277(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return 0;
    @try {
        NSString *aid=v.accessibilityIdentifier?:@"";
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(ADMenuFooterActionAid7255(aid)&&w>=300.0&&w<=420.0&&h>=36.0&&h<=66.0)return 6;
        BOOL inner=w>=402.0&&w<=408.0&&h>=46.0&&h<=51.0;
        BOOL wrapper=w>=408.0&&w<=412.0&&h>=50.0&&h<=55.0;
        if(!(inner||wrapper))return 0;
        CGFloat rr=MAX(v.layer.cornerRadius,ADPersonRCTBorderRadius7212(v));
        if(rr<12.0)return 0;
        return ADMenuFooterActionDescendant7261(v,inner?4:6)?(inner?5:3):0;
    } @catch(...) {}
    return 0;
}
static UIColor *ADMenuButtonFill7255(void){
    return ADSearchChromeFill7045();
}
static UIColor *ADMenuButtonBorder7255(void){
    static UIColor *c=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ c=[UIColor colorWithRed:116.0/255.0 green:122.0/255.0 blue:124.0/255.0 alpha:1.0]; });
    return c;
}
// v7.258: Menu owns one React border channel only.  The v7.256 probe proves
// the three footer action rows had borderWidth=1 *and* every per-edge width=1,
// which lets React render overlapping edge paths.  Keep the generic border as
// the sole owner and reset per-edge overrides to React's unset sentinel (-1).
static void ADMenuSetSingleRCTBorder7258(UIView *v,CGFloat width,UIColor *color){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return;
    @try {
        static SEL generalWidth=NULL,generalColor=NULL;
        static SEL sideWidths[6]={NULL},sideColors[6]={NULL}; static dispatch_once_t once;
        dispatch_once(&once,^{
            generalWidth=sel_registerName("setBorderWidth:");
            generalColor=sel_registerName("setBorderColor:");
            const char *wn[]={"setBorderTopWidth:","setBorderRightWidth:","setBorderBottomWidth:",
                              "setBorderLeftWidth:","setBorderStartWidth:","setBorderEndWidth:"};
            const char *cn[]={"setBorderTopColor:","setBorderRightColor:","setBorderBottomColor:",
                              "setBorderLeftColor:","setBorderStartColor:","setBorderEndColor:"};
            for(size_t i=0;i<6;i++){ sideWidths[i]=sel_registerName(wn[i]); sideColors[i]=sel_registerName(cn[i]); }
        });
        if([v respondsToSelector:generalWidth])((void(*)(id,SEL,CGFloat))objc_msgSend)(v,generalWidth,width);
        if([v respondsToSelector:generalColor])((void(*)(id,SEL,UIColor *))objc_msgSend)(v,generalColor,color);
        for(size_t i=0;i<6;i++){
            if([v respondsToSelector:sideWidths[i]])((void(*)(id,SEL,CGFloat))objc_msgSend)(v,sideWidths[i],-1.0);
            if([v respondsToSelector:sideColors[i]])((void(*)(id,SEL,UIColor *))objc_msgSend)(v,sideColors[i],nil);
        }
        v.layer.borderWidth=0.0;
        [v setNeedsDisplay]; [v.layer setNeedsDisplay];
    } @catch(...) {}
}
// v7.285 Alexa/Rufus: exact controls from the v7.282 comprehensive native probe.
// This is AppCX/navigation-root scoped and does not participate in Person ownership.
static BOOL ADAlexaAncestorAid7285(UIView *v,NSString *wanted,int maxDepth){
    if(!v||!wanted.length)return NO;
    @try {
        for(UIView *n=v;n&&maxDepth-->0;n=n.superview)
            if([n.accessibilityIdentifier isEqualToString:wanted])return YES;
    } @catch(...) {}
    return NO;
}
// v7.296: Alexa Settings is a probe-proven three-row React screen.
// Own only those exact row families; no visible-string matching or global SVG recolor.
static BOOL ADAlexaSettingsRowButton7296(UIView *v){
    if(!v||!v.window||!ADClassNameIs7183(v.window,"AppCXWindow"))return NO;
    @try {
        for(UIView *n=v;n&&n!=v.window;n=n.superview){
            NSString *aid=n.accessibilityIdentifier?:@"";
            if([aid isEqualToString:@"conversation_threads.button"]||
               [aid isEqualToString:@"get_started.button"]||
               [aid isEqualToString:@"manage_price_alerts.button"])return YES;
            if([aid isEqualToString:@"navigation-root"])break;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADAlexaSettingsSeparator7296(UIView *v){
    if(!v||!v.window||!ADClassNameIs7183(v,"RCTView")||!ADClassNameIs7183(v.window,"AppCXWindow"))return NO;
    @try {
        UIView *p=v.superview; NSString *pa=p.accessibilityIdentifier?:@"";
        if(!([pa isEqualToString:@"conversation_threads"]||[pa isEqualToString:@"get_started"]||
             [pa isEqualToString:@"manage_price_alerts"]))return NO;
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        return w>=384.0&&w<=396.0&&h>=6.0&&h<=10.0&&v.subviews.count==0;
    } @catch(...) {}
    return NO;
}
static const void *kADAlexaSettingsSeparatorLine7296=&kADAlexaSettingsSeparatorLine7296;
static void ADAlexaOwnSettingsSeparator7296(UIView *v){
    if(!gP.enabled||!ADAlexaSettingsSeparator7296(v))return;
    @try {
        CALayer *line=(CALayer *)objc_getAssociatedObject(v,kADAlexaSettingsSeparatorLine7296);
        if(!line){
            line=[CALayer layer];
            line.name=@"AmazonDarkAlexaSettingsSeparator7296";
            line.zPosition=CGFLOAT_MAX;
            objc_setAssociatedObject(v,kADAlexaSettingsSeparatorLine7296,line,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if(line.superlayer!=v.layer){ [line removeFromSuperlayer]; [v.layer addSublayer:line]; }
        CGFloat h=v.bounds.size.height,w=v.bounds.size.width;
        line.frame=CGRectMake(0.0,MAX(0.0,h-1.0),w,1.0);
        line.backgroundColor=ADBorderGray706().CGColor;
    } @catch(...) {}
}
// 0 untouched, 1 Plus button, 2 voice button, 3 View-chat-history border owner,
// 4 exact Alexa/Rufus suggestion pill shell. v7.295 supports both probe-proven
// native hydration families: the original ftuxRuxSuggestionPillList shells and
// #pillViewStyle shells under #in-view-wrapper-related_questions_*. No visible-string matching.
static int ADAlexaSuggestionPillFamily7295(UIView *v){
    if(!v||!v.window||!ADClassNameIs7183(v.window,"AppCXWindow"))return 0;
    @try {
        for(UIView *n=v;n&&n!=v.window;n=n.superview){
            NSString *aid=n.accessibilityIdentifier?:@"";
            if([aid hasPrefix:@"in-view-wrapper-ftuxRuxSuggestionPillList-"])return 1;
            if([aid hasPrefix:@"in-view-wrapper-related_questions_"])return 2;
        }
    } @catch(...) {}
    return 0;
}
static BOOL ADAlexaInSuggestionPillWrapper7288(UIView *v){ return ADAlexaSuggestionPillFamily7295(v)!=0; }
static BOOL ADAlexaSuggestionPillShell7288(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return NO;
    int family=ADAlexaSuggestionPillFamily7295(v); if(!family)return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(family==2){
            // v7.294 r1: second Alexa hydration uses exact #pillViewStyle shells
            // under #pill inside #in-view-wrapper-related_questions_*. These are
            // 34.7pt-high rounded pills with one text subtree.
            NSString *aid=v.accessibilityIdentifier?:@"";
            if(![aid isEqualToString:@"pillViewStyle"]||
               ![v.superview.accessibilityIdentifier isEqualToString:@"pill"])return NO;
            return w>=140.0&&w<=320.0&&h>=32.0&&h<=37.0&&v.subviews.count==1;
        }
        // First Alexa hydration retained exactly: anonymous 30pt shell -> RCTView -> RCTTextView.
        if(w<120.0||w>340.0||h<26.0||h>34.0||v.subviews.count!=1)return NO;
        UIView *mid=v.subviews.firstObject;
        if(!ADClassNameIs7183(mid,"RCTView")||mid.subviews.count!=1)return NO;
        return ADClassNameIs7183(mid.subviews.firstObject,"RCTTextView");
    } @catch(...) {}
    return NO;
}
static BOOL ADAlexaSuggestionPillText7288(UIView *v){
    if(!v||!ADAlexaInSuggestionPillWrapper7288(v))return NO;
    @try {
        for(UIView *n=v;n&&n!=v.window;n=n.superview)
            if(ADAlexaSuggestionPillShell7288(n))return YES;
    } @catch(...) {}
    return NO;
}
static void ADAlexaSuggestionPillLightStorage7288(NSTextStorage *ts){
    if(!ts.length)return;
    @try { [ts addAttribute:NSForegroundColorAttributeName value:ADLightText706() range:NSMakeRange(0,ts.length)]; } @catch(...) {}
}
static NSAttributedString *ADAlexaSuggestionPillLightString7288(NSAttributedString *in){
    if(!in.length)return in;
    @try {
        NSMutableAttributedString *m=[in mutableCopy];
        [m addAttribute:NSForegroundColorAttributeName value:ADLightText706() range:NSMakeRange(0,m.length)];
        return m;
    } @catch(...) { return in; }
}
static int ADAlexaReactControlRole7285(UIView *v){
    if(!v||!v.window||!ADClassNameIs7183(v,"RCTView")||!ADClassNameIs7183(v.window,"AppCXWindow"))return 0;
    @try {
        NSString *aid=v.accessibilityIdentifier?:@"";
        if([aid isEqualToString:@"PlusMenuButton"]&&ADAlexaAncestorAid7285(v,@"navigation-root",14))return 1;
        if([aid isEqualToString:@"TextBoxSearchVoiceComponentButton"]&&ADAlexaAncestorAid7285(v,@"navigation-root",14))return 2;
        if([aid isEqualToString:@"pillViewStyle"]&&[v.superview.accessibilityIdentifier isEqualToString:@"overflow-history-ingress-pill"]&&
           ADAlexaAncestorAid7285(v,@"navigation-root",14))return 3;
        if(ADAlexaSuggestionPillShell7288(v))return 4;
        if(ADAlexaSettingsSeparator7296(v))return 5;
    } @catch(...) {}
    return 0;
}
// v7.292: v7.291 probe confirms Plus wrapper geometry and persistent ring; PlusMenuButton's own RNSVGRect is already hidden,
// while its exact anonymous 32x32 parent wrapper still encloses the square-painted child.
// Move physical circle ownership one level up: the wrapper owns gray fill + oval clip + ring,
// and PlusMenuButton itself stays transparent. This isolates React's radius=0 writes inside
// a parent mask that React does not style.
static const void *kADAlexaPlusCircleMask7291=&kADAlexaPlusCircleMask7291;
static const void *kADAlexaPlusCircleFill7292=&kADAlexaPlusCircleFill7292;
static const void *kADAlexaPlusCircleRing7291=&kADAlexaPlusCircleRing7291;
static void ADAlexaOwnPlusCircle7291(UIView *v){
    if(!gP.enabled||!v||!v.window)return;
    @try {
        if(![v.accessibilityIdentifier isEqualToString:@"PlusMenuButton"]||
           !ADAlexaAncestorAid7285(v,@"navigation-root",14))return;
        UIView *wrap=v.superview;
        if(!wrap||!ADClassNameIs7183(wrap,"RCTView")||
           ![wrap.superview.accessibilityIdentifier isEqualToString:@"InputBoxContainer"])return;
        CGRect b=wrap.bounds; CGFloat w=b.size.width,h=b.size.height;
        if(w<28.0||w>36.0||h<28.0||h>36.0||fabs(w-h)>1.0)return;

        ADSetViewBackground7226(v,[UIColor clearColor],YES);
        v.layer.backgroundColor=[UIColor clearColor].CGColor;
        v.layer.borderWidth=0.0;

        // v7.292: React rewrites this anonymous wrapper's normal background back to clear
        // after our owner runs (v7.291 probe: ring survives, physical fill is transparent).
        // Keep the host itself transparent and own the gray disk with a named shape layer
        // that React does not style. The Plus child remains glyph-only.
        UIColor *fill=ADMenuButtonFill7255();
        wrap.layer.backgroundColor=[UIColor clearColor].CGColor;
        wrap.layer.cornerRadius=16.0;
        wrap.layer.masksToBounds=YES;
        wrap.clipsToBounds=YES;

        CAShapeLayer *fillLayer=(CAShapeLayer *)objc_getAssociatedObject(wrap,kADAlexaPlusCircleFill7292);
        if(!fillLayer){
            fillLayer=[CAShapeLayer layer];
            fillLayer.name=@"AmazonDarkAlexaPlusCircleFill7292";
            fillLayer.strokeColor=[UIColor clearColor].CGColor;
            fillLayer.lineWidth=0.0;
            objc_setAssociatedObject(wrap,kADAlexaPlusCircleFill7292,fillLayer,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if(fillLayer.superlayer!=wrap.layer){
            [fillLayer removeFromSuperlayer];
            [wrap.layer insertSublayer:fillLayer atIndex:0];
        }
        fillLayer.frame=b;
        fillLayer.fillColor=fill.CGColor;
        fillLayer.path=[UIBezierPath bezierPathWithOvalInRect:b].CGPath;

        CAShapeLayer *mask=(CAShapeLayer *)objc_getAssociatedObject(wrap,kADAlexaPlusCircleMask7291);
        if(!mask){
            mask=[CAShapeLayer layer];
            mask.name=@"AmazonDarkAlexaPlusCircleMask7291";
            objc_setAssociatedObject(wrap,kADAlexaPlusCircleMask7291,mask,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        mask.frame=b;
        mask.path=[UIBezierPath bezierPathWithOvalInRect:b].CGPath;
        if(wrap.layer.mask!=mask)wrap.layer.mask=mask;

        CAShapeLayer *ring=(CAShapeLayer *)objc_getAssociatedObject(wrap,kADAlexaPlusCircleRing7291);
        if(!ring){
            ring=[CAShapeLayer layer];
            ring.name=@"AmazonDarkAlexaPlusCircleRing7291";
            ring.fillColor=[UIColor clearColor].CGColor;
            ring.lineWidth=1.0;
            ring.zPosition=CGFLOAT_MAX;
            objc_setAssociatedObject(wrap,kADAlexaPlusCircleRing7291,ring,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if(ring.superlayer!=wrap.layer){
            [ring removeFromSuperlayer];
            [wrap.layer addSublayer:ring];
        }
        ring.frame=b;
        ring.strokeColor=ADBorderGray706().CGColor;
        ring.path=[UIBezierPath bezierPathWithOvalInRect:CGRectInset(b,0.5,0.5)].CGPath;
    } @catch(...) {}
}
// v7.326: preserve Amazon's measured 32x32 voice-button frame and the stock SVG's
// full paint geometry. The v7.307 ownership correction put our fill/ring on the
// right button, but also masked and clipped that RNSVG owner. The decorative layers
// stay centered on the exact stock button; no frame, bounds, center, transform,
// corner-radius, clipping, or layer-mask property is written on the glyph owner.
static const void *kADAlexaVoiceCircleFill7295=&kADAlexaVoiceCircleFill7295;
static const void *kADAlexaVoiceCircleRing7295=&kADAlexaVoiceCircleRing7295;
static void ADAlexaOwnVoiceCircle7295(UIView *v){
    if(!gP.enabled||!v||!v.window)return;
    @try {
        if(![v.accessibilityIdentifier isEqualToString:@"TextBoxSearchVoiceComponentButton"]||
           !ADAlexaAncestorAid7285(v,@"navigation-root",14))return;

        // v7.307 correctly found the actual button/SVG at 32x32, x=384. Keep that
        // ancestry and center only our paint layers on it; Amazon remains sole owner
        // of the view and SVG geometry.
        UIView *component=v.superview;
        UIView *inner=component.superview;
        UIView *wrap=inner.superview;
        if(!component||![component.accessibilityIdentifier isEqualToString:@"TextBoxSearchVoiceComponent"]||
           !inner||!ADClassNameIs7183(inner,"RCTView")||
           !wrap||!ADClassNameIs7183(wrap,"RCTView")||
           ![wrap.superview.accessibilityIdentifier isEqualToString:@"InputBoxContainer"])return;
        CGRect b=v.bounds; CGFloat w=b.size.width,h=b.size.height;
        if(w<28.0||w>36.0||h<28.0||h>36.0||fabs(w-h)>1.0)return;

        ADSetViewBackground7226(v,[UIColor clearColor],YES);
        v.layer.backgroundColor=[UIColor clearColor].CGColor;
        v.layer.borderWidth=0.0;

        UIColor *fill=ADMenuButtonFill7255();
        CAShapeLayer *fillLayer=(CAShapeLayer *)objc_getAssociatedObject(v,kADAlexaVoiceCircleFill7295);
        if(!fillLayer){
            fillLayer=[CAShapeLayer layer];
            fillLayer.name=@"AmazonDarkAlexaVoiceCircleFill7295";
            fillLayer.strokeColor=[UIColor clearColor].CGColor;
            fillLayer.lineWidth=0.0;
            objc_setAssociatedObject(v,kADAlexaVoiceCircleFill7295,fillLayer,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if(fillLayer.superlayer!=v.layer){
            [fillLayer removeFromSuperlayer];
            [v.layer insertSublayer:fillLayer atIndex:0];
        }
        fillLayer.frame=b;
        fillLayer.fillColor=fill.CGColor;
        fillLayer.path=[UIBezierPath bezierPathWithOvalInRect:b].CGPath;

        CAShapeLayer *ring=(CAShapeLayer *)objc_getAssociatedObject(v,kADAlexaVoiceCircleRing7295);
        if(!ring){
            ring=[CAShapeLayer layer];
            ring.name=@"AmazonDarkAlexaVoiceCircleRing7295";
            ring.fillColor=[UIColor clearColor].CGColor;
            ring.lineWidth=1.0;
            ring.zPosition=CGFLOAT_MAX;
            objc_setAssociatedObject(v,kADAlexaVoiceCircleRing7295,ring,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if(ring.superlayer!=v.layer){
            [ring removeFromSuperlayer];
            [v.layer addSublayer:ring];
        }
        ring.frame=b;
        ring.strokeColor=ADBorderGray706().CGColor;
        ring.path=[UIBezierPath bezierPathWithOvalInRect:CGRectInset(b,0.5,0.5)].CGPath;
    } @catch(...) {}
}

static void ADAlexaOwnReactControl7285(UIView *v){
    if(!gP.enabled||!v||!v.window)return;
    @try {
        int role=ADAlexaReactControlRole7285(v); if(!role)return;
        if(role==1){
            ADAlexaOwnPlusCircle7291(v);
        } else if(role==2){
            ADAlexaOwnVoiceCircle7295(v);
        } else if(role==4){
            // Match Cart action-button paint: #303335 fill, #747a7c edge, light text.
            // Preserve each probe-proven pill's own height/radius across both hydrations.
            ADSetViewBackground7226(v,ADMenuButtonFill7255(),YES);
            v.layer.cornerRadius=MIN(20.0,MAX(15.0,v.bounds.size.height*0.5));
            v.layer.borderWidth=1.0;
            v.layer.borderColor=ADMenuButtonBorder7255().CGColor;
            v.layer.masksToBounds=YES;
            v.clipsToBounds=YES;
        } else if(role==5){
            ADAlexaOwnSettingsSeparator7296(v);
        } else {
            ADMenuSetSingleRCTBorder7258(v,1.0,ADBorderGray706());
        }
    } @catch(...) {}
}

// 0 untouched, 1 OLED row/card with one gray border, 2 custom gray shortcut with
// one gray border, 3 retired React border shell, 4 OLED structural floor,
// 5 footer visible inner surface: OLED with no visible edge,
// 6 footer action leaf: transparent so it cannot repaint over the rounded surface.
static int ADMenuViewRole7255(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return 0;
    @try {
        int footerRole=ADMenuLocalFooterRole7277(v);
        if(footerRole)return footerRole;
        if(!v.window||!ADInMenuTab7255(v))return 0;
        NSString *aid=v.accessibilityIdentifier?:@"";
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        UIView *shortcut=ADMenuAncestorAid7255(v,@"image_menu_item_pill_",YES,6);
        if(shortcut&&w>=36.0&&w<=240.0&&h>=30.0&&h<=54.0&&ADPersonRCTBorderRadius7212(v)>=12.0)return 2;
        if([aid isEqualToString:@"theme_card_content_view_test_id"])return 1;
        // v7.260: the full Menu probe proves every expanded category uses
        // #subtheme-card-view and the same repeated 376x50/r16 row geometry.
        // Do NOT use Amazon's current borderWidth as the ownership signal: the
        // Travel row (`sbdlt`) is structurally identical but arrives with the
        // primary row's borderWidth at 0, while neighboring rows arrive at 1.
        // The stable discriminator is hierarchy shape: the real physical row is
        // the rounded 376x50 view with two content children; the same-geometry
        // rounded zero-child view is only a border/highlight shell.  Therefore
        // every subtheme row gets exactly one AmazonDark gray edge, including
        // Travel, and every competing rounded shell is retired.
        UIView *subthemeView=ADMenuAncestorAid7255(v,@"subtheme-card-view",NO,8);
        if(subthemeView){
            if(v==subthemeView)return 4;
            CGFloat rr=MAX(v.layer.cornerRadius,ADPersonRCTBorderRadius7212(v));
            if(w>=350.0&&w<=394.0&&h>=43.0&&h<=55.0&&rr>=8.0){
                if(v.subviews.count>=2)return 1;
                return 3;
            }
        }
        if(ADMenuDirectChildAid7255(v,@"subtheme-card"))return 1;
        if([aid isEqualToString:@"subtheme-card"]||[aid isEqualToString:@"subtheme-card-view"])return 4;
        UIView *themePress=ADMenuAncestorAid7255(v,@"theme-card-press",NO,5);
        if(themePress&&w>=390.0&&w<=420.0&&h>=48.0&&h<=66.0)return 3;
        UIView *themeContent=ADMenuAncestorAid7255(v,@"theme_card_content_view_test_id",NO,4);
        if(themeContent&&w>=44.0&&w<=62.0&&h>=44.0&&h<=66.0)return 4; // icon backdrop
        if([aid isEqualToString:@"scrolled-hamburger-view"]||[aid isEqualToString:@"theme-card"]||
           [aid isEqualToString:@"featured-programs-container"]||[aid isEqualToString:@"featured-programs-carousel"]||
           [aid isEqualToString:@"image-grid"]||[aid isEqualToString:@"image-grid-inner"])return 4;
    } @catch(...) {}
    return 0;
}
static void ADMenuApplyRole7281(UIView *v,int role){
    if(!gP.enabled||!v||!role)return;
    @try {
        UIColor *fill=(role==2)?ADMenuButtonFill7255():((role==3||role==6)?[UIColor clearColor]:ADOLED());
        ADSetViewBackground7226(v,fill,YES);
        if(role==1||role==2){
            UIColor *edge=(role==2)?ADMenuButtonBorder7255():ADBorderGray706();
            ADMenuSetSingleRCTBorder7258(v,1.0,edge);
        } else if(role==5){
            // v7.309: only the three exact footer action surfaces lose their
            // border. Keep the existing OLED floor/radius and Menu text owner.
            ADMenuSetSingleRCTBorder7258(v,0.0,[UIColor clearColor]);
        } else {
            ADMenuSetSingleRCTBorder7258(v,0.0,ADBorderGray706());
        }
        if(role==5){
            // The real visible 406x48.7 surface keeps its final r16 geometry and
            // clipping while its fill is OLED and every border channel is clear.
            v.layer.cornerRadius=16.0;
            v.layer.masksToBounds=YES;
        }
    } @catch(...) {}
}
static void ADMenuOwnView7255(UIView *v){
    if(gP.enabled&&v)ADMenuApplyRole7281(v,ADMenuViewRole7255(v));
}

// v7.311: the v7.309 Menu probe proves the missing "Explore more for you"
// carousel is mounted and correctly laid out.  The affected vector tiles have
// one exact physical shape only:
//
//   RCTView (58x58, alpha 0.06-0.08)
//     <- RCTView#featured-programs-tile-image-container_N
//
// and the wrapper owns one direct RNSVGSvgView.  Raster tiles in the same rail
// remain alpha 1 and use the existing Menu image/TWB path.  Restore opacity only
// for this exact vector wrapper; do not touch SVG paint, raster rendering mode,
// TWB eligibility, category glyphs, or any other Menu view.
static BOOL gADMenuFeaturedVectorOpacityWrite7310=NO;
static BOOL ADMenuFeaturedVectorWrapper7310(UIView *v){
    if(!v||!v.window||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<56.0||w>60.0||h<56.0||h>60.0)return NO;
        UIView *host=v.superview; NSString *aid=host.accessibilityIdentifier?:@"";
        if(!ADClassNameIs7183(host,"RCTView")||
           ![aid hasPrefix:@"featured-programs-tile-image-container_"])return NO;
        if(!ADMenuRoot7255(v))return NO;
        NSUInteger vectors=0,rasters=0;
        for(UIView *c in v.subviews){
            if(ADClassNameIs7183(c,"RNSVGSvgView"))vectors++;
            if([c isKindOfClass:[UIImageView class]]||ADClassNameIs7183(c,"RCTImageView"))rasters++;
        }
        return vectors==1&&rasters==0;
    } @catch(...) { return NO; }
}
static void ADMenuOwnFeaturedVectorOpacity7310(UIView *v){
    if(!gP.enabled||gADMenuFeaturedVectorOpacityWrite7310||
       !ADMenuFeaturedVectorWrapper7310(v))return;
    @try {
        if(v.alpha<0.999||v.layer.opacity<0.999){
            gADMenuFeaturedVectorOpacityWrite7310=YES;
            v.alpha=1.0;
            v.layer.opacity=1.0;
            gADMenuFeaturedVectorOpacityWrite7310=NO;
        }
    } @catch(...) { gADMenuFeaturedVectorOpacityWrite7310=NO; }
}
// v7.282: the paired cold/warm probes show the final React radius transaction is
// the first moment all three footer rows have both their exact descendant IDs and
// final 406/410 geometry. Own only those final surfaces in that same transaction.
static void ADMenuOwnFinalFooterRadius7281(UIView *v,CGFloat radius){
    if(!gP.enabled||radius<12.0)return;
    int role=ADMenuLocalFooterRole7277(v);
    if(role==3||role==5)ADMenuApplyRole7281(v,role);
}
static BOOL ADMenuDarkNeutral7255(UIColor *color){
    return ADDarkNeutral7259(color,YES);
}
static NSAttributedString *ADMenuLightString7255(NSAttributedString *in){
    return gP.enabled?ADLightNeutralString7271(in,ADMenuDarkNeutral7255):in;
}
static void ADMenuLightStorage7255(NSTextStorage *ts){
    if(gP.enabled)ADLightNeutralStorage7271(ts,ADMenuDarkNeutral7255);
}
static void ADMenuOwnText7255(UIView *v){
    if(!gP.enabled||!v||!v.window||!ADInMenuTab7255(v))return;
    NSTextStorage *ts=ADPersonTextStorage7206(v); if(ts)ADMenuLightStorage7255(ts);
}


static int ADReactSurface7226(UIView *v){
    if(!v)return ADReactSurfaceNone7226;
    @try {
        NSNumber *cached=objc_getAssociatedObject(v,kADReactSurfaceCache7232);
        if(cached)return cached.intValue;
        for(UIView *n=v; n; n=n.superview){
            NSString *aid=n.accessibilityIdentifier;
            if(([aid isEqualToString:@"scrolled-hamburger"]&&ADClassNameIs7183(n,"RCTScrollView"))||
               [aid isEqualToString:@"scrolled-hamburger-view"]){
                objc_setAssociatedObject(v,kADReactSurfaceCache7232,@(ADReactSurfaceMenu7255),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                return ADReactSurfaceMenu7255;
            }
            if([n.accessibilityIdentifier isEqualToString:@"me"]&&ADClassNameIs7183(n,"RCTScrollView")){
                objc_setAssociatedObject(v,kADReactSurfaceCache7232,@(ADReactSurfacePerson7226),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                return ADReactSurfacePerson7226;
            }
            if(ADClassNameIs7183(n,"SNPRootView")){
                if(objc_getAssociatedObject(n,kADLocationRootFirstPaint7202)){
                    objc_setAssociatedObject(v,kADReactSurfaceCache7232,@(ADReactSurfaceLocation7226),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    return ADReactSurfaceLocation7226;
                }
                break;
            }
            if([n isKindOfClass:[UIWindow class]])break;
        }
    } @catch(...) {}
    return ADReactSurfaceNone7226;
}
static void ADOwnReactView7226(UIView *v){
    if(!gP.enabled||!v||!v.window)return;
    @try {
        ADAlexaOwnReactControl7285(v);
        int surface=ADReactSurface7226(v);
        if(surface==ADReactSurfacePerson7226){
            ADPersonOwnView7206(v);
            return;
        }
        if(surface==ADReactSurfaceLocation7226){
            ADOwnLocationSheetFloor7196(v);
            if(ADLocationMarkedWideBrightFloor7205(v,v.backgroundColor))ADSetLocationBlack7202(v);
            return;
        }
        if(surface==ADReactSurfaceMenu7255){
            ADMenuOwnView7255(v);
            ADMenuOwnFeaturedVectorOpacity7310(v);
            return;
        }
        if(ADClassNameIs7183(v.window,"AppCXWindow")){
            ADOwnAppCXSheetFloor7255(v);
            ADOwnPersonSavingsFloor7259(v);
        }
    } @catch(...) {}
}

%hook RCTView
- (void)didMoveToWindow {
    %orig;
    UIView *v=(UIView *)self;
    objc_setAssociatedObject(v,kADReactSurfaceCache7232,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ADOwnReactView7226(v);
}
- (void)didMoveToSuperview {
    %orig;
    UIView *v=(UIView *)self;
    objc_setAssociatedObject(v,kADReactSurfaceCache7232,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(v.window)ADOwnReactView7226(v);
}
- (void)layoutSubviews {
    %orig;
    ADOwnReactView7226((UIView *)self);
}
- (void)setAlpha:(CGFloat)value {
    UIView *v=(UIView *)self;
    if(gADMenuFeaturedVectorOpacityWrite7310){
        %orig(value);
        return;
    }
    if(gP.enabled&&ADMenuFeaturedVectorWrapper7310(v)){
        %orig(1.0);
        return;
    }
    %orig(value);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    UIView *v=(UIView *)self;
    int alexaRole=gP.enabled?ADAlexaReactControlRole7285(v):0;
    if(alexaRole==1||alexaRole==2||alexaRole==4){
        UIColor *paint=(alexaRole==1)?[UIColor clearColor]:ADMenuButtonFill7255();
        gADPaintWriteDepth7226++;
        @try {
            %orig(paint);
            self.layer.backgroundColor=paint.CGColor;
        }
        @finally { if(gADPaintWriteDepth7226)gADPaintWriteDepth7226--; }
        ADAlexaOwnReactControl7285(v);
        return;
    }
    int surface=(gP.enabled&&v.window)?ADReactSurface7226(v):ADReactSurfaceNone7226;
    BOOL reviewPlate=surface==ADReactSurfacePerson7226&&ADPersonReviewBorderPlate7231(v);
    BOOL interestPlate=surface==ADReactSurfacePerson7226&&ADPersonInterestBorderPlate7235(v);
    BOOL buyOccluder=surface==ADReactSurfacePerson7226&&ADPersonBuyAgainOccluder7235(v);
    BOOL subscribeOccluder=surface==ADReactSurfacePerson7226&&ADPersonSubscribeOccluder7237(v);
    if(interestPlate||buyOccluder||subscribeOccluder){
        UIColor *clear=[UIColor clearColor];
        gADPaintWriteDepth7226++;
        @try {
            %orig(clear);
            self.layer.backgroundColor=clear.CGColor;
        }
        @finally { if(gADPaintWriteDepth7226)gADPaintWriteDepth7226--; }
        if(interestPlate)ADPersonOwnInterestBorderPlate7235(v);
        return;
    }
    if(reviewPlate){
        UIColor *reviewClear=[UIColor clearColor];
        gADPaintWriteDepth7226++;
        @try {
            %orig(reviewClear);
        }
        @finally { if(gADPaintWriteDepth7226)gADPaintWriteDepth7226--; }
        ADPersonOwnReviewBorderPlate7231(v);
        return;
    }
    BOOL personShell=surface==ADReactSurfacePerson7226&&ADPersonBorderOnlyShell7227(v);
    BOOL person=!personShell&&surface==ADReactSurfacePerson7226&&(ADPersonFloorCandidate7206(v,color)||ADPersonOLEDPlane7218(v,color));
    BOOL location=surface==ADReactSurfaceLocation7226&&(ADLocationSheetFloor7196(v,color)||ADLocationMarkedWideBrightFloor7205(v,color));
    BOOL appWindow=ADClassNameIs7183(v.window,"AppCXWindow");
    BOOL appcx=appWindow&&ADInAppCXBottomSheet7255(v)&&ADNeutralNearWhite7255(color);
    BOOL savings=appWindow&&ADInPersonSavingsSheet7259(v)&&ADNeutralNearWhite7255(color);
    int menuRole=gP.enabled?ADMenuLocalFooterRole7277(v):0;
    if(!menuRole&&surface==ADReactSurfaceMenu7255)menuRole=ADMenuViewRole7255(v);
    UIColor *menuColor=(menuRole==2)?ADMenuButtonFill7255():((menuRole==3||menuRole==6)?[UIColor clearColor]:ADOLED());
    UIColor *finalColor=menuRole?menuColor:(personShell?[UIColor clearColor]:((person||location||appcx||savings)?ADOLED():color));

    // One original React setter call, guarded across its super-call chain.  This is
    // the critical v7.226 recursion barrier: UIView and RCTView can no longer repaint
    // each other while committing the same background.
    BOOL transactionOpen=NO;
    gADPaintWriteDepth7226++;
    @try {
        if(location){
            [CATransaction begin]; transactionOpen=YES;
            [CATransaction setDisableActions:YES];
            [self.layer removeAnimationForKey:@"backgroundColor"];
            %orig(finalColor);
            self.layer.backgroundColor=finalColor.CGColor;
        } else {
            %orig(finalColor);
            if(person||menuRole||appcx||savings)self.layer.backgroundColor=finalColor.CGColor;
        }
    } @finally {
        if(transactionOpen)[CATransaction commit];
        if(gADPaintWriteDepth7226)gADPaintWriteDepth7226--;
    }

    if(person)ADPersonReassertBorder7206(v,YES);
    if(menuRole)ADMenuOwnView7255(v);
}
- (void)setBorderRadius:(CGFloat)value {
    int alexaRole=gP.enabled?ADAlexaReactControlRole7285((UIView *)self):0;
    if(alexaRole==1){
        %orig(value);
        ADAlexaOwnReactControl7285((UIView *)self);
        return;
    }
    if(alexaRole==2){
        // v7.326: Amazon owns the voice button's radius and SVG geometry. Our
        // separate fill/ring layers provide the dark paint without rewriting it.
        %orig(value);
        ADAlexaOwnReactControl7285((UIView *)self);
        return;
    }
    if(alexaRole==4){
        %orig(15.0);
        ADAlexaOwnReactControl7285((UIView *)self);
        return;
    }
    %orig(value);
    ADMenuOwnFinalFooterRadius7281((UIView *)self,value);
    if(alexaRole)ADAlexaOwnReactControl7285((UIView *)self);
}
- (void)setBorderWidth:(CGFloat)value {
    int alexaRole=gP.enabled?ADAlexaReactControlRole7285((UIView *)self):0;
    if(alexaRole==1||alexaRole==2||alexaRole==4){
        // Keep React's own border channel off; one CALayer ring is the sole owner.
        %orig(0.0);
        ADAlexaOwnReactControl7285((UIView *)self);
        return;
    }
    %orig(value);
}
- (void)setBorderColor:(UIColor *)value {
    int alexaRole=gP.enabled?ADAlexaReactControlRole7285((UIView *)self):0;
    if(alexaRole==3){
        UIColor *gray=ADBorderGray706();
        %orig(gray);
        return;
    }
    %orig(value);
    if(alexaRole==1||alexaRole==2||alexaRole==4)ADAlexaOwnReactControl7285((UIView *)self);
}
%end

// v7.285 Alexa/Rufus vector controls. Exact IDs come from the v7.282 Alexa probe.
// Root-only CAFilter inversion preserves authored geometry; the bottom full-size
// backing shape is hidden so the gray parent circle remains visible behind a white glyph.
static const void *kADAlexaVectorOwned7285=&kADAlexaVectorOwned7285;
static int ADAlexaVectorRole7285(UIView *svg){
    if(!svg||!svg.window||!ADClassNameIs7183(svg,"RNSVGSvgView")||!ADClassNameIs7183(svg.window,"AppCXWindow"))return 0;
    @try {
        NSString *aid=svg.accessibilityIdentifier?:@"",*parentAid=svg.superview.accessibilityIdentifier?:@"";
        // Settings and Chat-history can hydrate one wrapper differently. The stable owner is
        // the Alexa left navigation-button family, not the intermediate close wrapper.
        if(([aid isEqualToString:@"chevron-down-icon"]||[aid isEqualToString:@"chevron-left-Variant-icon"])&&ADAlexaAncestorAid7285(svg,@"MainNavigationHeader-left-button",5))return 1;
        if([aid isEqualToString:@"vertical-ellipsis-icon"]&&[parentAid isEqualToString:@"MainNavigationHeader-right-button-overflow"])return 2;
        if([aid isEqualToString:@"chat-history-threads-icon"]&&[parentAid isEqualToString:@"MainNavigationHeader-right-action-button-chatHistory"])return 3;
        if([parentAid isEqualToString:@"PlusMenuButton"])return 4;
        if([parentAid isEqualToString:@"TextBoxSearchVoiceComponentButton"])return 5;
        // v7.295 Settings probe: each of the three rows has exactly two SVG controls
        // (left semantic glyph + right chevron). Invert every SVG inside those exact
        // row-button families so all six render light, including the unnamed price-alert icon.
        if(ADAlexaSettingsRowButton7296(svg))return 6;
    } @catch(...) {}
    return 0;
}
static void ADAlexaInvertVectorRoot7285(UIView *svg){
    if(!svg)return;
    @try {
        Class F=NSClassFromString(@"CAFilter"); if(!F)return;
        SEL ft=sel_registerName("filterWithType:"); if(![F respondsToSelector:ft])return;
        id inv=((id(*)(id,SEL,id))objc_msgSend)(F,ft,@"colorInvert"); if(!inv)return;
        id hue=((id(*)(id,SEL,id))objc_msgSend)(F,ft,@"hueRotate");
        @try { if(hue)[hue setValue:@(3.141592653589793) forKey:@"inputAngle"]; } @catch(...) { hue=nil; }
        svg.layer.filters=hue?@[inv,hue]:@[inv];
    } @catch(...) {}
}
static void ADAlexaOwnVector7285(UIView *svg){
    if(!svg||!svg.window)return;
    @try {
        int role=ADAlexaVectorRole7285(svg); if(!role)return;
        if(!gP.enabled){
            if(objc_getAssociatedObject(svg,kADAlexaVectorOwned7285))svg.layer.filters=nil;
            if(role==4||role==5){
                NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:svg]; NSUInteger seen=0;
                while(seen<q.count&&seen<16){
                    UIView *x=q[seen++]; const char *cn=object_getClassName(x);
                    BOOL backing=cn&&((role==4&&strcmp(cn,"RNSVGRect")==0)||(role==5&&strcmp(cn,"RNSVGCircle")==0));
                    if(backing&&x.bounds.size.width>=28.0&&x.bounds.size.height>=28.0)x.hidden=NO;
                    if(x.subviews.count&&q.count-seen<16)[q addObjectsFromArray:x.subviews];
                }
            }
            objc_setAssociatedObject(svg,kADAlexaVectorOwned7285,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        if(role==4||role==5){
            NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:svg]; NSUInteger seen=0;
            while(seen<q.count&&seen<16){
                UIView *x=q[seen++]; const char *cn=object_getClassName(x);
                BOOL backing=cn&&((role==4&&strcmp(cn,"RNSVGRect")==0)||(role==5&&strcmp(cn,"RNSVGCircle")==0));
                if(backing&&x.bounds.size.width>=28.0&&x.bounds.size.height>=28.0)x.hidden=YES;
                if(x.subviews.count&&q.count-seen<16)[q addObjectsFromArray:x.subviews];
            }
        }
        ADAlexaInvertVectorRoot7285(svg);
        objc_setAssociatedObject(svg,kADAlexaVectorOwned7285,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}
%hook RNSVGSvgView
- (void)didMoveToWindow {
    %orig;
    ADAlexaOwnVector7285((UIView *)self);
    ADMenuOwnFeaturedVectorOpacity7310(((UIView *)self).superview);
}
- (void)didMoveToSuperview {
    %orig;
    if(((UIView *)self).window){
        ADAlexaOwnVector7285((UIView *)self);
        ADMenuOwnFeaturedVectorOpacity7310(((UIView *)self).superview);
    }
}
- (void)layoutSubviews {
    %orig;
    ADAlexaOwnVector7285((UIView *)self);
    ADMenuOwnFeaturedVectorOpacity7310(((UIView *)self).superview);
}
%end

%hook RNCEKVExternalKeyboardView
- (void)didMoveToWindow {
    %orig;
    UIView *v=(UIView *)self;
    ADPrimeLocationWrapper7202(v);
}
- (void)setFrame:(CGRect)frame {
    %orig(frame);
    UIView *v=(UIView *)self;
    ADPrimeLocationWrapper7202(v);
}
%end

static NSAttributedString *ADThemeReactAttributedText7271(UIView *v,NSAttributedString *text){
    if(!gP.enabled||!v.window)return ADLightAttributedText708(text);
    if(ADAlexaSuggestionPillText7288(v))return ADAlexaSuggestionPillLightString7288(text);
    int surface=ADReactSurface7226(v);
    if(surface==ADReactSurfacePerson7226){
        if(ADPersonOfflineFallbackButtonText7299(v))return ADPersonOfflineFallbackButtonString7299(text);
        return ADPersonHeaderLeaf7221(v)?ADPersonHeaderString7221(text):ADPersonLightString7206(text);
    }
    if(surface==ADReactSurfaceMenu7255)return ADMenuLightString7255(text);
    if(ADInLocationSheetContent7196(v))return ADLocationSheetLightString7196(v,text);
    if(ADClassNameIs7183(v.window,"AppCXWindow")){
        if(ADInAppCXBottomSheet7255(v))return ADAppCXSheetLightString7255(text);
        if(ADInPersonSavingsSheet7259(v))return ADPersonSavingsLightString7259(text);
    }
    return ADLightAttributedText708(text);
}
static BOOL ADThemeReactTextStorage7271(UIView *v,NSTextStorage *textStorage,BOOL includeBuyAgain){
    if(!gP.enabled||!v.window)return NO;
    if(ADAlexaSuggestionPillText7288(v)){ ADAlexaSuggestionPillLightStorage7288(textStorage); return YES; }
    int surface=ADReactSurface7226(v);
    if(surface==ADReactSurfacePerson7226||(includeBuyAgain&&ADPersonBuyAgain7208(v))){
        if(ADPersonOfflineFallbackButtonText7299(v))ADPersonOfflineFallbackButtonStorage7299(textStorage);
        else if(ADPersonTopMenuPillText7250(v))ADPersonTopMenuPillWhiteStorage7250(textStorage);
        else if(ADPersonHeaderLeaf7221(v))ADPersonHeaderStorage7221(textStorage);
        else ADPersonLightStorage7206(textStorage);
        return YES;
    }
    if(surface==ADReactSurfaceMenu7255){ ADMenuLightStorage7255(textStorage); return YES; }
    if(ADInLocationSheetContent7196(v)){ ADLocationSheetLightStorage7196(v,textStorage); return YES; }
    if(ADClassNameIs7183(v.window,"AppCXWindow")){
        if(ADInAppCXBottomSheet7255(v)){ ADAppCXSheetLightStorage7255(textStorage); return YES; }
        if(ADInPersonSavingsSheet7259(v)){ ADPersonSavingsLightStorage7259(textStorage); return YES; }
    }
    return NO;
}
static void ADOwnReactText7271(UIView *v,BOOL includeBuyAgain){
    if(!gP.enabled||!v.window)return;
    if(ADAlexaSuggestionPillText7288(v)){ NSTextStorage *ts=ADPersonTextStorage7206(v); if(ts)ADAlexaSuggestionPillLightStorage7288(ts); return; }
    int surface=ADReactSurface7226(v);
    if(surface==ADReactSurfacePerson7226||(includeBuyAgain&&ADPersonBuyAgain7208(v))){ ADPersonOwnText7206(v); return; }
    if(surface==ADReactSurfaceMenu7255){ ADMenuOwnText7255(v); return; }
    if(ADInLocationSheetContent7196(v)){ ADLocationSheetOwnText7196(v); return; }
    if(ADClassNameIs7183(v.window,"AppCXWindow")){
        NSTextStorage *ts=ADPersonTextStorage7206(v); if(!ts)return;
        if(ADInAppCXBottomSheet7255(v))ADAppCXSheetLightStorage7255(ts);
        else if(ADInPersonSavingsSheet7259(v))ADPersonSavingsLightStorage7259(ts);
    }
}

%hook RCTParagraphComponentView
- (void)setAttributedText:(NSAttributedString *)attributedText {
    NSAttributedString *r=nil;
    if(gP.enabled&&((UIView *)self).window&&ADInPersonTab7206((UIView *)self)) r=ADPersonHeaderLeaf7221((UIView *)self)?ADPersonHeaderString7221(attributedText):ADPersonLightString7206(attributedText);
    else if(gP.enabled&&((UIView *)self).window&&ADInMenuTab7255((UIView *)self)) r=ADMenuLightString7255(attributedText);
    else if(gP.enabled&&((UIView *)self).window&&ADInLocationSheetContent7196((UIView *)self)) r=ADLocationSheetLightString7196((UIView *)self,attributedText);
    else if(gP.enabled&&((UIView *)self).window&&ADInAppCXBottomSheet7255((UIView *)self)) r=ADAppCXSheetLightString7255(attributedText);
    else if(gP.enabled&&((UIView *)self).window&&ADInPersonSavingsSheet7259((UIView *)self)) r=ADPersonSavingsLightString7259(attributedText);
    else r=ADLightAttributedText708(attributedText);
    %orig(r);
}
- (void)_setAttributedString:(NSAttributedString *)attributedString {
    NSAttributedString *r=nil;
    if(gP.enabled&&((UIView *)self).window&&ADInPersonTab7206((UIView *)self)) r=ADPersonHeaderLeaf7221((UIView *)self)?ADPersonHeaderString7221(attributedString):ADPersonLightString7206(attributedString);
    else if(gP.enabled&&((UIView *)self).window&&ADInMenuTab7255((UIView *)self)) r=ADMenuLightString7255(attributedString);
    else if(gP.enabled&&((UIView *)self).window&&ADInLocationSheetContent7196((UIView *)self)) r=ADLocationSheetLightString7196((UIView *)self,attributedString);
    else if(gP.enabled&&((UIView *)self).window&&ADInAppCXBottomSheet7255((UIView *)self)) r=ADAppCXSheetLightString7255(attributedString);
    else if(gP.enabled&&((UIView *)self).window&&ADInPersonSavingsSheet7259((UIView *)self)) r=ADPersonSavingsLightString7259(attributedString);
    else r=ADLightAttributedText708(attributedString);
    %orig(r);
}
- (void)didMoveToWindow {
    %orig;
    if(!gP.enabled||!((UIView *)self).window)return;
    UIView *v=(UIView *)self;
    if(ADInPersonTab7206(v))ADPersonOwnText7206(v);
    else if(ADInMenuTab7255(v))ADMenuOwnText7255(v);
    else if(ADInLocationSheetContent7196(v))ADLocationSheetOwnText7196(v);
    else if(ADInPersonSavingsSheet7259(v)){ NSTextStorage *ts=ADPersonTextStorage7206(v); if(ts)ADPersonSavingsLightStorage7259(ts); }
}
%end

%hook RCTTextView
- (void)setTextStorage:(NSTextStorage *)textStorage {
    if(ADThemeReactTextStorage7271((UIView *)self,textStorage,YES)){
        %orig;
        return;
    }
    if(gP.enabled && textStorage.length){
        @try {
            NSRange whole=NSMakeRange(0,textStorage.length),range=NSMakeRange(0,0); UIColor *light=ADLightText706();
            id c=[textStorage attribute:NSForegroundColorAttributeName atIndex:0 longestEffectiveRange:&range inRange:whole];
            if(!(range.location==0 && NSMaxRange(range)==textStorage.length && [c isKindOfClass:[UIColor class]] && [(UIColor *)c isEqual:light]))
                [textStorage addAttribute:NSForegroundColorAttributeName value:light range:whole];
        } @catch(...) {}
    }
    %orig;
}
- (void)drawRect:(CGRect)rect {
    // v7.222 heading final-paint gate plus v7.228's exact Highlights tile gate.
    // React can rewrite body-copy storage after assignment; repair only text below
    // tile-widget/iconSection ancestry immediately before draw. Existing accent
    // preservation keeps Prime blue and other authored saturated runs intact.
    UIView *v=(UIView *)self;
    if(gP.enabled&&v.window){
        NSTextStorage *ts=ADPersonTextStorage7206(v);
        if(ADAlexaSuggestionPillText7288(v)){ if(ts)ADAlexaSuggestionPillLightStorage7288(ts); }
        if(ADClassNameIs7183(v.window,"AppCXWindow")){
            if(ADInAppCXBottomSheet7255(v)){ if(ts)ADAppCXSheetLightStorage7255(ts); }
            else if(ADInPersonSavingsSheet7259(v)){ if(ts)ADPersonSavingsLightStorage7259(ts); }
        }
        int surface=ADReactSurface7226(v);
        if(surface==ADReactSurfacePerson7226||ADPersonBuyAgain7208(v)){
            if(ADPersonOfflineFallbackButtonText7299(v)){ if(ts)ADPersonOfflineFallbackButtonStorage7299(ts); }
            else if(ADPersonTopMenuPillText7250(v)){ if(ts)ADPersonTopMenuPillWhiteStorage7250(ts); }
            else if(ADPersonHeaderLeaf7221(v)){ if(ts)ADPersonHeaderStorage7221(ts); }
            else if(ADPersonFinalTextOwner7239(v)||ADPersonInHighlightTile7212(v)){ if(ts)ADPersonLightStorage7206(ts); }
        } else if(surface==ADReactSurfaceMenu7255&&ts)ADMenuLightStorage7255(ts);
    }
    %orig(rect);
}
- (void)didMoveToWindow {
    %orig;
    objc_setAssociatedObject(self,kADReactSurfaceCache7232,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ADOwnReactText7271((UIView *)self,YES);
}
%end

%hook UILabel
- (void)setAttributedText:(NSAttributedString *)attributedText {
    UIView *v=(UIView *)self;
    if(gP.enabled){
        if(ADInAuthoredVisualSubNav7175(v)){
            %orig(attributedText);
            return;
        }
        if(v.window){
            if(ADClassNameIs7183(v.window,"AppCXWindow")){
                if(ADInAppCXBottomSheet7255(v)){
                    NSAttributedString *themed=ADAppCXSheetLightString7255(attributedText);
                    %orig(themed);
                    return;
                }
                if(ADInPersonSavingsSheet7259(v)){
                    NSAttributedString *themed=ADPersonSavingsLightString7259(attributedText);
                    %orig(themed);
                    return;
                }
            }
            int surface=ADReactSurface7226(v);
            if(surface==ADReactSurfacePerson7226){
                NSAttributedString *themed=ADPersonHeaderLeaf7221(v)?ADPersonHeaderString7221(attributedText):ADPersonLightString7206(attributedText);
                %orig(themed);
                return;
            }
            if(surface==ADReactSurfaceMenu7255){
                NSAttributedString *themed=ADMenuLightString7255(attributedText);
                %orig(themed);
                return;
            }
            if(ADInLocationSheetContent7196(v)){
                NSAttributedString *themed=ADLocationSheetLightString7196(v,attributedText);
                %orig(themed);
                return;
            }
        }
    }
    if(gP.enabled&&ADInSearchChrome706(v)&&attributedText.length){
        NSMutableAttributedString *m=[attributedText mutableCopy];
        [m addAttribute:NSForegroundColorAttributeName value:ADLightText706() range:NSMakeRange(0,m.length)];
        %orig(m);
        return;
    }
    NSAttributedString *r=ADLightAttributedText708(attributedText);
    %orig(r);
}
- (void)setTextColor:(UIColor *)color {
    UIView *v=(UIView *)self;
    if(gP.enabled){
        if(ADInAuthoredVisualSubNav7175(v)){
            %orig(color);
            return;
        }
        if(v.window){
            if(ADClassNameIs7183(v.window,"AppCXWindow")){
                if(ADInAppCXBottomSheet7255(v)){
                    UIColor *themed=ADNeutralNearBlack7255(color)?ADLightText706():color;
                    %orig(themed);
                    return;
                }
                if(ADInPersonSavingsSheet7259(v)){
                    UIColor *themed=ADPersonSavingsDarkNeutral7259(color)?ADLightText706():color;
                    %orig(themed);
                    return;
                }
            }
            int surface=ADReactSurface7226(v);
            if(surface==ADReactSurfacePerson7226){
                if(ADPersonHeaderLeaf7221(v)){
                    UIColor *light=ADLightText706();
                    %orig(light);
                    return;
                }
                if(ADPersonAccent7206(color)){
                    %orig(color);
                    return;
                }
                UIColor *themed=ADPersonPrimaryFont7206(self.font)?ADLightText706():ADPersonSecondary7206();
                %orig(themed);
                return;
            }
            if(surface==ADReactSurfaceMenu7255){
                UIColor *themed=ADMenuDarkNeutral7255(color)?ADLightText706():color;
                %orig(themed);
                return;
            }
            if(ADInLocationSheetContent7196(v)){
                if(ADLocationSheetPreserveBlueGeometry7196(v)||ADColorLinkBlue7196(color)){
                    %orig(color);
                    return;
                }
                UIColor *themed=ADLocationSheetTextColor7196(v);
                %orig(themed);
                return;
            }
        }
        UIColor *want=ADLightText706();
        if([self.textColor isEqual:want])return;
        %orig(want);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    UIView *v=(UIView *)self;
    objc_setAssociatedObject(v,kADReactSurfaceCache7232,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(!gP.enabled||!v.window||ADInAuthoredVisualSubNav7175(v))return;
    if(ADClassNameIs7183(v.window,"AppCXWindow")){
        if(ADInAppCXBottomSheet7255(v)){ if(ADNeutralNearBlack7255(self.textColor))self.textColor=ADLightText706(); return; }
        if(ADInPersonSavingsSheet7259(v)){ if(ADPersonSavingsDarkNeutral7259(self.textColor))self.textColor=ADLightText706(); return; }
    }
    int surface=ADReactSurface7226(v);
    if(surface==ADReactSurfacePerson7226){ ADPersonOwnText7206(v); return; }
    if(surface==ADReactSurfaceMenu7255){
        if(ADMenuDarkNeutral7255(self.textColor))self.textColor=ADLightText706();
        return;
    }
    if(ADInLocationSheetContent7196(v)){ ADLocationSheetOwnText7196(v); return; }
    UIColor *want=ADLightText706(); if(![self.textColor isEqual:want]) self.textColor=want;
}
%end

%hook UITextView
- (BOOL)becomeFirstResponder {
    if(gP.enabled)ADPrepareSearchKeyboard7120((UIView *)self);
    return %orig;
}
- (void)setKeyboardAppearance:(UIKeyboardAppearance)appearance {
    if(gP.enabled){
        UIKeyboardAppearance dark=UIKeyboardAppearanceDark;
        %orig(dark);
        return;
    }
    %orig;
}
- (void)setTextColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *want=ADLightText706();
        if([self.textColor isEqual:want])return;
        %orig(want);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window){ UIColor *want=ADLightText706(); if(![self.textColor isEqual:want]) self.textColor=want; ADPrepareSearchKeyboard7120((UIView *)self); }
}
%end

%hook UITextField
- (BOOL)becomeFirstResponder {
    BOOL orderSearch=gP.enabled&&((UIView *)self).window;
    if(gP.enabled)ADPrepareSearchKeyboard7120((UIView *)self);
    BOOL became=%orig;
    if(orderSearch&&became)ADPersonRepairOrderSearchAncestors7242((UIView *)self);
    return became;
}
- (void)setKeyboardAppearance:(UIKeyboardAppearance)appearance {
    if(gP.enabled){
        UIKeyboardAppearance dark=UIKeyboardAppearanceDark;
        %orig(dark);
        return;
    }
    %orig;
}
- (void)setTextColor:(UIColor *)color {
    if(gP.enabled){
        UIColor *want=ADLightText706();
        if([self.textColor isEqual:want])return;
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
        UIColor *want=ADLightText706(); if(![self.textColor isEqual:want]) self.textColor=want;
        if(search && self.placeholder.length){
            self.attributedPlaceholder=[[NSAttributedString alloc] initWithString:self.placeholder attributes:@{NSForegroundColorAttributeName:ADLightText706()}];
        }
        ADPersonRepairOrderSearchAncestors7242((UIView *)self);
    }
}
%end

// v7.243: React Native may override UITextField lifecycle methods on RCTUITextField.
// Own that exact class too so the universal OLED request cannot be bypassed by RN.
%hook RCTUITextField
- (BOOL)becomeFirstResponder {
    ADPrepareSearchKeyboard7120((UIView *)self);
    BOOL became=%orig;
    if(became)ADPersonRepairOrderSearchAncestors7242((UIView *)self);
    return became;
}
- (void)setKeyboardAppearance:(UIKeyboardAppearance)appearance {
    if(gP.enabled){
        UIKeyboardAppearance dark=UIKeyboardAppearanceDark;
        %orig(dark);
        return;
    }
    %orig(appearance);
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&((UIView *)self).window){
        ADPrepareSearchKeyboard7120((UIView *)self);
        ADPersonRepairOrderSearchAncestors7242((UIView *)self);
    }
}
%end

%hook UIButton
- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state {
    if(gP.enabled && ADInAuthoredVisualSubNav7175((UIView *)self)){
        %orig(color,state);
        return;
    }
    if(gP.enabled){
        UIColor *light=ADLightText706();
        if([[self titleColorForState:state] isEqual:light])return;
        %orig(light,state);
        return;
    }
    %orig;
}
%end

%hook CALayer
- (void)setBorderColor:(CGColorRef)color {
    if(gP.enabled){
        @try {
            id d=self.delegate;
            if([d isKindOfClass:[UIView class]] && ADInAuthoredVisualSubNav7175((UIView *)d)){
                %orig(color);
                return;
            }
            if([d isKindOfClass:[UIView class]] && ADMenuViewRole7255((UIView *)d)==2){
                CGColorRef buttonBorder=ADMenuButtonBorder7255().CGColor;
                %orig(buttonBorder);
                return;
            }
        } @catch(...) {}
    }
    if(gP.enabled&&color&&ADNeutralCGColor706(color)){
        UIColor *g=ADBorderGray706();
        CGColorRef cg=g.CGColor;
        if(self.borderColor&&CGColorEqualToColor(self.borderColor,cg))return;
        %orig(cg);
        return;
    }
    %orig;
}
%end

%hook CAShapeLayer
- (void)setStrokeColor:(CGColorRef)color {
    if(gP.enabled){
        @try {
            id d=self.delegate;
            if([d isKindOfClass:[UIView class]] && ADInAuthoredVisualSubNav7175((UIView *)d)){
                %orig(color);
                return;
            }
        } @catch(...) {}
    }
    if(gP.enabled&&color&&ADNeutralCGColor706(color)&&(self.bounds.size.width>24||self.bounds.size.height>24)){
        UIColor *g=ADBorderGray706();
        CGColorRef cg=g.CGColor;
        if(self.strokeColor&&CGColorEqualToColor(self.strokeColor,cg))return;
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

// v7.273: Amazon currently exposes two live Search-leading renderers. The dedicated
// Search-entry bar uses SBSearchBarIconView inside SBSearchBarLeadingStackView; product
// results can rebuild the same 18-30pt leading glyph as a plain UIImageView beneath
// SBSearchField/SBMultilineSearchView. Keep both exact routes, with the alternate route
// bounded to seven ancestors and the leading 8-42pt field slot.
static const void *kADSearchLeadingMagnifier7229=&kADSearchLeadingMagnifier7229;
static BOOL ADSearchLeadingMagnifier7229(UIImageView *iv){
    if(!iv)return NO;
    @try {
        if(objc_getAssociatedObject(iv,kADSearchLeadingMagnifier7229))return YES;
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<18.0||w>30.0||h<18.0||h>30.0||fabs(w-h)>4.0)return NO;
        UIView *field=nil; NSUInteger depth=0;
        for(UIView *n=iv.superview;n&&n!=iv.window&&depth<7;n=n.superview,depth++){
            if(ADClassNameHasFold7183(n,"sbsearchbarleadingstackview")&&ADClassNameHasFold7183(iv,"sbsearchbariconview")){
                objc_setAssociatedObject(iv,kADSearchLeadingMagnifier7229,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                return YES;
            }
            if(!field&&(ADClassNameHasFold7183(n,"sbsearchfield")||ADClassNameHasFold7183(n,"sbmultilinesearchview")))field=n;
        }
        if(!field)return NO;
        CGRect r=[iv convertRect:iv.bounds toView:field];
        CGFloat midX=CGRectGetMidX(r),midY=CGRectGetMidY(r);
        if(midX<8.0||midX>42.0||midY<4.0||midY>field.bounds.size.height-4.0)return NO;
        objc_setAssociatedObject(iv,kADSearchLeadingMagnifier7229,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return YES;
    } @catch(...) {}
    return NO;
}
static void ADOwnSearchLeadingMagnifier7229(UIImageView *iv){
    if(!gP.enabled||!iv||!iv.image)return;
    if(!objc_getAssociatedObject(iv,kADSearchLeadingMagnifier7229)&&!ADSearchLeadingMagnifier7229(iv))return;
    @try {
        UIImage *im=iv.image;
        if(im.renderingMode!=UIImageRenderingModeAlwaysTemplate&&!gADSearchImageWrite706){
            UIImage *tpl=[im imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            if(tpl){ gADSearchImageWrite706=YES; iv.image=tpl; gADSearchImageWrite706=NO; }
        }
        iv.tintColor=ADLightText706();
    } @catch(...) { gADSearchImageWrite706=NO; }
}

%hook SBSearchBar
- (void)didMoveToWindow {
    %orig;
    UIView *v=(UIView *)self;
    if(gP.enabled&&v.window){
        ADSetViewBackground7226(v,[UIColor clearColor],YES);
        v.layer.borderWidth=0;
    }
}
%end

static void ADOwnSearchSurface7045(UIView *v, BOOL ownBorder){
    if(!gP.enabled||!v||!v.window)return;
    @try {
        UIColor *fill=ADSearchChromeFill7045();
        ADSetViewBackground7226(v,fill,YES);
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
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
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
        ADSetViewBackground7226(v,fill,YES);
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
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
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
        ADSetViewBackground7226(root,ADOLED(),YES);
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
                ADSetViewBackground7226(ancestor,ADOLED(),YES);
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
                ADSetViewBackground7226(v,ADOLED(),YES);
                v.layer.borderColor=ADBorderGray706().CGColor;
                if(v.layer.borderWidth<0.5)v.layer.borderWidth=1.0;
            } else if(d>0 && ADBrightNeutralUIView708(v)){
                ADSetViewBackground7226(v,ADOLED(),YES);
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
- (void)didAddSubview:(UIView *)subview {
    %orig;
    ADPaintScanItSearchWidget7120((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
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
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
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
        ADSetViewBackground7226(v,ADOLED(),YES);
    } @catch(...) {}
}
%hook UIVisualEffectView
- (void)didMoveToWindow {
    %orig;
    BOOL bottom=NO; BOOL bar=ADBarGeometry713(self,&bottom);
    if(gP.enabled && self.window && (ADInBottomNav706(self)||ADTopChromeClass713(self)||bar)){
        self.effect=nil;
        ADSetViewBackground7226(self,ADOLED(),YES);
    }
}
- (void)layoutSubviews {
    %orig;
    BOOL bottom=NO; BOOL bar=ADBarGeometry713(self,&bottom);
    if(gP.enabled && self.window && (ADInBottomNav706(self)||ADTopChromeClass713(self)||bar)){
        self.effect=nil;
        ADSetViewBackground7226(self,ADOLED(),YES);
    }
}
%end

%hook UITabBar
- (void)didMoveToWindow {
    %orig;
    ADOwnBottomBar708((UIView *)self);
}
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
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
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
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
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
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
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
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
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
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
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
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
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(gP.enabled){
        UIColor *black=ADOLED();
        %orig(black);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window){ ADSetViewBackground7226(self,ADOLED(),YES); }
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
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(gP.enabled&&self.window&&ADExactGlowIngress7140(self)){
        UIColor *black=ADOLED();
        %orig(black);
        objc_setAssociatedObject(self,kADSearchDeliveryBand7139,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    %orig;
}
%end

// v7.211 exact Home visual-category chip floor ownership. This is deliberately on
// the cell class rather than the whole VisualSubNav controller. Every authored/placeholder
// fill is replaced by the same gray through this one exact owner.
%hook ANXVisualSubNavTextCollectionViewCell
- (void)setBackgroundColor:(UIColor *)color {
    if(ADInternalPaintWrite7226()){
        %orig(color);
        return;
    }
    if(gP.enabled){
        UIColor *fill=ADHomeChipGray7226();
        %orig(fill);
        return;
    }
    %orig(color);
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&((UIView *)self).window)ADOwnHomeVisualSubNavCell7211((UIView *)self);
}
%end

// v7.139 exact compact Search delivery/subnav ownership. These controller hooks are
// event-driven and geometry-gated; no hierarchy polling or recurring timer is used.
// ANXVisualSubNavViewController is intentionally left stock except for the
// exact cell-floor hook above. No controller-level repaint path is installed.


// Status-bar ownership from the v5.446/v6.0.5 lineage. This generic lifecycle hook
// does NOT paint controller views; it only installs a cached per-class light-content claim.
%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if(gP.enabled){
        ADClaimStatusController713(self);
        if(ADPrimaryAmazonController713(self) && self.isViewLoaded){
            ADSetViewBackground7226(self.view,ADOLED(),YES);
        }
    }
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if(gP.enabled){
        ADClaimStatusController713(self);
        if(ADPrimaryAmazonController713(self))ADConsiderLaunchReady706();
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

// v7.336: no app-switcher overlay ownership. v6.185 lets UIKit snapshot the
// already-themed live Amazon hierarchy naturally; only the primary Amazon UIWindow
// receives its ordinary OLED backing. No black/logo view is inserted for backgrounding.
%hook UIWindow
- (void)setRootViewController:(UIViewController *)vc {
    %orig;
    if(gP.enabled && ADPrimaryAmazonWindow713(self,vc)) ADSetViewBackground7226(self,ADOLED(),YES);
}
- (void)makeKeyAndVisible {
    if(gP.enabled && ADPrimaryAmazonWindow713(self,nil)) ADSetViewBackground7226(self,ADOLED(),YES);
    %orig;
}
%end

%hook UITableView
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window) ADSetViewBackground7226((UIView *)self,ADOLED(),YES);
}
%end

%hook UICollectionView
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window) ADSetViewBackground7226((UIView *)self,ADOLED(),YES);
}
%end

// v7.238: Person's vertical indicator is native UIScrollView chrome, not web
// content. The probe identifies the exact RCTCustomScrollView directly under
// RCTScrollView#me and shows its indicator thumb is black at 35% alpha. Set the
// stock indicator style to white only on that exact owner; no scroll listener or
// recurring hierarchy work is introduced.
static BOOL ADPersonCustomScroll7238(UIView *v){
    if(!v||!v.window||!ADClassNameIs7183(v,"RCTCustomScrollView"))return NO;
    @try {
        UIView *p=v.superview;
        return p&&ADClassNameIs7183(p,"RCTScrollView")&&[p.accessibilityIdentifier isEqualToString:@"me"];
    } @catch(...) { return NO; }
}
static void ADPersonOwnScrollIndicator7238(UIView *v){
    if(!gP.enabled||!ADPersonCustomScroll7238(v))return;
    @try { [(UIScrollView *)v setIndicatorStyle:UIScrollViewIndicatorStyleWhite]; } @catch(...) {}
}

%hook RCTCustomScrollView
- (void)didMoveToWindow {
    %orig;
    ADPersonOwnScrollIndicator7238((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    ADPersonOwnScrollIndicator7238((UIView *)self);
}
%end

%hook RCTRootView
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window) ADSetViewBackground7226((UIView *)self,ADOLED(),YES);
}
%end

%hook RCTRootContentView
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window) ADSetViewBackground7226((UIView *)self,ADOLED(),YES);
}
%end

%hook RCTScrollView
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window) ADSetViewBackground7226((UIView *)self,ADOLED(),YES);
}
- (void)layoutSubviews {
    %orig;
    if(gP.enabled&&self.window)ADPaintLocationSheetStable7196((UIView *)self);
}
%end

// v7.336: warm foreground behavior is intentionally returned to the v6.185 contract.
// AmazonDark does not fabricate a warm loading transition and does not inject a snapshot
// cover into Amazon's UIWindow. If Amazon itself instantiates one of its launch controllers,
// own only that controller's floor dark; never hide/show it as a warm-resume mechanism.
// The observers below are diagnostics only and do not paint or mutate the app hierarchy.
static dispatch_queue_t ADLaunchAppProbeQueue7317(void){
    static dispatch_queue_t q; static dispatch_once_t once; dispatch_once(&once,^{q=dispatch_queue_create("com.colindavidr.amazondark.launchprobe.app",DISPATCH_QUEUE_SERIAL);}); return q;
}
static NSString *ADLaunchAppProbePath7317(void){
    static NSString *p; static dispatch_once_t once; dispatch_once(&once,^{NSString *docs=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject];p=[(docs.length?docs:NSTemporaryDirectory()) stringByAppendingPathComponent:@"AmazonDark-v7.336-launch-app-probe.txt"];}); return p;
}
static void ADLaunchAppProbeLog7317(NSString *event,NSString *detail){
    @try {
        NSTimeInterval wall=CFAbsoluteTimeGetCurrent(),up=NSProcessInfo.processInfo.systemUptime;
        NSString *line=[NSString stringWithFormat:@"%.6f up=%.6f pid=%d main=%d event=%@ %@\n",wall,up,NSProcessInfo.processInfo.processIdentifier,[NSThread isMainThread]?1:0,event?:@"?",detail?:@""];
        dispatch_async(ADLaunchAppProbeQueue7317(),^{@autoreleasepool{@try{NSString *path=ADLaunchAppProbePath7317();NSData *d=[line dataUsingEncoding:NSUTF8StringEncoding];NSFileManager *fm=[NSFileManager defaultManager];if(![fm fileExistsAtPath:path])[fm createFileAtPath:path contents:nil attributes:nil];NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:path];if(h){[h seekToEndOfFile];[h writeData:d];[h closeFile];}}@catch(__unused NSException *e){}}});
    } @catch(__unused NSException *e){}
}
static NSString *ADLaunchSplashState7317(UIViewController *vc){
    @try { UIView *v=vc.view; return [NSString stringWithFormat:@"cls=%@ view=%p win=%p hidden=%d alpha=%.3f bg=%@",NSStringFromClass(vc.class)?:@"?",v,v.window,v.hidden?1:0,v.alpha,v.backgroundColor]; } @catch(...) { return @"state-exception"; }
}

static void ADOwnAmazonSplash7336(UIViewController *vc){
    if(!gP.enabled||!vc||!vc.view)return;
    @try { ADSetViewBackground7226(vc.view,ADOLED(),YES); } @catch(...) {}
}

static BOOL gADLaunchLifecycleLoggerInstalled7336=NO;
static void ADInstallLaunchLifecycleLogger7336(void){
    if(gADLaunchLifecycleLoggerInstalled7336)return;
    gADLaunchLifecycleLoggerInstalled7336=YES;
    @try {
        NSNotificationCenter *nc=[NSNotificationCenter defaultCenter];
        [nc addObserverForName:UISceneWillConnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *n){
            ADLaunchAppProbeLog7317(@"UISceneWillConnect",@"");
        }];
        [nc addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *n){
            ADLaunchAppProbeLog7317(@"UIApplicationWillResignActive",@"");
        }];
        [nc addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *n){
            ADLaunchAppProbeLog7317(@"UIApplicationDidEnterBackground",@"");
        }];
        [nc addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *n){
            ADLaunchAppProbeLog7317(@"UIApplicationWillEnterForeground",@"");
        }];
        [nc addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *n){
            ADLaunchAppProbeLog7317(@"UIApplicationDidBecomeActive",@"");
        }];
    } @catch(...) {}
}

// v7.336 deliberately does NOT restore v6.185's SplashBoard cache deletion.
// v7.330 was the confirmed no-white cold baseline; its system-snapshot policy stays exact.
// The v6.185 behavior being ported here is only warm direct-to-live-app behavior and
// the absence of any app-switcher cover inside Amazon.

// -----------------------------------------------------------------------------
// Launch transition handoff retained in v7.336. The SpringBoard side keeps the
// 1.40 s minimum and 0.55 s fade; Amazon releases it only after the bounded,
// stable real-Home check below. v7.330 snapshot/cache policy is unchanged; no
// app-switcher cover is injected.
// -----------------------------------------------------------------------------
static BOOL gADReadyPosted706=NO;
static BOOL gADReadyScheduled706=NO;
static BOOL gADReadyEvaluating706=NO;
static BOOL gADReadyDwell706=NO;
static NSUInteger gADReadyAttempts706=0;
static NSUInteger gADReadyStable706=0;

static BOOL ADVisibleSplashController706(void){
    @try {
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w || w.hidden || w.alpha<0.01)continue;
            UIViewController *vc=w.rootViewController;
            NSMutableArray *q=[NSMutableArray array]; if(vc)[q addObject:vc];
            for(NSUInteger i=0;i<q.count&&i<24;i++){
                UIViewController *x=q[i];
                NSString *xn=NSStringFromClass(x.class).lowercaseString?:@"";
                if(([xn containsString:@"splash"]||[xn containsString:@"launchscreen"]||[xn containsString:@"loading"]) && x.isViewLoaded && x.view.window && !x.view.hidden && x.view.alpha>0.01) return YES;
                if(x.presentedViewController)[q addObject:x.presentedViewController];
                for(UIViewController *c in x.childViewControllers) if(c)[q addObject:c];
            }
        }
    } @catch(...) {}
    return NO;
}
// v7.326: restore the v7.185 correctness-only launch gate. A black Home WebView can already exist underneath
// Amazon's transient stock white loading plane, so controller naming alone is not sufficient.
// During the one-shot cold-launch handoff only, reject any large visible bright-neutral native plane.
static BOOL ADVisibleBrightLaunchPlane7185(void){
    @try {
        CGRect screen=UIScreen.mainScreen.bounds;
        CGFloat screenArea=MAX(1.0,screen.size.width*screen.size.height);
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.02||fabs(w.windowLevel-UIWindowLevelNormal)>0.1)continue;
            NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:w];
            for(NSUInteger i=0;i<q.count&&i<220;i++){
                UIView *v=q[i]; if(!v||v.hidden||v.alpha<0.02)continue;
                CGRect r=[v convertRect:v.bounds toView:nil], ir=CGRectIntersection(r,screen);
                CGFloat area=MAX(0.0,ir.size.width)*MAX(0.0,ir.size.height);
                if(area>=screenArea*0.30 && ir.size.width>=screen.size.width*0.80){
                    UIColor *c=v.backgroundColor;
                    if((!c||CGColorGetAlpha(c.CGColor)<0.02)&&v.layer.backgroundColor)c=[UIColor colorWithCGColor:v.layer.backgroundColor];
                    if(ADBrightNeutral7130(c))return YES;
                }
                for(UIView *child in (v.subviews.copy?:@[])) if(child)[q addObject:child];
            }
        }
    } @catch(...) {}
    return NO;
}
static void ADPostReadyOnce(void){
    if(gADReadyPosted706)return; gADReadyPosted706=YES;
    NSInteger pid=NSProcessInfo.processInfo.processIdentifier;
    NSString *channel=[NSString stringWithFormat:@"com.colindavidr.amazondark.ready.%ld",(long)pid];
    ADLaunchAppProbeLog7317(@"home-ready.post",[NSString stringWithFormat:@"pid=%ld channel=%@ attempts=%lu stable=%lu",(long)pid,channel,(unsigned long)gADReadyAttempts706,(unsigned long)gADReadyStable706]);
    @try { notify_post(channel.UTF8String); } @catch(...) {}
}

// v7.326: restore the proven v7.170 pre-v7.115 launch-readiness contract. v7.115 replaced
// this bounded launch-only gate with an event-only handoff; the device now proves
// that the ready signal can arrive while Amazon's stock white splash composite is
// still on screen. Do not release the SpringBoard cover until a real, finished,
// OLED Home document is stable. This work exists only during cold-launch handoff.
static WKWebView *ADLaunchReadyWebView706(void){
    WKWebView *best=nil; CGFloat bestArea=0;
    @try {
        for(WKWebView *wv in ADTrackedWebViews()){
            if(!wv||!wv.window||wv.hidden||wv.alpha<0.01||wv.loading)continue;
            CGRect r=[wv convertRect:wv.bounds toView:nil];
            CGRect ir=CGRectIntersection(r,UIScreen.mainScreen.bounds);
            CGFloat a=MAX(0,ir.size.width)*MAX(0,ir.size.height);
            if(a>bestArea){ bestArea=a; best=wv; }
        }
    } @catch(...) {}
    return bestArea>=100000.0?best:nil;
}
static NSString *ADLaunchReadyJS706(void){
    return @"(function(){try{"
           "if(document.readyState!=='interactive'&&document.readyState!=='complete')return 0;"
           "var root=document.querySelector('#gwm-PageContent,#gwm-Deck,.gwm-dashboard-container,#a-page,[role=main],main');"
           "if(!root)return 0;var r=root.getBoundingClientRect(),h=Math.max(r.height||0,root.scrollHeight||0);"
           "if(r.width<300||h<300)return 0;var c=getComputedStyle(root).backgroundColor||'',m=c.match(/rgba?\\(\\s*([\\d.]+)\\s*,\\s*([\\d.]+)\\s*,\\s*([\\d.]+)/i);"
           "if(!m||(+m[1]>8)||(+m[2]>8)||(+m[3]>8))return 0;"
           "var media=root.querySelector('img,video,canvas');"
           "if(!media&&(root.children||[]).length<3&&h<innerHeight*.75)return 0;return 1;"
           "}catch(e){return 0}})();";
}
static void ADRunLaunchReadyCheck706(void);
static void ADScheduleLaunchReadyCheck706(NSTimeInterval delay){
    if(gADReadyPosted706||!gP.enabled||gADReadyScheduled706||gADReadyEvaluating706||gADReadyDwell706)return;
    if(gADReadyAttempts706>=120)return;
    gADReadyScheduled706=YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(MAX(0.0,delay)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        gADReadyScheduled706=NO;
        ADRunLaunchReadyCheck706();
    });
}
static void ADLaunchReadyFailure706(void){
    gADReadyStable706=0;
    gADReadyEvaluating706=NO;
    gADReadyDwell706=NO;
    ADScheduleLaunchReadyCheck706(0.125);
}
static void ADRunLaunchReadyCheck706(void){
    if(gADReadyPosted706||!gP.enabled||gADReadyEvaluating706||gADReadyDwell706)return;
    if(gADReadyAttempts706>=120)return;
    gADReadyAttempts706++;
    if(ADVisibleSplashController706()||ADVisibleBrightLaunchPlane7185()){ ADLaunchReadyFailure706(); return; }
    WKWebView *wv=ADLaunchReadyWebView706();
    if(!wv){ ADLaunchReadyFailure706(); return; }
    gADReadyEvaluating706=YES;
    [wv evaluateJavaScript:ADLaunchReadyJS706() completionHandler:^(id v,NSError *e){
        gADReadyEvaluating706=NO;
        if(gADReadyPosted706||!gP.enabled)return;
        BOOL ok=(!e&&[v respondsToSelector:@selector(integerValue)]&&[v integerValue]==1&&!wv.loading&&!ADVisibleSplashController706()&&!ADVisibleBrightLaunchPlane7185());
        if(!ok){ ADLaunchReadyFailure706(); return; }
        gADReadyStable706++;
        if(gADReadyStable706<3){ ADScheduleLaunchReadyCheck706(0.125); return; }
        gADReadyDwell706=YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.250*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            if(gADReadyPosted706||!gP.enabled){ gADReadyDwell706=NO; return; }
            if(ADVisibleSplashController706()||ADVisibleBrightLaunchPlane7185()){ ADLaunchReadyFailure706(); return; }
            WKWebView *finalWV=ADLaunchReadyWebView706();
            if(!finalWV){ ADLaunchReadyFailure706(); return; }
            gADReadyEvaluating706=YES; gADReadyDwell706=NO;
            [finalWV evaluateJavaScript:ADLaunchReadyJS706() completionHandler:^(id fv,NSError *fe){
                gADReadyEvaluating706=NO;
                BOOL finalOK=(!fe&&[fv respondsToSelector:@selector(integerValue)]&&[fv integerValue]==1&&!finalWV.loading&&!ADVisibleSplashController706()&&!ADVisibleBrightLaunchPlane7185());
                if(finalOK)ADPostReadyOnce(); else ADLaunchReadyFailure706();
            }];
        });
    }];
}
static void ADConsiderLaunchReady706(void){
    if(gADReadyPosted706||!gP.enabled)return;
    if(gADReadyAttempts706==0)ADLaunchAppProbeLog7317(@"home-ready.start",@"");
    // Multiple existing lifecycle hooks may arrive; this scheduler deduplicates them.
    ADScheduleLaunchReadyCheck706(0.0);
}


%hook AXUSplashScreenViewController
- (void)viewDidLoad {
    %orig;
    ADOwnAmazonSplash7336(self);
    ADLaunchAppProbeLog7317(@"AXUSplashScreenViewController.viewDidLoad",ADLaunchSplashState7317(self));
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    ADOwnAmazonSplash7336(self);
    ADLaunchAppProbeLog7317(@"AXUSplashScreenViewController.viewWillAppear",ADLaunchSplashState7317(self));
}
- (void)viewDidLayoutSubviews {
    %orig;
    ADOwnAmazonSplash7336(self);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    ADOwnAmazonSplash7336(self);
    ADLaunchAppProbeLog7317(@"AXUSplashScreenViewController.viewDidAppear",ADLaunchSplashState7317(self));
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    ADLaunchAppProbeLog7317(@"AXUSplashScreenViewController.viewDidDisappear",ADLaunchSplashState7317(self));
    ADConsiderLaunchReady706();
}
%end
%hook TezBaseSplashScreenViewController
- (void)viewDidLoad {
    %orig;
    ADOwnAmazonSplash7336(self);
    ADLaunchAppProbeLog7317(@"TezBaseSplashScreenViewController.viewDidLoad",ADLaunchSplashState7317(self));
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    ADOwnAmazonSplash7336(self);
    ADLaunchAppProbeLog7317(@"TezBaseSplashScreenViewController.viewWillAppear",ADLaunchSplashState7317(self));
}
- (void)viewDidLayoutSubviews {
    %orig;
    ADOwnAmazonSplash7336(self);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    ADOwnAmazonSplash7336(self);
    ADLaunchAppProbeLog7317(@"TezBaseSplashScreenViewController.viewDidAppear",ADLaunchSplashState7317(self));
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    ADLaunchAppProbeLog7317(@"TezBaseSplashScreenViewController.viewDidDisappear",ADLaunchSplashState7317(self));
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
static void ADResetNativeTWBCache7214(UIImageView *iv){
    if(!iv)return;
    @try {
        objc_setAssociatedObject(iv,kADTWBEligibility,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(iv,kADTWBEligibilityImage,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}
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
    if(ADInPersonTab7206(iv))return ADPersonMediaBlocked7206(iv);
    @try {
        UIImage *im=iv.image; if(!im)return YES;
        if(im.renderingMode==UIImageRenderingModeAlwaysTemplate)return YES;
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height; if(w<52||h<52)return YES;
        if(im.CGImage && CGImageGetWidth(im.CGImage)<=80 && CGImageGetHeight(im.CGImage)<=80)return YES;
        BOOL controlMeta=ADStringHasAny7226(iv.accessibilityLabel,ADNativeControlTokens7226())||
                         ADStringHasAny7226(iv.accessibilityIdentifier,ADNativeControlTokens7226());
        BOOL semanticProduct=ADStringHasAny7226(iv.accessibilityLabel,ADNativeProductTokens7226())||
                             ADStringHasAny7226(iv.accessibilityIdentifier,ADNativeProductTokens7226());
        UIView *n=iv;
        for(int i=0;i<4&&n;i++,n=n.superview){
            if([n isKindOfClass:[UIButton class]]||[n isKindOfClass:[UITabBar class]]||[n isKindOfClass:[UINavigationBar class]])return YES;
            controlMeta=controlMeta||ADStringHasAny7226(NSStringFromClass(n.class),ADNativeControlTokens7226())||
                                    ADStringHasAny7226(n.accessibilityIdentifier,ADNativeControlTokens7226());
            semanticProduct=semanticProduct||ADStringHasAny7226(NSStringFromClass(n.class),ADNativeProductTokens7226())||
                                             ADStringHasAny7226(n.accessibilityIdentifier,ADNativeProductTokens7226());
        }
        if(controlMeta)return YES;
        CGSize screen=UIScreen.mainScreen.bounds.size;
        if(screen.width>0 && screen.height>0 && w>=screen.width*0.72&&h>=screen.height*0.48)return YES;
        BOOL knownAmazonRaster=(ADClassNameHasFold7183(iv,"rctuiimageviewanimated")||ADClassNameHasFold7183(iv,"anxfastimageview"));
        if(!semanticProduct && !knownAmazonRaster)return YES;
    } @catch(...) { return YES; }
    return NO;
}
static BOOL ADNativeMediaBlockedCached7146(UIImageView *iv){
    if(!iv||!iv.image)return YES;
    CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
    BOOL person=ADInPersonTab7206(iv);
    BOOL personControl=person&&(ADPersonSectionChevron7217(iv)||ADPersonMedicalAuthoredIcon7231(iv));
    BOOL personForced=person&&(ADPersonExplicitProductMedia7206(iv)||ADPersonForcedMedia7212(iv)||
                               ADPersonForcedMedia7218(iv)||ADPersonReviewCompactImage7229(iv)||
                               ADPersonCustomerServiceLeadingImage7229(iv)||ADPersonSubscribeImage7235(iv)||
                               ADPersonPreviouslyWatchedImage7235(iv));
    if((w<52||h<52)&&!personForced)return YES; // exact Person section media may be smaller than the generic native threshold.
    @try {
        if(personControl){
            objc_setAssociatedObject(iv,kADTWBEligibilityImage,iv.image,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(iv,kADTWBEligibility,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return YES;
        }
        if(personForced){
            // A section marker is stronger than an earlier generic blocked-cache result.
            // This closes the single recycled Shopping List image that stayed untamed.
            objc_setAssociatedObject(iv,kADTWBEligibilityImage,iv.image,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(iv,kADTWBEligibility,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return NO;
        }
        UIImage *last=objc_getAssociatedObject(iv,kADTWBEligibilityImage);
        NSNumber *cached=objc_getAssociatedObject(iv,kADTWBEligibility);
        if(last==iv.image&&cached)return cached.boolValue;
        BOOL blocked=ADNativeMediaBlocked(iv);
        objc_setAssociatedObject(iv,kADTWBEligibilityImage,iv.image,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(iv,kADTWBEligibility,@(blocked),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return blocked;
    } @catch(...) { return ADNativeMediaBlocked(iv); }
}
static void ADEnsureNativeTWBOverlay7270(UIImageView *iv){
    if(!iv)return;
    @try {
        CALayer *ov=objc_getAssociatedObject(iv,kADTWBOverlay);
        if(!ov){
            ov=[CALayer layer]; ov.name=@"AmazonDarkTWB7";
            ov.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"backgroundColor":[NSNull null],@"zPosition":[NSNull null]};
            [iv.layer addSublayer:ov];
            objc_setAssociatedObject(iv,kADTWBOverlay,ov,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(ov.superlayer!=iv.layer)[iv.layer addSublayer:ov];
        CGRect want=iv.bounds; CGColorRef wantColor=ADNativeTWBOverlayColor7146().CGColor;
        if(!CGRectEqualToRect(ov.frame,want))ov.frame=want;
        if(!ov.backgroundColor||!CGColorEqualToColor(ov.backgroundColor,wantColor))ov.backgroundColor=wantColor;
        if(ov.zPosition!=FLT_MAX)ov.zPosition=FLT_MAX;
    } @catch(...) {}
}
static void ADApplyNativeTWBCached7183(UIImageView *iv,BOOL authoredSubNav){
    if(!iv)return;
    @try {
        CALayer *ov=objc_getAssociatedObject(iv,kADTWBOverlay);
        if(gP.enabled && authoredSubNav){
            if(ov){ [ov removeFromSuperlayer]; objc_setAssociatedObject(iv,kADTWBOverlay,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        if(!gP.enabled || !gP.whiteTame || !iv.window || ADNativeMediaBlockedCached7146(iv)){
            if(ov){ [ov removeFromSuperlayer]; objc_setAssociatedObject(iv,kADTWBOverlay,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        ADEnsureNativeTWBOverlay7270(iv);
    } @catch(...) {}
}
// v7.217: v6.185 Person top chrome keeps the greeting chevron, settings and
// notification glyphs light.  Current Amazon exposes these as tiny image views inside
// only the first ~90pt of the exact `me` root.  Keep the country flag out by bounding
// the horizontal range; product/media images cannot match this geometry/position.
static BOOL ADPersonTopChromeGlyph7217(UIImageView *iv){
    if(!iv||!iv.window||!ADInPersonTab7206(iv))return NO;
    @try {
        // The scrolled Medical Care icons and the 8pt notification badge are
        // authored rasters, not monochrome navigation glyphs.
        if(ADPersonMedicalAuthoredIcon7231(iv)||ADPersonNotificationBadge7237(iv))return NO;
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<8.0||w>40.0||h<8.0||h>40.0)return NO;
        UIView *root=nil;
        for(UIView *n=iv;n;n=n.superview){
            if([n.accessibilityIdentifier isEqualToString:@"me"]){ root=n; break; }
        }
        if(!root)return NO;
        CGRect r=[iv convertRect:iv.bounds toView:root];
        CGFloat mx=CGRectGetMidX(r);
        return CGRectGetMinY(r)>=-8.0&&CGRectGetMaxY(r)<=96.0&&mx>=85.0&&mx<=355.0;
    } @catch(...) { return NO; }
}
static void ADPersonOwnTopChromeGlyph7217(UIImageView *iv){
    if(!gP.enabled||!ADPersonTopChromeGlyph7217(iv))return;
    @try {
        UIImage *im=iv.image;
        if(im&&im.renderingMode!=UIImageRenderingModeAlwaysTemplate)iv.image=[im imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        iv.tintColor=ADLightText706();
    } @catch(...) {}
}

// v7.231: every visible right-facing Person action in the captured frame is a
// 12-30pt UIImageView in the trailing 82pt of the exact `me` canvas. This includes
// section headers, the Highlights blue-circle arrow, and the Customer Service row.
// The bounded geometry excludes Reviews product thumbnails and the close glyph.
static BOOL ADPersonRightArrow7231(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||!ADInPersonTab7206(iv))return NO;
    if(ADPersonHighlightIconArrow7240(iv))return YES;
    @try {
        // The country flag lives in the trailing band and matches the old arrow
        // geometry accidentally. Preserve its authored raster instead.
        if(ADPersonCountryFlag7237(iv))return NO;
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<12.0||w>30.0||h<12.0||h>30.0)return NO;
        UIView *me=ADPersonRoot7206(iv);
        if(!me)return NO;
        CGRect r=[iv convertRect:iv.bounds toView:me];
        CGFloat trailing=MAX(320.0,me.bounds.size.width-82.0);
        return CGRectGetMinX(r)>=trailing&&CGRectGetMaxX(r)<=me.bounds.size.width+2.0;
    } @catch(...) { return NO; }
}

static BOOL ADPersonSectionChevron7217(UIImageView *iv){
    if(!iv||!iv.window||!ADInPersonTab7206(iv))return NO;
    @try {
        if(ADPersonRightArrow7231(iv))return YES;
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<12.0||w>36.0||h<12.0||h>36.0)return NO;
        // v7.228 probe exposes the current section-chevron wrappers directly.
        // Use only those captured identifiers; this also prevents Highlights/Reviews
        // section arrows from being misclassified as forced TWB media.
        for(UIView *n=iv.superview;n&&n!=iv.window;n=n.superview){
            NSString *aid=(n.accessibilityIdentifier?:@"").lowercaseString;
            if([aid isEqualToString:@"yhwftr"]||[aid isEqualToString:@"gpw-footer-idftr"]||
               [aid isEqualToString:@"gcfooterftr"]||[aid isEqualToString:@"cm_yc-headerftr"])return YES;
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
        UIView *row=iv.superview;
        for(int up=0;row&&up<3;up++,row=row.superview){
            for(UIView *n in row.subviews){
                if(!ADPersonHeadingBand7217(n))continue;
                CGRect hr=[n convertRect:n.bounds toView:row];
                CGRect ir=[iv convertRect:iv.bounds toView:row];
                if(CGRectGetMidY(ir)>=CGRectGetMinY(hr)-8.0&&CGRectGetMidY(ir)<=CGRectGetMaxY(hr)+8.0&&
                   CGRectGetMinX(ir)>=CGRectGetMaxX(hr)-8.0)return YES;
            }
        }
    } @catch(...) {}
    return NO;
}
static void ADPersonOwnSectionChevron7217(UIImageView *iv){
    if(!gP.enabled||!ADPersonSectionChevron7217(iv))return;
    @try {
        UIImage *im=iv.image;
        if(im&&im.renderingMode!=UIImageRenderingModeAlwaysTemplate){
            UIImage *tpl=[im imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            if(tpl){ gADPersonOriginalImageWriting7218=YES; iv.image=tpl; gADPersonOriginalImageWriting7218=NO; }
        }
        iv.tintColor=ADLightText706();
    } @catch(...) { gADPersonOriginalImageWriting7218=NO; }
}

// v7.257 menu raster split from the captured hierarchy:
//   1 = authored small raster, restore stock fill and never tame
//   2 = monochrome disclosure/control glyph, template + light tint and never tame
//   3 = featured-program artwork, restore stock fill and allow the TWB preference
//   4 = expanded subtheme/dropdown artwork, restore stock fill and allow TWB
// RNSVG views are not UIImageViews and remain completely outside this path.
static const void *kADMenuFinalRasterKind7255=&kADMenuFinalRasterKind7255;
static BOOL gADMenuImageWrite7255=NO;
static UIView *ADMenuImageAncestor7255(UIView *v,BOOL (^match)(NSString *),int maxDepth){
    return ADMenuAncestorMatching7255(v,match,maxDepth);
}
// v7.257: the footer helper row at the bottom of the Hamburger page is an
// anonymous 406x~23 RCTView with exactly two children: a leading ~22pt
// RCTImageView and a wide RCTTextView.  The v7.256 probe shows the leading
// image has real 54x60 raster contents but was forced to AlwaysTemplate,
// collapsing its authored artwork into the blank white circle seen on device.
// Restore only this exact leading raster.  The trailing account/person glyph
// lives inside the text view and does not satisfy this structure.
static BOOL ADMenuFooterLeadingRaster7257(UIImageView *iv){
    if(!iv||!iv.window||!iv.image)return NO;
    @try {
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<18.0||w>25.0||h<18.0||h>25.0)return NO;
        UIView *wrap=iv.superview;
        if(!wrap||!ADClassNameIs7183(wrap,"RCTImageView"))return NO;
        UIView *row=wrap.superview;
        if(!row||!ADClassNameIs7183(row,"RCTView")||row.subviews.count!=2)return NO;
        CGFloat rw=row.bounds.size.width,rh=row.bounds.size.height;
        if(rw<398.0||rw>414.0||rh<18.0||rh>29.0)return NO;
        CGRect local=[wrap convertRect:wrap.bounds toView:row];
        if(CGRectGetMinX(local)>5.0||CGRectGetWidth(local)>26.0)return NO;
        BOOL wideText=NO;
        for(UIView *c in row.subviews){
            if(c==wrap)continue;
            if(ADClassNameIs7183(c,"RCTTextView")&&c.bounds.size.width>=320.0){ wideText=YES; break; }
        }
        return wideText;
    } @catch(...) { return NO; }
}
static int ADMenuImageKind7255(UIImageView *iv,BOOL discover){
    if(!iv||!gP.enabled||!iv.window||!iv.image)return 0;
    @try {
        NSNumber *cached=objc_getAssociatedObject(iv,kADMenuFinalRasterKind7255);
        if(cached&&cached.intValue>0)return cached.intValue;
        if(!discover)return 0;
        if(!ADClassNameIs7183(iv,"RCTUIImageViewAnimated")||!ADMenuRoot7255(iv))return 0;
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height; int kind=0;
        if(ADMenuImageAncestor7255(iv,^BOOL(NSString *a){ return [a hasPrefix:@"featured-programs-tile-image_"]; },7))kind=3;
        else if(ADMenuImageAncestor7255(iv,^BOOL(NSString *a){ return [a hasPrefix:@"subtheme_image_"]; },7))kind=4;
        else if(ADMenuFooterLeadingRaster7257(iv))kind=1;
        else if(ADMenuImageAncestor7255(iv,^BOOL(NSString *a){ return [a hasPrefix:@"image_menu_item_pill_"]; },7))kind=1;
        else if(ADMenuImageAncestor7255(iv,^BOOL(NSString *a){
            return ADMenuFooterActionAid7255(a);
        },7))kind=(w<=28.0&&h<=28.0)?2:1;
        else if(ADMenuImageAncestor7255(iv,^BOOL(NSString *a){ return [a isEqualToString:@"theme_card_content_view_test_id"]; },6))
            kind=(w<=24.0&&h<=24.0)?2:((w>=28.0&&h>=28.0&&w<=64.0&&h<=64.0)?1:0);
        if(kind>0)objc_setAssociatedObject(iv,kADMenuFinalRasterKind7255,@(kind),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        else objc_setAssociatedObject(iv,kADMenuFinalRasterKind7255,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return kind;
    } @catch(...) { return 0; }
}
static void ADMenuRemoveTWB7255(UIImageView *iv){
    if(!iv)return;
    @try {
        CALayer *ov=objc_getAssociatedObject(iv,kADTWBOverlay);
        if(ov){ [ov removeFromSuperlayer]; objc_setAssociatedObject(iv,kADTWBOverlay,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        objc_setAssociatedObject(iv,kADTWBEligibilityImage,iv.image,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(iv,kADTWBEligibility,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}
static void ADMenuFinalizeImage7255(UIImageView *iv,BOOL discover){
    int kind=ADMenuImageKind7255(iv,discover); if(!kind||!iv.image)return;
    @try {
        UIImage *im=iv.image;
        UIImageRenderingMode want=(kind==2)?UIImageRenderingModeAlwaysTemplate:UIImageRenderingModeAlwaysOriginal;
        if(im.renderingMode!=want&&!gADMenuImageWrite7255){
            UIImage *fixed=[im imageWithRenderingMode:want];
            if(fixed){ gADMenuImageWrite7255=YES; iv.image=fixed; gADMenuImageWrite7255=NO; im=iv.image; }
        }
        if(kind==2)iv.tintColor=ADLightText706();
        if(kind==3||kind==4){
            objc_setAssociatedObject(iv,kADTWBEligibilityImage,im,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(iv,kADTWBEligibility,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if(gP.enabled&&gP.whiteTame&&iv.window){
                if(kind==4)ADEnsureNativeTWBOverlay7270(iv);
                else ADApplyNativeTWBCached7183(iv,NO);
            } else ADMenuRemoveTWB7255(iv);
        } else ADMenuRemoveTWB7255(iv);
    } @catch(...) { gADMenuImageWrite7255=NO; }
}
static BOOL ADMenuControlImageWrapper7255(UIView *v){
    if(!v||!v.window||!ADClassNameIs7183(v,"RCTImageView")||!ADInMenuTab7255(v))return NO;
    @try {
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w>24.0||h>24.0)return NO;
        if(ADMenuAncestorMatching7255(v,^BOOL(NSString *a){ return [a isEqualToString:@"theme_card_content_view_test_id"]; },6))return YES;
        return ADMenuAncestorMatching7255(v,^BOOL(NSString *a){
            return ADMenuFooterActionAid7255(a);
        },6)!=nil;
    } @catch(...) { return NO; }
}
static void ADMenuOwnImageWrapper7255(UIView *v){
    if(!gP.enabled||!v||!v.window||!ADInMenuTab7255(v))return;
    @try {
        if(ADMenuControlImageWrapper7255(v))v.tintColor=ADLightText706();
    } @catch(...) {}
}

static void ADOwnImageView7226(UIImageView *iv,BOOL resetCache){
    if(!iv)return;
    if(resetCache){
        objc_setAssociatedObject(iv,kADTWBEligibility,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(iv,kADTWBEligibilityImage,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    BOOL authored=ADInAuthoredVisualSubNav7175((UIView *)iv);
    if(gP.enabled&&iv.window&&ADInPersonTab7206((UIView *)iv)){ ADPersonRestoreOriginalImage7218(iv); ADPersonRestoreProbeBackedOriginal7229(iv); }
    BOOL personArrow=gP.enabled&&iv.window&&ADPersonRightArrow7231(iv);
    if(gP.enabled&&iv.window&&!authored){
        ADTabImageWhite724(iv);
        ADTintSearchGlyph706(iv);
        ADTintSearchDeliveryGlyph7139(iv);
        ADPersonOwnTopChromeGlyph7217(iv);
        ADPersonOwnSectionChevron7217(iv);
    }
    if(personArrow){
        // A right-arrow control must own no media overlay. Clear both possible
        // overlay lanes after forcing the image to template/light.
        ADPersonApplyExactHighlightTWB7221(iv);
        ADApplyNativeTWBCached7183(iv,authored);
    } else if(ADPersonExactHighlightImage7221(iv))ADPersonApplyExactHighlightTWB7221(iv);
    else if(ADPersonHighlightImageContext7224(iv)){
        CALayer *old=objc_getAssociatedObject(iv,kADTWBOverlay);
        if(old){ [old removeFromSuperlayer]; objc_setAssociatedObject(iv,kADTWBOverlay,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    } else if(iv.window)ADApplyNativeTWBCached7183(iv,authored);
    if(gP.enabled&&iv.window)ADMenuFinalizeImage7255(iv,YES);
}
static void ADLayoutImageOverlays7226(UIImageView *iv){
    if(!iv)return;
    @try {
        CALayer *twb=objc_getAssociatedObject(iv,kADTWBOverlay);
        if(twb)twb.frame=iv.bounds;
        CALayer *highlight=objc_getAssociatedObject(iv,kADPersonHighlightImageOverlay7221);
        if(highlight){ highlight.frame=iv.bounds; highlight.cornerRadius=iv.layer.cornerRadius; }
    } @catch(...) {}
}

static const void *kADPersonImageSettle7227=&kADPersonImageSettle7227;
static void ADSchedulePersonImageSettle7227(UIImageView *iv){
    if(!gP.enabled||!iv||!iv.window||!ADInPersonTab7206((UIView *)iv))return;
    @try {
        if(objc_getAssociatedObject(iv,kADPersonImageSettle7227))return;
        objc_setAssociatedObject(iv,kADPersonImageSettle7227,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UIImageView *weakIV=iv;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.08*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            UIImageView *strongIV=weakIV;
            if(!strongIV)return;
            objc_setAssociatedObject(strongIV,kADPersonImageSettle7227,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if(!gP.enabled||!strongIV.window||!ADInPersonTab7206((UIView *)strongIV))return;
            // One post-hydration correction replaces v7.224's every-layout classifier.
            // React now has its final section ancestry, so authored/template restoration
            // and TWB eligibility are resolved once without a scrolling hot path.
            ADOwnImageView7226(strongIV,YES);
            ADLayoutImageOverlays7226(strongIV);
        });
    } @catch(...) {}
}

%hook UIImageView
- (void)setImage:(UIImage *)image {
    if(gADTabImageWriting724||gADPersonOriginalImageWriting7218||gADSearchImageWrite706||gADPersonOrderMagnifierWrite7243||gADMenuImageWrite7255){
        %orig(image);
        return;
    }
    objc_setAssociatedObject(self,kADMenuFinalRasterKind7255,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // v7.263: React/FastImage may recycle this leaf across refresh hydration.
    // Never let a prior surface classification suppress the new Person ancestry.
    objc_setAssociatedObject(self,kADReactSurfaceCache7232,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIImage *finalImage=image;
    if(gP.enabled&&image&&ADSearchLeadingMagnifier7229(self)&&image.renderingMode!=UIImageRenderingModeAlwaysTemplate){
        UIImage *tpl=[image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]; if(tpl)finalImage=tpl;
    }
    if(gP.enabled&&finalImage&&ADPersonOrderSearchMagnifierLeaf7243(self)&&finalImage.renderingMode!=UIImageRenderingModeAlwaysTemplate){
        UIImage *tpl=[finalImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]; if(tpl)finalImage=tpl;
    }
    %orig(finalImage);
    ADOwnSearchLeadingMagnifier7229(self);
    ADPersonOwnOrderSearchMagnifierLeaf7243(self);
    ADOwnImageView7226(self,YES);
    ADSchedulePersonImageSettle7227(self);
    ADApplyCNMExactDogTWB7309(self);
}
- (void)didMoveToWindow {
    %orig;
    objc_setAssociatedObject(self,kADMenuFinalRasterKind7255,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,kADReactSurfaceCache7232,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ADOwnSearchLeadingMagnifier7229(self);
    ADPersonOwnOrderSearchMagnifierLeaf7243(self);
    ADOwnImageView7226(self,YES);
    ADSchedulePersonImageSettle7227(self);
    ADApplyCNMExactDogTWB7309(self);
}
- (void)didMoveToSuperview {
    %orig;
    objc_setAssociatedObject(self,kADMenuFinalRasterKind7255,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,kADReactSurfaceCache7232,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(self.window){
        ADOwnSearchLeadingMagnifier7229(self);
        ADPersonOwnOrderSearchMagnifierLeaf7243(self);
        ADOwnImageView7226(self,YES);
        ADSchedulePersonImageSettle7227(self);
    }
    ADApplyCNMExactDogTWB7309(self);
}
- (void)setTintColor:(UIColor *)color {
    if(gP.enabled && ADInAuthoredVisualSubNav7175((UIView *)self)){
        %orig(color);
        return;
    }
    if(gP.enabled&&self.window){
        int menuKind=ADMenuImageKind7255(self,YES);
        if(menuKind==2){
            UIColor *menuLight=ADLightText706();
            %orig(menuLight);
            return;
        }
        if(menuKind==1||menuKind==3){
            %orig(color);
            return;
        }
        if(ADPersonOrderSearchMagnifierLeaf7243(self)){
            UIColor *light=ADLightText706();
            %orig(light);
            return;
        }
        if(ADInPersonTab7206((UIView *)self)&&ADPersonSectionKind7218((UIView *)self)==1){
            %orig(color);
            return;
        }
        if(ADPersonTopChromeGlyph7217(self)||ADPersonSectionChevron7217(self)){
            UIColor *light=ADLightText706();
            %orig(light);
            return;
        }
        CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
        if(w>1.0&&h>1.0&&w<=100.0&&h<=100.0){
            if(ADANXTabRoot724(self)){
                UIColor *light=ADLightText706();
                %orig(light);
                return;
            }
            if(ADInMarkedSearchDeliveryBand7139(self)||ADInSearchChrome706(self)||ADIsLocationGlyph709(self)||ADIsSearchBackGlyph7120(self)){
                UIColor *light=ADLightText706();
                %orig(light);
                return;
            }
        }
    }
    %orig(color);
}
- (void)layoutSubviews {
    %orig;
    // React rewrites rendering mode after assignment for these five exact visible
    // owners. Reassert only those small components at final layout; product/media
    // classification outside them remains off the scrolling hot path.
    if(objc_getAssociatedObject(self,kADSearchLeadingMagnifier7229)||ADSearchLeadingMagnifier7229(self))ADOwnSearchLeadingMagnifier7229(self);
    ADPersonOwnOrderSearchMagnifierLeaf7243(self);
    if(ADPersonRightArrow7231(self)||ADPersonMedicalAuthoredIcon7231(self)||
       ADPersonReviewCompactImage7229(self)||ADPersonCustomerServiceLeadingImage7229(self))
        ADOwnImageView7226(self,YES);
    ADMenuFinalizeImage7255(self,objc_getAssociatedObject(self,kADMenuFinalRasterKind7255)==nil);
    ADLayoutImageOverlays7226(self);
    ADApplyCNMExactDogTWB7309(self);
}
%end

// v7.235: React's actual Person raster leaf remains RCTUIImageViewAnimated.
// Extend v7.234's cached final-paint owner only to the additional probe-proven
// Subscribe/Previously-Watched rasters and the Highlights blue-circle arrow.
static const void *kADPersonFinalRasterKind7235=&kADPersonFinalRasterKind7235;
static int ADPersonFinalRasterKind7235(UIImageView *iv,BOOL discover){
    if(!iv||!gP.enabled||!iv.window||!ADInPersonTab7206((UIView *)iv))return 0;
    @try {
        NSNumber *cached=objc_getAssociatedObject(iv,kADPersonFinalRasterKind7235);
        if(cached&&cached.intValue>0)return cached.intValue;
        if(!discover)return 0;
        int kind=0;
        if(ADPersonMedicalAuthoredIcon7231(iv))kind=1;
        else if(ADPersonReviewCompactImage7229(iv))kind=2;
        else if(ADPersonCustomerServiceLeadingImage7229(iv))kind=3;
        else if(ADPersonSubscribeImage7235(iv))kind=4;
        else if(ADPersonPreviouslyWatchedImage7235(iv))kind=5;
        else if(ADPersonHighlightArrowLeaf7235(iv))kind=6;
        else if(ADPersonAvatarImage7237(iv))kind=7;
        else if(ADPersonNotificationBadge7237(iv))kind=8;
        else if(ADPersonCountryFlag7237(iv))kind=9;
        else if(ADPersonOfflineErrorRaster7299(iv))kind=10;
        if(kind>0)objc_setAssociatedObject(iv,kADPersonFinalRasterKind7235,@(kind),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        else objc_setAssociatedObject(iv,kADPersonFinalRasterKind7235,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return kind;
    } @catch(...) { return 0; }
}
static const void *kADPersonOfflineErrorMask7300=&kADPersonOfflineErrorMask7300;
static void ADPersonClearOfflineErrorMask7300(UIImageView *iv){
    if(!iv||!objc_getAssociatedObject(iv,kADPersonOfflineErrorMask7300))return;
    @try {
        iv.layer.cornerRadius=0.0;
        iv.layer.masksToBounds=NO;
        objc_setAssociatedObject(iv,kADPersonOfflineErrorMask7300,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}
static void ADPersonApplyOfflineErrorMask7300(UIImageView *iv){
    if(!iv)return;
    @try {
        CGFloat d=MIN(iv.bounds.size.width,iv.bounds.size.height);
        if(d<=1.0)return;
        iv.layer.cornerRadius=d*0.5;
        iv.layer.masksToBounds=YES;
        objc_setAssociatedObject(iv,kADPersonOfflineErrorMask7300,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}
static void ADPersonFinalizePersonImage7235(UIImageView *iv,BOOL discover){
    if(!iv)return;
    int kind=ADPersonFinalRasterKind7235(iv,discover);
    if(!kind||!iv.image){ ADPersonClearOfflineErrorMask7300(iv); return; }
    @try {
        if(kind==10)ADPersonApplyOfflineErrorMask7300(iv);
        else ADPersonClearOfflineErrorMask7300(iv);
        UIImage *im=iv.image;
        if(kind==6){
            if(im.renderingMode!=UIImageRenderingModeAlwaysTemplate&&!gADPersonOriginalImageWriting7218){
                UIImage *tpl=[im imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                if(tpl){ gADPersonOriginalImageWriting7218=YES; iv.image=tpl; gADPersonOriginalImageWriting7218=NO; }
            }
            iv.tintColor=ADLightText706();
            CALayer *hov=objc_getAssociatedObject(iv,kADPersonHighlightImageOverlay7221);
            if(hov){ [hov removeFromSuperlayer]; objc_setAssociatedObject(iv,kADPersonHighlightImageOverlay7221,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            CALayer *twb=objc_getAssociatedObject(iv,kADTWBOverlay);
            if(twb){ [twb removeFromSuperlayer]; objc_setAssociatedObject(iv,kADTWBOverlay,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            objc_setAssociatedObject(iv,kADTWBEligibilityImage,iv.image,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(iv,kADTWBEligibility,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else {
            if(im.renderingMode!=UIImageRenderingModeAlwaysOriginal&&!gADPersonOriginalImageWriting7218){
                UIImage *orig=[im imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
                if(orig){ gADPersonOriginalImageWriting7218=YES; iv.image=orig; gADPersonOriginalImageWriting7218=NO; }
            }
            if(kind==1||kind==7||kind==8||kind==9||kind==10){
                CALayer *ov=objc_getAssociatedObject(iv,kADTWBOverlay);
                if(ov){ [ov removeFromSuperlayer]; objc_setAssociatedObject(iv,kADTWBOverlay,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
                objc_setAssociatedObject(iv,kADTWBEligibilityImage,iv.image,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(iv,kADTWBEligibility,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else {
                ADResetNativeTWBCache7214(iv);
                ADApplyNativeTWBCached7183(iv,NO);
            }
        }
        ADLayoutImageOverlays7226(iv);
    } @catch(...) { gADPersonOriginalImageWriting7218=NO; }
}

// v7.285 Alexa suggestion-card media split from the v7.282 probe.
// The exact wrapper contains three 40x40 rasters: row 0 is authored palette artwork
// and is explicitly blocked from TWB; rows 1 and 2 alone receive the configured TWB.
static const void *kADAlexaSuggestionIndex7285=&kADAlexaSuggestionIndex7285;
static UIView *ADAlexaSuggestionWrapper7285(UIView *v){
    if(!v)return nil;
    @try {
        for(UIView *n=v;n&&n!=v.window;n=n.superview){
            NSString *aid=n.accessibilityIdentifier?:@"";
            if([aid hasPrefix:@"in-view-wrapper-ftuxRuxSuggestionCardList-"])return n;
        }
    } @catch(...) {}
    return nil;
}
static int ADAlexaSuggestionImageIndex7285(UIImageView *iv,BOOL discover){
    if(!iv||!iv.window||!iv.image||!ADClassNameIs7183(iv,"RCTUIImageViewAnimated"))return -1;
    @try {
        NSNumber *cached=objc_getAssociatedObject(iv,kADAlexaSuggestionIndex7285);
        if(cached)return cached.intValue-1;
        if(!discover)return -1;
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<36.0||w>44.0||h<36.0||h>44.0||fabs(w-h)>3.0)return -1;
        UIView *wrapper=ADAlexaSuggestionWrapper7285(iv); if(!wrapper)return -1;
        NSMutableArray<UIImageView *> *images=[NSMutableArray array];
        NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:wrapper]; NSUInteger seen=0;
        while(seen<q.count&&seen<96){
            UIView *x=q[seen++]; if(!x)continue;
            if(ADClassNameIs7183(x,"RCTUIImageViewAnimated")){
                CGFloat xw=x.bounds.size.width,xh=x.bounds.size.height;
                if(xw>=36.0&&xw<=44.0&&xh>=36.0&&xh<=44.0&&fabs(xw-xh)<=3.0)[images addObject:(UIImageView *)x];
            }
            if(x.subviews.count&&q.count-seen<96)[q addObjectsFromArray:x.subviews];
        }
        if(images.count!=3)return -1;
        [images sortUsingComparator:^NSComparisonResult(UIImageView *a,UIImageView *b){
            CGFloat ay=[a convertRect:a.bounds toView:nil].origin.y,by=[b convertRect:b.bounds toView:nil].origin.y;
            if(ay<by)return NSOrderedAscending; if(ay>by)return NSOrderedDescending; return NSOrderedSame;
        }];
        NSUInteger pos=[images indexOfObjectIdenticalTo:iv]; if(pos==NSNotFound||pos>2)return -1;
        objc_setAssociatedObject(iv,kADAlexaSuggestionIndex7285,@((int)pos+1),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return (int)pos;
    } @catch(...) { return -1; }
}
static void ADAlexaFinalizeSuggestionImage7285(UIImageView *iv,BOOL discover){
    int idx=ADAlexaSuggestionImageIndex7285(iv,discover); if(idx<0)return;
    @try {
        CALayer *ov=objc_getAssociatedObject(iv,kADTWBOverlay);
        if(idx==0||!gP.enabled||!gP.whiteTame||!iv.window){
            if(ov){ [ov removeFromSuperlayer]; objc_setAssociatedObject(iv,kADTWBOverlay,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            objc_setAssociatedObject(iv,kADTWBEligibilityImage,iv.image,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(iv,kADTWBEligibility,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        objc_setAssociatedObject(iv,kADTWBEligibilityImage,iv.image,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(iv,kADTWBEligibility,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADEnsureNativeTWBOverlay7270(iv);
        ADLayoutImageOverlays7226(iv);
    } @catch(...) {}
}

%hook RCTUIImageViewAnimated
- (void)setImage:(UIImage *)image {
    if(gADPersonOriginalImageWriting7218||gADMenuImageWrite7255){
        %orig(image);
        return;
    }
    objc_setAssociatedObject(self,kADPersonFinalRasterKind7235,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,kADMenuFinalRasterKind7255,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,kADAlexaSuggestionIndex7285,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,kADReactSurfaceCache7232,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    %orig(image);
    ADPersonFinalizePersonImage7235((UIImageView *)self,YES);
    ADMenuFinalizeImage7255((UIImageView *)self,YES);
    ADAlexaFinalizeSuggestionImage7285((UIImageView *)self,YES);
}
- (void)didMoveToSuperview {
    objc_setAssociatedObject(self,kADPersonFinalRasterKind7235,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,kADMenuFinalRasterKind7255,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,kADAlexaSuggestionIndex7285,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,kADReactSurfaceCache7232,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    %orig;
    if(((UIView *)self).window){
        ADPersonFinalizePersonImage7235((UIImageView *)self,YES);
        ADMenuFinalizeImage7255((UIImageView *)self,YES);
        ADAlexaFinalizeSuggestionImage7285((UIImageView *)self,YES);
    }
}
- (void)didMoveToWindow {
    %orig;
    objc_setAssociatedObject(self,kADReactSurfaceCache7232,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(((UIView *)self).window){
        ADPersonFinalizePersonImage7235((UIImageView *)self,YES);
        ADMenuFinalizeImage7255((UIImageView *)self,YES);
        ADAlexaFinalizeSuggestionImage7285((UIImageView *)self,YES);
    } else {
        objc_setAssociatedObject(self,kADPersonFinalRasterKind7235,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self,kADMenuFinalRasterKind7255,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self,kADAlexaSuggestionIndex7285,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
- (void)layoutSubviews {
    %orig;
    NSNumber *cached=objc_getAssociatedObject(self,kADPersonFinalRasterKind7235);
    ADPersonFinalizePersonImage7235((UIImageView *)self,(cached&&cached.intValue>0)?NO:YES);
    NSNumber *menuCached=objc_getAssociatedObject(self,kADMenuFinalRasterKind7255);
    ADMenuFinalizeImage7255((UIImageView *)self,(menuCached&&menuCached.intValue>0)?NO:YES);
    ADAlexaFinalizeSuggestionImage7285((UIImageView *)self,objc_getAssociatedObject(self,kADAlexaSuggestionIndex7285)==nil);
}
%end

// Exact Highlights semantic wrapper owner. Most tiles expose an anonymous
// RCTUIImageViewAnimated child and keep the v7.224 image-leaf TWB path. The probe
// shows the first visible tile can instead expose only its RCTImageView wrapper, so
// this hook shades that exact wrapper only while it lacks a raster UIImageView child.
%hook RCTImageView
- (void)didMoveToWindow {
    %orig;
    objc_setAssociatedObject(self,kADReactSurfaceCache7232,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(ADPersonOrderSearchMagnifierWrapper7243((UIView *)self))((UIView *)self).tintColor=ADLightText706();
    ADPersonOwnHighlightWrapper7229((UIView *)self);
    ADMenuOwnImageWrapper7255((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    if(ADPersonOrderSearchMagnifierWrapper7243((UIView *)self)){
        ((UIView *)self).tintColor=ADLightText706();
        for(UIView *child in ((UIView *)self).subviews)if([child isKindOfClass:[UIImageView class]])ADPersonOwnOrderSearchMagnifierLeaf7243((UIImageView *)child);
    }
    ADPersonOwnHighlightWrapper7229((UIView *)self);
    ADMenuOwnImageWrapper7255((UIView *)self);
}
- (void)setTintColor:(UIColor *)color {
    if(gP.enabled&&((UIView *)self).window&&ADPersonOrderSearchMagnifierWrapper7243((UIView *)self)){
        UIColor *light=ADLightText706();
        %orig(light);
        return;
    }
    if(gP.enabled&&((UIView *)self).window&&ADMenuControlImageWrapper7255((UIView *)self)){
        UIColor *menuLight=ADLightText706();
        %orig(menuLight);
        return;
    }
    %orig(color);
}
%end

// -----------------------------------------------------------------------------
// v7.336 launch hooks are owned by the exact Amazon splash controllers and the
// bounded Home-readiness gate above; no additional launch owner is declared here.
// -----------------------------------------------------------------------------


%group ADPrivacyHooks7271
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

%end

static BOOL gADPrivacyHooksInstalled7271=NO;
static void ADInstallPrivacyHooks7271(void){
    if(gADPrivacyHooksInstalled7271)return;
    gADPrivacyHooksInstalled7271=YES;
    %init(ADPrivacyHooks7271);
}

static BOOL gADMainHooksInstalled7271=NO;
static void ADInstallMainHooks7271(void){
    if(gADMainHooksInstalled7271)return;
    gADMainHooksInstalled7271=YES;
    %init;
}



// v7.255: keep all Logos directives above every probe implementation.
// One shared explicit-trigger dispatcher selects Cart, Person, or Hamburger/Menu at runtime.
static void ADInstallThreeTabProbes7254(void);

static void ADPrefsChanged(CFNotificationCenterRef c,void *o,CFStringRef n,const void *obj,CFDictionaryRef ui){
    BOOL wasPrivacy=gP.privacyMode;
    ADLoadPrefs();
    if(gP.enabled){ ADInstallMainHooks7271(); ADInstallThreeTabProbes7254(); }
    if(gP.enabled&&gP.force120Hz)ADInstallPromotionHooks7271();
    if(gP.enabled&&gP.privacyMode)ADInstallPrivacyHooks7271();
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
    ADLaunchAppProbeLog7317(@"Amazon.ctor",[NSString stringWithFormat:@"version=%s",AD_VERSION]);
    ADLoadPrefs();
    ADInstallLaunchLifecycleLogger7336();
    if(gP.enabled)ADInstallMainHooks7271();
    if(gP.enabled&&gP.force120Hz)ADInstallPromotionHooks7271();
    if(gP.enabled){
        ADInstallThreeTabProbes7254();
    }
    if(gP.enabled&&gP.privacyMode){
        ADInstallPrivacyHooks7271();
        ADRegisterPrivacyProtocol7117();
        ADCompilePrivacyContentRules7117();
    }

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,ADPrefsChanged,
        CFSTR("com.colindavidr.amazondark/prefs-changed"),NULL,CFNotificationSuspensionBehaviorCoalesce);
    ADRefreshRuntimeState7115(NO);
}


// v7.255: Retained Person UI forensics probe. It shares one explicit screenshot/SIGUSR2
// dispatcher with Cart and Hamburger/Menu, and remains dormant outside a matching active tab. This subsystem is completely dormant until the user
// explicitly takes a screenshot or sends SIGUSR2. It never alters Person visual ownership.
// A trigger temporarily walks only the exact React Person scroll surface top-to-bottom,
// allowing lazy/recycled nodes to hydrate, snapshots native/React text, glyph, border,
// layer, hierarchy and current AmazonDark classifier state, then restores the original offset.
static NSUInteger gADPersonProbeRun7233=0;
static BOOL gADPersonProbeBusy7233=NO;
static const unsigned long long kADPersonProbeCap7233=64ULL*1024ULL*1024ULL;

static NSString *ADProbeSafe7233(NSString *x){
    if(!x.length)return @"";
    @try {
        NSString *s=[x stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        s=[s stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        s=[s stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        s=[s stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
        if(s.length>180)s=[[s substringToIndex:180] stringByAppendingString:@"…"];
        return s;
    } @catch(...) { return @"?"; }
}
static NSString *ADProbeColor7233(UIColor *c){
    if(!c)return @"nil";
    @try {
        CGFloat r=0,g=0,b=0,a=0,w=0;
        if([c getRed:&r green:&g blue:&b alpha:&a])return [NSString stringWithFormat:@"rgba(%.3f,%.3f,%.3f,%.3f)",r,g,b,a];
        if([c getWhite:&w alpha:&a])return [NSString stringWithFormat:@"white(%.3f,%.3f)",w,a];
        return [NSString stringWithFormat:@"%@",c];
    } @catch(...) { return @"?"; }
}
static NSString *ADProbeCG7233(CGColorRef c){
    if(!c)return @"nil";
    @try { return ADProbeColor7233([UIColor colorWithCGColor:c]); } @catch(...) { return @"?"; }
}
static NSString *ADProbeChain7233(UIView *v){
    NSMutableArray<NSString *> *a=[NSMutableArray array];
    @try {
        UIView *n=v;
        for(int d=0;n&&d<10;d++,n=n.superview){
            NSString *cn=NSStringFromClass(n.class)?:@"?";
            NSString *aid=ADProbeSafe7233(n.accessibilityIdentifier);
            [a addObject:aid.length?[NSString stringWithFormat:@"%@#%@",cn,aid]:cn];
            if([n.accessibilityIdentifier isEqualToString:@"me"]&&ADClassNameIs7183(n,"RCTScrollView"))break;
        }
    } @catch(...) {}
    return [a componentsJoinedByString:@"<-"];
}
static NSString *ADProbeText7233(UIView *v){
    if(!v)return @"text=0";
    @try {
        NSTextStorage *ts=ADPersonTextStorage7206(v);
        if(ts&&ts.length){
            NSMutableArray<NSString *> *runs=[NSMutableArray array]; NSRange whole=NSMakeRange(0,ts.length);
            [ts enumerateAttributesInRange:whole options:0 usingBlock:^(NSDictionary *attrs,NSRange range,BOOL *stop){
                if(runs.count>=16){ *stop=YES; return; }
                UIColor *fg=attrs[NSForegroundColorAttributeName]; UIColor *bg=attrs[NSBackgroundColorAttributeName]; UIFont *font=attrs[NSFontAttributeName];
                NSNumber *ul=attrs[NSUnderlineStyleAttributeName],*st=attrs[NSStrikethroughStyleAttributeName],*kern=attrs[NSKernAttributeName];
                [runs addObject:[NSString stringWithFormat:@"%lu:%lu:fg=%@:bg=%@:font=%@/%.1f:primary=%d:ul=%@:st=%@:kern=%@",
                    (unsigned long)range.location,(unsigned long)range.length,ADProbeColor7233(fg),ADProbeColor7233(bg),font.fontName?:@"nil",font?font.pointSize:0.0,ADPersonPrimaryFont7206(font)?1:0,ul?:@0,st?:@0,kern?:@0]];
            }];
            return [NSString stringWithFormat:@"text=1 kind=rct len=%lu runs=[%@]",(unsigned long)ts.length,[runs componentsJoinedByString:@";"]];
        }
        if([v isKindOfClass:[UILabel class]]){
            UILabel *l=(UILabel *)v; NSMutableArray<NSString *> *runs=[NSMutableArray array]; NSAttributedString *at=l.attributedText;
            if(at.length){
                [at enumerateAttributesInRange:NSMakeRange(0,at.length) options:0 usingBlock:^(NSDictionary *attrs,NSRange range,BOOL *stop){
                    if(runs.count>=16){ *stop=YES; return; }
                    UIColor *fg=attrs[NSForegroundColorAttributeName]; UIColor *bg=attrs[NSBackgroundColorAttributeName]; UIFont *font=attrs[NSFontAttributeName];
                    [runs addObject:[NSString stringWithFormat:@"%lu:%lu:fg=%@:bg=%@:font=%@/%.1f",(unsigned long)range.location,(unsigned long)range.length,ADProbeColor7233(fg),ADProbeColor7233(bg),font.fontName?:@"nil",font?font.pointSize:0.0]];
                }];
            }
            return [NSString stringWithFormat:@"text=1 kind=label len=%lu color=%@ font=%@/%.1f lines=%ld align=%ld break=%ld adjusts=%d scale=%.2f runs=[%@]",
                (unsigned long)l.text.length,ADProbeColor7233(l.textColor),l.font.fontName?:@"nil",l.font.pointSize,(long)l.numberOfLines,(long)l.textAlignment,(long)l.lineBreakMode,l.adjustsFontSizeToFitWidth?1:0,l.minimumScaleFactor,[runs componentsJoinedByString:@";"]];
        }
    } @catch(...) {}
    NSString *cn=NSStringFromClass(v.class)?:@"";
    BOOL textish=[cn rangeOfString:@"Text" options:NSCaseInsensitiveSearch].location!=NSNotFound||[cn rangeOfString:@"Paragraph" options:NSCaseInsensitiveSearch].location!=NSNotFound;
    return textish?@"text=1 storage=none":@"text=0";
}
static NSString *ADProbeRCTEdges7233(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return @"rct=0";
    @try {
        const char *wn[]={"borderWidth","borderTopWidth","borderRightWidth","borderBottomWidth","borderLeftWidth","borderStartWidth","borderEndWidth"};
        const char *cn[]={"borderColor","borderTopColor","borderRightColor","borderBottomColor","borderLeftColor","borderStartColor","borderEndColor"};
        const char *rn[]={"borderRadius","borderTopLeftRadius","borderTopRightRadius","borderBottomLeftRadius","borderBottomRightRadius","borderTopStartRadius","borderTopEndRadius","borderBottomStartRadius","borderBottomEndRadius"};
        NSMutableArray *a=[NSMutableArray array];
        for(size_t i=0;i<sizeof(wn)/sizeof(*wn);i++){ SEL q=sel_registerName(wn[i]); if([v respondsToSelector:q]){ CGFloat x=((CGFloat(*)(id,SEL))objc_msgSend)(v,q); [a addObject:[NSString stringWithFormat:@"%s=%.2f",wn[i],x]]; } }
        for(size_t i=0;i<sizeof(cn)/sizeof(*cn);i++){ SEL q=sel_registerName(cn[i]); if([v respondsToSelector:q]){ id x=((id(*)(id,SEL))objc_msgSend)(v,q); [a addObject:[NSString stringWithFormat:@"%s=%@",cn[i],[x isKindOfClass:[UIColor class]]?ADProbeColor7233(x):[NSString stringWithFormat:@"%@",x]]]; } }
        for(size_t i=0;i<sizeof(rn)/sizeof(*rn);i++){ SEL q=sel_registerName(rn[i]); if([v respondsToSelector:q]){ CGFloat x=((CGFloat(*)(id,SEL))objc_msgSend)(v,q); [a addObject:[NSString stringWithFormat:@"%s=%.2f",rn[i],x]]; } }
        return [NSString stringWithFormat:@"rct=1 [%@]",[a componentsJoinedByString:@","]];
    } @catch(...) { return @"rct=1 err=1"; }
}
static NSString *ADProbeLayer7233(UIView *v){
    if(!v)return @"layers=0";
    @try {
        CALayer *root=v.layer; NSMutableArray<CALayer *> *q=[NSMutableArray arrayWithObject:root]; NSMutableArray<NSString *> *samples=[NSMutableArray array];
        NSUInteger seen=0,shape=0,grad=0,bordered=0,contents=0;
        while(q.count&&seen++<72){
            CALayer *l=q.firstObject; [q removeObjectAtIndex:0]; if(!l)continue;
            if(l.contents)contents++;
            BOOL interesting=(l==root)||l.borderWidth>0.01||l.backgroundColor||l.mask||[l isKindOfClass:[CAShapeLayer class]]||[l isKindOfClass:[CAGradientLayer class]]||l.shadowOpacity>0.001;
            if(l.borderWidth>0.01)bordered++;
            if([l isKindOfClass:[CAShapeLayer class]])shape++;
            if([l isKindOfClass:[CAGradientLayer class]])grad++;
            if(interesting&&samples.count<12){
                NSString *extra=@"";
                if([l isKindOfClass:[CAShapeLayer class]]){ CAShapeLayer *sh=(CAShapeLayer *)l; extra=[NSString stringWithFormat:@":shape(f=%@ s=%@ lw=%.2f dash=%@)",ADProbeCG7233(sh.fillColor),ADProbeCG7233(sh.strokeColor),sh.lineWidth,sh.lineDashPattern?:@[]]; }
                else if([l isKindOfClass:[CAGradientLayer class]]){ CAGradientLayer *g=(CAGradientLayer *)l; NSMutableArray *cs=[NSMutableArray array]; for(id c in g.colors?:@[]){ [cs addObject:ADProbeCG7233((__bridge CGColorRef)c)]; } extra=[NSString stringWithFormat:@":grad(%@)",[cs componentsJoinedByString:@"/"]]; }
                [samples addObject:[NSString stringWithFormat:@"%@ name=%@ f=(%.1f,%.1f %.1fx%.1f) bg=%@ bw=%.2f bc=%@ cr=%.2f op=%.2f z=%.1f mask=%d contents=%d shadow=%@/%.2f/%.2f%@",
                    NSStringFromClass(l.class),l.name?:@"nil",l.frame.origin.x,l.frame.origin.y,l.frame.size.width,l.frame.size.height,ADProbeCG7233(l.backgroundColor),l.borderWidth,ADProbeCG7233(l.borderColor),l.cornerRadius,l.opacity,l.zPosition,l.mask?1:0,l.contents?1:0,ADProbeCG7233(l.shadowColor),l.shadowOpacity,l.shadowRadius,extra]];
            }
            if(seen<52)for(CALayer *c in l.sublayers?:@[])[q addObject:c];
        }
        return [NSString stringWithFormat:@"layers=%lu shape=%lu grad=%lu bordered=%lu contents=%lu maskToBounds=%d samples=[%@]",(unsigned long)seen,(unsigned long)shape,(unsigned long)grad,(unsigned long)bordered,(unsigned long)contents,root.masksToBounds?1:0,[samples componentsJoinedByString:@" || "]];
    } @catch(...) { return @"layers=1 err=1"; }
}
static NSString *ADProbeImage7233(UIView *v){
    if(![v isKindOfClass:[UIImageView class]])return @"img=0";
    @try {
        UIImageView *iv=(UIImageView *)v; UIImage *im=iv.image; size_t pxw=0,pxh=0;
        if(im.CGImage){ pxw=CGImageGetWidth(im.CGImage); pxh=CGImageGetHeight(im.CGImage); }
        CALayer *twb=objc_getAssociatedObject(iv,kADTWBOverlay),*hl=objc_getAssociatedObject(iv,kADPersonHighlightImageOverlay7221);
        return [NSString stringWithFormat:@"img=1 has=%d mode=%ld pts=(%.1fx%.1f) px=(%zux%zu) scale=%.2f orient=%ld cap=(%.1f,%.1f,%.1f,%.1f) resize=%ld contentMode=%ld highlighted=%d anim=%d tint=%@ twb=%d hlTwb=%d topGlyph=%d arrow=%d chev=%d medical=%d review40=%d customer40=%d exactHL=%d hlCtx=%d explicit=%d forced12=%d forced18=%d blocked=%d final240=%d avatar=%d badge=%d flag=%d",
            im?1:0,(long)(im?im.renderingMode:-1),im?im.size.width:0.0,im?im.size.height:0.0,pxw,pxh,im?im.scale:0.0,(long)(im?im.imageOrientation:-1),
            im?im.capInsets.top:0.0,im?im.capInsets.left:0.0,im?im.capInsets.bottom:0.0,im?im.capInsets.right:0.0,(long)(im?im.resizingMode:-1),(long)iv.contentMode,iv.highlighted?1:0,iv.animationImages.count?1:0,ADProbeColor7233(iv.tintColor),twb?1:0,hl?1:0,
            ADPersonTopChromeGlyph7217(iv)?1:0,ADPersonRightArrow7231(iv)?1:0,ADPersonSectionChevron7217(iv)?1:0,ADPersonMedicalAuthoredIcon7231(iv)?1:0,ADPersonReviewCompactImage7229(iv)?1:0,ADPersonCustomerServiceLeadingImage7229(iv)?1:0,ADPersonExactHighlightImage7221(iv)?1:0,ADPersonHighlightImageContext7224(iv)?1:0,ADPersonExplicitProductMedia7206(iv)?1:0,ADPersonForcedMedia7212(iv)?1:0,ADPersonForcedMedia7218(iv)?1:0,ADPersonMediaBlocked7206(iv)?1:0,ADPersonFinalRasterKind7235(iv,YES),ADPersonAvatarImage7237(iv)?1:0,ADPersonNotificationBadge7237(iv)?1:0,ADPersonCountryFlag7237(iv)?1:0];
    } @catch(...) { return @"img=1 err=1"; }
}
static NSString *ADProbeControl7233(UIView *v){
    @try {
        if([v isKindOfClass:[UIControl class]]){ UIControl *c=(UIControl *)v; return [NSString stringWithFormat:@"control=1 enabled=%d selected=%d highlighted=%d state=%lu",c.enabled?1:0,c.selected?1:0,c.highlighted?1:0,(unsigned long)c.state]; }
        if([v isKindOfClass:[UIScrollView class]]){ UIScrollView *sv=(UIScrollView *)v; return [NSString stringWithFormat:@"scroll=1 offset=(%.1f,%.1f) content=(%.1fx%.1f) inset=(%.1f,%.1f,%.1f,%.1f) enabled=%d hInd=%d vInd=%d style=%ld",sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height,sv.adjustedContentInset.top,sv.adjustedContentInset.left,sv.adjustedContentInset.bottom,sv.adjustedContentInset.right,sv.scrollEnabled?1:0,sv.showsHorizontalScrollIndicator?1:0,sv.showsVerticalScrollIndicator?1:0,(long)sv.indicatorStyle]; }
    } @catch(...) {}
    return @"control=0";
}
static NSString *ADProbeClassifiers7233(UIView *v){
    if(!v)return @"classifiers=none";
    @try {
        BOOL image=[v isKindOfClass:[UIImageView class]]; UIImageView *iv=image?(UIImageView *)v:nil;
        CALayer *buy=objc_getAssociatedObject(v,kADPersonBuyAgainOutline7218),*plate=objc_getAssociatedObject(v,kADPersonHighlightPlateOverlay7212),*wrap=objc_getAssociatedObject(v,kADPersonHighlightWrapperOverlay7229),*review=objc_getAssociatedObject(v,kADPersonReviewOutline7231);
        return [NSString stringWithFormat:@"classifiers outer=%d inner=%d carOuter=%d carInner=%d sec=%d buyItem=%d buyWrap=%d topPill=%d shell=%d header=%d titleBand=%d textFix=%d hlTile=%d hlPlate=%d reviewPlate=%d hlWrap=%d fix240(list=%d interest=%d medicalCard=%d orderCard=%d buyOverlay=%d buyPrimary=%d subscribeOverlay=%d keepText=%d buyOuter=%d interestTitle=%d highlightArrow=%d nestedList=%d) ownOverlay(buy=%d plate=%d wrap=%d review=%d)%@",
            ADPersonOuterCardFloor7213(v)?1:0,ADPersonInternalMediaPlate7213(v)?1:0,ADPersonCarouselOuter7214(v)?1:0,ADPersonInsideCarouselOuter7214(v)?1:0,ADPersonSectionKind7218(v),ADPersonBuyAgainItem7218(v)?1:0,ADPersonBuyAgainWrapper7218(v)?1:0,ADPersonTopMenuPill7208(v)?1:0,ADPersonBorderOnlyShell7227(v)?1:0,ADPersonHeaderLeaf7221(v)?1:0,ADPersonHeadingBandGeometry7221(v)?1:0,ADPersonFinalTextOwner7239(v)?1:0,ADPersonHighlightTile7224(v)?1:0,ADPersonHighlightPlate7212(v)?1:0,ADPersonReviewBorderPlate7231(v)?1:0,ADPersonHighlightWrapperOwner7229(v)?1:0,
            ADPersonListCard7235(v)?1:0,ADPersonInterestBorderPlate7235(v)?1:0,
            ([(v.accessibilityIdentifier?:@"").lowercaseString isEqualToString:@"yhw_healthai_0"]||[(v.accessibilityIdentifier?:@"").lowercaseString isEqualToString:@"yhw_pharmacy_1"])?1:0,
            [(v.accessibilityIdentifier?:@"").lowercaseString isEqualToString:@"yo_btn"]?1:0,ADPersonBuyAgainOccluder7235(v)?1:0,ADPersonBuyAgainItem7218(v)?1:0,
            ADPersonSubscribeOccluder7237(v)?1:0,ADPersonKeepShoppingText7237(v)?1:0,ADPersonBuyAgainOuterBorderShell7238(v)?1:0,
            ADPersonInterestTitle7240(v)?1:0,(image&&ADPersonHighlightIconArrow7240(iv))?1:0,ADPersonNestedListBorder7239(v)?1:0,
            buy?1:0,plate?1:0,wrap?1:0,review?1:0,image?[NSString stringWithFormat:@" imgArrow=%d imgChevron=%d",ADPersonRightArrow7231(iv)?1:0,ADPersonSectionChevron7217(iv)?1:0]:@""];
    } @catch(...) { return @"classifiers=err"; }
}
static UIView *ADPersonProbeWrapper7233(void){
    @try {
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.01)continue; NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:w]; NSUInteger seen=0;
            while(q.count&&seen++<3600){ UIView *v=q.firstObject; [q removeObjectAtIndex:0]; if(!v)continue; if(ADClassNameIs7183(v,"RCTScrollView")&&[v.accessibilityIdentifier isEqualToString:@"me"])return v; if(q.count<3300)for(UIView *c in v.subviews)[q addObject:c]; }
        }
    } @catch(...) {}
    return nil;
}
static UIScrollView *ADPersonProbeScroll7233(UIView **wrapperOut){
    UIView *wrap=ADPersonProbeWrapper7233(); if(wrapperOut)*wrapperOut=wrap; if(!wrap)return nil;
    @try {
        if([wrap isKindOfClass:[UIScrollView class]])return (UIScrollView *)wrap;
        NSMutableArray<UIView *> *q=[NSMutableArray arrayWithArray:wrap.subviews]; NSUInteger seen=0;
        while(q.count&&seen++<120){ UIView *v=q.firstObject; [q removeObjectAtIndex:0]; if([v isKindOfClass:[UIScrollView class]])return (UIScrollView *)v; if(seen<80)for(UIView *c in v.subviews)[q addObject:c]; }
    } @catch(...) {}
    return nil;
}
static void ADProbeAppend7233(NSString *path,NSString *text){
    if(!path.length||!text.length)return;
    @try {
        NSFileManager *fm=[NSFileManager defaultManager]; [fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        unsigned long long cur=[[[fm attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] unsignedLongLongValue]; if(cur>=kADPersonProbeCap7233)return;
        NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding]; unsigned long long remain=kADPersonProbeCap7233-cur; if((unsigned long long)d.length>remain)d=[d subdataWithRange:NSMakeRange(0,(NSUInteger)remain)];
        if(![fm fileExistsAtPath:path]){ [d writeToFile:path atomically:YES]; return; }
        NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:path]; if(h){ [h seekToEndOfFile]; [h writeData:d]; [h closeFile]; }
    } @catch(...) {}
}
static NSString *ADProbePath7233(NSUInteger run){
    @try {
        NSDateFormatter *f=[NSDateFormatter new]; f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; f.timeZone=[NSTimeZone localTimeZone]; f.dateFormat=@"yyyyMMdd-HHmmss-SSS";
        NSString *stamp=[f stringFromDate:[NSDate date]]?:@"unknown",*name=[NSString stringWithFormat:@"AmazonDark-v7.336-person-ui-probe-%@-r%lu.txt",stamp,(unsigned long)run];
        NSString *docs=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject]; return [(docs.length?docs:NSTemporaryDirectory()) stringByAppendingPathComponent:name];
    } @catch(...) { return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"AmazonDark-v7.336-person-ui-probe-r%lu.txt",(unsigned long)run]]; }
}
static NSString *ADPersonSnapshot7233(UIView *wrap,UIScrollView *root,NSUInteger step,CGFloat targetY){
    NSMutableString *m=[NSMutableString string]; if(!root||!wrap)return @"PERSON_SNAPSHOT_NO_ROOT\n";
    @try {
        CGRect screen=UIScreen.mainScreen.bounds,rr=[root convertRect:root.bounds toView:nil];
        [m appendFormat:@"\n===== PERSON UI SNAPSHOT step=%lu targetY=%.1f actualOffset=(%.1f,%.1f) =====\nwrapper=%p root=%p frame=(%.1f,%.1f %.1fx%.1f) content=(%.1fx%.1f)\n",(unsigned long)step,targetY,root.contentOffset.x,root.contentOffset.y,wrap,root,rr.origin.x,rr.origin.y,rr.size.width,rr.size.height,root.contentSize.width,root.contentSize.height];
        NSMutableArray *q=[NSMutableArray arrayWithObject:@{ @"v":wrap,@"d":@0 }]; NSUInteger visited=0,logged=0,onscreen=0,texts=0,images=0,vectors=0,borders=0;
        while(q.count&&visited++<4800&&logged<3600){
            NSDictionary *it=q.firstObject; [q removeObjectAtIndex:0]; UIView *v=it[@"v"]; NSUInteger d=[it[@"d"] unsignedIntegerValue]; if(!v)continue;
            CGRect wr=CGRectZero; @try { wr=[v convertRect:v.bounds toView:nil]; } @catch(...) {}
            BOOL on=!v.hidden&&v.alpha>0.01&&wr.size.width>=0.25&&wr.size.height>=0.25&&CGRectIntersectsRect(wr,screen); if(on)onscreen++;
            NSString *cn=NSStringFromClass(v.class)?:@"?",*aid=ADProbeSafe7233(v.accessibilityIdentifier),*txt=ADProbeText7233(v); BOOL image=[v isKindOfClass:[UIImageView class]],vector=[cn rangeOfString:@"RNSVG" options:NSCaseInsensitiveSearch].location!=NSNotFound;
            if([txt hasPrefix:@"text=1"])texts++; if(image)images++; if(vector)vectors++; if(v.layer.borderWidth>0.01||ADPersonRCTBorderWidth7208(v)>0.01)borders++;
            CGFloat cy=wr.origin.y-rr.origin.y+root.contentOffset.y;
            CGAffineTransform t=v.transform;
            [m appendFormat:@"P step=%lu d=%lu ptr=%p parent=%p cls=%@ aid=\"%@\" win=(%.1f,%.1f %.1fx%.1f) cy=%.1f onscreen=%d hidden=%d alpha=%.2f user=%d clips=%d transform=(%.3f,%.3f,%.3f,%.3f,%.1f,%.1f) bg=%@ layerBg=%@ tint=%@ layerBorder=%.2f/%@ radius=%.2f shadow=%@/%.2f/%.2f contents=%d subviews=%lu sublayers=%lu traits=%llu chain=\"%@\" %@ %@ %@ %@ %@\n",
                (unsigned long)step,(unsigned long)d,v,v.superview,cn,aid,wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,cy,on?1:0,v.hidden?1:0,v.alpha,v.userInteractionEnabled?1:0,v.clipsToBounds?1:0,t.a,t.b,t.c,t.d,t.tx,t.ty,ADProbeColor7233(v.backgroundColor),ADProbeCG7233(v.layer.backgroundColor),ADProbeColor7233(v.tintColor),v.layer.borderWidth,ADProbeCG7233(v.layer.borderColor),v.layer.cornerRadius,ADProbeCG7233(v.layer.shadowColor),v.layer.shadowOpacity,v.layer.shadowRadius,v.layer.contents?1:0,(unsigned long)v.subviews.count,(unsigned long)v.layer.sublayers.count,(unsigned long long)v.accessibilityTraits,ADProbeChain7233(v),txt,ADProbeRCTEdges7233(v),ADProbeImage7233(v),ADProbeControl7233(v),ADProbeClassifiers7233(v)];
            [m appendFormat:@"L ptr=%p %@\n",v,ADProbeLayer7233(v)];
            logged++;
            if(q.count<4500)for(UIView *c in v.subviews)[q addObject:@{ @"v":c,@"d":@(d+1) }];
        }
        [m appendFormat:@"PERSON_SNAPSHOT_COUNTS step=%lu visited=%lu logged=%lu onscreen=%lu text=%lu images=%lu vectors=%lu bordered=%lu\n",(unsigned long)step,(unsigned long)visited,(unsigned long)logged,(unsigned long)onscreen,(unsigned long)texts,(unsigned long)images,(unsigned long)vectors,(unsigned long)borders];
    } @catch(NSException *e){ [m appendFormat:@"PERSON_SNAPSHOT_EXCEPTION %@\n",e]; }
    return m;
}
// v7.256 verification: the Subscribe & Save tap opens a separate AppCX window/root,
// outside RCTScrollView#me.  Capture that exact visible passthrough subtree once when
// the Person probe is explicitly triggered so the sheet header, safe-area strips,
// React text, glyph/image leaves and layer paint can be verified without a live scan.
static CGFloat ADPersonProbeVisibleArea7258(UIView *v){
    if(!v)return 0.0;
    @try {
        // Effective visibility matters here: the v7.256 miss came from selecting
        // descendants that were individually unhidden while their AppCX ancestor
        // was hidden. Reject any candidate whose ancestor chain is hidden/faded.
        for(UIView *n=v;n;n=n.superview)if(n.hidden||n.alpha<0.01)return 0.0;
        UIWindow *w=v.window; if(!w||w.hidden||w.alpha<0.01)return 0.0;
        CGRect wr=[v convertRect:v.bounds toView:nil],ir=CGRectIntersection(wr,UIScreen.mainScreen.bounds);
        if(CGRectIsNull(ir)||CGRectIsEmpty(ir))return 0.0;
        return MAX(0.0,ir.size.width)*MAX(0.0,ir.size.height);
    } @catch(...) { return 0.0; }
}
static CGFloat ADPersonAppCXRootScore7258(UIView *root){
    if(!root)return 0.0;
    @try {
        CGFloat best=0.0; NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:root]; NSUInteger seen=0;
        while(q.count&&seen++<2400){
            UIView *v=q.firstObject; [q removeObjectAtIndex:0]; if(!v)continue;
            NSString *aid=v.accessibilityIdentifier?:@""; NSString *cn=NSStringFromClass(v.class)?:@"";
            CGFloat a=ADPersonProbeVisibleArea7258(v);
            if(a>0.0&&([aid isEqualToString:@"AppCXBottomSheet"]||[aid isEqualToString:@"AppCXBottomSheetContentView"]||
               [cn rangeOfString:@"BottomSheet" options:NSCaseInsensitiveSearch].location!=NSNotFound)) best=MAX(best,a+200000.0);
            else best=MAX(best,a);
            if(q.count<2200)for(UIView *c in v.subviews)if(c)[q addObject:c];
        }
        return best;
    } @catch(...) { return 0.0; }
}
static NSArray<NSDictionary *> *ADPersonAppCXCandidates7258(NSMutableString *summary){
    NSMutableArray<NSDictionary *> *out=[NSMutableArray array];
    @try {
        NSUInteger wi=0;
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w)continue;
            CGRect wr=CGRectZero; @try{wr=[w convertRect:w.bounds toView:nil];}@catch(...){}
            [summary appendFormat:@"WINDOW_CANDIDATE index=%lu ptr=%p cls=%@ key=%d hidden=%d alpha=%.2f level=%.1f frame=(%.1f,%.1f %.1fx%.1f) rootVC=%@\n",
                (unsigned long)wi++,w,NSStringFromClass(w.class)?:@"?",w.isKeyWindow?1:0,w.hidden?1:0,w.alpha,w.windowLevel,
                wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,NSStringFromClass(w.rootViewController.class)?:@"nil"];
            if(w.hidden||w.alpha<0.01)continue;
            NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:w]; NSUInteger seen=0;
            while(q.count&&seen++<3600){
                UIView *v=q.firstObject; [q removeObjectAtIndex:0]; if(!v)continue;
                if([v.accessibilityIdentifier isEqualToString:@"AppCXTouchPassthroughView"]){
                    CGFloat score=ADPersonAppCXRootScore7258(v); CGRect vr=CGRectZero; @try{vr=[v convertRect:v.bounds toView:nil];}@catch(...){}
                    [summary appendFormat:@"APP_CX_CANDIDATE ptr=%p window=%p hidden=%d alpha=%.2f score=%.1f frame=(%.1f,%.1f %.1fx%.1f)\n",
                        v,w,v.hidden?1:0,v.alpha,score,vr.origin.x,vr.origin.y,vr.size.width,vr.size.height];
                    [out addObject:@{ @"root":v,@"score":@(score) }];
                }
                if(q.count<3300)for(UIView *c in v.subviews)if(c)[q addObject:c];
            }
        }
        [out sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){
            CGFloat aa=[a[@"score"] doubleValue],bb=[b[@"score"] doubleValue];
            if(aa>bb)return NSOrderedAscending; if(aa<bb)return NSOrderedDescending; return NSOrderedSame;
        }];
    } @catch(NSException *e){ [summary appendFormat:@"APP_CX_DISCOVERY_EXCEPTION %@\n",e]; }
    return out;
}
static NSInteger ADPersonModalCandidateScore7258(UIView *v){
    if(!v||v.hidden||v.alpha<0.01)return 0;
    @try {
        CGRect wr=[v convertRect:v.bounds toView:nil],ir=CGRectIntersection(wr,UIScreen.mainScreen.bounds);
        CGFloat area=MAX(0.0,ir.size.width)*MAX(0.0,ir.size.height);
        if(area<25000.0||ir.size.width<300.0)return 0;
        if(ADPersonRoot7206(v))return 0;
        NSString *aid=(v.accessibilityIdentifier?:@"").lowercaseString;
        NSString *cn=(NSStringFromClass(v.class)?:@"").lowercaseString;
        NSInteger score=(NSInteger)MIN(area,350000.0);
        if([aid containsString:@"sheet"]||[cn containsString:@"sheet"])score+=900000;
        if([aid containsString:@"modal"]||[cn containsString:@"presentation"]||[cn containsString:@"drop"]||[cn containsString:@"transition"])score+=500000;
        if([cn containsString:@"snproot"]||[cn containsString:@"rctrootcontent"])score+=250000;
        if(v.layer.cornerRadius>=12.0)score+=120000;
        if(wr.origin.y>180.0&&wr.origin.y<800.0)score+=180000;
        return score;
    } @catch(...) { return 0; }
}
static NSArray<NSDictionary *> *ADPersonForeignModalCandidates7258(NSMutableString *summary){
    NSMutableArray<NSDictionary *> *out=[NSMutableArray array];
    @try {
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.01)continue;
            NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:w]; NSUInteger seen=0;
            while(q.count&&seen++<4200){
                UIView *v=q.firstObject; [q removeObjectAtIndex:0]; if(!v)continue;
                NSInteger score=ADPersonModalCandidateScore7258(v);
                if(score>0){
                    CGRect wr=CGRectZero; @try{wr=[v convertRect:v.bounds toView:nil];}@catch(...){}
                    [out addObject:@{ @"root":v,@"score":@(score) }];
                    if(score>=500000)[summary appendFormat:@"MODAL_CANDIDATE ptr=%p cls=%@ aid=\"%@\" score=%ld frame=(%.1f,%.1f %.1fx%.1f) bg=%@\n",
                        v,NSStringFromClass(v.class)?:@"?",ADProbeSafe7233(v.accessibilityIdentifier),(long)score,
                        wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,ADProbeColor7233(v.backgroundColor)];
                }
                if(q.count<3900)for(UIView *c in v.subviews)if(c)[q addObject:c];
            }
        }
        [out sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){
            NSInteger aa=[a[@"score"] integerValue],bb=[b[@"score"] integerValue];
            if(aa>bb)return NSOrderedAscending; if(aa<bb)return NSOrderedDescending; return NSOrderedSame;
        }];
    } @catch(NSException *e){ [summary appendFormat:@"MODAL_DISCOVERY_EXCEPTION %@\n",e]; }
    if(out.count){ NSDictionary *b=out.firstObject; UIView *v=b[@"root"]; [summary appendFormat:@"MODAL_SELECTION ptr=%p score=%ld cls=%@ aid=\"%@\" candidates=%lu\n",v,(long)[b[@"score"] integerValue],NSStringFromClass(v.class)?:@"?",ADProbeSafe7233(v.accessibilityIdentifier),(unsigned long)out.count]; }
    else [summary appendString:@"MODAL_SELECTION ptr=0x0 score=0 candidates=0\n"];
    return out;
}
static BOOL ADPersonProbeRelatedRoots7258(UIView *a,UIView *b){
    if(!a||!b)return NO;
    @try { for(UIView *n=a;n;n=n.superview)if(n==b)return YES; for(UIView *n=b;n;n=n.superview)if(n==a)return YES; } @catch(...) {}
    return NO;
}
static NSString *ADPersonExternalRootSnapshot7258(UIView *root,NSString *label,NSUInteger maxLogged){
    if(!root)return [NSString stringWithFormat:@"\n===== PERSON EXTERNAL SNAPSHOT %@ =====\nROOT found=0\n",label?:@"?"];
    NSMutableString *m=[NSMutableString string];
    @try {
        CGRect screen=UIScreen.mainScreen.bounds,rr=[root convertRect:root.bounds toView:nil];
        [m appendFormat:@"\n===== PERSON EXTERNAL SNAPSHOT %@ =====\nROOT found=1 ptr=%p cls=%@ aid=\"%@\" frame=(%.1f,%.1f %.1fx%.1f) visibleArea=%.1f\n",
            label?:@"?",root,NSStringFromClass(root.class)?:@"?",ADProbeSafe7233(root.accessibilityIdentifier),rr.origin.x,rr.origin.y,rr.size.width,rr.size.height,ADPersonProbeVisibleArea7258(root)];
        NSMutableArray *q=[NSMutableArray arrayWithObject:@{ @"v":root,@"d":@0 }]; NSUInteger visited=0,logged=0,onscreen=0,texts=0,images=0;
        while(q.count&&visited++<maxLogged+500&&logged<maxLogged){
            NSDictionary *it=q.firstObject; [q removeObjectAtIndex:0]; UIView *v=it[@"v"]; NSUInteger d=[it[@"d"] unsignedIntegerValue]; if(!v)continue;
            CGRect wr=CGRectZero; @try { wr=[v convertRect:v.bounds toView:nil]; } @catch(...) {}
            BOOL on=!v.hidden&&v.alpha>0.01&&wr.size.width>=0.25&&wr.size.height>=0.25&&CGRectIntersectsRect(wr,screen); if(on)onscreen++;
            NSString *txt=ADProbeText7233(v); if([txt hasPrefix:@"text=1"])texts++; if([v isKindOfClass:[UIImageView class]])images++;
            CGAffineTransform t=v.transform;
            [m appendFormat:@"X d=%lu ptr=%p parent=%p cls=%@ aid=\"%@\" win=(%.1f,%.1f %.1fx%.1f) onscreen=%d hidden=%d alpha=%.2f user=%d clips=%d transform=(%.3f,%.3f,%.3f,%.3f,%.1f,%.1f) bg=%@ layerBg=%@ tint=%@ layerBorder=%.2f/%@ radius=%.2f contents=%d subviews=%lu sublayers=%lu appcx=%d passthrough=%d neutralFloor=%d chain=\"%@\" %@ %@ %@ %@\n",
                (unsigned long)d,v,v.superview,NSStringFromClass(v.class)?:@"?",ADProbeSafe7233(v.accessibilityIdentifier),wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,on?1:0,v.hidden?1:0,v.alpha,v.userInteractionEnabled?1:0,v.clipsToBounds?1:0,t.a,t.b,t.c,t.d,t.tx,t.ty,ADProbeColor7233(v.backgroundColor),ADProbeCG7233(v.layer.backgroundColor),ADProbeColor7233(v.tintColor),v.layer.borderWidth,ADProbeCG7233(v.layer.borderColor),v.layer.cornerRadius,v.layer.contents?1:0,(unsigned long)v.subviews.count,(unsigned long)v.layer.sublayers.count,ADInAppCXBottomSheet7255(v)?1:0,ADInAppCXPassthrough7256(v)?1:0,ADNeutralNearWhite7255(v.backgroundColor)?1:0,ADProbeChain7233(v),txt,ADProbeRCTEdges7233(v),ADProbeImage7233(v),ADProbeControl7233(v)];
            [m appendFormat:@"XL ptr=%p %@\n",v,ADProbeLayer7233(v)]; logged++;
            if(q.count<maxLogged+250)for(UIView *c in v.subviews)if(c)[q addObject:@{ @"v":c,@"d":@(d+1) }];
        }
        [m appendFormat:@"EXTERNAL_COUNTS label=%@ visited=%lu logged=%lu onscreen=%lu text=%lu images=%lu\n",label?:@"?",(unsigned long)visited,(unsigned long)logged,(unsigned long)onscreen,(unsigned long)texts,(unsigned long)images];
    } @catch(NSException *e){ [m appendFormat:@"EXTERNAL_EXCEPTION label=%@ %@\n",label?:@"?",e]; }
    return m;
}
static NSString *ADPersonExternalSnapshots7258(void){
    NSMutableString *m=[NSMutableString stringWithString:@"\n===== PERSON EXTERNAL/MODAL DISCOVERY =====\n"];
    NSArray<NSDictionary *> *appcx=ADPersonAppCXCandidates7258(m);
    NSUInteger count=MIN((NSUInteger)3,appcx.count);
    for(NSUInteger i=0;i<count;i++){
        UIView *root=appcx[i][@"root"];
        [m appendString:ADPersonExternalRootSnapshot7258(root,[NSString stringWithFormat:@"APPCX-%lu",(unsigned long)i],1600)];
    }
    NSArray<NSDictionary *> *modals=ADPersonForeignModalCandidates7258(m);
    NSUInteger modalCount=MIN((NSUInteger)3,modals.count),written=0;
    for(NSUInteger i=0;i<modalCount;i++){
        UIView *modal=modals[i][@"root"]; BOOL duplicate=NO;
        for(NSDictionary *d in appcx){ UIView *ar=d[@"root"]; if(ADPersonProbeRelatedRoots7258(ar,modal)){duplicate=YES;break;} }
        if(!duplicate){ [m appendString:ADPersonExternalRootSnapshot7258(modal,[NSString stringWithFormat:@"FOREIGN-MODAL-%lu",(unsigned long)written],1800)]; written++; }
    }
    if(!appcx.count)[m appendString:@"APP_CX_ROOTS found=0\n"];
    return m;
}

static void ADCapturePersonProbe7233(NSString *trigger){
    if(!gP.enabled||gADPersonProbeBusy7233)return;
    UIView *wrap=nil; UIScrollView *root=ADPersonProbeScroll7233(&wrap); if(!root||!wrap)return;
    gADPersonProbeBusy7233=YES; NSUInteger run=++gADPersonProbeRun7233; NSString *path=ADProbePath7233(run);
    CGPoint original=root.contentOffset; BOOL originalScroll=root.scrollEnabled; root.scrollEnabled=NO;
    CGFloat viewport=MAX(1.0,root.bounds.size.height),stride=MAX(320.0,MIN(600.0,viewport*0.58));
    ADProbeAppend7233(path,[NSString stringWithFormat:@"AMAZONDARK v7.336 PERSON UI FORENSICS PROBE\nversion=%s\ntrigger=%@\ndate=%@\nfile=%@\ncap_bytes=%llu\npolicy=no visible text strings, no accessibilityLabel text, no typed query, no web DOM, no network payloads\nroot wrapper is exact RCTScrollView aid=me; real scroll descendant is walked non-animated and restored\nexternal modal discovery=all AppCX roots are scored by visible sheet area; top roots plus best foreign modal are snapshotted\noriginalOffset=(%.1f,%.1f) content=(%.1fx%.1f) viewport=%.1f stride=%.1f maxSteps=40\n",
        AD_VERSION,trigger?:@"unknown",[NSDate date],path.lastPathComponent,kADPersonProbeCap7233,original.x,original.y,root.contentSize.width,root.contentSize.height,viewport,stride]);
    ADProbeAppend7233(path,ADPersonExternalSnapshots7258());
    __block NSUInteger step=0; __block CGFloat targetY=0,lastY=-999999; __block void (^next)(void)=nil;
    void (^finish)(NSString *)=^(NSString *reason){
        @try { [root setContentOffset:original animated:NO]; [root layoutIfNeeded]; root.scrollEnabled=originalScroll; } @catch(...) {}
        ADProbeAppend7233(path,[NSString stringWithFormat:@"\nPERSON_PROBE_END reason=%@ steps=%lu restoredOffset=(%.1f,%.1f) finalContent=(%.1fx%.1f)\n================ END RUN ================\n",reason?:@"done",(unsigned long)step,root.contentOffset.x,root.contentOffset.y,root.contentSize.width,root.contentSize.height]);
        gADPersonProbeBusy7233=NO; next=nil;
    };
    next=^{
        if(!root.window||!wrap.window||!ADInPersonTab7206(wrap)){ finish(@"person-left-window"); return; }
        if(step>=40){ finish(@"step-cap"); return; }
        CGFloat maxY=MAX(0.0,root.contentSize.height-root.bounds.size.height+root.adjustedContentInset.bottom); targetY=MIN(MAX(0.0,targetY),maxY);
        if(step>0&&fabs(targetY-lastY)<0.5&&fabs(targetY-maxY)<0.5){ finish(@"bottom"); return; }
        @try { [root setContentOffset:CGPointMake(original.x,targetY) animated:NO]; [root layoutIfNeeded]; } @catch(...) {}
        NSUInteger thisStep=step++; CGFloat thisY=targetY; lastY=targetY;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.34*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            ADProbeAppend7233(path,ADPersonSnapshot7233(wrap,root,thisStep,thisY));
            CGFloat newMax=MAX(0.0,root.contentSize.height-root.bounds.size.height+root.adjustedContentInset.bottom); if(fabs(thisY-newMax)<0.5){ finish(@"bottom"); return; }
            targetY=MIN(newMax,thisY+stride); dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.06*NSEC_PER_SEC)),dispatch_get_main_queue(),next);
        });
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.05*NSEC_PER_SEC)),dispatch_get_main_queue(),next);
}

// v7.255: Retained Shopping Cart UI forensics probe. It shares one explicit screenshot/SIGUSR2
// dispatcher with Person and Hamburger/Menu, and remains dormant outside a matching active tab.
// GitHub history/current web ownership identifies Cart as a WKWebView document (#cart-page /
// #sc-active-cart / #sc-saved-cart), not the React RCTScrollView#me used by Person.
// This subsystem is dormant until screenshot/SIGUSR2. v7.311 uses a two-trigger transaction:
// trigger one arms the bounded document-start lifecycle recorder, the user reproduces the Cart
// refresh/transition, and trigger two exports the transient paint ring plus settled DOM/native state.
// The old post-hoc scroll walk could only see the page after the white surfaces had disappeared.
static NSUInteger gADCartProbeRun7241=0;
static BOOL gADCartProbeBusy7241=NO;
static BOOL gADCartTransitionArmed7310=NO;
static NSString *gADCartTransitionPath7310=nil;
static WKWebView *gADCartTransitionWebView7310=nil;
static const unsigned long long kADCartProbeCap7241=64ULL*1024ULL*1024ULL;

static NSString *ADCartProbeSafe7241(NSString *x){
    if(!x.length)return @"";
    @try {
        NSString *s=[x stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
        s=[s stringByReplacingOccurrencesOfString:@"\"" withString:@"'"];
        s=[s stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        s=[s stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
        if(s.length>220)s=[[s substringToIndex:220] stringByAppendingString:@"…"];
        return s;
    } @catch(...) { return @"?"; }
}
static NSString *ADCartProbeColor7241(UIColor *c){
    if(!c)return @"nil";
    @try { CGFloat r=0,g=0,b=0,a=0,w=0; if([c getRed:&r green:&g blue:&b alpha:&a])return [NSString stringWithFormat:@"rgba(%.3f,%.3f,%.3f,%.3f)",r,g,b,a]; if([c getWhite:&w alpha:&a])return [NSString stringWithFormat:@"white(%.3f,%.3f)",w,a]; return [NSString stringWithFormat:@"%@",c]; } @catch(...) { return @"?"; }
}
static NSString *ADCartProbeCG7241(CGColorRef c){ if(!c)return @"nil"; @try { return ADCartProbeColor7241([UIColor colorWithCGColor:c]); } @catch(...) { return @"?"; } }
static NSString *ADCartProbeChain7241(UIView *v){
    NSMutableArray<NSString *> *a=[NSMutableArray array]; @try { for(UIView *n=v;n&&a.count<12;n=n.superview){ NSString *cn=NSStringFromClass(n.class)?:@"?",*aid=ADCartProbeSafe7241(n.accessibilityIdentifier); [a addObject:aid.length?[NSString stringWithFormat:@"%@#%@",cn,aid]:cn]; } } @catch(...) {} return [a componentsJoinedByString:@"<-"];
}
static NSString *ADCartProbeText7241(UIView *v){
    if(!v)return @"text=0";
    @try {
        NSTextStorage *ts=ADPersonTextStorage7206(v);
        if(ts&&ts.length){ NSMutableArray<NSString *> *runs=[NSMutableArray array]; [ts enumerateAttributesInRange:NSMakeRange(0,ts.length) options:0 usingBlock:^(NSDictionary *attrs,NSRange range,BOOL *stop){ if(runs.count>=16){*stop=YES;return;} UIColor *fg=attrs[NSForegroundColorAttributeName],*bg=attrs[NSBackgroundColorAttributeName]; UIFont *font=attrs[NSFontAttributeName]; [runs addObject:[NSString stringWithFormat:@"%lu:%lu:fg=%@:bg=%@:font=%@/%.1f",(unsigned long)range.location,(unsigned long)range.length,ADCartProbeColor7241(fg),ADCartProbeColor7241(bg),font.fontName?:@"nil",font?font.pointSize:0.0]]; }]; return [NSString stringWithFormat:@"text=1 kind=rct len=%lu runs=[%@]",(unsigned long)ts.length,[runs componentsJoinedByString:@";"]]; }
        if([v isKindOfClass:[UILabel class]]){ UILabel *l=(UILabel *)v; return [NSString stringWithFormat:@"text=1 kind=label len=%lu color=%@ font=%@/%.1f lines=%ld align=%ld break=%ld",(unsigned long)l.text.length,ADCartProbeColor7241(l.textColor),l.font.fontName?:@"nil",l.font.pointSize,(long)l.numberOfLines,(long)l.textAlignment,(long)l.lineBreakMode]; }
    } @catch(...) {}
    NSString *cn=NSStringFromClass(v.class)?:@""; BOOL textish=[cn rangeOfString:@"Text" options:NSCaseInsensitiveSearch].location!=NSNotFound||[cn rangeOfString:@"Paragraph" options:NSCaseInsensitiveSearch].location!=NSNotFound; return textish?@"text=1 storage=none":@"text=0";
}
static NSString *ADCartProbeRCT7241(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return @"rct=0";
    @try { const char *wn[]={"borderWidth","borderTopWidth","borderRightWidth","borderBottomWidth","borderLeftWidth"}; const char *cn[]={"borderColor","borderTopColor","borderRightColor","borderBottomColor","borderLeftColor"}; const char *rn[]={"borderRadius","borderTopLeftRadius","borderTopRightRadius","borderBottomLeftRadius","borderBottomRightRadius"}; NSMutableArray *a=[NSMutableArray array]; for(size_t i=0;i<sizeof(wn)/sizeof(*wn);i++){SEL q=sel_registerName(wn[i]);if([v respondsToSelector:q]){CGFloat x=((CGFloat(*)(id,SEL))objc_msgSend)(v,q);[a addObject:[NSString stringWithFormat:@"%s=%.2f",wn[i],x]];}} for(size_t i=0;i<sizeof(cn)/sizeof(*cn);i++){SEL q=sel_registerName(cn[i]);if([v respondsToSelector:q]){id x=((id(*)(id,SEL))objc_msgSend)(v,q);[a addObject:[NSString stringWithFormat:@"%s=%@",cn[i],[x isKindOfClass:[UIColor class]]?ADCartProbeColor7241(x):[NSString stringWithFormat:@"%@",x]]];}} for(size_t i=0;i<sizeof(rn)/sizeof(*rn);i++){SEL q=sel_registerName(rn[i]);if([v respondsToSelector:q]){CGFloat x=((CGFloat(*)(id,SEL))objc_msgSend)(v,q);[a addObject:[NSString stringWithFormat:@"%s=%.2f",rn[i],x]];}} return [NSString stringWithFormat:@"rct=1 [%@]",[a componentsJoinedByString:@","]]; } @catch(...) { return @"rct=1 err=1"; }
}
static NSString *ADCartProbeImage7241(UIView *v){
    if(![v isKindOfClass:[UIImageView class]])return @"img=0";
    @try { UIImageView *iv=(UIImageView *)v; UIImage *im=iv.image; size_t pxw=0,pxh=0; if(im.CGImage){pxw=CGImageGetWidth(im.CGImage);pxh=CGImageGetHeight(im.CGImage);} CALayer *twb=objc_getAssociatedObject(iv,kADTWBOverlay); return [NSString stringWithFormat:@"img=1 has=%d mode=%ld pts=(%.1fx%.1f) px=(%zux%zu) scale=%.2f contentMode=%ld tint=%@ twb=%d",im?1:0,(long)(im?im.renderingMode:-1),im?im.size.width:0.0,im?im.size.height:0.0,pxw,pxh,im?im.scale:0.0,(long)iv.contentMode,ADCartProbeColor7241(iv.tintColor),twb?1:0]; } @catch(...) { return @"img=1 err=1"; }
}
static NSString *ADCartProbeControl7241(UIView *v){
    @try { if([v isKindOfClass:[UIControl class]]){UIControl *c=(UIControl *)v;return [NSString stringWithFormat:@"control=1 enabled=%d selected=%d highlighted=%d state=%lu",c.enabled?1:0,c.selected?1:0,c.highlighted?1:0,(unsigned long)c.state];} if([v isKindOfClass:[UIScrollView class]]){UIScrollView *sv=(UIScrollView *)v;return [NSString stringWithFormat:@"scroll=1 offset=(%.1f,%.1f) content=(%.1fx%.1f) inset=(%.1f,%.1f,%.1f,%.1f) enabled=%d hInd=%d vInd=%d style=%ld",sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height,sv.adjustedContentInset.top,sv.adjustedContentInset.left,sv.adjustedContentInset.bottom,sv.adjustedContentInset.right,sv.scrollEnabled?1:0,sv.showsHorizontalScrollIndicator?1:0,sv.showsVerticalScrollIndicator?1:0,(long)sv.indicatorStyle];} } @catch(...) {} return @"control=0";
}
static NSString *ADCartProbeLayer7241(UIView *v){
    if(!v)return @"layers=0"; @try {CALayer *root=v.layer;NSMutableArray<CALayer *> *q=[NSMutableArray arrayWithObject:root];NSMutableArray<NSString *> *samples=[NSMutableArray array];NSUInteger seen=0,shape=0,grad=0,bordered=0,contents=0;while(q.count&&seen++<72){CALayer *l=q.firstObject;[q removeObjectAtIndex:0];if(!l)continue;if(l.contents)contents++;BOOL interesting=(l==root)||l.borderWidth>0.01||l.backgroundColor||l.mask||[l isKindOfClass:[CAShapeLayer class]]||[l isKindOfClass:[CAGradientLayer class]]||l.shadowOpacity>0.001;if(l.borderWidth>0.01)bordered++;if([l isKindOfClass:[CAShapeLayer class]])shape++;if([l isKindOfClass:[CAGradientLayer class]])grad++;if(interesting&&samples.count<12){NSString *extra=@"";if([l isKindOfClass:[CAShapeLayer class]]){CAShapeLayer *sh=(CAShapeLayer *)l;extra=[NSString stringWithFormat:@":shape(f=%@ s=%@ lw=%.2f dash=%@)",ADCartProbeCG7241(sh.fillColor),ADCartProbeCG7241(sh.strokeColor),sh.lineWidth,sh.lineDashPattern?:@[]];}else if([l isKindOfClass:[CAGradientLayer class]]){CAGradientLayer *g=(CAGradientLayer *)l;NSMutableArray *cs=[NSMutableArray array];for(id c in g.colors?:@[])[cs addObject:ADCartProbeCG7241((__bridge CGColorRef)c)];extra=[NSString stringWithFormat:@":grad(%@)",[cs componentsJoinedByString:@"/"]];}[samples addObject:[NSString stringWithFormat:@"%@ name=%@ f=(%.1f,%.1f %.1fx%.1f) bg=%@ bw=%.2f bc=%@ cr=%.2f op=%.2f z=%.1f mask=%d contents=%d shadow=%@/%.2f/%.2f%@",NSStringFromClass(l.class),l.name?:@"nil",l.frame.origin.x,l.frame.origin.y,l.frame.size.width,l.frame.size.height,ADCartProbeCG7241(l.backgroundColor),l.borderWidth,ADCartProbeCG7241(l.borderColor),l.cornerRadius,l.opacity,l.zPosition,l.mask?1:0,l.contents?1:0,ADCartProbeCG7241(l.shadowColor),l.shadowOpacity,l.shadowRadius,extra]];}if(seen<52)for(CALayer *c in l.sublayers?:@[])[q addObject:c];}return [NSString stringWithFormat:@"layers=%lu shape=%lu grad=%lu bordered=%lu contents=%lu maskToBounds=%d samples=[%@]",(unsigned long)seen,(unsigned long)shape,(unsigned long)grad,(unsigned long)bordered,(unsigned long)contents,root.masksToBounds?1:0,[samples componentsJoinedByString:@" || "]];} @catch(...) {return @"layers=1 err=1";}
}
static BOOL ADCartProbeIsDescendant7241(UIView *v,UIView *ancestor){ if(!v||!ancestor)return NO; @try {for(UIView *n=v;n;n=n.superview)if(n==ancestor)return YES;} @catch(...) {} return NO; }
static BOOL ADCartProbeIsAncestor7241(UIView *v,UIView *child){ return ADCartProbeIsDescendant7241(child,v); }

static void ADCartProbeAppend7241(NSString *path,NSString *text){
    if(!path.length||!text.length)return; @try {NSFileManager *fm=[NSFileManager defaultManager];[fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];unsigned long long cur=[[[fm attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] unsignedLongLongValue];if(cur>=kADCartProbeCap7241)return;NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding];unsigned long long remain=kADCartProbeCap7241-cur;if((unsigned long long)d.length>remain)d=[d subdataWithRange:NSMakeRange(0,(NSUInteger)remain)];if(![fm fileExistsAtPath:path]){[d writeToFile:path atomically:YES];return;}NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:path];if(h){[h seekToEndOfFile];[h writeData:d];[h closeFile];}} @catch(...) {}
}
static NSString *ADCartProbePath7241(NSUInteger run){
    @try {NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.timeZone=[NSTimeZone localTimeZone];f.dateFormat=@"yyyyMMdd-HHmmss-SSS";NSString *stamp=[f stringFromDate:[NSDate date]]?:@"unknown",*name=[NSString stringWithFormat:@"AmazonDark-v7.336-cart-transition-probe-%@-r%lu.txt",stamp,(unsigned long)run];NSString *docs=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject];return [(docs.length?docs:NSTemporaryDirectory()) stringByAppendingPathComponent:name];} @catch(...) {return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"AmazonDark-v7.336-cart-transition-probe-r%lu.txt",(unsigned long)run]];}
}
static NSString *ADCartProbeDetectJS7241(void){
    return
        @"(function(){try{var d=document,p=String(location.pathname||'').toLowerCase();var cp=!!d.querySelector('#cart-page'),ac=!!d.querySelector('#sc-active-cart'),sv=!"
        @"!d.querySelector('#sc-saved-cart');var legacy=!!d.querySelector('.sc-list-item,[class*=\"sc-list-item\"],form[id*=\"cart\" i],[id*=\"activeCart\" i]');var pathC"
        @"art=/\\/gp\\/cart(?:\\/|$)|\\/cart(?:\\/|$)/.test(p);var score=(ac?520:0)+(cp?420:0)+(sv?90:0)+(legacy?160:0)+(pathCart?220:0);var se=d.scrollingElement||d.docu"
        @"mentElement||d.body;return 'score='+score+' cartPage='+(cp?1:0)+' active='+(ac?1:0)+' saved='+(sv?1:0)+' legacy='+(legacy?1:0)+' pathCart='+(pathCart?1:0)+' rea"
        @"dy='+String(d.readyState||'')+' scrollH='+(se?Math.round(se.scrollHeight||0):0)+' clientH='+(se?Math.round(se.clientHeight||0):0)+' nodes='+(d.getElementsByTagN"
        @"ame('*').length||0)+' frames='+(d.getElementsByTagName('iframe').length||0)+' ad7='+(d.getElementById('ad7-static-theme')?1:0)+' twb='+(d.getElementById('ad7-pr"
        @"oduct-feed-twb')||d.getElementById('ad7-menu-twb')||d.getElementById('ad7-search-pane-twb')?1:0);}catch(e){return 'score=0 error=1';}})();";
}
static NSString *ADCartProbeDOMJS7241(NSUInteger step,BOOL full){
    static NSString *base=nil; static dispatch_once_t once; dispatch_once(&once,^{ base=
        @"(function(){try{var STEP=__STEP__,FULL=__FULL__,d=document,w=window,de=d.documentElement||{},se=d.scrollingElement||de||d.body;var sx=Number(w.scrollX||se.scrol"
        @"lLeft||0),sy=Number(w.scrollY||se.scrollTop||0),vw=Number(w.innerWidth||de.clientWidth||0),vh=Number(w.innerHeight||de.clientHeight||0);var LO=sy-140,HI=sy+vh+1"
        @"40,MAX=FULL?6200:2600,out=[],visited=0,emitted=0,trunc=0;function clean(v,n){v=String(v==null?'':v).replace(/[\\r\\n\\t]+/g,' ').replace(/\\|/g,'¦').replace(/\\"
        @"\\/g,'/');n=n||180;return v.length>n?v.slice(0,n)+'…':v}function hash(s){s=String(s||'');var h=2166136261>>>0;for(var i=0;i<s.length;i++){h^=s.charCodeAt(i);h=M"
        @"ath.imul(h,16777619)}return (h>>>0).toString(16)}function cls(e){var c='';try{c=typeof e.className==='string'?e.className:(e.className&&e.className.baseVal)||''"
        @"}catch(_){ }return clean(c,220)}function sig(e){var z=String(e.tagName||e.nodeName||'?').toLowerCase(),i='';try{i=e.id||''}catch(_){ }var c=cls(e).trim().split("
        @"/\\s+/).filter(Boolean).slice(0,3).join('.');return z+(i?'#'+clean(i,90):'')+(c?'.'+clean(c,100):'')}function chain(e){var a=[],x=e;for(var n=0;x&&n<8;n++){a.pu"
        @"sh(sig(x));if(x.parentElement){x=x.parentElement;continue}var r=x.getRootNode&&x.getRootNode();x=r&&r.host?r.host:null}return a.join('<-')}function attr(e,n,lim"
        @"){try{var v=e.getAttribute(n);return v==null?'':clean(v,lim||150)}catch(_){return ''}}function boolAttr(e,n){try{return e.hasAttribute(n)?1:0}catch(_){return 0}"
        @"}function kind(v){v=String(v||'');if(!v||v==='none')return 'none';if(/gradient/i.test(v))return 'gradient';if(/url\\(/i.test(v))return 'url';return clean(v,45)}"
        @"function textInfo(e){var own='';try{for(var i=0;i<e.childNodes.length;i++){var n=e.childNodes[i];if(n.nodeType===3)own+=n.nodeValue||''}}catch(_){ }own=own.trim"
        @"();var all='';try{all=(e.innerText||e.textContent||'').trim()}catch(_){ }if(all.length>12000)all=all.slice(0,12000);return ' ownText='+own.length+'/'+hash(own)+"
        @"' allText='+all.length+'/'+hash(all)}function pseudo(e,p){try{var c=getComputedStyle(e,p),ct=String(c.content||'');if((!ct||ct==='none'||ct==='normal')&&c.backg"
        @"roundColor==='rgba(0, 0, 0, 0)'&&c.backgroundImage==='none'&&parseFloat(c.borderTopWidth||0)===0&&parseFloat(c.width||0)===0&&parseFloat(c.height||0)===0)return"
        @" '';return ' '+p.slice(2)+'={ct='+ct.length+'/'+hash(ct)+' fg='+clean(c.color,45)+' bg='+clean(c.backgroundColor,45)+' bgImg='+kind(c.backgroundImage)+' wh='+cl"
        @"ean(c.width,25)+'x'+clean(c.height,25)+' b='+clean(c.borderTopWidth,15)+'/'+clean(c.borderTopColor,45)+' rad='+clean(c.borderRadius,35)+' fill='+clean(c.fill,45"
        @")+' stroke='+clean(c.stroke,45)+'}'}catch(_){return ''}}function tech(e){var names=['role','data-testid','data-component-type','data-csa-c-type','data-csa-c-con"
        @"tent-id','data-csa-c-slot-id','data-csa-c-painter','data-cel-widget','cel_widget_id','name','type','aria-hidden'];var a=[];for(var i=0;i<names.length;i++){var v"
        @"=attr(e,names[i]);if(v)a.push(names[i]+'='+v)}var asin=attr(e,'data-asin',40);if(asin)a.push('data-asin='+asin.length+'/'+hash(asin));if(boolAttr(e,'href'))a.pu"
        @"sh('href=1');if(boolAttr(e,'src'))a.push('src=1');var al=attr(e,'aria-label',1);try{var av=e.getAttribute('aria-label');if(av!=null)a.push('ariaLabel='+String(a"
        @"v).length+'/'+hash(av))}catch(_){ }try{var alt=e.getAttribute('alt');if(alt!=null)a.push('alt='+String(alt).length+'/'+hash(alt))}catch(_){ }try{if('value' in e"
        @"&&e.value!=null)a.push('value='+String(e.value).length+'/'+hash(e.value))}catch(_){ }try{if('checked' in e)a.push('checked='+(e.checked?1:0));if('selected' in e"
        @")a.push('selected='+(e.selected?1:0));if('disabled' in e)a.push('disabled='+(e.disabled?1:0))}catch(_){ }return a.join(',')}function media(e,c){var t=String(e.t"
        @"agName||'').toUpperCase();try{if(t==='IMG')return ' media=img('+Number(e.naturalWidth||0)+'x'+Number(e.naturalHeight||0)+' complete='+(e.complete?1:0)+' loading"
        @"='+clean(e.loading,20)+' fit='+clean(c.objectFit,30)+' pos='+clean(c.objectPosition,40)+')';if(t==='VIDEO')return ' media=video('+Number(e.videoWidth||0)+'x'+Nu"
        @"mber(e.videoHeight||0)+' paused='+(e.paused?1:0)+' muted='+(e.muted?1:0)+')';if(t==='CANVAS')return ' media=canvas('+Number(e.width||0)+'x'+Number(e.height||0)+"
        @"')';if(t==='SVG'||e instanceof SVGElement){var vb='';try{vb=e.getAttribute('viewBox')||''}catch(_){ }return ' media=svg(viewBox='+clean(vb,60)+' paths='+(e.quer"
        @"ySelectorAll?e.querySelectorAll('path').length:0)+' uses='+(e.querySelectorAll?e.querySelectorAll('use').length:0)+')'}}catch(_){ }return ''}function emit(e,sco"
        @"pe){if(emitted>=MAX){trunc=1;return}visited++;var r;try{r=e.getBoundingClientRect()}catch(_){return}var c;try{c=getComputedStyle(e)}catch(_){return}var docY=r.t"
        @"op+sy,near=(r.width>0.1&&r.height>0.1&&docY+r.height>=LO&&docY<=HI),sticky=(c.position==='fixed'||c.position==='sticky');if(!FULL&&!near&&!sticky)return;var id="
        @"'',cl='';try{id=e.id||'';cl=cls(e)}catch(_){ }var ti=tech(e);out.push('D step='+STEP+' scope='+scope+' n='+emitted+' tag='+String(e.tagName||e.nodeName||'?').to"
        @"LowerCase()+' id=\"'+clean(id,120)+'\" class=\"'+clean(cl,220)+'\" chain=\"'+clean(chain(e),520)+'\" vp=('+r.left.toFixed(1)+','+r.top.toFixed(1)+' '+r.width.to"
        @"Fixed(1)+'x'+r.height.toFixed(1)+') doc=('+Number(r.left+sx).toFixed(1)+','+Number(docY).toFixed(1)+') scroll=('+Number(e.scrollLeft||0).toFixed(1)+','+Number(e"
        @".scrollTop||0).toFixed(1)+' '+Number(e.scrollWidth||0).toFixed(1)+'x'+Number(e.scrollHeight||0).toFixed(1)+') children='+Number(e.childElementCount||0)+' disp='"
        @"+clean(c.display,28)+' vis='+clean(c.visibility,28)+' op='+clean(c.opacity,12)+' pos='+clean(c.position,20)+' z='+clean(c.zIndex,20)+' ov='+clean(c.overflowX,20"
        @")+'/'+clean(c.overflowY,20)+' pointer='+clean(c.pointerEvents,20)+' fg='+clean(c.color,52)+' textFill='+clean(c.webkitTextFillColor,52)+' bg='+clean(c.backgroun"
        @"dColor,52)+' bgImg='+kind(c.backgroundImage)+' mask='+kind(c.webkitMaskImage||c.maskImage)+' border='+clean(c.borderTopWidth,14)+'/'+clean(c.borderTopColor,52)+"
        @"','+clean(c.borderRightWidth,14)+'/'+clean(c.borderRightColor,52)+','+clean(c.borderBottomWidth,14)+'/'+clean(c.borderBottomColor,52)+','+clean(c.borderLeftWidt"
        @"h,14)+'/'+clean(c.borderLeftColor,52)+' rad='+clean(c.borderRadius,70)+' outline='+clean(c.outlineWidth,14)+'/'+clean(c.outlineColor,52)+' shadow='+clean(c.boxS"
        @"hadow,120)+' font='+clean(c.fontFamily,70)+'/'+clean(c.fontSize,24)+'/'+clean(c.fontWeight,24)+' line='+clean(c.lineHeight,24)+' align='+clean(c.textAlign,24)+'"
        @" deco='+clean(c.textDecorationLine,30)+' fill='+clean(c.fill,52)+' stroke='+clean(c.stroke,52)+' sw='+clean(c.strokeWidth,20)+' filter='+clean(c.filter,80)+' bl"
        @"end='+clean(c.mixBlendMode,24)+' isolate='+clean(c.isolation,24)+' transform='+clean(c.transform,100)+(ti?' attrs=['+ti+']':'')+textInfo(e)+media(e,c)+pseudo(e,"
        @"'::before')+pseudo(e,'::after'));emitted++;try{if(e.shadowRoot){scan(e.shadowRoot,'shadow:'+sig(e))}}catch(_){ }}function scan(root,scope){var a=[];try{a=root.q"
        @"uerySelectorAll('*')}catch(_){return}for(var i=0;i<a.length&&emitted<MAX;i++)emit(a[i],scope)}out.push('DOM_BEGIN step='+STEP+' full='+(FULL?1:0)+' ready='+Stri"
        @"ng(d.readyState||'')+' viewport='+vw+'x'+vh+' scroll='+sx+','+sy+' scrollSize='+Number(se?se.scrollWidth:0)+'x'+Number(se?se.scrollHeight:0)+' nodes='+d.getElem"
        @"entsByTagName('*').length+' frames='+d.getElementsByTagName('iframe').length+' stylesheets='+d.styleSheets.length+' ad7='+(d.getElementById('ad7-static-theme')?"
        @"1:0));scan(d,'main');var ifr=d.getElementsByTagName('iframe');for(var fi=0;fi<ifr.length&&emitted<MAX;fi++){try{var fd=ifr[fi].contentDocument;if(fd)scan(fd,'fr"
        @"ame'+fi);else out.push('FRAME step='+STEP+' index='+fi+' accessible=0')}catch(_){out.push('FRAME step='+STEP+' index='+fi+' accessible=0')}}out.push('DOM_END st"
        @"ep='+STEP+' full='+(FULL?1:0)+' visited='+visited+' emitted='+emitted+' truncated='+trunc);return out.join('\\n')+'\\n';}catch(e){return 'DOM_EXCEPTION '+String"
        @"(e&&e.message||e)+'\\n';}})();"; });
    NSString *js=[base stringByReplacingOccurrencesOfString:@"__STEP__" withString:[NSString stringWithFormat:@"%lu",(unsigned long)step]];
    return [js stringByReplacingOccurrencesOfString:@"__FULL__" withString:(full?@"true":@"false")];
}
static NSInteger ADCartProbeScore7241(id result){
    if(![result isKindOfClass:[NSString class]])return 0; NSString *s=(NSString *)result; NSRange r=[s rangeOfString:@"score="]; if(r.location==NSNotFound)return 0; NSString *tail=[s substringFromIndex:NSMaxRange(r)]; return [tail integerValue];
}
static NSArray<WKWebView *> *ADCartProbeWebViews7241(void){
    NSMutableOrderedSet<WKWebView *> *set=[NSMutableOrderedSet orderedSet]; @try {for(WKWebView *wv in ADTrackedWebViews())if(wv)[set addObject:wv];for(UIWindow *w in UIApplication.sharedApplication.windows){if(!w||w.hidden||w.alpha<0.01)continue;NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:w];NSUInteger seen=0;while(q.count&&seen++<5000){UIView *v=q.firstObject;[q removeObjectAtIndex:0];if([v isKindOfClass:[WKWebView class]])[set addObject:(WKWebView *)v];if(q.count<4700)for(UIView *c in v.subviews)[q addObject:c];}}} @catch(...) {} return set.array?:@[];
}
static void ADCartProbeFindWebView7241(NSString *path,void (^done)(WKWebView *,NSString *)){
    NSArray<WKWebView *> *views=ADCartProbeWebViews7241(); if(!views.count){done(nil,@"no-webviews");return;}
    __block NSUInteger idx=0; __block NSInteger bestScore=0; __block CGFloat bestArea=0; __block WKWebView *best=nil; __block NSString *bestMeta=@""; __block void (^next)(void)=nil;
    next=^{ if(idx>=views.count){WKWebView *winner=best;NSString *meta=bestMeta;next=nil;done(winner,meta);return;} WKWebView *wv=views[idx];NSUInteger thisIdx=idx++;CGRect wr=CGRectZero;@try{wr=[wv convertRect:wv.bounds toView:nil];}@catch(...){}CGFloat area=MAX(0.0,wr.size.width)*MAX(0.0,wr.size.height);[wv evaluateJavaScript:ADCartProbeDetectJS7241() completionHandler:^(id result,NSError *error){NSString *meta=[result isKindOfClass:[NSString class]]?(NSString *)result:[NSString stringWithFormat:@"score=0 error=%@",error.localizedDescription?:@"eval"] ;NSInteger score=ADCartProbeScore7241(meta);ADCartProbeAppend7241(path,[NSString stringWithFormat:@"CANDIDATE index=%lu ptr=%p window=%d hidden=%d alpha=%.2f frame=(%.1f,%.1f %.1fx%.1f) nativeContent=(%.1fx%.1f) %@\n",(unsigned long)thisIdx,wv,wv.window?1:0,wv.hidden?1:0,wv.alpha,wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,wv.scrollView.contentSize.width,wv.scrollView.contentSize.height,ADCartProbeSafe7241(meta)]);if(score>bestScore||(score==bestScore&&score>0&&area>bestArea)){bestScore=score;bestArea=area;best=wv;bestMeta=meta;}dispatch_async(dispatch_get_main_queue(),next);}]; }; next();
}
static NSString *ADCartNativeSnapshot7241(UIView *root,WKWebView *target,NSString *phase){
    NSMutableString *m=[NSMutableString string]; if(!root)return @"NATIVE_SNAPSHOT_NO_ROOT\n"; @try {CGRect screen=UIScreen.mainScreen.bounds;[m appendFormat:@"\n===== CART NATIVE SNAPSHOT phase=%@ root=%p target=%p =====\n",phase?:@"?",root,target];NSMutableArray *q=[NSMutableArray arrayWithObject:@{@"v":root,@"d":@0}];NSUInteger visited=0,logged=0,onscreen=0;while(q.count&&visited++<5200&&logged<4300){NSDictionary *it=q.firstObject;[q removeObjectAtIndex:0];UIView *v=it[@"v"];NSUInteger d=[it[@"d"] unsignedIntegerValue];if(!v)continue;CGRect wr=CGRectZero;@try{wr=[v convertRect:v.bounds toView:nil];}@catch(...){}BOOL on=!v.hidden&&v.alpha>0.01&&wr.size.width>=0.25&&wr.size.height>=0.25&&CGRectIntersectsRect(wr,screen);if(on)onscreen++;NSString *cn=NSStringFromClass(v.class)?:@"?",*aid=ADCartProbeSafe7241(v.accessibilityIdentifier);NSInteger rel=(v==target)?3:(ADCartProbeIsDescendant7241(v,target)?2:(ADCartProbeIsAncestor7241(v,target)?1:0));CGAffineTransform t=v.transform;[m appendFormat:@"N d=%lu ptr=%p parent=%p rel=%ld cls=%@ aid=\"%@\" win=(%.1f,%.1f %.1fx%.1f) onscreen=%d hidden=%d alpha=%.2f user=%d clips=%d transform=(%.3f,%.3f,%.3f,%.3f,%.1f,%.1f) bg=%@ layerBg=%@ tint=%@ layerBorder=%.2f/%@ radius=%.2f shadow=%@/%.2f/%.2f contents=%d subviews=%lu sublayers=%lu traits=%llu chain=\"%@\" %@ %@ %@ %@\n",(unsigned long)d,v,v.superview,(long)rel,cn,aid,wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,on?1:0,v.hidden?1:0,v.alpha,v.userInteractionEnabled?1:0,v.clipsToBounds?1:0,t.a,t.b,t.c,t.d,t.tx,t.ty,ADCartProbeColor7241(v.backgroundColor),ADCartProbeCG7241(v.layer.backgroundColor),ADCartProbeColor7241(v.tintColor),v.layer.borderWidth,ADCartProbeCG7241(v.layer.borderColor),v.layer.cornerRadius,ADCartProbeCG7241(v.layer.shadowColor),v.layer.shadowOpacity,v.layer.shadowRadius,v.layer.contents?1:0,(unsigned long)v.subviews.count,(unsigned long)v.layer.sublayers.count,(unsigned long long)v.accessibilityTraits,ADCartProbeChain7241(v),ADCartProbeText7241(v),ADCartProbeRCT7241(v),ADCartProbeImage7241(v),ADCartProbeControl7241(v)];[m appendFormat:@"NL ptr=%p %@\n",v,ADCartProbeLayer7241(v)];logged++;if(q.count<4900)for(UIView *c in v.subviews)[q addObject:@{@"v":c,@"d":@(d+1)}];}[m appendFormat:@"CART_NATIVE_COUNTS phase=%@ visited=%lu logged=%lu onscreen=%lu\n",phase?:@"?",(unsigned long)visited,(unsigned long)logged,(unsigned long)onscreen];} @catch(NSException *e){[m appendFormat:@"CART_NATIVE_EXCEPTION %@\n",e];} return m;
}
static void ADCartProbeEvalAppend7241(WKWebView *wv,NSString *path,NSString *js,NSString *label,void (^done)(void)){
    [wv evaluateJavaScript:js completionHandler:^(id result,NSError *error){ if([result isKindOfClass:[NSString class]])ADCartProbeAppend7241(path,(NSString *)result);else ADCartProbeAppend7241(path,[NSString stringWithFormat:@"%@_EVAL_ERROR %@\n",label?:@"JS",error.localizedDescription?:@"non-string"]); if(done)dispatch_async(dispatch_get_main_queue(),done); }];
}
static void ADCaptureCartProbe7241(NSString *trigger){
    if(!gP.enabled||gADCartProbeBusy7241)return;
    gADCartProbeBusy7241=YES;

    if(!gADCartTransitionArmed7310){
        NSUInteger run=++gADCartProbeRun7241; NSString *path=ADCartProbePath7241(run);
        ADCartProbeAppend7241(path,[NSString stringWithFormat:@"AMAZONDARK v7.336 SHOPPING CART TRANSITION FORENSICS PROBE\nversion=%s\nstage=ARM\ntrigger=%@\ndate=%@\nfile=%@\ncap_bytes=%llu\nclassification=Cart is a WKWebView document; target signatures #cart-page/#sc-active-cart/#sc-saved-cart plus Cart URL path\npolicy=no visible text strings, no aria-label/alt/value contents, no href/src URLs, no network payloads; technical ids/classes/testids/component attributes and privacy-safe hashes retained\nrecorder=45-second explicit-arm window; same-origin reload-persistent bounded ring; frame hit-test stacks; computed background/border/outline/shadow/pseudo paint; exact bright/loading candidates; matched CSS rules; stylesheet inventory; DOM mutation summaries; animation/transition/performance events; final full DOM plus native UIKit/WebKit snapshots\nnormal_runtime=bridge is inert outside an explicit Cart arm; no recurring production scan/listener/observer/timer/RAF\nworkflow=after this ARM completes, immediately reproduce the exact Cart refresh or tab transition; after the page settles (or take a screenshot during the white state), trigger once more to EXPORT\n",AD_VERSION,trigger?:@"unknown",[NSDate date],path.lastPathComponent,kADCartProbeCap7241]);
        ADCartProbeFindWebView7241(path,^(WKWebView *wv,NSString *meta){
            if(!wv||ADCartProbeScore7241(meta)<=0){
                ADCartProbeAppend7241(path,[NSString stringWithFormat:@"CART_ARM_NO_TARGET meta=%@\nCART_TRANSITION_PROBE_END reason=no-target\n================ END RUN ================\n",ADCartProbeSafe7241(meta)]);
                gADCartProbeBusy7241=NO; return;
            }
            CGRect wr=CGRectZero; @try { wr=[wv convertRect:wv.bounds toView:nil]; } @catch(...) {}
            ADCartProbeAppend7241(path,[NSString stringWithFormat:@"ARM_TARGET ptr=%p meta=%@ frame=(%.1f,%.1f %.1fx%.1f) offset=(%.1f,%.1f) nativeContent=(%.1fx%.1f)\n",wv,ADCartProbeSafe7241(meta),wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,wv.scrollView.contentOffset.x,wv.scrollView.contentOffset.y,wv.scrollView.contentSize.width,wv.scrollView.contentSize.height]);
            ADCartProbeAppend7241(path,ADCartNativeSnapshot7241(wv.window?:wv,wv,@"arm"));
            NSString *token=[NSString stringWithFormat:@"r%lu-%llu",(unsigned long)run,(unsigned long long)(NSDate.date.timeIntervalSince1970*1000.0)];
            NSString *arm=[NSString stringWithFormat:@"%@\n(function(){try{return window.__adCartTransitionArm7310?window.__adCartTransitionArm7310('%@'):'ARM_BRIDGE_MISSING'}catch(e){return 'ARM_EVAL_ERROR '+String(e&&e.name||'error')}})();",ADCartTransitionBridgeJS7310(),token];
            [wv evaluateJavaScript:arm completionHandler:^(id result,NSError *error){
                NSString *r=[result isKindOfClass:[NSString class]]?(NSString *)result:@"(non-string)";
                BOOL ok=!error&&[r hasPrefix:@"ARMED"];
                ADCartProbeAppend7241(path,[NSString stringWithFormat:@"ARM_RESULT ok=%d error=%@ result=%@\nARM_READY reproduce-now=1 window-seconds=45\n",ok?1:0,error?ADCartProbeSafe7241(error.localizedDescription):@"none",ADCartProbeSafe7241(r)]);
                if(ok){gADCartTransitionArmed7310=YES;gADCartTransitionPath7310=path;gADCartTransitionWebView7310=wv;}
                else ADCartProbeAppend7241(path,@"CART_TRANSITION_PROBE_END reason=arm-failed\n================ END RUN ================\n");
                gADCartProbeBusy7241=NO;
            }];
        });
        return;
    }

    NSString *path=gADCartTransitionPath7310;
    if(!path.length){
        gADCartTransitionArmed7310=NO; gADCartTransitionWebView7310=nil;
        gADCartProbeBusy7241=NO; return;
    }
    ADCartProbeAppend7241(path,[NSString stringWithFormat:@"\n===== EXPORT TRIGGER =====\nstage=EXPORT trigger=%@ date=%@\n",trigger?:@"unknown",[NSDate date]]);
    ADCartProbeFindWebView7241(path,^(WKWebView *found,NSString *meta){
        WKWebView *wv=(found&&ADCartProbeScore7241(meta)>0)?found:gADCartTransitionWebView7310;
        if(!wv){
            ADCartProbeAppend7241(path,[NSString stringWithFormat:@"CART_EXPORT_NO_TARGET meta=%@\nCART_TRANSITION_PROBE_END reason=export-no-target\n================ END RUN ================\n",ADCartProbeSafe7241(meta)]);
            gADCartTransitionArmed7310=NO;gADCartTransitionPath7310=nil;gADCartTransitionWebView7310=nil;gADCartProbeBusy7241=NO;return;
        }
        CGRect wr=CGRectZero; @try { wr=[wv convertRect:wv.bounds toView:nil]; } @catch(...) {}
        ADCartProbeAppend7241(path,[NSString stringWithFormat:@"EXPORT_TARGET ptr=%p meta=%@ frame=(%.1f,%.1f %.1fx%.1f) offset=(%.1f,%.1f) nativeContent=(%.1fx%.1f)\n",wv,ADCartProbeSafe7241(meta),wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,wv.scrollView.contentOffset.x,wv.scrollView.contentOffset.y,wv.scrollView.contentSize.width,wv.scrollView.contentSize.height]);
        ADCartProbeAppend7241(path,ADCartNativeSnapshot7241(wv.window?:wv,wv,@"export"));
        NSString *exportJS=[NSString stringWithFormat:@"%@\n(function(){try{return window.__adCartTransitionExport7310?window.__adCartTransitionExport7310():'EXPORT_BRIDGE_MISSING'}catch(e){return 'EXPORT_EVAL_ERROR '+String(e&&e.name||'error')}})();",ADCartTransitionBridgeJS7310()];
        [wv evaluateJavaScript:exportJS completionHandler:^(id result,NSError *error){
            ADCartProbeAppend7241(path,[NSString stringWithFormat:@"EXPORT_RESULT error=%@\n",error?ADCartProbeSafe7241(error.localizedDescription):@"none"]);
            if([result isKindOfClass:[NSString class]])ADCartProbeAppend7241(path,[(NSString *)result stringByAppendingString:@"\n"]);
            else ADCartProbeAppend7241(path,@"TRANSITION_LOG_UNAVAILABLE\n");
            ADCartProbeEvalAppend7241(wv,path,ADCartProbeDOMJS7241(999,YES),@"FINAL_FULL_DOM",^{
                NSString *clear=@"(function(){try{return window.__adCartTransitionClear7310?window.__adCartTransitionClear7310():'CLEAR_BRIDGE_MISSING'}catch(e){return 'CLEAR_EVAL_ERROR'}})();";
                [wv evaluateJavaScript:clear completionHandler:^(__unused id cleared,__unused NSError *clearError){
                    ADCartProbeAppend7241(path,[NSString stringWithFormat:@"CART_TRANSITION_PROBE_END reason=exported finalOffset=(%.1f,%.1f) finalContent=(%.1fx%.1f)\n================ END RUN ================\n",wv.scrollView.contentOffset.x,wv.scrollView.contentOffset.y,wv.scrollView.contentSize.width,wv.scrollView.contentSize.height]);
                    gADCartTransitionArmed7310=NO;gADCartTransitionPath7310=nil;gADCartTransitionWebView7310=nil;gADCartProbeBusy7241=NO;
                }];
            });
        }];
    });
}

// v7.255 Hamburger/Menu UI forensics probe. Historical builds expose the tab as
// ANXTabBarButton#menuTab, while the pane may be WebKit, React/native, or hybrid.
// The subsystem is dormant until screenshot/SIGUSR2 and restores every scroll position.
static NSUInteger gADMenuProbeRun7252=0;
static BOOL gADMenuProbeBusy7252=NO;
static const unsigned long long kADMenuProbeCap7252=64ULL*1024ULL*1024ULL;

static NSString *ADMenuProbeSafe7252(NSString *x){
    if(!x.length)return @"";
    @try {
        NSString *s=[x stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
        s=[s stringByReplacingOccurrencesOfString:@"\"" withString:@"'"];
        s=[s stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        s=[s stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
        if(s.length>220)s=[[s substringToIndex:220] stringByAppendingString:@"…"];
        return s;
    } @catch(...) { return @"?"; }
}
static NSString *ADMenuProbeColor7252(UIColor *c){
    if(!c)return @"nil";
    @try { CGFloat r=0,g=0,b=0,a=0,w=0; if([c getRed:&r green:&g blue:&b alpha:&a])return [NSString stringWithFormat:@"rgba(%.3f,%.3f,%.3f,%.3f)",r,g,b,a]; if([c getWhite:&w alpha:&a])return [NSString stringWithFormat:@"white(%.3f,%.3f)",w,a]; return [NSString stringWithFormat:@"%@",c]; } @catch(...) { return @"?"; }
}
static NSString *ADMenuProbeCG7252(CGColorRef c){ if(!c)return @"nil"; @try { return ADMenuProbeColor7252([UIColor colorWithCGColor:c]); } @catch(...) { return @"?"; } }
static NSString *ADMenuProbeChain7252(UIView *v){
    NSMutableArray<NSString *> *a=[NSMutableArray array]; @try { for(UIView *n=v;n&&a.count<12;n=n.superview){ NSString *cn=NSStringFromClass(n.class)?:@"?",*aid=ADMenuProbeSafe7252(n.accessibilityIdentifier); [a addObject:aid.length?[NSString stringWithFormat:@"%@#%@",cn,aid]:cn]; } } @catch(...) {} return [a componentsJoinedByString:@"<-"];
}
static NSString *ADMenuProbeText7252(UIView *v){
    if(!v)return @"text=0";
    @try {
        NSTextStorage *ts=ADPersonTextStorage7206(v);
        if(ts&&ts.length){ NSMutableArray<NSString *> *runs=[NSMutableArray array]; [ts enumerateAttributesInRange:NSMakeRange(0,ts.length) options:0 usingBlock:^(NSDictionary *attrs,NSRange range,BOOL *stop){ if(runs.count>=16){*stop=YES;return;} UIColor *fg=attrs[NSForegroundColorAttributeName],*bg=attrs[NSBackgroundColorAttributeName]; UIFont *font=attrs[NSFontAttributeName]; [runs addObject:[NSString stringWithFormat:@"%lu:%lu:fg=%@:bg=%@:font=%@/%.1f",(unsigned long)range.location,(unsigned long)range.length,ADMenuProbeColor7252(fg),ADMenuProbeColor7252(bg),font.fontName?:@"nil",font?font.pointSize:0.0]]; }]; return [NSString stringWithFormat:@"text=1 kind=rct len=%lu runs=[%@]",(unsigned long)ts.length,[runs componentsJoinedByString:@";"]]; }
        if([v isKindOfClass:[UILabel class]]){ UILabel *l=(UILabel *)v; return [NSString stringWithFormat:@"text=1 kind=label len=%lu color=%@ font=%@/%.1f lines=%ld align=%ld break=%ld",(unsigned long)l.text.length,ADMenuProbeColor7252(l.textColor),l.font.fontName?:@"nil",l.font.pointSize,(long)l.numberOfLines,(long)l.textAlignment,(long)l.lineBreakMode]; }
    } @catch(...) {}
    NSString *cn=NSStringFromClass(v.class)?:@""; BOOL textish=[cn rangeOfString:@"Text" options:NSCaseInsensitiveSearch].location!=NSNotFound||[cn rangeOfString:@"Paragraph" options:NSCaseInsensitiveSearch].location!=NSNotFound; return textish?@"text=1 storage=none":@"text=0";
}
static NSString *ADMenuProbeRCT7252(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return @"rct=0";
    @try { const char *wn[]={"borderWidth","borderTopWidth","borderRightWidth","borderBottomWidth","borderLeftWidth"}; const char *cn[]={"borderColor","borderTopColor","borderRightColor","borderBottomColor","borderLeftColor"}; const char *rn[]={"borderRadius","borderTopLeftRadius","borderTopRightRadius","borderBottomLeftRadius","borderBottomRightRadius"}; NSMutableArray *a=[NSMutableArray array]; for(size_t i=0;i<sizeof(wn)/sizeof(*wn);i++){SEL q=sel_registerName(wn[i]);if([v respondsToSelector:q]){CGFloat x=((CGFloat(*)(id,SEL))objc_msgSend)(v,q);[a addObject:[NSString stringWithFormat:@"%s=%.2f",wn[i],x]];}} for(size_t i=0;i<sizeof(cn)/sizeof(*cn);i++){SEL q=sel_registerName(cn[i]);if([v respondsToSelector:q]){id x=((id(*)(id,SEL))objc_msgSend)(v,q);[a addObject:[NSString stringWithFormat:@"%s=%@",cn[i],[x isKindOfClass:[UIColor class]]?ADMenuProbeColor7252(x):[NSString stringWithFormat:@"%@",x]]];}} for(size_t i=0;i<sizeof(rn)/sizeof(*rn);i++){SEL q=sel_registerName(rn[i]);if([v respondsToSelector:q]){CGFloat x=((CGFloat(*)(id,SEL))objc_msgSend)(v,q);[a addObject:[NSString stringWithFormat:@"%s=%.2f",rn[i],x]];}} return [NSString stringWithFormat:@"rct=1 [%@]",[a componentsJoinedByString:@","]]; } @catch(...) { return @"rct=1 err=1"; }
}
static NSString *ADMenuProbeImage7252(UIView *v){
    if(![v isKindOfClass:[UIImageView class]])return @"img=0";
    @try { UIImageView *iv=(UIImageView *)v; UIImage *im=iv.image; size_t pxw=0,pxh=0; if(im.CGImage){pxw=CGImageGetWidth(im.CGImage);pxh=CGImageGetHeight(im.CGImage);} CALayer *twb=objc_getAssociatedObject(iv,kADTWBOverlay); return [NSString stringWithFormat:@"img=1 has=%d mode=%ld pts=(%.1fx%.1f) px=(%zux%zu) scale=%.2f contentMode=%ld tint=%@ twb=%d",im?1:0,(long)(im?im.renderingMode:-1),im?im.size.width:0.0,im?im.size.height:0.0,pxw,pxh,im?im.scale:0.0,(long)iv.contentMode,ADMenuProbeColor7252(iv.tintColor),twb?1:0]; } @catch(...) { return @"img=1 err=1"; }
}
static NSString *ADMenuProbeControl7252(UIView *v){
    @try { if([v isKindOfClass:[UIControl class]]){UIControl *c=(UIControl *)v;return [NSString stringWithFormat:@"control=1 enabled=%d selected=%d highlighted=%d state=%lu",c.enabled?1:0,c.selected?1:0,c.highlighted?1:0,(unsigned long)c.state];} if([v isKindOfClass:[UIScrollView class]]){UIScrollView *sv=(UIScrollView *)v;return [NSString stringWithFormat:@"scroll=1 offset=(%.1f,%.1f) content=(%.1fx%.1f) inset=(%.1f,%.1f,%.1f,%.1f) enabled=%d hInd=%d vInd=%d style=%ld",sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height,sv.adjustedContentInset.top,sv.adjustedContentInset.left,sv.adjustedContentInset.bottom,sv.adjustedContentInset.right,sv.scrollEnabled?1:0,sv.showsHorizontalScrollIndicator?1:0,sv.showsVerticalScrollIndicator?1:0,(long)sv.indicatorStyle];} } @catch(...) {} return @"control=0";
}
static NSString *ADMenuProbeLayer7252(UIView *v){
    if(!v)return @"layers=0"; @try {CALayer *root=v.layer;NSMutableArray<CALayer *> *q=[NSMutableArray arrayWithObject:root];NSMutableArray<NSString *> *samples=[NSMutableArray array];NSUInteger seen=0,shape=0,grad=0,bordered=0,contents=0;while(q.count&&seen++<72){CALayer *l=q.firstObject;[q removeObjectAtIndex:0];if(!l)continue;if(l.contents)contents++;BOOL interesting=(l==root)||l.borderWidth>0.01||l.backgroundColor||l.mask||[l isKindOfClass:[CAShapeLayer class]]||[l isKindOfClass:[CAGradientLayer class]]||l.shadowOpacity>0.001;if(l.borderWidth>0.01)bordered++;if([l isKindOfClass:[CAShapeLayer class]])shape++;if([l isKindOfClass:[CAGradientLayer class]])grad++;if(interesting&&samples.count<12){NSString *extra=@"";if([l isKindOfClass:[CAShapeLayer class]]){CAShapeLayer *sh=(CAShapeLayer *)l;extra=[NSString stringWithFormat:@":shape(f=%@ s=%@ lw=%.2f dash=%@)",ADMenuProbeCG7252(sh.fillColor),ADMenuProbeCG7252(sh.strokeColor),sh.lineWidth,sh.lineDashPattern?:@[]];}else if([l isKindOfClass:[CAGradientLayer class]]){CAGradientLayer *g=(CAGradientLayer *)l;NSMutableArray *cs=[NSMutableArray array];for(id c in g.colors?:@[])[cs addObject:ADMenuProbeCG7252((__bridge CGColorRef)c)];extra=[NSString stringWithFormat:@":grad(%@)",[cs componentsJoinedByString:@"/"]];}[samples addObject:[NSString stringWithFormat:@"%@ name=%@ f=(%.1f,%.1f %.1fx%.1f) bg=%@ bw=%.2f bc=%@ cr=%.2f op=%.2f z=%.1f mask=%d contents=%d shadow=%@/%.2f/%.2f%@",NSStringFromClass(l.class),l.name?:@"nil",l.frame.origin.x,l.frame.origin.y,l.frame.size.width,l.frame.size.height,ADMenuProbeCG7252(l.backgroundColor),l.borderWidth,ADMenuProbeCG7252(l.borderColor),l.cornerRadius,l.opacity,l.zPosition,l.mask?1:0,l.contents?1:0,ADMenuProbeCG7252(l.shadowColor),l.shadowOpacity,l.shadowRadius,extra]];}if(seen<52)for(CALayer *c in l.sublayers?:@[])[q addObject:c];}return [NSString stringWithFormat:@"layers=%lu shape=%lu grad=%lu bordered=%lu contents=%lu maskToBounds=%d samples=[%@]",(unsigned long)seen,(unsigned long)shape,(unsigned long)grad,(unsigned long)bordered,(unsigned long)contents,root.masksToBounds?1:0,[samples componentsJoinedByString:@" || "]];} @catch(...) {return @"layers=1 err=1";}
}
static BOOL ADMenuProbeIsDescendant7252(UIView *v,UIView *ancestor){ if(!v||!ancestor)return NO; @try {for(UIView *n=v;n;n=n.superview)if(n==ancestor)return YES;} @catch(...) {} return NO; }
static BOOL ADMenuProbeIsAncestor7252(UIView *v,UIView *child){ return ADMenuProbeIsDescendant7252(child,v); }

static void ADMenuProbeAppend7252(NSString *path,NSString *text){
    if(!path.length||!text.length)return; @try {NSFileManager *fm=[NSFileManager defaultManager];[fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];unsigned long long cur=[[[fm attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] unsignedLongLongValue];if(cur>=kADMenuProbeCap7252)return;NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding];unsigned long long remain=kADMenuProbeCap7252-cur;if((unsigned long long)d.length>remain)d=[d subdataWithRange:NSMakeRange(0,(NSUInteger)remain)];if(![fm fileExistsAtPath:path]){[d writeToFile:path atomically:YES];return;}NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:path];if(h){[h seekToEndOfFile];[h writeData:d];[h closeFile];}} @catch(...) {}
}
static NSString *ADMenuProbePath7252(NSUInteger run){
    @try {NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.timeZone=[NSTimeZone localTimeZone];f.dateFormat=@"yyyyMMdd-HHmmss-SSS";NSString *stamp=[f stringFromDate:[NSDate date]]?:@"unknown",*name=[NSString stringWithFormat:@"AmazonDark-v7.336-menu-ui-probe-%@-r%lu.txt",stamp,(unsigned long)run];NSString *docs=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject];return [(docs.length?docs:NSTemporaryDirectory()) stringByAppendingPathComponent:name];} @catch(...) {return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"AmazonDark-v7.336-menu-ui-probe-r%lu.txt",(unsigned long)run]];}
}
static NSString *ADMenuProbeDetectJS7252(void){
    return
        @"(function(){try{var d=document,p=String(location.pathname||'').toLowerCase(),se=d.scrollingElement||d.documentElement||d.body;"
        @"var q='[id*=\\\"menu\\\" i],[class*=\\\"menu\\\" i],[data-testid*=\\\"menu\\\" i],[data-component-type*=\\\"menu\\\" i],[data-csa-c-content-id*=\\\"menu\\\" i],[id*=\\\"hmenu\\\" i],[class*=\\\"hmenu\\\" i],[id*=\\\"department\\\" i],[class*=\\\"department\\\" i],[id*=\\\"program\\\" i],[class*=\\\"program\\\" i],[id*=\\\"setting\\\" i],[class*=\\\"setting\\\" i],[id*=\\\"customer-service\\\" i],[class*=\\\"customer-service\\\" i]';"
        @"var tech=0;try{tech=d.querySelectorAll(q).length}catch(_){tech=0}var h=!!d.querySelector('#hmenu-canvas,[class*=\\\"hmenu\\\" i],[id*=\\\"hmenu\\\" i]');"
        @"var mr=!!d.querySelector('[id*=\\\"menu\\\" i],[class*=\\\"menu\\\" i],[data-testid*=\\\"menu\\\" i]');var pathMenu=/menu|hmenu|hamburger|nav/.test(p);"
        @"var score=Math.min(500,tech*14)+(h?420:0)+(mr?160:0)+(pathMenu?180:0);return 'score='+score+' tech='+tech+' hmenu='+(h?1:0)+' menuRoot='+(mr?1:0)+' pathMenu='+(pathMenu?1:0)+' ready='+String(d.readyState||'')+' scrollH='+(se?Math.round(se.scrollHeight||0):0)+' clientH='+(se?Math.round(se.clientHeight||0):0)+' nodes='+(d.getElementsByTagName('*').length||0)+' frames='+(d.getElementsByTagName('iframe').length||0)+' stylesheets='+d.styleSheets.length+' ad7='+(d.getElementById('ad7-static-theme')?1:0)+' twb='+(d.getElementById('ad7-product-feed-twb')||d.getElementById('ad7-menu-twb')||d.getElementById('ad7-search-pane-twb')?1:0);}catch(e){return 'score=0 error=1';}})();";
}
static NSString *ADMenuProbeDOMJS7252(NSUInteger step,BOOL full){
    static NSString *base=nil; static dispatch_once_t once; dispatch_once(&once,^{ base=
        @"(function(){try{var STEP=__STEP__,FULL=__FULL__,d=document,w=window,de=d.documentElement||{},se=d.scrollingElement||de||d.body;var sx=Number(w.scrollX||se.scrol"
        @"lLeft||0),sy=Number(w.scrollY||se.scrollTop||0),vw=Number(w.innerWidth||de.clientWidth||0),vh=Number(w.innerHeight||de.clientHeight||0);var LO=sy-140,HI=sy+vh+1"
        @"40,MAX=FULL?6200:2600,out=[],visited=0,emitted=0,trunc=0;function clean(v,n){v=String(v==null?'':v).replace(/[\\r\\n\\t]+/g,' ').replace(/\\|/g,'¦').replace(/\\"
        @"\\/g,'/');n=n||180;return v.length>n?v.slice(0,n)+'…':v}function hash(s){s=String(s||'');var h=2166136261>>>0;for(var i=0;i<s.length;i++){h^=s.charCodeAt(i);h=M"
        @"ath.imul(h,16777619)}return (h>>>0).toString(16)}function cls(e){var c='';try{c=typeof e.className==='string'?e.className:(e.className&&e.className.baseVal)||''"
        @"}catch(_){ }return clean(c,220)}function sig(e){var z=String(e.tagName||e.nodeName||'?').toLowerCase(),i='';try{i=e.id||''}catch(_){ }var c=cls(e).trim().split("
        @"/\\s+/).filter(Boolean).slice(0,3).join('.');return z+(i?'#'+clean(i,90):'')+(c?'.'+clean(c,100):'')}function chain(e){var a=[],x=e;for(var n=0;x&&n<8;n++){a.pu"
        @"sh(sig(x));if(x.parentElement){x=x.parentElement;continue}var r=x.getRootNode&&x.getRootNode();x=r&&r.host?r.host:null}return a.join('<-')}function attr(e,n,lim"
        @"){try{var v=e.getAttribute(n);return v==null?'':clean(v,lim||150)}catch(_){return ''}}function boolAttr(e,n){try{return e.hasAttribute(n)?1:0}catch(_){return 0}"
        @"}function kind(v){v=String(v||'');if(!v||v==='none')return 'none';if(/gradient/i.test(v))return 'gradient';if(/url\\(/i.test(v))return 'url';return clean(v,45)}"
        @"function textInfo(e){var own='';try{for(var i=0;i<e.childNodes.length;i++){var n=e.childNodes[i];if(n.nodeType===3)own+=n.nodeValue||''}}catch(_){ }own=own.trim"
        @"();var all='';try{all=(e.innerText||e.textContent||'').trim()}catch(_){ }if(all.length>12000)all=all.slice(0,12000);return ' ownText='+own.length+'/'+hash(own)+"
        @"' allText='+all.length+'/'+hash(all)}function pseudo(e,p){try{var c=getComputedStyle(e,p),ct=String(c.content||'');if((!ct||ct==='none'||ct==='normal')&&c.backg"
        @"roundColor==='rgba(0, 0, 0, 0)'&&c.backgroundImage==='none'&&parseFloat(c.borderTopWidth||0)===0&&parseFloat(c.width||0)===0&&parseFloat(c.height||0)===0)return"
        @" '';return ' '+p.slice(2)+'={ct='+ct.length+'/'+hash(ct)+' fg='+clean(c.color,45)+' bg='+clean(c.backgroundColor,45)+' bgImg='+kind(c.backgroundImage)+' wh='+cl"
        @"ean(c.width,25)+'x'+clean(c.height,25)+' b='+clean(c.borderTopWidth,15)+'/'+clean(c.borderTopColor,45)+' rad='+clean(c.borderRadius,35)+' fill='+clean(c.fill,45"
        @")+' stroke='+clean(c.stroke,45)+'}'}catch(_){return ''}}function tech(e){var names=['role','data-testid','data-component-type','data-csa-c-type','data-csa-c-con"
        @"tent-id','data-csa-c-slot-id','data-csa-c-painter','data-cel-widget','cel_widget_id','name','type','aria-hidden'];var a=[];for(var i=0;i<names.length;i++){var v"
        @"=attr(e,names[i]);if(v)a.push(names[i]+'='+v)}var asin=attr(e,'data-asin',40);if(asin)a.push('data-asin='+asin.length+'/'+hash(asin));if(boolAttr(e,'href'))a.pu"
        @"sh('href=1');if(boolAttr(e,'src'))a.push('src=1');var al=attr(e,'aria-label',1);try{var av=e.getAttribute('aria-label');if(av!=null)a.push('ariaLabel='+String(a"
        @"v).length+'/'+hash(av))}catch(_){ }try{var alt=e.getAttribute('alt');if(alt!=null)a.push('alt='+String(alt).length+'/'+hash(alt))}catch(_){ }try{if('value' in e"
        @"&&e.value!=null)a.push('value='+String(e.value).length+'/'+hash(e.value))}catch(_){ }try{if('checked' in e)a.push('checked='+(e.checked?1:0));if('selected' in e"
        @")a.push('selected='+(e.selected?1:0));if('disabled' in e)a.push('disabled='+(e.disabled?1:0))}catch(_){ }return a.join(',')}function media(e,c){var t=String(e.t"
        @"agName||'').toUpperCase();try{if(t==='IMG')return ' media=img('+Number(e.naturalWidth||0)+'x'+Number(e.naturalHeight||0)+' complete='+(e.complete?1:0)+' loading"
        @"='+clean(e.loading,20)+' fit='+clean(c.objectFit,30)+' pos='+clean(c.objectPosition,40)+')';if(t==='VIDEO')return ' media=video('+Number(e.videoWidth||0)+'x'+Nu"
        @"mber(e.videoHeight||0)+' paused='+(e.paused?1:0)+' muted='+(e.muted?1:0)+')';if(t==='CANVAS')return ' media=canvas('+Number(e.width||0)+'x'+Number(e.height||0)+"
        @"')';if(t==='SVG'||e instanceof SVGElement){var vb='';try{vb=e.getAttribute('viewBox')||''}catch(_){ }return ' media=svg(viewBox='+clean(vb,60)+' paths='+(e.quer"
        @"ySelectorAll?e.querySelectorAll('path').length:0)+' uses='+(e.querySelectorAll?e.querySelectorAll('use').length:0)+')'}}catch(_){ }return ''}function emit(e,sco"
        @"pe){if(emitted>=MAX){trunc=1;return}visited++;var r;try{r=e.getBoundingClientRect()}catch(_){return}var c;try{c=getComputedStyle(e)}catch(_){return}var docY=r.t"
        @"op+sy,near=(r.width>0.1&&r.height>0.1&&docY+r.height>=LO&&docY<=HI),sticky=(c.position==='fixed'||c.position==='sticky');if(!FULL&&!near&&!sticky)return;var id="
        @"'',cl='';try{id=e.id||'';cl=cls(e)}catch(_){ }var ti=tech(e);out.push('D step='+STEP+' scope='+scope+' n='+emitted+' tag='+String(e.tagName||e.nodeName||'?').to"
        @"LowerCase()+' id=\"'+clean(id,120)+'\" class=\"'+clean(cl,220)+'\" chain=\"'+clean(chain(e),520)+'\" vp=('+r.left.toFixed(1)+','+r.top.toFixed(1)+' '+r.width.to"
        @"Fixed(1)+'x'+r.height.toFixed(1)+') doc=('+Number(r.left+sx).toFixed(1)+','+Number(docY).toFixed(1)+') scroll=('+Number(e.scrollLeft||0).toFixed(1)+','+Number(e"
        @".scrollTop||0).toFixed(1)+' '+Number(e.scrollWidth||0).toFixed(1)+'x'+Number(e.scrollHeight||0).toFixed(1)+') children='+Number(e.childElementCount||0)+' disp='"
        @"+clean(c.display,28)+' vis='+clean(c.visibility,28)+' op='+clean(c.opacity,12)+' pos='+clean(c.position,20)+' z='+clean(c.zIndex,20)+' ov='+clean(c.overflowX,20"
        @")+'/'+clean(c.overflowY,20)+' pointer='+clean(c.pointerEvents,20)+' fg='+clean(c.color,52)+' textFill='+clean(c.webkitTextFillColor,52)+' bg='+clean(c.backgroun"
        @"dColor,52)+' bgImg='+kind(c.backgroundImage)+' mask='+kind(c.webkitMaskImage||c.maskImage)+' border='+clean(c.borderTopWidth,14)+'/'+clean(c.borderTopColor,52)+"
        @"','+clean(c.borderRightWidth,14)+'/'+clean(c.borderRightColor,52)+','+clean(c.borderBottomWidth,14)+'/'+clean(c.borderBottomColor,52)+','+clean(c.borderLeftWidt"
        @"h,14)+'/'+clean(c.borderLeftColor,52)+' rad='+clean(c.borderRadius,70)+' outline='+clean(c.outlineWidth,14)+'/'+clean(c.outlineColor,52)+' shadow='+clean(c.boxS"
        @"hadow,120)+' font='+clean(c.fontFamily,70)+'/'+clean(c.fontSize,24)+'/'+clean(c.fontWeight,24)+' line='+clean(c.lineHeight,24)+' align='+clean(c.textAlign,24)+'"
        @" deco='+clean(c.textDecorationLine,30)+' fill='+clean(c.fill,52)+' stroke='+clean(c.stroke,52)+' sw='+clean(c.strokeWidth,20)+' filter='+clean(c.filter,80)+' bl"
        @"end='+clean(c.mixBlendMode,24)+' isolate='+clean(c.isolation,24)+' transform='+clean(c.transform,100)+(ti?' attrs=['+ti+']':'')+textInfo(e)+media(e,c)+pseudo(e,"
        @"'::before')+pseudo(e,'::after'));emitted++;try{if(e.shadowRoot){scan(e.shadowRoot,'shadow:'+sig(e))}}catch(_){ }}function scan(root,scope){var a=[];try{a=root.q"
        @"uerySelectorAll('*')}catch(_){return}for(var i=0;i<a.length&&emitted<MAX;i++)emit(a[i],scope)}out.push('DOM_BEGIN step='+STEP+' full='+(FULL?1:0)+' ready='+Stri"
        @"ng(d.readyState||'')+' viewport='+vw+'x'+vh+' scroll='+sx+','+sy+' scrollSize='+Number(se?se.scrollWidth:0)+'x'+Number(se?se.scrollHeight:0)+' nodes='+d.getElem"
        @"entsByTagName('*').length+' frames='+d.getElementsByTagName('iframe').length+' stylesheets='+d.styleSheets.length+' ad7='+(d.getElementById('ad7-static-theme')?"
        @"1:0));scan(d,'main');var ifr=d.getElementsByTagName('iframe');for(var fi=0;fi<ifr.length&&emitted<MAX;fi++){try{var fd=ifr[fi].contentDocument;if(fd)scan(fd,'fr"
        @"ame'+fi);else out.push('FRAME step='+STEP+' index='+fi+' accessible=0')}catch(_){out.push('FRAME step='+STEP+' index='+fi+' accessible=0')}}out.push('DOM_END st"
        @"ep='+STEP+' full='+(FULL?1:0)+' visited='+visited+' emitted='+emitted+' truncated='+trunc);return out.join('\\n')+'\\n';}catch(e){return 'DOM_EXCEPTION '+String"
        @"(e&&e.message||e)+'\\n';}})();"; });
    NSString *js=[base stringByReplacingOccurrencesOfString:@"__STEP__" withString:[NSString stringWithFormat:@"%lu",(unsigned long)step]];
    return [js stringByReplacingOccurrencesOfString:@"__FULL__" withString:(full?@"true":@"false")];
}
static NSInteger ADMenuProbeScore7252(id result){
    if(![result isKindOfClass:[NSString class]])return 0; NSString *s=(NSString *)result; NSRange r=[s rangeOfString:@"score="]; if(r.location==NSNotFound)return 0; NSString *tail=[s substringFromIndex:NSMaxRange(r)]; return [tail integerValue];
}
static NSArray<WKWebView *> *ADMenuProbeWebViews7252(void){
    NSMutableOrderedSet<WKWebView *> *set=[NSMutableOrderedSet orderedSet]; @try {for(WKWebView *wv in ADTrackedWebViews())if(wv)[set addObject:wv];for(UIWindow *w in UIApplication.sharedApplication.windows){if(!w||w.hidden||w.alpha<0.01)continue;NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:w];NSUInteger seen=0;while(q.count&&seen++<5000){UIView *v=q.firstObject;[q removeObjectAtIndex:0];if([v isKindOfClass:[WKWebView class]])[set addObject:(WKWebView *)v];if(q.count<4700)for(UIView *c in v.subviews)[q addObject:c];}}} @catch(...) {} return set.array?:@[];
}

// v7.252 Hamburger/Menu forensics: hybrid discovery rather than assuming a renderer.
// Historical Amazon builds expose the bottom tab as ANXTabBarButton#menuTab, while Menu
// content has moved between server-driven WebKit and native/React surfaces. A trigger therefore
// inventories both lanes, then performs a finite full-scroll walk on every plausible active lane.
static BOOL ADMenuProbeEffectiveVisible7252(UIView *v){
    if(!v||!v.window)return NO;
    @try { for(UIView *n=v;n;n=n.superview){ if(n.hidden||n.alpha<0.01)return NO; } } @catch(...) { return NO; }
    return YES;
}
static BOOL ADMenuProbeHasAncestorClass7252(UIView *v,NSString *token){
    if(!v||!token.length)return NO;
    @try { for(UIView *n=v;n;n=n.superview){ if([NSStringFromClass(n.class) rangeOfString:token options:NSCaseInsensitiveSearch].location!=NSNotFound)return YES; } } @catch(...) {}
    return NO;
}
static UIControl *ADMenuProbeTab7252(void){
    @try {
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.01)continue;
            NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:w]; NSUInteger seen=0;
            while(q.count&&seen++<5000){ UIView *v=q.firstObject; [q removeObjectAtIndex:0];
                if([v.accessibilityIdentifier isEqualToString:@"menuTab"] && [v isKindOfClass:[UIControl class]])return (UIControl *)v;
                if(q.count<4700)for(UIView *c in v.subviews)[q addObject:c];
            }
        }
    } @catch(...) {}
    return nil;
}
static void ADMenuProbeLogTab7252(NSString *path){
    UIControl *tab=ADMenuProbeTab7252();
    if(!tab){ ADMenuProbeAppend7252(path,@"MENU_TAB found=0\n"); return; }
    CGRect r=CGRectZero; @try {r=[tab convertRect:tab.bounds toView:nil];} @catch(...) {}
    ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"MENU_TAB found=1 ptr=%p cls=%@ aid=menuTab selected=%d enabled=%d highlighted=%d state=%lu frame=(%.1f,%.1f %.1fx%.1f) tint=%@\n",tab,NSStringFromClass(tab.class),tab.selected?1:0,tab.enabled?1:0,tab.highlighted?1:0,(unsigned long)tab.state,r.origin.x,r.origin.y,r.size.width,r.size.height,ADMenuProbeColor7252(tab.tintColor)]);
}
static void ADMenuProbeFindWebView7252(NSString *path,void (^done)(WKWebView *,NSString *)){
    NSArray<WKWebView *> *views=ADMenuProbeWebViews7252(); if(!views.count){done(nil,@"no-webviews");return;}
    __block NSUInteger idx=0; __block NSInteger bestScore=NSIntegerMin; __block CGFloat bestArea=0; __block WKWebView *best=nil; __block NSString *bestMeta=@""; __block void (^next)(void)=nil;
    next=^{
        if(idx>=views.count){WKWebView *winner=best;NSString *meta=bestMeta;next=nil;done(winner,meta);return;}
        WKWebView *wv=views[idx];NSUInteger thisIdx=idx++;CGRect wr=CGRectZero;@try{wr=[wv convertRect:wv.bounds toView:nil];}@catch(...){}
        CGFloat area=MAX(0.0,wr.size.width)*MAX(0.0,wr.size.height); BOOL visible=ADMenuProbeEffectiveVisible7252(wv)&&wr.size.width>=280&&wr.size.height>=220&&CGRectIntersectsRect(wr,UIScreen.mainScreen.bounds);
        [wv evaluateJavaScript:ADMenuProbeDetectJS7252() completionHandler:^(id result,NSError *error){
            NSString *meta=[result isKindOfClass:[NSString class]]?(NSString *)result:[NSString stringWithFormat:@"score=0 error=%@",error.localizedDescription?:@"eval"];
            NSInteger semantic=ADMenuProbeScore7252(meta); NSInteger rank=visible?(semantic+1000):semantic;
            ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"WEB_CANDIDATE index=%lu ptr=%p window=%d visible=%d hidden=%d alpha=%.2f frame=(%.1f,%.1f %.1fx%.1f) nativeContent=(%.1fx%.1f) %@\n",(unsigned long)thisIdx,wv,wv.window?1:0,visible?1:0,wv.hidden?1:0,wv.alpha,wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,wv.scrollView.contentSize.width,wv.scrollView.contentSize.height,ADMenuProbeSafe7252(meta)]);
            if(visible&&(rank>bestScore||(rank==bestScore&&area>bestArea))){bestScore=rank;bestArea=area;best=wv;bestMeta=meta;}
            dispatch_async(dispatch_get_main_queue(),next);
        }];
    };
    next();
}
static UIScrollView *ADMenuProbeFindNativeScroll7252(NSString *path){
    __block UIScrollView *best=nil; __block NSInteger bestScore=NSIntegerMin; __block CGFloat bestArea=0; NSUInteger idx=0;
    @try {
        CGRect screen=UIScreen.mainScreen.bounds;
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.01)continue;
            NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:w]; NSUInteger seen=0;
            while(q.count&&seen++<7000){
                UIView *v=q.firstObject;[q removeObjectAtIndex:0];
                if([v isKindOfClass:[UIScrollView class]]){
                    UIScrollView *sv=(UIScrollView *)v; NSString *cn=NSStringFromClass(v.class)?:@"?"; CGRect wr=CGRectZero; @try{wr=[v convertRect:v.bounds toView:nil];}@catch(...){}
                    BOOL insideWeb=ADMenuProbeHasAncestorClass7252(v,@"WKWebView")||[cn rangeOfString:@"WKScroll" options:NSCaseInsensitiveSearch].location!=NSNotFound;
                    BOOL chrome=ADMenuProbeHasAncestorClass7252(v,@"ANXTabBar")||ADMenuProbeHasAncestorClass7252(v,@"Keyboard")||[cn rangeOfString:@"ScrollIndicator" options:NSCaseInsensitiveSearch].location!=NSNotFound;
                    BOOL visible=ADMenuProbeEffectiveVisible7252(v)&&CGRectIntersectsRect(wr,screen)&&wr.size.width>=280&&wr.size.height>=180;
                    BOOL scrollable=sv.contentSize.height>sv.bounds.size.height+8.0;
                    NSInteger score=0;
                    if([cn rangeOfString:@"RCTScroll" options:NSCaseInsensitiveSearch].location!=NSNotFound)score+=700;
                    if([cn rangeOfString:@"CollectionView" options:NSCaseInsensitiveSearch].location!=NSNotFound)score+=620;
                    if([cn rangeOfString:@"TableView" options:NSCaseInsensitiveSearch].location!=NSNotFound)score+=620;
                    if([cn rangeOfString:@"ScrollView" options:NSCaseInsensitiveSearch].location!=NSNotFound)score+=180;
                    if(scrollable)score+=420;
                    if(wr.size.width>=screen.size.width*0.75)score+=160;
                    if(wr.size.height>=screen.size.height*0.45)score+=160;
                    CGFloat area=MAX(0.0,wr.size.width)*MAX(0.0,wr.size.height);
                    ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"NATIVE_SCROLL_CANDIDATE index=%lu ptr=%p cls=%@ aid=\"%@\" visible=%d insideWeb=%d chrome=%d frame=(%.1f,%.1f %.1fx%.1f) offset=(%.1f,%.1f) content=(%.1fx%.1f) bounds=(%.1fx%.1f) scrollable=%d score=%ld\n",(unsigned long)idx++,sv,cn,ADMenuProbeSafe7252(v.accessibilityIdentifier),visible?1:0,insideWeb?1:0,chrome?1:0,wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height,sv.bounds.size.width,sv.bounds.size.height,scrollable?1:0,(long)score]);
                    if(visible&&!insideWeb&&!chrome&&(score>bestScore||(score==bestScore&&area>bestArea))){bestScore=score;bestArea=area;best=sv;}
                }
                if(q.count<6600)for(UIView *c in v.subviews)[q addObject:c];
            }
        }
    } @catch(...) {}
    return best;
}
static NSString *ADMenuNativeSnapshot7252(UIView *root,UIView *target,NSString *phase){
    NSMutableString *m=[NSMutableString string]; if(!root)return @"NATIVE_SNAPSHOT_NO_ROOT\n";
    @try {
        CGRect screen=UIScreen.mainScreen.bounds; [m appendFormat:@"\n===== MENU NATIVE SNAPSHOT phase=%@ root=%p target=%p =====\n",phase?:@"?",root,target];
        NSMutableArray *q=[NSMutableArray arrayWithObject:@{ @"v":root,@"d":@0 }]; NSUInteger visited=0,logged=0,onscreen=0;
        while(q.count&&visited++<6200&&logged<5200){NSDictionary *it=q.firstObject;[q removeObjectAtIndex:0];UIView *v=it[@"v"];NSUInteger d=[it[@"d"] unsignedIntegerValue];if(!v)continue;CGRect wr=CGRectZero;@try{wr=[v convertRect:v.bounds toView:nil];}@catch(...){}
            BOOL on=ADMenuProbeEffectiveVisible7252(v)&&wr.size.width>=0.25&&wr.size.height>=0.25&&CGRectIntersectsRect(wr,screen);if(on)onscreen++;
            NSString *cn=NSStringFromClass(v.class)?:@"?",*aid=ADMenuProbeSafe7252(v.accessibilityIdentifier);NSInteger rel=(v==target)?3:(ADMenuProbeIsDescendant7252(v,target)?2:(ADMenuProbeIsAncestor7252(v,target)?1:0));CGAffineTransform t=v.transform;
            [m appendFormat:@"N d=%lu ptr=%p parent=%p rel=%ld cls=%@ aid=\"%@\" win=(%.1f,%.1f %.1fx%.1f) onscreen=%d hidden=%d alpha=%.2f user=%d clips=%d transform=(%.3f,%.3f,%.3f,%.3f,%.1f,%.1f) bg=%@ layerBg=%@ tint=%@ layerBorder=%.2f/%@ radius=%.2f shadow=%@/%.2f/%.2f contents=%d subviews=%lu sublayers=%lu traits=%llu chain=\"%@\" %@ %@ %@ %@\n",(unsigned long)d,v,v.superview,(long)rel,cn,aid,wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,on?1:0,v.hidden?1:0,v.alpha,v.userInteractionEnabled?1:0,v.clipsToBounds?1:0,t.a,t.b,t.c,t.d,t.tx,t.ty,ADMenuProbeColor7252(v.backgroundColor),ADMenuProbeCG7252(v.layer.backgroundColor),ADMenuProbeColor7252(v.tintColor),v.layer.borderWidth,ADMenuProbeCG7252(v.layer.borderColor),v.layer.cornerRadius,ADMenuProbeCG7252(v.layer.shadowColor),v.layer.shadowOpacity,v.layer.shadowRadius,v.layer.contents?1:0,(unsigned long)v.subviews.count,(unsigned long)v.layer.sublayers.count,(unsigned long long)v.accessibilityTraits,ADMenuProbeChain7252(v),ADMenuProbeText7252(v),ADMenuProbeRCT7252(v),ADMenuProbeImage7252(v),ADMenuProbeControl7252(v)];
            [m appendFormat:@"NL ptr=%p %@\n",v,ADMenuProbeLayer7252(v)]; logged++; if(q.count<5800)for(UIView *c in v.subviews)[q addObject:@{ @"v":c,@"d":@(d+1) }];
        }
        [m appendFormat:@"MENU_NATIVE_COUNTS phase=%@ visited=%lu logged=%lu onscreen=%lu\n",phase?:@"?",(unsigned long)visited,(unsigned long)logged,(unsigned long)onscreen];
    } @catch(NSException *e){[m appendFormat:@"MENU_NATIVE_EXCEPTION %@\n",e];}
    return m;
}
static void ADMenuProbeEvalAppend7252(WKWebView *wv,NSString *path,NSString *js,NSString *label,void (^done)(void)){
    [wv evaluateJavaScript:js completionHandler:^(id result,NSError *error){if([result isKindOfClass:[NSString class]])ADMenuProbeAppend7252(path,(NSString *)result);else ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"%@_EVAL_ERROR %@\n",label?:@"JS",error.localizedDescription?:@"non-string"]);if(done)dispatch_async(dispatch_get_main_queue(),done);}];
}
static void ADMenuProbeScanWeb7252(WKWebView *wv,NSString *path,void (^done)(NSString *)){
    if(!wv){if(done)done(@"no-web");return;} UIScrollView *sv=wv.scrollView; CGPoint original=sv.contentOffset; BOOL originalScroll=sv.scrollEnabled; sv.scrollEnabled=NO; CGFloat viewport=MAX(1.0,sv.bounds.size.height),stride=MAX(260.0,MIN(620.0,viewport*0.60));CGRect wr=CGRectZero;@try{wr=[wv convertRect:wv.bounds toView:nil];}@catch(...){}
    ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"WEB_TARGET ptr=%p frame=(%.1f,%.1f %.1fx%.1f) originalOffset=(%.1f,%.1f) nativeContent=(%.1fx%.1f) viewport=%.1f stride=%.1f maxSteps=60\n",wv,wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,original.x,original.y,sv.contentSize.width,sv.contentSize.height,viewport,stride]);
    __block NSUInteger step=0;__block CGFloat targetY=0,lastY=-999999;__block BOOL finishing=NO;__block void (^next)(void)=nil;__block void (^finish)(NSString *)=nil;
    finish=^(NSString *reason){if(finishing)return;finishing=YES;@try{[sv setContentOffset:original animated:NO];[sv layoutIfNeeded];sv.scrollEnabled=originalScroll;}@catch(...){}ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"WEB_SCAN_END reason=%@ steps=%lu restoredOffset=(%.1f,%.1f) finalContent=(%.1fx%.1f)\n",reason?:@"done",(unsigned long)step,sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height]);if(done)done(reason?:@"done");next=nil;finish=nil;};
    void (^fullAndFinish)(NSString *)=^(NSString *reason){ADMenuProbeEvalAppend7252(wv,path,ADMenuProbeDOMJS7252(step,YES),@"FULL_DOM",^{finish(reason);});};
    next=^{if(finishing)return;if(!wv.window||!sv.superview){fullAndFinish(@"web-left-window");return;}if(step>=60){fullAndFinish(@"step-cap");return;}CGFloat maxY=MAX(0.0,sv.contentSize.height-sv.bounds.size.height+sv.adjustedContentInset.bottom);targetY=MIN(MAX(0.0,targetY),maxY);if(step>0&&fabs(targetY-lastY)<0.5&&fabs(targetY-maxY)<0.5){fullAndFinish(@"bottom");return;}@try{[sv setContentOffset:CGPointMake(original.x,targetY) animated:NO];[sv layoutIfNeeded];}@catch(...){}NSUInteger thisStep=step++;CGFloat thisY=targetY;lastY=targetY;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.30*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ADMenuProbeEvalAppend7252(wv,path,ADMenuProbeDOMJS7252(thisStep,NO),@"VIEWPORT_DOM",^{CGFloat newMax=MAX(0.0,sv.contentSize.height-sv.bounds.size.height+sv.adjustedContentInset.bottom);if(fabs(thisY-newMax)<0.5){fullAndFinish(@"bottom");return;}targetY=MIN(newMax,thisY+stride);dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.05*NSEC_PER_SEC)),dispatch_get_main_queue(),next);});});};
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.04*NSEC_PER_SEC)),dispatch_get_main_queue(),next);
}
static void ADMenuProbeScanNative7252(UIScrollView *sv,NSString *path,void (^done)(NSString *)){
    if(!sv){if(done)done(@"no-native");return;}CGPoint original=sv.contentOffset;BOOL originalScroll=sv.scrollEnabled;sv.scrollEnabled=NO;CGFloat viewport=MAX(1.0,sv.bounds.size.height),stride=MAX(220.0,MIN(560.0,viewport*0.58));CGRect wr=CGRectZero;@try{wr=[sv convertRect:sv.bounds toView:nil];}@catch(...){}
    ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"NATIVE_TARGET ptr=%p cls=%@ aid=\"%@\" frame=(%.1f,%.1f %.1fx%.1f) originalOffset=(%.1f,%.1f) content=(%.1fx%.1f) viewport=%.1f stride=%.1f maxSteps=50\n",sv,NSStringFromClass(sv.class),ADMenuProbeSafe7252(sv.accessibilityIdentifier),wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,original.x,original.y,sv.contentSize.width,sv.contentSize.height,viewport,stride]);
    __block NSUInteger step=0;__block CGFloat targetY=0,lastY=-999999;__block BOOL finishing=NO;__block void (^next)(void)=nil;__block void (^finish)(NSString *)=nil;
    finish=^(NSString *reason){if(finishing)return;finishing=YES;@try{[sv setContentOffset:original animated:NO];[sv layoutIfNeeded];sv.scrollEnabled=originalScroll;}@catch(...){}ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"NATIVE_SCAN_END reason=%@ steps=%lu restoredOffset=(%.1f,%.1f) finalContent=(%.1fx%.1f)\n",reason?:@"done",(unsigned long)step,sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height]);if(done)done(reason?:@"done");next=nil;finish=nil;};
    next=^{if(finishing)return;if(!sv.window||!sv.superview){finish(@"native-left-window");return;}if(step>=50){ADMenuProbeAppend7252(path,ADMenuNativeSnapshot7252(sv,sv,@"step-cap-final"));finish(@"step-cap");return;}CGFloat maxY=MAX(0.0,sv.contentSize.height-sv.bounds.size.height+sv.adjustedContentInset.bottom);targetY=MIN(MAX(0.0,targetY),maxY);if(step>0&&fabs(targetY-lastY)<0.5&&fabs(targetY-maxY)<0.5){ADMenuProbeAppend7252(path,ADMenuNativeSnapshot7252(sv,sv,@"bottom"));finish(@"bottom");return;}@try{[sv setContentOffset:CGPointMake(original.x,targetY) animated:NO];[sv layoutIfNeeded];}@catch(...){}NSUInteger thisStep=step++;CGFloat thisY=targetY;lastY=targetY;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.28*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ADMenuProbeAppend7252(path,ADMenuNativeSnapshot7252(sv,sv,[NSString stringWithFormat:@"step-%lu",(unsigned long)thisStep]));CGFloat newMax=MAX(0.0,sv.contentSize.height-sv.bounds.size.height+sv.adjustedContentInset.bottom);if(fabs(thisY-newMax)<0.5){finish(@"bottom");return;}targetY=MIN(newMax,thisY+stride);dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.05*NSEC_PER_SEC)),dispatch_get_main_queue(),next);});};
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.04*NSEC_PER_SEC)),dispatch_get_main_queue(),next);
}
static void ADCaptureMenuProbe7252(NSString *trigger){
    if(!gP.enabled||gADMenuProbeBusy7252)return;gADMenuProbeBusy7252=YES;NSUInteger run=++gADMenuProbeRun7252;NSString *path=ADMenuProbePath7252(run);
    ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"AMAZONDARK v7.336 HAMBURGER MENU UI FORENSICS PROBE\nversion=%s\ntrigger=%@\ndate=%@\nfile=%@\ncap_bytes=%llu\nclassification=hybrid discovery; stable native tab owner is ANXTabBarButton#menuTab, content renderer is discovered at trigger time\npolicy=no visible text strings, no accessibilityLabel text, no aria-label/alt/value contents, no href/src URLs, no network payloads; technical ids/classes and privacy-safe text lengths/hashes retained\nscan=finite explicit-trigger WebKit full-document walk plus finite native/React scroll walk when present; original offsets and scrollEnabled restored; bounded pre-trigger lifecycle ring captures footer-sized RCTView/RNCEKV setter/mount ordering\n",AD_VERSION,trigger?:@"unknown",[NSDate date],path.lastPathComponent,kADMenuProbeCap7252]);
    ADMenuProbeAppend7252(path,ADMenuLifecycleSnapshot7280(@"PRE_TRIGGER")); ADMenuLifecycleClear7280();
    ADMenuProbeLogTab7252(path); UIScrollView *native=ADMenuProbeFindNativeScroll7252(path); UIWindow *root=UIApplication.sharedApplication.keyWindow?:UIApplication.sharedApplication.windows.firstObject; if(root)ADMenuProbeAppend7252(path,ADMenuNativeSnapshot7252(root,native?:root,@"initial-window"));
    ADMenuProbeFindWebView7252(path,^(WKWebView *wv,NSString *meta){
        ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"WEB_SELECTION ptr=%p meta=%@\n",wv,ADMenuProbeSafe7252(meta)]);
        void (^finishAll)(void)=^{UIWindow *r=UIApplication.sharedApplication.keyWindow?:UIApplication.sharedApplication.windows.firstObject;if(r)ADMenuProbeAppend7252(path,ADMenuNativeSnapshot7252(r,native?:r,@"final-window"));ADMenuProbeAppend7252(path,ADMenuLifecycleSnapshot7280(@"PROBE_ACTIVITY"));ADMenuLifecycleClear7280();ADMenuProbeAppend7252(path,@"MENU_PROBE_END\n================ END RUN ================\n");gADMenuProbeBusy7252=NO;};
        void (^runNative)(void)=^{if(native){ADMenuProbeScanNative7252(native,path,^(__unused NSString *reason){finishAll();});}else finishAll();};
        NSInteger sem=ADMenuProbeScore7252(meta); if(wv&&(sem>0||!native)){ADMenuProbeScanWeb7252(wv,path,^(__unused NSString *reason){runNative();});}else runNative();
    });
}
static dispatch_source_t gADThreeTabProbeSignal7254=nil;

static UIControl *ADProbeTabButton7254(NSString *aid){
    if(!aid.length)return nil;
    @try {
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.01)continue;
            NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:w]; NSUInteger seen=0;
            while(q.count&&seen++<1800){
                UIView *v=q.firstObject; [q removeObjectAtIndex:0];
                if([v isKindOfClass:[UIControl class]]&&[v.accessibilityIdentifier isEqualToString:aid])return (UIControl *)v;
                if(q.count<1600)for(UIView *c in v.subviews)[q addObject:c];
            }
        }
    } @catch(...) {}
    return nil;
}
static BOOL ADProbeTabSelected7254(NSString *aid){
    UIControl *b=ADProbeTabButton7254(aid); if(!b)return NO;
    @try { return b.selected||((b.state&UIControlStateSelected)!=0)||((b.accessibilityTraits&UIAccessibilityTraitSelected)!=0); } @catch(...) { return NO; }
}


// v7.269 Alexa/Rufus UI forensics probe retained in v7.272. The selected native tab is historically
// ANXTabBarButton#rufusTab. Historical
// v7.162 source proves Amazon's Alexa/Rufus surfaces can use WebKit containers and
// pseudo-element painters, so this explicit-trigger probe inventories both native and
// WebKit ownership without assuming which renderer the current Alexa pane uses.
static NSUInteger gADAlexaProbeRun7269=0;
static BOOL gADAlexaProbeBusy7269=NO;
static const unsigned long long kADAlexaProbeCap7269=64ULL*1024ULL*1024ULL;
static NSString *ADAlexaProbePath7269(NSUInteger run){
    @try {NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.timeZone=[NSTimeZone localTimeZone];f.dateFormat=@"yyyyMMdd-HHmmss-SSS";NSString *stamp=[f stringFromDate:[NSDate date]]?:@"unknown",*name=[NSString stringWithFormat:@"AmazonDark-v7.336-alexa-ui-probe-%@-r%lu.txt",stamp,(unsigned long)run];NSString *docs=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject];return [(docs.length?docs:NSTemporaryDirectory()) stringByAppendingPathComponent:name];} @catch(...) {return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"AmazonDark-v7.336-alexa-ui-probe-r%lu.txt",(unsigned long)run]];}
}
static void ADAlexaProbeLogTabs7269(NSString *path){
    for(NSString *aid in @[@"rufusTab"]){
        UIControl *tab=ADProbeTabButton7254(aid); if(!tab){ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"ALEXA_TAB aid=%@ found=0\n",aid]);continue;}
        CGRect r=CGRectZero;@try{r=[tab convertRect:tab.bounds toView:nil];}@catch(...){}
        ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"ALEXA_TAB aid=%@ found=1 ptr=%p cls=%@ selected=%d enabled=%d highlighted=%d state=%lu traits=%llu frame=(%.1f,%.1f %.1fx%.1f) bg=%@ tint=%@ layerBorder=%.2f/%@ radius=%.2f\n",aid,tab,NSStringFromClass(tab.class),tab.selected?1:0,tab.enabled?1:0,tab.highlighted?1:0,(unsigned long)tab.state,(unsigned long long)tab.accessibilityTraits,r.origin.x,r.origin.y,r.size.width,r.size.height,ADMenuProbeColor7252(tab.backgroundColor),ADMenuProbeColor7252(tab.tintColor),tab.layer.borderWidth,ADMenuProbeCG7252(tab.layer.borderColor),tab.layer.cornerRadius]);
    }
}
static NSString *ADAlexaProbeDetectJS7269(void){
    return
        @"(function(){try{var d=document,p=String(location.pathname||'').toLowerCase(),se=d.scrollingElement||d.documentElement||d.body;"
        @"var q='[id*=\\\"rufus\\\" i],[class*=\\\"rufus\\\" i],[data-testid*=\\\"rufus\\\" i],[data-component-type*=\\\"rufus\\\" i],[data-csa-c-content-id*=\\\"rufus\\\" i],[data-csa-c-painter*=\\\"rufus\\\" i],[id*=\\\"alexa\\\" i],[class*=\\\"alexa\\\" i],[data-testid*=\\\"alexa\\\" i],[data-component-type*=\\\"alexa\\\" i],[data-csa-c-content-id*=\\\"alexa\\\" i],[id*=\\\"assistant\\\" i],[class*=\\\"assistant\\\" i],[data-testid*=\\\"assistant\\\" i],[id*=\\\"conversation\\\" i],[class*=\\\"conversation\\\" i],[data-testid*=\\\"conversation\\\" i],[id*=\\\"chat\\\" i],[class*=\\\"chat\\\" i],[data-testid*=\\\"chat\\\" i],[id*=\\\"nile\\\" i],[class*=\\\"nile\\\" i],[class*=\\\"nice-widget\\\" i]';"
        @"var tech=0;try{tech=d.querySelectorAll(q).length}catch(_){tech=0}var r=!!d.querySelector('[id*=\\\"rufus\\\" i],[class*=\\\"rufus\\\" i],[data-testid*=\\\"rufus\\\" i]'),a=!!d.querySelector('[id*=\\\"alexa\\\" i],[class*=\\\"alexa\\\" i],[data-testid*=\\\"alexa\\\" i]'),c=!!d.querySelector('[id*=\\\"conversation\\\" i],[class*=\\\"conversation\\\" i],[id*=\\\"chat\\\" i],[class*=\\\"chat\\\" i]');"
        @"var pathHit=/rufus|alexa|assistant|conversation|chat|nile/.test(p),score=Math.min(700,tech*18)+(r?360:0)+(a?360:0)+(c?220:0)+(pathHit?220:0);return 'score='+score+' tech='+tech+' rufus='+(r?1:0)+' alexa='+(a?1:0)+' chat='+(c?1:0)+' pathHit='+(pathHit?1:0)+' ready='+String(d.readyState||'')+' scrollH='+(se?Math.round(se.scrollHeight||0):0)+' clientH='+(se?Math.round(se.clientHeight||0):0)+' nodes='+(d.getElementsByTagName('*').length||0)+' frames='+(d.getElementsByTagName('iframe').length||0)+' stylesheets='+d.styleSheets.length+' ad7='+(d.getElementById('ad7-static-theme')?1:0);}catch(e){return 'score=0 error=1';}})();";
}
static NSString *ADAlexaProbeStylesJS7269(NSString *phase){
    NSString *ph=phase?:@"?";
    return [NSString stringWithFormat:
        @"(function(){try{var d=document,out=['\\n===== ALEXA STYLE OWNERS phase=%@ ====='],MAX=220;function clean(v,n){v=String(v==null?'':v).replace(/[\\r\\n\\t]+/g,' ');n=n||150;return v.length>n?v.slice(0,n)+'…':v}function hash(s){s=String(s||'');var h=2166136261>>>0;for(var i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619)}return (h>>>0).toString(16)}var nodes=d.querySelectorAll('style,link[rel~=\\\"stylesheet\\\"]');for(var i=0;i<nodes.length&&i<MAX;i++){var e=nodes[i],sh=null,rules=-1;try{sh=e.sheet;rules=sh&&sh.cssRules?sh.cssRules.length:0}catch(_){rules=-2}var txt=e.tagName==='STYLE'?String(e.textContent||''):'';out.push('STYLE n='+i+' tag='+String(e.tagName||'').toLowerCase()+' id=\\\"'+clean(e.id||'',100)+'\\\" class=\\\"'+clean(typeof e.className==='string'?e.className:'',150)+'\\\" media=\\\"'+clean(e.media||'',70)+'\\\" disabled='+(e.disabled?1:0)+' rules='+rules+' text='+txt.length+'/'+hash(txt)+' href='+(e.hasAttribute&&e.hasAttribute('href')?1:0));}var ad=d.querySelectorAll('[id^=\\\"ad7-\\\"]');for(var j=0;j<ad.length&&j<180;j++){var x=ad[j],t=String(x.textContent||''),rr=-1;try{rr=x.sheet&&x.sheet.cssRules?x.sheet.cssRules.length:0}catch(_){rr=-2}out.push('AD7 n='+j+' tag='+String(x.tagName||'').toLowerCase()+' id=\\\"'+clean(x.id||'',120)+'\\\" class=\\\"'+clean(typeof x.className==='string'?x.className:'',150)+'\\\" rules='+rr+' text='+t.length+'/'+hash(t));}var adopted=[];try{var aa=d.adoptedStyleSheets||[];for(var k=0;k<aa.length&&k<80;k++){var n=-1;try{n=aa[k].cssRules?aa[k].cssRules.length:0}catch(_){n=-2}adopted.push(n)}}catch(_){ }out.push('COUNTS styles='+nodes.length+' ad7='+ad.length+' adopted=['+adopted.join(',')+'] totalNodes='+d.getElementsByTagName('*').length+' frames='+d.getElementsByTagName('iframe').length);out.push('===== END ALEXA STYLE OWNERS =====\\n');return out.join('\\n')}catch(e){return 'ALEXA_STYLE_EXCEPTION '+String(e&&e.message||e)+'\\n'}})();",ph];
}
static void ADAlexaProbeFindWebView7269(NSString *path,void (^done)(WKWebView *,NSString *)){
    NSArray<WKWebView *> *views=ADMenuProbeWebViews7252(); if(!views.count){done(nil,@"no-webviews");return;}
    __block NSUInteger idx=0;__block NSInteger bestRank=NSIntegerMin;__block CGFloat bestArea=0;__block WKWebView *best=nil;__block NSString *bestMeta=@"";__block void (^next)(void)=nil;
    next=^{if(idx>=views.count){WKWebView *winner=best;NSString *meta=bestMeta;next=nil;done(winner,meta);return;}WKWebView *wv=views[idx];NSUInteger thisIdx=idx++;CGRect wr=CGRectZero;@try{wr=[wv convertRect:wv.bounds toView:nil];}@catch(...){}CGFloat area=MAX(0.0,wr.size.width)*MAX(0.0,wr.size.height);BOOL visible=ADMenuProbeEffectiveVisible7252(wv)&&wr.size.width>=180&&wr.size.height>=120&&CGRectIntersectsRect(wr,UIScreen.mainScreen.bounds);[wv evaluateJavaScript:ADAlexaProbeDetectJS7269() completionHandler:^(id result,NSError *error){NSString *meta=[result isKindOfClass:[NSString class]]?(NSString *)result:[NSString stringWithFormat:@"score=0 error=%@",error.localizedDescription?:@"eval"];NSInteger semantic=ADMenuProbeScore7252(meta),rank=visible?(semantic+1000):semantic;ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"ALEXA_WEB_CANDIDATE index=%lu ptr=%p window=%d visible=%d hidden=%d alpha=%.2f frame=(%.1f,%.1f %.1fx%.1f) nativeContent=(%.1fx%.1f) %@\n",(unsigned long)thisIdx,wv,wv.window?1:0,visible?1:0,wv.hidden?1:0,wv.alpha,wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,wv.scrollView.contentSize.width,wv.scrollView.contentSize.height,ADMenuProbeSafe7252(meta)]);if(visible&&(rank>bestRank||(rank==bestRank&&area>bestArea))){bestRank=rank;bestArea=area;best=wv;bestMeta=meta;}dispatch_async(dispatch_get_main_queue(),next);}];};next();
}
static NSString *ADAlexaNativeSnapshot7269(UIView *root,UIView *target,NSString *phase){
    NSString *x=ADMenuNativeSnapshot7252(root,target,phase);if(!x.length)return x;x=[x stringByReplacingOccurrencesOfString:@"MENU NATIVE" withString:@"ALEXA NATIVE"];x=[x stringByReplacingOccurrencesOfString:@"MENU_NATIVE_" withString:@"ALEXA_NATIVE_"];return x;
}
static void ADAlexaProbeScanNative7269(UIScrollView *sv,NSString *path,void (^done)(NSString *)){
    if(!sv){if(done)done(@"no-native");return;}CGPoint original=sv.contentOffset;BOOL originalScroll=sv.scrollEnabled;sv.scrollEnabled=NO;CGFloat viewport=MAX(1.0,sv.bounds.size.height),stride=MAX(220.0,MIN(560.0,viewport*0.58));CGRect wr=CGRectZero;@try{wr=[sv convertRect:sv.bounds toView:nil];}@catch(...){}
    ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"ALEXA_NATIVE_TARGET ptr=%p cls=%@ aid=\"%@\" frame=(%.1f,%.1f %.1fx%.1f) originalOffset=(%.1f,%.1f) content=(%.1fx%.1f) viewport=%.1f stride=%.1f maxSteps=50\n",sv,NSStringFromClass(sv.class),ADMenuProbeSafe7252(sv.accessibilityIdentifier),wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,original.x,original.y,sv.contentSize.width,sv.contentSize.height,viewport,stride]);
    __block NSUInteger step=0;__block CGFloat targetY=0,lastY=-999999;__block BOOL finishing=NO;__block void (^next)(void)=nil;__block void (^finish)(NSString *)=nil;
    finish=^(NSString *reason){if(finishing)return;finishing=YES;@try{[sv setContentOffset:original animated:NO];[sv layoutIfNeeded];sv.scrollEnabled=originalScroll;}@catch(...){}ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"ALEXA_NATIVE_SCAN_END reason=%@ steps=%lu restoredOffset=(%.1f,%.1f) finalContent=(%.1fx%.1f)\n",reason?:@"done",(unsigned long)step,sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height]);if(done)done(reason?:@"done");next=nil;finish=nil;};
    next=^{if(finishing)return;if(!sv.window||!sv.superview){finish(@"native-left-window");return;}if(step>=50){ADMenuProbeAppend7252(path,ADAlexaNativeSnapshot7269(sv,sv,@"step-cap-final"));finish(@"step-cap");return;}CGFloat maxY=MAX(0.0,sv.contentSize.height-sv.bounds.size.height+sv.adjustedContentInset.bottom);targetY=MIN(MAX(0.0,targetY),maxY);if(step>0&&fabs(targetY-lastY)<0.5&&fabs(targetY-maxY)<0.5){ADMenuProbeAppend7252(path,ADAlexaNativeSnapshot7269(sv,sv,@"bottom"));finish(@"bottom");return;}@try{[sv setContentOffset:CGPointMake(original.x,targetY) animated:NO];[sv layoutIfNeeded];}@catch(...){}NSUInteger thisStep=step++;CGFloat thisY=targetY;lastY=targetY;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.28*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ADMenuProbeAppend7252(path,ADAlexaNativeSnapshot7269(sv,sv,[NSString stringWithFormat:@"step-%lu",(unsigned long)thisStep]));CGFloat newMax=MAX(0.0,sv.contentSize.height-sv.bounds.size.height+sv.adjustedContentInset.bottom);if(fabs(thisY-newMax)<0.5){finish(@"bottom");return;}targetY=MIN(newMax,thisY+stride);dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.05*NSEC_PER_SEC)),dispatch_get_main_queue(),next);});};dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.04*NSEC_PER_SEC)),dispatch_get_main_queue(),next);
}
static void ADCaptureAlexaProbe7269(NSString *trigger){
    if(!gP.enabled||gADAlexaProbeBusy7269)return;gADAlexaProbeBusy7269=YES;NSUInteger run=++gADAlexaProbeRun7269;NSString *path=ADAlexaProbePath7269(run);
    ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"AMAZONDARK v7.336 ALEXA/RUFUS UI FORENSICS PROBE\nversion=%s\ntrigger=%@\ndate=%@\nfile=%@\ncap_bytes=%llu\nclassification=hybrid discovery; selected native tab owner is ANXTabBarButton#rufusTab; content renderer is discovered at trigger time\nhistory=v7.162 proved Alexa/Rufus surfaces can use WebKit nice-widget/Rufus containers and pseudo-element painters; no current Alexa visual ownership is assumed\npolicy=no visible text strings, no accessibilityLabel text, no aria-label/alt/value contents, no href/src URLs, no network payloads; technical ids/classes/testids/component attributes plus privacy-safe text lengths/hashes retained\nweb=all visible WKWebViews scored; chosen document gets finite top-to-bottom viewport snapshots plus final full DOM inventory (max 6200 nodes), open-shadow-root and accessible-iframe recursion, computed colors/backgrounds/images/masks/borders/radii/outlines/shadows/fonts/SVG/filter/transform/pseudo-elements/media and style-owner inventory; original offset restored\nnative=all visible native scroll candidates inventoried; best non-WebKit content scroll gets finite top-to-bottom UIKit/React snapshots including view/layer geometry, colors, borders, gradients/shapes, RCT edge props, text runs, controls, image/TWB state; original offset restored\nnormal_runtime=no observer/timer/RAF/scroll listener/recurring hierarchy scan is added by this probe\n",AD_VERSION,trigger?:@"unknown",[NSDate date],path.lastPathComponent,kADAlexaProbeCap7269]);
    ADAlexaProbeLogTabs7269(path);UIScrollView *native=ADMenuProbeFindNativeScroll7252(path);UIWindow *root=UIApplication.sharedApplication.keyWindow?:UIApplication.sharedApplication.windows.firstObject;if(root)ADMenuProbeAppend7252(path,ADAlexaNativeSnapshot7269(root,native?:root,@"initial-window"));
    ADAlexaProbeFindWebView7269(path,^(WKWebView *wv,NSString *meta){ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"ALEXA_WEB_SELECTION ptr=%p meta=%@\n",wv,ADMenuProbeSafe7252(meta)]);void (^finishAll)(void)=^{UIWindow *r=UIApplication.sharedApplication.keyWindow?:UIApplication.sharedApplication.windows.firstObject;if(r)ADMenuProbeAppend7252(path,ADAlexaNativeSnapshot7269(r,native?:r,@"final-window"));ADMenuProbeAppend7252(path,@"ALEXA_PROBE_END\n================ END RUN ================\n");gADAlexaProbeBusy7269=NO;};void (^runNative)(void)=^{if(native){ADAlexaProbeScanNative7269(native,path,^(__unused NSString *reason){finishAll();});}else finishAll();};if(wv){ADMenuProbeEvalAppend7252(wv,path,ADAlexaProbeStylesJS7269(@"initial"),@"ALEXA_STYLE_INITIAL",^{ADMenuProbeScanWeb7252(wv,path,^(__unused NSString *reason){ADMenuProbeEvalAppend7252(wv,path,ADAlexaProbeStylesJS7269(@"post-web-scan"),@"ALEXA_STYLE_FINAL",^{runNative();});});});}else runNative();});
}


// v7.299: Dedicated Person-submenu hybrid full-document forensics probe retained from v7.298.
// The main Person RCTScrollView#me probe remains unchanged.  When meTab is selected but the
// main Person root is absent or physically covered by a redirected/modal submenu, the existing
// single screenshot/SIGUSR2 dispatcher routes here instead.  This probe is deliberately renderer-
// agnostic: it inventories and sequentially walks every plausible visible WKWebView plus every
// plausible visible non-WebKit native/React scroll root, takes full-window native snapshots before
// and after, performs final full DOM inventories for every scanned document, and restores every
// original contentOffset/scrollEnabled value.  No normal-runtime observer/timer/RAF/scroll listener
// or recurring hierarchy scan is added.
static NSUInteger gADPersonSubmenuProbeRun7298=0;
static BOOL gADPersonSubmenuProbeBusy7298=NO;
static const unsigned long long kADPersonSubmenuProbeCap7298=64ULL*1024ULL*1024ULL;

static NSString *ADPersonSubmenuProbePath7298(NSUInteger run){
    @try {
        NSDateFormatter *f=[NSDateFormatter new]; f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        f.timeZone=[NSTimeZone localTimeZone]; f.dateFormat=@"yyyyMMdd-HHmmss-SSS";
        NSString *stamp=[f stringFromDate:[NSDate date]]?:@"unknown";
        NSString *name=[NSString stringWithFormat:@"AmazonDark-v7.336-person-submenu-hybrid-probe-%@-r%lu.txt",stamp,(unsigned long)run];
        NSString *docs=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject];
        return [(docs.length?docs:NSTemporaryDirectory()) stringByAppendingPathComponent:name];
    } @catch(...) {
        return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"AmazonDark-v7.336-person-submenu-hybrid-probe-r%lu.txt",(unsigned long)run]];
    }
}

static NSString *ADPersonSubmenuProbeDetectJS7298(void){
    return
        @"(function(){try{var d=document,de=d.documentElement||{},se=d.scrollingElement||de||d.body,n=d.getElementsByTagName('*'),shadow=0;"
        @"for(var i=0;i<n.length&&i<7000;i++){try{if(n[i].shadowRoot)shadow++}catch(_){}}"
        @"return 'ready='+String(d.readyState||'')+' viewport='+Number(innerWidth||de.clientWidth||0)+'x'+Number(innerHeight||de.clientHeight||0)+"
        @"' scroll='+Number(scrollX||se.scrollLeft||0)+','+Number(scrollY||se.scrollTop||0)+' scrollSize='+Number(se?se.scrollWidth:0)+'x'+Number(se?se.scrollHeight:0)+"
        @"' nodes='+n.length+' frames='+d.getElementsByTagName('iframe').length+' shadowRoots='+shadow+' stylesheets='+d.styleSheets.length+"
        @"' ad7='+(d.getElementById('ad7-static-theme')?1:0)+' twb='+(d.getElementById('ad7-product-feed-twb')||d.getElementById('ad7-menu-twb')||d.getElementById('ad7-search-pane-twb')?1:0);"
        @"}catch(e){return 'error=1';}})();";
}

static NSArray<WKWebView *> *ADPersonSubmenuVisibleWebViews7298(NSString *path){
    NSMutableArray<NSDictionary *> *ranked=[NSMutableArray array]; NSUInteger idx=0;
    @try {
        CGRect screen=UIScreen.mainScreen.bounds;
        for(WKWebView *wv in ADMenuProbeWebViews7252()){
            if(!wv)continue; CGRect wr=CGRectZero; @try { wr=[wv convertRect:wv.bounds toView:nil]; } @catch(...) {}
            CGRect inter=CGRectIntersection(wr,screen); CGFloat area=(!CGRectIsNull(inter)&&!CGRectIsEmpty(inter))?inter.size.width*inter.size.height:0.0;
            BOOL visible=ADMenuProbeEffectiveVisible7252(wv)&&area>=6000.0&&wr.size.width>=120.0&&wr.size.height>=90.0;
            ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"PERSON_SUBMENU_WEB_CANDIDATE index=%lu ptr=%p visible=%d window=%d hidden=%d alpha=%.2f frame=(%.1f,%.1f %.1fx%.1f) intersectionArea=%.1f nativeOffset=(%.1f,%.1f) nativeContent=(%.1fx%.1f)\n",(unsigned long)idx++,wv,visible?1:0,wv.window?1:0,wv.hidden?1:0,wv.alpha,wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,area,wv.scrollView.contentOffset.x,wv.scrollView.contentOffset.y,wv.scrollView.contentSize.width,wv.scrollView.contentSize.height]);
            if(visible)[ranked addObject:@{ @"wv":wv,@"area":@(area) }];
        }
    } @catch(...) {}
    [ranked sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){ return [b[@"area"] compare:a[@"area"]]; }];
    NSMutableArray<WKWebView *> *out=[NSMutableArray array];
    for(NSDictionary *d in ranked){ if(out.count>=6)break; WKWebView *wv=d[@"wv"]; if(wv)[out addObject:wv]; }
    return out;
}

static NSArray<UIScrollView *> *ADPersonSubmenuNativeScrolls7298(NSString *path){
    NSMutableArray<NSDictionary *> *ranked=[NSMutableArray array]; NSUInteger idx=0;
    @try {
        CGRect screen=UIScreen.mainScreen.bounds;
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.01)continue; NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:w]; NSUInteger seen=0;
            while(q.count&&seen++<7600){
                UIView *v=q.firstObject; [q removeObjectAtIndex:0]; if(!v)continue;
                if([v isKindOfClass:[UIScrollView class]]){
                    UIScrollView *sv=(UIScrollView *)v; NSString *cn=NSStringFromClass(v.class)?:@"?",*aid=v.accessibilityIdentifier?:@"";
                    CGRect wr=CGRectZero; @try { wr=[v convertRect:v.bounds toView:nil]; } @catch(...) {}
                    CGRect inter=CGRectIntersection(wr,screen); CGFloat area=(!CGRectIsNull(inter)&&!CGRectIsEmpty(inter))?inter.size.width*inter.size.height:0.0;
                    BOOL insideWeb=ADMenuProbeHasAncestorClass7252(v,@"WKWebView")||[cn rangeOfString:@"WKScroll" options:NSCaseInsensitiveSearch].location!=NSNotFound;
                    BOOL chrome=ADMenuProbeHasAncestorClass7252(v,@"ANXTabBar")||ADMenuProbeHasAncestorClass7252(v,@"Keyboard")||[cn rangeOfString:@"ScrollIndicator" options:NSCaseInsensitiveSearch].location!=NSNotFound;
                    BOOL mainPerson=[aid isEqualToString:@"me"]&&ADClassNameIs7183(v,"RCTScrollView");
                    BOOL visible=ADMenuProbeEffectiveVisible7252(v)&&area>=5000.0&&wr.size.width>=120.0&&wr.size.height>=90.0;
                    BOOL scrollable=sv.contentSize.height>sv.bounds.size.height+8.0||sv.contentSize.width>sv.bounds.size.width+8.0;
                    NSInteger score=0;
                    if([cn rangeOfString:@"RCTScroll" options:NSCaseInsensitiveSearch].location!=NSNotFound)score+=900;
                    if([cn rangeOfString:@"CollectionView" options:NSCaseInsensitiveSearch].location!=NSNotFound)score+=720;
                    if([cn rangeOfString:@"TableView" options:NSCaseInsensitiveSearch].location!=NSNotFound)score+=720;
                    if([cn rangeOfString:@"ScrollView" options:NSCaseInsensitiveSearch].location!=NSNotFound)score+=240;
                    if(scrollable)score+=500; if(wr.size.width>=screen.size.width*0.65)score+=160; if(wr.size.height>=screen.size.height*0.30)score+=160;
                    ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"PERSON_SUBMENU_NATIVE_SCROLL_CANDIDATE index=%lu ptr=%p cls=%@ aid=\"%@\" visible=%d insideWeb=%d chrome=%d mainPerson=%d frame=(%.1f,%.1f %.1fx%.1f) intersectionArea=%.1f offset=(%.1f,%.1f) content=(%.1fx%.1f) bounds=(%.1fx%.1f) scrollable=%d score=%ld\n",(unsigned long)idx++,sv,cn,ADMenuProbeSafe7252(aid),visible?1:0,insideWeb?1:0,chrome?1:0,mainPerson?1:0,wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,area,sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height,sv.bounds.size.width,sv.bounds.size.height,scrollable?1:0,(long)score]);
                    if(visible&&!insideWeb&&!chrome&&!mainPerson)[ranked addObject:@{ @"sv":sv,@"score":@(score),@"area":@(area) }];
                }
                if(q.count<7200)for(UIView *c in v.subviews)[q addObject:c];
            }
        }
    } @catch(...) {}
    [ranked sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){ NSComparisonResult r=[b[@"score"] compare:a[@"score"]]; return r==NSOrderedSame?[b[@"area"] compare:a[@"area"]]:r; }];
    NSMutableArray<UIScrollView *> *out=[NSMutableArray array];
    for(NSDictionary *d in ranked){
        if(out.count>=6)break; UIScrollView *sv=d[@"sv"]; if(!sv)continue; BOOL related=NO;
        for(UIScrollView *e in out){ if(ADMenuProbeIsDescendant7252(sv,e)||ADMenuProbeIsDescendant7252(e,sv)){related=YES;break;} }
        if(!related)[out addObject:sv];
    }
    return out;
}

static NSString *ADPersonSubmenuNativeSnapshot7298(UIView *root,UIView *target,NSString *phase){
    NSString *x=ADMenuNativeSnapshot7252(root,target,phase); if(!x.length)return x;
    x=[x stringByReplacingOccurrencesOfString:@"MENU NATIVE" withString:@"PERSON SUBMENU NATIVE"];
    x=[x stringByReplacingOccurrencesOfString:@"MENU_NATIVE_" withString:@"PERSON_SUBMENU_NATIVE_"];
    return x;
}

static void ADPersonSubmenuScanNative7298(UIScrollView *sv,NSString *path,NSUInteger index,void (^done)(NSString *)){
    if(!sv){if(done)done(@"no-native");return;}
    CGPoint original=sv.contentOffset; BOOL originalScroll=sv.scrollEnabled; sv.scrollEnabled=NO;
    CGFloat viewport=MAX(1.0,sv.bounds.size.height),stride=MAX(200.0,MIN(560.0,viewport*0.55)); CGRect wr=CGRectZero; @try { wr=[sv convertRect:sv.bounds toView:nil]; } @catch(...) {}
    ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"PERSON_SUBMENU_NATIVE_TARGET index=%lu ptr=%p cls=%@ aid=\"%@\" frame=(%.1f,%.1f %.1fx%.1f) originalOffset=(%.1f,%.1f) content=(%.1fx%.1f) viewport=%.1f stride=%.1f maxSteps=60\n",(unsigned long)index,sv,NSStringFromClass(sv.class),ADMenuProbeSafe7252(sv.accessibilityIdentifier),wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,original.x,original.y,sv.contentSize.width,sv.contentSize.height,viewport,stride]);
    __block NSUInteger step=0; __block CGFloat targetY=0,lastY=-999999; __block BOOL finishing=NO; __block void (^next)(void)=nil; __block void (^finish)(NSString *)=nil;
    finish=^(NSString *reason){
        if(finishing)return; finishing=YES; @try { [sv setContentOffset:original animated:NO]; [sv layoutIfNeeded]; sv.scrollEnabled=originalScroll; } @catch(...) {}
        ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"PERSON_SUBMENU_NATIVE_SCAN_END index=%lu reason=%@ steps=%lu restoredOffset=(%.1f,%.1f) finalContent=(%.1fx%.1f)\n",(unsigned long)index,reason?:@"done",(unsigned long)step,sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height]);
        if(done)done(reason?:@"done"); next=nil; finish=nil;
    };
    next=^{
        if(finishing)return; if(!sv.window||!sv.superview){finish(@"native-left-window");return;} if(step>=60){UIView *snapRoot=sv.window?sv.window:(UIView *)sv;ADMenuProbeAppend7252(path,ADPersonSubmenuNativeSnapshot7298(snapRoot,sv,[NSString stringWithFormat:@"native-%lu-step-cap-final",(unsigned long)index]));finish(@"step-cap");return;}
        CGFloat maxY=MAX(0.0,sv.contentSize.height-sv.bounds.size.height+sv.adjustedContentInset.bottom); targetY=MIN(MAX(0.0,targetY),maxY);
        if(step>0&&fabs(targetY-lastY)<0.5&&fabs(targetY-maxY)<0.5){UIView *snapRoot=sv.window?sv.window:(UIView *)sv;ADMenuProbeAppend7252(path,ADPersonSubmenuNativeSnapshot7298(snapRoot,sv,[NSString stringWithFormat:@"native-%lu-bottom",(unsigned long)index]));finish(@"bottom");return;}
        @try { [sv setContentOffset:CGPointMake(original.x,targetY) animated:NO]; [sv layoutIfNeeded]; } @catch(...) {}
        NSUInteger thisStep=step++; CGFloat thisY=targetY; lastY=targetY;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.28*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            UIView *snapRoot=sv.window?sv.window:(UIView *)sv; ADMenuProbeAppend7252(path,ADPersonSubmenuNativeSnapshot7298(snapRoot,sv,[NSString stringWithFormat:@"native-%lu-step-%lu",(unsigned long)index,(unsigned long)thisStep]));
            CGFloat newMax=MAX(0.0,sv.contentSize.height-sv.bounds.size.height+sv.adjustedContentInset.bottom); if(fabs(thisY-newMax)<0.5){finish(@"bottom");return;}
            targetY=MIN(newMax,thisY+stride); dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.05*NSEC_PER_SEC)),dispatch_get_main_queue(),next);
        });
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.04*NSEC_PER_SEC)),dispatch_get_main_queue(),next);
}

static BOOL ADPersonSubmenuLikelyActive7298(void){
    UIView *wrap=ADPersonProbeWrapper7233(); CGRect screen=UIScreen.mainScreen.bounds;
    if(!wrap||!ADMenuProbeEffectiveVisible7252(wrap))return YES;
    @try {
        CGRect wr=[wrap convertRect:wrap.bounds toView:nil],inter=CGRectIntersection(wr,screen); CGFloat area=(!CGRectIsNull(inter)&&!CGRectIsEmpty(inter))?inter.size.width*inter.size.height:0.0;
        if(area<screen.size.width*screen.size.height*0.30)return YES;
        // A large visible renderer/navigation root outside RCTScrollView#me is strong redirected-submenu evidence.
        NSUInteger seen=0;
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.01)continue; NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:w];
            while(q.count&&seen++<2600){UIView *v=q.firstObject;[q removeObjectAtIndex:0];if(!v)continue;
                if(v!=wrap&&!ADMenuProbeIsDescendant7252(v,wrap)){
                    NSString *aid=v.accessibilityIdentifier?:@""; BOOL marker=[aid isEqualToString:@"MainStackNavigation"]||[aid isEqualToString:@"navigation-root"]||[aid isEqualToString:@"WrappedNileFeatureContainer"];
                    BOOL web=[v isKindOfClass:[WKWebView class]];
                    if(marker||web){CGRect r=CGRectZero;@try{r=[v convertRect:v.bounds toView:nil];}@catch(...){}CGRect ii=CGRectIntersection(r,screen);CGFloat aa=(!CGRectIsNull(ii)&&!CGRectIsEmpty(ii))?ii.size.width*ii.size.height:0.0;if(ADMenuProbeEffectiveVisible7252(v)&&aa>=screen.size.width*screen.size.height*0.25)return YES;}
                }
                if(q.count<2400)for(UIView *c in v.subviews)[q addObject:c];
            }
        }
        // Physical occlusion test: if most hit-tested points inside the nominal Person viewport land
        // outside its subtree, a pushed/modal submenu is covering it even if React kept #me mounted.
        UIWindow *w=wrap.window; if(w&&!CGRectIsNull(inter)&&!CGRectIsEmpty(inter)){
            const CGFloat xs[]={0.20,0.50,0.80}, ys[]={0.22,0.55,0.82}; NSUInteger own=0,total=0;
            for(size_t yi=0;yi<sizeof(ys)/sizeof(*ys);yi++)for(size_t xi=0;xi<sizeof(xs)/sizeof(*xs);xi++){
                CGPoint p=CGPointMake(CGRectGetMinX(inter)+inter.size.width*xs[xi],CGRectGetMinY(inter)+inter.size.height*ys[yi]); UIView *hit=nil; @try {hit=[w hitTest:p withEvent:nil];} @catch(...) {}
                if(hit){total++; if(hit==wrap||ADMenuProbeIsDescendant7252(hit,wrap))own++;}
            }
            if(total>=4&&own*2<total)return YES;
        }
    } @catch(...) { return YES; }
    return NO;
}

static void ADCapturePersonSubmenuProbe7298(NSString *trigger){
    if(!gP.enabled||gADPersonSubmenuProbeBusy7298)return; gADPersonSubmenuProbeBusy7298=YES;
    NSUInteger run=++gADPersonSubmenuProbeRun7298; NSString *path=ADPersonSubmenuProbePath7298(run);
    ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"AMAZONDARK v7.336 PERSON SUBMENU HYBRID FULL-DOCUMENT PROBE\nversion=%s\ntrigger=%@\ndate=%@\nfile=%@\ncap_bytes=%llu\nclassification=selected native tab owner is ANXTabBarButton#meTab; this probe is used only when the exact main Person RCTScrollView#me is absent/covered by redirected or modal content\npolicy=no visible text strings, no accessibilityLabel text, no aria-label/alt/value contents, no href/src URL values, no network payloads; technical ids/classes/testids/component attributes plus privacy-safe text lengths/hashes retained\nweb=EVERY plausible visible WKWebView (max 6) is scanned sequentially from top to bottom; every document receives viewport computed-paint snapshots, open-shadow-root/accessibly reachable iframe recursion, style-owner inventory, final full DOM inventory (max 6200 nodes), and its original offset/scrollEnabled are restored\nnative=EVERY plausible visible non-WebKit native/React scroll root (max 6, ancestry-deduped, main #me root excluded) is scanned sequentially top-to-bottom; full-window snapshots capture non-scrollable native content, UIKit/React hierarchy, layers, colors, borders, gradients/shapes, RCT edge props, text runs, controls, images/TWB state; all original offsets restored\nnormal_runtime=single existing screenshot/SIGUSR2 dispatcher only; no second observer/signal source, no MutationObserver/timer/RAF/web-scroll listener/recurring hierarchy scan\n",AD_VERSION,trigger?:@"unknown",[NSDate date],path.lastPathComponent,kADPersonSubmenuProbeCap7298]);
    UIWindow *root=UIApplication.sharedApplication.keyWindow?:UIApplication.sharedApplication.windows.firstObject;
    if(root)ADMenuProbeAppend7252(path,ADPersonSubmenuNativeSnapshot7298(root,root,@"initial-window"));
    NSArray<WKWebView *> *webs=ADPersonSubmenuVisibleWebViews7298(path); NSArray<UIScrollView *> *natives=ADPersonSubmenuNativeScrolls7298(path);
    ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"PERSON_SUBMENU_SELECTION webCount=%lu nativeCount=%lu\n",(unsigned long)webs.count,(unsigned long)natives.count]);
    __block NSUInteger wi=0,ni=0; __block void (^scanNativeNext)(void)=nil; __block void (^scanWebNext)(void)=nil; __block void (^finishAll)(void)=nil;
    finishAll=^{UIWindow *r=UIApplication.sharedApplication.keyWindow?:UIApplication.sharedApplication.windows.firstObject;if(r)ADMenuProbeAppend7252(path,ADPersonSubmenuNativeSnapshot7298(r,r,@"final-window"));ADMenuProbeAppend7252(path,@"PERSON_SUBMENU_PROBE_END\n================ END RUN ================\n");gADPersonSubmenuProbeBusy7298=NO;scanWebNext=nil;scanNativeNext=nil;finishAll=nil;};
    scanNativeNext=^{
        if(ni>=natives.count){finishAll();return;} UIScrollView *sv=natives[ni]; NSUInteger thisIndex=ni++;
        ADPersonSubmenuScanNative7298(sv,path,thisIndex,^(__unused NSString *reason){dispatch_async(dispatch_get_main_queue(),scanNativeNext);});
    };
    scanWebNext=^{
        if(wi>=webs.count){scanNativeNext();return;} WKWebView *wv=webs[wi]; NSUInteger thisIndex=wi++;
        [wv evaluateJavaScript:ADPersonSubmenuProbeDetectJS7298() completionHandler:^(id meta,NSError *err){
            ADMenuProbeAppend7252(path,[NSString stringWithFormat:@"PERSON_SUBMENU_WEB_TARGET index=%lu ptr=%p meta=%@ error=%@\n",(unsigned long)thisIndex,wv,ADMenuProbeSafe7252([meta isKindOfClass:[NSString class]]?meta:@"non-string"),err.localizedDescription?:@"none"]);
            ADMenuProbeEvalAppend7252(wv,path,ADAlexaProbeStylesJS7269([NSString stringWithFormat:@"person-submenu-web-%lu-initial",(unsigned long)thisIndex]),@"PERSON_SUBMENU_STYLE_INITIAL",^{
                ADMenuProbeScanWeb7252(wv,path,^(__unused NSString *reason){
                    ADMenuProbeEvalAppend7252(wv,path,ADAlexaProbeStylesJS7269([NSString stringWithFormat:@"person-submenu-web-%lu-final",(unsigned long)thisIndex]),@"PERSON_SUBMENU_STYLE_FINAL",^{dispatch_async(dispatch_get_main_queue(),scanWebNext);});
                });
            });
        }];
    };
    if(!webs.count&&!natives.count){finishAll();return;} scanWebNext();
}

// v7.268 Home probe: exact currently visible frame only. No scrolling, no full-document
// querySelectorAll/TreeWalker, and no retained background work. The bridge above lets an
// explicit trigger ask visible cross-origin ad child frames for their own current viewport.
static BOOL gADHomeFrameProbeBusy7265=NO;
static NSUInteger gADHomeFrameProbeRun7265=0;
static const unsigned long long kADHomeFrameProbeCap7265=12ull*1024ull*1024ull;
static NSString *ADHomeFrameProbePath7265(NSUInteger run){
    @try {
        NSDateFormatter *f=[NSDateFormatter new]; f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; f.timeZone=[NSTimeZone localTimeZone]; f.dateFormat=@"yyyyMMdd-HHmmss-SSS";
        NSString *stamp=[f stringFromDate:[NSDate date]]?:@"unknown",*name=[NSString stringWithFormat:@"AmazonDark-v7.336-home-frame-probe-%@-r%lu.txt",stamp,(unsigned long)run];
        NSString *docs=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject]; return [(docs.length?docs:NSTemporaryDirectory()) stringByAppendingPathComponent:name];
    } @catch(...) { return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"AmazonDark-v7.336-home-frame-probe-r%lu.txt",(unsigned long)run]]; }
}
static void ADHomeFrameProbeAppend7265(NSString *path,NSString *text){
    if(!path.length||!text.length)return;
    @try {
        NSFileManager *fm=[NSFileManager defaultManager]; [fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        unsigned long long cur=[[[fm attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] unsignedLongLongValue]; if(cur>=kADHomeFrameProbeCap7265)return;
        NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding]; unsigned long long remain=kADHomeFrameProbeCap7265-cur; if((unsigned long long)d.length>remain)d=[d subdataWithRange:NSMakeRange(0,(NSUInteger)remain)];
        if(![fm fileExistsAtPath:path]){[d writeToFile:path atomically:YES];return;} NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:path]; if(h){[h seekToEndOfFile];[h writeData:d];[h closeFile];}
    } @catch(...) {}
}
static WKWebView *ADHomeFrameVisibleWebView7265(void){
    @try {
        NSMutableOrderedSet<WKWebView *> *set=[NSMutableOrderedSet orderedSet]; for(WKWebView *wv in ADTrackedWebViews())if(wv)[set addObject:wv];
        for(UIWindow *w in UIApplication.sharedApplication.windows){if(!w||w.hidden||w.alpha<0.01)continue;NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:w];NSUInteger seen=0;while(q.count&&seen++<1800){UIView *v=q.firstObject;[q removeObjectAtIndex:0];if([v isKindOfClass:[WKWebView class]])[set addObject:(WKWebView *)v];if(q.count<1600)for(UIView *c in v.subviews)[q addObject:c];}}
        CGRect screen=UIScreen.mainScreen.bounds; WKWebView *best=nil; CGFloat bestArea=0;
        for(WKWebView *wv in set){if(!wv.window||wv.hidden||wv.alpha<0.01)continue;CGRect r=[wv convertRect:wv.bounds toView:nil],i=CGRectIntersection(r,screen);if(CGRectIsNull(i)||CGRectIsEmpty(i))continue;CGFloat a=i.size.width*i.size.height;if(a>bestArea){best=wv;bestArea=a;}}
        return best;
    } @catch(...) { return nil; }
}
static NSString *ADHomeFrameNativeSnapshot7265(void){
    NSMutableString *m=[NSMutableString string];
    @try {
        UIWindow *root=UIApplication.sharedApplication.keyWindow?:UIApplication.sharedApplication.windows.firstObject;if(!root)return @"NATIVE_NO_WINDOW\n";CGRect screen=UIScreen.mainScreen.bounds;
        NSMutableArray *q=[NSMutableArray arrayWithObject:@{@"v":root,@"d":@0}];NSUInteger visited=0,logged=0;
        [m appendFormat:@"NATIVE_FRAME_BEGIN screen=(%.1f,%.1f %.1fx%.1f)\n",screen.origin.x,screen.origin.y,screen.size.width,screen.size.height];
        while(q.count&&visited++<1800&&logged<1000){NSDictionary *it=q.firstObject;[q removeObjectAtIndex:0];UIView *v=it[@"v"];NSUInteger d=[it[@"d"] unsignedIntegerValue];if(!v||v.hidden||v.alpha<0.01)continue;CGRect r=CGRectZero;@try{r=[v convertRect:v.bounds toView:nil];}@catch(...){}BOOL rootish=(v==root),hit=rootish||(r.size.width>.2&&r.size.height>.2&&CGRectIntersectsRect(r,screen));if(!hit)continue;NSString *cn=NSStringFromClass(v.class)?:@"?",*aid=ADProbeSafe7233(v.accessibilityIdentifier);CALayer *l=v.layer;[m appendFormat:@"N d=%lu cls=%@ aid=\"%@\" frame=(%.1f,%.1f %.1fx%.1f) alpha=%.2f bg=%@ tint=%@ border=%.2f/%@ radius=%.2f subviews=%lu layers=%lu %@ %@\n",(unsigned long)d,cn,aid,r.origin.x,r.origin.y,r.size.width,r.size.height,v.alpha,ADProbeColor7233(v.backgroundColor),ADProbeColor7233(v.tintColor),l.borderWidth,ADProbeCG7233(l.borderColor),l.cornerRadius,(unsigned long)v.subviews.count,(unsigned long)l.sublayers.count,ADProbeText7233(v),ADProbeControl7233(v)];logged++;if(d<28)for(UIView *c in v.subviews)if(q.count<1500)[q addObject:@{@"v":c,@"d":@(d+1)}];}
        [m appendFormat:@"NATIVE_FRAME_END visited=%lu logged=%lu truncated=%d\n",(unsigned long)visited,(unsigned long)logged,(visited>=1800||logged>=1000)?1:0];
    } @catch(NSException *e){[m appendFormat:@"NATIVE_EXCEPTION %@\n",e.name?:@"?"];}
    return m;
}
static NSString *ADHomeFramePrettyJSON7265(id result){
    if(![result isKindOfClass:[NSString class]])return [NSString stringWithFormat:@"WEB_RESULT_TYPE %@\n",NSStringFromClass([result class])?:@"nil"];
    NSString *s=(NSString *)result;@try{NSData *d=[s dataUsingEncoding:NSUTF8StringEncoding];id o=[NSJSONSerialization JSONObjectWithData:d options:0 error:nil];if(o){NSData *p=[NSJSONSerialization dataWithJSONObject:o options:NSJSONWritingPrettyPrinted error:nil];NSString *x=[[NSString alloc]initWithData:p encoding:NSUTF8StringEncoding];if(x.length)return [x stringByAppendingString:@"\n"];}}@catch(...){}return [s stringByAppendingString:@"\n"];
}

// v7.272: dedicated /s product-shopping / scrolling forensics probe restored from the
// historical Search-results probe lineage. It is explicit-trigger only and reuses the
// existing screenshot/SIGUSR2 dispatcher; no second listener, signal source, document-start
// script, observer, timer, RAF or scroll listener is added. The probe never changes the
// product-scroll offset.
static BOOL gADProductScrollProbeBusy7272=NO;
static NSUInteger gADProductScrollProbeRun7272=0;
static NSString *ADProductScrollProbePath7272(NSUInteger run){
    @try {
        NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.timeZone=[NSTimeZone localTimeZone];f.dateFormat=@"yyyyMMdd-HHmmss-SSS";
        NSString *stamp=[f stringFromDate:[NSDate date]]?:@"unknown",*name=[NSString stringWithFormat:@"AmazonDark-v7.336-product-scroll-probe-%@-r%lu.txt",stamp,(unsigned long)run];
        NSString *docs=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject];return [(docs.length?docs:NSTemporaryDirectory()) stringByAppendingPathComponent:name];
    } @catch(...) {return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"AmazonDark-v7.336-product-scroll-probe-r%lu.txt",(unsigned long)run]];}
}
static WKWebView *ADProductScrollWebView7272(void){
    @try {
        CGRect screen=UIScreen.mainScreen.bounds;WKWebView *best=nil;CGFloat bestArea=0;
        for(WKWebView *wv in ADTrackedWebViews()){
            if(!wv||!wv.window||wv.hidden||wv.alpha<0.01)continue;NSString *p=wv.URL.path?:@"";if(!([p isEqualToString:@"/s"]||[p hasPrefix:@"/s/"]))continue;
            CGRect r=[wv convertRect:wv.bounds toView:nil],i=CGRectIntersection(r,screen);if(CGRectIsNull(i)||CGRectIsEmpty(i))continue;CGFloat a=i.size.width*i.size.height;if(a>bestArea){best=wv;bestArea=a;}
        }
        if(best)return best;WKWebView *wv=ADHomeFrameVisibleWebView7265();NSString *p=wv.URL.path?:@"";return ([p isEqualToString:@"/s"]||[p hasPrefix:@"/s/"])?wv:nil;
    } @catch(...) {return nil;}
}
static NSString *ADProductScrollProbeJS7272(void){
    // v7.289: reuse the mature v7.280 Menu DOM forensic serializer for /s. It emits every
    // current/near-viewport node (up to 2600) with computed paint, pseudo-elements,
    // media, technical attributes, text length/hash and ancestry. No page scrolling.
    return ADMenuProbeDOMJS7252(0,NO);
}
static NSString *ADProductScrollHitGridJS7280(void){
    return @"(function(){try{function C(v,n){v=String(v==null?'':v).replace(/[\\r\\n\\t]+/g,' ').replace(/\\|/g,'¦').replace(/\\\\/g,'/');return v.length>(n||160)?v.slice(0,n||160)+'…':v}function S(e){if(!e)return '';var c='';try{c=typeof e.className==='string'?e.className:(e.className&&e.className.baseVal)||''}catch(_){ }var id='';try{id=e.id||''}catch(_){ }return String(e.tagName||'?').toLowerCase()+(id?'#'+C(id,70):'')+(c?'.'+C(c,110):'')}function P(e){try{var r=e.getBoundingClientRect(),c=getComputedStyle(e),b=getComputedStyle(e,'::before'),a=getComputedStyle(e,'::after'),ch=[],x=e.parentElement;for(var i=0;x&&i<8;i++,x=x.parentElement)ch.push(S(x));return {sig:S(e),r:[+r.x.toFixed(1),+r.y.toFixed(1),+r.width.toFixed(1),+r.height.toFixed(1)],bg:c.backgroundColor,fg:c.color,fill:c.fill,border:[c.borderTop,c.borderRight,c.borderBottom,c.borderLeft],rad:c.borderRadius,outline:c.outline,shadow:c.boxShadow,filter:c.filter,blend:c.mixBlendMode,pointer:c.pointerEvents,pos:c.position,z:c.zIndex,before:{content:String(b.content||'').length,bg:b.backgroundColor,fg:b.color,border:b.borderTop,rad:b.borderRadius},after:{content:String(a.content||'').length,bg:a.backgroundColor,fg:a.color,border:a.borderTop,rad:a.borderRadius},chain:ch}}catch(_){return {sig:S(e),err:1}}}var pts=[],xs=[12,54,108,162,216,270,324,378,418],ys=[];for(var y=12;y<innerHeight;y+=48)ys.push(y);for(var yi=0;yi<ys.length;yi++)for(var xi=0;xi<xs.length;xi++){var x=xs[xi],y=ys[yi],es=[];try{es=document.elementsFromPoint(x,y).slice(0,6).map(S)}catch(_){ }pts.push({p:[x,y],stack:es})}var root=document.getElementById('search')||document.body,all=root?root.querySelectorAll('*'):[],light=[],seen=0;for(var i=0;i<all.length&&seen<9000&&light.length<180;i++,seen++){var e=all[i],r=e.getBoundingClientRect();if(r.width<4||r.height<4||r.bottom< -100||r.top>innerHeight+100||r.right<0||r.left>innerWidth)continue;var c=getComputedStyle(e),m=/rgba?\\(([^)]+)\\)/.exec(c.backgroundColor),lum=0,alpha=0;if(m){var q=m[1].split(',').map(parseFloat);lum=(q[0]*.2126+q[1]*.7152+q[2]*.0722)/255;alpha=q.length>3?q[3]:1}var rad=parseFloat(c.borderRadius)||0,bw=parseFloat(c.borderTopWidth)||0,interactive=/^(A|BUTTON|INPUT|SELECT|TEXTAREA)$/.test(e.tagName)||e.getAttribute('role')==='button'||c.cursor==='pointer';if((alpha>.05&&lum>.28)||(rad>=10&&(bw>.2||interactive)))light.push(P(e))}return JSON.stringify({viewport:[innerWidth,innerHeight,devicePixelRatio],offset:[scrollX,scrollY],scanned:seen,paintedRoundedCandidates:light,hitGrid:pts},null,2)}catch(e){return 'PRODUCT_SCROLL_HITGRID_ERR '+String(e&&e.message||e)}})();";
}
static void ADCaptureProductScrollProbe7272(NSString *trigger){
    if(!gP.enabled||gADProductScrollProbeBusy7272)return;WKWebView *wv=ADProductScrollWebView7272();if(!wv)return;gADProductScrollProbeBusy7272=YES;NSUInteger run=++gADProductScrollProbeRun7272;NSString *path=ADProductScrollProbePath7272(run);UIScrollView *sv=wv.scrollView;CGRect wr=CGRectZero;@try{wr=[wv convertRect:wv.bounds toView:nil];}@catch(...){}
    ADHomeFrameProbeAppend7265(path,[NSString stringWithFormat:@"AMAZONDARK v7.336 PRODUCT SHOPPING/SCROLLING WIDE FORENSICS PROBE\nversion=%s\ntrigger=%@\ndate=%@\nfile=%@\nroute=/s only\npolicy=no typed query strings/no visible element strings/no URL values/no src/href values/no network payloads; technical ids/classes/testids/roles plus privacy-safe text lengths/hashes retained\nscan=explicit-trigger only; NO scrolling; all current/near-viewport DOM nodes up to 2600 with computed paint/pseudo/media/ancestry plus painted-rounded candidate inventory and viewport elementsFromPoint hit grid\nnormal_runtime=no second screenshot observer, no second SIGUSR2 source, no observer/timer/RAF/web-scroll listener/recurring DOM scan\nWEB_TARGET frame=(%.1f,%.1f %.1fx%.1f) offset=(%.1f,%.1f) content=(%.1fx%.1f) -- OFFSET NOT MODIFIED\n",AD_VERSION,trigger?:@"unknown",[NSDate date],path.lastPathComponent,wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height]);
    ADHomeFrameProbeAppend7265(path,ADHomeFrameNativeSnapshot7265());
    [wv evaluateJavaScript:ADProductScrollProbeJS7272() completionHandler:^(id result,NSError *error){
        ADHomeFrameProbeAppend7265(path,[NSString stringWithFormat:@"MAIN_DOCUMENT_WIDE error=%@\n",error?error.localizedDescription:@"none"]);
        if([result isKindOfClass:[NSString class]])ADHomeFrameProbeAppend7265(path,[(NSString *)result stringByAppendingString:@"\n"]);else ADHomeFrameProbeAppend7265(path,ADHomeFramePrettyJSON7265(result));
        [wv evaluateJavaScript:ADProductScrollHitGridJS7280() completionHandler:^(id grid,NSError *gridError){
            ADHomeFrameProbeAppend7265(path,[NSString stringWithFormat:@"HITGRID_AND_ROUNDED error=%@\n",gridError?gridError.localizedDescription:@"none"]);
            ADHomeFrameProbeAppend7265(path,ADHomeFramePrettyJSON7265(grid));
            ADHomeFrameProbeAppend7265(path,@"PRODUCT_SCROLL_PROBE_END\n================ END RUN ================\n");gADProductScrollProbeBusy7272=NO;
        }];
    }];
}

static void ADCaptureHomeFrameProbe7265(NSString *trigger){
    if(!gP.enabled||gADHomeFrameProbeBusy7265)return;gADHomeFrameProbeBusy7265=YES;NSUInteger run=++gADHomeFrameProbeRun7265;NSString *path=ADHomeFrameProbePath7265(run);WKWebView *wv=ADHomeFrameVisibleWebView7265();
    ADHomeFrameProbeAppend7265(path,[NSString stringWithFormat:@"AMAZONDARK v7.336 HOME CURRENT-FRAME PROBE\nversion=%s\ntrigger=%@\ndate=%@\nfile=%@\npolicy=current visible screen only; NO scrolling; NO full Home-document scan; privacy-safe text lengths/hashes in WebKit; native accessibility labels not emitted\nweb=bounded visible-branch recursion max 700 nodes per frame; cross-origin child frames respond only to this explicit trigger\nnative=bounded visible-branch walk max 1000 logged nodes\n",AD_VERSION,trigger?:@"unknown",[NSDate date],path.lastPathComponent]);
    ADHomeFrameProbeAppend7265(path,ADHomeFrameNativeSnapshot7265());
    if(!wv){ADHomeFrameProbeAppend7265(path,@"WEB_NO_VISIBLE_WKWEBVIEW\nHOME_FRAME_PROBE_END\n================ END RUN ================\n");gADHomeFrameProbeBusy7265=NO;return;}
    CGRect wr=CGRectZero;@try{wr=[wv convertRect:wv.bounds toView:nil];}@catch(...){}UIScrollView *sv=wv.scrollView;ADHomeFrameProbeAppend7265(path,[NSString stringWithFormat:@"WEB_TARGET ptr=%p frame=(%.1f,%.1f %.1fx%.1f) offset=(%.1f,%.1f) content=(%.1fx%.1f) -- OFFSET NOT MODIFIED\n",wv,wr.origin.x,wr.origin.y,wr.size.width,wr.size.height,sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height]);
    NSString *start=@"(function(){try{var token='h7266-'+Date.now()+'-'+Math.random().toString(36).slice(2);if(!window.__adHomeProbeSnap7265)return JSON.stringify({error:'bridge-missing'});window.__adHomeProbeCollector7265={token:token,main:window.__adHomeProbeSnap7265(),responses:[]};var req={__adHomeProbeReq7265:1,token:token},a=document.getElementsByTagName('iframe');if(window.__adHomeProbeBroadcast7265)window.__adHomeProbeBroadcast7265(req);return JSON.stringify({started:1,token:token,mainNodes:window.__adHomeProbeCollector7265.main.emitted||0,frameElements:a.length})}catch(e){return JSON.stringify({error:String(e&&e.message||e)})}})();";
    NSString *heal=ADHomeFrameProbeBridgeJS7265();
    [wv evaluateJavaScript:heal completionHandler:^(id healed,NSError *healError){
        ADHomeFrameProbeAppend7265(path,[NSString stringWithFormat:@"WEB_BOOTSTRAP error=%@ result=%@\n",healError?healError.localizedDescription:@"none",[healed isKindOfClass:[NSString class]]?healed:@"(non-string)"]);
        [wv evaluateJavaScript:start completionHandler:^(id result,NSError *error){ADHomeFrameProbeAppend7265(path,[NSString stringWithFormat:@"WEB_START error=%@ result=%@\n",error?error.localizedDescription:@"none",[result isKindOfClass:[NSString class]]?result:@"(non-string)"]);dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.55*NSEC_PER_SEC)),dispatch_get_main_queue(),^{NSString *finish=@"(function(){try{return JSON.stringify(window.__adHomeProbeCollector7265||{error:'collector-missing'})}catch(e){return JSON.stringify({error:String(e&&e.message||e)})}})();";[wv evaluateJavaScript:finish completionHandler:^(id final,NSError *err){ADHomeFrameProbeAppend7265(path,[NSString stringWithFormat:@"WEB_FRAME_DATA error=%@\n",err?err.localizedDescription:@"none"]);ADHomeFrameProbeAppend7265(path,ADHomeFramePrettyJSON7265(final));ADHomeFrameProbeAppend7265(path,@"HOME_FRAME_PROBE_END\n================ END RUN ================\n");gADHomeFrameProbeBusy7265=NO;}];});}];
    }];
}

// v7.292: screenshot/SIGUSR2 fallback for Alexa. Some native Rufus frames can be
// fully visible while ANXTabBarButton#rufusTab does not expose UIControlStateSelected at
// the exact notification turn. Detect only the probe-proven visible native Alexa root markers;
// this reuses the existing single trigger observer and adds no recurring scan.
static BOOL ADAlexaVisibleNativeContent7291(void){
    @try {
        CGRect screen=UIScreen.mainScreen.bounds; NSUInteger seen=0;
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.01)continue;
            NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:w];
            while(q.count&&seen++<1800){
                UIView *v=q.firstObject; [q removeObjectAtIndex:0];
                NSString *aid=v.accessibilityIdentifier?:@"";
                if([aid isEqualToString:@"navigation-root"]||
                   [aid isEqualToString:@"MainStackNavigation"]||
                   [aid isEqualToString:@"WrappedNileFeatureContainer"]){
                    CGRect r=CGRectZero; @try { r=[v convertRect:v.bounds toView:nil]; } @catch(...) {}
                    CGRect i=CGRectIntersection(r,screen);
                    if(!v.hidden&&v.alpha>=0.01&&!CGRectIsNull(i)&&!CGRectIsEmpty(i)&&
                       i.size.width>=180.0&&i.size.height>=180.0)return YES;
                }
                if(q.count<1600)for(UIView *c in v.subviews)[q addObject:c];
            }
        }
    } @catch(...) {}
    return NO;
}

static void ADCaptureThreeTabProbe7254(NSString *trigger){
    if(!gP.enabled)return;
    // Dispatch only from the current probe-proven native bottom-tab identifiers.
    if(ADProbeTabSelected7254(@"home")){ if(ADProductScrollWebView7272()){ADCaptureProductScrollProbe7272(trigger);return;} ADCaptureHomeFrameProbe7265(trigger); return; }
    if(ADProbeTabSelected7254(@"meTab")){ if(ADPersonSubmenuLikelyActive7298()){ADCapturePersonSubmenuProbe7298(trigger);return;} ADCapturePersonProbe7233(trigger); return; }
    if(ADProbeTabSelected7254(@"cartTab")){ ADCaptureCartProbe7241(trigger); return; }
    if(ADProbeTabSelected7254(@"menuTab")){ ADCaptureMenuProbe7252(trigger); return; }
    if(ADProbeTabSelected7254(@"rufusTab")){ ADCaptureAlexaProbe7269(trigger); return; }
    if(ADAlexaVisibleNativeContent7291()){ ADCaptureAlexaProbe7269([trigger stringByAppendingString:@"-visible-fallback"]); return; }
}
static void ADInstallThreeTabProbes7254(void){
    static dispatch_once_t once; dispatch_once(&once,^{
        signal(SIGUSR2,SIG_IGN);
        gADThreeTabProbeSignal7254=dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,SIGUSR2,0,dispatch_get_main_queue());
        if(gADThreeTabProbeSignal7254){
            dispatch_source_set_event_handler(gADThreeTabProbeSignal7254,^{ ADCaptureThreeTabProbe7254(@"SIGUSR2"); });
            dispatch_resume(gADThreeTabProbeSignal7254);
        }
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationUserDidTakeScreenshotNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *n){ ADCaptureThreeTabProbe7254(@"screenshot"); }];
    });
}

// v7.272 optimized keeps the same visual contract/probes while removing alternate owners, dead code and redundant hot-path work.

#pragma clang diagnostic pop
