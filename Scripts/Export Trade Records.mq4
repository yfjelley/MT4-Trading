#property copyright "Copyright 2016, Tim Hsu"
#property link      ""
#property version   "1.02"
#property description "以交易的主機端平倉時間為準, 匯出指定日期範圍的成交明細"
#property strict
#property script_show_inputs

//--- input parameters
input string START_DATE = "";    //平倉日起日(YYYY.MM.DD)
input string END_DATE   = "";    //平倉日訖日(YYYY.MM.DD)


void OnStart() {
    string startDate = "";
    string endDate = "";
    
    //如果起訖都不輸入, 就預設為本地系統日的前一日
    if(START_DATE == "" && END_DATE == "") {
        startDate = TimeToString(TimeLocal() - 24 * 60 * 60, TIME_DATE);
        endDate = startDate;
    }

    //如果只輸入起日, 訖日設為當日
    if(START_DATE != "" && END_DATE == "") {
        startDate = START_DATE;
        endDate = TimeToString(TimeLocal(), TIME_DATE);
    }
    
    //如果只輸入訖日, 起日設為 2010.01.01
    if(START_DATE == "" && END_DATE != "") {
        startDate = "2010.01.01";
        endDate = END_DATE;
    }
    
    int histOrders = OrdersHistoryTotal();
    Print("Total history orders: ", histOrders, ", Date to parse: ", startDate, " ~ ", endDate);

    string fileName = (string)AccountNumber() + ".csv";
    int outFile = FileOpen(fileName, FILE_COMMON|FILE_WRITE|FILE_CSV, ',', CP_UTF8);
    if(outFile < 0) {
        Alert("ERROR: Unable to open file.  Error code: " + (string)GetLastError());
        return;
    }
    
    FileWrite(outFile, "Account", "Ticket", "Symbol", "OrderType", "OpenTime", "OpenPrice", "CloseTime", "ClosePrice", "Lots", "Profit", "TakeProfit", "StopLoss", "Swap", "Commission", "Comment", "MagicNumber");
    
    double buyLots = 0;
    double sellLots = 0;
    double netProfit = 0;
    for(int i = 0; i < histOrders; i++) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
            //Alert("order " + i + ": " + TimeToString(OrderCloseTime(), TIME_DATE));
            if(TimeToString(OrderCloseTime(), TIME_DATE) >= startDate &&
               TimeToString(OrderCloseTime(), TIME_DATE) <= endDate &&
               OrderType() <= 1 ) {  // 0: buy, 1:sell
                //OrderPrint();
                //Alert("Account Number: " + AccountNumber()
                //    + ";\nTicket: " + (string)OrderTicket()
                //    + ";\nOrderType: " + (string)OrderType()
                //    + ";\nOrderOpenTime: " + (string)OrderOpenTime()
                //    + ";\nOrderOpenPrice: " + (string)OrderOpenPrice()
                //    + ";\nOrderCloseTime: " + (string)OrderCloseTime()
                //    + ";\nOrderClosePrice: " + (string)OrderClosePrice()
                //    + ";\nOrderSymbol: " + (string)OrderSymbol()
                //    + ";\nOrderLots: " + (string)OrderLots()
                //    + ";\nOrderProfit: " + (string)OrderProfit()
                //    + ";\nOrderCommission: " + (string)OrderCommission()
                //    + ";\nOrderSwap: " + (string)OrderSwap()
                //    + ";\nOrderComment: " + OrderComment()
                //    + ";\nOrderMagicNumber: " + OrderMagicNumber()
                //    );
                FileWrite(outFile, AccountNumber(), OrderTicket(), OrderSymbol(), OrderType(), 
                    OrderOpenTime(), OrderOpenPrice(), OrderCloseTime(), OrderClosePrice(), 
                    OrderLots(), OrderProfit(), OrderTakeProfit(), OrderStopLoss(), OrderSwap(), OrderCommission(), 
                    OrderComment(), OrderMagicNumber());

                if(OrderType() == 0)  buyLots += OrderLots();
                else  sellLots += OrderLots();
                netProfit += (OrderProfit() + OrderCommission() + OrderSwap());
            }
        } else {
            Alert("ERROR: Failed to get order: " + (string)GetLastError());             
        }
    }

    FileFlush(outFile);
    FileClose(outFile);
    
    PrintFormat("Transaction Summary: Buy %.2f, Sell %.2f, Net profit %.2f", buyLots, sellLots, netProfit);
    
    Print("交易明細紀錄檔儲存在: ",TerminalInfoString(TERMINAL_COMMONDATA_PATH), "\\Files\\", fileName); 
}
