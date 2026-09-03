from app.database.database import SessionLocal
from app.models.models import User
from app.services.auth_service import hash_password


USERS = [
    {
        "username": "Durgasevak",
        "password": "Durgasevak",
        "role": "viewer",
    },
    {
        "username": "Admin",
        "password": "Chatrapati",
        "role": "editor",
    },
]


def main():
    db = SessionLocal()

    try:
        for user_data in USERS:

            existing_user = (
                db.query(User)
                .filter(
                    User.username
                    == user_data["username"]
                )
                .first()
            )

            if existing_user:
                print(
                    f"User already exists: "
                    f"{user_data['username']}"
                )
                continue

            user = User(
                username=user_data["username"],
                password_hash=hash_password(
                    user_data["password"]
                ),
                role=user_data["role"],
            )

            db.add(user)

        db.commit()

        print("Users created successfully.")

    finally:
        db.close()


if __name__ == "__main__":
    main()
