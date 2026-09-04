// AmazonDarkSB.xm — v7.322 transition-coupled icon-tap cold-launch bridge
// Cold-launch first-frame bridge without touching SBSceneView.
//
// Architecture:
//   * Ordinary warm reopen: Amazon already has a process BEFORE the launch request -> do nothing.
//   * Genuine cold icon launch: before SpringBoard begins launching Amazon, show one independent,
//     non-key, noninteractive SpringBoard UIWindow whose dark surface begins at the tapped icon
//     geometry and expands with the launch. The window never mutates SBSceneView lifecycle state.
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

extern "C" void MSHookMessageEx(Class cls, SEL sel, IMP imp, IMP *result);

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

@interface SBIconView : UIView
- (void)tapGestureDidChange:(id)gesture;
@end

static UIWindow *gBridgeWindow7316;
static UIView *gBridgeSurface7322;
static unsigned gBridgeGen7316;

// v7.322 targeted launch recorder. Writes outside any app container so a SpringBoard
// launch-path failure can be recovered directly from NewTerm. Logging is serialized off-main;
// event timestamps are captured before enqueue so file I/O cannot perturb launch ordering.
static NSString * const kADSBLaunchProbePath7318=@"/var/mobile/AmazonDark-v7.322-launch-sb-probe.txt";
static dispatch_queue_t ADSBProbeQueue7318(void){
    static dispatch_queue_t q; static dispatch_once_t once;
    dispatch_once(&once,^{q=dispatch_queue_create("com.colindavidr.amazondark.launchprobe.sb",DISPATCH_QUEUE_SERIAL);});
    return q;
}
static NSString *ADSBRect7318(CGRect r){return [NSString stringWithFormat:@"%.1f,%.1f %.1fx%.1f",r.origin.x,r.origin.y,r.size.width,r.size.height];}
static void ADSBProbeLog7318(NSString *event,NSString *detail){
    @try {
        NSTimeInterval wall=[NSDate timeIntervalSinceReferenceDate];
        NSTimeInterval up=NSProcessInfo.processInfo.systemUptime;
        NSString *line=[NSString stringWithFormat:@"%.6f up=%.6f pid=%d main=%d event=%@ %@\n",wall,up,NSProcessInfo.processInfo.processIdentifier,[NSThread isMainThread]?1:0,event?:@"?",detail?:@""];
        dispatch_async(ADSBProbeQueue7318(),^{
            @autoreleasepool {
                @try {
                    NSData *d=[line dataUsingEncoding:NSUTF8StringEncoding];
                    NSFileManager *fm=[NSFileManager defaultManager];
                    if(![fm fileExistsAtPath:kADSBLaunchProbePath7318])[fm createFileAtPath:kADSBLaunchProbePath7318 contents:nil attributes:@{NSFilePosixPermissions:@0666}];
                    NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:kADSBLaunchProbePath7318];
                    if(h){[h seekToEndOfFile];[h writeData:d];[h closeFile];}
                } @catch(__unused NSException *e){}
            }
        });
    } @catch(__unused NSException *e){}
}
static void ADSBProbeWindows7318(NSString *reason){
    dispatch_async(dispatch_get_main_queue(),^{
        @try {
            NSArray<UIWindow *> *wins=UIApplication.sharedApplication.windows.copy?:@[];
            ADSBProbeLog7318(@"windows.begin",[NSString stringWithFormat:@"reason=%@ count=%lu",reason?:@"?",(unsigned long)wins.count]);
            NSUInteger i=0;
            for(UIWindow *w in wins){
                ADSBProbeLog7318(@"window",[NSString stringWithFormat:@"i=%lu cls=%@ level=%.1f hidden=%d alpha=%.3f key=%d frame=%@ root=%@ sceneState=%ld",(unsigned long)i++,NSStringFromClass(w.class)?:@"?",w.windowLevel,w.hidden?1:0,w.alpha,w.isKeyWindow?1:0,ADSBRect7318(w.frame),NSStringFromClass(w.rootViewController.class)?:@"?",(long)w.windowScene.activationState]);
            }
            ADSBProbeLog7318(@"windows.end",reason?:@"?");
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

@interface ADBridgeViewController7322 : UIViewController
@end
@implementation ADBridgeViewController7322
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures { return UIRectEdgeBottom; }
@end

static CGRect ADIconScreenRect7322(UIView *iconView) {
    @try {
        if(!iconView || !iconView.window)return CGRectNull;
        CGRect r=[iconView convertRect:iconView.bounds toView:nil];
        if(CGRectIsEmpty(r)||CGRectIsNull(r))return CGRectNull;
        return r;
    } @catch (__unused NSException *e) { return CGRectNull; }
}

static void ADRemoveBridge7316(void) {
    ADSBProbeLog7318(@"bridge.remove.enter",[NSString stringWithFormat:@"exists=%d",gBridgeWindow7316?1:0]);
    @try {
        UIWindow *w=gBridgeWindow7316;
        UIView *surface=gBridgeSurface7322;
        if(!w)return;
        gBridgeWindow7316=nil;
        gBridgeSurface7322=nil;
        [UIView animateWithDuration:0.10 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseOut animations:^{
            surface.alpha=0.0;
        } completion:^(__unused BOOL finished){
            w.hidden=YES;
            w.rootViewController=nil;
            ADSBProbeLog7318(@"bridge.remove.done",@"");
        }];
    } @catch (__unused NSException *e) {}
}

static void ADPresentBridge7316(UIView *iconView) {
    ADSBProbeLog7318(@"bridge.present.enter",[NSString stringWithFormat:@"exists=%d enabled=%d",gBridgeWindow7316?1:0,ADSBEnabled7316()?1:0]);
    @try {
        if(gBridgeWindow7316||!ADSBEnabled7316()){ADSBProbeLog7318(@"bridge.present.skip",@"existing-or-disabled");return;}
        CGRect screen=UIScreen.mainScreen.bounds;
        CGRect iconRect=ADIconScreenRect7322(iconView);
        if(CGRectIsNull(iconRect)||CGRectIsEmpty(iconRect))iconRect=CGRectMake(CGRectGetMidX(screen)-30.0,CGRectGetMidY(screen)-30.0,60.0,60.0);

        UIWindow *w=[[UIWindow alloc] initWithFrame:screen];
        if(@available(iOS 13.0,*)){
            UIWindowScene *scene=ADForegroundSpringBoardScene7316();
            ADSBProbeLog7318(@"bridge.scene",[NSString stringWithFormat:@"scene=%p state=%ld",scene,(long)scene.activationState]);
            if(scene)w.windowScene=scene;
        }

        UIColor *dark=[UIColor colorWithRed:0.094 green:0.102 blue:0.106 alpha:1.0];
        ADBridgeViewController7322 *vc=[ADBridgeViewController7322 new];
        vc.view.frame=screen;
        vc.view.backgroundColor=UIColor.clearColor;
        w.rootViewController=vc;
        w.backgroundColor=UIColor.clearColor;
        // Stay above SpringBoard/app-host content but below alert/system-overlay strata.
        w.windowLevel=UIWindowLevelNormal+10.0;
        w.userInteractionEnabled=NO;
        w.alpha=1.0;

        UIView *surface=[[UIView alloc] initWithFrame:iconRect];
        surface.backgroundColor=dark;
        surface.userInteractionEnabled=NO;
        surface.layer.masksToBounds=YES;
        surface.layer.cornerRadius=MIN(iconRect.size.width,iconRect.size.height)*0.225;
        [vc.view addSubview:surface];

        // No SpringBoard-side logo. The real Amazon splash controller owns artwork once its
        // scene exists; this bridge only owns the otherwise-white pre-process pixels.
        gBridgeWindow7316=w;
        gBridgeSurface7322=surface;
        w.hidden=NO;
        ADSBProbeLog7318(@"bridge.visible",[NSString stringWithFormat:@"ptr=%p level=%.1f start=%@ target=%@",w,w.windowLevel,ADSBRect7318(iconRect),ADSBRect7318(screen)]);

        [UIView animateWithDuration:0.34 delay:0.0 usingSpringWithDamping:0.90 initialSpringVelocity:0.0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{
            surface.frame=screen;
            surface.layer.cornerRadius=0.0;
        } completion:^(__unused BOOL finished){
            ADSBProbeLog7318(@"bridge.expand.done",[NSString stringWithFormat:@"frame=%@",ADSBRect7318(surface.frame)]);
        }];

        unsigned gen=++gBridgeGen7316;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(kBridgeHardCap7316*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            @try { if(gBridgeWindow7316&&gen==gBridgeGen7316){ADSBProbeLog7318(@"bridge.hardcap",[NSString stringWithFormat:@"gen=%u",gen]);ADRemoveBridge7316();} }
            @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

static void (*ADOrigIconTap7318)(id,SEL,id);
static void ADHookIconTap7318(id self,SEL _cmd,id gesture){
    NSString *bid=ADBundleForIconView7316(self);
    NSInteger pid=ADAmazonProcessIdentifier7316();
    NSInteger state=[gesture respondsToSelector:@selector(state)] ? (NSInteger)[gesture state] : -1;
    BOOL amazon=[(bid?:@"") isEqualToString:kAMZ];
    BOOL cold=(amazon && ADSBEnabled7316() && pid<=0 && state==UIGestureRecognizerStateEnded);
    ADSBProbeLog7318(@"SBIconView.tapGestureDidChange.pre",[NSString stringWithFormat:@"view=%p cls=%@ gestureCls=%@ state=%ld bid=%@ amazon=%d amazonPid=%ld cold=%d",self,NSStringFromClass([self class])?:@"?",NSStringFromClass([gesture class])?:@"?",(long)state,bid?:@"nil",amazon?1:0,(long)pid,cold?1:0]);
    if(cold)ADPresentBridge7316((UIView *)self);
    if(ADOrigIconTap7318)ADOrigIconTap7318(self,_cmd,gesture);
    ADSBProbeLog7318(@"SBIconView.tapGestureDidChange.post",[NSString stringWithFormat:@"bid=%@ amazonPid=%ld bridge=%d",bid?:@"nil",(long)ADAmazonProcessIdentifier7316(),gBridgeWindow7316?1:0]);
}
static void ADInstallDiscoveryHooks7318(void){
    @try {
        Class c=objc_getClass("SBIconView"); SEL sel=NSSelectorFromString(@"tapGestureDidChange:");
        Method m=c?class_getInstanceMethod(c,sel):NULL;
        if(m){
            MSHookMessageEx(c,sel,(IMP)ADHookIconTap7318,(IMP *)&ADOrigIconTap7318);
            ADSBProbeLog7318(@"hook.install",[NSString stringWithFormat:@"cls=SBIconView sel=tapGestureDidChange: types=%s",method_getTypeEncoding(m)?:"?"]);
        } else ADSBProbeLog7318(@"hook.skip",@"cls=SBIconView sel=tapGestureDidChange: absent");
    } @catch(__unused NSException *e){ADSBProbeLog7318(@"hook.exception",@"SBIconView tap");}
}

%ctor {
    ADSBProbeLog7318(@"ctor",[NSString stringWithFormat:@"enabled=%d",ADSBEnabled7316()?1:0]);
    ADInstallDiscoveryHooks7318();
    if(!ADSBEnabled7316())return;
    @try {
        static int nativeSplashToken=0;
        notify_register_dispatch("com.colindavidr.amazondark.native-splash-ready",&nativeSplashToken,
                                 dispatch_get_main_queue(),^(__unused int t){ ADSBProbeLog7318(@"native-splash-ready.notify",[NSString stringWithFormat:@"bridge=%d",gBridgeWindow7316?1:0]); ADRemoveBridge7316(); });
    } @catch (__unused NSException *e) {}
}
