// AmazonDarkSB.xm — v7.382, cold-artwork only; no unscoped live-XIB replacement.
// UI baseline: exact v7.307 (4bbbbd9). Injected only into SpringBoard.
// Replace only positively identified Amazon snapshot launch resources. Saved SceneContent
// and live views pass through unchanged. The generic scene placeholder/XIB provider is
// read-only observed only while an explicit transition probe is armed; its return is untouched.
// No scene cover, PID/cold classification, ready listener, deadline, minimum duration,
// animation override, warm/switcher handler, or snapshot deletion.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <unistd.h>
#import <math.h>
#import <string.h>
#import <ctype.h>

static NSString * const kAMZ = @"com.amazon.Amazon";
static NSString * const kDefaults = @"com.colindavidr.amazondark";

static BOOL ADSBEnabled(void) {
    @try {
        NSString *path=[@"/var/jb/var/mobile/Library/Preferences" stringByAppendingPathComponent:
                        [kDefaults stringByAppendingPathExtension:@"plist"]];
        id value=[NSDictionary dictionaryWithContentsOfFile:path][@"enabled"];
        return value ? [value boolValue] : YES;
    } @catch (__unused NSException *e) { return YES; }
}

static UIImage *ADSplashImage7191(void) {
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Called only by the artwork renderer, never by the dylib constructor.
        // Catch HERE: exceptions escaping dispatch_once terminate the process
        // before an outer caller's catch can recover (v7.337 crash report).
        @try {
            image=[UIImage imageWithContentsOfFile:@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png"];
        } @catch (__unused NSException *e) { image=nil; }
    });
    return image;
}

// v7.331's device probe proves dataProviderClassName may be nil. Select the
// persisted GeneratedDefault/Default kind instead; saved SceneContent is never
// modified. No image recognition, process classification or new lifecycle code.
@interface XBApplicationSnapshot : NSObject
@property(nonatomic,readonly) id containerIdentity;
@property(nonatomic,readonly,copy) NSString *dataProviderClassName;
@property(nonatomic,readonly) long long contentType;
@property(nonatomic,readonly,copy) NSString *launchInterfaceIdentifier;
@property(nonatomic,readonly) BOOL hasProtectedContent;
@property(nonatomic,readonly) id generationContext;
@property(nonatomic,readonly) CGSize referenceSize;
@property(nonatomic,readonly) CGFloat imageScale;
- (NSString *)descriptionWithoutVariants;
@end
@interface XBApplicationSnapshotManifestImpl : NSObject @end
@interface XBApplicationSnapshotImage : UIImage @end
@interface SBDeviceApplicationSceneViewPlaceholderContentViewProvider : NSObject @end
static const char kADGeneratedLaunch7337=0;

static BOOL ADLaunchProbeArmed7351(void){
    // Explicit NewTerm helper marker only. Normal launches pay one cheap existence check
    // at each diagnostic site and perform no formatting, queue creation, or log-file writes.
    static const char *path="/var/mobile/AmazonDark-launch-probe.arm";
    if(access(path,R_OK)!=0)return NO;
    @try {
        NSString *s=[NSString stringWithContentsOfFile:@"/var/mobile/AmazonDark-launch-probe.arm" encoding:NSUTF8StringEncoding error:nil];
        NSTimeInterval expiry=s.doubleValue,now=NSDate.date.timeIntervalSince1970;
        if(isfinite(expiry)&&expiry>now&&expiry<=now+600.0)return YES;
        unlink(path);
    } @catch(...) {}
    return NO;
}
static void ADLaunchLog7337(NSString *event,NSString *detail){
    if(!ADLaunchProbeArmed7351())return;
    @try {
        static dispatch_queue_t queue; static dispatch_once_t once;
        dispatch_once(&once,^{queue=dispatch_queue_create("com.colindavidr.amazondark.launch-artwork",DISPATCH_QUEUE_SERIAL);});
        NSString *line=[NSString stringWithFormat:@"%.6f up=%.6f pid=%d event=%@ %@\n",
            CFAbsoluteTimeGetCurrent(),NSProcessInfo.processInfo.systemUptime,getpid(),event,detail?:@""];
        dispatch_async(queue,^{@autoreleasepool{@try{
            NSString *path=@"/var/mobile/AmazonDark-v7.382-launch-sb-probe.txt";
            NSFileManager *fm=NSFileManager.defaultManager;
            if(![fm fileExistsAtPath:path])[fm createFileAtPath:path contents:nil attributes:@{NSFilePosixPermissions:@0666}];
            NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:path];
            if(file){[file seekToEndOfFile];[file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];[file closeFile];}
        }@catch(__unused NSException *e){}}});
    }@catch(__unused NSException *e){}
}


// Probe-only formatting for the generic scene-placeholder return. This never
// authorizes replacement and is called only while the explicit transition arm exists.
static NSString *ADProbeColor7379(UIColor *color){
    if(!color)return @"nil";
    @try {
        CGFloat r=0,g=0,b=0,a=0,w=0;
        if([color getRed:&r green:&g blue:&b alpha:&a])
            return [NSString stringWithFormat:@"%.3f,%.3f,%.3f,%.3f",r,g,b,a];
        if([color getWhite:&w alpha:&a])
            return [NSString stringWithFormat:@"%.3f,%.3f,%.3f,%.3f",w,w,w,a];
    } @catch(__unused NSException *e){}
    return @"unresolved";
}
static void ADObservePlaceholder7379(id application,id original){
    if(!ADLaunchProbeArmed7351())return;
    @try {
        NSString *bundle=nil;
        @try { bundle=[application valueForKey:@"bundleIdentifier"]; } @catch(__unused NSException *e){}
        if(![bundle isEqual:kAMZ])return;
        UIView *root=[original isKindOfClass:UIView.class]?(UIView *)original:nil;
        if(!root){ADLaunchLog7337(@"xib.observe",@"return=nil-or-nonview");return;}
        NSMutableArray *parts=[NSMutableArray array];
        NSMutableArray *queue=[NSMutableArray arrayWithObject:root];
        NSUInteger visited=0;
        while(queue.count&&visited++<24){
            UIView *v=queue.firstObject;[queue removeObjectAtIndex:0];
            UIColor *layerColor=v.layer.backgroundColor?[UIColor colorWithCGColor:v.layer.backgroundColor]:nil;
            [parts addObject:[NSString stringWithFormat:@"d=%lu cls=%@ f=%@ b=%@ bg=%@ lbg=%@ a=%.3f h=%d sub=%lu",
                (unsigned long)visited-1,NSStringFromClass(v.class),NSStringFromCGRect(v.frame),NSStringFromCGRect(v.bounds),
                ADProbeColor7379(v.backgroundColor),ADProbeColor7379(layerColor),v.alpha,v.hidden?1:0,(unsigned long)v.subviews.count]];
            if(queue.count<24&&v.subviews.count)[queue addObjectsFromArray:v.subviews];
        }
        ADLaunchLog7337(@"xib.observe",[parts componentsJoinedByString:@" | "]);
    } @catch(__unused NSException *e){ADLaunchLog7337(@"xib.observe.error",nil);}
}

// UIKit image drawing uses a local context and works for background snapshot
// fetches too. Cache only four rendered sizes, not app screenshots or live views.
static UIImage *ADLaunchArtwork7337(CGSize size,CGFloat scale){
    if(!isfinite(size.width)||!isfinite(size.height)||!isfinite(scale)||
       size.width<1||size.height<1||scale<1||scale>4||size.width*size.height*scale*scale>16000000)return nil;
    @try {
        static NSCache *cache; static dispatch_once_t once;
        dispatch_once(&once,^{cache=[NSCache new];cache.countLimit=4;cache.totalCostLimit=32*1024*1024;});
        NSString *key=[NSString stringWithFormat:@"%.3f/%.3f/%.3f",size.width,size.height,scale];
        UIImage *cached=[cache objectForKey:key]; if(cached)return cached;
        UIImage *logo=ADSplashImage7191();
        UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat preferredFormat];
        format.opaque=YES;format.scale=scale;
        format.preferredRange=UIGraphicsImageRendererFormatRangeStandard;
        UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
        UIImage *image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){
            [[UIColor blackColor] setFill];[context fillRect:(CGRect){CGPointZero,size}];
            if(logo){
                CGFloat width=size.width*0.62,height=width*logo.size.height/MAX(logo.size.width,1.0);
                [logo drawInRect:CGRectMake((size.width-width)/2,(size.height-height)/2,width,height)];
            }
        }];
        if(image)[cache setObject:image forKey:key cost:(NSUInteger)(size.width*size.height*scale*scale*4)];
        return image;
    }@catch(__unused NSException *e){return nil;}
}

// BEGIN HOST-TESTED COLD-LAUNCH POLICY
// XBApplicationSnapshot exposes the numeric contentType but the runtime header
// does not define its enum values. Read its own symbolic description rather
// than guess a number or a private C function's ABI. Only the first contentType
// field is inspected; variants/other objects can never authorize replacement.
// This small pure-C policy is exercised directly by the host regression test.
enum { ADKindUnknown7337, ADKindGenerated7337, ADKindDefault7337, ADKindScene7337 };
static int ADContentKind7337(const char *description){
    if(!description)return ADKindUnknown7337;
    const char *p=strstr(description,"contentType");if(!p)return ADKindUnknown7337;
    p+=strlen("contentType");while(isspace((unsigned char)*p))++p;
    if(*p!=':'&&*p!='=')return ADKindUnknown7337;
    ++p;while(isspace((unsigned char)*p))++p;
    const char *names[]={"GeneratedDefault","Default","SceneContent"};
    for(int i=0;i<3;++i){
        size_t n=strlen(names[i]);
        if(!strncmp(p,names[i],n) && (!p[n]||p[n]==';'||p[n]=='>'||p[n]=='}'||isspace((unsigned char)p[n])))return i+1;
    }
    return ADKindUnknown7337;
}
static int ADIsColdLaunchArtwork7337(int kind,const char *provider,int protectedContent,int fromLaunchRequest){
    if(protectedContent||kind==ADKindScene7337)return 0;
    return fromLaunchRequest||kind==ADKindGenerated7337||kind==ADKindDefault7337||
        (kind==ADKindUnknown7337&&provider&&!strcmp(provider,"XBLaunchImageDataProvider"));
}
// END HOST-TESTED COLD-LAUNCH POLICY

static UIImage *ADLaunchSnapshotImage7337(XBApplicationSnapshot *snapshot,UIImage *original,NSString *accessor,long long orientation){
    // Guard only synchronous lazy-UIImage recursion, not launch timing/state.
    static __thread BOOL producingImage=NO;
    if(producingImage)return original;
    @try {
        id bundle=[snapshot.containerIdentity valueForKey:@"bundleIdentifier"];
        if(![bundle isEqual:kAMZ])return original;
        producingImage=YES;
        @try {
        NSString *provider=nil;
        @try {id value=snapshot.dataProviderClassName;if([value isKindOfClass:NSString.class])provider=value;}
        @catch(__unused NSException *e){}
        // Do not persist a rejection on snapshot identity: an early accessor
        // may have no image yet, followed by a populated result on the same object.
        int kind=ADKindUnknown7337;
        @try {
            id description=[snapshot descriptionWithoutVariants];
            if([description isKindOfClass:NSString.class])kind=ADContentKind7337([description UTF8String]);
        }@catch(__unused NSException *e){}
        BOOL protectedContent=snapshot.hasProtectedContent;
        BOOL fromLaunchRequest=objc_getAssociatedObject(snapshot,&kADGeneratedLaunch7337)!=nil;
        // Generation context is authoritative even if a new snapshot has not
        // passed through the manifest callback in this process yet.
        if(!fromLaunchRequest&&kind!=ADKindScene7337){
            @try {fromLaunchRequest=[snapshot.generationContext valueForKey:@"launchRequest"]!=nil;}
            @catch(__unused NSException *e){}
        }
        BOOL launch=ADIsColdLaunchArtwork7337(kind,[provider UTF8String],protectedContent,fromLaunchRequest);
        BOOL imageOK=[original isKindOfClass:UIImage.class];
        CGSize size=CGSizeZero;CGFloat scale=1;
        if(launch){
            size=imageOK?original.size:snapshot.referenceSize;
            scale=imageOK?original.scale:snapshot.imageScale;
            // A confirmed launch request need not expose stock pixels first.
            // Its reference dimensions also cover cache misses/nil image results.
            BOOL useReference=!imageOK||!isfinite(size.width)||!isfinite(size.height)||size.width<1||size.height<1;
            if(useReference){
                size=snapshot.referenceSize;scale=snapshot.imageScale;
                BOOL landscape=orientation==UIInterfaceOrientationLandscapeLeft||orientation==UIInterfaceOrientationLandscapeRight;
                BOOL portrait=orientation==UIInterfaceOrientationPortrait||orientation==UIInterfaceOrientationPortraitUpsideDown;
                if((landscape&&size.width<size.height)||(portrait&&size.width>size.height))size=CGSizeMake(size.height,size.width);
            }
            if(!isfinite(scale)||scale<1||scale>4)scale=1;
        }
        UIImage *dark=launch?ADLaunchArtwork7337(size,scale):nil;
        NSString *kindName=kind==ADKindGenerated7337?@"GeneratedDefault":kind==ADKindDefault7337?@"Default":kind==ADKindScene7337?@"SceneContent":@"Unknown";
        // Optional diagnostics must never turn a completed replacement back
        // into the original white image if a metadata getter is unavailable.
        @try { ADLaunchLog7337(dark?@"snapshot.dark":@"snapshot.keep",[NSString stringWithFormat:
            @"snapshot=%p accessor=%@ provider=%@ type=%lld kind=%@ interface=%d request=%d protected=%d image=%@ size=%@ scale=%.2f reason=%@",
            snapshot,accessor,provider?:@"nil",snapshot.contentType,kindName,snapshot.launchInterfaceIdentifier.length>0,fromLaunchRequest,protectedContent,
            imageOK?NSStringFromClass(original.class):@"nil",NSStringFromCGSize(size),scale,
            protectedContent?@"protected":kind==ADKindScene7337?@"saved-scene-unchanged":!launch?@"not-confirmed-launch":dark?@"launch-artwork":@"artwork-failed"]);
        }@catch(__unused NSException *e){ADLaunchLog7337(dark?@"snapshot.dark":@"snapshot.keep",@"detail=unavailable");}
        return dark?:original;
        }@finally {producingImage=NO;}
    }@catch(__unused NSException *e){ADLaunchLog7337(@"snapshot.error",accessor);return original;}
}

%hook XBApplicationSnapshot
- (UIImage *)imageForInterfaceOrientation:(long long)orientation {
    UIImage *original=%orig;
    return ADLaunchSnapshotImage7337(self,original,@"image",orientation);
}
- (UIImage *)imageForInterfaceOrientation:(long long)orientation generationOptions:(unsigned long long)options {
    UIImage *original=%orig;
    return ADLaunchSnapshotImage7337(self,original,@"image-options",orientation);
}
- (UIImage *)cachedImageForInterfaceOrientation:(long long)orientation {
    UIImage *original=%orig;
    return ADLaunchSnapshotImage7337(self,original,@"cached",orientation);
}
%end

// Provenance comes from the system's launch-request factory, never an icon tap,
// running PID, elapsed time, or a previous process's ready notification.
%group ADLaunchFactory7337
%hook XBApplicationSnapshotManifestImpl
+ (void)_configureSnapshot:(XBApplicationSnapshot *)snapshot withCompatibilityInfo:(id)info forLaunchRequest:(id)request {
    %orig;
    @try {
        if(request&&[[snapshot.containerIdentity valueForKey:@"bundleIdentifier"] isEqual:kAMZ]){
            objc_setAssociatedObject(snapshot,&kADGeneratedLaunch7337,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            ADLaunchLog7337(@"launch.configure",[NSString stringWithFormat:@"snapshot=%p type=%lld",snapshot,snapshot.contentType]);
        }
    }@catch(__unused NSException *e){}
}
%end
%end

// Trace the lazy delivery form without changing its class or lifetime. The
// native wrapper has a private interfaceOrientation contract beyond UIImage;
// replacing the wrapper itself with a plain UIImage would be a regression.
%group ADLaunchImageWrapper7337
%hook XBApplicationSnapshotImage
- (id)initWithSnapshot:(XBApplicationSnapshot *)snapshot interfaceOrientation:(long long)orientation {
    id original=%orig;
    @try {
        if([[snapshot.containerIdentity valueForKey:@"bundleIdentifier"] isEqual:kAMZ])
            ADLaunchLog7337(@"image.wrapper",[NSString stringWithFormat:@"snapshot=%p orientation=%lld native=%d",snapshot,orientation,original!=nil]);
    }@catch(__unused NSException *e){}
    return original;
}
%end
%end

// v7.379 transition probe: observe the generic scene-placeholder provider without
// changing its return value. The old v7.337 bug replaced this object; this hook is
// read-after-%orig only and logs at most 24 view nodes while the explicit arm exists.
%group ADPlaceholderProbe7379
%hook SBDeviceApplicationSceneViewPlaceholderContentViewProvider
- (id)_loadLiveXIBViewForApplication:(id)application {
    id original=%orig;
    ADObservePlaceholder7379(application,original);
    return original;
}
%end
%end

// v7.379 retained production correction: do not replace or mutate the generic placeholder.
// The probe-only group above may observe its post-%orig return while explicitly armed.
// Unlike XBApplicationSnapshot, _loadLiveXIBViewForApplication: carries no snapshot kind or
// launch-request provenance. The v7.337 artwork branch replaced that generic provider for every
// Amazon invocation, including invocations that can participate in scene placeholder continuity.
// That violates the v7.335/v7.336 warm/switcher non-interference contract. The later v7.350
// app-side AXU/Tez seal independently owns the probe-proven cold native splash child, so the
// unproven generic XIB replacement is no longer needed for that failure.

%ctor {
    if(!ADSBEnabled())return;
    BOOL factory=class_getClassMethod(objc_getClass("XBApplicationSnapshotManifestImpl"),@selector(_configureSnapshot:withCompatibilityInfo:forLaunchRequest:))!=NULL;
    BOOL wrapper=class_getInstanceMethod(objc_getClass("XBApplicationSnapshotImage"),@selector(initWithSnapshot:interfaceOrientation:))!=NULL;
    BOOL placeholder=class_getInstanceMethod(objc_getClass("SBDeviceApplicationSceneViewPlaceholderContentViewProvider"),@selector(_loadLiveXIBViewForApplication:))!=NULL;
    // Image loading consults UIScreen; UIKit is not ready during dyld startup.
    // Keep startup diagnostics free of UIKit calls, including helper arguments.
    ADLaunchLog7337(@"ctor",[NSString stringWithFormat:@"version=7.382~cold-artwork-no-generic-xib base=v7.338 snapshotClass=%d factory=%d wrapper=%d placeholderProbe=%d logo=deferred",
        objc_getClass("XBApplicationSnapshot")!=Nil,factory,wrapper,placeholder]);
    @autoreleasepool {
        @try { %init; } @catch (__unused NSException *e) {}
        if(factory){ @try { %init(ADLaunchFactory7337); } @catch(__unused NSException *e){} }
        if(wrapper){ @try { %init(ADLaunchImageWrapper7337); } @catch(__unused NSException *e){} }
        if(placeholder){ @try { %init(ADPlaceholderProbe7379); } @catch(__unused NSException *e){} }
    }
}
