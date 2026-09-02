/*
 * AmazonDark — Settings pane.
 *
 * Mirrors CarBridgeReborn's shipped prefs controller, which runs correctly on
 * this device. The reason earlier versions of this file crashed was never the
 * code: the Linux CI toolchain emitted arm64e with the OLD ABI (capabilities
 * 0x0), so any call from our bundle into Preferences.framework failed PAC
 * authentication and killed Settings. The workflow now builds on macos-14 with
 * Apple's clang (capabilities 0x80), which is what makes this file viable.
 *
 * Two details that matter and are easy to get wrong:
 *   - %new is REQUIRED on adRespringTapped. Overrides (bundle, specifiers,
 *     viewWillAppear:) resolve through the superclass, but a brand-new
 *     selector that UIKit looks up by name is not registered on a %subclass
 *     without it -- CBR lost a build to exactly that (doesNotRecognizeSelector
 *     -> UIBarButtonItem _triggerActionForEvent:).
 *   - self must be cast to PSListController to message it: Logos forward
 *     declares the %subclass, so clang rejects the bare call.
 */
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>


#define AD_JB_PLIST  @"/var/jb/var/mobile/Library/Preferences/com.colindavidr.amazondark.plist"
#define BUNDLE_PATH  @"/var/jb/Library/PreferenceBundles/ADPrefs.bundle"

@interface PSSpecifier : NSObject
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

static void ADWritePreference(NSString *key,id value){
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
    return [NSBundle bundleWithPath:BUNDLE_PATH];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    @try {
        NSString *key = [specifier propertyForKey:@"key"];
        if (!key.length) return @YES;
        NSDictionary *file = [NSDictionary dictionaryWithContentsOfFile:AD_JB_PLIST];
        id v = file[key];
        if (v) return v;
        id def = [specifier propertyForKey:@"default"];
        return def ?: @YES;
    } @catch (NSException *e) { return @YES; }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    @try {
        NSString *key = [specifier propertyForKey:@"key"];
        if (key.length) ADWritePreference(key,value);
        gADChanged = YES;
        // Reveal the Respring button once something actually changed --
        // the standard Settings idiom, and what CBR ships.
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
    } @catch (NSException *e) {}
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
