//+------------------------------------------------------------------+
//|                                              WyckoffPhases.mqh   |
//|                        Smart Money Concepts Trading System       |
//|                                                                  |
//| Description: Class for identifying and analyzing market phases   |
//| based on Wyckoff principles and Accumulation-Manipulation-       |
//| Distribution (AMD) cycle.                                        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property strict

// Market phase enumeration
enum ENUM_MARKET_PHASE {
   PHASE_UNKNOWN,               // Unknown phase
   PHASE_ACCUMULATION_EARLY,    // Early accumulation (Phase A)
   PHASE_ACCUMULATION_MID,      // Mid accumulation (Phase B)
   PHASE_ACCUMULATION_LATE,     // Late accumulation (Phase C & D)
   PHASE_MARKUP,                // Markup (Phase E)
   PHASE_DISTRIBUTION_EARLY,    // Early distribution (Phase A)
   PHASE_DISTRIBUTION_MID,      // Mid distribution (Phase B)
   PHASE_DISTRIBUTION_LATE,     // Late distribution (Phase C & D)
   PHASE_MARKDOWN                // Markdown (Phase E)
};

// Wyckoff events enumeration
enum ENUM_WYCKOFF_EVENT {
   EVENT_NONE,                 // No specific event
   EVENT_PS,                   // Preliminary Support
   EVENT_SC,                   // Selling Climax
   EVENT_AR,                   // Automatic Rally
   EVENT_ST,                   // Secondary Test
   EVENT_SPRING,               // Spring (in Accumulation)
   EVENT_PSY,                  // Preliminary Supply
   EVENT_BC,                   // Buying Climax
   EVENT_AR_DIST,              // Automatic Reaction (in Distribution)
   EVENT_ST_DIST,              // Secondary Test (in Distribution)
   EVENT_UPTHRUST,             // Upthrust (in Distribution)
   EVENT_SOW,                  // Sign of Weakness
   EVENT_SOS,                  // Sign of Strength
   EVENT_UTAD                  // Upthrust After Distribution
};

//+------------------------------------------------------------------+
//| WyckoffPhases class                                              |
//+------------------------------------------------------------------+
class CWyckoffPhases {
private:
   int               m_lookback;            // Bars to look back for analysis
   bool              m_volumeAvailable;     // Whether volume data is available
   ENUM_MARKET_PHASE m_currentPhase;        // Current market phase
   ENUM_WYCKOFF_EVENT m_recentEvents[];     // Recent Wyckoff events

   // Private methods
   void              IdentifyWyckoffEvents(ENUM_TIMEFRAME timeframe);
   bool              DetectSellingClimax(int bar, ENUM_TIMEFRAME timeframe);
   bool              DetectBuyingClimax(int bar, ENUM_TIMEFRAME timeframe);
   bool              DetectSpring(int bar, ENUM_TIMEFRAME timeframe);
   bool              DetectUpthrust(int bar, ENUM_TIMEFRAME timeframe);
   bool              DetectSignOfStrength(int bar, ENUM_TIMEFRAME timeframe);
   bool              DetectSignOfWeakness(int bar, ENUM_TIMEFRAME timeframe);
   bool              IsVolumeSpiking(int bar, ENUM_TIMEFRAME timeframe);
   bool              IsPriceInRange(int startBar, int endBar, ENUM_TIMEFRAME timeframe);

public:
                     CWyckoffPhases();
                    ~CWyckoffPhases();

   // Initialization
   void              Initialize(int lookback);

   // Analysis methods
   ENUM_MARKET_PHASE DetermineMarketPhase(ENUM_TIMEFRAME timeframe);
   bool              IsInAccumulation(ENUM_TIMEFRAME timeframe);
   bool              IsInDistribution(ENUM_TIMEFRAME timeframe);
   
   // Helper methods
   string            MarketPhaseToString(ENUM_MARKET_PHASE phase);
   string            WyckoffEventToString(ENUM_WYCKOFF_EVENT event);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CWyckoffPhases::CWyckoffPhases() {
   m_lookback = 100;
   m_currentPhase = PHASE_UNKNOWN;
   m_volumeAvailable = true; // Assume volume data is available
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CWyckoffPhases::~CWyckoffPhases() {
   ArrayFree(m_recentEvents);
}

//+------------------------------------------------------------------+
//| Initialize the class with parameters                             |
//+------------------------------------------------------------------+
void CWyckoffPhases::Initialize(int lookback) {
   m_lookback = lookback;
   
   // Check if volume data is available
   m_volumeAvailable = (iVolume(_Symbol, PERIOD_CURRENT, 0) > 0);
}

//+------------------------------------------------------------------+
//| Identify Wyckoff events on the specified timeframe               |
//+------------------------------------------------------------------+
void CWyckoffPhases::IdentifyWyckoffEvents(ENUM_TIMEFRAME timeframe) {
   // Clear existing events
   ArrayFree(m_recentEvents);
   
   // Initialize array
   ArrayResize(m_recentEvents, 0);
   
   // We need at least 50 bars for reliable Wyckoff analysis
   if (m_lookback < 50) {
      m_lookback = 50;
   }
   
   // Loop through bars to find Wyckoff events
   for (int i = m_lookback - 1; i >= 5; i--) {
      ENUM_WYCKOFF_EVENT event = EVENT_NONE;
      
      // Detect Selling Climax
      if (DetectSellingClimax(i, timeframe)) {
         event = EVENT_SC;
      }
      // Detect Buying Climax
      else if (DetectBuyingClimax(i, timeframe)) {
         event = EVENT_BC;
      }
      // Detect Spring
      else if (DetectSpring(i, timeframe)) {
         event = EVENT_SPRING;
      }
      // Detect Upthrust
      else if (DetectUpthrust(i, timeframe)) {
         event = EVENT_UPTHRUST;
      }
      // Detect Sign of Strength
      else if (DetectSignOfStrength(i, timeframe)) {
         event = EVENT_SOS;
      }
      // Detect Sign of Weakness
      else if (DetectSignOfWeakness(i, timeframe)) {
         event = EVENT_SOW;
      }
      
      // If we detected an event, add it to the array
      if (event != EVENT_NONE) {
         int size = ArraySize(m_recentEvents);
         ArrayResize(m_recentEvents, size + 1);
         m_recentEvents[size] = event;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect a Selling Climax                                          |
//+------------------------------------------------------------------+
bool CWyckoffPhases::DetectSellingClimax(int bar, ENUM_TIMEFRAME timeframe) {
   // Need at least 10 bars before this one
   if (bar < 10) return false;
   
   // Check for a significant price drop
   double rangeBefore = 0;
   for (int i = bar + 10; i > bar; i--) {
      rangeBefore += MathAbs(iHigh(_Symbol, timeframe, i) - iLow(_Symbol, timeframe, i));
   }
   rangeBefore /= 10; // Average daily range
   
   // Current bar should have a significant range with close near the low
   double currentRange = iHigh(_Symbol, timeframe, bar) - iLow(_Symbol, timeframe, bar);
   bool isLongRange = currentRange > rangeBefore * 1.5;
   bool closesNearLow = (iClose(_Symbol, timeframe, bar) - iLow(_Symbol, timeframe, bar)) < (currentRange * 0.3);
   
   // Check volume if available
   bool hasHighVolume = IsVolumeSpiking(bar, timeframe);
   
   // Check for price reversal after this bar
   bool reverses = false;
   if (bar >= 3) {
      reverses = iClose(_Symbol, timeframe, bar-1) > iOpen(_Symbol, timeframe, bar-1) &&
                 iClose(_Symbol, timeframe, bar-2) > iOpen(_Symbol, timeframe, bar-2) &&
                 iClose(_Symbol, timeframe, bar-3) > iOpen(_Symbol, timeframe, bar-3);
   }
   
   return isLongRange && closesNearLow && (hasHighVolume || !m_volumeAvailable) && reverses;
}

//+------------------------------------------------------------------+
//| Detect a Buying Climax                                           |
//+------------------------------------------------------------------+
bool CWyckoffPhases::DetectBuyingClimax(int bar, ENUM_TIMEFRAME timeframe) {
   // Need at least 10 bars before this one
   if (bar < 10) return false;
   
   // Check for a significant price rise
   double rangeBefore = 0;
   for (int i = bar + 10; i > bar; i--) {
      rangeBefore += MathAbs(iHigh(_Symbol, timeframe, i) - iLow(_Symbol, timeframe, i));
   }
   rangeBefore /= 10; // Average daily range
   
   // Current bar should have a significant range with close near the high
   double currentRange = iHigh(_Symbol, timeframe, bar) - iLow(_Symbol, timeframe, bar);
   bool isLongRange = currentRange > rangeBefore * 1.5;
   bool closesNearHigh = (iHigh(_Symbol, timeframe, bar) - iClose(_Symbol, timeframe, bar)) < (currentRange * 0.3);
   
   // Check volume if available
   bool hasHighVolume = IsVolumeSpiking(bar, timeframe);
   
   // Check for price reversal after this bar
   bool reverses = false;
   if (bar >= 3) {
      reverses = iClose(_Symbol, timeframe, bar-1) < iOpen(_Symbol, timeframe, bar-1) &&
                 iClose(_Symbol, timeframe, bar-2) < iOpen(_Symbol, timeframe, bar-2) &&
                 iClose(_Symbol, timeframe, bar-3) < iOpen(_Symbol, timeframe, bar-3);
   }
   
   return isLongRange && closesNearHigh && (hasHighVolume || !m_volumeAvailable) && reverses;
}

//+------------------------------------------------------------------+
//| Detect a Spring (in Accumulation)                                |
//+------------------------------------------------------------------+
bool CWyckoffPhases::DetectSpring(int bar, ENUM_TIMEFRAME timeframe) {
   // Need at least 20 bars before this for proper context
   if (bar < 20) return false;
   
   // First, verify we're in a trading range (potential accumulation)
   if (!IsPriceInRange(bar + 20, bar, timeframe)) return false;
   
   // Calculate the trading range
   double rangeHigh = -DBL_MAX;
   double rangeLow = DBL_MAX;
   
   for (int i = bar + 20; i > bar; i--) {
      rangeHigh = MathMax(rangeHigh, iHigh(_Symbol, timeframe, i));
      rangeLow = MathMin(rangeLow, iLow(_Symbol, timeframe, i));
   }
   
   // A spring occurs when price briefly breaks below the trading range but closes back inside
   bool breaksBelow = iLow(_Symbol, timeframe, bar) < rangeLow;
   bool closesInside = iClose(_Symbol, timeframe, bar) > rangeLow;
   
   // Check for bullish follow-through
   bool bullishFollowThrough = false;
   if (bar >= 3) {
      bullishFollowThrough = iClose(_Symbol, timeframe, bar-1) > iOpen(_Symbol, timeframe, bar-1) &&
                             iClose(_Symbol, timeframe, bar-2) > iOpen(_Symbol, timeframe, bar-2) &&
                             iClose(_Symbol, timeframe, bar-3) > iOpen(_Symbol, timeframe, bar-3);
   }
   
   return breaksBelow && closesInside && bullishFollowThrough;
}

//+------------------------------------------------------------------+
//| Detect an Upthrust (in Distribution)                             |
//+------------------------------------------------------------------+
bool CWyckoffPhases::DetectUpthrust(int bar, ENUM_TIMEFRAME timeframe) {
   // Need at least 20 bars before this for proper context
   if (bar < 20) return false;
   
   // First, verify we're in a trading range (potential distribution)
   if (!IsPriceInRange(bar + 20, bar, timeframe)) return false;
   
   // Calculate the trading range
   double rangeHigh = -DBL_MAX;
   double rangeLow = DBL_MAX;
   
   for (int i = bar + 20; i > bar; i--) {
      rangeHigh = MathMax(rangeHigh, iHigh(_Symbol, timeframe, i));
      rangeLow = MathMin(rangeLow, iLow(_Symbol, timeframe, i));
   }
   
   // An upthrust occurs when price briefly breaks above the trading range but closes back inside
   bool breaksAbove = iHigh(_Symbol, timeframe, bar) > rangeHigh;
   bool closesInside = iClose(_Symbol, timeframe, bar) < rangeHigh;
   
   // Check for bearish follow-through
   bool bearishFollowThrough = false;
   if (bar >= 3) {
      bearishFollowThrough = iClose(_Symbol, timeframe, bar-1) < iOpen(_Symbol, timeframe, bar-1) &&
                             iClose(_Symbol, timeframe, bar-2) < iOpen(_Symbol, timeframe, bar-2) &&
                             iClose(_Symbol, timeframe, bar-3) < iOpen(_Symbol, timeframe, bar-3);
   }
   
   return breaksAbove && closesInside && bearishFollowThrough;
}

//+------------------------------------------------------------------+
//| Detect a Sign of Strength                                        |
//+------------------------------------------------------------------+
bool CWyckoffPhases::DetectSignOfStrength(int bar, ENUM_TIMEFRAME timeframe) {
   // Need at least 5 bars before this for proper context
   if (bar < 5) return false;
   
   // Look for a strong up move with increasing volume
   bool strongUpMove = iClose(_Symbol, timeframe, bar) > iOpen(_Symbol, timeframe, bar) &&
                      iClose(_Symbol, timeframe, bar) > iClose(_Symbol, timeframe, bar+1) &&
                      iClose(_Symbol, timeframe, bar) > iClose(_Symbol, timeframe, bar+2) &&
                      iClose(_Symbol, timeframe, bar) > iClose(_Symbol, timeframe, bar+3);
   
   // Check for expanding volume if available
   bool expandingVolume = false;
   if (m_volumeAvailable) {
      expandingVolume = iVolume(_Symbol, timeframe, bar) > iVolume(_Symbol, timeframe, bar+1) &&
                        iVolume(_Symbol, timeframe, bar) > iVolume(_Symbol, timeframe, bar+2);
   }
   
   // Check for follow-through
   bool followThrough = false;
   if (bar >= 2) {
      followThrough = iClose(_Symbol, timeframe, bar-1) > iClose(_Symbol, timeframe, bar) &&
                      iClose(_Symbol, timeframe, bar-2) > iClose(_Symbol, timeframe, bar-1);
   }
   
   return strongUpMove && (expandingVolume || !m_volumeAvailable) && followThrough;
}

//+------------------------------------------------------------------+
//| Detect a Sign of Weakness                                        |
//+------------------------------------------------------------------+
bool CWyckoffPhases::DetectSignOfWeakness(int bar, ENUM_TIMEFRAME timeframe) {
   // Need at least 5 bars before this for proper context
   if (bar < 5) return false;
   
   // Look for a strong down move with increasing volume
   bool strongDownMove = iClose(_Symbol, timeframe, bar) < iOpen(_Symbol, timeframe, bar) &&
                        iClose(_Symbol, timeframe, bar) < iClose(_Symbol, timeframe, bar+1) &&
                        iClose(_Symbol, timeframe, bar) < iClose(_Symbol, timeframe, bar+2) &&
                        iClose(_Symbol, timeframe, bar) < iClose(_Symbol, timeframe, bar+3);
   
   // Check for expanding volume if available
   bool expandingVolume = false;
   if (m_volumeAvailable) {
      expandingVolume = iVolume(_Symbol, timeframe, bar) > iVolume(_Symbol, timeframe, bar+1) &&
                        iVolume(_Symbol, timeframe, bar) > iVolume(_Symbol, timeframe, bar+2);
   }
   
   // Check for follow-through
   bool followThrough = false;
   if (bar >= 2) {
      followThrough = iClose(_Symbol, timeframe, bar-1) < iClose(_Symbol, timeframe, bar) &&
                      iClose(_Symbol, timeframe, bar-2) < iClose(_Symbol, timeframe, bar-1);
   }
   
   return strongDownMove && (expandingVolume || !m_volumeAvailable) && followThrough;
}

//+------------------------------------------------------------------+
//| Check if volume is spiking (significantly higher than average)   |
//+------------------------------------------------------------------+
bool CWyckoffPhases::IsVolumeSpiking(int bar, ENUM_TIMEFRAME timeframe) {
   if (!m_volumeAvailable) return false;
   
   // Calculate average volume over the last 20 bars
   double avgVolume = 0;
   for (int i = bar + 1; i <= bar + 20; i++) {
      avgVolume += iVolume(_Symbol, timeframe, i);
   }
   avgVolume /= 20;
   
   // Check if current volume is significantly higher than average
   return iVolume(_Symbol, timeframe, bar) > (avgVolume * 1.5);
}

//+------------------------------------------------------------------+
//| Check if price is trading in a range                             |
//+------------------------------------------------------------------+
bool CWyckoffPhases::IsPriceInRange(int startBar, int endBar, ENUM_TIMEFRAME timeframe) {
   if (startBar <= endBar) return false;
   
   // Calculate highest high and lowest low
   double highestHigh = -DBL_MAX;
   double lowestLow = DBL_MAX;
   
   for (int i = startBar; i >= endBar; i--) {
      highestHigh = MathMax(highestHigh, iHigh(_Symbol, timeframe, i));
      lowestLow = MathMin(lowestLow, iLow(_Symbol, timeframe, i));
   }
   
   // Calculate the range height as a percentage of the average price
   double avgPrice = (highestHigh + lowestLow) / 2;
   double rangePercent = (highestHigh - lowestLow) / avgPrice * 100;
   
   // If the range is less than 7%, consider it a trading range
   // Adjust this percentage based on the specific asset's volatility
   return rangePercent < 7.0;
}

//+------------------------------------------------------------------+
//| Determine the current market phase based on events and structure |
//+------------------------------------------------------------------+
ENUM_MARKET_PHASE CWyckoffPhases::DetermineMarketPhase(ENUM_TIMEFRAME timeframe) {
   // Identify Wyckoff events first
   IdentifyWyckoffEvents(timeframe);
   
   // Count occurrences of different events
   int scCount = 0;     // Selling Climax count
   int bcCount = 0;     // Buying Climax count
   int springCount = 0; // Spring count
   int upThrustCount = 0; // Upthrust count
   int sosCount = 0;    // Sign of Strength count
   int sowCount = 0;    // Sign of Weakness count
   
   for (int i = 0; i < ArraySize(m_recentEvents); i++) {
      switch (m_recentEvents[i]) {
         case EVENT_SC: scCount++; break;
         case EVENT_BC: bcCount++; break;
         case EVENT_SPRING: springCount++; break;
         case EVENT_UPTHRUST: upThrustCount++; break;
         case EVENT_SOS: sosCount++; break;
         case EVENT_SOW: sowCount++; break;
      }
   }
   
   // Identify the current trend
   double ma20 = iMA(_Symbol, timeframe, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
   double ma50 = iMA(_Symbol, timeframe, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
   double ma100 = iMA(_Symbol, timeframe, 100, 0, MODE_SMA, PRICE_CLOSE, 0);
   
   bool isUptrend = ma20 > ma50 && ma50 > ma100;
   bool isDowntrend = ma20 < ma50 && ma50 < ma100;
   bool isSideways = !isUptrend && !isDowntrend;
   
   // Determine the phase based on events and trend
   if (scCount > 0 && springCount > 0 && sosCount > 0) {
      // We've seen a selling climax, spring, and signs of strength - late accumulation
      m_currentPhase = PHASE_ACCUMULATION_LATE;
   }
   else if (scCount > 0 && sosCount > 0) {
      // We've seen a selling climax and signs of strength - mid accumulation
      m_currentPhase = PHASE_ACCUMULATION_MID;
   }
   else if (scCount > 0) {
      // We've seen a selling climax - early accumulation
      m_currentPhase = PHASE_ACCUMULATION_EARLY;
   }
   else if (bcCount > 0 && upThrustCount > 0 && sowCount > 0) {
      // We've seen a buying climax, upthrust, and signs of weakness - late distribution
      m_currentPhase = PHASE_DISTRIBUTION_LATE;
   }
   else if (bcCount > 0 && sowCount > 0) {
      // We've seen a buying climax and signs of weakness - mid distribution
      m_currentPhase = PHASE_DISTRIBUTION_MID;
   }
   else if (bcCount > 0) {
      // We've seen a buying climax - early distribution
      m_currentPhase = PHASE_DISTRIBUTION_EARLY;
   }
   else if (isUptrend) {
      // No specific events but in an uptrend - likely markup
      m_currentPhase = PHASE_MARKUP;
   }
   else if (isDowntrend) {
      // No specific events but in a downtrend - likely markdown
      m_currentPhase = PHASE_MARKDOWN;
   }
   else {
      // No clear evidence - unknown phase
      m_currentPhase = PHASE_UNKNOWN;
   }
   
   return m_currentPhase;
}

//+------------------------------------------------------------------+
//| Check if the market is in an accumulation phase                  |
//+------------------------------------------------------------------+
bool CWyckoffPhases::IsInAccumulation(ENUM_TIMEFRAME timeframe) {
   ENUM_MARKET_PHASE phase = DetermineMarketPhase(timeframe);
   
   return phase == PHASE_ACCUMULATION_EARLY || 
          phase == PHASE_ACCUMULATION_MID || 
          phase == PHASE_ACCUMULATION_LATE;
}

//+------------------------------------------------------------------+
//| Check if the market is in a distribution phase                   |
//+------------------------------------------------------------------+
bool CWyckoffPhases::IsInDistribution(ENUM_TIMEFRAME timeframe) {
   ENUM_MARKET_PHASE phase = DetermineMarketPhase(timeframe);
   
   return phase == PHASE_DISTRIBUTION_EARLY || 
          phase == PHASE_DISTRIBUTION_MID || 
          phase == PHASE_DISTRIBUTION_LATE;
}

//+------------------------------------------------------------------+
//| Convert market phase to string for logging                       |
//+------------------------------------------------------------------+
string CWyckoffPhases::MarketPhaseToString(ENUM_MARKET_PHASE phase) {
   switch (phase) {
      case PHASE_ACCUMULATION_EARLY: return "Early Accumulation";
      case PHASE_ACCUMULATION_MID: return "Mid Accumulation";
      case PHASE_ACCUMULATION_LATE: return "Late Accumulation";
      case PHASE_MARKUP: return "Markup";
      case PHASE_DISTRIBUTION_EARLY: return "Early Distribution";
      case PHASE_DISTRIBUTION_MID: return "Mid Distribution";
      case PHASE_DISTRIBUTION_LATE: return "Late Distribution";
      case PHASE_MARKDOWN: return "Markdown";
      default: return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Convert Wyckoff event to string for logging                      |
//+------------------------------------------------------------------+
string CWyckoffPhases::WyckoffEventToString(ENUM_WYCKOFF_EVENT event) {
   switch (event) {
      case EVENT_PS: return "Preliminary Support";
      case EVENT_SC: return "Selling Climax";
      case EVENT_AR: return "Automatic Rally";
      case EVENT_ST: return "Secondary Test";
      case EVENT_SPRING: return "Spring";
      case EVENT_PSY: return "Preliminary Supply";
      case EVENT_BC: return "Buying Climax";
      case EVENT_AR_DIST: return "Automatic Reaction";
      case EVENT_ST_DIST: return "Secondary Test";
      case EVENT_UPTHRUST: return "Upthrust";
      case EVENT_SOW: return "Sign of Weakness";
      case EVENT_SOS: return "Sign of Strength";
      case EVENT_UTAD: return "Upthrust After Distribution";
      default: return "None";
   }
}
