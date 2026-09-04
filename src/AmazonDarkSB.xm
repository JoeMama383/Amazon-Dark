// AmazonDarkSB.xm
// SpringBoard-side FIRST-FRAME shim for Amazon Shopping.
//
// Scope is intentionally tiny:
//   1. A genuine new Amazon process can expose the system-rendered stock LaunchScreen
//      before Amazon's own tweak code exists. SpringBoard masks only that interval.
//   2. As soon as Amazon's real splash controller is visibly presented with its floor
//      already owned dark, Amazon posts native-splash-ready and this shim is removed
//      immediately -- no Home/WebKit readiness gate, minimum hold, settle, or fade.
//   3. The same Amazon process is a warm resume and receives NO SpringBoard shim.
//
// v7.315 safety rule: SBSceneView lifecycle hooks NEVER inspect SpringBoard application
// state and NEVER mutate UIKit hierarchy synchronously. They only enqueue one main-queue
// continuation. All bundle/PID classification and any addSubview work occurs after UIKit
// has fully unwound the scene/window attachment transaction.
//
// A short absolute cap is failure safety only; it is not part of normal presentation.

#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/runtime.h>

static NSString * const kAMZ      = @"com.amazon.Amazon";
static NSString * const kDefaults = @"com.colindavidr.amazondark";
static const NSTimeInterval kShimHardCap7312 = 4.0;

@interface SBSceneView : UIView
@end

static UIView *gShim7312;
static SBSceneView *gShimHost7312;
static const void *kShimKey7312 = &kShimKey7312;
static unsigned gShimGen7312;
static NSInteger gAmazonProcessID7312;
static NSInteger gNativeSplashReadyPID7315;

static BOOL ADSBEnabled(void) {
    @try {
        NSString *path=[@"/var/jb/var/mobile/Library/Preferences" stringByAppendingPathComponent:
                        [kDefaults stringByAppendingPathExtension:@"plist"]];
        id value=[NSDictionary dictionaryWithContentsOfFile:path][@"enabled"];
        return value ? [value boolValue] : YES;
    } @catch (__unused NSException *e) { return YES; }
}

static NSString *ADSceneBundleId(UIView *v) {
    if(!v)return nil;
    NSArray *paths=@[@"sceneHandle.application.bundleIdentifier",
                     @"sceneHandle.sceneIdentity.bundleIdentifier",
                     @"application.bundleIdentifier",
                     @"sceneHandle.sceneIdentity.bundleIdentifierOverride",
                     @"_sceneHandle.application.bundleIdentifier"];
    for(NSString *path in paths){
        @try {
            id val=[v valueForKeyPath:path];
            if([val isKindOfClass:[NSString class]]&&[val length])return val;
        } @catch (__unused NSException *e) {}
    }
    return nil;
}

// Stable process identity across a normal warm resume. Unlike isRunning, this cannot
// flip from false to true midway through one cold launch and change classification.
static NSInteger ADAmazonProcessIdentifier7312(void) {
    @try {
        Class ctl=objc_getClass("SBApplicationController");
        if(!ctl||![ctl respondsToSelector:@selector(sharedInstance)])return 0;
        id shared=[ctl performSelector:@selector(sharedInstance)];
        if(!shared||![shared respondsToSelector:@selector(applicationWithBundleIdentifier:)])return 0;
        id app=[shared performSelector:@selector(applicationWithBundleIdentifier:) withObject:kAMZ];
        if(!app)return 0;
        NSArray *paths=@[@"processState.pid",@"processState.processIdentifier",@"process.pid",
                         @"process.processIdentifier",@"pid",@"processIdentifier"];
        for(NSString *path in paths){
            @try {
                id value=[app valueForKeyPath:path];
                if([value respondsToSelector:@selector(integerValue)]){
                    NSInteger p=[value integerValue];
                    if(p>0)return p;
                }
            } @catch (__unused NSException *e) {}
        }
    } @catch (__unused NSException *e) {}
    return 0;
}

static UIImage *ADSplashImage7312(void) {
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        image=[UIImage imageWithContentsOfFile:@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png"];
        if(!image)image=[UIImage imageWithContentsOfFile:@"/Library/Application Support/AmazonDark/splash-logo.png"];
    });
    return image;
}

static void ADRemoveShim7312(void) {
    @try {
        if(!gShim7312)return;
        UIView *shim=gShim7312; gShim7312=nil;
        SBSceneView *host=gShimHost7312; gShimHost7312=nil;
        if(host)objc_setAssociatedObject(host,kShimKey7312,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [shim removeFromSuperview];
    } @catch (__unused NSException *e) {}
}

// Scene-attached so Apple's normal scene/icon transform remains the animation owner.
// The shim exists only until Amazon's own dark native splash is confirmed onscreen.
static void ADAttachShim7312(UIView *host) {
    @try {
        if(!host)return;
        if(gShim7312&&gShim7312.superview==host)return;
        ADRemoveShim7312();

        UIColor *dk=[UIColor colorWithRed:0.094 green:0.102 blue:0.106 alpha:1.0];
        CGRect initial=host.bounds;
        CGRect screen=UIScreen.mainScreen.bounds;
        if(initial.size.width<200.0||initial.size.height<300.0)initial=screen;
        UIView *shim=[[UIView alloc] initWithFrame:initial];
        shim.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        shim.backgroundColor=dk;
        shim.userInteractionEnabled=NO;

        UIImage *splash=ADSplashImage7312();
        if(splash){
            UIImageView *logo=[[UIImageView alloc] initWithImage:splash];
            logo.contentMode=UIViewContentModeScaleAspectFit;
            logo.translatesAutoresizingMaskIntoConstraints=NO;
            [shim addSubview:logo];
            CGFloat baseW=host.bounds.size.width>=200.0?host.bounds.size.width:screen.size.width;
            CGFloat lw=MAX(baseW,200.0)*0.62;
            CGFloat lh=lw*(splash.size.height/MAX(splash.size.width,1.0));
            [NSLayoutConstraint activateConstraints:@[
                [logo.centerXAnchor constraintEqualToAnchor:shim.centerXAnchor],
                [logo.centerYAnchor constraintEqualToAnchor:shim.centerYAnchor],
                [logo.widthAnchor constraintEqualToConstant:lw],
                [logo.heightAnchor constraintEqualToConstant:lh],
            ]];
        }

        [host addSubview:shim];
        gShim7312=shim;
        gShimHost7312=(SBSceneView *)host;
        unsigned gen=++gShimGen7312;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(kShimHardCap7312*NSEC_PER_SEC)),
                       dispatch_get_main_queue(),^{
            @try { if(gShim7312&&gen==gShimGen7312)ADRemoveShim7312(); }
            @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

// v7.315: defer ALL SpringBoard inspection and hierarchy work until the current
// SBSceneView callback has completely returned to UIKit. The four watchdog stackshots
// from v7.313/v7.314 show the same self-owned pthread mutex on SpringBoard main; doing
// work "after %orig" was still inside UIKit's outer scene-attachment transaction.
static void ADScheduleShimCheck7315(SBSceneView *host) {
    if(!host)return;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if(!host.window||!ADSBEnabled())return;
            if(objc_getAssociatedObject(host,kShimKey7312))return;
            if(![(ADSceneBundleId(host) ?: @"") isEqualToString:kAMZ])return;

            NSInteger pid=ADAmazonProcessIdentifier7312();
            if(pid<=0)return; // fail open rather than risking a warm-resume mask

            // Same process => ordinary warm resume. Never fabricate a launch transition.
            if(gAmazonProcessID7312>0&&pid==gAmazonProcessID7312)return;

            // The native splash may have become ready before this deferred block ran.
            // In that case there is nothing left to bridge; remember the process and skip.
            if(gNativeSplashReadyPID7315>0&&pid==gNativeSplashReadyPID7315){
                gAmazonProcessID7312=pid;
                return;
            }

            ADAttachShim7312(host);
            if(gShim7312&&gShim7312.superview==host){
                objc_setAssociatedObject(host,kShimKey7312,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                gAmazonProcessID7312=pid;
            }
        } @catch (__unused NSException *e) {}
    });
}

%hook SBSceneView
- (void)didMoveToWindow {
    %orig;
    // Intentionally no property access, KVC, process lookup, or UIView mutation here.
    // Enqueue and return immediately so UIKit can release its scene/window mutex first.
    ADScheduleShimCheck7315(self);
}
%end

%ctor {
    @try {
        // SpringBoard may restart while Amazon remains alive. Seed the remembered PID so
        // that already-running Amazon is still treated as a warm resume.
        NSInteger p=ADAmazonProcessIdentifier7312();
        if(p>0)gAmazonProcessID7312=p;
    } @catch (__unused NSException *e) {}
    if(!ADSBEnabled())return;

    @try {
        static int nativeSplashToken=0;
        notify_register_dispatch("com.colindavidr.amazondark.native-splash-ready",&nativeSplashToken,
                                 dispatch_get_main_queue(),^(__unused int t){
            // Record which Amazon process already reached its real dark native splash.
            // This closes the race where the notification beats the deferred scene block.
            NSInteger p=ADAmazonProcessIdentifier7312();
            if(p>0){
                gNativeSplashReadyPID7315=p;
                gAmazonProcessID7312=p;
            }
            ADRemoveShim7312();
        });
    } @catch (__unused NSException *e) {}

    @autoreleasepool {
        @try { %init; }
        @catch (__unused NSException *e) {}
    }
}
