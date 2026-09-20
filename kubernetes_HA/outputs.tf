output "masters_public_ips" {
  value = {
    for name, vm in yandex_compute_instance.master :
    name => vm.network_interface[0].nat_ip_address
  }
  description = "Публичные IP всех master-нод"
}

output "api_lb_ip" {
  value       = local.api_lb_ip
  description = "Внутренний IP NLB — controlPlaneEndpoint (loadbalancer_apiserver в kubespray)"
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