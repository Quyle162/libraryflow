import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/session.dart';
import '../core/api.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';
import 'books.dart';
import 'circulation.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return PageFrame(
      title: 'categories',
      child: DataPanel<List<Json>>(
        load: () => api.list('/categories'),
        builder: (context, categories, refresh) {
          Future<void> edit([Json? category]) async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => EditFields(
                  title: category == null ? 'addCategory' : 'editCategory',
                  initial: category ?? const {},
                  fields: const [
                    (key: 'name', optional: false, max: 100),
                    (key: 'description', optional: true, max: 500),
                  ],
                  save: (data) async {
                    await api.send(
                      category == null
                          ? '/categories'
                          : "/categories/${category['id']}",
                      method: category == null ? 'POST' : 'PUT',
                      body: data,
                    );
                  },
                ),
              ),
            );
            if (context.mounted && changed == true) refresh();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => edit(),
                    icon: const Icon(Icons.add),
                    label: Text(context.tr('addCategory')),
                  ),
                ),
              ),
              Expanded(
                child: Collection(
                  onRefresh: refresh,
                  children: [
                    for (final category in categories)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.category_outlined),
                                title: Text(category['name'].toString()),
                                subtitle: Text(
                                  category['description'].toString(),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BooksPage(
                                      initialCategory: category['id'] as int,
                                    ),
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => edit(category),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: Text(context.tr('edit')),
                                  ),
                                  ActionButton(
                                    label: 'remove',
                                    icon: Icons.delete_outline,
                                    success: null,
                                    requiresConfirmation: true,
                                    action: () async {
                                      await api.send(
                                        "/categories/${category['id']}",
                                        method: 'DELETE',
                                      );
                                      if (context.mounted) refresh();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ReadersPage extends StatefulWidget {
  const ReadersPage({super.key});

  @override
  State<ReadersPage> createState() => _ReadersPageState();
}

class _ReadersPageState extends State<ReadersPage> {
  final search = TextEditingController();
  String term = '';
  int revision = 0;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return PageFrame(
      title: 'readers',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: search,
              maxLength: 200,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => setState(() => term = search.text.trim()),
              decoration: InputDecoration(
                labelText: context.tr('searchReaders'),
                counterText: '',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: context.tr('searchReaders'),
                  onPressed: () => setState(() => term = search.text.trim()),
                ),
              ),
            ),
          ),
          Expanded(
            child: DataPanel<List<Json>>(
              key: ValueKey((term, revision)),
              load: () => api.list('/users', query: {'q': term}),
              builder: (context, readers, refresh) => Collection(
                onRefresh: refresh,
                children: [
                  for (final reader in readers)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(reader['full_name'].toString()),
                        subtitle: Text(
                          "${reader['student_code'] ?? '—'} · ${context.tr('active_loans')}: ${reader['active_loans']}",
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReaderDetails(userId: reader['id'] as int),
                            ),
                          );
                          if (mounted && changed == true) {
                            setState(() => revision++);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReaderDetails extends StatelessWidget {
  const ReaderDetails({super.key, required this.userId});
  final int userId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return PageFrame(
      title: 'readers',
      child: DataPanel<Json>(
        load: () => api.object('/users/$userId'),
        builder: (context, user, _) {
          final records = rows(user['records']);
          final locked = user['status'] == 'locked';
          return Collection(
            children: [
              for (final key in [
                'full_name',
                'student_code',
                'username',
                'email',
                'active_loans',
              ])
                ListTile(
                  title: Text(context.tr(key)),
                  subtitle: Text(user[key]?.toString() ?? '—'),
                ),
              ListTile(
                title: Text(context.tr('status')),
                trailing: StatusTag(user['status'].toString()),
              ),
              ActionButton(
                label: locked ? 'unlock' : 'lock',
                icon: locked ? Icons.lock_open : Icons.lock_outline,
                success: null,
                requiresConfirmation: true,
                action: () async {
                  await api.send(
                    '/users/$userId/status',
                    method: 'PATCH',
                    body: {'status': locked ? 'active' : 'locked'},
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 22, 12, 8),
                child: Text(
                  context.tr('history'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (records.isEmpty) ListTile(title: Text(context.tr('empty'))),
              for (final record in records)
                Card(
                  child: ListTile(
                    title: Text(record['title'].toString()),
                    subtitle: Text(dateOf(context, record['borrowed_at'])),
                    trailing: StatusTag(displayStatus(record)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
