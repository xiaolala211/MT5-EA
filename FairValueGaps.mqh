//+------------------------------------------------------------------+
//|                                              FairValueGaps.mqh   |
//|                        Smart Money Concepts Trading System       |
//|                                                                  |
//| Description: Class for identifying and analyzing Fair Value Gaps |
//| (FVG) across different timeframes.                               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property strict

// FVG type enumeration
enum ENUM_FVG_TYPE {
   FVG_NONE,    // No FVG
   FVG_BULLISH, // Bullish FVG (gap up)
   FVG_BEARISH  // Bearish FVG (gap down)
};

//+------------------------------------------------------------------+
//| FVG structure                                                    |
//+------------------------------------------------------------------+
struct FairValueGap {
   ENUM_FVG_TYPE type;           // Type of FVG
   datetime time;                // Time of the FVG formation (middle candle)
   double upperBound;            // Upper boundary of the FVG
   double lowerBound;            // Lower boundary of the FVG
   double size;                  // Size of the FVG in points
   bool isFilled;                // Whether the FVG has been filled/mitigated
   bool isFresh;                 // Whether the FVG is fresh (recent)
   
   // Constructor
   FairValueGap() {
      type = FVG_NONE;
      time = 0;
      upperBound = 0;
      lowerBound = 0;
      size = 0;
      isFilled = false;
      isFresh = false;
   }
};

//+------------------------------------------------------------------+
//| FairValueGaps class                                              |
//+------------------------------------------------------------------+
class CFairValueGaps {
private:
   int               m_lookback;            // Bars to look back for FVGs
   int               m_minSize;             // Minimum size in pips for FVG
   FairValueGap      m_recentBullishFVGs[]; // Array of recent bullish FVGs
   FairValueGap      m_recentBearishFVGs[]; // Array of recent bearish FVGs
   
   // Private methods
   void              IdentifyFVGs(ENUM_TIMEFRAME timeframe);
   bool              IsFVGFilled(FairValueGap &fvg, ENUM_TIMEFRAME timeframe);
   
public:
                     CFairValueGaps();
                    ~CFairValueGaps();
   
   // Initialization
   void              Initialize(int lookback, int minSize);
   
   // Analysis methods
   bool              IsInRelevantFVG(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias);
   bool              HasFreshFVG(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias);
   
   // Helper methods for trade execution
   double            GetBullishFVGLowerBound(ENUM_TIMEFRAME timeframe);
   double            GetBearishFVGUpperBound(ENUM_TIMEFRAME timeframe);
   double            GetFVGMiddle(ENUM_FVG_TYPE type, ENUM_TIMEFRAME timeframe);
   
   // Utility methods
   string            FVGTypeToString(ENUM_FVG_TYPE type);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFairValueGaps::CFairValueGaps() {
   m_lookback = 20;
   m_minSize = 5;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFairValueGaps::~CFairValueGaps() {
   ArrayFree(m_recentBullishFVGs);
   ArrayFree(m_recentBearishFVGs);
}

//+------------------------------------------------------------------+
//| Initialize the class with parameters                             |
//+------------------------------------------------------------------+
void CFairValueGaps::Initialize(int lookback, int minSize) {
   m_lookback = lookback;
   m_minSize = minSize;
}

//+------------------------------------------------------------------+
//| Identify Fair Value Gaps on the specified timeframe              |
//+------------------------------------------------------------------+
void CFairValueGaps::IdentifyFVGs(ENUM_TIMEFRAME timeframe) {
   // Clear existing FVGs
   ArrayFree(m_recentBullishFVGs);
   ArrayFree(m_recentBearishFVGs);
   
   // Initialize arrays
   ArrayResize(m_recentBullishFVGs, 0);
   ArrayResize(m_recentBearishFVGs, 0);
   
   // Loop through bars to find FVGs
   for (int i = m_lookback - 1; i >= 2; i--) {
      // Check for bullish FVG
      // In a bullish FVG, the low of candle1 is higher than the high of candle3
      double candle1Low = iLow(_Symbol, timeframe, i-1);
      double candle3High = iHigh(_Symbol, timeframe, i+1);
      
      if (candle1Low > candle3High) {
         // We have a bullish FVG
         FairValueGap fvg;
         fvg.type = FVG_BULLISH;
         fvg.time = iTime(_Symbol, timeframe, i);
         fvg.upperBound = candle1Low;
         fvg.lowerBound = candle3High;
         fvg.size = (fvg.upperBound - fvg.lowerBound) / _Point;
         
         // Check if the FVG is large enough to be significant
         if (fvg.size >= m_minSize) {
            // Check if the FVG has been filled by subsequent price action
            fvg.isFilled = IsFVGFilled(fvg, timeframe);
            
            // A FVG is considered "fresh" if it's one of the 3 most recent
            fvg.isFresh = ArraySize(m_recentBullishFVGs) < 3;
            
            // Add to array
            int size = ArraySize(m_recentBullishFVGs);
            ArrayResize(m_recentBullishFVGs, size + 1);
            m_recentBullishFVGs[size] = fvg;
         }
      }
      
      // Check for bearish FVG
      // In a bearish FVG, the high of candle1 is lower than the low of candle3
      double candle1High = iHigh(_Symbol, timeframe, i-1);
      double candle3Low = iLow(_Symbol, timeframe, i+1);
      
      if (candle1High < candle3Low) {
         // We have a bearish FVG
         FairValueGap fvg;
         fvg.type = FVG_BEARISH;
         fvg.time = iTime(_Symbol, timeframe, i);
         fvg.upperBound = candle3Low;
         fvg.lowerBound = candle1High;
         fvg.size = (fvg.upperBound - fvg.lowerBound) / _Point;
         
         // Check if the FVG is large enough to be significant
         if (fvg.size >= m_minSize) {
            // Check if the FVG has been filled by subsequent price action
            fvg.isFilled = IsFVGFilled(fvg, timeframe);
            
            // A FVG is considered "fresh" if it's one of the 3 most recent
            fvg.isFresh = ArraySize(m_recentBearishFVGs) < 3;
            
            // Add to array
            int size = ArraySize(m_recentBearishFVGs);
            ArrayResize(m_recentBearishFVGs, size + 1);
            m_recentBearishFVGs[size] = fvg;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if an FVG has been filled by subsequent price action       |
//+------------------------------------------------------------------+
bool CFairValueGaps::IsFVGFilled(FairValueGap &fvg, ENUM_TIMEFRAME timeframe) {
   // Get the index of the FVG's middle candle
   int fvgIndex = 0;
   
   for (int i = 0; i < m_lookback; i++) {
      if (iTime(_Symbol, timeframe, i) == fvg.time) {
         fvgIndex = i;
         break;
      }
   }
   
   // No matching candle found
   if (fvgIndex == 0 && iTime(_Symbol, timeframe, 0) != fvg.time) {
      return true; // Assume filled if we can't find the FVG
   }
   
   // Check all candles after the FVG for potential filling
   for (int i = fvgIndex - 1; i >= 0; i--) {
      if (fvg.type == FVG_BULLISH) {
         // For bullish FVG, check if any low is below the lower boundary
         if (iLow(_Symbol, timeframe, i) <= fvg.lowerBound) {
            return true;
         }
      } else {
         // For bearish FVG, check if any high is above the upper boundary
         if (iHigh(_Symbol, timeframe, i) >= fvg.upperBound) {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if current price is in a relevant FVG                      |
//+------------------------------------------------------------------+
bool CFairValueGaps::IsInRelevantFVG(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias) {
   // Identify FVGs first
   IdentifyFVGs(timeframe);
   
   double currentPrice = iClose(_Symbol, timeframe, 0);
   
   // For bullish bias, check if price is near the lower bound of a bullish FVG
   if (currentBias == BIAS_BULLISH) {
      for (int i = 0; i < ArraySize(m_recentBullishFVGs); i++) {
         if (!m_recentBullishFVGs[i].isFilled) {
            double lowerBound = m_recentBullishFVGs[i].lowerBound;
            double upperBound = m_recentBullishFVGs[i].upperBound;
            
            // Price near the lower boundary is a good entry
            if (currentPrice >= lowerBound && 
                currentPrice <= lowerBound + (upperBound - lowerBound) * 0.3) {
               return true;
            }
         }
      }
   }
   // For bearish bias, check if price is near the upper bound of a bearish FVG
   else if (currentBias == BIAS_BEARISH) {
      for (int i = 0; i < ArraySize(m_recentBearishFVGs); i++) {
         if (!m_recentBearishFVGs[i].isFilled) {
            double lowerBound = m_recentBearishFVGs[i].lowerBound;
            double upperBound = m_recentBearishFVGs[i].upperBound;
            
            // Price near the upper boundary is a good entry
            if (currentPrice <= upperBound && 
                currentPrice >= upperBound - (upperBound - lowerBound) * 0.3) {
               return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if a fresh FVG has formed on the timeframe                 |
//+------------------------------------------------------------------+
bool CFairValueGaps::HasFreshFVG(ENUM_TIMEFRAME timeframe, ENUM_BIAS currentBias) {
   // Identify FVGs first
   IdentifyFVGs(timeframe);
   
   // For bullish bias, check for fresh bullish FVGs that are not filled
   if (currentBias == BIAS_BULLISH) {
      for (int i = 0; i < ArraySize(m_recentBullishFVGs); i++) {
         if (m_recentBullishFVGs[i].isFresh && !m_recentBullishFVGs[i].isFilled) {
            return true;
         }
      }
   }
   // For bearish bias, check for fresh bearish FVGs that are not filled
   else if (currentBias == BIAS_BEARISH) {
      for (int i = 0; i < ArraySize(m_recentBearishFVGs); i++) {
         if (m_recentBearishFVGs[i].isFresh && !m_recentBearishFVGs[i].isFilled) {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get the lower bound of the most recent bullish FVG               |
//+------------------------------------------------------------------+
double CFairValueGaps::GetBullishFVGLowerBound(ENUM_TIMEFRAME timeframe) {
   // Identify FVGs first
   IdentifyFVGs(timeframe);
   
   for (int i = 0; i < ArraySize(m_recentBullishFVGs); i++) {
      if (!m_recentBullishFVGs[i].isFilled) {
         return m_recentBullishFVGs[i].lowerBound;
      }
   }
   
   return 0; // No valid FVG found
}

//+------------------------------------------------------------------+
//| Get the upper bound of the most recent bearish FVG               |
//+------------------------------------------------------------------+
double CFairValueGaps::GetBearishFVGUpperBound(ENUM_TIMEFRAME timeframe) {
   // Identify FVGs first
   IdentifyFVGs(timeframe);
   
   for (int i = 0; i < ArraySize(m_recentBearishFVGs); i++) {
      if (!m_recentBearishFVGs[i].isFilled) {
         return m_recentBearishFVGs[i].upperBound;
      }
   }
   
   return 0; // No valid FVG found
}

//+------------------------------------------------------------------+
//| Get the middle of a FVG for potential entry                      |
//+------------------------------------------------------------------+
double CFairValueGaps::GetFVGMiddle(ENUM_FVG_TYPE type, ENUM_TIMEFRAME timeframe) {
   // Identify FVGs first
   IdentifyFVGs(timeframe);
   
   if (type == FVG_BULLISH && ArraySize(m_recentBullishFVGs) > 0) {
      for (int i = 0; i < ArraySize(m_recentBullishFVGs); i++) {
         if (!m_recentBullishFVGs[i].isFilled) {
            return m_recentBullishFVGs[i].lowerBound + 
                  (m_recentBullishFVGs[i].upperBound - m_recentBullishFVGs[i].lowerBound) * 0.5;
         }
      }
   }
   else if (type == FVG_BEARISH && ArraySize(m_recentBearishFVGs) > 0) {
      for (int i = 0; i < ArraySize(m_recentBearishFVGs); i++) {
         if (!m_recentBearishFVGs[i].isFilled) {
            return m_recentBearishFVGs[i].lowerBound + 
                  (m_recentBearishFVGs[i].upperBound - m_recentBearishFVGs[i].lowerBound) * 0.5;
         }
      }
   }
   
   return 0; // No valid FVG found
}

//+------------------------------------------------------------------+
//| Convert FVG type to string for logging                           |
//+------------------------------------------------------------------+
string CFairValueGaps::FVGTypeToString(ENUM_FVG_TYPE type) {
   switch (type) {
      case FVG_BULLISH: return "Bullish FVG";
      case FVG_BEARISH: return "Bearish FVG";
      default: return "None";
   }
}
