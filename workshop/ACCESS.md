# Доступ: по SSH с bastion и по доменному имени (без port-forward)

Дополнение к [`README.md`](README.md). Это **альтернативный путь для подготовленного стенда**: оператор даёт вам bastion-хост, вы заходите на него по SSH и работаете с кластером прямо там, а приложение открывается по доменному имени. Классический путь (свой ноутбук + `kubectl`/`virtctl` + `virtctl port-forward`) остаётся в [`README.md`](README.md) без изменений.

## 1. Заходим по SSH и работаем с kubectl/virtctl на bastion

Оператор поднимает общий **bastion** с уже установленными `kubectl`, `virtctl`, `git` и с вашим kubeconfig в `~/.kube/config`. Вы просто заходите по SSH — ставить что-либо на свой ноутбук не нужно:

```bash
ssh <user>@<bastion>
```

Дальше вся работа идёт **прямо на bastion** через `kubectl` и `virtctl`:

```bash
kubectl get vminstances                       # смотреть/управлять своим тенантом
kubectl apply -f app-1.yaml                   # поднять свою app-VM
virtctl ssh ubuntu@vmi/vm-instance-app-1      # зайти в гостя (без port-forward)
virtctl console vmi/vm-instance-app-1         # serial-консоль VM
```

- Отдельный `virtctl port-forward` держать не нужно — `virtctl ssh` тоннелирует поверх вашего доступа к кластеру. Цель для `virtctl` — имя VMI (`vm-instance-app-1`), не имя приложения `app-1`.
- kubeconfig уже на bastion, `kubectl` сразу видит ваш тенант.

## 2. Приложение — по доменному имени (без port-forward)

Оператор заранее создаёт в каждом тенанте `Service` на приложение (порт `80 -> 8080`) и `Ingress` с хостом `app.workshopXX.example.org` (XX — ваш номер). Участнику с ingress ничего делать не нужно.

Как только вы подняли `VMInstance app-1` и приложение внутри слушает `8080`, магазин публикуется по домену — проверяйте из браузера или `curl`, без туннеля и без `localhost:8080`:

```bash
curl -s https://app.workshopXX.example.org/actuator/health

curl -s -X POST https://app.workshopXX.example.org/api/orders \
  -H 'Content-Type: application/json' -d '{"item":"test"}'

curl -s https://app.workshopXX.example.org/api/orders
```

- Пока app-VM не создана или ещё грузится, домен отвечает `503` — это нормально: ingress ждёт бэкенд. После старта VM (порт 8080 слушается) — `200`, и заказ виден в списке.
- Домен `example.org` здесь как пример: реальный хост тура подскажет оператор.

## Когда что использовать

| Ситуация | Способ |
| --- | --- |
| Подготовленный стенд (есть bastion и домены) | SSH на bastion + `kubectl`/`virtctl` там; приложение по `https://app.workshopXX.example.org` |
| Свой ноутбук / отладка на «голом» тенанте | `kubectl`/`virtctl` локально + `virtctl port-forward ... 8080:8080` (см. [`README.md`](README.md)) |
| Нужна оболочка внутри VM | `virtctl ssh ubuntu@vmi/vm-instance-app-1` |
