// v7.373 universal dual UI probe architecture: screenshot FULL now performs finite renderer sweeps.
// Exactly two UI forensics categories remain:
//   1) screenshot -> FULL finite Web/native renderer sweep + final full inventories
//   2) scripts/ui-probe.sh arm -> current VIEWPORT only, then one SIGUSR2
// Both categories are route/tab agnostic. They inspect every on-screen WKWebView and
// the current UIKit/React hierarchy instead of dispatching to menu-specific scanners.
// No probe observer/timer/RAF/scroll listener or recurring hierarchy walk runs during
// normal use. The screenshot notification and SIGUSR2 source are the only triggers.

static dispatch_source_t gADThreeTabProbeSignal7254=nil; // retained symbol name; now universal
static BOOL gADUIProbeBusy7362=NO;
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
        NSString *name=[NSString stringWithFormat:@"AmazonDark-v7.380-%@-%@-r%lu.txt",stem,stamp?:@"unknown",(unsigned long)run];
        return [ADUIDocuments7362() stringByAppendingPathComponent:name];
    } @catch(...) { return [NSTemporaryDirectory() stringByAppendingPathComponent:@"AmazonDark-v7.380-ui-probe.txt"]; }
}

static void ADUIAppend7362(NSString *path,NSString *text,unsigned long long cap){
    if(!path.length||!text.length)return;
    @try {
        NSFileManager *fm=NSFileManager.defaultManager; [fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        unsigned long long cur=[[[fm attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] unsignedLongLongValue]; unsigned long long bodyCap=cap>8192ULL?cap-8192ULL:cap; if(cur>=bodyCap)return;
        NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding]; unsigned long long rem=bodyCap-cur; if((unsigned long long)d.length>rem)d=[d subdataWithRange:NSMakeRange(0,(NSUInteger)rem)];
        if(![fm fileExistsAtPath:path]){[d writeToFile:path atomically:YES];return;} NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:path];if(h){[h seekToEndOfFile];[h writeData:d];[h closeFile];}
    } @catch(...) {}
}

static void ADUIAppendTerminal7364(NSString *path,NSString *text,unsigned long long cap){
    if(!path.length||!text.length)return;
    @try {
        NSFileManager *fm=NSFileManager.defaultManager;unsigned long long cur=[[[fm attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] unsignedLongLongValue];if(cur>=cap)return;NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding];unsigned long long rem=cap-cur;if((unsigned long long)d.length>rem)d=[d subdataWithRange:NSMakeRange(0,(NSUInteger)rem)];
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
    return [NSString stringWithFormat:@"window.__adUIProbeMode7362='%@';window.__adUIProbePhase7364='%@';window.__adUIProbeStep7364=%lu;%@",m,p,(unsigned long)step,base?:@""];
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
        if(selected.count>=24)break;UIScrollView *sv=d[@"sv"];CGRect fr=[d[@"frame"] CGRectValue];BOOL dup=NO;
        for(NSDictionary *x in selected){UIScrollView *other=x[@"sv"];CGRect of=[x[@"frame"] CGRectValue];BOOL sameAxis=([d[@"v"] boolValue]&&[x[@"v"] boolValue])||([d[@"h"] boolValue]&&[x[@"h"] boolValue]);CGRect inter=CGRectIntersection(fr,of);CGFloat ia=CGRectIsNull(inter)?0:(inter.size.width*inter.size.height);CGFloat ma=MIN(fr.size.width*fr.size.height,of.size.width*of.size.height);if(sameAxis&&ADUIViewsRelated7364(sv,other)&&ma>0&&ia/ma>0.82){dup=YES;break;}}
        if(!dup)[selected addObject:d];
    }
    ADUIAppend7362(path,[NSString stringWithFormat:@"NATIVE_SCROLL_SELECTION total=%lu selected=%lu cap=24\n",(unsigned long)all.count,(unsigned long)selected.count],cap);
    return selected;
}

static void ADUIEvalAppend7364(WKWebView *wv,NSString *path,NSString *js,NSString *label,unsigned long long cap,void (^done)(void)){
    [wv evaluateJavaScript:js completionHandler:^(id result,NSError *error){
        if(error)ADUIAppend7362(path,[NSString stringWithFormat:@"WEB_ERROR label=%@ %@\n",label?:@"JS",ADUISafe7362(error.localizedDescription)],cap);
        else if([result isKindOfClass:[NSString class]]){ADUIAppend7362(path,[NSString stringWithFormat:@"\n--- %@ ---\n",label?:@"WEB"],cap);ADUIAppend7362(path,(NSString *)result,cap);ADUIAppend7362(path,@"\n",cap);}
        else ADUIAppend7362(path,[NSString stringWithFormat:@"WEB_RESULT label=%@ non-string class=%@\n",label?:@"JS",NSStringFromClass([result class])],cap);
        if(done)dispatch_async(dispatch_get_main_queue(),done);
    }];
}

static void ADUIScanWebViewFull7364(WKWebView *wv,NSUInteger index,NSString *path,unsigned long long cap,void (^done)(void)){
    if(!wv){if(done)done();return;}UIScrollView *sv=wv.scrollView;CGPoint original=sv.contentOffset;BOOL originalScroll=sv.scrollEnabled;sv.scrollEnabled=NO;CGRect wr=CGRectZero;@try{wr=[wv convertRect:wv.bounds toView:nil];}@catch(...){}
    UIEdgeInsets in=sv.adjustedContentInset;CGFloat minY=-in.top;CGFloat viewport=MAX(1.0,sv.bounds.size.height),stride=MAX(260.0,MIN(680.0,viewport*0.62));
    ADUIAppend7362(path,[NSString stringWithFormat:@"\n===== WEBVIEW FULL SWEEP index=%lu ptr=%p frame=%@ originalOffset=(%.1f,%.1f) content=(%.1fx%.1f) inset=(%.1f,%.1f,%.1f,%.1f) viewport=%.1f stride=%.1f maxSteps=72 =====\n",(unsigned long)index,wv,ADUIRect7362(wr),original.x,original.y,sv.contentSize.width,sv.contentSize.height,in.top,in.left,in.bottom,in.right,viewport,stride],cap);
    __block NSUInteger step=0;__block CGFloat targetY=minY,lastY=-999999;__block BOOL finishing=NO;__block void (^next)(void)=nil;__block void (^finish)(NSString *)=nil;
    finish=^(NSString *reason){if(finishing)return;finishing=YES;@try{[sv setContentOffset:original animated:NO];[sv layoutIfNeeded];sv.scrollEnabled=originalScroll;}@catch(...){}ADUIAppend7362(path,[NSString stringWithFormat:@"WEB_SWEEP_END index=%lu reason=%@ steps=%lu restoredOffset=(%.1f,%.1f) finalContent=(%.1fx%.1f)\n",(unsigned long)index,reason?:@"done",(unsigned long)step,sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height],cap);if(done)done();next=nil;finish=nil;};
    void (^finalInventory)(NSString *)=^(NSString *reason){ADUIEvalAppend7364(wv,path,ADUIWebJS7364(@"full",@"post-sweep-full",step),@"POST_SWEEP_FULL_DOM",cap,^{finish(reason);});};
    void (^startSweep)(void)=^{
        CGFloat maxY=MAX(minY,sv.contentSize.height-sv.bounds.size.height+sv.adjustedContentInset.bottom);
        if(maxY-minY<8.0){ADUIEvalAppend7364(wv,path,ADUIWebJS7364(@"viewport",@"sweep-step",0),@"SWEEP_STEP_0",cap,^{finalInventory(@"not-scrollable");});return;}
        next=^{
            if(finishing)return;if(!wv.window||!sv.superview){finalInventory(@"web-left-window");return;}if(step>=72){finalInventory(@"step-cap");return;}
            UIEdgeInsets curIn=sv.adjustedContentInset;CGFloat curMin=-curIn.top;CGFloat max=MAX(curMin,sv.contentSize.height-sv.bounds.size.height+curIn.bottom);targetY=MIN(MAX(curMin,targetY),max);
            if(step>0&&fabs(targetY-lastY)<0.5&&fabs(targetY-max)<0.5){finalInventory(@"bottom");return;}
            @try{[sv setContentOffset:CGPointMake(original.x,targetY) animated:NO];[sv layoutIfNeeded];}@catch(...){}
            NSUInteger thisStep=step++;CGFloat thisY=targetY;lastY=targetY;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.22*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                NSString *label=[NSString stringWithFormat:@"SWEEP_STEP_%lu",(unsigned long)thisStep];
                ADUIEvalAppend7364(wv,path,ADUIWebJS7364(@"viewport",@"sweep-step",thisStep),label,cap,^{
                    UIEdgeInsets ni=sv.adjustedContentInset;CGFloat nmin=-ni.top;CGFloat nmax=MAX(nmin,sv.contentSize.height-sv.bounds.size.height+ni.bottom);
                    if(fabs(thisY-nmax)<0.5){finalInventory(@"bottom");return;}targetY=MIN(nmax,thisY+stride);dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.04*NSEC_PER_SEC)),dispatch_get_main_queue(),next);
                });
            });
        };dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.04*NSEC_PER_SEC)),dispatch_get_main_queue(),next);
    };
    ADUIEvalAppend7364(wv,path,ADUIWebJS7364(@"full",@"initial-full",0),@"INITIAL_FULL_DOM",cap,startSweep);
}

static void ADUIProcessWebViews7364(NSArray *webs,NSUInteger index,BOOL viewportOnly,NSString *path,unsigned long long cap,void (^done)(void)){
    if(index>=webs.count){if(done)done();return;}WKWebView *wv=webs[index];CGRect wr=CGRectZero;@try{wr=[wv convertRect:wv.bounds toView:nil];}@catch(...){}UIScrollView *sv=wv.scrollView;CGPoint off=sv.contentOffset;CGSize content=sv.contentSize;
    ADUIAppend7362(path,[NSString stringWithFormat:@"\n===== WEBVIEW index=%lu ptr=%p frame=%@ offset=(%.1f,%.1f) content=(%.1fx%.1f) =====\n",(unsigned long)index,wv,ADUIRect7362(wr),off.x,off.y,content.width,content.height],cap);
    void (^nextWeb)(void)=^{ADUIProcessWebViews7364(webs,index+1,viewportOnly,path,cap,done);};
    if(viewportOnly)ADUIEvalAppend7364(wv,path,ADUIWebJS7364(@"viewport",@"viewport-trigger",0),@"VIEWPORT_DOM",cap,nextWeb);
    else ADUIScanWebViewFull7364(wv,index,path,cap,nextWeb);
}

static void ADUIScanNativeAxis7364(UIScrollView *sv,NSUInteger selectedIndex,BOOL horizontal,NSString *path,unsigned long long cap,CGPoint original,void (^done)(void)){
    if(!sv){if(done)done();return;}UIEdgeInsets in=sv.adjustedContentInset;CGFloat min=horizontal?-in.left:-in.top;CGFloat viewport=MAX(1.0,horizontal?sv.bounds.size.width:sv.bounds.size.height);CGFloat stride=MAX(180.0,MIN(620.0,viewport*0.62));NSUInteger maxSteps=horizontal?48:64;
    __block NSUInteger step=0;__block CGFloat target=min,last=-999999;__block BOOL finishing=NO;__block void (^next)(void)=nil;__block void (^finish)(NSString *)=nil;
    finish=^(NSString *reason){if(finishing)return;finishing=YES;@try{CGPoint p=sv.contentOffset;if(horizontal)p.x=original.x;else p.y=original.y;[sv setContentOffset:p animated:NO];[sv layoutIfNeeded];}@catch(...){}ADUIAppend7362(path,[NSString stringWithFormat:@"NATIVE_AXIS_END selected=%lu ptr=%p axis=%@ reason=%@ steps=%lu offset=(%.1f,%.1f)\n",(unsigned long)selectedIndex,sv,horizontal?@"x":@"y",reason?:@"done",(unsigned long)step,sv.contentOffset.x,sv.contentOffset.y],cap);if(done)done();next=nil;finish=nil;};
    next=^{
        if(finishing)return;if(!sv.window||!sv.superview){finish(@"native-left-window");return;}if(step>=maxSteps){finish(@"step-cap");return;}UIEdgeInsets ci=sv.adjustedContentInset;CGFloat cmin=horizontal?-ci.left:-ci.top;CGFloat max=horizontal?MAX(cmin,sv.contentSize.width-sv.bounds.size.width+ci.right):MAX(cmin,sv.contentSize.height-sv.bounds.size.height+ci.bottom);target=MIN(MAX(cmin,target),max);
        if(step>0&&fabs(target-last)<0.5&&fabs(target-max)<0.5){finish(@"edge");return;}CGPoint p=original;if(horizontal){p.x=target;p.y=sv.contentOffset.y;}else{p.y=target;p.x=sv.contentOffset.x;}@try{[sv setContentOffset:p animated:NO];[sv layoutIfNeeded];}@catch(...){}NSUInteger thisStep=step++;CGFloat thisTarget=target;last=target;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.20*NSEC_PER_SEC)),dispatch_get_main_queue(),^{NSString *phase=[NSString stringWithFormat:@"candidate-%lu-%@-step-%lu",(unsigned long)selectedIndex,horizontal?@"x":@"y",(unsigned long)thisStep];ADUIAppend7362(path,ADUINativeSubtreeSnapshot7364(sv,phase,10000),cap);UIEdgeInsets ni=sv.adjustedContentInset;CGFloat nmin=horizontal?-ni.left:-ni.top;CGFloat nmax=horizontal?MAX(nmin,sv.contentSize.width-sv.bounds.size.width+ni.right):MAX(nmin,sv.contentSize.height-sv.bounds.size.height+ni.bottom);if(fabs(thisTarget-nmax)<0.5){finish(@"edge");return;}target=MIN(nmax,thisTarget+stride);dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.04*NSEC_PER_SEC)),dispatch_get_main_queue(),next);});
    };dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.04*NSEC_PER_SEC)),dispatch_get_main_queue(),next);
}

static void ADUIScanNativeCandidate7364(NSDictionary *meta,NSUInteger selectedIndex,NSString *path,unsigned long long cap,void (^done)(void)){
    UIScrollView *sv=meta[@"sv"];if(!sv){if(done)done();return;}CGPoint original=sv.contentOffset;BOOL originalScroll=sv.scrollEnabled;sv.scrollEnabled=NO;BOOL vertical=[meta[@"v"] boolValue],horizontal=[meta[@"h"] boolValue];CGRect wr=CGRectZero;@try{wr=[sv convertRect:sv.bounds toView:nil];}@catch(...){}
    ADUIAppend7362(path,[NSString stringWithFormat:@"\n===== NATIVE FULL SWEEP selected=%lu ptr=%p cls=%@ aid=\"%@\" frame=%@ originalOffset=(%.1f,%.1f) content=(%.1fx%.1f) vertical=%d horizontal=%d =====\n",(unsigned long)selectedIndex,sv,NSStringFromClass(sv.class)?:@"?",ADUISafe7362(sv.accessibilityIdentifier),ADUIRect7362(wr),original.x,original.y,sv.contentSize.width,sv.contentSize.height,vertical?1:0,horizontal?1:0],cap);ADUIAppend7362(path,ADUINativeSubtreeSnapshot7364(sv,[NSString stringWithFormat:@"candidate-%lu-initial",(unsigned long)selectedIndex],10000),cap);
    void (^finish)(void)=^{@try{[sv setContentOffset:original animated:NO];[sv layoutIfNeeded];sv.scrollEnabled=originalScroll;}@catch(...){}ADUIAppend7362(path,[NSString stringWithFormat:@"NATIVE_SWEEP_END selected=%lu ptr=%p restoredOffset=(%.1f,%.1f) finalContent=(%.1fx%.1f)\n",(unsigned long)selectedIndex,sv,sv.contentOffset.x,sv.contentOffset.y,sv.contentSize.width,sv.contentSize.height],cap);if(done)done();};
    void (^runX)(void)=^{if(horizontal)ADUIScanNativeAxis7364(sv,selectedIndex,YES,path,cap,original,finish);else finish();};
    if(vertical)ADUIScanNativeAxis7364(sv,selectedIndex,NO,path,cap,original,runX);else runX();
}
static void ADUIProcessNativeCandidates7364(NSArray *candidates,NSUInteger index,NSString *path,unsigned long long cap,void (^done)(void)){
    if(index>=candidates.count){if(done)done();return;}ADUIScanNativeCandidate7364(candidates[index],index,path,cap,^{ADUIProcessNativeCandidates7364(candidates,index+1,path,cap,done);});
}

static void ADUIFinishCapture7364(BOOL viewportOnly,NSArray *webs,NSString *path,unsigned long long cap){
    if(!viewportOnly){ADUIAppend7362(path,@"\n===== NATIVE FINAL FULL SNAPSHOT =====\n",cap);ADUIAppend7362(path,ADUINativeSnapshot7362(NO),cap);}
    ADUIAppendTerminal7364(path,[NSString stringWithFormat:@"\nUI_PROBE_END category=%@ webviews=%lu\n================ END RUN ================\n",viewportOnly?@"viewport":@"full-sweep",(unsigned long)webs.count],cap);gADUIProbeBusy7362=NO;
}

static void ADCaptureUniversalUIProbe7362(BOOL viewportOnly,NSString *trigger){
    if(!gP.enabled||gADUIProbeBusy7362)return;gADUIProbeBusy7362=YES;
    NSUInteger run=viewportOnly?++gADUIViewportRun7362:++gADUIFullRun7362;unsigned long long cap=viewportOnly?kADUIViewportCap7362:kADUIFullCap7362;NSString *path=ADUIProbePath7362(viewportOnly,run);NSArray *webs=ADUIWebViews7362();
    NSString *header=[NSString stringWithFormat:@"AMAZONDARK v7.380 UNIVERSAL %@ UI FORENSICS PROBE\nversion=%s\ncategory=%@\ntrigger=%@\ndate=%@\nfile=%@\ncap_bytes=%llu\ncontract=screenshot always captures FULL SWEEP; scripts/ui-probe.sh arm captures VIEWPORT via one-shot SIGUSR2\nroute_policy=universal: no tab/menu/product/cart/person/alexa dispatcher; every current on-screen WKWebView plus every eligible current native scroll renderer is discovered dynamically\nprivacy=no visible text strings, accessibilityLabel/value strings, URL/src/href values, network payloads or clipboard data; text is length+hash only; technical class/id/testid/component paint metadata retained\nweb=%@\nnative=%@\nnormal_runtime=single screenshot notification + single SIGUSR2 dispatch source only; all scrolling/traversal is finite and exists only after an explicit trigger; no MutationObserver/timer/RAF/web-scroll listener/recurring hierarchy scan\nwebviews=%lu\n\n===== NATIVE INITIAL %@ SNAPSHOT =====\n",
        viewportOnly?@"VIEWPORT":@"FULL-SWEEP",AD_VERSION,viewportOnly?@"viewport":@"full-web-native-sweep",trigger?:@"unknown",[NSDate date],path.lastPathComponent,cap,
        viewportOnly?@"current visual viewport of every on-screen WKWebView; no offset mutation":@"initial full mounted DOM + finite top-to-bottom WKScrollView sweep for every on-screen WKWebView + final full DOM after hydration; every original offset/scrollEnabled value restored",
        viewportOnly?@"current screen-intersecting UIKit/React hierarchy only":@"initial/final full visible-window hierarchy + dynamically discovered non-WebKit scroll candidates swept across every scrollable axis with per-step subtree snapshots; every original offset/scrollEnabled value restored",
        (unsigned long)webs.count,viewportOnly?@"VIEWPORT":@"FULL"];
    ADUIAppend7362(path,header,cap);ADUIAppend7362(path,ADUINativeSnapshot7362(viewportOnly),cap);
    ADUIProcessWebViews7364(webs,0,viewportOnly,path,cap,^{
        if(viewportOnly){ADUIFinishCapture7364(YES,webs,path,cap);return;}
        ADUIAppend7362(path,@"\n===== NATIVE SCROLL DISCOVERY / SWEEP =====\n",cap);NSArray *native=ADUINativeScrollCandidates7364(path,cap);ADUIProcessNativeCandidates7364(native,0,path,cap,^{ADUIFinishCapture7364(NO,webs,path,cap);});
    });
}

static NSString *ADUIViewportArmPath7362(void){ return [ADUIDocuments7362() stringByAppendingPathComponent:@"AmazonDark-v7.380-ui-viewport.arm"]; }
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
