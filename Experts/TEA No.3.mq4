#property copyright "Copyright 2016, Tim Hsu"
#property link      ""
#property version   "1.00"
#property description "提姆茶３號"
#property description "撒豆子佈局策略, 在預想的震幅區間中"
#property description "每隔固定點距, 手數依等比或等差減碼, 預掛 stop 單等待成交"
#include <TEA.mqh>

//使用者輸入參數
input string CUSTOM_COMMENT    = "【提姆茶３號】";    //畫面註解
input string BREAK_LINE_1      = "＝＝＝＝＝";        //＝ [進場控制] ＝＝＝＝＝＝
input string START_TIME        = "";                  //開始時間 (HH:MM)
input string END_TIME          = "";                  //結束時間 (HH:MM)
input bool   CONTINUE_PUT_BEAN = true;                //無 STOP 單時再重新佈局
input bool   AUTO_CANCEL_BEAN  = false;               //是否自動依點距取消未成交的 STOP 單
input int    RESET_RANGE       = 320;                 //觸發自動取消 STOP 單的點距
input string BREAK_LINE_2      = "＝＝＝＝＝";        //＝ [BUY 佈局模式] ＝＝＝＝＝＝
input bool   BUY_PUT_BEANS     = true;                //是否佈局 BUY 單
input int    BUY_PUT_TYPE      = 2;                   //BUY 減碼模式 (1: 等差 2: 等比)
input double BUY_THROTTLE      = 0.5;                 //BUY 減碼差距/比例
input int    BUY_BREAK_POINT   = 750;                 //BUY 減碼起始點距 (0: 立刻減碼)
input int    BUY_MAX_BEANS     = 10;                  //BUY 佈局張數
input double BUY_INITIAL_LOTS  = 1;                   //BUY 起始手數
input double BUY_MINIMUM_LOTS  = 0.01;                //BUY 最小手數
input int    BUY_1ST_DISTANCE  = 100;                 //BUY 首張單距市價點距
input int    BUY_DISTANCE      = 125;                 //BUY 佈局間隔點距
input int    BUY_TAKE_PROFIT   = 100;                 //BUY 停利點 (0: 不設停利)
input int    BUY_STOP_LOSS     = 50;                  //BUY 停損點 (0: 不設停損)
input string BREAK_LINE_3      = "＝＝＝＝＝";        //＝ [SELL 佈局模式] ＝＝＝＝＝＝
input bool   SELL_PUT_BEANS    = true;                //是否佈局 SELL 單
input int    SELL_PUT_TYPE     = 2;                   //SELL 減碼模式 (1:等差 2:等比)
input double SELL_THROTTLE     = 0.5;                 //SELL 減碼差距/比例
input int    SELL_BREAK_POINT  = 750;                 //SELL 減碼起始點距 (0: 立刻減碼)
input int    SELL_MAX_BEANS    = 10;                  //SELL 佈局張數
input double SELL_INITIAL_LOTS = 1;                   //SELL 起始手數
input double SELL_MINIMUM_LOTS = 0.01;                //SELL 最小手數
input int    SELL_1ST_DISTANCE = 100;                 //SELL 首張單距市價點距
input int    SELL_DISTANCE     = 125;                 //SELL 佈局間隔點距
input int    SELL_TAKE_PROFIT  = 100;                 //SELL 停利點 (0: 不設停利)
input int    SELL_STOP_LOSS    = 50;                  //SELL 停損點 (0: 不設停損)


//EA 相關
const int    MAGIC_NUMBER         = 930214;
const string ORDER_COMMENT_PREFIX = "TEA3_";    //交易單說明前置字串
const int    PUT_TYPE_ARITHMETIC  = 1;
const int    PUT_TYPE_GEOMETRIC   = 2;


//資訊顯示用的 Label 物件名稱
const string LBL_COMMENT           = "lblComment";
const string LBL_TRADE_ENV         = "lblTradEvn";
const string LBL_PRICE             = "lblPrice";
const string LBL_SERVER_TIME       = "lblServerTime";
const string LBL_LOCAL_TIME        = "lblLocalTime";
const string LBL_TRADE_TIME        = "lblTradeTime";
const string TRADE_TIME_MSG        = "已超出撒豆時間！";
const string BTN_CANCEL_BUY_BEANS  = "btnCancelBuyBeans";
const string BTN_CANCEL_SELL_BEANS = "btnCancelSellBeans";


//全域變數
static bool        gs_isTradeTime     = false;
static string      gs_symbol          = Symbol();
static long        gs_chartId         = 0;
static int         gs_BuyBeanRounds   = 0;
static int         gs_SellBeanRounds  = 0;
static bool        gs_isPuttingBeans  = false;
static OrderStruct gs_buyPosition[];
static OrderStruct gs_sellPosition[];

int OnInit() {
    Print("Initializing ...");
    
    gs_symbol = Symbol();
    gs_chartId = ChartID();
    gs_BuyBeanRounds = 0;
    gs_SellBeanRounds = 0;
    
    PutInfoLables();
    UpdateInfoLabels();

    return INIT_SUCCEEDED;
}


void OnDeinit(const int reason) {
    Print("Deinitializing ...");
}


void OnTick() {
    UpdateInfoLabels();
        
    if(!HasNewBar())  return;

    if(AUTO_CANCEL_BEAN) {
        Print("Checking if need to cancel beans.");
        ResetBeans(OP_BUYSTOP);
        ResetBeans(OP_SELLSTOP);
    }
    
    gs_isTradeTime = IsTradeTime(START_TIME, END_TIME);
    SetTradeTimeLabel(gs_isTradeTime);
    if(!gs_isTradeTime) {
        Print("Not in trading time.");
        return;
    }

    CollectOrders(gs_symbol, OP_BUYSTOP, MAGIC_NUMBER, gs_buyPosition);
    CollectOrders(gs_symbol, OP_SELLSTOP, MAGIC_NUMBER, gs_sellPosition);
    Print("Current position: BUYSTOP = ", ArraySize(gs_buyPosition), ", SELLSTOP = ", ArraySize(gs_sellPosition));

    gs_isPuttingBeans = true;
    if(BUY_PUT_BEANS) {
        PutBeans(gs_buyPosition, OP_BUYSTOP);
    }
    if(SELL_PUT_BEANS) {
        PutBeans(gs_sellPosition, OP_SELLSTOP);
    }
    gs_isPuttingBeans = false;

    Print("Current position: BUYSTOP = ", ArraySize(gs_buyPosition), ", SELLSTOP = ", ArraySize(gs_sellPosition));
}


void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    if(gs_isPuttingBeans) {
        Print("Putting beans is in progress, could not delete.");
        return;
    }
    
    int tickets[];
    
    if(sparam == BTN_CANCEL_BUY_BEANS) {
        CollectOrders(gs_symbol, OP_BUYSTOP, MAGIC_NUMBER, tickets);
        DeletePendingOrders(tickets);
    }

    if(sparam == BTN_CANCEL_SELL_BEANS) {
        CollectOrders(gs_symbol, OP_SELLSTOP, MAGIC_NUMBER, tickets);
        DeletePendingOrders(tickets);
    }

    ObjectSetInteger(gs_chartId, sparam, OBJPROP_STATE, false);
}


//佈局 stop 單
void PutBeans(OrderStruct& orders[], int orderType) {    
    int    putType;
    double tpPoint;
    double slPoint;
    double initDistance;
    double distance;
    double orderPrice;
    double orderLots;
    double minLots;
    int    maxBeans;
    double tpPrice;
    double slPrice;
    double beanThrottle;
    string comment;
    int    ticket;
    string orderTypeString;
    int    putBeanRounds;
    int    breakPoint;
    
    if(orderType == OP_BUYSTOP) {
        orderTypeString = "BUY";
        putType = BUY_PUT_TYPE;
        tpPoint = IntegerToPrice(BUY_TAKE_PROFIT);
        slPoint = IntegerToPrice(BUY_STOP_LOSS);
        initDistance = IntegerToPrice(BUY_1ST_DISTANCE);
        distance = IntegerToPrice(BUY_DISTANCE);
        orderPrice = Ask;
        orderLots = BUY_INITIAL_LOTS;
        maxBeans = BUY_MAX_BEANS;
        beanThrottle = BUY_THROTTLE;
        minLots = BUY_MINIMUM_LOTS;
        putBeanRounds = gs_BuyBeanRounds;
        breakPoint = BUY_BREAK_POINT;
        
    } else {
        orderTypeString = "SELL";
        putType = SELL_PUT_TYPE;
        tpPoint = IntegerToPrice(-SELL_TAKE_PROFIT);
        slPoint = IntegerToPrice(-SELL_STOP_LOSS);
        initDistance = IntegerToPrice(-SELL_1ST_DISTANCE);
        distance = IntegerToPrice(-SELL_DISTANCE);
        orderPrice = Bid;
        orderLots = SELL_INITIAL_LOTS;
        maxBeans = SELL_MAX_BEANS;
        beanThrottle = BUY_THROTTLE;
        minLots = SELL_MINIMUM_LOTS;
        putBeanRounds = gs_SellBeanRounds;
        breakPoint = SELL_BREAK_POINT;
    }

    if(ArraySize(orders) == 0) {
        if(putBeanRounds == 0) {
            Print("Ready to put round ", putBeanRounds + 1, " ", orderTypeString, " beans.");
        } else if(putBeanRounds > 0 && CONTINUE_PUT_BEAN) {
            Print("Ready to put round ", putBeanRounds + 1, " ", orderTypeString, " beans.");
        } else {
            Print("Not allowed to put 2nd round beans.");
            return;
        }
        
    } else {
        Print("Found ", orderTypeString, " beans available, stop putting new beans.");
        return;
    }
    
    double totalLots = 0;
    double firstPrice = 0;
    double lastPrice = 0;

    for(int i = 1; i <= maxBeans; i++) {
        orderPrice += (i == 1)? initDistance : distance;

        if(i > 1 && PriceToInteger(MathAbs(distance)) * i >= breakPoint) {
            if(putType == PUT_TYPE_ARITHMETIC) {
                orderLots -= beanThrottle;
            }    
            else {
                orderLots *= beanThrottle;
            }
            
            if(orderLots < minLots) {
                Print("Order lots is less than minimum lots, stop putting beans.");
                break;
            }
        }

        orderLots = NormalizeDouble(orderLots, 2);
        tpPrice = NormalizeDouble((tpPoint == 0)? 0 : orderPrice + tpPoint, 5);
        slPrice = NormalizeDouble((slPoint == 0)? 0 : orderPrice - slPoint, 5);
        comment = BuildOrderComment(orderType, i);
        
        PrintFormat("Sending %s bean: Price = %.5f, Lots = %.2f, TP = %.5f, SL = %.5f", orderTypeString, orderPrice, orderLots, tpPrice, slPrice);
        ticket = SendOrder(gs_symbol, orderType, orderPrice, orderLots, comment, MAGIC_NUMBER, tpPrice, slPrice);

        if(ticket > 0) {
            AddTicketToPosition(ticket, orders);
            totalLots += orderLots;
            if(i == 1)  {
                firstPrice = orderPrice;
                lastPrice = orderPrice;
            }    
            else {
                lastPrice = orderPrice;
            }
        }
    }
    PrintFormat("Total %s lots=%.2f, distance=%.0f", orderTypeString, totalLots, PriceToInteger(MathAbs(lastPrice - firstPrice)));
    
    if(orderType == OP_BUYSTOP)
        gs_BuyBeanRounds += 1;
    else
        gs_SellBeanRounds += 1;    
}


//依最近的 stop 單離市價距離決定是否取消 stop 單
void ResetBeans(int orderType) {
    int currentRange = 0;
    double currentPrice = 0;
    string orderTypeString = "";
    OrderStruct beans[];
    
    CollectOrders(gs_symbol, orderType, MAGIC_NUMBER, beans);
    if(ArraySize(beans) == 0)  return;
    
    if(orderType == OP_BUYSTOP) {
        orderTypeString = "BUY STOP";
        currentPrice = Ask;
        currentRange = PriceToInteger(currentPrice - beans[0].openPrice);
    } else {
        orderTypeString = "SELL STOP";
        currentPrice = Bid;
        currentRange = PriceToInteger(beans[0].openPrice - currentPrice);
    }

    if(currentRange > RESET_RANGE) {
        PrintFormat("Cancel current beans.  last %s price: %.5f, current price: %.5f, range: %.0f", orderTypeString, beans[0].openPrice, currentPrice, currentRange);
        DeletePendingOrders(beans);
    }
}


//交易單註解
string BuildOrderComment(int orderType, int orderSeq) {
    if(orderType == OP_BUYSTOP)
        return ORDER_COMMENT_PREFIX + gs_symbol + "_B-" + (string)orderSeq;

    if(orderType == OP_SELLSTOP)
        return ORDER_COMMENT_PREFIX + gs_symbol + "_S-" + (string)orderSeq;
    
    return NULL;    
}


//在圖表上安置各項資訊標籤物件
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
    string custComment = CUSTOM_COMMENT;
    ENUM_ACCOUNT_TRADE_MODE accountType = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
    switch(accountType) {
        case ACCOUNT_TRADE_MODE_DEMO: 
            custComment += "模擬倉"; 
            break; 
        case ACCOUNT_TRADE_MODE_REAL: 
            custComment += "真倉"; 
            break; 
        default: 
            break; 
    } 
    SetLabelText(gs_chartId, LBL_COMMENT, custComment);

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

    //主機時間
    ObjectCreate(gs_chartId, LBL_SERVER_TIME, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_SERVER_TIME, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
    ObjectSetInteger(gs_chartId, LBL_SERVER_TIME, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, LBL_SERVER_TIME, OBJPROP_XDISTANCE, 5);
    ObjectSetInteger(gs_chartId, LBL_SERVER_TIME, OBJPROP_YDISTANCE, 30);
    ObjectSetInteger(gs_chartId, LBL_SERVER_TIME, OBJPROP_COLOR, clrLimeGreen);
    ObjectSetInteger(gs_chartId, LBL_SERVER_TIME, OBJPROP_FONTSIZE, 10);
    ObjectSetString(gs_chartId, LBL_SERVER_TIME, OBJPROP_FONT, "Verdana");
    SetLabelText(gs_chartId, LBL_SERVER_TIME, "主機：" + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));

    //本機時間
    ObjectCreate(gs_chartId, LBL_LOCAL_TIME, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_LOCAL_TIME, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
    ObjectSetInteger(gs_chartId, LBL_LOCAL_TIME, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, LBL_LOCAL_TIME, OBJPROP_XDISTANCE, 5);
    ObjectSetInteger(gs_chartId, LBL_LOCAL_TIME, OBJPROP_YDISTANCE, 15);
    ObjectSetInteger(gs_chartId, LBL_LOCAL_TIME, OBJPROP_COLOR, clrLimeGreen);
    ObjectSetInteger(gs_chartId, LBL_LOCAL_TIME, OBJPROP_FONTSIZE, 10);
    ObjectSetString(gs_chartId, LBL_LOCAL_TIME, OBJPROP_FONT, "Verdana");
    SetLabelText(gs_chartId, LBL_LOCAL_TIME, "本地：" + TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));

    //delete buy beans button
    ObjectCreate(gs_chartId, BTN_CANCEL_BUY_BEANS, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_BUY_BEANS, OBJPROP_CORNER, CORNER_LEFT_LOWER);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_BUY_BEANS, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_BUY_BEANS, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_BUY_BEANS, OBJPROP_YDISTANCE, 75);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_BUY_BEANS, OBJPROP_XSIZE, 130);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_BUY_BEANS, OBJPROP_YSIZE, 30);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_BUY_BEANS, OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_BUY_BEANS, OBJPROP_BGCOLOR, C'236,233,216');
    ObjectSetInteger(gs_chartId, BTN_CANCEL_BUY_BEANS, OBJPROP_FONTSIZE, 10);
    ObjectSetString(gs_chartId, BTN_CANCEL_BUY_BEANS, OBJPROP_FONT, "Verdana");
    SetLabelText(gs_chartId, BTN_CANCEL_BUY_BEANS, "Delete BUY Beans");

    //delete sell beans button
    ObjectCreate(gs_chartId, BTN_CANCEL_SELL_BEANS, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_SELL_BEANS, OBJPROP_CORNER, CORNER_LEFT_LOWER);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_SELL_BEANS, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_SELL_BEANS, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_SELL_BEANS, OBJPROP_YDISTANCE, 40);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_SELL_BEANS, OBJPROP_XSIZE, 130);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_SELL_BEANS, OBJPROP_YSIZE, 30);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_SELL_BEANS, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(gs_chartId, BTN_CANCEL_SELL_BEANS, OBJPROP_BGCOLOR, C'236,233,216');
    ObjectSetInteger(gs_chartId, BTN_CANCEL_SELL_BEANS, OBJPROP_FONTSIZE, 10);
    ObjectSetString(gs_chartId, BTN_CANCEL_SELL_BEANS, OBJPROP_FONT, "Verdana");
    SetLabelText(gs_chartId, BTN_CANCEL_SELL_BEANS, "Delete SELL Beans");
}


//設定標籤文字內容
void SetLabelText(long chartId, string labelName, string labelText) {
    ObjectSetString(chartId, labelName, OBJPROP_TEXT, labelText);
}


//更新資訊標籤內容
void UpdateInfoLabels() {
    double medianPrice = NormalizeDouble((Ask + Bid) / 2, 5);
    SetLabelText(gs_chartId, LBL_PRICE, StringFormat("%.5f", medianPrice));
    if(medianPrice > Open[0])
        ObjectSetInteger(gs_chartId, LBL_PRICE, OBJPROP_COLOR, clrDeepSkyBlue);
    else if(medianPrice < Open[0])
        ObjectSetInteger(gs_chartId, LBL_PRICE, OBJPROP_COLOR, clrDeepPink);
    else
        ObjectSetInteger(gs_chartId, LBL_PRICE, OBJPROP_COLOR, clrDarkGray);

    SetLabelText(gs_chartId, LBL_SERVER_TIME, "主機：" + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    SetLabelText(gs_chartId, LBL_LOCAL_TIME, "本地：" + TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));
}


//控制顯示超過進場時間訊息
void SetTradeTimeLabel(bool isTradeTime) {
    if(isTradeTime) {
        ObjectDelete(gs_chartId, LBL_TRADE_TIME);
            
    } else {
        ObjectCreate(gs_chartId, LBL_TRADE_TIME, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(gs_chartId, LBL_TRADE_TIME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(gs_chartId, LBL_TRADE_TIME, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(gs_chartId, LBL_TRADE_TIME, OBJPROP_XDISTANCE, 320);
        ObjectSetInteger(gs_chartId, LBL_TRADE_TIME, OBJPROP_YDISTANCE, 60);
        ObjectSetInteger(gs_chartId, LBL_TRADE_TIME, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(gs_chartId, LBL_TRADE_TIME, OBJPROP_FONTSIZE, 24);
        ObjectSetString(gs_chartId, LBL_TRADE_TIME, OBJPROP_FONT, "微軟正黑體");
        SetLabelText(gs_chartId, LBL_TRADE_TIME, TRADE_TIME_MSG);
    }
}