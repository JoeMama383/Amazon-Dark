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
// v7.306: persistent for the lifetime of this SBSceneView. A normal warm resume reuses
// the same scene and must not replay launch. A newly constructed scene (cold launch or
// UIKit scene reconstruction) receives the normal v7.301 Amazon cover even if the app
// process itself is still alive.
static const void *kSceneSeenKey7306 = &kSceneSeenKey7306;
static unsigned gCoverGen;

// v7.306 deliberately does not use processState as the launch discriminator. UIKit can
// disconnect/recreate a scene while Amazon's process survives, so scene continuity is the
// authoritative distinction between an ordinary warm resume and a real scene presentation.

static UIImage *ADSplashImage7191(void) {
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        image=[UIImage imageWithContentsOfFile:@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png"];
    });
    return image;
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
        unsigned myGen = ++gCoverGen;

        gPresentAt = CFAbsoluteTimeGetCurrent();

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHardCap * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            @try { if (gCoverOverlay && myGen == gCoverGen){ UIView *x = gCoverOverlay; gCoverOverlay = nil;
                       SBSceneView *h=gCoverHost; gCoverHost=nil; if(h)objc_setAssociatedObject(h,kCoveredKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                       [x removeFromSuperview]; } }
            @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

static void ADDismissCover(void) {
    @try {
        if (!gCoverOverlay) return;
        UIView *ov = gCoverOverlay; gCoverOverlay = nil;
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

        // v7.306: scene continuity is the correct warm/cold discriminator. iOS can keep
        // Amazon's process alive while disconnecting and later recreating its UIScene. The
        // old processState-only test called that case "warm" and skipped our cover, exposing
        // Amazon's stock white scene-rebuild/loading screen.
        //
        // First attachment of this SBSceneView = real scene presentation/reconstruction ->
        // use the exact v7.301 Amazon launch cover. Reattachment of the same scene = ordinary
        // warm resume -> return directly to the existing app UI with no launch replay.
        BOOL seen = (objc_getAssociatedObject(self, kSceneSeenKey7306) != nil);
        if (seen) return;
        objc_setAssociatedObject(self, kSceneSeenKey7306, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        BOOL already = (objc_getAssociatedObject(self, kCoveredKey) != nil);
        if (already) return;
        objc_setAssociatedObject(self, kCoveredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADAttachCoverToScene(self);
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
                if (!gCoverOverlay) return;
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
    @autoreleasepool {
        @try { %init; }
        @catch (__unused NSException *e) {}
    }
}
