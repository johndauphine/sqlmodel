#!/bin/bash
# =============================================================================
# migrate-all.sh
# Orchestrator script that runs the full migration pipeline
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error_exit() {
    echo ""
    echo "=========================================="
    echo "ERROR: Migration failed at step $1"
    echo "=========================================="
    echo ""
    echo "You can retry from this step by running:"
    echo "  $SCRIPT_DIR/0$1-*.sh"
    echo ""
    echo "Or rollback with:"
    echo "  $SCRIPT_DIR/05-rollback.sh"
    exit 1
}

# -----------------------------------------------------------------------------
# Check for config.env
# -----------------------------------------------------------------------------
if [[ ! -f "$SCRIPT_DIR/config.env" ]]; then
    echo "=========================================="
    echo "Configuration Required"
    echo "=========================================="
    echo ""
    echo "Please create config.env before running migration:"
    echo ""
    echo "  cp $SCRIPT_DIR/config.env.example $SCRIPT_DIR/config.env"
    echo "  vim $SCRIPT_DIR/config.env  # Edit with your settings"
    echo ""
    exit 1
fi

# -----------------------------------------------------------------------------
# Display configuration summary
# -----------------------------------------------------------------------------
source "$SCRIPT_DIR/config.env"

echo "=========================================="
echo "Schema Migration Pipeline"
echo "=========================================="
echo ""
echo "Source (MSSQL):"
echo "  Host: $MSSQL_HOST:$MSSQL_PORT"
echo "  Database: $MSSQL_DATABASE"
echo "  Schema: $MSSQL_SCHEMA"
echo ""
echo "Target (PostgreSQL):"
echo "  Host: $PG_HOST:$PG_PORT"
echo "  Database: $PG_DATABASE"
echo ""
echo "Tables: $TABLES"
echo "Working directory: $WORK_DIR"
echo ""
echo "=========================================="
echo ""

# -----------------------------------------------------------------------------
# Confirm before proceeding
# -----------------------------------------------------------------------------
read -p "Proceed with migration? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled"
    exit 0
fi

echo ""

# -----------------------------------------------------------------------------
# Run migration steps
# -----------------------------------------------------------------------------
START_TIME=$(date +%s)

log "Starting migration pipeline..."
echo ""

# Step 1: Generate models
echo "=========================================="
echo "Step 1/4: Generate SQLAlchemy models"
echo "=========================================="
"$SCRIPT_DIR/01-generate-models.sh" || error_exit 1
echo ""

# Step 2: Initialize Alembic
echo "=========================================="
echo "Step 2/4: Initialize Alembic"
echo "=========================================="
"$SCRIPT_DIR/02-init-alembic.sh" || error_exit 2
echo ""

# Step 3: Create migration
echo "=========================================="
echo "Step 3/4: Create migration"
echo "=========================================="
"$SCRIPT_DIR/03-create-migration.sh" || error_exit 3
echo ""

# Step 4: Apply migration
echo "=========================================="
echo "Step 4/4: Apply migration"
echo "=========================================="
"$SCRIPT_DIR/04-apply-migration.sh" || error_exit 4
echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "=========================================="
echo "Migration Complete"
echo "=========================================="
echo ""
echo "Duration: ${DURATION}s"
echo ""
echo "Artifacts created in: $WORK_DIR"
echo "  - models.py (SQLAlchemy models)"
echo "  - alembic/ (migration configuration)"
echo "  - venv/ (Python virtual environment)"
echo ""
echo "Next steps:"
echo "  - Verify tables: psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE -c '\\dt dbo.*'"
echo "  - Check status:  cd $WORK_DIR && source venv/bin/activate && alembic current"
echo "  - Rollback:      $SCRIPT_DIR/05-rollback.sh"
echo ""
