from datetime import datetime

from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from app.models.models import User


password_hash = PasswordHash.recommended()


def hash_password(password: str) -> str:
    return password_hash.hash(password)


def verify_password(
    plain_password: str,
    hashed_password: str,
) -> bool:
    return password_hash.verify(
        plain_password,
        hashed_password,
    )


def authenticate_user(
    db: Session,
    username: str,
    password: str,
):
    user = (
        db.query(User)
        .filter(
            User.username == username,
            User.is_active.is_(True),
        )
        .first()
    )

    if not user:
        return None

    if not verify_password(
        password,
        user.password_hash,
    ):
        return None

    user.last_login = datetime.now()

    db.commit()
    db.refresh(user)

    return user