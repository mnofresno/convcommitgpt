# convcommitgpt

## What is it?

`convcommitgpt` is a CLI tool that analyzes changes made in a Git repository (via a diff) and automatically generates commit messages following the [Conventional Commits](https://www.conventionalcommits.org/) convention, using advanced language models (such as Ollama).

Its goal is to facilitate the creation of clear, precise, and standardized commit messages, improving the quality of the change history and team collaboration.

---

## Main Features

- **Automatic Git diff analysis:** Generates a summary of the changes made to the source code.
- **Conventional commit message generation:** Uses AI to create messages following the Conventional Commits standard.
- **Customizable instruction prompt:** Allows you to modify the `instructions_prompt.md` file to adapt the style and format of the generated messages.
- **Support for Ollama:** Uses local Ollama models for commit message generation.
- **Docker execution:** Runs inside a Docker container for easy setup and isolation.
- **Visual spinner:** Shows an animated spinner while processing the request to improve the CLI user experience.

---

## Installation

### Quick Install (Recommended)

You can install convcommitgpt using curl:

```bash
curl -sSL https://raw.githubusercontent.com/mnofresno/convcommitgpt/main/install.sh | bash
```

The installer will:
1. Check for required dependencies (Docker/Podman, Git, Ollama)
2. Create necessary directories
3. Build the Docker image
4. Set up configuration
5. Create the `convcommit` command

### Manual Installation

If you prefer to install manually:

1. Clone the repository:
```bash
git clone https://github.com/mnofresno/convcommitgpt.git
cd convcommitgpt
```

2. Run the installer:
```bash
chmod +x test_install.sh
./test_install.sh
```

### Uninstallation

To uninstall convcommitgpt:

```bash
curl -sSL https://raw.githubusercontent.com/mnofresno/convcommitgpt/main/uninstall.sh | bash
```

Or manually:
```bash
chmod +x uninstall.sh
./uninstall.sh
```

The uninstaller will:
1. Backup your configuration
2. Remove all installed files
3. Clean up system directories

---

## Configuration

The tool uses environment variables to configure Ollama. You can define them in a `.env` file in `~/.local/lib/convcommitgpt/.env`.

Main variables:
- `BASE_URL`: Base URL of the Ollama API (default: `http://host.docker.internal:11434/v1`).
- `MODEL`: Name of the Ollama model to use (default: `mistral`).

Example `.env`:
```
BASE_URL=http://host.docker.internal:11434/v1
MODEL=mistral
```

---

## Usage

### Basic Usage

1. Make sure you have staged changes in your Git repository.
2. Run:

```bash
convcommit .
```

Or specify a different repository path:

```bash
convcommit /path/to/repository
```

Main options:
- `--repository-path` or `-r`: Path to the Git repository.
- `--prompt-file` or `-p`: Instruction prompt file (default `instructions_prompt.md`).
- `--model` or `-m`: Model to use.
- `--base-url`: API endpoint.
- `--diff-from-stdin` or `-d`: Allows passing a diff directly via stdin.
- `--debug-diff` or `-dd`: Shows the analyzed diff.
- `--max-bytes-in-diff` or `-mb`: Byte limit to analyze per file.

### Docker execution

You can also use the `convcommit.sh` script directly:

```bash
./convcommit.sh /path/to/repository
```

Or pass a diff directly:

```bash
git diff --cached | ./convcommit.sh -d -
```

---

## Customizing the prompt

You can edit the `instructions_prompt.md` file to change the instructions received by the AI model. This allows you to adapt the style, format, and level of detail of the generated commit messages.

---

## Example of a generated message

```
fix(api): handle null pointer exceptions in user authentication

- Fixed null pointer exceptions in the authentication module.
- Updated error handling for improved stability.
```

---

## Additional notes

- `.env`, `.venv`, and temporary files should not be uploaded to the repository.
- The system ignores changes in critical files such as the assistant itself or the instruction prompt.
- If the diff is too large, it is truncated to avoid token limit errors.

---

## License

MIT