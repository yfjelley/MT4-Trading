#property copyright "Copyright 2016, Tim Hsu"
#property link      ""
#property version   "1.00"
#property description "取消 TEA No.3 送出的預掛單"
#property strict
#property script_show_inputs
#include <TEA.mqh>


//--- input parameters
input bool CANCEL_PENDING_BUY  = true;    //是否取消預掛 Buy 單
input bool CANCEL_PENDING_SELL = true;    //是否取消預掛 Sell 單

const int MAGIC_NUMBER = 930214;

void OnStart() {
    int tickets[];

    if(CANCEL_PENDING_BUY) {
        CollectOrders(Symbol(), OP_BUYSTOP, MAGIC_NUMBER, tickets);
        DeletePendingOrders(tickets);
    }

    if(CANCEL_PENDING_SELL) {
        CollectOrders(Symbol(), OP_SELLSTOP, MAGIC_NUMBER, tickets);
        DeletePendingOrders(tickets);
    }
}