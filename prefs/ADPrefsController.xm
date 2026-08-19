// AmazonDark Settings bundle: preference I/O, live notification, optional respring.

#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

#define AD_DOMAIN    @"com.colindavidr.amazondark"
#define AD_JB_PLIST  @"/var/jb/var/mobile/Library/Preferences/com.colindavidr.amazondark.plist"
#define BUNDLE_PATH  @"/var/jb/Library/PreferenceBundles/ADPrefs.bundle"

@interface PSSpecifier : NSObject
+ (id)groupSpecifierWithName:(NSString *)name;
+ (id)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(NSInteger)cell edit:(Class)edit;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
@end

@interface PSListController : UIViewController
- (id)specifiers;
- (NSArray *)loadSpecifiersFromPlistName:(NSString *)plistName target:(id)target;
- (NSBundle *)bundle;
@end

@interface SBSRelaunchAction : NSObject
+ (instancetype)actionWithReason:(NSString *)reason options:(NSUInteger)options targetURL:(NSURL *)url;
@end
@interface FBSSystemService : NSObject
+ (instancetype)sharedService;
- (void)sendActions:(NSSet *)actions withResult:(id)result;
@end

static BOOL gADChanged = NO;

static void ADWriteBoth(NSString *key, id value){
    @try {
        CFPreferencesSetAppValue((__bridge CFStringRef)key,
                                 (__bridge CFPropertyListRef)value,
                                 (__bridge CFStringRef)AD_DOMAIN);
        CFPreferencesAppSynchronize((__bridge CFStringRef)AD_DOMAIN);
    } @catch (NSException *e) {}
    @try {
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithContentsOfFile:AD_JB_PLIST]
                                 ?: [NSMutableDictionary dictionary];
        d[key] = value;
        [d writeToFile:AD_JB_PLIST atomically:YES];
    } @catch (NSException *e) {}
    @try {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR("com.colindavidr.amazondark/prefs-changed"), NULL, NULL, YES);
    } @catch (NSException *e) {}
}

%subclass ADRootListController : PSListController

- (id)navigationTitle { return @"AmazonDark"; }

- (NSBundle *)bundle {
    NSBundle *b = [NSBundle bundleWithPath:BUNDLE_PATH];
    if (b) return b;
    return %orig;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    @try {
        NSString *key = [specifier propertyForKey:@"key"];
        if (!key.length) return @YES;
        NSDictionary *file = [NSDictionary dictionaryWithContentsOfFile:AD_JB_PLIST];
        id v = file[key];
        if (v) return v;
        CFPropertyListRef cv = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                         (__bridge CFStringRef)AD_DOMAIN);
        if (cv) return (__bridge_transfer id)cv;
        id def = [specifier propertyForKey:@"default"];
        return def ?: @YES;
    } @catch (NSException *e) { return @YES; }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    @try {
        NSString *key = [specifier propertyForKey:@"key"];
        if (key.length) ADWriteBoth(key, value);
        gADChanged = YES;

        UIViewController *vc = (UIViewController *)self;
        if (!vc.navigationItem.rightBarButtonItem){
            vc.navigationItem.rightBarButtonItem =
                [[UIBarButtonItem alloc] initWithTitle:@"Respring"
                                                 style:UIBarButtonItemStyleDone
                                                target:self
                                                action:@selector(adRespringTapped)];
        }
    } @catch (NSException *e) {}
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    @try {
        UIViewController *vc = (UIViewController *)self;
        if (gADChanged && !vc.navigationItem.rightBarButtonItem){
            vc.navigationItem.rightBarButtonItem =
                [[UIBarButtonItem alloc] initWithTitle:@"Respring"
                                                 style:UIBarButtonItemStyleDone
                                                target:self
                                                action:@selector(adRespringTapped)];
        }
    } @catch (NSException *e) {}
}

%new
- (void)adRespringTapped {
    @try {
        SBSRelaunchAction *a = [%c(SBSRelaunchAction) actionWithReason:@"AmazonDark"
                                                               options:(1 << 2) targetURL:nil];
        [[%c(FBSSystemService) sharedService] sendActions:[NSSet setWithObject:a] withResult:nil];
    } @catch (NSException *e) {}
}

- (id)specifiers {
    NSArray *specs = nil;
    @try {
        specs = [(PSListController *)self loadSpecifiersFromPlistName:@"Root" target:self];
    } @catch (NSException *e) { }
    if (!specs.count){
        @try {
            NSMutableArray *out = [NSMutableArray array];
            [out addObject:[%c(PSSpecifier) groupSpecifierWithName:@""]];
            PSSpecifier *sw = [%c(PSSpecifier) preferenceSpecifierNamed:@"Enabled"
                                  target:self
                                     set:@selector(setPreferenceValue:specifier:)
                                     get:@selector(readPreferenceValue:)
                                  detail:nil cell:6 edit:nil];
            [sw setProperty:@"enabled" forKey:@"key"];
            [sw setProperty:AD_DOMAIN  forKey:@"defaults"];
            [sw setProperty:@YES       forKey:@"default"];
            [out addObject:sw];
            specs = out;
        } @catch (NSException *e) { specs = @[]; }
    }
    @try {
        objc_setAssociatedObject(self, "adSpecs", specs, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        Ivar iv = class_getInstanceVariable(%c(PSListController), "_specifiers");
        if (iv) object_setIvar(self, iv, specs);
    } @catch (NSException *e) {}
    return specs;
}

%end

%ctor {
    %init;
}
