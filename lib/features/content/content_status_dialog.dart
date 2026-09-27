import 'package:flutter/material.dart';

import '../../content/content_controller.dart';
import '../../domain/app_language.dart';

Future<void> showContentStatusDialog({
  required BuildContext context,
  required ContentController controller,
  required AppLanguage language,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ContentStatusDialog(
      controller: controller,
      language: language,
    ),
  );
}

class _ContentStatusDialog extends StatelessWidget {
  const _ContentStatusDialog({
    required this.controller,
    required this.language,
  });

  final ContentController controller;
  final AppLanguage language;

  bool get _ru => language == AppLanguage.russian;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final checking = controller.phase == ContentUpdatePhase.checking;
        return AlertDialog(
          title: Text(_ru ? 'Учебные материалы' : 'Lerninhalte'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusRow(
                  label: _ru ? 'Версия' : 'Version',
                  value: controller.manifest.contentVersion,
                ),
                _StatusRow(
                  label: _ru ? 'Опубликовано' : 'Veröffentlicht',
                  value: _date(controller.manifest.publishedAt.toLocal()),
                ),
                _StatusRow(
                  label: _ru ? 'Источник' : 'Quelle',
                  value: controller.isBundled
                      ? (_ru ? 'Встроенная копия' : 'Integrierte Kopie')
                      : (_ru ? 'Загруженная копия' : 'Geladene Kopie'),
                ),
                _StatusRow(
                  label: _ru ? 'Состояние' : 'Status',
                  value: _phaseText(controller.phase),
                ),
                if (controller.lastCheckedAt case final checked?)
                  _StatusRow(
                    label: _ru ? 'Последняя проверка' : 'Letzte Prüfung',
                    value: _dateTime(checked.toLocal()),
                  ),
                if (controller.phase == ContentUpdatePhase.incompatible) ...[
                  const SizedBox(height: 12),
                  Text(
                    _ru
                        ? 'Для этой версии материалов нужно обновить приложение.'
                        : 'Für diese Lerninhalte muss die App aktualisiert werden.',
                  ),
                ],
                if (controller.phase == ContentUpdatePhase.error) ...[
                  const SizedBox(height: 12),
                  Text(
                    _ru
                        ? 'Проверка не удалась. Текущие материалы доступны офлайн.'
                        : 'Die Prüfung ist fehlgeschlagen. Die aktuellen Inhalte bleiben offline verfügbar.',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_ru ? 'Закрыть' : 'Schließen'),
            ),
            FilledButton.icon(
              key: const Key('check-content-update'),
              onPressed: checking || !controller.isConfigured
                  ? null
                  : controller.checkNow,
              icon: checking
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_ru ? 'Проверить' : 'Prüfen'),
            ),
          ],
        );
      },
    );
  }

  String _phaseText(ContentUpdatePhase phase) => switch (phase) {
        ContentUpdatePhase.idle => _ru ? 'Готово' : 'Bereit',
        ContentUpdatePhase.checking => _ru ? 'Проверка…' : 'Prüfung…',
        ContentUpdatePhase.upToDate => _ru ? 'Актуально' : 'Aktuell',
        ContentUpdatePhase.updated => _ru ? 'Обновлено' : 'Aktualisiert',
        ContentUpdatePhase.unavailable =>
          _ru ? 'Сервер не настроен' : 'Server nicht konfiguriert',
        ContentUpdatePhase.incompatible =>
          _ru ? 'Нужно обновить приложение' : 'App-Update erforderlich',
        ContentUpdatePhase.error =>
          _ru ? 'Нет связи с сервером' : 'Server nicht erreichbar',
      };

  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';

  String _dateTime(DateTime value) =>
      '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
