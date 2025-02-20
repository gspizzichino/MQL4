//+------------------------------------------------------------------+
//|                                                       H1EUST.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.01"
#property strict

// Input Parameters
input ENUM_TIMEFRAMES HigherTF = PERIOD_H4;     // Timeframe superiore
input ENUM_TIMEFRAMES MediumTF = PERIOD_H1;    // Timeframe medio
input ENUM_TIMEFRAMES LowerTF = PERIOD_M5;    // Timeframe inferiore
input int sma_PeriodHigherTF = 200;            // SMA per trend principale
input int ema_PeriodMediumTF = 21;             // EMA per movimento intermedio
input int ema_FastLowerTFPeriod = 5;          // EMA veloce per ingresso
input int ema_SlowLowerTFPeriod = 10;          // EMA lenta per ingresso
input int fastEMAPeriod = 12;    // Periodo della EMA veloce
input int slowEMAPeriod = 26;    // Periodo della EMA lenta
input int signalPeriod = 9;      // Periodo della linea di segnale
input int rsi_PeriodLowerTF = 14;              // RSI per conferma
input double Lots = 0.01;                      // Lotto fisso
input int MagicNumber = 123456;                // Identificatore unico
input double ATR_Multiplier_TP = 4.0;          // TP basato su ATR
input double ATR_Multiplier_SL = 1.5;          // SL basato su ATR
input int ATR_Period = 14;                     // Periodo ATR
input double BaseThreshold = 10;        // Base threshold (e.g., 10 pips)
input double LowFactor = 0.75;          // Adjustment factor for low volatility
input double HighFactor = 1.25;         // Adjustment factor for high volatility
input double LowVolatilityLevel = 0.001; // Low volatility level
input double HighVolatilityLevel = 0.002; // High volatility level
input int ADX_Period = 14;                     // Periodo ADX
input int MaxConsecutiveLosses = 3;            // Perdite consecutive max
input int maxOpenTrades = 1;                   // Max trade aperti
input int bollingerPeriod = 14;                // Bollinger Bands periodo
input double bollingerDeviation = 2.0;         // Bollinger Bands deviazioni
input double ADX_Threshold = 25.0;   // Soglia ADX per considerare un trend
input double rsi_BullishThreshold = 55; // Soglia rialzista RSI
input double rsi_LowerThreshold = 30;  // Soglia di ipervenduto (rialzista)
input double rsi_BearishThreshold = 45; // Soglia ribassista RSI
input double rsi_UpperThreshold = 70;  // Soglia di ipercomprato (ribassista)
input int rsi_Period = 14;
input int startTradingHour = 8;
input int endTradingHour = 20;
input int volume_period = 20;
input double riskPercentage = 5.0; // Percentuale di rischio per operazione

// Global Variables
datetime lastSignalTime = 0;                   // Ultimo segnale
int lastSignalType = -1;                       // Tipo di segnale
int consecutiveLosses = 0;                     // Contatore perdite

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("EA Initialized: H1EUST.mq4");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("EA Deinitialized.");
  }

//+------------------------------------------------------------------+
//| Funzione di logging                                              |
//+------------------------------------------------------------------+
void Log(string message)
  {
   Print("H1EUST.mq4: ", message);
  }

//+------------------------------------------------------------------+
//| Funzioni di supporto                                             |
//+------------------------------------------------------------------+
// Verifica il trend principale
bool IsUptrendHigherTF(double currentPrice, double sma)
  {
   return currentPrice > sma;
  }

bool IsDowntrendHigherTF(double currentPrice, double sma)
  {
   return currentPrice < sma;
  }

// Conta i trade aperti
int CountOpenTrades(int orderType)
  {
   int count = 0;
   for (int i = 0; i < OrdersTotal(); i++)
     {
      if (OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         if (OrderType() == orderType) count++;
     }
   return count;
  }

// Calcola SL e TP
double CalculateSL(int orderType, double entryPrice, double atrValue)
  {
   return orderType == OP_BUY ? NormalizeDouble(entryPrice - atrValue * ATR_Multiplier_SL, Digits) : NormalizeDouble(entryPrice + atrValue * ATR_Multiplier_SL, Digits);
  }

double CalculateTP(int orderType, double entryPrice, double atrValue)
  {
   return orderType == OP_BUY ? NormalizeDouble(entryPrice + atrValue * ATR_Multiplier_TP, Digits) : NormalizeDouble(entryPrice - atrValue * ATR_Multiplier_TP, Digits);
  }



int CalculateMACDSignal() {
    // Definizione degli array per il calcolo della linea MACD e della linea di segnale
    double macdArray[100] = {0};  // Array per memorizzare i valori del MACD
    double signalArray[100] = {0};  // Array per memorizzare i valori della linea di segnale

    // Popola l'array del MACD con i valori storici
    for (int i = 0; i < 100; i++) {
        double emaFast = iMA(NULL, PERIOD_H1, fastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, i);
        double emaSlow = iMA(NULL, PERIOD_H1, slowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, i);
        macdArray[i] = emaFast - emaSlow;
    }

    // Calcola la linea di segnale come EMA dell'array della linea MACD
    for (int i = 0; i < 100; i++) {
        signalArray[i] = iMAOnArray(macdArray, 0, signalPeriod, 0, MODE_EMA, i);
    }

    // Ottieni i valori più recenti del MACD e della linea di segnale
    double macdLine = macdArray[0];
    double signalLine = signalArray[0];

    // Ottieni i valori precedenti del MACD e della linea di segnale per verificare l'incrocio
    double previousMACD = macdArray[1];
    double previousSignal = signalArray[1];

    // Segnale di acquisto (long) se la linea MACD incrocia la linea di segnale dal basso verso l'alto
    if (macdLine > signalLine && previousMACD <= previousSignal) {
        Print("Segnale LONG MACD confermato in  H1.");
        return 0;  // Segnale LONG
    }

    // Segnale di vendita (short) se la linea MACD incrocia la linea di segnale dall'alto verso il basso
    if (macdLine < signalLine && previousMACD >= previousSignal) {
        Print("Segnale SHORT MACD confermato in  H1.");
        return 1;  // Segnale SHORT
    }

    // Nessun segnale identificato
    return -1;
}

//+------------------------------------------------------------------+
//| Analisi multi-timeframe                                          |
//+------------------------------------------------------------------+
int FindMultiTimeFrameSignals()
  {
   double smaHigherTF = iMA(NULL, HigherTF, sma_PeriodHigherTF, 0, MODE_SMA, PRICE_CLOSE, 0);
   double emaMediumTF = iMA(NULL, MediumTF, ema_PeriodMediumTF, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaFastLowerTF = iMA(NULL, LowerTF, ema_FastLowerTFPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaSlowLowerTF = iMA(NULL, LowerTF, ema_SlowLowerTFPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double rsiLowerTF = iRSI(NULL, LowerTF, rsi_PeriodLowerTF, PRICE_CLOSE, 0);
   double currentPriceHigherTF = iClose(NULL, HigherTF, 0);
   double currentPriceMediumTF = iClose(NULL, MediumTF, 0);
   double spread = MarketInfo(Symbol(), MODE_SPREAD) * Point;
   if (smaHigherTF == EMPTY_VALUE || emaMediumTF == EMPTY_VALUE)
     {
      Log("Errore nel calcolo degli indicatori.");
      return -1;
     }

   bool isUptrend = IsUptrendHigherTF(currentPriceHigherTF + spread, smaHigherTF);
   bool isDowntrend = IsDowntrendHigherTF(currentPriceHigherTF, smaHigherTF);

   if (isUptrend && currentPriceMediumTF > emaMediumTF && emaFastLowerTF > emaSlowLowerTF && rsiLowerTF < 70)
      return 0; // Long

   if (isDowntrend && currentPriceMediumTF < emaMediumTF && emaFastLowerTF < emaSlowLowerTF && rsiLowerTF > 30)
      return 1; // Short

   return -1; // Nessun segnale
  }


//+------------------------------------------------------------------+
//| Conferma del trend con le Bollinger Bands                       |
//+------------------------------------------------------------------+
int ConfirmTrendWithBollingerBands(ENUM_TIMEFRAMES timeframe1, ENUM_TIMEFRAMES timeframe2, int _bollingerPeriod, double _bollingerDeviation)
  {
   double upperBand1 = iBands(NULL, timeframe1, _bollingerPeriod, _bollingerDeviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
   double lowerBand1 = iBands(NULL, timeframe1, _bollingerPeriod, _bollingerDeviation, 0, PRICE_CLOSE, MODE_LOWER, 0);
   double currentPrice1 = iClose(NULL, timeframe1, 0);

   double upperBand2 = iBands(NULL, timeframe2, _bollingerPeriod, _bollingerDeviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
   double lowerBand2 = iBands(NULL, timeframe2, _bollingerPeriod, _bollingerDeviation, 0, PRICE_CLOSE, MODE_LOWER, 0);
   double currentPrice2 = iClose(NULL, timeframe2, 0);

   // Validazione dei valori
   if (upperBand1 == EMPTY_VALUE || lowerBand1 == EMPTY_VALUE || upperBand2 == EMPTY_VALUE || lowerBand2 == EMPTY_VALUE)
     {
      Log("Errore nel calcolo delle Bollinger Bands.");
      return -1;
     }

   // Conferma del trend rialzista
   if (currentPrice1 >= upperBand1 && currentPrice2 >= upperBand2)
     {
      Log("Trend rialzista confermato dalle Bollinger Bands.");
      return 0; // Trend rialzista
     }

   // Conferma del trend ribassista
   if (currentPrice1 <= lowerBand1 && currentPrice2 <= lowerBand2)
     {
      Log("Trend ribassista confermato dalle Bollinger Bands.");
      return 1; // Trend ribassista
     }

   Log("Nessun trend confermato dalle Bollinger Bands.");
   return -1; // Nessuna conferma
  }


//+------------------------------------------------------------------+
//| Funzione principale di trading                                   |
//+------------------------------------------------------------------+
void OnTick()
  {
   double atrValue = iATR(NULL, 0, ATR_Period, 0);
   if (atrValue == EMPTY_VALUE) return;
   //CheckClosedTrades();
   if (consecutiveLosses >= MaxConsecutiveLosses)
     {
      Log("Numero massimo di perdite consecutive raggiunto.");
      return;
     }
   
   if (!IsWithinTradingHours(startTradingHour, endTradingHour)) {
      //Log("Orario di basso volume.");
      return;
   }

   // Conferma del trend con le Bollinger Bands
   //int trendConfirmation = ConfirmTrendWithBollingerBands(MediumTF, HigherTF, bollingerPeriod, bollingerDeviation);

   // Trova segnali multi-time frame
   int signal = FindMultiTimeFrameSignals();
   int rsiSignal = FindRSISignals();
   bool adxTrendLong, adxTrendShort;
   adxTrendLong = ADX_LongTrend(ADX_Period, ADX_Threshold);
   adxTrendShort = ADX_ShortTrend(ADX_Period, ADX_Threshold);
   //int macdSignal = CalculateMACDSignal();
   // Verifica la validità del segnale e della conferma del trend
   if (signal != -1 && (TimeCurrent() - lastSignalTime > 60 || signal != lastSignalType))
     {
      double sl, tp;
      if (signal == 0 && adxTrendLong && rsiSignal ==0 && CountOpenTrades(OP_BUY) < maxOpenTrades && IsValidATR() && IsVolumeSignificant(PERIOD_H1, volume_period))
        {
         sl = Ask - atrValue * ATR_Multiplier_SL;  // SL 1.5x ATR below entry
         tp = Ask + atrValue * ATR_Multiplier_TP; // TP 2x ATR above entry
         OpenTrade(OP_BUY, Ask, sl, tp);
        }
      else if (signal == 1 && adxTrendShort && rsiSignal ==1 && CountOpenTrades(OP_SELL) < maxOpenTrades && IsValidATR()  && IsVolumeSignificant(PERIOD_H1, volume_period) /*&& IsBearishDivergence(Bid, 1)*/)
        {
         sl = Bid + atrValue * ATR_Multiplier_SL;  // SL 1.5x ATR above entry
         tp = Bid - atrValue * ATR_Multiplier_TP; // TP 2x ATR below entry
         OpenTrade(OP_SELL, Bid, sl, tp);
        }
      lastSignalTime = TimeCurrent();
      lastSignalType = signal;
     }
  }

bool IsWithinTradingHours(int startHour, int endHour)
  {
   int currentHour = TimeHour(TimeCurrent());

   if (currentHour >= startHour && currentHour <= endHour)
     {
      return true;
     }

   //Print("Fuori dall'orario di trading.");
   return false;
  }
  
  
//+------------------------------------------------------------------+
//| Apertura ordini                                                  |
//+------------------------------------------------------------------+
void OpenTrade(int orderType, double price, double sl, double tp)
  {
   double myLots = CalculateLotSize(sl);
   //int ticket = OrderSend(Symbol(), orderType, Lots, price, 3, sl, tp, "H1EUST Strategy", MagicNumber, 0, clrBlue);
   int ticket = OrderSend(Symbol(), orderType, myLots, price, 3, sl, tp, "H1EUST Strategy", MagicNumber, 0, clrBlue);
   if (ticket < 0)
     {
      Log("Errore apertura ordine: " + IntegerToString(GetLastError()));
      consecutiveLosses++;
     }
   else
     {
      Log("Trade aperto: " + IntegerToString(ticket));
      consecutiveLosses = 0;
     }
  }
  
  
  
void CheckClosedTrades()
  {
   for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
        {
         // Se l'ordine è chiuso, controlla il risultato
         if (OrderCloseTime() > lastSignalTime) // Solo ordini chiusi dopo l'ultimo segnale
           {
            if (OrderProfit() < 0) // Ordine chiuso in perdita
              {
               consecutiveLosses++;
               Log("Ordine chiuso in perdita. Consecutive losses: " + IntegerToString(consecutiveLosses));
              }
            else // Ordine chiuso in profitto
              {
               consecutiveLosses = 0; // Resetta se c'è un profitto
               Log("Ordine chiuso in profitto. Consecutive losses resettate.");
              }
           }
        }
     }
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


bool IsBearishRSI(int timeframe)
  {
   double rsiValue = iRSI(NULL, timeframe, rsi_Period, PRICE_CLOSE, 0);

   // Controlla che il valore RSI sia disponibile
   if (rsiValue == EMPTY_VALUE)
     {
      Print("Errore nel calcolo dell'RSI per timeframe: ", timeframe);
      return false;
     }

   // Condizioni per un segnale ribassista
   if (rsiValue < rsi_BearishThreshold) // Sotto la soglia ribassista
     {
      return true;
     }

   // Ritorno da ipercomprato
   if (rsiValue > rsi_UpperThreshold) // Sopra la soglia di ipercomprato
     {
      return true;
     }

   return false; // Nessuna condizione ribassista
  }




bool IsBullishRSI(int timeframe1, int timeframe2)
{
   // Calcolo RSI sul timeframe corrente
   double currentRsiValue = iRSI(NULL, timeframe1, rsi_Period, PRICE_CLOSE, 0);

   // Controlla che il valore RSI sia disponibile per il timeframe corrente
   if (currentRsiValue == EMPTY_VALUE)
   {
      Print("Errore nel calcolo dell'RSI per timeframe corrente: ", timeframe1);
      return false;
   }

   // Calcolo RSI sul timeframe maggiore
   double higherRsiValue = iRSI(NULL, timeframe2, rsi_Period, PRICE_CLOSE, 0);

   // Controlla che il valore RSI sia disponibile per il timeframe maggiore
   if (higherRsiValue == EMPTY_VALUE)
   {
      Print("Errore nel calcolo dell'RSI per timeframe maggiore: ", timeframe2);
      return false;
   }

   // Logica per segnale rialzista
   // Entrambi i timeframe devono soddisfare le condizioni
   if (currentRsiValue > rsi_BullishThreshold && higherRsiValue > rsi_BullishThreshold)
   {
      return true; // Conferma rialzista
   }

   // Rimbalzo da ipervenduto
   if (currentRsiValue < rsi_LowerThreshold && higherRsiValue > rsi_BullishThreshold)
   {
      return true; // Rimbalzo rialzista con conferma dal timeframe maggiore
   }

   return false; // Nessuna condizione rialzista
}

int FindRSISignals()
  {
   // Verifica condizioni rialziste
   if (IsBullishRSI(PERIOD_H1, PERIOD_H4))
     {
      //Print("RSI indica segnale rialzista.");
      return 0; // Segnale LONG
     }

   // Verifica condizioni ribassiste
   if (IsBearishRSI(PERIOD_H4) && IsBearishRSI(PERIOD_M15))
     {
      //Print("RSI indica segnale ribassista.");
      return 1; // Segnale SHORT
     }

   return -1; // Nessun segnale rilevato
  }

bool IsVolumeSignificant(ENUM_TIMEFRAMES timeframe, int volumePeriod)
  {
   // Ottieni il volume corrente
   double currentVolume = (double)iVolume(NULL, timeframe, 0);

   // Calcola la media mobile del volume
   double avgVolume = 0.0;
   for (int i = 0; i < volumePeriod; i++)
     {
      avgVolume += (double)iVolume(NULL, timeframe, i);
     }
   avgVolume /= volumePeriod;

   // Verifica se il volume corrente supera la media mobile
   if (currentVolume > avgVolume)
     {
      return true;
     }

   Print("Volume insufficiente: ", currentVolume, " vs media: ", avgVolume);
   return false;
  }


bool IsValidATR()
  {
    double atrValue = GetATR(ATR_Period);
  // Calculate adaptive threshold
    double adaptiveThreshold = CalculateAdaptiveThreshold(BaseThreshold, atrValue, LowFactor, HighFactor, LowVolatilityLevel, HighVolatilityLevel);
    double priceDifference = NormalizeDouble(MathAbs(Bid - iClose(NULL, 0, 1)), Digits); // Difference from the last close
    double thresholdInPrice = adaptiveThreshold * Point;
    // Use adaptiveThreshold for trading logic
    //Print("Current ATR: ", atrValue, " Adaptive Threshold: ", adaptiveThreshold, " Price Difference: ", priceDifference, "priceDifference > adaptiveThreshold" );

    // Example: Trade entry condition using adaptive threshold
   
    if (priceDifference > thresholdInPrice) {
      Print("ATR Valido");
      Print("Current ATR: ", atrValue, " Adaptive Threshold: ", adaptiveThreshold, " Price Difference: ", priceDifference, "priceDifference > adaptiveThreshold" );
      return true;
    } else {
      return false;
    }
    
  }

double GetATR(int atrPeriod) {
    return iATR(NULL, 0, atrPeriod, 0); // NULL for current symbol, 0 for current timeframe
}

double CalculateAdaptiveThreshold(double baseThreshold, double atrValue, double lowFactor, double highFactor, double lowLevel, double highLevel) {
    if (atrValue < lowLevel) {
        return baseThreshold * lowFactor; // Tighten threshold
    } else if (atrValue > highLevel) {
        return baseThreshold * highFactor; // Widen threshold
    }
    return baseThreshold; // Normal threshold
}

bool IsBullishDivergence(double currentPrice, int lookback)
{
   double currentRSI = iRSI(NULL, NULL, rsi_Period, PRICE_CLOSE, 0);
   double rsiPrev = iRSI(NULL, LowerTF, rsi_PeriodLowerTF, PRICE_CLOSE, lookback);
   double pricePrev = iClose(NULL, LowerTF, lookback);

   // Controlla se il prezzo è in aumento mentre l'RSI è in calo
   return (currentPrice > pricePrev && currentRSI < rsiPrev);
}

bool IsBearishDivergence(double currentPrice, int lookback)
{
   double currentRSI = iRSI(NULL, NULL, rsi_Period, PRICE_CLOSE, 0);
   double rsiPrev = iRSI(NULL, LowerTF, rsi_PeriodLowerTF, PRICE_CLOSE, lookback);
   double pricePrev = iClose(NULL, LowerTF, lookback);

   // Controlla se il prezzo è in calo mentre l'RSI è in aumento
   return (currentPrice < pricePrev && currentRSI > rsiPrev);
}

double CalculateLotSize(double stopLossPips)
{
   double accountBalance = AccountBalance();
   //double stopLossPips = 50; // Stop Loss specifico dell'operazione
   double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE) / MarketInfo(Symbol(), MODE_TICKSIZE);

   // Calcola il lotto dinamico
   return CalculateDynamicLot(riskPercentage, accountBalance, stopLossPips, pipValue);
}

double CalculateDynamicLot(double myRiskPercentage, double accountBalance, double stopLossPips, double pipValue)
{
   // Calcola la perdita massima accettabile
   double maxLoss = accountBalance * (myRiskPercentage / 100.0);

   // Calcola il lotto
   double lotSize = maxLoss / (stopLossPips * pipValue);

   // Restituisce il lotto dinamico, arrotondato al minimo consentito
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   lotSize = MathMin(MathMax(lotSize, minLot), maxLot); // Assicurati che il lotto sia nei limiti del mercato

   return lotSize;
}
