//+------------------------------------------------------------------+
//|                                                      TimUtil.mq4 |
//|                                          Copyright 2016, Tim Hsu |
//|                                                                  |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2016, Tim Hsu"
#property link      ""
#property version   "1.00"
#property strict

#import "stdlib.ex4" 
string ErrorDescription(int error_code); 
#import

//組合錯誤訊息
string CompileErrorMessage(int errorCode) export {
    return (string)errorCode + " - " + ErrorDescription(errorCode);
}


//偵測是否有新的 K 棒產生
bool HasNewBar() export {
    static datetime lastBarOpenTime;
    datetime currentBarOpenTime = Time[0];

    if(lastBarOpenTime != currentBarOpenTime) {
        lastBarOpenTime = currentBarOpenTime;
        return true;
    } else {
        return false;
    }
}


//以市價結清指定的倉單
void CloseOrders(int& orders[]) export {
    for(int i = 0; i < ArraySize(orders); i++) {
        if(OrderSelect(orders[i], SELECT_BY_TICKET, MODE_TRADES)) {
            if(OrderType() == OP_BUY) {
                if(!OrderClose(OrderTicket(), OrderLots(), Bid, 0))
                    Alert("平倉 " + (string)OrderTicket() + " 發生錯誤:" + CompileErrorMessage(GetLastError()));
            }

            if(OrderType() == OP_SELL) {
                if(!OrderClose(OrderTicket(), OrderLots(), Ask, 0))
                    Alert("平倉 " + (string)OrderTicket() + " 發生錯誤:" + CompileErrorMessage(GetLastError()));
            }
            
        } else {
            Alert("取得指定倉單: " + (string)orders[i], + " 發生錯誤: " + CompileErrorMessage(GetLastError()));
        }
    }
}


//刪除預掛單
void DeletePendingOrders(int& orders[]) export {
    for(int i = 0; i < ArraySize(orders); i++) {
        if(!OrderDelete(orders[i]))
            Alert("刪除預掛單 " + (string)orders[i] + " 發生錯誤: " + CompileErrorMessage(GetLastError()));
    }    
}


//取得指定類型的倉單編號
bool CollectOrderTickets(string symbol, int orderType, int& tickets[], int magicNumber = 930214) export {
    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if(OrderSymbol() == symbol && OrderType() == orderType && OrderMagicNumber() == magicNumber) {
                ArrayResize(tickets, ArraySize(tickets) + 1, 100);
                tickets[ArraySize(tickets) - 1] = OrderTicket();
            }
        } else {
            Alert("取得倉單發生錯誤: " + CompileErrorMessage(GetLastError()));
            return false;
        }
    }
    
    return true;
}
