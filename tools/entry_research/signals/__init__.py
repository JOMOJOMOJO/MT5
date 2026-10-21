from . import ichimoku_cloud, kijun_bounce, ema_cross
import pandas as pd

REGISTRY = {m.__name__.rsplit('.', 1)[-1]: m.detect for m in (ichimoku_cloud, kijun_bounce, ema_cross)}

def extract(features, methods):
    chunks = []
    for method in methods:
        for side, mask in REGISTRY[method](features).items():
            frame = features.loc[mask.fillna(False) & features.signal_eligible].copy()
            frame['method'], frame['side'] = method, side
            frame['candidate_id'] = [f'{method}:{side}:{t}' for t in frame.time]
            # Keep all events, annotate overlap instead of secretly deduplicating them.
            frame['same_side_consecutive'] = frame.signal_index.diff().eq(1)
            frame['overlap_50'] = frame.entry_index.diff().lt(50)
            frame['cluster_id'] = (~frame.overlap_50).cumsum()
            last = -1000000
            keep = []
            for idx in frame.entry_index:
                ok = idx >= last + 50
                keep.append(ok)
                if ok:
                    last = idx
            frame['nonoverlap_50'] = keep
            chunks.append(frame)
    return pd.concat(chunks, ignore_index=True).sort_values(['signal_time','method','side']).reset_index(drop=True)
