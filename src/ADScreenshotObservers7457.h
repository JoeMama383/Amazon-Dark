// Bounded registration evidence only. Never suppress, redirect, or invoke observers.
// No retained observer/block objects, screenshots, notification userInfo, or UI text.
static NSMutableArray *gADScreenshotRegistrations7457=nil;
static void ADRecordScreenshotRegistration7457(NSString *name,id observer,SEL selector,BOOL blockBased){
    if(![name isEqualToString:UIApplicationUserDidTakeScreenshotNotification])return;
    @try {
        @synchronized(NSNotificationCenter.class){
            if(!gADScreenshotRegistrations7457)gADScreenshotRegistrations7457=[NSMutableArray new];
            if(gADScreenshotRegistrations7457.count>=64)return;
            NSArray *stack=NSThread.callStackSymbols;
            if(stack.count>12)stack=[stack subarrayWithRange:NSMakeRange(0,12)];
            [gADScreenshotRegistrations7457 addObject:@{
                @"kind":blockBased?@"block-registration":@"selector-registration",
                @"observerClass":observer?NSStringFromClass([observer class]):@"not-available",
                @"selector":selector?NSStringFromSelector(selector):@"block",
                @"registrationStack":stack?:@[]
            }];
        }
    } @catch(...) {}
}
static NSString *ADScreenshotRegistrationReport7457(void){
    @try {
        NSArray *rows=nil;
        @synchronized(NSNotificationCenter.class){rows=[gADScreenshotRegistrations7457 copy]?:@[];}
        NSData *data=[NSJSONSerialization dataWithJSONObject:rows options:NSJSONWritingPrettyPrinted error:NULL];
        NSString *json=data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:@"[]";
        return [NSString stringWithFormat:@"\nSCREENSHOT_OBSERVER_REGISTRATIONS count=%lu cap=64 scope=registrations-after-tweak-load not-proof-of-delivery=1\n%@\n",(unsigned long)rows.count,json];
    } @catch(...) {return @"\nSCREENSHOT_OBSERVER_REGISTRATIONS unavailable\n";}
}
