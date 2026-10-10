// Minimal declarations for compiling the exact sheet helpers without an iOS SDK.
typedef signed char BOOL;
#define YES ((BOOL)1)
#define NO ((BOOL)0)
#define nil __null
#define NULL __null
#define MIN(a,b) ((a)<(b)?(a):(b))
typedef unsigned long NSUInteger;
typedef unsigned long size_t;
typedef double CGFloat;
struct CGSize { CGFloat width,height; };
struct CGPoint { CGFloat x,y; };
struct CGRect { CGPoint origin; CGSize size; };
CGRect CGRectMake(CGFloat,CGFloat,CGFloat,CGFloat);
typedef void *CGImageRef;typedef void *CGContextRef;typedef void *CGColorSpaceRef;
extern "C" void *calloc(size_t,size_t);extern "C" void free(void *);
size_t CGImageGetWidth(CGImageRef);size_t CGImageGetHeight(CGImageRef);
CGColorSpaceRef CGColorSpaceCreateDeviceRGB(void);void CGColorSpaceRelease(CGColorSpaceRef);
CGContextRef CGBitmapContextCreate(void *,size_t,size_t,size_t,size_t,CGColorSpaceRef,unsigned int);
void CGContextDrawImage(CGContextRef,CGRect,CGImageRef);CGImageRef CGBitmapContextCreateImage(CGContextRef);
void CGImageRelease(CGImageRef);void CGContextRelease(CGContextRef);
enum { kCGImageAlphaPremultipliedLast=1,kCGBitmapByteOrder32Big=2,UIImageRenderingModeAlwaysTemplate=2,OBJC_ASSOCIATION_RETAIN_NONATOMIC=1 };
@interface NSObject
+ (id)class;
- (BOOL)isKindOfClass:(id)c;
- (BOOL)respondsToSelector:(SEL)s;
- (BOOL)isEqual:(id)o;
@end
@interface NSNumber:NSObject
+ (id)numberWithInt:(int)n;
- (int)intValue;
@end
@interface NSString:NSObject
- (BOOL)isEqualToString:(NSString *)s;
- (BOOL)hasPrefix:(NSString *)s;
@end
@interface NSArray:NSObject
@property(readonly) NSUInteger count;
@property(readonly) id firstObject;
- (id)objectAtIndex:(NSUInteger)i;
- (NSUInteger)countByEnumeratingWithState:(void *)s objects:(id *)o count:(NSUInteger)c;
@end
@interface NSMutableArray:NSArray
+ (id)arrayWithObject:(id)o;
- (void)addObjectsFromArray:(NSArray *)a;
@end
@interface UIColor:NSObject
- (BOOL)getRed:(CGFloat *)r green:(CGFloat *)g blue:(CGFloat *)b alpha:(CGFloat *)a;
@end
@interface UIView:NSObject
@property UIView *superview;
@property NSArray *subviews;
@property UIView *window;
@property NSString *accessibilityIdentifier;
@property CGRect bounds;
@property UIColor *backgroundColor;
- (void)setNeedsDisplay;
@end
@interface NSTextStorage:NSObject
@property NSString *string;
@end
@interface UIImage:NSObject
@property CGImageRef CGImage;
@property CGFloat scale;
@property int imageOrientation;
+ (UIImage *)imageWithCGImage:(CGImageRef)cg scale:(CGFloat)s orientation:(int)o;
- (UIImage *)imageWithRenderingMode:(int)m;
@end
@interface UIImageView:UIView
@property UIImage *image;
@property UIColor *tintColor;
@end
id objc_getAssociatedObject(id,const void *);void objc_setAssociatedObject(id,const void *,id,int);
void objc_msgSend(void);SEL NSSelectorFromString(NSString *);
static struct { BOOL enabled,whiteTame; } gP;
static BOOL gADMenuImageWrite7255;
BOOL ADClassNameIs7183(id,const char *);
NSTextStorage *ADPersonTextStorage7206(UIView *);
void ADMenuLightStorage7255(NSTextStorage *);
UIColor *ADOLED(void);UIColor *ADLightText706(void);UIColor *ADBorderGray706(void);UIColor *ADMenuButtonFill7255(void);
void ADSetViewBackground7226(UIView *,UIColor *,BOOL);
void ADMenuRemoveTWB7255(UIImageView *);void ADEnsureNativeTWBOverlay7270(UIImageView *);
