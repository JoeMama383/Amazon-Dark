// AmazonDarkSB.xm
// SpringBoard-side dark cover for the Amazon Shopping launch screen.
//
// Injected ONLY into com.apple.springboard (AmazonDarkSB.plist). Amazon's white
// LaunchScreen is drawn by the render server before Amazon's process is alive,
// so it can't be themed from inside Amazon. Here we float a dark view in the
// stable containing SpringBoard window and lift it after Amazon reports ready.
//
// Why stable window coordinates and not a subview of the scene: an opaque view placed
// INSIDE SBSceneView makes FrontBoard treat Amazon's scene as fully occluded, so
// it suspends rendering and the app never draws (permanent black). The containing
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
    // FrontBoard has used more than one scene identity path across supported iOS
    // versions. Resolve after willMoveToWindow:%orig, when those handles exist.
    for(NSString *kp in @[@"sceneHandle.application.bundleIdentifier",
                           @"sceneHandle.sceneIdentity.bundleIdentifier",
                           @"application.bundleIdentifier",
                           @"sceneHandle.sceneIdentity.bundleIdentifierOverride",
                           @"_sceneHandle.application.bundleIdentifier"]){
        @try {
            id val=[v valueForKeyPath:kp];
            if([val isKindOfClass:[NSString class]]&&[(NSString *)val length])return val;
        } @catch (__unused NSException *e) {}
    }
    return nil;
}

static void ADDismissCover(void);
static UIView *gCoverOverlay;
static SBSceneView *gCoveredScene;
static const void *kCoveredKey = &kCoveredKey;
static const void *kSceneReadyKey7303 = &kSceneReadyKey7303;
static unsigned gCoverGen;

static void ADCancelCoverForScene(SBSceneView *scene) {
    @try {
        if(!scene||gCoveredScene!=scene)return;
        UIView *ov=gCoverOverlay; gCoverOverlay=nil; gCoveredScene=nil; ++gCoverGen;
        objc_setAssociatedObject(scene,kCoveredKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [ov removeFromSuperview];
    } @catch (__unused NSException *e) {}
}

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

// First-frame surface in the stable containing SpringBoard window. Unlike an
// opaque child of SBSceneView, this does not cause FrontBoard to regard Amazon's
// scene as occluded, so Amazon keeps rendering under the cover until ready.
static void ADAttachCoverToStableHost(UIView *host,SBSceneView *scene) {
    @try {
        if (!host||!scene) return;
        if (gCoverOverlay && gCoverOverlay.superview == host) return;
        if(gCoverOverlay){[gCoverOverlay removeFromSuperview];gCoverOverlay=nil;}
        UIColor *dk = [UIColor colorWithRed:0.094 green:0.102 blue:0.106 alpha:1.0];
        CGRect coverFrame=host.bounds;
        if(coverFrame.size.width<100.0||coverFrame.size.height<200.0)coverFrame=UIScreen.mainScreen.bounds;
        UIView *ov = [[UIView alloc] initWithFrame:coverFrame];
        ov.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        ov.backgroundColor = dk;
        ov.userInteractionEnabled = NO;

        UIImage *splash = ADSplashImage7191();
        if (splash) {
            UIImageView *logo = [[UIImageView alloc] initWithImage:splash];
            logo.contentMode = UIViewContentModeScaleAspectFit;
            CGFloat lw = MAX(ov.bounds.size.width, 200.0) * 0.62;
            CGFloat lh = lw * (splash.size.height / MAX(splash.size.width, 1.0));
            logo.bounds=CGRectMake(0.0,0.0,lw,lh);
            logo.center=CGPointMake(CGRectGetMidX(ov.bounds),CGRectGetMidY(ov.bounds));
            logo.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|
                                  UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
            [ov addSubview:logo];
        }
        [host addSubview:ov];
        [host bringSubviewToFront:ov];
        gCoverOverlay = ov;
        gCoveredScene = scene;
        unsigned myGen = ++gCoverGen;

        gPresentAt = CFAbsoluteTimeGetCurrent();

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHardCap * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            @try { if (gCoverOverlay && myGen == gCoverGen){ UIView *x = gCoverOverlay; gCoverOverlay = nil;
                       // The hard cap is a safety release, not proof that Amazon reached
                       // a dark stable frame. Leave ready unset so a later presentation of
                       // this scene is covered again until the real app-side signal arrives.
                       SBSceneView *s=gCoveredScene; gCoveredScene=nil; if(s)objc_setAssociatedObject(s,kCoveredKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                       [x removeFromSuperview]; } }
            @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

static void ADDismissCover(void) {
    @try {
        if (!gCoverOverlay) return;
        UIView *ov = gCoverOverlay; gCoverOverlay = nil;
        SBSceneView *s=gCoveredScene; gCoveredScene=nil; if(s){objc_setAssociatedObject(s,kCoveredKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);objc_setAssociatedObject(s,kSceneReadyKey7303,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
        [UIView animateWithDuration:kCoverFade animations:^{ ov.alpha = 0.0; }
                         completion:^(BOOL f){ @try { [ov removeFromSuperview]; }
                                               @catch (__unused NSException *e) {} }];
    } @catch (__unused NSException *e) {}
}

%hook SBSceneView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    // %orig populates FrontBoard's scene handle, but this entire call still
    // completes before the next Core Animation commit. Attach to newWindow—not
    // SBSceneView—so the first exposed Amazon frame is guaranteed dark while its
    // renderer continues working underneath.
    %orig(newWindow);
    @try {
        if(!newWindow){ADCancelCoverForScene(self);return;}
        if(!ADSBEnabled())return;
        if(![ADSceneBundleId(self) isEqualToString:kAMZ])return;
        BOOL already=objc_getAssociatedObject(self,kCoveredKey)!=nil;
        BOOL ready=objc_getAssociatedObject(self,kSceneReadyKey7303)!=nil;
        if(already){
            // Scene/window migrations must not strand the full-screen cover in an
            // obsolete SpringBoard host.
            if(gCoveredScene==self&&gCoverOverlay.superview!=newWindow)
                ADAttachCoverToStableHost(newWindow,self);
            return;
        }
        if(ready&&ADAmazonProcessAlive())return;
        objc_setAssociatedObject(self,kCoveredKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADAttachCoverToStableHost(newWindow,self);
    } @catch (__unused NSException *e) {}
}
- (void)didMoveToWindow {
    %orig;
    @try {
        if (!self.window) return;

        NSString *bid = ADSceneBundleId(self);
        if (![bid isEqualToString:kAMZ]) return;

        // Fallback for an iOS variant whose identity became available only here.
        // A scene already proven ready may resume normally; a new scene is covered
        // even if Amazon's newly spawned process already reports running.
        BOOL already = (objc_getAssociatedObject(self, kCoveredKey) != nil);
        if(already){
            // FrontBoard may perform one final sibling reorder between willMove and
            // didMove. Reassert the stable cover before that transaction commits.
            if(gCoveredScene==self&&gCoverOverlay.superview)
                [gCoverOverlay.superview bringSubviewToFront:gCoverOverlay];
            return;
        }
        BOOL ready=objc_getAssociatedObject(self,kSceneReadyKey7303)!=nil;
        if(ready&&ADAmazonProcessAlive())return;
        objc_setAssociatedObject(self, kCoveredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADAttachCoverToStableHost(self.window,self);
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
