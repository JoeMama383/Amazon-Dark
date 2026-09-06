// Opt-in diagnostics only. Included in Amazon's Tweak.xm, never AmazonDarkSB.
// A valid arm file must exist BEFORE this Amazon process starts. No arming on
// warm resume, no new lifecycle hooks, no CSS/geometry/scroll/snapshot writes.
#import <sys/stat.h>
#import <fcntl.h>

static NSString *const ADSkelArmPath7339=@"/var/mobile/AmazonDark-v7.339-skeleton.arm";
static const void *ADSkelScriptKey7339=&ADSkelScriptKey7339;
static NSString *ADSkelSource7339=nil;
static NSTimeInterval ADSkelUntil7339=0;
static NSString *ADSkelSession7339=nil;
static dispatch_queue_t ADSkelWriter7339;
static unsigned long long ADSkelBytes7339=0;
static BOOL ADSkelFileFull7339=NO;
static NSString *ADSkelPath7339=nil;

static BOOL ADSkelActive7339(void){
    return ADSkelUntil7339>0 && [NSDate timeIntervalSinceReferenceDate]+978307200.0<ADSkelUntil7339;
}
static void ADSkelWrite7339(NSDictionary *record){
    if(!ADSkelWriter7339||!record)return;
    // Immutable record serialization on a serial utility queue; no UI work here.
    dispatch_async(ADSkelWriter7339,^{
        @autoreleasepool {
            if(ADSkelFileFull7339)return;
            @try {
                NSData *json=[NSJSONSerialization dataWithJSONObject:record options:0 error:nil];
                if(!json)return;
                if(ADSkelBytes7339+json.length>20*1024*1024){
                    json=[@"{\"event\":\"NATIVE_FILE_LIMIT\",\"cap\":20971520}" dataUsingEncoding:NSUTF8StringEncoding];
                    ADSkelFileFull7339=YES;
                }
                int fd=open(ADSkelPath7339.fileSystemRepresentation,O_WRONLY|O_APPEND|O_CREAT,0600);
                if(fd<0)return;
                const uint8_t *p=(const uint8_t *)json.bytes; NSUInteger left=json.length;
                while(left){ssize_t n=write(fd,p,left);if(n<=0)break;p+=n;left-=n;}
                write(fd,"\n",1);close(fd);ADSkelBytes7339+=json.length+1;
            } @catch(...) {}
        }
    });
}
static NSDictionary *ADSkelEvent7339(NSString *event){
    return @{@"event":event,@"session":ADSkelSession7339?:@"",@"epoch":@([NSDate date].timeIntervalSince1970*1000),
        @"up":@(NSProcessInfo.processInfo.systemUptime),@"pid":@(getpid())};
}
static NSArray *ADSkelRect7339(CGRect r){return @[@(round(r.origin.x*10)/10),@(round(r.origin.y*10)/10),@(round(r.size.width*10)/10),@(round(r.size.height*10)/10)];}
static id ADSkelColor7339(CGColorRef c){
    if(!c)return [NSNull null];
    @try {
        UIColor *u=[UIColor colorWithCGColor:c];CGFloat r=0,g=0,b=0,a=0,w=0;
        if(![u getRed:&r green:&g blue:&b alpha:&a]){
            if(![u getWhite:&w alpha:&a])return @"unresolved";r=g=b=w;
        }
        return @[@(round(r*1000)/1000),@(round(g*1000)/1000),@(round(b*1000)/1000),@(round(a*1000)/1000)];
    } @catch(...) {return @"unresolved";}
}
static BOOL ADSkelBright7339(id c){
    return [c isKindOfClass:NSArray.class]&&[(NSArray *)c count]==4&&[c[3] doubleValue]>.15&&
        [c[0] doubleValue]*.2126+[c[1] doubleValue]*.7152+[c[2] doubleValue]*.0722>.59;
}
static NSString *ADSkelName7339(NSString *s){
    // Technical identifiers/classes only. No labels, text, view descriptions or URLs.
    if(![s isKindOfClass:NSString.class])return @"";
    if([s containsString:@"://"]||[s hasPrefix:@"data:"])return @"[resource]";
    return s.length>180?[s substringToIndex:180]:s;
}

@interface ADSkeletonProbe7339 : NSObject <WKScriptMessageHandler>
@property(nonatomic,strong) CADisplayLink *link;
@property(nonatomic,strong) NSMutableDictionary *previous;
@property(nonatomic) NSUInteger ticks;
@property(nonatomic) NSUInteger clipped;
@property(nonatomic) CFTimeInterval maxMS;
- (void)tick:(CADisplayLink *)link;
- (void)finish;
@end
static ADSkeletonProbe7339 *ADSkelProbe7339=nil;

@implementation ADSkeletonProbe7339
- (void)userContentController:(WKUserContentController *)ucc didReceiveScriptMessage:(WKScriptMessage *)message {
    @try {
        if(![message.name isEqualToString:@"adSkeleton7339"]||![message.body isKindOfClass:NSString.class])return;
        NSString *body=message.body;
        if(body.length>192*1024){ADSkelWrite7339(ADSkelEvent7339(@"WEB_MESSAGE_LIMIT"));return;}
        NSDictionary *data=[NSJSONSerialization JSONObjectWithData:[body dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        if(![data isKindOfClass:NSDictionary.class]||![data[@"session"] isEqual:ADSkelSession7339])return;
        WKWebView *wv=message.webView; CGRect r=CGRectZero;
        if(wv)r=[wv convertRect:wv.bounds toView:nil];
        NSMutableDictionary *record=[ADSkelEvent7339(@"WEB") mutableCopy];
        record[@"webView"]=[NSString stringWithFormat:@"%p",wv];record[@"mainFrame"]=@(message.frameInfo.mainFrame);
        record[@"window"]=@(wv.window!=nil);record[@"rect"]=ADSkelRect7339(r);record[@"data"]=data;
        ADSkelWrite7339(record);
    } @catch(...) {}
}
- (void)tick:(CADisplayLink *)link {
    if(!ADSkelActive7339()){[self finish];return;}
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    CFTimeInterval began=CACurrentMediaTime();self.ticks++;
    NSMutableDictionary *now=[NSMutableDictionary dictionary];NSMutableArray *events=[NSMutableArray array];
    NSMutableArray *queue=[NSMutableArray array];NSString *tab=@"unknown";NSUInteger index=0;
    @try {
        for(UIWindow *w in UIApplication.sharedApplication.windows)if(!w.hidden&&w.alpha>.01)[queue addObject:w];
        while(index<queue.count&&index<1400){
            UIView *v=queue[index++];if(v.hidden||v.alpha<.01)continue;
            if([v isKindOfClass:UIControl.class]&&[(UIControl *)v isSelected]&&v.accessibilityIdentifier.length)
                tab=ADSkelName7339(v.accessibilityIdentifier);
            CGRect r=[v convertRect:v.bounds toView:nil];CGRect screen=v.window.bounds;
            if(CGRectIsEmpty(r)||CGRectIsNull(CGRectIntersection(r,screen)))continue;
            BOOL web=[v isKindOfClass:WKWebView.class];
            // WebKit's pixels are captured by the all-frame DOM probe. Do not spend
            // the display budget recursively enumerating its internal view tree.
            if(!web)for(UIView *c in v.subviews)if(queue.count<1401)[queue addObject:c];
            NSMutableArray *layers=[NSMutableArray arrayWithObject:v.layer];
            NSUInteger layerIndex=0;
            while(layerIndex<layers.count&&layerIndex<20){
                CALayer *l=layers[layerIndex++];if(l.hidden||l.opacity<.01)continue;
                if(l==v.layer)for(CALayer *s in l.sublayers)if(![s.delegate isKindOfClass:UIView.class]&&layers.count<20)[layers addObject:s];
                CALayer *present=l.presentationLayer;
                id bg=ADSkelColor7339(l.backgroundColor),pb=ADSkelColor7339(present.backgroundColor),bc=ADSkelColor7339(l.borderColor);
                NSString *key=[NSString stringWithFormat:@"%p/%p",v,l];
                NSString *name=NSStringFromClass(v.class);
                BOOL hint=[name rangeOfString:@"skeleton" options:NSCaseInsensitiveSearch].location!=NSNotFound||
                    [name rangeOfString:@"loading" options:NSCaseInsensitiveSearch].location!=NSNotFound;
                BOOL gradient=[l isKindOfClass:CAGradientLayer.class];
                BOOL image=[v isKindOfClass:UIImageView.class]||l.contents!=nil;
                if(!(hint||gradient||web||self.previous[key]||ADSkelBright7339(bg)||ADSkelBright7339(pb)||
                    (l.borderWidth>=2&&ADSkelBright7339(bc))||(image&&r.size.width>=40&&r.size.height>=8)))continue;
                if(now.count>=160){self.clipped++;break;}
                NSMutableDictionary *node=[@{@"key":key,@"class":name,@"id":ADSkelName7339(v.accessibilityIdentifier),
                    @"rect":ADSkelRect7339(r),@"layerClass":NSStringFromClass(l.class),@"layerBounds":ADSkelRect7339(l.bounds),
                    @"layerFrame":ADSkelRect7339(l.frame),@"bg":bg,@"presentationBG":pb,@"border":bc,
                    @"borderWidth":@(l.borderWidth),@"radius":@(l.cornerRadius),@"alpha":@(v.alpha),
                    @"layerOpacity":@(l.opacity),@"masksToBounds":@(l.masksToBounds),@"contents":@(l.contents!=nil),
                    @"parentClass":v.superview?NSStringFromClass(v.superview.class):@"",@"parentID":ADSkelName7339(v.superview.accessibilityIdentifier)} mutableCopy];
                if(gradient){NSMutableArray *colors=[NSMutableArray array];for(id c in [(CAGradientLayer *)l colors])if(colors.count<12)[colors addObject:ADSkelColor7339((__bridge CGColorRef)c)];node[@"gradient"]=colors;}
                if([v isKindOfClass:UIImageView.class]){UIImage *i=[(UIImageView *)v image];node[@"imageSize"]=@[@(i.size.width),@(i.size.height)];}
                now[key]=node;
                if(![self.previous[key] isEqual:node])[events addObject:node];
            }
            if(CACurrentMediaTime()-began>.005){self.clipped++;break;}
        }
        if(index<queue.count)self.clipped++;
        // Do not claim nodes disappeared if this frame's traversal was capped.
        if(index>=queue.count)for(NSString *key in self.previous)if(!now[key])[events addObject:@{@"key":key,@"gone":@YES}];
        self.previous=now;self.maxMS=MAX(self.maxMS,(CACurrentMediaTime()-began)*1000);
        if(events.count||self.ticks%60==0){
            NSMutableDictionary *out=[ADSkelEvent7339(@"NATIVE_FRAME") mutableCopy];
            out[@"tab"]=tab;out[@"changes"]=events;out[@"visited"]=@(index);out[@"ticks"]=@(self.ticks);
            out[@"clipped"]=@(self.clipped);out[@"maxMS"]=@(self.maxMS);ADSkelWrite7339(out);
        }
    } @catch(...) {ADSkelWrite7339(ADSkelEvent7339(@"NATIVE_CAPTURE_EXCEPTION"));}
}
- (void)finish {
    if(!self.link)return;
    [self.link invalidate];self.link=nil;self.previous=nil;
    ADSkelWrite7339(ADSkelEvent7339(@"SESSION_END"));
}
@end

static void ADSkelInstall7339(void){
    // Read once per process. Re-arming requires a deliberate force-close/relaunch;
    // this guarantees injection before the first document and all child frames.
    if(ADSkelProbe7339)return;
    @try {
        NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:ADSkelArmPath7339 error:nil];
        if(!attrs||[attrs fileSize]>128)return;
        NSString *arm=[NSString stringWithContentsOfFile:ADSkelArmPath7339 encoding:NSUTF8StringEncoding error:nil];
        NSArray *parts=[[arm componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
            filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
        if(parts.count!=2)return;
        NSTimeInterval now=NSDate.date.timeIntervalSince1970,expiry=[parts[0] doubleValue];
        if(!isfinite(expiry)||expiry<=now||expiry>now+300)return;
        NSString *label=parts[1];if(![@[@"home",@"cart",@"both"] containsObject:label])return;
        ADSkelUntil7339=MIN(expiry,now+120);
        ADSkelSession7339=[NSString stringWithFormat:@"%.0f-%d-%@",now*1000,getpid(),label];
        ADSkelPath7339=[NSString stringWithFormat:@"/var/mobile/AmazonDark-v7.339-skeleton-%@.jsonl",ADSkelSession7339];
        ADSkelWriter7339=dispatch_queue_create("com.colindavidr.amazondark.skeleton.writer",DISPATCH_QUEUE_SERIAL);
        NSDictionary *config=@{@"session":ADSkelSession7339,@"until":@(ADSkelUntil7339*1000)};
        NSString *json=[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:config options:0 error:nil] encoding:NSUTF8StringEncoding];
        NSString *source=[NSString stringWithUTF8String:
            #include "ADSkeletonProbe7339.js.inc"
        ];
        ADSkelSource7339=[source stringByReplacingOccurrencesOfString:@"__AD_CONFIG__" withString:json];
        ADSkelProbe7339=[ADSkeletonProbe7339 new];ADSkelProbe7339.previous=[NSMutableDictionary dictionary];
        NSMutableDictionary *record=[ADSkelEvent7339(@"SESSION_START") mutableCopy];
        record[@"version"]=@AD_VERSION;record[@"until"]=@(ADSkelUntil7339*1000);record[@"label"]=label;
        record[@"policy"]=@"read-only; no text/URLs/pixels; prearmed document-start all-frame capture; max 120s/20MiB; truncation is explicit";
        ADSkelWrite7339(record);
        dispatch_async(dispatch_get_main_queue(),^{
            if(!ADSkelActive7339())return;
            ADSkelProbe7339.link=[CADisplayLink displayLinkWithTarget:ADSkelProbe7339 selector:@selector(tick:)];
            ADSkelProbe7339.link.preferredFramesPerSecond=60;
            [ADSkelProbe7339.link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((ADSkelUntil7339-now)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[ADSkelProbe7339 finish];});
    } @catch(...) {}
}
static void ADSkelAttach7339(WKUserContentController *ucc){
    if(!ucc||!ADSkelActive7339()||!ADSkelSource7339)return;
    @try {
        WKUserScript *old=objc_getAssociatedObject(ucc,ADSkelScriptKey7339);
        if(old&&[ucc.userScripts containsObject:old])return;
        WKContentWorld *world=[WKContentWorld worldWithName:@"AmazonDarkSkeleton7339"];
        [ucc removeScriptMessageHandlerForName:@"adSkeleton7339" contentWorld:world];
        [ucc addScriptMessageHandler:ADSkelProbe7339 contentWorld:world name:@"adSkeleton7339"];
        WKUserScript *script=[[WKUserScript alloc] initWithSource:ADSkelSource7339
            injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO inContentWorld:world];
        [ucc addUserScript:script];objc_setAssociatedObject(ucc,ADSkelScriptKey7339,script,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADSkelWrite7339(ADSkelEvent7339(@"UCC_ATTACHED"));
    } @catch(...) {ADSkelWrite7339(ADSkelEvent7339(@"UCC_ATTACH_EXCEPTION"));}
}
static BOOL ADSkelTrigger7339(NSString *trigger){
    if(!ADSkelActive7339())return NO;
    NSMutableDictionary *record=[ADSkelEvent7339(@"USER_MARK") mutableCopy];record[@"trigger"]=trigger?:@"";
    ADSkelWrite7339(record);return YES; // Prevent the old screenshot probe's automatic scrolling during this capture.
}
