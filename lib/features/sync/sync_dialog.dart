import 'package:flutter/material.dart';

import '../../l10n/ui_strings.dart';
import '../../sync/sync_controller.dart';
import '../../sync/sync_models.dart';

Future<void> showSyncDialog({
  required BuildContext context,
  required SyncController controller,
  required UiStrings strings,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SyncDialog(
      controller: controller,
      strings: strings,
    ),
  );
}

class _SyncDialog extends StatefulWidget {
  const _SyncDialog({required this.controller, required this.strings});

  final SyncController controller;
  final UiStrings strings;

  @override
  State<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<_SyncDialog> {
  late final TextEditingController _nicknameController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: widget.controller.nickname ?? '',
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final busy = controller.phase == SyncPhase.syncing;
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.cloud_sync_outlined),
              const SizedBox(width: 10),
              Expanded(child: Text(s.syncTitle)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.syncRiskHint),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('sync-nickname'),
                    controller: _nicknameController,
                    enabled: !busy,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: s.nickname,
                      helperText: s.nicknameHint,
                      errorText: _validationError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StatusPanel(controller: controller, strings: s),
                ],
              ),
            ),
          ),
          actions: [
            if (controller.nickname != null)
              TextButton(
                onPressed: busy ? null : _disconnect,
                child: Text(s.disconnectSync),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.close),
            ),
            if (controller.nickname != null)
              OutlinedButton.icon(
                key: const Key('sync-now'),
                onPressed: busy ? null : controller.syncNow,
                icon: const Icon(Icons.sync),
                label: Text(s.syncNow),
              ),
            FilledButton(
              key: const Key('connect-sync'),
              onPressed: busy ? null : _connect,
              child: Text(
                controller.nickname == null ? s.connectSync : s.changeNickname,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _connect() async {
    final value = _nicknameController.text;
    if (!isValidNickname(value)) {
      setState(() => _validationError = widget.strings.nicknameError);
      return;
    }
    setState(() => _validationError = null);
    await widget.controller.connect(value);
  }

  Future<void> _disconnect() async {
    await widget.controller.disconnect();
    _nicknameController.clear();
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.controller, required this.strings});

  final SyncController controller;
  final UiStrings strings;

  @override
  Widget build(BuildContext context) {
    final (icon, text, color) = switch (controller.phase) {
      SyncPhase.disconnected => (
          Icons.cloud_off_outlined,
          strings.syncDisconnected,
          null,
        ),
      SyncPhase.idle => (Icons.cloud_queue, strings.syncReady, null),
      SyncPhase.syncing => (Icons.sync, strings.syncing, null),
      SyncPhase.synced => (
          Icons.cloud_done_outlined,
          strings.syncComplete,
          Colors.green,
        ),
      SyncPhase.error => (
          Icons.cloud_off_outlined,
          strings.syncError,
          Theme.of(context).colorScheme.error,
        ),
      SyncPhase.unavailable => (
          Icons.settings_outlined,
          strings.syncUnavailable,
          Theme.of(context).colorScheme.error,
        ),
    };
    final lastSuccess = controller.lastSuccess;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(text)),
                if (controller.phase == SyncPhase.syncing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (controller.nickname != null) ...[
              const SizedBox(height: 6),
              Text('${strings.nickname}: ${controller.nickname}'),
            ],
            if (lastSuccess != null) ...[
              const SizedBox(height: 4),
              Text(strings.lastSync(lastSuccess)),
            ],
          ],
        ),
      ),
    );
  }
}
