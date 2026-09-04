// AmazonDarkSB.xm — v7.319 launch-discovery probe on v7.316 behavior
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
static unsigned gBridgeGen7316;

// v7.319 probe-only launch recorder. Writes outside any app container so a SpringBoard
// launch-path failure can be recovered directly from NewTerm. Logging is serialized off-main;
// event timestamps are captured before enqueue so file I/O cannot perturb launch ordering.
static NSString * const kADSBLaunchProbePath7318=@"/var/mobile/AmazonDark-v7.319-launch-sb-probe.txt";
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


static BOOL ADSBProbeInterestingClass7318(NSString *name){
    if(!name.length)return NO;
    return [name hasPrefix:@"SB"] || [name hasPrefix:@"SBH"] || [name isEqualToString:@"SpringBoard"];
}
static BOOL ADSBProbeInterestingSelector7318(NSString *sel){
    NSString *l=sel.lowercaseString;
    return [l containsString:@"launch"] || [l containsString:@"activate"] || [l containsString:@"open"] ||
           [l containsString:@"tap"] || [l containsString:@"touch"] || [l containsString:@"icon"];
}
static void ADSBDumpLaunchSurface7318(void){
    @try {
        int count=objc_getClassList(NULL,0); if(count<=0)return;
        Class *classes=(Class *)calloc((size_t)count,sizeof(Class)); if(!classes)return;
        count=objc_getClassList(classes,count);
        NSUInteger emitted=0;
        ADSBProbeLog7318(@"discovery.begin",[NSString stringWithFormat:@"classes=%d",count]);
        for(int i=0;i<count && emitted<1400;i++){
            Class c=classes[i]; NSString *cn=NSStringFromClass(c);
            if(!ADSBProbeInterestingClass7318(cn))continue;
            unsigned mc=0; Method *ml=class_copyMethodList(c,&mc);
            for(unsigned j=0;j<mc && emitted<1400;j++){
                SEL sel=method_getName(ml[j]); NSString *sn=NSStringFromSelector(sel);
                if(!ADSBProbeInterestingSelector7318(sn))continue;
                const char *types=method_getTypeEncoding(ml[j]);
                ADSBProbeLog7318(@"method",[NSString stringWithFormat:@"cls=%@ sel=%@ types=%s",cn,sn,types?:"?"]);
                emitted++;
            }
            if(ml)free(ml);
        }
        free(classes);
        ADSBProbeLog7318(@"discovery.end",[NSString stringWithFormat:@"emitted=%lu",(unsigned long)emitted]);
        for(NSString *cn in @[@"SBIconView",@"SBIconController",@"SBHIconManager",@"SBApplicationIcon"]){
            Class c=objc_getClass(cn.UTF8String); if(!c)continue;
            for(NSString *sn in @[@"tapGestureDidChange:",@"iconManager:touchesEndedForIconView:",@"iconManager:willPrepareIconViewForLaunch:",@"iconManager:launchIconForIconView:",@"iconModel:launchIcon:fromLocation:context:"]){
                Method m=class_getInstanceMethod(c,NSSelectorFromString(sn));
                ADSBProbeLog7318(@"candidate",[NSString stringWithFormat:@"cls=%@ sel=%@ exists=%d types=%s",cn,sn,m?1:0,m?(method_getTypeEncoding(m)?:"?"):"-"]);
            }
        }
    } @catch(__unused NSException *e){ ADSBProbeLog7318(@"discovery.exception",@""); }
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

static NSString *ADBundleForLaunchObject7318(id obj){
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
    ADSBProbeLog7318(@"bridge.remove.enter",[NSString stringWithFormat:@"exists=%d",gBridgeWindow7316?1:0]);
    @try {
        UIWindow *w=gBridgeWindow7316;
        if(!w)return;
        gBridgeWindow7316=nil;
        w.hidden=YES;
        w.rootViewController=nil;
        ADSBProbeLog7318(@"bridge.remove.done",@"");
    } @catch (__unused NSException *e) {}
}

static void ADPresentBridge7316(void) {
    ADSBProbeLog7318(@"bridge.present.enter",[NSString stringWithFormat:@"exists=%d enabled=%d",gBridgeWindow7316?1:0,ADSBEnabled7316()?1:0]);
    @try {
        if(gBridgeWindow7316||!ADSBEnabled7316()){ADSBProbeLog7318(@"bridge.present.skip",@"existing-or-disabled");return;}
        CGRect screen=UIScreen.mainScreen.bounds;
        UIWindow *w=[[UIWindow alloc] initWithFrame:screen];
        if(@available(iOS 13.0,*)){
            UIWindowScene *scene=ADForegroundSpringBoardScene7316();
            ADSBProbeLog7318(@"bridge.scene",[NSString stringWithFormat:@"scene=%p state=%ld",scene,(long)scene.activationState]);
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
        ADSBProbeLog7318(@"bridge.visible",[NSString stringWithFormat:@"ptr=%p level=%.1f hidden=%d alpha=%.3f frame=%@ logo=%d",w,w.windowLevel,w.hidden?1:0,w.alpha,ADSBRect7318(w.frame),splash?1:0]);
        ADSBProbeWindows7318(@"after-bridge-visible");
        unsigned gen=++gBridgeGen7316;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(kBridgeHardCap7316*NSEC_PER_SEC)),
                       dispatch_get_main_queue(),^{
            @try { if(gBridgeWindow7316&&gen==gBridgeGen7316){ADSBProbeLog7318(@"bridge.hardcap",[NSString stringWithFormat:@"gen=%u",gen]);ADRemoveBridge7316();} }
            @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

static void (*ADOrigIconTap7318)(id,SEL,id);
static void ADHookIconTap7318(id self,SEL _cmd,id gesture){
    NSString *bid=ADBundleForIconView7316(self);
    NSInteger pid=ADAmazonProcessIdentifier7316();
    ADSBProbeLog7318(@"SBIconView.tapGestureDidChange.pre",[NSString stringWithFormat:@"view=%p cls=%@ gestureCls=%@ state=%ld bid=%@ amazon=%d amazonPid=%ld",self,NSStringFromClass([self class])?:@"?",NSStringFromClass([gesture class])?:@"?",(long)([gesture respondsToSelector:@selector(state)]?[gesture state]:-1),bid?:@"nil",[(bid?:@"") isEqualToString:kAMZ]?1:0,(long)pid]);
    if(ADOrigIconTap7318)ADOrigIconTap7318(self,_cmd,gesture);
    ADSBProbeLog7318(@"SBIconView.tapGestureDidChange.post",[NSString stringWithFormat:@"bid=%@ amazonPid=%ld",bid?:@"nil",(long)ADAmazonProcessIdentifier7316()]);
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

%hook SBIconController
- (void)_launchFromIconView:(id)iconView {
    BOOL amazon=NO; BOOL cold=NO; NSInteger pid=0; NSString *bid=nil;
    @try {
        bid=ADBundleForIconView7316(iconView);
        pid=ADAmazonProcessIdentifier7316();
        amazon=[(bid?:@"") isEqualToString:kAMZ];
        if(amazon&&ADSBEnabled7316())cold=(pid<=0);
        ADSBProbeLog7318(@"SBIconController._launchFromIconView.pre",[NSString stringWithFormat:@"iconCls=%@ bid=%@ amazon=%d enabled=%d amazonPid=%ld cold=%d",NSStringFromClass([iconView class])?:@"?",bid?:@"nil",amazon?1:0,ADSBEnabled7316()?1:0,(long)pid,cold?1:0]);
        if(cold)ADPresentBridge7316();
    } @catch (__unused NSException *e) { ADSBProbeLog7318(@"SBIconController._launchFromIconView.exception",@""); }
    %orig;
    ADSBProbeLog7318(@"SBIconController._launchFromIconView.post",[NSString stringWithFormat:@"amazon=%d cold=%d bridge=%d",amazon?1:0,cold?1:0,gBridgeWindow7316?1:0]);
}
- (void)iconManager:(id)manager launchIconForIconView:(id)iconView {
    NSString *bid=nil; @try{bid=ADBundleForIconView7316(iconView);}@catch(__unused NSException *e){}
    ADSBProbeLog7318(@"SBIconController.iconManager.launchIconForIconView",[NSString stringWithFormat:@"iconCls=%@ bid=%@",NSStringFromClass([iconView class])?:@"?",bid?:@"nil"]);
    %orig;
}
%end

%hook SBApplicationIcon
- (void)launchFromLocation:(long long)location {
    NSString *bid=nil;
    @try { if([self respondsToSelector:@selector(applicationBundleID)])bid=[self applicationBundleID]; } @catch(__unused NSException *e){}
    ADSBProbeLog7318(@"SBApplicationIcon.launchFromLocation",[NSString stringWithFormat:@"location=%lld bid=%@ amazonPid=%ld",location,bid?:@"nil",(long)ADAmazonProcessIdentifier7316()]);
    %orig;
}
%end

%hook SBHIconManager
- (void)iconModel:(id)model launchIcon:(id)icon fromLocation:(id)location context:(id)context {
    NSString *bid=ADBundleForLaunchObject7318(icon);
    ADSBProbeLog7318(@"SBHIconManager.iconModel.launchIcon",[NSString stringWithFormat:@"iconCls=%@ bid=%@ locationCls=%@ contextCls=%@ amazonPid=%ld",NSStringFromClass([icon class])?:@"?",bid?:@"nil",NSStringFromClass([location class])?:@"?",NSStringFromClass([context class])?:@"?",(long)ADAmazonProcessIdentifier7316()]);
    %orig;
}
%end

%ctor {
    ADSBProbeLog7318(@"ctor",[NSString stringWithFormat:@"enabled=%d",ADSBEnabled7316()?1:0]);
    @try {
        ADSBProbeLog7318(@"selector-map",[NSString stringWithFormat:@"SBIconController=%d _launchFromIconView=%d launchIconForIconView=%d SBApplicationIcon=%d launchFromLocation=%d SBHIconManager=%d iconModelLaunch=%d",objc_getClass("SBIconController")?1:0,class_getInstanceMethod(objc_getClass("SBIconController"),@selector(_launchFromIconView:))?1:0,class_getInstanceMethod(objc_getClass("SBIconController"),@selector(iconManager:launchIconForIconView:))?1:0,objc_getClass("SBApplicationIcon")?1:0,class_getInstanceMethod(objc_getClass("SBApplicationIcon"),@selector(launchFromLocation:))?1:0,objc_getClass("SBHIconManager")?1:0,class_getInstanceMethod(objc_getClass("SBHIconManager"),@selector(iconModel:launchIcon:fromLocation:context:))?1:0]);
    } @catch(__unused NSException *e){}
    ADSBDumpLaunchSurface7318();
    ADInstallDiscoveryHooks7318();
    if(!ADSBEnabled7316())return;
    @try {
        static int nativeSplashToken=0;
        notify_register_dispatch("com.colindavidr.amazondark.native-splash-ready",&nativeSplashToken,
                                 dispatch_get_main_queue(),^(__unused int t){ ADSBProbeLog7318(@"native-splash-ready.notify",[NSString stringWithFormat:@"bridge=%d",gBridgeWindow7316?1:0]); ADRemoveBridge7316(); });
    } @catch (__unused NSException *e) {}
    @autoreleasepool {
        @try { %init; }
        @catch (__unused NSException *e) {}
    }
}
