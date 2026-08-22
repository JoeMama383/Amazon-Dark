// AmazonDark v6.0.207~experimental
// Minimal whole-app inversion experiment.
// Retained: SpringBoard cover/JIT broker, current prefs, 120 Hz, current top/search/bottom chrome, TWB.
// Removed: Dark Reader, native color engine, semantic surface repair, probes, glyph painters, card/border owners.

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>
#import <dlfcn.h>
#import <sys/types.h>
#import <unistd.h>
#import <stdint.h>
#import <errno.h>
#import <string.h>
#import <math.h>
#import <stdio.h>

#define AD_VERSION "v6.0.207-experimental"
#define AD_PREF_DOMAIN "com.colindavidr.amazondark"

extern char *__progname;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wobjc-method-access"

@interface CAFilter : NSObject
+ (id)filterWithType:(NSString *)type;
@end
@interface ANXTopNavBackgroundView : UIView @end
@interface _UIBarBackground : UIView @end
@interface SBSearchBar : UIView @end
@interface SBSearchField : UIView @end
@interface CXIStoreModesBottomNavToolbar : UIView @end
@interface CXIStoreModesTabBarView : UIView @end
@interface ANPRetailTabBar : UIView @end
@interface RCTUIImageViewAnimated : UIImageView @end
@interface ANXFastImageView : UIImageView @end

// -----------------------------------------------------------------------------
// Preferences — exact visible v185 settings are retained.
// -----------------------------------------------------------------------------
typedef struct {
    BOOL enabled;
    BOOL whiteTame;
    BOOL force120Hz;
    BOOL enableJIT;
    long whiteTameStrength;
} ADPrefs;
static ADPrefs gP;

static long ADPrefLong(NSDictionary *d, NSString *k, long def){
    id v=d[k]; return (v&&[v respondsToSelector:@selector(longValue)])?[v longValue]:def;
}
static BOOL ADPrefBool(NSDictionary *d, NSString *k, BOOL def){
    id v=d[k]; return (v&&[v respondsToSelector:@selector(boolValue)])?[v boolValue]:def;
}
static void ADLoadPrefs(void){
    gP.enabled=YES; gP.whiteTame=NO; gP.force120Hz=NO; gP.enableJIT=NO; gP.whiteTameStrength=45;
    @try {
        NSUserDefaults *u=[[NSUserDefaults alloc] initWithSuiteName:@AD_PREF_DOMAIN];
        NSDictionary *d=[u dictionaryRepresentation]?:@{};
        NSMutableArray *paths=[NSMutableArray arrayWithObjects:
            @"/var/jb/var/mobile/Library/Preferences/com.colindavidr.amazondark.plist",
            @"/var/mobile/Library/Preferences/com.colindavidr.amazondark.plist",nil];
        @try {
            Dl_info pi;
            if(dladdr((const void *)&ADLoadPrefs,&pi)&&pi.dli_fname){
                NSString *img=[NSString stringWithUTF8String:pi.dli_fname];
                NSRange jb=[img rangeOfString:@"/jb/"];
                if(jb.location!=NSNotFound){
                    NSString *root=[img substringToIndex:jb.location+jb.length-1];
                    [paths addObject:[root stringByAppendingPathComponent:@"var/mobile/Library/Preferences/com.colindavidr.amazondark.plist"]];
                }
            }
        } @catch(...) {}
        for(NSString *p in paths){
            NSDictionary *f=[NSDictionary dictionaryWithContentsOfFile:p];
            if(f.count){ NSMutableDictionary *m=[d mutableCopy]; [m addEntriesFromDictionary:f]; d=m; }
        }
        gP.enabled=ADPrefBool(d,@"enabled",gP.enabled);
        gP.whiteTame=ADPrefBool(d,@"whiteTame",gP.whiteTame);
        gP.force120Hz=ADPrefBool(d,@"force120Hz",gP.force120Hz);
        gP.enableJIT=ADPrefBool(d,@"enableJIT",gP.enableJIT);
        gP.whiteTameStrength=MAX(0,MIN(100,ADPrefLong(d,@"whiteTameStrength",gP.whiteTameStrength)));
    } @catch(...) {}
}

// -----------------------------------------------------------------------------
// Existing Dopamine JIT preference — same SpringBoard broker protocol, no report IO.
// -----------------------------------------------------------------------------
#ifndef CS_OPS_STATUS
#define CS_OPS_STATUS 0
#endif
#ifndef CS_DEBUGGED
#define CS_DEBUGGED 0x10000000
#endif
#ifndef SYS_csops
#define SYS_csops 169
#endif
#define AD_JIT_REQ_NOTIFY_622 "com.colindavidr.amazondark/jit-request-622"
#define AD_JIT_RES_NOTIFY_622 "com.colindavidr.amazondark/jit-result-622"

typedef struct { uint32_t flags; BOOL debugged; } ADJITState622;
static ADJITState622 ADReadJITState622(void){
    ADJITState622 st={0,NO};
    long rc=syscall(SYS_csops,getpid(),CS_OPS_STATUS,&st.flags,sizeof(st.flags));
    st.debugged=(rc==0&&(st.flags&CS_DEBUGGED)!=0); return st;
}
static uint64_t ADJITWireState622(pid_t pid,uint16_t nonce,int rc){
    return (((uint64_t)(uint32_t)pid)<<32)|(((uint64_t)nonce)<<16)|((uint16_t)(int16_t)rc);
}
static pid_t ADJITWirePID622(uint64_t s){return (pid_t)(uint32_t)(s>>32);}
static uint16_t ADJITWireNonce622(uint64_t s){return (uint16_t)((s>>16)&0xffffU);}
static uint16_t ADNextJITNonce622(void){static volatile uint32_t seq=0;uint16_t n=(uint16_t)__sync_add_and_fetch(&seq,1);return n?n:1;}
static void ADApplyJIT622(void){
    if(!gP.enabled||!gP.enableJIT)return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
        @autoreleasepool {
            if(ADReadJITState622().debugged)return;
            int req=0,res=0; uint16_t nonce=ADNextJITNonce622(); pid_t pid=getpid();
            if(notify_register_check(AD_JIT_RES_NOTIFY_622,&res)!=NOTIFY_STATUS_OK)return;
            if(notify_register_check(AD_JIT_REQ_NOTIFY_622,&req)!=NOTIFY_STATUS_OK){notify_cancel(res);return;}
            notify_set_state(req,ADJITWireState622(pid,nonce,0)); notify_post(AD_JIT_REQ_NOTIFY_622);
            for(int i=0;i<35;i++){uint64_t state=0;if(notify_get_state(res,&state)==NOTIFY_STATUS_OK&&ADJITWirePID622(state)==pid&&ADJITWireNonce622(state)==nonce)break;usleep(10000);}
            notify_cancel(req); notify_cancel(res);
        }
    });
}

// -----------------------------------------------------------------------------
// One compositor-level inversion. This is the experiment: one CAFilter on each
// Amazon UIWindow instead of thousands of color/style decisions.
// Product media gets the same filter locally, so the two inversions cancel.
// -----------------------------------------------------------------------------
static const void *kADRootInvert206=&kADRootInvert206;
static const void *kADMediaInvert206=&kADMediaInvert206;
static const void *kADMediaOriginalFilters206=&kADMediaOriginalFilters206;
static const void *kADTWBOverlay206=&kADTWBOverlay206;
static const void *kADTWBImage206=&kADTWBImage206;

static id ADInvertFilter206(void){
    static id f=nil; static dispatch_once_t once;
    dispatch_once(&once,^{ @try { f=[NSClassFromString(@"CAFilter") filterWithType:@"colorInvert"]; } @catch(...) { f=nil; } });
    return f;
}
static BOOL ADArrayHasInvert206(NSArray *a){ id inv=ADInvertFilter206(); if(!inv)return NO; for(id x in a)if(x==inv)return YES; return NO; }
static void ADAddInvert206(CALayer *l,const void *key){
    if(!l||!gP.enabled)return; id inv=ADInvertFilter206(); if(!inv)return;
    @try {
        if(objc_getAssociatedObject(l,key)&&ADArrayHasInvert206(l.filters))return;
        NSArray *old=l.filters?:@[];
        if(key==kADMediaInvert206&&!objc_getAssociatedObject(l,kADMediaOriginalFilters206))
            objc_setAssociatedObject(l,kADMediaOriginalFilters206,old,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if(!ADArrayHasInvert206(old))l.filters=[old arrayByAddingObject:inv];
        objc_setAssociatedObject(l,key,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}
static void ADRemoveMediaInvert206(CALayer *l){
    if(!l||!objc_getAssociatedObject(l,kADMediaInvert206))return;
    @try {
        NSArray *old=objc_getAssociatedObject(l,kADMediaOriginalFilters206);
        l.filters=old?:@[];
        objc_setAssociatedObject(l,kADMediaInvert206,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(l,kADMediaOriginalFilters206,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}
static void ADApplyRootInvert206(UIWindow *w){
    if(!w)return;
    @try {
        if(gP.enabled)ADAddInvert206(w.layer,kADRootInvert206);
        else if(objc_getAssociatedObject(w.layer,kADRootInvert206)){
            NSMutableArray *m=[w.layer.filters mutableCopy]?:[NSMutableArray array]; id inv=ADInvertFilter206(); if(inv)[m removeObjectIdenticalTo:inv]; w.layer.filters=m;
            objc_setAssociatedObject(w.layer,kADRootInvert206,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } @catch(...) {}
}

// Desired final chrome colors are written as their RGB complement because the root
// colorInvert runs after UIKit composites the bar.
static UIColor *ADPreColor206(uint8_t r,uint8_t g,uint8_t b){
    return [UIColor colorWithRed:(255-r)/255.0 green:(255-g)/255.0 blue:(255-b)/255.0 alpha:1.0];
}
static UIColor *ADPreBG206(void){ static UIColor *c; static dispatch_once_t once; dispatch_once(&once,^{c=ADPreColor206(24,26,27);}); return c; }
static UIColor *ADPreFG206(void){ static UIColor *c; static dispatch_once_t once; dispatch_once(&once,^{c=ADPreColor206(232,230,227);}); return c; }
static UIColor *ADPreBlue206(void){ static UIColor *c; static dispatch_once_t once; dispatch_once(&once,^{c=ADPreColor206(0,168,225);}); return c; }
static UIColor *ADPreBorder206(void){ static UIColor *c; static dispatch_once_t once; dispatch_once(&once,^{c=ADPreColor206(73,77,77);}); return c; }

// -----------------------------------------------------------------------------
// Native product media: O(1) per image assignment/layout, no image sampling, no
// semantic text walks, no peer registry. Every large raster photo is protected from
// inversion and, if enabled, gets the existing strength-style black TWB overlay.
// Glyphs/chrome are excluded before any TWB work.
// -----------------------------------------------------------------------------
static BOOL ADIsTabBarItemish(UIView *v);
static BOOL ADInTabBarChain(UIView *v){int d=0;while(v&&d++<12){if(ADIsTabBarItemish(v))return YES;v=v.superview;}return NO;}
static BOOL ADImageTemplateish206(UIImage *im){
    if(!im)return NO; if(im.renderingMode==UIImageRenderingModeAlwaysTemplate)return YES;
    CGImageRef cg=im.CGImage; if(cg&&(CGImageIsMask(cg)||CGImageGetAlphaInfo(cg)==kCGImageAlphaOnly))return YES;
    if(im.symbolConfiguration)return YES; return NO;
}
static BOOL ADChromeChain206(UIView *v){
    int d=0; while(v&&d++<10){const char *c=object_getClassName(v);if(c&&(strstr(c,"SearchBar")||strstr(c,"SearchField")||strstr(c,"SearchTextField")||strstr(c,"NavigationBar")||strstr(c,"BottomNav")||strstr(c,"TabBar")||strstr(c,"NavToolbar")))return YES;v=v.superview;} return NO;
}
static BOOL ADGlyphWord206(NSString *s){
    if(!s.length)return NO; s=s.lowercaseString;
    static NSArray *q=nil; static dispatch_once_t once; dispatch_once(&once,^{q=@[@"icon",@"glyph",@"logo",@"avatar",@"profile",@"badge",@"rating",@"star",@"chevron",@"checkbox",@"heart",@"share",@"search",@"camera",@"microphone",@"menu",@"hamburger",@"sprite",@"button",@"nav",@"tabbar"];});
    for(NSString *x in q)if([s containsString:x])return YES; return NO;
}
static BOOL ADNativeRasterPreserve207(UIImageView *iv){
    if(!iv||!iv.image||!iv.window||ADInTabBarChain(iv)||ADChromeChain206(iv)||ADImageTemplateish206(iv.image))return NO;
    NSString *meta=[NSString stringWithFormat:@"%@ %@ %@",NSStringFromClass(iv.class),iv.accessibilityIdentifier?:@"",iv.accessibilityLabel?:@""];
    if(ADGlyphWord206(meta))return NO;
    CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;if(w<1)w=iv.image.size.width;if(h<1)h=iv.image.size.height;
    CGImageRef cg=iv.image.CGImage;if(!cg)return NO;size_t pw=CGImageGetWidth(cg),ph=CGImageGetHeight(cg);
    // Preserve ordinary raster artwork/photos, but leave tiny icon bitmaps in the
    // globally inverted glyph lane so they become light with the rest of the UI.
    return (w>=40&&h>=40&&pw>=48&&ph>=48);
}
static BOOL ADNativeTWBEligible207(UIImageView *iv){
    if(!ADNativeRasterPreserve207(iv))return NO;
    CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
    if(w<1)w=iv.image.size.width;if(h<1)h=iv.image.size.height;
    if(w<44||h<44||w>1800||h>1800)return NO;
    NSString *meta=[NSString stringWithFormat:@"%@ %@ %@",NSStringFromClass(iv.class),iv.accessibilityIdentifier?:@"",iv.accessibilityLabel?:@""];
    if(ADGlyphWord206(meta))return NO;
    CGImageRef cg=iv.image.CGImage;
    if(cg){size_t pw=CGImageGetWidth(cg),ph=CGImageGetHeight(cg);if(pw<64||ph<64)return NO;}
    return YES;
}
static void ADRemoveTWB206(UIImageView *iv){
    CALayer *ov=objc_getAssociatedObject(iv,kADTWBOverlay206); if(ov){[ov removeFromSuperlayer];objc_setAssociatedObject(iv,kADTWBOverlay206,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);} objc_setAssociatedObject(iv,kADTWBImage206,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void ADUpdateNativeMedia206(UIImageView *iv){
    if(!iv)return;
    @try {
        BOOL preserve=gP.enabled&&ADNativeRasterPreserve207(iv);
        if(!preserve){ADRemoveMediaInvert206(iv.layer);ADRemoveTWB206(iv);return;}
        // Root inversion owns the app. Every ordinary raster image gets the same
        // local invert, cancelling the root filter so image pixels remain stock.
        ADAddInvert206(iv.layer,kADMediaInvert206);
        if(!gP.whiteTame||!ADNativeTWBEligible207(iv)){ADRemoveTWB206(iv);return;}
        CALayer *ov=objc_getAssociatedObject(iv,kADTWBOverlay206);
        if(!ov){ov=[CALayer layer];ov.name=@"AmazonDarkTWB207";[iv.layer addSublayer:ov];objc_setAssociatedObject(iv,kADTWBOverlay206,ov,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
        CGFloat a=0.50*(MAX(0,MIN(100,gP.whiteTameStrength))/100.0);
        [CATransaction begin];[CATransaction setDisableActions:YES];ov.frame=iv.bounds;ov.backgroundColor=[UIColor colorWithWhite:0 alpha:a].CGColor;ov.cornerRadius=iv.layer.cornerRadius;ov.masksToBounds=YES;ov.zPosition=CGFLOAT_MAX;[CATransaction commit];
        objc_setAssociatedObject(iv,kADTWBImage206,iv.image,OBJC_ASSOCIATION_ASSIGN);
    } @catch(...) {}
}

// -----------------------------------------------------------------------------
// Web product media counter-inversion + generalized TWB. The WebView itself is
// inverted only once by the UIWindow filter. Product media gets CSS invert(1), so
// it cancels the compositor inversion. TWB uses opacity: against the pre-inversion
// light page, which becomes a black blend after the root inversion.
// No MutationObserver, scroll listener, RAF loop, or Dark Reader exists here.
// -----------------------------------------------------------------------------
static NSString *ADWebMediaJS206(void){
    CGFloat q=1.0-(0.50*(MAX(0,MIN(100,gP.whiteTameStrength))/100.0)); if(!gP.whiteTame)q=1.0;
    return [NSString stringWithFormat:
    @"(function(){try{if(window.__AD_MIN207__)return;window.__AD_MIN207__=1;"
     "var Q=%.3f;var S=document.createElement('style');S.id='ad-min207';"
     "S.textContent='[data-ad-media207=\"1\"],#gwm-PageContent img,[class*=gwm] img,[class*=single-creative-card] img,[class*=single-video-card] img,[class*=theming-card] img{filter:invert(1)!important;}'+"
     "'[data-ad-twb207=\"1\"]{opacity:'+Q+'!important;}'+"
     "'[class*=theming-card-background],[class*=vjs-poster],[style*=background-image][class*=image],[style*=background-image][class*=poster],[style*=background-image][class*=creative]{filter:invert(1)!important;}';"
     "(document.head||document.documentElement).appendChild(S);"
     "function bad(e){try{var z=((e.className&&e.className.baseVal!==undefined)?e.className.baseVal:e.className)||'';z+=' '+(e.id||'')+' '+(e.getAttribute('alt')||'')+' '+(e.getAttribute('aria-label')||'')+' '+(e.getAttribute('src')||'');return /icon|glyph|logo|avatar|profile|badge|rating|star|chevron|checkbox|heart|share|search|camera|microphone|menu|hamburger|sprite|button|nav-|store-logo/i.test(z)||!!(e.closest&&e.closest('.puis-mab-overlay,[role=menu],[class*=searchbar],[class*=search-bar],[class*=nav-search]'));}catch(x){return true;}}"
     "function own(e){try{if(!e||e.nodeType!==1||bad(e))return;var t=String(e.tagName||'').toUpperCase();if(!/^(IMG|VIDEO|CANVAS)$/.test(t))return;var r=e.getBoundingClientRect?e.getBoundingClientRect():{width:0,height:0};var w=r.width||e.width||e.naturalWidth||e.videoWidth||0,h=r.height||e.height||e.naturalHeight||e.videoHeight||0;if(w<32||h<32)return;e.setAttribute('data-ad-media207','1');if(w>=44&&h>=44)e.setAttribute('data-ad-twb207','1');}catch(x){}}"
     "document.addEventListener('load',function(ev){own(ev.target);},true);document.addEventListener('loadedmetadata',function(ev){own(ev.target);},true);"
     "function init(){try{var a=document.querySelectorAll('img,video,canvas');for(var i=0;i<a.length;i++)own(a[i]);}catch(x){}}"
     "if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();"
     "window.__AD_TWB207__=function(v){Q=v;S.textContent=S.textContent.replace(/opacity:[0-9.]+!important/g,'opacity:'+Q+'!important');};"
     "}catch(e){}})();",q];
}
static void ADInstallWeb206(WKUserContentController *ucc){
    if(!ucc||!gP.enabled)return; static const void *k=&k;
    @try { if(objc_getAssociatedObject(ucc,k))return; WKUserScript *s=[[WKUserScript alloc] initWithSource:ADWebMediaJS206() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];[ucc addUserScript:s];objc_setAssociatedObject(ucc,k,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC); } @catch(...) {}
}

// -----------------------------------------------------------------------------
// v185 bottom navigation — direct behavioral port.
// The only experiment-specific addition is one counter-invert on the topmost bar
// host so the UIWindow inversion does not alter v185's own dark/white/blue output.
// -----------------------------------------------------------------------------
static UIColor *ADThemeColor207(NSString *hex){
    unsigned v=0; if(hex.length==7)sscanf(hex.UTF8String,"#%06x",&v);
    return [UIColor colorWithRed:((v>>16)&255)/255.0 green:((v>>8)&255)/255.0 blue:(v&255)/255.0 alpha:1.0];
}
static BOOL ADIsTabBarItemish(UIView *v){const char *n=object_getClassName(v);if(!n)return NO;return strstr(n,"BottomNav")||strstr(n,"TabBarItem")||strstr(n,"TabBar")||strstr(n,"NavToolbar");}
static UIColor *gAmazonBlue=nil;
static UIColor *ADBarBlue(void){if(gAmazonBlue)return gAmazonBlue;return ADThemeColor207(@"#00A8E1");}
static UIColor *ADBarWhite(void){return ADThemeColor207(@"#e8e6e3");}
static const void *kADBarSelKey=&kADBarSelKey,*kADBarPressKey=&kADBarPressKey;
static const void *kADBarNeutralize207=&kADBarNeutralize207,*kADBarNeutralizeOrig207=&kADBarNeutralizeOrig207;
static BOOL gADBarImageWriting6069=NO,gBarFixPending=NO,gBarCorrecting=NO;
static void ADSetBarNeutralize207(UIView *v,BOOL on){
    if(!v)return;@try{
        CALayer *l=v.layer;id inv=ADInvertFilter206();if(!inv)return;
        if(on){
            if(!objc_getAssociatedObject(l,kADBarNeutralize207))objc_setAssociatedObject(l,kADBarNeutralizeOrig207,l.filters?:@[],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            NSArray *a=l.filters?:@[];if(!ADArrayHasInvert206(a))l.filters=[a arrayByAddingObject:inv];
            objc_setAssociatedObject(l,kADBarNeutralize207,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }else if(objc_getAssociatedObject(l,kADBarNeutralize207)){
            l.filters=objc_getAssociatedObject(l,kADBarNeutralizeOrig207)?:@[];
            objc_setAssociatedObject(l,kADBarNeutralize207,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(l,kADBarNeutralizeOrig207,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }@catch(...){}
}
static BOOL ADExactBarHost207(UIView *v){const char *c=object_getClassName(v);return c&&(strstr(c,"CXIStoreModesBottomNavToolbar")||strstr(c,"CXIStoreModesTabBarView")||strstr(c,"ANPRetailTabBar"));}
static UIView *ADTopBarHost207(UIView *v){UIView *top=nil;int d=0;for(UIView *p=v;p&&d++<14;p=p.superview)if(ADExactBarHost207(p))top=p;return top?:v;}
static void ADEnsureBarNeutralize207(UIView *v){if(!v)return;UIView *top=ADTopBarHost207(v);if(top!=v)ADSetBarNeutralize207(v,NO);ADSetBarNeutralize207(top,gP.enabled);}
static void ADRememberBarSelection(UIView *root,BOOL selected){if(!root)return;@try{objc_setAssociatedObject(root,kADBarSelKey,@(selected),OBJC_ASSOCIATION_RETAIN_NONATOMIC);for(UIView *s in root.subviews)ADRememberBarSelection(s,selected);}@catch(...) {}}
static void ADRememberBarPress(UIView *root,BOOL selected){if(!root)return;@try{objc_setAssociatedObject(root,kADBarPressKey,@(selected),OBJC_ASSOCIATION_RETAIN_NONATOMIC);for(UIView *s in root.subviews)ADRememberBarPress(s,selected);}@catch(...) {}}
static void ADClearBarPress(UIView *root){if(!root)return;@try{objc_setAssociatedObject(root,kADBarPressKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);for(UIView *s in root.subviews)ADClearBarPress(s);}@catch(...) {}}
static BOOL ADBarSelectionKnown(UIView *v,BOOL *out){int d=0;UIView *p=v;while(p&&d++<12){NSNumber *n=objc_getAssociatedObject(p,kADBarPressKey);if(n){*out=n.boolValue;return YES;}p=p.superview;}d=0;p=v;while(p&&d++<12){NSNumber *n=objc_getAssociatedObject(p,kADBarSelKey);if(n){*out=n.boolValue;return YES;}p=p.superview;}return NO;}
static BOOL ADViewIsSelectedInBar(UIView *v){BOOL known=NO;if(ADBarSelectionKnown(v,&known))return known;int d=0;while(v&&d++<12){if([v isKindOfClass:[UIControl class]]&&((UIControl*)v).selected)return YES;v=v.superview;}return NO;}
static void ADTintBarIcon(UIImageView *iv,BOOL selected){
    @try{UIImage *img=iv.image;if(!img)return;if(!ADImageTemplateish206(img)){UIImage *tpl=[img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];if(tpl){gADBarImageWriting6069=YES;@try{iv.image=tpl;}@catch(...){}gADBarImageWriting6069=NO;}}
        UIColor *want=selected?ADBarWhite():ADBarBlue(),*cur=iv.tintColor;CGFloat cr,cg,cb,ca,wr,wg,wb,wa;BOOL same=cur&&[cur getRed:&cr green:&cg blue:&cb alpha:&ca]&&[want getRed:&wr green:&wg blue:&wb alpha:&wa]&&fabs(cr-wr)<.01&&fabs(cg-wg)<.01&&fabs(cb-wb)<.01;if(!same){[CATransaction begin];[CATransaction setDisableActions:YES];[UIView performWithoutAnimation:^{iv.tintColor=want;}];[CATransaction commit];}}
    @catch(...){gADBarImageWriting6069=NO;}
}
static void ADApplyBarTint(UIView *v,BOOL s){if(!v)return;@try{if([v isKindOfClass:[UIImageView class]])ADTintBarIcon((UIImageView*)v,s);for(UIView *x in v.subviews)ADApplyBarTint(x,s);}@catch(...) {}}
static void ADCorrectBarTintsIn(UIView *v){if(!v)return;@try{if([v isKindOfClass:[UIControl class]]&&ADInTabBarChain(v)){BOOL s=NO;if(!ADBarSelectionKnown(v,&s))s=((UIControl*)v).selected;ADApplyBarTint(v,s);}for(UIView *x in v.subviews)ADCorrectBarTintsIn(x);}@catch(...) {}}
static void ADScheduleBarCorrection(void){if(gBarFixPending||gBarCorrecting)return;gBarFixPending=YES;dispatch_async(dispatch_get_main_queue(),^{gBarFixPending=NO;gBarCorrecting=YES;@try{for(UIScene *sc in UIApplication.sharedApplication.connectedScenes)if([sc isKindOfClass:[UIWindowScene class]])for(UIWindow *w in ((UIWindowScene*)sc).windows)ADCorrectBarTintsIn(w);}@catch(...){}gBarCorrecting=NO;});}
static UIView *ADBarHostForView6153(UIView *v){UIView *fallback=nil;int d=0;while(v&&d++<14){const char *c=object_getClassName(v);if(c){if(strstr(c,"CXIStoreModesBottomNavToolbar")||strstr(c,"CXIStoreModesTabBarView")||strstr(c,"ANPRetailTabBar"))return v;if(strstr(c,"BottomNav")||strstr(c,"TabBar")||strstr(c,"NavToolbar"))fallback=v;}v=v.superview;}return fallback;}
static BOOL ADSameBarBranch6153(UIView *candidate,UIView *pressed){if(!candidate||!pressed)return NO;if(candidate==pressed)return YES;@try{if([pressed isDescendantOfView:candidate])return YES;if([candidate isDescendantOfView:pressed])return YES;}@catch(...){}return NO;}
static void ADClaimBarPressWalk6153(UIView *v,UIView *pressed){if(!v)return;@try{if([v isKindOfClass:[UIControl class]]&&ADInTabBarChain(v)){BOOL hit=ADSameBarBranch6153(v,pressed);ADRememberBarPress(v,hit);ADApplyBarTint(v,hit);}for(UIView *x in v.subviews)ADClaimBarPressWalk6153(x,pressed);}@catch(...) {}}
static void ADClaimBarPress6153(UIView *pressed){if(!pressed)return;@try{UIView *host=ADBarHostForView6153(pressed);if(host){ADClearBarPress(host);ADClaimBarPressWalk6153(host,pressed);}else{ADRememberBarPress(pressed,YES);ADApplyBarTint(pressed,YES);}}@catch(...) {}}
static void ADReleaseBarPress6153(UIView *v){if(!v)return;@try{UIView *host=ADBarHostForView6153(v);ADClearBarPress(host?:v);}@catch(...) {}}
static void ADForceBarDark(UIView *bar){if(!gP.enabled||!bar)return;@try{UIColor *want=ADThemeColor207(@"#181a1b"),*have=bar.backgroundColor;CGFloat r1,g1,b1,a1,r2,g2,b2,a2;BOOL same=have&&[have getRed:&r1 green:&g1 blue:&b1 alpha:&a1]&&[want getRed:&r2 green:&g2 blue:&b2 alpha:&a2]&&fabs(r1-r2)<.01&&fabs(g1-g2)<.01&&fabs(b1-b2)<.01&&fabs(a1-a2)<.01;if(!same)bar.backgroundColor=want;}@catch(...) {}}

// Search/top chrome remains the v185 visual contract. Because those surfaces stay
// under the root inversion, write the inverse RGB only at these exact owners.
static void ADPaintSearchBorder206(UIView *v){if(gP.enabled&&v)v.layer.borderColor=ADPreBorder206().CGColor;}

%hook UIWindow
- (void)didMoveToWindow {
    %orig;
    ADApplyRootInvert206(self);
}
- (void)layoutSubviews {
    %orig;
    ADApplyRootInvert206(self);
}
%end

%hook UIView
- (void)setTintColor:(UIColor *)color {
    @try {
        if(gP.enabled&&ADInTabBarChain(self)){
            if(color&&!gAmazonBlue){CGFloat r,g,b,a;if([color getRed:&r green:&g blue:&b alpha:&a]){CGFloat mx=MAX(r,MAX(g,b)),mn=MIN(r,MIN(g,b));if((mx-mn)>.15&&b>=r*.9)gAmazonBlue=[UIColor colorWithRed:r green:g blue:b alpha:1.0];}}
            BOOL sel=NO;if(!ADBarSelectionKnown(self,&sel))sel=ADViewIsSelectedInBar(self);UIColor *want=sel?ADBarWhite():ADBarBlue();
            CGFloat ir,ig,ib,ia,tr,tg,tb,ta;BOOL same=color&&[color getRed:&ir green:&ig blue:&ib alpha:&ia]&&[want getRed:&tr green:&tg blue:&tb alpha:&ta]&&fabs(ir-tr)<.01&&fabs(ig-tg)<.01&&fabs(ib-tb)<.01;
            if(same){
                %orig;
                return;
            }
            ADScheduleBarCorrection();
            %orig(want);
            return;
        }
    }@catch(...){}
    %orig;
}
%end

%hook ANXTopNavBackgroundView
- (void)setBackgroundColor:(UIColor *)c {
    if(gP.enabled){
        UIColor *pre=ADPreBG206();
        %orig(pre);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    if(gP.enabled&&self.window){self.backgroundColor=ADPreBG206();self.layer.backgroundColor=ADPreBG206().CGColor;}
}
- (void)layoutSubviews {
    %orig;
    if(gP.enabled&&self.window){self.backgroundColor=ADPreBG206();self.layer.backgroundColor=ADPreBG206().CGColor;}
}
%end

%hook UIVisualEffectView
- (void)setEffect:(UIVisualEffect *)e {
    if(gP.enabled&&[e isKindOfClass:[UIBlurEffect class]]&&self.bounds.size.width>200&&self.bounds.size.height<160){
        %orig(nil);
        self.backgroundColor=ADPreBG206();
        return;
    }
    %orig;
}
- (void)layoutSubviews {
    %orig;
    @try{if(gP.enabled&&self.window&&self.bounds.size.width>200&&self.bounds.size.height>0&&self.bounds.size.height<160){if(self.effect)self.effect=nil;self.backgroundColor=ADPreBG206();}}@catch(...){}
}
- (void)didMoveToWindow {
    %orig;
    @try{if(gP.enabled&&self.window&&self.bounds.size.height<160)self.backgroundColor=ADPreBG206();}@catch(...){}
}
%end

%hook _UIBarBackground
- (void)layoutSubviews {
    %orig;
    if(gP.enabled)((UIView*)self).backgroundColor=ADPreBG206();
}
%end
%hook SBSearchBar
- (void)layoutSubviews {
    %orig;
    ADPaintSearchBorder206(self);
}
%end
%hook SBSearchField
- (void)layoutSubviews {
    %orig;
    ADPaintSearchBorder206(self);
}
%end
%hook CXIStoreModesBottomNavToolbar
- (void)layoutSubviews {
    %orig;
    ADEnsureBarNeutralize207((UIView*)self);
    ADForceBarDark((UIView*)self);
}
- (void)didMoveToWindow {
    %orig;
    if(self.window){ADEnsureBarNeutralize207((UIView*)self);ADForceBarDark((UIView*)self);ADScheduleBarCorrection();}
}
%end
%hook CXIStoreModesTabBarView
- (void)layoutSubviews {
    %orig;
    ADEnsureBarNeutralize207((UIView*)self);
    ADForceBarDark((UIView*)self);
}
- (void)didMoveToWindow {
    %orig;
    if(self.window){ADEnsureBarNeutralize207((UIView*)self);ADForceBarDark((UIView*)self);ADScheduleBarCorrection();}
}
%end
%hook ANPRetailTabBar
- (void)layoutSubviews {
    %orig;
    ADEnsureBarNeutralize207((UIView*)self);
    ADForceBarDark((UIView*)self);
}
- (void)didMoveToWindow {
    %orig;
    if(self.window){ADEnsureBarNeutralize207((UIView*)self);ADForceBarDark((UIView*)self);ADScheduleBarCorrection();}
}
%end

%hook UIImageView
- (void)setImage:(UIImage *)image {
    if(gADBarImageWriting6069){
        %orig;
        return;
    }
    %orig;
    @try {
        if(ADInTabBarChain(self)){ADRemoveMediaInvert206(self.layer);ADRemoveTWB206(self);ADTintBarIcon(self,ADViewIsSelectedInBar(self));}
        else ADUpdateNativeMedia206(self);
    } @catch(...) {}
}
- (void)didMoveToWindow {
    %orig;
    @try{if(ADInTabBarChain(self))ADTintBarIcon(self,ADViewIsSelectedInBar(self));else ADUpdateNativeMedia206(self);}@catch(...){}
}
- (void)layoutSubviews {
    %orig;
    @try{if(!ADInTabBarChain(self))ADUpdateNativeMedia206(self);}@catch(...){}
}
%end

%hook RCTUIImageViewAnimated
- (void)didMoveToWindow {
    %orig;
    ADUpdateNativeMedia206((UIImageView*)self);
}
- (void)layoutSubviews {
    %orig;
    ADUpdateNativeMedia206((UIImageView*)self);
}
%end
%hook ANXFastImageView
- (void)didMoveToWindow {
    %orig;
    ADUpdateNativeMedia206((UIImageView*)self);
}
- (void)layoutSubviews {
    %orig;
    ADUpdateNativeMedia206((UIImageView*)self);
}
%end

%hook UIButton
- (void)setImage:(UIImage *)im forState:(UIControlState)state {
    %orig;
    if(gP.enabled&&ADInTabBarChain(self))ADApplyBarTint(self,ADViewIsSelectedInBar(self));
}
%end
%hook UIControl
- (void)setSelected:(BOOL)s {
    %orig;
    if(gP.enabled&&ADInTabBarChain(self)){ADRememberBarSelection(self,s);ADApplyBarTint(self,s);if(s)ADReleaseBarPress6153(self);ADScheduleBarCorrection();}
}
- (BOOL)beginTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    BOOL r=NO;
    r=%orig;
    if(gP.enabled&&ADInTabBarChain(self))ADClaimBarPress6153(self);
    return r;
}
- (void)setHighlighted:(BOOL)h {
    %orig;
    if(h&&gP.enabled&&ADInTabBarChain(self))ADClaimBarPress6153(self);
}
- (void)cancelTrackingWithEvent:(UIEvent *)e {
    %orig;
    if(gP.enabled&&ADInTabBarChain(self)){ADReleaseBarPress6153(self);ADScheduleBarCorrection();}
}
%end

%hook WKWebView
- (instancetype)initWithFrame:(CGRect)f configuration:(WKWebViewConfiguration *)cfg {
    if(gP.enabled&&cfg.userContentController)ADInstallWeb206(cfg.userContentController);
    id r=%orig;
    return r;
}
%end

// Light status-bar content is retained because the final top chrome is dark.
%hook UIViewController
- (UIStatusBarStyle)preferredStatusBarStyle {
    if(gP.enabled)return UIStatusBarStyleLightContent;
    UIStatusBarStyle r=%orig;
    return r;
}
%end
%hook UIApplication
- (void)setStatusBarStyle:(UIStatusBarStyle)s {
    if(gP.enabled){
        %orig(UIStatusBarStyleLightContent);
        return;
    }
    %orig;
}
- (void)setStatusBarStyle:(UIStatusBarStyle)s animated:(BOOL)a {
    if(gP.enabled){
        %orig(UIStatusBarStyleLightContent,a);
        return;
    }
    %orig;
}
%end

// SpringBoard cover readiness: the compositor inversion is installed immediately;
// SpringBoard itself enforces the existing 1.40 s minimum display time.
static void ADPostReady206(void){ static BOOL p=NO;if(p)return;p=YES;notify_post("com.colindavidr.amazondark.ready"); }


// ── PROMOTION + PRIVATE CADISPLAY 120 HZ FORCE (v6.0.10) ──────────────────────
// Public ProMotion ranges are advisory and v6.0.9 proved Core Animation was
// normalising Amazon back to 60 Hz even with both bundle opt-ins visible. On a
// jailbreak we can move one layer lower: CADisplay exposes a private
// overrideMinimumFrameDuration: policy selector. v6.0.10 experimentally clamps
// that integer policy to 2 on the 120-Hz device and verifies the resulting
// minimumFrameDuration/actual timing on-device rather than assuming success. We
// install a process-local runtime interpose so later CoreAnimation calls cannot
// silently restore the previous value while the preference is enabled.
//
// This affects only Amazon: AmazonDark.plist still injects this target solely into
// com.amazon.Amazon. We intentionally do NOT inject into backboardd or globally
// force SpringBoard; that would add system-wide battery/thermal cost and a daemon
// crash would be much more disruptive. If this private CADisplay path is absent on
// a future OS, every call is capability-checked and becomes a no-op.
static NSString * const ADPromotionInfoKey607 = @"CADisableMinimumFrameDurationOnPhone";
static NSString * const ADPromotionLegacyInfoKey609 = @"CADisableMinimumFrameDuration";

static BOOL ADIsPromotionInfoKey609(NSString *key){
    return [key isEqualToString:ADPromotionInfoKey607] || [key isEqualToString:ADPromotionLegacyInfoKey609];
}

static inline BOOL ADPromotionPreferenceOn611(void){ return gP.enabled && gP.force120Hz; }

%hook NSBundle
- (id)objectForInfoDictionaryKey:(NSString *)key {
    @try {
        if (ADPromotionPreferenceOn611() && self == [NSBundle mainBundle] && ADIsPromotionInfoKey609(key)) return @YES;
    } @catch(...) {}
    return %orig;
}
- (NSDictionary *)infoDictionary {
    NSDictionary *d = %orig;
    @try {
        if (!ADPromotionPreferenceOn611() || self != [NSBundle mainBundle]) return d;
        if ([d[ADPromotionInfoKey607] boolValue] && [d[ADPromotionLegacyInfoKey609] boolValue]) return d;
        NSMutableDictionary *m = [d mutableCopy];
        m[ADPromotionInfoKey607] = @YES;
        m[ADPromotionLegacyInfoKey609] = @YES;
        return m;
    } @catch(...) {}
    return d;
}
%end

%hookf(CFTypeRef, CFBundleGetValueForInfoDictionaryKey, CFBundleRef bundle, CFStringRef key) {
    if (ADPromotionPreferenceOn611() && bundle == CFBundleGetMainBundle() && key &&
        (CFEqual(key, CFSTR("CADisableMinimumFrameDurationOnPhone")) ||
         CFEqual(key, CFSTR("CADisableMinimumFrameDuration")))) return kCFBooleanTrue;
    return %orig;
}

%hookf(CFDictionaryRef, CFBundleGetInfoDictionary, CFBundleRef bundle) {
    CFDictionaryRef d = %orig;
    if (!ADPromotionPreferenceOn611() || bundle != CFBundleGetMainBundle() || !d) return d;
    static CFDictionaryRef promoted = NULL;
    if (promoted) return promoted;
    CFMutableDictionaryRef m = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, d);
    if (!m) return d;
    CFDictionarySetValue(m, CFSTR("CADisableMinimumFrameDurationOnPhone"), kCFBooleanTrue);
    CFDictionarySetValue(m, CFSTR("CADisableMinimumFrameDuration"), kCFBooleanTrue);
    promoted = m;
    return promoted;
}

static NSInteger ADPreferredMaxHz362(void){
    @try { return MIN((NSInteger)120, MAX((NSInteger)60, UIScreen.mainScreen.maximumFramesPerSecond)); } @catch(...) {}
    return 60;
}

// Weak registry of live links lets the Settings toggle take effect immediately in
// both directions. v6.0.10 only gated future setter calls; links already forced to
// 120 stayed forced until relaunch. Weak storage adds no ownership/lifetime cost.
static NSHashTable *gADDisplayLinks611 = nil;
static void ADTrackDisplayLink611(CADisplayLink *d){
    if (!d) return;
    @try {
        @synchronized([CADisplayLink class]) {
            if (!gADDisplayLinks611) gADDisplayLinks611 = [NSHashTable weakObjectsHashTable];
            [gADDisplayLinks611 addObject:d];
        }
    } @catch(...) {}
}
static NSArray *ADTrackedDisplayLinks611(void){
    @try {
        @synchronized([CADisplayLink class]) { return gADDisplayLinks611 ? gADDisplayLinks611.allObjects : @[]; }
    } @catch(...) {}
    return @[];
}

// Private CADisplay policy interpose. method_setImplementation keeps the hook local
// to Amazon and chains whatever implementation was present before AmazonDark.
typedef void (*ADCADisplayOverrideIMP610)(id, SEL, NSInteger);
static ADCADisplayOverrideIMP610 gADCADisplayOverrideOrig610 = NULL;
static BOOL gADCADisplayOverrideInstallTried610 = NO;
static BOOL gADCADisplayOverrideInstalled610 = NO;
static void ADForceOverrideMinimumFrameDuration610(id self, SEL _cmd, NSInteger duration){
    NSInteger forced = duration;
    @try { if (gP.enabled && gP.force120Hz && ADPreferredMaxHz362() >= 120) forced = 2; } @catch(...) {}
    if (gADCADisplayOverrideOrig610) gADCADisplayOverrideOrig610(self, _cmd, forced);
}
static void ADInstallPrivateDisplayForce610(void){
    if (gADCADisplayOverrideInstallTried610) return;
    gADCADisplayOverrideInstallTried610 = YES;
    @try {
        Class c = NSClassFromString(@"CADisplay");
        SEL sel = NSSelectorFromString(@"overrideMinimumFrameDuration:");
        Method m = c ? class_getInstanceMethod(c, sel) : NULL;
        if (!m) return;
        IMP old = method_getImplementation(m);
        if (!old || old == (IMP)ADForceOverrideMinimumFrameDuration610) return;
        gADCADisplayOverrideOrig610 = (ADCADisplayOverrideIMP610)old;
        method_setImplementation(m, (IMP)ADForceOverrideMinimumFrameDuration610);
        gADCADisplayOverrideInstalled610 = YES;
    } @catch(...) {}
}

static id ADDisplayForLink610(CADisplayLink *d){
    @try {
        SEL s = NSSelectorFromString(@"display");
        if (d && [d respondsToSelector:s]) return ((id(*)(id,SEL))objc_msgSend)(d,s);
    } @catch(...) {}
    return nil;
}

static const void *kADOrigLinkState611 = &kADOrigLinkState611;
static const void *kADOrigDisplayMin611 = &kADOrigDisplayMin611;
static void ADRememberPromotionState611(CADisplayLink *d){
    if (!d || objc_getAssociatedObject(d,kADOrigLinkState611)) return;
    @try {
        NSMutableDictionary *st=[NSMutableDictionary dictionary];
        st[@"fps"] = @(d.preferredFramesPerSecond);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ([d respondsToSelector:@selector(frameInterval)]) st[@"interval"] = @(d.frameInterval);
#pragma clang diagnostic pop
        if (@available(iOS 15.0,*)){
            CAFrameRateRange r=d.preferredFrameRateRange;
            st[@"range"]=[NSValue value:&r withObjCType:@encode(CAFrameRateRange)];
        }
        objc_setAssociatedObject(d,kADOrigLinkState611,st,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        id display=ADDisplayForLink610(d);
        if (display && !objc_getAssociatedObject(display,kADOrigDisplayMin611)){
            SEL minSel=NSSelectorFromString(@"minimumFrameDuration");
            if ([d respondsToSelector:minSel]){
                NSInteger v=((NSInteger(*)(id,SEL))objc_msgSend)(d,minSel);
                if (v>0) objc_setAssociatedObject(display,kADOrigDisplayMin611,@(v),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
    } @catch(...) {}
}
static void ADRestorePromotionState611(CADisplayLink *d){
    if (!d) return;
    @try {
        id display=ADDisplayForLink610(d);
        NSNumber *origMin=display ? objc_getAssociatedObject(display,kADOrigDisplayMin611) : nil;
        SEL forceSel=NSSelectorFromString(@"overrideMinimumFrameDuration:");
        if (origMin && display && [display respondsToSelector:forceSel])
            ((void(*)(id,SEL,NSInteger))objc_msgSend)(display,forceSel,(NSInteger)origMin.integerValue);
        SEL reasonSel=NSSelectorFromString(@"setHighFrameRateReason:");
        if ([d respondsToSelector:reasonSel])
            ((void(*)(id,SEL,uint32_t))objc_msgSend)(d,reasonSel,(uint32_t)0);
        NSDictionary *st=objc_getAssociatedObject(d,kADOrigLinkState611);
        if (st){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSNumber *interval=st[@"interval"];
            if (interval && [d respondsToSelector:@selector(setFrameInterval:)]) d.frameInterval=interval.integerValue;
#pragma clang diagnostic pop
            NSNumber *fps=st[@"fps"];
            if (fps) d.preferredFramesPerSecond=fps.integerValue;
            NSValue *rv=st[@"range"];
            if (rv){
                if (@available(iOS 15.0,*)){
                    CAFrameRateRange r; [rv getValue:&r]; d.preferredFrameRateRange=r;
                }
            }
        }
        objc_setAssociatedObject(d,kADOrigLinkState611,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (display) objc_setAssociatedObject(display,kADOrigDisplayMin611,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}

static BOOL ADForcePrivateDisplay610(CADisplayLink *d){
    if (!d || !gP.enabled || !gP.force120Hz || ADPreferredMaxHz362() < 120) return NO;
    ADInstallPrivateDisplayForce610();
    @try {
        id display = ADDisplayForLink610(d);
        SEL forceSel = NSSelectorFromString(@"overrideMinimumFrameDuration:");
        if (display && [display respondsToSelector:forceSel]){
            ((void(*)(id,SEL,NSInteger))objc_msgSend)(display, forceSel, (NSInteger)2);
            return YES;
        }
    } @catch(...) {}
    return NO;
}

static BOOL ADSetHighFrameRateReason610(CADisplayLink *d){
    @try {
        SEL s = NSSelectorFromString(@"setHighFrameRateReason:");
        if (d && [d respondsToSelector:s]){
            // Private CoreAnimation SPI; non-zero reason keeps this link classified
            // as high-frame-rate work rather than an idle/ordinary 60-Hz client.
            ((void(*)(id,SEL,uint32_t))objc_msgSend)(d,s,(uint32_t)0x41440001); // "AD" + 1
            return YES;
        }
    } @catch(...) {}
    return NO;
}

static CAFrameRateRange ADForcedRange610(void){
    // CAHighFPS' proven jailbreak pattern: leave a usable low bound but pin the
    // preferred + maximum values to the panel maximum. A rigid 120/120/120 range
    // was normalized back to 60 on this device in v6.0.9.
    float hz = (float)ADPreferredMaxHz362();
    return CAFrameRateRangeMake(30.0f, hz, hz);
}

static void ADApplyPromotion610(CADisplayLink *d){
    if (!d) return;
    ADTrackDisplayLink611(d);
    if (!gP.enabled || !gP.force120Hz) return;
    ADRememberPromotionState611(d);
    @try {
        ADForcePrivateDisplay610(d);       // policy first
        ADSetHighFrameRateReason610(d);    // classify link as high-rate
        // CAHighFPS does frameInterval first because Apple's implementation can
        // rewrite preferredFramesPerSecond as a side effect. Its proven fix is to
        // immediately force preferredFramesPerSecond back to 0 (= highest available).
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ([d respondsToSelector:@selector(setFrameInterval:)]) d.frameInterval = 1;
#pragma clang diagnostic pop
        d.preferredFramesPerSecond = 0;
        // Put the iOS 15+ range last so frameInterval's legacy setter cannot claw
        // the range back to 60 after we have selected the 120-Hz ceiling.
        if (@available(iOS 15.0,*)) d.preferredFrameRateRange = ADForcedRange610();
    } @catch(...) {}
}

%hook CADisplayLink
+ (CADisplayLink *)displayLinkWithTarget:(id)target selector:(SEL)sel {
    CADisplayLink *d = %orig;
    ADApplyPromotion610(d);
    return d;
}
- (instancetype)initWithTarget:(id)target selector:(SEL)sel {
    id d = %orig;
    ADApplyPromotion610((CADisplayLink *)d);
    return d;
}
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    @try {
        if (gP.enabled && gP.force120Hz){
            ADForcePrivateDisplay610(self);
            ADSetHighFrameRateReason610(self);
            // Match CAHighFPS: zero means "highest available" and avoids an app-
            // side numeric cap being re-normalized to 60 by Core Animation.
            NSInteger highest610 = 0;
            %orig(highest610);
            return;
        }
    } @catch(...) {}
    %orig;
}
- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    @try {
        if (gP.enabled && gP.force120Hz){
            ADForcePrivateDisplay610(self);
            ADSetHighFrameRateReason610(self);
            CAFrameRateRange range610 = ADForcedRange610();
            %orig(range610);
            return;
        }
    } @catch(...) {}
    %orig;
}
- (void)setFrameInterval:(NSInteger)interval {
    @try {
        if (gP.enabled && gP.force120Hz){
            ADForcePrivateDisplay610(self);
            NSInteger one610 = 1;
            %orig(one610);
            // Exact load-bearing CAHighFPS behavior: setFrameInterval: can impose
            // a 60-FPS preference internally, so clear that cap immediately after.
            if ([self respondsToSelector:@selector(setPreferredFramesPerSecond:)])
                self.preferredFramesPerSecond = 0;
            return;
        }
    } @catch(...) {}
    %orig;
}
- (void)addToRunLoop:(NSRunLoop *)runloop forMode:(NSRunLoopMode)mode {
    ADApplyPromotion610(self);
    %orig;
}
%end

// Reconfigure links immediately when the preference changes. Before forcing a
// link we snapshot its original public range/FPS/interval and its display's private
// minimum-frame-duration policy. OFF restores those exact values; ON reapplies the
// proven v6.0.10 force. No guessed "stock" frame rate is written.
static void ADRefreshPromotionState611(void){
    NSArray *links = ADTrackedDisplayLinks611();
    BOOL on = ADPromotionPreferenceOn611();
    for (CADisplayLink *d in links){
        if (!d) continue;
        @try {
            if (on){ ADApplyPromotion610(d); continue; }
            ADRestorePromotionState611(d);
        } @catch(...) {}
    }
}

// ── one-shot 120 Hz verification ──────────────────────────────────────────────

// -----------------------------------------------------------------------------
// Live settings: visual switches update without adding any interaction-time scan.
// JIT remains launch-time. The Settings bundle still says respring to take effect.
// -----------------------------------------------------------------------------
static void ADPrefsChanged206(CFNotificationCenterRef c,void *o,CFStringRef n,const void *obj,CFDictionaryRef ui){
    dispatch_async(dispatch_get_main_queue(),^{
        BOOL old120=gP.enabled&&gP.force120Hz; ADLoadPrefs(); BOOL new120=gP.enabled&&gP.force120Hz;
        if(old120!=new120)ADRefreshPromotionState611();
        @try { for(UIScene *sc in UIApplication.sharedApplication.connectedScenes)if([sc isKindOfClass:[UIWindowScene class]])for(UIWindow *w in ((UIWindowScene*)sc).windows)ADApplyRootInvert206(w); } @catch(...) {}
        ADScheduleBarCorrection();
    });
}

%ctor {
    if(strcmp(__progname,"Amazon")!=0)return;
    ADLoadPrefs();
    %init;
    ADApplyJIT622();
    dispatch_async(dispatch_get_main_queue(),^{
        @try { for(UIScene *sc in UIApplication.sharedApplication.connectedScenes)if([sc isKindOfClass:[UIWindowScene class]])for(UIWindow *w in ((UIWindowScene*)sc).windows)ADApplyRootInvert206(w); } @catch(...) {}
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.45*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ADPostReady206();});
    });
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,ADPrefsChanged206,CFSTR("com.colindavidr.amazondark/prefs-changed"),NULL,CFNotificationSuspensionBehaviorCoalesce);
}

#pragma clang diagnostic pop
