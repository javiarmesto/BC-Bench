import hashlib
from pathlib import Path
from shutil import copy2, copytree, rmtree

from bcbench.config import get_config
from bcbench.dataset import DatasetEntry
from bcbench.logger import get_logger
from bcbench.types import ALDCEvidence, ALDCFileEntry, AgentType

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

    If `agents.profiles[agents.name].include` is a non-empty list, only those
    agent files are copied into <target>/agents/. This keeps BCApps bug-fix
    runs focused on the single agent (al-developer-bench) or the conductor
    + 3 subagents bundle, instead of the full 11-agent ALDC library.

    Absent profile or absent include => legacy copy-all behavior (preserves
    the NAV path and any scenario that does not define a profile).
    """
    custom_agent_config: dict = agent_config["agents"]
    custom_agent_enabled: bool = custom_agent_config["enabled"]

    if custom_agent_enabled:
        source_instructions: Path = _get_source_instructions_path(entry.repo)
        target_dir: Path = agent_type.get_target_dir(repo_path)
        source_agents_dir: Path = source_instructions / "agents"
        target_agents_dir: Path = target_dir / "agents"

        agent_name: str = custom_agent_config["name"]
        profiles: dict = custom_agent_config.get("profiles") or {}
        include: list[str] | None = (profiles.get(agent_name) or {}).get("include")

        if include:
            target_agents_dir.mkdir(parents=True, exist_ok=True)
            copied: list[str] = []
            for name in include:
                src_file = source_agents_dir / name
                if not src_file.is_file():
                    logger.warning(f"Agent file in profile '{agent_name}' not found, skipping: {src_file}")
                    continue
                copy2(src_file, target_agents_dir / name)
                copied.append(name)
            logger.info(f"Custom agents copied for profile '{agent_name}' ({len(copied)}): {copied}")
        else:
            copytree(source_agents_dir, target_agents_dir, dirs_exist_ok=True)
            logger.info(f"Custom agents are set up from {source_agents_dir} (copy-all)")

        # Rewrite hardcoded `.github/` references in agent markdown files to
        # match the target agent's runtime directory. The ALDC source files
        # are authored with `.github/plans/` and `.github/skills/` paths
        # (conductor writes plan files, developer loads skills), which break
        # when copied into `.claude/` for Claude Code runs.
        _rewrite_agent_paths(target_agents_dir, agent_type)

        return agent_name

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


def build_aldc_evidence(
    repo_path: Path,
    agent_type: AgentType,
    *,
    agent_flag: str | None,
    instructions_enabled: bool,
) -> ALDCEvidence:
    """Snapshot the ALDC files placed in the testbed for audit purposes.

    Walks the agent's target directory (`.claude/` or `.github/`) and computes
    a SHA-256 hash of every file. The result is stored alongside the run so a
    reviewer can later prove which exact ALDC bytes the model was given —
    instead of having to trust that the boolean flags in
    ExperimentConfiguration reflect what actually landed on disk.

    Returns an ALDCEvidence with `files=[]` if the target dir does not exist
    (instructions disabled, or evidence collected before setup ran).
    """
    target_dir: Path = agent_type.get_target_dir(repo_path)

    files: list[ALDCFileEntry] = []
    rules_inlined = False
    rules_inlined_count = 0
    paths_rewritten = False

    if target_dir.exists() and target_dir.is_dir():
        for file_path in sorted(target_dir.rglob("*")):
            if not file_path.is_file():
                continue
            try:
                data = file_path.read_bytes()
            except OSError as e:
                logger.warning(f"Could not read {file_path} for ALDC evidence: {e}")
                continue
            files.append(
                ALDCFileEntry(
                    path=str(file_path.relative_to(target_dir)).replace("\\", "/"),
                    sha256=hashlib.sha256(data).hexdigest(),
                    bytes=len(data),
                )
            )

        # Detect whether the rules-inlining workaround actually fired
        root_instructions = target_dir / agent_type.instruction_filename
        if root_instructions.exists():
            try:
                root_text = root_instructions.read_text(encoding="utf-8")
                if "# Coding Rules (auto-loaded)" in root_text:
                    rules_inlined = True
                    rules_inlined_count = root_text.count("\n## Rule file: `")
            except OSError:
                pass

        # Detect whether the .github -> .claude path rewrite was applied
        if agent_type == AgentType.CLAUDE:
            agents_dir = target_dir / "agents"
            if agents_dir.exists():
                rewritten = False
                for agent_file in agents_dir.glob("*.md"):
                    try:
                        body = agent_file.read_text(encoding="utf-8")
                        if ".claude/plans/" in body or ".claude/skills/" in body:
                            rewritten = True
                            break
                    except OSError:
                        continue
                paths_rewritten = rewritten

    if not files and instructions_enabled:
        logger.warning(
            f"ALDC evidence is empty but instructions were enabled — target dir {target_dir} missing or unreadable"
        )

    return ALDCEvidence(
        target_dir=target_dir.name,
        agent_flag=agent_flag,
        rules_inlined=rules_inlined,
        rules_inlined_count=rules_inlined_count,
        paths_rewritten=paths_rewritten,
        files=files,
    )
