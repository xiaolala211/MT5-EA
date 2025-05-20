//+------------------------------------------------------------------+
//|                                                TradeManager.mqh  |
//|                        Smart Money Concepts Trading System       |
//|                                                                  |
//| Description: Class for managing trades, including position       |
//| sizing, partial profit-taking, and moving to breakeven.          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property strict

// Include Trade library
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// Trade State enumeration
enum ENUM_TRADE_STATE {
   TRADE_STATE_NEW,        // Newly opened trade
   TRADE_STATE_BREAKEVEN,  // SL moved to breakeven
   TRADE_STATE_PARTIAL_TP, // Partial TP taken
   TRADE_STATE_TRAILING,   // Trailing stop active
   TRADE_STATE_CLOSED      // Trade closed
};

//+------------------------------------------------------------------+
//| ManagedTrade structure                                           |
//+------------------------------------------------------------------+
struct ManagedTrade {
   ulong ticket;                // Trade ticket number
   ENUM_TRADE_STATE state;      // Current state of the trade
   datetime openTime;           // Time when the trade was opened
   double openPrice;            // Entry price
   double stopLoss;             // Original stop loss level
   double takeProfit;           // Original take profit level
   double lotSize;              // Original lot size
   double partialLotSize;       // Size for partial close
   double riskAmount;           // Amount risked on this trade
   bool isBreakEven;            // Whether SL is moved to breakeven
   bool isPartialClosed;        // Whether partial profit is taken
   bool isTrailingStopped;      // Whether trailing stop is activated
   
   // Constructor
   ManagedTrade() {
      ticket = 0;
      state = TRADE_STATE_NEW;
      openTime = 0;
      openPrice = 0;
      stopLoss = 0;
      takeProfit = 0;
      lotSize = 0;
      partialLotSize = 0;
      riskAmount = 0;
      isBreakEven = false;
      isPartialClosed = false;
      isTrailingStopped = false;
   }
};

//+------------------------------------------------------------------+
//| TradeManager class                                               |
//+------------------------------------------------------------------+
class CTradeManager {
private:
   double            m_riskPercentage;      // Risk per trade (% of balance)
   int               m_maxOpenTrades;       // Maximum number of open trades
   double            m_breakEvenAfterR;     // Move SL to BE after this R multiple
   bool              m_usePartialTP;        // Enable partial TP
   double            m_partialTPPercent;    // Percentage of position to close at TP1
   double            m_riskRewardRatio;     // Risk:Reward Ratio for TP2
   ManagedTrade      m_openTrades[];        // Array of managed trades
   CTrade            m_trade;               // Trade object for order execution
   CPositionInfo     m_position;            // Position info object
   
   // Private methods
   bool              ModifyStopLoss(ulong ticket, double newSL);
   bool              PartialClose(ulong ticket, double lotSize);
   double            CalculateDistance(double entryPrice, double stopLoss, ENUM_ORDER_TYPE orderType);
   double            CalculateProfitInR(double entryPrice, double currentPrice, double stopLoss, ENUM_ORDER_TYPE orderType);
   
public:
                     CTradeManager();
                    ~CTradeManager();
   
   // Initialization
   void              Initialize(double riskPercentage, int maxOpenTrades, double breakEvenAfterR, 
                               bool usePartialTP, double partialTPPercent, double riskRewardRatio);
   
   // Trade management methods
   void              RegisterTrade(ulong ticket, double entryPrice, double stopLoss, double takeProfit);
   void              ManageOpenTrades();
   int               GetOpenTradesCount();
   double            CalculateLotSize(double stopDistance);
   double            NormalizeLotSize(double lotSize);
   
   // Trade state tracking
   bool              IsBreakEvenLevelReached(ManagedTrade &trade);
   bool              IsPartialTakeProfitLevelReached(ManagedTrade &trade);
   bool              IsFinalTakeProfitLevelReached(ManagedTrade &trade);
   
   // Utility methods
   string            TradeStateToString(ENUM_TRADE_STATE state);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager() {
   m_riskPercentage = 1.0;
   m_maxOpenTrades = 3;
   m_breakEvenAfterR = 1.0;
   m_usePartialTP = true;
   m_partialTPPercent = 50.0;
   m_riskRewardRatio = 2.0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager() {
   ArrayFree(m_openTrades);
}

//+------------------------------------------------------------------+
//| Initialize the class with parameters                             |
//+------------------------------------------------------------------+
void CTradeManager::Initialize(double riskPercentage, int maxOpenTrades, double breakEvenAfterR, 
                              bool usePartialTP, double partialTPPercent, double riskRewardRatio) {
   m_riskPercentage = riskPercentage;
   m_maxOpenTrades = maxOpenTrades;
   m_breakEvenAfterR = breakEvenAfterR;
   m_usePartialTP = usePartialTP;
   m_partialTPPercent = partialTPPercent;
   m_riskRewardRatio = riskRewardRatio;
   
   // Initialize trade object
   m_trade.SetExpertMagicNumber(123456); // Set a unique magic number
   
   // Load existing open trades
   LoadOpenTrades();
}

//+------------------------------------------------------------------+
//| Register a new trade for management                              |
//+------------------------------------------------------------------+
void CTradeManager::RegisterTrade(ulong ticket, double entryPrice, double stopLoss, double takeProfit) {
   // Make sure the trade exists
   if (!m_position.SelectByTicket(ticket)) {
      Print("Failed to register trade: position with ticket ", ticket, " not found");
      return;
   }
   
   // Create a new managed trade
   ManagedTrade trade;
   trade.ticket = ticket;
   trade.state = TRADE_STATE_NEW;
   trade.openTime = TimeCurrent();
   trade.openPrice = entryPrice;
   trade.stopLoss = stopLoss;
   trade.takeProfit = takeProfit;
   trade.lotSize = m_position.Volume();
   trade.partialLotSize = trade.lotSize * (m_partialTPPercent / 100.0);
   
   // Calculate risk amount
   double riskPerPoint = trade.lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopDistance = MathAbs(entryPrice - stopLoss) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   trade.riskAmount = riskPerPoint * stopDistance;
   
   // Add to managed trades array
   int size = ArraySize(m_openTrades);
   ArrayResize(m_openTrades, size + 1);
   m_openTrades[size] = trade;
   
   Print("Trade registered: Ticket=", ticket, ", Entry=", DoubleToString(entryPrice, _Digits), 
         ", SL=", DoubleToString(stopLoss, _Digits), ", TP=", DoubleToString(takeProfit, _Digits),
         ", Lots=", DoubleToString(trade.lotSize, 2));
}

//+------------------------------------------------------------------+
//| Load existing open trades                                        |
//+------------------------------------------------------------------+
void CTradeManager::LoadOpenTrades() {
   // Clear the current trades array
   ArrayFree(m_openTrades);
   ArrayResize(m_openTrades, 0);
   
   // Loop through all open positions
   for (int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      
      // Select the position
      if (PositionSelectByTicket(ticket)) {
         // Get position details
         string symbol = PositionGetString(POSITION_SYMBOL);
         
         // Only manage positions for the current symbol and with our magic number
         if (symbol == _Symbol && PositionGetInteger(POSITION_MAGIC) == m_trade.RequestMagic()) {
            ManagedTrade trade;
            trade.ticket = ticket;
            trade.state = TRADE_STATE_NEW;
            trade.openTime = (datetime)PositionGetInteger(POSITION_TIME);
            trade.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            trade.stopLoss = PositionGetDouble(POSITION_SL);
            trade.takeProfit = PositionGetDouble(POSITION_TP);
            trade.lotSize = PositionGetDouble(POSITION_VOLUME);
            trade.partialLotSize = trade.lotSize * (m_partialTPPercent / 100.0);
            
            // Calculate risk amount
            double riskPerPoint = trade.lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double stopDistance = MathAbs(trade.openPrice - trade.stopLoss) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            trade.riskAmount = riskPerPoint * stopDistance;
            
            // Determine the state based on SL position
            if (trade.stopLoss == trade.openPrice) {
               trade.state = TRADE_STATE_BREAKEVEN;
               trade.isBreakEven = true;
            }
            
            // Add to managed trades array
            int size = ArraySize(m_openTrades);
            ArrayResize(m_openTrades, size + 1);
            m_openTrades[size] = trade;
            
            Print("Loaded existing trade: Ticket=", ticket, ", Entry=", DoubleToString(trade.openPrice, _Digits), 
                  ", SL=", DoubleToString(trade.stopLoss, _Digits), ", TP=", DoubleToString(trade.takeProfit, _Digits),
                  ", Lots=", DoubleToString(trade.lotSize, 2));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage all open trades                                           |
//+------------------------------------------------------------------+
void CTradeManager::ManageOpenTrades() {
   // Update and manage each registered trade
   for (int i = 0; i < ArraySize(m_openTrades); i++) {
      // Check if the trade is still open
      if (!m_position.SelectByTicket(m_openTrades[i].ticket)) {
         // Trade has been closed, mark it for removal
         m_openTrades[i].state = TRADE_STATE_CLOSED;
         continue;
      }
      
      // Get current trade details
      double currentPrice = m_position.PriceOpen();
      double currentSL = m_position.StopLoss();
      ENUM_POSITION_TYPE posType = m_position.PositionType();
      ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      
      // Check if criteria for breakeven are met
      if (!m_openTrades[i].isBreakEven && IsBreakEvenLevelReached(m_openTrades[i])) {
         // Move SL to breakeven (entry price)
         if (ModifyStopLoss(m_openTrades[i].ticket, m_openTrades[i].openPrice)) {
            m_openTrades[i].isBreakEven = true;
            m_openTrades[i].state = TRADE_STATE_BREAKEVEN;
            Print("SL moved to breakeven for trade #", m_openTrades[i].ticket);
         }
      }
      
      // Check if criteria for partial TP are met
      if (m_usePartialTP && !m_openTrades[i].isPartialClosed && IsPartialTakeProfitLevelReached(m_openTrades[i])) {
         // Calculate the lot size for partial close
         double partialLots = MathMin(m_openTrades[i].partialLotSize, m_position.Volume());
         
         // Partial close the position
         if (PartialClose(m_openTrades[i].ticket, partialLots)) {
            m_openTrades[i].isPartialClosed = true;
            m_openTrades[i].state = TRADE_STATE_PARTIAL_TP;
            Print("Partial profit taken for trade #", m_openTrades[i].ticket, ", Lots=", DoubleToString(partialLots, 2));
         }
      }
      
      // Check if criteria for trailing stop are met
      // In this simple implementation, we just use final TP level
      if (m_openTrades[i].isBreakEven && !m_openTrades[i].isTrailingStopped && IsFinalTakeProfitLevelReached(m_openTrades[i])) {
         // Calculate new SL at a profitable level
         double newSL = 0;
         double profitInPoints = MathAbs(m_position.PriceCurrent() - m_openTrades[i].openPrice) / _Point;
         
         if (orderType == ORDER_TYPE_BUY) {
            newSL = m_openTrades[i].openPrice + (profitInPoints * _Point * 0.5); // Move to 50% of the profit
         } else {
            newSL = m_openTrades[i].openPrice - (profitInPoints * _Point * 0.5); // Move to 50% of the profit
         }
         
         // Modify SL to the new level
         if (ModifyStopLoss(m_openTrades[i].ticket, newSL)) {
            m_openTrades[i].isTrailingStopped = true;
            m_openTrades[i].state = TRADE_STATE_TRAILING;
            Print("Trailing stop activated for trade #", m_openTrades[i].ticket, ", New SL=", DoubleToString(newSL, _Digits));
         }
      }
   }
   
   // Remove closed trades from the array
   for (int i = ArraySize(m_openTrades) - 1; i >= 0; i--) {
      if (m_openTrades[i].state == TRADE_STATE_CLOSED) {
         // Remove this trade from the array
         for (int j = i; j < ArraySize(m_openTrades) - 1; j++) {
            m_openTrades[j] = m_openTrades[j+1];
         }
         ArrayResize(m_openTrades, ArraySize(m_openTrades) - 1);
      }
   }
}

//+------------------------------------------------------------------+
//| Modify stop loss for a trade                                     |
//+------------------------------------------------------------------+
bool CTradeManager::ModifyStopLoss(ulong ticket, double newSL) {
   // Select the position
   if (!m_position.SelectByTicket(ticket)) {
      Print("Failed to modify SL: position with ticket ", ticket, " not found");
      return false;
   }
   
   // Get current position parameters
   double currentTP = m_position.TakeProfit();
   
   // Modify the position
   return m_trade.PositionModify(ticket, newSL, currentTP);
}

//+------------------------------------------------------------------+
//| Partially close a trade                                          |
//+------------------------------------------------------------------+
bool CTradeManager::PartialClose(ulong ticket, double lotSize) {
   // Select the position
   if (!m_position.SelectByTicket(ticket)) {
      Print("Failed to partially close: position with ticket ", ticket, " not found");
      return false;
   }
   
   // Make sure the lot size is valid
   lotSize = MathMin(lotSize, m_position.Volume());
   lotSize = NormalizeLotSize(lotSize);
   
   if (lotSize <= 0 || lotSize > m_position.Volume()) {
      Print("Invalid lot size for partial close: ", DoubleToString(lotSize, 2));
      return false;
   }
   
   // Close part of the position
   return m_trade.PositionClosePartial(ticket, lotSize);
}

//+------------------------------------------------------------------+
//| Calculate the distance between entry and stop loss in points     |
//+------------------------------------------------------------------+
double CTradeManager::CalculateDistance(double entryPrice, double stopLoss, ENUM_ORDER_TYPE orderType) {
   if (orderType == ORDER_TYPE_BUY) {
      return (entryPrice - stopLoss) / _Point;
   } else {
      return (stopLoss - entryPrice) / _Point;
   }
}

//+------------------------------------------------------------------+
//| Calculate profit in terms of R multiple                          |
//+------------------------------------------------------------------+
double CTradeManager::CalculateProfitInR(double entryPrice, double currentPrice, double stopLoss, ENUM_ORDER_TYPE orderType) {
   // Calculate the initial risk (1R) in points
   double initialRisk = MathAbs(entryPrice - stopLoss) / _Point;
   
   // Calculate the current profit/loss in points
   double currentProfit = 0;
   if (orderType == ORDER_TYPE_BUY) {
      currentProfit = (currentPrice - entryPrice) / _Point;
   } else {
      currentProfit = (entryPrice - currentPrice) / _Point;
   }
   
   // Calculate profit in R
   return (initialRisk > 0) ? currentProfit / initialRisk : 0;
}

//+------------------------------------------------------------------+
//| Check if breakeven level has been reached                        |
//+------------------------------------------------------------------+
bool CTradeManager::IsBreakEvenLevelReached(ManagedTrade &trade) {
   // Select the position
   if (!m_position.SelectByTicket(trade.ticket)) {
      return false;
   }
   
   // Determine order type
   ENUM_POSITION_TYPE posType = m_position.PositionType();
   ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   // Calculate current profit in R
   double profitInR = CalculateProfitInR(trade.openPrice, m_position.PriceCurrent(), trade.stopLoss, orderType);
   
   // Check if profit has reached the breakeven threshold
   return profitInR >= m_breakEvenAfterR;
}

//+------------------------------------------------------------------+
//| Check if partial take profit level has been reached              |
//+------------------------------------------------------------------+
bool CTradeManager::IsPartialTakeProfitLevelReached(ManagedTrade &trade) {
   // Select the position
   if (!m_position.SelectByTicket(trade.ticket)) {
      return false;
   }
   
   // Determine order type
   ENUM_POSITION_TYPE posType = m_position.PositionType();
   ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   // Calculate current profit in R
   double profitInR = CalculateProfitInR(trade.openPrice, m_position.PriceCurrent(), trade.stopLoss, orderType);
   
   // Check if profit has reached half the target R:R
   return profitInR >= (m_riskRewardRatio / 2);
}

//+------------------------------------------------------------------+
//| Check if final take profit level has been reached                |
//+------------------------------------------------------------------+
bool CTradeManager::IsFinalTakeProfitLevelReached(ManagedTrade &trade) {
   // Select the position
   if (!m_position.SelectByTicket(trade.ticket)) {
      return false;
   }
   
   // Determine order type
   ENUM_POSITION_TYPE posType = m_position.PositionType();
   ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   // Calculate current profit in R
   double profitInR = CalculateProfitInR(trade.openPrice, m_position.PriceCurrent(), trade.stopLoss, orderType);
   
   // Check if profit has reached the full target R:R
   return profitInR >= m_riskRewardRatio;
}

//+------------------------------------------------------------------+
//| Get the count of currently open managed trades                   |
//+------------------------------------------------------------------+
int CTradeManager::GetOpenTradesCount() {
   return ArraySize(m_openTrades);
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage and stop distance    |
//+------------------------------------------------------------------+
double CTradeManager::CalculateLotSize(double stopDistance) {
   if (stopDistance <= 0) return 0;
   
   // Get account balance
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Calculate risk amount in account currency
   double riskAmount = balance * (m_riskPercentage / 100.0);
   
   // Get tick value in account currency
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   // Calculate lot size
   double lotSize = riskAmount / (stopDistance * tickValue / _Point);
   
   // Normalize lot size
   return NormalizeLotSize(lotSize);
}

//+------------------------------------------------------------------+
//| Normalize lot size according to broker requirements              |
//+------------------------------------------------------------------+
double CTradeManager::NormalizeLotSize(double lotSize) {
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
//| Convert trade state to string for logging                        |
//+------------------------------------------------------------------+
string CTradeManager::TradeStateToString(ENUM_TRADE_STATE state) {
   switch (state) {
      case TRADE_STATE_NEW: return "New";
      case TRADE_STATE_BREAKEVEN: return "BreakEven";
      case TRADE_STATE_PARTIAL_TP: return "PartialTP";
      case TRADE_STATE_TRAILING: return "Trailing";
      case TRADE_STATE_CLOSED: return "Closed";
      default: return "Unknown";
   }
}
