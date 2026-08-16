# Выпуск Android

1. Создать upload key и сохранить его резервную копию вне репозитория:

```powershell
keytool -genkeypair -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Создать игнорируемый `android/key.properties`:

```properties
storeFile=upload-keystore.jks
storePassword=<секрет>
keyAlias=upload
keyPassword=<секрет>
```

3. Собрать публикационные артефакты:

```powershell
flutter build appbundle --release
flutter build apk --release --split-per-abi
```

4. Загрузить `build/app/outputs/bundle/release/app-release.aab` в закрытое
тестирование Google Play. Проверить privacy URL:
`https://obaldevshi-gbou-security-bbbf.twc1.net/privacy.html`.

Без `key.properties` сборка использует debug-подпись и предназначена только для
внутренней проверки, не для публикации в магазине.
