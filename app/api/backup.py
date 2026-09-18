from datetime import datetime
from pathlib import Path

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    UploadFile,
)
from fastapi.responses import FileResponse
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


@router.get("/download_latest")
def download_latest_backup(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        from app.models.models import CloudSync
        from fastapi import Response
        
        sync = db.query(CloudSync).first()
        
        if not sync or not sync.file_data:
            raise HTTPException(
                status_code=404,
                detail="No cloud backup found. Admin needs to upload one first.",
            )
        
        return Response(
            content=sync.file_data,
            media_type="application/octet-stream",
            headers={"Content-Disposition": "attachment; filename=durgasevak_backup.db"}
        )
    except Exception as exc:
        if isinstance(exc, HTTPException):
            raise exc
        raise HTTPException(
            status_code=500,
            detail=str(exc),
        )


@router.post("/import")
def import_backup(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
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

    try:
        from app.models.models import CloudSync
        from datetime import datetime
        
        file_data = file.file.read()
        
        sync = db.query(CloudSync).first()
        if sync:
            sync.file_data = file_data
            sync.updated_at = datetime.utcnow()
        else:
            sync = CloudSync(id=1, file_data=file_data)
            db.add(sync)
        db.commit()

        return {
            "success": True,
            "message": "Database uploaded to cloud successfully.",
        }

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=str(exc),
        )