from __future__ import annotations

import argparse
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).resolve()
PLUGIN_ROOT = SCRIPT_PATH.parents[1]
REPO_ROOT = SCRIPT_PATH.parents[3]
SKILLS_ROOT = PLUGIN_ROOT / "skills"
MCP_CONFIG_PATH = PLUGIN_ROOT / ".mcp.json"
PLUGIN_CONFIG_PATH = PLUGIN_ROOT / ".codex-plugin" / "plugin.json"
DEPARTMENTS_PATH = SKILLS_ROOT / "company" / "references" / "departments.md"
IMPROVEMENT_ROOT = REPO_ROOT / ".company" / "improvement"
SNAPSHOT_ROOT = IMPROVEMENT_ROOT / "snapshots"
REVIEW_ROOT = IMPROVEMENT_ROOT / "reviews"
CATALOG_PATH = IMPROVEMENT_ROOT / "snapshot-catalog.jsonl"
COMPANY_KNOWLEDGE_ROOT = REPO_ROOT / "knowledge" / "company"


def ensure_dirs() -> None:
    SNAPSHOT_ROOT.mkdir(parents=True, exist_ok=True)
    REVIEW_ROOT.mkdir(parents=True, exist_ok=True)
    COMPANY_KNOWLEDGE_ROOT.mkdir(parents=True, exist_ok=True)
    CATALOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not CATALOG_PATH.exists():
        CATALOG_PATH.write_text("", encoding="utf-8")


def repo_relative(path: Path) -> str:
    return path.resolve().relative_to(REPO_ROOT).as_posix()


def slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.strip().lower()).strip("-")
    return slug or "review"


def parse_departments() -> list[str]:
    if not DEPARTMENTS_PATH.exists():
        return []
    lines = DEPARTMENTS_PATH.read_text(encoding="utf-8").splitlines()
    departments: list[str] = []
    for line in lines:
        match = re.match(r"^##\s+(.+)$", line.strip())
        if match:
            departments.append(match.group(1).strip())
    return departments


def collect_skills() -> list[dict[str, str]]:
    skills: list[dict[str, str]] = []
    for path in sorted(SKILLS_ROOT.iterdir()):
        if not path.is_dir():
            continue
        skill_file = path / "SKILL.md"
        if not skill_file.exists():
            continue
        skills.append(
            {
                "name": path.name,
                "path": repo_relative(skill_file),
            }
        )
    return skills


def collect_mcp_servers() -> list[dict[str, Any]]:
    if not MCP_CONFIG_PATH.exists():
        return []
    payload = json.loads(MCP_CONFIG_PATH.read_text(encoding="utf-8"))
    servers = payload.get("mcpServers", {})
    items: list[dict[str, Any]] = []
    for name in sorted(servers):
        config = servers[name]
        items.append(
            {
                "name": name,
                "command": config.get("command"),
                "args": config.get("args", []),
            }
        )
    return items


def load_plugin_info() -> dict[str, Any]:
    if not PLUGIN_CONFIG_PATH.exists():
        return {}
    payload = json.loads(PLUGIN_CONFIG_PATH.read_text(encoding="utf-8"))
    return {
        "name": payload.get("name"),
        "version": payload.get("version"),
        "mcp_servers_path": payload.get("mcpServers"),
        "skills_path": payload.get("skills"),
    }


def build_snapshot(reason: str = "", note: str = "") -> dict[str, Any]:
    return {
        "captured_at": datetime.now().isoformat(timespec="seconds"),
        "reason": reason.strip(),
        "note": note.strip(),
        "plugin": load_plugin_info(),
        "departments": parse_departments(),
        "skills": collect_skills(),
        "mcp_servers": collect_mcp_servers(),
    }


def get_snapshot_files() -> list[Path]:
    if not SNAPSHOT_ROOT.exists():
        return []
    return sorted(SNAPSHOT_ROOT.glob("*.json"))


def load_latest_snapshot(exclude_path: Path | None = None) -> tuple[Path | None, dict[str, Any] | None]:
    files = get_snapshot_files()
    if exclude_path is not None:
        files = [path for path in files if path.resolve() != exclude_path.resolve()]
    if not files:
        return None, None
    latest = files[-1]
    return latest, json.loads(latest.read_text(encoding="utf-8"))


def compare_name_lists(previous: list[str], current: list[str]) -> dict[str, list[str]]:
    prev_set = set(previous)
    curr_set = set(current)
    return {
        "added": sorted(curr_set - prev_set),
        "removed": sorted(prev_set - curr_set),
        "unchanged": sorted(curr_set & prev_set),
    }


def build_diff(previous: dict[str, Any] | None, current: dict[str, Any]) -> dict[str, Any]:
    if previous is None:
        return {
            "departments": {"added": current["departments"], "removed": [], "unchanged": []},
            "skills": {"added": [item["name"] for item in current["skills"]], "removed": [], "unchanged": []},
            "mcp_servers": {"added": [item["name"] for item in current["mcp_servers"]], "removed": [], "unchanged": []},
        }

    prev_departments = previous.get("departments", [])
    prev_skills = [item.get("name", "") for item in previous.get("skills", [])]
    prev_mcp = [item.get("name", "") for item in previous.get("mcp_servers", [])]
    curr_skills = [item.get("name", "") for item in current.get("skills", [])]
    curr_mcp = [item.get("name", "") for item in current.get("mcp_servers", [])]
    return {
        "departments": compare_name_lists(prev_departments, current.get("departments", [])),
        "skills": compare_name_lists(prev_skills, curr_skills),
        "mcp_servers": compare_name_lists(prev_mcp, curr_mcp),
    }


def write_review_note(
    snapshot_path: Path,
    previous_path: Path | None,
    diff: dict[str, Any],
    reason: str,
    note: str,
) -> Path:
    stamp = snapshot_path.stem
    review_path = REVIEW_ROOT / f"{stamp}-review.md"
    lines = [
        "# Company Improvement Review",
        "",
        f"- Date: {datetime.now().date().isoformat()}",
        f"- Trigger: {reason or 'snapshot'}",
        f"- Previous snapshot: {repo_relative(previous_path) if previous_path else '(none)'}",
        f"- Current snapshot: {repo_relative(snapshot_path)}",
        f"- CEO approval needed: {'yes' if any(diff[key]['added'] or diff[key]['removed'] for key in diff) else 'no'}",
        "",
        "## Diff",
        "",
        f"- Added departments: {', '.join(diff['departments']['added']) or '(none)'}",
        f"- Removed departments: {', '.join(diff['departments']['removed']) or '(none)'}",
        f"- Added skills: {', '.join(diff['skills']['added']) or '(none)'}",
        f"- Removed skills: {', '.join(diff['skills']['removed']) or '(none)'}",
        f"- Added MCP servers: {', '.join(diff['mcp_servers']['added']) or '(none)'}",
        f"- Removed MCP servers: {', '.join(diff['mcp_servers']['removed']) or '(none)'}",
        "",
        "## Assessment",
        "",
        note or "-",
        "",
    ]
    review_path.write_text("\n".join(lines), encoding="utf-8")
    return review_path


def write_company_knowledge_note(
    snapshot_path: Path,
    previous_path: Path | None,
    review_path: Path,
    diff: dict[str, Any],
    reason: str,
    note: str,
) -> Path:
    stamp = snapshot_path.stem
    knowledge_path = COMPANY_KNOWLEDGE_ROOT / f"{stamp}.md"
    lines = [
        f"# 会社ナレッジ: {reason or 'snapshot'}",
        "",
        f"- 日付: {datetime.now().date().isoformat()}",
        f"- トリガー: {reason or 'snapshot'}",
        f"- 前回スナップショット: {repo_relative(previous_path) if previous_path else '(none)'}",
        f"- 今回スナップショット: {repo_relative(snapshot_path)}",
        f"- レビュー: {repo_relative(review_path)}",
        "",
        "## 要約",
        "",
        note or "-",
        "",
        "## 差分",
        "",
        f"- 追加された部署: {', '.join(diff['departments']['added']) or '(none)'}",
        f"- 削除された部署: {', '.join(diff['departments']['removed']) or '(none)'}",
        f"- 追加されたスキル: {', '.join(diff['skills']['added']) or '(none)'}",
        f"- 削除されたスキル: {', '.join(diff['skills']['removed']) or '(none)'}",
        f"- 追加されたMCP: {', '.join(diff['mcp_servers']['added']) or '(none)'}",
        f"- 削除されたMCP: {', '.join(diff['mcp_servers']['removed']) or '(none)'}",
        "",
        "## 学び",
        "",
        "- 共有能力の変更は、構造スナップショットと人間の判断記録を両方残す。",
        "- 会社の根本変更は、引き続き CEO 承認と結びつける。",
    ]
    knowledge_path.write_text("\n".join(lines), encoding="utf-8")
    return knowledge_path


def snapshot_company_state(reason: str = "", note: str = "") -> dict[str, Any]:
    ensure_dirs()
    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    suffix = slugify(reason) if reason else "snapshot"
    snapshot_path = SNAPSHOT_ROOT / f"{timestamp}-{suffix}.json"
    current = build_snapshot(reason=reason, note=note)
    previous_path, previous = load_latest_snapshot()
    diff = build_diff(previous, current)
    current["diff_from_previous"] = diff
    current["previous_snapshot"] = repo_relative(previous_path) if previous_path else None
    snapshot_path.write_text(json.dumps(current, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    review_path = write_review_note(snapshot_path, previous_path, diff, reason, note)
    knowledge_path = write_company_knowledge_note(snapshot_path, previous_path, review_path, diff, reason, note)
    catalog_entry = {
        "captured_at": current["captured_at"],
        "snapshot_path": repo_relative(snapshot_path),
        "review_path": repo_relative(review_path),
        "knowledge_path": repo_relative(knowledge_path),
        "reason": reason,
    }
    with CATALOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(catalog_entry, ensure_ascii=False) + "\n")

    return {
        "snapshot_path": repo_relative(snapshot_path),
        "review_path": repo_relative(review_path),
        "knowledge_path": repo_relative(knowledge_path),
        "diff": diff,
    }


def list_company_snapshots(limit: int = 10) -> list[dict[str, Any]]:
    ensure_dirs()
    lines = [line for line in CATALOG_PATH.read_text(encoding="utf-8").splitlines() if line.strip()]
    items = [json.loads(line) for line in lines]
    items.reverse()
    return items[:limit]


def load_snapshot(snapshot_path: str) -> tuple[Path, dict[str, Any]]:
    candidate = Path(snapshot_path)
    if candidate.is_absolute():
        resolved = candidate.resolve()
    else:
        resolved = (REPO_ROOT / candidate).resolve()
        if not resolved.exists():
            matches = list(SNAPSHOT_ROOT.glob(f"*{snapshot_path}*"))
            if len(matches) == 1:
                resolved = matches[0].resolve()
    if not resolved.exists():
        raise FileNotFoundError(f"Snapshot file was not found: {snapshot_path}")
    return resolved, json.loads(resolved.read_text(encoding="utf-8"))


def summarize_company_snapshot(snapshot_path: str) -> dict[str, Any]:
    resolved, payload = load_snapshot(snapshot_path)
    return {
        "path": repo_relative(resolved),
        "captured_at": payload.get("captured_at"),
        "reason": payload.get("reason"),
        "departments": payload.get("departments", []),
        "skills": [item.get("name") for item in payload.get("skills", [])],
        "mcp_servers": [item.get("name") for item in payload.get("mcp_servers", [])],
        "diff_from_previous": payload.get("diff_from_previous", {}),
    }


def format_snapshot_list(items: list[dict[str, Any]]) -> str:
    if not items:
        return "No company snapshots were found."
    lines = []
    for item in items:
        lines.append(
            f"{item.get('captured_at')} :: {item.get('snapshot_path')} :: "
            f"{item.get('reason') or 'snapshot'}"
        )
    return "\n".join(lines)


def format_snapshot_summary(payload: dict[str, Any]) -> str:
    diff = payload.get("diff_from_previous", {})
    lines = [
        f"Snapshot: {payload['path']}",
        f"Captured at: {payload.get('captured_at')}",
        f"Reason: {payload.get('reason') or 'snapshot'}",
        "",
        f"Departments: {', '.join(payload.get('departments', [])) or '(none)'}",
        f"Skills: {', '.join(payload.get('skills', [])) or '(none)'}",
        f"MCP servers: {', '.join(payload.get('mcp_servers', [])) or '(none)'}",
        "",
        "Diff from previous:",
        f"- Departments added: {', '.join(diff.get('departments', {}).get('added', [])) or '(none)'}",
        f"- Departments removed: {', '.join(diff.get('departments', {}).get('removed', [])) or '(none)'}",
        f"- Skills added: {', '.join(diff.get('skills', {}).get('added', [])) or '(none)'}",
        f"- Skills removed: {', '.join(diff.get('skills', {}).get('removed', [])) or '(none)'}",
        f"- MCP added: {', '.join(diff.get('mcp_servers', {}).get('added', [])) or '(none)'}",
        f"- MCP removed: {', '.join(diff.get('mcp_servers', {}).get('removed', [])) or '(none)'}",
    ]
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Snapshot and review the repo-local company structure.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    snapshot_parser = subparsers.add_parser("snapshot")
    snapshot_parser.add_argument("--reason", default="")
    snapshot_parser.add_argument("--note", default="")

    list_parser = subparsers.add_parser("list")
    list_parser.add_argument("--limit", type=int, default=10)

    summarize_parser = subparsers.add_parser("summarize")
    summarize_parser.add_argument("--snapshot", required=True)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.command == "snapshot":
        payload = snapshot_company_state(reason=args.reason, note=args.note)
        print(f"Snapshot: {payload['snapshot_path']}")
        print(f"Review: {payload['review_path']}")
        return 0

    if args.command == "list":
        print(format_snapshot_list(list_company_snapshots(limit=args.limit)))
        return 0

    if args.command == "summarize":
        print(format_snapshot_summary(summarize_company_snapshot(args.snapshot)))
        return 0

    parser.error(f"Unknown command: {args.command}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
