//+------------------------------------------------------------------+
//|                                                  880 Scanner.mq5 |
//|                                       Rodolfo Pereira de Andrade |
//|                                     https://rodorush.com.br/blog |
//+------------------------------------------------------------------+
#property copyright "Rodolfo Pereira de Andrade"
#property link      "https://rodorush.com.br/blog"
#property version   "1.01"

bool usaStoch;
double maFast[], maSlow[], stoch[], signal[], high[], low[];
double buyPrice, sellPrice;
ENUM_TIMEFRAMES period;
int candle;
int sinal;
int symbolsTotal;
int abrirGrafico;
int maHandle_fast, maHandle_slow, stochHandle;
long chart_id;
MqlRates rates[];
string templateName = "3EMA-5-10-20 STOCH14-3-3.tpl";
string symbolName;

//group "Fast MA"
int ma_period_fast; //Período
int ma_shift_fast = 0; //Deslocamento horizontal 
ENUM_MA_METHOD ma_method_fast = MODE_EMA; //Tipo
ENUM_APPLIED_PRICE applied_price_fast = PRICE_CLOSE; //Tipo do preço

//group "Slow MA"
int ma_period_slow; //Período
int ma_shift_slow = 0; //Deslocamento horizontal 
ENUM_MA_METHOD ma_method_slow = MODE_EMA; //Tipo
ENUM_APPLIED_PRICE applied_price_slow = PRICE_CLOSE; //Tipo do preço

//group "Stochastic"
int overBought; //Sobrecompra
int overSold; //Sobrevenda
int stoch_Kperiod; //K-period (número de barras para cálculos); Se 0 não usa.
int stoch_Dperiod; //D-period (período da primeira suavização) 
int stoch_slowing; //Final da suavização 
ENUM_MA_METHOD ma_method = MODE_SMA; //Tipo de suavização 
ENUM_STO_PRICE price_field = STO_LOWHIGH; //Método de cálculo estocástico 

void OnStart() {
   GlobalInputs();
   period = ChartPeriod(0);
   int buys = 0;
   int sells = 0;
 
   SetSeries();
   
   symbolsTotal = SymbolsTotal(true);
   for(int i=0;i<symbolsTotal;i++) {                                                    //Percorre todos os símbolos disponíveis no terminal.
      symbolName = SymbolName(i,true);
      
      Handles();
      IndBuffers();
            
      if(Sinal() == 2) { //Compra
         buys++;
         buyPrice = high[candle]+SymbolInfoDouble(symbolName,SYMBOL_TRADE_TICK_SIZE);
         if(IsChartOpened(i)) continue;
         Print("("+IntegerToString(i+1)+"/"+IntegerToString(symbolsTotal)+") "+symbolName+" = BUY em "+DoubleToString(buyPrice,(int)SymbolInfoInteger(symbolName,SYMBOL_DIGITS)));
         if(abrirGrafico >= 0) {
            chart_id = ChartOpen(symbolName,period);
            if(chart_id == 0) {
               MessageBox("Não foi possível abrir o gráfico de "+symbolName,"Erro ao abrir um gráfico!");
               continue;
            }
            CheckTemplateAndApply();
            DesenhaLinha();
         }
      }else if(Sinal() == -2) { //Venda
         sells++;
         sellPrice = low[candle]-SymbolInfoDouble(symbolName,SYMBOL_TRADE_TICK_SIZE);
         if(IsChartOpened(i)) continue;
         Print("("+IntegerToString(i+1)+"/"+IntegerToString(symbolsTotal)+") "+symbolName+" = SELL em "+DoubleToString(sellPrice,(int)SymbolInfoInteger(symbolName,SYMBOL_DIGITS)));
         if(abrirGrafico <= 0) {
            chart_id = ChartOpen(symbolName,period);
            if(chart_id == 0) {
               MessageBox("Não foi possível abrir o gráfico de "+symbolName,"Erro ao abrir um gráfico!");
               continue;
            }
            CheckTemplateAndApply();
            DesenhaLinha();
         }
      }else {
         Print("("+IntegerToString(i+1)+"/"+IntegerToString(symbolsTotal)+") "+symbolName+" = NO TRADES");
      }
   }
   Print("Total de BUYs = "+IntegerToString(buys));
   Print("Total de SELLs = "+IntegerToString(sells));
}

bool IsChartOpened(int pos) {
   long currChart = ChartFirst();
   long prevChart = currChart;
   int i=0,limit=200; 
   while(i<limit)// Temos provavelmente não mais do que 200 gráficos abertos 
     { 
      if(ChartSymbol(currChart) == symbolName) {
         if(sinal == 2) {
            Print("("+IntegerToString(pos+1)+"/"+IntegerToString(symbolsTotal)+") "+symbolName+" = BUY em "+DoubleToString(buyPrice,(int)SymbolInfoInteger(symbolName,SYMBOL_DIGITS))+". Mas já está aberto.");
         }else {
            Print("("+IntegerToString(pos+1)+"/"+IntegerToString(symbolsTotal)+") "+symbolName+" = SELL em "+DoubleToString(sellPrice,(int)SymbolInfoInteger(symbolName,SYMBOL_DIGITS))+". Mas já está aberto.");
         }
         DesenhaLinha();
         return(true);
      }
      currChart=ChartNext(prevChart); // Obter o ID do novo gráfico usando o ID gráfico anterior 
      if(currChart<0) break;          // Ter atingido o fim da lista de gráfico 
      prevChart=currChart;// vamos salvar o ID do gráfico atual para o ChartNext() 
      i++;// Não esqueça de aumentar o contador 
     }
   return(false);
}

void DesenhaLinha() {
bool falhou = true;
   string tradeSide = sinal == 2 ? "Compra" : "Venda";
   double tradePrice = sinal == 2 ? buyPrice : sellPrice;
   do {
      if(ObjectCreate(chart_id,tradeSide,OBJ_HLINE,0,0,tradePrice))
       if(ObjectFind(chart_id,tradeSide) == 0)
        if(ObjectSetInteger(chart_id,tradeSide,OBJPROP_STYLE,STYLE_DASH))
         if(ObjectGetInteger(chart_id,tradeSide,OBJPROP_STYLE) == STYLE_DASH)
          if(ObjectSetInteger(chart_id,tradeSide,OBJPROP_COLOR,clrAqua))
           if(ObjectGetInteger(chart_id,tradeSide,OBJPROP_COLOR) == clrAqua) {
              ChartRedraw(chart_id);
              falhou = false;
           }
   }while(falhou && !IsStopped());
}

void CheckTemplateAndApply() {
   if(FileIsExist(templateName)) { 
      if(ChartApplyTemplate(chart_id,templateName)) { 
         ChartRedraw(chart_id); 
      }else {
         Print("Falha ao aplicar " + templateName + ", código de erro ",GetLastError()); 
      }
   }else {
      Print("Arquivo " + templateName + " não encontrado em " + TerminalInfoString(TERMINAL_PATH)+"\\MQL5\\Files");
   }
}

int Sinal() {
   sinal = 0;
   if(maFast[candle] > maSlow[candle]) {
      //Compra no Éden dos Traders
      if((rates[candle+1].close < maFast[candle+1] && rates[candle].close > maFast[candle]) || //Fechou abaixo e fechou acima da média rápida
         (rates[candle+1].high > rates[candle].high && (rates[candle].open > maFast[candle] || rates[candle].close > maFast[candle])) || //Pullback com abertura ou fechamento acima da média rápida
         //Compra no Pullback
         (usaStoch && stoch[candle] < overSold && stoch_Kperiod > 0)) //Sobrevenda
          sinal = 2;
   }else if(maFast[candle] < maSlow[candle]) {
      //Venda no Éden dos Traders
      if((rates[candle+1].close > maFast[candle+1] && rates[candle].close < maFast[candle]) || //Fechou abaixo e fechou acima da média rápida
         (rates[candle+1].low < rates[candle].low && (rates[candle].open < maFast[candle] || rates[candle].close < maFast[candle])) || //Pullback com abertura ou fechamento acima da média rápida
         //Venda no Pullback
         (usaStoch && stoch[candle] > overBought && stoch_Kperiod > 0)) //Sobrecompra
          sinal = -2;
   }
   return(sinal);
}

void IndBuffers() {
   CopyBuffer(maHandle_fast,0,0,candle+2,maFast);
   CopyBuffer(maHandle_slow,0,0,candle+2,maSlow);
   CopyBuffer(stochHandle,0,0,candle+2,stoch);
   CopyBuffer(stochHandle,1,0,candle+2,signal);
   CopyHigh(symbolName,period,0,candle+2,high);
   CopyLow(symbolName,period,0,candle+2,low);
   CopyRates(symbolName, period, 0, candle+2, rates);
}

void SetSeries() {
   ArraySetAsSeries(maFast,true);
   ArraySetAsSeries(maSlow,true);
   ArraySetAsSeries(stoch,true);
   ArraySetAsSeries(signal,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(rates,true);
}

void Handles() {
   maHandle_fast = iMA(symbolName, period, ma_period_fast, ma_shift_fast, ma_method_fast, applied_price_fast);
   maHandle_slow = iMA(symbolName, period, ma_period_slow, ma_shift_slow, ma_method_slow, applied_price_slow);
   stochHandle = iStochastic(symbolName, period, stoch_Kperiod, stoch_Dperiod, stoch_slowing, ma_method, price_field);
}

void GlobalInputs() {
   if(!GlobalVariableCheck("candle")) GlobalVariableSet("candle",1);
   candle = (int)GlobalVariableGet("candle");
   
   if(!GlobalVariableCheck("usaStoch")) GlobalVariableSet("usaStoch", true);
   usaStoch = (bool)GlobalVariableGet("usaStoch");

   if(!GlobalVariableCheck("ma_period_fast")) GlobalVariableSet("ma_period_fast", 10);
   ma_period_fast = (int)GlobalVariableGet("ma_period_fast");

   if(!GlobalVariableCheck("ma_period_slow")) GlobalVariableSet("ma_period_slow", 20);
   ma_period_slow = (int)GlobalVariableGet("ma_period_slow");

   if(!GlobalVariableCheck("overBought")) GlobalVariableSet("overBought",80);
   overBought = (int)GlobalVariableGet("overBought");
   
   if(!GlobalVariableCheck("overSold")) GlobalVariableSet("overSold",20);
   overSold = (int)GlobalVariableGet("overSold");
   
   if(!GlobalVariableCheck("stoch_Kperiod")) GlobalVariableSet("stoch_Kperiod",14);
   stoch_Kperiod = (int)GlobalVariableGet("stoch_Kperiod");
   
   if(!GlobalVariableCheck("stoch_Dperiod")) GlobalVariableSet("stoch_Dperiod",3);
   stoch_Dperiod = (int)GlobalVariableGet("stoch_Dperiod");

   if(!GlobalVariableCheck("stoch_slowing")) GlobalVariableSet("stoch_slowing",3);
   stoch_slowing = (int)GlobalVariableGet("stoch_slowing");

   if(!GlobalVariableCheck("abrirGrafico")) GlobalVariableSet("abrirGrafico",1);
   abrirGrafico = (int)GlobalVariableGet("abrirGrafico");
}
//+------------------------------------------------------------------+