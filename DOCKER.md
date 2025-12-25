# Docker Deployment Guide for Newspipe

This guide explains how to deploy Newspipe using Docker.

## Quick Start with Docker Compose

The easiest way to run Newspipe with Docker is using Docker Compose, which will set up both the application and a PostgreSQL database.

### Prerequisites

- Docker Engine (20.10 or later)
- Docker Compose (2.0 or later)

### Steps

1. **Clone the repository** (if you haven't already):
   ```bash
   git clone https://github.com/cedricbonhomme/newspipe
   cd newspipe
   ```

2. **Configure environment variables**:
   
   Create a `.env` file from the example:
   
   ```bash
   cp .env.example .env
   vim .env  # Edit and set strong passwords and secrets
   ```
   
   **Important**: Set strong values for:
   - `POSTGRES_PASSWORD` - Database password
   - `SECRET_KEY` - Flask application secret key
   - `SECURITY_PASSWORD_SALT` - Password hashing salt
   
   You can generate secure random values with:
   ```bash
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   ```

3. **Configure the application** (optional):
   
   The `instance/config.py` file works out of the box with docker-compose and reads from environment variables. 
   
   You can customize additional settings if needed:
   ```bash
   vim instance/config.py  # Edit as needed
   ```

4. **Build and start the containers**:
   ```bash
   docker-compose up -d
   ```

5. **Initialize the database** (first time only):
   ```bash
   docker-compose exec web flask db_create
   docker-compose exec web flask db_init
   ```

6. **Create an admin user** (first time only):
   ```bash
   docker-compose exec web flask create_admin --nickname admin --password YourSecurePassword
   ```

7. **Access Newspipe**:
   
   Open your browser and navigate to `http://localhost:5000`

### Managing the Application

- **View logs**:
  ```bash
  docker-compose logs -f web
  ```

- **Stop the application**:
  ```bash
  docker-compose stop
  ```

- **Start the application**:
  ```bash
  docker-compose start
  ```

- **Restart the application**:
  ```bash
  docker-compose restart web
  ```

- **Stop and remove containers**:
  ```bash
  docker-compose down
  ```

- **Stop and remove containers and volumes** (⚠️ This will delete all data):
  ```bash
  docker-compose down -v
  ```

### Updating Newspipe

To update to the latest version:

```bash
git pull origin master
docker-compose build
docker-compose up -d
docker-compose exec web flask db upgrade
docker-compose exec web pybabel compile -d newspipe/translations
```

### Feed Fetching

To automatically fetch feeds, you can either:

1. **Execute manually**:
   ```bash
   docker-compose exec web flask fetch_asyncio
   ```

2. **Set up a cron job** on your host machine:
   ```bash
   0 */3 * * * cd /path/to/newspipe && docker-compose exec -T web flask fetch_asyncio
   ```

## Using Docker without Docker Compose

If you prefer to use Docker directly without Docker Compose:

### Build the image

```bash
docker build -t newspipe:latest .
```

### Run with SQLite (simpler, for testing)

```bash
# Create a directory for data
mkdir -p $(pwd)/var $(pwd)/instance

# Run the container
docker run -d \
  --name newspipe \
  -p 5000:5000 \
  -v $(pwd)/instance:/app/instance \
  -v $(pwd)/var:/app/var \
  -e FLASK_APP=app.py \
  -e NEWSPIPE_CONFIG=sqlite.py \
  newspipe:latest

# Initialize the database (first time only)
docker exec -it newspipe flask db_create
docker exec -it newspipe flask db_init

# Create admin user (first time only)
docker exec -it newspipe flask create_admin --nickname admin --password YourPassword
```

### Run with PostgreSQL (recommended for production)

```bash
# Start PostgreSQL
docker run -d \
  --name newspipe-db \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=changeme \
  -e POSTGRES_DB=postgres \
  -v newspipe-postgres:/var/lib/postgresql/data \
  postgres:17-alpine

# Run Newspipe
docker run -d \
  --name newspipe \
  --link newspipe-db:db \
  -p 5000:5000 \
  -v $(pwd)/instance:/app/instance \
  -v $(pwd)/var:/app/var \
  -e FLASK_APP=app.py \
  -e NEWSPIPE_CONFIG=config.py \
  newspipe:latest

# Initialize the database (first time only)
docker exec -it newspipe flask db_create
docker exec -it newspipe flask db_init

# Create admin user (first time only)
docker exec -it newspipe flask create_admin --nickname admin --password YourPassword
```

## Production Deployment

For production deployments, consider the following:

### 1. Use a Reverse Proxy

Run Newspipe behind a reverse proxy like Nginx or Traefik:

- Handle HTTPS/TLS termination
- Serve static files
- Load balancing
- Rate limiting

### 2. Use a Production WSGI Server

Instead of Flask's development server, use Gunicorn:

```dockerfile
# In your docker-compose.yml or docker run command, override the CMD:
command: gunicorn --bind 0.0.0.0:5000 --workers 4 --timeout 120 app:application
```

You'll need to add `gunicorn` to your Python dependencies.

### 3. Environment Variables

Use environment variables for sensitive configuration:

```yaml
environment:
  - FLASK_APP=app.py
  - NEWSPIPE_CONFIG=config.py
  - SECRET_KEY=${SECRET_KEY}
  - DATABASE_URL=${DATABASE_URL}
```

### 4. Persistent Volumes

Ensure you're using named volumes or bind mounts for:
- Database data (`/var/lib/postgresql/data`)
- Application logs (`/app/var`)
- Instance configuration (`/app/instance`)

### 5. Regular Backups

Set up regular backups of your PostgreSQL database:

```bash
docker exec newspipe-db pg_dump -U postgres postgres > backup-$(date +%Y%m%d).sql
```

## Troubleshooting

### Container won't start

Check the logs:
```bash
docker-compose logs web
# or
docker logs newspipe
```

### Database connection issues

Ensure the database container is healthy:
```bash
docker-compose ps
# or
docker ps
```

Check PostgreSQL logs:
```bash
docker-compose logs db
```

### Permission issues

The application runs as user `newspipe` (UID 1000). Ensure mounted volumes have correct permissions:
```bash
sudo chown -R 1000:1000 ./var ./instance
```

### Import existing data

To import an OPML file:
```bash
docker-compose exec web flask import_opml /path/to/feeds.opml
```

## Security Considerations

- Always change default secrets (`SECRET_KEY`, `SECURITY_PASSWORD_SALT`, database passwords)
- Use strong passwords for admin accounts
- Keep Docker images updated
- Use HTTPS in production
- Regularly update Newspipe and its dependencies
- Review the security settings in your configuration file
- Consider using Docker secrets for sensitive data

## Advanced Configuration

For advanced configuration options, refer to the example configuration files:
- `instance/config.py` - PostgreSQL configuration
- `instance/sqlite.py` - SQLite configuration

You can create custom configuration files and mount them into the container.
