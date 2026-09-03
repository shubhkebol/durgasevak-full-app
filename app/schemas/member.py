from pydantic import BaseModel, ConfigDict, EmailStr


class MemberCreate(BaseModel):
    name: str
    mobile: str | None = None
    email: EmailStr | None = None


class MemberUpdate(BaseModel):
    name: str | None = None
    mobile: str | None = None
    email: EmailStr | None = None


class MemberResponse(BaseModel):
    id: int
    name: str
    mobile: str | None
    email: str | None
    total_donation: int
    is_active: bool

    model_config = ConfigDict(from_attributes=True)