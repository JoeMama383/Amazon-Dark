// AmazonDarkSB.xm — v7.334 snapshot-scoped warm handoff
//
// A stock launch image/snapshot is owned by iOS before Amazon can draw. The old
// SBSceneView -didMoveToWindow path attached our cover only after the scene had
// entered a window, leaving one compositor frame in which the stock white image
// could win. This build uses SpringBoard's own device-scene overlay API instead:
//
//   * an Amazon icon tap pre-arms unless both process and live-scene continuity
//     prove that the launch is a genuine same-scene warm resume;
//   * SpringBoard's exact Amazon process-launch callback confirms/retains a new
//     process launch even when the old process was still alive at icon tap;
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

@interface SBApplication : NSObject
@property(nonatomic,readonly,copy) NSString *bundleIdentifier;
- (void)_processWillLaunch:(id)process;
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
// Set immediately by SBApplication -_processWillLaunch:, including when that
// callback is not delivered on SpringBoard's main thread. The next exact Amazon
// scene can therefore consume the authoritative cold decision without racing a
// queued main-thread block.
static int gAmazonProcessLaunchPending7327=0;
static NSInteger gAuthoritativeProcessPID7330=0;

// v7.334: readiness belongs to one concrete Amazon process. A global Darwin
// ready channel lets a dying/replaced Amazon process dismiss the cover that now
// belongs to its successor. Keep exactly one process-scoped subscription.
static int gReadyToken7330=0;
static NSInteger gReadyPID7330=0;
static unsigned gReadyGeneration7330=0;
static NSString * const kADSBLaunchProbePath7326=@"/var/mobile/AmazonDark-v7.334-launch-sb-probe.txt";
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


static void ADClearReadyListener7330(NSString *reason){
    int token=gReadyToken7330;
    NSInteger pid=gReadyPID7330;
    unsigned generation=gReadyGeneration7330;
    gReadyToken7330=0;
    gReadyPID7330=0;
    gReadyGeneration7330=0;
    if(token>0){
        @try { notify_cancel(token); } @catch(__unused NSException *e){}
    }
    if(token>0||pid>0){
        ADSBProbeLog7326(@"ready.listener.clear",[NSString stringWithFormat:@"reason=%@ pid=%ld token=%d gen=%u",reason?:@"?",(long)pid,token,generation]);
    }
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
static NSInteger ADPIDForSceneHandle7330(id handle){
    if(!handle)return 0;
    for(NSString *path in @[@"clientProcess.pid",@"clientProcess.processIdentifier",@"clientProcess.handle.pid",@"process.pid",@"process.processIdentifier",@"pid",@"processIdentifier"]){
        @try {
            id value=[handle valueForKeyPath:path];
            if([value respondsToSelector:@selector(integerValue)]){
                NSInteger pid=[value integerValue];
                if(pid>0)return pid;
            }
        } @catch(__unused NSException *e){}
    }
    return 0;
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
static BOOL ADHasAnySceneOverlay7327(void){
    for(SBDeviceApplicationSceneView *scene in ADAmazonScenes7326().allObjects)
        if(ADSceneOverlay7326(scene))return YES;
    return NO;
}

static void ADScheduleHardCap7330(unsigned generation){
    double elapsed=gFirstOverlayAt7326>0.0?(CFAbsoluteTimeGetCurrent()-gFirstOverlayAt7326):0.0;
    NSTimeInterval remaining=MAX(0.05,kCoverHardCap7326-MAX(0.0,elapsed));
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(remaining*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if(gColdActive7326&&generation==gColdGeneration7326){
            __atomic_store_n(&gAmazonProcessLaunchPending7327,0,__ATOMIC_RELEASE);
            __atomic_store_n(&gAuthoritativeProcessPID7330,0,__ATOMIC_RELEASE);
            ADClearReadyListener7330(@"hardcap");
            ADSBProbeLog7326(@"overlay.hardcap",[NSString stringWithFormat:@"gen=%u elapsed=%.3f",generation,CFAbsoluteTimeGetCurrent()-gFirstOverlayAt7326]);
            ADRemoveAllOverlays7326(NO);
        }
    });
}

static void ADScheduleReadyDismiss7332(NSInteger pid,unsigned generation){
    if(!gColdActive7326||generation!=gColdGeneration7326){
        ADSBProbeLog7326(@"ready.dismiss.invalidated",[NSString stringWithFormat:@"pid=%ld queuedGen=%u currentGen=%u active=%d",(long)pid,generation,gColdGeneration7326,gColdActive7326?1:0]);
        return;
    }
    BOOL hasOverlay=ADHasAnySceneOverlay7327();
    if(!hasOverlay){
        __atomic_store_n(&gAmazonProcessLaunchPending7327,0,__ATOMIC_RELEASE);
        __atomic_store_n(&gAuthoritativeProcessPID7330,0,__ATOMIC_RELEASE);
        gColdActive7326=NO;
        ADSBProbeLog7326(@"ready.notify",[NSString stringWithFormat:@"pid=%ld overlay=0 gen=%u",(long)pid,generation]);
        return;
    }
    double shown=gFirstOverlayAt7326>0.0?(CFAbsoluteTimeGetCurrent()-gFirstOverlayAt7326):0.0;
    double minimumRemaining=shown<kCoverMinimum7326?(kCoverMinimum7326-shown):0.0;
    double wait=MAX(minimumRemaining,kReadySettle7326);
    ADSBProbeLog7326(@"ready.notify",[NSString stringWithFormat:@"pid=%ld overlay=1 shown=%.3f wait=%.3f gen=%u",(long)pid,shown,wait,generation]);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(wait*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if(gColdActive7326&&generation==gColdGeneration7326){
            __atomic_store_n(&gAmazonProcessLaunchPending7327,0,__ATOMIC_RELEASE);
            __atomic_store_n(&gAuthoritativeProcessPID7330,0,__ATOMIC_RELEASE);
            ADSBProbeLog7326(@"ready.dismiss",[NSString stringWithFormat:@"pid=%ld gen=%u",(long)pid,generation]);
            ADRemoveAllOverlays7326(YES);
        } else {
            ADSBProbeLog7326(@"ready.dismiss.invalidated",[NSString stringWithFormat:@"pid=%ld queuedGen=%u currentGen=%u active=%d",(long)pid,generation,gColdGeneration7326,gColdActive7326?1:0]);
        }
    });
}

static void ADHandleReady7330(NSInteger pid,int token){
    @try {
        if(token!=gReadyToken7330||pid!=gReadyPID7330){
            ADSBProbeLog7326(@"ready.notify.stale",[NSString stringWithFormat:@"pid=%ld token=%d boundPid=%ld boundToken=%d gen=%u",(long)pid,token,(long)gReadyPID7330,gReadyToken7330,gColdGeneration7326]);
            return;
        }
        unsigned boundGeneration=gReadyGeneration7330;
        if(!gColdActive7326||boundGeneration!=gColdGeneration7326){
            ADSBProbeLog7326(@"ready.notify.stale",[NSString stringWithFormat:@"pid=%ld token=%d active=%d boundGen=%u currentGen=%u",(long)pid,token,gColdActive7326?1:0,boundGeneration,gColdGeneration7326]);
            ADClearReadyListener7330(@"stale-generation");
            return;
        }
        ADClearReadyListener7330(@"ready-received");
        ADScheduleReadyDismiss7332(pid,boundGeneration);
    } @catch(__unused NSException *e){}
}

static void ADBindReadyListener7330(NSInteger pid,NSString *reason){
    if(pid<=0){
        ADSBProbeLog7326(@"ready.listener.wait",[NSString stringWithFormat:@"reason=%@ pid=%ld gen=%u",reason?:@"?",(long)pid,gColdGeneration7326]);
        return;
    }
    if(gReadyToken7330>0&&gReadyPID7330==pid&&gReadyGeneration7330==gColdGeneration7326){
        ADSBProbeLog7326(@"ready.listener.keep",[NSString stringWithFormat:@"reason=%@ pid=%ld token=%d gen=%u",reason?:@"?",(long)pid,gReadyToken7330,gReadyGeneration7330]);
        return;
    }
    ADClearReadyListener7330(@"rebind");
    NSString *channel=[NSString stringWithFormat:@"com.colindavidr.amazondark.ready.%ld",(long)pid];
    int newToken=0;
    uint32_t status=notify_register_dispatch(channel.UTF8String,&newToken,dispatch_get_main_queue(),^(int token){
        ADHandleReady7330(pid,token);
    });
    if(status==NOTIFY_STATUS_OK&&newToken>0){
        gReadyToken7330=newToken;
        gReadyPID7330=pid;
        gReadyGeneration7330=gColdGeneration7326;
            ADSBProbeLog7326(@"ready.listener.bind",[NSString stringWithFormat:@"reason=%@ pid=%ld token=%d gen=%u channel=%@",reason?:@"?",(long)pid,newToken,gReadyGeneration7330,channel]);
    } else {
        ADSBProbeLog7326(@"ready.listener.error",[NSString stringWithFormat:@"reason=%@ pid=%ld status=%u token=%d gen=%u",reason?:@"?",(long)pid,status,newToken,gColdGeneration7326]);
        if(newToken>0)notify_cancel(newToken);
    }
}

static NSUInteger ADAmazonLiveSceneCount7328(void){
    return ADAmazonScenes7326().allObjects.count;
}
static void ADArmColdLaunch7326(NSString *reason,BOOL expireIfUnclaimed);
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
        if(gFirstOverlayAt7326<=0.0){
            gFirstOverlayAt7326=CFAbsoluteTimeGetCurrent();
            unsigned generation=gColdGeneration7326;
            // Start the fault cap when a cover actually becomes visible. A process
            // can be prewarmed long before a foreground scene exists, so timing from
            // _processWillLaunch: would discard the cover before the user's tap.
            ADScheduleHardCap7330(generation);
        }
        ADSBProbeLog7326(@"overlay.attach",[NSString stringWithFormat:@"reason=%@ scene=%p win=%p overlay=%p frame=%@ gen=%u",reason?:@"?",scene,scene.window,overlay,ADSBRect7326(scene.bounds),gColdGeneration7326]);
    } @catch(__unused NSException *e){
        objc_setAssociatedObject(scene,kADSceneOverlayKey7326,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADSBProbeLog7326(@"overlay.error",[NSString stringWithFormat:@"reason=%@ scene=%p",reason?:@"?",scene]);
    }
}
static void ADRegisterAmazonScene7326(SBDeviceApplicationSceneView *scene,id handle,NSString *reason){
    NSString *bundle=ADBundleForSceneHandle7326(handle);
    if(!scene||![bundle isEqualToString:kAMZ])return;
    NSInteger scenePID=ADPIDForSceneHandle7330(handle);

    // _processWillLaunch: is the source of truth for a new process. If its
    // callback arrived off-main and the queued arm has not run yet, consume the
    // atomic mark here before this newly-created scene can be presented.
    if(__atomic_load_n(&gAmazonProcessLaunchPending7327,__ATOMIC_ACQUIRE)&&!gColdActive7326){
        ADArmColdLaunch7326(@"authoritative-process-launch-scene",NO);
    }

    // Prewarming can announce the process before the user's icon tap. A covered
    // tap deliberately cancels the old listener; restore it here only when this
    // exact Amazon scene proves it belongs to the same authoritative PID. Never
    // bind a stale prior PID merely because SBApplication still reports it alive.
    if(__atomic_load_n(&gAmazonProcessLaunchPending7327,__ATOMIC_ACQUIRE)&&gColdActive7326&&gReadyPID7330<=0&&scenePID>0){
        NSInteger authoritativePID=__atomic_load_n(&gAuthoritativeProcessPID7330,__ATOMIC_ACQUIRE);
        if(authoritativePID<=0||authoritativePID==scenePID){
            if(authoritativePID<=0)__atomic_store_n(&gAuthoritativeProcessPID7330,scenePID,__ATOMIC_RELEASE);
            ADBindReadyListener7330(scenePID,@"authoritative-scene-process");
        } else {
            ADSBProbeLog7326(@"ready.listener.defer",[NSString stringWithFormat:@"scenePid=%ld authoritativePid=%ld gen=%u",(long)scenePID,(long)authoritativePID,gColdGeneration7326]);
        }
    }

    [ADAmazonScenes7326() addObject:scene];
    ADSBProbeLog7326(@"scene.register",[NSString stringWithFormat:@"reason=%@ scene=%p win=%p pid=%ld active=%d frame=%@",reason?:@"?",scene,scene.window,(long)scenePID,gColdActive7326?1:0,ADSBRect7326(scene.bounds)]);
    if(gColdActive7326)ADAttachSceneOverlay7326(scene,@"scene-created-during-cold-launch");
}
static void ADArmColdLaunch7326(NSString *reason,BOOL expireIfUnclaimed){
    ADClearReadyListener7330(@"cold-arm");
    ADRemoveAllOverlays7326(NO);
    gColdActive7326=YES;
    gFirstOverlayAt7326=0.0;
    unsigned generation=++gColdGeneration7326;
    NSArray *scenes=ADAmazonScenes7326().allObjects;
    ADSBProbeLog7326(@"cold.arm",[NSString stringWithFormat:@"reason=%@ gen=%u registeredScenes=%lu",reason?:@"?",generation,(unsigned long)scenes.count]);
    for(SBDeviceApplicationSceneView *scene in scenes)ADAttachSceneOverlay7326(scene,reason);

    // Only the early icon/PID-zero fallback is allowed to expire. An authoritative
    // process-launch arm survives prewarming until an Amazon foreground scene exists.
    if(expireIfUnclaimed)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(3.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if(gColdActive7326&&generation==gColdGeneration7326&&!ADHasAnySceneOverlay7327()){
            if(__atomic_load_n(&gAmazonProcessLaunchPending7327,__ATOMIC_ACQUIRE)){
                ADSBProbeLog7326(@"cold.arm.retain",[NSString stringWithFormat:@"gen=%u authoritative=1",generation]);
            } else {
                gColdActive7326=NO;
                __atomic_store_n(&gAuthoritativeProcessPID7330,0,__ATOMIC_RELEASE);
                ADClearReadyListener7330(@"cold-arm-expire");
                ADSBProbeLog7326(@"cold.arm.expire",[NSString stringWithFormat:@"gen=%u",generation]);
            }
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
    NSUInteger liveScenes=ADAmazonLiveSceneCount7328();
    BOOL processContinuous=pid>0&&running;
    // v7.334: process continuity is the warm contract. SpringBoard can transiently
    // have zero registered SBDeviceApplicationSceneView objects while the exact same
    // Amazon process survives an app-switcher/background scene reconstruction. Treating
    // that state as cold caused v7.334 to wait for a cold-only Home-ready signal that
    // never fires on an ordinary warm resume. A genuine replacement process is still
    // caught authoritatively by SBApplication -_processWillLaunch:.
    BOOL sameProcessWarm=processContinuous;
    BOOL needsCover=amazon&&ADSBEnabled7326()&&state==UIGestureRecognizerStateEnded&&!sameProcessWarm;
    if(amazon)ADSBProbeLog7326(@"icon.tap",[NSString stringWithFormat:@"view=%p bid=%@ state=%ld pid=%ld running=%d liveScenes=%lu sameProcessWarm=%d cover=%d",self,bundle,(long)state,(long)pid,running?1:0,(unsigned long)liveScenes,sameProcessWarm?1:0,needsCover?1:0]);
    if(amazon&&ADSBEnabled7326()&&state==UIGestureRecognizerStateEnded&&sameProcessWarm){
        // v7.334: v7.331's snapshot-only cover may still be present while Amazon is
        // inactive in the switcher. Tell this exact surviving process to retire it before
        // SpringBoard proceeds with the stock warm foreground transition.
        NSString *releaseChannel=[NSString stringWithFormat:@"com.colindavidr.amazondark.switcher-release.%ld",(long)pid];
        @try { notify_post(releaseChannel.UTF8String); } @catch(...) {}
        ADSBProbeLog7326(@"warm.snapshot-release",[NSString stringWithFormat:@"pid=%ld channel=%@",(long)pid,releaseChannel]);
        // A prior cold generation can still be alive while the user briefly enters the
        // app switcher. Do not let that stale generation follow a warm scene replacement.
        // Cancel it before SpringBoard continues the stock warm transition.
        if(gColdActive7326||ADHasAnySceneOverlay7327()){
            unsigned oldGeneration=gColdGeneration7326;
            ++gColdGeneration7326; // invalidate queued ready-dismiss/hard-cap closures
            ADClearReadyListener7330(@"verified-warm-icon-tap");
            __atomic_store_n(&gAmazonProcessLaunchPending7327,0,__ATOMIC_RELEASE);
            __atomic_store_n(&gAuthoritativeProcessPID7330,pid,__ATOMIC_RELEASE);
            ADRemoveAllOverlays7326(NO);
            ADSBProbeLog7326(@"warm.cancel",[NSString stringWithFormat:@"pid=%ld oldGen=%u newGen=%u liveScenes=%lu",(long)pid,oldGeneration,gColdGeneration7326,(unsigned long)liveScenes]);
        }
    } else if(needsCover){
        ADArmColdLaunch7326(@"verified-cold-icon-tap-fallback",YES);
    }
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

static NSInteger ADProcessPID7327(id process){
    for(NSString *path in @[@"pid",@"processIdentifier",@"handle.pid",@"identity.pid"]){
        @try {id value=[process valueForKeyPath:path];if([value respondsToSelector:@selector(integerValue)]){NSInteger pid=[value integerValue];if(pid>0)return pid;}} @catch(__unused NSException *e){}
    }
    return 0;
}
static void ADMarkAuthoritativeProcessLaunch7327(id process){
    NSInteger announcedPID=ADProcessPID7327(process);
    __atomic_store_n(&gAuthoritativeProcessPID7330,announcedPID,__ATOMIC_RELEASE);
    __atomic_store_n(&gAmazonProcessLaunchPending7327,1,__ATOMIC_RELEASE);
    ADSBProbeLog7326(@"process.willLaunch",[NSString stringWithFormat:@"process=%p pid=%ld main=%d currentPid=%ld gen=%u",process,(long)announcedPID,[NSThread isMainThread]?1:0,(long)ADAmazonPID7326(),gColdGeneration7326]);
    void (^arm)(void)=^{
        if(!ADSBEnabled7326())return;

        if(gColdActive7326&&ADHasAnySceneOverlay7327()){
            if(announcedPID>0&&gReadyPID7330==announcedPID&&gReadyGeneration7330==gColdGeneration7326){
                ADSBProbeLog7326(@"process.willLaunch.keep",[NSString stringWithFormat:@"pid=%ld gen=%u sameProcess=1",(long)announcedPID,gColdGeneration7326]);
                return;
            }
            // The icon tap may already have installed the correct visual overlay while
            // the old process was still alive. Keep that exact overlay, but transfer
            // ownership to the process SpringBoard has now announced. Incrementing the
            // generation invalidates any ready-dismiss or hard-cap closure queued by
            // the process being replaced without introducing a visual discontinuity.
            unsigned oldGeneration=gColdGeneration7326;
            unsigned newGeneration=++gColdGeneration7326;
            ADSBProbeLog7326(@"generation.rebase",[NSString stringWithFormat:@"pid=%ld oldGen=%u newGen=%u overlay=1",(long)announcedPID,oldGeneration,newGeneration]);
            ADBindReadyListener7330(announcedPID,@"replacement-process");
            ADScheduleHardCap7330(newGeneration);
            ADSBProbeLog7326(@"process.willLaunch.keep",[NSString stringWithFormat:@"pid=%ld oldGen=%u gen=%u sameProcess=0",(long)announcedPID,oldGeneration,newGeneration]);
            return;
        }

        ADArmColdLaunch7326(@"SBApplication-processWillLaunch",NO);
        ADBindReadyListener7330(announcedPID,@"authoritative-process-launch");
    };
    if([NSThread isMainThread])arm(); else dispatch_async(dispatch_get_main_queue(),arm);
}

%hook SBApplication
- (void)_processWillLaunch:(id)process {
    @try {if([self.bundleIdentifier isEqualToString:kAMZ]&&ADSBEnabled7326())ADMarkAuthoritativeProcessLaunch7327(process);} @catch(__unused NSException *e){}
    %orig;
}
%end

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
    ADSBProbeLog7326(@"ctor",[NSString stringWithFormat:@"enabled=%d processScopedReady=1",ADSBEnabled7326()?1:0]);
    ADInstallTapHook7326();
    if(!ADSBEnabled7326())return;
    @autoreleasepool {@try{%init;}@catch(__unused NSException *e){}}
}
