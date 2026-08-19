/*
 * AmazonDark v4.0.0  —  "True Dark" rewrite
 * ============================================================================
 * Target: Amazon Shopping iOS app (com.amazon.Amazon), v27.x, Dopamine rootless,
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
 * ROOTLESS SAFETY (preserved from the known-good runtime design)
 * ----------------------------------------------------------------------------
 *  - Keep constructor work bounded and defer normal setup onto the main queue.
 *  - All recurring recovery is event-driven or strictly bounded; no forever timer.
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
#import <dlfcn.h>
#import <sys/types.h>
#import <unistd.h>
#import <stdint.h>
#import <errno.h>
// Keep in lockstep with layout/DEBIAN/control.
#define AD_VERSION "v6.0.139"

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

@interface ANXTopNavBackgroundView : UIView @end

@interface AXUSplashScreenViewController : UIViewController @end
@interface TezBaseSplashScreenViewController : UIViewController @end
@interface WKScrollView : UIScrollView @end
@interface WKContentView : UIView @end
@interface RNSVGSvgView : UIView @end

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
    BOOL  enableJIT;          // Dopamine per-app JIT
    long  whiteTameStrength;  // v5.446: 0-100 tame strength
    long  brightness;         // Dark Reader 0..100+ (default 100)
    long  contrast;           // Dark Reader 0..100+ (default 100)
    long  sepia;              // Dark Reader 0..100  (default 0)
    long  grayscale;          // Dark Reader 0..100  (default 0)
    char  bgHex[8];           // dark scheme background, "#RRGGBB"
    char  fgHex[8];           // dark scheme text,       "#RRGGBB"
} ADPrefs;

static ADPrefs gP;
// v6.0.13 hot constants: these colors are requested from layout hooks constantly.
// Reuse one marked-own UIColor per live preference value instead of allocating a
// fresh UIColor + associated-object marker on every assignment.
static UIColor *gADBGColor613 = nil;
static UIColor *gADFGColor613 = nil;
static UIColor *gADBlueColor613 = nil;
static void ADSyncColorEngine(void);
static const void *kADModImageKey = &kADModImageKey;
static inline BOOL ADIsModifiedImage(UIImage *im){ return im && objc_getAssociatedObject(im, kADModImageKey) != nil; }
static inline void ADMarkModifiedImage(UIImage *im){ if (im) objc_setAssociatedObject(im, kADModImageKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static UIColor *ADColorFromHex(const char *hex);
static UIImage *ADGlyphify(UIImage *img);
static UIImage *ADGlyphifyForView(UIImage *img, UIView *v);
static void ADScheduleGlyphLift624(UIImageView *iv);
static void ADApplyNativeWhiteTameView(UIView *v);
static BOOL ADImageMostlyLight(UIImage *img);
static BOOL ADIsCategoryArtwork379(UIView *v);
static void ADRestoreCategoryArtwork379(UIImageView *iv);
static BOOL ADIsHamburgerSurface380(UIView *v);
static int ADMenuRole382(UIView *v);
static BOOL ADWTInWatchedCarousel380(UIView *v);
static inline double ADUptime(void);
static void ADPostAppReady(void);
static void ADPreDarken(WKWebView *wv);
static void ADPrimeWebBacking611(WKWebView *wv);
static void ADInvalidateWebCaches613(void);

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
    gP.enableJIT = NO;
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
        gP.enableJIT          = ADPrefBool(d, @"enableJIT",          gP.enableJIT);
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
    gADBGColor613 = nil;
    gADFGColor613 = nil;
    ADInvalidateWebCaches613();
    ADSyncColorEngine();
}

// ── DOPAMINE PER-APP JIT (v6.0.22) ──────────────────────────────────────────
// Production path: JIT is launch-time only. Settings changes already use the
// tweak's normal respring workflow, so there is no live CS_DEBUGGED revocation.
// Amazon asks the existing SpringBoard component to make one platform-authorized
// Dopamine request for Amazon's own PID, then verifies raw kernel CS_DEBUGGED.
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
#define AD_JIT_RC_NO_BACKEND_622 (-1001)
#define AD_JIT_RC_EXCEPTION_622  (-1002)
#define AD_JIT_RC_BAD_PID_622    (-1003)

typedef struct {
    uint32_t flags;
    int err;
    BOOL debugged;
} ADJITState622;

static ADJITState622 ADReadJITState622(void){
    ADJITState622 st = {0, 0, NO};
    errno = 0;
    long rc = syscall(SYS_csops, getpid(), CS_OPS_STATUS, &st.flags, sizeof(st.flags));
    st.err = (rc == 0 ? 0 : errno);
    st.debugged = (rc == 0 && (st.flags & CS_DEBUGGED) != 0);
    return st;
}

// 64-bit Darwin-notify state: pid[63:32], nonce[31:16], signed rc[15:0].
static uint64_t ADJITWireState622(pid_t pid, uint16_t nonce, int rc){
    return (((uint64_t)(uint32_t)pid) << 32) |
           (((uint64_t)nonce) << 16) |
           ((uint16_t)(int16_t)rc);
}
static pid_t ADJITWirePID622(uint64_t state){ return (pid_t)(uint32_t)(state >> 32); }
static uint16_t ADJITWireNonce622(uint64_t state){ return (uint16_t)((state >> 16) & 0xffffU); }
static int ADJITWireRC622(uint64_t state){ return (int)(int16_t)(state & 0xffffU); }

static uint16_t ADNextJITNonce622(void){
    static volatile uint32_t seq = 0;
    uint16_t n = (uint16_t)__sync_add_and_fetch(&seq, 1);
    return n ? n : 1;
}

static BOOL ADSendJITBrokerRequest622(int *brokerRCOut){
    int reqToken = 0, resToken = 0;
    BOOL got = NO;
    int rc = AD_JIT_RC_EXCEPTION_622;
    uint16_t nonce = ADNextJITNonce622();
    pid_t pid = getpid();

    if (notify_register_check(AD_JIT_RES_NOTIFY_622, &resToken) != NOTIFY_STATUS_OK) goto done;
    if (notify_register_check(AD_JIT_REQ_NOTIFY_622, &reqToken) != NOTIFY_STATUS_OK) goto done;
    if (notify_set_state(reqToken, ADJITWireState622(pid, nonce, 0)) != NOTIFY_STATUS_OK) goto done;
    if (notify_post(AD_JIT_REQ_NOTIFY_622) != NOTIFY_STATUS_OK) goto done;

    // Runs on a utility queue. Normal broker responses arrive almost immediately.
    for (int i = 0; i < 35; i++){
        uint64_t res = 0;
        if (notify_get_state(resToken, &res) == NOTIFY_STATUS_OK &&
            ADJITWirePID622(res) == pid && ADJITWireNonce622(res) == nonce){
            rc = ADJITWireRC622(res);
            got = YES;
            break;
        }
        usleep(10000);
    }

done:
    if (reqToken) notify_cancel(reqToken);
    if (resToken) notify_cancel(resToken);
    if (brokerRCOut) *brokerRCOut = rc;
    return got;
}

static void ADWriteJITReport622(NSString *status, BOOL responded, int backendRC,
                                ADJITState622 pre, ADJITState622 post){
    @try {
        NSString *p = [NSTemporaryDirectory() stringByAppendingPathComponent:@"AmazonDark-jit.txt"];
        NSString *s = [NSString stringWithFormat:
            @"AmazonDark %@\n"
             "enableJIT=%d\n"
             "status=%@\n"
             "backend=%@\n"
             "brokerResponded=%d\n"
             "backendRC=%d\n"
             "pid=%d\n"
             "preCsopsErr=%d\n"
             "preCsFlags=0x%08x\n"
             "preCS_DEBUGGED=%d\n"
             "postCsopsErr=%d\n"
             "postCsFlags=0x%08x\n"
             "postCS_DEBUGGED=%d\n"
             "amazonDarkTransitionedOn=%d\n",
             [NSString stringWithUTF8String:AD_VERSION], (gP.enabled && gP.enableJIT) ? 1 : 0,
             status ?: @"-",
             (gP.enabled && gP.enableJIT) ? @"SpringBoard-Dopamine-jbclient_platform_set_process_debugged" : @"none",
             responded ? 1 : 0, backendRC, getpid(),
             pre.err, pre.flags, pre.debugged ? 1 : 0,
             post.err, post.flags, post.debugged ? 1 : 0,
             (!pre.debugged && post.debugged && responded && backendRC == 0) ? 1 : 0];
        [s writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } @catch(...) {}
}

static void ADPerformJITRequest622(BOOL requestedOn){
    ADJITState622 pre = ADReadJITState622();

    // OFF is intentionally passive. The preference UI resprings, so a clean launch
    // simply makes no JIT request and starts without AmazonDark-owned CS_DEBUGGED.
    if (!requestedOn){
        ADWriteJITReport622(pre.debugged ? @"off-baseline-debugged" : @"off-clean",
                            NO, 0, pre, pre);
        return;
    }

    if (pre.debugged){
        ADWriteJITReport622(@"on-already-debugged", NO, 0, pre, pre);
        return;
    }

    int backendRC = AD_JIT_RC_EXCEPTION_622;
    BOOL responded = ADSendJITBrokerRequest622(&backendRC);
    ADJITState622 post = ADReadJITState622();
    NSString *status = @"on-failed-verification";

    if (!responded) status = @"on-broker-timeout";
    else if (backendRC == AD_JIT_RC_NO_BACKEND_622) status = @"broker-backend-unavailable";
    else if (backendRC == AD_JIT_RC_BAD_PID_622) status = @"broker-pid-rejected";
    else if (backendRC != 0) status = @"on-backend-error";
    else if (post.debugged) status = @"on-enabled-by-amazondark";

    ADWriteJITReport622(status, responded, backendRC, pre, post);
}

static void ADApplyJIT622(void){
    BOOL requestedOn = gP.enabled && gP.enableJIT;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool { ADPerformJITRequest622(requestedOn); }
    });
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
                    break;
                }
            }
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
// v6.0.13: all generated web payloads are immutable until preferences change.
// Dark Reader itself is ~346 KB; rebuilding the bootstrap with stringWithFormat on
// every navigation was pure allocation/copy churn. Cache each payload once per
// preference generation and drop it only when ADLoadPrefs() actually reloads.
static NSString *gADFixesLiteral613 = nil;
static NSString *gADThemeLiteral613 = nil;
static NSString *gADBootstrap613 = nil;
static NSString *gADReapply613 = nil;
static NSString *gADTameWeb613 = nil;
static void ADInvalidateWebCaches613(void){
    gADFixesLiteral613 = nil;
    gADThemeLiteral613 = nil;
    gADBootstrap613 = nil;
    gADReapply613 = nil;
    gADTameWeb613 = nil;
}

static NSString *ADFixesLiteral(void){
    if (gADFixesLiteral613) return gADFixesLiteral613;
    // The image backdrop is only meaningful where an image has TRANSPARENT pixels:
    // a dark panel behind an opaque JPEG is completely hidden by the photo. So this
    // helps transparent PNGs (icons, cut-out product shots) and is a harmless no-op
    // everywhere else. It cannot darken white that is baked into a JPEG's pixels -
    // that needs real pixel work, which is a separate decision.
    // v6.0.15 / v5.446 policy: backdrop is OPT-IN, never blanket.  A blanket
    // img{} fill is what painted rectangular dark boxes behind transparent ad logos.
    // Current 6.x does not need to mark web images proactively, so this remains a
    // zero-cost escape hatch for explicitly confirmed transparent artwork only.
    NSString *imgBackdrop = gP.imageBackdrop
        ? [NSString stringWithFormat:@"html body img[data-adbackdrop]{background-color:%s !important;}", gP.bgHex]
        : @"";
    gADFixesLiteral613 = [NSString stringWithFormat:
            @"{css:'"
             "img,picture,video,canvas,svg{filter:none !important;opacity:1 !important;"
             "mix-blend-mode:normal !important;isolation:auto !important;}"
             // v6.0.85: direct v5.446 Interests add-glyph owner. The blanket media
             // protection above freezes Amazon's dark add/plus bitmap unless this
             // higher-specificity rule re-enables the donor invert on that glyph only.
             "img[class*=add-icon],img[class*=plus-icon]{filter:invert(1) hue-rotate(180deg) !important;}"
             // v6.0.116: exact v5.446 Search/nav bitmap backdrop rule.
             // Search glyph hosts stay unpainted; only real IMG chrome is guaranteed
             // a transparent surround, while the donor generic glyph pass owns ink.
             "[class*=nav-search] img,[class*=searchbar] img,[class*=search-bar] img,"
             "[role=search] img,[class*=nav-] img[class*=icon],[class*=header] img[class*=icon]"
             "{background-color:transparent !important;}"
             // v6.0.138: keep Sponsored presentation stock-owned. Only the
             // text ink is bridged to Amazon/Dark Reader's dark-mode secondary gray;
             // glyph artwork, geometry, spacing and internal "i" remain untouched.
             "[class*=sponsored-label],[class*=ad-feedback-text],[id^=ad-feedback-text-],"
             "[id^=af-label-primary-link-],[data-ad-sponsorgray6138]"
             "{color:#b1aaa0 !important;-webkit-text-fill-color:#b1aaa0 !important;"
             "opacity:1 !important;visibility:visible !important;}"
             // First-paint stock sprite policy: never invert/replace the native asset.
             // Color is supplied for currentColor/icon-font variants; background-image
             // pixels, dimensions and the native internal i remain Amazon-owned.
             "[class*=ad-feedback-spr]"
             "{filter:none !important;color:#b1aaa0 !important;opacity:1 !important;visibility:visible !important;}"
             // Keep the probe-proven v6.0.133 APE floor ownership. This is not the
             // 6.0.134+ ancestor clearer: only Amazon's known APE placement chrome is
             // transparent so the already-dark page floor shows through.
             "[class*=ape-wrapper],[class*=ape-placement],[class*=ape-feedback]"
             "{background-color:transparent !important;border-color:transparent !important;"
             "box-shadow:none !important;outline-color:transparent !important;}"
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
             // v5.446 CHECKBOX FIRST-PAINT + 32PX SQUARE CHROME. The device capture
             // names the real Amazon painter as a 23px i.a-icon-checkbox.  Its
             // 3px dark spread plus 1.5px chrome spread is exactly 32px overall,
             // matching the cards/Heart/chevron controls without touching the
             // sprite image or background-position. The inset paint covers the
             // unchecked sprite with the exact shared #181a1b color; importantly,
             // no filter can blacken the chrome. Native :checked removes the
             // treatment immediately, leaving only Amazon's stock blue frame.
             ".a-checkbox:not(:has(input[type=checkbox]:checked)) i.a-icon-checkbox,"
             ".a-checkbox:not(:has(input[type=checkbox]:checked)) .a-icon-checkbox"
             "{filter:none !important;border-radius:4px !important;"
             "box-shadow:inset 0 0 0 64px #181a1b,0 0 0 3px #181a1b,"
             "0 0 0 4.5px rgba(255,255,255,.65) !important;"
             "transition:none !important;}"
             ".a-checkbox:has(input[type=checkbox]:checked) i.a-icon-checkbox,"
             ".a-checkbox:has(input[type=checkbox]:checked) .a-icon-checkbox"
             "{filter:none !important;border-radius:0 !important;box-shadow:none !important;"
             "transition:none !important;}"
             // Cart P14 proved the intermittent gray rectangle is the 35x44
             // label around the 23px sprite. It is not part of the sprite or hit
             // target, so neutralize only that paint at documentStart.
             ".sc-item-checkbox .a-checkbox>label"
             "{background-color:transparent !important;background-image:none !important;"
             "border:0 !important;box-shadow:none !important;outline:0 !important;filter:none !important;}"
             ".sc-item-checkbox .a-checkbox>label::before,.sc-item-checkbox .a-checkbox>label::after"
             "{background-color:transparent !important;background-image:none !important;"
             "border:0 !important;box-shadow:none !important;outline:0 !important;filter:none !important;}"
             // v6.0.103: the More-like-this two-cards control was visually racing its
             // own lazy <img>: the host circle could paint while the image was still a
             // grey/white shim, then repaint again when Amazon swapped in the real cards
             // bitmap. Own the finished glyph declaratively instead. The host keeps its
             // existing geometry/click target; only paint is supplied here, and Amazon's
             // transient child artwork stays invisible so there is no second visual cycle.
             "[class*=mlt-icon-container]"
             "{background-color:#181a1b !important;border:1.5px solid rgba(255,255,255,.65) !important;"
             "border-radius:50%% !important;box-shadow:none !important;box-sizing:border-box !important;"
             "background-image:url(data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHJlY3QgeD0iOC4yIiB5PSI0LjQiIHdpZHRoPSIxMC4yIiBoZWlnaHQ9IjEzLjQiIHJ4PSIxLjQiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2ZmZiIgc3Ryb2tlLXdpZHRoPSIxLjYiLz48cmVjdCB4PSI1LjQiIHk9IjcuMiIgd2lkdGg9IjEwLjIiIGhlaWdodD0iMTMuNCIgcng9IjEuNCIgZmlsbD0iIzE4MWExYiIgc3Ryb2tlPSIjZmZmIiBzdHJva2Utd2lkdGg9IjEuNiIvPjxwYXRoIGQ9Ik0xMC41IDEwLjh2Nk03LjUgMTMuOGg2IiBmaWxsPSJub25lIiBzdHJva2U9IiNmZmYiIHN0cm9rZS13aWR0aD0iMS42IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz48L3N2Zz4=) !important;"
             "background-repeat:no-repeat !important;background-position:center !important;"
             "background-size:24px 24px !important;transition:none !important;animation:none !important;}"
             "[class*=mlt-icon-container] img,[class*=mlt-icon-container] i,"
             "[class*=mlt-icon-container] svg,[class*=mlt-icon-container] [class*=mlt-image-icon],"
             "[class*=mlt-icon-container] [class*=mlt-text-icon]"
             "{opacity:0 !important;filter:none !important;background-color:transparent !important;"
             "transition:none !important;animation:none !important;}"
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
             // v6.0.119: restore the v5.446 action-control foreground owner that was
             // lost in the v6.0.103 rollback branch. In the chevron overflow menu this
             // is what keeps Save/Select/Share vector/icon ink white without painting
             // a backdrop behind the glyph.
             "[class*=lists-framework-action-button],"
             "[class*=lists-framework-action-button] *"
             "{color:#ffffff !important;fill:#ffffff !important;}"
             // v6.0.119: v5.446-style overflow-menu leaf ownership. Use the exact
             // indexed row token (not the slow substring/:has overlay selectors from
             // v6.0.112-114). The current v6.0.103 MLT first-frame owner did not exist
             // in the donor, so remove only its circular chrome inside this menu while
             // preserving its canonical stacked-cards/+ background-image.
             ".puis-mab-overlay-row .mlt-icon-container"
             "{background-color:transparent !important;border:0 !important;"
             "border-radius:0 !important;box-shadow:none !important;outline:0 !important;}"
             // v5.440/v5.446 probes identify these as the actual tiny menu painters:
             // Save = .puis-mab-overlay-heart, Select = i.a-icon-checkbox, Share =
             // a-icon-share / an empty 16px aok-inline-block background painter.
             // Filter only those leaves, never the row/wrapper, so alpha stays clear.
             ".puis-mab-overlay-row .puis-mab-overlay-heart,"
             ".puis-mab-overlay-row .a-icon-share"
             "{filter:brightness(0) invert(1) !important;color:#ffffff !important;"
             "fill:#ffffff !important;stroke:#ffffff !important;border:0 !important;"
             "box-shadow:none !important;outline:0 !important;}"
             // v6.0.121: restore the deterministic custom Select painter from v6.0.115.
             // The stock menu checkbox can arrive without usable sprite art and the normal
             // product Compare owner can reclaim it after mount. Paint only the exact menu
             // leaf with the preferred 16px white square/check; Amazon retains the row/input.
             "html body .puis-mab-overlay .puis-mab-overlay-row i.a-icon.a-icon-checkbox,"
             "html body .puis-mab-overlay .puis-mab-overlay-row i.a-icon-checkbox"
             "{filter:none !important;background-color:transparent !important;"
             "background-image:url(data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNiAxNiI+PHJlY3QgeD0iMS40IiB5PSIxLjQiIHdpZHRoPSIxMy4yIiBoZWlnaHQ9IjEzLjIiIHJ4PSIxLjciIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2ZmZiIgc3Ryb2tlLXdpZHRoPSIxLjgiLz48cGF0aCBkPSJNNC4yIDguMiA2LjggMTAuOCAxMiA1LjYiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2ZmZiIgc3Ryb2tlLXdpZHRoPSIxLjgiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCIvPjwvc3ZnPg==) !important;"
             "background-repeat:no-repeat !important;background-position:center !important;"
             "background-size:16px 16px !important;border:0 !important;border-radius:0 !important;"
             "box-shadow:none !important;outline:0 !important;transition:none !important;}"
             // v6.0.126: probe 6125 identifies Share's real painter conclusively.
             // Every sampled product uses the same mask-backed leaf:
             // .puis-mab-overlay-icon-share. Its mask is already the correct Amazon
             // Share shape; only the mask ink (background-color) is unstable. Hidden
             // overlays computed ~#e8e6e3 while the visible broken overlay computed
             // ~#0c0d0e. Own only that leaf's ink, never the row or chevron.
             "html body .puis-mab-overlay .puis-mab-overlay-row-share .puis-mab-overlay-icon-share"
             "{filter:none !important;background-color:#ffffff !important;"
             "color:#ffffff !important;fill:#ffffff !important;stroke:#ffffff !important;"
             "border:0 !important;box-shadow:none !important;outline:0 !important;"
             "transition:none !important;animation:none !important;}"
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
             // v6.0.101: the search-result deal chip is raw Amazon #cc0c39 before
             // Dark Reader and settles near #a50b31 after DR. Lock the final hue in
             // Dark Reader's authoritative fixes sheet so it cannot shift after first paint.
             "[class*=badgeLabel]{background-color:#a50b31 !important;color:#ffffff !important;"
             "-webkit-text-fill-color:#ffffff !important;mix-blend-mode:normal !important;transition:none !important;}"
             "[class*=badgeLabel] *{color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;}"
             // v6.0.101: v6.0.100 removed the white swatch background plane, but the
             // remaining circular flash is the stock light ring itself. Preserve
             // selected/unselected state while owning border/outline colour only.
             ".s-color-swatch-outer-circle{border-color:#2f2f32 !important;outline-color:#2f2f32 !important;transition:none !important;}"
             ".s-color-swatch-outer-circle.s-color-swatch-outer-circle-selected{border-color:#6d6b68 !important;outline-color:#6d6b68 !important;}"
             // v6.0.88: exact v5.446 v5.264-era Interests/image-wrapper prepaint.
             // This is the missing half of the historical flash fix: product-art
             // wrappers are transparent before hydration so the already-dark pane
             // floor shows through instead of Amazon white.  Keep this declarative;
             // do NOT restore the retired after-paint ADCardBorderFixJS census.
             "picture,[class*=image-container],[class*=thumbnail-conta],[class*=single-creative],"
             "[class*=s-image],[class*=unfill],[class*=placehold]"
             "{background-color:transparent !important;}"
             // v6.0.98: keep the v6.0.94/97 transparent shells and also neutralise
             // their structural pseudo-elements. Recycled
             // result rows can briefly instantiate these wrappers/pseudos with Amazon's
             // stock light paint before their final classes/styles settle. Only named
             // text/structure wrappers are cleared; swatch/radio/button artwork is not
             // selected, so the actual colour circles retain Amazon's fills/borders.
             "[data-csa-c-content-id=variation-options-link],[class*=s-variations-options-justify-content],"
             "[class*=s-variation-options-text],[class*=s-variation-options-link],"
             "[class*=s-color-swatch-container-list-view],[class*=puis-csi-with-label-container],"
             // v6.0.99: the visible rectangle is often the OUTER component shell, not
             // the inner text/swatch node. Own those immediate wrappers as transparent.
             "[class*=rush-component]:has([data-csa-c-content-id=variation-options-link]),"
             "[class*=rush-component]:has([class*=s-variation-options-link]),"
             "[class*=rush-component]:has([class*=s-color-swatch-container-list-view]),"
             "[class*=rush-component]:has([class*=puis-csi-with-label-container]),"
             ":where(div,span,section):has(> [data-csa-c-content-id=variation-options-link]),"
             ":where(div,span,section):has(> [class*=s-variation-options-link]),"
             ":where(div,span,section):has(> [class*=s-color-swatch-container-list-view]),"
             ":where(div,span,section):has(> [class*=puis-csi-with-label-container]),"
             ":where(div,span,section):has(> [class*=rush-component] [class*=s-variation-options-link]),"
             ":where(div,span,section):has(> [class*=rush-component] [class*=s-color-swatch-container-list-view]),"
             // Status-badge rows (Amazon's Choice / Best Seller) have their own full-width
             // structural row behind the actual colored/black badge. Clear the row only;
             // .a-badge/.a-badge-label remain Amazon-owned.
             "[data-component-type=s-status-badge-component],"
             "[data-component-type=s-status-badge-component]>.a-row.a-badge-region,"
             ":where(div,span,section):has(> [data-component-type=s-status-badge-component]),"
             ":where(div,span,section):has(> span [data-component-type=s-status-badge-component])"
             "{background:transparent !important;background-color:transparent !important;background-image:none !important;box-shadow:none !important;border-color:transparent !important;outline:0 !important;}"
             // v6.0.100: exact probe-proven inner shell ownership. Do not clear
             // swatch borders: only the stock white background plane is removed.
             ".s-color-swatch-container,.s-color-swatch-outer-circle,"
             ".puis-status-badge-container,[data-component-type=s-status-badge-component] .a-badge-region"
             "{background:transparent !important;background-color:transparent !important;background-image:none !important;box-shadow:none !important;}"
             "[data-csa-c-content-id=variation-options-link] [class*=a-truncate],"
             "[data-csa-c-content-id=variation-options-link] [class*=a-truncate-full],"
             "[data-csa-c-content-id=variation-options-link] [class*=a-truncate-cut],"
             "[class*=s-variation-options-link] [class*=a-truncate],"
             "[class*=s-variation-options-link] [class*=a-truncate-full],"
             "[class*=s-variation-options-link] [class*=a-truncate-cut],"
             "[class*=s-variation-options-link] [class*=rush-component],"
             "[class*=s-variation-options-link] [class*=text-wrapper],"
             "[class*=s-color-swatch-container-list-view] [class*=puis-csi-with-label-container],"
             "[class*=s-color-swatch-container-list-view] [class*=puis-cs-label],"
             "[class*=s-color-swatch-container-list-view] [class*=text-wrapper],"
             "[class*=s-color-swatch-container-list-view] [class*=rush-component],"
             "[class*=s-color-swatch-container-list-view] [class*=a-truncate],"
             "[class*=s-color-swatch-container-list-view] [class*=a-truncate-full],"
             "[class*=s-color-swatch-container-list-view] [class*=a-truncate-cut]"
             "{background:transparent !important;background-color:transparent !important;background-image:none !important;box-shadow:none !important;}"
             // v6.0.98: transient white shells can live on pseudo-elements even when
             // the settled element background is transparent. Clear pseudos only on
             // these variation/swatch structural shells; actual radio/swatch controls
             // are descendants and remain Amazon-owned.
             "[data-csa-c-content-id=variation-options-link]::before,[data-csa-c-content-id=variation-options-link]::after,"
             "[class*=s-variations-options-justify-content]::before,[class*=s-variations-options-justify-content]::after,"
             "[class*=s-variation-options-text]::before,[class*=s-variation-options-text]::after,"
             "[class*=s-variation-options-link]::before,[class*=s-variation-options-link]::after,"
             "[class*=s-color-swatch-container-list-view]::before,[class*=s-color-swatch-container-list-view]::after,"
             ".s-color-swatch-container::before,.s-color-swatch-container::after,"
             ".s-color-swatch-outer-circle::before,.s-color-swatch-outer-circle::after,"
             ".puis-status-badge-container::before,.puis-status-badge-container::after,"
             "[class*=puis-csi-with-label-container]::before,[class*=puis-csi-with-label-container]::after,"
             "[class*=s-variation-options-link] [class*=a-truncate]::before,[class*=s-variation-options-link] [class*=a-truncate]::after,"
             "[class*=s-color-swatch-container-list-view] [class*=a-truncate]::before,[class*=s-color-swatch-container-list-view] [class*=a-truncate]::after,"
             "[class*=s-color-swatch-container-list-view] [class*=a-truncate-cut]::before,[class*=s-color-swatch-container-list-view] [class*=a-truncate-cut]::after,"
             "[class*=rush-component]:has([class*=s-variation-options-link])::before,[class*=rush-component]:has([class*=s-variation-options-link])::after,"
             "[class*=rush-component]:has([class*=s-color-swatch-container-list-view])::before,[class*=rush-component]:has([class*=s-color-swatch-container-list-view])::after,"
             "[data-component-type=s-status-badge-component]::before,[data-component-type=s-status-badge-component]::after,"
             "[data-component-type=s-status-badge-component]>.a-row.a-badge-region::before,[data-component-type=s-status-badge-component]>.a-row.a-badge-region::after"
             "{background:transparent !important;background-color:transparent !important;background-image:none !important;box-shadow:none !important;}"
             ".s-coupon-tile.red{background-color:#440000 !important;background-image:none !important;}"
             ".s-coupon-tile.red label,.s-coupon-tile.red span"
             "{color:var(--darkreader-neutral-text,#e8e6e3) !important;"
             "-webkit-text-fill-color:var(--darkreader-neutral-text,#e8e6e3) !important;}"
             // v6.0.85: direct v5.446 person/Interests card + pill prepaint family.
             // These stable structural classes were the donor's parse-time owner for
             // the light card outlines seen while Interests-like surfaces hydrate.
             "[class*=a-cardui],[class*=npack-asin-card],[class*=gwm-asin-tile],"
             "[class*=gwm-window-layout],[class*=window-container],[class*=gwm-dashboard-container],"
             "[class*=wd-backdrop],[class*=theming-card],[class*=a-unordered-list],"
             "[class*=mosaic-container],[class*=puis-card],[class*=gwm-tile],[class*=_container_]"
             "{border-color:#3b4043 !important;}"
             "[class*=deal],[class*=badge],[class*=prime],[class*=error],[class*=alert],"
             "[class*=warning],[aria-invalid=true]{border-color:initial !important;}"
             "[class*=a-button-primary],[class*=a-button-search],[class*=a-button-oneclick],"
             "[class*=a-button-buy],.a-button-inner,.a-button-text{border-color:transparent !important;}"
             // v5.446 card-skeleton owner: empty structural shells carry no content,
             // so giving them the dark floor prevents a white hydration flash without
             // covering product imagery or live card content.
             "[class*=puis] [class*=a-section]:empty,[class*=s-result] [class*=a-section]:empty,"
             "[class*=s-card] [class*=a-section]:empty{background-color:#181a1b !important;}"
             // v6.0.37: v5.446's exact mosaic border owner lived after Dark Reader's
             // palette transform. Keep the seasonal panel on the same #3b4043 gray as
             // neighboring Home cards instead of letting DR re-map it to warm tan.
             "[class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer]"
             "{border-color:#3b4043 !important;}"
             "[class*=hp-mosaic-container] [class*=hp-mosaic-container],"
             "[class*=_mosaic-container_style_widgetContainer] [class*=mosaic-container]"
             "{border-color:#3b4043 !important;}"
             // v6.0.37: donor badgeMessage deliberately painted #181a1b behind deal
             // copy/countdowns. Keep its light ink but make that message surface/pseudos
             // transparent. badgeLabel (the red %% off pill) remains independently owned.
             "[class*=npack-asin-card] [class*=badgeMessage],"
             "[class*=npack-asin-card] [class*=badgeMessage] *,"
             "[class*=cXVhZ] [class*=badgeMessage],"
             "[class*=cXVhZ] [class*=badgeMessage] *"
             "{background-color:transparent !important;background-image:none !important;"
             "color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;"
             "box-shadow:none !important;border-color:transparent !important;outline:0 !important;}"
             "[class*=npack-asin-card] [class*=badgeMessage]::before,"
             "[class*=npack-asin-card] [class*=badgeMessage]::after,"
             "[class*=npack-asin-card] [class*=badgeMessage] *::before,"
             "[class*=npack-asin-card] [class*=badgeMessage] *::after,"
             "[class*=cXVhZ] [class*=badgeMessage]::before,"
             "[class*=cXVhZ] [class*=badgeMessage]::after,"
             "[class*=cXVhZ] [class*=badgeMessage] *::before,"
             "[class*=cXVhZ] [class*=badgeMessage] *::after"
             "{background:transparent !important;background-image:none !important;"
             "box-shadow:none !important;border-color:transparent !important;}"
             // v6.0.18 / v5.446 long-copy fade fix. Amazon overlays a white
             // read-more scrim on long descriptions/reviews. Remove only the
             // expander fade paint; never hide generic gradient content.
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
             // v6.0.24 / v5.446: PDP Share is its own stock action glyph.
             // Keep ownership on the actual share trigger/leaves so generic glyph
             // repair and carousel-dot paint can never decide its colour.
             ".ssf-share-trigger{color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;"
             "fill:#ffffff !important;stroke:#ffffff !important;filter:none !important;opacity:1 !important;}"
             ".ssf-share-trigger svg,.ssf-share-trigger path"
             "{color:#ffffff !important;fill:#ffffff !important;stroke:#ffffff !important;opacity:1 !important;}"
             ".ssf-share-trigger i,.ssf-share-trigger .a-icon,.ssf-share-trigger img"
             "{filter:brightness(0) invert(1) !important;background-color:transparent !important;"
             "color:#ffffff !important;opacity:1 !important;}"
             ".ssf-share-trigger::before,.ssf-share-trigger::after,"
             ".ssf-share-trigger *::before,.ssf-share-trigger *::after"
             "{color:#ffffff !important;filter:brightness(0) invert(1) !important;opacity:1 !important;}"
             // v6.0.20 direct v5.446 carousel-dot port. Static selectors own
             // first paint; dotFix374 below follows Amazon's live selected state.
             "ul.a-pagination.a-dots li.a-selected,"
             "ul.a-pagination.a-dots li.dot-selected-t2,"
             "ul.a-pagination.a-dots li[aria-current=true],"
             "ul.a-pagination.a-dots li[aria-current=page],"
             "ul.a-pagination.a-dots li[aria-selected=true],"
             "[data-ad-dotselected374]"
             "{background-color:#ffffff !important;border-color:#ffffff !important;}"
             "[data-ad-dotselected374]::before,[data-ad-dotselected374]::after,"
             "[data-ad-dotselected374] [class*=dot],[data-ad-dotselected374] span"
             "{background-color:#ffffff !important;border-color:#ffffff !important;"
             "color:#ffffff !important;fill:#ffffff !important;}"
             "',invert:[],ignoreInlineStyle:['[data-ad-native615]','[data-ad-native615] *',"
             "'ul.a-pagination.a-dots li.a-selected','ul.a-pagination.a-dots li.dot-selected-t2','[data-ad-dotselected374]',"
             "'[class*=ape-wrapper]','[class*=ape-placement]','[class*=ape-feedback]','[class*=ape-feedback] *',"
             "'html body .puis-mab-overlay .puis-mab-overlay-row-share .puis-mab-overlay-icon-share'],"
             "ignoreImageAnalysis:['*'],disableStyleSheetsProxy:false}",
            imgBackdrop];
    return gADFixesLiteral613;
}

static NSString *ADThemeLiteral(void){
    if (gADThemeLiteral613) return gADThemeLiteral613;
    // mode:1 = dark. styleSystemControls themes form controls/scrollbars.
    // The fixed/sticky headers Amazon uses respond better with these on.
    gADThemeLiteral613 = [NSString stringWithFormat:
        @"{mode:1,brightness:%ld,contrast:%ld,sepia:%ld,grayscale:%ld,"
         "darkSchemeBackgroundColor:'%s',darkSchemeTextColor:'%s',"
         "styleSystemControls:true}",
        gP.brightness, gP.contrast, gP.sepia, gP.grayscale, gP.bgHex, gP.fgHex];
    return gADThemeLiteral613;
}

// HEAVY: full Dark Reader UMD + first enable(). Injected ONCE per document at
// documentStart via a WKUserScript. The 346KB engine is parsed a single time per page.
static NSString *ADDarkReaderBootstrap(void){
    if (gADBootstrap613) return gADBootstrap613;
    NSString *dr = ADBundledDarkReaderJS();
    if (!dr.length) return nil;
    NSString *floorBG = [NSString stringWithUTF8String:gP.bgHex] ?: @"#181a1b";
    gADBootstrap613 = [NSString stringWithFormat:
        @"(function(){try{"
         "if(window.__AMZDARK_LOADED__)return;window.__AMZDARK_LOADED__=1;"
         // v6.0.12: establish the page canvas before the Dark Reader UMD is parsed.
         // This is intentionally root-only: it cannot touch product/photo pixels,
         // but it means lazy/virtualised holes reveal the theme floor, not Amazon white.
         "try{if(!document.getElementById('adfloor612')){var f=document.createElement('style');"
           "f.id='adfloor612';f.textContent='html,body,#a-page,#gwm-PageContent,main{background-color:%@ !important;}"
           // v6.0.88: restore the exact v5.446 adcardfix image-wrapper floor.
           // The historical Interests work made these wrappers transparent at parse
           // time; v6.0.85 accidentally ported the borders/skeletons but omitted this.
           "picture,[class*=image-container],[class*=thumbnail-conta],[class*=single-creative],"
           "[class*=s-image],[class*=unfill],[class*=placehold]"
           "{background-color:transparent !important;}"
           // v6.0.94: own variation + colour-swatch structural shells as transparent
           // at documentStart.  This prevents both the stock white first frame and the
           // darker replacement rectangle left by v6.0.89; the dark card underneath
           // remains visible while swatch circles themselves stay Amazon-owned.
           "[data-csa-c-content-id=variation-options-link],[class*=s-variations-options-justify-content],"
           "[class*=s-variation-options-text],[class*=s-variation-options-link],"
           "[class*=s-color-swatch-container-list-view],[class*=puis-csi-with-label-container],"
           // v6.0.99: clear the actual outer component shells at first paint, including
           // status-badge rows, while leaving the real swatches and badge labels alone.
           "[class*=rush-component]:has([data-csa-c-content-id=variation-options-link]),"
           "[class*=rush-component]:has([class*=s-variation-options-link]),"
           "[class*=rush-component]:has([class*=s-color-swatch-container-list-view]),"
           "[class*=rush-component]:has([class*=puis-csi-with-label-container]),"
           ":where(div,span,section):has(> [data-csa-c-content-id=variation-options-link]),"
           ":where(div,span,section):has(> [class*=s-variation-options-link]),"
           ":where(div,span,section):has(> [class*=s-color-swatch-container-list-view]),"
           ":where(div,span,section):has(> [class*=puis-csi-with-label-container]),"
           ":where(div,span,section):has(> [class*=rush-component] [class*=s-variation-options-link]),"
           ":where(div,span,section):has(> [class*=rush-component] [class*=s-color-swatch-container-list-view]),"
           "[data-component-type=s-status-badge-component],"
           "[data-component-type=s-status-badge-component]>.a-row.a-badge-region,"
           ":where(div,span,section):has(> [data-component-type=s-status-badge-component]),"
           ":where(div,span,section):has(> span [data-component-type=s-status-badge-component])"
           "{background:transparent !important;background-color:transparent !important;background-image:none !important;box-shadow:none !important;border-color:transparent !important;outline:0 !important;}"
             // v6.0.100: exact probe-proven inner shell ownership. Do not clear
             // swatch borders: only the stock white background plane is removed.
             ".s-color-swatch-container,.s-color-swatch-outer-circle,"
             ".puis-status-badge-container,[data-component-type=s-status-badge-component] .a-badge-region"
             "{background:transparent !important;background-color:transparent !important;background-image:none !important;box-shadow:none !important;}"
             // v6.0.101: first-paint ring colours matched to the settled dark state.
             // Never touch .s-color-swatch-inner-circle-fill; the real swatch colours
             // and selected-state geometry remain Amazon-owned.
             ".s-color-swatch-outer-circle{border-color:#2f2f32 !important;outline-color:#2f2f32 !important;transition:none !important;}"
             ".s-color-swatch-outer-circle.s-color-swatch-outer-circle-selected{border-color:#6d6b68 !important;outline-color:#6d6b68 !important;}"
           "[data-csa-c-content-id=variation-options-link] [class*=a-truncate],"
           "[data-csa-c-content-id=variation-options-link] [class*=a-truncate-full],"
           "[data-csa-c-content-id=variation-options-link] [class*=a-truncate-cut],"
           "[class*=s-variation-options-link] [class*=a-truncate],"
           "[class*=s-variation-options-link] [class*=a-truncate-full],"
           "[class*=s-variation-options-link] [class*=a-truncate-cut],"
           "[class*=s-variation-options-link] [class*=rush-component],"
           "[class*=s-variation-options-link] [class*=text-wrapper],"
           "[class*=s-color-swatch-container-list-view] [class*=puis-csi-with-label-container],"
           "[class*=s-color-swatch-container-list-view] [class*=puis-cs-label],"
           "[class*=s-color-swatch-container-list-view] [class*=text-wrapper],"
           "[class*=s-color-swatch-container-list-view] [class*=rush-component],"
           "[class*=s-color-swatch-container-list-view] [class*=a-truncate],"
           "[class*=s-color-swatch-container-list-view] [class*=a-truncate-full],"
           "[class*=s-color-swatch-container-list-view] [class*=a-truncate-cut]"
           "{background:transparent !important;background-color:transparent !important;background-image:none !important;box-shadow:none !important;}"
           // v6.0.98: transient white shells can live on pseudo-elements even when
           // the settled element background is transparent. Clear pseudos only on
           // these variation/swatch structural shells; actual radio/swatch controls
           // are descendants and remain Amazon-owned.
           "[data-csa-c-content-id=variation-options-link]::before,[data-csa-c-content-id=variation-options-link]::after,"
           "[class*=s-variations-options-justify-content]::before,[class*=s-variations-options-justify-content]::after,"
           "[class*=s-variation-options-text]::before,[class*=s-variation-options-text]::after,"
           "[class*=s-variation-options-link]::before,[class*=s-variation-options-link]::after,"
           "[class*=s-color-swatch-container-list-view]::before,[class*=s-color-swatch-container-list-view]::after,"
             ".s-color-swatch-container::before,.s-color-swatch-container::after,"
             ".s-color-swatch-outer-circle::before,.s-color-swatch-outer-circle::after,"
             ".puis-status-badge-container::before,.puis-status-badge-container::after,"
           "[class*=puis-csi-with-label-container]::before,[class*=puis-csi-with-label-container]::after,"
           "[class*=s-variation-options-link] [class*=a-truncate]::before,[class*=s-variation-options-link] [class*=a-truncate]::after,"
           "[class*=s-color-swatch-container-list-view] [class*=a-truncate]::before,[class*=s-color-swatch-container-list-view] [class*=a-truncate]::after,"
           "[class*=s-color-swatch-container-list-view] [class*=a-truncate-cut]::before,[class*=s-color-swatch-container-list-view] [class*=a-truncate-cut]::after,"
           "[class*=rush-component]:has([class*=s-variation-options-link])::before,[class*=rush-component]:has([class*=s-variation-options-link])::after,"
           "[class*=rush-component]:has([class*=s-color-swatch-container-list-view])::before,[class*=rush-component]:has([class*=s-color-swatch-container-list-view])::after,"
           "[data-component-type=s-status-badge-component]::before,[data-component-type=s-status-badge-component]::after,"
           "[data-component-type=s-status-badge-component]>.a-row.a-badge-region::before,[data-component-type=s-status-badge-component]>.a-row.a-badge-region::after"
           "{background:transparent !important;background-color:transparent !important;background-image:none !important;box-shadow:none !important;}"
           ".s-coupon-tile.red{background-color:#440000 !important;background-image:none !important;}"
           ".s-coupon-tile.red label,.s-coupon-tile.red span"
           "{color:var(--darkreader-neutral-text,#e8e6e3) !important;"
           "-webkit-text-fill-color:var(--darkreader-neutral-text,#e8e6e3) !important;}"
           // v6.0.85: direct v5.446 Interests/person-card first-paint rules. Keep them
           // in this already-existing documentStart sheet so Amazon never gets a light
           // hydration frame before Dark Reader's own override sheet is available.
           "img[class*=add-icon],img[class*=plus-icon]{filter:invert(1) hue-rotate(180deg) !important;}"
             // v6.0.116: exact v5.446 Search/nav bitmap backdrop rule.
             // Search glyph hosts stay unpainted; only real IMG chrome is guaranteed
             // a transparent surround, while the donor generic glyph pass owns ink.
             "[class*=nav-search] img,[class*=searchbar] img,[class*=search-bar] img,"
             "[role=search] img,[class*=nav-] img[class*=icon],[class*=header] img[class*=icon]"
             "{background-color:transparent !important;}"
             // v6.0.138: keep Sponsored presentation stock-owned. Only the
             // text ink is bridged to Amazon/Dark Reader's dark-mode secondary gray;
             // glyph artwork, geometry, spacing and internal "i" remain untouched.
             "[class*=sponsored-label],[class*=ad-feedback-text],[id^=ad-feedback-text-],"
             "[id^=af-label-primary-link-],[data-ad-sponsorgray6138]"
             "{color:#b1aaa0 !important;-webkit-text-fill-color:#b1aaa0 !important;"
             "opacity:1 !important;visibility:visible !important;}"
             // First-paint stock sprite policy: never invert/replace the native asset.
             // Color is supplied for currentColor/icon-font variants; background-image
             // pixels, dimensions and the native internal i remain Amazon-owned.
             "[class*=ad-feedback-spr]"
             "{filter:none !important;color:#b1aaa0 !important;opacity:1 !important;visibility:visible !important;}"
             // Keep the probe-proven v6.0.133 APE floor ownership. This is not the
             // 6.0.134+ ancestor clearer: only Amazon's known APE placement chrome is
             // transparent so the already-dark page floor shows through.
             "[class*=ape-wrapper],[class*=ape-placement],[class*=ape-feedback]"
             "{background-color:transparent !important;border-color:transparent !important;"
             "box-shadow:none !important;outline-color:transparent !important;}"
           // v6.0.103: first-frame two-cards owner. This is intentionally duplicated
           // in ADFixesLiteral so the exact same paint exists before and after Dark Reader.
           "[class*=mlt-icon-container]"
           "{background-color:#181a1b !important;border:1.5px solid rgba(255,255,255,.65) !important;"
           "border-radius:50%% !important;box-shadow:none !important;box-sizing:border-box !important;"
           "background-image:url(data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHJlY3QgeD0iOC4yIiB5PSI0LjQiIHdpZHRoPSIxMC4yIiBoZWlnaHQ9IjEzLjQiIHJ4PSIxLjQiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2ZmZiIgc3Ryb2tlLXdpZHRoPSIxLjYiLz48cmVjdCB4PSI1LjQiIHk9IjcuMiIgd2lkdGg9IjEwLjIiIGhlaWdodD0iMTMuNCIgcng9IjEuNCIgZmlsbD0iIzE4MWExYiIgc3Ryb2tlPSIjZmZmIiBzdHJva2Utd2lkdGg9IjEuNiIvPjxwYXRoIGQ9Ik0xMC41IDEwLjh2Nk03LjUgMTMuOGg2IiBmaWxsPSJub25lIiBzdHJva2U9IiNmZmYiIHN0cm9rZS13aWR0aD0iMS42IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz48L3N2Zz4=) !important;"
           "background-repeat:no-repeat !important;background-position:center !important;"
           "background-size:24px 24px !important;transition:none !important;animation:none !important;}"
           "[class*=mlt-icon-container] img,[class*=mlt-icon-container] i,"
           "[class*=mlt-icon-container] svg,[class*=mlt-icon-container] [class*=mlt-image-icon],"
           "[class*=mlt-icon-container] [class*=mlt-text-icon]"
           "{opacity:0 !important;filter:none !important;background-color:transparent !important;"
           "transition:none !important;animation:none !important;}"
           // v6.0.119: exact v5.446 documentStart treatment for lists-framework
           // action glyph leaves. This was present in the donor's earliest CSS but
           // missing from the v6.0.103-derived branch.
           "[class*=lists-framework-unfill],[class*=lists-framework-fill],"
           "[class*=lists-framework-action-button] svg,[class*=lists-framework-action-button] i,"
           "[class*=lists-framework-action-button] img"
           "{filter:brightness(0) invert(1) !important;background-color:transparent !important;"
           "border:0 !important;box-shadow:none !important;border-radius:0 !important;"
           "max-width:26px !important;max-height:26px !important;}"
           "[class*=lists-framework-action-button],[class*=lists-framework-action-button] *"
           "{color:#ffffff !important;fill:#ffffff !important;}"
           // v6.0.119 overflow compatibility for the 6.x canonical MLT owner. The
           // donor had no synthetic host circle here; flatten only the menu copy.
           ".puis-mab-overlay-row .mlt-icon-container"
           "{background-color:transparent !important;border:0 !important;"
           "border-radius:0 !important;box-shadow:none !important;outline:0 !important;}"
           ".puis-mab-overlay-row .puis-mab-overlay-heart,"
           ".puis-mab-overlay-row .a-icon-share"
           "{filter:brightness(0) invert(1) !important;color:#ffffff !important;"
           "fill:#ffffff !important;stroke:#ffffff !important;border:0 !important;"
           "box-shadow:none !important;outline:0 !important;}"
           // v6.0.121: deterministic v6.0.115 Select painter, duplicated in the
           // post-DarkReader fixes so later theme application cannot replace it.
           "html body .puis-mab-overlay .puis-mab-overlay-row i.a-icon.a-icon-checkbox,"
           "html body .puis-mab-overlay .puis-mab-overlay-row i.a-icon-checkbox"
           "{filter:none !important;background-color:transparent !important;"
           "background-image:url(data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNiAxNiI+PHJlY3QgeD0iMS40IiB5PSIxLjQiIHdpZHRoPSIxMy4yIiBoZWlnaHQ9IjEzLjIiIHJ4PSIxLjciIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2ZmZiIgc3Ryb2tlLXdpZHRoPSIxLjgiLz48cGF0aCBkPSJNNC4yIDguMiA2LjggMTAuOCAxMiA1LjYiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2ZmZiIgc3Ryb2tlLXdpZHRoPSIxLjgiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCIvPjwvc3ZnPg==) !important;"
           "background-repeat:no-repeat !important;background-position:center !important;"
           "background-size:16px 16px !important;border:0 !important;border-radius:0 !important;"
           "box-shadow:none !important;outline:0 !important;transition:none !important;}"
           // v6.0.126: same exact Share mask-leaf owner after Dark Reader.
           // The probe proves the stock mask itself is correct; keep it and lock only
           // the mask paint to white so hydration/visibility changes cannot darken it.
           "html body .puis-mab-overlay .puis-mab-overlay-row-share .puis-mab-overlay-icon-share"
           "{filter:none !important;background-color:#ffffff !important;"
           "color:#ffffff !important;fill:#ffffff !important;stroke:#ffffff !important;"
           "border:0 !important;box-shadow:none !important;outline:0 !important;"
           "transition:none !important;animation:none !important;}"
           "[class*=a-cardui],[class*=npack-asin-card],[class*=gwm-asin-tile],[class*=gwm-window-layout],"
           "[class*=window-container],[class*=gwm-dashboard-container],[class*=wd-backdrop],"
           "[class*=theming-card],[class*=a-unordered-list],[class*=mosaic-container],"
           "[class*=puis-card],[class*=gwm-tile],[class*=_container_]{border-color:#3b4043 !important;}"
           "[class*=deal],[class*=badge],[class*=prime],[class*=error],[class*=alert],"
           "[class*=warning],[aria-invalid=true]{border-color:initial !important;}"
           "[class*=a-button-primary],[class*=a-button-search],[class*=a-button-oneclick],"
           "[class*=a-button-buy],.a-button-inner,.a-button-text{border-color:transparent !important;}"
           "[class*=puis] [class*=a-section]:empty,[class*=s-result] [class*=a-section]:empty,"
           "[class*=s-card] [class*=a-section]:empty{background-color:%@ !important;}"
           // v6.0.36: promote the donor Home-card paint to documentStart.  The
           // seasonal mosaic family is semantic by class, not by the campaign title,
           // so College/holiday/back-to-school replacements inherit the same shell,
           // text, price, badge and arrow ownership before their first visible frame.
           "[class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer]{background-color:%@ !important;color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;border-color:#3b4043 !important;mix-blend-mode:normal !important;isolation:auto !important;}"
           "[class*=hp-mosaic-container] div,[class*=hp-mosaic-container] section,[class*=hp-mosaic-container] article,[class*=hp-mosaic-container] ul,[class*=hp-mosaic-container] ol,[class*=hp-mosaic-container] li,[class*=_mosaic-container_style_widgetContainer] div,[class*=_mosaic-container_style_widgetContainer] section,[class*=_mosaic-container_style_widgetContainer] article,[class*=_mosaic-container_style_widgetContainer] ul,[class*=_mosaic-container_style_widgetContainer] ol,[class*=_mosaic-container_style_widgetContainer] li{background-color:%@ !important;color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;border-color:#3b4043 !important;mix-blend-mode:normal !important;isolation:auto !important;}"
           "[class*=hp-mosaic-container] h1,[class*=hp-mosaic-container] h2,[class*=hp-mosaic-container] h3,[class*=hp-mosaic-container] h4,[class*=hp-mosaic-container] h5,[class*=hp-mosaic-container] h6,[class*=hp-mosaic-container] p,[class*=hp-mosaic-container] span,[class*=hp-mosaic-container] a,[class*=hp-mosaic-container] strong,[class*=hp-mosaic-container] small,[class*=_mosaic-container_style_widgetContainer] h1,[class*=_mosaic-container_style_widgetContainer] h2,[class*=_mosaic-container_style_widgetContainer] h3,[class*=_mosaic-container_style_widgetContainer] h4,[class*=_mosaic-container_style_widgetContainer] h5,[class*=_mosaic-container_style_widgetContainer] h6,[class*=_mosaic-container_style_widgetContainer] p,[class*=_mosaic-container_style_widgetContainer] span,[class*=_mosaic-container_style_widgetContainer] a,[class*=_mosaic-container_style_widgetContainer] strong,[class*=_mosaic-container_style_widgetContainer] small{color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;}"
           "[class*=hp-mosaic-container] .a-icon-next-rounded,[class*=hp-mosaic-container] .a-icon-previous-rounded,[class*=hp-mosaic-container] [class*=chevron],[class*=hp-mosaic-container] [class*=arrow],[class*=_mosaic-container_style_widgetContainer] .a-icon-next-rounded,[class*=_mosaic-container_style_widgetContainer] .a-icon-previous-rounded,[class*=_mosaic-container_style_widgetContainer] [class*=chevron],[class*=_mosaic-container_style_widgetContainer] [class*=arrow]{filter:brightness(0) invert(1) !important;opacity:1 !important;color:#e8e6e3 !important;fill:#e8e6e3 !important;stroke:#e8e6e3 !important;}"
           // v5.446's Home-card prepaint rules.  These are deliberately selector-only:
           // no text walk is needed for product titles/prices or deal badges to arrive
           // readable after Amazon hydrates a recycled card.
           "[class*=npack-asin-card],[class*=npack-asin-card] *,[class*=gwm-asin-tile],[class*=gwm-asin-tile] *,[class*=gwm-tile],[class*=gwm-tile] *,[class*=cXVhZ],[class*=cXVhZ] *{mix-blend-mode:normal !important;isolation:auto !important;}"
           "[class*=npack-asin-card] [class*=a-size-mini],[class*=npack-asin-card] [class*=badge],[class*=npack-asin-card] [class*=percent]{color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;}"
           "[class*=badgeLabel],[class*=hp-mosaic-container] [class*=badgeLabel],[class*=_mosaic-container_style_widgetContainer] [class*=badgeLabel]{background-color:#a50b31 !important;color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;mix-blend-mode:normal !important;}[class*=badgeLabel] *,[class*=hp-mosaic-container] [class*=badgeLabel] *,[class*=_mosaic-container_style_widgetContainer] [class*=badgeLabel] *{color:#ffffff !important;-webkit-text-fill-color:#ffffff !important;}"
           "[class*=npack-asin-card] [class*=badgeMessage],[class*=npack-asin-card] [class*=badgeMessage] *,[class*=cXVhZ] [class*=badgeMessage],[class*=cXVhZ] [class*=badgeMessage] *{background-color:transparent !important;background-image:none !important;color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;box-shadow:none !important;border-color:transparent !important;outline:0 !important;}"
           "[class*=npack-asin-card] [class*=badgeMessage]::before,[class*=npack-asin-card] [class*=badgeMessage]::after,[class*=npack-asin-card] [class*=badgeMessage] *::before,[class*=npack-asin-card] [class*=badgeMessage] *::after,[class*=cXVhZ] [class*=badgeMessage]::before,[class*=cXVhZ] [class*=badgeMessage]::after,[class*=cXVhZ] [class*=badgeMessage] *::before,[class*=cXVhZ] [class*=badgeMessage] *::after{background:transparent !important;background-image:none !important;box-shadow:none !important;border-color:transparent !important;}"
           "[class*=a-cardui] [class*=a-price-whole],[class*=a-cardui] [class*=a-price-symbol],[class*=a-cardui] [class*=a-price-decimal],[class*=a-cardui] [class*=a-truncate],[class*=cXVhZ] [class*=a-price-whole],[class*=cXVhZ] [class*=a-price-symbol],[class*=cXVhZ] [class*=a-price-decimal],[class*=cXVhZ] [class*=a-truncate],[class*=npack-asin-card] [class*=a-price-whole],[class*=npack-asin-card] [class*=a-price-symbol],[class*=npack-asin-card] [class*=a-price-decimal],[class*=npack-asin-card] [class*=a-truncate],[class*=gwm-asin-tile] [class*=a-price-whole],[class*=gwm-asin-tile] [class*=a-price-symbol],[class*=gwm-asin-tile] [class*=a-price-decimal],[class*=gwm-asin-tile] [class*=a-truncate]{color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;}"
           "[class*=gwm-tile] [class*=a-cardui-header],[class*=gwm-tile] [class*=a-cardui-header] *{color:#e8e6e3 !important;-webkit-text-fill-color:#e8e6e3 !important;}"
           "[style*=multiply],[style*=darken],[style*=color-burn],[class*=deal] [style*=blend],[class*=Deal] [style*=blend]{mix-blend-mode:normal !important;isolation:auto !important;}';"
           "(document.documentElement||document).appendChild(f);}}catch(e){}"
         // v6.0.15: Amazon-native ad islands.  v5.446 proved that creative
         // subtrees must be kept out of generic recolor/glyph ownership.  Mark the
         // known Home ad-card families before Dark Reader starts so all later
         // guards can use one cheap ancestor test.
         "try{window.__AD_NATIVE_SEL615__='[class*=single-creative-card],[class*=single-video-card],[class*=theming-card],[class*=canvas-card],[class*=ape-placement],[class*=ape-wrapper],[data-cel-widget*=ape],[id*=ape_],[class*=hybrid-widget-sponsored],[class*=adFeedbackMainComponent],[class*=sponsored-products]';"
           "window.__AD_IS_NATIVE615__=function(e){try{return !!(e&&e.closest&&(e.closest('[data-ad-native615]')||e.closest(window.__AD_NATIVE_SEL615__)));}catch(x){return false;}};"
           // v6.0.56: the old cleanup walked every descendant (up to 700) and every
           // attribute/style property twice.  Dark Reader already exposes exactly which
           // nodes it owns.  Touch only those markers; Amazon's own CSS stays untouched.
           "window.__AD_DR_ATTRS6056__=['data-darkreader-inline-bg','data-darkreader-inline-bgcolor','data-darkreader-inline-bgimage','data-darkreader-inline-border','data-darkreader-inline-border-bottom','data-darkreader-inline-border-bottom-short','data-darkreader-inline-border-left','data-darkreader-inline-border-left-short','data-darkreader-inline-border-right','data-darkreader-inline-border-right-short','data-darkreader-inline-border-top','data-darkreader-inline-border-top-short','data-darkreader-inline-border-short','data-darkreader-inline-boxshadow','data-darkreader-inline-color','data-darkreader-inline-fill','data-darkreader-inline-invert','data-darkreader-inline-outline','data-darkreader-inline-stopcolor','data-darkreader-inline-stroke'];"
           "window.__AD_DR_SEL6056__='[data-darkreader-inline-bg],[data-darkreader-inline-bgcolor],[data-darkreader-inline-bgimage],[data-darkreader-inline-border],[data-darkreader-inline-border-bottom],[data-darkreader-inline-border-bottom-short],[data-darkreader-inline-border-left],[data-darkreader-inline-border-left-short],[data-darkreader-inline-border-right],[data-darkreader-inline-border-right-short],[data-darkreader-inline-border-top],[data-darkreader-inline-border-top-short],[data-darkreader-inline-border-short],[data-darkreader-inline-boxshadow],[data-darkreader-inline-color],[data-darkreader-inline-fill],[data-darkreader-inline-invert],[data-darkreader-inline-outline],[data-darkreader-inline-stopcolor],[data-darkreader-inline-stroke],[style*=\"--darkreader-inline-\"]';"
           "window.__AD_STRIP_DR615__=function(root){try{if(!root||root.nodeType!==1)return 0;root.setAttribute('data-ad-native615','1');var E=[root],q=root.querySelectorAll?root.querySelectorAll(window.__AD_DR_SEL6056__):[];for(var i=0;i<q.length&&i<220;i++)E.push(q[i]);for(var z=0;z<E.length;z++){var el=E[z],A=window.__AD_DR_ATTRS6056__;for(var x=0;x<A.length;x++)if(el.hasAttribute&&el.hasAttribute(A[x]))el.removeAttribute(A[x]);var st=el.style;if(st){var rm=[];for(var y=0;y<st.length;y++){var pn=st[y];if(String(pn).indexOf('--darkreader-inline-')===0)rm.push(pn);}for(var y2=0;y2<rm.length;y2++)st.removeProperty(rm[y2]);}}return E.length;}catch(e){return 0;}};"
           "window.__AD_MARK_NATIVE615__=function(root){try{if(!root)return 0;var n=0,Q=[];if(root.nodeType===1&&root.matches&&root.matches(window.__AD_NATIVE_SEL615__))Q.push(root);if(root.querySelectorAll){var q=root.querySelectorAll(window.__AD_NATIVE_SEL615__),lim=(root===document)?80:16;for(var i=0;i<q.length&&i<lim;i++)Q.push(q[i]);}for(var j=0;j<Q.length;j++){var fresh=!Q[j].hasAttribute('data-ad-native615');if(fresh){Q[j].setAttribute('data-ad-native615','1');n++;}if(fresh||Q[j]===root)window.__AD_STRIP_DR615__(Q[j]);}try{if(window.__AD_TWB6033_ADROOT__){var h=(root.nodeType===1&&root.closest)?root.closest('[data-ad-native615],'+window.__AD_NATIVE_SEL615__):null;if(h)window.__AD_TWB6033_ADROOT__(root);for(var t=0;t<Q.length&&t<4;t++)if(Q[t]!==h)window.__AD_TWB6033_ADROOT__(Q[t]);}}catch(tx){}return n;}catch(e){return 0;}};"
           "window.__AD_MARK_NATIVE615__(document);if(!window.__AD_NATIVE_OBS615__&&document.documentElement){window.__AD_NATIVE_OBS615__=1;new MutationObserver(function(ms){try{for(var i=0;i<ms.length&&i<48;i++){var A=ms[i].addedNodes||[];for(var j=0;j<A.length&&j<24;j++)if(A[j]&&A[j].nodeType===1){window.__AD_MARK_NATIVE615__(A[j]);if(window.__AD_VIDEOSTOCK6066__)window.__AD_VIDEOSTOCK6066__(A[j]);}}}catch(e){}}).observe(document.documentElement,{childList:true,subtree:true});}}catch(e){}"
         // v6.0.67: preserve the matched compact-control tint and Amazon's native
         // glyphs. Clip only each compact control host + selected shell to a circle
         // so rectangular child/pseudo backing paint cannot remain visible in the
         // corners; intermediate wrappers are only cleared, never clipped.
         "try{var _v64=document.getElementById('advidwrap6064');if(_v64&&_v64.parentNode)_v64.parentNode.removeChild(_v64);var _v62=document.getElementById('advidctl6062');if(_v62&&_v62.parentNode)_v62.parentNode.removeChild(_v62);var _v67=document.getElementById('advidwrap6067');if(!_v67){_v67=document.createElement('style');_v67.id='advidwrap6067';_v67.textContent='[data-ad-videowrap6067],[data-ad-videowrap6067]::before,[data-ad-videowrap6067]::after{background:transparent!important;background-image:none!important;box-shadow:none!important;outline:none!important;border-color:transparent!important;}[data-ad-videoclip6067],[data-ad-videoshell6067]{overflow:hidden!important;border-radius:50%%!important;clip-path:circle(50%% at 50%% 50%%)!important;-webkit-clip-path:circle(50%% at 50%% 50%%)!important;}';(document.head||document.documentElement).appendChild(_v67);}"
           "function adVSem6067(e,lim){try{var s='',p=e,d=0;while(p&&d++<(lim||3)){var c=p.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));s+=' '+c+' '+String((p.getAttribute&&p.getAttribute('aria-label'))||(p.getAttribute&&p.getAttribute('title'))||'');p=p.parentElement;}return s;}catch(x){return '';}}"
           "function adVCtls6067(host,re,ban){try{var A=host&&host.querySelectorAll?host.querySelectorAll('button,[role=button],[aria-label],[title],svg,i,[class*=play],[class*=pause],[class*=mute],[class*=volume]'):[],O=[];for(var i=0;i<A.length&&i<180;i++){var e=A[i],sem=adVSem6067(e,3);if(ban&&ban.test(sem))continue;if(!re.test(sem))continue;var q=(e.closest&&e.closest('button,[role=button]'))||e,r=q.getBoundingClientRect();if(r.width<20||r.width>96||r.height<20||r.height>96)continue;if(O.indexOf(q)<0)O.push(q);}return O;}catch(x){return [];}}"
           "function adVAlpha6067(c){try{c=String(c||'').replace(/\s+/g,'').toLowerCase();if(!c||c==='transparent'||c==='rgba(0,0,0,0)')return 0;var m=c.match(/^rgba?\((\d+),(\d+),(\d+)(?:,([0-9.]+))?\)$/);return m?(m[4]===undefined?1:parseFloat(m[4])):1;}catch(x){return 0;}}"
           "function adVShell6067(q){try{if(!q)return null;var Q=[q],D=q.querySelectorAll?q.querySelectorAll('*'):[];for(var i=0;i<D.length&&i<24;i++)Q.push(D[i]);var best=null,score=-1;for(var j=0;j<Q.length;j++){var e=Q[j],r=e.getBoundingClientRect();if(r.width<24||r.width>86||r.height<24||r.height>86)continue;if(Math.abs(r.width-r.height)>12)continue;var cs=getComputedStyle(e),a=adVAlpha6067(cs.backgroundColor),rad=parseFloat(cs.borderTopLeftRadius)||0,sc=(rad>=Math.min(r.width,r.height)*.28?5:0)+(a>.02?2:0)-(Math.abs(r.width-r.height)/20)-(r.width/240);if(sc>score){score=sc;best=e;}}return best;}catch(x){return null;}}"
           "function adVPair6067(host,vr){try{var M=adVCtls6067(host,/mute|unmute|volume|sound/i,/play|pause|caption|fullscreen/i),P=adVCtls6067(host,/play|pause/i,/mute|volume|sound|caption|fullscreen/i);if(!M.length||!P.length)return null;var mute=null,mScore=1e15;for(var i=0;i<M.length;i++){var mr=M[i].getBoundingClientRect(),mx=mr.left+mr.width/2,my=mr.top+mr.height/2;if(mx<vr.left-24||mx>vr.right+24||my<vr.top-24||my>vr.bottom+24)continue;var rightPenalty=Math.max(0,(vr.left+vr.width*.58)-mx);var sc=rightPenalty*rightPenalty+Math.abs((vr.right)-mx);if(sc<mScore){mScore=sc;mute=M[i];}}if(!mute)return null;var mr=mute.getBoundingClientRect(),mx=mr.left+mr.width/2,my=mr.top+mr.height/2,play=null,pScore=1e15;for(var j=0;j<P.length;j++){var pr=P[j].getBoundingClientRect(),px=pr.left+pr.width/2,py=pr.top+pr.height/2,dx=Math.abs(px-mx),dy=Math.abs(py-my);if(px<vr.left-24||px>vr.right+24||py<vr.top-24||py>vr.bottom+24)continue;if(dx>110||dy>180)continue;var sc2=dx*dx+dy*dy+(py>my?2500:0);if(sc2<pScore){pScore=sc2;play=P[j];}}return play?{play:play,mute:mute}:null;}catch(x){return null;}}"
           "function adVScrub6067(q){try{if(!q)return; q.setAttribute('data-ad-native615','1');if(window.__AD_STRIP_DR615__)window.__AD_STRIP_DR615__(q);var E=[q],D=q.querySelectorAll?q.querySelectorAll('*'):[];for(var i=0;i<D.length&&i<36;i++)E.push(D[i]);for(var j=0;j<E.length;j++){var e=E[j],st=e.style;if(!st)continue;var f=String(st.getPropertyValue('filter')||'').replace(/\s+/g,'').toLowerCase();if(st.getPropertyPriority('filter')==='important'&&f==='brightness(0)invert(1)')st.removeProperty('filter');if(e.__adGlyph){delete e.__adGlyph;}var by=String(e.__adBy||'');if(/^gfix/.test(by)||by==='videoCtl6062')delete e.__adBy;if(e.removeAttribute){e.removeAttribute('data-ad-videoctl6062');e.removeAttribute('data-ad-videowrap6064');e.removeAttribute('data-ad-videostock6064');e.removeAttribute('data-ad-videoshell6065');e.removeAttribute('data-ad-videostock6065');e.removeAttribute('data-ad-videowrap6065');e.removeAttribute('data-ad-videowrap6066');e.removeAttribute('data-ad-videoshell6066');e.removeAttribute('data-ad-videoclip6066');}}}catch(x){}}"
           "function adVClearHost6067(q,shell){try{if(!q)return;var e=shell&&shell!==q?shell.parentElement:null,n=0;function clr(x){if(!x||x===shell)return;x.setAttribute('data-ad-videowrap6067','1');var st=x.style;if(!st)return;st.setProperty('background-color','transparent','important');st.setProperty('background-image','none','important');st.setProperty('box-shadow','none','important');st.setProperty('outline','none','important');st.setProperty('border-color','transparent','important');}clr(q);try{var qr=q.getBoundingClientRect();if(Math.abs(qr.width-qr.height)<=14)q.setAttribute('data-ad-videoclip6067','1');else q.removeAttribute('data-ad-videoclip6067');}catch(_q){}while(e&&e!==q&&n++<5){clr(e);e=e.parentElement;}if(e===q)clr(e);}catch(x){}}"
           "function adVMatchShells6067(play,mute){try{var ps=adVShell6067(play),ms=adVShell6067(mute);if(!ps||!ms)return 0;adVClearHost6067(play,ps);adVClearHost6067(mute,ms);var bg='rgba(255,255,255,0.38)';ps.style.setProperty('background-color',bg,'important');ms.style.setProperty('background-color',bg,'important');ps.style.setProperty('background-image','none','important');ms.style.setProperty('background-image','none','important');ps.style.setProperty('border-radius','50%%','important');ms.style.setProperty('border-radius','50%%','important');ps.style.setProperty('box-shadow','none','important');ms.style.setProperty('box-shadow','none','important');ps.setAttribute('data-ad-videoshell6067','1');ms.setAttribute('data-ad-videoshell6067','1');return 1;}catch(x){return 0;}}"
           "window.__AD_VIDEOSTOCK_ONE6067__=function(v){try{if(!v||String(v.tagName||'').toUpperCase()!=='VIDEO')return 0;var vr=v.getBoundingClientRect();if(vr.width<100||vr.height<70)return 0;var host=v,pd=0;while(host.parentElement&&pd++<4){var hp=host.parentElement,hr=hp.getBoundingClientRect();if(hr.width>=vr.width*.70&&hr.width<=vr.width*1.70&&hr.height>=vr.height*.70&&hr.height<=vr.height*1.75)host=hp;else break;}var pair=adVPair6067(host,vr);if(!pair)return 0;adVScrub6067(pair.play);adVScrub6067(pair.mute);pair.play.setAttribute('data-ad-videostock6067','1');pair.mute.setAttribute('data-ad-videostock6067','1');return adVMatchShells6067(pair.play,pair.mute);}catch(e){return 0;}};"
           "window.__AD_VIDEOSTOCK6067__=function(root){try{var V=[],n=0;function addFrom(b){if(!b)return;try{if(String(b.tagName||'').toUpperCase()==='VIDEO'&&V.indexOf(b)<0)V.push(b);var q=b.querySelectorAll?b.querySelectorAll('video'):[];for(var i=0;i<q.length&&V.length<36;i++)if(V.indexOf(q[i])<0)V.push(q[i]);}catch(x){}}addFrom(root);if(!V.length&&root&&root.nodeType===1){var p=root.parentElement,d=0;while(p&&d++<4&&!V.length){addFrom(p);p=p.parentElement;}}if(!V.length&&root===document)addFrom(document);for(var j=0;j<V.length&&j<36;j++)n+=window.__AD_VIDEOSTOCK_ONE6067__(V[j]);return n;}catch(e){return 0;}};"
           "var vcs67=function(ev){try{var t=ev&&ev.target;if(t&&String(t.tagName||'').toUpperCase()==='VIDEO'){window.__AD_VIDEOSTOCK_ONE6067__(t);setTimeout(function(){window.__AD_VIDEOSTOCK_ONE6067__(t);},90);}}catch(e){}};document.addEventListener('loadedmetadata',vcs67,true);document.addEventListener('loadeddata',vcs67,true);document.addEventListener('canplay',vcs67,true);document.addEventListener('play',vcs67,true);document.addEventListener('playing',vcs67,true);document.addEventListener('pause',vcs67,true);"
           "document.addEventListener('click',function(ev){try{var p=ev&&ev.target,d=0,sem='';while(p&&d++<4){var c=p.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));sem+=' '+c+' '+String((p.getAttribute&&p.getAttribute('aria-label'))||(p.getAttribute&&p.getAttribute('title'))||'');p=p.parentElement;}if(!/play|pause|mute|unmute|volume|sound/i.test(sem)||/caption|fullscreen/i.test(sem))return;setTimeout(function(){window.__AD_VIDEOSTOCK6067__(document);},0);setTimeout(function(){window.__AD_VIDEOSTOCK6067__(document);},120);}catch(e){}},true);"
           "var vis67=function(){try{window.__AD_VIDEOSTOCK6067__(document);}catch(e){}};if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',vis67,{once:true});else vis67();window.addEventListener('pageshow',vis67,{passive:true});}catch(e){}"
         // v6.0.36: seasonal Home mosaic cards are normal dark-theme chrome, not TWB.
         // v5.446 proved the stable owner is the hp-mosaic/widget family; the visible
         // campaign heading ("Off to College", holiday, etc.) is content and must not
         // be the selector. Reuse the existing contrast lifecycle with bounded local
         // card passes -- no observer, scroll callback or recurring timer is added.
         "try{if(!document.getElementById('adseasonal6036')){var c36=document.createElement('style');c36.id='adseasonal6036';"
           "c36.textContent='[data-ad-seasonal6036],[data-ad-seasonal-card6036]{background-color:var(--ad-seasonal6036-bg,#181a1b)!important;filter:none!important;mix-blend-mode:normal!important;opacity:1!important;box-shadow:none!important;border-color:#3b4043!important;}[data-ad-seasonal6036],[data-ad-seasonal6036] h1,[data-ad-seasonal6036] h2,[data-ad-seasonal6036] h3,[data-ad-seasonal6036] h4,[data-ad-seasonal6036] h5,[data-ad-seasonal6036] h6,[data-ad-seasonal6036] p,[data-ad-seasonal6036] a,[data-ad-seasonal6036] span,[data-ad-seasonal6036] strong,[data-ad-seasonal6036] small{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}[data-ad-seasonal6036] .a-icon-next-rounded,[data-ad-seasonal6036] .a-icon-previous-rounded,[data-ad-seasonal6036] [class*=chevron],[data-ad-seasonal6036] [class*=arrow]{color:#e8e6e3!important;filter:brightness(0) invert(1)!important;opacity:1!important;}[data-ad-seasonal6036] svg,[data-ad-seasonal6036] path{fill:#e8e6e3!important;stroke:#e8e6e3!important;}';"
           "(document.head||document.documentElement).appendChild(c36);}}catch(e){}"
         "window.__AD_SEASONAL6036__=function(root){try{if(window.top!==window||!document.body)return 0;"
           "function appbg(){var A=[document.body,document.documentElement];for(var z=0;z<A.length;z++){if(!A[z])continue;var c=String(getComputedStyle(A[z]).backgroundColor||'').replace(/\\s+/g,'');if(c&&c!=='transparent'&&c!=='rgba(0,0,0,0)')return c;}return 'rgb(24,26,27)';}"
           "function cn(e){var c=e&&e.className;if(c&&c.baseVal!==undefined)c=c.baseVal;return String(c||'').toLowerCase();}"
           "var SEL='[class*=hp-mosaic-container],[class*=_mosaic-container_style_widgetContainer]';"
           "function pin(pane,scope){try{if(!pane||!pane.isConnected)return 0;var bg=appbg(),R=pane.getBoundingClientRect(),n=1;pane.setAttribute('data-ad-seasonal6036','1');pane.setAttribute('data-ad-college6034','1');pane.style.setProperty('--ad-seasonal6036-bg',bg);pane.style.setProperty('background-color',bg,'important');pane.style.setProperty('filter','none','important');pane.style.setProperty('mix-blend-mode','normal','important');pane.style.setProperty('box-shadow','none','important');pane.style.setProperty('border-color','#3b4043','important');var K=[],src=(scope&&scope.nodeType===1&&pane.contains(scope))?scope:null,L=null,lim=360;if(src&&src!==pane){K.push(src);L=src.getElementsByTagName?src.getElementsByTagName('*'):[];lim=64;}else{L=pane.getElementsByTagName?pane.getElementsByTagName('*'):[];}for(var z=0;z<L.length&&K.length<lim;z++)K.push(L[z]);for(var i=0;i<K.length;i++){var e=K[i],tg=String(e.tagName||'').toUpperCase();if(!/^(DIV|SECTION|ARTICLE|UL|OL|LI|A)$/.test(tg))continue;var r=e.getBoundingClientRect();if(r.width<72||r.height<42||r.width>Math.max((innerWidth||390)*1.08,R.width*1.08))continue;var cs=getComputedStyle(e),bc=String(cs.backgroundColor||'').replace(/\\s+/g,''),bi=String(cs.backgroundImage||'none'),cl=cn(e),hasColor=!!(bc&&bc!=='transparent'&&bc!=='rgba(0,0,0,0)'),hasGrad=bi.indexOf('gradient(')>=0&&bi.indexOf('url(')<0;if(!hasColor&&!hasGrad)continue;var cardish=/mosaic|card|pane|tile|container|widget|asin|grid|product/.test(cl)||(r.width>=R.width*.36&&r.height>=80);if(!cardish)continue;e.setAttribute('data-ad-seasonal-card6036','1');e.setAttribute('data-ad-college-card6034','1');e.style.setProperty('--ad-seasonal6036-bg',bg);e.style.setProperty('background-color',bg,'important');if(hasGrad)e.style.setProperty('background-image','none','important');e.style.setProperty('filter','none','important');e.style.setProperty('mix-blend-mode','normal','important');e.style.setProperty('box-shadow','none','important');e.style.setProperty('border-color','#3b4043','important');n++;}return n;}catch(x){return 0;}}"
           "var B=(root&&root.nodeType===1)?root:document,R=[],q=null;function add(e){if(e&&R.indexOf(e)<0&&R.length<24)R.push(e);}"
           "if(B!==document){try{if(B.matches&&B.matches(SEL))add(B);if(B.closest)add(B.closest(SEL));}catch(x){}}"
           "try{q=B.querySelectorAll?B.querySelectorAll(SEL):[];for(var i=0;i<q.length&&i<24;i++)add(q[i]);}catch(x){}"
           // Heading fallback is retained only for an Amazon class rename; normal
           // ownership never depends on campaign copy.
           "if(!R.length&&B===document){var Q=document.getElementsByTagName('h2'),H=null;for(var h=0;h<Q.length&&h<120;h++){var t=String(Q[h].textContent||'').replace(/\\s+/g,' ').trim().toLowerCase();if(t==='off to college'){H=Q[h];break;}}if(H){var P=H.parentElement,d=0,vw=innerWidth||390;while(P&&d++<10){var rr=P.getBoundingClientRect();if(rr.width>=vw*.82&&rr.height>=150&&rr.height<=1000){add(P);break;}P=P.parentElement;}}}"
           "var total=0;for(var j=0;j<R.length;j++){var local=(B!==document&&R[j]!==B&&R[j].contains&&R[j].contains(B))?B:null;total+=pin(R[j],local);}window.__AD_SEASONAL6036_STATE__='roots='+R.length+' paint='+total;return total;}catch(e){window.__AD_SEASONAL6036_STATE__='err '+(e&&e.message||e);return 0;}};"
         // Existing call sites and the direct-TWB structural skip use the old symbol/
         // marker names; aliasing them keeps those proven paths intact.
         "window.__AD_COLLEGE6034__=window.__AD_SEASONAL6036__;"
         "%@\n" // DarkReader UMD
         "if(window.DarkReader&&DarkReader.enable){"
         "try{DarkReader.setFetchMethod(window.fetch);}catch(e){}"
         // WCAG contrast repair. Dark Reader recolours from the page's own palette,
         // which can leave text only marginally separated from its background - the
         // '% off' badges and the descriptions under product photos being the
         // reported cases. This measures the real computed contrast of every element
         // that owns visible text and lifts ONLY the ones that actually fail, so
         // brand colours that already read fine are untouched.
         "window.__AMZDARK_FIXCONTRAST__=function(root){try{var base=(root&&root.nodeType===1)?root:(document.body||document.documentElement);"
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
           // v6.0.56: contrast repair is fallback work, not the primary painter.  Bound
           // mutation-local passes so one huge hydrated subtree cannot monopolize WebKit.
           "var cap=(base===document.body||base===document.documentElement)?1400:((window.__AD_IS_NATIVE615__&&window.__AD_IS_NATIVE615__(base))?120:360);"
           "function collect(root,out,depth){try{if(out.length>=cap)return out;"
             "var list=root.querySelectorAll('*');"
             "for(var a=0;a<list.length&&out.length<cap;a++){var e=list[a];out.push(e);"
               // Shadow roots are separate trees: querySelectorAll stops at the host.
               "if(e.shadowRoot&&depth<4&&out.length<cap)collect(e.shadowRoot,out,depth+1);}"
             "}catch(e){}return out;}"
           "var els=[base];collect(base,els,0);var n=0,bfix=0,lfix=0,gfix=0;"           // Read the themed background off <html> rather than plumbing another
           // format argument through two call sites.
           "var BG='rgb(24,26,27)';try{var hb=getComputedStyle(document.documentElement).backgroundColor;"
             "var hl=lum(hb);if(hl!==null&&hl<0.25)BG=hb;}catch(e){}"
           // v6.0.10: v5.446/v5.439 dependency restoration. The exact 23px
           // a-icon-checkbox was being claimed by the generic glyph repair before
           // stockCheckbox434 could own it. Protect the native checkbox/Compare
           // subtree from every broad glyph writer; stockCheckbox434 remains sole owner.
           "function adCbx439(e9){try{return !!(e9&&e9.closest&&e9.closest('[class*=a-checkbox],[class*=a-icon-checkbox],input[type=checkbox],[role=checkbox],[class*=copilot-compare],button[aria-label*=ompare],[data-csa-c-content-id*=ompare]'));}catch(err){return true;}}"
           // v6.0.16 / v5.446: small round content bitmaps are not monochrome UI glyphs.
           // Keep the class reject broad and do ancestry/bitmap checks only on tiny <img>
           // candidates immediately before a glyph write.
           "var SKIP=/star|prime|logo|flag|swatch|thumb|sponsor|pill-image|product-image|photo|heart|wish|lists-framework|mlt-icon-container|avatar|profile|author|reviewer|byline|merchant|seller|brand|store|logo-|-logo|headshot|user-image|customer/i;"
           "var CONTENTIMG616='[data-hook*=review],[class*=review],[class*=profile],[class*=avatar],[class*=author],[class*=byline],[class*=merchant],[class*=seller],[class*=brand],[class*=store],[id*=review]';"
           // v6.0.90: Amazon's search-result feature badges (Works with Alexa,
           // recycled-material / carbon-impact marks, etc.) are tiny full-colour IMG
           // assets next to short product metadata text. Some recycled rows omit alt
           // text, so v6.0.16's narrow contentImg616 guard let the generic gfix1 lane
           // treat the same opaque bitmap as a monochrome UI glyph. brightness(0)+
           // invert(1) then turns every opaque pixel white, producing the exact blank
           // white square seen on-device. Restore the v5.446 product-art principle at
           // this leaf only: a tiny IMG in a non-interactive product metadata row is
           // authored content, not chrome. No new traversal is introduced; this runs
           // only for the already-visited tiny IMG candidate.
           "var PRODUCTCTX6090='[data-component-type=s-search-result],[class*=s-result-item],[class*=puis-card],[data-asin],[class*=s-product-image],[class*=product-image],[class*=faceout],[class*=gwm],[class*=cardui]';"
           "function productBadgeImg6094(e,r){try{if(!e||!e.closest||!e.closest(PRODUCTCTX6090))return false;"
             // v6.0.93 lifecycle probe named the failing renderer exactly:
             // IMG.s-image inside .s-pc-certification-faceout, usually wrapped by an
             // A role=button.  v6.0.90 rejected that wrapper as interactive before it
             // could classify the bitmap as content, then gfix1 whitened the entire
             // opaque PNG.  Exact certification/faceout ancestry wins before the UI
             // control reject; the surrounding chevron/control remains untouched.
             "if(e.closest('.s-pc-certification-faceout,.s-pc-faceout-container,[data-cy=s-pc-faceout-badge]'))return true;"
             "if(e.closest('button,[role=button],input,[class*=a-checkbox],[class*=a-icon-checkbox],[class*=puis-heart-position],[class*=lists-framework-action-button],[class*=mlt-icon-container],[data-action]'))return false;"
             "if(!r||r.width<8||r.height<8||r.width>48||r.height>48)return false;"
             "var p=e.parentElement,d=0;while(p&&d++<4){var pr=p.getBoundingClientRect();"
               "var tx=String(p.textContent||'').replace(/\\s+/g,' ').trim();"
               "if(tx.length>=3&&tx.length<=180&&pr.height>0&&pr.height<=64&&pr.width>=r.width*1.8)return true;"
               "if(p.matches&&p.matches(PRODUCTCTX6090))break;p=p.parentElement;}"
             "return false;}catch(x){return false;}}"
           "function contentImg616(e,r,cs){try{if(!e||String(e.tagName||'').toLowerCase()!=='img')return false;"
             "var al=(e.getAttribute&&e.getAttribute('alt')||'').trim();if(al.length>1)return true;"
             "if(e.closest&&e.closest(CONTENTIMG616))return true;"
             "if(productBadgeImg6094(e,r))return true;"
             "var brs=String((cs&&cs.borderRadius)||''),br=parseFloat(brs)||0,pct=brs.indexOf('%%')>=0;"
             "var circ=pct?br>=40:br>=Math.min(r.width,r.height)*0.4;"
             "if(circ&&((e.naturalWidth||0)>64||(e.naturalHeight||0)>64))return true;"
           "}catch(x){}return false;}"           // Classes the probe confirmed are monochrome UI glyphs. These get a
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
           // v6.0.82: Home product-copy bridge for Amazon-owned/native ad islands.
           // v6.0.15 intentionally keeps these islands out of broad Dark Reader/contrast
           // ownership, but some current recommendation widgets use the same family for
           // ordinary product cards. Their black title/price leaves therefore never reach
           // the generic contrast writer. Reuse this already-bounded traversal and lift
           // only dark-neutral DIRECT text that belongs to a real product card and does
           // not overlap product artwork. No extra DOM scan/observer is introduced.
           "function prodInk6078(e){try{if(!e||!e.childNodes)return 0;"
             "var tg=String(e.tagName||'').toUpperCase();if(!/^(?:A|SPAN|DIV|P|H1|H2|H3|H4|H5|STRONG|SMALL|SUP|B|EM)$/.test(tg))return 0;"
             "var own='';for(var q=0;q<e.childNodes.length&&q<10;q++){var nd=e.childNodes[q];if(nd.nodeType===3)own+=String(nd.nodeValue||'');}"
             "own=own.replace(/\s+/g,' ').trim();if(!own||own.length>320)return 0;"
             "function neutral6078(v){var m=/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)/.exec(String(v||''));if(!m)return false;var mx=Math.max(+m[1],+m[2],+m[3]),mn=Math.min(+m[1],+m[2],+m[3]);return (mx-mn)<48;}"
             "var cs=getComputedStyle(e),cl=lum(cs.color),fc=String(cs.webkitTextFillColor||''),fl=lum(fc);"
             "if(!((cl!==null&&cl<0.48&&neutral6078(cs.color))||(fl!==null&&fl<0.48&&neutral6078(fc))))return 0;"
             "var bl=bgOf(e);if(bl===null||bl>0.35)return 0;"
             "var p=e,card=null,d=0;while(p&&d++<7){var r=p.getBoundingClientRect();if(r.width>=120&&r.width<=540&&r.height>=120&&r.height<=760&&p.querySelector){"
               "var ph=null,im=null;try{ph=p.querySelector('a[href*=\"/dp/\"],a[href*=\"/gp/product/\"],[data-asin]');im=p.querySelector('img,picture');}catch(z){}"
               "if(ph&&im){card=p;break;}}p=p.parentElement;}if(!card)return 0;"
             "var er=e.getBoundingClientRect(),imgs=card.getElementsByTagName?card.getElementsByTagName('img'):[],saw=0;"
             "for(var j=0;j<imgs.length&&j<10;j++){var ir=imgs[j].getBoundingClientRect();if(ir.width<70||ir.height<70)continue;saw++;var ow=Math.min(er.right,ir.right)-Math.max(er.left,ir.left),oh=Math.min(er.bottom,ir.bottom)-Math.max(er.top,ir.top);if(ow>0&&oh>0&&((ow*oh)/Math.max(1,er.width*er.height))>0.18)return 0;}"
             "if(!saw)return 0;var a=e,ad=0;while(a&&a!==card.parentElement&&ad++<6){var bi=String(getComputedStyle(a).backgroundImage||'none');if(bi.indexOf('url(')>=0)return 0;a=a.parentElement;}"
             "e.style.setProperty('color',FG,'important');e.style.setProperty('-webkit-text-fill-color',FG,'important');e.setAttribute('data-ad-productink6078','1');return 1;"
           "}catch(x){return 0;}}"
           // v6.0.138: semantic Sponsored bridge. This reuses the existing bounded
           // contrast traversal instead of adding another document scan. It also
           // identifies Sponsor ancestry so generic glyph whitening cannot repaint
           // Amazon's stock info artwork.
           "function adSponsorText6138(e){try{if(!e||!e.childNodes)return false;var t='';for(var si=0;si<e.childNodes.length&&si<12;si++){var sn=e.childNodes[si];if(sn.nodeType===3)t+=' '+String(sn.nodeValue||'');}t=t.replace(/\s+/g,' ').trim();return /^sponsored(?: ad)?$/i.test(t);}catch(x){return false;}}"
           "function adSponsorCtx6138(e){try{var p=e,d=0;while(p&&d++<4){var c=p.className;if(c&&c.baseVal!==undefined)c=c.baseVal;var z=(String(c||'')+' '+String(p.id||'')).toLowerCase();if(/sponsor|ad-feedback|adfeedback|ape-feedback/.test(z)||adSponsorText6138(p))return true;var tx=String(p.textContent||'').replace(/\s+/g,' ').trim();if(tx.length<=120&&/\bsponsored(?: ad)?\b/i.test(tx))return true;p=p.parentElement;}return false;}catch(x){return false;}}"
           // Keep Amazon's stock info artwork. Only color-driven glyph implementations
           // are bridged to the same secondary gray; background-image sprites are left
           // byte-for-byte stock and merely protected from generic inversion.
           "function adSponsorGlyph6138(e){try{if(!e||e.nodeType!==1||adSponsorText6138(e)||!adSponsorCtx6138(e))return false;var r=e.getBoundingClientRect();if(r.width<5||r.height<5||r.width>30||r.height>30)return false;var cs=getComputedStyle(e),c=e.className;if(c&&c.baseVal!==undefined)c=c.baseVal;var z=(String(c||'')+' '+String(e.id||'')+' '+String((e.getAttribute&&e.getAttribute('aria-label'))||'')+' '+String((e.getAttribute&&e.getAttribute('title'))||'')).toLowerCase(),tg=String(e.tagName||'').toUpperCase(),bi=String(cs.backgroundImage||'none'),mi=String(cs.webkitMaskImage||cs.maskImage||'none'),pb=null,pa=null,pc=false;try{pb=getComputedStyle(e,'::before');pa=getComputedStyle(e,'::after');pc=(pb&&pb.content&&pb.content!=='none'&&pb.content!=='normal')||(pa&&pa.content&&pa.content!=='none'&&pa.content!=='normal');}catch(q){}var known=/ad-feedback-spr|feedback.*(?:spr|icon)|(?:sponsor|info).*icon|icon.*info/.test(z),vector=(tg==='SVG'||tg==='PATH'||(e.namespaceURI==='http://www.w3.org/2000/svg'));if(!known&&!vector&&mi==='none'&&bi==='none'&&!pc)return false;e.setAttribute('data-ad-sponsorglyph6138','1');e.style.setProperty('opacity','1','important');e.style.setProperty('visibility','visible','important');e.style.setProperty('mix-blend-mode','normal','important');if(mi!=='none'){e.style.setProperty('background-color','#b1aaa0','important');e.style.setProperty('filter','none','important');}else if(vector){var f=lum(cs.fill),st=lum(cs.stroke);e.style.setProperty('color','#b1aaa0','important');if(f!==null&&f<0.55)e.style.setProperty('fill','#b1aaa0','important');if(st!==null&&st<0.55)e.style.setProperty('stroke','#b1aaa0','important');e.style.setProperty('filter','none','important');}else if(bi==='none'){e.style.setProperty('color','#b1aaa0','important');e.style.setProperty('-webkit-text-fill-color','#b1aaa0','important');e.style.setProperty('filter','none','important');}else{e.style.setProperty('filter','none','important');}return true;}catch(x){return false;}}"
           "for(var i=0;i<els.length;i++){var el=els[i];"
             "if(adSponsorText6138(el)){el.setAttribute('data-ad-sponsorgray6138','1');el.style.setProperty('color','#b1aaa0','important');el.style.setProperty('-webkit-text-fill-color','#b1aaa0','important');el.style.setProperty('opacity','1','important');el.style.setProperty('visibility','visible','important');continue;}"
             "if(adSponsorGlyph6138(el))continue;"
             "if(window.__AD_IS_NATIVE615__&&window.__AD_IS_NATIVE615__(el)){n+=prodInk6078(el);continue;}"
             "var cs=getComputedStyle(el);"
             // v6.0.94: if a recycled product-badge IMG was previously claimed by
             // gfix1 earlier in this same WebView, release that stale inline filter
             // before the normal glyph gate runs again. This is O(1) and only does
             // geometry/ancestry work on elements already marked as a generic glyph.
             "try{if(el.__adGlyph&&/^gfix/.test(String(el.__adBy||''))&&String(el.tagName||'').toLowerCase()==='img'){"
               "var hr6090=el.getBoundingClientRect();if(contentImg616(el,hr6090,cs)){el.style.removeProperty('filter');el.__adGlyph=0;el.__adBy='productBadge6094';}}}catch(h6090){}"
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
               "if(gr.width>5&&gr.width<=lim&&gr.height>5&&gr.height<=lim&&!SKIP.test(cn2)&&!ot&&!adSponsorCtx6138(el)){"
                 "var isI=el.tagName.toLowerCase()==='img';"
                 // v5.446 device-proven case: a 32pt circular shop/avatar bitmap backed
                 // by a larger source was being silhouetted into a solid white disc.
                 // Run this only after the existing size/class/text gates.
                 "if(isI&&contentImg616(el,gr,cs))continue;"
                 "var hasB=cs.backgroundImage&&cs.backgroundImage!=='none';"
                 "if(isI||hasB){if(adCbx439(el))continue;el.style.setProperty('filter','brightness(0) invert(1)','important');"
                   "el.__adGlyph=1;el.__adBy='gfix1';gfix++;}}"
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
                   "var SK2=/star|prime|logo|flag|swatch|thumb|sponsor|pill-image|product-image|photo|avatar|profile|author|reviewer|byline|merchant|seller|brand|store|headshot|user-image|customer/i;"
                   "if(sr3.width>5&&sr3.width<=slim&&sr3.height>5&&sr3.height<=slim&&!SK2.test(sc3)&&!adSponsorCtx6138(el)){"
                     "if(adCbx439(el))continue;"
                     "el.style.setProperty('filter','brightness(0) invert(1)','important');el.__adGlyph=1;el.__adBy='gfix2';gfix++;}"
                 "}catch(e){}}"
               "if(!adSponsorCtx6138(el)){var fl2=lum(cs.fill),sl=lum(cs.stroke);"
               "if(fl2!==null&&fl2<0.22){el.style.setProperty('fill',FG,'important');n++;}"
               "if(sl!==null&&sl<0.22){el.style.setProperty('stroke',FG,'important');n++;}}"
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
               "if((hasC(pb)||hasC(pa))&&n<400&&!adSponsorCtx6138(el)){var pcl=lum(cs.color);"
                 "if(pcl!==null&&pcl<0.50){el.style.setProperty('color',FG,'important');n++;}}"
             "}catch(e){}"
             // MASK-IMAGE ICONS. The mask is the shape; the visible colour is the
             // element's background-color. Dark Reader treats that as a background and
             // darkens it, which paints the glyph in the page background colour - i.e.
             // makes it vanish rather than merely stay dark.
             "try{var mi=cs.webkitMaskImage||cs.maskImage;"
               "if(mi&&mi!=='none'&&n<400&&!adSponsorCtx6138(el)){var mbl=lum(cs.backgroundColor);"
                 "if(mbl!==null&&mbl<0.55){el.style.setProperty('background-color',FG,'important');n++;}}"
             "}catch(e){}"
             "try{if(n<400&&!adSponsorCtx6138(el)){var g3=el.getBoundingClientRect();"
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
           "try{var HRT=[],HS='[class*=heart],[class*=wish],[class*=lists-framework]';if(base.matches&&base.matches(HS))HRT.push(base);var HQ=base.querySelectorAll?base.querySelectorAll(HS):[];for(var hq=0;hq<HQ.length&&hq<240;hq++)HRT.push(HQ[hq]);"
             "for(var hz=0;hz<HRT.length;hz++){var he=HRT[hz];if(window.__AD_IS_NATIVE615__&&window.__AD_IS_NATIVE615__(he))continue;var hcs=getComputedStyle(he);"
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
         // v6.0.56: keep Dark Reader + document-start CSS on the critical path, but
         // move fallback contrast/seasonal repair to browser idle time.  This protects
         // Amazon's hydration/network completion and the 8.3 ms ProMotion frame budget.
         "window.__AD_IDLE6056__=function(fn,to){try{if(window.requestIdleCallback)return requestIdleCallback(function(){try{fn();}catch(e){}},{timeout:to||240});return setTimeout(function(){try{fn();}catch(e){}},60);}catch(e){return setTimeout(fn,60);}};"
         "window.__AMZDARK_APPLY__=function(){try{"
           "if(!document.querySelector('style.darkreader'))DarkReader.enable(%@,%@);"
           "if(window.__AD_MARK_NATIVE615__)window.__AD_MARK_NATIVE615__(document);"
           "window.__AD_IDLE6056__(function(){window.__AMZDARK_FIXCONTRAST__();if(window.__AD_COLLEGE6034__)window.__AD_COLLEGE6034__(document);},260);"
         "}catch(e){}};"
         // v6.0.131 PROBE: v6.0.128 did not change either standalone-ad symptom,
         // so stop guessing at the shell/path.  Dump exact live Sponsored label,
         // info-glyph, ad-root, media, iframe and TWB ownership only when the app is
         // backgrounded.  The existing MutationObserver hook remains a no-op here:
         // no new observer, timer, scroll hook, RAF, interval or steady-state scan.
         "window.__AD_STANDAD6129__=[];"
         "function sapS6129(v,n){v=String(v==null?'':v);return v.length>(n||180)?v.slice(0,n||180):v;}"
         "function sapCls6129(e){try{var c=e&&e.className;return sapS6129(c&&c.baseVal!==undefined?c.baseVal:(c||''),240);}catch(x){return'';}}"
         "function sapN6129(e){try{if(!e||e.nodeType!==1)return null;var c=getComputedStyle(e),b=getComputedStyle(e,'::before'),a=getComputedStyle(e,'::after'),r=e.getBoundingClientRect();return{tag:String(e.tagName||''),cl:sapCls6129(e),id:sapS6129(e.id||'',100),r:[Math.round(r.x),Math.round(r.y),Math.round(r.width),Math.round(r.height)],txt:sapS6129(String(e.textContent||'').replace(/\\s+/g,' ').trim(),150),role:sapS6129(e.getAttribute&&e.getAttribute('role'),80),aria:sapS6129(e.getAttribute&&e.getAttribute('aria-label'),120),title:sapS6129(e.getAttribute&&e.getAttribute('title'),120),src:sapS6129(e.currentSrc||e.src||(e.getAttribute&&e.getAttribute('data-src'))||'',220),by:sapS6129(e.__adBy||'',90),twb:String((e.getAttribute&&e.getAttribute('data-ad-twb6033'))||''),twbbg:String((e.getAttribute&&e.getAttribute('data-ad-twb-bg6033'))||''),native:String((e.getAttribute&&e.getAttribute('data-ad-native615'))||''),style:sapS6129(e.getAttribute&&e.getAttribute('style'),260),css:{d:sapS6129(c.display,40),v:sapS6129(c.visibility,40),op:sapS6129(c.opacity,40),f:sapS6129(c.filter,120),col:sapS6129(c.color,80),fill:sapS6129(c.fill,80),stroke:sapS6129(c.stroke,80),bg:sapS6129(c.backgroundColor,90),bgi:sapS6129(c.backgroundImage,240),mask:sapS6129(c.webkitMaskImage||c.maskImage,240),bs:sapS6129(c.boxShadow,180),bd:sapS6129(c.border,140),blend:sapS6129(c.mixBlendMode,60)},bef:{ct:sapS6129(b.content,90),bg:sapS6129(b.backgroundColor,90),bgi:sapS6129(b.backgroundImage,220),mask:sapS6129(b.webkitMaskImage||b.maskImage,220),f:sapS6129(b.filter,120),col:sapS6129(b.color,80),bs:sapS6129(b.boxShadow,140)},aft:{ct:sapS6129(a.content,90),bg:sapS6129(a.backgroundColor,90),bgi:sapS6129(a.backgroundImage,220),mask:sapS6129(a.webkitMaskImage||a.maskImage,220),f:sapS6129(a.filter,120),col:sapS6129(a.color,80),bs:sapS6129(a.boxShadow,140)}};}catch(x){return{err:String(x)}}}"
         "function sapChain6129(e,lim){var A=[];try{var p=e,d=0;while(p&&d++<(lim||9)){A.push(sapN6129(p));p=p.parentElement;}}catch(x){}return A;}"
         "function sapNear6129(label){var A=[];try{var lr=label.getBoundingClientRect(),root=label.parentElement||label,Q=root.querySelectorAll?root.querySelectorAll('i,svg,path,img,span,div,button,[role=button]'):[];for(var i=0;i<Q.length&&i<90&&A.length<20;i++){var e=Q[i];if(e===label)continue;var r=e.getBoundingClientRect();if(r.width<5||r.height<5||r.width>46||r.height>46)continue;var cx=r.left+r.width/2,cy=r.top+r.height/2,lcy=lr.top+lr.height/2;if(Math.abs(cy-lcy)>34||cx<lr.left-50||cx>lr.right+90)continue;var cs=getComputedStyle(e),mi=String(cs.webkitMaskImage||cs.maskImage||'none'),bi=String(cs.backgroundImage||'none'),cl=sapCls6129(e);if(/info|feedback|sponsor|icon|sprite/i.test(cl)||mi!=='none'||bi!=='none'||/^(I|SVG|PATH|IMG)$/.test(String(e.tagName||'')))A.push(sapN6129(e));}}catch(x){}return A;}"
         "function sapRoot6129(label){try{var p=label,d=0,best=null;while(p&&d++<11){var r=p.getBoundingClientRect();if(r.width>=220&&r.height>=42&&r.height<=420)best=p;if(r.width>=(innerWidth||390)*.88&&r.height>=48){best=p;break;}p=p.parentElement;}return best;}catch(x){return null;}}"
         "function sapMedia6129(root){var A=[];try{if(!root)return A;var Q=root.querySelectorAll?root.querySelectorAll('img,video,canvas,iframe,[data-ad-twb6033],[data-ad-twb-bg6033]'):[];for(var i=0;i<Q.length&&i<120&&A.length<36;i++){var e=Q[i],r=e.getBoundingClientRect();if(r.width<10||r.height<10)continue;A.push(sapN6129(e));}}catch(x){}return A;}"
         "function sapDump6129(){try{var out={url:String(location.href),top:(window.top===window),wh:[innerWidth||0,innerHeight||0],home:!!(document.documentElement&&document.documentElement.hasAttribute('data-ad-twb-home6033')),labels:[],frames:[],twb:[]};var W=document.createTreeWalker(document.body||document.documentElement,NodeFilter.SHOW_TEXT),nd,seen=0;while((nd=W.nextNode())&&seen++<9000&&out.labels.length<24){var t=String(nd.nodeValue||'').replace(/\\s+/g,' ').trim();if(!/^sponsored(?: ad)?$/i.test(t))continue;var e=nd.parentElement;if(!e)continue;var r=e.getBoundingClientRect();if(r.width<18||r.height<5||r.bottom<-80||r.top>(innerHeight||900)+120)continue;var root=sapRoot6129(e);out.labels.push({text:t,label:sapN6129(e),chain:sapChain6129(e,10),near:sapNear6129(e),root:root?sapN6129(root):null,media:sapMedia6129(root)});}var F=document.getElementsByTagName('iframe');for(var i=0;i<F.length&&out.frames.length<18;i++){var f=F[i],fr=f.getBoundingClientRect();if(fr.width<80||fr.height<24)continue;out.frames.push({frame:sapN6129(f),chain:sapChain6129(f,8)});}var T=document.getElementsByTagName?document.getElementsByTagName('*'):[];for(var j=0;j<T.length&&out.twb.length<50;j++){var z=T[j];if(!(z.hasAttribute&&((z.hasAttribute('data-ad-twb6033'))||(z.hasAttribute('data-ad-twb-bg6033')))))continue;var zr=z.getBoundingClientRect();if(zr.width<20||zr.height<20||zr.bottom<-100||zr.top>(innerHeight||900)+160)continue;out.twb.push(sapN6129(z));}window.__AD_STANDAD6129__.push(out);if(window.__AD_STANDAD6129__.length>8)window.__AD_STANDAD6129__.shift();return JSON.stringify(out);}catch(e){return 'ERR '+String(e);}}"
         "window.__AD_STANDAD6129_DUMP__=sapDump6129;"
         "window.__AD_FLASH6101_DUMP__=sapDump6129;"
         // Re-run fallback repair as lazy content arrives, but never synchronously in
         // the MutationObserver. v6.0.82 no longer discards native-ad descendants here:
         // __AMZDARK_FIXCONTRAST__ routes every such element through prodInk6078 and
         // continues before generic paint. Native-local roots are capped at 120.
         // Coalesce nested roots and let WebKit finish rendering.
         // v6.0.118: Search first-open path parity. Background/foreground already
         // proves the settled generic glyph repair is correct because visibility regain
         // calls __AMZDARK_APPLY__(), which runs a FULL-root FIXCONTRAST pass. The
         // initial lazy-content path only repaired each added subtree, so Amazon could
         // finish a clock/X/magnifier painter on an existing node after that local pass
         // and leave it dark until the lifecycle repair. Reuse this SAME observer,
         // debounce and idle callback: when a real Search-suggestion family enters the
         // DOM, promote that one coalesced batch to the exact full-root repair path.
         // No new observer, timer, interval, RAF, scroll listener or recurring scan.
         "try{var _t=null,_roots=[],_idle=0,_searchFull6118=0;"
         "function search6118(n){try{if(!n||n.nodeType!==1)return false;var S='.s-suggestion,.s-suggestion-container,[class*=recentSearch],[class*=search-suggestion]';return !!((n.matches&&n.matches(S))||(n.closest&&n.closest(S))||(n.querySelector&&n.querySelector(S)));}catch(e){return false;}}"
         "function run6056(){_idle=0;try{var R=_roots,full=_searchFull6118;_roots=[];_searchFull6118=0;if(full){var d=document.body||document.documentElement;window.__AMZDARK_FIXCONTRAST__(d);if(window.__AD_COLLEGE6034__)window.__AD_COLLEGE6034__(document);return;}for(var i=0;i<R.length;i++){var r=R[i];if(!r||!r.isConnected)continue;var nested=false;for(var j=0;j<R.length;j++){if(i!==j&&R[j]&&R[j].contains&&R[j].contains(r)){nested=true;break;}}if(!nested){window.__AMZDARK_FIXCONTRAST__(r);if(window.__AD_COLLEGE6034__)window.__AD_COLLEGE6034__(r);}}}catch(e){}}new MutationObserver(function(ms){try{for(var mi=0;mi<ms.length&&_roots.length<12;mi++){var A=ms[mi].addedNodes||[];for(var ai=0;ai<A.length&&_roots.length<12;ai++){var n=A[ai];if(n&&n.nodeType===3)n=n.parentElement;if(!n||n.nodeType!==1)continue;if(!_searchFull6118&&search6118(n))_searchFull6118=1;if(_roots.indexOf(n)<0)_roots.push(n);}}if(!_roots.length)return;clearTimeout(_t);_t=setTimeout(function(){if(_idle)return;_idle=1;window.__AD_IDLE6056__(run6056,320);},120);}catch(e){}})"
           ".observe(document.documentElement,{childList:true,subtree:true});}catch(e){}"
         "window.__AMZDARK_APPLY__();"
         // Re-apply when the page is restored from the back-forward cache (returning
         // to a tab). pageshow.persisted is true exactly in that case, and it is the
         // event that fires when no navigation happens — the cart's "went white on
         // return" path. Also re-assert on visibility regain.
         "try{window.addEventListener('pageshow',function(e){if(e.persisted)window.__AMZDARK_APPLY__();});}catch(e){}"
         "try{document.addEventListener('visibilitychange',function(){if(!document.hidden)window.__AMZDARK_APPLY__();});}catch(e){}"
         "}}catch(e){}})();",
        floorBG, floorBG, floorBG, floorBG, dr, [NSString stringWithUTF8String:gP.fgHex], ADThemeLiteral(), ADFixesLiteral()];
    return gADBootstrap613;
}


// ── Production WEB WHITE-BACKGROUND TAME ──────────────────────────────────
// v6.0.53: the old v5.446 scanner body was production-disabled since v6.0.27.
// Keep only the direct/declarative owner that is actually injected.
static NSString *ADWhiteTameWebJS6027(void){
    if (!gP.enabled || !gP.whiteTame) return nil;
    if (gADTameWeb613) return gADTameWeb613;
    CGFloat s=MAX(0,MIN(100,gP.whiteTameStrength));
    CGFloat b=1.0-(0.50*(s/100.0));
    CGFloat a=0.50*(s/100.0);
    gADTameWeb613 = [NSString stringWithFormat:
        @"(function(){try{"
         // v6.0.34: keep the v6.0.33 direct-ownership TWB baseline. Close the final
         // canvas-card gap with one declarative/leaf-local background owner. College
         // structural paint now belongs to the always-on dark-theme bootstrap above.
         // No TWB scroll listener, timer, or new MutationObserver is added.
         "var BB='brightness(%.3f) saturate(1.08)',AA='rgba(0,0,0,%.3f)';"
         "var U=String(location.href||'').toLowerCase(),HOME=(window.top===window&&(/\\/gp\\/gw\\/ajax\\/mshop/.test(U)||/ishome(?:pageredesign)?=true/.test(U)||/istransparentnav=true/.test(U)));if(HOME&&document.documentElement)document.documentElement.setAttribute('data-ad-twb-home6033','1');"
         "var old=document.getElementById('ad-twb6027'),old2=document.getElementById('ad-twb6029'),old3=document.getElementById('ad-twb6031'),old4=document.getElementById('ad-twb6033'),id='ad-twb6034',st=document.getElementById(id);"
         "if(old&&old!==st&&old.parentNode)old.parentNode.removeChild(old);if(old2&&old2!==st&&old2.parentNode)old2.parentNode.removeChild(old2);if(old3&&old3!==st&&old3.parentNode)old3.parentNode.removeChild(old3);if(old4&&old4!==st&&old4.parentNode)old4.parentNode.removeChild(old4);"
         "if(!st){st=document.createElement('style');st.id=id;(document.head||document.documentElement).appendChild(st);}"
         "var css='html body :is(' +"
           "'img.s-image,'+"
           "'.s-product-image-container img,'+"
           "'[data-component-type=s-product-image] img,'+"
           "'[data-component-type=s-search-result] img,'+"
           "'#dp-container img.a-dynamic-image,'+"
           "'#ppd img.a-dynamic-image,'+"
           "'#landingImage,'+"
           "'#imgTagWrapperId img,'+"
           "'.a-carousel-card img.a-dynamic-image,'+"
           "'img.a-amazon-image,'+"
           "'[class*=_gwm-asin-tile] img,'+"
           "'img[class*=_np],'+"
           "'[class*=product-image] img,'+"
           "'img[class*=_single-creative-card],'+"
           "'img[class*=_single-video-card],'+"
           "'[class*=single-creative-card] img,'+"
           "'[class*=single-video-card] img,'+"
           "'video.vjs-tech,'+"
           "'[class*=single-video-card] video,'+"
           "'[class*=video-card] video,'+"
           "'[class*=sbv-video] video,'+"
           "'[data-component-type*=video] video' +"
         "'):not([class*=icon]):not([class*=logo]):not([class*=avatar]):not([class*=profile]):not([class*=merchant]):not([class*=seller]):not([class*=brand]):not([class*=store]):not([class*=sprite]){filter:'+BB+'!important;}'+"
         // v5.446 _adHomeBgLeaf395 owns the actual leaf itself. v6.0.31 accidentally
         // required a second matching ancestor, so NPACK/vjs variants could escape.
         "'html[data-ad-twb-home6033] body [class*=theming-card-background],html[data-ad-twb-home6033] body .vjs-poster,html[data-ad-twb-home6033] body [class*=vjs-poster]{filter:none!important;background-blend-mode:normal!important;box-shadow:inset 0 0 0 9999px '+AA+'!important;}'+"
         "'html body :is([class*=single-creative-card],[class*=single-video-card],[class*=video-card],[class*=theming-card]) :is([class*=theming-card-background],.vjs-poster,[class*=vjs-poster]){filter:none!important;background-blend-mode:normal!important;box-shadow:inset 0 0 0 9999px '+AA+'!important;}'+"
         "'html[data-ad-twb-home6033] body :is([class*=npack-asin-card],[class*=gwm-asin-tile],[class*=gwm-tile],[class*=mosaic-container],[class*=canvas-container]) canvas,html body :is([class*=single-creative-card],[class*=single-video-card],[class*=video-card],[class*=theming-card],[class*=canvas-card],[class*=sbv-video]) canvas{filter:'+BB+'!important;}'+"
         "'html body :is([class*=single-creative-card],[class*=single-video-card],[class*=video-card],[class*=theming-card],[class*=canvas-card],[class*=sbv-video]) [style*=background-image]{background-blend-mode:normal!important;box-shadow:inset 0 0 0 9999px '+AA+'!important;}'+"
         // The last untamed Home hero is a _canvas-card_ whose visible painter is a
         // solid-color canvas-container, not an IMG or background-image:url(...) leaf.
         // An inset shadow dims only that background plane and leaves live text/art above it.
         "'html[data-ad-twb-home6033] body [class*=canvas-card] [class*=canvas-container],html[data-ad-twb-home6033] body [class*=canvas-card][class*=canvas-container]{filter:none!important;background-blend-mode:normal!important;box-shadow:inset 0 0 0 9999px '+AA+'!important;}'+"
         "'[data-ad-twb-before6033]::before,[data-ad-twb-after6033]::after{filter:'+BB+'!important;}'+"
         "'html body :is(.s-suggestion,.s-suggestion-container,[class*=recentSearch],[class*=search-suggestion],[class*=avatar],[class*=profile],[class*=merchant],[class*=seller],[class*=brand],[class*=store],[class*=logo]) img{filter:none!important;}';"
         "if(st.textContent!==css)st.textContent=css;"
         "function S(v){try{return String(v&&v.baseVal!==undefined?v.baseVal:(v||''));}catch(e){return '';}}"
         "function chain(e){var p=e,d=0,c='';while(p&&d++<6){c+=' '+S(p.className)+' '+String(p.id||'')+' '+String((p.getAttribute&&p.getAttribute('data-component-type'))||'')+' '+String((p.getAttribute&&p.getAttribute('data-hook'))||'');p=p.parentElement;}return c.toLowerCase();}"
         "function localText(e){var p=e,d=0,t='';while(p&&d++<6){var x=String(p.textContent||'').replace(/\\s+/g,' ').trim();if(x&&x.length<1200)t+=' '+x.toLowerCase();p=p.parentElement;}return t;}"
         "function blocked(e,c,t,fo,rv){if(!fo&&e.__adGlyph)return true;if(/avatar|profile|author|reviewer|byline|merchant|seller|brand-logo|store-logo|headshot|user-image|customer-avatar|star|rating|checkbox|heart|wish|search-suggestion|recentsearch|camera|microphone|location-icon|chevron|close-icon/.test(c))return true;if(!fo&&/sprite|icon|logo/.test(c))return true;if(rv&&/sprite|icon|logo|pixel/.test(c))return true;if(/medical care|health ai|prescriptions|personal guida|fast,? free deliv|your amazon highlights|total savings|sessions streamed|keep streaming/.test(t))return true;if(/same-day|same day|pharmacy|prime video|amazon haul|whole foods|autos/.test(t)&&/nav|explore|shortcut|chip|pill|category/.test(c+t))return true;return false;}"
         "function forced(t){return /subscribe (?:&|and) save|keep shopping for|shop previously watched|lists (?:and|&) registries|alexa for shopping|best deals on|send an amazon gift card|how can i help|returns are easy/.test(t);}"
         "function reviewCtx(t,c){return /your reviews|what did you think of the item/.test(t)||/review-image|customer-image|review.*photo/.test(c);}"
         "function product(e,c){var p=e,d=0;while(p&&d++<6){var asin=String((p.getAttribute&&p.getAttribute('data-asin'))||''),h=String((p.getAttribute&&p.getAttribute('href'))||''),q=S(p.className)+' '+String(p.id||'');if(asin||/asin|product|p13n|npack|cxvhz|gwm-asin|carousel-image|product-image|s-image|a-amazon-image/i.test(q)||h.indexOf('/dp/')>=0||h.indexOf('/gp/product/')>=0)return true;p=p.parentElement;}return /review-image|customer-image|review.*photo/.test(c);}"
         // Exact donor Home probes repeatedly name NPACK/GWM/mosaic roots in addition
         // to the obvious single-creative/video classes.
         "function carouselFamily(s){return /single-creative-card|single-video-card|video-card|theming-card|canvas-card|sbv-video|video-js|vjs-|ape-placement|ape-wrapper|hybrid-widget-sponsored|adfeedbackmaincomponent|sponsored-products|npack-asin-card|gwm-asin-tile|gwm-tile|mosaic-container|canvas-container/i.test(s);}"
         "function ownClass(e){return (S(e&&e.className)+' '+String(e&&e.id||'')).toLowerCase();}"
         // Donor __AD_HEROFAST365__ protects logo/icon/sprite on the media leaf itself;
         // it does not reject a whole image because an ancestor happens to say brand.
         "function creativeBlocked(e,src){var c=ownClass(e),al=String((e&&e.getAttribute&&e.getAttribute('alt'))||'').toLowerCase();return /sprite|icon|logo|pixel|avatar|profile|headshot|rating|star|checkbox|heart|wish/.test(c)||/logo|pixel|placeholder|spacer|blank|transparent/.test(src)||/\\b(?:logo|avatar|profile)\\b/.test(al);}"
         // v6.0.128: exact v5.446 _adBgPlacement365 policy. The four-parent check is
         // bounded and only prevents TWB from claiming structural ad backgrounds.
         "function adPlacement(e){try{var p=e,d=0;while(p&&d++<4){var c=S(p.className),id=String(p.id||''),cw=String((p.getAttribute&&p.getAttribute('data-cel-widget'))||'');if(/ape-placement|ape-wrapper|adfeedbackmaincomponent|ad-slot|adslot/i.test(c+' '+id+' '+cw))return true;if(p.getElementsByTagName&&p.getElementsByTagName('iframe').length&&p.getBoundingClientRect().width>240)return true;p=p.parentElement;}return false;}catch(x){return false;}}"
         "function paintBg(e){try{if(!e||e.nodeType!==1)return 0;if(e.closest&&e.closest('[data-ad-college6034]'))return 0;if(adPlacement(e))return 0;var r=e.getBoundingClientRect();if(r.width<32||r.height<32)return 0;var c=ownClass(e);if(/sprite|icon|logo|pixel|avatar|profile/.test(c))return 0;var cs=getComputedStyle(e),bi=String(cs.backgroundImage||'none'),known=/theming-card-background|vjs-poster/.test(c),solidCanvas=HOME&&/canvas-container/.test(c)&&e.closest&&e.closest('[class*=canvas-card]'),n=0;if(known||solidCanvas||bi.indexOf('url(')>=0){e.style.setProperty('filter','none','important');e.style.setProperty('background-blend-mode','normal','important');e.style.setProperty('box-shadow','inset 0 0 0 9999px '+AA,'important');e.setAttribute('data-ad-twb-bg6033','1');n++;}try{var bf=getComputedStyle(e,'::before'),af=getComputedStyle(e,'::after');if(String(bf.backgroundImage||'none').indexOf('url(')>=0){e.setAttribute('data-ad-twb-before6033','1');n++;}if(String(af.backgroundImage||'none').indexOf('url(')>=0){e.setAttribute('data-ad-twb-after6033','1');n++;}}catch(px){}return n;}catch(x){return 0;}}"
         "function creativeMedia(e){try{if(!e||e.nodeType!==1)return 0;var tg=String(e.tagName||'').toUpperCase();if(tg!=='IMG'&&tg!=='VIDEO'&&tg!=='CANVAS')return 0;var r=e.getBoundingClientRect(),src=String(e.currentSrc||e.src||e.poster||'').toLowerCase(),nw=(tg==='VIDEO'?(e.videoWidth||0):(e.naturalWidth||0)),nh=(tg==='VIDEO'?(e.videoHeight||0):(e.naturalHeight||0));if(creativeBlocked(e,src)||!((r.width>=32&&r.height>=32)||(nw>=32&&nh>=32)))return 0;if(mode==='productad'||mode==='standalone'){var W=innerWidth||390,H=innerHeight||700,full=(r.width>W*.64&&r.height>H*.55)||(r.width*r.height>W*H*.58);if(full&&tg!=='VIDEO'){e.style.removeProperty('filter');e.removeAttribute('data-ad-twb6033');return 0;}}e.style.setProperty('filter',BB,'important');e.setAttribute('data-ad-twb6033','1');return 1;}catch(x){return 0;}}"
         // Card-local equivalent of the donor hero/Home scans. It is bounded and runs
         // only when that card itself loads/changes; no page-wide or scroll-time recovery.
         "function adRoot(root){try{if(!root||root.nodeType!==1)return 0;var now=Date.now();if(root.__adTWB6055Stamp&&now-root.__adTWB6055Stamp<220)return 0;root.__adTWB6055Stamp=now;var A=[root],n=0,Q=root.querySelectorAll?root.querySelectorAll('img,video,canvas,[class*=theming-card-background],[class*=vjs-poster],[class*=canvas-container],[style*=background-image]'):[];for(var i=0;i<Q.length&&A.length<36;i++)A.push(Q[i]);for(var j=0;j<A.length;j++){var e=A[j],tg=String(e.tagName||'').toUpperCase();if(tg==='IMG'||tg==='VIDEO'||tg==='CANVAS')n+=creativeMedia(e);else n+=paintBg(e);}return n;}catch(x){return 0;}}"
         "function tameBgChain(e,c){try{if(!e)return;var p=e,d=0,ctx=c||'';while(p&&d++<6){var pc=S(p.className)+' '+String(p.id||''),fam=(mode==='hero')||carouselFamily(ctx+' '+pc);if(fam)paintBg(p);ctx+=' '+pc;p=p.parentElement;}}catch(x){}}"
         "var mode=(function(){try{if(window.top===window)return 'main';var u=String(document.referrer||'').toLowerCase();if(u.indexOf('/dp/')>=0||u.indexOf('/gp/aw/d/')>=0||u.indexOf('/gp/product/')>=0||u.indexOf('/s?')>=0||u.indexOf('/search')>=0||u.indexOf('?k=')>=0||u.indexOf('&k=')>=0||u.indexOf('field-keywords=')>=0)return 'productad';return ((innerHeight||0)<180||((innerWidth||1)/(innerHeight||1))>2.25)?'standalone':'hero';}catch(e){return 'main';}})();"
         "function tame(e){try{if(!e||e.nodeType!==1)return;var tg=String(e.tagName||'').toUpperCase();if(tg!=='IMG'&&tg!=='VIDEO'&&tg!=='CANVAS')return;var r=e.getBoundingClientRect();if(r.width<2||r.height<2)return;var c=chain(e),t=localText(e),src=String(e.currentSrc||e.src||e.poster||'').toLowerCase(),fo=forced(t),rv=reviewCtx(t,c),pr=product(e,c),hf=carouselFamily(c);if(mode==='hero')tameBgChain(e,c);if((hf?creativeBlocked(e,src):blocked(e,c,t,fo,rv))||/pixel|placeholder|spacer|blank|transparent/.test(src))return;var W=innerWidth||390,H=innerHeight||700,nw=(tg==='VIDEO'?(e.videoWidth||0):(e.naturalWidth||0)),nh=(tg==='VIDEO'?(e.videoHeight||0):(e.naturalHeight||0)),ok=false;if(mode==='productad'||mode==='standalone'){var full=(r.width>W*.64&&r.height>H*.55)||(r.width*r.height>W*H*.58);if(full&&tg!=='VIDEO'){e.style.removeProperty('filter');e.removeAttribute('data-ad-twb6033');return;}ok=(r.width>=26&&r.height>=26)||(nw>=26&&nh>=26);}else if(mode==='hero'||hf){ok=(r.width>=32&&r.height>=32)||(nw>=32&&nh>=32);}else{if(rv&&tg!=='IMG')return;var mn=(pr||fo||rv)?24:56;ok=(r.width>=mn&&r.height>=mn)||(nw>=mn&&nh>=mn);}if(!ok)return;e.style.setProperty('filter',BB,'important');e.setAttribute('data-ad-twb6033','1');}catch(x){}}"
         // Piggyback target for the already-existing v6.0.15 ad-island observer.
         "window.__AD_TWB6033_ADROOT__=adRoot;"
         "function ev(x){try{tame(x.target);}catch(e){}}"
         "document.addEventListener('load',ev,true);document.addEventListener('loadedmetadata',ev,true);document.addEventListener('loadeddata',ev,true);document.addEventListener('canplay',ev,true);document.addEventListener('playing',ev,true);"
         // One bounded initial/BFCache pass catches already-complete media. The only
         // pass remains media-only; the existing v6.0.15 ad observer invokes adRoot for lazy cards.
         "function once(){try{var tags=['img','video','canvas'],budget=420;for(var ti=0;ti<tags.length&&budget>0;ti++){var Q=document.getElementsByTagName(tags[ti]);for(var i=0;i<Q.length&&budget-- >0;i++)tame(Q[i]);}}catch(e){}}"
         "if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',once,{once:true});else once();"
         "window.addEventListener('pageshow',once,{passive:true});"
         "window.__AD_TWB6027_INSTALLED__=1;window.__AD_TWB6029_INSTALLED__=1;window.__AD_TWB6030_INSTALLED__=1;window.__AD_TWB6031_INSTALLED__=1;window.__AD_TWB6033_INSTALLED__=1;window.__AD_TWB6034_INSTALLED__=1;window.__AD_TWB6033_MODE__=mode;"
         "}catch(e){}})();", b, a];
    return gADTameWeb613;
}
static NSString *ADWhiteTameWebJS(void){ return ADWhiteTameWebJS6027(); }

static void ADAttachWhiteTameUserScript446(WKUserContentController *ucc){
    if (!ucc || !gP.enabled || !gP.whiteTame) return;
    @try {
        for (WKUserScript *existing in ucc.userScripts){
            if ([existing.source containsString:@"__AD_TWB6027_INSTALLED__"] || [existing.source containsString:@"__AD_TWB446_INSTALLED__"]) return;
        }
        NSString *js=ADWhiteTameWebJS();
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
    if (gADReapply613) return gADReapply613;
    gADReapply613 = [NSString stringWithFormat:
        @"(function(){try{"
         "if(!(window.DarkReader&&DarkReader.enable))return 'noDR';"
         "if(!document.querySelector('style.darkreader'))DarkReader.enable(%@,%@);"
         "if(window.__AMZDARK_FIXCONTRAST__){if(window.__AD_IDLE6056__){window.__AD_IDLE6056__(function(){window.__AMZDARK_FIXCONTRAST__();if(window.__AD_COLLEGE6034__)window.__AD_COLLEGE6034__(document);},260);return 'queued';}return ''+window.__AMZDARK_FIXCONTRAST__();}"
         "return 'nofix';"
         "}catch(e){return 'err';}})();",
        ADThemeLiteral(), ADFixesLiteral()];
    return gADReapply613;
}


// ── v6.0.9: exact v5.446 symbol/checkbox authority ───────────────────────────
// Heart-shell protection remains the proven lightweight 6.x guard. The sym413 owner
// and stockCheckbox434 paint/state owners below remain direct v5.446 transplants; v6.0.19's
// coalesced MutationObserver/shared post-scroll scheduler stays authoritative for performance.
static NSString *ADThreeSymbolsWebJS605(void){
    static NSString *cached = nil;
    if (cached) return cached;
    cached = [NSString stringWithFormat:
       @"(function(){try{if(window.__AD_SYM605_LOADED__)return 'already';window.__AD_SYM605_LOADED__=1;"
         "window.__AD_HEARTSHELL427__=function(){try{if(window.__ADFRAME_MODE__||!document.body)return 0;"
           "function real427(e){return !!(e&&e.querySelector&&e.querySelector('input[type=checkbox],[class*=a-icon-checkbox]'));}"
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
             "if(real427(p)||card427(p))break;if(inner427(p)){p=p.parentElement;continue;}var r=p.getBoundingClientRect();"
             "var geom=r.width>=18&&r.width<=60&&r.height>=18&&r.height<=60&&Math.abs(r.width-r.height)<=12;"
             "if(geom&&own427(p)){var st=getComputedStyle(p),clean=(String(st.backgroundColor||'').replace(/\\s+/g,'')==='rgba(0,0,0,0)'||String(st.backgroundColor||'')==='transparent')&&parseFloat(st.borderTopWidth||0)<.1&&String(st.boxShadow||'none')==='none';if(!clean||!p.hasAttribute('data-ad-heart-shell427'))flat427(p);n++;}"
             "p=p.parentElement;}}return n;}catch(e){return -1;}};"
         "try{if(document&&!document.getElementById('adheartshell427')){var h427=document.createElement('style');h427.id='adheartshell427';h427.textContent='[data-ad-heart-shell427]{background-color:transparent !important;border:0 !important;border-radius:0 !important;box-shadow:none !important;outline:none !important;}[data-ad-heart-shell427]::before,[data-ad-heart-shell427]::after{background-color:transparent !important;border:0 !important;box-shadow:none !important;outline:none !important;}';(document.head||document.documentElement).appendChild(h427);}}catch(e){}"
         "function sym413(){try{"
           "var SPEC={bg:'#181a1b',bd:'1.5px solid rgba(255,255,255,0.65)'};"
           "if(!document.getElementById('adcards440')){var s440=document.createElement('style');s440.id='adcards440';s440.textContent='[data-ad-cards440-pseudo*=b]::before,[data-ad-cards440-pseudo*=a]::after{filter:brightness(0) invert(1) !important;color:#fff !important;fill:#fff !important;stroke:#fff !important;}';(document.head||document.documentElement).appendChild(s440);}"
           "function cn(e){var c=e&&e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||''));}"
           "function rr(e){try{return e&&e.getBoundingClientRect?e.getBoundingClientRect():null;}catch(x){return null;}}"
           "function sq(e){var r=rr(e);"
           "return r.width>=22&&r.width<=48&&r.height>=22&&r.height<=48&&Math.abs(r.width-r.height)<=10;}"
           "function kind(e){var c=cn(e);"
             "if(/mlt-icon-container/.test(c))return 'cards';"
             "if(/a-checkbox/.test(c)&&!/a-icon-checkbox/.test(c))return 'checkbox';"
             "if(/puis-mab-chevron/.test(c)&&!/glyph/.test(c))return 'chevron';"
             "if(/puis-heart-position/.test(c)||/lists-framework-action-button/.test(c))return 'heart';"
             "return '';}"
           "function shown(e,stop){try{var p=e,u=0;while(p&&u++<10){var s=getComputedStyle(p),o=parseFloat(s.opacity||'1');if(String(s.display||'')==='none'||/hidden|collapse/.test(String(s.visibility||''))||o<.08)return false;if(p===stop)break;p=p.parentElement;}var r=rr(e);return !!(r&&r.width>=3&&r.height>=3);}catch(x){return false;}}"
           "function legacy(e){if(!e||e.hasAttribute('data-ad-cards440-host'))return;var old=e.getAttribute('data-ad-sym413')==='cards'||e.getAttribute('data-ad-disc420')==='disc'||e.__adBy==='sym413';if(old){['background-color','border','border-radius','box-shadow','box-sizing'].forEach(function(p){e.style.removeProperty(p);});e.removeAttribute('data-ad-sym413');e.removeAttribute('data-ad-disc420');delete e.__adBy;}var A=e.querySelectorAll('*');for(var i=0;i<A.length&&i<48;i++){var a=A[i],by=String(a.__adBy||''),owned=a.hasAttribute('data-ad-sym413glyph')||/^(?:sym413glyph|disc420|disc422)$/.test(by);if(!owned)continue;['filter','color','fill','stroke','background-color','visibility','opacity','border','box-shadow'].forEach(function(p){a.style.removeProperty(p);});a.removeAttribute('data-ad-sym413glyph');delete a.__adBy;delete a.__adGlyph;}}"
           "function checkboxAt(e){try{var card=e.closest&&e.closest('[class*=puis-card],[class*=s-result-item],[data-component-type=\"s-search-result\"],[data-asin],[class*=s-product-image],[class*=product-image]'),Q=card?card.querySelectorAll('[class*=a-icon-checkbox]'):document.querySelectorAll('[class*=a-icon-checkbox]'),r=rr(e);if(!r)return false;var x=r.left+r.width/2,y=r.top+r.height/2;for(var i=0;i<Q.length&&i<180;i++){var q=Q[i],qr=rr(q);if(!qr||!shown(q,card||document.body))continue;var qx=qr.left+qr.width/2,qy=qr.top+qr.height/2,ix=Math.max(0,Math.min(r.right,qr.right)-Math.max(r.left,qr.left)),iy=Math.max(0,Math.min(r.bottom,qr.bottom)-Math.max(r.top,qr.top));if((Math.abs(x-qx)<18&&Math.abs(y-qy)<18)||ix*iy>Math.min(r.width*r.height,qr.width*qr.height)*.35)return true;}return false;}catch(x){return true;}}"
           "function clearCards(e){var P=['background-color','border','border-radius','box-shadow','box-sizing'];for(var p=0;p<P.length;p++)e.style.removeProperty(P[p]);if(e.getAttribute('data-ad-cards440-suppressed')==='checkbox'){e.style.removeProperty('visibility');e.style.removeProperty('opacity');}e.removeAttribute('data-ad-cards440-host');e.removeAttribute('data-ad-cards440-suppressed');e.removeAttribute('data-ad-cards440-pseudo');e.removeAttribute('data-ad-sym413');var A=e.querySelectorAll('[data-ad-cards440-glyph],[data-ad-cards440-pseudo]');for(var i=0;i<A.length;i++){var a=A[i];['filter','color','fill','stroke','background-color'].forEach(function(k){a.style.removeProperty(k);});a.removeAttribute('data-ad-cards440-glyph');a.removeAttribute('data-ad-cards440-pseudo');if(a.__adBy==='cards440')delete a.__adBy;}}"
           "function glyph440(g){var r=rr(g);if(!r||r.width<3||r.height<3||r.width>48||r.height>48)return false;return true;}"
           "function cards(e){if(/mlt-icon-container/.test(cn(e))){if(e.getAttribute('data-ad-cards6103')!=='1'){legacy(e);clearCards(e);e.setAttribute('data-ad-cards6103','1');}return 1;}legacy(e);if(e.getAttribute('data-ad-cards440-suppressed')==='checkbox'){if(checkboxAt(e))return 0;e.style.removeProperty('visibility');e.style.removeProperty('opacity');e.removeAttribute('data-ad-cards440-suppressed');}var N=e.querySelectorAll('[class*=mlt-image-icon],img[class*=s-image],p[class*=mlt-text-icon],img,i,svg,path,use,polygon'),P=[e],live=[],pseudo='';for(var pi=0;pi<N.length&&pi<47;pi++)P.push(N[pi]);for(var i=0;i<P.length&&i<48;i++){var g=P[i],r=rr(g);if(!glyph440(g)||!shown(g,e))continue;var t=String(g.tagName||'').toUpperCase(),s=getComputedStyle(g),b=getComputedStyle(g,'::before'),a=getComputedStyle(g,'::after'),paint=/^(IMG|I|SVG|PATH|USE|POLYGON)$/.test(t)||/mlt-text-icon/.test(cn(g))||String(s.backgroundImage||'none')!=='none'||String(s.maskImage||s.webkitMaskImage||'none')!=='none';if(String(b&&b.backgroundImage||'none')!=='none'||String(b&&b.content||'none')!=='none')pseudo+='b';if(String(a&&a.backgroundImage||'none')!=='none'||String(a&&a.content||'none')!=='none')pseudo+='a';if(paint)live.push(g);}if(!live.length&&!pseudo){clearCards(e);return 0;}if(checkboxAt(e)){clearCards(e);e.setAttribute('data-ad-cards440-suppressed','checkbox');e.style.setProperty('visibility','hidden','important');e.style.setProperty('opacity','0','important');return 0;}var old=e.querySelectorAll('[data-ad-cards440-glyph],[data-ad-cards440-pseudo]');for(var o=0;o<old.length;o++){if(live.indexOf(old[o])>=0)continue;['filter','color','fill','stroke','background-color'].forEach(function(k){old[o].style.removeProperty(k);});old[o].removeAttribute('data-ad-cards440-glyph');old[o].removeAttribute('data-ad-cards440-pseudo');}e.setAttribute('data-ad-sym413','cards');e.setAttribute('data-ad-cards440-host','1');if(pseudo)e.setAttribute('data-ad-cards440-pseudo',pseudo);else e.removeAttribute('data-ad-cards440-pseudo');e.__adBy='cards440';e.style.setProperty('background-color',SPEC.bg,'important');e.style.setProperty('border',SPEC.bd,'important');e.style.setProperty('border-radius','50%%','important');e.style.setProperty('box-shadow','none','important');e.style.setProperty('box-sizing','border-box','important');for(var j=0;j<live.length;j++){var z=live[j],tg=String(z.tagName||'').toUpperCase();if(!glyph440(z))continue;z.setAttribute('data-ad-cards440-glyph','1');z.__adBy='cards440';if(/^(SVG|PATH|USE|POLYGON)$/.test(tg)){z.style.setProperty('filter','none','important');z.style.setProperty('fill','#ffffff','important');z.style.setProperty('stroke','#ffffff','important');}else z.style.setProperty('filter','brightness(0) invert(1)','important');z.style.setProperty('color','#ffffff','important');z.style.setProperty('background-color','transparent','important');if(pseudo)z.setAttribute('data-ad-cards440-pseudo',pseudo);}return 1;}"
           "var Q=document.querySelectorAll('[class*=mlt-icon-container],[class*=a-checkbox],[class*=puis-mab-chevron],[class*=puis-heart-position],[class*=lists-framework-action-button]'),n=0,sk=0;"
           "for(var i=0;i<Q.length&&i<400;i++){var e=Q[i],k=kind(e);"
             "if(!k){sk++;continue;}"
             "if(k==='cards'){if(cards(e))n++;else sk++;continue;}"
             "var hs=e.querySelector&&e.querySelector('[class*=lists-framework-action-button],[class*=puis-heart-position]');"
             "var rc=!!(e.querySelector&&e.querySelector('input[type=checkbox],[class*=a-icon-checkbox]'));"
             "if(hs&&!rc&&k!=='cards'){e.setAttribute('data-ad-heart-shell427','1');"
               "['data-ad-sym413','data-ad-stock403','data-ad-stocksel403','data-ad-v333403','data-ad-product391','data-ad-productselected391'].forEach(function(a){e.removeAttribute(a);});"
               "e.style.setProperty('background-color','transparent','important');"
               "e.style.setProperty('border','0','important');"
               "e.style.setProperty('border-radius','0','important');"
               "e.style.setProperty('box-shadow','none','important');"
               "e.style.setProperty('outline','none','important');sk++;continue;}"
             "if(k==='checkbox'){sk++;continue;}"
             "if(!sq(e)){sk++;continue;}"
             "if(e.parentElement&&e.parentElement.closest&&e.parentElement.closest('[data-ad-sym413]')){sk++;continue;}"
             "e.setAttribute('data-ad-sym413',k);e.__adBy='sym413';"
             "e.style.setProperty('background-color',SPEC.bg,'important');"
             "e.style.setProperty('border',SPEC.bd,'important');"
             "e.style.setProperty('border-radius','50%%','important');"
             "e.style.setProperty('box-shadow','none','important');"
             "e.style.setProperty('box-sizing','border-box','important');"
             "var G=e.querySelectorAll('img,i,svg,path,p');"
             "for(var j=0;j<G.length&&j<24;j++){var g=G[j],gr=g.getBoundingClientRect();"
               "if(gr.width>48||gr.height>48)continue;"
               "var tg=String(g.tagName||'').toUpperCase();"
               "if(tg==='IMG'||tg==='I'||tg==='P')"
                 "g.style.setProperty('filter','brightness(0) invert(1)','important');"
               "g.__adBy='sym413glyph';g.setAttribute('data-ad-sym413glyph','1');"
               "if(tg==='SVG'||tg==='PATH'){g.style.setProperty('fill','#ffffff','important');"
                 "g.style.setProperty('color','#ffffff','important');}"
               "g.style.setProperty('background-color','transparent','important');"
               "g.style.setProperty('visibility','visible','important');"
               "g.style.setProperty('opacity','1','important');"
               "g.removeAttribute('data-ad-compareorig380');g.removeAttribute('data-ad-compareorig379');}"
             "n++;}"
           "window.__AD_SYM413__='n='+n+' skip='+sk;"
         "}catch(e){window.__AD_SYM413__='err '+e;}}"
         "try{window.__AD_SYM413_PRE__=window.__AD_PRODUCTCTRL391RUN__;"
           "window.__AD_PRODUCTCTRL391RUN__=function(){"
             "var r=window.__AD_SYM413_PRE__?window.__AD_SYM413_PRE__():0;try{sym413();}catch(x){}return r;};"
         "}catch(e){}"
         "try{sym413();setTimeout(sym413,30);setTimeout(sym413,160);setTimeout(sym413,560);"
           "setTimeout(sym413,1560);setTimeout(sym413,2600);"
         "}catch(e){}"
         // v6.0.20: exact v5.446 PDP carousel selected-dot owner. The only
         // adaptation is scheduling: v6.0.19 already owns mutation/scroll recovery.
         "function dotFix374(){try{var U=document.querySelectorAll('ul.a-pagination.a-dots,[class*=a-pagination][class*=dots]'),n=0,total=0;for(var u=0;u<U.length&&u<8;u++){var D=U[u].querySelectorAll('li');for(var i=0;i<D.length&&i<30;i++){var d=D[i];total++;var cl=String(d.className||''),ac=String(d.getAttribute&&d.getAttribute('aria-current')||'').toLowerCase(),as=String(d.getAttribute&&d.getAttribute('aria-selected')||'').toLowerCase(),ds=String(d.getAttribute&&d.getAttribute('data-selected')||'').toLowerCase(),kid=null;try{kid=d.querySelector('.a-selected,.dot-selected-t2,[aria-current=true],[aria-current=page],[aria-selected=true],[data-selected=true]');}catch(ex){}var sel=/(^|\\s)(a-selected|dot-selected-t2)(\\s|$)/.test(cl)||ac==='true'||ac==='page'||as==='true'||ds==='true'||!!kid;if(sel){if(d.hasAttribute&&d.hasAttribute('data-darkreader-inline-bgcolor'))d.removeAttribute('data-darkreader-inline-bgcolor');d.style.setProperty('--darkreader-inline-bgcolor','#ffffff','important');d.style.setProperty('background-color','#ffffff','important');d.style.setProperty('border-color','#ffffff','important');d.setAttribute('data-ad-dotselected374','1');d.setAttribute('data-ad-dotfix','1');n++;}else{if(d.getAttribute&&d.getAttribute('data-ad-dotfix')==='1'){d.style.removeProperty('--darkreader-inline-bgcolor');d.style.removeProperty('background-color');d.style.removeProperty('border-color');d.removeAttribute('data-ad-dotfix');}d.removeAttribute&&d.removeAttribute('data-ad-dotselected374');}}}window.__AD_DOTFIX__=n;window.__AD_DOTTOTAL374__=total;}catch(e){}}"
         "window.__AD_DOTFIX374__=dotFix374;try{dotFix374();}catch(e){}"
         // v5.441 DEVICE-CAPTURED STOCK CHECKBOX + SHARED 32PX CHROME. Amazon
         // remains the sole owner of geometry, hit testing, state, and the checked
         // blue/checkmark sprite. Device P14 names Cart's hierarchy precisely:
         // 398x0 a-checkbox > 35x44 label > 23x23 input + 23x23 sprite. The old
         // shell pass skipped that label and let Amazon/Dark Reader intermittently
         // paint the gray rectangle. Mark every bounded Cart wrapper regardless of
         // existing visual paint, flatten it, and put one 32px chrome treatment on
         // the exact stock sprite via paint-only box-shadow. No width/height or
         // background-image/background-position write is allowed. The inset paint
         // covers the unchecked sprite without filtering it or the chrome. Native
         // :checked removes our paint synchronously and exposes Amazon's stock blue frame.
         "function stockCheckbox434(){if(window.__ADFRAME_MODE__||!document.body||window.__AD_CHECKBOX434_RUNNING__)return 0;window.__AD_CHECKBOX434_RUNNING__=1;try{"
           "var retired434=['adstock403','adcomparenative428','adcheckbox433'];for(var ri434=0;ri434<retired434.length;ri434++){var rs434=document.getElementById(retired434[ri434]);if(rs434&&rs434.parentNode)rs434.parentNode.removeChild(rs434);}"
           "var prior434=document.getElementById('adcheckbox434');if(prior434&&prior434.getAttribute('data-ad-native-state')!=='446'){if(prior434.parentNode)prior434.parentNode.removeChild(prior434);prior434=null;}"
           "if(!prior434){var s434=document.createElement('style');s434.id='adcheckbox434';s434.setAttribute('data-ad-native-state','446');"
             "s434.textContent='[data-ad-checkbox434-art]{filter:none !important;border-radius:4px !important;box-shadow:inset 0 0 0 64px #181a1b,0 0 0 3px #181a1b,0 0 0 4.5px rgba(255,255,255,.65) !important;transition:none !important;}'"
               "+'[data-ad-checkbox434-host]:is(input[type=checkbox]:checked,[aria-checked=true],[aria-pressed=true],[aria-selected=true],[data-checked=true],[data-selected=true],[data-state=checked],[data-state=on]) [data-ad-checkbox434-art],[data-ad-checkbox434-host]:has(input[type=checkbox]:checked,[aria-checked=true],[aria-pressed=true],[aria-selected=true],[data-checked=true],[data-selected=true],[data-state=checked],[data-state=on]) [data-ad-checkbox434-art],[data-ad-checkbox434-host][class*=checked]:not([class*=unchecked]) [data-ad-checkbox434-art],[data-ad-checkbox434-host][class*=selected]:not([class*=unselected]) [data-ad-checkbox434-art],[data-ad-checkbox434-host]:has([class*=checked]:not([class*=unchecked]),[class*=selected]:not([class*=unselected])) [data-ad-checkbox434-art],[data-ad-checkbox434-art]:is(input[type=checkbox]:checked,[aria-checked=true],[aria-pressed=true],[aria-selected=true],[data-checked=true],[data-selected=true],[data-state=checked],[data-state=on]),[data-ad-checkbox434-art][class*=checked]:not([class*=unchecked]),[data-ad-checkbox434-art][class*=selected]:not([class*=unselected]),[data-ad-checkbox434-art][src*=checkbox-on],[data-ad-checkbox434-art][src*=checkbox_checked],[data-ad-checkbox434-art][src*=checkmark],[data-ad-checkbox434-art][src*=selected],[data-ad-checkbox434-art][data-src*=checkbox-on],[data-ad-checkbox434-art][data-src*=checkbox_checked],[data-ad-checkbox434-art][data-src*=checkmark],[data-ad-checkbox434-art][data-src*=selected]{filter:none !important;border-radius:0 !important;box-shadow:none !important;}'"
               "+'[data-ad-checkbox434-shell=\"cart\"]{background-color:transparent !important;background-image:none !important;border:0 !important;box-shadow:none !important;outline:0 !important;filter:none !important;}'"
               "+'[data-ad-checkbox434-shell=\"cart\"]::before,[data-ad-checkbox434-shell=\"cart\"]::after{background-color:transparent !important;background-image:none !important;border:0 !important;box-shadow:none !important;outline:0 !important;filter:none !important;}';"
             "(document.head||document.documentElement).appendChild(s434);}"
           "function cn434(e){var c=e&&e.className;return String(c&&c.baseVal!==undefined?c.baseVal:(c||''));}"
           "function rr434(e){try{return e&&e.getBoundingClientRect?e.getBoundingClientRect():null;}catch(x){return null;}}"
           "function sq434(e,lo,hi){var r=rr434(e);return !!(r&&r.width>=lo&&r.width<=hi&&r.height>=lo&&r.height<=hi&&Math.abs(r.width-r.height)<=14);}"
           "function foreign434(e){try{return !!(e&&e.closest&&e.closest('[class*=mlt-icon-container],[class*=lists-framework-action-button],[data-ad-cards410-root],[data-ad-cards410-host],[data-ad-cards410-disc],[data-ad-cards410-glyph],[data-ad-heart-shell427],[class*=puis-heart-position],[class*=lists-treatment-hear],[class*=puis-mab-chevron],.puis-mab-overlay-row'));}catch(x){return true;}}"
           "function owned434(e){if(!e||e.nodeType!==1)return false;var p=String(e.getAttribute('data-ad-product391')||''),v=String(e.getAttribute('data-ad-v333403')||''),d=String(e.getAttribute('data-ad-disc420')||''),s=String(e.getAttribute('data-ad-sym413')||''),v4=String(e.getAttribute('data-ad-v333404')||'');if(p==='checkbox'||v==='c'||d==='checkbox'||s==='checkbox'||v4==='c'||v4==='checkbox')return true;var A=['data-ad-comparehost377','data-ad-comparechecked377','data-ad-compareinput377','data-ad-compare378','data-ad-compareleaf378','data-ad-compare-raster378','data-ad-compare379','data-ad-compareinput379','data-ad-compareorig379','data-ad-compare380','data-ad-compareinput380','data-ad-compareorig380','data-ad-comparelegacy387','data-ad-comparelegacyorig387','data-ad-productselected391','data-ad-productglyph391','data-ad-productraster391','data-ad-productvector391','data-ad-stock403','data-ad-stocksel403','data-ad-stockglyph403','data-ad-stockraster403','data-ad-stockvector403','data-ad-sym413glyph','data-ad-comparefunc428','data-ad-compareselected428','data-ad-comparehit428'];for(var i=0;i<A.length;i++)if(e.hasAttribute(A[i]))return true;return /^(?:product391|sym413|sym413glyph|disc420|disc422)$/.test(String(e.__adBy||''));}"
           "var marks434=['data-ad-comparehost377','data-ad-comparechecked377','data-ad-compareinput377','data-ad-compare378','data-ad-compareleaf378','data-ad-compare-raster378','data-ad-compare379','data-ad-compareinput379','data-ad-compareorig379','data-ad-compare380','data-ad-compareinput380','data-ad-compareorig380','data-ad-comparelegacy387','data-ad-comparelegacyorig387','data-ad-product391','data-ad-productselected391','data-ad-productglyph391','data-ad-productraster391','data-ad-productvector391','data-ad-stock403','data-ad-stocksel403','data-ad-stockglyph403','data-ad-stockraster403','data-ad-stockvector403','data-ad-v333403','data-ad-v333404','data-ad-disc420','data-ad-sym413','data-ad-sym413glyph','data-ad-comparefunc428','data-ad-compareselected428','data-ad-comparehit428'];"
           "var props434=['background-color','border','border-color','border-width','border-style','border-radius','box-shadow','box-sizing','filter','width','height','min-width','min-height','max-width','max-height','position','inset','top','right','bottom','left','transform','overflow','isolation','outline','z-index','margin','pointer-events','opacity','visibility','color','fill','stroke','transition','display','cursor'];/* preserve Amazon background-image/mask sprite */"
           "function scrub434(e){if(!owned434(e))return 0;for(var p=0;p<props434.length;p++)e.style.removeProperty(props434[p]);for(var a=0;a<marks434.length;a++)e.removeAttribute(marks434[a]);delete e.__adBy;delete e.__adGlyph;delete e.__adManual380;delete e.__adManualSig380;delete e.__adCompareBlue428;return 1;}"
           "function generic434(e){var b=String(e&&e.__adBy||'');if(!/^(?:gfix1|gfix2|aic|gsweep|fltpanel)$/.test(b))return 0;e.style.removeProperty('filter');delete e.__adBy;delete e.__adGlyph;return 1;}"
           "function visual434(e){try{var c=getComputedStyle(e),b=getComputedStyle(e,'::before'),a=getComputedStyle(e,'::after'),bi=String(c.backgroundImage||'none'),mi=String(c.maskImage||c.webkitMaskImage||'none'),pbi=String((b&&b.backgroundImage)||'none')+' '+String((a&&a.backgroundImage)||'none'),pmi=String((b&&(b.maskImage||b.webkitMaskImage))||'none')+' '+String((a&&(a.maskImage||a.webkitMaskImage))||'none');return bi!=='none'||mi!=='none'||pbi!=='none none'||pmi!=='none none';}catch(x){return false;}}"
           "function light434(c){try{var m=/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([0-9.]+))?/i.exec(String(c&&c.backgroundColor||''));if(!m||(m[4]!==undefined&&+m[4]<.12))return false;return (.2126*(+m[1])+.7152*(+m[2])+.0722*(+m[3]))/255>.62;}catch(x){return false;}}"
           "function group434(e){if(!e||!scope434(e)||foreign434(e))return null;var exact=(e.matches&&e.matches('[class*=a-icon-checkbox]'))?e:(e.querySelector&&e.querySelector('[class*=a-icon-checkbox]')),ep=e.parentElement,eu=0;while(!exact&&ep&&eu++<4){exact=ep.querySelector&&ep.querySelector('[class*=a-icon-checkbox]');if(exact||ep.matches&&ep.matches(scopeSel434))break;ep=ep.parentElement;}if(exact&&!foreign434(exact)){var ah=exact.closest&&exact.closest('div.a-checkbox,[class~=a-checkbox]');if(ah&&scope434(ah)&&!foreign434(ah))return ah;var ch=exact.closest&&exact.closest('[class*=copilot-compare]');if(ch&&scope434(ch)&&sq434(ch,16,76)&&!foreign434(ch))return ch;var bh=exact.closest&&exact.closest('button[aria-label*=ompare],[role=button][aria-label*=ompare],[data-csa-c-content-id*=ompare],[data-testid*=ompare]');if(bh&&scope434(bh)&&sq434(bh,16,76)&&!foreign434(bh))return bh;}var legit=e.closest&&e.closest('[class*=copilot-compare],[class*=compare-checkbox],button[aria-label*=ompare],[role=button][aria-label*=ompare],[role=checkbox],[aria-checked],[data-csa-c-content-id*=ompare],[data-testid*=ompare]');if(!exact&&!legit)return null;var tg0=String(e.tagName||'').toUpperCase(),p=/^(IMG|I|INPUT|SVG|PATH|USE|POLYGON)$/.test(tg0)?e.parentElement:e,sem=null,best=null,u=0;while(p&&u++<8){if(foreign434(p))return null;var tg=String(p.tagName||'').toUpperCase();if(!sem&&p.matches&&p.matches(semanticSel434)&&sq434(p,16,76))sem=p;if(!best&&!/^(IMG|I|INPUT|SVG|PATH|USE|POLYGON)$/.test(tg)&&sq434(p,16,76))best=p;if(p.matches&&p.matches(scopeSel434))break;p=p.parentElement;}return sem||best||((tg0==='INPUT')?e:(e.parentElement||e));}"
           "function selected434(h){try{var q=(h.matches&&h.matches('input[type=checkbox]'))?h:h.querySelector('input[type=checkbox]');if(q)return !!q.checked;var A=[h],Z=h.querySelectorAll?h.querySelectorAll('[role=checkbox],[aria-checked],[aria-pressed],[aria-selected],[data-checked],[data-selected],[data-state]'):[];for(var i=0;i<Z.length&&i<32;i++)A.push(Z[i]);for(var j=0;j<A.length;j++){var e=A[j],a=String(e.getAttribute('aria-checked')||e.getAttribute('aria-pressed')||e.getAttribute('aria-selected')||e.getAttribute('data-checked')||e.getAttribute('data-selected')||e.getAttribute('data-state')||'').toLowerCase(),c=cn434(e).toLowerCase();if(a==='true'||a==='checked'||a==='on'||(/checked|selected/.test(c)&&!/unchecked|unselected/.test(c)))return true;if(a==='false'||a==='unchecked'||a==='off')return false;}var im=h.querySelector&&h.querySelector('img[src],img[data-src]'),src=im?String(im.currentSrc||im.src||im.getAttribute('data-src')||'').toLowerCase():'';return /checkbox[_-]?(?:on|checked)|checkmark|selected/.test(src)&&!/unchecked|unselected/.test(src);}catch(x){return false;}}"
           "function art434(h,seed){try{var Q=[h],D=h.querySelectorAll?h.querySelectorAll('*'):[];for(var q=0;q<D.length&&q<100;q++)Q.push(D[q]);if(Q.indexOf(seed)<0)Q.push(seed);var best=null,bs=9999;for(var i=0;i<Q.length;i++){var e=Q[i];if(!e||foreign434(e))continue;var r=rr434(e);if(!r||r.width<8||r.height<8||r.width>76||r.height>76)continue;var tg=String(e.tagName||'').toUpperCase();if(/^(PATH|USE|POLYGON)$/.test(tg))continue;var c=cn434(e).toLowerCase(),src=String((e.currentSrc||e.src||(e.getAttribute&&e.getAttribute('data-src'))||'')).toLowerCase(),cs=getComputedStyle(e),op=parseFloat(cs.opacity||'1'),exact=/a-icon-checkbox|checkbox[-_ ]?(?:icon|sprite|image)|checkmark|check-mark|tick/.test(c+' '+src),painted=visual434(e)||light434(cs),role=e.getAttribute&&e.getAttribute('role')==='checkbox',score=999;if(exact)score=0;else if(painted)score=20;else if(/^(I|IMG|SVG)$/.test(tg))score=35;else if(tg==='INPUT'&&String(e.type||'').toLowerCase()==='checkbox')score=45;else if(role)score=60;else if(e===seed)score=90;else continue;if(e===h)score+=25;if(op<.12||String(cs.visibility||'')==='hidden'||String(cs.display||'')==='none')score+=70;score+=(r.width*r.height)/100000;if(score<bs){bs=score;best=e;}}return best||(sq434(seed,8,76)?seed:(sq434(h,8,76)?h:null));}catch(x){return null;}}"
           "var prevHosts434=document.querySelectorAll('[data-ad-checkbox434-host]'),prevArts434=document.querySelectorAll('[data-ad-checkbox434-art]'),prevShells434=document.querySelectorAll('[data-ad-checkbox434-shell]');"
           "var shells434=[],hosts434=[],arts434=[],unchecked434=0,checked434=0,cleaned434=0,skip434=0,cartShell434=0;"
           "function shell434(h,art){if(!cart434||!h||!art)return;var p=art.parentElement,u=0;while(p&&u++<5){var tg=String(p.tagName||'').toUpperCase(),r=rr434(p),bounded=!!(r&&r.width>=18&&r.width<=76&&r.height>=18&&r.height<=76);if(p!==art&&p.contains&&p.contains(art)&&bounded&&!/^(IMG|I|INPUT|SVG|PATH|USE)$/.test(tg)){p.setAttribute('data-ad-checkbox434-shell','cart');if(shells434.indexOf(p)<0){shells434.push(p);cartShell434++;}}if(p.matches&&p.matches(scopeSel434))break;p=p.parentElement;}}"
           "var C=document.querySelectorAll('input[type=checkbox],[role=checkbox],[aria-checked],[class*=a-checkbox],[class*=a-icon-checkbox],[class*=copilot-compare],button[aria-label*=ompare],[role=button][aria-label*=ompare],[data-csa-c-content-id*=ompare],[data-testid*=ompare],img[src*=checkbox],img[data-src*=checkbox]');"
           "for(var i=0;i<C.length&&i<1100;i++){var seed=C[i],h=group434(seed);if(!h||hosts434.indexOf(h)>=0){skip434++;continue;}var Q=[h],D=h.querySelectorAll?h.querySelectorAll('*'):[];for(var q=0;q<D.length&&q<140;q++)Q.push(D[q]);for(var z=0;z<Q.length;z++){cleaned434+=generic434(Q[z]);cleaned434+=scrub434(Q[z]);Q[z].removeAttribute('data-ad-checkbox433-art');}var art=art434(h,seed);if(!art){skip434++;continue;}hosts434.push(h);var syn=h.querySelectorAll?h.querySelectorAll('[data-ad-comparebox377],[data-ad-comparecheck377]'):[];for(var sy=0;sy<syn.length;sy++){if(syn[sy].parentNode)syn[sy].parentNode.removeChild(syn[sy]);cleaned434++;}if(h.getAttribute('data-ad-checkbox434-host')!=='stock')h.setAttribute('data-ad-checkbox434-host','stock');var AL=[art],EX=h.querySelectorAll?h.querySelectorAll('[class*=a-icon-checkbox],img[src*=checkbox],img[data-src*=checkbox]'):[];for(var ex=0;ex<EX.length&&ex<24;ex++){var xa=EX[ex],xr=rr434(xa),xs=getComputedStyle(xa);if(xr&&xr.width>=8&&xr.height>=8&&xr.width<=76&&xr.height<=76&&parseFloat(xs.opacity||'1')>=.12&&String(xs.display||'')!=='none'&&String(xs.visibility||'')!=='hidden'&&AL.indexOf(xa)<0)AL.push(xa);}for(var al=0;al<AL.length;al++){var aa=AL[al];if(arts434.indexOf(aa)<0){if(aa.getAttribute('data-ad-checkbox434-art')!=='stock')aa.setAttribute('data-ad-checkbox434-art','stock');arts434.push(aa);}}shell434(h,art);if(selected434(h))checked434++;else unchecked434++;}"
           "var old433=document.querySelectorAll('[data-ad-checkbox433-art]');for(var x433=0;x433<old433.length;x433++)old433[x433].removeAttribute('data-ad-checkbox433-art');"
           "for(var ph=0;ph<prevHosts434.length;ph++)if(hosts434.indexOf(prevHosts434[ph])<0)prevHosts434[ph].removeAttribute('data-ad-checkbox434-host');for(var pa=0;pa<prevArts434.length;pa++)if(arts434.indexOf(prevArts434[pa])<0)prevArts434[pa].removeAttribute('data-ad-checkbox434-art');for(var ps=0;ps<prevShells434.length;ps++)if(shells434.indexOf(prevShells434[ps])<0)prevShells434[ps].removeAttribute('data-ad-checkbox434-shell');"
           "window.__AD_CHECKBOX434_STATE__='hosts='+hosts434.length+' art='+arts434.length+' unchecked='+unchecked434+' checked='+checked434+' cart='+(cart434?1:0)+' shells='+cartShell434+' cleaned='+cleaned434+' skip='+skip434;return hosts434.length;"
         "}catch(e){window.__AD_CHECKBOX434_STATE__='err '+(e&&e.message||e);return -1;}finally{window.__AD_CHECKBOX434_RUNNING__=0;}}"
         "try{window.__AD_CHECKBOX434__=stockCheckbox434;if(!window.__AD_CHECKBOX434_WRAP__){window.__AD_CHECKBOX434_WRAP__=1;"
           "window.__AD_PRODUCTCTRL391_PRE434__=window.__AD_PRODUCTCTRL391RUN__;window.__AD_PRODUCTCTRL391RUN__=function(){var r=window.__AD_PRODUCTCTRL391_PRE434__?window.__AD_PRODUCTCTRL391_PRE434__():0;try{window.__AD_CHECKBOX434__();}catch(x){}try{window.__AD_DOTFIX374__&&window.__AD_DOTFIX374__();}catch(x){}return r;};"
           "function queue434(delay){try{clearTimeout(window.__AD_CHECKBOX434_T__);window.__AD_CHECKBOX434_T__=setTimeout(function(){try{window.__AD_CHECKBOX434__();}catch(x){}try{window.__AD_DOTFIX374__&&window.__AD_DOTFIX374__();}catch(x){}},delay||90);}catch(x){}}"
           // v6.0.56: Amazon mutates class/src constantly while Home hydrates.  The old
           // observer turned every one of those changes into a whole-document checkbox
           // scan.  Only schedule when the mutation can actually contain a checkbox or dot.
           "var REL434='input[type=checkbox],[role=checkbox],[aria-checked],[class*=a-checkbox],[class*=a-icon-checkbox],[class*=copilot-compare],button[aria-label*=ompare],[role=button][aria-label*=ompare],[data-csa-c-content-id*=ompare],[data-testid*=ompare],img[src*=checkbox],img[data-src*=checkbox],ul.a-pagination.a-dots,[class*=a-pagination][class*=dots]';"
           "function rel434(n){try{if(!n||n.nodeType!==1)return false;if(n.matches&&n.matches(REL434))return true;if(n.closest&&n.closest('ul.a-pagination.a-dots,[class*=a-pagination][class*=dots],[class*=a-checkbox],[class*=copilot-compare],[role=checkbox]'))return true;return !!(n.querySelector&&n.querySelector(REL434));}catch(x){return false;}}"
           // v6.0.94 performance: retire the global post-scroll reconciliation path.
           // Reuse this already-existing filtered observer for the few Heart/cards
           // structures that used to depend on scroll-stop recovery.  No new observer
           // is created; symbol work now wakes only when a relevant node/state changes.
           "var RELSYM6094='[class*=puis-heart-position],[class*=lists-framework-action-button],[class*=lists-framework-heart],[class*=mlt-icon-container]';"
           "function relsym6094(n){try{if(!n||n.nodeType!==1)return false;if(n.matches&&n.matches(RELSYM6094))return true;if(n.closest&&n.closest(RELSYM6094))return true;return !!(n.querySelector&&n.querySelector(RELSYM6094));}catch(x){return false;}}"
           "function qsym6094(){try{if(window.__AD_SYM605_QUEUE__)window.__AD_SYM605_QUEUE__();}catch(x){}}"
           "new MutationObserver(function(ms){try{var qc=0,qs=0;for(var i=0;i<ms.length;i++){var m=ms[i];if(m.type==='attributes'){if(!qc&&rel434(m.target))qc=1;if(!qs&&relsym6094(m.target))qs=1;}var A=m.addedNodes||[];for(var j=0;j<A.length&&(!qc||!qs);j++){var an=A[j];if(!qc&&rel434(an))qc=1;if(!qs&&relsym6094(an))qs=1;}if(qc&&qs)break;}if(qc)queue434(90);if(qs)qsym6094();}catch(x){}}).observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['class','aria-current','aria-checked','aria-pressed','aria-selected','data-checked','data-selected','data-state','checked','src','data-src']});}"
           "stockCheckbox434();setTimeout(stockCheckbox434,40);setTimeout(stockCheckbox434,180);setTimeout(stockCheckbox434,700);setTimeout(stockCheckbox434,1800);"
         "}catch(e){}"
         // Tiny 6.x reapply entry point only. It does not alter either donor owner.
         "window.__AD_SYM605_RUN__=sym413;"
         "window.__AD_SYM605_QUEUE__=function(){try{if(window.__AD_SYM605_Q__)return;window.__AD_SYM605_Q__=1;var f=function(){window.__AD_SYM605_Q__=0;try{window.__AD_HEARTSHELL427__();}catch(x){}try{sym413();}catch(x){}try{window.__AD_CHECKBOX434__&&window.__AD_CHECKBOX434__();}catch(x){}try{window.__AD_DOTFIX374__&&window.__AD_DOTFIX374__();}catch(x){}};if(window.requestIdleCallback)requestIdleCallback(f,{timeout:220});else setTimeout(f,40);}catch(e){}};"
         // v6.0.94: no web scroll listener. Heart/cards recovery is mutation/state
         // driven through the existing filtered checkbox/dot observer above.
         "try{window.__AD_SYM605_QUEUE__();}catch(e){}"
       "return 'sym609';}catch(e){return 'sym609err '+(e&&e.message||e);}})();"];
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
                     NSString *full=ADWhiteTameWebJS(); if(full.length)[wv evaluateJavaScript:full completionHandler:nil];
                 }];
        }
        NSString *js = ADDarkReaderReapply();
        if (js.length) [wv evaluateJavaScript:js completionHandler:nil];

        // Functional self-heal only: diagnostics used to retain URL/state sets here
        // even though logging was compiled out. Ask just the two facts repair needs.
        [wv evaluateJavaScript:
            @"(function(){try{return (!window.__AMZDARK_LOADED__||!(window.DarkReader&&DarkReader.enable))?1:0;}catch(e){return 1;}})()"
             completionHandler:^(id result, NSError *err){
            @try {
                if (err || ![result respondsToSelector:@selector(boolValue)] || ![result boolValue]) return;
                WKUserContentController *ucc = wv.configuration.userContentController;
                Class WKUS = NSClassFromString(@"WKUserScript");
                NSString *boot = ADDarkReaderBootstrap();
                if (ucc && WKUS && boot.length){
                    BOOL present = NO;
                    for (WKUserScript *existing in ucc.userScripts){
                        if ([existing.source containsString:@"__AMZDARK_LOADED__"]){ present = YES; break; }
                    }
                    if (!present){
                        WKUserScript *us = [[WKUS alloc] initWithSource:boot
                                                           injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                        forMainFrameOnly:NO];
                        [ucc addUserScript:us];
                        ADAttachWhiteTameUserScript446(ucc);
                    }
                }
                [wv evaluateJavaScript:
                    @"(function(){try{if(window.__AMZDARK_HEALED__)return 0;window.__AMZDARK_HEALED__=1;return 1;}catch(e){return 1;}})()"
                     completionHandler:^(id heal, NSError *healErr){
                    if (healErr || ![heal respondsToSelector:@selector(boolValue)] || ![heal boolValue]) return;
                    NSString *full = ADDarkReaderBootstrap();
                    if (full.length) [wv evaluateJavaScript:full completionHandler:nil];
                }];
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
        [wv evaluateJavaScript:@"(function(){try{return window.__AMZDARK_LOADED__?1:0;}catch(e){return 0;}})()"
             completionHandler:^(id loaded, NSError *err){
            if (!err && [loaded respondsToSelector:@selector(boolValue)] && [loaded boolValue]) return;
            NSString *js = ADDarkReaderBootstrap();
            if (js.length) [wv evaluateJavaScript:js completionHandler:nil];
            NSString *twb446 = ADWhiteTameWebJS();
            if (twb446.length) [wv evaluateJavaScript:twb446 completionHandler:nil];
            NSString *sym446 = ADThreeSymbolsWebJS605();
            if (sym446.length) [wv evaluateJavaScript:sym446 completionHandler:nil];
        }];
    } @catch(...) {}
}

// v6.0.13: discover pre-warmed web views once, then keep weak references from the
// WKWebView hooks. Screen-change bursts no longer recursively walk every UIKit view
// just to rediscover the same handful of web views.
static NSHashTable *gADWebViews613 = nil;
static BOOL gADWebDiscoveryDone613 = NO;
static void ADTrackWebView613(WKWebView *wv){
    if (!wv) return;
    @try {
        if (!gADWebViews613) gADWebViews613 = [NSHashTable weakObjectsHashTable];
        [gADWebViews613 addObject:wv];
    } @catch(...) {}
}

static void ADWalkWebViews613(UIView *v){
    if (!v) return;
    @try {
        if ([v isKindOfClass:[WKWebView class]]){
            WKWebView *wv=(WKWebView *)v;
            ADTrackWebView613(wv);
            ADPrimeWebBacking611(wv);
            ADEnableDarkReaderIn(wv);
            return; // WKWebView internals cannot contain another app WKWebView.
        }
        for (UIView *s in v.subviews) ADWalkWebViews613(s);
    } @catch(...) {}
}
static void ADInjectAllWebViews(void){
    @try {
        if (!gADWebDiscoveryDone613){
            gADWebDiscoveryDone613 = YES;
            for (UIScene *sc in [UIApplication sharedApplication].connectedScenes){
                if (![sc isKindOfClass:[UIWindowScene class]]) continue;
                for (UIWindow *w in ((UIWindowScene *)sc).windows) ADWalkWebViews613(w);
            }
            return;
        }
        for (WKWebView *wv in gADWebViews613.allObjects){
            if (!wv) continue;
            ADPrimeWebBacking611(wv);
            ADEnableDarkReaderIn(wv);
        }
    } @catch(...) {}
}

// v6.0.98 diagnostic exporter.  The JS ring buffer above reuses an existing DOM
// observer; backgrounding once after reproducing the flash simply dumps that buffer.
static NSString *gADFlashProbePath6131 = nil;
static NSString *ADFlashProbeRequestedPath6131(void){
    return @"/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents/AmazonDark-standalone-ad-probe-6131.txt";
}
static NSString *ADFlashProbeFallbackPath6131(void){
    return [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"AmazonDark-standalone-ad-probe-6131.txt"];
}
static NSString *ADFlashProbePath6101(void){
    return gADFlashProbePath6131 ?: ADFlashProbeFallbackPath6131();
}
static void ADAppendFlashProbe6101(NSString *line){
    if (!line.length) return;
    @try {
        NSString *path=ADFlashProbePath6101();
        NSFileHandle *fh=[NSFileHandle fileHandleForWritingAtPath:path];
        if (!fh){
            NSError *e=nil;
            [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&e];
            return;
        }
        [fh seekToEndOfFile]; [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [fh closeFile];
    } @catch(...) {}
}
static void ADResetFlashProbe6101(void){
    @try {
        NSString *requested=ADFlashProbeRequestedPath6131();
        NSString *fallback=ADFlashProbeFallbackPath6131();
        NSString *base=[NSString stringWithFormat:@"AmazonDark standalone-ad DOM/TWB probe 6131\nversion=%s\npid=%d\nrequested=%@\n",AD_VERSION,getpid(),requested];
        NSError *e=nil;
        BOOL ok=[base writeToFile:requested atomically:YES encoding:NSUTF8StringEncoding error:&e];
        if (ok){
            gADFlashProbePath6131=requested;
            ADAppendFlashProbe6101(@"output=requested-shared-documents\n\n");
            return;
        }
        gADFlashProbePath6131=fallback;
        NSString *h=[base stringByAppendingFormat:@"output=fallback-amazon-documents\nprimaryWriteError=%@ (%ld) %@\nfallback=%@\n\n",e.domain?:@"?",(long)e.code,e.localizedDescription?:@"?",fallback];
        NSError *fe=nil;
        [h writeToFile:fallback atomically:YES encoding:NSUTF8StringEncoding error:&fe];
        if (fe) NSLog(@"[AmazonDark] v6.0.131 probe fallback write failed: %@",fe);
    } @catch(...) {}
}
static void ADDumpFlashProbe6101(NSString *label){
    if (![NSThread isMainThread]){ dispatch_async(dispatch_get_main_queue(), ^{ ADDumpFlashProbe6101(label); }); return; }
    @try {
        NSArray *views=gADWebViews613.allObjects; NSUInteger idx=0;
        ADAppendFlashProbe6101([NSString stringWithFormat:@"DUMP %@ uptime=%.3f webviews=%lu\n",label?:@"?",ADUptime(),(unsigned long)views.count]);
        for (WKWebView *wv in views){
            if (!wv || !wv.window) continue;
            NSString *url=wv.URL.absoluteString?:@""; NSUInteger my=idx++;
            [wv evaluateJavaScript:@"(function(){try{return window.__AD_FLASH6101_DUMP__?window.__AD_FLASH6101_DUMP__():'NO_PROBE';}catch(e){return 'ERR '+String(e);}})();" completionHandler:^(id result,NSError *error){
                NSString *body=error?[NSString stringWithFormat:@"ERROR %@",error]:([result isKindOfClass:[NSString class]]?result:[result description]);
                ADAppendFlashProbe6101([NSString stringWithFormat:@"WEBVIEW %lu %@\n%@\n\n",(unsigned long)my,url,body?:@"(nil)"]);
            }];
        }
        if (!idx) ADAppendFlashProbe6101(@"NO MOUNTED WEBVIEWS\n\n");
    } @catch(...) {}
}
static void ADFlashWillResign6101(CFNotificationCenterRef center, void *observer,
                                  CFStringRef name, const void *object,
                                  CFDictionaryRef userInfo){
    dispatch_async(dispatch_get_main_queue(), ^{ @try { ADDumpFlashProbe6101(@"WILL_RESIGN_ACTIVE"); } @catch(...) {} });
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
    } @catch(...) {}
}
%end

// v6.0.11: keep WebKit's backing surfaces dark, not just the DOM. At 120 Hz a
// very fast fling can expose an unpainted/recycled WebKit tile for a frame or two;
// the screenshot's hard white tail is the backing surface showing through. This is
// constant-time state, not a scroll-time repaint: once the web view/scroll view are
// dark, missing tiles reveal #181a1b instead of UIKit/WebKit white.
static void ADPrimeWebBacking611(WKWebView *wv){
    if (!wv || !gP.enabled || !gP.webDarkReader) return;
    @try {
        UIColor *dark = ADColorFromHex(gP.bgHex);
        wv.opaque = NO;
        wv.backgroundColor = dark;
        UIScrollView *sv = wv.scrollView;
        if (sv) sv.backgroundColor = dark;
        @try { [wv setValue:dark forKey:@"underPageBackgroundColor"]; } @catch(...) {}
    } @catch(...) {}
}

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
    WKWebView *wv = %orig;
    ADTrackWebView613(wv);
    ADPrimeWebBacking611(wv);
    return wv;
}
- (void)didMoveToWindow {
    %orig;
    @try {
        ADTrackWebView613(self);
        if (!self.window || !gP.enabled || !gP.webDarkReader) return;
        ADPrimeWebBacking611(self);
        ADPreDarken(self);   // exact v5.446 instant dark floor for a page that is mid-load
        ADAttachThreeSymbolsUserScript605(self.configuration.userContentController);
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
            }
            objc_setAssociatedObject(self, kUS, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        ADBootstrapDarkReaderIn(self); // engine into the already-rendered document (idempotent)
    } @catch(...) {}
}
- (void)webView:(WKWebView *)wv didFinishNavigation:(id)nav {
    %orig;
    ADTrackWebView613(self);
    ADEnableDarkReaderIn(self);
    // v5.446 direct-port cover release: only a real Amazon page counts.
    @try {
        NSString *nu = wv.URL.absoluteString ?: @"";
        BOOL realPage = ([nu containsString:@"amazon.com"] &&
                         ![nu containsString:@"about:blank"] &&
                         ![nu containsString:@"autocomplete"] &&
                         ![nu containsString:@"/ap/"]);
        if (realPage){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ ADPostAppReady(); });
        }
    } @catch(...) {}
}
%end


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
@interface ADHzProbeTarget : NSObject
@property(nonatomic,assign) NSUInteger frames;
@property(nonatomic,assign) CFTimeInterval firstTS;
@property(nonatomic,assign) double timingHzSum;
@property(nonatomic,assign) NSUInteger timingSamples;
@property(nonatomic,assign) BOOL forceAtStart;
@end
static ADHzProbeTarget *gADHzProbeTarget = nil;
static CADisplayLink *gADHzProbeLink611 = nil;
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
        BOOL legacyUnlocked = [[[NSBundle mainBundle] objectForInfoDictionaryKey:ADPromotionLegacyInfoKey609] boolValue];
        BOOL lowPower = [NSProcessInfo processInfo].lowPowerModeEnabled;
        NSInteger thermal = 0;
        if (@available(iOS 11.0, *)) thermal = [NSProcessInfo processInfo].thermalState;
        double durationHz = link.duration > 0.0001 ? 1.0/link.duration : 0;
        NSInteger preferredFPS = link.preferredFramesPerSecond;
        CAFrameRateRange requested = CAFrameRateRangeMake(0,0,0);
        if (@available(iOS 15.0,*)) requested = link.preferredFrameRateRange;

        id display = ADDisplayForLink610(link);
        BOOL forceAPI = display && [display respondsToSelector:NSSelectorFromString(@"overrideMinimumFrameDuration:")];
        BOOL reasonAPI = [link respondsToSelector:NSSelectorFromString(@"setHighFrameRateReason:")];
        double displayHz = 0, linkMaxHz = 0;
        NSInteger actualFPS = 0, minFrameDuration = 0;
        SEL refreshSel = NSSelectorFromString(@"refreshRate");
        if (display && [display respondsToSelector:refreshSel]) displayHz = ((double(*)(id,SEL))objc_msgSend)(display,refreshSel);
        SEL maxSel = NSSelectorFromString(@"maximumRefreshRate");
        if ([link respondsToSelector:maxSel]) linkMaxHz = ((double(*)(id,SEL))objc_msgSend)(link,maxSel);
        SEL actualSel = NSSelectorFromString(@"actualFramesPerSecond");
        if ([link respondsToSelector:actualSel]) actualFPS = ((NSInteger(*)(id,SEL))objc_msgSend)(link,actualSel);
        SEL minSel = NSSelectorFromString(@"minimumFrameDuration");
        if ([link respondsToSelector:minSel]) minFrameDuration = ((NSInteger(*)(id,SEL))objc_msgSend)(link,minSel);

        NSString *report = [NSString stringWithFormat:
            @"AmazonDark %@\nforce120Hz=%d\nscreenMax=%ld\nbundleHighRefreshUnlocked=%d\nbundleLegacyUnlocked=%d\nlowPowerMode=%d\nthermalState=%ld\nprivateDisplayForceAPI=%d\nprivateDisplayForceHook=%d\nprivateDisplayForceActive=%d\nhighFrameRateReasonAPI=%d\ndisplayRefreshRate=%.1f\nlinkMaximumRefreshRate=%.1f\nrequestedRange=%.1f-%.1f preferred=%.1f\npreferredFPS=%ld\nactualFPS=%ld\nminimumFrameDuration=%ld\ndurationHz=%.1f\ncallbackHz=%.1f\ntargetTimingHz=%.1f\n",
            @AD_VERSION, self.forceAtStart ? 1 : 0, (long)maxHz, unlocked ? 1 : 0, legacyUnlocked ? 1 : 0,
            lowPower ? 1 : 0, (long)thermal, forceAPI ? 1 : 0,
            gADCADisplayOverrideInstalled610 ? 1 : 0, self.forceAtStart ? 1 : 0, reasonAPI ? 1 : 0,
            displayHz, linkMaxHz, requested.minimum, requested.maximum, requested.preferred,
            (long)preferredFPS, (long)actualFPS, (long)minFrameDuration,
            durationHz, callbackHz, timingHz];
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"AmazonDark-hz.txt"];
        [report writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [link invalidate]; gADHzProbeTarget = nil; gADHzProbeLink611 = nil;
    } @catch(...) { [link invalidate]; gADHzProbeTarget=nil; gADHzProbeLink611=nil; }
}
@end
static void ADStopHzVerification611(void){
    @try { if (gADHzProbeLink611) [gADHzProbeLink611 invalidate]; } @catch(...) {}
    gADHzProbeLink611 = nil; gADHzProbeTarget = nil; gADHzProbeDone = NO;
}
static void ADStartHzVerification(void){
    @try {
        if (!gP.enabled || gADHzProbeDone || gADHzProbeTarget) return;
        gADHzProbeDone = YES;
        ADHzProbeTarget *p = [ADHzProbeTarget new];
        p.forceAtStart = ADPromotionPreferenceOn611();
        CADisplayLink *d = [CADisplayLink displayLinkWithTarget:p selector:@selector(tick:)];
        gADHzProbeTarget=p; gADHzProbeLink611=d;
        [d addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    } @catch(...) { gADHzProbeTarget=nil; gADHzProbeLink611=nil; }
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

// v6.0.77: UIKit owns the real scroll-indicator thumb.  The v6.0.74 ownership
// probe showed its private _UIScrollViewScrollIndicator wrapper contains a plain
// UIView whose light thumb background was being fed back through our generic
// native background curve and mapped to #181a1b.  Recognise only that tiny
// private indicator subtree so UIKit's UIScrollViewIndicatorStyleWhite pixels
// survive unchanged.  This is not a custom scrollbar painter.
static BOOL ADInNativeScrollIndicator6077(UIView *v){
    UIView *p=v; int d=0;
    while (p && d++ < 4){
        const char *cn=object_getClassName(p);
        if (cn && strstr(cn, "UIScrollViewScrollIndicator")) return YES;
        p=p.superview;
    }
    return NO;
}

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
static BOOL gADBarImageWriting6069 = NO;
static void ADTintBarIcon(UIImageView *iv, BOOL selected){
    @try {
        UIImage *img = iv.image;
        if (!img) return;
        // Templatise so the tint takes. A bitmap icon ignores tintColor, which is why
        // the dark bitmaps stayed dark; a template renders entirely in its tint.
        if (!ADImageIsTemplateish(img)){
            UIImage *tpl = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            if (tpl){
                ADMarkModifiedImage(tpl);
                gADBarImageWriting6069 = YES;
                @try { iv.image = tpl; } @catch(...) {}
                gADBarImageWriting6069 = NO;
            }
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

// v6.0.28: Amazon's Home nav is intentionally "transparent" so it can sample the
// active hero/ad card and tint the chrome to that card's average colour.  The old
// broad scroll recovery happened to repaint this view after the adaptive update;
// v6.0.19 correctly removed that expensive recovery but left this actual owner
// unclaimed.  Own only ANXTopNavBackgroundView here -- not every nav/search view.
// Catch nil/clear assignments too: transparency is precisely how the carousel colour
// leaks through.  isKindOfClass keeps subclasses/KVO wrappers covered.
static BOOL ADIsAdaptiveTopNavBackgroundView(id obj){
    if (!obj) return NO;
    @try {
        Class c = NSClassFromString(@"ANXTopNavBackgroundView");
        if (c && [obj isKindOfClass:c]) return YES;
        const char *cn = object_getClassName(obj);
        return cn && strstr(cn, "ANXTopNavBackgroundView");
    } @catch(...) {}
    return NO;
}

%hook UIView
- (void)setBackgroundColor:(UIColor *)color {
    // Authoritative Home top-chrome lock.  This intentionally precedes the nil/own
    // guards because Amazon's adaptive-nav implementation frequently clears the fill
    // to reveal/sample the carousel underneath.
    @try {
        if (ADRecolorOn() && ADIsAdaptiveTopNavBackgroundView(self)) {
            UIColor *locked = ADColorFromHex(gP.bgHex);
            %orig(locked);
            return;
        }
    } @catch(...) {}
    // UIKit's private scroll-thumb views are already styled by the authoritative
    // UIScrollViewIndicatorStyleWhite owner below.  Do not feed their system color
    // through the generic background curve or the white thumb becomes dark again.
    @try {
        if (ADRecolorOn() && ADInNativeScrollIndicator6077(self)) {
            %orig;
            return;
        }
    } @catch(...) {}
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

// v6.0.13: the old implementation hooked UIView layoutSubviews globally just to
// reach this one RN SVG class plus tiny RN-hosted UILabel glyphs. Hook the actual
// owners instead so ordinary views pay zero SVG-probe cost.
%hook RNSVGSvgView
- (void)didMoveToWindow {
    %orig;
    @try { if (gP.enabled && self.window) ADInvertRNSVG(self); } @catch(...) {}
}
- (void)layoutSubviews {
    %orig;
    @try { if (gP.enabled && self.window) ADInvertRNSVG(self); } @catch(...) {}
}
%end

// v6.0.53: compact rendered-peer TWB ownership.
// v6.0.51 proved that the unresolved Person images are ordinary RCTUIImageViews
// whose rendered peers already carry the correct overlay. The failed heading
// registry is removed entirely; ownership now stays image/event driven.
static const void *kADWhiteTameOverlayKey = &kADWhiteTameOverlayKey;
static const void *kADPeerWakeImage6053 = &kADPeerWakeImage6053;
static const void *kADPeerRegistered6053 = &kADPeerRegistered6053;
static const void *kADPeerNegativeImage6055 = &kADPeerNegativeImage6055;
static const void *kADPeerNegativeGeneration6055 = &kADPeerNegativeGeneration6055;
static const void *kADPeerNegativeSize6055 = &kADPeerNegativeSize6055;
static NSHashTable *ADNativeRCTViews6053(void){
    static NSHashTable *t; static dispatch_once_t once;
    dispatch_once(&once, ^{ t=[NSHashTable weakObjectsHashTable]; });
    return t;
}
static BOOL gADPeerWake6053=NO;
static NSUInteger gADPeerGeneration6055=1;
static BOOL ADNativeTWBUIChain6027(UIImageView *iv);
static void ADNativeClearPeerNegative6055(UIImageView *iv){
    if(!iv) return;
    objc_setAssociatedObject(iv,kADPeerNegativeImage6055,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(iv,kADPeerNegativeGeneration6055,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(iv,kADPeerNegativeSize6055,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void ADNativeResetRCTRegistration6055(UIImageView *iv){
    if(!iv) return;
    @try { [ADNativeRCTViews6053() removeObject:iv]; } @catch(...) {}
    objc_setAssociatedObject(iv,kADPeerRegistered6053,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL ADNativeRCTCandidate6053(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||iv.hidden||iv.alpha<.01) return NO;
    const char *cn=object_getClassName(iv);
    if(!cn||!strstr(cn,"RCTUIImageView")) return NO;
    CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
    if(w<60||h<60||w>220||h>220) return NO;
    CGFloat ratio=(h>0)?w/h:99; if(ratio<1) ratio=1/ratio;
    if(ratio>1.9) return NO;
    if(iv.image.renderingMode==UIImageRenderingModeAlwaysTemplate||ADImageIsTemplateish(iv.image)) return NO;
    return !ADNativeTWBUIChain6027(iv);
}
static void ADNativeRegisterRCT6053(UIImageView *iv){
    if(!iv||objc_getAssociatedObject(iv,kADPeerRegistered6053)) return;
    @try {
        if(ADNativeRCTCandidate6053(iv)){
            [ADNativeRCTViews6053() addObject:iv];
            objc_setAssociatedObject(iv,kADPeerRegistered6053,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } @catch(...) {}
}
static BOOL ADNativePeerMatch6053(UIImageView *source, CGRect sr, UIImageView *peer){
    if(!peer||peer==source||peer.window!=source.window||peer.hidden||peer.alpha<.01||!peer.image||
       !objc_getAssociatedObject(peer,kADPeerRegistered6053)) return NO;
    CGFloat sw=source.bounds.size.width,sh=source.bounds.size.height;
    CGFloat pw=peer.bounds.size.width,ph=peer.bounds.size.height;
    if(pw<60||ph<60||pw>220||ph>220||fabs(sw-pw)>4.0||fabs(sh-ph)>4.0) return NO;
    CGFloat ratio=(ph>0)?pw/ph:99; if(ratio<1) ratio=1/ratio;
    if(ratio>1.9||peer.image.renderingMode==UIImageRenderingModeAlwaysTemplate||ADImageIsTemplateish(peer.image)) return NO;
    CGRect pr=[peer convertRect:peer.bounds toView:peer.window];
    CGFloat rowTol=MAX(14.0,MIN(sh,ph)*0.28);
    return fabs(CGRectGetMidY(sr)-CGRectGetMidY(pr))<=rowTol &&
           fabs(CGRectGetMidX(sr)-CGRectGetMidX(pr))<=900.0;
}
static BOOL ADNativePeerConsensus6053(UIImageView *iv){
    if(!ADNativeRCTCandidate6053(iv)) return NO;
    ADNativeRegisterRCT6053(iv);
    @try {
        UIImage *im=iv.image;
        NSNumber *ng=objc_getAssociatedObject(iv,kADPeerNegativeGeneration6055);
        UIImage *ni=objc_getAssociatedObject(iv,kADPeerNegativeImage6055);
        NSValue *ns=objc_getAssociatedObject(iv,kADPeerNegativeSize6055);
        if(ni==im&&ng.unsignedIntegerValue==gADPeerGeneration6055&&ns&&CGSizeEqualToSize(ns.CGSizeValue,iv.bounds.size)) return NO;
        CGRect ir=[iv convertRect:iv.bounds toView:iv.window];
        int positive=0;
        for(UIImageView *p in ADNativeRCTViews6053()){
            if(!ADNativePeerMatch6053(iv,ir,p)) continue;
            CALayer *ov=objc_getAssociatedObject(p,kADWhiteTameOverlayKey);
            if(ov&&ov.superlayer==p.layer&&++positive>=2){ ADNativeClearPeerNegative6055(iv); return YES; }
        }
        objc_setAssociatedObject(iv,kADPeerNegativeImage6055,im,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(iv,kADPeerNegativeGeneration6055,@(gADPeerGeneration6055),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(iv,kADPeerNegativeSize6055,[NSValue valueWithCGSize:iv.bounds.size],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(...) {}
    return NO;
}
static void ADNativeWakePeers6053(UIImageView *source){
    if(gADPeerWake6053||!source) return;
    UIImage *im=source.image;
    if(!im||objc_getAssociatedObject(source,kADPeerWakeImage6053)==im) return;
    if(!ADNativeRCTCandidate6053(source)) return;
    @try {
        objc_setAssociatedObject(source,kADPeerWakeImage6053,im,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADNativeRegisterRCT6053(source);
        CGRect sr=[source convertRect:source.bounds toView:source.window];
        gADPeerWake6053=YES;
        for(UIImageView *p in ADNativeRCTViews6053()){
            if(!ADNativePeerMatch6053(source,sr,p)) continue;
            CALayer *ov=objc_getAssociatedObject(p,kADWhiteTameOverlayKey);
            if(!ov||ov.superlayer!=p.layer) ADApplyNativeWhiteTameView(p);
        }
    } @catch(...) {}
    gADPeerWake6053=NO;
}

%hook UILabel
- (void)didMoveToWindow {
    %orig;
    @try { if (ADRecolorOn() && self.window) ADInvertRNSVG(self); } @catch(...) {}
}
- (void)layoutSubviews {
    %orig;
    @try { if (ADRecolorOn() && self.window) ADInvertRNSVG(self); } @catch(...) {}
}
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
    // Amazon can bypass UIView and drive the adaptive Home nav's backing layer
    // directly.  Mirror the view-level lock so neither direct-layer updates nor a
    // transparent clear can hand the chrome back to carousel colour sampling.
    @try {
        id d = self.delegate;
        if (ADRecolorOn() && ADIsAdaptiveTopNavBackgroundView(d)) {
            UIColor *locked = ADColorFromHex(gP.bgHex);
            CGColorRef lockedCG = locked.CGColor;
            %orig(lockedCG);
            return;
        }
    } @catch(...) {}
    // Same scroll-thumb exemption at the backing-layer level: UIKit may update
    // the indicator fill directly on CALayer instead of UIView.backgroundColor.
    @try {
        id d=self.delegate;
        if (ADRecolorOn() && [d isKindOfClass:[UIView class]] &&
            ADInNativeScrollIndicator6077((UIView *)d)) {
            %orig;
            return;
        }
    } @catch(...) {}
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
    %orig;
    if (!contents || !gP.enabled || !gP.whiteTame) return;
    @try {
        id d=self.delegate;
        if (d && [d isKindOfClass:[UIImageView class]]){
            UIImageView *iv=(UIImageView *)d;
            if (iv.window && !ADIsWebKitOwned(iv)) ADApplyNativeWhiteTameView(iv);
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
// v6.0.28: direct owner for Amazon's adaptive/transparent Home top-nav backdrop.
// This view is what the Home carousel retints.  Reasserting here is O(1) and replaces
// the old accidental dependency on broad scroll-time hierarchy recovery.
%hook ANXTopNavBackgroundView
- (void)setBackgroundColor:(UIColor *)color {
    if (!ADRecolorOn()) {
        %orig;
        return;
    }
    UIColor *locked = ADColorFromHex(gP.bgHex);
    %orig(locked);
}
- (void)didMoveToWindow {
    %orig;
    @try {
        if (ADRecolorOn() && self.window) {
            UIColor *locked = ADColorFromHex(gP.bgHex);
            self.backgroundColor = locked;
            self.layer.backgroundColor = locked.CGColor;
        }
    } @catch(...) {}
}
- (void)layoutSubviews {
    %orig;
    @try {
        if (ADRecolorOn() && self.window) {
            UIColor *locked = ADColorFromHex(gP.bgHex);
            self.backgroundColor = locked;
            self.layer.backgroundColor = locked.CGColor;
        }
    } @catch(...) {}
}
%end

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


// WKScrollView is deliberately the only WebKit internal view we recolour. Dark
// Reader owns page content; this hook owns only the scroll view's empty backing.
%hook WKScrollView
- (void)setBackgroundColor:(UIColor *)color {
    if (gP.enabled && gP.webDarkReader){
        UIColor *dark611 = ADColorFromHex(gP.bgHex);
        %orig(dark611);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    @try { if (self.window && gP.enabled && gP.webDarkReader) self.backgroundColor = ADColorFromHex(gP.bgHex); } @catch(...) {}
}
%end

// v6.0.12: WKContentView is the inner WebKit canvas that spans the scrollable page.
// v6.0.11 only owned WKWebView/WKScrollView; when WebKit outran lazy tile painting,
// this inner canvas could still paint its stock white background over both of them.
// Own ONLY the root content canvas -- never WKCompositingView/tile layers -- so media
// and Dark Reader compositing stay untouched while an unpainted hole has a dark floor.
%hook WKContentView
- (void)setBackgroundColor:(UIColor *)color {
    if (gP.enabled && gP.webDarkReader){
        UIColor *dark612 = ADColorFromHex(gP.bgHex);
        %orig(dark612);
        return;
    }
    %orig;
}
- (void)setOpaque:(BOOL)opaque {
    if (gP.enabled && gP.webDarkReader){
        %orig(YES);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    @try {
        if (!self.window || !gP.enabled || !gP.webDarkReader) return;
        UIColor *dark612 = ADColorFromHex(gP.bgHex);
        self.opaque = YES;
        self.backgroundColor = dark612;
        self.layer.backgroundColor = dark612.CGColor;
    } @catch(...) {}
}
- (void)layoutSubviews {
    %orig;
    @try {
        if (!self.window || !gP.enabled || !gP.webDarkReader) return;
        UIColor *dark612 = ADColorFromHex(gP.bgHex);
        // Layer assignment closes the path where WebKit updates the backing layer
        // directly rather than going through UIView setBackgroundColor:.
        self.layer.backgroundColor = dark612.CGColor;
    } @catch(...) {}
}
%end

%hook UIScrollView
- (void)didMoveToWindow {
    %orig;
    @try { if (ADRecolorOn() && self.window) self.indicatorStyle = UIScrollViewIndicatorStyleWhite; } @catch(...) {}
}
// v6.0.76: didMoveToWindow was only a one-time request. Amazon/WebKit/RN can
// assign the style again after mount, which silently returns the thumb to dark.
// Own the public UIScrollView style setter instead of painting private indicator
// views, so native geometry, alpha, fade timing, and both axes remain untouched.
- (void)setIndicatorStyle:(UIScrollViewIndicatorStyle)style {
    if (ADRecolorOn()) {
        %orig(UIScrollViewIndicatorStyleWhite);
        return;
    }
    %orig;
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
static const void *kADWhiteTameLightKey363 = &kADWhiteTameLightKey363;
static const void *kADWhiteTameLightPending6056 = &kADWhiteTameLightPending6056;
// v6.0.56: first-time pixel sampling used to draw/decode the image synchronously on
// the main thread. Keep the exact 12x12 classifier, but perform that one-time read on
// a utility queue and re-enter the existing owner when the result is ready.
static BOOL ADWTImageLight363(UIImageView *iv, UIImage *im, BOOL *ready){
    if(ready) *ready=NO;
    if(!iv||!im) return NO;
    @try {
        NSNumber *c=objc_getAssociatedObject(im,kADWhiteTameLightKey363);
        if(c){ if(ready)*ready=YES; return c.boolValue; }
        UIImage *pending=objc_getAssociatedObject(iv,kADWhiteTameLightPending6056);
        if(pending==im) return NO;
        objc_setAssociatedObject(iv,kADWhiteTameLightPending6056,im,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UIImageView *weakIV=iv;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
            BOOL ok=ADImageMostlyLight(im);
            dispatch_async(dispatch_get_main_queue(), ^{
                @try {
                    objc_setAssociatedObject(im,kADWhiteTameLightKey363,@(ok),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    UIImageView *live=weakIV;
                    if(!live) return;
                    if(objc_getAssociatedObject(live,kADWhiteTameLightPending6056)==im)
                        objc_setAssociatedObject(live,kADWhiteTameLightPending6056,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    if(live.image==im&&live.window) ADApplyNativeWhiteTameView(live);
                } @catch(...) {}
            });
        });
    } @catch(...) {}
    return NO;
}

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
static UIView *ADMenuRoot382(UIView *v);
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
// v5.382: return to the v5.365 local-section model that originally fixed the
// sibling React/Fabric Person panes. Nearest compact section ownership is decisive;
// broad window headings are only a fallback. Customer Service is explicitly negative.
// v6.0.55: cache each compact wrapper result briefly so sibling product images do not
// repeat the same bounded text walk while a React card is being recycled/layouted.
static const void *kADWTLocalCtx6055 = &kADWTLocalCtx6055;
static const void *kADWTLocalTime6055 = &kADWTLocalTime6055;
static int ADWTLocalSection365(UIView *v){
    @try {
        UIWindow *w=v.window; UIView *p=v; int up=0;
        while(p && up++<7){
            CGFloat h=p.bounds.size.height, ww=p.bounds.size.width;
            if(h>=40 && h<=760 && ww>=40 && (!w || ww<=w.bounds.size.width*1.25)){
                CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
                NSNumber *ct=objc_getAssociatedObject(p,kADWTLocalTime6055);
                NSNumber *cc=objc_getAssociatedObject(p,kADWTLocalCtx6055);
                if(ct&&cc){
                    CFAbsoluteTime age=now-ct.doubleValue; int cv=cc.intValue;
                    if((cv!=0&&age<2.0)||(cv==0&&age<0.20)){
                        if(cv) return cv;
                        p=p.superview; continue;
                    }
                }
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
                       [lo containsString:@"keep shopping for"] || [lo containsString:@"your interests"] ||
                       [lo containsString:@"buy again"] || [lo containsString:@"alexa for shopping"] ||
                       [lo containsString:@"lists and registries"] || [lo containsString:@"lists & registries"]) product=YES;
                    if(qi<28){ for(UIView *sv in x.subviews){ if(q.count<90) [q addObject:sv]; else break; } }
                }
                int result=0;
                if(neg && h<=280) result=1;
                else if(reviews) result=3;
                else if(product) result=2;
                else if(neg) result=1;
                objc_setAssociatedObject(p,kADWTLocalCtx6055,@(result),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(p,kADWTLocalTime6055,@(now),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                if(result) return result;
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
                                            [lo containsString:@"keep shopping for"]||[lo containsString:@"shop previously watched"]||
                                            [lo containsString:@"your interests"]||[lo containsString:@"buy again"]||
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
        UIImage *cur=iv.image,*orig=objc_getAssociatedObject(cur,kADOrigImageKey);
        BOOL changed=(orig!=nil || cur.renderingMode!=UIImageRenderingModeAlwaysOriginal);
        if(changed){
            UIImage *want=orig ?: [cur imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            if(want){ gADGlyphWriting=YES; iv.image=want; gADGlyphWriting=NO; }
            iv.tintColor=nil;
        }
    } @catch(...) {}
}

// v6.0.31: direct semantic section ownership for the small Person/Alexa media that
// v5.446 deliberately forced into TWB. The donor found these with window-wide heading
// bands and carousel subtree scans. Production now inspects only a tiny compact local
// neighborhood when a new UIImage appears, caches the result, and never discovers it
// from a scroll callback.
static const void *kADTWBDirectCtx6031 = &kADTWBDirectCtx6031;
static const void *kADTWBDirectCtxImage6031 = &kADTWBDirectCtxImage6031;
static const void *kADTWBDirectCtxTime6031 = &kADTWBDirectCtxTime6031;
static const void *kADTWBDirectCtxAttempts6031 = &kADTWBDirectCtxAttempts6031;

// 0 ordinary; 1 explicit no-TWB; 2 forced product/Alexa media; 3 Reviews photo.
static int ADTWBTextKind6031(NSString *text){
    if(!text.length) return 0;
    NSString *lo=[[text lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(!lo.length) return 0;
    if([lo containsString:@"medical care"] || [lo containsString:@"your amazon highlights"] ||
       [lo containsString:@"need help"] || [lo containsString:@"contact customer service"] ||
       [lo isEqualToString:@"customer service"]) return 1;
    if([lo containsString:@"your reviews"] || [lo containsString:@"what did you think of the item"]) return 3;
    if([lo containsString:@"shop previously watched"] ||
       [lo containsString:@"your interests"] || [lo containsString:@"buy again"] ||
       [lo containsString:@"lists and registries"] || [lo containsString:@"lists & registries"] ||
       [lo containsString:@"alexa for shopping"] ||
       [lo containsString:@"subscribe & save"] || [lo containsString:@"subscribe and save"] ||
       [lo containsString:@"keep shopping for"] || [lo hasPrefix:@"best deals on"] ||
       [lo containsString:@"returns are easy"] || [lo containsString:@"send an amazon gift card"]) return 2;
    return 0;
}

static int ADTWBDirectLocalCtx6031(UIImageView *iv){
    if(!iv||!iv.window) return 0;
    @try {
        // Reuse the exact retained v5.446 compact-section/carousel resolvers, but
        // only here at direct image assignment/reparent time. Their old scroll/window
        // scheduler remains disabled, so the detailed Person/Alexa semantics survive
        // without returning to scan-on-scroll behavior.
        BOOL reactish=NO; UIView *rp=iv; int ru=0;
        while(rp&&ru++<6){
            const char *rc=object_getClassName(rp);
            if(rc&&(strstr(rc,"RCT")||strstr(rc,"React")||strstr(rc,"Fabric"))){reactish=YES;break;}
            rp=rp.superview;
        }
        if(reactish){
            int cc=ADWTCarouselSection384(iv);
            // A positive carousel cache is already authoritative; avoid repeating the
            // local wrapper walk for every sibling image in the same section.
            if(cc==3) return 3;
            if(cc==2) return 2;
            int lc=ADWTLocalSection365(iv);
            // v6.0.42: a compact positive local section may override an outer mixed
            // carousel exclusion, so cc==1 still consults local ownership.
            if(lc==3) return 3;
            if(lc==2) return 2;
            if(cc==1 || lc==1) return 1;
            // ADWTLocalSection365 covers the full retained Person/Alexa vocabulary.
            // Do not immediately perform a second sibling-text walk for React images.
            return 0;
        }
        UIView *p=iv; int up=0;
        while(p&&up++<7){
            CGFloat ph=p.bounds.size.height,pw=p.bounds.size.width;
            if(ph>=36&&ph<=820&&pw>=36){
                int own=ADTWBTextKind6031(ADWTViewText362(p));
                if(own) return own;
                NSArray *a=p.subviews; NSUInteger lim=MIN((NSUInteger)14,a.count);
                int neg=0,pos=0,rev=0;
                for(NSUInteger i=0;i<lim;i++){
                    UIView *x=a[i]; int k=ADTWBTextKind6031(ADWTViewText362(x));
                    if(k==1)neg=1; else if(k==2)pos=1; else if(k==3)rev=1;
                    NSArray *b=x.subviews; NSUInteger lim2=MIN((NSUInteger)8,b.count);
                    for(NSUInteger j=0;j<lim2;j++){
                        int q=ADTWBTextKind6031(ADWTViewText362(b[j]));
                        if(q==1)neg=1; else if(q==2)pos=1; else if(q==3)rev=1;
                    }
                }
                // Named product/review ownership wins in a mixed Person wrapper;
                // compact Help/Medical wrappers remain explicit exclusions.
                if(rev) return 3;
                if(pos) return 2;
                if(neg&&ph<=300) return 1;
            }
            p=p.superview;
        }
    } @catch(...) {}
    return 0;
}

static int ADTWBDirectCtx6031(UIImageView *iv, UIImage *im){
    if(!iv||!im) return 0;
    @try {
        UIImage *ci=objc_getAssociatedObject(iv,kADTWBDirectCtxImage6031);
        NSNumber *cv=objc_getAssociatedObject(iv,kADTWBDirectCtx6031);
        NSNumber *ct=objc_getAssociatedObject(iv,kADTWBDirectCtxTime6031);
        NSNumber *ca=objc_getAssociatedObject(iv,kADTWBDirectCtxAttempts6031);
        CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
        if(ci==im&&cv){
            int v=cv.intValue;
            if(v!=0) return v;
            NSInteger attempts=ca.integerValue;
            // React can assign the bitmap just before its sibling heading hydrates.
            // One spaced negative re-probe is enough for late React heading hydration;
            // after that, settle this UIImage instead of rescanning during layouts.
            if(attempts>=1 || (ct&&now-ct.doubleValue<0.28)) return 0;
        }
        int k=ADTWBDirectLocalCtx6031(iv);
        NSInteger attempts=(ci==im&&ca)?ca.integerValue+1:0;
        objc_setAssociatedObject(iv,kADTWBDirectCtxImage6031,im,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(iv,kADTWBDirectCtx6031,@(k),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(iv,kADTWBDirectCtxTime6031,@(now),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(iv,kADTWBDirectCtxAttempts6031,@(attempts),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return k;
    } @catch(...) {}
    return 0;
}

// v6.0.53 direct native TWB owner. Classification is image/event driven and cached
// for the exact UIImage. Once ownership and semantic context settle, layout only
// maintains the existing CALayer; it does not rediscover the section.
static const void *kADTWBCachedImage6027 = &kADTWBCachedImage6027;
static const void *kADTWBDecision6027 = &kADTWBDecision6027;

static UIColor *ADWhiteTameShade6053(void){
    static NSInteger last=-1000; static UIColor *shade=nil;
    NSInteger cur=MAX(0,MIN(100,gP.whiteTameStrength));
    if(!shade||last!=cur){ shade=[UIColor colorWithWhite:0 alpha:0.50*(cur/100.0)]; last=cur; }
    return shade;
}
static void ADNativeTWBStyleOverlay6053(UIImageView *iv, CALayer *ov){
    if(!iv||!ov) return;
    CGRect b=iv.bounds; if(!CGRectEqualToRect(ov.frame,b)) ov.frame=b;
    CGFloat cr=iv.layer.cornerRadius; if(fabs(ov.cornerRadius-cr)>.01) ov.cornerRadius=cr;
    CGColorRef shade=ADWhiteTameShade6053().CGColor;
    if(!ov.backgroundColor||!CGColorEqualToColor(ov.backgroundColor,shade)) ov.backgroundColor=shade;
    if(ov.zPosition!=9999) ov.zPosition=9999;
}
static void ADNativeTWBRelease6027(UIImageView *iv){
    if(!iv) return;
    @try {
        CALayer *ov=objc_getAssociatedObject(iv,kADWhiteTameOverlayKey);
        if(ov){ [ov removeFromSuperlayer]; objc_setAssociatedObject(iv,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    } @catch(...) {}
}
static void ADTWBResetSemantic6031(UIImageView *iv){
    if(!iv) return;
    objc_setAssociatedObject(iv,kADTWBDirectCtxImage6031,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(iv,kADTWBDirectCtx6031,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(iv,kADTWBDirectCtxTime6031,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(iv,kADTWBDirectCtxAttempts6031,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void ADTWBPromoteProduct6053(UIImageView *iv, UIImage *im){
    objc_setAssociatedObject(iv,kADTWBCachedImage6027,im,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(iv,kADTWBDecision6027,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(iv,kADTWBDirectCtxImage6031,im,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(iv,kADTWBDirectCtx6031,@2,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(iv,kADTWBDirectCtxTime6031,@(CFAbsoluteTimeGetCurrent()),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(iv,kADTWBDirectCtxAttempts6031,@0,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL ADNativeTWBUIChain6027(UIImageView *iv){
    if(!iv) return YES;
    @try {
        if(ADInTabBarChain(iv)||ADIsChromeGlyphContext(iv)) return YES;
        UIView *p=iv; int up=0;
        while(p&&up++<6){
            const char *c=object_getClassName(p);
            if(c&&(strstr(c,"Button")||strstr(c,"Search")||strstr(c,"Navigation")||
                   strstr(c,"TabBar")||strstr(c,"Icon")||strstr(c,"Glyph")||
                   strstr(c,"Symbol")||strstr(c,"Avatar")||strstr(c,"Profile")||
                   strstr(c,"Logo")||strstr(c,"Badge")||strstr(c,"Checkbox")||
                   strstr(c,"Radio")||strstr(c,"Rating")||strstr(c,"Star"))) return YES;
            p=p.superview;
        }
        NSString *aid=[iv.accessibilityIdentifier lowercaseString];
        if(aid.length&&([aid containsString:@"icon"]||[aid containsString:@"logo"]||
                       [aid containsString:@"avatar"]||[aid containsString:@"profile"]||
                       [aid containsString:@"search"]||[aid containsString:@"history"]||
                       [aid containsString:@"close"]||[aid containsString:@"share"]||
                       [aid containsString:@"camera"]||[aid containsString:@"microphone"])) return YES;
    } @catch(...) {}
    return NO;
}

static void ADApplyNativeWhiteTameView(UIView *v){
    if(![v isKindOfClass:[UIImageView class]]) return;
    UIImageView *iv=(UIImageView *)v;
    @try {
        UIImage *im=iv.image;
        if(!gP.enabled||!gP.whiteTame||!iv.window||ADIsWebKitOwned(iv)||!im){
            ADNativeTWBRelease6027(iv);
            objc_setAssociatedObject(iv,kADTWBCachedImage6027,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(iv,kADTWBDecision6027,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            ADTWBResetSemantic6031(iv);
            return;
        }
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        if(w<1||h<1) return; // wait for settled geometry; do not cache the miss
        // These gates are unconditional even for forced product context. Reject them
        // before any section discovery so tiny RCT chrome never pays semantic work.
        if(w<28||h<28||w>1200||h>1200||ADInTabBarChain(iv)){
            ADNativeTWBRelease6027(iv);
            return;
        }

        UIImage *cached=objc_getAssociatedObject(iv,kADTWBCachedImage6027);
        NSNumber *decision=objc_getAssociatedObject(iv,kADTWBDecision6027);
        UIImage *ctxImage=objc_getAssociatedObject(iv,kADTWBDirectCtxImage6031);
        NSNumber *ctxValue=objc_getAssociatedObject(iv,kADTWBDirectCtx6031);
        NSNumber *ctxAttempts=objc_getAssociatedObject(iv,kADTWBDirectCtxAttempts6031);
        CALayer *ov=objc_getAssociatedObject(iv,kADWhiteTameOverlayKey);
        BOOL semanticSettled=(ctxImage==im&&ctxValue&&(ctxValue.intValue!=0||ctxAttempts.integerValue>=1));
        if(ov&&ov.superlayer==iv.layer&&cached==im&&decision.boolValue&&semanticSettled){
            ADNativeTWBStyleOverlay6053(iv,ov);
            return;
        }

        ADNativeRegisterRCT6053(iv);
        int ctx=(w<=240&&h<=240)?ADTWBDirectCtx6031(iv,im):0;
        BOOL forced=(ctx==2), review=(ctx==3);
        BOOL own=NO, lightReady=YES;

        if(forced||review){
            own=YES;
            objc_setAssociatedObject(iv,kADTWBCachedImage6027,im,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(iv,kADTWBDecision6027,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(ctx!=1 && cached==im && decision){
            own=decision.boolValue;
        } else if(ctx!=1){
            own=ADWTImageLight363(iv,im,&lightReady);
            if(lightReady){
                objc_setAssociatedObject(iv,kADTWBCachedImage6027,im,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(iv,kADTWBDecision6027,@(own),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }

        // The proven v6.0.51 behavior remains the final authority for an image that
        // would otherwise be rejected, including a broad ctx==1 false negative.
        if(!own && ADNativePeerConsensus6053(iv)){
            own=YES; ctx=2; forced=YES; review=NO; lightReady=YES;
            ADTWBPromoteProduct6053(iv,im);
        }
        if(!own&&!lightReady){ ADNativeTWBRelease6027(iv); return; }
        if(!own||ctx==1){ ADNativeTWBRelease6027(iv); return; }

        CGFloat minDim=forced?28:(review?30:48);
        if(w<minDim||h<minDim||(review&&(w>200||h>200))||
           ((!forced)&&(ADImageIsTemplateish(im)||ADNativeTWBUIChain6027(iv)))){
            ADNativeTWBRelease6027(iv);
            return;
        }

        ov=objc_getAssociatedObject(iv,kADWhiteTameOverlayKey);
        BOOL newPeerPositive=NO;
        if(!ov){
            ov=[CALayer layer]; ov.name=@"AmazonDarkWhiteTame6027";
            [iv.layer addSublayer:ov];
            objc_setAssociatedObject(iv,kADWhiteTameOverlayKey,ov,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            newPeerPositive=(objc_getAssociatedObject(iv,kADPeerRegistered6053)!=nil);
        } else if(ov.superlayer!=iv.layer) [iv.layer addSublayer:ov];
        ADNativeTWBStyleOverlay6053(iv,ov);
        if(newPeerPositive){ if(++gADPeerGeneration6055==0) gADPeerGeneration6055=1; }
        ADNativeWakePeers6053(iv);
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
        ADScheduleGlyphLift624(self);

        // (1) Backdrop for TRANSPARENT images — cheap, always-on-when-enabled.
        // v5.446 guard: never put a rectangular backdrop behind small UI glyphs
        // or native search/nav chrome. Camera/mic/search icons are transparent
        // artwork, so painting their UIImageView bounds is exactly what creates
        // the visible dark boxes around them. Large transparent artwork can still
        // use the generic backdrop path.
        CGFloat bw = self.bounds.size.width, bh = self.bounds.size.height;
        if (gP.imageBackdrop && (bw > 48 || bh > 48) && !ADIsChromeGlyphContext(self)){
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
        ADApplyNativeWhiteTame(self);

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

// v6.0.24: restore v5.446's view-aware glyph gate. The 6.x streamlined
// path called ADGlyphify() directly, which lost the donor's distinction between
// small UI chrome and larger content artwork. More importantly, late template
// assignments could keep Amazon's dark tint until an unrelated sweep happened.
// v6.0.75: the voice-permission probe proved its 44x44 microphone is not RNSVG.
// It is an RCTUIImageViewAnimated bitmap under the two voice-permission headings.
// v5.446's measured native-glyph lane admitted neutral glyphs through 52x52; the
// streamlined v6 view gate stops ordinary content at 40x40. Restore only this one
// semantic exception instead of widening every native image back to the donor band.
static BOOL ADIsVoicePermissionMic6075(UIView *v){
    if (!v) return NO;
    @try {
        const char *cn=object_getClassName(v);
        if (!cn || !strstr(cn,"RCTUIImageViewAnimated")) return NO;
        CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
        if (w<36||h<36||w>52||h>52) return NO;
        UIView *p=v.superview; int d=0;
        while(p&&d++<5){
            NSString *a=nil; @try { a=p.accessibilityLabel.lowercaseString; } @catch(...) {}
            if(a.length&&[a containsString:@"allow microphone access"]&&
                         [a containsString:@"shop faster with voice"]) return YES;
            p=p.superview;
        }
    } @catch(...) {}
    return NO;
}
static UIImage *ADGlyphifyForView(UIImage *img, UIView *v){
    @try {
        if (v && ADMenuRole382(v)==1) return nil;
        if (v && ADIsCategoryArtwork379(v)) return nil;
        if (v && !ADInTabBarChain(v) && !ADIsChromeGlyphContext(v)){
            CGFloat w=v.bounds.size.width, h=v.bounds.size.height;
            if(w<1 && img) w=img.size.width;
            if(h<1 && img) h=img.size.height;
            if ((w > 40 || h > 40) && !ADIsVoicePermissionMic6075(v)) return nil;
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

// v6.0.24: v5.446 had a delayed native-glyph lift specifically because Amazon/
// React can assign or re-tint the search-history X/clock after the first paint.
// Restore that convergence without the donor's broad probe machinery: only small
// glyph-sized views or known search/nav chrome are revisited, three times total.
static BOOL ADNativeGlyphReject624(UIView *v){
    @try {
        UIView *p=v; int d=0;
        while(p&&d++<6){
            NSString *cn=NSStringFromClass([p class]).lowercaseString;
            NSString *al=nil; @try { al=p.accessibilityLabel.lowercaseString; } @catch(...) {}
            NSString *sig=[NSString stringWithFormat:@"%@ %@",cn?:@"",al?:@""];
            if([sig containsString:@"star"]||[sig containsString:@"rating"]||
               [sig containsString:@"logo"]||[sig containsString:@"avatar"]||
               [sig containsString:@"profile"]||[sig containsString:@"brand"]||
               [sig containsString:@"merchant"]||[sig containsString:@"seller"])
                return YES;
            p=p.superview;
        }
    } @catch(...) {}
    return NO;
}
static void ADReassertNativeGlyph624(UIImageView *iv){
    @try {
        if (!iv || !iv.window || !ADRecolorOn() || ADIsWebKitOwned(iv)) return;
        if (ADInTabBarChain(iv)) return;
        UIImage *im=iv.image; if(!im) return;
        CGFloat w=iv.bounds.size.width, h=iv.bounds.size.height;
        if(w<1) w=im.size.width; if(h<1) h=im.size.height;
        if (w<5 || h<5 || w>56 || h>56) return;
        if (ADNativeGlyphReject624(iv) || ADMenuRole382(iv)==1 || ADIsCategoryArtwork379(iv)) return;
        UIColor *fg=ADColorFromHex(gP.fgHex);
        if (ADImageIsTemplateish(im) || ADIsModifiedImage(im)){
            iv.tintColor=fg;
            return;
        }
        UIImage *tpl=ADGlyphifyForView(im,iv);
        if(tpl){
            gADGlyphWriting=YES;
            iv.image=tpl;
            gADGlyphWriting=NO;
            iv.tintColor=fg;
        }
    } @catch(...) { gADGlyphWriting=NO; }
}
static void ADScheduleGlyphLift624(UIImageView *iv){
    if(!iv) return;
    @try {
        UIImage *im=iv.image; if(!im) return;
        CGFloat w=iv.bounds.size.width, h=iv.bounds.size.height;
        if(w<1) w=im.size.width; if(h<1) h=im.size.height;
        // Cheap gate BEFORE queueing delayed work: product photos never allocate
        // these blocks. The affected search/action glyphs are all icon-sized.
        if(w<5||h<5||w>56||h>56) return;
    } @catch(...) { return; }
    ADReassertNativeGlyph624(iv);
    __weak UIImageView *w=iv;
    const int64_t ms[]={80,260,700};
    for(int i=0;i<3;i++) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,ms[i]*1000000LL),dispatch_get_main_queue(),^{
        @try { UIImageView *x=w; if(x&&x.window) ADReassertNativeGlyph624(x); } @catch(...) {}
    });
}

%hook UIImageView
- (void)setImage:(UIImage *)image {
    if (gADBarImageWriting6069 || gADGlyphWriting) {
        %orig;
        return;
    }
    if (!image || ADIsWebKitOwned(self)) {
        %orig;
        if(!image) ADNativeTWBRelease6027(self);
        return;
    }
    // Detached: nothing to walk yet. Defer to didMoveToWindow, where ancestry -- and
    // therefore the tab-bar test -- is knowable.
    if (!self.superview && !self.window) {
        %orig;
        ADNativeTWBRelease6027(self);
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
            ADNativeTWBRelease6027(self);
            ADTintBarIcon(self, ADViewIsSelectedInBar(self));  // then templatise + colour
            return;
        }
        UIImage *tpl = ADGlyphifyForView(image, self);
        if (tpl) {
            ((UIView *)self).tintColor = ADColorFromHex(gP.fgHex);
            %orig(tpl);
            ADScheduleGlyphLift624(self);
            if (gP.whiteTame && self.window) ADApplyNativeWhiteTame(self);
            return;
        }
    } @catch(...) {}
    %orig;
    @try { if (self.window) ADScheduleGlyphLift624(self); } @catch(...) {}
    @try { if (gP.enabled && gP.whiteTame && self.window) ADApplyNativeWhiteTame(self); } @catch(...) {}
}
%end

// React Native image views: re-evaluate on attachment/reparent, then use the
// settled-cache fast path during layout.
%hook RCTUIImageViewAnimated
- (void)didMoveToWindow {
    %orig;
    @try {
        UIImageView *iv=(UIImageView *)(id)self;
        ADNativeClearPeerNegative6055(iv);
        ADNativeResetRCTRegistration6055(iv);
        UIView *vv=(UIView *)iv;
        if(gP.enabled&&gP.whiteTame&&vv.window) ADApplyNativeWhiteTameView(vv);
    } @catch(...) {}
}
- (void)didMoveToSuperview {
    %orig;
    if (!gP.enabled || !gP.whiteTame) return;
    @try {
        UIImageView *iv=(UIImageView *)(id)self;
        ADTWBResetSemantic6031(iv);
        ADNativeClearPeerNegative6055(iv);
        ADNativeResetRCTRegistration6055(iv);
        objc_setAssociatedObject(iv,kADPeerWakeImage6053,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADApplyNativeWhiteTameView((UIView *)iv);
    } @catch(...) {}
}
- (void)layoutSubviews {
    %orig;
    @try {
        UIView *vv=(UIView *)(id)self;
        if(gP.enabled&&gP.whiteTame&&vv.window) ADApplyNativeWhiteTameView(vv);
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
        CGFloat bw=self.bounds.size.width, bh=self.bounds.size.height;
        if(bw<1) bw=image.size.width; if(bh<1) bh=image.size.height;
        if (ADImageIsTemplateish(image) && !ADNativeGlyphReject624(self) && !ADIsCategoryArtwork379(self) &&
            (ADIsChromeGlyphContext(self) || (bw>=5 && bh>=5 && bw<=52 && bh<=52))) {
            ((UIView *)self).tintColor = ADColorFromHex(gP.fgHex);
            %orig(image, state);
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
static void ADInvertRNSVG(UIView *v){
    @try {
        const char *cn = object_getClassName(v);
        if (!cn) return;
        CGFloat w = v.bounds.size.width, h = v.bounds.size.height;
        // v6.0.85: exact v5.446 final floor. Alexa's vertical ellipsis is only
        // ~4x12pt, so the streamlined 6pt floor excluded it before ownership.
        if (w < 3 || w > 48 || h < 3 || h > 48) return;
        if (strcmp(cn, "RNSVGSvgView") != 0) return; // donor final: root only
        // Heal, don't just flag: React can clear layer.filters when a mounted SVG
        // re-renders. If our filters disappeared, re-assert the same donor pair.
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

// v6.0.72: streamlined port of the v5.350 voice-permission repair.
// The donor ran this from a second whole-window voice sweep after the normal native
// sweep.  We instead piggyback on ADSweepViewTree(), so the TextKit backing store is
// inspected at the same hydrated/visible stage without another traversal.
static BOOL ADVoiceTarget6072(NSString *t){
    if (!t.length || t.length > 700) return NO;
    static NSArray *parts=nil; static dispatch_once_t once;
    dispatch_once(&once, ^{ parts=@[@"allow microphone access", @"shop faster with voice",
        @"you can always turn it off", @"your audio is transcribed in the cloud",
        @"about shopping with voice"]; });
    NSString *lo=t.lowercaseString;
    for (NSString *q in parts) if ([lo containsString:q]) return YES;
    return NO;
}
static BOOL ADVoiceDarkNeutral6072(UIColor *c){
    if (!c) return YES;
    CGFloat r=0,g=0,b=0,a=0;
    if (![c getRed:&r green:&g blue:&b alpha:&a] || a<0.05) return NO;
    CGFloat mx=MAX(r,MAX(g,b)), mn=MIN(r,MIN(g,b));
    return (0.2126*r+0.7152*g+0.0722*b)<0.42 && (mx-mn)<0.20;
}
static int ADVoiceLiftStore6072(NSMutableAttributedString *store){
    if (!store.length) return 0;
    @try {
        NSMutableAttributedString *m=[store mutableCopy];
        __block int changed=0;
        [m enumerateAttribute:NSForegroundColorAttributeName
                      inRange:NSMakeRange(0,m.length) options:0
                   usingBlock:^(id value, NSRange range, BOOL *stop){
            UIColor *c=[value isKindOfClass:[UIColor class]]?(UIColor *)value:nil;
            if (!ADVoiceDarkNeutral6072(c)) return;
            [m addAttribute:NSForegroundColorAttributeName value:ADColorFromHex(gP.fgHex) range:range];
            changed++;
        }];
        if (changed) [store setAttributedString:m];
        return changed;
    } @catch(...) {}
    return 0;
}
static void ADVoiceRepairView6072(UIView *v){
    @try {
        Class RCT=NSClassFromString(@"RCTTextView");
        if (!RCT || ![v isKindOfClass:RCT] || !ADVoiceTarget6072(ADWTViewText362(v))) return;
        int changed=0, depth=0;
        for (Class c=[v class]; c && c!=[UIView class] && depth++<10; c=class_getSuperclass(c)){
            unsigned int n=0; Ivar *ivs=class_copyIvarList(c,&n);
            for (unsigned int i=0;i<n;i++){
                Ivar iv=ivs[i]; const char *enc=ivar_getTypeEncoding(iv);
                if (!enc || enc[0]!='@') continue;
                id obj=nil; @try { obj=object_getIvar(v,iv); } @catch(...) { obj=nil; }
                NSMutableAttributedString *store=nil;
                if ([obj isKindOfClass:[NSTextStorage class]] ||
                    [obj isKindOfClass:[NSMutableAttributedString class]]) store=(NSMutableAttributedString *)obj;
                else if ([obj isKindOfClass:[NSLayoutManager class]]) store=[(NSLayoutManager *)obj textStorage];
                if (store) changed += ADVoiceLiftStore6072(store);
            }
            if (ivs) free(ivs);
        }
        if (changed){ [v setNeedsLayout]; [v setNeedsDisplay]; [v.layer setNeedsDisplay]; }
    } @catch(...) {}
}

// v6.0.139: Person > Sign Out confirmation is already structurally correct in
// v6.0.138. Only own the two requested button paints: black ink on the stock
// yellow Sign Out button, and a medium-gray Cancel button with white ink.
// The context gate requires the signed-in confirmation copy plus BOTH button labels,
// so ordinary Sign Out / Cancel controls elsewhere in Amazon remain untouched.
static BOOL ADSignOutDialogContext6139(UIButton *b){
    @try {
        UIView *p=b.superview; int up=0;
        while(p && up++<6){
            BOOL signedIn=NO, signOut=NO, cancel=NO;
            NSMutableArray *q=[NSMutableArray arrayWithObject:p];
            for(NSUInteger qi=0; qi<q.count && qi<96; qi++){
                UIView *x=q[qi];
                NSString *lo=[[ADWTViewText362(x) lowercaseString]
                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if([lo containsString:@"you are signed in as"]) signedIn=YES;
                if([lo isEqualToString:@"sign out"]) signOut=YES;
                if([lo isEqualToString:@"cancel"]) cancel=YES;
                if(signedIn && signOut && cancel) return YES;
                if(qi<32){
                    for(UIView *sv in x.subviews){
                        if(q.count<96) [q addObject:sv]; else break;
                    }
                }
            }
            p=p.superview;
        }
    } @catch(...) {}
    return NO;
}
static void ADSignOutDialogButton6139(UIButton *b){
    if(!b || !b.window) return;
    @try {
        NSString *lo=[[(b.currentTitle ?: b.titleLabel.text ?: @"") lowercaseString]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        BOOL isSignOut=[lo isEqualToString:@"sign out"];
        BOOL isCancel=[lo isEqualToString:@"cancel"];
        if((!isSignOut && !isCancel) || !ADSignOutDialogContext6139(b)) return;

        if(isSignOut){
            UIColor *black=ADColorFromHex("#000000");
            [b setTitleColor:black forState:UIControlStateNormal];
            [b setTitleColor:black forState:UIControlStateHighlighted];
            [b setTitleColor:black forState:UIControlStateSelected];
        } else {
            UIColor *gray=ADColorFromHex("#666666");
            UIColor *white=ADColorFromHex("#FFFFFF");
            b.backgroundColor=gray;
            b.layer.backgroundColor=gray.CGColor;
            [b setTitleColor:white forState:UIControlStateNormal];
            [b setTitleColor:white forState:UIControlStateHighlighted];
            [b setTitleColor:white forState:UIControlStateSelected];

            // Some Amazon builds put the visible rectangle on a one-level wrapper
            // around the UIButton. Only recolor a wrapper whose geometry is effectively
            // the same as the button; never touch the dialog/card background itself.
            UIView *box=b.superview;
            if(box){
                CGFloat dw=fabs(box.bounds.size.width-b.bounds.size.width);
                CGFloat dh=fabs(box.bounds.size.height-b.bounds.size.height);
                if(dw<=12.0 && dh<=12.0 && box.bounds.size.height>=36.0 && box.bounds.size.height<=110.0){
                    box.backgroundColor=gray;
                    box.layer.backgroundColor=gray.CGColor;
                }
            }
        }
    } @catch(...) {}
}

static void ADSweepViewTree(UIView *v, int depth, BOOL inTabBar){
    if (!v || depth > 60) return;
    @try {
        if (ADIsWebKitOwned(v)) return;                 // Dark Reader's territory
        if (ADInNativeScrollIndicator6077(v)) return;  // UIKit owns native scroll-thumb paint
        ADVoiceRepairView6072(v);                     // hydrated native voice-sheet ink
        ADInvertRNSVG(v);                               // Alexa panel vector icons
        if ([v isKindOfClass:[UIImageView class]]) ADApplyNativeWhiteTameView(v); // direct TWB media only
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
                UIImage *tpl = ADGlyphifyForView(((UIImageView *)v).image, v);
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
                ADSignOutDialogButton6139(b);
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
    if (hex && strcmp(hex, gP.bgHex) == 0 && gADBGColor613) return gADBGColor613;
    if (hex && strcmp(hex, gP.fgHex) == 0 && gADFGColor613) return gADFGColor613;
    if (hex && strcmp(hex, "#00A8E1") == 0 && gADBlueColor613) return gADBlueColor613;
    unsigned int r=24,g=26,b=27;
    if (hex && hex[0]=='#') sscanf(hex+1, "%02x%02x%02x", &r,&g,&b);
    UIColor *c = ADMarkOwnColor([UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0]);
    if (hex && strcmp(hex, gP.bgHex) == 0) gADBGColor613 = c;
    else if (hex && strcmp(hex, gP.fgHex) == 0) gADFGColor613 = c;
    else if (hex && strcmp(hex, "#00A8E1") == 0) gADBlueColor613 = c;
    return c;
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
static void ADReapplyBurst(UIView *root){
    const uint32_t gen = ++gADBurstGeneration;
    __weak UIView *weakRoot = root;
    static const int64_t delays_ms[] = {0, 120, 420};
    for (int i = 0; i < 3; i++){
        const int pass = i;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delays_ms[i]*1000000LL),
            dispatch_get_main_queue(), ^{ @try {
                if (gen != gADBurstGeneration) return;
                ADForceWindowsDarkTrait();
                ADInjectAllWebViews();
                // v6.0.19: a viewDidAppear transition only needs the newly shown
                // controller tree. Dedicated header/tab hooks own global chrome, and
                // reusable-cell hooks own later content. Avoid two whole-window walks
                // whenever PDP Details/Explore/Reviews swaps child controllers.
                if (pass != 1){
                    UIView *r = weakRoot;
                    if (r && r.window) ADSweepViewTree(r, 0, ADInTabBarChain(r));
                }
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
            ADReapplyBurst(self.view);
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
    if (posted) return;
    // ABSOLUTE deadline, not a retry budget. The callers fire at wildly different
    // times -- 0.25s, 0.35s, a 60-tick timer, and a 9s backstop -- so a countdown
    // starting from "whenever we were first called" could push the signal past any
    // cover cap. On this device the trigger landed at t=5.6s; a 4.9s budget from
    // there would have signalled at 10.5s, long after the cover had gone.
    if (!ADScreenLooksDark() && ADUptime() < 7.5){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ ADPostAppReady(); });
        return;
    }
    posted = YES;
    notify_post("com.colindavidr.amazondark.ready");
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

// ─── live visual/performance settings reload ───────────────────────────────────────
// ADRootListController posts this Darwin notification on every toggle. Visual settings
// and 120 Hz can reapply in-process; JIT is intentionally launch-time because the
// preference workflow resprings before the next Amazon launch.
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
            BOOL oldPromotion = ADPromotionPreferenceOn611();
            ADLoadPrefs();              // also re-syncs + clears the colour/script caches
            BOOL newPromotion = ADPromotionPreferenceOn611();
            if (oldPromotion != newPromotion){
                ADStopHzVerification611();
                ADRefreshPromotionState611();
                ADStartHzVerification();
            }
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

// ─── %ctor : process guard + hook registration + bounded startup recovery ────
%ctor {
    if (strcmp(__progname, "Amazon") != 0) return;   // belt (plist filter is the braces)
    ADResetFlashProbe6101();
    // v5.446 direct-port: drop cached light launch snapshots.
    @try {
        NSString *lib = [NSSearchPathForDirectoriesInDomains(
                            NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
        NSString *snap = [lib stringByAppendingPathComponent:@"SplashBoard/Snapshots"];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *kids = [fm contentsOfDirectoryAtPath:snap error:nil];
        for (NSString *k in kids){
            NSString *sub = [snap stringByAppendingPathComponent:k];
            for (NSString *f in [fm contentsOfDirectoryAtPath:sub error:nil])
                [fm removeItemAtPath:[sub stringByAppendingPathComponent:f] error:nil];
        }
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

    dispatch_async(dispatch_get_main_queue(), ^{
        ADLoadPrefs();
        ADApplyJIT622();
        ADRefreshPromotionState611();
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
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(),
        NULL, ADFlashWillResign6101,
        (__bridge CFStringRef)UIApplicationWillResignActiveNotification,
        NULL, CFNotificationSuspensionBehaviorCoalesce);

}

#pragma clang diagnostic pop
