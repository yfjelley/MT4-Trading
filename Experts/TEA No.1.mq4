#property copyright "Copyright 2016, Tim Hsu"
#property link      ""
#property version   "1.00"
#property description "利用鱷魚線判斷趨勢走向"
#property description "當有明顯趨發生時, 順向加碼"
#property description "當趨勢轉折時, 自動平倉"
#property strict

input string BREAK_LINE_0        = "====="; //== [總體參數] =====
input int    ALLIGATOR_GAP       = 5;       //鱷魚線之間的間隙

input string BREAK_LINE_1        = "====="; //== [BUY 參數] =====
input double BUY_INITIAL_LOTS    = 0.01;    //BUY 起始手數
input double BUY_INCREMENT_LOTS  = 0.02;    //BUY 加碼手數
input int    BUY_MAX_ORDERS      = 10;      //BUY 最大單數
input int    BUY_TAKE_PROFIT     = 100;     //BUY 停利點數

input string BREAK_LINE_2        = "====="; //== [SELL 參數] =====
input double SELL_INITIAL_LOTS   = 0.01;    //SELL 起始手數
input double SELL_INCREMENT_LOTS = 0.02;    //SELL 加碼手數
input int    SELL_MAX_ORDERS     = 10;      //SELL 最大單數
input int    SELL_TAKE_PROFIT    = 100;     //SELL 停利點數

#import "TimUtil.ex4" 
string CompileErrorMessage(int errorCode);
bool HasNewBar();
void CloseOrders(int& orders[]);
bool CollectOrderTickets(string symbol, int orderType, int& tickets[]);
#import

const string ORDER_COMMENT_PREFIX = "_TEA01_";
const int    SLIPPAGE             = 0;

//趨勢線方向
const int TREND_NONE  =  0;
const int TREND_LONG  =  1;
const int TREND_SHORT = -1;

//趨勢線轉折方向
const int TURN_NONE  =  0;
const int TURN_LONG  =  1;
const int TURN_SHORT = -1;

static int _lastTurnningDirection;

int OnInit() {
    Print("Initializing ...");
    _lastTurnningDirection = TREND_NONE;
    
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    Print("Deinitializing ...");
}


void OnTick() {
    if(!HasNewBar()) return;

    Print("========== A new K bar comes in. ==========");
    if(!(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED))) {
        //Print("允許 EA 自動交易選項未開啟!");
        return;
    }

    //收集目前開倉的單號
    int buyOrders[];
    int sellOrders[];
    
    CollectOrderTickets(Symbol(), OP_BUY, buyOrders);
    CollectOrderTickets(Symbol(), OP_SELL, sellOrders);

    Print("Checking trend and turnning direction...");
    int currentTrend = AlligatorTrend(0);
    int estimatedTrend = AlligatorTrend(-3);
    int currentTurn = LipsTurnningDirection();
    
    if(currentTurn != TURN_NONE) {
        _lastTurnningDirection = currentTurn;
    }
    
    //Lips 轉折與趨勢不同向, 則停損處理
    if(currentTurn != currentTrend) {
        //趨勢向多, 轉折向空, 且預估 lips 觸及 teeth 時, 平 Buy 單
        if(currentTrend == TREND_LONG && GetAlligator(MODE_GATORLIPS, -3) < GetAlligator(MODE_GATORTEETH, -3)) {
            Print("Closing BUY orders due to lips turnning over.");
            CloseOrders(buyOrders);
        }

        //趨勢向空, 轉折向多時, 且預估 lips 觸及 teeth 時, 平 Sell 單
        if(currentTrend == TREND_SHORT && GetAlligator(MODE_GATORLIPS, -3) > GetAlligator(MODE_GATORTEETH, -3)) {
            Print("Closing SELL orders due to lips turnning over.");
            CloseOrders(sellOrders);
        }
    } 
    

    //Lips 轉折與預估趨勢同向, 或無轉折(初始化或趨勢延續時), 則開倉或再加碼
    if(_lastTurnningDirection == TURN_NONE || _lastTurnningDirection == estimatedTrend) {
        double orderLots = 0;
        int ticket = 0;
        string comment = "";
        double takeProfit = 0;
        double stopLoss = 0;
        
        //佈局 buy 單
        if(estimatedTrend == TREND_LONG && ArraySize(buyOrders) < BUY_MAX_ORDERS /*&& Ask > GetAlligator(MODE_GATORLIPS, 0)*/) {
            if(ArraySize(buyOrders) == 0) {
                orderLots = BUY_INITIAL_LOTS;
                comment = Symbol() + ORDER_COMMENT_PREFIX + "B-0";    

            } else {
                if(OrderSelect(buyOrders[ArraySize(buyOrders) - 1], SELECT_BY_TICKET, MODE_TRADES)) {
                    orderLots = OrderLots() + BUY_INCREMENT_LOTS;
                    comment = Symbol() + ORDER_COMMENT_PREFIX + "B-" + (string)(ArraySize(buyOrders));
                }
                else {
                    Alert("取得指定倉單 " + (string)buyOrders[ArraySize(buyOrders) - 1], " 發生錯誤: " + CompileErrorMessage(GetLastError()));
                }
            }
            
            ticket = OrderSend(Symbol(), OP_BUY, orderLots, Ask, SLIPPAGE, stopLoss, takeProfit, comment, 930214, 0, clrBlue);
            if(ticket > 0) {
                if(BUY_TAKE_PROFIT != 0) {  //設定停利點
                    if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
                        takeProfit = OrderOpenPrice() + BUY_TAKE_PROFIT * Point;
                        if(!OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), takeProfit, OrderExpiration(), clrBlue)) {
                            Alert("設定倉單停利點 " + (string)ticket + " 發生錯誤: " + CompileErrorMessage(GetLastError()));
                        }
                    
                    } else {
                        Alert("取得指定倉單 " + (string)ticket + " 發生錯誤: " + CompileErrorMessage(GetLastError()));
                    }
                }
            
            } else {
                Alert("佈局 Buy 單發生錯誤: " + CompileErrorMessage(GetLastError()));
            }
        }
        
        //佈局 sell 單
        if(estimatedTrend == TREND_SHORT && ArraySize(sellOrders) < SELL_MAX_ORDERS /*&& Bid < GetAlligator(MODE_GATORLIPS, 0)*/) {
            if(ArraySize(sellOrders) == 0) {
                orderLots = SELL_INITIAL_LOTS;
                comment = Symbol() + ORDER_COMMENT_PREFIX + "S-0";

            } else {
                if(OrderSelect(sellOrders[ArraySize(sellOrders) - 1], SELECT_BY_TICKET, MODE_TRADES)) {
                    orderLots = OrderLots() + SELL_INCREMENT_LOTS;
                    comment = Symbol() + ORDER_COMMENT_PREFIX + "S-" + (string)(ArraySize(sellOrders));
                }
                else {
                    Alert("取得指定倉單 " + (string)sellOrders[ArraySize(sellOrders) - 1] + " 發生錯誤: " + CompileErrorMessage(GetLastError()));
                }
            }

            ticket = OrderSend(Symbol(), OP_SELL, orderLots, Bid, SLIPPAGE, stopLoss, takeProfit, comment, 930214, 0, clrRed);
            if(ticket > 0) {
                if(SELL_TAKE_PROFIT != 0) {  //設定停利點
                    if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
                        takeProfit = OrderOpenPrice() - SELL_TAKE_PROFIT * Point;
                        if(!OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), takeProfit, OrderExpiration(), clrBlue)) {
                            Alert("設定倉單停利點 " + (string)ticket + " 發生錯誤: " + CompileErrorMessage(GetLastError()));
                        }
                    } else {
                        Alert("取得指定倉單 " + (string)ticket + " 發生錯誤: " + CompileErrorMessage(GetLastError()));
                    }
                }
            
            } else {
                Alert("佈局 Sell 單發生錯誤: " + CompileErrorMessage(GetLastError()));
            }
        }
    }
}


//偵測 Alligator lips 是否反轉
int LipsTurnningDirection() {
    static int turnningPoint = 0;

    double lips_last3 = GetAlligator(MODE_GATORLIPS, 3);
    double lips_current = GetAlligator(MODE_GATORLIPS, 0);
    double lips_next3 = GetAlligator(MODE_GATORLIPS, -3);

    double slop_history = (lips_current - lips_last3) * MathPow(10, Digits) / 3;
    double slop_furture = (lips_next3 - lips_current) * MathPow(10, Digits) / 3;

    PrintFormat("Slop: history = %.2f; future = %.2f", slop_history, slop_furture);

    if(slop_history < 0 && slop_furture > 0) {
        Print("Lips is turnning LONG.");
        ObjectCreate(ChartID(), "turn" + (string)turnningPoint++, OBJ_ARROW_UP, 0, TimeCurrent(), Open[0]);
        ChartRedraw();
        return TURN_LONG;
    }

    if(slop_history > 0 && slop_furture < 0) {
        Print("Lips is turnning SHORT.");
        ObjectCreate(ChartID(), "turn" + (string)turnningPoint++, OBJ_ARROW_DOWN, 0, TimeCurrent(), Open[0]);
        ChartRedraw();
        return TURN_SHORT;
    } 
    
    Print("Lips is NOT turnning, keep the same trend.");
    return TURN_NONE;
}


//用鱷魚線判斷趨勢
int AlligatorTrend(int shift = 0) {
    double lips = GetAlligator(MODE_GATORLIPS, shift);
    double teeth = GetAlligator(MODE_GATORTEETH, shift);
    double jaw = GetAlligator(MODE_GATORJAW, shift);
    
    double diff_lips_teeth = MathAbs(lips - teeth) * MathPow(10, Digits);
    double diff_jaw_teeth = MathAbs(jaw - teeth) * MathPow(10, Digits);
    
    PrintFormat("timeframe: %d; lips = %.5f; teeth = %.5f; jaw = %.5f; diff_lips_teeth: %.0f; diff_jaw_teeth: %.0f", shift, lips, teeth, jaw, diff_lips_teeth, diff_jaw_teeth);
    
    if(lips > teeth && teeth > jaw && diff_lips_teeth > ALLIGATOR_GAP && diff_jaw_teeth > ALLIGATOR_GAP) {
        PrintFormat("Timeframe %d is a LONG trend.", shift);
        return TREND_LONG;
    }
    
    if(jaw > teeth && teeth > lips && diff_lips_teeth > ALLIGATOR_GAP && diff_jaw_teeth > ALLIGATOR_GAP) {
        PrintFormat("Timeframe %d is a SHORT trend.", shift);
        return TREND_SHORT;
    }
    
    PrintFormat("Timeframe %d has NO trend.", shift);
    return TREND_NONE;
}


//取得鱷魚線的值
double GetAlligator(int lineMode, int shift) {
    return iAlligator(NULL, 0, 13, 8, 8, 5, 5, 3, MODE_SMMA, PRICE_MEDIAN, lineMode, shift);
}