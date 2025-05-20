//+------------------------------------------------------------------+
//|                                                      Logger.mqh  |
//|                        Smart Money Concepts Trading System       |
//|                                                                  |
//| Description: Class for logging system activities, trade          |
//| signals, and events to a file and/or terminal.                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property strict

// Log level enumeration
enum ENUM_LOG_LEVEL {
   LOG_LEVEL_ERROR,      // Error messages only
   LOG_LEVEL_WARNING,    // Errors and warnings
   LOG_LEVEL_INFO,       // Normal information
   LOG_LEVEL_DEBUG,      // Detailed debug information
   LOG_LEVEL_VERBOSE     // Very detailed information
};

//+------------------------------------------------------------------+
//| Logger class                                                     |
//+------------------------------------------------------------------+
class CLogger {
private:
   string            m_fileName;            // File name for log output
   int               m_fileHandle;          // Handle to the log file
   bool              m_isInitialized;       // Whether logger is initialized
   bool              m_logToFile;           // Whether to write to file
   bool              m_logToTerminal;       // Whether to write to terminal
   ENUM_LOG_LEVEL    m_logLevel;            // Current log level
   
   // Private methods
   void              AppendLogLine(string message);
   string            FormatLogMessage(string message, ENUM_LOG_LEVEL level);
   string            LogLevelToString(ENUM_LOG_LEVEL level);
   string            GetTimeStamp();
   
public:
                     CLogger();
                    ~CLogger();
   
   // Initialization
   bool              Initialize(string fileName, bool logToFile = true, bool logToTerminal = true, ENUM_LOG_LEVEL level = LOG_LEVEL_INFO);
   void              Deinitialize();
   
   // Logging methods
   void              Log(string message, ENUM_LOG_LEVEL level = LOG_LEVEL_INFO);
   void              LogError(string message);
   void              LogWarning(string message);
   void              LogInfo(string message);
   void              LogDebug(string message);
   void              LogVerbose(string message);
   
   // Settings
   void              SetLogLevel(ENUM_LOG_LEVEL level);
   void              EnableFileLogging(bool enable);
   void              EnableTerminalLogging(bool enable);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLogger::CLogger() {
   m_fileName = "SMC_EA_Log.txt";
   m_fileHandle = INVALID_HANDLE;
   m_isInitialized = false;
   m_logToFile = true;
   m_logToTerminal = true;
   m_logLevel = LOG_LEVEL_INFO;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLogger::~CLogger() {
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize the logger                                            |
//+------------------------------------------------------------------+
bool CLogger::Initialize(string fileName, bool logToFile = true, bool logToTerminal = true, ENUM_LOG_LEVEL level = LOG_LEVEL_INFO) {
   // Set logger properties
   m_fileName = fileName;
   m_logToFile = logToFile;
   m_logToTerminal = logToTerminal;
   m_logLevel = level;
   
   // If file logging is enabled, open/create the log file
   if (m_logToFile) {
      m_fileHandle = FileOpen(m_fileName, FILE_WRITE | FILE_READ | FILE_TXT);
      
      if (m_fileHandle == INVALID_HANDLE) {
         m_logToFile = false;
         Print("Error: Failed to open log file (", m_fileName, "). Error code: ", GetLastError());
         return false;
      }
      
      // Move file pointer to the end
      FileSeek(m_fileHandle, 0, SEEK_END);
      
      // Write header if this is a new file (empty)
      if (FileSize(m_fileHandle) == 0) {
         string header = GetTimeStamp() + " SMC Expert Advisor Log Started\n";
         FileWriteString(m_fileHandle, header);
      } else {
         // Add a separator line if the file already has content
         string separator = "\n" + GetTimeStamp() + " --- New Session Started ---\n";
         FileWriteString(m_fileHandle, separator);
      }
   }
   
   m_isInitialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize the logger                                          |
//+------------------------------------------------------------------+
void CLogger::Deinitialize() {
   if (m_isInitialized && m_logToFile && m_fileHandle != INVALID_HANDLE) {
      // Write footer
      string footer = GetTimeStamp() + " SMC Expert Advisor Log Ended\n";
      FileWriteString(m_fileHandle, footer);
      
      // Close file
      FileClose(m_fileHandle);
      m_fileHandle = INVALID_HANDLE;
   }
   
   m_isInitialized = false;
}

//+------------------------------------------------------------------+
//| Write a message to the log                                       |
//+------------------------------------------------------------------+
void CLogger::Log(string message, ENUM_LOG_LEVEL level = LOG_LEVEL_INFO) {
   // Only log if the level is appropriate
   if (level > m_logLevel) return;
   
   // Format the message
   string formattedMessage = FormatLogMessage(message, level);
   
   // Log to terminal if enabled
   if (m_logToTerminal) {
      if (level == LOG_LEVEL_ERROR) {
         Print("ERROR: ", message);
      } else if (level == LOG_LEVEL_WARNING) {
         Print("WARNING: ", message);
      } else {
         Print(message);
      }
   }
   
   // Log to file if enabled
   if (m_isInitialized && m_logToFile && m_fileHandle != INVALID_HANDLE) {
      AppendLogLine(formattedMessage);
   }
}

//+------------------------------------------------------------------+
//| Log an error message                                             |
//+------------------------------------------------------------------+
void CLogger::LogError(string message) {
   Log(message, LOG_LEVEL_ERROR);
}

//+------------------------------------------------------------------+
//| Log a warning message                                            |
//+------------------------------------------------------------------+
void CLogger::LogWarning(string message) {
   Log(message, LOG_LEVEL_WARNING);
}

//+------------------------------------------------------------------+
//| Log an info message                                              |
//+------------------------------------------------------------------+
void CLogger::LogInfo(string message) {
   Log(message, LOG_LEVEL_INFO);
}

//+------------------------------------------------------------------+
//| Log a debug message                                              |
//+------------------------------------------------------------------+
void CLogger::LogDebug(string message) {
   Log(message, LOG_LEVEL_DEBUG);
}

//+------------------------------------------------------------------+
//| Log a verbose message                                            |
//+------------------------------------------------------------------+
void CLogger::LogVerbose(string message) {
   Log(message, LOG_LEVEL_VERBOSE);
}

//+------------------------------------------------------------------+
//| Set the log level                                                |
//+------------------------------------------------------------------+
void CLogger::SetLogLevel(ENUM_LOG_LEVEL level) {
   m_logLevel = level;
}

//+------------------------------------------------------------------+
//| Enable or disable file logging                                   |
//+------------------------------------------------------------------+
void CLogger::EnableFileLogging(bool enable) {
   if (enable && !m_logToFile) {
      // Re-open the log file
      m_fileHandle = FileOpen(m_fileName, FILE_WRITE | FILE_READ | FILE_TXT);
      if (m_fileHandle != INVALID_HANDLE) {
         m_logToFile = true;
         FileSeek(m_fileHandle, 0, SEEK_END);
      }
   } else if (!enable && m_logToFile) {
      // Close the log file
      if (m_fileHandle != INVALID_HANDLE) {
         FileClose(m_fileHandle);
         m_fileHandle = INVALID_HANDLE;
      }
      m_logToFile = false;
   }
}

//+------------------------------------------------------------------+
//| Enable or disable terminal logging                               |
//+------------------------------------------------------------------+
void CLogger::EnableTerminalLogging(bool enable) {
   m_logToTerminal = enable;
}

//+------------------------------------------------------------------+
//| Append a line to the log file                                    |
//+------------------------------------------------------------------+
void CLogger::AppendLogLine(string message) {
   if (m_fileHandle != INVALID_HANDLE) {
      FileWriteString(m_fileHandle, message + "\n");
      FileFlush(m_fileHandle); // Ensure the data is written immediately
   }
}

//+------------------------------------------------------------------+
//| Format a log message with timestamp and level                    |
//+------------------------------------------------------------------+
string CLogger::FormatLogMessage(string message, ENUM_LOG_LEVEL level) {
   string levelStr = LogLevelToString(level);
   string timestamp = GetTimeStamp();
   
   return timestamp + " [" + levelStr + "] " + message;
}

//+------------------------------------------------------------------+
//| Convert log level to string                                      |
//+------------------------------------------------------------------+
string CLogger::LogLevelToString(ENUM_LOG_LEVEL level) {
   switch (level) {
      case LOG_LEVEL_ERROR: return "ERROR";
      case LOG_LEVEL_WARNING: return "WARNING";
      case LOG_LEVEL_INFO: return "INFO";
      case LOG_LEVEL_DEBUG: return "DEBUG";
      case LOG_LEVEL_VERBOSE: return "VERBOSE";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Get a formatted timestamp for logging                            |
//+------------------------------------------------------------------+
string CLogger::GetTimeStamp() {
   MqlDateTime dt;
   TimeCurrent(dt);
   
   string timestamp = StringFormat("%04d-%02d-%02d %02d:%02d:%02d",
                                  dt.year, dt.mon, dt.day, 
                                  dt.hour, dt.min, dt.sec);
   
   return timestamp;
}
