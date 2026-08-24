

## Цель задания
В тестовой среде для работы с Kubernetes, установленной в предыдущем ДЗ, необходимо развернуть Pod с приложением и подключиться к нему со своего локального компьютера.

### Чеклист готовности к домашнему заданию
- Установленное k8s-решение (например, MicroK8S).
- Установленный локальный kubectl.
- Редактор YAML-файлов с подключенным Git-репозиторием.
- Инструменты и дополнительные материалы, которые пригодятся для выполнения задания
- Описание Pod и примеры манифестов.
- Описание Service.
## Задание 1. Создать Pod с именем hello-world
- Создать манифест (yaml-конфигурацию) Pod.
- Использовать image - gcr.io/kubernetes-e2e-test-images/echoserver:2.2.
- Подключиться локально к Pod с помощью kubectl port-forward и вывести значение (curl или в браузере).
## Задание 2. Создать Service и подключить его к Pod
- Создать Pod с именем netology-web.
- Использовать image — gcr.io/kubernetes-e2e-test-images/echoserver:2.2.
- Создать Service с именем netology-svc и подключить к netology-web.
- Подключиться локально к Service с помощью kubectl port-forward и вывести значение (curl или в браузере).
### Правила приёма работы
- Домашняя работа оформляется в своем Git-репозитории в файле README.md. 
- Выполненное домашнее задание пришлите ссылкой на .md-файл в вашем репозитории.
- Файл README.md должен содержать скриншоты вывода команд kubectl get pods, а также скриншот результата подключения.
- Репозиторий должен содержать файлы манифестов и ссылки на них в файле README.md.

# Разбор решения задачи
### Поднял облачную машину
Зашел на нее и исправил в конфиге обновленный ip адрес, сгенерировал новые сертификаты и скопировал их в конфиг на хостовой машине включил дашборд (на всякий)б обновил для него токен и записал, проверил готовность ноды. На хостовой машине проверил дашборд, записал путь конфига в переменные окружения, проверил готовность
```bash
sudo nano /var/snap/microk8s/current/certs/csr.conf.template
sudo microk8s refresh-certs --cert server.crt
microk8s enable dashboard  
microk8s kubectl get pods -n kube-system  
microk8s kubectl create token default
microk8s status --wait-ready  
microk8s kubectl get nodes
exit
KUBECONFIG=~/.kube/config-microk8s kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
echo 'export KUBECONFIG=~/.kube/config-microk8s' >> ~/.bashrc 
source ~/.bashrc
echo $KUBECONFIG 
kubectl config view --minify 
kubectl get nodes
```

![](<Pasted image 20260824203739.png>)

## Разбор решения задания 1. Создать Pod с именем hello-world
#### создал файл-манифест `~/home/vboxuser~/microkuber/hello-world-pod.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-world
  labels:
    app: hello-world
spec:
  containers:
    - name: echoserver
      image: gcr.io/kubernetes-e2e-test-images/echoserver:2.2
      ports:
        - containerPort: 8080
```
Порт `8080` это стандартный порт, на котором слушает `echoserver`.
#### Применил манифест
```bash
kubectl apply -f hello-world-pod.yaml
```
#### Провериk, что Pod запустился
```bash
kubectl get pods
kubectl describe pod hello-world
```

![](<Pasted image 20260824204300.png>)
#### Подключился через port-forward

```bash
kubectl port-forward pod/hello-world 8080:8080
```
#### В новом терминале:
``` bash
curl http://localhost:8080
```

![](<Pasted image 20260824204510.png>)
#### В браузере:
![](<Pasted image 20260824204558.png>)

## Разбор задания 2. Создать Service и подключить его к Pod

#### Создал файл-манифест `netology-web-pod.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: netology-web
  labels:
    app: netology-web
spec:
  containers:
    - name: echoserver
      image: gcr.io/kubernetes-e2e-test-images/echoserver:2.2
      ports:
        - containerPort: 8080
```
- label `app: netology-web` должен точно совпадать с selector в Service
#### создал файл-манифест `netology-svc.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: netology-svc
spec:
  selector:
    app: netology-web
  ports:
    - name: web
      port: 80
      targetPort: 8080
```
- `port: 80` - порт  Service, `targetPort: 8080` - целевой порт, на котором реально слушает контейнер echoserver.
#### Применил оба манифеста
```bash
kubectl apply -f netology-web-pod.yaml
kubectl apply -f netology-svc.yaml
```
#### Провериk связку Pod - Service - Endpoints
```bash
kubectl get pods --show-labels
kubectl get svc netology-svc
kubectl get endpoints netology-svc
```
![](<Pasted image 20260824205433.png>)
#### подключился к поду через service
```bash
kubectl port-forward svc/netology-svc 8080:80
```
![](<Pasted image 20260824205920.png>)
#### и в соседнем терминале выполнил:
```bash 
curl http://localhost:8080
```
![](<Pasted image 20260824210054.png>)
трафик прошел путь: `локальный порт - Service - Endpoints - Pod netology-web` .
#### тоже самое для pod hello-world:
```bash
kubectl port-forward pod/hello-world 8080:8080
```
![](<Pasted image 20260824210356.png>)

