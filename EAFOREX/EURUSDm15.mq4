//+------------------------------------------------------------------+
//| Input dell'EA                                                   |
//+------------------------------------------------------------------+
input double Lots = 0.01;            // Lotto fisso
input double RiskRewardRatio = 3;  // Rapporto rischio/rendimento
input double StopLossPips = 20;    // Stop Loss in pips
input int MaxTradesPerDay = 3;     // Numero massimo di operazioni giornaliere
input int MagicNumber = 123456;    // Numero magico per identificare i trade
input int RSI_period = 14;
input double RSI_overbought = 65;   //Overbought Level
input double RSI_oversold = 35;   // Oversold Level
input double RSI_overbought_short = 55;
input double RSI_oversold_short = 40;
input int ATR_Period = 10;
input double ATR_Multiplier = 0.5;
input double atrMultiplierTP = 4.0; // TP basato su 2x ATR
input double atrMultiplierSL = 2.0; // SL basato su 1x ATR
input int EMA_Fast_Period = 10;              // Fast EMA period
input int EMA_Slow_Period = 20;              // Slow EMA period
input int ADX_Period = 14;            // Periodo dell'ADX
input double ADX_Threshold = 25.0;   // Soglia ADX per considerare un trend
// Variabili globali per il contatore dei trade
double dailyLoss = 0.0;        // Perdita accumulata giornalmente
double maxDailyLoss = 0.02;    // 2% del capitale iniziale come perdita massima giornaliera
int tradesToday = 0;               // Numero di operazioni aperte oggi
datetime lastTradeTime = 0;        // Tempo dell'ultima operazione
int cooldownPeriod = 3600;  // Cooldown period in seconds (e.g., 1 hour)
int lastLossTime = 0;

//+------------------------------------------------------------------+
//| Funzione OnInit                                                  |
//+------------------------------------------------------------------+
int OnInit() {
    Print("EA avviato con protezione da overtrading.");
    return(INIT_SUCCEEDED);
}



//+------------------------------------------------------------------+
//| Funzione OnTick                                                  |
//+------------------------------------------------------------------+
int currentDay = -1;        // Memorizza il giorno corrente (inizializzato a un valore invalido)

void OnTick() {
    double balance = AccountBalance();
    //if (Period() != PERIOD_M15) return;
    
    if (dailyLoss / balance >= maxDailyLoss) {
        Print("DEBUG - Perdita giornaliera massima raggiunta. Trading interrotto.");
        CloseAllPositions();
        return; // Stop ai trade per il giorno
    }
    datetime currentTime = TimeCurrent(); // Tempo corrente del server
    int today = TimeDay(currentTime);    // Giorno corrente

    // Verifica se il giorno è cambiato
    if (today != currentDay) {
        tradesToday = 0; // Resetta il contatore giornaliero
        currentDay = today; // Aggiorna il giorno corrente
        //Print("DEBUG - Contatore giornaliero resettato. Nuovo giorno: ", TimeToString(currentTime, TIME_DATE));
    }

    //Print("DEBUG - Ora corrente: ", TimeToString(currentTime, TIME_DATE | TIME_MINUTES));

    // Controllo del limite giornaliero
    if (tradesToday >= MaxTradesPerDay) {
        //Print("DEBUG - Limite giornaliero raggiunto: ", tradesToday, " / ", MaxTradesPerDay);
        return;
    }

    // Controllo temporale per evitare trade multipli troppo ravvicinati
    if (!CanTrade()) {
        Print("DEBUG - Attesa in corso per evitare trade multipli troppo ravvicinati.");
        return;
    }
   if (!IsTrendingMarket()) {
        Print("DEBUG - bassa volatilità per entrare a mercato.");
        return;
    }
   if (!IsMarketActive()) {
        Print("DEBUG - mercato in orario di poca attività.");
        return;
    }
    // Condizioni di ingresso LONG
    if (ShouldEnterLong()) {
        OpenPosition(OP_BUY);
    }

    // Condizioni di ingresso SHORT
    if (ShouldEnterShort()) {
        OpenPosition(OP_SELL);
    }
    //ApplyTrailingStop();
}



// Funzione per limitare il numero di operazioni ravvicinate
bool CanTrade() {
    int minInterval = 900; // Intervallo minimo tra trade in secondi (15 minuti)

    // Controlla se l'intervallo minimo è rispettato
    if (TimeCurrent() - lastTradeTime < minInterval) {
        return false; // Intervallo non rispettato
    }
    
    if (TimeCurrent() - lastLossTime < cooldownPeriod) {
        Print("DEBUG - Cooldown active. Last loss time: ", TimeToString(lastLossTime));
        return false;
    }

    return true; // È possibile fare trade
}
//+------------------------------------------------------------------+
//| Funzione per aprire una posizione                                |
//+------------------------------------------------------------------+
void OpenPosition(int orderType) {
    if (tradesToday >= MaxTradesPerDay) {
        //Print("DEBUG - Tentativo di apertura bloccato: Limite giornaliero raggiunto.");
        return;
    }

    double price = (orderType == OP_BUY) ? Ask : Bid;

    // Calcolo del Take Profit (TP) e Stop Loss (SL)
    double takeProfit = StopLossPips * Point * RiskRewardRatio;

    double sl = CalculateStopLoss(price, orderType, atrMultiplierSL);
    //double tp = CalculateTakeProfit(price, orderType, StopLossPips, RiskRewardRatio);
    double tp = CalculateDynamicTakeProfit(price, orderType, atrMultiplierTP); 
    // Validate SL and TP
    if (!ValidateStopLevel(price, sl, tp, orderType)) {
        Print("DEBUG - Livelli di SL/TP non validi. Ordine non inviato.");
        return;
    }
    // Invio dell'ordine
    int ticket = OrderSend(Symbol(), orderType, Lots, price, 3, sl, tp, "EA Migliorato", MagicNumber, 0, clrBlue);
    
    if (ticket < 0) {
        Print("Errore nell'apertura del trade: ", GetLastError());
    } else {
        //Print("Trade aperto con successo. Ticket: ", ticket, ", SL: ", sl, ", TP: ", tp);
        tradesToday++;
        lastTradeTime = TimeCurrent(); // Aggiorna il tempo dell'ultimo trade solo se riuscito
        //Print("DEBUG - Contatore aggiornato: tradesToday = ", tradesToday);
    }
}


//+------------------------------------------------------------------+
//| Condizioni di ingresso                                           |
//+------------------------------------------------------------------+


bool IsTradingSession() {
    datetime currentTime = TimeCurrent();
    int hour = TimeHour(currentTime);

    // Sessione di Londra (8:00-17:00) e New York (13:00-22:00)
    return (hour >= 8 && hour <= 17) || (hour >= 13 && hour <= 22);
}

double CalculateMarketRange(int bars) {
    double highest = High[iHighest(NULL, 0, MODE_HIGH, bars, 0)];
    double lowest = Low[iLowest(NULL, 0, MODE_LOW, bars, 0)];
    return highest - lowest;
}

//bool ShouldEnterLong() {
//    int emaSignal = EMA_Crossover_Signal(EMA_Fast_Period, EMA_Slow_Period);
//    int smaSignal = SMA_Crossover_Signal(EMA_Fast_Period, EMA_Slow_Period);
//    double adx = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MAIN, 0);
//    int rsi_confirm  = RSI_Confirmation(RSI_period, RSI_overbought, RSI_oversold, ATR_Period, ATR_Multiplier);
//    double macdMain = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
//    double macdSignal = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
//    double atr = iATR(NULL, 0, 14, 0);
//    double minRange = 0.0015; // 20 pips
//    double cci = iCCI(NULL, 0, 14, PRICE_CLOSE, 0);
//    double roc = CalculateROC(14);
//    Print("DEBUG LONG - EMA: ",  emaSignal, " SMA: ",  smaSignal, " RSI: ",  rsi_confirm);
//    
//    //return (
//    //    emaFast > emaSlow &&
//    //    adx > 20 &&
//    //    rsi > 30 && rsi < 70 &&
//    //    macdMain > macdSignal &&
//    //    atr > 0.0005 &&
//    //    IsTrendBullish() &&
//    //    IsMomentumStrong()
//    //);
//    //Print("DEBUG LONG - EMA Fast: ", emaFast, ", EMA Slow: ", emaSlow, ", ADX: ", adx, ", RSI: ", rsi, ", MACD Main: ", macdMain, ", MACD Signal: ", macdSignal, ", ATR: ", atr);
//
//    // Condizioni di ingresso LONG
//    return (
//        emaSignal == 1 &&                   // Incrocio medie mobili
//        smaSignal == 1 &&                   // Incrocio medie mobili
//        rsi_confirm == 1
//    );
//}
//
//
//bool ShouldEnterShort() {
//    int emaSignal = EMA_Crossover_Signal(EMA_Fast_Period, EMA_Slow_Period);
//    int smaSignal = SMA_Crossover_Signal(EMA_Fast_Period, EMA_Slow_Period);
//    double adx = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MAIN, 0);
//    int rsi_confirm  = RSI_Confirmation(RSI_period, RSI_overbought, RSI_oversold, ATR_Period, ATR_Multiplier);
//    double macdMain = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
//    double macdSignal = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
//    double atr = iATR(NULL, 0, 14, 0);
//    double minRange = 0.0015; // 20 pips
//    Print("DEBUG SHORT - EMA: ",  emaSignal, " SMA: ",  smaSignal, " RSI: ",  rsi_confirm);
//    //Print("DEBUG SHORT - EMA Fast: ", emaFast, ", EMA Slow: ", emaSlow, ", ADX: ", adx, ", RSI: ", rsi, ", MACD Main: ", macdMain, ", MACD Signal: ", macdSignal, ", ATR: ", atr);
//    double cci = iCCI(NULL, 0, 14, PRICE_CLOSE, 0);
//    double roc = CalculateROC(14); 
//    // return (
//    //    emaFast < emaSlow &&
//    //    adx > 20 &&
//    //    rsi > 30 && rsi < 70 &&
//    //    macdMain < macdSignal &&
//    //    atr > 0.0005 &&
//    //    IsTrendBearish() &&
//    //    IsMomentumStrong()
//    //);   
//    // Condizioni di ingresso SHORT
//    return (
//        emaSignal == 2 &&                      // Incrocio medie mobili
//        smaSignal == 2 &&                      // Incrocio medie mobili
//        rsi_confirm == 2
//    );
//}

//bool ShouldEnterLong() {
//    int emaSignal = EMA_Crossover_Signal(EMA_Fast_Period, EMA_Slow_Period);
//    int smaSignal = SMA_Crossover_Signal(EMA_Fast_Period, EMA_Slow_Period);
//    int rsiSignal = RSI_Confirmation(RSI_period, RSI_overbought, RSI_oversold, ATR_Period, ATR_Multiplier);
//    bool adxTrend = ADX_Trend(ADX_Period, ADX_Threshold);
//    int alignments = 0;
//
//    if (emaSignal == 1) alignments++;
//    if (smaSignal == 1) alignments++;
//    if (rsiSignal == 1) alignments++;
//
//    // Conferma multi-timeframe per RSI
//    if (alignments >= 1 && adxTrend && MultiTimeframeRSIConfirmation(RSI_period, RSI_overbought, RSI_oversold)) {
//        return true; // Condizioni soddisfatte per ingresso LONG
//    }
//
//    return false; // Nessuna condizione soddisfatta
//}
//
//bool ShouldEnterShort() {
//    int emaSignal = EMA_Crossover_Signal(EMA_Fast_Period, EMA_Slow_Period);
//    int smaSignal = SMA_Crossover_Signal(EMA_Fast_Period, EMA_Slow_Period);
//    int rsiSignal = RSI_Confirmation(RSI_period, RSI_overbought_short, RSI_oversold_short, ATR_Period, ATR_Multiplier);
//    bool adxTrend = ADX_Trend(ADX_Period, ADX_Threshold);
//    int alignments = 0;
//
//    if (emaSignal == 2) alignments++;
//    if (smaSignal == 2) alignments++;
//    if (rsiSignal == 2) alignments++;
//
//    // Conferma multi-timeframe per RSI
//    if (alignments >= 1 && adxTrend) {
//        return true; // Condizioni soddisfatte per ingresso SHORT
//    }
//
//    return false; // Nessuna condizione soddisfatta
//}


bool ShouldEnterLong() {
    int rsiSignal = RSI_Confirmation(RSI_period, RSI_overbought, RSI_oversold, ATR_Period, atrMultiplierTP);
    bool adxTrend = ADX_Trend(ADX_Period, ADX_Threshold);
    return rsiSignal == 1 && adxTrend; // RSI rialzista e conferma ADX
}

bool ShouldEnterShort() {
    int rsiSignal = RSI_Confirmation(RSI_period, RSI_overbought_short, RSI_oversold_short, ATR_Period, atrMultiplierSL);
    bool adxTrend = ADX_Trend(ADX_Period, ADX_Threshold);
    return rsiSignal == 2 && adxTrend  && IsStrongDowntrend(); // RSI ribassista e conferma ADX
}


bool ResistanceFilter() {
    double upperBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
    return Close[0] >= upperBand; // Prezzo vicino alla resistenza
}





int IsDivergence(double tolerance) {
    double rsiCurrent = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    double rsiPrevious = iRSI(NULL, 0, 14, PRICE_CLOSE, 1);
    double priceCurrent = Close[0];
    double pricePrevious = Close[1];

    // Divergenza rialzista con tolleranza
    if ((rsiCurrent > rsiPrevious + tolerance) && (priceCurrent < pricePrevious - tolerance)) {
        return 1; // Divergenza rialzista
    }

    // Divergenza ribassista con tolleranza
    if ((rsiCurrent < rsiPrevious - tolerance) && (priceCurrent > pricePrevious + tolerance)) {
        return -1; // Divergenza ribassista
    }

    return 0; // Nessuna divergenza
}




//+------------------------------------------------------------------+
//| Funzione per calcolare il livello di StopLevel                  |
//+------------------------------------------------------------------+
double CalculateStopLevel(double price, int orderType, double stopLossPips, double spread) {
    double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point; // Valore minimo richiesto dal broker
    double defaultStopLevel = 10 * Point; // StopLevel di default se il valore del broker non è valido

    // Validazione dello StopLevel
    if (stopLevel <= 0) {
        Print("StopLevel non valido fornito dal broker, utilizzo valore di default: ", defaultStopLevel);
        stopLevel = defaultStopLevel;
    }

    // Calcolo del livello di SL in base al tipo di ordine
    double calculatedSL = 0;
    if (orderType == OP_BUY) {
        calculatedSL = NormalizeDouble(price - stopLossPips * Point - spread, Digits);
        if ((price - calculatedSL) < stopLevel) {
            calculatedSL = NormalizeDouble(price - stopLevel, Digits);
        }
    } else if (orderType == OP_SELL) {
        calculatedSL = NormalizeDouble(price + stopLossPips * Point + spread, Digits);
        if ((calculatedSL - price) < stopLevel) {
            calculatedSL = NormalizeDouble(price + stopLevel, Digits);
        }
    }

    return calculatedSL;
}

//double CalculateStopLoss(double price, int orderType) {
//    double atr = iATR(NULL, 0, 14, 0); // Calcola l'ATR con periodo 14
//    double spread = MarketInfo(Symbol(), MODE_SPREAD) * Point; // Spread corrente
//    double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point; // Stop minimo richiesto dal broker
//    double calculatedSL = atr * 1.5; // Stop loss basato sull'ATR (moltiplicatore personalizzabile)
//
//    // Valida lo StopLevel rispetto al broker
//    if (stopLevel <= 0) {
//        Print("StopLevel non valido fornito dal broker, utilizzo valore di default.");
//        stopLevel = 10 * Point; // Default di 10 pips se il valore non è valido
//    }
//
//    // Calcola lo SL per ordine BUY o SELL
//    if (orderType == OP_BUY) {
//        calculatedSL = NormalizeDouble(price - calculatedSL - spread, Digits);
//        if ((price - calculatedSL) < stopLevel) {
//            calculatedSL = NormalizeDouble(price - stopLevel, Digits);
//        }
//    } else if (orderType == OP_SELL) {
//        calculatedSL = NormalizeDouble(price + calculatedSL + spread, Digits);
//        if ((calculatedSL - price) < stopLevel) {
//            calculatedSL = NormalizeDouble(price + stopLevel, Digits);
//        }
//    }
//
//    return calculatedSL;
//}

//double CalculateStopLoss(double price, int orderType) {
//    double atr = iATR(NULL, 0, 14, 0);
//    double spread = MarketInfo(Symbol(), MODE_SPREAD) * Point;
//    double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
//    double calculatedSL = atr * atrMultiplierSL;
//
//    // Validazione di ATR e StopLevel
//    if (atr <= 0) {
//        Print("ATR non valido, utilizzo valore predefinito.");
//        atr = 10 * Point;
//    }
//    if (stopLevel <= 0) {
//        Print("StopLevel non valido fornito dal broker, utilizzo valore di default.");
//        stopLevel = 10 * Point;
//    }
//
//    // Calcola lo SL per BUY e SELL
//    if (orderType == OP_BUY) {
//        calculatedSL = price - (calculatedSL + spread);
//        if ((price - calculatedSL) < stopLevel) {
//            calculatedSL = price - stopLevel;
//        }
//    } else if (orderType == OP_SELL) {
//        calculatedSL = price + (calculatedSL + spread);
//        if ((calculatedSL - price) < stopLevel) {
//            calculatedSL = price + stopLevel;
//        }
//    }
//
//    return NormalizeDouble(calculatedSL, Digits);
//}


bool IsTrendBullish() {
    double emaFastH4 = iMA(NULL, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    double emaSlowH4 = iMA(NULL, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
    return emaFastH4 > emaSlowH4;
}

bool IsTrendBearish() {
    double emaFastH4 = iMA(NULL, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    double emaSlowH4 = iMA(NULL, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
    return emaFastH4 < emaSlowH4;
}

// Dopo ogni chiusura trade
void OnTradeClose(int ticket, double profitLoss) {
    if (profitLoss < 0) {
        dailyLoss += MathAbs(profitLoss); // Add only losses to daily total
        lastLossTime  = TimeCurrent();    // Update cooldown timer
        Print("DEBUG - Loss recorded. Cooldown activated.");
    }
}


double CalculateTakeProfit(double price, int orderType, double stopLossPips, double riskRewardRatio) {
    double spread = MarketInfo(Symbol(), MODE_SPREAD) * Point; // Spread corrente
    double stopLoss = stopLossPips * Point; // Stop loss calcolato in punti
    double takeProfitDistance = stopLoss * riskRewardRatio; // Calcolo del TP basato sul RRR

    // Calcolo del livello di Take Profit
    double tp = 0.0;
    if (orderType == OP_BUY) {
        tp = NormalizeDouble(price + takeProfitDistance + spread, Digits);
    } else if (orderType == OP_SELL) {
        tp = NormalizeDouble(price - takeProfitDistance - spread, Digits);
    }

    Print("DEBUG - Take Profit calcolato: ", tp, ", RRR: ", riskRewardRatio, ", Spread: ", spread);
    return tp;
}

void CloseAllPositions() {
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderMagicNumber() == MagicNumber) {
            bool result = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 3, clrRed);
            if (result) {
                Print("DEBUG - Trade chiuso. Ticket: ", OrderTicket());
            } else {
                Print("Errore nella chiusura del trade: ", GetLastError());
            }
        }
    }
}

//double CalculateDynamicTakeProfit(double price, int orderType, double atrMultiplier) {
//    double atr = iATR(NULL, 0, 14, 0); // ATR corrente
//    double takeProfitDistance = atr * atrMultiplier; // Moltiplicatore dinamico basato sull'ATR
//
//    double tp = 0.0;
//    if (orderType == OP_BUY) {
//        tp = NormalizeDouble(price + takeProfitDistance, Digits);
//    } else if (orderType == OP_SELL) {
//        tp = NormalizeDouble(price - takeProfitDistance, Digits);
//    }
//
//    Print("DEBUG - Take Profit dinamico calcolato: ", tp, ", ATR: ", atr);
//    return tp;
//}


//double CalculateDynamicTakeProfit(double price, int orderType, double atrMultiplier) {
//    double atr = iATR(NULL, 0, 14, 0);
//    if (atr <= 0) {
//        Print("ATR non valido, utilizzo valore predefinito.");
//        atr = 10 * Point; // Default ATR
//    }
//
//    if (atrMultiplier <= 0) {
//        Print("Moltiplicatore ATR non valido, utilizzo valore predefinito.");
//        atrMultiplier = 1.0; // Default multiplier
//    }
//
//    double takeProfitDistance = atr * atrMultiplier;
//
//    // Calcola il TP per BUY e SELL
//    double tp = 0.0;
//    if (orderType == OP_BUY) {
//        tp = price + takeProfitDistance;
//    } else if (orderType == OP_SELL) {
//        tp = price - takeProfitDistance;
//    }
//
//    return NormalizeDouble(tp, Digits);
//}

double CalculateDynamicTakeProfit(double price, int orderType, double myAtrMultiplierTP) {
    double atr = iATR(NULL, 0, 14, 0);
    double takeProfitDistance = atr * myAtrMultiplierTP;
    return (orderType == OP_BUY) ? price + takeProfitDistance : price - takeProfitDistance;
}

double CalculateStopLoss(double price, int orderType, double myAtrMultiplierSL) {
    double atr = iATR(NULL, 0, 14, 0);
    double stopLossDistance = atr * myAtrMultiplierSL;
    return (orderType == OP_BUY) ? price - stopLossDistance : price + stopLossDistance;
}


void ApplyTrailingStop() {
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderMagicNumber() == MagicNumber) {
            double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point; // Minimum stop level required by broker
            double spread = MarketInfo(Symbol(), MODE_SPREAD) * Point;
            double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
            double newStopLoss = 0.0;

            // Calculate new stop loss
            if (OrderType() == OP_BUY) {
                newStopLoss = NormalizeDouble(currentPrice - 10 * Point, Digits);
                if ((currentPrice - newStopLoss) < stopLevel + spread) {
                    newStopLoss = NormalizeDouble(currentPrice - stopLevel - spread, Digits);
                }
            } else if (OrderType() == OP_SELL) {
                newStopLoss = NormalizeDouble(currentPrice + 10 * Point, Digits);
                if ((newStopLoss - currentPrice) < stopLevel + spread) {
                    newStopLoss = NormalizeDouble(currentPrice + stopLevel + spread, Digits);
                }
            }

            // Ensure new stop loss is valid and different from the current stop loss
            if (OrderStopLoss() != newStopLoss) {
                bool result = OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrBlue);
                if (!result) {
                    Print("Errore nell'aggiornamento del Trailing Stop: ", GetLastError(), " SL: ", newStopLoss);
                } else {
                    Print("Trailing Stop aggiornato. Nuovo SL: ", newStopLoss);
                }
            }
        }
    }
}


bool IsMomentumBullish() {
    double macdHist = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0) - 
                      iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
    return macdHist > 0;
}

bool IsMomentumBearish() {
    double macdHist = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0) - 
                      iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
    return macdHist < 0;
}

bool MomentumShortFilter() {
    double emaFast = iMA(NULL, 0, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
    double emaSlow = iMA(NULL, 0, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
    return (emaFast < emaSlow);
}


bool ValidateStopLevel(double price, double &stopLoss, double &takeProfit, int orderType) {
    double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
    double spread = MarketInfo(Symbol(), MODE_SPREAD) * Point;

    if (orderType == OP_BUY) {
        stopLoss = MathMax(stopLoss, price - stopLevel - spread);
        takeProfit = MathMax(takeProfit, price + stopLevel);
    } else if (orderType == OP_SELL) {
        stopLoss = MathMin(stopLoss, price + stopLevel + spread);
        takeProfit = MathMin(takeProfit, price - stopLevel);
    }

    return true;
}

bool IsVolatilitySufficient() {
    double atr = iATR(NULL, 0, 14, 0);
    double averageATR = 0.0;
    for (int i = 0; i < 10; i++) {
        averageATR += iATR(NULL, 0, 14, i);
    }
    averageATR /= 10; // Media degli ultimi 10 valori ATR
    return atr > averageATR * 0.8; // Volatilità sufficiente
}

bool IsHigherTimeframeBullish() {
    double emaFast = iMA(NULL, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    double emaSlow = iMA(NULL, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
    return emaFast > emaSlow; // Trend rialzista su H4
}

bool IsHigherTimeframeBearish() {
    double emaFast = iMA(NULL, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    double emaSlow = iMA(NULL, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
    return emaFast < emaSlow; // Trend ribassista su H4
}

bool IsVolumeSufficient() {
    double volume = iVolume(NULL, 0, 0); // Current bar volume
    return volume > 1000; // Example threshold
}

bool IsRangeSufficient(double minRange) {
    double range = High[iHighest(NULL, 0, MODE_HIGH, 20, 0)] - Low[iLowest(NULL, 0, MODE_LOW, 20, 0)];
    return range > minRange;
}


bool IsBollingerBreakout(bool isLong) {
    double upperBand = iBands(NULL, 0, 20, 2.0, 0, PRICE_CLOSE, MODE_UPPER, 0);
    double lowerBand = iBands(NULL, 0, 20, 2.0, 0, PRICE_CLOSE, MODE_LOWER, 0);
    double closePrice = Close[0];

    if (isLong) {
        return closePrice > upperBand; // Breakout rialzista
    } else {
        return closePrice < lowerBand; // Breakout ribassista
    }
}

double CalculateROC(int period) {
    double previousPrice = iClose(NULL, 0, period);
    double currentPrice = Close[0];
    return ((currentPrice - previousPrice) / previousPrice) * 100; // Percentuale di variazione
}


bool IsPriceInBollingerRange() {
    double upperBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
    double lowerBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
    double closePrice = iClose(NULL, 0, 0);
    return (closePrice > lowerBand && closePrice < upperBand); // Controlla se il prezzo è all'interno delle bande
}


bool IsMomentumStrong() {
    double roc = CalculateROC(14); // Calcolo ROC con un periodo di 14
    return roc > 0.5; // Filtra solo movimenti con forza sufficiente
}

void OnTradeStopLoss() {
    lastLossTime = TimeCurrent(); // Aggiorna il tempo dell'ultimo Stop Loss
}

// Funzione RSI_Confirmation
int RSI_Confirmation(int rsiPeriod, double baseOverbought, double baseOversold, int atrPeriod, double atrMultiplier) {
    // Calcolo del valore RSI corrente e precedente
    double rsiValue = iRSI(NULL, 0, rsiPeriod, PRICE_CLOSE, 0);
    double rsiPrevValue = iRSI(NULL, 0, rsiPeriod, PRICE_CLOSE, 1);

    // Calcolo dell'ATR corrente
    double atrValue = iATR(NULL, 0, atrPeriod, 0);

    // Adattamento dei livelli RSI in base alla volatilità
    double adjustedOverbought = baseOverbought + (atrValue * atrMultiplier);
    double adjustedOversold = baseOversold - (atrValue * atrMultiplier);

    // Limitare i valori per evitare distorsioni
    adjustedOverbought = MathMin(adjustedOverbought, 90); // Livello massimo di ipercomprato
    adjustedOversold = MathMax(adjustedOversold, 10);     // Livello minimo di ipervenduto

    // Segnale rialzista (RSI in ipervenduto adattato e in aumento)
    if (rsiPrevValue < adjustedOversold && rsiValue > rsiPrevValue) {
        return 1; // Segnale rialzista
    }

    // Segnale ribassista (RSI in ipercomprato adattato e in diminuzione)
    if (rsiPrevValue > adjustedOverbought && rsiValue < rsiPrevValue) {
        return 2; // Segnale ribassista
    }

    // Nessun segnale valido
    return 0;
}

int SMA_Crossover_Signal(int fastPeriod, int slowPeriod) {
    // Calcolo delle SMA
    double smaFastPrev = iMA(NULL, 0, fastPeriod, 0, MODE_SMA, PRICE_CLOSE, 1); // SMA veloce (precedente)
    double smaSlowPrev = iMA(NULL, 0, slowPeriod, 0, MODE_SMA, PRICE_CLOSE, 1); // SMA lenta (precedente)
    double smaFastCurr = iMA(NULL, 0, fastPeriod, 0, MODE_SMA, PRICE_CLOSE, 0); // SMA veloce (corrente)
    double smaSlowCurr = iMA(NULL, 0, slowPeriod, 0, MODE_SMA, PRICE_CLOSE, 0); // SMA lenta (corrente)

    // Segnale rialzista: SMA veloce incrocia verso l'alto la SMA lenta
    if (smaFastPrev <= smaSlowPrev && smaFastCurr > smaSlowCurr) {
        return 1; // Segnale rialzista
    }

    // Segnale ribassista: SMA veloce incrocia verso il basso la SMA lenta
    if (smaFastPrev >= smaSlowPrev && smaFastCurr < smaSlowCurr) {
        return 2; // Segnale ribassista
    }

    // Nessun segnale
    return 0;
}

int EMA_Crossover_Signal(int fastPeriod, int slowPeriod) {
    // Calcolo delle EMA
    double emaFastPrev = iMA(NULL, 0, fastPeriod, 0, MODE_EMA, PRICE_CLOSE, 1); // EMA veloce (precedente)
    double emaSlowPrev = iMA(NULL, 0, slowPeriod, 0, MODE_EMA, PRICE_CLOSE, 1); // EMA lenta (precedente)
    double emaFastCurr = iMA(NULL, 0, fastPeriod, 0, MODE_EMA, PRICE_CLOSE, 0); // EMA veloce (corrente)
    double emaSlowCurr = iMA(NULL, 0, slowPeriod, 0, MODE_EMA, PRICE_CLOSE, 0); // EMA lenta (corrente)

    // Segnale rialzista: EMA veloce incrocia verso l'alto la EMA lenta
    if (emaFastPrev <= emaSlowPrev && emaFastCurr > emaSlowCurr) {
        return 1; // Segnale rialzista
    }

    // Segnale ribassista: EMA veloce incrocia verso il basso la EMA lenta
    if (emaFastPrev >= emaSlowPrev && emaFastCurr < emaSlowCurr) {
        return 2; // Segnale ribassista
    }

    // Nessun segnale
    return 0;
}

// Funzione ADX_Trend
bool ADX_Trend(int adxPeriod, double adxThreshold) {
    double adxValue = iADX(NULL, 0, adxPeriod, PRICE_CLOSE, MODE_MAIN, 0); // Valore ADX corrente
    return adxValue >= adxThreshold; // Ritorna true se l'ADX è sopra la soglia
}

bool ADX_LongTrend(int adxPeriod, double adxThreshold) {
    double adxValue = iADX(NULL, 0, adxPeriod, PRICE_CLOSE, MODE_MAIN, 0); // Valore ADX
    double diPlus = iADX(NULL, 0, adxPeriod, PRICE_CLOSE, MODE_PLUSDI, 0); // Valore +DI
    double diMinus = iADX(NULL, 0, adxPeriod, PRICE_CLOSE, MODE_MINUSDI, 0); // Valore -DI

    // Condizioni per trend long
    return (adxValue >= adxThreshold && diPlus > diMinus);
}

bool ADX_ShortTrend(int adxPeriod, double adxThreshold) {
    double adxValue = iADX(NULL, 0, adxPeriod, PRICE_CLOSE, MODE_MAIN, 0); // Valore ADX
    double diPlus = iADX(NULL, 0, adxPeriod, PRICE_CLOSE, MODE_PLUSDI, 0); // Valore +DI
    double diMinus = iADX(NULL, 0, adxPeriod, PRICE_CLOSE, MODE_MINUSDI, 0); // Valore -DI

    // Condizioni per trend short
    return (adxValue >= adxThreshold && diMinus > diPlus);
}

bool MultiTimeframeConfirmation() {
    double emaFastM15 = iMA(NULL, PERIOD_M15, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
    double emaSlowM15 = iMA(NULL, PERIOD_M15, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, 0);

    // Conferma ribassista su timeframe M15
    return emaFastM15 < emaSlowM15;
}

bool BollingerResistanceFilter() {
    double upperBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0); // Banda superiore
    double price = Close[0];

    // Verifica se il prezzo è vicino alla resistenza dinamica
    return price >= upperBand;
}

bool DivergenceRSI() {
    double rsiCurrent = iRSI(NULL, 0, RSI_period, PRICE_CLOSE, 0); // RSI corrente
    double rsiPrev = iRSI(NULL, 0, RSI_period, PRICE_CLOSE, 1);    // RSI precedente
    double priceCurrent = Close[0];
    double pricePrev = Close[1];

    // Controllo per divergenza ribassista
    return (priceCurrent > pricePrev) && (rsiCurrent < rsiPrev);
}

bool VolumeFilter() {
    double volumeCurrent = Volume[0];
    double volumePrev = Volume[1];

    // Condizione: volume in aumento rispetto alla candela precedente
    return volumeCurrent > volumePrev;
}

double CalculateResistance(int lookbackPeriod) {
    double resistance = High[0]; // Inizializza al valore attuale del massimo

    for (int i = 1; i <= lookbackPeriod; i++) {
        if (High[i] > resistance) {
            resistance = High[i]; // Aggiorna il massimo
        }
    }

    return resistance; // Restituisce il massimo come livello di resistenza
}

bool MomentumFilterM15() {
    double emaFast = iMA(NULL, PERIOD_M15, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
    double emaSlow = iMA(NULL, PERIOD_M15, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
    return emaFast < emaSlow;
}


double CalculateATRMultiplier(double atrValue) {
    if (atrValue > MarketInfo(Symbol(), MODE_POINT) * 50) { // Alta volatilità
        return 0.7; // Incrementa il moltiplicatore
    }
    return 0.5; // Valore predefinito
}

bool MultiTimeframeRSIConfirmation(int rsiPeriod, double baseOverbought, double baseOversold) {
    double rsiH4 = iRSI(NULL, PERIOD_H4, rsiPeriod, PRICE_CLOSE, 0); // RSI su H4
    return rsiH4 < baseOversold || rsiH4 > baseOverbought; // Conferma da timeframe superiore
}

bool IsTrendingMarket() {
    double adx = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MAIN, 0);
    return adx > 25; // Trend confermato solo se ADX > 25
}

bool IsStrongDowntrend() {
    double adx = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MAIN, 0);
    double diMinus = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MINUSDI, 0);
    return adx > 25 && diMinus > 20; // Conferma short con ADX e DI-
}

bool IsMarketActive() {
    int hour = TimeHour(TimeCurrent());
    return (hour >= 8 && hour <= 20); // Operazioni solo in orari attivi
}

bool BollingerFilterShort(double bufferPips) {
    double upperBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0); // Banda superiore
    double price = Close[0];
    double buffer = bufferPips * MarketInfo(Symbol(), MODE_POINT); // Converti i pips in unità di prezzo
    return (price >= upperBand - buffer); // Prezzo vicino alla banda superiore
}
