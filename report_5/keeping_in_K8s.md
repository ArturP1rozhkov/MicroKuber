

# Домашнее задание к занятию «Хранение в K8s»

### Цель задания

Научиться работать с хранилищами в тестовой среде Kubernetes:

- обеспечить обмен файлами между контейнерами пода;
- создавать **PersistentVolume** (PV) и использовать его в подах через **PersistentVolumeClaim** (PVC);
- объявлять свой **StorageClass** (SC) и монтировать его в под через **PVC**.

Это задание поможет вам освоить базовые принципы взаимодействия с хранилищами в Kubernetes — одного из ключевых навыков для работы с кластерами. На практике Volume, PV, PVC используются для хранения данных независимо от пода, обмена данными между подами и контейнерами внутри пода. Понимание этих механизмов поможет вам упростить проектирование слоя данных для приложений, разворачиваемых в кластере k8s.

---

## Задание 1. Volume: обмен данными между контейнерами в поде

### Задача

Создать Deployment приложения, состоящего из двух контейнеров, обменивающихся данными.

### Шаги выполнения

1. Создать Deployment приложения, состоящего из контейнеров busybox и multitool.
2. Настроить busybox на запись данных каждые 5 секунд в некий файл в общей директории.
3. Обеспечить возможность чтения файла контейнером multitool.

### Что сдать на проверку

- Манифесты:
    - `containers-data-exchange.yaml`
- Скриншоты:
    - описание пода с контейнерами (`kubectl describe pods data-exchange`)
    - вывод команды чтения файла (`tail -f <имя общего файла>`)

---

## Задание 2. PV, PVC

### Задача

Создать Deployment приложения, использующего локальный PV, созданный вручную.

### Шаги выполнения

1. Создать Deployment приложения, состоящего из контейнеров busybox и multitool, использующего созданный ранее PVC
2. Создать PV и PVC для подключения папки на локальной ноде, которая будет использована в поде.
3. Продемонстрировать, что контейнер multitool может читать данные из файла в смонтированной директории, в который busybox записывает данные каждые 5 секунд.
4. Удалить Deployment и PVC. Продемонстрировать, что после этого произошло с PV. Пояснить, почему. (Используйте команду `kubectl describe pv`).
5. Продемонстрировать, что файл сохранился на локальном диске ноды. Удалить PV. Продемонстрировать, что произошло с файлом после удаления PV. Пояснить, почему.

### Что сдать на проверку

- Манифесты:
    - `pv-pvc.yaml`
- Скриншоты:
    - каждый шаг выполнения задания, начиная с шага 2.
- Описания:
    - объяснение наблюдаемого поведения ресурсов в двух последних шагах.

---

## Задание 3. StorageClass

### Задача

Создать Deployment приложения, использующего PVC, созданный на основе StorageClass.

### Шаги выполнения

1. Создать Deployment приложения, состоящего из контейнеров busybox и multitool, использующего созданный ранее PVC.
2. Создать SC и PVC для подключения папки на локальной ноде, которая будет использована в поде.
3. Продемонстрировать, что контейнер multitool может читать данные из файла в смонтированной директории, в который busybox записывает данные каждые 5 секунд.

### Что сдать на проверку

- Манифесты:
    - `sc.yaml`
- Скриншоты:
    - каждый шаг выполнения задания, начиная с шага 2

---

## Шаблоны манифестов с учебными комментариями

### 1. Deployment (containers-data-exchange.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-exchange
spec:
  replicas: # ЗАДАНИЕ: Укажите количество реплик
  selector:
    matchLabels:
      app: # ДОПОЛНИТЕ: Метка для селектора
  template:
    metadata:
      labels:
        app: # ПОВТОРИТЕ: Метка из selector.matchLabels
    spec:
      containers:
      - name: # ДОПОЛНИТЕ: Имя первого контейнера
        image: busybox
        command: ["/bin/sh", "-c"] 
        args: ["echo $(date) > путь_к_файлу; sleep 3600"] # КЛЮЧЕВОЕ: Команда записи данных в файл в директории из секции volumeMounts контейнера
        volumeMounts:
        - name: # ДОПОЛНИТЕ: Имя монтируемого раздела. Должно совпадать с именем эфемерного хранилища, объявленного на уровне пода.
          mountPath: # КЛЮЧЕВОЕ: Путь монтирования эфемерного хранилища внутри контейнера 1
      - name: # ДОПОЛНИТЕ: Имя второго контейнера
        image: busybox
        command: ["/bin/sh", "-c"]
        args: ["tail -f путь_к_файлу"] # КЛЮЧЕВОЕ: Команда для чтения данных из файла, расположенного в директории, указанной в volumeMounts контейнера
        volumeMounts:
        - name: # ДОПОЛНИТЕ: Имя монтируемого раздела. Должно совпадать с именем эфемерного хранилища, объявленного на уровне пода
          mountPath: # КЛЮЧЕВОЕ: Путь монтирования эфемерного хранилища внутри контейнера 2
      volumes:
      - name: # ДОПОЛНИТЕ: Имя монтируемого раздела эфемерного хранилища
        emptyDir: {} # ИНФОРМАЦИЯ: Определяем эфемерное хранилище, которое работает только внутри пода
```

### 2. Deployment (pv-pvc.yaml)

```yaml
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: # ДОПОЛНИТЕ: Имя хранилища
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: # КЛЮЧЕВОЕ: Путь к директории на ноде (хосте, на котором развёрнут кластер)
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: # ДОПОЛНИТЕ: Имя PVC
spec:
  volumeName: # ДОПОЛНИТЕ: Имя PV, к которому будет привязан PVC, должен совпадать с созданным ранее PV
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: # ДОПОЛНИТЕ: Какой объём хранилища вы хотите передать в контейнер. Должно быть меньше или равно параметру storage из PV
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-exchange-pvc
spec:
  replicas: # ЗАДАНИЕ: Укажите количество реплик
  selector:
    matchLabels:
      app: # ДОПОЛНИТЕ: Метка для селектора
  template:
    metadata:
      labels:
        app: # ПОВТОРИТЕ: Метка из selector.matchLabels
    spec:
      containers:
      - name: # ДОПОЛНИТЕ: Имя первого контейнера
        image: busybox
        command: ["/bin/sh", "-c"] 
        args: ["echo $(date) > путь_к_файлу; sleep 3600"] # КЛЮЧЕВОЕ: Команда записи данных в файл в директории из секции volumeMounts контейнера 
        volumeMounts:
        - name: # ДОПОЛНИТЕ: Имя монтируемого раздела. Должно совпадать с именем хранилища, объявленного на уровне пода
          mountPath: # КЛЮЧЕВОЕ: Путь монтирования хранилища внутри контейнера 1
      - name: # ДОПОЛНИТЕ: Имя второго контейнера
        image: busybox
        command: ["/bin/sh", "-c"]
        args: ["tail -f путь_к_файлу"] # КЛЮЧЕВОЕ: Команда для чтения данных из файла, расположенного в директории, указанной в volumeMounts контейнера
        volumeMounts:
        - name: # ДОПОЛНИТЕ: Имя монтируемого раздела. Должно совпадать с именем хранилища, объявленного на уровне пода
          mountPath: # КЛЮЧЕВОЕ: Путь монтирования хранилища внутри контейнера 2
      volumes:
      - name: # ДОПОЛНИТЕ: Имя монтируемого раздела хранилища
        persistentVolumeClaim:
          claimName: # КЛЮЧЕВОЕ: Совпадает с именем PVC объявленного ранее
```

### 3. Deployment (sc.yaml)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: # ДОПОЛНИТЕ: Имя StorageClass
provisioner: kubernetes.io/no-provisioner # ИНФОРМАЦИЯ: Нет автоматического развёртывания
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: # ДОПОЛНИТЕ: Имя PVC
spec:
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: # ДОПОЛНИТЕ: Какой объем хранилища вы хотите передать в контейнер. Должно быть меньше или равно параметру storage из PV
  storageClassName: # ДОПОЛНИТЕ: Имя StorageClass. Должно совпадать с объявленным ранее
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-exchange-sc
spec:
  replicas: # ЗАДАНИЕ: Укажите количество реплик
  selector:
    matchLabels:
      app: # ДОПОЛНИТЕ: Метка для селектора
  template:
    metadata:
      labels:
        app: # ПОВТОРИТЕ: Метка из selector.matchLabels
    spec:
      containers:
      - name: # ДОПОЛНИТЕ: Имя первого контейнера
        image: busybox
        command: ["/bin/sh", "-c"] 
        args: ["echo $(date) > путь_к_файлу; sleep 3600"] # КЛЮЧЕВОЕ: Команда для чтения данных из файла, расположенного в директории, указанной в volumeMounts контейнера
        volumeMounts:
        - name: # ДОПОЛНИТЕ: Имя монтируемого раздела. Должно совпадать с именем хранилища, объявленного на уровне пода
          mountPath: # КЛЮЧЕВОЕ: Путь монтирования хранилища внутри контейнера 1
      - name: # ДОПОЛНИТЕ: Имя второго контейнера
        image: busybox
        command: ["/bin/sh", "-c"]
        args: ["tail -f путь_к_файлу"] # КЛЮЧЕВОЕ: Команда для чтения данных из файла, расположенного в директории, указанной в volumeMounts контейнера
        volumeMounts:
        - name: # ДОПОЛНИТЕ: Имя монтируемого раздела. Должно совпадать с именем хранилища, объявленного на уровне пода
          mountPath: # КЛЮЧЕВОЕ: Путь монтирования хранилища внутри контейнера 2
      volumes:
      - name: # ДОПОЛНИТЕ: Имя монтируемого раздела хранилища
        persistentVolumeClaim:
          claimName: # КЛЮЧЕВОЕ: Совпадает с именем PVC объявленного ранее
```


# Разбор решения задач
### Обновляю файл - manifest Deployment (`containers-data-exchange.yaml`) из шаблона

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-exchange
spec:
  replicas: 1
  selector:
    matchLabels:
      app: data-exchange
  template:
    metadata:
      labels:
        app: data-exchange
    spec:
      containers:
      - name: busybox-writer
        image: busybox
        command: ["/bin/sh", "-c"]
        args: ["while true; do echo $(date) >> /data/shared.log; sleep 5; done"]
        volumeMounts:
        - name: shared-data
          mountPath: /data
      - name: multitool-reader
        image: wbitt/network-multitool
        command: ["/bin/sh", "-c"]
        args: ["tail -f /data/shared.log"]
        volumeMounts:
        - name: shared-data
          mountPath: /data
      volumes:
      - name: shared-data
        emptyDir: {}
```

- **Имена контейнеров** (`busybox-writer`, `multitool-reader`) сделаны так, чтобы в `kubectl describe pods` и `kubectl exec -c <name>` сразу было понятно, какой контейнер за что отвечает.
- **Команда записи**: `echo ... > файл; sleep 3600` из шаблона запишет данные один раз и уснёт.  Заменил на `while true; do echo $(date) >> файл; sleep 5; done` - цикл с дозаписью (`>>`, а не `>`).
- **mountPath одинаковый в обоих контейнерах** (`/data`), иначе они будут видеть разные (непересекающиеся) файловые деревья, 
- образ `wbitt/network-multitool` собран на базе Alpine (есть и вариант на Ubuntu с тегом `-extra` или `-al`, если нужны дополнительные утилиты), и в нём тоже доступен `/bin/sh`, поэтому команда `tail -f` в `command`/`args` остаётся без изменений.
- **selector.matchLabels и template.labels** обязаны совпадать буквально.
- **Один volume на два разных образа** потому, что это ресурс уровня Pod, а не контейнера; тип и происхождение образов не влияют на возможность общего доступа к файловой системе.


### применил и проверил:
```bash
kubectl apply -f containers-data-exchange.yaml
kubectl get pods -o wide 
kubectl logs deployment/data-exchange -c multitool-reader --follow
```

![](<Pasted image 20260903145927.png>)

![](<Pasted image 20260903150011.png>)

## `describe pods`

- **Оба контейнера в состоянии Running, Ready: True**. Под `2/2 Running`, то есть Kubernetes подтверждает, что оба контейнера успешно стартовали и здоровы.
- **Volumes - shared-data - Type: EmptyDir**: используется хранилище уровня пода, а не отдельного контейнера.
- **Mounts у обоих контейнеров: `/data from shared-data (rw)`** - оба контейнера монтируют один и тот же volume в одну и ту же точку, что и обеспечивает обмен файлом между ними.
## `kubectl logs kubectl logs deployment/data-exchange -c multitool-reader --follow`
Вывод показывает временные метки с шагом по 5 секунд, значит busybox-writer  дописывает файл каждые 5 секунд, а multitool-reader корректно читает поток через `tail -f` в реальном времени.

### файл в контейнере:

![](<Pasted image 20260903151251.png>)

# Разбор решения задачи 2:
### Обновляю файл - manifest Deployment (`pv-pvc.yaml`) из шаблона

```yaml
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-exchange-pv
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/data-exchange
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-exchange-pvc
spec:
  volumeName: data-exchange-pv
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-exchange-pvc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: data-exchange-pvc
  template:
    metadata:
      labels:
        app: data-exchange-pvc
    spec:
      containers:
      - name: busybox-writer
        image: busybox
        command: ["/bin/sh", "-c"]
        args: ["while true; do echo $(date) >> /data/shared.log; sleep 5; done"]
        volumeMounts:
        - name: shared-data
          mountPath: /data
      - name: multitool-reader
        image: wbitt/network-multitool
        command: ["/bin/sh", "-c"]
        args: ["tail -f /data/shared.log"]
        volumeMounts:
        - name: shared-data
          mountPath: /data
      volumes:
      - name: shared-data
        persistentVolumeClaim:
          claimName: data-exchange-pvc
```

- **persistentVolumeReclaimPolicy: Retain** : определяет, что произойдёт с данными на диске ноды после удаления PVC. При `Retain` PV не удаляется автоматически и не готов к переиспользованию сразу. Данные сохраняются, PV переходит в статус `Released`. 
- **volumeName в PVC жёстко привязывает его к конкретному PV** (static provisioning). Без этого поля PVC мог бы связаться с любым подходящим по размеру/accessModes PV в кластере.
- **storage в PVC (1Gi) равен storage в PV (1Gi)** - по спецификации Kubernetes PVC может запросить объём меньше или равный объёму PV, но не больше, иначе связывание (binding) не произойдёт.
- **hostPath.path: /mnt/data-exchange** - выбрана директория вне стандартных системных путей Minikube, чтобы не конфликтовать с существующими данными на ноде.

Директория `/mnt/data-exchange` должна существовать на ноде Minikube заранее - Kubernetes с `hostPath` не создаёт директорию, если тип не указан как `DirectoryOrCreate` (в шаблоне это не задано, значит директория должна быть создана вручную). Поэтому зашел на ноду и создал директорию:

```bash
ssh -l yc-user 158.160.209.10
sudo mkdir -p /mnt/data-exchange
sudo chmod 777 /mnt/data-exchange
exit
```

### применил и проверил:

```bash
kubectl apply -f pv-pvc.yaml
kubectl get pv
kubectl get pvc
kubectl get pods -o wide
```

![](<Pasted image 20260903152724.png>)

- **kubectl get pv** -  `STATUS` `Bound`
- **kubectl get pvc**  `STATUS: Bound`,  в колонке `VOLUME` - имя `data-exchange-pv`, подтверждает связь именно с этим PV.
- **kubectl get pods** - под `data-exchange-pvc-...`  - `2/2 Running`. 

### обмен данными через **постоянное** хранилище:

```bash
kubectl get pv,pvc
kubectl logs deployment/data-exchange-pvc -c multitool-reader --follow
```

![](<Pasted image 20260903153551.png>)

![](<Pasted image 20260903153608.png>)

Контейнер `busybox-writer` записывает в файл `/data/shared.log` новую временную метку раз в 5 секунд. Контейнер `multitool-reader` читает этот же файл в режиме `tail -f`. Результат: `multitool-reader` получает новые строки каждые 5 секунд, значит общий файл на PVC успешно монтирован в оба контейнера. В отличие от задания 1, за `/data/shared.log` стоит PV `data-exchange-pv`, использующий директорию `/mnt/data-exchange` на ноде, данные находятся на файловой системе ноды, а не внутри жизненного цикла пода.

### Удаляю Deployment и PVC. Демонстрирую, что после этого произошло с PV. Пояснения.

```bash
kubectl delete deployment data-exchange-pvc
kubectl wait --for=delete pod -l app=data-exchange-pvc --timeout=60s
kubectl delete pvc data-exchange-pvc
kubectl get pv 
kubectl describe pv data-exchange-pv
```

![](<Pasted image 20260903154142.png>)

После удаления Deployment `data-exchange-pvc` и PVC `data-exchange-pvc` PersistentVolume `data-exchange-pv` перешёл в состояние Released. Это связано с политикой `persistentVolumeReclaimPolicy: Retain`: Kubernetes не удаляет объект PV и не очищает физическое хранилище после удаления PVC. В поле Claim остаётся ссылка на удалённый PVC `default/data-exchange-pvc`, что показывает предыдущую привязку тома. Повторное автоматическое использование такого PV не выполняется: для него требуется вручную принять решение, чтобы исключить непреднамеренную передачу оставшихся данных другому потребителю.
### Доказать, что файл сохранился **на ноде**, не в Kubernetes-контейнере. После удаления повторная проверка на ноде

```bash
ssh -l yc-user 158.160.209.10
sudo ls -lah /mnt/data-exchange 
sudo tail -n 10 /mnt/data-exchange/shared.log
exit
kubectl delete pv data-exchange-pv
kubectl get pv
```

![](<Pasted image 20260903154829.png>)

После удаления Deployment и PVC файл `shared.log` сохранился в директории `/mnt/data-exchange` на ноде Minikube, так как PV использует hostPath, то есть существующую директорию на локальной файловой системе ноды, а политика Retain не удаляет связанное хранилище после удаления PVC. Kubernetes считает такой том освобождённым, но данные предыдущего потребителя остаются до ручной очистки администратором.

![](<Pasted image 20260903155557.png>)

После удаления объекта PV `data-exchange-pv` файл `shared.log` в директории `/mnt/data-exchange` остался неизменным на ноде minikube. Это связано с тем, что PV типа hostPath - это ссылка Kubernetes на существующую директорию на локальной файловой системе ноды, а не самостоятельно управляемый физический носитель. Удаление PV удаляет только API-объект и запись о привязке, но не инициирует очистку данных на диске, поскольку у hostPath нет провижининга и деинициализации хранилища на уровне плагина.

# Разбор решения задачи 3
## Cоздание Deployment приложения, использующего PVC, созданного на основе StorageClass.

### Доработал manifest - файл `sc.yaml`

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-exchange-sc-pv
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /mnt/data-exchange-sc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-exchange-sc-pvc
spec:
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-storage
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-exchange-sc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: data-exchange-sc
  template:
    metadata:
      labels:
        app: data-exchange-sc
    spec:
      containers:
      - name: busybox-writer
        image: busybox
        command: ["/bin/sh", "-c"]
        args: ["while true; do echo $(date) >> /data/shared.log; sleep 5; done"]
        volumeMounts:
        - name: shared-data
          mountPath: /data
      - name: multitool-reader
        image: wbitt/network-multitool
        command: ["/bin/sh", "-c"]
        args: ["tail -f /data/shared.log"]
        volumeMounts:
        - name: shared-data
          mountPath: /data
      volumes:
      - name: shared-data
        persistentVolumeClaim:
          claimName: data-exchange-sc-pvc
```

- **storageClassName совпадает в PV, PVC и объявлении SC** (`local-storage`) - это поле, а не `volumeName`связывает PVC с подходящим PV. Если PV не будет иметь такой же `storageClassName`, PVC останется в статусе `Pending`.
- **Новый путь `hostPath.path: /mnt/data-exchange-sc`** -  отличается от пути в задании 2 (`/mnt/data-exchange`), чтобы избежать коллизий между заданиями и случайного использования старого файла из прошлого шага в новом сценарии.
- **PVC без `volumeName`** - принципиальное отличие от задания 2. Связывание происходит динамически по StorageClass, а не статически по конкретному имени PV.

### На ноде перед применением создал соответствующую директорию

```bash
ssh -l yc-user 158.160.209.10
sudo mkdir -p /mnt/data-exchange-sc
sudo chmod 777 /mnt/data-exchange-sc
exit
```
### Применил и проверил:

```bash
kubectl apply -f sc.yaml
kubectl get storageclass
kubectl get pv
kubectl get pvc
kubectl get pods -o wide
```

![](<Pasted image 20260903233947.png>)

- `StorageClass local-storage`. `PROVISIONER: kubernetes.io/no-provisioner`, `VOLUMEBINDINGMODE: WaitForFirstConsumer` - класс описывает локальное хранилище без автоматического создания PV. PVC привязывается после появления первого потребителя.
- `data-exchange-sc-pv``STATUS: Bound`, `CLAIM: default/data-exchange-sc-pvc`, `STORAGECLASS: local-storage`. Подходящий заранее созданный PV был выбран и связан с PVC по классу хранения.
- `data-exchange-sc-pvc``STATUS: Bound`, `VOLUME: data-exchange-sc-pv`, `STORAGECLASS: local-storage`. PVC получил доступ к PV без поля `volumeName`.Выбор выполнен через требования PVC и совпадающий `storageClassName`.
- `data-exchange-sc-...``2/2 Running`, нода `minikube`. Оба контейнера запущены и успешно смонтировали PVC.
- В выводе StorageClass `RECLAIMPOLICY: Delete`, хотя у вручную объявленного PV видно `RECLAIM POLICY: Retain`. Это не противоречие. `reclaimPolicy: Delete` у StorageClass - значение по умолчанию для PV, которые **мог бы динамически создать provisioner**. Но `kubernetes.io/no-provisioner` не выполняет динамический provisioning, а существующий PV создан вручную и имеет свою явную настройку `persistentVolumeReclaimPolicy: Retain`. Именно эта настройка PV будет определять его при удалении PVC.
### Чтение общего файла через PVC, созданный на основе StorageClass:

```bash
kubectl logs deployment/data-exchange-sc -c multitool-reader --follow
kubectl exec deployment/data-exchange-sc -c multitool-reader -- ls -lah /data
kubectl exec deployment/data-exchange-sc -c multitool-reader -- tail -n 10 /data/shared.log
```

![](<Pasted image 20260903234219.png>)

![](<Pasted image 20260903235008.png>)

Создан StorageClass local-storage с provisioner `kubernetes.io/no-provisioner` и режимом `WaitForFirstConsumer`. Так как provisioner не создаёт хранилище автоматически, `PersistentVolume` был подготовлен вручную с тем же `storageClassName: local-storage`.` PVC data-exchange-sc-pvc` не содержит поля `volumeName`, поэтому Kubernetes выбрал подходящий PV по параметрам запроса и `StorageClass`. После создания Deployment PVC и PV перешли в состояние Bound, а оба контейнера Pod получили общий доступ к смонтированной директории `/data`.
Вывод подтверждает выполнение задания 3: контейнер `multitool-reader` читает тот же файл, в который контейнер `busybox-writer` записывает строки каждые 5 секунд. PVC `data-exchange-sc-pvc` выступает промежуточным слоем между Pod и PV, выбранным по `StorageClass local-storage`.

