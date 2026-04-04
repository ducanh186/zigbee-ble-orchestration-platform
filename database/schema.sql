-- SmartBridge Cloud Database Schema
-- PostgreSQL 15+ / asyncpg
-- Generated from SQLAlchemy ORM models (cloud/app/models.py)

CREATE TABLE homes (
    id          VARCHAR     PRIMARY KEY,
    name        VARCHAR     NOT NULL,
    created_at  TIMESTAMP   DEFAULT now()
);

CREATE TABLE rooms (
    id          VARCHAR     PRIMARY KEY,
    home_id     VARCHAR     NOT NULL REFERENCES homes(id),
    name        VARCHAR     NOT NULL,
    created_at  TIMESTAMP   DEFAULT now()
);

CREATE TABLE users (
    id          VARCHAR     PRIMARY KEY,
    username    VARCHAR     NOT NULL UNIQUE,
    home_id     VARCHAR     REFERENCES homes(id),
    created_at  TIMESTAMP   DEFAULT now()
);

CREATE TABLE devices (
    id          VARCHAR     PRIMARY KEY,    -- logical device_id, e.g. "light-01"
    device_type VARCHAR     NOT NULL,
    eui64       VARCHAR,
    room_id     VARCHAR     REFERENCES rooms(id),
    name        VARCHAR,
    is_online   BOOLEAN     DEFAULT TRUE,
    created_at  TIMESTAMP   DEFAULT now(),
    updated_at  TIMESTAMP   DEFAULT now()
);

CREATE TABLE device_states (
    id          SERIAL      PRIMARY KEY,
    device_id   VARCHAR     NOT NULL REFERENCES devices(id),
    state       JSONB       NOT NULL,
    reported_at TIMESTAMP   NOT NULL,
    created_at  TIMESTAMP   DEFAULT now()
);

CREATE INDEX ix_device_states_device_reported
    ON device_states (device_id, reported_at);

CREATE TABLE events (
    id          SERIAL      PRIMARY KEY,
    device_id   VARCHAR     REFERENCES devices(id),
    event_type  VARCHAR     NOT NULL,
    payload     JSONB       NOT NULL,
    occurred_at TIMESTAMP   NOT NULL,
    created_at  TIMESTAMP   DEFAULT now()
);

CREATE INDEX ix_events_device_occurred
    ON events (device_id, occurred_at);

CREATE TABLE commands (
    id          VARCHAR     PRIMARY KEY,    -- command_id uuid
    device_id   VARCHAR     NOT NULL REFERENCES devices(id),
    op          VARCHAR     NOT NULL,
    target      JSONB       NOT NULL,
    status      VARCHAR     NOT NULL DEFAULT 'accepted',
    reason      VARCHAR,
    created_at  TIMESTAMP   DEFAULT now(),
    updated_at  TIMESTAMP   DEFAULT now()
);

CREATE INDEX ix_commands_device_created
    ON commands (device_id, created_at);
