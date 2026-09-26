# EMA display addition (2026-09-24)

- Target: `mql/Experts/USDJPY_M1_M5_3WaveIn3Wave_Long.mq5` (not CC variant).
- Added `InpShowEMAs=true` and a display-only custom indicator, M1 close EMA 20/50/100 (pink/blue/purple). No signal, order, SL/TP or Shared source edits.
- Indicator deployed to the active terminal MQL5/Indicators. EA compiled in place. Nonvisual tests skip indicator creation. Only the uniquely named attached indicator is removed on deinitialization.
- Both [EA compile](ea_compile.log) and [indicator compile](indicator_compile.log): 0 errors, 0 warnings. Chart attachment/appearance has not been tested in a running visual terminal.
- Prior EA source and binary retained as before.mq5 / before.ex5. Existing user changes to Shared/Inputs were preserved; compilation uses those current local includes, including their default-false CC options.
- Build used hidden direct MetaEditor invocation: repo compile wrapper launches without hidden mode and copies to other terminal installations, so it was not used for this narrowly scoped deployment.
- Existing colors: M5 Wave1 MediumSeaGreen; M5 pivot links DarkOrange (not dedicated Wave2); M1 Wave1 Aqua; M1 Wave2 Orange; M1 Wave3 start Lime; M1 generic pivot links SlateGray; fib50 Silver dotted horizontal.
