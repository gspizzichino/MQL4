// --- Parametri Configurabili ---
input int EMA_Fast_Period = 10;              // Fast EMA period
input int EMA_Slow_Period = 20;             // Slow EMA period
input int ATR_Period = 14;                  // ATR calculation period
input int ADX_Period = 14;
input int RSI_Period = 7;
input double ADX_Threshold = 20.0;   // Soglia ADX per considerare un trend
input double ATR_Multiplier_SL = 1.5;       // Multiplier for Stop Loss (1.5x ATR)
input double ATR_Multiplier_TP = 2.0;       // Multiplier for Take Profit (2x ATR)
input double Lots = 0.01;                    // Fixed lot size per trade
input int MagicNumber = 123456;             // Unique identifier for trades by this EA
input int MinSignalDistance = 3;    // Distanza minima tra segnali in numero di candele
input string TradeLogFileName = "TradeLog.csv"; // Nome del file di log
input bool AppendLog = true;                   // Accoda al log esistente
// Global Variables
int consecutiveLosses = 0;  // Track consecutive losses
input int MaxConsecutiveLosses = 3;  // Maximum allowed consecutive losses


// Global counters for logging
int totalTrades = 0;
int totalBullishCrossovers = 0;
int totalBearishCrossovers = 0;
int skippedLowADX = 0;
int acceptedLowADX = 0;
int skippedTradeTypeOpen = 0;
int loggedOrders[];


// At the end of the backtest or trading session
void PrintSummary() {
    Print("Summary of Operations:");
    Print("Total Trades Executed: ", totalTrades);
    Print("Bullish Crossovers Detected: ", totalBullishCrossovers);
    Print("Bearish Crossovers Detected: ", totalBearishCrossovers);
    Print("Signals Skipped Due to Low ADX: ", skippedLowADX);
    Print("Signals Accepted Due to High ADX: ", acceptedLowADX);
    Print("Signals Skipped Due to Open Trade Type: ", skippedTradeTypeOpen);
}

void OnTick() {
    double emaFast = iMA(NULL, 0, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
    double emaSlow = iMA(NULL, 0, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
    double atrValue = iATR(NULL, 0, ATR_Period, 0);
    double adxValue = iADX(NULL, 0, ADX_Period, PRICE_CLOSE, MODE_MAIN, 0);
    double rsiValue = iRSI(NULL, 0, RSI_Period, PRICE_CLOSE, 0);
    double sl;
    double tp;
    for (int i = 0; i < OrdersHistoryTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
            if (OrderMagicNumber() == MagicNumber && OrderType() <= OP_SELL) {
                // Controlla se l'ordine è già stato loggato
                bool isAlreadyLogged = false;
                for (int j = 0; j < ArraySize(loggedOrders); j++) {
                    if (loggedOrders[j] == OrderTicket()) {
                        isAlreadyLogged = true;
                        break;
                    }
                }

                if (!isAlreadyLogged) {
                    // Logga l'ordine e aggiungilo alla lista degli ordini registrati
                    LogTradeToCSV("CLOSE", OrderType(), OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit(), OrderProfit());
                    ArrayResize(loggedOrders, ArraySize(loggedOrders) + 1);
                    loggedOrders[ArraySize(loggedOrders) - 1] = OrderTicket();
                }
            }
        }
    }
    if (consecutiveLosses >= MaxConsecutiveLosses) {
        skippedTradeTypeOpen++;
        return;
    }

    // Filter out low-trend conditions using ADX
    if (adxValue < ADX_Threshold) {
            skippedLowADX++; // Increment low ADX counter
            return;
    } else {
            acceptedLowADX++;
    } 
    
    // Check for bullish crossover
    if (emaFast > emaSlow && iMA(NULL, 0, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, 1) <= 
        iMA(NULL, 0, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, 1)) {
        if (CanTradeType(OP_BUY)) {
            sl = Ask - atrValue * ATR_Multiplier_SL;  // SL 1.5x ATR below entry
            tp = Ask + atrValue * ATR_Multiplier_TP; // TP 2x ATR above entry
            OpenTrade(OP_BUY, Ask, sl, tp);
            LogTradeToCSV("OPEN", OP_BUY, Ask, sl, tp, 0.0);
            totalTrades++;
        }
        totalBullishCrossovers++;
    }

    // Check for bearish crossover
    if (emaFast < emaSlow && iMA(NULL, 0, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, 1) >= 
        iMA(NULL, 0, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, 1)) {
            // Check ADX threshold
    if (adxValue < ADX_Threshold) {
        Print("Bearish crossover skipped: Low ADX (", adxValue, ")");
        skippedLowADX++;
        return;
    }

    // Check RSI overbought condition
    if (rsiValue <= 40) {
        Print("Bearish crossover skipped: RSI not overbought (", rsiValue, ")");
        return;
    }
     if (CanTradeType(OP_SELL)) {
         sl = Bid + atrValue * ATR_Multiplier_SL;  // SL 1.5x ATR above entry
         tp = Bid - atrValue * ATR_Multiplier_TP; // TP 2x ATR below entry
         OpenTrade(OP_SELL, Bid, sl, tp);
         LogTradeToCSV("OPEN", OP_SELL, Bid, sl, tp, 0.0);
         totalTrades++;
     }
     totalBearishCrossovers++;
    }
}


//void OnTick() {
//    // Calculate the current ATR, ADX, and RSI values
//    double atrValue = iATR(NULL, 0, ATR_Period, 0);
//    double adxValue = iADX(NULL, 0, ADX_Period, PRICE_CLOSE, MODE_MAIN, 0);
//    double rsiValue = iRSI(NULL, 0, RSI_Period, PRICE_CLOSE, 0);
//    double sl;
//    double tp;
//    // Dynamically adjust ATR and ADX periods
//    int atrPeriod, adxPeriod;
//    AdjustPeriodsDynamically(atrValue, adxValue, 0.001, 0.0005, 30, 20, atrPeriod, adxPeriod);
//
//    // Adjust EMA periods based on market conditions
//    int emaFastPeriod = DynamicEMAPeriod(atrValue, 0.001, 0.0005);
//    int emaSlowPeriod = AdjustEMAPeriodByTrend(adxValue, 30, 20);
//   
//
//    // Calculate EMA values
//    double emaFast = iMA(NULL, 0, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
//    double emaSlow = iMA(NULL, 0, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
//    //Print("EMA Fast: ", emaFast, " | EMA Slow: ", emaSlow, " | Fast Period: ", emaFastPeriod, " | Slow Period: ", emaSlowPeriod);
//    // Check if the EA should stop trading due to consecutive losses
//    if (consecutiveLosses >= MaxConsecutiveLosses) {
//        skippedTradeTypeOpen++;
//        return;
//    }
//
//    // Filter out low-trend conditions using ADX
//    if (adxValue < ADX_Threshold) {
//            skippedLowADX++; // Increment low ADX counter
//            return;
//    } else {
//            acceptedLowADX++;
//    } 
//
//    // Check for Bullish Crossover with RSI confirmation
//    if (emaFast > emaSlow && iMA(NULL, 0, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, 1) <= 
//        iMA(NULL, 0, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, 1) && rsiValue < 30) {
//        if (CanTradeType(OP_BUY)) {
//            sl = Ask - atrValue * 1.5;  // SL 1.5x ATR
//            tp = Ask + atrValue * 2.5; // TP 2.5x ATR
//            OpenTrade(OP_BUY, Ask, sl, tp);
//            totalTrades++;
//        }
//        totalBullishCrossovers++;
//    }
//
//    // Check for Bearish Crossover with RSI confirmation
//    if (emaFast < emaSlow && iMA(NULL, 0, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, 1) >= 
//        iMA(NULL, 0, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, 1) && rsiValue > 70) {
//        if (CanTradeType(OP_SELL)) {
//            sl = Bid + atrValue * ATR_Multiplier_SL;  // SL 1.5x ATR
//            tp = Bid - atrValue * ATR_Multiplier_TP; // TP 2.5x ATR
//            OpenTrade(OP_SELL, Bid, sl, tp);
//            totalTrades++;
//        }
//    }
//}

// Helper Functions

// Adjust periods dynamically
void AdjustPeriodsDynamically(double atrValue, double adxValue, double atrHigh, double atrLow, double adxStrong, double adxWeak, int &atrPeriod, int &adxPeriod) {
    // Adjust ATR Period
    atrPeriod = (atrValue > atrHigh) ? 10 : (atrValue < atrLow) ? 20 : 14;
    // Adjust ADX Period
    adxPeriod = (adxValue > adxStrong) ? 7 : (adxValue < adxWeak) ? 20 : 14;
}

int DynamicEMAPeriod(double atrValue, double highVolatilityThreshold, double lowVolatilityThreshold) {
    if (atrValue > highVolatilityThreshold) {
        return 5;  // Short period for high volatility
    } else if (atrValue < lowVolatilityThreshold) {
        return 10;  // Shorter period for low volatility to allow faster response
    } else {
        return 8;  // Moderate period for typical conditions
    }
}

int AdjustEMAPeriodByTrend(double adxValue, double strongTrendThreshold, double weakTrendThreshold) {
    if (adxValue > strongTrendThreshold) {
        return 10;  // Shorter period for strong trends
    } else if (adxValue < weakTrendThreshold) {
        return 14;  // Moderate period for weak trends to prevent over-smoothing
    } else {
        return 12;  // Balance for average trends
    }
}


// Validate if the trade type can be opened
bool CanTradeType(int orderType) {
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS) && OrderType() == orderType) {
            return false;  // Trade type already open
        }
    }
    return true;
}

// Open a trade
void OpenTrade(int orderType, double price, double sl, double tp) {
    int ticket = OrderSend(Symbol(), orderType, Lots, price, 3, sl, tp, "Refined Strategy", MagicNumber, 0, clrBlue);
    if (ticket < 0) {
        Print("Error opening trade: ", GetLastError());
        consecutiveLosses++;
    } else {
        Print("Trade opened: ", ticket);
        consecutiveLosses = 0;  // Reset consecutive losses on success
    }
}

void OnDeinit(const int reason) {
    // Print summary when backtest ends
    PrintSummary();
}


void LogTradeToCSV(string eventType, int orderType, double openPrice, double stopLoss, double takeProfit, double profitLoss) {
    double rsi = iRSI(NULL, 0, RSI_Period, PRICE_CLOSE, 0);
    double emaFast = iMA(NULL, 0, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
    double emaSlow = iMA(NULL, 0, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
    double adx = iADX(NULL, 0, ADX_Period, PRICE_CLOSE, MODE_MAIN, 0);
    string orderTypeStr = (orderType == OP_BUY) ? "BUY" : "SELL";
    // Apri il file in modalità append
    int fileHandle = FileOpen(TradeLogFileName, FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_WRITE, '|');
    if (fileHandle < 0) {
        Print("DEBUG: Error opening file: ", GetLastError());
        return;
    }

    // Scrivi i dati
    FileSeek(fileHandle, 0, SEEK_END); // Posizionati alla fine del file
    FileWrite(fileHandle,
              TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), // Timestamp
              eventType,                                           // Event type (OPEN o CLOSE)
              orderTypeStr,                                        // Order type
              openPrice,                                           // Open price
              stopLoss,                                            // Stop loss
              takeProfit,                                          // Take profit
              profitLoss,                                          // Profit/loss
              rsi,                                                 // RSI value
              emaFast,                                             // EMA Fast
              emaSlow,                                             // EMA Slow
              adx);                                                // ADX

    FileClose(fileHandle);
    Print("DEBUG: Trade data logged: ", eventType);
}