// v7.568: captured Health/Grocery React sheets. Discovery is an exact leaf event;
// only the first positive identification primes earlier-mounted descendants.
static const void *kADServiceSheet7565=&kADServiceSheet7565;
static void ADServiceImage7565(UIImageView *iv);
static void ADServicePaint7565(UIView *v);
static UIView *ADServiceRoot7565(UIView *v){
    if(!gP.enabled||!v||!v.window)return nil;
    for(NSUInteger i=0;v&&i<28;i++,v=v.superview){
        if([objc_getAssociatedObject(v,kADServiceSheet7565) intValue]==1)return v;
        if([v.accessibilityIdentifier isEqualToString:@"sheet-view"])return nil;
    }
    return nil;
}
static BOOL ADServiceScope7565(UIView *v){
    return gP.enabled&&([objc_getAssociatedObject(v,kADServiceSheet7565) intValue]==2||ADServiceRoot7565(v)!=nil);
}
static void ADServiceDiscover7565(UIView *v,NSTextStorage *storage){
    if(!gP.enabled||!v.window)return;
    NSString *aid=v.accessibilityIdentifier?:@"";
    BOOL witness=[aid hasPrefix:@"pill-bw_health_ai_pill_"];
    if(!witness&&ADClassNameIs7183(v,"RCTTextView")){
        NSString *text=(storage?:ADPersonTextStorage7206(v)).string;
        witness=[text isEqualToString:@"Find a nearby store"]||[text isEqualToString:@"See all health services"];
    }
    if(!witness)return;
    UIView *root=nil;BOOL inset=NO;
    for(UIView *n=v;n;n=n.superview){
        if([n.accessibilityIdentifier isEqualToString:@"sheet-inset-view"])inset=YES;
        if([n.accessibilityIdentifier isEqualToString:@"sheet-view"]){root=n;break;}
    }
    if(!root||!inset||objc_getAssociatedObject(root,kADServiceSheet7565))return;
    objc_setAssociatedObject(root,kADServiceSheet7565,@1,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSMutableArray *q=[NSMutableArray arrayWithObject:root];
    for(NSUInteger i=0;i<q.count&&i<160;i++){
        UIView *n=[q objectAtIndex:i];ADServicePaint7565(n);
        if([n isKindOfClass:[UIImageView class]])ADServiceImage7565((UIImageView *)n);
        [q addObjectsFromArray:n.subviews];
    }
    // Same captured sibling topology as App Settings; preserve the grabber and geometry.
    UIView *container=root.superview,*host=container.superview;
    if(ADClassNameIs7183(host,"RCTView")&&host.subviews.count==2){
        for(UIView *s in host.subviews){
            if(s==container||!ADClassNameIs7183(s,"RCTView")||s.subviews.count!=1)continue;
            UIView *b=s.subviews.firstObject;
            if(!ADClassNameIs7183(b,"RCTView")||b.bounds.size.width<host.bounds.size.width*.95||b.bounds.size.height<host.bounds.size.height*.95)continue;
            objc_setAssociatedObject(b,kADServiceSheet7565,@2,OBJC_ASSOCIATION_RETAIN_NONATOMIC);ADServicePaint7565(b);
        }
    }
}
static UIColor *ADServiceFill7565(UIView *v,UIColor *color){
    if(!ADServiceScope7565(v))return color;
    if(objc_getAssociatedObject(v,kADServiceSheet7565))return ADOLED();
    CGFloat r=0,g=0,b=0,a=0;
    if(color&&[color getRed:&r green:&g blue:&b alpha:&a]&&a>.05&&MIN(r,MIN(g,b))>.75){
        BOOL pill=[v.superview.accessibilityIdentifier hasPrefix:@"pill-bw_health_ai_pill_"];
        return pill?ADMenuButtonFill7255():ADOLED();
    }
    return color;
}
static void ADServicePaint7565(UIView *v){
    if(!ADServiceScope7565(v))return;
    if(ADClassNameIs7183(v,"RCTTextView")){
        ADMenuLightStorage7255(ADPersonTextStorage7206(v));[v setNeedsDisplay];return;
    }
    if(!ADClassNameIs7183(v,"RCTView"))return;
    UIColor *old=v.backgroundColor,*want=ADServiceFill7565(v,old);
    if(want&&![want isEqual:old])ADSetViewBackground7226(v,want,YES);
    // Recolor existing React borders only; do not add a second layer border or change radii.
    SEL sel=NSSelectorFromString(@"setBorderColor:");
    if([v respondsToSelector:sel])((void(*)(id,SEL,id))objc_msgSend)(v,sel,ADBorderGray706());
}
