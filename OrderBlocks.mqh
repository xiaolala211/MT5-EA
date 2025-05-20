//+------------------------------------------------------------------+
//|                                                 OrderBlocks.mqh  |
//|                        Smart Money Concepts Trading System       |
//|                                                                  |
//| Description: Class for identifying and analyzing Order Blocks    |
//| (OB) across different timeframes.                                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property strict

// Order Block type enumeration
enum ENUM_ORDER_BLOCK_TYPE {
   OB_NONE,        // No Order Block
   OB_BULLISH,     // Bullish Order Block (down candle before up move)
   OB_BEARISH,     // Bearish Order Block (up candle before down move)
   OB_BREAKER_BULLISH, // Bullish Breaker Block
   OB_BREAKER_BEARISH, // Bearish Breaker Block
   OB_MITIGATION_BULLISH, // Bullish Mitigation Block
   OB_MITIGATION_BEARISH  // Bearish Mitigation Block
};

//+------------------------------------------------------------------+
//| Order Block structure                                            |
//+------------------------------------------------------------------+
struct OrderBlock {
   ENUM_ORDER_BLOCK_TYPE type;    // Type of Order Block
   datetime time;                 // Time of the Order Block candle
   double high;                   // High of the Order Block
   double low;                    // Low of the Order Block
   double open;                   // Open of the Order Block
   double close;                  // Close of the Order Block
   bool isFresh;                  // Whether the OB is fresh (not tested yet)
   
   // Constructor
   OrderBlock() {
      type = OB_NONE;
      time = 0;
      high = 0;
      low = 0;
      open = 0;
      close = 0;
      isFresh = false;
   }
};

//+------------------------------------------------------------------+
//| OrderBlocks class                                                |
//+------------------------------------------------------------------+
class COrderBlocks {
private:
   int               m_lookback;            // Bars to look back for OBs
   int               m_minPipsForLG;        // Minimum pips for liquidity grab
   OrderBlock        m_recentBullishOBs[];  // Array of recent bullish OBs
   OrderBlock        m_recentBearishOBs[];  // Array of recent bearish OBs
   
   // Private methods
   bool              IsValidBullishOB(int potentialOBIndex, ENUM_TIMEFRAME timeframe);
   bool              IsValidBearishOB(int potentialOBIndex, ENUM_TIMEFRAME timeframe);
   double            CalculateImpulseStrength(int startIndex, int endIndex, ENUM_TIMEFRAME timeframe);
   void              IdentifyOrderBlocks(ENUM_TIMEFRAME timeframe);
   
public:
                     COrderBlocks();
                    ~COrderBlocks();
   
   // Initialization
   void              Initialize(int lookback, int minPipsForLG);
   
   // Analysis methods
   bool              IsInRelevantOrderBlock(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias);
   bool              HasFreshOrderBlock(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias);
   
   // Helper methods for trade execution
   double            GetBullishOBLow(ENUM_TIMEFRAME timeframe);
   double            GetBearishOBHigh(ENUM_TIMEFRAME timeframe);
   
   // Utility methods
   string            OrderBlockTypeToString(ENUM_ORDER_BLOCK_TYPE type);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COrderBlocks::COrderBlocks() {
   m_lookback = 20;
   m_minPipsForLG = 10;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
COrderBlocks::~COrderBlocks() {
   ArrayFree(m_recentBullishOBs);
   ArrayFree(m_recentBearishOBs);
}

//+------------------------------------------------------------------+
//| Initialize the class with parameters                             |
//+------------------------------------------------------------------+
void COrderBlocks::Initialize(int lookback, int minPipsForLG) {
   m_lookback = lookback;
   m_minPipsForLG = minPipsForLG;
}

//+------------------------------------------------------------------+
//| Check if a candle is a valid bullish Order Block                 |
//+------------------------------------------------------------------+
bool COrderBlocks::IsValidBullishOB(int potentialOBIndex, ENUM_TIMEFRAME timeframe) {
   // A bullish OB is a down candle (close < open) before a strong up move
   
   // Check if it's a down candle
   if (iClose(_Symbol, timeframe, potentialOBIndex) >= iOpen(_Symbol, timeframe, potentialOBIndex)) {
      return false;
   }
   
   // Look for a strong impulse move up after this candle
   double impulseStrength = CalculateImpulseStrength(potentialOBIndex, potentialOBIndex - 3, timeframe);
   
   // The impulse should be strong and in the opposite direction (up)
   if (impulseStrength <= 0 || impulseStrength < m_minPipsForLG * _Point) {
      return false;
   }
   
   // Additional check: the low of the potential OB should be lower than the low of the next candle
   if (iLow(_Symbol, timeframe, potentialOBIndex) >= iLow(_Symbol, timeframe, potentialOBIndex - 1)) {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if a candle is a valid bearish Order Block                 |
//+------------------------------------------------------------------+
bool COrderBlocks::IsValidBearishOB(int potentialOBIndex, ENUM_TIMEFRAME timeframe) {
   // A bearish OB is an up candle (close > open) before a strong down move
   
   // Check if it's an up candle
   if (iClose(_Symbol, timeframe, potentialOBIndex) <= iOpen(_Symbol, timeframe, potentialOBIndex)) {
      return false;
   }
   
   // Look for a strong impulse move down after this candle
   double impulseStrength = CalculateImpulseStrength(potentialOBIndex, potentialOBIndex - 3, timeframe);
   
   // The impulse should be strong and in the opposite direction (down)
   if (impulseStrength >= 0 || MathAbs(impulseStrength) < m_minPipsForLG * _Point) {
      return false;
   }
   
   // Additional check: the high of the potential OB should be higher than the high of the next candle
   if (iHigh(_Symbol, timeframe, potentialOBIndex) <= iHigh(_Symbol, timeframe, potentialOBIndex - 1)) {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate the strength of an impulse move                        |
//+------------------------------------------------------------------+
double COrderBlocks::CalculateImpulseStrength(int startIndex, int endIndex, ENUM_TIMEFRAME timeframe) {
   if (startIndex <= endIndex) return 0; // Invalid indices
   
   // Calculate the net price movement from start to end
   double startPrice = iClose(_Symbol, timeframe, startIndex);
   double endPrice = iClose(_Symbol, timeframe, endIndex);
   
   return endPrice - startPrice;
}

//+------------------------------------------------------------------+
//| Identify Order Blocks on the specified timeframe                 |
//+------------------------------------------------------------------+
void COrderBlocks::IdentifyOrderBlocks(ENUM_TIMEFRAME timeframe) {
   // Clear existing OBs
   ArrayFree(m_recentBullishOBs);
   ArrayFree(m_recentBearishOBs);
   
   // Initialize arrays
   ArrayResize(m_recentBullishOBs, 0);
   ArrayResize(m_recentBearishOBs, 0);
   
   // Loop through bars to find OBs
   for (int i = m_lookback - 1; i >= 3; i--) {
      // Check for bullish OB
      if (IsValidBullishOB(i, timeframe)) {
         OrderBlock ob;
         ob.type = OB_BULLISH;
         ob.time = iTime(_Symbol, timeframe, i);
         ob.high = iHigh(_Symbol, timeframe, i);
         ob.low = iLow(_Symbol, timeframe, i);
         ob.open = iOpen(_Symbol, timeframe, i);
         ob.close = iClose(_Symbol, timeframe, i);
         ob.isFresh = true; // Assume it's fresh until we check
         
         // Check if this OB has been tested (price returned to it)
         for (int j = i - 1; j >= 0; j--) {
            if (iLow(_Symbol, timeframe, j) <= ob.low) {
               ob.isFresh = false;
               break;
            }
         }
         
         // Add to array
         int size = ArraySize(m_recentBullishOBs);
         ArrayResize(m_recentBullishOBs, size + 1);
         m_recentBullishOBs[size] = ob;
      }
      
      // Check for bearish OB
      if (IsValidBearishOB(i, timeframe)) {
         OrderBlock ob;
         ob.type = OB_BEARISH;
         ob.time = iTime(_Symbol, timeframe, i);
         ob.high = iHigh(_Symbol, timeframe, i);
         ob.low = iLow(_Symbol, timeframe, i);
         ob.open = iOpen(_Symbol, timeframe, i);
         ob.close = iClose(_Symbol, timeframe, i);
         ob.isFresh = true; // Assume it's fresh until we check
         
         // Check if this OB has been tested (price returned to it)
         for (int j = i - 1; j >= 0; j--) {
            if (iHigh(_Symbol, timeframe, j) >= ob.high) {
               ob.isFresh = false;
               break;
            }
         }
         
         // Add to array
         int size = ArraySize(m_recentBearishOBs);
         ArrayResize(m_recentBearishOBs, size + 1);
         m_recentBearishOBs[size] = ob;
      }
   }
   
   // Check for breaker blocks and mitigation blocks
   // This is a more complex analysis that tracks how OBs get broken
   // For simplicity, we'll skip this detailed implementation
}

//+------------------------------------------------------------------+
//| Check if current price is in a relevant Order Block              |
//+------------------------------------------------------------------+
bool COrderBlocks::IsInRelevantOrderBlock(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias) {
   // Identify OBs first
   IdentifyOrderBlocks(timeframe);
   
   double currentPrice = iClose(_Symbol, timeframe, 0);
   
   // For bullish bias, check if price is in a bullish OB
   if (currentBias == BIAS_BULLISH) {
      for (int i = 0; i < ArraySize(m_recentBullishOBs); i++) {
         // Price should be near the OB's low for optimal entry
         if (currentPrice >= m_recentBullishOBs[i].low && 
             currentPrice <= m_recentBullishOBs[i].low + (m_recentBullishOBs[i].high - m_recentBullishOBs[i].low) * 0.5) {
            return true;
         }
      }
   }
   // For bearish bias, check if price is in a bearish OB
   else if (currentBias == BIAS_BEARISH) {
      for (int i = 0; i < ArraySize(m_recentBearishOBs); i++) {
         // Price should be near the OB's high for optimal entry
         if (currentPrice <= m_recentBearishOBs[i].high && 
             currentPrice >= m_recentBearishOBs[i].high - (m_recentBearishOBs[i].high - m_recentBearishOBs[i].low) * 0.5) {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if a fresh Order Block has formed on the timeframe         |
//+------------------------------------------------------------------+
bool COrderBlocks::HasFreshOrderBlock(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias) {
   // Identify OBs first
   IdentifyOrderBlocks(timeframe);
   
   // For bullish bias, check for fresh bullish OBs
   if (currentBias == BIAS_BULLISH) {
      for (int i = 0; i < ArraySize(m_recentBullishOBs); i++) {
         if (m_recentBullishOBs[i].isFresh) {
            return true;
         }
      }
   }
   // For bearish bias, check for fresh bearish OBs
   else if (currentBias == BIAS_BEARISH) {
      for (int i = 0; i < ArraySize(m_recentBearishOBs); i++) {
         if (m_recentBearishOBs[i].isFresh) {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get the low of the most recent bullish OB for entry/SL           |
//+------------------------------------------------------------------+
double COrderBlocks::GetBullishOBLow(ENUM_TIMEFRAME timeframe) {
   // Identify OBs first
   IdentifyOrderBlocks(timeframe);
   
   if (ArraySize(m_recentBullishOBs) > 0) {
      // Return the low of the most recent bullish OB
      return m_recentBullishOBs[0].low;
   }
   
   return 0; // No valid OB found
}

//+------------------------------------------------------------------+
//| Get the high of the most recent bearish OB for entry/SL          |
//+------------------------------------------------------------------+
double COrderBlocks::GetBearishOBHigh(ENUM_TIMEFRAME timeframe) {
   // Identify OBs first
   IdentifyOrderBlocks(timeframe);
   
   if (ArraySize(m_recentBearishOBs) > 0) {
      // Return the high of the most recent bearish OB
      return m_recentBearishOBs[0].high;
   }
   
   return 0; // No valid OB found
}

//+------------------------------------------------------------------+
//| Convert Order Block type to string for logging                   |
//+------------------------------------------------------------------+
string COrderBlocks::OrderBlockTypeToString(ENUM_ORDER_BLOCK_TYPE type) {
   switch (type) {
      case OB_BULLISH: return "Bullish OB";
      case OB_BEARISH: return "Bearish OB";
      case OB_BREAKER_BULLISH: return "Bullish Breaker";
      case OB_BREAKER_BEARISH: return "Bearish Breaker";
      case OB_MITIGATION_BULLISH: return "Bullish Mitigation";
      case OB_MITIGATION_BEARISH: return "Bearish Mitigation";
      default: return "None";
   }
}
