"""Regression tests for the al-developer-bench agent markdown.

These tests guard the three reinforcement edits made to al-developer-bench
after the audit revealed that the model could not be relied on to load rule
files via auto-apply. The agent body itself is the highest-weight location
for instructions in a CLI host (it IS the system prompt when invoked via
--agent=al-developer-bench), so we inline the most critical conventions
there directly.

If any of these tests fail, the bench agent has lost reinforcement that the
evaluation depends on. Either restore the missing section or update the test
to match the new expectation explicitly.
"""

from pathlib import Path

import pytest

from bcbench.config import get_config

_config = get_config()

# Both repo variants ship the same bench agent file. They must remain in sync
# so that whichever testbed gets cloned, the agent has the same reinforcement.
_BENCH_AGENT_PATHS = [
    _config.paths.agent_share_dir / "instructions" / "microsoft-BCApps" / "agents" / "al-developer-bench.md",
    _config.paths.agent_share_dir / "instructions" / "microsoftInternal-NAV" / "agents" / "al-developer-bench.md",
]


@pytest.fixture(params=_BENCH_AGENT_PATHS, ids=lambda p: p.parent.parent.name)
def bench_agent_text(request) -> str:
    path: Path = request.param
    assert path.exists(), f"al-developer-bench.md not found at {path}"
    return path.read_text(encoding="utf-8")


def test_frontmatter_intact(bench_agent_text: str):
    """The agent file must still parse as a Claude Code agent (frontmatter at top)."""
    assert bench_agent_text.startswith("---\n"), "agent must start with YAML frontmatter"
    assert "name: AL Implementation Specialist (Bench Mode)" in bench_agent_text
    assert "tools:" in bench_agent_text
    assert "model:" in bench_agent_text


def test_bench_step_0_present(bench_agent_text: str):
    """Step 0 must instruct the agent to read the failing test before touching code."""
    assert "Bench Mode — Step 0: Read the Test Contract FIRST" in bench_agent_text, (
        "Step 0 (read test first) is missing — bench runs may form fix hypotheses "
        "before reading the test contract"
    )
    # The procedure must mention searching for tests and reading them in full
    assert "Glob: **/*Test*.al" in bench_agent_text or "*Tests.al" in bench_agent_text
    assert "test is authoritative" in bench_agent_text.lower()
    # Anti-pattern warning is the closer that anchors Step 0
    assert "Anti-pattern" in bench_agent_text


def test_test_files_are_read_only_boundary_present(bench_agent_text: str):
    """The agent must explicitly know test files are read-only.

    Without this hard boundary the model occasionally tries to "fix" a failing
    test by changing assertions to match its (wrong) implementation, which
    invalidates the entire run.
    """
    assert "TEST FILES ARE READ-ONLY" in bench_agent_text, (
        "Hard boundary 'test files are read-only' is missing"
    )
    # Three explicit prohibitions that must remain enumerated
    assert "Add, remove, or modify `[Test]` procedures" in bench_agent_text
    assert "Change assertion values" in bench_agent_text
    assert "Disable tests" in bench_agent_text


def test_hardcoded_conventions_section_present(bench_agent_text: str):
    """The inlined AL conventions must remain in the agent body.

    These were inlined deliberately because CLI hosts do not honor VS Code
    Copilot Chat's auto-apply mechanism for rule files. If this section
    disappears the agent loses its highest-weight reference for the AL
    conventions that break runs most often when ignored.
    """
    assert "<hardcoded_conventions>" in bench_agent_text
    assert "</hardcoded_conventions>" in bench_agent_text

    # Spot-check the most critical conventions
    must_contain = [
        # Naming
        "3-character prefix",
        "max **26 characters",
        # Field access (this is a frequent source of compile errors)
        "Rec is reserved for triggers",
        # Test library refs (the #1 source of AL0185 errors)
        'Codeunit "Library Assert"',
        "AL0185",
        # Test codeunit skeleton
        "Subtype = Test;",
        "TestPermissions = TestPermissions::Disabled",
        # Extension-only pattern
        "tableextension",
        "EventSubscriber",
        # Performance
        "SetLoadFields",
        "early filtering",
        # Error handling
        "TryFunction",
        # Final checklist
        "Quick checklist before declaring a fix complete",
    ]
    missing = [phrase for phrase in must_contain if phrase not in bench_agent_text]
    assert not missing, f"hardcoded_conventions section is missing critical phrases: {missing}"


def test_bcapps_and_nav_copies_in_sync():
    """Both bench file copies must be byte-identical.

    The two repos use identical bench mode agents — drift between them would
    mean a comparison run reads different instructions depending on which
    dataset entry it picked, which would silently bias the experiment.
    """
    bcapps = _BENCH_AGENT_PATHS[0].read_bytes()
    nav = _BENCH_AGENT_PATHS[1].read_bytes()
    assert bcapps == nav, (
        "al-developer-bench.md drifted between microsoft-BCApps and microsoftInternal-NAV — "
        "re-sync them so both datasets evaluate against the same agent"
    )


def test_pause_and_confirm_gates_disabled_in_bench(bench_agent_text: str):
    """Bench mode must NOT have HITL gates active.

    The bench agent inherits the developer's PAUSE/Confirm logic but disables
    it (auto-continue). If the disabling marker disappears, the agent will
    start asking the user for approvals during runs and time out.
    """
    assert "disabled in bench mode — auto-continue" in bench_agent_text, (
        "PAUSE/Confirm gates appear active — bench runs will hang waiting for user input"
    )
