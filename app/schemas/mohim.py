from datetime import date

from pydantic import BaseModel, ConfigDict


class MohimCreate(BaseModel):
    title: str
    description: str | None = None
    start_date: date
    end_date: date


class MohimUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    start_date: date | None = None
    end_date: date | None = None


class MohimResponse(BaseModel):
    id: int
    title: str
    description: str | None
    start_date: date
    end_date: date
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


class MohimFinancialSummary(BaseModel):
    mohim_id: int
    title: str
    start_date: date
    end_date: date
    total_donation: int
    total_expense: int
    balance: int