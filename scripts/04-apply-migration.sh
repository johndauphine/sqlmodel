#!/bin/bash
# =============================================================================
# 04-apply-migration.sh
# Apply Alembic migration to PostgreSQL
# Idempotent: skips if already at head
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
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# -----------------------------------------------------------------------------
# Validate prerequisites
# -----------------------------------------------------------------------------
log "Checking prerequisites..."

if [[ ! -d "$WORK_DIR/alembic" ]]; then
    echo "ERROR: Alembic not initialized in $WORK_DIR"
    echo "Please run 02-init-alembic.sh first"
    exit 1
fi

MIGRATION_FILES=$(ls "$WORK_DIR/alembic/versions/"*.py 2>/dev/null | wc -l)
if [[ "$MIGRATION_FILES" -eq 0 ]]; then
    echo "ERROR: No migration files found"
    echo "Please run 03-create-migration.sh first"
    exit 1
fi

cd "$WORK_DIR"

# -----------------------------------------------------------------------------
# Activate virtual environment
# -----------------------------------------------------------------------------
log "Activating virtual environment..."
source venv/bin/activate

# -----------------------------------------------------------------------------
# Check if already at head
# -----------------------------------------------------------------------------
log "Checking migration status..."

CURRENT=$(alembic current 2>/dev/null | grep -oE '^[a-f0-9]+' || echo "none")
HEAD=$(alembic heads 2>/dev/null | grep -oE '^[a-f0-9]+' || echo "none")

log "Current revision: $CURRENT"
log "Head revision: $HEAD"

if [[ "$CURRENT" == "$HEAD" && "$HEAD" != "none" ]]; then
    log "Already at head - no migrations to apply"

    # Still verify tables exist
    log "Verifying tables in dbo schema..."
    export PGPASSWORD="$PG_PASSWORD"
    TABLES_RESULT=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" \
        -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'dbo' ORDER BY table_name;" 2>/dev/null)
    unset PGPASSWORD

    if [[ -n "$TABLES_RESULT" ]]; then
        log "Tables in dbo schema:"
        echo "$TABLES_RESULT" | while read -r table; do
            if [[ -n "$table" ]]; then
                echo "  - $table"
            fi
        done
    fi

    deactivate
    log "Step 4 complete: Already up to date"
    exit 0
fi

# -----------------------------------------------------------------------------
# Generate DDL SQL
# -----------------------------------------------------------------------------
DDL_FILE="migration_$(date '+%Y%m%d_%H%M%S').sql"
log "Generating DDL SQL: $DDL_FILE"
alembic upgrade head --sql > "$DDL_FILE"
log "DDL SQL saved to: $WORK_DIR/$DDL_FILE"

# -----------------------------------------------------------------------------
# Apply migration
# -----------------------------------------------------------------------------
log "Applying migration to PostgreSQL..."
alembic upgrade head

# -----------------------------------------------------------------------------
# Verify migration
# -----------------------------------------------------------------------------
log "Verifying migration..."

NEW_REVISION=$(alembic current 2>/dev/null | head -1)
log "Current revision: $NEW_REVISION"

# -----------------------------------------------------------------------------
# List created tables
# -----------------------------------------------------------------------------
log "Verifying tables in dbo schema..."

export PGPASSWORD="$PG_PASSWORD"
TABLES_RESULT=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" \
    -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'dbo' ORDER BY table_name;" 2>/dev/null)
unset PGPASSWORD

if [[ -n "$TABLES_RESULT" ]]; then
    log "Tables created in dbo schema:"
    echo "$TABLES_RESULT" | while read -r table; do
        if [[ -n "$table" ]]; then
            echo "  - $table"
        fi
    done
else
    echo "WARNING: No tables found in dbo schema"
fi

deactivate
log "Step 4 complete: Migration applied"
log "DDL SQL file: $WORK_DIR/$DDL_FILE"
