import 'package:flutter/material.dart';

import '../../domain/daily_session.dart';
import '../../domain/repositories/daily_session_repository.dart';
import '../../l10n/ui_strings.dart';
import '../../reminders/reminder_controller.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({
    required this.sessions,
    required this.strings,
    required this.refreshToken,
    required this.onOpenSession,
    this.reminders,
    super.key,
  });

  final DailySessionRepository sessions;
  final UiStrings strings;
  final int refreshToken;
  final ValueChanged<String> onOpenSession;
  final ReminderController? reminders;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  List<DailySession>? _sessions;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant TodayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken ||
        widget.strings.language != oldWidget.strings.language) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    if (sessions == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final s = widget.strings;
    final requiredSessions = sessions.where((session) => session.isRequired);
    final extras = sessions.where((session) => !session.isRequired);
    final completed =
        requiredSessions.where((session) => session.isComplete).length;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(s.dailyPlan, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(s.dailyProgress(completed)),
        if (widget.reminders case final reminders?) ...[
          const SizedBox(height: 16),
          _reminderCard(reminders),
        ],
        const SizedBox(height: 16),
        ...requiredSessions.map(_sessionCard),
        if (extras.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(s.extraSession, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...extras.map(_sessionCard),
        ],
      ],
    );
  }

  Widget _reminderCard(ReminderController reminders) {
    final s = widget.strings;
    return AnimatedBuilder(
      animation: reminders,
      builder: (context, _) => Card(
        child: ListTile(
          leading: Icon(
            reminders.isEnabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
          ),
          title: Text(s.remindersTitle),
          subtitle: Text(
            reminders.isEnabled ? s.remindersEnabled : s.remindersDisabled,
          ),
          trailing: reminders.isEnabled
              ? const Icon(Icons.check)
              : FilledButton(
                  key: const Key('enable-reminders'),
                  onPressed:
                      reminders.isBusy ? null : reminders.requestPermission,
                  child: reminders.isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(s.enableReminders),
                ),
        ),
      ),
    );
  }

  Widget _sessionCard(DailySession session) {
    final s = widget.strings;
    final status = switch (session.status) {
      DailySessionStatus.planned => s.planned,
      DailySessionStatus.inProgress => s.inProgress,
      DailySessionStatus.completed => s.completed,
    };
    final action = switch (session.status) {
      DailySessionStatus.planned => s.start,
      DailySessionStatus.inProgress => s.continueSession,
      DailySessionStatus.completed => s.repeatSession,
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: session.isComplete
              ? const Icon(Icons.check)
              : Text('${session.slot ?? '+'}'),
        ),
        title: Text(
          session.slot == null
              ? s.extraSession
              : s.sessionNumber(session.slot!),
        ),
        subtitle: Text(
          '$status · ${s.sessionAnswers(session.answeredCount, session.targetAnswers)}',
        ),
        trailing: FilledButton(
          key: Key('open-session-${session.slot ?? session.id}'),
          onPressed: () => _open(session),
          child: Text(action),
        ),
      ),
    );
  }

  Future<void> _open(DailySession session) async {
    if (session.isComplete) {
      final extra = await widget.sessions.createExtra(
        localDate: localDayKey(DateTime.now()),
        now: DateTime.now().toUtc(),
      );
      widget.onOpenSession(extra.id);
      return;
    }
    widget.onOpenSession(session.id);
  }

  Future<void> _reload() async {
    final now = DateTime.now();
    final sessions = await widget.sessions.ensureDay(
      localDate: localDayKey(now),
      now: now.toUtc(),
    );
    if (mounted) setState(() => _sessions = sessions);
  }
}
