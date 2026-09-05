// AmazonDarkSB.xm — v7.337, cold-launch artwork with iOS-owned presentation.
// UI baseline: exact v7.307 (4bbbbd9). Injected only into SpringBoard.
// Replace only positively identified Amazon launch resources. Saved scene images
// and live views pass through. No scene cover, PID/cold classification, ready
// listener, deadline, minimum duration, animation override, or snapshot deletion.

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
        image=[UIImage imageWithContentsOfFile:@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png"];
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
@interface SBDeviceApplicationSceneViewPlaceholderContentViewProvider : NSObject
@end
static const char kADGeneratedLaunch7337=0;

static void ADLaunchLog7337(NSString *event,NSString *detail){
    @try {
        static dispatch_queue_t queue; static dispatch_once_t once;
        dispatch_once(&once,^{queue=dispatch_queue_create("com.colindavidr.amazondark.launch-artwork",DISPATCH_QUEUE_SERIAL);});
        NSString *line=[NSString stringWithFormat:@"%.6f up=%.6f pid=%d event=%@ %@\n",
            CFAbsoluteTimeGetCurrent(),NSProcessInfo.processInfo.systemUptime,getpid(),event,detail?:@""];
        dispatch_async(queue,^{@autoreleasepool{@try{
            NSString *path=@"/var/mobile/AmazonDark-v7.337-launch-sb-probe.txt";
            NSFileManager *fm=NSFileManager.defaultManager;
            if(![fm fileExistsAtPath:path])[fm createFileAtPath:path contents:nil attributes:@{NSFilePosixPermissions:@0666}];
            NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:path];
            if(file){[file seekToEndOfFile];[file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];[file closeFile];}
        }@catch(__unused NSException *e){}}});
    }@catch(__unused NSException *e){}
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

// A missing disk launch snapshot can be supplied by the launch XIB instead.
// Replace only that detached return value; never insert/remove scene children
// inside willMoveToWindow:, or alter the provider's saved-user-content branch.
%hook SBDeviceApplicationSceneViewPlaceholderContentViewProvider
- (id)_loadLiveXIBViewForApplication:(id)application {
    id original=%orig;
    @try {
        if(![[application valueForKey:@"bundleIdentifier"] isEqual:kAMZ])return original;
        UIView *source=[original isKindOfClass:UIView.class]?(UIView *)original:nil;
        CGRect bounds=source.bounds;
        if(CGRectIsEmpty(bounds))bounds=UIScreen.mainScreen.bounds;
        CGFloat scale=source?source.contentScaleFactor:UIScreen.mainScreen.scale;
        UIImage *image=ADLaunchArtwork7337(bounds.size,scale);
        if(!image){ADLaunchLog7337(@"xib.fallback",@"reason=no-artwork");return original;}
        UIImageView *replacement=[[UIImageView alloc] initWithImage:image];
        replacement.frame=source&&!CGRectIsEmpty(source.frame)?source.frame:bounds;
        replacement.bounds=bounds;
        replacement.autoresizingMask=source?source.autoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        replacement.contentMode=UIViewContentModeScaleToFill;
        replacement.userInteractionEnabled=NO;
        ADLaunchLog7337(@"xib.dark",NSStringFromCGSize(bounds.size));
        return replacement;
    }@catch(__unused NSException *e){ADLaunchLog7337(@"xib.error",nil);return original;}
}
%end

%ctor {
    if(!ADSBEnabled())return;
    BOOL factory=class_getClassMethod(objc_getClass("XBApplicationSnapshotManifestImpl"),@selector(_configureSnapshot:withCompatibilityInfo:forLaunchRequest:))!=NULL;
    BOOL wrapper=class_getInstanceMethod(objc_getClass("XBApplicationSnapshotImage"),@selector(initWithSnapshot:interfaceOrientation:))!=NULL;
    ADLaunchLog7337(@"ctor",[NSString stringWithFormat:@"version=7.337~v7307-stock-timing-cold-artwork base=4bbbbd9 mode=artwork-only snapshotClass=%d xibClass=%d factory=%d wrapper=%d logo=%d",
        objc_getClass("XBApplicationSnapshot")!=Nil,
        objc_getClass("SBDeviceApplicationSceneViewPlaceholderContentViewProvider")!=Nil,factory,wrapper,ADSplashImage7191()!=nil]);
    @autoreleasepool {
        @try { %init; } @catch (__unused NSException *e) {}
        if(factory){ @try { %init(ADLaunchFactory7337); } @catch(__unused NSException *e){} }
        if(wrapper){ @try { %init(ADLaunchImageWrapper7337); } @catch(__unused NSException *e){} }
    }
}
