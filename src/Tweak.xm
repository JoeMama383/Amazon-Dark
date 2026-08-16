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
#define AD_VERSION "v6.0.27"

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
             "'ul.a-pagination.a-dots li.a-selected','ul.a-pagination.a-dots li.dot-selected-t2','[data-ad-dotselected374]'],"
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
           "f.id='adfloor612';f.textContent='html,body,#a-page,#gwm-PageContent,main{background-color:%@ !important;}';"
           "(document.documentElement||document).appendChild(f);}}catch(e){}"
         // v6.0.15: Amazon-native ad islands.  v5.446 proved that creative
         // subtrees must be kept out of generic recolor/glyph ownership.  Mark the
         // known Home ad-card families before Dark Reader starts so all later
         // guards can use one cheap ancestor test.
         "try{window.__AD_NATIVE_SEL615__='[class*=single-creative-card],[class*=single-video-card],[class*=theming-card],[class*=canvas-card],[class*=ape-placement],[class*=ape-wrapper],[data-cel-widget*=ape],[id*=ape_],[class*=hybrid-widget-sponsored],[class*=adFeedbackMainComponent],[class*=sponsored-products]';"
           "window.__AD_IS_NATIVE615__=function(e){try{return !!(e&&e.closest&&(e.closest('[data-ad-native615]')||e.closest(window.__AD_NATIVE_SEL615__)));}catch(x){return false;}};"
           "window.__AD_STRIP_DR615__=function(root){try{var R=[];if(root&&root.nodeType===1&&((root.matches&&root.matches(window.__AD_NATIVE_SEL615__))||root.hasAttribute('data-ad-native615')))R.push(root);if(root&&root.querySelectorAll){var q=root.querySelectorAll('[data-ad-native615],'+window.__AD_NATIVE_SEL615__);for(var i=0;i<q.length&&i<80;i++)R.push(q[i]);}for(var r=0;r<R.length;r++){var a=R[r];a.setAttribute('data-ad-native615','1');var E=[a],k=a.querySelectorAll('*');for(var j=0;j<k.length&&j<700;j++)E.push(k[j]);for(var z=0;z<E.length;z++){var el=E[z],at=Array.prototype.slice.call(el.attributes||[]);for(var x=0;x<at.length;x++){var nm=at[x].name;if(nm.indexOf('data-darkreader-inline-')===0)el.removeAttribute(nm);}var st=el.style;if(st){var rm=[];for(var y=0;y<st.length;y++){var pn=st[y];if(String(pn).indexOf('--darkreader-inline-')===0)rm.push(pn);}for(var y2=0;y2<rm.length;y2++)st.removeProperty(rm[y2]);}}}return R.length;}catch(e){return 0;}};"
           "window.__AD_MARK_NATIVE615__=function(root){try{if(!root)return 0;var n=0,Q=[];if(root.nodeType===1&&root.matches&&root.matches(window.__AD_NATIVE_SEL615__))Q.push(root);if(root.querySelectorAll){var q=root.querySelectorAll(window.__AD_NATIVE_SEL615__);for(var i=0;i<q.length&&i<80;i++)Q.push(q[i]);}for(var j=0;j<Q.length;j++){if(!Q[j].hasAttribute('data-ad-native615')){Q[j].setAttribute('data-ad-native615','1');n++;}}if(Q.length){window.__AD_STRIP_DR615__(root);setTimeout(function(){try{window.__AD_STRIP_DR615__(root);}catch(e){}},40);}return n;}catch(e){return 0;}};"
           "window.__AD_MARK_NATIVE615__(document);if(!window.__AD_NATIVE_OBS615__&&document.documentElement){window.__AD_NATIVE_OBS615__=1;new MutationObserver(function(ms){try{for(var i=0;i<ms.length&&i<48;i++){var A=ms[i].addedNodes||[];for(var j=0;j<A.length&&j<24;j++)if(A[j]&&A[j].nodeType===1)window.__AD_MARK_NATIVE615__(A[j]);}}catch(e){}}).observe(document.documentElement,{childList:true,subtree:true});}}catch(e){}"
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
           "function collect(root,out,depth){try{"
             "var list=root.querySelectorAll('*');"
             "for(var a=0;a<list.length;a++){var e=list[a];out.push(e);"
               // Shadow roots are separate trees: querySelectorAll stops at the host,
               // so anything Amazon builds inside one is unreachable from the document.
               "if(e.shadowRoot&&depth<4&&out.length<6000)collect(e.shadowRoot,out,depth+1);}"
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
           "var SKIP=/star|prime|logo|flag|swatch|thumb|sponsor|pill-image|product-image|photo|heart|wish|lists-framework|avatar|profile|author|reviewer|byline|merchant|seller|brand|store|logo-|-logo|headshot|user-image|customer/i;"
           "var CONTENTIMG616='[data-hook*=review],[class*=review],[class*=profile],[class*=avatar],[class*=author],[class*=byline],[class*=merchant],[class*=seller],[class*=brand],[class*=store],[id*=review]';"
           "function contentImg616(e,r,cs){try{if(!e||String(e.tagName||'').toLowerCase()!=='img')return false;"
             "var al=(e.getAttribute&&e.getAttribute('alt')||'').trim();if(al.length>1)return true;"
             "if(e.closest&&e.closest(CONTENTIMG616))return true;"
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
           "for(var i=0;i<els.length;i++){var el=els[i];"
             "if(window.__AD_IS_NATIVE615__&&window.__AD_IS_NATIVE615__(el))continue;"
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
                   "if(sr3.width>5&&sr3.width<=slim&&sr3.height>5&&sr3.height<=slim&&!SK2.test(sc3)){"
                     "if(adCbx439(el))continue;"
                     "el.style.setProperty('filter','brightness(0) invert(1)','important');el.__adGlyph=1;el.__adBy='gfix2';gfix++;}"
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
         "window.__AMZDARK_APPLY__=function(){try{"
           "if(!document.querySelector('style.darkreader'))DarkReader.enable(%@,%@);"
           "if(window.__AD_MARK_NATIVE615__)window.__AD_MARK_NATIVE615__(document);"
           "window.__AMZDARK_FIXCONTRAST__();"
           "if(window.__AD_STRIP_DR615__)window.__AD_STRIP_DR615__(document);"
         "}catch(e){}};"
         // Re-run the repair as the page fills in (carousels, lazy tiles), debounced
         // so a busy DOM cannot turn this into a hot loop.
         "try{var _t=null,_roots=[];new MutationObserver(function(ms){try{for(var mi=0;mi<ms.length&&_roots.length<24;mi++){var A=ms[mi].addedNodes||[];for(var ai=0;ai<A.length&&_roots.length<24;ai++){var n=A[ai];if(n&&n.nodeType===3)n=n.parentElement;if(!n||n.nodeType!==1)continue;if(window.__AD_IS_NATIVE615__&&window.__AD_IS_NATIVE615__(n))continue;if(_roots.indexOf(n)<0)_roots.push(n);}}if(!_roots.length)return;clearTimeout(_t);"
           "_t=setTimeout(function(){try{var R=_roots;_roots=[];for(var i=0;i<R.length;i++){var r=R[i];if(!r||!r.isConnected)continue;var nested=false;for(var j=0;j<R.length;j++){if(i!==j&&R[j]&&R[j].contains&&R[j].contains(r)){nested=true;break;}}if(!nested)window.__AMZDARK_FIXCONTRAST__(r);}}catch(e){}},180);}catch(e){}})"
           ".observe(document.documentElement,{childList:true,subtree:true});}catch(e){}"
         "window.__AMZDARK_APPLY__();"
         // Re-apply when the page is restored from the back-forward cache (returning
         // to a tab). pageshow.persisted is true exactly in that case, and it is the
         // event that fires when no navigation happens — the cart's "went white on
         // return" path. Also re-assert on visibility regain.
         "try{window.addEventListener('pageshow',function(e){if(e.persisted)window.__AMZDARK_APPLY__();});}catch(e){}"
         "try{document.addEventListener('visibilitychange',function(){if(!document.hidden)window.__AMZDARK_APPLY__();});}catch(e){}"
         "}}catch(e){}})();",
        floorBG, dr, [NSString stringWithUTF8String:gP.fgHex], ADThemeLiteral(), ADFixesLiteral()];
    return gADBootstrap613;
}


// ── v5.446 WEB WHITE-BACKGROUND TAME backport ───────────────────────────────
// The body below is copied from the exact v5.446 donor. It is kept separate from
// the v5.42 Dark Reader bootstrap so unrelated v5.43x/v5.44x UI fixes are not imported.
static NSString *ADWhiteTameLegacyWebJS446(void){
    if (!gP.enabled || !gP.whiteTame) return nil;
    if (gADTameWeb613) return gADTameWeb613;
    gADTameWeb613 = [NSString stringWithFormat:
        @"(function(){try{window.__ADTAME_ON__=1;window.__ADTAME_S__=%ld;"
         "if(window.__AD_TWB446_INSTALLED__){if(window._adTameFast362)window._adTameFast362(document.documentElement);if(window._adTameSpecial446)window._adTameSpecial446(document.documentElement);if(window._adScheduleTameFull446)window._adScheduleTameFull446(320);return;}"
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
         "function _adBgPlacement365(e){try{var p=e,d=0;while(p&&d++<4){var c=p.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));var id=String(p.id||''),cw=String((p.getAttribute&&p.getAttribute('data-cel-widget'))||'');if(/ape-placement|ape-wrapper|adfeedbackmaincomponent|ad-slot|adslot/i.test(c+' '+id+' '+cw))return true;if(p.querySelector&&p.querySelector('iframe')&&p.getBoundingClientRect().width>240)return true;p=p.parentElement;}return false;}catch(x){return false;}}function _adHomeBgLeaf395(e){try{if(window.__AD_TWB_FRAME_MODE446__||!e||!document.body||!window.__ADTAME_ON__)return false;if(document.querySelector('#search,.s-search-results,[data-component-type=\"s-search-result\"],#productTitle,#dp-container,#ppd'))return false;var c=e.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));if(!/theming-card-background|vjs-poster/i.test(c))return false;var p=e,u=0,ctx=c;while(p&&u++<7){ctx+=' '+String(p.className||'')+' '+String(p.id||'');if(/single-video-card|single-creative-card|video-card|video-js|vjs-|sbv-video|theming-card/i.test(ctx))break;p=p.parentElement;}if(!/single-video-card|single-creative-card|video-card|video-js|vjs-|sbv-video|theming-card/i.test(ctx))return false;var S=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),aa=(0.50*(S/100)).toFixed(3);e.removeAttribute('data-ad-tame-bgfast364');e.removeAttribute('data-ad-tame-fast362');e.style.setProperty('filter','none','important');e.style.removeProperty('background-color');e.style.setProperty('background-blend-mode','normal','important');e.style.setProperty('box-shadow','inset 0 0 0 9999px rgba(0,0,0,'+aa+')','important');e.setAttribute('data-ad-homebg395','1');e.__adTamed=1;e.__adTameSig='HBG395|'+String(getComputedStyle(e).backgroundImage||'');e.__adBy='homeBgLeaf395';return true;}catch(x){return false;}}"
         "function _adKnownProduct366(e){try{if(!e)return false;var p=e,d=0;while(p&&d++<6){var c=p.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));var id=String(p.id||''),asin=String((p.getAttribute&&p.getAttribute('data-asin'))||''),href=String((p.getAttribute&&p.getAttribute('href'))||'');if(asin||/asin|product|p13n|npack|cxvhz|gwm-asin|carousel-image|product-image/i.test(c+' '+id)||href.indexOf('/dp/')>=0||href.indexOf('/gp/product/')>=0)return true;p=p.parentElement;}return false;}catch(x){return false;}}"
         "window.__AD_TWB_FRAME_MODE446__=(function(){try{if(window.top===window)return '';var u=String(document.referrer||'').toLowerCase(),prod=u.indexOf('/dp/')>=0||u.indexOf('/gp/aw/d/')>=0||u.indexOf('/gp/product/')>=0||u.indexOf('/s?')>=0||u.indexOf('/search')>=0||u.indexOf('?k=')>=0||u.indexOf('&k=')>=0||u.indexOf('field-keywords=')>=0;if(prod)return 'productad';return ((innerHeight||0)<180||((innerWidth||1)/(innerHeight||1))>2.25)?'standalone':'hero';}catch(e){return '';}})();"
           "window.__AD_COMPACTSTRIP373__=function(){try{if(!document.body||String(window.__AD_TWB_FRAME_MODE446__||'')!=='standalone')return 0;var w=innerWidth||0,h=innerHeight||999;if(w<280||h>100)return 0;var tx=String(document.body.innerText||document.body.textContent||'').replace(/\\s+/g,' ').trim();var ok=/\\bsponsored(?: ad)?\\b/i.test(tx);window.__AD_COMPACTSTRIP373_N__=ok?1:0;if(ok){try{window.top.postMessage({__adCompact373:1},'*');}catch(ep){}}return ok?1:0;}catch(e){window.__AD_COMPACTSTRIP373_N__=0;return 0;}};"
           "window.__AD_COMPACTMEDIA373__=function(){try{if(!window.__ADTAME_ON__){window.__AD_COMPACTMEDIA373_N__=0;return 0;}var S=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),bb=(1-0.50*(S/100)).toFixed(3),M=document.querySelectorAll('img,video,canvas'),n=0;for(var i=0;i<M.length&&i<160;i++){var e=M[i],r=e.getBoundingClientRect();if(r.width<26||r.height<26)continue;var cn=e.className;cn=String(cn&&cn.baseVal!==undefined?cn.baseVal:(cn||''));if(/sprite|icon|logo|pixel/i.test(cn))continue;var sig=String(e.currentSrc||e.src||e.poster||'')+'|'+bb;if(e.__adTame362===sig)continue;if(String(e.tagName||'').toUpperCase()!=='VIDEO')e.style.setProperty('filter','brightness('+bb+') saturate(1.08)','important');e.setAttribute('data-ad-tame362','media');e.__adTame362=sig;e.__adBy='compactMedia373';n++;}window.__AD_COMPACTMEDIA373_N__=n;window.__AD_ADTAME__='media373='+n+' bg=0 solid=0';return n;}catch(e){window.__AD_COMPACTMEDIA373_N__=-1;return 0;}};"
           "window.__AD_PRODUCTSTRIP375__=function(){try{if(!document.body)return 0;if(window.__AD_STRIPCONF375__){try{window.top.postMessage({__adStrip374:1},'*');}catch(ep0){}return 1;}var mode=String(window.__AD_TWB_FRAME_MODE446__||''),w=innerWidth||0,h=innerHeight||999,tx=String(document.body.innerText||document.body.textContent||'').replace(/\\s+/g,' ').trim(),spon=/\\bsponsored(?: ad)?\\b/i.test(tx),compactGeom=(w>=280&&h<=190),ok=(mode==='productad')||(compactGeom&&spon&&(mode==='standalone'||mode===''||mode==='hero'));window.__AD_STRIP375_SPON__=spon?1:0;if(ok){window.__AD_STRIPCONF375__=1;window.__AD_STRIP375_FIRSTMODE__=mode||'-';try{window.top.postMessage({__adStrip374:1},'*');}catch(ep){}}window.__AD_STRIP375_N__=ok?1:0;return ok?1:0;}catch(e){window.__AD_STRIP375_N__=0;return 0;}};"
           "window.__AD_STRIPMEDIA374__=function(){try{var W=innerWidth||390,H=innerHeight||125,n=0,skip=0,cleared=0;if(!window.__ADTAME_ON__){window.__AD_STRIPMEDIA374_N__=0;window.__AD_STRIPFULL374_N__=0;return 0;}try{var T=document.querySelectorAll('[data-ad-tame362]');for(var ti=0;ti<T.length&&ti<500;ti++){var te=T[ti],tt=String(te.tagName||'').toUpperCase();if(tt==='IMG'||tt==='VIDEO'||tt==='CANVAS')continue;te.style.setProperty('filter','none','important');te.style.removeProperty('background-blend-mode');te.style.removeProperty('background-color');te.removeAttribute('data-ad-tame362');te.__adTame362=0;cleared++;}}catch(ec){}var S=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),bb=(1-0.50*(S/100)).toFixed(3),M=document.querySelectorAll('img,video,canvas');for(var i=0;i<M.length&&i<220;i++){var e=M[i],r=e.getBoundingClientRect();if(r.width<26||r.height<26)continue;var cn=e.className;cn=String(cn&&cn.baseVal!==undefined?cn.baseVal:(cn||''));var src=String(e.currentSrc||e.src||e.poster||'');if(/sprite|icon|logo|pixel|placeholder|spacer/i.test(cn+' '+src))continue;var full=(r.width>W*0.64&&r.height>H*0.55)||(r.width*r.height>W*H*0.58);if(full){if(e.hasAttribute('data-ad-tame362')||/brightness/i.test(String(e.style.getPropertyValue('filter')||''))){e.style.setProperty('filter','none','important');e.removeAttribute('data-ad-tame362');e.__adTame362=0;}e.setAttribute('data-ad-stripfullskip374','1');e.__adBy='stripFullSkip374';skip++;continue;}var sig=src+'|'+bb;if(e.__adTame362===sig&&e.getAttribute('data-ad-tame362')==='media374'){n++;continue;}if(String(e.tagName||'').toUpperCase()!=='VIDEO')e.style.setProperty('filter','brightness('+bb+') saturate(1.08)','important');e.setAttribute('data-ad-tame362','media374');e.__adTame362=sig;e.__adBy='stripMedia374';n++;}window.__AD_STRIPMEDIA374_N__=n;window.__AD_STRIPFULL374_N__=skip;window.__AD_ADTAME__='strip374 media='+n+' bg=0 fullSkip='+skip+' cleared='+cleared;return n;}catch(e){window.__AD_STRIPMEDIA374_N__=-1;return 0;}};"
           "window.__AD_HEROFAST365__=function(root){try{if(window.__AD_TWB_FRAME_MODE446__!=='hero'||!window.__ADTAME_ON__||!root||root.nodeType!==1)return 0;var S=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),bb=(1-0.50*(S/100)).toFixed(3),aa=(0.50*(S/100)).toFixed(3),A=[];if(!document.getElementById('adheropseudo366')){var ps=document.createElement('style');ps.id='adheropseudo366';ps.textContent='[data-ad-herobefore366]::before,[data-ad-heroafter366]::after{filter:brightness('+bb+') saturate(1.08) !important;}';(document.head||document.documentElement).appendChild(ps);}if(/^(IMG|VIDEO|CANVAS)$/i.test(String(root.tagName||'')))A.push(root);try{var q=root.querySelectorAll('img,video,canvas');for(var i=0;i<q.length&&i<120;i++)A.push(q[i]);}catch(e){}var n=0,b=0,pn=0;for(var j=0;j<A.length;j++){var x=A[j],r=x.getBoundingClientRect();if(r.width<32||r.height<32)continue;var c=x.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));if(/sprite|icon|logo|pixel/i.test(c))continue;var w='brightness('+bb+') saturate(1.08)';if(String(x.style.getPropertyValue('filter')||'')!==w||x.style.getPropertyPriority('filter')!=='important')x.style.setProperty('filter',w,'important');x.setAttribute('data-ad-tame362','media');x.__adBy='heroFast366';n++;}var B=[];if(/^(HTML|BODY|DIV|SECTION|A|SPAN|LI|FIGURE|PICTURE)$/i.test(String(root.tagName||'')))B.push(root);try{var qb=root.querySelectorAll('html,body,div,section,a,span,li,figure,picture');for(var k=0;k<qb.length&&k<120;k++)B.push(qb[k]);}catch(e){}for(var z=0;z<B.length&&b<40;z++){var e=B[z],rr=e.getBoundingClientRect();if(rr.width<32||rr.height<32)continue;var cc=e.className;cc=String(cc&&cc.baseVal!==undefined?cc.baseVal:(cc||''));if(/sprite|icon|logo|pixel/i.test(cc))continue;var cs=getComputedStyle(e),bi=String(cs.backgroundImage||'none');if(bi.indexOf('url(')>=0){e.style.setProperty('background-color','rgba(0,0,0,'+aa+')','important');e.style.setProperty('background-blend-mode','multiply','important');e.setAttribute('data-ad-tame362','bg');e.__adBy='heroFastBg366';b++;}try{var bf=getComputedStyle(e,'::before'),af=getComputedStyle(e,'::after'),bfi=String(bf.backgroundImage||'none'),afi=String(af.backgroundImage||'none');if(bfi.indexOf('url(')>=0){e.setAttribute('data-ad-herobefore366','1');e.__adBy='heroPseudo366';pn++;}if(afi.indexOf('url(')>=0){e.setAttribute('data-ad-heroafter366','1');e.__adBy='heroPseudo366';pn++;}}catch(px){}}window.__AD_HEROFAST365_N__=n+b+pn;return n+b+pn;}catch(e){return 0;}};"
                  "function _adHomeMedia395(){try{if(window.__AD_TWB_FRAME_MODE446__||!document.body||!window.__ADTAME_ON__)return 0;if(document.querySelector('#search,.s-search-results,[data-component-type=\"s-search-result\"],#productTitle,#dp-container,#ppd')){window.__AD_HOMEMEDIA395__='home=0 product=1';return 0;}var S=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),bb=(1-0.50*(S/100)).toFixed(3),E=document.querySelectorAll('img[class*=\"_single-creative-card\"],img[class*=\"_single-video-card\"],[class*=\"single-creative-card\"] img,[class*=\"single-video-card\"] img,video.vjs-tech,[class*=\"single-video-card\"] video,[class*=\"theming-card-background\"],.vjs-poster,[class*=\"vjs-poster\"]'),media=0,bg=0,uncovered=0,hazard=0;for(var i=0;i<E.length&&i<240;i++){var e=E[i],r=e.getBoundingClientRect(),tg=String(e.tagName||'').toUpperCase();if(r.width<100||r.height<70)continue;if(tg==='DIV'||tg==='SECTION'||tg==='SPAN'){if(!_adHomeBgLeaf395(e))continue;bg++;var cs=getComputedStyle(e);if(String(cs.filter||'none')!=='none'||String(cs.backgroundBlendMode||'normal').indexOf('multiply')>=0)hazard++;if(!e.hasAttribute('data-ad-homebg395'))uncovered++;continue;}if(tg!=='IMG'&&tg!=='VIDEO'&&tg!=='CANVAS')continue;var want='brightness('+bb+') saturate(1.08)';e.setAttribute('data-ad-tame-fast362','1');e.setAttribute('data-ad-homemedia395','1');if(String(e.style.getPropertyValue('filter')||'')!==want||e.style.getPropertyPriority('filter')!=='important')e.style.setProperty('filter',want,'important');e.__adTamed=1;e.__adTameSig='HM395|'+String(e.currentSrc||e.src||e.poster||'');e.__adBy='homeMedia395';media++;if(String(getComputedStyle(e).filter||'').indexOf('brightness')<0)uncovered++;}window.__AD_HOMEMEDIA395__='media='+media+' bg='+bg+' uncovered='+uncovered+' hazard='+hazard;return media+bg;}catch(e){window.__AD_HOMEMEDIA395__='err '+(e&&e.message||e);return 0;}}"
         "function _adNativeMediaOK615(e){try{if(!(window.__AD_IS_NATIVE615__&&window.__AD_IS_NATIVE615__(e)))return true;var tg=String(e.tagName||'').toUpperCase();if(tg!=='IMG'&&tg!=='VIDEO'&&tg!=='CANVAS')return false;var p=e,d=0,ctx='';while(p&&d++<5){var c=p.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));ctx+=' '+c+' '+String(p.id||'');p=p.parentElement;}if(/sprite|icon|logo|pixel|avatar|profile|author|reviewer|byline|merchant|seller|brand|store|headshot|user-image|customer/i.test(ctx))return false;return true;}catch(x){return false;}}"
         "function _adTameSpecial446(root){try{if(!window.__ADTAME_ON__)return 0;var mode=String(window.__AD_TWB_FRAME_MODE446__||'');if(!mode)return _adHomeMedia395();if(window.__AD_PRODUCTSTRIP375__&&window.__AD_PRODUCTSTRIP375__())return window.__AD_STRIPMEDIA374__?window.__AD_STRIPMEDIA374__():0;if(mode==='standalone'&&window.__AD_COMPACTSTRIP373__&&window.__AD_COMPACTSTRIP373__())return window.__AD_COMPACTMEDIA373__?window.__AD_COMPACTMEDIA373__():0;if(mode==='hero'&&window.__AD_HEROFAST365__)return window.__AD_HEROFAST365__(root||document.documentElement);return 0;}catch(e){return 0;}}"
         "function _adSpecialRelevant446(e){try{if(!e||e.nodeType!==1)return false;var tg=String(e.tagName||'').toUpperCase();if(tg==='IMG'||tg==='VIDEO'||tg==='CANVAS')return true;var c=e.className;c=String(c&&c.baseVal!==undefined?c.baseVal:(c||''));if(/single-creative-card|single-video-card|theming-card-background|vjs-poster/i.test(c))return true;return !!(e.querySelector&&e.querySelector('img,video,canvas,[class*=single-creative-card],[class*=single-video-card],[class*=theming-card-background],.vjs-poster'));}catch(x){return false;}}"
         "function _adTameCss362(){try{if(!window.__ADTAME_ON__)return;if(document.getElementById('adtame362'))return;"
           "var S=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),bb=(1-0.50*(S/100)).toFixed(3);"
           "var aa=(0.50*(S/100)).toFixed(3);var st=document.createElement('style');st.id='adtame362';st.textContent='[data-ad-tame-fast362=\"1\"]{filter:brightness('+bb+') saturate(1.08) !important;}[data-ad-tame-bgfast364=\"1\"]{background-color:rgba(0,0,0,'+aa+') !important;background-blend-mode:multiply !important;}';"
           "(document.head||document.documentElement).appendChild(st);}catch(e){}}"
         "function _adTameFast362(root,full){try{if(!window.__ADTAME_ON__||!root||root.nodeType!==1)return 0;_adTameCss362();var mc446=full?360:100,ml446=full?420:120,bc446=full?900:120,bl446=full?930:130;var S365=Math.max(0,Math.min(100,window.__ADTAME_S__||45)),bb365=(1-0.50*(S365/100)).toFixed(3),aa365=(0.50*(S365/100)).toFixed(3);var A=[];"
           "if(/^(IMG|VIDEO|CANVAS)$/i.test(String(root.tagName||'')))A.push(root);try{var q=root.querySelectorAll('img,video,canvas');for(var i=0;i<q.length&&i<mc446;i++)A.push(q[i]);}catch(e){}"
           "var n=0;for(var j=0;j<A.length&&j<ml446;j++){var x=A[j];if(!_adNativeMediaOK615(x)){if(String(x.__adBy||'').indexOf('whiteTame')===0)x.style.removeProperty('filter');x.removeAttribute('data-ad-tame-fast362');x.__adTamed=0;continue;}var tg=String(x.tagName||'').toUpperCase(),cn=x.className;cn=String(cn&&cn.baseVal!==undefined?cn.baseVal:(cn||''));var band=_adTameBand362(x),xr=x.getBoundingClientRect(),prod366=(tg==='IMG'&&_adKnownProduct366(x)),review366=(band===3);"
             "if(band<0||_adExploreIcon363(x)||_adNoTameGlyph367(x)){x.removeAttribute('data-ad-tame-fast362');if(String(x.__adBy||'').indexOf('whiteTame')===0)x.style.removeProperty('filter');x.__adTamed=0;x.__adBy='exploreSkip362';continue;}"
             "if(review366&&tg!=='IMG')continue;if(review366&&/sprite|icon|logo|pixel|star|rating|close/i.test(cn))continue;"
             "if(band!==2&&!review366&&!prod366&&/sprite|icon|logo|pixel/i.test(cn))continue;if(x.__adGlyph&&band!==2&&!review366&&!prod366)continue;var ok=(tg==='VIDEO'||tg==='CANVAS');"
             "if(!ok&&tg==='IMG'){var nw=x.naturalWidth||+(x.getAttribute&&x.getAttribute('width')||0),nh=x.naturalHeight||+(x.getAttribute&&x.getAttribute('height')||0),mn=((band===2||review366||prod366)?24:56);ok=(nw>=mn&&nh>=mn)||((review366||prod366)&&xr.width>=24&&xr.height>=24);}"
             "if(!ok)continue;var want365='brightness('+bb365+') saturate(1.08)';x.setAttribute('data-ad-tame-fast362','1');if(String(x.style.getPropertyValue('filter')||'')!==want365||x.style.getPropertyPriority('filter')!=='important')x.style.setProperty('filter',want365,'important');x.__adTamed=1;x.__adTameSig=tg+'|'+String(x.currentSrc||x.src||x.poster||'');x.__adBy=(review366?'whiteTameReview366':(band===2?'whiteTameFast365ctx':'whiteTameFast365'));n++;}"
           // CSS-background ads were the remaining sporadic Home misses once the full
           // pass was intentionally delayed. Scan only a tiny local budget here and
           // mark the BACKGROUND layer; child text is never filtered.
           "var B=[];if(/^(DIV|SPAN|A|SECTION|LI)$/i.test(String(root.tagName||'')))B.push(root);try{var qb=root.querySelectorAll('div,span,a,section,li');for(var k=0;k<qb.length&&k<bc446;k++)B.push(qb[k]);}catch(e){}"
           "var bg=0;for(var z=0;z<B.length&&z<bl446;z++){var be=B[z];if(_adHomeBgLeaf395(be))continue;if(window.__AD_IS_NATIVE615__&&window.__AD_IS_NATIVE615__(be)){if(String(be.__adBy||'').indexOf('whiteTameFastBg')===0){be.style.removeProperty('background-color');be.style.removeProperty('background-blend-mode');be.removeAttribute('data-ad-tame-bgfast364');be.__adTamed=0;}continue;}var bandb=_adTameBand362(be);if(bandb<0||bandb===3||_adExploreIcon363(be)||_adNoTameGlyph367(be)){be.removeAttribute('data-ad-tame-bgfast364');if(String(be.__adBy||'').indexOf('whiteTame')===0){be.style.removeProperty('background-color');be.style.removeProperty('background-blend-mode');be.__adBy='tameSkip365';}continue;}"
             "if(_adBgPlacement365(be)||(be.hasAttribute&&be.hasAttribute('data-ad-productad367')))continue;var cs=getComputedStyle(be),bi=String(cs.backgroundImage||'none');if(bi.indexOf('url(')<0)continue;var br=be.getBoundingClientRect(),mn2=(bandb===2?32:56);if(br.width<mn2||br.height<mn2)continue;var bc=be.className;bc=String(bc&&bc.baseVal!==undefined?bc.baseVal:(bc||''));if(bandb!==2&&/sprite|icon|logo|pixel/i.test(bc))continue;be.setAttribute('data-ad-tame-bgfast364','1');be.style.setProperty('background-color','rgba(0,0,0,'+aa365+')','important');be.style.setProperty('background-blend-mode','multiply','important');be.__adTamed=1;be.__adTameSig='BG|'+bi;be.__adBy=(bandb===2?'whiteTameFastBg365ctx':'whiteTameFastBg365');bg++;}"
           "return n+bg;}catch(e){return 0;}}"
         "try{window._adTameFast362=_adTameFast362;window._adTameSpecial446=_adTameSpecial446;window._adScheduleTameSpecial446=function(root){try{window.__AD_TWB446_SPECIALROOT__=root||document.documentElement;if(window.__AD_TWB446_SPECIALPEND__)return;window.__AD_TWB446_SPECIALPEND__=1;setTimeout(function(){try{window.__AD_TWB446_SPECIALPEND__=0;var r=window.__AD_TWB446_SPECIALROOT__||document.documentElement;window.__AD_TWB446_SPECIALROOT__=null;_adTameSpecial446(r);}catch(e){}},140);}catch(e){}};window._adScheduleTameFull446=function(delay){try{if(window.__AD_TWB446_FULLPEND__)return;var now=Date.now(),wait=Math.max(delay||0,Math.max(0,1200-(now-(window.__AD_TWB446_LASTFULL__||0))));window.__AD_TWB446_FULLPEND__=1;setTimeout(function(){var run=function(){try{window.__AD_TWB446_FULLPEND__=0;window.__AD_TWB446_LASTFULL__=Date.now();_adTameFast362(document.documentElement,true);_adTameSpecial446(document.documentElement);}catch(e){window.__AD_TWB446_FULLPEND__=0;}};try{if(window.requestIdleCallback)requestIdleCallback(run,{timeout:700});else run();}catch(e){run();}},wait);}catch(e){}};_adTameCss362();_adTameFast362(document.documentElement);_adTameSpecial446(document.documentElement);window._adScheduleTameFull446(650);document.addEventListener('load',function(e){try{_adTameFast362(e.target);if(_adSpecialRelevant446(e.target))window._adScheduleTameSpecial446(e.target);}catch(x){}},true);window.addEventListener('pageshow',function(){try{window._adScheduleTameFull446(260);}catch(e){}},{passive:true});}catch(e){}"

         "try{if(!window.__AD_TWB446_OBS__){window.__AD_TWB446_OBS__=1;new MutationObserver(function(muts){try{var sp=0,sr=null;for(var mi=0;mi<muts.length&&mi<48;mi++){var mm=muts[mi];if(mm.type==='attributes'){if(mm.target){window._adTameFast362(mm.target);if(_adSpecialRelevant446(mm.target)){sp=1;sr=mm.target;}}continue;}var aa=mm.addedNodes||[];for(var ai=0;ai<aa.length&&ai<24;ai++){if(aa[ai]&&aa[ai].nodeType===1){window._adTameFast362(aa[ai]);if(_adSpecialRelevant446(aa[ai])){sp=1;sr=aa[ai];}}}}if(sp&&window._adScheduleTameSpecial446)window._adScheduleTameSpecial446(sr);}catch(x){}}).observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['src','srcset','poster','class']});}}catch(e){}"
         "}catch(e){}})();",
        (long)gP.whiteTameStrength];
    return gADTameWeb613;
}

// v6.0.27 TWB architecture experiment.
// Keep the exact v5.446-derived scanner in source for A/B recovery, but production
// uses assignment/CSS ownership so TWB does no DOM recovery walk while scrolling.
static const BOOL kADLegacyTWB6027 = NO;

static NSString *ADWhiteTameWebJS6027(void){
    if (!gP.enabled || !gP.whiteTame) return nil;
    CGFloat s=MAX(0,MIN(100,gP.whiteTameStrength));
    CGFloat b=1.0-(0.50*(s/100.0));
    return [NSString stringWithFormat:
        @"(function(){try{"
         "var id='ad-twb6027',st=document.getElementById(id);"
         "if(!st){st=document.createElement('style');st.id=id;(document.head||document.documentElement).appendChild(st);}"
         "var css='html body :is(' +"
           "'img.s-image,'+"
           "'.s-product-image-container img,'+"
           "'[data-component-type=\\\"s-product-image\\\"] img,'+"
           "'[data-component-type=\\\"s-search-result\\\"] img,'+"
           "'#dp-container img.a-dynamic-image,'+"
           "'#ppd img.a-dynamic-image,'+"
           "'#landingImage,'+"
           "'#imgTagWrapperId img,'+"
           "'.a-carousel-card img.a-dynamic-image,'+"
           "'img.a-amazon-image,'+"
           "'[class*=\\\"_gwm-asin-tile\\\"] img,'+"
           "'img[class*=\\\"_np\\\"],'+"
           "'[class*=\\\"product-image\\\"] img' +"
         "'):not([class*=\\\"icon\\\"]):not([class*=\\\"logo\\\"]):not([class*=\\\"avatar\\\"]):not([class*=\\\"profile\\\"]):not([class*=\\\"merchant\\\"]):not([class*=\\\"seller\\\"]):not([class*=\\\"brand\\\"]):not([class*=\\\"store\\\"]):not([class*=\\\"sprite\\\"]){filter:brightness(%.3f) saturate(1.08)!important;}'+"
         "'html body :is(.s-suggestion,.s-suggestion-container,[class*=\\\"recentSearch\\\"],[class*=\\\"search-suggestion\\\"],[class*=\\\"avatar\\\"],[class*=\\\"profile\\\"],[class*=\\\"merchant\\\"],[class*=\\\"seller\\\"],[class*=\\\"brand\\\"],[class*=\\\"store\\\"],[class*=\\\"logo\\\"]) img{filter:none!important;}';"
         "if(st.textContent!==css)st.textContent=css;"
         "window.__AD_TWB6027_INSTALLED__=1;"
         "}catch(e){}})();", b];
}

static NSString *ADWhiteTameWebJS446(void){
    return kADLegacyTWB6027 ? ADWhiteTameLegacyWebJS446() : ADWhiteTameWebJS6027();
}

static void ADAttachWhiteTameUserScript446(WKUserContentController *ucc){
    if (!ucc || !gP.enabled || !gP.whiteTame) return;
    @try {
        for (WKUserScript *existing in ucc.userScripts){
            if ([existing.source containsString:@"__AD_TWB6027_INSTALLED__"] || [existing.source containsString:@"__AD_TWB446_INSTALLED__"]) return;
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
    if (gADReapply613) return gADReapply613;
    gADReapply613 = [NSString stringWithFormat:
        @"(function(){try{"
         "if(!(window.DarkReader&&DarkReader.enable))return 'noDR';"
         "if(!document.querySelector('style.darkreader'))DarkReader.enable(%@,%@);"
         "if(window.__AMZDARK_FIXCONTRAST__)return ''+window.__AMZDARK_FIXCONTRAST__();"
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
           "function cards(e){legacy(e);if(e.getAttribute('data-ad-cards440-suppressed')==='checkbox'){if(checkboxAt(e))return 0;e.style.removeProperty('visibility');e.style.removeProperty('opacity');e.removeAttribute('data-ad-cards440-suppressed');}var N=e.querySelectorAll('[class*=mlt-image-icon],img[class*=s-image],p[class*=mlt-text-icon],img,i,svg,path,use,polygon'),P=[e],live=[],pseudo='';for(var pi=0;pi<N.length&&pi<47;pi++)P.push(N[pi]);for(var i=0;i<P.length&&i<48;i++){var g=P[i],r=rr(g);if(!glyph440(g)||!shown(g,e))continue;var t=String(g.tagName||'').toUpperCase(),s=getComputedStyle(g),b=getComputedStyle(g,'::before'),a=getComputedStyle(g,'::after'),paint=/^(IMG|I|SVG|PATH|USE|POLYGON)$/.test(t)||/mlt-text-icon/.test(cn(g))||String(s.backgroundImage||'none')!=='none'||String(s.maskImage||s.webkitMaskImage||'none')!=='none';if(String(b&&b.backgroundImage||'none')!=='none'||String(b&&b.content||'none')!=='none')pseudo+='b';if(String(a&&a.backgroundImage||'none')!=='none'||String(a&&a.content||'none')!=='none')pseudo+='a';if(paint)live.push(g);}if(!live.length&&!pseudo){clearCards(e);return 0;}if(checkboxAt(e)){clearCards(e);e.setAttribute('data-ad-cards440-suppressed','checkbox');e.style.setProperty('visibility','hidden','important');e.style.setProperty('opacity','0','important');return 0;}var old=e.querySelectorAll('[data-ad-cards440-glyph],[data-ad-cards440-pseudo]');for(var o=0;o<old.length;o++){if(live.indexOf(old[o])>=0)continue;['filter','color','fill','stroke','background-color'].forEach(function(k){old[o].style.removeProperty(k);});old[o].removeAttribute('data-ad-cards440-glyph');old[o].removeAttribute('data-ad-cards440-pseudo');}e.setAttribute('data-ad-sym413','cards');e.setAttribute('data-ad-cards440-host','1');if(pseudo)e.setAttribute('data-ad-cards440-pseudo',pseudo);else e.removeAttribute('data-ad-cards440-pseudo');e.__adBy='cards440';e.style.setProperty('background-color',SPEC.bg,'important');e.style.setProperty('border',SPEC.bd,'important');e.style.setProperty('border-radius','50%%','important');e.style.setProperty('box-shadow','none','important');e.style.setProperty('box-sizing','border-box','important');for(var j=0;j<live.length;j++){var z=live[j],tg=String(z.tagName||'').toUpperCase();if(!glyph440(z))continue;z.setAttribute('data-ad-cards440-glyph','1');z.__adBy='cards440';if(/^(SVG|PATH|USE|POLYGON)$/.test(tg)){z.style.setProperty('filter','none','important');z.style.setProperty('fill','#ffffff','important');z.style.setProperty('stroke','#ffffff','important');}else z.style.setProperty('filter','brightness(0) invert(1)','important');z.style.setProperty('color','#ffffff','important');z.style.setProperty('background-color','transparent','important');if(pseudo)z.setAttribute('data-ad-cards440-pseudo',pseudo);}return 1;}"
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
           "var cartSeed434=document.querySelector('[class*=sc-list-item],[class*=sc-item]'),body434=cartSeed434?String(document.body.innerText||document.body.textContent||'').toLowerCase():'',cart434=!!cartSeed434&&body434.indexOf('proceed to checkout')>=0&&(body434.indexOf('save for later')>=0||body434.indexOf('select all items')>=0||body434.indexOf('deselect all items')>=0);"
           "var scopeSel434='[class*=puis-card],[class*=s-result-item],[data-component-type=\"s-search-result\"],[data-asin],[class*=s-product-image],[class*=product-image],[class*=sc-list-item],[class*=sc-item]';"
           "var semanticSel434='[class*=copilot-compare],button[aria-label*=ompare],[role=button][aria-label*=ompare],[role=checkbox],[aria-checked],[data-csa-c-content-id*=ompare],[data-testid*=ompare],div.a-checkbox,[class~=a-checkbox]';"
           "function scope434(e){return !!(e&&e.closest&&e.closest(scopeSel434));}/* Cart mode changes shell paint only, never page-wide checkbox scope */"
           "function foreign434(e){try{return !!(e&&e.closest&&e.closest('[class*=mlt-icon-container],[class*=lists-framework-action-button],[data-ad-cards410-root],[data-ad-cards410-host],[data-ad-cards410-disc],[data-ad-cards410-glyph],[data-ad-heart-shell427],[class*=puis-heart-position],[class*=lists-treatment-hear],[class*=puis-mab-chevron]'));}catch(x){return true;}}"
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
           "function queue434(delay){try{clearTimeout(window.__AD_CHECKBOX434_T__);window.__AD_CHECKBOX434_T__=setTimeout(function(){try{window.__AD_CHECKBOX434__();}catch(x){}try{window.__AD_DOTFIX374__&&window.__AD_DOTFIX374__();}catch(x){}},delay||70);}catch(x){}}"
           "new MutationObserver(function(){queue434(70);}).observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['class','aria-current','aria-checked','aria-pressed','aria-selected','data-checked','data-selected','data-state','checked','src','data-src']});}"
           "stockCheckbox434();setTimeout(stockCheckbox434,40);setTimeout(stockCheckbox434,180);setTimeout(stockCheckbox434,700);setTimeout(stockCheckbox434,1800);"
         "}catch(e){}"
         // Tiny 6.x reapply entry point only. It does not alter either donor owner.
         "window.__AD_SYM605_RUN__=sym413;"
         "window.__AD_SYM605_QUEUE__=function(){try{if(window.__AD_SYM605_Q__)return;window.__AD_SYM605_Q__=1;var f=function(){window.__AD_SYM605_Q__=0;try{window.__AD_HEARTSHELL427__();}catch(x){}try{sym413();}catch(x){}try{window.__AD_CHECKBOX434__&&window.__AD_CHECKBOX434__();}catch(x){}try{window.__AD_DOTFIX374__&&window.__AD_DOTFIX374__();}catch(x){}};if(window.requestAnimationFrame)requestAnimationFrame(f);else setTimeout(f,0);}catch(e){}};"
         "try{if(!window.__AD_SYM_SCROLL619__){window.__AD_SYM_SCROLL619__=1;addEventListener('scroll',function(){clearTimeout(window.__AD_SYM_SCROLL_T619__);window.__AD_SYM_SCROLL_T619__=setTimeout(function(){try{window.__AD_SYM605_QUEUE__();}catch(x){}},140);},{passive:true,capture:true});}}catch(e){}"
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
                     NSString *full=ADWhiteTameWebJS446(); if(full.length)[wv evaluateJavaScript:full completionHandler:nil];
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
            NSString *twb446 = ADWhiteTameWebJS446();
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

// v6.0.13: the old implementation hooked UIView layoutSubviews globally just to
// reach this one RN SVG class plus tiny RN-hosted UILabel glyphs. Hook the actual
// owners instead so ordinary views pay zero SVG-probe cost.
%hook RNSVGSvgView
- (void)didMoveToWindow {
    %orig;
    @try { if (ADRecolorOn() && self.window) ADInvertRNSVG(self); } @catch(...) {}
}
- (void)layoutSubviews {
    %orig;
    @try { if (ADRecolorOn() && self.window) ADInvertRNSVG(self); } @catch(...) {}
}
%end

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
        if(!kADLegacyTWB6027)return;
        // v6.0.23: retain the v6.0.19 React recovery, and recover ordinary native
        // horizontal image carousels without restoring v5.446's every-scroll whole-tree
        // sweep. Non-React lanes are geometry-gated and use a 72-view budget.
        const char *scn=object_getClassName(self);
        BOOL react=(scn&&(strstr(scn,"RCT")||strstr(scn,"React")));
        CGSize bs=self.bounds.size,cs=self.contentSize;
        BOOL horizontal=(!react&&bs.width>=180&&bs.height>=60&&bs.height<=520&&cs.width>bs.width*1.20&&cs.width>cs.height*1.10);
        if(!react&&!horizontal)return;
        if(objc_getAssociatedObject(self,kADTWBScrollPend446))return;
        objc_setAssociatedObject(self,kADTWBScrollPend446,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UIScrollView *ws=self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(react?300:420)*1000000LL),dispatch_get_main_queue(),^{
            UIScrollView *ss=ws;if(!ss)return;objc_setAssociatedObject(ss,kADTWBScrollPend446,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            @try {
                NSUInteger cap=react?180:72,expand=react?55:28;
                NSMutableArray *q=[NSMutableArray arrayWithObject:ss];
                for(NSUInteger i=0;i<q.count&&i<cap;i++){
                    UIView *x=q[i];
                    if([x isKindOfClass:[UIImageView class]]){
                        ADApplyNativeWhiteTameView(x);
                        if(react)ADSubscribeOverlay394(x);
                    }
                    if(i<expand){for(UIView *c in x.subviews){if(q.count<cap)[q addObject:c];else break;}}
                }
            } @catch(...) {}
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
// v6.0.27 direct native TWB owner. Classification happens on image assignment and
// is cached on the UIImageView for that exact UIImage. Layout/reapply calls only keep
// the already-owned overlay sized correctly; they do not walk section trees.
static const void *kADTWBCachedImage6027 = &kADTWBCachedImage6027;
static const void *kADTWBDecision6027 = &kADTWBDecision6027;

static void ADNativeTWBRelease6027(UIImageView *iv){
    if(!iv) return;
    @try {
        CALayer *ov=objc_getAssociatedObject(iv,kADWhiteTameOverlayKey);
        if(ov){ [ov removeFromSuperlayer]; objc_setAssociatedObject(iv,kADWhiteTameOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    } @catch(...) {}
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

static void ADApplyNativeWhiteTameDirect6027(UIView *v){
    if(![v isKindOfClass:[UIImageView class]]) return;
    UIImageView *iv=(UIImageView *)v;
    @try {
        UIImage *im=iv.image;
        if(!gP.enabled||!gP.whiteTame||!iv.window||ADIsWebKitOwned(iv)||!im){
            ADNativeTWBRelease6027(iv);
            objc_setAssociatedObject(iv,kADTWBCachedImage6027,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(iv,kADTWBDecision6027,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
        // Do not cache unresolved geometry; a recycled RN image often receives its
        // bitmap before layout and should get one classification when bounds arrive.
        if(w<1||h<1) return;
        if(w<48||h<48||w>1200||h>1200||ADImageIsTemplateish(im)||ADNativeTWBUIChain6027(iv)){
            // Geometry/context can change without another setImage: during RN reuse.
            // Release visual ownership but keep the cached image-lightness decision
            // available if the same view later becomes eligible again.
            ADNativeTWBRelease6027(iv);
            return;
        }
        UIImage *cached=objc_getAssociatedObject(iv,kADTWBCachedImage6027);
        NSNumber *decision=objc_getAssociatedObject(iv,kADTWBDecision6027);
        BOOL own=NO;
        if(cached==im&&decision){
            own=decision.boolValue;
        } else {
            // The sampler result itself is cached on UIImage, so a recycled image used
            // in multiple cells incurs the 12x12 sample only once for the entire app.
            own=ADWTImageLight363(im);
            objc_setAssociatedObject(iv,kADTWBCachedImage6027,im,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(iv,kADTWBDecision6027,@(own),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if(!own){ ADNativeTWBRelease6027(iv); return; }
        CGFloat a=0.50*(MAX(0,MIN(100,gP.whiteTameStrength))/100.0);
        CALayer *ov=objc_getAssociatedObject(iv,kADWhiteTameOverlayKey);
        if(!ov){
            ov=[CALayer layer]; ov.name=@"AmazonDarkWhiteTame6027";
            [iv.layer addSublayer:ov];
            objc_setAssociatedObject(iv,kADWhiteTameOverlayKey,ov,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(ov.superlayer!=iv.layer) [iv.layer addSublayer:ov];
        ov.frame=iv.bounds;
        ov.cornerRadius=iv.layer.cornerRadius;
        ov.backgroundColor=[UIColor colorWithWhite:0 alpha:a].CGColor;
        ov.zPosition=9999;
    } @catch(...) {}
}

static void ADApplyNativeWhiteTameView(UIView *v){
    if(!kADLegacyTWB6027){ ADApplyNativeWhiteTameDirect6027(v); return; }
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
        } else {
            if (ov.superlayer != v.layer) [v.layer addSublayer:ov];
            ov.frame=v.bounds; ov.backgroundColor=[UIColor colorWithWhite:0 alpha:a].CGColor; ov.zPosition=9999;
        }
    } @catch(...) {}
}
static void ADPrimeNativeWhiteTame363(UIView *v, UIImage *incoming){
    if(!kADLegacyTWB6027) return;
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
        if(kADLegacyTWB6027) ADSubscribeOverlay394(self);

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
static UIImage *ADGlyphifyForView(UIImage *img, UIView *v){
    @try {
        if (v && ADMenuRole382(v)==1) return nil;
        if (v && ADIsCategoryArtwork379(v)) return nil;
        if (v && !ADInTabBarChain(v) && !ADIsChromeGlyphContext(v)){
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
    if (gADGlyphWriting) {
        %orig;
        return;
    }
    if (!image || ADIsWebKitOwned(self)) {
        %orig;
        if(!kADLegacyTWB6027 && !image) ADNativeTWBRelease6027(self);
        return;
    }
    // Detached: nothing to walk yet. Defer to didMoveToWindow, where ancestry -- and
    // therefore the tab-bar test -- is knowable.
    if (!self.superview && !self.window) {
        %orig;
        if(!kADLegacyTWB6027) ADNativeTWBRelease6027(self);
        return;
    }
    @try { if (kADLegacyTWB6027 && gP.whiteTame && self.window && !ADInTabBarChain(self)) ADPrimeNativeWhiteTame363(self,image); } @catch(...) {}
    @try {
        // THE tab-bar fix. The dump proved unselected tab icons are dark BITMAPS
        // going invisible on the dark bar, so we still convert them. What we must NOT
        // do is pin the tint: a converted template inherits the bar's tint, which is
        // what lets the selected state colour it blue. Pinning fg is what turned the
        // cart white -- that was the real defect behind four builds of gating, not the
        // conversion.
        if (ADInTabBarChain(self)) {
            %orig;                                       // install the artwork
            if(!kADLegacyTWB6027) ADNativeTWBRelease6027(self);
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

// v5.446: React Native image views reassert TWB during recycling/layout.
%hook RCTUIImageViewAnimated
- (void)didMoveToSuperview {
    %orig;
    if (!gP.enabled || !gP.whiteTame) return;
    if(!kADLegacyTWB6027){ ADApplyNativeWhiteTameDirect6027((UIView *)self); return; }
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
        if(!kADLegacyTWB6027){
            if(gP.enabled&&gP.whiteTame&&vv.window) ADApplyNativeWhiteTameDirect6027(vv);
            return;
        }
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

}

#pragma clang diagnostic pop
