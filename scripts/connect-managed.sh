#!/bin/bash
# Переключить мигрированное приложение с legacy hardcoded IP на managed DNS-endpoints.
# Запускать в app-VM под root ПОСЛЕ netfix-dhcp.sh + ребута (иначе DNS не резолвит).
set -e
CONF=/etc/orders/application.properties

# =========================================================================
# ВСТАВЬТЕ ИМЕНА ВАШИХ managed-сервисов.
#   Формат Service DNS в вашем тенанте (namespace = tenant-<ваш-логин>):
#     Postgres: postgres-<имя-postgres>-rw.<namespace>.svc.cozy.local
#     Kafka:    kafka-<имя-kafka>-kafka-bootstrap.<namespace>.svc.cozy.local
#   Имена сервисов видны в дашборде: Postgres/Kafka -> ваш инстанс -> Services.
# =========================================================================
PG_HOST="postgres-ВАШ_POSTGRES-rw.tenant-ВАШ_ЛОГИН.svc.cozy.local"
KAFKA_HOST="kafka-ВАШ_KAFKA-kafka-bootstrap.tenant-ВАШ_ЛОГИН.svc.cozy.local"
# =========================================================================

echo "== было (legacy hardcoded IP) =="
grep -E 'datasource.url|bootstrap-servers' "$CONF"

sed -i "s#192.168.10.30:5432#${PG_HOST}:5432#; s#192.168.10.40:9092#${KAFKA_HOST}:9092#" "$CONF"

echo "== стало (managed DNS) =="
grep -E 'datasource.url|bootstrap-servers' "$CONF"

echo "== перезапускаю приложение =="
systemctl restart orders-api
sleep 8
systemctl is-active orders-api
curl -s -o /dev/null -w 'app-health HTTP %{http_code}\n' localhost:8080/actuator/health
