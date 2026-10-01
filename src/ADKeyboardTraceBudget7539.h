#ifndef AD_KEYBOARD_TRACE_BUDGET_7539
#define AD_KEYBOARD_TRACE_BUDGET_7539
/* Diagnostic-only rolling budget: a burst cannot disable the rest of a session. */
typedef struct { double start; unsigned count, dropped; } ADKeyboardBudget7539;
static int ADKeyboardBudgetTake7539(ADKeyboardBudget7539 *b,double now){
    if(now<b->start||now-b->start>=5.0){b->start=now;b->count=0;}
    if(b->count>=512){b->dropped++;return 0;}
    b->count++;return 1;
}
#endif
