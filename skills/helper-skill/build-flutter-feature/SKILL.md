---
name: build-flutter-feature
description: Спроектировать или реализовать изолированную Flutter-фичу по SOLID и частичной Clean Architecture. Использовать при добавлении новой функции, разделении слоёв, создании repository/use case/BLoC, mock-режима или исправлении архитектурных зависимостей.
---

# Архитектура Flutter-фичи

1. Прочитать карточку функции, API-контракт и ближайшую существующую фичу. Не реорганизовывать весь проект ради одной задачи.
2. Создать feature-local структуру для нового кода:

```text
features/<feature>/
├── domain/         # сущности/DTO, repository contract, use cases
├── data/           # API models, datasource, mappers, repository implementation
└── presentation/   # bloc, pages, widgets
```

3. Соблюдать направление зависимостей: `presentation → domain ← data`. Domain не должен импортировать Retrofit, Dio, JSON-модели, Flutter widgets или файлы из `data/`.
4. Описать domain-типы и узкий repository interface для одной фичи. Не расширять общий `MainRepository`, если контракт относится только к новой функции.
5. Возвращать из repository domain-типы и `Either<Failure, T>`. Преобразовывать request/response models в domain внутри data-слоя.
6. Создать отдельный use case для каждого бизнес-действия. Use case координирует правила и repository, но не знает о UI и HTTP.
7. В data-слое разделить сетевой datasource, сериализуемые модели, mapper и implementation repository. Ошибки переводить через общий `ErrorHandler`.
8. В presentation хранить только UI-состояние и оркестрацию: событие → use case → новое состояние. Не создавать request models и не парсить JSON внутри BLoC/page.
9. Разделять ответственность по SOLID:
   - один класс — одна причина изменения;
   - presentation зависит от абстракции repository через use case;
   - интерфейс repository содержит только операции фичи;
   - real и mock implementations взаимозаменяемы.
10. Зарегистрировать зависимости через Injectable/GetIt и обновить mock implementation, чтобы `main_mock.dart` поддерживал тот же сценарий.
11. Добавить маршрут и ARB-строки только после готовности domain/data контракта. UI строить по `../design-flutter-ui/SKILL.md`.
12. Запустить только необходимые генераторы и форматирование. Не запускать `flutter analyze`, тесты, приложение, UI-проверки и сборки без отдельной явной просьбы пользователя.
13. Статически сверить mapping API→domain, success/failure use case и основные BLoC transitions по коду; mock-сценарий передать пользователю для ручной проверки.

Не создавать абстракцию без варианта использования. Допустимо объединить простые mapper/model файлы, но нельзя смешивать domain с transport-моделями или UI с сетевым кодом.
