from fastapi import APIRouter

from cloud.app.schemas import HealthOut

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthOut)
async def health_check():
    """Return service health status."""
    return HealthOut()
