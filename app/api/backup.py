from datetime import datetime
from pathlib import Path

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    UploadFile,
)
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User
from app.services.backup_service import (
    export_database,
    import_database,
)
from app.utils.auth import (
    get_current_user,
    require_editor,
)


router = APIRouter(
    prefix="/backup",
    tags=["Backup"],
)


@router.get("/export")
def export_backup(
    current_user: User = Depends(require_editor),
):
    try:
        timestamp = datetime.now().strftime(
            "%Y%m%d_%H%M%S"
        )

        backup_directory = Path("backups")
        backup_directory.mkdir(
            parents=True,
            exist_ok=True,
        )

        backup_path = (
            backup_directory
            / f"durgasevak_backup_{timestamp}.db"
        )

        export_database(
            str(backup_path)
        )

        return {
            "success": True,
            "message": (
                "Database backup created successfully."
            ),
            "file": str(backup_path),
        }

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=str(exc),
        )


@router.post("/import")
def import_backup(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    if not file.filename:
        raise HTTPException(
            status_code=400,
            detail="No backup file provided.",
        )

    if not file.filename.lower().endswith(".db"):
        raise HTTPException(
            status_code=400,
            detail="Only .db backup files are supported.",
        )

    temporary_directory = Path("temp")
    temporary_directory.mkdir(
        parents=True,
        exist_ok=True,
    )

    temporary_file = (
        temporary_directory
        / "durgasevak_import.db"
    )

    try:
        with temporary_file.open("wb") as buffer:
            while True:
                chunk = file.file.read(
                    1024 * 1024
                )

                if not chunk:
                    break

                buffer.write(chunk)

        result = import_database(
            str(temporary_file)
        )

        return {
            "success": True,
            "message": (
                "Database imported successfully. "
                "Existing database was backed up first."
            ),
            "safety_backup": result[
                "safety_backup"
            ],
        }

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        )

    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=404,
            detail=str(exc),
        )

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=str(exc),
        )

    finally:
        if temporary_file.exists():
            temporary_file.unlink()