

# Домашнее задание к занятию «Сетевое взаимодействие в Kubernetes»

### Цель задания

Научиться настраивать доступ к приложениям в Kubernetes:
- Внутри кластера через **Service** (ClusterIP, NodePort).
- Снаружи кластера через **Ingress**.

Это задание поможет вам освоить базовые принципы сетевого взаимодействия в Kubernetes — ключевого навыка для работы с кластерами.
На практике Service и Ingress используются для доступа к приложениям, балансировки нагрузки и маршрутизации трафика. Понимание этих механизмов поможет вам упростить управление сервисами в рабочих окружениях и снизит риски ошибок при развёртывании.

------

## **Подготовка**
### **Чеклист готовности**
- Установлен Kubernetes (MicroK8S, Minikube или другой).
- Установлен `kubectl`.
- Редактор для YAML-файлов (VS Code, Vim и др.).

------

### Инструменты, которые пригодятся для выполнения задания

1. [Инструкция](https://microk8s.io/docs/getting-started) по установке MicroK8S.
2. [Инструкция](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fwindows%2Fx86-64%2Fstable%2F.exe+download) по установке Minikube. 
3. [Инструкция](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/)по установке kubectl.
4. [Инструкция](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-kubernetes-tools) по установке VS Code

### Дополнительные материалы, которые пригодятся для выполнения задания

1. [Описание](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) Deployment и примеры манифестов.
2. [Описание](https://kubernetes.io/docs/concepts/services-networking/service/) Описание Service.
3. [Описание](https://kubernetes.io/docs/concepts/services-networking/ingress/) Ingress.
4. [Описание](https://github.com/wbitt/Network-MultiTool) Multitool.

------

## **Задание 1: Настройка Service (ClusterIP и NodePort)**
### **Задача**
Развернуть приложение из двух контейнеров (`nginx` и `multitool`) и обеспечить доступ к ним:
- Внутри кластера через **ClusterIP**.
- Снаружи через **NodePort**.

### **Шаги выполнения**

1. **Создать Deployment** с двумя контейнерами:
   - `nginx` (порт `80`).
   - `multitool` (порт `8080`).
   - Количество реплик: `3`.
2. **Создать Service типа ClusterIP**, который:
   - Открывает `nginx` на порту `9001`.
   - Открывает `multitool` на порту `9002`.
1. **Проверить доступность** изнутри кластера:
   
```bash
 kubectl run test-pod --image=wbitt/network-multitool --rm -it -- sh
 curl <service-name>:9001 # Проверить nginx
 curl <service-name>:9002 # Проверить multitool
```

4. **Создать Service типа NodePort** для доступа к `nginx` снаружи.
5. **Проверить доступ** с локального компьютера:
   
```bash
 curl <node-ip>:<node-port>
```
 или через браузер.

### **Что сдать на проверку**
- Манифесты:
  - `deployment-multi-container.yaml`
  - `service-clusterip.yaml`
  - `service-nodeport.yaml`
- Скриншоты проверки доступа (`curl` или браузер).


## **Задание 2: Настройка Ingress**

### **Задача**

Развернуть два приложения (`frontend` и `backend`) и обеспечить доступ к ним через **Ingress** по разным путям.

### **Шаги выполнения**
1. **Развернуть два Deployment**:
   - `frontend` (образ `nginx`).
   - `backend` (образ `wbitt/network-multitool`).
2. **Создать Service** для каждого приложения.
3. **Включить Ingress-контроллер**:
   
```bash
 microk8s enable ingress
```
   
1. **Создать Ingress**, который:
   - Открывает `frontend` по пути `/`.
   - Открывает `backend` по пути `/api`.
1. **Проверить доступность**:

```bash
 curl <host>/
 curl <host>/api
```
   
 или через браузер.

### **Что сдать на проверку**
- Манифесты:
  - `deployment-frontend.yaml`
  - `deployment-backend.yaml`
  - `service-frontend.yaml`
  - `service-backend.yaml`
  - `ingress.yaml`
- Скриншоты проверки доступа (`curl` или браузер).

---

## Шаблоны манифестов с учебными комментариями
### **1. Deployment (nginx + multitool)**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: # ПРИМЕР: "multi-container-app"
spec:
  replicas: # ЗАДАНИЕ: Укажите количество реплик
  selector:
    matchLabels:
      app: # ДОПОЛНИТЕ: Метка для селектора
  template:
    metadata:
      labels:
        app: # ПОВТОРИТЕ метку из selector.matchLabels
    spec:
      containers:
 - name: # ЗАДАНИЕ: Название первого контейнера
        image: nginx
        ports:
 - containerPort: 80
 - name: multitool
        image: wbitt/network-multitool
        ports:
 - containerPort: 8080
        env:
 - name: HTTP_PORT
          value: "8080" # КЛЮЧЕВОЙ МОМЕНТ: Порт должен совпадать с containerPort
```

### **2. Ingress (для frontend и backend)**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: # ЗАДАНИЕ: Придумайте имя, допустим example-ingress
  annotations:  # ВАЖНО: Эта аннотация нужна для rewrite правил
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
 - http:
      paths:
 - path: /
        pathType: Prefix
        backend:
          service:
            name: # УКАЖИТЕ: Имя frontend Service
            port:
              number: 80
 - path: /api # КЛЮЧЕВОЙ ПУТЬ: API endpoint
        pathType: Prefix
        backend:
          service:
            name: # УКАЖИТЕ: Имя backend Service
            port:
              number: 80
```

---

## **Правила приёма работы**
1. Домашняя работа оформляется в своём Git-репозитории в файле README.md. Выполненное домашнее задание пришлите ссылкой на .md-файл в вашем репозитории.
2. Файл README.md должен содержать скриншоты вывода необходимых команд `kubectl` и скриншоты результатов.
3. Репозиторий должен содержать тексты манифестов или ссылки на них в файле README.md.

---
# Разбор решения задания 1
### Создал файл `deployment-multi-container.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-container-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: multi-container-app
  template:
    metadata:
      labels:
        app: multi-container-app
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
        - name: multitool
          image: wbitt/network-multitool
          ports:
            - containerPort: 8080
          env:
            - name: HTTP_PORT
              value: "8080"
```

- replicas: 3 - количество реплик согласно задания; каждая реплика - это отдельный Pod с двумя контейнерами внутри.
- selector.matchLabels и template.metadata.labels должны совпадать буквально (app: multi-container-app), иначе Deployment не найдёт свои Pod'ы и создаст новые бесконечно.
- Имя контейнера nginx - просто читаемый идентификатор внутри Pod, не влияет на сеть.
- env.HTTP_PORT: "8080" -  по умолчанию network-multitool слушает 80 порт , и Service, настроенный на порт 8080, будет отдавать connection refused при проверке.
- Значение "8080" указано в кавычках, потому что переменные окружения в Kubernetes - это всегда строки, даже если по смыслу это число.
- при применении каждый из трёх Pod получит один общий IP-адрес для обоих контейнеров. Это значит, что nginx и multitool внутри одного Pod могут общаться друг с другом через localhost.
#### Применил deployment-multi-container.yaml
```yaml
kubectl apply -f deployment-multi-container.yaml
```

![](<Pasted image 20260828151555.png>)

![](<Pasted image 20260828151831.png>)

- У каждого Pod собственный IP из сети Calico: 10.1.120.84, 10.1.120.86, 10.1.120.88; для обращения к ним создам Service.
- Оба контейнера находятся в одном Pod и используют общую сеть Pod’а, поэтому nginx слушает 80/TCP, а multitool - 8080/TCP на одном и том же IP Pod’а.
- Переменная HTTP_PORT=8080 применена корректно, а значит backend должен принимать HTTP-трафик на 8080.
#### Создал manifest-файл `service-clusterip.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: multi-container-clusterip
spec:
  type: ClusterIP
  selector:
    app: multi-container-app
  ports:
    - name: nginx-http
      protocol: TCP
      port: 9001
      targetPort: 80
    - name: multitool-http
      protocol: TCP
      port: 9002
      targetPort: 8080service-clusterip.yaml
```
- selector.app совпадает с меткой на Pod’ах, поэтому Kubernetes автоматически сформирует список endpoint’ов из трёх Pod’ов.
- port: 9001 - порт, по которому клиент обращается к имени Service.
- targetPort: 80 - реальный порт nginx в выбранном Pod’е.
- port: 9002 направляется на targetPort: 8080, где работает multitool.
- Service предоставит стабильные DNS-имя multi-container-clusterip и ClusterIP, даже если Pod’ы будут пересозданы. port Service может отличаться от targetPort контейнера.

#### Применил и выполнил:
```bash
kubectl apply -f service-clusterip.yaml
kubectl get svc multi-container-clusterip
kubectl get endpoints multi-container-clusterip
```
![](<Pasted image 20260828152737.png>)

#### Проверка изнутри кластера
```bash
kubectl run test-pod --image=wbitt/network-multitool --rm -it -- sh
#изнутри:
curl multi-container-clusterip:9001
curl multi-container-clusterip:9002

```
![](<Pasted image 20260828152936.png>)

- 9001 вернул страницу nginx. Ответ nginx показывает стандартную заглушку.
- 9002 вернул ответ от multitool с конкретным Pod'ом-получателем multi-container-app-d7789cb84-j2rfn. Ответ multitool содержит имя Pod'а и его IP - это функция образа для диагностики для проверки балансировки нагрузки. При повторе curl multi-container-clusterip:9002 несколько раз, имя Pod'а в ответе будет меняться. Это работа round-robin балансировки между тремя репликами.
![](<Pasted image 20260828153622.png>)

#### Создал manifest-файл `service-nodeport.yaml`. Для внешнего доступа к nginx
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: multi-container-app
  ports:
    - name: nginx-http
      protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080
```

- nodePort: 30080 - порт из диапазона 30000-32767, который Kubernetes откроет на ноде. Если не указать nodePort, Kubernetes выберет случайный порт из этого диапазона автоматически - оба варианта допустимы, но явное указание удобнее для документирования.
- port: 80 - порт самого Service.
- targetPort: 80 - порт nginx внутри Pod'а, куда реально пойдёт трафик.
- По заданию этот Service нужен только для nginx.

#### Применил манифесты
```bash
kubectl apply -f service-nodeport.yaml
kubectl get svc nginx-nodeport
```
#### Проверил с облачной машины:
```bash
curl 10.130.0.23:30080
```
![](<Pasted image 20260828154439.png>)

#### С локальной машины:
```bash
curl 158.160.209.10:30080
```
![](<Pasted image 20260828154655.png>)

Доступ к поду через NodePort Service снаружи и с самой облачной машины на порт 30080 корректно работает
## Разбор решения задачи 2:
#### Включаю Ingress Controller облачной ВМ `minikube`
```bash
ssh -l yc-user 158.160.209.10
microk8s enable ingress
```

![](<Pasted image 20260828193948.png>)

#### проверил:
```bash
microk8s status
kubectl get ingressclass
kubectl get pods -A | grep -Ei 'ingress|traefik|nginx'
```

![](<Pasted image 20260828194212.png>)

MicroK8s версии 1.35 Ingress addon по умолчанию устанавливает Traefik и создаёт класс `public`; поэтому в манифесте нужно явно указать `ingressClassName: public`, а не  nginx-controller.
#### создал manifest-файл `deployment-frontend.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: nginx
          ports:
            - containerPort: 80
```
#### создал manifest-файл `deployment-backend.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: wbitt/network-multitool
          ports:
            - containerPort: 8080
          env:
            - name: HTTP_PORT
              value: "8080"
```
- Отдельные Deployment для `frontend` и `backend` - по заданию, раздельные приложения с разными метками (`app: frontend` и `app: backend`). В первом задании оба контейнера жили в одном Pod.
- `replicas: 2` - достаточно для демонстрации балансировки.
- У `backend` снова используется `HTTP_PORT=8080`, по той же причине, что и в первом задании (multitool и nginx по умолчанию слушают один и тот же 80 порт).
#### Применил манифесты:
```bash
kubectl apply -f deployment-frontend.yaml
kubectl apply -f deployment-backend.yaml
kubectl get pods -l app=frontend
kubectl get pods -l app=backend
```

![](<Pasted image 20260828195538.png>)
#### Cоздал внутренние `ClusterIP` Service. На них Ingress будет передавать HTTP-запросы
#### `service-frontend.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  type: ClusterIP
  selector:
    app: frontend
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
```

####  `service-backend.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 8080
```
- backend Service слушает 80 порт, так как Ingress направляет запросы на порт **Service**, а не напрямую на `containerPort`. Service дальше перенаправит трафик в Pod на `8080`.
#### Применил манифесты и проверил
```bash
kubectl apply -f service-frontend.yaml
kubectl apply -f service-backend.yaml

kubectl get svc frontend-service backend-service
kubectl get endpointslice \
  -l 'kubernetes.io/service-name in (frontend-service,backend-service)'
```

![](<Pasted image 20260828200425.png>)

Оба Service подключены к своим Pod’ам корректно: `frontend-service` видит два endpoint’а на порту `80`, `backend-service` - два endpoint’а на порту `8080`. Это подтверждает, что `selector` и `targetPort` настроены верно, и трафик через Service дойдёт до реальных контейнеров.
#### создал файл `ingress.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
spec:
  ingressClassName: public
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 80
```

#### Создал файл `traefik-middleware.yaml`
Кластер использует MicroK8s Ingress addon на базе Traefik, а не ingress-nginx. Поэтому аннотация `nginx.ingress.kubernetes.io/rewrite-target` из шаблона задания **не поддерживается** этим контроллером и **заменена Traefik Middleware** типа `stripPrefix`, который выполняет ту же функцию: убирает префикс `/api` перед передачей запроса в backend-сервис.
```yaml
  apiVersion: traefik.io/v1alpha1
   kind: Middleware
   metadata:
     name: strip-api-prefix
     namespace: default
   spec:
     stripPrefix:
       prefixes:
         - /api
       forceSlash: true 
```

#### Создал `backend-ingress.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend-ingress
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: default-strip-api-prefix@kubernetescrd
spec:
  ingressClassName: public
  rules:
    - http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend-service
                port:
                  number: 80
```
Эти три манифеста разделяют обязанности: `ingress.yaml` публикует frontend на `/`, `backend-ingress.yaml` отправляет `/api` в backend, а `traefik-middleware.yaml` изменяет путь перед передачей backend’у. Такое разделение понадобилось потому, что в качестве ingress в текущей версии по умолчанию используется **Traefik**, а шаблон задания рассчитан на ingress-nginx и его аннотацию rewrite (https://doc.traefik.io/traefik-hub/api-gateway/reference/routing/kubernetes/http/routers/ref-ingress-annotations)
- `ingressClassName: public` - явно указываю класс, потому что в кластере их сразу три (`nginx`, `public`, `traefik`), и Kubernetes должен знать, какой использовать; без этого поля Ingress может остаться без класса и не обработается контроллером.
- `rules` - список правил маршрутизации. Их можно разделять по доменам (`host`) и URL-путям (`path`).
- Отсутствие `host` означает: правило подходит для запросов с **любым** значением HTTP-заголовка `Host`, включая обращения по IP-адресу.
- `path: /` - начало URL-пути.
- `pathType: Prefix` означает «всё, что начинается с `/`»: `/`, `/index.html`, `/css/site.css`, `/anything`. То есть это правило - fallback для frontend. Если более точного правила нет, запрос попадёт в `frontend-service`. Traefik создаёт обработчик по данным Ingress и по умолчанию применяет сопоставление уровня `PathPrefix`.
- Порядок правил для Traefik: путь `/api` идёт **после** `/`. Traefik сопоставляет наиболее специфичный `Prefix` первым независимо от порядка в файле, поэтому конфликта не будет. Запросы на `/api` попадут в `backend-service`, а всё остальное - во `frontend-service`.
- Оба backend указывают `port.number: 80`. Это порт **Service**, а не контейнера, Service маршрутизирует трафик в поды.
- `Middleware` - это CRD, то есть **Custom Resource Definition** от Traefik. Kubernetes по умолчанию не знает такого типа; он появился в API только потому, что MicroK8s Ingress addon установил CRD и сам Traefik умеет его читать. Проверка `kubectl api-resources | grep -i middleware` подтвердила наличие этого типа объекта. Имя middleware - `strip-api-prefix`, namespace - `default`, как и у Ingress и Service.
- `stripPrefix` удаляет совпавший префикс из URI перед отправкой запроса в backend. Это нужно в ситуации: dнешний URL:  `/api` но Backend ждёт: `/`. Без middleware `curl http://158.160.209.10/api` отдает `404 Not Found`. Traefik направлял запрос в нужный `backend-service`, но передавал путь `/api`. Встроенный nginx в образе multitool не имел страницы/обработчика `/api`, поэтому вернул 404. После `stripPrefix`  стало: `/api`->`/`, `/api/`->`/`, `/api/status`->`/status`. Traefik также помещает удалённый префикс в заголовок `X-Forwarded-Prefix: /api`. Это полезно для приложений, которым нужно формировать корректные внешние ссылки, зная, что снаружи они опубликованы не в корне сайта.
- `forceSlash: true` - этот параметр делает результат предсказуемым, когда после удаления префикса путь становится пустым. Для запроса `/api` после удаления `/api` получается пустая строка, а `forceSlash: true` приводит его к `/`. Без такого нормализующего поведения некоторые backend-приложения могут по-разному интерпретировать пустой путь. В текущих версиях Traefik этот параметр обычно уже не обязателен, но в решении сделал его явным.
- API-маршрут в `backend-ingress.yaml`: Правило `/api` (`path: /api`, `pathType: Prefix`). Это правило совпадает с запросами: `/api`, `/api/`, `/api/v1/users`,` /api/health`.  Оно не должно совпадать с `/apix`, потому что Kubernetes `Prefix` сопоставляет путь по сегментам URL, а не только как набор символов. Также существует маршрут `/` для frontend. Оба формально подходят к `/api`, однако более специфичное правило `/api` имеет приоритет перед `/`. Traefik сравнивает правила по длине и использует наиболее конкретное совпадение.
- Аннотация Middleware: `annotations: traefik.ingress.kubernetes.io/router.middlewares: default-strip-api-prefix@kubernetescrd`. Аннотация - это дополнительная метаинформация, обычно специфичная для контроллера. Kubernetes API её хранит, но интерпретировать и применять должен Traefik. Формат ссылки такой: `<namespace>-<имя>@<provider>`. Traefik требует суффикс `@kubernetescrd`, так как у него могут быть разные провайдеры конфигурации: Kubernetes Ingress, Kubernetes CRD, файлы, Docker labels и другие. Документация Traefik приводит такой же формат для привязки middleware к Ingress.
- Почему два Ingress: можно было оставить `/` и `/api` в одном объекте, но тогда middleware пришлось бы назначить всему объекту через аннотацию. В результате `stripPrefix` работал бы также для frontend-маршрута. Это само по себе не сломало бы frontend, но архитектурно неверно: middleware предназначен только для API-пути. Поэтому объекты разделены: `frontend-ingress` -> `/` -> `frontend-service:80` (без middleware). `backend-ingress` -> `/api` -> `/api` -> `backend-service:80`. Это пример принципа **минимальной области действия настройки**: каждая конфигурация влияет только на тот маршрут, для которого действительно нужна.
#### Полный путь `/api`:
1. Клиент открывает `http://158.160.209.10/api`.
2. Соединение приходит на порт `80` VM, который опубликован Traefik через `hostPort`.
3. Traefik ищет подходящий Ingress. `/api` более специфичен, чем `/`, поэтому выбирается `backend-ingress`.
4. По аннотации Traefik подключает `default-strip-api-prefix@kubernetescrd`.
5. Middleware преобразует URI `/api` в `/`.
6. Traefik направляет HTTP-запрос в `backend-service` на его Service-порт `80`.
7. Service по selector находит endpoints backend Deployment и пересылает запрос на `8080` одного из Pod’ов.
8. `network-multitool` получает запрос `/` и возвращает диагностический ответ.
  Traefik может использовать данные EndpointSlice, чтобы обращаться к endpoint’ам Pod’ов, связанным с Service; при этом Service остаётся декларативной точкой назначения и источником портовой конфигурации.
  Поэтому перед настройкой маршрутов в реальном кластере всегда полезно выполнить: 
```bash
kubectl get ingressclass
kubectl get pods -A | grep -Ei 'ingress|traefik|nginx'
```
  Сначала определяется фактический контроллер, а уже затем выбираются его аннотации, CRD и способ диагностики.

#### Применил и проверил:
```bash
kubectl api-resources | grep -i middleware # CRD Middleware есть в кластере
kubectl apply -f ingress.yaml
kubectl apply -f traefik-middleware.yaml
kubectl apply -f backend-ingress.yaml
kubectl get ingress example-ingress
kubectl describe ingress example-ingress
```

![](<Pasted image 20260828214500.png>)

![](<Pasted image 20260828214618.png>)

#### Проверка через прямой порт 80
```bash
curl http://158.160.209.10/
curl http://158.160.209.10/api
curl http://158.160.209.10:32062/
curl http://158.160.209.10:32062/api
```

![](<Pasted image 20260828214757.png>)

![](<Pasted image 20260828214820.png>)

Путь `/` отдаёт nginx, а `/api` теперь корректно доходит до multitool через `stripPrefix`. В двух разных запросах ответили разные Pod backend (`7cmws` и `zt2b7`), что подтверждает балансировку между репликами.

