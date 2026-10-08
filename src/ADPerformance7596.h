// No clocks, allocations, hierarchy walks or timers on the inactive path.
static BOOL gADPerformanceActive7596=NO;
static unsigned gADPerformanceGeneration7596=0;
enum ADPerformanceLane7596 { ADPerfEvent,ADPerfReactLayout,ADPerfImageLayout,ADPerfImageCommit,ADPerfTextCommit,ADPerfViewPaint,ADPerfLabel,ADPerfLaneCount };
static void ADPerformanceRecord7596(unsigned lane,double milliseconds);
static void ADPerformanceEvent7596(UIEvent *event);
static void ADPerformanceEnroll7596(WKWebView *web);
static void ADPerformanceInstall7596(void);
static void ADPerformanceNavigation7596(UIViewController *controller,BOOL begin);
class ADPerformanceScope7596 {
    unsigned lane,generation; double start;
public:
    explicit ADPerformanceScope7596(unsigned value):lane(value),generation(gADPerformanceGeneration7596),start(gADPerformanceActive7596?CACurrentMediaTime():0){}
    ~ADPerformanceScope7596(){if(start&&gADPerformanceActive7596&&generation==gADPerformanceGeneration7596)ADPerformanceRecord7596(lane,(CACurrentMediaTime()-start)*1000);}
};
