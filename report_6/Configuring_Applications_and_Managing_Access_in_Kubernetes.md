

# Домашнее задание к занятию «Настройка приложений и управление доступом в Kubernetes»

### Цель задания

Научиться:

- Настраивать конфигурацию приложений с помощью **ConfigMaps** и **Secrets**
- Управлять доступом пользователей через **RBAC**

Это задание поможет вам освоить ключевые механизмы Kubernetes для работы с конфигурацией и безопасностью. Эти навыки необходимы для уверенного администрирования кластеров в реальных проектах. На практике навыки используются для:

- Хранения чувствительных данных (Secrets)
- Гибкого управления настройками приложений (ConfigMaps)
- Контроля доступа пользователей и сервисов (RBAC)

---

## **Подготовка**

### **Чеклист готовности**

- Установлен Kubernetes (MicroK8S, Minikube или другой)
- Установлен `kubectl`
- Редактор для YAML-файлов (VS Code, Vim и др.)
- Утилита `openssl` для генерации сертификатов

---

### Инструменты, которые пригодятся для выполнения задания

1. [Инструкция](https://microk8s.io/docs/getting-started) по установке MicroK8S
2. [Инструкция](https://minikube.sigs.k8s.io/docs/start/) по установке Minikube
3. [Инструкция](https://kubernetes.io/docs/tasks/tools/) по установке kubectl
4. [Инструкция](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-kubernetes-tools) по установке VS Code

### Дополнительные материалы, которые пригодятся для выполнения задания

1. [Описание](https://kubernetes.io/docs/concepts/configuration/secret/) Secret.
2. [Описание](https://kubernetes.io/docs/concepts/configuration/configmap/) ConfigMap.
3. [Описание](https://github.com/wbitt/Network-MultiTool) Multitool.
4. [Описание](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) RBAC.
5. [Пользователи и авторизация RBAC в Kubernetes](https://habr.com/ru/company/flant/blog/470503/).
6. [RBAC with Kubernetes in Minikube](https://medium.com/@HoussemDellai/rbac-with-kubernetes-in-minikube-4deed658ea7b).

---

## **Задание 1: Работа с ConfigMaps**

### **Задача**

Развернуть приложение (nginx + multitool), решить проблему конфигурации через ConfigMap и подключить веб-страницу.

### **Шаги выполнения**

1. **Создать Deployment** с двумя контейнерами
    - `nginx`
    - `multitool`
2. **Подключить веб-страницу** через ConfigMap
3. **Проверить доступность**

### **Что сдать на проверку**

- Манифесты:
    - `deployment.yaml`
    - `configmap-web.yaml`
- Скриншот вывода `curl` или браузера

---

## **Задание 2: Настройка HTTPS с Secrets**

### **Задача**

Развернуть приложение с доступом по HTTPS, используя самоподписанный сертификат.

### **Шаги выполнения**

1. **Сгенерировать SSL-сертификат**

```shell
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=myapp.example.com"
```

2. **Создать Secret**
3. **Настроить Ingress**
4. **Проверить HTTPS-доступ**

### **Что сдать на проверку**

- Манифесты:
    - `secret-tls.yaml`
    - `ingress-tls.yaml`
- Скриншот вывода `curl -k`

---

## **Задание 3: Настройка RBAC**

### **Задача**

Создать пользователя с ограниченными правами (только просмотр логов и описания подов).

### **Шаги выполнения**

1. **Включите RBAC в microk8s**

```shell
microk8s enable rbac
```

2. **Создать SSL-сертификат для пользователя**

```shell
openssl genrsa -out developer.key 2048
openssl req -new -key developer.key -out developer.csr -subj "/CN={ИМЯ ПОЛЬЗОВАТЕЛЯ}"
openssl x509 -req -in developer.csr -CA {CA серт вашего кластера} -CAkey {CA ключ вашего кластера} -CAcreateserial -out developer.crt -days 365
```

3. **Создать Role (только просмотр логов и описания подов) и RoleBinding**
4. **Проверить доступ**

### **Что сдать на проверку**

- Манифесты:
    - `role-pod-reader.yaml`
    - `rolebinding-developer.yaml`
- Команды генерации сертификатов
- Скриншот проверки прав (`kubectl get pods --as=developer`)

---

## Шаблоны манифестов с учебными комментариями

### **1. Deployment с ConfigMap (nginx + multitool)**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config # ПОДКЛЮЧЕНИЕ ConfigMap
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config # УКАЖИТЕ имя созданного ConfigMap
```

### **2. ConfigMap для веб-страницы**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-content # ИЗМЕНИТЕ: Укажите имя ConfigMap
  namespace: default # ОПЦИОНАЛЬНО: Укажите namespace, если не default
data:
  # КЛЮЧЕВОЙ МОМЕНТ: index.html будет подключен как файл
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
      <title>Страница из ConfigMap</title> # ИЗМЕНИТЕ: Заголовок страницы
    </head>
    <body>
      <h1>Привет от Kubernetes!</h1> # ДОБАВЬТЕ: Свой контент страницы
    </body>
    </html>
```

### **3. Secret для TLS-сертификата**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret # ИЗМЕНИТЕ при необходимости
type: kubernetes.io/tls
data:
  tls.crt: # ЗАМЕНИТЕ на base64-код сертификата (cat tls.crt | base64 -w 0)
  tls.key: # ЗАМЕНИТЕ на base64-код ключа (cat tls.key | base64 -w 0)
```

### **4. Role для просмотра подов**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-viewer # ИЗМЕНИТЕ: Название роли
  namespace: default # ВАЖНО: Role работает только в указанном namespace
rules:
- apiGroups: [""] # КЛЮЧЕВОЙ МОМЕНТ: "" означает core API group
  resources: # РАЗРЕШЕННЫЕ РЕСУРСЫ:
    - pods # Доступ к просмотру подов
    - pods/log # Доступ к логам подов
  verbs: # РАЗРЕШЕННЫЕ ДЕЙСТВИЯ:
    - get # Просмотр отдельных подов
    - list # Список всех подов
    - watch # Мониторинг изменений
    - describe # Просмотр деталей
# ДОПОЛНИТЕЛЬНО: Можно добавить больше правил для других ресурсов
```

---

## **Правила приёма работы**

1. Домашняя работа оформляется в своём Git-репозитории в файле README.md. Выполненное домашнее задание пришлите ссылкой на .md-файл в вашем репозитории.
2. Файл README.md должен содержать:
    - Скриншоты вывода команд `kubectl`
    - Скриншоты результатов выполнения
    - Тексты манифестов или ссылки на них
3. Для заданий с TLS приложите команды генерации сертификатов

---
# Разбор решения задачи 1

### Создаю ConfigMap с веб-страницей
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-content
  namespace: default
data:
  index.html: |
    <!doctype html>
    <html lang="ru">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Kubernetes ConfigMap</title>
    </head>
    <body>
      <h1>Привет от Kubernetes!</h1>
      <p>Эта страница передана в контейнер nginx через ConfigMap.</p>
      <p>Домашнее задание: настройка приложений и управление доступом в Kubernetes.</p>
    </body>
    </html>
```

- `metadata.name: web-content` - имя объекта, на которое позже будет ссылка в `Deployment`.
- `namespace: default` - ConfigMap и Pod должны быть в одном namespace.
- Блок `|` сохраняет HTML как многострочный текст, включая переводы строк.
- Название ключа `index.html`: nginx по умолчанию ищет именно этот файл в web-root.
### Применил и выполнил проверку
```bash
kubectl apply -f configmap-web.yaml
kubectl get configmap web-content -n default
kubectl describe configmap web-content -n default
```

![](<Pasted image 20260904134254.png>)

ConfigMap создан корректно: объект `web-content` находится в `default`, содержит один ключ `index.html`, а HTML успешно сохранён в Kubernetes.

### Создал файл - manifest `deployment.yaml` 
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
  labels:
    app: web-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          volumeMounts:
            - name: web-content
              mountPath: /usr/share/nginx/html
              readOnly: true

        - name: multitool
          image: wbitt/network-multitool:latest
          command: 
	        - /bin/sh 
	        - -c 
	        - sleep infinity

      volumes:
        - name: web-content
          configMap:
            name: web-content
            items:
              - key: index.html
                path: index.html
```

- Создаю один Pod с двумя контейнерами: `nginx` отдаёт веб-страницу на TCP/80; `multitool` - диагностический контейнер в том же Pod, для проверки сети, DNS и HTTP изнутри кластера. 
- ConfigMap подключается **только к nginx**, потому что именно ему нужен файл страницы.
- `spec.selector.matchLabels` у Deployment **обязан совпадать** с `spec.template.metadata.labels`. По этим меткам Deployment понимает, какими Pod'ами он управляет; далее те же labels использует Service, чтобы направлять трафик на нужные Pod'ы.
- В разделе `volumes` указан источник данных - ConfigMap `web-content`. В `volumeMounts` этот том подключён к `/usr/share/nginx/html`; ключ `index.html` становится файлом с таким именем в данной директории. Поле `readOnly: true` подчёркивает, что приложение не должно менять управляемую Kubernetes конфигурацию.

### Применил и выполнил проверки
```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/web-app -n default
kubectl get deployment,pods -n default -o wide

kubectl exec deployment/web-app -n default -c nginx -- \
  cat /usr/share/nginx/html/index.html
  
kubectl exec deployment/web-app -n default -c multitool -- \
  curl -s http://127.0.0.1/
```

![](<Pasted image 20260904140020.png>)

- Pod находится в состоянии `2/2 Running`, 
- запрос из `multitool` на `127.0.0.1:80` вернул HTML из ConfigMap. Это подтверждает, что оба контейнера работают в одном Pod и разделяют его сетевое пространство, а `index.html` корректно смонтирован в web-root nginx

### Создал файл - manifest `service-web.yaml`
```bash
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: web-app
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: http
```

- `type: ClusterIP` создаёт внутренний виртуальный IP так как внешний HTTPS-трафик будет принимать Ingress/Traefik, а он отправит его на этот Service.
- `selector.app: web-app` должен совпадать с label в шаблоне Pod Deployment.
- `port: 80` - порт Service.
- `targetPort: http` - ссылка на именованный `containerPort` nginx (`name: http`, `containerPort: 80`), а не на контейнер `multitool`. Именованные порты помогают избежать несогласованности при смене  порта приложения.
### Применил и выполнил прверки

```bash
kubectl apply -f service-web.yaml
kubectl get service web-app-service -n default
kubectl get endpoints web-app-service -n default
```

![](<Pasted image 20260904140856.png>)

### Проверка Pod извне:
в первом терминале запустил:
```bash
kubectl port-forward -n default service/web-app-service 8080:80
```

Во втором терминале рядом запустил:
```bash
curl -i http://127.0.0.1:8080/
```

![](<Pasted image 20260904141321.png>)

HTTP-статус `HTTP/1.1 200 OK` и HTML-страница из ConfigMap демонстрируют доступность извне веб-страницы

# Разбор решения задачи 2
### Генерирую самоподписанный сертификат
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=myapp.example.com"
```

- `-x509` - сразу создаёт самоподписанный сертификат, а не запрос (CSR), потому что нет отдельного центра сертификации.
- `-nodes` - не шифровать приватный ключ паролем. Не для прода.
- `-newkey rsa:2048` - генерирует новый RSA-ключ длиной 2048 бит.
- `-days 365` - срок действия сертификата.
- `-subj "/CN=myapp.example.com"` - Common Name сертификата; должен совпадать с `host`, который позже будет указан в Ingress, иначе браузер/curl выдаст ошибку несовпадения имени.
### Выполнил для проверки того, что файлы появились:
```bash
ls -l tls.crt tls.key
openssl x509 -in tls.crt -noout -subject -dates
```

![](<Pasted image 20260904142053.png>)

### Создаю TLS Secret из уже готовых файлов сертификата и ключа:

```bash
kubectl create secret tls tls-secret \
  --cert=tls.crt --key=tls.key \
  -n default
```

- Специализированный тип `kubernetes.io/tls` ожидает два ключа данных - `tls.crt` и `tls.key`;
- команда `kubectl create secret tls` формирует их автоматически в правильной base64-кодировке и с нужными именами ключей. 
- Ручной вариант из шаблона задания (`cat tls.crt | base64 -w 0`) даёт тот же результат, но требует аккуратно вставить длинные base64-строки в YAML без переносов, где есть риск ошибиться. 
### Проверил создание:
```bash
kubectl get secret tls-secret -n default
kubectl describe secret tls-secret -n default
```
### Экспорт секрета в manifest.yaml файл
```bash
kubectl get secret tls-secret -n default -o yaml > secret-tls.yaml
```

![](<Pasted image 20260904143010.png>)

### получившийся файл `secret-tls.yaml` (лишние поля удалены)
```yaml
apiVersion: v1
data:
  tls.crt: LS0tLS1________DRVJUSUZJQ0FURS0tLS0tCg==
  tls.key: LS0tLS1CRUd_______S0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K
kind: Secret
metadata:
  name: tls-secret
  namespace: default
type: kubernetes.io/tls
```

### Для настройки Ingress с TLS создал файл `ingress-tls.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-app-ingress
  namespace: default
  annotations: traefik.ingress.kubernetes.io/router.tls: "true" traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - myapp.example.com
      secretName: tls-secret
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-app-service
                port:
                  number: 80
```

- `ingressClassName: traefik` - явно указывает, какой ingress-контроллер должен обрабатывать этот объект. В MicroK8s addon ingress устанавливает именно Traefik, поэтому имя класса - `traefik`;
- Для Traefik TLS-секция `spec.tls` выбирает сертификат из Secret, но согласно документации Traefik для включения TLS у созданного router нужна аннотация `traefik.ingress.kubernetes.io/router.tls: "true"`. Добавил также `router.entrypoints: websecure`, чтобы маршрут был привязан к HTTPS-входу. (https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/ingress/)
- `spec.tls[].hosts` должен содержать точное имя, совпадающее с `CN` сертификата (`myapp.example.com`), иначе TLS handshake завершится ошибкой проверки имени.
- `secretName: tls-secret` - ссылка на созданный ранее Secret; Traefik достаёт `tls.crt`/`tls.key` именно оттуда и представляет их клиенту при HTTPS-подключении.
- `rules[].host` определяет, для какого доменного имени применяется правило маршрутизации — при обращении по IP или другому имени Traefik не применит это правило.
- `backend.service` указывает на уже существующий `web-app-service`, порт 80 (тот же ClusterIP-сервис, что использовался в задании 1). HTTPS завершается на Ingress, а к nginx внутри кластера трафик идёт обычным HTTP. 
### Применил manifest и проверил:
```bash
kubectl apply -f ingress-tls.yaml
kubectl get ingress -n default
kubectl describe ingress web-app-ingress -n default
```

![](<Pasted image 20260904144749.png>)

- Ingress создан и настроен верно: TLS секция подтверждает `tls-secret terminates myapp.example.com`, а backend указывает на реальный Pod `10.1.120.124:80`. Значит маршрутизация от Ingress до Service до Pod работает согласованно.
- поле ADDRESS пустое так как Traefik как DaemonSet/Deployment работает без внешнего LoadBalancer IP в облаке.
### Проверка HTTPS
На облачной машине где живет кластер выполнил запрос:
```bash
curl -vk \
  --resolve myapp.example.com:32151:10.130.0.23 \
  https://myapp.example.com:32151/
```
`--resolve` временно сопоставляет имя и IP только для данного вызова curl, а `-k` допускает self-signed сертификат
![](<Pasted image 20260904145435.png>)
![](<Pasted image 20260904145520.png>)

- `subject: CN=myapp.example.com` и `issuer: CN=myapp.example.com` подтверждают, что Traefik использует self-signed сертификат из `tls-secret`, а не сгенерировал сертификат по умолчанию.
- `SSL certificate verify result: self-signed certificate (18), continuing anyway` - ожидаемое предупреждение, а не ошибка: curl прошёл проверку только благодаря флагу `-k`, что абсолютно корректно для самоподписанного сертификата .
- `HTTP/2 200` и HTML в теле ответа подтверждают, что Ingress успешно проксирует трафик до `web-app-service` - Pod `nginx`.
- Аннотации `router.tls` и `router.entrypoints: websecure` сработали правильно - Traefik создал HTTPS-роутер для этого Ingress.


# Разбор решения задачи 3

### проверяю RBAC. Для этого на облачной машине выполнил:
```bash
sudo microk8s enable rbac
```

![](<Pasted image 20260904150024.png>)

### С хостовой проверил:
```bash
kubectl auth can-i create roles -n default
kubectl auth can-i create rolebindings -n default
kubectl get role,rolebinding -n default
```

![](<Pasted image 20260904150500.png>)
Команда `kubectl get role,rolebinding -n default` вернула пусто потому, что **ещё не создан** ни одной `Role`, ни одного `RoleBinding` в этом namespace. RBAC  работает (проверяет права), но правил пока нет.
### CA кластера:
Для подписи сертификата пользователя нужны файлы `ca.crt` и `ca.key` с той же VM, где установлен MicroK8s:
```bash
ssh yc-user@158.160.209.10
sudo ls -l /var/snap/microk8s/current/certs/ca.crt /var/snap/microk8s/current/certs/ca.key
```
![](<Pasted image 20260904150814.png>)

Срок действия:
```bash
sudo openssl x509 -in /var/snap/microk8s/current/certs/ca.crt -noout -subject -dates
```
![](<Pasted image 20260904151012.png>)

### Создаю клиентский сертификат пользователя `developer` на сервере MicroK8s, не копируя закрытый ключ CA за пределы узла. 
```bash
mkdir -p ~/rbac-lab
chmod 700 ~/rbac-lab
cd ~/rbac-lab

openssl genrsa -out developer.key 2048

openssl req -new \ 
  -key developer.key \ 
  -out developer.csr \ 
  -subj "/CN=developer"

ls -l developer.key developer.csr
openssl req -in developer.csr -noout -subject
```
- `developer.key` - приватный ключ будущего пользователя; 
- `developer.csr` - запрос на сертификат, содержащий публичный ключ и subject `CN=developer`.
- При сертификатной аутентификации Kubernetes интерпретирует `CN` из subject валидного клиентского сертификата как имя пользователя, поэтому имя в RoleBinding далее должно быть строго `developer`.
- Группа не требуется, потому что привязывать роль буду напрямую к `kind: User`, `name: developer`.

![](<Pasted image 20260904152124.png>)

### Подпись сертификата CA кластера
```bash
sudo openssl x509 -req \
  -in developer.csr \
  -CA /var/snap/microk8s/current/certs/ca.crt \
  -CAkey /var/snap/microk8s/current/certs/ca.key \
  -CAcreateserial \
  -out developer.crt \
  -days 365 \
  -sha256
```
- `-in developer.csr` - берёт ранее созданный запрос пользователя;
- `-CA` - публичный сертификат CA MicroK8s;
- `-CAkey` - закрытый ключ CA, который используется исключительно на сервере;
- `-CAcreateserial` - создаёт серийный файл CA для выдачи уникального номера сертификата;
- `-out developer.crt` - сохраняет подписанный пользовательский сертификат;
- `-days 365` - задаёт срок действия один год;
- `-sha256` - использует SHA-256 для подписи.
MicroK8s хранит CA и связанные PKI-файлы в `/var/snap/microk8s/current/certs/`. Клиентский сертификат, доверенный CA, позволяет пройти аутентификацию в API Kubernetes; дальше его реальные права определит RBAC. (https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
### Проверка сертификата
```bash
openssl x509 -in developer.crt -noout -subject -issuer -dates
openssl verify \
  -CAfile /var/snap/microk8s/current/certs/ca.crt \
  developer.crt
```

![](<Pasted image 20260904152646.png>)

`openssl verify -CAfile` проверил цепочку доверия сертификата к указанному CA. Сертификат подписан корректно: `subject=CN=developer`, `issuer` совпадает с CA кластера, срок действия - год, и команда `openssl verify` подтвердила цепочку доверия (`developer.crt: OK`). Аутентификация для пользователя `developer` теперь технически возможна.

### Создал файл `role-pod-reader.yaml`
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]
```

- `apiGroups: [""]` - пустая строка означает core API group, где живут `pods`; отдельно указывать версию API не нужно.
- `pods` с `get/list/watch` даёт возможность `kubectl get pods` и `kubectl describe pod`: команда `describe` не имеет отдельного verb в RBAC - она использует `get` на объекте и, если применимо, `list` на связанных событиях, поэтому отдельного verb `describe` в API вообще не существует. 
- `pods/log` - отдельный subresource, обязательный для доступа к `kubectl logs`; без него команда `logs` вернёт `Forbidden`, даже если есть права на сам `pods`.(https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- `watch` нужен, если `developer` захочет использовать `kubectl get pods -w` для отслеживания изменений в реальном времени.

### Создал файл `rolebinding-developer.yaml`
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-pod-reader-binding
  namespace: default
subjects:
  - kind: User
    name: developer
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```
- `kind: User`, `name: developer` - Kubernetes не хранит пользователей как объекты; это имя должно точно совпадать с `CN` из сертификата, который прошёл аутентификацию. (https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
- `RoleBinding` действует только внутри своего `namespace` (`default`), поэтому `developer` получит права строго в этом namespace, а не во всём кластере - это соответствует принципу минимальных привилегий. (https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- `roleRef` ссылается на `pod-reader`, созданную выше; имя роли и namespace должны совпадать.

### Примени оба манифеста:
```bash
kubectl apply -f role-pod-reader.yaml
kubectl apply -f rolebinding-developer.yaml
kubectl get role,rolebinding -n default
kubectl describe role pod-reader -n default
```

![](<Pasted image 20260904153319.png>)

Role и RoleBinding созданы: `pod-reader` содержит правило для `pods` (`get`, `list`, `watch`) и отдельное правило для `pods/log` (`get`), а `RoleBinding` привязывает эти права к пользователю `developer` в namespace `default`.

### Проверка через --as
Kubernetes позволяет проверить, как выглядели бы права другого пользователя, с помощью флага `--as`, используя текущий (административный) `kubectl`. Это самый быстрый способ протестировать RBAC без настройки отдельного kubeconfig.
```bash
kubectl get pods -n default --as=developer
kubectl describe pod web-app-8547b64966-4t84z -n default --as=developer
kubectl logs web-app-8547b64966-4t84z -c nginx -n default --as=developer
```

![](<Pasted image 20260904153807.png>)
![](<Pasted image 20260904153829.png>)
### Проверка запрета
```bash
kubectl delete pod web-app-8547b64966-4t84z -n default --as=developer
kubectl get deployments -n default --as=developer
kubectl get secrets -n default --as=developer
```
Дополнительно удобно проверить права декларативно без выполнения самой команды:
```bash
kubectl auth can-i get pods -n default --as=developer
kubectl auth can-i get pods/log -n default --as=developer
kubectl auth can-i delete pods -n default --as=developer
kubectl auth can-i list secrets -n default --as=developer
```

![](<Pasted image 20260904154128.png>)

- `kubectl get pods --as=developer` отработал успешно: право `list` на ресурс `pods` выдано.
- `kubectl describe pod ... --as=developer` отработал без ошибок: право `get` на `pods` разрешает чтение конкретного Pod.
- `kubectl logs ... --as=developer` отработал успешно: доступ к логам требует отдельного subresource `pods/log` с флагом `get`. Он задан правильно.
- Все запрещённые действия вернули `Forbidden`: у пользователя нет `delete` для Pod, нет `list` для `deployments.apps` и `secrets`.
- Пользователь аутентифицируется как `developer`, потому что его клиентский сертификат подписан доверенным CA кластера и содержит `CN=developer`; Kubernetes использует CN сертификата как имя пользователя.

