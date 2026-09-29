// v7.518: one foreground contour per physical Returns card.
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
// One contour above content, never one contour for every nested wrapper.
static void ADPersonOwnReturnsCard7514(UIView *v){
    if(!v)return;
    @try {
        CAShapeLayer *ol=objc_getAssociatedObject(v,kADPersonReturnsOutline7514);
        BOOL card=gP.enabled&&ADPersonReturnsCard7514(v);
        BOOL outer=card&&ADPersonReturnsOuterCard7517(v);
        if(!outer&&ol){[ol removeFromSuperlayer];objc_setAssociatedObject(v,kADPersonReturnsOutline7514,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);ol=nil;}
        if(!card)return;
        ADSetViewBackground7226(v,ADOLED(),YES);
        // RCT draws its border into layer contents, underneath child backgrounds.
        // Clearing every nested RCT border avoids the previous double outlines.
        v.layer.borderWidth=0.0;
        ADPersonSetRCTBorder7208(v,0.0);
        if(!outer)return;
        if(!ol){
            ol=[CAShapeLayer layer];ol.name=@"AmazonDarkPersonReturnsOutline7518";
            ol.fillColor=[UIColor clearColor].CGColor;
            ol.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"path":[NSNull null],@"strokeColor":[NSNull null],@"zPosition":[NSNull null]};
            objc_setAssociatedObject(v,kADPersonReturnsOutline7514,ol,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if(ol.superlayer!=v.layer)[v.layer addSublayer:ol];
        CGFloat radius=ADPersonDesiredRadius7212(v,MAX(v.layer.cornerRadius,ADPersonRCTBorderRadius7212(v)));
        ol.frame=v.bounds;ol.path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(v.bounds,0.5,0.5) cornerRadius:MAX(0.0,radius-0.5)].CGPath;
        ol.strokeColor=ADBorderGray706().CGColor;ol.lineWidth=1.0;ol.zPosition=FLT_MAX;ol.hidden=NO;
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
