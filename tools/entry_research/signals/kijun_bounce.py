"""Touch the PREVIOUS confirmed Kijun; close back on the trend side."""
def detect(df):
    line = df.kijun.shift()
    long = (df.close.shift() > line) & (df.low <= line) & (df.close > line) & (df.close > df.open)
    short = (df.close.shift() < line) & (df.high >= line) & (df.close < line) & (df.close < df.open)
    return {'LONG': long, 'SHORT': short}
