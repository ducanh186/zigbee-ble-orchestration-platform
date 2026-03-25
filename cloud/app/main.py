import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from cloud.app.database import async_session, init_db
from cloud.app.mqtt_client import mqtt_service
from cloud.app.routers import commands, devices, events, health

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # -- Startup --
    await init_db()
    mqtt_service.set_db_session_factory(async_session)
    try:
        mqtt_service.connect()
        logger.info("MQTT client started")
    except Exception as exc:
        logger.warning("MQTT connection failed (continuing without): %s", exc)

    yield

    # -- Shutdown --
    mqtt_service.disconnect()
    logger.info("MQTT client stopped")


app = FastAPI(
    title="IoT Smart Building Cloud API",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(health.router)
app.include_router(devices.router)
app.include_router(events.router)
app.include_router(commands.router)
