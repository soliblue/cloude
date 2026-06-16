from fastapi import FastAPI

from app.api import health, macs
from app.core.config import settings
from app.db.schema import init_db


def create_app() -> FastAPI:
    init_db()
    enable_docs = settings().enable_docs
    app = FastAPI(
        title="Remote CC Provisioning",
        docs_url="/docs" if enable_docs else None,
        redoc_url="/redoc" if enable_docs else None,
        openapi_url="/openapi.json" if enable_docs else None,
    )
    app.include_router(health.router)
    app.include_router(macs.router)
    return app


app = create_app()
