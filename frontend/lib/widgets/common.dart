import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../l10n/strings.dart';

String dateOf(BuildContext context, dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null
      ? '—'
      : DateFormat.yMd(context.tr.locale.languageCode)
            .add_Hm()
            .format(date.toLocal());
}

String failureOf(Object? error) =>
    error is ApiFailure ? error.code : 'server_error';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr(title)), actions: actions),
    body: SafeArea(child: child),
  );
}

class DataPanel<T> extends StatefulWidget {
  const DataPanel({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback) builder;

  @override
  State<DataPanel<T>> createState() => _DataPanelState<T>();
}

class _DataPanelState<T> extends State<DataPanel<T>> {
  late Future<T> _future = widget.load();
  void refresh() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 12),
                Text(
                  context.tr(failureOf(snapshot.error)),
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: refresh,
                  child: Text(context.tr('retryAction')),
                ),
              ],
            ),
          ),
        );
      }
      return widget.builder(context, snapshot.requireData, refresh);
    },
  );
}

class Collection extends StatelessWidget {
  const Collection({super.key, required this.children, this.onRefresh});
  final List<Widget> children;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final child in children)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 70),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 46,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(context.tr('empty')),
              ],
            ),
          ),
      ],
    );
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: () async => onRefresh!(), child: list);
  }
}

class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.action,
    this.icon,
    this.success = 'done',
    this.requiresConfirmation = false,
  });
  final String label;
  final Future<void> Function() action;
  final IconData? icon;
  final String? success;
  final bool requiresConfirmation;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool busy = false;

  Future<void> run() async {
    if (widget.requiresConfirmation && !await confirm(context, widget.label)) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final tr = context.tr;
    final success = widget.success;
    try {
      await widget.action();
      if (success != null && messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(tr(success))));
      }
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(tr(failureOf(error)))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy ? null : run,
    icon: busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(widget.icon ?? Icons.check),
    label: Text(context.tr(widget.label)),
  );
}

Future<bool> confirm(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr(title)),
        content: Text(context.tr('confirmHint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    ) ??
    false;

class StatusTag extends StatelessWidget {
  const StatusTag(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      'overdue' ||
      'rejected' ||
      'locked' => (palette.errorContainer, palette.onErrorContainer),
      'due_soon' ||
      'pending' => (const Color(0xffffe29b), const Color(0xff493400)),
      _ => (palette.secondaryContainer, palette.onSecondaryContainer),
    };
    return Chip(
      backgroundColor: background,
      side: BorderSide.none,
      label: Text(context.tr(status), style: TextStyle(color: foreground)),
    );
  }
}

typedef FieldSpec = ({String key, bool optional, int max});

class EditFields extends StatefulWidget {
  const EditFields({
    super.key,
    required this.title,
    required this.fields,
    required this.save,
    this.initial = const {},
    this.categories,
  });
  final String title;
  final List<FieldSpec> fields;
  final Json initial;
  final Future<void> Function(Json) save;
  final List<Json>? categories;

  @override
  State<EditFields> createState() => _EditFieldsState();
}

class _EditFieldsState extends State<EditFields> {
  final form = GlobalKey<FormState>();
  late final controllers = {
    for (final field in widget.fields)
      field.key: TextEditingController(
        text: widget.initial[field.key]?.toString() ?? '',
      ),
  };
  late int? category = widget.initial['category_id'] as int?;

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? validate(FieldSpec field, String value) {
    final tr = context.tr;
    final key = field.key;
    if (!field.optional && value.isEmpty) return tr('required');
    if (value.length > field.max) return tr('tooLong');
    if (key == 'email' &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return tr('emailInvalid');
    }
    if (key == 'published_year' || key == 'total_copies') {
      final number = int.tryParse(value);
      final isYear = key == 'published_year';
      if (number == null ||
          number < (isYear ? 1000 : 0) ||
          number > (isYear ? DateTime.now().year : 100000)) {
        return tr('number');
      }
    }
    if (key.endsWith('_password') &&
        (utf8.encode(value).length > 72 ||
            (key == 'new_password' && value.length < 8))) {
      return tr('passwordLength');
    }
    if (key == 'cover_image' &&
        value.isNotEmpty &&
        !RegExp(r'^/covers/LF\d{3}\.webp$').hasMatch(value)) {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          uri.host.isEmpty ||
          !['https', 'http'].contains(uri.scheme)) {
        return tr('invalidUrl');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: widget.title,
    child: Form(
      key: form,
      child: Collection(
        children: [
          for (final field in widget.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: controllers[field.key],
                decoration: InputDecoration(labelText: context.tr(field.key)),
                obscureText: field.key.endsWith('_password'),
                keyboardType: switch (field.key) {
                  'total_copies' || 'published_year' => TextInputType.number,
                  'email' => TextInputType.emailAddress,
                  'cover_image' => TextInputType.url,
                  _ => TextInputType.text,
                },
                maxLines: field.key == 'description' ? 4 : 1,
                validator: (value) => validate(
                  field,
                  field.key.endsWith('_password')
                      ? value ?? ''
                      : value?.trim() ?? '',
                ),
              ),
            ),
          if (widget.categories case final categories?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<int>(
                initialValue: category,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.tr('category')),
                items: [
                  for (final item in categories)
                    DropdownMenuItem(
                      value: item['id'] as int,
                      child: Text(
                        item['name'].toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => category = value,
                validator: (value) =>
                    value == null ? context.tr('required') : null,
              ),
            ),
          ActionButton(
            label: 'save',
            success: null,
            action: () async {
              if (!form.currentState!.validate()) return;
              final data = <String, dynamic>{
                for (final entry in controllers.entries)
                  entry.key: entry.key.endsWith('_password')
                      ? entry.value.text
                      : entry.value.text.trim(),
                if (widget.categories != null) 'category_id': category,
              };
              await widget.save(data);
              if (context.mounted) Navigator.pop(context, true);
            },
          ),
        ],
      ),
    ),
  );
}
