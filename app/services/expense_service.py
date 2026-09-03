from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.models import Expense, Mohim


def create_expense(
    db: Session,
    mohim_id: int,
    amount: int,
    expense_date,
    description: str,
    notes: str | None = None,
):
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
        return None, "Expense amount must be greater than zero."

    description = description.strip()

    if not description:
        return None, "Expense description is required."

    expense = Expense(
        mohim_id=mohim_id,
        amount=amount,
        expense_date=expense_date,
        description=description,
        notes=notes.strip() if notes else None,
    )

    db.add(expense)
    db.commit()
    db.refresh(expense)

    return expense, None


def get_mohim_total_expense(
    db: Session,
    mohim_id: int,
):
    total = (
        db.query(
            func.coalesce(
                func.sum(Expense.amount),
                0,
            )
        )
        .filter(
            Expense.mohim_id == mohim_id,
            Expense.is_active.is_(True),
        )
        .scalar()
    )

    return int(total)


def get_mohim_expenses(
    db: Session,
    mohim_id: int,
):
    return (
        db.query(Expense)
        .filter(
            Expense.mohim_id == mohim_id,
            Expense.is_active.is_(True),
        )
        .order_by(
            Expense.expense_date.desc(),
            Expense.id.desc(),
        )
        .all()
    )


def get_expense_by_id(
    db: Session,
    expense_id: int,
):
    return (
        db.query(Expense)
        .filter(
            Expense.id == expense_id,
            Expense.is_active.is_(True),
        )
        .first()
    )


def update_expense(
    db: Session,
    expense: Expense,
    amount: int | None = None,
    expense_date=None,
    description: str | None = None,
    notes: str | None = None,
    mohim_id: int | None = None,
):
    if amount is not None:
        if amount <= 0:
            return None, "Expense amount must be greater than zero."

        expense.amount = amount

    if expense_date is not None:
        expense.expense_date = expense_date

    if description is not None:
        description = description.strip()

        if not description:
            return None, "Expense description is required."

        expense.description = description

    if notes is not None:
        expense.notes = notes.strip() or None

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

        expense.mohim_id = mohim_id

    db.commit()
    db.refresh(expense)

    return expense, None


def deactivate_expense(
    db: Session,
    expense: Expense,
):
    expense.is_active = False

    db.commit()
    db.refresh(expense)

    return expense