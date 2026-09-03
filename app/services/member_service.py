from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.models import Member, Donation


def create_member(
    db: Session,
    name: str,
    mobile: str | None = None,
    email: str | None = None,
):
    name = name.strip()

    if mobile:
        mobile = mobile.strip()

    if email:
        email = email.strip()

    if mobile:
        existing_member = (
            db.query(Member)
            .filter(
                Member.mobile == mobile,
                Member.is_active.is_(True),
            )
            .first()
        )

        if existing_member:
            return existing_member, False

    member = Member(
        name=name,
        mobile=mobile,
        email=email,
    )

    db.add(member)
    db.commit()
    db.refresh(member)

    return member, True


def get_all_members(db: Session):
    return (
        db.query(Member)
        .filter(Member.is_active.is_(True))
        .order_by(Member.name)
        .all()
    )


def get_member_by_id(
    db: Session,
    member_id: int,
):
    return (
        db.query(Member)
        .filter(
            Member.id == member_id,
            Member.is_active.is_(True),
        )
        .first()
    )


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
        )
        .scalar()
    )

    return int(total)


def get_members_with_total_donation(db: Session):
    return (
        db.query(
            Member.id,
            Member.name,
            Member.mobile,
            Member.email,
            Member.is_active,
            func.coalesce(
                func.sum(Donation.amount),
                0,
            ).label("total_donation"),
        )
        .outerjoin(
            Donation,
            Donation.member_id == Member.id,
        )
        .filter(
            Member.is_active.is_(True),
        )
        .group_by(
            Member.id,
            Member.name,
            Member.mobile,
            Member.email,
            Member.is_active,
        )
        .order_by(Member.name)
        .all()
    )


def update_member(
    db: Session,
    member: Member,
    name: str | None = None,
    mobile: str | None = None,
    email: str | None = None,
):
    if name is not None:
        name = name.strip()

        if not name:
            return None, "Member name cannot be empty."

        member.name = name

    if mobile is not None:
        mobile = mobile.strip()

        if mobile:
            existing_member = (
                db.query(Member)
                .filter(
                    Member.mobile == mobile,
                    Member.id != member.id,
                    Member.is_active.is_(True),
                )
                .first()
            )

            if existing_member:
                return None, "Mobile number already belongs to another member."

        member.mobile = mobile or None

    if email is not None:
        member.email = email.strip() or None

    db.commit()
    db.refresh(member)

    return member, None


def deactivate_member(
    db: Session,
    member: Member,
):
    member.is_active = False

    db.commit()
    db.refresh(member)

    return member