def detect(df):
    return {'LONG': (df.close.shift() < df.bb_low.shift()) & (df.close >= df.bb_low) & (df.close <= df.bb_high),
            'SHORT': (df.close.shift() > df.bb_high.shift()) & (df.close <= df.bb_high) & (df.close >= df.bb_low)}
