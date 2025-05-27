import logging
import re
import os

import click
from openai import OpenAI, OpenAIError
from openai.types import Completion

from spinner import Spinner
from pathlib import Path

logger = logging.getLogger(__name__)


class Assistant:
    def __init__(self, api_url: str, api_key: str, max_tokens: int = 8192):
        self.max_tokens = max_tokens
        self.openai_client = OpenAI(api_key=api_key, base_url=api_url)

    def _clean_output(self, text: str) -> str:
        # Remove think tags and their content
        text = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL)
        # Remove any remaining think tags without content
        text = re.sub(r'</?think>', '', text)
        # Remove any leading/trailing whitespace and newlines
        text = text.strip()
        return text

    def assist(
        self,
        instructions_path: str,
        user_input: str,
        spinner_message: str = "Processing...",
        after_failed_message: str = "",
        model_name: str|None = None,
        temperature: int = 0
    ) -> str:
        try:
            instructions = Path(instructions_path).read_text()
        except FileNotFoundError:
            click.secho(f"Error: The file at {instructions_path} was not found.")
            return ""

        verbose = os.getenv("VERBOSE", "false").lower() == "true"
        if verbose:
            logger.debug("Getting Models List...")

        spinner = Spinner(text=spinner_message)

        try:
            if model_name is None:
                models = self.openai_client.models.list()
                if verbose:
                    logger.debug(f"Model List: {models}")
                    logger.debug("Using completions API (no stream)...")
                model_name = models.data[0].id

            click.secho(f"Selected model: {model_name}")
            spinner.start()

            chat_prompt = [
                {"role": "system", "content": "You are a precise assistant that follows the instructions exactly as provided."},
                {"role": "user", "content": f"Instructions:\n\n{instructions}\n\nUser input:\n\n{user_input}"}
            ]

            completions: Completion = self.openai_client.chat.completions.create(
                model=model_name,
                messages=chat_prompt,
                stream=False,
                temperature=temperature,
                max_tokens=self.max_tokens,
            )
        except OpenAIError as e:
            click.secho(
                f"""

AI responded with a "{e}" error. :(
This usually indicates that the input is too large
or that the `skynet.max_tokens` config parameter is set too low.
Try reducing the input size or increasing the `skynet.max_tokens` value.
{after_failed_message}
                """,
                fg="magenta",
            )
            raise e
        finally:
            spinner.stop()

        completions_output = completions.choices[0].message.content
        if verbose:
            logger.debug(f"Response: '{completions_output}'")
        return self._clean_output(completions_output)
