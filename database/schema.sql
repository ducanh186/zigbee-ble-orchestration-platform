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
    display_name VARCHAR,
    role        VARCHAR     NOT NULL DEFAULT 'viewer',
    password_hash VARCHAR,
    must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    last_login_at TIMESTAMP,
    password_changed_at TIMESTAMP,
    home_id     VARCHAR     REFERENCES homes(id),
    created_at  TIMESTAMP   DEFAULT now(),
    updated_at  TIMESTAMP   DEFAULT now()
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

CREATE TABLE automations (
    id              VARCHAR     PRIMARY KEY,
    name            VARCHAR     NOT NULL,
    enabled         BOOLEAN     NOT NULL DEFAULT TRUE,
    tenant_id       VARCHAR     NOT NULL,
    site_id         VARCHAR     NOT NULL,
    gateway_id      VARCHAR     NOT NULL,
    "trigger"       JSONB       NOT NULL,
    actions         JSONB       NOT NULL,
    sync_status     VARCHAR     NOT NULL DEFAULT 'pending',
    last_run_status VARCHAR     NOT NULL DEFAULT 'never_run',
    last_error      VARCHAR,
    created_at      TIMESTAMP   DEFAULT now(),
    updated_at      TIMESTAMP   DEFAULT now()
);

CREATE INDEX ix_automations_gateway_created
    ON automations (tenant_id, site_id, gateway_id, created_at);

CREATE TABLE factory_devices (
    eui64        VARCHAR     PRIMARY KEY,
    install_code VARCHAR     NOT NULL,
    device_type  VARCHAR     NOT NULL,
    model        VARCHAR,
    is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
    claimed_at   TIMESTAMP,
    created_at   TIMESTAMP   DEFAULT now(),
    updated_at   TIMESTAMP   DEFAULT now()
);

CREATE INDEX ix_factory_devices_type_active
    ON factory_devices (device_type, is_active);
