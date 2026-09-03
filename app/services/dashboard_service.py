from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.models import Member, Donation, Expense, Mohim


def get_dashboard_summary(db: Session):

    total_members = (
        db.query(func.count(Member.id))
        .filter(Member.is_active.is_(True))
        .scalar()
    ) or 0

    total_donation = (
        db.query(func.coalesce(func.sum(Donation.amount), 0))
        .filter(Donation.is_active.is_(True))
        .scalar()
    ) or 0

    total_expense = (
        db.query(func.coalesce(func.sum(Expense.amount), 0))
        .filter(Expense.is_active.is_(True))
        .scalar()
    ) or 0

    total_mohims = (
        db.query(func.count(Mohim.id))
        .filter(Mohim.is_active.is_(True))
        .scalar()
    ) or 0

    balance = total_donation - total_expense

    return {
        "total_members": int(total_members),
        "total_donation": int(total_donation),
        "total_expense": int(total_expense),
        "balance": int(balance),
        "total_mohims": int(total_mohims),
    }
def get_member_donation_summary(db: Session):
    results = (
        db.query(
            Member.id,
            Member.name,
            Member.mobile,
            func.coalesce(
                func.sum(Donation.amount),
                0,
            ).label("total_donation"),
        )
        .outerjoin(
            Donation,
            (
                Donation.member_id == Member.id
            )
            & Donation.is_active.is_(True),
        )
        .filter(
            Member.is_active.is_(True),
        )
        .group_by(
            Member.id,
            Member.name,
            Member.mobile,
        )
        .order_by(
            Member.name,
        )
        .all()
    )

    return [
        {
            "member_id": row.id,
            "name": row.name,
            "mobile": row.mobile,
            "total_donation": int(row.total_donation),
        }
        for row in results
    ]
