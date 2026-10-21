"""9/26/52 cloud at its displayed time: spans shifted +26 bars."""
def detect(df):
    long = (df.close > df.cloud_upper) & (df.close.shift() <= df.cloud_upper.shift())
    short = (df.close < df.cloud_lower) & (df.close.shift() >= df.cloud_lower.shift())
    return {'LONG': long, 'SHORT': short}
