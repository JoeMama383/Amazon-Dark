// v7.479 returns-menu FULL r1: the bright fade at the bottom is a plain UIView
// sibling of ANXTabBarView with one CAGradientLayer.  Neutralize only that exact
// bottom-bar fade family: near-full-width, 40-110pt tall, co-located with the tab bar.
// v7.481 removes the stale bright-neutral gate: r1 proves the same owner can already
// report transparent after our first pass while its gradient family is still the one to suppress.
static void ADNeutralizeBottomFadeSibling7480(UIView *v){
    if(!gP.enabled||!v||!v.window||!v.superview)return;
    @try {
        CGRect vr=v.frame;
        for(UIView *sib in v.superview.subviews){
            if(!sib||sib==v)continue;
            CGRect f=sib.frame;
            if(f.size.width<vr.size.width*0.90||f.size.height<40.0||f.size.height>110.0)continue;
            if(f.origin.y<vr.origin.y-8.0||f.origin.y>vr.origin.y+12.0)continue;
            BOOL gradient=NO;
            for(CALayer *l in (sib.layer.sublayers?:@[]))if([l isKindOfClass:[CAGradientLayer class]]){gradient=YES;break;}
            if(!gradient)continue;
            [CATransaction begin]; [CATransaction setDisableActions:YES];
            sib.opaque=NO; sib.alpha=0.0; sib.backgroundColor=UIColor.clearColor;
            sib.layer.backgroundColor=UIColor.clearColor.CGColor;
            sib.layer.borderWidth=0.0; sib.layer.shadowOpacity=0.0f;
            for(CALayer *l in (sib.layer.sublayers?:@[])){l.hidden=YES;l.opacity=0.0f;l.backgroundColor=UIColor.clearColor.CGColor;}
            [CATransaction commit];
        }
    } @catch(...) {}
}
