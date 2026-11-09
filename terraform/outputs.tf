output "website_url" {
  value = "https://photos.${var.domain}/"
}

output "bucket_name" {
  value = yandex_storage_bucket.photos.bucket
}

output "access_key" {
  value     = yandex_iam_service_account_static_access_key.cloudphoto.access_key
  sensitive = true
}

output "secret_key" {
  value     = yandex_iam_service_account_static_access_key.cloudphoto.secret_key
  sensitive = true
}
