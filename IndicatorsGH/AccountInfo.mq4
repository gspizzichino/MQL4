//+------------------------------------------------------------------+
//|                                                  AccountInfo.mq4 |
//|                        Copyright 2020, Horse Technology Corp. MZ |
//|                                   https://www.horsegroup.net/en/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, Horse Technology Software Corp. MZ"
#property link      "https://www.horsegroup.net/en/"
#property version   "1.00"
#property description "账户信息管理和历史订单统计指标" 
#property description "人民币计数选项需要在市场观察添加货币对USDCNH！" 
#property description "指标所有权和归属权归于马汇科技@Horseforex" 
#property description "如需修改及自定义指标请联系VX:306599003" 
#property description "开户链接: https://secure.horsegroup.net/register/" 
#property description "Account Management Indicators. Copyright@Horseforex" 
#property description "Open Account: https://secure.horsegroup.net/register/" 
#property strict
#property indicator_chart_window
#define EXPERT_MAGIC 0
//#property indicator_chart_window
#include <stderror.mqh> 
#include <stdlib.mqh> 

//extern color          TextColor = clrGold; 
int countcandle=20;

//--- input parameters
input bool     ShowAccountInfo=true;       //显示账户信息
extern bool           ShowPanel=true;       //显示背景板
input bool ShowInChinese=true;                //中文显示
input bool ShowInRMB=false;                //人民币计数(平台需有USDCNH)
//input bool     SetTimeClose=false;        //每日收盘前平仓
//input bool     SetCountLoss=false;        //两次错误禁止交易
//input bool     SetAutoModtify=true;       //下单自动设止损
//input bool     SetAtuoTP=false;        //设置自动止盈
//input double   TakeProfitMoney=1000.0;    //止盈资金
//input double   TakeProfitPrecentage=50.0; //止盈比率
//input bool     SetAtuoSL=false;        //设置自动止损
//input double   StopLossMoney=-400.0;      //止损资金
//input double   StopLossPrecentage=20.0;   //止盈比率
extern string           ttt="---------自定义项---------";       //自定义项-----
//extern bool    SetEmail=true;            //邮件预警(需开启SMTP)
//extern double    SetAlarmBalance=2000;    //账户净资产低于X预警
input datetime checktime=D'2020.08.21 00:00'; //起始时间
input double ExpectedTP=2000; //预期收益
input color          PanelColor  = clrDarkSlateGray; // 背景颜色
input color          TextColor = clrYellow;     // 字体颜色
//input string   SetYourSymbol;
string text;
double orderprofit=0;
int             countloss,countprofit,flag;
int calaryi;
datetime begin_day;         
datetime begin_week;            
datetime begin_month;          
datetime begin_year;     
datetime testorder;     
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
  
   if(AccountInfoString(ACCOUNT_COMPANY)=="Horse Forex Ltd")
         {           
               // TextCreate("PASS","Horse Technology @copyright",15,15,10,Red);
               // flag=1;
         }
    else {
            Alert("Invaild Broker !");
            Alert("Please Change Account !");
            Alert("Failed Authorization !");
            return(INIT_FAILED);
         }  
//--- indicator buffers mapping
     if(ShowPanel)if(ShowInChinese)RectLabelCreate(0,"BACKG",0,10,255,335,310,PanelColor,BORDER_RAISED,CORNER_LEFT_UPPER,clrBlack,STYLE_SOLID,2);  
     if(ShowPanel)if(!ShowInChinese)RectLabelCreate(0,"BACKG",0,10,255,380,310,PanelColor,BORDER_RAISED,CORNER_LEFT_UPPER,clrBlack,STYLE_SOLID,2);  
//---
      Comment("Horse Technology @copyright\nhttps://www.horsegroup.net/\nOpen Account: https://secure.horsegroup.net/register/");
   return(INIT_SUCCEEDED);
  }
  
void OnDeinit(const int reason)
  {
  DeleteAll();
  ObjectDelete(0,"BACKG");
//--- destroy timer
   
   
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
        double transrmb=SymbolInfoDouble("USDCNH",SYMBOL_ASK);
      double accountbalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double accountequity=AccountInfoDouble(ACCOUNT_EQUITY); 
      int t=OrdersTotal();
      double caltotalLots=0;
       for(int i=t-1;i>=0;i--)
            {  
               if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true)  
               {
            //--- parameters of the order
            ulong  position_ticket=OrderTicket();                                      // ticket of the position
            string position_symbol=OrderSymbol();                        // symbol 
            //int    digits=(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS);              // number of decimal places
            //ulong  magic=PositionGetInteger(POSITION_MAGIC);                                  // MagicNumber of the position
            ulong  magic=0;
            double volume1=OrderLots();                                 // volume of the position
            double sl=OrderStopLoss();                                 // volume of the position          
            caltotalLots=volume1+caltotalLots;
               }
            }
//--- for email alarm            
//      if(SetEmail)      
//      if(testorder!=Time[0])
//      {      
//       
//       if(accountequity<=SetAlarmBalance)
//       SendMail("警告！您的账户净值低于 "+DoubleToString(SetAlarmBalance,2)+" !!!",
//               "当前服务器时间："+TimeToString(TimeCurrent(),TIME_MINUTES)+"\n"
//               +"警告！您的账户净值为 "+DoubleToString(accountequity,2)+" !!!"+"\n"
//               +"您账户净值低于 "+DoubleToString(SetAlarmBalance,2)+" 设定值!!!"+"\n"
//               +"\n"
//               +"! 投资有风险，保本第一位！");
//       
//       testorder=Time[0]; 
//      }
//--- for all deals  
     //GetTradeHistory(7);
     
      double caldayprofit=0,calweekprofit=0,calcustprofit=0,caldaylots=0;
      double   profit,lots=0; 
      int caldaysl=0;
      datetime time1; 
      ulong    ticket=0; //long     entry;

      begin_day=StartOfDay(TimeCurrent());
      begin_week=StartOfWeek(TimeCurrent());
//--- check history orders        
      if(OrdersHistoryTotal()>0)
        {
         int j=OrdersHistoryTotal()-1;
         for(int i=OrdersHistoryTotal()-1; i>=0; i--) //建仓晚至早_非平仓时间
           {
                  if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==true)
                  {  
                  //--- get deals properties 
                  time1 =OrderOpenTime(); 
                  //entry =HistoryDealGetInteger(ticket,DEAL_ENTRY); 
                  profit=OrderProfit()+OrderCommission()+OrderSwap(); 
                  lots=OrderLots();
                  //printf(lots);
                  //if(time1>=(TimeCurrent()-1*PeriodSeconds(PERIOD_D1))&&(entry==DEAL_ENTRY_OUT)){caldayprofit=caldayprofit+profit;caldaylots=caldaylots+lots;}
                  //if(time1>=(TimeCurrent()-7*PeriodSeconds(PERIOD_D1))&&(entry==DEAL_ENTRY_OUT)){calweekprofit=calweekprofit+profit;}
                  if((time1>begin_day)){caldayprofit+=profit;caldaylots+=lots;if(profit<0)caldaysl++;}
                  if((time1>begin_week)){calweekprofit+=profit;}
                  if((time1>checktime)){calcustprofit+=profit;}
                  }
            }
         }    
      static string context[];
      ArrayResize(context,60);
      int Aryi=0;//倒转Aryi--;      
     if(ShowInChinese)
      {   
            if(ShowInRMB)
            {
            context[Aryi]="----------@HorseForex----------------"; Aryi++;
            context[Aryi]="| 账户管理 |    | Account Mangement  |"; Aryi++;
            context[Aryi]="-------------------------------------"; Aryi++;
            context[Aryi]="欧洲："+TimeToString(TimeGMT()+3600)+"  美国："+TimeToString(TimeGMT()+3600-18000,TIME_SECONDS);Aryi++; //爆仓比例："+DoubleToString(AccountStopoutLevel(),0)+"%"
            context[Aryi]="---------"; Aryi++;
            context[Aryi]="持仓单数："+IntegerToString(t)+"      持仓盈亏[RMB]："+DoubleToString((accountequity-accountbalance)*transrmb,2); Aryi++;  //多单库存费MarketInfo(Symbol(),MODE_SWAPLONG),2);空单库存费MarketInfo(Symbol(),MODE_SWAPSHORT);
            context[Aryi]="持仓手数："+DoubleToString(caltotalLots,2)+"   持仓盈亏比例："+DoubleToString(((accountequity-accountbalance)/accountbalance)*100,2)+"%"; Aryi++; 
            context[Aryi]="---------";   Aryi++;
            context[Aryi]="当日平仓盈亏："+DoubleToString(caldayprofit*transrmb,2)+"   当周平仓盈亏："+DoubleToString(calweekprofit*transrmb,2); Aryi++;
            context[Aryi]="日平仓盈亏比："+DoubleToString(caldayprofit/accountbalance*100,2)+"%"+"  周平仓盈亏比："+DoubleToString(calweekprofit/accountbalance*100,2)+"%";Aryi++;
            context[Aryi]="当日已交易数量："+DoubleToString(caldaylots,2)+"  亏损交易次数："+IntegerToString(caldaysl);  Aryi++;
            context[Aryi]="---------";   Aryi++;
            //context[Aryi]="平仓手数："+DoubleToString(HAllLots_1,2)+"  平仓盈亏："+DoubleToString(HAllProfit_1,2);Aryi++;  //多单库存费隔夜过夜费MarketInfo(Symbol(),MODE_SWAPLONG);空单库存费隔夜过夜费MarketInfo(Symbol(),MODE_SWAPSHORT);
            context[Aryi]="自定义日[RMB]："+DoubleToString(calcustprofit*transrmb,2)+"   预期差值："+DoubleToString((ExpectedTP-calcustprofit)*transrmb,2);Aryi++; //context[Aryi]="   
            context[Aryi]="账户余额[RMB]："+DoubleToString(accountbalance*transrmb,2)+"  账户净值："+DoubleToString(accountequity*transrmb,2);Aryi++; //context[Aryi]="                    账户净值："+DoubleToString(accountequity,2);Aryi++;
            {context[Aryi]="----- "+Symbol()+" 保证金 = "+DoubleToString(MarketInfo(Symbol(),MODE_MARGINREQUIRED),2)+" USD -----"; Aryi++;}
            calaryi=Aryi;
            }
            else
            {
            context[Aryi]="----------@HorseForex----------------"; Aryi++;
            context[Aryi]="| 账户管理 |    | Account Mangement  |"; Aryi++;
            context[Aryi]="-------------------------------------"; Aryi++;
            context[Aryi]="欧洲："+TimeToString(TimeGMT()+3600)+"  美国："+TimeToString(TimeGMT()+3600-18000,TIME_SECONDS);Aryi++; //爆仓比例："+DoubleToString(AccountStopoutLevel(),0)+"%"
            context[Aryi]="---------"; Aryi++;
            context[Aryi]="持仓单数："+IntegerToString(t)+"      持仓盈亏："+DoubleToString((accountequity-accountbalance),2); Aryi++;  //多单库存费MarketInfo(Symbol(),MODE_SWAPLONG),2);空单库存费MarketInfo(Symbol(),MODE_SWAPSHORT);
            context[Aryi]="持仓手数："+DoubleToString(caltotalLots,2)+"   持仓盈亏比例："+DoubleToString(((accountequity-accountbalance)/accountbalance)*100,2)+"%"; Aryi++; 
            context[Aryi]="---------";   Aryi++;
            context[Aryi]="当日平仓盈亏："+DoubleToString(caldayprofit,2)+"   当周平仓盈亏："+DoubleToString(calweekprofit,2); Aryi++;
            context[Aryi]="日平仓盈亏比："+DoubleToString(caldayprofit/accountbalance*100,2)+"%"+"  周平仓盈亏比："+DoubleToString(calweekprofit/accountbalance*100,2)+"%";Aryi++;
            context[Aryi]="当日已交易数量："+DoubleToString(caldaylots,2)+"  亏损交易次数："+IntegerToString(caldaysl);  Aryi++;
            context[Aryi]="---------";   Aryi++;
            //context[Aryi]="平仓手数："+DoubleToString(HAllLots_1,2)+"  平仓盈亏："+DoubleToString(HAllProfit_1,2);Aryi++;  //多单库存费隔夜过夜费MarketInfo(Symbol(),MODE_SWAPLONG);空单库存费隔夜过夜费MarketInfo(Symbol(),MODE_SWAPSHORT);
            context[Aryi]="自定义日："+DoubleToString(calcustprofit,2)+"   预期差值："+DoubleToString((ExpectedTP-calcustprofit),2);Aryi++; //context[Aryi]="   
            context[Aryi]="账户余额："+DoubleToString(accountbalance,2)+"  账户净值："+DoubleToString(accountequity,2);Aryi++; //context[Aryi]="                    账户净值："+DoubleToString(accountequity,2);Aryi++;
            {context[Aryi]="----- "+Symbol()+" 保证金 = "+DoubleToString(MarketInfo(Symbol(),MODE_MARGINREQUIRED),2)+" USD -----"; Aryi++;}
            calaryi=Aryi;
            }
      }
      else{
      context[Aryi]="-----@HorseForex------"; Aryi++;
      context[Aryi]="|  Account Mangement |"; Aryi++;
      context[Aryi]="----------------------"; Aryi++;
      context[Aryi]="Europe："+TimeToString(TimeGMT()+3600)+"  America："+TimeToString(TimeGMT()+3600-18000,TIME_SECONDS);Aryi++; //爆仓比例："+DoubleToString(AccountStopoutLevel(),0)+"%"
      context[Aryi]="---------"; Aryi++;
      context[Aryi]="Holding Symbol："+IntegerToString(t)+"      Profit："+DoubleToString((accountequity-accountbalance),2); Aryi++;  //多单库存费MarketInfo(Symbol(),MODE_SWAPLONG),2);空单库存费MarketInfo(Symbol(),MODE_SWAPSHORT);
      context[Aryi]="Holding Orders："+DoubleToString(caltotalLots,2)+"   Percentage："+DoubleToString(((accountequity-accountbalance)/accountbalance)*100,2)+"%"; Aryi++; 
      context[Aryi]="---------";   Aryi++;
      context[Aryi]="Daily Profit："+DoubleToString(caldayprofit,2)+"       Weekly Profit："+DoubleToString(calweekprofit,2); Aryi++;
      context[Aryi]="Daily Percentage："+DoubleToString(caldayprofit/accountbalance*100,2)+"%"+"   Weekly Percentage："+DoubleToString(calweekprofit/accountbalance*100,2)+"%";Aryi++;
      context[Aryi]="Daily Trade："+DoubleToString(caldaylots,2)+"         Loss Count："+IntegerToString(caldaysl);  Aryi++;
      context[Aryi]="---------";   Aryi++;
      //context[Aryi]="平仓手数："+DoubleToString(HAllLots_1,2)+"  平仓盈亏："+DoubleToString(HAllProfit_1,2);Aryi++;  //多单库存费隔夜过夜费MarketInfo(Symbol(),MODE_SWAPLONG);空单库存费隔夜过夜费MarketInfo(Symbol(),MODE_SWAPSHORT);
      context[Aryi]="Custom Day："+DoubleToString(calcustprofit,2)+"        Expectation："+DoubleToString((ExpectedTP-calcustprofit),2);Aryi++; 
      context[Aryi]="Account Balance："+DoubleToString(accountbalance,2)+"  Account Equity："+DoubleToString(accountequity,2);Aryi++; //context[Aryi]="                    账户净值："+DoubleToString(accountequity,2);Aryi++;
      {context[Aryi]="----- "+Symbol()+" Margin = "+DoubleToString(MarketInfo(Symbol(),MODE_MARGINREQUIRED),2)+" USD -----"; Aryi++;}
      calaryi=Aryi;
      }
      for(int j=0; j<Aryi; j++) //if(j!=7&&j!=9){tempj++;}
        {
         //
         if(ShowAccountInfo) 
         CreateLabel("CheckTrend"+IntegerToString(j),20,10+(Aryi+j)*18,""+context[j],10,0,ANCHOR_LEFT_UPPER,TextColor);//(j+1)*A_信息间隔N,""+Text[j],A_信息大小,1,ANCHOR_RIGHT_UPPER,A_信息颜色);
        }       
//--- apply on chart 
   ChartRedraw();  
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void CreateLabel(string Name,int XDistance,int YDistance,string StringText,int FontSize,int Corner,int Anchor,color TextColor1)
  {
   if(ObjectFind(0,Name)==-1) //判断是否存在
     {
      ObjectCreate(0,Name,OBJ_LABEL,0,0,0); //第4个：ChartWindowFind()自适应第几个窗口、WindowFind("YCADX"+IntegerToString(ADX周期))查找在哪个窗口  WindowOnDropped()自适应窗口
      ObjectSetString(0,Name,OBJPROP_FONT,"宋体"); //字体 宋体比微软雅黑更清晰,但大字体时更模糊。 "微软雅黑"
      ObjectSetInteger(0,Name,OBJPROP_CORNER,0);//放哪个角落 0123为左右上下
      ObjectSetInteger(0,Name,OBJPROP_SELECTABLE,0); //0不可选取,1可被选取
     }
   ObjectSetInteger(0,Name,OBJPROP_FONTSIZE,FontSize);//文字大小
   ObjectSetInteger(0,Name,OBJPROP_COLOR,TextColor1); //文字颜色
   ObjectSetInteger(0,Name,OBJPROP_XDISTANCE,XDistance);//X轴位置
   ObjectSetInteger(0,Name,OBJPROP_YDISTANCE,YDistance);//Y轴位置
   ObjectSetString(0,Name,OBJPROP_TEXT,StringText); //插入string文字  //在大括号内部为不变更，外部为设置变更
   ObjectSetInteger(0,Name,OBJPROP_ANCHOR,Anchor); //向左对齐、向右对齐 //ANCHOR_LEFT_UPPER (向左上角对齐) ANCHOR_RIGHT_LOWER（向右下角对齐）
  }
//+------------------------------------------------------------------+
void TextCreate(string name,string neirong,int x,int y,int daxiao,color yanse)
  {
    if(ObjectFind(name)<0)
     {
        ObjectCreate(name,OBJ_LABEL,0,0,0);
        ObjectSetText(name,neirong,daxiao,"宋体",yanse);
        ObjectSet(name,OBJPROP_XDISTANCE,x);
        ObjectSet(name,OBJPROP_YDISTANCE,y);
        ObjectSet(name,OBJPROP_CORNER,0);
     }
    else
     {
        ObjectSetText(name,neirong,daxiao,"宋体",yanse);
        WindowRedraw();
     }
  }
  
void CloseAllOrders()
  {
     double myBid,myLot;
     int myType,i,problem;
     bool result = false;
     int myTicket=0;

     for(i=OrdersTotal()-1;i>=0;i--)
         {
                if(OrderSelect(i,SELECT_BY_POS))
                {
                       if(OrdersTotal()>0)                        // &&OrderSymbol()==SetYourSymbol
                              {                            
                              myTicket=OrderTicket();
                              myLot=OrderLots();
                              myType=OrderType();
                              if(OrderType()==OP_BUYLIMIT  || OrderType()==OP_BUYSTOP )
                                {
                                    result=OrderDelete(myTicket);
                                }
                              if(OrderType()==OP_SELL || OrderType()==OP_BUY)
                                {
                                    myBid=MarketInfo(OrderSymbol(),MODE_ASK);
                                    result=OrderClose(myTicket,myLot,myBid,500,Yellow);
                                }
                                                        
                              if (result != 1) 
                              {
                              problem = GetLastError();
                              Print("LastError = "+IntegerToString(problem));
                              } else problem = 0;
                        }
                }
         }         
  } 
  
//+--------------------------------------------------------------------------+ 
//| Requests history for the last days and returns false in case of failure  | 
//+--------------------------------------------------------------------------+ 
//bool GetTradeHistory(int days) 
//  { 
////--- set a week period to request trade history 
//   datetime to=TimeCurrent(); 
//   datetime from=to-days*PeriodSeconds(PERIOD_D1); 
//   ResetLastError(); 
////--- make a request and check the result 
//   if(!HistorySelect(from,to)) 
//     { 
//      Print(__FUNCTION__," HistorySelect=false. Error code=",GetLastError()); 
//      return false; 
//     } 
////--- history received successfully 
//   return true; 
//  }
//   
void orderslatuomodtify()
{
   bool res=false;double sl_level;
   int t=OrdersTotal();
   for(int i=t-1;i>=0;i--)
     {    
            //printf("AutoSet");
            //--- parameters of the order
            //int  position_ticket=OrderTicket();                                      // ticket of the position
            //string position_symbol=OrderSymbol();                        // symbol 
            ////int    digits=(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS);              // number of decimal places
            ////ulong  magic=PositionGetInteger(POSITION_MAGIC);                                  // MagicNumber of the position
            //// ulong  magic=0;
            //double volume=OrderLots();                                 // volume of the position
            //double sl=OrderStopLoss();                                 // volume of the position
            //int type=OrderType();    // type of the position
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true)  
      {
                 if(OrderStopLoss() == NULL)
                     {
                       printf("AutoSet StopLossPosition!");
                     
                       double point=SymbolInfoDouble(OrderSymbol(),SYMBOL_ASK);
                       
                       if(OrderType()==OP_BUY)
                             {
                              if(OrderOpenPrice()<2)sl_level=point*(1-0.008);
                              else sl_level=point*(1-0.005);
                              //request.sl=NormalizeDouble(sl_level,(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS));
                              res=OrderModify(OrderTicket(),OrderOpenPrice(),sl_level,0,0,Green);     
                             }
                       else
                             {
                              if(OrderOpenPrice()<2)sl_level=point*(1+0.008);
                              else sl_level=point*(1+0.005);
                              res=OrderModify(OrderTicket(),OrderOpenPrice(),sl_level,0,0,Green); 
                             }
                             
                                                  
                        if(!res) 
                           //printf("Error in OrderModify. %s  Error code= %s ",com,GetLastError()); 
                           Print("Error in TrackingPriceModify. Error: ",ErrorDescription(GetLastError())); 
                      // else 
                           printf("Order TrackingPriceModify %s modified successfully."); 
                       
                      }
          }
                 
                
       }
}

bool SelectPosition()
  {
//--- check position in Hedging mode
      bool res=false;
      uint totalselect=OrdersTotal();
      if(totalselect==0)
      {
         //printf("No Trading Position ! Waiting...");
         flag=0;
      }
      else
      {

               res=true;
               flag=1;
                     
      }  
      
//--- result for Hedging mode
      return(res);
  }

void CheckTime()
{
     datetime Todaytime=TimeGMT();
     //printf(TimeToString(Todaytime,TIME_DATE));
     MqlDateTime tm;
     if(TimeToStruct(Todaytime,tm))
         {  
            //printf("hour=%d , min=%d ",tm.hour,tm.min);
            //if(tm.hour==20)
            //      {
            //        if(SetTimeClose)
            //               {
            //                 if(flag==1)
            //                     {
            //                         printf("It's time(23H tradingtime) to close all position!");
            //                         Print("23H StopAll");
            //                         CloseAllOrders();    
            //                         flag=0;
            //                     } 
            //               }
            //        }
            if(tm.hour==0)
                  {
                                    countloss=0;
                                    countprofit=0;
                  }
         }
}  
  void DeleteAll()
  {

//--- for all deals 
   for(int j=0; j<calaryi; j++) //if(j!=7&&j!=9){tempj++;}
        {
         //
         ObjectDelete(0,"CheckTrend"+IntegerToString(j));
        }
  }
         
bool RectLabelCreate(const long             chart_ID=0,               // chart's ID
                     const string           name="RectLabel",         // label name
                     const int              sub_window=0,             // subwindow index
                     const int              x=0,                      // X coordinate
                     const int              y=0,                      // Y coordinate
                     const int              width=50,                 // width
                     const int              height=18,                // height
                     const color            back_clr=C'236,233,216',  // background color
                     const ENUM_BORDER_TYPE border=BORDER_SUNKEN,     // border type
                     const ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER, // chart corner for anchoring
                     const color            clr=clrRed,               // flat border color (Flat)
                     const ENUM_LINE_STYLE  style=STYLE_SOLID,        // flat border style
                     const int              line_width=1,             // flat border width
                     const bool             back=false,               // in the background
                     const bool             selection=false,          // highlight to move
                     const bool             hidden=true,              // hidden in the object list
                     const long             z_order=0)                // priority for mouse click
  {
//--- reset the error value
   ResetLastError();
//--- create a rectangle label
   if(!ObjectCreate(chart_ID,name,OBJ_RECTANGLE_LABEL,sub_window,0,0))
     {
      Print(__FUNCTION__,
            ": failed to create a rectangle label! Error code = ",GetLastError());
      return(false);
     }
//--- set label coordinates
   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
//--- set label size
   ObjectSetInteger(chart_ID,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(chart_ID,name,OBJPROP_YSIZE,height);
//--- set background color
   ObjectSetInteger(chart_ID,name,OBJPROP_BGCOLOR,back_clr);
//--- set border type
   ObjectSetInteger(chart_ID,name,OBJPROP_BORDER_TYPE,border);
//--- set the chart's corner, relative to which point coordinates are defined
   ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
//--- set flat border color (in Flat mode)
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set flat border line style
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set flat border width
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,line_width);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the label by mouse
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }        
    datetime StartOfDay(const datetime time)
  {
   return((time/86400)*86400);
  }
//+------------------------------------------------------------------+
//| Возвращает время начала недели                                   |
//+------------------------------------------------------------------+
datetime StartOfWeek(const datetime time)
  {
   long tmp=time;
   long corrector= 259200;
   tmp+=corrector;
   tmp=(tmp/604800)*604800;
   tmp-=corrector;
   return((datetime)tmp);
  }
//+------------------------------------------------------------------+
//| Возвращает время начала месяца                                   |
//+------------------------------------------------------------------+
datetime StartOfMonth(const datetime time)
  {
   MqlDateTime stm;
   ::TimeToStruct(time,stm);
   stm.day=1;
   stm.hour=0;
   stm.min=0;
   stm.sec=0;
   return(::StructToTime(stm));
  }
//+------------------------------------------------------------------+
//| Возвращает время начала года                                     |
//+------------------------------------------------------------------+
datetime StartOfYear(const datetime time)
  {
   MqlDateTime stm;
   ::TimeToStruct(time,stm);
   stm.day=1;
   stm.mon=1;
   stm.hour=0;
   stm.min=0;
   stm.sec=0;
   return(::StructToTime(stm));
  }