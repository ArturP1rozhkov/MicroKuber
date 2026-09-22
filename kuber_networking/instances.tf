# instances.tf — виртуальные машины: 1 мастер и 4 воркера

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

locals {
  workers = {
    "worker-1" = "10.10.2.11"
    "worker-2" = "10.10.2.12"
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
