# Regression status

`INVALID_FOR_STEP15C_ANALYSIS`

This third run restored 7,282 reversal signals but blocked one historical
weekend-gap fill because it compared the fill tick, rather than the causal
signal clock, with the 120-second signal window. It produced 7,280 fills instead
of the frozen 7,281. The `_r4` implementation accepts a later first available
quote only when the signal itself was armed within the existing window.
