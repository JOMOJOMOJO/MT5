from __future__ import annotations

import argparse
import json
import time
from datetime import datetime
from pathlib import Path
from typing import Any

import MetaTrader5 as mt5


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_OUTPUT_ROOT = REPO_ROOT / "reports" / "research"
ORIGIN_PATH = REPO_ROOT.parents[2] / "origin.txt"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Probe MT5 market book availability for a symbol.")
    parser.add_argument("--symbol", default="BTCUSD")
    parser.add_argument("--samples", type=int, default=10)
    parser.add_argument("--sleep-ms", type=int, default=500)
    parser.add_argument("--levels", type=int, default=10)
    parser.add_argument("--output-dir")
    parser.add_argument("--terminal-path")
    return parser.parse_args()


def load_terminal_path(explicit: str | None) -> str:
    if explicit:
        return explicit
    origin = ORIGIN_PATH.read_text(encoding="utf-16").strip()
    return str(Path(origin) / "terminal64.exe")


def slugify(value: str) -> str:
    return "".join(ch.lower() if ch.isalnum() else "-" for ch in value).strip("-")


def default_output_dir(symbol: str) -> Path:
    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    return DEFAULT_OUTPUT_ROOT / f"{timestamp}-{slugify(symbol)}-market-book-probe"


def level_to_dict(level: Any) -> dict[str, Any]:
    return {
        "type": int(level.type),
        "price": float(level.price),
        "volume": int(level.volume),
        "volume_dbl": float(getattr(level, "volume_dbl", 0.0) or 0.0),
    }


def compute_imbalance(book: list[Any]) -> dict[str, float] | None:
    if not book:
        return None
    bid_volume = 0.0
    ask_volume = 0.0
    for level in book:
        volume = float(getattr(level, "volume_dbl", 0.0) or getattr(level, "volume", 0.0) or 0.0)
        if int(level.type) == 1:
            bid_volume += volume
        elif int(level.type) == 2:
            ask_volume += volume
    total = bid_volume + ask_volume
    if total <= 0.0:
        return None
    return {
        "bid_volume": bid_volume,
        "ask_volume": ask_volume,
        "imbalance": (bid_volume - ask_volume) / total,
    }


def main() -> int:
    args = parse_args()
    terminal_path = load_terminal_path(args.terminal_path)
    output_dir = Path(args.output_dir) if args.output_dir else default_output_dir(args.symbol)
    output_dir.mkdir(parents=True, exist_ok=True)

    if not mt5.initialize(path=terminal_path):
        raise RuntimeError(f"MT5 initialize failed: {mt5.last_error()}")

    try:
        if not mt5.symbol_select(args.symbol, True):
            raise RuntimeError(f"Failed to select symbol {args.symbol}: {mt5.last_error()}")

        subscribed = mt5.market_book_add(args.symbol)
        samples: list[dict[str, Any]] = []
        for index in range(args.samples):
            book = mt5.market_book_get(args.symbol)
            tick = mt5.symbol_info_tick(args.symbol)
            levels = [] if book is None else [level_to_dict(level) for level in book[: args.levels]]
            imbalance = None if book is None else compute_imbalance(book)
            samples.append(
                {
                    "index": index,
                    "timestamp": datetime.now().isoformat(timespec="seconds"),
                    "book_len": 0 if book is None else len(book),
                    "imbalance": imbalance,
                    "levels": levels,
                    "tick": None
                    if tick is None
                    else {
                        "bid": float(tick.bid),
                        "ask": float(tick.ask),
                        "last": float(tick.last),
                        "volume": int(tick.volume),
                        "time": int(tick.time),
                    },
                    "last_error": list(mt5.last_error()),
                }
            )
            time.sleep(max(0, args.sleep_ms) / 1000.0)

        populated = [sample for sample in samples if sample["book_len"] > 0]
        status = "available" if populated else "empty"
        avg_imbalance = None
        if populated:
            values = [sample["imbalance"]["imbalance"] for sample in populated if sample["imbalance"]]
            if values:
                avg_imbalance = sum(values) / len(values)

        payload = {
            "generated_at": datetime.now().isoformat(timespec="seconds"),
            "symbol": args.symbol,
            "samples": samples,
            "subscription_ok": bool(subscribed),
            "status": status,
            "populated_samples": len(populated),
            "average_imbalance": avg_imbalance,
            "conclusion": (
                "DOM levels were available."
                if populated
                else "MarketBookGet returned no levels. Treat DOM-based entry filters as unavailable on this broker feed."
            ),
        }

        (output_dir / "summary.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        lines = [
            f"# Market Book Probe: {args.symbol}",
            "",
            f"- Subscription ok: `{subscribed}`",
            f"- Status: `{status}`",
            f"- Populated samples: `{len(populated)}` / `{args.samples}`",
            f"- Average imbalance: `{avg_imbalance if avg_imbalance is not None else 'n/a'}`",
            "",
            "## Conclusion",
            "",
            f"- {payload['conclusion']}",
        ]
        (output_dir / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"Output dir: {output_dir}")
        print(f"Status: {status}")
        return 0
    finally:
        try:
            mt5.market_book_release(args.symbol)
        except Exception:
            pass
        mt5.shutdown()


if __name__ == "__main__":
    raise SystemExit(main())
