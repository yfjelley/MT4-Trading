#property copyright "Copyright 2016, Tim Hsu"
#property link      ""
#property version   "1.01"
#property description "假裝犬類下單"
#property script_show_inputs
#property strict

#import "stdlib.ex4" 
string ErrorDescription(int error_code); 
#import

input int    ORD_TYPE     = 0;          //交易類型: 0=B 1=S 2=BL 3=SL 4=BS 5=SS
input int    ORD_PRICE    = 0;          //價格 (0=市價)
input double ORD_LOTS     = 0;          //手數
input string ORD_COMMENT  = "";         //附註
input int    MAGIC_NUMBER = 88882000;   //犬類 Magic number


void OnStart() {
    double price = ORD_PRICE * Point;
    if(ORD_TYPE == OP_BUY)  price = Ask;
    if(ORD_TYPE == OP_SELL)  price = Bid;
    
    int ticket = OrderSend(Symbol(), ORD_TYPE, ORD_LOTS, price, 0, 0, 0, ORD_COMMENT, MAGIC_NUMBER, 0, (ORD_TYPE % 2 == 0)? clrBlue : clrRed);
    if(ticket < 0)
        Alert("下單發生錯誤: " + CompileErrorMessage(GetLastError()));
}


//組合錯誤訊息
string CompileErrorMessage(int errorCode) {
    return (string)errorCode + " - " + ErrorDescription(errorCode);
}
