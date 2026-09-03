from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User
from app.services.report_service import (
    get_monthly_donation_report,
    get_monthly_expense_report,
    get_monthly_financial_summary,
)
from app.utils.auth import get_current_user


router = APIRouter(
    prefix="/reports",
    tags=["Reports"],
)


@router.get("/monthly-donations")
def monthly_donations(
    year: int = Query(..., ge=2000, le=2100),
    month: int = Query(..., ge=1, le=12),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    data = get_monthly_donation_report(
        db=db,
        year=year,
        month=month,
    )

    total = sum(
        item["total_donation"]
        for item in data
    )

    return {
        "success": True,
        "year": year,
        "month": month,
        "total_donation": total,
        "data": data,
    }


@router.get("/monthly-expenses")
def monthly_expenses(
    year: int = Query(..., ge=2000, le=2100),
    month: int = Query(..., ge=1, le=12),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    data = get_monthly_expense_report(
        db=db,
        year=year,
        month=month,
    )

    total = sum(
        item["total_expense"]
        for item in data
    )

    return {
        "success": True,
        "year": year,
        "month": month,
        "total_expense": total,
        "data": data,
    }


@router.get("/monthly-financial-summary")
def monthly_financial_summary(
    year: int = Query(..., ge=2000, le=2100),
    month: int = Query(..., ge=1, le=12),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return {
        "success": True,
        "data": get_monthly_financial_summary(
            db=db,
            year=year,
            month=month,
        ),
    }