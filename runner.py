from pathlib import Path

from assistant import Assistant
from diff_generator import DiffGenerator


class Runner:
    def __init__(self, assistant: Assistant) -> None:
        self.assistant = assistant

    def generate(self, diff_to_analyze: str, instructions_file: str, model: str):
        return self.assistant.assist(
            instructions_file,
            diff_to_analyze,
            "Processing stagged diff changes...",
            "\n-> Remember you can always remove bigger changes from stagging and evaluate them afterwards.",
            model
        )
