

# Домашнее задание к занятию «Запуск приложений в K8S»

### Цель задания

В тестовой среде для работы с Kubernetes, установленной в предыдущем ДЗ, необходимо развернуть Deployment с приложением, состоящим из нескольких контейнеров, и масштабировать его.

---

### Чеклист готовности к домашнему заданию

1. Установленное k8s-решение (например, MicroK8S).
2. Установленный локальный kubectl.
3. Редактор YAML-файлов с подключённым git-репозиторием.

---

### Инструменты и дополнительные материалы, которые пригодятся для выполнения задания

1. [Описание](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) Deployment и примеры манифестов.
2. [Описание](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) Init-контейнеров.
3. [Описание](https://github.com/wbitt/Network-MultiTool) Multitool.

---

### Задание 1. Создать Deployment и обеспечить доступ к репликам приложения из другого Pod

1. Создать Deployment приложения, состоящего из двух контейнеров — nginx и multitool. Решить возникшую ошибку.
2. После запуска увеличить количество реплик работающего приложения до 2.
3. Продемонстрировать количество подов до и после масштабирования.
4. Создать Service, который обеспечит доступ до реплик приложений из п.1.
5. Создать отдельный Pod с приложением multitool и убедиться с помощью `curl`, что из пода есть доступ до приложений из п.1.

---

### Задание 2. Создать Deployment и обеспечить старт основного контейнера при выполнении условий

1. Создать Deployment приложения nginx и обеспечить старт контейнера только после того, как будет запущен сервис этого приложения.
2. Убедиться, что nginx не стартует. В качестве Init-контейнера взять busybox.
3. Создать и запустить Service. Убедиться, что Init запустился.
4. Продемонстрировать состояние пода до и после запуска сервиса.

--- 
# Разбор решения задачи 1
### Создание Deployment с nginx и multitool
#### Создал файл-Manifest для pod `deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-multitool
  labels:
    app: nginx-multitool
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-multitool
  template:
    metadata:
      labels:
        app: nginx-multitool
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
        - name: multitool
          image: wbitt/network-multitool
```
#### Применил его и проверил результат
```bash
kubectl apply -f deployment.yaml
kubectl get pods
```
Контейнер multitool упал с ошибкой
![](<Pasted image 20260826215512.png>)

Оба контейнера в поде по умолчанию хотят слушать порт 80. nginx как веб-сервер, multitool тоже поднимает встроенный nginx на 80/443. Поды в Kubernetes используют одно network namespace на все контейнеры, поэтому два процесса не могут слушать один и тот же порт одновременно. Возможные варианты решения - изменить порт multitool или изменить порт nginx.
По выводу видно, что 80 порт первым занял nginx, а падает multitool:
- `nginx: State: Running, Restart Count: 0` - nginx запустился первым и занял порт 80;
- `multitool: State: Waiting, Reason: CrashLoopBackOff, Last State: Terminated, Exit Code: 1` - контейнер стартует, его встроенный nginx пытается забиндить порт 80, получает отказ (порт уже занят первым контейнером в общем network namespace пода) и падает с кодом 1;
- Событие `Warning BackOff ... Back-off restarting failed container multitool` - kubelet перезапускает контейнер с растущей задержкой, поэтому интервал между рестартами со временем увеличивается.
#### Меняю порты multitool. Обновленный файл-manifest `deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-multitool
  labels:
    app: nginx-multitool
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-multitool
  template:
    metadata:
      labels:
        app: nginx-multitool
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
        - name: multitool
          image: wbitt/network-multitool
          env:
            - name: HTTP_PORT
              value: "1180"
            - name: HTTPS_PORT
              value: "11443"
```
Это официальный (https://hub.docker.com/r/wbitt/network-multitool) способ исправить ошибку занятых портов 80 и 443 в multitool:
```yaml
        - name: multitool
          image: wbitt/network-multitool
          env:
            - name: HTTP_PORT
              value: "1180"
            - name: HTTPS_PORT
              value: "11443"
          ports:
            - containerPort: 1180
```
значения env - строки, поэтому в кавычках. Декларация `containerPort` формально ни на что не влияет.
#### Применил и проверил:
```bash
kubectl apply -f deployment.yaml
kubectl get pods -w
```
![](<Pasted image 20260826220700.png>)
Cтарый под был `nginx-multitool-6c85fd788-*`, новый  `nginx-multitool-675fb777cc-*`. Когда изменился шаблон пода в Deployment (добавил env), контроллер выполнил rolling update: создал новый ReplicaSet (`675fb777cc`) с исправленной спецификацией, поднял его под и только потом удалил под старого ReplicaSet.
![](<Pasted image 20260826220915.png>)
#### увеличиваю количество реплик до 2
Есть 2 способа: 
- Императивный: `kubectl scale deployment nginx-multitool --replicas=2`. Быстрый, но расходится расходится с YAML-манифестом в git
- Декларативный: Поменять `replicas: 2` в манифесте и `kubectl apply`. Состояние кластера совпадает с репозиторием
Делаю через корректировку manifest файла `deployment.yaml`: в `spec` поменял `replicas: 1` на `replicas: 2`. Применил:
```bash
kubectl apply -f deployment.yaml
kubectl get pods -w -o wide
```
![](<Pasted image 20260826221321.png>)
#### Создаю Service. Создал файл `service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-multitool-svc
spec:
  selector:
    app: nginx-multitool
  ports:
    - name: nginx
      port: 80
      targetPort: 80
    - name: multitool
      port: 1180
      targetPort: 1180
```
- `type` не указан. По умолчанию будет `ClusterIP`, то есть сервис доступен только внутри кластера. 
- У сервиса **два порта**: 80 ведёт на nginx, 1180 - на multitool. Когда у Service больше одного порта, каждому нужно давать уникальное `name` - иначе API-сервер отклонит манифест.
- `selector` должен совпадать с `labels` подов в шаблоне Deployment. 
#### Применил:
```bash
kubectl apply -f service.yaml
kubectl get svc
kubectl get endpoints nginx-multitool-svc
```
![](<Pasted image 20260826221823.png>)

Service работает правильно: `nginx-multitool-svc` получил ClusterIP `10.152.183.209` и привязался к обоим подам - в endpoints видны `10.1.120.120` и `10.1.120.121` на портах 80 и 1180 (вывод просто сокращён до "+ 1 more..."). Значит selector совпал с labels, и балансировка пойдёт на обе реплики.
Предупреждение `v1 Endpoints is deprecated in v1.33+` -  в свежих версиях Kubernetes классический объект Endpoints заменён на EndpointSlice, который лучше масштабируется (группирует до ~100 эндпоинтов в слайс). (https://kubernetes.io/blog/2025/04/24/endpoints-deprecation/)

```bash
kubectl get endpointslice -l kubernetes.io/service-name=nginx-multitool-svc
```
![](<Pasted image 20260826222219.png>)
#### Создаk файл `multitool-pod.yaml`:
Cоздал отдельный Pod с multitool и проверил из него доступ к приложению.
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multitool-test
spec:
  containers:
    - name: multitool
      image: wbitt/network-multitool
```
Это под без Deployment для разовых отладочных задач. Он не будет пересоздаваться контроллером, живёт, до удаления.
#### Применил и запустил. Выполнил  из тестового пода curl к **обоим** контейнерам через Service:
```bash
kubectl apply -f multitool-pod.yaml
kubectl get pod multitool-test
kubectl exec -it multitool-test -- curl -s nginx-multitool-svc
kubectl exec -it multitool-test -- curl -s nginx-multitool-svc:1180
```
первая команда вернула HTML главной страницы nginx (`Welcome to nginx!`), вторая - HTML-страницу multitool, где в тексте указан IP конкретного пода, который ответил. Выполнил вторую команду несколько раз подряд. В ответах чередуются IP `10.1.120.120` и `10.1.120.121`. Это показывает работу балансировщика - Service распределяет запросы между репликами.
![](<Pasted image 20260826222850.png>)

# Разбор решения задачи 2

#### Создал manifest-файл `deployment-nginx-init.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-init
  labels:
    app: nginx-init
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-init
  template:
    metadata:
      labels:
        app: nginx-init
    spec:
      initContainers:
        - name: wait-for-service
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              until nslookup nginx-init-svc; do
                echo "waiting for nginx-init-svc...";
                sleep 2;
              done;
              echo "Service found, starting nginx"
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```
- initContainers - один init-контейнер wait-for-service на busybox.
- Цикл until nslookup nginx-init-svc - опрашивает DNS каждые 2 секунды. BusyBox имеет встроенный nslookup, поэтому дополнительных образов не нужно.
- Имя сервиса в nslookup (nginx-init-svc) должно точно совпадать с именем Service, который создадим позже.
  
#### Примениk манифест и проверил статус:
```bash
kubectl apply -f deployment-nginx-init.yaml
kubectl get pods -w
kubectl logs nginx-init-69b87c85cc-grvx8  -c wait-for-service
```
- Под завис в статусе Init:0/1 - nginx не стартовал.

![](<Pasted image 20260827120604.png>)

![](<Pasted image 20260827121344.png>)

#### Создал manifest-файл `service-nginx-init.yaml`
``` yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-init-svc
spec:
  selector:
    app: nginx-init
  ports:
    - port: 80
      targetPort: 80
```
- Имя сервиса nginx-init-svc - точно как в команде nslookup init-контейнера. При несовпадении или опечатке будет вечный Init:0/1.
- Selector app: nginx-init совпадает с labels пода из Deployment. Пока под в Init, у него нет готовых endpoints, но DNS-запись для Service создаётся сразу при создании объекта,  поэтому сценарий трюк с nslookup работает, не дожидаясь endpoints.
#### Применил manifest-файл 
```bash
kubectl apply -f service-nginx-init.yaml
kubectl get pods -w
kubectl get pods
kubectl logs nginx-init-69b87c85cc-grvx8 -c wait-for-service | tail -3
```

И ... снова задуманная схема дала сбой...

![](<Pasted image 20260827125428.png>)

![](<Pasted image 20260827125449.png>)

Под должен был перейти в Running в течение нескольких секунд после создания сервиса. Однако он всё ещё в Init:0/1 через минуту, и это ненормально. Для диагностики проверяю:
- что сервис реально существует и его точное имя:
```bash
kubectl get svc nginx-init-svc
```
- Свежие логи init-контейнера - что nslookup отвечает 
``` bash
kubectl logs nginx-init-69b87c85cc-grvx8 -c wait-for-service --tail=10
```
- Проверка DNS из живого пода (multitool-test)
```bash
kubectl exec -it multitool-test -- nslookup nginx-init-svc
kubectl exec -it multitool-test -- nslookup nginx-init-svc.default.svc.cluster.local
```
- Состояние CoreDNS
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```
Проблема не в сервисе и не в DNS кластера, а в busybox nslookup (https://github.com/gliderlabs/docker-alpine/issues/539)
Это описанный баг BusyBox: его nslookup (реализация на musl/uclibc) некорректно обрабатывает список search-доменов из /etc/resolv.conf. Он возвращает ошибку (exit code 1), если хотя бы один из запросов по search-доменам ответил NXDOMAIN - даже когда другой запрос успешно нашёл имя. В логе init-контейнера `nginx-init-svc.default.svc.cluster.local` существует, но все равно продолжает перебирать svc.cluster.local, cluster.local, ru-central1.internal, auto.internal. Из-за NXDOMAIN на этих суффиксах считает весь запрос неудачным. 
![](<Pasted image 20260827130834.png>)
При этом multitool-test резолвил нормально, так как на нём Alpine с более свежим стеком и другим поведением резолвера. 
Таким образом, если запросить полное имя `nginx-init-svc.default.svc.cluster.local`, перебор search-доменов не нужен, и busybox отвечает корректно.

#### В manifest-файле `deployment-nginx-init.yaml`  поменял команду init-контейнера на полное FQDN service:
```yaml
          command:
            - sh
            - -c
            - |
              until nslookup nginx-init-svc.default.svc.cluster.local; do
                echo "waiting for nginx-init-svc...";
                sleep 2;
              done;
              echo "Service found, starting nginx"
```
#### пересоздал Deployment и проверил результат:
```bash
kubectl delete deployment nginx-init
kubectl apply -f deployment-nginx-init.yaml
kubectl get pods -w
```
![](<Pasted image 20260827131431.png>)

#### Проверил логи init контейнера. Сервис успешно обнаруживается nslookup  BusyBox.

![](<Pasted image 20260827131513.png>)

#### nginx реально отвечает через сервис:

![](<Pasted image 20260827131545.png>)




