import 'package:flutter/material.dart';

import '../../domain/id_generator.dart';
import '../../domain/learning_item.dart';
import '../../domain/learning_item_display.dart';
import '../../domain/repositories/learning_item_repository.dart';
import '../../l10n/ui_strings.dart';

class DictionaryMaterialPage extends StatefulWidget {
  const DictionaryMaterialPage({
    required this.repository,
    required this.strings,
    super.key,
  });

  final LearningItemRepository repository;
  final UiStrings strings;

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
        item.topic,
        item.level,
        item.lesson,
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
            subtitle: Text(
              '${learningItemMeaning(item)}  •  '
              '${item.level} · ${s.lesson} ${item.lesson} · ${item.topic}',
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
    final saved = await showDialog<LearningItem>(
      context: context,
      builder: (context) =>
          _LearningItemEditor(item: item, strings: widget.strings),
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
  const _LearningItemEditor({required this.strings, this.item});

  final UiStrings strings;
  final LearningItem? item;

  @override
  State<_LearningItemEditor> createState() => _LearningItemEditorState();
}

class _LearningItemEditorState extends State<_LearningItemEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _german;
  late final TextEditingController _translation;
  late final TextEditingController _plural;
  late final TextEditingController _level;
  late final TextEditingController _lesson;
  late final TextEditingController _topic;
  late final TextEditingController _source;
  late LearningItemType _type;
  late String _article;
  late bool _learned;

  bool get _isNoun => _type == LearningItemType.noun;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _type = item?.type == LearningItemType.noun
        ? LearningItemType.noun
        : LearningItemType.word;
    _article = item?.content['article'] as String? ?? 'der';
    _learned = item?.learned ?? true;
    _german = TextEditingController(text: item?.content['german'] as String?);
    _translation =
        TextEditingController(text: item?.content['translation_ru'] as String?);
    _plural = TextEditingController(text: item?.content['plural'] as String?);
    _level = TextEditingController(text: item?.level ?? 'A1.1');
    _lesson = TextEditingController(text: item?.lesson);
    _topic = TextEditingController(text: item?.topic);
    _source = TextEditingController(
        text: item?.sourceRef ?? 'DAA / Schritte plus Neu');
  }

  @override
  void dispose() {
    _german.dispose();
    _translation.dispose();
    _plural.dispose();
    _level.dispose();
    _lesson.dispose();
    _topic.dispose();
    _source.dispose();
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
                Row(
                  children: [
                    Expanded(
                        child: _field(
                            key: const Key('level'),
                            controller: _level,
                            label: s.level)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _field(
                            key: const Key('lesson'),
                            controller: _lesson,
                            label: s.lesson)),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                    key: const Key('topic'),
                    controller: _topic,
                    label: s.topic),
                const SizedBox(height: 12),
                _field(
                    key: const Key('source'),
                    controller: _source,
                    label: s.source),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.learned),
                  subtitle: Text(s.learnedHint),
                  value: _learned,
                  onChanged: (value) => setState(() => _learned = value),
                ),
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
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: _required,
      textCapitalization: capitalization,
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
        level: _level.text.trim(),
        lesson: _lesson.text.trim(),
        topic: _topic.text.trim(),
        learned: _learned,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
        sourceRef: _source.text.trim(),
        content: <String, Object?>{
          'german': _german.text.trim(),
          'translation_ru': _translation.text.trim(),
          if (_isNoun) 'article': _article,
          if (_isNoun) 'plural': _plural.text.trim(),
        },
      ),
    );
  }
}
