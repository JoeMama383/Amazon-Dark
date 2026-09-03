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
//   - the event-driven cover has an absolute hard cap, so it can never remain stuck;
//   - only ever triggered by a scene whose bundle id is exactly Amazon.

#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/runtime.h>

static NSString * const kAMZ      = @"com.amazon.Amazon";
static NSString * const kDefaults = @"com.colindavidr.amazondark";
static const NSTimeInterval kCoverFade    = 0.55; // lift animation
static const NSTimeInterval kReadySettle   = 0.40; // v7.116: keep the cover fully opaque for
                                                  // a short post-ready settle window. If the
                                                  // ready event arrives early, the existing
                                                  // 1.40 s minimum absorbs this completely.
static const NSTimeInterval kCoverHardCap = 20.0; // absolute max on screen
static const NSTimeInterval kWarmShieldFallback = 2.50; // bounded safety fallback if foreground-ready races
static const NSTimeInterval kWarmShieldSettle   = 0.35; // let the live resumed scene composite under solid dark
static const NSTimeInterval kWarmShieldFade     = 0.18; // warm resume only; cold launch keeps the stock 0.55 s fade

@interface SBSceneView : UIView
@end

static double gPresentAt;

static BOOL ADSBEnabled(void) {
    @try {
        NSString *path=[@"/var/jb/var/mobile/Library/Preferences" stringByAppendingPathComponent:
                        [kDefaults stringByAppendingPathExtension:@"plist"]];
        id value=[NSDictionary dictionaryWithContentsOfFile:path][@"enabled"];
        return value ? [value boolValue] : YES;
    } @catch (__unused NSException *e) { return YES; }
}

static NSString *ADSceneBundleId(UIView *v) {
    @try {
        id val=[v valueForKeyPath:@"sceneHandle.application.bundleIdentifier"];
        return [val isKindOfClass:[NSString class]] ? val : nil;
    } @catch (__unused NSException *e) { return nil; }
}

static void ADDismissCover(void);
static UIView *gCoverOverlay;
static SBSceneView *gCoverHost;
static const void *kCoveredKey = &kCoveredKey;
static BOOL gWarmShieldActive = NO;
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
        image=[UIImage imageWithContentsOfFile:@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png"];
    });
    return image;
}

// v7.305: warm-resume protection derived from the proven v7.185/v7.186 mask,
// but deliberately logo-free. A live/suspended Amazon process can expose a cached/native
// white frame before Amazon receives foreground callbacks. Cover only that pre-composite
// interval with a plain dark surface so warm reopening never replays the Amazon launch art.
static void ADDismissWarmShield(void);
static void ADAttachWarmShieldToScene(UIView *host) {
    @try {
        if (!host) return;
        if (gCoverOverlay && gCoverOverlay.superview == host) return;
        UIView *ov = [[UIView alloc] initWithFrame:host.bounds];
        ov.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        ov.backgroundColor = [UIColor colorWithRed:0.094 green:0.102 blue:0.106 alpha:1.0];
        ov.userInteractionEnabled = NO;
        [host addSubview:ov];
        gCoverOverlay = ov;
        gCoverHost = (SBSceneView *)host;
        gWarmShieldActive = YES;
        unsigned myGen = ++gCoverGen;
        gPresentAt = CFAbsoluteTimeGetCurrent();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kWarmShieldFallback * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (myGen == gCoverGen && gWarmShieldActive) ADDismissWarmShield();
        });
    } @catch (__unused NSException *e) {}
}

static void ADDismissWarmShield(void) {
    @try {
        if (!gCoverOverlay || !gWarmShieldActive) return;
        UIView *ov = gCoverOverlay; gCoverOverlay = nil; gWarmShieldActive = NO;
        SBSceneView *h=gCoverHost; gCoverHost=nil;
        if(h)objc_setAssociatedObject(h,kCoveredKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [UIView animateWithDuration:kWarmShieldFade animations:^{ ov.alpha = 0.0; }
                         completion:^(BOOL f){ @try { [ov removeFromSuperview]; }
                                               @catch (__unused NSException *e) {} }];
    } @catch (__unused NSException *e) {}
}

// Dark surface parented to the zooming scene view, so SpringBoard's launch
// animation plays exactly as it does for every other app -- only its contents
// are dark instead of Amazon's white launch screen.
static void ADAttachCoverToScene(UIView *host) {
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
        gWarmShieldActive = NO;
        unsigned myGen = ++gCoverGen;

        gPresentAt = CFAbsoluteTimeGetCurrent();

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHardCap * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            @try { if (gCoverOverlay && myGen == gCoverGen){ UIView *x = gCoverOverlay; gCoverOverlay = nil; gWarmShieldActive = NO;
                       SBSceneView *h=gCoverHost; gCoverHost=nil; if(h)objc_setAssociatedObject(h,kCoveredKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                       [x removeFromSuperview]; } }
            @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

static void ADDismissCover(void) {
    @try {
        if (!gCoverOverlay) return;
        UIView *ov = gCoverOverlay; gCoverOverlay = nil; gWarmShieldActive = NO;
        SBSceneView *h=gCoverHost; gCoverHost=nil; if(h)objc_setAssociatedObject(h,kCoveredKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

        NSString *bid = ADSceneBundleId(self);
        if (![bid isEqualToString:kAMZ]) return;

        // v7.305: preserve v7.301 cold-launch presentation exactly. For a live/suspended
        // process, use only a logo-free dark shield so a cached/native white frame cannot leak
        // while also avoiding v7.186's visible replay of the Amazon loading presentation.
        BOOL alive = ADAmazonProcessAlive();

        BOOL already = (objc_getAssociatedObject(self, kCoveredKey) != nil);
        if (already) return;
        objc_setAssociatedObject(self, kCoveredKey, @YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (alive) ADAttachWarmShieldToScene(self);
        else ADAttachCoverToScene(self);
    } @catch (__unused NSException *e) {}
}
%end



%ctor {
    if(!ADSBEnabled())return;

    // Event-driven dismissal: the app posts readiness after its first dark composite.
    // The independent hard cap above is a SpringBoard safety invariant only.
    @try {
        static int adReadyToken = 0;
        notify_register_dispatch("com.colindavidr.amazondark.ready", &adReadyToken,
                                 dispatch_get_main_queue(), ^(int t){
            @try {
                if (!gCoverOverlay || gWarmShieldActive) return;
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
                unsigned gen = gCoverGen;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    if(gen==gCoverGen && !gWarmShieldActive) ADDismissCover();
                });
            } @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
    @try {
        static int adForegroundToken = 0;
        notify_register_dispatch("com.colindavidr.amazondark.foreground-ready", &adForegroundToken,
                                 dispatch_get_main_queue(), ^(int t){
            @try {
                if (!gCoverOverlay || !gWarmShieldActive) return;
                unsigned gen = gCoverGen;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(kWarmShieldSettle*NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    if(gen==gCoverGen && gWarmShieldActive) ADDismissWarmShield();
                });
            } @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
    @autoreleasepool {
        @try { %init; }
        @catch (__unused NSException *e) {}
    }
}
