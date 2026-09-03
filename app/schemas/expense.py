from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class ExpenseCreate(BaseModel):
    mohim_id: int
    amount: int = Field(gt=0)
    expense_date: date
    description: str
    notes: str | None = None


class ExpenseResponse(BaseModel):
    id: int
    mohim_id: int
    amount: int
    expense_date: date
    description: str
    notes: str | None

    model_config = ConfigDict(from_attributes=True)


class MohimExpenseSummary(BaseModel):
    success: bool
    mohim_id: int
    total_expense: int
    expenses: list[ExpenseResponse]