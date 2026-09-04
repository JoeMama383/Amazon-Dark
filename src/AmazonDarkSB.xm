// AmazonDarkSB.xm — v7.326 pre-presentation native scene overlay
//
// A stock launch image/snapshot is owned by iOS before Amazon can draw. The old
// SBSceneView -didMoveToWindow path attached our cover only after the scene had
// entered a window, leaving one compositor frame in which the stock white image
// could win. This build uses SpringBoard's own device-scene overlay API instead:
//
//   * a verified cold Amazon icon tap is classified before SpringBoard launches it;
//   * an already-created Amazon scene receives the overlay before the original tap;
//   * a newly-created Amazon scene receives it from its designated initializer,
//     before the scene is presented;
//   * the overlay belongs to the scene, so Apple's normal icon/scene animation is
//     still the only transition animation and no independent UIWindow is involved.

#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/runtime.h>
#import <limits.h>

extern "C" void MSHookMessageEx(Class cls, SEL sel, IMP imp, IMP *result);

static NSString * const kAMZ      = @"com.amazon.Amazon";
static NSString * const kDefaults = @"com.colindavidr.amazondark";
static const NSTimeInterval kCoverFade7326    = 0.55;
static const NSTimeInterval kReadySettle7326  = 0.40;
static const NSTimeInterval kCoverMinimum7326 = 1.40;
static const NSTimeInterval kCoverHardCap7326 = 20.0;
static const long long kOverlayPriority7326   = LLONG_MAX - 0x414D5A;

@interface SBIconView : UIView
- (void)tapGestureDidChange:(id)gesture;
@end

@interface SBDeviceApplicationSceneOverlayBasicWrapperView : UIView
- (instancetype)initWithCounterRotationRequirement:(BOOL)required;
@property(nonatomic) BOOL shouldLayoutOverlayImmediatelyForContainerGeometryChange;
@end

@interface SBDeviceApplicationSceneView : UIView
- (instancetype)initWithSceneHandle:(id)sceneHandle
                      referenceSize:(CGSize)referenceSize
                 contentOrientation:(long long)contentOrientation
               containerOrientation:(long long)containerOrientation
                      hostRequester:(id)hostRequester;
- (void)addOverlayView:(id)view withPriority:(long long)priority;
- (void)removeOverlayView:(id)view withPriority:(long long)priority;
@end

static const void *kADSceneOverlayKey7326=&kADSceneOverlayKey7326;
static unsigned gColdGeneration7326=0;
static BOOL gColdActive7326=NO;
static double gFirstOverlayAt7326=0.0;

static NSString * const kADSBLaunchProbePath7326=@"/var/mobile/AmazonDark-v7.326-launch-sb-probe.txt";
static dispatch_queue_t ADSBProbeQueue7326(void){
    static dispatch_queue_t q; static dispatch_once_t once;
    dispatch_once(&once,^{q=dispatch_queue_create("com.colindavidr.amazondark.launchprobe.sb",DISPATCH_QUEUE_SERIAL);});
    return q;
}
static NSString *ADSBRect7326(CGRect r){
    return [NSString stringWithFormat:@"%.1f,%.1f %.1fx%.1f",r.origin.x,r.origin.y,r.size.width,r.size.height];
}
static void ADSBProbeLog7326(NSString *event,NSString *detail){
    @try {
        NSTimeInterval wall=[NSDate timeIntervalSinceReferenceDate],up=NSProcessInfo.processInfo.systemUptime;
        NSString *line=[NSString stringWithFormat:@"%.6f up=%.6f pid=%d main=%d event=%@ %@\n",wall,up,NSProcessInfo.processInfo.processIdentifier,[NSThread isMainThread]?1:0,event?:@"?",detail?:@""];
        dispatch_async(ADSBProbeQueue7326(),^{ @autoreleasepool { @try {
            NSData *d=[line dataUsingEncoding:NSUTF8StringEncoding];
            NSFileManager *fm=[NSFileManager defaultManager];
            if(![fm fileExistsAtPath:kADSBLaunchProbePath7326])
                [fm createFileAtPath:kADSBLaunchProbePath7326 contents:nil attributes:@{NSFilePosixPermissions:@0666}];
            NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:kADSBLaunchProbePath7326];
            if(h){[h seekToEndOfFile];[h writeData:d];[h closeFile];}
        } @catch(__unused NSException *e){} }});
    } @catch(__unused NSException *e){}
}

static BOOL ADSBEnabled7326(void){
    @try {
        for(NSString *path in @[@"/var/jb/var/mobile/Library/Preferences/com.colindavidr.amazondark.plist",@"/var/mobile/Library/Preferences/com.colindavidr.amazondark.plist"]){
            NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:path];
            if(d){id value=d[@"enabled"];return value?[value boolValue]:YES;}
        }
    } @catch(__unused NSException *e){}
    return YES;
}
static NSInteger ADAmazonPID7326(void){
    @try {
        Class controller=objc_getClass("SBApplicationController");
        if(!controller||![controller respondsToSelector:@selector(sharedInstance)])return 0;
        id shared=[controller performSelector:@selector(sharedInstance)];
        if(!shared||![shared respondsToSelector:@selector(applicationWithBundleIdentifier:)])return 0;
        id app=[shared performSelector:@selector(applicationWithBundleIdentifier:) withObject:kAMZ];
        if(!app)return 0;
        for(NSString *path in @[@"processState.pid",@"processState.processIdentifier",@"process.pid",@"process.processIdentifier",@"pid",@"processIdentifier"]){
            @try {
                id value=[app valueForKeyPath:path];
                if([value respondsToSelector:@selector(integerValue)]){
                    NSInteger pid=[value integerValue]; if(pid>0)return pid;
                }
            } @catch(__unused NSException *e){}
        }
    } @catch(__unused NSException *e){}
    return 0;
}
static BOOL ADAmazonProcessRunning7326(void){
    @try {
        Class controller=objc_getClass("SBApplicationController");
        if(!controller||![controller respondsToSelector:@selector(sharedInstance)])return NO;
        id shared=[controller performSelector:@selector(sharedInstance)];
        if(!shared||![shared respondsToSelector:@selector(applicationWithBundleIdentifier:)])return NO;
        id app=[shared performSelector:@selector(applicationWithBundleIdentifier:) withObject:kAMZ];
        if(!app)return NO;
        id state=nil; @try {state=[app valueForKey:@"processState"];} @catch(__unused NSException *e){}
        if(state&&[state respondsToSelector:@selector(isRunning)]){
            id value=[state valueForKey:@"isRunning"];
            if([value respondsToSelector:@selector(boolValue)])return [value boolValue];
        }
    } @catch(__unused NSException *e){}
    return NO;
}
static NSString *ADBundleForIconView7326(id iconView){
    if(!iconView)return nil;
    for(NSString *path in @[@"applicationBundleIdentifier",@"applicationBundleIdentifierForShortcuts",@"icon.applicationBundleID",@"icon.applicationBundleIdentifier",@"icon.application.bundleIdentifier"]){
        @try {id value=[iconView valueForKeyPath:path];if([value isKindOfClass:[NSString class]]&&[value length])return value;} @catch(__unused NSException *e){}
    }
    return nil;
}
static NSString *ADBundleForSceneHandle7326(id handle){
    if(!handle)return nil;
    for(NSString *path in @[@"application.bundleIdentifier",@"application.bundleID",@"bundleIdentifier",@"clientProcess.identity.embeddedApplicationIdentifier"]){
        @try {id value=[handle valueForKeyPath:path];if([value isKindOfClass:[NSString class]]&&[value length])return value;} @catch(__unused NSException *e){}
    }
    return nil;
}
static UIImage *ADSplashImage7326(void){
    static UIImage *image; static dispatch_once_t once;
    dispatch_once(&once,^{
        image=[UIImage imageWithContentsOfFile:@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png"];
        if(!image)image=[UIImage imageWithContentsOfFile:@"/Library/Application Support/AmazonDark/splash-logo.png"];
    });
    return image;
}
static NSHashTable<SBDeviceApplicationSceneView *> *ADAmazonScenes7326(void){
    static NSHashTable *scenes; static dispatch_once_t once;
    dispatch_once(&once,^{scenes=[NSHashTable weakObjectsHashTable];});
    return scenes;
}

static UIView *ADSceneOverlay7326(SBDeviceApplicationSceneView *scene){
    return scene?(UIView *)objc_getAssociatedObject(scene,kADSceneOverlayKey7326):nil;
}
static void ADRemoveSceneOverlay7326(SBDeviceApplicationSceneView *scene,BOOL animated){
    @try {
        UIView *overlay=ADSceneOverlay7326(scene); if(!overlay)return;
        objc_setAssociatedObject(scene,kADSceneOverlayKey7326,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        void (^remove)(void)=^{
            @try {
                if([scene respondsToSelector:@selector(removeOverlayView:withPriority:)])
                    [scene removeOverlayView:overlay withPriority:kOverlayPriority7326];
                else [overlay removeFromSuperview];
            } @catch(__unused NSException *e){@try{[overlay removeFromSuperview];}@catch(__unused NSException *ignored){}}
        };
        if(animated){
            [UIView animateWithDuration:kCoverFade7326 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseOut animations:^{overlay.alpha=0.0;} completion:^(__unused BOOL finished){remove();}];
        } else remove();
        ADSBProbeLog7326(@"overlay.remove",[NSString stringWithFormat:@"scene=%p overlay=%p animated=%d",scene,overlay,animated?1:0]);
    } @catch(__unused NSException *e){}
}
static void ADRemoveAllOverlays7326(BOOL animated){
    NSArray *scenes=ADAmazonScenes7326().allObjects;
    for(SBDeviceApplicationSceneView *scene in scenes)ADRemoveSceneOverlay7326(scene,animated);
    gColdActive7326=NO;
}
static void ADAttachSceneOverlay7326(SBDeviceApplicationSceneView *scene,NSString *reason){
    if(!scene||!gColdActive7326||!ADSBEnabled7326()||ADSceneOverlay7326(scene))return;
    @try {
        Class wrapperClass=objc_getClass("SBDeviceApplicationSceneOverlayBasicWrapperView");
        if(!wrapperClass){ADSBProbeLog7326(@"overlay.skip",@"native-wrapper-class-absent");return;}
        SBDeviceApplicationSceneOverlayBasicWrapperView *overlay=[[wrapperClass alloc] initWithCounterRotationRequirement:NO];
        if(!overlay){ADSBProbeLog7326(@"overlay.skip",@"native-wrapper-init-failed");return;}
        overlay.frame=scene.bounds;
        overlay.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        overlay.backgroundColor=[UIColor blackColor];
        overlay.opaque=YES;
        overlay.userInteractionEnabled=NO;
        overlay.shouldLayoutOverlayImmediatelyForContainerGeometryChange=YES;

        UIImage *splash=ADSplashImage7326();
        if(splash){
            UIImageView *logo=[[UIImageView alloc] initWithImage:splash];
            logo.contentMode=UIViewContentModeScaleAspectFit;
            logo.translatesAutoresizingMaskIntoConstraints=NO;
            [overlay addSubview:logo];
            CGFloat referenceWidth=MAX(CGRectGetWidth(scene.bounds),CGRectGetWidth(UIScreen.mainScreen.bounds));
            CGFloat logoWidth=MAX(referenceWidth,200.0)*0.62;
            CGFloat logoHeight=logoWidth*(splash.size.height/MAX(splash.size.width,1.0));
            [NSLayoutConstraint activateConstraints:@[[logo.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],[logo.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor],[logo.widthAnchor constraintEqualToConstant:logoWidth],[logo.heightAnchor constraintEqualToConstant:logoHeight]]];
        }

        objc_setAssociatedObject(scene,kADSceneOverlayKey7326,overlay,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [scene addOverlayView:overlay withPriority:kOverlayPriority7326];
        if(gFirstOverlayAt7326<=0.0)gFirstOverlayAt7326=CFAbsoluteTimeGetCurrent();
        ADSBProbeLog7326(@"overlay.attach",[NSString stringWithFormat:@"reason=%@ scene=%p win=%p overlay=%p frame=%@ gen=%u",reason?:@"?",scene,scene.window,overlay,ADSBRect7326(scene.bounds),gColdGeneration7326]);
    } @catch(__unused NSException *e){
        objc_setAssociatedObject(scene,kADSceneOverlayKey7326,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADSBProbeLog7326(@"overlay.error",[NSString stringWithFormat:@"reason=%@ scene=%p",reason?:@"?",scene]);
    }
}
static void ADRegisterAmazonScene7326(SBDeviceApplicationSceneView *scene,id handle,NSString *reason){
    NSString *bundle=ADBundleForSceneHandle7326(handle);
    if(!scene||![bundle isEqualToString:kAMZ])return;
    [ADAmazonScenes7326() addObject:scene];
    ADSBProbeLog7326(@"scene.register",[NSString stringWithFormat:@"reason=%@ scene=%p win=%p active=%d frame=%@",reason?:@"?",scene,scene.window,gColdActive7326?1:0,ADSBRect7326(scene.bounds)]);
    if(gColdActive7326)ADAttachSceneOverlay7326(scene,@"scene-created-during-cold-launch");
}
static void ADArmColdLaunch7326(NSString *reason){
    ADRemoveAllOverlays7326(NO);
    gColdActive7326=YES;
    gFirstOverlayAt7326=0.0;
    unsigned generation=++gColdGeneration7326;
    NSArray *scenes=ADAmazonScenes7326().allObjects;
    ADSBProbeLog7326(@"cold.arm",[NSString stringWithFormat:@"reason=%@ gen=%u registeredScenes=%lu",reason?:@"?",generation,(unsigned long)scenes.count]);
    for(SBDeviceApplicationSceneView *scene in scenes)ADAttachSceneOverlay7326(scene,@"pre-original-icon-tap");

    // An icon tap normally creates/reuses its scene immediately. If no exact Amazon
    // scene appears, discard the arm instead of affecting a later unrelated launch.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(3.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if(gColdActive7326&&generation==gColdGeneration7326){
            BOOL hasOverlay=NO;
            for(SBDeviceApplicationSceneView *scene in ADAmazonScenes7326().allObjects){if(ADSceneOverlay7326(scene)){hasOverlay=YES;break;}}
            if(!hasOverlay){gColdActive7326=NO;ADSBProbeLog7326(@"cold.arm.expire",[NSString stringWithFormat:@"gen=%u",generation]);}
        }
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(kCoverHardCap7326*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if(gColdActive7326&&generation==gColdGeneration7326){
            ADSBProbeLog7326(@"overlay.hardcap",[NSString stringWithFormat:@"gen=%u",generation]);
            ADRemoveAllOverlays7326(NO);
        }
    });
}

static void (*ADOrigIconTap7326)(id,SEL,id);
static void ADHookIconTap7326(id self,SEL _cmd,id gesture){
    NSString *bundle=ADBundleForIconView7326(self);
    NSInteger pid=ADAmazonPID7326();
    NSInteger state=[gesture respondsToSelector:@selector(state)]?(NSInteger)[gesture state]:-1;
    BOOL amazon=[(bundle?:@"") isEqualToString:kAMZ];
    BOOL running=ADAmazonProcessRunning7326();
    BOOL cold=amazon&&ADSBEnabled7326()&&state==UIGestureRecognizerStateEnded&&(pid<=0||!running);
    if(amazon)ADSBProbeLog7326(@"icon.tap",[NSString stringWithFormat:@"view=%p bid=%@ state=%ld pid=%ld running=%d cold=%d",self,bundle,(long)state,(long)pid,running?1:0,cold?1:0]);
    if(cold)ADArmColdLaunch7326(@"verified-cold-icon-tap");
    if(ADOrigIconTap7326)ADOrigIconTap7326(self,_cmd,gesture);
}
static void ADInstallTapHook7326(void){
    @try {
        Class cls=objc_getClass("SBIconView"); SEL selector=NSSelectorFromString(@"tapGestureDidChange:");
        Method method=cls?class_getInstanceMethod(cls,selector):NULL;
        if(method){MSHookMessageEx(cls,selector,(IMP)ADHookIconTap7326,(IMP *)&ADOrigIconTap7326);ADSBProbeLog7326(@"hook.install",@"SBIconView tapGestureDidChange:");}
        else ADSBProbeLog7326(@"hook.skip",@"SBIconView tapGestureDidChange: absent");
    } @catch(__unused NSException *e){}
}

%hook SBDeviceApplicationSceneView
- (instancetype)initWithSceneHandle:(id)sceneHandle
                      referenceSize:(CGSize)referenceSize
                 contentOrientation:(long long)contentOrientation
               containerOrientation:(long long)containerOrientation
                      hostRequester:(id)hostRequester {
    SBDeviceApplicationSceneView *scene=%orig(sceneHandle,referenceSize,contentOrientation,containerOrientation,hostRequester);
    @try {ADRegisterAmazonScene7326(scene,sceneHandle,@"designated-init");} @catch(__unused NSException *e){}
    return scene;
}
- (void)invalidate {
    @try {
        if([ADAmazonScenes7326() containsObject:self]){
            ADRemoveSceneOverlay7326(self,NO);
            [ADAmazonScenes7326() removeObject:self];
            ADSBProbeLog7326(@"scene.invalidate",[NSString stringWithFormat:@"scene=%p",self]);
        }
    } @catch(__unused NSException *e){}
    %orig;
}
%end

%ctor {
    ADSBProbeLog7326(@"ctor",[NSString stringWithFormat:@"enabled=%d",ADSBEnabled7326()?1:0]);
    ADInstallTapHook7326();
    if(!ADSBEnabled7326())return;
    @try {
        static int readyToken=0;
        notify_register_dispatch("com.colindavidr.amazondark.ready",&readyToken,dispatch_get_main_queue(),^(__unused int token){
            @try {
                if(!gColdActive7326){ADSBProbeLog7326(@"ready.notify",@"active=0");return;}
                BOOL hasOverlay=NO;
                for(SBDeviceApplicationSceneView *scene in ADAmazonScenes7326().allObjects){if(ADSceneOverlay7326(scene)){hasOverlay=YES;break;}}
                if(!hasOverlay){gColdActive7326=NO;ADSBProbeLog7326(@"ready.notify",@"active=1 overlay=0");return;}
                double shown=gFirstOverlayAt7326>0.0?(CFAbsoluteTimeGetCurrent()-gFirstOverlayAt7326):0.0;
                double minimumRemaining=shown<kCoverMinimum7326?(kCoverMinimum7326-shown):0.0;
                double wait=MAX(minimumRemaining,kReadySettle7326);
                unsigned generation=gColdGeneration7326;
                ADSBProbeLog7326(@"ready.notify",[NSString stringWithFormat:@"overlay=1 shown=%.3f wait=%.3f gen=%u",shown,wait,generation]);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(wait*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                    if(gColdActive7326&&generation==gColdGeneration7326){
                        ADSBProbeLog7326(@"ready.dismiss",[NSString stringWithFormat:@"gen=%u",generation]);
                        ADRemoveAllOverlays7326(YES);
                    }
                });
            } @catch(__unused NSException *e){}
        });
    } @catch(__unused NSException *e){}
    @autoreleasepool {@try{%init;}@catch(__unused NSException *e){}}
}
