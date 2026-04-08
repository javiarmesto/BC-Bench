"""Parser for ALDC runtime usage from agent debug/session logs.

After an agent run completes, this module inspects the host-specific
debug log and extracts evidence that the ALDC components placed in the
testbed were actually exercised by the model — not just available.

Distinguishes:
  * skills_invoked   — which `.claude/skills/skill-X/SKILL.md` skills the
                       model loaded via the Skill tool
  * subagents_invoked — which custom subagents the model delegated to via
                       the Task tool (al-planning-subagent, etc.)
  * custom_agent_confirmed — whether the agent name passed via --agent=
                             appears anywhere in the log (a sanity check
                             that the host actually loaded the file)

The parser is intentionally tolerant: it works against both Claude Code
debug logs and Copilot CLI session logs, because both formats embed JSON
tool inputs that mention skill / subagent names by string. If a host
changes its log format, the worst case is we report empty counts — never
a crash.
"""

from __future__ import annotations

import re
from collections import Counter
from pathlib import Path

from bcbench.logger import get_logger
from bcbench.types import ALDCUsage

logger = get_logger(__name__)

# `"name": "skill-XXX"` — matches Skill tool input args from Claude or
# Copilot. Both hosts dump tool inputs as JSON in their logs, with the skill
# identifier appearing inside a "name" field.
_SKILL_NAME_PATTERN = re.compile(r'"name"\s*:\s*"(skill-[a-z][a-z0-9-]*)"')

# `"subagent_type": "al-planning-subagent"` — Task tool input args naming
# the delegated agent. Restrict to AL subagents to avoid catching unrelated
# strings.
_SUBAGENT_PATTERN = re.compile(r'"subagent_type"\s*:\s*"(al-[a-z0-9-]+)"')

# Fallback: known AL subagent names appearing as bare strings in the log
_KNOWN_SUBAGENTS = (
    "al-planning-subagent",
    "al-implement-subagent",
    "al-review-subagent",
)


def parse_aldc_usage(log_path: Path | None, custom_agent: str | None) -> ALDCUsage:
    """Inspect an agent log and extract ALDC usage evidence.

    Args:
        log_path: Path to the debug or session log file. May be None or
            missing — both produce an empty ALDCUsage.
        custom_agent: The agent name passed via --agent=... at run time.
            Used to confirm the host actually loaded the agent file.

    Returns:
        ALDCUsage with skills_invoked, subagents_invoked, and
        custom_agent_confirmed populated.
    """
    if log_path is None or not log_path.exists():
        return ALDCUsage()

    try:
        content = log_path.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        logger.warning(f"Could not read agent log {log_path}: {e}")
        return ALDCUsage()

    return parse_aldc_usage_from_text(content, custom_agent)


def parse_aldc_usage_from_text(content: str, custom_agent: str | None) -> ALDCUsage:
    """Same as parse_aldc_usage but operates on raw log text.

    Useful for tests and for callers that already have the log in memory.
    """
    skills: Counter[str] = Counter()
    for match in _SKILL_NAME_PATTERN.finditer(content):
        skills[match.group(1)] += 1

    subagents: Counter[str] = Counter()
    for match in _SUBAGENT_PATTERN.finditer(content):
        subagents[match.group(1)] += 1

    # Fallback: if the JSON-args pattern missed the subagent_type field,
    # count bare references to known AL subagent identifiers. This catches
    # cases where the host logs the delegated agent name in a non-JSON line
    # (e.g. "Delegating to al-planning-subagent...").
    if not subagents:
        for name in _KNOWN_SUBAGENTS:
            count = content.count(name)
            if count > 0:
                subagents[name] = count

    custom_agent_confirmed = False
    if custom_agent:
        custom_agent_confirmed = custom_agent in content

    return ALDCUsage(
        skills_invoked=dict(skills),
        subagents_invoked=dict(subagents),
        custom_agent_confirmed=custom_agent_confirmed,
    )
