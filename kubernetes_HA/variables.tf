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