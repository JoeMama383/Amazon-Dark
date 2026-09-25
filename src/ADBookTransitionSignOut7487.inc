// v7.487 — probe-backed PUTB book-detail transition ownership + exact v6.0.185
// Sign Out dialog visual port. No timers, observers, polling, or hierarchy scans.

static const void *kADBookAMIWebRoot7487=&kADBookAMIWebRoot7487;

// Transition probe v7.486 shows the two visible stages share one exact native owner:
// UIView (AMIWebViewController), 430x829 below the top chrome. During the parallax
// stage it is a child of _UIParallaxDimmingView and is opaque white; after the dimming
// wrapper is removed the same AMI root remains opaque white as the blank canvas. Claim
// only a bright-neutral, near-full-content root whose direct responder is AMIWebViewController.
static BOOL ADBookAMIWebRoot7487(UIView *v, UIColor *candidate){
    if(!gP.enabled||!v)return NO;
    @try {
        if([objc_getAssociatedObject(v,kADBookAMIWebRoot7487) boolValue])return YES;
        const char *cn=object_getClassName(v);
        if(!cn||strcmp(cn,"UIView")!=0)return NO;
        UIResponder *r=v.nextResponder;
        if(!r||![NSStringFromClass(r.class) isEqualToString:@"AMIWebViewController"])return NO;
        UIColor *c=candidate?:v.backgroundColor;
        if(!ADBrightNeutral7130(c))return NO;
        UIWindow *w=v.window;
        if(w&&!ADClassNameIs7183(w,"AppCXWindow")&&!ADPrimaryAmazonWindow713(w,nil))return NO;
        CGFloat sw=w?CGRectGetWidth(w.bounds):CGRectGetWidth(UIScreen.mainScreen.bounds);
        CGFloat sh=w?CGRectGetHeight(w.bounds):CGRectGetHeight(UIScreen.mainScreen.bounds);
        CGFloat vw=MAX(CGRectGetWidth(v.bounds),CGRectGetWidth(v.frame));
        CGFloat vh=MAX(CGRectGetHeight(v.bounds),CGRectGetHeight(v.frame));
        if(vw>1&&sw>1&&vw<sw*0.94)return NO;
        if(vh>1&&sh>1&&vh<sh*0.65)return NO;
        objc_setAssociatedObject(v,kADBookAMIWebRoot7487,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return YES;
    } @catch(...) { return NO; }
}

// Exact v6.0.185 donor contract (probe 6140 lineage): native AWButton siblings in
// the compact Sign Out confirmation dialog. Sign Out keeps Amazon's button-image
// geometry but uses the donor dark yellow #D4A017. Cancel uses #666666 with white ink.
static const void *kADCancelGrayImage7487=&kADCancelGrayImage7487;
static const void *kADSignOutYellowImage7487=&kADSignOutYellowImage7487;

static BOOL ADAWButton7487(UIButton *b){
    if(!b)return NO;
    const char *cn=object_getClassName(b);
    return cn&&strcmp(cn,"AWButton")==0;
}
static NSString *ADButtonTitle7487(UIButton *b){
    if(!b)return @"";
    NSString *t=[b titleForState:UIControlStateNormal];
    if(!t.length)t=b.titleLabel.text;
    return t?:@"";
}
static BOOL ADSignOutDialogButton7487(UIButton *b,BOOL *isSignOut,BOOL *isCancel){
    if(isSignOut)*isSignOut=NO;
    if(isCancel)*isCancel=NO;
    if(!gP.enabled||!ADAWButton7487(b))return NO;
    @try {
        NSString *own=ADButtonTitle7487(b);
        BOOL so=[own isEqualToString:@"Sign Out"],ca=[own isEqualToString:@"Cancel"];
        if(!so&&!ca)return NO;
        UIView *box=b.superview;
        if(!box||box.bounds.size.width<240||box.bounds.size.width>340||box.bounds.size.height<170||box.bounds.size.height>300)return NO;
        BOOL account=NO,hasSO=NO,hasCancel=NO;
        NSUInteger lim=MIN((NSUInteger)16,box.subviews.count);
        for(NSUInteger i=0;i<lim;i++){
            UIView *x=box.subviews[i];
            if([x isKindOfClass:[UILabel class]]){
                NSString *t=((UILabel *)x).text?:@"";
                if([t hasPrefix:@"You are signed in as "])account=YES;
            } else if([x isKindOfClass:[UIButton class]]&&ADAWButton7487((UIButton *)x)){
                NSString *t=ADButtonTitle7487((UIButton *)x);
                if([t isEqualToString:@"Sign Out"])hasSO=YES;
                else if([t isEqualToString:@"Cancel"])hasCancel=YES;
            }
        }
        if(!(account&&hasSO&&hasCancel))return NO;
        if(isSignOut)*isSignOut=so;
        if(isCancel)*isCancel=ca;
        return YES;
    } @catch(...) { return NO; }
}
static UIImage *ADTintButtonBackground7487(UIImage *src,UIColor *ink){
    if(!src||!ink||src.size.width<=0||src.size.height<=0)return src;
    @try {
        CGSize sz=src.size; CGRect r=(CGRect){CGPointZero,sz};
        UIGraphicsBeginImageContextWithOptions(sz,NO,src.scale>0?src.scale:0.0);
        CGContextRef ctx=UIGraphicsGetCurrentContext();
        if(!ctx){UIGraphicsEndImageContext();return src;}
        [src drawInRect:r];
        CGContextSetBlendMode(ctx,kCGBlendModeSourceIn);
        CGContextSetFillColorWithColor(ctx,ink.CGColor);
        CGContextFillRect(ctx,r);
        UIImage *out=UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        if(!out)return src;
        UIEdgeInsets cap=src.capInsets;
        if(!UIEdgeInsetsEqualToEdgeInsets(cap,UIEdgeInsetsZero))out=[out resizableImageWithCapInsets:cap resizingMode:src.resizingMode];
        return out;
    } @catch(...) { return src; }
}
static void ADPaintSignOutDialogButton7487(UIButton *b){
    BOOL so=NO,ca=NO;
    if(!ADSignOutDialogButton7487(b,&so,&ca))return;
    @try {
        const UIControlState states[]={UIControlStateNormal,UIControlStateHighlighted,UIControlStateSelected,UIControlStateDisabled};
        if(ca){
            UIColor *white=[UIColor whiteColor];
            for(NSUInteger i=0;i<sizeof(states)/sizeof(states[0]);i++) [b setTitleColor:white forState:states[i]];
            b.titleLabel.textColor=white;
            UIImage *ours=objc_getAssociatedObject(b,kADCancelGrayImage7487),*cur=[b backgroundImageForState:UIControlStateNormal];
            if(!ours||cur!=ours){
                UIImage *gray=cur?ADTintButtonBackground7487(cur,[UIColor colorWithWhite:0.40 alpha:1.0]):nil;
                if(gray){objc_setAssociatedObject(b,kADCancelGrayImage7487,gray,OBJC_ASSOCIATION_RETAIN_NONATOMIC);for(NSUInteger i=0;i<sizeof(states)/sizeof(states[0]);i++)[b setBackgroundImage:gray forState:states[i]];}
            }
        } else if(so){
            UIImage *ours=objc_getAssociatedObject(b,kADSignOutYellowImage7487),*cur=[b backgroundImageForState:UIControlStateNormal];
            if(!ours||cur!=ours){
                UIImage *yellow=cur?ADTintButtonBackground7487(cur,[UIColor colorWithRed:0.831 green:0.627 blue:0.090 alpha:1.0]):nil;
                if(yellow){objc_setAssociatedObject(b,kADSignOutYellowImage7487,yellow,OBJC_ASSOCIATION_RETAIN_NONATOMIC);for(NSUInteger i=0;i<sizeof(states)/sizeof(states[0]);i++)[b setBackgroundImage:yellow forState:states[i]];}
            }
        }
    } @catch(...) {}
}
