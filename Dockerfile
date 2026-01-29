FROM python:3.13-slim

WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Install dependencies
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

# Copy FTP server code
COPY server.py .

# Create temporary upload directory
RUN mkdir -p /tmp/ftp_uploads

# Expose FTP port
EXPOSE 2121

# Expose passive mode port range (optional)
EXPOSE 60000-60100

# Run FTP server
CMD ["uv", "run", "server.py"]
# CMD ["sleep", "infinity"]
