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
  description = "Минорная ветка Kubernetes"
}

variable "preemptible" {
  type        = bool
  default     = true
  description = "Прерываемые ВМ"
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
