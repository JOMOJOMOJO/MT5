# Tick-shock Step 3 independent oracle calculations

## Oracle independence

Expected values in this document were derived from the stated formulas and
literal fixture values. No MQL production function, EX5, Strategy Tester result,
baseline outcome, or copied implementation branch was used to generate an
expected value. Step 5 may parse these CSV files but must not update them.

Decimal price arithmetic is shown before tolerance is applied. Natural log
values are mathematical <code>ln(newer/older)</code>. Tick rounding is defined
directly as:

<pre>
ceil_tick(x)  = ceil(x / tick_size) * tick_size
floor_tick(x) = floor(x / tick_size) * tick_size
</pre>

## 1. Clock, delay, and causality

### REALIZABLE_EA formula

<pre>
event_due      = signal_event_msc + requested_delay_ms
processing_due = signal_processing_msc + submit_latency_ms
eligible       = max(event_due, processing_due)
</pre>

A candidate quote is usable only when it is a real same-symbol quote,
<code>quote_msc &gt; signal_event_msc</code>,
<code>quote_msc &gt;= eligible</code>, and
<code>quote_msc &gt;= signal_processing_msc</code>.

#### TS-TIME-001

<pre>
signal_event       = 1000
signal_processing  = 1600
delay              = 0
submit_latency     = 0
event_due          = 1000
processing_due     = 1600
eligible           = 1600
</pre>

Quotes 1100 and 1599 are rejected. The real quote at 1600 is accepted. Entry
before processing and entry before eligibility both remain zero.

#### TS-TIME-002 / 003 / 004

| Test | Event | Delay | Eligible | -1 ms | equality | +1 ms |
|---|---:|---:|---:|---|---|---|
| TS-TIME-002 | 1000 | 0 | 1000 | signal tick 1000 is rejected by strict later-tick rule | first real 1001 accepted | later |
| TS-TIME-003 | 1000 | 100 | 1100 | 1099 reject | 1100 accept | 1101 later |
| TS-TIME-004 | 1000 | 250 | 1250 | 1249 reject | 1250 accept | 1251 later |

The 0 ms case differs from ordinary equality: a quote at the signal event time
is prohibited even though it equals eligibility.

#### TS-TIME-005

<pre>
event_due      = 1000 + 100 = 1100
processing_due = 1200 + 50  = 1250
eligible       = max(1100,1250) = 1250
</pre>

Quote 1249 rejects; quote 1250 accepts.

#### TS-TIME-006

Eligibility is 1250 but there is no 1250 quote. Quotes are not interpolated.
The first later real quote is 1251.

### Stale detection quote

For TS-DETECT-001:

<pre>
detection_grid_msc      = 1000
detection_quote_msc     = 950
detection_quote_age_ms  = 1000 - 950 = 50
</pre>

There is no real quote at 1000. Detection can be represented at the grid
boundary, but entry cannot. The first later real quote is 1030; a generated
entry timestamp 1000 is forbidden.

### Global merge lag

For TS-MERGE-002:

<pre>
signal_event_msc      = 1000
signal_processing_msc = 1600
merge_lag_ms          = 1600 - 1000 = 600
eligible              = max(1000,1600) = 1600
</pre>

The held historical quote is not retrospectively executable. The first
same-symbol quote after recognition in the fixture is 1601.

### Reversal clock

For TS-REV-001, the state threshold is first met at 3000:

<pre>
continuation_invalidated_msc = 3000
reversal_signal_msc          = 3000
processing_msc               = 3600
eligible                     = max(3000,3600) = 3600
</pre>

The signal is not reassigned to 3100 or 3600. A real quote at 3600 is later than
the signal and is eligible.

## 2. Detector calculations

### Independent 250/500/1000 ms log returns

TS-RET-001 event Mid is 1.0020 at 2000 ms.

<pre>
250 ms anchor  = 1.0015 at 1750
return_250     = ln(1.0020 / 1.0015)
               = 0.000499126539

500 ms anchor  = 1.0010 at 1500
return_500     = ln(1.0020 / 1.0010)
               = 0.000998502330

1000 ms anchor = 1.0000 at 1000
return_1000    = ln(1.0020 / 1.0000)
               = 0.001998002663
</pre>

All values are distinct. For TS-RET-002 the required 1000 ms anchor is 1000,
but the only candidate is 1001. Exact-match validity is false and the CSV value
is blank, not numeric zero.

### Percentile

TS-PCT-001 uses sorted half-tick bins <code>[2,4,6,8]</code> and type-7 linear
rank:

<pre>
rank = 0.75 * (4 - 1) = 2.25
lo = value[2] = 6
hi = value[3] = 8
quantile_bin = 6 + (8 - 6) * 0.25 = 6.5
half_tick = 0.00005
quantile_price = 6.5 * 0.00005 = 0.000325
</pre>

### Robust Z and MAD

TS-Z-001:

<pre>
raw_scale = 1.4826 * 0.00005 = 0.00007413
noise_floor = 0.00001
robust_scale = max(raw_scale,noise_floor) = 0.00007413
Z = (0.0005 - 0.0002) / 0.00007413
  = 4.046944556860
</pre>

TS-Z-002:

<pre>
MAD = 0
raw_scale = 0
noise_floor_price = 1 tick * 0.00010 = 0.00010
robust_scale = 0.00010
Z = (0.00045 - 0.00010) / 0.00010 = 3.5
</pre>

The result is finite and <code>scale_floored=true</code>.

### Directional efficiency

TS-EFF-001 Mid path is
<code>1.0000 → 1.0003 → 1.0002 → 1.0005</code>.

<pre>
net displacement = abs(1.0005 - 1.0000) = 0.0005
path length = 0.0003 + 0.0001 + 0.0003 = 0.0007
efficiency = 0.0005 / 0.0007 = 0.714285714286
</pre>

TS-EFF-002 has path length zero, so validity is false and no event is created.

### Gate ratios and boundaries

TS-INT-001:

<pre>
29 / 20 = 1.45   fail
30 / 20 = 1.50   pass at equality
31 / 20 = 1.55   pass
</pre>

TS-MOVE-001 with spread 0.0001:

<pre>
0.00039999 / 0.0001 = 3.9999 fail
0.00040000 / 0.0001 = 4.0000 pass
0.00040001 / 0.0001 = 4.0001 pass
</pre>

TS-SPREAD-001 with median spread 0.0001:

<pre>
0.00014999 / 0.0001 = 1.4999 pass
0.00015000 / 0.0001 = 1.5000 pass
0.00015001 / 0.0001 = 1.5001 fail
</pre>

TS-GATE-001 applies the same <code>value &gt;= minimum</code> rule to percentile,
Z, efficiency, intensity, and Move/Spread, and
<code>value &lt;= maximum</code> to spread ratio. At all equalities the six-bit
mask is binary 111111 = decimal 63.

### Baseline count

The minimum is exactly 300 valid retained samples. Therefore:

- TS-BASE-001: 299 ≥ 300 is false; detector gates do not run.
- TS-BASE-002: 300 ≥ 300 is true; detector gates may run.

## 3. State calculations

### Long path

TS-STATE-LONG-001 freezes high 1.0012 against start 0.9990:

<pre>
burst_range = 1.0012 - 0.9990 = 0.0022
pullback Mid = 1.00076
retracement = (1.0012 - 1.00076) / 0.0022
            = 0.00044 / 0.0022 = 0.20 = 20 percent
</pre>

Mids 1.00121 and 1.00122 are consecutive increasing updates beyond the frozen
high, so the second produces REACCELERATION.

### Short path

TS-STATE-SHORT-001 freezes low 0.9998 against start 1.0030:

<pre>
burst_range = 1.0030 - 0.9998 = 0.0032
pullback Mid = 1.00044
retracement = (1.00044 - 0.9998) / 0.0032
            = 0.00064 / 0.0032 = 0.20 = 20 percent
</pre>

Mids 0.99979 and 0.99978 are consecutive decreasing updates below the frozen
low, giving the symmetric result.

### Boundaries

- Burst quiet: 1399−1100=299 does not freeze; 1400−1100=300 freezes.
- Burst max: 3999−1000=2999 does not freeze; 4000−1000=3000 freezes.
- Pullback: 14.999% is shallow; 15% and 35% are valid; 35.001% is diagnostic
  too-deep; 50% invalidates.
- Timeout: 10999−1000=9999 does not expire; 11000−1000=10000 expires.

## 4. Entry, spread stress, risk, SL, TP, RR

### Common stressed quote

TS-EXEC-LONG-001 and TS-EXEC-SHORT-001:

<pre>
base Bid = 1.1000
base Ask = 1.1002
Mid = (1.1000 + 1.1002) / 2 = 1.1001
base spread = 0.0002
stressed spread = 0.0002 * 1.25 = 0.00025
stressed Bid = 1.1001 - 0.000125 = 1.099975
stressed Ask = 1.1001 + 0.000125 = 1.100225
</pre>

The risk base remains the unstressed 0.0002.

### Long entry, slippage, risk, SL, TP

<pre>
entry slippage = 1 * 0.0001 = 0.0001
raw Long entry = 1.100225 + 0.0001 = 1.100325
Long entry = ceil_tick(1.100325) = 1.1004

requested risk = ceil_tick(5 * 0.0002) = 0.0010
raw SL = 1.1004 - 0.0010 = 1.0994
Long SL = floor_tick(1.0994) = 1.0994

raw TP = 1.1004 + 1.2 * 0.0010 = 1.1016
Long TP = ceil_tick(1.1016) = 1.1016
realized RR = (1.1016 - 1.1004) / 0.0010 = 1.2
</pre>

### Short entry, slippage, risk, SL, TP

<pre>
raw Short entry = 1.099975 - 0.0001 = 1.099875
Short entry = floor_tick(1.099875) = 1.0998

requested risk = 0.0010
raw SL = 1.0998 + 0.0010 = 1.1008
Short SL = ceil_tick(1.1008) = 1.1008

raw TP = 1.0998 - 1.2 * 0.0010 = 1.0986
Short TP = floor_tick(1.0986) = 1.0986
realized RR = (1.0998 - 1.0986) / 0.0010 = 1.2
</pre>

### Outward RR with fractional target tick

TS-RR-001 uses entry 1.1000, risk 0.0003, tick 0.0001:

<pre>
Long raw TP = 1.1000 + 1.2 * 0.0003 = 1.10036
Long TP = ceil_tick(1.10036) = 1.1004
Long RR = 0.0004 / 0.0003 = 1.333333333333

Short raw TP = 1.1000 - 1.2 * 0.0003 = 1.09964
Short TP = floor_tick(1.09964) = 1.0996
Short RR = 0.0004 / 0.0003 = 1.333333333333
</pre>

Both are greater than or equal to 1.2. Nearest rounding would be an invalid
oracle.

## 5. Commission and exit outcomes

### Commission R

TS-COMM-001 supplies an independently fixed one-lot structural SL loss of 100
account-currency units and round-turn commission 7:

<pre>
commission_R = abs(7 / 100) = 0.07
net_R = gross_R - commission_R = 1.20 - 0.07 = 1.13
</pre>

### TP limit

TS-TP-001 has Long entry 1.1000, SL 1.0990, TP 1.1012, and Bid 1.1015:

<pre>
risk = 1.1000 - 1.0990 = 0.0010
TP is crossed, but limit fill = 1.1012
gross_R = (1.1012 - 1.1000) / 0.0010 = 1.2
</pre>

### Long SL gap and exit slippage

TS-SL-001 tradable Bid is 1.0987 and adverse slippage is 0.0001:

<pre>
fill = 1.0987 - 0.0001 = 1.0986
stop_gap = 1.0990 - 1.0986 = 0.0004
gross_R = (1.0986 - 1.1000) / 0.0010 = -1.4
</pre>

### Short SL gap and exit slippage

TS-SL-002 tradable Ask is 1.1013:

<pre>
fill = 1.1013 + 0.0001 = 1.1014
stop_gap = 1.1014 - 1.1010 = 0.0004
gross_R = (1.1000 - 1.1014) / 0.0010 = -1.4
</pre>

### Time exit

TS-TIMEEXIT-001:

<pre>
deadline = 1000 + 120 * 1000 = 121000
120999 is not expired
121000 is expired
Long fill = current Bid = 1.1004
gross_R = (1.1004 - 1.1000) / 0.0010 = 0.4
</pre>

## 6. Broker distance

Stops distance is 0.0005.

Long exact case:

<pre>
current Bid - SL = 1.1000 - 1.0995 = 0.0005 pass
TP - current Bid = 1.1005 - 1.1000 = 0.0005 pass
</pre>

Long fail:

<pre>
1.1000 - 1.09951 = 0.00049 < 0.0005
reason = INVALID_BROKER_STOP
</pre>

Short exact case:

<pre>
SL - current Ask = 1.1007 - 1.1002 = 0.0005 pass
current Ask - TP = 1.1002 - 1.0997 = 0.0005 pass
</pre>

Short fail:

<pre>
1.10069 - 1.1002 = 0.00049 < 0.0005
reason = INVALID_BROKER_STOP
</pre>

Entry price is intentionally absent from these distance equations. FreezeLevel
does not replace StopsLevel in the initial feasibility result.

## 7. Policy mask

Bit 1 means <code>stressed_spread/risk &lt;= 0.20</code>. Bit 2 means
<code>risk/known_range &lt;= 0.45</code>.

| Cost condition | Range condition | Decimal mask |
|---|---|---:|
| pass at 0.20 | pass at 0.45 | 3 |
| pass | fail at 0.46 | 1 |
| fail at 0.201 | pass | 2 |
| fail | fail | 0 |

The mask is recorded. None of these four values changes a broker-feasible
barrier result into invalid.

## 8. Same-ms order and market cluster

For TS-SAMEMSC-001, the three EURUSD quotes at 1000 share one group. Sequence 3
is final, so the one grid point is Bid 1.1002, Ask 1.1004, Mid 1.1003.

For simultaneous currencies, the independent sort key is:

<pre>
(time_msc, configured_symbol_index, input_sequence)
</pre>

It does not use lexical symbol order or processing time.

For TS-CLUSTER-001, the first event is 10000 and window is 2000:

<pre>
11999 - 10000 = 1999  same cluster 1
12000 - 10000 = 2000  same cluster 1
12001 - 10000 = 2001  new cluster 2
</pre>

The anchor remains 10000; chained events do not extend it. Different detectors
can create multiple event rows but share the same market cluster.

## 9. Order aggregation

### Multiple deals

TS-ORDER-002:

<pre>
filled = 0.04 + 0.06 = 0.10
weighted value = 0.04*1.1000 + 0.06*1.1002
               = 0.044000 + 0.066012 = 0.110012
average = 0.110012 / 0.10 = 1.10012
</pre>

### Partial fills

TS-PARTIAL-001:

<pre>
after deal 1: remaining = 0.10 - 0.04 = 0.06
after deal 2: remaining = 0.10 - 0.07 = 0.03
after deal 3: remaining = 0.10 - 0.10 = 0

weighted value =
  0.04*1.1000 + 0.03*1.1002 + 0.03*1.1003
  = 0.044000 + 0.033006 + 0.033009
  = 0.110015
average = 0.110015 / 0.10 = 1.10015
</pre>

No exit/close state is permitted after deal 1 or deal 2.

### Residual cancel

TS-ORDER-003 requested 0.10, filled 0.06, then terminal cancel 0.04:

<pre>
filled_volume = 0.06
cancelled_volume = 0.04
active remaining_volume = 0
entry resolution = true
</pre>

The filled position continues to WAIT_EXIT; cancellation does not erase the
0.06 lots.

### Observation truth

Server SL/TP requires the matching <code>DEAL_REASON_SL</code> or
<code>DEAL_REASON_TP</code>. A crossed fixture price without a recorded server
deal is not PASS. Likewise, TS-RESTART-001 has no injected process boundary:
result is SKIP/NOT_OBSERVED and pass count is unchanged.

## 10. CSV and provenance

TS-CSV-002 synthetic outcomes:

<pre>
valid = TP + SL + TIME = 3
invalid = NO_SIGNAL = 1
sum_R = 1.2 - 1.4 + 0.4 = 0.2
</pre>

TS-PROV-001 compares literal SHA strings. Because current source SHA and
baseline source SHA differ, equality is false and formal-edge eligibility is
false regardless of baseline profitability.

## Review result

All numeric expected values can be reproduced from this document and the
fixture literals without executing production code. Boundary comparisons are
explicit, price side is explicit, and absence is distinct from numeric zero.
