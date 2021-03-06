#property copyright "Copyright 2016, Tim Hsu"
#property link      ""
#property version   "1.16"
#property description "根據鱷魚線及 MACD 判斷入場時機，自動進行佈局"
#property strict
#include <TEA.mqh>


//使用者輸入參數
input string CUSTOM_COMMENT             = "【提姆茶６號】";    //畫面註解
input int    TRACE_PREV_BARS            = 360;                 //向前回溯幾根 K 棒以標示入場點
input string BREAK_LINE_1               = "＝＝＝＝＝";        //＝ [ 進場控制 ] ＝＝＝＝＝＝
input string TRADE_DAYS                 = "123456";            //操作日 (星期123456)
input int    TRADE_START_HOUR           = 0;                   //操作開始時間
input int    TRADE_END_HOUR             = 23;                  //操作結束時間
input string BREAK_LINE_2               = "＝＝＝＝＝";        //＝ [ 風險管理 ] ＝＝＝＝＝＝
input bool   STOP_TRADE_AFTER_STOP_LOSS = true;                //停損後暫停下單
input double STOP_LOSS_AMOUNT           = 0;                   //停損金額 (0: 關閉)
input double TAKE_PROFIT_AMOUNT         = 0;                   //停利金額 (0: 關閉)
input string BREAK_LINE_3               = "＝＝＝＝＝";        //＝ [ 下單參數 ] ＝＝＝＝＝＝
input double INITIAL_LOTS               = 1;                   //起始手數
input double MULTIPLIER                 = 1;                   //加碼比例
input int    MAXIMUM_ORDERS             = 10;                  //最大單數
input double MINIMUM_LOTS               = 0.1;                 //最小手數
input int    TAKE_PROFIT                = 0;                   //獲利點數 (0: 關閉)
input int    STOP_LOSS                  = 0;                   //停損點數 (0: 關閉)
input string BREAK_LINE_4               = "＝＝＝＝＝";        //＝ [ 交易紀錄 ] ＝＝＝＝＝＝
input bool   EXPORT_TXN_LOG             = true;                //每日匯出交易紀錄


//EA 相關
const int    MAGIC_NUMBER         = 930214;
const string ORDER_COMMENT_PREFIX = "TEA6_";    //交易單說明前置字串
const int    ARROW_GAP            = 30;         //畫 signal 箭號距 K 棒上下端的點數


//資訊顯示用的 Label 物件名稱
const string LBL_COMMENT      = "lblComment";
const string LBL_TRADE_ENV    = "lblTradEvn";
const string LBL_PRICE        = "lblPrice";
const string LBL_SIGNAL_TEXT  = "lblTrendingText";
const string LBL_SIGNAL       = "lblSignal";
const string LBL_SPREAD       = "lblSpread";
const string LBL_SERVER_TIME  = "lblServerTime";
const string LBL_LOCAL_TIME   = "lblLocalTime";
const string LBL_TRADE_TIME   = "lblTradeTime";
const string LBL_STOP_TRADE   = "lblStopTrade";
const string LBL_BASIC_PARAM  = "lblBasicParam";
const string LBL_MAX_LOSS_AMT = "lblMaxLossAmt";
const string ARROW_UP         = "↑";
const string ARROW_DOWN       = "↓";
const string ARROW_NONE       = "＝";
const string TRADE_TIME_MSG   = "茶棧已打烊，明日請早！";
const string STOP_TRADE_MSG   = "已達停損標準，茶棧暫停營業！";


//趨勢線轉折方向
const int TURN_NONE  =  0;
const int TURN_LONG  =  1;
const int TURN_SHORT = -1;


//全域變數
static bool        gs_isTradeTime    = false;
static bool        gs_stopTrading    = false;
static string      gs_symbol         = Symbol();
static long        gs_chartId        = 0;
static int         gs_lastSignal     = SIGNAL_NONE;
static string      gs_fileName       = "TEA6_" + (string)AccountNumber() + ".txt";
static double      gs_maxLossAmt     = 0;
static string      gs_maxLossAmtKey  = "MaxLossAmount";
static string      gs_lastExportDate = "";
static OrderStruct gs_buyPosition[];
static OrderStruct gs_sellPosition[];


int OnInit() {
    Print("Initializing ...");

    gs_symbol = Symbol();
    gs_chartId = ChartID();
    gs_isTradeTime = IsTradeTime(TRADE_DAYS, TRADE_START_HOUR, TRADE_END_HOUR);
    gs_lastSignal = CombineSignals(GetSignalByAlligator(), GetSignalByMACD());
    gs_lastExportDate = "";
    
    CollectOrders(gs_symbol, OP_BUY, MAGIC_NUMBER, gs_buyPosition);
    CollectOrders(gs_symbol, OP_SELL, MAGIC_NUMBER, gs_sellPosition);
    Print("Current position: BUY = ", ArraySize(gs_buyPosition), ", SELL = ", ArraySize(gs_sellPosition));

    PutInfoLables();
    UpdateInfoLabels();
    UpdateSignalLabel();
    SetTradeTimeLabel(gs_isTradeTime);

    return INIT_SUCCEEDED;
}


void OnDeinit(const int reason) {
    DeleteMyObjects();
}

void DeleteMyObjects() {
    ObjectDelete(gs_chartId, LBL_COMMENT);
    ObjectDelete(gs_chartId, LBL_TRADE_ENV);
    ObjectDelete(gs_chartId, LBL_PRICE);
    ObjectDelete(gs_chartId, LBL_SIGNAL_TEXT);
    ObjectDelete(gs_chartId, LBL_SIGNAL);
    ObjectDelete(gs_chartId, LBL_SPREAD);
    ObjectDelete(gs_chartId, LBL_SERVER_TIME);
    ObjectDelete(gs_chartId, LBL_LOCAL_TIME);
    ObjectDelete(gs_chartId, LBL_TRADE_TIME);
    ObjectDelete(gs_chartId, LBL_STOP_TRADE);
    ObjectDelete(gs_chartId, LBL_BASIC_PARAM);
    ObjectDelete(gs_chartId, LBL_MAX_LOSS_AMT);
    ObjectsDeleteAll(gs_chartId, -1, OBJ_ARROW);
}

void OnTick() {
    UpdateInfoLabels();

    //stop loss control by amount
    if(IsReachStopLossAmount(STOP_LOSS_AMOUNT)) {
        Print("Loss exceed $", STOP_LOSS_AMOUNT, ", closing position...");
        CloseMarketOrders(gs_buyPosition);
        CloseMarketOrders(gs_sellPosition);
        if(STOP_TRADE_AFTER_STOP_LOSS) {
            gs_stopTrading = true;
            SetStopTradeLabel(gs_stopTrading);
        }
        //refresh current position
        CollectOrders(gs_symbol, OP_BUY, MAGIC_NUMBER, gs_buyPosition);
        CollectOrders(gs_symbol, OP_SELL, MAGIC_NUMBER, gs_sellPosition);
    }

    //take profit control by amount
    if(IsReachTakeProfitAmount(TAKE_PROFIT_AMOUNT)) {
        Print("Profit exceed $", TAKE_PROFIT_AMOUNT, ", closing position...");
        CloseMarketOrders(gs_buyPosition);
        CloseMarketOrders(gs_sellPosition);

        //refresh current position
        CollectOrders(gs_symbol, OP_BUY, MAGIC_NUMBER, gs_buyPosition);
        CollectOrders(gs_symbol, OP_SELL, MAGIC_NUMBER, gs_sellPosition);
    }

    if(AccountProfit() < gs_maxLossAmt) {
        gs_maxLossAmt = NormalizeDouble(AccountProfit(), 2);
        WriteData(gs_fileName, gs_maxLossAmtKey, StringFormat("%.2f", MathAbs(gs_maxLossAmt)));
        PrintFormat("Max loss amount reached $%.2f", MathAbs(gs_maxLossAmt));
    }

    if(!HasNewBar())  return;

    //export orders closed in previous day
    if(EXPORT_TXN_LOG && TimeToString(TimeCurrent(), TIME_DATE) != gs_lastExportDate) {
        ExportTradeHistory(gs_symbol, "", "", MAGIC_NUMBER);
        gs_lastExportDate = TimeToString(TimeCurrent(), TIME_DATE);
    }

    //refresh current position    
    CollectOrders(gs_symbol, OP_BUY, MAGIC_NUMBER, gs_buyPosition);
    CollectOrders(gs_symbol, OP_SELL, MAGIC_NUMBER, gs_sellPosition);
    Print("Current position: BUY = ", ArraySize(gs_buyPosition), ", SELL = ", ArraySize(gs_sellPosition));

    //checking signal availability, and then close position (hopfully profitable)
    if(ArraySize(gs_buyPosition) > 0) {
        if(Close[1] < GetAlligator(Period(), MODE_GATORLIPS, 1) || MACDTurnningDirection() == TURN_SHORT) {
            Print("LONG trend is going to be end, closing BUY position.");
            CloseMarketOrders(gs_buyPosition);
            CollectOrders(gs_symbol, OP_BUY, MAGIC_NUMBER, gs_buyPosition);
            //if(gs_lastSignal == SIGNAL_BUY) {
            //    Print("Alligator is turning short, or close price crossed teeth.  Cancel BUY signal.");
            //    gs_lastSignal = SIGNAL_NONE;
            //}    
        }
    }

    if(ArraySize(gs_sellPosition) > 0) {
        if(Close[1] > GetAlligator(Period(), MODE_GATORLIPS, 1) || MACDTurnningDirection() == TURN_LONG) {
            Print("SHORT trend is going to end, closing SELL position.");
            CloseMarketOrders(gs_sellPosition);
            CollectOrders(gs_symbol, OP_SELL, MAGIC_NUMBER, gs_sellPosition);
            //if(gs_lastSignal == SIGNAL_SELL) {
            //    Print("Alligator is turning long, or close price crossed teeth.  Cancel BUY signal.");
            //    gs_lastSignal = SIGNAL_NONE;
            //}
        }
    }
    
    //check if signal appears
    gs_lastSignal = CombineSignals(GetSignalByAlligator(), GetSignalByMACD());
    UpdateSignalLabel();
    if(gs_lastSignal == SIGNAL_BUY) {
        PutSignalArrow(SIGNAL_BUY, Time[1], Low[1] - ARROW_GAP * Point);
    } else if(gs_lastSignal == SIGNAL_SELL) {
        PutSignalArrow(SIGNAL_SELL, Time[1], High[1] + ARROW_GAP * 2 * Point);
    }

    //check trading time
    gs_isTradeTime = IsTradeTime(TRADE_DAYS, TRADE_START_HOUR, TRADE_END_HOUR);
    SetTradeTimeLabel(gs_isTradeTime);
    if(!gs_isTradeTime)  return;

    if(gs_stopTrading)  return;

    if(gs_lastSignal == SIGNAL_BUY) {
        Print("Last signal is BUY, placeing buy order...");
        PlaceOrder(gs_buyPosition, OP_BUY);
    }

    if(gs_lastSignal == SIGNAL_SELL) {
        Print("Last signal is SELL, placeing sell order...");
        PlaceOrder(gs_sellPosition, OP_SELL);
    }
    Print("Current position: BUY = ", ArraySize(gs_buyPosition), ", SELL = ", ArraySize(gs_sellPosition));
}


//下單邏輯
void PlaceOrder(OrderStruct& orders[], int orderType) {
    int orderCnt = ArraySize(orders);
    if(orderCnt >= MAXIMUM_ORDERS) {
        Print("Reached maximum orders, reject to place new order.");
        return;
    }
    
    double lastLots = (orderCnt == 0)? 0 : orders[orderCnt - 1].lots;
    double lastPrice = (orderCnt == 0)? 0 : orders[orderCnt - 1].openPrice;
    double lots = 0;
    double currentPrice = 0;
    double takeProfit = 0;
    double stopLoss = 0;
    string comment = BuildOrderComment(orderType, orderCnt + 1);
    string orderTypeString = "";
        
    if(orderType == OP_BUY) {
        orderTypeString = "BUY";
        currentPrice = Ask;
        takeProfit = (TAKE_PROFIT == 0)? 0 : currentPrice + TAKE_PROFIT * Point;
        stopLoss = (STOP_LOSS == 0)? 0 : currentPrice - STOP_LOSS * Point;
    } else {
        orderTypeString = "SELL";
        currentPrice = Bid;
        takeProfit = (TAKE_PROFIT == 0)? 0 : currentPrice - TAKE_PROFIT * Point;
        stopLoss = (STOP_LOSS == 0)? 0 : currentPrice + STOP_LOSS * Point;
    }

    if(orderCnt == 0) {
        Print(orderTypeString, " signal confirmed, placing initial order.");
        lots = INITIAL_LOTS;
    } else {
        Print(orderTypeString, " signal continued, placing more orders.");
        lots = NormalizeDouble(lastLots * MULTIPLIER, 2);
        if(lots <= MINIMUM_LOTS)  lots = MINIMUM_LOTS;
    }
    
    Print("Sending ", orderTypeString, " order...");
    int ticket = SendOrder(gs_symbol, orderType, currentPrice, lots,comment, MAGIC_NUMBER, takeProfit, stopLoss);
    
    if(ticket > 0) {
        AddTicketToPosition(ticket, orders);
    }
}


//put signal arrow
void PutSignalArrow(int signalType, datetime arrowTime, double arrowPrice) {
    const int BUY_ARROW_CODE  = 233;
    const int SELL_ARROW_CODE = 234;
    
    static int arrowId = 0;
    string arrowName = "SIGNAL_" + (string)arrowId++;
    color arrowColor;
    
    if(signalType == SIGNAL_BUY) {
        arrowColor = clrBlue;
        
        ObjectCreate(gs_chartId, arrowName, OBJ_ARROW, 0, arrowTime, arrowPrice);
        ObjectSetInteger(gs_chartId, arrowName, OBJPROP_ARROWCODE, BUY_ARROW_CODE);
        ObjectSetInteger(gs_chartId, arrowName, OBJPROP_COLOR, arrowColor);
    }

    if(signalType == SIGNAL_SELL) {
        arrowColor = clrRed;
        
        ObjectCreate(gs_chartId, arrowName, OBJ_ARROW, 0, arrowTime, arrowPrice);
        ObjectSetInteger(gs_chartId, arrowName, OBJPROP_ARROWCODE, SELL_ARROW_CODE);
        ObjectSetInteger(gs_chartId, arrowName, OBJPROP_COLOR, arrowColor);
    }
}


//交易單註解
string BuildOrderComment(int orderType, int orderSeq) {
    if(orderType == OP_BUY)
        return ORDER_COMMENT_PREFIX + gs_symbol + "_B-" + (string)orderSeq;

    if(orderType == OP_SELL)
        return ORDER_COMMENT_PREFIX + gs_symbol + "_S-" + (string)orderSeq;
    
    return NULL;    
}


//在圖表上安置各項資訊標籤物件
void PutInfoLables() {
    DeleteMyObjects();

    //put signal arrows for past K bars
    int signal = SIGNAL_NONE;
    for(int i = 1; i <= TRACE_PREV_BARS; i++) {
        signal = CombineSignals(GetSignalByAlligator(i), GetSignalByMACD(i));
        if(signal == SIGNAL_BUY) {
            PutSignalArrow(SIGNAL_BUY, Time[i], Low[i] - ARROW_GAP * Point);
        } else if(signal == SIGNAL_SELL) {
            PutSignalArrow(SIGNAL_SELL, Time[i], High[i] + ARROW_GAP * 2 * Point);
        }
    }

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

    //進場訊號標題
    ObjectCreate(gs_chartId, LBL_SIGNAL_TEXT, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_SIGNAL_TEXT, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(gs_chartId, LBL_SIGNAL_TEXT, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, LBL_SIGNAL_TEXT, OBJPROP_XDISTANCE, 82);
    ObjectSetInteger(gs_chartId, LBL_SIGNAL_TEXT, OBJPROP_YDISTANCE, 98);
    ObjectSetInteger(gs_chartId, LBL_SIGNAL_TEXT, OBJPROP_COLOR, clrNavajoWhite);
    ObjectSetInteger(gs_chartId, LBL_SIGNAL_TEXT, OBJPROP_FONTSIZE, 12);
    ObjectSetString(gs_chartId, LBL_SIGNAL_TEXT, OBJPROP_FONT, "微軟正黑體");
    SetLabelText(gs_chartId, LBL_SIGNAL_TEXT, "進場信號：");

    //進場訊號
    ObjectCreate(gs_chartId, LBL_SIGNAL, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_SIGNAL, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(gs_chartId, LBL_SIGNAL, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, LBL_SIGNAL, OBJPROP_XDISTANCE, 70);
    ObjectSetInteger(gs_chartId, LBL_SIGNAL, OBJPROP_YDISTANCE, 98);
    ObjectSetInteger(gs_chartId, LBL_SIGNAL, OBJPROP_COLOR, clrLightGray);
    ObjectSetInteger(gs_chartId, LBL_SIGNAL, OBJPROP_FONTSIZE, 12);
    ObjectSetString(gs_chartId, LBL_SIGNAL, OBJPROP_FONT, "Verdana");
    SetLabelText(gs_chartId, LBL_SIGNAL, ARROW_NONE);

    //點差
    ObjectCreate(gs_chartId, LBL_SPREAD, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_SPREAD, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(gs_chartId, LBL_SPREAD, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetInteger(gs_chartId, LBL_SPREAD, OBJPROP_XDISTANCE, 5);
    ObjectSetInteger(gs_chartId, LBL_SPREAD, OBJPROP_YDISTANCE, 98);
    ObjectSetInteger(gs_chartId, LBL_SPREAD, OBJPROP_COLOR, clrNavajoWhite);
    ObjectSetInteger(gs_chartId, LBL_SPREAD, OBJPROP_FONTSIZE, 12);
    ObjectSetString(gs_chartId, LBL_SPREAD, OBJPROP_FONT, "Verdana");
    SetLabelText(gs_chartId, LBL_SPREAD, StringFormat("(%.0f)", MarketInfo(gs_symbol, MODE_SPREAD)));

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

    //基本參數
    ObjectCreate(gs_chartId, LBL_BASIC_PARAM, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_BASIC_PARAM, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(gs_chartId, LBL_BASIC_PARAM, OBJPROP_ANCHOR, ANCHOR_LEFT);
    ObjectSetInteger(gs_chartId, LBL_BASIC_PARAM, OBJPROP_XDISTANCE, 5);
    ObjectSetInteger(gs_chartId, LBL_BASIC_PARAM, OBJPROP_YDISTANCE, 22);
    ObjectSetInteger(gs_chartId, LBL_BASIC_PARAM, OBJPROP_COLOR, clrDarkOrange);
    ObjectSetInteger(gs_chartId, LBL_BASIC_PARAM, OBJPROP_FONTSIZE, 12);
    ObjectSetString(gs_chartId, LBL_BASIC_PARAM, OBJPROP_FONT, "Consolas");
    string basicParam = StringFormat("Param: %d-%d, %.2f/%.3fx, TP$=%.2f, SL$=%.2f, Profit$=%.2f", TRADE_START_HOUR, TRADE_END_HOUR, INITIAL_LOTS, MULTIPLIER, TAKE_PROFIT_AMOUNT, STOP_LOSS_AMOUNT, AccountProfit());
    SetLabelText(gs_chartId, LBL_BASIC_PARAM, basicParam);

    //最大浮虧金額
    ObjectCreate(gs_chartId, LBL_MAX_LOSS_AMT, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(gs_chartId, LBL_MAX_LOSS_AMT, OBJPROP_CORNER, CORNER_LEFT_LOWER);
    ObjectSetInteger(gs_chartId, LBL_MAX_LOSS_AMT, OBJPROP_ANCHOR, ANCHOR_LEFT);
    ObjectSetInteger(gs_chartId, LBL_MAX_LOSS_AMT, OBJPROP_XDISTANCE, 5);
    ObjectSetInteger(gs_chartId, LBL_MAX_LOSS_AMT, OBJPROP_YDISTANCE, 15);
    ObjectSetInteger(gs_chartId, LBL_MAX_LOSS_AMT, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(gs_chartId, LBL_MAX_LOSS_AMT, OBJPROP_FONTSIZE, 10);
    ObjectSetString(gs_chartId, LBL_MAX_LOSS_AMT, OBJPROP_FONT, "Verdana");
    SetLabelText(gs_chartId, LBL_MAX_LOSS_AMT, "最大浮虧 $" + (string)MathAbs(gs_maxLossAmt));
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

    SetLabelText(gs_chartId, LBL_SPREAD, StringFormat("(%.0f)", MarketInfo(gs_symbol, MODE_SPREAD)));

    SetLabelText(gs_chartId, LBL_SERVER_TIME, "主機：" + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    SetLabelText(gs_chartId, LBL_LOCAL_TIME, "本地：" + TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));

    string basicParam = StringFormat("Param: %d-%d, %.2f/%.3fx, TP$=%.2f, SL$=%.2f, Profit$=%.2f", TRADE_START_HOUR, TRADE_END_HOUR, INITIAL_LOTS, MULTIPLIER, TAKE_PROFIT_AMOUNT, STOP_LOSS_AMOUNT, AccountProfit());
    SetLabelText(gs_chartId, LBL_BASIC_PARAM, basicParam);

    SetLabelText(gs_chartId, LBL_MAX_LOSS_AMT, "最大浮虧 $" + (string)MathAbs(gs_maxLossAmt));
}


//更新趨勢標籤顯示狀態
void UpdateSignalLabel() {
    if(gs_lastSignal == SIGNAL_NONE) {
        SetLabelText(gs_chartId, LBL_SIGNAL, ARROW_NONE);
        ObjectSetInteger(gs_chartId, LBL_SIGNAL, OBJPROP_COLOR, clrLightGray);

    } else if(gs_lastSignal == SIGNAL_SELL) {
        SetLabelText(gs_chartId, LBL_SIGNAL, ARROW_DOWN);
        ObjectSetInteger(gs_chartId, LBL_SIGNAL, OBJPROP_COLOR, clrDeepPink);

    } else {
        SetLabelText(gs_chartId, LBL_SIGNAL, ARROW_UP);
        ObjectSetInteger(gs_chartId, LBL_SIGNAL, OBJPROP_COLOR, clrDeepSkyBlue);
    }
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


//控制顯示停損暫停交易訊息
void SetStopTradeLabel(bool isStopTrading) {
    if(isStopTrading) {
        ObjectCreate(gs_chartId, LBL_STOP_TRADE, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(gs_chartId, LBL_STOP_TRADE, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(gs_chartId, LBL_STOP_TRADE, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(gs_chartId, LBL_STOP_TRADE, OBJPROP_XDISTANCE, 90);
        ObjectSetInteger(gs_chartId, LBL_STOP_TRADE, OBJPROP_YDISTANCE, 100);
        ObjectSetInteger(gs_chartId, LBL_STOP_TRADE, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(gs_chartId, LBL_STOP_TRADE, OBJPROP_FONTSIZE, 32);
        ObjectSetString(gs_chartId, LBL_STOP_TRADE, OBJPROP_FONT, "微軟正黑體");
        SetLabelText(gs_chartId, LBL_STOP_TRADE, STOP_TRADE_MSG);
            
    } else {
        ObjectDelete(gs_chartId, LBL_STOP_TRADE);
    }
}


//偵測 Alligator lips 是否反轉
int LipsTurnningDirection() {
    static int turnningPoint = 0;

    double lips_last3 = GetAlligator(Period(), MODE_GATORLIPS, 3);
    double lips_current = GetAlligator(Period(), MODE_GATORLIPS, 0);
    double lips_next3 = GetAlligator(Period(), MODE_GATORLIPS, -3);

    double slop_history = (lips_current - lips_last3) * MathPow(10, Digits) / 3;
    double slop_furture = (lips_next3 - lips_current) * MathPow(10, Digits) / 3;

    PrintFormat("Slop: history = %.2f; future = %.2f", slop_history, slop_furture);

    if(slop_history < 0 && slop_furture > 0) {
        Print("Lips is turnning LONG.");
        return TURN_LONG;
    }

    if(slop_history > 0 && slop_furture < 0) {
        Print("Lips is turnning SHORT.");
        return TURN_SHORT;
    } 
    
    Print("Lips is NOT turnning, keep the same trend.");
    return TURN_NONE;
}


//偵測 MACD 柱是否反轉
int MACDTurnningDirection() {
    if(GetMACD(Period(), MODE_MAIN, 2) < GetMACD(Period(), MODE_MAIN, 1) &&
       GetMACD(Period(), MODE_MAIN, 2) < GetMACD(Period(), MODE_MAIN, 3)) {
        Print("Found MACD is turnning LONG.");
        return TURN_LONG;
    }

    if(GetMACD(Period(), MODE_MAIN, 2) > GetMACD(Period(), MODE_MAIN, 1) &&
       GetMACD(Period(), MODE_MAIN, 2) > GetMACD(Period(), MODE_MAIN, 3)) {
        Print("Found MACD is turnning SHORT.");
        return TURN_SHORT;
    }

    return TURN_NONE;
}