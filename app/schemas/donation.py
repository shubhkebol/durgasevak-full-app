from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class DonationCreate(BaseModel):
    member_id: int
    amount: int = Field(gt=0)
    donation_date: date
    mohim_id: int | None = None
    notes: str | None = None


class DonationResponse(BaseModel):
    id: int
    member_id: int
    mohim_id: int | None
    amount: int
    donation_date: date
    notes: str | None

    model_config = ConfigDict(from_attributes=True)


class MemberDonationSummary(BaseModel):
    success: bool
    member_id: int
    total_donation: int
    donations: list[DonationResponse]