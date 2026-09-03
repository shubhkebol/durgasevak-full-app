from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User
from app.schemas.mohim import (
    MohimCreate,
    MohimUpdate,
    MohimResponse,
    MohimFinancialSummary,
)
from app.services.mohim_service import (
    create_mohim,
    get_all_mohims,
    get_mohim_by_id,
    update_mohim,
    deactivate_mohim,
)
from app.services.donation_service import (
    get_mohim_financial_summary,
)
from app.utils.auth import (
    get_current_user,
    require_editor,
)


router = APIRouter(
    prefix="/mohims",
    tags=["Mohims"],
)


@router.post(
    "/",
    response_model=MohimResponse,
    status_code=201,
)
def add_mohim(
    mohim_data: MohimCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_editor),
):
    title = mohim_data.title.strip()

    if not title:
        raise HTTPException(
            status_code=400,
            detail="Mohim title is required.",
        )

    if mohim_data.end_date < mohim_data.start_date:
        raise HTTPException(
            status_code=400,
            detail="End date cannot be before start date.",
        )

    return create_mohim(
        db=db,
        title=title,
        description=mohim_data.description,
        start_date=mohim_data.start_date,
        end_date=mohim_data.end_date,
    )


@router.get(
    "/",
    response_model=list[MohimResponse],
)
def get_mohims(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_all_mohims(db)


@router.get(
    "/{mohim_id}",
    response_model=MohimResponse,
)
def get_mohim(
    mohim_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    mohim = get_mohim_by_id(
        db=db,
        mohim_id=mohim_id,
    )

    if not mohim:
        raise HTTPException(
            status_code=404,
            detail="Mohim not found.",
        )

    return mohim


@router.put(
    "/{mohim_id}",
    response_model=MohimResponse,
)
def edit_mohim(
    mohim_id: int,
    mohim_data: MohimUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_editor),
):
    mohim = get_mohim_by_id(
        db=db,
        mohim_id=mohim_id,
    )

    if not mohim:
        raise HTTPException(
            status_code=404,
            detail="Mohim not found.",
        )

    mohim, error = update_mohim(
        db=db,
        mohim=mohim,
        title=mohim_data.title,
        description=mohim_data.description,
        start_date=mohim_data.start_date,
        end_date=mohim_data.end_date,
    )

    if error:
        raise HTTPException(
            status_code=400,
            detail=error,
        )

    return mohim


@router.delete(
    "/{mohim_id}",
)
def delete_mohim(
    mohim_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_editor),
):
    mohim = get_mohim_by_id(
        db=db,
        mohim_id=mohim_id,
    )

    if not mohim:
        raise HTTPException(
            status_code=404,
            detail="Mohim not found.",
        )

    deactivate_mohim(
        db=db,
        mohim=mohim,
    )

    return {
        "success": True,
        "message": "Mohim deactivated successfully.",
        "mohim_id": mohim.id,
    }


@router.get(
    "/{mohim_id}/financial-summary",
    response_model=MohimFinancialSummary,
)
def financial_summary(
    mohim_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    mohim = get_mohim_by_id(
        db=db,
        mohim_id=mohim_id,
    )

    if not mohim:
        raise HTTPException(
            status_code=404,
            detail="Mohim not found.",
        )

    summary = get_mohim_financial_summary(
        db=db,
        mohim_id=mohim_id,
    )

    return {
        "mohim_id": mohim.id,
        "title": mohim.title,
        "start_date": mohim.start_date,
        "end_date": mohim.end_date,
        "total_donation": summary["total_donation"],
        "total_expense": summary["total_expense"],
        "balance": summary["balance"],
    }