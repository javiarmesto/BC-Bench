"""Tests for the ALDC runtime usage parser shared by Claude and Copilot."""

from pathlib import Path
from tempfile import NamedTemporaryFile

from bcbench.agent.shared.aldc_usage import parse_aldc_usage, parse_aldc_usage_from_text


def test_empty_log_returns_empty_usage():
    usage = parse_aldc_usage_from_text("", custom_agent="al-developer-bench")
    assert usage.skills_invoked == {}
    assert usage.subagents_invoked == {}
    assert usage.custom_agent_confirmed is False


def test_missing_log_path_returns_empty():
    usage = parse_aldc_usage(Path("/nonexistent/path.log"), custom_agent="al-developer-bench")
    assert usage.skills_invoked == {}
    assert usage.subagents_invoked == {}
    assert usage.custom_agent_confirmed is False


def test_none_log_path_returns_empty():
    usage = parse_aldc_usage(None, custom_agent=None)
    assert usage.skills_invoked == {}
    assert usage.subagents_invoked == {}
    assert usage.custom_agent_confirmed is False


def test_skill_invocations_extracted_from_json_args():
    """The Skill tool input args contain `"name": "skill-XXX"`."""
    log = """
    [DEBUG] executePreToolHooks called for tool: Skill
    [DEBUG] Tool input: {"name": "skill-testing"}
    [DEBUG] executePreToolHooks called for tool: Skill
    [DEBUG] Tool input: {"name": "skill-api"}
    [DEBUG] executePreToolHooks called for tool: Skill
    [DEBUG] Tool input: {"name": "skill-testing"}
    """
    usage = parse_aldc_usage_from_text(log, custom_agent=None)
    assert usage.skills_invoked == {"skill-testing": 2, "skill-api": 1}


def test_subagent_invocations_extracted_from_task_args():
    """The Task tool input args contain `"subagent_type": "al-XXX"`."""
    log = """
    [DEBUG] executePreToolHooks called for tool: Task
    [DEBUG] Tool input: {"subagent_type": "al-planning-subagent", "prompt": "..."}
    [DEBUG] executePreToolHooks called for tool: Task
    [DEBUG] Tool input: {"subagent_type": "al-review-subagent", "prompt": "..."}
    """
    usage = parse_aldc_usage_from_text(log, custom_agent=None)
    assert usage.subagents_invoked == {"al-planning-subagent": 1, "al-review-subagent": 1}


def test_subagent_fallback_when_json_pattern_misses():
    """If no `subagent_type` JSON, fall back to bare-name detection of known subagents."""
    log = "Delegating control to al-planning-subagent for spec analysis..."
    usage = parse_aldc_usage_from_text(log, custom_agent=None)
    assert "al-planning-subagent" in usage.subagents_invoked
    assert usage.subagents_invoked["al-planning-subagent"] >= 1


def test_custom_agent_confirmed_when_name_in_log():
    log = "Loading agent from .claude/agents/al-developer-bench.md ... done"
    usage = parse_aldc_usage_from_text(log, custom_agent="al-developer-bench")
    assert usage.custom_agent_confirmed is True


def test_custom_agent_not_confirmed_when_absent():
    log = "Loading agent from .claude/agents/al-conductor-bench.md ... done"
    usage = parse_aldc_usage_from_text(log, custom_agent="al-developer-bench")
    assert usage.custom_agent_confirmed is False


def test_custom_agent_none_means_no_check():
    log = "anything"
    usage = parse_aldc_usage_from_text(log, custom_agent=None)
    assert usage.custom_agent_confirmed is False


def test_full_example_combines_all_signals():
    """Realistic mixed log with skills, subagents, and the agent name."""
    log = """
    [INFO] Starting Claude Code with --agent=al-conductor-bench
    [DEBUG] Loading .claude/agents/al-conductor-bench.md
    [DEBUG] executePreToolHooks called for tool: Task
    [DEBUG] Tool input: {"subagent_type": "al-planning-subagent", "prompt": "design"}
    [DEBUG] executePreToolHooks called for tool: Skill
    [DEBUG] Tool input: {"name": "skill-testing"}
    [DEBUG] executePreToolHooks called for tool: Task
    [DEBUG] Tool input: {"subagent_type": "al-implement-subagent", "prompt": "code"}
    [DEBUG] executePreToolHooks called for tool: Skill
    [DEBUG] Tool input: {"name": "skill-events"}
    """
    usage = parse_aldc_usage_from_text(log, custom_agent="al-conductor-bench")
    assert usage.skills_invoked == {"skill-testing": 1, "skill-events": 1}
    assert usage.subagents_invoked == {"al-planning-subagent": 1, "al-implement-subagent": 1}
    assert usage.custom_agent_confirmed is True


def test_real_file_round_trip():
    """End-to-end: write to a temp file and read it back via parse_aldc_usage."""
    log_content = """
    [DEBUG] executePreToolHooks called for tool: Skill
    [DEBUG] Tool input: {"name": "skill-api"}
    Loading al-developer-bench from .claude/agents/
    """
    with NamedTemporaryFile(mode="w", suffix=".log", delete=False, encoding="utf-8") as f:
        f.write(log_content)
        log_path = Path(f.name)

    try:
        usage = parse_aldc_usage(log_path, custom_agent="al-developer-bench")
        assert usage.skills_invoked == {"skill-api": 1}
        assert usage.custom_agent_confirmed is True
    finally:
        log_path.unlink()
