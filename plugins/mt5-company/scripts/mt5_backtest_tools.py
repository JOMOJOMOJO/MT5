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

KNOWN_ENCODINGS = ("utf-8-sig", "utf-16", "utf-16-le", "utf-16-be", "cp1252", "latin-1")

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


@dataclass
class ImportedRun:
    payload: dict[str, Any]
    run_path: Path
    knowledge_path: Path
    imported_copy_path: Path | None


def normalize_ws(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("\xa0", " ")).strip()


def normalize_label(text: str) -> str:
    cleaned = normalize_ws(unescape(text).lower())
    cleaned = cleaned.replace("%", " percent ")
    cleaned = re.sub(r"[()/:]+", " ", cleaned)
    cleaned = re.sub(r"[^a-z0-9]+", " ", cleaned)
    return re.sub(r"\s+", " ", cleaned).strip()


NORMALIZED_ALIAS_SET = {
    normalize_label(alias)
    for aliases in METRIC_ALIASES.values()
    for alias in aliases
}


def slugify(text: str) -> str:
    lowered = text.strip().lower()
    slug = re.sub(r"[^a-z0-9]+", "-", lowered).strip("-")
    return slug or "report"


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
    match = re.search(r"([-+]?\d[\d\s,\.]*)\s*\(([-+]?\d[\d\s,\.]*)\s*%\)", text)
    if not match:
        return parse_number(text), None
    return parse_number(match.group(1)), parse_number(match.group(2))


def parse_count_percent(text: str) -> tuple[int | None, float | None]:
    value, percent = parse_value_percent(text)
    count = None if value is None else int(round(value))
    return count, percent


def parse_period(value: str) -> tuple[str | None, str | None]:
    cleaned = normalize_ws(value)
    if not cleaned:
        return None, None
    match = re.match(r"([A-Za-z0-9_]+)\s*\((.+)\)", cleaned)
    if match:
        return match.group(1), match.group(2)
    token = cleaned.split(" ", 1)[0]
    return token, None


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
                if key in NORMALIZED_ALIAS_SET:
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
        first_record = records[0]
        if len(records) > 1:
            if "profit" in first_record:
                metrics["best_record_profit"] = parse_number(first_record["profit"])
            if "result" in first_record:
                metrics["best_record_result"] = parse_number(first_record["result"])
            if "pass" in first_record:
                metrics["best_record_pass"] = parse_int(first_record["pass"])

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
            weak_points.append("標本数がやや少なく、結論を強く言いにくいです。")
        else:
            strengths.append("取引回数は最低限の検討に耐える水準です。")

    profit_factor = metrics.get("profit_factor")
    if isinstance(profit_factor, (int, float)):
        if profit_factor < 1.0:
            weak_points.append("Profit Factor が 1.0 未満で、現状の優位性は不足しています。")
        elif profit_factor < 1.2:
            weak_points.append("Profit Factor が低く、コスト悪化で崩れやすいです。")
        elif profit_factor >= 1.5:
            strengths.append("Profit Factor は比較的良好です。")

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
            weak_points.append("ドローダウンがやや大きく、リスク改善余地があります。")
        else:
            strengths.append("ドローダウンは比較的抑えられています。")

    long_rate = metrics.get("long_positions_percent")
    short_rate = metrics.get("short_positions_percent")
    if isinstance(long_rate, (int, float)) and isinstance(short_rate, (int, float)):
        if abs(long_rate - short_rate) >= 20:
            weak_points.append("買いと売りの成績差が大きく、方向依存の可能性があります。")

    if report_kind == "optimization_export" and metrics.get("records_count"):
        notes.append("最適化 XML は並び順の影響を受けるため、上位結果の評価基準を固定して扱ってください。")

    if not strengths and not weak_points:
        notes.append("主要指標を十分に読めなかったため、元レポートの確認が必要です。")

    headline = " / ".join(weak_points[:2] or strengths[:2] or ["要確認"])
    return {
        "headline": headline,
        "strengths": strengths,
        "weak_points": weak_points,
        "notes": notes,
    }


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
    ea_name = ea_name_override or metrics.get("ea_name") or "unknown-ea"
    symbol = metrics.get("symbol")
    timeframe = metrics.get("timeframe") or metrics.get("period")
    summary = build_summary(metrics, report_kind)
    raw_fields = {
        key: values if len(values) > 1 else values[0]
        for key, values in fields.items()
    }

    return {
        "imported_at": imported_at,
        "identity": {
            "title": title,
            "ea_name": ea_name,
            "symbol": symbol,
            "timeframe": timeframe,
            "report_kind": report_kind,
        },
        "source": {
            "original_path": str(report_path.resolve()),
            "type": report_path.suffix.lower().lstrip("."),
        },
        "metrics": metrics,
        "summary": summary,
        "tags": tags,
        "raw_fields": raw_fields,
        "records_preview": records[:20],
    }


def write_backtest_note(run: dict[str, Any], run_path: Path) -> Path:
    identity = run["identity"]
    metrics = run["metrics"]
    summary = run["summary"]
    slug_source = "-".join(
        part
        for part in [
            slugify(str(identity.get("ea_name") or "")),
            slugify(str(identity.get("symbol") or "")),
            slugify(str(identity.get("timeframe") or "")),
            slugify(str(run.get("run_id") or "")),
        ]
        if part
    )
    note_path = KNOWLEDGE_BACKTEST_ROOT / f"{slug_source or 'backtest'}.md"

    lines = [
        f"# {identity.get('ea_name', 'EA')} {identity.get('symbol') or ''} {identity.get('timeframe') or ''}".strip(),
        "",
        f"- Date: {run['imported_at']}",
        f"- EA: {identity.get('ea_name', '-')}",
        f"- Symbol: {identity.get('symbol', '-') or '-'}",
        f"- Timeframe: {identity.get('timeframe', '-') or '-'}",
        f"- Tester config: -",
        f"- Evidence: {repo_relative(run_path)}",
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
    next_actions = []
    if weak_points:
        next_actions.append("弱点が改善できる仮説を `knowledge/experiments/` に切り出す。")
    if metrics.get("total_trades") is not None and metrics.get("total_trades", 0) < 100:
        next_actions.append("サンプルを増やせる期間や銘柄条件を再検討する。")
    if not next_actions:
        next_actions.append("差分比較のため、次の run を取り込んで比較する。")
    lines.extend(f"- {item}" for item in next_actions)
    lines.append("")

    note_path.write_text("\n".join(lines), encoding="utf-8")
    return note_path


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
    identity = payload["identity"]
    run_slug = "-".join(
        part
        for part in [
            slugify(str(identity.get("ea_name") or "")),
            slugify(str(identity.get("symbol") or "")),
            slugify(str(identity.get("timeframe") or "")),
            slugify(source_path.stem),
        ]
        if part
    )
    run_id = f"{timestamp}-{run_slug or 'backtest-run'}"

    imported_copy_path: Path | None = None
    if copy_source:
        imported_copy_path = IMPORTED_ROOT / f"{run_id}{source_path.suffix.lower()}"
        shutil.copy2(source_path, imported_copy_path)
        payload["source"]["imported_copy_path"] = repo_relative(imported_copy_path)

    payload["run_id"] = run_id
    run_path = RUNS_ROOT / f"{run_id}.json"
    run_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    knowledge_path = write_backtest_note(payload, run_path)
    return ImportedRun(payload=payload, run_path=run_path, knowledge_path=knowledge_path, imported_copy_path=imported_copy_path)


def list_backtest_runs(limit: int = 10, ea_name: str | None = None) -> list[dict[str, Any]]:
    ensure_dirs()
    runs = sorted(RUNS_ROOT.glob("*.json"), key=lambda path: path.stat().st_mtime, reverse=True)
    items: list[dict[str, Any]] = []
    for path in runs:
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
                "headline": payload.get("summary", {}).get("headline"),
                "imported_at": payload.get("imported_at"),
            }
        )
        if len(items) >= limit:
            break
    return items


def load_run(run_path: str) -> tuple[Path, dict[str, Any]]:
    path = Path(run_path)
    resolved = path if path.is_absolute() else (REPO_ROOT / path)
    resolved = resolved.resolve()
    if not resolved.exists():
        raise FileNotFoundError(f"Run file was not found: {resolved}")
    return resolved, json.loads(resolved.read_text(encoding="utf-8"))


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


def build_cli() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Import and compare MT5 backtest reports.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    import_parser = subparsers.add_parser("import", help="Import an MT5 report into runs and knowledge.")
    import_parser.add_argument("--report", required=True, help="Path to an MT5 HTML, XML, or CSV report.")
    import_parser.add_argument("--ea-name", help="Override EA name.")
    import_parser.add_argument("--tag", action="append", default=[], help="Tag to attach to the imported run.")
    import_parser.add_argument("--no-copy", action="store_true", help="Do not copy the source report into reports/backtest/imported.")

    list_parser = subparsers.add_parser("list", help="List imported backtest runs.")
    list_parser.add_argument("--limit", type=int, default=10)
    list_parser.add_argument("--ea-name")

    summary_parser = subparsers.add_parser("summarize", help="Summarize one imported run.")
    summary_parser.add_argument("--run", required=True)

    compare_parser = subparsers.add_parser("compare", help="Compare two imported runs.")
    compare_parser.add_argument("--baseline", required=True)
    compare_parser.add_argument("--candidate", required=True)
    compare_parser.add_argument("--save", action="store_true")

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

    parser.error("Unknown command.")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
