// v7.524: preserve Amazon's authored Returns-card geometry, keep the left curved edge unobscured after remounts, and keep the Returns thumbnail lane rendered/tamed without recentering the text.
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
// Exact identities survive section replacement and offline/refresh mount order.
static BOOL ADPersonReturnsIdentity7521(UIView *v){
    NSString *aid=v.accessibilityIdentifier;
    if([aid isEqualToString:@"yr_view_all_returns_card"])return YES;
    if(![aid hasPrefix:@"yr_item_"]||aid.length<=8)return NO;
    for(NSUInteger i=8;i<aid.length;i++){unichar c=[aid characterAtIndex:i];if(c<'0'||c>'9')return NO;}
    return YES;
}
// The r5 capture shows a square 290x67.3 child inside the 292x69.3,
// radius-12 yr_item_0. Its opaque floor covers the parent's curved border.
// Clear only this inset content plane; the authored card supplies the OLED floor.
static BOOL ADPersonReturnsOccluder7521(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView")||!ADInPersonTab7206(v))return NO;
    UIView *p=v.superview;
    if(!p||!ADPersonReturnsIdentity7521(p)||![p.accessibilityIdentifier hasPrefix:@"yr_item_"])return NO;
    CGRect f=v.frame;CGSize b=p.bounds.size;
    return f.origin.x>=0&&f.origin.y>=0&&f.origin.x<=2&&f.origin.y<=2&&
        fabs(CGRectGetMaxX(f)-b.width)<=2&&fabs(CGRectGetMaxY(f)-b.height)<=2;
}
// v7.522 r2 proves a second occluder survives after submenu -> back rehydration:
// an opaque 60x67.3 paint-only child fills the reserved thumbnail column at card
// local (1,1). It sits above the parent's radius-12 border raster and covers only
// the top-left/bottom-left arcs, which is why the straight left edge survives and
// pressing the card can temporarily restore the corners. Match that exact nested
// plane, not the thumbnail/image wrapper itself, and clear only its fill.
static BOOL ADPersonReturnsLeftOccluderGeometry7523(CGRect f,CGSize b){
    return f.origin.x>=0&&f.origin.x<=2.5&&f.origin.y>=0&&f.origin.y<=2.5&&
        f.size.width>=48.0&&f.size.width<=72.0&&f.size.height>=52.0&&
        fabs(CGRectGetMaxY(f)-b.height)<=2.5;
}
static BOOL ADPersonReturnsLeftCornerOccluder7523(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView")||!ADInPersonTab7206(v)||v.subviews.count)return NO;
    @try {
        UIView *host=v.superview;if(!host)return NO;
        CGRect hf=v.frame;CGSize hb=host.bounds.size;
        if(hf.origin.x<-0.5||hf.origin.y<-0.5||fabs(CGRectGetMaxX(hf)-hb.width)>1.5||fabs(CGRectGetMaxY(hf)-hb.height)>1.5)return NO;
        UIView *card=nil;
        for(UIView *n=host;n;n=n.superview){
            if(ADPersonReturnsIdentity7521(n)){card=n;break;}
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
        if(!card||![card.accessibilityIdentifier hasPrefix:@"yr_item_"])return NO;
        CGRect f=[v convertRect:v.bounds toView:card];
        return ADPersonReturnsLeftOccluderGeometry7523(f,card.bounds.size);
    } @catch(...) { return NO; }
}
static void ADPersonOwnReturnsLeftCornerOccluder7523(UIView *v){
    if(!(gP.enabled&&ADPersonReturnsLeftCornerOccluder7523(v)))return;
    ADSetViewBackground7226(v,[UIColor clearColor],YES);
    [v setNeedsDisplay];[v.layer setNeedsDisplay];
}
// The current FULL r1 proves the left lane is real content, not dead padding: the
// card contains a 48x52 RCTUIImageViewAnimated thumbnail inside a 60x67 reserved
// slot. Keep that lane dark/transparent while the raster loads and treat the raster
// itself as authored product media. Because the lane is real, do not recenter the
// text wrapper across the full 292pt card width.
static BOOL ADPersonReturnsThumbnailShellGeometry7524(CGRect f,CGSize b){
    return f.origin.x>=0&&f.origin.x<=16.0&&f.origin.y>=0&&f.origin.y<=12.5&&
        f.size.width>=40.0&&f.size.width<=72.0&&f.size.height>=48.0&&f.size.height<=68.5&&
        CGRectGetMaxX(f)<=84.0&&CGRectGetMaxY(f)<=b.height+2.5;
}
static UIView *ADPersonReturnsCard7524(UIView *v){
    if(!v)return nil;
    @try {
        for(UIView *n=v;n;n=n.superview){
            if(ADPersonReturnsIdentity7521(n)&&[n.accessibilityIdentifier hasPrefix:@"yr_item_"])return n;
            if([n.accessibilityIdentifier isEqualToString:@"me"])break;
        }
    } @catch(...) {}
    return nil;
}
static BOOL ADPersonReturnsThumbnailShell7524(UIView *v){
    if(!v||!ADClassNameIs7183(v,"RCTView")||!ADInPersonTab7206(v))return NO;
    @try {
        UIView *card=ADPersonReturnsCard7524(v);
        if(!card)return NO;
        CGRect f=[v convertRect:v.bounds toView:card];
        return ADPersonReturnsThumbnailShellGeometry7524(f,card.bounds.size);
    } @catch(...) { return NO; }
}
static void ADPersonOwnReturnsThumbnailShell7524(UIView *v){
    if(!(gP.enabled&&ADPersonReturnsThumbnailShell7524(v)))return;
    ADSetViewBackground7226(v,[UIColor clearColor],YES);
    v.layer.backgroundColor=[UIColor clearColor].CGColor;
    [v setNeedsDisplay];[v.layer setNeedsDisplay];
}
static BOOL ADPersonReturnsThumbnailLeaf7524(UIImageView *iv){
    if(!iv||!iv.window||!iv.image||!ADClassNameIs7183(iv,"RCTUIImageViewAnimated")||!ADInPersonTab7206((UIView *)iv))return NO;
    @try {
        UIView *card=ADPersonReturnsCard7524(iv);
        if(!card)return NO;
        CGRect f=[iv convertRect:iv.bounds toView:card];
        return f.origin.x>=4.0&&f.origin.x<=18.0&&f.origin.y>=4.0&&f.origin.y<=16.0&&
            f.size.width>=40.0&&f.size.width<=56.0&&f.size.height>=44.0&&f.size.height<=60.0&&
            CGRectGetMaxX(f)<=80.0&&CGRectGetMaxY(f)<=card.bounds.size.height;
    } @catch(...) { return NO; }
}
static BOOL ADPersonReturnsCardHasThumbnail7524(UIView *card){
    if(!card)return NO;
    @try {
        NSMutableArray<UIView *> *q=[NSMutableArray arrayWithArray:card.subviews];
        NSUInteger index=0; int seen=0;
        while(index<q.count&&seen++<24){
            UIView *x=q[index++];
            if([x isKindOfClass:[UIImageView class]]&&ADPersonReturnsThumbnailLeaf7524((UIImageView *)x))return YES;
            if(ADClassNameIs7183(x,"RCTView")){
                CGRect f=[x convertRect:x.bounds toView:card];
                if(ADPersonReturnsThumbnailShellGeometry7524(f,card.bounds.size))return YES;
            }
            if(seen<12)for(UIView *c in x.subviews)if(q.count<24)[q addObject:c];
        }
    } @catch(...) {}
    return NO;
}

static BOOL ADPersonReturnsUnder7514(UIView *v){
    if(!v)return NO;
    @try { for(UIView *n=v;n;n=n.superview){ if(ADPersonReturnsIdentity7521(n)||objc_getAssociatedObject(n,kADPersonReturnsSection7514))return YES; if([n.accessibilityIdentifier isEqualToString:@"me"])break; } } @catch(...) {}
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
        ADSetViewBackground7226(v,ADPersonReturnsOccluder7521(v)?[UIColor clearColor]:ADOLED(),YES);
        ADPersonReturnsBorderColors7519(v);
    } @catch(...) {}
}
static void ADPersonPrimeReturns7514(UIView *root){
    if(!root||!root.window)return;
    @try {
        NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:root]; int seen=0;
        while(q.count&&seen++<64){
            UIView *v=q.lastObject;[q removeLastObject];
            if(ADClassNameIs7183(v,"RCTView")){
                ADPersonOwnReturnsLeftCornerOccluder7523(v);
                ADPersonOwnReturnsThumbnailShell7524(v);
                ADPersonOwnReturnsCard7514(v);
            }
            const char *cn=object_getClassName(v);
            if([v isKindOfClass:[UILabel class]]||(cn&&(strstr(cn,"Text")||strstr(cn,"Paragraph")))){ ADPersonOwnText7206(v); [v setNeedsDisplay]; [v.layer setNeedsDisplay]; }
            for(UIView *c in v.subviews)if(c.window==root.window)[q addObject:c];
        }
    } @catch(...) {}
}

static NSTextStorage *ADPersonTextStorage7206(UIView *v);
// r1: the 292pt card reserves 60pt for an obscured thumbnail. Center the
// existing text wrapper using its rendered glyph bounds, not that empty column.
static void ADPersonCenterReturnsText7522(UIView *v){
    if(!gP.enabled||!v.window||!ADInPersonTab7206(v))return;
    @try {
        UIView *wrap=v;
        if([v.accessibilityIdentifier isEqualToString:@"ImageWithTextViewTextComponent"])wrap=v.superview;
        if(![wrap.accessibilityIdentifier isEqualToString:@"ImageWithTextViewParentComponent"])return;
        UIView *card=wrap.superview.superview.superview;
        if(!ADPersonReturnsIdentity7521(card)||![card.accessibilityIdentifier hasPrefix:@"yr_item_"])return;
        if(ADPersonReturnsCardHasThumbnail7524(card))return;
        UIView *text=wrap.subviews.firstObject;
        if(![text.accessibilityIdentifier isEqualToString:@"ImageWithTextViewTextComponent"])return;
        NSTextStorage *ts=ADPersonTextStorage7206(text);
        NSLayoutManager *lm=ts.layoutManagers.firstObject;
        NSTextContainer *tc=lm.textContainers.firstObject;
        if(!ts.length||!tc)return;
        [lm ensureLayoutForTextContainer:tc];
        CGRect ink=[lm usedRectForTextContainer:tc];
        if(ink.size.width<=0||ink.size.width>card.bounds.size.width-8)return;
        CGRect shown=[text convertRect:ink toView:card];
        CGPoint wanted=[card convertPoint:CGPointMake(CGRectGetMidX(card.bounds),CGRectGetMidY(shown)) toView:wrap.superview];
        CGPoint actual=[card convertPoint:CGPointMake(CGRectGetMidX(shown),CGRectGetMidY(shown)) toView:wrap.superview];
        CGFloat dx=wanted.x-actual.x;
        if(fabs(dx)>0.1){CGPoint c=wrap.center;c.x+=dx;wrap.center=c;}
    } @catch(...) {}
}
