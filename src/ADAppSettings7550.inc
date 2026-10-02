// Restored exact sheet-view ownership. Never cache a pre-hydration miss.
// Compatibility entry points retain the current text commit hooks.
static UIView *ADAppSettingsRoot7548(UIView *v){
    if(!gP.enabled||!v||!v.window)return nil;
    if(!ADAppSettingsScope7547(v))ADPersonSavingsSheetRoot7259(v);
    if(!ADAppSettingsScope7547(v))return nil;
    for(NSUInteger depth=0;v&&depth<24;depth++,v=v.superview)
        if(objc_getAssociatedObject(v,kADAppSettingsSheet7547))return v;
    return nil;
}
static UIColor *ADAppSettingsTextColor7548(UIColor *old){
    if(!old||ADMenuDarkNeutral7255(old))return ADLightText706();
    return old;
}
static void ADAppSettingsOwn7548(UIView *v){
    ADAppSettingsOwn7547(v);
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
    // The captured close X is RCTTextView/ZapfDingbats, handled as text.
    // Do not invert arbitrary SVGs in this sheet.
    (void)svg;
}
