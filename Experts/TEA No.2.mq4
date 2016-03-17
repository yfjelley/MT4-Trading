#property copyright "Copyright 2016, Tim Hsu"
#property link      ""
#property version   "1.00"
#property description ""
#property strict

input string CUSTOM_COMMENT = "【提姆茶２號】";

//交易相關
const int    MAGIC_NUMBER         = 930214;
const string ORDER_COMMENT_PREFIX = "_TEA2_";    //交易單說明前置字串
const int    SLIPPAGE             = 0;           //交易滑點容許值
const int    ALLIGATOR_GAP        = 5;           //鱷魚線之間的間隙

//趨勢線方向
const int TREND_NONE  =  0;    //無明確趨勢
const int TREND_LONG  =  1;    //看多趨勢
const int TREND_SHORT = -1;    //看空趨勢

//資訊顯示用的 Label 物件名稱
const string LBL_COMMENT       = "lblComment";
const string LBL_TRADE_ENV     = "lblTradEvn";
const string LBL_PRICE         = "lblPrice";
const string LBL_TRENDING_TEXT = "lblTrendingText";
const string LBL_TREND_LONG    = "lblTrendingBuy";
const string LBL_TREND_SHORT   = "lblTrendingSell";
const string LBL_SPREAD        = "lblSpread";
const string ARROW_UP          = "↑";
const string ARROW_DOWN        = "↓";
const string ARROW_NONE        = "　";

#import "TimUtil.ex4" 
string CompileErrorMessage(int errorCode);
bool HasNewBar();
void CloseOrders(int& orders[]);
bool CollectOrderTickets(string symbol, int orderType, int& tickets[], int magicNumber = 930214);
string GetTimeFrameString(int period);
#import

static long gs_chartId = 0;
static int gs_currentTrend = TREND_NONE;

int OnInit() {
    Print("Initializing ...");
    
    gs_chartId = ChartID();
    gs_currentTrend = GetTrendByAlligator();
    
    PutInfoLables();
    UpdateInfoLabels();
    UpdateTrendLabels();
    
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    Print("Deinitializing ...");
}

void OnTick() {
    UpdateInfoLabels();    

    if(!HasNewBar()) return;
    
    UpdateTrendLabels();
    
}

void PutInfoLables() {
    ObjectsDeleteAll(gs_chartId);

    //comment label
    ObjectCreate(gs_chartId, LBL_COMMENT, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_COMMENT, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(gs_chartId, LBL_COMMENT, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, LBL_COMMENT, OBJPROP_XDISTANCE, 5);
    ObjectSetInteger(gs_chartId, LBL_COMMENT, OBJPROP_YDISTANCE, 24);
    ObjectSetInteger(gs_chartId, LBL_COMMENT, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(gs_chartId, LBL_COMMENT, OBJPROP_FONTSIZE, 12);
    ObjectSetString(gs_chartId, LBL_COMMENT, OBJPROP_FONT, "微軟正黑體");
    SetLabelText(gs_chartId, LBL_COMMENT, CUSTOM_COMMENT);

    //交易品種及時區
    ObjectCreate(gs_chartId, LBL_TRADE_ENV, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_TRADE_ENV, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(gs_chartId, LBL_TRADE_ENV, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, LBL_TRADE_ENV, OBJPROP_XDISTANCE, 5);
    ObjectSetInteger(gs_chartId, LBL_TRADE_ENV, OBJPROP_YDISTANCE, 45);
    ObjectSetInteger(gs_chartId, LBL_TRADE_ENV, OBJPROP_COLOR, clrOrange);
    ObjectSetInteger(gs_chartId, LBL_TRADE_ENV, OBJPROP_FONTSIZE, 18);
    ObjectSetString(gs_chartId, LBL_TRADE_ENV, OBJPROP_FONT, "Verdana");
    SetLabelText(gs_chartId, LBL_TRADE_ENV, Symbol() + "-" + GetTimeFrameString(Period()));

    //價格
    ObjectCreate(gs_chartId, LBL_PRICE, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_PRICE, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(gs_chartId, LBL_PRICE, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, LBL_PRICE, OBJPROP_XDISTANCE, 5);
    ObjectSetInteger(gs_chartId, LBL_PRICE, OBJPROP_YDISTANCE, 72);
    ObjectSetInteger(gs_chartId, LBL_PRICE, OBJPROP_COLOR, clrDeepSkyBlue);
    ObjectSetInteger(gs_chartId, LBL_PRICE, OBJPROP_FONTSIZE, 24);
    ObjectSetString(gs_chartId, LBL_PRICE, OBJPROP_FONT, "Verdana");
    SetLabelText(gs_chartId, LBL_PRICE, StringFormat("%.5f", NormalizeDouble((Ask + Bid) / 2, 5)));

    //趨勢標題
    ObjectCreate(gs_chartId, LBL_TRENDING_TEXT, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_TRENDING_TEXT, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(gs_chartId, LBL_TRENDING_TEXT, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, LBL_TRENDING_TEXT, OBJPROP_XDISTANCE, 80);
    ObjectSetInteger(gs_chartId, LBL_TRENDING_TEXT, OBJPROP_YDISTANCE, 98);
    ObjectSetInteger(gs_chartId, LBL_TRENDING_TEXT, OBJPROP_COLOR, clrNavajoWhite);
    ObjectSetInteger(gs_chartId, LBL_TRENDING_TEXT, OBJPROP_FONTSIZE, 12);
    ObjectSetString(gs_chartId, LBL_TRENDING_TEXT, OBJPROP_FONT, "微軟正黑體");
    SetLabelText(gs_chartId, LBL_TRENDING_TEXT, "趨勢：");

    //向上箭頭
    ObjectCreate(gs_chartId, LBL_TREND_LONG, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_TREND_LONG, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(gs_chartId, LBL_TREND_LONG, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, LBL_TREND_LONG, OBJPROP_XDISTANCE, 70);
    ObjectSetInteger(gs_chartId, LBL_TREND_LONG, OBJPROP_YDISTANCE, 98);
    ObjectSetInteger(gs_chartId, LBL_TREND_LONG, OBJPROP_COLOR, clrDeepSkyBlue);
    ObjectSetInteger(gs_chartId, LBL_TREND_LONG, OBJPROP_FONTSIZE, 12);
    ObjectSetString(gs_chartId, LBL_TREND_LONG, OBJPROP_FONT, "Verdana");
    SetLabelText(gs_chartId, LBL_TREND_LONG, ARROW_UP);

    //向下箭頭
    ObjectCreate(gs_chartId, LBL_TREND_SHORT, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_TREND_SHORT, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(gs_chartId, LBL_TREND_SHORT, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, LBL_TREND_SHORT, OBJPROP_XDISTANCE, 60);
    ObjectSetInteger(gs_chartId, LBL_TREND_SHORT, OBJPROP_YDISTANCE, 98);
    ObjectSetInteger(gs_chartId, LBL_TREND_SHORT, OBJPROP_COLOR, clrDeepPink);
    ObjectSetInteger(gs_chartId, LBL_TREND_SHORT, OBJPROP_FONTSIZE, 12);
    ObjectSetString(gs_chartId, LBL_TREND_SHORT, OBJPROP_FONT, "Verdana");
    SetLabelText(gs_chartId, LBL_TREND_SHORT, ARROW_DOWN);

    //點差
    ObjectCreate(gs_chartId, LBL_SPREAD, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_SPREAD, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(gs_chartId, LBL_SPREAD, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, LBL_SPREAD, OBJPROP_XDISTANCE, 5);
    ObjectSetInteger(gs_chartId, LBL_SPREAD, OBJPROP_YDISTANCE, 98);
    ObjectSetInteger(gs_chartId, LBL_SPREAD, OBJPROP_COLOR, clrNavajoWhite);
    ObjectSetInteger(gs_chartId, LBL_SPREAD, OBJPROP_FONTSIZE, 12);
    ObjectSetString(gs_chartId, LBL_SPREAD, OBJPROP_FONT, "Verdana");
    SetLabelText(gs_chartId, LBL_SPREAD, StringFormat("(%.0f)", (Ask - Bid) / Point));
}

void SetLabelText(long chartId, string labelName, string labelText) {
    ObjectSetString(chartId, labelName, OBJPROP_TEXT, labelText);
}

void UpdateInfoLabels() {
    double medianPrice = NormalizeDouble((Ask + Bid) / 2, 5);
    SetLabelText(gs_chartId, LBL_PRICE, StringFormat("%.5f", medianPrice));
    if(medianPrice > Open[0])
        ObjectSetInteger(gs_chartId, LBL_PRICE, OBJPROP_COLOR, clrDeepSkyBlue);
    else if(medianPrice < Open[0])
        ObjectSetInteger(gs_chartId, LBL_PRICE, OBJPROP_COLOR, clrDeepPink);
    else
        ObjectSetInteger(gs_chartId, LBL_PRICE, OBJPROP_COLOR, clrDarkGray);

    SetLabelText(gs_chartId, LBL_SPREAD, StringFormat("(%.0f)", (Ask - Bid) / Point));
}

void UpdateTrendLabels() {
    gs_currentTrend = GetTrendByAlligator();

    if(gs_currentTrend == TREND_LONG) {
        SetLabelText(gs_chartId, LBL_TREND_LONG, ARROW_UP);
        SetLabelText(gs_chartId, LBL_TREND_SHORT, ARROW_NONE);
        Print("Current trend is LONG.");

    } else if(gs_currentTrend == TREND_SHORT) {
        SetLabelText(gs_chartId, LBL_TREND_LONG, ARROW_NONE);
        SetLabelText(gs_chartId, LBL_TREND_SHORT, ARROW_DOWN);
        Print("Current trend is SHORT.");

    } else {
        SetLabelText(gs_chartId, LBL_TREND_LONG, ARROW_UP);
        SetLabelText(gs_chartId, LBL_TREND_SHORT, ARROW_DOWN);
        Print("Current trend is unknown.");
    }
}

int GetTrendByAlligator() {
    int trendH1 = AlligatorTrend(PERIOD_H1, 0);
    int trendD1 = AlligatorTrend(PERIOD_D1, -3);
    
    if(trendH1 == trendD1) return trendH1;
    else return TREND_NONE;
}

//取得鱷魚線的值
double GetAlligator(int timeFrame, int lineMode, int shift) {
    return iAlligator(Symbol(), timeFrame, 13, 8, 8, 5, 5, 3, MODE_SMMA, PRICE_MEDIAN, lineMode, shift);
}

//用鱷魚線判斷趨勢
int AlligatorTrend(int timeFrame, int shift = 0) {
    double lips = GetAlligator(timeFrame, MODE_GATORLIPS, shift);
    double teeth = GetAlligator(timeFrame, MODE_GATORTEETH, shift);
    double jaw = GetAlligator(timeFrame, MODE_GATORJAW, shift);
    
    double diff_lips_teeth = MathAbs(lips - teeth) * MathPow(10, Digits);
    double diff_jaw_teeth = MathAbs(jaw - teeth) * MathPow(10, Digits);
    
    PrintFormat("timeframe: %s; shift: %d; lips = %.5f; teeth = %.5f; jaw = %.5f; diff_lips_teeth: %.0f; diff_jaw_teeth: %.0f", GetTimeFrameString(timeFrame), shift, lips, teeth, jaw, diff_lips_teeth, diff_jaw_teeth);
    
    if(lips > teeth && teeth > jaw && diff_lips_teeth > ALLIGATOR_GAP && diff_jaw_teeth > ALLIGATOR_GAP) {
        PrintFormat("Timeframe %s, shift %d is a LONG trend.", GetTimeFrameString(timeFrame), shift);
        return TREND_LONG;
    }
    
    if(jaw > teeth && teeth > lips && diff_lips_teeth > ALLIGATOR_GAP && diff_jaw_teeth > ALLIGATOR_GAP) {
        PrintFormat("Timeframe %s, shift %d is a SHORT trend.", GetTimeFrameString(timeFrame), shift);
        return TREND_SHORT;
    }
    
    PrintFormat("Timeframe %s, shift %d has NO trend.", GetTimeFrameString(timeFrame), shift);
    return TREND_NONE;
}
