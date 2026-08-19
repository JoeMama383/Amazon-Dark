// Native color transformation interface.

#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef NS_ENUM(NSInteger, ADColorRole) {
    ADColorRoleBackground = 0,
    ADColorRoleForeground = 1,
    ADColorRoleBorder     = 2,

    ADColorRoleAuto       = 3,
};

typedef struct {
    double brightness;
    double contrast;
    double grayscale;
    double sepia;
    double bgR, bgG, bgB;
    double fgR, fgG, fgB;
} ADThemeConfig;

extern ADThemeConfig ADTheme;
void ADColorSetTheme(ADThemeConfig cfg);

void ADModifyRGB(ADColorRole role,
                 CGFloat r,  CGFloat g,  CGFloat b,
                 CGFloat *outR, CGFloat *outG, CGFloat *outB);

UIColor  *ADModifyUIColor(UIColor *c, ADColorRole role);
CGColorRef ADModifyCGColor(CGColorRef c, ADColorRole role) CF_RETURNS_NOT_RETAINED;

BOOL ADIsModifiedUIColor(UIColor *c);

BOOL ADIsModifiedUIColorForRole(UIColor *c, ADColorRole role);

void ADParseHexInto(const char *hex, double *r, double *g, double *b);

#ifdef __cplusplus
}
#endif
