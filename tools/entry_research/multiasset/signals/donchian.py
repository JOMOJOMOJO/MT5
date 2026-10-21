def detect(df):
    return {'LONG': (df.close > df.dc_high) & (df.close.shift() <= df.dc_high.shift()),
            'SHORT': (df.close < df.dc_low) & (df.close.shift() >= df.dc_low.shift())}
