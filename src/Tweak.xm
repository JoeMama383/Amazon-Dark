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
#define AD_VERSION "v5.365.0"

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
// Logging (file-based, sandbox-safe). Raw writes only from ctor; Obj-C-free.
// ─────────────────────────────────────────────────────────────────────────────────
static int gFD = -1;
static void ADOpenLog(void){
    const char *t = getenv("TMPDIR");
    char p[2048];
    if (t && *t) snprintf(p, sizeof(p), "%sAmazonDark.log", t);   // TMPDIR ends with '/'
    else         strncpy(p, "/tmp/AmazonDark.log", sizeof(p));
    gFD = open(p, O_WRONLY | O_CREAT | O_TRUNC, 0644);
}
static void ADRaw(const char *s){ if (gFD >= 0){ write(gFD, s, strlen(s)); write(gFD, "\n", 1); } }

// Formatted logging. Safe after launch (Obj-C available); never called from %ctor.
static void ADLog(NSString *fmt, ...) NS_FORMAT_FUNCTION(1,2);
static void ADLog(NSString *fmt, ...){
    @try {
        va_list ap; va_start(ap, fmt);
        NSString *m = [[NSString alloc] initWithFormat:fmt arguments:ap];
        va_end(ap);
        ADRaw([[@"[AmazonDark] " stringByAppendingString:m] UTF8String]);
    } @catch(...) {}
}

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
    BOOL  whiteTame;          // clamp blown-out studio backgrounds in photos
    BOOL  force120Hz;         // request 120Hz ProMotion when hardware/OS permits
    long  whiteTameStrength;  // 0-100: how far the highlight ceiling drops
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
static UIImage *ADGlyphifyForView(UIImage *img, UIView *v);
static BOOL ADIsChromeGlyphContext(UIView *v);
static void ADRunProbe(void);
static void ADApplyNativeWhiteTameView(UIView *v);
static void ADPrimeNativeWhiteTame363(UIView *v, UIImage *incoming);
static void ADSubscribeOverlay394(UIView *v);
static BOOL ADImageMostlyLight(UIImage *img);
static BOOL ADIsCategoryArtwork379(UIView *v);
static void ADRestoreCategoryArtwork379(UIImageView *iv);
static BOOL ADIsHamburgerSurface380(UIView *v);
static int ADMenuRole382(UIView *v);
static BOOL ADWTInWatchedCarousel380(UIView *v);
// Forward declarations required by the early Menu glyph gate (v5.382 lint/compile fix).
static inline BOOL ADImageIsTemplateish(UIImage *im);
static const void *kADOrigImageKey = &kADOrigImageKey;

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

static void ADLoadPrefs(void);
static BOOL gPrefsLoadedOnce = NO;
static NSString *gADBootCache = nil;   // rebuilt only when prefs change; ALL access via ADBootQueue
static dispatch_queue_t ADBootQueue(void);
static inline void ADEnsurePrefs(void){
    if (gPrefsLoadedOnce) return;
    if ([NSThread isMainThread]){ ADLoadPrefs(); return; }
    dispatch_async(dispatch_get_main_queue(), ^{ if (!gPrefsLoadedOnce) ADLoadPrefs(); });
}
static void ADLoadPrefs(void){
    gPrefsLoadedOnce = YES;
    dispatch_async(ADBootQueue(), ^{ gADBootCache = nil; });   // serialized invalidation
    // Defaults: everything a "true dark mode" wants, image inversion OFF.
    gP.enabled = YES; gP.webDarkReader = YES; gP.nativeTheme = YES;
    gP.imageBackdrop = YES;
    gP.whiteTame = NO;                 // opt-in: it is the one feature that touches photos
    gP.force120Hz = NO;                 // opt-in: OS may still cap for LPM/thermal/display
    gP.whiteTameStrength = 45;
    gP.imageKeyBackground = NO;
    gP.nativeRecolor = YES;
    gP.brightness = 100; gP.contrast = 100; gP.sepia = 0; gP.grayscale = 0;
    strcpy(gP.bgHex, "#181a1b"); strcpy(gP.fgHex, "#e8e6e3");
    // Declared at function scope: the log below sits outside the @try, and in
    // v5.65.0 these lived inside it, which would not compile.
    const char *srcPath = "(defaults only)";
    unsigned long nKeys = 0;
    @try {
        NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:@(AD_PREF_DOMAIN)];
        NSDictionary *d = [u dictionaryRepresentation] ?: @{};
        // WHY THE SETTINGS TOGGLE DID NOTHING. Settings writes this domain
        // through cfprefsd, which lands in the REAL /var/mobile/Library/
        // Preferences -- not the /var/jb mirror this used to read, and the
        // NSUserDefaults suite above can come back empty inside Amazon's
        // sandbox. So the switch was writing somewhere the tweak never looked.
        // Read every plausible location, last one found wins, and derive the
        // jailbreak root from our own loaded image so no path is hardcoded.
        NSMutableArray *paths = [NSMutableArray array];
        [paths addObject:[NSString stringWithFormat:@"/var/jb/var/mobile/Library/Preferences/%s.plist", AD_PREF_DOMAIN]];
        @try {
            Dl_info info;
            if (dladdr((const void *)&ADLoadPrefs, &info) && info.dli_fname){
                NSString *img = [NSString stringWithUTF8String:info.dli_fname];
                NSRange jb = [img rangeOfString:@"/jb/"];
                if (jb.location != NSNotFound){
                    NSString *root = [img substringToIndex:jb.location + jb.length - 1];
                    [paths addObject:[NSString stringWithFormat:@"%@/var/mobile/Library/Preferences/%s.plist", root, AD_PREF_DOMAIN]];
                }
            }
        } @catch(...) {}
        [paths addObject:[NSString stringWithFormat:@"/var/mobile/Library/Preferences/%s.plist", AD_PREF_DOMAIN]];
        for (NSString *pp in paths){
            NSDictionary *fromFile = [NSDictionary dictionaryWithContentsOfFile:pp];
            if (fromFile.count){
                NSMutableDictionary *m = [d mutableCopy];
                [m addEntriesFromDictionary:fromFile];
                d = m;
                srcPath = pp.UTF8String;
            }
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
        nKeys = (unsigned long)d.count;
    } @catch(...) {}
    ADSyncColorEngine();
    ADLog(@"prefs: src=%s keys=%lu", srcPath, nKeys);
    ADLog(@"prefs: enabled=%d web=%d nativeTheme=%d nativeRecolor=%d force120=%d bright=%ld contrast=%ld gray=%ld sepia=%ld bg=%s fg=%s",
          gP.enabled, gP.webDarkReader, gP.nativeTheme, gP.nativeRecolor, gP.force120Hz,
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
            // v5.278: the hardcoded fallbacks below are a LEFTOVER install layout and
            // they were winning. On device the dylib does not sit beside the bundle, so
            // both dir-relative candidates missed and we loaded the stale loose copy at
            // Application Support/AmazonDark/darkreader.js -- an old file that no build
            // updates. Every engine change (the v5.275 border clamp included) silently
            // had no effect. Search the BUNDLE path explicitly, in both rootless and
            // rootful prefixes, before any loose fallback.
            NSArray *cands = @[
                [dir stringByAppendingPathComponent:@"AmazonDark.bundle/darkreader.js"],
                @"/var/jb/Library/Application Support/AmazonDark/AmazonDark.bundle/darkreader.js",
                @"/Library/Application Support/AmazonDark/AmazonDark.bundle/darkreader.js",
                [dir stringByAppendingPathComponent:@"darkreader.js"],
                @"/var/jb/Library/Application Support/AmazonDark/darkreader.js",
                @"/Library/Application Support/AmazonDark/darkreader.js",
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
    // Opt-IN, not opt-out. A blanket rule paints every image the moment it
    // exists and can only be corrected afterwards, which is the bar flashing on
    // and off. Only images a pass has confirmed are clear of artwork get one.
    NSString *imgBackdrop = gP.imageBackdrop
        ? [NSString stringWithFormat:
             @"html body img[data-adbackdrop]{background-color:%s !important;}", gP.bgHex]
        : @"";
    return [NSString stringWithFormat:
            @"{css:'"
             // v5.256 shipped "*{border-color:#3b3c3e !important;}" here to darken the
             // person-tab / Interests CSS borders at parse time. Reverted in v5.257:
             // "*" also recoloured elements using border-width:Npx;border-color:transparent
             // as a spacing trick, making those invisible borders show as grey frames --
             // which read as the product photos cropping/flashing frame-to-frame. The
             // border darkening returns as a TARGETED sheet once P8BORD names the actual
             // selectors and colours; a global rule cannot tell a spacing border from a
             // visible one, so it stays out until we have that.
             "img,picture,video,canvas,svg{filter:none !important;opacity:1 !important;"
             "mix-blend-mode:normal !important;isolation:auto !important;}"
             // The Interests "+" is an <img class=*add-icon*> (P7PLUS). The blanket
             // img{filter:none} above -- there to protect product photos -- was also
             // freezing this glyph as Amazon's dark asset. Higher specificity than the
             // bare img rule, so it re-enables inversion for the icon ONLY, flipping
             // lightness while preserving hue (a dark + becomes a light +).
             "img[class*=add-icon],img[class*=plus-icon]{filter:invert(1) hue-rotate(180deg) !important;}"
             "%@"
             "[style*=\\\"background-image\\\"]{filter:none !important;}"
             // THE FIX THAT ACTUALLY WORKED, brought back. v5.27.0 whitened the heart
             // with a documentStart CSS rule and it visibly worked; v5.28.0 removed it
             // because [class*=heart-position] dragged the 32px disc into the whitening
             // (the white blob). Every JS attempt since lost a timing race CSS cannot
             // DARK CIRCLE, CHROME RING, WHITE SYMBOL -- the specified target for
             // both buttons, stated after the invert experiment: "circles with
             // chrome borders and white symbols". The disc is styled on the BUTTON
             // element across both card layouts (aria-label catches the grid
             // compare variant whose class family differs); the wrapper span is
             // explicitly flattened so nested matches cannot double-ring. Glyphs go
             // white by silhouette; the loading placeholder is hidden outright
             // because whitening a solid square asset produces a white box.
             // lists-framework-action-button intentionally omitted: it also lands on
             // row-sized containers (Interests popup), where a disc becomes an oval
             // spanning the row. It is styled from JS instead, size-guarded.
             "[class*=copilot-compare][class*=on-image-button],"
             "[class*=copilot-compare] [class*=on-image-button],"
             "[class*=s-product-image] button[aria-label*=ompare],"
             "[class*=puisg-col] [role=button][aria-label*=ompare],"
             "[class*=s-product-image] [data-csa-c-content-id*=ompare],"
             "[class*=puisg-col] [data-csa-c-content-id*=ompare]"
             "{background-color:transparent !important;border-radius:0 !important;"
             "border:0 !important;box-shadow:none !important;box-sizing:border-box !important;}"
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
             // v5.377: this is Amazon's stock Compare checkbox.  Previous builds
             // incorrectly turned the MLT host into a circular white-glyph button.
             // Flatten that old treatment at documentStart; compareFix377 paints
             // only the centered 24px checkbox and preserves the blue checked state.
             "[class*=mlt-icon-container]"
             "{background-color:transparent !important;border-radius:0 !important;"
             "border:0 !important;box-shadow:none !important;box-sizing:border-box !important;}"
             "[class*=mlt-icon-container] img[class*=s-image],"
             "[class*=mlt-image-icon] img[class*=s-image]"
             "{filter:none !important;background-color:transparent !important;}"
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
             "[class*=lists-framework-unfill],[class*=lists-framework-fill],"
             "[class*=copilot-compare] [class*=on-image-button] img,"
             "[class*=copilot-compare] [class*=on-image-button] i,"
             "[class*=copilot-compare] [class*=on-image-button] svg,"
             "[class*=copilot-compare][class*=on-image-button] img,"
             "[class*=copilot-compare][class*=on-image-button] i,"
             "[class*=copilot-compare][class*=on-image-button] svg,"
             "[class*=s-product-image] button[aria-label*=ompare] img,"
             "[class*=s-product-image] button[aria-label*=ompare] i,"
             "[class*=s-product-image] button[aria-label*=ompare] svg,"
             "[class*=puisg-col] [role=button][aria-label*=ompare] img,"
             "[class*=puisg-col] [role=button][aria-label*=ompare] i,"
             "[class*=puisg-col] [role=button][aria-label*=ompare] svg,"
             "[class*=s-product-image] [data-csa-c-content-id*=ompare] img,"
             "[class*=s-product-image] [data-csa-c-content-id*=ompare] i,"
             "[class*=s-product-image] [data-csa-c-content-id*=ompare] svg,"
             "[class*=puisg-col] [data-csa-c-content-id*=ompare] img,"
             "[class*=puisg-col] [data-csa-c-content-id*=ompare] i,"
             "[class*=puisg-col] [data-csa-c-content-id*=ompare] svg"
             "{filter:brightness(0) invert(1) !important;"
             "background-color:transparent !important;}"
             "[class*=puis-heart-position] [class*=placehold],[class*=heart-placeholder],"
             "[class*=puis-heart-position] img[src*=grey-pixel],[class*=puis-heart-position] img[src*=gray-pixel],"
             "[class*=puis-heart-position] img[src*=transparent-pixel],[class*=puis-heart-position] img[src*=placeholder],"
             "[class*=puis-heart-position] img[src*=spacer],[class*=puis-heart-position] img[src*=blank],"
             "[class*=puis-heart-position] img[class*=placehold]"
             "{display:none !important;filter:none !important;opacity:0 !important;}"
             // PHOTO SHIELD. Merchandise imagery must never carry a silhouette
             // filter, whatever rule above tried to apply one. Element selectors
             // are included deliberately to raise specificity over the
             // attribute-only rules that were matching these thumbnails.
             // AD-CARD TEXT (v5.361): creative copy is authored content. Never
             // pin its ink to dark or light here. The ad-card guard below strips
             // Dark Reader's inline writes and the contrast pass skips the subtree;
             // leaving colour unset is what lets mixed stock creative colours survive.
             "html body [data-adcrt],html body [data-adcrt] *"
             "{mix-blend-mode:normal !important;}"
             "html body [class*=product-image] img[src],"
             "html body [class*=s-product-image] img[src],"
             "html body [class*=product-image] picture[class],"
             "html body [class*=order] img[src],"
             "html body [class*=shipment] img[src],"
             "html body [class*=item-view] img[src],"
             "html body [class*=asin] img[src],"
             "html body [class*=your-orders] img[src]"
             "{filter:none !important;}"
             "[class*=lists-framework-action-button],"
             "[class*=lists-framework-action-button] *,"
             "[class*=copilot-compare] [class*=on-image-button] *,"
             "[class*=copilot-compare][class*=on-image-button] *"
             "{color:#ffffff !important;fill:#ffffff !important;}"
             // v5.375: image-backed search action controls are not trustworthy artwork.
             // Amazon serves three visually different states for the same control
             // (proper white cards, black cards, or an opaque square). Once runtime
             // confirms a cards-action host, hide the supplied painter and render one
             // canonical vector so template/lazy-asset swaps cannot change its look.
             "[data-ad-actionhost375]{position:relative !important;}"
             "[data-ad-actionorig375]{visibility:hidden !important;opacity:0 !important;}"
             "[data-ad-actioncanonical375]{position:absolute !important;left:50%% !important;"
             "top:50%% !important;transform:translate(-50%%,-50%%) !important;"
             "width:22px !important;height:22px !important;display:block !important;"
             "visibility:visible !important;opacity:1 !important;filter:none !important;"
             "background:transparent !important;pointer-events:none !important;z-index:2 !important;}"
             "[data-ad-actioncanonical375] rect,[data-ad-actioncanonical375] path"
             "{fill:none !important;stroke:#ffffff !important;stroke-width:1.8 !important;"
             "stroke-linecap:round !important;stroke-linejoin:round !important;}"
             // v5.377: MLT is Amazon's compare checkbox, NOT the cards-action glyph.
             // Render a square dark checkbox with a chrome bezel; selected state keeps
             // Amazon's stock rgb(33,98,161) blue and a white checkmark.
             "[data-ad-comparehost377]{position:relative !important;background:transparent !important;"
             "border:0 !important;border-radius:4px !important;box-shadow:none !important;}"
             "[data-ad-comparebox377]{position:absolute !important;left:50%% !important;top:50%% !important;"
             "width:24px !important;height:24px !important;transform:translate(-50%%,-50%%) !important;"
             "display:block !important;pointer-events:none !important;box-sizing:border-box !important;"
             "border-radius:4px !important;background:#181a1b !important;"
             "border:1.5px solid #9aa0a3 !important;"
             "box-shadow:inset 0 0 0 1px rgba(255,255,255,.10),0 0 0 1px #3b4043 !important;"
             "z-index:2 !important;filter:none !important;opacity:1 !important;}"
             "[data-ad-comparehost377][data-ad-comparechecked377=\"1\"] [data-ad-comparebox377]"
             "{background:#2162a1 !important;border-color:#2162a1 !important;"
             "box-shadow:inset 0 0 0 1px rgba(255,255,255,.12) !important;}"
             "[data-ad-comparecheck377]{position:absolute !important;left:20%% !important;top:18%% !important;"
             "width:60%% !important;height:60%% !important;display:none !important;overflow:visible !important;"
             "fill:none !important;stroke:#ffffff !important;stroke-width:3 !important;"
             "stroke-linecap:round !important;stroke-linejoin:round !important;}"
             "[data-ad-comparehost377][data-ad-comparechecked377=\"1\"] [data-ad-comparecheck377]"
             "{display:block !important;}"
             "[data-ad-compareinput377]{opacity:0 !important;position:absolute !important;inset:0 !important;"
             "width:100%% !important;height:100%% !important;margin:0 !important;z-index:4 !important;"
             "cursor:pointer !important;}"
             // v5.378: rollback the synthetic icon era. Keep Amazon's own heart/cards/compare
             // artwork and only normalize its paint. The action host gets the requested dark
             // circular chrome, while the stock Compare checkbox remains square and clickable.
             "[data-ad-stockaction378=\"1\"]{background:#181a1b !important;border-radius:50%% !important;"
             "border:1.5px solid rgba(255,255,255,.65) !important;box-shadow:none !important;"
             "box-sizing:border-box !important;}"
             "[data-ad-stockglyph378=\"1\"]{visibility:visible !important;opacity:1 !important;"
             "background-color:transparent !important;}"
             "[data-ad-stockglyph378=\"1\"][data-ad-raster378=\"1\"]{filter:brightness(0) invert(1) !important;}"
             "[data-ad-compare378=\"0\"] [data-ad-compareleaf378=\"1\"][data-ad-compare-raster378=\"1\"]"
             "{filter:brightness(0) invert(1) !important;}"
             "[data-ad-compare378=\"1\"] [data-ad-compareleaf378=\"1\"][data-ad-compare-raster378=\"1\"]"
             "{filter:none !important;}"
             "[data-ad-carticon378=\"1\"][data-ad-cart-raster378=\"1\"]"
             "{filter:brightness(0) invert(1) !important;background-color:transparent !important;}"
             "[data-ad-carticon378=\"1\"] svg,[data-ad-carticon378=\"1\"] path,"
             "svg[data-ad-carticon378=\"1\"],path[data-ad-carticon378=\"1\"]"
             "{color:#fff !important;fill:#fff !important;stroke:#fff !important;}"
             "[data-ad-stockglyph378=\"1\"] svg,[data-ad-stockglyph378=\"1\"] path,"
             "svg[data-ad-stockglyph378=\"1\"],path[data-ad-stockglyph378=\"1\"]"
             "{color:#fff !important;fill:#fff !important;stroke:#fff !important;}"
             "[data-ad-compare378] [data-ad-compareleaf378=\"1\"]"
             "{visibility:visible !important;opacity:1 !important;}"
             "[data-ad-compare378=\"0\"] [data-ad-compareleaf378=\"1\"] svg,"
             "[data-ad-compare378=\"0\"] svg[data-ad-compareleaf378=\"1\"],"
             "[data-ad-compare378=\"0\"] [data-ad-compareleaf378=\"1\"] path,"
             "[data-ad-compare378=\"0\"] path[data-ad-compareleaf378=\"1\"]"
             "{color:#fff !important;fill:#fff !important;stroke:#fff !important;}"
             "[data-ad-compare378]{background:transparent !important;border-radius:0 !important;"
             "border:0 !important;box-shadow:none !important;}"
             // v5.379: stock controls only. The list/cards glyph remains Amazon's own
             // artwork, but its host is forced to the same dark circular chrome as Heart.
             // Compare uses the REAL Amazon click/input target; only its paint is normalized.
             "[data-ad-stockaction379=\"1\"]{position:relative !important;background-color:#181a1b !important;"
             "border-radius:50%% !important;border:0 !important;overflow:hidden !important;"
             "box-shadow:inset 0 0 0 64px #181a1b,0 0 0 1.5px rgba(255,255,255,.65) !important;"
             "box-sizing:border-box !important;isolation:isolate !important;}"
             "[data-ad-stockaction379=\"1\"] [data-ad-stockglyph379=\"1\"]{position:relative !important;"
             "z-index:1 !important;visibility:visible !important;opacity:1 !important;background-color:transparent !important;}"
             "[data-ad-stockglyph379=\"1\"][data-ad-raster379=\"1\"]{filter:brightness(0) invert(1) !important;}"
             "[data-ad-stockglyph379=\"1\"] svg,[data-ad-stockglyph379=\"1\"] path,"
             "svg[data-ad-stockglyph379=\"1\"],path[data-ad-stockglyph379=\"1\"]"
             "{color:#fff !important;fill:#fff !important;stroke:#fff !important;}"
             "[data-ad-compare379]{position:relative !important;width:32px !important;height:32px !important;"
             "min-width:32px !important;min-height:32px !important;max-width:32px !important;max-height:32px !important;"
             "background:#181a1b !important;border:1.5px solid #9aa0a3 !important;border-radius:4px !important;"
             "box-shadow:none !important;box-sizing:border-box !important;overflow:hidden !important;}"
             "[data-ad-compare379=\"1\"]{background:#2162a1 !important;border-color:#2162a1 !important;}"
             "[data-ad-compare379=\"1\"]::after{content:\"\" !important;position:absolute !important;"
             "left:10px !important;top:5px !important;width:8px !important;height:14px !important;"
             "border:solid #fff !important;border-width:0 2.5px 2.5px 0 !important;"
             "transform:rotate(45deg) !important;z-index:2 !important;pointer-events:none !important;}"
             "[data-ad-compareinput379=\"1\"]{opacity:0 !important;position:absolute !important;inset:0 !important;"
             "width:100%% !important;height:100%% !important;margin:0 !important;z-index:4 !important;cursor:pointer !important;}"
             "[data-ad-compareorig379=\"1\"]{visibility:hidden !important;opacity:0 !important;pointer-events:none !important;}"
             // Cart's blank light pill can be a pseudo/background painter rather than the host.
             "[data-ad-cartchrome379=\"1\"]{background:#181a1b !important;background-image:none !important;"
             "border:1px solid #6c7073 !important;border-radius:999px !important;box-shadow:none !important;"
             "color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;}"
             "[data-ad-cartchrome379=\"1\"]::before,[data-ad-cartchrome379=\"1\"]::after"
             "{background:#181a1b !important;background-image:none !important;box-shadow:none !important;}"
             // v5.380: keep the stock two-card glyph, but give its REAL small host the
             // same dark circular chrome as the already-correct Heart control. The JS
             // copies Heart's live chrome when available; these values are the fallback.
             "[data-ad-stockaction380=\"1\"]{position:relative !important;background-color:#181a1b !important;"
             "border-radius:50%% !important;border:1.5px solid #6c7073 !important;"
             "box-shadow:inset 0 0 0 1px rgba(255,255,255,.10) !important;box-sizing:border-box !important;"
             "overflow:hidden !important;isolation:isolate !important;}"
             "[data-ad-stockglyph380=\"1\"]{position:relative !important;z-index:2 !important;"
             "visibility:visible !important;opacity:1 !important;background-color:transparent !important;}"
             "[data-ad-stockglyph380=\"1\"][data-ad-stockraster380=\"1\"]{filter:brightness(0) invert(1) !important;}"
             "[data-ad-stockglyph380=\"1\"] svg,[data-ad-stockglyph380=\"1\"] path,"
             "svg[data-ad-stockglyph380=\"1\"],path[data-ad-stockglyph380=\"1\"]"
             "{color:#fff !important;fill:#fff !important;stroke:#fff !important;}"
             // Compare keeps Amazon's real click target. A paint-only pseudo sits above
             // Amazon's white bitmap so unchecked is dark/chrome and checked is blue.
             "[data-ad-compare380]{position:relative !important;background:transparent !important;"
             "border:0 !important;border-radius:4px !important;box-shadow:none !important;overflow:visible !important;}"
             "[data-ad-compare380]::before{content:\"\" !important;position:absolute !important;left:50%% !important;top:50%% !important;"
             "width:28px !important;height:28px !important;transform:translate(-50%%,-50%%) !important;"
             "background:#181a1b !important;border:1.5px solid #9aa0a3 !important;border-radius:4px !important;"
             "box-shadow:inset 0 0 0 1px rgba(255,255,255,.10) !important;z-index:3 !important;pointer-events:none !important;}"
             "[data-ad-compare380=\"1\"]::before{background:#2162a1 !important;border-color:#2162a1 !important;}"
             "[data-ad-compare380=\"1\"]::after{content:\"\" !important;position:absolute !important;"
             "left:50%% !important;top:50%% !important;width:8px !important;height:14px !important;"
             "border:solid #fff !important;border-width:0 2.5px 2.5px 0 !important;"
             "transform:translate(-50%%,-62%%) rotate(45deg) !important;z-index:4 !important;pointer-events:none !important;}"
             "[data-ad-compareorig380=\"1\"]{visibility:hidden !important;opacity:0 !important;pointer-events:none !important;}"
             "[data-ad-compareinput380=\"1\"]{opacity:0 !important;position:absolute !important;inset:0 !important;"
             "width:100%% !important;height:100%% !important;margin:0 !important;z-index:6 !important;cursor:pointer !important;}"
             // v5.380 Cart recovery paints the actual light rectangle immediately to
             // the right of Delete, even when Amazon gives that painter no role/text.
             "[data-ad-cartchrome380=\"1\"]{background:#181a1b !important;background-image:none !important;"
             "border:1px solid #6c7073 !important;border-radius:999px !important;box-shadow:none !important;"
             "color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;opacity:1 !important;}"
             "[data-ad-cartchrome380=\"1\"]::before,[data-ad-cartchrome380=\"1\"]::after"
             "{background:#181a1b !important;background-image:none !important;box-shadow:none !important;}"
             // Exact Cart Share recovery. v5.380's light-painter geometry never saw
             // the actual button (probe stayed direct=0), so key it to Share + Delete row.
             "[data-ad-cartshare381=\"1\"]{background:#181a1b !important;background-color:#181a1b !important;"
             "background-image:none !important;border:1px solid #6c7073 !important;border-radius:999px !important;"
             "box-shadow:none !important;color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;opacity:1 !important;}"
             "[data-ad-cartshare381=\"1\"]::before,[data-ad-cartshare381=\"1\"]::after"
             "{background:#181a1b !important;background-image:none !important;box-shadow:none !important;}"
             "[data-ad-cartshare381=\"1\"] *{color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;"
             "background-color:transparent !important;background-image:none !important;}"
             // PDP share is a separate web control and must never inherit dark icon
             // paint from a recycled product template. Filter only glyph leaves.
             ".ssf-share-trigger,[data-ad-share377=\"1\"]{color:#ffffff !important;"
             "-webkit-text-fill-color:#ffffff !important;fill:#ffffff !important;stroke:#ffffff !important;"
             "filter:none !important;opacity:1 !important;}"
             ".ssf-share-trigger svg,.ssf-share-trigger path,[data-ad-share377=\"1\"] svg,"
             "[data-ad-share377=\"1\"] path{color:#ffffff !important;fill:#ffffff !important;"
             "stroke:#ffffff !important;opacity:1 !important;}"
             ".ssf-share-trigger i,.ssf-share-trigger .a-icon,.ssf-share-trigger img"
             "{filter:brightness(0) invert(1) !important;background-color:transparent !important;"
             "color:#ffffff !important;opacity:1 !important;}"
             ".ssf-share-trigger::before,.ssf-share-trigger::after,"
             ".ssf-share-trigger *::before,.ssf-share-trigger *::after"
             "{color:#ffffff !important;filter:brightness(0) invert(1) !important;opacity:1 !important;}"

             // A second Amazon compare implementation exposes only .a-icon-checkbox.
             // Paint it with the exact same square state machine as compare380.
             "[data-ad-comparelegacy387]{position:relative !important;background:transparent !important;"
             "border:0 !important;border-radius:4px !important;box-shadow:none !important;overflow:visible !important;}"
             "[data-ad-comparelegacy387]::before{content:\"\" !important;position:absolute !important;left:50%% !important;top:50%% !important;"
             "width:28px !important;height:28px !important;transform:translate(-50%%,-50%%) !important;"
             "background:#181a1b !important;border:1.5px solid #9aa0a3 !important;border-radius:4px !important;"
             "box-shadow:inset 0 0 0 1px rgba(255,255,255,.10) !important;z-index:3 !important;pointer-events:none !important;}"
             "[data-ad-comparelegacy387=\"1\"]::before{background:#2162a1 !important;border-color:#2162a1 !important;}"
             "[data-ad-comparelegacy387=\"1\"]::after{content:\"\" !important;position:absolute !important;"
             "left:50%% !important;top:50%% !important;width:8px !important;height:14px !important;"
             "border:solid #fff !important;border-width:0 2.5px 2.5px 0 !important;"
             "transform:translate(-50%%,-62%%) rotate(45deg) !important;z-index:4 !important;pointer-events:none !important;}"
             "[data-ad-comparelegacyorig387=\"1\"]{visibility:hidden !important;opacity:0 !important;pointer-events:none !important;}"
             // v5.391 product controls: paint ONLY Amazon's existing stock host at its
             // stock coordinates. No inserted span, no width/height/position/transform,
             // no parent overflow/isolation rewrite. One 1.5px inset chrome ring.
             "[data-ad-product391]{background-color:#181a1b !important;border:0 !important;"
             "border-radius:50%% !important;box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.65) !important;"
             "box-sizing:border-box !important;}"
             "[data-ad-productglyph391=\"1\"]{visibility:visible !important;opacity:1 !important;background-color:transparent !important;}"
             "[data-ad-productraster391=\"1\"]{filter:brightness(0) invert(1) !important;}"
             "[data-ad-productvector391=\"1\"],svg[data-ad-productvector391=\"1\"],path[data-ad-productvector391=\"1\"]"
             "{color:#fff !important;fill:#fff !important;stroke:#fff !important;}"
             // v5.393: Amazon also renders the Search Heart through ::before/::after
             // on some hydrated layouts. Mark the real pseudo painter from JS and
             // whiten only that pseudo; unmarked hydration shells remain transparent.
             "html body [class*=puis-heart-position] [data-ad-heartbefore393=\"1\"]::before,"
             "html body [class*=puis-heart-position] [data-ad-heartafter393=\"1\"]::after"
             "{color:#fff !important;opacity:1 !important;visibility:visible !important;}"
             "html body [class*=puis-heart-position] [data-ad-heartbeforemask393=\"1\"]::before,"
             "html body [class*=puis-heart-position] [data-ad-heartaftermask393=\"1\"]::after"
             "{background-color:#fff !important;filter:none !important;}"
             "html body [class*=puis-heart-position] [data-ad-heartbeforeraster393=\"1\"]::before,"
             "html body [class*=puis-heart-position] [data-ad-heartafterraster393=\"1\"]::after"
             "{background-color:transparent !important;filter:brightness(0) invert(1) !important;}"
             "[data-ad-homeback393=\"1\"]{background-color:#181a1b !important;}"
             "[data-ad-homebackbefore393=\"1\"]::before,[data-ad-homebackafter393=\"1\"]::after"
             "{background-color:#181a1b !important;background-image:none !important;}"
             // compareStock380/legacyCompare387 keep state/click ownership; this marker
             // changes presentation only. The outer host is the common circle; the inner
             // white square/check identifies checkbox state without ever painting a white box.
             "[data-ad-product391=\"checkbox\"]::before{content:\"\" !important;position:absolute !important;"
             "left:50%% !important;top:50%% !important;width:13px !important;height:13px !important;"
             "transform:translate(-50%%,-50%%) !important;background:transparent !important;"
             "border:1.5px solid #fff !important;border-radius:2px !important;box-shadow:none !important;"
             "pointer-events:none !important;z-index:3 !important;}"
             "[data-ad-product391=\"checkbox\"]::after{content:none !important;}"
             "[data-ad-product391=\"checkbox\"][data-ad-productselected391=\"1\"]::after{content:\"\" !important;"
             "position:absolute !important;left:50%% !important;top:50%% !important;width:6px !important;height:10px !important;"
             "border:solid #fff !important;border-width:0 2px 2px 0 !important;"
             "transform:translate(-50%%,-62%%) rotate(45deg) !important;pointer-events:none !important;z-index:4 !important;}"
             "[data-ad-product391=\"checkbox\"] [data-ad-compareorig380=\"1\"],"
             "[data-ad-product391=\"checkbox\"] [data-ad-comparelegacyorig387=\"1\"],"
             "[data-ad-product391=\"checkbox\"] img[class*=s-image]"
             "{visibility:hidden !important;opacity:0 !important;}"
             // Cart Share now clones the already-correct Delete control instead of
             // receiving a hand-authored second bezel. Pseudos are explicitly cleared.
             "[data-ad-cartclone382=\"1\"]{background-color:var(--ad-cart-bg,transparent) !important;"
             "background-image:var(--ad-cart-bi,none) !important;border-color:var(--ad-cart-bc,#6c7073) !important;"
             "border-style:var(--ad-cart-bs,solid) !important;border-width:var(--ad-cart-bw,1px) !important;"
             "border-radius:var(--ad-cart-br,999px) !important;box-shadow:var(--ad-cart-sh,none) !important;"
             "color:var(--ad-cart-fg,#e8e6e3) !important;-webkit-text-fill-color:var(--ad-cart-fg,#e8e6e3) !important;}"
             "[data-ad-cartclone382=\"1\"]::before,[data-ad-cartclone382=\"1\"]::after"
             "{background:transparent !important;background-image:none !important;border-color:transparent !important;box-shadow:none !important;}"
             "[data-ad-cartclone382=\"1\"] *{color:var(--ad-cart-fg,#e8e6e3) !important;"
             "-webkit-text-fill-color:var(--ad-cart-fg,#e8e6e3) !important;}"
             // PDP Share: never filter the whole host. Mark/filter the actual raster,
             // background-image or mask painter only; SVG/path paint is pinned white.
             ".ssf-share-trigger,[data-ad-share382=\"1\"]{color:#fff !important;-webkit-text-fill-color:#fff !important;"
             "fill:#fff !important;stroke:#fff !important;filter:none !important;opacity:1 !important;}"
             "[data-ad-sharepaint382=\"1\"]{filter:brightness(0) invert(1) !important;opacity:1 !important;background-color:transparent !important;}"
             "[data-ad-share382=\"1\"] svg,[data-ad-share382=\"1\"] path{color:#fff !important;fill:#fff !important;stroke:#fff !important;opacity:1 !important;}"
             "[data-ad-share382=\"1\"]::before,[data-ad-share382=\"1\"]::after,"
             "[data-ad-share382=\"1\"] *::before,[data-ad-share382=\"1\"] *::after"
             "{color:#fff !important;filter:brightness(0) invert(1) !important;opacity:1 !important;}"

             // Home shortcut strips (Haul / Prime Video / Grocery...): brand
             // artwork sits on LIGHT pills, where the dark image backdrop reads
             // as a black box. Brand imgs keep a clean slate.
             // Chrome glyphs: no backdrop, ever. Sized rules cannot be expressed
             // in CSS, so cover the search/nav containers by name here and let the
             // JS pass above catch the rest by measured size.
             "[class*=nav-search] img,[class*=searchbar] img,[class*=search-bar] img,"
             "[role=search] img,[class*=nav-] img[class*=icon],[class*=header] img[class*=icon]"
             "{background-color:transparent !important;}"
             "img[alt*=\\\"Whole Foods\\\"],img[alt*=Prime],img[alt*=prime],img[alt*=Fresh],"
             "img[alt*=Haul],img[alt*=haul],img[alt*=Grocer],img[alt*=Luxury],img[alt*=Pharmac]"
             "{background-color:transparent !important;filter:none !important;}"
             // ISSUE 2: the read-more fade on long reviews is a white gradient
             // overlay; on the dark theme it reads as a white smear. Remove the
             // paint wholesale -- the expander still works, the text just ends.
             // THE CONTENT REGRESSION, AND MY FAULT. v5.54 put display:none in a
             // rule whose selector list included [class*=gradient] -- so every
             // element with "gradient" anywhere in its class was HIDDEN, and on
             // the home and cart pages that is real content, not scrim. Two
             // separate rules now: real elements only ever lose their PAINT,
             // and display:none is confined to pseudo-elements, which draw
             // nothing but the fade itself.
             "[class*=expander] [class*=fade],[class*=fade-out],"
             "[data-hook*=review] [class*=fade],[class*=expander-fade],"
             "[class*=a-reactive-container],[class*=reactive-contain]"
             "{background:transparent !important;background-image:none !important;"
             "box-shadow:none !important;}"
             "[class*=a-expander-partial]::before,[class*=a-expander-partial]::after,"
             "[class*=expander-content]::before,[class*=expander-content]::after,"
             "[class*=a-expander-partial-collapse-container]::after,"
             "[class*=a-expander-partial-collapse-container]::before,"
             "[data-hook*=review] [class*=expander]::after,"
             "[data-hook*=review] [class*=expander]::before,"
             "[class*=cr-] [class*=expander]::after,[class*=cr-] [class*=expander]::before,"
             "[class*=review] [class*=expander]::after,[class*=review] [class*=expander]::before"
             "{background:none !important;background-image:none !important;"
             "content:none !important;display:none !important;}"

             // Card skeletons. The light= probe names div.a-section@76x64 shells
             // that stay light through every pass -- they flash white where the
             // heart will be while the card hydrates. Empty shells carry no
             // content, so darkening them at documentStart cannot cover anything.
             "[class*=puis] [class*=a-section]:empty,[class*=s-result] [class*=a-section]:empty,"
             "[class*=s-card] [class*=a-section]:empty"
             "{background-color:#181a1b !important;}"

             // Promo/hero card header: no dark box behind it, and its title text
             // stays the stock dark (it sits on a light hero image).
             "[class*=a-cardui-header]{background-color:transparent !important;}"
             // v5.287: REMOVED the blanket "{color:#0f1111}" on card-header titles.
             // P9CONTRAST measured this text at tl=0.06 (exactly #0f1111, i.e. ours)
             // sitting on bl=0.11 -- black on black, unreadable. The rule assumed the
             // header sits on a light hero image, which is untrue for the home-feed ad
             // cards. Nothing replaces it: DR and the contrast repair both MEASURE the
             // real background, so they pick a readable colour where a fixed ink cannot.
             // Darkening blends crush their content toward black on a dark theme; the
             // deal badges use them inline. Neutralise at documentStart so the text is
             // legible on first paint instead of after the repair catches up.
             "[style*=multiply],[style*=darken],[style*=color-burn],"
             "[class*=deal] [style*=blend],[class*=Deal] [style*=blend]"
             "{mix-blend-mode:normal !important;isolation:auto !important;}"
             "',invert:[],ignoreInlineStyle:['[class*=puis-heart-position]','[class*=puis-heart-position] *',"
             "'[class*=lists-framework-action-button]','[class*=lists-framework-action-button] *',"
             "'[class*=copilot-compare]','[class*=copilot-compare] *','[data-ad-stocktext]','[data-ad-stocktext] *','[data-adcrt]','[data-adcrt] *','[data-ad-sponsored-light363]','[data-ad-sponsored-light363] *','[data-ad-college-chevron]','[data-ad-college-chevron] *','[data-ad-college-chevron-sprite]','ul.a-pagination.a-dots li.a-selected','li.dot-selected-t2','[data-ad-cardborder]','[data-ad-nav-chevron-paint]'],"
             "ignoreImageAnalysis:['*'],disableStyleSheetsProxy:false}",
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
static dispatch_queue_t ADBootQueue(void){
    static dispatch_queue_t q; static dispatch_once_t once;
    dispatch_once(&once, ^{ q = dispatch_queue_create("com.amazondark.boot", DISPATCH_QUEUE_SERIAL); });
    return q;
}
static NSString *ADDarkReaderBootstrapBuild(void){
    NSString *dr = ADBundledDarkReaderJS();
    if (!dr.length) return nil;
    NSString *adBody = [NSString stringWithFormat:
        @"(function(){try{"
         "if(window.__AMZDARK_LOADED__){try{window.__AD_REINJ__=(window.__AD_REINJ__||0)+1;}catch(e){}return;}""window.__AMZDARK_LOADED__=1;""try{window.__AD_T0__=Date.now();""window.__AD_PRETHEMED__=document.querySelector('style.darkreader')?1:0;""window.__AD_NAV__=(performance&&performance.navigation)?performance.navigation.type:-1;""}catch(e){}"
         // v5.264: DIM CARD/PILL BORDERS AT PARSE TIME. The person-tab card outlines and
         // the Interests scroll-flash are one thing: real CSS borders (P9FIX tagged |b)
         // that paint LIGHT before Dark Reader darkens them. A pre-paint stylesheet on the
         // stable card classes makes them dark from the first frame -- no light flash, and
         // DR has nothing to fight. Scoped to specific classes (not *), so transparent
         // spacing borders stay untouched: no crop regression.
         // v5.396: main-frame marker is set at documentStart before Home carousel DOM paints.
         // This lets the prepaint sheet suppress Amazon's colored carousel ambient layer
         // before recycled/overscroll content can expose it for a frame.
         "try{if(window===window.top&&document&&document.documentElement)document.documentElement.setAttribute('data-ad-main396','1');}catch(e){}"
         "try{if(document&&!document.getElementById('adcardfix')){"
           "var __acs=document.createElement('style');__acs.id='adcardfix';"
           "__acs.textContent='picture,[class*=image-container],[class*=thumbnail-conta],[class*=single-creative],[class*=s-image],[class*=unfill],[class*=placehold]{background-color:transparent !important;}[class*=puis-heart-position] button,[class*=puis-heart-position] [role=button],[class*=puis-heart-position] a,[class*=puis-heart-position] span,[class*=puis-heart-position] div{background-color:transparent !important;}[class*=puis-heart-position] button::before,[class*=puis-heart-position] button::after,[class*=puis-heart-position] [role=button]::before,[class*=puis-heart-position] [role=button]::after,[class*=puis-heart-position] a::before,[class*=puis-heart-position] a::after,[class*=puis-heart-position] span::before,[class*=puis-heart-position] span::after,[class*=puis-heart-position] div::before,[class*=puis-heart-position] div::after{background-color:transparent !important;}[class*=puis-heart-position] img[src*=grey-pixel],[class*=puis-heart-position] img[src*=gray-pixel],[class*=puis-heart-position] img[src*=transparent-pixel],[class*=puis-heart-position] img[src*=placeholder],[class*=puis-heart-position] img[src*=spacer],[class*=puis-heart-position] img[src*=blank],[class*=puis-heart-position] img[class*=placehold]{display:none !important;filter:none !important;opacity:0 !important;}#search [class*=puis-heart-position],.s-search-results [class*=puis-heart-position],[data-component-type=\"s-search-result\"] [class*=puis-heart-position],#dp-container [class*=puis-heart-position],#ppd [class*=puis-heart-position]{visibility:hidden !important;}#search [class*=puis-heart-position][data-ad-heartready394=\"1\"],.s-search-results [class*=puis-heart-position][data-ad-heartready394=\"1\"],[data-component-type=\"s-search-result\"] [class*=puis-heart-position][data-ad-heartready394=\"1\"],#dp-container [class*=puis-heart-position][data-ad-heartready394=\"1\"],#ppd [class*=puis-heart-position][data-ad-heartready394=\"1\"]{visibility:visible !important;}[class*=s-image],[class*=s-product-image] img,img[class*=s-image]{object-fit:contain !important;}[class*=a-cardui],[class*=npack-asin-card],[class*=gwm-asin-tile],[class*=gwm-window-layout],[class*=window-container],[class*=gwm-dashboard-container],[class*=wd-backdrop],[class*=theming-card],[class*=a-unordered-list],[class*=mosaic-container],[class*=puis-card],[class*=gwm-tile],[class*=_container_]{border-color:#3b4043 !important;}[class*=deal],[class*=badge],[class*=prime],[class*=error],[class*=alert],[class*=warning],[aria-invalid=true]{border-color:initial !important;}[class*=a-button-primary],[class*=a-button-search],[class*=a-button-oneclick],[class*=a-button-buy],.a-button-inner,.a-button-text{border-color:transparent !important;}[class*=ape-placement],[class*=ape-wrapper],[data-cel-widget*=ape],[id*=ape_],[class*=ape-placement] *,[class*=ape-wrapper] *,[data-cel-widget*=ape] *,[id*=ape_] *{filter:none !important;mix-blend-mode:normal !important;isolation:auto !important;text-shadow:none !important;}[class*=ape-placement],[class*=ape-wrapper],[data-cel-widget*=ape],[id*=ape_]{background-color:initial !important;}[class*=ape-placement] img,[class*=ape-wrapper] img,[class*=ape-placement] svg,[class*=ape-wrapper] svg,[class*=ape-placement] picture,[class*=ape-wrapper] picture{filter:none !important;opacity:1 !important;}[class*=ape-placement] span,[class*=ape-placement] a,[class*=ape-placement] p,[class*=ape-placement] h1,[class*=ape-placement] h2,[class*=ape-placement] h3,[class*=ape-placement] h4,[class*=ape-wrapper] span,[class*=ape-wrapper] a,[class*=ape-wrapper] p,[class*=ape-wrapper] h1,[class*=ape-wrapper] h2,[class*=ape-wrapper] h3,[class*=ape-wrapper] h4,[class*=theming-card] span,[class*=theming-card] a,[class*=theming-card] p,[class*=theming-card] h1,[class*=theming-card] h2,[class*=theming-card] h3,[class*=theming-card] h4{background-color:transparent !important;}[class*=hybrid-widget-sponsored],[class*=hybrid-widget-sponsored] *,[class*=adFeedbackMainComponent],[class*=adFeedbackMainComponent] *,[class*=sponsored-label],[class*=sponsored-label] *{opacity:1 !important;filter:none !important;mix-blend-mode:normal !important;}[class*=theming-card] [class*=a-cardui-header],[class*=a-cardui-header][class*=theming]{background-color:transparent !important;}[class*=npack-asin-card],[class*=npack-asin-card] *{filter:none !important;opacity:1 !important;mix-blend-mode:normal !important;isolation:auto !important;}[class*=npack-asin-card] [class*=a-size-mini],[class*=npack-asin-card] [class*=badge],[class*=npack-asin-card] [class*=percent]{color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;}[class*=npack-asin-card] [class*=badgeMessage],[class*=npack-asin-card] [class*=badgeMessage] *,[class*=cXVhZ] [class*=badgeMessage],[class*=cXVhZ] [class*=badgeMessage] *{background-color:#181a1b !important;background-image:none !important;color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;box-shadow:none !important;}[class*=npack-asin-card] [class*=badgeMessage]::before,[class*=npack-asin-card] [class*=badgeMessage]::after,[class*=npack-asin-card] [class*=badgeMessage] *::before,[class*=npack-asin-card] [class*=badgeMessage] *::after,[class*=cXVhZ] [class*=badgeMessage]::before,[class*=cXVhZ] [class*=badgeMessage]::after,[class*=cXVhZ] [class*=badgeMessage] *::before,[class*=cXVhZ] [class*=badgeMessage] *::after{background:#181a1b !important;background-image:none !important;box-shadow:none !important;}[class*=a-cardui-header],[class*=a-cardui-header] *{background-color:transparent !important;}[class*=gwm-tile] [class*=a-cardui-header],[class*=gwm-tile] [class*=a-cardui-header] *{color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;}[class*=hybrid-widget-sponsored],[class*=adFeedbackMainComponent],[class*=hybrid-widget-sponsored] *,[class*=adFeedbackMainComponent] *{background-color:transparent !important;}[class*=bW9ia],[class*=bW9ia] *{filter:none !important;opacity:1 !important;mix-blend-mode:normal !important;}[class*=bW9ia] span,[class*=bW9ia] a,[class*=bW9ia] [class*=price],[class*=bW9ia] [class*=badge],[class*=bW9ia] [class*=percent]{background-color:transparent !important;}[class*=sponsored-products] img[src*=logo],[class*=sponsored-products] img[class*=logo],[class*=sponsored-brand] img,[class*=brand-logo] img{background-color:#e8e6e3 !important;border-radius:4px !important;padding:2px !important;}[class*=cXVhZ],[class*=cXVhZ] *,[class*=badgeLabel],[class*=badgeContainer],[class*=theming-card],[class*=theming-card] *,[class*=canvas-card],[class*=canvas-card] *{mix-blend-mode:normal !important;isolation:auto !important;}[class*=badgeLabel]{background-color:#cc0c39 !important;color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;}[class*=badgeLabel],[class*=badgeLabel] *{color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;}[class*=npack-asin-card],[class*=canvas-card],[class*=theming-card-background]{background-color:initial !important;}[class*=badgeLabel]{background-color:#cc0c39 !important;}[class*=badgeLabel],[class*=badgeLabel] *{color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;}[class*=cXVhZ],[class*=cXVhZ] *{filter:none !important;opacity:1 !important;}[class*=a-cardui] [class*=a-price-whole],[class*=a-cardui] [class*=a-price-symbol],[class*=a-cardui] [class*=a-price-decimal],[class*=a-cardui] [class*=a-truncate],[class*=cXVhZ] [class*=a-price-whole],[class*=cXVhZ] [class*=a-price-symbol],[class*=cXVhZ] [class*=a-price-decimal],[class*=cXVhZ] [class*=a-truncate],[class*=npack-asin-card] [class*=a-price-whole],[class*=npack-asin-card] [class*=a-price-symbol],[class*=npack-asin-card] [class*=a-price-decimal],[class*=npack-asin-card] [class*=a-truncate]{color:#e8e6e3 !important;}ul.a-pagination.a-dots li.a-selected,ul.a-pagination.a-dots li.dot-selected-t2,ul.a-pagination.a-dots li[aria-current=true],ul.a-pagination.a-dots li[aria-current=page],ul.a-pagination.a-dots li[aria-selected=true],[data-ad-dotselected374]{background-color:#ffffff !important;border-color:#ffffff !important;}[data-ad-dotselected374]::before,[data-ad-dotselected374]::after,[data-ad-dotselected374] [class*=dot],[data-ad-dotselected374] span{background-color:#ffffff !important;border-color:#ffffff !important;color:#ffffff !important;fill:#ffffff !important;}[class*=pack-size-badge],[class*=pack-size-badge] *{color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;}[data-ad-nav-chevron-paint=\"1\"],[data-ad-nav-chevron=\"1\"] [class*=a-icon],[data-ad-nav-chevron=\"1\"] i,[data-ad-nav-chevron=\"1\"] svg,[data-ad-nav-chevron=\"1\"] path,[data-ad-college-section=\"1\"] .a-icon-next-rounded,[data-ad-college-section=\"1\"] .a-icon-previous-rounded{filter:brightness(0) invert(1) !important;opacity:1 !important;color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;}[data-ad-nav-chevron=\"1\"] svg,[data-ad-nav-chevron=\"1\"] path{fill:#e8e6e3 !important;stroke:#e8e6e3 !important;}.a-icon-next-rounded,.a-icon-previous-rounded,.a-carousel-goto-nextpage .a-icon,.a-carousel-goto-prevpage .a-icon,.a-carousel-button-right .a-icon,.a-carousel-button-left .a-icon,[class*=carousel] [class*=chevron],[class*=carousel] [class*=arrow],[class*=cXVhZ] [class*=chevron],[class*=cXVhZ] [class*=arrow]{filter:brightness(0) invert(1) !important;opacity:1 !important;color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;border-color:#e8e6e3 !important;fill:#e8e6e3 !important;stroke:#e8e6e3 !important;}[data-ad-college-chevron=\"1\"],[data-ad-college-chevron=\"1\"] *{color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;border-color:#e8e6e3 !important;fill:#e8e6e3 !important;stroke:#e8e6e3 !important;opacity:1 !important;}[data-ad-college-chevron=\"1\"]::before,[data-ad-college-chevron=\"1\"]::after,[data-ad-college-chevron=\"1\"] *::before,[data-ad-college-chevron=\"1\"] *::after{color:#e8e6e3 !important;border-color:#e8e6e3 !important;}[data-ad-college-chevron-sprite=\"1\"]{filter:brightness(0) invert(1) !important;}[data-ad-expchev383=\"1\"],[data-ad-expchev383=\"1\"] *{color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;fill:#e8e6e3 !important;stroke:#e8e6e3 !important;border-color:#e8e6e3 !important;opacity:1 !important;}[data-ad-expchev383=\"1\"]::before,[data-ad-expchev383=\"1\"]::after,[data-ad-expchev383=\"1\"] *::before,[data-ad-expchev383=\"1\"] *::after{color:#e8e6e3 !important;border-color:#e8e6e3 !important;fill:#e8e6e3 !important;stroke:#e8e6e3 !important;filter:brightness(0) invert(1) !important;}[data-ad-expchev383=\"1\"] img,[data-ad-expchev383=\"1\"] i{filter:brightness(0) invert(1) !important;opacity:1 !important;}.a-icon-extender-expand,.a-icon-extender-collapse,.a-icon-dropdown,[class*=a-icon-extender],[aria-expanded] .a-icon{filter:brightness(0) invert(1) !important;opacity:1 !important;color:#e8e6e3 !important;fill:#e8e6e3 !important;stroke:#e8e6e3 !important;}[data-ad-cardborder=\"1\"],[class*=\"_npack-asin-card_style_asin-cont\"],[class*=\"sc-card-style\"],[class*=\"_hp-mosaic-container_style_widgetContainer\"],[class*=\"_mosaic-container_style_widgetContainer\"]{border-color:#3b4043 !important;outline-color:#3b4043 !important;}[class*=\"_npack-asin-card_style_asin-cont\"]::before,[class*=\"_npack-asin-card_style_asin-cont\"]::after,[class*=\"sc-card-style\"]::before,[class*=\"sc-card-style\"]::after,[class*=\"_hp-mosaic-container_style_widgetContainer\"]::before,[class*=\"_hp-mosaic-container_style_widgetContainer\"]::after,[class*=\"_mosaic-container_style_widgetContainer\"]::before,[class*=\"_mosaic-container_style_widgetContainer\"]::after{border-color:#3b4043 !important;outline-color:#3b4043 !important;}[data-ad-videoctl362],[class*=ape-placement] [data-ad-videoctl362],[class*=ape-wrapper] [data-ad-videoctl362]{background:rgba(0,0,0,.72) !important;border-radius:999px !important;box-shadow:none !important;}[data-ad-videoctl362] svg,[data-ad-videoctl362] path,[data-ad-videoctl362] polygon{fill:#fff !important;stroke:#fff !important;color:#fff !important;}[data-ad-yml-head363=\"1\"],[data-ad-yml-head363=\"1\"] *{color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;opacity:1 !important;}[data-ad-sponsored-light363=\"1\"],[data-ad-sponsored-light363=\"1\"] *{color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;opacity:1 !important;}[data-ad-reviewink367=\"1\"]{color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;}[data-ad-producttext370=\"1\"]{color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;}[data-ad-productad367=\"1\"]{background-color:#181a1b !important;border-color:#3b4043 !important;outline-color:#3b4043 !important;}[data-ad-share375=\"1\"] img,[data-ad-share375=\"1\"] i,[data-ad-share375=\"1\"] [class*=icon]{filter:brightness(0) invert(1) !important;opacity:1 !important;background-color:transparent !important;}[data-ad-share375=\"1\"],[data-ad-share375=\"1\"] *{color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;}[data-ad-share375=\"1\"] svg,[data-ad-share375=\"1\"] path{fill:#ffffff !important;stroke:#ffffff !important;}[data-ad-actionhost376]{background-color:#181a1b !important;border-radius:50%% !important;border:1.5px solid rgba(255,255,255,.65) !important;box-shadow:none !important;box-sizing:border-box !important;}[data-ad-actionorig376]{visibility:hidden !important;opacity:0 !important;}[data-ad-actioncanonical376]{position:absolute !important;left:50%% !important;top:50%% !important;transform:translate(-50%%,-50%%) !important;width:23px !important;height:23px !important;display:block !important;visibility:visible !important;opacity:1 !important;filter:none !important;background:transparent !important;pointer-events:none !important;z-index:3 !important;}[data-ad-actioncanonical376] rect,[data-ad-actioncanonical376] path{fill:none !important;stroke:#ffffff !important;stroke-width:1.8 !important;stroke-linecap:round !important;stroke-linejoin:round !important;}[data-ad-sponsored376=\"1\"],[data-ad-sponsored376=\"1\"] *{color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;opacity:1 !important;visibility:visible !important;}[data-ad-rating376=\"1\"]{color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;opacity:1 !important;visibility:visible !important;}[data-ad-adtext376=\"1\"]{color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;opacity:1 !important;visibility:visible !important;}[data-ad-main396] [class*=single-creative-card] [class*=theming-card-background],[data-ad-main396] [class*=single-video-card] [class*=theming-card-background],[data-ad-main396] [class*=theming-card] [class*=theming-card-background]{background:#181a1b !important;background-color:#181a1b !important;background-image:none !important;filter:none !important;mix-blend-mode:normal !important;box-shadow:none !important;animation:none !important;transition:none !important;isolation:auto !important;}[data-ad-main396] [class*=single-creative-card] [class*=theming-card-background]::before,[data-ad-main396] [class*=single-creative-card] [class*=theming-card-background]::after,[data-ad-main396] [class*=single-video-card] [class*=theming-card-background]::before,[data-ad-main396] [class*=single-video-card] [class*=theming-card-background]::after,[data-ad-main396] [class*=theming-card] [class*=theming-card-background]::before,[data-ad-main396] [class*=theming-card] [class*=theming-card-background]::after{background:#181a1b !important;background-color:#181a1b !important;background-image:none !important;filter:none !important;mix-blend-mode:normal !important;box-shadow:none !important;animation:none !important;transition:none !important;}';"
           "(document.head||document.documentElement).appendChild(__acs);}}catch(e){}"
         // v5.397: SYMBOL THEME AUTHORITY = exact v5.333 policy for every
         // non-checkbox symbol family. The current Compare/MLT checkbox is deliberately
         // excluded and remains owned by compareStock380/legacyCompare387/product391.
         "try{if(document&&!document.getElementById('adsymbol333397')){var __s333=document.createElement('style');__s333.id='adsymbol333397';"
           "__s333.textContent='"
             "img[class*=add-icon],img[class*=plus-icon]{filter:invert(1) hue-rotate(180deg) !important;}"
             "[class*=puis-heart-position]{background-color:transparent !important;border:0 !important;box-shadow:none !important;}"
             "#search [class*=puis-heart-position],.s-search-results [class*=puis-heart-position],[data-component-type=\"s-search-result\"] [class*=puis-heart-position],#dp-container [class*=puis-heart-position],#ppd [class*=puis-heart-position]{visibility:visible !important;}"
             "[class*=puis-heart-position] [class*=placehold],[class*=heart-placeholder]{display:none !important;}"
             "[class*=lists-framework-action-button] img,[class*=lists-framework-action-button] i,[class*=lists-framework-action-button] svg,[class*=lists-framework-unfill],[class*=lists-framework-fill]{filter:brightness(0) invert(1) !important;background-color:transparent !important;}"
             "[class*=lists-framework-action-button],[class*=lists-framework-action-button] *{color:#ffffff !important;fill:#ffffff !important;}"
             "[class*=nav-search] img,[class*=searchbar] img,[class*=search-bar] img,[role=search] img,[class*=nav-] img[class*=icon],[class*=header] img[class*=icon]{background-color:transparent !important;}"
           "';(document.head||document.documentElement).appendChild(__s333);}}catch(e){}"
         "try{window.__AD_EARLY__='';"
           "var __adPinRe=/unfill|placehold/i;"
           "var __adPin=function(n){try{"
             "if(!n||n.nodeType!==1)return;"
             "var c=n.className;if(c&&c.baseVal!==undefined)c=c.baseVal;c=String(c||'');"
             "if(__adPinRe.test(c)){n.style.setProperty('background-color','transparent','important');}"
             "if(typeof onArt==='function'&&onArt(n)){}else "
             "if(String(c).indexOf('a-section')>=0&&n.closest&&"
               "n.closest('[class*=puis],[class*=s-result],[class*=s-card]')&&"
               "!n.closest('[class*=s-product-image],[class*=mlt-icon],[class*=puis-heart-position]')&&"
               "!(n.querySelector&&n.querySelector("
                 "'[class*=mlt-icon],[class*=puis-heart-position],[class*=lists-framework-action]'))){"
"if(!(function(x){try{return x.closest&&x.closest('[class*=a-cardui-header],[class*=sponsored-products],[class*=hybrid-widget-sponsored],[class*=adFeedbackMainComponent]');}catch(e){return false;}})(n)){"
               "n.style.setProperty('background-color','#181a1b','important');}"
             "}""n.__adBgBy='adpin1';"
             "if(n.querySelectorAll){var q=n.querySelectorAll('[class*=unfill],[class*=placehold]');"
               "for(var i=0;i<q.length;i++)q[i].style.setProperty('background-color','transparent','important');"
               "var q2=n.querySelectorAll('[class*=a-section]');"
               "for(var k2=0;k2<q2.length&&k2<200;k2++){var e2=q2[k2];"
                 "if(typeof onArt==='function'&&onArt(e2)){}else "
                 "if(e2.closest&&e2.closest('[class*=puis],[class*=s-result],[class*=s-card]')&&"
                   "!e2.closest('[class*=s-product-image],[class*=mlt-icon],[class*=puis-heart-position]')&&"
                   "!(e2.querySelector&&e2.querySelector("
                     "'[class*=mlt-icon],[class*=puis-heart-position],[class*=lists-framework-action]'))){"
"if(!(function(x){try{return x.closest&&x.closest('[class*=a-cardui-header],[class*=sponsored-products],[class*=hybrid-widget-sponsored],[class*=adFeedbackMainComponent]');}catch(e){return false;}})(e2)){"
                   "e2.style.setProperty('background-color','#181a1b','important');}}}"
             "}""e2.__adBgBy='adpin2';"
           "}catch(e){}};"
           "new MutationObserver(function(ms){for(var i=0;i<ms.length;i++){var m=ms[i];"
             "if(m.type==='attributes'){__adPin(m.target);continue;}"
             "for(var j=0;j<m.addedNodes.length;j++)__adPin(m.addedNodes[j]);}})"
             ".observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['class']});"
           "var __adSnap=function(t){try{"
             "var u=document.querySelector('[class*=lists-framework-unfill]');"
             "var pp=document.querySelector('[class*=heart-placeholder]');"
             "var d=function(x){if(!x)return '-';var cs=getComputedStyle(x);"
               "return (cs.backgroundColor||'').replace(/ /g,'')+'/'+(cs.backgroundImage==='none'?'-':'Y')+'/'+String(cs.filter).slice(0,24);};"
             "window.__AD_EARLY__+=' t'+t+'[u:'+d(u)+'|p:'+d(pp)+']';"
           "}catch(e){}};"
           "setTimeout(function(){__adSnap(120);},120);"
           "setTimeout(function(){__adSnap(400);},400);"
           "setTimeout(function(){__adSnap(900);},900);"
         "}catch(e){}"
         "%@\n" // DarkReader UMD
         // ── AD FRAME GATE ───────────────────────────────────────────────────────
         // Gate the ENGINE out of ad content instead of hunting for elements to
         // protect. Ten builds went into identifying which element draws a star or a
         // caption; none of that was needed. Ad creatives render correctly on their
         // own -- black text on a light card, orange stars -- and every symptom here
         // (text flipping to grey then back, stars going white, black boxes behind
         // captions) is our engine arriving after first paint and repainting content
         // that was already right. So an ad document is left completely stock.
         //
         // Two doors have to be shut, not one. This is the first: the engine running
         // INSIDE the ad frame, since the user scripts are forMainFrameOnly:NO.
         "try{window.__ADFRAMESKIP__=(function(){try{"
           "if(window.top===window)return 0;"
           "var h=String(location.href||'')+' '+String(document.referrer||'');"
           "return 1;"
         "}catch(e){return 0;}})();}catch(e){}"
         // CHILD AD FRAMES (v5.361): keep authored creative styling stock. Dark
         // Reader remains fully gated out. White Background Taming runs separately
         // against media/background paint only so DOM copy is never recoloured or
         // composited underneath a whole-frame filter.
         "if(window.top!==window){try{"
           // Keep reporting alive: FIXCONTRAST is where the child-frame poster lives,
           // so a bare stub would make this frame invisible in the log.
           "window.__AMZDARK_FIXCONTRAST__=function(){"
             "try{if(window.__ADPOST__)window.__ADPOST__();}catch(e){}return -3;};"
           // v5.361: child ad frames stay visually STOCK. Dark Reader is gated out,
           // and we no longer recolour their text/background/borders with a second
           // home-grown theme. White Background Taming gets a separate media-only
           // pass so video/photo paint can be toned without filtering the iframe as
           // a whole (which also filtered the headline and made it look behind the tame).
           // v5.362: two explicitly separate child-ad paths. Tall/square top-carousel
           // creatives keep authored STOCK text; short/wide standalone placements use
           // the proven v5.360 custom dark ad theme. The child can classify itself from
           // viewport shape on first paint; the parent may refine the mode by postMessage.
           "window.__AD_PRODUCTREF369__=(function(){try{var u=String(document.referrer||'').toLowerCase();return u.indexOf('/dp/')>=0||u.indexOf('/gp/aw/d/')>=0||u.indexOf('/gp/product/')>=0||u.indexOf('/s?')>=0||u.indexOf('/search')>=0||u.indexOf('?k=')>=0||u.indexOf('&k=')>=0||u.indexOf('field-keywords=')>=0;}catch(e){return false;}})();window.__ADFRAME_MODE__=window.__AD_PRODUCTREF369__?'productad':(((innerHeight||0)<180||((innerWidth||1)/(innerHeight||1))>2.25)?'standalone':'hero');"
           "try{addEventListener('message',function(ev){try{var d=ev.data;if(d&&d.__amzAdMode){var nm=String(d.__amzAdMode||'');if(window.__AD_PRODUCTREF369__&&nm==='standalone')nm='productad';window.__ADFRAME_MODE__=nm;window.__AD_HEROFAST365__&&window.__AD_HEROFAST365__(document.documentElement);window.__AMZDARK_ADTHEME__&&window.__AMZDARK_ADTHEME__();}}catch(e){};});}catch(e){}"
           "var AF={p:function(c){try{var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)(?:,\\s*([0-9.]+))?\\)/.exec(c||'');"
             "if(!m)return null;return{r:+m[1],g:+m[2],b:+m[3],a:m[4]===undefined?1:+m[4]};}catch(e){return null;}},"
             "l:function(x){return (0.2126*x.r+0.7152*x.g+0.0722*x.b)/255;},"
             "s:function(x){var mx=Math.max(x.r,x.g,x.b),mn=Math.min(x.r,x.g,x.b);return (mx-mn)/255;}};"
           // v5.300: ad iframes are now fully stock. P9CONTRAST returns none on the
           // carousel creatives, and the probe cannot run in child frames -- so those
           // cards live in ad iframes, where ADFRAMESKIP already keeps Dark Reader out.
           // This minimal theme was therefore the only thing still painting them, and
           // its luminance guesses are the dark-on-dark text and the plates behind
           // captions. Reporting kept, all writes removed.
           "window.__AMZDARK_ADTHEME_STANDALONE__=function(){try{"
             "if(!document.body)return -1;"
             "if(!document.getElementById('adfrstand362')){var st=document.createElement('style');"
               "st.id='adfrstand362';st.textContent='html,body{background-color:#181a1b !important;}'"
                 // The blue box is a focus ring left behind after the Sponsored
                 // disclosure sheet closes -- the element keeps :focus, and WebKit
                 // paints the default highlight. Suppressed for tap targets only.
                 "+'*{-webkit-tap-highlight-color:transparent !important;}'"
                 "+'*:focus,*:focus-visible{outline:none !important;box-shadow:none !important;}';"
               "(document.head||document.documentElement).appendChild(st);}"
             "var E=document.querySelectorAll('*'),nb=0,nt=0,nbd=0;"
             "for(var i=0;i<E.length&&i<900;i++){var e=E[i];var tg=e.tagName;"
               "if(tg==='IMG'||tg==='PICTURE'||tg==='VIDEO'||tg==='CANVAS'"
                 "||tg==='SVG'||tg==='svg'||tg==='USE'||tg==='PATH')continue;"
               "var cs=getComputedStyle(e);"
               // A background-image is not automatically artwork. The second creative
               // template keeps its whole lower block white because the wrapper carries
               // one, and skipping on its mere presence left the entire card stock.
               // Only a RASTER url on a reasonably large box counts as a picture;
               // gradients and tiny spacer images are just paint and may be darkened.
               "var bgi9=String(cs.backgroundImage||'');"
               "var isArt9=false;"
               "if(bgi9.indexOf('url(')>=0){"
                 "var rc9=e.getBoundingClientRect();"
                 "isArt9=(rc9.width>=60&&rc9.height>=60);"
                 "if(isArt9&&/\\.(svg)(\\?|\\)|$)/i.test(bgi9))isArt9=false;}"
               // A LIGHT CHIP BEHIND A BRAND MARK STAYS LIGHT. Images are never
               // repainted (rule 3), so darkening the white disc behind a logo leaves
               // dark ink on a dark ground -- the Liquid Death mark went practically
               // invisible that way. Keeping the chip stock is the fix, because it
               // preserves the brand exactly as drawn instead of altering artwork.
               "var chip9=false;"
               "try{var cr9b=e.getBoundingClientRect();"
                 "if(cr9b.width<=120&&cr9b.height<=120&&e.querySelector"
                   "&&e.querySelector('img,svg,picture'))chip9=true;}catch(e9){}"
               "if(e.hasAttribute&&e.hasAttribute('data-ad-sponrow367')){e.style.setProperty('background-color','transparent','important');e.style.setProperty('background-image','none','important');e.style.setProperty('box-shadow','none','important');continue;}""if(!isArt9&&!chip9){"
                 "var bg=AF.p(cs.backgroundColor);"
                 "if(bg&&bg.a>0.3&&AF.l(bg)>0.6){"
                   "e.style.setProperty('background-color','#181a1b','important');nb++;}"
                 "if(bgi9.indexOf('gradient')>=0&&bgi9.indexOf('url(')<0){"
                   "e.style.setProperty('background-image','none','important');"
                   "e.style.setProperty('background-color','#181a1b','important');nb++;}}"
               // RULE 4: LIFT A DARK MONOCHROME LOGO. Images are never repainted, which
               // is right for photos and stars -- but a black wordmark on a card we
               // just darkened is invisible, and there is no light chip behind this
               // one to preserve. Measured, not guessed: mostly transparent, near
               // black, neutral. A colour logo or a photo fails the test and is left
               // exactly as drawn. Cached by src so each asset is measured once.
               "if(tg==='IMG'){try{"
                 "var lsrc=String(e.currentSrc||e.src||'');"
                 "if(lsrc&&!e.__adLogoDone){e.__adLogoDone=1;"
                   "if(!window.__ADLOGOC__)window.__ADLOGOC__={};"
                   "var lv=window.__ADLOGOC__[lsrc];"
                   "if(lv===1){e.style.setProperty('filter','invert(1)','important');}"
                   "else if(lv===undefined){"
                     "var li=new Image();li.crossOrigin='anonymous';"
                     "li.onload=function(){try{"
                       "var lw=Math.min(li.naturalWidth||32,32),lh=Math.min(li.naturalHeight||32,32);"
                       "if(!lw||!lh)return;"
                       "var lc=document.createElement('canvas');lc.width=lw;lc.height=lh;"
                       "var lx=lc.getContext('2d');lx.drawImage(li,0,0,lw,lh);"
                       "var ld=lx.getImageData(0,0,lw,lh).data;"
                       "var tot=0,clr=0,sum=0,cnt=0,lite=0,sat=0;"
                       "for(var z=0;z<ld.length;z+=4){tot++;"
                         "if(ld[z+3]<40){clr++;continue;}"
                         "var lz=0.2126*ld[z]+0.7152*ld[z+1]+0.0722*ld[z+2];"
                         "sum+=lz;cnt++;if(lz>153)lite++;"
                         "var mx=ld[z]>ld[z+1]?ld[z]:ld[z+1];if(ld[z+2]>mx)mx=ld[z+2];"
                         "var mn=ld[z]<ld[z+1]?ld[z]:ld[z+1];if(ld[z+2]<mn)mn=ld[z+2];"
                         "sat+=(mx-mn);}"
                       "if(!cnt||!tot)return;"
                       "var cf=clr/tot,av=(sum/cnt)/255,lf2=lite/cnt,sf2=((sat/cnt)/255);"
                       "var ok=(cf>0.35&&av<0.30&&lf2<0.10&&sf2<0.10);"
                       "window.__ADLOGOC__[lsrc]=ok?1:0;"
                       "if(ok){e.style.setProperty('filter','invert(1)','important');"
                         "window.__AD_ADLOGO__=(window.__AD_ADLOGO__||0)+1;}"
                     "}catch(e2){}};"
                     "li.onerror=function(){window.__ADLOGOC__[lsrc]=0;};"
                     "li.src=lsrc;}}"
               "}catch(e){}}"
               // NOT LEAF-ONLY. A label that wraps its text plus an icon -- "Sponsored"
               // with its info glyph -- has childElementCount 1 and was therefore never
               // recoloured, while rule 1 darkened the card around it. That is why the
               // card goes dark and the label stays dark, and why every main-document
               // measurement looked healthy: the element was never a candidate here.
               // The test is now "does this element own a direct text node", which is
               // what actually determines whether it paints glyphs.
               "var ownTxt='';try{for(var cn=0;cn<e.childNodes.length&&cn<12;cn++){"
                 "var nd=e.childNodes[cn];"
                 "if(nd.nodeType===3)ownTxt+=String(nd.nodeValue||'');}"
               "}catch(e3){}"
               "var themeTxt=ownTxt.trim();try{if(!themeTxt&&e.childElementCount<=2&&!e.querySelector('img,svg,picture,video,canvas')){var tx9=String(e.textContent||'').replace(/\\s+/g,' ').trim();if(tx9.length>0&&tx9.length<140)themeTxt=tx9;}}catch(et){}"
               "if(themeTxt){"
                 "var fg=AF.p(cs.color);"
                 // 0.78, not 0.5. ADFRAME reported text=0 while a visibly dim label sat
                 // right there: the rule demanded near-BLACK ink, so a mid-grey
                 // secondary label ("Sponsored") never qualified. Saturation still does
                 // the real work -- blue prime and red badges stay untouched -- so
                 // raising the luminance ceiling only catches greys that should match
                 // the card's other text anyway.
                 "if(fg&&AF.l(fg)<0.78&&AF.s(fg)<0.12){"
               "e.style.setProperty('color','#e8e6e3','important');e.style.setProperty('-webkit-text-fill-color','#e8e6e3','important');nt++;}}"
               "try{var BS=['Top','Right','Bottom','Left'];"
                 "for(var bi=0;bi<4;bi++){"
                   "var bw=parseFloat(cs['border'+BS[bi]+'Width'])||0;if(bw<0.5)continue;"
                   "var bsty=cs['border'+BS[bi]+'Style'];if(bsty==='none'||bsty==='hidden')continue;"
                   "var bcp=AF.p(cs['border'+BS[bi]+'Color']);"
                   "if(bcp&&bcp.a>0.3&&AF.l(bcp)>0.6&&AF.s(bcp)<0.12){"
                     "e.style.setProperty('border-'+BS[bi].toLowerCase()+'-color','#3b3c3e','important');nbd++;}}"
               "}catch(eb){}e.__adStand362=1;"
               "}"
             "window.__AD_STANDALONE__='bg='+nb+' text='+nt+' border='+nbd+' logo='+(window.__AD_ADLOGO__||0);return nb+nt+nbd;"
           "}catch(e){window.__AD_STANDALONE__='err '+e;return -1;}};"
           // v5.370: product/search ad frames keep the box/chrome removal from v5.369.
           // Repair dark neutral copy (including WebKit text-fill) without restoring
           // any background/chrome painter. White Background Taming stays media-only.
           "window.__AD_ADTEXT371__=function(){try{if(!document.body)return 0;var mode=String(window.__ADFRAME_MODE__||''),sticky=!!window.__AD_STRIPCONF375__,compact=(mode==='standalone'&&(innerWidth||0)>=240&&(innerHeight||999)<=190);if(mode!=='productad'&&!compact&&!sticky){window.__AD_ADTEXT371_N__=0;window.__AD_ADTEXT371_LEFT__=0;window.__AD_ADTEXT371_ROOTS__=1;window.__AD_ADVIS375_N__=0;window.__AD_ADTEXT376_LOCKED__=0;window.__AD_ADTEXT376_GRAYLEFT__=0;window.__AD_COMPACT371__=0;return 0;}var roots=[document],ri=0;while(ri<roots.length&&roots.length<24){var rt=roots[ri++],H=[];try{H=rt.querySelectorAll?rt.querySelectorAll('*'):[];}catch(er){H=[];}for(var hi=0;hi<H.length&&hi<1000&&roots.length<24;hi++){var sr=H[hi].shadowRoot;if(sr&&roots.indexOf(sr)<0)roots.push(sr);}}var n=0,left=0,vis=0,locked=0,grayleft=0,budget=0;for(var rr=0;rr<roots.length&&budget<3000;rr++){var R=roots[rr],E=[];try{E=R.querySelectorAll?R.querySelectorAll('*'):[];}catch(eq){E=[];}for(var i=0;i<E.length&&budget++<3000;i++){var e=E[i],tg=String(e.tagName||'').toUpperCase();if(tg==='IMG'||tg==='PICTURE'||tg==='VIDEO'||tg==='CANVAS'||tg==='SVG'||tg==='USE'||tg==='PATH'||tg==='SCRIPT'||tg==='STYLE'||tg==='INPUT'||tg==='TEXTAREA'||tg==='SELECT'||tg==='OPTION')continue;var own='';try{for(var q=0;q<e.childNodes.length&&q<14;q++){var nd=e.childNodes[q];if(nd.nodeType===3)own+=String(nd.nodeValue||'');}}catch(et){}var txt=own.replace(/\\s+/g,' ').trim();try{if(!txt&&e.childElementCount<=2&&!e.querySelector('img,svg,picture,video,canvas,input,select,textarea')){var tx=String(e.textContent||'').replace(/\\s+/g,' ').trim();if(tx.length>0&&tx.length<260)txt=tx;}}catch(ex){}if(!txt)continue;if(sticky){try{var vr=e.getBoundingClientRect();if(vr.width>1&&vr.height>1){var vc=getComputedStyle(e),changed=false;if(parseFloat(vc.opacity||'1')<0.92){e.style.setProperty('opacity','1','important');changed=true;}if(vc.visibility==='hidden'||vc.visibility==='collapse'){e.style.setProperty('visibility','visible','important');changed=true;}var up=e.parentElement,ud=0;while(up&&up!==document.body&&ud++<3){var uc=getComputedStyle(up),ur=up.getBoundingClientRect();if(ur.width<1||ur.height<1)break;if(parseFloat(uc.opacity||'1')<0.92){up.style.setProperty('opacity','1','important');changed=true;}if(uc.visibility==='hidden'||uc.visibility==='collapse'){up.style.setProperty('visibility','visible','important');changed=true;}up=up.parentElement;}if(changed)vis++;}}catch(ev){}}var cs=getComputedStyle(e),fg=AF.p(cs.color),ff=AF.p(cs.webkitTextFillColor||cs.getPropertyValue('-webkit-text-fill-color')),fl=AF.p(cs.fill),nf=!!(fg&&AF.s(fg)<0.34),nff=!!(ff&&AF.s(ff)<0.34),nfl=!!(fl&&AF.s(fl)<0.34),bad=sticky?(nf||nff||((tg==='TEXT'||tg==='TSPAN')&&nfl)):((fg&&((fg.a!==undefined&&fg.a<0.20)||(AF.l(fg)<0.72&&AF.s(fg)<0.26)))||(ff&&((ff.a!==undefined&&ff.a<0.20)||(AF.l(ff)<0.72&&AF.s(ff)<0.26)))||((tg==='TEXT'||tg==='TSPAN')&&fl&&AF.l(fl)<0.72&&AF.s(fl)<0.26));if(!bad)continue;var ink=sticky?'#ffffff':'#e8e6e3';e.style.setProperty('color',ink,'important');e.style.setProperty('-webkit-text-fill-color',ink,'important');e.style.setProperty('opacity','1','important');e.style.setProperty('visibility','visible','important');if(tg==='TEXT'||tg==='TSPAN')e.style.setProperty('fill',ink,'important');e.setAttribute(sticky?'data-ad-adtext376':'data-ad-adtext371','1');e.__adBy=sticky?'adText376':'adText375';n++;if(sticky)locked++;try{var cs2=getComputedStyle(e),fg2=AF.p(cs2.color),ff2=AF.p(cs2.webkitTextFillColor||cs2.getPropertyValue('-webkit-text-fill-color'));if(sticky){if((fg2&&AF.s(fg2)<0.34&&AF.l(fg2)<0.92)||(ff2&&AF.s(ff2)<0.34&&AF.l(ff2)<0.92))grayleft++;}else if((fg2&&AF.l(fg2)<0.60&&AF.s(fg2)<0.26)||(ff2&&AF.l(ff2)<0.60&&AF.s(ff2)<0.26))left++;}catch(ec){}}}window.__AD_ADTEXT371_N__=n;window.__AD_ADTEXT371_LEFT__=left;window.__AD_ADTEXT371_ROOTS__=roots.length;window.__AD_ADVIS375_N__=vis;window.__AD_ADTEXT376_LOCKED__=locked;window.__AD_ADTEXT376_GRAYLEFT__=grayleft;window.__AD_COMPACT371__=compact?1:0;return n;}catch(e){window.__AD_ADTEXT371_N__=-1;window.__AD_ADTEXT376_GRAYLEFT__=-1;return 0;}};"
           // v5.377: text-node lock for confirmed Sponsored strips. v5.376
           // still depended on element shape/direct-child counts, so some Amazon
           // creative templates could leave a neutral title/price black. Walk the
           // actual text nodes, clear text-only compositor filters, and pin every
           // neutral live text painter to pure white. Saturated Prime/star/deal paint
           // is preserved. A short rAF insurance lane below closes first-paint races.
           "window.__AD_STRIPTEXT377__=function(){try{if(!document.body||!window.__AD_STRIPCONF375__){window.__AD_STRIPTEXT377_N__=0;window.__AD_STRIPTEXT377_DARK__=0;window.__AD_STRIPTEXT377_FILTERS__=0;window.__AD_STRIPTEXT377_FULL__=0;return 0;}if(!document.getElementById('adfrstripink377')){var st377=document.createElement('style');st377.id='adfrstripink377';st377.textContent='[data-ad-striptext377]{color:#fff !important;-webkit-text-fill-color:#fff !important;opacity:1 !important;visibility:visible !important;filter:none !important;mix-blend-mode:normal !important;text-shadow:none !important;}[data-ad-striptext377]::before,[data-ad-striptext377]::after{color:#fff !important;-webkit-text-fill-color:#fff !important;}';(document.head||document.documentElement).appendChild(st377);}var roots=[document],ri=0;while(ri<roots.length&&roots.length<24){var rt=roots[ri++],AA=[];try{AA=rt.querySelectorAll?rt.querySelectorAll('*'):[];}catch(er){AA=[];}for(var ai=0;ai<AA.length&&ai<1200&&roots.length<24;ai++){var sr=AA[ai].shadowRoot;if(sr&&roots.indexOf(sr)<0)roots.push(sr);}}var n=0,dark=0,filters=0,budget=0,full=0,W=innerWidth||390,H=innerHeight||125;try{var IM=document.querySelectorAll('img,canvas,video');for(var im=0;im<IM.length&&im<80;im++){var ir=IM[im].getBoundingClientRect();if(ir.width>=W*.72&&ir.height>=H*.68)full++;}}catch(ei){}for(var rr=0;rr<roots.length&&budget<900;rr++){var R=roots[rr],tw=null;try{tw=document.createTreeWalker(R,NodeFilter.SHOW_TEXT,null);}catch(et){tw=null;}if(!tw)continue;var nd;while((nd=tw.nextNode())&&budget++<900){var txt=String(nd.nodeValue||'').replace(/\\s+/g,' ').trim();if(!txt)continue;var e=nd.parentElement;if(!e)continue;var tg=String(e.tagName||'').toUpperCase();if(tg==='SCRIPT'||tg==='STYLE'||tg==='NOSCRIPT'||tg==='TEXTAREA'||tg==='OPTION')continue;var cs=getComputedStyle(e),fg=AF.p(cs.color),ff=AF.p(cs.webkitTextFillColor||cs.getPropertyValue('-webkit-text-fill-color')),sat=Math.max(fg?AF.s(fg):0,ff?AF.s(ff):0);if(sat>=0.36)continue;if(e.hasAttribute&&e.hasAttribute('data-darkreader-inline-color'))e.removeAttribute('data-darkreader-inline-color');e.style.setProperty('--darkreader-inline-color','#ffffff','important');e.style.setProperty('color','#ffffff','important');e.style.setProperty('-webkit-text-fill-color','#ffffff','important');e.style.setProperty('opacity','1','important');e.style.setProperty('visibility','visible','important');e.style.setProperty('filter','none','important');e.style.setProperty('mix-blend-mode','normal','important');e.style.setProperty('text-shadow','none','important');e.setAttribute('data-ad-striptext377','1');e.__adBy='stripText377';var up=e.parentElement,ud=0;while(up&&up!==document.body&&ud++<5){var uc=getComputedStyle(up),uf=String(uc.filter||'none');if(uf!=='none'){up.style.setProperty('filter','none','important');filters++;}if(parseFloat(uc.opacity||'1')<0.99)up.style.setProperty('opacity','1','important');if(uc.visibility==='hidden'||uc.visibility==='collapse')up.style.setProperty('visibility','visible','important');if(String(uc.mixBlendMode||'normal')!=='normal')up.style.setProperty('mix-blend-mode','normal','important');up=up.parentElement;}var etg=String(e.tagName||'').toUpperCase();if(etg==='TEXT'||etg==='TSPAN')e.style.setProperty('fill','#ffffff','important');n++;var c2=getComputedStyle(e),p2=AF.p(c2.color),f2=AF.p(c2.webkitTextFillColor||c2.getPropertyValue('-webkit-text-fill-color'));if((p2&&AF.s(p2)<.36&&AF.l(p2)<.94)||(f2&&AF.s(f2)<.36&&AF.l(f2)<.94))dark++;}}window.__AD_STRIPTEXT377_N__=n;window.__AD_STRIPTEXT377_DARK__=dark;window.__AD_STRIPTEXT377_FILTERS__=filters;window.__AD_STRIPTEXT377_FULL__=full;return n;}catch(e){window.__AD_STRIPTEXT377_N__=-1;window.__AD_STRIPTEXT377_DARK__=-1;return 0;}};"
           // v5.378: a few Home standalone creatives hydrate a small neutral-white
           // badge/chrome rectangle after the large-container clear pass. Darken only
           // compact neutral structural boxes; saturated deal/Prime paint is untouched.
           // v5.379: compact Sponsored text must be readable even when Amazon never sends
           // a productad/standalone mode. This pass changes TEXT ONLY and is geometry+Sponsored gated.
           "window.__AD_ANYSPONINK379__=function(){try{if(!document.body)return 0;var w=innerWidth||0,h=innerHeight||999;if(w<240||w>560||h>210){window.__AD_ANYSPON379_N__=0;window.__AD_ANYSPON379_DARK__=0;window.__AD_ANYSPON379_ROOTS__=0;return 0;}var bt=String(document.body.innerText||document.body.textContent||'').replace(/\\s+/g,' ').trim();if(!bt||bt.length>1800||/captcha|verify you are human|sign[ -]?in|checkout/i.test(bt)){window.__AD_ANYSPON379_N__=0;window.__AD_ANYSPON379_DARK__=0;window.__AD_ANYSPON379_ROOTS__=0;return 0;}var media=!!document.querySelector('img,picture,video,canvas'),adlike=/\\bsponsored(?: ad)?\\b|advertis|\\$\\s*\\d|\\d(?:\\.\\d)?\\s*out of 5/i.test(bt);if(!adlike&&!media){window.__AD_ANYSPON379_N__=0;window.__AD_ANYSPON379_DARK__=0;window.__AD_ANYSPON379_ROOTS__=0;return 0;}function pc(v){var m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/.exec(String(v||''));return m?[+m[1],+m[2],+m[3]]:null;}var roots=[document],ri=0;while(ri<roots.length&&roots.length<32){var rt=roots[ri++],H=[];try{H=rt.querySelectorAll?rt.querySelectorAll('*'):[];}catch(er){H=[];}for(var hi=0;hi<H.length&&hi<1400&&roots.length<32;hi++){var sr=H[hi].shadowRoot;if(sr&&roots.indexOf(sr)<0)roots.push(sr);}}var n=0,dark=0,budget=0;for(var rr=0;rr<roots.length&&budget<4200;rr++){var R=roots[rr],E=[];try{E=R.querySelectorAll?R.querySelectorAll('span,p,a,div,h1,h2,h3,h4,h5,label,strong,b,small'):[];}catch(eq){E=[];}for(var i=0;i<E.length&&budget++<4200;i++){var e=E[i],own='';for(var q=0;q<e.childNodes.length&&q<14;q++){if(e.childNodes[q].nodeType===3)own+=String(e.childNodes[q].nodeValue||'');}own=own.replace(/\\s+/g,' ').trim();if(!own&&e.childElementCount<=2&&!e.querySelector('img,svg,picture,video,canvas,input,select,textarea')){var ft=String(e.textContent||'').replace(/\\s+/g,' ').trim();if(ft.length>0&&ft.length<=360)own=ft;}if(!own||own.length>360)continue;var cs=getComputedStyle(e),c=pc(cs.color),f=pc(cs.webkitTextFillColor||cs.getPropertyValue('-webkit-text-fill-color'));var base=c||f;if(!base)continue;var mx=Math.max(base[0],base[1],base[2]),mn=Math.min(base[0],base[1],base[2]),sat=(mx-mn)/255;if(sat>=.30)continue;e.style.setProperty('color','#ffffff','important');e.style.setProperty('-webkit-text-fill-color','#ffffff','important');e.style.setProperty('opacity','1','important');e.style.setProperty('visibility','visible','important');e.style.setProperty('filter','none','important');e.setAttribute('data-ad-anysponink379','1');e.__adBy='compactAdInk379';var up=e.parentElement,ud=0;while(up&&ud++<2){var uc=getComputedStyle(up);if(String(uc.filter||'none')!=='none')up.style.setProperty('filter','none','important');if(parseFloat(uc.opacity||'1')<.92)up.style.setProperty('opacity','1','important');if(uc.visibility==='hidden'||uc.visibility==='collapse')up.style.setProperty('visibility','visible','important');up=up.parentElement;}n++;var c2=pc(getComputedStyle(e).color),f2=pc(getComputedStyle(e).webkitTextFillColor||getComputedStyle(e).getPropertyValue('-webkit-text-fill-color'));function bad(q){return q&&(.2126*q[0]+.7152*q[1]+.0722*q[2])/255<.92;}if(bad(c2)||bad(f2))dark++;}}window.__AD_ANYSPON379_N__=n;window.__AD_ANYSPON379_DARK__=dark;window.__AD_ANYSPON379_ROOTS__=roots.length;return n;}catch(e){window.__AD_ANYSPON379_N__=-1;window.__AD_ANYSPON379_DARK__=-1;window.__AD_ANYSPON379_ROOTS__=-1;return 0;}};"
           // v5.382: Home standalone-only inverse scrub. A late Dark Reader pass can
           // recreate one large neutral OLED-black structural wrapper even though html/body
           // and the iframe parent are transparent. Clear only large non-media dark-neutral
           // wrappers in HOME standalone children; product/PDP strips are excluded.
           "window.__AD_STANDDARK382__=function(){try{var mode=String(window.__ADFRAME_MODE__||''),home=(mode==='standalone'&&!window.__AD_PRODUCTREF369__);if(!home||!document.body){window.__AD_STANDDARK382_N__=0;window.__AD_STANDDARK382_LEFT__=0;return 0;}if(!document.getElementById('adstanddark382')){var st=document.createElement('style');st.id='adstanddark382';st.textContent='[data-ad-standdark382]{background-color:transparent !important;background-image:none !important;box-shadow:none !important;}[data-ad-standdarkbefore382]::before,[data-ad-standdarkafter382]::after{background-color:transparent !important;background-image:none !important;box-shadow:none !important;}';(document.head||document.documentElement).appendChild(st);}function pc(v){var m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([0-9.]+))?/i.exec(String(v||''));return m?[+m[1],+m[2],+m[3],m[4]===undefined?1:+m[4]]:null;}var W=innerWidth||390,H=innerHeight||130,E=document.querySelectorAll('div,section,article,a,span'),n=0,left=0;for(var i=0;i<E.length&&i<1800;i++){var e=E[i],r=e.getBoundingClientRect();if(r.width<W*.45||r.height<H*.34)continue;if(e.querySelector&&e.querySelector(':scope > img,:scope > video,:scope > canvas'))continue;var cs=getComputedStyle(e),bi=String(cs.backgroundImage||'none'),bg=pc(cs.backgroundColor);if(!bg||bg[3]<.55||bi.indexOf('url(')>=0)continue;var mx=Math.max(bg[0],bg[1],bg[2]),mn=Math.min(bg[0],bg[1],bg[2]),lum=(.2126*bg[0]+.7152*bg[1]+.0722*bg[2])/255,sat=(mx-mn)/255;if(lum>.12||sat>.12)continue;e.setAttribute('data-ad-standdark382','1');e.style.setProperty('background-color','transparent','important');if(bi!=='none')e.style.setProperty('background-image','none','important');e.style.setProperty('box-shadow','none','important');try{var b=getComputedStyle(e,'::before'),a=getComputedStyle(e,'::after'),bc=pc(b.backgroundColor),ac=pc(a.backgroundColor);if(bc&&bc[3]>.55&&(.2126*bc[0]+.7152*bc[1]+.0722*bc[2])/255<.12)e.setAttribute('data-ad-standdarkbefore382','1');if(ac&&ac[3]>.55&&(.2126*ac[0]+.7152*ac[1]+.0722*ac[2])/255<.12)e.setAttribute('data-ad-standdarkafter382','1');}catch(px){}n++;}var Q=document.querySelectorAll('[data-ad-standdark382]');for(var j=0;j<Q.length;j++){var q=pc(getComputedStyle(Q[j]).backgroundColor);if(q&&q[3]>.55&&(.2126*q[0]+.7152*q[1]+.0722*q[2])/255<.12)left++;}window.__AD_STANDDARK382_N__=n;window.__AD_STANDDARK382_LEFT__=left;return n;}catch(e){window.__AD_STANDDARK382_N__=-1;window.__AD_STANDDARK382_LEFT__=-1;return 0;}};"
           // v5.379: remove only the small neutral-white chrome. Do NOT paint it OLED black.
           "window.__AD_STRIPCHROME379__=function(){try{if(!document.body||!window.__AD_STRIPCONF375__){window.__AD_STRIPCHROME379_N__=0;window.__AD_STRIPCHROME379_LEFT__=0;return 0;}function pc(v){var m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([0-9.]+))?/i.exec(String(v||''));return m?[+m[1],+m[2],+m[3],m[4]===undefined?1:+m[4]]:null;}var E=document.querySelectorAll('div,span,a,label,section,button'),n=0,left=0;for(var i=0;i<E.length&&i<1400;i++){var e=E[i],r=e.getBoundingClientRect();if(r.width<18||r.width>240||r.height<10||r.height>70)continue;var c=getComputedStyle(e),bg=pc(c.backgroundColor);if(!bg||bg[3]<.55)continue;var mx=Math.max(bg[0],bg[1],bg[2]),mn=Math.min(bg[0],bg[1],bg[2]),lum=(.2126*bg[0]+.7152*bg[1]+.0722*bg[2])/255,sat=(mx-mn)/255;if(lum<.80||sat>.14)continue;if(e.querySelector&&e.querySelector('img,video,canvas'))continue;e.setAttribute('data-ad-stripchrome379','1');e.style.setProperty('background-color','transparent','important');e.style.setProperty('background-image','none','important');e.style.setProperty('box-shadow','none','important');e.style.setProperty('border-color','transparent','important');n++;}var Q=document.querySelectorAll('[data-ad-stripchrome379]');for(var j=0;j<Q.length;j++){var q=pc(getComputedStyle(Q[j]).backgroundColor);if(q){var l=(.2126*q[0]+.7152*q[1]+.0722*q[2])/255;if(l>.70)left++;}}window.__AD_STRIPCHROME379_N__=n;window.__AD_STRIPCHROME379_LEFT__=left;return n;}catch(e){window.__AD_STRIPCHROME379_N__=-1;return 0;}};"
           // v5.373: the 396x62-style Sponsored strip is text/chrome in its own
           // child frame while the product artwork may be painted separately by the
           // host page. Never run background taming in this child. Make every solid
           // structural layer transparent, preserve URL-backed artwork, and tame only
           // actual IMG/VIDEO/CANVAS media if the template contains any.
           "window.__AD_COMPACTSTRIP373__=function(){try{if(!document.body||String(window.__ADFRAME_MODE__||'')!=='standalone')return 0;var w=innerWidth||0,h=innerHeight||999;if(w<280||h>100)return 0;var tx=String(document.body.innerText||document.body.textContent||'').replace(/\\s+/g,' ').trim();var ok=/\\bsponsored(?: ad)?\\b/i.test(tx);window.__AD_COMPACTSTRIP373_N__=ok?1:0;if(ok){try{window.top.postMessage({__adCompact373:1},'*');}catch(ep){}}return ok?1:0;}catch(e){window.__AD_COMPACTSTRIP373_N__=0;return 0;}};"
           "window.__AD_CLEARSTAND373__=function(){try{var n=0,left=0,st=document.getElementById('adfrstand362');if(st&&st.parentNode){st.parentNode.removeChild(st);n++;}var old=document.getElementById('adfrmin');if(old&&old.parentNode)old.parentNode.removeChild(old);var prod=document.getElementById('adfrproduct370');if(prod&&prod.parentNode)prod.parentNode.removeChild(prod);var oldc=document.getElementById('adfrcompact372');if(oldc&&oldc.parentNode)oldc.parentNode.removeChild(oldc);if(!document.getElementById('adfrcompact373')){var cs=document.createElement('style');cs.id='adfrcompact373';cs.textContent='html,body{background:transparent !important;background-color:transparent !important;}body *,body *::before,body *::after{background-color:transparent !important;box-shadow:none !important;outline-color:transparent !important;border-color:transparent !important;-webkit-backdrop-filter:none !important;backdrop-filter:none !important;}';(document.head||document.documentElement).appendChild(cs);}var W=innerWidth||390,H=innerHeight||80,E=document.querySelectorAll('*');for(var i=0;i<E.length&&i<1800;i++){var e=E[i],tg=String(e.tagName||'').toUpperCase(),media=(tg==='IMG'||tg==='PICTURE'||tg==='VIDEO'||tg==='CANVAS'||tg==='SVG'||tg==='USE'||tg==='PATH');if(media)continue;var r=e.getBoundingClientRect(),large=(r.width>=W*0.52&&r.height>=H*0.42),cs2=getComputedStyle(e),bi=String(cs2.backgroundImage||'none');if(large&&bi.indexOf('url(')<0&&bi!=='none'){e.style.setProperty('background-image','none','important');n++;}if(large){e.style.setProperty('background-color','transparent','important');e.style.setProperty('box-shadow','none','important');e.style.setProperty('outline','none','important');e.style.setProperty('border-color','transparent','important');e.style.setProperty('-webkit-backdrop-filter','none','important');e.style.setProperty('backdrop-filter','none','important');e.style.setProperty('filter','none','important');e.style.setProperty('mix-blend-mode','normal','important');e.style.setProperty('opacity','1','important');e.setAttribute('data-ad-compactclear373','1');n++;}if(e.__adStand362){e.__adStand362=0;}}try{var Q=document.querySelectorAll('[data-ad-tame362=\"bg\"]');for(var q=0;q<Q.length&&q<240;q++){var x=Q[q];x.style.removeProperty('background-color');x.style.removeProperty('background-blend-mode');x.removeAttribute('data-ad-tame362');x.__adTame362=0;x.__adPhoto365=0;n++;}}catch(er){}var C=document.querySelectorAll('html,body,[data-ad-compactclear373]');for(var c=0;c<C.length&&c<300;c++){var y=C[c],yr=y.getBoundingClientRect();if(y!==document.documentElement&&y!==document.body&&(yr.width<W*0.52||yr.height<H*0.42))continue;var sy=getComputedStyle(y),bc=String(sy.backgroundColor||'').replace(/\\s+/g,''),bim=String(sy.backgroundImage||'none'),sh=String(sy.boxShadow||'none');if(bc!=='rgba(0,0,0,0)'&&bc!=='transparent')left++;else if(bim!=='none'&&bim.indexOf('url(')<0)left++;else if(sh!=='none')left++;}window.__AD_CLEARSTAND373_N__=n;window.__AD_COMPACTCHROME373_LEFT__=left;return n;}catch(e){window.__AD_CLEARSTAND373_N__=-1;window.__AD_COMPACTCHROME373_LEFT__=-1;return 0;}};"
           "window.__AD_COMPACTMEDIA373__=function(){try{if(!window.__ADTAME_ON__){window.__AD_COMPACTMEDIA373_N__=0;return 0;}var S=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),bb=(1-0.50*(S/100)).toFixed(3),M=document.querySelectorAll('img,video,canvas'),n=0;for(var i=0;i<M.length&&i<160;i++){var e=M[i],r=e.getBoundingClientRect();if(r.width<26||r.height<26)continue;var cn=e.className;cn=String(cn&&cn.baseVal!==undefined?cn.baseVal:(cn||''));if(/sprite|icon|logo|pixel/i.test(cn))continue;var sig=String(e.currentSrc||e.src||e.poster||'')+'|'+bb;if(e.__adTame362===sig)continue;e.style.setProperty('filter','brightness('+bb+') saturate(1.08)','important');e.setAttribute('data-ad-tame362','media');e.__adTame362=sig;e.__adBy='compactMedia373';n++;}window.__AD_COMPACTMEDIA373_N__=n;window.__AD_ADTAME__='media373='+n+' bg=0 solid=0';return n;}catch(e){window.__AD_COMPACTMEDIA373_N__=-1;return 0;}};"
           // v5.374 consistency policy: all small Sponsored product strips use
           // ONE renderer regardless of whether Amazon/referrer calls the child
           // productad or standalone. Structural chrome is transparent, neutral copy
           // is pinned light, and White Background Taming is allowed on local media
           // only -- never on a row-sized raster or a background/container layer.
           "window.__AD_PRODUCTSTRIP375__=function(){try{if(!document.body)return 0;if(window.__AD_STRIPCONF375__){try{window.top.postMessage({__adStrip374:1},'*');}catch(ep0){}return 1;}var mode=String(window.__ADFRAME_MODE__||''),w=innerWidth||0,h=innerHeight||999,tx=String(document.body.innerText||document.body.textContent||'').replace(/\\s+/g,' ').trim(),spon=/\\bsponsored(?: ad)?\\b/i.test(tx),compactGeom=(w>=280&&h<=190),ok=(mode==='productad')||(compactGeom&&spon&&(mode==='standalone'||mode===''||mode==='hero'));window.__AD_STRIP375_SPON__=spon?1:0;if(ok){window.__AD_STRIPCONF375__=1;window.__AD_STRIP375_FIRSTMODE__=mode||'-';try{window.top.postMessage({__adStrip374:1},'*');}catch(ep){}}window.__AD_STRIP375_N__=ok?1:0;return ok?1:0;}catch(e){window.__AD_STRIP375_N__=0;return 0;}};"
           "window.__AD_CLEARSTRIP374__=function(){try{var n=0,left=0,W=innerWidth||390,H=innerHeight||125,ids=['adfrstand362','adfrmin','adfrproduct370','adfrcompact372','adfrcompact373'];for(var ii=0;ii<ids.length;ii++){var old=document.getElementById(ids[ii]);if(old&&old.parentNode){old.parentNode.removeChild(old);n++;}}if(!document.getElementById('adfrstrip374')){var st=document.createElement('style');st.id='adfrstrip374';st.textContent='html,body{background:transparent !important;background-color:transparent !important;}[data-ad-stripclear374]{background-color:transparent !important;box-shadow:none !important;outline:none !important;border-color:transparent !important;-webkit-backdrop-filter:none !important;backdrop-filter:none !important;mix-blend-mode:normal !important;opacity:1 !important;}[data-ad-stripbefore374]::before,[data-ad-stripafter374]::after{background-color:transparent !important;background-image:none !important;box-shadow:none !important;outline:none !important;border-color:transparent !important;filter:none !important;-webkit-backdrop-filter:none !important;backdrop-filter:none !important;}[data-ad-adtext371]{color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;}';(document.head||document.documentElement).appendChild(st);}var E=document.querySelectorAll('*');for(var i=0;i<E.length&&i<2200;i++){var e=E[i],tg=String(e.tagName||'').toUpperCase(),media=(tg==='IMG'||tg==='PICTURE'||tg==='VIDEO'||tg==='CANVAS'||tg==='SVG'||tg==='USE'||tg==='PATH');if(media)continue;var r=e.getBoundingClientRect(),large=(e===document.documentElement||e===document.body||(r.width>=W*0.45&&r.height>=H*0.38));if(!large)continue;var cs=getComputedStyle(e),bi=String(cs.backgroundImage||'none');e.style.setProperty('background-color','transparent','important');if(bi!=='none'&&bi.indexOf('url(')<0)e.style.setProperty('background-image','none','important');e.style.setProperty('box-shadow','none','important');e.style.setProperty('outline','none','important');e.style.setProperty('border-color','transparent','important');e.style.setProperty('-webkit-backdrop-filter','none','important');e.style.setProperty('backdrop-filter','none','important');e.style.setProperty('mix-blend-mode','normal','important');e.style.setProperty('opacity','1','important');var own=String(e.style.getPropertyValue('filter')||''),by=String(e.__adBy||'');if(e.hasAttribute('data-ad-tame362')||e.__adStand362||/brightness|contrast|saturate/i.test(own)||/adBg|whiteTame|adMedia|compactMedia/i.test(by))e.style.setProperty('filter','none','important');if(e.getAttribute('data-ad-tame362')==='bg'){e.style.removeProperty('background-blend-mode');e.removeAttribute('data-ad-tame362');e.__adTame362=0;}e.setAttribute('data-ad-stripclear374','1');n++;try{var bf=getComputedStyle(e,'::before'),af=getComputedStyle(e,'::after');var bfb=String(bf.backgroundColor||'').replace(/\\s+/g,''),afb=String(af.backgroundColor||'').replace(/\\s+/g,''),bfi=String(bf.backgroundImage||'none'),afi=String(af.backgroundImage||'none'),bfs=String(bf.boxShadow||'none'),afs=String(af.boxShadow||'none');if((bfb&&bfb!=='rgba(0,0,0,0)'&&bfb!=='transparent')||(bfi!=='none'&&bfi.indexOf('url(')<0)||bfs!=='none')e.setAttribute('data-ad-stripbefore374','1');if((afb&&afb!=='rgba(0,0,0,0)'&&afb!=='transparent')||(afi!=='none'&&afi.indexOf('url(')<0)||afs!=='none')e.setAttribute('data-ad-stripafter374','1');}catch(px){}}try{var BG=document.querySelectorAll('[data-ad-tame362=\"bg\"]');for(var b=0;b<BG.length&&b<500;b++){var x=BG[b];x.style.removeProperty('background-color');x.style.removeProperty('background-blend-mode');x.style.setProperty('filter','none','important');x.removeAttribute('data-ad-tame362');x.__adTame362=0;x.__adPhoto365=0;n++;}}catch(eb){}var C=document.querySelectorAll('html,body,[data-ad-stripclear374]');for(var c=0;c<C.length&&c<420;c++){var y=C[c],yr=y.getBoundingClientRect();if(y!==document.documentElement&&y!==document.body&&(yr.width<W*0.45||yr.height<H*0.38))continue;var sy=getComputedStyle(y),bc=String(sy.backgroundColor||'').replace(/\\s+/g,''),bim=String(sy.backgroundImage||'none'),sh=String(sy.boxShadow||'none'),fl=String(sy.filter||'none');if(bc!=='rgba(0,0,0,0)'&&bc!=='transparent')left++;else if(bim!=='none'&&bim.indexOf('url(')<0)left++;else if(sh!=='none'||fl!=='none')left++;}window.__AD_CLEARSTRIP374_N__=n;window.__AD_STRIPCHROME374_LEFT__=left;return n;}catch(e){window.__AD_CLEARSTRIP374_N__=-1;window.__AD_STRIPCHROME374_LEFT__=-1;return 0;}};"
           "window.__AD_STRIPMEDIA374__=function(){try{var W=innerWidth||390,H=innerHeight||125,n=0,skip=0,cleared=0;if(!window.__ADTAME_ON__){window.__AD_STRIPMEDIA374_N__=0;window.__AD_STRIPFULL374_N__=0;return 0;}try{var T=document.querySelectorAll('[data-ad-tame362]');for(var ti=0;ti<T.length&&ti<500;ti++){var te=T[ti],tt=String(te.tagName||'').toUpperCase();if(tt==='IMG'||tt==='VIDEO'||tt==='CANVAS')continue;te.style.setProperty('filter','none','important');te.style.removeProperty('background-blend-mode');te.style.removeProperty('background-color');te.removeAttribute('data-ad-tame362');te.__adTame362=0;cleared++;}}catch(ec){}var S=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),bb=(1-0.50*(S/100)).toFixed(3),M=document.querySelectorAll('img,video,canvas');for(var i=0;i<M.length&&i<220;i++){var e=M[i],r=e.getBoundingClientRect();if(r.width<26||r.height<26)continue;var cn=e.className;cn=String(cn&&cn.baseVal!==undefined?cn.baseVal:(cn||''));var src=String(e.currentSrc||e.src||e.poster||'');if(/sprite|icon|logo|pixel|placeholder|spacer/i.test(cn+' '+src))continue;var full=(r.width>W*0.64&&r.height>H*0.55)||(r.width*r.height>W*H*0.58);if(full){if(e.hasAttribute('data-ad-tame362')||/brightness/i.test(String(e.style.getPropertyValue('filter')||''))){e.style.setProperty('filter','none','important');e.removeAttribute('data-ad-tame362');e.__adTame362=0;}e.setAttribute('data-ad-stripfullskip374','1');e.__adBy='stripFullSkip374';skip++;continue;}var sig=src+'|'+bb;if(e.__adTame362===sig&&e.getAttribute('data-ad-tame362')==='media374'){n++;continue;}e.style.setProperty('filter','brightness('+bb+') saturate(1.08)','important');e.setAttribute('data-ad-tame362','media374');e.__adTame362=sig;e.__adBy='stripMedia374';n++;}window.__AD_STRIPMEDIA374_N__=n;window.__AD_STRIPFULL374_N__=skip;window.__AD_ADTAME__='strip374 media='+n+' bg=0 fullSkip='+skip+' cleared='+cleared;return n;}catch(e){window.__AD_STRIPMEDIA374_N__=-1;return 0;}};"
           "window.__AMZDARK_ADTAME__=function(){try{"
             "if(!document.body)return -1;"
             "if(!window.__ADTAME_ON__){window.__AD_ADTAME__='off';return 0;}"
             "var S=Math.max(0,Math.min(100,window.__ADTAME_S__||45));"
             "var bb=(1-0.50*(S/100)).toFixed(3),aa=(0.50*(S/100)).toFixed(3);"
             "function pc(c){try{var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)(?:,\\s*([0-9.]+))?\\)/.exec(String(c||''));"
               "if(!m)return null;return{r:+m[1],g:+m[2],b:+m[3],a:m[4]===undefined?1:+m[4]};}catch(e){return null;}}"
             "function sat(c){var mx=Math.max(c.r,c.g,c.b),mn=Math.min(c.r,c.g,c.b);return (mx-mn)/255;}"
             "function lumc(c){return (0.2126*c.r+0.7152*c.g+0.0722*c.b)/255;}"
             "var n=0,bg=0,solid=0,M=document.querySelectorAll('img,video,canvas'),productad=(window.__ADFRAME_MODE__==='productad'),standalone=(window.__ADFRAME_MODE__==='standalone'||productad),minM=standalone?26:48;"
             "var dt365=String((document.body&&document.body.innerText)||'').replace(/\\s+/g,' ').trim();var photoOnly365=(window.__ADFRAME_MODE__==='standalone')&&dt365.replace(/sponsored(?: ad)?/ig,'').trim().length<24;"
             "for(var i=0;i<M.length&&i<220;i++){var e=M[i],r=e.getBoundingClientRect();"
               "if(r.width<minM||r.height<minM)continue;var fullP368=productad&&r.width>(innerWidth||390)*0.72&&r.height>(innerHeight||80)*0.62;if(fullP368){if(e.__adTame362){e.style.removeProperty('filter');e.removeAttribute('data-ad-tame362');e.__adTame362=0;e.__adBy='productRasterSkip368';}continue;}"
               "var cn=e.className;if(cn&&cn.baseVal!==undefined)cn=cn.baseVal;"
               "if(/sprite|icon|logo|pixel/i.test(String(cn||'')))continue;"
               "var esig=String(e.currentSrc||e.src||e.poster||'')+'|'+bb;if(e.__adTame362===esig)continue;"
               "e.style.setProperty('filter','brightness('+bb+') saturate(1.08)','important');"
               "e.setAttribute('data-ad-tame362','media');e.__adTame362=esig;e.__adBy='adMedia362';n++;}"
             // CSS background artwork is darkened at the BACKGROUND layer only.
             // background-blend-mode does not composite child text into the effect.
             "var B=document.querySelectorAll('div,section,a,span,li');"
             "for(var j=0;j<B.length&&j<800&&bg<60;j++){var q=B[j],cs=getComputedStyle(q),bi=String(cs.backgroundImage||'none');"
               "if(bi.indexOf('url(')<0)continue;var rr=q.getBoundingClientRect(),minB=standalone?26:48;"
               "if(rr.width<minB||rr.height<minB)continue;var full365=standalone&&rr.width>(innerWidth||390)*0.72&&rr.height>(innerHeight||80)*0.72;if(productad&&full365){q.style.removeProperty('background-color');q.style.removeProperty('background-blend-mode');q.removeAttribute('data-ad-tame362');q.__adTame362=0;q.__adPhoto365=0;q.__adBy='productRasterBgSkip368';continue;}if(full365&&!photoOnly365){if(q.__adPhoto365){q.style.removeProperty('background-color');q.style.removeProperty('background-blend-mode');q.__adTame362=0;q.__adPhoto365=0;}continue;}"
               "var qc=q.className;if(qc&&qc.baseVal!==undefined)qc=qc.baseVal;"
               "if(/sprite|icon|logo|pixel/i.test(String(qc||'')))continue;"
               "var qsig=bi+'|'+aa;if(q.__adTame362===qsig)continue;"
               "q.style.setProperty('background-color','rgba(0,0,0,'+aa+')','important');"
               "q.style.setProperty('background-blend-mode','multiply','important');"
               "q.setAttribute('data-ad-tame362','bg');q.__adTame362=qsig;q.__adPhoto365=(full365&&photoOnly365)?1:0;q.__adBy=q.__adPhoto365?'adBgPhoto365':'adBg362';bg++;}"
             // v5.363: standalone taming is MEDIA-ONLY. The custom standalone dark
             // theme above still owns chrome/background/text, but White Background
             // Taming must never tone a whole ad box. That was the uniform veil seen
             // over the Liquid Death / truck placements in 5.362.
             "window.__AD_ADTAME__='media='+n+' bg='+bg+' solid='+solid+' photoOnly='+(photoOnly365?1:0);return n+bg+solid;"
           "}catch(e){window.__AD_ADTAME__='err '+e;return -1;}};"
           "window.__AD_SPON365__=function(){try{if(!document.body)return 0;if(!document.getElementById('adspon365')){var ss=document.createElement('style');ss.id='adspon365';ss.textContent='[data-ad-sponsored365]{color:#fff !important;-webkit-text-fill-color:#fff !important;opacity:1 !important;background-color:transparent !important;}[data-ad-sponrow367]{background-color:transparent !important;background-image:none !important;box-shadow:none !important;}';(document.head||document.documentElement).appendChild(ss);}if(!document.createTreeWalker)return 0;var W=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT),nd,n=0,k=0;while((nd=W.nextNode())&&k++<900){var t=String(nd.nodeValue||'').replace(/\\s+/g,' ').trim();if(!/^sponsored(?: ad)?$/i.test(t))continue;var e=nd.parentElement;if(!e)continue;e.setAttribute('data-ad-sponsored365','1');var p=e,u=0;while(p&&u++<3){var r=p.getBoundingClientRect(),tx=String(p.textContent||'').replace(/\\s+/g,' ').trim();if(r.height>=10&&r.height<=66&&r.width>=60&&tx.length<=90&&!(p.querySelector&&p.querySelector('img,picture,video,canvas'))){p.setAttribute('data-ad-sponrow367','1');p.style.setProperty('background-color','transparent','important');p.style.setProperty('box-shadow','none','important');}p=p.parentElement;}n++;}return n;}catch(e){return 0;}};"
           "window.__AD_HEROFAST365__=function(root){try{if(window.__ADFRAME_MODE__!=='hero'||!window.__ADTAME_ON__||!root||root.nodeType!==1)return 0;var S=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),bb=(1-0.50*(S/100)).toFixed(3),aa=(0.50*(S/100)).toFixed(3),A=[];if(!document.getElementById('adheropseudo366')){var ps=document.createElement('style');ps.id='adheropseudo366';ps.textContent='[data-ad-herobefore366]::before,[data-ad-heroafter366]::after{filter:brightness('+bb+') saturate(1.08) !important;}';(document.head||document.documentElement).appendChild(ps);}if(/^(IMG|VIDEO|CANVAS)$/i.test(String(root.tagName||'')))A.push(root);try{var q=root.querySelectorAll('img,video,canvas');for(var i=0;i<q.length&&i<120;i++)A.push(q[i]);}catch(e){}var n=0,b=0,pn=0;for(var j=0;j<A.length;j++){var x=A[j],r=x.getBoundingClientRect();if(r.width<32||r.height<32)continue;var c=x.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));if(/sprite|icon|logo|pixel/i.test(c))continue;var w='brightness('+bb+') saturate(1.08)';if(String(x.style.getPropertyValue('filter')||'')!==w||x.style.getPropertyPriority('filter')!=='important')x.style.setProperty('filter',w,'important');x.setAttribute('data-ad-tame362','media');x.__adBy='heroFast366';n++;}var B=[];if(/^(HTML|BODY|DIV|SECTION|A|SPAN|LI|FIGURE|PICTURE)$/i.test(String(root.tagName||'')))B.push(root);try{var qb=root.querySelectorAll('html,body,div,section,a,span,li,figure,picture');for(var k=0;k<qb.length&&k<120;k++)B.push(qb[k]);}catch(e){}for(var z=0;z<B.length&&b<40;z++){var e=B[z],rr=e.getBoundingClientRect();if(rr.width<32||rr.height<32)continue;var cc=e.className;cc=String(cc&&cc.baseVal!==undefined?cc.baseVal:(cc||''));if(/sprite|icon|logo|pixel/i.test(cc))continue;var cs=getComputedStyle(e),bi=String(cs.backgroundImage||'none');if(bi.indexOf('url(')>=0){e.style.setProperty('background-color','rgba(0,0,0,'+aa+')','important');e.style.setProperty('background-blend-mode','multiply','important');e.setAttribute('data-ad-tame362','bg');e.__adBy='heroFastBg366';b++;}try{var bf=getComputedStyle(e,'::before'),af=getComputedStyle(e,'::after'),bfi=String(bf.backgroundImage||'none'),afi=String(af.backgroundImage||'none');if(bfi.indexOf('url(')>=0){e.setAttribute('data-ad-herobefore366','1');e.__adBy='heroPseudo366';pn++;}if(afi.indexOf('url(')>=0){e.setAttribute('data-ad-heroafter366','1');e.__adBy='heroPseudo366';pn++;}}catch(px){}}window.__AD_HEROFAST365_N__=n+b+pn;return n+b+pn;}catch(e){return 0;}};"
           "window.__AD_VIDEOCTL362__=function(){try{"
             "if(window.__ADFRAME_MODE__!=='hero')return 0;"
             "if(!document.getElementById('advidctl362')){var vs=document.createElement('style');vs.id='advidctl362';"
               "vs.textContent='[data-ad-videoctl362]{background:rgba(0,0,0,.72) !important;border-radius:999px !important;box-shadow:none !important;}[data-ad-videoctl362] svg,[data-ad-videoctl362] path,[data-ad-videoctl362] polygon{fill:#fff !important;stroke:#fff !important;color:#fff !important;}';"
               "(document.head||document.documentElement).appendChild(vs);}"
             "var A=document.querySelectorAll('button,[role=button],svg,i'),n=0,w=innerWidth||390,h=innerHeight||300;"
             "for(var i=0;i<A.length&&i<700;i++){var e=A[i],r=e.getBoundingClientRect();if(r.width<10||r.width>64||r.height<10||r.height>64)continue;"
               "var c=e.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));var lab=String(e.getAttribute&&e.getAttribute('aria-label')||e.getAttribute&&e.getAttribute('title')||'');"
               "var sem=/play|pause/i.test(c+' '+lab),edge=(r.left<w*0.30&&r.top>h*0.45);if(!sem&&!edge)continue;"
               "var p=e,up=0;while(p.parentElement&&up++<2){var pr=p.parentElement.getBoundingClientRect();if(pr.width>=18&&pr.width<=64&&pr.height>=18&&pr.height<=64)p=p.parentElement;else break;}"
               "p.setAttribute('data-ad-videoctl362','1');n++;}"
             "return n;}catch(e){return 0;}};"
           "window.__AMZDARK_ADTHEME__=function(){try{"
             "var mode=window.__ADFRAME_MODE__||'hero',any379=window.__AD_ANYSPONINK379__?window.__AD_ANYSPONINK379__():0,sp365=window.__AD_SPON365__?window.__AD_SPON365__():0;"
             "var strip375=window.__AD_PRODUCTSTRIP375__?window.__AD_PRODUCTSTRIP375__():0;if(strip375){var cl375=window.__AD_CLEARSTRIP374__?window.__AD_CLEARSTRIP374__():0;var in375=window.__AD_ADTEXT371__?window.__AD_ADTEXT371__():0;var tx377=window.__AD_STRIPTEXT377__?window.__AD_STRIPTEXT377__():0;var bx378=window.__AD_STRIPCHROME379__?window.__AD_STRIPCHROME379__():0;var dk382=window.__AD_STANDDARK382__?window.__AD_STANDDARK382__():0;var tm375=window.__AD_STRIPMEDIA374__?window.__AD_STRIPMEDIA374__():0;var sp375=window.__AD_SPON365__?window.__AD_SPON365__():0;window.__AD_STANDALONE__='strip-stock382';window.__AD_ADTHEME__='mode='+mode+' strip379=1 any379='+String(window.__AD_ANYSPON379_N__||0)+' dark379='+String(window.__AD_ANYSPON379_DARK__||0)+' roots379='+String(window.__AD_ANYSPON379_ROOTS__||0)+' t377='+String(window.__AD_STRIPTEXT377_N__||0)+' d377='+String(window.__AD_STRIPTEXT377_DARK__||0)+' box379='+String(window.__AD_STRIPCHROME379_N__||0)+' boxleft379='+String(window.__AD_STRIPCHROME379_LEFT__||0)+' black382='+String(window.__AD_STANDDARK382_N__||0)+' blackleft382='+String(window.__AD_STANDDARK382_LEFT__||0)+' sticky='+String(window.__AD_STRIPCONF375__?1:0)+' clean375='+cl375+' chrome375='+String(window.__AD_STRIPCHROME374_LEFT__||0)+' ink375='+in375+' white376='+String(window.__AD_ADTEXT376_LOCKED__||0)+' grayleft376='+String(window.__AD_ADTEXT376_GRAYLEFT__||0)+' media375='+String(window.__AD_STRIPMEDIA374_N__||0)+' fullSkip375='+String(window.__AD_STRIPFULL374_N__||0)+' spon='+sp375;return cl375+in375+tx377+bx378+dk382+tm375+sp375;}"
             "if(mode==='productad'){var csp=document.getElementById('adfrcompact373');if(csp&&csp.parentNode)csp.parentNode.removeChild(csp);var oldc372=document.getElementById('adfrcompact372');if(oldc372&&oldc372.parentNode)oldc372.parentNode.removeChild(oldc372);var oldp=document.getElementById('adfrstand362');if(oldp&&oldp.parentNode)oldp.parentNode.removeChild(oldp);var oldm=document.getElementById('adfrmin');if(oldm&&oldm.parentNode)oldm.parentNode.removeChild(oldm);if(!document.getElementById('adfrproduct370')){var pst=document.createElement('style');pst.id='adfrproduct370';pst.textContent='html,body{background-color:transparent !important;}';(document.head||document.documentElement).appendChild(pst);}try{var pe=document.querySelectorAll('*');for(var pi=0;pi<pe.length&&pi<900;pi++){var px=pe[pi];if(!px.__adStand362)continue;var pv=String(px.style.getPropertyValue('background-color')||'').replace(/\\s+/g,'').toLowerCase();if(pv==='#181a1b'||pv==='rgb(24,26,27)')px.style.removeProperty('background-color');var bs=['top','right','bottom','left'];for(var pbi=0;pbi<4;pbi++){var bp='border-'+bs[pbi]+'-color',bv=String(px.style.getPropertyValue(bp)||'').replace(/\\s+/g,'').toLowerCase();if(bv==='#3b3c3e'||bv==='rgb(59,60,62)')px.style.removeProperty(bp);}}}catch(pc369){}var ptx=window.__AD_ADTEXT371__?window.__AD_ADTEXT371__():0;var pt=window.__AMZDARK_ADTAME__?window.__AMZDARK_ADTAME__():0;var ps=window.__AD_SPON365__?window.__AD_SPON365__():0;window.__AD_STANDALONE__='product-stock373';window.__AD_ADTHEME__='mode=productad stock=1 ink371='+ptx+' left='+String(window.__AD_ADTEXT371_LEFT__||0)+' roots='+String(window.__AD_ADTEXT371_ROOTS__||1)+' '+String(window.__AD_ADTAME__||('tame='+pt))+' spon='+ps+' pref='+(window.__AD_PRODUCTREF369__?1:0);return ptx+pt+ps;}"
             "if(mode==='standalone'){var compact373=window.__AD_COMPACTSTRIP373__?window.__AD_COMPACTSTRIP373__():0;if(compact373){var clean373=window.__AD_CLEARSTAND373__?window.__AD_CLEARSTAND373__():0;var ink373=window.__AD_ADTEXT371__?window.__AD_ADTEXT371__():0;var tame373=window.__AD_COMPACTMEDIA373__?window.__AD_COMPACTMEDIA373__():0;var spon373=window.__AD_SPON365__?window.__AD_SPON365__():0;window.__AD_STANDALONE__='compact-stock373';window.__AD_ADTHEME__='mode=standalone compact373=1 clean373='+clean373+' chrome373='+String(window.__AD_COMPACTCHROME373_LEFT__||0)+' ink371='+ink373+' left='+String(window.__AD_ADTEXT371_LEFT__||0)+' roots='+String(window.__AD_ADTEXT371_ROOTS__||1)+' media373='+String(window.__AD_COMPACTMEDIA373_N__||0)+' spon='+spon373;return clean373+ink373+tame373+spon373;}var cst=document.getElementById('adfrcompact373');if(cst&&cst.parentNode)cst.parentNode.removeChild(cst);var cst372=document.getElementById('adfrcompact372');if(cst372&&cst372.parentNode)cst372.parentNode.removeChild(cst372);var old=document.getElementById('adfrmin');if(old&&old.parentNode)old.parentNode.removeChild(old);var prodst=document.getElementById('adfrproduct370');if(prodst&&prodst.parentNode)prodst.parentNode.removeChild(prodst);"
               "var sn=window.__AMZDARK_ADTHEME_STANDALONE__?window.__AMZDARK_ADTHEME_STANDALONE__():0;"
               "var ink371=window.__AD_ADTEXT371__?window.__AD_ADTEXT371__():0;"
               "var stn=window.__AMZDARK_ADTAME__?window.__AMZDARK_ADTAME__():0;"
               "var sp367=window.__AD_SPON365__?window.__AD_SPON365__():0;"
               "window.__AD_ADTHEME__='mode=standalone '+String(window.__AD_STANDALONE__||('theme='+sn))+' ink371='+ink371+' left='+String(window.__AD_ADTEXT371_LEFT__||0)+' roots='+String(window.__AD_ADTEXT371_ROOTS__||1)+' compact='+String(window.__AD_COMPACT371__||0)+' compact373=0 '+String(window.__AD_ADTAME__||('tame='+stn))+' spon='+sp367;return sn+ink371+stn+sp367;}"
             "var csh=document.getElementById('adfrcompact373');if(csh&&csh.parentNode)csh.parentNode.removeChild(csh);var csh372=document.getElementById('adfrcompact372');if(csh372&&csh372.parentNode)csh372.parentNode.removeChild(csh372);var old2=document.getElementById('adfrstand362');if(old2&&old2.parentNode)old2.parentNode.removeChild(old2);"
             "if(!document.getElementById('adfrmin')){var st=document.createElement('style');"
               "st.id='adfrmin';st.textContent='*{-webkit-tap-highlight-color:transparent !important;}';"
               "(document.head||document.documentElement).appendChild(st);}"
             "var tn=window.__AMZDARK_ADTAME__?window.__AMZDARK_ADTAME__():0,vc=window.__AD_VIDEOCTL362__?window.__AD_VIDEOCTL362__():0;"
             "window.__AD_ADTHEME__='mode=hero stock=1 '+String(window.__AD_ADTAME__||('tame='+tn))+' ctl='+vc;return tn+vc;"
           "}catch(e){window.__AD_ADTHEME__='err '+e;return -1;}};"
           // Self-contained poster. The main one is defined at the END of the pass we
           // now return from early, so it would never exist in an ad frame -- which is
           // why ADTHEME never reached the log.
           "window.__ADFPOST__=function(){try{if(window.top===window)return;"
             "var f='ADFRAME '+(window.__AD_ADTHEME__||'pending');"
             "if(f!==window.__ADFLAST__){window.__ADFLAST__=f;"
               "window.top.postMessage({__adfr:1,"
                 "u:String(location.pathname||'/').slice(-16)+'|'+String(window.__ADFRAME_MODE__||'-').slice(0,4),r:f},'*');}"
           "}catch(e){}};"
           "try{window.__AD_HEROFAST365__&&window.__AD_HEROFAST365__(document.documentElement);window.__AMZDARK_ADTHEME__();window.__ADFPOST__();}catch(e){}"
           "try{var _at=null;new MutationObserver(function(ms){try{for(var mi=0;mi<ms.length;mi++){var mm=ms[mi];if(mm.type==='attributes'&&mm.target){mm.target.__adStand362=0;if(window.__AD_HEROFAST365__)window.__AD_HEROFAST365__(mm.target);}else if(mm.type==='childList'&&window.__AD_HEROFAST365__){for(var ai=0;ai<mm.addedNodes.length&&ai<16;ai++){var an=mm.addedNodes[ai];if(an&&an.nodeType===1)window.__AD_HEROFAST365__(an);}}}if(window.__AD_ANYSPONINK379__)window.__AD_ANYSPONINK379__();if(window.__AD_STRIPCONF375__&&window.__AD_ADTEXT371__)window.__AD_ADTEXT371__();if(window.__AD_STRIPCONF375__&&window.__AD_STRIPTEXT377__)window.__AD_STRIPTEXT377__();if(window.__AD_STRIPCONF375__&&window.__AD_STRIPCHROME379__)window.__AD_STRIPCHROME379__();if(window.__AD_STRIPCONF375__&&window.__AD_STANDDARK382__)window.__AD_STANDDARK382__();}catch(e){}clearTimeout(_at);"
             "_at=setTimeout(function(){try{window.__AMZDARK_ADTHEME__();window.__ADFPOST__();}catch(e){}},window.__AD_STRIPCONF375__?40:180);})"
             ".observe(document.documentElement,{childList:true,subtree:true,attributes:true,characterData:true,attributeFilter:['src','srcset','poster','class','style']});}catch(e){}"
           "try{var __ad377rf=0;function __ad377raf(){if(++__ad377rf>180)return;try{if(window.__AD_ANYSPONINK379__)window.__AD_ANYSPONINK379__();if(window.__AD_STRIPCONF375__&&window.__AD_STRIPTEXT377__)window.__AD_STRIPTEXT377__();if(window.__AD_STRIPCONF375__&&window.__AD_STRIPCHROME379__)window.__AD_STRIPCHROME379__();if(window.__AD_STRIPCONF375__&&window.__AD_STANDDARK382__)window.__AD_STANDDARK382__();}catch(e){}requestAnimationFrame(__ad377raf);}requestAnimationFrame(__ad377raf);}catch(e){}"
           "try{var __ad378iv=0,__ad378tm=setInterval(function(){if(++__ad378iv>60){clearInterval(__ad378tm);return;}try{if(window.__AD_ANYSPONINK379__)window.__AD_ANYSPONINK379__();if(window.__AD_STRIPCONF375__){if(window.__AD_STRIPTEXT377__)window.__AD_STRIPTEXT377__();if(window.__AD_STRIPCHROME379__)window.__AD_STRIPCHROME379__();}}catch(e){}},500);}catch(e){}"
           "try{document.addEventListener('load',function(ev){try{var t=ev.target;if(t&&t.nodeType===1&&window.__AD_HEROFAST365__)window.__AD_HEROFAST365__(t);}catch(e){}},true);}catch(e){}"
           "try{document.addEventListener('DOMContentLoaded',function(){try{window.__AMZDARK_ADTHEME__();window.__ADFPOST__();}catch(e){}},{once:true});}catch(e){}"
           // Mutations/source changes handle normal dynamic media; a short bounded poll
           // remains only as insurance for canvas/video state that changes without DOM writes.
           "try{var _n=0,_iv=setInterval(function(){if(++_n>8){clearInterval(_iv);return;}"
             "try{window.__AMZDARK_ADTHEME__();window.__ADFPOST__();}catch(e){}},2000);}catch(e){}"
           "try{addEventListener('load',function(){"
             "try{window.__AMZDARK_ADTHEME__();}catch(e){}"
             "setTimeout(function(){try{window.__AMZDARK_ADTHEME__();}catch(e){}},700);"
           "},{once:true});}catch(e){}"
         "}catch(e){}}"
         "else if(window.DarkReader&&DarkReader.enable){"
         "try{DarkReader.setFetchMethod(window.fetch);}catch(e){}"
 // ── AD-CARD FLIP GUARD ──────────────────────────────────────────────────
 // THE FLIP, not the colour. An ad creative paints with its own correct text,
 // then Dark Reader's pass runs and rewrites it -- that is the grey-then-black
 // flicker on the home-feed cards. A stylesheet cannot win this: DR writes
 // INLINE styles, and inline !important beats stylesheet !important, which is
 // why every parse-time rule so far changed the colour but not the flipping.
 //
 // So strip DR's own inline writes back off ad subtrees and keep them off. The
 // observer is scoped to attribute changes for the darkreader attributes only,
 // and each hit just clears the properties DR set -- no colour of ours is
 // imposed, so the creative renders exactly as Amazon shipped it.
         "try{(function(){"
           "var ADSEL='[data-adcrt],[data-ad-stocktext]';"
           "function isAd(n){try{return n&&n.closest&&n.closest(ADSEL);}catch(e){return null;}}"
           "function strip(n){try{"
             "if(!n||n.nodeType!==1)return;"
             "if(n.matches&&n.matches('[data-ad-college-chevron],[data-ad-college-chevron] *'))return;"
             "n.__adStrip=(n.__adStrip||0)+1;if(n.__adStrip>12)return;"
             "if(n.hasAttribute('data-darkreader-inline-color')){"
               "n.style.removeProperty('color');n.style.removeProperty('-webkit-text-fill-color');"
               "n.removeAttribute('data-darkreader-inline-color');}"
             "if(n.hasAttribute('data-darkreader-inline-bgcolor')){"
               "n.style.removeProperty('background-color');"
               "n.removeAttribute('data-darkreader-inline-bgcolor');}"
             "if(n.hasAttribute('data-darkreader-inline-border-top')||n.hasAttribute('data-darkreader-inline-border-color')){"
               "n.style.removeProperty('border-color');"
               "n.removeAttribute('data-darkreader-inline-border-top');"
               "n.removeAttribute('data-darkreader-inline-border-color');}"
           "}catch(e){}}"
           "function sweep(root){try{"
             "var ads=(root||document).querySelectorAll(ADSEL);"
             "for(var i=0;i<ads.length&&i<40;i++){"
               "try{if(ads[i].hasAttribute('data-adcrt'))ads[i].setAttribute('data-ad-stocktext','1');}catch(e){}"
               "strip(ads[i]);"
               "var kids=ads[i].querySelectorAll('*');"
               "for(var j=0;j<kids.length&&j<400;j++)strip(kids[j]);}"
           "}catch(e){}}"
           "sweep(document);"
           "var pend=null;"
           "new MutationObserver(function(ms){"
             "for(var i=0;i<ms.length;i++){var t=ms[i].target;"
               "if(t&&t.nodeType===1&&isAd(t)){clearTimeout(pend);"
                 "pend=setTimeout(function(){sweep(document);},16);return;}}"
           "}).observe(document.documentElement,{subtree:true,attributes:true,"
             "attributeFilter:['style','data-darkreader-inline-color','data-darkreader-inline-bgcolor']});"
           "addEventListener('load',function(){sweep(document);},{once:true});"
           "setTimeout(function(){sweep(document);},600);"
           "setTimeout(function(){sweep(document);},1800);"
         "})();}catch(e){}"
         // v5.373: a compact Sponsored child can be transparent internally while
         // its iframe/wrapper still paints a solid black or white row. Keep the frame
         // itself transparent provisionally, then clear only size-matched wrappers
         // after the child confirms it is the compact Sponsored template.
         "try{window.__AD_MARKCOMPACT373__=function(f,confirmed){try{if(!f)return 0;var r=f.getBoundingClientRect();if(r.width<280||r.height<40||r.height>100)return 0;f.setAttribute('data-ad-compactframe373','1');f.style.setProperty('background','transparent','important');f.style.setProperty('background-color','transparent','important');f.style.setProperty('border','0','important');f.style.setProperty('outline','none','important');f.style.setProperty('box-shadow','none','important');f.style.setProperty('filter','none','important');f.style.setProperty('opacity','1','important');var n=1;if(confirmed){var p=f.parentElement,d=0;while(p&&d++<3){var pr=p.getBoundingClientRect();var near=(pr.width>=r.width*0.82&&pr.width<=r.width*1.28&&pr.height>=r.height*0.70&&pr.height<=r.height*2.20);if(!near)break;var cs=getComputedStyle(p),bi=String(cs.backgroundImage||'none');p.style.setProperty('background-color','transparent','important');if(bi.indexOf('url(')<0&&bi!=='none')p.style.setProperty('background-image','none','important');p.style.setProperty('border-color','transparent','important');p.style.setProperty('outline','none','important');p.style.setProperty('box-shadow','none','important');p.style.setProperty('-webkit-backdrop-filter','none','important');p.style.setProperty('backdrop-filter','none','important');p.setAttribute('data-ad-compactwrap373','1');p.__adBy='compactWrap373';n++;p=p.parentElement;}f.setAttribute('data-ad-compactconfirmed373','1');}window.__AD_COMPACTFRAME373_N__=(window.__AD_COMPACTFRAME373_N__||0)+1;return n;}catch(e){return 0;}};}catch(e){}"
         // v5.374: one parent-side frame policy for productad AND confirmed
         // compact Sponsored strips. Clearing iframe/wrapper paint here prevents the
         // same row from alternating between white, black, and filtered depending on
         // which child template/referrer Amazon delivered.
         "try{window.__AD_MARKSTRIP374__=function(f,confirmed){try{if(!f)return 0;var r=f.getBoundingClientRect();if(r.width<280||r.height<40||r.height>220)return 0;f.setAttribute('data-ad-stripframe374','1');f.style.setProperty('background','transparent','important');f.style.setProperty('background-color','transparent','important');f.style.setProperty('border','0','important');f.style.setProperty('outline','none','important');f.style.setProperty('box-shadow','none','important');f.style.setProperty('filter','none','important');f.style.setProperty('mix-blend-mode','normal','important');f.style.setProperty('opacity','1','important');var n=1;if(confirmed){var p=f.parentElement,d=0;while(p&&d++<4){var pr=p.getBoundingClientRect();var near=(pr.width>=r.width*0.80&&pr.width<=r.width*1.32&&pr.height>=r.height*0.62&&pr.height<=r.height*2.60);if(!near)break;var cs=getComputedStyle(p),bi=String(cs.backgroundImage||'none');p.style.setProperty('background-color','transparent','important');if(bi!=='none'&&bi.indexOf('url(')<0)p.style.setProperty('background-image','none','important');p.style.setProperty('border-color','transparent','important');p.style.setProperty('outline','none','important');p.style.setProperty('box-shadow','none','important');p.style.setProperty('filter','none','important');p.style.setProperty('-webkit-backdrop-filter','none','important');p.style.setProperty('backdrop-filter','none','important');p.style.setProperty('mix-blend-mode','normal','important');p.style.setProperty('opacity','1','important');p.setAttribute('data-ad-stripwrap374','1');p.__adBy='stripWrap374';n++;p=p.parentElement;}f.setAttribute('data-ad-stripconfirmed374','1');}if(String(f.getAttribute('data-ad-frame-mode362')||'')==='standalone'&&window.__AD_STANDPARENT393__)window.__AD_STANDPARENT393__(f);window.__AD_STRIPFRAME374_N__=(window.__AD_STRIPFRAME374_N__||0)+1;return n;}catch(e){return 0;}};}catch(e){}"
         // v5.393: CONFIRMED standalone parent cleanup. The visible Home black box
         // is outside the child frame: the child already reports black382=0, while its
         // 396x62-ish parent lane remains black. Anchor ONLY to a child that has sent
         // __adStrip374 confirmation, then clear neutral-black ancestry around that exact
         // frame. This does not inspect/modify creative descendants or media state.
         "try{window.__AD_STANDPARENT393__=function(f){try{if(window.__ADFRAME_MODE__||!f||!document.body)return 0;if(String(f.getAttribute('data-ad-frame-mode362')||'')!=='standalone'||!f.hasAttribute('data-ad-stripframe374'))return 0;if(document.querySelector('#search,.s-search-results,[data-component-type=\"s-search-result\"],#productTitle,#dp-container,#ppd'))return 0;var r=f.getBoundingClientRect(),W=innerWidth||390;if(r.width<280||r.height<40||r.height>180)return 0;function pc(v){var m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([0-9.]+))?/i.exec(String(v||''));return m?[+m[1],+m[2],+m[3],m[4]===undefined?1:+m[4]]:null;}function black(q){if(!q||q[3]<.30)return false;var mx=Math.max(q[0],q[1],q[2]),mn=Math.min(q[0],q[1],q[2]),lum=(.2126*q[0]+.7152*q[1]+.0722*q[2])/255,sat=(mx-mn)/255;return lum<.20&&sat<.10;}function pp(e,w){try{var c=getComputedStyle(e,w),bi=String(c.backgroundImage||'none');return bi.indexOf('url(')<0&&black(pc(c.backgroundColor));}catch(x){return false;}}f.style.setProperty('background','transparent','important');f.style.setProperty('background-color','transparent','important');f.style.setProperty('box-shadow','none','important');var p=f.parentElement,d=0,n=0;while(p&&p!==document.body&&d++<8){var pr=p.getBoundingClientRect(),cand=pr.width>=r.width*.72&&pr.width<=W*1.18&&pr.height>=r.height*.55&&pr.height<=Math.max(420,r.height*6.5);if(cand&&!(p.querySelector&&p.querySelector('video'))){var cs=getComputedStyle(p),bi=String(cs.backgroundImage||'none'),bad=bi.indexOf('url(')<0&&black(pc(cs.backgroundColor)),bp=pp(p,'::before'),ap=pp(p,'::after');if(bad||bp||ap){p.setAttribute('data-ad-standparent393','1');if(bad){p.style.setProperty('background-color','transparent','important');if(bi!=='none')p.style.setProperty('background-image','none','important');p.style.setProperty('box-shadow','none','important');}if(bp)p.setAttribute('data-ad-standparentbefore393','1');if(ap)p.setAttribute('data-ad-standparentafter393','1');n++;}}p=p.parentElement;}window.__AD_STANDPARENT393_STATE__='fixed='+n;return n;}catch(e){window.__AD_STANDPARENT393_STATE__='err '+(e&&e.message||e);return 0;}};}catch(e){}"
         "try{if(!document.getElementById('adstandparent393')){var sp393=document.createElement('style');sp393.id='adstandparent393';sp393.textContent='[data-ad-standparent393]{background-color:transparent !important;box-shadow:none !important;}[data-ad-standparentbefore393]::before,[data-ad-standparentafter393]::after{background-color:transparent !important;background-image:none !important;box-shadow:none !important;}';(document.head||document.documentElement).appendChild(sp393);}}catch(e){}"
         "try{if(!document.getElementById('adstandparent395')){var sp395=document.createElement('style');sp395.id='adstandparent395';sp395.textContent='[data-ad-standparent395]{background-color:transparent !important;background-image:none !important;box-shadow:none !important;filter:none !important;-webkit-backdrop-filter:none !important;backdrop-filter:none !important;mix-blend-mode:normal !important;border-color:transparent !important;outline:none !important;}[data-ad-standbefore395]::before,[data-ad-standafter395]::after{background-color:transparent !important;background-image:none !important;box-shadow:none !important;filter:none !important;-webkit-backdrop-filter:none !important;backdrop-filter:none !important;}';(document.head||document.documentElement).appendChild(sp395);}}catch(e){}"
                  "function _adStandaloneSweep395(){try{if(window.__ADFRAME_MODE__||!document.body)return 0;if(document.querySelector('#search,.s-search-results,[data-component-type=\"s-search-result\"],#productTitle,#dp-container,#ppd')){window.__AD_STANDSWEEP395__='home=0 product=1';return 0;}var F=document.querySelectorAll('iframe[data-ad-frame-mode362=\"standalone\"]'),n=0,wraps=0,hazard=0,W=innerWidth||390;function clean(f){var r=f.getBoundingClientRect(),p=f.parentElement,d=0,c=0;f.style.setProperty('background','transparent','important');f.style.setProperty('background-color','transparent','important');f.style.setProperty('box-shadow','none','important');f.style.setProperty('filter','none','important');f.style.setProperty('mix-blend-mode','normal','important');while(p&&p!==document.body&&d++<8){var pr=p.getBoundingClientRect();if(pr.width<r.width*.65||pr.width>W*1.14||pr.height<r.height*.45||pr.height>680)break;if(p.querySelector&&p.querySelector('video')){p=p.parentElement;continue;}var frames=p.querySelectorAll?p.querySelectorAll('iframe').length:0;if(frames>1)break;var cs=getComputedStyle(p),bi=String(cs.backgroundImage||'none');if(bi.indexOf('url(')<0){p.style.setProperty('background-color','transparent','important');if(bi!=='none')p.style.setProperty('background-image','none','important');p.style.setProperty('box-shadow','none','important');p.style.setProperty('filter','none','important');p.style.setProperty('-webkit-backdrop-filter','none','important');p.style.setProperty('backdrop-filter','none','important');p.style.setProperty('mix-blend-mode','normal','important');p.style.setProperty('border-color','transparent','important');p.style.setProperty('outline','none','important');p.setAttribute('data-ad-standparent395','1');try{var b=getComputedStyle(p,'::before'),a=getComputedStyle(p,'::after'),bbi=String(b.backgroundImage||'none'),abi=String(a.backgroundImage||'none'),bbc=String(b.backgroundColor||'transparent').replace(/\\s+/g,''),abc=String(a.backgroundColor||'transparent').replace(/\\s+/g,''),bbs=String(b.boxShadow||'none'),abs=String(a.boxShadow||'none');if((bbi!=='none'&&bbi.indexOf('url(')<0)||(bbc!=='transparent'&&bbc!=='rgba(0,0,0,0)')||bbs!=='none')p.setAttribute('data-ad-standbefore395','1');if((abi!=='none'&&abi.indexOf('url(')<0)||(abc!=='transparent'&&abc!=='rgba(0,0,0,0)')||abs!=='none')p.setAttribute('data-ad-standafter395','1');}catch(px){}c++;}p=p.parentElement;}return c;}for(var i=0;i<F.length&&i<60;i++){var f=F[i],r=f.getBoundingClientRect();if(r.width<280||r.width>W*1.10||r.height<40||r.height>180)continue;var sig=(String(f.src||'')+' '+String(f.title||'')+' '+String(f.name||'')+' '+String(f.className||'')).toLowerCase();if(/video|player|youtube|vimeo|captcha|challenge|map|payment/.test(sig))continue;f.setAttribute('data-ad-homeauto395','1');if(window.__AD_MARKSTRIP374__)window.__AD_MARKSTRIP374__(f,true);wraps+=clean(f);n++;var p=f.parentElement,d=0;while(p&&p!==document.body&&d++<8){var pr=p.getBoundingClientRect();if(pr.width<r.width*.65||pr.width>W*1.14||pr.height<r.height*.45||pr.height>680)break;if(!(p.querySelector&&p.querySelector('video'))){var cs=getComputedStyle(p),bi=String(cs.backgroundImage||'none'),bc=String(cs.backgroundColor||'transparent').replace(/\\s+/g,''),sh=String(cs.boxShadow||'none'),fl=String(cs.filter||'none');if(bi.indexOf('url(')<0&&((bc!=='transparent'&&bc!=='rgba(0,0,0,0)')||bi!=='none'||sh!=='none'||fl!=='none'))hazard++;}p=p.parentElement;}}window.__AD_STANDSWEEP395__='frames='+n+' wraps='+wraps+' hazard='+hazard;return n;}catch(e){window.__AD_STANDSWEEP395__='err '+(e&&e.message||e);return 0;}}"
         "window._adStandaloneSweep395=_adStandaloneSweep395;"
         // v5.362: classify child ad frames without peeking into cross-origin DOM.
         // Short/wide placements are standalone; only tall/square placements near the
         // top of the document are top-carousel hero creatives. Child frames have a
         // shape fallback too, so this postMessage is a refinement rather than a race.
         "try{window.__AD_FRAMECLASS362__=function(){var F=document.querySelectorAll('iframe'),n=0;"
           "for(var fi=0;fi<F.length&&fi<80;fi++){var f=F[fi],r=f.getBoundingClientRect();if(r.width<120||r.height<50)continue;"
             "var dy=r.top+(window.scrollY||window.pageYOffset||0),ratio=r.width/Math.max(1,r.height);"
             "var cls=f.className;cls=String(cls&&cls.baseVal!==undefined?cls.baseVal:(cls||''));var anc='';try{var p=f.parentElement,d=0;while(p&&d++<4){anc+=' '+String(p.className||'');p=p.parentElement;}}catch(e){}"
             "var hero=(r.height>=180&&ratio<2.25&&(dy<1250||/carousel|hero|billboard|rotator|slideshow/i.test(cls+anc)));"
             "var href369=String(location.href||'').toLowerCase(),prodURL369=(href369.indexOf('/dp/')>=0||href369.indexOf('/gp/aw/d/')>=0||href369.indexOf('/gp/product/')>=0||href369.indexOf('/s?')>=0||href369.indexOf('/search')>=0||href369.indexOf('?k=')>=0||href369.indexOf('&k=')>=0||href369.indexOf('field-keywords=')>=0);var productDoc=prodURL369;try{productDoc=productDoc||!!document.querySelector('#dp,#ppd,#centerCol,#productTitle,#buybox,#add-to-cart-button,#buy-now-button,.s-search-results,.s-main-slot,[data-component-type=\"s-search-result\"],[data-feature-name=\"buybox\"],[data-feature-name=\"title\"]');}catch(e){}window.__AD_PRODUCTDOC369__=productDoc?1:0;"
             "var productAd=(!hero&&productDoc&&r.width>=300&&r.height>=55&&r.height<=260);var mode=hero?'hero':(productAd?'productad':'standalone');f.setAttribute('data-ad-frame-mode362',mode);f.setAttribute('data-ad-frame-why369',productAd?(prodURL369?'url369':'dom369'):(hero?'hero':'standalone'));if(window.__AD_MARKSTRIP374__){if(productAd)window.__AD_MARKSTRIP374__(f,true);else if(mode==='standalone'&&r.width>=280&&r.height<=180){var home395=(!productDoc&&r.width>=280&&r.width<=(innerWidth||390)*1.10&&r.height>=40&&r.height<=180);if(home395)f.setAttribute('data-ad-homeauto395','1');window.__AD_MARKSTRIP374__(f,home395);}}try{f.contentWindow&&f.contentWindow.postMessage({__amzAdMode:mode},'*');}catch(e){}n++;}"
           "window.__AD_FRAMECLASS362_N__=n;return n;};window.__AD_FRAMECLASS362__();"
           "var ft362=null;new MutationObserver(function(){clearTimeout(ft362);ft362=setTimeout(function(){try{window.__AD_FRAMECLASS362__();}catch(e){}},60);}).observe(document.documentElement,{childList:true,subtree:true});"
         "}catch(e){}"
         // WCAG contrast repair. Dark Reader recolours from the page's own palette,
         // which can leave text only marginally separated from its background - the
         // '% off' badges and the descriptions under product photos being the
         // reported cases. This measures the real computed contrast of every element
         // that owns visible text and lifts ONLY the ones that actually fail, so
         // brand colours that already read fine are untouched.
         // Re-run the repair as the page fills in (carousels, lazy tiles), debounced
         // so a busy DOM cannot turn this into a hot loop.
         // Mark a container that actually carries creative artwork. Cheap, and
         // idempotent -- the marker is what the stylesheet keys off.
         "function _adMark(el){try{"
           "if(!el||el.nodeType!==1||el.hasAttribute('data-adcrt'))return false;"
           "var r=el.getBoundingClientRect();"
           "if(r.width<200||r.height<80)return false;"
           // The container must PAINT the artwork itself. A product tile holds its
           // photo in a child <img> with the text below, and must never match.
           "var bi=getComputedStyle(el).backgroundImage||'';"
           "if(bi.indexOf('url(')<0)return false;"
           // and the caption must actually sit ON it: at least one text child
           // whose box falls inside the container's own painted area
           "var over=false;"
           "try{var er=el.getBoundingClientRect();"
             "var tq=el.querySelectorAll('span,p,h1,h2,h3');"
             "for(var t9=0;t9<tq.length&&t9<30;t9++){"
               "var te9=tq[t9];var has=false;"
               "for(var c9=0;c9<te9.childNodes.length&&c9<4;c9++){"
                 "var n9=te9.childNodes[c9];"
                 "if(n9.nodeType===3&&n9.nodeValue&&n9.nodeValue.trim()){has=true;break;}}"
               "if(!has)continue;"
               "var tr9=te9.getBoundingClientRect();"
               "if(tr9.width<10||tr9.height<6)continue;"
               "if(tr9.left>=er.left-2&&tr9.right<=er.right+2&&"
                  "tr9.top>=er.top-2&&tr9.bottom<=er.bottom+2){over=true;break;}}"
           "}catch(e){}"
           "if(!over)return false;"
           "el.setAttribute('data-adcrt','1');"
           "window.__AD_CRT__=(window.__AD_CRT__||0)+1;return true;"
         "}catch(e){return false;}}"
         "window.__AMZDARK_FIXCONTRAST__=function(){try{"
           // AD FRAME: STOP HERE. The stub installed by the gate 140 lines above is
           // overwritten by this very assignment, so door 1 has never actually been
           // shut -- only Dark Reader was being skipped while this whole pass kept
           // running in ad frames and doing the darkening, silhouetting and contrast
           // flipping it was supposed to be excluded from. The guard has to live
           // INSIDE the function, because the function is what wins the assignment.
           "if(window.__ADFRAMESKIP__){"
             "try{if(window.__ADFPOST__)window.__ADFPOST__();}catch(e){}return -3;}"
           // FRAME BRIDGE. Installed BEFORE the early-return guards below, so a
           // frame still registers even on a throttled pass.
           //
           // The user scripts are forMainFrameOnly:NO, so every fix runs in every
           // frame -- but evaluateJavaScript reads the MAIN frame only, so every
           // probe result computed in a child frame has been silently discarded.
           // That is not a CARDX bug, it is a structural blind spot, and it explains
           // CARDX[none scanned=0], DARKGLYPH[clean art=6] and FLTSCAN[n=0] alike:
           // those numbers are real, they are just the main frame's, and the home
           // feed is not in it. Child frames now post their fragment to the top
           // frame, which collects them for the report. postMessage is deliberate:
           // it works cross-origin, which a shared global cannot.
           "if(!window.__ADFB__){window.__ADFB__=1;"
             "if(window.top===window){window.__AD_FRAMES__={};"
               "addEventListener('message',function(ev){try{"
                 "var d=ev.data;if(!d||typeof d!=='object')return;if(d.__adStrip374===1){try{var IF374=document.querySelectorAll('iframe');for(var ci374=0;ci374<IF374.length&&ci374<100;ci374++){if(IF374[ci374].contentWindow===ev.source){window.__AD_MARKSTRIP374__&&window.__AD_MARKSTRIP374__(IF374[ci374],true);break;}}}catch(ec374){}return;}if(d.__adCompact373===1){try{var IF373=document.querySelectorAll('iframe');for(var ci373=0;ci373<IF373.length&&ci373<80;ci373++){if(IF373[ci373].contentWindow===ev.source){window.__AD_MARKCOMPACT373__&&window.__AD_MARKCOMPACT373__(IF373[ci373],true);break;}}}catch(ec373){}return;}if(d.__adfr!==1)return;"
                 "var k=String(d.u||'?').slice(0,22);"
                 "if(!window.__AD_FRAMES__)window.__AD_FRAMES__={};"
                 "var kn=0;for(var kk in window.__AD_FRAMES__)kn++;"
                 // Prefer frames that actually found something. A feed page can host a
                 // dozen ad iframes and the first six were winning the slots on
                 // arrival order alone -- the same document-order bias that ate four
                 // probe budgets.
                 "var interesting=/STAR |stars=[1-9]|ADFRAME mode=productad|strip375=1|compact373=1/.test(String(d.r||''));"
                 "if(kn>=6&&!(k in window.__AD_FRAMES__)&&!interesting)return;"
                 "if(kn>=10&&!(k in window.__AD_FRAMES__)){"
                   "for(var dk in window.__AD_FRAMES__){"
                     "if(!/STAR |stars=[1-9]/.test(window.__AD_FRAMES__[dk])){"
                       "delete window.__AD_FRAMES__[dk];break;}}}"
                 "window.__AD_FRAMES__[k]=String(d.r||'').slice(0,200);"
               "}catch(e){}},false);}}"
           // SCROLL GUARD + RATE LIMIT. The pass measures ~50ms. That is harmless
           // occasionally and ruinous continuously -- and Amazon's feed lazy-loads
           // as you scroll, so the MutationObserver below fires in a steady stream
           // and a 150ms debounce means ~50ms of blocked main thread every 150ms.
           // That is the scroll lag: not one slow pass, one pass running constantly.
           // Never run while a scroll is in flight; never run more than once per
           // 400ms. Both cases schedule a single trailing run so nothing is lost.
           "if(!window.__ADSCRINIT__){window.__ADSCRINIT__=1;var _st=null;"
             "addEventListener('scroll',function(){window.__ADSCROLLING__=1;"
               "clearTimeout(_st);_st=setTimeout(function(){window.__ADSCROLLING__=0;},180);},"
               "{passive:true,capture:true});}"
           "var _nw=Date.now();"
           "if(window.__ADSCROLLING__||(window.__ADLAST__&&_nw-window.__ADLAST__<400)){"
             "if(!window.__ADTRAIL__){window.__ADTRAIL__=setTimeout(function(){"
               "window.__ADTRAIL__=null;try{window.__AMZDARK_FIXCONTRAST__();}catch(e){}},450);}"
             // RETURN THE CACHED REPORT, NOT -2. The poll calls this function to READ
             // the probes, but the rate limiter I added in v5.180 to fix scroll lag
             // bails out before the report is ever assembled -- so on any surface you
             // have to scroll to reach (i.e. the home feed) the poll got a bare -2 and
             // every probe value came back empty or stale. That is why CARDX,
             // DARKGLYPH and FLTSCAN all read as nothing on the home feed while the
             // same probes returned real data on the shopping pane. Work still stops;
             // only reporting continues.
             "try{if(window.__ADPOST__)window.__ADPOST__();}catch(e){}"
             "return (window.__AD_LASTREP__?(window.__AD_LASTREP__+' [thr]'):-2);}"
           "window.__ADLAST__=_nw;"
           "var FG='%@';"
           "function ch(v){v=v/255;return v<=0.03928?v/12.92:Math.pow((v+0.055)/1.055,2.4);}"
           "function lum(c){var m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([\\d.]+))?\\)/.exec(c);"
             "if(!m)return null;var a=m[4]===undefined?1:parseFloat(m[4]);if(a<0.1)return null;"
             "return 0.2126*ch(+m[1])+0.7152*ch(+m[2])+0.0722*ch(+m[3]);}"
           // Returns null when the effective ground is ARTWORK rather than a
           // colour. Crucially this is true from the moment CSS applies -- it
           // reads the declaration, not the loaded pixels -- so it holds on the
           // very first pass, before the creative has downloaded.
           "function bgOf(e){var d=0;"
             "while(e&&d++<14){var cs9=getComputedStyle(e);"
               "if((cs9.backgroundImage||'').indexOf('url(')>=0){"
                 "var tg9=(e.tagName||'').toLowerCase();"
                 "if(tg9!=='body'&&tg9!=='html'){"
                   "var r9=e.getBoundingClientRect();"
                   "if(r9.width>=110&&r9.height>=60)return null;}}"
               "var l=lum(cs9.backgroundColor);"
               "if(l!==null)return l;e=e.parentElement;}"
             "return 0.02;}"
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
           "var els=collect(document.body,[],0),n=0,bfix=0,lfix=0,gfix=0,bigfix=0;"
           // Large artwork rectangles, gathered once. Anything overlapping one of
           // these is chrome ON a creative: darkening it paints a box over the art.
           "var ART=[];try{var AQ=document.querySelectorAll('img,picture,video');"
           "__ck('AQ');"
             "for(var aq=0;aq<AQ.length&&aq<250&&((aq&15)||!ovr())&&ART.length<80;aq++){"
               "var arr=AQ[aq].getBoundingClientRect();"
               "if(arr.width>=110&&arr.height>=60)ART.push(arr);}"
             "var AQ2=document.querySelectorAll('div,section,a,span');"
             "for(var aq2=0;aq2<AQ2.length&&aq2<900&&ART.length<120;aq2++){"
               "var bgi3=getComputedStyle(AQ2[aq2]).backgroundImage||'';"
               "if(bgi3.indexOf('url(')<0)continue;"
               "var ar2=AQ2[aq2].getBoundingClientRect();"
               "if(ar2.width>=110&&ar2.height>=60)ART.push(ar2);}"
           "}catch(e){}"
           // Overlap, not containment: a caption strip that runs a few pixels wider
           // than the creative is still chrome sitting on artwork.
           "function artOverlap(r5){try{var best=0;"
             "var ar5=Math.max(r5.width*r5.height,1);"
             "for(var oa=0;oa<ART.length;oa++){var a5=ART[oa];"
               "var ow=Math.min(r5.right,a5.right)-Math.max(r5.left,a5.left);"
               "var oh=Math.min(r5.bottom,a5.bottom)-Math.max(r5.top,a5.top);"
               "if(ow<=0||oh<=0)continue;"
               "var f5=(ow*oh)/ar5;if(f5>best)best=f5;}"
             "return best;}catch(e){return 0;}}"
           // AD CARD = NO TEXT, NO BACKGROUND. A card-sized ancestor carrying a
           // creative (its own background-image, or a large img inside) marks its whole
           // subtree untouchable. This is why the top-of-feed cards get a black box
           // behind their copy and why light text lands on a light creative: our
           // passes were treating card copy as ordinary page text. Cached per element.
           "function inAdCard(el0){try{if(el0.__adCardQ!==undefined)return el0.__adCardQ;"
             "var p0=el0,d0=0,r0=false;"
             "while(p0&&d0++<9){var pr0=p0.getBoundingClientRect();"
               "if(pr0.width>=250&&pr0.height>=150){"
                 "var ps0=getComputedStyle(p0);"
                 // Own background-image only. Requiring merely "contains a large img"
                 // matched ordinary product cards too, which is why 38 containers
                 // suppressed 453 text writes -- far more than the handful of ad
                 // creatives on screen. A creative paints itself; a product card holds
                 // a photo in a child. Only the former is an ad card.
                 "if(String(ps0.backgroundImage||'').indexOf('url(')>=0){r0=true;break;}"
                 // ...or an img that fills most of the container, which is what a
                 // full-bleed creative looks like when delivered as an <img>.
                 "try{var im0=p0.querySelector('img,picture,video');"
                   "if(im0){var ir0=im0.getBoundingClientRect();"
                     // 0.85 width took this from 38 containers to 0. A creative is
                     // image-dominated but not necessarily edge-to-edge, so require the
                     // image to cover most of the box by AREA instead of by width.
                     "if((ir0.width*ir0.height)>=(pr0.width*pr0.height)*0.45)"
                       "{r0=true;break;}}}catch(e0){}}"
               "p0=p0.parentElement;}"
             "el0.__adCardQ=r0;if(r0){"
               "try{p0&&p0.setAttribute&&p0.setAttribute('data-ad-stocktext','1');}catch(e){}"
               "window.__AD_CARDBLK__=(window.__AD_CARDBLK__||0)+1;}"
             "return r0;}catch(e){return true;}}"
           // v5.288: AD SUBTREES ARE OFF-LIMITS TO THE CONTRAST PASS.
           // The reported flip -- ad text changes colour the moment you STOP
           // scrolling the carousel -- is this pass, not Dark Reader. The scroll
           // guard below sets __ADSCROLLING__ and defers the work to a trailing
           // run ~450ms after scrolling settles, which is exactly when the colour
           // changes. Every colour write in this function already consults onArt(),
           // so folding the ad test in here excludes ads from ALL of them at once
           // rather than patching each write site.
           "var ADSEL2='[class*=ape-placement],[class*=ape-wrapper],[data-cel-widget*=ape],[id*=ape_],[class*=theming-card],[class*=ape]';"
           "function inAd(e4){try{"
             "if(e4.__adIn!==undefined)return e4.__adIn;"
             "var v=!!(e4.closest&&e4.closest(ADSEL2));"
             "try{e4.__adIn=v;}catch(e){}return v;"
           "}catch(e){return false;}}"
           "function onArt(e2){try{"
             "if(inAd(e2))return true;"
             "var r5=e2.getBoundingClientRect();"
             "if(r5.width<1||r5.height<1)return false;"
             "return artOverlap(r5)>=0.5;"
             "}catch(e){}return false;}"
           // A dark panel inside a still-light card reads as a box behind the text.
           "function ancLight(e3){try{var pa=e3.parentElement,pd=0;"
             "var vh2=window.innerHeight||800;"
             "while(pa&&pd++<4){var pl2=lum(getComputedStyle(pa).backgroundColor);"
               "if(pl2!==null){if(pl2<=0.55)return false;"
                 "var pr5=pa.getBoundingClientRect();"
                 // page-sized light ground is a target, not a protector
                 "return (pr5.height<vh2*0.75);}"
               "pa=pa.parentElement;}"
             "}catch(e){}return false;}"           // Read the themed background off <html> rather than plumbing another
           // format argument through two call sites.
           "var BG='rgb(24,26,27)';try{var hb=getComputedStyle(document.documentElement).backgroundColor;"
             "var hl=lum(hb);if(hl!==null&&hl<0.25)BG=hb;}catch(e){}"
           "var SKIP=/star|prime|logo|flag|swatch|thumb|sponsor|pill-image|product-image|photo|heart|wish|lists-framework|avatar|profile|author|reviewer|byline|merchant|seller|brand|store|logo-|-logo|headshot|user-image|customer/i;"
           // PRODUCT ART GUARD. One definition, enforced at every filtering site:
           // merchandise imagery must never be recoloured anywhere in the app.
           // Deliberately broad -- a missed glyph is cosmetic, an inverted
           // product photo is not.
           "var PRODC='[class*=s-product-image],[class*=product-image],[class*=s-image],"
             "[class*=a-dynamic-image],[class*=image-container],[data-component-type=s-search-result],"
             "[class*=asin],[class*=carousel],[class*=faceout],[class*=gwm],[class*=cardui],"
             "[class*=deal],[class*=promo],[class*=hero],[class*=creative],[class*=ad-],[id*=gw-]';"
           // A filter on a container repaints everything beneath it, so only leaf
           // glyphs may ever be filtered. This is what inverted the bugle: the
           // icon itself was untouched, its wrapper was not.
           // A raster image beyond glyph size is a photo. Silhouetting one paints
           // a solid white rectangle, which is what happened to order thumbnails.
           "function isPhoto(el7){try{"
             "if(!el7||!el7.tagName)return false;"
             "if(el7.tagName.toLowerCase()!=='img')return false;"
             "var r7=el7.getBoundingClientRect();"
             "return (r7.width>48||r7.height>48);"
           "}catch(e){return false;}}"
           // TIME BUDGET. This pass runs on every DOM mutation and every heartbeat
           // tick, and across 19 loops it can visit ~13,300 elements, nearly all of
           // them doing getComputedStyle or getBoundingClientRect. Unbounded, that
           // is seconds of blocked main thread -- which is the scroll lag. Each loop
           // now yields once the budget is spent; elements already handled are
           // marked and skipped cheaply, so successive passes pick up where the last
           // left off and coverage still converges.
           // PER-SECTION budget, not one shared deadline. A single 16ms budget is
           // first-come-first-served: the sections before RS spend all of it, so
           // every later loop -- including TQ, the tileart pass that whitens dark
           // icons -- exits on its first iteration having done nothing. That is the
           // bugle and the card icon going dark. Each section now gets its own
           // slice, so no single loop can block, but every loop still gets to run.
           "var __T0=Date.now(),__t0=__T0,__ckl=[],__cut=0;"
           "function __ck(n){try{__ckl.push(n+':'+(Date.now()-__T0));__t0=Date.now();}catch(e){}}"
           "function ovr(){if(Date.now()-__t0>16){__cut++;return true;}return false;}"
           "function holdsArt(el6){try{"
             "return !!(el6&&el6.querySelector&&el6.querySelector('img,picture,video,canvas,svg'));"
           "}catch(e){return false;}}"
           "function artChk(e9){try{"
             "var w9=Math.round(e9.getBoundingClientRect().width);"
             "if(e9.__adArtW===w9&&e9.__adArtV!==undefined)return e9.__adArtV;"
             "var v9=(isPhoto(e9)||holdsArt(e9)||isProdArt(e9));"
             "e9.__adArtW=w9;e9.__adArtV=v9;return v9;"
           "}catch(err){return true;}}"
           "function isProdArt(el4){try{"
             "if(!el4||!el4.tagName)return false;"
             "var tg4=el4.tagName.toLowerCase();"
             "var al4=(el4.getAttribute&&el4.getAttribute('alt'))||'';"
             // a descriptive alt is merchandise copy, never a UI glyph
             "if(al4.length>18)return true;"
             "var r4=el4.getBoundingClientRect();"
             "if(r4.width>140||r4.height>140)return true;"
             "var cl4=el4.className;if(cl4&&cl4.baseVal!==undefined)cl4=cl4.baseVal;cl4=String(cl4||'');"
             "if(/product|asin|thumb|photo|hero|creative|poster|cover-art/i.test(cl4))return true;"
             // Round crops are avatars, store marks and review photos -- content,
             // never chrome. This is the shape both reported regressions shared.
             "try{var brs4=getComputedStyle(el4).borderRadius;"
             "var br4=parseFloat(brs4)||0;"
               "var pct4=/%%/.test(brs4);"
               "var circ4=(pct4?br4>=40:(br4>=r4.width*0.4));"
               "if(circ4){"
                 "if(r4.width>=40)return true;"
                 // A CIRCLE BACKED BY A REAL BITMAP is a photo scaled down -- a store
                 // mark, an avatar, a review thumb -- not a glyph. The width>=40 floor
                 // above missed exactly that: shop circles render at 32px from a
                 // 192px source, so they failed the circular test and got silhouetted
                 // into solid white discs. Display size is the wrong axis here.
                 "if(tg4==='img'&&((el4.naturalWidth||0)>64||(el4.naturalHeight||0)>64))return true;"
               "}}catch(e){}"
             "if(el4.closest&&el4.closest(PRODC)){"
               // inside merchandising chrome: only a small, label-bearing tile
               // icon may still be treated as a glyph
               "if(!(r4.width<=48&&r4.height<=48))return true;"
               "if(/sbs-pill-image|icon/i.test(cl4))return false;"
               // A GLYPH-SIZED element inside an interactive control is chrome,
               // whatever it happens to be overlaid on. The compare/list buttons sit
               // on top of the product image, so they inherit the search-result
               // container and every guarded site read them as artwork and refused
               // to whiten them. Anything over 48px already returned true above, so
               // no product photo can reach this line.
               "if(el4.closest('button,[role=button],[aria-label],[data-action],"
                 "[class*=button],[class*=btn],[class*=action]'))return false;"
               "return true;}"
             "if(tg4==='img'){var nw=el4.naturalWidth||0,nh=el4.naturalHeight||0;"
               "if(nw>400||nh>400)return true;}"
             "}catch(e){}return false;}"           // Classes the probe confirmed are monochrome UI glyphs. These get a
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
             // v5.288: skip ad subtrees before ANY work. onArt() alone was not
             // enough -- several colour writes further down (the cardui sweep, the
             // glyph and shadow passes) never consult it, so an ad card could still
             // be recoloured on the trailing post-scroll run. One exit here covers
             // every branch in the pass.
             "if(inAd(el))continue;"
             "var cs=getComputedStyle(el);"
             // NO LIGHT PANELS. Anything still measuring light after Dark Reader has
             // run is a miss -- a gradient it could not parse, a shadow subtree, an
             // inline style it skipped. Correct by COMPUTED value so the mechanism
             // does not matter. els is in document order, so an ancestor is darkened
             // before its children are contrast-checked against it.
             "if(lfix<500){var pl=lum(cs.backgroundColor);"
               "if(pl!==null&&pl>0.55&&!onArt(el)&&!ancLight(el)){"
                 "if(!inAdCard(el))el.style.setProperty('background-color',BG,'important');lfix++;}}""el.__adBgBy='lfix';"
             // LARGE light panels, uncapped. Section-sized light surfaces (the
             // pharmacy pink wrapper, the light-blue insurance strip) are never
             // content -- darken them even after the general cap is spent.
             "if(bigfix<120){var plb=lum(cs.backgroundColor);"
               "if(plb!==null&&plb>0.55&&!onArt(el)){var rb=el.getBoundingClientRect();"
                 "if(rb.width>=200&&rb.height>=80){"
                   "el.style.setProperty('background-color',BG,'important');bigfix++;}}}""el.__adBgBy='bigfix';"
             // LIGHT GRADIENTS. lfix read 0 on every line while a 430x627 light panel
             // sat on screen, because a gradient lives in background-IMAGE and is
             // invisible to a backgroundColor check. The probe named it:
             // div.wd-backdrop-gradient, the 'Researched by Alexa' card. Parse the
             // stops and only neutralise gradients that actually resolve light, so
             // decorative dark gradients are left alone.
             "if(lfix<500){var gbi=cs.backgroundImage||'';"
               "if(gbi.indexOf('gradient')>=0&&el.closest){"
                 "try{if(el.closest('[data-hook*=review],[class*=a-expander],[class*=expander-partial]')){"
                   "el.style.setProperty('background-image','none','important');"
                   "el.style.setProperty('background','none','important');}}catch(e){}}"
               "if(gbi.indexOf('gradient')>=0){var g2=el.getBoundingClientRect();"
                 "if(g2.width>120&&g2.height>28){var gmx=0,gm,gre=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/g;"
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
               "var inFlt=false;try{inFlt=!!(el.closest&&el.closest("
                 "'[class*=filter],[class*=refinement],[class*=facet]'));}catch(e){}"
               "var lim=inFlt?72:(ICON.test(cn2)?40:36);"
               "var inContent=false;try{inContent=!!(el.closest&&el.closest("
                 "'[data-hook*=review],[class*=review],[class*=profile],[class*=avatar],"
                 "[class*=author],[class*=byline],[class*=merchant],[class*=seller],"
                 "[class*=brand],[class*=store],[id*=review]'));}catch(e){}"
               // A real <img> carrying alt text is almost always content (an
               // avatar's alt is the person's name, a logo's is the brand). Icon
               // markup uses a nested a-icon-alt span, not the img's own alt, so
               // this does not catch the glyphs we actually want.
               "var isI=el.tagName.toLowerCase()==='img';"
               "var hasAlt=isI&&el.getAttribute&&(el.getAttribute('alt')||'').trim().length>1;"
               "if(gr.width>5&&gr.width<=lim&&gr.height>5&&gr.height<=lim&&!SKIP.test(cn2)&&!ot&&(function(){var b9=bgOf(el);return b9!==null&&b9<=0.5;})()&&!inContent&&(inFlt||!hasAlt)){"
                 "var hasB=cs.backgroundImage&&cs.backgroundImage!=='none';"
                 "if(isI||hasB){"
                   // Guard BEFORE the write. This ran after it, so a product photo
                   // was silhouetted first and the continue then skipped the mark,
                   // leaving it invisible to every by= audit.
                   "if(artChk(el))continue;"
                   "el.style.setProperty('filter','brightness(0) invert(1)','important');"
               "el.__adGlyph=1;el.__adBy='gfix1';gfix++;}}"
             "}catch(e){}}"
             "if(el.tagName&&el.tagName.toLowerCase()==='img'&&lfix<500){"
               "var pw2=el.getBoundingClientRect();"
               // Glyph-sized art never needs a backdrop; the dark panel behind a
               // small search-bar icon is the black box, not a feature.
               "if(pw2.width>0&&pw2.width<=48&&pw2.height>0&&pw2.height<=48){"
                 "el.style.setProperty('background-color','transparent','important');}"
               // Any image sitting on a LIGHT surface -- promo cards, banners,
               // hero lockups like the pharmacy wordmark -- must not carry the
               // dark backdrop. No width cap: a wide logo needs this too.
               "else if((function(){var b8=bgOf(el.parentElement||el);return b8!==null&&b8>0.06;})()){"
                 "el.style.setProperty('background-color','transparent','important');}}"
             "try{if(lfix<500&&el.tagName){var tn3=el.tagName.toLowerCase();"
               "if(tn3!=='img'&&tn3!=='svg'&&tn3!=='canvas'){"
                 "var ownbl=lum(cs.backgroundColor);"
                 "if(ownbl!==null&&ownbl<0.25){"
                   "var pbl=bgOf(el.parentElement||el);if(pbl===null)pbl=0.02;"
                   // Surface is a distinct colour (teal) or light, and clearly
                   // lighter than the element's own near-black fill: our box, not
                   // a real chip. Margin of 0.12 keeps genuine dark-on-dark chips.
                   "if(pbl>0.12&&pbl>ownbl+0.12){el.style.setProperty('background-color','transparent','important');}}}}"
             "}catch(e){}"
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
                     "if(artChk(el))continue;"
               "el.style.setProperty('filter','brightness(0) invert(1)','important');el.__adGlyph=1;el.__adBy='gfix2';gfix++;}"
                 "}catch(e){}}"
               "var fl2=lum(cs.fill),sl=lum(cs.stroke);"
               "if(fl2!==null&&fl2<0.45){el.style.setProperty('fill',FG,'important');n++;}"
               "if(sl!==null&&sl<0.45){el.style.setProperty('stroke',FG,'important');n++;}"
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
                 "if(pcl!==null&&pcl<0.50&&!onArt(el)){el.style.setProperty('color',FG,'important');n++;}}"
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
             // Text overlaid on a promo/hero IMAGE keeps its own colour. Catches
             // both a CSS url() background and an <img>/<picture> that actually
             // OVERLAPS this text (product titles sit BELOW their image, so they
             // do not overlap and are still themed normally).
             "var overImg=false;"
             "try{var tr=el.getBoundingClientRect();var pe2=el,pd2=0;"
               "var ovl=function(ir){return ir.width>=100&&ir.height>=100"
                 "&&ir.left<tr.right&&ir.right>tr.left&&ir.top<tr.bottom&&ir.bottom>tr.top;};"
               "while(pe2&&pd2++<10){var pcs2=getComputedStyle(pe2);"
                 "if((pcs2.backgroundImage||'').indexOf('url(')>=0){overImg=true;break;}"
                 "var ims=pe2.querySelectorAll?pe2.querySelectorAll('img,picture,video'):[];"
                 "for(var qi=0;qi<ims.length;qi++){if(ovl(ims[qi].getBoundingClientRect())){overImg=true;break;}}"
                 "if(overImg)break;"
                 "var sib=pe2.previousElementSibling,sc=0;"
                 "while(sib&&sc++<4){if(/^(img|picture|video)$/i.test(sib.tagName)&&ovl(sib.getBoundingClientRect())){overImg=true;break;}"
                   "var si=sib.querySelectorAll?sib.querySelectorAll('img,picture,video'):[];"
                   "for(var sj=0;sj<si.length;sj++){if(ovl(si[sj].getBoundingClientRect())){overImg=true;break;}}"
                   "if(overImg)break;sib=sib.previousElementSibling;}"
                 "if(overImg||lum(pcs2.backgroundColor)!==null)break;"
                 "pe2=pe2.parentElement;}}catch(e){}"
             "if(overImg){"
               "try{if(!window.__AD_PROMO__&&el.getBoundingClientRect().width>70){"
                 "var pcn=el.className;if(pcn&&pcn.baseVal!==undefined)pcn=pcn.baseVal;"
                 "var par=el.parentElement,pp='';if(par){var pc=par.className;if(pc&&pc.baseVal!==undefined)pc=pc.baseVal;pp=String(pc||'').split(' ')[0];}"
                 "window.__AD_PROMO__=el.tagName.toLowerCase()+'.'+String(pcn||'').split(' ')[0].slice(0,34)"
                   "+'^'+pp.slice(0,28)+'/'+cs.color;}}catch(e){}"
               "if(lum(cs.color)!==null&&lum(cs.color)>0.5)"
                 "el.style.setProperty('color','#0f1111','important');continue;}"
             "var bl=bgOf(el);"
             // ground is artwork: we cannot know the contrast, so leave the site's
             // own colour alone rather than guessing and correcting later
             "if(bl===null)continue;"
             "var hi=Math.max(fl,bl)+0.05,lo=Math.min(fl,bl)+0.05;"
             // NAMED EXEMPTION. onArt exists to keep captions printed on an ad creative
             // stock, and it must stay -- but a carousel's "Sponsored" label sits over
             // the product thumbnail, trips the same test, and is left dark while the
             // info icon beside it (an image, handled by a glyph pass that never
             // consults onArt) goes light. That mismatch is the reported symptom.
             //
             // Scoped as tightly as I can make it: the exact word, a label-sized box,
             // and a leaf node. A caption on a creative is none of those things.
             // Reset per element sweep: the tracker persisted across passes, so it reported a
             // historical minimum captured before our write landed rather than the
             // current colour. That is what made lum=0.35 look like a live failure.
             "if(!window.__ADSPXR__){window.__ADSPXR__=1;window.__AD_SPXL__=undefined;window.__AD_SPX__=null;"
             // Do NOT zero the total here. The report reads __AD_SPXT__, and resetting
             // it at the start of the sweep is why P2SPON went from seen=74 to seen=0:
             // the counter was being cleared and then read before the sweep refilled
             // it on a throttled pass. Only the darkest-sample state needs resetting.
             "}"
             "var spx=false;"
             // NOT a leaf. "Sponsored" and its info icon share a span, so
             // childElementCount===0 was never true and SPON stayed at zero.
             // The text and size caps already do the narrowing.
             "try{if(el.childElementCount<=6){"
               "var stt=String(el.textContent||'').trim();"
               "var sbr=el.getBoundingClientRect();"
               // VISIBLE NODES ONLY, and report what matched. SPON counts writes that land,
               // yet the label stays dark -- which means we are colouring a node that is not
               // the one being painted. Amazon ships screen-reader duplicates of this exact
               // string, and the old test had only an UPPER size bound, so a clipped 1px
               // offscreen span passed it happily while the visible label went untouched.
               "if(/^sponsored/i.test(stt)&&stt.length<=14"
                   "&&sbr.width>=18&&sbr.height>=7&&sbr.width<=220&&sbr.height<=44)spx=true;}"
             "}catch(e){}"
             // Self-contained: records the first Sponsored-ish node WE SEE, matched or not,
             // so the next log distinguishes "wrong node" from "never matched".
             "try{if(el.childElementCount<=8){var _t=String(el.textContent||'').trim();if(/^sponsored/i.test(_t)){var _r=el.getBoundingClientRect();if(_r.width>4){var _k=el.firstElementChild;var _ic=getComputedStyle(el).color;var _kc=_k?getComputedStyle(_k).color:_ic;var _l1=lum(_ic),_l2=lum(_kc);var _lm=Math.min(_l1===null?1:_l1,_l2===null?1:_l2);window.__AD_SPXT__=(window.__AD_SPXT__||0)+1;if(window.__AD_SPXL__===undefined||_lm<window.__AD_SPXL__){window.__AD_SPXL__=_lm;var _c=el.className;if(_c&&_c.baseVal!==undefined)_c=_c.baseVal;window.__AD_SPX__=el.tagName+'@'+Math.round(_r.width)+'x'+Math.round(_r.height)+'|kids='+el.childElementCount+'|hit='+(spx?1:0)+'|lum='+_lm.toFixed(2)+'|ink='+_ic+'|kid='+_kc+'|cls='+String(_c||'').slice(0,14)+'|anc='+(_an||'none')+'|self='+String(getComputedStyle(el).webkitTextFillColor||'-').slice(0,18)+'/op'+getComputedStyle(el).opacity+'/f'+String(getComputedStyle(el).filter||'none').slice(0,10);}}}}}catch(e){}"
             "var _an='',_ap=el.parentElement,_ad=0;while(_ap&&_ad++<6){var _af=getComputedStyle(_ap);var _ff=String(_af.filter||'none'),_oo=String(_af.opacity||'1'),_bb=String(_af.mixBlendMode||'normal');if(_ff!=='none'||_oo!=='1'||_bb!=='normal'){_an+='^'+String(_ap.className||'').slice(0,10)+'='+_ff.slice(0,12)+'/op'+_oo+'/'+_bb+'|by='+(_ap.__adBy||'-');}_ap=_ap.parentElement;}"
             // spx must bypass the CONTRAST test, not just the onArt guard. bgOf sees
             // the white product thumbnail behind the label, reads the contrast as
             // good, and never enters this branch at all -- so the exemption never got
             // a chance to apply and relaxing the leaf test could not have helped.
             // A Sponsored label that is currently dark is lightened outright.
             // NO DARKNESS TEST FOR A SPONSORED LABEL. SPX reported hit=1 with
             // ink=rgb(178,172,162) -- luminance 0.68, a mid grey, not black. The
             // fl<0.5 gate I wrote assumed the label would be near-black, so a label
             // that was already partly themed failed it and was never written, while
             // SPON counted the genuinely dark ones elsewhere. The label should simply
             // match the card's other text, so it is set unconditionally.
             // Pull back: writing unconditionally hit 107 elements and still did not
             // fix the label, so it was spraying, not fixing. Only act when THIS node
             // or its first child is actually dark ink -- SPX will now show both.
             "var kink=null;try{var kfc=el.firstElementChild;"
               "if(kfc)kink=lum(getComputedStyle(kfc).color);}catch(e){}"
             "if(inAdCard(el))window.__AD_TXTSKIP__=(window.__AD_TXTSKIP__||0)+1;"
             "if(!inAdCard(el)&&((spx&&((fl!==null&&fl<0.55)||(kink!==null&&kink<0.55)))"
               "||(hi/lo<3.0&&!onArt(el)))){"
               "el.style.setProperty('color',FG,'important');"
               // SPON=4 proved the write lands, yet the label still renders dark --
               // so we are colouring a WRAPPER while an inner node carries its own
               // colour. Inline !important beats any stylesheet, so the only way this
               // loses is if the painted glyphs belong to a different element.
               // -webkit-text-fill-color is set too because it overrides color
               // outright wherever Dark Reader has applied it.
               "if(spx){try{"
                 // -webkit-text-fill-color OVERRIDES color when painting but leaves
                 // color reading unchanged, and opacity on the element itself dims
                 // light ink toward the background. Either produces exactly what we
                 // observe: ink=rgb(232,230,227) and dark pixels. The ancestor walk
                 // started at parentElement, so the span's OWN opacity was never
                 // measured. Both are forced here, and both are reported below.
                 "el.style.setProperty('-webkit-text-fill-color',FG,'important');"
                 "el.style.setProperty('opacity','1','important');"
                 "el.style.setProperty('mix-blend-mode','normal','important');"
                 "el.style.setProperty('filter','none','important');"
                 "var kids=el.querySelectorAll('*');"
                 "for(var ki=0;ki<kids.length&&ki<6;ki++){"
                   "var kt=kids[ki].tagName;"
                   "if(kt==='IMG'||kt==='SVG'||kt==='svg'||kt==='PATH'||kt==='USE')continue;"
                   "kids[ki].style.setProperty('color',FG,'important');"
                   "kids[ki].style.setProperty('-webkit-text-fill-color',FG,'important');"
                   "kids[ki].style.setProperty('opacity','1','important');"
                   "kids[ki].style.setProperty('filter','none','important');}"
               "}catch(e){}"
               "window.__AD_SPON__=(window.__AD_SPON__||0)+1;}n++;}}"

           // Clear stray dark square wrappers around the buttons (the box that
           // can extend past the pill). Shapes/borders are persistent CSS above.
           // WHITE-BACKGROUND TAMING (opt-in, Settings > AmazonDark).
           // v5.361: media elements still use a filter, but CSS-background creatives
           // use background-blend-mode instead. A CSS filter on a card container also
           // filters every child -- including the headline -- which is exactly why
           // some top-carousel copy was sitting "behind" the tame while img-backed
           // cards were fine. Blend mode darkens the background image only.
           "try{if(window.__ADTAME_ON__){"
             "var cL=Math.max(0.12,Math.min(0.95,1-0.85*(window.__ADTAME_S__||45)/100));"
             "var S7=(window.__ADTAME_S__||45);"
             "var bb9=(1-0.50*(S7/100)).toFixed(3),aa9=(0.50*(S7/100)).toFixed(3);"
             "function ctx7(e,re){try{var p=e,d=0;while(p&&d++<7){var rr=p.getBoundingClientRect();"
               "if(rr.width>=100&&rr.height>0&&rr.height<=720){var tx=String(p.textContent||'').replace(/\\s+/g,' ').trim();"
                 "if(tx.length>0&&tx.length<2200&&re.test(tx))return true;}p=p.parentElement;}}catch(e){}return false;}"
             "function force7(e){return _adTameBand362(e)===2||ctx7(e,/(?:returns are easy|send an amazon gift card|subscribe\\s*&\\s*save|shop previously watched)/i)"
               "||/alexa|rufus/i.test(String(location.href||'')+' '+String(document.title||''));}"
             "function explore7(e){return _adTameBand362(e)===-1||ctx7(e,/explore more for you/i);}"
             // Repair stale experimental SVG-filter state from old builds.
             "try{var OLD=document.querySelectorAll('[style*=adtamef]');"
             "__ck('OLD');"
               "for(var o9=0;o9<OLD.length&&o9<300&&((o9&15)||!ovr());o9++){"
                 "OLD[o9].style.removeProperty('filter');OLD[o9].__adTamed=0;}"
               "var hostOld=document.getElementById('adtamef-host');"
               "if(hostOld&&hostOld.parentNode)hostOld.parentNode.removeChild(hostOld);"
             "}catch(e){}"
             "var tamed=0,bgtamed=0;"
             // Real media: filter the media itself, never its text-bearing parent.
             // Never filter an iframe as one composited layer: that dims its DOM text too.
             // Child ad frames run their own media-only tame below, so only the photo/video
             // paint is darkened while authored copy remains stock and above it.
             "var PI=document.querySelectorAll('img,video,canvas');"
             "for(var pi=0;pi<PI.length&&pi<360&&((pi&15)||!ovr());pi++){var im7=PI[pi];"
               "var band7=_adTameBand362(im7);if(band7===-1||_adExploreIcon363(im7)){im7.removeAttribute('data-ad-tame-fast362');if(im7.__adTamed){im7.style.removeProperty('filter');im7.__adTamed=0;im7.__adBy='tameSkip364';}continue;}var review7=(band7===3),prod7=_adKnownProduct366(im7),force=(band7===2)||force7(im7),explore=explore7(im7)&&!force;"
               "if(explore){im7.removeAttribute('data-ad-tame-fast362');if(im7.__adTamed){im7.style.removeProperty('filter');im7.__adTamed=0;im7.__adBy='tameSkip364';}continue;}"
               "var tg7=String(im7.tagName||'').toUpperCase();if(review7&&tg7!=='IMG')continue;"
               "var sig7=tg7+'|'+String(im7.currentSrc||im7.src||im7.getAttribute&&im7.getAttribute('poster')||'');"
               "if(im7.__adTamed&&im7.__adTameSig===sig7&&String(getComputedStyle(im7).filter||'').indexOf('brightness')>=0)continue;"
               "var ir7=im7.getBoundingClientRect();var min7=(force||review7||prod7)?24:56;"
               "if(ir7.width<min7||ir7.height<min7)continue;"
               "if(im7.__adGlyph&&!force&&!review7&&!prod7)continue;"
               "var icn7=im7.className;if(icn7&&icn7.baseVal!==undefined)icn7=icn7.baseVal;"
               "if(review7&&/sprite|icon|logo|pixel|star|rating|close/i.test(String(icn7||'')))continue;"
               "if(!force&&!review7&&!prod7&&/sprite|icon|logo|pixel/i.test(String(icn7||'')))continue;"
               "im7.setAttribute('data-ad-tame-fast362','1');im7.style.setProperty('filter','brightness('+bb9+') saturate(1.08)','important');"
               "im7.__adTamed=1;im7.__adTameSig=sig7;im7.__adBy=review7?'whiteTameReview366':(force?'whiteTame361ctx':'whiteTame361');tamed++;}"
             // CSS-background creative: multiply ONLY the painted background. Applying
             // filter here would dim/recolour all descendant text as one composited layer.
             "var PB=document.querySelectorAll('div,span,a,section,li');"
             "__ck('PB');"
             "for(var z9=0;z9<PB.length&&z9<900&&((z9&15)||!ovr())&&bgtamed<72;z9++){"
               "var be9=PB[z9];if(_adHomeBgLeaf395(be9))continue;if(_adBgPlacement365(be9))continue;var bs9=getComputedStyle(be9),bi9=String(bs9.backgroundImage||'none');"
               "if(bi9.indexOf('url(')<0)continue;"
               "var bandb=_adTameBand362(be9);if(bandb===-1||bandb===3||_adExploreIcon363(be9)){be9.removeAttribute('data-ad-tame-bgfast364');if(be9.__adTamed){be9.style.removeProperty('background-blend-mode');be9.style.removeProperty('background-color');be9.__adTamed=0;be9.__adBy='tameSkip364';}continue;}var forceb=(bandb===2)||force7(be9),exploreb=explore7(be9)&&!forceb;"
               "if(exploreb){be9.removeAttribute('data-ad-tame-bgfast364');if(be9.__adTamed){be9.style.removeProperty('background-blend-mode');be9.style.removeProperty('background-color');be9.__adTamed=0;be9.__adBy='tameSkip364';}continue;}"
               "var br9=be9.getBoundingClientRect(),minb=forceb?32:56;if(br9.width<minb||br9.height<minb)continue;"
               "var bcn=be9.className;if(bcn&&bcn.baseVal!==undefined)bcn=bcn.baseVal;"
               "if(!forceb&&/sprite|icon|logo|pixel/i.test(String(bcn||'')))continue;"
               "var bsig='BG|'+bi9;if(be9.__adTamed&&be9.__adTameSig===bsig&&String(getComputedStyle(be9).backgroundBlendMode||'').indexOf('multiply')>=0)continue;"
               "if(be9.querySelector&&be9.querySelector('span,p,h1,h2,h3,h4,a')&&_adMark(be9))try{be9.setAttribute('data-ad-stocktext','1');}catch(e){}"
               "be9.setAttribute('data-ad-tame-bgfast364','1');be9.style.setProperty('background-color','rgba(0,0,0,'+aa9+')','important');"
               "be9.style.setProperty('background-blend-mode','multiply','important');"
               "be9.__adTamed=1;be9.__adTameSig=bsig;be9.__adBy=forceb?'whiteTame361bgctx':'whiteTame361bg';bgtamed++;}"
             "if(tamed||bgtamed)window.__AD_TAME__='media='+tamed+' bg='+bgtamed+' ceil='+cL.toFixed(2);"
           "}}catch(e){}"
                      // DARK LOGO LIFT. A brand mark is mostly transparent with dark ink; a
           // product photo is opaque edge to edge. That difference is measurable,
           // so logos can be lifted without any photo being touched.
           "try{if(!window.__AD_LOGOQ__)window.__AD_LOGOQ__=1;"
             "var LG=document.querySelectorAll('img');"
             "for(var lg=0;lg<LG.length&&lg<200;lg++){var le=LG[lg];"
               "if(le.__adLogo)continue;"
               "var lr=le.getBoundingClientRect();"
               "if(lr.width<40||lr.width>240||lr.height<20||lr.height>240)continue;"
               "if(String(getComputedStyle(le).filter||'none').indexOf('invert')>=0)continue;"
               "var lsrc=le.currentSrc||le.src;if(!lsrc)continue;"
               "le.__adLogo=1;"
               "(function(el8,src8){try{"
                 "var pi8=new Image();pi8.crossOrigin='anonymous';"
                 "pi8.onload=function(){try{"
                   "var w8=Math.min(pi8.naturalWidth||32,40),h8=Math.min(pi8.naturalHeight||32,40);"
                   "if(!w8||!h8)return;"
                   "var cv8=document.createElement('canvas');cv8.width=w8;cv8.height=h8;"
                   "var cx8=cv8.getContext('2d');cx8.drawImage(pi8,0,0,w8,h8);"
                   "var d8=cx8.getImageData(0,0,w8,h8).data;"
                   "var tot=0,clear=0,sum=0,cnt=0,lite=0,sat8=0;"
                   "for(var z8=0;z8<d8.length;z8+=4){tot++;"
                     "if(d8[z8+3]<40){clear++;continue;}"
                     "var l8=0.2126*d8[z8]+0.7152*d8[z8+1]+0.0722*d8[z8+2];"
                     "sum+=l8;cnt++;if(l8>153)lite++;"
                     "var m8=d8[z8]>d8[z8+1]?d8[z8]:d8[z8+1];if(d8[z8+2]>m8)m8=d8[z8+2];"
                     "var n8=d8[z8]<d8[z8+1]?d8[z8]:d8[z8+1];if(d8[z8+2]<n8)n8=d8[z8+2];"
                     "sat8+=(m8-n8);}"
                   "if(!cnt||!tot)return;"
                   "var clearFrac=clear/tot,avg8=(sum/cnt)/255,liteFrac=lite/cnt;"
                   "var sf8=((sat8/cnt)/255);"
                   // opaque edge to edge => photograph, never touched
                   "if(clearFrac<0.35)return;"
                   // already has light ink => renders fine on a dark ground
                   "if(avg8>=0.45||liteFrac>=0.10)return;"
                   // COLOUR IS NEVER INVERTED. This pass measured luminance only, and
                   // an orange star sprite is dark enough on average to read as ink --
                   // so it was flipped, hue and partial fill included. TILEART[n=0]
                   // proves the tileart pass never ran, and this one is unstamped,
                   // which is why every probe reported the offender as by=-.
                   "if(sf8>=0.10){if(!window.__AD_LOGO__)window.__AD_LOGO__="
                     "'skipped-colour sat='+sf8.toFixed(2);return;}"
                   "el8.style.setProperty('filter','invert(1)','important');"
                   "el8.__adGlyph=1;el8.__adBy='logolift';"
                   "if(!window.__AD_LOGO__)window.__AD_LOGO__="
                     "'lifted clear='+clearFrac.toFixed(2)+' avg='+avg8.toFixed(2);"
                 "}catch(e){if(!window.__AD_LOGO__)window.__AD_LOGO__='tainted';}};"
                 "pi8.onerror=function(){if(!window.__AD_LOGO__)window.__AD_LOGO__='cors-fail';};"
                 "pi8.src=src8;"
               "}catch(e){}})(le,lsrc);}"
           "}catch(e){}"
                      // TEXT-SOURCE + BOX-SOURCE PROBE. Always reports.
                      "try{if(!window.__AD_TXTSRC__){"
                        "var QQ=document.querySelectorAll('span,p,h1,h2,h3,a,div');"
                        "var pick=null,seen=0,onart=0;"
                        "for(var y1=0;y1<QQ.length&&y1<3000&&!pick;y1++){var e1=QQ[y1];"
                          "var has=false;"
                          "for(var y2=0;y2<e1.childNodes.length&&y2<4;y2++){"
                            "var q1=e1.childNodes[y2];"
                            "if(q1.nodeType===3&&q1.nodeValue&&q1.nodeValue.trim().length>2){has=true;break;}}"
                          "if(!has)continue;"
                          "var r1=e1.getBoundingClientRect();"
                          "if(r1.width<40||r1.height<8)continue;seen++;"
                          // sits on a creative?
                          "var a1=e1.parentElement,d1=0,art=null;"
                          "while(a1&&d1++<6){var ab=getComputedStyle(a1).backgroundImage||'';"
                            "if(ab.indexOf('url(')>=0){var ar=a1.getBoundingClientRect();"
                              "if(ar.width>160&&ar.height>60){art=a1;break;}}"
                            "a1=a1.parentElement;}"
                          "if(!art)continue;onart++;"
                          "pick=e1;}"
                        "if(!pick){window.__AD_TXTSRC__='none text='+seen+' onart='+onart;}"
                        "else{"
                          "var inl=String(pick.style.getPropertyValue('color')||'-');"
                          "var comp=getComputedStyle(pick).color.replace(/ /g,'');"
                          // which stylesheet rule is setting the colour?
                          "var hit='-',sheets=0,blocked=0;"
                          "try{for(var s1=0;s1<document.styleSheets.length;s1++){"
                            "var rr=null;try{rr=document.styleSheets[s1].cssRules;}catch(e){blocked++;continue;}"
                            "if(!rr)continue;sheets++;"
                            "for(var s2=0;s2<rr.length&&s2<3000;s2++){var one=rr[s2];"
                              "if(!one||!one.selectorText||!one.style)continue;"
                              "if(!one.style.getPropertyValue('color'))continue;"
                              "try{if(!pick.matches(one.selectorText))continue;}catch(e){continue;}"
                              "hit=one.selectorText.slice(0,60)+' => '+one.style.getPropertyValue('color');"
                            "}}}catch(e){}"
                          "window.__AD_TXTSRC__='inline='+inl.slice(0,18)+' comp='+comp"
                            "+' rule='+hit+' sheets='+sheets+'/'+blocked"
                            "+' marks:'+(pick.__adPinned?'pin ':'')+(pick.__adBy||'-');"
                          // and the box behind it
                          "try{var br=pick.getBoundingClientRect();"
                            "var cx=Math.round(br.left+br.width/2),cy=Math.round(br.top+br.height/2);"
                            "var st=document.elementsFromPoint(cx,cy)||[];var lay='';"
                            "for(var s3=0;s3<st.length&&s3<5;s3++){var le=st[s3];"
                              "var lb=lum(getComputedStyle(le).backgroundColor);"
                              "var lc=le.className;if(lc&&lc.baseVal!==undefined)lc=lc.baseVal;"
                              "var lr=le.getBoundingClientRect();"
                              "lay+=' '+String(lc||le.tagName).slice(0,14)"
                                "+'@'+Math.round(lr.width)+'x'+Math.round(lr.height)"
                                "+'['+(lb===null?'-':lb.toFixed(2))"
                                "+(le.__adBgBy?('/'+le.__adBgBy):'')+']';}"
                            "window.__AD_BOXSRC__=lay||'empty';"
                          "}catch(e){window.__AD_BOXSRC__='err';}"
                        "}"
                      "}}catch(e){window.__AD_TXTSRC__='err '+e;}"
                                            // AD-CARD STRUCTURE PROBE. Always reports.
           "try{if(!window.__AD_CARDX__){"
             "var TT=document.querySelectorAll('span,p,h1,h2,h3,a');"
             "window.__AD_TXTN__=TT.length;"
             "var picked=null,scanned=0;"
             "for(var x1=0;x1<TT.length&&x1<2500&&!picked;x1++){var t1=TT[x1];"
               "var has=false;"
               "for(var x2=0;x2<t1.childNodes.length&&x2<4;x2++){"
                 "var n1=t1.childNodes[x2];"
                 "if(n1.nodeType===3&&n1.nodeValue&&n1.nodeValue.trim().length>2){has=true;break;}}"
               "if(!has)continue;"
               "var r1=t1.getBoundingClientRect();"
               "if(r1.width<40||r1.height<8)continue;"
               "scanned++;"
               // themed light right now?
               "var cl1=lum(getComputedStyle(t1).color);"
               "if(cl1===null||cl1<0.55)continue;"
               // sitting over artwork?
               "var a1=t1.parentElement,d1=0,art=null;"
               "while(a1&&d1++<6){"
                 "var abi=getComputedStyle(a1).backgroundImage||'';"
                 "if(abi.indexOf('url(')>=0){var ar1=a1.getBoundingClientRect();"
                   "if(ar1.width>200&&ar1.height>80){art=a1;break;}}"
                 "a1=a1.parentElement;}"
               "if(!art)continue;"
               "picked=t1;}"
             "if(!picked){window.__AD_CARDX__='none scanned='+scanned+' pool='+TT.length;}"
             "else{"
               "var chain='',cur=picked,dd=0;"
               "while(cur&&dd++<7){"
                 "var ccn=cur.className;if(ccn&&ccn.baseVal!==undefined)ccn=ccn.baseVal;"
                 "ccn=String(ccn||'').split(' ').slice(0,2).join('.');"
                 "var ccs=getComputedStyle(cur);var cr=cur.getBoundingClientRect();"
                 "chain+=' '+(dd===1?'*':'^')+cur.tagName.toLowerCase()"
                   "+(ccn?('.'+ccn.slice(0,26)):'')"
                   "+'@'+Math.round(cr.width)+'x'+Math.round(cr.height)"
                   "+'[bgi='+(((ccs.backgroundImage||'').indexOf('url(')>=0)?'Y':'-')"
                   "+(cur.hasAttribute&&cur.hasAttribute('data-adcrt')?'/MARKED':'')+']';"
                 "cur=cur.parentElement;}"
               "var marked=document.querySelectorAll('[data-adcrt]').length;"
               "window.__AD_CARDX__='col='+getComputedStyle(picked).color.replace(/ /g,'')"
                 "+' markedNodes='+marked+chain;}"
           "}}catch(e){window.__AD_CARDX__='err '+e;}"
                      // CREATIVE MARKER. Server-rendered cards never fire an insertion the
           // fast lane can see, so sweep for them here as well.
           "try{var CQ=document.querySelectorAll('div,section,a,li');var mn=0;"
             "for(var cq=0;cq<CQ.length&&cq<1200;cq++){if(_adMark(CQ[cq]))mn++;}"
             "if(mn)window.__AD_CRTN__='n='+mn;"
           "}catch(e){}"
                      // Mark images whose box falls on a creative, so the backdrop rule can
           // exclude them. Attribute-based so the exclusion is pure CSS once set.
           "try{var BD=document.querySelectorAll('img');var bdn=0;"
             "for(var bd=0;bd<BD.length&&bd<300;bd++){var be=BD[bd];"
               "if(be.hasAttribute('data-adonart'))continue;"
               "var brr=be.getBoundingClientRect();"
               "if(brr.width<20||brr.height<10)continue;"
               "if(typeof artOverlap!=='function')break;"
               "if(artOverlap(brr)>=0.35){be.removeAttribute('data-adbackdrop');continue;}"
               // clear of artwork: a backdrop here helps a transparent glyph and
               // cannot paint over a picture
               "be.setAttribute('data-adbackdrop','1');bdn++;}"
             "if(bdn)window.__AD_ONART__='backdrops='+bdn;"
           "}catch(e){}"
                      // PHOTO RESCUE. Runs before anything else and judges by computed
           // result, not by our own bookkeeping -- a stylesheet rule leaves no
           // mark, which is exactly how order thumbnails were being flattened.
           "try{var RS=document.querySelectorAll('img');var resc=0,rfirst='';"
           "__ck('RS');"
             "for(var rs=0;rs<RS.length&&rs<400&&((rs&15)||!ovr());rs++){var re2=RS[rs];"
               "var rr2=re2.getBoundingClientRect();"
               "if(rr2.width<=48&&rr2.height<=48)continue;"
               "var rf2=String(getComputedStyle(re2).filter||'none');"
               "if(rf2==='none')continue;"
               // brightness(0) exactly -- brightness(0.775) from the tame pass
               // must survive, so the closing paren matters here
               "if(re2.__adLogo&&rf2.indexOf('invert(')>=0)continue;"
               "if(rf2.indexOf('brightness(0)')<0&&rf2.indexOf('invert(')<0)continue;"
               "re2.style.setProperty('filter','none','important');"
               // Identify WHICH injected rule matched, rather than only clearing
               // the result -- the selector is what has to change permanently.
               "if(!window.__AD_RULE__){try{"
                 "var shts=document.styleSheets;"
                 "for(var sh=0;sh<shts.length&&!window.__AD_RULE__;sh++){"
                   "var rls=null;try{rls=shts[sh].cssRules;}catch(e){continue;}"
                   "if(!rls)continue;"
                   "for(var rl=0;rl<rls.length&&rl<4000&&((rl&15)||!ovr());rl++){var one=rls[rl];"
                     "if(!one||!one.selectorText||!one.style)continue;"
                     "var ft=one.style.getPropertyValue('filter')||'';"
                     "if(ft.indexOf('brightness(0)')<0&&ft.indexOf('invert(')<0)continue;"
                     "try{if(!re2.matches(one.selectorText))continue;}catch(e){continue;}"
                     "window.__AD_RULE__=one.selectorText.slice(0,120);break;}}"
               "}catch(e){}}"
               "if(!rfirst){var rcn=re2.className;"
                 "if(rcn&&rcn.baseVal!==undefined)rcn=rcn.baseVal;"
                 "var rp2=re2.parentElement;var rpc=rp2?rp2.className:'';"
                 "if(rpc&&rpc.baseVal!==undefined)rpc=rpc.baseVal;"
                 "rfirst=String(rcn||'img').slice(0,20)+'^'+String(rpc||'-').slice(0,24)"
                   "+'@'+Math.round(rr2.width)+'x'+Math.round(rr2.height);}"
               "resc++;}"
             "if(resc)window.__AD_RESCUE__='n='+resc+' first='+rfirst;"
           "}catch(e){}"
                      // ORDER THUMB AUDIT. Always reports. Names any photo-sized image that
           // is not rendering normally, with every mark we could have left on it.
           "try{var OI=document.querySelectorAll('img');var obad=[],oseen=0;"
           "__ck('OI');"
             "for(var oi=0;oi<OI.length&&oi<300&&((oi&15)||!ovr())&&obad.length<4;oi++){var oe=OI[oi];"
               "var orr=oe.getBoundingClientRect();"
               "if(orr.width<56||orr.height<56)continue;"
               "oseen++;"
               "var ocs=getComputedStyle(oe);"
               "var oflt=String(ocs.filter||'none');"
               "var obg=String(ocs.backgroundColor||'');"
               "var suspect=(oflt.indexOf('brightness(0')>=0)||(oflt.indexOf('invert')>=0)"
                 "||(parseFloat(ocs.opacity||'1')<0.9)||(ocs.visibility==='hidden');"
               "if(!suspect)continue;"
               "var ocn=oe.className;if(ocn&&ocn.baseVal!==undefined)ocn=ocn.baseVal;"
               "obad.push(String(ocn||'img').slice(0,18)"
                 "+'@'+Math.round(orr.width)+'x'+Math.round(orr.height)"
                 "+'|flt='+oflt.slice(0,26)+'|op='+ocs.opacity"
                 "+'|bg='+obg.replace(/ /g,'')"
                 "+'|glyph='+(oe.__adGlyph?1:0)+'|by='+(oe.__adBy||'-')"
                 "+'|tamed='+(oe.__adTamed?1:0));}"
             "window.__AD_ORDERS__=(obad.length?('n='+obad.length+' '+obad.join(' ~ ')):"
               "('clean photos='+oseen));"
           "}catch(e){window.__AD_ORDERS__='err '+e;}"
                      // BEHIND-TEXT AUDIT. The dark rectangle is a sibling/backdrop element,
           // not the text's own background, so probe the paint stack under the
           // text run itself. Reports the full stack with each background and
           // its author tag; always reports, including the clean case.
           // ONCE PER DOCUMENT. Pure diagnostic, and the most expensive thing in
           // the whole pass: up to 2500 document.elementsFromPoint hit-tests, each
           // forcing a full render-tree hit test, re-run on every heartbeat tick
           // and every MutationObserver debounce. Removed once already in v5.160
           // ("blocking first paint since v5.155.0") and it came back.
           "try{if(window.__AD_TB_DONE__)throw 0;window.__AD_TB_DONE__=1;"
             "var TB=document.querySelectorAll('span,div,p,a,h1,h2,h3,h4,li');"
             "__ck('TB');"
             "var thits=[],tscan=0;"
             "for(var tb=0;tb<TB.length&&tb<2500&&((tb&15)||!ovr())&&thits.length<3;tb++){var te3=TB[tb];"
               "var own='';"
               "for(var cn5=0;cn5<te3.childNodes.length&&cn5<6;cn5++){"
                 "var nd5=te3.childNodes[cn5];"
                 "if(nd5.nodeType===3&&nd5.nodeValue&&nd5.nodeValue.trim().length>1)"
                   "own+=nd5.nodeValue.trim()+' ';}"
               "own=own.trim();"
               "if(own.length<2||own.length>60)continue;"
               "var trr=te3.getBoundingClientRect();"
               "if(trr.width<20||trr.height<8)continue;"
               "if(trr.top<0||trr.top>(window.innerHeight||900))continue;"
               "tscan++;"
               "var cx5=Math.round(trr.left+trr.width/2),cy5=Math.round(trr.top+trr.height/2);"
               "var stack=[];try{stack=document.elementsFromPoint(cx5,cy5)||[];}catch(e){}"
               "var found=null,layers='';"
               "for(var sk=0;sk<stack.length&&sk<6&&((sk&15)||!ovr());sk++){var se5=stack[sk];"
                 "var sbg=lum(getComputedStyle(se5).backgroundColor);"
                 "var scn=se5.className;if(scn&&scn.baseVal!==undefined)scn=scn.baseVal;"
                 "var srr=se5.getBoundingClientRect();"
                 "layers+=' '+String(scn||se5.tagName).slice(0,16)"
                   "+'@'+Math.round(srr.width)+'x'+Math.round(srr.height)"
                   "+'['+(sbg===null?'-':sbg.toFixed(2))"
                   "+(se5.__adBgBy?('/'+se5.__adBgBy):'')+']';"
                 "if(found===null&&se5!==te3&&sbg!==null&&sbg<0.30)found=sk;}"
               "if(found===null)continue;"
               "var tov=(typeof artOverlap==='function')?artOverlap(trr):0;"
               "thits.push('\\''+own.slice(0,20)+'\\' art='+tov.toFixed(2)+' ::'+layers);}"
             "window.__AD_TEXTBOX__=(thits.length?('n='+thits.length+' '+thits.join(' || ')):"
               "('none sampled='+tscan));"
           "}catch(e){window.__AD_TEXTBOX__='err '+e;}"
           // AD CARD AUDIT. Always reports. A dark box sitting on a light card is
           // the defect; this names the element and, via __adBgBy, the pass that
           // painted it -- so it stops being a guess about which pass to blame.
           // Same treatment: 2500 elements with a getComputedStyle each. Useful
           // once per page, ruinous every 1.2s.
           // RE-ARMED. I gated this to once per document in v5.177, which for an ad
           // card injected lazily means it ran long before the card existed -- so it
           // reported "clean" every time regardless. Up to 12 attempts across the
           // session, latching the moment it finds something so it stops paying.
           "try{if((window.__AD_AC_N__||0)>=12||window.__AD_AC_HIT__)throw 0;"
             "window.__AD_AC_N__=(window.__AD_AC_N__||0)+1;"
             "var AC=document.querySelectorAll('div,span,section,a,p');var hits=[],scanned=0;"
             "__ck('AC');"
             "for(var ac=0;ac<AC.length&&ac<2500&&((ac&15)||!ovr())&&hits.length<4;ac++){var ce2=AC[ac];"
               "var cl6=lum(getComputedStyle(ce2).backgroundColor);"
               "if(cl6===null||cl6>0.30)continue;"
               "var cr6=ce2.getBoundingClientRect();"
               "if(cr6.width<40||cr6.height<12||cr6.width>420)continue;"
               "scanned++;"
               "var lp=ce2.parentElement,lg=null,ld=0;"
               "while(lp&&ld++<4){var ll=lum(getComputedStyle(lp).backgroundColor);"
                 "if(ll!==null){lg=ll;break;}lp=lp.parentElement;}"
               // A creative's lightness is an IMAGE, so no ancestor reports a
               // light colour -- overlap with artwork is the real signal.
               "var ov5=(typeof artOverlap==='function')?artOverlap(cr6):0;"
               "if((lg===null||lg<=0.55)&&ov5<0.5)continue;"
               "var ccl=ce2.className;if(ccl&&ccl.baseVal!==undefined)ccl=ccl.baseVal;"
               "hits.push(ce2.tagName.toLowerCase()+'.'+String(ccl||'').slice(0,20)"
                 "+'@'+Math.round(cr6.width)+'x'+Math.round(cr6.height)"
                 "+'|bg='+cl6.toFixed(2)+'|par='+(lg===null?'none':lg.toFixed(2))"
                 "+'|art='+ov5.toFixed(2)"
                 "+'|by='+(ce2.__adBgBy||'-'));}"
             "if(hits.length)window.__AD_AC_HIT__=1;"
             "window.__AD_ADCARD__=(hits.length?('n='+hits.length+' '+hits.join(' ~ '))"
               ":('clean scanned='+scanned+' run='+window.__AD_AC_N__));"
           "}catch(e){window.__AD_ADCARD__='err '+e;}"
                      // BOX KILLER. A dark background anywhere between artwork and the light
           // card it sits on is a box we or Dark Reader painted under transparent
           // ink -- the pharmacy wordmark case. Immediate-parent checks miss it
           // because DR themes the whole container chain, so search UP for the
           // light surface and clear everything dark below it.
           "try{var BK0=document.querySelectorAll('img,svg,picture'),BK=[];"
             "for(var b0=0;b0<BK0.length&&b0<300;b0++)BK.push(BK0[b0]);"
             "var BKA=document.querySelectorAll('div,span,a,section');"
             "__ck('BKA');"
             "for(var b1=0;b1<BKA.length&&b1<1200&&((b1&15)||!ovr())&&BK.length<420;b1++){"
               "var ba=BKA[b1];var bgi2=getComputedStyle(ba).backgroundImage||'';"
               "if(bgi2.indexOf('url(')>=0)BK.push(ba);}"
             "var bkn=0,bkr='';"
             "for(var bk=0;bk<BK.length&&bk<420&&((bk&15)||!ovr());bk++){var bi=BK[bk];"
               "var br4=bi.getBoundingClientRect();"
               "if(br4.width<8||br4.height<8)continue;"
               "var lightAnc=null,an2=bi.parentElement,ad2=0;"
               "while(an2&&ad2++<8){var al2=lum(getComputedStyle(an2).backgroundColor);"
                 "if(al2!==null&&al2>0.5){lightAnc=an2;break;}"
                 "an2=an2.parentElement;}"
               "if(!lightAnc)continue;"
               "var bol=lum(getComputedStyle(bi).backgroundColor);"
               "if(bol!==null&&bol<0.30){bi.style.setProperty('background-color','transparent','important');bkn++;}"
               "var cn4=bi.parentElement,cd2=0;"
               "while(cn4&&cn4!==lightAnc&&cd2++<8){"
                 "var cl2=lum(getComputedStyle(cn4).backgroundColor);"
                 "if(cl2!==null&&cl2<0.30){"
                   "cn4.style.setProperty('background-color','transparent','important');bkn++;"
                   "if(!bkr){var kc2=cn4.className;if(kc2&&kc2.baseVal!==undefined)kc2=kc2.baseVal;"
                     "var kr2=cn4.getBoundingClientRect();"
                     "bkr=cn4.tagName.toLowerCase()+'.'+String(kc2||'').slice(0,22)"
                       "+'@'+Math.round(kr2.width)+'x'+Math.round(kr2.height);}}"
                 "cn4=cn4.parentElement;}}"
             "if(bkn&&!window.__AD_BOXKILL__)window.__AD_BOXKILL__='n='+bkn+' first='+bkr;"
           "}catch(e){}"
                      // BOX CLEARER. Small dark wrappers hugging the mlt/heart discs are our
           // own earlier paint (or anything else's); the disc supplies its own
           // background, so every tight ancestor goes transparent.
           "try{var MC=document.querySelectorAll('[class*=mlt-icon-container],[class*=lists-framework-action-button]');"
           "__ck('MC');"
             "for(var mq=0;mq<MC.length&&mq<80&&((mq&15)||!ovr());mq++){var me=MC[mq];"
               "var mp=me.parentElement,md=0;"
               "while(mp&&md++<3){var mr2=mp.getBoundingClientRect();"
                 "if(mr2.width<=64&&mr2.height<=64){"
                   "mp.style.setProperty('background-color','transparent','important');"
                   "mp.style.setProperty('box-shadow','none','important');}"
                 "mp=mp.parentElement;}}"
           "}catch(e){}"
                      // SCREW PROBE. Always reports. Anchors on the tile LABEL, so it does not
           // depend on finding the filter panel or on any class name.
           "try{var sp='no-label';"
             "var LB=document.querySelectorAll('span,div,p,label,a,li');"
             "__ck('LB');"
             "for(var sl=0;sl<LB.length;sl++){var le=LB[sl];"
               "if(le.children.length>2)continue;"
               "var lt=(le.textContent||'').trim();"
               "if(lt!=='Bugle'&&lt!=='Brad'&&lt!=='Button')continue;"
               "var host=null;"
               "try{host=le.closest('li,[class*=a-list-item],[class*=sbs-refinement]');}catch(e){}"
               "if(!host){host=le;var hd=0;"
                 "while(host.parentElement&&hd++<4){host=host.parentElement;"
                   "if(host.querySelector&&host.querySelector('img,svg'))break;}}"
               "var anc='',ap=le.parentElement,ad3=0;"
               "while(ap&&ad3++<5){var af=String(getComputedStyle(ap).filter||'none');"
                 "var acl2=ap.className;if(acl2&&acl2.baseVal!==undefined)acl2=acl2.baseVal;"
                 "anc+=' ^'+String(acl2||ap.tagName).slice(0,14)+'='+af.slice(0,18);"
                 "ap=ap.parentElement;}"
               "var arts=host.querySelectorAll('img,svg,i,span,div');var parts=[];"
               "for(var ai=0;ai<arts.length&&parts.length<4;ai++){var ae2=arts[ai];"
                 "var acs=getComputedStyle(ae2);"
                 "var isImg=(ae2.tagName.toLowerCase()==='img'||ae2.tagName.toLowerCase()==='svg');"
                 "var hasBg=((acs.backgroundImage||'').indexOf('url(')>=0);"
                 "if(!isImg&&!hasBg)continue;"
                 "var ar3=ae2.getBoundingClientRect();"
                 "if(ar3.width<8||ar3.height<8)continue;"
                 "var acn=ae2.className;if(acn&&acn.baseVal!==undefined)acn=acn.baseVal;"
                 "var pbg=ae2.parentElement?getComputedStyle(ae2.parentElement).backgroundColor:'-';"
                 "parts.push(ae2.tagName.toLowerCase()+'.'+String(acn||'').slice(0,18)"
                   "+'@'+Math.round(ar3.width)+'x'+Math.round(ar3.height)"
                   "+'|src='+(isImg?'tag':'bgimg')"
                   "+'|own='+acs.backgroundColor.replace(/ /g,'')"
                   "+'|par='+String(pbg).replace(/ /g,'')"
                   "+'|flt='+String(acs.filter||'none').slice(0,22)"
                   "+'|glyph='+(ae2.__adGlyph?1:0)"
                   "+'|by='+(ae2.__adBy||'-')"
                   "+'|blend='+String(acs.mixBlendMode||'-')"
                   "+'|op='+String(acs.opacity||'-')"
                   "+'|src='+String((ae2.currentSrc||ae2.src||'-')).slice(-26));}"
               "sp=lt+' host@'+Math.round(host.getBoundingClientRect().width)"
                 "+'x'+Math.round(host.getBoundingClientRect().height)"
                 "+' :: '+(parts.length?parts.join(' ~ '):'no-art')+' ANC'+anc;"
               "if(lt==='Bugle')break;}"
             "window.__AD_SCREW__=sp;"
           "}catch(e){window.__AD_SCREW__='err '+e;}"
                      // DARK-GLYPH AUDIT. Dark ink on a dark ground is invisible by
           // definition; anything listed here is a glyph a pass should have
           // whitened and did not.
           "try{var DG=document.querySelectorAll('img,svg,i,span,div');"
             "var dghits=[],dgseen=0;"
             "for(var dg=0;dg<DG.length&&dg<2000&&dghits.length<4;dg++){var ge=DG[dg];"
               "var gr=ge.getBoundingClientRect();"
               "if(gr.width<12||gr.width>52||gr.height<12||gr.height>52)continue;"
               "var gcs=getComputedStyle(ge);var gtag=ge.tagName.toLowerCase();"
               "var hasArt=(gtag==='img'||gtag==='svg')"
                 "||((gcs.backgroundImage||'').indexOf('url(')>=0)"
                 "||(((gcs.webkitMaskImage||gcs.maskImage||'none'))!=='none');"
               "if(!hasArt)continue;"
               "dgseen++;"
               "if(String(gcs.filter||'none').indexOf('invert')>=0)continue;"
               "if(ge.__adGlyph)continue;"
               // ground: nearest ancestor that paints a background
               "var gp=ge.parentElement,gl=null,gd=0;"
               "while(gp&&gd++<4){var v9=lum(getComputedStyle(gp).backgroundColor);"
                 "if(v9!==null){gl=v9;break;}gp=gp.parentElement;}"
               "if(gl===null||gl>0.30)continue;"
               "var ink=null;"
               "if(gtag==='svg')ink=lum(gcs.fill);"
               "if(ink===null)ink=lum(gcs.color);"
               "if(ink!==null&&ink>0.45)continue;"
               "var gcn=ge.className;if(gcn&&gcn.baseVal!==undefined)gcn=gcn.baseVal;"
               "dghits.push(gtag+'.'+String(gcn||'-').slice(0,20)"
                 "+'@'+Math.round(gr.width)+'x'+Math.round(gr.height)"
                 "+'|ink='+(ink===null?'-':ink.toFixed(2))"
                 "+'|ground='+gl.toFixed(2)"
                 "+'|src='+String((ge.currentSrc||ge.src||'-')).slice(-22));}"
             "window.__AD_DARKGLYPH__=(dghits.length?('n='+dghits.length+' '+dghits.join(' ~ ')):"
               "('clean art='+dgseen));"
           "}catch(e){window.__AD_DARKGLYPH__='err '+e;}"
                      // v5.391: the old root-size ACTION-BUTTON DISC is retired. Product
           // controls are skinned in-place by __AD_PRODUCTCTRL391RUN__ after the
           // page is positively identified as Search/PDP. No DOM disc is inserted.
                      // DARK ART ON A DARK TILE. Applies wherever it occurs, so no panel has
           // to be located first. The bugle screw is this shape: a monochrome
           // drawing sitting invisibly on the tile our theming darkened.
           "try{var TQ=document.querySelectorAll('img,svg,i,span,div');var tl=0,tfirst='';"
           "__ck('TQ');"
             "for(var tq=0;tq<TQ.length&&tq<2500&&((tq&15)||!ovr());tq++){var te=TQ[tq];"
               // Recycled node: if our ink was dropped by a re-render, treat it as
               // fresh rather than skipping it for the life of the page.
               "if(te.__adGlyph){try{"
                 "if(te.tagName.toLowerCase()!=='svg')continue;"
                 "var rfl=lum(getComputedStyle(te).fill);"
                 "if(rfl!==null&&rfl>=0.40)continue;"
               "}catch(e){continue;}}"
               "var tcs=getComputedStyle(te);var ttag=te.tagName.toLowerCase();"
               "var tArt=(ttag==='img'||ttag==='svg');"
               "if(!tArt){var tbi=tcs.backgroundImage||'';"
                 "if(tbi.indexOf('url(')<0)continue;"
                 "if(te.children.length>0)continue;"
                 "tArt=true;}"
               "var tr=te.getBoundingClientRect();"
               // Vector chrome may be large; a raster image may not. 48px is above
               // every known glyph family here (mlt 24, sbs-pill 34) and below
               // every avatar, brand logo and review photo seen so far.
               "var rasterCap=(ttag==='img')?48:140;"
               "if(tr.width<16||tr.width>rasterCap||tr.height<16||tr.height>rasterCap)continue;"
               "var ratio=tr.width/Math.max(tr.height,1);"
               "if(ratio<0.45||ratio>2.2)continue;"
               "var tcn=te.className;if(tcn&&tcn.baseVal!==undefined)tcn=tcn.baseVal;tcn=String(tcn||'');"
               // sbs-pill-image is the filter TILE icon, not a product photo --
               // confirmed by probe. Let it through SKIP for this pass only.
               "if(SKIP.test(tcn)&&!/sbs-pill-image/i.test(tcn))continue;"
               "if(te.closest&&te.closest('[class*=s-product-image],[class*=product-image],[class*=mlt-icon],[class*=heart],[class*=lists-framework]'))continue;"
               "var talt=(te.getAttribute&&te.getAttribute('alt'))||'';"
               "if(talt.length>18)continue;"
               "if(String(tcs.filter||'').indexOf('invert')>=0)continue;"
               // the tile: a dark, icon-sized box the drawing nearly fills
               "var tile=null;"
               "var selfL=lum(tcs.backgroundColor);"
               "if(selfL!==null&&selfL<0.30)tile=te;"
               "var tp=te.parentElement,tdep=0;"
               "while(!tile&&tp&&tdep++<5){var tpl=lum(getComputedStyle(tp).backgroundColor);"
                 "var tpr=tp.getBoundingClientRect();"
                 "if(tpl!==null&&tpl<0.32"
                   "&&tpr.width>=tr.width-2&&tpr.height>=tr.height-2){tile=tp;break;}"
                 "tp=tp.parentElement;}"
               "if(!tile)continue;"
               "if(artChk(te))continue;"
               "te.__adGlyph=1;te.__adBy='tileart';tl++;"
               // Vector glyph: read its ink and lift it directly.
               "if(ttag==='svg'){try{"
                 "var fl4=lum(tcs.fill),sl4=lum(tcs.stroke),cl5=lum(tcs.color);"
                 "var ink=(fl4!==null?fl4:(sl4!==null?sl4:cl5));"
                 "if((ink===null||ink<0.40)&&!onArt(te)){"
                   "te.style.setProperty('color','#e8e6e3','important');"
                   "if(fl4===null||fl4<0.40)te.style.setProperty('fill','#e8e6e3','important');"
                   "if(sl4!==null&&sl4<0.40)te.style.setProperty('stroke','#e8e6e3','important');"
                   "var kids=te.querySelectorAll('path,circle,rect,polygon,g,line');"
                   "for(var kk=0;kk<kids.length&&kk<12&&((kk&15)||!ovr());kk++){"
                     "var kf=lum(getComputedStyle(kids[kk]).fill);"
                     "if(kf===null||kf<0.40)kids[kk].style.setProperty('fill','#e8e6e3','important');}"
                   "if(!window.__AD_SVGINK__)window.__AD_SVGINK__='lifted ink='+(ink===null?'none':ink.toFixed(2));}"
                 "else if(!window.__AD_SVGINK__)window.__AD_SVGINK__='left ink='+ink.toFixed(2);"
               "}catch(e){}continue;}"
               "(function(el5){try{"
                 // NEVER invert unmeasured. This inverted any non-<img> candidate
                 // outright, with no luminance test at all -- so on a still-loading
                 // document the tile heuristic matched containers whose art had not
                 // arrived and flipped every one on sight. That is the inverted
                 // loading screen. A CSS-background icon now goes through the same
                 // canvas measurement as an <img>; anything unmeasurable is left be.
                 "var srcu=null;"
                 "if(el5.tagName.toLowerCase()==='img'){srcu=el5.currentSrc||el5.src;}"
                 "else{var bgi9=String(getComputedStyle(el5).backgroundImage||'');"
                   "var i1=bgi9.indexOf('url(');"
                   "if(i1>=0){var s1=bgi9.slice(i1+4);var i2=s1.indexOf(')');"
                     "if(i2>0)srcu=s1.slice(0,i2).replace(/^[\\s'\\u0022]+|[\\s'\\u0022]+$/g,'');}}"
                 "if(!srcu){if(!window.__AD_TILEMEAS__)window.__AD_TILEMEAS__='no-src-skipped';return;}"
                 // CACHE BY SOURCE URL. Amazon serves these icons from a handful of
                 // shared sprite sheets, so without this the SAME asset was fetched,
                 // decoded, drawn to canvas and pixel-scanned once per element --
                 // hundreds of times per page and again on every re-render. That is
                 // the jank: repeated main-thread decode + getImageData for an answer
                 // that depends only on the URL.
                 "if(!window.__ADTMC__)window.__ADTMC__={};"
                 "var cv9=window.__ADTMC__[srcu];"
                 "if(cv9!==undefined){"
                   "if(cv9===1){el5.style.setProperty('filter','invert(1)','important');"
                     "el5.style.setProperty('background-color','transparent','important');el5.__adBy='tilecache';}"
                   "return;}"
                 // Hard ceiling per document. Past this we leave icons alone rather
                 // than keep paying -- a slightly under-themed glyph beats an
                 // unresponsive app.
                 "window.__ADTMN__=(window.__ADTMN__||0)+1;"
                 "if(window.__ADTMN__>400){"
                   "if(!window.__AD_TILEMEAS__)window.__AD_TILEMEAS__='budget-hit';return;}"
                 "var pr6=new Image();pr6.crossOrigin='anonymous';"
                 "pr6.onload=function(){try{"
                   "var cw=Math.min(pr6.naturalWidth||32,32),ch=Math.min(pr6.naturalHeight||32,32);"
                   "if(!cw||!ch)return;"
                   "var cv=document.createElement('canvas');cv.width=cw;cv.height=ch;"
                   "var cx=cv.getContext('2d');cx.drawImage(pr6,0,0,cw,ch);"
                   "var dd=cx.getImageData(0,0,cw,ch).data,sum=0,cnt=0,lite=0,sat=0;"
                   "for(var z=0;z<dd.length;z+=4){if(dd[z+3]<40)continue;"
                     "var lz=0.2126*dd[z]+0.7152*dd[z+1]+0.0722*dd[z+2];"
                     "sum+=lz;cnt++;if(lz>153)lite++;"
                     // channel spread: neutral ink sits near zero, brand colour does not
                     "var mx=dd[z]>dd[z+1]?dd[z]:dd[z+1];if(dd[z+2]>mx)mx=dd[z+2];"
                     "var mn=dd[z]<dd[z+1]?dd[z]:dd[z+1];if(dd[z+2]<mn)mn=dd[z+2];"
                     "sat+=(mx-mn);}"
                   "if(!cnt)return;var avg=(sum/cnt)/255;var lf=lite/cnt;"
                   "var sf=((sat/cnt)/255);"
                   // Any real light content means the sprite already reads on a
                   // dark tile; inverting it would flip it against its peers.
                   // COLOUR IS NEVER SILHOUETTED. invert(1) discards the hue as surely
                   // as a template tint does, so this is the same invariant the native
                   // path enforces -- and this pass had no colour term at all. It is
                   // what turns an orange star rating into a solid white block: the
                   // sprite measures dark enough to look like ink, so it gets flipped,
                   // taking the orange and the partial fill with it. RATSCAN showed
                   // only 9 native image views on the whole feed, so these ratings are
                   // web content and this is the pass that reaches them.
                   "window.__ADTMC__[srcu]=(avg<0.28&&lf<0.03&&sf<0.10)?1:0;"
                   "if(avg<0.28&&lf<0.03&&sf<0.10){"
                     "el5.style.setProperty('filter','invert(1)','important');"
                     "el5.style.setProperty('background-color','transparent','important');"
                     "el5.__adBy='tileart';"
                     "if(!window.__AD_TILEMEAS__)window.__AD_TILEMEAS__="
                       "'inverted avg='+avg.toFixed(2)+' light='+lf.toFixed(2);}"
                   "else if(!window.__AD_TILEMEAS__)window.__AD_TILEMEAS__="
                     "'left avg='+avg.toFixed(2)+' light='+lf.toFixed(2);"
                 "}catch(e){if(!window.__AD_TILEMEAS__)window.__AD_TILEMEAS__='tainted';}};"
                 "pr6.onerror=function(){window.__ADTMC__[srcu]=0;"
               "if(!window.__AD_TILEMEAS__)window.__AD_TILEMEAS__='cors-fail';};"
                 "pr6.src=srcu;"
               "}catch(e){}})(te);"
               "if(!tfirst)tfirst=ttag+'.'+tcn.slice(0,20)"
                 "+'@'+Math.round(tr.width)+'x'+Math.round(tr.height);}"
             "window.__AD_TILEART__='n='+tl+(tfirst?(' first='+tfirst):'')"
               "+(window.__AD_SVGINK__?(' svg='+window.__AD_SVGINK__):'')"
               "+(window.__AD_TILEMEAS__?(' meas='+window.__AD_TILEMEAS__):'');"
           "}catch(e){}"
                      // FILTER PANEL BY HEADING. The tile container uses hashed class names
           // (no filter/refinement/facet), so anchor on the visible "Filters for"
           // heading instead, walk up to the section, and whiten every monochrome
           // pictogram inside. SKIP still protects photo pills. The audit reports
           // up to three refused candidates -- the old version stopped on the
           // FIRST candidate, which was a correctly-skipped product pill, and
           // masked the real miss.
           "try{var fhead=null;"
             "var HD=document.querySelectorAll('h1,h2,h3,h4,span,div,p');"
             "__ck('HD');"
             "var cand=[];"
             "for(var hh=0;hh<HD.length;hh++){var he2=HD[hh];"
               "if(he2.children.length>3)continue;"
               "var ht2=(he2.textContent||'').trim();"
               "if(ht2.length<5||ht2.length>80)continue;"
               "if(ht2.toLowerCase().indexOf('filter')<0)continue;"
               "var hr2=he2.getBoundingClientRect();"
               "if(hr2.width<60||hr2.height<10||hr2.height>90)continue;"
               "if(cand.length<3)cand.push(ht2.slice(0,26)+'@'+Math.round(hr2.width)+'x'+Math.round(hr2.height));"
               "if(!fhead)fhead=he2;}"
             "if(!fhead&&!window.__AD_FLTSCAN__){var hasf=0;"
               "try{hasf=((document.body.innerText||'').indexOf('Filters')>=0)?1:0;}catch(e){}"
               "window.__AD_FLTSCAN__='nohead n='+HD.length+' has='+hasf"
                 "+' cands='+(cand.length?cand.join('|'):'0');}"
             "if(fhead){var fsec=fhead,fu=0,vw2=window.innerWidth||390,fcur=fhead,fbest=null;"
               "while(fcur.parentElement&&fu++<10){fcur=fcur.parentElement;"
                 "var fsr=fcur.getBoundingClientRect();"
                 "if(fsr.width>=vw2*0.80&&fsr.height>=200)fbest=fcur;}"
               "fsec=fbest||fhead.parentElement||fhead;"
               "var fels=fsec.querySelectorAll('img,svg,i,span,div');"
               "var fmiss=[];"
               "for(var fz=0;fz<fels.length&&fz<400&&((fz&15)||!ovr());fz++){var fe2=fels[fz];"
                 "var fr3=fe2.getBoundingClientRect();"
                 "if(fr3.width<10||fr3.width>130||fr3.height<10||fr3.height>130)continue;"
                 "var fc2=fe2.className;if(fc2&&fc2.baseVal!==undefined)fc2=fc2.baseVal;fc2=String(fc2||'');"
                 "if(SKIP.test(fc2))continue;"
                 "var ftg=fe2.tagName.toLowerCase();"
                 "var fcs2=getComputedStyle(fe2);"
                 "var fart=(ftg==='img')||(ftg==='svg')"
                   "||(fcs2.backgroundImage&&fcs2.backgroundImage.indexOf('url(')>=0)"
                   "||((fcs2.webkitMaskImage||fcs2.maskImage||'none')!=='none');"
                 "if(!fart)continue;"
                 "if(String(fcs2.filter||'').indexOf('invert')>=0)continue;"
                 // GUARD FIRST. This sat BELOW both writes: a product photo was
                 // silhouetted and only then asked whether it was a product photo.
                 // Its continue also skipped the marking line below, which is why
                 // these images logged as glyph=0 by=- and no audit ever saw them.
                 "if(artChk(fe2))continue;"
                 "if(ftg==='svg'){fe2.style.setProperty('fill','#ffffff','important');"
                   "fe2.style.setProperty('stroke','#ffffff','important');continue;}"
                 "fe2.style.setProperty('filter','brightness(0) invert(1)','important');"
                 "fe2.style.setProperty('background-color','transparent','important');"
               "fe2.__adGlyph=1;fe2.__adBy='fltpanel';"
                 "if(fmiss.length<3)fmiss.push(ftg+'.'+fc2.slice(0,22)+'@'+Math.round(fr3.width)+'x'+Math.round(fr3.height));}"
               "if(!window.__AD_FLTSCAN__)window.__AD_FLTSCAN__="
                 "(fmiss.length?('lit: '+fmiss.join(' ')):('sec@'+Math.round(fsec.getBoundingClientRect().width)"
                   "+'x'+Math.round(fsec.getBoundingClientRect().height)+' none-lit'));"
             "}"
           "}catch(e){}"
                      // v5.378: legacy geometry-based compare painters disabled. They could not
           // distinguish Amazon's stock Compare checkbox from heart/list controls and were
           // responsible for stacked circles and duplicated/squashed glyphs. Stock artwork only.
           "try{window.__AD_CMPSCAN__='stock378';window.__AD_CMPFIX__='stock378';}catch(e){}"
                      // v5.357: HOME CARD BORDER + COLLEGE CHEVRON REPAIR.
           // Device evidence from 5.356 gives us two hard facts:
           //   (1) the rows we already mark are truly fixed (#3b4043 inline), while
           //       the remaining bad cards are simply outside the named-section walk;
           //   (2) P21 is still n=0, so the arrow painter is outside sec54's subtree.
           // Keep the proven section repair, then add two evidence-based fallbacks:
           // normalize only the exact Dark-Reader brown border seen on-device, anywhere
           // on a large rounded DIV/LI/SECTION/ARTICLE; and discover carousel arrows
           // from their own Next/Previous accessibility label rather than ancestry.
           "try{var H54=document.querySelectorAll('h1,h2,h3,h4,span,div'),S54=[],SN54=[],CH57=null;"
             "__ck('SEC57');"
             "function n54(x){return String(x||'').replace(/\\s+/g,' ').trim().toLowerCase();}"
             "function sec54(h){var p=h.parentElement,u=0;while(p&&u++<10){var r=p.getBoundingClientRect();if(r.width>=300&&r.height>=130&&r.height<=1100)return p;p=p.parentElement;}return null;}"
             "for(var h54=0;h54<H54.length&&h54<3000;h54++){var hh54=H54[h54];if(hh54.children&&hh54.children.length>5)continue;var tx54=n54(hh54.textContent),nm54='';"
               "if(tx54==='off to college'){nm54='college';if(!CH57)CH57=hh54;}else if(tx54==='deals for you')nm54='deals';else if(tx54==='you might like')nm54='might';else if(tx54.indexOf('recommended')===0&&tx54.indexOf('for you')>=0)nm54='recommended';else if(tx54.indexOf('keep shopping')===0)nm54='keep';else if(tx54.indexOf('continue browsing')===0)nm54='continue';else continue;"
               "var ss54=sec54(hh54);if(!ss54)continue;if(nm54==='college')ss54.setAttribute('data-ad-college-section','1');if(S54.indexOf(ss54)<0){S54.push(ss54);SN54.push(nm54);}}"
             "var SD54=['Top','Right','Bottom','Left'];"
             "for(var s54=0;s54<S54.length&&s54<12;s54++){var se54=S54[s54],q54=se54.querySelectorAll('*');"
               "for(var b54=-1;b54<q54.length&&b54<1200;b54++){var be54=(b54<0?se54:q54[b54]),br54=be54.getBoundingClientRect();if(br54.width<110||br54.height<55)continue;"
                 "var tg54=String(be54.tagName||'').toUpperCase();if(tg54==='BUTTON'||tg54==='INPUT'||tg54==='SELECT'||tg54==='TEXTAREA')continue;"
                 "var bc54=getComputedStyle(be54),rad54=Math.max(parseFloat(bc54.borderTopLeftRadius)||0,parseFloat(bc54.borderTopRightRadius)||0,parseFloat(bc54.borderBottomLeftRadius)||0,parseFloat(bc54.borderBottomRightRadius)||0);if(rad54<4)continue;"
                 "var painted54=0,outline54=0;for(var sd54=0;sd54<4;sd54++){var side54=SD54[sd54],bw54=parseFloat(bc54['border'+side54+'Width'])||0,bs54=String(bc54['border'+side54+'Style']||'');if(bw54>=0.5&&bs54!=='none'&&bs54!=='hidden'){painted54=1;break;}}"
                 "var ow54=parseFloat(bc54.outlineWidth)||0,os54=String(bc54.outlineStyle||'');if(ow54>=0.5&&os54!=='none'&&os54!=='hidden')outline54=1;if(!painted54&&!outline54)continue;"
                 "be54.setAttribute('data-ad-cardborder','1');be54.setAttribute('data-ad-border-section',SN54[s54]);"
                 "if(artChk(be54)&&/^(IMG|PICTURE|VIDEO|CANVAS|SVG)$/.test(tg54))continue;"
                 "if(painted54){be54.style.setProperty('border-color','#3b4043','important');be54.__adBy='cardborder57s';}"
                 "if(outline54){if(artChk(be54)&&/^(IMG|PICTURE|VIDEO|CANVAS|SVG)$/.test(tg54))continue;be54.style.setProperty('outline-color','#3b4043','important');be54.__adBy='cardborder57s';}"
               "}"
             "}"
             // Global brown-border fallback. This does NOT guess card classes: it only
             // changes the exact #544e45-ish border family measured in every failed
             // device probe, on card-sized rounded container tags.
             "function rgb57(v){var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)/.exec(String(v||''));return m?[+m[1],+m[2],+m[3]]:null;}"
             "function br57(v){var c=rgb57(v);return !!(c&&Math.abs(c[0]-84)<=7&&Math.abs(c[1]-78)<=7&&Math.abs(c[2]-69)<=7);}"
             "var GB57=document.querySelectorAll('li,div,section,article');"
             "for(var g57=0;g57<GB57.length&&g57<6000;g57++){var ge57=GB57[g57],gr57=ge57.getBoundingClientRect();if(gr57.width<110||gr57.height<55)continue;"
               "var gs57=getComputedStyle(ge57),gd57=0,go57=0,rr57=Math.max(parseFloat(gs57.borderTopLeftRadius)||0,parseFloat(gs57.borderTopRightRadius)||0,parseFloat(gs57.borderBottomLeftRadius)||0,parseFloat(gs57.borderBottomRightRadius)||0);if(rr57<4)continue;"
               "for(var d57=0;d57<4;d57++){var sd57=SD54[d57],gw57=parseFloat(gs57['border'+sd57+'Width'])||0,gst57=String(gs57['border'+sd57+'Style']||'');if(gw57>=0.5&&gst57!=='none'&&gst57!=='hidden'&&br57(gs57['border'+sd57+'Color'])){gd57=1;break;}}"
               "var gow57=parseFloat(gs57.outlineWidth)||0,gost57=String(gs57.outlineStyle||'');if(gow57>=0.5&&gost57!=='none'&&gost57!=='hidden'&&br57(gs57.outlineColor))go57=1;if(!gd57&&!go57)continue;"
               "ge57.setAttribute('data-ad-cardborder','1');ge57.setAttribute('data-ad-border-section','global-brown');"
               "if(gd57){ge57.style.setProperty('border-color','#3b4043','important');ge57.__adBy='cardborder57g';}"
               "if(go57){ge57.style.setProperty('outline-color','#3b4043','important');ge57.__adBy='cardborder57g';}"
             "}"
             // Carousel arrows: search the accessibility labels themselves globally.
             // 5.356 proved the College painter is not a descendant of sec54, so section
             // ancestry is no longer used as the primary selector. Marking is enough;
             // the documentStart CSS above owns the actual paint and therefore does not
             // introduce another runtime filter writer for the JS regression gate.
             "function cl57(e){var c=e&&e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||''));}"
             "function pp57(e){try{if(!e)return false;var s=getComputedStyle(e),b=getComputedStyle(e,'::before'),a=getComputedStyle(e,'::after'),c=cl57(e);return /icon|arrow|chevron|caret/i.test(c)||(s.backgroundImage&&s.backgroundImage!=='none')||((s.webkitMaskImage||s.maskImage||'none')!=='none')||(b&&((b.backgroundImage&&b.backgroundImage!=='none')||((b.webkitMaskImage||b.maskImage||'none')!=='none')))||(a&&((a.backgroundImage&&a.backgroundImage!=='none')||((a.webkitMaskImage||a.maskImage||'none')!=='none')));}catch(_){return false;}}"
             "function mk57(e,lab){if(!e)return;var x=e,j=0;while(x&&j++<4){var xr=x.getBoundingClientRect(),xc=cl57(x);if(xr.width>=4&&xr.width<=100&&xr.height>=4&&xr.height<=100&&!/star|prime|logo|flag|swatch|thumb|heart|wish|rating|checkbox|toggle|product|photo/i.test(xc)&&pp57(x)){x.setAttribute('data-ad-nav-chevron-paint','1');x.setAttribute('data-ad-nav-label',String(lab||'').slice(0,32));x.__adGlyph=1;x.__adBy='collegeNav57';}x=x.parentElement;}}"
             "var NV57=document.querySelectorAll('.a-icon-alt,[aria-label],[title]');"
             "for(var nv57=0;nv57<NV57.length&&nv57<3000;nv57++){var ne57=NV57[nv57],lab57=n54((ne57.matches&&ne57.matches('.a-icon-alt')?ne57.textContent:'')||ne57.getAttribute('aria-label')||ne57.getAttribute('title'));if(!/^(next|previous)(?:\\b|\\s|$)/i.test(lab57))continue;mk57(ne57,lab57);var nd57=ne57.querySelectorAll&&ne57.querySelectorAll('.a-icon,i,svg,[class*=arrow],[class*=chevron]');if(nd57)for(var nj57=0;nj57<nd57.length&&nj57<8;nj57++)mk57(nd57[nj57],lab57);}"
             // Fallback tied directly to the old P9VIS evidence: a visible dark
             // a-icon-alt inside the vertical band of the Off-to-College row.
             "if(CH57){var chR57=CH57.getBoundingClientRect(),AA57=document.querySelectorAll('.a-icon-alt');for(var aa57=0;aa57<AA57.length&&aa57<1200;aa57++){var ae57=AA57[aa57],ar57=ae57.getBoundingClientRect(),dy57=ar57.top-chR57.top;if(dy57<-40||dy57>650||ar57.width<6||ar57.width>100||ar57.height<5||ar57.height>100)continue;var ap57=ae57.parentElement,ac57=cl57(ap57);if(/star|prime|logo|heart|wish|rating|badge/i.test(ac57))continue;var as57=getComputedStyle(ae57),cc57=rgb57(as57.color);if(cc57&&(0.2126*cc57[0]+0.7152*cc57[1]+0.0722*cc57[2])<120){mk57(ae57,'college-low-ink');mk57(ap57,'college-low-ink');}}}"
           "}catch(e){}"
           // v5.358: P21 stayed n=0 through 5.357 even though the College row
           // itself is positively located. Target the actual visual edge zone below
           // "Off to College" instead of assuming Amazon's standard carousel DOM.
           // Only small arrow-like/clickable painters at the left/right edges in that
           // narrow vertical band are marked. Static CSS handles sprite, SVG, border
           // and pseudo-element arrow implementations without touching product art.
           "try{var HH58=document.querySelectorAll('h1,h2,h3,h4,span,div'),H58=null;"
             "for(var hi58=0;hi58<HH58.length&&hi58<3500;hi58++){var ht58=String(HH58[hi58].textContent||'').replace(/\\s+/g,' ').trim().toLowerCase();if(ht58==='off to college'){H58=HH58[hi58];break;}}"
             "if(H58){var hr58=H58.getBoundingClientRect(),vw58=window.innerWidth||390,y058=hr58.bottom-18,y158=hr58.bottom+120;"
               "function cc58(e){var c=e&&e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||''));}"
               "function dark58(v){var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)/.exec(String(v||''));return !!(m&&(0.2126*+m[1]+0.7152*+m[2]+0.0722*+m[3])<150);}"
               "function bp58(s){if(!s)return false;var S=['Top','Right','Bottom','Left'];for(var z58=0;z58<4;z58++){var q58=S[z58],w58=parseFloat(s['border'+q58+'Width'])||0;if(w58>=1&&w58<=8&&dark58(s['border'+q58+'Color']))return true;}return false;}"
               "function mark58(e,why){if(!e||!e.setAttribute)return;var r=e.getBoundingClientRect();if(r.width<3||r.width>96||r.height<3||r.height>96)return;e.setAttribute('data-ad-college-chevron','1');if(e.__adBy!=='collegeFast59')e.setAttribute('data-ad-college-chevron-why',why);e.__adGlyph=1;if(e.__adBy!=='collegeFast59')e.__adBy='collegeEdge58';var s=getComputedStyle(e),b=getComputedStyle(e,'::before'),a=getComputedStyle(e,'::after'),tg=String(e.tagName||'').toUpperCase();if(tg==='SVG'||tg==='PATH'||tg==='I'||String(s.backgroundImage||'none')!=='none'||String(s.webkitMaskImage||s.maskImage||'none')!=='none'||(b&&String(b.backgroundImage||'none')!=='none')||(a&&String(a.backgroundImage||'none')!=='none'))e.setAttribute('data-ad-college-chevron-sprite','1');}"
               "var E58=document.querySelectorAll('a,button,i,span,div,svg,path');"
               "for(var ei58=0;ei58<E58.length&&ei58<7000;ei58++){var e58=E58[ei58],r58=e58.getBoundingClientRect(),cx58=r58.left+r58.width/2,cy58=r58.top+r58.height/2;if(r58.width<3||r58.width>96||r58.height<3||r58.height>96||cy58<y058||cy58>y158||(cx58>100&&cx58<vw58-100))continue;var tg58=String(e58.tagName||'').toUpperCase();if(/^(IMG|PICTURE|VIDEO|CANVAS)$/.test(tg58))continue;var c58=cc58(e58),al58=String(e58.getAttribute&&((e58.getAttribute('aria-label')||'')+' '+(e58.getAttribute('title')||''))||''),s58=getComputedStyle(e58),b58=getComputedStyle(e58,'::before'),a58=getComputedStyle(e58,'::after');var hint58=/arrow|chev|next|prev|carousel|nav/i.test(c58+' '+al58)||tg58==='SVG'||tg58==='PATH'||tg58==='I'||String(s58.backgroundImage||'none')!=='none'||String(s58.webkitMaskImage||s58.maskImage||'none')!=='none'||bp58(s58)||bp58(b58)||bp58(a58)||((tg58==='A'||tg58==='BUTTON')&&String(s58.cursor||'')==='pointer');if(!hint58)continue;mark58(e58,'edge');var K58=e58.querySelectorAll&&e58.querySelectorAll('i,span,svg,path,[class*=icon],[class*=arrow],[class*=chev]');if(K58)for(var ki58=0;ki58<K58.length&&ki58<16;ki58++)mark58(K58[ki58],'child');}"
             "}"
           "}catch(e){}"
           "try{var AIC=document.querySelectorAll('[class*=a-icon]');"
                      "__ck('AIC');"
             "for(var ai=0;ai<AIC.length&&ai<500&&((ai&15)||!ovr());ai++){var ae=AIC[ai];"
               "var acn=ae.className;if(acn&&acn.baseVal!==undefined)acn=acn.baseVal;acn=String(acn||'');"
               "if(/star|prime|logo|flag|swatch|thumb|sponsor|product|photo|-alt|toggle|switch|checkbox|heart|wish|lists-framework|copilot-compare/i.test(acn))continue;"
               "var acs=getComputedStyle(ae),abf=getComputedStyle(ae,'::before'),aba=getComputedStyle(ae,'::after');"
               "var abi=acs.backgroundImage||acs.webkitMaskImage||acs.maskImage"
                 "||abf.backgroundImage||abf.webkitMaskImage||abf.maskImage"
                 "||aba.backgroundImage||aba.webkitMaskImage||aba.maskImage;"
               "if(!abi||abi==='none'||abi.indexOf('url(')<0)continue;"
               "if(ae.closest&&ae.closest('[class*=heart],[class*=wish],[class*=lists-framework],[class*=copilot-compare]'))continue;"
               "var ar=ae.getBoundingClientRect();"
               "if(ar.width>5&&ar.width<=60&&ar.height>5&&ar.height<=60){"
                 "if(artChk(ae))continue;"
               "ae.style.setProperty('filter','brightness(0) invert(1)','important');ae.__adGlyph=1;ae.__adBy='aic';}}"
           "}catch(e){}"
           "try{var CDU=document.querySelectorAll('[class*=cardui],[class*=Cardui]');"
           "__ck('CDU');"
             "for(var di=0;di<CDU.length&&di<20&&((di&15)||!ovr());di++){var card=CDU[di];"
               "var cr=card.getBoundingClientRect();if(cr.width<120||cr.height<80)continue;"
               "var bc9=bgOf(card);if(bc9===null||bc9<0.4)continue;"
               "var kids=card.querySelectorAll('*');"
               "for(var ki=0;ki<kids.length&&ki<250&&((ki&15)||!ovr());ki++){var kd=kids[ki];"
                 "var kbl=lum(getComputedStyle(kd).backgroundColor);"
                 "if(kbl===null||kbl>=0.25)continue;"
                 "var kr=kd.getBoundingClientRect();"
                 "if(kr.width>=cr.width*0.96&&kr.height>=cr.height*0.96)continue;"
                 "kd.style.setProperty('background-color','transparent','important');}}"
           "}catch(e){}"
           "try{var PRM=document.querySelectorAll('[class*=sub-header-title-font]');"
           "__ck('PRM');"
             // v5.289: THIS is the ad-card text flip. The sweep forced EVERY
               // sub-header title to #0f1111 inline -- inline beats any stylesheet,
               // which is why removing the CSS rule in v5.287 changed nothing -- and
               // it runs inside FIXCONTRAST, i.e. on the trailing run ~450ms after
               // scrolling stops. That is exactly the reported behaviour: bad state
               // holds while scrolling, colour changes the moment you settle.
               //
               // It also stripped dark backgrounds off five ancestors, which erased
               // an ad card's own backdrop. Now: leave ad/themed cards alone entirely,
               // and elsewhere only darken the title when the background is genuinely
               // light -- measured, not assumed.
             "for(var pi=0;pi<PRM.length&&pi<40&&((pi&15)||!ovr());pi++){var pt=PRM[pi];"
               "if(inAd(pt))continue;"
               "var ptBg=bgOf(pt);"
               "if(ptBg===null||ptBg<0.55)continue;"
               "pt.style.setProperty('color','#0f1111','important');"
               "pt.style.setProperty('-webkit-text-fill-color','#0f1111','important');"
               // clear dark background boxes on the header ancestors
               "var pa=pt,pd=0;"
               "while(pa&&pd++<5){if(inAd(pa))break;"
                 "var pac=getComputedStyle(pa),pal=lum(pac.backgroundColor);"
                 "if(pal!==null&&pal<0.3)pa.style.setProperty('background-color','transparent','important');"
                 "pa=pa.parentElement;}}"
           "}catch(e){}"
           "try{var WG=function(root){if(!root||!root.querySelectorAll)return;"
               "var gl=root.querySelectorAll('*');"
               "for(var wi=0;wi<gl.length&&wi<90&&((wi&15)||!ovr());wi++){var g=gl[wi];"
                 "var gr=g.getBoundingClientRect();"
                 "if(gr.width<4||gr.width>40||gr.height<4||gr.height>40)continue;"
                 "var gsty=getComputedStyle(g),gtg=(g.tagName||'').toLowerCase();"
                 "if(g.namespaceURI==='http://www.w3.org/2000/svg'){"
                   "g.style.setProperty('fill',FG,'important');"
                   "g.style.setProperty('stroke',FG,'important');continue;}"
                 "var gbi=gsty.backgroundImage,gmi=gsty.webkitMaskImage||gsty.maskImage;"
                 "var gbf=getComputedStyle(g,'::before'),gaf=getComputedStyle(g,'::after');"
                 "var sprite=(gbi&&gbi.indexOf('url(')>=0)"
                   "||(gbf.backgroundImage&&gbf.backgroundImage.indexOf('url(')>=0)"
                   "||(gaf.backgroundImage&&gaf.backgroundImage.indexOf('url(')>=0);"
                 "var mask=(gmi&&gmi!=='none')"
                   "||(gbf.webkitMaskImage&&gbf.webkitMaskImage!=='none')"
                   "||(gbf.maskImage&&gbf.maskImage!=='none');"
                 "if(gtg==='img'||sprite){"
                   "if(artChk(g))continue;"
                   "g.style.setProperty('filter','brightness(0) invert(1)','important');"
                   "g.__adGlyph=1;g.__adBy='gsweep';continue;}"
                 "if(mask){g.style.setProperty('background-color',FG,'important');continue;}"
                 "var pc=(gbf.content&&gbf.content!=='none'&&gbf.content!=='normal')"
                   "||(gaf.content&&gaf.content!=='none'&&gaf.content!=='normal');"
                 "var wtx=false;for(var wz=0;wz<g.childNodes.length;wz++){var wn=g.childNodes[wz];"
                   "if(wn.nodeType===3&&wn.nodeValue&&wn.nodeValue.trim()){wtx=true;break;}}"
                 "if(pc){var pcl=lum(gsty.color);"
                   "if(pcl!==null&&pcl<0.6&&!onArt(g))g.style.setProperty('color',FG,'important');continue;}"
                 "if(!g.children.length&&!wtx&&gr.width<=14&&gr.height<=14){"
                   "var dbl=lum(gsty.backgroundColor);"
                   "if(dbl!==null&&dbl<0.5){g.style.setProperty('background-color',FG,'important');continue;}}}"
             "};"
             "var WGT=document.querySelectorAll("
               "'[class*=sc-nested-actions]');"
             "for(var wti=0;wti<WGT.length&&wti<40&&((wti&15)||!ovr());wti++)WG(WGT[wti]);"
           "}catch(e){}"

           // One-shot probe. Two builds have now been spent inferring what paints
           // these glyphs from what does NOT move. Cheaper to just ask the DOM: report
           // the first few icon-sized elements and which mechanism draws each, so the
           // next change targets a known selector instead of a guess.
           // The one-shot flag was the bug: __AMZDARK_APPLY__ calls this once at
           // bootstrap and DISCARDS the result, so the probe was always spent before
           // the first logged invocation. Compute once, cache, return every time.
           // Caching fixed the "consumed at bootstrap" bug but introduced its twin:
           // the bootstrap call runs against a near-empty DOM, found nothing, and
           // cached THAT. Hence probe=none while gfix was busy matching elements.
           // Only cache a result that actually found something; keep retrying until
           // one does.
           // NO CACHE. Cached-once has now been wrong twice: spent on the bootstrap
           // DOM, then locked to an early snapshot holding only the filter icon while
           // the product cards had not rendered. Recompute every call -- it is two
           // bounded scans behind a 400ms debounce -- so the log always describes the
           // DOM as it stands right now.
           "var pr='';try{{"
             "var seen={},acc=[];"
             "for(var q=0;q<els.length&&acc.length<14;q++){var pe=els[q];"
               "var rc=pe.getBoundingClientRect();"
               "if(rc.width<6||rc.width>40||rc.height<6||rc.height>40)continue;"
               "if(pe.children.length>2)continue;"
               "var pcs=getComputedStyle(pe),tg=pe.tagName.toLowerCase(),kind='';"
               "var pbi=pcs.backgroundImage,pmi=pcs.webkitMaskImage||pcs.maskImage;"
               "var ppb=getComputedStyle(pe,'::before');"
               "if(tg==='img')kind='img';"
               "else if(pmi&&pmi!=='none')kind='mask';"
               "else if(pbi&&pbi!=='none')kind='bgimg';"
               "else if(hasC(ppb))kind='pseudo';"
               "else if(pe.namespaceURI==='http://www.w3.org/2000/svg')kind='svg';"
               "else continue;"
               "var cn=pe.className;if(cn&&cn.baseVal!==undefined)cn=cn.baseVal;"
               "cn=(cn||'').toString().split(' ')[0].slice(0,22);"
               "var k=kind+'.'+cn;if(seen[k])continue;seen[k]=1;"
               "acc.push(k+'@'+Math.round(rc.width)+'x'+Math.round(rc.height)+'/'+pcs.color"
                 "+'/f:'+((pcs.filter&&pcs.filter!=='none')?'Y':'-'));}"
             // also name whatever is still LIGHT, which is what the Alexa card is
             "var lt=[];for(var w=0;w<els.length&&lt.length<3;w++){var le=els[w];"
               "var lcs=getComputedStyle(le),ll=lum(lcs.backgroundColor);"
               // lfix has read 0 on every line, so whatever is still light is not a
               // backgroundColor. A gradient is the obvious candidate and is invisible
               // to lum(), so report those too rather than keep guessing at the pane.
               "var lgi=lcs.backgroundImage||'';var lgr=lgi.indexOf('gradient')>=0;"
               "if(!lgr&&(ll===null||ll<=0.55))continue;var lr=le.getBoundingClientRect();"
               "if(lr.width<60||lr.height<20)continue;"
               "var lc=le.className;if(lc&&lc.baseVal!==undefined)lc=lc.baseVal;"
               "lt.push(le.tagName.toLowerCase()+'.'+(lc||'').toString().split(' ')[0].slice(0,18)"
                 "+'@'+Math.round(lr.width)+'x'+Math.round(lr.height));}"
             // Targeted: name the heart's markup directly instead of hoping it lands
             // in the first N icon-sized elements.
             "var ht=[];try{var hq=document.querySelectorAll("
               "'[class*=heart],[class*=wish],[class*=favor],[aria-label*=list],[aria-label*=List]');"
               "for(var y=0;y<hq.length&&ht.length<4;y++){var he=hq[y];"
                 "var hr=he.getBoundingClientRect();if(hr.width<4)continue;"
                 "var hcs=getComputedStyle(he),hk='plain';"
                 "var hbi=hcs.backgroundImage,hmi=hcs.webkitMaskImage||hcs.maskImage;"
                 "if(he.tagName.toLowerCase()==='img')hk='img';"
                 "else if(hmi&&hmi!=='none')hk='mask';"
                 "else if(hbi&&hbi!=='none')hk='bgimg';"
                 "else if(he.namespaceURI==='http://www.w3.org/2000/svg')hk='svg';"
                 "var hc=he.className;if(hc&&hc.baseVal!==undefined)hc=hc.baseVal;"
                 "ht.push(hk+'.'+(hc||'').toString().split(' ')[0].slice(0,20)"
                   "+'@'+Math.round(hr.width)+'x'+Math.round(hr.height)"
                   "+'/f:'+(hcs.fill||'-')+'/c:'+hcs.color);}}catch(e){}"
             // Full subtree of the first heart container, so we stop inferring which
             // node draws the glyph. Widened after the 10-node cap cut the walk off
             // exactly where the glyph should live (the children of the 32x32
             // lists-framework span were nodes 11+): 24 nodes, ::after as well as
             // ::before, pseudo paint sources, and the tail of any <img> src, which
             // names the artwork outright.
             "var htree='';try{var HB=document.querySelector('[class*=heart],[class*=wish],[class*=lists-framework]');"
               "if(HB){var top=HB,up=0;"
                 "while(top.parentElement&&up++<3){var pp2=top.parentElement;"
                   "var pr3=pp2.getBoundingClientRect();if(pr3.width>48||pr3.height>48)break;top=pp2;}"
                 "var stk=[top],hd=[],gd=0;"
                 "var pc2=function(p){return !!(p&&p.content&&p.content!=='none'&&p.content!=='normal');};"
                 "var pi2=function(p){return !!(p&&p.backgroundImage&&p.backgroundImage!=='none');};"
                 "var pm2=function(p){return !!(p&&((p.webkitMaskImage||p.maskImage||'none')!=='none'));};"
                 "while(stk.length&&hd.length<24&&gd++<300){var nd=stk.shift();"
                   "var ncs=getComputedStyle(nd),nrr=nd.getBoundingClientRect();"
                   "var nbb=getComputedStyle(nd,'::before'),naa=getComputedStyle(nd,'::after');"
                   "var cn3=nd.className;if(cn3&&cn3.baseVal!==undefined)cn3=cn3.baseVal;"
                   "var sr2='';if(nd.tagName.toLowerCase()==='img'){"
                     "sr2=(nd.currentSrc||nd.src||'').split('?')[0];sr2='|src='+(sr2?sr2.slice(-26):'-');}"
                   "hd.push(nd.tagName.toLowerCase()+'.'+String(cn3||'').split(' ')[0].slice(0,24)"
                     "+'@'+Math.round(nrr.width)+'x'+Math.round(nrr.height)"
                     "+'|top'+Math.round(nrr.top-bt)"
                     "+'|bg='+ncs.backgroundColor.replace(/ /g,'')"
                     "+'|bgi='+(ncs.backgroundImage==='none'?'-':'Y')"
                     "+'|mask='+(((ncs.webkitMaskImage||ncs.maskImage||'none')==='none')?'-':'Y')"
                     "+'|bef='+(pc2(nbb)?'Y':'-')+'|aft='+(pc2(naa)?'Y':'-')"
                     "+'|pbgi='+(((pi2(nbb)?'b':'')+(pi2(naa)?'a':''))||'-')"
                     "+'|pmsk='+(((pm2(nbb)?'b':'')+(pm2(naa)?'a':''))||'-')"
                     "+'|flt='+ncs.filter+sr2);"
                   "for(var ci2=0;ci2<nd.children.length;ci2++)stk.push(nd.children[ci2]);}"
                 "htree=' HEARTTREE='+hd.join(' ~ ');}"
             "}catch(e){}"
             "var fd=[];try{var FQ=document.querySelectorAll("
               "'[class*=a-expander] *,[data-hook*=review] *');"
               "for(var y2=0;y2<FQ.length&&y2<250&&((y2&15)||!ovr())&&fd.length<3;y2++){var fe2=FQ[y2];"
                 "var c2=getComputedStyle(fe2),b2=c2.backgroundImage||'';"
                 "var pa2=getComputedStyle(fe2,'::after'),pb2=getComputedStyle(fe2,'::before');"
                 "var pab=(pa2&&pa2.backgroundImage!=='none')?pa2.backgroundImage:"
                   "((pb2&&pb2.backgroundImage!=='none')?pb2.backgroundImage:'');"
                 "var src2=(b2.indexOf('gradient')>=0)?b2:((pab.indexOf('gradient')>=0)?('PSEUDO:'+pab):'');"
                 "if(!src2){var lb2=lum(c2.backgroundColor);"
                   "if(lb2!==null&&lb2>0.5)src2='LIGHTBG:'+c2.backgroundColor;}"
                 "if(!src2)continue;"
                 "var r2=fe2.getBoundingClientRect();"
                 "var cn4=fe2.className;if(cn4&&cn4.baseVal!==undefined)cn4=cn4.baseVal;"
                 "fd.push(fe2.tagName.toLowerCase()+'.'+String(cn4||'').split(' ')[0].slice(0,22)"
                   "+'@'+Math.round(r2.width)+'x'+Math.round(r2.height)+'|'+src2.slice(0,46));}"
             "}catch(e){}"
             "var btree='';try{"
               "var findBtn=function(sel){var q=document.querySelectorAll(sel);"
                 "for(var z=0;z<q.length;z++){var rr=q[z].getBoundingClientRect();"
                   "if(rr.width>20&&rr.height>20)return q[z];}return null;};"
               "var dumpBtn=function(el,tag){if(!el)return '';var top=el,up=0;"
                 "var bt=el.getBoundingClientRect().top;"
                 "if(/ompare/i.test(tag)){top=el.parentElement||el;}"
                 "else{while(top.parentElement&&up++<6)top=top.parentElement;}"
                 "var stk=[top],out=[],gd=0;"
                 "while(stk.length&&out.length<14&&gd++<120){var nd=stk.shift();"
                   "var cs=getComputedStyle(nd),rc=nd.getBoundingClientRect();"
                   "var cn=nd.className;if(cn&&cn.baseVal!==undefined)cn=cn.baseVal;"
                   "out.push(nd.tagName.toLowerCase()+'.'+String(cn||'').split(' ')[0].slice(0,30)"
                     "+'@'+Math.round(rc.width)+'x'+Math.round(rc.height)"
                     "+'|bg='+cs.backgroundColor.replace(/ /g,'')"
                     "+'|rad='+(parseFloat(cs.borderTopLeftRadius)||0)"
                     "+'|bgi='+(cs.backgroundImage==='none'?'-':'Y'));"
                   "for(var ci=0;ci<nd.children.length;ci++)stk.push(nd.children[ci]);}"
                 "return ' '+tag+'='+out.join(' ~ ');};"
               "btree=dumpBtn(findBtn('[aria-label*=ompare],[class*=compare],[data-csa-c-content-id*=ompare]'),'CMPTREE')"
                 "+dumpBtn(findBtn('[class*=heart],[class*=wish]'),'HRTBTN');"
             "}catch(e){}"
             "try{var desc=function(n){if(!n)return'';var nr=n.getBoundingClientRect();"
                 "var ncs=getComputedStyle(n),ntg=(n.tagName||'').toLowerCase(),nk='plain';"
                 "var nbi=ncs.backgroundImage,nmi=ncs.webkitMaskImage||ncs.maskImage,nbf=getComputedStyle(n,'::before');"
                 "if(ntg==='img')nk='img';else if(nmi&&nmi!=='none')nk='mask';"
                 "else if(nbi&&nbi!=='none')nk='bgimg';"
                 "else if(nbf.backgroundImage&&nbf.backgroundImage!=='none')nk='pre-bg';"
                 "else if(nbf.content&&nbf.content!=='none'&&nbf.content!=='normal')nk='pre-txt';"
                 "else if(n.namespaceURI==='http://www.w3.org/2000/svg')nk='svg';"
                 "var nc=n.className;if(nc&&nc.baseVal!==undefined)nc=nc.baseVal;"
                 "return ntg+'.'+String(nc||'').split(' ')[0].slice(0,16)+'|'+nk"
                   "+'@'+Math.round(nr.width)+'x'+Math.round(nr.height)"
                   "+'|f:'+((ncs.filter&&ncs.filter!=='none')?'Y':'-')"
                   "+'|fl:'+String(ncs.fill||'-').replace(/ /g,'').slice(0,10)"
                   "+'|c:'+ncs.color.replace(/ /g,'');};"
               "var KBQ=document.querySelectorAll("
               "'[aria-label*=More],[aria-label*=more],[aria-label*=ptions],[aria-label*=verflow],"
               "[class*=sc-nested-actions],[class*=overflow],[class*=kebab],[class*=ellipsis]');"
               "for(var kq=0;kq<KBQ.length;kq++){var ke=KBQ[kq];"
                 "var kr=ke.getBoundingClientRect();if(kr.width<10||kr.width>48||kr.height<10||kr.height>48)continue;"
                 "var kb=[desc(ke)],kk2=ke.querySelectorAll('*');"
                 "for(var ki2=0;ki2<kk2.length&&kb.length<7;ki2++)kb.push(desc(kk2[ki2]));"
                 "window.__AD_KEBAB__=kb.join(' > ');break;}"
               "var CBQ=document.querySelectorAll('[class*=copilot-compare]');"
               "__ck('CBQ');"
               "var cb=[];for(var cq=0;cq<CBQ.length&&cb.length<6;cq++){var cbe=CBQ[cq];"
                 "var cbr=cbe.getBoundingClientRect();if(cbr.width<6||cbr.width>40||cbr.height<6||cbr.height>40)continue;"
                 "cb.push(desc(cbe));}"
               "if(cb.length)window.__AD_CMPBAR__=cb.join(' ~ ');"
             "}catch(e){}"
             "try{var CXB=document.querySelectorAll('[class*=on-image-button]');var cxt=null;"
             "__ck('CXB');"
               "for(var cx=0;cx<CXB.length;cx++){var cxe=CXB[cx];"
                 "var cxcl=cxe.className;if(cxcl&&cxcl.baseVal!==undefined)cxcl=cxcl.baseVal;cxcl=String(cxcl||'');"
                 "if(/compare/i.test(cxcl)||(cxe.closest&&cxe.closest('[class*=copilot-compare]'))){cxt=cxe;break;}}"
               "if(cxt){var cxa=[],node=cxt,cbr=cxt.getBoundingClientRect(),up=0;"
                 "while(node&&up++<5){var ncs=getComputedStyle(node),nr=node.getBoundingClientRect();"
                   "var ncl=node.className;if(ncl&&ncl.baseVal!==undefined)ncl=ncl.baseVal;"
                   "cxa.push(node.tagName.toLowerCase()+'.'+String(ncl||'').split(' ')[0].slice(0,20)"
                     "+'|top'+Math.round(nr.top-cbr.top)+'|h'+Math.round(nr.height)"
                     "+'|bg='+ncs.backgroundColor.replace(/ /g,'')"
                     "+'|bgi='+(ncs.backgroundImage==='none'?'-':'Y')"
                     "+'|sh='+(ncs.boxShadow==='none'?'-':ncs.boxShadow.replace(/ /g,'').slice(0,26)));"
                   "node=node.parentElement;}"
                 "window.__AD_CMPX__=cxa.join(' > ');}"
             "}catch(e){}"
             "pr=' url='+String(location.pathname||'').slice(0,28)"
               "+(window.__AD_CMPX__?(' CMPX='+window.__AD_CMPX__):'')"
               "+(window.__AD_RULE__?(' RULE['+window.__AD_RULE__+']'):'')"
               "+(window.__AD_RESCUE__?(' RESCUE['+window.__AD_RESCUE__+']'):'')"
               "+(window.__AD_ORDERS__?(' ORDERS['+window.__AD_ORDERS__+']'):'')"
               "+(window.__AD_TAME__?(' TAME['+window.__AD_TAME__+']'):'')"
               "+(window.__AD_TEXTBOX__?(' TEXTBOX['+window.__AD_TEXTBOX__+']'):'')"
               "+(window.__AD_ADCARD__?(' ADCARD['+window.__AD_ADCARD__+']'):'')"
               "+(window.__AD_SCREW__?(' SCREW['+window.__AD_SCREW__+']'):'')"
               "+(window.__AD_SHOP__?(' SHOP['+window.__AD_SHOP__+']'):'')"
               "+(window.__AD_MLT__?(' MLT[n='+window.__AD_MLT__+']'):'')"
               "+(window.__AD_PERF__?(' PERF['+window.__AD_PERF__+']'):'')"
               "+(window.__AD_TILEART__?(' TILEART['+window.__AD_TILEART__+']'):'')"
               "+(window.__AD_BOXKILL__?(' BOXKILL['+window.__AD_BOXKILL__+']'):'')"
               "+(window.__AD_FLTSCAN__?(' FLTSCAN['+window.__AD_FLTSCAN__+']'):'')"
               "+(window.__AD_CMPSCAN__?(' CMPSCAN['+window.__AD_CMPSCAN__+']'):'')"
               "+(window.__AD_DARKGLYPH__?(' DARKGLYPH['+window.__AD_DARKGLYPH__+']'):'')"
               "+(window.__AD_TXTSRC__?(' TXTSRC['+window.__AD_TXTSRC__+']'):'')"
               "+(window.__AD_BOXSRC__?(' BOXSRC['+window.__AD_BOXSRC__+']'):'')"
               "+(window.__AD_CARDX__?(' CARDX['+window.__AD_CARDX__+']'):'')"
               "+(function(){try{var F=window.__AD_FRAMES__;if(!F)return '';"
                 "var o=[],c=0;for(var k in F){if(c++>=6)break;o.push(k+' '+F[k]);}"
                 "return o.length?(' FRAMES[n='+o.length+' :: '+o.join(' || ')+']'):' FRAMES[n=0]';"
               "}catch(e){return ' FRAMES[err]';}})()"
               "+(window.__AD_DISC__?(' DISC['+window.__AD_DISC__+']'):'')"
               "+(window.__AD_LOGO__?(' LOGO['+window.__AD_LOGO__+']'):'')"
               "+(window.__AD_ADSKIP__?(' ADSKIP='+window.__AD_ADSKIP__):'')"
               "+(window.__AD_SPON__?(' SPON='+window.__AD_SPON__):'')"
               "+(window.__AD_CARDBLK__?(' CARDBLK='+window.__AD_CARDBLK__):'')"
               "+' P1ADCARD[blk='+(window.__AD_CARDBLK__||0)+' txtskip='+(window.__AD_TXTSKIP__||0)+']'"
               "+' P2SPON[wrote='+(window.__AD_SPON__||0)+' seen='+(window.__AD_SPXT__||0)"
                 "+' dark='+(window.__AD_SPXL__===undefined?'-':window.__AD_SPXL__.toFixed(2))+']'"
               "+(window.__AD_SPX__?(' SPX[n='+(window.__AD_SPXT__||0)+' '+window.__AD_SPX__+']'):'')"
               "+(window.__AD_FRSKIP__?(' FRSKIP='+window.__AD_FRSKIP__):'')"
               "+(window.__AD_FRSRC__?(' FRSRC='+window.__AD_FRSRC__):'')"
               "+(function(){try{var F=window.__AD_FRAMES__,o=[];if(!F)return '';"
                 "for(var k in F){o.push(k+' '+F[k]);}"
                 "return o.length?(' ADTH['+o.join(' | ')+']'):'';"
               "}catch(e){return '';}})()"
               "+(window.__AD_SIL__?(' SIL['+window.__AD_SIL__+']'):'')"
               "+(window.__AD_CMPFIX__?(' CMPFIX['+window.__AD_CMPFIX__+']'):'')"
               "+(window.__AD_KEBAB__?(' KEBAB='+window.__AD_KEBAB__):'')"
               "+(window.__AD_CMPBAR__?(' CMPBAR='+window.__AD_CMPBAR__):'')"
               "+(window.__AD_PROMO__?(' PROMO='+window.__AD_PROMO__):'')"
               "+btree"
               "+(fd.length?(' FADE='+fd.join(' ~ ')):' FADE=none')"
               "+(window.__AD_EARLY__?(' EARLY='+window.__AD_EARLY__):'')"
               "+(acc.length?(' probe='+acc.join(' ')):' probe=none')"
               "+(lt.length?(' light='+lt.join(' ')):'')"
               "+(ht.length?(' HEART='+ht.join(' ')):'')+htree;}"
           "}catch(e){pr=' probeERR';}"
           // v5.378: MLT is a stock Amazon Compare control. The old generic MLT
           // silhouette sweep is disabled so selected blue art cannot be inverted or layered.
           "try{window.__AD_MLT__='stock378';}catch(e){}"
           "__ck('MIC');"

           // SHOP PROBE, standalone. Placed at the top level of the pass, immediately
           // before the return -- last time I nested it inside the ADCARD block,
           // which is gated by `throw 0` after its first run, so it may never have
           // executed at all. Reports every small element inside a control with the
           // properties that separate a sprite glyph from a photo. Once per document.
           "try{if(document.readyState==='complete'&&!window.__AD_SHOP_DONE__){"
             "window.__AD_SHOP_DONE__=1;"
             "var SH=document.querySelectorAll('img,svg,span,div'),so=[],ssk=0;"
             "for(var si=0;si<SH.length&&si<3000&&so.length<20;si++){var se=SH[si];"
               "var sr=se.getBoundingClientRect();"
               "if(sr.width<18||sr.width>110||sr.height<18||sr.height>110)continue;"
               // SQUARE-ISH ONLY. The last run filled its whole budget with 86x32
               // and 46x20 toolbar chips and never reached anything round.
               "var asp=sr.width/(sr.height||1);if(asp<0.7||asp>1.45)continue;"
               "if(!se.closest||!se.closest('button,[role=button],[aria-label],a'))continue;"
               "var sc=getComputedStyle(se);"
               "var pe=se.parentElement;"
               "var pbr=pe?String(getComputedStyle(pe).borderRadius||'-'):'-';"
               // MUST BEAR ART OR BE A CIRCLE. Every entry last time was nat=0x0
               // with no radius -- plain text spans, telling us nothing.
               "var bgiu=String(sc.backgroundImage||'').indexOf('url(')>=0;"
               "var isim=(se.tagName==='IMG'||se.tagName==='svg'||se.tagName==='SVG');"
               "var circ=(/%%/.test(String(sc.borderRadius||''))||/%%/.test(pbr));"
               "if(!isim&&!bgiu&&!circ){ssk++;continue;}"
               "so.push(se.tagName+'@'+Math.round(sr.width)+'x'+Math.round(sr.height)"
                 "+'|cls='+String((se.className&&se.className.baseVal!==undefined)"
                   "?se.className.baseVal:(se.className||'')).slice(0,22)"
                 "+'|nat='+(se.naturalWidth||0)+'x'+(se.naturalHeight||0)"
                 "+'|br='+sc.borderRadius+'|pbr='+pbr"
                 "+'|flt='+String(sc.filter).slice(0,24)"
                 "+'|bgi='+(String(sc.backgroundImage||'').indexOf('url(')>=0?'y':'n')"
                 "+'|by='+(se.__adBy||'-')"
                 "+'|'+String(se.currentSrc||se.src||'').slice(-20));}"
             "window.__AD_SHOP__=(so.length?(so.join(' ~ ')+' [skipped='+ssk+' of '+SH.length+']')"
               ":('none scanned='+SH.length+' skipped='+ssk));"
           "}}catch(e){window.__AD_SHOP__='err '+e;}"
           "window.__ADSPXR__=0;"
           "window.__AD_PERF__='ms='+(Date.now()-__T0)+' cut='+__cut+' '+__ckl.join(' ');"
           // CHILD FRAME -> TOP. Every frame self-describes (text-element count, body
           // child count, path) so "nothing found" is distinguishable from "nothing
           // here", which is exactly the ambiguity that made scanned=0 unreadable.
           // Posts only when the fragment changes, so this is not a message storm.
           // Poster hoisted onto window so the THROTTLED path can call it too -- a
           // child frame that bails out early must still register, or FRAMES[n=0]
           // just means "everything was rate limited", which is what it meant before.
           "window.__ADPOST__=function(){try{if(window.top===window)return;"
             "var _fr='t='+(window.__AD_TXTN__===undefined?'?':window.__AD_TXTN__)"
               "+' b='+((document.body&&document.body.children.length)||0)"
               "+(window.__AD_CARDX__?(' CARDX['+window.__AD_CARDX__+']'):'')"
               "+(window.__AD_ADCARD__?(' ADCARD['+window.__AD_ADCARD__+']'):'')"
               "+(window.__AD_TXTSRC__?(' TXTSRC['+window.__AD_TXTSRC__+']'):'')"
               "+(window.__AD_BOXSRC__?(' BOXSRC['+window.__AD_BOXSRC__+']'):'')"
               "+(window.__AD_BOXKILL__?(' BOXKILL['+window.__AD_BOXKILL__+']'):'')"
               // SIL and LOGO were computed in every frame and forwarded from none of
               // them. The top frame reports stars=0 across 1134 elements, which is
               // true of THAT document -- the rating simply is not in it. The audit
               // has been running in the child frames all along and its result was
               // being dropped on the floor.
               "+(window.__AD_SIL__?(' SIL['+window.__AD_SIL__+']'):'')"
               "+(window.__AD_ADTHEME__?(' ADTHEME['+window.__AD_ADTHEME__+']'):'')"
               "+(window.__AD_LOGO__?(' LOGO['+window.__AD_LOGO__+']'):'');"
             "if(_fr!==window.__ADFRLAST__){window.__ADFRLAST__=_fr;"
               "window.top.postMessage({__adfr:1,"
                 "u:String(location.pathname||'/').slice(-20),r:_fr},'*');}"
           "}catch(e){}};"
           "try{window.__ADPOST__();}catch(e){}"
           // Cache the assembled report so a throttled call can still hand it back.
           // SILHOUETTE AUDIT. Every previous probe asked "is pass X touching this?"
           // and the answer kept coming back no -- gfix, tileart and the native lift
           // have each been cleared in turn. This asks the opposite question: find
           // everything on screen that is CURRENTLY inverted and report which pass
           // stamped it. All eleven invert writers now stamp __adBy, so by=<name>
           // names the culprit outright, and by=- means a twelfth writer exists that
           // I have not found. Re-arms until it actually finds something.
           "try{if((window.__AD_SIL_N__||0)<40&&!window.__AD_SIL_HIT__){"
             "window.__AD_SIL_N__=(window.__AD_SIL_N__||0)+1;"
             // TWO BUCKETS AND A DEDUPE. The last run returned six copies of one 20x20
             // header icon: querySelectorAll walks document order, chrome comes first,
             // and the budget was gone before the walk reached a card. That is the
             // fourth probe of mine eaten the same way, so this stops relying on a
             // bigger number. Anything whose class or src names a star or rating goes
             // in the priority bucket and is reported first wherever it sits;
             // everything else must be below the header and is deduped by class+size,
             // so N copies of one icon can never consume the budget again.
             "var SQ=document.querySelectorAll('img,svg,span,div,i'),pri=[],oth=[],seenK={},starN=0;"
             "for(var sq=0;sq<SQ.length&&sq<2500&&(pri.length+oth.length)<10;sq++){var se2=SQ[sq];"
               "var sr2=se2.getBoundingClientRect();"
               "if(sr2.width<10||sr2.width>200||sr2.height<8||sr2.height>60)continue;"
               "if(sr2.bottom<0||sr2.top>(window.innerHeight||900))continue;"
               "var sc2=getComputedStyle(se2),sfl=String(sc2.filter||'');"
               "var kcls=String((se2.className&&se2.className.baseVal!==undefined)"
                 "?se2.className.baseVal:(se2.className||''));"
               "var ksrc=String(se2.currentSrc||se2.src||'');"
               "var isStar=/star|rating|review/i.test(kcls+' '+ksrc);"
               "if(isStar)starN++;"
               // A STAR IS REPORTED WHETHER OR NOT IT CARRIES A FILTER. The last run
               // said none scanned=1195, but the filter test ran BEFORE the star test,
               // so an unfiltered star was discarded and "no stars here" was
               // indistinguishable from "stars here, no filter on them". Those point
               // at completely different causes.
               //
               // The ancestor chain matters just as much: a filter on a parent inverts
               // the whole subtree while the child's own computed filter still reads
               // none. This project has already been caught by exactly that once -- it
               // cost three builds of threshold tuning on the wrong element.
               "if(isStar){"
                 "var anc='',ap=se2.parentElement,ad4=0;"
                 "while(ap&&ad4++<5){var af=String(getComputedStyle(ap).filter||'none');"
                   "if(af!=='none')anc+='^'+String(ap.className||'').slice(0,10)+'='+af.slice(0,14);"
                   "ap=ap.parentElement;}"
                 "if(pri.length<4)pri.push('STAR '+se2.tagName+'@'"
                   "+Math.round(sr2.width)+'x'+Math.round(sr2.height)"
                   "+'|cls='+kcls.slice(0,18)+'|flt='+sfl.slice(0,18)"
                   "+'|op='+sc2.opacity+'|blend='+sc2.mixBlendMode"
                   "+'|by='+(se2.__adBy||'-')+'|anc='+(anc||'none')"
                   "+'|'+ksrc.slice(-20));"
                 "continue;}"
               "if(sfl.indexOf('invert')<0&&sfl.indexOf('brightness')<0)continue;"
               "{"
                 "if(sr2.top<160)continue;"
                 "var kk=kcls.slice(0,16)+'|'+Math.round(sr2.width)+'x'+Math.round(sr2.height);"
                 "if(seenK[kk])continue;seenK[kk]=1;}"
               "(isStar?pri:oth).push(se2.tagName+'@'+Math.round(sr2.width)+'x'+Math.round(sr2.height)"
                 "+'|cls='+String((se2.className&&se2.className.baseVal!==undefined)"
                   "?se2.className.baseVal:(se2.className||'')).slice(0,20)"
                 "+'|flt='+sfl.slice(0,20)"
                 "+'|by='+(se2.__adBy||'-')"
                 "+'|'+String(se2.currentSrc||se2.src||'').slice(-18));}"
             // Latch only on a priority hit. Chrome findings must not stop the search.
             "if(pri.length)window.__AD_SIL_HIT__=1;"
             "var sv=pri.concat(oth);"
             "window.__AD_SIL__=(sv.length?('star='+pri.length+'/'+starN+' '+sv.join(' ~ '))"
               ":('none scanned='+SQ.length+' stars='+starN+' run='+window.__AD_SIL_N__));"
           "}}catch(e){window.__AD_SIL__='err '+e;}"
           "try{window.__AD_LASTREP__=n+'/'+bfix+'/'+lfix+'/'+gfix+'/'+bigfix+pr;}catch(e){}"
           "try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}"
           "return n+'/'+bfix+'/'+lfix+'/'+gfix+'/'+bigfix+pr;}catch(e){return -1;}};"
         // v5.391: existing-host-only product control skin. Hard-gated to Search/PDP;
         // Home and child ad frames exit before any DOM/style write. No createElement,
         // appendChild, insertBefore, dimensions, transforms, overflow or position writes.
         "window.__AD_PRODUCTCTRL391RUN__=function(){try{if(window.__ADFRAME_MODE__||!document.body)return 0;"
           "function page(){try{if(document.querySelector('#productTitle,#dp-container,#ppd,.ssf-share-trigger'))return 2;if(document.querySelector('#search,.s-search-results,.s-result-list,[data-component-type=\"s-search-result\"]'))return 1;}catch(x){}return 0;}"
           "var pg=page();window.__AD_PRODUCTPAGE391__=pg;if(!pg){window.__AD_PRODUCTCTRL391__='off';return 0;}"
           "var heart=0,cards=0,arrow=0,check=0,miss=0,seen=[];"
           "function cn(e){var c=e&&e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||''));}"
           "function rr(e){try{return e&&e.getBoundingClientRect?e.getBoundingClientRect():null;}catch(x){return null;}}"
           "function square(e,lo,hi){var r=rr(e);return !!(r&&r.width>=lo&&r.width<=hi&&r.height>=lo&&r.height<=hi&&Math.abs(r.width-r.height)<=7);}"
           "function structural(e){if(!e||e.nodeType!==1)return false;return !/^(IMG|I|INPUT|SVG|PATH|USE|POLYGON)$/.test(String(e.tagName||'').toUpperCase());}"
           "function badleaf(e){var z=String((e&&e.currentSrc)||e&&e.src||'')+' '+cn(e);return /placehold|spacer|grey-pixel|gray-pixel|transparent-pixel/i.test(z);}"
           "function productCard(e){return e&&e.closest&&e.closest('[class*=\"puis-card\"],[class*=\"s-result-item\"],[data-asin],[class*=\"s-product-image\"],[class*=\"product-image\"]');}"
           "function skin(h,type){if(!h||seen.indexOf(h)>=0)return 0;var r=rr(h);if(!r||r.width<20||r.width>50||r.height<20||r.height>50||Math.abs(r.width-r.height)>8)return 0;seen.push(h);h.setAttribute('data-ad-product391',type);h.removeAttribute('data-ad-productselected390');h.style.setProperty('background-color','#181a1b','important');h.style.setProperty('border','0','important');h.style.setProperty('border-radius','50%%','important');h.style.setProperty('box-shadow','inset 0 0 0 1.5px rgba(255,255,255,.65)','important');h.style.setProperty('box-sizing','border-box','important');return 1;}"
           "function paint(e,h){if(!e||e===h||e.nodeType!==1||badleaf(e))return 0;var r=rr(e);if(!r||r.width<3||r.height<3||r.width>36||r.height>36)return 0;var t=String(e.tagName||'').toUpperCase(),cs=getComputedStyle(e),bi=String(cs.backgroundImage||'none'),mi=String(cs.maskImage||cs.webkitMaskImage||'none');e.setAttribute('data-ad-productglyph391','1');e.style.setProperty('visibility','visible','important');e.style.setProperty('opacity','1','important');e.__adGlyph=1;e.__adBy='product391';if(t==='IMG'||t==='I'||bi!=='none'||mi!=='none')e.setAttribute('data-ad-productraster391','1');if(t==='SVG'||t==='PATH'||t==='USE'||t==='POLYGON'){e.setAttribute('data-ad-productvector391','1');e.style.setProperty('color','#fff','important');e.style.setProperty('fill','#fff','important');e.style.setProperty('stroke','#fff','important');}return 1;}"
           "function around(root,g,lo,hi){if(!root||!g)return null;var p=g,best=null,bd=999,u=0;while(p&&u++<8){if(structural(p)&&square(p,lo,hi)){var r=rr(p),d=Math.abs(Math.max(r.width,r.height)-34);if(d<bd){bd=d;best=p;}}if(p===root)break;p=p.parentElement;}return best;}"
           "function glyphs(h){if(!h||!h.querySelectorAll)return;var G=h.querySelectorAll('img,i,svg,path,use,polygon,[class*=\"a-icon\"],[class*=\"lists-framework-unfill\"],[class*=\"lists-framework-fill\"]');for(var i=0;i<G.length&&i<40;i++)paint(G[i],h);}"
           // v5.393 Heart: do not skin anything until the REAL stock painter exists.
           // The failed 5.392 probe found 24-42 hosts with glyph=0, proving that host
           // geometry alone is not enough. Support element, background/mask and pseudo
           // Heart painters, reject 1-2px/lazy shims, and clear stale empty Heart chrome.
           "function ph393(e){var z=String((e&&e.currentSrc)||e&&e.src||'')+' '+cn(e);if(/placehold|spacer|grey[-_]?pixel|gray[-_]?pixel|transparent[-_]?pixel|(?:^|[/_-])blank(?:[._-]|$)/i.test(z))return 1;var t=String(e&&e.tagName||'').toUpperCase();return !!(t==='IMG'&&e.complete&&(e.naturalWidth||0)>0&&(e.naturalHeight||0)>0&&(e.naturalWidth||0)<=2&&(e.naturalHeight||0)<=2);}"
           "function ps393(e,w){try{var c=getComputedStyle(e,w),bi=String(c.backgroundImage||'none'),mi=String(c.maskImage||c.webkitMaskImage||'none'),ct=String(c.content||'none');if(mi!=='none')return 2;if(bi!=='none'&&bi.indexOf('url(')>=0)return 1;if(ct&&ct!=='none'&&ct!=='normal'&&ct!=='\"\"')return 3;}catch(x){}return 0;}"
           "function markps393(e,w,t){if(!e||!t)return;var pre=w==='::before'?'before':'after';e.setAttribute('data-ad-heart'+pre+'393','1');if(t===2)e.setAttribute('data-ad-heart'+pre+'mask393','1');else if(t===1)e.setAttribute('data-ad-heart'+pre+'raster393','1');}"
           "function clearHeart393(root){if(!root||!root.querySelectorAll)return;root.removeAttribute('data-ad-heartready394');var O=root.querySelectorAll('[data-ad-product391=\"heart\"]');for(var oi=0;oi<O.length;oi++){var o=O[oi];o.removeAttribute('data-ad-product391');['background-color','border','border-radius','box-shadow','box-sizing'].forEach(function(k){o.style.removeProperty(k);});}var M=root.querySelectorAll('[data-ad-heartbefore393],[data-ad-heartafter393],[data-ad-heartbeforemask393],[data-ad-heartaftermask393],[data-ad-heartbeforeraster393],[data-ad-heartafterraster393]');for(var mi=0;mi<M.length;mi++){['data-ad-heartbefore393','data-ad-heartafter393','data-ad-heartbeforemask393','data-ad-heartaftermask393','data-ad-heartbeforeraster393','data-ad-heartafterraster393'].forEach(function(a){M[mi].removeAttribute(a);});}}"
           "function heartGlyph393(root){if(!root)return null;var Q=root.querySelectorAll('[class*=\"lists-treatment-hear\"] .a-icon,[class*=\"heart\"] .a-icon,[class*=\"wish\"] .a-icon,[class*=\"favor\"] .a-icon,.a-icon,img,i,svg,path,use,polygon,button,[role=button],a,span,div'),best=null,bs=-1;for(var qi=0;qi<Q.length&&qi<140;qi++){var e=Q[qi],r=rr(e);if(!r||r.width<3||r.height<3||r.width>48||r.height>48||ph393(e))continue;var t=String(e.tagName||'').toUpperCase(),c=cn(e),cs=getComputedStyle(e),bi=String(cs.backgroundImage||'none'),mi=String(cs.maskImage||cs.webkitMaskImage||'none'),pb=ps393(e,'::before'),pa=ps393(e,'::after'),real=(t==='SVG'||t==='PATH'||t==='USE'||t==='POLYGON'||(t==='IMG'&&!!String(e.currentSrc||e.src||''))||bi.indexOf('url(')>=0||mi!=='none'||pb||pa);if(!real)continue;var sc=0;if(/heart|wish|favor|lists-treatment/i.test(c))sc+=40;if(/a-icon/i.test(c))sc+=18;if(t==='IMG'||t==='I'||t==='SVG'||t==='PATH')sc+=10;if(bi.indexOf('url(')>=0||mi!=='none')sc+=16;if(pb||pa)sc+=14;sc+=Math.max(0,10-Math.abs(Math.max(r.width,r.height)-20));if(sc>bs){bs=sc;best={e:e,pb:pb,pa:pa};}}return best;}"
           "var H=document.querySelectorAll('[class*=\"puis-heart-position\"]');for(var hi=0;hi<H.length&&hi<180;hi++){var hr=H[hi],pick=heartGlyph393(hr);if(!pick){clearHeart393(hr);miss++;continue;}var hg=pick.e,hh=around(hr,hg,24,48);if(!hh&&square(hr,24,48))hh=hr;if(!hh){clearHeart393(hr);miss++;continue;}if(skin(hh,'heart')){var hpok=paint(hg,hh);if(pick.pb)markps393(hg,'::before',pick.pb);if(pick.pa)markps393(hg,'::after',pick.pa);if(hpok||pick.pb||pick.pa){hr.setAttribute('data-ad-heartready394','1');heart++;}else{clearHeart393(hr);miss++;}}}"
           // Two-card/list: locate Amazon's real glyph, then the nearest existing square host.
           // Row-sized lists roots are never rounded and no replacement disc is created.
           "var A=document.querySelectorAll('[class*=\"lists-framework-action-button\"]');for(var ai=0;ai<A.length&&ai<200;ai++){var ar=A[ai];if(ar.closest&&ar.closest('[class*=\"puis-heart-position\"]'))continue;var Q=ar.querySelectorAll('[class*=\"lists-framework-unfill\"],[class*=\"lists-framework-fill\"],img,i,svg'),ag=null,bs=-1;for(var aq=0;aq<Q.length&&aq<70;aq++){var e=Q[aq],er=rr(e);if(!er||er.width<3||er.height<3||er.width>42||er.height>42||badleaf(e))continue;var sc=0,c=cn(e),src=String(e.currentSrc||e.src||'');if(/lists-framework-(?:unfill|fill)/i.test(c))sc+=30;if(/01rrzVoKd5L/i.test(src))sc+=30;if(/^(IMG|I|SVG)$/i.test(String(e.tagName||'')))sc+=4;if(sc>bs){bs=sc;ag=e;}}if(!ag){miss++;continue;}var ah=around(ar,ag,24,50);if(!ah&&square(ar,24,50))ah=ar;if(!ah){miss++;continue;}if(skin(ah,'cards')){glyphs(ah);paint(ag,ah);cards++;}}"
           // Product down-arrow only. Require Search/PDP plus product-card ancestry and
           // reject carousel navigation, Heart, cards and Compare families.
           "var E=document.querySelectorAll('[class*=\"a-icon-dropdown\"],[class*=\"a-icon-extender\"],[class*=\"chevron\"],[class*=\"caret\"],[class*=\"arrow\"]'),seenArrow=[];for(var ei=0;ei<E.length&&ei<500;ei++){var eg=E[ei],ec=productCard(eg);if(!ec)continue;var cl=cn(eg);if(/carousel|next|previous|prev/i.test(cl))continue;if(eg.closest&&eg.closest('[class*=\"puis-heart-position\"],[class*=\"lists-framework-action-button\"],[class*=\"mlt-icon-container\"],[role=checkbox]'))continue;var eh=around(ec,eg,22,48);if(!eh||seenArrow.indexOf(eh)>=0)continue;seenArrow.push(eh);if(skin(eh,'arrow')){glyphs(eh);paint(eg,eh);arrow++;}}"
           "function selected(e){try{var q=e&&e.querySelector&&e.querySelector('input[type=checkbox]');if(q)return !!q.checked;var p=e,u=0;while(p&&u++<5){var a=String(p.getAttribute&&p.getAttribute('aria-checked')||p.getAttribute&&p.getAttribute('data-checked')||p.getAttribute&&p.getAttribute('data-selected')||'').toLowerCase(),c=cn(p).toLowerCase();if(a==='true'||/(^|[ _-])(checked|selected|active)([ _-]|$)/.test(c))return true;if(a==='false')return false;p=p.parentElement;}var im=e&&e.querySelector&&e.querySelector('img'),src=im?String(im.currentSrc||im.src||'').toLowerCase():'';return /checkbox[_-]?(?:on|checked)|checkmark|selected/.test(src);}catch(x){return false;}}"
           "function checkHost(e){var p=e&&String(e.tagName||'').toUpperCase()==='INPUT'?e.parentElement:e,best=null,bd=999,u=0;while(p&&u++<7){if(structural(p)&&square(p,24,46)){var r=rr(p),d=Math.abs(Math.max(r.width,r.height)-32);if(d<bd){bd=d;best=p;}}if(productCard(p)&&best)break;p=p.parentElement;}return best;}"
           // Compare: preserve compareStock380/legacy state/click machinery; skin the exact
           // existing square host after those functions flatten it.
           "var C=document.querySelectorAll('[class*=\"mlt-icon-container\"],[role=checkbox],input[type=checkbox],i.a-icon-checkbox,[class*=\"a-icon-checkbox\"]'),seenC=[];for(var ci=0;ci<C.length&&ci<450;ci++){var ce=C[ci],ch=checkHost(ce);if(!ch||seenC.indexOf(ch)>=0)continue;if(!productCard(ch)&&!(/mlt-icon-container/i.test(cn(ch))))continue;seenC.push(ch);if(!skin(ch,'checkbox'))continue;ch.setAttribute('data-ad-productselected391',selected(ch)?'1':'0');var O=ch.querySelectorAll('img,i,svg,path,[class*=\"a-icon-checkbox\"],[class*=\"icon\"],[class*=\"image\"]');for(var oi=0;oi<O.length&&oi<45;oi++){var ox=O[oi],orr=rr(ox);if(!orr||orr.width>48||orr.height>48)continue;ox.setAttribute('data-ad-compareorig380','1');}check++;}"
           "window.__AD_PRODUCTCTRL391__='page='+pg+' heart='+heart+' cards='+cards+' arrow='+arrow+' checkbox='+check+' miss='+miss;return heart+cards+arrow+check;"
         "}catch(e){window.__AD_PRODUCTCTRL391__='err '+(e&&e.message||e);return -1;}};"
         // v5.397: keep the current checkbox implementation byte-for-byte, then
         // restore v5.333 ownership for every other product/control symbol after the
         // newer product-control pass has run. No checkbox/MLT/role=checkbox node is touched.
         "window.__AD_SYMBOL333397__=function(){try{if(window.__ADFRAME_MODE__||!document.body)return 0;"
           "function ischeck397(e){try{return !!(e&&e.closest&&e.closest('[class*=mlt-icon-container],[role=checkbox],input[type=checkbox],[class*=a-icon-checkbox],[data-ad-compare380],[data-ad-comparelegacy387],[data-ad-product391=\"checkbox\"]'));}catch(x){return false;}}"
           "function rasterSafe397(e){try{return !!(e&&!artChk(e));}catch(x){return false;}}"
           "var reset397=0,D397=document.querySelectorAll('[data-ad-product391]:not([data-ad-product391=\"checkbox\"])');"
           "for(var d397=0;d397<D397.length&&d397<260;d397++){var h397=D397[d397];if(ischeck397(h397))continue;h397.removeAttribute('data-ad-product391');h397.removeAttribute('data-ad-productselected391');['background-color','border','border-radius','box-shadow','box-sizing'].forEach(function(k397){h397.style.removeProperty(k397);});reset397++;}"
           "var G397=document.querySelectorAll('[data-ad-productglyph391],[data-ad-productraster391],[data-ad-productvector391]');for(var g397=0;g397<G397.length&&g397<700;g397++){var q397=G397[g397];if(ischeck397(q397))continue;var t397=String(q397.tagName||'').toUpperCase(),cs397=getComputedStyle(q397),bi397=String(cs397.backgroundImage||'none'),mi397=String(cs397.maskImage||cs397.webkitMaskImage||'none');if(t397==='SVG'||t397==='PATH'||t397==='USE'||t397==='POLYGON'){q397.style.setProperty('color','#fff','important');q397.style.setProperty('fill','#fff','important');q397.style.setProperty('stroke','#fff','important');}else if(rasterSafe397(q397)&&(t397==='IMG'||t397==='I'||bi397!=='none'||mi397!=='none')){q397.style.setProperty('filter','brightness(0) invert(1)','important');q397.style.setProperty('background-color','transparent','important');}q397.removeAttribute('data-ad-productglyph391');q397.removeAttribute('data-ad-productraster391');q397.removeAttribute('data-ad-productvector391');q397.__adGlyph=1;q397.__adBy='v333397';}"
           "var H397=document.querySelectorAll('[class*=puis-heart-position]');for(var h397i=0;h397i<H397.length&&h397i<180;h397i++){var hr397=H397[h397i];if(ischeck397(hr397))continue;hr397.removeAttribute('data-ad-heartready394');hr397.style.setProperty('background-color','transparent','important');hr397.style.setProperty('border','0','important');hr397.style.setProperty('box-shadow','none','important');hr397.style.setProperty('visibility','visible','important');var hm397=hr397.querySelectorAll('[data-ad-heartbefore393],[data-ad-heartafter393],[data-ad-heartbeforemask393],[data-ad-heartaftermask393],[data-ad-heartbeforeraster393],[data-ad-heartafterraster393]');for(var hz397=0;hz397<hm397.length;hz397++){['data-ad-heartbefore393','data-ad-heartafter393','data-ad-heartbeforemask393','data-ad-heartaftermask393','data-ad-heartbeforeraster393','data-ad-heartafterraster393'].forEach(function(a397){hm397[hz397].removeAttribute(a397);});}}"
           // Exact v5.333 ACTION-BUTTON DISC runtime, restored verbatim in behavior.
           "var DB397=document.querySelectorAll('[class*=lists-framework-action-button]'),ndisc397=0,dskip397=0;for(var db397=0;db397<DB397.length&&db397<80;db397++){var de397=DB397[db397];if(ischeck397(de397))continue;var dr397=de397.getBoundingClientRect();if(dr397.width<18||dr397.width>52||dr397.height<18||dr397.height>52){dskip397++;continue;}if(Math.abs(dr397.width-dr397.height)>10){dskip397++;continue;}de397.style.setProperty('background-color','#181a1b','important');de397.style.setProperty('border-radius','50%%','important');de397.style.setProperty('border','1.5px solid rgba(255,255,255,0.65)','important');de397.style.setProperty('box-shadow','none','important');de397.style.setProperty('box-sizing','border-box','important');ndisc397++;}"
           "window.__AD_SYMBOL333397_STATE__='reset='+reset397+' action='+ndisc397+' skip='+dskip397;return reset397+ndisc397;"
         "}catch(e){window.__AD_SYMBOL333397_STATE__='err '+(e&&e.message||e);return -1;}};"
         "try{window.__AD_PRODUCTCTRL391_ORIG397__=window.__AD_PRODUCTCTRL391RUN__;window.__AD_PRODUCTCTRL391RUN__=function(){var r397=window.__AD_PRODUCTCTRL391_ORIG397__?window.__AD_PRODUCTCTRL391_ORIG397__():0;try{window.__AD_SYMBOL333397__();}catch(e397){}return r397;};}catch(e){}"
         "try{window.__AD_SYMBOL333397__();setTimeout(window.__AD_SYMBOL333397__,40);setTimeout(window.__AD_SYMBOL333397__,220);setTimeout(window.__AD_SYMBOL333397__,900);}catch(e){}"
         "window.__AMZDARK_APPLY__=function(){try{"
           "if(!document.querySelector('style.darkreader'))DarkReader.enable(%@,%@);"
           "if(window._adTameFast362)_adTameFast362(document.documentElement);"
           "if(window._adTextPins363)_adTextPins363(document.documentElement);"
           "if(window.__AD_COLLEGE_FAST59__)window.__AD_COLLEGE_FAST59__();"
           "if(window._adVideoCtlMain362)_adVideoCtlMain362();"
           "if(window._adHomeVideo391)_adHomeVideo391();"
           "if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();"
         "}catch(e){}};"
         // v5.403: RESTORE THE USER-CONFIRMED v5.333 SYMBOL PRESENTATION for the
         // three non-checkbox Search/product controls: Heart, cards/list-plus, and
         // product down-arrow.  The existing v5.397 post-modern authority is already
         // the exact v5.333 policy for those families, so this layer MUST NOT restyle
         // their host or glyph.  It only leaves a passive family marker for the probe.
         // The checkbox is the sole v5.402 family the user reported working; preserve
         // that stock-checkbox treatment unchanged in behavior and isolate it here.
         "window.__AD_STOCKCAP403__=function(){try{if(window.__ADFRAME_MODE__||!document.body)return 0;var H=document.querySelectorAll('[data-ad-product391]'),n=0,c=0;for(var i=0;i<H.length&&i<96;i++){var h=H[i],t=String(h.getAttribute('data-ad-product391')||''),k='';if(t==='heart')k='h';else if(t==='cards')k='d';else if(t==='arrow')k='a';else if(t===('c'+'heckbox'))k='c';else continue;h.setAttribute('data-ad-v333403',k);if(k!=='c'){n++;continue;}h.setAttribute('data-ad-stock403','c');h.setAttribute('data-ad-stocksel403',String(h.getAttribute('data-ad-productselected391')||'0'));var G=h.querySelectorAll('[data-ad-productglyph391],[data-ad-productraster391],[data-ad-productvector391],[data-ad-compareorig380],[data-ad-comparelegacyorig387],img,i,svg,path,use,polygon,.a-icon');for(var j=0;j<G.length&&j<80;j++){var g=G[j],r=g.getBoundingClientRect?g.getBoundingClientRect():null;if(r&&(r.width>56||r.height>56))continue;var tg=String(g.tagName||'').toUpperCase(),cs=getComputedStyle(g),bi=String(cs.backgroundImage||'none'),mi=String(cs.maskImage||cs.webkitMaskImage||'none');g.setAttribute('data-ad-stockglyph403','c');if(g.hasAttribute('data-ad-productvector391')||tg==='SVG'||tg==='PATH'||tg==='USE'||tg==='POLYGON')g.setAttribute('data-ad-stockvector403','1');else if(g.hasAttribute('data-ad-productraster391')||tg==='IMG'||tg==='I'||bi!=='none'||mi!=='none')g.setAttribute('data-ad-stockraster403','1');}c++;n++;}window.__AD_STOCKCAP403_STATE__='n='+n+' checkbox='+c;return n;}catch(e){window.__AD_STOCKCAP403_STATE__='err '+(e&&e.message||e);return -1;}};"
         "window.__AD_STOCKFIN403__=function(){try{if(window.__ADFRAME_MODE__||!document.body)return 0;var H=document.querySelectorAll('[data-ad-stock403=\"c\"]'),n=0;for(var i=0;i<H.length&&i<96;i++){var h=H[i];['background','background-color','border','border-color','border-width','border-style','border-radius','box-shadow','box-sizing','filter','width','height','min-width','min-height','max-width','max-height'].forEach(function(k){h.style.removeProperty(k);});h.removeAttribute('data-ad-product391');h.removeAttribute('data-ad-productselected391');var G=h.querySelectorAll('[data-ad-stockglyph403]');for(var j=0;j<G.length&&j<80;j++){var g=G[j];['filter','background','background-color','color','fill','stroke','visibility','opacity'].forEach(function(k){g.style.removeProperty(k);});g.removeAttribute('data-ad-productglyph391');g.removeAttribute('data-ad-productraster391');g.removeAttribute('data-ad-productvector391');g.removeAttribute('data-ad-compareorig380');g.removeAttribute('data-ad-comparelegacyorig387');}n++;}window.__AD_STOCKFIN403_STATE__='checkbox='+n;return n;}catch(e){window.__AD_STOCKFIN403_STATE__='err '+(e&&e.message||e);return -1;}};"
         "try{window.__AD_PRODUCTCTRL391_BASE403__=window.__AD_PRODUCTCTRL391_ORIG397__;window.__AD_PRODUCTCTRL391_ORIG397__=function(){var r=window.__AD_PRODUCTCTRL391_BASE403__?window.__AD_PRODUCTCTRL391_BASE403__():0;try{window.__AD_STOCKCAP403__();}catch(x){}return r;};window.__AD_PRODUCTCTRL391_WRAP403__=window.__AD_PRODUCTCTRL391RUN__;window.__AD_PRODUCTCTRL391RUN__=function(){var r=window.__AD_PRODUCTCTRL391_WRAP403__?window.__AD_PRODUCTCTRL391_WRAP403__():0;try{window.__AD_STOCKFIN403__();}catch(x){}return r;};}catch(e){}"
         "try{if(document&&!document.getElementById('adstock403')){var s403=document.createElement('style');s403.id='adstock403';s403.textContent='[data-ad-stock403=c]{background-color:#181a1b !important;border-color:#9aa0a3 !important;border-width:1.5px !important;border-style:solid !important;box-shadow:none !important;box-sizing:border-box !important;filter:none !important;}[data-ad-stockglyph403]{visibility:visible !important;opacity:1 !important;background-color:transparent !important;}[data-ad-stockraster403=1]{filter:brightness(0) invert(1) !important;}[data-ad-stockvector403=1],[data-ad-stockvector403=1] *{color:#fff !important;fill:#fff !important;stroke:#fff !important;}[data-ad-stock403=c]::before,[data-ad-stock403=c]::after{content:none !important;display:none !important;}[data-ad-stock403=c] [data-ad-stockglyph403]{visibility:visible !important;opacity:1 !important;}[data-ad-stock403=c][data-ad-stocksel403=1] [data-ad-stockraster403=1]{filter:none !important;}';(document.head||document.documentElement).appendChild(s403);}}catch(e){}"
         // v5.401 Home bleed experiment: v5.397 Home paint/color logic remains byte-for-byte.
         // The only new paint rule clips the actual ambient layer to its own border box.
         // No host/ancestor writes; no contain/overflow/isolation/transform/background/filter;
         // no DOM observer or recurring JS. This cannot flatten carousel card colors.
         "try{if(document&&!document.getElementById('adbleed401')){var b401=document.createElement('style');b401.id='adbleed401';b401.textContent='html[data-ad-main396] [class*=single-creative-card] [class*=theming-card-background],html[data-ad-main396] [class*=single-video-card] [class*=theming-card-background]{-webkit-clip-path:inset(0.5px) !important;clip-path:inset(0.5px) !important;-webkit-backface-visibility:hidden !important;backface-visibility:hidden !important;background-clip:padding-box !important;}';(document.head||document.documentElement).appendChild(b401);}}catch(e){}"
         // v5.403: College pane backdrop normalization.  The existing College locator
         // already marks only the "Off to College" section.  Match its full-width
         // structural backdrop(s) to the actual app/body background instead of imposing
         // a separate darker pane shade.  No product/image/filter/text paint is changed.
         "window.__AD_COLLEGEBG403__=function(){try{if(window.__ADFRAME_MODE__||!document.body)return 0;function bg403(){var A=[document.body,document.documentElement];for(var z=0;z<A.length;z++){if(!A[z])continue;var c=String(getComputedStyle(A[z]).backgroundColor||'').replace(/\\s+/g,'');if(c&&c!=='transparent'&&c!=='rgba(0,0,0,0)')return c;}return 'rgb(24,26,27)';}var bg=bg403(),C=document.querySelectorAll('[data-ad-college-section=\"1\"]'),n=0,fill=0;for(var i=0;i<C.length&&i<8;i++){var s=C[i],sr=s.getBoundingClientRect();s.style.setProperty('--ad-college-bg403',bg);s.setAttribute('data-ad-college-bg403','1');s.style.setProperty('background-color',bg,'important');n++;var K=s.querySelectorAll('div,section,article,ul,ol');for(var j=0;j<K.length&&j<180;j++){var e=K[j],r=e.getBoundingClientRect();if(sr.width<120||sr.height<80||r.width<sr.width*.88||r.height<sr.height*.42)continue;if(r.width*r.height<sr.width*sr.height*.38)continue;var cs=getComputedStyle(e),bi=String(cs.backgroundImage||'none'),bc=String(cs.backgroundColor||'').replace(/\\s+/g,'');if(bi.indexOf('url(')>=0||!bc||bc==='transparent'||bc==='rgba(0,0,0,0)')continue;e.style.setProperty('--ad-college-bg403',bg);e.setAttribute('data-ad-college-bg403','1');e.style.setProperty('background-color',bg,'important');fill++;}}window.__AD_COLLEGEBG403_STATE__='section='+n+' fill='+fill+' bg='+bg;return n+fill;}catch(e){window.__AD_COLLEGEBG403_STATE__='err '+(e&&e.message||e);return -1;}};"
         "try{if(document&&!document.getElementById('adcollege403')){var c403=document.createElement('style');c403.id='adcollege403';c403.textContent='[data-ad-college-bg403=\"1\"]{background-color:var(--ad-college-bg403,#181a1b) !important;}[data-ad-college-bg403=\"1\"]::before,[data-ad-college-bg403=\"1\"]::after{background-color:var(--ad-college-bg403,#181a1b) !important;}';(document.head||document.documentElement).appendChild(c403);}}catch(e){}"
         "try{window.__AD_COLLEGEBG403__();setTimeout(window.__AD_COLLEGEBG403__,420);setTimeout(window.__AD_COLLEGEBG403__,1250);setTimeout(window.__AD_COLLEGEBG403__,2800);if(!window.__AD_COLLEGEBG403_SCROLL__){window.__AD_COLLEGEBG403_SCROLL__=1;addEventListener('scroll',function(){clearTimeout(window.__AD_COLLEGEBG403_T__);window.__AD_COLLEGEBG403_T__=setTimeout(function(){try{window.__AD_COLLEGEBG403__();}catch(x){}},120);},{passive:true,capture:true});}}catch(e){}"
         "try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}"
         // v5.362: fast White-Tame lane. Dynamic VIDEO/IMG nodes are marked on the
         // mutation/load microtask; CSS owns the paint. This avoids waiting for the
         // expensive full contrast scanner before a newly-mounted media frame darkens.
         // v5.362: section geometry is shared by the fast and full tame lanes.
         // These Person/Hamburger/Alexa layouts put headings and artwork in sibling
         // trees, so ancestor text matching can never classify them reliably.
         // v5.363: section bands from TEXT NODES, not textContent on thousands of
         // elements. This both catches React/web layouts whose heading wrapper owns
         // extra children (the old exact-element test missed Explore/Alexa) and avoids
         // forcing layout on ~2600 candidates every 700ms.
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
         // Exact text pins that must never depend on Dark Reader's palette pass.
         // Text-node matching handles wrappers with an adjacent info glyph.
         "function _adSponsorPin366(e){try{if(!e||e.nodeType!==1)return 0;"
           "if(typeof artChk==='function'&&artChk(e))return 0;"
           "var c=String(e.style.getPropertyValue('color')||''),f=String(e.style.getPropertyValue('-webkit-text-fill-color')||'');"
           "if(c!=='#fff'&&c!=='#ffffff'&&c!=='rgb(255, 255, 255)'){"
             "e.style.setProperty('color','#fff','important');"
             "e.__adBy='sponsored366';}"
           "if(f!=='#fff'&&f!=='#ffffff'&&f!=='rgb(255, 255, 255)'){"
             "e.style.setProperty('-webkit-text-fill-color','#fff','important');"
             "e.__adBy='sponsored366';}"
           "return 1;}catch(x){return 0;}}"
         "function _adReviewInk367(e,t){try{var lo=String(t||'').toLowerCase();if(lo.indexOf('looking for specific info')===0)return true;if(lo!=='show more')return false;var p=e,d=0;while(p&&d++<7){var tx=String(p.textContent||'').replace(/\\s+/g,' ').toLowerCase();if(tx.length<1800&&(/looking for specific info|customer reviews|reviews and q&a/.test(tx)))return true;p=p.parentElement;}return false;}catch(x){return false;}}"
         "function _adTextPins363(root){try{if(!root||root.nodeType!==1||!document.createTreeWalker)return 0;var W=document.createTreeWalker(root,NodeFilter.SHOW_TEXT),nd,n=0,seen=0;while((nd=W.nextNode())&&seen++<1400){var t=String(nd.nodeValue||'').replace(/\\s+/g,' ').trim();if(!t||t.length>48)continue;var e=nd.parentElement;if(!e||/^(SCRIPT|STYLE|NOSCRIPT)$/i.test(e.tagName))continue;var r=e.getBoundingClientRect();if(r.width<12||r.height<5)continue;"
           "if(t.toLowerCase()==='you might like'&&r.width>=70&&r.width<=320){e.setAttribute('data-ad-yml-head363','1');e.__adBy='yml363';n++;continue;}"
           "if(_adReviewInk367(e,t)){e.setAttribute('data-ad-reviewink367','1');e.style.setProperty('color','#e8e6e3','important');e.style.setProperty('-webkit-text-fill-color','#e8e6e3','important');e.__adBy='reviewInk367';n++;continue;}"
           "if(/^sponsored(?: ad)?$/i.test(t)&&r.width>=28&&r.width<=260&&r.height<=48){e.setAttribute('data-ad-sponsored-light363','1');_adSponsorPin366(e);n++;}}window.__AD_TEXTPINS363__=n;return n;}catch(e){return 0;}}"
         "try{window._adTextPins363=_adTextPins363;_adTextPins363(document.documentElement);}catch(e){}"
         // v5.367: normalize only sponsored product/search cards with an Add-to-cart action.
         "function _adProductAds367(root){try{if(!root||root.nodeType!==1||!document.createTreeWalker)return 0;var W=document.createTreeWalker(root,NodeFilter.SHOW_TEXT),nd,n=0,seen=0;while((nd=W.nextNode())&&seen++<1200){var t=String(nd.nodeValue||'').replace(/\\s+/g,' ').trim();if(!/^sponsored(?: ad)?$/i.test(t))continue;var lab=nd.parentElement;if(!lab)continue;var card=lab,p=0;while(card&&p++<9){var rr=card.getBoundingClientRect(),tx=String(card.textContent||'').replace(/\\s+/g,' ').toLowerCase(),cc=card.className;cc=String(cc&&cc.baseVal!==undefined?cc.baseVal:(cc||''));if(rr.width>=270&&rr.height>=150&&rr.height<=950&&card.querySelector&&card.querySelector('img')&&(tx.indexOf('add to cart')>=0||/puis|s-result|search-result|product-card|product-grid/i.test(cc)))break;card=card.parentElement;}if(!card||p>9)continue;if(card.closest&&card.closest('[class*=ape-placement],[class*=ape-wrapper],[data-cel-widget*=ape]'))continue;var cr=card.getBoundingClientRect();if(cr.width<270||cr.height<150||cr.height>950)continue;card.setAttribute('data-ad-productad367','1');card.setAttribute('data-ad-cardborder','1');card.setAttribute('data-ad-border-section','product-ad367');card.style.setProperty('background-color','#181a1b','important');card.style.setProperty('border-color','#3b4043','important');card.style.setProperty('outline-color','#3b4043','important');if(card.hasAttribute('data-ad-tame-bgfast364')){card.removeAttribute('data-ad-tame-bgfast364');card.style.removeProperty('background-blend-mode');}card.__adBy='productAd367';_adSponsorPin366(lab);var T=card.querySelectorAll('span,p,h1,h2,h3,h4,h5,a,div');for(var i=0;i<T.length&&i<260;i++){var e=T[i];if(e.children&&e.children.length>4)continue;var own='';for(var q=0;q<e.childNodes.length&&q<8;q++){var cn=e.childNodes[q];if(cn.nodeType===3)own+=String(cn.nodeValue||'');}if(!own.trim())continue;var cs=getComputedStyle(e),m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)/.exec(String(cs.color||''));if(!m)continue;var R=+m[1],G=+m[2],B=+m[3],mx=Math.max(R,G,B),mn=Math.min(R,G,B),lum=(0.2126*R+0.7152*G+0.0722*B)/255;if(lum<0.48&&(mx-mn)<34){e.style.setProperty('color','#e8e6e3','important');e.style.setProperty('-webkit-text-fill-color','#e8e6e3','important');}}var I=card.querySelectorAll('img');for(var ii=0;ii<I.length&&ii<16;ii++)_adTameFast362(I[ii]);n++;}window.__AD_PRODUCTADS367__=n;return n;}catch(e){return 0;}}"

         // v5.371: compact Sponsored strips can remain a short standalone iframe or
         // render directly in the product page, so the productad-only 5.370 ink pass
         // missed the title/price in the latter case. This lane touches text only.
         "function _adCompactSponsoredInk371(root){try{if(!root||root.nodeType!==1||!document.createTreeWalker)return 0;function pc371(v){var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)/.exec(String(v||''));return m?[+m[1],+m[2],+m[3]]:null;}function bad371(v){var c=pc371(v);if(!c)return false;var r=c[0],g=c[1],b=c[2],mx=Math.max(r,g,b),mn=Math.min(r,g,b),l=(0.2126*r+0.7152*g+0.0722*b)/255;return l<0.70&&(mx-mn)/255<0.26;}var W=document.createTreeWalker(root,NodeFilter.SHOW_TEXT),nd,cards=0,ink=0,k=0;while((nd=W.nextNode())&&k++<1400){var t=String(nd.nodeValue||'').replace(/\\s+/g,' ').trim();if(!/^sponsored(?: ad)?$/i.test(t))continue;var e=nd.parentElement,best=null,d=0;while(e&&d++<6){var r=e.getBoundingClientRect(),tx=String(e.textContent||'').replace(/\\s+/g,' ').trim();if(r.width>=250&&r.height>=38&&r.height<=190&&tx.length>5&&tx.length<520&&(e.querySelector&&e.querySelector('img,picture')))best=e;e=e.parentElement;}if(!best)continue;best.setAttribute('data-ad-compactad371','1');best.__adBy='compactAd371';var T=best.querySelectorAll('span,p,a,div,h1,h2,h3,h4,h5');for(var i=0;i<T.length&&i<220;i++){var x=T[i],own='';try{for(var q=0;q<x.childNodes.length&&q<10;q++){var cn=x.childNodes[q];if(cn.nodeType===3)own+=String(cn.nodeValue||'');}}catch(et){}if(!own.replace(/\\s+/g,' ').trim())continue;var cs=getComputedStyle(x);if(!bad371(cs.color)&&!bad371(cs.webkitTextFillColor||cs.getPropertyValue('-webkit-text-fill-color')))continue;x.style.setProperty('color','#e8e6e3','important');x.style.setProperty('-webkit-text-fill-color','#e8e6e3','important');x.setAttribute('data-ad-compactink371','1');x.__adBy='compactInk371';ink++;}cards++;}window.__AD_COMPACTCARDS371__=cards;window.__AD_COMPACTINK371__=ink;return ink;}catch(e){return 0;}}"
         // v5.378: geometry fallback for Amazon's compact ad iframes. Some 396x62/402x125
         // frames never receive the normal productDoc/referrer classification, leaving the child
         // on a generic standalone path. Compact full-width frames are ad-strip candidates unless
         // they identify as video/player/captcha; mark and post productad so the child text lock runs.
         "function _adForceCompactStrip378(root){try{if(!root||root.nodeType!==1)return 0;var F=[];if(String(root.tagName||'').toUpperCase()==='IFRAME')F=[root];else if(root.querySelectorAll)F=root.querySelectorAll('iframe');var n=0;for(var i=0;i<F.length&&i<120;i++){var f=F[i],r=f.getBoundingClientRect();if(r.width<280||r.width>520||r.height<50||r.height>165)continue;var sig=(String(f.getAttribute('src')||'')+' '+String(f.getAttribute('title')||'')+' '+String(f.getAttribute('name')||'')+' '+String(f.className||'')).toLowerCase();if(/youtube|video|player|captcha|challenge|map|payment/.test(sig))continue;var near=false,p=f,d=0;while(p&&d++<5){var tx=String(p.textContent||'').replace(/\\s+/g,' ').toLowerCase(),cl=String(p.className||'').toLowerCase();if(/sponsored|advertis/.test(tx)||/sponsor|advert|ape-|ad-/.test(cl)){near=true;break;}p=p.parentElement;}var pdp=!!document.querySelector('.ssf-share-trigger,#productTitle,#title_feature_div,#dp-container,#ppd');if(!pdp)continue;var exact=(r.width>=390&&r.width<=440&&r.height<=140);if(!near&&!exact)continue;if(window.__AD_MARKSTRIP374__)window.__AD_MARKSTRIP374__(f,true);f.setAttribute('data-ad-frame-mode362','productad');f.setAttribute('data-ad-frame-why369',near?'force379-dom':'force379-geom');try{f.contentWindow&&f.contentWindow.postMessage({__amzAdMode:'productad'},'*');}catch(ex){}n++;}window.__AD_FORCESTRIP379__=n;return n;}catch(e){window.__AD_FORCESTRIP379__=-1;return 0;}}"
         // v5.378: some PDP ad templates render text in the parent document beside an
         // iframe instead of inside it. Lock neutral parent-side copy to white using the
         // exact Sponsored anchor; this complements the child-frame strip lock.
         "function _adStripParentInk379(root){try{if(!root||root.nodeType!==1||!document.createTreeWalker)return 0;function pc(v){var m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/.exec(String(v||''));return m?[+m[1],+m[2],+m[3]]:null;}var W=document.createTreeWalker(root,NodeFilter.SHOW_TEXT),nd,n=0,dark=0,seen=0,cards=0;while((nd=W.nextNode())&&seen++<4200){var t=String(nd.nodeValue||'').replace(/\\s+/g,' ').trim();if(!/^sponsored(?: ad)?$/i.test(t))continue;var card=nd.parentElement,d=0,best=null;while(card&&d++<9){var r=card.getBoundingClientRect(),tx=String(card.textContent||'').replace(/\\s+/g,' ').trim();if(r.width>=260&&r.width<=540&&r.height>=32&&r.height<=235&&tx.length>0&&tx.length<1200)best=card;card=card.parentElement;}if(!best)continue;cards++;var E=best.querySelectorAll('span,p,a,div,h1,h2,h3,h4,h5,label,strong,b');for(var i=0;i<E.length&&i<700;i++){var e=E[i],own='';for(var q=0;q<e.childNodes.length&&q<14;q++){if(e.childNodes[q].nodeType===3)own+=String(e.childNodes[q].nodeValue||'');}own=own.replace(/\\s+/g,' ').trim();if(!own||own.length>320)continue;var cs=getComputedStyle(e),c=pc(cs.color);if(!c)continue;var mx=Math.max(c[0],c[1],c[2]),mn=Math.min(c[0],c[1],c[2]),sat=(mx-mn)/255;if(sat>=.30)continue;e.style.setProperty('color','#ffffff','important');e.style.setProperty('-webkit-text-fill-color','#ffffff','important');e.style.setProperty('opacity','1','important');e.style.setProperty('visibility','visible','important');e.style.setProperty('filter','none','important');e.setAttribute('data-ad-parentstripink379','1');e.__adBy='parentStripInk379';n++;var c2=pc(getComputedStyle(e).color);if(c2&&(.2126*c2[0]+.7152*c2[1]+.0722*c2[2])/255<.92)dark++;}}window.__AD_PARENTSTRIP379__='cards='+cards+' ink='+n+' dark='+dark;return n;}catch(e){window.__AD_PARENTSTRIP379__='err '+e;return 0;}}"
         "function _adBorderFast367(root){try{if(!root||root.nodeType!==1)return 0;function pc(v){var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)/.exec(String(v||''));return m?[+m[1],+m[2],+m[3]]:null;}function brown(v){var c=pc(v);if(!c)return false;var r=c[0],g=c[1],b=c[2],mx=Math.max(r,g,b),mn=Math.min(r,g,b);return r>=55&&r<=125&&g>=48&&g<=115&&b>=38&&b<=105&&(mx-mn)<=32&&r>=g-4&&g>=b-5&&(r-b)>=4;}var A=[];if(/^(DIV|LI|SECTION|ARTICLE|A)$/i.test(String(root.tagName||'')))A.push(root);try{var q=root.querySelectorAll('div,li,section,article,a');for(var i=0;i<q.length&&i<90;i++)A.push(q[i]);var tq=root.querySelectorAll('[class*=_npack-asin-card_style_asin-cont],[class*=sc-card-style]');for(var ti=0;ti<tq.length&&ti<520;ti++)A.push(tq[ti]);}catch(e){}var n=0,S=['Top','Right','Bottom','Left'],seen=[];for(var j=0;j<A.length&&j<620;j++){var e=A[j];if(seen.indexOf(e)>=0)continue;seen.push(e);var r=e.getBoundingClientRect();if(r.width<100||r.height<52)continue;var c=e.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));if(/badge|deal|prime|button|coupon|discount|alert|warning/i.test(c))continue;var known368=/_npack-asin-card_style_asin-cont|sc-card-style/i.test(c),cs=getComputedStyle(e),rad=Math.max(parseFloat(cs.borderTopLeftRadius)||0,parseFloat(cs.borderTopRightRadius)||0,parseFloat(cs.borderBottomLeftRadius)||0,parseFloat(cs.borderBottomRightRadius)||0);if(!known368&&rad<3&&!/card|tile|mosaic|window|container/i.test(c))continue;var hit=false,paint=false;for(var k=0;k<4;k++){var sd=S[k],w=parseFloat(cs['border'+sd+'Width'])||0,st=String(cs['border'+sd+'Style']||'');if(w>=0.5&&st!=='none'&&st!=='hidden'){paint=true;if(brown(cs['border'+sd+'Color'])){hit=true;break;}}}if(!hit){var ow=parseFloat(cs.outlineWidth)||0;if(ow>=0.5){paint=true;if(brown(cs.outlineColor))hit=true;}}if(known368&&paint)hit=true;if(!hit)continue;e.setAttribute('data-ad-cardborder','1');e.setAttribute('data-ad-border-section',known368?'fast368':'fast367');e.style.setProperty('border-color','#3b4043','important');e.style.setProperty('outline-color','#3b4043','important');e.__adBy=known368?'cardborder368':'cardborder367';n++;}window.__AD_BORDERFAST367__=n;return n;}catch(e){return 0;}}"
         // v5.370: exact remaining npack/sc + mosaic wrapper card families. Do not wait for a painted
         // border or final layout dimensions; pin all four side colours as soon as the
         // recycled card exists, and normalize a brown box-shadow if that is the painter.
         "function _adExactBorder370(root){try{if(!root||root.nodeType!==1)return 0;function pc369(v){var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)/.exec(String(v||''));return m?[+m[1],+m[2],+m[3]]:null;}function br369(v){var c=pc369(v);if(!c)return false;var r=c[0],g=c[1],b=c[2],mx=Math.max(r,g,b),mn=Math.min(r,g,b);return r>=55&&r<=125&&g>=48&&g<=115&&b>=38&&b<=105&&(mx-mn)<=32&&r>=g-4&&g>=b-5&&(r-b)>=4;}var A=[];try{if(root.matches&&root.matches('[class*=\"_npack-asin-card_style_asin-cont\"],[class*=\"sc-card-style\"],[class*=\"_hp-mosaic-container_style_widgetContainer\"],[class*=\"_mosaic-container_style_widgetContainer\"]'))A.push(root);var q=root.querySelectorAll?root.querySelectorAll('[class*=\"_npack-asin-card_style_asin-cont\"],[class*=\"sc-card-style\"],[class*=\"_hp-mosaic-container_style_widgetContainer\"],[class*=\"_mosaic-container_style_widgetContainer\"]'):[];for(var i=0;i<q.length&&i<720;i++)A.push(q[i]);}catch(eq){}var n=0,seen=[];for(var j=0;j<A.length&&j<740;j++){var e=A[j];if(seen.indexOf(e)>=0)continue;seen.push(e);var lk369=(e.getAttribute&&e.getAttribute('data-ad-border-section')==='exact370'&&e.style.getPropertyValue('border-top-color')==='#3b4043'&&e.style.getPropertyValue('border-right-color')==='#3b4043'&&e.style.getPropertyValue('border-bottom-color')==='#3b4043'&&e.style.getPropertyValue('border-left-color')==='#3b4043'&&e.style.getPropertyPriority('border-top-color')==='important');if(lk369)continue;e.setAttribute('data-ad-cardborder','1');e.setAttribute('data-ad-border-section','exact370');e.style.setProperty('border-top-color','#3b4043','important');e.style.setProperty('border-right-color','#3b4043','important');e.style.setProperty('border-bottom-color','#3b4043','important');e.style.setProperty('border-left-color','#3b4043','important');e.style.setProperty('outline-color','#3b4043','important');try{var cs=getComputedStyle(e),bs=String(cs.boxShadow||'');if(bs&&bs!=='none'){var nb=bs.replace(/rgba?\\([^)]*\\)/g,function(z){return br369(z)?'rgb(59, 64, 67)':z;});if(nb!==bs)e.style.setProperty('box-shadow',nb,'important');}}catch(eb){}e.__adBy='cardborder370';n++;}window.__AD_BORDEREXACT370__=n;return n;}catch(e){return 0;}}"

         // v5.371: mosaic wrappers were still being starved by the shared exact370
         // query budget after long Home feeds accumulated hundreds of npack cards.
         // Give the outer mosaic family its own pass and rerun it on scroll so newly
         // recycled "For you / Deals" frames cannot remain at Amazon's brown border.
         "function _adMosaicBorder371(root){try{if(!root||root.nodeType!==1)return 0;var SEL='[class*=\"_hp-mosaic-container_style_widgetContainer\"],[class*=\"_mosaic-container_style_widgetContainer\"]',A=[];try{if(root.matches&&root.matches(SEL))A.push(root);var q=root.querySelectorAll?root.querySelectorAll(SEL):[];for(var i=0;i<q.length;i++)A.push(q[i]);}catch(eq){}var n=0;for(var j=0;j<A.length;j++){var e=A[j];if(!e||!e.style)continue;var locked=(e.getAttribute&&e.getAttribute('data-ad-border-section')==='exact371'&&e.style.getPropertyValue('border-top-color')==='#3b4043'&&e.style.getPropertyValue('border-right-color')==='#3b4043'&&e.style.getPropertyValue('border-bottom-color')==='#3b4043'&&e.style.getPropertyValue('border-left-color')==='#3b4043'&&e.style.getPropertyPriority('border-top-color')==='important');if(locked)continue;e.setAttribute('data-ad-cardborder','1');e.setAttribute('data-ad-border-section','exact371');e.style.setProperty('border-top-color','#3b4043','important');e.style.setProperty('border-right-color','#3b4043','important');e.style.setProperty('border-bottom-color','#3b4043','important');e.style.setProperty('border-left-color','#3b4043','important');e.style.setProperty('outline-color','#3b4043','important');e.__adBy='cardborder371';n++;}window.__AD_MOSAIC371__=n;return n;}catch(e){return 0;}}"
         "try{window._adProductAds367=_adProductAds367;window._adCompactSponsoredInk371=_adCompactSponsoredInk371;window._adForceCompactStrip378=_adForceCompactStrip378;window._adStripParentInk379=_adStripParentInk379;window._adBorderFast367=_adBorderFast367;window._adExactBorder370=_adExactBorder370;window._adMosaicBorder371=_adMosaicBorder371;_adProductAds367(document.documentElement);_adCompactSponsoredInk371(document.documentElement);_adForceCompactStrip378(document.documentElement);_adStripParentInk379(document.documentElement);_adBorderFast367(document.documentElement);_adExactBorder370(document.documentElement);_adMosaicBorder371(document.documentElement);setTimeout(function(){try{_adExactBorder370(document.documentElement);_adMosaicBorder371(document.documentElement);}catch(e){}},120);setTimeout(function(){try{_adExactBorder370(document.documentElement);_adMosaicBorder371(document.documentElement);}catch(e){}},650);setTimeout(function(){try{_adExactBorder370(document.documentElement);_adMosaicBorder371(document.documentElement);}catch(e){}},1800);}catch(e){}"
         "try{if(!window.__ADMB371INIT__){window.__ADMB371INIT__=1;var _mb371raf=0;addEventListener('scroll',function(){if(_mb371raf)return;_mb371raf=1;var f=function(){_mb371raf=0;try{_adMosaicBorder371(document.documentElement);}catch(e){}};if(window.requestAnimationFrame)requestAnimationFrame(f);else setTimeout(f,0);},{passive:true,capture:true});addEventListener('pageshow',function(){try{_adMosaicBorder371(document.documentElement);}catch(e){}},{passive:true});}}catch(e){}"
         "try{if(!window.__ADPS378INIT__){window.__ADPS378INIT__=1;var _ps378=0;addEventListener('scroll',function(){clearTimeout(_ps378);_ps378=setTimeout(function(){try{_adForceCompactStrip378(document.documentElement);_adStripParentInk379(document.documentElement);}catch(e){}},90);},{passive:true,capture:true});addEventListener('pageshow',function(){try{_adForceCompactStrip378(document.documentElement);_adStripParentInk379(document.documentElement);}catch(e){}},{passive:true});}}catch(e){}"
         // Restore the stock black circular backing for top-carousel play/pause controls.
         // If the player lives in the child ad frame its own path handles it; this is
         // the main-document overlay case shown in the 5.361 screenshot.
         "function _adVideoCtlMain362(){try{var V=document.querySelectorAll('video'),n=0;for(var vi=0;vi<V.length&&vi<32;vi++){var v=V[vi],vr=v.getBoundingClientRect();if(vr.width<120||vr.height<80)continue;"
           "var host=v,pd=0;while(host.parentElement&&pd++<4){var hr=host.parentElement.getBoundingClientRect();if(hr.width<=vr.width*1.55&&hr.height<=vr.height*1.65)host=host.parentElement;else break;}"
           "var A=host.querySelectorAll?host.querySelectorAll('button,[role=button],svg,i'):[];for(var ai=0;ai<A.length&&ai<160;ai++){var e=A[ai],r=e.getBoundingClientRect();if(r.width<10||r.width>64||r.height<10||r.height>64)continue;var cx=r.left+r.width/2,cy=r.top+r.height/2;if(cx<vr.left-12||cx>vr.right+12||cy<vr.top+vr.height*.42||cy>vr.bottom+20)continue;"
             "var c=e.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));var lab=String((e.getAttribute&&e.getAttribute('aria-label'))||(e.getAttribute&&e.getAttribute('title'))||'');var sem=/play|pause/i.test(c+' '+lab),left=cx<vr.left+Math.max(100,vr.width*.30);if(!sem&&!left)continue;"
             "var p=e,up=0;while(p.parentElement&&up++<2){var pr=p.parentElement.getBoundingClientRect();if(pr.width>=18&&pr.width<=64&&pr.height>=18&&pr.height<=64)p=p.parentElement;else break;}p.setAttribute('data-ad-videoctl362','1');p.__adBy='videoCtlMain362';n++;}}window.__AD_VIDEOCTL_MAIN362__=n;return n;}catch(e){return 0;}}"
         "try{window._adVideoCtlMain362=_adVideoCtlMain362;_adVideoCtlMain362();}catch(e){}"
         // v5.391: Home carousel video-ad playback rescue. This is deliberately
         // independent of product-control chrome and does not alter layout, poster,
         // opacity, pointer-events or media filters. It only re-issues play() for
         // visible Home ad videos that Amazon already declares muted/autoplay-capable.
         "function _adHomeVideo391(){try{if(window.__ADFRAME_MODE__||!document.body)return 0;var HS=document.querySelectorAll('[class*=\"_hp-mosaic-container_style_widgetContainer\"],[class*=\"_mosaic-container_style_widgetContainer\"],[class*=\"gwm-dashboard-container\"],[class*=\"gwm-window-layout\"],[class*=\"gwm-asin-tile\"]');if(HS.length<2){window.__AD_HOMEVIDEO391__='home=0';return 0;}if(document.querySelector('#search,.s-search-results,[data-component-type=\"s-search-result\"],#productTitle,#dp-container,#ppd')){window.__AD_HOMEVIDEO391__='home=0 product=1';return 0;}var V=document.querySelectorAll('video'),seen=0,inview=0,eligible=0,attempt=0,playing=0,reject=0,waiting=0,H=innerHeight||900,W=innerWidth||390;function cls(e){var c=e&&e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||''));}function adctx(v){var p=v,u=0,t=cls(v);while(p&&u++<7){t+=' '+cls(p)+' '+String(p.id||'');if(/single-video-card|video-card|sbv-video|vjs-tech|sponsored|advert|ad[-_]|ape[-_]|creative|theming-card/i.test(t))return true;p=p.parentElement;}return false;}function hook(v){if(v.__adHV391)return;v.__adHV391=1;var f=function(){try{setTimeout(_adHomeVideo391,40);}catch(e){}};v.addEventListener('loadeddata',f,{passive:true});v.addEventListener('canplay',f,{passive:true});v.addEventListener('emptied',f,{passive:true});}for(var i=0;i<V.length&&i<80;i++){var v=V[i],r=v.getBoundingClientRect();if(r.width<120||r.height<70)continue;seen++;if(!adctx(v))continue;var vis=r.right>0&&r.left<W&&r.bottom>0&&r.top<H;if(!vis)continue;inview++;v.setAttribute('data-ad-homevideo391','1');v.setAttribute('playsinline','');v.setAttribute('webkit-playsinline','');try{v.playsInline=true;}catch(x){}hook(v);var canAuto=!!(v.autoplay||v.defaultMuted||v.muted||v.hasAttribute('muted'));if(!canAuto)continue;eligible++;if(!v.paused&&!v.ended){playing++;continue;}if(v.ended)continue;if(v.networkState===3){waiting++;continue;}var now=Date.now();if(v.__adHV391Try&&now-v.__adHV391Try<1000){waiting++;continue;}v.__adHV391Try=now;try{var pr=v.play();attempt++;if(pr&&typeof pr.then==='function'){pr.then(function(){try{window.__AD_HOMEVIDEO391_OK__=(window.__AD_HOMEVIDEO391_OK__||0)+1;}catch(x){}}).catch(function(){try{window.__AD_HOMEVIDEO391_REJ__=(window.__AD_HOMEVIDEO391_REJ__||0)+1;}catch(x){}});}}catch(x){reject++;}}window.__AD_HOMEVIDEO391__='seen='+seen+' inview='+inview+' eligible='+eligible+' attempt='+attempt+' playing='+playing+' waiting='+waiting+' reject='+reject+' ok='+(window.__AD_HOMEVIDEO391_OK__||0)+' preject='+(window.__AD_HOMEVIDEO391_REJ__||0);return attempt+playing;}catch(e){window.__AD_HOMEVIDEO391__='err '+(e&&e.message||e);return 0;}}"
         "try{window._adHomeVideo391=_adHomeVideo391;_adHomeVideo391();if(!window.__ADHV391INIT__){window.__ADHV391INIT__=1;var hvT=0;var hvRun=function(){clearTimeout(hvT);hvT=setTimeout(function(){try{_adHomeVideo391();}catch(e){}},120);};addEventListener('scroll',hvRun,{passive:true,capture:true});addEventListener('pageshow',hvRun,{passive:true});document.addEventListener('visibilitychange',function(){if(!document.hidden)hvRun();},{passive:true});}}catch(e){}"
         // v5.393: HOME VIDEO-CAROUSEL AMBIENT BACKDROP. The supplied recording
         // shows the saturated blue lane is an ancestor of the 299x478 vjs-tech card.
         // Previous generic Home classifiers missed/protected it. Anchor to the actual
         // ad-video DOM, skip the 299px creative itself, and neutralize only full-width
         // saturated ancestor paint. No video attributes/playback/filter/layout writes.
                  "function _adHomeMedia395(){try{if(window.__ADFRAME_MODE__||!document.body||!window.__ADTAME_ON__)return 0;if(document.querySelector('#search,.s-search-results,[data-component-type=\"s-search-result\"],#productTitle,#dp-container,#ppd')){window.__AD_HOMEMEDIA395__='home=0 product=1';return 0;}var S=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),bb=(1-0.50*(S/100)).toFixed(3),E=document.querySelectorAll('img[class*=\"_single-creative-card\"],img[class*=\"_single-video-card\"],[class*=\"single-creative-card\"] img,[class*=\"single-video-card\"] img,video.vjs-tech,[class*=\"single-video-card\"] video,[class*=\"theming-card-background\"],.vjs-poster,[class*=\"vjs-poster\"]'),media=0,bg=0,uncovered=0,hazard=0;for(var i=0;i<E.length&&i<240;i++){var e=E[i],r=e.getBoundingClientRect(),tg=String(e.tagName||'').toUpperCase();if(r.width<100||r.height<70)continue;if(tg==='DIV'||tg==='SECTION'||tg==='SPAN'){if(!_adHomeBgLeaf395(e))continue;bg++;var cs=getComputedStyle(e);if(String(cs.filter||'none')!=='none'||String(cs.backgroundBlendMode||'normal').indexOf('multiply')>=0)hazard++;if(!e.hasAttribute('data-ad-homebg395'))uncovered++;continue;}if(tg!=='IMG'&&tg!=='VIDEO'&&tg!=='CANVAS')continue;var want='brightness('+bb+') saturate(1.08)';e.setAttribute('data-ad-tame-fast362','1');e.setAttribute('data-ad-homemedia395','1');if(String(e.style.getPropertyValue('filter')||'')!==want||e.style.getPropertyPriority('filter')!=='important')e.style.setProperty('filter',want,'important');e.__adTamed=1;e.__adTameSig='HM395|'+String(e.currentSrc||e.src||e.poster||'');e.__adBy='homeMedia395';media++;if(String(getComputedStyle(e).filter||'').indexOf('brightness')<0)uncovered++;}window.__AD_HOMEMEDIA395__='media='+media+' bg='+bg+' uncovered='+uncovered+' hazard='+hazard;return media+bg;}catch(e){window.__AD_HOMEMEDIA395__='err '+(e&&e.message||e);return 0;}}"
         "window._adHomeMedia395=_adHomeMedia395;"
         "try{_adHomeMedia395();_adStandaloneSweep395();setTimeout(_adHomeMedia395,120);setTimeout(_adHomeMedia395,420);setTimeout(_adHomeMedia395,1100);setTimeout(_adStandaloneSweep395,180);setTimeout(_adStandaloneSweep395,700);setTimeout(_adStandaloneSweep395,1500);if(!window.__ADHOMEP395INIT__){window.__ADHOMEP395INIT__=1;var hp395=0;addEventListener('scroll',function(){if(hp395)return;hp395=1;var f=function(){hp395=0;try{_adHomeMedia395();_adStandaloneSweep395();}catch(e){}};if(requestAnimationFrame)requestAnimationFrame(f);else setTimeout(f,0);},{passive:true,capture:true});addEventListener('pageshow',function(){try{_adHomeMedia395();_adStandaloneSweep395();}catch(e){}},{passive:true});}}catch(e){}"
         // v5.359: the 5.358 device probe finally identified the College painters as
         // edge SVGs. The full contrast pass intentionally does not run while scrolling,
         // which is why those SVGs were visible black until the trailing pass/heartbeat.
         // This tiny dedicated path runs on the mutation microtask and a rAF-throttled
         // scroll listener, so the data attribute is present before the next paint.
         // It only marks small SVGs at the extreme screen edges in the narrow band
         // immediately under the exact "Off to College" heading; CSS still owns paint.
         "function _adCollegeFast59(){try{"
           "var H=window.__AD_COLLEGE_H59__;"
           "if(!H||!H.isConnected){H=null;var Q=document.querySelectorAll('h1,h2,h3,h4,span,div');"
             "for(var i59=0;i59<Q.length&&i59<3500;i59++){var q59=Q[i59];if(q59.children&&q59.children.length>5)continue;"
               "var t59=String(q59.textContent||'').replace(/\\s+/g,' ').trim().toLowerCase();if(t59==='off to college'){H=q59;window.__AD_COLLEGE_H59__=q59;break;}}}"
           "if(!H)return 0;var hr59=H.getBoundingClientRect(),vh59=window.innerHeight||900,vw59=window.innerWidth||390;"
           "if(hr59.bottom<-160||hr59.top>vh59+160)return 0;var y059=hr59.bottom-18,y159=hr59.bottom+120,V59=document.querySelectorAll('svg'),n59=0;"
           "for(var v59=0;v59<V59.length&&v59<1200;v59++){var e59=V59[v59],r59=e59.getBoundingClientRect(),cx59=r59.left+r59.width/2,cy59=r59.top+r59.height/2;"
             "if(r59.width<3||r59.width>96||r59.height<3||r59.height>96||cy59<y059||cy59>y159||(cx59>100&&cx59<vw59-100))continue;"
             "var c59=e59.className;c59=String(c59&&c59.baseVal!==undefined?c59.baseVal:(c59||''));if(/star|prime|logo|heart|wish|rating|badge|product|photo/i.test(c59))continue;"
             "e59.setAttribute('data-ad-college-chevron','1');e59.setAttribute('data-ad-college-chevron-sprite','1');e59.setAttribute('data-ad-college-chevron-why','fast59');e59.__adGlyph=1;e59.__adBy='collegeFast59';n59++;}"
           "window.__AD_COLLEGE_FAST59_N__=n59;return n59;}catch(e){return 0;}}"
         "window.__AD_COLLEGE_FAST59__=_adCollegeFast59;"
         "try{_adCollegeFast59();}catch(e){}"
         "try{if(!window.__ADCF59INIT__){window.__ADCF59INIT__=1;var _cf59raf=0;"
           "addEventListener('scroll',function(){if(_cf59raf)return;_cf59raf=1;"
             "var f59=function(){_cf59raf=0;try{_adCollegeFast59();}catch(e){}};"
             "if(window.requestAnimationFrame)requestAnimationFrame(f59);else setTimeout(f59,0);"
           "},{passive:true,capture:true});}}catch(e){}"
         "function _adPin(root){try{"
           "if(!root||root.nodeType!==1)return;"
           "var list=[root];"
           "try{var q=root.querySelectorAll('span,div,p,a,h1,h2,h3,h4');"
             "for(var i2=0;i2<q.length&&i2<80;i2++)list.push(q[i2]);}catch(e){}"
           "for(var j2=0;j2<list.length;j2++){var el2=list[j2];"
             "if(el2.__adPinned)continue;"
             "var txt='';"
             "for(var c2=0;c2<el2.childNodes.length&&c2<4;c2++){"
               "var nd=el2.childNodes[c2];"
               "if(nd.nodeType===3&&nd.nodeValue&&nd.nodeValue.trim())txt+=nd.nodeValue;}"
             "if(!txt.trim())continue;"
             // on a creative? the artwork lives on an ancestor, not the caption
             "var an=el2.parentElement,d2=0,onart=false;"
             "while(an&&d2++<4){var acs=getComputedStyle(an);"
               "if((acs.backgroundImage||'').indexOf('url(')>=0){"
                 "var ar=an.getBoundingClientRect();"
                 "if(ar.width>200&&ar.height>80){onart=true;break;}}"
               "an=an.parentElement;}"
             "if(!onart)continue;"
             "el2.__adPinned=1;"
             // mark the creative container; the stylesheet does the rest
             "var mk=el2.parentElement,md=0;"
             "while(mk&&md++<4){if(_adMark(mk))break;mk=mk.parentElement;}"
             "window.__AD_PIN__=(window.__AD_PIN__||0)+1;}"
         "}catch(e){}}"
         // v5.363 PERFORMANCE: mutations only run the tiny marker lanes synchronously.
         // The ~50ms full contrast/tame sweep runs once after the DOM settles instead
         // of every ~220-400ms throughout lazy-loading/scrolling.
         "try{var _t=null;new MutationObserver(function(muts){var structural=0;"
           "try{for(var m2=0;m2<muts.length&&m2<40;m2++){var mm2=muts[m2];if(mm2.type==='attributes'){if(mm2.target){_adTameFast362(mm2.target);_adBorderFast367(mm2.target);_adExactBorder370(mm2.target);_adMosaicBorder371(mm2.target);if(mm2.target.hasAttribute&&mm2.target.hasAttribute('data-ad-sponsored-light363'))_adSponsorPin366(mm2.target);if(mm2.target.hasAttribute&&mm2.target.hasAttribute('data-ad-reviewink367')){mm2.target.style.setProperty('color','#e8e6e3','important');mm2.target.style.setProperty('-webkit-text-fill-color','#e8e6e3','important');}}continue;}structural=1;var ad=mm2.addedNodes;for(var a2=0;a2<ad.length&&a2<20;a2++){_adPin(ad[a2]);_adTameFast362(ad[a2]);_adTextPins363(ad[a2]);if(ad[a2]&&ad[a2].nodeType===1){var tx367=String(ad[a2].textContent||'');_adForceCompactStrip378(ad[a2]);if(tx367.length<7000&&/sponsored/i.test(tx367)){_adProductAds367(ad[a2]);_adCompactSponsoredInk371(ad[a2]);_adStripParentInk379(ad[a2]);}_adBorderFast367(ad[a2]);_adExactBorder370(ad[a2]);_adMosaicBorder371(ad[a2]);}}try{_adVideoCtlMain362();}catch(e){}}}catch(e){}"
           "try{_adCollegeFast59();}catch(e){}try{if(structural&&window._adHomeVideo391)_adHomeVideo391();}catch(e){}try{if(structural&&window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}if(structural){clearTimeout(_t);_t=setTimeout(function(){try{if(!document.hidden&&!window.__ADSCROLLING__)window.__AMZDARK_FIXCONTRAST__();}catch(e){}},1900);}})"
           ".observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['src','srcset','poster','class','style']});}catch(e){}"
         "try{if(window._adHomeMedia395)_adHomeMedia395();}catch(e){}try{if(window._adStandaloneSweep395)_adStandaloneSweep395();}catch(e){}"
         // One late backstop only. The old six 8-second full scans could collide with
         // Home's own renderer long after the page was already stable.
         "try{if(!window.__AMZDARK_HB__){window.__AMZDARK_HB__=1;setTimeout(function(){try{if(!document.hidden&&!window.__ADSCROLLING__)window.__AMZDARK_FIXCONTRAST__();}catch(e){}},12000);}}catch(e){}"
         "window.__AMZDARK_APPLY__();"
         // Fast early passes so promo text / buttons are corrected before the
         // eye registers Dark Reader's first-paint colours. One-shot, bounded.
         "try{setTimeout(function(){try{window.__AMZDARK_FIXCONTRAST__();}catch(e){}},350);}catch(e){}"
         // Re-apply when the page is restored from the back-forward cache (returning
         // to a tab). pageshow.persisted is true exactly in that case, and it is the
         // event that fires when no navigation happens — the cart's "went white on
         // return" path. Also re-assert on visibility regain.
         "try{window.addEventListener('pageshow',function(e){if(e.persisted)window.__AMZDARK_APPLY__();});}catch(e){}"
         "try{document.addEventListener('visibilitychange',function(){if(!document.hidden)window.__AMZDARK_APPLY__();});}catch(e){}"
         "}}catch(e){}})();",
        dr, [NSString stringWithUTF8String:gP.fgHex], ADThemeLiteral(), ADFixesLiteral()];
    return [NSString stringWithFormat:
            @"try{window.__ADTAME_ON__=%d;window.__ADTAME_S__=%ld;}catch(e){}\n%@",
            gP.whiteTame ? 1 : 0, (long)gP.whiteTameStrength, adBody];
}
// Force-dark pass for the Pharmacy surface. Deliberately ungated -- on this pane
// every light background is wrong -- with artwork excluded by tag rather than by
// heuristic, and same-origin child frames walked explicitly, since
// evaluateJavaScript reaches the main frame only.
static NSString *ADPharmForceJS(void){
    return 
                                  @"(function(){try{"
           // AMIConfigurableWebViewController is generic -- Amazon uses it for ad
           // landing pages too. Identify the surface from the document before
           // rewriting every colour on it, or an ad page ends up blank.
           "var hh9=(location&&location.href)?location.href.toLowerCase():'';"
           "var tt9=(document.title||'').toLowerCase();"
           "var isPharm=(hh9.indexOf('pharmacy')>=0||hh9.indexOf('/rx')>=0"
             "||tt9.indexOf('pharmacy')>=0||tt9.indexOf('prescription')>=0);"
           "if(!isPharm)return 'skip not-pharmacy '+hh9.slice(0,40);"
           "var n=0,t=0;"
                                   "function L(c){try{var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)(?:,\\s*([0-9.]+))?\\)/.exec(c||'');"
                                     "if(!m)return null;if(m[4]!==undefined&&parseFloat(m[4])<0.15)return null;"
                                     "return (0.2126*+m[1]+0.7152*+m[2]+0.0722*+m[3])/255;}catch(e){return null;}}"
                                   "var A=document.querySelectorAll('*');"
                                   "for(var i=0;i<A.length&&i<4000;i++){var e=A[i];"
                                     "var tg=e.tagName.toLowerCase();"
                                     "if(tg==='img'||tg==='svg'||tg==='video'||tg==='canvas')continue;"
                                     "var cs=getComputedStyle(e);"
                                     "if((cs.backgroundImage||'').indexOf('url(')>=0)continue;"
                                     // ON A CREATIVE? This skipped elements carrying artwork
                                     // THEMSELVES, but a caption sitting on an ad creative has no
                                     // background-image of its own -- the artwork is on a parent --
                                     // so it sailed through and got painted #181a1b. That is the
                                     // black box behind ad-card text. Only creative-sized artwork
                                     // counts, so a small background icon still darkens normally.
                                     "var anc=e.parentElement,ad2=0,onart=false;"
                                     "while(anc&&ad2++<4){"
                                       "var acs=getComputedStyle(anc);"
                                       "if((acs.backgroundImage||'').indexOf('url(')>=0){"
                                         "var arr=anc.getBoundingClientRect();"
                                         "if(arr.width>200&&arr.height>80){onart=true;break;}}"
                                       "anc=anc.parentElement;}"
                                     "if(onart)continue;"
                                     "var bt=String(e.textContent||'').trim();""var isBadge=(bt.length>0&&bt.length<16&&(bt.indexOf('%')>=0||bt.indexOf('$')>=0||/off|deal|save|coupon/i.test(bt)));""if(isBadge){var bp=e.parentElement,bd=0,nearImg=false;""while(bp&&bd++<4){if(bp.querySelector&&bp.querySelector('img,picture')){nearImg=true;break;}bp=bp.parentElement;}""if(nearImg)continue;}"   /* BADGEOVERIMG */
                                     "var bl=L(cs.backgroundColor);"
                                     "if(bl!==null&&bl>0.5){e.style.setProperty('background-color','#181a1b','important');"
                                       "e.__adBgBy='reapply';n++;}"
                                     "var tl2=L(cs.color);"
                                     "if(tl2!==null&&tl2<0.35){e.style.setProperty('color','#e8e6e3','important');t++;}}"
                                   "try{document.documentElement.style.setProperty('background-color','#181a1b','important');"
                                       "document.body.style.setProperty('background-color','#181a1b','important');}catch(e){}"
                   "var fr=0,fd=0;try{var IF=document.querySelectorAll('iframe');fr=IF.length;"
                     "for(var q=0;q<IF.length&&q<12;q++){var d2=null;"
                       // Door 2, and the one that made the element guards pointless:
                       // this walks OUT of the top frame and into each child document,
                       // so skipping the engine inside an ad frame achieved nothing
                       // while this kept reaching in and repainting it from outside.
                       // NO PATTERN MATCH. The child frame is served as a hashed
                       // filename (7D0tCs28FCA1nV9.html), so matching on adsystem,
                       // creative, sspa and friends was never going to catch it -- the
                       // same guessing that has cost most of this hunt.
                       //
                       // A frame the host page embeds is content we did not lay out and
                       // cannot reason about, and the instruction is that ad cards stay
                       // stock. So the top frame no longer reaches into ANY child
                       // document. The src is logged so we learn what these frames
                       // actually are instead of inferring it.
                       "try{var fsrc=String(IF[q].src||IF[q].getAttribute('src')||'(none)');"
                         "if(!window.__AD_FRSRC__)window.__AD_FRSRC__=fsrc.slice(-40);"
                         "window.__AD_FRSKIP__=(window.__AD_FRSKIP__||0)+1;continue;"
                       "}catch(e){}"
                       "try{d2=IF[q].contentDocument;}catch(e){d2=null;}"
                       "if(!d2||!d2.body)continue;"
                       // An ad document can also be recognised from the inside, which
                       // covers srcdoc and about:blank frames that have no useful src.
                       "try{if(d2.defaultView&&d2.defaultView.__ADFRAMESKIP__){"
                         "window.__AD_FRSKIP__=(window.__AD_FRSKIP__||0)+1;continue;}"
                       "}catch(e){}"
                       "fd++;"
                       "var B=d2.querySelectorAll('*');"
                       "for(var k=0;k<B.length&&k<3000;k++){var e2=B[k];"
                         "var g2=e2.tagName.toLowerCase();"
                         "if(g2==='img'||g2==='svg'||g2==='video'||g2==='canvas')continue;"
                         "var c2=d2.defaultView.getComputedStyle(e2);"
                         "if((c2.backgroundImage||'').indexOf('url(')>=0)continue;"
                         // ON A CREATIVE? This skipped elements carrying artwork
                         // THEMSELVES, but a caption sitting on an ad creative has no
                         // background-image of its own -- the artwork is on a parent --
                         // so it sailed through and got painted #181a1b. That is the
                         // black box behind ad-card text, and the ad cards are iframe
                         // content, which is why this is the write that reaches them.
                         // Only creative-sized artwork counts, so a small background
                         // icon still darkens normally.
                         "var oa3=false,an3=e2.parentElement,ad5=0;"
                         "while(an3&&ad5++<5){"
                           "var ac3=d2.defaultView.getComputedStyle(an3);"
                           "if((ac3.backgroundImage||'').indexOf('url(')>=0){"
                             "var ar5=an3.getBoundingClientRect();"
                             "if(ar5.width>160&&ar5.height>60){oa3=true;break;}}"
                           "if(an3.querySelector&&an3.querySelector('img,picture,video')){"
                             "var ar6=an3.getBoundingClientRect();"
                             "if(ar6.width>160&&ar6.height>60){oa3=true;break;}}"
                           "an3=an3.parentElement;}"
                         "if(oa3){window.__AD_ADSKIP__=(window.__AD_ADSKIP__||0)+1;continue;}"
                         "var bt3=String(e2.textContent||'').trim();""var isB3=(bt3.length>0&&bt3.length<16&&(bt3.indexOf('%')>=0||bt3.indexOf('$')>=0||/off|deal|save|coupon/i.test(bt3)));""if(isB3){var b3=e2.parentElement,d3b=0,ni3=false;""while(b3&&d3b++<4){if(b3.querySelector&&b3.querySelector('img,picture')){ni3=true;break;}b3=b3.parentElement;}""if(ni3){window.__AD_ADSKIP__=(window.__AD_ADSKIP__||0)+1;continue;}}"   /* BADGEOVERIMG */
                         "var b2=L(c2.backgroundColor);"
                         "if(b2!==null&&b2>0.5){e2.style.setProperty('background-color','#181a1b','important');"
                           "e2.__adBgBy='ifrfix';n++;}"
                         "var oa2=false,an2=e2.parentElement,ad3=0;"
                         "while(an2&&ad3++<4){var ac2=d2.defaultView.getComputedStyle(an2);"
                           "if((ac2.backgroundImage||'').indexOf('url(')>=0){"
                             "var ar3=an2.getBoundingClientRect();"
                             "if(ar3.width>200&&ar3.height>80){oa2=true;break;}}"
                           "an2=an2.parentElement;}"
                         "var x2=L(c2.color);"
                         "if(x2!==null&&x2<0.35&&!oa2){e2.style.setProperty('color','#e8e6e3','important');t++;}}"
                       "try{d2.documentElement.style.setProperty('background-color','#181a1b','important');"
                           "d2.body.style.setProperty('background-color','#181a1b','important');}catch(e){}}"
                   "}catch(e){}"
                   "return 'bg='+n+' text='+t+' if='+fr+'/'+fd;}catch(e){return 'err '+e;}})()";
}

static NSString *ADDarkReaderBootstrap(void){
    __block NSString *out = nil;
    dispatch_sync(ADBootQueue(), ^{
        if (!gADBootCache) gADBootCache = ADDarkReaderBootstrapBuild();
        out = gADBootCache;
    });
    return out;
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
    NSString *raBody = [NSString stringWithFormat:
        @"(function(){try{"
         "if(!(window.DarkReader&&DarkReader.enable))return 'noDR';"
         "if(!document.querySelector('style.darkreader'))DarkReader.enable(%@,%@);"
         "if(window.__AMZDARK_FIXCONTRAST__)return ''+window.__AMZDARK_FIXCONTRAST__();"
         "return 'nofix';"
         "}catch(e){return 'err';}})();",
        ADThemeLiteral(), ADFixesLiteral()];
    return [NSString stringWithFormat:
            @"try{window.__ADTAME_ON__=%d;window.__ADTAME_S__=%ld;}catch(e){}\n%@",
            gP.whiteTame ? 1 : 0, (long)gP.whiteTameStrength, raBody];
}

static void ADBootstrapDarkReaderIn(WKWebView *wv);
static const void *kADBootedKey = &kADBootedKey;
static const void *kADUSKey = &kADUSKey;
static const void *kADEnableStampKey363 = &kADEnableStampKey363;
static int gLoadLog = 12;
// Add our documentStart engine user-script to a webview's config if it is not
// already there. Called from the load hooks so it lands BEFORE the navigation
// -- the only timing that reaches loadHTMLString/loadData content and child
// frames. Safe to call repeatedly (guarded per webview).
static void ADEnsureUserScript(WKWebView *wv){
    @try {
        if (!gP.enabled || !gP.webDarkReader || !wv) return;
        if (objc_getAssociatedObject(wv, kADUSKey)) return;
        NSString *js = ADDarkReaderBootstrap();
        Class WKUS = NSClassFromString(@"WKUserScript");
        WKUserContentController *ucc = wv.configuration.userContentController;
        if (js.length && WKUS && ucc){
            WKUserScript *us = [[WKUS alloc] initWithSource:js
                                              injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                           forMainFrameOnly:NO];
            [ucc addUserScript:us];
            objc_setAssociatedObject(wv, kADUSKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (gLoadLog > 0){ gLoadLog--;
                ADLog(@"loadhook: injected userscript into %s", object_getClassName(wv)); }
        }
    } @catch(...) {}
}
static void ADEnableDarkReaderIn(WKWebView *wv){
    if (!gP.enabled || !gP.webDarkReader || !wv) return;
    @try {
        // v5.363: appearance bursts used to call this several times inside 500ms,
        // each call doing multiple evaluateJavaScript round-trips. One re-apply per
        // 1.5s per webview is enough; documentStart owns first paint.
        CFAbsoluteTime now363=CFAbsoluteTimeGetCurrent();
        NSNumber *last363=objc_getAssociatedObject(wv,kADEnableStampKey363);
        if (last363 && now363-last363.doubleValue<1.50) return;
        objc_setAssociatedObject(wv,kADEnableStampKey363,@(now363),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

        // Report/self-heal once per URL. Re-running this second JS round-trip on every
        // appearance was diagnostic debt and contributed to Home stalls. pageshow + the
        // documentStart engine own same-URL restores; a new URL gets one health check.
        static const void *kADStateURLKey363 = &kADStateURLKey363;
        NSString *stateURL363 = wv.URL.absoluteString ?: @"(no url)";
        NSString *lastStateURL363 = objc_getAssociatedObject(wv, kADStateURLKey363);
        BOOL needState363 = !lastStateURL363 || ![lastStateURL363 isEqualToString:stateURL363];
        if (needState363) objc_setAssociatedObject(wv, kADStateURLKey363, stateURL363, OBJC_ASSOCIATION_COPY_NONATOMIC);
        if (needState363) [wv evaluateJavaScript:
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
                // Overlay diagnostic: name the elements veiling product images. Amazon blocks
                // remote DOM inspection, so the page has to tell us itself. Runs once per URL.
                if ([st containsString:@"complete"]) {
                    static NSMutableSet *ovSeen = nil;
                    if (!ovSeen) ovSeen = [NSMutableSet set];
                    if (![ovSeen containsObject:u]){
                        NSString *probe =
                          @"(function(){try{"
                           "var imgs=[].slice.call(document.querySelectorAll('img'));"
                           "var big=imgs.filter(function(i){var r=i.getBoundingClientRect();"
                             "return r.width>=80&&r.height>=80;});"
                           "if(!big.length)return 'imgs='+imgs.length+' big=0';"
                           "var out=[];"
                           "for(var n=0;n<big.length&&out.length<3;n++){var im=big[n];"
                             "var cs=getComputedStyle(im);"
                             "var r=im.getBoundingClientRect();"
                             "var top=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);"
                             "var cover='self';"
                             "if(top&&top!==im){var tcs=getComputedStyle(top);"
                               "cover=(top.tagName||'?')+'.'+String(top.className||'').slice(0,24)"
                                 "+'{bg='+tcs.backgroundColor+',bgi='+tcs.backgroundImage.slice(0,24)"
                                 "+',op='+tcs.opacity+'}';}"
                             "out.push('IMG{filter='+cs.filter+',op='+cs.opacity"
                               "+',blend='+cs.mixBlendMode+',bg='+cs.backgroundColor"
                               "+'} cover='+cover);}"
                           "var bgEls=[].slice.call(document.querySelectorAll('div,span,a'))"
                             ".filter(function(e){var c=getComputedStyle(e);"
                               "if(c.backgroundImage.indexOf('url(')<0)return false;"
                               "var r=e.getBoundingClientRect();return r.width>=80&&r.height>=80;});"
                           "for(var m=0;m<bgEls.length&&m<2;m++){var be=bgEls[m];"
                             "var bc=getComputedStyle(be);"
                             "out.push('BGEL{filter='+bc.filter+',op='+bc.opacity"
                               "+',bg='+bc.backgroundColor+',bgi='+bc.backgroundImage.slice(0,50)+'}');}"
                           "var htmlF=getComputedStyle(document.documentElement).filter;"
                           "var bodyF=getComputedStyle(document.body).filter;"
                           "var png=0,jpg=0,other=0;"
                           "for(var q=0;q<big.length;q++){var u2=(big[q].currentSrc||big[q].src||'');"
                             "if(/\\.png(\\?|$)/i.test(u2))png++;"
                             "else if(/\\.jpe?g(\\?|$)/i.test(u2))jpg++;else other++;}"
                           "var fr=document.querySelectorAll('iframe').length;"
                           "return 'img='+big.length+' png='+png+' jpg='+jpg+' other='+other"
                             "+' bgEl='+bgEls.length+' iframes='+fr"
                             "+' htmlFilter='+htmlF+' bodyFilter='+bodyF"
                             "+' || '+out.join(' || ');"
                           "}catch(e){return 'err:'+e;}})()";
                        [wv evaluateJavaScript:probe completionHandler:^(id r3, NSError *e3){
                            @try {
                                if (![r3 isKindOfClass:[NSString class]]) return;
                                NSString *res = (NSString *)r3;
                                // Only remember a sample that actually found media. An
                                // empty result means we looked too early (or the content
                                // lives in a frame), so leave the URL un-cached and try
                                // again on the next pass rather than caching a blind spot.
                                BOOL useful = !([res containsString:@"img=0 bgEl=0"] ||
                                                [res hasPrefix:@"imgs=0"]);
                                if (useful) [ovSeen addObject:u];
                                ADLog(@"overlay@%@: %@%@", u, res, useful ? @"" : @" [retrying]");
                            } @catch(...) {}
                        }];
                    }
                }
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
    } @catch(...) {}
}

static int gWebSeen = 0;
static void ADBootstrapDarkReaderIn(WKWebView *wv);
static void ADWalkWebViews(UIView *v){
    @try {
        if ([v isKindOfClass:[WKWebView class]]){
            gWebSeen++;
            WKWebView *wv = (WKWebView *)v;
            @try {
                static NSMutableSet *seenWV = nil;
                if (!seenWV) seenWV = [NSMutableSet set];
                NSString *u = wv.URL.absoluteString ?: @"(no url)";
                NSString *key = [NSString stringWithFormat:@"%s|%@", object_getClassName(wv),
                                 u.length > 70 ? [u substringToIndex:70] : u];
                if (![seenWV containsObject:key]){
                    [seenWV addObject:key];
                    ADLog(@"WEBVIEW cls=%s url=%@", object_getClassName(wv), u);
                    // Ping the document once per webview and surface the FAILURE, not
                    // just the success: an App-Bound block answers here as
                    // WKErrorDomain/14 with no result, which is indistinguishable from
                    // silence unless the error is printed. Also record whether the
                    // configuration carries the restriction at all.
                    BOOL lim = NO;
                    @try { lim = [[wv.configuration valueForKey:@"limitsNavigationsToAppBoundDomains"] boolValue]; } @catch(...) {}
                    NSString *uShort = u.length > 60 ? [u substringToIndex:60] : u;
                    [wv evaluateJavaScript:
                        @"(function(){try{return (location.href||'nohref').slice(0,60)"
                         "+' DR='+(window.DarkReader?1:0)"
                         "+' t='+String(document.title||'').slice(0,24)+' fr='+frames.length;}catch(e){return 'jserr';}})()"
                         completionHandler:^(id pr, NSError *pe){
                        @try {
                            if (pe) ADLog(@"wvping %@ -> ERR %@/%ld appbound=%d",
                                          uShort, pe.domain, (long)pe.code, lim ? 1 : 0);
                            else    ADLog(@"wvping %@ -> %@ appbound=%d",
                                          uShort, pr, lim ? 1 : 0);
                        } @catch(...) {}
                    }];
                }
            } @catch(...) {}
            ADEnableDarkReaderIn(wv);
        }
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
// WKWebViewConfiguration — App-Bound Domains would silently kill every injection
// path (user scripts AND evaluateJavaScript) on any origin not in the app's
// WKAppBoundDomains list. Pharmacy is the prime suspect for living on such an
// origin. Force the restriction off; log if Amazon actually tried to enable it,
// because that log line is the confirmation of the whole mechanism.
%hook WKWebViewConfiguration
- (void)setLimitsNavigationsToAppBoundDomains:(BOOL)flag {
    if (flag) ADLog(@"appbound: Amazon requested limitsNavigationsToAppBoundDomains=YES — forcing NO");
    %orig(NO);
}
- (BOOL)limitsNavigationsToAppBoundDomains {
    return NO;
}
%end

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
        ADEnsurePrefs();
        if (!gP.enabled || !gP.webDarkReader) return;
        NSString *boot = ADDarkReaderBootstrap();
        Class WKUS = NSClassFromString(@"WKUserScript");
        if (!boot.length || !WKUS) return;
        WKUserScript *us = [[WKUS alloc] initWithSource:boot
                                          injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                       forMainFrameOnly:NO];
        [self addUserScript:us];
        ADLog(@"web: user script restored after removeAllUserScripts");
    } @catch(...) {}
}
%end

static inline double ADUptime(void);

// ── app-ready signal ────────────────────────────────────────────────────────
// Stock iOS keeps the launch screen up only until the app's FIRST FRAME, then
// drops it -- no timer. The SpringBoard cover now mirrors that: this posts a
// Darwin notification once per launch when the UI is demonstrably up (first
// webview attach, or activation as fallback), and the cover dismisses on
// receipt instead of waiting out a fixed 3s hold.
static void ADDarkenNativeTree(UIView *v, int depth, int *n){
    if (!v || depth > 10) return;
    @try {
        UIColor *c = v.backgroundColor;
        if (c){
            CGFloat r=0,g=0,b=0,a=0;
            if ([c getRed:&r green:&g blue:&b alpha:&a] && a > 0.3){
                CGFloat l = 0.2126*r + 0.7152*g + 0.0722*b;
                if (l > 0.45){
                    v.backgroundColor = [UIColor colorWithRed:0.094 green:0.102 blue:0.106 alpha:1.0];
                    (*n)++;
                }
            }
        }
        for (UIView *sv in v.subviews) ADDarkenNativeTree(sv, depth + 1, n);
    } @catch(...) {}
}

// Measure a UIImage the same way the web passes measure a sprite: fraction of
// transparent pixels, and the average luminance of the opaque ones. A glyph is
// mostly clear with dark ink; a photograph is opaque edge to edge.
static BOOL ADImageIsDarkGlyph(UIImage *img, CGFloat *clearOut, CGFloat *avgOut,
                               CGFloat *satOut){
    if (!img) return NO;
    @try {
        CGImageRef cg = img.CGImage;
        if (!cg) return NO;
        const int N = 16;
        size_t bpr = (size_t)N * 4;
        unsigned char *buf = (unsigned char *)calloc((size_t)N * bpr, 1);
        if (!buf) return NO;
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGContextRef ctx = CGBitmapContextCreate(buf, N, N, 8, bpr, cs,
                              kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(cs);
        if (!ctx){ free(buf); return NO; }
        CGContextClearRect(ctx, CGRectMake(0, 0, N, N));
        CGContextDrawImage(ctx, CGRectMake(0, 0, N, N), cg);
        CGContextRelease(ctx);
        int total = N * N, clear = 0, cnt = 0, lite = 0;
        double sum = 0, sat = 0;
        for (int i = 0; i < total; i++){
            unsigned char *px = buf + (i * 4);
            if (px[3] < 40){ clear++; continue; }
            double l = 0.2126*px[0] + 0.7152*px[1] + 0.0722*px[2];
            sum += l; cnt++;
            if (l > 153) lite++;
            // channel spread: black and grey ink sit near zero, brand colour does not
            int mx = px[0] > px[1] ? px[0] : px[1]; if (px[2] > mx) mx = px[2];
            int mn = px[0] < px[1] ? px[0] : px[1]; if (px[2] < mn) mn = px[2];
            sat += (mx - mn);
        }
        free(buf);
        if (!cnt) return NO;
        CGFloat clearFrac = (CGFloat)clear / (CGFloat)total;
        CGFloat avg = (CGFloat)((sum / cnt) / 255.0);
        CGFloat liteFrac = (CGFloat)lite / (CGFloat)cnt;
        CGFloat satFrac = (CGFloat)((sat / cnt) / 255.0);
        if (clearOut) *clearOut = clearFrac;
        if (avgOut) *avgOut = avg;
        if (satOut) *satOut = satFrac;
        // opaque edge to edge => a picture, never touched
        if (clearFrac < 0.35) return NO;
        // already light enough to read on a dark ground
        if (avg >= 0.45 || liteFrac >= 0.10) return NO;
        return YES;
    } @catch(...) {}
    return NO;
}

static BOOL gADGlyphWriting = NO;
static void ADLiftNativeGlyph(UIImageView *iv);
// Try immediately, then converge over the first second. Each attempt is a cheap
// no-op once the image has been handled, because the guard is keyed on it.
static void ADScheduleGlyphLift(UIImageView *iv){
    if (!iv) return;
    @try {
        ADLiftNativeGlyph(iv);
        __weak UIImageView *w = iv;
        const double when[] = { 0.03, 0.10, 0.25, 0.60, 1.20 };
        for (int i = 0; i < 5; i++){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(when[i] * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                @try { UIImageView *v2 = w; if (v2 && v2.window) ADLiftNativeGlyph(v2); }
                @catch(...) {}
            });
        }
    } @catch(...) {}
}

static int gNatGlyphLogged = 0;
static int gNatGlyphTotal = 0;
static int gBorderFix = 0, gBorderSeen = 0;

// BORDER NORMALISATION. There was no border handling anywhere in the tweak, which
// is why the person tab's card outlines stay stock-light while the Interests pane's
// read grey -- and why they flicker: whatever repaints them wins, and we never had
// an opinion. A light border on a dark card is the wrong end of the scale, so any
// visible border lighter than mid-grey is pinned to one value. Pinned, not nudged:
// re-applying the same colour every sweep is what stops the flashing.
static void ADBorderProbe(void);

// PLUS-GLYPH PROBE. The Interests "+" stays dark and previous attempts assumed it
// was a UIImageView the glyph lift would reach. This reports every small round view
// in that pane with what it actually draws with -- image, layer contents, a shape
// layer, or a label -- because those need four different fixes and we have never
// established which one it is.
static int gPlusN = 0;
static void ADPlusWalk(UIView *v, int depth){
    if (!v || depth > 34 || gPlusN >= 8 || v.hidden || v.alpha < 0.05) return;
    @try {
        CGFloat w = v.bounds.size.width, h = v.bounds.size.height;
        // SKIP THE HEADER BAND. Every entry last run was the search bar -- Scan
        // Products, Voice Search, Deliver to -- because querySelector order puts
        // chrome first and the budget was gone before the Interests pane rendered.
        // Fifth probe of mine consumed this way; the band test is now permanent.
        CGRect fr = [v convertRect:v.bounds toView:nil];
        // CIRCULAR ONLY. P4REJECT came back clear=0.00 avg=0.93 -- a fully opaque
        // near-white image, i.e. a product thumbnail on white, not the + glyph. The
        // tile photos are also 100x100 and filled the budget first. The + is drawn as
        // a circle, so require an actual circular clip (or a visible ring) and let the
        // square thumbnails fall out on their own.
        CGFloat rad = v.layer.cornerRadius;
        BOOL circular = (rad >= w * 0.35) || (v.layer.borderWidth > 0.4 && rad > 8);
        BOOL roundish = (w >= 34 && w <= 110 && h >= 34 && h <= 110 &&
                         fabs(w - h) < 12 && fr.origin.y > 200 && circular);
        if (roundish){
            CALayer *l = v.layer;
            UIImage *im = [v isKindOfClass:[UIImageView class]] ? ((UIImageView *)v).image : nil;
            NSString *al = nil;
            @try { al = v.accessibilityLabel; } @catch(...) {}
            CGFloat tr = -1, tg = -1, tb = -1, ta = -1;
            if (v.tintColor) [v.tintColor getRed:&tr green:&tg blue:&tb alpha:&ta];
            gPlusN++;
            ADLog(@"P4PLUS[%s layer=%s %.0fx%.0f img=%d contents=%d sub=%lu "
                   "radius=%.0f border=%.1f tint=%.2f,%.2f,%.2f al='%@']",
                  object_getClassName(v), object_getClassName(l), w, h,
                  im ? 1 : 0, l.contents ? 1 : 0, (unsigned long)v.subviews.count,
                  l.cornerRadius, l.borderWidth, tr, tg, tb,
                  al.length ? al : @"-");
        }
        for (UIView *sv in v.subviews) ADPlusWalk(sv, depth + 1);
    } @catch(...) {}
}

// P5 POSITIONAL DUMP. Six attempts have keyed on a property of the "+" -- image,
// size, roundness, transparency -- and each matched something else. Position is the
// one axis not yet used: the glyph sits at the far left of the Interests pane, below
// the header and well above the tab bar. This dumps EVERYTHING in that box with no
// property filter at all, so whatever draws it cannot avoid being listed.
static int gP5 = 0;
static void ADPlusPosWalk(UIView *v, int depth){
    if (!v || depth > 36 || gP5 >= 14 || v.hidden || v.alpha < 0.05) return;
    @try {
        CGRect f = [v convertRect:v.bounds toView:nil];
        CGFloat w = f.size.width, h = f.size.height;
        if (f.origin.x < 130 && f.origin.y > 60 && f.origin.y < 260 &&
            w >= 20 && w <= 130 && h >= 20 && h <= 130){
            CALayer *l = v.layer;
            UIImage *im = [v isKindOfClass:[UIImageView class]] ? ((UIImageView *)v).image : nil;
            CGFloat br = -1, bg = -1, bb = -1, ba = -1;
            if (v.backgroundColor) [v.backgroundColor getRed:&br green:&bg blue:&bb alpha:&ba];
            NSString *al = nil; @try { al = v.accessibilityLabel; } @catch(...) {}
            gP5++;
            ADLog(@"P5POS[%s layer=%s %.0fx%.0f @%.0f,%.0f img=%d contents=%d "
                   "sublayers=%lu rad=%.0f bw=%.1f bg=%.2f,%.2f,%.2f/%.2f sub=%lu al='%@']",
                  object_getClassName(v), object_getClassName(l), w, h,
                  f.origin.x, f.origin.y, im ? 1 : 0, l.contents ? 1 : 0,
                  (unsigned long)l.sublayers.count, l.cornerRadius, l.borderWidth,
                  br, bg, bb, ba, (unsigned long)v.subviews.count,
                  al.length ? al : @"-");
        }
        for (UIView *sv in v.subviews) ADPlusPosWalk(sv, depth + 1);
    } @catch(...) {}
}

static void ADPlusProbe(void){
    @try {
        if (!gP.enabled) return;
        // Re-arm per pane rather than once per process, so arriving at Interests
        // later in a session still produces a sample.
        static int rounds = 0;
        if (rounds++ > 400) return;
        gPlusN = 0;
        UIWindow *key = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows)
            if (w && !w.hidden && w.alpha > 0.05){ key = w; break; }
        if (key){ ADPlusWalk(key, 0); gP5 = 0; ADPlusPosWalk(key, 0); }
        ADBorderProbe();
    } @catch(...) {}
}

// P6 HAIRLINE PROBE AND FIX. P3BORDER saw zero layer borders, so the person tab's
// card outlines are not borderWidth at all. The remaining native possibility is a
// thin subview with a light background -- a hairline -- which is how UIKit draws
// separators and how a card edge is often faked. That is measurable and fixable in
// the same pass: a view that is long and 1-3pt thin, with a light opaque background,
// is a rule, never content.
static int gHairSeen = 0, gHairFix = 0;

static void ADHairlineFix(UIView *v){
    @try {
        if (!v) return;
        CGFloat w = v.bounds.size.width, h = v.bounds.size.height;
        BOOL thin = (h > 0 && h <= 3.5 && w >= 40) || (w > 0 && w <= 3.5 && h >= 40);
        if (!thin) return;
        UIColor *c = v.backgroundColor;
        if (!c) return;
        CGFloat r, g, b, a;
        if (![c getRed:&r green:&g blue:&b alpha:&a]) return;
        if (a < 0.15) return;
        gHairSeen++;
        CGFloat lum = 0.2126*r + 0.7152*g + 0.0722*b;
        if (lum < 0.30) return;                     // already dark
        static UIColor *want = nil;
        if (!want) want = [UIColor colorWithRed:0.231 green:0.235 blue:0.243 alpha:1.0];
        v.backgroundColor = want;
        gHairFix++;
        static int logged = 0;
        if ((gHairFix % 20) == 1 && logged < 10){
            logged++;
            ADLog(@"P6HAIR[seen=%d fixed=%d %s %.0fx%.0f lum=%.2f]",
                  gHairSeen, gHairFix, object_getClassName(v), w, h, lum);
        }
    } @catch(...) {}
}

static inline BOOL ADIsOwnColor(UIColor *c);

// P6BORDER. P3BORDER saw zero layer borders, so the person-tab outlines are drawn
// some other way, and there are only two plausible ways: a hairline subview with a
// light background, or a card whose own background is light with a darker child
// inset on top -- in which case the visible "border" is the parent showing through
// at the edges. Those need opposite fixes, so both shapes are reported: thin light
// strips, and card-sized views carrying a light background.
static int gP6 = 0;
static void ADBorderProbeWalk(UIView *v, int depth){
    if (!v || depth > 36 || gP6 >= 12 || v.hidden || v.alpha < 0.05) return;
    @try {
        CGRect f = [v convertRect:v.bounds toView:nil];
        CGFloat w = f.size.width, h = f.size.height;
        UIColor *bc = v.backgroundColor;
        CGFloat r = -1, g = -1, b = -1, a = -1;
        BOOL got = (bc && [bc getRed:&r green:&g blue:&b alpha:&a] && a > 0.05);
        CGFloat lum = got ? (0.2126*r + 0.7152*g + 0.0722*b) : -1;
        BOOL hairline = (got && lum > 0.35 && ((h <= 3 && w > 40) || (w <= 3 && h > 40)));
        BOOL lightCard = (got && lum > 0.35 && w >= 120 && w <= 430 && h >= 50 && h <= 420);
        if ((hairline || lightCard) && f.origin.y > 60 && f.origin.y < 900){
            gP6++;
            ADLog(@"P6BORDER[%s %s %.0fx%.0f @%.0f,%.0f bg=%.2f,%.2f,%.2f/%.2f "
                   "rad=%.0f sub=%lu own=%d]",
                  hairline ? "HAIRLINE" : "LIGHTCARD", object_getClassName(v),
                  w, h, f.origin.x, f.origin.y, r, g, b, a,
                  v.layer.cornerRadius, (unsigned long)v.subviews.count,
                  ADIsOwnColor(bc) ? 1 : 0);
        }
        for (UIView *sv in v.subviews) ADBorderProbeWalk(sv, depth + 1);
    } @catch(...) {}
}

static void ADBorderProbe(void){
    @try {
        if (!gP.enabled) return;
        static int rounds = 0;
        if (rounds++ > 400) return;
        UIWindow *key = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows)
            if (w && !w.hidden && w.alpha > 0.05){ key = w; break; }
        if (key){ gP6 = 0; ADBorderProbeWalk(key, 0); }
    } @catch(...) {}
}

static void ADNormalizeBorder(UIView *v){
    @try {
        if (!v) return;
        CALayer *l = v.layer;
        if (l.borderWidth <= 0 || !l.borderColor) return;
        gBorderSeen++;
        UIColor *c = [UIColor colorWithCGColor:l.borderColor];
        CGFloat r = 0, g = 0, b = 0, a = 0;
        if (![c getRed:&r green:&g blue:&b alpha:&a]) return;
        if (a < 0.05) return;
        CGFloat lum = 0.2126*r + 0.7152*g + 0.0722*b;
        if (lum < 0.28) return;                     // already dark enough
        static UIColor *want = nil;
        if (!want) want = [UIColor colorWithRed:0.231 green:0.235 blue:0.243 alpha:1.0];
        l.borderColor = want.CGColor;
        gBorderFix++;
        // Independent cadence. This used to sit inside the natrestore branch, so it
        // only printed when an unrelated image correction happened -- which is why
        // BORDER never appeared once.
        static int logged = 0;
        if ((gBorderFix % 25) == 1 && logged < 12){
            logged++;
            ADLog(@"P3BORDER[seen=%d fixed=%d]", gBorderSeen, gBorderFix);
        }
    } @catch(...) {}
}

static int gNatRestored = 0;
static int gUntintSeen = 0, gUntintTmpl = 0, gUntintColour = 0, gUntintLogged = 0;

// UNTINT ANY COLOURED IMAGE, whoever tinted it. The per-view marker in
// ADLiftNativeGlyph only covers views IT touched, but the log shows two distinct
// tints on screen -- #E8E6E3 from that pass and #DEDBD6 from one of the fourteen
// other tintColor writers -- so a star row tinted by any of the others was never
// corrected, which is why no natrestore line appeared while the stars stayed white.
//
// This is safe without knowing the culprit because it rests on an invariant, not a
// guess: template rendering discards colour and keeps only alpha, so nobody sets
// AlwaysTemplate on a coloured asset deliberately. Rendering mode is a UIImage flag
// and CGImage keeps the original pixels, so a white-rendering star still measures
// as orange and can be put back exactly.
static void ADUntintColourImage(UIImageView *iv){
    @try {
        if (!iv) return;
        UIImage *im = iv.image;
        gUntintSeen++;
        // Census every 200 image views. If tmpl stays 0 while the stars render white,
        // they are NOT being whitened by template+tint and this corrector can never
        // be the fix -- which is the single thing that would redirect this hunt.
        if ((gUntintSeen % 200) == 0 && gUntintLogged < 8){
            gUntintLogged++;
            ADLog(@"UNTINT[seen=%d tmpl=%d coloured=%d restored=%d]",
                  gUntintSeen, gUntintTmpl, gUntintColour, gNatRestored);
        }
        if (!im || im.renderingMode != UIImageRenderingModeAlwaysTemplate) return;
        gUntintTmpl++;
        CGFloat c = 0, a = 0, sat = 0;
        ADImageIsDarkGlyph(im, &c, &a, &sat);
        if (sat <= 0.10) return;                    // genuinely monochrome: leave it
        gUntintColour++;
        gADGlyphWriting = YES;
        iv.image = [im imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        gADGlyphWriting = NO;
        ((UIView *)iv).tintColor = nil;
        if (gNatRestored < 16){
            gNatRestored++;
            ADLog(@"natrestore #%d %s %.0fx%.0f sat=%.2f", gNatRestored,
                  object_getClassName(iv), iv.bounds.size.width,
                  iv.bounds.size.height, sat);
        }
    } @catch(...) {}
}


static void ADLiftNativeGlyph(UIImageView *iv){
    @try {
        if (!iv || !iv.image) return;
        // v5.382: Menu CONTENT never enters the glyph pipeline. Only top search
        // chrome/right chevrons (role=2) are eligible for light-glyph treatment.
        int menuRole382=ADMenuRole382(iv);
        if (menuRole382==1) {
            if(ADImageIsTemplateish(iv.image)||objc_getAssociatedObject(iv.image,kADOrigImageKey)||iv.tintColor) ADRestoreCategoryArtwork379(iv);
            return;
        }
        if (menuRole382==2) {
            UIImage *mi=iv.image;
            if(mi && mi.renderingMode!=UIImageRenderingModeAlwaysTemplate){ gADGlyphWriting=YES; iv.image=[mi imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]; gADGlyphWriting=NO; }
            iv.tintColor=ADColorFromHex(gP.fgHex);
            return;
        }
        static const void *kNatGlyphKey = &kNatGlyphKey;
        // Keyed on the image, not the view: React Native replaces the image on
        // re-render, and a per-view mark would skip the replacement forever.
        static const void *kNatTintedKey = &kNatTintedKey;

        // SELF-CORRECTION, BEFORE THE MARK CHECK. Refusing to lift cannot undo a lift
        // that already happened, and this is why the stars now flash orange and then
        // go white again: a fresh decode paints orange, then a template variant is
        // reinstated on the view and the mark check below waves it straight through.
        //
        // renderingMode is a UIImage-level flag; CGImage keeps the original pixels.
        // So an image rendering as a white silhouette still MEASURES as orange, which
        // means we can detect the mistake and put it back. AlwaysOriginal restores the
        // artwork whatever tint is set, and clearing tintColor stops it applying to
        // any image that lands on this view later.
        UIImage *curImg = iv.image;
        if (curImg && objc_getAssociatedObject(iv, kNatTintedKey)){
            CGFloat c2 = 0, a2 = 0, s2 = 0;
            ADImageIsDarkGlyph(curImg, &c2, &a2, &s2);
            if (s2 > 0.10){
                gADGlyphWriting = YES;
                iv.image = [curImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
                gADGlyphWriting = NO;
                iv.tintColor = nil;
                objc_setAssociatedObject(iv, kNatTintedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(iv, kNatGlyphKey,  nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                if (gNatRestored < 12){
                    gNatRestored++;
                    ADLog(@"natrestore #%d %s %.0fx%.0f sat=%.2f", gNatRestored,
                          object_getClassName(iv), iv.bounds.size.width,
                          iv.bounds.size.height, s2);
                }
                return;
            }
        }

        UIImage *done = objc_getAssociatedObject(iv, kNatGlyphKey);
        if (done && done == iv.image) return;
        CGSize sz = iv.bounds.size;
        if (sz.width < 10 || sz.height < 10 || sz.width > 260 || sz.height > 260) return;
        BOOL glyphSized = (sz.width <= 52 && sz.height <= 52);
        // only on a dark ground, same rule the web pass uses
        CGFloat gl = -1.0;
        UIView *p = iv.superview; int d = 0;
        while (p && d++ < 4){
            UIColor *bc = p.backgroundColor;
            CGFloat r,g,b,a;
            if (bc && [bc getRed:&r green:&g blue:&b alpha:&a] && a > 0.3){
                gl = 0.2126*r + 0.7152*g + 0.0722*b; break;
            }
            p = p.superview;
        }
        if (gl < 0 || gl > 0.30) return;
        CGFloat clearFrac = 0, avg = 0, satFrac = 0;
        if (!ADImageIsDarkGlyph(iv.image, &clearFrac, &avg, &satFrac)){
            // The + never appears in the natglyph log at all, so a gate ABOVE the log
            // rejects it and we have never known which. Report the measurement for a
            // plus-sized view so the rejection is attributable.
            static int rej = 0;
            CGFloat rw = iv.bounds.size.width, rh = iv.bounds.size.height;
            // Skip opaque near-white images: those are tile photos, and they were
            // consuming every slot before the glyph could be sampled.
            if (rej < 10 && rw >= 34 && rw <= 140 && rh >= 34 && rh <= 140 &&
                !(clearFrac < 0.05 && avg > 0.75)){
                rej++;
                ADLog(@"P4REJECT[%s %.0fx%.0f clear=%.2f avg=%.2f sat=%.2f notglyph]",
                      object_getClassName(iv), rw, rh, clearFrac, avg, satFrac);
            }
            return;
        }
        // COLOUR TEST APPLIES AT EVERY SIZE. Template rendering discards colour and
        // keeps only alpha, so tinting a coloured image is always destructive -- that
        // is an invariant, not a size-dependent heuristic. This guard used to sit
        // inside the !glyphSized branch, which meant anything 52x52 or under skipped
        // it entirely. A star rating is drawn as individual ~16px stars, so every one
        // of them was template-tinted: the orange is discarded and a partial fill
        // becomes a uniform white silhouette, which is why the rating reads as five
        // white stars regardless of the score.
        if (satFrac > 0.10) return;         // neutral only: never repaint colour
        // Beyond glyph size this is a brand mark, and only a BLACK one is
        // invisible on a dark ground. A coloured logo already reads, so it stays
        // exactly as the brand drew it.
        if (!glyphSized){
            // P4PLUS showed the Interests "+" is a 100x100 RCTUIImageViewAnimated, so
            // it never qualified as glyph-sized and fell into the brand-mark branch,
            // where the 0.12 luminance ceiling is tuned for a solid black wordmark.
            // A thin stroke on a transparent field averages higher than that across
            // its opaque pixels, so a nearly-empty neutral mark is admitted here.
            BOOL sparseMark = (clearFrac > 0.80 && avg < 0.40 && satFrac < 0.06 &&
                               iv.bounds.size.width <= 140 && iv.bounds.size.height <= 140);
            if (!sparseMark){
                if (clearFrac < 0.50) return;   // must be a mark, not a picture
                if (avg > 0.12) return;         // near-black ink only
            }
        }
        UIImage *lifted = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        gADGlyphWriting = YES;          // our own write must not re-enter setImage:
        iv.image = lifted;
        gADGlyphWriting = NO;
        iv.tintColor = [UIColor colorWithRed:0.910 green:0.902 blue:0.890 alpha:1.0];
        objc_setAssociatedObject(iv, kNatGlyphKey, lifted, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // Record that WE set this view's tint, so the correction above can take it back.
        objc_setAssociatedObject(iv, kNatTintedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        gNatGlyphTotal++;
        if (gNatGlyphLogged < 24){
            gNatGlyphLogged++;
            ADLog(@"natglyph #%d %s %.0fx%.0f clear=%.2f avg=%.2f sat=%.2f ground=%.2f %s",
                  gNatGlyphTotal, object_getClassName(iv), sz.width, sz.height,
                  clearFrac, avg, satFrac, gl, glyphSized ? "glyph" : "mark");
        }
    } @catch(...) {}
}

static void ADCollectWebViews(UIView *v, NSMutableArray *out, int depth){
    // DEPTH 30, NOT 12. A React Native screen nests far deeper than twelve levels,
    // so any WKWebView hosted under an RN tree was invisible to every caller of this
    // -- including whatever decides which view to poll. RATSCAN showed 9 native
    // image views, the polled document reports stars=0 over 1134 elements, and its
    // one child frame is an empty shell: the rating is in a web view this collector
    // never reached. (Fixed once already in the other lineage; this one kept 12.)
    if (!v || depth > 30 || out.count >= 12) return;
    @try {
        if ([v isKindOfClass:[WKWebView class]]) { [out addObject:v]; return; }
        for (UIView *sv in v.subviews) ADCollectWebViews(sv, out, depth + 1);
    } @catch(...) {}
}

static UIImage *ADSplashLogoImage(void){
    static UIImage *cached = nil; static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (NSString *cp in @[@"/var/jb/Library/Application Support/AmazonDark/splash-logo.png",
                               @"/Library/Application Support/AmazonDark/splash-logo.png"]){
            cached = [UIImage imageWithContentsOfFile:cp];
            if (cached) break;
        }
    });
    return cached;
}

// Darken the launch storyboard in place. Runs while the launch screen is still
// on screen, so the snapshot iOS captures for the icon-zoom is a dark one.
static int gLaunchDarkLogged = 0;
static void ADCountViews(UIView *v, int depth, int *n){
    if (!v || depth > 8 || *n > 60) return;
    (*n)++;
    for (UIView *sv in v.subviews) ADCountViews(sv, depth + 1, n);
}
// True only while the launch storyboard is what is on screen: it has a handful
// of views, whereas Amazon's real UI has hundreds.
static BOOL ADLaunchTreeIsTrivial(void){
    int n = 0;
    @try {
        for (UIWindow *w in [UIApplication sharedApplication].windows){
            if (!w || w.hidden) continue;
            ADCountViews(w, 0, &n);
        }
    } @catch(...) {}
    return (n > 0 && n <= 40);
}
static void ADLaunchDarkenTree(UIView *v, int depth, int *bg, int *logo){
    if (!v || depth > 8) return;
    @try {
        UIColor *c = v.backgroundColor;
        if (c){
            CGFloat r=0,g=0,b=0,a=0;
            if ([c getRed:&r green:&g blue:&b alpha:&a] && a > 0.5){
                CGFloat l = 0.2126*r + 0.7152*g + 0.0722*b;
                if (l > 0.5){
                    v.backgroundColor = [UIColor colorWithRed:0.094 green:0.102 blue:0.106 alpha:1.0];
                    (*bg)++;
                }
            }
        }
        ADNormalizeBorder(v);
        ADHairlineFix(v);
        if ([v isKindOfClass:[UIImageView class]]){
            // Every image view on every sweep. This used to hang off a narrow
            // diagnostic branch (no backgroundColor, big and visible), which is why
            // UNTINT never printed a single census line.
            ADUntintColourImage((UIImageView *)v);
            UIImageView *iv = (UIImageView *)v;
            CGSize sz = iv.bounds.size;
            // The wordmark lockup: wide, not a small chrome glyph. Its ink is dark,
            // so on a darkened ground it must be replaced, not merely recoloured.
            if (iv.image && sz.width > 90.0 && sz.height > 20.0 && ADLaunchTreeIsTrivial()){
                UIImage *rep = ADSplashLogoImage();
                if (rep){
                    iv.image = rep;
                    iv.contentMode = UIViewContentModeScaleAspectFit;
                    (*logo)++;
                }
            }
        }
        for (UIView *sv in v.subviews) ADLaunchDarkenTree(sv, depth + 1, bg, logo);
    } @catch(...) {}
}

static void ADLaunchScreenDarkPass(void){
    @try {
        if (!gP.enabled) return;          // master switch: no repaint when off
        if (!gP.enabled) return;          // master switch must gate this too
        if (ADUptime() > 4.2) return;
        int bg = 0, logo = 0;
        for (UIWindow *w in [UIApplication sharedApplication].windows){
            if (!w || w.hidden) continue;
            w.backgroundColor = [UIColor colorWithRed:0.094 green:0.102 blue:0.106 alpha:1.0];
            ADLaunchDarkenTree(w, 0, &bg, &logo);
        }
        if ((bg || logo) && gLaunchDarkLogged < 3){
            gLaunchDarkLogged++;
            ADLog(@"launchdark bg=%d logo=%d t=%.2f", bg, logo, ADUptime());
        }
    } @catch(...) {}
}

// Lifting the cover is a promise that what is underneath is dark. This posted the
// moment a web view attached, regardless of what the screen actually looked like,
// so on a cold launch the cover came off a half-themed app: our text recolouring
// had landed (light text) while the backgrounds were still light. That reads as
// "inverted", and the fully unthemed frames read as the white flash. Same cause.
//
// Samples the largest opaque surface on screen and retries while it is still light.
// The deadline is absolute -- after it we post anyway, and SpringBoard's own hard
// cap would drop the cover regardless, so this can delay the lift but never hang it.
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
static int gWkLogLeft = 6;
// A one-line dark floor evaluated into whatever document currently exists --
// no Dark Reader needed. If the engine is already there this is a no-op; if
// the page is mid-load and unthemed, the background stops being white NOW.
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

%hook WKWebView
- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    @try { if (gLoadLog > 0){ gLoadLog--; ADLog(@"loadhook: loadHTMLString on %s len=%lu",
              object_getClassName(self), (unsigned long)string.length); } ADEnsureUserScript(self); } @catch(...) {}
    return %orig;
}
- (WKNavigation *)loadData:(NSData *)data MIMEType:(NSString *)MIMEType characterEncodingName:(NSString *)enc baseURL:(NSURL *)baseURL {
    @try { ADEnsureUserScript(self); } @catch(...) {}
    return %orig;
}
- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    @try { ADEnsureUserScript(self); } @catch(...) {}
    return %orig;
}
- (id)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)cfg {
    @try {
        ADEnsurePrefs();
        if (gWkLogLeft > 0){ gWkLogLeft--;
            ADLog(@"wkhook init en=%d dr=%d t=%.1f", gP.enabled?1:0, gP.webDarkReader?1:0, ADUptime()); }
        if (gP.enabled && gP.webDarkReader && cfg && cfg.userContentController){
            NSString *js = ADDarkReaderBootstrap();
            Class WKUS = NSClassFromString(@"WKUserScript");
            if (js.length && WKUS){
                WKUserScript *us = [[WKUS alloc] initWithSource:js
                                                  injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                               forMainFrameOnly:NO];
                [cfg.userContentController addUserScript:us];
            }
        }
    } @catch(...) {}
    return %orig;
}
- (void)didMoveToWindow {
    %orig;
    @try {
        ADEnsurePrefs();
        if (!self.window || !gP.enabled || !gP.webDarkReader) return;
        ADPreDarken(self);   // instant dark floor for a page that is mid-load
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
            }
            objc_setAssociatedObject(self, kUS, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        ADBootstrapDarkReaderIn(self); // engine into the already-rendered document (idempotent)

        // Census + repair for LATE webviews. One-shot per instance: name it, ping
        // it (surfacing any injection error), and run the repair pass a few times
        // on a private schedule -- the global burst timer is long dead by the time
        // surfaces like Pharmacy are opened, which is exactly why they stayed
        // light and silent through every previous probe.
        static const void *kADAttachOnce = &kADAttachOnce;
        if (!objc_getAssociatedObject(self, kADAttachOnce)){
            objc_setAssociatedObject(self, kADAttachOnce, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            NSString *au = self.URL.absoluteString ?: @"(no url yet)";
            if (au.length > 70) au = [au substringToIndex:70];
            ADLog(@"wvattach cls=%s url=%@ t=%.1f", object_getClassName(self), au, ADUptime());
            // Measure the page directly: readyState complete AND real content
            // height. Delegate callbacks proved unreliable (no navdone ever
            // fired), so nothing here depends on them.
            @try {
                __weak WKWebView *rw = self;
                __block int rtick = 0;
                NSTimer *rt = [NSTimer scheduledTimerWithTimeInterval:0.15 repeats:YES
                                                                block:^(NSTimer *t){
                    @try {
                        WKWebView *w4 = rw;
                        if (!w4 || ++rtick > 60){ [t invalidate]; ADPostAppReady(); return; }
                        NSString *u6 = w4.URL.absoluteString ?: @"";
                        if (![u6 containsString:@"amazon.com"]) return;
                        [w4 evaluateJavaScript:
                            @"(function(){try{return document.readyState+':'"
                             "+(document.body?document.body.scrollHeight:0);}catch(e){return 'e:0';}})()"
                             completionHandler:^(id rr, NSError *ee){
                            @try {
                                if (ee || ![rr isKindOfClass:[NSString class]]) return;
                                NSArray *pp = [(NSString *)rr componentsSeparatedByString:@":"];
                                if (pp.count < 2) return;
                                BOOL done = [pp[0] isEqualToString:@"complete"];
                                int hgt = [pp[1] intValue];
                                if (done && hgt > 400){
                                    ADLog(@"pageready h=%d t=%.1f", hgt, ADUptime());
                                    [t invalidate];
                                    ADPostAppReady();
                                }
                            } @catch(...) {}
                        }];
                    } @catch(...) { [t invalidate]; }
                }];
                (void)rt;
            } @catch(...) {}
            __weak WKWebView *weakWv = self;
            // Delegate-independent late coverage: watch the URL itself. Prewarmed
            // views (AMIConfigurableWebView) sit blank for minutes, then navigate
            // when their surface opens -- long after any fixed schedule.
            static int gPollCount = 0;
            if (gPollCount < 6){
                gPollCount++;
                NSTimer *poll = [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:YES
                                                                  block:^(NSTimer *tm){
                    @try {
                        WKWebView *wp = weakWv;
                        static const void *kLastU = &kLastU;
                        if (!wp){ [tm invalidate]; return; }
                        // Never work in the background: that is what gets the app
                        // killed and forces the cold relaunch.
                        if ([UIApplication sharedApplication].applicationState
                                != UIApplicationStateActive){
                            // Kill it outright: a timer that merely skips still keeps
                            // the process busy and jetsam-eligible in the background.
                            [tm invalidate];
                            return;
                        }
                        if (ADUptime() > 900.0){ [tm invalidate]; return; }
                        NSString *cu = wp.URL.absoluteString ?: @"";
                        NSString *lu = objc_getAssociatedObject(wp, kLastU) ?: @"";
                        static const void *kTick = &kTick;
                        int tick = [objc_getAssociatedObject(wp, kTick) intValue] + 1;
                        objc_setAssociatedObject(wp, kTick, @(tick), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        BOOL changed = ![cu isEqualToString:lu];
                        if (changed)
                            objc_setAssociatedObject(wp, kLastU, cu, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        if (!wp.window) return;
                        // No native URL (AMIConfigurableWebView): interrogate the
                        // document every 3rd tick instead of skipping forever.
                        if (!cu.length){
                            if (tick % 3 != 0) return;
                            // Prewarmed and URL-less: the Pharmacy surface. Its content
                            // re-renders, so force it on every visit rather than once.
                            @try {
                                [wp evaluateJavaScript:ADPharmForceJS()
                                     completionHandler:^(id rr, NSError *ee){
                                    @try {
                                        if (ee) ADLog(@"pollforce -> ERR %@/%ld", ee.domain, (long)ee.code);
                                        else ADLog(@"pollforce -> %@", rr);
                                    } @catch(...) {}
                                }];
                            } @catch(...) {}
                        } else if (!changed) return;
                        NSString *cs = cu.length ? (cu.length > 60 ? [cu substringToIndex:60] : cu)
                                                 : [NSString stringWithFormat:@"(nourl:%s)", object_getClassName(wp)];
                        [wp evaluateJavaScript:ADDarkReaderReapply()
                             completionHandler:^(id rp, NSError *ep){
                            @try {
                                if (ep) ADLog(@"wvpoll %@ -> ERR %@/%ld", cs, ep.domain, (long)ep.code);
                                else if ([rp isKindOfClass:[NSString class]]) ADLog(@"wvpoll %@ -> %@", cs, rp);
                                else ADLog(@"wvpoll %@ -> (nil)", cs);
                            } @catch(...) {}
                        }];
                    } @catch(...) { [tm invalidate]; }
                }];
                (void)poll;
            }
            for (NSNumber *delay in @[@0.8, @2.0, @4.5]){
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    @try {
                        WKWebView *wv2 = weakWv;
                        if (!wv2 || !wv2.window) return;
                        NSString *u3 = wv2.URL.absoluteString ?: @"(no url)";
                        if (u3.length > 60) u3 = [u3 substringToIndex:60];
                        [wv2 evaluateJavaScript:ADDarkReaderReapply()
                              completionHandler:^(id r4, NSError *e4){
                            @try {
                                if (e4) ADLog(@"wvrepair %@ -> ERR %@/%ld",
                                              u3, e4.domain, (long)e4.code);
                                else if ([r4 isKindOfClass:[NSString class]])
                                          ADLog(@"wvrepair %@ -> %@", u3, r4);
                            } @catch(...) {}
                        }];
                    } @catch(...) {}
                });
            }
        }
    } @catch(...) {}
}
- (void)webView:(WKWebView *)wv didFinishNavigation:(id)nav {
    %orig;
    // Content is drawn -- but only a REAL page counts. about:blank and the
    // autocomplete helper finish in milliseconds, which is what lifted the cover
    // before the shopping page had painted.
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
    // Late surfaces navigate long after every timer is dead; run the repair on a
    // short private schedule after EVERY finished navigation so client-side and
    // late loads (Pharmacy) are covered without any global cadence.
    @try {
        __weak WKWebView *weakNav = wv;
        for (NSNumber *d2 in @[@0.6, @1.8]){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(d2.doubleValue * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                @try {
                    WKWebView *wv3 = weakNav;
                    if (!wv3 || !wv3.window) return;
                    NSString *u5 = wv3.URL.absoluteString ?: @"(no url)";
                    if (u5.length > 60) u5 = [u5 substringToIndex:60];
                    [wv3 evaluateJavaScript:ADDarkReaderReapply()
                          completionHandler:^(id r6, NSError *e6){
                        @try {
                            if (e6) ADLog(@"navrepair %@ -> ERR %@/%ld", u5, e6.domain, (long)e6.code);
                        } @catch(...) {}
                    }];
                } @catch(...) {}
            });
        }
    } @catch(...) {}
    ADEnableDarkReaderIn(self);
}
%end

// ── OPTIONAL PROMOTION REQUEST (v5.362) ───────────────────────────────────────
// Requests the panel maximum (up to 120Hz) from CADisplayLink when enabled. iOS can
// still reduce refresh under Low Power Mode, thermal pressure, unsupported displays,
// or system policy; this is a request, not a bypass of those governors.
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

// Search fields and nav bars draw their own background; a dark panel behind a
// small glyph there reads as a black box rather than a backdrop.
// True only when the nearest ancestor that paints an opaque background is our
// dark theme (or unknown). A light or saturated surface returns NO, so the
// backdrop is skipped there.
static BOOL ADAncestorSurfaceIsDark(UIView *v){
    UIView *p = v; int d = 0;
    while (p && d++ < 10){
        UIColor *bg = p.backgroundColor;
        CGFloat r,g,b,a;
        if (bg && [bg getRed:&r green:&g blue:&b alpha:&a] && a > 0.5){
            CGFloat l = 0.2126*r + 0.7152*g + 0.0722*b;
            return l < 0.10;
        }
        p = p.superview;
    }
    return YES;   // unknown: keep prior behaviour
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
static BOOL ADBackdropIsDark(UIView *v);
static void ADLaunchWhiteGuard(UIView *v);
static void ADLaunchScreenDarkPass(void);
static NSString *ADPharmForceJS(void);
static void ADInvertRNSVGApply(UIView *v);
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
        static int bar383log=0;
        if(bar383log++<48){
            CGFloat lr=0,lg=0,lb=0,la=0; UIColor *lc=((UIView *)iv).tintColor;
            BOOL lok=lc&&[lc getRed:&lr green:&lg blue:&lb alpha:&la];
            ADLog(@"P44BAR383[%s %.0fx%.0f sel=%d tint=%s%.2f,%.2f,%.2f mode=%ld]",object_getClassName(iv),iv.bounds.size.width,iv.bounds.size.height,selected?1:0,lok?"":"?",lr,lg,lb,(long)iv.image.renderingMode);
        }
    } @catch(...) {}
}
static BOOL gADSettingImage = NO;   // re-entrancy guard for the setImage: hooks
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

// Is this view painted over creative artwork? Walks up looking for an image
// view large enough to be a card creative that actually covers the label.
// "Covers" means the picture sits behind most of the text, not merely near it.
// Touching at an edge -- a rating line beside a thumbnail, a "Sponsored" label
// under a photo -- is not text on a creative, and treating it as such is what
// left that copy dark on a dark card.
static BOOL ADCoversRect(CGRect pic, CGRect text){
    @try {
        CGFloat area = text.size.width * text.size.height;
        if (area <= 1) return NO;
        CGRect inter = CGRectIntersection(pic, text);
        if (CGRectIsNull(inter)) return NO;
        CGFloat cov = (inter.size.width * inter.size.height) / area;
        return cov >= 0.80;
    } @catch(...) {}
    return NO;
}

// Depth-first search for a picture that covers the given screen rect.
static UIImageView *ADFindCoveringPicture(UIView *root, CGRect target, int depth){
    if (!root || depth > 5) return nil;
    @try {
        for (UIView *c in root.subviews){
            if ([c isKindOfClass:[UIImageView class]] && ((UIImageView *)c).image){
                CGRect cr = [c convertRect:c.bounds toView:nil];
                if (cr.size.width >= 160 && cr.size.height >= 60 &&
                    ADCoversRect(cr, target)) return (UIImageView *)c;
            }
            UIImageView *deep = ADFindCoveringPicture(c, target, depth + 1);
            if (deep) return deep;
        }
    } @catch(...) {}
    return nil;
}

static UIImageView *ADCreativeBehind(UIView *v){
    @try {
        if (!v) return nil;
        CGRect vr = [v convertRect:v.bounds toView:nil];
        UIView *p = v.superview; int d = 0;
        while (p && d++ < 6){
            // An ancestor container is never "artwork behind the text" -- it always
            // contains the label by definition. Only a real image view that
            // COVERS the label counts, and that is tested below.
            // a picture anywhere beneath this card-sized ancestor that covers us
            @try {
                CGRect pr2 = [p convertRect:p.bounds toView:nil];
                if (pr2.size.width >= 200 && pr2.size.height >= 100){
                    UIImageView *found = ADFindCoveringPicture(p, vr, 0);
                    if (found) return found;
                }
            } @catch(...) {}
            for (UIView *sib in p.subviews){
                if (sib == v) continue;
                if (![sib isKindOfClass:[UIImageView class]]) continue;
                if (!((UIImageView *)sib).image) continue;
                CGRect sr = [sib convertRect:sib.bounds toView:nil];
                if (sr.size.width < 160 || sr.size.height < 60) continue;
                if (ADCoversRect(sr, vr)) return (UIImageView *)sib;
            }
            p = p.superview;
        }
    } @catch(...) {}
    return nil;
}

static int gNatAnyLogged = 0;
static void ADReportAnyTextWrite(id lb, UIColor *from, UIColor *to, const char *via){
    @try {
        if (gNatAnyLogged >= 14) return;
        gNatAnyLogged++;
        NSString *txt = @"";
        @try { if ([lb respondsToSelector:@selector(text)]) txt = [lb performSelector:@selector(text)] ?: @""; }
        @catch(...) {}
        CGFloat r1=0,g1=0,b1=0,a1=0,r2=0,g2=0,b2=0,a2=0;
        [from getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
        [to   getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
        CGRect fr = CGRectZero;
        @try { if ([lb isKindOfClass:[UIView class]]) fr = [(UIView *)lb convertRect:((UIView *)lb).bounds toView:nil]; }
        @catch(...) {}
        ADLog(@"nattext #%d via=%s %s '%@' %.0fx%.0f from=%.2f to=%.2f",
              gNatAnyLogged, via, object_getClassName(lb),
              [txt substringToIndex:MIN((NSUInteger)16, txt.length)],
              fr.size.width, fr.size.height,
              0.2126*r1+0.7152*g1+0.0722*b1, 0.2126*r2+0.7152*g2+0.0722*b2);
    } @catch(...) {}
}

static int gNatTextLogged = 0;
static void ADReportNativeCaption(UILabel *lb, UIColor *from, UIColor *to){
    @try {
        if (gNatTextLogged >= 10) return;
        UIImageView *art = ADCreativeBehind(lb);
        if (!art) return;                       // only the ad-card case matters here
        gNatTextLogged++;
        CGFloat r1=0,g1=0,b1=0,a1=0,r2=0,g2=0,b2=0,a2=0;
        [from getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
        [to   getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
        CGRect lr = [lb convertRect:lb.bounds toView:nil];
        CGRect ar = [art convertRect:art.bounds toView:nil];
        // what is painted directly behind the label?
        NSString *behind = @"-";
        @try {
            UIView *sv = lb.superview;
            UIColor *bc = sv.backgroundColor;
            CGFloat br=0,bg=0,bb=0,ba=0;
            if (bc && [bc getRed:&br green:&bg blue:&bb alpha:&ba] && ba > 0.05)
                behind = [NSString stringWithFormat:@"%s/%.2f",
                          object_getClassName(sv), 0.2126*br+0.7152*bg+0.0722*bb];
            else behind = [NSString stringWithFormat:@"%s/clear", object_getClassName(sv)];
        } @catch(...) {}
        ADLog(@"natcap #%d %s '%@' %.0fx%.0f from=%.2f to=%.2f art=%s@%.0fx%.0f behind=%@",
              gNatTextLogged, object_getClassName(lb),
              [(lb.text ?: @"") substringToIndex:MIN((NSUInteger)18, (lb.text ?: @"").length)],
              lr.size.width, lr.size.height,
              0.2126*r1+0.7152*g1+0.0722*b1, 0.2126*r2+0.7152*g2+0.0722*b2,
              object_getClassName(art), ar.size.width, ar.size.height, behind);
    } @catch(...) {}
}

%hook UILabel
- (void)setTextColor:(UIColor *)color {
    if (!ADRecolorOn() || !color || ADIsOwnColor(color)) {
        %orig;
        return;
    }
    @try {
        UIColor *m = ADModifyUIColor(color, ADColorRoleForeground);
        if (!m) m = color;
        // ad-card copy keeps the colour the site chose for it
        if (ADCreativeBehind(self)) {
            %orig;
            return;
        }
        ADReportAnyTextWrite(self, color, m, "UILabel.setTextColor");
        ADReportNativeCaption(self, color, m);
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

// Diagnostic for the Fabric text path: what the ink was, what we changed it to,
// and whether a creative-sized image view covers this text.
static int gFabLogged = 0;
static void ADReportFabricText(id vObj, NSAttributedString *before, NSAttributedString *after){
    @try {
        if (gFabLogged >= 12 || !before || before.length == 0) return;
        UIColor *c1 = [before attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL];
        UIColor *c2 = after.length ? [after attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL] : nil;
        CGFloat r1=0,g1=0,b1=0,a1=0,r2=0,g2=0,b2=0,a2=0;
        BOOL h1 = c1 && [c1 getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
        BOOL h2 = c2 && [c2 getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
        gFabLogged++;
        UIView *v = [vObj isKindOfClass:[UIView class]] ? (UIView *)vObj : nil;
        UIImageView *art = v ? ADCreativeBehind(v) : nil;
        CGRect fr = v ? [v convertRect:v.bounds toView:nil] : CGRectZero;
        ADLog(@"fabtext #%d '%@' %.0fx%.0f from=%@ to=%@ creative=%@",
              gFabLogged,
              [before.string substringToIndex:MIN((NSUInteger)18, before.string.length)],
              fr.size.width, fr.size.height,
              h1 ? [NSString stringWithFormat:@"%.2f", 0.2126*r1+0.7152*g1+0.0722*b1] : @"-",
              h2 ? [NSString stringWithFormat:@"%.2f", 0.2126*r2+0.7152*g2+0.0722*b2] : @"-",
              art ? [NSString stringWithFormat:@"%s", object_getClassName(art)] : @"none");
    } @catch(...) {}
}

// Fabric text (new architecture). Setter lives on RCTParagraphComponentView.
%hook RCTParagraphComponentView
- (void)setAttributedText:(NSAttributedString *)attributedText {
    @try {
        NSAttributedString *r = ADRecolorAttributedString(attributedText);
        @try { ADReportFabricText(self, attributedText, r); } @catch(...) {}
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
        // Diagnostic: which path actually carries the ad-card captions.
        @try {
            static int pLog = 0;
            if (pLog < 10 && textStorage && textStorage.length){
                pLog++;
                UIColor *pc = [textStorage attribute:NSForegroundColorAttributeName
                                             atIndex:0 effectiveRange:NULL];
                CGFloat pr2=0,pg=0,pb=0,pa=0;
                BOOL ok = pc && [pc getRed:&pr2 green:&pg blue:&pb alpha:&pa];
                id sObj = (id)self;   // class is only forward-declared here
                UIView *pv = [sObj isKindOfClass:[UIView class]] ? (UIView *)sObj : nil;
                CGRect pf = pv ? [pv convertRect:pv.bounds toView:nil] : CGRectZero;
                UIImageView *pa2 = pv ? ADCreativeBehind(pv) : nil;
                ADLog(@"papertext #%d '%@' %.0fx%.0f ink=%@ creative=%@",
                      pLog,
                      [textStorage.string substringToIndex:MIN((NSUInteger)18, textStorage.string.length)],
                      pf.size.width, pf.size.height,
                      ok ? [NSString stringWithFormat:@"%.2f", 0.2126*pr2+0.7152*pg+0.0722*pb] : @"-",
                      pa2 ? @"YES" : @"none");
            }
        } @catch(...) {}
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
        // Text laid over a creative keeps the colour the site chose for it.
        UIImageView *artBehind = ADCreativeBehind(self);
        {
            static int adSeen = 0;
            static NSMutableSet *adSaid = nil;
            CGRect lr = [self convertRect:self.bounds toView:nil];
            // laid out, feed-sized, and not something already reported
            if (adSeen < 40 && lr.size.width > 60 && lr.size.height > 10){
                NSString *key = [attributedText.string substringToIndex:
                                    MIN((NSUInteger)16, attributedText.string.length)];
                if (!adSaid) adSaid = [NSMutableSet set];
                if (![adSaid containsObject:key]){
                    [adSaid addObject:key];
                    adSeen++;
                    ADLog(@"adtext #%d '%@' %.0fx%.0f y=%.0f creative=%s",
                          adSeen, key, lr.size.width, lr.size.height, lr.origin.y,
                          artBehind ? "YES-skip" : "none-recolour");
                }
            }
        }
        if (artBehind) {
            %orig;
            return;
        }
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

// ── HEADER PROBE ────────────────────────────────────────────────────────────
// Reports what actually paints the top band once a scroll settles. The search
// header is dark at rest and pale after scrolling, which is the signature of a
// live backdrop sampling whatever passes beneath it -- but "which view" has been
// assumed twice already, so this names the class, its layer class, and the blur
// style rather than inferring them.
static void ADHeaderWalk(UIView *v, int depth, int *n){
    if (!v || depth > 20 || *n >= 14 || v.hidden || v.alpha < 0.05) return;
    @try {
        CGRect f = [v convertRect:v.bounds toView:nil];
        if (f.origin.y < 130 && CGRectGetMaxY(f) > 0 && f.size.width > 120 &&
            f.size.height > 8 && f.size.height < 220){
            const char *cn = object_getClassName(v);
            const char *ln = object_getClassName(v.layer);
            const char *ef = "-";
            if ([v isKindOfClass:[UIVisualEffectView class]]){
                UIVisualEffect *e = ((UIVisualEffectView *)v).effect;
                ef = e ? object_getClassName(e) : "nil";
            }
            CGFloat r = -1, g = -1, b = -1, a = -1;
            if (v.backgroundColor) [v.backgroundColor getRed:&r green:&g blue:&b alpha:&a];
            (*n)++;
            ADLog(@"HEADER[%s layer=%s effect=%s y=%.0f h=%.0f bg=%.2f,%.2f,%.2f/%.2f]",
                  cn, ln, ef, f.origin.y, f.size.height, r, g, b, a);
        }
        for (UIView *sv in v.subviews) ADHeaderWalk(sv, depth + 1, n);
    } @catch(...) {}
}

static void ADHeaderProbe(void){
    @try {
        if (!gP.enabled) return;
        UIWindow *key = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows)
            if (w && !w.hidden && w.alpha > 0.05){ key = w; break; }
        if (!key) return;
        static int fired = 0;
        if (fired++ > 40) return;         // enough samples to cover a scroll
        int n = 0;
        ADHeaderWalk(key, 0, &n);
    } @catch(...) {}
}

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

static void ADSweepViewTree(UIView *v, int depth, BOOL inTabBar);
static void ADSweepTimed(UIView *v, BOOL inTabBar, const char *why);
static const void *kADScrollPendKey = &kADScrollPendKey;
%hook UIScrollView
- (void)didMoveToWindow {
    %orig;
    @try { if (ADRecolorOn() && self.window) self.indicatorStyle = UIScrollViewIndicatorStyleWhite; } @catch(...) {}
}
- (void)setContentOffset:(CGPoint)offset {
    %orig;
    @try {
        if (!ADRecolorOn() || !self.window || ADIsWebKitOwned(self)) return;
        // Coalesce: schedule ONE scoped sweep ~300ms after scrolling settles.
        if (objc_getAssociatedObject(self, kADScrollPendKey)) return;
        objc_setAssociatedObject(self, kADScrollPendKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UIScrollView *ws = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300*1000000LL),
            dispatch_get_main_queue(), ^{
                UIScrollView *ss = ws;
                if (!ss) return;
                objc_setAssociatedObject(ss, kADScrollPendKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                @try { if (ADRecolorOn() && ss.window) ADSweepTimed(ss, NO, "scroll"); } @catch(...) {}
                @try { if(gP.enabled&&gP.whiteTame&&ss.window){NSMutableArray *sq394=[NSMutableArray arrayWithObject:ss];for(NSUInteger qi394=0;qi394<sq394.count&&qi394<180;qi394++){UIView *x394=sq394[qi394];if([x394 isKindOfClass:[UIImageView class]])ADSubscribeOverlay394(x394);if(qi394<55){for(UIView *c394 in x394.subviews){if(sq394.count<180)[sq394 addObject:c394];else break;}}}} } @catch(...) {}
                @try { ADHeaderProbe(); } @catch(...) {}
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

// ════════════════════════════════════════════════════════════════════════════════
// DIAGNOSTIC PROBE — make the tweak tell us what is still light.
// ────────────────────────────────────────────────────────────────────────────────
// Three rounds of inferring from screenshots has not converged, because a white
// panel can be a UIView background, a drawRect: fill, a UIImage, or a web surface,
// and they look identical in a photo but need completely different fixes. This walks
// the live hierarchy and logs the CLASS of anything still rendering light, plus how
// it is coloured. One line per offender tells us which mechanism to target.
//
// Throttled hard: at most one report per screen appearance and capped entries, so it
// cannot spam the log or cost anything meaningful on the main thread.
static BOOL  gProbeArmed  = NO;
static int   gProbeReports = 0;
// Dedupe by identity rather than capping the number of runs. The old hard cap of 6
// reports was consumed during launch, so by the time a problem tab was opened the
// probe had permanently stopped — which is exactly why the hamburger returned no
// diagnostics. Reporting each distinct offender once keeps it alive indefinitely
// without spamming.
static NSMutableSet *gProbeSeen = nil;
static BOOL ADProbeFirstTime(NSString *key){
    if (!gProbeSeen) gProbeSeen = [NSMutableSet set];
    if ([gProbeSeen containsObject:key]) return NO;
    [gProbeSeen addObject:key];
    return YES;
}

static void ADProbeTree(UIView *v, int depth, int *found){
    if (!v || depth > 40 || *found >= 40) return;
    @try {
        if (ADIsWebKitOwned(v)) {
            ADLog(@"  probe: WEBVIEW %s (Dark Reader territory)", object_getClassName(v));
            return;
        }
        // Small image-bearing views: the Alexa panel's native icons. Either
        // UIImageView artwork, or raw layer.contents -- React Native Fabric
        // paints images that way and bypasses every UIImageView hook, which
        // would explain glyphs no pass has ever touched.
        @try {
            CGFloat gw = v.bounds.size.width, gh = v.bounds.size.height;
            if (gw >= 4 && gw <= 48 && gh >= 4 && gh <= 48 && !v.hidden){
                BOOL isIv = [v isKindOfClass:[UIImageView class]];
                BOOL isLb = [v isKindOfClass:[UILabel class]];
                UIImage *gi = isIv ? ((UIImageView *)v).image : nil;
                BOOL layerImg = !isIv && v.layer.contents != nil;
                if (gi || layerImg || isLb){
                    NSString *gk = [NSString stringWithFormat:@"G%s%.0fx%.0f",
                                    object_getClassName(v), gw, gh];
                    if (ADProbeFirstTime(gk)){
                        UIColor *tc = v.tintColor; CGFloat tr,tg,tb,ta; double tl = -1;
                        if (tc && [tc getRed:&tr green:&tg blue:&tb alpha:&ta]) tl = 0.2126*tr+0.7152*tg+0.0722*tb;
                        if (isLb){
                            UILabel *pl = (UILabel *)v;
                            UIColor *ptc = pl.textColor; CGFloat pr,pg,pb,pa; double ptl = -1;
                            if (ptc && [ptc getRed:&pr green:&pg blue:&pb alpha:&pa]) ptl = 0.2126*pr+0.7152*pg+0.0722*pb;
                            NSString *pt = pl.text.length ? [pl.text substringToIndex:MIN((NSUInteger)6, pl.text.length)] : @"";
                            ADLog(@"  probe: GLYPH %s %.0fx%.0f LBL txt='%s' tl=%.2f cont=%d bkd=%d tint=%.2f",
                                  object_getClassName(v), gw, gh,
                                  pt.UTF8String ?: "", ptl, v.layer.contents?1:0,
                                  ADBackdropIsDark(v)?1:0, tl);
                        } else {
                            ADLog(@"  probe: GLYPH %s %.0fx%.0f img=%d dark=%d tmpl=%d layer=%d tint=%.2f",
                                  object_getClassName(v), gw, gh, gi?1:0,
                                  gi?ADIsDarkGlyph(gi):0, (gi && ADImageIsTemplateish(gi))?1:0,
                                  layerImg?1:0, tl);
                        }
                        (*found)++;
                    }
                }
            }
        } @catch(...) {}
        UIColor *bg = v.backgroundColor;
        if (bg){
            CGFloat r,g,b,a;
            if ([bg getRed:&r green:&g blue:&b alpha:&a] && a > 0.2){
                CGFloat lum = 0.2126*r + 0.7152*g + 0.0722*b;
                if (lum > 0.55){                     // still light => an offender
                    NSString *k = [NSString stringWithFormat:@"L%s%.0fx%.0f",
                                   object_getClassName(v), v.bounds.size.width, v.bounds.size.height];
                    if (ADProbeFirstTime(k)){
                        ADLog(@"  probe: LIGHT bg %s rgba(%.2f,%.2f,%.2f,%.2f) frame=%.0fx%.0f",
                              object_getClassName(v), r,g,b,a,
                              v.bounds.size.width, v.bounds.size.height);
                        (*found)++;
                    }
                } else if (a < 0.95 && lum < 0.35 && v.bounds.size.width > 100){
                    // Dark AND translucent over a large area = the veil on the home tab.
                    NSString *k = [NSString stringWithFormat:@"O%s%.0fx%.0f",
                                   object_getClassName(v), v.bounds.size.width, v.bounds.size.height];
                    if (ADProbeFirstTime(k)){
                        ADLog(@"  probe: DARK-OVERLAY %s rgba(%.2f,%.2f,%.2f,%.2f) frame=%.0fx%.0f",
                              object_getClassName(v), r,g,b,a,
                              v.bounds.size.width, v.bounds.size.height);
                        (*found)++;
                    }
                }
            }
        } else if (v.bounds.size.width > 150 && v.bounds.size.height > 60 && !v.hidden) {
            // No backgroundColor at all but big and visible => probably drawRect: or a
            // UIImageView. Naming it tells us which of the two to chase.
            BOOL isImg = [v isKindOfClass:[UIImageView class]];
            // If it draws itself, does the class override drawRect: ? That is the
            // signal for [UIColor set]/setFill painting our hooks should be catching.
            BOOL drawsSelf = [v methodForSelector:@selector(drawRect:)] !=
                             [UIView instanceMethodForSelector:@selector(drawRect:)];
            // For image views, is the image a tiny resizable slice (a background) or a
            // real picture? Tiny + tiled = a themeable chrome asset.
            const char *imgInfo = "";
            if (isImg){
                UIImage *im = ((UIImageView *)v).image;
                if (im && (im.size.width < 8 || im.size.height < 8)) imgInfo = " TINY-STRETCH-IMG";
            }
            NSString *k = [NSString stringWithFormat:@"N%s%.0fx%.0f",
                           object_getClassName(v), v.bounds.size.width, v.bounds.size.height];
            if (ADProbeFirstTime(k)){
                ADLog(@"  probe: NO-BG %s%s%s%s frame=%.0fx%.0f",
                      object_getClassName(v),
                      isImg ? " IMAGEVIEW" : "",
                      drawsSelf ? " DRAWS-SELF" : "",
                      imgInfo,
                      v.bounds.size.width, v.bounds.size.height);
                (*found)++;
            }
        }
        for (UIView *s in v.subviews) ADProbeTree(s, depth+1, found);
    } @catch(...) {}
}

static void ADRunProbe(void){
    if (!gProbeArmed) return;
    gProbeArmed = NO;
    gProbeReports++;
    @try {
        int found = 0;
        ADLog(@"── probe #%d: scanning for surfaces still light ──", gProbeReports);
        ADLog(@"P28HZ[pref=%d screenMax=%ld]", gP.force120Hz?1:0, (long)UIScreen.mainScreen.maximumFramesPerSecond);
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes){
            if (![sc isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)sc).windows) ADProbeTree(w, 0, &found);
        }
        ADLog(@"── probe #%d complete: %d offender(s) ──", gProbeReports, found);
    } @catch(...) {}
}

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
                    static int peerLog388=0;
                    if(peerLog388++<36) ADLog(@"P52PEER388[%s %.0fx%.0f peers=%d tamed=%d]",object_getClassName(v),vw,vh,peers,tamed);
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
            static int ml384=0; if((changed||ml384<3)&&ml384++<18)ADLog(@"P47MENUACTIVE384[active=%d x=%.2f seen=%d]",hit?1:0,hitX,seen);
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
        static int mlog=0;if(mlog++<18)ADLog(@"P44MENU383[%s %.0fx%.0f role=%d changed=%d]",object_getClassName(iv),iv.bounds.size.width,iv.bounds.size.height,ADMenuRole382(iv),changed?1:0);
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
            if (ctx==2) { static int person381log=0; if(person381log++<18) ADLog(@"P45PERSON383[%s %.0fx%.0f overlay=1 local=%d watched=%d]",object_getClassName(v),v.bounds.size.width,v.bounds.size.height,ADWTLocalSection365(v),ADWTInWatchedCarousel380(v)?1:0); }
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
        static int sub394log=0;if(sub394log++<40)ADLog(@"P58SUB394[%s %.0fx%.0f overlay=1]",object_getClassName(v),v.bounds.size.width,v.bounds.size.height);
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
        // v5.383: resolve Menu CONTENT ownership before glyph conversion or White-Tame.
        // This prevents the convert->restore flash seen in v5.379-v5.381.
        int mr382=ADMenuRole382(self);
        if(mr382==1){ if(ADImageIsTemplateish(self.image)||objc_getAssociatedObject(self.image,kADOrigImageKey)||self.tintColor) ADRestoreCategoryArtwork379(self); return; }
        if(mr382==2){ CALayer *mov=objc_getAssociatedObject(self,kADWhiteTameOverlayKey); if(mov){[mov removeFromSuperlayer];objc_setAssociatedObject(self,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);} objc_setAssociatedObject(self,kADWTForcedImage364,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); UIImage *mi=self.image; if(mi&&mi.renderingMode!=UIImageRenderingModeAlwaysTemplate){gADGlyphWriting=YES;self.image=[mi imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];gADGlyphWriting=NO;} self.tintColor=ADColorFromHex(gP.fgHex); return; }
        // Measured lift for small monochrome assets on a dark ground.
        ADScheduleGlyphLift(self);
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
        // Never behind glyph-sized artwork, never inside search/nav chrome, and
        // never over a coloured/light surface (a teal or promo header), where a
        // near-black panel reads as a box instead of a backdrop.
        CGFloat bw = self.bounds.size.width, bh = self.bounds.size.height;
        BOOL surfDark = ADAncestorSurfaceIsDark(self);
        // A creative behind this image means the visible ground is a photo, not
        // the dark ancestor colour -- a panel there is a black box over artwork.
        // If the view is not laid out yet we cannot know what is behind it, and a
        // wrong backdrop is visible while a missing one is not -- so treat
        // unknown as "do not paint".
        BOOL laidOut = (bw > 1 && bh > 1 && self.window != nil);
        BOOL overArt = (!laidOut) || (ADCreativeBehind(self) != nil);
        if (gP.imageBackdrop && (bw > 48 || bh > 48) && !ADIsChromeGlyphContext(self)
            && surfDark && !overArt){
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
            UIImage *tpl = ADGlyphifyForView(self.image, self);
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
        ADApplyNativeWhiteTame(self);
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

// Only convert glyph-sized artwork. Category thumbnails and other content
// illustrations are larger than any real monochrome UI glyph; whitening them
// destroys their detail. Tab-bar icons are exempt -- they are tinted by
// selection state on their own path and must still convert.
static UIImage *ADGlyphifyForView(UIImage *img, UIView *v){
    @try {
        if (v && ADMenuRole382(v)==1) return nil;
        if (v && ADIsCategoryArtwork379(v)) return nil;
        if (v && !ADInTabBarChain(v) && !ADIsChromeGlyphContext(v)){
            // setImage: often fires before layout, when bounds are still 0x0. Fall
            // back to UIImage.size so 44-80pt menu/content art cannot be template-
            // whitened for one frame and then restored later (the visible flash).
            CGFloat w=v.bounds.size.width, h=v.bounds.size.height;
            if(w<1 && img) w=img.size.width;
            if(h<1 && img) h=img.size.height;
            if (w > 40 || h > 40) return nil;
        }
    } @catch(...) {}
    return ADGlyphify(img);
}
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
    if (!image || ADIsWebKitOwned(self) || !ADRecolorOn() || gADSettingImage) {
        %orig;
        return;
    }
    // v5.383 Menu content is installed AlwaysOriginal on the first assignment,
    // while bottom tab chrome bypasses this path and keeps the old bar state machine.
    @try {
        int mr382=ADMenuRole382(self);
        if(mr382==1){
            UIImage *orig=objc_getAssociatedObject(image,kADOrigImageKey);
            UIImage *want=orig ?: (image.renderingMode==UIImageRenderingModeAlwaysOriginal ? image : [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]);
            CALayer *ov=objc_getAssociatedObject(self,kADWhiteTameOverlayKey);
            if(ov){[ov removeFromSuperlayer];objc_setAssociatedObject(self,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
            objc_setAssociatedObject(self,kADWTForcedImage364,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            self.tintColor=nil;
            gADGlyphWriting=YES;
            %orig(want);
            gADGlyphWriting=NO;
            return;
        }
        if(mr382==2){
            CALayer *mov=objc_getAssociatedObject(self,kADWhiteTameOverlayKey);
            if(mov){[mov removeFromSuperlayer];objc_setAssociatedObject(self,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
            objc_setAssociatedObject(self,kADWTForcedImage364,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            UIImage *want=image.renderingMode==UIImageRenderingModeAlwaysTemplate ? image : [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            gADGlyphWriting=YES;
            %orig(want);
            gADGlyphWriting=NO;
            self.tintColor=ADColorFromHex(gP.fgHex);
            return;
        }
    } @catch(...) {}
    // A remotely fetched glyph arrives here, often well after didMoveToWindow.
    // Measure from the arrival so the dark original is never shown and then
    // corrected -- that correction is what reads as a colour flip.
    @try {
        if (gP.enabled && !gADGlyphWriting) {
            __weak UIImageView *wArr = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                @try { UIImageView *v3 = wArr; if (v3 && v3.window) { ADScheduleGlyphLift(v3); } }
                @catch(...) {}
            });
        }
    } @catch(...) {}
    // Detached: nothing to walk yet. Defer to didMoveToWindow, where ancestry -- and
    // therefore the tab-bar test -- is knowable.
    if (!self.window) {
        %orig;
        return;
    }
    @try { if(gP.whiteTame&&self.window&&!ADInTabBarChain(self)) ADPrimeNativeWhiteTame363(self,image); } @catch(...) {}
    @try {
        // THE tab-bar fix. The dump proved unselected tab icons are dark BITMAPS
        // going invisible on the dark bar, so we still convert them. What we must NOT
        // do is pin the tint: a converted template inherits the bar's tint, which is
        // what lets the selected state colour it blue. Pinning fg is what turned the
        // cart white -- that was the real defect behind four builds of gating, not the
        // conversion.
        if (ADInTabBarChain(self)) {
            %orig;                                       // install the artwork
            gADSettingImage = YES;                       // our own writes must not re-enter
            @try { ADTintBarIcon(self, ADViewIsSelectedInBar(self)); } @catch(...) {}
            gADSettingImage = NO;
            return;
        }
        UIImage *tpl = ADGlyphifyForView(image, self);
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

// v5.366: React frequently reparents/re-lays out small product thumbnails without
// sending a new image assignment. Reassert only the existing White-Tame policy after
// layout so Alexa/Previously Watched/Reviews thumbnails cannot lose their overlay.
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
            vv.bounds.size.width <= 280 && vv.bounds.size.height <= 280) {
            ADApplyNativeWhiteTameView(vv);
            static int miss383log=0;
            if(miss383log<24 && vv.bounds.size.width>=50 && vv.bounds.size.height>=50 && vv.bounds.size.width<=190 && vv.bounds.size.height<=190){
                ADWTBands362 bb=ADWTBandsForWindow362(vv.window);
                if(bb.subscribe>=0 || bb.keep>=0 || bb.watched>=0 || bb.alexa>=0){
                    CALayer *ov=objc_getAssociatedObject(vv,kADWhiteTameOverlayKey);
                    if(!ov){
                        CGRect rr=[vv convertRect:vv.bounds toView:vv.window];
                        ADLog(@"P45MISS383[%s %.0fx%.0f y=%.0f ctx=%d local=%d sub=%.0f keep=%.0f watched=%.0f]",object_getClassName(vv),vv.bounds.size.width,vv.bounds.size.height,CGRectGetMidY(rr),ADWTNativeContext(vv),ADWTLocalSection365(vv),bb.subscribe,bb.keep,bb.watched);
                        miss383log++;
                    }
                }
            }
        }
    } @catch(...) {}
}
%end

// Many of these glyphs are button artwork rather than plain image views — the heart,
// the filters control, the recent-search rows.
%hook UIButton
- (void)setImage:(UIImage *)image forState:(UIControlState)state {
    if (!image || !ADRecolorOn() || gADSettingImage) {
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
        UIImage *tpl = ADGlyphifyForView(image, self);
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

// The residual seconds-long delay: the bottom bar is Packard/React-Native, so a
// tap can be consumed by an RN pressable -- no UIControl ever tracks or flips
// `selected`, and neither of the immediate paths above fires. The white then
// arrives only with the next incidental sweep. UIWindow sendEvent: sees every
// touch no matter who handles it; a touch in the bar region fires a short
// correction burst, and whichever pass first observes the settled selection
// paints it. Writes are idempotent, so the burst cannot ring.
static void ADSweep(void);
static int gBarTapLog = 4;
%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    %orig;
    @try {
        if (!ADRecolorOn()) return;
        for (UITouch *t in event.allTouches){
            if (t.phase != UITouchPhaseBegan && t.phase != UITouchPhaseEnded) continue;
            CGPoint pt = [t locationInView:nil];
            CGFloat H = self.bounds.size.height;
            if (H > 0 && pt.y > H - 130.0){
                if (gBarTapLog > 0){ gBarTapLog--; ADLog(@"bartap y=%.0f t=%.1f", pt.y, ADUptime()); }
                static const int64_t d_ms[] = {0, 250, 700};
                for (int i = 0; i < 3; i++){
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, d_ms[i]*1000000LL),
                        dispatch_get_main_queue(), ^{ @try { ADScheduleBarCorrection(); } @catch(...) {} });
                }
                break;
            }
        }
    } @catch(...) {}
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
static int gRNLogLeft = 8;
static BOOL ADBackdropIsDark(UIView *v){
    UIView *p = v.superview; int d = 0;
    while (p && d++ < 12){
        UIColor *bg = p.backgroundColor;
        if (bg){
            CGFloat r,g,b,a;
            if ([bg getRed:&r green:&g blue:&b alpha:&a] && a > 0.5)
                return (0.2126*r + 0.7152*g + 0.0722*b) < 0.45;
        }
        p = p.superview;
    }
    return YES;   // themed app: unknown means dark
}
static void ADInvertRNSVG(UIView *v){
    @try {
        const char *cn = object_getClassName(v);
        if (!cn) return;
        CGFloat w = v.bounds.size.width, h = v.bounds.size.height;
        if (w < 3 || w > 48 || h < 3 || h > 48) return;   // icons, not illustrations
        BOOL take = (strcmp(cn, "RNSVGSvgView") == 0);    // root only; children ride along
        if (0 && !take && [v isKindOfClass:[UILabel class]]){   // DISABLED in v5.52.0 stability build
            // The kebab: an RN-hosted UILabel whose dots are baked into layer
            // contents. The colour-property gate could never match -- the sweep
            // recolours textColor, so the PROPERTY reads light while the PIXELS
            // stay dark (v5.41.0 logged zero cls=UILabel for exactly this
            // reason). So judge by pixels: render the label once and ask
            // ADIsDarkGlyph. A label whose text genuinely went light fails the
            // darkness test and is left alone; capped attempts keep the render
            // cost bounded while late-drawn contents still get a look.
            if (w >= 6 && h >= 6 && v.layer.contents != nil && ADBackdropIsDark(v)){
                NSNumber *att = objc_getAssociatedObject(v, kADRNCheckKey);
                if (att.intValue < 4 && !objc_getAssociatedObject(v, kADRNInvertKey)){
                    objc_setAssociatedObject(v, kADRNCheckKey, @(att.intValue + 1),
                                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    // NOT here: this code path runs inside layoutSubviews, and
                    // rendering a view mid-layout is reentrant UIKit. Decide on
                    // the next turn, where snapshotting is legal.
                    dispatch_async(dispatch_get_main_queue(), ^{ @try {
                        if (objc_getAssociatedObject(v, kADRNInvertKey)) return;
                        UIGraphicsBeginImageContextWithOptions(v.bounds.size, NO, 1);
                        [v drawViewHierarchyInRect:v.bounds afterScreenUpdates:NO];
                        UIImage *im = UIGraphicsGetImageFromCurrentImageContext();
                        UIGraphicsEndImageContext();
                        if (im && ADIsDarkGlyph(im)) ADInvertRNSVGApply(v);
                    } @catch(...) {} });
                }
            }
        }
        if (!take) return;
        // Heal, don't just flag: React clears layer.filters when it re-renders a
        // mounted view, which is why every icon reverted to black after visiting
        // the dots menu. If our filters are gone, put them back.
        if (objc_getAssociatedObject(v, kADRNInvertKey) && v.layer.filters.count) return;
        ADInvertRNSVGApply(v);
    } @catch(...) {}
}
static void ADInvertRNSVGApply(UIView *v){
    @try {
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
        if (gRNLogLeft > 0){ gRNLogLeft--;
            ADLog(@"rnsvg inverted cls=%s %.0fx%.0f", object_getClassName(v),
                  v.bounds.size.width, v.bounds.size.height); }
    } @catch(...) {}
}

// The Alexa composer + and microphone are RNSVGSvgView roots. The existing tree
// sweep fixes them eventually; hook their first mount/layout so they are white before
// the first visible frame instead of requiring repeated refreshes.
%hook RNSVGSvgView
- (void)didMoveToWindow {
    %orig;
    @try { UIView *vv=(UIView *)self; if (gP.enabled && vv.window) ADInvertRNSVG(vv); } @catch(...) {}
}
- (void)layoutSubviews {
    %orig;
    @try { UIView *vv=(UIView *)self; if (gP.enabled && vv.window) ADInvertRNSVG(vv); } @catch(...) {}
}
%end

// ─── status bar: beat subclass overrides ────────────────────────────────────
static NSMutableDictionary *gSBOrig = nil;      // class name -> original IMP (as uintptr)
static int gSBLogLeft = 8;
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
// Walk from this VC's class up to UIViewController; the first class that
// implements preferredStatusBarStyle directly is the one deciding, so that is
// the one to replace. Runs once per class, then never again.
static NSMutableSet *gSBSeen = nil;
static void ADClaimStatusBarFor(Class c){
    @try {
        SEL sel = @selector(preferredStatusBarStyle);
        Class base = [UIViewController class];
        if (!gSBOrig) gSBOrig = [NSMutableDictionary dictionary];
        if (!gSBSeen) gSBSeen = [NSMutableSet set];
        // Examined once per class: copying a method list on every appearance is
        // exactly the kind of per-screen cost that shows up as scroll lag.
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
                    if (gSBLogLeft > 0){ gSBLogLeft--;
                        ADLog(@"statusbar: claimed %s", class_getName(c)); }
                }
                break;
            }
            free(ms);
            if (here) break;
            c = class_getSuperclass(c);
        }
    } @catch(...) {}
}

static int gTabDumpLeft = 16;   // one-shot budget, refreshed on each app launch
static int gSwImgSeen = 0, gSwGlyphFixed = 0, gSwDarkLabels = 0, gSwViews = 0;
static int gSwLabelFixed = 0, gSwTemplateSeen = 0, gSwTintFixed = 0;
static char gSwSample[96] = {0};
static char gSwTintNow[64] = {0};
// BUDGET. This recursed an entire view subtree with real per-node work and no node
// limit, on every scroll settle and every viewDidAppear. On the home feed that tree
// is thousands of views deep in aggregate, which is the only thing left in the stack
// that can produce a multi-second stall. Capped by nodes and by wall clock; the
// timer re-runs, and already-handled views are cheap to revisit, so coverage still
// converges across passes.
static CFAbsoluteTime gSweepDeadline = 0;
static int gSweepNodes = 0;
static int gSweepCut = 0;

static void ADSweepViewTree(UIView *v, int depth, BOOL inTabBar){
    if (!v || depth > 60) return;
    if (++gSweepNodes > 1100){ gSweepCut++; return; }
    if ((gSweepNodes & 63) == 0 && CFAbsoluteTimeGetCurrent() > gSweepDeadline){
        gSweepCut++; return;
    }
    @try {
        if (ADIsWebKitOwned(v)) return;                 // Dark Reader's territory
        ADInvertRNSVG(v);                               // Alexa panel vector icons
        ADLaunchWhiteGuard(v);                          // launch-window white killer
        ADApplyNativeWhiteTameView(v);                    // UIImageView + targeted Fabric media
        // Was `return`, which skipped this view AND everything under it -- including
        // the background fill. That is where the grey boxes behind the nav tabs came
        // from: an unthemed light fill sitting exactly where we refused to look, and
        // appearing or not depending on whether that view happened to be installed
        // for the current tab state. Only the icon and label work needs holding back
        // here; the fill still has to be darkened like everything else.
        BOOL tabBarish = inTabBar || ADIsTabBarItemish(v);   // INHERITED, not re-derived
        if (tabBarish && gTabDumpLeft > 0 &&
            ([v isKindOfClass:[UIImageView class]] || [v isKindOfClass:[UIButton class]])){
            @try {
                UIImage *di = [v isKindOfClass:[UIImageView class]] ? ((UIImageView *)v).image
                                                                    : ((UIButton *)v).currentImage;
                UIColor *dt = v.tintColor; CGFloat r,g,b,a; double tl = -1;
                if (dt && [dt getRed:&r green:&g blue:&b alpha:&a]) tl = 0.2126*r+0.7152*g+0.0722*b;
                BOOL ownbg = (v.backgroundColor && ADIsOwnColor(v.backgroundColor));
                UIImage *orig = di ? objc_getAssociatedObject(di, kADOrigImageKey) : nil;
                ADLog(@"tabdump cls=%s img=%d dark=%d tmpl=%d tint=%.2f rgb=%.2f,%.2f,%.2f sel=%d bg=%d orig=%d",
                      object_getClassName(v), di?1:0,
                      di?ADIsDarkGlyph(di):0, (di && ADImageIsTemplateish(di))?1:0,
                      tl, (tl>=0?r:0),(tl>=0?g:0),(tl>=0?b:0),
                      ADViewIsSelectedInBar(v)?1:0, ownbg?1:0, orig?1:0);
                gTabDumpLeft--;
            } @catch(...) {}
        }
        // Thin non-icon bar views: candidates for the selection indicator the user
        // wants white. Report class/size/background so it can be targeted exactly.
        if (tabBarish && gTabDumpLeft > 0 &&
            ![v isKindOfClass:[UIImageView class]] && ![v isKindOfClass:[UIButton class]]){
            @try {
                CGFloat hh = v.bounds.size.height, ww = v.bounds.size.width;
                if (hh > 0 && hh < 8 && ww > 12){
                    UIColor *bc = v.backgroundColor; double bl = -1; CGFloat br,bgc,bb,ba;
                    if (bc && [bc getRed:&br green:&bgc blue:&bb alpha:&ba]) bl = 0.2126*br+0.7152*bgc+0.0722*bb;
                    ADLog(@"tabline cls=%s w=%.0f h=%.1f bg=%.2f tagged=%d inchain=%d",
                          object_getClassName(v), ww, hh, bl,
                          ADIsTaggedIndicator(v) ? 1 : 0, ADInTabBarChain(v) ? 1 : 0);
                    gTabDumpLeft--;
                }
            } @catch(...) {}
        }
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
        gSwViews++;
        if ([v isKindOfClass:[UIImageView class]]){
            @try {
                UIImageView *iv = (UIImageView *)v;
                if (iv.image) gSwImgSeen++;
                if (tabBarish){
                    ADTintBarIcon(iv, ADViewIsSelectedInBar(iv));
                } else {
                // v5.382: Menu content is stock; Menu chrome is allowed to continue
                // through the normal light-glyph path.
                if (ADMenuRole382(iv)==1 || ADIsCategoryArtwork379(iv)) {
                    if(ADImageIsTemplateish(iv.image)||objc_getAssociatedObject(iv,kADOrigImageKey)) ADRestoreCategoryArtwork379(iv);
                } else {
                    if (iv.image && ADImageIsTemplateish(iv.image)){
                        gSwTemplateSeen++;
                        UIColor *tint = iv.tintColor;
                        CGFloat tr,tg,tb,ta;
                        if (tint && [tint getRed:&tr green:&tg blue:&tb alpha:&ta] &&
                            (0.2126*tr + 0.7152*tg + 0.0722*tb) < 0.45 && !tabBarish){
                            ((UIView *)iv).tintColor = ADColorFromHex(gP.fgHex);
                            gSwTintFixed++;
                        }
                        // Read back what a real template icon's tint RESOLVES to, whether
                        // or not we just changed it. Recording only on the fix path would
                        // go silent in exactly the steady state we need to inspect.
                        if (!gSwTintNow[0]){
                            @try {
                                CGFloat nr,ng,nb,na;
                                if ([((UIView *)iv).tintColor getRed:&nr green:&ng blue:&nb alpha:&na])
                                    snprintf(gSwTintNow, sizeof(gSwTintNow), "%.2f,%.2f,%.2f", nr,ng,nb);
                            } @catch(...) {}
                        }
                    }
                    UIImage *tpl = ADGlyphifyForView(((UIImageView *)v).image, v);
                    if (tpl) gSwGlyphFixed++;
                    if (tpl){
                        ((UIView *)v).tintColor = ADColorFromHex(gP.fgHex);
                        ((UIImageView *)v).image = tpl;
                    }
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
                    gSwTemplateSeen++;
                    UIColor *tint = b.tintColor;
                    CGFloat tr,tg,tb,ta;
                    if (tint && [tint getRed:&tr green:&tg blue:&tb alpha:&ta] &&
                        (0.2126*tr + 0.7152*tg + 0.0722*tb) < 0.45 && !tabBarish){
                        ((UIView *)b).tintColor = ADColorFromHex(gP.fgHex);
                        gSwTintFixed++;
                    }
                }
                UIImage *tpl = ADGlyphifyForView(cur, b);
                if (tpl){
                    ((UIView *)b).tintColor = ADColorFromHex(gP.fgHex);
                    [b setImage:tpl forState:UIControlStateNormal];
                }
                }
            } @catch(...) {}
        }

        if (!tabBarish && [v isKindOfClass:[UILabel class]]){
            UILabel *l = (UILabel *)v;
            if(ADMenuRole382(v)==2){ l.textColor=ADColorFromHex(gP.fgHex); l.tintColor=ADColorFromHex(gP.fgHex); }
            UIColor *tc = l.textColor;
            @try {
                CGFloat rr,gg,bb,aa;
                if (tc && [tc getRed:&rr green:&gg blue:&bb alpha:&aa] &&
                    (0.2126*rr+0.7152*gg+0.0722*bb) < 0.30) gSwDarkLabels++;
            } @catch(...) {}
            if (tc && !ADIsModifiedUIColor(tc)) {
                UIColor *mt = ADModifyUIColor(tc, ADColorRoleForeground);
                if (mt) { l.textColor = mt; gSwLabelFixed++; }
                else if (!gSwSample[0]) {
                    // Record ONE declined label so we can see what it actually is.
                    @try {
                        CGFloat r2,g2,b2,a2;
                        BOOL ok = [tc getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
                        snprintf(gSwSample, sizeof(gSwSample), "%s rgba=%s%.2f,%.2f,%.2f,%.2f",
                                 object_getClassName(l), ok ? "" : "UNREADABLE ",
                                 ok?r2:0, ok?g2:0, ok?b2:0, ok?a2:0);
                    } @catch(...) {}
                }
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
        ADSweepTimed(self, ADInTabBarChain(self), "view");
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
        ADSweepTimed(self, ADInTabBarChain(self), "view");
    } @catch(...) {}
}
%end

// Timed entry point. Sets the budget, counts nodes, and reports anything slow so
// the native side stops being the unmeasured half of this problem.
static void ADSweepTimed(UIView *v, BOOL inTabBar, const char *why){
    @try {
        CFAbsoluteTime t0 = CFAbsoluteTimeGetCurrent();
        gSweepNodes = 0; gSweepCut = 0;
        gSweepDeadline = t0 + 0.004;                 // 4ms: keep UI responsive; assignment hooks cover media immediately
        ADSweepViewTree(v, 0, inTabBar);
        double ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000.0;
        static int logged = 0;
        if (ms > 3.0 && logged < 40){
            logged++;
            ADLog(@"NPERF[%s ms=%.1f nodes=%d cut=%d]", why, ms, gSweepNodes, gSweepCut);
        }
    } @catch(...) {}
}

// ── TEXT CLASS PROBE ────────────────────────────────────────────────────────
// Every text hook in this tweak -- UILabel setText/setAttributedText, RCTTextView
// setTextStorage -- has reported nothing for the ad-card copy, across four builds.
// Rather than guess at a fifth path, this asks the opposite question: find the
// strings on screen and report WHICH CLASS is holding them.
//
// It matches on the visible text itself ("Sponsored", a rating like 4.4) and dumps
// the view's class, its layer class, and whether it exposes text at all. A class
// that draws with CoreText straight into its layer -- RCTParagraphComponentView on
// RN's new architecture is the obvious candidate -- has no text setter to hook,
// which would explain four builds of silence and mean the fix has to be a layer or
// draw-time intercept rather than another setter.
static int gRatSeen = 0, gRatBelow = 0;

static BOOL ADProbeStringMatches(NSString *t){
    if (!t.length || t.length > 64) return NO;
    if ([t rangeOfString:@"Sponsored"].location != NSNotFound) return YES;
    if ([t rangeOfString:@"out of 5"].location != NSNotFound) return YES;
    // a bare rating: one digit, a dot, one digit
    if (t.length >= 3 && t.length <= 5){
        unichar a = [t characterAtIndex:0], b = [t characterAtIndex:1];
        if (a >= '0' && a <= '9' && (b == '.' || b == ',')) return YES;
    }
    return NO;
}

static NSString *ADProbeTextOf(UIView *v){
    @try {
        if ([v respondsToSelector:@selector(attributedText)]){
            id at = [v performSelector:@selector(attributedText)];
            if ([at isKindOfClass:[NSAttributedString class]]) return [(NSAttributedString *)at string];
        }
    } @catch(...) {}
    @try {
        if ([v respondsToSelector:@selector(text)]){
            id t = [v performSelector:@selector(text)];
            if ([t isKindOfClass:[NSString class]]) return (NSString *)t;
        }
    } @catch(...) {}
    @try { return v.accessibilityLabel; } @catch(...) {}
    return nil;
}

static void ADTextClassWalk(UIView *v, int depth, int *n){
    if (!v || depth > 40 || *n >= 18 || v.hidden || v.alpha < 0.05) return;
    @try {
        NSString *t = ADProbeTextOf(v);
        if (ADProbeStringMatches(t)){
            (*n)++;
            CGRect f = [v convertRect:v.bounds toView:nil];
            CGFloat r = -1, g = -1, b = -1, a = -1;
            @try {
                if ([v respondsToSelector:@selector(textColor)]){
                    id tc = [v performSelector:@selector(textColor)];
                    if ([tc isKindOfClass:[UIColor class]])
                        [(UIColor *)tc getRed:&r green:&g blue:&b alpha:&a];
                }
            } @catch(...) {}
            UIImageView *cre = ADCreativeBehind(v);
            ADLog(@"TEXTCLASS[%s layer=%s '%@' %.0fx%.0f y=%.0f ink=%.2f,%.2f,%.2f/%.2f "
                   "setText=%d setAttr=%d creative=%s]",
                  object_getClassName(v), object_getClassName(v.layer),
                  t.length > 22 ? [t substringToIndex:22] : t,
                  f.size.width, f.size.height, f.origin.y, r, g, b, a,
                  [v respondsToSelector:@selector(setText:)] ? 1 : 0,
                  [v respondsToSelector:@selector(setAttributedText:)] ? 1 : 0,
                  cre ? "YES" : "none");
        }
        // No UIView held those strings, so report what IS drawing at rating size --
        // with the same measurements the lift gate uses, so a decision can be checked
        // against the pixels rather than inferred. If the rating and "Sponsored" are
        // images, this is where they show up, and that also explains why four builds
        // of text hooks reported nothing.
        else if ([v isKindOfClass:[UIImageView class]]){
            UIImageView *iv = (UIImageView *)v;
            CGFloat w = v.bounds.size.width, h = v.bounds.size.height;
            CGRect fr0 = [v convertRect:v.bounds toView:nil];
            if (iv.image){ gRatSeen++; if (fr0.origin.y > 240) gRatBelow++; }
            // SKIP CHROME. The last run spent its whole budget on the search bar and
            // tab icons at y=66..123 and never reached a card, which is the same cap
            // exhaustion v5.215 fixed. Cards start well below the header.
            if (iv.image && w >= 10 && w <= 220 && h >= 8 && h <= 44 && fr0.origin.y > 240){
                CGFloat c3 = 0, a3 = 0, s3 = 0;
                ADImageIsDarkGlyph(iv.image, &c3, &a3, &s3);
                CGRect f = fr0;
                CGFloat tr = -1, tg = -1, tb = -1, ta = -1;
                if (v.tintColor) [v.tintColor getRed:&tr green:&tg blue:&tb alpha:&ta];
                (*n)++;
                ADLog(@"RATIMG[%s %.0fx%.0f y=%.0f clear=%.2f avg=%.2f sat=%.2f "
                       "tmpl=%d tint=%.2f,%.2f,%.2f/%.2f]",
                      object_getClassName(v), w, h, f.origin.y,
                      c3, a3, s3,
                      iv.image.renderingMode == UIImageRenderingModeAlwaysTemplate ? 1 : 0,
                      tr, tg, tb, ta);
            }
        }
        for (UIView *sv in v.subviews) ADTextClassWalk(sv, depth + 1, n);
    } @catch(...) {}
}

static void ADTextClassProbe(void){
    @try {
        if (!gP.enabled) return;
        static int rounds = 0;
        // CAP ON FINDINGS, NOT ATTEMPTS. A flat 8-round budget is spent during launch
        // and navigation -- every viewDidAppear consumes one -- so by the time you
        // scroll to the ads the probe is already silent. That is why v5.218 reported
        // only chrome and v5.219 reported nothing: both were the same exhausted
        // budget, not evidence about the cards.
        static int found = 0;
        if (found >= 3 || rounds++ > 400) return;
        UIWindow *key = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows)
            if (w && !w.hidden && w.alpha > 0.05){ key = w; break; }
        if (!key) return;
        int n = 0;
        gRatSeen = 0; gRatBelow = 0;
        ADTextClassWalk(key, 0, &n);
        if (n) found++;
        // Census, so silence is interpretable: imgs is every UIImageView with an
        // image the walk reached, below is how many sat under the header. imgs>0 with
        // below=0 means the walk never gets into the feed at all.
        else if ((rounds % 12) == 1)
            ADLog(@"RATSCAN[none imgs=%d below240=%d round=%d]",
                  gRatSeen, gRatBelow, rounds);
    } @catch(...) {}
}


// ── P19 VOICE-PERMISSION NATIVE REPAIR (v5.349) ─────────────────────────────
// v5.348 proved the microphone pre-permission pane is not in the probed WKWebView
// DOM (P18VOICE[root=none]). The screenshot also shows mixed black body copy and
// cyan links inside the same paragraphs, which is characteristic of native/RN
// attributed text. Find ONLY those unique voice-permission strings in the visible
// UIView tree and lift dark neutral runs while preserving saturated link colours.
// This operates on Amazon's original text objects -- no overlay and no geometry.
static BOOL ADVoiceTargetText(NSString *t){
    if (!t.length || t.length > 700) return NO;
    if ([t rangeOfString:@"Allow microphone access" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    if ([t rangeOfString:@"Shop faster with voice" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    if ([t rangeOfString:@"You can always turn it off" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    if ([t rangeOfString:@"Your audio is transcribed in the cloud" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    if ([t rangeOfString:@"about shopping with voice" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    return NO;
}

static BOOL ADVoiceColorIsDarkNeutral(UIColor *c){
    if (!c) return YES;   // an attributed run with no explicit colour defaults dark
    @try {
        CGFloat r=0,g=0,b=0,a=0;
        if (![c getRed:&r green:&g blue:&b alpha:&a] || a < 0.05) return NO;
        CGFloat mx=MAX(r,MAX(g,b)), mn=MIN(r,MIN(g,b));
        CGFloat lum=0.2126*r+0.7152*g+0.0722*b;
        // Preserve Amazon's cyan links and any other intentional saturated accent.
        return lum < 0.42 && (mx-mn) < 0.20;
    } @catch(...) {}
    return NO;
}

static NSAttributedString *ADVoiceLiftAttributed(NSAttributedString *in, int *runs){
    if (!in.length) return in;
    @try {
        NSMutableAttributedString *m=[in mutableCopy];
        __block int changed=0;
        NSRange full=NSMakeRange(0,m.length);
        [m enumerateAttribute:NSForegroundColorAttributeName inRange:full options:0
                   usingBlock:^(id value, NSRange range, BOOL *stop){
            @try {
                UIColor *c=[value isKindOfClass:[UIColor class]] ? (UIColor *)value : nil;
                if (!ADVoiceColorIsDarkNeutral(c)) return;
                [m addAttribute:NSForegroundColorAttributeName value:ADColorFromHex(gP.fgHex) range:range];
                changed++;
            } @catch(...) {}
        }];
        if (runs) *runs += changed;
        return changed ? m : in;
    } @catch(...) {}
    return in;
}

// v5.350: Amazon's voice-permission sheet uses RCTTextView leaves whose visible
// string is exposed only through accessibility.  This build of RCTTextView has no
// attributedText/textStorage/textColor selector, but RN commonly keeps its TextKit
// objects as private object ivars.  Inspect those ivars directly and recolour any
// mutable attributed backing store in place.  This changes the ORIGINAL renderer;
// there is no overlay and no replacement view.  ADVoiceLiftAttributed preserves
// saturated runs (the cyan links) and only lifts dark neutral ink.
static int gP20VoiceLeft = 12;
static int ADVoiceRepairHiddenRCTStorage(UIView *v){
    if (!v) return 0;
    @try {
        NSString *cn=NSStringFromClass([v class]);
        if (![cn isEqualToString:@"RCTTextView"]) return 0;
        int changedRuns=0;
        NSMutableArray *seen=[NSMutableArray array];
        Class c=[v class]; int depth=0;
        while(c && c!=[UIView class] && depth++<10){
            unsigned int n=0; Ivar *ivs=class_copyIvarList(c,&n);
            for(unsigned int i=0;i<n;i++){
                Ivar iv=ivs[i];
                const char *enc=ivar_getTypeEncoding(iv);
                if(!enc || enc[0]!='@') continue;
                id obj=nil;
                @try { obj=object_getIvar(v,iv); } @catch(...) { obj=nil; }
                if(!obj) continue;
                if(seen.count<18){
                    const char *nm=ivar_getName(iv);
                    [seen addObject:[NSString stringWithFormat:@"%s=%s",nm?nm:"?",object_getClassName(obj)]];
                }
                @try {
                    NSMutableAttributedString *store=nil;
                    if([obj isKindOfClass:[NSTextStorage class]] ||
                       [obj isKindOfClass:[NSMutableAttributedString class]]){
                        store=(NSMutableAttributedString *)obj;
                    } else if([obj isKindOfClass:[NSLayoutManager class]]){
                        NSTextStorage *ts=[(NSLayoutManager *)obj textStorage];
                        if(ts) store=ts;
                    }
                    if(store && store.length){
                        int rr=0;
                        NSAttributedString *lift=ADVoiceLiftAttributed(store,&rr);
                        if(lift!=store && rr>0){
                            [store setAttributedString:lift];
                            changedRuns += rr;
                        }
                    }
                } @catch(...) {}
            }
            if(ivs) free(ivs);
            c=class_getSuperclass(c);
        }
        if(changedRuns>0){
            [v setNeedsLayout];
            [v setNeedsDisplay];
            [v.layer setNeedsDisplay];
        }
        if(gP20VoiceLeft>0){
            gP20VoiceLeft--;
            CGRect f=[v convertRect:v.bounds toView:nil];
            NSString *txt=ADProbeTextOf(v) ?: @"";
            if(txt.length>62) txt=[txt substringToIndex:62];
            ADLog(@"P20VOICE[RCTTextView %.0fx%.0f y=%.0f '%@' runs=%d ivars=%@]",
                  f.size.width,f.size.height,f.origin.y,txt,changedRuns,
                  seen.count?[seen componentsJoinedByString:@" ~ "]:@"none");
        }
        return changedRuns;
    } @catch(...) {}
    return 0;
}

static void ADVoiceNativeWalk(UIView *v, int depth, int *matched, int *fixed,
                              NSMutableArray *samples){
    if (!v || depth > 45 || v.hidden || v.alpha < 0.05) return;
    @try {
        NSString *txt=ADProbeTextOf(v);
        if (ADVoiceTargetText(txt)){
            (*matched)++;
            BOOL did=NO; int runFix=0;
            BOOL hasAttr=[v respondsToSelector:@selector(attributedText)];
            BOOL hasAttrString=[v respondsToSelector:NSSelectorFromString(@"attributedString")];
            BOOL hasStorage=[v respondsToSelector:NSSelectorFromString(@"textStorage")];
            BOOL canSetAttr=[v respondsToSelector:@selector(setAttributedText:)];
            BOOL canSetPriv=[v respondsToSelector:NSSelectorFromString(@"_setAttributedString:")];
            BOOL hasTC=[v respondsToSelector:@selector(textColor)];
            BOOL canSetTC=[v respondsToSelector:@selector(setTextColor:)];
            CGFloat lum=-1,sat=-1;

            if (hasAttr || hasAttrString || hasStorage){
                @try {
                    id a=nil;
                    if (hasAttr) a=[v performSelector:@selector(attributedText)];
                    if (![a isKindOfClass:[NSAttributedString class]] && hasAttrString)
                        a=[v performSelector:NSSelectorFromString(@"attributedString")];
                    if (![a isKindOfClass:[NSAttributedString class]] && hasStorage)
                        a=[v performSelector:NSSelectorFromString(@"textStorage")];
                    if ([a isKindOfClass:[NSAttributedString class]] && [(NSAttributedString *)a length]){
                        NSAttributedString *r=ADVoiceLiftAttributed((NSAttributedString *)a,&runFix);
                        if (r != a){
                            if ([a isKindOfClass:[NSTextStorage class]]){
                                [(NSTextStorage *)a setAttributedString:r];
                                did=YES;
                            } else if (canSetAttr){
                                [v performSelector:@selector(setAttributedText:) withObject:r];
                                did=YES;
                            } else if (canSetPriv){
                                [v performSelector:NSSelectorFromString(@"_setAttributedString:") withObject:r];
                                did=YES;
                            }
                        }
                    }
                } @catch(...) {}
            }

            if (!did && hasTC && canSetTC){
                @try {
                    id tc=[v performSelector:@selector(textColor)];
                    if ([tc isKindOfClass:[UIColor class]]){
                        CGFloat r=0,g=0,b=0,a=0;
                        if ([(UIColor *)tc getRed:&r green:&g blue:&b alpha:&a]){
                            CGFloat mx=MAX(r,MAX(g,b)),mn=MIN(r,MIN(g,b));
                            lum=0.2126*r+0.7152*g+0.0722*b; sat=mx-mn;
                        }
                        if (ADVoiceColorIsDarkNeutral((UIColor *)tc)){
                            [v performSelector:@selector(setTextColor:) withObject:ADColorFromHex(gP.fgHex)];
                            did=YES;
                        }
                    }
                } @catch(...) {}
            }

            // No public text API on Amazon's RCTTextView: repair its private
            // mutable TextKit backing store directly (v5.350).
            if (!did){
                int hiddenRuns=ADVoiceRepairHiddenRCTStorage(v);
                if(hiddenRuns>0){ runFix += hiddenRuns; did=YES; }
            }

            if (did) (*fixed)++;
            if (samples.count < 12){
                CGRect f=[v convertRect:v.bounds toView:nil];
                NSString *shortT=txt.length>54 ? [txt substringToIndex:54] : txt;
                [samples addObject:[NSString stringWithFormat:
                    @"%s@%.0fx%.0f y=%.0f '%@' attr=%d/set=%d priv=%d tc=%d lum=%.2f sat=%.2f runs=%d fix=%d",
                    object_getClassName(v),f.size.width,f.size.height,f.origin.y,shortT,
                    (hasAttr||hasAttrString||hasStorage)?1:0,canSetAttr?1:0,canSetPriv?1:0,hasTC?1:0,lum,sat,runFix,did?1:0]];
            }
        }
        for (UIView *sv in v.subviews)
            ADVoiceNativeWalk(sv,depth+1,matched,fixed,samples);
    } @catch(...) {}
}

static void ADVoiceNativeSweep(void){
    @try {
        if (!ADRecolorOn()) return;
        int matched=0,fixed=0;
        NSMutableArray *samples=[NSMutableArray array];
        for (UIWindow *w in [UIApplication sharedApplication].windows){
            if (!w || w.hidden || w.alpha < 0.05) continue;
            ADVoiceNativeWalk(w,0,&matched,&fixed,samples);
        }
        static NSString *last=nil;
        NSString *now=[NSString stringWithFormat:@"P19VOICE[matched=%d fixed=%d %@]",
                       matched,fixed,samples.count?[samples componentsJoinedByString:@" ~~ "]:@"none"];
        if (!last || ![last isEqualToString:now]){
            last=now;
            ADLog(@"%@",now);
        }
    } @catch(...) {}
}

// ── WEB VIEW CENSUS ─────────────────────────────────────────────────────────
// One poll, one document, and the rating is in none of them. This asks every
// WKWebView on screen the same two questions -- how many elements do you have, and
// how many of them look like a star rating -- so the one holding the widget names
// itself. Until now the answer "stars=0" only ever came from a single view that
// was never confirmed to be the right one.
// ── WEB PROBE (P8BORD / P7PLUS) ─────────────────────────────────────────────
// Temporary diagnostic. WVCENSUS proved both open surfaces are web (person tab =
// /gw/ajax/mshop.html, Interests = /interest-prompts, img=0), so the light borders
// are CSS borders and the "+" is a CSS/pseudo/mask glyph, not a layer or an <img>.
// This names the actual offenders so the fix can be a SCOPED parse-time sheet
// instead of a third guess. Regex-free and backslash-free on purpose: the payload
// is ObjC -> JS source -> single-quoted strings, and every escaping bug this file
// has shipped came from that layering. Entries are space-joined into ONE line so
// the existing grep -aoE "P8BORD\[[^]]*\]" / "P7PLUS\[[^]]*\]" pulls each token.
// ── PERSON-TAB CARD/PILL BORDER FIX (P9FIX) ─────────────────────────────────
// The light outlines on the person tab are real CSS borders on ROUNDED cards and
// pills in the main document. P8BORD proved form controls / spacing borders are
// square (r=0) while cards/pills are rounded, so border-radius is the discriminator
// CSS cannot express. Run from the census (never the DR bootstrap, so no black-
// screen risk). Dim a side ONLY when the element is visible, rounded (rad>=4),
// sizeable, its border is painted (a>0.3) and neutral-light (0.10<lum<0.70,
// sat<0.12): that hits cards + pills, skips square selects and transparent
// spacing borders (no crop regression), and leaves brand-coloured edges alone.
// Marked once so re-runs are cheap.
static NSString *ADCardBorderFixJS(void){
    return
       @"(function(){try{"
       "if(window.top!==window.self)return 'skip-sub';"
       "var all=document.querySelectorAll('*'),N=Math.min(all.length,2500),done=0,samp=[];"
       "var VH=window.innerHeight||800;"
       "function cc(c){var a=String(c||'').split('('),b=(a[1]||'').split(')')[0].split(',');"
         "if(b.length<3)return null;var r=+b[0],g=+b[1],bl=+b[2],al=b.length>3?+b[3]:1;"
         "return{a:al,l:(0.2126*r+0.7152*g+0.0722*bl)/255*(al<1?al:1),s:(Math.max(r,g,bl)-Math.min(r,g,bl))/255};}"
       "function lite(c){var x=cc(c);return !!(x&&x.a>0.3&&x.l>0.10&&x.l<0.99&&x.s<0.12);}"
       "function clsN(e){var c=e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||'')).slice(0,22);}"
       "var SD=['Top','Right','Bottom','Left'];"
       "for(var i=0;i<N;i++){var e=all[i];var tg=e.tagName;"
         "if(tg==='SELECT'||tg==='INPUT'||tg==='TEXTAREA'||tg==='OPTION')continue;"
         "var st=getComputedStyle(e);var rad=parseFloat(st.borderTopLeftRadius)||0;"
         "var rc=e.getBoundingClientRect();if(rc.width<60||rc.height<16)continue;if(rc.bottom<0||rc.top>VH*3)continue;"
         "if(rad<4&&rc.width<300)continue;"
         "var did='';"
         "for(var k=0;k<4;k++){var w=parseFloat(st['border'+SD[k]+'Width'])||0;if(w<0.5)continue;"
           "var sy=st['border'+SD[k]+'Style'];if(sy==='none'||sy==='hidden')continue;"
           "if(lite(st['border'+SD[k]+'Color'])){e.style.setProperty('border-'+SD[k].toLowerCase()+'-color','#2a2a2c','important');if(did.indexOf('b')<0)did+='b';}}"
         "var ow=parseFloat(st.outlineWidth)||0,ost=String(st.outlineStyle||'');"
         "if(ow>=0.5&&ost!=='none'&&ost!==''&&lite(st.outlineColor)){e.style.setProperty('outline-color','#2a2a2c','important');did+='o';}"
         "var bsh=String(st.boxShadow||'');"
         "if(bsh&&bsh!=='none'&&lite(bsh)){e.style.setProperty('box-shadow','none','important');did+='s';}"
         "if(did){done++;if(samp.length<6)samp.push(tg+'|'+clsN(e)+'|'+Math.round(rc.width)+'x'+Math.round(rc.height)+'|r'+Math.round(rad)+'|'+did);}}"
       "window.__AD_CARDBFIX__=done;"
       "return 'u='+String(location.pathname||'/').slice(-18)+' done='+done+(samp.length?' '+samp.join(' ~ '):'');"
       "}catch(e){return 'err '+(e&&e.message||e);}})()";
}

static NSString *ADProbeWebJS(void){
    return
       @"(function(){try{"
       "var __sub=(window.top!==window.self);"
       "var u=String(location.pathname||'/');"
       "var intr=u.indexOf('interest')>=0,msh=u.indexOf('mshop')>=0;"
       "var all=document.querySelectorAll('*'),N=Math.min(all.length,4000),out=[];"
       "function cls(e){var c=e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||'')).slice(0,26);}"
       "function lum(s){var a=String(s||'').split('('),b=(a[1]||'').split(')')[0].split(',');"
         "if(b.length<3)return -1;var r=parseFloat(b[0]),g=parseFloat(b[1]),bl=parseFloat(b[2]),"
         "al=b.length>3?parseFloat(b[3]):1;if(!(al>0))return -1;"
         "return (0.2126*r+0.7152*g+0.0722*bl)/255*(al<1?al:1);}"
       "try{var CT=[],VH2=window.innerHeight||900,ALL2=document.querySelectorAll('*');"
         "function bgUp(e){var d=0;while(e&&d++<12){var L=lum(getComputedStyle(e).backgroundColor);"
           "if(L>=0)return L;e=e.parentElement;}return -1;}"
         "for(var ci=0;ci<ALL2.length&&CT.length<8;ci++){var e6=ALL2[ci];"
           "if(e6.childElementCount)continue;"
           "var t6=String(e6.textContent||'').trim();if(t6.length<3)continue;"
           "var r6=e6.getBoundingClientRect();if(r6.width<40||r6.height<8)continue;"
           "if(r6.bottom<0||r6.top>VH2)continue;"
           "var s6=getComputedStyle(e6);var tl=lum(s6.color),bl=bgUp(e6);"
           "if(tl<0||bl<0)continue;"
           "if(Math.abs(tl-bl)>0.25)continue;"
           "var ch6=[],n6=e6,d6=0;while(n6&&d6<4){ch6.push((cls(n6)||n6.tagName).slice(0,20));n6=n6.parentElement;d6++;}"
           "var dri=0;try{if(e6.hasAttribute('data-darkreader-inline-color'))dri=1;}catch(x6){}"
           "CT.push(t6.slice(0,14)+'|tl='+tl.toFixed(2)+'|bl='+bl.toFixed(2)+'|dr='+dri+'|'+ch6.join('>'));}"
         "out.push('P9CONTRAST['+(CT.length?CT.join(' ~ '):'none')+']');}catch(ec2){out.push('P9CONTRAST[err]');}"
       "try{var SB=[],EB=document.querySelectorAll('*');"
         "for(var q1=0;q1<EB.length&&SB.length<6;q1++){var b1=EB[q1];"
           "var r1=b1.getBoundingClientRect();if(r1.width<250||r1.height<12||r1.height>80)continue;"
           "var t1=String(b1.textContent||'').toLowerCase();if(t1.indexOf('sponsor')<0)continue;"
           "if(t1.length>40)continue;"
           "var y1=getComputedStyle(b1);var l1=lum(y1.backgroundColor);"
           "var k1=[],n1=b1,d1=0;while(n1&&d1<4){k1.push((cls(n1)||n1.tagName).slice(0,20));n1=n1.parentElement;d1++;}"
           "SB.push(Math.round(r1.width)+'x'+Math.round(r1.height)+'|bg='+y1.backgroundColor+'|L='+(l1<0?'-':l1.toFixed(2))+'|'+k1.join('>'));}"
         "out.push('P9SPONBAR['+(SB.length?SB.join(' ~ '):'none')+']');}catch(x1){out.push('P9SPONBAR[err]');}"
       "try{var CL=[],EC=document.querySelectorAll('*');"
         "for(var q2=0;q2<EC.length&&CL.length<8;q2++){var c2=EC[q2];"
           "var x2=String(c2.textContent||'').trim();if(x2.length<2||x2.length>16)continue;"
           "if(x2.indexOf('%')<0&&x2.indexOf('$')<0)continue;"
             "var pw=c2.parentElement,lw=-1,dw=0;while(pw&&dw++<6){var q=lum(getComputedStyle(pw).backgroundColor);if(q>=0){lw=q;break;}pw=pw.parentElement;}"
           "var r2=c2.getBoundingClientRect();if(r2.width<8)continue;"
           "if(r2.bottom<0||r2.top>(window.innerHeight||900))continue;"
           "var y2=getComputedStyle(c2);var l2=lum(y2.backgroundColor);if(l2<0)continue;"
           "var k2=[],n2=c2,e2=0;while(n2&&e2<5){k2.push((cls(n2)||n2.tagName).slice(0,20));n2=n2.parentElement;e2++;}"
           "var o3=1,f3='-',a3=c2,d3=0;while(a3&&d3<8){var g3=getComputedStyle(a3);o3*=parseFloat(g3.opacity||1);if(g3.filter&&g3.filter!=='none')f3=g3.filter.slice(0,20);a3=a3.parentElement;d3++;}"
             "var bm='-',ab=c2,db2=0;while(ab&&db2<6){var gb=getComputedStyle(ab);if(gb.mixBlendMode&&gb.mixBlendMode!=='normal'){bm=gb.mixBlendMode;break;}ab=ab.parentElement;db2++;}"
             "CL.push(x2.slice(0,12)+'|'+c2.tagName+'|blend='+bm+'|op='+o3.toFixed(2)+'|f='+f3+'|bg='+y2.backgroundColor+'|col='+y2.color+'|'+k2.join('>'));}"
         "out.push('P9COLLEGE['+(CL.length?CL.join(' ~ '):'none')+']');}catch(x2){out.push('P9COLLEGE[err]');}"
       // P9VIS (v5.333): buckets per family (max 4/family, 24 total) so one
       // family cannot starve the scan before it reaches the price cards, and
       // reports tfc (webkit-text-fill-color luminance) + dr (1 = node carries a
       // data-darkreader-* attr). dr=1 with dark colour means Dark Reader touched
       // the node and still left it dark -> we must colour it ourselves.
       "try{"
       "  var VH9=window.innerHeight||900;"
       "  function lum9(s){var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)(?:,\\s*([0-9.]+))?\\)/.exec(String(s||''));"
       "    if(!m)return -1;var a=m[4]===undefined?1:+m[4];if(!(a>0.05))return -1;"
       "    return (0.2126*+m[1]+0.7152*+m[2]+0.0722*+m[3])/255;}"
       "  function cls9(e){var c=e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||'')).slice(0,22);}"
       "  function fam9(e){try{"
       "    if(e.closest('[class*=cXVhZ]'))return 'cXVhZ';"
       "    if(e.closest('[class*=npack-asin-card]'))return 'npack';"
       "    if(e.closest('[class*=theming-card]'))return 'theming';"
       "    if(e.closest('[class*=a-cardui]'))return 'cardui';"
       "  }catch(_){}return '-';}"
       "  function bd9(e){var d=0,n=e.parentElement;"
       "    while(n&&d++<14){var s=getComputedStyle(n);"
       "      var bi=s.backgroundImage;if(bi&&bi!=='none')return {L:-1,img:1};"
       "      var L=lum9(s.backgroundColor);if(L>=0)return {L:L,img:0};n=n.parentElement;}"
       "    return {L:-1,img:0};}"
       "  function dr9(e){try{var a=e.attributes;for(var k=0;k<a.length;k++){if(a[k].name.indexOf('data-darkreader')===0)return 1;}}catch(_){}return 0;}"
       "  var all9=document.querySelectorAll('*'),N9=Math.min(all9.length,6000),H9=[],CN9={},TOT9=0;"
       "  for(var i9=0;i9<N9&&TOT9<24;i9++){var e9=all9[i9];"
       "    var f9=fam9(e9);if(f9==='-')continue;"
       "    var rc9=String(e9.className&&e9.className.baseVal!==undefined?e9.className.baseVal:(e9.className||''));if(/a-offscreen/.test(rc9))continue;"
       "    if((CN9[f9]||0)>=4)continue;"
       "    var r9=e9.getBoundingClientRect();if(r9.width<6||r9.height<5)continue;"
       "    if(r9.bottom<0||r9.top>VH9*2)continue;"
       "    var s9=getComputedStyle(e9),tg9=e9.tagName;"
       "    var gl9=(tg9==='svg'||tg9==='SVG'||tg9==='I'||tg9==='PATH'||/chevron|arrow|icon|caret/i.test(cls9(e9)));"
       "    var tx9=(e9.childElementCount===0)?String(e9.textContent||'').trim():'';"
       "    var te9=(tx9.length>=1&&tx9.length<=40&&e9.childElementCount===0);"
       "    if(!gl9&&!te9)continue;"
       "    var ic9=gl9?(s9.fill&&s9.fill!=='none'?s9.fill:s9.color):s9.color;"
       "    var il9=lum9(ic9);if(il9<0)continue;"
       "    var tf9=lum9(s9.getPropertyValue('-webkit-text-fill-color')||s9.webkitTextFillColor);"
       "    var eff9=(tf9>=0)?tf9:il9;"
       "    var b9=bd9(e9);"
       "    var tag9=(gl9?'glyph':tx9.slice(0,10));"
       "    var pv9='|inkL='+il9.toFixed(2)+'|tfc='+(tf9<0?'-':tf9.toFixed(2))+'|dr='+dr9(e9);"
       "    if(b9.L<0){if(b9.img&&(eff9>0.6||eff9<0.4)){H9.push('IMG '+f9+'|'+tg9+'|'+tag9+pv9+'|bgimg|'+cls9(e9));CN9[f9]=(CN9[f9]||0)+1;TOT9++;}continue;}"
       "    var d9=Math.abs(eff9-b9.L);"
       "    if(d9<0.22){H9.push(f9+'|'+tg9+'|'+tag9+pv9+'|bgL='+b9.L.toFixed(2)+'|d='+d9.toFixed(2)+(b9.img?'|+img':'')+'|'+cls9(e9));CN9[f9]=(CN9[f9]||0)+1;TOT9++;}}"
       "  out.push('P9VIS[n='+H9.length+(H9.length?' '+H9.join(' ~ '):'')+']');"
       "}catch(e9x){out.push('P9VIS[err '+(e9x&&e9x.message||e9x)+']');}"
       // P9BADGE (v5.335): diagnostic-only structure dump for deal badges.
       // The 5.334 device data disproved the DR-strip theory (broken cardui
       // badges were dr=0). Walk percent-off / deal-label leaves up six levels
       // and report class + background + border + text colour at each level so
       // the exact cardui container and the reported brown border are observable.
       "try{"
       "  var VHB=window.innerHeight||900;"
       "  function rgbB(s){var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)(?:,\\s*([0-9.]+))?\\)/.exec(String(s||''));"
       "    if(!m)return '-';var a=m[4]===undefined?1:+m[4];if(!(a>0.05))return '-';"
       "    return Math.round(+m[1])+','+Math.round(+m[2])+','+Math.round(+m[3]);}"
       "  function clsB(e){var c=e.className;var z=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));return (z||e.tagName||'?').replace(/\\s+/g,'.').slice(0,34);}"
       "  function famB(e){try{"
       "    if(e.closest('[class*=cXVhZ]'))return 'cXVhZ';"
       "    if(e.closest('[class*=npack-asin-card]'))return 'npack';"
       "    if(e.closest('[class*=theming-card]'))return 'theming';"
       "    if(e.closest('[class*=a-cardui]'))return 'cardui';"
       "  }catch(_){}return '-';}"
       "  function drB(e){try{var a=e.attributes;for(var k=0;k<a.length;k++){if(a[k].name.indexOf('data-darkreader')===0)return 1;}}catch(_){}return 0;}"
       "  var allB=document.querySelectorAll('*'),NB=Math.min(allB.length,7000),HB=[];"
       "  for(var iB=0;iB<NB&&HB.length<10;iB++){var eB=allB[iB];"
       "    if(eB.childElementCount!==0)continue;"
       "    var txB=String(eB.textContent||'').trim();"
       "    var isPct=/\\d+%\\s*off/i.test(txB),isDeal=/(?:limited\\s+time\\s+deal|deal\\s+selling\\s+fast)/i.test(txB);"
       "    if(!isPct&&!isDeal)continue;"
       "    var fB=famB(eB);if(fB==='-')continue;"
       "    var rB=eB.getBoundingClientRect();if(rB.width<8||rB.height<6)continue;"
       "    if(rB.bottom<0||rB.top>VHB*2)continue;"
       "    var chB=[],nB=eB,dB=0;"
       "    while(nB&&dB<6){var sB=getComputedStyle(nB);var bwB=parseFloat(sB.borderTopWidth)||0;"
       "      chB.push(dB+':'+clsB(nB)+'{bg='+rgbB(sB.backgroundColor)+',bd='+rgbB(sB.borderTopColor)+',bw='+bwB.toFixed(1)+',c='+rgbB(sB.color)+'}');"
       "      nB=nB.parentElement;dB++;}"
       "    HB.push(fB+'|'+(isPct?'pct:':'deal:')+txB.slice(0,18)+'|dr='+drB(eB)+'|'+chB.join('>'));}"
       "  out.push('P9BADGE[n='+HB.length+(HB.length?' '+HB.join(' ~ '):'')+']');"
       "}catch(eBx){out.push('P9BADGE[err '+(eBx&&eBx.message||eBx)+']');}"
       // P10MEDIA (v5.339): diagnostic-only probe for the product-view heart
       // and image carousel pagination dots. Do not style either yet: the heart may
       // be SVG/mask/sprite/pseudo markup, while the selected dot is likely a tiny
       // background-painted node. Report the actual paint source + ancestry first.
       "try{"
       "  var VM=window.innerHeight||900,WM=window.innerWidth||390;"
       "  function cM(e){var c=e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||'')).replace(/\\s+/g,'.').slice(0,28);}"
       "  function rgbM(v){var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)(?:,\\s*([0-9.]+))?\\)/.exec(String(v||''));if(!m)return '-';var a=m[4]===undefined?1:+m[4];if(!(a>0.05))return '-';return Math.round(+m[1])+','+Math.round(+m[2])+','+Math.round(+m[3]);}"
       "  function drM(e){try{var a=e.attributes;for(var i=0;i<a.length;i++)if(a[i].name.indexOf('data-darkreader')===0)return 1;}catch(_){}return 0;}"
       "  function valM(e){try{return [e.id||'',e.getAttribute('aria-label')||'',e.getAttribute('title')||'',e.getAttribute('data-action')||'',e.getAttribute('data-csa-c-content-id')||'',cM(e)].join(' ');}catch(_){return cM(e);}}"
       "  function paintM(e){var s=getComputedStyle(e),b=getComputedStyle(e,'::before'),a=getComputedStyle(e,'::after'),r=e.getBoundingClientRect();"
       "    var mi=s.webkitMaskImage||s.maskImage||'none';var bi=s.backgroundImage||'none';"
       "    var pc=function(x){return x&&x.content&&x.content!=='none'&&x.content!=='normal';};"
       "    return e.tagName.toLowerCase()+'.'+cM(e)+'@'+Math.round(r.width)+'x'+Math.round(r.height)+'+'+Math.round(r.left)+','+Math.round(r.top)"
       "      +'{bg='+rgbM(s.backgroundColor)+',c='+rgbM(s.color)+',fill='+rgbM(s.fill)+',stroke='+rgbM(s.stroke)"
       "      +',bgi='+(bi==='none'?'-':'Y')+',mask='+(mi==='none'?'-':'Y')+',bef='+(pc(b)?'Y':'-')+',aft='+(pc(a)?'Y':'-')"
       "      +',pbg='+(rgbM(b&&b.backgroundColor)||'-')+'/'+(rgbM(a&&a.backgroundColor)||'-')"
       "      +',flt='+(s.filter&&s.filter!=='none'?String(s.filter).slice(0,18):'-')+',dr='+drM(e)+',glyph='+(e.__adGlyph?1:0)+',by='+(e.__adBy||'-')+'}';}"
       "  var HM=[],seenH={},EM=document.querySelectorAll('*'),NM=Math.min(EM.length,7000);"
       "  for(var iM=0;iM<NM&&HM.length<8;iM++){var h=EM[iM],hr=h.getBoundingClientRect();if(hr.width<8||hr.width>90||hr.height<8||hr.height>90)continue;if(hr.bottom<0||hr.top>VM)continue;"
       "    var sig=valM(h),ctl=h.closest?h.closest('button,a,[role=button]'):null;if(ctl&&ctl!==h)sig+=' '+valM(ctl);"
       "    if(!/heart|wish|favor|favour|save|add.to.list|lists-framework/i.test(sig))continue;"
       "    var key=Math.round(hr.left)+'/'+Math.round(hr.top)+'/'+Math.round(hr.width)+'/'+Math.round(hr.height);if(seenH[key])continue;seenH[key]=1;"
       "    var ch=[],n=h,d=0;while(n&&d++<5){ch.push(paintM(n));n=n.parentElement;}HM.push(ch.join('>'));}"
       "  var DM=[];"
       "  for(var jM=0;jM<NM&&DM.length<90;jM++){var d=EM[jM],rr=d.getBoundingClientRect();if(rr.width<4||rr.width>22||rr.height<4||rr.height>22)continue;if(rr.bottom<0||rr.top>VM)continue;"
       "    if(rr.width/rr.height<0.65||rr.width/rr.height>1.45)continue;var ds=getComputedStyle(d);var rad=parseFloat(ds.borderTopLeftRadius)||0;if(rad<Math.min(rr.width,rr.height)*0.30)continue;"
       "    if(String(d.textContent||'').trim())continue;var own=rgbM(ds.backgroundColor),pb=getComputedStyle(d,'::before'),pa=getComputedStyle(d,'::after');"
       "    var hasP=(rgbM(pb.backgroundColor)!=='-'||rgbM(pa.backgroundColor)!=='-'||(pb.content&&pb.content!=='none'&&pb.content!=='normal')||(pa.content&&pa.content!=='none'&&pa.content!=='normal'));"
       "    var bw=parseFloat(ds.borderTopWidth)||0;if(own==='-'&&!hasP&&bw<0.5)continue;DM.push({e:d,x:rr.left+rr.width/2,y:rr.top+rr.height/2,w:rr.width,h:rr.height});}"
       "  DM.sort(function(a,b){return a.y-b.y||a.x-b.x;});var GR=[],used={};"
       "  for(var gM=0;gM<DM.length&&GR.length<3;gM++){if(used[gM])continue;var G=[gM];for(var kM=gM+1;kM<DM.length;kM++){if(Math.abs(DM[kM].y-DM[gM].y)<=5&&Math.abs(DM[kM].h-DM[gM].h)<=5)G.push(kM);}"
       "    if(G.length<3)continue;var minx=99999,maxx=-1;for(var zM=0;zM<G.length;zM++){minx=Math.min(minx,DM[G[zM]].x);maxx=Math.max(maxx,DM[G[zM]].x);}if(maxx-minx<25)continue;"
       "    var dsM=[];for(var z2=0;z2<G.length&&dsM.length<10;z2++){used[G[z2]]=1;var de=DM[G[z2]].e,st=getComputedStyle(de);dsM.push(paintM(de)+'|sel='+(de.getAttribute('aria-current')||de.getAttribute('aria-selected')||de.getAttribute('data-selected')||'-'));}"
       "    GR.push('y='+Math.round(DM[G[0]].y)+' '+dsM.join('~'));}"
       "  out.push('P10MEDIA[heart='+(HM.length?HM.join(' ~~ '):'none')+' || dots='+(GR.length?GR.join(' ~~ '):'none')+']');"
       "}catch(eMx){out.push('P10MEDIA[err '+(eMx&&eMx.message||eMx)+']');}"

       // P11PACKWEB (v5.340): exact visible Pack text probe. The media controls
       // proved native, but the count badge may still be web content.
       "try{"
       "  var PW=[],AW=document.querySelectorAll('*'),NW=Math.min(AW.length,7000);"
       "  function p11c(e){var c=e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||'')).replace(/\\s+/g,'.').slice(0,30);}"
       "  function p11rgb(v){var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)(?:,\\s*([0-9.]+))?\\)/.exec(String(v||''));if(!m)return '-';var a=m[4]===undefined?1:+m[4];if(!(a>0.05))return '-';return Math.round(+m[1])+','+Math.round(+m[2])+','+Math.round(+m[3]);}"
       "  for(var qW=0;qW<NW&&PW.length<5;qW++){var eW=AW[qW];if(eW.childElementCount)continue;var tW=String(eW.textContent||'').trim();if(!/^pack$/i.test(tW))continue;"
       "    var rW=eW.getBoundingClientRect();if(rW.width<2||rW.height<2||rW.bottom<0||rW.top>(window.innerHeight||900))continue;"
       "    var C=[],nW=eW,dW=0;while(nW&&dW++<5){var sW=getComputedStyle(nW);C.push((nW.tagName||'?')+'.'+p11c(nW)+'{c='+p11rgb(sW.color)+',bg='+p11rgb(sW.backgroundColor)+',bgi='+(sW.backgroundImage&&sW.backgroundImage!=='none'?'Y':'-')+'}');nW=nW.parentElement;}"
       "    PW.push(Math.round(rW.left)+','+Math.round(rW.top)+'|'+C.join('>'));}"
       "  out.push('P11PACKWEB[n='+PW.length+(PW.length?' '+PW.join(' ~~ '):'')+']');"
       "}catch(ePW){out.push('P11PACKWEB[err '+(ePW&&ePW.message||ePW)+']');}"

       // P12MEDIA (v5.341): DOM hit-test the visible product-media controls by
       // screen position instead of class names. P10 missed the heart/dots by
       // selector/shape assumptions, while P11 proved the surrounding media UI
       // is WKWebView content. Capture the exact paint stack at the heart, share
       // and carousel-dot coordinates so the next patch can use stable selectors.
       "try{"
       "  var W12=window.innerWidth||414,H12=window.innerHeight||896;"
       "  function c12(e){var c=e&&e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||'')).replace(/\\s+/g,'.').slice(0,44);}"
       "  function rgb12(v){var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)(?:,\\s*([0-9.]+))?\\)/.exec(String(v||''));if(!m)return '-';var a=m[4]===undefined?1:+m[4];if(!(a>0.04))return '-';return Math.round(+m[1])+','+Math.round(+m[2])+','+Math.round(+m[3]);}"
       "  function one12(e){if(!e)return '-';var r=e.getBoundingClientRect(),s=getComputedStyle(e),b=getComputedStyle(e,'::before'),a=getComputedStyle(e,'::after');"
       "    var mi=String(s.webkitMaskImage||s.maskImage||'none')!=='none'?'Y':'-';var bi=String(s.backgroundImage||'none')!=='none'?'Y':'-';"
       "    var bc=(b&&b.content&&b.content!=='none'&&b.content!=='normal')?'Y':'-';var ac=(a&&a.content&&a.content!=='none'&&a.content!=='normal')?'Y':'-';"
       "    var aria=String((e.getAttribute&&((e.getAttribute('aria-label')||e.getAttribute('aria-current')||e.getAttribute('aria-selected')||e.getAttribute('data-selected')||e.getAttribute('role'))))||'-').replace(/\\s+/g,' ').slice(0,28);"
       "    return (e.tagName||'?')+'.'+c12(e)+'@'+Math.round(r.left)+','+Math.round(r.top)+','+Math.round(r.width)+'x'+Math.round(r.height)"
       "      +'{c='+rgb12(s.color)+',bg='+rgb12(s.backgroundColor)+',bgi='+bi+',mask='+mi+',fill='+rgb12(s.fill)+',stroke='+rgb12(s.stroke)+',op='+String(s.opacity||'1').slice(0,4)+',f='+(s.filter&&s.filter!=='none'?'Y':'-')"
       "      +',bef='+rgb12(b&&b.backgroundColor)+'/'+rgb12(b&&b.color)+'/'+rgb12(b&&b.fill)+'/'+(b&&b.backgroundImage&&b.backgroundImage!=='none'?'I':'-')+'/'+bc"
       "      +',aft='+rgb12(a&&a.backgroundColor)+'/'+rgb12(a&&a.color)+'/'+rgb12(a&&a.fill)+'/'+(a&&a.backgroundImage&&a.backgroundImage!=='none'?'I':'-')+'/'+ac+',a='+aria+'}';}"
       "  function hit12(tag,x,y){var A=[];try{A=document.elementsFromPoint?document.elementsFromPoint(x,y):[];}catch(_){}var R=[],seen={};for(var i=0;i<A.length&&R.length<8;i++){var e=A[i],k=(e.tagName||'?')+'|'+c12(e)+'|'+Math.round(e.getBoundingClientRect().width)+'x'+Math.round(e.getBoundingClientRect().height);if(seen[k])continue;seen[k]=1;R.push(one12(e));}return tag+'='+R.join('>');}"
       "  var YS=[0.78,0.82,0.85],HR=[],DR=[];"
       "  for(var yi=0;yi<YS.length;yi++){var yy=H12*YS[yi];HR.push(hit12('H'+Math.round(YS[yi]*100),W12*0.85,yy));HR.push(hit12('S'+Math.round(YS[yi]*100),W12*0.94,yy));}"
       "  var DX=[0.40,0.44,0.48,0.52,0.56,0.60];for(var yj=0;yj<YS.length;yj++){var dy=H12*YS[yj];for(var xi=0;xi<DX.length;xi++)DR.push(hit12('D'+Math.round(DX[xi]*100)+'y'+Math.round(YS[yj]*100),W12*DX[xi],dy));}"
       "  var PR=[];try{var pe=document.querySelector('.pack-size-badge__label,.pack-size-badge');if(pe){var pn=pe,d=0;while(pn&&d++<8){PR.push(one12(pn));pn=pn.parentElement;}}}catch(_){}"
       "  out.push('P12MEDIA[wh='+Math.round(W12)+'x'+Math.round(H12)+' || '+HR.join(' ~~ ')+' || '+DR.join(' ~~ ')+' || packChain='+(PR.length?PR.join('>'):'none')+']');"
       "}catch(e12){out.push('P12MEDIA[err '+(e12&&e12.message||e12)+']');}"
       // P13MEDIA (v5.342): pointer-events-independent product heart dump +
       // direct carousel-dot child dump. P12 found the share and pagination row,
       // but elementsFromPoint skipped the heart painter. Walk all DOM rectangles
       // immediately left of the known share control instead.
       "try{"
       "  function c13(e){var c=e&&e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||'')).replace(/\\s+/g,'.').slice(0,52);}"
       "  function r13(v){var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)(?:,\\s*([0-9.]+))?\\)/.exec(String(v||''));if(!m)return '-';var a=m[4]===undefined?1:+m[4];if(!(a>0.04))return '-';return Math.round(+m[1])+','+Math.round(+m[2])+','+Math.round(+m[3]);}"
       "  function d13(e){if(!e)return '-';var q=e.getBoundingClientRect(),s=getComputedStyle(e),b=getComputedStyle(e,'::before'),a=getComputedStyle(e,'::after');"
       "    var ar=String((e.getAttribute&&((e.getAttribute('aria-label')||e.getAttribute('title')||e.getAttribute('role')||e.getAttribute('aria-current')||e.getAttribute('aria-selected'))))||'-').replace(/\\s+/g,' ').slice(0,30);"
       "    var src='';if((e.tagName||'').toLowerCase()==='img')src=String(e.currentSrc||e.src||'').split('?')[0].slice(-32);"
       "    return (e.tagName||'?')+'.'+c13(e)+'@'+Math.round(q.left)+','+Math.round(q.top)+','+Math.round(q.width)+'x'+Math.round(q.height)"
       "      +'{pe='+String(s.pointerEvents||'-')+',vis='+String(s.visibility||'-')+',op='+String(s.opacity||'1').slice(0,4)+',z='+String(s.zIndex||'-')+',c='+r13(s.color)+',bg='+r13(s.backgroundColor)"
       "      +',bgi='+(s.backgroundImage&&s.backgroundImage!=='none'?'Y':'-')+',mask='+((s.webkitMaskImage||s.maskImage||'none')!=='none'?'Y':'-')+',fill='+r13(s.fill)+',stroke='+r13(s.stroke)+',f='+(s.filter&&s.filter!=='none'?'Y':'-')"
       "      +',bef='+r13(b&&b.backgroundColor)+'/'+r13(b&&b.color)+'/'+r13(b&&b.fill)+'/'+(b&&b.backgroundImage&&b.backgroundImage!=='none'?'I':'-')+'/'+(b&&b.content&&b.content!=='none'&&b.content!=='normal'?'C':'-')"
       "      +',aft='+r13(a&&a.backgroundColor)+'/'+r13(a&&a.color)+'/'+r13(a&&a.fill)+'/'+(a&&a.backgroundImage&&a.backgroundImage!=='none'?'I':'-')+'/'+(a&&a.content&&a.content!=='none'&&a.content!=='normal'?'C':'-')+',a='+ar+(src?'|src='+src:'')+'}';}"
       "  var SH=null,QS=document.querySelectorAll('.ssf-share-trigger');for(var si=0;si<QS.length;si++){var sr0=QS[si].getBoundingClientRect();if(sr0.width>8&&sr0.height>8&&sr0.bottom>0&&sr0.top<(window.innerHeight||900)){SH=QS[si];break;}}"
       "  var HH=[];if(SH){var sr=SH.getBoundingClientRect(),cx=sr.left+sr.width/2,cy=sr.top+sr.height/2,ALL=document.querySelectorAll('*'),NN=Math.min(ALL.length,9000),seen={};"
       "    for(var hi=0;hi<NN&&HH.length<40;hi++){var he=ALL[hi],hr=he.getBoundingClientRect();if(hr.width<2||hr.height<2||hr.width>90||hr.height>70)continue;var hx=hr.left+hr.width/2,hy=hr.top+hr.height/2;"
       "      if(hx<cx-100||hx>cx-14||Math.abs(hy-cy)>34)continue;var hk=(he.tagName||'?')+'|'+c13(he)+'|'+Math.round(hr.left)+','+Math.round(hr.top)+','+Math.round(hr.width)+','+Math.round(hr.height);if(seen[hk])continue;seen[hk]=1;HH.push(d13(he));}}"
       "  var DD=[];var DU=document.querySelector('ul.a-pagination.a-dots');if(DU){DD.push('UL='+d13(DU));var dq=DU.querySelectorAll('*');for(var di=0;di<dq.length&&DD.length<30;di++){var de=dq[di],dr=de.getBoundingClientRect();if(dr.width<1||dr.height<1)continue;DD.push(d13(de)+'|txt='+String(de.textContent||'').replace(/\\s+/g,' ').trim().slice(0,12));}}"
       "  out.push('P13MEDIA[share='+(SH?d13(SH):'none')+' || heartBand='+(HH.length?HH.join(' ~~ '):'none')+' || dots='+(DD.length?DD.join(' ~~ '):'none')+']');"
       "}catch(e13){out.push('P13MEDIA[err '+(e13&&e13.message||e13)+']');}"

       // P14HEART (v5.343): dump the actual media action row anchored on the
       // known-good .ssf-share-trigger. P13 discarded zero-size nodes, but CSS
       // pseudo glyphs often live on 0x0/inline shells. Keep those this time and
       // report ::before/::after paint plus positioning so the black heart painter
       // can be named without another coordinate guess.
       "try{"
       "  function c14(e){var c=e&&e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||'')).replace(/\\s+/g,'.').slice(0,58);}"
       "  function rgb14(v){var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)(?:,\\s*([0-9.]+))?\\)/.exec(String(v||''));if(!m)return '-';var a=m[4]===undefined?1:+m[4];if(!(a>0.04))return '-';return Math.round(+m[1])+','+Math.round(+m[2])+','+Math.round(+m[3]);}"
       "  function ps14(p){if(!p)return '-';return 'ct='+String(p.content||'-').slice(0,18)+',c='+rgb14(p.color)+',bg='+rgb14(p.backgroundColor)+',bgi='+(p.backgroundImage&&p.backgroundImage!=='none'?'Y':'-')+',msk='+(((p.webkitMaskImage||p.maskImage||'none')!=='none')?'Y':'-')+',f='+(p.filter&&p.filter!=='none'?'Y':'-')+',pos='+String(p.position||'-')+',l='+String(p.left||'-')+',r='+String(p.right||'-')+',t='+String(p.top||'-')+',w='+String(p.width||'-')+',h='+String(p.height||'-');}"
       "  function e14(e){var r=e.getBoundingClientRect(),s=getComputedStyle(e),b=getComputedStyle(e,'::before'),a=getComputedStyle(e,'::after');var ar='-';try{ar=e.getAttribute('aria-label')||e.getAttribute('title')||e.getAttribute('role')||'-';}catch(_){}return (e.tagName||'?')+'.'+c14(e)+'@'+Math.round(r.left)+','+Math.round(r.top)+','+Math.round(r.width)+'x'+Math.round(r.height)+'{disp='+String(s.display||'-')+',pos='+String(s.position||'-')+',pe='+String(s.pointerEvents||'-')+',c='+rgb14(s.color)+',bg='+rgb14(s.backgroundColor)+',bgi='+(s.backgroundImage&&s.backgroundImage!=='none'?'Y':'-')+',msk='+(((s.webkitMaskImage||s.maskImage||'none')!=='none')?'Y':'-')+',fill='+rgb14(s.fill)+',stroke='+rgb14(s.stroke)+',bef['+ps14(b)+'],aft['+ps14(a)+'],a='+String(ar).replace(/\\s+/g,' ').slice(0,28)+'}';}"
       "  var sh=document.querySelector('.ssf-share-trigger'),row=null;if(sh){row=sh.parentElement;var up=0;while(row&&up++<8){var rr=row.getBoundingClientRect();if(rr.width>300&&rr.height>=12&&rr.height<=70)break;row=row.parentElement;}}"
       "  var z=[];if(row){z.push('ROW='+e14(row));var q=row.querySelectorAll('*');for(var i=0;i<q.length&&z.length<90;i++){var x=q[i],cs=getComputedStyle(x),bf=getComputedStyle(x,'::before'),af=getComputedStyle(x,'::after'),r=x.getBoundingClientRect();var paint=(cs.backgroundImage&&cs.backgroundImage!=='none')||((cs.webkitMaskImage||cs.maskImage||'none')!=='none')||(bf&&((bf.content&&bf.content!=='none'&&bf.content!=='normal')||(bf.backgroundImage&&bf.backgroundImage!=='none')||((bf.webkitMaskImage||bf.maskImage||'none')!=='none')))||(af&&((af.content&&af.content!=='none'&&af.content!=='normal')||(af.backgroundImage&&af.backgroundImage!=='none')||((af.webkitMaskImage||af.maskImage||'none')!=='none')))||r.width<=40||r.height<=40;if(!paint)continue;z.push(e14(x));}}"
       "  out.push('P14HEART['+(z.length?z.join(' ~~ '):'none')+']');"
       "}catch(e14x){out.push('P14HEART[err '+(e14x&&e14x.message||e14x)+']');}"

       // P17HEART (v5.347): verify the original Amazon paint leaf and the
       // documentStart CSS filter, without mutating the node from JavaScript.
       "try{var h17=document.querySelector('[class*=lists-treatment-hear] .a-icon');if(h17){var r17=h17.getBoundingClientRect(),s17=getComputedStyle(h17),f17=String(s17.filter||'none').replace(/\\s+/g,' ');out.push('P17HEART[node=.a-icon@'+Math.round(r17.width)+'x'+Math.round(r17.height)+' bgi='+(s17.backgroundImage&&s17.backgroundImage!=='none'?'Y':'-')+' filter='+f17.slice(0,72)+' css='+((f17.indexOf('brightness(0)')>=0&&f17.indexOf('invert(1)')>=0)?'1':'0')+']');}else out.push('P17HEART[node=none]');}catch(e17){out.push('P17HEART[err '+(e17&&e17.message||e17)+']');}"

       // P21CHEV (v5.358): report the geometry-selected College edge painters
       // plus any older semantic markers. Include pseudo/border paint so a surviving
       // CSS-border arrow is diagnosable instead of collapsing back to n=0.
       "try{var C21=document.querySelectorAll('[data-ad-college-chevron=\"1\"],[data-ad-nav-chevron-paint=\"1\"]'),Q21=[];for(var i21=0;i21<C21.length&&i21<20;i21++){var c21=C21[i21],r21=c21.getBoundingClientRect(),s21=getComputedStyle(c21),b21=getComputedStyle(c21,'::before'),a21=getComputedStyle(c21,'::after');Q21.push('why='+String(c21.getAttribute('data-ad-college-chevron-why')||c21.getAttribute('data-ad-nav-label')||'-')+'|'+c21.tagName+'.'+String(c21.className||'').replace(/\\s+/g,'.').slice(0,34)+'@'+Math.round(r21.left)+','+Math.round(r21.top)+'/'+Math.round(r21.width)+'x'+Math.round(r21.height)+'|c='+String(s21.color||'-')+'|bt='+String(s21.borderTopColor||'-')+'|br='+String(s21.borderRightColor||'-')+'|fill='+String(s21.fill||'-')+'|bgi='+(s21.backgroundImage&&s21.backgroundImage!=='none'?'Y':'-')+'|bef='+String(b21&&b21.borderTopColor||'-')+'/'+String(b21&&b21.borderRightColor||'-')+'|aft='+String(a21&&a21.borderTopColor||'-')+'/'+String(a21&&a21.borderRightColor||'-')+'|f='+String(s21.filter||'none').replace(/\\s+/g,' ').slice(0,38)+'|by='+String(c21.__adBy||'-'));}out.push('P21CHEV[n='+Q21.length+(Q21.length?' '+Q21.join(' ~~ '):'')+']');}catch(e21){out.push('P21CHEV[err '+(e21&&e21.message||e21)+']');}"

       // P22BORDER (v5.357): report normalized cards, including global-brown catches.
       "try{var B22=document.querySelectorAll('[data-ad-cardborder=\"1\"]'),R22=[];for(var i22=0;i22<B22.length;i22++){var b22=B22[i22],r22=b22.getBoundingClientRect(),s22=getComputedStyle(b22);if(r22.width<120||r22.height<50)continue;var z22=b22.tagName+'.'+String(b22.className||'').replace(/\\s+/g,'.').slice(0,32)+'@y'+Math.round(r22.top)+'/'+Math.round(r22.width)+'x'+Math.round(r22.height)+'|t='+String(s22.borderTopColor||'-')+'|in='+String(b22.style.getPropertyValue('border-color')||'-')+'!'+String(b22.style.getPropertyPriority('border-color')||'-')+'|sec='+String(b22.getAttribute('data-ad-border-section')||'-')+'|by='+String(b22.__adBy||'-');R22.push(z22);if(R22.length>12)R22.shift();}out.push('P22BORDER[n='+R22.length+(R22.length?' '+R22.join(' ~~ '):'')+']');}catch(e22){out.push('P22BORDER[err '+(e22&&e22.message||e22)+']');}"

       // P23BROWN (v5.357): hard win condition for the remaining card-border bug.
       // Reports any large rounded container still painting the exact brown family.
       "try{function rb23(v){var m=/rgba?\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)/.exec(String(v||''));if(!m)return false;var r=+m[1],g=+m[2],b=+m[3],mx=Math.max(r,g,b),mn=Math.min(r,g,b);return r>=55&&r<=125&&g>=48&&g<=115&&b>=38&&b<=105&&(mx-mn)<=32&&r>=g-4&&g>=b-5&&(r-b)>=4;}var E23=document.querySelectorAll('li,div,section,article'),R23=[];for(var i23=0;i23<E23.length&&R23.length<12;i23++){var e23=E23[i23],r23=e23.getBoundingClientRect();if(r23.width<110||r23.height<55)continue;var s23=getComputedStyle(e23),rad23=Math.max(parseFloat(s23.borderTopLeftRadius)||0,parseFloat(s23.borderTopRightRadius)||0,parseFloat(s23.borderBottomLeftRadius)||0,parseFloat(s23.borderBottomRightRadius)||0);if(rad23<4)continue;var hit23=rb23(s23.borderTopColor)||rb23(s23.borderRightColor)||rb23(s23.borderBottomColor)||rb23(s23.borderLeftColor)||rb23(s23.outlineColor);if(!hit23)continue;R23.push(e23.tagName+'.'+String(e23.className||'').replace(/\\s+/g,'.').slice(0,42)+'@y'+Math.round(r23.top)+'/'+Math.round(r23.width)+'x'+Math.round(r23.height)+'|t='+String(s23.borderTopColor||'-')+'|by='+String(e23.__adBy||'-'));}out.push('P23BROWN[n='+R23.length+(R23.length?' '+R23.join(' ~~ '):'')+']');}catch(e23){out.push('P23BROWN[err '+(e23&&e23.message||e23)+']');}"

       "/*V5313FIX*/"
       "try{(function(){"
         "var SEL='[class*=a-cardui-header] *,[class*=a-cardui-header],'"
           "+'[class*=sponsored-products] *,[class*=sponsored-products],'"
           "+'[class*=hybrid-widget-sponsored] *,[class*=adFeedbackMainComponent] *';"
         "function dealText(e){try{var t=String(e.textContent||'').replace(/\\s+/g,' ').trim();return /^(?:\\d+%\\s*off|limited\\s+time\\s+deal|deal\\s+selling\\s+fast)$/i.test(t);}catch(_){return false;}}"
         "function clr(){try{var N=document.querySelectorAll(SEL),c=0,sk=0;"
           "for(var i=0;i<N.length&&i<4000;i++){var e=N[i];"
             "if(e.querySelector&&e.querySelector('img,picture,video'))continue;"
             "if(dealText(e)){sk++;continue;}"
             "var bs=e.style&&e.style.backgroundColor;"
             "if(bs){e.style.setProperty('background-color','transparent','important');c++;}"
             "else{var cs=getComputedStyle(e),L=lum(cs.backgroundColor);"
               "if(L>=0&&L<0.16){e.style.setProperty('background-color','transparent','important');c++;}}}"
           "window.__AD_BOXCLR__=c;window.__AD_BOXCLR_DEALSKIP__=sk;}catch(e){}}"
         // v5.374: Amazon recycles both PDP dot markup and Pack badge children.
         // Key the repair to semantic selected state and the whole badge subtree,
         // not one historical class/leaf. Markers keep the correct paint persistent.
         "function dotFix(){try{var U=document.querySelectorAll('ul.a-pagination.a-dots,[class*=a-pagination][class*=dots]'),n=0,total=0;for(var u=0;u<U.length&&u<8;u++){var D=U[u].querySelectorAll('li');for(var i=0;i<D.length&&i<30;i++){var d=D[i];total++;var cl=String(d.className||''),ac=String(d.getAttribute&&d.getAttribute('aria-current')||'').toLowerCase(),as=String(d.getAttribute&&d.getAttribute('aria-selected')||'').toLowerCase(),ds=String(d.getAttribute&&d.getAttribute('data-selected')||'').toLowerCase(),kid=null;try{kid=d.querySelector('.a-selected,.dot-selected-t2,[aria-current=true],[aria-current=page],[aria-selected=true],[data-selected=true]');}catch(ex){}var sel=/(^|\\s)(a-selected|dot-selected-t2)(\\s|$)/.test(cl)||ac==='true'||ac==='page'||as==='true'||ds==='true'||!!kid;if(sel){if(d.hasAttribute&&d.hasAttribute('data-darkreader-inline-bgcolor'))d.removeAttribute('data-darkreader-inline-bgcolor');d.style.setProperty('--darkreader-inline-bgcolor','#ffffff','important');d.style.setProperty('background-color','#ffffff','important');d.style.setProperty('border-color','#ffffff','important');d.setAttribute('data-ad-dotselected374','1');d.setAttribute('data-ad-dotfix','1');n++;}else{if(d.getAttribute&&d.getAttribute('data-ad-dotfix')==='1'){d.style.removeProperty('--darkreader-inline-bgcolor');d.style.removeProperty('background-color');d.style.removeProperty('border-color');d.removeAttribute('data-ad-dotfix');}d.removeAttribute&&d.removeAttribute('data-ad-dotselected374');}}}window.__AD_DOTFIX__=n;window.__AD_DOTTOTAL374__=total;}catch(e){}}"
         "function packFix(){try{var R=document.querySelectorAll('[class*=pack-size-badge]'),n=0,leaf=0;for(var i=0;i<R.length&&i<40;i++){var r=R[i],A=[r],Q=r.querySelectorAll?r.querySelectorAll('*'):[];for(var q=0;q<Q.length&&q<40;q++)A.push(Q[q]);for(var j=0;j<A.length&&j<44;j++){var p=A[j],tg=String(p.tagName||'').toUpperCase();if(tg==='SVG'||tg==='PATH'||tg==='IMG'||tg==='VIDEO'||tg==='CANVAS')continue;if(p.hasAttribute&&p.hasAttribute('data-darkreader-inline-color'))p.removeAttribute('data-darkreader-inline-color');p.style.setProperty('--darkreader-inline-color','#e8e6e3','important');p.style.setProperty('color','#e8e6e3','important');p.style.setProperty('-webkit-text-fill-color','#e8e6e3','important');p.setAttribute('data-ad-packfix374','1');if(p.childElementCount===0&&String(p.textContent||'').trim())leaf++;n++;}r.setAttribute('data-ad-packroot374','1');}window.__AD_PACKFIX__=n;window.__AD_PACKLEAF374__=leaf;}catch(e){}}"
         // v5.375: Amazon's supplied cards-action asset is not visually stable.
         // Replace its painter with one canonical vector on every qualifying render.
         // v5.377: lists-framework remains the canonical cards/add-to-list action.
         // MLT is a separate compare checkbox and must never receive the circular
         // cards glyph treatment.
         "function compareStock379(){try{var C=document.querySelectorAll('[class*=mlt-icon-container]'),hosts=0,on=0,off=0,leaves=0,nested=0,inputs=0;function pick(h){try{if(h.__adManualUntil379&&Date.now()<h.__adManualUntil379)return !!h.__adManual379;var q=h.querySelector('input[type=checkbox]');if(q&&q.checked)return true;var ac=String(h.getAttribute('aria-checked')||h.getAttribute('data-checked')||h.getAttribute('data-selected')||'').toLowerCase(),cl=h.className;cl=String(cl&&cl.baseVal!==undefined?cl.baseVal:(cl||'')).toLowerCase();if(ac==='true'||/(^|[ _-])(checked|selected|active)([ _-]|$)/.test(cl))return true;var im=h.querySelector('img');if(im&&/checkbox[_-]?(?:on|checked)|checkmark|selected/i.test(String(im.getAttribute('src')||im.getAttribute('data-src')||'')))return true;return false;}catch(e){return false;}}for(var i=0;i<C.length&&i<220;i++){var h=C[i],anc=h.parentElement&&h.parentElement.closest?h.parentElement.closest('[class*=mlt-icon-container]'):null;if(anc){nested++;continue;}var r=h.getBoundingClientRect();if(r.width<18||r.width>70||r.height<18||r.height>70)continue;var sel=pick(h);h.removeAttribute('data-ad-compare378');h.setAttribute('data-ad-compare379',sel?'1':'0');h.style.setProperty('background-color',sel?'#2162a1':'#181a1b','important');h.style.setProperty('border',sel?'1.5px solid #2162a1':'1.5px solid #9aa0a3','important');h.style.setProperty('border-radius','4px','important');h.style.setProperty('box-shadow','none','important');h.style.setProperty('box-sizing','border-box','important');h.removeAttribute('data-ad-comparehost377');h.removeAttribute('data-ad-comparechecked377');var b=h.querySelector(':scope > [data-ad-comparebox377]');if(b&&b.parentNode)b.parentNode.removeChild(b);var inp=h.querySelector('input[type=checkbox]');if(inp){inputs++;inp.setAttribute('data-ad-compareinput379','1');inp.style.setProperty('opacity','0','important');inp.style.setProperty('position','absolute','important');inp.style.setProperty('inset','0','important');inp.style.setProperty('width','100%%','important');inp.style.setProperty('height','100%%','important');inp.style.setProperty('margin','0','important');inp.style.setProperty('z-index','4','important');inp.removeAttribute('data-ad-compareinput377');}var A=h.querySelectorAll('img,i,svg,path,[class*=icon],[class*=image]');for(var j=0;j<A.length&&j<36;j++){var a=A[j];if(a===inp||a.contains&&inp&&a.contains(inp))continue;var ar=a.getBoundingClientRect();if(ar.width>70||ar.height>70)continue;a.setAttribute('data-ad-compareorig379','1');a.style.setProperty('visibility','hidden','important');a.style.setProperty('opacity','0','important');a.style.setProperty('background-color','transparent','important');leaves++;}hosts++;if(sel)on++;else off++;}window.__AD_COMPARE379__='hosts='+hosts+' on='+on+' off='+off+' inputs='+inputs+' nested='+nested+' hidden='+leaves;}catch(e){window.__AD_COMPARE379__='err '+e;}}"
         "function cartChrome379(){try{var tx=String((document.body&&document.body.innerText)||'').toLowerCase();if(tx.indexOf('subtotal')<0||tx.indexOf('save for later')<0){window.__AD_CART379__='off';return;}var E=document.querySelectorAll('button,[role=button],a,span,div,input'),n=0,direct=0;function pc(v){var m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/.exec(String(v||''));return m?[+m[1],+m[2],+m[3]]:null;}function isLight(e){try{var c=getComputedStyle(e),b=getComputedStyle(e,'::before'),a=getComputedStyle(e,'::after'),L=[pc(c.backgroundColor),pc(b.backgroundColor),pc(a.backgroundColor)];for(var k=0;k<L.length;k++){var q=L[k];if(!q)continue;var mx=Math.max(q[0],q[1],q[2]),mn=Math.min(q[0],q[1],q[2]),lum=(.2126*q[0]+.7152*q[1]+.0722*q[2])/255,sat=(mx-mn)/255;if(lum>=.76&&sat<=.16)return true;}return false;}catch(x){return false;}}function paint(e){if(!e||!e.style||e.hasAttribute('data-ad-cartchrome379'))return;e.setAttribute('data-ad-cartchrome379','1');e.style.setProperty('background-color','#181a1b','important');e.style.setProperty('background-image','none','important');e.style.setProperty('border','1px solid #6c7073','important');e.style.setProperty('border-radius','999px','important');e.style.setProperty('box-shadow','none','important');e.style.setProperty('color','#e8e6e3','important');e.style.setProperty('-webkit-text-fill-color','#e8e6e3','important');e.style.setProperty('opacity','1','important');n++;}for(var i=0;i<E.length&&i<2600;i++){var e=E[i],r=e.getBoundingClientRect();if(r.width<36||r.width>150||r.height<24||r.height>62)continue;if(r.bottom<0||r.top>(innerHeight||900)+150)continue;if(!isLight(e))continue;var txt=String(e.textContent||e.value||'').replace(/\\s+/g,' ').trim().toLowerCase();if(/checkout|add to cart|quantity/.test(txt))continue;paint(e);}var D=document.querySelectorAll('button,[role=button],a,span,div');for(var di=0;di<D.length&&di<2200;di++){var de=D[di],dt=String(de.textContent||'').replace(/\\s+/g,' ').trim();if(dt!=='Delete')continue;var dh=de.closest&&de.closest('button,[role=button],a');if(!dh)dh=de;var dr=dh.getBoundingClientRect(),best=null,bd=999,seen=[];for(var ci=0;ci<E.length&&ci<2600;ci++){var x=E[ci],host=(x.closest&&x.closest('button,[role=button],a'))||x;if(!host||host===dh||dh.contains(host)||seen.indexOf(host)>=0)continue;seen.push(host);var xr=host.getBoundingClientRect();if(xr.width<34||xr.width>125||xr.height<24||xr.height>60)continue;if(Math.abs((xr.top+xr.height/2)-(dr.top+dr.height/2))>14||xr.left<dr.right-4)continue;var gap=xr.left-dr.right;if(gap<0||gap>170||gap>=bd)continue;var xt=String(host.textContent||host.value||'').replace(/\\s+/g,' ').trim().toLowerCase();if(/delete|save for later|checkout|add to cart|quantity/.test(xt))continue;if(!isLight(host))continue;best=host;bd=gap;}if(best){paint(best);best.setAttribute('data-ad-cartdirect379','1');direct++;}}window.__AD_CART379__='fixed='+n+' direct='+direct;}catch(e){window.__AD_CART379__='err '+e;}}"
         "function legacyCompare387(){try{var C=document.querySelectorAll('i.a-icon-checkbox,[class*=a-icon-checkbox]'),hosts=[],orig=0,on=0,off=0,skip=0;function sq(e){if(!e||!e.getBoundingClientRect)return false;var r=e.getBoundingClientRect();return r.width>=24&&r.width<=44&&r.height>=24&&r.height<=44&&Math.abs(r.width-r.height)<=8;}function selected(e){var p=e,u=0;while(p&&u++<4){var a=String(p.getAttribute&&p.getAttribute('aria-checked')||p.getAttribute&&p.getAttribute('data-checked')||p.getAttribute&&p.getAttribute('data-selected')||'').toLowerCase(),c=String(p.className&&p.className.baseVal!==undefined?p.className.baseVal:(p.className||'')).toLowerCase();if(a==='true'||/(^|[ _-])(checked|selected|active)([ _-]|$)/.test(c))return true;if(a==='false')return false;p=p.parentElement;}return false;}for(var i=0;i<C.length&&i<240;i++){var x=C[i];if(x.closest&&x.closest('[data-ad-compare380],[class*=mlt-icon-container],[class*=lists-framework-action-button],[class*=heart],[class*=wish],[class*=favorite]')){skip++;continue;}var card=x.closest&&x.closest('[class*=puis-card],[class*=s-result-item],[data-asin],[class*=product-image]');if(!card){skip++;continue;}var p=x,best=null,u=0;while(p&&p!==card&&u++<6){if(sq(p))best=p;p=p.parentElement;}if(!best){skip++;continue;}if(hosts.indexOf(best)>=0)continue;hosts.push(best);var sel=selected(x);best.setAttribute('data-ad-comparelegacy387',sel?'1':'0');best.style.setProperty('background-color','transparent','important');best.style.setProperty('border','0','important');best.style.setProperty('box-shadow','none','important');x.setAttribute('data-ad-comparelegacyorig387','1');orig++;if(sel)on++;else off++;}window.__AD_COMPARELEGACY387__='hosts='+hosts.length+' orig='+orig+' on='+on+' off='+off+' skip='+skip;}catch(e){window.__AD_COMPARELEGACY387__='err '+e;}}"
         "function compareStock380(){try{var C=document.querySelectorAll('[class*=mlt-icon-container],[role=checkbox],input[type=checkbox]'),hosts=[],on=0,off=0,inputs=0,hidden=0,skip=0;function sig(h){try{var card=h.closest&&h.closest('[data-asin]');if(card&&card.getAttribute('data-asin'))return 'a:'+card.getAttribute('data-asin');var p=h.parentElement,u=0;while(p&&u++<5){var im=p.querySelector&&p.querySelector('img[src],img[data-src]');if(im){var z=String(im.currentSrc||im.src||im.getAttribute('data-src')||'');if(z)return 'i:'+z.slice(-80);}p=p.parentElement;}}catch(e){}return '';}function actual(h){try{var q=h.querySelector('input[type=checkbox]');if(q)return !!q.checked;var ar=String(h.getAttribute('aria-checked')||h.getAttribute('data-checked')||h.getAttribute('data-selected')||'').toLowerCase();if(ar==='true')return true;if(ar==='false')return false;var cl=String(h.className&&h.className.baseVal!==undefined?h.className.baseVal:(h.className||'')).toLowerCase();if(/(^|[ _-])(checked|selected|active)([ _-]|$)/.test(cl))return true;var im=h.querySelector('img');var src=im?String(im.getAttribute('src')||im.getAttribute('data-src')||'').toLowerCase():'';if(/checkbox[_-]?(?:on|checked)|checkmark|selected/.test(src))return true;if(/checkbox[_-]?(?:off|unchecked)/.test(src))return false;}catch(e){}return null;}function outer(e){var h=e&&e.nodeType===1?e:null;if(h&&String(h.tagName||'').toUpperCase()==='INPUT')h=h.parentElement;var best=null,p=h,u=0;while(p&&u++<6){var r=p.getBoundingClientRect();if(r.width>=24&&r.width<=44&&r.height>=24&&r.height<=44&&Math.abs(r.width-r.height)<=8)best=p;var pc=String(p.className&&p.className.baseVal!==undefined?p.className.baseVal:(p.className||''));if(/mlt-icon-container/i.test(pc)&&best)break;p=p.parentElement;}return best;}for(var i=0;i<C.length&&i<360;i++){var h=outer(C[i]);if(!h||hosts.indexOf(h)>=0){skip++;continue;}var near=h.closest&&h.closest('[class*=puis-card],[class*=s-result-item],[data-asin],[class*=product-image]');var hc=String(h.className&&h.className.baseVal!==undefined?h.className.baseVal:(h.className||''));if(!near&&!/mlt-icon-container/i.test(hc)){skip++;continue;}hosts.push(h);var hs=sig(h);if(h.__adManualSig380&&h.__adManualSig380!==hs){delete h.__adManual380;delete h.__adManualSig380;}var a=actual(h),sel=(a===null?(h.__adManual380===1):a);h.removeAttribute('data-ad-compare378');h.removeAttribute('data-ad-compare379');h.setAttribute('data-ad-compare380',sel?'1':'0');h.style.setProperty('background-color','transparent','important');h.style.setProperty('border','0','important');h.style.setProperty('box-shadow','none','important');h.style.setProperty('border-radius','4px','important');var old=h.querySelectorAll('[data-ad-compareorig379],[data-ad-compareorig378]');for(var o=0;o<old.length;o++){old[o].style.removeProperty('visibility');old[o].style.removeProperty('opacity');old[o].removeAttribute('data-ad-compareorig379');old[o].removeAttribute('data-ad-compareorig378');}var inp=h.querySelector('input[type=checkbox]');if(inp){inputs++;inp.setAttribute('data-ad-compareinput380','1');}var A=h.querySelectorAll('img,i,svg,path,[class*=icon],[class*=image]');for(var j=0;j<A.length&&j<48;j++){var x=A[j];if(inp&&(x===inp||x.contains&&x.contains(inp)))continue;var r=x.getBoundingClientRect();if(r.width>48||r.height>48)continue;x.setAttribute('data-ad-compareorig380','1');hidden++;}if(sel)on++;else off++;}window.__AD_COMPARE380__='hosts='+hosts.length+' on='+on+' off='+off+' inputs='+inputs+' hidden='+hidden+' skip='+skip;}catch(e){window.__AD_COMPARE380__='err '+e;}}"
         "function cartChrome382(){try{var D=document.querySelectorAll('button,[role=button],a,span,div'),share=0,rows=0;function hostOf(e){if(!e)return null;return (e.closest&&e.closest('button,[role=button],a'))||e;}function exact(root,word){var Q=root.querySelectorAll('button,[role=button],a,span,div');for(var i=0;i<Q.length&&i<220;i++){if(String(Q[i].textContent||'').replace(/\\s+/g,' ').trim()===word)return Q[i];}return null;}for(var di=0;di<D.length&&di<3200;di++){var de=D[di];if(String(de.textContent||'').replace(/\\s+/g,' ').trim()!=='Delete')continue;var dh=hostOf(de),row=dh.parentElement,u=0;while(row&&u++<6){var tx=String(row.textContent||'').replace(/\\s+/g,' ').trim();if(/Save for later/i.test(tx)&&/Delete/i.test(tx)&&/Share/i.test(tx))break;row=row.parentElement;}if(!row)continue;rows++;var se=exact(row,'Share');if(!se)continue;var sh=hostOf(se),dr=dh.getBoundingClientRect(),sr=sh.getBoundingClientRect();if(sr.width<34||sr.width>150||sr.height<20||sr.height>64||Math.abs((sr.top+sr.height/2)-(dr.top+dr.height/2))>24)continue;var ds=getComputedStyle(dh),fg=String(ds.color||'#e8e6e3');sh.removeAttribute('data-ad-cartshare381');sh.removeAttribute('data-ad-cartchrome380');sh.setAttribute('data-ad-cartclone382','1');sh.style.setProperty('--ad-cart-bg',String(ds.backgroundColor||'transparent'));sh.style.setProperty('--ad-cart-bi',String(ds.backgroundImage||'none'));sh.style.setProperty('--ad-cart-bc',String(ds.borderTopColor||'#6c7073'));sh.style.setProperty('--ad-cart-bs',String(ds.borderTopStyle||'solid'));sh.style.setProperty('--ad-cart-bw',String(ds.borderTopWidth||'1px'));sh.style.setProperty('--ad-cart-br',String(ds.borderRadius||'999px'));sh.style.setProperty('--ad-cart-sh',String(ds.boxShadow||'none'));sh.style.setProperty('--ad-cart-fg',fg);sh.style.setProperty('background-color',String(ds.backgroundColor||'transparent'),'important');sh.style.setProperty('background-image',String(ds.backgroundImage||'none'),'important');sh.style.setProperty('border-color',String(ds.borderTopColor||'#6c7073'),'important');sh.style.setProperty('border-style',String(ds.borderTopStyle||'solid'),'important');sh.style.setProperty('border-width',String(ds.borderTopWidth||'1px'),'important');sh.style.setProperty('border-radius',String(ds.borderRadius||'999px'),'important');sh.style.setProperty('box-shadow',String(ds.boxShadow||'none'),'important');sh.style.setProperty('color',fg,'important');sh.style.setProperty('-webkit-text-fill-color',fg,'important');share++;break;}window.__AD_CART382__='rows='+rows+' share='+share;}catch(e){window.__AD_CART382__='err '+e;}}"
         "function shareFix382(){try{var S=document.querySelectorAll('.ssf-share-trigger'),hosts=0,paint=0,vec=0;for(var i=0;i<S.length&&i<20;i++){var h=S[i],r=h.getBoundingClientRect();if(r.width<8||r.height<8)continue;hosts++;h.removeAttribute('data-ad-share377');h.setAttribute('data-ad-share382','1');h.style.setProperty('color','#fff','important');h.style.setProperty('-webkit-text-fill-color','#fff','important');h.style.setProperty('opacity','1','important');var A=h.querySelectorAll('*');for(var j=0;j<A.length&&j<90;j++){var a=A[j],ar=a.getBoundingClientRect();if(ar.width>100||ar.height>100)continue;var tg=String(a.tagName||'').toUpperCase(),cs=getComputedStyle(a),bi=String(cs.backgroundImage||'none'),mi=String(cs.maskImage||cs.webkitMaskImage||'none');if(tg==='SVG'||tg==='PATH'||tg==='POLYGON'||tg==='USE'){a.style.setProperty('fill','#fff','important');a.style.setProperty('stroke','#fff','important');a.style.setProperty('color','#fff','important');a.style.setProperty('opacity','1','important');vec++;continue;}if(tg==='IMG'||tg==='I'||bi!=='none'||mi!=='none'){a.setAttribute('data-ad-sharepaint382','1');a.style.setProperty('opacity','1','important');a.style.setProperty('background-color','transparent','important');a.__adGlyph=1;a.__adBy='share382';paint++;}}}window.__AD_SHARE382__='hosts='+hosts+' paint='+paint+' vec='+vec;}catch(e){window.__AD_SHARE382__='err '+e;}}"
         "function chevronFix383(){try{var Q=document.querySelectorAll('[aria-label*=expand i],[aria-label*=collapse i],[aria-label*=details i],[aria-expanded] [class*=a-icon],[aria-expanded][class*=a-icon],[class*=a-icon-extender],[class*=a-icon-dropdown],[class*=expander] [class*=a-icon],[class*=expand] [class*=a-icon],[class*=collapse] [class*=a-icon],button [class*=chevron],button [class*=caret],button [class*=arrow],[role=button] [class*=chevron],[role=button] [class*=caret],[role=button] [class*=arrow]'),n=0,sk=0;function bad(e){return !!(e&&e.closest&&e.closest('[class*=heart],[class*=wish],[class*=favorite],[class*=lists-framework-action-button],[class*=mlt-icon-container],[role=checkbox],input[type=checkbox]'));}function mark(e){if(!e||!e.setAttribute||bad(e))return;var r=e.getBoundingClientRect();if(r.width<3||r.height<3||r.width>72||r.height>72)return;e.setAttribute('data-ad-expchev383','1');e.__adGlyph=1;e.__adBy='expchev383';var tg=String(e.tagName||'').toUpperCase();if(tg==='SVG'||tg==='PATH'||tg==='POLYGON'||tg==='USE'){e.style.setProperty('color','#e8e6e3','important');e.style.setProperty('fill','#e8e6e3','important');e.style.setProperty('stroke','#e8e6e3','important');}n++;}for(var i=0;i<Q.length&&i<260;i++){var e=Q[i];if(bad(e)){sk++;continue;}mark(e);var A=e.querySelectorAll?e.querySelectorAll('svg,path,i,img,[class*=chevron],[class*=caret],[class*=arrow],[class*=a-icon]'):[];for(var j=0;j<A.length&&j<12;j++)mark(A[j]);}window.__AD_CHEV383__='n='+n+' skip='+sk;}catch(e){window.__AD_CHEV383__='err '+e;}}"
         "function sponsorFix376(){try{var E=document.querySelectorAll('span,div,p,a,h1,h2,h3,h4,h5,label'),n=0,dark=0;for(var i=0;i<E.length&&i<5000;i++){var e=E[i],t=String(e.textContent||'').replace(/\\s+/g,' ').trim();if(!/^sponsored(?: ad)?$/i.test(t))continue;if(e.childElementCount>4)continue;var cs=getComputedStyle(e),m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/.exec(String(cs.color||''));if(m&&(0.2126*(+m[1])+0.7152*(+m[2])+0.0722*(+m[3]))<220)dark++;e.style.setProperty('color','#ffffff','important');e.style.setProperty('-webkit-text-fill-color','#ffffff','important');e.style.setProperty('opacity','1','important');e.style.setProperty('visibility','visible','important');e.setAttribute('data-ad-sponsored376','1');e.__adBy='sponsored376';n++;}window.__AD_SPON376__='n='+n+' darkBefore='+dark;}catch(e){window.__AD_SPON376__='err '+e;}}"
         "function ratingFix376(){try{var A=document.querySelectorAll('[aria-label*=\"out of 5 stars\"],[class*=a-icon-star],[class*=a-star],[id*=acrCustomerReviewText],[class*=acrCustomerReviewText],[class*=averageStarRating]'),roots=[],n=0;for(var i=0;i<A.length&&i<500;i++){var a=A[i],r=a,p=0;while(r&&p++<4){var tx=String(r.textContent||'').replace(/\\s+/g,' ').trim(),rr=r.getBoundingClientRect();if(tx.length>=2&&tx.length<=140&&rr.height>4&&rr.height<=90&&(/\\d(?:\\.\\d)?/.test(tx))){break;}r=r.parentElement;}if(!r||roots.indexOf(r)>=0)continue;roots.push(r);var L=r.querySelectorAll('span,a,div');for(var j=0;j<L.length&&j<80;j++){var x=L[j];if(x.childElementCount>0)continue;var t=String(x.textContent||'').replace(/\\s+/g,' ').trim();if(!t||t.length>42)continue;var ok=/^\\d(?:\\.\\d)?$/.test(t)||/^\\(?[\\d,.]+[Kk]?\\)?$/.test(t)||/^\\d(?:\\.\\d)?\\s+out of 5 stars$/i.test(t);if(!ok)continue;x.style.setProperty('color','#ffffff','important');x.style.setProperty('-webkit-text-fill-color','#ffffff','important');x.style.setProperty('opacity','1','important');x.style.setProperty('visibility','visible','important');x.setAttribute('data-ad-rating376','1');x.__adBy='rating376';n++;}}window.__AD_RATING376__='roots='+roots.length+' ink='+n;}catch(e){window.__AD_RATING376__='err '+e;}}"
         // v5.347 PDP HEART. The confirmed 20x20 .a-icon painter is handled
         // exclusively by the documentStart CSS rule above. Do not mutate its
         // filter from JS: the regression gate correctly requires artwork guards
         // for dynamic filter writers, while this named Amazon chrome glyph is
         // safer and earlier as a selector-only CSS exception.
         "function homeAmbient386(){try{if(window.__ADFRAME_MODE__||!document.body){window.__AD_HOMEAMBIENT386__='off';return 0;}var SEL='[class*=\"_hp-mosaic-container_style_widgetContainer\"],[class*=\"_mosaic-container_style_widgetContainer\"],[class*=\"gwm-dashboard-container\"],[class*=\"gwm-window-layout\"],[class*=\"gwm-asin-tile\"]',S=document.querySelectorAll(SEL);if(S.length<2){window.__AD_HOMEAMBIENT386__='home=0';return 0;}function pc(v){var m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([0-9.]+))?/i.exec(String(v||''));return m?[+m[1],+m[2],+m[3],m[4]===undefined?1:+m[4]]:null;}function sat(q){return q?(Math.max(q[0],q[1],q[2])-Math.min(q[0],q[1],q[2]))/255:0;}var seen=[],n=0,left=0,W=innerWidth||390,H=innerHeight||700;function fix(e){if(!e||seen.indexOf(e)>=0)return;seen.push(e);var r=e.getBoundingClientRect();if(r.width<W*.82||r.height<H*.55)return;var cl=String(e.className&&e.className.baseVal!==undefined?e.className.baseVal:(e.className||'')).toLowerCase();if(/carousel|hero|slideshow|swiper|swipe|creative|product-image|image-container/.test(cl))return;var cs=getComputedStyle(e),bg=pc(cs.backgroundColor),bi=String(cs.backgroundImage||'none'),grad=/gradient\\(/i.test(bi)&&bi.indexOf('url(')<0,hot=!!(bg&&bg[3]>.35&&sat(bg)>.12);if(!hot&&!grad)return;e.setAttribute('data-ad-homeambient386','1');e.style.setProperty('background-color','#181a1b','important');if(grad)e.style.setProperty('background-image','none','important');n++;}fix(document.documentElement);fix(document.body);for(var i=0;i<S.length&&i<10;i++){var p=S[i].parentElement,u=0;while(p&&u++<8){fix(p);if(p===document.body)break;p=p.parentElement;}}var Q=document.querySelectorAll('[data-ad-homeambient386]');for(var j=0;j<Q.length;j++){var c=getComputedStyle(Q[j]),q=pc(c.backgroundColor),b=String(c.backgroundImage||'none');if((q&&q[3]>.35&&sat(q)>.12)||(/gradient\\(/i.test(b)&&b.indexOf('url(')<0))left++;}window.__AD_HOMEAMBIENT386__='home=1 fixed='+n+' left='+left+' seeds='+S.length;return n;}catch(e){window.__AD_HOMEAMBIENT386__='err '+e;return 0;}}"
         "function badgeFix(){try{"
           "var B=document.querySelectorAll('[class*=badgeLabel]');for(var i=0;i<B.length&&i<200;i++){var b=B[i];if(b.hasAttribute&&b.hasAttribute('data-darkreader-inline-bgcolor')){b.style.removeProperty('background-color');b.removeAttribute('data-darkreader-inline-bgcolor');}b.style.setProperty('background-color','#cc0c39','important');b.style.setProperty('color','#ffffff','important');b.style.setProperty('-webkit-text-fill-color','#ffffff','important');}"
           "var S=document.querySelectorAll('[class*=sponsored-products] *,[class*=npack-asin-card] *,[class*=cXVhZ] *'),n=0;for(var j=0;j<S.length&&j<2500&&n<80;j++){var x=S[j];if(x.childElementCount!==0)continue;var t=String(x.textContent||'').replace(/\\s+/g,' ').trim();"
             "if(/^\\d+%\\s*off$/i.test(t)){var p=x.parentElement;if(p){p.style.setProperty('background-color','#cc0c39','important');p.style.setProperty('color','#ffffff','important');p.style.setProperty('-webkit-text-fill-color','#ffffff','important');}x.style.setProperty('color','#ffffff','important');x.style.setProperty('-webkit-text-fill-color','#ffffff','important');n++;}"
             "else if(/^(?:limited\\s+time\\s+deal|deal\\s+selling\\s+fast)$/i.test(t)){x.style.setProperty('color','#e8e6e3','important');x.style.setProperty('-webkit-text-fill-color','#e8e6e3','important');if(x.closest&&(x.closest('[class*=npack-asin-card]')||x.closest('[class*=cXVhZ]'))){var m=x.closest('[class*=badgeMessage]')||x.parentElement;if(m){m.style.setProperty('background-color','#181a1b','important');m.style.setProperty('background-image','none','important');m.style.setProperty('box-shadow','none','important');}x.style.setProperty('background-color','#181a1b','important');x.style.setProperty('background-image','none','important');x.style.setProperty('box-shadow','none','important');}n++;}}window.__AD_SPONSORED_BADGEFIX__=n;"
         "}catch(e){}}""homeAmbient386();badgeFix();dotFix();packFix();compareStock380();legacyCompare387();cartChrome382();shareFix382();chevronFix383();sponsorFix376();ratingFix376();try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}try{if(window._adHomeVideo391)window._adHomeVideo391();}catch(e){}""clr();setTimeout(clr,300);setTimeout(clr,1200);setTimeout(clr,2500);""setTimeout(homeAmbient386,300);setTimeout(homeAmbient386,1200);setTimeout(homeAmbient386,2500);""setTimeout(badgeFix,300);setTimeout(badgeFix,1200);setTimeout(badgeFix,2500);""setTimeout(dotFix,120);setTimeout(dotFix,500);setTimeout(dotFix,1400);setTimeout(dotFix,2800);""setTimeout(packFix,120);setTimeout(packFix,500);setTimeout(packFix,1400);setTimeout(packFix,2800);setTimeout(compareStock380,0);setTimeout(compareStock380,120);setTimeout(compareStock380,500);setTimeout(compareStock380,1500);setTimeout(function(){try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}},20);setTimeout(function(){try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}},180);setTimeout(function(){try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}},700);setTimeout(legacyCompare387,0);setTimeout(legacyCompare387,120);setTimeout(legacyCompare387,500);setTimeout(legacyCompare387,1500);setTimeout(function(){try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}},60);setTimeout(function(){try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}},220);setTimeout(function(){try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}},650);setTimeout(function(){try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}},1650);setTimeout(function(){try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}},2600);setTimeout(cartChrome382,20);setTimeout(cartChrome382,180);setTimeout(cartChrome382,700);setTimeout(cartChrome382,1800);setTimeout(sponsorFix376,20);setTimeout(sponsorFix376,180);setTimeout(sponsorFix376,700);setTimeout(sponsorFix376,1800);setTimeout(ratingFix376,40);setTimeout(ratingFix376,240);setTimeout(ratingFix376,900);setTimeout(ratingFix376,2200);setTimeout(shareFix382,40);setTimeout(shareFix382,180);setTimeout(shareFix382,700);setTimeout(shareFix382,1800);setTimeout(chevronFix383,20);setTimeout(chevronFix383,180);setTimeout(chevronFix383,700);setTimeout(chevronFix383,1800);addEventListener('scroll',function(){clearTimeout(window.__bgT);window.__bgT=setTimeout(function(){homeAmbient386();badgeFix();dotFix();packFix();compareStock380();legacyCompare387();cartChrome382();shareFix382();chevronFix383();sponsorFix376();ratingFix376();try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}try{if(window._adHomeVideo391)window._adHomeVideo391();}catch(e){}},100);},{passive:true,capture:true});""addEventListener('scroll',function(){clearTimeout(window.__bxS);window.__bxS=setTimeout(clr,120);},{passive:true,capture:true});"
         "new MutationObserver(function(){clearTimeout(window.__bxT);"
           "window.__bxT=setTimeout(function(){clr();dotFix();packFix();compareStock380();legacyCompare387();cartChrome382();shareFix382();chevronFix383();sponsorFix376();ratingFix376();try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(e){}},20);}).observe(document.documentElement,"
           "{subtree:true,childList:true,attributes:true,attributeFilter:['style','class','aria-current','aria-selected','data-selected','src','data-src','data-darkreader-inline-bgcolor','data-darkreader-inline-color','fill','stroke']});"
         "try{new MutationObserver(function(){try{cartChrome382();}catch(e){}}).observe(document.documentElement,{subtree:true,childList:true});}catch(e){}"
         "try{document.addEventListener('change',function(e){try{if(e&&e.target&&(String(e.target.type||'').toLowerCase()==='checkbox'||(e.target.closest&&e.target.closest('[data-ad-compare380],[class*=mlt-icon-container]'))))setTimeout(compareStock380,0);}catch(x){}},true);document.addEventListener('click',function(e){try{if(!e||!e.target||!e.target.closest)return;var h=e.target.closest('[data-ad-compare380]');if(!h){var m=e.target.closest('[class*=mlt-icon-container]');while(m&&m.parentElement&&m.parentElement.closest&&m.parentElement.closest('[class*=mlt-icon-container]'))m=m.parentElement.closest('[class*=mlt-icon-container]');h=m;}if(!h)return;var cur=String(h.getAttribute('data-ad-compare380')||'0')==='1';h.__adManual380=cur?0:1;var card=h.closest&&h.closest('[data-asin]');h.__adManualSig380=card&&card.getAttribute('data-asin')?'a:'+card.getAttribute('data-asin'):'';h.setAttribute('data-ad-compare380',cur?'0':'1');setTimeout(compareStock380,0);setTimeout(compareStock380,120);setTimeout(compareStock380,500);setTimeout(function(){try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(z){}},10);setTimeout(function(){try{if(window.__AD_PRODUCTCTRL391RUN__)window.__AD_PRODUCTCTRL391RUN__();}catch(z){}},140);}catch(x){}},true);}catch(e){}"
       "})();}catch(e){}"
       "/*V5395FIX*//*V5394FIX*//*V5314FIX*//*V5315FIX*/"
"/*V5317FIX*//*V5376FIX*//*V5377FIX*//*V5378FIX*//*V5379FIX*//*V5380FIX*//*V5381FIX*//*V5382FIX*//*V5383FIX*//*V5384FIX*//*V5385FIX*//*V5386FIX*//*V5387FIX*//*V5388FIX*//*V5391FIX*//*V5393FIX*/"
       "try{var R=[],EL=document.querySelectorAll('*');"
         "for(var q=0;q<EL.length&&R.length<8;q++){var e=EL[q];"
           "var t=String(e.textContent||'').trim();"
           "var r=e.getBoundingClientRect();if(r.width<8||r.height<6)continue;"
           "if(r.bottom<0||r.top>(window.innerHeight||900))continue;"
           "var st=getComputedStyle(e);"
           "if(e.childElementCount>0)continue;if(t.length<4||t.length>34)continue;var fz=parseFloat(st.fontSize)||0;if(fz<15)continue;"
           "var ch=[],n=e,d=0;while(n&&d<4){ch.push((cls(n)||n.tagName).slice(0,20));n=n.parentElement;d++;}"
           "var op=1,fl='-',an=e,dd=0;while(an&&dd<5){var as=getComputedStyle(an);op*=parseFloat(as.opacity||1);if(as.filter&&as.filter!=='none')fl=as.filter.slice(0,18);an=an.parentElement;dd++;}"
             "R.push(t.slice(0,14)+'|'+e.tagName+'|op='+op.toFixed(2)+'|f='+fl+'|'+Math.round(r.width)+'x'+Math.round(r.height)"
             "+'|bg='+st.backgroundColor+'|col='+st.color+'|fs='+fz.toFixed(0)+'|'+ch.join('>'));}"
         "out.push('~~P9HEADER[sub='+(__sub?1:0)+' '+(R.length?R.join(' ~ '):'none')+']');}catch(x){out.push('P9HEADER[err]');}"
       "try{var R=[],EL=document.querySelectorAll('*');"
         "for(var q=0;q<EL.length&&R.length<8;q++){var e=EL[q];"
           "var t=String(e.textContent||'').trim();"
           "var r=e.getBoundingClientRect();if(r.width<8||r.height<6)continue;"
           "if(r.bottom<0||r.top>(window.innerHeight||900))continue;"
           "var st=getComputedStyle(e);"
           "if(t.indexOf('%')<0||t.length>14)continue;if(e.childElementCount>2)continue;"
           "var ch=[],n=e,d=0;while(n&&d<4){ch.push((cls(n)||n.tagName).slice(0,20));n=n.parentElement;d++;}"
           "var op2=1,fl2='-',a2=e,d2=0;while(a2&&d2<5){var s2=getComputedStyle(a2);op2*=parseFloat(s2.opacity||1);if(s2.filter&&s2.filter!=='none')fl2=s2.filter.slice(0,18);a2=a2.parentElement;d2++;}"
             "R.push(t.slice(0,14)+'|'+e.tagName+'|op='+op2.toFixed(2)+'|f='+fl2+'|'+Math.round(r.width)+'x'+Math.round(r.height)"
             "+'|bg='+st.backgroundColor+'|col='+st.color+'|'+ch.join('>'));}"
         "out.push('P9PCT[sub='+(__sub?1:0)+' '+(R.length?R.join(' ~ '):'none')+']');}catch(x){out.push('P9PCT[err]');}"
       "try{var R=[],EL=document.querySelectorAll('*');"
         "for(var q=0;q<EL.length&&R.length<8;q++){var e=EL[q];"
           "var t=String(e.textContent||'').trim();"
           "var r=e.getBoundingClientRect();if(r.width<8||r.height<6)continue;"
           "if(r.bottom<0||r.top>(window.innerHeight||900))continue;"
           "var st=getComputedStyle(e);"
           "if(t.charAt(0)!=='$'||t.length>12)continue;if(e.childElementCount>2)continue;"
           "var ch=[],n=e,d=0;while(n&&d<4){ch.push((cls(n)||n.tagName).slice(0,20));n=n.parentElement;d++;}"
           "R.push(t.slice(0,14)+'|'+e.tagName+'|'+Math.round(r.width)+'x'+Math.round(r.height)"
             "+'|bg='+st.backgroundColor+'|col='+st.color+'|'+ch.join('>'));}"
         "out.push('P9DOLLAR[sub='+(__sub?1:0)+' '+(R.length?R.join(' ~ '):'none')+']');}catch(x){out.push('P9DOLLAR[err]');}"
       "try{var R=[],EL=document.querySelectorAll('*');"
         "for(var q=0;q<EL.length&&R.length<8;q++){var e=EL[q];"
           "var t=String(e.textContent||'').trim();"
           "var r=e.getBoundingClientRect();if(r.width<8||r.height<6)continue;"
           "if(r.bottom<0||r.top>(window.innerHeight||900))continue;"
           "var st=getComputedStyle(e);"
           "if(t.toLowerCase().indexOf('sponsor')<0||t.length>18)continue;"
           "var ch=[],n=e,d=0;while(n&&d<4){ch.push((cls(n)||n.tagName).slice(0,20));n=n.parentElement;d++;}"
           "R.push(t.slice(0,14)+'|'+e.tagName+'|'+Math.round(r.width)+'x'+Math.round(r.height)"
             "+'|bg='+st.backgroundColor+'|col='+st.color+'|'+ch.join('>'));}"
         "out.push('P9SPON[sub='+(__sub?1:0)+' '+(R.length?R.join(' ~ '):'none')+']');}catch(x){out.push('P9SPON[err]');}"
       // P24TAME (v5.361): media filters and background-only blend taming.
       "try{var T24=[],E24=document.querySelectorAll('*'),V24=window.innerHeight||900;for(var i24=0;i24<E24.length&&T24.length<24;i24++){var e24=E24[i24],f24=e24.hasAttribute&&e24.hasAttribute('data-ad-tame-fast362'),b24=e24.hasAttribute&&e24.hasAttribute('data-ad-tame-bgfast364');if(!e24.__adTamed&&!f24&&!b24)continue;var r24=e24.getBoundingClientRect();if(r24.width<28||r24.height<28||r24.bottom<0||r24.top>V24*2)continue;var s24=getComputedStyle(e24),c24=e24.className;if(c24&&c24.baseVal!==undefined)c24=c24.baseVal;T24.push(e24.tagName+'.'+String(c24||'').replace(/\\s+/g,'.').slice(0,28)+'@'+Math.round(r24.width)+'x'+Math.round(r24.height)+'|f='+String(s24.filter||'none').replace(/\\s+/g,' ').slice(0,26)+'|blend='+String(s24.backgroundBlendMode||'-').slice(0,12)+'|fast='+(f24?'m':'-')+(b24?'b':'-')+'|by='+(e24.__adBy||'-'));}out.push('P24TAME[n='+T24.length+(T24.length?' '+T24.join(' ~~ '):'')+']');}catch(e24x){out.push('P24TAME[err '+(e24x&&e24x.message||e24x)+']');}"
       // P27VID (v5.362): confirm stock black play/pause backing was restored.
       "try{var A27=document.querySelectorAll('[data-ad-videoctl362]'),Q27=[];for(var i27=0;i27<A27.length&&i27<12;i27++){var e27=A27[i27],r27=e27.getBoundingClientRect(),s27=getComputedStyle(e27);Q27.push(e27.tagName+'@'+Math.round(r27.left)+','+Math.round(r27.top)+'/'+Math.round(r27.width)+'x'+Math.round(r27.height)+'|bg='+String(s27.backgroundColor||'-').replace(/ /g,'')+'|by='+(e27.__adBy||'-'));}out.push('P27VID[n='+Q27.length+(Q27.length?' '+Q27.join(' ~~ '):'')+']');}catch(e27){out.push('P27VID[err '+(e27&&e27.message||e27)+']');}"

       // P30INK (v5.363): exact readability pins without touching creative copy.
       "try{var A30=document.querySelectorAll('[data-ad-yml-head363],[data-ad-sponsored-light363]'),Q30=[];for(var i30=0;i30<A30.length&&i30<18;i30++){var e30=A30[i30],s30=getComputedStyle(e30),t30=String(e30.textContent||'').replace(/\\s+/g,' ').trim();Q30.push(t30.slice(0,22)+'|c='+String(s30.color||'-').replace(/ /g,'')+'|fill='+String(s30.webkitTextFillColor||'-').replace(/ /g,'')+'|by='+(e30.__adBy||'-'));}out.push('P30INK[n='+Q30.length+(Q30.length?' '+Q30.join(' ~~ '):'')+']');}catch(e30){out.push('P30INK[err '+(e30&&e30.message||e30)+']');}"
       // P31FIX (v5.367): narrow cleanup markers.
       "try{var pa31=document.querySelectorAll('[data-ad-productad367]').length,ri31=document.querySelectorAll('[data-ad-reviewink367]').length,bf31=document.querySelectorAll('[data-ad-border-section=\"fast367\"],[data-ad-border-section=\"fast368\"]').length,be31=document.querySelectorAll('[data-ad-border-section=\"exact370\"],[data-ad-border-section=\"exact371\"]').length,pf31=document.querySelectorAll('iframe[data-ad-frame-mode362=\"productad\"]').length;out.push('P31FIX[productAd='+pa31+' productFrame='+pf31+' reviewInk='+ri31+' borderFast='+bf31+' borderExact='+be31+']');}catch(e31){out.push('P31FIX[err '+(e31&&e31.message||e31)+']');}"
       "try{var P32=document.querySelectorAll('iframe[data-ad-frame-mode362=\"productad\"]'),R32=[];for(var i32=0;i32<P32.length&&i32<8;i32++){var f32=P32[i32],r32=f32.getBoundingClientRect();R32.push(String(f32.getAttribute('data-ad-frame-why369')||'-')+'@'+Math.round(r32.left)+','+Math.round(r32.top)+'/'+Math.round(r32.width)+'x'+Math.round(r32.height));}out.push('P32V374[productDoc='+String(window.__AD_PRODUCTDOC369__||0)+' productFrame='+P32.length+(R32.length?' '+R32.join(' ~~ '):'')+']');}catch(e32){out.push('P32V374[err '+(e32&&e32.message||e32)+']');}"
       "try{var A33=document.querySelectorAll('[class*=_hp-mosaic-container_style_widgetContainer],[class*=_mosaic-container_style_widgetContainer]'),Q33=[];for(var i33=0;i33<A33.length&&i33<10;i33++){var e33=A33[i33],r33=e33.getBoundingClientRect(),s33=getComputedStyle(e33);if(r33.width<100||r33.height<50)continue;Q33.push(e33.tagName+'.'+cls(e33)+'@'+Math.round(r33.top)+'/'+Math.round(r33.width)+'x'+Math.round(r33.height)+'|t='+String(s33.borderTopColor||'-').replace(/ /g,'')+'|sec='+String(e33.getAttribute('data-ad-border-section')||'-')+'|by='+(e33.__adBy||'-'));}out.push('P33V374[n='+Q33.length+(Q33.length?' '+Q33.join(' ~~ '):'')+']');}catch(e33){out.push('P33V374[err '+(e33&&e33.message||e33)+']');}"
       "try{var A34=document.querySelectorAll('[class*=_hp-mosaic-container_style_widgetContainer],[class*=_mosaic-container_style_widgetContainer]'),Q34=[],brown34=0,fixed34=0;for(var i34=0;i34<A34.length;i34++){var e34=A34[i34],r34=e34.getBoundingClientRect(),s34=getComputedStyle(e34),bc34=String(s34.borderTopColor||'').replace(/ /g,''),isB34=(bc34==='rgb(84,78,69)'||bc34==='rgb(85,79,70)'||bc34==='rgb(83,77,68)');if(isB34)brown34++;if(e34.getAttribute&&e34.getAttribute('data-ad-border-section')==='exact371')fixed34++;if(Q34.length<12&&(isB34||(r34.bottom>=-80&&r34.top<=(window.innerHeight||900)+80)))Q34.push(e34.tagName+'.'+cls(e34)+'@'+Math.round(r34.top)+'/'+Math.round(r34.width)+'x'+Math.round(r34.height)+'|t='+bc34+'|sec='+String(e34.getAttribute('data-ad-border-section')||'-')+'|by='+(e34.__adBy||'-'));}out.push('P34V374[total='+A34.length+' brown='+brown34+' fixed='+fixed34+(Q34.length?' '+Q34.join(' ~~ '):'')+']');}catch(e34){out.push('P34V374[err '+(e34&&e34.message||e34)+']');}"
       "try{var C35=document.querySelectorAll('[data-ad-compactad371]'),I35=document.querySelectorAll('[data-ad-compactink371]'),Q35=[];for(var i35=0;i35<I35.length&&i35<8;i35++){var e35=I35[i35],r35=e35.getBoundingClientRect(),s35=getComputedStyle(e35),t35=String(e35.textContent||'').replace(/\\s+/g,' ').trim();Q35.push(t35.slice(0,24)+'@'+Math.round(r35.top)+'|c='+String(s35.color||'-').replace(/ /g,'')+'|fill='+String(s35.webkitTextFillColor||'-').replace(/ /g,'')+'|by='+(e35.__adBy||'-'));}out.push('P35V374[cards='+C35.length+' ink='+I35.length+(Q35.length?' '+Q35.join(' ~~ '):'')+']');}catch(e35){out.push('P35V374[err '+(e35&&e35.message||e35)+']');}"
       "try{var F36=document.querySelectorAll('iframe[data-ad-frame-mode362=\"standalone\"]'),Q36=[];for(var i36=0;i36<F36.length&&i36<12;i36++){var f36=F36[i36],r36=f36.getBoundingClientRect();if(r36.width<280||r36.height>100)continue;Q36.push(Math.round(r36.left)+','+Math.round(r36.top)+'/'+Math.round(r36.width)+'x'+Math.round(r36.height));}out.push('P36V374[compactStandalone='+Q36.length+(Q36.length?' '+Q36.join(' ~~ '):'')+']');}catch(e36){out.push('P36V374[err '+(e36&&e36.message||e36)+']');}"
       "try{var F37=document.querySelectorAll('iframe[data-ad-compactframe373]'),W37=document.querySelectorAll('[data-ad-compactwrap373]'),Q37=[];for(var i37=0;i37<F37.length&&i37<8;i37++){var f37=F37[i37],r37=f37.getBoundingClientRect();if(r37.width<250||r37.height>110)continue;var s37=getComputedStyle(f37),p37=f37.parentElement,ps37=p37?getComputedStyle(p37):null;Q37.push(Math.round(r37.left)+','+Math.round(r37.top)+'/'+Math.round(r37.width)+'x'+Math.round(r37.height)+'|conf='+(f37.hasAttribute('data-ad-compactconfirmed373')?1:0)+'|bg='+String(s37.backgroundColor||'-').replace(/ /g,'')+'|fil='+String(s37.filter||'-').replace(/ /g,'')+'|pbg='+(ps37?String(ps37.backgroundColor||'-').replace(/ /g,''):'-'));}out.push('P37V374[frames='+F37.length+' wraps='+W37.length+(Q37.length?' '+Q37.join(' ~~ '):'')+']');}catch(e37){out.push('P37V374[err '+(e37&&e37.message||e37)+']');}"

       // P38V374: consistency state for the Pack badge and PDP carousel dots.
       "try{var PK38=[],R38=document.querySelectorAll('[class*=pack-size-badge]');for(var r38=0;r38<R38.length&&PK38.length<12;r38++){var pr38=R38[r38].getBoundingClientRect();if(pr38.width<8||pr38.height<8)continue;var L38=R38[r38].querySelectorAll('*');for(var l38=0;l38<L38.length&&PK38.length<12;l38++){var e38=L38[l38];if(e38.childElementCount!==0)continue;var tx38=String(e38.textContent||'').replace(/\\s+/g,' ').trim();if(!tx38||tx38.length>16)continue;var sc38=getComputedStyle(e38);PK38.push(tx38+'|c='+String(sc38.color||'-').replace(/ /g,'')+'|fill='+String(sc38.webkitTextFillColor||'-').replace(/ /g,'')+'|mk='+(e38.hasAttribute('data-ad-packfix374')?1:0));}}var DT38=[],U38=document.querySelectorAll('ul.a-pagination.a-dots,[class*=a-pagination][class*=dots]');for(var u38=0;u38<U38.length&&DT38.length<16;u38++){var D38=U38[u38].querySelectorAll('li');for(var d38=0;d38<D38.length&&DT38.length<16;d38++){var q38=D38[d38],qr38=q38.getBoundingClientRect();if(qr38.width<2||qr38.height<2)continue;var qs38=getComputedStyle(q38),ar38=String(q38.getAttribute('aria-current')||q38.getAttribute('aria-selected')||'-');DT38.push(String(q38.className||'-').slice(0,20)+'|sel='+(q38.hasAttribute('data-ad-dotselected374')?1:0)+'|aria='+ar38+'|bg='+String(qs38.backgroundColor||'-').replace(/ /g,''));}}out.push('P38V374[pack='+PK38.length+(PK38.length?' '+PK38.join(' ~~ '):'')+' | dots='+DT38.length+(DT38.length?' '+DT38.join(' ~~ '):'')+']');}catch(e38){out.push('P38V374[err '+(e38&&e38.message||e38)+']');}"
       // separate lists-framework cards action.
       // P39V382: true icon-sized stock cards host + frozen Compare state.
       "try{var A39=document.querySelectorAll('[data-ad-stockaction382]'),C39=document.querySelectorAll('[data-ad-compare380]'),Q39=[];for(var i39=0;i39<A39.length&&Q39.length<8;i39++){var h39=A39[i39],r39=h39.getBoundingClientRect(),s39=getComputedStyle(h39);Q39.push('A@'+Math.round(r39.left)+','+Math.round(r39.top)+'/'+Math.round(r39.width)+'x'+Math.round(r39.height)+'|bg='+String(s39.backgroundColor||'-').replace(/ /g,'')+'|br='+String(s39.borderColor||'-').replace(/ /g,''));}for(var j39=0;j39<C39.length&&Q39.length<14;j39++){var c39=C39[j39],rr39=c39.getBoundingClientRect(),st=c39.getAttribute('data-ad-compare380'),b39=getComputedStyle(c39,'::before');Q39.push('C@'+Math.round(rr39.left)+','+Math.round(rr39.top)+'/'+Math.round(rr39.width)+'x'+Math.round(rr39.height)+'|sel='+st+'|box='+String(b39.backgroundColor||'-').replace(/ /g,''));}var bad39=0;for(var b39=0;b39<A39.length;b39++){var br39=A39[b39].getBoundingClientRect();if(br39.width>64||br39.height>64||Math.abs(br39.width-br39.height)>14)bad39++;}out.push('P39V382[action='+A39.length+' malformed='+bad39+' compare='+C39.length+(Q39.length?' '+Q39.join(' ~~ '):'')+' state='+String(window.__AD_STOCKACTION382__||'-')+' cmp='+String(window.__AD_COMPARE380__||'-')+']');}catch(e39){out.push('P39V382[err '+(e39&&e39.message||e39)+']');}"
       "try{var A384=document.querySelectorAll('[data-ad-stockaction384],[data-ad-stockdisc384]'),L384=document.querySelectorAll('[data-ad-stockglyph384]'),C384=document.querySelectorAll('[data-ad-compare380]'),Q384=[],ov384=0;for(var i384=0;i384<A384.length&&Q384.length<10;i384++){var e384=A384[i384],r384=e384.getBoundingClientRect(),k384=e384.hasAttribute('data-ad-stockdisc384')?'S':'D';Q384.push(k384+'@'+Math.round(r384.left)+','+Math.round(r384.top)+'/'+Math.round(r384.width)+'x'+Math.round(r384.height));for(var j384=0;j384<C384.length;j384++){var c384=C384[j384].getBoundingClientRect(),cx384=r384.left+r384.width/2,cy384=r384.top+r384.height/2,qx384=c384.left+c384.width/2,qy384=c384.top+c384.height/2;if(Math.abs(cx384-qx384)<18&&Math.abs(cy384-qy384)<18){ov384++;break;}}}out.push('P39V384[action='+A384.length+' leaf='+L384.length+' compare='+C384.length+' overlap='+ov384+(Q384.length?' '+Q384.join(' ~~ '):'')+' state='+String(window.__AD_STOCKACTION384__||'-')+']');}catch(e384){out.push('P39V384[err '+(e384&&e384.message||e384)+']');}"
       "try{var H386=document.querySelectorAll('[data-ad-heartbezel386]'),Q386=[],rl386=0;for(var h386=0;h386<H386.length&&h386<12;h386++){var e386=H386[h386],r386=e386.getBoundingClientRect(),s386=getComputedStyle(e386),sh386=String(s386.boxShadow||'');if(sh386.indexOf('1.5px')<0)rl386++;Q386.push(Math.round(r386.left)+','+Math.round(r386.top)+'/'+Math.round(r386.width)+'x'+Math.round(r386.height)+'|sh='+(sh386==='none'?'none':'yes'));}out.push('P48HEART386[hosts='+H386.length+' ringless='+rl386+(Q386.length?' '+Q386.join(' ~~ '):'')+' state='+String(window.__AD_HEART386__||'-')+']');}catch(e386){out.push('P48HEART386[err '+(e386&&e386.message||e386)+']');}"
       "try{var HH=document.querySelectorAll('[data-ad-heart387]'),HG=document.querySelectorAll('[data-ad-heartglyph387]'),AA=document.querySelectorAll('[data-ad-stockaction387]'),AG=document.querySelectorAll('[data-ad-stockglyph387]'),CC=document.querySelectorAll('[data-ad-compare380],[data-ad-comparelegacy387]'),Q=[],dup=0,ring=0,darkg=0,ov=0,whitebox=0;function cen(e){var r=e.getBoundingClientRect();return [r.left+r.width/2,r.top+r.height/2,r.width,r.height];}for(var i=0;i<HH.length;i++){var h=HH[i],c=cen(h),s=getComputedStyle(h);if(String(s.borderTopWidth||'0').indexOf('1.5')<0)ring++;for(var j=i+1;j<HH.length;j++){var d=cen(HH[j]);if(Math.abs(c[0]-d[0])<3&&Math.abs(c[1]-d[1])<3)dup++;}if(Q.length<5)Q.push('H@'+Math.round(c[0])+','+Math.round(c[1])+'/'+Math.round(c[2])+'x'+Math.round(c[3]));}for(var a=0;a<AA.length;a++){var ar=cen(AA[a]),ss=getComputedStyle(AA[a]);if(String(ss.borderTopWidth||'0').indexOf('1.5')<0)ring++;for(var c=0;c<CC.length;c++){var cr=cen(CC[c]);if(Math.abs(ar[0]-cr[0])<18&&Math.abs(ar[1]-cr[1])<18){ov++;break;}}if(Q.length<10)Q.push('A@'+Math.round(ar[0])+','+Math.round(ar[1])+'/'+Math.round(ar[2])+'x'+Math.round(ar[3]));}for(var g=0;g<AG.length;g++){var gs=getComputedStyle(AG[g]),tg=String(AG[g].tagName||'').toUpperCase();if((tg==='IMG'||tg==='I')&&String(gs.filter||'none').indexOf('invert')<0)darkg++;}var LG=document.querySelectorAll('[data-ad-comparelegacyorig387]');for(var l=0;l<LG.length;l++){var ls=getComputedStyle(LG[l]);if(ls.visibility!=='hidden'&&parseFloat(ls.opacity||'1')>.05)whitebox++;}out.push('P50CTRL387[heart='+HH.length+' hleaf='+HG.length+' action='+AA.length+' aglyph='+AG.length+' compare='+CC.length+' dup='+dup+' ringless='+ring+' darkglyph='+darkg+' overlap='+ov+' whiteorig='+whitebox+(Q.length?' '+Q.join(' ~~ '):'')+' hstate='+String(window.__AD_HEART387__||'-')+' astate='+String(window.__AD_STOCKACTION387__||'-')+' lstate='+String(window.__AD_COMPARELEGACY387__||'-')+']');}catch(e50){out.push('P50CTRL387[err '+(e50&&e50.message||e50)+']');}"
       "try{var HR=document.querySelectorAll('[data-ad-heart388]'),HD=document.querySelectorAll('[data-ad-heartdisc388]'),HG=document.querySelectorAll('[data-ad-heartglyph388]'),HP=document.querySelectorAll('[data-ad-heartbefore388],[data-ad-heartafter388]'),SR=document.querySelectorAll('[data-ad-stockroot388]'),SD=document.querySelectorAll('[data-ad-stockdisc388]'),SG=document.querySelectorAll('[data-ad-stockglyph388]'),SP=document.querySelectorAll('[data-ad-stockbefore388],[data-ad-stockafter388]'),CC=document.querySelectorAll('[data-ad-compare380],[data-ad-comparelegacy387]'),oval=0,ring=0,dark=0,ov=0,Q=[];function cen(e){var r=e.getBoundingClientRect();return [r.left+r.width/2,r.top+r.height/2,r.width,r.height];}for(var i=0;i<HD.length;i++){var d=HD[i],c=cen(d),st=getComputedStyle(d);if(Math.abs(c[2]-36)>2||Math.abs(c[3]-36)>2||Math.abs(c[2]-c[3])>2)oval++;if(String(st.borderTopWidth||'0').indexOf('1.5')<0)ring++;if(Q.length<5)Q.push('H@'+Math.round(c[0])+','+Math.round(c[1])+'/'+Math.round(c[2])+'x'+Math.round(c[3]));}for(var j=0;j<SD.length;j++){var d2=SD[j],c2=cen(d2),st2=getComputedStyle(d2);if(Math.abs(c2[2]-36)>2||Math.abs(c2[3]-36)>2||Math.abs(c2[2]-c2[3])>2)oval++;if(String(st2.borderTopWidth||'0').indexOf('1.5')<0)ring++;for(var k=0;k<CC.length;k++){var cc=cen(CC[k]);if(Math.abs(c2[0]-cc[0])<18&&Math.abs(c2[1]-cc[1])<18){ov++;break;}}if(Q.length<10)Q.push('A@'+Math.round(c2[0])+','+Math.round(c2[1])+'/'+Math.round(c2[2])+'x'+Math.round(c2[3]));}var G=[];for(var a=0;a<HG.length;a++)G.push(HG[a]);for(var b=0;b<SG.length;b++)G.push(SG[b]);for(var g=0;g<G.length;g++){var gs=getComputedStyle(G[g]),tg=String(G[g].tagName||'').toUpperCase();if((tg==='IMG'||tg==='I')&&String(gs.filter||'none').indexOf('invert')<0)dark++;}out.push('P51CTRL388[hroot='+HR.length+' hdisc='+HD.length+' hglyph='+HG.length+' hpseudo='+HP.length+' aroot='+SR.length+' adisc='+SD.length+' aglyph='+SG.length+' apseudo='+SP.length+' oval='+oval+' ringless='+ring+' darkglyph='+dark+' overlap='+ov+(Q.length?' '+Q.join(' ~~ '):'')+' hstate='+String(window.__AD_HEART388__||'-')+' astate='+String(window.__AD_STOCKACTION388__||'-')+']');}catch(e51){out.push('P51CTRL388[err '+(e51&&e51.message||e51)+']');}"
       // P53V360CTRL (v5.389): authoritative probe for restored v5.360 product-control architecture.
       // Heart: Amazon owns the stock host/painter; this tweak only keeps the historical
       // transparent heart-position shell + leaf whitening. Two-card: the exact historical
       // size-guarded lists-framework-action-button disc in clr() owns the chrome.
       "try{var H53=document.querySelectorAll('[class*=puis-heart-position]'),A53=document.querySelectorAll('[class*=lists-framework-action-button]'),Q53=[],hov53=0,aok53=0,aoval53=0,adark53=0,modern53=0;function rr53(e){return e.getBoundingClientRect();}function lum53(c){var m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/i.exec(String(c||''));return m?(0.2126*(+m[1])+0.7152*(+m[2])+0.0722*(+m[3]))/255:-1;}for(var h53=0;h53<H53.length;h53++){var hr53=rr53(H53[h53]);if(hr53.width>hr53.height+20&&getComputedStyle(H53[h53]).borderTopWidth!=='0px')hov53++;if(Q53.length<5)Q53.push('H@'+Math.round(hr53.left)+','+Math.round(hr53.top)+'/'+Math.round(hr53.width)+'x'+Math.round(hr53.height));}for(var a53=0;a53<A53.length;a53++){var ae53=A53[a53],ar53=rr53(ae53);if(ar53.width<18||ar53.width>52||ar53.height<18||ar53.height>52)continue;if(Math.abs(ar53.width-ar53.height)>10){aoval53++;continue;}var as53=getComputedStyle(ae53);var br53=parseFloat(as53.borderTopWidth||'0');var bg53=lum53(as53.backgroundColor);if(br53>=1&&bg53>=0&&bg53<.22)aok53++;var G53=ae53.querySelectorAll('img,i,svg,path,[class*=lists-framework-unfill],[class*=lists-framework-fill]');for(var g53=0;g53<G53.length&&g53<20;g53++){var ge53=G53[g53],gr53=rr53(ge53);if(gr53.width<5||gr53.height<5||gr53.width>40||gr53.height>40)continue;var gs53=getComputedStyle(ge53),tg53=String(ge53.tagName||'').toUpperCase();if((tg53==='IMG'||tg53==='I')&&String(gs53.filter||'none').indexOf('invert')<0)adark53++;}}modern53=document.querySelectorAll('[data-ad-heart388],[data-ad-heart387],[data-ad-heartbezel386],[data-ad-stockroot388],[data-ad-stockdisc388],[data-ad-stockaction387],[data-ad-stockaction384],[data-ad-stockaction382]').length;out.push('P53V360CTRL[heartRoots='+H53.length+' heartOval='+hov53+' actionRoots='+A53.length+' actionGood='+aok53+' actionOval='+aoval53+' actionDark='+adark53+' modern='+modern53+(Q53.length?' '+Q53.join(' ~~ '):'')+' disc='+String(window.__AD_DISC__||'-')+']');}catch(e53){out.push('P53V360CTRL[err '+(e53&&e53.message||e53)+']');}"
       // P54CTRL391: authoritative in-place product-control state. Position/size are
       // Amazon-owned; ring/bg must match and there must be no v5.390 synthetic nodes.
       "try{var D54=document.querySelectorAll('[data-ad-product391]'),h54=0,c54=0,a54=0,k54=0,bg54=0,ring54=0,wide54=0,Q54=[];for(var i54=0;i54<D54.length;i54++){var e54=D54[i54],r54=e54.getBoundingClientRect(),t54=String(e54.getAttribute('data-ad-product391')||'-'),s54=getComputedStyle(e54);if(t54==='heart')h54++;else if(t54==='cards')c54++;else if(t54==='arrow')a54++;else if(t54==='checkbox')k54++;if(Math.abs(r54.width-r54.height)>8)wide54++;if(String(s54.backgroundColor||'').replace(/\\s+/g,'')!=='rgb(24,26,27)')bg54++;if(String(s54.boxShadow||'').indexOf('1.5px')<0)ring54++;if(Q54.length<10)Q54.push(t54+'@'+Math.round(r54.left)+','+Math.round(r54.top)+'/'+Math.round(r54.width)+'x'+Math.round(r54.height));}var syn54=document.querySelectorAll('[data-ad-productdisc390],[data-ad-productanchor390],[data-ad-checkboxglyph390]').length;out.push('P54CTRL391[page='+String(window.__AD_PRODUCTPAGE391__||0)+' n='+D54.length+' heart='+h54+' cards='+c54+' arrow='+a54+' checkbox='+k54+' badBg='+bg54+' badRing='+ring54+' wide='+wide54+' synthetic390='+syn54+' state='+String(window.__AD_PRODUCTCTRL391__||'-')+(Q54.length?' '+Q54.join(' ~~ '):'')+']');}catch(e54){out.push('P54CTRL391[err '+(e54&&e54.message||e54)+']');}"
       // P55VIDEO391: visible Home video readiness/playback rescue state.
       "try{var V55=document.querySelectorAll('video[data-ad-homevideo391]'),pv55=0,pl55=0,w55=0,Q55=[];for(var i55=0;i55<V55.length&&i55<20;i55++){var v55=V55[i55],r55=v55.getBoundingClientRect();if(v55.paused)pv55++;else pl55++;if(v55.readyState<2)w55++;if(Q55.length<8)Q55.push(Math.round(r55.left)+','+Math.round(r55.top)+'/'+Math.round(r55.width)+'x'+Math.round(r55.height)+'|p='+Number(v55.paused)+'|rs='+v55.readyState+'|a='+Number(v55.autoplay)+'|m='+Number(v55.muted||v55.defaultMuted));}out.push('P55VIDEO391[n='+V55.length+' playing='+pl55+' paused='+pv55+' waiting='+w55+' state='+String(window.__AD_HOMEVIDEO391__||'-')+(Q55.length?' '+Q55.join(' ~~ '):'')+']');}catch(e55){out.push('P55VIDEO391[err '+(e55&&e55.message||e55)+']');}"
       // P56HOME393: direct evidence for the two Home regressions. Standalone is
       // anchored to confirmed standalone iframe ancestry; bleed is anchored to video-card ancestry.
              "try{var F56=document.querySelectorAll('iframe[data-ad-homeauto395=\"1\"]'),stand56=F56.length,haz56=0,W56=innerWidth||390;for(var i56=0;i56<F56.length;i56++){var f56=F56[i56],fr56=f56.getBoundingClientRect(),p56=f56.parentElement,d56=0;while(p56&&p56!==document.body&&d56++<8){var pr56=p56.getBoundingClientRect();if(pr56.width<fr56.width*.65||pr56.width>W56*1.14||pr56.height<fr56.height*.45||pr56.height>680)break;if(!(p56.querySelector&&p56.querySelector('video'))){var s56=getComputedStyle(p56),bi56=String(s56.backgroundImage||'none'),bc56=String(s56.backgroundColor||'transparent').replace(/\\s+/g,''),sh56=String(s56.boxShadow||'none'),fl56=String(s56.filter||'none');if(bi56.indexOf('url(')<0&&((bc56!=='transparent'&&bc56!=='rgba(0,0,0,0)')||bi56!=='none'||sh56!=='none'||fl56!=='none'))haz56++;}p56=p56.parentElement;}}var M56=document.querySelectorAll('[data-ad-homemedia395]'),B56=document.querySelectorAll('[data-ad-homebg395]'),unc56=0,comp56=0;for(var m56=0;m56<M56.length;m56++){if(String(getComputedStyle(M56[m56]).filter||'').indexOf('brightness')<0)unc56++;}for(var b56=0;b56<B56.length;b56++){var bs56=getComputedStyle(B56[b56]);if(String(bs56.filter||'none')!=='none'||String(bs56.backgroundBlendMode||'normal').indexOf('multiply')>=0)comp56++;}out.push('P56HOME395[stand='+stand56+' hazard='+haz56+' media='+M56.length+' bg='+B56.length+' uncovered='+unc56+' compositor='+comp56+' sstate='+String(window.__AD_STANDSWEEP395__||'-')+' mstate='+String(window.__AD_HOMEMEDIA395__||'-')+']');}catch(e56){out.push('P56HOME395[err '+(e56&&e56.message||e56)+']');}"
              "try{var G59=document.querySelectorAll('[class*=theming-card-background]'),risk59=0,seen59=0;for(var g59=0;g59<G59.length&&g59<80;g59++){var e59=G59[g59],p59=e59,u59=0,ctx59='';while(p59&&u59++<7){ctx59+=' '+String(p59.className||'');p59=p59.parentElement;}if(!/single-video-card|single-creative-card|theming-card/i.test(ctx59))continue;seen59++;var c59=getComputedStyle(e59),bi59=String(c59.backgroundImage||'none'),bc59=String(c59.backgroundColor||'').replace(/\\s+/g,''),f59=String(c59.filter||'none'),mb59=String(c59.mixBlendMode||'normal');if(bi59!=='none'||(bc59!=='rgb(24,26,27)'&&bc59!=='rgba(24,26,27,1)'&&bc59!=='#181a1b')||f59!=='none'||mb59!=='normal')risk59++;}out.push('P59BLEED396[main='+(document.documentElement&&document.documentElement.hasAttribute('data-ad-main396')?1:0)+' bg='+seen59+' risk='+risk59+']');}catch(e59){out.push('P59BLEED396[err '+(e59&&e59.message||e59)+']');}"
       // P60SYMBOL397: v5.333 non-checkbox symbol authority. bad=0 means every
       // sampled non-checkbox legacy symbol painter is light; cbTouched must stay 0.
       "try{var S60=document.querySelectorAll('[class*=lists-framework-action-button] img,[class*=lists-framework-action-button] i,[class*=lists-framework-action-button] svg,[class*=lists-framework-unfill],[class*=lists-framework-fill],img[class*=add-icon],img[class*=plus-icon],[class*=puis-heart-position] .a-icon,[class*=puis-heart-position] img'),bad60=0,seen60=0,Q60=[];for(var i60=0;i60<S60.length&&i60<220;i60++){var e60=S60[i60];if(e60.closest&&e60.closest('[class*=mlt-icon-container],[role=checkbox],input[type=checkbox],[class*=a-icon-checkbox],[data-ad-compare380],[data-ad-comparelegacy387],[data-ad-product391=\"checkbox\"]'))continue;var r60=e60.getBoundingClientRect();if(r60.width<3||r60.height<3||r60.width>60||r60.height>60)continue;seen60++;var c60=getComputedStyle(e60),t60=String(e60.tagName||'').toUpperCase(),ok60=1;if(t60==='IMG'||t60==='I')ok60=String(c60.filter||'none').indexOf('invert')>=0;else if(t60==='SVG'||t60==='PATH')ok60=(String(c60.fill||c60.color||'').indexOf('255')>=0||String(c60.fill||c60.color||'').indexOf('232')>=0);if(!ok60){bad60++;if(Q60.length<8)Q60.push(t60+'.'+String(e60.className&&e60.className.baseVal!==undefined?e60.className.baseVal:e60.className||'').slice(0,28));}}var C60=document.querySelectorAll('[class*=mlt-icon-container] [data-ad-productglyph391],[class*=mlt-icon-container] [data-ad-productraster391],[class*=mlt-icon-container] [data-ad-productvector391],[data-ad-product391=\"checkbox\"]'),ct60=0;for(var c60i=0;c60i<C60.length;c60i++){if(C60[c60i].__adBy==='v333397')ct60++;}out.push('P60SYMBOL397[seen='+seen60+' bad='+bad60+' cbTouched='+ct60+' state='+String(window.__AD_SYMBOL333397_STATE__||'-')+(Q60.length?' '+Q60.join(' ~~ '):'')+']');}catch(e60){out.push('P60SYMBOL397[err '+(e60&&e60.message||e60)+']');}"
       // P69V333403: Heart/cards/down-arrow are passive-only v5.333 families; the
       // checkbox remains the isolated working stock treatment. override MUST be 0.
       "try{var H69=document.querySelectorAll('[data-ad-v333403]'),h69=0,d69=0,a69=0,c69=0,bad69=0,miss69=0,ov69=0,Q69=[];function lum69(v){var m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/i.exec(String(v||''));return m?(0.2126*(+m[1])+0.7152*(+m[2])+0.0722*(+m[3])):-1;}for(var i69=0;i69<H69.length&&i69<120;i69++){var e69=H69[i69],t69=String(e69.getAttribute('data-ad-v333403')||'-');if(t69==='h')h69++;else if(t69==='d')d69++;else if(t69==='a')a69++;else if(t69==='c')c69++;if(t69!=='c'&&e69.hasAttribute('data-ad-stock403'))ov69++;if(t69==='c')continue;var G69=e69.querySelectorAll('img,i,svg,path,use,polygon,.a-icon,[class*=lists-framework-unfill],[class*=lists-framework-fill]'),found69=0,good69=0,desc69='';for(var j69=0;j69<G69.length&&j69<60;j69++){var g69=G69[j69],r69=g69.getBoundingClientRect();if(r69.width<3||r69.height<3||r69.width>60||r69.height>60)continue;var s69=getComputedStyle(g69),tg69=String(g69.tagName||'').toUpperCase(),bi69=String(s69.backgroundImage||'none'),mi69=String(s69.maskImage||s69.webkitMaskImage||'none'),flt69=String(s69.filter||'none');var raster69=(tg69==='IMG'||tg69==='I'||bi69!=='none'||mi69!=='none'),vector69=(tg69==='SVG'||tg69==='PATH'||tg69==='USE'||tg69==='POLYGON');if(!raster69&&!vector69)continue;found69=1;if(raster69&&flt69.indexOf('invert')>=0)good69=1;if(vector69&&Math.max(lum69(s69.fill),lum69(s69.stroke),lum69(s69.color))>=180)good69=1;if(!desc69)desc69=tg69+'|f='+flt69.slice(0,28)+'|fill='+String(s69.fill||'-').replace(/\\s+/g,'');if(good69)break;}if(!found69)miss69++;else if(!good69)bad69++;if(Q69.length<10)Q69.push(t69+'|'+(desc69||'no-leaf'));}out.push('P69V333403[h='+h69+' cards='+d69+' arrow='+a69+' checkbox='+c69+' bad='+bad69+' missing='+miss69+' override='+ov69+' v333='+String(window.__AD_SYMBOL333397_STATE__||'-')+' cbcap='+String(window.__AD_STOCKCAP403_STATE__||'-')+' cbfin='+String(window.__AD_STOCKFIN403_STATE__||'-')+(Q69.length?' '+Q69.join(' ~~ '):'')+']');}catch(e69){out.push('P69V333403[err '+(e69&&e69.message||e69)+']');}"
       // P70COLLEGE403: the College section/full-size backdrop must equal the live app background.
       "try{function norm70(v){return String(v||'').replace(/\\s+/g,'');}var app70=norm70(getComputedStyle(document.body||document.documentElement).backgroundColor),C70=document.querySelectorAll('[data-ad-college-section=\"1\"]'),T70=document.querySelectorAll('[data-ad-college-bg403=\"1\"]'),mis70=0,Q70=[];for(var i70=0;i70<T70.length&&i70<24;i70++){var e70=T70[i70],b70=norm70(getComputedStyle(e70).backgroundColor);if(app70&&app70!=='transparent'&&app70!=='rgba(0,0,0,0)'&&b70!==app70)mis70++;if(Q70.length<8){var r70=e70.getBoundingClientRect();Q70.push(Math.round(r70.width)+'x'+Math.round(r70.height)+'|'+b70);}}out.push('P70COLLEGE403[section='+C70.length+' targets='+T70.length+' mismatch='+mis70+' app='+app70+' state='+String(window.__AD_COLLEGEBG403_STATE__||'-')+(Q70.length?' '+Q70.join(' ~~ '):'')+']');}catch(e70){out.push('P70COLLEGE403[err '+(e70&&e70.message||e70)+']');}"
       // P66BLEED401: verify narrow self-clip only; color/background are diagnostic, never rewritten.
       "try{var B66=document.querySelectorAll('[class*=single-creative-card] [class*=theming-card-background],[class*=single-video-card] [class*=theming-card-background]'),seen66=0,clipMiss66=0,Q66=[];for(var i66=0;i66<B66.length&&i66<80;i66++){var e66=B66[i66],r66=e66.getBoundingClientRect();if(r66.width<80||r66.height<60)continue;seen66++;var s66=getComputedStyle(e66),cp66=String(s66.clipPath||s66.webkitClipPath||'none'),bg66=String(s66.backgroundColor||'').replace(/\\s+/g,'');if(cp66==='none')clipMiss66++;if(Q66.length<8)Q66.push(Math.round(r66.width)+'x'+Math.round(r66.height)+'|clip='+cp66+'|bg='+bg66);}out.push('P66BLEED401[seen='+seen66+' clipMiss='+clipMiss66+' style='+(document.getElementById('adbleed401')?1:0)+(Q66.length?' '+Q66.join(' ~~ '):'')+']');}catch(e66){out.push('P66BLEED401[err '+(e66&&e66.message||e66)+']');}"
       // P67PAGE401: loading-health sentinel for the v5.399 regression.
       "try{out.push('P67PAGE401[ready='+String(document.readyState||'-')+' search='+(document.querySelector('#search,.s-search-results,.s-result-list')?1:0)+' product='+(document.querySelector('#productTitle,#dp-container,#ppd')?1:0)+' body='+(document.body?document.body.children.length:0)+' stockStyle='+(document.getElementById('adstock403')?1:0)+' bleedStyle='+(document.getElementById('adbleed401')?1:0)+']');}catch(e67){out.push('P67PAGE401[err '+(e67&&e67.message||e67)+']');}"
       // P57HEART393: a Heart host is not considered good unless a real element or
       // pseudo painter is present. This catches the exact 5.392 glyph=0 failure.
              "try{var R57=document.querySelectorAll('[class*=puis-heart-position]'),ready57=0,vu57=0,rng57=0,Q57=[];for(var i57=0;i57<R57.length&&i57<160;i57++){var r57=R57[i57],rd57=r57.getAttribute('data-ad-heartready394')==='1',cs57=getComputedStyle(r57);if(rd57)ready57++;else if(cs57.visibility!=='hidden'&&cs57.display!=='none')vu57++;if(rd57){var g57=r57.querySelectorAll('[data-ad-productglyph391], [data-ad-heartbefore393], [data-ad-heartafter393]');if(!g57.length)rng57++;}if(Q57.length<8){var br57=r57.getBoundingClientRect();Q57.push(Math.round(br57.left)+','+Math.round(br57.top)+'/'+Math.round(br57.width)+'x'+Math.round(br57.height)+'|r='+(rd57?1:0));}}out.push('P57HEART394[roots='+R57.length+' ready='+ready57+' visibleUnready='+vu57+' readyNoGlyph='+rng57+(Q57.length?' '+Q57.join(' ~~ '):'')+']');}catch(e57){out.push('P57HEART394[err '+(e57&&e57.message||e57)+']');}"
       "try{var HA386=document.querySelectorAll('[data-ad-homeambient386]'),hl386=0,HQ386=[];function p49(v){var m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([0-9.]+))?/i.exec(String(v||''));return m?[+m[1],+m[2],+m[3],m[4]===undefined?1:+m[4]]:null;}for(var i49=0;i49<HA386.length&&i49<8;i49++){var e49=HA386[i49],r49=e49.getBoundingClientRect(),c49=getComputedStyle(e49),q49=p49(c49.backgroundColor);if(q49&&q49[3]>.35&&(Math.max(q49[0],q49[1],q49[2])-Math.min(q49[0],q49[1],q49[2]))/255>.12)hl386++;HQ386.push(String(e49.tagName||'-')+'@'+Math.round(r49.top)+'/'+Math.round(r49.width)+'x'+Math.round(r49.height));}out.push('P49HOME386[n='+HA386.length+' hueleft='+hl386+(HQ386.length?' '+HQ386.join(' ~~ '):'')+' state='+String(window.__AD_HOMEAMBIENT386__||'-')+']');}catch(e49){out.push('P49HOME386[err '+(e49&&e49.message||e49)+']');}"
       // P40V379: Sponsored frame/parent text state.
       "try{var F40=document.querySelectorAll('iframe[data-ad-stripframe374]'),PI40=document.querySelectorAll('[data-ad-parentstripink379]'),pd40=0,Q40=[];for(var p40=0;p40<PI40.length;p40++){var m40=/rgb\\((\\d+),\\s*(\\d+),\\s*(\\d+)/.exec(String(getComputedStyle(PI40[p40]).color||''));if(m40&&(.2126*(+m40[1])+.7152*(+m40[2])+.0722*(+m40[3]))/255<.92)pd40++;}for(var i40=0;i40<F40.length&&i40<8;i40++){var f40=F40[i40],r40=f40.getBoundingClientRect();if(r40.width<250||r40.height>230)continue;Q40.push(String(f40.getAttribute('data-ad-frame-why369')||f40.getAttribute('data-ad-frame-mode362')||'-')+'@'+Math.round(r40.left)+','+Math.round(r40.top)+'/'+Math.round(r40.width)+'x'+Math.round(r40.height));}out.push('P40V379[frames='+F40.length+' forced='+String(window.__AD_FORCESTRIP379__||0)+' parentInk='+PI40.length+' parentDark='+pd40+(Q40.length?' '+Q40.join(' ~~ '):'')+']');}catch(e40){out.push('P40V379[err '+(e40&&e40.message||e40)+']');}"
       // P41V382: actual PDP Share painter leaves, not the whole host.
       "try{var S41=document.querySelectorAll('[data-ad-share382]'),Q41=[];for(var i41=0;i41<S41.length&&i41<8;i41++){var h41=S41[i41],r41=h41.getBoundingClientRect();if(r41.width<8||r41.height<8)continue;var P41=h41.querySelectorAll('[data-ad-sharepaint382]'),v41=h41.querySelector('svg,path'),ps41=P41.length?getComputedStyle(P41[0]):(v41?getComputedStyle(v41):getComputedStyle(h41));Q41.push(Math.round(r41.left)+','+Math.round(r41.top)+'/'+Math.round(r41.width)+'x'+Math.round(r41.height)+'|paint='+P41.length+'|flt='+String(ps41.filter||'none').slice(0,22)+'|fill='+String(ps41.fill||'-').replace(/ /g,''));}out.push('P41V382[n='+Q41.length+(Q41.length?' '+Q41.join(' ~~ '):'')+' state='+String(window.__AD_SHARE382__||'-')+']');}catch(e41){out.push('P41V382[err '+(e41&&e41.message||e41)+']');}"
       // P43V382: Share clones the live Delete chrome.
       "try{var S43=document.querySelectorAll('[data-ad-cartclone382]'),Q43=[];for(var i43=0;i43<S43.length&&i43<6;i43++){var e43=S43[i43],r43=e43.getBoundingClientRect(),c43=getComputedStyle(e43);Q43.push(Math.round(r43.left)+','+Math.round(r43.top)+'/'+Math.round(r43.width)+'x'+Math.round(r43.height)+'|bg='+String(c43.backgroundColor||'-').replace(/ /g,'')+'|br='+String(c43.borderColor||'-').replace(/ /g,''));}out.push('P43V382[share='+S43.length+(Q43.length?' '+Q43.join(' ~~ '):'')+' state='+String(window.__AD_CART382__||'-')+']');}catch(e43){out.push('P43V382[err '+(e43&&e43.message||e43)+']');}"
       // P46V383: semantic expander/down-chevron painters should be light.
       "try{var C46=document.querySelectorAll('[data-ad-expchev383]'),Q46=[],dark46=0;for(var i46=0;i46<C46.length&&i46<20;i46++){var e46=C46[i46],r46=e46.getBoundingClientRect(),s46=getComputedStyle(e46),b46=getComputedStyle(e46,'::before'),a46=getComputedStyle(e46,'::after');var cc46=String(s46.color||'-').replace(/ /g,''),bc46=String(b46&&b46.borderTopColor||'-').replace(/ /g,''),ac46=String(a46&&a46.borderTopColor||'-').replace(/ /g,'');var m46=/rgb\\((\\d+),\\s*(\\d+),\\s*(\\d+)/.exec(cc46);if(m46&&(.2126*(+m46[1])+.7152*(+m46[2])+.0722*(+m46[3]))/255<.55)dark46++;Q46.push(e46.tagName+'.'+String(e46.className||'').replace(/\\s+/g,'.').slice(0,28)+'@'+Math.round(r46.left)+','+Math.round(r46.top)+'/'+Math.round(r46.width)+'x'+Math.round(r46.height)+'|c='+cc46+'|b='+bc46+'|a='+ac46);}out.push('P46V383[n='+C46.length+' dark='+dark46+(Q46.length?' '+Q46.join(' ~~ '):'')+' state='+String(window.__AD_CHEV383__||'-')+']');}catch(e46){out.push('P46V383[err '+(e46&&e46.message||e46)+']');}"
       // P42V376: exact Sponsored labels and rating/review numerics must be pure white.
       "try{var S42=document.querySelectorAll('[data-ad-sponsored376]'),R42=document.querySelectorAll('[data-ad-rating376]'),sd42=0,rd42=0,Q42=[];for(var i42=0;i42<S42.length;i42++){var ss42=getComputedStyle(S42[i42]),c42=String(ss42.color||'').replace(/ /g,'');if(c42!=='rgb(255,255,255)')sd42++;if(Q42.length<5)Q42.push('S:'+String(S42[i42].textContent||'').replace(/\\s+/g,' ').trim()+'='+c42);}for(var j42=0;j42<R42.length;j42++){var rs42=getComputedStyle(R42[j42]),rc42=String(rs42.color||'').replace(/ /g,'');if(rc42!=='rgb(255,255,255)')rd42++;if(Q42.length<10)Q42.push('R:'+String(R42[j42].textContent||'').replace(/\\s+/g,' ').trim()+'='+rc42);}out.push('P42V376[spon='+S42.length+' sDark='+sd42+' rating='+R42.length+' rDark='+rd42+(Q42.length?' '+Q42.join(' ~~ '):'')+']');}catch(e42){out.push('P42V376[err '+(e42&&e42.message||e42)+']');}"

       // P26FRAME (v5.362): parent-side ad-frame classification.
       "try{var F26=document.querySelectorAll('iframe'),Q26=[];for(var i26=0;i26<F26.length&&Q26.length<12;i26++){var f26=F26[i26],r26=f26.getBoundingClientRect();if(r26.width<100||r26.height<40)continue;Q26.push(String(f26.getAttribute('data-ad-frame-mode362')||'-')+'@'+Math.round(r26.left)+','+Math.round(r26.top)+'/'+Math.round(r26.width)+'x'+Math.round(r26.height));}out.push('P26FRAME[n='+Q26.length+(Q26.length?' '+Q26.join(' ~~ '):'')+']');}catch(e26){out.push('P26FRAME[err '+(e26&&e26.message||e26)+']');}"

       // P25STOCK: top/home creative text must be untouched by our own forced ink
       // and carry no Dark Reader inline colour marker after the ad strip.
       "try{var Q25=[],A25=document.querySelectorAll('[data-ad-stocktext]'),V25=window.innerHeight||900;for(var a25=0;a25<A25.length&&Q25.length<10;a25++){var c25=A25[a25],r25=c25.getBoundingClientRect();if(r25.width<180||r25.height<80||r25.bottom<0||r25.top>V25*2)continue;var T25=c25.querySelectorAll('span,p,h1,h2,h3,h4,a');for(var t25=0;t25<T25.length&&t25<80;t25++){var x25=T25[t25];if(x25.children&&x25.children.length>2)continue;var tx25=String(x25.textContent||'').replace(/\\s+/g,' ').trim();if(tx25.length<2||tx25.length>60)continue;var xr25=x25.getBoundingClientRect();if(xr25.width<8||xr25.height<6)continue;var sx25=getComputedStyle(x25);Q25.push(tx25.slice(0,18)+'|c='+String(sx25.color||'-').replace(/ /g,'')+'|dr='+(x25.hasAttribute('data-darkreader-inline-color')?1:0)+'|fill='+String(sx25.webkitTextFillColor||'-').replace(/ /g,''));if(Q25.length>=10)break;}}out.push('P25STOCK[n='+Q25.length+(Q25.length?' '+Q25.join(' ~~ '):'')+']');}catch(e25){out.push('P25STOCK[err '+(e25&&e25.message||e25)+']');}"
       "try{var S5=[],E5=document.querySelectorAll('*');"
         "for(var z5=0;z5<E5.length&&S5.length<8;z5++){var e5=E5[z5];"
           "var r5=e5.getBoundingClientRect();"
           "if(r5.width<150||r5.height<80)continue;"
           "if(r5.bottom<0||r5.top>(window.innerHeight||900))continue;"
           "var s5=getComputedStyle(e5);var L5=lum(s5.backgroundColor);"
           "if(L5<0.45)continue;"
           "var c5=[],n5=e5,d5=0;while(n5&&d5<4){c5.push((cls(n5)||n5.tagName).slice(0,20));n5=n5.parentElement;d5++;}"
           "S5.push(Math.round(r5.width)+'x'+Math.round(r5.height)+'|'+e5.tagName"
             "+'|bg='+s5.backgroundColor+'|L='+L5.toFixed(2)+'|col='+s5.color+'|'+c5.join('>'));}"
         "out.push('P9STANDALONE[sub='+(__sub?1:0)+' '+(S5.length?S5.join(' ~ '):'none')+']');}catch(x5){out.push('P9STANDALONE[err]');}"
       "if(!intr&&!msh)return out.join(' ')+' P8SKIP[u='+u.slice(-22)+']';"
       "function bord(st){var SD=['Top','Right','Bottom','Left'];"
         "for(var k=0;k<4;k++){var w=parseFloat(st['border'+SD[k]+'Width'])||0;if(w<0.5)continue;"
           "var sy=st['border'+SD[k]+'Style'];if(sy==='none'||sy==='hidden')continue;"
           "var L=lum(st['border'+SD[k]+'Color']);"
           "if(L>0.10)return SD[k].charAt(0)+' w='+w.toFixed(0)+' L='+L.toFixed(2)+' '+st['border'+SD[k]+'Color'];}"
         "return '';}"
       "var bn=0,bs=[],shn=0,shs=[],flt=0,dr=0;"
       "for(var i=0;i<N;i++){var e=all[i],st=getComputedStyle(e);"
         "var h=bord(st);if(h){bn++;if(bs.length<8){var rd=parseFloat(st.borderTopLeftRadius)||0;var dv=(e.hasAttribute&&e.hasAttribute('data-darkreader-inline-border-top'))?1:0;bs.push(e.tagName+'|'+cls(e)+'|'+h+'|r='+rd.toFixed(0)+'|dr='+dv);}}"
         "var sh='';var bsh=String(st.boxShadow||'');"
         "if(bsh&&bsh!=='none'){var Ls=lum(bsh);if(Ls>0.45)sh='shadow L='+Ls.toFixed(2)+' '+bsh.slice(0,34);}"
         "if(!sh){var ow=parseFloat(st.outlineWidth)||0,ost=String(st.outlineStyle||'');"
           "if(ow>=0.5&&ost!=='none'&&ost!==''){var Lo=lum(st.outlineColor);"
             "if(Lo>0.45)sh='outline w='+ow.toFixed(0)+' L='+Lo.toFixed(2)+' '+st.outlineColor;}}"
         "if(sh){shn++;if(shs.length<6)shs.push(e.tagName+'|'+cls(e)+'|'+sh);}"
         "if(String(st.filter||'none')!=='none')flt++;"
         "if(e.hasAttribute&&(e.hasAttribute('data-darkreader-inline-bgcolor')||e.hasAttribute('data-darkreader-inline-color')||e.hasAttribute('data-darkreader-inline-border-top')))dr++;}"
       "out.push('P8BORD[n='+bn+(bs.length?' '+bs.join(' ~ '):'')+']');"
       "out.push('P8SHDW[n='+shn+(shs.length?' '+shs.join(' ~ '):'')+']');"
       "out.push('P8CHURN[flt='+flt+' dr='+dr+' els='+all.length+']');"
       "var fn2=0,fs2=[];"
       "for(var fi=0;fi<window.frames.length&&fs2.length<5;fi++){"
         "try{var fd=window.frames[fi].document;if(!fd)continue;var fe=fd.querySelectorAll('*'),lim=Math.min(fe.length,2000);"
           "for(var q=0;q<lim;q++){var hh=bord(getComputedStyle(fe[q]));if(hh){fn2++;if(fs2.length<5)fs2.push('f'+fi+'|'+fe[q].tagName+'|'+cls(fe[q])+'|'+hh);}}"
         "}catch(ce){fs2.push('f'+fi+':xorigin');}}"
       "out.push('P8FRAME[n='+fn2+' frames='+window.frames.length+(fs2.length?' '+fs2.join(' ~ '):'')+']');"
       "if(intr){var pl=[];"
         "for(var j=0;j<N&&pl.length<6;j++){var e2=all[j];var t=String(e2.textContent||'').trim();"
           "var bf='',af='';try{bf=String(getComputedStyle(e2,'::before').content||'');}catch(x){}"
           "try{af=String(getComputedStyle(e2,'::after').content||'');}catch(y){}"
           "var c2=cls(e2).toLowerCase();"
           "var al2=String((e2.getAttribute&&(e2.getAttribute('aria-label')||''))||'').toLowerCase();"
           "var isP=(t==='+')||bf.indexOf('+')>=0||af.indexOf('+')>=0||bf.indexOf('2b')>=0"
             "||c2.indexOf('add')>=0||c2.indexOf('plus')>=0||c2.indexOf('follow')>=0"
             "||al2.indexOf('add')>=0||al2.indexOf('plus')>=0||al2.indexOf('follow')>=0;"
           "if(!isP)continue;var s2=getComputedStyle(e2);"
           "var bg=String(s2.backgroundImage||'');if(bg.length>44)bg=bg.slice(0,44)+'..';"
           "var mk=String(s2.maskImage||s2.webkitMaskImage||'');if(mk.length>26)mk=mk.slice(0,26)+'..';"
           "var sv=e2.tagName==='svg'?'SELF':((e2.querySelector&&e2.querySelector('svg'))?'child':'-');"
           "pl.push(e2.tagName+'|'+cls(e2).slice(0,20)+'|t='+t.slice(0,4)+'|bf='+(bf||'-').slice(0,8)"
             "+'|bg='+(bg==='none'||!bg?'-':bg)+'|mask='+(mk==='none'||!mk?'-':mk)"
             "+'|svg='+sv+'|col='+s2.color+'|fill='+(s2.fill||'-'));}"
         "out.push('P7PLUS[n='+pl.length+(pl.length?' '+pl.join(' ~ '):' none')+']');}"
       "try{var FR=window.__AD_FRAMES__||{},fk=[],ff;for(ff in FR)fk.push(ff);"
         "if(fk.length){var fo=[];for(var fx=0;fx<fk.length&&fx<4;fx++)fo.push(fk[fx]+'=>'+String(FR[fk[fx]]).slice(0,180));"
           "out.push('P8SUB['+fo.join(' ~ ')+']');}else{out.push('P8SUB[none]');}}catch(es){out.push('P8SUB[err]');}"
       "try{var fl=[];for(var q2=0;q2<N&&fl.length<6;q2++){var e3=all[q2];var st3=getComputedStyle(e3);"
         "var bs3=String(st3.boxShadow||'');if(!bs3||bs3==='none')continue;"
         "var drs=(e3.hasAttribute&&e3.hasAttribute('data-darkreader-inline-boxshadow'))?1:0;"
         "var l3=lum(bs3);"
         "if(drs||l3>0.20){fl.push(e3.tagName+'|'+cls(e3)+'|dr='+drs+'|L='+(l3<0?'-':l3.toFixed(2))+'|'+bs3.slice(0,34));}}"
         "out.push('P9FLASH['+(fl.length?fl.join(' ~ '):'none')+']');}catch(ef){out.push('P9FLASH[err]');}"
       "try{var DM=[],VH=window.innerHeight||800;"
         "for(var z=0;z<N;z++){var e5=all[z];var r5=e5.getBoundingClientRect();"
           "if((r5.width<200&&r5.height<200)||(r5.width<20&&r5.height<20))continue;if(r5.bottom<0||r5.top>VH*2)continue;"
           "var s5=getComputedStyle(e5);"
           "var bw=parseFloat(s5.borderTopWidth)||0;var bL=bw>0?lum(s5.borderTopColor):-1;"
           "var oL=(parseFloat(s5.outlineWidth)>0&&s5.outlineStyle!=='none')?lum(s5.outlineColor):-1;"
           "var bs5=String(s5.boxShadow||'');var sL=(bs5&&bs5!=='none')?lum(bs5):-1;"
           "var gL=lum(s5.backgroundColor);"
           "var bimg=String(s5.borderImageSource||'none');var hasBI=(bimg&&bimg!=='none')?1:0;"
           "var bgimg=String(s5.backgroundImage||'none');var hasBG=(bgimg&&bgimg!=='none')?1:0;"
           "var pB='';try{var cb=getComputedStyle(e5,'::before');var pbw=parseFloat(cb.borderTopWidth)||0;"
             "var pbL=pbw>0?lum(cb.borderTopColor):-1;var pgL=lum(cb.backgroundColor);"
             "if(cb.content&&cb.content!=='none'&&(pbL>0.45||pgL>0.45))pB='::before bw='+pbw+' bL='+pbL.toFixed(2)+' bg='+pgL.toFixed(2);}catch(pe){}"
           "var pA='';try{var ca=getComputedStyle(e5,'::after');var paw=parseFloat(ca.borderTopWidth)||0;"
             "var paL=paw>0?lum(ca.borderTopColor):-1;var pagL=lum(ca.backgroundColor);"
             "if(ca.content&&ca.content!=='none'&&(paL>0.45||pagL>0.45))pA='::after bw='+paw+' bL='+paL.toFixed(2)+' bg='+pagL.toFixed(2);}catch(pa){}"
           "var interesting=(bL>0.45||oL>0.45||sL>0.45||gL>0.45||hasBI||pB||pA);"
           "if(!interesting)continue;"
           "DM.push({a:r5.width*r5.height,d:Math.round(r5.width)+'x'+Math.round(r5.height)+'|'+e5.tagName+'|'+cls(e5)"
             "+'|b'+bw+'='+bL.toFixed(2)+'|sh='+(sL<0?'-':sL.toFixed(2))+'|bg='+gL.toFixed(2)"
             "+(hasBI?'|BIMG='+bimg.slice(0,22):'')+(hasBG?'|BGIMG='+bgimg.slice(0,22):'')"
             "+(pB?'|'+pB:'')+(pA?'|'+pA:'')});}"
         "DM.sort(function(a,b){return b.a-a.a;});var dd=[];"
         "for(var z2=0;z2<DM.length&&z2<6;z2++)dd.push(DM[z2].d);"
         "out.push('P9DUMP['+(dd.length?dd.join(' ~ '):'none-light')+']');}catch(ed){out.push('P9DUMP[err '+(ed&&ed.message||ed)+']');}"
       "try{var fr=[];for(var fi=0;fi<window.frames.length;fi++){"
         "try{fr.push('f'+fi+':'+String(window.frames[fi].location.href||'').slice(-26));}catch(cx){fr.push('f'+fi+':xorigin');}}"
         "out.push('P9FR[frames='+window.frames.length+(fr.length?' '+fr.join(' '):'')+']');}catch(ef){out.push('P9FR[err]');}"
       "try{var SD2=[];for(var fj=0;fj<window.frames.length&&SD2.length<6;fj++){"
         "try{var fdoc=window.frames[fj].document;if(!fdoc)continue;var fel=fdoc.querySelectorAll('*'),flim=Math.min(fel.length,3000);"
           "for(var fq=0;fq<flim&&SD2.length<6;fq++){var fe2=fel[fq];var fr2=fe2.getBoundingClientRect();"
             "if(fr2.width<250||fr2.height<28)continue;var fs2=getComputedStyle(fe2);"
             "var fbw=parseFloat(fs2.borderTopWidth)||0;var fbL=fbw>0?lum(fs2.borderTopColor):-1;"
             "var fsh=String(fs2.boxShadow||'');var fsL=(fsh&&fsh!=='none')?lum(fsh):-1;"
             "var fgL=lum(fs2.backgroundColor);var fmx=Math.max(fbL,fsL,fgL);if(fmx<0.45)continue;"
             "SD2.push('f'+fj+'|'+Math.round(fr2.width)+'x'+Math.round(fr2.height)+'|'+fe2.tagName+'|'+cls(fe2)+'|b='+fbL.toFixed(2)+'|sh='+(fsL<0?'-':fsL.toFixed(2))+'|bg='+fgL.toFixed(2));}"
         "}catch(cy){}}"
         "out.push('P9SUBD['+(SD2.length?SD2.join(' ~ '):'none')+']');}catch(eg){out.push('P9SUBD[err]');}"
       "try{var IMG=document.querySelectorAll('img'),IC=[];"
         "for(var iz=0;iz<IMG.length&&IC.length<6;iz++){var im=IMG[iz];var ir=im.getBoundingClientRect();"
           "if(ir.width<40||ir.height<40)continue;var wr=im.parentElement;if(!wr)continue;"
           "var ws=getComputedStyle(wr),is=getComputedStyle(im);"
           "var nw=im.naturalWidth||0,nh=im.naturalHeight||0;""var nar=(nh>0)?(nw/nh):0,rar=(ir.height>0)?(ir.width/ir.height):0;""var fit=(nar>0&&rar>0)?Math.abs(nar-rar)/nar:-1;""IC.push(Math.round(ir.width)+'x'+Math.round(ir.height)+'|IMG<'+wr.tagName+'|w='+cls(wr)+'|wbg='+ws.backgroundColor+'|by='+(wr.__adBy||im.__adBy||'-')+'|of='+is.objectFit+'|nat='+nw+'x'+nh+'|ar='+(fit<0?'?':fit.toFixed(2))+'|ibg='+is.backgroundColor);}"
         "out.push('P9CROP['+(IC.length?IC.join(' ~ '):'none')+']');}catch(ecc){out.push('P9CROP[err]');}"
       "try{var SEL=['[class*=_container_]','[class*=mosaic-container]','[class*=puis-card]','[class*=gwm-tile]'];"
         "var PO=[];for(var pi=0;pi<SEL.length;pi++){var nl=document.querySelectorAll(SEL[pi]);"
           "var big=0,fr='';for(var pj=0;pj<nl.length;pj++){var pr=nl[pj].getBoundingClientRect();"
             "if(pr.width>=150&&pr.height>=40){big++;if(!fr)fr=Math.round(pr.width)+'x'+Math.round(pr.height)+'@'+Math.round(pr.left)+','+Math.round(pr.top);}}"
           "PO.push(SEL[pi].replace('[class*=','').replace(']','')+'='+nl.length+'/big'+big+(fr?' '+fr:''));}"
         "out.push('P9PAINT['+PO.join(' ~ ')+']');}catch(ep){out.push('P9PAINT[err]');}"
       "try{var W=window.innerWidth,H=window.innerHeight,PT=[],seen={};"
         "function desc(e){var st=getComputedStyle(e);"
           "return e.tagName+'|'+cls(e)+'|bw='+st.borderTopWidth+'/'+st.borderLeftWidth"
             "+'|bc='+st.borderLeftColor+'|bg='+st.backgroundColor+'|ol='+st.outlineWidth+' '+st.outlineColor;}"
         "var pts=[];"
         "for(var yy=140;yy<H-60;yy+=60){pts.push([6,yy]);pts.push([14,yy]);pts.push([22,yy]);}"
         "for(var xx=20;xx<W-20;xx+=Math.max(40,Math.floor(W/8))){pts.push([xx,H*0.30|0]);pts.push([xx,H*0.55|0]);}"
         "for(var pk=0;pk<pts.length&&PT.length<10;pk++){var px=pts[pk][0],py=pts[pk][1];"
           "var el=null;try{el=document.elementFromPoint(px,py);}catch(e1){}"
           "if(!el){PT.push(px+','+py+'=>NULL');continue;}"
           "var chain=[],n=el,d=0;"
           "while(n&&d<3){chain.push(desc(n));n=n.parentElement;d++;}"
           "var key=chain.join('>');if(seen[key])continue;seen[key]=1;"
           "PT.push(px+','+py+'=>'+chain.join(' >> '));}"
         "out.push('P9POINT[vw='+W+'x'+H+' '+PT.join(' ~~ ')+']');}catch(ept){out.push('P9POINT[err '+(ept&&ept.message||ept)+']');}"
       "try{var age=(window.__AD_T0__?(Date.now()-window.__AD_T0__):-1);"
         "var drs=document.querySelectorAll('style.darkreader').length;"
         "var drAttr=document.querySelectorAll('[data-darkreader-inline-bgcolor],[data-darkreader-inline-color]').length;"
         "var imgs=document.querySelectorAll('img').length;"
         "var loaded=0,sized=0;var IM=document.querySelectorAll('img');"
         "for(var wi=0;wi<IM.length&&wi<400;wi++){if(IM[wi].complete)loaded++;"
           "var rr=IM[wi].getBoundingClientRect();if(rr.width>2&&rr.height>2)sized++;}"
         "out.push('P9WARM[age='+age+'ms pretheme='+(window.__AD_PRETHEMED__===undefined?'?':window.__AD_PRETHEMED__)"
           "+' reinj='+(window.__AD_REINJ__||0)+' nav='+(window.__AD_NAV__===undefined?'?':window.__AD_NAV__)"
           "+' drstyles='+drs+' drattr='+drAttr+' imgs='+imgs+' complete='+loaded+' sized='+sized"
           "+' rs='+document.readyState+']');}catch(ew){out.push('P9WARM[err]');}"
       "return out.join(' ');"
       "}catch(err){return 'P8ERR['+(err&&err.message||err)+']';}})()";
}

// v5.363 focused diagnostics: one web probe per visible WKWebView after a screen
// settles. This preserves P21/P24/P26/P27/P30 evidence without the old census,
// layer dump, media probes, or recursive native offender walk on every appearance.
static void ADFocusedProbe363(void){
    @try {
        if (!gP.enabled) return;
        static CFAbsoluteTime last=0; CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
        if(now-last<4.0) return; last=now;
        ADLog(@"P28HZ[pref=%d screenMax=%ld]", gP.force120Hz?1:0,
              (long)UIScreen.mainScreen.maximumFramesPerSecond);
        NSMutableSet *seen=[NSMutableSet set]; int sent=0;
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes){
            if (sent>=2) break;
            if (![sc isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)sc).windows){
                if (sent>=2) break;
                if (!w || w.hidden || w.alpha<0.05) continue;
                NSMutableArray *wv=[NSMutableArray array];
                ADCollectWebViews(w,wv,0);
                for (WKWebView *web in wv){
                    if(sent>=2) break;
                    NSValue *key=[NSValue valueWithNonretainedObject:web];
                    if ([seen containsObject:key]) continue;
                    [seen addObject:key];
                    if (!web.window || web.hidden || web.alpha<0.05) continue;
                    CGRect wr=[web convertRect:web.bounds toView:w]; if(!CGRectIntersectsRect(wr,w.bounds)||wr.size.width<40||wr.size.height<40) continue;
                    sent++;
                    [web evaluateJavaScript:ADProbeWebJS() completionHandler:^(id r, NSError *e){
                        @try {
                            if ([r isKindOfClass:[NSString class]] && [(NSString *)r length]) ADLog(@"%@",r);
                            else if (e) ADLog(@"P8ERR[wk %@/%ld]",e.domain,(long)e.code);
                        } @catch(...) {}
                    }];
                }
            }
        }
    } @catch(...) {}
}

// ── NATIVE HAIRLINE / BORDER SWEEP (P9NAT) ──────────────────────────────────
// ADHairlineFix and ADNormalizeBorder already exist and are correct, but their only
// caller (ADLaunchDarkenTree) is gated by "ADUptime() > 4.2" -- they run for the
// first four seconds of app launch and never again. That is why the person-tab card
// outlines were never darkened natively and why P6HAIR/P3BORDER never printed while
// sitting on that pane: the walker was not running. This re-runs the same two
// correctors on the live window on the census cadence, and reports what it saw so a
// zero is evidence rather than silence.
//
// Deliberately conservative: it only recolours (a) CALayer borders that are already
// light and (b) thin light-background hairline views. It never touches bounds,
// hidden, alpha, image content, or the view hierarchy, and never repaints whole
// views -- so it cannot blank a screen the way native modal repainting did earlier.
static int gNatSweepLogged = 0;
// READ-ONLY native background census (P9BG). Every native check so far counted
// layer BORDERS (P3BORDER/P9NAT bseen) or thin hairline VIEWS (P6HAIR/hseen) --
// nothing ever counted a plain UIView carrying a light backgroundColor. The
// native background darkening lives in the launch-gated walker (ADUptime()>4.2),
// so any view composed after launch keeps its stock light background, and a light
// container behind web content reads on screen as card edges. This only READS:
// no setter is called anywhere on this path, so it cannot blank a surface.
static int gBGLight = 0, gBGSeen = 0;
static NSMutableArray *gBGSamples = nil;
static void ADNativeBGCensus(UIView *v, int depth){
    if (!v || depth > 14) return;
    @try {
        if (v.hidden || v.alpha < 0.05) return;
        CGRect fr = v.frame;
        if (fr.size.width >= 40 && fr.size.height >= 1){
            gBGSeen++;
            UIColor *bg = v.backgroundColor;
            CGFloat r=0,g=0,b=0,a=0;
            if (bg && [bg getRed:&r green:&g blue:&b alpha:&a] && a > 0.30){
                CGFloat L = 0.2126*r + 0.7152*g + 0.0722*b;
                if (L > 0.35){
                    gBGLight++;
                    if (gBGSamples.count < 6){
                        [gBGSamples addObject:
                          [NSString stringWithFormat:@"%s|%dx%d|L=%.2f|a=%.2f",
                            object_getClassName(v),
                            (int)fr.size.width, (int)fr.size.height, L, a]];
                    }
                }
            }
        }
        for (UIView *sv in v.subviews) ADNativeBGCensus(sv, depth + 1);
    } @catch(...) {}
}

static void ADNativeSweepWalk(UIView *v, int depth){
    if (!v || depth > 12) return;
    @try {
        if (v.hidden || v.alpha < 0.05) return;
        ADNormalizeBorder(v);
        ADHairlineFix(v);
        for (UIView *sv in v.subviews) ADNativeSweepWalk(sv, depth + 1);
    } @catch(...) {}
}
static void ADNativeSweep(void){
    @try {
        if (!gP.enabled) return;
        if (!ADRecolorOn()) return;
        int b0 = gBorderFix, h0 = gHairFix, bs0 = gBorderSeen, hs0 = gHairSeen;
        for (UIWindow *w in [UIApplication sharedApplication].windows){
            if (!w || w.hidden || w.alpha < 0.05) continue;
            ADNativeSweepWalk(w, 0);
        }
        int db = gBorderFix - b0, dh = gHairFix - h0;
        int dbs = gBorderSeen - bs0, dhs = gHairSeen - hs0;
        // Read-only background census on the same cadence.
        @try {
            gBGLight = 0; gBGSeen = 0;
            if (!gBGSamples) gBGSamples = [NSMutableArray array];
            [gBGSamples removeAllObjects];
            for (UIWindow *w2 in [UIApplication sharedApplication].windows){
                if (!w2 || w2.hidden || w2.alpha < 0.05) continue;
                ADNativeBGCensus(w2, 0);
            }
            if (gNatSweepLogged < 200)
                ADLog(@"P9BG[light=%d seen=%d %@]", gBGLight, gBGSeen,
                      gBGSamples.count ? [gBGSamples componentsJoinedByString:@" ~ "] : @"none");
        } @catch(...) {}
        if (gNatSweepLogged < 200){
            gNatSweepLogged++;
            ADLog(@"P9NAT[bseen=%d bfix=%d hseen=%d hfix=%d totb=%d toth=%d]",
                  dbs, db, dhs, dh, gBorderFix, gHairFix);
        }
    } @catch(...) {}
}

static void ADWebViewCensus(void){
    @try {
        if (!gP.enabled) return;
        // RE-ARM PER PANE. Latching after two productive rounds meant this fired on
        // the home feed and never ran again -- so the Interests pane, which P5POS just
        // showed has no native "+" at all, was never censused. Every pane gets a look.
        // Cap raised 400 -> 2000 in v5.263: the census also drives the card/pill
        // border fix (ADCardBorderFixJS), and at 400 it stopped mid-session, so a
        // pane opened late (the person tab, after heavy testing) got no fix pass.
        static int rounds = 0;
        if (rounds++ > 100000) return;
        UIWindow *key = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows)
            if (w && !w.hidden && w.alpha > 0.05){ key = w; break; }
        if (!key) return;
        ADNativeSweep();   // recurring native hairline/border correction (P9NAT)
        NSMutableArray *wvs = [NSMutableArray array];
        ADCollectWebViews(key, wvs, 0);
        if (!wvs.count){ if ((rounds % 20) == 1) ADLog(@"WVCENSUS[no webviews]"); return; }
        int idx = 0;
        for (WKWebView *w in wvs){
            int myIdx = idx++;
            // FIVE DETECTORS, REPORTED SEPARATELY. "stars=0" has been my own matcher
            // failing, not proof of absence: it tested class and src only, and this app
            // uses hashed CSS-module names (_cXVhZ_header-icon_2) while a sprite drawn
            // as a CSS background-image has no src at all. Each signal is counted on
            // its own so the log says WHICH one finds the widget -- and a genuine zero
            // across all five is then real evidence rather than a blind spot.
            NSString *js =
              @"(function(){try{var E=document.querySelectorAll('*');"
               "var aN=0,cN=0,bN=0,nN=0,sN=0,ex='';"
               "var S=document.querySelectorAll('img,svg,i,span,div,a');"
               "for(var i=0;i<S.length&&i<4000;i++){var el=S[i];"
                 "var c=String((el.className&&el.className.baseVal!==undefined)"
                   "?el.className.baseVal:(el.className||''));"
                 "var sr=String(el.currentSrc||el.src||'');"
                 "var al=String(el.getAttribute&&(el.getAttribute('aria-label')||el.getAttribute('title'))||'');"
                 "var bg='';try{bg=String(getComputedStyle(el).backgroundImage||'');}catch(e2){}"
                 "var tx=(el.childElementCount===0)?String(el.textContent||'').trim():'';"
                 "var hit=0;"
                 "if(/out of 5|stars?\\b/i.test(al)){aN++;hit=1;}"
                 "if(/star|rating|review/i.test(c)){cN++;hit=1;}"
                 "if(/star|rating|review/i.test(sr)||/star|rating|review/i.test(bg)){bN++;hit=1;}"
                 "if(/^[0-5][.,][0-9]$/.test(tx)){nN++;hit=1;}"
                 "if(hit){sN++;if(!ex)ex=el.tagName+'|c='+c.slice(0,20)+'|al='+al.slice(0,16)"
                   "+'|bg='+(bg.indexOf('url(')>=0?'y':'n')+'|t='+tx.slice(0,6);}}"
               "return 'els='+E.length+' any='+sN+' aria='+aN+' cls='+cN+' img='+bN+' num='+nN"
                 "+' frames='+window.frames.length"
                 "+' u='+String(location.pathname||'/').slice(-20)"
                 "+(ex?(' ex='+ex):'');"
               "}catch(e){return 'err '+e;}})()";
            [w evaluateJavaScript:js completionHandler:^(id r, NSError *e){
                @try {
                    NSString *v = [r isKindOfClass:[NSString class]] ? (NSString *)r
                                : (e ? [NSString stringWithFormat:@"ERR %@/%ld", e.domain, (long)e.code]
                                     : @"(nil)");

                    ADLog(@"WVCENSUS[#%d of %lu %@]", myIdx, (unsigned long)wvs.count, v);
                } @catch(...) {}
            }];
            // Same web view, same cadence: name the CSS borders (P8BORD) and the
            // Interests "+" candidates (P7PLUS) so the next fix is scoped, not guessed.
            [w evaluateJavaScript:ADProbeWebJS() completionHandler:^(id pr, NSError *pe){
                @try {
                    if ([pr isKindOfClass:[NSString class]] && [(NSString *)pr length])
                        ADLog(@"%@", pr);
                    else if (pe)
                        ADLog(@"P8ERR[wk %@/%ld]", pe.domain, (long)pe.code);
                } @catch(...) {}
            }];
            // v5.269: REMOVED the after-paint ADCardBorderFixJS pass. It ran on every
            // page and darkened borders AFTER first paint -> a "render then darken"
            // flash on every interface, and on the person tab it lost the race to
            // Dark Reader (which re-applies border-color inline between ticks). Card
            // borders are now handled pre-paint via the adcardfix stylesheet using
            // border-style (which DR never overrides), so no JS pass is needed.
        }
    } @catch(...) {}
}

// ── LAYER DUMP ──────────────────────────────────────────────────────────────
// A genuine change of approach. Native UIImageView, native text setters and the web
// DOM have each been eliminated on evidence, yet 24 WKCompositingViews and 45
// RCTViews are on screen. The gap is that React Native's Fabric components are not
// UIImageView or UILabel subclasses -- RCTImageComponentView and
// RCTParagraphComponentView draw into their own CALayer -- so every isKindOfClass:
// probe I have written looked past them, and every text hook keyed on setters they
// do not implement.
//
// So this asks nothing about class membership. It dumps EVERY view in the card band
// with what its layer is actually holding: contents, filters, compositingFilter,
// mask, and the accessibility label that Fabric does populate. Deduped by class and
// size so one repeated icon cannot eat the budget again.
static void ADLayerWalk(UIView *v, int depth, int *n, NSMutableSet *seen){
    if (!v || depth > 40 || *n >= 14 || v.hidden || v.alpha < 0.05) return;
    @try {
        CGRect f = [v convertRect:v.bounds toView:nil];
        CGFloat w = f.size.width, h = f.size.height;
        NSString *al = nil;
        @try { al = v.accessibilityLabel; } @catch(...) {}
        BOOL ratingish = (al.length && ([al rangeOfString:@"out of 5"].location != NSNotFound ||
                                        [al rangeOfString:@"star"].location != NSNotFound));
        BOOL banded = (f.origin.y > 200 && w >= 24 && w <= 220 && h >= 8 && h <= 60);
        if (ratingish || banded){
            NSString *key = [NSString stringWithFormat:@"%s|%.0fx%.0f",
                             object_getClassName(v), w, h];
            if (ratingish || ![seen containsObject:key]){
                if (!ratingish) [seen addObject:key];
                (*n)++;
                CALayer *l = v.layer;
                CGFloat tr = -1, tg = -1, tb = -1, ta = -1;
                if (v.tintColor) [v.tintColor getRed:&tr green:&tg blue:&tb alpha:&ta];
                ADLog(@"LAYER[%s layer=%s %.0fx%.0f y=%.0f contents=%d filters=%lu "
                       "cfilter=%s mask=%d sub=%lu tint=%.2f,%.2f,%.2f al='%@']",
                      object_getClassName(v), object_getClassName(l), w, h, f.origin.y,
                      l.contents ? 1 : 0, (unsigned long)l.filters.count,
                      l.compositingFilter ? object_getClassName(l.compositingFilter) : "-",
                      l.mask ? 1 : 0, (unsigned long)v.subviews.count,
                      tr, tg, tb,
                      al.length ? (al.length > 26 ? [al substringToIndex:26] : al) : @"-");
            }
        }
        for (UIView *sv in v.subviews) ADLayerWalk(sv, depth + 1, n, seen);
    } @catch(...) {}
}

static void ADLayerDump(void){
    @try {
        if (!gP.enabled) return;
        static int rounds = 0, found = 0;
        if (found >= 2 || rounds++ > 400) return;
        UIWindow *key = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows)
            if (w && !w.hidden && w.alpha > 0.05){ key = w; break; }
        if (!key) return;
        int n = 0;
        ADLayerWalk(key, 0, &n, [NSMutableSet set]);
        if (n) found++;
        else if ((rounds % 25) == 1) ADLog(@"LAYER[nothing in band round=%d]", rounds);
    } @catch(...) {}
}


// ── P11 MEDIA-CONTROL PROBE (v5.340) ──────────────────────────────────────────
// P10 proved the visible product-view heart and carousel dots are not in the DOM.
// Probe them from the native hierarchy by geometry instead of class-name guesses.
// The correctly-light share control is intentionally captured beside the dark
// heart so the two can be compared property-for-property. Also name any native
// "Pack" label and dump its actual text colour / ancestry.
static NSString *ADP11Color(UIColor *c){
    @try {
        if (!c) return @"-";
        CGFloat r=0,g=0,b=0,a=0;
        if (![c getRed:&r green:&g blue:&b alpha:&a]) return @"?";
        return [NSString stringWithFormat:@"%.2f,%.2f,%.2f/%.2f",r,g,b,a];
    } @catch(...) {}
    return @"?";
}

static NSString *ADP11LayerColor(CGColorRef cg){
    @try {
        if (!cg) return @"-";
        return ADP11Color([UIColor colorWithCGColor:cg]);
    } @catch(...) {}
    return @"?";
}

static NSString *ADP11Chain(UIView *v){
    @try {
        NSMutableArray *a=[NSMutableArray array];
        UIView *n=v; int d=0;
        while(n && d++<5){
            NSString *cn=[NSString stringWithUTF8String:object_getClassName(n)];
            [a addObject:cn ?: @"?"];
            n=n.superview;
        }
        return [a componentsJoinedByString:@">"];
    } @catch(...) {}
    return @"?";
}

static NSString *ADP11SubLayers(CALayer *l){
    @try {
        if (!l.sublayers.count) return @"-";
        NSMutableArray *a=[NSMutableArray array];
        NSUInteger n=MIN((NSUInteger)5,l.sublayers.count);
        for(NSUInteger i=0;i<n;i++){
            CALayer *q=l.sublayers[i];
            NSString *piece=nil;
            if ([q isKindOfClass:[CAShapeLayer class]]){
                CAShapeLayer *sh=(CAShapeLayer *)q;
                piece=[NSString stringWithFormat:@"%s(f=%@,s=%@)",
                       object_getClassName(q),ADP11LayerColor(sh.fillColor),ADP11LayerColor(sh.strokeColor)];
            } else {
                piece=[NSString stringWithFormat:@"%s(bg=%@,cont=%d)",
                       object_getClassName(q),ADP11LayerColor(q.backgroundColor),q.contents?1:0];
            }
            [a addObject:piece ?: @"?"];
        }
        return [a componentsJoinedByString:@","];
    } @catch(...) {}
    return @"?";
}

static NSString *ADP11Text(UIView *v){
    @try {
        if ([v isKindOfClass:[UILabel class]]) return ((UILabel *)v).text;
        if ([v respondsToSelector:@selector(text)]){
            id t=[v performSelector:@selector(text)];
            if ([t isKindOfClass:[NSString class]]) return t;
        }
        NSString *al=v.accessibilityLabel;
        if (al.length) return al;
    } @catch(...) {}
    return nil;
}

static int gP11Rounds=0;
static void ADP11Walk(UIView *v, int depth, CGFloat sw, CGFloat sh, int *icons, int *dots, int *packs){
    if (!v || depth>44 || v.hidden || v.alpha<0.05) return;
    @try {
        CGRect f=[v convertRect:v.bounds toView:nil];
        CGFloat w=f.size.width,h=f.size.height,x=f.origin.x,y=f.origin.y;
        BOOL p11Onscreen=!(w<=0 || h<=0 || x>sw || y>sh || x+w<0 || y+h<0);

        NSString *txt=ADP11Text(v);
        if (p11Onscreen && *packs<8 && txt.length){
            NSString *t=[txt stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([t caseInsensitiveCompare:@"Pack"]==NSOrderedSame){
                UIColor *tc=nil;
                @try {
                    if ([v isKindOfClass:[UILabel class]]) tc=((UILabel *)v).textColor;
                    else if ([v respondsToSelector:@selector(textColor)]) tc=[(id)v textColor];
                } @catch(...) {}
                (*packs)++;
                ADLog(@"P11PACK[%s %.0fx%.0f @%.0f,%.0f text='%@' tc=%@ tint=%@ bg=%@ lbg=%@ contents=%d sub=%lu chain=%@]",
                      object_getClassName(v),w,h,x,y,t,
                      ADP11Color(tc),ADP11Color(v.tintColor),ADP11Color(v.backgroundColor),
                      ADP11LayerColor(v.layer.backgroundColor),v.layer.contents?1:0,
                      (unsigned long)v.layer.sublayers.count,ADP11Chain(v));
            }
        }

        // Heart + share live together on the right half beneath the product image.
        // Capture both; the share glyph is our known-good control sample.
        if (p11Onscreen && *icons<18 && x>sw*0.52 && y>sh*0.48 && y<sh*0.90 &&
            w>=18 && w<=70 && h>=18 && h<=70){
            BOOL isIV=[v isKindOfClass:[UIImageView class]];
            BOOL isBtn=[v isKindOfClass:[UIButton class]];
            UIImage *im=isIV?((UIImageView *)v).image:(isBtn?((UIButton *)v).currentImage:nil);
            const char *cn=object_getClassName(v);
            BOOL interesting=im || v.layer.contents || v.layer.sublayers.count ||
                             (txt.length>0) || (cn && strstr(cn,"SVG")) ||
                             (cn && strstr(cn,"Image"));
            if (interesting){
                CGFloat cf=0,av=0,sat=0; BOOL dg=im?ADImageIsDarkGlyph(im,&cf,&av,&sat):NO;
                (*icons)++;
                ADLog(@"P11ICON[%s %.0fx%.0f @%.0f,%.0f al='%@' img=%d mode=%ld dark=%d clear=%.2f avg=%.2f sat=%.2f tint=%@ bg=%@ lbg=%@ contents=%d sub=%lu layers=%@ chain=%@]",
                      object_getClassName(v),w,h,x,y,txt.length?txt:@"-",
                      im?1:0,im?(long)im.renderingMode:-1L,dg?1:0,cf,av,sat,
                      ADP11Color(v.tintColor),ADP11Color(v.backgroundColor),
                      ADP11LayerColor(v.layer.backgroundColor),v.layer.contents?1:0,
                      (unsigned long)v.layer.sublayers.count,ADP11SubLayers(v.layer),ADP11Chain(v));
            }
        }

        // Carousel indicators are tiny round views in the same lower media band.
        if (p11Onscreen && *dots<24 && y>sh*0.45 && y<sh*0.90 &&
            w>=3 && w<=20 && h>=3 && h<=20 && fabs(w-h)<=5){
            CGFloat rad=v.layer.cornerRadius;
            UIColor *bg=v.backgroundColor;
            BOOL paint=(bg!=nil || v.layer.backgroundColor!=nil || v.layer.contents!=nil || v.layer.sublayers.count>0);
            if (paint && (rad>=MIN(w,h)*0.20 || w<=10 || h<=10)){
                (*dots)++;
                ADLog(@"P11DOT[%s %.0fx%.0f @%.0f,%.0f rad=%.1f bg=%@ lbg=%@ tint=%@ contents=%d sub=%lu layers=%@ chain=%@]",
                      object_getClassName(v),w,h,x,y,rad,ADP11Color(bg),
                      ADP11LayerColor(v.layer.backgroundColor),ADP11Color(v.tintColor),
                      v.layer.contents?1:0,(unsigned long)v.layer.sublayers.count,
                      ADP11SubLayers(v.layer),ADP11Chain(v));
            }
        }

        for (UIView *sv in v.subviews) ADP11Walk(sv,depth+1,sw,sh,icons,dots,packs);
    } @catch(...) {}
}

static void ADMediaNativeProbe(void){
    @try {
        if (!gP.enabled || gP11Rounds++>80) return;
        int icons=0,dots=0,packs=0;
        for (UIWindow *w in [UIApplication sharedApplication].windows){
            if (!w || w.hidden || w.alpha<0.05) continue;
            CGFloat sw=w.bounds.size.width, sh=w.bounds.size.height;
            ADP11Walk(w,0,sw,sh,&icons,&dots,&packs);
        }
        ADLog(@"P11MEDIA[icons=%d dots=%d packs=%d round=%d]",icons,dots,packs,gP11Rounds);
    } @catch(...) {}
}


// ── P15 PRODUCT-DETAIL HEART LAYER RESCUE (v5.344) ─────────────────────────────
// P10-P14 proved the black PDP heart is not represented by a normal DOM node and
// is not a child of the adjacent web share control. Older AmazonDark heart fixes
// succeeded by whitening the GLYPH paint, not its surrounding disc. Reuse the
// same Core Animation colorInvert+hueRotate recipe already proven on RNSVGSvgView,
// but only for transparent, glyph-sized layers in the narrow heart slot immediately
// left of Share. Dots are centered much farther left and Share itself is outside
// the x band, so neither is eligible. This also catches WebKit compositor layers,
// which the generic native colour hooks intentionally skip.
static const void *kADP15HeartKey = &kADP15HeartKey;
static const void *kADP15HeartFiltersKey = &kADP15HeartFiltersKey;
static int gP15Rounds = 0;
static int gP15LogLeft = 36;

static BOOL ADP15LayerTransparent(CALayer *l){
    @try {
        if (!l.backgroundColor) return YES;
        UIColor *c=[UIColor colorWithCGColor:l.backgroundColor];
        CGFloat r=0,g=0,b=0,a=0;
        if ([c getRed:&r green:&g blue:&b alpha:&a]) return a < 0.15;
    } @catch(...) {}
    return NO;
}
static BOOL ADP15ShapeDark(CALayer *l){
    @try {
        if (![l isKindOfClass:[CAShapeLayer class]]) return NO;
        CAShapeLayer *sh=(CAShapeLayer *)l;
        CGColorRef arr[2]={sh.fillColor,sh.strokeColor};
        for(int i=0;i<2;i++){
            if(!arr[i]) continue;
            UIColor *c=[UIColor colorWithCGColor:arr[i]];
            CGFloat r=0,g=0,b=0,a=0;
            if([c getRed:&r green:&g blue:&b alpha:&a] && a>0.20 &&
               (0.2126*r+0.7152*g+0.0722*b)<0.38) return YES;
        }
    } @catch(...) {}
    return NO;
}
static void ADP15ApplyHeartFilter(CALayer *l){
    @try {
        NSArray *ours=objc_getAssociatedObject(l,kADP15HeartFiltersKey);
        if (objc_getAssociatedObject(l,kADP15HeartKey) && l.filters.count) return;
        Class F=NSClassFromString(@"CAFilter"); if(!F) return;
        id inv=[F filterWithType:@"colorInvert"]; if(!inv) return;
        id hue=[F filterWithType:@"hueRotate"];
        @try { [hue setValue:@(M_PI) forKey:@"inputAngle"]; } @catch(...) { hue=nil; }
        ours=hue?@[inv,hue]:@[inv];
        objc_setAssociatedObject(l,kADP15HeartKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(l,kADP15HeartFiltersKey,ours,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        l.filters=ours;
    } @catch(...) {}
}
static void ADP15HeartWalk(CALayer *l, CALayer *root, CGFloat sw, CGFloat sh,
                           int depth, int *seen, int *fixed){
    if(!l||!root||depth>70||l.hidden||l.opacity<0.05||*seen>4500) return;
    (*seen)++;
    @try {
        CGRect fr=[l convertRect:l.bounds toLayer:root];
        CGFloat w=fabs(fr.size.width),h=fabs(fr.size.height);
        CGFloat cx=CGRectGetMidX(fr),cy=CGRectGetMidY(fr);
        // Measured PDP geometry across 430x813 and 430x896 captures: heart sits
        // around x=.83W, y=.79H; Share begins around x=.91W. Give layout some room.
        BOOL band=(cx>sw*0.75 && cx<sw*0.90 && cy>sh*0.70 && cy<sh*0.86 &&
                   w>=6 && w<=54 && h>=6 && h<=54);
        if(band){
            BOOL tr=ADP15LayerTransparent(l);
            BOOL shapeDark=ADP15ShapeDark(l);
            BOOL hasContents=(l.contents!=nil);
            // Filter only the actual paint leaf. Applying the same invert to a
            // compositor parent AND its painted child would double-invert the glyph
            // back to black. CAShapeLayer is paint by definition; contents-backed
            // layers qualify only when they have no child layers of their own.
            BOOL paintLeaf=shapeDark || (hasContents && l.sublayers.count==0);
            BOOL candidate=tr && paintLeaf;
            if(candidate){
                ADP15ApplyHeartFilter(l); (*fixed)++;
            }
            if(gP15LogLeft>0){gP15LogLeft--;
                NSString *fc=@"-",*sc=@"-";
                if([l isKindOfClass:[CAShapeLayer class]]){
                    CAShapeLayer *shp=(CAShapeLayer *)l;
                    fc=ADP11LayerColor(shp.fillColor);sc=ADP11LayerColor(shp.strokeColor);
                }
                ADLog(@"P15HEARTLAYER[%s %.0fx%.0f @%.0f,%.0f cont=%d trans=%d shapeDark=%d fill=%@ stroke=%@ filters=%lu fixed=%d]",
                      object_getClassName(l),w,h,fr.origin.x,fr.origin.y,
                      hasContents?1:0,tr?1:0,shapeDark?1:0,fc,sc,
                      (unsigned long)l.filters.count,candidate?1:0);
            }
        }
        for(CALayer *q in l.sublayers) ADP15HeartWalk(q,root,sw,sh,depth+1,seen,fixed);
    } @catch(...) {}
}
static void ADP15HeartLayerPass(void){
    if(!ADRecolorOn() || gP15Rounds++>120) return;
    @try {
        int seen=0,fixed=0;
        for(UIWindow *w in [UIApplication sharedApplication].windows){
            if(!w||w.hidden||w.alpha<0.05) continue;
            ADP15HeartWalk(w.layer,w.layer,w.bounds.size.width,w.bounds.size.height,0,&seen,&fixed);
        }
        if((fixed>0 || gP15Rounds<=8) && gP15LogLeft>0){gP15LogLeft--;
            ADLog(@"P15HEARTLAYER[summary round=%d seen=%d fixed=%d]",gP15Rounds,seen,fixed);
        }
    } @catch(...) {}
}

static void ADSweepAllWindows(void){
    if (!ADRecolorOn()) return;
    @try {
        int nwin = 0;
        gSwViews = gSwImgSeen = gSwGlyphFixed = gSwDarkLabels = gSwLabelFixed = 0;
        gSwTemplateSeen = gSwTintFixed = 0;
        gSwSample[0] = 0;
        gSwTintNow[0] = 0;
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes){
            if (![sc isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)sc).windows){ nwin++; ADSweepTimed(w, NO, "window"); }
        }
        ADVoiceNativeSweep();
        static NSString *last = nil;
        NSString *now = [NSString stringWithFormat:
                         @"win=%d views=%d img=%d tmpl=%d tintFixed=%d glyphFixed=%d darkLabels=%d labelFixed=%d%s%s%s%s",
                         nwin, gSwViews, gSwImgSeen, gSwTemplateSeen, gSwTintFixed,
                         gSwGlyphFixed, gSwDarkLabels, gSwLabelFixed,
                         gSwSample[0]  ? " declined=" : "", gSwSample[0]  ? gSwSample  : "",
                         gSwTintNow[0] ? " tintNow="  : "", gSwTintNow[0] ? gSwTintNow : ""];
        if (!last || ![last isEqualToString:now]){ last = now; ADLog(@"sweep %@", now); }
        // v5.345: P15 found no independently addressable paint layer for the PDP heart.
        // Leave the forensic code in place, but stop spending every sweep walking it.
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
// ─── launch-window white killer ─────────────────────────────────────────────────
// Setting the splash VC's backgroundColor was correct but insufficient: the 4+
// second white screen is an OPAQUE surface drawn over it -- most likely a
// fullscreen UIImageView whose bitmap bakes the logo into a white field, which
// no backgroundColor can darken. For the first 12 seconds of the process, any
// screen-covering view is inspected: a light background is repainted, and a
// mostly-light IMAGE gets the same colorInvert+hueRotate the RNSVG icons use --
// white field goes dark, dark logo goes light, coloured artwork keeps its hue.
// splashdump lines name every large surface seen, so if the white lives in a
// class this net misses, the next log says exactly which.
static double gADT0 = 0;
static inline double ADUptime(void){
    double now = CFAbsoluteTimeGetCurrent();
    if (gADT0 == 0) gADT0 = now;
    return now - gADT0;
}
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
static int gSplashDumpLeft = 10;
static int gSplashFixLeft  = 6;
static BOOL ADViewHasContentDescendant(UIView *v, int depth){
    if (!v || depth > 3) return NO;
    @try {
        for (UIView *sv in v.subviews){
            if ([sv isKindOfClass:[UITextField class]] || [sv isKindOfClass:[UITextView class]]) return YES;
            if ([sv isKindOfClass:[UILabel class]] && ((UILabel *)sv).text.length) return YES;
            if ([sv isKindOfClass:[UIImageView class]] && ((UIImageView *)sv).image) return YES;
            if (ADViewHasContentDescendant(sv, depth + 1)) return YES;
        }
    } @catch(...) {}
    return NO;
}
static int gSplashPillLeft = 4;
static void ADLaunchWhiteGuard(UIView *v){
    @try {
        if (!gP.enabled || ADUptime() > 12.0) return;
        CGRect sb = [UIScreen mainScreen].bounds;
        CGFloat w = v.bounds.size.width, h = v.bounds.size.height;
        // The launch storyboard's decorative search-bar outline: a short, wide,
        // rounded/bordered pill near the top. On the dark launch frame it reads as
        // a stray border (reported as a "dynamic island border"). Hide it -- it is
        // decoration on a screen that exists for under a second.
        if (ADUptime() < 4.0 &&
            h >= 36 && h <= 96 && w >= sb.size.width*0.55 && w < sb.size.width*0.98 &&
            (v.layer.cornerRadius >= 12.0 || v.layer.borderWidth > 0.4) &&
            !ADViewHasContentDescendant(v, 0)){
            if (gSplashPillLeft > 0){
                gSplashPillLeft--;
                ADLog(@"splashpill hid cls=%s %.0fx%.0f r=%.0f bw=%.1f",
                      object_getClassName(v), w, h,
                      (double)v.layer.cornerRadius, (double)v.layer.borderWidth);
            }
            v.layer.borderWidth = 0;
            v.hidden = YES;
            return;
        }
        if (w < sb.size.width*0.6 || h < sb.size.height*0.5) return;
        BOOL isIv = [v isKindOfClass:[UIImageView class]];
        UIImage *im = isIv ? ((UIImageView *)v).image : nil;
        UIColor *bg = v.backgroundColor; double bl = -1; CGFloat r,g,b,a;
        if (bg && [bg getRed:&r green:&g blue:&b alpha:&a] && a > 0.5)
            bl = 0.2126*r + 0.7152*g + 0.0722*b;
        if (gSplashDumpLeft > 0 && (im || bl >= 0)){
            gSplashDumpLeft--;
            ADLog(@"splashdump cls=%s %.0fx%.0f bg=%.2f img=%d light=%d t=%.1f",
                  object_getClassName(v), w, h, bl, im?1:0,
                  im?ADImageMostlyLight(im):0, ADUptime());
        }
        if (bl > 0.55 && !ADIsOwnColor(bg)) v.backgroundColor = ADColorFromHex(gP.bgHex);
        if (im && gSplashFixLeft > 0 && !objc_getAssociatedObject(v, kADRNInvertKey) &&
            ADImageMostlyLight(im)){
            Class F = NSClassFromString(@"CAFilter");
            if (F){
                id inv = [F filterWithType:@"colorInvert"];
                id hue = [F filterWithType:@"hueRotate"];
                @try { [hue setValue:@(M_PI) forKey:@"inputAngle"]; } @catch(...) { hue = nil; }
                if (inv){
                    NSArray *ours = hue ? @[inv, hue] : @[inv];
                    v.layer.filters = ours;
                    objc_setAssociatedObject(v, kADRNFiltersKey, ours, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    objc_setAssociatedObject(v, kADRNInvertKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    gSplashFixLeft--;
                    ADLog(@"splash inverted cls=%s %.0fx%.0f", object_getClassName(v), w, h);
                }
            }
        }
    } @catch(...) {}
}
static void ADDarkenSplashTree(UIView *v, int d){
    if (!v || d > 8) return;
    @try { ADLaunchWhiteGuard(v); for (UIView *sv in v.subviews) ADDarkenSplashTree(sv, d+1); } @catch(...) {}
}
static void ADDarkenSplash(UIViewController *vc){
    if (!gP.enabled) return;
    @try {
        UIView *v = vc.view;
        if (v){ v.backgroundColor = ADColorFromHex(gP.bgHex); ADDarkenSplashTree(v, 0); }
    } @catch(...) {}
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

// ─── decaying launch timer (bounded) ──────────────────────────────────────────────
// Catches views built before injection. It stops after the launch window, but that
// no longer leaves later tabs white: new web views re-theme themselves on mount
// (WKWebView didMoveToWindow) and on the RN tab-switch hook below, and native views
// are themed at assignment. So this timer is purely a launch-time backstop.
static int gSweepTicks = 0;
static void ADStartTimer(void){
    if (gSweepTicks++ > 20) {           // ~40s, then done — events take over
        ADRaw("[AmazonDark] launch sweeps complete; event-driven from here");
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.0*NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{ ADSweep(); ADStartTimer(); });
}

// ─── event-driven re-theme on tab / screen change (kills the white flash) ──────────
// The flashing you saw is a NEW web view being mounted for the tab you switch to:
// for a few frames it shows its own white page before Dark Reader paints the DOM,
// and if the launch timer had already stopped, nothing re-applied. Rather than run
// a forever-timer, we re-theme exactly when the view hierarchy changes. A short
// coalesced burst (0 / 60 / 200 / 500 ms) covers the mount-to-first-paint window
// without a standing cost.
static const void *kADVCPrimed364 = &kADVCPrimed364;
static void ADReapplyBurst(UIViewController *vc){
    // v5.364: returning to an already-mounted tab is not a navigation. Its WKUserScript,
    // pageshow/visibility lane and assignment hooks are already live, so globally walking
    // every WKWebView + native window here only starved Home's renderer (black-screen until
    // refresh). First appearance gets one 4ms-bounded local native catch-up; later returns
    // only reassert the dark trait.
    @try {
        ADForceWindowsDarkTrait();
        if (!vc || objc_getAssociatedObject(vc,kADVCPrimed364)) return;
        objc_setAssociatedObject(vc,kADVCPrimed364,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UIViewController *wvc=vc;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,220*1000000LL),dispatch_get_main_queue(),^{ @try {
            UIViewController *v=wvc; if(v&&v.viewIfLoaded&&v.view.window) ADSweepTimed(v.view,ADInTabBarChain(v.view),"appear364");
        } @catch(...) {} });
    } @catch(...) {}
}

// UIViewController appearance is the most reliable, arch-agnostic signal for a tab
// switch or push. Gate to controllers that actually host content so we do not fire
// the burst for every cell-sized child VC.
%hook UIViewController
- (void)viewDidLoad {
    %orig;
    // Earliest reachable point for the launch storyboard's controller: darken
    // before the first frame is composited, so the captured snapshot is dark.
    // (launch darkening retired -- see ADLaunchScreenDarkPass)
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // v5.363: retired legacy automatic probe avalanche; ADRunProbe below remains.
    @try {
        if (!ADRecolorOn()) return;
        if (self.view.window && self.view.bounds.size.width > 200){
            NSString *vcKey = [NSString stringWithUTF8String:object_getClassName(self)];
            static NSMutableSet *vcSeen = nil;
            if (!vcSeen) vcSeen = [NSMutableSet set];
            if (![vcSeen containsObject:vcKey]){
                [vcSeen addObject:vcKey];
                ADLog(@"screen: %@ modal=%d", vcKey,
                      self.presentingViewController ? 1 : 0);
            }
            // Presented sheets that are SwiftUI-hosted or pharmacy/health-named:
            // flip the trait to dark. If that surface honours system appearance
            // (SwiftUI does by default), Amazon's OWN dark palette takes over --
            // which no amount of external repainting has managed to reach.
            @try {
                const char *cn3 = object_getClassName(self);
                BOOL sheet = (self.presentingViewController != nil);
                // Widened from the census. The previous test wanted "Hosting" and
                // matched none of the real names -- RCTModalHostViewController has
                // "Host" without the "ing", which is why traitdark never fired.
                // Narrowed after black-screen reports: a bare "Host" match also
                // caught RCTModalHostViewController, and forcing a dark trait on
                // a React Native modal can blank it. Only the store-mode classes
                // the census actually named are eligible now.
                BOOL hostish = (strstr(cn3, "StoreMode") != NULL ||
                                strstr(cn3, "AMIConfigurable") != NULL);
                if (sheet && hostish &&
                    [self respondsToSelector:@selector(setOverrideUserInterfaceStyle:)] &&
                    self.overrideUserInterfaceStyle != UIUserInterfaceStyleDark){
                    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
                    ADLog(@"traitdark: %s", cn3);
                }
            } @catch(...) {}
            // Store-mode surfaces (Pharmacy lives here): drive the repair from the
            // controller when it APPEARS. The prewarmed AMIConfigurableWebView
            // exposes no URL, so the URL-change poll never interrogates it; this
            // path does not depend on a URL, a timer, or Amazon's own delegate.
            @try {
                const char *cn5 = object_getClassName(self);
                if (!gP.enabled) return;
                if (strstr(cn5, "StoreMode") || strstr(cn5, "AMIConfigurable")) {
                    ADLog(@"pharmhook %s matched", cn5);
                    // Native pass only for the store-mode root. The generic
                    // configurable webview also backs ad landing pages, and
                    // repainting those blanked them.
                    @try {
                        int nbg = 0;
                        if (strstr(cn5, "StoreMode"))
                            ADDarkenNativeTree(self.viewIfLoaded, 0, &nbg);
                        if (nbg) ADLog(@"pharmnative %s bg=%d", cn5, nbg);
                    } @catch(...) {}
                    __weak UIViewController *wvc = self;
                    for (NSNumber *d3 in @[@0.3, @1.2, @3.0]) {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                       (int64_t)(d3.doubleValue * NSEC_PER_SEC)),
                                       dispatch_get_main_queue(), ^{
                            @try {
                                UIViewController *v2 = wvc;
                                if (!v2) return;
                                NSMutableArray *found = [NSMutableArray array];
                                if (v2.viewIfLoaded) ADCollectWebViews(v2.viewIfLoaded, found, 0);
                                // Fall back to the whole window hierarchy: the store-mode
                                // sheet's view can report no window at this point, which is
                                // what silently blocked every previous attempt.
                                if (!found.count){
                                    for (UIWindow *w3 in [UIApplication sharedApplication].windows){
                                        if (w3 && !w3.hidden) ADCollectWebViews(w3, found, 0);
                                    }
                                }
                                int nbg2 = 0;
                                ADDarkenNativeTree(v2.viewIfLoaded, 0, &nbg2);
                                if (!found.count) {
                                    ADLog(@"pharmrepair %s -> no webview (native bg=%d)", cn5, nbg2);
                                    return;
                                }
                                ADLog(@"pharmforce %s webviews=%lu", cn5, (unsigned long)found.count);
                                int widx = 0;
                                NSString *force = ADPharmForceJS();
                                for (WKWebView *w2 in found) {
                                    int myIdx = widx++;
                                    [w2 evaluateJavaScript:force completionHandler:^(id rf, NSError *ef){
                                        @try {
                                            if (ef) ADLog(@"pharmforce #%d -> ERR %@/%ld", myIdx, ef.domain, (long)ef.code);
                                            else ADLog(@"pharmforce #%d -> %@", myIdx, rf);
                                        } @catch(...) {}
                                    }];
                                    [w2 evaluateJavaScript:ADDarkReaderBootstrap()
                                         completionHandler:^(id r7, NSError *e7){
                                        @try {
                                            if (e7) ADLog(@"pharmboot #%d -> ERR %@/%ld",
                                                          myIdx, e7.domain, (long)e7.code);
                                            else ADLog(@"pharmboot #%d -> %@", myIdx, r7);
                                        } @catch(...) {}
                                    }];
                                }
                            } @catch(...) {}
                        });
                    }
                }
            } @catch(...) {}
            gProbeArmed = YES;
            @try {
                if (gP.enabled){
                    ADClaimStatusBarFor(object_getClass(self));
                    // Children decide as often as containers do on RN screens.
                    for (UIViewController *ch in self.childViewControllers)
                        ADClaimStatusBarFor(object_getClass(ch));
                    if (gSBLogLeft > 0){ gSBLogLeft--;
                        ADLog(@"statusbar: vc=%s appStyle=%ld",
                              object_getClassName(self),
                              (long)[UIApplication sharedApplication].statusBarStyle); }
                }
            } @catch(...) {}
            ADReapplyBurst(self);
            // Focused probe after the burst settles. The recursive native offender
            // scanner is intentionally not automatic anymore; it was expensive debug debt.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1750*1000000LL),
                dispatch_get_main_queue(), ^{ ADFocusedProbe363(); });
        }
    } @catch(...) {}
}
- (UIStatusBarStyle)preferredStatusBarStyle {
    if (gP.enabled) return UIStatusBarStyleLightContent;
    return %orig;
}
%end

// React Native's StatusBar module sets the style through the legacy
// UIApplication API, which never consults any view controller. Force it light.
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
    // Report the engine state AFTER prefs load -- reading gP in the ctor gives a
    // zero-initialised struct, which is what made the first reading meaningless.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        ADLog(@"engine enabled=%d nativeRecolor=%d webDarkReader=%d recolorOn=%d",
              gP.enabled ? 1 : 0, gP.nativeRecolor ? 1 : 0,
              gP.webDarkReader ? 1 : 0, ADRecolorOn() ? 1 : 0);
    });
    @try {
        // 20ms cadence: the launch window appears somewhere in the first second and
        // must be darkened within the same frame it becomes visible, before the
        // system captures its snapshot.
        // Disabled: it repaints the real UI just after the stock logo shows,
        // which reads as an inverted flash. Dark launch is the cover's job.
        if (0) dispatch_async(dispatch_get_main_queue(), ^{
            ADLaunchScreenDarkPass();
            __block NSTimer *lt2 = [NSTimer scheduledTimerWithTimeInterval:0.02 repeats:YES
                                                                     block:^(NSTimer *t){
                @try {
                    ADLaunchScreenDarkPass();
                    if (ADUptime() > 4.0) [t invalidate];
                } @catch(...) { [t invalidate]; }
            }];
            (void)lt2;
        });
    } @catch(...) {}
    // Drop the cached (light) launch snapshots so the system recaptures a dark
    // one from our darkened launch views. Own-container only; no entitlements.
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
    // Activation fallback for the ready signal: if no webview attaches (native-
    // only cold path), the cover still lifts shortly after the app is active.
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
        ADLockDarkWeblab();
        ADForceAppearanceDark();
        ADForceWindowsDarkTrait();
        ADInjectAllWebViews();
        ADSweepAllWindows();
    });
    // v5.363: bounded startup backstops. Assignment hooks + documentStart injection
    // own the steady state; nine escalating sweeps plus a second 40s timer were
    // duplicate work and could starve Home's own renderer.
    for (NSNumber *dn in @[@0.25,@1.50]){
        double d=dn.doubleValue;
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

    // ADStartTimer intentionally not started: the bounded startup passes above and
    // event-driven navigation/assignment hooks now provide coverage without a 40s
    // main-thread sweep train.
}

#pragma clang diagnostic pop
