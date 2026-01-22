#!/bin/bash
# =============================================================================
# 02-init-alembic.sh
# Initialize Alembic for PostgreSQL migration
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Load configuration
# -----------------------------------------------------------------------------
if [[ ! -f "$SCRIPT_DIR/config.env" ]]; then
    echo "ERROR: config.env not found"
    exit 1
fi

source "$SCRIPT_DIR/config.env"

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
urlencode() {
    python3 -c "import urllib.parse; print(urllib.parse.quote('$1', safe=''))"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# -----------------------------------------------------------------------------
# Validate prerequisites
# -----------------------------------------------------------------------------
log "Checking prerequisites..."

if [[ ! -d "$WORK_DIR" ]]; then
    echo "ERROR: Working directory not found: $WORK_DIR"
    echo "Please run 01-generate-models.sh first"
    exit 1
fi

if [[ ! -f "$WORK_DIR/models.py" ]]; then
    echo "ERROR: models.py not found in $WORK_DIR"
    echo "Please run 01-generate-models.sh first"
    exit 1
fi

if ! command -v psql &> /dev/null; then
    echo "ERROR: psql is required but not installed"
    exit 1
fi

cd "$WORK_DIR"

# -----------------------------------------------------------------------------
# Activate virtual environment
# -----------------------------------------------------------------------------
log "Activating virtual environment..."
source venv/bin/activate

# -----------------------------------------------------------------------------
# Install Alembic dependencies
# -----------------------------------------------------------------------------
log "Installing Alembic and PostgreSQL driver..."
pip install --quiet alembic sqlalchemy psycopg2-binary

# -----------------------------------------------------------------------------
# Initialize Alembic (if not already initialized)
# -----------------------------------------------------------------------------
if [[ ! -d "alembic" ]]; then
    log "Initializing Alembic..."
    alembic init alembic
else
    log "Alembic already initialized, updating configuration..."
fi

# -----------------------------------------------------------------------------
# Build PostgreSQL connection string
# -----------------------------------------------------------------------------
ENCODED_PG_PASSWORD=$(urlencode "$TARGET_PG_PASSWORD")
PG_URL="postgresql://${TARGET_PG_USER}:${ENCODED_PG_PASSWORD}@${TARGET_PG_HOST}:${TARGET_PG_PORT}/${TARGET_PG_DATABASE}"

# For alembic.ini, escape % as %%
PG_URL_INI=$(echo "$PG_URL" | sed 's/%/%%/g')

log "Target PostgreSQL connection: ${TARGET_PG_USER}@${TARGET_PG_HOST}:${TARGET_PG_PORT}/${TARGET_PG_DATABASE}"

# -----------------------------------------------------------------------------
# Update alembic.ini with PostgreSQL connection
# -----------------------------------------------------------------------------
log "Updating alembic.ini..."

# Replace the sqlalchemy.url line
sed -i "s|^sqlalchemy.url = .*|sqlalchemy.url = $PG_URL_INI|" alembic.ini

# -----------------------------------------------------------------------------
# Update alembic/env.py to import models
# -----------------------------------------------------------------------------
log "Updating alembic/env.py..."

# Create the updated env.py
cat > alembic/env.py << 'ENVPY'
from logging.config import fileConfig
import sys
from pathlib import Path

from sqlalchemy import engine_from_config
from sqlalchemy import pool

from alembic import context

# Add parent directory to path to import models
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from models import Base

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Interpret the config file for Python logging.
# This line sets up loggers basically.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# add your model's MetaData object here
# for 'autogenerate' support
target_metadata = Base.metadata

# other values from the config, defined by the needs of env.py,
# can be acquired:
# my_important_option = config.get_main_option("my_important_option")
# ... etc.


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    This configures the context with just a URL
    and not an Engine, though an Engine is acceptable
    here as well.  By skipping the Engine creation
    we don't even need a DBAPI to be available.

    Calls to context.execute() here emit the given string to the
    script output.

    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_schemas=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode.

    In this scenario we need to create an Engine
    and associate a connection with the context.

    """
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            include_schemas=True,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
ENVPY

# -----------------------------------------------------------------------------
# Derive target schema name: dw__<database>__<schema> (lowercase)
# -----------------------------------------------------------------------------
TARGET_SCHEMA="dw__${SOURCE_PG_DATABASE,,}__${SOURCE_PG_SCHEMA,,}"
log "Target PostgreSQL schema: $TARGET_SCHEMA"

# -----------------------------------------------------------------------------
# Create target schema in PostgreSQL
# -----------------------------------------------------------------------------
log "Creating schema '$TARGET_SCHEMA' in PostgreSQL..."

export PGPASSWORD="$TARGET_PG_PASSWORD"
psql -h "$TARGET_PG_HOST" -p "$TARGET_PG_PORT" -U "$TARGET_PG_USER" -d "$TARGET_PG_DATABASE" \
    -c "CREATE SCHEMA IF NOT EXISTS $TARGET_SCHEMA;" 2>/dev/null || {
    echo "WARNING: Could not create $TARGET_SCHEMA schema (it may already exist)"
}
unset PGPASSWORD

deactivate
log "Step 2 complete: Alembic initialized"
