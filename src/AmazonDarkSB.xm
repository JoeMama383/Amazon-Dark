// AmazonDark SpringBoard companion
// Cold-launch dark scene cover + optional JIT broker; event-driven and guarded.

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
static const NSTimeInterval kCoverHold    = 8.5;

static const NSTimeInterval kCoverFade    = 0.55;
static const NSTimeInterval kCoverHardCap = 10.0;

@interface SBSceneView : UIView
@end

static double gPresentAt;

// Cached preference state
static BOOL gADSBEnabled = YES;
static void ADSBReloadEnabled(void) {
    @try {
        CFPreferencesAppSynchronize((__bridge CFStringRef)kDefaults);
        Boolean valid = NO;
        Boolean on = CFPreferencesGetAppBooleanValue(CFSTR("enabled"),
                        (__bridge CFStringRef)kDefaults, &valid);
        if (valid) { gADSBEnabled = on ? YES : NO; return; }
        for (NSString *base in @[@"/var/mobile/Library/Preferences/",
                                 @"/var/jb/var/mobile/Library/Preferences/"]) {
            NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:
                [base stringByAppendingFormat:@"%@.plist", kDefaults]];
            if (d && d[@"enabled"] != nil) { gADSBEnabled = [d[@"enabled"] boolValue]; return; }
        }
        gADSBEnabled = YES;
    } @catch (__unused NSException *e) { gADSBEnabled = YES; }
}
static BOOL ADSBEnabled(void) { return gADSBEnabled; }

static NSString *ADSceneBundleId(UIView *v) {
    NSArray *paths = @[ @"sceneHandle.application.bundleIdentifier",
                        @"sceneHandle.sceneIdentity.bundleIdentifier",
                        @"application.bundleIdentifier",
                        @"sceneHandle.sceneIdentity.bundleIdentifierOverride",
                        @"_sceneHandle.application.bundleIdentifier" ];
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
static unsigned gCoverGen;

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

// Scene-attached launch cover
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
        [host addSubview:ov];
        gCoverOverlay = ov;
        unsigned myGen = ++gCoverGen;

        gPresentAt = CFAbsoluteTimeGetCurrent();

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHold * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{

            if (myGen == gCoverGen){
                ADDismissCover();
            }
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHardCap * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            @try { if (gCoverOverlay && myGen == gCoverGen){ UIView *x = gCoverOverlay; gCoverOverlay = nil;
                       [x removeFromSuperview]; } }
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
    } @catch (__unused NSException *e) {}
}

// Optional Dopamine JIT broker
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
        } @catch (__unused NSException *e) {
        }
    }
}

// Amazon scene lifecycle
%hook SBSceneView
- (void)didMoveToWindow {
    %orig;
    @try {
        if (!self.window) return;

        if (!ADSBEnabled()) return;
        NSString *bid = ADSceneBundleId(self);
        if (![bid isEqualToString:kAMZ]) return;

        BOOL alive = ADAmazonProcessAlive();

        static const void *kCoveredKey = &kCoveredKey;
        BOOL already = (objc_getAssociatedObject(self, kCoveredKey) != nil);
        if (alive || already) return;
        objc_setAssociatedObject(self, kCoveredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        ADAttachCoverToScene(self);
    } @catch (__unused NSException *e) {}
}
%end

// Event registrations
%ctor {
    ADSBReloadEnabled();
    @try {
        static int adPrefsToken = 0;
        notify_register_dispatch("com.colindavidr.amazondark/prefs-changed", &adPrefsToken,
                                 dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(int t){
            ADSBReloadEnabled();
        });
    } @catch (__unused NSException *e) {}

    @try {
        static int adJITToken622 = 0;
        notify_register_dispatch(AD_JIT_REQ_NOTIFY_622, &adJITToken622,
                                 dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(int t){
            ADSBHandleJITRequest622(t);
        });
    } @catch (__unused NSException *e) {}

    @try {
        static int adReadyToken = 0;
        notify_register_dispatch("com.colindavidr.amazondark.ready", &adReadyToken,
                                 dispatch_get_main_queue(), ^(int t){
            @try {
                if (!gCoverOverlay) return;
                double shown = CFAbsoluteTimeGetCurrent() - gPresentAt;
                double wait  = shown < 1.40 ? (1.40 - shown) : 0.0;
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
