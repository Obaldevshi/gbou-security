---
name: 10-add-feature
description: Реализовать одну функцию FastAPI + Flutter для mobile и web. Использовать после подготовки карточки функции.
---

# Реализация функции

1. Прочитать карточку функции, релевантный код и helpers `skills/helper-skill/build-flutter-feature/SKILL.md` и `skills/helper-skill/build-fastapi-feature/SKILL.md`.
2. Реализовать backend по слоям: model, schema, repository, service, route и migration при необходимости.
3. Реализовать Flutter по слоям: API model/service, repository, use case/BLoC и общий UI mobile/web.
4. Синхронизировать пути, поля, nullable-типы, пагинацию и обработку ошибок.
5. Обновить mock fixtures и mock repositories для того же сценария.
6. Для различий ширины использовать `AppLayoutItemBuilder`; не дублировать экраны без платформенной необходимости.
7. Запустить только требуемые генераторы и форматирование, если без них нельзя получить корректный исходный код.
8. Не запускать приложение, эмулятор, Chrome, визуальную проверку UI, `flutter analyze`, тесты и любые `flutter build`/Makefile-сборки без отдельной явной просьбы пользователя.
9. Обновить карточку функции фактическими изменениями и перейти к `$11-verify-mock`, чтобы подготовить пользователю ручной чек-лист.
