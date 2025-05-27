FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv

# Activate virtual environment and install dependencies
SHELL ["/bin/bash", "-c"]
RUN source /opt/venv/bin/activate && \
    pip install --no-cache-dir \
    click==8.1.7 \
    openai>=1.12.0 \
    gitpython==3.1.43 \
    python-dotenv==1.0.1

# Copy all files
COPY . /app/

# Set proper permissions
RUN chmod -R 755 /app

# Create activation script
RUN echo '#!/bin/bash\nsource /opt/venv/bin/activate\nexec "$@"' > /usr/local/bin/venv-activate && \
    chmod +x /usr/local/bin/venv-activate

# Set the entrypoint to use the virtual environment
ENTRYPOINT ["/usr/local/bin/venv-activate", "python", "convcommit.py"]
