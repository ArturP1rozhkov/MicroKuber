data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

locals {
  masters = {
    master-1 = "10.10.1.10"
    master-2 = "10.10.1.11"
    master-3 = "10.10.1.12"
  }
  master_priority = {
    master-1 = 150
    master-2 = 140
    master-3 = 130
  }
  workers = {
    worker-1 = "10.10.2.11"
    worker-2 = "10.10.2.12"
    worker-3 = "10.10.2.13"
    worker-4 = "10.10.2.14"
  }
  nodemap = merge(local.masters, local.workers, { "k8s-vip" = local.vip })
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
      hostname      = each.key
      role          = "master"
      nodemap       = local.nodemap
      vip           = local.vip
      node_ip       = each.value
      vrrp_state    = each.key == "master-1" ? "MASTER" : "BACKUP"
      vrrp_priority = local.master_priority[each.key]
      vrrp_pass     = local.vrrp_pass
      peers         = [for k, ip in local.masters : ip if k != each.key]
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
      hostname      = each.key
      role          = "worker"
      nodemap       = local.nodemap
      vip           = local.vip
      node_ip       = each.value
      vrrp_state    = "BACKUP"
      vrrp_priority = 100
      vrrp_pass     = local.vrrp_pass
      peers         = []
    })
  }

  labels = {
    role    = "worker"
    project = "k8s-course"
  }

  depends_on = [yandex_compute_instance.master]
}