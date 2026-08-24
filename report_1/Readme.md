
#  Задание:
### Задание 1. Установка MicroK8S

1. Установить MicroK8S на локальную машину или на удалённую виртуальную машину.
2. Установить dashboard.
3. Сгенерировать сертификат для подключения к внешнему ip-адресу.

### Задание 2. Установка и настройка локального kubectl

1. Установить на локальную машину kubectl.
2. Настроить локально подключение к кластеру.
3. Подключиться к дашборду с помощью port-forward.

### Правила приёма работы

1. Домашняя работа оформляется в своём Git-репозитории в файле README.md. Выполненное домашнее задание пришлите ссылкой на .md-файл в вашем репозитории.
2. Файл README.md должен содержать скриншоты вывода команд `kubectl get nodes` и скриншот дашборда.

# Разбор решения задачи:
#### На облачной машине сделал:
```bash
sudo apt update
sudo apt install -y snapd
sudo snap install microk8s --classic
sudo usermod -a -G microk8s $USER
mkdir -p ~/.kube
chmod 0700 ~/.kube
sudo chown -f -R $USER ~/.kube
```
Эти команды делают следующее:
- `snapd` устанавливает менеджер snap-пакетов, через который распространяется MicroK8s.(https://canonical.com/microk8s/docs/getting-started)
- `sudo snap install microk8s --classic` ставит сам кластер как единый пакет.
- Добавление пользователя в группу `microk8s` нужно, чтобы потом работать с кластером без постоянного `sudo`.
После этого переподключился к удаленной машине. 
#### После повторного входа:
```bash
microk8s status --wait-ready
microk8s kubectl get nodes -o wide
```

![](<Pasted image 20260823125433.png>)

![](<Pasted image 20260823125958.png>)

#### Включаю dashboard на удалённой VM. 
Официально это делается одной командой `microk8s enable dashboard`, а для входа в Dashboard в версиях MicroK8s 1.24+ токен можно получить через `microk8s kubectl create token default`. (https://snapcraft.io/microk8s)
```bash
microk8s enable dashboard
microk8s kubectl get pods -n kube-system
microk8s kubectl create token default
```
Полученный токен сохранил для входа в Dashboard через браузер на хостовой машине.

![](<Pasted image 20260823130224.png>)
- pod'ы dashboard в `Running`  (https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
- сервис `kubernetes-dashboard-kong-proxy`, через который и будет идти `port-forward` - `Running`
в текущей версии MicroK8s dashboard разворачивается в `kubernetes-dashboard`, поэтому команда доступа отличается от примера в задании

#### Настройка  сертификата для внешнего IP `158.160.139.152`
для подключения локального `kubectl` к удалённому API. Официальная документация MicroK8s (https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/) говорит, что для доступа к API через внешний адрес нужно добавить этот адрес в `/var/snap/microk8s/current/certs/csr.conf.template`, а затем перевыпустить `server.crt`
На удаленной машине:
```bash
sudo nano /var/snap/microk8s/current/certs/csr.conf.template
```
в секцию `[ alt_names ]` добавил значение внешнего ip облачной машины: `IP.99 = 158.160.139.152`  (https://stackoverflow.com/questions/63451290/microk8s-devops-unable-to-connect-to-the-server-x509-certificate-is-valid-f/63470856)
#### Перевыпуск сертификата: 
```bash
sudo microk8s refresh-certs --cert server.crt
```
#### Проверка готовности:
```bash
microk8s status --wait-ready
microk8s kubectl get nodes
```
сертификат перевыпущен корректно: MicroK8s сделал backup, сгенерировал новый `server.crt`, перезапустил `kubelite` и `cluster-agent`, а после этого кластер снова вышел в `Ready`.

#### Устанавливаю локальный `kubectl` на хостовую. 
Для Linux официальный способ установки бинаря `kubectl` - скачать актуальный релиз с `dl.k8s.io`, сделать файл исполняемым и положить его в `/usr/local/bin`; при этом версия клиента должна быть в пределах одной minor-версии от кластера.
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
kubectl version --client
source <(kubectl completion bash)
echo 'source <(kubectl completion bash)' >> ~/.bashrc
```


![](<Pasted image 20260823131103.png>)
в текущей версии MicroK8s используется namespace `kubernetes-dashboard` и сервис `kubernetes-dashboard-kong-proxy`, а не старый `kube-system/service/kubernetes-dashboard`
#### На удалённой VM получил kubeconfig из MicroK8s:
```bash
microk8s config
```
Эта команда выводит kubeconfig MicroK8s, который затем можно использовать на внешней машине как обычный конфиг `kubectl` (https://discuss.kubernetes.io/t/where-does-microk8s-store-kubectl-config-file/11032)
На локальном хосте:
```bash
mkdir -p ~/.kube
nano ~/.kube/config-microk8s
chmod 600 ~/.kube/config-microk8s
KUBECONFIG=~/.kube/config-microk8s kubectl get nodes
```
Вставил скопированный конфиг туда и сразу заменил строку server: https://10.130.0.23:16443 на server: https://158.160.139.152:16443
После подключения последней командой  нода `minikube` отображается на хосте в статусе `Ready`

#### Подключение к Dashboard
```bash
KUBECONFIG=~/.kube/config-microk8s kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
```
#### в браузере открываю https://localhost:8443
способ подключения из офф документации (https://canonical.com/microk8s/docs/addon-dashboard)
Для входа по **token** и вставил токен, который получил на удалённой VM командой `microk8s kubectl create token default`. Для Kubernetes Dashboard официальный способ доступа - локальный `port-forward` плюс аутентификация токеном service account. (https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)

![](<Pasted image 20260823132152.png>)



