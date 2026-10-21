"""EMA20/50 confirmed close crossover; no parameter sweep."""
def detect(df):
    long = (df.ema_fast > df.ema_slow) & (df.ema_fast.shift() <= df.ema_slow.shift())
    short = (df.ema_fast < df.ema_slow) & (df.ema_fast.shift() >= df.ema_slow.shift())
    return {'LONG': long, 'SHORT': short}
