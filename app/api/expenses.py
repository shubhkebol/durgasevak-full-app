from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User
from app.services.expense_service import (
    create_expense,
    get_expense_by_id,
    get_mohim_expenses,
    get_mohim_total_expense,
    update_expense,
    deactivate_expense,
)
from app.utils.auth import (
    get_current_user,
    require_editor,
)


router = APIRouter(
    prefix="/expenses",
    tags=["Expenses"],
)


class ExpenseCreate(BaseModel):
    mohim_id: int
    amount: int = Field(gt=0)
    expense_date: date
    description: str
    notes: str | None = None


class ExpenseUpdate(BaseModel):
    amount: int | None = Field(
        default=None,
        gt=0,
    )
    expense_date: date | None = None
    description: str | None = None
    notes: str | None = None
    mohim_id: int | None = None


@router.post("/")
def add_expense(
    expense_data: ExpenseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_editor),
):
    expense, error = create_expense(
        db=db,
        mohim_id=expense_data.mohim_id,
        amount=expense_data.amount,
        expense_date=expense_data.expense_date,
        description=expense_data.description,
        notes=expense_data.notes,
    )

    if error:
        raise HTTPException(
            status_code=400,
            detail=error,
        )

    return {
        "success": True,
        "message": "Expense created successfully.",
        "data": {
            "id": expense.id,
            "mohim_id": expense.mohim_id,
            "amount": expense.amount,
            "expense_date": expense.expense_date,
            "description": expense.description,
            "notes": expense.notes,
        },
    }


@router.get("/mohim/{mohim_id}")
def get_mohim_expense_history(
    mohim_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    expenses = get_mohim_expenses(
        db=db,
        mohim_id=mohim_id,
    )

    total = get_mohim_total_expense(
        db=db,
        mohim_id=mohim_id,
    )

    return {
        "success": True,
        "mohim_id": mohim_id,
        "total_expense": total,
        "expenses": [
            {
                "id": expense.id,
                "amount": expense.amount,
                "expense_date": expense.expense_date,
                "description": expense.description,
                "notes": expense.notes,
            }
            for expense in expenses
        ],
    }


@router.put("/{expense_id}")
def edit_expense(
    expense_id: int,
    expense_data: ExpenseUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_editor),
):
    expense = get_expense_by_id(
        db=db,
        expense_id=expense_id,
    )

    if not expense:
        raise HTTPException(
            status_code=404,
            detail="Expense not found.",
        )

    expense, error = update_expense(
        db=db,
        expense=expense,
        amount=expense_data.amount,
        expense_date=expense_data.expense_date,
        description=expense_data.description,
        notes=expense_data.notes,
        mohim_id=expense_data.mohim_id,
    )

    if error:
        raise HTTPException(
            status_code=400,
            detail=error,
        )

    return {
        "success": True,
        "message": "Expense updated successfully.",
        "data": {
            "id": expense.id,
            "mohim_id": expense.mohim_id,
            "amount": expense.amount,
            "expense_date": expense.expense_date,
            "description": expense.description,
            "notes": expense.notes,
        },
    }


@router.delete("/{expense_id}")
def delete_expense(
    expense_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_editor),
):
    expense = get_expense_by_id(
        db=db,
        expense_id=expense_id,
    )

    if not expense:
        raise HTTPException(
            status_code=404,
            detail="Expense not found.",
        )

    deactivate_expense(
        db=db,
        expense=expense,
    )

    return {
        "success": True,
        "message": "Expense deleted successfully.",
        "expense_id": expense.id,
    }