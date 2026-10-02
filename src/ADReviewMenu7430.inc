static UIView *ADReviewMenuRoot7430(UIView *v){
    for(int i=0;v&&i<32;i++,v=v.superview){
        if([v.accessibilityIdentifier isEqualToString:@"long-press-modal"])return v;
    }
    return nil;
}
static int ADReviewMenuButton7430(UIView *v){
    NSString *aid=v.accessibilityIdentifier;
    if([aid isEqualToString:@"actions-buttons-view-save-button"]||[aid isEqualToString:@"actions-buttons-view-share-button"]||[aid isEqualToString:@"actions-buttons-view-more-like-this-button"])return 1;
    UIView *row=v.superview;
    if(![row.superview.accessibilityIdentifier isEqualToString:@"long-press-actions-modal-content"])return 0;
    if([aid isEqualToString:@"button"])return 2;
    if(ADClassNameIs7183(v,"RCTView")&&ADAlexaResultsHasChild7427(row,NULL,@"button"))return 3;
    return 0;
}
static UIColor *ADReviewMenuFill7430(UIView *v,UIColor *incoming){
    int role=ADReviewMenuButton7430(v);
    if(role==1||role==3)return ADMenuButtonFill7255();
    if(role==2||[v.accessibilityIdentifier isEqualToString:@"long-press-modal"])return ADOLED();
    CGFloat r=0,g=0,b=0,a=0;
    if(!incoming||![incoming getRed:&r green:&g blue:&b alpha:&a]||a<0.005)return incoming;
    if(v.bounds.size.width>0&&v.bounds.size.width<=1.5&&v.bounds.size.height>=10)return ADBorderGray706();
    BOOL neutral=MAX(r,MAX(g,b))-MIN(r,MIN(g,b))<0.16;
    BOOL reviewBlue=r>0.8&&g>0.9&&b>0.98;
    return (neutral||reviewBlue)?ADOLED():incoming;
}
static void ADReviewMenuOwn7430(UIView *v){
    if(!gP.enabled||!ADReviewMenuRoot7430(v))return;
    UIColor *fill=ADReviewMenuFill7430(v,v.backgroundColor);
    if(fill)ADSetViewBackground7226(v,fill,YES);
    int role=ADReviewMenuButton7430(v);
    if(role)ADMenuSetSingleRCTBorder7258(v,1,ADMenuButtonBorder7255());
    v.layer.shadowOpacity=0;
}
static void ADAlexaInvertVectorRoot7285(UIView *svg);
static BOOL ADReviewMenuVector7430(UIView *svg){
    if(!gP.enabled||!ADReviewMenuRoot7430(svg))return NO;
    if(ADReviewMenuButton7430(svg.superview.superview)==3){
        svg.hidden=YES;
        ADReviewMenuOwn7430(svg.superview.superview);
        return YES;
    }
    if(ADAlexaResultsHasChild7427(svg.superview,"RCTTextView",nil)&&ADAlexaResultsHasChild7427(svg.superview.superview,NULL,@"aspect-list"))ADAlexaInvertVectorRoot7285(svg);
    return YES;
}
static BOOL ADReviewMenuBlur7430(UIVisualEffectView *v){
    if(!gP.enabled||!ADReviewMenuRoot7430(v))return NO;
    v.hidden=YES;
    ADSetViewBackground7226(v.superview,ADOLED(),YES);
    return YES;
}

#include "ADAppSettings7550.inc"

