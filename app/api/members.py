from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User
from app.schemas.member import (
    MemberCreate,
    MemberUpdate,
    MemberResponse,
)
from app.services.member_service import (
    create_member,
    get_member_by_id,
    get_member_total_donation,
    get_members_with_total_donation,
    update_member,
    deactivate_member,
)
from app.utils.auth import (
    get_current_user,
    require_editor,
)


router = APIRouter(
    prefix="/members",
    tags=["Members"],
)


@router.get(
    "/",
    response_model=list[MemberResponse],
)
def get_members(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    members = get_members_with_total_donation(db)

    return members


@router.post(
    "/",
    response_model=MemberResponse,
    status_code=201,
)
def add_member(
    member_data: MemberCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_editor),
):
    name = member_data.name.strip()

    if not name:
        raise HTTPException(
            status_code=400,
            detail="Member name is required.",
        )

    member, created = create_member(
        db=db,
        name=name,
        mobile=member_data.mobile,
        email=(
            str(member_data.email)
            if member_data.email
            else None
        ),
    )

    if not created:
        raise HTTPException(
            status_code=409,
            detail=(
                "Member with this mobile number "
                "already exists."
            ),
        )

    return {
        "id": member.id,
        "name": member.name,
        "mobile": member.mobile,
        "email": member.email,
        "total_donation": 0,
        "is_active": member.is_active,
    }


@router.get(
    "/{member_id}",
    response_model=MemberResponse,
)
def get_member(
    member_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    member = get_member_by_id(
        db=db,
        member_id=member_id,
    )

    if not member:
        raise HTTPException(
            status_code=404,
            detail="Member not found.",
        )

    total_donation = get_member_total_donation(
        db=db,
        member_id=member_id,
    )

    return {
        "id": member.id,
        "name": member.name,
        "mobile": member.mobile,
        "email": member.email,
        "total_donation": total_donation,
        "is_active": member.is_active,
    }


@router.put(
    "/{member_id}",
    response_model=MemberResponse,
)
def edit_member(
    member_id: int,
    member_data: MemberUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_editor),
):
    member = get_member_by_id(
        db=db,
        member_id=member_id,
    )

    if not member:
        raise HTTPException(
            status_code=404,
            detail="Member not found.",
        )

    member, error = update_member(
        db=db,
        member=member,
        name=member_data.name,
        mobile=member_data.mobile,
        email=(
            str(member_data.email)
            if member_data.email
            else None
        ),
    )

    if error:
        raise HTTPException(
            status_code=409,
            detail=error,
        )

    total_donation = get_member_total_donation(
        db=db,
        member_id=member.id,
    )

    return {
        "id": member.id,
        "name": member.name,
        "mobile": member.mobile,
        "email": member.email,
        "total_donation": total_donation,
        "is_active": member.is_active,
    }


@router.delete(
    "/{member_id}",
)
def delete_member(
    member_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_editor),
):
    member = get_member_by_id(
        db=db,
        member_id=member_id,
    )

    if not member:
        raise HTTPException(
            status_code=404,
            detail="Member not found.",
        )

    deactivate_member(
        db=db,
        member=member,
    )

    return {
        "success": True,
        "message": "Member deactivated successfully.",
        "member_id": member.id,
    }