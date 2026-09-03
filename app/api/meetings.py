from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import Meeting, MeetingDiscussion


router = APIRouter(
    prefix="/meetings",
    tags=["Meetings"],
)


class MeetingCreate(BaseModel):
    meeting_date: date
    title: str
    notes: str | None = None


class DiscussionCreate(BaseModel):
    discussion: str
    decision: str | None = None


@router.post("/")
def add_meeting(
    meeting_data: MeetingCreate,
    db: Session = Depends(get_db),
):
    title = meeting_data.title.strip()

    if not title:
        raise HTTPException(
            status_code=400,
            detail="Meeting title is required.",
        )

    meeting = Meeting(
        meeting_date=meeting_data.meeting_date,
        title=title,
        notes=meeting_data.notes,
    )

    db.add(meeting)
    db.commit()
    db.refresh(meeting)

    return {
        "success": True,
        "message": "Meeting created successfully.",
        "data": {
            "id": meeting.id,
            "meeting_date": meeting.meeting_date,
            "title": meeting.title,
            "notes": meeting.notes,
        },
    }


@router.get("/")
def get_meetings(
    db: Session = Depends(get_db),
):
    meetings = (
        db.query(Meeting)
        .order_by(Meeting.meeting_date.desc())
        .all()
    )

    return {
        "success": True,
        "data": [
            {
                "id": meeting.id,
                "meeting_date": meeting.meeting_date,
                "title": meeting.title,
                "notes": meeting.notes,
            }
            for meeting in meetings
        ],
    }


@router.post("/{meeting_id}/discussions")
def add_discussion(
    meeting_id: int,
    discussion_data: DiscussionCreate,
    db: Session = Depends(get_db),
):
    meeting = (
        db.query(Meeting)
        .filter(Meeting.id == meeting_id)
        .first()
    )

    if not meeting:
        raise HTTPException(
            status_code=404,
            detail="Meeting not found.",
        )

    discussion_text = discussion_data.discussion.strip()

    if not discussion_text:
        raise HTTPException(
            status_code=400,
            detail="Discussion is required.",
        )

    discussion = MeetingDiscussion(
        meeting_id=meeting_id,
        discussion=discussion_text,
        decision=discussion_data.decision,
    )

    db.add(discussion)
    db.commit()
    db.refresh(discussion)

    return {
        "success": True,
        "message": "Discussion added successfully.",
        "data": {
            "id": discussion.id,
            "meeting_id": discussion.meeting_id,
            "discussion": discussion.discussion,
            "decision": discussion.decision,
        },
    }


@router.get("/{meeting_id}/discussions")
def get_discussions(
    meeting_id: int,
    db: Session = Depends(get_db),
):
    meeting = (
        db.query(Meeting)
        .filter(Meeting.id == meeting_id)
        .first()
    )

    if not meeting:
        raise HTTPException(
            status_code=404,
            detail="Meeting not found.",
        )

    discussions = (
        db.query(MeetingDiscussion)
        .filter(MeetingDiscussion.meeting_id == meeting_id)
        .order_by(MeetingDiscussion.id)
        .all()
    )

    return {
        "success": True,
        "meeting_id": meeting_id,
        "discussions": [
            {
                "id": discussion.id,
                "discussion": discussion.discussion,
                "decision": discussion.decision,
            }
            for discussion in discussions
        ],
    }