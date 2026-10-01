// Match the native WebKit editing environment to the existing Dark input policy.
// Only the current WKContentView owns this override; release it when editing ends.
static const void *kADWebKeyboardStyle7546=&kADWebKeyboardStyle7546;
static __thread BOOL ADWebKeyboardStyleWrite7546=NO;
static void ADWebKeyboardStyle7546(UIView *view,BOOL acquire){
    if(!view)return;
    @try {
        NSNumber *saved=objc_getAssociatedObject(view,kADWebKeyboardStyle7546);
        if(acquire&&gP.enabled){
            if(!saved)objc_setAssociatedObject(view,kADWebKeyboardStyle7546,@(view.overrideUserInterfaceStyle),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if(view.overrideUserInterfaceStyle!=UIUserInterfaceStyleDark){
                ADWebKeyboardStyleWrite7546=YES;
                view.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
            }
        } else if(saved){
            objc_setAssociatedObject(view,kADWebKeyboardStyle7546,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            ADWebKeyboardStyleWrite7546=YES;
            view.overrideUserInterfaceStyle=(UIUserInterfaceStyle)saved.integerValue;
        }
    } @catch(...) {} @finally { ADWebKeyboardStyleWrite7546=NO; }
}
static UIUserInterfaceStyle ADWebKeyboardRequestedStyle7546(UIView *view,UIUserInterfaceStyle style){
    NSNumber *saved=objc_getAssociatedObject(view,kADWebKeyboardStyle7546);
    if(saved&&!ADWebKeyboardStyleWrite7546){
        objc_setAssociatedObject(view,kADWebKeyboardStyle7546,@(style),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if(gP.enabled)return UIUserInterfaceStyleDark;
        objc_setAssociatedObject(view,kADWebKeyboardStyle7546,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return style;
}
