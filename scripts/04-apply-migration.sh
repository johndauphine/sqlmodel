#!/bin/bash
# =============================================================================
# 04-apply-migration.sh
# Apply Alembic migration to PostgreSQL
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
# Show current migration status
# -----------------------------------------------------------------------------
log "Current Alembic status:"
alembic current 2>/dev/null || echo "  (no migrations applied yet)"

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
