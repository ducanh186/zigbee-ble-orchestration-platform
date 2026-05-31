from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SECURE_COMPOSE = REPO_ROOT / "deploy" / "docker-compose.prod-secure.yml"
NGINX_CONF = REPO_ROOT / "deploy" / "nginx" / "prod.conf"


def test_secure_production_compose_exposes_only_reverse_proxy_ports() -> None:
    compose = SECURE_COMPOSE.read_text(encoding="utf-8")

    assert '"80:80"' in compose
    assert '"443:443"' in compose
    assert '"8000:8000"' not in compose
    assert '"1883:1883"' not in compose
    assert '"5432:5432"' not in compose
    assert "cloud-api:" in compose
    assert "expose:" in compose
    assert '"8000"' in compose
    assert "postgres:" in compose
    assert "mosquitto:" in compose


def test_nginx_production_config_redirects_http_and_proxies_https() -> None:
    conf = NGINX_CONF.read_text(encoding="utf-8")

    assert "listen 80" in conf
    assert "return 301 https://$host$request_uri" in conf
    assert "listen 443 ssl" in conf
    assert "ssl_certificate" in conf
    assert "ssl_certificate_key" in conf
    assert "proxy_pass http://cloud-api:8000" in conf
    assert "proxy_set_header Authorization $http_authorization" in conf
