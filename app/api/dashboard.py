from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User
from app.services.dashboard_service import (
    get_dashboard_summary,
    get_member_donation_summary,
)
from app.utils.auth import get_current_user


router = APIRouter(
    prefix="/dashboard",
    tags=["Dashboard"],
)


@router.get("/")
def dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return {
        "success": True,
        "data": get_dashboard_summary(db),
    }


@router.get("/member-donations")
def member_donations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return {
        "success": True,
        "data": get_member_donation_summary(db),
    }