from pathlib import Path
import shutil
import sqlite3
from datetime import datetime

from app.database.database import DATABASE_PATH


def export_database(destination: str):
    source = Path(DATABASE_PATH)
    destination_path = Path(destination)

    if not source.exists():
        raise FileNotFoundError(
            "Durgasevak database not found."
        )

    destination_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    shutil.copy2(
        source,
        destination_path,
    )

    return destination_path


def import_database(source: str):
    source_path = Path(source)
    destination_path = Path(DATABASE_PATH)

    if not source_path.exists():
        raise FileNotFoundError(
            "Backup database file not found."
        )

    if source_path.resolve() == destination_path.resolve():
        raise ValueError(
            "Source backup and active database cannot be the same file."
        )

    if source_path.suffix.lower() != ".db":
        raise ValueError(
            "Only SQLite .db backup files are supported."
        )

    # Validate backup before touching the active database.
    if not _is_valid_database(source_path):
        raise ValueError(
            "Invalid or incompatible Durgasevak database backup."
        )

    # Create automatic safety backup.
    backup_directory = Path("backups")
    backup_directory.mkdir(
        parents=True,
        exist_ok=True,
    )

    timestamp = datetime.now().strftime(
        "%Y%m%d_%H%M%S"
    )

    safety_backup = (
        backup_directory
        / f"durgasevak_before_import_{timestamp}.db"
    )

    if destination_path.exists():
        shutil.copy2(
            destination_path,
            safety_backup,
        )

    # Replace current database only after
    # successful validation.
    shutil.copy2(
        source_path,
        destination_path,
    )

    return {
        "imported_file": str(source_path),
        "safety_backup": str(safety_backup),
    }


def _is_valid_database(database_path: Path) -> bool:
    connection = None

    try:
        connection = sqlite3.connect(
            database_path
        )

        tables = connection.execute(
            """
            SELECT name
            FROM sqlite_master
            WHERE type = 'table'
            """
        ).fetchall()

        table_names = {
            table[0]
            for table in tables
        }

        # Current V1 schema.
        required_tables = {
            "members",
            "mohims",
            "donations",
            "expenses",
            "users",
        }

        return required_tables.issubset(
            table_names
        )

    except sqlite3.Error:
        return False

    finally:
        if connection:
            connection.close()