// AmazonDarkSB.xm — v7.324 pre-armed scene cover + proven Home-ready handoff
// Restores the proven stock-transition presentation used by the v7.301 line.
//
// Key correction from the v7.319 launch probe:
//   * classify a genuine cold Amazon launch at SBIconView tapGestureDidChange:, where
//     Amazon's PID is still 0 on the tested iOS 17 device;
//   * carry that one-shot decision forward to SBSceneView didMoveToWindow;
//   * attach the dark cover to the Amazon SBSceneView even if the process has started
//     by then. This removes the old late-PID cold/warm race without replacing iOS's
//     native icon-zoom transition.
//
// The cover is a subview of the launching Amazon scene, exactly so SpringBoard animates
// it with the app. No independent top-level launch window is used in this build.

#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/runtime.h>

extern "C" void MSHookMessageEx(Class cls, SEL sel, IMP imp, IMP *result);

static NSString * const kAMZ      = @"com.amazon.Amazon";
static NSString * const kDefaults = @"com.colindavidr.amazondark";
static const NSTimeInterval kCoverFade7323        = 0.55;
static const NSTimeInterval kReadySettle7324       = 0.40;
static const NSTimeInterval kCoverMinimum7324      = 1.40;
static const NSTimeInterval kCoverHardCap7323      = 20.0;

@interface SBSceneView : UIView @end
@interface SBIconView : UIView
- (void)tapGestureDidChange:(id)gesture;
@end

static UIView *gCoverOverlay7323;
static SBSceneView *gCoverHost7323;
static const void *kCoveredKey7323=&kCoveredKey7323;
static unsigned gCoverGen7323;
static BOOL gColdLaunchPending7323=NO;
static unsigned gColdArmGen7323;
static double gPresentAt7324=0.0;

static NSString * const kADSBLaunchProbePath7323=@"/var/mobile/AmazonDark-v7.324-launch-sb-probe.txt";
static dispatch_queue_t ADSBProbeQueue7323(void){
    static dispatch_queue_t q; static dispatch_once_t once;
    dispatch_once(&once,^{q=dispatch_queue_create("com.colindavidr.amazondark.launchprobe.sb",DISPATCH_QUEUE_SERIAL);});
    return q;
}
static NSString *ADSBRect7323(CGRect r){return [NSString stringWithFormat:@"%.1f,%.1f %.1fx%.1f",r.origin.x,r.origin.y,r.size.width,r.size.height];}
static void ADSBProbeLog7323(NSString *event,NSString *detail){
    @try {
        NSTimeInterval wall=[NSDate timeIntervalSinceReferenceDate], up=NSProcessInfo.processInfo.systemUptime;
        NSString *line=[NSString stringWithFormat:@"%.6f up=%.6f pid=%d main=%d event=%@ %@\n",wall,up,NSProcessInfo.processInfo.processIdentifier,[NSThread isMainThread]?1:0,event?:@"?",detail?:@""];
        dispatch_async(ADSBProbeQueue7323(),^{ @autoreleasepool { @try {
            NSData *d=[line dataUsingEncoding:NSUTF8StringEncoding]; NSFileManager *fm=[NSFileManager defaultManager];
            if(![fm fileExistsAtPath:kADSBLaunchProbePath7323])[fm createFileAtPath:kADSBLaunchProbePath7323 contents:nil attributes:@{NSFilePosixPermissions:@0666}];
            NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:kADSBLaunchProbePath7323]; if(h){[h seekToEndOfFile];[h writeData:d];[h closeFile];}
        } @catch(__unused NSException *e){} }});
    } @catch(__unused NSException *e){}
}

static BOOL ADSBEnabled7323(void){
    @try {
        for(NSString *path in @[@"/var/jb/var/mobile/Library/Preferences/com.colindavidr.amazondark.plist",@"/var/mobile/Library/Preferences/com.colindavidr.amazondark.plist"]){
            NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:path]; if(d){id v=d[@"enabled"]; return v?[v boolValue]:YES;}
        }
    } @catch(__unused NSException *e){}
    return YES;
}
static NSInteger ADAmazonPID7323(void){
    @try {
        Class ctl=objc_getClass("SBApplicationController"); if(!ctl||![ctl respondsToSelector:@selector(sharedInstance)])return 0;
        id shared=[ctl performSelector:@selector(sharedInstance)]; if(!shared||![shared respondsToSelector:@selector(applicationWithBundleIdentifier:)])return 0;
        id app=[shared performSelector:@selector(applicationWithBundleIdentifier:) withObject:kAMZ]; if(!app)return 0;
        for(NSString *path in @[@"processState.pid",@"processState.processIdentifier",@"process.pid",@"process.processIdentifier",@"pid",@"processIdentifier"]){
            @try { id v=[app valueForKeyPath:path]; if([v respondsToSelector:@selector(integerValue)]){NSInteger p=[v integerValue]; if(p>0)return p;} } @catch(__unused NSException *e){}
        }
    } @catch(__unused NSException *e){}
    return 0;
}
static BOOL ADAmazonProcessRunning7324(void){
    @try {
        Class ctl=objc_getClass("SBApplicationController"); if(!ctl||![ctl respondsToSelector:@selector(sharedInstance)])return NO;
        id shared=[ctl performSelector:@selector(sharedInstance)]; if(!shared||![shared respondsToSelector:@selector(applicationWithBundleIdentifier:)])return NO;
        id app=[shared performSelector:@selector(applicationWithBundleIdentifier:) withObject:kAMZ]; if(!app)return NO;
        id ps=nil; @try { ps=[app valueForKey:@"processState"]; } @catch(__unused NSException *e){}
        if(ps&&[ps respondsToSelector:@selector(isRunning)]){ id v=[ps valueForKey:@"isRunning"]; if([v respondsToSelector:@selector(boolValue)])return [v boolValue]; }
    } @catch(__unused NSException *e){}
    return NO;
}
static NSString *ADBundleForIconView7323(id iconView){
    if(!iconView)return nil;
    @try {
        for(NSString *path in @[@"applicationBundleIdentifier",@"applicationBundleIdentifierForShortcuts",@"icon.applicationBundleID",@"icon.applicationBundleIdentifier",@"icon.application.bundleIdentifier"]){
            @try { id v=[iconView valueForKeyPath:path]; if([v isKindOfClass:[NSString class]]&&[v length])return v; } @catch(__unused NSException *e){}
        }
    } @catch(__unused NSException *e){}
    return nil;
}
static NSString *ADSceneBundleId7323(UIView *v){
    @try { id val=[v valueForKeyPath:@"sceneHandle.application.bundleIdentifier"]; return [val isKindOfClass:[NSString class]]?val:nil; }
    @catch(__unused NSException *e){return nil;}
}
static UIImage *ADSplashImage7323(void){
    static UIImage *image; static dispatch_once_t once;
    dispatch_once(&once,^{ image=[UIImage imageWithContentsOfFile:@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png"]; if(!image)image=[UIImage imageWithContentsOfFile:@"/Library/Application Support/AmazonDark/splash-logo.png"]; });
    return image;
}

static void ADRemoveCover7323(BOOL animated){
    @try {
        UIView *ov=gCoverOverlay7323; if(!ov)return;
        gCoverOverlay7323=nil; SBSceneView *host=gCoverHost7323; gCoverHost7323=nil;
        if(host)objc_setAssociatedObject(host,kCoveredKey7323,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADSBProbeLog7323(@"cover.remove",[NSString stringWithFormat:@"animated=%d host=%p",animated?1:0,host]);
        if(animated){ [UIView animateWithDuration:kCoverFade7323 animations:^{ov.alpha=0.0;} completion:^(__unused BOOL f){@try{[ov removeFromSuperview];}@catch(__unused NSException *e){}}]; }
        else [ov removeFromSuperview];
    } @catch(__unused NSException *e){}
}
static void ADMoveCoverToScene7324(SBSceneView *host){
    @try {
        UIView *ov=gCoverOverlay7323; SBSceneView *old=gCoverHost7323;
        if(!ov||!host||!host.window||old==host)return;
        if(old)objc_setAssociatedObject(old,kCoveredKey7323,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ov.frame=host.bounds; ov.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [host addSubview:ov];
        gCoverHost7323=host; objc_setAssociatedObject(host,kCoveredKey7323,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADSBProbeLog7323(@"cover.move",[NSString stringWithFormat:@"from=%p to=%p win=%p frame=%@",old,host,host.window,ADSBRect7323(host.bounds)]);
    } @catch(__unused NSException *e){}
}
static void ADAttachCoverToScene7323(SBSceneView *host,NSString *reason){
    @try {
        if(!host||!host.window)return;
        if(gCoverOverlay7323&&gCoverOverlay7323.superview==host)return;
        UIView *ov=[[UIView alloc] initWithFrame:host.bounds];
        ov.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        ov.backgroundColor=[UIColor colorWithRed:0.094 green:0.102 blue:0.106 alpha:1.0]; ov.userInteractionEnabled=NO;
        UIImage *splash=ADSplashImage7323();
        if(splash){
            UIImageView *logo=[[UIImageView alloc] initWithImage:splash]; logo.contentMode=UIViewContentModeScaleAspectFit; logo.translatesAutoresizingMaskIntoConstraints=NO; [ov addSubview:logo];
            CGFloat lw=MAX(host.bounds.size.width,200.0)*0.62, lh=lw*(splash.size.height/MAX(splash.size.width,1.0));
            [NSLayoutConstraint activateConstraints:@[[logo.centerXAnchor constraintEqualToAnchor:ov.centerXAnchor],[logo.centerYAnchor constraintEqualToAnchor:ov.centerYAnchor],[logo.widthAnchor constraintEqualToConstant:lw],[logo.heightAnchor constraintEqualToConstant:lh]]];
        }
        [host addSubview:ov]; gCoverOverlay7323=ov; gCoverHost7323=host; gPresentAt7324=CFAbsoluteTimeGetCurrent(); unsigned gen=++gCoverGen7323;
        ADSBProbeLog7323(@"cover.attach",[NSString stringWithFormat:@"reason=%@ host=%p win=%p frame=%@ pidNow=%ld",reason?:@"?",host,host.window,ADSBRect7323(host.bounds),(long)ADAmazonPID7323()]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(kCoverHardCap7323*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            @try { if(gCoverOverlay7323&&gen==gCoverGen7323){ADSBProbeLog7323(@"cover.hardcap",@""); ADRemoveCover7323(NO);} } @catch(__unused NSException *e){}
        });
    } @catch(__unused NSException *e){}
}

static void (*ADOrigIconTap7323)(id,SEL,id);
static void ADHookIconTap7323(id self,SEL _cmd,id gesture){
    NSString *bid=ADBundleForIconView7323(self); NSInteger pid=ADAmazonPID7323();
    NSInteger state=[gesture respondsToSelector:@selector(state)]?(NSInteger)[gesture state]:-1;
    BOOL amazon=[(bid?:@"") isEqualToString:kAMZ]; BOOL running=ADAmazonProcessRunning7324();
    BOOL cold=(amazon&&ADSBEnabled7323()&&state==UIGestureRecognizerStateEnded&&(pid<=0||!running));
    if(cold){
        gColdLaunchPending7323=YES; unsigned arm=++gColdArmGen7323;
        ADSBProbeLog7323(@"cold.arm",[NSString stringWithFormat:@"view=%p bid=%@ state=%ld pid=%ld running=%d gen=%u",self,bid,(long)state,(long)pid,running?1:0,arm]);
        // One-shot stale-arm safety only. A real scene attachment normally consumes this within ~1 s.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(3.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ if(gColdLaunchPending7323&&arm==gColdArmGen7323){gColdLaunchPending7323=NO; ADSBProbeLog7323(@"cold.arm.expire",[NSString stringWithFormat:@"gen=%u",arm]);} });
    }
    if(ADOrigIconTap7323)ADOrigIconTap7323(self,_cmd,gesture);
}
static void ADInstallTapHook7323(void){
    @try { Class c=objc_getClass("SBIconView"); SEL s=NSSelectorFromString(@"tapGestureDidChange:"); Method m=c?class_getInstanceMethod(c,s):NULL; if(m){MSHookMessageEx(c,s,(IMP)ADHookIconTap7323,(IMP *)&ADOrigIconTap7323); ADSBProbeLog7323(@"hook.install",@"SBIconView tapGestureDidChange:");} else ADSBProbeLog7323(@"hook.skip",@"SBIconView tapGestureDidChange: absent"); }
    @catch(__unused NSException *e){}
}

%hook SBSceneView
- (void)didMoveToWindow {
    %orig;
    @try {
        if(!self.window||!ADSBEnabled7323())return;
        NSString *bid=ADSceneBundleId7323(self); if(![bid isEqualToString:kAMZ])return;
        BOOL prearmed=gColdLaunchPending7323; NSInteger pid=ADAmazonPID7323();
        BOOL running=ADAmazonProcessRunning7324();
        ADSBProbeLog7323(@"scene.didMove",[NSString stringWithFormat:@"host=%p win=%p prearmed=%d pid=%ld running=%d covered=%d activeCover=%d",self,self.window,prearmed?1:0,(long)pid,running?1:0,objc_getAssociatedObject(self,kCoveredKey7323)?1:0,gCoverOverlay7323?1:0]);
        // During one cold launch SpringBoard may replace the concrete Amazon scene host.
        // Keep the same opaque cover on whichever Amazon scene is actually entering a window.
        if(gCoverOverlay7323){ ADMoveCoverToScene7324(self); return; }
        if(objc_getAssociatedObject(self,kCoveredKey7323))return;
        if(prearmed){ gColdLaunchPending7323=NO; objc_setAssociatedObject(self,kCoveredKey7323,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC); ADAttachCoverToScene7323(self,@"prearmed-cold"); return; }
        // Treat a stale PID whose processState is no longer running as cold too.
        if(pid<=0||!running){ objc_setAssociatedObject(self,kCoveredKey7323,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC); ADAttachCoverToScene7323(self,@"scene-cold-fallback"); }
    } @catch(__unused NSException *e){}
}
%end

%ctor {
    ADSBProbeLog7323(@"ctor",[NSString stringWithFormat:@"enabled=%d",ADSBEnabled7323()?1:0]);
    ADInstallTapHook7323();
    if(!ADSBEnabled7323())return;
    @try {
        static int token=0;
        notify_register_dispatch("com.colindavidr.amazondark.ready",&token,dispatch_get_main_queue(),^(__unused int t){
            @try {
                if(!gCoverOverlay7323){ADSBProbeLog7323(@"ready.notify",@"cover=0");return;}
                double shown=CFAbsoluteTimeGetCurrent()-gPresentAt7324;
                double minimumRemaining=shown<kCoverMinimum7324?(kCoverMinimum7324-shown):0.0;
                double wait=minimumRemaining>kReadySettle7324?minimumRemaining:kReadySettle7324;
                unsigned gen=gCoverGen7323;
                ADSBProbeLog7323(@"ready.notify",[NSString stringWithFormat:@"cover=1 shown=%.3f wait=%.3f gen=%u",shown,wait,gen]);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(wait*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                    @try { if(gCoverOverlay7323&&gen==gCoverGen7323){ADSBProbeLog7323(@"ready.dismiss",[NSString stringWithFormat:@"gen=%u",gen]);ADRemoveCover7323(YES);} } @catch(__unused NSException *e){}
                });
            } @catch(__unused NSException *e){}
        });
    } @catch(__unused NSException *e){}
    @autoreleasepool { @try { %init; } @catch(__unused NSException *e){} }
}
