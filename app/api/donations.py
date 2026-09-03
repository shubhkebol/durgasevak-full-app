from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User
from app.services.donation_service import (
    create_donation,
    get_donation_by_id,
    get_member_donations,
    get_member_total_donation,
    update_donation,
    deactivate_donation,
)
from app.utils.auth import (
    get_current_user,
    require_editor,
)


router = APIRouter(
    prefix="/donations",
    tags=["Donations"],
)


class DonationCreate(BaseModel):
    member_id: int
    amount: int = Field(gt=0)
    donation_date: date
    mohim_id: int | None = None
    notes: str | None = None


class DonationUpdate(BaseModel):
    amount: int | None = Field(
        default=None,
        gt=0,
    )
    donation_date: date | None = None
    mohim_id: int | None = None
    notes: str | None = None


@router.post("/")
def add_donation(
    donation_data: DonationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_editor),
):
    donation, error = create_donation(
        db=db,
        member_id=donation_data.member_id,
        amount=donation_data.amount,
        donation_date=donation_data.donation_date,
        mohim_id=donation_data.mohim_id,
        notes=donation_data.notes,
    )

    if error:
        raise HTTPException(
            status_code=400,
            detail=error,
        )

    return {
        "success": True,
        "message": "Donation created successfully.",
        "data": {
            "id": donation.id,
            "member_id": donation.member_id,
            "mohim_id": donation.mohim_id,
            "amount": donation.amount,
            "donation_date": donation.donation_date,
            "notes": donation.notes,
        },
    }


@router.get("/member/{member_id}")
def get_member_donation_history(
    member_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    donations = get_member_donations(
        db=db,
        member_id=member_id,
    )

    total = get_member_total_donation(
        db=db,
        member_id=member_id,
    )

    return {
        "success": True,
        "member_id": member_id,
        "total_donation": total,
        "donations": [
            {
                "id": donation.id,
                "mohim_id": donation.mohim_id,
                "amount": donation.amount,
                "donation_date": donation.donation_date,
                "notes": donation.notes,
            }
            for donation in donations
        ],
    }


@router.put("/{donation_id}")
def edit_donation(
    donation_id: int,
    donation_data: DonationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_editor),
):
    donation = get_donation_by_id(
        db=db,
        donation_id=donation_id,
    )

    if not donation:
        raise HTTPException(
            status_code=404,
            detail="Donation not found.",
        )

    donation, error = update_donation(
        db=db,
        donation=donation,
        amount=donation_data.amount,
        donation_date=donation_data.donation_date,
        mohim_id=donation_data.mohim_id,
        notes=donation_data.notes,
    )

    if error:
        raise HTTPException(
            status_code=400,
            detail=error,
        )

    return {
        "success": True,
        "message": "Donation updated successfully.",
        "data": {
            "id": donation.id,
            "member_id": donation.member_id,
            "mohim_id": donation.mohim_id,
            "amount": donation.amount,
            "donation_date": donation.donation_date,
            "notes": donation.notes,
        },
    }


@router.delete("/{donation_id}")
def delete_donation(
    donation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_editor),
):
    donation = get_donation_by_id(
        db=db,
        donation_id=donation_id,
    )

    if not donation:
        raise HTTPException(
            status_code=404,
            detail="Donation not found.",
        )

    deactivate_donation(
        db=db,
        donation=donation,
    )

    return {
        "success": True,
        "message": "Donation deleted successfully.",
        "donation_id": donation.id,
    }