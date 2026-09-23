# outputs.tf — то, что Terraform покажет после apply.
# Именно по этим адресам будем подключаться и собирать кластер.

output "master_public_ip" {
  value       = yandex_compute_instance.master.network_interface[0].nat_ip_address
  description = "Внешний IP мастера — единственная точка входа в кластер снаружи"
}

output "master_internal_ip" {
  value       = yandex_compute_instance.master.network_interface[0].ip_address
  description = "Внутренний IP мастера (он же NAT и control-plane endpoint)"
}

output "workers_internal_ips" {
  value = {
    for name, vm in yandex_compute_instance.worker :
    name => vm.network_interface[0].ip_address
  }
  description = "Внутренние адреса воркеров (private-подсеть)"
}

# Готовый шаблон команды для подключения к воркеру через мастер-jumphost.
# Пример: ssh -J ubuntu@<master_public_ip> ubuntu@10.10.2.11
output "ssh_jump_example" {
  value = format(
    "ssh -J ubuntu@%s ubuntu@10.10.2.11",
    yandex_compute_instance.master.network_interface[0].nat_ip_address
  )
  description = "Пример подключения к worker-1 через мастер как jump host"
}
