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

@interface SBApplicationIcon : NSObject
- (void)launchFromLocation:(long long)location;
- (id)applicationBundleID;
@end

@interface SBHIconManager : NSObject
@end

static UIWindow *gBridgeWindow7316;
static unsigned gBridgeGen7316;

// v7.317 probe-only launch recorder. Writes outside any app container so a SpringBoard
// launch-path failure can be recovered directly from NewTerm. Logging is serialized off-main;
// event timestamps are captured before enqueue so file I/O cannot perturb launch ordering.
static NSString * const kADSBLaunchProbePath7317=@"/var/mobile/AmazonDark-v7.317-launch-sb-probe.txt";
static dispatch_queue_t ADSBProbeQueue7317(void){
    static dispatch_queue_t q; static dispatch_once_t once;
    dispatch_once(&once,^{q=dispatch_queue_create("com.colindavidr.amazondark.launchprobe.sb",DISPATCH_QUEUE_SERIAL);});
    return q;
}
static NSString *ADSBRect7317(CGRect r){return [NSString stringWithFormat:@"%.1f,%.1f %.1fx%.1f",r.origin.x,r.origin.y,r.size.width,r.size.height];}
static void ADSBProbeLog7317(NSString *event,NSString *detail){
    @try {
        NSTimeInterval wall=[NSDate timeIntervalSinceReferenceDate];
        NSTimeInterval up=NSProcessInfo.processInfo.systemUptime;
        NSString *line=[NSString stringWithFormat:@"%.6f up=%.6f pid=%d main=%d event=%@ %@\n",wall,up,NSProcessInfo.processInfo.processIdentifier,[NSThread isMainThread]?1:0,event?:@"?",detail?:@""];
        dispatch_async(ADSBProbeQueue7317(),^{
            @autoreleasepool {
                @try {
                    NSData *d=[line dataUsingEncoding:NSUTF8StringEncoding];
                    NSFileManager *fm=[NSFileManager defaultManager];
                    if(![fm fileExistsAtPath:kADSBLaunchProbePath7317])[fm createFileAtPath:kADSBLaunchProbePath7317 contents:nil attributes:@{NSFilePosixPermissions:@0666}];
                    NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:kADSBLaunchProbePath7317];
                    if(h){[h seekToEndOfFile];[h writeData:d];[h closeFile];}
                } @catch(__unused NSException *e){}
            }
        });
    } @catch(__unused NSException *e){}
}
static void ADSBProbeWindows7317(NSString *reason){
    dispatch_async(dispatch_get_main_queue(),^{
        @try {
            NSArray<UIWindow *> *wins=UIApplication.sharedApplication.windows.copy?:@[];
            ADSBProbeLog7317(@"windows.begin",[NSString stringWithFormat:@"reason=%@ count=%lu",reason?:@"?",(unsigned long)wins.count]);
            NSUInteger i=0;
            for(UIWindow *w in wins){
                ADSBProbeLog7317(@"window",[NSString stringWithFormat:@"i=%lu cls=%@ level=%.1f hidden=%d alpha=%.3f key=%d frame=%@ root=%@ sceneState=%ld",(unsigned long)i++,NSStringFromClass(w.class)?:@"?",w.windowLevel,w.hidden?1:0,w.alpha,w.isKeyWindow?1:0,ADSBRect7317(w.frame),NSStringFromClass(w.rootViewController.class)?:@"?",(long)w.windowScene.activationState]);
            }
            ADSBProbeLog7317(@"windows.end",reason?:@"?");
        } @catch(__unused NSException *e){}
    });
}

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

static NSString *ADBundleForLaunchObject7317(id obj){
    if(!obj)return nil;
    @try {
        for(NSString *path in @[@"applicationBundleID",@"applicationBundleIdentifier",@"bundleIdentifier",@"application.bundleIdentifier",@"application.bundleID"]){
            @try { id v=[obj valueForKeyPath:path]; if([v isKindOfClass:[NSString class]]&&[v length])return v; } @catch(__unused NSException *e){}
        }
    } @catch(__unused NSException *e){}
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
    ADSBProbeLog7317(@"bridge.remove.enter",[NSString stringWithFormat:@"exists=%d",gBridgeWindow7316?1:0]);
    @try {
        UIWindow *w=gBridgeWindow7316;
        if(!w)return;
        gBridgeWindow7316=nil;
        w.hidden=YES;
        w.rootViewController=nil;
        ADSBProbeLog7317(@"bridge.remove.done",@"");
    } @catch (__unused NSException *e) {}
}

static void ADPresentBridge7316(void) {
    ADSBProbeLog7317(@"bridge.present.enter",[NSString stringWithFormat:@"exists=%d enabled=%d",gBridgeWindow7316?1:0,ADSBEnabled7316()?1:0]);
    @try {
        if(gBridgeWindow7316||!ADSBEnabled7316()){ADSBProbeLog7317(@"bridge.present.skip",@"existing-or-disabled");return;}
        CGRect screen=UIScreen.mainScreen.bounds;
        UIWindow *w=[[UIWindow alloc] initWithFrame:screen];
        if(@available(iOS 13.0,*)){
            UIWindowScene *scene=ADForegroundSpringBoardScene7316();
            ADSBProbeLog7317(@"bridge.scene",[NSString stringWithFormat:@"scene=%p state=%ld",scene,(long)scene.activationState]);
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
        ADSBProbeLog7317(@"bridge.visible",[NSString stringWithFormat:@"ptr=%p level=%.1f hidden=%d alpha=%.3f frame=%@ logo=%d",w,w.windowLevel,w.hidden?1:0,w.alpha,ADSBRect7317(w.frame),splash?1:0]);
        ADSBProbeWindows7317(@"after-bridge-visible");
        unsigned gen=++gBridgeGen7316;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(kBridgeHardCap7316*NSEC_PER_SEC)),
                       dispatch_get_main_queue(),^{
            @try { if(gBridgeWindow7316&&gen==gBridgeGen7316){ADSBProbeLog7317(@"bridge.hardcap",[NSString stringWithFormat:@"gen=%u",gen]);ADRemoveBridge7316();} }
            @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

%hook SBIconController
- (void)_launchFromIconView:(id)iconView {
    BOOL amazon=NO; BOOL cold=NO; NSInteger pid=0; NSString *bid=nil;
    @try {
        bid=ADBundleForIconView7316(iconView);
        pid=ADAmazonProcessIdentifier7316();
        amazon=[(bid?:@"") isEqualToString:kAMZ];
        if(amazon&&ADSBEnabled7316())cold=(pid<=0);
        ADSBProbeLog7317(@"SBIconController._launchFromIconView.pre",[NSString stringWithFormat:@"iconCls=%@ bid=%@ amazon=%d enabled=%d amazonPid=%ld cold=%d",NSStringFromClass([iconView class])?:@"?",bid?:@"nil",amazon?1:0,ADSBEnabled7316()?1:0,(long)pid,cold?1:0]);
        if(cold)ADPresentBridge7316();
    } @catch (__unused NSException *e) { ADSBProbeLog7317(@"SBIconController._launchFromIconView.exception",@""); }
    %orig;
    ADSBProbeLog7317(@"SBIconController._launchFromIconView.post",[NSString stringWithFormat:@"amazon=%d cold=%d bridge=%d",amazon?1:0,cold?1:0,gBridgeWindow7316?1:0]);
}
- (void)iconManager:(id)manager launchIconForIconView:(id)iconView {
    NSString *bid=nil; @try{bid=ADBundleForIconView7316(iconView);}@catch(__unused NSException *e){}
    ADSBProbeLog7317(@"SBIconController.iconManager.launchIconForIconView",[NSString stringWithFormat:@"iconCls=%@ bid=%@",NSStringFromClass([iconView class])?:@"?",bid?:@"nil"]);
    %orig;
}
%end

%hook SBApplicationIcon
- (void)launchFromLocation:(long long)location {
    NSString *bid=nil;
    @try { if([self respondsToSelector:@selector(applicationBundleID)])bid=[self applicationBundleID]; } @catch(__unused NSException *e){}
    ADSBProbeLog7317(@"SBApplicationIcon.launchFromLocation",[NSString stringWithFormat:@"location=%lld bid=%@ amazonPid=%ld",location,bid?:@"nil",(long)ADAmazonProcessIdentifier7316()]);
    %orig;
}
%end

%hook SBHIconManager
- (void)iconModel:(id)model launchIcon:(id)icon fromLocation:(id)location context:(id)context {
    NSString *bid=ADBundleForLaunchObject7317(icon);
    ADSBProbeLog7317(@"SBHIconManager.iconModel.launchIcon",[NSString stringWithFormat:@"iconCls=%@ bid=%@ locationCls=%@ contextCls=%@ amazonPid=%ld",NSStringFromClass([icon class])?:@"?",bid?:@"nil",NSStringFromClass([location class])?:@"?",NSStringFromClass([context class])?:@"?",(long)ADAmazonProcessIdentifier7316()]);
    %orig;
}
%end

%ctor {
    ADSBProbeLog7317(@"ctor",[NSString stringWithFormat:@"enabled=%d",ADSBEnabled7316()?1:0]);
    @try {
        ADSBProbeLog7317(@"selector-map",[NSString stringWithFormat:@"SBIconController=%d _launchFromIconView=%d launchIconForIconView=%d SBApplicationIcon=%d launchFromLocation=%d SBHIconManager=%d iconModelLaunch=%d",objc_getClass("SBIconController")?1:0,class_getInstanceMethod(objc_getClass("SBIconController"),@selector(_launchFromIconView:))?1:0,class_getInstanceMethod(objc_getClass("SBIconController"),@selector(iconManager:launchIconForIconView:))?1:0,objc_getClass("SBApplicationIcon")?1:0,class_getInstanceMethod(objc_getClass("SBApplicationIcon"),@selector(launchFromLocation:))?1:0,objc_getClass("SBHIconManager")?1:0,class_getInstanceMethod(objc_getClass("SBHIconManager"),@selector(iconModel:launchIcon:fromLocation:context:))?1:0]);
    } @catch(__unused NSException *e){}
    if(!ADSBEnabled7316())return;
    @try {
        static int nativeSplashToken=0;
        notify_register_dispatch("com.colindavidr.amazondark.native-splash-ready",&nativeSplashToken,
                                 dispatch_get_main_queue(),^(__unused int t){ ADSBProbeLog7317(@"native-splash-ready.notify",[NSString stringWithFormat:@"bridge=%d",gBridgeWindow7316?1:0]); ADRemoveBridge7316(); });
    } @catch (__unused NSException *e) {}
    @autoreleasepool {
        @try { %init; }
        @catch (__unused NSException *e) {}
    }
}
