//+------------------------------------------------------------------+
//|                                               SupplyDemand.mqh   |
//|                        Smart Money Concepts Trading System       |
//|                                                                  |
//| Description: Class for identifying and analyzing Supply and      |
//| Demand zones across different timeframes.                        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property strict

// Zone type enumeration
enum ENUM_ZONE_TYPE {
   ZONE_NONE,    // No zone
   ZONE_SUPPLY,  // Supply zone (resistance)
   ZONE_DEMAND   // Demand zone (support)
};

// Zone strength enumeration
enum ENUM_ZONE_STRENGTH {
   STRENGTH_WEAK,    // Weak zone
   STRENGTH_NORMAL,  // Normal zone
   STRENGTH_STRONG   // Strong zone
};

//+------------------------------------------------------------------+
//| Zone structure                                                   |
//+------------------------------------------------------------------+
struct Zone {
   ENUM_ZONE_TYPE type;        // Type of zone
   ENUM_ZONE_STRENGTH strength; // Strength of the zone
   datetime time;              // Time of zone formation
   double upper;               // Upper boundary
   double lower;               // Lower boundary
   int touchCount;             // Number of times price touched the zone
   bool isFresh;               // Whether the zone is fresh (not tested yet)
   bool isBroken;              // Whether the zone has been broken
   
   // Constructor
   Zone() {
      type = ZONE_NONE;
      strength = STRENGTH_NORMAL;
      time = 0;
      upper = 0;
      lower = 0;
      touchCount = 0;
      isFresh = true;
      isBroken = false;
   }
};

//+------------------------------------------------------------------+
//| SupplyDemand class                                               |
//+------------------------------------------------------------------+
class CSupplyDemand {
private:
   int               m_lookback;            // Bars to look back for zone analysis
   Zone              m_supplyZones[];       // Array of supply zones
   Zone              m_demandZones[];       // Array of demand zones
   
   // Private methods
   void              IdentifySupplyDemandZones(ENUM_TIMEFRAME timeframe);
   bool              IsSupplyZoneCandidate(int bar, ENUM_TIMEFRAME timeframe);
   bool              IsDemandZoneCandidate(int bar, ENUM_TIMEFRAME timeframe);
   ENUM_ZONE_STRENGTH DetermineZoneStrength(int departurBar, ENUM_TIMEFRAME timeframe, ENUM_ZONE_TYPE type);
   bool              DoZonesOverlap(Zone &zone1, Zone &zone2);
   void              MergeOverlappingZones();
   void              UpdateZoneStatus(ENUM_TIMEFRAME timeframe);
   
public:
                     CSupplyDemand();
                    ~CSupplyDemand();
   
   // Initialization
   void              Initialize(int lookback);
   
   // Analysis methods
   bool              IsInSupplyZone(ENUM_TIMEFRAME timeframe);
   bool              IsInDemandZone(ENUM_TIMEFRAME timeframe);
   Zone              GetNearestSupplyZone(ENUM_TIMEFRAME timeframe);
   Zone              GetNearestDemandZone(ENUM_TIMEFRAME timeframe);
   
   // Utility methods
   string            ZoneTypeToString(ENUM_ZONE_TYPE type);
   string            ZoneStrengthToString(ENUM_ZONE_STRENGTH strength);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSupplyDemand::CSupplyDemand() {
   m_lookback = 100;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSupplyDemand::~CSupplyDemand() {
   ArrayFree(m_supplyZones);
   ArrayFree(m_demandZones);
}

//+------------------------------------------------------------------+
//| Initialize the class with parameters                             |
//+------------------------------------------------------------------+
void CSupplyDemand::Initialize(int lookback) {
   m_lookback = lookback;
}

//+------------------------------------------------------------------+
//| Identify Supply and Demand zones on the specified timeframe      |
//+------------------------------------------------------------------+
void CSupplyDemand::IdentifySupplyDemandZones(ENUM_TIMEFRAME timeframe) {
   // Clear existing zones
   ArrayFree(m_supplyZones);
   ArrayFree(m_demandZones);
   
   // Initialize arrays
   ArrayResize(m_supplyZones, 0);
   ArrayResize(m_demandZones, 0);
   
   // Loop through bars to find Supply and Demand zones
   for (int i = m_lookback - 1; i >= 3; i--) {
      // Check for Supply zone formation
      if (IsSupplyZoneCandidate(i, timeframe)) {
         Zone zone;
         zone.type = ZONE_SUPPLY;
         zone.time = iTime(_Symbol, timeframe, i);
         
         // Find the departure bar (strong move down from supply)
         int departureBar = i;
         while (departureBar > 0 && iClose(_Symbol, timeframe, departureBar) > iOpen(_Symbol, timeframe, departureBar)) {
            departureBar--;
         }
         
         // Set zone boundaries
         zone.upper = iHigh(_Symbol, timeframe, i);
         zone.lower = iLow(_Symbol, timeframe, i);
         
         // Determine zone strength
         zone.strength = DetermineZoneStrength(departureBar, timeframe, ZONE_SUPPLY);
         
         // Add to array
         int size = ArraySize(m_supplyZones);
         ArrayResize(m_supplyZones, size + 1);
         m_supplyZones[size] = zone;
      }
      
      // Check for Demand zone formation
      if (IsDemandZoneCandidate(i, timeframe)) {
         Zone zone;
         zone.type = ZONE_DEMAND;
         zone.time = iTime(_Symbol, timeframe, i);
         
         // Find the departure bar (strong move up from demand)
         int departureBar = i;
         while (departureBar > 0 && iClose(_Symbol, timeframe, departureBar) < iOpen(_Symbol, timeframe, departureBar)) {
            departureBar--;
         }
         
         // Set zone boundaries
         zone.upper = iHigh(_Symbol, timeframe, i);
         zone.lower = iLow(_Symbol, timeframe, i);
         
         // Determine zone strength
         zone.strength = DetermineZoneStrength(departureBar, timeframe, ZONE_DEMAND);
         
         // Add to array
         int size = ArraySize(m_demandZones);
         ArrayResize(m_demandZones, size + 1);
         m_demandZones[size] = zone;
      }
   }
   
   // Merge overlapping zones
   MergeOverlappingZones();
   
   // Update zone status (touches, broken, etc.)
   UpdateZoneStatus(timeframe);
}

//+------------------------------------------------------------------+
//| Check if a bar is a potential Supply zone candidate              |
//+------------------------------------------------------------------+
bool CSupplyDemand::IsSupplyZoneCandidate(int bar, ENUM_TIMEFRAME timeframe) {
   // Need at least 3 bars after this one
   if (bar < 3) return false;
   
   // Check if this is a bearish reversal point (price rejection from a high)
   bool isReversal = iHigh(_Symbol, timeframe, bar) > iHigh(_Symbol, timeframe, bar+1) &&
                     iHigh(_Symbol, timeframe, bar) > iHigh(_Symbol, timeframe, bar-1);
   
   // Check for strong move down after this bar
   bool strongMoveDown = false;
   int consecutiveDownBars = 0;
   
   for (int i = bar - 1; i >= MathMax(0, bar - 4); i--) {
      if (iClose(_Symbol, timeframe, i) < iOpen(_Symbol, timeframe, i)) {
         consecutiveDownBars++;
      }
   }
   
   strongMoveDown = consecutiveDownBars >= 2;
   
   // Check for significant distance moved from the high
   bool significantDistance = false;
   if (bar >= 3) {
      double highPoint = iHigh(_Symbol, timeframe, bar);
      double lowAfter = iLow(_Symbol, timeframe, bar-3);
      double movePercent = (highPoint - lowAfter) / highPoint * 100;
      
      significantDistance = movePercent > 0.3; // 0.3% move is significant, adjust as needed
   }
   
   return isReversal && strongMoveDown && significantDistance;
}

//+------------------------------------------------------------------+
//| Check if a bar is a potential Demand zone candidate              |
//+------------------------------------------------------------------+
bool CSupplyDemand::IsDemandZoneCandidate(int bar, ENUM_TIMEFRAME timeframe) {
   // Need at least 3 bars after this one
   if (bar < 3) return false;
   
   // Check if this is a bullish reversal point (price rejection from a low)
   bool isReversal = iLow(_Symbol, timeframe, bar) < iLow(_Symbol, timeframe, bar+1) &&
                     iLow(_Symbol, timeframe, bar) < iLow(_Symbol, timeframe, bar-1);
   
   // Check for strong move up after this bar
   bool strongMoveUp = false;
   int consecutiveUpBars = 0;
   
   for (int i = bar - 1; i >= MathMax(0, bar - 4); i--) {
      if (iClose(_Symbol, timeframe, i) > iOpen(_Symbol, timeframe, i)) {
         consecutiveUpBars++;
      }
   }
   
   strongMoveUp = consecutiveUpBars >= 2;
   
   // Check for significant distance moved from the low
   bool significantDistance = false;
   if (bar >= 3) {
      double lowPoint = iLow(_Symbol, timeframe, bar);
      double highAfter = iHigh(_Symbol, timeframe, bar-3);
      double movePercent = (highAfter - lowPoint) / lowPoint * 100;
      
      significantDistance = movePercent > 0.3; // 0.3% move is significant, adjust as needed
   }
   
   return isReversal && strongMoveUp && significantDistance;
}

//+------------------------------------------------------------------+
//| Determine the strength of a zone                                 |
//+------------------------------------------------------------------+
ENUM_ZONE_STRENGTH CSupplyDemand::DetermineZoneStrength(int departureBar, ENUM_TIMEFRAME timeframe, ENUM_ZONE_TYPE type) {
   // If no valid departure bar, return normal strength
   if (departureBar <= 0) return STRENGTH_NORMAL;
   
   // Calculate the move size from the zone
   double moveSize = 0;
   
   if (type == ZONE_SUPPLY) {
      double highPoint = iHigh(_Symbol, timeframe, departureBar + 1);
      double lowPoint = iLow(_Symbol, timeframe, departureBar);
      moveSize = highPoint - lowPoint;
   } else {
      double lowPoint = iLow(_Symbol, timeframe, departureBar + 1);
      double highPoint = iHigh(_Symbol, timeframe, departureBar);
      moveSize = highPoint - lowPoint;
   }
   
   // Calculate average candle size for reference
   double avgCandleSize = 0;
   for (int i = departureBar + 5; i > departureBar; i--) {
      avgCandleSize += (iHigh(_Symbol, timeframe, i) - iLow(_Symbol, timeframe, i));
   }
   avgCandleSize /= 5;
   
   // Determine strength based on move size relative to average candle
   if (moveSize > avgCandleSize * 3) {
      return STRENGTH_STRONG;
   } else if (moveSize > avgCandleSize * 1.5) {
      return STRENGTH_NORMAL;
   } else {
      return STRENGTH_WEAK;
   }
}

//+------------------------------------------------------------------+
//| Check if two zones overlap                                       |
//+------------------------------------------------------------------+
bool CSupplyDemand::DoZonesOverlap(Zone &zone1, Zone &zone2) {
   // Check if the two zones overlap
   return (zone1.lower <= zone2.upper && zone1.upper >= zone2.lower);
}

//+------------------------------------------------------------------+
//| Merge overlapping zones of the same type                         |
//+------------------------------------------------------------------+
void CSupplyDemand::MergeOverlappingZones() {
   // Merge overlapping supply zones
   for (int i = 0; i < ArraySize(m_supplyZones) - 1; i++) {
      for (int j = i + 1; j < ArraySize(m_supplyZones); j++) {
         if (DoZonesOverlap(m_supplyZones[i], m_supplyZones[j])) {
            // Merge the zones
            m_supplyZones[i].upper = MathMax(m_supplyZones[i].upper, m_supplyZones[j].upper);
            m_supplyZones[i].lower = MathMin(m_supplyZones[i].lower, m_supplyZones[j].lower);
            
            // Keep the earliest time
            m_supplyZones[i].time = MathMin(m_supplyZones[i].time, m_supplyZones[j].time);
            
            // Keep the highest strength
            if (m_supplyZones[j].strength > m_supplyZones[i].strength) {
               m_supplyZones[i].strength = m_supplyZones[j].strength;
            }
            
            // Remove the second zone
            for (int k = j; k < ArraySize(m_supplyZones) - 1; k++) {
               m_supplyZones[k] = m_supplyZones[k+1];
            }
            ArrayResize(m_supplyZones, ArraySize(m_supplyZones) - 1);
            j--; // Adjust index after removal
         }
      }
   }
   
   // Merge overlapping demand zones
   for (int i = 0; i < ArraySize(m_demandZones) - 1; i++) {
      for (int j = i + 1; j < ArraySize(m_demandZones); j++) {
         if (DoZonesOverlap(m_demandZones[i], m_demandZones[j])) {
            // Merge the zones
            m_demandZones[i].upper = MathMax(m_demandZones[i].upper, m_demandZones[j].upper);
            m_demandZones[i].lower = MathMin(m_demandZones[i].lower, m_demandZones[j].lower);
            
            // Keep the earliest time
            m_demandZones[i].time = MathMin(m_demandZones[i].time, m_demandZones[j].time);
            
            // Keep the highest strength
            if (m_demandZones[j].strength > m_demandZones[i].strength) {
               m_demandZones[i].strength = m_demandZones[j].strength;
            }
            
            // Remove the second zone
            for (int k = j; k < ArraySize(m_demandZones) - 1; k++) {
               m_demandZones[k] = m_demandZones[k+1];
            }
            ArrayResize(m_demandZones, ArraySize(m_demandZones) - 1);
            j--; // Adjust index after removal
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update status of all zones (touches, broken, etc.)               |
//+------------------------------------------------------------------+
void CSupplyDemand::UpdateZoneStatus(ENUM_TIMEFRAME timeframe) {
   // We need to check if price has touched or broken each zone since its formation
   
   // Loop through all supply zones
   for (int i = 0; i < ArraySize(m_supplyZones); i++) {
      // Find the bar index corresponding to the zone time
      int zoneBarIndex = -1;
      for (int j = 0; j < m_lookback; j++) {
         if (iTime(_Symbol, timeframe, j) == m_supplyZones[i].time) {
            zoneBarIndex = j;
            break;
         }
      }
      
      // If zone time not found, skip this zone
      if (zoneBarIndex == -1) continue;
      
      // Check all bars since zone formation
      for (int j = zoneBarIndex - 1; j >= 0; j--) {
         // Check if price touched the zone
         if (iHigh(_Symbol, timeframe, j) >= m_supplyZones[i].lower && 
             iLow(_Symbol, timeframe, j) <= m_supplyZones[i].upper) {
            m_supplyZones[i].touchCount++;
            m_supplyZones[i].isFresh = false;
         }
         
         // Check if price broke the zone (closed above the upper boundary)
         if (iClose(_Symbol, timeframe, j) > m_supplyZones[i].upper) {
            m_supplyZones[i].isBroken = true;
         }
      }
   }
   
   // Loop through all demand zones
   for (int i = 0; i < ArraySize(m_demandZones); i++) {
      // Find the bar index corresponding to the zone time
      int zoneBarIndex = -1;
      for (int j = 0; j < m_lookback; j++) {
         if (iTime(_Symbol, timeframe, j) == m_demandZones[i].time) {
            zoneBarIndex = j;
            break;
         }
      }
      
      // If zone time not found, skip this zone
      if (zoneBarIndex == -1) continue;
      
      // Check all bars since zone formation
      for (int j = zoneBarIndex - 1; j >= 0; j--) {
         // Check if price touched the zone
         if (iHigh(_Symbol, timeframe, j) >= m_demandZones[i].lower && 
             iLow(_Symbol, timeframe, j) <= m_demandZones[i].upper) {
            m_demandZones[i].touchCount++;
            m_demandZones[i].isFresh = false;
         }
         
         // Check if price broke the zone (closed below the lower boundary)
         if (iClose(_Symbol, timeframe, j) < m_demandZones[i].lower) {
            m_demandZones[i].isBroken = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if current price is in a Supply zone                       |
//+------------------------------------------------------------------+
bool CSupplyDemand::IsInSupplyZone(ENUM_TIMEFRAME timeframe) {
   // Make sure zones are identified
   IdentifySupplyDemandZones(timeframe);
   
   double currentPrice = iClose(_Symbol, timeframe, 0);
   
   // Check if price is in any supply zone that is not broken
   for (int i = 0; i < ArraySize(m_supplyZones); i++) {
      if (!m_supplyZones[i].isBroken) {
         if (currentPrice >= m_supplyZones[i].lower && currentPrice <= m_supplyZones[i].upper) {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if current price is in a Demand zone                       |
//+------------------------------------------------------------------+
bool CSupplyDemand::IsInDemandZone(ENUM_TIMEFRAME timeframe) {
   // Make sure zones are identified
   IdentifySupplyDemandZones(timeframe);
   
   double currentPrice = iClose(_Symbol, timeframe, 0);
   
   // Check if price is in any demand zone that is not broken
   for (int i = 0; i < ArraySize(m_demandZones); i++) {
      if (!m_demandZones[i].isBroken) {
         if (currentPrice >= m_demandZones[i].lower && currentPrice <= m_demandZones[i].upper) {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get the nearest Supply zone above current price                  |
//+------------------------------------------------------------------+
Zone CSupplyDemand::GetNearestSupplyZone(ENUM_TIMEFRAME timeframe) {
   // Make sure zones are identified
   IdentifySupplyDemandZones(timeframe);
   
   double currentPrice = iClose(_Symbol, timeframe, 0);
   double minDistance = DBL_MAX;
   Zone nearestZone;
   
   // Find the nearest supply zone above current price
   for (int i = 0; i < ArraySize(m_supplyZones); i++) {
      if (!m_supplyZones[i].isBroken && m_supplyZones[i].lower > currentPrice) {
         double distance = m_supplyZones[i].lower - currentPrice;
         if (distance < minDistance) {
            minDistance = distance;
            nearestZone = m_supplyZones[i];
         }
      }
   }
   
   return nearestZone;
}

//+------------------------------------------------------------------+
//| Get the nearest Demand zone below current price                  |
//+------------------------------------------------------------------+
Zone CSupplyDemand::GetNearestDemandZone(ENUM_TIMEFRAME timeframe) {
   // Make sure zones are identified
   IdentifySupplyDemandZones(timeframe);
   
   double currentPrice = iClose(_Symbol, timeframe, 0);
   double minDistance = DBL_MAX;
   Zone nearestZone;
   
   // Find the nearest demand zone below current price
   for (int i = 0; i < ArraySize(m_demandZones); i++) {
      if (!m_demandZones[i].isBroken && m_demandZones[i].upper < currentPrice) {
         double distance = currentPrice - m_demandZones[i].upper;
         if (distance < minDistance) {
            minDistance = distance;
            nearestZone = m_demandZones[i];
         }
      }
   }
   
   return nearestZone;
}

//+------------------------------------------------------------------+
//| Convert zone type to string for logging                          |
//+------------------------------------------------------------------+
string CSupplyDemand::ZoneTypeToString(ENUM_ZONE_TYPE type) {
   switch (type) {
      case ZONE_SUPPLY: return "Supply";
      case ZONE_DEMAND: return "Demand";
      default: return "None";
   }
}

//+------------------------------------------------------------------+
//| Convert zone strength to string for logging                      |
//+------------------------------------------------------------------+
string CSupplyDemand::ZoneStrengthToString(ENUM_ZONE_STRENGTH strength) {
   switch (strength) {
      case STRENGTH_WEAK: return "Weak";
      case STRENGTH_NORMAL: return "Normal";
      case STRENGTH_STRONG: return "Strong";
      default: return "Unknown";
   }
}
