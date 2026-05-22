import asyncio
import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from cloud.app.command_timeout import run_timeout_worker
from cloud.app.database import async_session, init_db
from cloud.app.device_lifecycle import run_offline_reaper
from cloud.app.mqtt_client import mqtt_service
from cloud.app.routers import automations, commands, devices, events, gateways, health

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

    stop_event = asyncio.Event()
    timeout_task = asyncio.create_task(
        run_timeout_worker(async_session, stop_event),
        name="command-timeout-worker",
    )
    reaper_task = asyncio.create_task(
        run_offline_reaper(async_session, stop_event),
        name="device-offline-reaper",
    )

    yield

    # -- Shutdown --
    stop_event.set()
    for task in (timeout_task, reaper_task):
        try:
            await asyncio.wait_for(task, timeout=3.0)
        except asyncio.TimeoutError:
            task.cancel()
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
app.include_router(automations.router)
app.include_router(gateways.router)
app.include_router(gateways.devices_router)

# -- Serve web dashboard --
_webdev_dir = Path(__file__).resolve().parent.parent / "webdev"
if _webdev_dir.is_dir():
    app.mount("/static", StaticFiles(directory=str(_webdev_dir)), name="static")

    @app.get("/", include_in_schema=False)
    async def _serve_dashboard():
        return FileResponse(str(_webdev_dir / "index.html"))

