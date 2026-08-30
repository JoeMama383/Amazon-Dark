// AmazonDarkSB.xm
// SpringBoard-side dark cover for the Amazon Shopping launch screen.
//
// Injected ONLY into com.apple.springboard (AmazonDarkSB.plist). Amazon's white
// LaunchScreen is drawn by the render server before Amazon's process is alive,
// so it can't be themed from inside Amazon. Here we float a dark WINDOW over the
// launching Amazon scene and lift it a few seconds later.
//
// Why a separate window and not a subview of the scene: an opaque view placed
// INSIDE SBSceneView makes FrontBoard treat Amazon's scene as fully occluded, so
// it suspends rendering and the app never draws (permanent black). A separate
// SpringBoard window floats on top without changing the app scene's occlusion,
// so Amazon renders normally underneath and is there the instant we lift it.
//
// SAFETY (runs in SpringBoard => a fault here is safe mode):
//   - every entry point is @try/@catch guarded;
//   - the cover window lifts on a timer AND an absolute hard cap, so it can
//     never get stuck blacking out the screen;
//   - only ever triggered by a scene whose bundle id is exactly Amazon.

#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/runtime.h>

static NSString * const kAMZ      = @"com.amazon.Amazon";
static NSString * const kDefaults = @"com.colindavidr.amazondark";
static const NSTimeInterval kCoverHold    = 17.0;  // LAST RESORT. The app guarantees a
                                                  // signal after a slow cold Home composite; the app-side gate can stay
                                                  // active for roughly 15 s plus JS completion latency, so this fallback
                                                  // must remain above that correctness window.
static const NSTimeInterval kCoverFade    = 0.55; // lift animation
static const NSTimeInterval kReadySettle   = 0.40; // v7.116: keep the cover fully opaque for
                                                  // a short post-ready settle window. If the
                                                  // ready event arrives early, the existing
                                                  // 1.40 s minimum absorbs this completely.
static const NSTimeInterval kCoverHardCap = 20.0; // absolute max on screen
static const NSTimeInterval kWarmCoverFallback = 2.50; // only if foreground-ready races/is missed
static const NSTimeInterval kWarmReadySettle = 0.40; // let the resumed scene composite under the mask

@interface SBSceneView : UIView
@end

static double gPresentAt;

static BOOL ADSBEnabled(void) {
    @try {
        CFPreferencesAppSynchronize((__bridge CFStringRef)kDefaults);
        Boolean valid = NO;
        Boolean on = CFPreferencesGetAppBooleanValue(CFSTR("enabled"),
                        (__bridge CFStringRef)kDefaults, &valid);
        if (valid) return on ? YES : NO;
        // CFPreferences came back invalid: read the file directly rather than
        // assuming the tweak is on. Guessing "on" here is what let a disabled
        // tweak keep drawing a cover.
        @try {
            for (NSString *base in @[@"/var/mobile/Library/Preferences/",
                                     @"/var/jb/var/mobile/Library/Preferences/"]) {
                NSString *pp = [base stringByAppendingFormat:@"%@.plist", kDefaults];
                NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:pp];
                if (d && d[@"enabled"] != nil) return [d[@"enabled"] boolValue];
            }
        } @catch (__unused NSException *e) {}
        return YES;   // genuinely no preference written yet
    } @catch (__unused NSException *e) { return YES; }
}

static NSString *ADSceneBundleId(UIView *v) {
    static NSArray<NSString *> *paths;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ paths = @[ @"sceneHandle.application.bundleIdentifier",
                                      @"sceneHandle.sceneIdentity.bundleIdentifier",
                                      @"application.bundleIdentifier",
                                      @"sceneHandle.sceneIdentity.bundleIdentifierOverride",
                                      @"_sceneHandle.application.bundleIdentifier" ]; });
    for (NSString *kp in paths) {
        @try {
            id val = [v valueForKeyPath:kp];
            if ([val isKindOfClass:[NSString class]] && [(NSString *)val length]) {
                return (NSString *)val;
            }
        } @catch (__unused NSException *e) {}
    }
    return nil;
}

static void ADDismissCover(void);
static UIView *gCoverOverlay;
static SBSceneView *gCoverHost;
static const void *kCoveredKey = &kCoveredKey;
static BOOL gCoverWarm;
static unsigned gCoverGen;

// YES when Amazon already has a running process -- i.e. this is a resume, not a
// cold launch. Nothing here is required to exist; unknown means "cover it".
static BOOL ADAmazonProcessAlive(void) {
    @try {
        Class ctl = objc_getClass("SBApplicationController");
        if (!ctl || ![ctl respondsToSelector:@selector(sharedInstance)]) return NO;
        id shared = [ctl performSelector:@selector(sharedInstance)];
        if (!shared || ![shared respondsToSelector:@selector(applicationWithBundleIdentifier:)]) return NO;
        id app = [shared performSelector:@selector(applicationWithBundleIdentifier:) withObject:kAMZ];
        if (!app || ![app respondsToSelector:@selector(processState)]) return NO;
        id ps = [app performSelector:@selector(processState)];
        if (!ps) return NO;
        if ([ps respondsToSelector:@selector(isRunning)]) {
            NSNumber *r = [ps valueForKey:@"isRunning"];
            if (r) return r.boolValue;
        }
    } @catch (__unused NSException *e) {}
    return NO;
}

static UIImage *ADSplashImage7191(void) {
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (NSString *cp in @[@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png",
                               @"/Library/Application Support/AmazonDark/splash-logo.png"]) {
            image = [UIImage imageWithContentsOfFile:cp];
            if (image) break;
        }
    });
    return image;
}

// Dark surface parented to the zooming scene view, so SpringBoard's launch
// animation plays exactly as it does for every other app -- only its contents
// are dark instead of Amazon's white launch screen.
static void ADAttachCoverToScene(UIView *host, BOOL warm) {
    @try {
        if (!host) return;
        if (gCoverOverlay && gCoverOverlay.superview == host) return;
        UIColor *dk = [UIColor colorWithRed:0.094 green:0.102 blue:0.106 alpha:1.0];
        UIView *ov = [[UIView alloc] initWithFrame:host.bounds];
        ov.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        ov.backgroundColor = dk;
        ov.userInteractionEnabled = NO;

        UIImage *splash = ADSplashImage7191();
        if (splash) {
            UIImageView *logo = [[UIImageView alloc] initWithImage:splash];
            logo.contentMode = UIViewContentModeScaleAspectFit;
            logo.translatesAutoresizingMaskIntoConstraints = NO;
            [ov addSubview:logo];
            CGFloat lw = MAX(host.bounds.size.width, 200.0) * 0.62;
            CGFloat lh = lw * (splash.size.height / MAX(splash.size.width, 1.0));
            [NSLayoutConstraint activateConstraints:@[
                [logo.centerXAnchor constraintEqualToAnchor:ov.centerXAnchor],
                [logo.centerYAnchor constraintEqualToAnchor:ov.centerYAnchor],
                [logo.widthAnchor constraintEqualToConstant:lw],
                [logo.heightAnchor constraintEqualToConstant:lh],
            ]];
        }
        [host addSubview:ov];
        gCoverOverlay = ov;
        gCoverHost = (SBSceneView *)host;
        gCoverWarm = warm;
        unsigned myGen = ++gCoverGen;

        gPresentAt = CFAbsoluteTimeGetCurrent();

        if (warm) {
            // v7.185: historical warm/soft-launch mask. DidBecomeActive normally releases
            // this first; bounded fallback only prevents a missed notification from sticking.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kWarmCoverFallback * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (myGen == gCoverGen && gCoverOverlay && gCoverWarm) {
                    ADDismissCover();
                }
            });
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHold * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (myGen == gCoverGen){
                    ADDismissCover();
                }
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHardCap * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                @try { if (gCoverOverlay && myGen == gCoverGen){ UIView *x = gCoverOverlay; gCoverOverlay = nil;
                           SBSceneView *h=gCoverHost; gCoverHost=nil; gCoverWarm=NO; if(h)objc_setAssociatedObject(h,kCoveredKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                           [x removeFromSuperview]; } }
                @catch (__unused NSException *e) {}
            });
        }
    } @catch (__unused NSException *e) {}
}

static void ADDismissCover(void) {
    @try {
        if (!gCoverOverlay) return;
        UIView *ov = gCoverOverlay; gCoverOverlay = nil;
        SBSceneView *h=gCoverHost; gCoverHost=nil; gCoverWarm=NO; if(h)objc_setAssociatedObject(h,kCoveredKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [UIView animateWithDuration:kCoverFade animations:^{ ov.alpha = 0.0; }
                         completion:^(BOOL f){ @try { [ov removeFromSuperview]; }
                                               @catch (__unused NSException *e) {} }];
    } @catch (__unused NSException *e) {}
}

%hook SBSceneView
- (void)didMoveToWindow {
    %orig;
    @try {
        if (!self.window) return;

        if (!ADSBEnabled()) return;
        NSString *bid = ADSceneBundleId(self);
        if (![bid isEqualToString:kAMZ]) return;

        // Cold and warm scene entries are both masked. Historical device testing showed
        // that a running/suspended process can still expose a cached/native white first frame.
        BOOL alive = ADAmazonProcessAlive();
        // One active cover per scene entry. Unknown process state is treated as cold;
        // the hard cap guarantees that a missed app signal cannot leave the mask stuck.
        // Per active launch, not permanently per scene: the marker is cleared when the
        // cover leaves so a reused SpringBoard scene can protect a later cold launch too.
        BOOL already = (objc_getAssociatedObject(self, kCoveredKey) != nil);
        if (already) return;
        objc_setAssociatedObject(self, kCoveredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // Cold launches use the full readiness gate. A live/suspended Amazon process gets
        // the proven warm first-frame mask instead of exposing a cached/native white frame.
        ADAttachCoverToScene(self, alive);
    } @catch (__unused NSException *e) {}
}
%end



%ctor {

    // Event-driven dismissal, matching the system: the launch screen leaves at
    // the app's first frame, not on a timer. The app posts this once its UI is
    // up; the kCoverHold timer stays only as a fallback for a launch where the
    // signal never arrives.
    @try {
        static int adReadyToken = 0;
        notify_register_dispatch("com.colindavidr.amazondark.ready", &adReadyToken,
                                 dispatch_get_main_queue(), ^(int t){
            @try {
                if (!gCoverOverlay || gCoverWarm) return;
                double shown = CFAbsoluteTimeGetCurrent() - gPresentAt;
                // v7.116: the app-side handoff is now event-driven and deliberately free of
                // DOM polling/timers. A lifecycle event can still precede Amazon's final
                // splash-to-Home composite by a few frames, which made the stock white
                // loading surface briefly visible through our 0.55 s fade. Keep that
                // protection here in SpringBoard instead of putting polling/delays back
                // into Amazon. This is bounded and one-shot: wait until BOTH the historical
                // 1.40 s minimum and a 0.40 s post-ready settle window are satisfied.
                double minimumRemaining = shown < 1.40 ? (1.40 - shown) : 0.0;
                double wait = minimumRemaining > kReadySettle ? minimumRemaining : kReadySettle;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ ADDismissCover(); });
            } @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
    @try {
        static int adForegroundToken = 0;
        notify_register_dispatch("com.colindavidr.amazondark.foreground-ready", &adForegroundToken,
                                 dispatch_get_main_queue(), ^(int t){
            @try {
                if (!gCoverOverlay || !gCoverWarm) return;
                double shown = CFAbsoluteTimeGetCurrent() - gPresentAt;
                double wait = kWarmReadySettle;
                if (shown < 0.20) wait = MAX(wait, 0.20 - shown);
                unsigned gen = gCoverGen;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(wait*NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ if(gen==gCoverGen && gCoverWarm) ADDismissCover(); });
            } @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}

    @autoreleasepool {
        @try { %init; }
        @catch (__unused NSException *e) {}
    }
}
