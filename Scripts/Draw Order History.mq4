#property copyright "Copyright 2016, Tim Hsu"
#property link      ""
#property version   "1.04"
#property description "繪製歷史交易軌跡"
#property strict
#property script_show_inputs
#include <TEA.mqh>

input bool DRAW_BUY_ORDERS  = true;  //繪製 BUY 軌跡
input bool DRAW_SELL_ORDERS = true;  //繪製 SELL 軌跡
input int  MAGIC_NUMBER     = 0;     //EA Magic Number

static long gs_chartId = ChartID();

void OnStart() {
    ObjectsDeleteAll(gs_chartId);
    
    if(DRAW_BUY_ORDERS) {
        OrderStruct buyOrders[];
        CollectHistoryOrders(Symbol(), OP_BUY, MAGIC_NUMBER, buyOrders);
        DrawTrades(buyOrders, OP_BUY);
    }

    if(DRAW_SELL_ORDERS) {
        OrderStruct sellOrders[];
        CollectHistoryOrders(Symbol(), OP_SELL, MAGIC_NUMBER, sellOrders);
        DrawTrades(sellOrders, OP_SELL);
    }

}


//繪製交易軌跡
void DrawTrades(OrderStruct& orders[], int orderType) {
    string desc;
    double profit;
    for(int i = 0; i < ArraySize(orders); i++) {
        desc = StringFormat("Lots %.2f  %s", orders[i].lots, orders[i].comment);
        DrawOpenArrow("O-" + (string)orders[i].ticket, orders[i].openTime, orders[i].openPrice, orders[i].orderType, desc);

        profit = NormalizeDouble(orders[i].profit + orders[i].swap, 2);
        desc = "";
        DrawLine("L-" + (string)orders[i].ticket, orders[i].openTime, orders[i].openPrice, orders[i].closeTime, orders[i].closePrice, orders[i].orderType, desc, (profit >= 0));
        
        desc = StringFormat("Profit $%.2f", profit);
        DrawCloseArrow("C-" + (string)orders[i].ticket, orders[i].closeTime, orders[i].closePrice, orders[i].orderType, desc);
    }
}


//畫進場點
void DrawOpenArrow(string arrowName, datetime arrowTime, double arrowPrice, int orderType, string description = "") {
    ENUM_OBJECT objType = (orderType == OP_BUY)? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
    color orderColor = (orderType == OP_BUY)? clrBlue : clrRed;
    
    ObjectCreate(gs_chartId, arrowName, objType, 0, arrowTime, arrowPrice);
    ObjectSetInteger(gs_chartId, arrowName, OBJPROP_COLOR, orderColor);
    ObjectSetString(gs_chartId, arrowName, OBJPROP_TEXT, description);
}

//畫出場點
void DrawCloseArrow(string arrowName, datetime arrowTime, double arrowPrice, int orderType, string description = "") {
    ENUM_OBJECT objType = OBJ_ARROW_STOP;
    color orderColor = (orderType == OP_BUY)? clrBlue : clrRed;
    
    ObjectCreate(gs_chartId, arrowName, objType, 0, arrowTime, arrowPrice);
    ObjectSetInteger(gs_chartId, arrowName, OBJPROP_COLOR, orderColor);
    ObjectSetString(gs_chartId, arrowName, OBJPROP_TEXT, description);
}


//畫出進場點至出場點之間的連線
void DrawLine(string lineName, datetime lineOpenTime, double lineOpenPrice, datetime lineCloseTime, double lineClosePrice, int orderType, string description = "", bool profitable = true) {
    color orderColor = (orderType == OP_BUY)? clrDodgerBlue : clrOrangeRed;
    
    ObjectCreate(gs_chartId, lineName, OBJ_TREND, 0, lineOpenTime, lineOpenPrice, lineCloseTime, lineClosePrice);
    ObjectSetInteger(gs_chartId, lineName, OBJPROP_COLOR, orderColor);
    if(profitable) {
        ObjectSetInteger(gs_chartId, lineName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(gs_chartId, lineName, OBJPROP_WIDTH, 2);
    } else {
        ObjectSetInteger(gs_chartId, lineName, OBJPROP_STYLE, STYLE_DASH);
        //ObjectSetInteger(gs_chartId, lineName, OBJPROP_WIDTH, 1);
    }
    ObjectSetString(gs_chartId, lineName, OBJPROP_TEXT, description);
    ObjectSet(lineName, OBJPROP_RAY, 0);
    ObjectSetString(gs_chartId, lineName, OBJPROP_TEXT, description);
}