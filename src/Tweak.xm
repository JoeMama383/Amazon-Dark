/*
 * AmazonDark v4.0.0  —  "True Dark" rewrite
 * ============================================================================
 * Target: Amazon Shopping iOS app (com.amazon.Amazon), v27.x, NathanLR rootless,
 *         arm64 / arm64e. iOS 15+.
 *
 * WHY THIS IS A REWRITE (and not another v3.x inversion tweak)
 * ----------------------------------------------------------------------------
 * v3.x forced a `colorInvert` CAFilter onto the top-level UIWindow layer and then
 * tried to *counter-invert* every image layer back to normal. That fight is
 * inherently racy: the window inverts synchronously, but per-image counter-filters
 * only land on layout, so photos flash (and often stay) as negatives. That is the
 * root cause of "everything is dark but the images are inverted."
 *
 * A real dark mode never inverts a photo in the first place. That is what NOIR /
 * Dark Reader do on the web, and it is the behavior we want. So v4 stops inverting
 * and instead darkens each surface with a method appropriate to that surface:
 *
 *   1. WEB VIEWS  (Home gateway, Cart, PDP, Search, most "content"):  Dark Reader.
 *      We bundle the official Dark Reader engine (MIT, resources/darkreader.js) and
 *      call DarkReader.enable(theme). Dark Reader analyses each element's real
 *      colors and generates a genuine dark theme. It deliberately LEAVES <img>,
 *      <picture>, <video>, <canvas> and background images ALONE. This is the fix
 *      for inverted images, and it is the surface the user confirmed works perfectly
 *      via the NOIR Safari extension.
 *
 *   2. NATIVE CHROME  (tab bar, nav/search bar, SwiftUI/UIKit surfaces):  the app's
 *      OWN native dark theme. Confirmed in the 27.11.8 binary: a complete native
 *      dark theme (ANXDarkModeServiceImpl, dark ConfigurableChromeSkins, dark
 *      tab-bar tokens) gated behind ONE Weblab, NAVX_DARK_MODE_IOS_1283655
 *      (default-treatment "C" = off). We flip that gate on client-side + set the
 *      appearance preference to dark + make the trait-observer report dark, then
 *      fire ANXAppearanceModeDidChangeNotification. Amazon then renders its own
 *      designed dark chrome — correct icons, correct accent colors, no inversion.
 *
 *   3. NATIVE NON-WEB CONTENT that stays light because it is server-driven and the
 *      server withholds dark color tokens for accounts outside the dark cohort:
 *      an OPTIONAL, preference-gated, background-only darkening pass that recolors
 *      solid light backgrounds toward the configured dark background and NEVER
 *      touches image/glyph layers. Off by default (see AD_PREF_NATIVE_FALLBACK).
 *
 * Everything is controlled by a preference plist (see prefs/ subproject), so this
 * is a true dark mode with color settings, like CarBridge / OneSettings, not a
 * one-size invert.
 *
 * NATHANLR SAFETY (carried over verbatim from the CarBridgeReborn sessions)
 * ----------------------------------------------------------------------------
 *  - ZERO Obj-C in %ctor: no NSLog/os_log, no @"" literals at ctor scope. The ObjC
 *    runtime is not guaranteed ready when the dylib loads on NathanLR; touching it
 *    there SIGBUS/SIGABRTs. %ctor uses only raw write() syscalls + a process guard.
 *  - All Obj-C work is deferred onto the main queue / dispatch_after sweeps.
 *  - File logging to $TMPDIR (sandbox-writable; /var/mobile is NOT writable from a
 *    sandboxed app — that mistake cost a whole session last time).
 *  - Every hook body is wrapped in @try/@catch so an unexpected shape is absorbed.
 *  - No auto-killall in postinst (respring races with Ellekit/dpkg triggers).
 * ============================================================================
 */

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <string.h>
#import <notify.h>
#import <stdio.h>
#import <unistd.h>
#import <fcntl.h>
#import <dlfcn.h>
// Keep in lockstep with layout/DEBIAN/control. The init log is the only way to
// confirm which build is live on device.
#define AD_VERSION "v6.0.7"

#import "ADColor.h"
#import "ADImageKey.h"

extern char *__progname;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wobjc-method-access"

// ─── the Weblab that gates Amazon's native dark theme (confirmed in binary) ─────────
#define AD_DARK_WEBLAB      "NAVX_DARK_MODE_IOS_1283655"
#define AD_DARK_TREATMENT   "T1"   // change to T2/T3 if a future build gates on another

// Preference domain (matches prefs subproject + postinst).
#define AD_PREF_DOMAIN      "com.colindavidr.amazondark"

// ════════════════════════════════════════════════════════════════════════════════
// Class forward-decls. We declare unknown Amazon classes as UIView/NSObject so the
// compiler resolves selectors; Logos/%hook only installs on classes that exist at
// runtime, so declaring one that is absent in some build is harmless.
// ════════════════════════════════════════════════════════════════════════════════
@interface ANXDarkModeServiceImpl : NSObject
- (BOOL)isDarkModeExperienceEnabled;
- (BOOL)isDarkModeExperienceActive;
- (BOOL)systemDarkModeActive;
@end

@interface AXUSplashScreenViewController : UIViewController @end
@interface TezBaseSplashScreenViewController : UIViewController @end

// ─────────────────────────────────────────────────────────────────────────────────
// Logging is compiled out in v6.0.4 performance mode.
#define ADOpenLog() ((void)0)
#define ADRaw(...)  ((void)0)
#define ADLog(...)  ((void)0)

// ════════════════════════════════════════════════════════════════════════════════
// PREFERENCES
// Read straight from the plist the settings bundle writes. We avoid a hard Cephei
// dependency (keeps the tweak self-contained); NSUserDefaults(suiteName:) reads the
// same file HBPreferences/Cephei write to under rootless.
// ════════════════════════════════════════════════════════════════════════════════
typedef struct {
    BOOL  enabled;            // master on/off
    BOOL  webDarkReader;      // use Dark Reader in web views
    BOOL  nativeTheme;        // force Amazon's native dark theme (weblab)
    BOOL  imageKeyBackground; // corner-key white studio backdrops in photos (opt-in)
    BOOL  imageBackdrop;      // dark panel behind images (helps transparent ones)
    BOOL  nativeRecolor;      // Dark Reader colour engine over native (non-web) content
    BOOL  whiteTame;          // v5.446: tame blown-out studio backgrounds
    BOOL  force120Hz;         // v5.446: request ProMotion maximum
    long  whiteTameStrength;  // v5.446: 0-100 tame strength
    long  brightness;         // Dark Reader 0..100+ (default 100)
    long  contrast;           // Dark Reader 0..100+ (default 100)
    long  sepia;              // Dark Reader 0..100  (default 0)
    long  grayscale;          // Dark Reader 0..100  (default 0)
    char  bgHex[8];           // dark scheme background, "#RRGGBB"
    char  fgHex[8];           // dark scheme text,       "#RRGGBB"
} ADPrefs;

static ADPrefs gP;
static void ADSyncColorEngine(void);
static const void *kADModImageKey = &kADModImageKey;
static inline BOOL ADIsModifiedImage(UIImage *im){ return im && objc_getAssociatedObject(im, kADModImageKey) != nil; }
static inline void ADMarkModifiedImage(UIImage *im){ if (im) objc_setAssociatedObject(im, kADModImageKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static UIColor *ADColorFromHex(const char *hex);
static UIImage *ADGlyphify(UIImage *img);
static void ADApplyNativeWhiteTameView(UIView *v);
static void ADPrimeNativeWhiteTame363(UIView *v, UIImage *incoming);
static void ADSubscribeOverlay394(UIView *v);
static BOOL ADImageMostlyLight(UIImage *img);
static BOOL ADIsCategoryArtwork379(UIView *v);
static void ADRestoreCategoryArtwork379(UIImageView *iv);
static BOOL ADIsHamburgerSurface380(UIView *v);
static int ADMenuRole382(UIView *v);
static BOOL ADWTInWatchedCarousel380(UIView *v);
static inline double ADUptime(void);
static void ADPostAppReady(void);
static void ADPreDarken(WKWebView *wv);

static long ADPrefLong(NSDictionary *d, NSString *k, long def){
    id v = d[k]; return (v && [v respondsToSelector:@selector(longValue)]) ? [v longValue] : def;
}
static BOOL ADPrefBool(NSDictionary *d, NSString *k, BOOL def){
    id v = d[k]; return (v && [v respondsToSelector:@selector(boolValue)]) ? [v boolValue] : def;
}
static void ADPrefHex(NSDictionary *d, NSString *k, const char *def, char *out){
    id v = d[k];
    NSString *s = ([v isKindOfClass:[NSString class]] && [v length] >= 4) ? v : @(def);
    strncpy(out, s.UTF8String, 7); out[7] = 0;
}

static void ADLoadPrefs(void){
    // Defaults: everything a "true dark mode" wants, image inversion OFF.
    gP.enabled = YES; gP.webDarkReader = YES; gP.nativeTheme = YES;
    gP.imageBackdrop = YES;
    gP.whiteTame = NO;
    gP.force120Hz = NO;
    gP.whiteTameStrength = 45;
    gP.imageKeyBackground = NO;
    gP.nativeRecolor = YES;
    gP.brightness = 100; gP.contrast = 100; gP.sepia = 0; gP.grayscale = 0;
    strcpy(gP.bgHex, "#181a1b"); strcpy(gP.fgHex, "#e8e6e3");
    @try {
        NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:@(AD_PREF_DOMAIN)];
        NSDictionary *d = [u dictionaryRepresentation] ?: @{};
        // v5.446 preference path handling: Settings/cfprefsd can write either the
        // real mobile preferences path or the rootless mirror. Merge every known path.
        NSMutableArray *paths = [NSMutableArray arrayWithObjects:
            [NSString stringWithFormat:@"/var/jb/var/mobile/Library/Preferences/%s.plist", AD_PREF_DOMAIN],
            [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%s.plist", AD_PREF_DOMAIN], nil];
        @try {
            Dl_info pi;
            if (dladdr((const void *)&ADLoadPrefs, &pi) && pi.dli_fname){
                NSString *img=[NSString stringWithUTF8String:pi.dli_fname];
                NSRange jb=[img rangeOfString:@"/jb/"];
                if(jb.location!=NSNotFound){
                    NSString *root=[img substringToIndex:jb.location+jb.length-1];
                    [paths addObject:[NSString stringWithFormat:@"%@/var/mobile/Library/Preferences/%s.plist",root,AD_PREF_DOMAIN]];
                }
            }
        } @catch(...) {}
        for (NSString *pp in paths){
            NSDictionary *fromFile=[NSDictionary dictionaryWithContentsOfFile:pp];
            if(fromFile.count){NSMutableDictionary *m=[d mutableCopy];[m addEntriesFromDictionary:fromFile];d=m;}
        }

        gP.enabled            = ADPrefBool(d, @"enabled",            gP.enabled);
        gP.webDarkReader      = ADPrefBool(d, @"webDarkReader",      gP.webDarkReader);
        gP.nativeTheme        = ADPrefBool(d, @"nativeTheme",        gP.nativeTheme);
        gP.imageBackdrop      = ADPrefBool(d, @"imageBackdrop",      gP.imageBackdrop);
        gP.whiteTame          = ADPrefBool(d, @"whiteTame",          gP.whiteTame);
        gP.force120Hz         = ADPrefBool(d, @"force120Hz",         gP.force120Hz);
        gP.whiteTameStrength  = ADPrefLong(d, @"whiteTameStrength",  gP.whiteTameStrength);
        gP.imageKeyBackground = ADPrefBool(d, @"imageKeyBackground", gP.imageKeyBackground);
        gP.nativeRecolor      = ADPrefBool(d, @"nativeRecolor",      gP.nativeRecolor);
        gP.brightness         = ADPrefLong(d, @"brightness",         gP.brightness);
        gP.contrast           = ADPrefLong(d, @"contrast",           gP.contrast);
        gP.sepia              = ADPrefLong(d, @"sepia",              gP.sepia);
        gP.grayscale          = ADPrefLong(d, @"grayscale",          gP.grayscale);
        ADPrefHex(d, @"bgHex", "#181a1b", gP.bgHex);
        ADPrefHex(d, @"fgHex", "#e8e6e3", gP.fgHex);
    } @catch(...) {}
    ADSyncColorEngine();
    ADLog(@"prefs: enabled=%d web=%d nativeTheme=%d nativeRecolor=%d tame=%d tameStrength=%ld force120=%d bright=%ld contrast=%ld gray=%ld sepia=%ld bg=%s fg=%s",
          gP.enabled, gP.webDarkReader, gP.nativeTheme, gP.nativeRecolor,
          gP.whiteTame, gP.whiteTameStrength, gP.force120Hz,
          gP.brightness, gP.contrast, gP.grayscale, gP.sepia, gP.bgHex, gP.fgHex);
}

// ════════════════════════════════════════════════════════════════════════════════
// SURFACE 1 — WEB VIEWS via bundled Dark Reader
// ════════════════════════════════════════════════════════════════════════════════

// Locate our bundled darkreader.js next to the dylib (rootless-safe: use dladdr to
// find our own install dir, then read the sibling resource).
static NSString *ADBundledDarkReaderJS(void){
    static NSString *cached = nil;
    static BOOL tried = NO;
    if (tried) return cached;
    tried = YES;
    @try {
        Dl_info info; static int anchor;
        if (dladdr((const void *)&anchor, &info) && info.dli_fname){
            NSString *dylib = @(info.dli_fname);
            NSString *dir = [dylib stringByDeletingLastPathComponent];
            // Theos installs BUNDLE resources to .../AmazonDark.bundle next to the dylib.
            NSArray *cands = @[
                [dir stringByAppendingPathComponent:@"AmazonDark.bundle/darkreader.js"],
                [dir stringByAppendingPathComponent:@"darkreader.js"],
                @"/var/jb/Library/Application Support/AmazonDark/darkreader.js",
            ];
            for (NSString *c in cands){
                NSString *s = [NSString stringWithContentsOfFile:c encoding:NSUTF8StringEncoding error:nil];
                if (s.length){
                    cached = s;
                    ADLog(@"darkreader.js loaded (%lu bytes) from %@", (unsigned long)s.length, c);
                    break;
                }
                ADLog(@"darkreader.js NOT at %@", c);
            }
            if (!cached.length)
                ADLog(@"FATAL: darkreader.js missing — web surfaces will stay LIGHT. "
                       "Check the package installed it under Application Support/AmazonDark.");
        }
    } @catch(...) {}
    return cached;
}

// The theme literal, built from live prefs (shared by both the heavy bootstrap and
// the lightweight re-enable call).
// THE HOME-TAB VEIL, root-caused by the DOM probe:
//   IMG{filter=none, op=1, blend=multiply, bg=rgba(0,0,0,0)}
// Amazon sets mix-blend-mode:multiply on product images. Multiply is a no-op against
// white (x * 1 = x), so on Amazon's stock light page the images look untouched — but
// multiply against a DARK backdrop multiplies every pixel by that dark colour, so the
// photo is literally blended into the background. That is the "semi-transparent black
// overlay" over the products, and it explains why filter and opacity resets did
// nothing: neither was ever involved. Forcing mix-blend-mode:normal restores the
// images exactly. isolation:auto stops a parent stacking context re-introducing it.
//
// Fixes object passed as enable()'s 2nd argument. ignoreImageAnalysis:['*'] stops
// Dark Reader hiding / inverting / solid-filling images — the home-tab product veil.
// This is the web-side half of the project's core promise: never touch imagery.
//
// The css field is injected by Dark Reader as an authoritative override sheet
// (overrideStyle.textContent in dynamic-theme/index.ts), so it wins the cascade.
// We use it to undo the OTHER way Dark Reader can veil a photo: it runs
// modifyGradientColor() on every CSS gradient stop (a path entirely separate from
// image analysis), so a white→transparent scrim gradient laid over a hero image
// gets its stops darkened into a grey/black film. The rules below force any element
// that layers a gradient ON TOP of a background image to drop the gradient, and
// neutralise standalone overlay layers, without touching gradients used as real
// button or chip fills.
static NSString *ADFixesLiteral(void){
    // The image backdrop is only meaningful where an image has TRANSPARENT pixels:
    // a dark panel behind an opaque JPEG is completely hidden by the photo. So this
    // helps transparent PNGs (icons, cut-out product shots) and is a harmless no-op
    // everywhere else. It cannot darken white that is baked into a JPEG's pixels -
    // that needs real pixel work, which is a separate decision.
    NSString *imgBackdrop = gP.imageBackdrop
        ? [NSString stringWithFormat:@"img{background-color:%s !important;}", gP.bgHex]
        : @"";
    return [NSString stringWithFormat:
            @"{css:'"
             "img,picture,video,canvas,svg{filter:none !important;opacity:1 !important;"
             "mix-blend-mode:normal !important;isolation:auto !important;}"
             "%@"
             "[style*=\\\"background-image\\\"]{filter:none !important;}"
             // THE FIX THAT ACTUALLY WORKED, brought back. v5.27.0 whitened the heart
             // with a documentStart CSS rule and it visibly worked; v5.28.0 removed it
             // because [class*=heart-position] dragged the 32px disc into the whitening
             // (the white blob). Every JS attempt since lost a timing race that
             // document-start CSS avoids.
             // v5.435: retired Shopping Compare presentation removed. These old
             // copilot/aria/content-id selectors forced every descendant through a
             // white silhouette with greater specificity than the stock-state owner.
             // On dark Shopping rows that produced the solid white square and also
             // overrode filter:none after Amazon selected its blue/checkmark sprite.
             // Cart never used this DOM family and stays byte-locked in v5.434.
             "[class*=puis-heart-position]"
             "{background-color:transparent !important;border:0 !important;"
             "box-shadow:none !important;}"
             // v5.393: SEARCH/PDP HEART FIRST-PAINT GUARD. Amazon temporarily mounts
             // a white structural shell before the actual Heart painter hydrates. Clear
             // only background COLOR on the tiny Heart subtree at documentStart; never
             // move/resize it and never remove a real background-image/mask. The runtime
             // below restores white on a real mask/pseudo glyph after positive detection.
             "[class*=puis-heart-position] button,[class*=puis-heart-position] [role=button],"
             "[class*=puis-heart-position] a,[class*=puis-heart-position] span,[class*=puis-heart-position] div"
             "{background-color:transparent !important;}"
             "[class*=puis-heart-position] button::before,[class*=puis-heart-position] button::after,"
             "[class*=puis-heart-position] [role=button]::before,[class*=puis-heart-position] [role=button]::after,"
             "[class*=puis-heart-position] a::before,[class*=puis-heart-position] a::after,"
             "[class*=puis-heart-position] span::before,[class*=puis-heart-position] span::after,"
             "[class*=puis-heart-position] div::before,[class*=puis-heart-position] div::after"
             "{background-color:transparent !important;}"
             // PDP LISTS HEART. Device probe on v5.345 names the actual painter:
             // 24x24 lists-treatment shells -> 20x20 .a-icon with background-image.
             // Filter ONLY that paint leaf; touching the parent recreates the old
             // v5.27 white-blob regression.
             "[class*=lists-treatment-hear] .a-icon"
             "{filter:brightness(0) invert(1) !important;"
             "background-color:transparent !important;}"
             // v5.424: colour ONLY -- no radius/size/border, so this rule can
             // never turn a container into an oval. Restores the cards glyph
             // whitening that v5.423 removed along with the shape rules.
             "[class*=mlt-icon-container] img[class*=s-image],"
             "[class*=mlt-image-icon] img[class*=s-image]"
             "{filter:brightness(0) invert(1) !important;background-color:transparent !important;}"
             // v5.374: search templates can temporarily expose a 1x1/lazy
             // placeholder in this action control. Inverting that shim creates the
             // solid white square. Hide known shims at documentStart; runtime below
             // restores a real glyph or supplies the same cards+ fallback.
             "[class*=lists-framework-action-button] img[src*=grey-pixel],"
             "[class*=lists-framework-action-button] img[src*=gray-pixel],"
             "[class*=lists-framework-action-button] img[src*=transparent-pixel],"
             "[class*=lists-framework-action-button] img[src*=placeholder],"
             "[class*=lists-framework-action-button] img[src*=spacer],"
             "[class*=lists-framework-action-button] img[class*=placehold],"
             "[class*=lists-framework-action-button] [class*=placeholder]"
             "{display:none !important;filter:none !important;opacity:0 !important;}"
             "[data-ad-actionfallback374]{width:22px !important;height:22px !important;"
             "display:block !important;opacity:1 !important;filter:none !important;"
             "background:transparent !important;pointer-events:none !important;}"
             "[data-ad-actionfallback374] rect,[data-ad-actionfallback374] path"
             "{fill:none !important;stroke:#ffffff !important;stroke-width:1.8 !important;}"
             "[data-ad-actionglyph374]{opacity:1 !important;background-color:transparent !important;}"
             "[class*=lists-framework-action-button] img[data-ad-actionglyph374]"
             "{display:inline-block !important;opacity:1 !important;}"
             "[class*=lists-framework-action-button] img,"
             "[class*=lists-framework-action-button] i,"
             "[class*=lists-framework-action-button] svg,"
             "[class*=lists-framework-unfill],[class*=lists-framework-fill]"
             "{filter:brightness(0) invert(1) !important;"
             "background-color:transparent !important;}"
             "[class*=puis-heart-position] [class*=placehold],[class*=heart-placeholder],"
             "[class*=puis-heart-position] img[src*=grey-pixel],[class*=puis-heart-position] img[src*=gray-pixel],"
             "[class*=puis-heart-position] img[src*=transparent-pixel],[class*=puis-heart-position] img[src*=placeholder],"
             "[class*=puis-heart-position] img[src*=spacer],[class*=puis-heart-position] img[src*=blank],"
             "[class*=puis-heart-position] img[class*=placehold]"
             "{display:none !important;filter:none !important;opacity:0 !important;}"
             // Darkening blends crush their content toward black on a dark theme; the
             // deal badges use them inline. Neutralise at documentStart so the text is
             // legible on first paint instead of after the repair catches up.
             "[style*=multiply],[style*=darken],[style*=color-burn],"
             "[class*=deal] [style*=blend],[class*=Deal] [style*=blend]"
             "{mix-blend-mode:normal !important;isolation:auto !important;}"
             "',invert:[],ignoreInlineStyle:[],ignoreImageAnalysis:['*'],disableStyleSheetsProxy:false}",
            imgBackdrop];
}

static NSString *ADThemeLiteral(void){
    // mode:1 = dark. styleSystemControls themes form controls/scrollbars.
    // The fixed/sticky headers Amazon uses respond better with these on.
    return [NSString stringWithFormat:
        @"{mode:1,brightness:%ld,contrast:%ld,sepia:%ld,grayscale:%ld,"
         "darkSchemeBackgroundColor:'%s',darkSchemeTextColor:'%s',"
         "styleSystemControls:true}",
        gP.brightness, gP.contrast, gP.sepia, gP.grayscale, gP.bgHex, gP.fgHex];
}

// HEAVY: full Dark Reader UMD + first enable(). Injected ONCE per document at
// documentStart via a WKUserScript. The 346KB engine is parsed a single time per page.
static NSString *ADDarkReaderBootstrap(void){
    NSString *dr = ADBundledDarkReaderJS();
    if (!dr.length) return nil;
    return [NSString stringWithFormat:
        @"(function(){try{"
         "if(window.__AMZDARK_LOADED__)return;window.__AMZDARK_LOADED__=1;%@\n" // DarkReader UMD
         "if(window.DarkReader&&DarkReader.enable){"
         "try{DarkReader.setFetchMethod(window.fetch);}catch(e){}"
         // WCAG contrast repair. Dark Reader recolours from the page's own palette,
         // which can leave text only marginally separated from its background - the
         // '% off' badges and the descriptions under product photos being the
         // reported cases. This measures the real computed contrast of every element
         // that owns visible text and lifts ONLY the ones that actually fail, so
         // brand colours that already read fine are untouched.
         "window.__AMZDARK_FIXCONTRAST__=function(){try{"
           "var FG='%@';"
           "function ch(v){v=v/255;return v<=0.03928?v/12.92:Math.pow((v+0.055)/1.055,2.4);}"
           "function lum(c){var m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([\\d.]+))?\\)/.exec(c);"
             "if(!m)return null;var a=m[4]===undefined?1:parseFloat(m[4]);if(a<0.1)return null;"
             "return 0.2126*ch(+m[1])+0.7152*ch(+m[2])+0.0722*ch(+m[3]);}"
           "function bgOf(e){while(e){var l=lum(getComputedStyle(e).backgroundColor);"
             "if(l!==null)return l;e=e.parentElement;}return 0.02;}"
           // Darkening blend modes are destructive on a dark theme: multiply/darken/
           // color-burn all SUBTRACT light, so against a dark backdrop they crush the
           // element toward black. That is what veiled the home tiles (fixed in v5.8.0
           // via CSS on media elements) and it is back on the explore pane because
           // there the blend mode sits on a CONTAINER, not the <img> - resetting the
           // child cannot undo a parent's blending of the whole composited subtree.
           // Neutralising by COMPUTED value catches it wherever it lives: img, div,
           // background-image element or wrapper. Lighten/screen/overlay are left
           // alone - they add light, which is harmless here.
           "var BAD={'multiply':1,'darken':1,'color-burn':1};"
           "function collect(root,out,depth){try{"
             "var list=root.querySelectorAll('*');"
             "for(var a=0;a<list.length;a++){var e=list[a];out.push(e);"
               // Shadow roots are separate trees: querySelectorAll stops at the host,
               // so anything Amazon builds inside one is unreachable from the document.
               "if(e.shadowRoot&&depth<4&&out.length<6000)collect(e.shadowRoot,out,depth+1);}"
             "}catch(e){}return out;}"
           "var els=collect(document.body,[],0),n=0,bfix=0,lfix=0,gfix=0;"           // Read the themed background off <html> rather than plumbing another
           // format argument through two call sites.
           "var BG='rgb(24,26,27)';try{var hb=getComputedStyle(document.documentElement).backgroundColor;"
             "var hl=lum(hb);if(hl!==null&&hl<0.25)BG=hb;}catch(e){}"
           "var SKIP=/star|prime|logo|flag|swatch|thumb|sponsor|pill-image|product-image|photo|heart|wish|lists-framework/i;"           // Classes the probe confirmed are monochrome UI glyphs. These get a
           // looser size cap, because the heart measures 33x33 against a 32 limit and
           // was failing by a single pixel, while sbs-pill-image at 34x34 is a product
           // thumbnail that must keep its colour.
           "var ICON=/heart|wish|favor|lists-framework|a-icon|icon-|-icon|^_[a-z0-9]{4,8}_/i;"           // collect() walks document.body's DESCENDANTS, so <html> and <body>
           // themselves are never in els. A page that paints its own light background
           // on body -- Amazon Pharmacy's pink -- is invisible to every per-element
           // rule, and its inline/high-specificity value also overrides Dark Reader's
           // sheet. Darken them explicitly. Both solid and gradient forms.
           "try{var roots=[document.documentElement,document.body];"
             "for(var ri=0;ri<roots.length;ri++){var be=roots[ri];if(!be)continue;"
               "var bcs=getComputedStyle(be),bbl=lum(bcs.backgroundColor);"
               "if(bbl!==null&&bbl>0.4){be.style.setProperty('background-color',BG,'important');lfix++;}"
               "var bbi=bcs.backgroundImage||'';"
               "if(bbi.indexOf('gradient')>=0){var bmx=0,bm,bre=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/g;"
                 "while((bm=bre.exec(bbi))){var bl2=0.2126*ch(+bm[1])+0.7152*ch(+bm[2])+0.0722*ch(+bm[3]);"
                   "if(bl2>bmx)bmx=bl2;}"
                 "if(bmx>0.4){be.style.setProperty('background-image','none','important');"
                   "be.style.setProperty('background-color',BG,'important');lfix++;}}}"
           "}catch(e){}"
           "for(var i=0;i<els.length;i++){var el=els[i];"
             "var cs=getComputedStyle(el);"
             // NO LIGHT PANELS. Anything still measuring light after Dark Reader has
             // run is a miss -- a gradient it could not parse, a shadow subtree, an
             // inline style it skipped. Correct by COMPUTED value so the mechanism
             // does not matter. els is in document order, so an ancestor is darkened
             // before its children are contrast-checked against it.
             "if(lfix<300){var pl=lum(cs.backgroundColor);"
               "if(pl!==null&&pl>0.55){el.style.setProperty('background-color',BG,'important');lfix++;}}"
             // LIGHT GRADIENTS. lfix read 0 on every line while a 430x627 light panel
             // sat on screen, because a gradient lives in background-IMAGE and is
             // invisible to a backgroundColor check. The probe named it:
             // div.wd-backdrop-gradient, the 'Researched by Alexa' card. Parse the
             // stops and only neutralise gradients that actually resolve light, so
             // decorative dark gradients are left alone.
             "if(lfix<300){var gbi=cs.backgroundImage||'';"
               "if(gbi.indexOf('gradient')>=0){var g2=el.getBoundingClientRect();"
                 "if(g2.width>120&&g2.height>60){var gmx=0,gm,gre=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/g;"
                   "while((gm=gre.exec(gbi))){var gl2=0.2126*ch(+gm[1])+0.7152*ch(+gm[2])+0.0722*ch(+gm[3]);"
                     "if(gl2>gmx)gmx=gl2;}"
                   "if(gmx>0.55){el.style.setProperty('background-image','none','important');"
                     "el.style.setProperty('background-color',BG,'important');lfix++;}}}}"
             // SPRITE AND <img> GLYPHS -- the heart and the filter control.
             // ignoreImageAnalysis:['*'] switches off Dark Reader's dark-image
             // inversion (added in v5.4.0 to protect product photos) and the injected
             // img{filter:none} rule blocks it a second time, so a monochrome icon
             // shipped as an <img> or CSS sprite has nothing acting on it at all.
             // Forcing it white is safe at glyph size and beats measuring pixels,
             // which cannot work here: these come from m.media-amazon.com and would
             // taint a canvas. Inline !important outranks stylesheet !important, so
             // this wins over our own img{filter:none}.
             "if(gfix<160&&!el.__adGlyph){try{var gr=el.getBoundingClientRect();"
               "var cn2=el.className;if(cn2&&cn2.baseVal!==undefined)cn2=cn2.baseVal;"
               "cn2=(cn2||'').toString();"
               // textContent was the wrong test. Amazon's standard icon markup nests a
               // visually-hidden label -- <span class=a-icon><span class=a-icon-alt>Add
               // to list</span></span> -- so textContent is non-empty and the guard
               // rejected precisely the markup being targeted. That is why the filter
               // control (no nested label) went white and the heart did not. Only the
               // element's OWN direct text nodes should disqualify it.
               "var ot=false;for(var z=0;z<el.childNodes.length;z++){var nz=el.childNodes[z];"
                 "if(nz.nodeType===3&&nz.nodeValue&&nz.nodeValue.trim()){ot=true;break;}}"
               "var lim=ICON.test(cn2)?40:36;"
               "if(gr.width>5&&gr.width<=lim&&gr.height>5&&gr.height<=lim&&!SKIP.test(cn2)&&!ot){"
                 "var isI=el.tagName.toLowerCase()==='img';"
                 "var hasB=cs.backgroundImage&&cs.backgroundImage!=='none';"
                 "if(isI||hasB){el.style.setProperty('filter','brightness(0) invert(1)','important');"
                   "el.__adGlyph=1;gfix++;}}"
             "}catch(e){}}"
             "if(BAD[cs.mixBlendMode]&&bfix<800){"
               "el.style.setProperty('mix-blend-mode','normal','important');"
               "el.style.setProperty('isolation','auto','important');bfix++;}"
             // SVG icons. Dark Reader recolours CSS 'color'; it does not touch the
             // fill/stroke PRESENTATION ATTRIBUTES that line-art icons use, so an
             // <svg fill="#000"> stays black on a themed page. Measured on device:
             // the X and recent-search glyphs sit at rgb(12,13,14) - actually darker
             // than the rgb(24,26,27) background - while text on the same page themed
             // correctly. Only dark fills are redirected, so multi-colour artwork and
             // brand marks keep their palette.
             "if(el.namespaceURI==='http://www.w3.org/2000/svg'){"
               "if(el.tagName.toLowerCase()==='svg'&&gfix<160&&!el.__adGlyph){"
                 "try{var sr3=el.getBoundingClientRect();"
                   "var sc3=el.className;if(sc3&&sc3.baseVal!==undefined)sc3=sc3.baseVal;sc3=(sc3||'').toString();"
                   "var slim=ICON.test(sc3)?44:40;"
                   "var SK2=/star|prime|logo|flag|swatch|thumb|sponsor|pill-image|product-image|photo/i;"
                   "if(sr3.width>5&&sr3.width<=slim&&sr3.height>5&&sr3.height<=slim&&!SK2.test(sc3)){"
                     "el.style.setProperty('filter','brightness(0) invert(1)','important');el.__adGlyph=1;gfix++;}"
                 "}catch(e){}}"
               "var fl2=lum(cs.fill),sl=lum(cs.stroke);"
               "if(fl2!==null&&fl2<0.22){el.style.setProperty('fill',FG,'important');n++;}"
               "if(sl!==null&&sl<0.22){el.style.setProperty('stroke',FG,'important');n++;}"
             "}"
             // ICON FONTS / PSEUDO-ELEMENT GLYPHS. The text pass below requires a
             // literal child text node, and a ::before glyph has none - the character
             // lives in generated content. So an icon font renders in the element's
             // own dark `color` and nothing above ever looks at it. This is the single
             // most likely reason autocomplete reports 0/0 while its clock and X
             // glyphs sit there black.
             "function hasC(p){if(!p)return false;var c=p.content;"
               "if(!c||c==='none'||c==='normal')return false;return c.length>2;}"
             "try{var pb=getComputedStyle(el,'::before'),pa=getComputedStyle(el,'::after');"
               "if((hasC(pb)||hasC(pa))&&n<400){var pcl=lum(cs.color);"
                 "if(pcl!==null&&pcl<0.50){el.style.setProperty('color',FG,'important');n++;}}"
             "}catch(e){}"
             // MASK-IMAGE ICONS. The mask is the shape; the visible colour is the
             // element's background-color. Dark Reader treats that as a background and
             // darkens it, which paints the glyph in the page background colour - i.e.
             // makes it vanish rather than merely stay dark.
             "try{var mi=cs.webkitMaskImage||cs.maskImage;"
               "if(mi&&mi!=='none'&&n<400){var mbl=lum(cs.backgroundColor);"
                 "if(mbl!==null&&mbl<0.55){el.style.setProperty('background-color',FG,'important');n++;}}"
             "}catch(e){}"
             "try{if(n<400){var g3=el.getBoundingClientRect();"
               "if(g3.width>5&&g3.width<=40&&g3.height>5&&g3.height<=40){"
                 "var bw2=parseFloat(cs.borderTopWidth)||parseFloat(cs.borderLeftWidth)||0;"
                 "if(bw2>=1.5){var bcl=lum(cs.borderTopColor||cs.borderLeftColor);"
                   "if(bcl!==null&&bcl<0.35){var ot2=false;"
                     "for(var z2=0;z2<el.childNodes.length;z2++){var nz2=el.childNodes[z2];"
                       "if(nz2.nodeType===3&&nz2.nodeValue&&nz2.nodeValue.trim()){ot2=true;break;}}"
                     "if(!ot2){el.style.setProperty('border-color',FG,'important');n++;}}}}}"
             "}catch(e){}"
             "if(n>=400)continue;"
             "var t=false;"
             "for(var k=0;k<el.childNodes.length;k++){var nd=el.childNodes[k];"
               "if(nd.nodeType===3&&nd.nodeValue&&nd.nodeValue.trim()){t=true;break;}}"
             "if(!t)continue;"
             "var fl=lum(cs.color);if(fl===null)continue;"
             "var bl=bgOf(el);var hi=Math.max(fl,bl)+0.05,lo=Math.min(fl,bl)+0.05;"
             "if(hi/lo<3.0){el.style.setProperty('color',FG,'important');n++;}}"
           // HEARTS. Two parts, kept separate so they cannot fight: darken the circle
           // (a light background on the element or a near ancestor) and lighten the
           // glyph by whatever actually draws it. Doing this by mechanism avoids the
           // whole-box whitening that hid the heart behind a white disc.
           "try{var HRT=document.querySelectorAll('[class*=heart],[class*=wish],[class*=lists-framework]');"
             "for(var hz=0;hz<HRT.length;hz++){var he=HRT[hz];var hcs=getComputedStyle(he);"
               // circle: darken this element's light bg, and the first light ancestor bg
               "var hcl2=he.className;if(hcl2&&hcl2.baseVal!==undefined)hcl2=hcl2.baseVal;hcl2=String(hcl2||'');"
               "if(/unfill|placehold|a-icon/i.test(hcl2)){he.style.setProperty('background-color','transparent','important');}"
               "else if(lum(hcs.backgroundColor)>0.5){he.style.setProperty('background-color',BG,'important');}"
               "var pe=he.parentElement,pd=0;"
               "while(pe&&pd++<3){var pl=lum(getComputedStyle(pe).backgroundColor);"
                 "if(pl!==null&&pl>0.5){pe.style.setProperty('background-color',BG,'important');break;}"
                 "pe=pe.parentElement;}"
               // glyph: img/bgimg is handled by the documentStart CSS silhouette
               // rule (the v5.27.0 approach that demonstrably worked) -- CSS survives
               // Amazon re-rendering the node, inline styles do not, which is where
               // every JS-era attempt actually died. Here: masks, then fill/color.
               "var hrc=he.getBoundingClientRect();"
               "var isGlyph=(hrc.width>0&&hrc.width<=28&&hrc.height>0&&hrc.height<=28);"
               "var hmi=hcs.webkitMaskImage||hcs.maskImage;"
               "if(hmi&&hmi!=='none'&&isGlyph){he.style.setProperty('background-color',FG,'important');}"
               "else if(hmi&&hmi!=='none'){he.style.setProperty('background-color',BG,'important');}"
               "else{var hf=lum(hcs.fill);if(hf!==null&&hf<0.35)he.style.setProperty('fill',FG,'important');"
                 "var hc2=lum(hcs.color);if(hc2!==null&&hc2<0.35)he.style.setProperty('color',FG,'important');}"
             "}}catch(e){}"
           "var pr=\'\';"
           "return n+'/'+bfix+'/'+lfix+'/'+gfix+pr;}catch(e){return -1;}};"
         "window.__AMZDARK_APPLY__=function(){try{"
           "if(!document.querySelector('style.darkreader'))DarkReader.enable(%@,%@);"
           "window.__AMZDARK_FIXCONTRAST__();"
         "}catch(e){}};"
         // Re-run the repair as the page fills in (carousels, lazy tiles), debounced
         // so a busy DOM cannot turn this into a hot loop.
         "try{var _t=null;new MutationObserver(function(){clearTimeout(_t);"
           "_t=setTimeout(function(){try{window.__AMZDARK_FIXCONTRAST__();}catch(e){}},150);})"
           ".observe(document.documentElement,{childList:true,subtree:true});}catch(e){}"
         "window.__AMZDARK_APPLY__();"
         // Re-apply when the page is restored from the back-forward cache (returning
         // to a tab). pageshow.persisted is true exactly in that case, and it is the
         // event that fires when no navigation happens — the cart's "went white on
         // return" path. Also re-assert on visibility regain.
         "try{window.addEventListener('pageshow',function(e){if(e.persisted)window.__AMZDARK_APPLY__();});}catch(e){}"
         "try{document.addEventListener('visibilitychange',function(){if(!document.hidden)window.__AMZDARK_APPLY__();});}catch(e){}"
         "}}catch(e){}})();",
        dr, [NSString stringWithUTF8String:gP.fgHex], ADThemeLiteral(), ADFixesLiteral()];
}


// ── v5.446 WEB WHITE-BACKGROUND TAME backport ───────────────────────────────
// The body below is copied from the exact v5.446 donor. It is kept separate from
// the v5.42 Dark Reader bootstrap so unrelated v5.43x/v5.44x UI fixes are not imported.
static NSString *ADWhiteTameWebJS446(void){
    if (!gP.enabled || !gP.whiteTame) return nil;
    return [NSString stringWithFormat:
        @"(function(){try{window.__ADTAME_ON__=1;window.__ADTAME_S__=%ld;"
         "if(window.__AD_TWB446_INSTALLED__){if(window._adTameFast362)window._adTameFast362(document.documentElement);return;}"
         "window.__AD_TWB446_INSTALLED__=1;"
         "function _adTameBands362(){try{var now=Date.now();if(window.__ADTB362__&&now-(window.__ADTB362T__||0)<1200)return window.__ADTB362__;"
           "var b={explore:-1,shopcat:-1,sub:-1,keep:-1,watched:-1,lists:-1,how:-1,questions:-1,medical:-1,highlights:-1,giftcard:-1,reviews:-1,help:-1,returns:-1,related:-1},root=document.body||document.documentElement,sy=window.scrollY||window.pageYOffset||0;"
           "if(root&&document.createTreeWalker){var W=document.createTreeWalker(root,NodeFilter.SHOW_TEXT),nd,n=0;while((nd=W.nextNode())&&n++<3600){var t=String(nd.nodeValue||'').replace(/\\s+/g,' ').trim().toLowerCase();if(t.length<4||t.length>90)continue;var e=nd.parentElement;if(!e||/^(SCRIPT|STYLE|NOSCRIPT)$/i.test(e.tagName))continue;var hit=0;"
             "if(t==='explore more for you'&&b.explore<0){hit=1;b.explore=0;}else if(t==='shop by category'&&b.shopcat<0){hit=2;b.shopcat=0;}"
             "else if((t==='subscribe & save'||t==='subscribe and save')&&b.sub<0){hit=3;b.sub=0;}else if(t.indexOf('keep shopping for')===0&&b.keep<0){hit=4;b.keep=0;}"
             "else if(t==='shop previously watched'&&b.watched<0){hit=5;b.watched=0;}else if(t.indexOf('lists and registries')===0&&b.lists<0){hit=6;b.lists=0;}"
             "else if((t==='how can i help?'||t==='how can i help')&&b.how<0){hit=7;b.how=0;}else if(t.indexOf('questions while you shop')===0&&b.questions<0){hit=8;b.questions=0;}"
             "else if(t==='medical care'&&b.medical<0){hit=15;b.medical=0;}else if(t==='your amazon highlights'&&b.highlights<0){hit=9;b.highlights=0;}else if(t.indexOf('gift card balance')===0&&b.giftcard<0){hit=10;b.giftcard=0;}"
             "else if(t==='your reviews'&&b.reviews<0){hit=11;b.reviews=0;}else if(t.indexOf('need help?')===0&&b.help<0){hit=12;b.help=0;}"
             "else if(t==='returns are easy'&&b.returns<0){hit=13;b.returns=0;}else if(t.indexOf('related products')===0&&b.related<0){hit=14;b.related=0;}if(!hit)continue;"
             "var r=e.getBoundingClientRect();if(r.width<8||r.height<4)continue;var y=r.top+sy+r.height/2;if(hit===1)b.explore=y;else if(hit===2)b.shopcat=y;else if(hit===3)b.sub=y;else if(hit===4)b.keep=y;else if(hit===5)b.watched=y;else if(hit===6)b.lists=y;else if(hit===7)b.how=y;else if(hit===8)b.questions=y;else if(hit===9)b.highlights=y;else if(hit===10)b.giftcard=y;else if(hit===11)b.reviews=y;else if(hit===12)b.help=y;else if(hit===13)b.returns=y;else if(hit===14)b.related=y;else if(hit===15)b.medical=y;}}"
           "window.__ADTB362__=b;window.__ADTB362T__=now;return b;}catch(e){return null;}}"
         // band: -1 explicit skip, 2 forced product-media section, 3 Reviews
         // photo-only. Highlights/Explore never receive White Background Taming.
         "function _adTameBand362(e){try{var b=_adTameBands362();if(!b||!e)return 0;var r=e.getBoundingClientRect(),y=r.top+(window.scrollY||window.pageYOffset||0)+r.height/2;"
           "if(b.medical>=0&&y>b.medical&&y<(b.highlights>b.medical?b.highlights:b.medical+520))return -1;"
           "if(b.highlights>=0&&y>b.highlights&&y<(b.giftcard>b.highlights?b.giftcard:b.highlights+520))return -1;"
           "if(b.reviews>=0&&y>b.reviews&&y<(b.help>b.reviews?b.help:b.reviews+900))return 3;"
           "if(b.explore>=0&&y>b.explore&&y<(b.shopcat>b.explore?b.shopcat:b.explore+720))return -1;"
           "if(b.sub>=0&&y>b.sub&&y<(b.keep>b.sub?b.keep:b.sub+760))return 2;"
           "if(b.keep>=0&&y>b.keep&&y<(b.watched>b.keep?b.watched:b.keep+900))return 2;"
           "if(b.watched>=0&&y>b.watched&&y<(b.lists>b.watched?b.lists:b.watched+620))return 2;"
           "if(b.how>=0&&y>b.how&&y<(b.questions>b.how?b.questions:b.how+580))return 2;"
           "if(b.returns>=0&&y>b.returns&&y<(b.related>b.returns?b.related:b.returns+520))return 2;return 0;}catch(e){return 0;}}"
         "function _adExploreIcon363(e){try{var p=e,d=0,re=/(?:same-day|same day|pharmacy|prime video|amazon haul|whole foods|autos)/i;while(p&&d++<5){var tx=String(p.textContent||'').replace(/\\s+/g,' ').trim();if(tx.length>0&&tx.length<420&&re.test(tx))return true;p=p.parentElement;}}catch(x){}return false;}"
         "function _adNoTameGlyph367(e){try{var p=e,d=0,re=/(?:medical care|health ai|prescriptions|personal guida|fast,? free deliv|your amazon highlights|total savings|sessions streamed|keep streaming)/i;while(p&&d++<5){var tx=String(p.textContent||'').replace(/\\s+/g,' ').trim();if(tx.length>0&&tx.length<520&&re.test(tx))return true;p=p.parentElement;}}catch(x){}return false;}"
         "function _adBgPlacement365(e){try{var p=e,d=0;while(p&&d++<4){var c=p.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));var id=String(p.id||''),cw=String((p.getAttribute&&p.getAttribute('data-cel-widget'))||'');if(/ape-placement|ape-wrapper|adfeedbackmaincomponent|ad-slot|adslot/i.test(c+' '+id+' '+cw))return true;if(p.querySelector&&p.querySelector('iframe')&&p.getBoundingClientRect().width>240)return true;p=p.parentElement;}return false;}catch(x){return false;}}function _adHomeBgLeaf395(e){try{if(window.__ADFRAME_MODE__||!e||!document.body||!window.__ADTAME_ON__)return false;if(document.querySelector('#search,.s-search-results,[data-component-type=\"s-search-result\"],#productTitle,#dp-container,#ppd'))return false;var c=e.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));if(!/theming-card-background|vjs-poster/i.test(c))return false;var p=e,u=0,ctx=c;while(p&&u++<7){ctx+=' '+String(p.className||'')+' '+String(p.id||'');if(/single-video-card|single-creative-card|video-card|video-js|vjs-|sbv-video|theming-card/i.test(ctx))break;p=p.parentElement;}if(!/single-video-card|single-creative-card|video-card|video-js|vjs-|sbv-video|theming-card/i.test(ctx))return false;var S=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),aa=(0.50*(S/100)).toFixed(3);e.removeAttribute('data-ad-tame-bgfast364');e.removeAttribute('data-ad-tame-fast362');e.style.setProperty('filter','none','important');e.style.removeProperty('background-color');e.style.setProperty('background-blend-mode','normal','important');e.style.setProperty('box-shadow','inset 0 0 0 9999px rgba(0,0,0,'+aa+')','important');e.setAttribute('data-ad-homebg395','1');e.__adTamed=1;e.__adTameSig='HBG395|'+String(getComputedStyle(e).backgroundImage||'');e.__adBy='homeBgLeaf395';return true;}catch(x){return false;}}"
         "function _adKnownProduct366(e){try{if(!e)return false;var p=e,d=0;while(p&&d++<6){var c=p.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));var id=String(p.id||''),asin=String((p.getAttribute&&p.getAttribute('data-asin'))||''),href=String((p.getAttribute&&p.getAttribute('href'))||'');if(asin||/asin|product|p13n|npack|cxvhz|gwm-asin|carousel-image|product-image/i.test(c+' '+id)||href.indexOf('/dp/')>=0||href.indexOf('/gp/product/')>=0)return true;p=p.parentElement;}return false;}catch(x){return false;}}"
         "function _adTameCss362(){try{if(!window.__ADTAME_ON__)return;if(document.getElementById('adtame362'))return;"
           "var S=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),bb=(1-0.50*(S/100)).toFixed(3);"
           "var aa=(0.50*(S/100)).toFixed(3);var st=document.createElement('style');st.id='adtame362';st.textContent='[data-ad-tame-fast362=\"1\"]{filter:brightness('+bb+') saturate(1.08) !important;}[data-ad-tame-bgfast364=\"1\"]{background-color:rgba(0,0,0,'+aa+') !important;background-blend-mode:multiply !important;}';"
           "(document.head||document.documentElement).appendChild(st);}catch(e){}}"
         "function _adTameFast362(root){try{if(!window.__ADTAME_ON__||!root||root.nodeType!==1)return 0;_adTameCss362();var S365=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),bb365=(1-0.50*(S365/100)).toFixed(3),aa365=(0.50*(S365/100)).toFixed(3);var A=[];"
           "if(/^(IMG|VIDEO|CANVAS)$/i.test(String(root.tagName||'')))A.push(root);try{var q=root.querySelectorAll('img,video,canvas');for(var i=0;i<q.length&&i<100;i++)A.push(q[i]);}catch(e){}"
           "var n=0;for(var j=0;j<A.length&&j<120;j++){var x=A[j],tg=String(x.tagName||'').toUpperCase(),cn=x.className;cn=String(cn&&cn.baseVal!==undefined?cn.baseVal:(cn||''));var band=_adTameBand362(x),xr=x.getBoundingClientRect(),prod366=(tg==='IMG'&&_adKnownProduct366(x)),review366=(band===3);"
             "if(band<0||_adExploreIcon363(x)||_adNoTameGlyph367(x)){x.removeAttribute('data-ad-tame-fast362');if(String(x.__adBy||'').indexOf('whiteTame')===0)x.style.removeProperty('filter');x.__adTamed=0;x.__adBy='exploreSkip362';continue;}"
             "if(review366&&tg!=='IMG')continue;if(review366&&/sprite|icon|logo|pixel|star|rating|close/i.test(cn))continue;"
             "if(band!==2&&!review366&&!prod366&&/sprite|icon|logo|pixel/i.test(cn))continue;if(x.__adGlyph&&band!==2&&!review366&&!prod366)continue;var ok=(tg==='VIDEO'||tg==='CANVAS');"
             "if(!ok&&tg==='IMG'){var nw=x.naturalWidth||+(x.getAttribute&&x.getAttribute('width')||0),nh=x.naturalHeight||+(x.getAttribute&&x.getAttribute('height')||0),mn=((band===2||review366||prod366)?24:56);ok=(nw>=mn&&nh>=mn)||((review366||prod366)&&xr.width>=24&&xr.height>=24);}"
             "if(!ok)continue;var want365='brightness('+bb365+') saturate(1.08)';x.setAttribute('data-ad-tame-fast362','1');if(String(x.style.getPropertyValue('filter')||'')!==want365||x.style.getPropertyPriority('filter')!=='important')x.style.setProperty('filter',want365,'important');x.__adTamed=1;x.__adTameSig=tg+'|'+String(x.currentSrc||x.src||x.poster||'');x.__adBy=(review366?'whiteTameReview366':(band===2?'whiteTameFast365ctx':'whiteTameFast365'));n++;}"
           // CSS-background ads were the remaining sporadic Home misses once the full
           // pass was intentionally delayed. Scan only a tiny local budget here and
           // mark the BACKGROUND layer; child text is never filtered.
           "var B=[];if(/^(DIV|SPAN|A|SECTION|LI)$/i.test(String(root.tagName||'')))B.push(root);try{var qb=root.querySelectorAll('div,span,a,section,li');for(var k=0;k<qb.length&&k<120;k++)B.push(qb[k]);}catch(e){}"
           "var bg=0;for(var z=0;z<B.length&&z<130;z++){var be=B[z],bandb=_adTameBand362(be);if(bandb<0||bandb===3||_adExploreIcon363(be)||_adNoTameGlyph367(be)){be.removeAttribute('data-ad-tame-bgfast364');if(String(be.__adBy||'').indexOf('whiteTame')===0){be.style.removeProperty('background-color');be.style.removeProperty('background-blend-mode');be.__adBy='tameSkip365';}continue;}"
             "if(_adHomeBgLeaf395(be))continue;if(_adBgPlacement365(be)||(be.hasAttribute&&be.hasAttribute('data-ad-productad367')))continue;var cs=getComputedStyle(be),bi=String(cs.backgroundImage||'none');if(bi.indexOf('url(')<0)continue;var br=be.getBoundingClientRect(),mn2=(bandb===2?32:56);if(br.width<mn2||br.height<mn2)continue;var bc=be.className;bc=String(bc&&bc.baseVal!==undefined?bc.baseVal:(bc||''));if(bandb!==2&&/sprite|icon|logo|pixel/i.test(bc))continue;be.setAttribute('data-ad-tame-bgfast364','1');be.style.setProperty('background-color','rgba(0,0,0,'+aa365+')','important');be.style.setProperty('background-blend-mode','multiply','important');be.__adTamed=1;be.__adTameSig='BG|'+bi;be.__adBy=(bandb===2?'whiteTameFastBg365ctx':'whiteTameFastBg365');bg++;}"
           "return n+bg;}catch(e){return 0;}}"
         "try{window._adTameFast362=_adTameFast362;_adTameCss362();_adTameFast362(document.documentElement);document.addEventListener('load',function(e){try{_adTameFast362(e.target);}catch(x){}},true);}catch(e){}"

         "try{if(!window.__AD_TWB446_OBS__){window.__AD_TWB446_OBS__=1;new MutationObserver(function(muts){try{for(var mi=0;mi<muts.length&&mi<48;mi++){var mm=muts[mi];if(mm.type==='attributes'){if(mm.target)window._adTameFast362(mm.target);continue;}var aa=mm.addedNodes||[];for(var ai=0;ai<aa.length&&ai<24;ai++){if(aa[ai]&&aa[ai].nodeType===1)window._adTameFast362(aa[ai]);}}}catch(x){}}).observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['src','srcset','poster','class']});}}catch(e){}"
         "}catch(e){}})();",
        (long)gP.whiteTameStrength];
}

static void ADAttachWhiteTameUserScript446(WKUserContentController *ucc){
    if (!ucc || !gP.enabled || !gP.whiteTame) return;
    @try {
        for (WKUserScript *existing in ucc.userScripts){
            if ([existing.source containsString:@"__AD_TWB446_INSTALLED__"]) return;
        }
        NSString *js=ADWhiteTameWebJS446();
        if(!js.length)return;
        WKUserScript *us=[[WKUserScript alloc] initWithSource:js injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
        [ucc addUserScript:us];
    } @catch(...) {}
}

// LIGHT: re-apply the theme. MUST be a no-op when the page is already themed.
//
// This previously ran DarkReader.disable() whenever style.darkreader was missing,
// then re-enabled. That call strips Dark Reader's stylesheet, so the page snaps to
// stock white before going dark again — and because the burst fires it repeatedly
// (0/60/200/500ms on every viewDidAppear, plus each sweep), the home tab visibly
// flashed white/dark/white. It was added to fix the cart, but the cart's real cause
// was 'noflag' (the user script never ran in that document), which the self-heal
// below handles. So the disable() was solving a problem that did not exist while
// creating one that did. Removed.
//
// Now: if the stylesheet is present the page is themed and we touch nothing.
// LIGHT: re-apply. Skipping DarkReader.enable() when the page is already themed is
// what stopped the white flashing in v5.5.1 and must stay — but the REPAIR passes
// must not inherit that early return.
//
// They did, and it made three builds' worth of work inert. The SVG fill fix, the
// contrast lifting and the shadow-DOM traversal all live inside
// __AMZDARK_FIXCONTRAST__, and this function returned before reaching it whenever
// style.darkreader was present. On the search pane — which IS themed, its
// recent-search text being correctly light — the native burst therefore did nothing
// at all, which is exactly why those icons and labels never changed.
//
// So: enable() stays conditional, the repair runs every time. It is idempotent
// (it only rewrites values that currently fail) and cheap on a settled page.
static NSString *ADDarkReaderReapply(void){
    return [NSString stringWithFormat:
        @"(function(){try{"
         "if(!(window.DarkReader&&DarkReader.enable))return 'noDR';"
         "if(!document.querySelector('style.darkreader'))DarkReader.enable(%@,%@);"
         "if(window.__AMZDARK_FIXCONTRAST__)return ''+window.__AMZDARK_FIXCONTRAST__();"
         "return 'nofix';"
         "}catch(e){return 'err';}})();",
        ADThemeLiteral(), ADFixesLiteral()];
}


// ── v6.0.5: Heart / two-cards / chevron only ────────────────────────────────
// Amazon owns all other controls end-to-end; this subsystem never selects them.
static NSString *ADThreeSymbolsWebJS605(void){
    static NSString *cached = nil;
    if (cached) return cached;
    cached = [NSString stringWithFormat:
       @"(function(){try{if(window.__AD_SYM605_LOADED__)return 'already';window.__AD_SYM605_LOADED__=1;"
         "window.__AD_HEARTSHELL427__=function(){try{if(window.__ADFRAME_MODE__||!document.body)return 0;"
           "function card427(e){var c=String(e&&e.className||'');return /mlt-icon-container/.test(c)||e.getAttribute('data-ad-sym413')==='cards';}"
           "function inner427(e){return !!(e&&(e.hasAttribute('data-ad-cards410-host')||e.hasAttribute('data-ad-cards410-root')||e.hasAttribute('data-ad-cards410-disc')));}"
           "function own427(e){return e.getAttribute('data-ad-sym413')==='heart'||e.hasAttribute('data-ad-heart-shell427');}"
           "function flat427(e){e.setAttribute('data-ad-heart-shell427','1');e.__adBy='heartShell427';"
             "['data-ad-sym413','data-ad-v333404'].forEach(function(a){e.removeAttribute(a);});"
             "e.style.setProperty('background-color','transparent','important');"
             "e.style.setProperty('border','0','important');"
             "e.style.setProperty('border-radius','0','important');"
             "e.style.setProperty('box-shadow','none','important');"
             "e.style.setProperty('outline','none','important');}"
           "var R=document.querySelectorAll('[class*=lists-framework-action-button],[class*=puis-heart-position]'),n=0;"
           "for(var i=0;i<R.length&&i<180;i++){var p=R[i].parentElement,d=0;while(p&&d++<4){"
             "if(card427(p))break;if(inner427(p)){p=p.parentElement;continue;}var r=p.getBoundingClientRect();"
             "var geom=r.width>=18&&r.width<=60&&r.height>=18&&r.height<=60&&Math.abs(r.width-r.height)<=12;"
             "if(geom&&own427(p)){var st=getComputedStyle(p),clean=(String(st.backgroundColor||'').replace(/\\s+/g,'')==='rgba(0,0,0,0)'||String(st.backgroundColor||'')==='transparent')&&parseFloat(st.borderTopWidth||0)<.1&&String(st.boxShadow||'none')==='none';if(!clean||!p.hasAttribute('data-ad-heart-shell427'))flat427(p);n++;}"
             "p=p.parentElement;}}return n;}catch(e){return -1;}};"
         "try{if(document&&!document.getElementById('adheartshell427')){var h427=document.createElement('style');h427.id='adheartshell427';h427.textContent='[data-ad-heart-shell427]{background-color:transparent !important;border:0 !important;border-radius:0 !important;box-shadow:none !important;outline:none !important;}[data-ad-heart-shell427]::before,[data-ad-heart-shell427]::after{background-color:transparent !important;border:0 !important;box-shadow:none !important;outline:none !important;}';(document.head||document.documentElement).appendChild(h427);}}catch(e){}"
         "function sym413(){try{"
           "var SPEC={bg:'#181a1b',bd:'1.5px solid rgba(255,255,255,0.65)'};"
           "if(!document.getElementById('adcards440')){var s440=document.createElement('style');s440.id='adcards440';s440.textContent='[data-ad-cards440-pseudo*=b]::before,[data-ad-cards440-pseudo*=a]::after{filter:brightness(0) invert(1) !important;color:#fff !important;fill:#fff !important;stroke:#fff !important;}';(document.head||document.documentElement).appendChild(s440);}"
           "function cn(e){var c=e&&e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||''));}"
           "function rr(e){try{return e&&e.getBoundingClientRect?e.getBoundingClientRect():null;}catch(x){return null;}}"
           "function sq(e){var r=rr(e);return !!(r&&r.width>=22&&r.width<=48&&r.height>=22&&r.height<=48&&Math.abs(r.width-r.height)<=10);}"
           "function kind(e){var c=cn(e);if(/mlt-icon-container/.test(c))return 'cards';if(/puis-mab-chevron/.test(c)&&!/glyph/.test(c))return 'chevron';if(/puis-heart-position/.test(c)||/lists-framework-action-button/.test(c))return 'heart';return '';}"
           "function shown(e,stop){try{var p=e,u=0;while(p&&u++<10){var st=getComputedStyle(p),o=parseFloat(st.opacity||'1');if(String(st.display||'')==='none'||/hidden|collapse/.test(String(st.visibility||''))||o<.08)return false;if(p===stop)break;p=p.parentElement;}var r=rr(e);return !!(r&&r.width>=3&&r.height>=3);}catch(x){return false;}}"
           "function legacy(e){if(!e||e.hasAttribute('data-ad-cards440-host'))return;var old=e.getAttribute('data-ad-sym413')==='cards'||e.getAttribute('data-ad-disc420')==='disc'||e.__adBy==='sym413';if(old){['background-color','border','border-radius','box-shadow','box-sizing'].forEach(function(p){e.style.removeProperty(p);});e.removeAttribute('data-ad-sym413');e.removeAttribute('data-ad-disc420');delete e.__adBy;}var A=e.querySelectorAll('*');for(var i=0;i<A.length&&i<48;i++){var a=A[i],by=String(a.__adBy||''),owned=a.hasAttribute('data-ad-sym413glyph')||/^(?:sym413glyph|disc420|disc422)$/.test(by);if(!owned)continue;['filter','color','fill','stroke','background-color','visibility','opacity','border','box-shadow'].forEach(function(p){a.style.removeProperty(p);});a.removeAttribute('data-ad-sym413glyph');delete a.__adBy;delete a.__adGlyph;}}"
           "function clearCards(e){var P=['background-color','border','border-radius','box-shadow','box-sizing'];for(var p=0;p<P.length;p++)e.style.removeProperty(P[p]);e.removeAttribute('data-ad-cards440-host');e.removeAttribute('data-ad-cards440-pseudo');e.removeAttribute('data-ad-sym413');var A=e.querySelectorAll('[data-ad-cards440-glyph],[data-ad-cards440-pseudo]');for(var i=0;i<A.length;i++){var a=A[i];['filter','color','fill','stroke','background-color'].forEach(function(k){a.style.removeProperty(k);});a.removeAttribute('data-ad-cards440-glyph');a.removeAttribute('data-ad-cards440-pseudo');if(a.__adBy==='cards440')delete a.__adBy;}}"
           "function glyph440(g){var r=rr(g);return !!(r&&r.width>=3&&r.height>=3&&r.width<=48&&r.height<=48);}"
           "function cards(e){legacy(e);var N=e.querySelectorAll('[class*=mlt-image-icon],img[class*=s-image],p[class*=mlt-text-icon],img,i,svg,path,use,polygon'),P=[e],live=[],pseudo='';for(var pi=0;pi<N.length&&pi<47;pi++)P.push(N[pi]);for(var i=0;i<P.length&&i<48;i++){var g=P[i];if(!glyph440(g)||!shown(g,e))continue;var t=String(g.tagName||'').toUpperCase(),st=getComputedStyle(g),bb=getComputedStyle(g,'::before'),aa=getComputedStyle(g,'::after'),paint=/^(IMG|I|SVG|PATH|USE|POLYGON)$/.test(t)||/mlt-text-icon/.test(cn(g))||String(st.backgroundImage||'none')!=='none'||String(st.maskImage||st.webkitMaskImage||'none')!=='none';if(String(bb&&bb.backgroundImage||'none')!=='none'||String(bb&&bb.content||'none')!=='none')pseudo+='b';if(String(aa&&aa.backgroundImage||'none')!=='none'||String(aa&&aa.content||'none')!=='none')pseudo+='a';if(paint)live.push(g);}if(!live.length&&!pseudo){clearCards(e);return 0;}var old=e.querySelectorAll('[data-ad-cards440-glyph],[data-ad-cards440-pseudo]');for(var o=0;o<old.length;o++){if(live.indexOf(old[o])>=0)continue;['filter','color','fill','stroke','background-color'].forEach(function(k){old[o].style.removeProperty(k);});old[o].removeAttribute('data-ad-cards440-glyph');old[o].removeAttribute('data-ad-cards440-pseudo');}e.setAttribute('data-ad-sym413','cards');e.setAttribute('data-ad-cards440-host','1');if(pseudo)e.setAttribute('data-ad-cards440-pseudo',pseudo);else e.removeAttribute('data-ad-cards440-pseudo');e.__adBy='cards440';e.style.setProperty('background-color',SPEC.bg,'important');e.style.setProperty('border',SPEC.bd,'important');e.style.setProperty('border-radius','50%%','important');e.style.setProperty('box-shadow','none','important');e.style.setProperty('box-sizing','border-box','important');for(var j=0;j<live.length;j++){var z=live[j],tg=String(z.tagName||'').toUpperCase();z.setAttribute('data-ad-cards440-glyph','1');z.__adBy='cards440';if(/^(SVG|PATH|USE|POLYGON)$/.test(tg)){z.style.setProperty('filter','none','important');z.style.setProperty('fill','#ffffff','important');z.style.setProperty('stroke','#ffffff','important');}else z.style.setProperty('filter','brightness(0) invert(1)','important');z.style.setProperty('color','#ffffff','important');z.style.setProperty('background-color','transparent','important');if(pseudo)z.setAttribute('data-ad-cards440-pseudo',pseudo);}return 1;}"
           "var Q=document.querySelectorAll('[class*=mlt-icon-container],[class*=puis-mab-chevron],[class*=puis-heart-position],[class*=lists-framework-action-button]');"
           "for(var i=0;i<Q.length&&i<320;i++){var e=Q[i],k=kind(e);if(!k)continue;if(k==='cards'){cards(e);continue;}var hs=e.querySelector&&e.querySelector('[class*=lists-framework-action-button],[class*=puis-heart-position]');if(hs){e.setAttribute('data-ad-heart-shell427','1');e.style.setProperty('background-color','transparent','important');e.style.setProperty('border','0','important');e.style.setProperty('border-radius','0','important');e.style.setProperty('box-shadow','none','important');e.style.setProperty('outline','none','important');continue;}if(!sq(e))continue;if(e.parentElement&&e.parentElement.closest&&e.parentElement.closest('[data-ad-sym413]'))continue;e.setAttribute('data-ad-sym413',k);e.__adBy='sym413';e.style.setProperty('background-color',SPEC.bg,'important');e.style.setProperty('border',SPEC.bd,'important');e.style.setProperty('border-radius','50%%','important');e.style.setProperty('box-shadow','none','important');e.style.setProperty('box-sizing','border-box','important');var G=e.querySelectorAll('img,i,svg,path,p');for(var j=0;j<G.length&&j<24;j++){var g=G[j],gr=g.getBoundingClientRect();if(gr.width>48||gr.height>48)continue;var tg=String(g.tagName||'').toUpperCase();if(tg==='IMG'||tg==='I'||tg==='P')g.style.setProperty('filter','brightness(0) invert(1)','important');g.__adBy='sym413glyph';g.setAttribute('data-ad-sym413glyph','1');if(tg==='SVG'||tg==='PATH'){g.style.setProperty('fill','#ffffff','important');g.style.setProperty('color','#ffffff','important');}g.style.setProperty('background-color','transparent','important');g.style.setProperty('visibility','visible','important');g.style.setProperty('opacity','1','important');}}"
         "}catch(e){}}"
         "window.__AD_SYM605_RUN__=sym413;"
         "window.__AD_SYM605_QUEUE__=function(){try{if(window.__AD_SYM605_Q__)return;window.__AD_SYM605_Q__=1;var f=function(){window.__AD_SYM605_Q__=0;try{window.__AD_HEARTSHELL427__();}catch(x){}try{window.__AD_SYM605_RUN__();}catch(x){}};if(window.requestAnimationFrame)requestAnimationFrame(f);else setTimeout(f,0);}catch(e){}};"
         "try{if(!window.__AD_SYM605_OBS__){window.__AD_SYM605_OBS__=1;new MutationObserver(function(){window.__AD_SYM605_QUEUE__();}).observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['class','src','data-src']});addEventListener('scroll',window.__AD_SYM605_QUEUE__,{passive:true,capture:true});}window.__AD_SYM605_QUEUE__();setTimeout(window.__AD_SYM605_QUEUE__,140);setTimeout(window.__AD_SYM605_QUEUE__,700);}catch(e){}"
       "return 'sym605';}catch(e){return 'sym605err';}})();"];
    return cached;
}

static void ADAttachThreeSymbolsUserScript605(WKUserContentController *ucc){
    if (!ucc) return;
    @try {
        NSString *js = ADThreeSymbolsWebJS605();
        if (!js.length) return;
        for (WKUserScript *u in ucc.userScripts){
            if ([u.source containsString:@"__AD_SYM605_LOADED__"]) return;
        }
        WKUserScript *us = [[WKUserScript alloc] initWithSource:js
            injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
        [ucc addUserScript:us];
    } @catch(...) {}
}

static void ADEnableDarkReaderIn(WKWebView *wv){
    if (!gP.enabled || !gP.webDarkReader || !wv) return;
    @try {
        ADAttachWhiteTameUserScript446(wv.configuration.userContentController);
        ADAttachThreeSymbolsUserScript605(wv.configuration.userContentController);
        [wv evaluateJavaScript:@"(function(){try{if(window.__AD_SYM605_QUEUE__){window.__AD_SYM605_QUEUE__();return 1;}return 0;}catch(e){return 0;}})();"
             completionHandler:^(id r, NSError *e){
                 if (!e && [r respondsToSelector:@selector(boolValue)] && [r boolValue]) return;
                 NSString *full=ADThreeSymbolsWebJS605(); if(full.length)[wv evaluateJavaScript:full completionHandler:nil];
             }];
        if(gP.whiteTame){
            [wv evaluateJavaScript:@"(function(){try{if(window._adTameFast362){window._adTameFast362(document.documentElement);return 1;}return 0;}catch(e){return 0;}})();"
                 completionHandler:^(id r, NSError *e){
                     if (!e && [r respondsToSelector:@selector(boolValue)] && [r boolValue]) return;
                     NSString *full=ADWhiteTameWebJS446(); if(full.length)[wv evaluateJavaScript:full completionHandler:nil];
                 }];
        }
        // Lightweight re-apply; the heavy engine arrives via the documentStart userscript.
        NSString *js = ADDarkReaderReapply();
        if (js.length){
            [wv evaluateJavaScript:js completionHandler:^(id r, NSError *e){
                @try {
                    if (![r isKindOfClass:[NSString class]]) return;
                    NSString *res = (NSString *)r;
                    // 'n/bfix' = text colours lifted / blend modes neutralised.
                    // 'nofix'  = the repair function is not defined in this document.
                    // Deduped per URL+result so a settled page cannot spam the log.
                    static NSMutableSet *seenFix = nil;
                    if (!seenFix) seenFix = [NSMutableSet set];
                    NSString *u2 = wv.URL.absoluteString ?: @"(none)";
                    if (u2.length > 60) u2 = [u2 substringToIndex:60];
                    NSString *k = [NSString stringWithFormat:@"%@|%@", u2, res];
                    if (![seenFix containsObject:k]){
                        [seenFix addObject:k];
                        ADLog(@"repair %@ -> %@", u2, res);
                    }
                } @catch(...) {}
            }];
        }

        // Name the page once per URL. Tells us which surfaces are actually web —
        // a tab that never shows up here is native and needs a different fix.
        static NSMutableSet *seen = nil;
        if (!seen) seen = [NSMutableSet set];
        NSString *u = wv.URL.absoluteString ?: @"(no url)";
        if (u.length > 90) u = [u substringToIndex:90];
        if (![seen containsObject:u]){
            [seen addObject:u];
            ADLog(@"web themed: %@", u);
        }

        // Report the page's ACTUAL state back into the log. The cart keeps reverting
        // to light on tab-return and two rounds of native-side timing fixes have not
        // held, so stop inferring: ask the document directly whether the engine is
        // loaded, whether its stylesheet is still attached, and what readyState it is
        // in. Deduped per URL+state so it cannot spam.
        [wv evaluateJavaScript:
            @"(function(){try{return (window.DarkReader?'DR':'noDR')+'/'"
             "+(document.querySelector('style.darkreader')?'styled':'NOSTYLE')+'/'"
             "+(window.__AMZDARK_LOADED__?'flag':'noflag')+'/'+document.readyState;}"
             "catch(e){return 'err';}})()"
             completionHandler:^(id result, NSError *err){
            @try {
                NSString *st = [result isKindOfClass:[NSString class]] ? (NSString *)result
                                                                       : @"(nonstring)";
                // Log state TRANSITIONS: remember the last state per URL and log only
                // when it changes, so an oscillation shows as alternating lines instead
                // of collapsing to one. This is what will confirm the flip is fixed.
                static NSMutableDictionary *lastState = nil;
                if (!lastState) lastState = [NSMutableDictionary dictionary];
                NSString *prev = lastState[u];
                if (!prev || ![prev isEqualToString:st]){
                    lastState[u] = st;
                    ADLog(@"web state: %@ -> %@%@", u, st, err ? @" (evalError)" : @"");
                }

                // SELF-HEAL. 'noflag' means __AMZDARK_LOADED__ is absent, i.e. the
                // documentStart WKUserScript never ran in THIS document — so the page
                // has no engine to re-enable and every light-touch re-apply is a no-op.
                // That is the real cart failure: not a bfcache restore (which would
                // keep the flag and lose only the styles), but a fresh document our
                // script never reached, because the web view was created or navigated
                // outside the window in which we attach the script.
                //
                // Rather than chase every creation path, repair it here: inject the
                // full engine directly into the live document. evaluateJavaScript does
                // not care how the document came to exist, so this works regardless.
                // v6.0.4: historical overlay probe removed; it only scanned/logged DOM.
                if ([st containsString:@"noflag"] || [st hasPrefix:@"noDR"]){
                    // ROOT-CAUSE HALF. noflag recurring on every navigation means our
                    // documentStart user script is not present on this web view's content
                    // controller any more. The binary exports removeAllUserScripts and an
                    // AMIPrewarmWebviewTask, so Amazon both prewarms web views (created
                    // before we could hook init) and clears user scripts on reuse. Healing
                    // the current document alone therefore fixes one page and leaves the
                    // NEXT navigation unthemed — which is precisely the observed cycle:
                    // noflag -> repair -> dark -> navigate -> noflag -> repair ...
                    //
                    // So re-attach the script here. Once it is back on the controller the
                    // next document is themed at documentStart, before first paint, and
                    // there is no white gap to repair.
                    @try {
                        WKUserContentController *ucc = wv.configuration.userContentController;
                        Class WKUS = NSClassFromString(@"WKUserScript");
                        NSString *boot = ADDarkReaderBootstrap();
                        if (ucc && WKUS && boot.length){
                            BOOL present = NO;
                            for (WKUserScript *existing in ucc.userScripts){
                                if ([existing.source containsString:@"__AMZDARK_LOADED__"]){
                                    present = YES;
                                    break;
                                }
                            }
                            if (!present){
                                WKUserScript *us =
                                    [[WKUS alloc] initWithSource:boot
                                                   injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                forMainFrameOnly:NO];
                                [ucc addUserScript:us];
                                ADAttachWhiteTameUserScript446(ucc);
                                ADLog(@"web: user script re-attached (was stripped) for %@", u);
                            }
                        }
                    } @catch(...) {}

                    // Re-heal EVERY time the document is unthemed, not once per URL.
                    // Guard on DOCUMENT identity: __AMZDARK_HEALED__ lives on window, so a
                    // fresh document at a reused URL heals again while a single document is
                    // never re-injected (no flash, no wasted 346KB parse).
                    NSString *heal =
                        @"(function(){try{"
                         "if(window.__AMZDARK_HEALED__)return 'already';"
                         "window.__AMZDARK_HEALED__=1;return 'heal';"
                         "}catch(e){return 'heal';}})()";
                    [wv evaluateJavaScript:heal completionHandler:^(id r2, NSError *e2){
                        @try {
                            if ([r2 isKindOfClass:[NSString class]] &&
                                [(NSString *)r2 isEqualToString:@"heal"]){
                                NSString *full = ADDarkReaderBootstrap();
                                if (full.length){
                                    ADLog(@"web repair: injecting full engine into %@", u);
                                    [wv evaluateJavaScript:full completionHandler:^(id r3, NSError *e3){
                                        if (e3) ADLog(@"web repair FAILED: %@", e3.localizedDescription);
                                    }];
                                }
                            }
                        } @catch(...) {}
                    }];
                }
            } @catch(...) {}
        }];
    } @catch(...) {}
}

// Inject the FULL engine into whatever is already rendered (used once for web views
// that existed before our hook — e.g. the warmed gateway — where the documentStart
// userscript won't fire until the next load). Idempotent: the bootstrap self-guards
// on window.__AMZDARK_LOADED__, so calling it repeatedly is safe.
static void ADBootstrapDarkReaderIn(WKWebView *wv){
    if (!gP.enabled || !gP.webDarkReader || !wv) return;
    @try {
        NSString *js = ADDarkReaderBootstrap();
        if (js.length) [wv evaluateJavaScript:js completionHandler:nil];
        NSString *twb446 = ADWhiteTameWebJS446();
        if (twb446.length) [wv evaluateJavaScript:twb446 completionHandler:nil];
        NSString *sym446 = ADThreeSymbolsWebJS605();
        if (sym446.length) [wv evaluateJavaScript:sym446 completionHandler:nil];
    } @catch(...) {}
}

static int gWebSeen = 0;
static void ADWalkWebViews(UIView *v){
    @try {
        if ([v isKindOfClass:[WKWebView class]]){ gWebSeen++; ADEnableDarkReaderIn((WKWebView *)v); }
        for (UIView *s in v.subviews) ADWalkWebViews(s);
    } @catch(...) {}
}
static void ADInjectAllWebViews(void){
    @try {
        gWebSeen = 0;
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes){
            if (![sc isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)sc).windows) ADWalkWebViews(w);
        }
        static int lastReported = -1;
        if (gWebSeen != lastReported){ ADLog(@"web views themed: %d", gWebSeen); lastReported = gWebSeen; }
    } @catch(...) {}
}

// ════════════════════════════════════════════════════════════════════════════════
// WKUserContentController — restore our script the moment Amazon strips it.
// ────────────────────────────────────────────────────────────────────────────────
// The binary exports removeAllUserScripts and AMIPrewarmWebviewTask: Amazon prewarms
// web views and clears their user scripts on reuse. That is why 'noflag' recurred on
// every navigation no matter how many times we healed the current document — the
// documentStart hook was being removed behind us, so each new page painted white
// before the repair could land. Re-adding immediately after the strip means the next
// document is themed at documentStart, before first paint, so there is no white gap
// at all rather than a gap we race to patch.
// ════════════════════════════════════════════════════════════════════════════════
%hook WKUserContentController
- (void)removeAllUserScripts {
    %orig;
    @try {
        if (!gP.enabled || !gP.webDarkReader) return;
        NSString *boot = ADDarkReaderBootstrap();
        Class WKUS = NSClassFromString(@"WKUserScript");
        if (!boot.length || !WKUS) return;
        WKUserScript *us = [[WKUS alloc] initWithSource:boot
                                          injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                       forMainFrameOnly:NO];
        [self addUserScript:us];
        ADAttachWhiteTameUserScript446(self);
        ADAttachThreeSymbolsUserScript605(self);
        ADLog(@"web: user scripts restored after removeAllUserScripts");
    } @catch(...) {}
}
%end

%hook WKWebView
- (id)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)cfg {
    @try {
        if (gP.enabled && gP.webDarkReader && cfg && cfg.userContentController){
            NSString *js = ADDarkReaderBootstrap();
            Class WKUS = NSClassFromString(@"WKUserScript");
            if (js.length && WKUS){
                WKUserScript *us = [[WKUS alloc] initWithSource:js
                                                  injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                               forMainFrameOnly:NO];
                [cfg.userContentController addUserScript:us];
                ADAttachWhiteTameUserScript446(cfg.userContentController);
                ADAttachThreeSymbolsUserScript605(cfg.userContentController);
            }
        }
    } @catch(...) {}
    return %orig;
}
- (void)didMoveToWindow {
    %orig;
    @try {
        if (!self.window || !gP.enabled || !gP.webDarkReader) return;
        ADPreDarken(self);   // exact v5.446 instant dark floor for a page that is mid-load
        ADAttachThreeSymbolsUserScript605(self.configuration.userContentController);
        // Paint the web view's own backdrop dark up front so the white page has
        // nothing to flash before Dark Reader paints the DOM. Cheap and idempotent.
        self.opaque = NO;
        self.backgroundColor = ADColorFromHex(gP.bgHex);
        @try { [self setValue:ADColorFromHex(gP.bgHex) forKey:@"underPageBackgroundColor"]; } @catch(...) {}
        // Attach a documentStart user-script even to pre-initialised web views (e.g. the
        // warmed gateway) so a pull-to-refresh re-applies Dark Reader on the next load.
        static const void *kUS = &kUS;
        if (!objc_getAssociatedObject(self, kUS)){
            NSString *js = ADDarkReaderBootstrap();
            Class WKUS = NSClassFromString(@"WKUserScript");
            WKUserContentController *ucc = self.configuration.userContentController;
            if (js.length && WKUS && ucc){
                WKUserScript *us = [[WKUS alloc] initWithSource:js
                                                  injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                               forMainFrameOnly:NO];
                [ucc addUserScript:us];
                ADAttachWhiteTameUserScript446(ucc);
                ADAttachThreeSymbolsUserScript605(ucc);
            }
            objc_setAssociatedObject(self, kUS, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        ADBootstrapDarkReaderIn(self); // engine into the already-rendered document (idempotent)
    } @catch(...) {}
}
- (void)webView:(WKWebView *)wv didFinishNavigation:(id)nav {
    %orig;
    ADEnableDarkReaderIn(self);
    // v5.446 direct-port cover release: only a real Amazon page counts.
    @try {
        NSString *nu = wv.URL.absoluteString ?: @"";
        BOOL realPage = ([nu containsString:@"amazon.com"] &&
                         ![nu containsString:@"about:blank"] &&
                         ![nu containsString:@"autocomplete"] &&
                         ![nu containsString:@"/ap/"]);
        ADLog(@"navdone real=%d %@", realPage ? 1 : 0,
              nu.length > 60 ? [nu substringToIndex:60] : nu);
        if (realPage){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ ADPostAppReady(); });
        }
    } @catch(...) {}
}
%end


// ── PROMOTION OPT-IN + 120 HZ REQUEST (v6.0.7) ────────────────────────────────
// Apple gates >60 Hz on iPhone behind CADisableMinimumFrameDurationOnPhone.
// Amazon's shipped Info.plist does not expose that opt-in, so Core Animation capped
// the old Request 120 Hz hook at 60 even on a 120-Hz panel.  Present the key as YES
// from both Foundation and CoreFoundation lookup paths.  This only unlocks the
// available range; the preference below still decides whether AmazonDark explicitly
// requests the panel maximum. System thermal / Low Power / accessibility policy wins.
static NSString * const ADPromotionInfoKey607 = @"CADisableMinimumFrameDurationOnPhone";

%hook NSBundle
- (id)objectForInfoDictionaryKey:(NSString *)key {
    @try {
        if (self == [NSBundle mainBundle] && [key isEqualToString:ADPromotionInfoKey607]) return @YES;
    } @catch(...) {}
    return %orig;
}
- (NSDictionary *)infoDictionary {
    NSDictionary *d = %orig;
    @try {
        if (self != [NSBundle mainBundle] || [d[ADPromotionInfoKey607] boolValue]) return d;
        NSMutableDictionary *m = [d mutableCopy];
        m[ADPromotionInfoKey607] = @YES;
        return m;
    } @catch(...) {}
    return d;
}
%end

%hookf(CFTypeRef, CFBundleGetValueForInfoDictionaryKey, CFBundleRef bundle, CFStringRef key) {
    if (bundle == CFBundleGetMainBundle() && key && CFEqual(key, CFSTR("CADisableMinimumFrameDurationOnPhone")))
        return kCFBooleanTrue;
    return %orig;
}

// Requests the panel maximum (up to 120 Hz) from CADisplayLink when enabled.
// The v6.0.7 bundle-key spoof above removes Amazon's 60-Hz opt-in ceiling; this
// remains best-effort because iOS can reduce refresh under system policy.
static NSInteger ADPreferredMaxHz362(void){
    @try { return MIN((NSInteger)120, MAX((NSInteger)60, UIScreen.mainScreen.maximumFramesPerSecond)); } @catch(...) {}
    return 60;
}
%hook CADisplayLink
+ (CADisplayLink *)displayLinkWithTarget:(id)target selector:(SEL)sel {
    CADisplayLink *d=%orig;
    @try { if (gP.enabled && gP.force120Hz){ NSInteger hz=ADPreferredMaxHz362(); if (@available(iOS 15.0,*)) d.preferredFrameRateRange=CAFrameRateRangeMake(hz,hz,hz); else d.preferredFramesPerSecond=hz; } } @catch(...) {}
    return d;
}
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    @try {
        if (gP.enabled && gP.force120Hz){
            NSInteger hz = ADPreferredMaxHz362();
            %orig(hz);
            return;
        }
    } @catch(...) {}
    %orig;
}
- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    @try {
        if (gP.enabled && gP.force120Hz){
            NSInteger hz = ADPreferredMaxHz362();
            CAFrameRateRange forcedRange = CAFrameRateRangeMake(hz, hz, hz);
            %orig(forcedRange);
            return;
        }
    } @catch(...) {}
    %orig;
}
%end

// ── one-shot 120 Hz verification ──────────────────────────────────────────────
// Runs only when Request 120 Hz is enabled. It samples one second, writes one
// tiny result file, invalidates its display link, and has no standing runtime cost.
@interface ADHzProbeTarget : NSObject
@property(nonatomic,assign) NSUInteger frames;
@property(nonatomic,assign) CFTimeInterval firstTS;
@property(nonatomic,assign) double timingHzSum;
@property(nonatomic,assign) NSUInteger timingSamples;
@end
static ADHzProbeTarget *gADHzProbeTarget = nil;
static BOOL gADHzProbeDone = NO;
@implementation ADHzProbeTarget
- (void)tick:(CADisplayLink *)link {
    @try {
        if (self.firstTS <= 0) self.firstTS = link.timestamp;
        self.frames++;
        CFTimeInterval dt = link.targetTimestamp - link.timestamp;
        if (dt > 0.001 && dt < 0.1){ self.timingHzSum += 1.0/dt; self.timingSamples++; }
        CFTimeInterval elapsed = link.timestamp - self.firstTS;
        if (elapsed < 1.0) return;
        double callbackHz = elapsed > 0 ? ((double)(self.frames - 1) / elapsed) : 0;
        double timingHz = self.timingSamples ? self.timingHzSum / (double)self.timingSamples : 0;
        NSInteger maxHz = UIScreen.mainScreen.maximumFramesPerSecond;
        BOOL unlocked = [[[NSBundle mainBundle] objectForInfoDictionaryKey:ADPromotionInfoKey607] boolValue];
        BOOL lowPower = [NSProcessInfo processInfo].lowPowerModeEnabled;
        NSInteger thermal = 0;
        if (@available(iOS 11.0, *)) thermal = [NSProcessInfo processInfo].thermalState;
        NSString *report = [NSString stringWithFormat:
            @"AmazonDark %@\nforce120Hz=1\nscreenMax=%ld\nbundleHighRefreshUnlocked=%d\nlowPowerMode=%d\nthermalState=%ld\ncallbackHz=%.1f\ntargetTimingHz=%.1f\n",
            @AD_VERSION, (long)maxHz, unlocked ? 1 : 0, lowPower ? 1 : 0,
            (long)thermal, callbackHz, timingHz];
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"AmazonDark-hz.txt"];
        [report writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [link invalidate]; gADHzProbeTarget = nil;
    } @catch(...) { [link invalidate]; gADHzProbeTarget=nil; }
}
@end
static void ADStartHzVerification(void){
    @try {
        if (!gP.enabled || !gP.force120Hz){ gADHzProbeDone = NO; return; }
        if (gADHzProbeDone || gADHzProbeTarget) return;
        gADHzProbeDone = YES;
        ADHzProbeTarget *p = [ADHzProbeTarget new];
        CADisplayLink *d = [CADisplayLink displayLinkWithTarget:p selector:@selector(tick:)];
        gADHzProbeTarget=p;
        [d addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    } @catch(...) { gADHzProbeTarget=nil; }
}


// ════════════════════════════════════════════════════════════════════════════════
// SURFACE 2 — NATIVE CHROME via Amazon's own dark theme (flip the Weblab gate)
// ════════════════════════════════════════════════════════════════════════════════

// Force the two computed booleans the whole native theme keys off of.
%hook ANXDarkModeServiceImpl
- (BOOL)isDarkModeExperienceEnabled { if (gP.enabled && gP.nativeTheme) return YES; return %orig;
}
- (BOOL)isDarkModeExperienceActive  { if (gP.enabled && gP.nativeTheme) return YES; return %orig;
}
- (BOOL)systemDarkModeActive        { if (gP.enabled && gP.nativeTheme) return YES; return %orig;
}
%end

// Lock the Weblab treatment for the dark experiment so every downstream consumer
// (skins, tab-bar tokens, RN appearance module) sees the app as dark-enabled.
// AMIRedstoneWeblabBridgeService is the confirmed bridge; lockWeblab:toTreatment:
// returns BOOL. We call it once the service exists; guarded and idempotent.
static void ADLockDarkWeblab(void){
    if (!gP.enabled || !gP.nativeTheme) return;
    @try {
        Class Bridge = NSClassFromString(@"AMIRedstoneWeblabBridgeService");
        if (!Bridge) return;
        SEL shared = NSSelectorFromString(@"sharedWeblabService");
        id svc = nil;
        if ([Bridge respondsToSelector:shared]) svc = ((id(*)(id,SEL))objc_msgSend)(Bridge, shared);
        if (!svc) return;
        SEL lock = NSSelectorFromString(@"lockWeblab:toTreatment:");
        if ([svc respondsToSelector:lock]){
            ((void(*)(id,SEL,id,id))objc_msgSend)(svc, lock, @AD_DARK_WEBLAB, @AD_DARK_TREATMENT);
            ADRaw("[AmazonDark] locked NAVX_DARK_MODE_IOS_1283655 -> " AD_DARK_TREATMENT);
        }
    } @catch(...) {}
}

// Push the appearance preference to dark and broadcast the change so already-rendered
// chrome re-skins. The preference persists as an NSInteger tri-state
// (0 system / 1 light / 2 dark, mirroring UIUserInterfaceStyle); we set 2 and also
// call applyPreference: if present.
static void ADForceAppearanceDark(void){
    if (!gP.enabled || !gP.nativeTheme) return;
    @try {
        Class PM = NSClassFromString(@"ANXAppearancePreferenceManager");
        if (PM){
            SEL save  = NSSelectorFromString(@"savePreference:");
            SEL apply = NSSelectorFromString(@"applyPreference:");
            if ([PM respondsToSelector:save])  ((void(*)(id,SEL,long))objc_msgSend)(PM, save, 2);
            if ([PM respondsToSelector:apply]) ((void(*)(id,SEL,long))objc_msgSend)(PM, apply, 2);
        }
        // Fire the documented notification so listeners re-render.
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"ANXAppearanceModeDidChangeNotification"
                          object:nil
                        userInfo:@{ @"darkMode": @YES }];
    } @catch(...) {}
}

// Make the trait-observer report dark so systemDarkModeActive is naturally YES even
// if the boolean hook above is bypassed by a code path that re-reads the trait.
static void ADForceWindowsDarkTrait(void){
    if (!gP.enabled || !gP.nativeTheme) return;
    if (@available(iOS 13.0, *)) {
        @try {
            for (UIScene *sc in [UIApplication sharedApplication].connectedScenes){
                if (![sc isKindOfClass:[UIWindowScene class]]) continue;
                for (UIWindow *w in ((UIWindowScene *)sc).windows)
                    w.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
            }
        } @catch(...) {}
    }
}

// ════════════════════════════════════════════════════════════════════════════════
// SURFACE 3 — NATIVE CONTENT via the Dark Reader colour engine (ADColor.m)
// ────────────────────────────────────────────────────────────────────────────────
// This is the part that makes it a *dark mode* rather than an *inversion*.
//
// We intercept each colour at the moment the app assigns it and re-map it in HSL
// space: backgrounds fall toward the dark pole, text and tints rise toward the
// light pole, borders compress toward the middle. Hue and saturation survive, so
// Amazon orange stays orange and the blue links stay blue — they just sit at a
// lightness that works on a dark surface.
//
// The critical property: a colour is a *declaration*, never a pixel. We never
// touch layer.contents, never install a CAFilter, never see a CGImage. Photos,
// product shots, customer images and app icons are therefore untouched — not
// because we detect and exempt them, but because they are not on this code path
// at all. That is the structural fix for the inverted-images bug, and it is why
// no allowlist of image classes needs maintaining ever again.
// ════════════════════════════════════════════════════════════════════════════════

// Push the current prefs into the colour engine (also clears its memo cache).
static void ADSyncColorEngine(void){
    ADThemeConfig cfg;
    cfg.brightness = (double)gP.brightness;
    cfg.contrast   = (double)gP.contrast;
    cfg.grayscale  = (double)gP.grayscale;
    cfg.sepia      = (double)gP.sepia;
    cfg.bgR = 24;  cfg.bgG = 26;  cfg.bgB = 27;
    cfg.fgR = 232; cfg.fgG = 230; cfg.fgB = 227;
    ADParseHexInto(gP.bgHex, &cfg.bgR, &cfg.bgG, &cfg.bgB);
    ADParseHexInto(gP.fgHex, &cfg.fgR, &cfg.fgG, &cfg.fgB);
    ADColorSetTheme(cfg);
}

// WebKit renders its own hierarchy and Dark Reader already owns everything inside
// it. Recolouring WK's internal views would fight the web engine and can blank the
// compositing layers, so we leave that whole subtree alone.
static inline BOOL ADIsWebKitOwned(id obj){
    if (!obj) return NO;
    const char *n = object_getClassName(obj);
    if (!n) return NO;
    if (n[0]=='W' && n[1]=='K') return YES;                 // WKWebView, WKContentView, …
    if (strncmp(n, "Web", 3) == 0) return YES;              // WebSimpleLayer, WebLayer, …
    return NO;
}
// A CALayer inside WebKit often has no delegate at all, so test the layer itself too.
static inline BOOL ADLayerIsWebKitOwned(CALayer *l){
    if (!l) return NO;
    if (ADIsWebKitOwned(l)) return YES;
    return ADIsWebKitOwned(l.delegate);
}

static inline BOOL ADRecolorOn(void){ return gP.enabled && gP.nativeRecolor; }

// ─── colours the tweak creates itself ─────────────────────────────────────────
// Anything we build from the theme is ALREADY the final on-screen value. Running it
// back through ADModifyUIColor is not idempotent: the foreground curve maps light to
// dark, so assigning our light foreground to a tint produced a DARK tint. That is
// what kept every icon dark while the sweep reported it had fixed them.
//
// ADIsModifiedUIColor could not catch this. It recognises values the transform has
// EMITTED; the theme's foreground pole (#e8e6e3) is an INPUT we supply, and the
// transform's actual output for dark text is a different value (~rgb(222,219,215)),
// so the pole never appeared in that set.
static const void *kADOwnColorKey = &kADOwnColorKey;
static inline BOOL ADIsOwnColor(UIColor *c){
    return c != nil && objc_getAssociatedObject(c, kADOwnColorKey) != nil;
}
static inline UIColor *ADMarkOwnColor(UIColor *c){
    if (c) objc_setAssociatedObject(c, kADOwnColorKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return c;
}

// A UIImage counts as template-rendered if UIKit will paint it with tintColor.
// renderingMode alone is not enough: an asset marked "Template Image" in the
// catalogue reports UIImageRenderingModeAutomatic and is resolved to template at
// draw time, so the AlwaysTemplate test walked straight past the app's own icons.
static const void *kADOrigImageKey = &kADOrigImageKey;
static UIColor *gAmazonBlue = nil;   // Amazon's own tab accent, captured live
static BOOL ADIsTabBarItemish(UIView *v);
// Walk UP. ADIsTabBarItemish names CONTAINER classes, so the image view that actually
// holds the cart glyph never matches on its own -- only an ancestor does. Declared
// here rather than next to the sweep because THREE separate paths repaint glyphs and
// all three need this gate: setImage:, setImage:forState:, and the didMoveToWindow
// catch-up. v5.21.0 gated the first two and the cart tab stayed white, because the
// third one was still repainting it.
static BOOL ADInTabBarChain(UIView *v){
    int d = 0;
    while (v && d++ < 12){ if (ADIsTabBarItemish(v)) return YES; v = v.superview; }
    return NO;
}

static BOOL ADIsChromeGlyphContext(UIView *v){
    UIView *p = v; int d = 0;
    while (p && d++ < 8){
        const char *c = object_getClassName(p);
        if (c && (strstr(c, "SearchBar")  || strstr(c, "SearchField") ||
                  strstr(c, "NavigationBar") || strstr(c, "TextField") ||
                  strstr(c, "SearchTextField")))
            return YES;
        p = p.superview;
    }
    return NO;
}
static inline BOOL ADImageIsTemplateish(UIImage *im){
    if (!im) return NO;
    if (im.renderingMode == UIImageRenderingModeAlwaysTemplate) return YES;
    if (im.renderingMode == UIImageRenderingModeAlwaysOriginal) return NO;
    CGImageRef cg = im.CGImage;
    if (cg && (CGImageIsMask(cg) || CGImageGetAlphaInfo(cg) == kCGImageAlphaOnly)) return YES;
    if (im.symbolConfiguration != nil) return YES;   // SF Symbols are always template
    return NO;
}

// ─── tab bar colouring ──────────────────────────────────────────────────────────
// The bar wants COLOUR, not our monochrome foreground: every tab in Amazon's accent
// blue, the selected one white. The generic setTintColor hook was lightening Amazon's
// blue to ~0.90 (near white), which is exactly why every tab went white. We capture
// Amazon's own accent so the shade matches, stop transforming bar tints, and colour
// each icon explicitly by selection state.
static UIColor *ADBarBlue(void){
    if (gAmazonBlue) return gAmazonBlue;
    return ADColorFromHex("#00A8E1");            // marked-own fallback
}
static UIColor *ADBarWhite(void){ return ADColorFromHex(gP.fgHex); }   // marked-own ~white
static const void *kADBarSelKey = &kADBarSelKey;
static const void *kADIndicatorKey = &kADIndicatorKey;
// React-Native glyph invert bookkeeping (used by the CALayer setFilters guard
// below and the ADInvertRNSVG helper further down).
static const void *kADRNInvertKey  = &kADRNInvertKey;
static const void *kADRNFiltersKey = &kADRNFiltersKey;
static const void *kADRNCheckKey   = &kADRNCheckKey;
static inline BOOL ADIsTaggedIndicator(UIView *v){
    return v && objc_getAssociatedObject(v, kADIndicatorKey) != nil;
}
static inline void ADTagIndicator(UIView *v){
    if (!v) return;
    objc_setAssociatedObject(v, kADIndicatorKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // The tag must ALSO live on the layer. UIView.backgroundColor forwards to
    // layer.backgroundColor as a raw CGColor, which cannot carry the own-colour
    // marker -- so the CALayer hook had no way to recognise the indicator and
    // re-darkened the white one call after the sweep set it (the tabline probe
    // read bg=0.10 at the start of every sweep for exactly this reason).
    @try { objc_setAssociatedObject(v.layer, kADIndicatorKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); } @catch(...) {}
}
static void ADRememberBarSelection(UIView *root, BOOL selected){
    if (!root) return;
    @try {
        objc_setAssociatedObject(root, kADBarSelKey, @(selected), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        for (UIView *s in root.subviews) ADRememberBarSelection(s, selected);
    } @catch(...) {}
}
// Recorded state beats a live ancestor walk: during a tap the walk can observe the
// pre-tap value and repaint blue over the white we just set.
static BOOL ADBarSelectionKnown(UIView *v, BOOL *out){
    int d = 0;
    while (v && d++ < 12){
        NSNumber *n = objc_getAssociatedObject(v, kADBarSelKey);
        if (n){ *out = n.boolValue; return YES; }
        v = v.superview;
    }
    return NO;
}
static BOOL ADViewIsSelectedInBar(UIView *v){
    int d = 0;
    while (v && d++ < 12){
        if ([v isKindOfClass:[UIControl class]] && ((UIControl *)v).selected) return YES;
        v = v.superview;
    }
    return NO;
}
static void ADTintBarIcon(UIImageView *iv, BOOL selected){
    @try {
        UIImage *img = iv.image;
        if (!img) return;
        // Templatise so the tint takes. A bitmap icon ignores tintColor, which is why
        // the dark bitmaps stayed dark; a template renders entirely in its tint.
        if (!ADImageIsTemplateish(img)){
            UIImage *tpl = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            if (tpl){ ADMarkModifiedImage(tpl); iv.image = tpl; }
        }
        UIColor *want = selected ? ADBarWhite() : ADBarBlue();
        // Idempotent: only write when it would actually change something. Each write
        // provokes another setTintColor:, so unconditional writes keep the loop alive.
        UIColor *cur = ((UIView *)iv).tintColor;
        CGFloat cr,cg,cb,ca,wr,wg,wb,wa;
        BOOL same = cur &&
            [cur getRed:&cr green:&cg blue:&cb alpha:&ca] &&
            [want getRed:&wr green:&wg blue:&wb alpha:&wa] &&
            fabs(cr-wr) < 0.01 && fabs(cg-wg) < 0.01 && fabs(cb-wb) < 0.01;
        if (!same){
            // Snap, don't fade. This write lands inside whatever animation context
            // Amazon's tab transition has open, so UIKit eased the colour change
            // over the transition's duration -- the slow blue-to-white. Disabling
            // implicit actions for this one assignment makes it take on the next
            // frame instead.
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [UIView performWithoutAnimation:^{ ((UIView *)iv).tintColor = want; }];
            [CATransaction commit];
        }
    } @catch(...) {}
}
static BOOL gBarFixPending = NO;
static BOOL gBarCorrecting  = NO;
static void ADApplyBarTint(UIView *container, BOOL selected);
static void ADCorrectBarTintsIn(UIView *v){
    if (!v) return;
    @try {
        if ([v isKindOfClass:[UIControl class]] && ADInTabBarChain(v))
            ADApplyBarTint(v, ((UIControl *)v).selected);
        for (UIView *sv in v.subviews) ADCorrectBarTintsIn(sv);
    } @catch(...) {}
}
static void ADScheduleBarCorrection(void){
    if (gBarFixPending || gBarCorrecting) return;
    gBarFixPending = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        gBarFixPending = NO;
        gBarCorrecting = YES;
        @try {
            for (UIScene *sc in [UIApplication sharedApplication].connectedScenes){
                if (![sc isKindOfClass:[UIWindowScene class]]) continue;
                for (UIWindow *w in ((UIWindowScene *)sc).windows) ADCorrectBarTintsIn(w);
            }
        } @catch(...) {}
        gBarCorrecting = NO;
    });
}
static void ADApplyBarTint(UIView *container, BOOL selected){
    if (!container) return;
    @try {
        if ([container isKindOfClass:[UIImageView class]]) ADTintBarIcon((UIImageView *)container, selected);
        for (UIView *s in container.subviews) ADApplyBarTint(s, selected);
    } @catch(...) {}
}

// ─── UIView / UILabel / controls ──────────────────────────────────────────────────
static void ADInvertRNSVG(UIView *v);

%hook UIView
- (void)didMoveToWindow {
    %orig;
    @try { if (ADRecolorOn() && self.window) ADInvertRNSVG(self); } @catch(...) {}
}
// didMoveToWindow fires BEFORE layout -- a freshly mounted icon still reads
// 0x0 there and the size gate rejects it (the gear's revert path). Layout is
// when bounds are real, and it re-runs when React patches a mounted view, so
// this is both the correct first application point and a healing pass. The
// helper's first line is a class-name strcmp, so the global cost is nil.
- (void)layoutSubviews {
    %orig;
    @try { if (ADRecolorOn() && self.window) ADInvertRNSVG(self); } @catch(...) {}
}
- (void)setBackgroundColor:(UIColor *)color {
    if (!ADRecolorOn() || !color || ADIsOwnColor(color) || ADIsWebKitOwned(self)) {
        %orig;
        return;
    }
    @try {
        // Tab selection indicator: a short thin bar inside the tab bar. Only the
        // active tab draws one, so no selection test is needed -- and the earlier
        // test was what suppressed this, since the indicator is not inside the
        // selected control's subtree. Width separates it from the 430-wide hairline.
        // Tagged by the sweep, which runs after layout. Measuring here is unreliable:
        // setBackgroundColor: often precedes layout, so bounds read 0x0 and any size
        // test fails silently -- the reason the previous attempt never took effect.
        if (ADIsTaggedIndicator(self)){
            UIColor *ind = ADBarWhite();
            %orig(ind);
            return;
        }
    } @catch(...) {}
    @try {
        // Kill translucent dark veils. A ~50%-opaque dark fill spread over a large
        // view is a scrim sitting on top of content (the home-tab overlay the probe
        // named: UIView rgba(0.09,0.10,0.11,0.50)). On a light UI it dims things a
        // little; on our now-dark UI it just muddies the product cards underneath for
        // no benefit. If a dark, half-transparent colour lands on a sizeable view,
        // drop it to clear so the themed content shows through cleanly.
        CGFloat r,g,b,a;
        if ([color getRed:&r green:&g blue:&b alpha:&a]){
            CGFloat lum = 0.2126*r + 0.7152*g + 0.0722*b;
            if (a > 0.15 && a < 0.85 && lum < 0.25 &&
                self.bounds.size.width > 120 && self.bounds.size.height > 120){
                %orig([UIColor clearColor]);
                return;
            }
        }
        UIColor *m = ADModifyUIColor(color, ADColorRoleBackground);
        if (!m) m = color;
        %orig(m);
        return;
    } @catch(...) {}
    %orig;
}
- (void)setTintColor:(UIColor *)color {
    // Tab bar FIRST, before the generic guard below. The blue/white flash was a fight:
    // we set a tab icon blue, Amazon reset its tint (often to nil -> reverts to the
    // bar's inherited near-white), our next sweep re-blued it. Overriding every
    // assignment here -- real colour, nil, or our own -- means Amazon's value never
    // lands, so there is nothing to flash against. (The old !color guard sat ABOVE
    // this and swallowed the nil case, which is why it had to move below.)
    @try {
        if (ADRecolorOn() && !ADIsWebKitOwned(self) && ADInTabBarChain(self)){
            if (color && !ADIsOwnColor(color)){
                CGFloat r,g,b,a;
                if (!gAmazonBlue && [color getRed:&r green:&g blue:&b alpha:&a]){
                    CGFloat mx = MAX(r,MAX(g,b)), mn = MIN(r,MIN(g,b));
                    if ((mx-mn) > 0.15 && b >= r*0.9)
                        gAmazonBlue = ADMarkOwnColor([UIColor colorWithRed:r green:g blue:b alpha:1.0]);
                }
            }
            if (!ADIsOwnColor(color)){
                // Resolve to a local -- Logos's %orig tokenizer rejects a nested call
                // in its arguments, which is what broke the v5.28.0 CI lint.
                BOOL sel = NO;
                if (!ADBarSelectionKnown(self, &sel)) sel = ADViewIsSelectedInBar(self);
                UIColor *want = sel ? ADBarWhite() : ADBarBlue();
                CGFloat ir,ig,ib,ia,tr2,tg2,tb2,ta2;
                BOOL alreadyWanted = color &&
                    [color getRed:&ir green:&ig blue:&ib alpha:&ia] &&
                    [want getRed:&tr2 green:&tg2 blue:&tb2 alpha:&ta2] &&
                    fabs(ir-tr2) < 0.01 && fabs(ig-tg2) < 0.01 && fabs(ib-tb2) < 0.01;
                if (alreadyWanted){
                    %orig;
                    return;
                }
                ADScheduleBarCorrection();
                %orig(want);
                return;
            }
            %orig;
            return;
        }
    } @catch(...) {}
    if (!ADRecolorOn() || !color || ADIsOwnColor(color) || ADIsWebKitOwned(self)) {
        %orig;
        return;
    }
    @try {
        UIColor *m = ADModifyUIColor(color, ADColorRoleForeground);
        if (!m) m = color;
        %orig(m);
        return;
    } @catch(...) {}
    %orig;
}
%end

%hook UILabel
- (void)setTextColor:(UIColor *)color {
    if (!ADRecolorOn() || !color || ADIsOwnColor(color)) {
        %orig;
        return;
    }
    @try {
        UIColor *m = ADModifyUIColor(color, ADColorRoleForeground);
        if (!m) m = color;
        %orig(m);
        return;
    } @catch(...) {}
    %orig;
}
%end

%hook UITextView
- (void)setTextColor:(UIColor *)color {
    if (!ADRecolorOn() || !color || ADIsOwnColor(color)) {
        %orig;
        return;
    }
    @try {
        UIColor *m = ADModifyUIColor(color, ADColorRoleForeground);
        if (!m) m = color;
        %orig(m);
        return;
    } @catch(...) {}
    %orig;
}
%end

%hook UITextField
- (void)setTextColor:(UIColor *)color {
    if (!ADRecolorOn() || !color || ADIsOwnColor(color)) {
        %orig;
        return;
    }
    @try {
        UIColor *m = ADModifyUIColor(color, ADColorRoleForeground);
        if (!m) m = color;
        %orig(m);
        return;
    } @catch(...) {}
    %orig;
}
%end

%hook UIButton
- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state {
    if (!ADRecolorOn() || !color || ADIsOwnColor(color)) {
        %orig;
        return;
    }
    @try {
        UIColor *m = ADModifyUIColor(color, ADColorRoleForeground);
        if (!m) m = color;
        %orig(m, state);
        return;
    } @catch(...) {}
    %orig;
}
%end

// ════════════════════════════════════════════════════════════════════════════════
// SURFACE 3b — REACT NATIVE TEXT (the "text is almost as dark as the background")
// ────────────────────────────────────────────────────────────────────────────────
// This is the piece v5.0.3 was missing. React Native does NOT put text in a UILabel
// with a settable textColor. RCTParagraphComponentView / RCTTextView hold an
// NSAttributedString and draw it themselves in drawRect: via
//   -drawAttributedString:paragraphAttributes:frame:drawHighlightPath:
// The colour is baked into NSForegroundColorAttributeName runs inside that string,
// so our UILabel/UITextView textColor hooks never see it. The RN background went
// dark (UIView/CALayer hooks caught it) while the dark text stayed dark — hence
// near-invisible labels on the account, cart and Alexa tabs.
//
// Fix: intercept the attributed string on its way in, walk every foreground-colour
// run, and push each through the SAME foreground curve as everything else. Text
// runs with no explicit colour default to black in RN, so a nil-colour run is
// treated as black and lifted to the light pole too.
// ════════════════════════════════════════════════════════════════════════════════

static NSAttributedString *ADRecolorAttributedString(NSAttributedString *in){
    if (!ADRecolorOn() || in.length == 0) return in;
    @try {
        NSMutableAttributedString *m = [in mutableCopy];
        NSRange full = NSMakeRange(0, m.length);
        [m enumerateAttribute:NSForegroundColorAttributeName inRange:full
                      options:0
                   usingBlock:^(id value, NSRange range, BOOL *stop){
            @try {
                UIColor *orig = [value isKindOfClass:[UIColor class]]
                                ? (UIColor *)value
                                : [UIColor blackColor];   // RN default text colour
                UIColor *mod = ADModifyUIColor(orig, ADColorRoleForeground);
                if (mod) [m addAttribute:NSForegroundColorAttributeName value:mod range:range];
            } @catch(...) {}
        }];
        return m;
    } @catch(...) { return in; }
}

// Fabric text (new architecture). Setter lives on RCTParagraphComponentView.
%hook RCTParagraphComponentView
- (void)setAttributedText:(NSAttributedString *)attributedText {
    @try {
        NSAttributedString *r = ADRecolorAttributedString(attributedText);
        %orig(r);
        return;
    } @catch(...) {}
    %orig;
}
- (void)_setAttributedString:(NSAttributedString *)attributedString {
    @try {
        NSAttributedString *r = ADRecolorAttributedString(attributedString);
        %orig(r);
        return;
    } @catch(...) {}
    %orig;
}
%end

// Paper text (old architecture) — still present in this binary.
%hook RCTTextView
- (void)setTextStorage:(NSTextStorage *)textStorage {
    @try {
        if (ADRecolorOn() && textStorage.length){
            NSRange full = NSMakeRange(0, textStorage.length);
            [textStorage enumerateAttribute:NSForegroundColorAttributeName inRange:full
                                    options:0
                                 usingBlock:^(id value, NSRange range, BOOL *stop){
                @try {
                    UIColor *orig = [value isKindOfClass:[UIColor class]]
                                    ? (UIColor *)value : [UIColor blackColor];
                    UIColor *mod = ADModifyUIColor(orig, ADColorRoleForeground);
                    if (mod) [textStorage addAttribute:NSForegroundColorAttributeName
                                                 value:mod range:range];
                } @catch(...) {}
            }];
        }
    } @catch(...) {}
    %orig;
}
%end

// Some Amazon custom labels vend an attributed string through UILabel directly.
%hook UILabel
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!ADRecolorOn() || !attributedText.length) {
        %orig;
        return;
    }
    @try {
        NSAttributedString *r = ADRecolorAttributedString(attributedText);
        %orig(r);
        return;
    } @catch(...) {}
    %orig;
}
%end

// ─── CALayer: catches React Native (Fabric sets layer colours directly) ───────────
%hook CALayer
- (void)setBackgroundColor:(CGColorRef)color {
    if (!ADRecolorOn() || !color) {
        %orig;
        return;
    }
    @try {
        if (ADLayerIsWebKitOwned(self)) {
            %orig;
            return;
        }
        // Claimed tab-bar elements (selection indicator, top hairline). Their view
        // sets a marked-own white, but the marker cannot survive the UIColor ->
        // CGColor forwarding, so without this check the hook mapped the white
        // straight back to the dark background colour.
        if (objc_getAssociatedObject(self, kADIndicatorKey)) {
            %orig;
            return;
        }
        CGColorRef m = ADModifyCGColor(color, ADColorRoleBackground);
        if (!m) m = color;
        %orig(m);
        return;
    } @catch(...) {}
    %orig;
}
- (void)setContents:(id)contents {
    @try { if(contents&&gP.enabled&&gP.whiteTame){ id d=self.delegate; if(d&&[d isKindOfClass:[UIView class]]) ADPrimeNativeWhiteTame363((UIView *)d,nil); } } @catch(...) {}
    %orig;
    if (!contents || !gP.enabled || !gP.whiteTame) return;
    @try {
        id d=self.delegate;
        if (d && [d isKindOfClass:[UIView class]]){
            UIView *v=(UIView *)d;
            if (v.window && !ADIsWebKitOwned(v)) ADApplyNativeWhiteTameView(v);
        }
    } @catch(...) {}
}
- (void)setBorderColor:(CGColorRef)color {
    if (!ADRecolorOn() || !color) {
        %orig;
        return;
    }
    @try {
        if (ADLayerIsWebKitOwned(self)) {
            %orig;
            return;
        }
        CGColorRef m = ADModifyCGColor(color, ADColorRoleBorder);
        if (!m) m = color;
        %orig(m);
        return;
    } @catch(...) {}
    %orig;
}
- (void)setFilters:(NSArray *)filters {
    @try {
        id d = self.delegate;
        if (d && [d isKindOfClass:[UIView class]] &&
            objc_getAssociatedObject(d, kADRNInvertKey)){
            NSArray *ours = objc_getAssociatedObject(d, kADRNFiltersKey);
            if (ours.count){
                BOOL has = NO;
                for (id f in (filters ?: @[])){ if ([ours containsObject:f]){ has = YES; break; } }
                if (!has){
                    NSMutableArray *m2 = [NSMutableArray arrayWithArray:(filters ?: @[])];
                    [m2 addObjectsFromArray:ours];
                    %orig(m2);
                    return;
                }
            }
        }
    } @catch(...) {}
    %orig;
}
%end

%hook CAGradientLayer
- (void)setColors:(NSArray *)colors {
    if (!ADRecolorOn() || colors.count == 0) {
        %orig;
        return;
    }
    @try {
        NSMutableArray *out = [NSMutableArray arrayWithCapacity:colors.count];
        for (id c in colors){
            CGColorRef cg = (__bridge CGColorRef)c;
            CGColorRef m  = ADModifyCGColor(cg, ADColorRoleBackground);
            [out addObject:(__bridge id)(m ? m : cg)];
        }
        %orig(out);
        return;
    } @catch(...) {}
    %orig;
}
%end

// ════════════════════════════════════════════════════════════════════════════════
// SURFACE 3e — react-native-linear-gradient (BVLinearGradientLayer)
// ────────────────────────────────────────────────────────────────────────────────
// This layer is why a region can render solid white while every hook and the probe
// swear nothing is white. It is a plain CALayer that paints its gradient in
// drawInContext: with raw CoreGraphics — so it is NOT a CAGradientLayer (the hook
// above never sees it), it has no backgroundColor (the probe prints NO-BG), and it
// never calls [UIColor setFill] (pure CGGradientRef). A white→light-grey RN
// <LinearGradient> backdrop is therefore invisible to the entire engine and renders
// as a white sheet. Its colors property is the single choke point: transform the
// stops with the background curve and the gradient darkens like any other surface,
// hue preserved for genuinely colourful brand gradients.
// ════════════════════════════════════════════════════════════════════════════════
%hook BVLinearGradientLayer
- (void)setColors:(NSArray *)colors {
    if (!ADRecolorOn() || colors.count == 0) {
        %orig;
        return;
    }
    @try {
        NSMutableArray *out = [NSMutableArray arrayWithCapacity:colors.count];
        for (id c in colors){
            if ([c isKindOfClass:[UIColor class]]){
                UIColor *m = ADModifyUIColor((UIColor *)c, ADColorRoleBackground);
                [out addObject:(m ? m : c)];
            } else if (c && CFGetTypeID((__bridge CFTypeRef)c) == CGColorGetTypeID()){
                CGColorRef m = ADModifyCGColor((__bridge CGColorRef)c, ADColorRoleBackground);
                [out addObject:(m ? (__bridge id)m : c)];
            } else {
                [out addObject:c];
            }
        }
        %orig(out);
        return;
    } @catch(...) {}
    %orig;
}
%end

// ─── system chrome that has its own switches rather than colours ───────────────────
%hook UIVisualEffectView
- (void)setEffect:(UIVisualEffect *)effect {
    if (!ADRecolorOn()) {
        %orig;
        return;
    }
    @try {
        if ([effect isKindOfClass:[UIBlurEffect class]]){
            // BAR-SIZED: no blur at all. Substituting a dark MATERIAL still leaves a
            // backdrop that samples whatever passes behind it, so the home header
            // went pale the moment a bright hero card scrolled under it -- and any
            // effect Amazon re-applied put that sampling straight back, undoing the
            // nil we set in didMoveToWindow. A flat opaque fill cannot be dragged
            // light by the content, and costs nothing per frame.
            CGFloat h = self.bounds.size.height, w = self.bounds.size.width;
            if (h > 0 && h < 160 && w > 200){
                %orig(nil);
                ((UIView *)self).backgroundColor = ADColorFromHex(gP.bgHex);
                return;
            }
            %orig([UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark]);
            return;
        }
    } @catch(...) {}
    %orig;
}
- (void)layoutSubviews {
    %orig;
    // BOUNDS ARE ONLY AUTHORITATIVE HERE. setEffect: requires h > 0 to decide a view
    // is bar-sized, but Amazon sets the effect before layout, when bounds are still
    // zero -- so that path applied a dark MATERIAL (which still samples the feed)
    // and nothing ever revisited it. The probe caught exactly that: a 119pt
    // UIVisualEffectView still holding a live UIBlurEffect.
    @try {
        if (!ADRecolorOn() || !self.window) return;
        CGFloat h = self.bounds.size.height, w = self.bounds.size.width;
        if (h <= 0 || h >= 160 || w <= 200) return;
        if (!self.effect) return;                       // already flat
        static const void *kNilled = &kNilled;
        int n = [objc_getAssociatedObject(self, kNilled) intValue];
        if (n >= 4) return;                             // bounded: cannot ping-pong
        objc_setAssociatedObject(self, kNilled, @(n + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.effect = nil;
        ((UIView *)self).backgroundColor = ADColorFromHex(gP.bgHex);
    } @catch(...) {}
}
- (void)didMoveToWindow {
    %orig;
    @try {
        // The light band behind the status bar and search field is a bar-background
        // blur whose backdrop paints its own light tint, so forcing the effect dark
        // in setEffect: is not always enough. Drop a dark fill behind the effect view
        // when it is bar-sized so the top matches the themed content below it.
        if (ADRecolorOn() && self.window && self.bounds.size.height < 160){
            ((UIView *)self).backgroundColor = ADColorFromHex(gP.bgHex);
            // OPAQUE, not a darker blur. Any UIBlurEffect samples whatever passes
            // behind it, so on the home tab a bright hero card scrolling under the
            // header drags it light no matter which "dark" material we pick -- and
            // a thicker material only costs more to composite every frame. Dropping
            // the effect makes the bar a flat fill: maximally dark, and it stops
            // re-blurring the feed on every scroll frame.
            if (self.effect) self.effect = nil;
            // This is the load-bearing path, not a backstop. initWithEffect: is
            // deliberately NOT hooked: it is an init-family method and this target
            // builds with -fobjc-arc, where Logos init hooks are fragile. Every
            // effect view that renders must enter a window, so catching it here
            // covers construction-time effects without hooking init at all.
            // Flagged so setting the effect (which triggers layout) cannot re-enter.
            static const void *kForced = &kForced;
            if (!objc_getAssociatedObject(self, kForced) &&
                [self.effect isKindOfClass:[UIBlurEffect class]]){
                objc_setAssociatedObject(self, kForced, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                self.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
            }
        }
    } @catch(...) {}
}
%end

// _UIBarBackground is the nav/search bar's own backing view; force it dark so the
// top band matches the themed content below it.
%hook _UIBarBackground
- (void)layoutSubviews {
    %orig;
    @try {
        if (gP.enabled) ((UIView *)self).backgroundColor = ADColorFromHex(gP.bgHex);
    } @catch(...) {}
}
%end

static const void *kADTWBScrollPend446 = &kADTWBScrollPend446;
%hook UIScrollView
- (void)didMoveToWindow {
    %orig;
    @try { if (ADRecolorOn() && self.window) self.indicatorStyle = UIScrollViewIndicatorStyleWhite; } @catch(...) {}
}
- (void)setContentOffset:(CGPoint)offset {
    %orig;
    @try {
        if(!gP.enabled||!gP.whiteTame||!self.window||ADIsWebKitOwned(self))return;
        if(objc_getAssociatedObject(self,kADTWBScrollPend446))return;
        objc_setAssociatedObject(self,kADTWBScrollPend446,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UIScrollView *ws=self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,300*1000000LL),dispatch_get_main_queue(),^{
            UIScrollView *ss=ws;if(!ss)return;objc_setAssociatedObject(ss,kADTWBScrollPend446,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            @try { NSMutableArray *q=[NSMutableArray arrayWithObject:ss]; for(NSUInteger i=0;i<q.count&&i<180;i++){UIView *x=q[i];if([x isKindOfClass:[UIImageView class]])ADSubscribeOverlay394(x);if(i<55){for(UIView *c in x.subviews){if(q.count<180)[q addObject:c];else break;}}} } @catch(...) {}
        });
    } @catch(...) {}
}
%end

// ════════════════════════════════════════════════════════════════════════════════
// SURFACE 4 — bottom nav toolbar chrome (the tab bar strip).
// These Amazon container views sometimes assert an opaque light backdrop AFTER our
// generic hooks run, so a plain colour swap can be overwritten. Forcing the fill in
// layoutSubviews (which re-runs on every relayout) makes it stick. Image-safe: only
// the container's own backgroundColor is touched, never any glyph/icon subview.
// ════════════════════════════════════════════════════════════════════════════════
// The tab-bar strip. Force the container dark, but NEVER recurse into its item/icon
// subviews — those are template-tinted glyphs, and repainting their backgrounds (or
// the fill landing mid-transition) is what made tabs intermittently vanish. We set
// the fill only when it is not already our colour, so a fast relayout does not keep
// re-triggering it.
static void ADForceBarDark(UIView *bar){
    if (!gP.enabled || !bar) return;
    @try {
        UIColor *want = ADColorFromHex(gP.bgHex);
        UIColor *have = bar.backgroundColor;
        CGFloat r1,g1,b1,a1,r2,g2,b2,a2;
        BOOL same = have &&
            [have getRed:&r1 green:&g1 blue:&b1 alpha:&a1] &&
            [want getRed:&r2 green:&g2 blue:&b2 alpha:&a2] &&
            fabs(r1-r2)<0.01 && fabs(g1-g2)<0.01 && fabs(b1-b2)<0.01 && fabs(a1-a2)<0.01;
        if (!same) bar.backgroundColor = want;
    } @catch(...) {}
}
%hook CXIStoreModesBottomNavToolbar
- (void)layoutSubviews {
    %orig;
    ADForceBarDark((UIView *)self);
}
%end
%hook CXIStoreModesTabBarView
- (void)layoutSubviews {
    %orig;
    ADForceBarDark((UIView *)self);
}
%end
%hook ANPRetailTabBar
- (void)layoutSubviews {
    %orig;
    ADForceBarDark((UIView *)self);
}
%end

// ════════════════════════════════════════════════════════════════════════════════
// SURFACE 3c — drawRect: painting (the gap that left whole panels white)
// ────────────────────────────────────────────────────────────────────────────────
// A view that paints itself in drawRect: never assigns a backgroundColor. It calls
// [someColor setFill] / [someColor set] and fills a rect. Nothing in the UIView or
// CALayer hooks can see that, so those panels stayed exactly as Amazon drew them —
// which is what the white "lattice" on the hamburger tab and the white boxes on the
// account tab are. Routing the paint colours through the same curve fixes the whole
// class of them at once, without naming a single Amazon class.
//
// Images are unaffected: this intercepts *fill/stroke colours*, never image drawing.
// ════════════════════════════════════════════════════════════════════════════════
%hook UIColor
- (void)set {
    if (!ADRecolorOn()) {
        %orig;
        return;
    }
    @try {
        UIColor *m = ADModifyUIColor(self, ADColorRoleAuto);
        if (m) {
            [m set];
            return;
        }
    } @catch(...) {}
    %orig;
}
- (void)setFill {
    if (!ADRecolorOn()) {
        %orig;
        return;
    }
    @try {
        UIColor *m = ADModifyUIColor(self, ADColorRoleAuto);
        if (m) {
            [m setFill];
            return;
        }
    } @catch(...) {}
    %orig;
}
- (void)setStroke {
    if (!ADRecolorOn()) {
        %orig;
        return;
    }
    @try {
        UIColor *m = ADModifyUIColor(self, ADColorRoleBorder);
        if (m) {
            [m setStroke];
            return;
        }
    } @catch(...) {}
    %orig;
}
%end

// v6.0.4: retired historical native hierarchy diagnostic probe.
// It had no theming responsibility and recursively walked windows only to log offenders.

// ════════════════════════════════════════════════════════════════════════════════
// SURFACE 3d — REACT NATIVE VIEW BACKGROUNDS
// ────────────────────────────────────────────────────────────────────────────────
// The probe proved these were unreachable: RCTScrollView and the account-menu tiles
// held pure opaque white through every sweep. Two reasons, both structural.
//
//  1. Obj-C dispatch. RCTView overrides setBackgroundColor:, so a %hook on UIView
//     is simply never consulted for it — the subclass implementation wins.
//  2. RN's override early-returns when the incoming colour isEqual: the stored one.
//
// Hooking the RN classes themselves fixes (1); the sweep now passing a transformed
// colour fixes (2). Both are needed — the hook catches live updates, the sweep
// catches anything built before we attached.
//
// Still image-safe: these set a view's own background fill, never layer.contents.
// ════════════════════════════════════════════════════════════════════════════════
%hook RCTView
- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!ADRecolorOn() || !backgroundColor) {
        %orig;
        return;
    }
    @try {
        UIColor *m = ADModifyUIColor(backgroundColor, ADColorRoleBackground);
        if (!m) m = backgroundColor;
        %orig(m);
        return;
    } @catch(...) {}
    %orig;
}
%end

%hook RCTScrollView
- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!ADRecolorOn() || !backgroundColor) {
        %orig;
        return;
    }
    @try {
        UIColor *m = ADModifyUIColor(backgroundColor, ADColorRoleBackground);
        if (!m) m = backgroundColor;
        %orig(m);
        return;
    } @catch(...) {}
    %orig;
}
%end

%hook RCTViewComponentView
- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!ADRecolorOn() || !backgroundColor) {
        %orig;
        return;
    }
    @try {
        UIColor *m = ADModifyUIColor(backgroundColor, ADColorRoleBackground);
        if (!m) m = backgroundColor;
        %orig(m);
        return;
    } @catch(...) {}
    %orig;
}
%end

// RN text colour also arrives as a discrete attribute object on the Paper path.
%hook RCTTextAttributes
- (void)setForegroundColor:(UIColor *)foregroundColor {
    if (!ADRecolorOn() || !foregroundColor) {
        %orig;
        return;
    }
    @try {
        UIColor *m = ADModifyUIColor(foregroundColor, ADColorRoleForeground);
        if (!m) m = foregroundColor;
        %orig(m);
        return;
    } @catch(...) {}
    %orig;
}
%end


// v6.0.0 compatibility guard for donor-internal UIImage writes.
static BOOL gADGlyphWriting = NO;

static BOOL ADImageMostlyLight(UIImage *img){
    @try {
        CGImageRef src = img.CGImage;
        if (!src) return NO;
        enum { W = 12, H = 12 };
        uint8_t buf[W*H*4];
        memset(buf, 0, sizeof(buf));
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGContextRef ctx = CGBitmapContextCreate(buf, W, H, 8, W*4, cs,
                            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(cs);
        if (!ctx) return NO;
        CGContextDrawImage(ctx, CGRectMake(0,0,W,H), src);
        CGContextRelease(ctx);
        long n = 0; double sum = 0;
        for (int i = 0; i < W*H; i++){
            uint8_t *px = buf + i*4;
            if (px[3] < 100) continue;
            n++; sum += (0.2126*px[0] + 0.7152*px[1] + 0.0722*px[2]) / 255.0;
        }
        if (n < (long)(W*H*0.4)) return NO;   // mostly transparent: not a white field
        return (sum / n) > 0.60;
    } @catch(...) {}
    return NO;
}

// ── NATIVE WHITE-BACKGROUND TAME (v5.362) ─────────────────────────────────────
// Context is resolved by SCREEN BANDS rather than rescanning six ancestor trees for
// every image. This fixes sibling-based sections (Subscribe & Save, Previously watched,
// Alexa) and gives Explore-more a hard exclusion band. The band map is cached briefly,
// which is substantially cheaper during scrolling.
static const void *kADWhiteTameOverlayKey = &kADWhiteTameOverlayKey;
static const void *kADWhiteTameLightKey363 = &kADWhiteTameLightKey363;
static int gADNativeTameLog = 0;
static BOOL ADWTImageLight363(UIImage *im){
    if (!im) return NO;
    @try {
        NSNumber *c=objc_getAssociatedObject(im,kADWhiteTameLightKey363);
        if (c) return c.boolValue;
        BOOL ok=ADImageMostlyLight(im);
        objc_setAssociatedObject(im,kADWhiteTameLightKey363,@(ok),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return ok;
    } @catch(...) {}
    return NO;
}

typedef struct {
    CGFloat explore, shopcat, subscribe, keep, watched, lists, how, questions,
            medical, highlights, giftcard, reviews, help, alexa, returns, related;
} ADWTBands362;
static __weak UIWindow *gADWTBandWindow362 = nil;
static CFAbsoluteTime gADWTBandTime362 = 0;
static ADWTBands362 gADWTBands362;

static NSString *ADWTViewText362(UIView *v){
    @try {
        NSString *t=v.accessibilityLabel;
        if ([v isKindOfClass:[UILabel class]]) t=((UILabel *)v).text ?: t;
        else if ([v isKindOfClass:[UIButton class]]) t=((UIButton *)v).titleLabel.text ?: t;
        else if ([v isKindOfClass:[UITextView class]]) t=((UITextView *)v).text ?: t;
        if (!t.length && [v respondsToSelector:@selector(text)]){ id x=[v performSelector:@selector(text)]; if([x isKindOfClass:[NSString class]]) t=x; }
        if (!t.length && [v respondsToSelector:@selector(attributedText)]){ id a=[v performSelector:@selector(attributedText)]; if([a isKindOfClass:[NSAttributedString class]]) t=[a string]; }
        return t ?: @"";
    } @catch(...) {}
    return @"";
}
static void ADWTBandWalk362(UIView *v, UIWindow *w, int depth, int *budget, ADWTBands362 *b){
    if (!v || !w || !b || depth>14 || !budget || (*budget)--<=0) return;
    @try {
        // v5.383: inactive RN tabs stay mounted. Do not let hidden or horizontally
        // off-screen branches overwrite Person-section heading bands. Vertical slack
        // stays generous so a heading just above/below the viewport still owns media
        // that is currently visible while scrolling.
        if(v!=w){
            if(v.hidden || v.alpha<0.01) return;
            CGRect gate=[v convertRect:v.bounds toView:w];
            if(gate.size.width>1 && gate.size.height>1){
                CGFloat ww=w.bounds.size.width, wh=w.bounds.size.height;
                if(CGRectGetMaxX(gate)<-24 || CGRectGetMinX(gate)>ww+24) return;
                if(CGRectGetMaxY(gate)<-1400 || CGRectGetMinY(gate)>wh+1400) return;
            }
        }
        NSString *lo=[[ADWTViewText362(v) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (lo.length){
            CGRect r=[v convertRect:v.bounds toView:w]; CGFloat y=CGRectGetMidY(r);
            if ([lo containsString:@"explore more for you"]) b->explore=y;
            else if ([lo containsString:@"shop by category"]) b->shopcat=y;
            else if ([lo containsString:@"subscribe & save"] || [lo containsString:@"subscribe and save"]) b->subscribe=y;
            else if ([lo containsString:@"keep shopping for"]) b->keep=y;
            else if ([lo containsString:@"shop previously watched"]) b->watched=y;
            else if ([lo containsString:@"lists and registries"] || [lo containsString:@"lists & registries"]) b->lists=y;
            else if ([lo containsString:@"how can i help"]) b->how=y;
            else if ([lo containsString:@"questions while you shop"]) b->questions=y;
            else if ([lo isEqualToString:@"medical care"]) b->medical=y;
            else if ([lo isEqualToString:@"your amazon highlights"]) b->highlights=y;
            else if ([lo containsString:@"gift card balance"]) b->giftcard=y;
            else if ([lo isEqualToString:@"your reviews"]) b->reviews=y;
            else if ([lo containsString:@"need help"]) b->help=y;
            else if ([lo containsString:@"alexa for shopping"]) b->alexa=y;
            else if ([lo isEqualToString:@"returns are easy"]) b->returns=y;
            else if ([lo containsString:@"related products"]) b->related=y;
        }
        for (UIView *sv in v.subviews) ADWTBandWalk362(sv,w,depth+1,budget,b);
    } @catch(...) {}
}
static ADWTBands362 ADWTBandsForWindow362(UIWindow *w){
    CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
    if (w && w==gADWTBandWindow362 && now-gADWTBandTime362<0.35) return gADWTBands362;
    ADWTBands362 b={-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};
    if (w){ int budget=2400; ADWTBandWalk362(w,w,0,&budget,&b); }
    gADWTBandWindow362=w; gADWTBandTime362=now; gADWTBands362=b; return b;
}
static const void *kADWTForcedImage364 = &kADWTForcedImage364;
static UIView *ADMenuRoot382(UIView *v);
static BOOL ADWTRawImageLike364(UIView *v){
    if (!v) return NO;
    const char *c=object_getClassName(v); if(!c) return NO;
    if (strstr(c,"Text")||strstr(c,"Label")||strstr(c,"Paragraph")||strstr(c,"Button")||
        strstr(c,"SVG")||strstr(c,"Icon")||strstr(c,"Shape")||strstr(c,"Gradient")) return NO;
    return YES;
}
static BOOL ADWTExploreTile363(UIView *v){
    @try {
        UIView *p=v; int up=0;
        while(p && up++<5){
            NSString *own=[[ADWTViewText362(p) lowercaseString] copy];
            if([own containsString:@"same-day"]||[own containsString:@"same day"]||[own containsString:@"pharmacy"]||[own containsString:@"prime video"]||[own containsString:@"haul"]||[own containsString:@"whole foods"]||[own isEqualToString:@"autos"]) return YES;
            NSArray *subs=p.subviews; int lim=(int)MIN((NSUInteger)16,subs.count);
            for(int i=0;i<lim;i++){ NSString *lo=[[ADWTViewText362(subs[i]) lowercaseString] copy];
                if([lo containsString:@"same-day"]||[lo containsString:@"same day"]||[lo containsString:@"pharmacy"]||[lo containsString:@"prime video"]||[lo containsString:@"haul"]||[lo containsString:@"whole foods"]||[lo isEqualToString:@"autos"]) return YES; }
            p=p.superview;
        }
    } @catch(...) {}
    return NO;
}
// Medical Care and Amazon Highlights are icon/glyph tiles, not product photos.
static BOOL ADWTNoTameGlyph367(UIView *v){
    @try {
        UIView *p=v; int up=0;
        while(p && up++<6){
            NSMutableArray *q=[NSMutableArray arrayWithObject:p]; int seen=0;
            for(NSUInteger qi=0; qi<q.count && seen++<42; qi++){
                UIView *x=q[qi];
                NSString *lo=[[[ADWTViewText362(x) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
                if([lo containsString:@"medical care"] || [lo isEqualToString:@"health ai"] ||
                   [lo containsString:@"prescriptions"] || [lo containsString:@"personal guida"] ||
                   [lo containsString:@"fast, free deliv"] || [lo containsString:@"your amazon highlights"] ||
                   [lo containsString:@"total savings"] || [lo containsString:@"sessions streamed"] ||
                   [lo containsString:@"keep streaming"] || [lo containsString:@"need help"] ||
                   [lo containsString:@"contact customer service"]) return YES;
                if(qi<12){ for(UIView *sv in x.subviews){ if(q.count<42)[q addObject:sv]; else break; } }
            }
            p=p.superview;
        }
    } @catch(...) {}
    return NO;
}
// v5.368: Highlights is a horizontally virtualized carousel. A recycled tile can be
// several sibling branches away from the heading, so text-ancestor matching alone misses
// some cells until a refresh. Resolve the nearest horizontal scroll container and inspect
// only its compact section wrapper for the heading.
static BOOL ADWTInHighlightsCarousel368(UIView *v){
    @try {
        UIView *p=v; int up=0;
        while(p && up++<10){
            if ([p isKindOfClass:[UIScrollView class]]){
                UIScrollView *sv=(UIScrollView *)p;
                CGFloat bw=sv.bounds.size.width,bh=sv.bounds.size.height;
                BOOL horiz=(bw>40&&bh>=45&&bh<=360&&sv.contentSize.width>bw*1.08);
                if(horiz){
                    UIView *z=sv.superview; int zu=0;
                    while(z && zu++<3){
                        CGFloat zh=z.bounds.size.height, zw=z.bounds.size.width;
                        if(zh>=70&&zh<=560&&zw>=120){
                            NSMutableArray *q=[NSMutableArray arrayWithObject:z]; int seen=0;
                            for(NSUInteger qi=0; qi<q.count && seen++<180; qi++){
                                UIView *x=q[qi];
                                NSString *lo=[[[ADWTViewText362(x) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
                                if([lo containsString:@"your amazon highlights"]) return YES;
                                if(qi<50){ for(UIView *c in x.subviews){ if(q.count<180)[q addObject:c]; else break; } }
                            }
                        }
                        z=z.superview;
                    }
                }
            }
            p=p.superview;
        }
    } @catch(...) {}
    return NO;
}
// v5.382: return to the v5.365 local-section model that originally fixed the
// sibling React/Fabric Person panes. Nearest compact section ownership is decisive;
// broad window headings are only a fallback. Customer Service is explicitly negative.
static int ADWTLocalSection365(UIView *v){
    @try {
        UIWindow *w=v.window; UIView *p=v; int up=0;
        while(p && up++<7){
            CGFloat h=p.bounds.size.height, ww=p.bounds.size.width;
            if(h>=40 && h<=760 && ww>=40 && (!w || ww<=w.bounds.size.width*1.25)){
                NSMutableArray *q=[NSMutableArray arrayWithObject:p]; int seen=0;
                BOOL neg=NO, reviews=NO, product=NO;
                for(NSUInteger qi=0; qi<q.count && seen++<90; qi++){
                    UIView *x=q[qi]; NSString *lo=[[ADWTViewText362(x) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if([lo containsString:@"need help"] || [lo containsString:@"contact customer service"] ||
                       [lo containsString:@"customer service"] || [lo containsString:@"medical care"] ||
                       [lo containsString:@"your amazon highlights"] || [lo containsString:@"total savings"] ||
                       [lo containsString:@"sessions streamed"]) neg=YES;
                    if([lo containsString:@"your reviews"] || [lo containsString:@"what did you think of the item"]) reviews=YES;
                    if([lo containsString:@"returns are easy"] || [lo containsString:@"send an amazon gift card"] ||
                       [lo containsString:@"shop previously watched"] || [lo containsString:@"subscribe & save"] ||
                       [lo containsString:@"subscribe and save"] || [lo hasPrefix:@"best deals on"] ||
                       [lo hasPrefix:@"keep shopping for"] || [lo containsString:@"alexa for shopping"] ||
                       [lo containsString:@"lists and registries"] || [lo containsString:@"lists & registries"]) product=YES;
                    if(qi<28){ for(UIView *sv in x.subviews){ if(q.count<90) [q addObject:sv]; else break; } }
                }
                // A compact Need-help/Customer-Service row is a hard exclusion.
                // In a broader mixed Person wrapper, the named product section wins so
                // one Customer-Service row cannot suppress Subscribe/Watched/Alexa.
                if(neg && h<=280) return 1;
                if(reviews) return 3;
                if(product) return 2;
                if(neg) return 1;
            }
            p=p.superview;
        }
    } @catch(...) {}
    return 0;
}
// v5.384: Person product panes are horizontally virtualized React sections.
// Resolve the nearest carousel from its OWN compact wrapper so first-frame image
// assignment does not wait for the window-wide heading-band cache. This is the
// bounded sibling-layout mechanism that Subscribe & Save / Keep Shopping need.
// Cache the result on the scroll view; never retain a product UIImage.
static const void *kADWTCarouselCtx384 = &kADWTCarouselCtx384;
static const void *kADWTCarouselTime384 = &kADWTCarouselTime384;
static int ADWTCarouselSection384(UIView *v){
    @try {
        if(!v || !v.window) return 0;
        UIWindow *w=v.window; UIView *p=v; int up=0;
        while(p && up++<11){
            if([p isKindOfClass:[UIScrollView class]]){
                UIScrollView *sv=(UIScrollView *)p;
                CGFloat bw=sv.bounds.size.width,bh=sv.bounds.size.height;
                CGFloat cw=sv.contentSize.width,ch=sv.contentSize.height;
                // RN often assigns the UIImage before horizontal contentSize is hydrated.
                // Treat a compact, non-vertically-scrolling UIScrollView as the carousel
                // immediately; waiting for cw>bw was the remaining first-frame flash.
                BOOL horiz=(bw>=70&&bh>=45&&bh<=380&&
                            (cw>bw*1.05 || ch<=MAX(bh*1.35,bh+40)));
                if(horiz){
                    CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
                    NSNumber *ct=objc_getAssociatedObject(sv,kADWTCarouselTime384);
                    NSNumber *cc=objc_getAssociatedObject(sv,kADWTCarouselCtx384);
                    if(ct&&cc){
                        CFAbsoluteTime age=now-ct.doubleValue; int cv=cc.intValue;
                        // Positive product ownership is section state, not image state.
                        // Hold it through React relayout/reimage churn; exclusions refresh
                        // more often, and a miss is intentionally very short-lived.
                        if((cv==2&&age<8.0)||((cv==1||cv==3)&&age<1.5)||(cv==0&&age<0.06)) return cv;
                    }
                    CGRect sr=[sv convertRect:sv.bounds toView:w];
                    int result=0; CGFloat best=CGFLOAT_MAX;
                    UIView *z=sv.superview; int zu=0;
                    while(z && z!=w && zu++<4){
                        CGFloat zh=z.bounds.size.height,zw=z.bounds.size.width;
                        if(zh>=60&&zh<=900&&zw>=80&&zw<=w.bounds.size.width*1.25){
                            NSMutableArray *q=[NSMutableArray arrayWithObject:z]; int seen=0;
                            for(NSUInteger qi=0;qi<q.count&&seen++<170;qi++){
                                UIView *x=q[qi]; if(x.hidden||x.alpha<.01)continue;
                                NSString *lo=[[ADWTViewText362(x) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                if(lo.length){
                                    int kind=0;
                                    if([lo containsString:@"medical care"]||[lo containsString:@"your amazon highlights"]||
                                       [lo containsString:@"need help"]||[lo containsString:@"contact customer service"]||
                                       [lo isEqualToString:@"customer service"]) kind=1;
                                    else if([lo containsString:@"your reviews"]||[lo containsString:@"what did you think of the item"]) kind=3;
                                    else if([lo containsString:@"subscribe & save"]||[lo containsString:@"subscribe and save"]||
                                            [lo hasPrefix:@"keep shopping for"]||[lo containsString:@"shop previously watched"]||
                                            [lo containsString:@"alexa for shopping"]||[lo hasPrefix:@"best deals on"]||
                                            [lo containsString:@"lists and registries"]||[lo containsString:@"lists & registries"]) kind=2;
                                    if(kind){
                                        CGRect lr=[x convertRect:x.bounds toView:w];
                                        CGFloat dy=fabs(CGRectGetMidY(lr)-CGRectGetMinY(sr));
                                        BOOL near=(CGRectGetMaxY(lr)>=CGRectGetMinY(sr)-300 && CGRectGetMinY(lr)<=CGRectGetMaxY(sr)+120);
                                        if(near&&dy<best){ best=dy; result=kind; }
                                    }
                                }
                                if(qi<48){for(UIView *sv2 in x.subviews){if(q.count<170)[q addObject:sv2];else break;}}
                            }
                        }
                        z=z.superview;
                    }
                    objc_setAssociatedObject(sv,kADWTCarouselCtx384,@(result),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    objc_setAssociatedObject(sv,kADWTCarouselTime384,@(now),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    return result;
                }
            }
            p=p.superview;
        }
    } @catch(...) {}
    return 0;
}

// v5.388: structural peer fallback for the two remaining native WBT misses.
// Keep Shopping is a 3-column grid and Home promo/ad carousels are compact peer
// groups. Positive ownership is sticky; a negative hydration result expires almost
// immediately so one recycled tile cannot sit bright for ~0.75s. Retain no UIImage.
static const void *kADWTPeers388 = &kADWTPeers388;
static const void *kADWTPeersTime388 = &kADWTPeersTime388;
static BOOL ADWTProductPeers388(UIView *v){
    @try {
        if(!v||!v.window||![v isKindOfClass:[UIImageView class]]) return NO;
        const char *cn=object_getClassName(v); if(!cn||!strstr(cn,"RCTUIImageView")) return NO;
        CGFloat vw=v.bounds.size.width,vh=v.bounds.size.height;
        if(vw<50||vw>190||vh<50||vh>190) return NO;
        // Hard exclusions only. Positive product/ad peer ownership intentionally wins
        // over the broad glyph-text census that was dropping one recycled tile.
        if(ADMenuRole382(v)!=0||ADWTInHighlightsCarousel368(v)||ADWTExploreTile363(v)) return NO;
        UIWindow *w=v.window; UIView *p=v.superview; int up=0;
        while(p&&p!=w&&up++<7){
            CGFloat pw=p.bounds.size.width,ph=p.bounds.size.height;
            if(pw>=190&&pw<=w.bounds.size.width*1.35&&ph>=120&&ph<=1200){
                NSString *pt=[[ADWTViewText362(p) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if([pt containsString:@"medical care"]||[pt containsString:@"your amazon highlights"]||
                   [pt containsString:@"need help"]||[pt containsString:@"contact customer service"]||
                   [pt containsString:@"your reviews"]||[pt containsString:@"what did you think of the item"]){
                    p=p.superview; continue;
                }
                CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
                NSNumber *tm=objc_getAssociatedObject(p,kADWTPeersTime388);
                NSNumber *cv=objc_getAssociatedObject(p,kADWTPeers388);
                if(tm&&cv){
                    CFAbsoluteTime age=now-tm.doubleValue;
                    if(cv.boolValue&&age<4.0) return YES;
                    // A negative result during React hydration must be almost ephemeral;
                    // the old 0.75s miss cache was the visible flash / single missing tile.
                    if(!cv.boolValue&&age<0.04){ p=p.superview; continue; }
                }
                int peers=0,tamed=0; NSMutableArray *q=[NSMutableArray arrayWithObject:p];
                for(NSUInteger qi=0;qi<q.count&&qi<150;qi++){
                    UIView *x=q[qi];
                    if(x.hidden||x.alpha<.01) continue;
                    if([x isKindOfClass:[UIImageView class]]){
                        const char *xc=object_getClassName(x);
                        CGFloat xw=x.bounds.size.width,xh=x.bounds.size.height;
                        BOOL similar=(xc&&strstr(xc,"RCTUIImageView")&&xw>=50&&xw<=190&&xh>=50&&xh<=190&&
                                      fabs(xw-vw)<=70&&fabs(xh-vh)<=90&&
                                      !ADWTInHighlightsCarousel368(x)&&ADMenuRole382(x)==0);
                        if(similar){
                            peers++;
                            if(objc_getAssociatedObject(x,kADWhiteTameOverlayKey)) tamed++;
                        }
                    }
                    if(qi<55){for(UIView *sv in x.subviews){if(q.count<150)[q addObject:sv];else break;}}
                }
                BOOL hit=(peers>=3)||(peers>=2&&tamed>=1);
                objc_setAssociatedObject(p,kADWTPeers388,@(hit),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(p,kADWTPeersTime388,@(now),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                if(hit){
                    return YES;
                }
            }
            p=p.superview;
        }
    } @catch(...) {}
    return NO;
}

// 0 normal, 1 explicit exclusion, 2 forced product-media context,
// 3 Reviews photo-only context. This restores the v5.374/365 ordering.
static int ADWTNativeContext(UIView *v){
    @try {
        UIWindow *w=v.window; if (!w) return 0;
        if(ADMenuRoot382(v)) return 1;
        CGRect vr=[v convertRect:v.bounds toView:w]; CGFloat y=CGRectGetMidY(vr);
        // Fast-path the local carousel before the window-wide heading census. This is
        // what lets ADPrimeNativeWhiteTame363 install the overlay before a new image
        // is committed instead of one layout pass later.
        int carousel=ADWTCarouselSection384(v);
        if (carousel==2) return 2;
        if (ADWTProductPeers388(v)) return 2;
        ADWTBands362 b=ADWTBandsForWindow362(w);
        int local=ADWTLocalSection365(v);
        if (b.medical>=0 && y>b.medical && (b.highlights>b.medical ? y<b.highlights : y<b.medical+520)) return 1;
        if (b.highlights>=0 && y>b.highlights && (b.giftcard>b.highlights ? y<b.giftcard : y<b.highlights+520)) return 1;
        if (b.reviews>=0 && y>b.reviews && (b.help>b.reviews ? y<b.help : y<b.reviews+900)) return 3;
        if (carousel==3 || local==3) return 3;
        if (carousel==1 || local==1) return 1;
        if (ADWTInHighlightsCarousel368(v)) return 1;
        if (ADWTExploreTile363(v)) return 1;
        if (b.explore>=0 && y>b.explore && (b.shopcat>b.explore ? y<b.shopcat : y<b.explore+720)) return 1;
        // v5.383: a positively identified product section wins before the broad
        // glyph-text exclusion. The old exclusion can see Medical/Help text through
        // a mixed React wrapper and was dropping individual Subscribe/Keep images.
        if (local==2) return 2;
        if (b.subscribe>=0 && y>b.subscribe && (b.keep>b.subscribe ? y<b.keep : y<b.subscribe+760)) return 2;
        if (b.keep>=0 && y>b.keep && (b.watched>b.keep ? y<b.watched : y<b.keep+900)) return 2;
        if (b.watched>=0 && y>b.watched && (b.lists>b.watched ? y<b.lists : y<b.watched+620)) return 2;
        if (b.returns>=0 && y>b.returns && (b.related>b.returns ? y<b.related : y<b.returns+520)) return 2;
        if (b.alexa>=0){ CGFloat aw=v.bounds.size.width,ah=v.bounds.size.height,ar=aw/MAX((CGFloat)1.0,ah); if(aw>=24&&ah>=24&&aw<=190&&ah<=190&&ar>=0.35&&ar<=2.50) return 2; }
        if (ADWTNoTameGlyph367(v)) return 1;
    } @catch(...) {}
    return 0;
}

// v5.382 crashfix: Menu ownership is queried from several hot UIImage/Fabric paths.
// The first v5.382 implementation cached only positive Menu roots, so every image on a
// NON-Menu screen (especially Person) re-walked up to 1,100 views.  Cache BOTH answers
// briefly per screen root and bound the occasional scan.  Do not persist ownership on
// reusable UIKit roots across tab transitions.
static UIView *ADMenuRoot382(UIView *v){
    @try {
        UIWindow *w=v.window; if(!w||!v) return nil;
        // v5.383: Menu ownership is CONTENT ownership only. The bottom tab bar keeps
        // the proven v5.374 chrome state machine (selected white / unselected blue).
        if(ADInTabBarChain(v)) return nil;
        CGFloat ww=w.bounds.size.width, wh=w.bounds.size.height;
        UIView *root=nil,*p=v; int up=0;
        while(p&&p!=w&&up++<18){ CGFloat pw=p.bounds.size.width,ph=p.bounds.size.height; if(pw>=ww*.78&&ph>=wh*.48){root=p;break;} p=p.superview; }
        if(!root) return nil;

        static __weak UIView *lastRoot=nil;
        static CFAbsoluteTime lastTime=0;
        static BOOL lastHit=NO;
        CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
        if(root==lastRoot && now-lastTime<0.60) return lastHit?root:nil;

        BOOL canonical=NO,sw=NO,so=NO,del=NO;
        NSMutableArray *q=[NSMutableArray arrayWithObject:root];
        for(NSUInteger qi=0;qi<q.count&&qi<700;qi++){
            UIView *x=q[qi]; if(x.hidden||x.alpha<.01)continue;
            if(x!=root){
                CGRect xr=[x convertRect:x.bounds toView:w];
                if(xr.size.width>1 && xr.size.height>1 &&
                   (CGRectGetMaxX(xr)<-24 || CGRectGetMinX(xr)>ww+24 ||
                    CGRectGetMaxY(xr)<-220 || CGRectGetMinY(xr)>wh+220)) continue;
            }
            NSString *lo=[[ADWTViewText362(x) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if([lo containsString:@"explore more for you"]||[lo containsString:@"shop by category"]) canonical=YES;
            if([lo containsString:@"switch accounts"]) sw=YES;
            if([lo isEqualToString:@"sign out"]||[lo containsString:@"sign out"]) so=YES;
            if([lo containsString:@"delivery services"]) del=YES;
            if(canonical||(sw&&(so||del))) break;
            if(qi<220){for(UIView *sv in x.subviews){if(q.count<700)[q addObject:sv];else break;}}
        }
        lastRoot=root; lastTime=now; lastHit=(canonical||(sw&&so)||(sw&&del));
        return lastHit?root:nil;
    } @catch(...) {}
    return nil;
}
// v5.384: visible Hamburger content stays Menu-owned even when its heading is
// scrolled offscreen. The selected bottom tab is a stronger source of truth than
// visible text, but the lookup is bounded + cached so we do not recreate v5.382's
// per-image whole-tree resource spike. Offscreen mounted tabs are deliberately false.
static __weak UIWindow *gADMenuActiveWindow384=nil;
static CFAbsoluteTime gADMenuActiveTime384=0;
static BOOL gADMenuActive384=NO;
static CGFloat gADMenuActiveX384=-1;
static BOOL ADHamburgerScreenActive384(UIView *v){
    @try {
        if(!v||!v.window||ADInTabBarChain(v))return NO;
        UIWindow *w=v.window; CGRect vr=[v convertRect:v.bounds toView:w];
        if(vr.size.width>1&&vr.size.height>1){
            if(CGRectGetMaxX(vr)<-18||CGRectGetMinX(vr)>w.bounds.size.width+18||
               CGRectGetMaxY(vr)<-80||CGRectGetMinY(vr)>w.bounds.size.height+120) return NO;
        }
        CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
        if(w!=gADMenuActiveWindow384||now-gADMenuActiveTime384>=0.50){
            BOOL hit=NO; CGFloat hitX=-1; int seen=0;
            NSMutableArray *q=[NSMutableArray arrayWithObject:w];
            for(NSUInteger qi=0;qi<q.count&&seen++<420;qi++){
                UIView *x=q[qi]; if(x.hidden||x.alpha<.01)continue;
                if(ADInTabBarChain(x)){
                    BOOL sel=NO,known=ADBarSelectionKnown(x,&sel);
                    if(!known&&[x isKindOfClass:[UIControl class]]) sel=((UIControl *)x).selected;
                    if(sel){
                        CGRect xr=[x convertRect:x.bounds toView:w];
                        if(xr.size.width>4&&xr.size.height>4&&CGRectGetMidY(xr)>w.bounds.size.height*.72){
                            CGFloat nx=CGRectGetMidX(xr)/MAX((CGFloat)1.0,w.bounds.size.width);
                            if(nx>=0.58&&nx<=0.82){hitX=nx;hit=YES;break;}
                            if(hitX<0)hitX=nx;
                        }
                    }
                }
                if(qi<150){for(UIView *sv in x.subviews){if(q.count<420)[q addObject:sv];else break;}}
            }
            BOOL changed=(w!=gADMenuActiveWindow384||hit!=gADMenuActive384);
            gADMenuActiveWindow384=w; gADMenuActiveTime384=now; gADMenuActive384=hit; gADMenuActiveX384=hitX;
        }
        return gADMenuActive384;
    } @catch(...) {}
    return NO;
}

// 0 not Menu, 1 Menu content artwork (leave completely stock), 2 Menu chrome
// (search magnifier/camera/mic and right-edge chevrons: allow/tint light).
static int ADMenuRole382(UIView *v){
    @try {
        // Bottom navigation is never Menu content/chrome. Let ADTintBarIcon and the
        // old tab selection machinery own it exactly as they did before v5.382.
        if(!v || ADInTabBarChain(v)) return 0;
        UIView *root=ADMenuRoot382(v); BOOL active=ADHamburgerScreenActive384(v);
        if(!root&&!active)return 0;
        if(ADIsChromeGlyphContext(v)) return 2;
        UIWindow *w=v.window; if(!w)return 1;
        CGRect r=[v convertRect:v.bounds toView:w]; CGFloat vw=r.size.width,vh=r.size.height;
        // Amazon's native row-chevron painter is a 93x44 UIImageView whose glyph is
        // right-aligned inside the hit box. v5.383's <=46 test mislabeled it content.
        if(vw<=110&&vh<=56&&CGRectGetMaxX(r)>=w.bounds.size.width-96) return 2;
        if(vw<=56&&vh<=56&&CGRectGetMidY(r)<=150) return 2;
        return 1;
    } @catch(...) {}
    return 0;
}
static BOOL ADIsHamburgerSurface380(UIView *v){ return ADMenuRoot382(v)!=nil; }

// Kept only as a diagnostic/compatibility helper. Person policy no longer depends on
// this fragile horizontal-scroll detector; the v5.365 local heading resolver owns it.
static BOOL ADWTInWatchedCarousel380(UIView *v){
    @try {
        UIView *p=v; int up=0;
        while(p&&up++<8){
            CGFloat h=p.bounds.size.height,w=p.bounds.size.width;
            if(h>=50&&h<=520&&w>=100){
                NSMutableArray *q=[NSMutableArray arrayWithObject:p];
                for(NSUInteger qi=0;qi<q.count&&qi<120;qi++){
                    UIView *x=q[qi]; NSString *lo=[[ADWTViewText362(x) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if([lo containsString:@"shop previously watched"]) return YES;
                    if(qi<36){for(UIView *sv in x.subviews){if(q.count<120)[q addObject:sv];else break;}}
                }
            }
            p=p.superview;
        }
    } @catch(...) {}
    return NO;
}

static BOOL ADIsCategoryArtwork379(UIView *v){
    @try {
        if(!v||ADInTabBarChain(v)||ADIsWebKitOwned(v))return NO;
        int mr=ADMenuRole382(v);
        if(mr==1){ CGFloat vw=v.bounds.size.width,vh=v.bounds.size.height; return vw>=20&&vh>=20&&vw<=120&&vh<=120; }
        if(mr==2)return NO;
        if(ADIsChromeGlyphContext(v))return NO;
        CGFloat vw=v.bounds.size.width,vh=v.bounds.size.height;
        if(vw>=24&&vh>=24&&vw<=110&&vh<=110&&ADWTExploreTile363(v))return YES;
    } @catch(...) {}
    return NO;
}
static void ADRestoreCategoryArtwork379(UIImageView *iv){
    @try {
        if(!iv||!iv.image)return;
        CALayer *ov=objc_getAssociatedObject(iv,kADWhiteTameOverlayKey);
        if(ov){[ov removeFromSuperlayer];objc_setAssociatedObject(iv,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
        objc_setAssociatedObject(iv,kADWTForcedImage364,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIImage *cur=iv.image,*orig=objc_getAssociatedObject(cur,kADOrigImageKey);
        BOOL changed=(orig!=nil || cur.renderingMode!=UIImageRenderingModeAlwaysOriginal);
        if(changed){
            UIImage *want=orig ?: [cur imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            if(want){ gADGlyphWriting=YES; iv.image=want; gADGlyphWriting=NO; }
            iv.tintColor=nil;
        }
    } @catch(...) {}
}

static const void *kADWTCtxUntil365 = &kADWTCtxUntil365;
static const void *kADWTCtxImage382 = &kADWTCtxImage382;
static int ADWTStableContext365(UIView *v){
    int ctx=ADWTNativeContext(v);
    @try {
        UIImage *cur=[v isKindOfClass:[UIImageView class]]?((UIImageView *)v).image:nil;
        if(ctx==1 || ctx==3){
            objc_setAssociatedObject(v,kADWTCtxUntil365,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(v,kADWTCtxImage382,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return ctx;
        }
        CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
        if(ctx==2){
            objc_setAssociatedObject(v,kADWTCtxUntil365,@(now+2.0),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            // Store only the pointer VALUE. Retaining the UIImage here pins every
            // recycled Person product bitmap until the sticky window expires and can
            // push Amazon over its per-process jetsam limit during a tab transition.
            if(cur)objc_setAssociatedObject(v,kADWTCtxImage382,@((unsigned long long)(uintptr_t)cur),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return 2;
        }
        NSNumber *until=objc_getAssociatedObject(v,kADWTCtxUntil365);
        NSNumber *held=objc_getAssociatedObject(v,kADWTCtxImage382);
        unsigned long long curToken=cur?(unsigned long long)(uintptr_t)cur:0;
        if(until&&until.doubleValue>now&&cur&&held&&held.unsignedLongLongValue==curToken)return 2;
        if(until){objc_setAssociatedObject(v,kADWTCtxUntil365,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);objc_setAssociatedObject(v,kADWTCtxImage382,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
    } @catch(...) {}
    return ctx;
}
static void ADApplyNativeWhiteTameView(UIView *v){
    @try {
        if (!v || ADIsWebKitOwned(v)) return;
        if (ADMenuRole382(v)!=0) {
            CALayer *menuOv=objc_getAssociatedObject(v,kADWhiteTameOverlayKey);
            if(menuOv){ [menuOv removeFromSuperlayer]; objc_setAssociatedObject(v,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            objc_setAssociatedObject(v,kADWTForcedImage364,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        BOOL isIV=[v isKindOfClass:[UIImageView class]];
        UIImage *ivImage=isIV ? ((UIImageView *)v).image : nil;
        BOOL hasMedia=isIV ? (ivImage!=nil) : (v.layer.contents!=nil);
        CALayer *ov=objc_getAssociatedObject(v,kADWhiteTameOverlayKey);
        if (!hasMedia || (!isIV && v.subviews.count>0) ||
            v.bounds.size.width < 28 || v.bounds.size.height < 28) {
            if (ov) { [ov removeFromSuperlayer]; objc_setAssociatedObject(v,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        int ctx=ADWTStableContext365(v);
        if (ctx==1){
            objc_setAssociatedObject(v,kADWTForcedImage364,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (ov){ [ov removeFromSuperlayer]; objc_setAssociatedObject(v,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        CGFloat tw=v.bounds.size.width, th=v.bounds.size.height;
        // v5.379: 44-64px category/shortcut artwork is chrome, not a product photo.
        // Never place the native dimming CALayer on generic small ctx=0 UIImageViews.
        // Named product sections (ctx=2) still opt in below, so Keep Shopping remains covered.
        if (ctx==0 && isIV && tw<=80 && th<=80) {
            if (ov) { [ov removeFromSuperlayer]; objc_setAssociatedObject(v,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            objc_setAssociatedObject(v,kADWTForcedImage364,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        // v5.363: White Background Taming is image-selective again. Generic native
        // UIImageViews must actually measure mostly-light; this prevents illustrated
        // Explore-more glyphs from being dimmed even if their heading band is missed.
        // Explicit product sections may opt in regardless of pixel average. Raw Fabric
        // layer.contents is allowed only in those named sections AND only for an
        // image-sized leaf. Reviews are photo-only: UIImageView thumbnails may tame,
        // while generic Fabric card containers are categorically rejected.
        // A named product section can briefly fall out of the cached screen band while
        // its scroll view is moving. Remember the exact UIImage object that was positively
        // classified; the same mounted image stays tamed instead of flashing on/off.
        UIImage *forced=objc_getAssociatedObject(v,kADWTForcedImage364);
        if (isIV && forced && forced!=ivImage){ objc_setAssociatedObject(v,kADWTForcedImage364,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); forced=nil; }
        BOOL reviewIV=(isIV && ctx==3 && ivImage && tw>=30 && th>=30 && tw<=190 && th<=190 &&
                       !ADIsChromeGlyphContext(v));
        if (isIV && (ctx==2||reviewIV) && ivImage){
            objc_setAssociatedObject(v,kADWTForcedImage364,ivImage,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            forced=ivImage;
        }
        BOOL lightIV=isIV && ADWTImageLight363(ivImage);
        BOOL stickyIV=isIV && forced==ivImage && ivImage!=nil;
        BOOL ivEligible=isIV && (ctx==2||reviewIV||lightIV||stickyIV);
        // Generic Fabric RCTView layer.contents is useful in named product sections,
        // but NEVER in Reviews: the 160x160 review card itself was being mistaken for
        // one image. Reviews are UIImageView-only.
        BOOL rawEligible=(!isIV && ctx==2 && ADWTRawImageLike364(v) && tw<=170 && th<=170);
        CGFloat minDim=(ctx==2||ctx==3||stickyIV||lightIV)?30:56;
        if (!gP.enabled || !gP.whiteTame || (!v.window && !stickyIV) || !hasMedia ||
            ADInTabBarChain(v) || (ADIsChromeGlyphContext(v) && ctx==0) || ctx==1 ||
            (!ivEligible && !rawEligible) || tw<minDim || th<minDim) {
            if (ov) { [ov removeFromSuperlayer]; objc_setAssociatedObject(v,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            return;
        }
        CGFloat a=0.50*(MAX(0,MIN(100,gP.whiteTameStrength))/100.0);
        if (!ov) {
            ov=[CALayer layer];
            ov.frame=v.bounds; ov.backgroundColor=[UIColor colorWithWhite:0 alpha:a].CGColor;
            ov.zPosition=9999; ov.name=@"AmazonDarkWhiteTame362";
            [v.layer addSublayer:ov];
            objc_setAssociatedObject(v,kADWhiteTameOverlayKey,ov,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (gADNativeTameLog++<48)
                ADLog(@"P24NATTAME[%s %.0fx%.0f alpha=%.3f ctx=%d raw=%d band=366]",
                      object_getClassName(v),v.bounds.size.width,v.bounds.size.height,a,ctx,isIV?0:1);
        } else {
            if (ov.superlayer != v.layer) [v.layer addSublayer:ov];
            ov.frame=v.bounds; ov.backgroundColor=[UIColor colorWithWhite:0 alpha:a].CGColor; ov.zPosition=9999;
        }
    } @catch(...) {}
}
static void ADPrimeNativeWhiteTame363(UIView *v, UIImage *incoming){
    @try {
        if(!v||!gP.enabled||!gP.whiteTame||!v.window||ADIsWebKitOwned(v)) return;
        if(ADMenuRole382(v)!=0){ CALayer *menuOv=objc_getAssociatedObject(v,kADWhiteTameOverlayKey); if(menuOv){[menuOv removeFromSuperlayer];objc_setAssociatedObject(v,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);} objc_setAssociatedObject(v,kADWTForcedImage364,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); return; }
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if(w<28||h<28) return;
        int ctx=ADWTStableContext365(v);
        CALayer *ov=objc_getAssociatedObject(v,kADWhiteTameOverlayKey);
        if(ctx==0 && [v isKindOfClass:[UIImageView class]] && w<=80 && h<=80){ if(ov){[ov removeFromSuperlayer];objc_setAssociatedObject(v,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);} objc_setAssociatedObject(v,kADWTForcedImage364,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); return; }
        if(ctx==1||ADWTInHighlightsCarousel368(v)||(ctx!=2&&ADWTNoTameGlyph367(v))){ if(ov){[ov removeFromSuperlayer];objc_setAssociatedObject(v,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);} objc_setAssociatedObject(v,kADWTForcedImage364,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); return; }
        BOOL review=([v isKindOfClass:[UIImageView class]] && ctx==3 && w>=30 && h>=30 && w<=190 && h<=190 && !ADIsChromeGlyphContext(v));
        BOOL light=(ctx==0&&incoming)?ADWTImageLight363(incoming):NO;
        if(!(ctx==2||review)&&!light) return;
        if((ctx==2||review)&&incoming) objc_setAssociatedObject(v,kADWTForcedImage364,incoming,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        CGFloat a=0.50*(MAX(0,MIN(100,gP.whiteTameStrength))/100.0);
        if(!ov){ov=[CALayer layer];ov.name=@"AmazonDarkWhiteTame365Prime";[v.layer addSublayer:ov];objc_setAssociatedObject(v,kADWhiteTameOverlayKey,ov,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
        else if(ov.superlayer!=v.layer)[v.layer addSublayer:ov];
        ov.frame=v.bounds;ov.backgroundColor=[UIColor colorWithWhite:0 alpha:a].CGColor;ov.zPosition=9999;
    } @catch(...) {}
}
// v5.394: surgical Person -> Subscribe & Save fallback. The exact section was
// fixed historically but has repeatedly fallen through the generic Person classifier
// during RN recycling. Keep this independent from Alexa/Hamburger/Cart ownership:
// only a product-sized UIImageView inside a compact ancestor that positively contains
// the exact Subscribe & Save heading can receive this dedicated overlay.
static const void *kADSubscribeOverlay394 = &kADSubscribeOverlay394;
static BOOL ADInSubscribeSave394(UIView *v){
    @try {
        if(!v||!v.window||ADIsWebKitOwned(v)||ADMenuRole382(v)!=0||ADInTabBarChain(v)) return NO;
        CGFloat vw=v.bounds.size.width,vh=v.bounds.size.height;
        if(vw<30||vh<30||vw>240||vh>240) return NO;
        UIWindow *w=v.window; UIView *p=v; int up=0;
        while(p&&p!=w&&up++<10){
            CGFloat pw=p.bounds.size.width,ph=p.bounds.size.height;
            if(pw>=70&&pw<=w.bounds.size.width*1.35&&ph>=55&&ph<=900){
                NSMutableArray *q=[NSMutableArray arrayWithObject:p]; int seen=0;
                for(NSUInteger qi=0;qi<q.count&&seen++<190;qi++){
                    UIView *x=q[qi]; if(x.hidden||x.alpha<.01)continue;
                    NSString *lo=[[[ADWTViewText362(x) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
                    if([lo containsString:@"subscribe & save"]||[lo containsString:@"subscribe and save"]) return YES;
                    if(qi<55){for(UIView *sv in x.subviews){if(q.count<190)[q addObject:sv];else break;}}
                }
            }
            p=p.superview;
        }
        // Sibling-tree fallback: exact screen heading plus tight vertical ownership.
        ADWTBands362 b=ADWTBandsForWindow362(w);
        if(b.subscribe>=0){
            CGRect vr=[v convertRect:v.bounds toView:w]; CGFloat y=CGRectGetMidY(vr);
            CGFloat end=CGFLOAT_MAX;
            CGFloat cand[]={b.keep,b.watched,b.lists,b.help,b.medical,b.highlights};
            for(int i=0;i<6;i++)if(cand[i]>b.subscribe&&cand[i]<end)end=cand[i];
            if(end==CGFLOAT_MAX)end=b.subscribe+700;
            if(y>=b.subscribe-120&&y<end) return YES;
        }
    } @catch(...) {}
    return NO;
}
static void ADSubscribeOverlay394(UIView *v){
    @try {
        if(!v||![v isKindOfClass:[UIImageView class]]) return;
        CALayer *forced=objc_getAssociatedObject(v,kADSubscribeOverlay394);
        BOOL hit=(gP.enabled&&gP.whiteTame&&v.window&&((UIImageView *)v).image&&ADInSubscribeSave394(v));
        CALayer *normal=objc_getAssociatedObject(v,kADWhiteTameOverlayKey);
        if(!hit||normal){
            if(forced){[forced removeFromSuperlayer];objc_setAssociatedObject(v,kADSubscribeOverlay394,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
            return;
        }
        CGFloat a=0.50*(MAX(0,MIN(100,gP.whiteTameStrength))/100.0);
        if(!forced){forced=[CALayer layer];forced.name=@"AmazonDarkSubscribe394";[v.layer addSublayer:forced];objc_setAssociatedObject(v,kADSubscribeOverlay394,forced,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
        else if(forced.superlayer!=v.layer)[v.layer addSublayer:forced];
        forced.frame=v.bounds;forced.backgroundColor=[UIColor colorWithWhite:0 alpha:a].CGColor;forced.zPosition=9999;
    } @catch(...) {}
}
static void ADApplyNativeWhiteTame(UIImageView *iv){ ADApplyNativeWhiteTameView(iv); }


// ════════════════════════════════════════════════════════════════════════════════
// SURFACE 5 — image backdrops (native half of the same idea as the web CSS above).
// ────────────────────────────────────────────────────────────────────────────────
// Setting a dark backgroundColor on an image view shows through wherever the image
// has TRANSPARENT pixels — cut-out product shots, icons, logos with alpha. It is
// completely hidden behind an opaque JPEG, so it is a no-op on ordinary photos
// rather than a risk to them.
//
// What this deliberately does NOT do: touch layer.contents or any pixel of the
// image. White baked into a JPEG stays exactly as photographed. That limitation is
// the whole reason images have survived this project intact, and it is not worth
// trading away for this.
// ════════════════════════════════════════════════════════════════════════════════
%hook UIImageView
- (void)didMoveToWindow {
    %orig;
    @try {
        if (!gP.enabled || !self.window || ADIsWebKitOwned(self)) return;
        // The tab bar owns its own colours. Both branches below repaint: the backdrop
        // drops a dark panel behind any transparent artwork, and the catch-up
        // glyphifies and re-tints. Between them that is the white cart icon and the
        // nav items that read as blank until tapped -- tapping installs the selected
        // artwork through a path that already ran before injection.
        // The dump settled the tab bar: unselected icons are dark BITMAPS (dark=1,
        // tmpl=0) rendering invisibly on the dark bar. Convert them like any glyph,
        // but skip the backdrop and the tint pin so the bar's own tint -- selected
        // blue, unselected grey -- still drives their colour.
        if (ADInTabBarChain(self)){
            ADTintBarIcon(self, ADViewIsSelectedInBar(self));
            return;                                      // bar icons are fully handled
        }

        // (1) Backdrop for TRANSPARENT images — cheap, always-on-when-enabled.
        if (gP.imageBackdrop){
            UIImage *img = self.image;
            if (img && img.CGImage){
                CGImageAlphaInfo a = CGImageGetAlphaInfo(img.CGImage);
                BOOL hasAlpha = (a == kCGImageAlphaFirst || a == kCGImageAlphaLast ||
                                 a == kCGImageAlphaPremultipliedFirst ||
                                 a == kCGImageAlphaPremultipliedLast);
                if (hasAlpha && !self.backgroundColor)
                    ((UIView *)self).backgroundColor = ADColorFromHex(gP.bgHex);
            }
        }

        // (1b) Catch-up for glyphs assigned BEFORE our hooks were installed. New
        // assignments are handled earlier and more reliably by the setImage: hook.
        {
            UIImage *tpl = ADGlyphify(self.image);
            if (tpl){
                ((UIView *)self).tintColor = ADColorFromHex(gP.fgHex);
                self.image = tpl;
            }
        }

        // (2) Corner-key white-studio backdrops in OPAQUE photos — pixel work, opt-in.
        // Off by default: it edits pixels, which everything else here avoids, and a
        // wrong key looks worse than a white card. Runs on a background queue and
        // caches per source image so each is processed at most once; if the key
        // declines (ambiguous / not white-studio) the original is kept untouched.
        ADApplyNativeWhiteTame(self);
        ADSubscribeOverlay394(self);

        if (gP.imageKeyBackground){
            UIImage *img = self.image;
            if (img && img.CGImage && !ADIsModifiedImage(img)){
                static const void *kKeyed = &kKeyed;
                if (!objc_getAssociatedObject(img, kKeyed)){
                    objc_setAssociatedObject(img, kKeyed, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    __weak UIImageView *weakSelf = self;
                    NSString *hexStr = [NSString stringWithUTF8String:gP.bgHex];
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                        @try {
                            UIImage *keyed = ADKeyWhiteBackground(img, hexStr.UTF8String);
                            if (!keyed) return;
                            ADMarkModifiedImage(keyed);
                            dispatch_async(dispatch_get_main_queue(), ^{
                                @try {
                                    UIImageView *sv = weakSelf;
                                    if (sv && sv.image == img) sv.image = keyed;   // still the same image
                                } @catch(...) {}
                            });
                        } @catch(...) {}
                    });
                }
            }
        }
    } @catch(...) {}
}
%end

// ════════════════════════════════════════════════════════════════════════════════
// SURFACE 3f — DIRECTLY-DRAWN TEXT (NSString / NSAttributedString draw APIs)
// ────────────────────────────────────────────────────────────────────────────────
// The gap left by making the drawRect: paint path one-way in v5.3.1. That change
// (light fills darken, dark fills untouched) was needed to stop an already-dark
// backdrop being flipped light — but it means dark text painted through
// [UIColor set] + drawInRect: is now left dark on a dark background, i.e. invisible.
//
// The fix is to intercept where the colour is UNAMBIGUOUSLY text rather than trying
// to guess intent from a bare fill colour. In these APIs the foreground attribute is
// text by definition, so pushing it through the foreground curve carries none of the
// risk that made the generic paint hook one-way: we can never lighten a background
// here, because a background is never drawn by drawInRect:withAttributes:.
// ════════════════════════════════════════════════════════════════════════════════

// Return a copy of `attrs` whose foreground colour has been run through the
// foreground curve. Text with no explicit colour defaults to black, which on a dark
// surface is the worst case, so that is lifted too.
static NSDictionary *ADRecolorTextAttrs(NSDictionary *attrs){
    if (!ADRecolorOn()) return attrs;
    @try {
        UIColor *fg = attrs[NSForegroundColorAttributeName];
        if (fg && ADIsModifiedUIColor(fg)) return attrs;          // already ours
        UIColor *src = [fg isKindOfClass:[UIColor class]] ? fg : [UIColor blackColor];
        UIColor *mod = ADModifyUIColor(src, ADColorRoleForeground);
        if (!mod) return attrs;
        NSMutableDictionary *m = attrs ? [attrs mutableCopy] : [NSMutableDictionary dictionary];
        m[NSForegroundColorAttributeName] = mod;
        return m;
    } @catch(...) {}
    return attrs;
}

%hook NSString
- (void)drawAtPoint:(CGPoint)point withAttributes:(NSDictionary *)attrs {
    @try {
        NSDictionary *a = ADRecolorTextAttrs(attrs);
        %orig(point, a);
        return;
    } @catch(...) {}
    %orig;
}
- (void)drawInRect:(CGRect)rect withAttributes:(NSDictionary *)attrs {
    @try {
        NSDictionary *a = ADRecolorTextAttrs(attrs);
        %orig(rect, a);
        return;
    } @catch(...) {}
    %orig;
}
- (void)drawWithRect:(CGRect)rect
             options:(NSStringDrawingOptions)options
          attributes:(NSDictionary *)attrs
             context:(NSStringDrawingContext *)context {
    @try {
        NSDictionary *a = ADRecolorTextAttrs(attrs);
        %orig(rect, options, a, context);
        return;
    } @catch(...) {}
    %orig;
}
%end

%hook NSAttributedString
- (void)drawAtPoint:(CGPoint)point {
    @try {
        NSAttributedString *r = ADRecolorAttributedString(self);
        if (r != self) {
            [r drawAtPoint:point];
            return;
        }
    } @catch(...) {}
    %orig;
}
- (void)drawInRect:(CGRect)rect {
    @try {
        NSAttributedString *r = ADRecolorAttributedString(self);
        if (r != self) {
            [r drawInRect:rect];
            return;
        }
    } @catch(...) {}
    %orig;
}
%end

// ════════════════════════════════════════════════════════════════════════════════
// SURFACE 5b — GLYPH CONVERSION AT ASSIGNMENT TIME
// ────────────────────────────────────────────────────────────────────────────────
// Converting glyphs only in didMoveToWindow was too late and too narrow. Any icon
// whose image is set AFTER the view is already on screen never got converted — the
// search magnifier once the search UI opens, the filters icon after a search, the
// recent-searches glyph, the heart on a product cell. It also caused the location
// pin to flash black: the original dark artwork was displayed first and only
// repainted when the view moved into the window.
//
// Intercepting setImage: fixes both at once. The conversion happens before the
// image is ever handed to the view, so a late assignment is caught and there is no
// intermediate frame showing the dark original.
//
// Results are cached per UIImage (checked-and-not-a-glyph is remembered too), so a
// given image is analysed at most once no matter how often it is re-assigned during
// scrolling.
static const void *kADGlyphChecked = &kADGlyphChecked;

static UIImage *ADGlyphify(UIImage *img){
    if (!gP.enabled || !gP.imageBackdrop || !img) return nil;
    @try {
        if (ADIsModifiedImage(img)) return nil;                        // already ours
        if (objc_getAssociatedObject(img, kADGlyphChecked)) return nil; // known non-glyph
        if (ADImageIsTemplateish(img)) return nil;   // already tinted, not repainted
        if (!ADIsDarkGlyph(img)){
            objc_setAssociatedObject(img, kADGlyphChecked, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return nil;
        }
        UIImage *tpl = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        if (!tpl) return nil;
        ADMarkModifiedImage(tpl);
        // Keep the original. Every gate so far has been a promise not to convert;
        // this is the ability to UNDO one, which is what the tab bar actually needs.
        objc_setAssociatedObject(tpl, kADOrigImageKey, img, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return tpl;
    } @catch(...) {}
    return nil;
}

%hook UIImageView
- (void)setImage:(UIImage *)image {
    if (gADGlyphWriting) {
        %orig;
        return;
    }
    if (!image || ADIsWebKitOwned(self)) {
        %orig;
        return;
    }
    // Detached: nothing to walk yet. Defer to didMoveToWindow, where ancestry -- and
    // therefore the tab-bar test -- is knowable.
    if (!self.superview && !self.window) {
        %orig;
        return;
    }
    @try { if (gP.whiteTame && self.window && !ADInTabBarChain(self)) ADPrimeNativeWhiteTame363(self,image); } @catch(...) {}
    @try {
        // THE tab-bar fix. The dump proved unselected tab icons are dark BITMAPS
        // going invisible on the dark bar, so we still convert them. What we must NOT
        // do is pin the tint: a converted template inherits the bar's tint, which is
        // what lets the selected state colour it blue. Pinning fg is what turned the
        // cart white -- that was the real defect behind four builds of gating, not the
        // conversion.
        if (ADInTabBarChain(self)) {
            %orig;                                       // install the artwork
            ADTintBarIcon(self, ADViewIsSelectedInBar(self));  // then templatise + colour
            return;
        }
        UIImage *tpl = ADGlyphify(image);
        if (tpl) {
            ((UIView *)self).tintColor = ADColorFromHex(gP.fgHex);
            %orig(tpl);
            if (gP.whiteTame && self.window) ADApplyNativeWhiteTame(self);
            return;
        }
    } @catch(...) {}
    %orig;
    @try { if (gP.enabled && gP.whiteTame && self.window) ADApplyNativeWhiteTame(self); } @catch(...) {}
}
%end

// v5.446: React Native image views reassert TWB during recycling/layout.
%hook RCTUIImageViewAnimated
- (void)didMoveToSuperview {
    %orig;
    @try {
        UIView *vv=(UIView *)self; ADSubscribeOverlay394(vv);
        __weak UIView *wv=vv;
        const int64_t ds394[]={80,260,700};
        for(int i=0;i<3;i++)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,ds394[i]*1000000LL),dispatch_get_main_queue(),^{UIView *x=wv;if(x)ADSubscribeOverlay394(x);});
    } @catch(...) {}
}
- (void)layoutSubviews {
    %orig;
    @try {
        UIView *vv=(UIView *)self;
        if (gP.enabled && gP.whiteTame && vv.window &&
            vv.bounds.size.width >= 24 && vv.bounds.size.height >= 24 &&
            vv.bounds.size.width <= 280 && vv.bounds.size.height <= 280)
            ADApplyNativeWhiteTameView(vv);
    } @catch(...) {}
}
%end

// Many of these glyphs are button artwork rather than plain image views — the heart,
// the filters control, the recent-search rows.
%hook UIButton
- (void)setImage:(UIImage *)image forState:(UIControlState)state {
    if (!image) {
        %orig;
        return;
    }
    if (!self.superview && !self.window) {
        %orig;
        return;
    }
    @try {
        if (ADInTabBarChain(self)) {
            %orig(image, state);
            ADApplyBarTint(self, ADViewIsSelectedInBar(self));
            return;
        }
        UIImage *tpl = ADGlyphify(image);
        if (tpl) {
            ((UIView *)self).tintColor = ADColorFromHex(gP.fgHex);
            %orig(tpl, state);
            return;
        }
    } @catch(...) {}
    %orig;
}
%end

// Selection changes after the launch timer stops, so a tap must re-colour the tab
// itself. setSelected: is the exact event; ADApplyBarTint reads the NEW value.
%hook UIControl
- (void)setSelected:(BOOL)selected {
    %orig;
    @try {
        if (ADRecolorOn() && ADInTabBarChain(self)){
            // Record first so any tint assignment triggered by this change reads the
            // NEW value rather than re-deriving a stale one.
            ADRememberBarSelection(self, selected);
            ADApplyBarTint(self, selected);
            ADScheduleBarCorrection();
        }
    } @catch(...) {}
}
// The residual lag is upstream of us: Amazon flips `selected` only partway
// through its own transition, and no amount of snap-on-assignment can beat the
// moment the assignment happens. Finger-down is the earliest truthful signal --
// paint the tapped tab white immediately and let the deferred correction pass
// re-read real state afterwards, which also cleans up a cancelled touch.
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    BOOL r = %orig;
    @try {
        if (ADRecolorOn() && ADInTabBarChain(self)){
            ADRememberBarSelection(self, YES);
            ADApplyBarTint(self, YES);
            ADScheduleBarCorrection();
        }
    } @catch(...) {}
    return r;
}
%end

// ─── catch-up sweep ───────────────────────────────────────────────────────────────
// Views built before our hooks installed (the pre-warmed gateway, the splash stack)
// already hold light colours. Re-assigning a view's own colour runs it through the
// hook once; ADModifyUIColor recognises anything it previously emitted, so a view
// that is swept twice is not darkened twice.
static BOOL ADIsTabBarItemish(UIView *v){
    const char *n = object_getClassName(v);
    if (!n) return NO;
    return (strstr(n,"BottomNav") || strstr(n,"TabBarItem") ||
            strstr(n,"TabBar") || strstr(n,"NavToolbar"));
}
// ─── React Native SVG icons (the Alexa panel) ────────────────────────────────────
// The GLYPH probe named the Alexa panel's dark icons: RNSVGSvgView -- react-native-
// svg painting vector paths straight into layer contents. No UIImageView hook, no
// web pass, no tint can reach that artwork. A Core Animation colour filter can:
// colorInvert flips the dark strokes light, hueRotate(pi) restores hue for any
// coloured artwork caught in the net -- the same invert+hue-rotate recipe Dark
// Reader uses for images, applied at the layer. Private CAFilter is resolved at
// runtime and every call is guarded, so a missing class is a silent no-op.
@interface CAFilter : NSObject
+ (id)filterWithType:(NSString *)type;
@end
static BOOL ADHasRNAncestor(UIView *v){
    UIView *p = v; int d = 0;
    while (p && d++ < 10){
        const char *pc = object_getClassName(p);
        if (pc && (strncmp(pc, "RCT", 3) == 0 || strncmp(pc, "RNS", 3) == 0)) return YES;
        p = p.superview;
    }
    return NO;
}
static void ADInvertRNSVG(UIView *v){
    @try {
        const char *cn = object_getClassName(v);
        if (!cn) return;
        CGFloat w = v.bounds.size.width, h = v.bounds.size.height;
        if (w < 6 || w > 48 || h < 6 || h > 48) return;   // icons, not illustrations
        BOOL take = (strcmp(cn, "RNSVGSvgView") == 0);    // root only; children ride along
        if (!take && [v isKindOfClass:[UILabel class]]){
            // The kebab: an RN-hosted UILabel whose dots are baked into layer
            // contents. The colour-property gate could never match -- the sweep
            // recolours textColor, so the PROPERTY reads light while the PIXELS
            // stay dark (v5.41.0 logged zero cls=UILabel for exactly this
            // reason). So judge by pixels: render the label once and ask
            // ADIsDarkGlyph. A label whose text genuinely went light fails the
            // darkness test and is left alone; capped attempts keep the render
            // cost bounded while late-drawn contents still get a look.
            if (v.layer.contents != nil && ADHasRNAncestor(v)){
                NSNumber *att = objc_getAssociatedObject(v, kADRNCheckKey);
                if (att.intValue < 4){
                    objc_setAssociatedObject(v, kADRNCheckKey, @(att.intValue + 1),
                                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    @try {
                        UIGraphicsBeginImageContextWithOptions(v.bounds.size, NO, 1);
                        [v drawViewHierarchyInRect:v.bounds afterScreenUpdates:NO];
                        UIImage *im = UIGraphicsGetImageFromCurrentImageContext();
                        UIGraphicsEndImageContext();
                        if (im && ADIsDarkGlyph(im)) take = YES;
                    } @catch(...) {}
                }
            }
        }
        if (!take) return;
        // Heal, don't just flag: React clears layer.filters when it re-renders a
        // mounted view, which is why every icon reverted to black after visiting
        // the dots menu. If our filters are gone, put them back.
        if (objc_getAssociatedObject(v, kADRNInvertKey) && v.layer.filters.count) return;
        Class F = NSClassFromString(@"CAFilter");
        if (!F) return;
        id inv = [F filterWithType:@"colorInvert"];
        if (!inv) return;
        id hue = [F filterWithType:@"hueRotate"];
        @try { [hue setValue:@(M_PI) forKey:@"inputAngle"]; } @catch(...) { hue = nil; }
        NSArray *ours = hue ? @[inv, hue] : @[inv];
        v.layer.filters = ours;
        objc_setAssociatedObject(v, kADRNFiltersKey, ours, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(v, kADRNInvertKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
}

static void ADSweepViewTree(UIView *v, int depth, BOOL inTabBar){
    if (!v || depth > 60) return;
    @try {
        if (ADIsWebKitOwned(v)) return;                 // Dark Reader's territory
        ADInvertRNSVG(v);                               // Alexa panel vector icons
        ADApplyNativeWhiteTameView(v);                   // v5.446 TWB native media
        // Was `return`, which skipped this view AND everything under it -- including
        // the background fill. That is where the grey boxes behind the nav tabs came
        // from: an unthemed light fill sitting exactly where we refused to look, and
        // appearing or not depending on whether that view happened to be installed
        // for the current tab state. Only the icon and label work needs holding back
        // here; the fill still has to be darkened like everything else.
        BOOL tabBarish = inTabBar || ADIsTabBarItemish(v);   // INHERITED, not re-derived
        if (tabBarish){
            const char *scn = object_getClassName(v);
            if (scn && strstr(scn, "BarBackgroundShadow")){
                ADTagIndicator(v);   // claim it, or the CALayer hook re-darkens the white
                ((UIView *)v).backgroundColor = ADBarWhite();   // whiten the top hairline
            }
            // Selection indicator: the short bar above the active symbol. It was being
            // logged but never recoloured, so it stayed the app's dark grey. Width is
            // what separates it from the full-width hairline -- the indicator spans one
            // tab, the separator spans the bar -- and it is only lit for the selected
            // tab so the others do not all light up.
            @try {
                CGFloat ih = v.bounds.size.height, iw = v.bounds.size.width;
                if (ih > 0 && ih < 8 && iw > 12 && iw < 160 &&
                    ![v isKindOfClass:[UIImageView class]] && ![v isKindOfClass:[UIButton class]]){
                    ADTagIndicator(v);                    // so reassignments stay white
                    ((UIView *)v).backgroundColor = ADBarWhite();
                }
            } @catch(...) {}
        }
        // Do not re-darken the tab indicator we just lit.
        BOOL isTabIndicator = NO;
        @try {
            CGFloat th = v.bounds.size.height, tw = v.bounds.size.width;
            isTabIndicator = (tabBarish && th > 0 && th < 8 && tw > 12 && tw < 160 &&
                              ![v isKindOfClass:[UIImageView class]] &&
                              ![v isKindOfClass:[UIButton class]]);
        } @catch(...) {}
        UIColor *bg = v.backgroundColor;
        if (!isTabIndicator && bg && !ADIsOwnColor(bg) && !ADIsModifiedUIColor(bg)) {
            // Assign the TRANSFORMED colour, never the same object back.
            //
            // The old code did `v.backgroundColor = bg` and relied on our UIView hook
            // to convert it in flight. That fails twice over on React Native views:
            // RCTView overrides setBackgroundColor: (so the UIView hook never runs for
            // it), and its override early-returns when the new value isEqual: the one
            // it already holds — so handing back the identical object was a guaranteed
            // no-op. That is why RCTScrollView and the four 94x39 account-menu tiles
            // stayed pure white through every sweep.
            //
            // Passing a genuinely different colour object satisfies the equality check
            // and works regardless of whether a subclass overrides the setter.
            UIColor *m = ADModifyUIColor(bg, ADColorRoleBackground);
            if (m) v.backgroundColor = m;
        }
        // GLYPH RESCUE. Our setImage: hooks only fire when the app calls that setter.
        // An icon supplied through UIButtonConfiguration (iOS 15+), set during init,
        // or assigned before injection never triggers them and stays black. Reading
        // the CURRENT image here catches it regardless of how it got there — measured
        // on device, the search-pane X and history glyphs were still near-black under
        // v5.14.0, which means no setter path reached them. ADGlyphify caches both
        // outcomes, so a view swept repeatedly costs a dictionary lookup.
        if ([v isKindOfClass:[UIImageView class]]){
            @try {
                UIImageView *iv = (UIImageView *)v;
                if (tabBarish){
                    ADTintBarIcon(iv, ADViewIsSelectedInBar(iv));
                } else {
                if (iv.image && ADImageIsTemplateish(iv.image)){
                    UIColor *tint = iv.tintColor;
                    CGFloat tr,tg,tb,ta;
                    if (tint && [tint getRed:&tr green:&tg blue:&tb alpha:&ta] &&
                        (0.2126*tr + 0.7152*tg + 0.0722*tb) < 0.45 && !tabBarish){
                        ((UIView *)iv).tintColor = ADColorFromHex(gP.fgHex);
                    }
                }
                UIImage *tpl = ADGlyphify(((UIImageView *)v).image);
                if (tpl){
                    ((UIView *)v).tintColor = ADColorFromHex(gP.fgHex);
                    ((UIImageView *)v).image = tpl;
                }
                }
            } @catch(...) {}
        } else if ([v isKindOfClass:[UIButton class]]){
            @try {
                UIButton *b = (UIButton *)v;
                if (tabBarish){ ADApplyBarTint(b, ADViewIsSelectedInBar(b)); }
                else {
                UIImage *cur = b.currentImage;
                if (cur && ADImageIsTemplateish(cur)){
                    UIColor *tint = b.tintColor;
                    CGFloat tr,tg,tb,ta;
                    if (tint && [tint getRed:&tr green:&tg blue:&tb alpha:&ta] &&
                        (0.2126*tr + 0.7152*tg + 0.0722*tb) < 0.45 && !tabBarish){
                        ((UIView *)b).tintColor = ADColorFromHex(gP.fgHex);
                    }
                }
                UIImage *tpl = ADGlyphify(cur);
                if (tpl){
                    ((UIView *)b).tintColor = ADColorFromHex(gP.fgHex);
                    [b setImage:tpl forState:UIControlStateNormal];
                }
                }
            } @catch(...) {}
        }

        if (!tabBarish && [v isKindOfClass:[UILabel class]]){
            UILabel *l = (UILabel *)v;
            UIColor *tc = l.textColor;
            if (tc && !ADIsModifiedUIColor(tc)) {
                UIColor *mt = ADModifyUIColor(tc, ADColorRoleForeground);
                if (mt) { l.textColor = mt; }
            }
        } else if ([v respondsToSelector:@selector(textColor)] &&
                   [v respondsToSelector:@selector(setTextColor:)]) {
            // Any other view exposing textColor — UITextView/UITextField and Amazon's
            // own label subclasses. Needed because our setter hooks only fire when the
            // app ASSIGNS a colour: a label that never sets one and inherits the
            // default black is never intercepted, so the sweep is its only chance.
            // Measured on device: 'Search with photo' was sitting at pure rgb(0,0,0).
            @try {
                UIColor *tc = [(id)v textColor];
                if (tc && !ADIsModifiedUIColor(tc)){
                    UIColor *mt = ADModifyUIColor(tc, ADColorRoleForeground);
                    if (mt) [(id)v setTextColor:mt];
                }
            } @catch(...) {}
        }
        if (!tabBarish && [v isKindOfClass:[UIButton class]]){
            // Button titles follow the same rule, and a button whose title colour was
            // never explicitly set is exactly the case the setTitleColor: hook cannot see.
            @try {
                UIButton *b = (UIButton *)v;
                UIColor *tc = b.titleLabel.textColor;
                if (tc && !ADIsModifiedUIColor(tc)){
                    UIColor *mt = ADModifyUIColor(tc, ADColorRoleForeground);
                    if (mt) [b setTitleColor:mt forState:UIControlStateNormal];
                }
            } @catch(...) {}
        }
        for (UIView *s in v.subviews) ADSweepViewTree(s, depth + 1, tabBarish);
    } @catch(...) {}
}
// ─── sweep a cell as it comes into view ───────────────────────────────────────────
// The launch timer stops after ~40s by design, so content built later is only
// corrected when some unrelated event happens to fire a sweep. That is the "dark at
// first, correct once you have been scrolling a while" lag on the home feed: the
// transform is right, it is just arriving late.
//
// didMoveToWindow is the wrong moment -- a REUSED cell never leaves the window, so
// it would fire on first appearance and never again, which is exactly the scrolling
// case we need. layoutSubviews fires after the cell is reconfigured, so the colours
// we are about to read are the final ones. Guarded by a per-reuse flag cleared in
// prepareForReuse, so each cell is swept once per reuse cycle rather than on every
// layout pass.
static const void *kADCellSwept = &kADCellSwept;

%hook UICollectionViewCell
- (void)prepareForReuse {
    %orig;
    objc_setAssociatedObject(self, kADCellSwept, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)layoutSubviews {
    %orig;
    @try {
        if (!ADRecolorOn() || !self.window) return;
        if (objc_getAssociatedObject(self, kADCellSwept)) return;
        objc_setAssociatedObject(self, kADCellSwept, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // Seed from real ancestry. Passing NO restarted the walk mid-tree with the
        // inherited flag cleared, so a tab bar built out of collection view cells had
        // its whole subtree treated as ordinary content -- undoing the v5.19.1 fix
        // for exactly the views it was meant to protect.
        ADSweepViewTree(self, 0, ADInTabBarChain(self));
    } @catch(...) {}
}
%end

%hook UITableViewCell
- (void)prepareForReuse {
    %orig;
    objc_setAssociatedObject(self, kADCellSwept, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)layoutSubviews {
    %orig;
    @try {
        if (!ADRecolorOn() || !self.window) return;
        if (objc_getAssociatedObject(self, kADCellSwept)) return;
        objc_setAssociatedObject(self, kADCellSwept, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADSweepViewTree(self, 0, ADInTabBarChain(self));
    } @catch(...) {}
}
%end

static void ADSweepAllWindows(void){
    if (!ADRecolorOn()) return;
    @try {
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes){
            if (![sc isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)sc).windows) ADSweepViewTree(w, 0, NO);
        }
    } @catch(...) {}
}

// ════════════════════════════════════════════════════════════════════════════════
// Splash: while Dark Reader / native theme spin up, keep the launch screen dark so
// there is no white flash. Set the splash VC's own view backgroundColor (no invert).
// ════════════════════════════════════════════════════════════════════════════════
static UIColor *ADColorFromHex(const char *hex){
    unsigned int r=24,g=26,b=27;
    if (hex && hex[0]=='#') sscanf(hex+1, "%02x%02x%02x", &r,&g,&b);
    // Marked as ours: this is a finished theme colour, not an app colour awaiting
    // transformation. Without the mark, handing it to tintColor ran it through the
    // foreground curve and came back dark.
    return ADMarkOwnColor([UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0]);
}
static void ADDarkenSplash(UIViewController *vc){
    if (!gP.enabled) return;
    @try { UIView *v = vc.view; if (v) v.backgroundColor = ADColorFromHex(gP.bgHex); } @catch(...) {}
}
%hook AXUSplashScreenViewController
- (void)viewDidLayoutSubviews {
    %orig;
    ADDarkenSplash(self);
}
- (void)viewDidAppear:(BOOL)a {
    %orig;
    ADDarkenSplash(self);
}
%end
%hook TezBaseSplashScreenViewController
- (void)viewDidLayoutSubviews {
    %orig;
    ADDarkenSplash(self);
}
- (void)viewDidAppear:(BOOL)a {
    %orig;
    ADDarkenSplash(self);
}
%end

// ════════════════════════════════════════════════════════════════════════════════
// Periodic re-apply. Web tabs re-render their DOM on back-navigation / pull-to-refresh
// and can drop Dark Reader; re-enabling is idempotent. Native theme re-broadcast is
// cheap. Timer self-reschedules with a gentle cadence.
// ════════════════════════════════════════════════════════════════════════════════
static void ADSweep(void){
    ADForceWindowsDarkTrait();
    ADInjectAllWebViews();
    ADSweepAllWindows();
}

// ─── bounded launch recovery is scheduled once from %ctor (v6.0.7) ────────────
// There is deliberately no second recursive sweep timer. New views are handled by
// event-driven WKWebView, screen, and reusable-cell hooks below.

// ─── event-driven re-theme on tab / screen change (kills the white flash) ──────────
// The flashing you saw is a NEW web view being mounted for the tab you switch to:
// for a few frames it shows its own white page before Dark Reader paints the DOM,
// and if the launch timer had already stopped, nothing re-applied. Rather than run
// a forever-timer, we re-theme exactly when the view hierarchy changes. A short
// coalesced burst (0 / 60 / 200 / 500 ms) covers the mount-to-first-paint window
// without a standing cost.
static uint32_t gADBurstGeneration = 0;
static void ADReapplyBurst(void){
    const uint32_t gen = ++gADBurstGeneration;
    static const int64_t delays_ms[] = {0, 120, 420};
    for (int i = 0; i < 3; i++){
        const int pass = i;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delays_ms[i]*1000000LL),
            dispatch_get_main_queue(), ^{ @try {
                if (gen != gADBurstGeneration) return;
                ADForceWindowsDarkTrait();
                ADInjectAllWebViews();
                if (pass != 1) ADSweepAllWindows();
            } @catch(...) {} });
    }
}

// ─── v5.446 status bar direct port ───────────────────────────────────────────
// Amazon/RN subclasses frequently override preferredStatusBarStyle themselves.
// Claim the actual deciding implementation once per class so dark chrome always
// keeps light status-bar content. The class cache avoids repeated method-list walks.
static NSMutableDictionary *gSBOrig = nil;
static NSMutableSet *gSBSeen = nil;
static UIStatusBarStyle ADSBStyleImp(id self, SEL _cmd){
    if (gP.enabled) return UIStatusBarStyleLightContent;
    @try {
        Class c = object_getClass(self);
        while (c){
            NSNumber *v = gSBOrig[NSStringFromClass(c)];
            if (v){
                IMP orig = (IMP)(uintptr_t)[v unsignedLongLongValue];
                UIStatusBarStyle (*fn)(id, SEL) = (UIStatusBarStyle (*)(id, SEL))orig;
                if (fn) return fn(self, _cmd);
            }
            c = class_getSuperclass(c);
        }
    } @catch(...) {}
    return UIStatusBarStyleDefault;
}
static void ADClaimStatusBarFor(Class c){
    @try {
        SEL sel = @selector(preferredStatusBarStyle);
        Class base = [UIViewController class];
        if (!gSBOrig) gSBOrig = [NSMutableDictionary dictionary];
        if (!gSBSeen) gSBSeen = [NSMutableSet set];
        if (!c) return;
        NSString *seenKey = NSStringFromClass(c);
        if ([gSBSeen containsObject:seenKey]) return;
        [gSBSeen addObject:seenKey];
        while (c && c != base){
            unsigned int n = 0;
            Method *ms = class_copyMethodList(c, &n);
            BOOL here = NO;
            for (unsigned i = 0; i < n; i++){
                if (method_getName(ms[i]) != sel) continue;
                here = YES;
                NSString *key = NSStringFromClass(c);
                if (!gSBOrig[key]){
                    IMP orig = method_getImplementation(ms[i]);
                    gSBOrig[key] = @((unsigned long long)(uintptr_t)orig);
                    method_setImplementation(ms[i], (IMP)ADSBStyleImp);
                }
                break;
            }
            free(ms);
            if (here) break;
            c = class_getSuperclass(c);
        }
    } @catch(...) {}
}

// UIViewController appearance is the most reliable, arch-agnostic signal for a tab
// switch or push. Gate to controllers that actually host content so we do not fire
// the burst for every cell-sized child VC.
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    @try {
        if (!ADRecolorOn()) return;
        if (self.view.window && self.view.bounds.size.width > 200){
            ADClaimStatusBarFor(object_getClass(self));
            for (UIViewController *ch in self.childViewControllers)
                ADClaimStatusBarFor(object_getClass(ch));
            ADReapplyBurst();
        }
    } @catch(...) {}
}
- (UIStatusBarStyle)preferredStatusBarStyle {
    if (gP.enabled) return UIStatusBarStyleLightContent;
    return %orig;
}
%end

// React Native's StatusBar module can bypass view-controller style queries and
// set the legacy UIApplication status-bar style directly. v5.446 forced that path
// to light content as well.
%hook UIApplication
- (void)setStatusBarStyle:(UIStatusBarStyle)style {
    if (gP.enabled && style != UIStatusBarStyleLightContent){
        %orig(UIStatusBarStyleLightContent);
        return;
    }
    %orig;
}
- (void)setStatusBarStyle:(UIStatusBarStyle)style animated:(BOOL)animated {
    if (gP.enabled && style != UIStatusBarStyleLightContent){
        %orig(UIStatusBarStyleLightContent, animated);
        return;
    }
    %orig;
}
%end


// ── v5.446 SpringBoard-cover ready signal ───────────────────────────────────
static double gADT0 = 0;
static inline double ADUptime(void){
    double now = CFAbsoluteTimeGetCurrent();
    if (gADT0 == 0) gADT0 = now;
    return now - gADT0;
}

static void ADDarkScan(UIView *v, int depth, CGFloat *bestArea, CGFloat *bestLum){
    if (!v || depth > 8 || v.hidden || v.alpha < 0.5) return;
    @try {
        CGFloat a = v.bounds.size.width * v.bounds.size.height;
        UIColor *c = v.backgroundColor;
        CGFloat r, g, b, al;
        if (c && a > *bestArea && [c getRed:&r green:&g blue:&b alpha:&al] && al > 0.9){
            *bestArea = a;
            *bestLum  = 0.2126*r + 0.7152*g + 0.0722*b;
        }
        for (UIView *sv in v.subviews) ADDarkScan(sv, depth + 1, bestArea, bestLum);
    } @catch(...) {}
}

static BOOL ADScreenLooksDark(void){
    @try {
        UIWindow *key = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows)
            if (w && !w.hidden && w.alpha > 0.05){ key = w; break; }
        if (!key) return NO;
        CGFloat area = 0, lum = -1;
        ADDarkScan(key, 0, &area, &lum);
        if (lum < 0) return NO;                      // nothing opaque yet: not ready
        CGFloat screen = key.bounds.size.width * key.bounds.size.height;
        if (area < screen * 0.30) return NO;         // too small to be the backdrop
        return lum < 0.35;
    } @catch(...) {}
    return NO;
}

static void ADPostAppReady(void){
    static BOOL posted = NO;
    static int waits = 0;
    if (posted) return;
    // ABSOLUTE deadline, not a retry budget. The callers fire at wildly different
    // times -- 0.25s, 0.35s, a 60-tick timer, and a 9s backstop -- so a countdown
    // starting from "whenever we were first called" could push the signal past any
    // cover cap. On this device the trigger landed at t=5.6s; a 4.9s budget from
    // there would have signalled at 10.5s, long after the cover had gone.
    if (!ADScreenLooksDark() && ADUptime() < 7.5){
        waits++;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ ADPostAppReady(); });
        return;
    }
    posted = YES;
    notify_post("com.colindavidr.amazondark.ready");
    ADLog(@"appready posted t=%.1f dark=%d waits=%d",
          ADUptime(), ADScreenLooksDark() ? 1 : 0, waits);
}

static void ADPreDarken(WKWebView *wv){
    @try {
        if (![NSThread isMainThread]) return;
        [wv evaluateJavaScript:
            @"try{if(!document.getElementById('adpre')){var s=document.createElement('style');"
             "s.id='adpre';s.textContent='html,body{background:#181a1b !important}';"
             "(document.documentElement||document).appendChild(s);}}catch(e){}"
             completionHandler:nil];
    } @catch(...) {}
}

// ─── live settings reload ─────────────────────────────────────────────────────────
// ADRootListController posts this Darwin notification on every toggle. Without an
// observer the setting sat in the plist and did nothing until the app was killed,
// which made the whole Settings pane look broken.
//
// Caveat worth knowing: web surfaces re-theme exactly, because DarkReader.enable()
// recomputes from the untouched DOM. Native views cannot — the original colour is
// gone once replaced, so re-running the transform over already-themed views drifts
// slightly (it converges, it does not blow up). A relaunch gives an exact result.
static void ADPrefsChanged(CFNotificationCenterRef center, void *observer,
                           CFStringRef name, const void *object,
                           CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            ADLoadPrefs();              // also re-syncs + clears the colour cache
            ADStartHzVerification();
            ADRaw("[AmazonDark] prefs reloaded (Darwin notification)");
            ADForceWindowsDarkTrait();
            ADInjectAllWebViews();      // exact re-theme on web
            ADSweepAllWindows();        // best-effort re-theme on native
        } @catch(...) {}
    });
}

// Foreground: a backgrounded app can be re-laid-out by the system, and web tabs may
// have been reclaimed. One sweep on return is far cheaper than a forever-timer.
static void ADAppForegrounded(CFNotificationCenterRef center, void *observer,
                              CFStringRef name, const void *object,
                              CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{ @try { ADSweep(); } @catch(...) {} });
}

// ─── %ctor : Obj-C-free. Process guard + open log + %init + schedule real work. ────
%ctor {
    if (strcmp(__progname, "Amazon") != 0) return;   // belt (plist filter is the braces)
    ADOpenLog();
    ADRaw("[AmazonDark] " AD_VERSION " init (DarkReader web + native colour engine)");
    // v5.446 direct-port: drop cached light launch snapshots.
    @try {
        NSString *lib = [NSSearchPathForDirectoriesInDomains(
                            NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
        NSString *snap = [lib stringByAppendingPathComponent:@"SplashBoard/Snapshots"];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *kids = [fm contentsOfDirectoryAtPath:snap error:nil];
        NSUInteger killed = 0;
        for (NSString *k in kids){
            NSString *sub = [snap stringByAppendingPathComponent:k];
            for (NSString *f in [fm contentsOfDirectoryAtPath:sub error:nil]){
                if ([fm removeItemAtPath:[sub stringByAppendingPathComponent:f] error:nil]) killed++;
            }
        }
        if (kids.count) ADLog(@"splashsnap cleared %lu file(s)", (unsigned long)killed);
    } @catch(...) {}
    // v5.446 direct-port activation fallback for native-only cold paths.
    @try {
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *n){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(9.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ ADPostAppReady(); });
        }];
    } @catch(...) {}
    %init;
    ADRaw("[AmazonDark] hooks registered");
    {
        const char *names[] = {"RCTParagraphComponentView","RCTTextView","RCTViewComponentView",
                               "RCTScrollView","RCTTextAttributes",
                               "CXIStoreModesBottomNavToolbar","CXIStoreModesTabBarView",
                               "ANPRetailTabBar","ANXDarkModeServiceImpl"};
        for (unsigned i = 0; i < sizeof(names)/sizeof(names[0]); i++){
            char buf[160];
            snprintf(buf, sizeof(buf), "[AmazonDark] class %s: %s",
                     names[i], objc_getClass(names[i]) ? "FOUND" : "MISSING (hook inert)");
            ADRaw(buf);
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        ADLoadPrefs();
        ADStartHzVerification();
        ADLockDarkWeblab();
        ADForceAppearanceDark();
        ADForceWindowsDarkTrait();
        ADInjectAllWebViews();
        ADSweepAllWindows();
    });
    // One bounded launch-recovery schedule. v6.0.6 ran this geometric series plus
    // a second recursive 2-second timer, causing ~16 overlapping full sweeps. Six
    // strategically spaced passes cover late services/web views; event-driven hooks
    // own everything after 9 seconds.
    static const double adLaunchPasses607[] = {0.20, 0.60, 1.30, 2.80, 5.50, 9.00};
    for (unsigned i = 0; i < sizeof(adLaunchPasses607)/sizeof(adLaunchPasses607[0]); i++){
        double d = adLaunchPasses607[i];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(d*NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
                ADLockDarkWeblab();
                ADForceAppearanceDark();
                ADSweep();
            });
    }
    // Live settings reload + foreground re-apply.
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, ADPrefsChanged,
        CFSTR("com.colindavidr.amazondark/prefs-changed"),
        NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(),
        NULL, ADAppForegrounded,
        (__bridge CFStringRef)UIApplicationWillEnterForegroundNotification,
        NULL, CFNotificationSuspensionBehaviorCoalesce);

}

#pragma clang diagnostic pop
