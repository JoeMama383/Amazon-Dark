// v7.519: preserve Amazon's authored Returns-card geometry.
//
// v7.514/v7.516 forced React border widths on every near-card-sized nested RCTView;
// v7.518 then zeroed those widths and replaced them with a CAShapeLayer contour. Both
// approaches changed ownership/geometry and could leave incomplete edges until press-time
// hydration. The Returns family now keeps every authored width/radius/edge exactly as React
// supplies it and changes only paint: existing React/CALayer border channels are gray and
// the card floor is OLED. Re-application is bounded to layout/hydration hooks already used
// by Person; there is no observer, timer, recurring traversal, or production scroll work.
static const void *kADPersonReturnsSection7514=&kADPersonReturnsSection7514;
static const void *kADPersonReturnsOutline7514=&kADPersonReturnsOutline7514; // v7.518 overlay cleanup key
static BOOL ADPersonReturnsUnder7514(UIView *v){
    if(!v)return NO;
    @try { for(UIView *n=v;n;n=n.superview){ if(objc_getAssociatedObject(n,kADPersonReturnsSection7514))return YES; if([n.accessibilityIdentifier isEqualToString:@"me"])break; } } @catch(...) {}
    return NO;
}
static BOOL ADPersonReturnsCard7514(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView")||!ADPersonReturnsUnder7514(v))return NO;
    @try { CGFloat w=v.bounds.size.width,h=v.bounds.size.height; return w>=250.0&&w<=335.0&&h>=52.0&&h<=105.0; } @catch(...) { return NO; }
}
// Paint-only React border reassertion. Intentionally NO setBorderWidth:, edge-width,
// radius, frame, bounds, transform, mask, or custom outline writes.
static void ADPersonReturnsBorderColors7519(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView"))return;
    @try {
        static SEL setters[7]={NULL};static dispatch_once_t once;
        dispatch_once(&once,^{
            const char *names[]={"setBorderColor:","setBorderTopColor:","setBorderRightColor:","setBorderBottomColor:","setBorderLeftColor:","setBorderStartColor:","setBorderEndColor:"};
            for(size_t i=0;i<7;i++)setters[i]=sel_registerName(names[i]);
        });
        UIColor *gray=ADBorderGray706();
        for(size_t i=0;i<7;i++){SEL sel=setters[i];if([v respondsToSelector:sel])((void(*)(id,SEL,UIColor *))objc_msgSend)(v,sel,gray);}
        if(v.layer.borderWidth>0.01)v.layer.borderColor=gray.CGColor;
        [v setNeedsDisplay];[v.layer setNeedsDisplay];
    } @catch(...) {}
}
static void ADPersonOwnReturnsCard7514(UIView *v){
    if(!v)return;
    @try {
        CAShapeLayer *legacy=objc_getAssociatedObject(v,kADPersonReturnsOutline7514);
        if(legacy){[legacy removeFromSuperlayer];objc_setAssociatedObject(v,kADPersonReturnsOutline7514,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
        if(!(gP.enabled&&ADPersonReturnsCard7514(v)))return;
        ADSetViewBackground7226(v,ADOLED(),YES);
        ADPersonReturnsBorderColors7519(v);
    } @catch(...) {}
}
static void ADPersonPrimeReturns7514(UIView *root){
    if(!root||!root.window)return;
    @try {
        NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:root]; int seen=0;
        while(q.count&&seen++<64){
            UIView *v=q.lastObject;[q removeLastObject];
            if(ADClassNameIs7183(v,"RCTView"))ADPersonOwnReturnsCard7514(v);
            const char *cn=object_getClassName(v);
            if([v isKindOfClass:[UILabel class]]||(cn&&(strstr(cn,"Text")||strstr(cn,"Paragraph")))){ ADPersonOwnText7206(v); [v setNeedsDisplay]; [v.layer setNeedsDisplay]; }
            for(UIView *c in v.subviews)if(c.window==root.window)[q addObject:c];
        }
    } @catch(...) {}
}
