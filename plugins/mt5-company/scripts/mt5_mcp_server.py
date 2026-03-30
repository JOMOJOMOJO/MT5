from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

from mt5_backtest_tools import (
    compare_backtest_runs,
    format_comparison,
    format_run_list,
    format_summary,
    import_backtest_report,
    list_backtest_runs,
    summarize_backtest_run,
)
from company_snapshot import (
    format_snapshot_list,
    format_snapshot_summary,
    list_company_snapshots,
    snapshot_company_state,
    summarize_company_snapshot,
)


SERVER_NAME = "mt5-workspace"
SERVER_VERSION = "0.1.0"
SCRIPT_PATH = Path(__file__).resolve()
PLUGIN_ROOT = SCRIPT_PATH.parents[1]
REPO_ROOT = SCRIPT_PATH.parents[3]
ROOT_SCRIPTS = REPO_ROOT / "scripts"
KNOWLEDGE_ROOT = REPO_ROOT / "knowledge"
KNOWLEDGE_CATEGORIES = ("company", "backtests", "optimizations", "experiments", "lessons", "patterns")


def json_dumps(payload: dict[str, Any]) -> bytes:
    return json.dumps(payload, ensure_ascii=False).encode("utf-8")


def write_message(payload: dict[str, Any]) -> None:
    body = json_dumps(payload)
    header = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
    sys.stdout.buffer.write(header)
    sys.stdout.buffer.write(body)
    sys.stdout.buffer.flush()


def read_message() -> dict[str, Any] | None:
    headers: dict[str, str] = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            return None
        if line in (b"\r\n", b"\n"):
            break
        text = line.decode("ascii").strip()
        if ":" not in text:
            continue
        key, value = text.split(":", 1)
        headers[key.lower()] = value.strip()

    content_length = int(headers.get("content-length", "0"))
    if content_length <= 0:
        return None
    body = sys.stdin.buffer.read(content_length)
    return json.loads(body.decode("utf-8"))


def resolve_repo_path(candidate: str) -> Path:
    raw = Path(candidate)
    path = raw if raw.is_absolute() else (REPO_ROOT / raw)
    resolved = path.resolve()
    if resolved != REPO_ROOT and REPO_ROOT not in resolved.parents:
        raise ValueError("Path must stay inside the repository.")
    return resolved


def repo_relative(path: Path) -> str:
    return path.resolve().relative_to(REPO_ROOT).as_posix()


def slugify(text: str) -> str:
    lowered = text.strip().lower()
    slug = re.sub(r"[^a-z0-9]+", "-", lowered).strip("-")
    return slug or "note"


def ensure_knowledge_dirs() -> None:
    for category in KNOWLEDGE_CATEGORIES:
        (KNOWLEDGE_ROOT / category).mkdir(parents=True, exist_ok=True)


def run_powershell(script: Path, extra_args: list[str]) -> dict[str, Any]:
    result = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(script),
            *extra_args,
        ],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return {
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
        "exit_code": result.returncode,
    }


def tool_list_eas(arguments: dict[str, Any]) -> str:
    del arguments
    files = sorted(REPO_ROOT.glob("mql/Experts/**/*.mq5"))
    if not files:
        return "No EA source files were found under mql/Experts/."
    return "\n".join(repo_relative(path) for path in files)


def tool_compile_ea(arguments: dict[str, Any]) -> str:
    script = ROOT_SCRIPTS / "compile.ps1"
    args: list[str] = []
    source = arguments.get("source")
    if source:
        resolved = resolve_repo_path(str(source))
        args.extend(["-Source", str(resolved)])
    result = run_powershell(script, args)
    message = [
        f"exit_code: {result['exit_code']}",
        f"stdout:\n{result['stdout'] or '(empty)'}",
        f"stderr:\n{result['stderr'] or '(empty)'}",
    ]
    if result["exit_code"] != 0:
        raise RuntimeError("\n\n".join(message))
    return "\n\n".join(message)


def tool_launch_backtest(arguments: dict[str, Any]) -> str:
    script = ROOT_SCRIPTS / "backtest.ps1"
    args: list[str] = []
    config_path = arguments.get("config_path")
    if config_path:
        resolved = resolve_repo_path(str(config_path))
        args.extend(["-ConfigPath", str(resolved)])
    result = run_powershell(script, args)
    message = [
        f"exit_code: {result['exit_code']}",
        f"stdout:\n{result['stdout'] or '(empty)'}",
        f"stderr:\n{result['stderr'] or '(empty)'}",
    ]
    if result["exit_code"] != 0:
        raise RuntimeError("\n\n".join(message))
    return "\n\n".join(message)


def tool_launch_optimization(arguments: dict[str, Any]) -> str:
    script = ROOT_SCRIPTS / "optimize.ps1"
    args: list[str] = []
    config_path = arguments.get("config_path")
    if config_path:
        resolved = resolve_repo_path(str(config_path))
        args.extend(["-ConfigPath", str(resolved)])
    result = run_powershell(script, args)
    message = [
        f"exit_code: {result['exit_code']}",
        f"stdout:\n{result['stdout'] or '(empty)'}",
        f"stderr:\n{result['stderr'] or '(empty)'}",
    ]
    if result["exit_code"] != 0:
        raise RuntimeError("\n\n".join(message))
    return "\n\n".join(message)


def tool_record_knowledge(arguments: dict[str, Any]) -> str:
    ensure_knowledge_dirs()
    category = str(arguments.get("category", "backtests"))
    if category not in KNOWLEDGE_CATEGORIES:
        raise ValueError(f"Unknown category '{category}'.")

    title = str(arguments.get("title", "")).strip()
    if not title:
        raise ValueError("title is required.")

    summary = str(arguments.get("summary", "")).strip()
    details = str(arguments.get("details", "")).strip()
    symbol = str(arguments.get("symbol", "")).strip()
    timeframe = str(arguments.get("timeframe", "")).strip()
    evidence_path = str(arguments.get("evidence_path", "")).strip()
    tags = arguments.get("tags", [])
    if not isinstance(tags, list):
        raise ValueError("tags must be an array of strings.")

    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    note_path = KNOWLEDGE_ROOT / category / f"{timestamp}-{slugify(title)}.md"

    lines = [
        f"# {title}",
        "",
        f"- Date: {datetime.now().isoformat(timespec='seconds')}",
        f"- Category: {category}",
    ]
    if symbol:
        lines.append(f"- Symbol: {symbol}")
    if timeframe:
        lines.append(f"- Timeframe: {timeframe}")
    if evidence_path:
        lines.append(f"- Evidence: {evidence_path}")
    if tags:
        lines.append(f"- Tags: {', '.join(str(tag) for tag in tags)}")

    lines.extend(
        [
            "",
            "## Summary",
            "",
            summary or "-",
            "",
            "## Details",
            "",
            details or "-",
            "",
        ]
    )

    note_path.parent.mkdir(parents=True, exist_ok=True)
    note_path.write_text("\n".join(lines), encoding="utf-8")
    return f"Saved knowledge note: {repo_relative(note_path)}"


def tool_search_knowledge(arguments: dict[str, Any]) -> str:
    ensure_knowledge_dirs()
    query = str(arguments.get("query", "")).strip().lower()
    category = str(arguments.get("category", "")).strip()
    limit = int(arguments.get("limit", 5))

    if category and category not in KNOWLEDGE_CATEGORIES:
        raise ValueError(f"Unknown category '{category}'.")

    roots = [KNOWLEDGE_ROOT / category] if category else [KNOWLEDGE_ROOT / item for item in KNOWLEDGE_CATEGORIES]
    files: list[Path] = []
    for root in roots:
        files.extend(root.rglob("*.md"))

    files = sorted(files, key=lambda path: path.stat().st_mtime, reverse=True)
    matches: list[str] = []
    for path in files:
        content = path.read_text(encoding="utf-8").strip()
        if query and query not in content.lower() and query not in path.name.lower():
            continue
        first_line = content.splitlines()[0] if content else path.name
        matches.append(f"{repo_relative(path)} :: {first_line}")
        if len(matches) >= limit:
            break

    if not matches:
        return "No knowledge notes matched the query."
    return "\n".join(matches)


def tool_import_backtest_report(arguments: dict[str, Any]) -> str:
    report_path = str(arguments.get("report_path", "")).strip()
    if not report_path:
        raise ValueError("report_path is required.")
    ea_name = str(arguments.get("ea_name", "")).strip() or None
    tags = arguments.get("tags", [])
    if not isinstance(tags, list):
        raise ValueError("tags must be an array of strings.")
    copy_source = bool(arguments.get("copy_source", True))
    imported = import_backtest_report(
        report_path=report_path,
        ea_name=ea_name,
        tags=[str(tag) for tag in tags],
        copy_source=copy_source,
    )
    lines = [
        f"Run JSON: {repo_relative(imported.run_path)}",
        f"Knowledge note: {repo_relative(imported.knowledge_path)}",
    ]
    if imported.imported_copy_path is not None:
        lines.append(f"Imported copy: {repo_relative(imported.imported_copy_path)}")
    lines.append(f"Headline: {imported.payload['summary']['headline']}")
    return "\n".join(lines)


def tool_list_backtest_runs(arguments: dict[str, Any]) -> str:
    limit = int(arguments.get("limit", 10))
    ea_name = str(arguments.get("ea_name", "")).strip() or None
    return format_run_list(list_backtest_runs(limit=limit, ea_name=ea_name))


def tool_summarize_backtest_run(arguments: dict[str, Any]) -> str:
    run_path = str(arguments.get("run_path", "")).strip()
    if not run_path:
        raise ValueError("run_path is required.")
    return format_summary(summarize_backtest_run(run_path))


def tool_compare_backtest_runs(arguments: dict[str, Any]) -> str:
    baseline = str(arguments.get("baseline_run_path", "")).strip()
    candidate = str(arguments.get("candidate_run_path", "")).strip()
    if not baseline or not candidate:
        raise ValueError("baseline_run_path and candidate_run_path are required.")
    save_markdown = bool(arguments.get("save_markdown", False))
    return format_comparison(
        compare_backtest_runs(
            baseline_path=baseline,
            candidate_path=candidate,
            save_markdown=save_markdown,
        )
    )


def tool_snapshot_company_state(arguments: dict[str, Any]) -> str:
    reason = str(arguments.get("reason", "")).strip()
    note = str(arguments.get("note", "")).strip()
    payload = snapshot_company_state(reason=reason, note=note)
    lines = [
        f"Snapshot: {payload['snapshot_path']}",
        f"Review: {payload['review_path']}",
    ]
    diff = payload.get("diff", {})
    lines.append(f"Skills added: {', '.join(diff.get('skills', {}).get('added', [])) or '(none)'}")
    lines.append(f"MCP added: {', '.join(diff.get('mcp_servers', {}).get('added', [])) or '(none)'}")
    lines.append(f"Departments added: {', '.join(diff.get('departments', {}).get('added', [])) or '(none)'}")
    return "\n".join(lines)


def tool_list_company_snapshots(arguments: dict[str, Any]) -> str:
    limit = int(arguments.get("limit", 10))
    return format_snapshot_list(list_company_snapshots(limit=limit))


def tool_summarize_company_snapshot(arguments: dict[str, Any]) -> str:
    snapshot_path = str(arguments.get("snapshot_path", "")).strip()
    if not snapshot_path:
        raise ValueError("snapshot_path is required.")
    return format_snapshot_summary(summarize_company_snapshot(snapshot_path))


TOOLS: dict[str, dict[str, Any]] = {
    "list_eas": {
        "description": "List EA source files under mql/Experts.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "additionalProperties": False,
        },
        "handler": tool_list_eas,
    },
    "compile_ea": {
        "description": "Run scripts/compile.ps1 for an EA source file.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "source": {
                    "type": "string",
                    "description": "Optional path to a .mq5 file, relative to the repo root.",
                }
            },
            "additionalProperties": False,
        },
        "handler": tool_compile_ea,
    },
    "launch_backtest": {
        "description": "Run scripts/backtest.ps1 with an optional tester config path.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "config_path": {
                    "type": "string",
                    "description": "Optional path to a tester .ini file, relative to the repo root.",
                }
            },
            "additionalProperties": False,
        },
        "handler": tool_launch_backtest,
    },
    "launch_optimization": {
        "description": "Run scripts/optimize.ps1 with an optional MT5 optimization config path.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "config_path": {
                    "type": "string",
                    "description": "Optional path to an optimization .ini file, relative to the repo root.",
                }
            },
            "additionalProperties": False,
        },
        "handler": tool_launch_optimization,
    },
    "record_knowledge": {
        "description": "Create a Markdown note under knowledge/ for backtests, experiments, lessons, or patterns.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "category": {
                    "type": "string",
                    "enum": list(KNOWLEDGE_CATEGORIES),
                },
                "title": {"type": "string"},
                "summary": {"type": "string"},
                "details": {"type": "string"},
                "symbol": {"type": "string"},
                "timeframe": {"type": "string"},
                "evidence_path": {"type": "string"},
                "tags": {
                    "type": "array",
                    "items": {"type": "string"},
                },
            },
            "required": ["category", "title"],
            "additionalProperties": False,
        },
        "handler": tool_record_knowledge,
    },
    "search_knowledge": {
        "description": "Search Markdown notes under knowledge/ and return recent matches.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string"},
                "category": {
                    "type": "string",
                    "enum": list(KNOWLEDGE_CATEGORIES),
                },
                "limit": {"type": "integer", "minimum": 1, "maximum": 20},
            },
            "additionalProperties": False,
        },
        "handler": tool_search_knowledge,
    },
    "import_backtest_report": {
        "description": "Import an MT5 HTML, XML, or CSV report into reports/backtest/runs and knowledge/backtests.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "report_path": {
                    "type": "string",
                    "description": "Absolute or repo-relative path to an MT5 report file.",
                },
                "ea_name": {
                    "type": "string",
                    "description": "Optional EA name override.",
                },
                "tags": {
                    "type": "array",
                    "items": {"type": "string"},
                },
                "copy_source": {
                    "type": "boolean",
                    "description": "Whether to copy the original report into reports/backtest/imported.",
                },
            },
            "required": ["report_path"],
            "additionalProperties": False,
        },
        "handler": tool_import_backtest_report,
    },
    "list_backtest_runs": {
        "description": "List recent imported backtest runs from reports/backtest/runs.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "limit": {"type": "integer", "minimum": 1, "maximum": 50},
                "ea_name": {"type": "string"},
            },
            "additionalProperties": False,
        },
        "handler": tool_list_backtest_runs,
    },
    "summarize_backtest_run": {
        "description": "Summarize one imported backtest run JSON file.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "run_path": {
                    "type": "string",
                    "description": "Repo-relative or absolute path to a run JSON file.",
                }
            },
            "required": ["run_path"],
            "additionalProperties": False,
        },
        "handler": tool_summarize_backtest_run,
    },
    "compare_backtest_runs": {
        "description": "Compare two imported backtest run JSON files and report improvements and regressions.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "baseline_run_path": {
                    "type": "string",
                    "description": "Repo-relative or absolute path to the baseline run JSON.",
                },
                "candidate_run_path": {
                    "type": "string",
                    "description": "Repo-relative or absolute path to the candidate run JSON.",
                },
                "save_markdown": {
                    "type": "boolean",
                    "description": "Save a markdown comparison note under reports/backtest/comparisons.",
                },
            },
            "required": ["baseline_run_path", "candidate_run_path"],
            "additionalProperties": False,
        },
        "handler": tool_compare_backtest_runs,
    },
    "snapshot_company_state": {
        "description": "Capture a snapshot of the current company structure, skills, and MCP servers, then compare it to the previous snapshot.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "reason": {"type": "string"},
                "note": {"type": "string"},
            },
            "additionalProperties": False,
        },
        "handler": tool_snapshot_company_state,
    },
    "list_company_snapshots": {
        "description": "List recent company snapshots under .company/improvement/snapshots.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "limit": {"type": "integer", "minimum": 1, "maximum": 50},
            },
            "additionalProperties": False,
        },
        "handler": tool_list_company_snapshots,
    },
    "summarize_company_snapshot": {
        "description": "Summarize one company snapshot JSON file.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "snapshot_path": {
                    "type": "string",
                    "description": "Repo-relative or absolute path to a company snapshot JSON file.",
                }
            },
            "required": ["snapshot_path"],
            "additionalProperties": False,
        },
        "handler": tool_summarize_company_snapshot,
    },
}


def handle_request(message: dict[str, Any]) -> dict[str, Any] | None:
    method = message.get("method")
    request_id = message.get("id")
    params = message.get("params", {})

    if method == "initialize":
        protocol_version = params.get("protocolVersion", "2024-11-05")
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {
                "protocolVersion": protocol_version,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
            },
        }

    if method == "notifications/initialized":
        return None

    if method == "ping":
        return {"jsonrpc": "2.0", "id": request_id, "result": {}}

    if method == "tools/list":
        tools = []
        for name, payload in TOOLS.items():
            tools.append(
                {
                    "name": name,
                    "description": payload["description"],
                    "inputSchema": payload["inputSchema"],
                }
            )
        return {"jsonrpc": "2.0", "id": request_id, "result": {"tools": tools}}

    if method == "tools/call":
        name = params.get("name")
        arguments = params.get("arguments", {})
        tool = TOOLS.get(name)
        if tool is None:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "content": [{"type": "text", "text": f"Unknown tool: {name}"}],
                    "isError": True,
                },
            }
        try:
            output = tool["handler"](arguments)
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "content": [{"type": "text", "text": output}],
                    "isError": False,
                },
            }
        except Exception as exc:  # noqa: BLE001
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "content": [{"type": "text", "text": str(exc)}],
                    "isError": True,
                },
            }

    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "error": {
            "code": -32601,
            "message": f"Method not found: {method}",
        },
    }


def main() -> int:
    ensure_knowledge_dirs()
    while True:
        message = read_message()
        if message is None:
            return 0
        response = handle_request(message)
        if response is not None:
            write_message(response)


if __name__ == "__main__":
    raise SystemExit(main())
