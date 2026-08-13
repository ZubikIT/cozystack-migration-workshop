# 🚀 Воркшоп: миграция VMware-VM в Cozystack

Мигрируем «легаси»-приложение из VMware в облачную платформу Cozystack —
**своими руками, self-service**. В этой репе всё нужное: манифесты по фазам,
скрипты и шпаргалка.

---

## Что будем делать

```
Вход в тенант  →  свой S3-бакет  →  conversion-VM (virt-v2v: OVA → qcow2)
      →  заливаем образ в бакет  →  app-VM из своего образа
      →  managed Postgres + Kafka  →  подключаем приложение  →  заказы летят в PG + Kafka
```

---

## Доступы (выдаёт ведущий)

- **Дашборд:** https://dashboard.workshop.aenix.io
- **Логин / пароль:** `pXX` / *(выдаётся на воркшопе)*
- **kubeconfig:** дашборд → **Info → Secrets → `kubeconfig-tenant-pXX`**
  (нужен `kubectl oidc-login` / kubelogin — при первом `kubectl` откроется браузер Keycloak)

> Во всех манифестах и командах замени `tenant-pXX` на свой namespace.

---

## Фазы (манифесты + команды)

### Фаза 1 — свой S3-бакет
```bash
kubectl apply -f manifests/01-bucket.yaml
```
Креды бакета: дашборд → Bucket → ваш бакет → **Secrets** (`accessKey`, `secretKey`,
`endpoint`, `bucketName`) — вставляются в `scripts/convert.sh`.

### Фаза 2 — conversion-VM + конвертация
```bash
kubectl apply -f manifests/02-conversion-vm.yaml
```
Дождись Running, зайди в VNC (или `virtctl ssh ubuntu@vm-instance-convert`,
пароль `ubuntu`), впиши свои креды в `scripts/convert.sh` и запусти:
`virt-v2v` сконвертит OVA → qcow2 и зальёт в твой бакет. В конце скрипт печатает
**presigned-ссылку** на образ.

### Фаза 3 — app-VM из своего образа
Вставь presigned-ссылку в `manifests/03-app-vm.yaml` (поле `url`), затем:
```bash
kubectl apply -f manifests/03-app-vm.yaml
```
Вход в гостя: `root` / `cozydemo`.

### Фаза 4 — managed Postgres + Kafka
```bash
kubectl apply -f manifests/04-managed.yaml
```

### Фаза 5 — подключение приложения к managed
В app-VM (`virtctl console vm-instance-app-1`, `root`/`cozydemo`):
1. **Сеть на pod-NIC** — `scripts/netfix-dhcp.sh` (переключает eth0 на DHCP) + ребут.
2. **Конфиг на managed DNS** — `scripts/connect-managed.sh`.
3. **Схема БД** — накатить `scripts/orders-schema.sql` в managed Postgres
   (не забудь GRANT под superuser — см. комментарий в файле).

---

## Скрипты (`scripts/`)

| Файл | Что делает |
| --- | --- |
| `convert.sh` | качает OVA, `virt-v2v` → qcow2, заливает в свой бакет, печатает presigned |
| `netfix-dhcp.sh` | переключает eth0 мигрированной VM на DHCP (pod-NIC) |
| `connect-managed.sh` | переключает приложение на managed DNS |
| `orders-schema.sql` | таблица `orders` + сид для managed Postgres |

---

## ⚡ Шпаргалка команд

```bash
# app-VM (CentOS) — root / cozydemo
virtctl console --namespace=tenant-pXX vm-instance-app-1

# conversion-VM (ubuntu) — ubuntu / ubuntu
virtctl ssh --namespace=tenant-pXX ubuntu@vm-instance-convert

# проброс приложения на localhost
virtctl port-forward --namespace=tenant-pXX vm-instance-app-1 8088:8080

# health: 200 = Postgres и Kafka живы
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/actuator/health

# создать заказ (пишется в Postgres + событие в Kafka)
curl -s -X POST http://localhost:8080/api/orders \
  -H 'Content-Type: application/json' -d '{"item":"test"}'
```

---

## ⚠️ Частые грабли

- **conversion-VM — только `ubuntu-20.04`** (24.04 kernel panic, 22.04 ломает virt-v2v).
- **VMDisk `storage` > размера каталожного образа** (иначе clone fail; удаление зависает в Terminating). Для ubuntu-20.04 бери 25Gi.
- После старта app-VM: **сначала netfix** (eth0 → DHCP, ребут), **потом connect** (конфиг на managed DNS). Порядок важен.
- **Схема БД — два шага:** `GRANT ... ON SCHEMA public` (superuser) **и** `CREATE TABLE` (`orders-schema.sql`). Без таблицы `POST /api/orders` → **500** (а health при этом 200!).
- **firewalld** в мигрированном CentOS закрывает 8080 → `systemctl stop firewalld`.
