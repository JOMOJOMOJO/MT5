from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime
from html import unescape
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[3]
REPORT_ROOT = REPO_ROOT / "reports" / "backtest"
IMPORTED_ROOT = REPORT_ROOT / "imported"
RUNS_ROOT = REPORT_ROOT / "runs"
COMPARISONS_ROOT = REPORT_ROOT / "comparisons"
KNOWLEDGE_BACKTEST_ROOT = REPO_ROOT / "knowledge" / "backtests"
CATALOG_PATH = REPORT_ROOT / "catalog.jsonl"

KNOWN_ENCODINGS = (
    "utf-8-sig",
    "utf-16",
    "utf-16-le",
    "utf-16-be",
    "cp932",
    "shift_jis",
    "cp1252",
    "latin-1",
)

HTML_ROW_RE = re.compile(r"<tr\b[^>]*>(.*?)</tr>", re.IGNORECASE | re.DOTALL)
HTML_CELL_RE = re.compile(r"<t[dh]\b[^>]*>(.*?)</t[dh]>", re.IGNORECASE | re.DOTALL)
HTML_TAG_RE = re.compile(r"<[^>]+>")

METRIC_ALIASES = {
    "ea_name": ("expert", "expert advisor"),
    "symbol": ("symbol",),
    "period": ("period",),
    "model": ("model",),
    "history_quality_percent": ("history quality",),
    "bars": ("bars", "bars in test"),
    "ticks": ("ticks", "ticks modelled"),
    "symbols_count": ("symbols",),
    "initial_deposit": ("initial deposit",),
    "total_net_profit": ("total net profit", "net profit"),
    "gross_profit": ("gross profit",),
    "gross_loss": ("gross loss",),
    "profit_factor": ("profit factor",),
    "expected_payoff": ("expected payoff",),
    "recovery_factor": ("recovery factor",),
    "sharpe_ratio": ("sharpe ratio",),
    "absolute_drawdown": ("absolute drawdown",),
    "maximal_drawdown": ("maximal drawdown",),
    "relative_drawdown": ("relative drawdown",),
    "total_trades": ("total trades",),
    "short_positions": ("short trades won percent", "short positions won percent"),
    "long_positions": ("long trades won percent", "long positions won percent"),
    "profit_trades": ("profit trades percent of total",),
    "loss_trades": ("loss trades percent of total",),
    "largest_profit_trade": ("largest profit trade",),
    "largest_loss_trade": ("largest loss trade",),
    "average_profit_trade": ("average profit trade",),
    "average_loss_trade": ("average loss trade",),
}

LOCALIZED_LABEL_ALIASES = {
    "エキスパート": "expert",
    "銘柄": "symbol",
    "期間": "period",
    "ヒストリー品質": "history quality",
    "バー": "bars",
    "ティック": "ticks",
    "初期証拠金": "initial deposit",
    "総損益": "total net profit",
    "総利益": "gross profit",
    "総損失": "gross loss",
    "プロフィットファクター": "profit factor",
    "期待利得": "expected payoff",
    "リカバリファクター": "recovery factor",
    "シャープレシオ": "sharpe ratio",
    "残高絶対ドローダウン": "absolute drawdown",
    "残高最大ドローダウン": "maximal drawdown",
    "残高相対ドローダウン": "relative drawdown",
    "取引数": "total trades",
    "ショート (勝率 %)": "short trades won percent",
    "ロング (勝率 %)": "long positions won percent",
    "勝ちトレード (勝率 %)": "profit trades percent of total",
    "負けトレード (負率 %)": "loss trades percent of total",
    "最大 勝ちトレード": "largest profit trade",
    "最大 負けトレード": "largest loss trade",
    "平均 勝ちトレード": "average profit trade",
    "平均 負けトレード": "average loss trade",
}

HIGHER_IS_BETTER = {
    "total_net_profit",
    "profit_factor",
    "expected_payoff",
    "recovery_factor",
    "sharpe_ratio",
    "win_rate_percent",
}

LOWER_IS_BETTER = {
    "maximal_drawdown_percent",
    "relative_drawdown_percent",
}

COMPARE_METRICS = (
    "total_net_profit",
    "profit_factor",
    "expected_payoff",
    "maximal_drawdown_percent",
    "relative_drawdown_percent",
    "total_trades",
    "win_rate_percent",
    "recovery_factor",
    "sharpe_ratio",
)

TIMEFRAME_LABELS = {
    "1": "M1",
    "5": "M5",
    "15": "M15",
    "30": "M30",
    "60": "H1",
    "240": "H4",
    "1440": "D1",
    "10080": "W1",
    "43200": "MN1",
    "16385": "H1",
    "16388": "H4",
    "16408": "D1",
    "32769": "W1",
    "49153": "MN1",
}


@dataclass
class ImportedRun:
    payload: dict[str, Any]
    run_path: Path
    knowledge_path: Path
    imported_copy_path: Path | None


def normalize_ws(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("\xa0", " ")).strip()


def normalize_label(text: str) -> str:
    cleaned = normalize_ws(unescape(text))
    cleaned = re.sub(r"[：:]+$", "", cleaned).strip()
    localized = LOCALIZED_LABEL_ALIASES.get(cleaned)
    if localized:
        cleaned = localized
    cleaned = cleaned.lower().replace("%", " percent ")
    cleaned = re.sub(r"[()/:]+", " ", cleaned)
    cleaned = re.sub(r"[^a-z0-9]+", " ", cleaned)
    return re.sub(r"\s+", " ", cleaned).strip()


def slugify(text: str) -> str:
    lowered = text.strip().lower()
    slug = re.sub(r"[^a-z0-9]+", "-", lowered).strip("-")
    return slug or "unknown"


def repo_relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO_ROOT).as_posix()
    except ValueError:
        return str(path.resolve())


def ensure_dirs() -> None:
    for path in (IMPORTED_ROOT, RUNS_ROOT, COMPARISONS_ROOT, KNOWLEDGE_BACKTEST_ROOT):
        path.mkdir(parents=True, exist_ok=True)


def read_text_file(path: Path) -> str:
    for encoding in KNOWN_ENCODINGS:
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
    return path.read_text(encoding="utf-8", errors="ignore")


def parse_number(text: str) -> float | None:
    match = re.search(r"[-+]?\d[\d\s,\.]*", text)
    if not match:
        return None
    token = match.group(0).replace(" ", "")
    if "," in token and "." in token:
        if token.rfind(",") > token.rfind("."):
            token = token.replace(".", "").replace(",", ".")
        else:
            token = token.replace(",", "")
    elif token.count(",") == 1 and "." not in token:
        head, tail = token.split(",", 1)
        if 1 <= len(tail) <= 3:
            token = f"{head}.{tail}"
        else:
            token = token.replace(",", "")
    else:
        token = token.replace(",", "")
    try:
        return float(token)
    except ValueError:
        return None


def parse_int(text: str) -> int | None:
    value = parse_number(text)
    return None if value is None else int(round(value))


def parse_value_percent(text: str) -> tuple[float | None, float | None]:
    amount_first = re.search(r"([-+]?\d[\d\s,\.]*)\s*\(([-+]?\d[\d\s,\.]*)\s*%\)", text)
    if amount_first:
        return parse_number(amount_first.group(1)), parse_number(amount_first.group(2))

    percent_first = re.search(r"([-+]?\d[\d\s,\.]*)\s*%\s*\(([-+]?\d[\d\s,\.]*)\)", text)
    if percent_first:
        return parse_number(percent_first.group(2)), parse_number(percent_first.group(1))

    return parse_number(text), None


def parse_count_percent(text: str) -> tuple[int | None, float | None]:
    value, percent = parse_value_percent(text)
    return (None if value is None else int(round(value))), percent


def parse_period(value: str) -> tuple[str | None, str | None]:
    cleaned = normalize_ws(value)
    if not cleaned:
        return None, None
    match = re.match(r"([A-Za-z0-9_]+)\s*\((.+)\)", cleaned)
    if match:
        return match.group(1), match.group(2)
    token = cleaned.split(" ", 1)[0]
    return token, None


def parse_bool_token(value: Any) -> bool | None:
    if isinstance(value, bool):
        return value
    if value is None:
        return None
    lowered = str(value).strip().lower()
    if lowered in {"true", "1", "yes", "on"}:
        return True
    if lowered in {"false", "0", "no", "off"}:
        return False
    return None


def timeframe_label(value: Any) -> str | None:
    if value is None:
        return None
    token = str(value).strip()
    if not token:
        return None
    if token in TIMEFRAME_LABELS:
        return TIMEFRAME_LABELS[token]
    upper = token.upper()
    if upper.startswith("PERIOD_"):
        return upper.replace("PERIOD_", "")
    return upper


def derive_direction_mode(allow_buy: bool | None, allow_sell: bool | None) -> str | None:
    if allow_buy is True and allow_sell is True:
        return "long-short"
    if allow_buy is True and allow_sell is False:
        return "long-only"
    if allow_buy is False and allow_sell is True:
        return "short-only"
    if allow_buy is False and allow_sell is False:
        return "disabled"
    return None


def load_report_context(report_path: Path) -> dict[str, Any]:
    candidates = (
        report_path.with_name(report_path.name + ".meta.json"),
        report_path.with_name(report_path.stem + ".meta.json"),
    )
    for candidate in candidates:
        if not candidate.exists():
            continue
        try:
            return json.loads(candidate.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError):
            continue
    return {}


def extract_strategy_context(report_path: Path) -> dict[str, Any]:
    context = load_report_context(report_path)
    tester = context.get("tester", {}) if isinstance(context, dict) else {}
    preset = context.get("preset", {}) if isinstance(context, dict) else {}
    params = preset.get("parameters", {}) if isinstance(preset, dict) else {}
    params = params if isinstance(params, dict) else {}

    allow_buy = parse_bool_token(params.get("InpAllowBuy"))
    allow_sell = parse_bool_token(params.get("InpAllowSell"))
    use_confirm = parse_bool_token(params.get("InpUseConfirmRegime"))

    strategy = {
        "tester_symbol": tester.get("symbol"),
        "tester_period": tester.get("period"),
        "preset_name": preset.get("name"),
        "preset_source": preset.get("source"),
        "signal_timeframe": timeframe_label(params.get("InpSignalTimeframe")),
        "regime_timeframe": timeframe_label(params.get("InpRegimeTimeframe")),
        "confirm_timeframe": timeframe_label(params.get("InpConfirmRegimeTimeframe")) if use_confirm is not False else None,
        "direction_mode": derive_direction_mode(allow_buy, allow_sell),
        "allow_buy": allow_buy,
        "allow_sell": allow_sell,
        "buy_logic_mask": parse_int(str(params.get("InpBuyLogicMask"))) if params.get("InpBuyLogicMask") is not None else None,
        "sell_logic_mask": parse_int(str(params.get("InpSellLogicMask"))) if params.get("InpSellLogicMask") is not None else None,
    }
    return {key: value for key, value in strategy.items() if value not in (None, "", [])}


def strip_html(fragment: str) -> str:
    return normalize_ws(unescape(HTML_TAG_RE.sub(" ", fragment)))


def add_field(fields: dict[str, list[str]], label: str, value: str) -> None:
    normalized_label = normalize_label(label)
    normalized_value = normalize_ws(value)
    if not normalized_label or not normalized_value:
        return
    fields.setdefault(normalized_label, []).append(normalized_value)


def extract_fields_from_rows(rows: list[list[str]]) -> dict[str, list[str]]:
    fields: dict[str, list[str]] = {}
    for row in rows:
        if len(row) < 2:
            continue
        start_index = 0 if len(row) % 2 == 0 else 1
        for index in range(start_index, len(row) - 1, 2):
            add_field(fields, row[index], row[index + 1])
    return fields


def parse_html_fields(path: Path) -> tuple[dict[str, list[str]], list[dict[str, str]], str]:
    text = read_text_file(path)
    rows: list[list[str]] = []
    for row_html in HTML_ROW_RE.findall(text):
        cells = [strip_html(cell) for cell in HTML_CELL_RE.findall(row_html)]
        cells = [cell for cell in cells if cell]
        if cells:
            rows.append(cells)
    fields = extract_fields_from_rows(rows)
    title_match = re.search(r"<title\b[^>]*>(.*?)</title>", text, re.IGNORECASE | re.DOTALL)
    title = strip_html(title_match.group(1)) if title_match else path.stem
    return fields, [], title


def parse_xml_fields(path: Path) -> tuple[dict[str, list[str]], list[dict[str, str]], str]:
    tree = ET.parse(path)
    root = tree.getroot()
    fields: dict[str, list[str]] = {}
    records: list[dict[str, str]] = []
    normalized_aliases = {normalize_label(alias) for aliases in METRIC_ALIASES.values() for alias in aliases}

    for element in root.iter():
        children = list(element)
        if not children:
            continue
        if all(not list(child) for child in children):
            record = {
                normalize_label(child.tag): normalize_ws(child.text or "")
                for child in children
                if normalize_ws(child.text or "")
            }
            if not record:
                continue
            records.append(record)
            if len(record) == 2 and {"label", "value"} <= set(record):
                add_field(fields, record["label"], record["value"])
                continue
            if len(record) == 2 and {"name", "value"} <= set(record):
                add_field(fields, record["name"], record["value"])
                continue
            for key, value in record.items():
                if key in normalized_aliases:
                    fields.setdefault(key, []).append(value)

    title = normalize_ws(root.tag) or path.stem
    return fields, records, title


def parse_csv_fields(path: Path) -> tuple[dict[str, list[str]], list[dict[str, str]], str]:
    text = read_text_file(path)
    rows = list(csv.reader(text.splitlines()))
    cleaned_rows = [[normalize_ws(cell) for cell in row if normalize_ws(cell)] for row in rows]
    fields = extract_fields_from_rows(cleaned_rows)
    records: list[dict[str, str]] = []
    if rows:
        header = [normalize_label(cell) for cell in rows[0]]
        if len(header) > 1 and all(header):
            for row in rows[1:]:
                cleaned = [normalize_ws(cell) for cell in row]
                if len(cleaned) != len(header):
                    continue
                record = {header[index]: cleaned[index] for index in range(len(header)) if cleaned[index]}
                if record:
                    records.append(record)
    return fields, records, path.stem


def parse_report(path: Path) -> tuple[dict[str, list[str]], list[dict[str, str]], str, str]:
    suffix = path.suffix.lower()
    if suffix in {".htm", ".html"}:
        fields, records, title = parse_html_fields(path)
        return fields, records, title, "single_test_report"
    if suffix == ".xml":
        fields, records, title = parse_xml_fields(path)
        return fields, records, title, "optimization_export"
    if suffix == ".csv":
        fields, records, title = parse_csv_fields(path)
        return fields, records, title, "csv_export"
    raise ValueError(f"Unsupported report type: {path.suffix}")


def first_field(fields: dict[str, list[str]], aliases: tuple[str, ...]) -> str | None:
    for alias in aliases:
        values = fields.get(normalize_label(alias))
        if values:
            return values[0]
    return None


def build_metrics(fields: dict[str, list[str]], records: list[dict[str, str]]) -> dict[str, Any]:
    metrics: dict[str, Any] = {}

    for key, aliases in METRIC_ALIASES.items():
        value = first_field(fields, aliases)
        if value is None:
            continue
        if key in {"ea_name", "symbol", "period", "model"}:
            metrics[key] = value
        elif key in {"bars", "ticks", "symbols_count", "total_trades"}:
            metrics[key] = parse_int(value)
        elif key == "history_quality_percent":
            metrics[key] = parse_number(value)
        elif key in {"short_positions", "long_positions", "profit_trades", "loss_trades"}:
            count, percent = parse_count_percent(value)
            metrics[f"{key}_count"] = count
            metrics[f"{key}_percent"] = percent
        elif key in {"maximal_drawdown", "relative_drawdown"}:
            amount, percent = parse_value_percent(value)
            metrics[f"{key}_amount"] = amount
            metrics[f"{key}_percent"] = percent
        else:
            metrics[key] = parse_number(value)

    if "period" in metrics:
        timeframe, tested_range = parse_period(str(metrics["period"]))
        metrics["timeframe"] = timeframe
        if tested_range:
            metrics["tested_range"] = tested_range

    if metrics.get("profit_trades_percent") is not None:
        metrics["win_rate_percent"] = metrics["profit_trades_percent"]

    if records:
        metrics["records_count"] = len(records)

    return {key: value for key, value in metrics.items() if value not in (None, "", [])}


def build_summary(metrics: dict[str, Any], report_kind: str) -> dict[str, Any]:
    strengths: list[str] = []
    weak_points: list[str] = []
    notes: list[str] = []

    trades = metrics.get("total_trades")
    if isinstance(trades, int):
        if trades < 30:
            weak_points.append("取引回数が少なすぎて判断が不安定です。")
        elif trades < 100:
            weak_points.append("取引回数がまだ少なく、過信しにくい結果です。")
        else:
            strengths.append("取引回数は最低限の評価に耐える水準です。")

    profit_factor = metrics.get("profit_factor")
    if isinstance(profit_factor, (int, float)):
        if profit_factor < 1.0:
            weak_points.append("Profit Factor が 1.0 未満で、収益性はまだ不足しています。")
        elif profit_factor < 1.2:
            weak_points.append("Profit Factor が低く、コスト込みで崩れやすいです。")
        elif profit_factor >= 1.5:
            strengths.append("Profit Factor は十分に高い水準です。")

    net_profit = metrics.get("total_net_profit")
    if isinstance(net_profit, (int, float)):
        if net_profit <= 0:
            weak_points.append("総損益がプラスではありません。")
        else:
            strengths.append("総損益はプラスです。")

    drawdowns = [
        value
        for value in (
            metrics.get("maximal_drawdown_percent"),
            metrics.get("relative_drawdown_percent"),
        )
        if isinstance(value, (int, float))
    ]
    if drawdowns:
        worst_drawdown = max(drawdowns)
        if worst_drawdown >= 30:
            weak_points.append("ドローダウンが大きく、実運用には危険です。")
        elif worst_drawdown >= 20:
            weak_points.append("ドローダウンがやや大きく、リスク改善が必要です。")
        else:
            strengths.append("ドローダウンは比較的抑えられています。")

    long_rate = metrics.get("long_positions_percent")
    short_rate = metrics.get("short_positions_percent")
    if isinstance(long_rate, (int, float)) and isinstance(short_rate, (int, float)):
        if abs(long_rate - short_rate) >= 20:
            weak_points.append("買いと売りの勝率差が大きく、片側に偏っています。")

    if report_kind == "optimization_export" and metrics.get("records_count"):
        notes.append("最適化レポートなので、上位結果だけでなく近傍パラメータの安定性も確認してください。")

    if not strengths and not weak_points:
        notes.append("主要指標を十分に読めなかったため、元レポートの確認が必要です。")

    headline = " / ".join(weak_points[:2] or strengths[:2] or ["要確認"])
    return {
        "headline": headline,
        "strengths": strengths,
        "weak_points": weak_points,
        "notes": notes,
    }


def build_identity(payload: dict[str, Any]) -> tuple[str, str, str]:
    identity = payload["identity"]
    ea_slug = slugify(str(identity.get("ea_name") or "unknown-ea"))
    symbol_slug = slugify(str(identity.get("symbol") or "unknown-symbol"))
    timeframe_slug = slugify(str(identity.get("timeframe") or "unknown-timeframe"))
    return ea_slug, symbol_slug, timeframe_slug


def build_run_payload(
    report_path: Path,
    fields: dict[str, list[str]],
    records: list[dict[str, str]],
    title: str,
    report_kind: str,
    ea_name_override: str | None,
    tags: list[str],
) -> dict[str, Any]:
    imported_at = datetime.now().isoformat(timespec="seconds")
    metrics = build_metrics(fields, records)
    strategy = extract_strategy_context(report_path)
    ea_name = ea_name_override or metrics.get("ea_name") or "unknown-ea"
    symbol = metrics.get("symbol")
    timeframe = strategy.get("signal_timeframe") or metrics.get("timeframe") or metrics.get("period")
    summary = build_summary(metrics, report_kind, strategy)

    return {
        "imported_at": imported_at,
        "identity": {
            "title": title,
            "ea_name": ea_name,
            "symbol": symbol,
            "timeframe": timeframe,
            "tested_range": metrics.get("tested_range"),
            "report_kind": report_kind,
        },
        "storage": {},
        "source": {
            "original_path": str(report_path.resolve()),
            "type": report_path.suffix.lower().lstrip("."),
        },
        "strategy": strategy,
        "metrics": metrics,
        "summary": summary,
        "tags": tags,
        "raw_fields": {
            key: values if len(values) > 1 else values[0]
            for key, values in fields.items()
        },
        "records_preview": records[:20],
    }


def copy_report_bundle(source_path: Path, target_dir: Path) -> Path:
    target_dir.mkdir(parents=True, exist_ok=True)
    report_copy = target_dir / f"report{source_path.suffix.lower()}"
    shutil.copy2(source_path, report_copy)

    for sibling in source_path.parent.glob(f"{source_path.stem}*"):
        if sibling.resolve() == source_path.resolve() or not sibling.is_file():
            continue
        shutil.copy2(sibling, target_dir / sibling.name)

    return report_copy


def write_backtest_note(run: dict[str, Any], run_path: Path, note_path: Path) -> Path:
    identity = run["identity"]
    strategy = run.get("strategy", {})
    metrics = run["metrics"]
    summary = run["summary"]

    lines = [
        f"# {identity.get('ea_name', 'EA')} {identity.get('symbol') or ''} {identity.get('timeframe') or ''}".strip(),
        "",
        f"- Date: {run['imported_at']}",
        f"- EA: {identity.get('ea_name', '-')}",
        f"- Symbol: {identity.get('symbol', '-') or '-'}",
        f"- Timeframe: {identity.get('timeframe', '-') or '-'}",
        f"- Tested range: {identity.get('tested_range', '-') or '-'}",
        f"- Evidence: {repo_relative(run_path)}",
        f"- Imported assets: {run['storage'].get('imported_dir', '-')}",
        f"- Tags: {', '.join(run.get('tags', [])) or '-'}",
        "",
        "## Summary",
        "",
        f"- {summary.get('headline') or '要確認'}",
        "",
        "## Key Metrics",
        "",
        f"- Total Net Profit: {metrics.get('total_net_profit', '-')}",
        f"- Profit Factor: {metrics.get('profit_factor', '-')}",
        f"- Expected Payoff: {metrics.get('expected_payoff', '-')}",
        f"- Maximal Drawdown %: {metrics.get('maximal_drawdown_percent', '-')}",
        f"- Relative Drawdown %: {metrics.get('relative_drawdown_percent', '-')}",
        f"- Total Trades: {metrics.get('total_trades', '-')}",
        "",
        "## What Worked",
        "",
    ]

    strengths = summary.get("strengths") or ["-"]
    lines.extend(f"- {item}" for item in strengths)
    lines.extend(["", "## What Failed", ""])
    weak_points = summary.get("weak_points") or ["-"]
    lines.extend(f"- {item}" for item in weak_points)
    lines.extend(["", "## Next Action", ""])

    next_actions: list[str] = []
    if weak_points:
        next_actions.append("弱点を補う仮説を `knowledge/experiments/` に切り出す。")
    if metrics.get("total_trades") is not None and metrics.get("total_trades", 0) < 100:
        next_actions.append("サンプルを増やせる期間や条件で追加検証する。")
    if not next_actions:
        next_actions.append("次の run を追加して比較可能な状態にする。")
    lines.extend(f"- {item}" for item in next_actions)
    lines.append("")

    note_path.parent.mkdir(parents=True, exist_ok=True)
    note_path.write_text("\n".join(lines), encoding="utf-8")
    return note_path


def append_catalog(run_path: Path, note_path: Path, payload: dict[str, Any]) -> None:
    metrics = payload.get("metrics", {})
    entry = {
        "run_path": repo_relative(run_path),
        "knowledge_path": repo_relative(note_path),
        "imported_at": payload.get("imported_at"),
        "identity": payload.get("identity", {}),
        "strategy": payload.get("strategy", {}),
        "summary": {"headline": payload.get("summary", {}).get("headline")},
        "metrics": {
            "total_net_profit": metrics.get("total_net_profit"),
            "profit_factor": metrics.get("profit_factor"),
            "relative_drawdown_percent": metrics.get("relative_drawdown_percent"),
            "total_trades": metrics.get("total_trades"),
        },
        "storage": payload.get("storage", {}),
    }
    with CATALOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def rebuild_catalog() -> int:
    ensure_dirs()
    run_files = sorted(iter_run_files(), key=lambda path: path.stat().st_mtime)
    CATALOG_PATH.write_text("", encoding="utf-8")
    rebuilt = 0

    for run_path in run_files:
        payload = json.loads(run_path.read_text(encoding="utf-8"))
        note_path_value = payload.get("storage", {}).get("knowledge_path")
        if not note_path_value:
            continue
        note_path = (REPO_ROOT / note_path_value).resolve()
        if not note_path.exists():
            continue
        append_catalog(run_path, note_path, payload)
        rebuilt += 1

    return rebuilt


def import_backtest_report(
    report_path: str,
    ea_name: str | None = None,
    tags: list[str] | None = None,
    copy_source: bool = True,
) -> ImportedRun:
    ensure_dirs()
    source_path = Path(report_path).expanduser().resolve()
    if not source_path.exists():
        raise FileNotFoundError(f"Report file was not found: {source_path}")

    fields, records, title, report_kind = parse_report(source_path)
    tag_list = tags or []
    payload = build_run_payload(source_path, fields, records, title, report_kind, ea_name, tag_list)

    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S-%f")
    ea_slug, symbol_slug, timeframe_slug = build_identity(payload)
    report_slug = slugify(source_path.stem)[:32] or "report"
    run_id = f"{timestamp}-{report_slug}"

    imported_copy_path: Path | None = None
    imported_dir = IMPORTED_ROOT / ea_slug / symbol_slug / timeframe_slug / run_id
    run_path = RUNS_ROOT / ea_slug / symbol_slug / timeframe_slug / f"{run_id}.json"
    note_path = KNOWLEDGE_BACKTEST_ROOT / ea_slug / symbol_slug / timeframe_slug / f"{run_id}.md"

    if copy_source:
        imported_copy_path = copy_report_bundle(source_path, imported_dir)

    payload["run_id"] = run_id
    payload["storage"] = {
        "ea_key": ea_slug,
        "symbol_key": symbol_slug,
        "timeframe_key": timeframe_slug,
        "run_path": repo_relative(run_path),
        "knowledge_path": repo_relative(note_path),
        "imported_dir": repo_relative(imported_dir) if copy_source else None,
        "imported_report": repo_relative(imported_copy_path) if imported_copy_path else None,
    }
    run_path.parent.mkdir(parents=True, exist_ok=True)
    run_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    knowledge_path = write_backtest_note(payload, run_path, note_path)
    append_catalog(run_path, knowledge_path, payload)

    return ImportedRun(
        payload=payload,
        run_path=run_path,
        knowledge_path=knowledge_path,
        imported_copy_path=imported_copy_path,
    )


def iter_run_files() -> list[Path]:
    ensure_dirs()
    return sorted(
        (
            path
            for path in RUNS_ROOT.glob("**/*.json")
            if "_legacy_flat" not in path.parts
        ),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )


def list_backtest_runs(limit: int = 10, ea_name: str | None = None) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for path in iter_run_files():
        payload = json.loads(path.read_text(encoding="utf-8"))
        identity = payload.get("identity", {})
        if ea_name and str(identity.get("ea_name", "")).lower() != ea_name.lower():
            continue
        items.append(
            {
                "path": repo_relative(path),
                "ea_name": identity.get("ea_name"),
                "symbol": identity.get("symbol"),
                "timeframe": identity.get("timeframe"),
                "signal_timeframe": payload.get("strategy", {}).get("signal_timeframe"),
                "direction_mode": payload.get("strategy", {}).get("direction_mode"),
                "headline": payload.get("summary", {}).get("headline"),
                "imported_at": payload.get("imported_at"),
            }
        )
        if len(items) >= limit:
            break
    return items


def load_run(run_path: str) -> tuple[Path, dict[str, Any]]:
    candidate = Path(run_path)
    if candidate.is_absolute():
        resolved = candidate.resolve()
        if not resolved.exists():
            raise FileNotFoundError(f"Run file was not found: {resolved}")
        return resolved, json.loads(resolved.read_text(encoding="utf-8"))

    direct = (REPO_ROOT / candidate).resolve()
    if direct.exists():
        return direct, json.loads(direct.read_text(encoding="utf-8"))

    matches = list(RUNS_ROOT.glob(f"**/{run_path}"))
    if len(matches) == 1:
        resolved = matches[0].resolve()
        return resolved, json.loads(resolved.read_text(encoding="utf-8"))
    if len(matches) > 1:
        raise FileExistsError(f"Multiple run files matched '{run_path}'. Use a repo-relative path.")
    raise FileNotFoundError(f"Run file was not found: {run_path}")


def compare_backtest_runs(baseline_path: str, candidate_path: str, save_markdown: bool = False) -> dict[str, Any]:
    ensure_dirs()
    baseline_resolved, baseline = load_run(baseline_path)
    candidate_resolved, candidate = load_run(candidate_path)
    baseline_metrics = baseline.get("metrics", {})
    candidate_metrics = candidate.get("metrics", {})

    deltas: dict[str, dict[str, Any]] = {}
    improvements: list[str] = []
    regressions: list[str] = []

    for metric in COMPARE_METRICS:
        baseline_value = baseline_metrics.get(metric)
        candidate_value = candidate_metrics.get(metric)
        if not isinstance(baseline_value, (int, float)) or not isinstance(candidate_value, (int, float)):
            continue

        delta = candidate_value - baseline_value
        deltas[metric] = {
            "baseline": baseline_value,
            "candidate": candidate_value,
            "delta": delta,
        }

        if metric in HIGHER_IS_BETTER:
            if delta > 0:
                improvements.append(f"{metric}: {baseline_value} -> {candidate_value}")
            elif delta < 0:
                regressions.append(f"{metric}: {baseline_value} -> {candidate_value}")
        elif metric in LOWER_IS_BETTER:
            if delta < 0:
                improvements.append(f"{metric}: {baseline_value} -> {candidate_value}")
            elif delta > 0:
                regressions.append(f"{metric}: {baseline_value} -> {candidate_value}")

    payload = {
        "baseline": repo_relative(baseline_resolved),
        "candidate": repo_relative(candidate_resolved),
        "improvements": improvements,
        "regressions": regressions,
        "deltas": deltas,
    }

    if save_markdown:
        timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S-%f")
        comparison_path = COMPARISONS_ROOT / f"{timestamp}-comparison.md"
        lines = [
            "# Backtest Comparison",
            "",
            f"- Baseline: {payload['baseline']}",
            f"- Candidate: {payload['candidate']}",
            "",
            "## Improvements",
            "",
        ]
        lines.extend(f"- {item}" for item in improvements or ["-"])
        lines.extend(["", "## Regressions", ""])
        lines.extend(f"- {item}" for item in regressions or ["-"])
        lines.append("")
        comparison_path.write_text("\n".join(lines), encoding="utf-8")
        payload["comparison_note"] = repo_relative(comparison_path)

    return payload


def summarize_backtest_run(run_path: str) -> dict[str, Any]:
    resolved, payload = load_run(run_path)
    return {
        "path": repo_relative(resolved),
        "imported_at": payload.get("imported_at"),
        "identity": payload.get("identity", {}),
        "strategy": payload.get("strategy", {}),
        "headline": payload.get("summary", {}).get("headline"),
        "strengths": payload.get("summary", {}).get("strengths", []),
        "weak_points": payload.get("summary", {}).get("weak_points", []),
        "metrics": payload.get("metrics", {}),
    }


def format_run_list(items: list[dict[str, Any]]) -> str:
    if not items:
        return "No backtest runs were found."
    lines = []
    for item in items:
        lines.append(
            f"{item['path']} :: {item.get('ea_name') or '-'} / {item.get('symbol') or '-'} / "
            f"{item.get('timeframe') or '-'} / {item.get('headline') or '要確認'}"
        )
    return "\n".join(lines)


def format_comparison(payload: dict[str, Any]) -> str:
    lines = [
        f"Baseline: {payload['baseline']}",
        f"Candidate: {payload['candidate']}",
        "",
        "Improvements:",
    ]
    lines.extend(f"- {item}" for item in payload.get("improvements", []) or ["-"])
    lines.extend(["", "Regressions:"])
    lines.extend(f"- {item}" for item in payload.get("regressions", []) or ["-"])
    if payload.get("comparison_note"):
        lines.extend(["", f"Saved: {payload['comparison_note']}"])
    return "\n".join(lines)


def format_summary(payload: dict[str, Any]) -> str:
    lines = [
        f"Run: {payload['path']}",
        f"Headline: {payload.get('headline') or '要確認'}",
        "",
        "Weak points:",
    ]
    lines.extend(f"- {item}" for item in payload.get("weak_points", []) or ["-"])
    lines.extend(["", "Strengths:"])
    lines.extend(f"- {item}" for item in payload.get("strengths", []) or ["-"])
    return "\n".join(lines)


def build_summary(metrics: dict[str, Any], report_kind: str, strategy: dict[str, Any] | None = None) -> dict[str, Any]:
    strengths: list[str] = []
    weak_points: list[str] = []
    notes: list[str] = []
    strategy = strategy or {}

    trades = metrics.get("total_trades")
    if isinstance(trades, int):
        if trades < 10:
            weak_points.append("取引回数が少なすぎて判断が不安定です。")
        elif trades < 25:
            notes.append("取引回数は少なめなので、別期間や別レジームで補強が必要です。")
        elif trades < 100:
            notes.append("取引回数はまだ多くないため、追加検証で安定性を確認してください。")
        else:
            strengths.append("取引回数は初期評価に耐える水準です。")

    profit_factor = metrics.get("profit_factor")
    if isinstance(profit_factor, (int, float)):
        if profit_factor < 1.0:
            weak_points.append("Profit Factor が 1.0 未満で、収益性はまだ不足しています。")
        elif profit_factor < 1.2:
            weak_points.append("Profit Factor が弱く、コスト増で崩れやすい状態です。")
        elif profit_factor >= 1.5:
            strengths.append("Profit Factor は深掘りに値する水準です。")

    net_profit = metrics.get("total_net_profit")
    if isinstance(net_profit, (int, float)):
        if net_profit <= 0:
            weak_points.append("総損益がまだプラスではありません。")
        else:
            strengths.append("総損益はプラスです。")

    drawdowns = [
        value
        for value in (
            metrics.get("maximal_drawdown_percent"),
            metrics.get("relative_drawdown_percent"),
        )
        if isinstance(value, (int, float))
    ]
    if drawdowns:
        worst_drawdown = max(drawdowns)
        if worst_drawdown >= 30:
            weak_points.append("ドローダウンが大きすぎて実運用には危険です。")
        elif worst_drawdown >= 20:
            weak_points.append("ドローダウンがやや大きく、リスク制御の見直しが必要です。")
        else:
            strengths.append("ドローダウンは比較的抑えられています。")

    long_rate = metrics.get("long_positions_percent")
    short_rate = metrics.get("short_positions_percent")
    long_count = metrics.get("long_positions_count")
    short_count = metrics.get("short_positions_count")
    direction_mode = strategy.get("direction_mode")
    if isinstance(long_rate, (int, float)) and isinstance(short_rate, (int, float)):
        both_sides_active = (
            isinstance(long_count, int)
            and isinstance(short_count, int)
            and long_count > 0
            and short_count > 0
        )
        if both_sides_active and direction_mode not in {"long-only", "short-only"} and abs(long_rate - short_rate) >= 20:
            weak_points.append("買いと売りの成績差が大きく、片側依存の可能性があります。")

    if report_kind == "optimization_export" and metrics.get("records_count"):
        notes.append("最適化レポートです。上位1件だけでなく近傍の安定性も見てください。")

    if not strengths and not weak_points:
        notes.append("レポートは取り込み済みですが、人の判断での解釈がまだ必要です。")

    headline = " / ".join(
        weak_points[:2] or strengths[:2] or ["レポート要約はまだ生成されていません。"]
    )
    return {
        "headline": headline,
        "strengths": strengths,
        "weak_points": weak_points,
        "notes": notes,
    }


def write_backtest_note(run: dict[str, Any], run_path: Path, note_path: Path) -> Path:
    identity = run["identity"]
    strategy = run.get("strategy", {})
    metrics = run["metrics"]
    summary = run["summary"]

    lines = [
        f"# {identity.get('ea_name', 'EA')} {identity.get('symbol') or ''} {identity.get('timeframe') or ''}".strip(),
        "",
        f"- 日付: {run['imported_at']}",
        f"- EA: {identity.get('ea_name', '-')}",
        f"- 通貨: {identity.get('symbol', '-') or '-'}",
        f"- 時間足: {identity.get('timeframe', '-') or '-'}",
        f"- テスター時間足: {strategy.get('tester_period') or metrics.get('timeframe', '-') or '-'}",
        f"- 検証期間: {identity.get('tested_range', '-') or '-'}",
        f"- 証跡: {repo_relative(run_path)}",
        f"- 取込資産: {run['storage'].get('imported_dir', '-')}",
        f"- タグ: {', '.join(run.get('tags', [])) or '-'}",
        "",
        "## 戦略メタデータ",
        "",
        f"- シグナル時間足: {strategy.get('signal_timeframe') or identity.get('timeframe', '-') or '-'}",
        f"- レジーム時間足: {strategy.get('regime_timeframe') or '-'}",
        f"- 確認時間足: {strategy.get('confirm_timeframe') or '-'}",
        f"- 売買方向: {strategy.get('direction_mode') or '-'}",
        f"- Buy logic mask: {strategy.get('buy_logic_mask') if strategy.get('buy_logic_mask') is not None else '-'}",
        f"- Sell logic mask: {strategy.get('sell_logic_mask') if strategy.get('sell_logic_mask') is not None else '-'}",
        f"- Preset: {strategy.get('preset_name') or '-'}",
        "",
        "## 要約",
        "",
        f"- {summary.get('headline') or 'レポート要約はまだ生成されていません。'}",
        "",
        "## 主要指標",
        "",
        f"- 総損益: {metrics.get('total_net_profit', '-')}",
        f"- Profit Factor: {metrics.get('profit_factor', '-')}",
        f"- 期待値: {metrics.get('expected_payoff', '-')}",
        f"- 最大DD %: {metrics.get('maximal_drawdown_percent', '-')}",
        f"- 相対DD %: {metrics.get('relative_drawdown_percent', '-')}",
        f"- 総取引数: {metrics.get('total_trades', '-')}",
        "",
        "## 良かった点",
        "",
    ]

    strengths = summary.get("strengths") or ["-"]
    lines.extend(f"- {item}" for item in strengths)
    lines.extend(["", "## 悪かった点", ""])
    weak_points = summary.get("weak_points") or ["-"]
    lines.extend(f"- {item}" for item in weak_points)
    lines.extend(["", "## 次のアクション", ""])

    next_actions: list[str] = []
    if weak_points:
        next_actions.append("主な弱点を 1 つ選び、knowledge/experiments/ に次の仮説として切り出す。")
    if metrics.get("total_trades") is not None and metrics.get("total_trades", 0) < 100:
        next_actions.append("サンプルが薄いので、期間または別レジームでも再検証する。")
    if not next_actions:
        next_actions.append("次の run と比較して、再現性のある改善だけ残す。")
    lines.extend(f"- {item}" for item in next_actions)
    lines.append("")

    note_path.parent.mkdir(parents=True, exist_ok=True)
    note_path.write_text("\n".join(lines), encoding="utf-8")
    return note_path


def format_run_list(items: list[dict[str, Any]]) -> str:
    if not items:
        return "バックテスト run はまだありません。"
    lines = []
    for item in items:
        timeframe = item.get("signal_timeframe") or item.get("timeframe") or "-"
        direction_mode = item.get("direction_mode") or "-"
        lines.append(
            f"{item['path']} :: {item.get('ea_name') or '-'} / {item.get('symbol') or '-'} / "
            f"{timeframe} / {direction_mode} / {item.get('headline') or 'レポート要約はまだ生成されていません。'}"
        )
    return "\n".join(lines)


def format_summary(payload: dict[str, Any]) -> str:
    identity = payload.get("identity", {})
    strategy = payload.get("strategy", {})
    metrics = payload.get("metrics", {})

    lines = [
        f"Run: {payload['path']}",
        f"Imported: {payload.get('imported_at') or '-'}",
        f"EA: {identity.get('ea_name') or '-'}",
        f"Symbol: {identity.get('symbol') or '-'}",
        f"Signal TF: {strategy.get('signal_timeframe') or identity.get('timeframe') or '-'}",
        f"Tester Period: {strategy.get('tester_period') or metrics.get('timeframe') or '-'}",
        f"Direction: {strategy.get('direction_mode') or '-'}",
        f"Regime TF: {strategy.get('regime_timeframe') or '-'}",
        f"Confirm TF: {strategy.get('confirm_timeframe') or '-'}",
        f"Headline: {payload.get('headline') or 'レポート要約はまだ生成されていません。'}",
        "",
        "Weak points:",
    ]
    lines.extend(f"- {item}" for item in payload.get("weak_points", []) or ["-"])
    lines.extend(["", "Strengths:"])
    lines.extend(f"- {item}" for item in payload.get("strengths", []) or ["-"])
    return "\n".join(lines)


def build_cli() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Import and compare MT5 backtest reports.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    import_parser = subparsers.add_parser("import", help="Import an MT5 report into runs and knowledge.")
    import_parser.add_argument("--report", required=True, help="Path to an MT5 HTML, XML, or CSV report.")
    import_parser.add_argument("--ea-name", help="Override EA name.")
    import_parser.add_argument("--tag", action="append", default=[], help="Tag to attach to the imported run.")
    import_parser.add_argument("--no-copy", action="store_true", help="Do not copy the source report bundle.")

    list_parser = subparsers.add_parser("list", help="List imported backtest runs.")
    list_parser.add_argument("--limit", type=int, default=10)
    list_parser.add_argument("--ea-name")

    summary_parser = subparsers.add_parser("summarize", help="Summarize one imported run.")
    summary_parser.add_argument("--run", required=True)

    compare_parser = subparsers.add_parser("compare", help="Compare two imported runs.")
    compare_parser.add_argument("--baseline", required=True)
    compare_parser.add_argument("--candidate", required=True)
    compare_parser.add_argument("--save", action="store_true")

    subparsers.add_parser("rebuild-catalog", help="Rebuild catalog.jsonl from saved run JSON files.")

    return parser


def main() -> int:
    parser = build_cli()
    args = parser.parse_args()

    if args.command == "import":
        imported = import_backtest_report(
            report_path=args.report,
            ea_name=args.ea_name,
            tags=args.tag,
            copy_source=not args.no_copy,
        )
        print(f"Run JSON: {repo_relative(imported.run_path)}")
        print(f"Knowledge note: {repo_relative(imported.knowledge_path)}")
        if imported.imported_copy_path is not None:
            print(f"Imported copy: {repo_relative(imported.imported_copy_path)}")
        print(f"Headline: {imported.payload['summary']['headline']}")
        return 0

    if args.command == "list":
        print(format_run_list(list_backtest_runs(limit=args.limit, ea_name=args.ea_name)))
        return 0

    if args.command == "summarize":
        print(format_summary(summarize_backtest_run(args.run)))
        return 0

    if args.command == "compare":
        print(format_comparison(compare_backtest_runs(args.baseline, args.candidate, save_markdown=args.save)))
        return 0

    if args.command == "rebuild-catalog":
        rebuilt = rebuild_catalog()
        print(f"Rebuilt catalog entries: {rebuilt}")
        return 0

    parser.error("Unknown command")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
