// Probe-backed shared keyboard dock geometry: align only the right dictation glyph
// to the left dock-control optical center. Do not move buttons, resize icons, or scan beyond direct children.
static UIImageView *ADDockItemImage7513(UIView *button){
    if(!button)return nil;
    @try {
        for(UIView *v in (button.subviews.copy?:@[]))
            if([v isKindOfClass:[UIImageView class]]&&!v.hidden&&v.alpha>0.01)
                return (UIImageView *)v;
    } @catch(...) {}
    return nil;
}
static void ADAlignKeyboardMic7513(UIKeyboardDockView *dock){
    if(!gP.enabled||!dock||!dock.window)return;
    @try {
        UIView *left=nil,*right=nil;
        for(UIView *v in (dock.subviews.copy?:@[])){
            if(!ADClassNameIs7183(v,"UIKeyboardDockItemButton"))continue;
            CGFloat x=CGRectGetMidX(v.frame);
            if(!left||x<CGRectGetMidX(left.frame))left=v;
            if(!right||x>CGRectGetMidX(right.frame))right=v;
        }
        if(!left||!right||left==right)return;
        CGFloat dockMid=CGRectGetMidX(dock.bounds);
        if(CGRectGetMidX(left.frame)>=dockMid||CGRectGetMidX(right.frame)<=dockMid)return;
        [left layoutIfNeeded]; [right layoutIfNeeded];
        UIImageView *leftIcon=ADDockItemImage7513(left),*rightIcon=ADDockItemImage7513(right);
        if(!leftIcon||!rightIcon||rightIcon.bounds.size.width<=0.0)return;
        // The probe identifies the dictation glyph as the portrait-shaped right icon
        // (26.7x32.7) versus the square emoji/globe icon (31.7x31.7).
        CGFloat ratio=rightIcon.bounds.size.height/rightIcon.bounds.size.width;
        if(ratio<1.08)return;
        CGPoint lc=[leftIcon.superview convertPoint:leftIcon.center toView:dock];
        CGPoint rc=[rightIcon.superview convertPoint:rightIcon.center toView:dock];
        CGFloat dy=lc.y-rc.y,ady=dy<0.0?-dy:dy;
        if(ady<1.0||ady>12.0)return;
        CGPoint target=[dock convertPoint:CGPointMake(rc.x,lc.y) toView:rightIcon.superview];
        CGPoint c=rightIcon.center;c.y=target.y;rightIcon.center=c;
    } @catch(...) {}
}
