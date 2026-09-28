// v7.517: Person > Your Returns rehydration keeps exactly one React Native border.
// v7.514/v7.516 treated every card-sized RCTView below yr-titlettl as a physical
// card. React nests multiple near-card-sized wrappers there, so each wrapper was
// given its own RCT border and the result was the visible concentric outlines.
// Keep the bounded section/text rehydration, but only the OUTERMOST matching RCTView
// owns the rounded gray stroke. Any nested candidate is explicitly borderless.
static const void *kADPersonReturnsSection7514=&kADPersonReturnsSection7514;
static const void *kADPersonReturnsOutline7514=&kADPersonReturnsOutline7514; // stale v7.514 shape cleanup key
static BOOL ADPersonReturnsUnder7514(UIView *v){
    if(!v)return NO;
    @try { for(UIView *n=v;n;n=n.superview){ if(objc_getAssociatedObject(n,kADPersonReturnsSection7514))return YES; if([n.accessibilityIdentifier isEqualToString:@"me"])break; } } @catch(...) {}
    return NO;
}
static BOOL ADPersonReturnsCard7514(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView")||!ADPersonReturnsUnder7514(v))return NO;
    @try { CGFloat w=v.bounds.size.width,h=v.bounds.size.height; return w>=250.0&&w<=335.0&&h>=52.0&&h<=105.0; } @catch(...) { return NO; }
}
static BOOL ADPersonReturnsHasCardAncestor7517(UIView *v){
    if(!v)return NO;
    @try {
        for(UIView *n=v.superview;n&&n!=v.window;n=n.superview){
            if(ADPersonReturnsCard7514(n))return YES;
            if(objc_getAssociatedObject(n,kADPersonReturnsSection7514))break;
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
    } @catch(...) {}
    return NO;
}
static BOOL ADPersonReturnsOuterCard7517(UIView *v){
    return ADPersonReturnsCard7514(v)&&!ADPersonReturnsHasCardAncestor7517(v);
}
static void ADPersonOwnReturnsCard7514(UIView *v){
    if(!v)return;
    @try {
        // Always retire the obsolete v7.514 shape if a live upgraded process still has it.
        CAShapeLayer *old=objc_getAssociatedObject(v,kADPersonReturnsOutline7514);
        if(old){ [old removeFromSuperlayer]; objc_setAssociatedObject(v,kADPersonReturnsOutline7514,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        if(!(gP.enabled&&ADPersonReturnsCard7514(v)))return;
        ADSetViewBackground7226(v,ADOLED(),YES);
        v.layer.borderWidth=0.0;
        v.layer.borderColor=ADBorderGray706().CGColor;
        if(!ADPersonReturnsOuterCard7517(v)){
            // Nested React wrappers are content, never a second physical card frame.
            ADPersonSetRCTBorder7208(v,0.0);
            return;
        }
        CGFloat authored=MAX(v.layer.cornerRadius,ADPersonRCTBorderRadius7212(v));
        CGFloat radius=ADPersonDesiredRadius7212(v,authored);
        ADPersonSetRCTRadius7212(v,radius);
        ADPersonSetRCTBorder7208(v,1.0);
    } @catch(...) {}
}
static void ADPersonPrimeReturns7514(UIView *root){
    if(!root||!root.window)return;
    @try {
        NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:root]; int seen=0;
        while(q.count&&seen++<48){
            UIView *v=q.lastObject;[q removeLastObject];
            if(ADClassNameIs7183(v,"RCTView"))ADPersonOwnReturnsCard7514(v);
            const char *cn=object_getClassName(v);
            if([v isKindOfClass:[UILabel class]]||(cn&&(strstr(cn,"Text")||strstr(cn,"Paragraph")))){ ADPersonOwnText7206(v); [v setNeedsDisplay]; [v.layer setNeedsDisplay]; }
            for(UIView *c in v.subviews)if(c.window==root.window)[q addObject:c];
        }
    } @catch(...) {}
}
