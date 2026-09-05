// AmazonDarkSB.xm — v7.331, v7.307 baseline plus launch-artwork substitution.
// SpringBoard-side dark cover for the Amazon Shopping launch screen.
//
// Injected ONLY into com.apple.springboard (AmazonDarkSB.plist). Amazon's white
// LaunchScreen is drawn by the render server before Amazon's process is alive,
// so it can't be themed from inside Amazon. v7.307's scene-attached cover and
// its lifetime remain intact. The addition below supplies dark artwork at the
// launch-image source, even when the existing cover's cold/warm test skips it.
//
// SAFETY (runs in SpringBoard => a fault here is safe mode):
//   - every entry point is @try/@catch guarded;
//   - the event-driven cover has an absolute hard cap, so it can never remain stuck;
//   - only ever triggered by a scene whose bundle id is exactly Amazon.

#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/runtime.h>
#import <unistd.h>
#import <math.h>

static NSString * const kAMZ      = @"com.amazon.Amazon";
static NSString * const kDefaults = @"com.colindavidr.amazondark";
static const NSTimeInterval kCoverFade    = 0.55; // lift animation
static const NSTimeInterval kReadySettle   = 0.40; // v7.116: keep the cover fully opaque for
                                                  // a short post-ready settle window. If the
                                                  // ready event arrives early, the existing
                                                  // 1.40 s minimum absorbs this completely.
static const NSTimeInterval kCoverHardCap = 20.0; // absolute max on screen

@interface SBSceneView : UIView
@end

static double gPresentAt;

static BOOL ADSBEnabled(void) {
    @try {
        NSString *path=[@"/var/jb/var/mobile/Library/Preferences" stringByAppendingPathComponent:
                        [kDefaults stringByAppendingPathExtension:@"plist"]];
        id value=[NSDictionary dictionaryWithContentsOfFile:path][@"enabled"];
        return value ? [value boolValue] : YES;
    } @catch (__unused NSException *e) { return YES; }
}

static NSString *ADSceneBundleId(UIView *v) {
    @try {
        id val=[v valueForKeyPath:@"sceneHandle.application.bundleIdentifier"];
        return [val isKindOfClass:[NSString class]] ? val : nil;
    } @catch (__unused NSException *e) { return nil; }
}

static void ADDismissCover(void);
static UIView *gCoverOverlay;
static SBSceneView *gCoverHost;
static const void *kCoveredKey = &kCoveredKey;
static unsigned gCoverGen;

// YES when Amazon already has a running process -- i.e. this is a resume, not a
// cold launch. Nothing here is required to exist; unknown means "cover it".
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

static UIImage *ADSplashImage7191(void) {
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        image=[UIImage imageWithContentsOfFile:@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png"];
    });
    return image;
}

// The iOS 17 interfaces expose launch images separately from scene snapshots.
// Match the explicit launch-image provider, never a guessed numeric contentType,
// image brightness, process-state flag, or every Amazon snapshot indiscriminately.
@interface XBApplicationSnapshot : NSObject
@property(nonatomic,readonly) id containerIdentity;
@property(nonatomic,readonly,copy) NSString *dataProviderClassName;
@end
@interface SBDeviceApplicationSceneViewPlaceholderContentViewProvider : NSObject
@end

static void ADLaunchLog7331(NSString *event,NSString *detail){
    @try {
        static dispatch_queue_t queue; static dispatch_once_t once;
        dispatch_once(&once,^{queue=dispatch_queue_create("com.colindavidr.amazondark.launch-artwork",DISPATCH_QUEUE_SERIAL);});
        NSString *line=[NSString stringWithFormat:@"%.6f up=%.6f pid=%d event=%@ %@\n",
            CFAbsoluteTimeGetCurrent(),NSProcessInfo.processInfo.systemUptime,getpid(),event,detail?:@""];
        dispatch_async(queue,^{@autoreleasepool{@try{
            NSString *path=@"/var/mobile/AmazonDark-v7.331-launch-sb-probe.txt";
            NSFileManager *fm=NSFileManager.defaultManager;
            if(![fm fileExistsAtPath:path])[fm createFileAtPath:path contents:nil attributes:@{NSFilePosixPermissions:@0666}];
            NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:path];
            if(file){[file seekToEndOfFile];[file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];[file closeFile];}
        }@catch(__unused NSException *e){}}});
    }@catch(__unused NSException *e){}
}

// UIKit image drawing uses a local context and works for background snapshot
// fetches too. Cache only four rendered sizes, not app screenshots or live views.
static UIImage *ADLaunchArtwork7331(CGSize size,CGFloat scale){
    if(!isfinite(size.width)||!isfinite(size.height)||!isfinite(scale)||
       size.width<1||size.height<1||scale<1||scale>4||size.width*size.height*scale*scale>16000000)return nil;
    @try {
        static NSCache *cache; static dispatch_once_t once;
        dispatch_once(&once,^{cache=[NSCache new];cache.countLimit=4;cache.totalCostLimit=32*1024*1024;});
        NSString *key=[NSString stringWithFormat:@"%.3f/%.3f/%.3f",size.width,size.height,scale];
        UIImage *cached=[cache objectForKey:key]; if(cached)return cached;
        UIImage *logo=ADSplashImage7191(); if(!logo)return nil;
        UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat preferredFormat];
        format.opaque=YES;format.scale=scale;
        UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
        UIImage *image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){
            [[UIColor blackColor] setFill];[context fillRect:(CGRect){CGPointZero,size}];
            CGFloat width=size.width*0.62,height=width*logo.size.height/MAX(logo.size.width,1.0);
            [logo drawInRect:CGRectMake((size.width-width)/2,(size.height-height)/2,width,height)];
        }];
        if(image)[cache setObject:image forKey:key cost:(NSUInteger)(size.width*size.height*scale*scale*4)];
        return image;
    }@catch(__unused NSException *e){return nil;}
}

static UIImage *ADLaunchSnapshotImage7331(XBApplicationSnapshot *snapshot,UIImage *original){
    @try {
        id bundle=[snapshot.containerIdentity valueForKey:@"bundleIdentifier"];
        if(![bundle isEqual:kAMZ])return original;
        NSString *provider=snapshot.dataProviderClassName;
        BOOL launch=[provider isEqualToString:@"XBLaunchImageDataProvider"];
        // Log once per snapshot identity; no file paths, snapshot pixels or user text.
        static const char logged=0;
        if(!objc_getAssociatedObject(snapshot,&logged)){
            objc_setAssociatedObject(snapshot,&logged,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            ADLaunchLog7331(@"snapshot.source",[NSString stringWithFormat:@"provider=%@ launch=%d",provider?:@"nil",launch]);
        }
        if(!launch||![original isKindOfClass:UIImage.class])return original;
        UIImage *dark=ADLaunchArtwork7331(original.size,original.scale);
        ADLaunchLog7331(dark?@"snapshot.dark":@"snapshot.fallback",NSStringFromCGSize(original.size));
        return dark?:original;
    }@catch(__unused NSException *e){ADLaunchLog7331(@"snapshot.error",nil);return original;}
}

%hook XBApplicationSnapshot
- (UIImage *)imageForInterfaceOrientation:(long long)orientation {
    UIImage *original=%orig;
    return ADLaunchSnapshotImage7331(self,original);
}
- (UIImage *)imageForInterfaceOrientation:(long long)orientation generationOptions:(unsigned long long)options {
    UIImage *original=%orig;
    return ADLaunchSnapshotImage7331(self,original);
}
- (UIImage *)cachedImageForInterfaceOrientation:(long long)orientation {
    UIImage *original=%orig;
    return ADLaunchSnapshotImage7331(self,original);
}
%end

// A missing disk launch snapshot can be supplied by the launch XIB instead.
// Replace only that detached return value; never insert/remove scene children
// inside willMoveToWindow:, or alter the provider's saved-user-content branch.
%hook SBDeviceApplicationSceneViewPlaceholderContentViewProvider
- (id)_loadLiveXIBViewForApplication:(id)application {
    id original=%orig;
    @try {
        if(![[application valueForKey:@"bundleIdentifier"] isEqual:kAMZ])return original;
        if(![original isKindOfClass:UIView.class]){ADLaunchLog7331(@"xib.fallback",@"reason=no-view");return original;}
        UIView *source=(UIView *)original;
        if(source.superview||source.window){ADLaunchLog7331(@"xib.fallback",@"reason=attached");return original;}
        UIImage *image=ADLaunchArtwork7331(source.bounds.size,source.contentScaleFactor);
        if(!image){ADLaunchLog7331(@"xib.fallback",@"reason=no-artwork");return original;}
        UIImageView *replacement=[[UIImageView alloc] initWithImage:image];
        replacement.frame=source.frame;replacement.bounds=source.bounds;
        replacement.autoresizingMask=source.autoresizingMask;
        replacement.contentMode=UIViewContentModeScaleToFill;
        replacement.userInteractionEnabled=NO;
        ADLaunchLog7331(@"xib.dark",NSStringFromCGSize(source.bounds.size));
        return replacement;
    }@catch(__unused NSException *e){ADLaunchLog7331(@"xib.error",nil);return original;}
}
%end

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

        UIImage *splash = ADSplashImage7191();
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
        gCoverHost = (SBSceneView *)host;
        unsigned myGen = ++gCoverGen;

        gPresentAt = CFAbsoluteTimeGetCurrent();

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoverHardCap * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            @try { if (gCoverOverlay && myGen == gCoverGen){ UIView *x = gCoverOverlay; gCoverOverlay = nil;
                       SBSceneView *h=gCoverHost; gCoverHost=nil; if(h)objc_setAssociatedObject(h,kCoveredKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                       [x removeFromSuperview]; } }
            @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

static void ADDismissCover(void) {
    @try {
        if (!gCoverOverlay) return;
        UIView *ov = gCoverOverlay; gCoverOverlay = nil;
        SBSceneView *h=gCoverHost; gCoverHost=nil; if(h)objc_setAssociatedObject(h,kCoveredKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [UIView animateWithDuration:kCoverFade animations:^{ ov.alpha = 0.0; }
                         completion:^(BOOL f){ @try { [ov removeFromSuperview]; }
                                               @catch (__unused NSException *e) {} }];
    } @catch (__unused NSException *e) {}
}

%hook SBSceneView
- (void)didMoveToWindow {
    %orig;
    @try {
        if (!self.window) return;

        NSString *bid = ADSceneBundleId(self);
        if (![bid isEqualToString:kAMZ]) return;

        // Cold-launch cover only. If Amazon already has a live/suspended process,
        // reopening it is a normal foreground resume and must not replay our launch screen.
        BOOL alive = ADAmazonProcessAlive();
        if (alive) return;

        // One active cover per cold launch. The marker is cleared when the cover leaves,
        // allowing a later true cold launch to receive the cover again.
        BOOL already = (objc_getAssociatedObject(self, kCoveredKey) != nil);
        if (already) return;
        objc_setAssociatedObject(self, kCoveredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADAttachCoverToScene(self);
    } @catch (__unused NSException *e) {}
}
%end



%ctor {
    if(!ADSBEnabled())return;
    ADLaunchLog7331(@"ctor",[NSString stringWithFormat:@"version=7.331 base=4bbbbd9 snapshotClass=%d xibClass=%d",
        objc_getClass("XBApplicationSnapshot")!=Nil,
        objc_getClass("SBDeviceApplicationSceneViewPlaceholderContentViewProvider")!=Nil]);

    // Event-driven dismissal: the app posts readiness after its first dark composite.
    // The independent hard cap above is a SpringBoard safety invariant only.
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
