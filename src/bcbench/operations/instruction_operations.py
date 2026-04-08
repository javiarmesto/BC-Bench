from pathlib import Path
from shutil import copytree, rmtree

from bcbench.config import get_config
from bcbench.dataset import DatasetEntry
from bcbench.logger import get_logger
from bcbench.types import AgentType

logger = get_logger(__name__)
_config = get_config()


def setup_instructions_from_config(agent_config: dict, entry: DatasetEntry, repo_path: Path, agent_type: AgentType) -> bool:
    """
    Setup custom instructions from config if enabled.

    Args:
        agent_config: Agent configuration dictionary
        entry: Dataset entry containing repo information
        repo_path: Path to repository where instructions will be copied
        agent_type: Type of agent (Copilot or Claude)

    Returns:
        True if instructions are enabled, False otherwise
    """
    instructions_config: dict = agent_config["instructions"]
    instructions_enabled: bool = instructions_config["enabled"]

    if instructions_enabled:
        source_instructions: Path = _get_source_instructions_path(entry.repo)
        target_dir: Path = agent_type.get_target_dir(repo_path)

        logger.info(f"Setting up custom instructions for repository: {entry.repo}")
        if target_dir.exists():
            rmtree(target_dir)
        copytree(source_instructions, target_dir)

        # Rename canonical instruction file to agent-specific name
        canonical = target_dir / _config.file_patterns.instruction_source_naming
        expected = target_dir / agent_type.instruction_filename
        if canonical.exists() and canonical != expected:
            canonical.rename(expected)
            logger.info(f"Renamed {canonical.name} -> {expected.name}")

        # Inline coding rules into the root instructions file.
        # Neither Claude Code nor Copilot CLI auto-loads `rules/*.md`, so without
        # this inlining the 8 coding standards would never reach the model.
        # The rules are concatenated as a single "Coding Rules (auto-loaded)"
        # section at the bottom of CLAUDE.md / copilot-instructions.md.
        _inline_rules_into_root_instructions(target_dir, expected)

        logger.info(f"{target_dir.name} dir is overwritten with {source_instructions}")

    return instructions_enabled


def setup_custom_agent(agent_config: dict, entry: DatasetEntry, repo_path: Path, agent_type: AgentType) -> str | None:
    """
    Setup custom agents in the repository if available.
    """
    custom_agent_config: dict = agent_config["agents"]
    custom_agent_enabled: bool = custom_agent_config["enabled"]

    if custom_agent_enabled:
        source_instructions: Path = _get_source_instructions_path(entry.repo)
        target_dir: Path = agent_type.get_target_dir(repo_path)
        copytree(source_instructions / "agents", target_dir / "agents", dirs_exist_ok=True)

        # Rewrite hardcoded `.github/` references in agent markdown files to
        # match the target agent's runtime directory. The ALDC source files
        # are authored with `.github/plans/` and `.github/skills/` paths
        # (conductor writes plan files, developer loads skills), which break
        # when copied into `.claude/` for Claude Code runs.
        _rewrite_agent_paths(target_dir / "agents", agent_type)

        logger.info(f"Custom agents are set up from {source_instructions / 'agents'}")
        return custom_agent_config.get("name")

    return None


def _inline_rules_into_root_instructions(target_dir: Path, root_instructions_file: Path) -> None:
    """Concatenate all rules/*.md into the root instructions file.

    The ALDC rules are designed for VS Code Copilot's auto-apply mechanism
    (`paths:` frontmatter), which neither Claude Code nor Copilot CLI honors.
    To ensure the 8 coding standards actually reach the model, this function
    strips each rule file's YAML frontmatter and appends the body to
    CLAUDE.md / copilot-instructions.md under a "Coding Rules" section.
    """
    rules_dir = target_dir / "rules"
    if not rules_dir.exists() or not root_instructions_file.exists():
        logger.debug(f"Skipping rules inlining: rules={rules_dir.exists()}, root={root_instructions_file.exists()}")
        return

    rule_files = sorted(rules_dir.glob("*.md"))
    if not rule_files:
        logger.debug(f"No rule files found in {rules_dir}")
        return

    sections: list[str] = [
        "\n\n---\n\n# Coding Rules (auto-loaded)\n",
        (
            "> These rules are mandatory for all AL code in this repository. "
            "They were inlined from the ALDC `rules/` directory because neither "
            "Claude Code nor Copilot CLI auto-loads `rules/*.md` via frontmatter.\n"
        ),
    ]

    for rule_file in rule_files:
        body = _strip_yaml_frontmatter(rule_file.read_text(encoding="utf-8"))
        sections.append(f"\n## Rule file: `{rule_file.name}`\n\n{body.strip()}\n")

    with root_instructions_file.open("a", encoding="utf-8") as f:
        f.write("".join(sections))

    logger.info(f"Inlined {len(rule_files)} rule file(s) into {root_instructions_file.name}")


def _strip_yaml_frontmatter(text: str) -> str:
    """Remove a leading YAML frontmatter block (delimited by ---) if present."""
    if not text.startswith("---"):
        return text
    lines = text.splitlines()
    # Find the closing `---` on a line by itself
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return "\n".join(lines[i + 1 :]).lstrip("\n")
    return text  # malformed frontmatter, return as-is


def _rewrite_agent_paths(agents_dir: Path, agent_type: AgentType) -> None:
    """Rewrite hardcoded `.github/` path references in agent markdown files.

    For Claude runs, `.github/plans/` and `.github/skills/` are replaced with
    `.claude/plans/` and `.claude/skills/`. For Copilot runs this is a no-op
    (the source files already use `.github/`).
    """
    if agent_type != AgentType.CLAUDE:
        return

    if not agents_dir.exists():
        return

    replacements = {
        ".github/plans/": ".claude/plans/",
        ".github/skills/": ".claude/skills/",
        ".github/agents/": ".claude/agents/",
        ".github/instructions/": ".claude/instructions/",
    }

    rewritten_count = 0
    for agent_file in agents_dir.glob("*.md"):
        original = agent_file.read_text(encoding="utf-8")
        patched = original
        for old, new in replacements.items():
            patched = patched.replace(old, new)
        if patched != original:
            agent_file.write_text(patched, encoding="utf-8")
            rewritten_count += 1

    if rewritten_count:
        logger.info(f"Rewrote .github -> .claude paths in {rewritten_count} agent file(s) under {agents_dir}")


def _get_source_instructions_path(repo_name: str) -> Path:
    """
    Get path to source instruction folder for a repository.

    Instructions are stored in shared/instructions/ and used by both Copilot and Claude.

    Raises:
        FileNotFoundError: If instruction file doesn't exist
    """
    sanitized_name = repo_name.replace("/", "-")
    instructions_path = _config.paths.agent_share_dir / _config.file_patterns.instructions_dirname / sanitized_name

    if not instructions_path.exists():
        raise FileNotFoundError(f"Instruction folder not found: {instructions_path}\nExpected for repository: {repo_name}")

    return instructions_path


def copy_problem_statement_folder(entry: DatasetEntry, repo_path: Path) -> None:
    """
    Copy problem statement folder to the testbed repository root.

    This makes the problem statement (including any screenshots) accessible to Copilot during evaluation.

    Args:
        entry: Dataset entry containing problem_statement path
        repo_path: Path to testbed repository where folder will be copied
    """
    source_dir: Path = entry.problem_statement_dir
    dest_dir: Path = repo_path / _config.file_patterns.problem_statement_dest_dir

    if dest_dir.exists():
        rmtree(dest_dir)

    copytree(source_dir, dest_dir)
    logger.info(f"Copied problem statement folder from {source_dir} to {dest_dir}")
