from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.models import Member, Donation, Mohim,Expense


def get_monthly_donation_report(
    db: Session,
    year: int,
    month: int,
):
    results = (
        db.query(
            Member.id.label("member_id"),
            Member.name.label("member_name"),
            Mohim.id.label("mohim_id"),
            Mohim.title.label("mohim_title"),
            func.sum(Donation.amount).label("total_donation"),
        )
        .join(
            Donation,
            Donation.member_id == Member.id,
        )
        .outerjoin(
            Mohim,
            Mohim.id == Donation.mohim_id,
        )
        .filter(
            Member.is_active.is_(True),
            Donation.is_active.is_(True),
            func.strftime("%Y", Donation.donation_date)
            == str(year),
            func.strftime("%m", Donation.donation_date)
            == f"{month:02d}",
        )
        .group_by(
            Member.id,
            Member.name,
            Mohim.id,
            Mohim.title,
        )
        .order_by(
            Member.name,
            Mohim.title,
        )
        .all()
    )

    return [
        {
            "member_id": row.member_id,
            "member_name": row.member_name,
            "mohim_id": row.mohim_id,
            "mohim_title": row.mohim_title or "General Donation",
            "total_donation": int(row.total_donation),
        }
        for row in results
    ]

def get_monthly_expense_report(
    db: Session,
    year: int,
    month: int,
):
    results = (
        db.query(
            Mohim.id.label("mohim_id"),
            Mohim.title.label("mohim_title"),
            func.sum(Expense.amount).label("total_expense"),
        )
        .join(
            Expense,
            Expense.mohim_id == Mohim.id,
        )
        .filter(
            Mohim.is_active.is_(True),
            Expense.is_active.is_(True),
            func.strftime("%Y", Expense.expense_date) == str(year),
            func.strftime("%m", Expense.expense_date) == f"{month:02d}",
        )
        .group_by(
            Mohim.id,
            Mohim.title,
        )
        .order_by(
            Mohim.title,
        )
        .all()
    )

    return [
        {
            "mohim_id": row.mohim_id,
            "mohim_title": row.mohim_title,
            "total_expense": int(row.total_expense),
        }
        for row in results
    ]

def get_monthly_financial_summary(
    db: Session,
    year: int,
    month: int,
):
    donation_data = get_monthly_donation_report(
        db=db,
        year=year,
        month=month,
    )

    expense_data = get_monthly_expense_report(
        db=db,
        year=year,
        month=month,
    )

    total_donation = sum(
        item["total_donation"]
        for item in donation_data
    )

    total_expense = sum(
        item["total_expense"]
        for item in expense_data
    )

    balance = total_donation - total_expense

    return {
        "year": year,
        "month": month,
        "total_donation": total_donation,
        "total_expense": total_expense,
        "balance": balance,
        "donations": donation_data,
        "expenses": expense_data,
    }