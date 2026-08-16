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
#import <dlfcn.h>
#import <limits.h>
#import <string.h>
#import <stdint.h>
#import <math.h>
#import <sys/types.h>

static NSString * const kAMZ      = @"com.amazon.Amazon";
static NSString * const kDefaults = @"com.colindavidr.amazondark";
static const NSTimeInterval kCoverHold    = 8.5;  // LAST RESORT. The app guarantees a
                                                  // signal by t=7.5s, so this must sit above
                                                  // that or the timer pre-empts the signal -
                                                  // which is exactly what 3.0s was doing.
static const NSTimeInterval kCoverFade    = 0.55; // smooth final handoff into live Amazon
static const NSTimeInterval kCoverHardCap = 10.0; // absolute max on screen
static const NSTimeInterval kReCoverGap   = 8.0;  // legacy custom-window path only
static const NSTimeInterval kWarmMin647    = 0.20; // minimum warm-mask dwell before fade
static const NSTimeInterval kWarmFallback647 = 0.75; // warm resume fallback if app signal races/misses

@interface SBSceneView : UIView
@end

@interface UIImage (AD)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bid format:(int)fmt scale:(CGFloat)scale;
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bid format:(int)fmt;
@end

static UIWindow *gCoverWin;
static double gPresentAt;
static NSTimeInterval gLastPresent;
static UIView *gStableCover647;
static BOOL gWarmCover647;
static NSTimeInterval gLastWarmPresent647;

static void ADSBLog(NSString *msg) {
    @try {
        static NSFileHandle *fh; static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSString *p = @"/var/mobile/AmazonDarkSB.log";
            [[NSFileManager defaultManager] createFileAtPath:p contents:nil attributes:nil];
            fh = [NSFileHandle fileHandleForWritingAtPath:p];
        });
        NSString *line = [NSString stringWithFormat:@"%f %@\n", CFAbsoluteTimeGetCurrent(), msg];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    } @catch (__unused NSException *e) {}
}

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

static NSString *ADSceneBundleId(UIView *v, NSString **hitPathOut) {
    NSArray *paths = @[ @"sceneHandle.application.bundleIdentifier",
                        @"sceneHandle.sceneIdentity.bundleIdentifier",
                        @"application.bundleIdentifier",
                        @"sceneHandle.sceneIdentity.bundleIdentifierOverride",
                        @"_sceneHandle.application.bundleIdentifier" ];
    for (NSString *kp in paths) {
        @try {
            id val = [v valueForKeyPath:kp];
            if ([val isKindOfClass:[NSString class]] && [(NSString *)val length]) {
                if (hitPathOut) *hitPathOut = kp;
                return (NSString *)val;
            }
        } @catch (__unused NSException *e) {}
    }
    return nil;
}

static UIWindowScene *ADForegroundWindowScene(void) {
    @try {
        NSArray *scenes = [[UIApplication sharedApplication].connectedScenes allObjects];
        for (UIScene *s in scenes)
            if ([s isKindOfClass:[UIWindowScene class]] &&
                s.activationState == UISceneActivationStateForegroundActive)
                return (UIWindowScene *)s;
        for (UIScene *s in scenes)
            if ([s isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)s;
    } @catch (__unused NSException *e) {}
    return nil;
}

static void ADDismissCover(void);
static UIView *gCoverOverlay;
static unsigned gCoverGen;

// v6.0.47: keep the proven centered result without withholding artwork.
// The dark cold-launch surface still lives inside SBSceneView so Apple's native
// scene transform remains untouched.  The Amazon wordmark itself is placed in
// SpringBoard window coordinates with an explicit frame (no Auto Layout), so it
// is centered and visible on the first frame without inheriting the scene transform.
static UIImage *ADSplashImage647(void){
    @try {
        for (NSString *cp in @[@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png",
                               @"/Library/Application Support/AmazonDark/splash-logo.png"]) {
            UIImage *im=[UIImage imageWithContentsOfFile:cp];
            if(im) return im;
        }
    } @catch (__unused NSException *e) {}
    return nil;
}

static void ADRemoveStableCover647(void){
    @try {
        if(gStableCover647){ UIView *v=gStableCover647; gStableCover647=nil; [v removeFromSuperview]; }
        gWarmCover647=NO;
    } @catch (__unused NSException *e) {}
}

static void ADShowStableCover647(UIView *sceneHost, UIView *forcedStableHost, BOOL opaque){
    @try {
        UIView *stableHost=forcedStableHost ?: sceneHost.window ?: sceneHost;
        if(!stableHost) return;
        ADRemoveStableCover647();

        CGRect stableBounds=stableHost.bounds;
        if(CGRectGetWidth(stableBounds)<100.0 || CGRectGetHeight(stableBounds)<100.0)
            stableBounds=[UIScreen mainScreen].bounds;
        UIView *cover=[[UIView alloc] initWithFrame:stableBounds];
        cover.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        cover.backgroundColor=opaque ? [UIColor colorWithRed:0.094 green:0.102 blue:0.106 alpha:1.0] : [UIColor clearColor];
        cover.userInteractionEnabled=NO;

        UIImage *splash=ADSplashImage647();
        if(splash){
            CGFloat sw=MAX(CGRectGetWidth(cover.bounds),200.0);
            CGFloat lw=sw*0.62;
            CGFloat lh=lw*(splash.size.height/MAX(splash.size.width,1.0));
            UIImageView *logo=[[UIImageView alloc] initWithImage:splash];
            logo.contentMode=UIViewContentModeScaleAspectFit;
            logo.bounds=CGRectMake(0,0,lw,lh);
            logo.center=CGPointMake(CGRectGetMidX(cover.bounds),CGRectGetMidY(cover.bounds));
            logo.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|
                                  UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
            [cover addSubview:logo];
        }
        [stableHost addSubview:cover];
        gStableCover647=cover;
        gWarmCover647=opaque;
        ADSBLog([NSString stringWithFormat:@"COVER stable first-frame logo=%d opaque=%d", splash?1:0, opaque?1:0]);
    } @catch (__unused NSException *e) {}
}

// YES when Amazon already has a running process -- i.e. this is a resume, not a
// cold launch. Nothing here is required to exist; unknown means "cover it".
static BOOL ADAmazonProcessAlive(int *taskStateOut) {
    if (taskStateOut) *taskStateOut = -1;
    @try {
        Class ctl = objc_getClass("SBApplicationController");
        if (!ctl || ![ctl respondsToSelector:@selector(sharedInstance)]) return NO;
        id shared = [ctl performSelector:@selector(sharedInstance)];
        if (!shared || ![shared respondsToSelector:@selector(applicationWithBundleIdentifier:)]) return NO;
        id app = [shared performSelector:@selector(applicationWithBundleIdentifier:) withObject:kAMZ];
        if (!app || ![app respondsToSelector:@selector(processState)]) return NO;
        id ps = [app performSelector:@selector(processState)];
        if (!ps) return NO;
        if (taskStateOut && [ps respondsToSelector:@selector(taskState)]) {
            NSNumber *ts = [ps valueForKey:@"taskState"];
            if (ts) *taskStateOut = ts.intValue;
        }
        if ([ps respondsToSelector:@selector(isRunning)]) {
            NSNumber *r = [ps valueForKey:@"isRunning"];
            if (r) return r.boolValue;
        }
    } @catch (__unused NSException *e) {}
    return NO;
}

// Cold launch: keep only the dark surface inside the zooming scene.  The
// wordmark is a separate stable-window-coordinate overlay, so it is visible
// immediately and always originates at true screen center.
static void ADAttachCoverToScene(UIView *host) {
    @try {
        if (!host) return;
        if (gCoverOverlay && gCoverOverlay.superview == host) return;
        UIColor *dk = [UIColor colorWithRed:0.094 green:0.102 blue:0.106 alpha:1.0];
        UIView *ov = [[UIView alloc] initWithFrame:host.bounds];
        ov.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        ov.backgroundColor = dk;
        ov.userInteractionEnabled = NO;

        if (!ADSBEnabled()) { ADSBLog(@"COVER skipped (disabled)"); return; }
        [host addSubview:ov];
        gCoverOverlay = ov;
        unsigned myGen = ++gCoverGen;
        if(!gStableCover647) ADShowStableCover647(host, nil, NO);
        else { gStableCover647.backgroundColor=[UIColor clearColor]; gWarmCover647=NO; }

        gPresentAt = CFAbsoluteTimeGetCurrent();
        ADSBLog([NSString stringWithFormat:@"COVER cold scene+stable artwork (%@)", NSStringFromClass([host class])]);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHold * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (myGen == gCoverGen){
                ADSBLog([NSString stringWithFormat:@"COVER hold-timer fired at %.2fs (no ready signal arrived)",
                         CFAbsoluteTimeGetCurrent() - gPresentAt]);
                ADDismissCover();
            }
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHardCap * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            @try {
                if (myGen == gCoverGen){
                    if(gCoverOverlay){ UIView *x=gCoverOverlay; gCoverOverlay=nil; [x removeFromSuperview]; }
                    ADRemoveStableCover647();
                    ADSBLog(@"COVER cold hardcap (no signal)");
                }
            } @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

// Warm/resume launch: mask the app/snapshot from SpringBoard space rather than
// relying on Amazon's process to erase a cached white frame before iOS displays it.
// This cover is outside SBSceneView, so Amazon continues rendering underneath it.
static void ADPresentWarmCover647(UIView *host){
    @try {
        NSTimeInterval now=CFAbsoluteTimeGetCurrent();
        if(now-gLastWarmPresent647<0.35) return;
        gLastWarmPresent647=now;
        unsigned myGen=++gCoverGen;
        gPresentAt=now;
        if(!gStableCover647) ADShowStableCover647(host, nil, YES);
        else gStableCover647.backgroundColor=[UIColor colorWithRed:0.094 green:0.102 blue:0.106 alpha:1.0];
        gWarmCover647=YES;
        ADSBLog(@"COVER warm mask presented");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(kWarmFallback647*NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            @try { if(myGen==gCoverGen && gWarmCover647){ ADSBLog(@"COVER warm fallback"); ADDismissCover(); } }
            @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

static void ADDismissCover(void) {
    @try {
        ++gCoverGen;
        if (gCoverOverlay) {
            UIView *ov = gCoverOverlay; gCoverOverlay = nil;
            [UIView animateWithDuration:kCoverFade delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                             animations:^{ ov.alpha=0.0; }
                             completion:^(BOOL f){ @try { [ov removeFromSuperview]; } @catch (__unused NSException *e) {} }];
        }
        if(gStableCover647){
            UIView *v=gStableCover647; gStableCover647=nil; gWarmCover647=NO;
            [UIView animateWithDuration:kCoverFade delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                             animations:^{ v.alpha=0.0; }
                             completion:^(BOOL f){ @try { [v removeFromSuperview]; } @catch (__unused NSException *e) {} }];
        }
        if (gCoverWin) {
            UIWindow *w = gCoverWin; gCoverWin = nil;
            [UIView animateWithDuration:kCoverFade delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                             animations:^{ w.alpha=0.0; }
                             completion:^(BOOL f){ @try { w.hidden=YES; } @catch (__unused NSException *e) {} }];
        }
        ADSBLog(@"COVER fading 0.55s");
    } @catch (__unused NSException *e) {}
}

static void ADPresentCover(void) {
    @try {
        NSTimeInterval now = CFAbsoluteTimeGetCurrent();
        if (gCoverWin) return;
        if (now - gLastPresent < kReCoverGap) return;
        gLastPresent = now;

        UIWindow *w = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        UIWindowScene *sc = ADForegroundWindowScene();
        if (sc) w.windowScene = sc;
        UIColor *dark = [UIColor colorWithRed:0x18/255.0 green:0x1a/255.0 blue:0x1b/255.0 alpha:1.0];
        UIViewController *vc = [UIViewController new];
        vc.view.backgroundColor = dark;
        w.rootViewController = vc;
        w.backgroundColor = dark;

        // The zooming surface. Slightly lifted from the base so the growth is
        // legible as a surface opening rather than a logo drifting in place.
        UIView *adCard = [[UIView alloc] initWithFrame:vc.view.bounds];
        adCard.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        adCard.backgroundColor = [UIColor colorWithRed:0.118 green:0.126 blue:0.130 alpha:1.0];
        adCard.layer.masksToBounds = YES;
        [vc.view addSubview:adCard];

        // Inverted splash logo, generated from the app's own launch screen: dark
        // ground, light wordmark, the orange smile kept orange. Falls back to the
        // rounded app icon only if the packaged asset is missing.
        BOOL usedSplash = NO;
        @try {
            UIImage *splash = nil;
            NSArray *cand = @[@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png",
                              @"/Library/Application Support/AmazonDark/splash-logo.png"];
            for (NSString *cp in cand) {
                splash = [UIImage imageWithContentsOfFile:cp];
                if (splash) break;
            }
            if (splash) {
                UIImageView *logo = [[UIImageView alloc] initWithImage:splash];
                logo.contentMode = UIViewContentModeScaleAspectFit;   // wordmark: no
                logo.translatesAutoresizingMaskIntoConstraints = NO;  // corner mask
                logo.tag = 7741;
                [adCard addSubview:logo];
                CGFloat lw = [UIScreen mainScreen].bounds.size.width * 0.62;
                CGFloat lh = lw * (splash.size.height / MAX(splash.size.width, 1.0));
                [NSLayoutConstraint activateConstraints:@[
                    [logo.centerXAnchor constraintEqualToAnchor:adCard.centerXAnchor],
                    [logo.centerYAnchor constraintEqualToAnchor:adCard.centerYAnchor],
                    [logo.widthAnchor constraintEqualToConstant:lw],
                    [logo.heightAnchor constraintEqualToConstant:lh],
                ]];
                usedSplash = YES;
                ADSBLog([NSString stringWithFormat:@"COVER splash logo (%.0fx%.0f)", splash.size.width, splash.size.height]);
            }
        } @catch (__unused NSException *e) {}
        @try {
            if (usedSplash) goto coverAssembled;
            UIImage *icon = nil;
            if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)])
                icon = [UIImage _applicationIconImageForBundleIdentifier:kAMZ format:2 scale:[UIScreen mainScreen].scale];
            if (!icon && [UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:)])
                icon = [UIImage _applicationIconImageForBundleIdentifier:kAMZ format:2];
            if (icon) {
                UIImageView *logo = [[UIImageView alloc] initWithImage:icon];
                logo.contentMode = UIViewContentModeScaleAspectFit;
                logo.translatesAutoresizingMaskIntoConstraints = NO;
                logo.tag = 7741;
                logo.layer.cornerRadius = 22.0;
                logo.layer.masksToBounds = YES;
                [adCard addSubview:logo];
                [NSLayoutConstraint activateConstraints:@[
                    [logo.centerXAnchor constraintEqualToAnchor:adCard.centerXAnchor],
                    [logo.centerYAnchor constraintEqualToAnchor:adCard.centerYAnchor],
                    [logo.widthAnchor constraintEqualToConstant:132.0],
                    [logo.heightAnchor constraintEqualToConstant:132.0],
                ]];
                ADSBLog(@"COVER logo added");
            } else { ADSBLog(@"COVER logo unavailable"); }
        } @catch (__unused NSException *e) {}
        coverAssembled:;
        w.windowLevel = UIWindowLevelAlert + 1.0;
        w.userInteractionEnabled = NO;

        // OPAQUE BASE, ZOOMING CARD. The base is dark and full-screen on frame
        // one, so the white launch frame is never visible for even one frame --
        // that was the flaw in the earlier zoom attempt. The card then grows from
        // icon-sized to full-screen with its corner radius relaxing, which is the
        // stock "app opens" motion, at a stock-like pace.
        UIView *cv = w.rootViewController.view;
        BOOL adReduce = UIAccessibilityIsReduceMotionEnabled();
        cv.alpha = 1.0;                       // base opaque immediately: no white
        UIView *card = nil;
        for (UIView *sv in cv.subviews) { card = sv; break; }
        if (card && !adReduce){
            card.layer.cornerRadius = 46.0;
            card.transform = CGAffineTransformMakeScale(0.26, 0.26);
            card.alpha = 0.55;
        }
        w.hidden = NO;   // show without becoming key (don't steal input focus)
        if (card && !adReduce){
            [UIView animateWithDuration:0.62 delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 card.transform = CGAffineTransformIdentity;
                                 card.alpha = 1.0;
                             } completion:nil];
            CABasicAnimation *cr = [CABasicAnimation animationWithKeyPath:@"cornerRadius"];
            cr.fromValue = @46.0; cr.toValue = @0.0; cr.duration = 0.62;
            cr.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            [card.layer addAnimation:cr forKey:@"adcr"];
            card.layer.cornerRadius = 0.0;
        }
        gCoverWin = w;
        gPresentAt = CFAbsoluteTimeGetCurrent();
        ADSBLog(@"COVER presented (zoom)");

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHold * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ ADDismissCover(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHardCap * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            @try { if (gCoverWin) { UIWindow *x = gCoverWin; gCoverWin = nil; x.hidden = YES; ADSBLog(@"COVER hardcap"); } }
            @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}


// ── v6.0.22 Dopamine JIT broker ─────────────────────────────────────────────
// SpringBoard is the platform-authorized caller Dopamine requires. This broker
// accepts only Amazon's PID and only enables the debug/JIT state; disabling is
// handled by the normal respring + clean Amazon launch path.
#define AD_JIT_REQ_NOTIFY_622 "com.colindavidr.amazondark/jit-request-622"
#define AD_JIT_RES_NOTIFY_622 "com.colindavidr.amazondark/jit-result-622"
#define AD_JIT_RC_NO_BACKEND_622 (-1001)
#define AD_JIT_RC_EXCEPTION_622  (-1002)
#define AD_JIT_RC_BAD_PID_622    (-1003)

static uint64_t ADSBJITWireState622(pid_t pid, uint16_t nonce, int rc){
    return (((uint64_t)(uint32_t)pid) << 32) |
           (((uint64_t)nonce) << 16) |
           ((uint16_t)(int16_t)rc);
}
static pid_t ADSBJITWirePID622(uint64_t state){ return (pid_t)(uint32_t)(state >> 32); }
static uint16_t ADSBJITWireNonce622(uint64_t state){ return (uint16_t)((state >> 16) & 0xffffU); }

static BOOL ADSBIsAmazonPID622(pid_t pid){
    if (pid <= 1) return NO;
    typedef int (*ADProcPidPathFn622)(int, void *, uint32_t);
    static ADProcPidPathFn622 procPidPath = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        procPidPath = (ADProcPidPathFn622)dlsym(RTLD_DEFAULT, "proc_pidpath");
        if (!procPidPath){
            void *h = dlopen("/usr/lib/libproc.dylib", RTLD_LAZY | RTLD_LOCAL);
            if (h) procPidPath = (ADProcPidPathFn622)dlsym(h, "proc_pidpath");
        }
    });
    if (!procPidPath) return NO;

    char path[PATH_MAX] = {0};
    int n = procPidPath((int)pid, path, (uint32_t)sizeof(path));
    if (n <= 0 || !path[0]) return NO;
    size_t len = strlen(path);
    const char *suffix = "/Amazon.app/Amazon";
    size_t slen = strlen(suffix);
    return len >= slen && strcmp(path + len - slen, suffix) == 0;
}

static void ADSBHandleJITRequest622(int token){
    @autoreleasepool {
        @try {
            uint64_t req = 0;
            if (notify_get_state(token, &req) != NOTIFY_STATUS_OK) return;
            pid_t pid = ADSBJITWirePID622(req);
            uint16_t nonce = ADSBJITWireNonce622(req);
            int rc = AD_JIT_RC_EXCEPTION_622;

            if (!ADSBIsAmazonPID622(pid)){
                rc = AD_JIT_RC_BAD_PID_622;
            } else {
                typedef int (*ADSetProcessDebuggedFn622)(uint64_t, bool);
                ADSetProcessDebuggedFn622 fn =
                    (ADSetProcessDebuggedFn622)dlsym(RTLD_DEFAULT, "jbclient_platform_set_process_debugged");
                if (!fn) rc = AD_JIT_RC_NO_BACKEND_622;
                else {
                    @try { rc = fn((uint64_t)pid, true); }
                    @catch (__unused NSException *e) { rc = AD_JIT_RC_EXCEPTION_622; }
                }
            }

            int resToken = 0;
            if (notify_register_check(AD_JIT_RES_NOTIFY_622, &resToken) == NOTIFY_STATUS_OK){
                notify_set_state(resToken, ADSBJITWireState622(pid, nonce, rc));
                notify_post(AD_JIT_RES_NOTIFY_622);
                notify_cancel(resToken);
            }
            ADSBLog([NSString stringWithFormat:@"JIT broker pid=%d rc=%d", pid, rc]);
        } @catch (__unused NSException *e) {
            ADSBLog(@"JIT broker exception");
        }
    }
}

%hook SBSceneView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;
    @try {
        if(!newWindow || !ADSBEnabled()) return;
        NSString *hitPath=nil;
        NSString *bid=ADSceneBundleId(self,&hitPath);
        if(![bid isEqualToString:kAMZ]) return;

        // First-frame anti-flash cover. This is installed in the stable SpringBoard
        // window coordinate space BEFORE the Amazon scene is exposed. Explicit frame
        // geometry means the wordmark is centered immediately and never rides the
        // icon-origin scene transform. didMoveToWindow decides cold vs warm lifecycle.
        ++gCoverGen; // invalidate any stale timer/fade from a prior transition
        ADShowStableCover647(self,newWindow,YES);
        ADSBLog(@"COVER prewindow first-frame installed");
    } @catch (__unused NSException *e) {}
}
- (void)didMoveToWindow {
    %orig;
    @try {
        if (!self.window) return;

        static NSMutableSet *seen; static dispatch_once_t once;
        dispatch_once(&once, ^{ seen = [NSMutableSet set]; });
        NSString *cls = NSStringFromClass([self class]);

        if (!ADSBEnabled()) return;
        NSString *hitPath = nil;
        NSString *bid = ADSceneBundleId(self, &hitPath);
        if (![seen containsObject:cls]) {
            [seen addObject:cls];
            ADSBLog([NSString stringWithFormat:@"SCENE class=%@ bid=%@ via=%@", cls, bid ?: @"-", hitPath ?: @"-"]);
        }
        if (![bid isEqualToString:kAMZ]) return;

        int ts = -1;
        BOOL alive = ADAmazonProcessAlive(&ts);
        static const void *kCoveredKey = &kCoveredKey;
        BOOL already = (objc_getAssociatedObject(self, kCoveredKey) != nil);
        ADSBLog([NSString stringWithFormat:@"scene attach alive=%d taskState=%d already=%d",
                 alive ? 1 : 0, ts, already ? 1 : 0]);

        // A running Amazon process is a warm/resume path.  The old code skipped
        // coverage here, which allowed iOS to expose a stale/native white splash
        // before Amazon had a chance to repaint it.  Mask that transition from
        // stable SpringBoard coordinates and let Amazon render underneath.
        if(alive){ ADPresentWarmCover647(self); return; }

        // Cold launch: one scene-attached dark surface per scene, plus the stable
        // centered artwork overlay created by ADAttachCoverToScene().
        if(already) return;
        objc_setAssociatedObject(self, kCoveredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADAttachCoverToScene(self);
    } @catch (__unused NSException *e) {}
}
%end

%ctor {
    // Dopamine JIT broker: one event-driven enable request channel. SpringBoard is
    // the platform-authorized caller; the handler itself validates Amazon's PID.
    @try {
        static int adJITToken622 = 0;
        notify_register_dispatch(AD_JIT_REQ_NOTIFY_622, &adJITToken622,
                                 dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(int t){
            ADSBHandleJITRequest622(t);
        });
    } @catch (__unused NSException *e) {}

    // Event-driven dismissal, matching the system: the launch screen leaves at
    // the app's first frame, not on a timer. The app posts this once its UI is
    // up; the kCoverHold timer stays only as a fallback for a launch where the
    // signal never arrives.
    @try {
        static int adReadyToken = 0;
        notify_register_dispatch("com.colindavidr.amazondark.ready", &adReadyToken,
                                 dispatch_get_main_queue(), ^(int t){
            @try {
                if (!gCoverWin && !gCoverOverlay) return;
                double shown = CFAbsoluteTimeGetCurrent() - gPresentAt;
                double wait = shown < 1.40 ? (1.40 - shown) : 0.0;
                ADSBLog([NSString stringWithFormat:@"COVER ready (shown %.2fs, wait %.2fs, fade %.2fs)", shown, wait, kCoverFade]);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(wait*NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ ADDismissCover(); });
            } @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}

    // Warm foreground handoff. Amazon posts this on each DidBecomeActive.  Only a
    // warm SpringBoard cover consumes it; cold launch continues to use the original
    // dark-screen readiness notification above.
    @try {
        static int adForegroundToken647 = 0;
        notify_register_dispatch("com.colindavidr.amazondark.foreground-ready-647", &adForegroundToken647,
                                 dispatch_get_main_queue(), ^(int t){
            @try {
                if(!gWarmCover647 || !gStableCover647) return;
                double shown=CFAbsoluteTimeGetCurrent()-gPresentAt;
                double wait=shown<kWarmMin647 ? (kWarmMin647-shown) : 0.0;
                unsigned gen=gCoverGen;
                ADSBLog([NSString stringWithFormat:@"COVER warm ready shown=%.2f wait=%.2f",shown,wait]);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(wait*NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ if(gWarmCover647 && gen==gCoverGen) ADDismissCover(); });
            } @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}

    @autoreleasepool {
        @try { %init; ADSBLog(@"AmazonDarkSB ctor"); }
        @catch (__unused NSException *e) {}
    }
}
