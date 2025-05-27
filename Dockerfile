FROM --platform=$BUILDPLATFORM python:3.12

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Set environment variables for timeouts and compatibility
ENV OPENAI_TIMEOUT=300
ENV HTTPX_TIMEOUT=300
ENV MAX_TOKENS=4096
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV OLLAMA_HOST=host.docker.internal
ENV OLLAMA_PORT=11434

# Copy application files
COPY *.py ./
COPY *.md ./

# Set the entrypoint
ENTRYPOINT ["python", "convcommit.py"]
