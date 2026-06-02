-- Canonical RBAC roles for the smart-home MVP.
-- Safe to run more than once on PostgreSQL.

ALTER TABLE users
ADD COLUMN IF NOT EXISTS role VARCHAR NOT NULL DEFAULT 'viewer';

ALTER TABLE users
ADD COLUMN IF NOT EXISTS password_hash VARCHAR;

ALTER TABLE users
ADD COLUMN IF NOT EXISTS display_name VARCHAR;

ALTER TABLE users
ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE users
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE users
ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP;

ALTER TABLE users
ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMP;

ALTER TABLE users
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP;

UPDATE users
SET role = 'parent'
WHERE role IN ('operator', 'user');

UPDATE users
SET role = 'viewer'
WHERE role IN ('member', '');

UPDATE users
SET role = 'viewer'
WHERE role IS NULL
   OR role NOT IN ('admin', 'parent', 'viewer');
