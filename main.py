from fastapi import FastAPI

from app.api.auth import router as auth_router
from app.api.members import router as members_router
from app.api.donations import router as donations_router
from app.api.mohims import router as mohims_router
from app.api.expenses import router as expenses_router
from app.api.dashboard import router as dashboard_router
from app.api.reports import router as reports_router
from app.api.backup import router as backup_router


app = FastAPI(
    title="Durgasevak API",
    description="Backend API for Durgasevak financial management",
    version="1.0.0",
)


@app.get("/")
def root():
    return {
        "success": True,
        "message": "Welcome to Durgasevak API",
    }


app.include_router(auth_router)
app.include_router(members_router)
app.include_router(donations_router)
app.include_router(mohims_router)
app.include_router(expenses_router)
app.include_router(dashboard_router)
app.include_router(reports_router)
app.include_router(backup_router)