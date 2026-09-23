---
type: Курс по DevOPS Home Work
module: Kubernetes
lesson_no: 10
lesson_theme: Как работает сеть в K8s
---
> [!bookmark]
>
> **Домашнее задание: <%+ tp.file.title %>**


## Задание: Создать сетевую политику или несколько политик для обеспечения доступа

1. Создать deployment'ы приложений frontend, backend и cache и соответствующие сервисы.
2. В качестве образа использовать network-multitool.
3. Разместить поды в namespace App.
4. Создать политики, чтобы обеспечить доступ frontend -> backend -> cache. Другие виды подключений должны быть запрещены.
5. Продемонстрировать, что трафик разрешён и запрещён.

## Разбор решения задания:

Инфраструктурную часть закрываю файлами Terraform из предыдущего задания: 1 master node, 2 worker node. Файлы в репозитории проекта. 
![](<Pasted image 20260923115736.png>)

![](<Pasted image 20260923121106.png>)

![](<Pasted image 20260923121137.png>)

##### бутстрап кластера:
```bash
sudo kubeadm init \
  --apiserver-advertise-address 10.10.1.10 \
  --pod-network-cidr 192.168.0.0/16
```

![](<Pasted image 20260923122534.png>)

##### Kubeconfig для пользователя (с Master)
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes
```

##### CNI  Calico
``` bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/calico.yaml
kubectl get pods -n kube-system -w
```

![](<Pasted image 20260923123351.png>)
##### Присоединение воркеров (с хостовой машины)
``` bash
for i in 11 12; do
  echo "=== join worker 10.10.2.$i ==="
  ssh -J ubuntu@111.88.243.38 ubuntu@10.10.2.$i \
    "sudo kubeadm join 10.10.1.10:6443 --token 3uy7bt.0el9cshfpoiyno10 \
        --discovery-token-ca-cert-hash sha256:99e85a74bfe356122dc970b2278715d599bd39ef3a62d1a1ab02b5231fa47a75"
done
```

![](<Pasted image 20260923123833.png>)

```bash
kubectl get nodes -o wide          # 3 ноды, все Ready
kubectl get pods -n kube-system    # calico-node ×3, coredns Running
```

![](<Pasted image 20260923124332.png>)

![](<Pasted image 20260923124402.png>)
Три ноды Ready и все calico-node/kube-proxy поды Running.  Calico выдал каждой ноде свой /24 из 192.168.0.0/16.



#### Файлы - манифесты. В каждом Deployment + Service связкой.
##### k8s-00-Namespace
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: app
  labels:
    name: app
```

##### k8s-01-frontend
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: app
  labels:
    app: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend   # именно этот label используем в NetworkPolicy
    spec:
      containers:
        - name: network-multitool
          image: wbitt/network-multitool:latest
          ports:
            - containerPort: 80
              protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: app
  labels:
    app: frontend
spec:
  type: ClusterIP          # внутренний сервис: доступ к frontend оформляем через kubectl port-forward
  selector:
    app: frontend          # selector сервиса = label пода -> трафик на podIP:80
  ports:
    - name: http
      protocol: TCP
      port: 80             # порт сервиса
      targetPort: 80       # порт контейнера (можно указать именем, если name у containerPort)
```

##### k8s-02-backend
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: app
  labels:
    app: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: network-multitool
          image: wbitt/network-multitool:latest
          ports:
            - containerPort: 80
              protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: app
  labels:
    app: backend
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
```

##### k8s-03-cache
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache
  namespace: app
  labels:
    app: cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache
  template:
    metadata:
      labels:
        app: cache
    spec:
      containers:
        - name: network-multitool
          image: wbitt/network-multitool:latest
          ports:
            - containerPort: 80
              protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: cache
  namespace: app
  labels:
    app: cache
spec:
  type: ClusterIP
  selector:
    app: cache
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
```

- Нумерация по очередности раскатывания на ноды через SSH
- **Namespace** - app namespace - DNS label
- **Deployment/Service связаны лейблами**: `metadata.labels` у пода, `spec.selector` у деплоя и `spec.selector` у сервиса везде повторяют `app: frontend|backend|cache`. Эти же лейблы позже уедут в `podSelector` NetworkPolicy - селекторы работают только с ними.
- **Порт 80** - встроенный HTTP-сервер wbitt/network-multitool слушает 80 порт; `targetPort: 80` у сервиса к нему и ведёт.
- **ClusterIP везде, в том числе у frontend** для внутрикластерной изоляции. Проверять frontend буду через `kubectl port-forward svc/frontend 8080:80 -n app` (`port-forward` идёт напрямую в под мимо ClusterIP).

##### деплой приложений в namespace app через stdin в SSH:
``` bash
for f in manifests/k8s-*.yaml; do
  echo "=== apply $f ==="
  cat "$f" | ssh ubuntu@111.88.243.38 kubectl apply -f -
done
```

Порядок здесь критичен из-за `kubectl apply -f` - через stdin: деплои ссылаются на namespace app, и если 00-namespace пойдёт не первым, получится ошибка namespaces "app" not found

![](<Pasted image 20260923132524.png>)

##### Проверяю:
```bash
# namespace создан, его labels
ssh ubuntu@111.88.243.38 kubectl get ns app --show-labels

# поды: статус, ноды, IP
ssh ubuntu@111.88.243.38 kubectl -n app get pods -o wide -w

# сервисы и их endpoints
ssh ubuntu@111.88.243.38 kubectl -n app get svc
ssh ubuntu@111.88.243.38 kubectl -n app get endpoints
```

![](<Pasted image 20260923132905.png>)

##### В namespace `app` нет ни одной NetworkPolicy.
Весь трафик между подами разрешён в прямую, и в обратную сторону.
```bash
# frontend -> backend и frontend -> cache
# backend -> frontend и backend -> cache
# cache -> frontend и cache -> backend  

for src in frontend backend cache; do
  for dst in frontend backend cache; do
    [ "$src" = "$dst" ] && continue
    echo "===== $src -> $dst ====="
    ssh ubuntu@111.88.243.38 kubectl -n app exec deploy/$src -- curl -sS -m 3 http://$dst
    echo; echo
  done
done

```

![](<Pasted image 20260923142252.png>)

- все шесть пар возвращают баннер с именем отвечавшего пода. В баннере видно, какой именно под (backend-58d9c4c8fc-lb28l и его podIP) ответил ClusterIP-сервису.
---
#### Планирование политик: 

##### Подход A: default-deny только на Ingress. 
Запрет всем подам принимать входящие соединения, затем разрешение: backend принимает от frontend, cache принимает от backend. Матрица приложений сработает, но исходящий трафик останется свободным - cache сможет сходить в интернет или в любой под кластера. Формально «другие виды подключений запрещены», но это не отвечает цели задания.

##### Подход B: default-deny на Ingress + Egress. 
Полная изоляция в обе стороны, затем точечные разрешения. 
- Политика с policyTypes: `[Ingress, Egress]` и пустыми `podSelector: {}` применяется ко всем подам `namespace` и запрещает и приём, и отправку.
- Разрешение на одном конце не даёт права другому: ingress-правило на backend «прими от frontend» не создаёт права frontend'у отправлять. Из-за default-deny на Egress frontend'у нужно собственное egress-разрешение «иди к backend». То есть каждая связь разрешается дважды - на отправителе и на получателе.
- Общий default-deny на Egress сломает и резолвинг DNS: запросы подов уходят к CoreDNS (10.96.0.10:53) в namespace kube-system. Поэтому нужно отдельное общее разрешение на DNS, иначе curl по имени отвалится.

##### Вариант политик: четыре файла / пять объектов:

| Назначение файла    | Объект(ы)  | Что разрешает                                             |
| ------------------- | ---------- | --------------------------------------------------------- |
| default-deny        | 1 политика | Запрещает весь ingress и egress всем подам в app          |
| allow-dns           | 1 политика | Всем подам: egress к kube-dns в kube-system, UDP+TCP:53   |
| frontend-to-backend | 2 политики | frontend egress->backend:80; backend ingress<-frontend:80 |
| backend-to-cache    | 2 политики | backend egress->cache:80; cache ingress<-backend:80       |
frontend'у не разрешён никакой ingress (ему никто не должен писать), cache'у - никакого egress кроме DNS («запрещённые» направления). 

#### Создал 4 файла в папке manifests
##### k8s-04-default-deny.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: app
  labels:
    purpose: netpol-homework
spec:
  podSelector: {}          # пустой селектор выбирает все поды namespace
  policyTypes:
    - Ingress
    - Egress
```

- `podSelector {}` = ВСЕ поды namespace app. 
- `policyTypes` перечислены оба, но правил ingress/egress нет 
- `ingress/egress` отсутствуют - все соединения обоих направлений запрещены

##### k8s-05-allow-dns.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: app
  labels:
spec:
  podSelector: {}          
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

- Разрешение на DNS: без него после default-deny на Egress поды теряют резолвинг имён, так как CoreDNS живёт в namespace kube-system (Service kube-dns, ClusterIP 10.96.0.10), а default-deny его отрезает. Разрешаем ТОЛЬКО 53/udp и 53/tcp к подам kube-dns.
##### k8s-06-frontend-to-backend.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress-to-backend
  namespace: app
  labels:
spec:
  podSelector:
    matchLabels:
      app: frontend      
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-ingress-from-frontend
  namespace: app
  labels:
spec:
  podSelector:
    matchLabels:
      app: backend       
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 80
```

- Связь от frontend до backend. Из-за default-deny на оба направления одну связь надо разрешить дважды: отправителю (egress с frontend) и получателю (ingress на backend).
- frontend может отправлять только в backend:80 (плюс DNS из 05-файла)
- backend может принимать только от frontend:80
##### k8s-07-backend-to-cache.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress-to-cache
  namespace: app
  labels:
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: cache
      ports:
        - protocol: TCP
          port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cache-ingress-from-backend
  namespace: app
  labels:
spec:
  podSelector:
    matchLabels:
      app: cache
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 80
```
- backend может отправлять только в cache:80 (плюс DNS из 05-файла)
- cache может принимать только от backend:80.
- Ingress-правил больше нет (default-deny) на frontend и на cache никто больше не попадёт, а сам cache никуда не выйдет.

#### применяю политики
```bash
for f in manifests/k8s-0[4-7]-*.yaml; do
  echo "=== apply $f ==="
  cat "$f" | ssh ubuntu@111.88.243.38 kubectl apply -f -
done
```
![](<Pasted image 20260923151501.png>)
##### запрос политик
```bash
ssh ubuntu@111.88.243.38 kubectl -n app get networkpolicies
```
![](<Pasted image 20260923151616.png>)

##### рендер одного из правил
```bash
ssh ubuntu@111.88.243.38 kubectl -n app describe networkpolicy backend-ingress-from-frontend
```
![](<Pasted image 20260923151720.png>)

#### проверка связанности циклом
```bash
for src in frontend backend cache; do
  for dst in frontend backend cache; do
    [ "$src" = "$dst" ] && continue
    echo "===== $src -> $dst ====="
    ssh ubuntu@111.88.243.38 kubectl -n app exec deploy/$src -- curl -sS -m 3 http://$dst
    echo "exit_code=$?"
    echo
  done
done



ssh ubuntu@111.88.243.38 kubectl -n app exec deploy/frontend -- nslookup backend

ssh ubuntu@111.88.243.38 kubectl -n app exec deploy/frontend -- curl -sS -m 3 https://ya.ru; echo "exit_code=$?"
```

![](<Pasted image 20260923152655.png>)

- frontend -> backend и backend -> cache разрешены, баннеры, exit 0. Цепочка из задания работает.
- Все четыре запрещённые цепочки - exit 28 после 3001–3002 мс таймаута, то есть Calico дропает пакеты.
- nslookup резолвит через 10.96.0.10 - DNS-правило в 05 файле работает.
- ya.ru: резолв прошёл, TCP 443 отвалился, что подтверждает что  «DNS разрешён / транспорт запрещён».


> [!calendar] Дата
> **Добавлено:** 2026-09-22  19:57
> **Изменено: **<%+ tp.file.last_modified_date("YYYY-MM-DD HH:mm") %>
> **Тема задания:** <%+ tp.file.title %>
