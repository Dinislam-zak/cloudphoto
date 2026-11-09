# Cloudphoto

Фотоархив на Yandex Object Storage.

## Состав репозитория

- `terraform/` — инфраструктура: бакет, CNAME `photos.<domain>`, сервисный аккаунт, статический ключ, привязка сертификата.
- `cmd/cloudphoto/`, `internal/` — CLI `cloudphoto` на Go.
- `scripts/` — тестовые скрипты.

## Требования к окружению

Для `cloudphoto`:

| Переменная | Значение |
|---|---|
| `BUCKET` | Имя бакета (`vvot16-photos-2026`) |
| `AWS_ACCESS_KEY_ID` | Статический ключ сервисного аккаунта |
| `AWS_SECRET_ACCESS_KEY` | Секретная часть статического ключа |

Ключи создаются Terraform:
```bash
terraform output -raw access_key
terraform output -raw secret_key
```

Для Terraform нужна `YC_TOKEN`:
```bash
export YC_TOKEN=$(yc iam create-token)
```

Go ≥ 1.22, Linux x86_64.

## Сборка

```bash
go build -o cloudphoto ./cmd/cloudphoto
```

Кросс-компиляция под целевую платформу:
```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o cloudphoto ./cmd/cloudphoto
```

## Terraform

```bash
cd terraform
export YC_TOKEN=$(yc iam create-token)
terraform init
terraform apply
```

После `apply` подождите 1–5 минут, пока DNS-запись `photos.<domain>` распространится. Сайт заработает после `cloudphoto mksite`.

**Не запускайте `terraform apply` после `mksite` без необходимости.** `mksite` настраивает `website` и публичный ACL бакета, они исключены из управления Terraform через `lifecycle.ignore_changes`.

## Использование cloudphoto

```
cloudphoto list [--album ALBUM]
cloudphoto upload --album ALBUM [--path DIR]
cloudphoto download --album ALBUM [--path DIR]
cloudphoto delete --album ALBUM [--photo PHOTO]
cloudphoto mksite
```

## Схема организации облачного хранилища

| Назначение | Ключ объекта |
|---|---|
| Фотография | `album/<имя-альбома>/<исходное-имя-файла>` |
| Маркер пустого альбома | `album/<имя-альбома>/` (объект нулевого размера) |
| Главная страница | `index.html` |
| Страница ошибки | `error.html` |
| Страница альбома | `album<N>.html`, где N — временный номер от 1 до числа альбомов |

### Обоснование

1. **Однозначная связь «альбом — фотография».** Ключ `album/<album>/<file>` делится на три сегмента: префикс `album`, имя альбома, имя файла. Символ `/` запрещён в именах альбомов и файлов (валидируется в CLI), поэтому разделитель однозначен.

2. **Сохранение регистра.** S3-ключи регистрозависимы, `Photo1.JPG` и `photo1.jpg` — разные объекты. В `list` возвращаются исходные имена с регистром.

3. **Одинаковые имена в разных альбомах** не конфликтуют — разные префиксы `album/A/` и `album/B/`.

4. **Одинаковые имена в одном альбоме** — это один ключ, повторный `upload` перезаписывает объект (требование «заменить фотографию»).

5. **Пустой альбом.** Маркер `album/<album>/` (объект нулевого размера) делает альбом видимым в `ListObjectsV2` с `Prefix="album/"` и `Delimiter="/"` (попадает в `CommonPrefixes`). `ListPhotos` без delimiter отбрасывает ключ, совпадающий с префиксом, и фотографий в альбоме не числится.

6. **Отличие фотографий от служебных страниц.** Служебные страницы в корне (`index.html`, `error.html`, `album<N>.html`), фотографии — под `album/`. `ListAlbums` запрашивает только `Prefix="album/"`, поэтому служебные объекты в листинг альбомов не попадают.

7. **Кириллица, пробелы, спецсимволы.** S3 хранит ключи как UTF-8, имена попадают в ключ без искажений. При генерации HTML в `mksite` имена экранируются `html.EscapeString`, URL фотографий — через `url.URL{Path:...}.EscapedPath()` (percent-encoding UTF-8).

8. **Идемпотентность.** `upload` перезаписывает ключ, `delete` без `--photo` удаляет всё под префиксом, `mksite` перезаписывает `index.html`, `error.html`, `album<N>.html`. Повторный запуск любой команды не создаёт дублей.

9. **Отсутствие конфликта со служебными страницами.** Альбом с именем `1.html` создаст ключи `album/1.html/...` — это не пересекается с `album1.html` в корне.

## Тесты

```bash
export BUCKET=vvot16-photos-2026
export AWS_ACCESS_KEY_ID=$(cat ~/.cloudphoto_access_key)
export AWS_SECRET_ACCESS_KEY=$(cat ~/.cloudphoto_secret_key)

./scripts/test_upload.sh
./scripts/test_download.sh
./scripts/test_delete.sh
./scripts/test_mksite.sh
```