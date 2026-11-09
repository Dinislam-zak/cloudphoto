terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.120"
    }
  }
}

provider "yandex" {
  folder_id = var.folder_id
  zone      = "ru-central1-a"
}

resource "yandex_storage_bucket" "photos" {
  bucket    = var.bucket_name
  folder_id = var.folder_id


  https {
    certificate_id = var.cert_id
  }
  lifecycle {
    ignore_changes = [
      website,
      anonymous_access_flags,
    ]
  }

}

resource "yandex_dns_recordset" "photos" {
  zone_id = var.dns_zone_id
  name    = "photos"
  type    = "CNAME"
  ttl     = 3600
  data    = ["${var.bucket_name}.website.yandexcloud.net."]
}


resource "yandex_iam_service_account" "cloudphoto" {
  name      = "cloudphoto-sa-vvot16"
  folder_id = var.folder_id
}


resource "yandex_resourcemanager_folder_iam_member" "cloudphoto_storage" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.cloudphoto.id}"
}

resource "yandex_iam_service_account_static_access_key" "cloudphoto" {
  service_account_id = yandex_iam_service_account.cloudphoto.id
  description        = "Static key for cloudphoto CLI"
}
