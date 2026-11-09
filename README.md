# cloudphoto

Фотоархив на Yandex Object Storage.

## Состав

- `terraform/` — инфраструктура: бакет Object Storage, CNAME-запись
  `photos.vvot16.itiscl.ru`, сервисный аккаунт для CLI, привязка
  TLS-сертификата Let's Encrypt из Certificate Manager.
- `cmd/cloudphoto/`, `internal/` — CLI-утилита `cloudphoto` на Go (WIP).

## Требования к окружению

- Terraform >= 1.5
- Yandex Cloud CLI (`yc`), аутентифицированный под аккаунтом с правами
  на каталог `b1gp6r963tbt3s9i3unj`
- Go >= 1.22 (для CLI)
- Для Terraform: `export YC_TOKEN=$(yc iam create-token)`

## Terraform

```bash
cd terraform
export YC_TOKEN=$(yc iam create-token)
terraform init
terraform plan
terraform apply