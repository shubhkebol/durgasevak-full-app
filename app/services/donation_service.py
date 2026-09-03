from datetime import date

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.models import Donation, Member, Mohim


def create_donation(
    db: Session,
    member_id: int,
    amount: int,
    donation_date: date,
    mohim_id: int | None = None,
    notes: str | None = None,
):
    member = (
        db.query(Member)
        .filter(
            Member.id == member_id,
            Member.is_active.is_(True),
        )
        .first()
    )

    if not member:
        return None, "Member not found."

    if mohim_id is not None:
        mohim = (
            db.query(Mohim)
            .filter(
                Mohim.id == mohim_id,
                Mohim.is_active.is_(True),
            )
            .first()
        )

        if not mohim:
            return None, "Mohim not found."

    if amount <= 0:
        return None, "Donation amount must be greater than zero."

    donation = Donation(
        member_id=member_id,
        mohim_id=mohim_id,
        amount=amount,
        donation_date=donation_date,
        notes=notes.strip() if notes else None,
    )

    db.add(donation)
    db.commit()
    db.refresh(donation)

    return donation, None


def get_member_total_donation(
    db: Session,
    member_id: int,
):
    total = (
        db.query(
            func.coalesce(
                func.sum(Donation.amount),
                0,
            )
        )
        .filter(
            Donation.member_id == member_id,
            Donation.is_active.is_(True),
        )
        .scalar()
    )

    return int(total)


def get_member_donations(
    db: Session,
    member_id: int,
):
    return (
        db.query(Donation)
        .filter(
            Donation.member_id == member_id,
            Donation.is_active.is_(True),
        )
        .order_by(
            Donation.donation_date.desc(),
            Donation.id.desc(),
        )
        .all()
    )


def get_donation_by_id(
    db: Session,
    donation_id: int,
):
    return (
        db.query(Donation)
        .filter(
            Donation.id == donation_id,
            Donation.is_active.is_(True),
        )
        .first()
    )


def update_donation(
    db: Session,
    donation: Donation,
    amount: int | None = None,
    donation_date: date | None = None,
    mohim_id: int | None = None,
    notes: str | None = None,
):
    if amount is not None:
        if amount <= 0:
            return None, "Donation amount must be greater than zero."

        donation.amount = amount

    if donation_date is not None:
        donation.donation_date = donation_date

    if mohim_id is not None:
        mohim = (
            db.query(Mohim)
            .filter(
                Mohim.id == mohim_id,
                Mohim.is_active.is_(True),
            )
            .first()
        )

        if not mohim:
            return None, "Mohim not found."

        donation.mohim_id = mohim_id

    if notes is not None:
        donation.notes = notes.strip() or None

    db.commit()
    db.refresh(donation)

    return donation, None


def deactivate_donation(
    db: Session,
    donation: Donation,
):
    donation.is_active = False

    db.commit()
    db.refresh(donation)

    return donation


def get_mohim_total_donation(
    db: Session,
    mohim_id: int,
):
    total = (
        db.query(
            func.coalesce(
                func.sum(Donation.amount),
                0,
            )
        )
        .filter(
            Donation.mohim_id == mohim_id,
            Donation.is_active.is_(True),
        )
        .scalar()
    )

    return int(total)


def get_mohim_financial_summary(
    db: Session,
    mohim_id: int,
):
    total_donation = get_mohim_total_donation(
        db=db,
        mohim_id=mohim_id,
    )

    from app.services.expense_service import get_mohim_total_expense

    total_expense = get_mohim_total_expense(
        db=db,
        mohim_id=mohim_id,
    )

    balance = total_donation - total_expense

    return {
        "mohim_id": mohim_id,
        "total_donation": total_donation,
        "total_expense": total_expense,
        "balance": balance,
    }