# Sturk Mobile — Flutter starter

## Собрать APK через GitHub Actions (без Flutter на своём ПК)

1. Создай новый репозиторий на GitHub и загрузи в него содержимое этой папки.
2. Открой вкладку **Actions**.
3. Выбери workflow **Build Sturk APK**.
4. Нажми **Run workflow**.
5. В поле `api_url` укажи полный адрес API, например `https://твой-домен/api.php`.
6. После завершения открой запуск workflow и скачай artifact **Sturk-Android-APK**.

GitHub Actions создаст Android-папку, получит зависимости и соберёт release APK.
