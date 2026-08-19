// Image-key background adjustment interface.

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import "ADColor.h"

#ifdef __cplusplus
extern "C" {
#endif

UIImage *ADKeyWhiteBackground(UIImage *img, const char *bgHex);

BOOL ADIsDarkGlyph(UIImage *img);

#ifdef __cplusplus
}
#endif
