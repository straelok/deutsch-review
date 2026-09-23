import 'package:flutter/material.dart';

import '../../domain/id_generator.dart';
import '../../domain/learning_item.dart';
import '../../domain/repositories/learning_item_repository.dart';

class DictionaryMaterialPage extends StatefulWidget {
  const DictionaryMaterialPage({required this.repository, super.key});

  final LearningItemRepository repository;

  @override
  State<DictionaryMaterialPage> createState() => _MaterialPageState();
}

class _MaterialPageState extends State<DictionaryMaterialPage> {
  List<LearningItem> _items = const [];
  Object? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    'Material',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    '${_items.length} Einträge aus deinem DAA-Kurs',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              FilledButton.icon(
                key: const Key('add-material'),
                onPressed: _loading ? null : () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Hinzufügen'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text('Das Material konnte nicht geladen werden.'),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _reload, child: const Text('Erneut laden')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
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
            Text(
              'Noch keine Wörter',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Füge den bereits gelernten Stoff aus deinem Kurs hinzu.',
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: CircleAvatar(
              child: Icon(
                item.type == LearningItemType.noun
                    ? Icons.text_fields
                    : Icons.translate,
              ),
            ),
            title: Text(_displayGerman(item)),
            subtitle: Text(
              '${item.content['translation_ru']}  •  '
              '${item.level} · Lektion ${item.lesson} · ${item.topic}',
            ),
            trailing: IconButton(
              key: Key('edit-${item.id}'),
              tooltip: 'Bearbeiten',
              onPressed: () => _openEditor(item),
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        );
      },
    );
  }

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
      builder: (context) => _LearningItemEditor(item: item),
    );
    if (saved == null) return;

    try {
      await widget.repository.save(saved);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item == null ? 'Eintrag hinzugefügt.' : 'Änderungen gespeichert.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Der Eintrag konnte nicht gespeichert werden.'),
        ),
      );
    }
  }

  static String _displayGerman(LearningItem item) {
    final german = item.content['german'] as String? ?? '';
    final article = item.content['article'] as String?;
    if (item.type == LearningItemType.noun && article != null) {
      return '$article $german';
    }
    return german;
  }
}

class _LearningItemEditor extends StatefulWidget {
  const _LearningItemEditor({this.item});

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
    _translation = TextEditingController(
      text: item?.content['translation_ru'] as String?,
    );
    _plural = TextEditingController(text: item?.content['plural'] as String?);
    _level = TextEditingController(text: item?.level ?? 'A1.1');
    _lesson = TextEditingController(text: item?.lesson);
    _topic = TextEditingController(text: item?.topic);
    _source = TextEditingController(
      text: item?.sourceRef ?? 'DAA / Schritte plus Neu',
    );
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
    return AlertDialog(
      title: Text(
        widget.item == null ? 'Material hinzufügen' : 'Material bearbeiten',
      ),
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
                  decoration: const InputDecoration(labelText: 'Typ'),
                  items: const [
                    DropdownMenuItem(
                      value: LearningItemType.word,
                      child: Text('Wort'),
                    ),
                    DropdownMenuItem(
                      value: LearningItemType.noun,
                      child: Text('Nomen'),
                    ),
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
                    decoration: const InputDecoration(labelText: 'Artikel'),
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
                TextFormField(
                  key: const Key('german'),
                  controller: _german,
                  decoration: InputDecoration(
                    labelText: _isNoun ? 'Nomen' : 'Deutsches Wort',
                  ),
                  validator: _required,
                  textCapitalization: _isNoun
                      ? TextCapitalization.words
                      : TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                if (_isNoun) ...[
                  TextFormField(
                    key: const Key('plural'),
                    controller: _plural,
                    decoration: const InputDecoration(labelText: 'Plural'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  key: const Key('translation'),
                  controller: _translation,
                  decoration: const InputDecoration(labelText: 'Bedeutung'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('level'),
                        controller: _level,
                        decoration: const InputDecoration(labelText: 'Niveau'),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const Key('lesson'),
                        controller: _lesson,
                        decoration: const InputDecoration(labelText: 'Lektion'),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('topic'),
                  controller: _topic,
                  decoration: const InputDecoration(labelText: 'Thema'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('source'),
                  controller: _source,
                  decoration: const InputDecoration(labelText: 'Quelle'),
                  validator: _required,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Im Kurs gelernt'),
                  subtitle: const Text(
                    'Nur gelernter Stoff wird später wiederholt.',
                  ),
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const Key('save-material'),
          onPressed: _submit,
          child: const Text('Speichern'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Pflichtfeld' : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final previous = widget.item;
    final now = DateTime.now().toUtc();
    final content = <String, Object?>{
      'german': _german.text.trim(),
      'translation_ru': _translation.text.trim(),
      if (_isNoun) 'article': _article,
      if (_isNoun) 'plural': _plural.text.trim(),
    };
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
        content: content,
      ),
    );
  }
}
