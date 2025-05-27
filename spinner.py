import itertools
import threading
import time

import click


class Spinner:
    def __init__(self, text="Processing..."):
        self.spinner = itertools.cycle(["|", "/", "-", "\\"])
        self.text = click.style(text, fg="yellow")
        self.stop_running = False

    def start(self):
        """
        Start the spinner in a separate thread.
        """
        self.stop_running = False
        threading.Thread(target=self._spin, daemon=True).start()

    def _spin(self):
        """
        Spin until stopped.
        """
        while not self.stop_running:
            print(
                f"\r{self.text} {click.style(next(self.spinner), fg='yellow')}", end="", flush=True
            )
            time.sleep(0.1)
        print("\r", end="", flush=True)

    def stop(self):
        """
        Stop the spinner and clear the line.
        """
        self.stop_running = True
        time.sleep(0.1)
        print("\r" + " " * (len(self.text) + 1) + "\r", end="", flush=True)
