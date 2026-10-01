// Opt-in transition evidence only. No text, keyboard pixels, or input values.
static void ADKeyboardTrace7538(id object,NSString *phase,NSInteger incoming,NSInteger outgoing){
    if(!ADSkelTransition7339||!ADSkelActive7339())return;
    @try {
        static NSString *session=nil; static NSUInteger count=0;
        if(![session isEqual:ADSkelSession7339]){session=[ADSkelSession7339 copy];count=0;}
        if(count>=512)return; count++;
        NSMutableDictionary *r=[ADSkelEvent7339(@"KEYBOARD_TRAITS") mutableCopy];
        r[@"phase"]=phase;r[@"class"]=object?NSStringFromClass([object class]):@"nil";
        r[@"object"]=[NSString stringWithFormat:@"%p",object];r[@"incoming"]=@(incoming);r[@"outgoing"]=@(outgoing);
        r[@"enabled"]=@(gP.enabled);
        for(NSString *name in @[@"keyboardAppearance",@"keyboardType",@"autocorrectionType",@"autocapitalizationType",@"spellCheckingType",@"returnKeyType"]){
            SEL s=NSSelectorFromString(name);
            if([object respondsToSelector:s])r[name]=@(((NSInteger(*)(id,SEL))objc_msgSend)(object,s));
        }
        if(count==512)r[@"limitReached"]=@YES;
        ADSkelWrite7339(r);
    } @catch(...) {}
}
