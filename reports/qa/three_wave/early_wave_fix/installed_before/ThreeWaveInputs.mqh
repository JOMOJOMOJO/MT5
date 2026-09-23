#ifndef THREE_WAVE_INPUTS
#define THREE_WAVE_INPUTS
input ENUM_TIMEFRAMES InpLowerTF              = PERIOD_M1;
input ENUM_TIMEFRAMES InpHigherTF             = PERIOD_M5;
input int             InpLowerLeftBars        = 2;
input int             InpLowerRightBars       = 2;
input int             InpHigherLeftBars       = 2;
input int             InpHigherRightBars      = 2;
input int             InpHistoryLowerBars     = 6000;
input int             InpHistoryHigherBars    = 1800;
input int             InpMaxSetupMinutes      = 240;
input double          InpFibZoneLow           = 0.382;
input double          InpFibZoneHigh          = 0.618;
input bool            InpRequireFibZone       = false;
input bool            InpRequireCloseBreak    = true;
input bool            InpShowHigherPivots     = true;
input bool            InpShowRelevantM1Pivots = true;
input bool            InpShowFibZone          = true;
input bool            InpShowStructureLines   = true;
input bool            InpDiagnosticMode       = true;
input int             InpMaxDrawSetups        = 12;


#endif
