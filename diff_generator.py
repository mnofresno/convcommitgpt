import re
import subprocess
from importlib import util
from pathlib import Path

import click
from git import GitCommandError, Repo

from assistant import Assistant

assistant_module = util.find_spec(Assistant.__module__)
assistant_path = assistant_module.origin if assistant_module else ""


class DiffGenerator:
    blacklist = [assistant_path, "instructions_prompt.md"]

    def __init__(self, max_diff_size: int = 1024) -> None:
        self.max_diff_size = max_diff_size

    def generate(self, repo_path: Path) -> str:
        max_diff_size = self.max_diff_size
        try:
            repo = Repo(repo_path)
            if repo.bare:
                raise ValueError(
                    "The provided path is a bare repository or not a valid Git repository."
                )

            diffs = repo.git.diff("--cached", "--name-status").splitlines()
            result = []

            for diff in diffs:
                parts = re.split(r"\t+", diff, maxsplit=2)
                status, file = (parts[0][0], parts[-1])
                if any(file in blacklisted_file for blacklisted_file in self.blacklist):
                    result.append(f"* Changes to {file} were made")
                    continue

                if status == "D":
                    result.append(f"* file: {file} was deleted")
                else:
                    file_diff = repo.git.diff("--cached", file)
                    if max_diff_size != 0 and len(file_diff.encode("utf-8")) > max_diff_size:
                        result.append(
                            f"Diff for {file} is too large, truncated:\n{file_diff[:max_diff_size]}... [truncated up to {max_diff_size} bytes]\n"
                        )
                    else:
                        result.append(file_diff)

            return "\n".join(result)

        except GitCommandError as e:
            click.secho(e)
            return f"Error generating diff: {e}"

    def open_for_edit(self, repo_path: Path, message: str) -> str:
        try:
            repo = Repo(repo_path)
            if repo.bare:
                raise ValueError(
                    "The provided path is a bare repository or not a valid Git repository."
                )
            if not repo.is_dirty(index=True, working_tree=False):
                raise ValueError("No changes are staged for commit.")
            subprocess.run(
                ["git", "-C", str(repo_path), "commit", "--edit", "-m", message], check=True
            )
            return "Commit editor opened successfully."
        except GitCommandError as e:
            click.secho(e)
            return f"Error opening commit editor: {e}"
        except Exception as e:
            click.secho(e)
            return f"Error: {e}"
