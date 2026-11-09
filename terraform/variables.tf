variable "folder_id" {
  type        = string
  description = "ID каталога Yandex Cloud"
}

variable "bucket_name" {
  type        = string
  description = "Имя бакета"
}

variable "domain" {
  type        = string
  description = "Доменная зона, например vvot16.itiscl.ru"
}

variable "cert_id" {
  type        = string
  description = "ID сертификата в Certificate Manager"
}

variable "dns_zone_id" {
  type        = string
  description = "ID DNS-зоны"
}
