from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


class MeetingCreate(BaseModel):
    meeting_date: date
    title: str
    notes: str | None = None


class MeetingResponse(BaseModel):
    id: int
    meeting_date: date
    title: str
    notes: str | None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DiscussionCreate(BaseModel):
    discussion: str
    decision: str | None = None


class DiscussionResponse(BaseModel):
    id: int
    meeting_id: int
    discussion: str
    decision: str | None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)