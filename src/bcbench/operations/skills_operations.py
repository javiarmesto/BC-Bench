from pathlib import Path
from shutil import copytree, rmtree

from bcbench.dataset.dataset_entry import DatasetEntry
from bcbench.logger import get_logger
from bcbench.operations.instruction_operations import _get_source_instructions_path
from bcbench.types import AgentType

logger = get_logger(__name__)


def setup_agent_skills(agent_config: dict, entry: DatasetEntry, repo_path: Path, agent_type: AgentType) -> bool:
    """
    Setup skills in the repository if available.

    If `skills.include` is a non-empty list, only those skill folders are
    copied into <target>/skills/. Absent include => legacy copy-all behavior
    (preserves any scenario that does not declare a whitelist, including NAV).

    Returns:
        True if skills were copied, False if skills are disabled.
    """
    skills_config: dict = agent_config["skills"]
    skills_enabled: bool = skills_config["enabled"]

    if skills_enabled:
        source_skills: Path = _get_source_instructions_path(entry.repo)
        source_skills_dir = source_skills / "skills"

        # Skip if skills folder doesn't exist for this repo
        if not source_skills_dir.exists():
            raise FileNotFoundError(f"Skills folder not found for repository: {entry.repo} at {source_skills_dir}")

        # Copilot reads from .github automatically, Claude reads from .claude automatically
        target_dir: Path = agent_type.get_target_dir(repo_path)
        skills_dir = target_dir / "skills"

        # Remove existing skills directory to ensure clean state
        if skills_dir.exists():
            rmtree(skills_dir)

        skills_include: list[str] | None = skills_config.get("include")
        if skills_include:
            skills_dir.mkdir(parents=True, exist_ok=True)
            copied: list[str] = []
            for name in skills_include:
                src = source_skills_dir / name
                if not src.is_dir():
                    logger.warning(f"Skill folder not found, skipping: {src}")
                    continue
                copytree(src, skills_dir / name)
                copied.append(name)
            logger.info(f"Skills copied ({len(copied)}): {copied}")
        else:
            copytree(source_skills_dir, skills_dir)
            logger.info(f"Skills copied from {source_skills_dir} to {skills_dir} (copy-all)")
    return skills_enabled
