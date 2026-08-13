# 🚀 Воркшоп: миграция VMware-VM в Cozystack

Раздатка для участника (на 1 страницу). Мигрируем «легаси»-приложение из VMware
в облачную платформу Cozystack — **своими руками, self-service**.

---

## Что будем делать

```
Вход в тенант  →  свой S3-бакет  →  conversion-VM (virt-v2v: OVA → qcow2)
      →  заливаем образ в бакет  →  app-VM из своего образа
      →  managed Postgres + Kafka  →  подключаем приложение  →  заказы летят в PG + Kafka
```

1. Заходим в **свой тенант** (дашборд, свой логин).
2. Создаём **свой S3-бакет** под образ.
3. Поднимаем **conversion-VM** и конвертируем VMware-OVA в qcow2 (`virt-v2v`).
4. Заливаем свой образ в бакет (`mc`).
5. Поднимаем **app-VM** из своего образа.
6. Поднимаем **managed Postgres + Kafka** из каталога.
7. Подключаем приложение к managed → заказы пишутся в Postgres и летят в Kafka.

---

## Доступы (выдаёт ведущий)

- **Дашборд:** https://dashboard.workshop.aenix.io
- **Логин / пароль:** `pXX` / *(выдаётся на воркшопе)*
- **kubeconfig:** в дашборде → **Info → Secrets → `kubeconfig-tenant-pXX`**
  (нужен плагин `kubectl oidc-login` / kubelogin — при первом `kubectl` откроется браузер Keycloak)

---

## 📦 Полная инструкция, манифесты и скрипты

Всё пошагово (со скринами, готовыми манифестами для копипаста и скриптами):

👉 **https://github.com/aenix-org/cozystack-workshop-cis/blob/main/docs/PARTICIPANT_MIGRATION_FLOW.md**

Скрипты — `docs/scripts/` в той же репе:

| Файл | Что делает |
| --- | --- |
| `convert.sh` | качает OVA, `virt-v2v` → qcow2, заливает в свой бакет |
| `netfix-dhcp.sh` | переключает eth0 мигрированной VM на DHCP (pod-NIC) |
| `connect-managed.sh` | переключает приложение на managed DNS |
| `orders-schema.sql` | таблица `orders` + сид для managed Postgres |

---

## ⚡ Шпаргалка команд

**Доступ к VM** (замени `pXX` на свой тенант):

```bash
# app-VM (CentOS) — root / cozydemo
virtctl console --namespace=tenant-pXX vm-instance-app-1

# conversion-VM (ubuntu) — ubuntu / ubuntu
virtctl ssh --namespace=tenant-pXX ubuntu@vm-instance-convert

# проброс приложения на localhost
virtctl port-forward --namespace=tenant-pXX vm-instance-app-1 8088:8080
```

**Проверки:**

```bash
# health: 200 = Postgres и Kafka живы, приложение подключилось
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/actuator/health

# создать заказ (пишется в Postgres + событие в Kafka)
curl -s -X POST http://localhost:8080/api/orders \
  -H 'Content-Type: application/json' -d '{"item":"test"}'
```

---

## ⚠️ Частые грабли

- **conversion-VM — только `ubuntu-20.04`** (24.04 kernel panic, 22.04 ломает virt-v2v).
- **VMDisk `storage` > размера каталожного образа** (иначе clone fail; удаление зависает в Terminating).
- После старта app-VM: **сначала netfix** (eth0 → DHCP, ребут), **потом connect** (конфиг на managed DNS). Порядок важен.
- **Схема БД — два шага:** `GRANT ... ON SCHEMA public` (superuser) **и** `CREATE TABLE` (`orders-schema.sql`). Без таблицы `POST /api/orders` → **500** (а health при этом 200!).
- **firewalld** в мигрированном CentOS закрывает 8080 → `systemctl stop firewalld`.
