

### Инструменты и дополнительные материалы, которые пригодятся для выполнения задания

1. [Инструкция по установке kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/).
2. [Документация kubespray](https://kubespray.io/).

-----
### Задание 1. Установить кластер k8s с 1 master node

1. Подготовка работы кластера из 5 нод: 1 мастер и 4 рабочие ноды.
2. В качестве CRI — containerd.
3. Запуск etcd производить на мастере.
4. Способ установки выбрать самостоятельно.

------
### Задание 2*. Установить HA кластер

1. Установить кластер в режиме HA.
2. Использовать нечётное количество Master-node.
3. Для cluster ip использовать keepalived или другой способ.

# Разбор решения задания:

## Задание 1
Для упрощения задачи развертывание ВМ-инфраструктуры (образы ubuntu, сеть, статичные ip адреса нод и др.) в облаке решил делать через Terraform. Сloud-init будет делать первичную настройку (пользователь, swap, kernel-модули, sysctl, containerd, kubeadm/kubelet/kubectl), а кластер буду связывать руками через kubeadm.

### Создал файлы:
#### providers.tf
```yaml
terraform {
  required_version = ">= 1.3"

  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone     
}

```

##### Блок terraform - метаданные самого проекта.
- terraform {  - служебный блок, где описываются требования к окружению
- required_version = ">= 1.3" - ограничение на версию бинарника Terraform, которым разрешено работать с этим кодом. 
- required_providers { - вложенный блок, перечисляющий все провайдеры, от которых зависит конфигурация. 
- yandex = { - это локальное имя, под которым провайдер известен в коде ( `yandex_vpc_network`, `yandex_compute_instance`).
- source = "yandex-cloud/yandex" - адрес в реестре провайдеров (registry.terraform.io): организация yandex-cloud, провайдер yandex. Это то место, откуда terraform init скачивает плагин. Обратите внимание, что тут нет version = "..." — намеренно: точную версию фиксирует файл .terraform.lock.hcl (мы его специально коммитим в git). 
##### Блок provider "yandex" - конфигурация подключения.

- provider "yandex" { - настройка уже скачанного плагина: куда подключаться и от чьего имени работать.
- `cloud_id = var.cloud_id` - идентификатор облака в Yandex Cloud. Значение в переменной `var.cloud_id`  в файле variables.tf и заполненной в terraform.tfvars. 
- `folder_id = var.folder_id` - каталог внутри облака.
- zone = var.zone - зона доступности по умолчанию (ru-central1-a). 

В файле нет токена и ключа. Аутентификация провайдера берётся из переменной окружения YC_TOKEN (export YC_TOKEN=$(yc iam create-token)), Terraform читает её автоматически. 

#### variables.tf
``` yaml
variable "cloud_id" {
  type        = string
  description = "ID облака Yandex Cloud"
}

variable "folder_id" {
  type        = string
  description = "ID каталога, в котором создаются ресурсы"
}

variable "zone" {
  type        = string
  default     = "ru-central1-a"
  description = "Зона доступности"
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
  description = "Путь к публичному SSH-ключу"
}

variable "k8s_minor" {
  type        = string
  default     = "v1.34"
  description = Минорная ветка Kubernetes
}

variable "preemptible" {
  type        = bool
  default     = true
  description = Прерываемые ВМ
}

variable "public_subnet_cidr" {
  type        = string
  default     = "10.10.1.0/24"
  description = "Подсеть с единственной «публичной» нодой (мастер)"
}

variable "private_subnet_cidr" {
  type        = string
  default     = "10.10.2.0/24"
  description = "Изолированная подсеть с worker-нодами"
}

```

- Синтаксис: variable "имя" { ... } - блок, который объявляет входной параметр конфигурации. Это контракт модуля: всё, что может отличаться между запусками/окружениями, выносится сюда. Ссылка на значение в остальном коде - через var.имя.

- Три аргумента внутри:

type = string / type = bool - тип переменной. У нас два типа: string для идентификаторов и путей, bool для флага прерываемости.

default = ... - значение по умолчанию. Есть default - переменную можно не задавать; нет default - Terraform потребует значение любым доступным способом.

description = ... - описание переменной. Когда Terraform просит значение интерактивно, он показывает именно этот текст. 

Приоритет значений - откуда берётся число, если оно задано в нескольких местах. Цепочка от сильного к слабому: флаг командной строки -var, далее файл -var-file (terraform.tfvars), далее переменная окружения TF_VAR_имя или default из кода. 

- cloud_id, folder_id - идентификаторы облака и каталога. Эти значения уникальны для каждого владельца облака.

- zone - зона доступности. default - ru-central1-a.

- ssh_public_key_path - путь к публичному ключу. Используется в instances.tf в конструкции trimspace(file(pathexpand(...))): pathexpand разворачивает ~ в домашний каталог, file читает содержимое, trimspace срезает возможный перевод строки в конце. Ключ объявлен путём, а не значением - в файл конфигурации не тащится даже публичная часть ключа, она читается с хостовой машины в момент plan.

- k8s_minor - минорная ветка Kubernetes, (v1.37). От неё в cloud-init собирается URL apt-репозитория pkgs.k8s.io/core:/stable:/v1.37/deb. Это переменная, а не константа в шаблоне: ветка меняется со временем, и менять её надо в одном месте, гарантируя одинаковую версию на всех нодах (kubeadm требует идентичности kubelet на нодах).

- preemptible - флаг прерываемости ВМ в Yandex Cloud из соображений экономии средств. Флаг вынесен в переменную, чтобы переключение на обычные ВМ делалось одной строкой в tfvars.

- public_subnet_cidr, private_subnet_cidr - адресные планы двух подсетей. Это основа всей сетевой схемы: 10.10.1.0/24 - «публичная» подсеть мастера, 10.10.2.0/24 - приватная для воркеров. Вынесены в переменные, потому что от них зависят ещё статические адреса нод в instances.tf - при смене CIDR всё меняется согласованно через одно место.

#### terraform.tfvars
```yaml
# значения переменных под мое облако.
cloud_id  = "b1g3g3a6ro9rr9hd0mvm"

folder_id = "b1grsjmidldjs2rmkgd0"

zone = "ru-central1-a"

ssh_public_key_path = "~/.ssh/id_ed25519.pub"

k8s_minor   = "v1.37"  

preemptible = true    

```
конкретные значения моего облака: b1g3g3a6ro9rr9hd0mvm / b1grsjmidldjs2rmkgd0 / ru-central1-a, версия k8s, значения флага прерываемости  и путь к SSH-ключу. 
#### network.tf
```yaml
# сетевой слой кластера.
locals {
  master_ip = "10.10.1.10"
}

resource "yandex_vpc_network" "k8s" {
  name = "k8s-course-net"
}

resource "yandex_vpc_subnet" "public" {
  name           = "k8s-public-a"
  network_id     = yandex_vpc_network.k8s.id
  zone           = var.zone
  v4_cidr_blocks = [var.public_subnet_cidr]
}

resource "yandex_vpc_subnet" "private" {
  name           = "k8s-private-a"
  network_id     = yandex_vpc_network.k8s.id
  zone           = var.zone
  v4_cidr_blocks = [var.private_subnet_cidr]

  route_table_id = yandex_vpc_route_table.k8s.id
}

resource "yandex_vpc_route_table" "k8s" {
  name       = "k8s-private-via-master"
  network_id = yandex_vpc_network.k8s.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = local.master_ip
  }
}

```

- locals { master_ip = "10.10.1.10" } - именованная константа проекта. Внутренний IP мастера не должен меняться пользователем, он часть архитектуры (на него смотрят route table, /etc/hosts, kubeadm-адрес), поэтому это local, а не var. Обращение - local.master_ip.

- Синтаксис resource "yandex_vpc_network" "k8s" - три уровня адреса: тип (yandex_vpc_network - что создаём, префикс провайдера), имя (k8s - задаю логическое имя), и полный адрес yandex_vpc_network.k8s, по которому на ресурс ссылаются другие блоки. 

- resource "yandex_vpc_network" - сеть. VPC в Yandex Cloud - изолированный L3-домен: ресурсы разных сетей не видят друг друга без специальных средств. Для учебного проекта специально создал отдельную k8s-course-net: у учебного проекта свой жизненный цикл, terraform destroy снесёт только её.

- resource "yandex_vpc_subnet" "public" - публичная подсеть.

- network_id = yandex_vpc_network.k8s.id - неявная зависимость: ссылка на атрибут .id ещё не созданного ресурса. Terraform строит из таких ссылок граф (DAG) и гарантирует: сначала сеть, потом подсеть. 

- zone = var.zone - подсеть привязана к зоне (подсеть - всегда в одной зоне, зона может содержать много подсетей).

- `v4_cidr_blocks = [var.public_subnet_cidr]` - список IPv4-диапазонов подсети (10.10.1.0/24). Квадратные скобки - это HCL-список.

Чего у этой подсети нет: `route_table_id`. Это прямое следствие ограничения Yandex Cloud: ВМ с публичным IP работает через него только если в её подсети нет статического маршрута 0.0.0.0/0. Если `route_table_id` была бы объявлена на обе подсети «для единообразия», то мастер потерял бы интернет вместе со всем кластером.
- resource "yandex_vpc_subnet" "private" -= приватная подсеть. Всё то же, что и у `public`, плюс: 
- `route_table_id = yandex_vpc_route_table.k8s.id` - привязка таблицы маршрутизации. С этого момента весь трафик воркеров, не предназначенный внутриподсетевым адресам, уходит согласно этой таблице. Ещё одна неявная зависимость в графе: таблица создаётся до подсети.
- resource "yandex_vpc_route_table" - та самая таблица.
- network_id = ...  таблица обязана принадлежать той же сети, что и маршрутизируемые подсети.
- static_route { ... } - вложенный блок маршрута.
- destination_prefix = "0.0.0.0/0" - маска назначения «любой адрес». Это default route: правило применяется к пакету, если ни один более конкретный маршрут не совпал. 
- next_hop_address = local.master_ip - «следующий транзитный узел»: пакеты с любым назначением отправляются на внутренний IP мастера. Дальше облако снимает с себя ответственность, а мастер (благодаря ip_forward=1 из cloud-init и MASQUERADE-правилу) транслирует их в свой публичный IP.
###### Итоговая схема - весь путь пакета из воркера в интернет:

```text
worker-1 (10.10.2.11) → default route (таблица) → master-1 (10.10.1.10)
  → MASQUERADE (исходящий IP = 51.250.x.x / 93.77.x.x) → интернет
```
И обратное следствие: отказ мастера - воркеры теряют интернет, но не локальную сеть (подсеть-то отдельно). 

#### instances.tf
```yaml
# instances.tf — виртуальные машины: 1 мастер и 4 воркера

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

locals {
  workers = {
    "worker-1" = "10.10.2.11"
    "worker-2" = "10.10.2.12"
    "worker-3" = "10.10.2.13"
    "worker-4" = "10.10.2.14"
  }

  node_map = merge({ "master-1" = local.master_ip }, local.workers)
}

# Мастер
resource "yandex_compute_instance" "master" {
  name        = "master-1"
  hostname    = "master-1"
  platform_id = "standard-v2"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = var.preemptible
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-hdd"
      size     = 20
    }
  }

  network_interface {
    subnet_id    = yandex_vpc_subnet.public.id
    ip_address = local.master_ip
    nat          = true             # ЕДИНСТВЕННЫЙ внешний IP кластера
  }

  metadata = {
    ssh-keys = "ubuntu:${trimspace(file(pathexpand(var.ssh_public_key_path)))}"

    user-data = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
      hostname  = "master-1"
      role      = "master"
      k8s_minor = var.k8s_minor
      node_map  = local.node_map
    })
  }

  labels = {
    role    = "master"
    project = "k8s-course"
  }
}

# Воркеры
resource "yandex_compute_instance" "worker" {
  for_each = local.workers

  name        = each.key
  hostname    = each.key
  platform_id = "standard-v2"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = var.preemptible
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-hdd"
      size     = 20
    }
  }

  network_interface {
    subnet_id    = yandex_vpc_subnet.private.id
    ip_address = each.value
    nat          = false            
  }

  metadata = {
    ssh-keys = "ubuntu:${trimspace(file(pathexpand(var.ssh_public_key_path)))}"
    user-data = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
      hostname  = each.key
      role      = "worker"
      k8s_minor = var.k8s_minor
      node_map  = local.node_map
    })
  }

  labels = {
    role    = "worker"
    project = "k8s-course"
  }

  depends_on = [yandex_compute_instance.master]
}

```
 
###### **`data "yandex_compute_image" "ubuntu"`**- блок _data source_: чтение существующего объекта вместо создания нового. Terraform при plan ходит в API Yandex и спрашивает: «дай ID последнего образа из семейства `ubuntu-2204-lts`». Семейство - это подвижный указатель: облако обновляет образы, мы всегда получаем свежий (безопасные патчи)

###### **`locals` - два значения.**
- `workers` - карта «имя ноды - её IP». Ключи словаря: при `for_each` они становятся частью адреса ресурса (`yandex_compute_instance.worker["worker-2"]`), поэтому карта даёт стабильную идентичность нод. В отличие от `count` (нумерация 0..3): при удалении из середины списка при `count`  Terraform пересоздаст половину нод, потому что индексы съехали; при `for_each` по карте - удалится ровно та нода, чей ключ исчез.
- `node_map = merge({ "master-1" = local.master_ip }, local.workers)`- функция `merge` склеивает два словаря в один: полная карта «все 5 нод - их IP». Она уезжает в cloud-init обеих ролей и превращается в пять строк hosts-файл  `/etc/hosts`идентичный на всех нодах.

###### **`resource "yandex_compute_instance" "master"` - мастер.**

- `name = "master-1"` - имя ВМ в API облака, `hostname` - имя ОС внутри гостя (что покажет `hostname` и что увидит kubeadm). Дублирую явно, чтобы не зависеть от поведения провайдера.
- `platform_id = "standard-v2"` - поколение железа (Intel Cascade Lake). Дешевле v3 (Ice Lake), для кластера без нагрузки - разницы нет. Выбор из ценовых соображений.
- `resources { cores = 2, memory = 4, core_fraction = 20 }` - CPU/RAM. `core_fraction = 20` - гарантированная доля vCPU: 20% означает, что два «ядра» дают в среднем 0.4 vCPU, но могут всплеском взять больше, когда гипервизор свободен. Прошли прекомпьют kubeadm, потому что он проверяет _количество_ ядер (≥2), а не долю. Мастеру - 4 ГБ: etcd + apiserver + controller-manager + scheduler проживают в этом объёме.
- `scheduling_policy { preemptible = var.preemptible }` - флаг прерываемости. 
- `boot_disk - initialize_params` - диск создаётся одновременно с ВМ: из образа (`image_id` из `data source` - ещё одна неявная зависимость), тип `network-hdd` (вдвое дешевле SSD - на бутстрапе медленнее, потом не важно, но только для учебного проекта), 20 ГБ.
- `network_interface` - сеть ВМ: подсеть public, **статический внутренний IP** `ip_address = local.master_ip` (10.10.1.10 - тот самый адрес, на который смотрит route table всей private-подсети; при его смене воркеры потеряют маршрут), и `nat = true` - единственный в кластере публичный IP. NAT тут - one-to-one: облако транслирует внутренний адрес в внешний на своей границе.
###### `metadata = { ... }` - словарь пар ключ-значение, доступных ВМ через сервис метаданных (агент внутри машины читает их по адресу 169.254.169.254 - этот API отдаёт и SSH-ключи, и cloud-config):
- `ssh-keys = "ubuntu:${...}"` - интерполяция: `pathexpand` разворачивает `~`, `file` читает файл, `trimspace` срезает хвостовой перенос строки. Префикс `ubuntu:` говорит провайдеру, какому пользователю образа дать ключ.
- `user-data = templatefile(...)` - бутстрап: функция читает `templates/cloud-init.yaml.tpl` и подставляет переменные. `${path.module}` - каталог, где лежит конфигурация: путь не сломается при переносе проекта. В словаре значений: `role = "master"` - в шаблоне включит блок NAT, `node_map`, `k8s_minor`, `hostname`. На каждую ВМ уезжает свой отрендеренный cloud-config - тот, что был в выводе `terraform plan`.
- `labels` - метки пары ключ-значение на ресурсах облака. Не влияют на работу, влияют на удобство: фильтрация в консоли, разнесение затрат по биллингу (`project = "k8s-course"`).


###### **`resource "yandex_compute_instance" "worker"` - четыре воркера одной декларацией.**
- `for_each = local.workers` - мета-аргумент, превращающий один блок в N ресурсов: по одному на ключ карты. В apply-логе это отображается как  `yandex_compute_instance.worker["worker-1"] ... ["worker-4"]`, создававшиеся параллельно.
- `each.key` / `each.value` - внутри `for_each` блоку доступны объект `each`: `.key` («worker-2») и `.value` («10.10.2.12»). Ссылки на текущую итерацию.
- Отличия от мастера, все осознанные: `memory = 2` (воркеру без нагрузки хватает минимума Kubernetes), подсеть `private`, `ip_address = each.value`, `nat = false` - наружу воркеры не торчат принципиально.
- `depends_on = [yandex_compute_instance.master]` - **явная** зависимость (в отличие от неявных через ссылки). Terraform создаст мастера раньше воркеров. Гарантируется порядок _создания ВМ_, но не готовность cloud-init мастера - воркеры начнут bootstrap, когда NAT на мастере ещё не поднят. Эту последовательность закрывает не Terraform, а цикл ожидания сети в cloud-init (`until curl ...`). 
#### outputs.tf
```yaml
output "master_public_ip" {
  value       = yandex_compute_instance.master.network_interface[0].nat_ip_address
  description = "Внешний IP мастера — единственная точка входа в кластер снаружи"
}

output "master_internal_ip" {
  value       = yandex_compute_instance.master.network_interface[0].ip_address
  description = "Внутренний IP мастера (NAT и control-plane endpoint)"
}

output "workers_internal_ips" {
  value = {
    for name, vm in yandex_compute_instance.worker :
    name => vm.network_interface[0].ip_address
  }
  description = "Внутренние адреса воркеров (private-подсеть)"
}

output "ssh_jump_example" {
  value = format(
    "ssh -J ubuntu@%s ubuntu@10.10.2.11",
    yandex_compute_instance.master.network_interface[0].nat_ip_address
  )
  description = "Пример подключения к worker-1 через мастер как jump host"
}

```

###### Terraform после apply знает об инфраструктуре всё, но молча: state лежит в файле, а пользователь видит только лог. `output` - это декларация «после apply покажи мне вот эти значения». Без него пришлось бы открывать `terraform.tfstate` руками или идти в консоль облака.  `terraform output` - все значения, `terraform output master_public_ip` - одно конкретное.

###### **`master_public_ip` - самый важный output.**
- `value = yandex_compute_instance.master.network_interface[0].nat_ip_address` . Разбор адреса атрибута: ресурс - его атрибут `network_interface` (это **список** блоков, у ВМ их может быть несколько), поэтому `[0]` - индексация первого интерфейса, а `.nat_ip_address` - уже атрибут этого интерфейса: внешний адрес, который облако выдало под NAT.
- Этот атрибут из категории `(known after apply)`. Значение не существует, пока ВМ не создана, Terraform показывает его отсутствие на этапе планирования и заполняет её фактом после применения.
- `description` - та же роль, что у переменных: документирование, описание.

###### **`master_internal_ip`** - то же самое, но атрибут `ip_address` (внутренний статический, `10.10.1.10`). Необходим для симметрии и удобства: потребитель выводов (скрипт, юзер) не должен знать, откуда значение взялось - из константы или из облака. Для мастера по факту всегда вернётся то же, что `local.master_ip` потому что адрес назначен статически.

###### **`workers_internal_ips` - выражение `for`.**
- Конструкция `{ for name, vm in yandex_compute_instance.worker : name => vm.network_interface[0].ip_address }`  это **for expression**, способ построить новую коллекцию из существующей на лету. Читается: «для каждой пары (name, vm) из ресурса-коллекции worker построить элемент словаря name - IP интерфейса».
- `yandex_compute_instance.worker` без индекса это вся карта из for_each: четыре ресурса разом. `name` - ключ итерации («worker-1»), `vm` - объект ресурса этой итерации.
- На выходе получается словарь: `{"worker-1" = "10.10.2.11", ...}`  в `terraform output`. Это способ «пробить» коллекцию ресурсов до нужного поля. Если добавить worker-5 в `locals.workers`, output сам начнёт содержать пять записей  код масштабируется без правок.

###### **`ssh_jump_example` - output-конструктор.**

- `format("ssh -J ubuntu@%s ubuntu@10.10.2.11", ...nat_ip_address)` - функция форматирования строк, куда подставляется публичный IP. Собирает готовую к копированию команду.
- Output возвращает строку, в которую уже встроено знание о jump-host-схеме с примером команды как зайти на конкретный воркер. 
- `10.10.2.11` захардкожен в строке, но правильнее чистый вариант - `local.workers["worker-1"]`.
  
**Чего здесь нет**

- **`sensitive = true`** - аргументы, помечаемые как секретные значения (пароли БД, ключи): в консольном выводе они маскируются звёздочками, но в state-файле лежат открыто.
- **`terraform output -json`** - машиночитаемый формат для скриптов и CI: `terraform output -json master_public_ip | jq -r .value` - готовый способ перенаправить адрес дальше по пайплайну.
- **Outputs как интерфейс между конфигурациями.** В больших проектах outputs одного модуля (например, network) становятся входами другого (например, cluster) - это аналог публичного API модуля. Текущий проект одномодульный, но паттерн тот же: outputs = то, что проект «отдаёт наружу».

#### cloud-init.yaml.tpl
```yaml
#cloud-config

hostname: ${hostname}
preserve_hostname: false
ssh_pwauth: false
package_update: false
package_upgrade: false

write_files:
  - path: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter

  - path: /etc/sysctl.d/k8s.conf
    content: |
      net.bridge.bridge-nf-call-iptables  = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward                 = 1

runcmd:
%{ for name, ip in node_map ~}
  - echo "${ip} ${name}" >> /etc/hosts
%{ endfor ~}
  - swapoff -a
  - sed -i '/ swap / s/^/#/' /etc/fstab
  - modprobe overlay
  - modprobe br_netfilter
  - sysctl --system
%{ if role == "master" ~}
  - iptables -t nat -A POSTROUTING -o eth0 ! -d 10.10.0.0/16 -j MASQUERADE
%{ endif ~}
  - sh -c 'for i in $(seq 1 60); do curl -fsS --max-time 5 -o /dev/null https://mirror.yandex.ru && exit 0; sleep 10; done; exit 1'
  - DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  - DEBIAN_FRONTEND=noninteractive apt-get install -y containerd apt-transport-https ca-certificates curl gpg
  - mkdir -p /etc/containerd
  - containerd config default > /etc/containerd/config.toml
  - sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  - systemctl enable --now containerd
  - systemctl restart containerd
%{ if role == "master" ~}
  - echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
  - DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
  - netfilter-persistent save
%{ endif ~}
  - mkdir -p -m 755 /etc/apt/keyrings
  - curl -fsSL https://pkgs.k8s.io/core:/stable:/${k8s_minor}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  - echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${k8s_minor}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
  - apt-get update
  - DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl
  - apt-mark hold kubelet kubeadm kubectl
```

#### Разбор файла:
Это одновременно YAML (для cloud-init) и Terraform-шаблон (для `templatefile`). Два вида подстановок из Terraform:
- `${hostname}` - **интерполяция**: значение подставляется в текст (`master-1`, `v1.37`);
- `%{ if ... }%` / `%{ for ... }%` - **директивы**: управляющая логика, которая вырезается из результата. `~` на конце (`%{ endif ~}`) - «обрезать пробелы вокруг», чтобы директивы не оставляли пустых строк в YAML.

На выходе для каждой из пяти ВМ получается свой чистый cloud-config: у мастера - с NAT-блоками, у воркеров - без. 

**`#cloud-config`** - первая строка маркер формата: без неё cloud-init не распознаёт документ как cloud-config и молча его игнорирует. 

##### **Верхний уровень - параметры cloud-init:**
- `hostname: ${hostname}` - имя машины, которое она получит при первой загрузке (клонируется из Terraform).
- `preserve_hostname: false` - cloud-init разрешено управлять hostname и при последующих загрузках.
- `ssh_pwauth: false` - SSH только по ключу, парольная аутентификация отключена.
- `package_update: false`, `package_upgrade: false` - запрет скачивания и обновления пакетов.
##### write_files - постоянная конфигурация ОС:

Файлы пишутся на ранней стадии (config stage), до выполнения runcmd. Паттерн «файл конфигурации» вместо «команда настройки» выбран потому, что файлы _переживают перезагрузку_, а команды `modprobe`/`sysctl` дают только немедленный эффект. Поэтому каждое изменение ядра в файле в двух местах: файл (постоянство) + команда в runcmd (применить сейчас, не дожидаясь ребута).

- `/etc/modules-load.d/k8s.conf` - каталог modules-load.d читает systemd при старте: перечисленные модули загружаются автоматически при каждой загрузке. `overlay` - файловая система оверлеев, на которой containerd собирает слои образов. `br_netfilter` - включает учёт трафика с сетевых мостов в netfilter; без него iptables «слеп» к трафику подов (pod-ы живут на мостах CNI).
- `/etc/sysctl.d/k8s.conf` - каталог sysctl.d читается утилитой sysctl при загрузке. `bridge-nf-call-iptables/ip6tables = 1` - продолжение br_netfilter: bridge-трафик прогоняется через цепочки iptables (иначе CNI не сможет строить политики). `ip_forward = 1` - ядро разрешено маршрутизировать пакеты между интерфейсами; нужно и pod-сети, и мастеру в роли NAT-шлюза.
##### runcmd - исполнение:

Команды выполняются по порядку на финальной стадии (final stage). Почему apt-операции именно здесь, а не в `package_upgrade`: стадии cloud-init идут в порядке init -> config -> final. Стандартный `package_upgrade` выполняется на config-стадии - **до** runcmd, а значит, до того, как мастер поднимет NAT. Воркеры стартовали бы качать пакеты в сеть, которой ещё нет. `false` в шапке и ручное управление порядком в runcmd позволяет запустить скачивание и обновление в нужный момент.

- **Цикл `%{ for name, ip in node_map ~}`** - разворачивается в пять команд `echo`. Каждая дописывает строку `IP имя` в `/etc/hosts` - статическое разрешение имён всех нод на каждой ноде. Смысл: kubeadm, kubelet и хостовая машина по SSH используют имена (`master-1`, `worker-1`) без DNS.
- `swapoff -a` - отключить swap немедленно.
- `sed -i '/ swap / s/^/#/' /etc/fstab` - закомментировать строку swap в fstab, чтобы он не вернулся после перезагрузки. Двойное действие = «сейчас и навсегда». Причина: kubelet проектируется в расчёте на предсказуемое управление памятью; со swap ломаются метрики и eviction.
- `modprobe overlay`, `modprobe br_netfilter` - загрузить модули сейчас (файлы из write_files дадут постоянство).
- `sysctl --system` - применить все файлы sysctl.d немедленно.
- **Блок `%{ if role == "master" ~}`** - условная директива: содержимое попадает только в cloud-config мастера. Это  механизм «один шаблон - две роли».
- `iptables -t nat -A POSTROUTING -o eth0 ! -d 10.10.0.0/16 -j MASQUERADE` - NAT-правило мастера: `-t nat` - таблица NAT (трансляция адресов). `-A POSTROUTING` - дописать правило в цепочку post-routing: обрабатываются пакеты, уже прошедшие решение о маршруте. `-o eth0` - **только пакеты, уходящие через eth0**: без этого флага правило ловило и loopback-трафик к DNS-stub'у systemd-resolved (127.0.0.53), ломая DNS на мастере. `! -d 10.10.0.0/16` - исключение: пакеты, предназначенные внутрь нашей VPC, не транслировать. `-j MASQUERADE` - действие: подменять адрес источника на адрес исходящего интерфейса. Итог: транзит воркеров в интернет выходит «под адресом» мастера.
- **Ожидание сети**: `sh -c 'for i in $(seq 1 60); do curl -fsS --max-time 5 -o /dev/null https://mirror.yandex.ru && exit 0; sleep 10; done; exit 1'` - фикс, тоже после аварии. `seq 1 60` - 60 попыток; `curl -fsS --max-time 5` - тихий HTTP-запрос с жёстким таймаутом 5 секунд (без вечных зависаний); `&& exit 0` - сеть появилась, продолжаем runcmd; `sleep 10` - пауза между попытками; `exit 1` после исчерпания - cloud-init завершится с `status: error`, видимым и диагностируемым. Предыдущая версия `until apt-get update` ложно проходила: apt-get update возвращает код 0 даже при полностью упавших репозиториях. 
- `apt-get upgrade -y` - обновление ОС до актуального состояния.
- `apt-get install -y containerd ...` - CRI кластера + вспомогательные пакеты.
- `containerd config default > /etc/containerd/config.toml` - сгенерировать эталонный конфиг. Надёжнее ручного: всегда полон и актуален версии.
- `sed -i 's/SystemdCgroup = false/SystemdCgroup = true/'` - **критический патч**: контейнерный рантайм и kubelet должны использовать один cgroup-драйвер. Дефолт containerd - `cgroupfs`, kubelet - `systemd`. Рассинхрон = kubelet не управляет контейнерами. Одна из самых частых ошибок при ручной установке k8s.
- `systemctl enable --now containerd` + `restart` - включить в автозагрузку (`enable`), запустить немедленно (`--now`), затем перезапустить для гарантированного применения конфига.
- **Второй master-блок - персистенция NAT**: `debconf-set-selections` заранее отвечает «да» на вопрос установщика iptables-persistent (cloud-init неинтерактивен, интерактивный вопрос его подвесил бы); установка пакета; `netfilter-persistent save` - сброс текущих правил в `/etc/iptables/rules.v4`. Без этого после перезагрузки (в т.ч. принудительной) мастер терял бы NAT и воркеры оставались без интернета.
- **Репозиторий Kubernetes**: `mkdir -p -m 755 /etc/apt/keyrings` - каталог для ключей по современной конвенции (права 755 - apt требует, чтобы каталог был читаем). `curl ... Release.key | gpg --dearmor` - скачать GPG-ключ репозитория и перевести из текстового ASCII-формата в бинарный. Строка `deb [signed-by=...] .../${k8s_minor}/...` - подключить репозиторий, привязав его к конкретному ключу; `${k8s_minor}` подставляет ветку (v1.37) - фиксация канала гарантирует одинаковые версии на всех нодах. Ключ и строка - всегда пара: репозиторий без ключа = «The repository is not signed».
- `apt-get update` - подтянуть индексы нового репозитория.
- `apt-get install -y kubelet kubeadm kubectl` - три бинарника кластера: kubelet (агент ноды), kubeadm (сборщик кластера), kubectl (CLI к API).
- `apt-mark hold kubelet kubeadm kubectl` - запретить обновление этих пакетов: unattended-upgrades не должен молча обновлять компоненты Kubernetes, ломая согласованность версий. Версии кластера меняются только осознанно, через `kubeadm upgrade`.

### Для проверки корректности созданных элементов использую скрипт `validate-cloud-init.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ ! -f tfplan ]; then
  echo "tfplan не найден. Сначала: export YC_TOKEN=\$(yc iam create-token) && terraform plan -out=tfplan"
  exit 1
fi

rm -f rendered-*.yaml

terraform show -json tfplan > /tmp/tfplan.json

python3 - <<'PYEOF'
import json, sys, yaml

plan = json.load(open('/tmp/tfplan.json'))
resources = plan['planned_values']['root_module']['resources']

rendered = []
for res in resources:
    if res['type'] != 'yandex_compute_instance':
        continue
    hostname = res['values']['hostname']
    user_data = res['values']['metadata']['user-data']
    fn = f'rendered-{hostname}.yaml'
    with open(fn, 'w') as fh:
        fh.write(user_data)
    rendered.append(fn)
    print(f'Рендер из плана: {fn}')

if not rendered:
    sys.exit('В плане не найдено yandex_compute_instance — tfplan устарел или пуст')

for fn in rendered:
    first = open(fn).readline().rstrip('\n')
    assert first == '#cloud-config', f'{fn}: первая строка {first!r}, ожидалась #cloud-config'
    data = yaml.safe_load(open(fn))
    assert isinstance(data, dict), f'{fn}: YAML-документ не является словарём — рендер сломан'
    print(f'YAML OK (маппинг, ключи: {", ".join(sorted(data))}): {fn}')

print(f'Всего отрендерено нод: {len(rendered)}')
PYEOF

for f in rendered-*.yaml; do
  sudo cloud-init schema -c "$f" --annotate
done

echo "ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ"
```

##### Разбор скрипта:
**`set -euo pipefail`** - три флага, стандарт де-факто для безопасных скриптов:
- `-e` - немедленный выход при любом ненулевом коде возврата команды. Без него скрипт продолжил бы работу после падения посередине.
- `-u` - ошибка при обращении к несуществующей переменной. Ловит опечатки в именах на ранней стадии.
- `-o pipefail` - конвейер `a | b | c` возвращает код самой _упавшей_ команды, а не последней. Без него `terraform show | python3` мог бы «пройти успешно», даже если terraform упал, а python получил пустоту.
  
`if [ ! -f tfplan ]` - проверка предусловия: если плана нет, скрипт не имеет смысла. Паттерн сообщением, что делать,  вместо того чтобы упасть с загадочной ошибкой. Внутри echo экранированные `\$(...)`  чтобы при выводе текста команда не выполнилась, а показалась как подсказка.
**`rm -f rendered-*.yaml`** - очистка артефактов прошлого прогона. Паттерн идемпотентности: повторный запуск скрипта должен давать одинаковый результат, а не накапливать хвосты (например, если ноду переименовали - старый rendered-файл остался бы висеть и вводить в заблуждение).
**`terraform show -json tfplan > /tmp/tfplan.json`** - ключевой переход. `terraform show -json` разворачивает сохранённый план в машиночитаемый JSON. Смысл всей архитектуры скрипта: **источник истины - план**, то есть ровно то, что будет применено при `terraform apply`. Это третья версия подхода, и она родилась из двух неудач: рендер через `terraform console` дважды ломался на экранировании вывода (jsonencode-двойное кодирование, потом пустой вывод конвейера). Файл кладём в `/tmp`, чтобы не мусорить в репозитории (gitignore не нужен для того, чего нет в рабочем каталоге).
**`python3 - <<'PYEOF' ... PYEOF`** - heredoc: скрипт на Python встроен в bash-скрипт. Кавычки в `<<'PYEOF'` критичны: они запрещают bash делать подстановки внутри текста. Python получает код как есть, а не с развёрнутыми `$`-переменными.

###### **Python-часть, по строкам:**

- `plan['planned_values']['root_module']['resources']` - навигация по JSON-структуре плана: `planned_values` - будущее состояние, `root_module` - единственный модуль, `resources` - список ресурсов, которые apply создаст.
- `if res['type'] != 'yandex_compute_instance': continue` - фильтр: из плана интересны только ВМ (в плане есть и сеть, и подсети - их пропускаем).
- `res['values']['hostname']` и `['metadata']['user-data']` - вытаскиваем из запланированных значений ВМ её имя и отрендеренный cloud-config. Это **не повторный рендер шаблона**, это user-data, который Terraform положил в план при его создании. Скрипт не может разойтись с реальностью по определению.
- `with open(fn, 'w') as fh: fh.write(user_data)` - запись слепка `rendered-<имя-ноды>.yaml`. Артефакт создаётся только ради проверок и для просмотра глазами.
- `if not rendered: sys.exit(...)` - план есть, ВМ в нём нет (устаревший tfplan от прошлого конфига) - внятная ошибка, а не «проверок ноль, всё хорошо», пустой результат проверки не тоже самое, что и успешная проверка.
###### **Блок проверок:**

- `assert first == '#cloud-config'` - первая строка файла cloud-config обязана быть маркером формата. В предыдущих итерациях сломанный рендер однажды превратил файл в однострочную строку, и cloud-init его молча отверг. Теперь это проверяется явно до валидации.
- `data = yaml.safe_load(...)` + `assert isinstance(data, dict)` - парсим YAML и **проверяем тип результата**. 
- `", ".join(sorted(data))` - печать списка ключей: что внутри `hostname`, `runcmd`, `write_files` и остальные.

**`sudo cloud-init schema -c "$f" --annotate`** - валидатор самого cloud-init сверяет документ со своей JSON-схемой (имена модулей, типы аргументов). `sudo` нужен, потому что cloud-init при старте читает свои системные конфиги из `/etc/cloud`, недоступные обычному пользователю. `--annotate` в случае ошибки покажет проблемные строки прямо в файле.

**`echo "ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ"`** - финальная строка: если скрипт добрался до неё, значит, ни один `set -e` не сработал и все проверки успешные.

**Общая архитектура скрипта** - три уровня проверок, каждый ловит своё: синтаксис YAML (Python), формат cloud-config (первая строка + схема), соответствие плану (сам источник данных). 
### Проверка файлов через 
```bash
./validate-cloud-init.sh # скрипт создал 5 файлов-рендеров готовых cloud-config каждой ноды
terraform validate
yc iam create-token
export YC_TOKEN=$(yc iam create-token)
terraform plan -out=tfplan
terraform apply 
```

![](<Pasted image 20260919163709.png>)

![](<Pasted image 20260919165851.png>)

![](<Pasted image 20260917212128.png>)

![](<Pasted image 20260917211948.png>)

### Проверяю что получилось

```bash
ssh ubuntu@51.250.89.107
cloud-init status --wait #по окончании процесса: status: done
kubeadm version                    # v1.37.x
kubectl version --client
systemctl status containerd --no-pager
sudo iptables -t nat -L POSTROUTING -n | grep MASQUERADE   # правило NAT живо
cat /etc/hosts                     # все 5 нод
free -h | grep -i swap             # пусто — swap отключён

# Воркер — через мастер как jump host
for i in 11 12 13 14; do
     echo "===worker с IP 10.10.2.$i=== "
     ssh -J ubuntu@51.250.89.107 ubuntu@10.10.2.$i "cloud-init status; kubeadm version -o short; free -h | grep -i Swap || echo 'swap: off'"
   done
```

![](<Pasted image 20260918133454.png>)

![](<Pasted image 20260918133616.png>)

![](<Pasted image 20260918133639.png>)

Инфраструктурная часть закрыта. Мастер настроен как задумано, получил единственный внешний ip адрес, DNS живой, kubeadm v1.37.0, containerd и NAT-правило работает. Все четыре воркера поднялись, kubeadm  с v1.37.0, NAT подтверждён - воркеры выходят в интернет под адресом мастера.

### Настройка kubernetes на мастер ноде и воркерах
#### выбор CNI-плагина

|               | Flannel                                | Calico                         | Cilium                 |
| ------------- | -------------------------------------- | ------------------------------ | ---------------------- |
| Модель        | VXLAN-оверлей                          | BGP/VXLAN, iptables или eBPF   | eBPF                   |
| NetworkPolicy | нет - критично для продакшена tasrieit | полная                         | полная + L7            |
| Сложность     | минимальная                            | средняя                        | высокая                |
| Для кого      | хоумлаб, простые связки                | продакшен у большинства команд | масштаб, observability |
Calico - стандарт отрасли. 

#### pod-network CIDR
--pod-network-cidr это адресное пространство, из которого подам выдаются IP. Оно должно совпадать с CIDR в манифесте CNI и не должно пересекаться с существующими сетями. 
- ноды: 10.10.1.0/24 (public) и 10.10.2.0/24 (private);
- service CIDR (дефолт kubeadm): 10.96.0.0/12;
- pod CIDR Calico по умолчанию: 192.168.0.0/16 - ни с чем не пересекается.

Для Flannel, CIDR был бы 10.244.0.0/16.

#### инициализация (на мастере)
```bash
sudo kubeadm init \
  --apiserver-advertise-address 10.10.1.10 \
  --pod-network-cidr 192.168.0.0/16
  
mkdir -p $HOME/.kube
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes # мастер NotReady, CNI ещё не стоит
  
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/calico.yaml

kubectl get pods -n kube-system -w
kubectl get nodes     # мастер должен стать Ready
```

![](<Pasted image 20260918135710.png>)

- Static pods control plane: kube-apiserver, controller-manager, scheduler, etcd - kubelet поднял их напрямую из манифестов в /etc/kubernetes/manifests, минуя API-сервер. 
- `Taint node-role.kubernetes.io/control-plane:NoSchedule` : на мастере,  обычные поды на него не планируются. В продакшене так и должно быть; в учебном кластере при желании снимается.
- CoreDNS + kube-proxy - штатные аддоны.
- Calico: calico-node (DaemonSet - по одному на ноду, на воркерах будет автоматически после join) + calico-kube-controllers.

#### Подключаю воркеры (с хостовой машины, с sudo)
```bash
for i in 11 12 13 14; do
  echo "=== join worker 10.10.2.$i ==="
  ssh -J ubuntu@93.77.187.156 ubuntu@10.10.2.$i \
    "sudo kubeadm join 10.10.1.10:6443 --token 8tx6wx.jtfskqvqg01cnez0 \
     --discovery-token-ca-cert-hash sha256:a19adb15d29c75cbf552fd6a961400fc6cbe2c4e3428c62424620a3896c257f7"
done
```

(токен выдан кубером после команды 
sudo kubeadm init \
  --apiserver-advertise-address 10.10.1.10 \
  --pod-network-cidr 192.168.0.0/16)

![](<Pasted image 20260918140656.png>)

![](<Pasted image 20260918140747.png>)

preflight - воркер через токен находит API-сервер - сверяет CA-хеш из discovery (защита от подключения к чужому кластеру) - TLS bootstrap: kubelet отправляет CSR, csrapprover её подписывает - нода получает сертификаты и регистрируется в кластере.
#### проверяю 
```bash
kubectl get nodes -w
kubectl get pods -n kube-system
```

![](<Pasted image 20260918141004.png>)

![](<Pasted image 20260918141058.png>)

Кластер из пяти нод полностью собран, calico-node и kube-proxy стоят на всех пяти нодах (пять DaemonSet-подов каждого), control plane в порядке.
#### проверка
```bash
kubectl create deployment web --image=nginx --replicas=4
kubectl get pods -o wide
```

![](<Pasted image 20260918141730.png>)

поды размещены на worker с 1 по 4 (на мастер не попали - taint control-plane). В колонке NODE - распределение, в IP - адреса из pod-CIDR 192.168.0.0/16, по /24 на ноду от Calico IPAM.

```bash
kubectl expose deployment web --port=80
kubectl run test --rm -it --image=busybox --restart=Never -- \
  sh -c "nslookup web.default.svc.cluster.local && wget -qO- web | head -5"
```

![](<Pasted image 20260918142040.png>)

проверил CoreDNS (резолвинг имени сервиса) и cluster-сеть (запрос до пода на любой ноде). wget вернул HTML-заголовок страницы nginx.

```bash
kubectl expose deployment web --port=80 --type=NodePort --name=web-np
kubectl get svc web-np

curl -I http://93.77.187.156:30129 # номер порта из вывода команды выше, с хостовой машины
```

![](<Pasted image 20260918142712.png>)

Запрос прошел путь: хостовая машина - публичный IP мастера - kube-proxy/NodePort - под nginx на одном из воркеров в private-подсети - и обратно. Nginx ответил "200 OK" из-за границы NAT-схемы: следовательно  вся архитектура работает корректно.

## Разбор задачи 2*
#### Ключевые решения и обоснование с учетом выполненного Задания 1:

| Решение                                                                 | Комментарий                                                                                                                                                                                                                                                                     |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Все 3 мастера в публичной подсети                                       | VRRP (Virtual Router Redundancy Protocol) работает в пределах одного L2-сегмента. Каждый мастер получает свой публичный IP для SSH доступа (в проде я оставил бы один jump-host)                                                                                                |
| VIP (virtual IP) 10.10.1.100, /32 на eth0                               | Вне диапазона статических IP нод; keepalived поднимает его как вторичный адрес и анонсирует gratuitous ARP                                                                                                                                                                      |
| keepalived в режиме **unicast**                                         | В облачных сетях (включая Yandex Cloud) multicast между ВМ недоступен, поэтому VRRP-пакеты отправляются напрямую одноранговым узлам через `unicast_src_ip` / `unicast_peer`                                                                                                     |
| Проверка `chk_apiserver` -`weight -40`                                  | VIP уходит с мастера, на котором умер kube-apiserver, даже если у него максимальный priority.  `weight` нужен, чтобы до `kubeadm init` (apiserver ещё не поднят нигде) VIP оставался на master-1, иначе `kubeadm init` повиснет на недоступном controlPlaneEndpoint             |
| Route table private-подсети - next hop = VIP                            | шлюзом NAT для воркеров становится тот мастер, который держит VIP. Все мастера получают одинаковое MASQUERADE-правило, NAT переезжает вместе с VIP                                                                                                                              |
| `kubeadm init --control-plane-endpoint 10.10.1.100:6443 --upload-certs` | Официальный путь kubeadm: сертификаты apiserver выпускаются на VIP, а `--upload-certs` складывает их в Secret, чтобы остальные мастера забрали их при join через `--certificate-key`. Ключ сертификатов живёт ~2 часа, потом перегенерируется `kubeadm init phase upload-certs` |
P.S.: схема не сработала. После долгих мучений и отладки выяснено, что в отличие от первой части задания, где проброс от воркеров шел на реальный ip адрес мастера, в текущем виде схема с keepalived-VIP (виртуальный ip) оказалась в инфраструктуре Яндекса нежизнеспособной: траффик на незарегистрированные адреса не доставляется. Поэтому далее файлы с корректировками следующего формата:
- в файл `network.tf` добавлен NAT-gateway, изменен route table
- `cloud-init.yaml.tpl` - удален блок keepalived, MASQUERADE, iptables-persistent
- Terraform - добавлен внутренний NLB (network load balancer) с обвязкой
- в kubespray group_vars добавлен `loadbalancer_apiserver.address` - внутренний IP NLB
#### Переиспользую файлы Terraform из предыдущего задания. Для этого внесу изменения (с учетом правок по вышеуказанным причинам, здесь и далее по тексту отчета):
3 мастера, NAT-gateway (`shared_egress_gateway`) и route table приватной подсети теперь ведёт `0.0.0.0/0` на `gateway_id`

##### Записал файл `network.tf` следующим содержанием
```yaml
resource "yandex_vpc_network" "k8s" {
  name = "k8s-course-net"
}

resource "yandex_vpc_subnet" "public" {
  name           = "k8s-public-a"
  network_id     = yandex_vpc_network.k8s.id
  zone           = var.zone
  v4_cidr_blocks = var.public_subnet_cidr
}

resource "yandex_vpc_subnet" "private" {
  name           = "k8s-private-a"
  network_id     = yandex_vpc_network.k8s.id
  zone           = var.zone
  v4_cidr_blocks = var.private_subnet_cidr
  route_table_id = yandex_vpc_route_table.k8s.id
}

# NAT-шлюз: исходящий интернет приватной подсети воркеров. Живёт в платформе и не зависит от состояния master-нод.

resource "yandex_vpc_gateway" "nat" {
  name = "k8s-nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "k8s" {
  name       = "k8s-private-via-natgw"
  network_id = yandex_vpc_network.k8s.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}
```

##### добавлен файл `loadbalancer.tf`

```yaml
# Внутренний NLB — "cluster IP" (controlPlaneEndpoint) для API-сервера, адрес NLB выдаётся платформой.

locals {
  api_lb_ip = "10.10.1.50"
}

resource "yandex_lb_target_group" "masters" {
  name = "k8s-api-tg"

  dynamic "target" {
    for_each = local.masters
    content {
      subnet_id = yandex_vpc_subnet.public.id
      address   = target.value
    }
  }
}

resource "yandex_lb_network_load_balancer" "api" {
  name = "k8s-api-lb"
  type = "internal"

  listener {
    name        = "k8s-api"
    port        = 6443
    target_port = 6443
    internal_address_spec {
      subnet_id = yandex_vpc_subnet.public.id
      address   = local.api_lb_ip
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.masters.id

    healthcheck {
      name = "tcp-6443"
      tcp_options {
        port = 6443
      }
    }
  }
}
```

**`loadbalancer.tf`** - target group из трёх мастеров, внутренний NLB с фиксированным адресом `10.10.1.50` и healthcheck по TCP/6443. Синтаксис внутреннего listener'а сверен с официальными примерами Yandex. https://yandex.cloud/ru/docs/network-load-balancer/operations/internal-lb-create, https://github.com/yandex-cloud-examples/yc-s3-private-endpoint/blob/main/load-balancer.tf
##### файл `instances.tf`
```yaml
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

locals {
  masters = {
    master-1 = "10.10.1.10"
    master-2 = "10.10.1.11"
    master-3 = "10.10.1.12"
  }
  workers = {
    worker-1 = "10.10.2.11"
    worker-2 = "10.10.2.12"
    worker-3 = "10.10.2.13"
    worker-4 = "10.10.2.14"
  }
  nodemap = merge(local.masters, local.workers)
}

resource "yandex_compute_instance" "master" {
  for_each    = local.masters
  name        = each.key
  hostname    = each.key
  platform_id = "standard-v2"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = var.preemptible
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-hdd"
      size     = 20
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.public.id
    ip_address = each.value
    nat        = true
  }

  metadata = {
    ssh-keys = "ubuntu:${trimspace(file(pathexpand(var.ssh_public_key_path)))}"
    user-data = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
      hostname = each.key
      role      = "master"
      nodemap   = local.nodemap
    })
  }

  labels = {
    role    = "master"
    project = "k8s-course"
  }
}

resource "yandex_compute_instance" "worker" {
  for_each    = local.workers
  name        = each.key
  hostname    = each.key
  platform_id = "standard-v2"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = var.preemptible
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-hdd"
      size     = 20
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.private.id
    ip_address = each.value
    nat        = false
  }

  metadata = {
    ssh-keys = "ubuntu:${trimspace(file(pathexpand(var.ssh_public_key_path)))}"
    user-data = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
      hostname = each.key
      role      = "worker"
      nodemap   = local.nodemap
    })
  }

  labels = {
    role    = "worker"
    project = "k8s-course"
  }

  depends_on = [yandex_compute_instance.master]
}
```
мастер превращается в `for_each`-ресурс, 4 ГБ, nat=true, воркеры как раньше, но в templatefile ушли все keepalived-переменные

##### файл `templates/cloud-init.yaml.tpl`
```yaml
#cloud-config

hostname: ${hostname}
preserve_hostname: false
ssh_pwauth: false
package_update: false
package_upgrade: false

write_files:
  - path: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter

  - path: /etc/sysctl.d/k8s.conf
    content: |
      net.bridge.bridge-nf-call-iptables  = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward                 = 1

runcmd:
%{ for name, ip in nodemap ~}
  - echo "${ip} ${name}" >> /etc/hosts
%{ endfor ~}
  - swapoff -a
  - sed -i '/ swap / s/^/#/' /etc/fstab
  - modprobe overlay
  - modprobe br_netfilter
  - sysctl --system
  - sh -c 'for i in $(seq 1 60); do curl -fsS --max-time 5 -o /dev/null https://mirror.yandex.ru && exit 0; sleep 10; done; exit 1'
  - apt-get update
```

осталось после правки: hostname, /etc/hosts, swap-off, модули и sysctl (kubespray их тоже выставит, но преднастройка ускоряет bootstrap), wait-loop и `apt-get update`. Никакой роли master/worker в сетевой части, ноды теперь симметричны, вся сетевая связанность переехала в платформу.
##### файл `outputs.tf`
```yaml

output "masters_public_ips" {
 value = {
   for name, vm in yandex_compute_instance.master :
   name => vm.network_interface[0].nat_ip_address
 }
 description = "Публичные IP master-нод"
}

output "api_lb_ip" {
 value       = local.api_lb_ip
 description = "Внутренний IP NLB (loadbalancer_apiserver в kubespray)"
}

output "workers_internal_ips" {
 value = {
   for name, vm in yandex_compute_instance.worker :
   name => vm.network_interface[0].ip_address
 }
 description = "Внутренние IP worker-нод"
}

output "ssh_jump_example" {
 value = format(
   "ssh -J ubuntu@%s ubuntu@10.10.2.11",
   yandex_compute_instance.master["master-1"].network_interface[0].nat_ip_address
 )
 description = "Доступ к worker-1 через master-1 как jump host"
}
```    

`api_lb_ip` вместо `vip`
##### файл `variables.tf`

```yaml
variable "cloud_id" {
  type        = string
  description = "ID облака Yandex Cloud"
}

variable "folder_id" {
  type        = string
  description = "ID каталога"
}

variable "zone" {
  type        = string
  default     = "ru-central1-a"
  description = "Зона доступности"
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
  description = "Путь к публичному SSH-ключу"
}

variable "preemptible" {
  type        = bool
  default     = true
  description = "Прерываемые ВМ"
}

variable "public_subnet_cidr" {
  type        = list(string)
  default     = ["10.10.1.0/24"]
  description = "CIDR публичной подсети (master-ноды, общий L2 для VRRP)"
}

variable "private_subnet_cidr" {
  type        = list(string)
  default     = ["10.10.2.0/24"]
  description = "CIDR приватной подсети (worker-ноды)"
}
```

- **`variables.tf`** - удалена переменная `k8s_minor`. Версия Kubernetes теперь задаётся не в Terraform, а в инвентаре kubespray (`kube_version` в group_vars).
- **`cloud-init.yaml.tpl`** - убрано всё, чем kubespray теперь управляет сам: установка containerd, apt-репозиторий pkgs.k8s.io, kubelet/kubeadm/kubectl и `apt-mark hold`. containerd ставится kubespray-ролью как дефолтный `container_manager`, и предустановленный kubelet из cloud-init только создал бы конфликт версий. 
- **`instances.tf`** - 3 мастера через `for_each`, каждому `nat = true` (итог: 3 публичных IP + 4 внутренних).
- **`outputs.tf`** - публичные IP всех мастеров, пример jump-подключения.
- `providers.tf`, `variables.tf`, `terraform.tfvars` (кроме того, что из него удалена запись о переменной k8s_minor) и `validate-cloud-init.sh` остаются без изменений
##### Проверки перед apply 
```bash
cd kubernetes_HA
terraform init
terraform fmt -recursive
terraform validate
export YC_TOKEN=$(yc iam create-token)
terraform plan -out=tfplan 
./validate-cloud-init.sh        # отрендерит 7 cloud-config'ов и проверит их схему
```

![](<Pasted image 20260920125501.png>)

![](<Pasted image 20260920125540.png>)

![](<Pasted image 20260920125616.png>)

##### Применяем все
```bash
terraform apply tfplan
```

![](<Pasted image 20260919190620.png>)

![](<Pasted image 20260920130232.png>)

![](<Pasted image 20260920130337.png>)

![](<Pasted image 20260920130416.png>)

![](<Pasted image 20260920130537.png>)

![](<Pasted image 20260920130623.png>)


#### Проверки после подъема всех нод. С мастеров:
```bash
cloud-init status --wait
free -h | grep -i swap
cat /etc/hosts
ip -4 addr show eth0
ping ya.ru
nc -zv -w3 10.10.1.11 22
nc -zv -w3 10.10.1.12 22
nc -zv -w3 10.10.1.13 22 # доступность мастеров с других мастеров
nc -zv -w3 10.10.1.50 6443 # с воркера доступность балансера
```

##### вычистил артефакты из `~/.ssh/known_hosts`
```bash
for ip in 10.10.1.10 10.10.1.11 10.10.1.12 10.10.2.11 10.10.2.12 10.10.2.13 10.10.2.14; do 
  ssh-keygen -f ~/.ssh/known_hosts -R "$ip" 
done
```

#### Установка kubespray
##### Установка файлов из офф репозитория kubespray

```bash
cd ~/microkuber
git submodule add https://github.com/kubernetes-sigs/kubespray.git deploy/kubespray
cd deploy/kubespray
git tag -l 'v2.*' --sort=-v:refname | head -5
git checkout v2.31.0 
```

##### Окружение и зависимости (venv)

```bash
cd ~/microkuber/deploy/kubespray
python3 -m venv ~/.venvs/kubespray
source ~/.venvs/kubespray/bin/activate
pip install -r requirements.txt
```

![](<Pasted image 20260919221951.png>)

##### Инвентарь и group_vars
###### файл `~/microkuber/kubernetes_HA/inventory/ha-cluster/hosts.yaml`

```yaml
all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_common_args: >-
      -o ProxyJump=ubuntu@111.88.242.202
      -o StrictHostKeyChecking=accept-new
  hosts:
    master-1:
      ansible_host: 10.10.1.10
    master-2:
      ansible_host: 10.10.1.11
    master-3:
      ansible_host: 10.10.1.12
    worker-1:
      ansible_host: 10.10.2.11
    worker-2:
      ansible_host: 10.10.2.12
    worker-3:
      ansible_host: 10.10.2.13
    worker-4:
      ansible_host: 10.10.2.14
  children:
    kube_control_plane:
      hosts:
        master-1:
        master-2:
        master-3:
    kube_node:
      hosts:
        worker-1:
        worker-2:
        worker-3:
        worker-4:
    etcd:
      hosts:
        master-1:
        master-2:
        master-3:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
```

###### файл `kubernetes_HA/inventory/ha-cluster/group_vars/k8s-cluster/k8s-cluster.yml`

```yaml
---
# kube_version: v1.35.4

loadbalancer_apiserver_localhost: false
loadbalancer_apiserver:
  address: 10.10.1.50
  port: 6443

container_manager: containerd  
kube_network_plugin: calico     


kube_service_addresses: 10.96.0.0/12
kube_pods_subnet: 192.168.0.0/16
kube_network_node_prefix: 24
kube_proxy_mode: iptables
```

##### Запуск установки

``` bash
cd ~/microkuber/deploy/kubespray 
source ~/.venvs/kubespray/bin/activate 
ansible -i ../../kubernetes_HA/inventory/ha-cluster/hosts.yaml -m ping all # все 7 нод pong
ansible-playbook -i ../../kubernetes_HA/inventory/ha-cluster/hosts.yaml cluster.yml -b -v 2>&1 | tee ~/cluster-install.log
```

- `-b` - become= sudo (облачный пользователь ubuntu имеет NOPASSWD sudo, поэтому пароль не спросит).
- `-v` - детальный вывод по таскам для чтения лога.
- `tee` - сохраняю лог в файл, чтобы разбирать по шагам.

##### путем многочисленных и продолжительных проверок установлены сетевые неполадки, для устравнения которых необходимо применение следующих правил, оформленных в отдельную ansible роль (в совокупности с переводом кластера в kube_proxy_mode: iptables):
```yaml
---
- name: Route Kubernetes API ClusterIP locally on control-plane nodes
  hosts: kube_control_plane
  become: true
  gather_facts: false

  tasks:
    - name: Redirect Kubernetes Service ClusterIP from local processes to local API server
      ansible.builtin.iptables:
        table: nat
        chain: OUTPUT
        protocol: tcp
        destination: 10.96.0.1
        destination_port: "443"
        jump: REDIRECT
        to_ports: "6443"
        action: insert
        rule_num: 1

    - name: Redirect Kubernetes Service ClusterIP from incoming host-network traffic to local API server
      ansible.builtin.iptables:
        table: nat
        chain: PREROUTING
        protocol: tcp
        destination: 10.96.0.1
        destination_port: "443"
        jump: REDIRECT
        to_ports: "6443"
        action: insert
        rule_num: 1

    - name: Redirect NLB API endpoint to local API server on control-plane nodes
      ansible.builtin.iptables:
        table: nat
        chain: OUTPUT
        protocol: tcp
        destination: 10.10.1.50
        destination_port: "6443"
        jump: REDIRECT
        to_ports: "6443"
        action: insert
        rule_num: 1


- name: Route Kubernetes API ClusterIP through internal NLB on worker nodes
  hosts: kube_node
  become: true
  gather_facts: false

  tasks:
    - name: DNAT Kubernetes Service ClusterIP for local worker processes
      ansible.builtin.iptables:
        table: nat
        chain: OUTPUT
        protocol: tcp
        destination: 10.96.0.1
        destination_port: "443"
        jump: DNAT
        to_destination: 10.10.1.50:6443
        action: insert
        rule_num: 1

    - name: DNAT Kubernetes Service ClusterIP for incoming host-network traffic
      ansible.builtin.iptables:
        table: nat
        chain: PREROUTING
        protocol: tcp
        destination: 10.96.0.1
        destination_port: "443"
        jump: DNAT
        to_destination: 10.10.1.50:6443
        action: insert
        rule_num: 1

    - name: SNAT ClusterIP source address to worker IP for NLB response routing
      ansible.builtin.iptables:
        table: nat
        chain: POSTROUTING
        protocol: tcp
        source: 10.96.0.1
        destination: 10.10.1.50
        destination_port: "6443"
        jump: MASQUERADE
        action: insert
        rule_num: 1
```

##### для проверки результата с ноды master-1:
```bash
sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes -o wide

echo
sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get pods -A -o wide
```

![](<Pasted image 20260920192044.png>)

Все элементы кластера в состоянии `Running`, имеют заданные сетевые атрибуты. 
В процессе настройки была диагностирована и устранена сетевая проблема bootstrap-этапа: взаимодействие внутреннего NLB, Service ClusterIP `10.96.0.1`, IPVS, conntrack/SNAT и CNI с воспроизводимым Ansible-решением. 

##### Для нового развертывания:
```bash
# 1. Клонировать  конфигурацию
git clone https://github.com/ArturP1rozhkov/MicroKuber/tree/main/kubernetes_HA.git ~/microkuber/kubernetes_HA

# 2. Получить зафиксированную версию Kubespray
git clone --branch v2.31.0 --depth 1 \
  https://github.com/kubernetes-sigs/kubespray.git \
  ~/microkuber/deploy/kubespray

# 3. Применить сетовые правила, нужные для NLB-схемы
ansible-playbook \
  -i ~/microkuber/kubernetes_HA/inventory/ha-cluster/hosts.yaml \
  ~/microkuber/kubernetes_HA/inventory/ha-cluster/api-nlb-nat.yml

# 4. Развернуть/сверить Kubernetes-кластер
cd ~/microkuber/deploy/kubespray

ansible-playbook \
  -i ~/microkuber/kubernetes_HA/inventory/ha-cluster/hosts.yaml \
  cluster.yml \
  -b -v
```



