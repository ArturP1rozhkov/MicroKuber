# Внутренний NLB — "cluster IP" (controlPlaneEndpoint) для API-сервера.
# Заменяет keepalived-VIP: незарегистрированные адреса в SDN YC не
# доставляются (проверено экспериментально), адрес NLB выдаётся платформой.

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