# Multi-stage Dockerfile for Newspipe

# Stage 1: Build stage
FROM python:3.13-slim AS builder

# Install system dependencies and Node.js
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libpq-dev \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy all files
COPY . .

# Install Node.js dependencies
RUN npm ci

# Create symlink for npm components
RUN cd newspipe/static && ln -sf ../../node_modules npm_components

# Install Python dependencies from pyproject.toml
# Using pip to install the package in editable mode reads from pyproject.toml
# This keeps dependencies in sync with the project definition
RUN pip install --no-cache-dir -e .

# Compile translations
RUN pybabel compile -d newspipe/translations

# Stage 2: Runtime stage
FROM python:3.13-slim

# Install runtime dependencies including wget for health checks
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -m -u 1000 -s /bin/bash newspipe

# Set working directory
WORKDIR /app

# Copy installed packages and application from builder
COPY --from=builder /usr/local/lib/python3.13/site-packages /usr/local/lib/python3.13/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /app /app

# Create necessary directories and set permissions
RUN mkdir -p /app/var && \
    chown -R newspipe:newspipe /app

# Switch to app user
USER newspipe

# Expose port
EXPOSE 5000

# Set environment variables
ENV FLASK_APP=app.py \
    NEWSPIPE_CONFIG=sqlite.py \
    PYTHONUNBUFFERED=1

# Health check - using wget which is lighter than requests
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:5000 || exit 1

# Default command
# Note: Database must be initialized before first run. See README for details.
CMD ["flask", "run", "--host=0.0.0.0"]
