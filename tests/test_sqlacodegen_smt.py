"""Tests for sqlacodegen_smt generator — unit tests against SmtGenerator."""

from __future__ import annotations

from sqlalchemy import (
    Column,
    Computed,
    ForeignKeyConstraint,
    Identity,
    Integer,
    MetaData,
    PrimaryKeyConstraint,
    String,
    Table,
    Text,
    DateTime,
    UniqueConstraint,
    create_engine,
    text,
)
from sqlacodegen_smt.generator import SmtGenerator


def _make_generator(
    tables: dict,
    target_schema: str = "dw__testdb__dbo",
    source_database: str = "TestDB",
    source_schema: str = "dbo",
) -> SmtGenerator:
    """Build a SmtGenerator from a dict of table definitions.

    tables = {
        "Users": {
            "columns": [Column("Id", Integer, primary_key=True, autoincrement=True), ...],
            "constraints": [PrimaryKeyConstraint("Id", name="PK_Users"), ...],
        }
    }
    """
    engine = create_engine("sqlite://")
    metadata = MetaData()

    for table_name, defn in tables.items():
        Table(
            table_name,
            metadata,
            *defn.get("columns", []),
            *defn.get("constraints", []),
            schema=source_schema,
        )

    return SmtGenerator(
        metadata=metadata,
        bind=engine,
        options=(),
        target_schema=target_schema,
        source_database=source_database,
        source_schema=source_schema,
    )


class TestSmtGeneratorBasic:
    def test_multi_file_output(self):
        gen = _make_generator({
            "Users": {
                "columns": [
                    Column("Id", Integer, primary_key=True, autoincrement=True),
                    Column("DisplayName", String(40), nullable=False),
                ],
                "constraints": [
                    PrimaryKeyConstraint("Id", name="PK_Users"),
                ],
            },
        })
        files = gen.generate()

        assert "base.py" in files
        assert "users.py" in files
        assert "__init__.py" in files

    def test_base_file_content(self):
        gen = _make_generator({
            "T": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_T")],
            },
        })
        files = gen.generate()

        base = files["base.py"]
        assert "class Base(DeclarativeBase):" in base
        assert "from sqlalchemy.orm import DeclarativeBase" in base

    def test_tablename_lowercase(self):
        gen = _make_generator({
            "Users": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
        })
        files = gen.generate()

        assert "__tablename__ = 'users'" in files["users.py"]

    def test_class_name_preserves_case(self):
        gen = _make_generator({
            "Users": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
        })
        files = gen.generate()

        assert "class Users(Base):" in files["users.py"]

    def test_target_schema_in_table_args(self):
        gen = _make_generator({
            "Users": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
        })
        files = gen.generate()

        assert "'schema': 'dw__testdb__dbo'" in files["users.py"]

    def test_pk_constraint_lowercase(self):
        gen = _make_generator({
            "Users": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
        })
        files = gen.generate()

        content = files["users.py"]
        assert "'pk_users'" in content
        assert "'id'" in content

    def test_column_db_name_lowercase(self):
        gen = _make_generator({
            "Users": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("DisplayName", String(40), nullable=False),
                ],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
        })
        files = gen.generate()

        content = files["users.py"]
        assert "'displayname'" in content

    def test_python_attr_preserves_case(self):
        gen = _make_generator({
            "Users": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("DisplayName", String(40), nullable=False),
                ],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
        })
        files = gen.generate()

        content = files["users.py"]
        assert "DisplayName:" in content

    def test_identity_for_autoincrement_pk(self):
        gen = _make_generator({
            "Users": {
                "columns": [
                    Column("Id", Integer, primary_key=True, autoincrement=True),
                ],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
        })
        files = gen.generate()

        content = files["users.py"]
        assert "Identity()" in content
        assert "primary_key=True" in content

    def test_nullable_optional_hint(self):
        gen = _make_generator({
            "Users": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("AboutMe", Text(), nullable=True),
                ],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
        })
        files = gen.generate()

        content = files["users.py"]
        assert "Optional[" in content
        assert "from typing import Optional" in content

    def test_non_nullable_no_optional(self):
        gen = _make_generator({
            "Users": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("Name", String(50), nullable=False),
                ],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
        })
        files = gen.generate()

        content = files["users.py"]
        # Name should have nullable=False, not Optional
        assert "nullable=False" in content


class TestSmtGeneratorFK:
    def test_fk_constraint_target_schema(self):
        gen = _make_generator({
            "Users": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
            "Posts": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("OwnerUserId", Integer, nullable=True),
                ],
                "constraints": [
                    PrimaryKeyConstraint("Id", name="PK_Posts"),
                    ForeignKeyConstraint(
                        ["OwnerUserId"],
                        ["dbo.Users.Id"],
                        name="FK_Posts_Users",
                    ),
                ],
            },
        })
        files = gen.generate()

        content = files["posts.py"]
        # FK should reference target schema, not source
        assert "dw__testdb__dbo.users.id" in content
        assert "fk_posts_users" in content.lower()

    def test_fk_local_columns_lowercase(self):
        gen = _make_generator({
            "Users": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
            "Posts": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("OwnerUserId", Integer),
                ],
                "constraints": [
                    PrimaryKeyConstraint("Id", name="PK_Posts"),
                    ForeignKeyConstraint(
                        ["OwnerUserId"],
                        ["dbo.Users.Id"],
                        name="FK_Posts_Users",
                    ),
                ],
            },
        })
        files = gen.generate()

        content = files["posts.py"]
        assert "owneruserid" in content


class TestSmtGeneratorKeyword:
    def test_keyword_column_escaping(self):
        gen = _make_generator({
            "Badges": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("Class", Integer, nullable=False),
                ],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Badges")],
            },
        })
        files = gen.generate()

        content = files["badges.py"]
        # 'Class' is a keyword — attribute should be escaped
        assert "Class_:" in content
        # DB column name should still be lowercase
        assert "'class'" in content

    def test_keyword_table_name_filename(self):
        """Table named with a Python keyword gets escaped filename and imports."""
        gen = _make_generator({
            "Class": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Class")],
            },
        })
        files = gen.generate()

        # Filename should be escaped (class_.py, not class.py)
        assert "class_.py" in files
        assert "class.py" not in files

        # __init__.py should use escaped module name
        init = files["__init__.py"]
        assert "from .class_ import" in init


class TestSmtGeneratorNoRelationships:
    def test_no_relationship_in_output(self):
        gen = _make_generator({
            "Users": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
            "Posts": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("OwnerUserId", Integer),
                ],
                "constraints": [
                    PrimaryKeyConstraint("Id", name="PK_Posts"),
                    ForeignKeyConstraint(
                        ["OwnerUserId"],
                        ["dbo.Users.Id"],
                        name="FK_Posts_Users",
                    ),
                ],
            },
        })
        files = gen.generate()

        for filename, content in files.items():
            assert "relationship" not in content.lower() or filename == "__init__.py"


class TestSmtGeneratorHeader:
    def test_file_header_present(self):
        gen = _make_generator({
            "Users": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
        })
        files = gen.generate()

        content = files["users.py"]
        assert "Auto-generated SQLAlchemy model: Users" in content
        assert "Source: TestDB.dbo" in content
        assert "Target: dw__testdb__dbo" in content


class TestSmtGeneratorInitFile:
    def test_init_imports(self):
        gen = _make_generator({
            "Users": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
            "Posts": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Posts")],
            },
        })
        files = gen.generate()

        init = files["__init__.py"]
        assert "from .base import Base" in init
        assert "from .users import Users" in init
        assert "from .posts import Posts" in init


class TestSmtGeneratorDatetime:
    def test_datetime_column(self):
        gen = _make_generator({
            "Events": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("CreatedAt", DateTime(), nullable=False),
                ],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Events")],
            },
        })
        files = gen.generate()

        content = files["events.py"]
        assert "import datetime" in content
        assert "datetime.datetime" in content
        assert "DateTime" in content


class TestSmtGeneratorCollation:
    def test_collation_stripped(self):
        gen = _make_generator({
            "Users": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("Name", String(50, collation="SQL_Latin1_General_CP1_CI_AS")),
                ],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
        })
        files = gen.generate()

        content = files["users.py"]
        assert "collation" not in content
        assert "SQL_Latin1" not in content


class TestSmtGeneratorCompositeFK:
    def test_composite_fk_target_schema(self):
        """Composite FK columns are all lowercased and reference target schema."""
        gen = _make_generator({
            "Parents": {
                "columns": [
                    Column("TenantId", Integer, primary_key=True),
                    Column("ParentId", Integer, primary_key=True),
                ],
                "constraints": [
                    PrimaryKeyConstraint("TenantId", "ParentId", name="PK_Parents"),
                ],
            },
            "Children": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("TenantId", Integer, nullable=False),
                    Column("ParentId", Integer, nullable=False),
                ],
                "constraints": [
                    PrimaryKeyConstraint("Id", name="PK_Children"),
                    ForeignKeyConstraint(
                        ["TenantId", "ParentId"],
                        ["dbo.Parents.TenantId", "dbo.Parents.ParentId"],
                        name="FK_Children_Parents",
                    ),
                ],
            },
        })
        files = gen.generate()

        content = files["children.py"]
        # Both local columns lowercase
        assert "tenantid" in content
        assert "parentid" in content
        # Both remote refs use target schema + lowercase
        assert "dw__testdb__dbo.parents.tenantid" in content
        assert "dw__testdb__dbo.parents.parentid" in content
        # Constraint name lowercase
        assert "fk_children_parents" in content


class TestSmtGeneratorServerDefault:
    def test_default_clause_rendered(self):
        """Non-sequence server_default values (e.g. DEFAULT 1) are emitted."""
        gen = _make_generator({
            "Users": {
                "columns": [
                    Column("Id", Integer, primary_key=True, autoincrement=True),
                    Column(
                        "Reputation",
                        Integer,
                        nullable=False,
                        server_default=text("1"),
                    ),
                ],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Users")],
            },
        })
        files = gen.generate()

        content = files["users.py"]
        assert "server_default=text('1')" in content
        assert "from sqlalchemy" in content
        assert "text" in content

    def test_default_clause_zero(self):
        """DEFAULT 0 is also rendered (not treated as falsy)."""
        gen = _make_generator({
            "Posts": {
                "columns": [
                    Column("Id", Integer, primary_key=True, autoincrement=True),
                    Column(
                        "Score",
                        Integer,
                        nullable=False,
                        server_default=text("0"),
                    ),
                ],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Posts")],
            },
        })
        files = gen.generate()

        content = files["posts.py"]
        assert "server_default=text('0')" in content

    def test_identity_server_default_rendered(self):
        """Columns with explicit Identity server_default emit Identity()."""
        gen = _make_generator({
            "Items": {
                "columns": [
                    Column(
                        "Id",
                        Integer,
                        primary_key=True,
                        server_default=Identity(),
                    ),
                ],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Items")],
            },
        })
        files = gen.generate()

        content = files["items.py"]
        assert "Identity()" in content

    def test_computed_column_rendered(self):
        """Computed columns emit Computed() in the model."""
        gen = _make_generator({
            "Orders": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("Qty", Integer, nullable=False),
                    Column("Price", Integer, nullable=False),
                    Column(
                        "Total",
                        Integer,
                        Computed("Qty * Price"),
                        nullable=False,
                    ),
                ],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Orders")],
            },
        })
        files = gen.generate()

        content = files["orders.py"]
        assert "Computed(" in content
        assert "Qty * Price" in content

    def test_string_server_default(self):
        """String column with a text default is rendered."""
        gen = _make_generator({
            "Settings": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column(
                        "Status",
                        String(20),
                        nullable=False,
                        server_default=text("'active'"),
                    ),
                ],
                "constraints": [PrimaryKeyConstraint("Id", name="PK_Settings")],
            },
        })
        files = gen.generate()

        content = files["settings.py"]
        assert "server_default=text(\"'active'\")" in content


class TestSmtGeneratorUniqueConstraint:
    def test_unique_constraint_in_table_args(self):
        """Explicit UniqueConstraint on non-PK column appears in __table_args__."""
        gen = _make_generator({
            "Users": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("Email", String(100), nullable=False),
                ],
                "constraints": [
                    PrimaryKeyConstraint("Id", name="PK_Users"),
                    UniqueConstraint("Email", name="UQ_Users_Email"),
                ],
            },
        })
        files = gen.generate()

        content = files["users.py"]
        assert "UniqueConstraint" in content
        assert "uq_users_email" in content.lower()


class TestSmtGeneratorDltNormalization:
    """Regressions surfaced by codex review of the dlt-naming change."""

    def test_double_underscore_preserved_in_tablename(self):
        """Source table `orders__items` keeps the `__` separator (dlt path-aware)."""
        gen = _make_generator({
            "orders__items": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id")],
            },
        })
        files = gen.generate()

        assert "orders__items.py" in files
        content = files["orders__items.py"]
        assert "__tablename__ = 'orders__items'" in content

    def test_double_underscore_preserved_in_fk_target(self):
        """FK ref to a `__`-bearing table preserves the separator in the target ref."""
        gen = _make_generator({
            "users__archive": {
                "columns": [Column("Id", Integer, primary_key=True)],
                "constraints": [PrimaryKeyConstraint("Id")],
            },
            "Posts": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("UserId", Integer, nullable=False),
                ],
                "constraints": [
                    PrimaryKeyConstraint("Id"),
                    ForeignKeyConstraint(
                        ["UserId"],
                        ["dbo.users__archive.Id"],
                        name="FK_Posts_UsersArchive",
                    ),
                ],
            },
        })
        files = gen.generate()
        content = files["posts.py"]
        assert "dw__testdb__dbo.users__archive.id" in content

    def test_unique_constraint_refs_match_normalized_columns(self):
        """UniqueConstraint column refs use the same normalized DB name as the column.

        Without this, columns whose normalized form differs from the original
        (e.g. trailing-underscore stripping by dlt) leave the constraint pointing
        at a non-existent column, raising ConstraintColumnNotFoundError on import.
        """
        gen = _make_generator({
            "Widgets": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("foo_", String(20), nullable=False),
                ],
                "constraints": [
                    PrimaryKeyConstraint("Id"),
                    UniqueConstraint("foo_", name="uq_widgets_foo"),
                ],
            },
        })
        files = gen.generate()
        content = files["widgets.py"]

        assert "mapped_column('foo'," in content
        assert "UniqueConstraint('foo'" in content
        assert "'foo_'" not in content

    def test_db_name_collision_raises(self):
        """Two source columns whose normalized DB names collide raise ValueError."""
        import pytest

        gen = _make_generator({
            "Widgets": {
                "columns": [
                    Column("Id", Integer, primary_key=True),
                    Column("foo", String(20), nullable=False),
                    Column("foo_", String(20), nullable=False),
                ],
                "constraints": [PrimaryKeyConstraint("Id")],
            },
        })
        with pytest.raises(ValueError, match="Column name collision"):
            gen.generate()
