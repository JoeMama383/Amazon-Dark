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
#import <sys/types.h>

static NSString * const kAMZ      = @"com.amazon.Amazon";
static NSString * const kDefaults = @"com.colindavidr.amazondark";
static const NSTimeInterval kCoverHold    = 8.5;  // LAST RESORT. The app guarantees a
                                                  // signal by t=7.5s, so this must sit above
                                                  // that or the timer pre-empts the signal -
                                                  // which is exactly what 3.0s was doing.
static const NSTimeInterval kCoverFade    = 0.55; // lift animation
static const NSTimeInterval kReadySettle   = 0.40; // v7.116: keep the cover fully opaque for
                                                  // a short post-ready settle window. If the
                                                  // ready event arrives early, the existing
                                                  // 1.40 s minimum absorbs this completely.
static const NSTimeInterval kCoverHardCap = 10.0; // absolute max on screen

@interface SBSceneView : UIView
@end

static double gPresentAt;

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

static void ADDismissCover(void);
static UIView *gCoverOverlay;
static unsigned gCoverGen;

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

        UIImage *splash = nil;
        for (NSString *cp in @[@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png",
                               @"/Library/Application Support/AmazonDark/splash-logo.png"]) {
            splash = [UIImage imageWithContentsOfFile:cp];
            if (splash) break;
        }
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
        // Re-check at the moment of attach: the switch can be turned off while
        // SpringBoard is already running, and nothing should be covered then.
        if (!ADSBEnabled()) { ADSBLog(@"COVER skipped (disabled)"); return; }
        [host addSubview:ov];
        gCoverOverlay = ov;
        unsigned myGen = ++gCoverGen;

        gPresentAt = CFAbsoluteTimeGetCurrent();
        ADSBLog([NSString stringWithFormat:@"COVER overlay in scene (%@ logo=%d)",
                 NSStringFromClass([host class]), splash ? 1 : 0]);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHold * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            // Log WHICH path lifted the cover. Previously a timer dismissal and a
            // signal dismissal were indistinguishable except by the absence of the
            // "COVER ready" line, which is a terrible thing to have to infer.
            if (myGen == gCoverGen){
                ADSBLog([NSString stringWithFormat:
                         @"COVER hold-timer fired at %.2fs (no ready signal arrived)",
                         CFAbsoluteTimeGetCurrent() - gPresentAt]);
                ADDismissCover();   // never dismiss a newer cover
            }
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHardCap * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            @try { if (gCoverOverlay && myGen == gCoverGen){ UIView *x = gCoverOverlay; gCoverOverlay = nil;
                       [x removeFromSuperview]; ADSBLog(@"COVER overlay hardcap (no signal)"); } }
            @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

static void ADDismissCover(void) {
    @try {
        if (!gCoverOverlay) return;
        UIView *ov = gCoverOverlay; gCoverOverlay = nil;
        [UIView animateWithDuration:kCoverFade animations:^{ ov.alpha = 0.0; }
                         completion:^(BOOL f){ @try { [ov removeFromSuperview]; }
                                               @catch (__unused NSException *e) {} }];
        ADSBLog(@"COVER overlay dismissed (signal)");
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

        // Cover disabled: it was overlaying SpringBoard's icon-zoom launch
        // animation. The launch screen is darkened at its source instead.
        // Resume: Amazon's own view is already drawn behind this scene, so the
        // overlay would be replaying a launch that is not happening.
        int ts = -1;
        BOOL alive = ADAmazonProcessAlive(&ts);
        // One cover per launch. If the process-alive lookup fails we must not
        // fall through and cover a running app -- that is the state where no
        // ready signal can arrive, so the cover would simply sit there.
        // Per-scene, not per-clock: a fresh scene always gets its cover, while a
        // scene that already had one never gets a second.
        static const void *kCoveredKey = &kCoveredKey;
        BOOL already = (objc_getAssociatedObject(self, kCoveredKey) != nil);
        ADSBLog([NSString stringWithFormat:@"scene attach alive=%d taskState=%d already=%d",
                 alive ? 1 : 0, ts, already ? 1 : 0]);
        if (alive || already) return;
        objc_setAssociatedObject(self, kCoveredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // Parented to the scene view: SpringBoard's zoom animates it.
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
                ADSBLog([NSString stringWithFormat:@"COVER ready (shown %.2fs, minRemain %.2fs, settle %.2fs, wait %.2fs)",
                         shown, minimumRemaining, kReadySettle, wait]);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ ADDismissCover(); });
            } @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
    @autoreleasepool {
        @try { %init; ADSBLog(@"AmazonDarkSB ctor"); }
        @catch (__unused NSException *e) {}
    }
}
