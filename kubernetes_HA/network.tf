locals {
  vip       = "10.10.1.100"
  vrrp_pass = "k8svrrp" # не более 8 символов — ограничение VRRP
}

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

resource "yandex_vpc_route_table" "k8s" {
  name       = "k8s-private-via-vip"
  network_id = yandex_vpc_network.k8s.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = local.vip
  }
}