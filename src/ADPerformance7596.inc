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
    return [d stringByAppendingPathComponent:[@"AmazonDark-v7.641-performance" stringByAppendingString:suffix]];
}
// Keep diagnostics outside the app's page globals and bridge overrides.
static WKContentWorld *ADPerfWorld7635(void){return [WKContentWorld worldWithName:@"AmazonDarkPerformance7635"];}
static void ADPerfEval7635(WKWebView *web,NSString *script,void (^completion)(id,NSError *)){
    [web evaluateJavaScript:script inFrame:nil inContentWorld:ADPerfWorld7635() completionHandler:completion];
}
static void *kADPerfLoading7596=&kADPerfLoading7596;
@interface ADPerformance7596 : NSObject <WKScriptMessageHandler>
@property(nonatomic,strong) CADisplayLink *display;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) NSTimer *webSampleTimer;
@property(nonatomic,strong) NSHashTable *webs;
@property(nonatomic,strong) NSHashTable *controllers;
@property(nonatomic,strong) NSHashTable *pendingEvals;
@property(nonatomic,strong) WKUserScript *navigationScript;
@property(nonatomic,strong) WKUserScript *themeScript;
@property(nonatomic,strong) NSMutableArray *themeReports;
@property(nonatomic,strong) NSMutableArray *scriptInventory;
@property(nonatomic,strong) NSMutableArray *sampleDiagnostics;
@property(nonatomic,strong) NSMapTable *navigationStarts;
@property(nonatomic,strong) NSMapTable *controllerStarts;
@property(nonatomic,strong) NSMutableArray *controllerTransitions;
@property(nonatomic,strong) NSMutableArray *documents;
@property(nonatomic,strong) NSMutableArray *navigations;
@property(nonatomic,strong) NSMutableArray *injectionTimings;
@property(nonatomic) NSUInteger webEvalAcks,webBridgeReports,webEvalMissing,webPeriodicSamples,webPeriodicFailures;
@property(nonatomic,copy) NSString *session;
@property(nonatomic,copy) NSString *program;
@property(nonatomic) double deadline,lastFrame;
@property(nonatomic) NSUInteger injected,failed,dropped,enrolled;
@property(nonatomic) BOOL styleExperiment;
@property(nonatomic) BOOL finishing,writing,otherProbeObserved,themeEnabledAtArm;
@property(nonatomic) UIBackgroundTaskIdentifier backgroundTask;
- (void)foreground:(NSNotification *)notification;
- (void)background:(NSNotification *)notification;
- (void)enroll:(WKWebView *)web;
- (void)attach:(WKUserContentController *)ucc;
- (void)acceptThemeBody:(NSDictionary *)body main:(BOOL)main;
- (void)inventory:(WKUserContentController *)ucc phase:(NSUInteger)phase;
- (void)finish:(NSString *)reason;
- (void)acceptWebBody:(NSDictionary *)body origin:(NSString *)origin;
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
    self.styleExperiment=[request hasSuffix:@"styles\n"];
    double armed=request.doubleValue,now=NSDate.date.timeIntervalSince1970;
    if(armed>now+5||now-armed>600)return;
    memset(gADPerfLanes7596,0,sizeof(gADPerfLanes7596));memset(&gADPerfFrames7596,0,sizeof(gADPerfFrames7596));memset(&gADPerfInputAge7596,0,sizeof(gADPerfInputAge7596));memset(gADPerfFrameSeconds7596,0,sizeof(gADPerfFrameSeconds7596));
    self.themeReports=[NSMutableArray array];self.scriptInventory=[NSMutableArray array];
    self.pendingEvals=[NSHashTable weakObjectsHashTable];self.sampleDiagnostics=[NSMutableArray array];
    self.webs=[NSHashTable weakObjectsHashTable];self.controllers=[NSHashTable weakObjectsHashTable];
    self.controllerStarts=[NSMapTable weakToStrongObjectsMapTable];self.controllerTransitions=[NSMutableArray array];
    self.navigationStarts=[NSMapTable weakToStrongObjectsMapTable];self.documents=[NSMutableArray array];self.navigations=[NSMutableArray array];self.injectionTimings=[NSMutableArray array];
    self.otherProbeObserved=gADUIProbeBusy7362||ADSkelActive7339();self.themeEnabledAtArm=gP.enabled;
    self.session=NSUUID.UUID.UUIDString;self.deadline=(now+90)*1000;self.lastFrame=0;self.injected=0;self.failed=0;self.dropped=0;self.enrolled=0;self.webEvalAcks=0;self.webBridgeReports=0;self.webEvalMissing=0;self.webPeriodicSamples=0;self.webPeriodicFailures=0;self.backgroundTask=UIBackgroundTaskInvalid;
    NSString *source=@""
#include "ADPerformance7596.js.inc"
    ;
    self.program=[[source stringByReplacingOccurrencesOfString:@"__SESSION__" withString:[NSString stringWithFormat:@"\"%@\"",self.session]] stringByReplacingOccurrencesOfString:@"__DEADLINE__" withString:[NSString stringWithFormat:@"%.0f",self.deadline]];
    self.navigationScript=[[WKUserScript alloc] initWithSource:self.program injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES inContentWorld:ADPerfWorld7635()];
    NSString *themeSource=@""
#include "ADThemeWork7637.js.inc"
    ;
    themeSource=[[themeSource stringByReplacingOccurrencesOfString:@"__SESSION__" withString:[NSString stringWithFormat:@"\"%@\"",self.session]] stringByReplacingOccurrencesOfString:@"__DEADLINE__" withString:[NSString stringWithFormat:@"%.0f",self.deadline]];
    themeSource=[themeSource stringByReplacingOccurrencesOfString:@"__STYLE_TRIALS__" withString:(self.styleExperiment?@"true":@"false")];
    self.themeScript=[[WKUserScript alloc] initWithSource:themeSource injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    gADPerformanceGeneration7596++;gADPerfStart7596=CACurrentMediaTime();gADPerformanceActive7596=YES;
    [@"running\n" writeToFile:ADPerfPath7596(@".state") atomically:YES encoding:NSUTF8StringEncoding error:nil];
    self.display=[CADisplayLink displayLinkWithTarget:self selector:@selector(frame:)];
    [self.display addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    self.timer=[NSTimer timerWithTimeInterval:90 target:self selector:@selector(expired:) userInfo:nil repeats:NO];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    // v7.641: the asynchronous WKScriptMessageHandler may fail inside Amazon's
    // WebKit content world. While explicitly armed, pull existing JS counters at
    // 5-second intervals instead; no DOM traversal or production polling.
    self.webSampleTimer=[NSTimer timerWithTimeInterval:5 target:self selector:@selector(sampleWeb:) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.webSampleTimer forMode:NSRunLoopCommonModes];
    for(WKWebView *web in ADTrackedWebViews())[self enroll:web];
}
- (void)sampleWeb:(NSTimer *)timer {
    if(!gADPerformanceActive7596||self.finishing||self.writing)return;
    NSString *session=self.session;
    NSUInteger checked=0;
    for(WKWebView *web in self.webs.allObjects){
        if(checked++>=8)break; // bounded diagnostic workload, not all-frame traversal
        if(!web||!web.window||[self.pendingEvals containsObject:web])continue;
        [self.pendingEvals addObject:web];double began=CACurrentMediaTime();BOOL loading=web.loading;
        [web evaluateJavaScript:@"window.__adThemeWork7637 && window.__adThemeWork7637.snapshot()" completionHandler:^(id value,NSError *error){
            if(!error&&gADPerformanceActive7596&&[self.session isEqual:session])[self acceptThemeBody:value main:YES];
        }];
        ADPerfEval7635(web,@"window.__adPerformance7596 && window.__adPerformance7596.snapshotInitial()",^(id value,NSError *error){
            if(!gADPerformanceActive7596||self.finishing||self.writing||![self.session isEqual:session])return;
            [self.pendingEvals removeObject:web];
            NSDictionary *snapshot=[value isKindOfClass:NSDictionary.class]?(NSDictionary *)value:nil;
            if(!error&&[snapshot[@"session"] isEqual:session]){
                self.webPeriodicSamples++;
                [self acceptWebBody:snapshot origin:@"eval"];
            }else {self.webPeriodicFailures++;if(!error)[self inject:web];}
            if(self.sampleDiagnostics.count<128)[self.sampleDiagnostics addObject:@{@"atMs":@((began-gADPerfStart7596)*1000),@"evalMs":@((CACurrentMediaTime()-began)*1000),@"loading":@(loading),@"errorCode":@(error?error.code:0),@"snapshotAck":@(!error&&[snapshot[@"session"] isEqual:session])}];
        });
    }
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
    // Diagnostic only: sample *during* WebKit loading. The older loading guard
    // excluded the exact 18-20 second slow intervals under investigation.
    if(!gADPerformanceActive7596||!web.window||!self.program||[self.pendingEvals containsObject:web])return;
    if(self.injected>=128){self.dropped++;return;}
    [self.pendingEvals addObject:web];
    NSString *session=self.session;
    BOOL wasLoading=web.loading;
    double began=CACurrentMediaTime();
    self.injected++;
    // The JS fixture still uses the old 5s periodic contract. The native
    // caller requests one *immediate* initial report once instrumentation is
    // installed; this does not add an observer or any production polling.
    NSString *script=[self.program stringByAppendingString:@";window.__adPerformance7596 && window.__adPerformance7596.snapshotInitial()"];
    ADPerfEval7635(web,script,^(id value,NSError *error){
        if(![self.session isEqual:session]||self.writing)return;
        [self.pendingEvals removeObject:web];
        if(error)self.failed++;
        // An eval completion is not an acknowledgement of WebKit telemetry.
        // Preserve the returned bounded numeric snapshot even if postMessage
        // failed, the page navigated or its bridge was not installed.
        NSDictionary *snapshot=([value isKindOfClass:NSDictionary.class])?(NSDictionary *)value:nil;
        BOOL acknowledged=!error&&[snapshot[@"session"] isEqual:session];
        if(acknowledged){self.webEvalAcks++;[self acceptWebBody:snapshot origin:@"eval"];}
        else self.webEvalMissing++;
        if(self.injectionTimings.count<128)[self.injectionTimings addObject:@{
            @"atMs":@((began-gADPerfStart7596)*1000),
            @"evalMs":@((CACurrentMediaTime()-began)*1000),
            @"wasLoading":@(wasLoading),@"success":@(!error),@"snapshotAck":@(acknowledged)
        }];else self.dropped++;
    });
}
// Preserve the exact authored script order. During this controlled replacement
// the production removal hook must neither clear receipts nor reinstall scripts.
- (void)attach:(WKUserContentController *)ucc {
    if(!gADPerformanceActive7596||!ucc||!self.themeScript)return;
    if(![self.controllers containsObject:ucc]){
        if(self.controllers.count>=32)return;
        [self inventory:ucc phase:0];
        [ucc addScriptMessageHandler:self contentWorld:ADPerfWorld7635() name:@"adPerformance7596"];
        [ucc addScriptMessageHandler:self name:@"adThemeWork7637"];
        [self.controllers addObject:ucc];
    }
    NSArray *scripts=[ucc.userScripts copy];
    if([scripts containsObject:self.navigationScript]&&[scripts containsObject:self.themeScript])return;
    gADUserScriptRestoreDepth7637++;
    @try {
        [ucc removeAllUserScripts];
        // Both recorders precede production scripts on every subsequent document.
        [ucc addUserScript:self.themeScript];[ucc addUserScript:self.navigationScript];
        for(WKUserScript *script in scripts)if(script!=self.navigationScript&&script!=self.themeScript)[ucc addUserScript:script];
    }@finally{gADUserScriptRestoreDepth7637--;}
}
- (void)inventory:(WKUserContentController *)ucc phase:(NSUInteger)phase {
    if(self.scriptInventory.count>=64)return;
    NSArray *scripts=ucc.userScripts;NSUInteger checked=0,copies=0,chars=0;
    NSHashTable *seen=[NSHashTable weakObjectsHashTable];
    for(WKUserScript *script in scripts){
        if(checked++>=256)break;
        if([seen containsObject:script])copies++;else [seen addObject:script];
        chars+=script.source.length;
    }
    [self.scriptInventory addObject:@{@"phase":@(phase),@"scripts":@(scripts.count),@"duplicateObjects":@(copies),@"sourceChars":@(chars),@"capped":@(scripts.count>256)}];
}
- (void)acceptThemeBody:(NSDictionary *)body main:(BOOL)main {
    if(self.writing||![body isKindOfClass:NSDictionary.class]||![body[@"session"] isEqual:self.session])return;
    NSMutableDictionary *safe=[NSMutableDictionary dictionary];safe[@"mainFrame"]=@(main);
    for(NSString *key in @[@"documentId",@"timeOriginMs",@"route",@"durationMs",@"themeSheets",@"themeRules",@"unreadableSheets",@"adoptedSheets",@"dropped",@"styleMode",@"styleState",@"stylePlanned",@"styleSpentMs"]){
        id value=body[key];if([value isKindOfClass:NSNumber.class]&&isfinite([value doubleValue])&&[value doubleValue]>=0)safe[key]=value;
    }
    for(NSString *key in @[@"metrics",@"slowCalls",@"styleTrials"]){
        NSMutableArray *out=[NSMutableArray array];id entries=body[key];
        if([entries isKindOfClass:NSArray.class])for(id entry in entries){
            if(out.count>=96)break;if(![entry isKindOfClass:NSDictionary.class])continue;
            id name=entry[@"name"];if(![name isKindOfClass:NSString.class]||[name length]>96||!([key isEqual:@"styleTrials"]?[name hasPrefix:@"ad"]:[name hasPrefix:@"s"]))continue;
            const char *letters=[name UTF8String];BOOL valid=YES;
            for(const char *c=letters;*c;c++)if(!((*c>='a'&&*c<='z')||(*c>='A'&&*c<='Z')||(*c>='0'&&*c<='9')||*c=='/'||*c=='#'||*c=='_'||*c=='-')){valid=NO;break;}
            if(!valid)continue;
            NSMutableDictionary *row=[NSMutableDictionary dictionary];row[@"name"]=name;
            for(NSString *field in @[@"count",@"totalMs",@"maxMs",@"atMs",@"durationMs",@"rules",@"disableMs",@"restoreMs",@"failed"]){id n=entry[field];if([n isKindOfClass:NSNumber.class]&&isfinite([n doubleValue])&&[n doubleValue]>=0)row[field]=n;}
            [out addObject:row];
        }
        safe[key]=out;
    }
    if(!safe[@"documentId"])return;
    // Cumulative per-document rows: replace, do not accumulate a growing history.
    for(NSUInteger i=0;i<self.themeReports.count;i++)if([self.themeReports[i][@"documentId"] isEqual:safe[@"documentId"]]&&[self.themeReports[i][@"mainFrame"] isEqual:safe[@"mainFrame"]]&&fabs([self.themeReports[i][@"timeOriginMs"] doubleValue]-[safe[@"timeOriginMs"] doubleValue])<=5.0){
        if([self.themeReports[i][@"durationMs"] doubleValue]<=[safe[@"durationMs"] doubleValue])[self.themeReports replaceObjectAtIndex:i withObject:safe];return;
    }
    if(self.themeReports.count<128)[self.themeReports addObject:safe];else self.dropped++;
}
- (void)enroll:(WKWebView *)web {
    if(!gADPerformanceActive7596||!web||!web.window||[self.webs containsObject:web])return;
    if(self.enrolled>=32){self.dropped++;return;}
    WKUserContentController *ucc=web.configuration.userContentController;
    [self attach:ucc];
    [self.webs addObject:web];self.enrolled++;
    [web addObserver:self forKeyPath:@"loading" options:NSKeyValueObservingOptionNew context:kADPerfLoading7596];
    if(web.loading)[self.navigationStarts setObject:@(CACurrentMediaTime()) forKey:web];
    [self inject:web];
}
- (void)observeValueForKeyPath:(NSString *)key ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if(context!=kADPerfLoading7596){[super observeValueForKeyPath:key ofObject:object change:change context:context];return;}
    if(!gADPerformanceActive7596)return;
    WKWebView *web=(WKWebView *)object;
    if(web.loading){[self.navigationStarts setObject:@(CACurrentMediaTime()) forKey:web];[self inject:web];return;}
    NSNumber *start=[self.navigationStarts objectForKey:web];
    if(start){if(self.navigations.count<128)[self.navigations addObject:@{ @"atMs":@((start.doubleValue-gADPerfStart7596)*1000),@"loadingMs":@((CACurrentMediaTime()-start.doubleValue)*1000) }];else self.dropped++;[self.navigationStarts removeObjectForKey:web];}
    [self inject:web];
}
- (void)userContentController:(WKUserContentController *)ucc didReceiveScriptMessage:(WKScriptMessage *)message {
    if([message.name isEqual:@"adThemeWork7637"]){
        if((gADPerformanceActive7596||self.finishing)&&!self.writing)[self acceptThemeBody:message.body main:message.frameInfo.mainFrame];return;
    }
    if((!gADPerformanceActive7596&&!self.finishing)||self.writing||![message.name isEqual:@"adPerformance7596"]||!message.frameInfo.mainFrame)return;
    NSDictionary *body=[message.body isKindOfClass:NSDictionary.class]?message.body:nil;
    if(![body[@"session"] isEqual:self.session])return;
    self.webBridgeReports++;
    [self acceptWebBody:body origin:@"message"];
}
- (void)acceptWebBody:(NSDictionary *)body origin:(NSString *)origin {
    if(!body||self.writing||![body[@"session"] isEqual:self.session])return;
    // Whitelist numeric aggregates; never persist arbitrary page message strings/content.
    NSMutableDictionary *safe=[NSMutableDictionary dictionary];
    for(NSString *key in @[@"timeOriginMs",@"durationMs",@"resourceEntriesDropped",@"pendingInputs",@"inputDropped",@"scrollGestures",@"scrollStarted",@"bridgeAttempted",@"bridgeFailed"]){id value=body[key];if([value isKindOfClass:NSNumber.class]&&isfinite([value doubleValue]))safe[key]=value;}
    for(NSString *key in @[@"frames",@"inputToNextRAF",@"eventTiming",@"longTasks",@"resources",@"scrollFromMove",@"scrollFromTouch",@"inputArrival",@"inputTaskDelay",@"eventLoopLag"]){
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
    NSString *reason=body[@"reason"];safe[@"reason"]=[@[@"deadline",@"pagehide",@"native-stop",@"replaced",@"snapshot"] containsObject:reason?:@""]?reason:@"unknown";
    safe[@"receivedAtMs"]=@((CACurrentMediaTime()-gADPerfStart7596)*1000);
    safe[@"origin"]=[origin isEqual:@"eval"]?@"eval":@"message";
    // Report carries only an opaque numeric page-instance key (never URLs/content).
    NSMutableDictionary *kinds=[NSMutableDictionary dictionary];
    for(NSString *k in @[@"pointerdown",@"pointerup",@"keydown",@"click",@"touchstart"]){id n=[body[@"inputKinds"] isKindOfClass:NSDictionary.class]?body[@"inputKinds"][k]:nil;if([n isKindOfClass:NSNumber.class]&&isfinite([n doubleValue])&&[n doubleValue]>=0)kinds[k]=n;}
    safe[@"inputKinds"]=kinds;
    NSMutableArray *slow=[NSMutableArray array];
    if([body[@"slowEvents"] isKindOfClass:NSArray.class])for(id e in body[@"slowEvents"]){if(slow.count>=64)break;if(![e isKindOfClass:NSDictionary.class])continue;NSMutableDictionary *v=[NSMutableDictionary dictionary];for(NSString *k in @[@"atMs",@"delayMs",@"kind"]){id n=e[k];if([n isKindOfClass:NSNumber.class]&&isfinite([n doubleValue])&&[n doubleValue]>=0)v[k]=n;}if(v.count==3)[slow addObject:v];}
    safe[@"slowEvents"]=slow;
    // Diagnostics are capped; the report consolidates each page's latest snapshot.
    id docId=body[@"documentId"];
    if([docId isKindOfClass:NSNumber.class]&&[docId doubleValue]>=0&&[docId doubleValue]<1000000000)safe[@"documentId"]=docId;
    if(self.documents.count<128)[self.documents addObject:safe];else {
        // Keep a final cumulative sample even after the snapshot ring fills.
        BOOL replaced=NO;
        if(safe[@"documentId"])for(NSUInteger i=0;i<self.documents.count;i++)if([self.documents[i][@"documentId"] isEqual:safe[@"documentId"]]){[self.documents replaceObjectAtIndex:i withObject:safe];replaced=YES;break;}
        if(!replaced)self.dropped++;
    }
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
    [self.display invalidate];self.display=nil;[self.timer invalidate];self.timer=nil;[self.webSampleTimer invalidate];self.webSampleTimer=nil;
    double duration=(CACurrentMediaTime()-gADPerfStart7596)*1000;
    self.backgroundTask=[UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{[self write:reason duration:duration];}];
    for(WKWebView *web in self.webs.allObjects){
        [web removeObserver:self forKeyPath:@"loading" context:kADPerfLoading7596];
        NSString *session=self.session;
        [web evaluateJavaScript:@"window.__adThemeWork7637 && window.__adThemeWork7637.stop()" completionHandler:^(id value,NSError *error){
            if(!error&&self.finishing&&[self.session isEqual:session])[self acceptThemeBody:value main:YES];
        }];
        ADPerfEval7635(web,@"window.__adPerformance7596 && (window.__adPerformance7596.stop('native-stop') || window.__adPerformance7596.snapshotInitial())",^(id value,NSError *error){
            if(!self.writing&&self.finishing&&[session isEqual:self.session]&&!error&&[value isKindOfClass:NSDictionary.class]&&[value[@"session"] isEqual:session])[self acceptWebBody:value origin:@"eval"];
        });
    }
    // Bounded grace for WebKit messages, including the last foreground document.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self write:reason duration:duration];});
}
- (void)write:(NSString *)reason duration:(double)duration {
    if(!self.finishing||self.writing)return;self.writing=YES;
    for(WKUserContentController *ucc in self.controllers.allObjects){
        [ucc removeScriptMessageHandlerForName:@"adPerformance7596" contentWorld:ADPerfWorld7635()];
        // Public WebKit API has no individual removal: preserve every other script, in order.
        [ucc removeScriptMessageHandlerForName:@"adThemeWork7637"];
        NSArray *scripts=[ucc.userScripts copy];
        if([scripts containsObject:self.navigationScript]||[scripts containsObject:self.themeScript]){
            gADUserScriptRestoreDepth7637++;
            @try {
                [ucc removeAllUserScripts];
                for(WKUserScript *script in scripts)if(script!=self.themeScript){if(script!=self.navigationScript)[ucc addUserScript:script];}
            }@finally{gADUserScriptRestoreDepth7637--;}
        }
        [self inventory:ucc phase:1];
    }
    self.navigationScript=nil;self.themeScript=nil;
    NSArray *names=@[@"eventDispatchInclusive",@"reactLayoutTheme",@"imageLayoutTheme",@"imageCommitInclusive",@"reactTextCommitInclusive",@"viewBackgroundInclusive",@"labelAttributedCommitInclusive",@"childFrameRepairRoundTrip"];
    NSMutableDictionary *lanes=[NSMutableDictionary dictionary];for(unsigned i=0;i<ADPerfLaneCount;i++)lanes[names[i]]=ADPerfMetricJSON7596(gADPerfLanes7596[i]);
    NSMutableArray *seconds=[NSMutableArray array];for(unsigned i=0;i<90;i++)[seconds addObject:@(gADPerfFrameSeconds7596[i])];
    NSDictionary *report=@{ @"version":@AD_VERSION,@"schema":@1,@"session":self.session,@"endReason":reason,@"durationMs":@(duration),@"nativeFrames":ADPerfMetricJSON7596(gADPerfFrames7596),@"touchEventAge":ADPerfMetricJSON7596(gADPerfInputAge7596),@"frameGapsOver50MsBySecond":seconds,@"lanes":lanes,@"webDocuments":[self.documents copy],@"styleExperiment":@(self.styleExperiment),@"themeWork":[self.themeReports copy],@"userScriptInventory":[self.scriptInventory copy],@"webLoadingIntervals":[self.navigations copy],@"controllerTransitions":[self.controllerTransitions copy],@"otherDiagnosticObserved":@(self.otherProbeObserved),@"themeEnabledAtArm":@(self.themeEnabledAtArm),@"enrolledWebViews":@(self.enrolled),@"injectionAttempts":@(self.injected),@"injectionErrors":@(self.failed),@"injectionTimings":[self.injectionTimings copy],@"webEvalAcks":@(self.webEvalAcks),@"webEvalMissing":@(self.webEvalMissing),@"webBridgeReports":@(self.webBridgeReports),@"sampleDiagnostics":[self.sampleDiagnostics copy],@"webPeriodicSamples":@(self.webPeriodicSamples),@"webPeriodicFailures":@(self.webPeriodicFailures),@"droppedRecords":@(self.dropped),@"unfinishedLoadingIntervals":@(self.navigationStarts.count),@"coverage":@"Native foreground only. Web aggregates are returned by eval as a fallback if the message bridge fails, and are pulled every five seconds while armed; Theme install/listener timings include child documents when document-start enrollment succeeds; input timings remain main-frame only. No cold-start or server attribution. Theme timings are inclusive and do not measure deferred CSS rendering cost. Child-frame repair round trips include WebContent queueing and IPC, not just JavaScript. Existing loaded documents have no retroactive theme timings. Missing Web reports are not zero latency. Inclusive lanes overlap; do not sum. RAF is not presentation latency. Controller appearance intervals include animations. Diagnostic overhead is included." };
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
static void ADPerformanceAttach7637(id controller){if(gADPerformanceActive7596)[gADPerformance7596 attach:(WKUserContentController *)controller];}
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
