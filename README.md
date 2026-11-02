# Салон красоты

Приложение на Flutter Web для записи в салон красоты. Данные хранит PocketBase, клиент работает через REST API. Есть три роли: клиент, мастер и администратор.

Запуск сервера. Скачайте PocketBase с https://github.com/pocketbase/pocketbase/releases, положите pocketbase.exe в папку pocketbase. Откройте в этой папке PowerShell (не запускайте exe двойным щелчком) и выполните:

    .\pocketbase.exe superuser upsert admin@salon.com Admin2026!
    .\pocketbase.exe serve

Схема данных и правила доступа создаются сами из папки pb_migrations, серверные проверки лежат в pb_hooks. Учебные данные загружаются так:

    $env:PB_ADMIN_EMAIL="admin@salon.com"
    $env:PB_ADMIN_PASSWORD="Admin2026!"
    node pocketbase/seed.mjs

Запуск приложения:

    flutter pub get
    flutter run -d edge --web-port=5555 --web-hostname=localhost --dart-define=API_BASE_URL=http://127.0.0.1:8090/api

Без сервера данные можно хранить в браузере:

    flutter run -d edge --dart-define=BACKEND=persistent

Логическая и физическая схемы базы данных лежат в docs/er-model.drawio, файл открывается в draw.io.

Учётные записи: admin@salon.ru / Admin2026!, master@salon.ru / Master2026!, client@salon.ru / Client2026!.

Проверки:

    flutter analyze
    flutter test

Публикация на GitHub Pages идёт через .github/workflows/deploy.yml. В настройках репозитория нужно выбрать источник Pages «GitHub Actions». Опубликованная версия хранит данные в браузере.
