// v7.514: Person > Your Returns can remount the first carousel card against the
// viewport clip edge.  Own only the yr-titlettl-scoped card family and draw the
// single gray contour inset inside bounds so its left stroke cannot be clipped.
static const void *kADPersonReturnsSection7514=&kADPersonReturnsSection7514;
static const void *kADPersonReturnsOutline7514=&kADPersonReturnsOutline7514;
static BOOL ADPersonReturnsUnder7514(UIView *v){
    if(!v)return NO;
    @try { for(UIView *n=v;n;n=n.superview){ if(objc_getAssociatedObject(n,kADPersonReturnsSection7514))return YES; if([n.accessibilityIdentifier isEqualToString:@"me"])break; } } @catch(...) {}
    return NO;
}
static BOOL ADPersonReturnsCard7514(UIView *v){
    if(!v||!v.window||!ADInPersonTab7206(v)||!ADClassNameIs7183(v,"RCTView")||!ADPersonReturnsUnder7514(v))return NO;
    @try { CGFloat w=v.bounds.size.width,h=v.bounds.size.height; return w>=250.0&&w<=335.0&&h>=52.0&&h<=105.0; } @catch(...) { return NO; }
}
static void ADPersonOwnReturnsCard7514(UIView *v){
    if(!v)return;
    @try {
        CAShapeLayer *ol=objc_getAssociatedObject(v,kADPersonReturnsOutline7514);
        BOOL own=gP.enabled&&ADPersonReturnsCard7514(v);
        if(!own){ if(ol&&v.window){[ol removeFromSuperlayer];objc_setAssociatedObject(v,kADPersonReturnsOutline7514,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);} return; }
        ADSetViewBackground7226(v,ADOLED(),YES);
        v.layer.borderWidth=0.0; ADPersonSetRCTBorder7208(v,0.0);
        if(!ol){
            ol=[CAShapeLayer layer]; ol.name=@"AmazonDarkPersonReturnsOutline7514"; ol.fillColor=[UIColor clearColor].CGColor; ol.lineWidth=1.0;
            ol.actions=@{@"bounds":[NSNull null],@"position":[NSNull null],@"path":[NSNull null],@"strokeColor":[NSNull null],@"zPosition":[NSNull null]};
            [v.layer addSublayer:ol]; objc_setAssociatedObject(v,kADPersonReturnsOutline7514,ol,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if(ol.superlayer!=v.layer)[v.layer addSublayer:ol];
        CGFloat r=MAX(8.0,MAX(v.layer.cornerRadius,ADPersonRCTBorderRadius7212(v)));
        ol.frame=v.bounds; ol.strokeColor=ADBorderGray706().CGColor; ol.lineWidth=1.0;
        ol.path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(v.bounds,0.75,0.75) cornerRadius:r].CGPath;
        ol.zPosition=FLT_MAX; ol.hidden=v.hidden||v.alpha<0.01;
    } @catch(...) {}
}
static void ADPersonPrimeReturns7514(UIView *root){
    if(!root||!root.window)return;
    @try {
        NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:root]; int seen=0;
        while(q.count&&seen++<48){
            UIView *v=q.lastObject;[q removeLastObject];
            if(ADClassNameIs7183(v,"RCTView"))ADPersonOwnReturnsCard7514(v);
            const char *cn=object_getClassName(v); if([v isKindOfClass:[UILabel class]]||(cn&&(strstr(cn,"Text")||strstr(cn,"Paragraph")))){ADPersonOwnText7206(v);[v setNeedsDisplay];[v.layer setNeedsDisplay];}
            for(UIView *c in v.subviews)if(c.window==root.window)[q addObject:c];
        }
    } @catch(...) {}
}
