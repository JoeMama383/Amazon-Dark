// Opt-in transition evidence only. No text, keyboard pixels, or input values.
#include "ADKeyboardTraceBudget7539.h"
static void ADKeyboardTrace7538(id object,NSString *phase,NSInteger incoming,NSInteger outgoing){
    if(!ADSkelTransition7339||!ADSkelActive7339())return;
    static __thread BOOL reading=NO;
    if(reading)return;
    reading=YES;
    @try {
        static NSString *session=nil; static NSMutableDictionary *seen=nil;
        static ADKeyboardBudget7539 budget={0,0,0}; static NSUInteger duplicates=0;
        if(![session isEqual:ADSkelSession7339]){
            session=[ADSkelSession7339 copy];seen=[NSMutableDictionary dictionary];
            budget.start=0;budget.count=0;budget.dropped=0;duplicates=0;
        }
        NSMutableDictionary *state=[NSMutableDictionary dictionary];
        state[@"incoming"]=@(incoming);state[@"outgoing"]=@(outgoing);state[@"enabled"]=@(gP.enabled);
        for(NSString *name in @[@"keyboardAppearance",@"keyboardType",@"autocorrectionType",@"autocapitalizationType",@"spellCheckingType",@"returnKeyType",@"smartQuotesType",@"smartDashesType",@"smartInsertDeleteType"]){
            SEL s=NSSelectorFromString(name);
            if([object respondsToSelector:s])state[name]=@(((NSInteger(*)(id,SEL))objc_msgSend)(object,s));
        }
        if([object respondsToSelector:@selector(isSecureTextEntry)])state[@"secure"]=@(((BOOL(*)(id,SEL))objc_msgSend)(object,@selector(isSecureTextEntry)));
        NSString *key=[NSString stringWithFormat:@"%p:%@",object,phase];
        if([seen[key] isEqual:state]){duplicates++;return;}
        if(!ADKeyboardBudgetTake7539(&budget,[[NSProcessInfo processInfo] systemUptime]))return;
        if(seen.count>=256)[seen removeAllObjects];
        seen[key]=[state copy];
        NSMutableDictionary *r=[ADSkelEvent7339(@"KEYBOARD_TRAITS") mutableCopy];
        [r addEntriesFromDictionary:state];
        r[@"phase"]=phase;r[@"class"]=object?NSStringFromClass([object class]):@"nil";
        r[@"object"]=[NSString stringWithFormat:@"%p",object];
        r[@"duplicatesSuppressed"]=@(duplicates);r[@"budgetDropped"]=@(budget.dropped);
        r[@"limitReached"]=@(budget.count==512);duplicates=0;budget.dropped=0;
        ADSkelWrite7339(r);
    } @catch(...) {} @finally { reading=NO; }
}
