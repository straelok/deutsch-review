import 'package:flutter/material.dart';

import '../../domain/id_generator.dart';
import '../../domain/learning_item.dart';
import '../../domain/learning_item_display.dart';
import '../../domain/practice.dart';
import '../../domain/repositories/learning_item_repository.dart';
import '../../domain/repositories/practice_repository.dart';
import '../../l10n/ui_strings.dart';

class DictionaryMaterialPage extends StatefulWidget {
  const DictionaryMaterialPage({
    required this.repository,
    required this.practice,
    required this.strings,
    required this.refreshToken,
    super.key,
  });

  final LearningItemRepository repository;
  final PracticeRepository practice;
  final UiStrings strings;
  final int refreshToken;

  @override
  State<DictionaryMaterialPage> createState() => _MaterialPageState();
}

class _MaterialPageState extends State<DictionaryMaterialPage> {
  final _searchController = TextEditingController();
  List<LearningItem> _items = const [];
  Object? _loadError;
  bool _loading = true;

  List<LearningItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items.where((item) {
      final values = <String>[
        learningItemGerman(item),
        learningItemMeaning(item),
        learningItemNote(item) ?? '',
        learningItemExample(item) ?? '',
      ];
      return values.any((value) => value.toLowerCase().contains(query));
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _reload();
    _searchController.addListener(_searchChanged);
  }

  @override
  void didUpdateWidget(covariant DictionaryMaterialPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) _reload();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_searchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.material,
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text(s.entries(_items.length)),
                ],
              ),
              FilledButton.icon(
                key: const Key('add-material'),
                onPressed: _loading ? null : () => _openEditor(),
                icon: const Icon(Icons.add),
                label: Text(s.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('material-search'),
            controller: _searchController,
            decoration: InputDecoration(
              labelText: s.search,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final s = widget.strings;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(s.loadError),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _reload, child: Text(s.retry)),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return _EmptyMaterial(title: s.noWords, message: s.noWordsHint);
    }
    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      return Center(child: Text(s.noSearchResults));
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final note = learningItemNote(item);
        final example = learningItemExample(item);
        return Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              child: Icon(
                item.type == LearningItemType.noun
                    ? Icons.text_fields
                    : Icons.translate,
              ),
            ),
            title: Text(learningItemGerman(item)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(learningItemMeaning(item)),
                if (example != null) Text(s.exampleValue(example)),
                if (note != null) Text(s.noteValue(note)),
                Text(s.addedAt(item.createdAt)),
              ],
            ),
            trailing: PopupMenuButton<String>(
              key: Key('item-menu-${item.id}'),
              onSelected: (action) {
                if (action == 'edit') _openEditor(item);
                if (action == 'delete') _delete(item);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text(s.edit)),
                PopupMenuItem(value: 'delete', child: Text(s.delete)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _searchChanged() => setState(() {});

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final items = await widget.repository.findActive();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([LearningItem? item]) async {
    final summary =
        item == null ? null : await widget.practice.summaryForItem(item.id);
    if (!mounted) return;
    final saved = await showDialog<LearningItem>(
      context: context,
      builder: (context) => _LearningItemEditor(
        item: item,
        statistics: summary,
        strings: widget.strings,
      ),
    );
    if (saved == null) return;
    final duplicate = _items.any(
      (existing) =>
          existing.id != saved.id &&
          existing.type == saved.type &&
          learningItemGerman(existing).trim().toLowerCase() ==
              learningItemGerman(saved).trim().toLowerCase(),
    );
    if (duplicate && !await _confirmDuplicate()) return;

    try {
      await widget.repository.save(saved);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                item == null ? widget.strings.added : widget.strings.saved)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.saveError)),
      );
    }
  }

  Future<bool> _confirmDuplicate() async {
    final s = widget.strings;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(s.duplicateTitle),
            content: Text(s.duplicateMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.saveAnyway),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _delete(LearningItem item) async {
    final s = widget.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteTitle),
        content: Text(s.deleteMessage(learningItemGerman(item))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository
        .softDelete(id: item.id, deletedAt: DateTime.now().toUtc());
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.deleted),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () async {
            await widget.repository.restore(
              id: item.id,
              restoredAt: DateTime.now().toUtc(),
            );
            await _reload();
          },
        ),
      ),
    );
  }
}

class _EmptyMaterial extends StatelessWidget {
  const _EmptyMaterial({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _LearningItemEditor extends StatefulWidget {
  const _LearningItemEditor({
    required this.strings,
    this.item,
    this.statistics,
  });

  final UiStrings strings;
  final LearningItem? item;
  final PracticeSummary? statistics;

  @override
  State<_LearningItemEditor> createState() => _LearningItemEditorState();
}

class _LearningItemEditorState extends State<_LearningItemEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _german;
  late final TextEditingController _translation;
  late final TextEditingController _plural;
  late final TextEditingController _note;
  late final TextEditingController _example;
  late LearningItemType _type;
  late String _article;

  bool get _isNoun => _type == LearningItemType.noun;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _type = item?.type == LearningItemType.noun
        ? LearningItemType.noun
        : LearningItemType.word;
    _article = item?.content['article'] as String? ?? 'der';
    _german = TextEditingController(text: item?.content['german'] as String?);
    _translation =
        TextEditingController(text: item?.content['translation_ru'] as String?);
    _plural = TextEditingController(text: item?.content['plural'] as String?);
    _note = TextEditingController(text: item?.content['note'] as String?);
    _example = TextEditingController(text: item?.content['example'] as String?);
  }

  @override
  void dispose() {
    _german.dispose();
    _translation.dispose();
    _plural.dispose();
    _note.dispose();
    _example.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return AlertDialog(
      title: Text(widget.item == null ? s.addMaterial : s.editMaterial),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<LearningItemType>(
                  key: const Key('material-type'),
                  initialValue: _type,
                  decoration: InputDecoration(labelText: s.type),
                  items: [
                    DropdownMenuItem(
                        value: LearningItemType.word, child: Text(s.word)),
                    DropdownMenuItem(
                        value: LearningItemType.noun, child: Text(s.noun)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 12),
                if (_isNoun) ...[
                  DropdownButtonFormField<String>(
                    key: const Key('article'),
                    initialValue: _article,
                    decoration: InputDecoration(labelText: s.article),
                    items: const [
                      DropdownMenuItem(value: 'der', child: Text('der')),
                      DropdownMenuItem(value: 'die', child: Text('die')),
                      DropdownMenuItem(value: 'das', child: Text('das')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _article = value);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _field(
                  key: const Key('german'),
                  controller: _german,
                  label: _isNoun ? s.noun : s.germanWord,
                  capitalization: _isNoun
                      ? TextCapitalization.words
                      : TextCapitalization.sentences,
                ),
                if (_isNoun) ...[
                  const SizedBox(height: 12),
                  _field(
                      key: const Key('plural'),
                      controller: _plural,
                      label: s.plural),
                ],
                const SizedBox(height: 12),
                _field(
                  key: const Key('translation'),
                  controller: _translation,
                  label: s.meaning,
                ),
                const SizedBox(height: 12),
                _field(
                  key: const Key('usage-example'),
                  controller: _example,
                  label: s.usageExample,
                  required: false,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _field(
                  key: const Key('note'),
                  controller: _note,
                  label: s.note,
                  required: false,
                  maxLines: 3,
                ),
                if (widget.statistics case final statistics?) ...[
                  const SizedBox(height: 20),
                  _WordStatistics(summary: statistics, strings: s),
                ],
                if (widget.item != null) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      s.addedAt(widget.item!.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          key: const Key('save-material'),
          onPressed: _submit,
          child: Text(s.save),
        ),
      ],
    );
  }

  TextFormField _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    TextCapitalization capitalization = TextCapitalization.sentences,
    bool required = true,
    int maxLines = 1,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: required ? _required : null,
      textCapitalization: capitalization,
      maxLines: maxLines,
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? widget.strings.requiredField
        : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final previous = widget.item;
    final now = DateTime.now().toUtc();
    Navigator.pop(
      context,
      LearningItem(
        id: previous?.id ?? newUuidV4(),
        type: _type,
        level: previous?.level ?? '',
        lesson: previous?.lesson ?? '',
        topic: previous?.topic ?? '',
        learned: true,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
        sourceRef: previous?.sourceRef ?? 'manual',
        content: <String, Object?>{
          'german': _german.text.trim(),
          'translation_ru': _translation.text.trim(),
          if (_isNoun) 'article': _article,
          if (_isNoun) 'plural': _plural.text.trim(),
          if (_example.text.trim().isNotEmpty) 'example': _example.text.trim(),
          if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        },
      ),
    );
  }
}

class _WordStatistics extends StatelessWidget {
  const _WordStatistics({required this.summary, required this.strings});

  final PracticeSummary summary;
  final UiStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.wordStatistics,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _value('word-stat-attempts', strings.attempts, summary.attempts),
            _value(
                'word-stat-correct', strings.correctAnswers, summary.correct),
            _value('word-stat-errors', strings.errors, summary.errors),
            _value(
              'word-stat-accuracy',
              strings.accuracy,
              '${(summary.accuracy * 100).round()} %',
            ),
          ],
        ),
      ],
    );
  }

  Widget _value(String key, String label, Object value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: '$value',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      key: Key(key),
    );
  }
}
