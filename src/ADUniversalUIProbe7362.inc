// v7.362 universal dual UI probe architecture.
// Exactly two UI forensics categories remain:
//   1) screenshot -> FULL mounted DOM + full mounted native hierarchy
//   2) scripts/ui-probe.sh arm -> current VIEWPORT only, then one SIGUSR2
// Both categories are route/tab agnostic. They inspect every on-screen WKWebView and
// the current UIKit/React hierarchy instead of dispatching to menu-specific scanners.
// No probe observer/timer/RAF/scroll listener or recurring hierarchy walk runs during
// normal use. The screenshot notification and SIGUSR2 source are the only triggers.

static dispatch_source_t gADThreeTabProbeSignal7254=nil; // retained symbol name; now universal
static BOOL gADUIProbeBusy7362=NO;
static NSUInteger gADUIFullRun7362=0;
static NSUInteger gADUIViewportRun7362=0;
static const unsigned long long kADUIFullCap7362=96ULL*1024ULL*1024ULL;
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
            while(q.count&&visited<(viewportOnly?7000:16000)&&logged<(viewportOnly?5000:14000)){
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
    [m appendFormat:@"NATIVE_END mode=%@ windows=%lu visited=%lu logged=%lu truncated=%d\n",viewportOnly?@"viewport":@"full",(unsigned long)windows,(unsigned long)visited,(unsigned long)logged,(visited>=(viewportOnly?7000:16000)||logged>=(viewportOnly?5000:14000))?1:0];
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
        NSString *name=[NSString stringWithFormat:@"AmazonDark-v7.362-%@-%@-r%lu.txt",stem,stamp?:@"unknown",(unsigned long)run];
        return [ADUIDocuments7362() stringByAppendingPathComponent:name];
    } @catch(...) { return [NSTemporaryDirectory() stringByAppendingPathComponent:@"AmazonDark-v7.362-ui-probe.txt"]; }
}

static void ADUIAppend7362(NSString *path,NSString *text,unsigned long long cap){
    if(!path.length||!text.length)return;
    @try {
        NSFileManager *fm=NSFileManager.defaultManager; [fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        unsigned long long cur=[[[fm attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] unsignedLongLongValue]; if(cur>=cap)return;
        NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding]; unsigned long long rem=cap-cur; if((unsigned long long)d.length>rem)d=[d subdataWithRange:NSMakeRange(0,(NSUInteger)rem)];
        if(![fm fileExistsAtPath:path]){[d writeToFile:path atomically:YES];return;} NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:path];if(h){[h seekToEndOfFile];[h writeData:d];[h closeFile];}
    } @catch(...) {}
}

static NSString *ADUIWebJS7362(BOOL viewportOnly){
    static NSString *base=nil;static dispatch_once_t once;dispatch_once(&once,^{
        static const char script[]=
#include "ADUniversalUIProbe7362.js.inc"
        ;
        base=[[NSString alloc] initWithBytes:script length:sizeof(script)-1 encoding:NSUTF8StringEncoding];
    });
    return [NSString stringWithFormat:@"window.__adUIProbeMode7362='%@';%@",viewportOnly?@"viewport":@"full",base?:@""];
}

static void ADUIFinishWebViews7362(NSArray *webs,NSUInteger index,BOOL viewportOnly,NSString *path,unsigned long long cap){
    if(index>=webs.count){
        ADUIAppend7362(path,[NSString stringWithFormat:@"\nUI_PROBE_END category=%@ webviews=%lu\n================ END RUN ================\n",viewportOnly?@"viewport":@"full",(unsigned long)webs.count],cap);
        gADUIProbeBusy7362=NO; return;
    }
    WKWebView *wv=webs[index]; CGRect wr=CGRectZero; @try{wr=[wv convertRect:wv.bounds toView:nil];}@catch(...){}
    UIScrollView *sv=wv.scrollView; CGPoint off=sv.contentOffset; CGSize content=sv.contentSize;
    ADUIAppend7362(path,[NSString stringWithFormat:@"\n===== WEBVIEW index=%lu ptr=%p frame=%@ offset=(%.1f,%.1f) content=(%.1fx%.1f) =====\n",(unsigned long)index,wv,ADUIRect7362(wr),off.x,off.y,content.width,content.height],cap);
    [wv evaluateJavaScript:ADUIWebJS7362(viewportOnly) completionHandler:^(id result,NSError *error){
        if(error)ADUIAppend7362(path,[NSString stringWithFormat:@"WEB_ERROR index=%lu %@\n",(unsigned long)index,ADUISafe7362(error.localizedDescription)],cap);
        else if([result isKindOfClass:[NSString class]]){ADUIAppend7362(path,(NSString *)result,cap);ADUIAppend7362(path,@"\n",cap);}
        else ADUIAppend7362(path,[NSString stringWithFormat:@"WEB_RESULT index=%lu non-string class=%@\n",(unsigned long)index,NSStringFromClass([result class])],cap);
        ADUIFinishWebViews7362(webs,index+1,viewportOnly,path,cap);
    }];
}

static void ADCaptureUniversalUIProbe7362(BOOL viewportOnly,NSString *trigger){
    if(!gP.enabled||gADUIProbeBusy7362)return; gADUIProbeBusy7362=YES;
    NSUInteger run=viewportOnly?++gADUIViewportRun7362:++gADUIFullRun7362; unsigned long long cap=viewportOnly?kADUIViewportCap7362:kADUIFullCap7362; NSString *path=ADUIProbePath7362(viewportOnly,run);
    NSArray *webs=ADUIWebViews7362();
    NSString *header=[NSString stringWithFormat:@"AMAZONDARK v7.362 UNIVERSAL %@ UI FORENSICS PROBE\nversion=%s\ncategory=%@\ntrigger=%@\ndate=%@\nfile=%@\ncap_bytes=%llu\ncontract=screenshot always captures FULL; scripts/ui-probe.sh arm captures VIEWPORT via one-shot SIGUSR2\nroute_policy=universal: no tab/menu/product/cart/person/alexa dispatcher; every current on-screen WKWebView is inspected\nprivacy=no visible text strings, accessibilityLabel/value strings, URL/src/href values, network payloads or clipboard data; text is length+hash only; technical class/id/testid/component paint metadata retained\nweb=%@\nnative=%@\nnormal_runtime=single screenshot notification + single SIGUSR2 dispatch source only; no MutationObserver/timer/RAF/web-scroll listener/recurring DOM or native hierarchy scan\nwebviews=%lu\n\n===== NATIVE %@ SNAPSHOT =====\n",
        viewportOnly?@"VIEWPORT":@"FULL",AD_VERSION,viewportOnly?@"viewport":@"full-dom-native",trigger?:@"unknown",[NSDate date],path.lastPathComponent,cap,
        viewportOnly?@"current visual viewport only: intersecting DOM nodes, pseudo paint, media, hit-test stacks, open shadow roots and same-origin frames; no scrolling or offset mutation":@"entire mounted DOM of each on-screen WKWebView, including offscreen/hidden DOM nodes, pseudo paint, media, open shadow roots and same-origin frames; no route-specific selector assumptions",
        viewportOnly?@"current screen-intersecting UIKit/React views and their direct layer paint only":@"entire mounted hierarchy of every visible UIWindow, including offscreen/hidden descendants and direct sublayer paint; current screen intersection is flagged per node",
        (unsigned long)webs.count,viewportOnly?@"VIEWPORT":@"FULL"];
    ADUIAppend7362(path,header,cap); ADUIAppend7362(path,ADUINativeSnapshot7362(viewportOnly),cap);
    ADUIFinishWebViews7362(webs,0,viewportOnly,path,cap);
}

static NSString *ADUIViewportArmPath7362(void){ return [ADUIDocuments7362() stringByAppendingPathComponent:@"AmazonDark-v7.362-ui-viewport.arm"]; }
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
    if([trigger isEqualToString:@"screenshot"]){ if(ADSkelTrigger7339(trigger))return; ADCaptureUniversalUIProbe7362(NO,trigger); return; }
    if([trigger isEqualToString:@"SIGUSR2"]){ if(ADSkelTrigger7339(trigger))return; if(ADUIConsumeViewportArm7362())ADCaptureUniversalUIProbe7362(YES,@"armed-SIGUSR2"); return; }
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
