from .donchian import detect as breakout


def detect(df):
    return {side: mask & df.contracted_previous for side, mask in breakout(df).items()}
