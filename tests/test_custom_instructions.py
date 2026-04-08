"""
Simple verification script for custom instructions framework.
Verifies that instruction files get created without invoking the copilot agent.
"""

from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import MagicMock

from bcbench.config import get_config
from bcbench.dataset import DatasetEntry
from bcbench.operations.instruction_operations import (
    _get_source_instructions_path,
    build_aldc_evidence,
    setup_custom_agent,
    setup_instructions_from_config,
)
from bcbench.operations.skills_operations import setup_agent_skills
from bcbench.types import AgentType

_config = get_config()


def test_get_instructions_path():
    # Test with microsoftInternal/NAV
    path = _get_source_instructions_path("microsoftInternal/NAV")
    assert path.exists(), f"Instruction file should exist: {path}"
    assert path.name == "microsoftInternal-NAV"


def test_setup_custom_instructions():
    instructions_source = _get_source_instructions_path("microsoftInternal/NAV")

    with TemporaryDirectory() as tmpdir:
        repo_path = Path(tmpdir)
        entry = MagicMock(spec=DatasetEntry)
        entry.repo = "microsoftInternal/NAV"
        config = {"instructions": {"enabled": True}}

        # Setup instructions
        result = setup_instructions_from_config(config, entry, repo_path, agent_type=AgentType.COPILOT)
        assert result is True

        # Verify
        target_path = repo_path / ".github"
        assert target_path.exists(), ".github directory should be created"

        # Verify files were copied (AGENTS.md gets renamed to agent-specific filename)
        source_naming = _config.file_patterns.instruction_source_naming
        for item in instructions_source.iterdir():
            target_item = target_path / AgentType.COPILOT.instruction_filename if item.name == source_naming else target_path / item.name
            assert target_item.exists(), f"{target_item} should exist"

            # Verify file content matches
            if item.is_file():
                source_content = item.read_text(encoding="utf-8")
                target_content = target_item.read_text(encoding="utf-8")
                if item.name == source_naming:
                    # Root instructions file has rules inlined as a trailing section
                    assert target_content.startswith(source_content), f"Renamed {target_item.name} should start with source AGENTS.md content"
                    assert "# Coding Rules (auto-loaded)" in target_content, f"{target_item.name} should have inlined rules section"
                else:
                    assert target_content == source_content, f"Content mismatch for {item.name}"
            elif item.is_dir():
                # For directories, verify all files match recursively
                for source_file in item.rglob("*"):
                    if source_file.is_file():
                        target_file = target_item / source_file.relative_to(item)
                        assert target_file.exists(), f"{target_file} should exist"
                        assert target_file.read_text(encoding="utf-8") == source_file.read_text(encoding="utf-8"), f"Content mismatch for {target_file}"


def test_sanitization():
    test_cases = [
        ("microsoftInternal/NAV", "microsoftInternal-NAV"),
        ("org/repo", "org-repo"),
        ("user/my-repo", "user-my-repo"),
    ]

    for repo_name, expected_sanitized in test_cases:
        sanitized = repo_name.replace("/", "-")
        assert sanitized == expected_sanitized, f"Failed for {repo_name}"


def test_nonexistent_instructions():
    try:
        _get_source_instructions_path("nonexistent/repo")
        raise AssertionError("Should raise FileNotFoundError")
    except FileNotFoundError as e:
        assert "nonexistent/repo" in str(e)


def test_overwrite_existing_instructions():
    instructions_source = _get_source_instructions_path("microsoftInternal/NAV")

    with TemporaryDirectory() as tmpdir:
        repo_path = Path(tmpdir)
        entry = MagicMock(spec=DatasetEntry)
        entry.repo = "microsoftInternal/NAV"
        config = {"instructions": {"enabled": True}}

        # Create initial instruction file with different content
        github_dir = repo_path / ".github"
        github_dir.mkdir(parents=True, exist_ok=True)
        target_path = github_dir / AgentType.COPILOT.instruction_filename
        original_content = "# Original instructions\nThis should be overwritten"
        target_path.write_text(original_content)

        # Setup instructions (should overwrite)
        setup_instructions_from_config(config, entry, repo_path, agent_type=AgentType.COPILOT)

        # Verify file was overwritten
        assert target_path.exists(), "Instruction file should exist"
        new_content = target_path.read_text(encoding="utf-8")
        assert new_content != original_content, "Content should be overwritten"
        source_file = instructions_source / _config.file_patterns.instruction_source_naming
        assert new_content.startswith(source_file.read_text(encoding="utf-8")), "Content should start with source AGENTS.md"
        assert "# Coding Rules (auto-loaded)" in new_content, "Rules should be inlined"


def test_path_specific_instructions_removed_before_copy():
    with TemporaryDirectory() as tmpdir:
        repo_path = Path(tmpdir)
        entry = MagicMock(spec=DatasetEntry)
        entry.repo = "microsoftInternal/NAV"
        config = {"instructions": {"enabled": True}}

        # Create existing .github directory with old files
        github_dir = repo_path / ".github"
        github_dir.mkdir(parents=True, exist_ok=True)
        old_file = github_dir / "old.md"
        old_file.write_text("# Old instruction that should be removed")

        # Setup instructions (should remove existing .github and copy new one)
        setup_instructions_from_config(config, entry, repo_path, agent_type=AgentType.COPILOT)

        # Verify old file was removed
        assert not (github_dir / "old.md").exists(), "Old file should be removed"
        # Verify new structure was copied
        assert github_dir.exists(), ".github directory should exist after setup"
        assert (github_dir / AgentType.COPILOT.instruction_filename).exists(), "Main instruction file should exist"


def test_no_path_specific_instructions_warning():
    with TemporaryDirectory() as tmpdir:
        repo_path = Path(tmpdir)
        entry = MagicMock(spec=DatasetEntry)
        entry.repo = "microsoftInternal/NAV"
        config = {"instructions": {"enabled": True}}

        # Setup instructions
        setup_instructions_from_config(config, entry, repo_path, agent_type=AgentType.COPILOT)

        # Verify repository-level instructions were created
        github_dir = repo_path / ".github"
        assert github_dir.exists(), ".github directory should be created"
        assert (github_dir / AgentType.COPILOT.instruction_filename).exists(), "Main instruction file should exist"


def test_empty_instructions_folder_warning():
    with TemporaryDirectory() as tmpdir:
        repo_path = Path(tmpdir)
        entry = MagicMock(spec=DatasetEntry)
        entry.repo = "microsoftInternal/NAV"
        config = {"instructions": {"enabled": True}}

        # Setup instructions
        setup_instructions_from_config(config, entry, repo_path, agent_type=AgentType.COPILOT)

        # Verify .github directory was created
        github_dir = repo_path / ".github"
        assert github_dir.exists(), ".github directory should be created"
        assert (github_dir / AgentType.COPILOT.instruction_filename).exists(), "Main instruction file should exist"


def test_claude_instructions_renamed():
    instructions_source = _get_source_instructions_path("microsoftInternal/NAV")

    with TemporaryDirectory() as tmpdir:
        repo_path = Path(tmpdir)
        entry = MagicMock(spec=DatasetEntry)
        entry.repo = "microsoftInternal/NAV"
        config = {"instructions": {"enabled": True}}

        result = setup_instructions_from_config(config, entry, repo_path, agent_type=AgentType.CLAUDE)
        assert result is True

        claude_dir = repo_path / ".claude"
        assert claude_dir.exists(), ".claude directory should be created"

        # AGENTS.md should be renamed to CLAUDE.md
        assert not (claude_dir / _config.file_patterns.instruction_source_naming).exists(), "Source file should be renamed"
        claude_md = claude_dir / AgentType.CLAUDE.instruction_filename
        assert claude_md.exists(), "CLAUDE.md should exist"

        # CLAUDE.md should start with the original AGENTS.md content and contain the inlined rules section
        source_content = (instructions_source / _config.file_patterns.instruction_source_naming).read_text(encoding="utf-8")
        claude_content = claude_md.read_text(encoding="utf-8")
        assert claude_content.startswith(source_content), "CLAUDE.md should start with source AGENTS.md content"
        assert "# Coding Rules (auto-loaded)" in claude_content, "CLAUDE.md should have inlined rules section"
        # Verify each rule file's body was inlined (check by filename mention in section headers)
        rules_dir = instructions_source / "rules"
        if rules_dir.exists():
            for rule_file in rules_dir.glob("*.md"):
                assert f"`{rule_file.name}`" in claude_content, f"Rule file {rule_file.name} should be referenced in inlined section"


def test_claude_agent_paths_rewritten():
    """Agent files copied for Claude runs should have `.github/` paths rewritten to `.claude/`.

    The ALDC source agent files (e.g. al-conductor-bench.md) hardcode
    `.github/plans/` and `.github/skills/` because they were authored for
    Copilot. When copied into `.claude/agents/` for Claude Code runs, the
    paths must be rewritten to `.claude/` or the conductor writes plan files
    to a non-existent directory and the orchestration silently fails.
    """
    with TemporaryDirectory() as tmpdir:
        repo_path = Path(tmpdir)
        entry = MagicMock(spec=DatasetEntry)
        entry.repo = "microsoft/BCApps"
        config = {
            "instructions": {"enabled": True},
            "agents": {"enabled": True, "name": "al-conductor-bench"},
        }

        # Full setup (instructions + custom agent) to place agents under .claude/
        setup_instructions_from_config(config, entry, repo_path, agent_type=AgentType.CLAUDE)
        custom_agent = setup_custom_agent(config, entry, repo_path, agent_type=AgentType.CLAUDE)
        assert custom_agent == "al-conductor-bench"

        claude_agents_dir = repo_path / ".claude" / "agents"
        assert claude_agents_dir.exists(), ".claude/agents should be populated"

        # The source conductor agent has many `.github/plans/` and `.github/skills/` refs.
        # After rewrite, zero instances of `.github/plans/` should remain in any agent file.
        for agent_file in claude_agents_dir.glob("*.md"):
            text = agent_file.read_text(encoding="utf-8")
            assert ".github/plans/" not in text, f"{agent_file.name} still contains .github/plans/ after rewrite"
            assert ".github/skills/" not in text, f"{agent_file.name} still contains .github/skills/ after rewrite"

        # And the conductor should now have `.claude/plans/` refs instead
        conductor_file = claude_agents_dir / "al-conductor-bench.md"
        if conductor_file.exists():
            conductor_text = conductor_file.read_text(encoding="utf-8")
            assert ".claude/plans/" in conductor_text, "Conductor should have rewritten .claude/plans/ refs"


def test_copilot_agent_paths_not_rewritten():
    """Copilot runs should leave `.github/` paths in agent files untouched."""
    with TemporaryDirectory() as tmpdir:
        repo_path = Path(tmpdir)
        entry = MagicMock(spec=DatasetEntry)
        entry.repo = "microsoft/BCApps"
        config = {
            "instructions": {"enabled": True},
            "agents": {"enabled": True, "name": "al-conductor-bench"},
        }

        setup_instructions_from_config(config, entry, repo_path, agent_type=AgentType.COPILOT)
        setup_custom_agent(config, entry, repo_path, agent_type=AgentType.COPILOT)

        github_agents_dir = repo_path / ".github" / "agents"
        assert github_agents_dir.exists(), ".github/agents should be populated"

        conductor_file = github_agents_dir / "al-conductor-bench.md"
        if conductor_file.exists():
            # Source file has .github/plans/ refs, should be preserved for Copilot
            conductor_text = conductor_file.read_text(encoding="utf-8")
            assert ".github/plans/" in conductor_text, "Copilot runs should preserve .github/plans/ refs"


def test_aldc_evidence_snapshot_after_full_setup():
    """build_aldc_evidence should record every file laid down with a SHA-256 hash."""
    with TemporaryDirectory() as tmpdir:
        repo_path = Path(tmpdir)
        entry = MagicMock(spec=DatasetEntry)
        entry.repo = "microsoft/BCApps"
        config = {
            "instructions": {"enabled": True},
            "skills": {"enabled": True},
            "agents": {"enabled": True, "name": "al-developer-bench"},
        }

        setup_instructions_from_config(config, entry, repo_path, agent_type=AgentType.CLAUDE)
        setup_agent_skills(config, entry, repo_path, agent_type=AgentType.CLAUDE)
        setup_custom_agent(config, entry, repo_path, agent_type=AgentType.CLAUDE)

        evidence = build_aldc_evidence(
            repo_path,
            AgentType.CLAUDE,
            agent_flag="al-developer-bench",
            instructions_enabled=True,
        )

        # Top-level shape
        assert evidence.target_dir == ".claude"
        assert evidence.agent_flag == "al-developer-bench"
        assert len(evidence.files) > 0, "Snapshot should contain files"

        # CLAUDE.md, at least one skill SKILL.md, and at least one agent .md must be present
        paths = {f.path for f in evidence.files}
        assert "CLAUDE.md" in paths, "CLAUDE.md should be recorded"
        assert any(p.startswith("skills/") and p.endswith("SKILL.md") for p in paths), "at least one skill should be present"
        assert any(p.startswith("agents/") and p.endswith(".md") for p in paths), "at least one agent should be present"

        # Every entry has a non-empty hash and a positive byte count
        for f in evidence.files:
            assert len(f.sha256) == 64, f"sha256 should be 64 hex chars, got {f.sha256!r}"
            assert f.bytes > 0, f"empty file recorded: {f.path}"

        # Rules-inlining workaround should have fired
        assert evidence.rules_inlined is True
        assert evidence.rules_inlined_count >= 1, "at least one rule should be inlined"

        # Path rewrite workaround should have fired (developer-bench mentions skills, conductor mentions plans)
        assert evidence.paths_rewritten is True


def test_aldc_evidence_empty_when_setup_skipped():
    """If instructions were never copied, evidence should be empty but valid."""
    with TemporaryDirectory() as tmpdir:
        repo_path = Path(tmpdir)
        evidence = build_aldc_evidence(
            repo_path,
            AgentType.CLAUDE,
            agent_flag=None,
            instructions_enabled=False,
        )
        assert evidence.target_dir == ".claude"
        assert evidence.agent_flag is None
        assert evidence.files == []
        assert evidence.rules_inlined is False
        assert evidence.rules_inlined_count == 0
        assert evidence.paths_rewritten is False
