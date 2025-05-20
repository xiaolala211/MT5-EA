//+------------------------------------------------------------------+
//|                                           SMC_ExpertAdvisor.mq5  |
//|                        Smart Money Concepts Trading System       |
//|                                                                  |
//| Description: Expert Advisor implementing Smart Money Concepts    |
//| trading strategy with multi-timeframe analysis.                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property link      ""
#property version   "1.00"
#property strict

// Include necessary files
#include <Trade\Trade.mqh>
#include "Include\SMC\MarketStructure.mqh"
#include "Include\SMC\OrderBlocks.mqh"
#include "Include\SMC\FairValueGaps.mqh"
#include "Include\SMC\LiquidityAnalysis.mqh"
#include "Include\SMC\WyckoffPhases.mqh"
#include "Include\SMC\SupplyDemand.mqh"
#include "Include\SMC\TimeAnalysis.mqh"
#include "Include\SMC\TradeManager.mqh"
#include "Include\SMC\Utilities.mqh"
#include "Include\SMC\Logger.mqh"

// Input parameters
input group "General Settings"
input bool   EnableTrading = true;          // Enable automatic trading
input double RiskPercentage = 1.0;          // Risk per trade (% of balance)
input int    MaxOpenTrades = 3;             // Maximum number of open trades

input group "Timeframe Settings"
input bool   UseWeekly = true;              // Use Weekly timeframe for HTF analysis
input bool   UseDaily = true;               // Use Daily timeframe for HTF analysis
input bool   UseH4 = true;                  // Use H4 timeframe for MTF analysis
input bool   UseH1 = true;                  // Use H1 timeframe for MTF analysis
input bool   UseM15 = true;                 // Use M15 timeframe for LTF analysis
input bool   UseM5 = true;                  // Use M5 timeframe for LTF analysis
input bool   UseM1 = false;                 // Use M1 timeframe for LTF analysis

input group "Market Structure Settings"
input int    MSLookback = 20;               // Number of bars to analyze for market structure
input int    OBLookback = 10;               // Number of bars to analyze for order blocks
input int    FVGLookback = 10;              // Number of bars to analyze for FVGs

input group "Liquidity Settings"
input int    LiquidityRange = 10;           // Range to look for liquidity (pips)
input int    LGLookback = 5;                // Lookback period for liquidity grabs

input group "Trade Management"
input double BreakEvenAfterR = 1.0;         // Move SL to BE after this R multiple
input bool   UsePartialTakeProfit = true;   // Enable partial TP
input double PartialTPPercent = 50.0;       // Percentage of position to close at TP1
input double RRRatio = 2.0;                 // Risk:Reward Ratio for TP2

input group "ICT Kill Zone Settings"
input bool   UseLondonSession = true;       // Use London session kill zone
input bool   UseNewYorkSession = true;      // Use New York session kill zone

input group "Advanced Settings"
input bool   EnableLogging = true;          // Enable detailed logging
input int    MinPipsForLG = 10;             // Minimum pips for liquidity grab
input int    FVGMinSize = 5;                // Minimum FVG size in pips

// Global variables
CTrade trade;                   // Trade object for order execution
CLogger logger;                 // Logger object
CMarketStructure marketStructure; // Market structure analyzer
COrderBlocks orderBlocks;       // Order blocks analyzer
CFairValueGaps fvgAnalysis;     // Fair Value Gaps analyzer
CLiquidityAnalysis liquidityAnalysis; // Liquidity analyzer
CWyckoffPhases wyckoffPhases;   // Wyckoff phases analyzer
CSupplyDemand supplyDemand;     // Supply/Demand zones analyzer
CTimeAnalysis timeAnalysis;     // Time-based analysis (ICT Kill Zones)
CTradeManager tradeManager;     // Trade management
CUtilities utilities;           // Utility functions

ENUM_TIMEFRAME HTFArray[2];     // Higher timeframes array
ENUM_TIMEFRAME MTFArray[2];     // Medium timeframes array
ENUM_TIMEFRAME LTFArray[3];     // Lower timeframes array

enum ENUM_BIAS {
   BIAS_BULLISH,
   BIAS_BEARISH,
   BIAS_NEUTRAL
};

ENUM_BIAS   currentBias = BIAS_NEUTRAL;
bool        inHtfPOI = false;   // Price in HTF Point of Interest
bool        inMtfPOI = false;   // Price in MTF Point of Interest
bool        inKillZone = false; // In an ICT Kill Zone
bool        hasLiquidityGrab = false; // Detected a recent liquidity grab
bool        hasChoch = false;   // Detected a Change of Character
bool        hasBOS = false;     // Detected a Break of Structure

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Initialize logger
   if (EnableLogging) {
      logger.Initialize("SMC_EA_Log.txt");
      logger.Log("SMC Expert Advisor initialized");
   }
   
   // Set up timeframe arrays
   int htfIndex = 0;
   if (UseWeekly) HTFArray[htfIndex++] = PERIOD_W1;
   if (UseDaily) HTFArray[htfIndex++] = PERIOD_D1;
   
   int mtfIndex = 0;
   if (UseH4) MTFArray[mtfIndex++] = PERIOD_H4;
   if (UseH1) MTFArray[mtfIndex++] = PERIOD_H1;
   
   int ltfIndex = 0;
   if (UseM15) LTFArray[ltfIndex++] = PERIOD_M15;
   if (UseM5) LTFArray[ltfIndex++] = PERIOD_M5;
   if (UseM1) LTFArray[ltfIndex++] = PERIOD_M1;
   
   // Check if at least one timeframe is selected in each category
   if (htfIndex == 0 || mtfIndex == 0 || ltfIndex == 0) {
      logger.Log("Error: At least one timeframe must be selected in each category (HTF, MTF, LTF)");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Initialize objects with parameters
   marketStructure.Initialize(MSLookback);
   orderBlocks.Initialize(OBLookback, MinPipsForLG);
   fvgAnalysis.Initialize(FVGLookback, FVGMinSize);
   liquidityAnalysis.Initialize(LiquidityRange, LGLookback);
   wyckoffPhases.Initialize(30); // Lookback for Wyckoff analysis
   supplyDemand.Initialize(20);  // Lookback for S/D zones
   timeAnalysis.Initialize(UseLondonSession, UseNewYorkSession);
   tradeManager.Initialize(RiskPercentage, MaxOpenTrades, BreakEvenAfterR, 
                          UsePartialTakeProfit, PartialTPPercent, RRRatio);
   
   // Set up trade object
   trade.SetExpertMagicNumber(123456); // Set a unique magic number
   
   logger.Log("Expert initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   logger.Log("Expert Advisor deinitialized. Reason: " + 
              utilities.GetDeinitReasonText(reason));
   logger.Deinitialize();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   // Check if trading is allowed
   if (!EnableTrading) return;
   
   // Skip processing if there's no new bar on the lowest timeframe
   if (!IsNewBar(LTFArray[0])) return;
   
   // Update current market conditions
   inKillZone = timeAnalysis.IsInKillZone();
   
   // Stage 1: HTF Analysis - Determining Directional Bias
   AnalyzeHigherTimeframes();
   
   // Stage 2: MTF Analysis - Refining POIs and Waiting
   if (currentBias != BIAS_NEUTRAL) {
      AnalyzeMediumTimeframes();
   }
   
   // Stage 3: LTF Analysis - Seeking Trade Setups and Entry Signals
   if (inMtfPOI || inHtfPOI) {
      AnalyzeLowerTimeframes();
   }
   
   // Stage 4: Execution and Trade Management (if setup conditions are met)
   if (ShouldEnterTrade()) {
      ExecuteTrade();
   }
   
   // Always manage open trades
   tradeManager.ManageOpenTrades();
}

//+------------------------------------------------------------------+
//| Check if a new bar has formed on the specified timeframe         |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES timeframe) {
   static datetime last_time = 0;
   datetime current_time = iTime(_Symbol, timeframe, 0);
   
   if (current_time != last_time) {
      last_time = current_time;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Stage 1: Analyze Higher Timeframes for directional bias          |
//+------------------------------------------------------------------+
void AnalyzeHigherTimeframes() {
   // Reset HTF analysis flags
   inHtfPOI = false;
   currentBias = BIAS_NEUTRAL;
   
   string htfAnalysis = "";
   
   // Analyze each HTF timeframe
   for (int i = 0; i < ArraySize(HTFArray); i++) {
      if (HTFArray[i] == 0) continue; // Skip if timeframe not selected
      
      ENUM_TIMEFRAME tf = HTFArray[i];
      string tfName = utilities.TimeframeToString(tf);
      
      // Analyze the market structure on this timeframe
      ENUM_MARKET_STRUCTURE_TYPE msType = marketStructure.AnalyzeStructure(tf);
      
      // Analyze Wyckoff/AMD cycle phase
      ENUM_MARKET_PHASE marketPhase = wyckoffPhases.DetermineMarketPhase(tf);
      
      // Based on market structure and phase, determine bias
      ENUM_BIAS tfBias = BIAS_NEUTRAL;
      
      if (msType == MS_UPTREND && 
          (marketPhase == PHASE_ACCUMULATION_LATE || 
           marketPhase == PHASE_MARKUP)) {
         tfBias = BIAS_BULLISH;
      }
      else if (msType == MS_DOWNTREND && 
              (marketPhase == PHASE_DISTRIBUTION_LATE || 
               marketPhase == PHASE_MARKDOWN)) {
         tfBias = BIAS_BEARISH;
      }
      
      // Higher priority to lower HTF timeframe (e.g., Daily over Weekly)
      if (tfBias != BIAS_NEUTRAL) {
         currentBias = tfBias;
      }
      
      // Check if current price is in HTF POI
      bool inSupplyZone = (tfBias == BIAS_BEARISH) && 
                          supplyDemand.IsInSupplyZone(tf);
      
      bool inDemandZone = (tfBias == BIAS_BULLISH) && 
                           supplyDemand.IsInDemandZone(tf);
      
      bool inOB = orderBlocks.IsInRelevantOrderBlock(tf, tfBias);
      bool inFVG = fvgAnalysis.IsInRelevantFVG(tf, tfBias);
      
      // If price is in any HTF POI that aligns with bias
      if (inSupplyZone || inDemandZone || inOB || inFVG) {
         inHtfPOI = true;
      }
      
      // Logging for this timeframe
      htfAnalysis += tfName + ": ";
      htfAnalysis += "Structure=" + marketStructure.MarketStructureToString(msType) + ", ";
      htfAnalysis += "Phase=" + wyckoffPhases.MarketPhaseToString(marketPhase) + ", ";
      htfAnalysis += "Bias=" + (tfBias == BIAS_BULLISH ? "Bullish" : 
                               (tfBias == BIAS_BEARISH ? "Bearish" : "Neutral")) + ", ";
      htfAnalysis += "In POI=" + (inHtfPOI ? "Yes" : "No") + "\n";
   }
   
   logger.Log("HTF Analysis Complete: " + 
              (currentBias == BIAS_BULLISH ? "BULLISH" :
               currentBias == BIAS_BEARISH ? "BEARISH" : "NEUTRAL"));
   logger.Log(htfAnalysis);
}

//+------------------------------------------------------------------+
//| Stage 2: Analyze Medium Timeframes to refine POIs                |
//+------------------------------------------------------------------+
void AnalyzeMediumTimeframes() {
   // Reset MTF analysis flags
   inMtfPOI = false;
   
   string mtfAnalysis = "";
   
   // Analyze each MTF timeframe
   for (int i = 0; i < ArraySize(MTFArray); i++) {
      if (MTFArray[i] == 0) continue; // Skip if timeframe not selected
      
      ENUM_TIMEFRAME tf = MTFArray[i];
      string tfName = utilities.TimeframeToString(tf);
      
      // Check if MTF structure aligns with HTF bias
      ENUM_MARKET_STRUCTURE_TYPE msType = marketStructure.AnalyzeStructure(tf);
      bool structureAligned = false;
      
      if ((currentBias == BIAS_BULLISH && 
           (msType == MS_UPTREND || msType == MS_ACCUMULATION)) ||
          (currentBias == BIAS_BEARISH && 
           (msType == MS_DOWNTREND || msType == MS_DISTRIBUTION))) {
         structureAligned = true;
      }
      
      // Only proceed if structure is aligned with HTF bias
      if (structureAligned) {
         // Check for MTF POIs that align with bias
         bool inSupplyZone = (currentBias == BIAS_BEARISH) && 
                             supplyDemand.IsInSupplyZone(tf);
         
         bool inDemandZone = (currentBias == BIAS_BULLISH) && 
                             supplyDemand.IsInDemandZone(tf);
         
         bool inOB = orderBlocks.IsInRelevantOrderBlock(tf, currentBias);
         bool inFVG = fvgAnalysis.IsInRelevantFVG(tf, currentBias);
         
         // If price is in any MTF POI that aligns with bias
         if (inSupplyZone || inDemandZone || inOB || inFVG) {
            inMtfPOI = true;
         }
         
         mtfAnalysis += tfName + ": ";
         mtfAnalysis += "Structure=" + marketStructure.MarketStructureToString(msType) + ", ";
         mtfAnalysis += "Aligned=" + (structureAligned ? "Yes" : "No") + ", ";
         mtfAnalysis += "In POI=" + (inMtfPOI ? "Yes" : "No") + 
                        (inSupplyZone ? " (Supply)" : "") + 
                        (inDemandZone ? " (Demand)" : "") + 
                        (inOB ? " (OB)" : "") + 
                        (inFVG ? " (FVG)" : "") + "\n";
      }
   }
   
   logger.Log("MTF Analysis Complete: In MTF POI = " + (inMtfPOI ? "YES" : "NO"));
   logger.Log(mtfAnalysis);
}

//+------------------------------------------------------------------+
//| Stage 3: Analyze Lower Timeframes for specific entry signals     |
//+------------------------------------------------------------------+
void AnalyzeLowerTimeframes() {
   // Reset LTF analysis flags
   hasLiquidityGrab = false;
   hasChoch = false;
   hasBOS = false;
   
   string ltfAnalysis = "";
   
   // Only proceed with LTF analysis if we're in an HTF or MTF POI
   if (!inHtfPOI && !inMtfPOI) return;
   
   // Analyze each LTF timeframe
   for (int i = 0; i < ArraySize(LTFArray); i++) {
      if (LTFArray[i] == 0) continue; // Skip if timeframe not selected
      
      ENUM_TIMEFRAME tf = LTFArray[i];
      string tfName = utilities.TimeframeToString(tf);
      
      // Check for liquidity grab signals
      hasLiquidityGrab = liquidityAnalysis.DetectLiquidityGrab(tf, currentBias);
      
      // Check for Change of Character and Break of Structure
      hasChoch = marketStructure.DetectCHoCH(tf, currentBias);
      hasBOS = marketStructure.DetectBOS(tf, currentBias);
      
      // Check for LTF confirmations
      bool hasFVG = fvgAnalysis.HasFreshFVG(tf, currentBias);
      bool hasOB = orderBlocks.HasFreshOrderBlock(tf, currentBias);
      
      ltfAnalysis += tfName + ": ";
      ltfAnalysis += "LG=" + (hasLiquidityGrab ? "Yes" : "No") + ", ";
      ltfAnalysis += "CHoCH=" + (hasChoch ? "Yes" : "No") + ", ";
      ltfAnalysis += "BOS=" + (hasBOS ? "Yes" : "No") + ", ";
      ltfAnalysis += "FVG=" + (hasFVG ? "Yes" : "No") + ", ";
      ltfAnalysis += "OB=" + (hasOB ? "Yes" : "No") + "\n";
      
      // If we've found confirmation on this timeframe, no need to check lower ones
      if (hasLiquidityGrab && hasChoch && hasBOS && (hasFVG || hasOB)) {
         break;
      }
   }
   
   logger.Log("LTF Analysis Complete: Setup conditions = " + 
             (ShouldEnterTrade() ? "MET" : "NOT MET"));
   logger.Log(ltfAnalysis);
}

//+------------------------------------------------------------------+
//| Determine if trade entry conditions are met                      |
//+------------------------------------------------------------------+
bool ShouldEnterTrade() {
   // We need a valid bias from HTF
   if (currentBias == BIAS_NEUTRAL) return false;
   
   // We need to be in a Point of Interest
   if (!inHtfPOI && !inMtfPOI) return false;
   
   // Prefer to trade in ICT Kill Zones, but can be overridden
   // based on very strong setup conditions
   bool strongSetup = hasLiquidityGrab && hasChoch && hasBOS;
   
   if (!inKillZone && !strongSetup) return false;
   
   // For entry, we need proper confirmation
   return hasLiquidityGrab && hasChoch && hasBOS;
}

//+------------------------------------------------------------------+
//| Execute trade based on current setup                             |
//+------------------------------------------------------------------+
void ExecuteTrade() {
   // Check if we're already at max trades
   if (tradeManager.GetOpenTradesCount() >= MaxOpenTrades) {
      logger.Log("Max open trades limit reached, not entering new trade");
      return;
   }
   
   ENUM_ORDER_TYPE orderType = (currentBias == BIAS_BULLISH) ? 
                               ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   // Get current price
   double entryPrice = (orderType == ORDER_TYPE_BUY) ? 
                       SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                       SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculate SL and TP based on relevant POIs and current setup
   double stopLoss = 0, takeProfit = 0;
   
   // For buy orders
   if (orderType == ORDER_TYPE_BUY) {
      // SL typically below the liquidity grab low or a relevant structure level
      stopLoss = liquidityAnalysis.GetBuyStopLossLevel();
      
      // If not available, use the last significant low
      if (stopLoss == 0) {
         stopLoss = marketStructure.GetLastSignificantLow(LTFArray[0]);
      }
      
      // TP typically at next HTF/MTF resistance or liquidity level
      takeProfit = liquidityAnalysis.GetBuyTakeProfitLevel();
      
      // If not available, use R:R ratio
      if (takeProfit == 0) {
         double slDistance = entryPrice - stopLoss;
         takeProfit = entryPrice + (slDistance * RRRatio);
      }
   }
   // For sell orders
   else {
      // SL typically above the liquidity grab high or a relevant structure level
      stopLoss = liquidityAnalysis.GetSellStopLossLevel();
      
      // If not available, use the last significant high
      if (stopLoss == 0) {
         stopLoss = marketStructure.GetLastSignificantHigh(LTFArray[0]);
      }
      
      // TP typically at next HTF/MTF support or liquidity level
      takeProfit = liquidityAnalysis.GetSellTakeProfitLevel();
      
      // If not available, use R:R ratio
      if (takeProfit == 0) {
         double slDistance = stopLoss - entryPrice;
         takeProfit = entryPrice - (slDistance * RRRatio);
      }
   }
   
   // Validate SL and TP
   if (stopLoss == 0 || takeProfit == 0) {
      logger.Log("Failed to determine valid SL/TP levels, trade not executed");
      return;
   }
   
   // Calculate position size based on risk percentage
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercentage / 100.0);
   double slDistance = MathAbs(entryPrice - stopLoss);
   double pipValue = utilities.CalculatePipValue();
   double lotSize = 0;
   
   if (slDistance > 0 && pipValue > 0) {
      lotSize = riskAmount / (slDistance * pipValue / _Point);
      lotSize = utilities.NormalizeLotSize(lotSize);
   }
   
   if (lotSize <= 0) {
      logger.Log("Invalid lot size calculated, trade not executed");
      return;
   }
   
   // Execute the trade
   bool result = trade.PositionOpen(_Symbol, orderType, lotSize, entryPrice, stopLoss, takeProfit, "SMC EA");
   
   if (result) {
      logger.Log("Trade executed successfully: " + 
                EnumToString(orderType) + ", Lot: " + DoubleToString(lotSize, 2) + 
                ", Entry: " + DoubleToString(entryPrice, _Digits) + 
                ", SL: " + DoubleToString(stopLoss, _Digits) + 
                ", TP: " + DoubleToString(takeProfit, _Digits));
      
      // Register this trade with the trade manager for further management
      tradeManager.RegisterTrade(trade.ResultOrder(), entryPrice, stopLoss, takeProfit);
   } else {
      logger.Log("Trade execution failed: " + IntegerToString(trade.ResultRetcode()) + 
                " - " + trade.ResultRetcodeDescription());
   }
}
