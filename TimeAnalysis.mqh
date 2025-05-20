//+------------------------------------------------------------------+
//|                                                TimeAnalysis.mqh  |
//|                        Smart Money Concepts Trading System       |
//|                                                                  |
//| Description: Class for analyzing time-based factors, particularly|
//| ICT Kill Zones (London and New York sessions).                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property strict

// Session enumeration
enum ENUM_SESSION {
   SESSION_NONE,       // No specific session
   SESSION_ASIAN,      // Asian session
   SESSION_LONDON,     // London session
   SESSION_NEW_YORK,   // New York session
   SESSION_OVERLAP     // London/New York overlap
};

//+------------------------------------------------------------------+
//| TimeAnalysis class                                               |
//+------------------------------------------------------------------+
class CTimeAnalysis {
private:
   bool              m_useLondonSession;    // Whether to use London session
   bool              m_useNewYorkSession;   // Whether to use New York session
   datetime          m_londonOpen;          // Current day's London session open time
   datetime          m_londonClose;         // Current day's London session close time
   datetime          m_newYorkOpen;         // Current day's New York session open time
   datetime          m_newYorkClose;        // Current day's New York session close time
   
   // Private methods
   void              CalculateSessionTimes();
   bool              IsInSession(datetime time, datetime sessionOpen, datetime sessionClose);
   
public:
                     CTimeAnalysis();
                    ~CTimeAnalysis();
   
   // Initialization
   void              Initialize(bool useLondonSession, bool useNewYorkSession);
   
   // Analysis methods
   ENUM_SESSION      GetCurrentSession();
   bool              IsInKillZone();
   bool              IsInLondonSession();
   bool              IsInNewYorkSession();
   bool              IsInLondonOpen();
   bool              IsInNewYorkOpen();
   bool              IsInSessionOverlap();
   
   // Utility methods
   string            SessionToString(ENUM_SESSION session);
   int               GetServerGMTOffset();
   datetime          GetAdjustedServerTime();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTimeAnalysis::CTimeAnalysis() {
   m_useLondonSession = true;
   m_useNewYorkSession = true;
   m_londonOpen = 0;
   m_londonClose = 0;
   m_newYorkOpen = 0;
   m_newYorkClose = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTimeAnalysis::~CTimeAnalysis() {
}

//+------------------------------------------------------------------+
//| Initialize the class with parameters                             |
//+------------------------------------------------------------------+
void CTimeAnalysis::Initialize(bool useLondonSession, bool useNewYorkSession) {
   m_useLondonSession = useLondonSession;
   m_useNewYorkSession = useNewYorkSession;
   
   // Calculate session times for today
   CalculateSessionTimes();
}

//+------------------------------------------------------------------+
//| Calculate session open and close times for current day           |
//+------------------------------------------------------------------+
void CTimeAnalysis::CalculateSessionTimes() {
   // Get current server time with broker's timezone offset
   datetime serverTime = GetAdjustedServerTime();
   
   // Extract current date components
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   
   // Set session times in broker's timezone (GMT offset applied)
   int gmtOffset = GetServerGMTOffset();
   
   // London Session: 8:00 - 16:00 GMT
   int londonOpenHour = 8 + gmtOffset; // 8:00 GMT in server time
   int londonCloseHour = 16 + gmtOffset; // 16:00 GMT in server time
   
   // Adjust for day boundary crossings
   while (londonOpenHour < 0) londonOpenHour += 24;
   while (londonOpenHour >= 24) londonOpenHour -= 24;
   while (londonCloseHour < 0) londonCloseHour += 24;
   while (londonCloseHour >= 24) londonCloseHour -= 24;
   
   // Construct London session datetime values
   MqlDateTime londonOpenDt, londonCloseDt;
   londonOpenDt = dt;
   londonCloseDt = dt;
   
   londonOpenDt.hour = londonOpenHour;
   londonOpenDt.min = 0;
   londonOpenDt.sec = 0;
   
   londonCloseDt.hour = londonCloseHour;
   londonCloseDt.min = 0;
   londonCloseDt.sec = 0;
   
   // Adjust day if needed
   if (londonCloseHour < londonOpenHour) {
      // Session crosses midnight
      londonCloseDt.day += 1;
      // Handle month boundary if needed
      if (londonCloseDt.day > DayOfMonth(londonCloseDt.year, londonCloseDt.mon)) {
         londonCloseDt.day = 1;
         londonCloseDt.mon += 1;
         if (londonCloseDt.mon > 12) {
            londonCloseDt.mon = 1;
            londonCloseDt.year += 1;
         }
      }
   }
   
   // Convert to datetime
   m_londonOpen = StructToTime(londonOpenDt);
   m_londonClose = StructToTime(londonCloseDt);
   
   // New York Session: 13:00 - 21:00 GMT
   int nyOpenHour = 13 + gmtOffset; // 13:00 GMT in server time
   int nyCloseHour = 21 + gmtOffset; // 21:00 GMT in server time
   
   // Adjust for day boundary crossings
   while (nyOpenHour < 0) nyOpenHour += 24;
   while (nyOpenHour >= 24) nyOpenHour -= 24;
   while (nyCloseHour < 0) nyCloseHour += 24;
   while (nyCloseHour >= 24) nyCloseHour -= 24;
   
   // Construct New York session datetime values
   MqlDateTime nyOpenDt, nyCloseDt;
   nyOpenDt = dt;
   nyCloseDt = dt;
   
   nyOpenDt.hour = nyOpenHour;
   nyOpenDt.min = 0;
   nyOpenDt.sec = 0;
   
   nyCloseDt.hour = nyCloseHour;
   nyCloseDt.min = 0;
   nyCloseDt.sec = 0;
   
   // Adjust day if needed
   if (nyCloseHour < nyOpenHour) {
      // Session crosses midnight
      nyCloseDt.day += 1;
      // Handle month boundary if needed
      if (nyCloseDt.day > DayOfMonth(nyCloseDt.year, nyCloseDt.mon)) {
         nyCloseDt.day = 1;
         nyCloseDt.mon += 1;
         if (nyCloseDt.mon > 12) {
            nyCloseDt.mon = 1;
            nyCloseDt.year += 1;
         }
      }
   }
   
   // Convert to datetime
   m_newYorkOpen = StructToTime(nyOpenDt);
   m_newYorkClose = StructToTime(nyCloseDt);
}

//+------------------------------------------------------------------+
//| Check if given time is within a session's hours                  |
//+------------------------------------------------------------------+
bool CTimeAnalysis::IsInSession(datetime time, datetime sessionOpen, datetime sessionClose) {
   return (time >= sessionOpen && time < sessionClose);
}

//+------------------------------------------------------------------+
//| Determine which trading session is currently active              |
//+------------------------------------------------------------------+
ENUM_SESSION CTimeAnalysis::GetCurrentSession() {
   // Get current server time
   datetime serverTime = GetAdjustedServerTime();
   
   // Recalculate session times if we're in a new day
   static datetime lastCheckDay = 0;
   MqlDateTime currentDt, lastDt;
   TimeToStruct(serverTime, currentDt);
   TimeToStruct(lastCheckDay, lastDt);
   
   if (lastCheckDay == 0 || currentDt.day != lastDt.day || 
       currentDt.mon != lastDt.mon || currentDt.year != lastDt.year) {
      CalculateSessionTimes();
      lastCheckDay = serverTime;
   }
   
   // Check which session we're in
   bool inLondon = IsInSession(serverTime, m_londonOpen, m_londonClose);
   bool inNewYork = IsInSession(serverTime, m_newYorkOpen, m_newYorkClose);
   
   if (inLondon && inNewYork) {
      return SESSION_OVERLAP;
   } else if (inLondon) {
      return SESSION_LONDON;
   } else if (inNewYork) {
      return SESSION_NEW_YORK;
   } else {
      // Check if it's the Asian session (rough approximation, 00:00-08:00 GMT)
      MqlDateTime dt;
      TimeToStruct(serverTime, dt);
      
      // Asian session
      int asianOpenHour = 0 + GetServerGMTOffset(); // 00:00 GMT
      int asianCloseHour = 8 + GetServerGMTOffset(); // 08:00 GMT
      
      while (asianOpenHour < 0) asianOpenHour += 24;
      while (asianOpenHour >= 24) asianOpenHour -= 24;
      while (asianCloseHour < 0) asianCloseHour += 24;
      while (asianCloseHour >= 24) asianCloseHour -= 24;
      
      if ((asianOpenHour < asianCloseHour && dt.hour >= asianOpenHour && dt.hour < asianCloseHour) ||
          (asianOpenHour > asianCloseHour && (dt.hour >= asianOpenHour || dt.hour < asianCloseHour))) {
         return SESSION_ASIAN;
      }
      
      return SESSION_NONE;
   }
}

//+------------------------------------------------------------------+
//| Check if we're in an ICT Kill Zone                               |
//+------------------------------------------------------------------+
bool CTimeAnalysis::IsInKillZone() {
   // Kill Zones are typically the first hour of the London and NY sessions
   datetime serverTime = GetAdjustedServerTime();
   
   bool inLondonKillZone = false;
   bool inNYKillZone = false;
   
   // Check if we're within the first hour of London session
   if (m_useLondonSession) {
      datetime londonFirstHour = m_londonOpen + 3600; // One hour from open
      inLondonKillZone = serverTime >= m_londonOpen && serverTime < londonFirstHour;
   }
   
   // Check if we're within the first hour of NY session
   if (m_useNewYorkSession) {
      datetime nyFirstHour = m_newYorkOpen + 3600; // One hour from open
      inNYKillZone = serverTime >= m_newYorkOpen && serverTime < nyFirstHour;
   }
   
   return inLondonKillZone || inNYKillZone;
}

//+------------------------------------------------------------------+
//| Check if we're in the London session                             |
//+------------------------------------------------------------------+
bool CTimeAnalysis::IsInLondonSession() {
   if (!m_useLondonSession) return false;
   
   datetime serverTime = GetAdjustedServerTime();
   return IsInSession(serverTime, m_londonOpen, m_londonClose);
}

//+------------------------------------------------------------------+
//| Check if we're in the New York session                           |
//+------------------------------------------------------------------+
bool CTimeAnalysis::IsInNewYorkSession() {
   if (!m_useNewYorkSession) return false;
   
   datetime serverTime = GetAdjustedServerTime();
   return IsInSession(serverTime, m_newYorkOpen, m_newYorkClose);
}

//+------------------------------------------------------------------+
//| Check if we're in the London open hour                           |
//+------------------------------------------------------------------+
bool CTimeAnalysis::IsInLondonOpen() {
   if (!m_useLondonSession) return false;
   
   datetime serverTime = GetAdjustedServerTime();
   datetime londonFirstHour = m_londonOpen + 3600; // One hour from open
   return serverTime >= m_londonOpen && serverTime < londonFirstHour;
}

//+------------------------------------------------------------------+
//| Check if we're in the New York open hour                         |
//+------------------------------------------------------------------+
bool CTimeAnalysis::IsInNewYorkOpen() {
   if (!m_useNewYorkSession) return false;
   
   datetime serverTime = GetAdjustedServerTime();
   datetime nyFirstHour = m_newYorkOpen + 3600; // One hour from open
   return serverTime >= m_newYorkOpen && serverTime < nyFirstHour;
}

//+------------------------------------------------------------------+
//| Check if we're in the London-NY session overlap                  |
//+------------------------------------------------------------------+
bool CTimeAnalysis::IsInSessionOverlap() {
   if (!m_useLondonSession || !m_useNewYorkSession) return false;
   
   datetime serverTime = GetAdjustedServerTime();
   return IsInSession(serverTime, m_newYorkOpen, m_londonClose);
}

//+------------------------------------------------------------------+
//| Get server's GMT offset (estimate)                               |
//+------------------------------------------------------------------+
int CTimeAnalysis::GetServerGMTOffset() {
   // This function attempts to estimate the GMT offset of the broker's server
   // It may not be entirely accurate for all brokers/platforms
   
   // Get current broker server time
   datetime serverTime = TimeCurrent();
   
   // Get GMT time by assuming TimeCurrent() is in broker server time
   MqlDateTime serverDt;
   TimeToStruct(serverTime, serverDt);
   
   // The broker's local time offset from GMT/UTC in hours
   // This is an estimate and may need adjustment based on the broker
   // Default to GMT
   return 0;
}

//+------------------------------------------------------------------+
//| Get broker server time adjusted to estimated GMT offset          |
//+------------------------------------------------------------------+
datetime CTimeAnalysis::GetAdjustedServerTime() {
   // Simply returns the current server time
   // The session calculations will use the estimated GMT offset
   return TimeCurrent();
}

//+------------------------------------------------------------------+
//| Convert session type to string for logging                       |
//+------------------------------------------------------------------+
string CTimeAnalysis::SessionToString(ENUM_SESSION session) {
   switch (session) {
      case SESSION_ASIAN: return "Asian";
      case SESSION_LONDON: return "London";
      case SESSION_NEW_YORK: return "New York";
      case SESSION_OVERLAP: return "London/NY Overlap";
      default: return "None";
   }
}
