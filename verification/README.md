# Журнал проверки: прогон материалов на стенде

Здесь лежит то, что реально выполнялось на выданной виртуалке, и что из этого
получилось. Сырые выводы команд — в [`logs/`](logs/), по файлу на лабу.

**Где выполнялось:** виртуалка воркшопа, `ssh workshop80@157.180.61.252 -p 30821`,
тенант `tenant-workshop80`, кластер платформы `api.workshop.aenix.io`.
**Когда:** 28 августа 2026.

## Что за окружение

| Проверка | Результат |
|---|---|
| Вход по SSH паролем, без ключа | работает |
| `kubectl config current-context` | `tenant-workshop80` |
| `kubectl get vminstance` | отвечает, Keycloak не спрашивает |
| Виртуалка общая на всех участников | да, в `/home` лежат `workshop79`…`workshop95` |
| Выход в интернет с виртуалки | **отсутствует** |
| `sudo` на виртуалке | **недоступен**, просит пароль |

Установленные инструменты:

| Есть | Нет |
|---|---|
| `kubectl` v1.34.3, `virtctl` v1.8.4, `git`, `curl`, `wget`, `python3` | `helm`, `flux`, `psql`, `jq`, `mongosh`, `clickhouse-client`, `docker`, `sshpass` |

## Статическая проверка репозитория

Прогнана локально, до выхода на стенд.

| Что проверялось | Итог |
|---|---|
| Разбор всех YAML (76 файлов в `labs/` и `manifests/`) | все читаются; шаблоны Helm-чарта лабы 13 не в счёт — там Go-шаблоны, а не YAML |
| Синтаксис shell-скриптов (`bash -n`, 38 файлов) | ошибок нет |
| Файлы, которые README велит применять (`kubectl apply -f …`) | все на месте |
| Плейсхолдер `XX` | не встречается, кроме ASCII-арта лабы 02 и `\uXXXX` в комментарии Go |
| Ссылки на исходники | ведут на `ZubikIT/cozystack-migration-workshop`, raw отдаёт 200 |

## Прогон лаб

Заполняется по ходу.

| Лаба | Итог | Лог |
|---|---|---|
| 00 · Кластер | заказан, поднимается | [`logs/00-cluster.log`](logs/00-cluster.log) |

## Что нашлось

### 1. Лаба 00: команда получения `lab.kubeconfig` не работает

`bastion/labs/00-cluster/README.md:305` предлагает достать кубконфиг учебного кластера
из секрета. Под учёткой участника это запрещено:

```
$ kubectl auth can-i get secrets -n tenant-workshop80
no
$ kubectl -n tenant-workshop80 get secret kubernetes-lab-admin-kubeconfig -o name
Error from server (Forbidden): secrets "kubernetes-lab-admin-kubeconfig" is forbidden:
User "system:serviceaccount:tenant-workshop80:workshop80" cannot get resource "secrets"
```

При этом строкой выше README утверждает обратное: «Cozystack заводит на ваш кластер
отдельное правило доступа, разрешающее читать ровно этот секрет». Такого правила нет.
Работает только второй способ, через дашборд: секрет `kubernetes-lab-admin-kubeconfig`
на странице приложения `lab` виден, ключей в нём ровно четыре — как и написано.

### 2. Лабы рассчитаны на другой доступ, чем есть на виртуалке

В 10 README и 5 `check.sh` — 43 команды вида `kubectl --kubeconfig ~/.kube/workshop`.
На виртуалке лежит только `~/.kube/config`, и это токен сервис-аккаунта: прав у него
меньше, чем у учётки из дашборда. Файла `~/.kube/workshop` на стенде нет.

### 3. Виртуалку под лабы не готовили

* папки `labs/` в `~/workshop` нет — там только `README.md`, `chat/`, `manifests/`, `scripts/`;
* нет `helm`, `flux`, `psql`, `jq`, `mongosh`, `clickhouse-client`, `docker`;
* поставить их нечем: `sudo` требует пароль, интернета с виртуалки нет.

Проверка сети с виртуалки:

```
https://github.com               нет связи
https://raw.githubusercontent.com  нет связи
https://get.helm.sh              нет связи
https://s3.workshop.aenix.io     403   (то есть достижим)
```

Отсюда же следует, что `git clone` из `labs/00-cluster/README.md:101`
и `labs/01-deploy/README.md:94` на виртуалке не отработает.

### 4. Материалы на стенде и в репозитории разошлись

Скачал `~/workshop` со стенда и сравнил.

| Что | Итог |
|---|---|
| `scripts/` — все четыре файла | совпадают байт в байт |
| `manifests/` — все четыре | первая строка комментария разная |

На стенде: `# namespace (tenant-workshopNN) уже подставлен под ваш тенант при подготовке виртуалки.`
В репозитории было: `# Перед применением замените tenant-workshop80 на свой namespace.` —
для пути через виртуалку это неверно, номер там подставлен заранее. Приведено к смыслу
стенда.

## Что сделано на стенде

| Действие | Итог |
|---|---|
| `kubectl apply -f labs/00-cluster/cluster.yaml` | `kubernetes.apps.cozystack.io/lab created` |
| Ожидание готовности | `lab True 2m` — около двух минут |
| Кластер виден в дашборде | да, скриншоты в [`screenshots/`](screenshots/) |
| `lab.kubeconfig` | **не получен** — см. пункт 1 |

Лабы 01–14 без `lab.kubeconfig` не запускаются, поэтому дальше прогон остановлен.
