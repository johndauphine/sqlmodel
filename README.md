# PostgreSQL Schema Migration Scripts

Automated scripts for migrating database schemas between PostgreSQL databases using SQLAlchemy and Alembic.

## Overview

This toolkit generates SQLAlchemy models from a source PostgreSQL database and creates Alembic migrations to replicate the schema in a target PostgreSQL database with a different schema naming convention.

**Key Features:**
- Automated model generation using sqlacodegen
- Alembic-based schema migrations
- Lowercase table/column/constraint names in target
- Foreign key relationships preserved and transformed
- Configurable table selection
- Idempotent scripts (safe to run multiple times)
- Rollback support

## Quick Start

```bash
# 1. Configure your databases
cp scripts/config.env.example scripts/config.env
vim scripts/config.env  # Edit with your settings

# 2. Run full migration
./scripts/migrate-all.sh

# 3. Rollback if needed
./scripts/05-rollback.sh
```

## Configuration

Edit `scripts/config.env`:

```bash
# Source Database (PostgreSQL)
SOURCE_PG_HOST=localhost
SOURCE_PG_PORT=5432
SOURCE_PG_USER=postgres
SOURCE_PG_PASSWORD=YourPassword
SOURCE_PG_DATABASE=SourceDB
SOURCE_PG_SCHEMA=dbo

# Target Database (PostgreSQL)
TARGET_PG_HOST=localhost
TARGET_PG_PORT=5432
TARGET_PG_USER=postgres
TARGET_PG_PASSWORD=YourPassword
TARGET_PG_DATABASE=TargetDB

# Tables to migrate (comma-separated or "all")
TABLES=Users,Posts,Comments
```

**Target Schema Naming:**
The target schema is automatically derived as: `dw__<source_database>__<source_schema>` (lowercase)

Example: Source `StackOverflow2010.dbo` becomes target schema `dw__stackoverflow2010__dbo`

## Scripts

| Script | Description |
|--------|-------------|
| `migrate-all.sh` | Runs the full migration pipeline |
| `01-generate-models.sh` | Generates SQLAlchemy models from source |
| `02-init-alembic.sh` | Initializes Alembic for target database |
| `03-create-migration.sh` | Creates Alembic migration |
| `04-apply-migration.sh` | Applies migration and generates DDL |
| `05-rollback.sh` | Rolls back migrations |

### Running Individual Scripts

```bash
# Generate models only
./scripts/01-generate-models.sh

# Initialize Alembic
./scripts/02-init-alembic.sh

# Create migration (review before applying)
./scripts/03-create-migration.sh

# Apply migration
./scripts/04-apply-migration.sh

# Rollback options
./scripts/05-rollback.sh              # Rollback all
./scripts/05-rollback.sh -1           # Rollback one revision
./scripts/05-rollback.sh base yes     # Rollback all and drop schema
```

## Generated Artifacts

After running the migration, the `migration_workspace/` directory contains:

```
migration_workspace/
├── venv/                    # Python virtual environment
├── models.py                # Generated SQLAlchemy models
├── migration.sql            # Generated DDL
├── alembic.ini              # Alembic configuration
└── alembic/
    ├── env.py
    └── versions/            # Migration files
```

## Example Output

```
Tables migrated to dw__stackoverflow2010__dbo:
  - badges
  - comments
  - linktypes
  - postlinks
  - posts
  - posttypes
  - users
  - votes
  - votetypes
```

## Model Features

Generated models use SQLAlchemy 2.0+ syntax:
- `Mapped` type annotations
- `DeclarativeBase` pattern
- Identity columns properly mapped
- Optional fields using `Optional[]` type hints
- Foreign key constraints with proper schema references

Example:
```python
class Users(Base):
    __tablename__ = 'users'
    __table_args__ = {'schema': 'dw__stackoverflow2010__dbo'}

    Id: Mapped[int] = mapped_column('id', Integer, Identity(), primary_key=True)
    DisplayName: Mapped[str] = mapped_column('displayname', VARCHAR(40), nullable=False)
    Reputation: Mapped[int] = mapped_column('reputation', Integer, nullable=False)

class Posts(Base):
    __tablename__ = 'posts'
    __table_args__ = (
        ForeignKeyConstraint(['owneruserid'], ['dw__stackoverflow2010__dbo.users.id']),
        {'schema': 'dw__stackoverflow2010__dbo'}
    )
```

## Transformations

The model generation script automatically transforms identifiers for the target database:

| Source | Target |
|--------|--------|
| Schema `dbo` | Schema `dw__<database>__<schema>` |
| Table `Users` | Table `users` |
| Column `DisplayName` | Column `displayname` |
| Constraint `PK_Users` | Constraint `pk_users` |
| FK reference `dbo.Users.Id` | FK reference `dw__<db>__<schema>.users.id` |

Python attribute names are preserved as PascalCase for code readability while database identifiers use lowercase.

## Idempotency

All scripts are idempotent and can be run multiple times safely:
- Models are skipped if `models.py` exists
- Empty migrations are automatically removed
- Already-applied migrations are skipped

## Prerequisites

- Python 3.10+
- PostgreSQL with psql client
- Source and target PostgreSQL databases

## Docker Setup (for testing)

Quick setup using Docker for local testing:

```bash
# Start PostgreSQL container
docker run -d --name postgres-migration \
  -e POSTGRES_PASSWORD=PostgresPassword123 \
  -p 5433:5432 \
  postgres:15

# Wait for PostgreSQL to be ready
until pg_isready -h localhost -p 5433 -U postgres; do sleep 1; done

# Create source and target databases
PGPASSWORD=PostgresPassword123 psql -h localhost -p 5433 -U postgres <<EOF
CREATE DATABASE "SourceDB";
CREATE DATABASE "TargetDB";
EOF

# Create source schema and tables in SourceDB
PGPASSWORD=PostgresPassword123 psql -h localhost -p 5433 -U postgres -d SourceDB <<EOF
CREATE SCHEMA dbo;
CREATE TABLE dbo."Users" (
    "Id" SERIAL PRIMARY KEY,
    "DisplayName" VARCHAR(40) NOT NULL
);
EOF

# Update config.env with port 5433, then run migration
./scripts/migrate-all.sh

# Cleanup when done
docker stop postgres-migration && docker rm postgres-migration
```

## Verification

```bash
# Check migration status
cd scripts/migration_workspace
source venv/bin/activate
alembic current
alembic history --verbose

# List tables in target
psql -h localhost -p 5432 -U postgres -d TargetDB \
  -c "\dt dw__stackoverflow2010__dbo.*"
```
