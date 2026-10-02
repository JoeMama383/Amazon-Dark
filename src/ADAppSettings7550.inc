static NSString *ADAppSettingsLeafText7548(UIView *v){
    if(!v)return @"";
    @try {
        if([v isKindOfClass:[UILabel class]]){
            UILabel *l=(UILabel *)v;
            if(l.text.length)return l.text.lowercaseString;
            if(l.attributedText.string.length)return l.attributedText.string.lowercaseString;
        }
        if([v isKindOfClass:[UIButton class]]){
            UIButton *b=(UIButton *)v;
            NSString *t=[b titleForState:UIControlStateNormal];
            if(t.length)return t.lowercaseString;
            NSAttributedString *a=[b attributedTitleForState:UIControlStateNormal];
            if(a.string.length)return a.string.lowercaseString;
        }
        if([v isKindOfClass:[UITextField class]]){
            UITextField *tf=(UITextField *)v;
            NSString *t=tf.text.length?tf.text:tf.placeholder;
            if(t.length)return t.lowercaseString;
        }
        if([v isKindOfClass:[UITextView class]]){
            UITextView *tv=(UITextView *)v;
            if(tv.text.length)return tv.text.lowercaseString;
        }
        NSTextStorage *ts=ADPersonTextStorage7206(v);
        if(ts.string.length)return ts.string.lowercaseString;
        NSString *al=v.accessibilityLabel?:@"";
        if(al.length)return al.lowercaseString;
    } @catch(...) {}
    return @"";
}
static const void *kADAppSettingsWitness7548=&kADAppSettingsWitness7548;
static BOOL ADAppSettingsWitness7548(UIView *root){
    if(!root)return NO;
    @try {
        NSNumber *cached=objc_getAssociatedObject(root,kADAppSettingsWitness7548);
        if(cached)return cached.boolValue;
        BOOL title=NO,notifications=NO,permissions=NO,storage=NO,legal=NO,rate=NO;
        NSMutableArray<UIView *> *q=[NSMutableArray arrayWithObject:root]; NSUInteger seen=0;
        while(seen<q.count&&seen<192){
            UIView *x=q[seen++];
            NSString *t=ADAppSettingsLeafText7548(x);
            if(t.length){
                if([t containsString:@"app settings"])title=YES;
                if([t containsString:@"notifications"])notifications=YES;
                if([t containsString:@"permissions"])permissions=YES;
                if([t containsString:@"manage app storage"])storage=YES;
                if([t containsString:@"legal & about"])legal=YES;
                if([t containsString:@"rate our app"])rate=YES;
            }
            if(x.subviews.count&&q.count-seen<192)[q addObjectsFromArray:x.subviews];
        }
        int hits=(notifications?1:0)+(permissions?1:0)+(storage?1:0)+(legal?1:0)+(rate?1:0);
        BOOL match=title&&hits>=2;
        objc_setAssociatedObject(root,kADAppSettingsWitness7548,@(match),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return match;
    } @catch(...) { return NO; }
}
static UIView *ADAppSettingsRoot7548(UIView *v){
    if(!gP.enabled||!v||!v.window)return nil;
    @try {
        CGRect wb=v.window.bounds;
        for(NSUInteger d=0;v&&d<24;d++,v=v.superview){
            if([v isKindOfClass:[UIWindow class]])break;
            CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
            if(w<wb.size.width*0.82||h<120.0||h>520.0)continue;
            CGRect r=[v convertRect:v.bounds toView:v.window];
            if(CGRectGetMinY(r)<wb.size.height*0.28||CGRectGetMaxY(r)>wb.size.height+8.0)continue;
            if(ADAppSettingsWitness7548(v))return v;
        }
    } @catch(...) {}
    return nil;
}
static BOOL ADAppSettingsHandle7548(UIView *v){
    UIView *root=ADAppSettingsRoot7548(v); if(!root)return NO;
    @try {
        CGRect rr=[root convertRect:root.bounds toView:root.window],vr=[v convertRect:v.bounds toView:v.window];
        CGFloat w=vr.size.width,h=vr.size.height;
        CGFloat cx=CGRectGetMidX(vr),rcx=CGRectGetMidX(rr);
        return w>=36.0&&w<=96.0&&h>=3.0&&h<=10.0&&fabs(cx-rcx)<=22.0&&CGRectGetMinY(vr)>=CGRectGetMinY(rr)+4.0&&CGRectGetMaxY(vr)<=CGRectGetMinY(rr)+30.0;
    } @catch(...) { return NO; }
}
static BOOL ADAppSettingsDivider7548(UIView *v){
    UIView *root=ADAppSettingsRoot7548(v); if(!root||!ADClassNameIs7183(v,"RCTView"))return NO;
    @try {
        CGRect rr=[root convertRect:root.bounds toView:root.window],vr=[v convertRect:v.bounds toView:v.window];
        return vr.size.height>0&&vr.size.height<=1.5&&vr.size.width>=rr.size.width*0.72&&CGRectGetMinY(vr)>=CGRectGetMinY(rr)+38.0&&CGRectGetMaxY(vr)<=CGRectGetMaxY(rr)-8.0;
    } @catch(...) { return NO; }
}
static UIColor *ADAppSettingsTextColor7548(UIColor *old){
    if(!old||ADMenuDarkNeutral7255(old))return ADLightText706();
    return old;
}
static void ADAppSettingsOwn7548(UIView *v){
    if(!gP.enabled||!v||!v.window)return;
    UIView *root=ADAppSettingsRoot7548(v); if(!root)return;
    @try {
        if(ADAppSettingsHandle7548(v)){
            ADSetViewBackground7226(v,[UIColor colorWithWhite:0.55 alpha:1.0],YES);
            return;
        }
        if(ADAppSettingsDivider7548(v)){
            ADSetViewBackground7226(v,ADBorderGray706(),YES);
            return;
        }
        UIColor *bg=v.backgroundColor,*lbg=v.layer.backgroundColor?[UIColor colorWithCGColor:v.layer.backgroundColor]:nil;
        if(v==root||ADNeutralNearWhite7255(bg)||ADNeutralNearWhite7255(lbg)){
            ADSetViewBackground7226(v,ADOLED(),YES);
            v.layer.shadowOpacity=0.0;
            return;
        }
        if(ADClassNameIs7183(v,"RCTView")){
            CGRect rr=[root convertRect:root.bounds toView:root.window],vr=[v convertRect:v.bounds toView:v.window];
            BOOL row=vr.size.width>=rr.size.width*0.88&&vr.size.height>=34.0&&vr.size.height<=80.0&&CGRectGetMinY(vr)>=CGRectGetMinY(rr)+34.0&&CGRectGetMaxY(vr)<=CGRectGetMaxY(rr)+2.0;
            BOOL clearish=(!bg||CGColorEqualToColor(bg.CGColor,[UIColor clearColor].CGColor))&&(!v.layer.backgroundColor||CGColorGetAlpha(v.layer.backgroundColor)<=0.05);
            if(row&&clearish)ADSetViewBackground7226(v,ADOLED(),YES);
        }
        v.layer.shadowOpacity=0.0;
    } @catch(...) {}
}
static void ADAppSettingsOwnText7548(UIView *v){
    if(!gP.enabled||!ADAppSettingsRoot7548(v))return;
    @try {
        NSTextStorage *ts=ADPersonTextStorage7206(v); if(ts){ ADMenuLightStorage7255(ts); [v setNeedsDisplay]; [v.layer setNeedsDisplay]; }
        if([v isKindOfClass:[UILabel class]]){
            UILabel *l=(UILabel *)v; UIColor *want=ADAppSettingsTextColor7548(l.textColor);
            if(want&&![want isEqual:l.textColor])l.textColor=want;
            if(l.attributedText.length){ NSAttributedString *r=ADMenuLightString7255(l.attributedText); if(r)l.attributedText=r; }
        } else if([v isKindOfClass:[UIButton class]]){
            UIButton *b=(UIButton *)v; UIColor *c=[b titleColorForState:UIControlStateNormal];
            if(!c||ADMenuDarkNeutral7255(c))[b setTitleColor:ADLightText706() forState:UIControlStateNormal];
            NSAttributedString *at=[b attributedTitleForState:UIControlStateNormal];
            if(at){ NSAttributedString *r=ADMenuLightString7255(at); if(r)[b setAttributedTitle:r forState:UIControlStateNormal]; }
        }
    } @catch(...) {}
}
static void ADAppSettingsOwnVector7548(UIView *svg){
    if(!gP.enabled||!svg||!svg.window||!ADClassNameIs7183(svg,"RNSVGSvgView")||!ADAppSettingsRoot7548(svg))return;
    @try {
        CGFloat w=svg.bounds.size.width,h=svg.bounds.size.height;
        if(w>0&&w<=40.0&&h>0&&h<=40.0)ADAlexaInvertVectorRoot7285(svg);
    } @catch(...) {}
}

