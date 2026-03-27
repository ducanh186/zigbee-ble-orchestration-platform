import uvicorn

from cloud.app.config import settings


if __name__ == "__main__":
    uvicorn.run(
        "cloud.app.main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=True,
    )
