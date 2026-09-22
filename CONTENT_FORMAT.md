# Content format

Статус: начальный проект формата. До реализации импорта структура может уточняться. Любое несовместимое изменение повышает `format_version` и получает миграцию.

## Пакет

```json
{
  "format_version": 1,
  "package_id": "0195f6d8-8b37-7c98-a816-7a6a4ee8bdf1",
  "created_at": "2026-09-22T12:00:00Z",
  "source": {
    "kind": "textbook",
    "title": "Schritte plus Neu",
    "reference": "A1.1, Lektion 1"
  },
  "items": []
}
```

## Общие поля элемента

```json
{
  "id": "0195f6d8-b4aa-7c10-92bf-294df3c82d79",
  "type": "noun",
  "level": "A1.1",
  "lesson": "1",
  "topic": "Begrüßung",
  "learned": true,
  "created_at": "2026-09-22T12:00:00Z",
  "updated_at": "2026-09-22T12:00:00Z",
  "deleted_at": null,
  "source_ref": "Schritte plus Neu, A1.1, Lektion 1",
  "content": {}
}
```

## Начальные значения `type`

- `word`
- `noun`
- `verb`
- `phrase`
- `sentence`
- `grammar_rule`
- `rule_example`
- `fill_gap`
- `word_order`
- `multiple_choice`

Несколько правильных ответов задаются массивом `accepted_answers` внутри `content`. Русская подсказка хранится явно в `content.hint_ru`; приложение не генерирует её самостоятельно.

## Правила импорта

- Пакет полностью проверяется до записи в основную базу.
- Неизвестная версия отклоняется с понятным сообщением.
- UUID валидируются; совпадения показываются пользователю до импорта.
- Импорт не удаляет существующие данные молча.
- Ошибка одного элемента отображается с его индексом или UUID.
