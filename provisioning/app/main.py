from fastapi import FastAPI

from app.api import health, macs, pairing_sessions
from app.db.schema import init_db


def create_app() -> FastAPI:
    init_db()
    app = FastAPI(title="Remote CC Provisioning")
    app.include_router(health.router)
    app.include_router(pairing_sessions.router)
    app.include_router(macs.router)
    return app


app = create_app()
