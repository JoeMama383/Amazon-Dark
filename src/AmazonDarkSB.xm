// AmazonDarkSB.xm — v7.316
// Cold-launch first-frame bridge without touching SBSceneView.
//
// Architecture:
//   * Ordinary warm reopen: Amazon already has a process BEFORE the launch request -> do nothing.
//   * Genuine cold icon launch: before SpringBoard begins launching Amazon, show one independent,
//     non-key, noninteractive dark SpringBoard UIWindow. This window is NOT inserted into the
//     Amazon scene and never participates in SBSceneView lifecycle transactions.
//   * Amazon's exact native splash controller owns its own floor dark in Tweak.xm. Once that splash
//     has actually appeared it posts native-splash-ready and this independent bridge disappears.
//   * A short hard cap is failure safety only.
//
// The v7.312-v7.315 SBSceneView experiments are intentionally absent. The watchdog stackshots showed
// SpringBoard main self-deadlocking inside the scene/window attachment transaction even when work was
// moved after %orig / to a queued continuation. This implementation never hooks SBSceneView.

#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/runtime.h>

static NSString * const kAMZ      = @"com.amazon.Amazon";
static NSString * const kDefaults = @"com.colindavidr.amazondark";
static const NSTimeInterval kBridgeHardCap7316 = 4.0;

@interface SBIconController : NSObject
@end

static UIWindow *gBridgeWindow7316;
static unsigned gBridgeGen7316;

static BOOL ADSBEnabled7316(void) {
    @try {
        NSArray *paths=@[@"/var/jb/var/mobile/Library/Preferences/com.colindavidr.amazondark.plist",
                         @"/var/mobile/Library/Preferences/com.colindavidr.amazondark.plist"];
        for(NSString *path in paths){
            NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:path];
            if(d){ id value=d[@"enabled"]; return value ? [value boolValue] : YES; }
        }
    } @catch (__unused NSException *e) {}
    return YES;
}

// Sampled BEFORE SpringBoard starts the launch. This is the key difference from the old
// didMoveToWindow classifier, where isRunning/PID could change during the same cold launch.
static NSInteger ADAmazonProcessIdentifier7316(void) {
    @try {
        Class ctl=objc_getClass("SBApplicationController");
        if(!ctl||![ctl respondsToSelector:@selector(sharedInstance)])return 0;
        id shared=[ctl performSelector:@selector(sharedInstance)];
        if(!shared||![shared respondsToSelector:@selector(applicationWithBundleIdentifier:)])return 0;
        id app=[shared performSelector:@selector(applicationWithBundleIdentifier:) withObject:kAMZ];
        if(!app)return 0;
        for(NSString *path in @[@"processState.pid",@"processState.processIdentifier",@"process.pid",
                                @"process.processIdentifier",@"pid",@"processIdentifier"]){
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

static NSString *ADBundleForIconView7316(id iconView) {
    if(!iconView)return nil;
    @try {
        for(NSString *path in @[@"applicationBundleIdentifier",@"applicationBundleIdentifierForShortcuts",
                                @"icon.applicationBundleID",@"icon.applicationBundleIdentifier",
                                @"icon.application.bundleIdentifier",@"icon.application.bundleIdentifier"]){
            @try {
                id v=[iconView valueForKeyPath:path];
                if([v isKindOfClass:[NSString class]]&&[v length])return v;
            } @catch (__unused NSException *e) {}
        }
    } @catch (__unused NSException *e) {}
    return nil;
}

static UIWindowScene *ADForegroundSpringBoardScene7316(void) {
    if(@available(iOS 13.0,*)){
        @try {
            UIWindowScene *fallback=nil;
            for(UIScene *s in UIApplication.sharedApplication.connectedScenes){
                if(![s isKindOfClass:[UIWindowScene class]])continue;
                UIWindowScene *ws=(UIWindowScene *)s;
                if(s.activationState==UISceneActivationStateForegroundActive)return ws;
                if(!fallback&&s.activationState==UISceneActivationStateForegroundInactive)fallback=ws;
            }
            return fallback;
        } @catch (__unused NSException *e) {}
    }
    return nil;
}

static UIImage *ADSplashImage7316(void) {
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        image=[UIImage imageWithContentsOfFile:@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png"];
        if(!image)image=[UIImage imageWithContentsOfFile:@"/Library/Application Support/AmazonDark/splash-logo.png"];
    });
    return image;
}

static void ADRemoveBridge7316(void) {
    @try {
        UIWindow *w=gBridgeWindow7316;
        if(!w)return;
        gBridgeWindow7316=nil;
        w.hidden=YES;
        w.rootViewController=nil;
    } @catch (__unused NSException *e) {}
}

static void ADPresentBridge7316(void) {
    @try {
        if(gBridgeWindow7316||!ADSBEnabled7316())return;
        CGRect screen=UIScreen.mainScreen.bounds;
        UIWindow *w=[[UIWindow alloc] initWithFrame:screen];
        if(@available(iOS 13.0,*)){
            UIWindowScene *scene=ADForegroundSpringBoardScene7316();
            if(scene)w.windowScene=scene;
        }
        UIColor *dark=[UIColor colorWithRed:0.094 green:0.102 blue:0.106 alpha:1.0];
        UIViewController *vc=[UIViewController new];
        vc.view.frame=screen;
        vc.view.backgroundColor=dark;
        w.rootViewController=vc;
        w.backgroundColor=dark;
        w.windowLevel=UIWindowLevelAlert+1000.0;
        w.userInteractionEnabled=NO;
        w.alpha=1.0;

        UIImage *splash=ADSplashImage7316();
        if(splash){
            CGFloat lw=screen.size.width*0.62;
            CGFloat lh=lw*(splash.size.height/MAX(splash.size.width,1.0));
            UIImageView *logo=[[UIImageView alloc] initWithFrame:CGRectMake((screen.size.width-lw)*0.5,
                                                                            (screen.size.height-lh)*0.5,
                                                                            lw,lh)];
            logo.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|
                                  UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
            logo.contentMode=UIViewContentModeScaleAspectFit;
            logo.image=splash;
            [vc.view addSubview:logo];
        }

        // Do not make key. SpringBoard keeps its normal key window/input ownership; this is visual only.
        gBridgeWindow7316=w;
        w.hidden=NO;
        unsigned gen=++gBridgeGen7316;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(kBridgeHardCap7316*NSEC_PER_SEC)),
                       dispatch_get_main_queue(),^{
            @try { if(gBridgeWindow7316&&gen==gBridgeGen7316)ADRemoveBridge7316(); }
            @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

%hook SBIconController
- (void)_launchFromIconView:(id)iconView {
    BOOL amazon=NO;
    BOOL cold=NO;
    @try {
        amazon=[(ADBundleForIconView7316(iconView) ?: @"") isEqualToString:kAMZ];
        if(amazon&&ADSBEnabled7316())cold=(ADAmazonProcessIdentifier7316()<=0);
        if(cold)ADPresentBridge7316();
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

%ctor {
    if(!ADSBEnabled7316())return;
    @try {
        static int nativeSplashToken=0;
        notify_register_dispatch("com.colindavidr.amazondark.native-splash-ready",&nativeSplashToken,
                                 dispatch_get_main_queue(),^(__unused int t){ ADRemoveBridge7316(); });
    } @catch (__unused NSException *e) {}
    @autoreleasepool {
        @try { %init; }
        @catch (__unused NSException *e) {}
    }
}
