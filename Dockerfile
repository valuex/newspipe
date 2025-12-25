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

# Install Python dependencies directly from pyproject.toml using pip
# This avoids needing Poetry in the container
RUN pip install --no-cache-dir \
    "pyvulnerabilitylookup>=2.2.0" \
    "aiohttp>=3.11.2" \
    "requests>=2.32.5" \
    "chardet>=5.2.0" \
    "requests-futures>=1.0.2" \
    "beautifulsoup4>=4.12.3" \
    "lxml>=5.3.0" \
    "opml>=0.5" \
    "SQLAlchemy>=2.0.36" \
    "alembic>=1.14.0" \
    "Flask>=3.1.0" \
    "Flask-SQLAlchemy>=3.0.3" \
    "Flask-Login>=0.6.3" \
    "Flask-Principal>=0.4.0" \
    "Flask-WTF>=1.1.1" \
    "Flask-RESTful>=0.3.10" \
    "Flask-paginate>=2024.4.12" \
    "Flask-Babel>=4.0.0" \
    "Flask-Migrate>=3.0.1" \
    "WTForms>=3.1.1" \
    "python-dateutil>=2.8.2" \
    "psycopg2-binary>=2.9.10" \
    "flask-talisman>=1.1.0" \
    "feedparser>=6.0.12" \
    "mypy>=1.13.0" \
    "ldap3>=2.9.1" \
    "bleach>=6.2.0,<7.0.0"

# Compile translations
RUN pybabel compile -d newspipe/translations

# Stage 2: Runtime stage
FROM python:3.13-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
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

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:5000', timeout=5)" || exit 1

# Default command
# Note: Database must be initialized before first run. See README for details.
CMD ["flask", "run", "--host=0.0.0.0"]
