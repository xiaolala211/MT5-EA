//+------------------------------------------------------------------+
//|                                             MarketStructure.mqh  |
//|                        Smart Money Concepts Trading System       |
//|                                                                  |
//| Description: Class for analyzing market structure (HH, HL, LH,   |
//| LL, BOS, CHoCH) across different timeframes.                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property strict

// Market structure type enumeration
enum ENUM_MARKET_STRUCTURE_TYPE {
   MS_NEUTRAL,    // No clear structure
   MS_UPTREND,    // Higher Highs and Higher Lows
   MS_DOWNTREND,  // Lower Highs and Lower Lows
   MS_ACCUMULATION, // Sideways after downtrend (potential reversal up)
   MS_DISTRIBUTION  // Sideways after uptrend (potential reversal down)
};

//+------------------------------------------------------------------+
//| MarketStructure class                                            |
//+------------------------------------------------------------------+
class CMarketStructure {
private:
   int               m_lookback;            // Bars to look back for structure
   int               m_swingStrength;       // Minimum number of bars to confirm a swing
   
   // Arrays to store structure points
   datetime          m_highSwingTimes[];    // Times of swing highs
   datetime          m_lowSwingTimes[];     // Times of swing lows
   double            m_highSwingValues[];   // Values of swing highs
   double            m_lowSwingValues[];    // Values of swing lows
   
   // Variables to track recent BOS and CHoCH
   datetime          m_lastBOSTime;         // Time of last BOS
   datetime          m_lastCHoCHTime;       // Time of last CHoCH
   ENUM_MARKET_STRUCTURE_TYPE m_lastStructure; // Last identified structure type
   
   // Private methods
   void              FindSwingPoints(ENUM_TIMEFRAME timeframe);
   bool              IsSwingHigh(int bar, int leftStrength, int rightStrength, ENUM_TIMEFRAME timeframe);
   bool              IsSwingLow(int bar, int leftStrength, int rightStrength, ENUM_TIMEFRAME timeframe);
   
public:
                     CMarketStructure();
                    ~CMarketStructure();
   
   // Initialization
   void              Initialize(int lookback, int swingStrength = 3);
   
   // Analysis methods
   ENUM_MARKET_STRUCTURE_TYPE AnalyzeStructure(ENUM_TIMEFRAME timeframe);
   bool              DetectBOS(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias);
   bool              DetectCHoCH(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias);
   
   // Helper methods for trade execution
   double            GetLastSignificantHigh(ENUM_TIMEFRAME timeframe);
   double            GetLastSignificantLow(ENUM_TIMEFRAME timeframe);
   
   // Utility methods
   string            MarketStructureToString(ENUM_MARKET_STRUCTURE_TYPE type);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMarketStructure::CMarketStructure() {
   m_lookback = 100;
   m_swingStrength = 3;
   m_lastBOSTime = 0;
   m_lastCHoCHTime = 0;
   m_lastStructure = MS_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMarketStructure::~CMarketStructure() {
   ArrayFree(m_highSwingTimes);
   ArrayFree(m_lowSwingTimes);
   ArrayFree(m_highSwingValues);
   ArrayFree(m_lowSwingValues);
}

//+------------------------------------------------------------------+
//| Initialize the class with parameters                             |
//+------------------------------------------------------------------+
void CMarketStructure::Initialize(int lookback, int swingStrength = 3) {
   m_lookback = lookback;
   m_swingStrength = swingStrength;
}

//+------------------------------------------------------------------+
//| Find swing points (highs and lows) on the specified timeframe    |
//+------------------------------------------------------------------+
void CMarketStructure::FindSwingPoints(ENUM_TIMEFRAME timeframe) {
   // Clear existing swing points
   ArrayFree(m_highSwingTimes);
   ArrayFree(m_lowSwingTimes);
   ArrayFree(m_highSwingValues);
   ArrayFree(m_lowSwingValues);
   
   // Initialize arrays
   ArrayResize(m_highSwingTimes, 0);
   ArrayResize(m_lowSwingTimes, 0);
   ArrayResize(m_highSwingValues, 0);
   ArrayResize(m_lowSwingValues, 0);
   
   // Loop through bars to find swing points
   for (int i = m_swingStrength; i < m_lookback - m_swingStrength; i++) {
      // Check for swing high
      if (IsSwingHigh(i, m_swingStrength, m_swingStrength, timeframe)) {
         ArrayResize(m_highSwingTimes, ArraySize(m_highSwingTimes) + 1);
         ArrayResize(m_highSwingValues, ArraySize(m_highSwingValues) + 1);
         
         m_highSwingTimes[ArraySize(m_highSwingTimes) - 1] = iTime(_Symbol, timeframe, i);
         m_highSwingValues[ArraySize(m_highSwingValues) - 1] = iHigh(_Symbol, timeframe, i);
      }
      
      // Check for swing low
      if (IsSwingLow(i, m_swingStrength, m_swingStrength, timeframe)) {
         ArrayResize(m_lowSwingTimes, ArraySize(m_lowSwingTimes) + 1);
         ArrayResize(m_lowSwingValues, ArraySize(m_lowSwingValues) + 1);
         
         m_lowSwingTimes[ArraySize(m_lowSwingTimes) - 1] = iTime(_Symbol, timeframe, i);
         m_lowSwingValues[ArraySize(m_lowSwingValues) - 1] = iLow(_Symbol, timeframe, i);
      }
   }
}

//+------------------------------------------------------------------+
//| Check if a bar is a swing high                                   |
//+------------------------------------------------------------------+
bool CMarketStructure::IsSwingHigh(int bar, int leftStrength, int rightStrength, ENUM_TIMEFRAME timeframe) {
   double currentHigh = iHigh(_Symbol, timeframe, bar);
   
   // Check bars to the left
   for (int i = 1; i <= leftStrength; i++) {
      if (iHigh(_Symbol, timeframe, bar - i) >= currentHigh) {
         return false;
      }
   }
   
   // Check bars to the right
   for (int i = 1; i <= rightStrength; i++) {
      if (iHigh(_Symbol, timeframe, bar + i) >= currentHigh) {
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if a bar is a swing low                                    |
//+------------------------------------------------------------------+
bool CMarketStructure::IsSwingLow(int bar, int leftStrength, int rightStrength, ENUM_TIMEFRAME timeframe) {
   double currentLow = iLow(_Symbol, timeframe, bar);
   
   // Check bars to the left
   for (int i = 1; i <= leftStrength; i++) {
      if (iLow(_Symbol, timeframe, bar - i) <= currentLow) {
         return false;
      }
   }
   
   // Check bars to the right
   for (int i = 1; i <= rightStrength; i++) {
      if (iLow(_Symbol, timeframe, bar + i) <= currentLow) {
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Analyze market structure to determine structure type             |
//+------------------------------------------------------------------+
ENUM_MARKET_STRUCTURE_TYPE CMarketStructure::AnalyzeStructure(ENUM_TIMEFRAME timeframe) {
   // Find swing points first
   FindSwingPoints(timeframe);
   
   // Not enough swing points to determine structure
   if (ArraySize(m_highSwingValues) < 3 || ArraySize(m_lowSwingValues) < 3) {
      return MS_NEUTRAL;
   }
   
   // Check for uptrend: consecutive HH and HL
   bool isUptrend = true;
   for (int i = 2; i < ArraySize(m_highSwingValues); i++) {
      if (m_highSwingValues[i] <= m_highSwingValues[i-2]) {
         isUptrend = false;
         break;
      }
   }
   
   for (int i = 2; i < ArraySize(m_lowSwingValues); i++) {
      if (m_lowSwingValues[i] <= m_lowSwingValues[i-2]) {
         isUptrend = false;
         break;
      }
   }
   
   if (isUptrend) {
      m_lastStructure = MS_UPTREND;
      return MS_UPTREND;
   }
   
   // Check for downtrend: consecutive LH and LL
   bool isDowntrend = true;
   for (int i = 2; i < ArraySize(m_highSwingValues); i++) {
      if (m_highSwingValues[i] >= m_highSwingValues[i-2]) {
         isDowntrend = false;
         break;
      }
   }
   
   for (int i = 2; i < ArraySize(m_lowSwingValues); i++) {
      if (m_lowSwingValues[i] >= m_lowSwingValues[i-2]) {
         isDowntrend = false;
         break;
      }
   }
   
   if (isDowntrend) {
      m_lastStructure = MS_DOWNTREND;
      return MS_DOWNTREND;
   }
   
   // Check for accumulation or distribution
   // Accumulation: price is in a range after a downtrend
   if (m_lastStructure == MS_DOWNTREND) {
      // Calculate range size
      double rangeHigh = m_highSwingValues[0];
      double rangeLow = m_lowSwingValues[0];
      
      for (int i = 1; i < MathMin(3, ArraySize(m_highSwingValues)); i++) {
         rangeHigh = MathMax(rangeHigh, m_highSwingValues[i]);
      }
      
      for (int i = 1; i < MathMin(3, ArraySize(m_lowSwingValues)); i++) {
         rangeLow = MathMin(rangeLow, m_lowSwingValues[i]);
      }
      
      // If range is relatively tight, it might be accumulation
      double rangeSize = rangeHigh - rangeLow;
      double avgRange = rangeSize / 3; // average over 3 swings
      
      // If average movement is small, consider it accumulation
      if (avgRange < 0.003 * rangeHigh) { // 0.3% threshold, adjust as needed
         m_lastStructure = MS_ACCUMULATION;
         return MS_ACCUMULATION;
      }
   }
   
   // Distribution: price is in a range after an uptrend
   if (m_lastStructure == MS_UPTREND) {
      // Calculate range size
      double rangeHigh = m_highSwingValues[0];
      double rangeLow = m_lowSwingValues[0];
      
      for (int i = 1; i < MathMin(3, ArraySize(m_highSwingValues)); i++) {
         rangeHigh = MathMax(rangeHigh, m_highSwingValues[i]);
      }
      
      for (int i = 1; i < MathMin(3, ArraySize(m_lowSwingValues)); i++) {
         rangeLow = MathMin(rangeLow, m_lowSwingValues[i]);
      }
      
      // If range is relatively tight, it might be distribution
      double rangeSize = rangeHigh - rangeLow;
      double avgRange = rangeSize / 3; // average over 3 swings
      
      // If average movement is small, consider it distribution
      if (avgRange < 0.003 * rangeHigh) { // 0.3% threshold, adjust as needed
         m_lastStructure = MS_DISTRIBUTION;
         return MS_DISTRIBUTION;
      }
   }
   
   // If no clear pattern, use previous structure or default to neutral
   return m_lastStructure != MS_NEUTRAL ? m_lastStructure : MS_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Detect Break of Structure (BOS) on the specified timeframe       |
//+------------------------------------------------------------------+
bool CMarketStructure::DetectBOS(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias) {
   // Find swing points
   FindSwingPoints(timeframe);
   
   // Not enough swing points to determine BOS
   if (ArraySize(m_highSwingValues) < 3 || ArraySize(m_lowSwingValues) < 3) {
      return false;
   }
   
   bool bos = false;
   datetime currentTime = iTime(_Symbol, timeframe, 0);
   
   // For bullish bias, look for price breaking above a previous significant high
   if (currentBias == BIAS_BULLISH) {
      double lastHigh = m_highSwingValues[1]; // Previous significant high
      double currentPrice = iClose(_Symbol, timeframe, 0);
      
      if (currentPrice > lastHigh) {
         bos = true;
      }
   }
   // For bearish bias, look for price breaking below a previous significant low
   else if (currentBias == BIAS_BEARISH) {
      double lastLow = m_lowSwingValues[1]; // Previous significant low
      double currentPrice = iClose(_Symbol, timeframe, 0);
      
      if (currentPrice < lastLow) {
         bos = true;
      }
   }
   
   // Check if this is a new BOS (not the same one we detected previously)
   if (bos && currentTime != m_lastBOSTime) {
      m_lastBOSTime = currentTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detect Change of Character (CHoCH) on the specified timeframe    |
//+------------------------------------------------------------------+
bool CMarketStructure::DetectCHoCH(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias) {
   // Find swing points
   FindSwingPoints(timeframe);
   
   // Not enough swing points to determine CHoCH
   if (ArraySize(m_highSwingValues) < 3 || ArraySize(m_lowSwingValues) < 3) {
      return false;
   }
   
   bool choch = false;
   datetime currentTime = iTime(_Symbol, timeframe, 0);
   
   // For bullish bias, look for a higher low after a series of lower lows
   if (currentBias == BIAS_BULLISH) {
      // Check if the most recent low is higher than the previous low
      // but we were previously in a downtrend (consecutive lower lows)
      if (m_lowSwingValues[0] > m_lowSwingValues[1] && 
          m_lowSwingValues[1] < m_lowSwingValues[2]) {
         choch = true;
      }
   }
   // For bearish bias, look for a lower high after a series of higher highs
   else if (currentBias == BIAS_BEARISH) {
      // Check if the most recent high is lower than the previous high
      // but we were previously in an uptrend (consecutive higher highs)
      if (m_highSwingValues[0] < m_highSwingValues[1] && 
          m_highSwingValues[1] > m_highSwingValues[2]) {
         choch = true;
      }
   }
   
   // Check if this is a new CHoCH (not the same one we detected previously)
   if (choch && currentTime != m_lastCHoCHTime) {
      m_lastCHoCHTime = currentTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get the last significant high for SL placement                   |
//+------------------------------------------------------------------+
double CMarketStructure::GetLastSignificantHigh(ENUM_TIMEFRAME timeframe) {
   FindSwingPoints(timeframe);
   
   if (ArraySize(m_highSwingValues) > 0) {
      return m_highSwingValues[0];
   }
   
   // If no swing high found, return current high plus a buffer
   return iHigh(_Symbol, timeframe, 0) + (10 * _Point);
}

//+------------------------------------------------------------------+
//| Get the last significant low for SL placement                    |
//+------------------------------------------------------------------+
double CMarketStructure::GetLastSignificantLow(ENUM_TIMEFRAME timeframe) {
   FindSwingPoints(timeframe);
   
   if (ArraySize(m_lowSwingValues) > 0) {
      return m_lowSwingValues[0];
   }
   
   // If no swing low found, return current low minus a buffer
   return iLow(_Symbol, timeframe, 0) - (10 * _Point);
}

//+------------------------------------------------------------------+
//| Convert market structure type to string for logging              |
//+------------------------------------------------------------------+
string CMarketStructure::MarketStructureToString(ENUM_MARKET_STRUCTURE_TYPE type) {
   switch (type) {
      case MS_UPTREND: return "Uptrend";
      case MS_DOWNTREND: return "Downtrend";
      case MS_ACCUMULATION: return "Accumulation";
      case MS_DISTRIBUTION: return "Distribution";
      default: return "Neutral";
   }
}
