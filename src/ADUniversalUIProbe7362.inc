// v7.439 universal cross-frame UI probe architecture: FULL/VIEWPORT cover native, main Web DOM, and every injected child/SafeFrame DOM.
// Exactly two UI forensics categories remain:
//   1) screenshot -> FULL finite Web/native renderer sweep + final full inventories
//   2) scripts/ui-probe.sh arm -> current VIEWPORT only, then one SIGUSR2
// Both categories are route/tab agnostic. They inspect every on-screen WKWebView, every
// document frame (including cross-origin SafeFrames through a dormant all-frame bridge),
// and the current UIKit/React hierarchy instead of dispatching to menu-specific scanners.
// Normal runtime adds only one inert message listener per Web document frame; there is no
// MutationObserver, timer, RAF, web-scroll listener, polling loop, or recurring hierarchy walk.
// The screenshot notification and armed SIGUSR2 remain the only capture triggers.

static dispatch_source_t gADThreeTabProbeSignal7254=nil; // retained symbol name; now universal
static BOOL gADUIProbeBusy7362=NO;
static BOOL gADUIProbePartial7446=NO;
static NSTimeInterval gADUIProbeDeadline7446=0;
static NSHashTable *gADUIFailedWebs7446=nil;
static NSUInteger gADUIFramePayloads7446=0;
static BOOL gADUIExpectedFrames7446=NO;
static NSMutableSet *gADUIFrameBatches7446=nil;
static BOOL ADUIExpired7446(void){return NSDate.date.timeIntervalSince1970>gADUIProbeDeadline7446;}
static NSUInteger gADUIFullRun7362=0;
static NSUInteger gADUIViewportRun7362=0;
static const unsigned long long kADUIFullCap7362=192ULL*1024ULL*1024ULL;
static const unsigned long long kADUIViewportCap7362=48ULL*1024ULL*1024ULL;

static NSString *ADUIHash7362(NSString *s);

static NSString *ADUIDocuments7362(void){
    static NSString *docs=nil; static dispatch_once_t once;
    dispatch_once(&once,^{
        NSString *p=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject];
        docs=p.length?p:NSTemporaryDirectory();
    });
    return docs;
}

static NSString *ADUISafe7362(NSString *x){
    if(!x.length)return @"";
    @try {
        NSString *s=[x stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        s=[s stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        s=[s stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        s=[s stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
        if(s.length>180)s=[[s substringToIndex:120] stringByAppendingFormat:@"…#%@",ADUIHash7362(s)];
        return s;
    } @catch(...) { return @"?"; }
}

static NSString *ADUIHash7362(NSString *s){
    if(!s)s=@"";
    uint32_t h=2166136261u;
    @try { for(NSUInteger i=0;i<s.length;i++){ h^=(uint32_t)[s characterAtIndex:i]; h*=16777619u; } } @catch(...) {}
    return [NSString stringWithFormat:@"%08x",h];
}

static NSString *ADUIColor7362(UIColor *c){
    if(!c)return @"nil";
    @try {
        CGFloat r=0,g=0,b=0,a=0,w=0;
        UIColor *x=c;
        if([x respondsToSelector:@selector(resolvedColorWithTraitCollection:)])x=[x resolvedColorWithTraitCollection:UIScreen.mainScreen.traitCollection];
        if([x getRed:&r green:&g blue:&b alpha:&a])return [NSString stringWithFormat:@"rgba(%.3f,%.3f,%.3f,%.3f)",r,g,b,a];
        if([x getWhite:&w alpha:&a])return [NSString stringWithFormat:@"white(%.3f,%.3f)",w,a];
        return ADUISafe7362([x description]);
    } @catch(...) { return @"?"; }
}

static NSString *ADUICG7362(CGColorRef c){
    if(!c)return @"nil";
    @try { return ADUIColor7362([UIColor colorWithCGColor:c]); } @catch(...) { return @"?"; }
}

static NSString *ADUIRect7362(CGRect r){
    return [NSString stringWithFormat:@"(%.1f,%.1f %.1fx%.1f)",r.origin.x,r.origin.y,r.size.width,r.size.height];
}

static BOOL ADUIViewActuallyVisible7362(UIView *v){
    if(!v||!v.window||v.hidden||v.alpha<0.005)return NO;
    @try {
        for(UIView *n=v.superview;n;n=n.superview)if(n.hidden||n.alpha<0.005)return NO;
        CGRect wr=[v convertRect:v.bounds toView:nil];
        return wr.size.width>=0.1&&wr.size.height>=0.1&&CGRectIntersectsRect(wr,UIScreen.mainScreen.bounds);
    } @catch(...) { return NO; }
}

static NSString *ADUITextMeta7362(UIView *v){
    if(!v)return @"text=0";
    @try {
        NSString *text=nil; UIColor *color=nil; UIFont *font=nil; NSAttributedString *attr=nil;
        if([v isKindOfClass:[UILabel class]]){ UILabel *x=(UILabel *)v;text=x.text;color=x.textColor;font=x.font;attr=x.attributedText; }
        else if([v isKindOfClass:[UITextField class]]){ UITextField *x=(UITextField *)v;text=x.text;color=x.textColor;font=x.font;attr=x.attributedText; }
        else if([v isKindOfClass:[UITextView class]]){ UITextView *x=(UITextView *)v;text=x.text;color=x.textColor;font=x.font;attr=x.attributedText; }
        else {
            id ts=nil; @try { ts=[v valueForKey:@"textStorage"]; } @catch(...) {}
            if([ts isKindOfClass:[NSAttributedString class]])attr=(NSAttributedString *)ts;
        }
        NSUInteger len=text.length; if(!len&&attr)len=attr.length;
        if(!len)return @"text=0";
        NSString *hash=ADUIHash7362(text?:attr.string?:@"");
        NSMutableArray *runs=[NSMutableArray array];
        if(attr.length){
            [attr enumerateAttributesInRange:NSMakeRange(0,attr.length) options:0 usingBlock:^(NSDictionary *attrs,NSRange range,BOOL *stop){
                if(runs.count>=12){*stop=YES;return;}
                UIColor *fg=attrs[NSForegroundColorAttributeName]; UIColor *bg=attrs[NSBackgroundColorAttributeName]; UIFont *rf=attrs[NSFontAttributeName];
                [runs addObject:[NSString stringWithFormat:@"%lu:%lu:fg=%@:bg=%@:font=%@/%.1f",(unsigned long)range.location,(unsigned long)range.length,ADUIColor7362(fg),ADUIColor7362(bg),ADUISafe7362(rf.fontName),rf.pointSize]];
            }];
        }
        return [NSString stringWithFormat:@"text=1 len=%lu hash=%@ color=%@ font=%@/%.1f runs=[%@]",(unsigned long)len,hash,ADUIColor7362(color),ADUISafe7362(font.fontName),font.pointSize,[runs componentsJoinedByString:@","]];
    } @catch(...) { return @"text=err"; }
}

static NSString *ADUIImageMeta7362(UIView *v){
    if(![v isKindOfClass:[UIImageView class]])return @"img=0";
    @try {
        UIImageView *iv=(UIImageView *)v; UIImage *im=iv.image;
        if(!im)return [NSString stringWithFormat:@"img=1 image=0 mode=%ld",(long)iv.contentMode];
        return [NSString stringWithFormat:@"img=1 image=1 px=(%.0fx%.0f) scale=%.2f render=%ld cap=(%.1f,%.1f,%.1f,%.1f) mode=%ld highlighted=%d",
                im.size.width*im.scale,im.size.height*im.scale,im.scale,(long)im.renderingMode,im.capInsets.top,im.capInsets.left,im.capInsets.bottom,im.capInsets.right,(long)iv.contentMode,iv.highlighted?1:0];
    } @catch(...) { return @"img=err"; }
}

static NSString *ADUIControlMeta7362(UIView *v){
    if(![v isKindOfClass:[UIControl class]])return @"control=0";
    @try {
        UIControl *c=(UIControl *)v; NSMutableString *m=[NSMutableString stringWithFormat:@"control=1 enabled=%d selected=%d highlighted=%d state=%lu",c.enabled?1:0,c.selected?1:0,c.highlighted?1:0,(unsigned long)c.state];
        if([c isKindOfClass:[UIButton class]]){
            UIButton *b=(UIButton *)c; NSString *t=[b titleForState:c.state]?:[b titleForState:UIControlStateNormal]?:@""; UIImage *im=[b imageForState:c.state]?:[b imageForState:UIControlStateNormal]; UIImage *bg=[b backgroundImageForState:c.state]?:[b backgroundImageForState:UIControlStateNormal];
            [m appendFormat:@" buttonTitleLen=%lu buttonTitleHash=%@ titleColor=%@ image=%d bgImage=%d",(unsigned long)t.length,ADUIHash7362(t),ADUIColor7362([b titleColorForState:c.state]?:[b titleColorForState:UIControlStateNormal]),im?1:0,bg?1:0];
        }
        return m;
    } @catch(...) { return @"control=err"; }
}

static NSString *ADUIEdges7362(UIView *v){
    @try {
        NSMutableArray *a=[NSMutableArray array]; NSArray *keys=@[@"borderTopWidth",@"borderRightWidth",@"borderBottomWidth",@"borderLeftWidth",@"borderWidth",@"borderRadius"];
        for(NSString *k in keys){ id x=nil; @try{x=[v valueForKey:k];}@catch(...){} if([x isKindOfClass:[NSNumber class]])[a addObject:[NSString stringWithFormat:@"%@=%.2f",k,[x doubleValue]]]; }
        return a.count?[NSString stringWithFormat:@"rct={%@}",[a componentsJoinedByString:@","]]:@"rct=0";
    } @catch(...) { return @"rct=err"; }
}

static NSString *ADUILayerMeta7362(UIView *v){
    if(!v.layer)return @"layer=0";
    @try {
        CALayer *l=v.layer; NSMutableString *m=[NSMutableString stringWithFormat:@"layer=1 class=%@ name=%@ frame=%@ bg=%@ border=%.2f/%@ radius=%.2f opacity=%.2f z=%.1f contents=%d masks=%d shadow=%@/%.2f/%.2f sublayers=%lu",
            NSStringFromClass(l.class),ADUISafe7362(l.name),ADUIRect7362(l.frame),ADUICG7362(l.backgroundColor),l.borderWidth,ADUICG7362(l.borderColor),l.cornerRadius,l.opacity,l.zPosition,l.contents?1:0,l.masksToBounds?1:0,ADUICG7362(l.shadowColor),l.shadowOpacity,l.shadowRadius,(unsigned long)l.sublayers.count];
        NSUInteger n=MIN((NSUInteger)10,l.sublayers.count); for(NSUInteger i=0;i<n;i++){ CALayer *s=l.sublayers[i]; [m appendFormat:@" | sub%lu=%@/%@ f=%@ bg=%@ b=%.1f/%@ r=%.1f op=%.2f z=%.1f contents=%d mask=%d",(unsigned long)i,NSStringFromClass(s.class),ADUISafe7362(s.name),ADUIRect7362(s.frame),ADUICG7362(s.backgroundColor),s.borderWidth,ADUICG7362(s.borderColor),s.cornerRadius,s.opacity,s.zPosition,s.contents?1:0,s.mask?1:0]; }
        return m;
    } @catch(...) { return @"layer=err"; }
}

static NSString *ADUIChain7362(UIView *v){
    NSMutableArray *a=[NSMutableArray array];
    @try { for(UIView *n=v;n&&a.count<10;n=n.superview){ NSString *cn=NSStringFromClass(n.class)?:@"?"; NSString *aid=ADUISafe7362(n.accessibilityIdentifier); [a addObject:aid.length?[NSString stringWithFormat:@"%@#%@",cn,aid]:cn]; } } @catch(...) {}
    return [a componentsJoinedByString:@"<-"];
}

static NSString *ADUINativeSnapshot7362(BOOL viewportOnly){
    NSMutableString *m=[NSMutableString string]; CGRect screen=UIScreen.mainScreen.bounds; NSUInteger visited=0,logged=0,windows=0;
    @try {
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.005)continue; windows++;
            NSMutableArray *q=[NSMutableArray arrayWithObject:@{ @"v":w,@"d":@0 }];
            while(q.count&&visited<(viewportOnly?9000:26000)&&logged<(viewportOnly?7000:24000)){
                NSDictionary *it=q.firstObject;[q removeObjectAtIndex:0]; UIView *v=it[@"v"]; NSUInteger d=[it[@"d"] unsignedIntegerValue]; if(!v)continue; visited++;
                CGRect wr=CGRectZero; @try{wr=[v convertRect:v.bounds toView:nil];}@catch(...){}
                BOOL on=!v.hidden&&v.alpha>=0.005&&wr.size.width>=0.1&&wr.size.height>=0.1&&CGRectIntersectsRect(wr,screen);
                if(!viewportOnly||on){
                    NSString *cn=NSStringFromClass(v.class)?:@"?",*aid=ADUISafe7362(v.accessibilityIdentifier); CGAffineTransform t=v.transform;
                    [m appendFormat:@"N d=%lu ptr=%p parent=%p cls=%@ aid=\"%@\" win=%@ onscreen=%d hidden=%d alpha=%.3f user=%d clips=%d transform=(%.3f,%.3f,%.3f,%.3f,%.1f,%.1f) bg=%@ tint=%@ layerBg=%@ layerBorder=%.2f/%@ radius=%.2f subviews=%lu traits=%llu chain=\"%@\" %@ %@ %@ %@\n",
                        (unsigned long)d,v,v.superview,cn,aid,ADUIRect7362(wr),on?1:0,v.hidden?1:0,v.alpha,v.userInteractionEnabled?1:0,v.clipsToBounds?1:0,t.a,t.b,t.c,t.d,t.tx,t.ty,ADUIColor7362(v.backgroundColor),ADUIColor7362(v.tintColor),ADUICG7362(v.layer.backgroundColor),v.layer.borderWidth,ADUICG7362(v.layer.borderColor),v.layer.cornerRadius,(unsigned long)v.subviews.count,(unsigned long long)v.accessibilityTraits,ADUIChain7362(v),ADUITextMeta7362(v),ADUIImageMeta7362(v),ADUIControlMeta7362(v),ADUIEdges7362(v)];
                    [m appendFormat:@"L ptr=%p %@\n",v,ADUILayerMeta7362(v)]; logged++;
                }
                if(q.count<15000)for(UIView *c in v.subviews)[q addObject:@{ @"v":c,@"d":@(d+1) }];
            }
        }
    } @catch(NSException *e) { [m appendFormat:@"NATIVE_EXCEPTION %@\n",ADUISafe7362(e.reason)]; }
    [m appendFormat:@"NATIVE_END mode=%@ windows=%lu visited=%lu logged=%lu truncated=%d\n",viewportOnly?@"viewport":@"full",(unsigned long)windows,(unsigned long)visited,(unsigned long)logged,(visited>=(viewportOnly?9000:26000)||logged>=(viewportOnly?7000:24000))?1:0];
    return m;
}

static NSArray *ADUIWebViews7362(void){
    NSMutableArray *out=[NSMutableArray array]; NSMutableSet *seen=[NSMutableSet set]; CGRect screen=UIScreen.mainScreen.bounds;
    @try {
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.005)continue; NSMutableArray *q=[NSMutableArray arrayWithObject:w]; NSUInteger n=0;
            while(q.count&&n++<12000){ UIView *v=q.firstObject;[q removeObjectAtIndex:0]; if(!v)continue;
                if([v isKindOfClass:[WKWebView class]]&&ADUIViewActuallyVisible7362(v)){
                    NSString *key=[NSString stringWithFormat:@"%p",v]; if(![seen containsObject:key]){[seen addObject:key];[out addObject:v];}
                }
                if(q.count<11000)for(UIView *c in v.subviews)[q addObject:c];
            }
        }
        for(WKWebView *wv in ADTrackedWebViews()){
            if(!wv||![wv isKindOfClass:[WKWebView class]]||!ADUIViewActuallyVisible7362(wv))continue; NSString *key=[NSString stringWithFormat:@"%p",wv]; if(![seen containsObject:key]){[seen addObject:key];[out addObject:wv];}
        }
    } @catch(...) {}
    return out;
}

static NSString *ADUIProbePath7362(BOOL viewportOnly,NSUInteger run){
    @try {
        static NSDateFormatter *f=nil;static dispatch_once_t once;dispatch_once(&once,^{f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.dateFormat=@"yyyyMMdd-HHmmss-SSS";});
        NSString *stamp=nil;@synchronized(f){f.timeZone=[NSTimeZone localTimeZone];stamp=[f stringFromDate:[NSDate date]];}
        NSString *stem=viewportOnly?@"ui-viewport-probe":@"ui-full-probe";
        NSString *name=[NSString stringWithFormat:@"AmazonDark-v7.446-%@-%@-r%lu.txt",stem,stamp?:@"unknown",(unsigned long)run];
        return [ADUIDocuments7362() stringByAppendingPathComponent:name];
    } @catch(...) { return [NSTemporaryDirectory() stringByAppendingPathComponent:@"AmazonDark-v7.446-ui-probe.txt"]; }
}

static NSString *ADUIStatePath7445(BOOL viewportOnly){
    NSString *name=viewportOnly?@"AmazonDark-v7.446-ui-viewport.state":@"AmazonDark-v7.446-ui-full.state";
    return [ADUIDocuments7362() stringByAppendingPathComponent:name];
}
static void ADUIWriteState7445(BOOL viewportOnly,NSString *state,NSString *path){
    @try {
        NSString *name=path.lastPathComponent?:@"";
        NSString *line=[NSString stringWithFormat:@"%@ %.0f %@\n",state?:@"unknown",NSDate.date.timeIntervalSince1970,name];
        [line writeToFile:ADUIStatePath7445(viewportOnly) atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } @catch(...) {}
}

static void ADUIAppend7362(NSString *path,NSString *text,unsigned long long cap){
    if(!path.length||!text.length)return;
    @try {
        NSFileManager *fm=NSFileManager.defaultManager; [fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        unsigned long long cur=[[[fm attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] unsignedLongLongValue]; unsigned long long bodyCap=cap>8192ULL?cap-8192ULL:cap; if(cur>=bodyCap){gADUIProbePartial7446=YES;return;}
        NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding]; unsigned long long rem=bodyCap-cur; if((unsigned long long)d.length>rem){gADUIProbePartial7446=YES;d=[d subdataWithRange:NSMakeRange(0,(NSUInteger)rem)];}
        if(![fm fileExistsAtPath:path]){[d writeToFile:path atomically:YES];return;} NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:path];if(h){[h seekToEndOfFile];[h writeData:d];[h closeFile];}
    } @catch(...) {}
}

static NSString *gADUIProbeActivePath7433=nil;
static unsigned long long gADUIProbeActiveCap7433=0;
static NSString *gADUIProbeActiveNonce7433=nil;

@interface ADUniversalUIBridge7433 : NSObject <WKScriptMessageHandler>
@property(nonatomic,strong) NSMutableDictionary *pending;
@end
static ADUniversalUIBridge7433 *gADUniversalUIBridge7433=nil;

@implementation ADUniversalUIBridge7433
- (void)userContentController:(WKUserContentController *)ucc didReceiveScriptMessage:(WKScriptMessage *)message {
    @try {
        if(![message.name isEqualToString:@"adUniversalUI7433"]||![message.body isKindOfClass:NSDictionary.class])return;
        NSDictionary *b=(NSDictionary *)message.body; NSString *nonce=[b[@"nonce"] isKindOfClass:NSString.class]?b[@"nonce"]:nil;
        if(!nonce.length||!gADUIProbeActiveNonce7433.length||![nonce isEqualToString:gADUIProbeActiveNonce7433]||!gADUIProbeActivePath7433.length)return;
        NSString *capture=[b[@"captureId"] isKindOfClass:NSString.class]?b[@"captureId"]:@"?";
        NSString *frame=[b[@"frameId"] isKindOfClass:NSString.class]?b[@"frameId"]:@"?";
        NSString *mode=[b[@"mode"] isKindOfClass:NSString.class]?b[@"mode"]:@"?";
        NSString *phase=[b[@"phase"] isKindOfClass:NSString.class]?b[@"phase"]:@"?";
        NSInteger depth=[b[@"depth"] respondsToSelector:@selector(integerValue)]?[b[@"depth"] integerValue]:0;
        NSInteger step=[b[@"step"] respondsToSelector:@selector(integerValue)]?[b[@"step"] integerValue]:0;
        NSInteger seq=[b[@"seq"] respondsToSelector:@selector(integerValue)]?[b[@"seq"] integerValue]:-1;
        NSInteger total=[b[@"total"] respondsToSelector:@selector(integerValue)]?[b[@"total"] integerValue]:0;
        NSString *payload=[b[@"payload"] isKindOfClass:NSString.class]?b[@"payload"]:nil;
        if(capture.length>240||frame.length>120||mode.length>24||phase.length>96||depth<0||depth>32||step<0||step>500||seq<0||total<1||total>96||seq>=total||!payload||payload.length>100000)return;
        if(!self.pending)self.pending=[NSMutableDictionary dictionary];
        if(self.pending.count>96)[self.pending removeAllObjects];
        NSString *key=[NSString stringWithFormat:@"%@|%@|%@",nonce,capture,frame]; NSMutableDictionary *item=self.pending[key];
        if(!item){NSMutableArray *chunks=[NSMutableArray arrayWithCapacity:(NSUInteger)total];for(NSInteger i=0;i<total;i++)[chunks addObject:NSNull.null];item=[@{ @"chunks":chunks,@"total":@(total),@"received":@0,@"capture":capture,@"frame":frame,@"mode":mode,@"phase":phase,@"depth":@(depth),@"step":@(step) } mutableCopy];self.pending[key]=item;}
        if([item[@"total"] integerValue]!=total)return; NSMutableArray *chunks=item[@"chunks"]; if(seq>=(NSInteger)chunks.count)return;
        if(chunks[(NSUInteger)seq]==NSNull.null){chunks[(NSUInteger)seq]=payload;item[@"received"]=@([item[@"received"] integerValue]+1);}
        if([item[@"received"] integerValue]!=total)return;
        NSMutableString *joined=[NSMutableString string];for(id x in chunks)if([x isKindOfClass:NSString.class])[joined appendString:x];
        WKWebView *wv=message.webView; CGRect wr=CGRectZero;@try{if(wv)wr=[wv convertRect:wv.bounds toView:nil];}@catch(...){}
        NSString *head=[NSString stringWithFormat:@"\n--- CROSS_FRAME_DOM frame=%@ depth=%ld mode=%@ phase=%@ step=%ld mainFrame=%d webView=%p webFrame=%@ chunks=%ld bytes=%lu ---\n",ADUISafe7362(frame),(long)depth,ADUISafe7362(mode),ADUISafe7362(phase),(long)step,message.frameInfo.mainFrame?1:0,wv,ADUIRect7362(wr),(long)total,(unsigned long)[joined lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
        id frameData=[NSJSONSerialization JSONObjectWithData:[joined dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        if([frameData isKindOfClass:NSDictionary.class]){
            NSString *batchKey=[NSString stringWithFormat:@"%@|%@|%ld",frame,phase,(long)step];
            if([frameData[@"more"] boolValue])[gADUIFrameBatches7446 addObject:batchKey];else [gADUIFrameBatches7446 removeObject:batchKey];
            if([frameData[@"counts"][@"truncated"] boolValue]||frameData[@"error"])gADUIProbePartial7446=YES;
        }
        gADUIFramePayloads7446++;ADUIAppend7362(gADUIProbeActivePath7433,head,gADUIProbeActiveCap7433);ADUIAppend7362(gADUIProbeActivePath7433,joined,gADUIProbeActiveCap7433);ADUIAppend7362(gADUIProbeActivePath7433,@"\n--- END CROSS_FRAME_DOM ---\n",gADUIProbeActiveCap7433);
        [self.pending removeObjectForKey:key];
    } @catch(NSException *e) { if(gADUIProbeActivePath7433.length)ADUIAppend7362(gADUIProbeActivePath7433,[NSString stringWithFormat:@"CROSS_FRAME_HANDLER_EXCEPTION %@\n",ADUISafe7362(e.reason)],gADUIProbeActiveCap7433); }
}
@end

static void ADUIProbeAttach7362(WKUserContentController *ucc){
    if(!ucc||!gP.enabled)return;
    @try {
        WKUserScript *old=objc_getAssociatedObject(ucc,kADUniversalProbeUS7433); if(old&&[ucc.userScripts containsObject:old])return;
        if(!gADUniversalUIBridge7433){gADUniversalUIBridge7433=[ADUniversalUIBridge7433 new];gADUniversalUIBridge7433.pending=[NSMutableDictionary dictionary];}
        @try{[ucc removeScriptMessageHandlerForName:@"adUniversalUI7433"];}@catch(...){}
        [ucc addScriptMessageHandler:gADUniversalUIBridge7433 name:@"adUniversalUI7433"];
        static NSString *source=nil;static dispatch_once_t once;dispatch_once(&once,^{static const char script[]=
#include "ADUniversalUIProbe7362.frame.js.inc"
        ;source=[[NSString alloc] initWithBytes:script length:sizeof(script)-1 encoding:NSUTF8StringEncoding];});
        WKUserScript *us=[[WKUserScript alloc] initWithSource:source?:@"" injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
        [ucc addUserScript:us];objc_setAssociatedObject(ucc,kADUniversalProbeUS7433,us,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}

static void ADUIAppendTerminal7364(NSString *path,NSString *text,unsigned long long cap){
    if(!path.length||!text.length)return;
    @try {
        NSFileManager *fm=NSFileManager.defaultManager;unsigned long long cur=[[[fm attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] unsignedLongLongValue];if(cur>=cap)return;NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding];unsigned long long rem=cap-cur;if((unsigned long long)d.length>rem){gADUIProbePartial7446=YES;d=[d subdataWithRange:NSMakeRange(0,(NSUInteger)rem)];}
        if(![fm fileExistsAtPath:path]){[d writeToFile:path atomically:YES];return;}NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:path];if(h){[h seekToEndOfFile];[h writeData:d];[h closeFile];}
    } @catch(...) {}
}

static NSString *ADUIWebJS7364(NSString *mode,NSString *phase,NSUInteger step){
    static NSString *base=nil;static dispatch_once_t once;dispatch_once(&once,^{
        static const char script[]=
#include "ADUniversalUIProbe7362.js.inc"
        ;
        base=[[NSString alloc] initWithBytes:script length:sizeof(script)-1 encoding:NSUTF8StringEncoding];
    });
    NSString *m=[mode isEqualToString:@"viewport"]?@"viewport":@"full";
    NSString *p=phase.length?phase:@"unknown";
    return [NSString stringWithFormat:@"window.__adUIProbeMode7362='%@';window.__adUIProbePhase7364='%@';window.__adUIProbeStep7364=%lu;window.__adUIProbeNonce7433='%@';%@",m,p,(unsigned long)step,gADUIProbeActiveNonce7433?:@"",base?:@""];
}
static BOOL ADUIAncestorClassContains7364(UIView *v,NSString *needle){
    if(!v||!needle.length)return NO;
    @try { for(UIView *n=v;n;n=n.superview){NSString *cn=NSStringFromClass(n.class)?:@"";if([cn rangeOfString:needle options:NSCaseInsensitiveSearch].location!=NSNotFound)return YES;} } @catch(...) {}
    return NO;
}
static BOOL ADUIViewsRelated7364(UIView *a,UIView *b){
    if(!a||!b)return NO;
    @try {for(UIView *n=a;n;n=n.superview)if(n==b)return YES;for(UIView *n=b;n;n=n.superview)if(n==a)return YES;} @catch(...) {}
    return NO;
}
static NSString *ADUINativeSubtreeSnapshot7364(UIView *root,NSString *phase,NSUInteger maxLogged){
    NSMutableString *m=[NSMutableString string]; if(!root)return m; CGRect screen=UIScreen.mainScreen.bounds; NSUInteger visited=0,logged=0,onscreen=0;
    @try {
        CGRect rr=[root convertRect:root.bounds toView:nil];
        [m appendFormat:@"\n===== NATIVE SWEEP SNAPSHOT phase=%@ root=%p cls=%@ aid=\"%@\" frame=%@ =====\n",phase?:@"?",root,NSStringFromClass(root.class)?:@"?",ADUISafe7362(root.accessibilityIdentifier),ADUIRect7362(rr)];
        NSMutableArray *q=[NSMutableArray arrayWithObject:@{ @"v":root,@"d":@0 }];
        while(q.count&&visited<maxLogged+1200&&logged<maxLogged){
            NSDictionary *it=q.firstObject;[q removeObjectAtIndex:0];UIView *v=it[@"v"];NSUInteger d=[it[@"d"] unsignedIntegerValue];if(!v)continue;visited++;
            CGRect wr=CGRectZero;@try{wr=[v convertRect:v.bounds toView:nil];}@catch(...){}
            BOOL on=!v.hidden&&v.alpha>=0.005&&wr.size.width>=0.1&&wr.size.height>=0.1&&CGRectIntersectsRect(wr,screen);if(on)onscreen++;
            CGAffineTransform t=v.transform;
            [m appendFormat:@"S d=%lu ptr=%p parent=%p cls=%@ aid=\"%@\" win=%@ onscreen=%d hidden=%d alpha=%.3f user=%d clips=%d transform=(%.3f,%.3f,%.3f,%.3f,%.1f,%.1f) bg=%@ tint=%@ layerBg=%@ layerBorder=%.2f/%@ radius=%.2f subviews=%lu traits=%llu chain=\"%@\" %@ %@ %@ %@\n",
             (unsigned long)d,v,v.superview,NSStringFromClass(v.class)?:@"?",ADUISafe7362(v.accessibilityIdentifier),ADUIRect7362(wr),on?1:0,v.hidden?1:0,v.alpha,v.userInteractionEnabled?1:0,v.clipsToBounds?1:0,t.a,t.b,t.c,t.d,t.tx,t.ty,ADUIColor7362(v.backgroundColor),ADUIColor7362(v.tintColor),ADUICG7362(v.layer.backgroundColor),v.layer.borderWidth,ADUICG7362(v.layer.borderColor),v.layer.cornerRadius,(unsigned long)v.subviews.count,(unsigned long long)v.accessibilityTraits,ADUIChain7362(v),ADUITextMeta7362(v),ADUIImageMeta7362(v),ADUIControlMeta7362(v),ADUIEdges7362(v)];
            [m appendFormat:@"SL ptr=%p %@\n",v,ADUILayerMeta7362(v)];logged++;
            if(q.count<maxLogged+1000)for(UIView *c in v.subviews)if(c)[q addObject:@{ @"v":c,@"d":@(d+1) }];
        }
    } @catch(NSException *e){[m appendFormat:@"NATIVE_SWEEP_EXCEPTION phase=%@ %@\n",phase?:@"?",ADUISafe7362(e.reason)];}
    [m appendFormat:@"NATIVE_SWEEP_COUNTS phase=%@ visited=%lu logged=%lu onscreen=%lu truncated=%d\n",phase?:@"?",(unsigned long)visited,(unsigned long)logged,(unsigned long)onscreen,(visited>=maxLogged+1200||logged>=maxLogged)?1:0];
    return m;
}

static NSArray *ADUINativeScrollCandidates7364(NSString *path,unsigned long long cap){
    NSMutableArray *all=[NSMutableArray array];CGRect screen=UIScreen.mainScreen.bounds;NSUInteger index=0;
    @try {
        for(UIWindow *w in UIApplication.sharedApplication.windows){
            if(!w||w.hidden||w.alpha<0.005)continue;NSMutableArray *q=[NSMutableArray arrayWithObject:w];NSUInteger seen=0;
            while(q.count&&seen++<18000){
                UIView *v=q.firstObject;[q removeObjectAtIndex:0];if(!v)continue;
                if([v isKindOfClass:[UIScrollView class]]){
                    UIScrollView *sv=(UIScrollView *)v;CGRect wr=CGRectZero;@try{wr=[sv convertRect:sv.bounds toView:nil];}@catch(...){}
                    BOOL web=ADUIAncestorClassContains7364(sv,@"WKWebView")||ADUIAncestorClassContains7364(sv,@"WKScroll")||[NSStringFromClass(sv.class) rangeOfString:@"WK" options:NSCaseInsensitiveSearch].location!=NSNotFound;
                    BOOL chrome=ADUIAncestorClassContains7364(sv,@"Keyboard")||ADUIAncestorClassContains7364(sv,@"ANXTabBar")||[NSStringFromClass(sv.class) rangeOfString:@"ScrollIndicator" options:NSCaseInsensitiveSearch].location!=NSNotFound;
                    UIEdgeInsets in=sv.adjustedContentInset;CGFloat spanY=sv.contentSize.height-sv.bounds.size.height+in.top+in.bottom,spanX=sv.contentSize.width-sv.bounds.size.width+in.left+in.right;
                    BOOL vy=spanY>8.0,hx=spanX>8.0,visible=ADUIViewActuallyVisible7362(sv)&&CGRectIntersectsRect(wr,screen);
                    if(!web&&!chrome&&visible&&(vy||hx)&&wr.size.width>=80.0&&wr.size.height>=70.0){
                        NSString *cn=NSStringFromClass(sv.class)?:@"?";CGFloat area=wr.size.width*wr.size.height;NSInteger score=(NSInteger)MIN(area,400000.0);
                        if(vy)score+=500000;if(hx)score+=180000;
                        if([cn rangeOfString:@"RCTScroll" options:NSCaseInsensitiveSearch].location!=NSNotFound)score+=450000;
                        if([cn rangeOfString:@"CollectionView" options:NSCaseInsensitiveSearch].location!=NSNotFound)score+=320000;
                        if([cn rangeOfString:@"TableView" options:NSCaseInsensitiveSearch].location!=NSNotFound)score+=320000;
                        if(wr.size.width>=screen.size.width*0.70)score+=220000;if(wr.size.height>=screen.size.height*0.35)score+=220000;
                        NSDictionary *d=@{ @"sv":sv,@"score":@(score),@"v":@(vy),@"h":@(hx),@"frame":[NSValue valueWithCGRect:wr],@"idx":@(index++) };
                        [all addObject:d];
                        ADUIAppend7362(path,[NSString stringWithFormat:@"NATIVE_SCROLL_CANDIDATE idx=%lu ptr=%p cls=%@ aid=\"%@\" score=%ld frame=%@ content=(%.1fx%.1f) bounds=(%.1fx%.1f) vertical=%d horizontal=%d offset=(%.1f,%.1f)\n",(unsigned long)[d[@"idx"] unsignedIntegerValue],sv,cn,ADUISafe7362(sv.accessibilityIdentifier),(long)score,ADUIRect7362(wr),sv.contentSize.width,sv.contentSize.height,sv.bounds.size.width,sv.bounds.size.height,vy?1:0,hx?1:0,sv.contentOffset.x,sv.contentOffset.y],cap);
                    }
                }
                if(q.count<17000)for(UIView *c in v.subviews)if(c)[q addObject:c];
            }
        }
    } @catch(NSException *e){ADUIAppend7362(path,[NSString stringWithFormat:@"NATIVE_SCROLL_DISCOVERY_EXCEPTION %@\n",ADUISafe7362(e.reason)],cap);}
    [all sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSInteger aa=[a[@"score"] integerValue],bb=[b[@"score"] integerValue];if(aa>bb)return NSOrderedAscending;if(aa<bb)return NSOrderedDescending;return NSOrderedSame;}];
    NSMutableArray *selected=[NSMutableArray array];
    for(NSDictionary *d in all){
        if(selected.count>=4)break;UIScrollView *sv=d[@"sv"];CGRect fr=[d[@"frame"] CGRectValue];BOOL dup=NO;
        for(NSDictionary *x in selected){UIScrollView *other=x[@"sv"];CGRect of=[x[@"frame"] CGRectValue];BOOL sameAxis=([d[@"v"] boolValue]&&[x[@"v"] boolValue])||([d[@"h"] boolValue]&&[x[@"h"] boolValue]);CGRect inter=CGRectIntersection(fr,of);CGFloat ia=CGRectIsNull(inter)?0:(inter.size.width*inter.size.height);CGFloat ma=MIN(fr.size.width*fr.size.height,of.size.width*of.size.height);if(sameAxis&&ADUIViewsRelated7364(sv,other)&&ma>0&&ia/ma>0.82){dup=YES;break;}}
        if(!dup)[selected addObject:d];
    }
    ADUIAppend7362(path,[NSString stringWithFormat:@"NATIVE_SCROLL_SELECTION total=%lu selected=%lu cap=4\n",(unsigned long)all.count,(unsigned long)selected.count],cap);
    return selected;
}

static void ADUIEvalAppend7364(WKWebView *wv,NSString *path,NSString *js,NSString *label,unsigned long long cap,void (^done)(void)){
    if(!wv||[gADUIFailedWebs7446 containsObject:wv]||ADUIExpired7446()){gADUIProbePartial7446=YES;if(done)done();return;}
    __block BOOL settled=NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(4.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if(settled)return;settled=YES;gADUIProbePartial7446=YES;[gADUIFailedWebs7446 addObject:wv];
        ADUIAppend7362(path,[NSString stringWithFormat:@"WEB_TIMEOUT label=%@ after=4.0s\n",label?:@"JS"],cap);
        if(done)done();
    });
    [wv evaluateJavaScript:js completionHandler:^(id result,NSError *error){
        dispatch_async(dispatch_get_main_queue(),^{
            if(settled)return;settled=YES;
            if(error){gADUIProbePartial7446=YES;[gADUIFailedWebs7446 addObject:wv];ADUIAppend7362(path,[NSString stringWithFormat:@"WEB_ERROR label=%@ %@\n",label?:@"JS",ADUISafe7362(error.localizedDescription)],cap);}
            else if([result isKindOfClass:[NSString class]]){
                ADUIAppend7362(path,[NSString stringWithFormat:@"\n--- %@ ---\n",label?:@"WEB"],cap);ADUIAppend7362(path,(NSString *)result,cap);ADUIAppend7362(path,@"\n",cap);
                id obj=[NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                if([obj isKindOfClass:NSDictionary.class]){
                    if([obj[@"counts"][@"frames"] unsignedIntegerValue]>0)gADUIExpectedFrames7446=YES;
                    if(obj[@"error"]||[obj[@"counts"][@"truncated"] boolValue]||[obj[@"counts"][@"scrollOwnerLimit"] boolValue])gADUIProbePartial7446=YES;
                    if([obj[@"more"] boolValue]){
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.012*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                            ADUIEvalAppend7364(wv,path,@"window.__adUIProbeContinue7446 ? window.__adUIProbeContinue7446() : JSON.stringify({error:'continuation-lost'})",label,cap,done);
                        });return;
                    }
                }else gADUIProbePartial7446=YES;
            }
            else ADUIAppend7362(path,[NSString stringWithFormat:@"WEB_RESULT label=%@ non-string class=%@\n",label?:@"JS",NSStringFromClass([result class])],cap);
            if(done)done();
        });
    }];
}

// Diagnostic-only document and overflow-owner navigation. No runtime observer or scroll lock.
static void ADUIScrollCommand7446(WKWebView *wv,NSString *command,void (^done)(NSDictionary *)){
    NSString *payload=@
#include "ADUIProbeScroll7446.js.inc"
    ;
    NSString *js=[NSString stringWithFormat:@"window.__adUIWalkCommand7446=%@;\n%@",command,payload];
    __block BOOL settled=NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(4.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if(settled)return;settled=YES;gADUIProbePartial7446=YES;[gADUIFailedWebs7446 addObject:wv];if(done)done(@{@"error":@"scroll-command-timeout"});
    });
    [wv evaluateJavaScript:js completionHandler:^(id result,NSError *error){
        if(settled)return;settled=YES;
        if(error||![result isKindOfClass:NSDictionary.class]){gADUIProbePartial7446=YES;if(done)done(@{@"error":@"scroll-command-failed"});return;}
        if(done)done(result);
    }];
}
static void ADUIScanWebViewFull7364(WKWebView *wv,NSUInteger index,NSString *path,unsigned long long cap,void (^done)(void)){
    if(!wv){if(done)done();return;}
    CGPoint original=wv.scrollView.contentOffset;
    __block NSUInteger step=0,bottomStable=0,stalled=0;
    __block CGFloat lastMax=-1,targetY=0;
    __block BOOL finishing=NO;
    __block void (^next)(NSDictionary *)=nil;
    __block void (^finish)(NSString *)=nil;
    ADUIAppend7362(path,@"WEB_DOCUMENT_SWEEP maxSteps=120 bottomStable=3 owners=document+large-overflow-containers scrollLock=none\n",cap);
    finish=^(NSString *reason){
        if(finishing)return;finishing=YES;
        if(![reason isEqualToString:@"all-owners-bottom-stable"])gADUIProbePartial7446=YES;
        ADUIScrollCommand7446(wv,@"'restore'",^(NSDictionary *restored){
            if(restored[@"error"])gADUIProbePartial7446=YES;
            [wv.scrollView setContentOffset:original animated:NO];
            ADUIAppend7362(path,[NSString stringWithFormat:@"WEB_SWEEP_END index=%lu reason=%@ steps=%lu restore=%@\n",(unsigned long)index,reason,(unsigned long)step,restored],cap);
            next=nil;finish=nil;if(done)done();
        });
    };
    next=^(NSDictionary *m){
        if(finishing)return;
        if(m[@"error"]||ADUIExpired7446()||[gADUIFailedWebs7446 containsObject:wv]||!wv.window||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive){finish(@"cancelled-or-web-error");return;}
        if([m[@"done"] boolValue]){finish(@"all-owners-bottom-stable");return;}
        if(step>=120){finish(@"step-cap");return;}
        CGFloat y=[m[@"y"] doubleValue],max=[m[@"max"] doubleValue];
        if(lastMax>=0&&fabs(lastMax-max)>1){bottomStable=0;ADUIAppend7362(path,@"WEB_CONTENT_GROWTH or resize\n",cap);}lastMax=max;
        ADUIAppend7362(path,[NSString stringWithFormat:@"WEB_OWNER_STEP index=%@ total=%@ y=%.1f max=%.1f target=%.1f step=%lu\n",m[@"index"],m[@"total"],y,max,targetY,(unsigned long)step],cap);
        if(fabs(y-targetY)>3&&y<max-2){stalled++;if(stalled>=3){finish(@"scroll-owner-stalled");return;}}else stalled=0;
        NSUInteger current=step++;
        ADUIEvalAppend7364(wv,path,ADUIWebJS7364(@"viewport",@"sweep-step",current),[NSString stringWithFormat:@"SWEEP_STEP_%lu",(unsigned long)current],cap,^{
            if(finishing)return;
            ADUIScrollCommand7446(wv,@"'read'",^(NSDictionary *after){
                if(after[@"error"]){finish(@"scroll-read-failed");return;}
                CGFloat actual=[after[@"y"] doubleValue],limit=[after[@"max"] doubleValue];
                if(actual>=limit-2&&fabs(limit-lastMax)<1)bottomStable++;else bottomStable=0;
                NSString *command;
                if(bottomStable>=3){command=@"'next'";targetY=0;lastMax=-1;bottomStable=0;stalled=0;}
                else{targetY=MIN(limit,actual+MAX(160.0,[after[@"height"] doubleValue]*0.75));command=[NSString stringWithFormat:@"%.3f",targetY];}
                ADUIAppend7362(path,[NSString stringWithFormat:@"WEB_BOTTOM_HOLD stable=%lu actual=%.1f max=%.1f\n",(unsigned long)bottomStable,actual,limit],cap);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.6*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                    if(finishing)return;ADUIScrollCommand7446(wv,command,^(NSDictionary *moved){
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.20*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                            if(finishing)return;if(moved[@"error"]){finish(@"scroll-move-failed");return;}ADUIScrollCommand7446(wv,@"'read'",next);
                        });
                    });
                });
            });
        });
    };
    ADUIEvalAppend7364(wv,path,ADUIWebJS7364(@"full",@"initial-full",0),@"INITIAL_FULL_DOM",cap,^{
        if([gADUIFailedWebs7446 containsObject:wv]||ADUIExpired7446()){finish(@"initial-inventory-incomplete");return;}
        ADUIScrollCommand7446(wv,@"'init'",next);
    });
}

static void ADUIProcessWebViews7364(NSArray *webs,NSUInteger index,BOOL viewportOnly,NSString *path,unsigned long long cap,void (^done)(void)){
    if(index>=webs.count){if(done)done();return;}WKWebView *wv=webs[index];CGRect wr=CGRectZero;@try{wr=[wv convertRect:wv.bounds toView:nil];}@catch(...){}UIScrollView *sv=wv.scrollView;CGPoint off=sv.contentOffset;CGSize content=sv.contentSize;
    ADUIAppend7362(path,[NSString stringWithFormat:@"\n===== WEBVIEW index=%lu ptr=%p frame=%@ offset=(%.1f,%.1f) content=(%.1fx%.1f) =====\n",(unsigned long)index,wv,ADUIRect7362(wr),off.x,off.y,content.width,content.height],cap);
    void (^nextWeb)(void)=^{ADUIProcessWebViews7364(webs,index+1,viewportOnly,path,cap,done);};
    if(viewportOnly)ADUIEvalAppend7364(wv,path,ADUIWebJS7364(@"viewport",@"viewport-trigger",0),@"VIEWPORT_DOM",cap,nextWeb);
    else ADUIScanWebViewFull7364(wv,index,path,cap,nextWeb);
}

static void ADUIScanNativeAxis7364(UIScrollView *sv,NSUInteger selectedIndex,BOOL horizontal,NSString *path,unsigned long long cap,CGPoint original,void (^done)(void)){
    if(!sv){if(done)done();return;}UIEdgeInsets in=sv.adjustedContentInset;CGFloat min=horizontal?-in.left:-in.top;CGFloat viewport=MAX(1.0,horizontal?sv.bounds.size.width:sv.bounds.size.height);CGFloat stride=MAX(180.0,MIN(620.0,viewport*0.62));NSUInteger maxSteps=horizontal?16:32;
    __block NSUInteger step=0;__block CGFloat target=min,last=-999999;__block BOOL finishing=NO;__block void (^next)(void)=nil;__block void (^finish)(NSString *)=nil;
    finish=^(NSString *reason){if(finishing)return;finishing=YES;@try{CGPoint p=sv.contentOffset;if(horizontal)p.x=original.x;else p.y=original.y;[sv setContentOffset:p animated:NO];[sv layoutIfNeeded];}@catch(...){}ADUIAppend7362(path,[NSString stringWithFormat:@"NATIVE_AXIS_END selected=%lu ptr=%p axis=%@ reason=%@ steps=%lu offset=(%.1f,%.1f)\n",(unsigned long)selectedIndex,sv,horizontal?@"x":@"y",reason?:@"done",(unsigned long)step,sv.contentOffset.x,sv.contentOffset.y],cap);if(done)done();next=nil;finish=nil;};
    next=^{
        if(finishing)return;if(ADUIExpired7446()){gADUIProbePartial7446=YES;finish(@"cancelled-or-deadline");return;}if(!sv.window||!sv.superview){finish(@"native-left-window");return;}if(step>=maxSteps){gADUIProbePartial7446=YES;finish(@"step-cap");return;}UIEdgeInsets ci=sv.adjustedContentInset;CGFloat cmin=horizontal?-ci.left:-ci.top;CGFloat max=horizontal?MAX(cmin,sv.contentSize.width-sv.bounds.size.width+ci.right):MAX(cmin,sv.contentSize.height-sv.bounds.size.height+ci.bottom);target=MIN(MAX(cmin,target),max);
        if(step>0&&fabs(target-last)<0.5&&fabs(target-max)<0.5){finish(@"edge");return;}CGPoint p=original;if(horizontal){p.x=target;p.y=sv.contentOffset.y;}else{p.y=target;p.x=sv.contentOffset.x;}@try{[sv setContentOffset:p animated:NO];[sv layoutIfNeeded];}@catch(...){}NSUInteger thisStep=step++;CGFloat thisTarget=target;last=target;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.08*NSEC_PER_SEC)),dispatch_get_main_queue(),^{NSString *phase=[NSString stringWithFormat:@"candidate-%lu-%@-step-%lu",(unsigned long)selectedIndex,horizontal?@"x":@"y",(unsigned long)thisStep];ADUIAppend7362(path,ADUINativeSubtreeSnapshot7364(sv,phase,2500),cap);UIEdgeInsets ni=sv.adjustedContentInset;CGFloat nmin=horizontal?-ni.left:-ni.top;CGFloat nmax=horizontal?MAX(nmin,sv.contentSize.width-sv.bounds.size.width+ni.right):MAX(nmin,sv.contentSize.height-sv.bounds.size.height+ni.bottom);if(fabs(thisTarget-nmax)<0.5){finish(@"edge");return;}target=MIN(nmax,thisTarget+stride);dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.03*NSEC_PER_SEC)),dispatch_get_main_queue(),next);});
    };dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.04*NSEC_PER_SEC)),dispatch_get_main_queue(),next);
}

static void ADUIScanNativeCandidate7364(NSDictionary *meta,NSUInteger selectedIndex,NSString *path,unsigned long long cap,void (^done)(void)){
    UIScrollView *sv=meta[@"sv"];if(!sv){if(done)done();return;}CGPoint original=sv.contentOffset;BOOL vertical=[meta[@"v"] boolValue],horizontal=[meta[@"h"] boolValue];CGRect wr=CGRectZero;@try{wr=[sv convertRect:sv.bounds toView:nil];}@catch(...){}
    ADUIAppend7362(path,[NSString stringWithFormat:@"\n===== NATIVE FULL SWEEP selected=%lu ptr=%p cls=%@ aid=\"%@\" frame=%@ originalOffset=(%.1f,%.1f) content=(%.1fx%.1f) vertical=%d horizontal=%d =====\n",(unsigned long)selectedIndex,sv,NSStringFromClass(sv.class)?:@"?",ADUISafe7362(sv.accessibilityIdentifier),ADUIRect7362(wr),original.x,original.y,sv.contentSize.width,sv.contentSize.height,vertical?1:0,horizontal?1:0],cap);ADUIAppend7362(path,ADUINativeSubtreeSnapshot7364(sv,[NSString stringWithFormat:@"candidate-%lu-initial",(unsigned long)selectedIndex],2500),cap);
    void (^finish)(void)=^{@try{[sv setContentOffset:original animated:NO];[sv layoutIfNeeded];}@catch(...){}ADUIAppend7362(path,[NSString stringWithFormat:@"NATIVE_SWEEP_END selected=%lu ptr=%p restoredOffset=(%.1f,%.1f) finalContent=(%.1fx%.1f)\n",(unsigned long)selectedIndex,sv,sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height],cap);if(done)done();};
    void (^runX)(void)=^{if(horizontal)ADUIScanNativeAxis7364(sv,selectedIndex,YES,path,cap,original,finish);else finish();};
    if(vertical)ADUIScanNativeAxis7364(sv,selectedIndex,NO,path,cap,original,runX);else runX();
}
static void ADUIProcessNativeCandidates7364(NSArray *candidates,NSUInteger index,NSString *path,unsigned long long cap,void (^done)(void)){
    if(index>=candidates.count){if(done)done();return;}ADUIScanNativeCandidate7364(candidates[index],index,path,cap,^{ADUIProcessNativeCandidates7364(candidates,index+1,path,cap,done);});
}

static void ADUIFinishCapture7364(BOOL viewportOnly,NSArray *webs,NSString *path,unsigned long long cap){
    if(!viewportOnly){ADUIAppend7362(path,@"\n===== NATIVE FINAL FULL SNAPSHOT =====\n",cap);ADUIAppend7362(path,ADUINativeSnapshot7362(NO),cap);}
    ADUIAppend7362(path,@"\nCROSS_FRAME_FLUSH_WAIT ms=900 reason=allow final child/SafeFrame message chunks to complete\n",cap);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.90*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if((gADUIExpectedFrames7446&&gADUIFramePayloads7446==0)||gADUIFrameBatches7446.count>0||gADUniversalUIBridge7433.pending.count>0)gADUIProbePartial7446=YES;
        ADUIAppendTerminal7364(path,[NSString stringWithFormat:@"\nUI_PROBE_END category=%@ webviews=%lu crossframe=best-effort-check-CROSS_FRAME_DOM\n================ END RUN ================\n",viewportOnly?@"viewport":@"full-sweep",(unsigned long)webs.count],cap);
        ADUIAppendTerminal7364(path,[NSString stringWithFormat:@"COVERAGE state=%@ framePayloads=%lu frameCompleteness=unverified\n",gADUIProbePartial7446?@"partial":@"completed",(unsigned long)gADUIFramePayloads7446],cap);
        ADUIWriteState7445(viewportOnly,gADUIProbePartial7446?@"partial":@"completed",path);
        gADUIProbeActivePath7433=nil;gADUIProbeActiveNonce7433=nil;gADUIProbeActiveCap7433=0;if(gADUniversalUIBridge7433)[gADUniversalUIBridge7433.pending removeAllObjects];gADUIProbeBusy7362=NO;
    });
}

static void ADCaptureUniversalUIProbe7362(BOOL viewportOnly,NSString *trigger);
static BOOL gADUIWaitingForeground7446=NO;
static void ADUIWaitForeground7446(BOOL viewportOnly,NSString *trigger,NSUInteger attempts){
    if(UIApplication.sharedApplication.applicationState==UIApplicationStateActive){gADUIWaitingForeground7446=NO;ADCaptureUniversalUIProbe7362(viewportOnly,trigger);return;}
    if(attempts==0){gADUIWaitingForeground7446=NO;ADUIWriteState7445(viewportOnly,@"foreground-timeout",@"no-capture");return;}
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ADUIWaitForeground7446(viewportOnly,trigger,attempts-1);});
}

static void ADCaptureUniversalUIProbe7362(BOOL viewportOnly,NSString *trigger){
    if(!gP.enabled)return;
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive){
        if(!gADUIWaitingForeground7446){gADUIWaitingForeground7446=YES;ADUIWriteState7445(viewportOnly,@"waiting-foreground",@"no-capture");ADUIWaitForeground7446(viewportOnly,trigger,60);}return;
    }
    if(gADUIProbeBusy7362){ADUIAppend7362(gADUIProbeActivePath7433,@"TRIGGER_REJECTED reason=capture-already-running\n",gADUIProbeActiveCap7433);return;}
    if(ADSkelProbe7339&&!ADSkelProbe7339.finished)[ADSkelProbe7339 finish];
    gADUIProbeBusy7362=YES;gADUIProbePartial7446=NO;gADUIFramePayloads7446=0;gADUIExpectedFrames7446=NO;gADUIFrameBatches7446=[NSMutableSet set];
    gADUIProbeDeadline7446=NSDate.date.timeIntervalSince1970+(viewportOnly?45.0:240.0);
    gADUIFailedWebs7446=[NSHashTable weakObjectsHashTable];
    NSUInteger run=viewportOnly?++gADUIViewportRun7362:++gADUIFullRun7362;unsigned long long cap=viewportOnly?kADUIViewportCap7362:kADUIFullCap7362;NSString *path=ADUIProbePath7362(viewportOnly,run);NSArray *webs=ADUIWebViews7362();
    ADUIWriteState7445(viewportOnly,@"started",path);
    gADUIProbeActivePath7433=path;gADUIProbeActiveCap7433=cap;gADUIProbeActiveNonce7433=[NSString stringWithFormat:@"%lld-%d-%lu",(long long)(NSDate.date.timeIntervalSince1970*1000.0),getpid(),(unsigned long)run];if(gADUniversalUIBridge7433)[gADUniversalUIBridge7433.pending removeAllObjects];
    NSString *header=[NSString stringWithFormat:@"AMAZONDARK v7.446 UNIVERSAL %@ UI FORENSICS PROBE\nversion=%s\ncategory=%@\ntrigger=%@\ndate=%@\nfile=%@\ncap_bytes=%llu\ncontract=screenshot always captures FULL SWEEP; scripts/ui-probe.sh arm captures VIEWPORT via one-shot SIGUSR2\nroute_policy=universal: no tab/menu/product/cart/person/alexa dispatcher; every current on-screen WKWebView, every injected child/SafeFrame document, plus every eligible current native scroll renderer is discovered dynamically\nprivacy=no visible text strings, accessibilityLabel/value strings, URL/src/href values, network payloads or clipboard data; text is length+hash only; frame origin/path/referrer are hash-only; technical class/id/testid/component paint metadata retained\ncrossframe=all-frame documentStart bridge; child frames self-inspect their own DOM and computed paint, then send chunked sanitized results to native; main frame never attempts cross-origin contentDocument access\nweb=%@\nnative=%@\nnormal_runtime=single screenshot notification + single SIGUSR2 dispatch source + one inert message listener per web document frame; all scanning/traversal is finite and exists only after an explicit trigger; no MutationObserver/timer/RAF/web-scroll listener/polling/recurring hierarchy scan\nwebviews=%lu\n\n===== NATIVE INITIAL %@ SNAPSHOT =====\n",
        viewportOnly?@"VIEWPORT":@"FULL-SWEEP",AD_VERSION,viewportOnly?@"viewport":@"full-web-native-sweep",trigger?:@"unknown",[NSDate date],path.lastPathComponent,cap,
        viewportOnly?@"current visual viewport of every on-screen WKWebView plus every visible child/SafeFrame document; no offset mutation":@"batched mounted DOM + finite document/large-overflow-owner sweep with lazy-growth viewport snapshots; original offsets restored; scrolling is never disabled",
        viewportOnly?@"current screen-intersecting UIKit/React hierarchy only":@"initial/final full visible-window hierarchy + dynamically discovered non-WebKit scroll candidates swept across every scrollable axis with per-step subtree snapshots; original offsets restored; scrolling is never disabled",
        (unsigned long)webs.count,viewportOnly?@"VIEWPORT":@"FULL"];
    ADUIAppend7362(path,header,cap);ADUIAppend7362(path,ADUINativeSnapshot7362(viewportOnly),cap);
    ADUIProcessWebViews7364(webs,0,viewportOnly,path,cap,^{
        if(viewportOnly){ADUIFinishCapture7364(YES,webs,path,cap);return;}
        ADUIAppend7362(path,@"\n===== NATIVE SCROLL DISCOVERY / SWEEP =====\n",cap);NSArray *native=ADUINativeScrollCandidates7364(path,cap);ADUIProcessNativeCandidates7364(native,0,path,cap,^{ADUIFinishCapture7364(NO,webs,path,cap);});
    });
}

static NSString *ADUIViewportArmPath7362(void){ return [ADUIDocuments7362() stringByAppendingPathComponent:@"AmazonDark-v7.446-ui-viewport.arm"]; }
static BOOL ADUIConsumeViewportArm7362(void){
    NSString *p=ADUIViewportArmPath7362(); NSFileManager *fm=NSFileManager.defaultManager; if(![fm fileExistsAtPath:p])return NO;
    BOOL ok=NO; @try {
        NSString *s=[NSString stringWithContentsOfFile:p encoding:NSUTF8StringEncoding error:nil]?:@""; NSDictionary *attrs=[fm attributesOfItemAtPath:p error:nil]; NSDate *d=attrs[NSFileModificationDate]; NSTimeInterval age=d?-[d timeIntervalSinceNow]:9999;
        ok=[s hasPrefix:@"viewport"]&&age>=-5&&age<=300;
    } @catch(...) {} [fm removeItemAtPath:p error:nil]; return ok;
}

static void ADCaptureThreeTabProbe7254(NSString *trigger){
    // Function name retained only so ctor/prefs wiring stays byte-small. The old route-specific
    // dispatcher is gone: screenshot means full; an armed SIGUSR2 means viewport.
    if(!gP.enabled)return;
    if([trigger isEqualToString:@"screenshot"]){ ADSkelTrigger7339(trigger); ADCaptureUniversalUIProbe7362(NO,trigger); return; }
    if([trigger isEqualToString:@"SIGUSR2"]){ ADSkelTrigger7339(trigger); if(ADUIConsumeViewportArm7362())ADCaptureUniversalUIProbe7362(YES,@"armed-SIGUSR2"); return; }
}

static void ADInstallThreeTabProbes7254(void){
    static dispatch_once_t once; dispatch_once(&once,^{
        ADSkelInstall7339();
        signal(SIGUSR2,SIG_IGN);
        gADThreeTabProbeSignal7254=dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,SIGUSR2,0,dispatch_get_main_queue());
        if(gADThreeTabProbeSignal7254){ dispatch_source_set_event_handler(gADThreeTabProbeSignal7254,^{ ADCaptureThreeTabProbe7254(@"SIGUSR2"); }); dispatch_resume(gADThreeTabProbeSignal7254); }
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationUserDidTakeScreenshotNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *n){ ADCaptureThreeTabProbe7254(@"screenshot"); }];
    });
}
