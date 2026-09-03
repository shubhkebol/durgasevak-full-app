from sqlalchemy.orm import Session

from app.models.models import Mohim


def create_mohim(
    db: Session,
    title: str,
    description: str | None,
    start_date,
    end_date,
):
    mohim = Mohim(
        title=title.strip(),
        description=description.strip() if description else None,
        start_date=start_date,
        end_date=end_date,
    )

    db.add(mohim)
    db.commit()
    db.refresh(mohim)

    return mohim


def get_all_mohims(db: Session):
    return (
        db.query(Mohim)
        .filter(Mohim.is_active.is_(True))
        .order_by(Mohim.start_date.desc())
        .all()
    )


def get_mohim_by_id(
    db: Session,
    mohim_id: int,
):
    return (
        db.query(Mohim)
        .filter(
            Mohim.id == mohim_id,
            Mohim.is_active.is_(True),
        )
        .first()
    )


def update_mohim(
    db: Session,
    mohim: Mohim,
    title: str | None = None,
    description: str | None = None,
    start_date=None,
    end_date=None,
):
    if title is not None:
        title = title.strip()

        if not title:
            return None, "Mohim title cannot be empty."

        mohim.title = title

    if description is not None:
        mohim.description = description.strip() or None

    if start_date is not None:
        mohim.start_date = start_date

    if end_date is not None:
        mohim.end_date = end_date

    if mohim.end_date < mohim.start_date:
        return None, "End date cannot be before start date."

    db.commit()
    db.refresh(mohim)

    return mohim, None


def deactivate_mohim(
    db: Session,
    mohim: Mohim,
):
    mohim.is_active = False

    db.commit()
    db.refresh(mohim)

    return mohim