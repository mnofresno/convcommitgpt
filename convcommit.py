#!/usr/bin/env python3

from io import TextIOWrapper
import os
import click
from pathlib import Path
from assistant import Assistant
from diff_generator import DiffGenerator
from dotenv import load_dotenv
from runner import Runner

env_file = Path(__file__).parent.resolve() / '.env'

load_dotenv(env_file)

@click.command()
@click.option('--repository-path', '-r', required=False, type=click.Path(exists=True, file_okay=False, resolve_path=True), default=os.getenv("REPO_PATH", "."), help="Path to the Git repository")
@click.option('--diff-from-stdin', '-d', required=False, type=click.File('r'), default=None, help="Pass directly the git diff from stdin")
@click.option('--prompt-file', '-p', default='instructions_prompt.md', type=click.Path(exists=True, dir_okay=False), help="Instructions prompt file")
@click.option('--model', '-m', default=os.getenv("MODEL", "gpt-4o-mini"), help="AI model to use")
@click.option('--openai-api-key', '-k', default=os.getenv("OPENAI_API_KEY", "no-api-key"), help="OpenAI API Key")
@click.option('--base-url', default=os.getenv("BASE_URL", "https://api.openai.com/v1"), help="Base URL for the OpenAI API")
@click.option('--debug-diff', '-dd', flag_value=True, help="Show debugging git diff used to analyze")
@click.option('--max-bytes-in-diff', '-mb', default=1024, help="Max number of bytes to analyze a file from git diff")
def main(
    repository_path: Path|None,
    prompt_file: Path|None,
    model:str|None,
    openai_api_key:str,
    base_url:str,
    diff_from_stdin: TextIOWrapper|None,
    debug_diff: bool = False,
    max_bytes_in_diff: int = 1024
):
    if ((not repository_path) and (not diff_from_stdin)):
        click.echo("Error: repository_path or direct_diff_as_input variable is not set or is not a valid directory.")
        exit(1)

    if diff_from_stdin is None and repository_path is not None :
        diff_generator = DiffGenerator(max_bytes_in_diff)
        diff_to_analyze = diff_generator.generate(Path(repository_path).resolve())
    else:
        diff_to_analyze = diff_from_stdin.read()

    assistant = Assistant(api_url=base_url, api_key=openai_api_key)
    runner = Runner(assistant)
    commit_message = runner.generate(diff_to_analyze, prompt_file, model)
    if (debug_diff):
        click.secho(f"Received diff: {diff_to_analyze}", fg="green")
    click.echo("-> Commit Message:")
    click.echo(commit_message)

if __name__ == "__main__":
    main()
