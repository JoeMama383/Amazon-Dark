// v7.546 viewport: App Settings is an anonymous React sheet, not a WebView.
static NSTextStorage *ADPersonTextStorage7206(UIView *v);
static void ADPersonSavingsLightStorage7259(NSTextStorage *ts);
static const void *kADAppSettingsSheet7547=&kADAppSettingsSheet7547;
static BOOL ADAppSettingsTitle7547(UIView *v){
    return ADClassNameIs7183(v,"RCTTextView")&&[ADPersonTextStorage7206(v).string isEqualToString:@"App Settings"];
}
static BOOL ADAppSettingsBackdrop7547(UIView *v){
    return [objc_getAssociatedObject(v,kADAppSettingsSheet7547) intValue]==2;
}
static BOOL ADAppSettingsScope7547(UIView *v){
    NSUInteger depth=0;
    for(UIView *n=v;n&&depth++<24;n=n.superview){
        if(objc_getAssociatedObject(n,kADAppSettingsSheet7547))return YES;
        if([n.accessibilityIdentifier isEqualToString:@"sheet-view"])return NO;
    }
    return NO;
}
static BOOL ADAppSettingsOwn7547(UIView *v){
    if(!gP.enabled||!ADAppSettingsScope7547(v))return NO;
    @try {
        if(ADClassNameIs7183(v,"RCTTextView")){
            ADPersonSavingsLightStorage7259(ADPersonTextStorage7206(v));
            [v setNeedsDisplay];return YES;
        }
        if(!ADClassNameIs7183(v,"RCTView"))return NO;
        BOOL thin=v.bounds.size.height>0&&v.bounds.size.height<=1.5&&v.bounds.size.width>=100;
        BOOL grabber=v.bounds.size.height>0&&v.bounds.size.height<=5&&v.bounds.size.width<=60&&v.bounds.size.width>=20;
        ADSetViewBackground7226(v,(thin||grabber)?ADBorderGray706():ADOLED(),YES);
        if(thin){
            SEL sel=NSSelectorFromString(@"setBorderBottomColor:");
            if([v respondsToSelector:sel])((void(*)(id,SEL,id))objc_msgSend)(v,sel,ADBorderGray706());
        }
        return YES;
    } @catch(...) {} return NO;
}
static void ADAppSettingsPrime7547(UIView *root){
    if(!gP.enabled||objc_getAssociatedObject(root,kADAppSettingsSheet7547))return;
    objc_setAssociatedObject(root,kADAppSettingsSheet7547,@1,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // One finite pass when the exact title identifies this sheet, including earlier-mounted owners.
    NSMutableArray *q=[NSMutableArray arrayWithObject:root];NSUInteger seen=0;
    while(seen<q.count&&seen<96){UIView *v=q[seen++];ADAppSettingsOwn7547(v);[q addObjectsFromArray:v.subviews];}
    // Captured backdrop is the sheet container's sibling with one full-screen child.
    UIView *container=root.superview,*host=container.superview;
    if(!ADClassNameIs7183(host,"RCTView")||host.subviews.count!=2)return;
    for(UIView *sibling in host.subviews){
        if(sibling==container||!ADClassNameIs7183(sibling,"RCTView")||sibling.subviews.count!=1)continue;
        UIView *backdrop=sibling.subviews.firstObject;
        if(!ADClassNameIs7183(backdrop,"RCTView")||backdrop.bounds.size.width<host.bounds.size.width*.95||backdrop.bounds.size.height<host.bounds.size.height*.95)continue;
        objc_setAssociatedObject(backdrop,kADAppSettingsSheet7547,@2,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ADAppSettingsOwn7547(backdrop);
    }
}
