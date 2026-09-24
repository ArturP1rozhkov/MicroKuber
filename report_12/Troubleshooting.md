

## Задание. 
При деплое приложение web-consumer не может подключиться к auth-db. Необходимо это исправить.
Установить приложение по команде: 
```bash
kubectl apply -f https://raw.githubusercontent.com/netology-code/kuber-homeworks/main/3.5/files/task.yaml
```

Выявить проблему и описать. Исправить проблему, описать, что сделано. Продемонстрировать, что проблема решена.
##### Файл - манифест 
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-consumer
  namespace: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-consumer
  template:
    metadata:
      labels:
        app: web-consumer
    spec:
      containers:
      - command:
        - sh
        - -c
        - while true; do curl auth-db; sleep 5; done
        image: radial/busyboxplus:curl
        name: busybox
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-db
  namespace: data
spec:
  replicas: 1
  selector:
    matchLabels:
      app: auth-db
  template:
    metadata:
      labels:
        app: auth-db
    spec:
      containers:
      - image: nginx:1.19.1
        name: nginx
        ports:
        - containerPort: 80
          protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: auth-db
  namespace: data
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: auth-db
```
## Разбор решения задания
### Инфраструктуру поднимаю с переиспользованием терраформ-файлов из предыдущего задания.  
![](<Pasted image 20260924192457.png>)

![](<Pasted image 20260924192529.png>)

#### Ошибка установки manifest файла 
![](<Pasted image 20260924193239.png>)

- В манифесте нет объектов `Namespace`. Строка `namespace: web` не создаёт `namespace`, а только говорит, куда положить `Deployment`. То же самое с `data`. Пока таких пространств имён нет, API отклоняет все три объекта, поэтому в выводе три NotFound.

![](<Pasted image 20260924193836.png>)
##### Лечим: 
```bash
kubectl create namespace web
   kubectl create namespace data
   kubectl apply -f https://raw.githubusercontent.com/netology-code/kuber-homeworks/main/3.5/files/task.yaml
   kubectl get deploy,svc,pods -n web
   kubectl get deploy,svc,pods -n data
```

![](<Pasted image 20260924194048.png>)
- ErrImagePull и ContainerCreating означают, что kubelet не смог взять образ radial/busyboxplus:curl. Пока образ не скачан, curl auth-db ни разу не выполнялся.

```bash
kubectl get pods -n web -o wide
kubectl describe pod -n web -l app=web-consumer | sed -n '/Events/,$p'
kubectl get events -n web --sort-by='.lastTimestamp'
kubectl describe pod -n web web-consumer-7757db9bf-hz6cq
```

![](<Pasted image 20260924194626.png>)

![](<Pasted image 20260924194646.png>)

- `ImagePullBackOff` уже подтверждён: оба пода назначены на воркеры и получили IP, но контейнер не создан. Пустой вывод второй команды значит, что фильтр `sed` ничего не захватил.
- Образ `radial/busyboxplus:curl` собран в старом формате `Docker schema 1`. `Containerd` на `Kubernetes 1.37` такой манифест больше не распаковывает, поэтому `kubelet` повторяет `pull` и уходит в `ImagePullBackOff`. Оба воркера получили одну и ту же ошибку, `registry` при этом доступен.
- команда `curl auth-db` ещё ни разу не запускалась.

#### меняю образ клиента и оставляю команду curl auth-db

```bash
kubectl set image deployment/web-consumer busybox=curlimages/curl -n web
kubectl rollout status deployment/web-consumer -n web
kubectl get pods -n web
kubectl logs -n web -l app=web-consumer --tail=20
```

![](<Pasted image 20260924195151.png>)

- Поды клиента поднялись и находятся в статусе `Running`
- `curl: (6) Could not resolve host: auth-db` - ошибка кроется в исходном деплойменте. `curl: (6)` означает, что имя `auth-db` не резолвится. До порта и до `nginx` запрос не дошёл: иначе был бы `connection refused` или HTTP-ответ.
- Под лежит в `namespace` `web`, а `Service` `auth-db` - в `data`. Короткое имя ищется только в `namespace` пода, то есть как `auth-db.web`. Сервис в другом `namespace` так не находится. Селектор и порт 80 здесь ни при чём: до выбора `endpoint` DNS уже остановился.

##### Смотрю как отображаются короткие и длинные имена app
```bash
kubectl get endpoints -n data auth-db
kubectl exec -n web deploy/web-consumer -- cat /etc/resolv.conf
kubectl exec -n web deploy/web-consumer -- curl -sv --max-time 5 http://auth-db.data
```

![](<Pasted image 20260924195940.png>)

- Короткое имя `auth-db` не находится из `namespace web`. Cервис жив и отвечает.
- `ENDPOINTS` равен `192.168.133.194:80`, это IP пода `nginx`. Cелектор и порт исправны. `EndpointSlice` с именем `auth-db` не нашёлся, потому что у slice другое имя, обычно `auth-db-<суффикс>`. 
- В `resolv.conf` search начинается с `web.svc.cluster.local`, поэтому `curl auth-db` ищет `auth-db.web.svc.cluster.local`. Имени `auth-db.data` хватило: `search` дописал `svc.cluster.local`, `curl` получил `ClusterIP 10.96.54.71` и ответ `HTTP/1.1 200` от `nginx/1.19.1`.
  
#### Исправляю строку в команде контейнера web-consumer:
- было:
```yaml
command:
  - sh
  - -c
  - while true; do curl auth-db; sleep 5; done
```
- Нужно заменить только последнюю строку:
```yaml
command:
  - sh
  - -c
  - while true; do curl auth-db.data.svc.cluster.local; sleep 5; done
```
- то есть `do curl auth-db` на `do curl auth-db.data.svc.cluster.local`
##### Или командой:

```bash
kubectl patch deployment web-consumer -n web --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/command/2","value":"while true; do curl auth-db.data.svc.cluster.local; sleep 5; done"}]'
kubectl rollout status deployment/web-consumer -n web
kubectl logs -n web -l app=web-consumer --tail=5
```

![](<Pasted image 20260924201534.png>)

- `patch` делает то же самое: путь `/spec/template/spec/containers/0/command/2` означает `«нулевой контейнер, второй элемент массива command»`, считая с нуля. Это строка цикла. В неё подставляется то же самое, но с полным DNS-именем сервиса: имя, namespace data, зона `svc.cluster.local`. Короткое `auth-db` Kubernetes ищет в `namespace` пода, то есть в `web`. Полное имя указывает на `Service` в data напрямую и не зависит от search в `resolv.conf`.
- Вывод перемешался, потому что `kubectl logs -l app=web-consumer` склеил логи всех подов с этой меткой. Строки `Could not resolve host: auth-db` - старый `ReplicaSet`, он ещё попал в выборку. Фрагмент HTML `nginx` - новый под: имя разрешилось, соединение прошло, сервер ответил страницей.
##### Более чистый вывод:
```bash
kubectl get pods -n web
kubectl logs -n web web-consumer-5f5f865855-qkdj7 --tail=20
```

![](<Pasted image 20260924201745.png>)

Проблема решена. Новые поды `web-consumer-5f5f865855-qkdj7` (и `web-consumer-5f5f865855-w8ggb` тоже) пишут только страницу `nginx`, без `Could not resolve host`. Значит, имя `auth-db.data.svc.cluster.local` резолвится, `Service` отдает под `auth-db`, а `nginx` отвечает `200`.

### Итог:
- После создания `namespace` `web` и `data` клиент не подключался к `auth-db`. Сначала мешал образ `radial/busyboxplus:curl` : `containerd` не принимает `schema 1`, поды были в `ImagePullBackOff`. После замены образа на `curlimages/curl` команда из задания дала `curl: (6) Could not resolve host: auth-db`.
- Причина: `Service auth-db` находится в `namespace` `data`, а под - в `web`. Короткое имя ищется в `namespace` пода. `Endpoints` при этом был живой, `192.168.133.194:80`, а `curl http://auth-db.data` вернул `HTTP 200` от `nginx`.
- Исправление. В команде контейнера `web-consumer` имя `auth-db` заменено на `auth-db.data.svc.cluster.local`.
- Лог нового пода содержит `Welcome to nginx!` и не содержит ошибки резолвинга. 



