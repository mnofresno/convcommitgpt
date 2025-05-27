FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    curl \
    procps \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv

# Activate virtual environment and install dependencies
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir \
    click==8.1.7 \
    openai>=1.12.0 \
    gitpython==3.1.43 \
    python-dotenv==1.0.1

# Set environment variables for timeouts and compatibility
ENV OPENAI_TIMEOUT=300
ENV HTTPX_TIMEOUT=300
ENV MAX_TOKENS=4096
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV OLLAMA_HOST=host.docker.internal
ENV OLLAMA_PORT=11434

# Create a non-root user
RUN useradd -m -u 1000 appuser

# Copy all files
COPY . /app/

# Set proper permissions
RUN chown -R appuser:appuser /app && \
    chmod -R 755 /app

# Switch to non-root user
USER appuser

# Set the entrypoint to use the virtual environment
ENTRYPOINT ["/opt/venv/bin/python", "convcommit.py"]
