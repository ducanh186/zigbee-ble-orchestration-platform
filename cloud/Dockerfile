FROM python:3.12-slim

WORKDIR /app
ENV PYTHONPATH=/app

# Install deps first (cache layer)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy cloud package into /app/cloud/
COPY __init__.py cloud/
COPY __main__.py cloud/
COPY app/         cloud/app/
COPY webdev/      cloud/webdev/
COPY alembic.ini  cloud/
COPY alembic/     cloud/alembic/

# Data volume mount point
RUN mkdir -p /app/data

EXPOSE 8000

# Seed + run
CMD ["sh", "-c", "alembic -c cloud/alembic.ini upgrade head && python -m cloud.app.seed && python -m uvicorn cloud.app.main:app --host 0.0.0.0 --port 8000"]
