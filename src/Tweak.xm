// AmazonDark v7.0.0-invert — experimental
//
// A deliberate reset. Everything from the 6.x line is gone: Dark Reader, White
// Background Taming, the symbols/checkbox owners, the contrast walk, the Person raster
// machinery, every probe and every bisect switch. What produced the input latency was
// Dark Reader's MutationObserver re-theming each node as it arrived, and most of the
// 6.x apparatus existed to patch what that engine got wrong.
//
// This build asks the opposite question: what if nothing analyses anything?
//
// One inversion, applied once, by the compositor:
//
//   web    - a single document-start stylesheet inverts the root and re-inverts media
//   native - one colorInvert filter on the window layer, cancelled per image layer
//
// Double inversion is the whole trick. A filter on an ancestor composites with a filter
// on a descendant, so inverting the root and inverting an image again returns that
// image to its original colours. It costs nothing per node: no observer, no scan, no
// timer, no querySelectorAll, no getComputedStyle, no getBoundingClientRect.
//
// hue-rotate(180deg) follows the web inversion so hues land near where they started --
// a bare invert turns Amazon's orange blue. CAFilter has no hue-rotate, so the native
// side is a plain inversion and its accent colours will shift.
//
// KNOWN LIMITS, stated up front rather than discovered later:
//   - CSS-painted imagery (background-image on a div, mask, border-image) is not an
//     element that can be re-inverted by tag. The one attribute selector below covers
//     inline background-image; art painted from a stylesheet class will stay inverted.
//   - Native inversion is uniform. Imagery drawn by anything other than a UIImageView
//     layer -- a custom -drawRect:, a CAGradientLayer, a video layer -- is not
//     cancelled and will appear inverted.
//   - Colours here are mathematically inverted, not designed. This is an experiment in
//     cost, not a replacement for 6.x theming.

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#define AD_VERSION "v7.0.0-invert"

@interface CAFilter : NSObject
+ (id)filterWithName:(NSString *)name;
@end

// ─────────────────────────────────────────────────────────────────────────────
// Web: one stylesheet, injected at document start, never touched again.
// ─────────────────────────────────────────────────────────────────────────────
static NSString *ADInvertCSS(void) {
    return
    // The root carries the inversion. White pages become black, every colour flips,
    // and hue-rotate puts hues back near where they started.
    @"html{filter:invert(1) hue-rotate(180deg) !important;"
     "background-color:#ffffff !important;}"

    // Re-invert anything carrying real imagery so it composites back to normal.
    // Tag-based, so this stays a constant-time match rather than a tree search.
    "img,video,canvas,picture,svg,iframe,embed,object"
    "{filter:invert(1) hue-rotate(180deg) !important;}"

    // Amazon paints a lot of product art as an inline background-image on a plain div,
    // which no tag selector can reach. One attribute test per element, still no walk.
    "[style*=\"background-image\"]"
    "{filter:invert(1) hue-rotate(180deg) !important;}"

    // Media nested inside already re-inverted media would invert a third time.
    "img img,picture img,svg img,canvas img,video img,"
    "[style*=\"background-image\"] img,[style*=\"background-image\"] video,"
    "[style*=\"background-image\"] canvas,[style*=\"background-image\"] svg"
    "{filter:none !important;}";
}

static NSString *ADInvertJS(void) {
    static NSString *cached = nil;
    if (cached) return cached;
    NSString *css = [ADInvertCSS() stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    cached = [NSString stringWithFormat:
        @"(function(){try{"
         "if(window.__AD_INVERT7__)return;window.__AD_INVERT7__=1;"
         "var s=document.createElement('style');s.id='ad-invert7';"
         "s.textContent=\"%@\";"
         // documentStart can run before <head> exists.
         "(document.head||document.documentElement).appendChild(s);"
         "}catch(e){}})();", css];
    return cached;
}

static void ADAttachInvert(WKWebView *wv) {
    if (!wv) return;
    @try {
        WKUserContentController *ucc = wv.configuration.userContentController;
        if (!ucc) return;
        static const void *kDone = &kDone;
        if (objc_getAssociatedObject(ucc, kDone)) return;
        objc_setAssociatedObject(ucc, kDone, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        Class WKUS = NSClassFromString(@"WKUserScript");
        if (!WKUS) return;
        WKUserScript *us = [[WKUS alloc] initWithSource:ADInvertJS()
                                          injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                       forMainFrameOnly:NO];
        [ucc addUserScript:us];
    } @catch (__unused NSException *e) {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Native: one filter on the window, cancelled on image layers.
// ─────────────────────────────────────────────────────────────────────────────
static id ADColorInvertFilter(void) {
    static id f = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            Class C = NSClassFromString(@"CAFilter");
            if (C) f = [C filterWithName:@"colorInvert"];
        } @catch (__unused NSException *e) {}
    });
    return f;
}

static void ADApplyInvert(CALayer *layer) {
    if (!layer) return;
    @try {
        id f = ADColorInvertFilter();
        if (!f) return;
        if (layer.filters.count) return;   // already carries ours
        layer.filters = @[f];
    } @catch (__unused NSException *e) {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Hooks. Four of them. Each fires once per object and does no work afterwards.
// ─────────────────────────────────────────────────────────────────────────────
%hook UIWindow

- (void)didMoveToScreen {
    %orig;
    ADApplyInvert(self.layer);
}

- (void)becomeKeyWindow {
    %orig;
    ADApplyInvert(self.layer);
}

%end

%hook UIImageView

- (void)didMoveToWindow {
    %orig;
    // Cancels the window inversion for this subtree: invert of invert is identity.
    ADApplyInvert(self.layer);
}

%end

%hook WKWebView

- (void)didMoveToWindow {
    %orig;
    // The page inverts itself in CSS, so the compositor must not invert it again.
    @try {
        self.layer.filters = nil;
    } @catch (__unused NSException *e) {}
    ADAttachInvert(self);
}

%end

%ctor {
    @autoreleasepool {
        %init;
    }
}
