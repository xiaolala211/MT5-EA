//+------------------------------------------------------------------+
//|                                                   Utilities.mqh  |
//|                        Smart Money Concepts Trading System       |
//|                                                                  |
//| Description: Utility functions for the SMC trading system.       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property strict

//+------------------------------------------------------------------+
//| Utilities class                                                  |
//+------------------------------------------------------------------+
class CUtilities {
public:
                     CUtilities();
                    ~CUtilities();
   
   // Timeframe conversion
   string            TimeframeToString(ENUM_TIMEFRAME timeframe);
   ENUM_TIMEFRAME    StringToTimeframe(string tfString);
   
   // Price calculations
   double            CalculatePipValue();
   double            PointsToPips(double points);
   double            PipsToPoints(double pips);
   
   // Position sizing
   double            NormalizeLotSize(double lotSize);
   double            CalculatePositionSize(double riskAmount, double stopLossPoints);
   
   // Risk management
   double            CalculateRiskAmount(double accountBalance, double riskPercent);
   double            CalculateRisk(double lotSize, double stopLossPoints);
   double            CalculateReward(double lotSize, double takeProfitPoints);
   double            CalculateRiskRewardRatio(double stopLossPoints, double takeProfitPoints);
   
   // Formatting
   string            DoubleToNiceString(double value, int digits);
   string            GetDeinitReasonText(int reason);
   
   // Day of Month calculation
   int               DayOfMonth(int year, int month);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CUtilities::CUtilities() {
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CUtilities::~CUtilities() {
}

//+------------------------------------------------------------------+
//| Convert timeframe to string                                      |
//+------------------------------------------------------------------+
string CUtilities::TimeframeToString(ENUM_TIMEFRAME timeframe) {
   switch (timeframe) {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
      default: return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Convert string to timeframe                                      |
//+------------------------------------------------------------------+
ENUM_TIMEFRAME CUtilities::StringToTimeframe(string tfString) {
   if (tfString == "M1") return PERIOD_M1;
   if (tfString == "M5") return PERIOD_M5;
   if (tfString == "M15") return PERIOD_M15;
   if (tfString == "M30") return PERIOD_M30;
   if (tfString == "H1") return PERIOD_H1;
   if (tfString == "H4") return PERIOD_H4;
   if (tfString == "D1") return PERIOD_D1;
   if (tfString == "W1") return PERIOD_W1;
   if (tfString == "MN1") return PERIOD_MN1;
   
   return PERIOD_CURRENT; // Default to current timeframe
}

//+------------------------------------------------------------------+
//| Calculate the pip value for the current symbol                   |
//+------------------------------------------------------------------+
double CUtilities::CalculatePipValue() {
   // Get the tick value in the account currency
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   // Calculate pips per tick
   double pipsPerTick = 1;
   
   // For Forex pairs, 1 pip is usually 0.0001 for 4-digit brokers
   // and 0.00001 for 5-digit brokers
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   if (digits == 3 || digits == 5) {
      // JPY pairs (3 digits) or 5-digit broker
      pipsPerTick = 0.1;
   }
   
   // Calculate the value of 1 pip
   double pipValue = tickValue / pipsPerTick;
   
   return pipValue;
}

//+------------------------------------------------------------------+
//| Convert points to pips                                           |
//+------------------------------------------------------------------+
double CUtilities::PointsToPips(double points) {
   // Get the number of digits in the symbol price
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   // For Forex pairs, 1 pip is usually 0.0001 for 4-digit brokers
   // and 0.00001 for 5-digit brokers
   double pipMultiplier = 1;
   
   if (digits == 3 || digits == 5) {
      // JPY pairs (3 digits) or 5-digit broker
      pipMultiplier = 10;
   }
   
   return points / _Point / pipMultiplier;
}

//+------------------------------------------------------------------+
//| Convert pips to points                                           |
//+------------------------------------------------------------------+
double CUtilities::PipsToPoints(double pips) {
   // Get the number of digits in the symbol price
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   // For Forex pairs, 1 pip is usually 0.0001 for 4-digit brokers
   // and 0.00001 for 5-digit brokers
   double pipMultiplier = 1;
   
   if (digits == 3 || digits == 5) {
      // JPY pairs (3 digits) or 5-digit broker
      pipMultiplier = 10;
   }
   
   return pips * _Point * pipMultiplier;
}

//+------------------------------------------------------------------+
//| Normalize lot size according to broker requirements              |
//+------------------------------------------------------------------+
double CUtilities::NormalizeLotSize(double lotSize) {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Ensure lot size is within min/max limits
   lotSize = MathMin(maxLot, MathMax(minLot, lotSize));
   
   // Round to the nearest lot step
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk amount and stop loss       |
//+------------------------------------------------------------------+
double CUtilities::CalculatePositionSize(double riskAmount, double stopLossPoints) {
   if (stopLossPoints <= 0) return 0;
   
   // Get tick value in account currency
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   // Calculate lot size
   double lotSize = riskAmount / (stopLossPoints * tickValue / _Point);
   
   // Normalize lot size
   return NormalizeLotSize(lotSize);
}

//+------------------------------------------------------------------+
//| Calculate risk amount based on account balance and risk percent  |
//+------------------------------------------------------------------+
double CUtilities::CalculateRiskAmount(double accountBalance, double riskPercent) {
   return accountBalance * (riskPercent / 100.0);
}

//+------------------------------------------------------------------+
//| Calculate risk in account currency for a trade                   |
//+------------------------------------------------------------------+
double CUtilities::CalculateRisk(double lotSize, double stopLossPoints) {
   // Get tick value in account currency
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   // Calculate risk
   return lotSize * (stopLossPoints * tickValue / _Point);
}

//+------------------------------------------------------------------+
//| Calculate potential reward in account currency for a trade       |
//+------------------------------------------------------------------+
double CUtilities::CalculateReward(double lotSize, double takeProfitPoints) {
   // Get tick value in account currency
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   // Calculate reward
   return lotSize * (takeProfitPoints * tickValue / _Point);
}

//+------------------------------------------------------------------+
//| Calculate risk:reward ratio for a trade                          |
//+------------------------------------------------------------------+
double CUtilities::CalculateRiskRewardRatio(double stopLossPoints, double takeProfitPoints) {
   if (stopLossPoints <= 0) return 0;
   
   return takeProfitPoints / stopLossPoints;
}

//+------------------------------------------------------------------+
//| Format a double value with the specified number of digits        |
//+------------------------------------------------------------------+
string CUtilities::DoubleToNiceString(double value, int digits) {
   return DoubleToString(value, digits);
}

//+------------------------------------------------------------------+
//| Get textual description of a deinit reason                       |
//+------------------------------------------------------------------+
string CUtilities::GetDeinitReasonText(int reason) {
   switch (reason) {
      case REASON_PROGRAM: return "Program terminated normally";
      case REASON_REMOVE: return "Expert removed from chart";
      case REASON_RECOMPILE: return "Expert recompiled";
      case REASON_CHARTCHANGE: return "Symbol or timeframe changed";
      case REASON_CHARTCLOSE: return "Chart closed";
      case REASON_PARAMETERS: return "Input parameters changed";
      case REASON_ACCOUNT: return "Another account activated";
      case REASON_TEMPLATE: return "New template applied";
      case REASON_INITFAILED: return "Initialization failed";
      case REASON_CLOSE: return "Terminal closed";
      default: return "Unknown reason: " + IntegerToString(reason);
   }
}

//+------------------------------------------------------------------+
//| Calculate number of days in a month                              |
//+------------------------------------------------------------------+
int CUtilities::DayOfMonth(int year, int month) {
   int daysInMonth;
   
   switch (month) {
      case 1: // January
      case 3: // March
      case 5: // May
      case 7: // July
      case 8: // August
      case 10: // October
      case 12: // December
         daysInMonth = 31;
         break;
      
      case 4: // April
      case 6: // June
      case 9: // September
      case 11: // November
         daysInMonth = 30;
         break;
      
      case 2: // February
         // Check for leap year
         if ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) {
            daysInMonth = 29; // Leap year
         } else {
            daysInMonth = 28; // Non-leap year
         }
         break;
      
      default:
         daysInMonth = 30; // Default to 30 days
   }
   
   return daysInMonth;
}
