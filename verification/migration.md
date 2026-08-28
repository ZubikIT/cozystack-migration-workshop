# Путь миграции: что выполнено на стенде, по шагам

Прогон постов из [`../bastion/chat/`](../bastion/chat/) на выданной виртуалке,
тенант `tenant-workshop80`. Ниже — только то, что реально выполнялось, и что ответил стенд.

## Шаг 0. Уборка

Учебный кластер `lab` из лабы 00 удалён — он не помещался в квоту тенанта и держал
660m из 800m `requests.cpu`. После удаления освободилось: `requests.cpu 410m / 800m`.

```
$ kubectl delete kubernetes.apps.cozystack.io lab -n tenant-workshop80
kubernetes.apps.cozystack.io "lab" deleted
```

## Шаг 1. Бакет

Уже был создан до начала прогона.

```
$ kubectl get buckets.apps.cozystack.io -n tenant-workshop80
my-images   True   93s   e6ba931dbd1c
```

Секрет `bucket-my-images-app-credentials`, четыре ключа — `accessKey`, `bucketName`,
`endpoint`, `secretKey`. Как и написано в посте 14.

⚠️ **Командой их не прочитать.** `kubectl auth can-i get secrets` → `no`. Работает только
дашборд. Для пути через виртуалку это существенно: пост 14 отправляет за ключами в
дашборд, и это единственный работающий способ — командой не выйдет.

## Шаг 2. Машина-конвертер

```
$ cd ~/workshop && kubectl apply -f manifests/02-conversion-vm.yaml
vmdisk.apps.cozystack.io/convert-tools created
vminstance.apps.cozystack.io/convert created

$ kubectl get vminstance,vmdisk -n tenant-workshop80
convert         True   33s
convert-tools   True   33s
```

Поднялась за 33 секунды.

**Вход в консоль работает:**

```
$ virtctl console --namespace=tenant-workshop80 vm-instance-convert
ubuntu@vm-instance-convert:~$ cloud-init status; which virt-v2v mc qemu-img
status: error
/usr/bin/virt-v2v
/usr/local/bin/mc
/usr/bin/qemu-img
```

Логин `ubuntu` / пароль `ubuntu` из `cloudInit` принимается. Инструменты установлены,
хотя `cloud-init` рапортует `error` — на работу это не повлияло.

## Шаг 3. Конвертация образа

Скрипт скачался внутрь машины по ссылке из поста — интернет у неё есть:

```
$ curl -fsSLO https://raw.githubusercontent.com/ZubikIT/cozystack-migration-workshop/master/bastion/scripts/convert.sh
$ wc -l convert.sh
44 convert.sh
```

Ключи бакета подставлены, проверены `mc` — подключение к бакету проходит.

### 🐞 Найдено и починено: проверка заполнения всегда врёт

Пост 18 предлагал убедиться, что заглушек не осталось, так:

```bash
grep ВСТАВЬТЕ convert.sh || echo "всё заполнено, можно запускать"
```

Но строка 7 самого скрипта — это заголовок `# ВСТАВЬТЕ СВОИ ЗНАЧЕНИЯ.`, и `grep` находит
её всегда. Проверено: все три значения подставлены, `grep -c ВСТАВЬТЕ` возвращает `1`.
Участник, заполнивший всё правильно, никогда не увидит «всё заполнено» и решит, что
ошибся.

Исправлено на `grep ВСТАВЬТЕ_` — с подчёркиванием, как в самих заглушках
(`ВСТАВЬТЕ_bucketName`, `ВСТАВЬТЕ_accessKey`, `ВСТАВЬТЕ_secretKey`). Заголовок с пробелом
больше не совпадает.

### Запуск

```
$ screen -dmS convert bash -c "sudo bash convert.sh > convert.log 2>&1"
== 1. nested-virt? (если /dev/kvm нет -> TCG, медленнее, но работает) ==
  /dev/kvm НЕТ -> LIBGUESTFS_BACKEND=direct (TCG)
== 2. качаю исходный OVA ==
[  28.8] Converting CentOS Linux release 7.8.2003 (Core) to run on KVM
```

Режим эмуляции — ровно как предупреждает пост.
