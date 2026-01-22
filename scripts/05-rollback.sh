#!/bin/bash
# =============================================================================
# 05-rollback.sh
# Rollback Alembic migration
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
# Derive target schema name: dw__<database>__<schema> (lowercase)
# -----------------------------------------------------------------------------
TARGET_SCHEMA="dw__${MSSQL_DATABASE,,}__${MSSQL_SCHEMA,,}"

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
ROLLBACK_TARGET="${1:-base}"
DROP_SCHEMA="${2:-no}"

# -----------------------------------------------------------------------------
# Validate prerequisites
# -----------------------------------------------------------------------------
log "Checking prerequisites..."

if [[ ! -d "$WORK_DIR/alembic" ]]; then
    echo "ERROR: Alembic not initialized in $WORK_DIR"
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
CURRENT_REVISION=$(alembic current 2>/dev/null | head -1)
if [[ -z "$CURRENT_REVISION" ]]; then
    echo "  (no migrations applied)"
    log "Nothing to rollback"
    deactivate
    exit 0
fi
echo "  $CURRENT_REVISION"

# -----------------------------------------------------------------------------
# Show migration history
# -----------------------------------------------------------------------------
log "Migration history:"
alembic history --verbose 2>/dev/null | head -20

# -----------------------------------------------------------------------------
# Perform rollback
# -----------------------------------------------------------------------------
if [[ "$ROLLBACK_TARGET" == "base" ]]; then
    log "Rolling back all migrations..."
    alembic downgrade base
elif [[ "$ROLLBACK_TARGET" =~ ^-[0-9]+$ ]]; then
    log "Rolling back $ROLLBACK_TARGET revision(s)..."
    alembic downgrade "$ROLLBACK_TARGET"
else
    log "Rolling back to revision: $ROLLBACK_TARGET"
    alembic downgrade "$ROLLBACK_TARGET"
fi

# -----------------------------------------------------------------------------
# Verify rollback
# -----------------------------------------------------------------------------
log "Rollback complete"
log "Current Alembic status:"
alembic current 2>/dev/null || echo "  (no migrations applied)"

# -----------------------------------------------------------------------------
# Optionally drop the schema
# -----------------------------------------------------------------------------
if [[ "$DROP_SCHEMA" == "yes" || "$DROP_SCHEMA" == "--drop-schema" ]]; then
    log "Dropping $TARGET_SCHEMA schema..."

    export PGPASSWORD="$PG_PASSWORD"
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" \
        -c "DROP SCHEMA IF EXISTS $TARGET_SCHEMA CASCADE;" 2>/dev/null
    unset PGPASSWORD

    log "Schema $TARGET_SCHEMA dropped"
fi

# -----------------------------------------------------------------------------
# Show remaining tables
# -----------------------------------------------------------------------------
export PGPASSWORD="$PG_PASSWORD"
TABLES_RESULT=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" \
    -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema = '$TARGET_SCHEMA' ORDER BY table_name;" 2>/dev/null)
unset PGPASSWORD

if [[ -n "$TABLES_RESULT" ]]; then
    log "Remaining tables in $TARGET_SCHEMA schema:"
    echo "$TABLES_RESULT" | while read -r table; do
        if [[ -n "$table" ]]; then
            echo "  - $table"
        fi
    done
else
    log "No tables in $TARGET_SCHEMA schema"
fi

deactivate
log "Step 5 complete: Rollback finished"

echo ""
echo "Usage:"
echo "  $0              # Rollback all migrations"
echo "  $0 -1           # Rollback one revision"
echo "  $0 base yes     # Rollback all and drop schema"
echo "  $0 <revision>   # Rollback to specific revision"
