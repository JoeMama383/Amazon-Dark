#include <math.h>
// v7.600: bounded, explicitly armed performance diagnostics. Main-thread counters.
// Kept separate from FULL/VIEWPORT: no UI inventory, screenshot or scroll mutation.
struct ADPerfMetric7596 { unsigned long count,buckets[8]; double total,max; };
static ADPerfMetric7596 gADPerfLanes7596[ADPerfLaneCount],gADPerfFrames7596,gADPerfInputAge7596;
static unsigned gADPerfFrameSeconds7596[90];
static double gADPerfStart7596=0;
static void ADPerfAdd7596(ADPerfMetric7596 *m,double v){
    if(!isfinite(v)||v<0)return;
    m->count++;m->total+=v;if(v>m->max)m->max=v;
    const double bounds[]={1,4,8,16.7,33.4,50,100};unsigned i=0;while(i<7&&v>bounds[i])i++;m->buckets[i]++;
}
static void ADPerformanceRecord7596(unsigned lane,double ms){if(lane<ADPerfLaneCount)ADPerfAdd7596(&gADPerfLanes7596[lane],ms);}
static void ADPerformanceEvent7596(UIEvent *event){
    if(gADPerformanceActive7596&&event.type==UIEventTypeTouches&&event.timestamp>0)ADPerfAdd7596(&gADPerfInputAge7596,(CACurrentMediaTime()-event.timestamp)*1000);
}
static NSDictionary *ADPerfMetricJSON7596(ADPerfMetric7596 m){
    NSMutableArray *b=[NSMutableArray array];for(unsigned i=0;i<8;i++)[b addObject:@(m.buckets[i])];
    return @{ @"count":@(m.count),@"totalMs":@(m.total),@"maxMs":@(m.max),@"buckets":b };
}
static NSString *ADPerfPath7596(NSString *suffix){
    NSString *d=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    return [d stringByAppendingPathComponent:[@"AmazonDark-v7.600-performance" stringByAppendingString:suffix]];
}
static void *kADPerfLoading7596=&kADPerfLoading7596;
@interface ADPerformance7596 : NSObject <WKScriptMessageHandler>
@property(nonatomic,strong) CADisplayLink *display;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) NSHashTable *webs;
@property(nonatomic,strong) NSHashTable *controllers;
@property(nonatomic,strong) NSMapTable *navigationStarts;
@property(nonatomic,strong) NSMapTable *controllerStarts;
@property(nonatomic,strong) NSMutableArray *controllerTransitions;
@property(nonatomic,strong) NSMutableArray *documents;
@property(nonatomic,strong) NSMutableArray *navigations;
@property(nonatomic,copy) NSString *session;
@property(nonatomic,copy) NSString *program;
@property(nonatomic) double deadline,lastFrame;
@property(nonatomic) NSUInteger injected,failed,dropped,enrolled;
@property(nonatomic) BOOL finishing,writing,otherProbeObserved;
@property(nonatomic) UIBackgroundTaskIdentifier backgroundTask;
- (void)foreground:(NSNotification *)notification;
- (void)background:(NSNotification *)notification;
- (void)enroll:(WKWebView *)web;
- (void)finish:(NSString *)reason;
- (void)navigation:(UIViewController *)controller begin:(BOOL)begin;
@end
static ADPerformance7596 *gADPerformance7596=nil;
@implementation ADPerformance7596
- (void)foreground:(NSNotification *)notification {
    if(gADPerformanceActive7596||self.finishing)return;
    NSString *arm=ADPerfPath7596(@".arm");
    NSString *request=[NSString stringWithContentsOfFile:arm encoding:NSUTF8StringEncoding error:nil];
    if(!request)return;
    [[NSFileManager defaultManager] removeItemAtPath:arm error:nil];
    double armed=request.doubleValue,now=NSDate.date.timeIntervalSince1970;
    if(!gP.enabled||armed>now+5||now-armed>600)return;
    memset(gADPerfLanes7596,0,sizeof(gADPerfLanes7596));memset(&gADPerfFrames7596,0,sizeof(gADPerfFrames7596));memset(&gADPerfInputAge7596,0,sizeof(gADPerfInputAge7596));memset(gADPerfFrameSeconds7596,0,sizeof(gADPerfFrameSeconds7596));
    self.webs=[NSHashTable weakObjectsHashTable];self.controllers=[NSHashTable weakObjectsHashTable];
    self.controllerStarts=[NSMapTable weakToStrongObjectsMapTable];self.controllerTransitions=[NSMutableArray array];
    self.navigationStarts=[NSMapTable weakToStrongObjectsMapTable];self.documents=[NSMutableArray array];self.navigations=[NSMutableArray array];
    self.otherProbeObserved=gADUIProbeBusy7362||ADSkelActive7339();
    self.session=NSUUID.UUID.UUIDString;self.deadline=(now+90)*1000;self.lastFrame=0;self.injected=0;self.failed=0;self.dropped=0;self.enrolled=0;self.backgroundTask=UIBackgroundTaskInvalid;
    NSString *source=@""
#include "ADPerformance7596.js.inc"
    ;
    self.program=[[source stringByReplacingOccurrencesOfString:@"__SESSION__" withString:[NSString stringWithFormat:@"\"%@\"",self.session]] stringByReplacingOccurrencesOfString:@"__DEADLINE__" withString:[NSString stringWithFormat:@"%.0f",self.deadline]];
    gADPerformanceGeneration7596++;gADPerfStart7596=CACurrentMediaTime();gADPerformanceActive7596=YES;
    [@"running\n" writeToFile:ADPerfPath7596(@".state") atomically:YES encoding:NSUTF8StringEncoding error:nil];
    self.display=[CADisplayLink displayLinkWithTarget:self selector:@selector(frame:)];
    [self.display addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    self.timer=[NSTimer timerWithTimeInterval:90 target:self selector:@selector(expired:) userInfo:nil repeats:NO];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    for(WKWebView *web in ADTrackedWebViews())[self enroll:web];
}
- (void)frame:(CADisplayLink *)link {
    if(gADUIProbeBusy7362||ADSkelActive7339())self.otherProbeObserved=YES;
    double t=link.timestamp;
    if(self.lastFrame){
        double ms=(t-self.lastFrame)*1000;ADPerfAdd7596(&gADPerfFrames7596,ms);
        // Buckets use absolute observed callback gaps, not an assumed refresh rate.
        int second=(int)(CACurrentMediaTime()-gADPerfStart7596);if(ms>50&&second>=0&&second<90)gADPerfFrameSeconds7596[second]++;
    }
    self.lastFrame=t;
}
- (void)inject:(WKWebView *)web {
    if(!gADPerformanceActive7596||!web.window||web.loading)return;
    NSString *session=self.session;
    self.injected++;
    [web evaluateJavaScript:self.program completionHandler:^(id value,NSError *error){if(error&&[self.session isEqual:session])self.failed++;}];
}
- (void)enroll:(WKWebView *)web {
    if(!gADPerformanceActive7596||!web||!web.window||[self.webs containsObject:web])return;
    if(self.enrolled>=32){self.dropped++;return;}
    WKUserContentController *ucc=web.configuration.userContentController;
    if(![self.controllers containsObject:ucc]){
        [ucc addScriptMessageHandler:self name:@"adPerformance7596"];[self.controllers addObject:ucc];
    }
    [self.webs addObject:web];self.enrolled++;
    [web addObserver:self forKeyPath:@"loading" options:NSKeyValueObservingOptionNew context:kADPerfLoading7596];
    if(web.loading)[self.navigationStarts setObject:@(CACurrentMediaTime()) forKey:web];
    [self inject:web];
}
- (void)observeValueForKeyPath:(NSString *)key ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if(context!=kADPerfLoading7596){[super observeValueForKeyPath:key ofObject:object change:change context:context];return;}
    if(!gADPerformanceActive7596)return;
    WKWebView *web=(WKWebView *)object;
    if(web.loading){[self.navigationStarts setObject:@(CACurrentMediaTime()) forKey:web];return;}
    NSNumber *start=[self.navigationStarts objectForKey:web];
    if(start){if(self.navigations.count<128)[self.navigations addObject:@{ @"atMs":@((start.doubleValue-gADPerfStart7596)*1000),@"loadingMs":@((CACurrentMediaTime()-start.doubleValue)*1000) }];else self.dropped++;[self.navigationStarts removeObjectForKey:web];}
    [self inject:web];
}
- (void)userContentController:(WKUserContentController *)ucc didReceiveScriptMessage:(WKScriptMessage *)message {
    if((!gADPerformanceActive7596&&!self.finishing)||self.writing||![message.name isEqual:@"adPerformance7596"]||!message.frameInfo.mainFrame)return;
    NSDictionary *body=[message.body isKindOfClass:NSDictionary.class]?message.body:nil;
    if(![body[@"session"] isEqual:self.session])return;
    // Whitelist numeric aggregates; never persist arbitrary page message strings/content.
    NSMutableDictionary *safe=[NSMutableDictionary dictionary];
    for(NSString *key in @[@"durationMs",@"resourceEntriesDropped",@"pendingInputs",@"inputDropped"]){id value=body[key];if([value isKindOfClass:NSNumber.class]&&isfinite([value doubleValue]))safe[key]=value;}
    for(NSString *key in @[@"frames",@"inputToNextRAF",@"eventTiming",@"longTasks",@"resources"]){
        NSDictionary *m=[body[key] isKindOfClass:NSDictionary.class]?body[key]:nil;NSMutableDictionary *out=[NSMutableDictionary dictionary];
        for(NSString *field in @[@"count",@"totalMs",@"maxMs"]){id value=m[field];if([value isKindOfClass:NSNumber.class]&&isfinite([value doubleValue]))out[field]=value;}
        NSArray *b=[m[@"buckets"] isKindOfClass:NSArray.class]?m[@"buckets"]:nil;
        if(b.count==8){BOOL valid=YES;for(id v in b)if((![v isKindOfClass:NSNumber.class]||!isfinite([v doubleValue])))valid=NO;if(valid)out[@"buckets"]=b;}
        safe[key]=out;
    }
    NSMutableDictionary *nav=[NSMutableDictionary dictionary];
    for(NSString *key in @[@"responseStart",@"responseEnd",@"domInteractive",@"domContentLoadedEventEnd",@"loadEventEnd"]){id v=[body[@"navigationMs"] isKindOfClass:NSDictionary.class]?body[@"navigationMs"][key]:nil;if([v isKindOfClass:NSNumber.class]&&isfinite([v doubleValue]))nav[key]=v;}
    safe[@"navigationMs"]=nav;
    NSMutableArray *supported=[NSMutableArray array];for(NSString *t in @[@"event",@"resource",@"longtask"])if([body[@"supported"] isKindOfClass:NSArray.class]&&[body[@"supported"] containsObject:t])[supported addObject:t];safe[@"supported"]=supported;
    NSString *reason=body[@"reason"];safe[@"reason"]=[@[@"deadline",@"pagehide",@"native-stop",@"replaced"] containsObject:reason?:@""]?reason:@"unknown";
    safe[@"receivedAtMs"]=@((CACurrentMediaTime()-gADPerfStart7596)*1000);
    if(self.documents.count<128)[self.documents addObject:safe];else self.dropped++;
}
- (void)navigation:(UIViewController *)controller begin:(BOOL)begin {
    if(begin){if(self.controllerStarts.count<128)[self.controllerStarts setObject:@(CACurrentMediaTime()) forKey:controller];else self.dropped++;return;}
    NSNumber *start=[self.controllerStarts objectForKey:controller];if(!start)return;
    [self.controllerStarts removeObjectForKey:controller];
    if(self.controllerTransitions.count<128)[self.controllerTransitions addObject:@{ @"controllerClass":NSStringFromClass(controller.class),@"atMs":@((start.doubleValue-gADPerfStart7596)*1000),@"appearanceMs":@((CACurrentMediaTime()-start.doubleValue)*1000) }];else self.dropped++;
}
- (void)expired:(NSTimer *)timer {[self finish:@"deadline"];}
- (void)background:(NSNotification *)notification {[self finish:@"background"];}
- (void)finish:(NSString *)reason {
    if(!gADPerformanceActive7596)return;
    gADPerformanceActive7596=NO;self.finishing=YES;
    [self.display invalidate];self.display=nil;[self.timer invalidate];self.timer=nil;
    double duration=(CACurrentMediaTime()-gADPerfStart7596)*1000;
    self.backgroundTask=[UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{[self write:reason duration:duration];}];
    for(WKWebView *web in self.webs.allObjects){
        [web removeObserver:self forKeyPath:@"loading" context:kADPerfLoading7596];
        [web evaluateJavaScript:@"window.__adPerformance7596 && window.__adPerformance7596.stop('native-stop')" completionHandler:nil];
    }
    // Bounded grace for WebKit messages, including the last foreground document.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self write:reason duration:duration];});
}
- (void)write:(NSString *)reason duration:(double)duration {
    if(!self.finishing||self.writing)return;self.writing=YES;
    for(WKUserContentController *ucc in self.controllers.allObjects)[ucc removeScriptMessageHandlerForName:@"adPerformance7596"];
    NSArray *names=@[@"eventDispatchInclusive",@"reactLayoutTheme",@"imageLayoutTheme",@"imageCommitInclusive",@"reactTextCommitInclusive",@"viewBackgroundInclusive",@"labelAttributedCommitInclusive"];
    NSMutableDictionary *lanes=[NSMutableDictionary dictionary];for(unsigned i=0;i<ADPerfLaneCount;i++)lanes[names[i]]=ADPerfMetricJSON7596(gADPerfLanes7596[i]);
    NSMutableArray *seconds=[NSMutableArray array];for(unsigned i=0;i<90;i++)[seconds addObject:@(gADPerfFrameSeconds7596[i])];
    NSDictionary *report=@{ @"version":@AD_VERSION,@"schema":@1,@"session":self.session,@"endReason":reason,@"durationMs":@(duration),@"nativeFrames":ADPerfMetricJSON7596(gADPerfFrames7596),@"touchEventAge":ADPerfMetricJSON7596(gADPerfInputAge7596),@"frameGapsOver50MsBySecond":seconds,@"lanes":lanes,@"webDocuments":[self.documents copy],@"webLoadingIntervals":[self.navigations copy],@"controllerTransitions":[self.controllerTransitions copy],@"otherDiagnosticObserved":@(self.otherProbeObserved),@"enrolledWebViews":@(self.enrolled),@"injectionAttempts":@(self.injected),@"injectionErrors":@(self.failed),@"droppedRecords":@(self.dropped),@"unfinishedLoadingIntervals":@(self.navigationStarts.count),@"coverage":@"Native foreground only. Main Web documents attach after loading; no cross-origin frames, cold-start or server attribution. Missing Web reports are not zero latency. Inclusive lanes overlap; do not sum. RAF is not presentation latency. Controller appearance intervals include animations. Diagnostic overhead is included." };
    NSString *path=ADPerfPath7596(@".json"),*state=ADPerfPath7596(@".state");
    UIBackgroundTaskIdentifier task=self.backgroundTask;self.backgroundTask=UIBackgroundTaskInvalid;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
        NSError *error=nil;NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:&error];
        BOOL ok=data&&[data writeToFile:path options:NSDataWritingAtomic error:&error];
        if(![[NSFileManager defaultManager] fileExistsAtPath:ADPerfPath7596(@".arm")])[(ok?@"completed\n":@"write-error\n") writeToFile:state atomically:YES encoding:NSUTF8StringEncoding error:nil];
        dispatch_async(dispatch_get_main_queue(),^{self.finishing=NO;self.writing=NO;if(task!=UIBackgroundTaskInvalid)[UIApplication.sharedApplication endBackgroundTask:task];});
    });
    self.webs=nil;self.controllers=nil;self.program=nil;
}
@end
static void ADPerformanceEnroll7596(WKWebView *web){if(gADPerformanceActive7596)[gADPerformance7596 enroll:web];}
static void ADPerformanceNavigation7596(UIViewController *controller,BOOL begin){if(gADPerformanceActive7596)[gADPerformance7596 navigation:controller begin:begin];}
static void ADPerformanceInstall7596(void){
    static dispatch_once_t once;dispatch_once(&once,^{
        gADPerformance7596=[ADPerformance7596 new];
        NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
        [center addObserver:gADPerformance7596 selector:@selector(foreground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [center addObserver:gADPerformance7596 selector:@selector(background:) name:UIApplicationWillResignActiveNotification object:nil];
    });
}
