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
#define AD_VERSION "v5.256.0"

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
    ADLog(@"prefs: enabled=%d web=%d nativeTheme=%d nativeRecolor=%d bright=%ld contrast=%ld gray=%ld sepia=%ld bg=%s fg=%s",
          gP.enabled, gP.webDarkReader, gP.nativeTheme, gP.nativeRecolor,
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
             "{background-color:#181a1b !important;border-radius:50%% !important;"
             "border:1.5px solid rgba(255,255,255,0.65) !important;"
             "box-shadow:none !important;box-sizing:border-box !important;}"
             "[class*=puis-heart-position]"
             "{background-color:transparent !important;border:0 !important;"
             "box-shadow:none !important;}"
             "[class*=mlt-icon-container]"
             "{background-color:#181a1b !important;border-radius:50%% !important;"
             "border:1.5px solid rgba(255,255,255,0.65) !important;"
             "box-shadow:none !important;box-sizing:border-box !important;}"
             "[class*=mlt-icon-container] img[class*=s-image],"
             "[class*=mlt-image-icon] img[class*=s-image]"
             "{filter:brightness(0) invert(1) !important;"
             "background-color:transparent !important;}"
             "[class*=mlt-icon-container] *,[class*=mlt-text-icon]"
             "{color:#ffffff !important;fill:#ffffff !important;}"
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
             "[class*=puis-heart-position] [class*=placehold],[class*=heart-placeholder]"
             "{display:none !important;}"
             // PHOTO SHIELD. Merchandise imagery must never carry a silhouette
             // filter, whatever rule above tried to apply one. Element selectors
             // are included deliberately to raise specificity over the
             // attribute-only rules that were matching these thumbnails.
             // AD-CARD TEXT. Scoped to containers a pass has confirmed carry
             // creative artwork -- never a container family, which covered the
             // entire feed. Once the marker is set, every caption inside is
             // pinned by CSS with no per-element work and no timing race.
             "html body [data-adcrt] span,"
             "html body [data-adcrt] p,"
             "html body [data-adcrt] h1,"
             "html body [data-adcrt] h2,"
             "html body [data-adcrt] h3,"
             "html body [data-adcrt] a"
             "{color:#0f1111 !important;-webkit-text-fill-color:#0f1111 !important;}"
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
             "'[class*=copilot-compare]','[class*=copilot-compare] *'],"
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
         "try{if(document&&!document.getElementById('adcardfix')){"
           "var __acs=document.createElement('style');__acs.id='adcardfix';"
           "__acs.textContent='picture,[class*=image-container],[class*=thumbnail-conta],[class*=single-creative],[class*=s-image],[class*=unfill],[class*=placehold]{background-color:transparent !important;}[class*=s-image],[class*=s-product-image] img,img[class*=s-image]{object-fit:contain !important;}[class*=a-cardui],[class*=npack-asin-card],[class*=gwm-asin-tile],[class*=gwm-window-layout],[class*=window-container],[class*=gwm-dashboard-container],[class*=wd-backdrop],[class*=theming-card],[class*=a-unordered-list],[class*=mosaic-container],[class*=puis-card],[class*=gwm-tile],[class*=_container_]{border-color:#2f3133 !important;}[class*=deal],[class*=badge],[class*=prime],[class*=error],[class*=alert],[class*=warning],[aria-invalid=true]{border-color:initial !important;}[class*=a-button-primary],[class*=a-button-search],[class*=a-button-oneclick],[class*=a-button-buy],.a-button-inner,.a-button-text{border-color:transparent !important;}[class*=ape-placement],[class*=ape-wrapper],[data-cel-widget*=ape],[id*=ape_],[class*=ape-placement] *,[class*=ape-wrapper] *,[data-cel-widget*=ape] *,[id*=ape_] *{filter:none !important;mix-blend-mode:normal !important;isolation:auto !important;text-shadow:none !important;}[class*=ape-placement],[class*=ape-wrapper],[data-cel-widget*=ape],[id*=ape_]{background-color:initial !important;}[class*=ape-placement] img,[class*=ape-wrapper] img,[class*=ape-placement] svg,[class*=ape-wrapper] svg,[class*=ape-placement] picture,[class*=ape-wrapper] picture{filter:none !important;opacity:1 !important;}[class*=ape-placement] span,[class*=ape-placement] a,[class*=ape-placement] p,[class*=ape-placement] h1,[class*=ape-placement] h2,[class*=ape-placement] h3,[class*=ape-placement] h4,[class*=ape-wrapper] span,[class*=ape-wrapper] a,[class*=ape-wrapper] p,[class*=ape-wrapper] h1,[class*=ape-wrapper] h2,[class*=ape-wrapper] h3,[class*=ape-wrapper] h4,[class*=theming-card] span,[class*=theming-card] a,[class*=theming-card] p,[class*=theming-card] h1,[class*=theming-card] h2,[class*=theming-card] h3,[class*=theming-card] h4{background-color:transparent !important;}';"
           "(document.head||document.documentElement).appendChild(__acs);}}catch(e){}"
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
               "n.style.setProperty('background-color','#181a1b','important');}""n.__adBgBy='adpin1';"
             "if(n.querySelectorAll){var q=n.querySelectorAll('[class*=unfill],[class*=placehold]');"
               "for(var i=0;i<q.length;i++)q[i].style.setProperty('background-color','transparent','important');"
               "var q2=n.querySelectorAll('[class*=a-section]');"
               "for(var k2=0;k2<q2.length&&k2<200;k2++){var e2=q2[k2];"
                 "if(typeof onArt==='function'&&onArt(e2)){}else "
                 "if(e2.closest&&e2.closest('[class*=puis],[class*=s-result],[class*=s-card]')&&"
                   "!e2.closest('[class*=s-product-image],[class*=mlt-icon],[class*=puis-heart-position]')&&"
                   "!(e2.querySelector&&e2.querySelector("
                     "'[class*=mlt-icon],[class*=puis-heart-position],[class*=lists-framework-action]'))){"
                   "e2.style.setProperty('background-color','#181a1b','important');}}}""e2.__adBgBy='adpin2';"
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
         // MINIMAL AD-FRAME THEME. Exempting the frame made the card render stock
         // white, which proved the ad lives in a child frame but is not dark mode.
         // Dark Reader is still kept out of here -- its palette analysis is what
         // turns orange stars white and flips captions -- and this runs in its place.
         //
         // Three rules, and nothing else is touched:
         //   1. near-white backgrounds go dark; anything carrying a background-image
         //      is left alone so product art and sprite sheets survive
         //   2. leaf text that is near-BLACK AND near-NEUTRAL goes light. Saturation
         //      is the whole point: the blue "prime" wordmark and the red deal badge
         //      are coloured, so they keep their brand colour, while 4.9, 34 and the
         //      title are neutral and become readable
         //   3. img/svg/picture/video/canvas are never touched at all, which is what
         //      preserves the stars and the orange prime check
         "if(window.top!==window){try{"
           // Keep reporting alive: FIXCONTRAST is where the child-frame poster lives,
           // so a bare stub would make this frame invisible in the log.
           "window.__AMZDARK_FIXCONTRAST__=function(){"
             "try{if(window.__ADPOST__)window.__ADPOST__();}catch(e){}return -3;};"
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
           "window.__AMZDARK_ADTHEME__=function(){try{"
             "if(!document.body)return -1;"
             "if(!document.getElementById('adfrmin')){var st=document.createElement('style');"
               "st.id='adfrmin';st.textContent='html,body{background-color:#181a1b !important;}'"
                 // The blue box is a focus ring left behind after the Sponsored
                 // disclosure sheet closes -- the element keeps :focus, and WebKit
                 // paints the default highlight. Suppressed for tap targets only.
                 "+'*{-webkit-tap-highlight-color:transparent !important;}'"
                 "+'*:focus,*:focus-visible{outline:none !important;box-shadow:none !important;}';"
               "(document.head||document.documentElement).appendChild(st);}"
             "var E=document.querySelectorAll('*'),nb=0,nt=0,nbd=0;"
             "for(var i=0;i<E.length&&i<3000;i++){var e=E[i];var tg=e.tagName;"
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
               "if(!isArt9&&!chip9){"
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
               "if(ownTxt.trim()){"
                 "var fg=AF.p(cs.color);"
                 // 0.78, not 0.5. ADFRAME reported text=0 while a visibly dim label sat
                 // right there: the rule demanded near-BLACK ink, so a mid-grey
                 // secondary label ("Sponsored") never qualified. Saturation still does
                 // the real work -- blue prime and red badges stay untouched -- so
                 // raising the luminance ceiling only catches greys that should match
                 // the card's other text anyway.
                 "if(fg&&AF.l(fg)<0.78&&AF.s(fg)<0.12){"
               "e.style.setProperty('color','#e8e6e3','important');nt++;}}"
               "try{var BS=['Top','Right','Bottom','Left'];"
                 "for(var bi=0;bi<4;bi++){"
                   "var bw=parseFloat(cs['border'+BS[bi]+'Width'])||0;if(bw<0.5)continue;"
                   "var bsty=cs['border'+BS[bi]+'Style'];if(bsty==='none'||bsty==='hidden')continue;"
                   "var bcp=AF.p(cs['border'+BS[bi]+'Color']);"
                   "if(bcp&&bcp.a>0.3&&AF.l(bcp)>0.6&&AF.s(bcp)<0.12){"
                     "e.style.setProperty('border-'+BS[bi].toLowerCase()+'-color','#3b3c3e','important');nbd++;}}"
               "}catch(eb){}"
               "}"
             "window.__AD_ADTHEME__='bg='+nb+' text='+nt+' border='+nbd+' logo='+(window.__AD_ADLOGO__||0);return nb+nt+nbd;"
           "}catch(e){window.__AD_ADTHEME__='err '+e;return -1;}};"
           // Self-contained poster. The main one is defined at the END of the pass we
           // now return from early, so it would never exist in an ad frame -- which is
           // why ADTHEME never reached the log.
           "window.__ADFPOST__=function(){try{if(window.top===window)return;"
             "var f='ADFRAME '+(window.__AD_ADTHEME__||'pending');"
             "if(f!==window.__ADFLAST__){window.__ADFLAST__=f;"
               "window.top.postMessage({__adfr:1,"
                 "u:String(location.pathname||'/').slice(-20),r:f},'*');}"
           "}catch(e){}};"
           "try{window.__AMZDARK_ADTHEME__();window.__ADFPOST__();}catch(e){}"
           "try{var _at=null;new MutationObserver(function(){clearTimeout(_at);"
             "_at=setTimeout(function(){try{window.__AMZDARK_ADTHEME__();}catch(e){}},120);})"
             ".observe(document.documentElement,{childList:true,subtree:true});}catch(e){}"
           // 60 ticks, and re-run on load. The taller creative paints after the old
           // 10s window closed, so the theme had already stopped looking.
           "try{var _n=0,_iv=setInterval(function(){if(++_n>60){clearInterval(_iv);return;}"
             "try{window.__AMZDARK_ADTHEME__();window.__ADFPOST__();}catch(e){}},400);}catch(e){}"
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
           "var ADSEL='[class*=ape-placement],[class*=ape-wrapper],[data-cel-widget*=ape],[id*=ape_],[class*=theming-card],[class*=a-cardui-header]';"
           "function isAd(n){try{return n&&n.closest&&n.closest(ADSEL);}catch(e){return null;}}"
           "function adLum(c){try{var a=String(c||'').split('('),b=(a[1]||'').split(')')[0].split(',');"
             "if(b.length<3)return -1;var al=b.length>3?parseFloat(b[3]):1;if(!(al>0))return -1;"
             "return (0.2126*parseFloat(b[0])+0.7152*parseFloat(b[1])+0.0722*parseFloat(b[2]))/255;"
           "}catch(e){return -1;}}"
           "function adBgOf(e){var d=0;while(e&&d++<10){var L=adLum(getComputedStyle(e).backgroundColor);"
             "if(L>=0)return L;e=e.parentElement;}return -1;}"
           "function adFix(n){try{"
             "if(!n||n.nodeType!==1||n.childElementCount)return;"
             "var t=String(n.textContent||'').trim();if(t.length<2)return;"
             "var cs=getComputedStyle(n);"
             "var own=adLum(cs.backgroundColor),par=adBgOf(n.parentElement);"
             "if(own>=0&&par>=0&&own<0.25&&par>0.5){"
               "n.style.setProperty('background-color','transparent','important');}"
             "var tl=adLum(cs.color),bl=adBgOf(n);"
             "if(tl<0||bl<0)return;"
             "if(Math.abs(tl-bl)>=0.32)return;"
             "n.__adCn=(n.__adCn||0)+1;if(n.__adCn>12)return;"
             "var ink=(bl>0.5)?'#0f1111':'#e8e6e3';"
             "n.style.setProperty('color',ink,'important');"
             "n.style.setProperty('-webkit-text-fill-color',ink,'important');"
           "}catch(e){}}"
           "function strip(n){try{"
             "adFix(n);"
             "if(!n||n.nodeType!==1)return;"
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
             "for(var i=0;i<ads.length&&i<40;i++){strip(ads[i]);"
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
                 "var d=ev.data;if(!d||typeof d!=='object'||d.__adfr!==1)return;"
                 "var k=String(d.u||'?').slice(0,22);"
                 "if(!window.__AD_FRAMES__)window.__AD_FRAMES__={};"
                 "var kn=0;for(var kk in window.__AD_FRAMES__)kn++;"
                 // Prefer frames that actually found something. A feed page can host a
                 // dozen ad iframes and the first six were winning the slots on
                 // arrival order alone -- the same document-order bias that ate four
                 // probe budgets.
                 "var interesting=/STAR |stars=[1-9]/.test(String(d.r||''));"
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
             "el0.__adCardQ=r0;if(r0)window.__AD_CARDBLK__=(window.__AD_CARDBLK__||0)+1;"
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
           "try{if(window.__ADTAME_ON__){"
             "var cL=Math.max(0.12,Math.min(0.95,1-0.85*(window.__ADTAME_S__||45)/100));"
             // Repair pass for anything a previous build left pointing at the
             // SVG def; those elements are invisible until the style is replaced.
             "try{var OLD=document.querySelectorAll('[style*=adtamef]');"
             "__ck('OLD');"
               "for(var o9=0;o9<OLD.length&&o9<300&&((o9&15)||!ovr());o9++){"
                 "OLD[o9].style.removeProperty('filter');OLD[o9].__adTamed=0;}"
               "var hostOld=document.getElementById('adtamef-host');"
               "if(hostOld&&hostOld.parentNode)hostOld.parentNode.removeChild(hostOld);"
             "}catch(e){}"
             "var PI0=document.querySelectorAll('img'),PI=[];"
               "for(var z8=0;z8<PI0.length&&z8<300;z8++)PI.push(PI0[z8]);"
               // cards that paint their picture as a CSS background
               "var PB=document.querySelectorAll('div,span,a,section,li');"
               "__ck('PB');"
               "for(var z9=0;z9<PB.length&&z9<1500&&((z9&15)||!ovr())&&PI.length<420;z9++){"
                 "var be9=PB[z9];"
                 "if((getComputedStyle(be9).backgroundImage||'').indexOf('url(')<0)continue;"
                 "PI.push(be9);}"
             "var tamed=0;"
             "for(var pi=0;pi<PI.length&&pi<420&&((pi&15)||!ovr());pi++){var im7=PI[pi];"
               "if(im7.__adTamed)continue;"
               "var ir7=im7.getBoundingClientRect();"
               // product imagery only: big enough to be a photo, and never a glyph
               // 56px: below this it is chrome, not a picture. The ad-card
               // thumbnails that went untreated sit between 56 and 90.
               "if(ir7.width<56||ir7.height<56)continue;"
               "if(im7.__adGlyph)continue;"
               "var icn7=im7.className;if(icn7&&icn7.baseVal!==undefined)icn7=icn7.baseVal;"
               "if(/sprite|icon|logo|pixel/i.test(String(icn7||'')))continue;"
               // Self-contained filter functions only: nothing to dereference, so
               // nothing can fail to resolve and blank the element.
               "var bb9=(1-0.50*((window.__ADTAME_S__||45)/100)).toFixed(3);"
               "im7.style.setProperty('filter','brightness('+bb9+') saturate(1.08)','important');"
               "im7.__adTamed=1;tamed++;}"
             "if(tamed&&!window.__AD_TAME__)window.__AD_TAME__='n='+tamed+' ceil='+cL.toFixed(2);"
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
                      // ACTION-BUTTON DISC. Same look the CSS used to apply, but only for
           // elements that are genuinely icon-sized -- a row-sized container
           // carrying the same class is left alone.
           "try{var DB=document.querySelectorAll('[class*=lists-framework-action-button]');"
             "var ndisc=0,dskip=0;"
             "for(var db=0;db<DB.length&&db<80;db++){var de=DB[db];"
               "var dr=de.getBoundingClientRect();"
               "if(dr.width<18||dr.width>52||dr.height<18||dr.height>52){dskip++;continue;}"
               "if(Math.abs(dr.width-dr.height)>10){dskip++;continue;}"
               "de.style.setProperty('background-color','#181a1b','important');"
               "de.style.setProperty('border-radius','50%%','important');"
               "de.style.setProperty('border','1.5px solid rgba(255,255,255,0.65)','important');"
               "de.style.setProperty('box-shadow','none','important');"
               "de.style.setProperty('box-sizing','border-box','important');"
               "ndisc++;}"
             "if(ndisc||dskip)window.__AD_DISC__='on='+ndisc+' skipped='+dskip;"
           "}catch(e){}"
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
                      // COMPARE DISC BY POSITION. Name-based selection has missed in every
           // form, so use the layout invariant instead: the compare control is the
           // icon-sized overlay in the lower-left of the product image (the heart
           // owns the lower-right). Report what was found ONCE via CMPSCAN so the
           // real class can graduate into the stylesheet.
           "try{var IMGC=document.querySelectorAll('[class*=s-product-image]');"
           "__ck('IMGC');"
             "for(var ig=0;ig<IMGC.length&&ig<40&&((ig&15)||!ovr());ig++){var box=IMGC[ig];"
               "var br=box.getBoundingClientRect();"
               "if(br.width<80||br.height<80)continue;"
               "var alln=box.querySelectorAll('*');var tgt=null;"
               "for(var an=0;an<alln.length&&an<150&&((an&15)||!ovr());an++){var el2=alln[an];"
                 "var er=el2.getBoundingClientRect();"
                 "if(er.width<22||er.width>46||er.height<22||er.height>46)continue;"
                 "if(er.left-br.left>br.width*0.40)continue;"
                 "if(er.bottom<br.top+br.height*0.55)continue;"
                 "if(el2.closest&&el2.closest('[class*=heart],[class*=wish],[class*=lists-framework]'))continue;"
                 "var art=el2.querySelector('img,i,svg');"
                 "var ecs=getComputedStyle(el2);"
                 "var selfArt=(ecs.backgroundImage&&ecs.backgroundImage!=='none')"
                   "||((ecs.webkitMaskImage||ecs.maskImage||'none')!=='none');"
                 "if(!art&&!selfArt)continue;"
                 "tgt=el2;var artMode=art?'child':'self';"
                 "tgt.style.setProperty('background-color','#181a1b','important');"
                 "tgt.style.setProperty('border-radius','50%%','important');"
                 "tgt.style.setProperty('border','1.5px solid rgba(255,255,255,0.65)','important');"
                 "tgt.style.setProperty('box-shadow','none','important');"
                 "tgt.style.setProperty('box-sizing','border-box','important');"
                 "if(art){var arts=tgt.querySelectorAll('img,i,svg,use,span,div');"
                   "for(var av=0;av<arts.length&&av<12&&((av&15)||!ovr());av++){"
                     // NOT artChk here. The parent has ALREADY been positively
                     // identified as a circular control -- we just gave it a dark
                     // fill and a white border -- so its children are that control's
                     // glyph by construction. closest(PRODC) is meaningless at this
                     // site because the control is OVERLAID on the product image, so
                     // it inherits [data-component-type=s-search-result] and every
                     // glyph reads as product art. A size test keeps the property
                     // that matters (never silhouette anything photo-sized) without
                     // that false positive.
                     "var ar9=arts[av].getBoundingClientRect();"
                     "if(ar9.width>48||ar9.height>48||ar9.width<6||ar9.height<6)continue;"
                     "var cs9=getComputedStyle(arts[av]),tg9=arts[av].tagName;"
                     "if(!(tg9==='IMG'||tg9==='SVG'||tg9==='svg'||tg9==='I'||tg9==='USE'"
                       "||String(cs9.backgroundImage||'').indexOf('url(')>=0"
                       "||String(cs9.maskImage||cs9.webkitMaskImage||'').indexOf('url(')>=0))continue;"
                     "arts[av].style.setProperty('filter','brightness(0) invert(1)','important');"
                     "arts[av].style.setProperty('background-color','transparent','important');"
                     "arts[av].__adGlyph=1;arts[av].__adBy='compdisc';}}"
                 // sprite drawn by the element's own background: silhouette via a
                 // pseudo cannot be set inline, so lift the artwork with invert and
                 // let the pinned dark bg/border above stay (they are bg-COLOR and
                 // border, unaffected by filter stacking order on the same element
                 // is fine: filter applies to the whole element render, so instead
                 // skip filter here and rely on mask colouring below).
                 "if(!art&&selfArt&&(ecs.webkitMaskImage||ecs.maskImage||'none')!=='none'){"
                   "tgt.style.setProperty('background-color','#e8e6e3','important');}"
                 "var pe2=tgt.parentElement,pd2=0;"
                 "while(pe2&&pd2++<2){var pr2=pe2.getBoundingClientRect();"
                   "if(pr2.width<=64&&pr2.height<=64){"
                     "pe2.style.setProperty('background-color','transparent','important');"
                     "pe2.style.setProperty('box-shadow','none','important');}"
                   "pe2=pe2.parentElement;}"
                 "if(!window.__AD_CMPSCAN__){var pcl2=tgt.parentElement?String(tgt.parentElement.className&&tgt.parentElement.className.baseVal!==undefined?tgt.parentElement.className.baseVal:tgt.parentElement.className||''):'-';"
                   "var scl2=String(tgt.className&&tgt.className.baseVal!==undefined?tgt.className.baseVal:tgt.className||'');"
                   "window.__AD_CMPSCAN__='self='+scl2.slice(0,36)+' par='+pcl2.slice(0,36)+' art='+artMode;}"
                 "break;}}"
           "}catch(e){}"
                      // COMPARE DISC BY GEOMETRY. The heart is right; the compare button is
           // the same widget under a different name per layout. Find it the way the
           // probe does, verify it is icon-sized inside a product card, apply the
           // exact heart look inline, and report the class ONCE so the stylesheet
           // can be pinned to the real selector next round.
           "try{var CF=document.querySelectorAll("
             "'[aria-label*=ompare],[class*=compare],[data-csa-c-content-id*=ompare]');"
             "for(var cf=0;cf<CF.length&&cf<80&&((cf&15)||!ovr());cf++){var ce=CF[cf];"
               "var cr2=ce.getBoundingClientRect();"
               "if(cr2.width<22||cr2.width>46||cr2.height<22||cr2.height>46)continue;"
               "if(!(ce.closest&&ce.closest('[class*=s-product-image],[class*=puisg-col]')))continue;"
               "var ccl=ce.className;if(ccl&&ccl.baseVal!==undefined)ccl=ccl.baseVal;ccl=String(ccl||'');"
               "if(/tray|heart|wish|lists-framework/i.test(ccl))continue;"
               "ce.style.setProperty('background-color','#181a1b','important');"
               "ce.style.setProperty('border-radius','50%%','important');"
               "ce.style.setProperty('border','1.5px solid rgba(255,255,255,0.65)','important');"
               "ce.style.setProperty('box-shadow','none','important');"
               "ce.style.setProperty('box-sizing','border-box','important');"
               "var cg=ce.querySelectorAll('img,i,svg,use,span,div');"
               "for(var cg2=0;cg2<cg.length&&cg2<12&&((cg2&15)||!ovr());cg2++){"
                 // Same reasoning as the compare disc above: the parent is an
                 // identified control, so size is the right test, not provenance.
                 "var cr9=cg[cg2].getBoundingClientRect();"
                 "if(cr9.width>48||cr9.height>48||cr9.width<6||cr9.height<6)continue;"
                 "var cs9=getComputedStyle(cg[cg2]),tg9=cg[cg2].tagName;"
                 "if(!(tg9==='IMG'||tg9==='SVG'||tg9==='svg'||tg9==='I'||tg9==='USE'"
                   "||String(cs9.backgroundImage||'').indexOf('url(')>=0"
                   "||String(cs9.maskImage||cs9.webkitMaskImage||'').indexOf('url(')>=0))continue;"
                 "cg[cg2].style.setProperty('filter','brightness(0) invert(1)','important');"
                 "cg[cg2].style.setProperty('background-color','transparent','important');"
                 "cg[cg2].__adGlyph=1;cg[cg2].__adBy='heartdisc';}"
               "if(!window.__AD_CMPFIX__){window.__AD_CMPFIX__="
                 "'cls='+ccl.slice(0,40)+' aria='+String(ce.getAttribute('aria-label')||'-').slice(0,24)"
                 "+' csa='+String(ce.getAttribute('data-csa-c-content-id')||'-').slice(0,24);}}"
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
           // MLT ICON CONTAINERS. A 32px circular icon container whose glyph nothing
           // claims -- the probe reported by=- on every one of them, so it renders
           // dark on a dark disc. The CSS rule that should cover it carries a
           // CSS rule at line 367 only matches img[class*=s-image] -- and the probe
           // shows the child sitting there is grey-pixel.gif at nat=1x1, a lazy
           // placeholder, so at the moment the sheet applies there is nothing real to
           // filter and the swapped-in glyph is never revisited. Doing it in JS
           // instead of widening the selector, because a stylesheet
           // cannot measure anything and size is the only safe discriminator:
           // the container must be icon-sized, and any child with a large source
           // bitmap is a photo and is left alone.
           "try{var MIC=document.querySelectorAll('[class*=mlt-icon-container]');"
             "for(var mi=0;mi<MIC.length&&mi<60&&((mi&15)||!ovr());mi++){"
               "var mc=MIC[mi];var mr=mc.getBoundingClientRect();"
               "if(mr.width<16||mr.width>64||mr.height<16||mr.height>64)continue;"
               "var gl=mc.querySelectorAll('img,svg,i,use,span,div');"
               "for(var gi2=0;gi2<gl.length&&gi2<8;gi2++){var ge=gl[gi2];"
                 "if(ge.__adGlyph)continue;"
                 "var gr=ge.getBoundingClientRect();"
                 "if(gr.width>48||gr.height>48||gr.width<6||gr.height<6)continue;"
                 "if((ge.naturalWidth||0)>96||(ge.naturalHeight||0)>96)continue;"
                 "var gc=getComputedStyle(ge),gt=ge.tagName;"
                 "if(!(gt==='IMG'||gt==='svg'||gt==='SVG'||gt==='I'||gt==='USE'"
                   "||String(gc.backgroundImage||'').indexOf('url(')>=0"
                   "||String(gc.maskImage||gc.webkitMaskImage||'').indexOf('url(')>=0))continue;"
                 "ge.style.setProperty('filter','brightness(0) invert(1)','important');"
                 "ge.style.setProperty('background-color','transparent','important');"
                 "ge.__adGlyph=1;ge.__adBy='mlticon';"
                 "window.__AD_MLT__=(window.__AD_MLT__||0)+1;}}"
           "}catch(e){window.__AD_MLT__='err '+e;}"
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
           "return n+'/'+bfix+'/'+lfix+'/'+gfix+'/'+bigfix+pr;}catch(e){return -1;}};"
         "window.__AMZDARK_APPLY__=function(){try{"
           "if(!document.querySelector('style.darkreader'))DarkReader.enable(%@,%@);"
           "window.__AMZDARK_FIXCONTRAST__();"
         "}catch(e){}};"
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
         "try{var _t=null,_last=0;new MutationObserver(function(muts){"
           // synchronous fast lane: pin stock colour before this frame paints
           "try{for(var m2=0;m2<muts.length&&m2<40;m2++){"
             "var ad=muts[m2].addedNodes;"
             "for(var a2=0;a2<ad.length&&a2<20;a2++)_adPin(ad[a2]);}}catch(e){}"
           "var _n=Date.now();"
           "if(_n-_last>110){_last=_n;"
             "if(window.requestAnimationFrame)requestAnimationFrame(function(){"
               "try{window.__AMZDARK_FIXCONTRAST__();}catch(e){}});"
             "else{try{window.__AMZDARK_FIXCONTRAST__();}catch(e){}}}"
           "clearTimeout(_t);"
           "_t=setTimeout(function(){_last=Date.now();"
             "try{window.__AMZDARK_FIXCONTRAST__();}catch(e){}},400);})"
           ".observe(document.documentElement,{childList:true,subtree:true});}catch(e){}"
           // Heartbeat: cheap, idempotent, and the only thing that survives a
           // late re-mount of an already-processed subtree.
           "try{if(!window.__AMZDARK_HB__){window.__AMZDARK_HB__=1;var hbn=0;"
             "var hb=setInterval(function(){try{"
               "if(++hbn>75){clearInterval(hb);return;}"
               "window.__AMZDARK_FIXCONTRAST__();"
             "}catch(e){}},1200);}}catch(e){}"
         "window.__AMZDARK_APPLY__();"
         // Fast early passes so promo text / buttons are corrected before the
         // eye registers Dark Reader's first-paint colours. One-shot, bounded.
         "try{[30,90,180,320,600].forEach(function(t){setTimeout(function(){"
           "try{window.__AMZDARK_FIXCONTRAST__();}catch(e){}},t);});}catch(e){}"
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
        // Measured lift for small monochrome assets on a dark ground -- the
        // Interests plus glyph is one of these, and it is native, so no web
        // pass could ever have reached it. Photographs fail the alpha test.
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
        if (v && !ADInTabBarChain(v) && !ADIsChromeGlyphContext(v)){
            CGFloat w = v.bounds.size.width, h = v.bounds.size.height;
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
    // A remotely fetched glyph arrives here, often well after didMoveToWindow.
    // Measure from the arrival so the dark original is never shown and then
    // corrected -- that correction is what reads as a colour flip.
    @try {
        if (gP.enabled && !gADGlyphWriting) {
            __weak UIImageView *wArr = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                @try { UIImageView *v3 = wArr; if (v3 && v3.window) ADScheduleGlyphLift(v3); }
                @catch(...) {}
            });
        }
    } @catch(...) {}
    // Detached: nothing to walk yet. Defer to didMoveToWindow, where ancestry -- and
    // therefore the tab-bar test -- is knowable.
    if (!self.superview && !self.window) {
        %orig;
        return;
    }
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
            return;
        }
    } @catch(...) {}
    %orig;
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
    if (++gSweepNodes > 3000){ gSweepCut++; return; }
    if ((gSweepNodes & 63) == 0 && CFAbsoluteTimeGetCurrent() > gSweepDeadline){
        gSweepCut++; return;
    }
    @try {
        if (ADIsWebKitOwned(v)) return;                 // Dark Reader's territory
        ADInvertRNSVG(v);                               // Alexa panel vector icons
        ADLaunchWhiteGuard(v);                          // launch-window white killer
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
        gSweepDeadline = t0 + 0.008;                 // 8ms, half a frame
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
       "if(window.top!==window.self)return '';"
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
       "try{var R=[],EL=document.querySelectorAll('*');"
         "for(var q=0;q<EL.length&&R.length<8;q++){var e=EL[q];"
           "var t=String(e.textContent||'').trim();"
           "var r=e.getBoundingClientRect();if(r.width<8||r.height<6)continue;"
           "if(r.bottom<0||r.top>(window.innerHeight||900))continue;"
           "var st=getComputedStyle(e);"
           "if(t.length<3||t.length>40)continue;var bl=lum(st.backgroundColor);if(bl<0||bl>0.25)continue;if(!e.closest||!e.closest('[class*=ape],[class*=theming-card],[class*=gwm],[class*=creative]'))continue;"
           "var ch=[],n=e,d=0;while(n&&d<4){ch.push((cls(n)||n.tagName).slice(0,20));n=n.parentElement;d++;}"
           "R.push(t.slice(0,14)+'|'+e.tagName+'|'+Math.round(r.width)+'x'+Math.round(r.height)"
             "+'|bg='+st.backgroundColor+'|col='+st.color+'|L='+lum(st.backgroundColor).toFixed(2)+'|'+ch.join('>'));}"
         "out.push('P9CAROBOX['+(R.length?R.join(' ~ '):'none')+']');}catch(x){out.push('P9CAROBOX[err]');}"
       "try{var R=[],EL=document.querySelectorAll('*');"
         "for(var q=0;q<EL.length&&R.length<8;q++){var e=EL[q];"
           "var t=String(e.textContent||'').trim();"
           "var r=e.getBoundingClientRect();if(r.width<8||r.height<6)continue;"
           "if(r.bottom<0||r.top>(window.innerHeight||900))continue;"
           "var st=getComputedStyle(e);"
           "if(t.indexOf('%')<0||t.length>14)continue;if(e.childElementCount>2)continue;"
           "var ch=[],n=e,d=0;while(n&&d<4){ch.push((cls(n)||n.tagName).slice(0,20));n=n.parentElement;d++;}"
           "R.push(t.slice(0,14)+'|'+e.tagName+'|'+Math.round(r.width)+'x'+Math.round(r.height)"
             "+'|bg='+st.backgroundColor+'|col='+st.color+'|'+ch.join('>'));}"
         "out.push('P9PCT['+(R.length?R.join(' ~ '):'none')+']');}catch(x){out.push('P9PCT[err]');}"
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
         "out.push('P9DOLLAR['+(R.length?R.join(' ~ '):'none')+']');}catch(x){out.push('P9DOLLAR[err]');}"
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
         "out.push('P9SPON['+(R.length?R.join(' ~ '):'none')+']');}catch(x){out.push('P9SPON[err]');}"
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
         "if(fk.length){var fo=[];for(var fx=0;fx<fk.length&&fx<4;fx++)fo.push(fk[fx]+'=>'+String(FR[fk[fx]]).slice(0,80));"
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
        static NSString *last = nil;
        NSString *now = [NSString stringWithFormat:
                         @"win=%d views=%d img=%d tmpl=%d tintFixed=%d glyphFixed=%d darkLabels=%d labelFixed=%d%s%s%s%s",
                         nwin, gSwViews, gSwImgSeen, gSwTemplateSeen, gSwTintFixed,
                         gSwGlyphFixed, gSwDarkLabels, gSwLabelFixed,
                         gSwSample[0]  ? " declined=" : "", gSwSample[0]  ? gSwSample  : "",
                         gSwTintNow[0] ? " tintNow="  : "", gSwTintNow[0] ? gSwTintNow : ""];
        if (!last || ![last isEqualToString:now]){ last = now; ADLog(@"sweep %@", now); }
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
static void ADReapplyBurst(void){
    static const int64_t delays_ms[] = {0, 60, 200, 500};
    for (int i = 0; i < 4; i++){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delays_ms[i]*1000000LL),
            dispatch_get_main_queue(), ^{ @try {
                ADForceWindowsDarkTrait();
                ADInjectAllWebViews();
                ADSweepAllWindows();
            } @catch(...) {} });
    }
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
    @try {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ ADPlusProbe(); });
    } @catch(...) {}
    @try {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ ADLayerDump(); });
    } @catch(...) {}
    @try {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ ADWebViewCensus(); });
    } @catch(...) {}
    // 1.6s: long enough for the feed's lazy cards to render.
    @try {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ ADTextClassProbe(); });
    } @catch(...) {}
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
            ADReapplyBurst();
            // Probe after the burst has settled, so we only report genuine hold-outs.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 900*1000000LL),
                dispatch_get_main_queue(), ^{ ADRunProbe(); });
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
    // Escalating sweeps to catch late-initialised services/web views (0.2s..~10s).
    for (double d = 0.2; d <= 10.0; d *= 1.6){
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

    ADStartTimer();
}

#pragma clang diagnostic pop
