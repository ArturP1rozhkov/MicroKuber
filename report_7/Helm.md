

# Домашнее задание к занятию «Helm»

### Цель задания
В тестовой среде Kubernetes необходимо установить и обновить приложения с помощью Helm.

---
### Задание 1. Подготовить Helm-чарт для приложения

1. Необходимо упаковать приложение в чарт для деплоя в разные окружения.
2. Каждый компонент приложения деплоится отдельным deployment’ом или statefulset’ом.
3. В переменных чарта измените образ приложения для изменения версии.
---
### Задание 2. Запустить две версии в разных неймспейсах

1. Подготовив чарт, необходимо его проверить. Запуститe несколько копий приложения.
2. Одну версию в namespace=app1, вторую версию в том же неймспейсе, третью версию в namespace=app2.
3. Продемонстрируйте результат.

---
# Разбор решения задания 1

### Для начала установил актуальную версию Helm 4 и проверил

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -s -- --version v4.3.0 #прописал версию, иначе ставит v3.22.0
helm version
helm list
helm repo add bitnami https://charts.bitnami.com/bitnami
```

![](<Pasted image 20260913151927.png>)

### Создал проект чарта
```bash
helm create myapp
find myapp -type f
helm lint myapp
helm template myapp --namespace app1 | less
```

![](<Pasted image 20260913152957.png>)

- `helm create` создал папку `myapp/` в текущем каталоге;
- `helm lint`  ответил, что чарт структурно валиден;
- `helm template` показал отрендеренный YAML демо-приложения (не скринил).
### Удалил ненужное:
```bash
rm myapp/templates/hpa.yaml \
   myapp/templates/ingress.yaml \
   myapp/templates/httproute.yaml \
   myapp/templates/serviceaccount.yaml \
   myapp/templates/NOTES.txt \
   myapp/templates/deployment.yaml \
   myapp/templates/service.yaml
rm -r myapp/templates/tests
```
- Оставил только `_helpers.tpl` - это библиотека функций;
- `hpa.yaml` - автомасштабирование (выходит за рамки задания);
- `ingress.yaml`, `httproute.yaml` - демонстрация будет через port-forward;
- `serviceaccount.yaml`, `tests/`, `NOTES.txt` -к приложению отношения не имеет;
- `deployment.yaml`, `service.yaml` - заменю своими.

### Заменил содержимое `myapp/Chart.yaml`:
```yaml
apiVersion: v2
name: myapp
description: Frontend + Backend application chart for Helm homework
type: application
version: 0.1.1
appVersion: "1.0.0"
```
- `apiVersion: v2` - формат чартов, работает и в Helm 4;
- `version` - при каждом изменении шаблонов буду инкрементировать;
- `appVersion` - версия приложения, удобно использовать как тег образа.
### Заменил содержимое `values.yaml`
```yaml
frontend:
  replicaCount: 2
  image:
    repository: nginx
    tag: "1.25"
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 80
  containerPort: 80

backend:
  replicaCount: 2
  image:
    repository: wbitt/network-multitool
    tag: "latest"
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 80
  containerPort: 8080
```

- **Структура `frontend:` / `backend:`** - каждый компонент в своем изолированном блоке. В шаблонах будет именоваться например как `.Values.frontend.image.tag`;
- **`tag: "1.25"` в кавычках** - YAML может воспринять `1.25` как число с плавающей точкой, а тег образа должен быть строкой;
- **`pullPolicy: IfNotPresent`** - в MicroK8s  не будет подтягиваться образ при каждом пересоздании пода;

### Проверил:
```bash
helm lint myapp
helm template myapp
```

![](<Pasted image 20260913155036.png>)

### Заменил содержимое `myapp/templates/_helpers.tpl`:
```yaml
{{- define "myapp.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "myapp.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
```

- `{{- ... }}` - дефис слева/справа убирает пробельные символы до/после тега. Без них в YAML выползали бы пустые строки;
- `define` … `end` - объявление именованного шаблона. Вызывается через `include "myapp.fullname" .`;
- `.Chart.Name`, `.Release.Name` - встроенные объекты Helm: метаданные чарта и имя релиза. Точка в начале - «корневой контекст»;
- `| trunc 63 | trimSuffix "-"` - **пайплайн**, как в bash: значение проходит слева направо. Обрезка до 63 символов - требование DNS-имён Kubernetes (RFC 1123), это защита от длинных имён релизов;
 - `fullname` решает задачу двух релизов в одном неймспейсе: релиз `v1` даст ресурсы `v1-myapp-frontend`, релиз `v2` - `v2-myapp-frontend`.

### `myapp/templates/deployment-frontend.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}-frontend
  labels:
    app: {{ include "myapp.fullname" . }}-frontend
spec:
  replicas: {{ .Values.frontend.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "myapp.fullname" . }}-frontend
  template:
    metadata:
      labels:
        app: {{ include "myapp.fullname" . }}-frontend
    spec:
      containers:
      - name: frontend
        image: "{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}"
        imagePullPolicy: {{ .Values.frontend.image.pullPolicy }}
        ports:
        - containerPort: {{ .Values.frontend.containerPort }}
```

### `myapp/templates/service-frontend.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "myapp.fullname" . }}-frontend
spec:
  type: {{ .Values.frontend.service.type }}
  selector:
    app: {{ include "myapp.fullname" . }}-frontend
  ports:
  - name: http
    port: {{ .Values.frontend.service.port }}
    targetPort: {{ .Values.frontend.containerPort }}
```

### `myapp/templates/deployment-backend.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}-backend
  labels:
    app: {{ include "myapp.fullname" . }}-backend
spec:
  replicas: {{ .Values.backend.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "myapp.fullname" . }}-backend
  template:
    metadata:
      labels:
        app: {{ include "myapp.fullname" . }}-backend
    spec:
      containers:
      - name: backend
        image: "{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag }}"
        imagePullPolicy: {{ .Values.backend.image.pullPolicy }}
        ports:
        - containerPort: {{ .Values.backend.containerPort }}
        env:
        - name: HTTP_PORT
          value: {{ .Values.backend.containerPort | quote }}
```

### `myapp/templates/service-backend.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "myapp.fullname" . }}-backend
spec:
  type: {{ .Values.backend.service.type }}
  selector:
    app: {{ include "myapp.fullname" . }}-backend
  ports:
  - name: http
    port: {{ .Values.backend.service.port }}
    targetPort: {{ .Values.backend.containerPort }}
```
- `value: {{ .Values.backend.containerPort | quote }}` - функция `quote` оборачивает значение в кавычки. `containerPort` в values - число, а env-переменные в Kubernetes **обязаны** быть строками. Без `quote` получил бы YAML-ошибку вида `cannot unmarshal number into string` при деплое.
- env берётся из `containerPort` - устраняет дубль из values, меняется порт в одном месте, и env, и ports, и сервис подставят значение сами.

### Проверил:
```bash
helm lint myapp
helm template myapp --namespace app1
helm template v1 myapp --namespace app1
```
В первом случае проверки шаблона Helm использует значения по умолчанию, а во втором я указал имя релиза `v1` и все имена ресурсов в рендере `yaml` шаблонов поменялись на `v1-myapp-*`:

![](<Pasted image 20260913161503.png>)

и скрин с `v1` 
![](<Pasted image 20260913161543.png>)

### Готовлю namespaces:
```bash
kubectl create namespace app1
kubectl create namespace app2
```
`helm install` сам не создаёт неймспейс, он упадёт с ошибкой `namespace "app1" not found`, если его нет. Есть флаг `--create-namespace`, но в реальных проектах неймспейсы создают отдельно, с квотами, лимитами и лейблами, а не полагаются на случайный флаг установщика.
### Устанавливаю три релиза:
```bash
helm install v1 myapp --namespace app1
helm install v2 myapp --set frontend.image.tag=1.27 --namespace app1
helm install v3 myapp --set frontend.image.tag=alpine --set backend.replicaCount=1 --namespace app2
```

- **`v1`** - ставится «как есть», на значениях из чарта (`nginx:1.25`). Это показывает то, что значения по умолчанию в `values.yaml` - самодостаточная конфигурация;
- **`v2`** - та же команда в **тот же namespace**, но с переопределением тега через `--set`. Сработает только потому, что все имена ресурсов строятся от `Release.Name`. Если в манифестах будут стоять жёсткие `name: frontend`, второй релиз получил бы `Error: services "frontend-service" already exists`;
- **`v3`** - в namespace `app2`, и ещё `--set backend.replicaCount=1` показывает, что параметризуются не только версии образов, но и топология;
- **`--set` или `-f файл`**: - `--set` удобен для точечных переопределений и CI; для полноценных окружений в проде хранят отдельные файлы values (`values-app1.yaml`).
Порядок приоритета важен: значения из `--set` перекрывают значения из `-f`,  дефолтные из `values.yaml` чарта.

![](<Pasted image 20260913162835.png>)

### Проверка результата:
```bash
helm list -A
kubectl get all -n app1
kubectl get all -n app2
kubectl get deployments -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,IMAGE:.spec.template.spec.containers[*].image' | grep -E "myapp|NAMESPACE"
```

![](<Pasted image 20260913163704.png>)

![](<Pasted image 20260913164014.png>)
### Проверка как Helm хранит состояние релизов:
```bash
kubectl get secrets -n app1 | grep sh.helm.release
```
![](<Pasted image 20260913163817.png>)

### Демонстрация разницы версий приложений:
```bash
kubectl port-forward svc/v1-myapp-frontend 9001:80 -n app1 
curl -sI localhost:9001 | grep -i ^server

kubectl port-forward svc/v2-myapp-frontend 9002:80 -n app1 &
curl -sI localhost:9002 | grep -i ^server

kubectl port-forward svc/v3-myapp-frontend 9003:80 -n app2 &
curl -sI localhost:9003 | grep -i ^server

kubectl port-forward svc/v1-myapp-backend 9004:80 -n app1
curl -s localhost:9004
```
Через port-forward запросил заголовок `Server` у трёх экземпляров фронтенда и одного бэкэнда (по очереди, отдельными терминалами):

![](<Pasted image 20260913164943.png>)

![](<Pasted image 20260913165059.png>)

![](<Pasted image 20260913165148.png>)

![](<Pasted image 20260913165917.png>)

### Обновление релиза: обновляю v1 с 1.25 на свежий тег:
```bash
helm upgrade v1 myapp --set frontend.image.tag=1.29 --namespace app1
helm history v1 -n app1
kubectl rollout status deployment/v1-myapp-frontend -n app1
kubectl get rs -n app1 | grep v1-myapp-frontend
```

![](<Pasted image 20260913170824.png>)

![](<Pasted image 20260913170608.png>)

Вывод демонстрирует всю механику Helm-катом и Kubernetes в связке:
- **REVISION: 2** в выводе и два ряда в `helm history` - Helm ведёт полную историю: ревизия 1 со статусом `superseded` сохранена, её состояние лежит в секрете и доступно для отката;
- **Новый ReplicaSet `5f99c544c4` масштабирован до 2, старый обнулён** - Deployment выполнил rolling update: поднял новые поды с `nginx:1.29`, убедился в готовности, и только потом погасил старые. Helm здесь лишь отправил обновлённый манифест, обновлением занимался Kubernetes.
- **`Server: nginx/1.29.8`** - версия приложения поменялась через переменную чарта. Имя тега совпало с реальной версией.

### Откат:
```bash
helm rollback v1 1 -n app1
kubectl rollout status deployment/v1-myapp-frontend -n app1

kubectl port-forward svc/v1-myapp-frontend 9001:80 -n app1 # в разных терминалах проверка версии
curl -sI localhost:9001 | grep -i ^server   

helm history v1 -n app1
```

![](<Pasted image 20260913173155.png>)

![](<Pasted image 20260913173235.png>)

![](<Pasted image 20260913173325.png>)
Поды откатились к nginx 1.25, в истории появилась **revision 4** : Helm создал новую ревизию с содержимым **revision 1**.
### Очистил машину:
```bash
helm uninstall v1 -n app1
helm uninstall v2 -n app1
helm uninstall v3 -n app2
helm list -A         
kubectl delete ns app1 app2
```
