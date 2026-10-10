// Syntax-only declarations, not a replacement for the iOS SDK/device build.
#include <string.h>
#include <math.h>
typedef signed char BOOL;
typedef unsigned long NSUInteger;
typedef long NSInteger;
typedef double CFTimeInterval;
typedef unsigned long UIBackgroundTaskIdentifier;
#define YES ((BOOL)1)
#define NO ((BOOL)0)
#define nil __null
#define UIBackgroundTaskInvalid ((UIBackgroundTaskIdentifier)-1)
#define NSUTF8StringEncoding 4
#define NSDocumentDirectory 9
#define NSUserDomainMask 1
#define NSKeyValueObservingOptionNew 1
#define NSJSONWritingPrettyPrinted 1
#define NSDataWritingAtomic 1
#define NSEC_PER_SEC 1000000000ull
#define DISPATCH_TIME_NOW 0
#define DISPATCH_QUEUE_PRIORITY_DEFAULT 0
#define AD_VERSION "v7.596-performance-probe-runtime-audit"
@class NSString,NSArray,NSDictionary,NSError;
@protocol NSFastEnumeration
- (NSUInteger)countByEnumeratingWithState:(void*)state objects:(id __unsafe_unretained *)buffer count:(NSUInteger)len;
@end
@interface NSObject
+ (instancetype)new;
+ (id)class;
- (id)class;
- (BOOL)isKindOfClass:(id)cls;
- (BOOL)isEqual:(id)value;
- (id)copy;
- (void)addObserver:(id)o forKeyPath:(NSString *)k options:(NSUInteger)n context:(void*)c;
- (void)removeObserver:(id)o forKeyPath:(NSString *)k context:(void*)c;
- (void)observeValueForKeyPath:(NSString *)k ofObject:(id)o change:(NSDictionary *)d context:(void*)c;
@end
@interface NSString:NSObject
+ (id)stringWithUTF8String:(const char*)s;
+ (instancetype)stringWithFormat:(NSString*)f,...;
+ (instancetype)stringWithContentsOfFile:(NSString*)p encoding:(NSUInteger)e error:(NSError**)error;
- (NSString*)stringByAppendingPathComponent:(NSString*)s;
- (NSString*)stringByAppendingString:(NSString*)s;
- (NSString*)stringByReplacingOccurrencesOfString:(NSString*)s withString:(NSString*)r;
- (BOOL)writeToFile:(NSString*)p atomically:(BOOL)a encoding:(NSUInteger)e error:(NSError**)err;
@property(readonly) double doubleValue;
@end
@interface NSNumber:NSObject
+ (instancetype)numberWithBool:(BOOL)n;
+ (instancetype)numberWithInt:(int)n;
+ (instancetype)numberWithUnsignedInt:(unsigned)n;
+ (instancetype)numberWithUnsignedInteger:(NSUInteger)n;
+ (instancetype)numberWithUnsignedLong:(unsigned long)n;
+ (instancetype)numberWithDouble:(double)n;
@property(readonly) double doubleValue;
@end
@interface NSArray:NSObject<NSFastEnumeration>
+ (instancetype)arrayWithObjects:(const id[])objects count:(NSUInteger)cnt;
@property(readonly) NSUInteger count;
@property(readonly) id firstObject;
- (id)objectAtIndexedSubscript:(NSUInteger)i;
- (BOOL)containsObject:(id)o;
@end
@interface NSMutableArray:NSArray
+ (instancetype)array;
- (void)addObject:(id)o;
@end
@interface NSDictionary:NSObject<NSFastEnumeration>
+ (instancetype)dictionaryWithObjects:(const id[])objects forKeys:(const id[])keys count:(NSUInteger)cnt;
- (id)objectForKeyedSubscript:(id)key;
@end
@interface NSMutableDictionary:NSDictionary
+ (instancetype)dictionary;
- (void)setObject:(id)obj forKeyedSubscript:(id)key;
@end
@interface NSHashTable:NSObject
+ (instancetype)weakObjectsHashTable;
@property(readonly) NSUInteger count;
@property(readonly) NSArray *allObjects;
- (id)objectAtIndexedSubscript:(NSUInteger)i;
- (BOOL)containsObject:(id)o;
- (void)addObject:(id)o;
@end
@interface NSMapTable:NSObject
+ (instancetype)weakToStrongObjectsMapTable;
@property(readonly) NSUInteger count;
- (void)setObject:(id)o forKey:(id)k;
- (id)objectForKey:(id)k;
- (void)removeObjectForKey:(id)k;
@end
@interface NSNotification:NSObject @end
@interface NSNotificationCenter:NSObject
+ (instancetype)defaultCenter;
- (void)addObserver:(id)o selector:(SEL)s name:(NSString*)n object:(id)obj;
@end
extern NSString *UIApplicationDidBecomeActiveNotification,*UIApplicationWillResignActiveNotification,*NSRunLoopCommonModes;
@interface NSRunLoop:NSObject
+ (instancetype)mainRunLoop;
- (void)addTimer:(id)t forMode:(NSString*)m;
@end
@interface NSTimer:NSObject
+ (instancetype)timerWithTimeInterval:(double)t target:(id)obj selector:(SEL)s userInfo:(id)info repeats:(BOOL)r;
- (void)invalidate;
@end
@interface NSDate:NSObject
+ (instancetype)date;
@property(readonly) double timeIntervalSince1970;
@end
@interface NSUUID:NSObject
+ (instancetype)UUID;
@property(readonly) NSString *UUIDString;
@end
@interface NSFileManager:NSObject
+ (instancetype)defaultManager;
- (BOOL)fileExistsAtPath:(NSString*)p;
- (BOOL)removeItemAtPath:(NSString*)p error:(NSError**)err;
@end
@interface NSData:NSObject
- (BOOL)writeToFile:(NSString*)p options:(NSUInteger)o error:(NSError**)err;
@end
@interface NSJSONSerialization:NSObject
+ (NSData*)dataWithJSONObject:(id)obj options:(NSUInteger)o error:(NSError**)err;
@end
@interface UIApplication:NSObject
+ (instancetype)sharedApplication;
- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithExpirationHandler:(void(^)(void))h;
- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)t;
@end
@interface CADisplayLink:NSObject
+ (instancetype)displayLinkWithTarget:(id)obj selector:(SEL)s;
- (void)addToRunLoop:(NSRunLoop*)r forMode:(NSString*)m;
- (void)invalidate;
@property(readonly) double timestamp;
@end
@interface UIViewController:NSObject @end
NSString *NSStringFromClass(id);
@interface UIEvent:NSObject
@property(readonly) NSInteger type;
@property(readonly) double timestamp;
@end
#define UIEventTypeTouches 0
@protocol WKScriptMessageHandler @end
@interface WKUserContentController:NSObject
- (void)addScriptMessageHandler:(id)h name:(NSString*)n;
- (void)removeScriptMessageHandlerForName:(NSString*)n;
@end
@interface WKWebViewConfiguration:NSObject
@property(readonly) WKUserContentController *userContentController;
@end
@interface WKWebView:NSObject
@property(readonly) id window;
@property(readonly) BOOL loading;
@property(readonly) WKWebViewConfiguration *configuration;
- (void)evaluateJavaScript:(NSString*)s completionHandler:(void(^)(id,NSError*))h;
@end
@interface WKFrameInfo:NSObject
@property(readonly,getter=isMainFrame) BOOL mainFrame;
@end
@interface WKScriptMessage:NSObject
@property(readonly) NSString *name;
@property(readonly) WKFrameInfo *frameInfo;
@property(readonly) id body;
@end
NSArray *NSSearchPathForDirectoriesInDomains(NSUInteger,NSUInteger,BOOL);
CFTimeInterval CACurrentMediaTime(void);
typedef void *dispatch_queue_t;
typedef long dispatch_once_t;
void dispatch_once(dispatch_once_t*,void(^)(void));
void dispatch_async(dispatch_queue_t,void(^)(void));
void dispatch_after(unsigned long long,dispatch_queue_t,void(^)(void));
unsigned long long dispatch_time(unsigned long long,long long);
dispatch_queue_t dispatch_get_main_queue(void);
dispatch_queue_t dispatch_get_global_queue(long,unsigned long);
static struct {BOOL enabled;} gP;
static BOOL gADUIProbeBusy7362;
static BOOL ADSkelActive7339(void){return NO;}
static NSArray *ADTrackedWebViews(void){return nil;}
