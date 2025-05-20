//+------------------------------------------------------------------+
//|                                           LiquidityAnalysis.mqh  |
//|                        Smart Money Concepts Trading System       |
//|                                                                  |
//| Description: Class for analyzing liquidity zones, liquidity      |
//| grabs, and stop hunts.                                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property strict

// Liquidity type enumeration
enum ENUM_LIQUIDITY_TYPE {
   LIQ_NONE,           // No specific liquidity
   LIQ_BUY_STOPS,      // Buy stops above a level (target for bearish LG)
   LIQ_SELL_STOPS,     // Sell stops below a level (target for bullish LG)
   LIQ_EQUAL_HIGHS,    // Equal highs (EQH) - multiple tests of the same high
   LIQ_EQUAL_LOWS      // Equal lows (EQL) - multiple tests of the same low
};

//+------------------------------------------------------------------+
//| LiquidityZone structure                                          |
//+------------------------------------------------------------------+
struct LiquidityZone {
   ENUM_LIQUIDITY_TYPE type;    // Type of liquidity
   datetime time;               // Time of the liquidity level
   double level;                // Price level of the liquidity
   double thickness;            // Estimated thickness of liquidity (in points)
   bool isSwept;                // Whether the liquidity has been swept
   
   // Constructor
   LiquidityZone() {
      type = LIQ_NONE;
      time = 0;
      level = 0;
      thickness = 0;
      isSwept = false;
   }
};

//+------------------------------------------------------------------+
//| LiquidityGrab structure                                          |
//+------------------------------------------------------------------+
struct LiquidityGrab {
   ENUM_LIQUIDITY_TYPE targetType;    // Type of liquidity targeted
   datetime time;                     // Time of the liquidity grab
   double sweepLevel;                 // Price level that was swept
   double reversalLevel;              // Price level after reversal
   bool isValid;                      // Whether the liquidity grab is valid (reversal occurred)
   
   // Constructor
   LiquidityGrab() {
      targetType = LIQ_NONE;
      time = 0;
      sweepLevel = 0;
      reversalLevel = 0;
      isValid = false;
   }
};

//+------------------------------------------------------------------+
//| LiquidityAnalysis class                                          |
//+------------------------------------------------------------------+
class CLiquidityAnalysis {
private:
   int               m_range;              // Range to look for liquidity (in pips)
   int               m_lookback;           // Lookback period for liquidity grabs
   LiquidityZone     m_liquidityZones[];  // Array of identified liquidity zones
   LiquidityGrab     m_recentGrabs[];     // Array of recent liquidity grabs
   
   // Private methods
   void              IdentifyLiquidityZones(ENUM_TIMEFRAME timeframe);
   void              IdentifyLiquidityGrabs(ENUM_TIMEFRAME timeframe);
   bool              IsEqualHigh(double price1, double price2, double threshold);
   bool              IsEqualLow(double price1, double price2, double threshold);
   bool              IsReversal(int bar, ENUM_TIMEFRAME timeframe, bool checkBullish);
   
public:
                     CLiquidityAnalysis();
                    ~CLiquidityAnalysis();
   
   // Initialization
   void              Initialize(int range, int lookback);
   
   // Analysis methods
   bool              DetectLiquidityGrab(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias);
   bool              IsInLiquidityZone(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias);
   
   // Helper methods for trade execution
   double            GetBuyStopLossLevel();
   double            GetSellStopLossLevel();
   double            GetBuyTakeProfitLevel();
   double            GetSellTakeProfitLevel();
   
   // Utility methods
   string            LiquidityTypeToString(ENUM_LIQUIDITY_TYPE type);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLiquidityAnalysis::CLiquidityAnalysis() {
   m_range = 20;
   m_lookback = 10;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLiquidityAnalysis::~CLiquidityAnalysis() {
   ArrayFree(m_liquidityZones);
   ArrayFree(m_recentGrabs);
}

//+------------------------------------------------------------------+
//| Initialize the class with parameters                             |
//+------------------------------------------------------------------+
void CLiquidityAnalysis::Initialize(int range, int lookback) {
   m_range = range;
   m_lookback = lookback;
}

//+------------------------------------------------------------------+
//| Identify liquidity zones on the specified timeframe              |
//+------------------------------------------------------------------+
void CLiquidityAnalysis::IdentifyLiquidityZones(ENUM_TIMEFRAME timeframe) {
   // Clear existing liquidity zones
   ArrayFree(m_liquidityZones);
   
   // Initialize array
   ArrayResize(m_liquidityZones, 0);
   
   double threshold = m_range * _Point; // Threshold for equal levels
   
   // Find equal highs (EQH)
   for (int i = 0; i < m_lookback - 1; i++) {
      for (int j = i + 1; j < m_lookback; j++) {
         if (IsEqualHigh(iHigh(_Symbol, timeframe, i), iHigh(_Symbol, timeframe, j), threshold)) {
            // We found an equal high
            LiquidityZone zone;
            zone.type = LIQ_EQUAL_HIGHS;
            zone.time = iTime(_Symbol, timeframe, MathMin(i, j));
            zone.level = MathMax(iHigh(_Symbol, timeframe, i), iHigh(_Symbol, timeframe, j));
            zone.thickness = threshold;
            
            // Check if this EQH has been swept
            zone.isSwept = iHigh(_Symbol, timeframe, 0) > zone.level;
            
            // Add to array
            int size = ArraySize(m_liquidityZones);
            ArrayResize(m_liquidityZones, size + 1);
            m_liquidityZones[size] = zone;
            
            // No need to continue inner loop
            break;
         }
      }
   }
   
   // Find equal lows (EQL)
   for (int i = 0; i < m_lookback - 1; i++) {
      for (int j = i + 1; j < m_lookback; j++) {
         if (IsEqualLow(iLow(_Symbol, timeframe, i), iLow(_Symbol, timeframe, j), threshold)) {
            // We found an equal low
            LiquidityZone zone;
            zone.type = LIQ_EQUAL_LOWS;
            zone.time = iTime(_Symbol, timeframe, MathMin(i, j));
            zone.level = MathMin(iLow(_Symbol, timeframe, i), iLow(_Symbol, timeframe, j));
            zone.thickness = threshold;
            
            // Check if this EQL has been swept
            zone.isSwept = iLow(_Symbol, timeframe, 0) < zone.level;
            
            // Add to array
            int size = ArraySize(m_liquidityZones);
            ArrayResize(m_liquidityZones, size + 1);
            m_liquidityZones[size] = zone;
            
            // No need to continue inner loop
            break;
         }
      }
   }
   
   // Identify potential buy stops above swing highs
   double highestHigh = iHigh(_Symbol, timeframe, iHighest(_Symbol, timeframe, MODE_HIGH, m_lookback, 0));
   
   LiquidityZone buyStopsZone;
   buyStopsZone.type = LIQ_BUY_STOPS;
   buyStopsZone.time = iTime(_Symbol, timeframe, 0);
   buyStopsZone.level = highestHigh + (5 * _Point); // Assuming stops are placed a few pips above
   buyStopsZone.thickness = 10 * _Point; // Estimated thickness
   buyStopsZone.isSwept = iHigh(_Symbol, timeframe, 0) > buyStopsZone.level;
   
   // Add to array
   int buyStopsSize = ArraySize(m_liquidityZones);
   ArrayResize(m_liquidityZones, buyStopsSize + 1);
   m_liquidityZones[buyStopsSize] = buyStopsZone;
   
   // Identify potential sell stops below swing lows
   double lowestLow = iLow(_Symbol, timeframe, iLowest(_Symbol, timeframe, MODE_LOW, m_lookback, 0));
   
   LiquidityZone sellStopsZone;
   sellStopsZone.type = LIQ_SELL_STOPS;
   sellStopsZone.time = iTime(_Symbol, timeframe, 0);
   sellStopsZone.level = lowestLow - (5 * _Point); // Assuming stops are placed a few pips below
   sellStopsZone.thickness = 10 * _Point; // Estimated thickness
   sellStopsZone.isSwept = iLow(_Symbol, timeframe, 0) < sellStopsZone.level;
   
   // Add to array
   int sellStopsSize = ArraySize(m_liquidityZones);
   ArrayResize(m_liquidityZones, sellStopsSize + 1);
   m_liquidityZones[sellStopsSize] = sellStopsZone;
}

//+------------------------------------------------------------------+
//| Identify liquidity grabs on the specified timeframe              |
//+------------------------------------------------------------------+
void CLiquidityAnalysis::IdentifyLiquidityGrabs(ENUM_TIMEFRAME timeframe) {
   // Clear existing liquidity grabs
   ArrayFree(m_recentGrabs);
   
   // Initialize array
   ArrayResize(m_recentGrabs, 0);
   
   // First identify liquidity zones
   IdentifyLiquidityZones(timeframe);
   
   // Loop through the liquidity zones to see if any have been grabbed recently
   for (int i = 0; i < ArraySize(m_liquidityZones); i++) {
      if (m_liquidityZones[i].isSwept) {
         // Check when this zone was swept
         int sweepIndex = -1;
         
         // Find the candle that swept this liquidity
         for (int j = 0; j < m_lookback; j++) {
            if (m_liquidityZones[i].type == LIQ_EQUAL_HIGHS || m_liquidityZones[i].type == LIQ_BUY_STOPS) {
               if (iHigh(_Symbol, timeframe, j) > m_liquidityZones[i].level) {
                  sweepIndex = j;
                  break;
               }
            }
            else if (m_liquidityZones[i].type == LIQ_EQUAL_LOWS || m_liquidityZones[i].type == LIQ_SELL_STOPS) {
               if (iLow(_Symbol, timeframe, j) < m_liquidityZones[i].level) {
                  sweepIndex = j;
                  break;
               }
            }
         }
         
         // If we found the sweep, check if it was followed by a reversal
         if (sweepIndex >= 0) {
            bool checkBullish = (m_liquidityZones[i].type == LIQ_EQUAL_LOWS || 
                                m_liquidityZones[i].type == LIQ_SELL_STOPS);
            
            if (IsReversal(sweepIndex, timeframe, checkBullish)) {
               LiquidityGrab grab;
               grab.targetType = m_liquidityZones[i].type;
               grab.time = iTime(_Symbol, timeframe, sweepIndex);
               grab.sweepLevel = m_liquidityZones[i].level;
               
               // Set reversal level based on liquidity type
               if (checkBullish) {
                  grab.reversalLevel = iClose(_Symbol, timeframe, sweepIndex);
               } else {
                  grab.reversalLevel = iClose(_Symbol, timeframe, sweepIndex);
               }
               
               grab.isValid = true;
               
               // Add to array
               int size = ArraySize(m_recentGrabs);
               ArrayResize(m_recentGrabs, size + 1);
               m_recentGrabs[size] = grab;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if two price levels are approximately equal (for highs)    |
//+------------------------------------------------------------------+
bool CLiquidityAnalysis::IsEqualHigh(double price1, double price2, double threshold) {
   return MathAbs(price1 - price2) < threshold;
}

//+------------------------------------------------------------------+
//| Check if two price levels are approximately equal (for lows)     |
//+------------------------------------------------------------------+
bool CLiquidityAnalysis::IsEqualLow(double price1, double price2, double threshold) {
   return MathAbs(price1 - price2) < threshold;
}

//+------------------------------------------------------------------+
//| Check if a bar shows reversal characteristics                    |
//+------------------------------------------------------------------+
bool CLiquidityAnalysis::IsReversal(int bar, ENUM_TIMEFRAME timeframe, bool checkBullish) {
   if (bar <= 0) return false;
   
   // Check for bullish reversal after a liquidity grab of sell stops
   if (checkBullish) {
      // The bar that swept liquidity should have a long lower wick
      double lowerWick = iOpen(_Symbol, timeframe, bar) - iLow(_Symbol, timeframe, bar);
      double upperWick = iHigh(_Symbol, timeframe, bar) - iClose(_Symbol, timeframe, bar);
      double body = MathAbs(iClose(_Symbol, timeframe, bar) - iOpen(_Symbol, timeframe, bar));
      
      // Long lower wick (at least 2x the body) and close in the upper half
      if (lowerWick > body * 2 && iClose(_Symbol, timeframe, bar) > iOpen(_Symbol, timeframe, bar)) {
         return true;
      }
      
      // Alternative: the next few bars close higher
      int nextBarsUp = 0;
      for (int i = bar - 1; i >= MathMax(bar - 3, 0); i--) {
         if (iClose(_Symbol, timeframe, i) > iOpen(_Symbol, timeframe, i)) {
            nextBarsUp++;
         }
      }
      
      return nextBarsUp >= 2;
   }
   // Check for bearish reversal after a liquidity grab of buy stops
   else {
      // The bar that swept liquidity should have a long upper wick
      double upperWick = iHigh(_Symbol, timeframe, bar) - iOpen(_Symbol, timeframe, bar);
      double lowerWick = iClose(_Symbol, timeframe, bar) - iLow(_Symbol, timeframe, bar);
      double body = MathAbs(iClose(_Symbol, timeframe, bar) - iOpen(_Symbol, timeframe, bar));
      
      // Long upper wick (at least 2x the body) and close in the lower half
      if (upperWick > body * 2 && iClose(_Symbol, timeframe, bar) < iOpen(_Symbol, timeframe, bar)) {
         return true;
      }
      
      // Alternative: the next few bars close lower
      int nextBarsDown = 0;
      for (int i = bar - 1; i >= MathMax(bar - 3, 0); i--) {
         if (iClose(_Symbol, timeframe, i) < iOpen(_Symbol, timeframe, i)) {
            nextBarsDown++;
         }
      }
      
      return nextBarsDown >= 2;
   }
}

//+------------------------------------------------------------------+
//| Detect a recent liquidity grab                                   |
//+------------------------------------------------------------------+
bool CLiquidityAnalysis::DetectLiquidityGrab(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias) {
   // Identify liquidity grabs
   IdentifyLiquidityGrabs(timeframe);
   
   // If no recent grabs, return false
   if (ArraySize(m_recentGrabs) == 0) {
      return false;
   }
   
   // Find the most recent valid liquidity grab that aligns with the bias
   for (int i = 0; i < ArraySize(m_recentGrabs); i++) {
      if (m_recentGrabs[i].isValid) {
         // For bullish bias, we want a grab of sell stops or equal lows
         if (currentBias == BIAS_BULLISH && 
            (m_recentGrabs[i].targetType == LIQ_SELL_STOPS || 
             m_recentGrabs[i].targetType == LIQ_EQUAL_LOWS)) {
            return true;
         }
         // For bearish bias, we want a grab of buy stops or equal highs
         else if (currentBias == BIAS_BEARISH && 
                 (m_recentGrabs[i].targetType == LIQ_BUY_STOPS || 
                  m_recentGrabs[i].targetType == LIQ_EQUAL_HIGHS)) {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if price is in a liquidity zone                            |
//+------------------------------------------------------------------+
bool CLiquidityAnalysis::IsInLiquidityZone(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias) {
   // Identify liquidity zones
   IdentifyLiquidityZones(timeframe);
   
   double currentPrice = iClose(_Symbol, timeframe, 0);
   
   // Check if price is near any of the identified liquidity zones
   for (int i = 0; i < ArraySize(m_liquidityZones); i++) {
      double upperBound = m_liquidityZones[i].level + m_liquidityZones[i].thickness;
      double lowerBound = m_liquidityZones[i].level - m_liquidityZones[i].thickness;
      
      // Price is within the zone
      if (currentPrice >= lowerBound && currentPrice <= upperBound) {
         // For bullish bias, we're interested in sell stop zones
         if (currentBias == BIAS_BULLISH && 
            (m_liquidityZones[i].type == LIQ_SELL_STOPS || 
             m_liquidityZones[i].type == LIQ_EQUAL_LOWS)) {
            return true;
         }
         // For bearish bias, we're interested in buy stop zones
         else if (currentBias == BIAS_BEARISH && 
                 (m_liquidityZones[i].type == LIQ_BUY_STOPS || 
                  m_liquidityZones[i].type == LIQ_EQUAL_HIGHS)) {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get a suitable stop loss level for a buy trade                   |
//+------------------------------------------------------------------+
double CLiquidityAnalysis::GetBuyStopLossLevel() {
   IdentifyLiquidityGrabs(PERIOD_CURRENT);
   
   for (int i = 0; i < ArraySize(m_recentGrabs); i++) {
      if (m_recentGrabs[i].isValid && 
         (m_recentGrabs[i].targetType == LIQ_SELL_STOPS || 
          m_recentGrabs[i].targetType == LIQ_EQUAL_LOWS)) {
         // SL below the sweep level with some buffer
         return m_recentGrabs[i].sweepLevel - (10 * _Point);
      }
   }
   
   return 0; // No suitable level found
}

//+------------------------------------------------------------------+
//| Get a suitable stop loss level for a sell trade                  |
//+------------------------------------------------------------------+
double CLiquidityAnalysis::GetSellStopLossLevel() {
   IdentifyLiquidityGrabs(PERIOD_CURRENT);
   
   for (int i = 0; i < ArraySize(m_recentGrabs); i++) {
      if (m_recentGrabs[i].isValid && 
         (m_recentGrabs[i].targetType == LIQ_BUY_STOPS || 
          m_recentGrabs[i].targetType == LIQ_EQUAL_HIGHS)) {
         // SL above the sweep level with some buffer
         return m_recentGrabs[i].sweepLevel + (10 * _Point);
      }
   }
   
   return 0; // No suitable level found
}

//+------------------------------------------------------------------+
//| Get a suitable take profit level for a buy trade                 |
//+------------------------------------------------------------------+
double CLiquidityAnalysis::GetBuyTakeProfitLevel() {
   IdentifyLiquidityZones(PERIOD_CURRENT);
   
   // Look for buy stops or equal highs that haven't been swept yet
   for (int i = 0; i < ArraySize(m_liquidityZones); i++) {
      if ((m_liquidityZones[i].type == LIQ_BUY_STOPS || 
           m_liquidityZones[i].type == LIQ_EQUAL_HIGHS) && 
          !m_liquidityZones[i].isSwept) {
         return m_liquidityZones[i].level;
      }
   }
   
   return 0; // No suitable level found
}

//+------------------------------------------------------------------+
//| Get a suitable take profit level for a sell trade                |
//+------------------------------------------------------------------+
double CLiquidityAnalysis::GetSellTakeProfitLevel() {
   IdentifyLiquidityZones(PERIOD_CURRENT);
   
   // Look for sell stops or equal lows that haven't been swept yet
   for (int i = 0; i < ArraySize(m_liquidityZones); i++) {
      if ((m_liquidityZones[i].type == LIQ_SELL_STOPS || 
           m_liquidityZones[i].type == LIQ_EQUAL_LOWS) && 
          !m_liquidityZones[i].isSwept) {
         return m_liquidityZones[i].level;
      }
   }
   
   return 0; // No suitable level found
}

//+------------------------------------------------------------------+
//| Convert liquidity type to string for logging                     |
//+------------------------------------------------------------------+
string CLiquidityAnalysis::LiquidityTypeToString(ENUM_LIQUIDITY_TYPE type) {
   switch (type) {
      case LIQ_BUY_STOPS: return "Buy Stops";
      case LIQ_SELL_STOPS: return "Sell Stops";
      case LIQ_EQUAL_HIGHS: return "Equal Highs";
      case LIQ_EQUAL_LOWS: return "Equal Lows";
      default: return "None";
   }
}
