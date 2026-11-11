import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/session.dart';
import '../core/api.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key, this.initialCategory});
  final int? initialCategory;

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  final search = TextEditingController();
  String term = '';
  late int category = widget.initialCategory ?? 0;
  String sort = 'title';
  bool archived = false;
  int revision = 0;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> edit(BuildContext context, List<Json> categories) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BookForm(categories: categories)),
    );
    if (mounted && changed == true) setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final api = session.api;
    return PageFrame(
      title: session.librarian ? 'manageBooks' : 'books',
      child: DataPanel<List<Json>>(
        load: () => api.list('/categories'),
        builder: (context, categories, refreshCategories) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    children: [
                      TextField(
                        controller: search,
                        maxLength: 200,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) =>
                            setState(() => term = search.text.trim()),
                        decoration: InputDecoration(
                          labelText: context.tr('searchBooks'),
                          counterText: '',
                          suffixIcon: IconButton(
                            tooltip: context.tr('searchBooks'),
                            icon: const Icon(Icons.search),
                            onPressed: () =>
                                setState(() => term = search.text.trim()),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue:
                                  categories.any((row) => row['id'] == category)
                                  ? category
                                  : 0,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: context.tr('category'),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 0,
                                  child: Text(
                                    context.tr('allCategories'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                for (final item in categories)
                                  DropdownMenuItem(
                                    value: item['id'] as int,
                                    child: Text(
                                      item['name'].toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => category = value ?? 0),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: sort,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: context.tr('sort'),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'title',
                                  child: Text(
                                    context.tr('sortTitle'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'year',
                                  child: Text(
                                    context.tr('sortYear'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => sort = value ?? 'title'),
                            ),
                          ),
                        ],
                      ),
                      if (session.librarian)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              FilterChip(
                                label: Text(context.tr('archiveView')),
                                selected: archived,
                                onSelected: (value) =>
                                    setState(() => archived = value),
                              ),
                              FilledButton.icon(
                                onPressed: () => edit(context, categories),
                                icon: const Icon(Icons.add),
                                label: Text(context.tr('addBook')),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: DataPanel<List<Json>>(
                key: ValueKey((term, category, sort, archived, revision)),
                load: () => api.list(
                  '/books',
                  query: {
                    'q': term,
                    'sort': sort,
                    'archived': archived ? '1' : '0',
                    if (categories.any((row) => row['id'] == category))
                      'category_id': category,
                  },
                ),
                builder: (context, books, refresh) => Collection(
                  onRefresh: () {
                    refreshCategories();
                    refresh();
                  },
                  children: [
                    for (final book in books)
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: BookCover(book, width: 42, height: 58),
                          title: Text(
                            book['title'].toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            "${book['author']}\n${context.tr('available_copies')} · ${book['available_copies']}",
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookDetails(
                                  bookId: book['id'] as int,
                                  categories: categories,
                                ),
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
      ),
    );
  }
}

class BookCover extends StatelessWidget {
  const BookCover(
    this.book, {
    super.key,
    required this.width,
    required this.height,
  });
  final Json book;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final title = book['title'].toString();
    final fallback = Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(width / 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.primary, palette.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            color: palette.onPrimary,
            size: width / 3,
          ),
          if (width >= 60)
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.onPrimary,
                fontSize: width / 10,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
    final url = book['cover_image'] as String?;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url == null || url.isEmpty
          ? fallback
          : Image.network(
              context.read<Session>().api.coverUrl(url),
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class BookDetails extends StatelessWidget {
  const BookDetails({
    super.key,
    required this.bookId,
    required this.categories,
  });
  final int bookId;
  final List<Json> categories;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final api = session.api;
    return PageFrame(
      title: 'detail',
      child: DataPanel<Json>(
        load: () => api.object('/books/$bookId'),
        builder: (context, book, refresh) => Collection(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BookCover(book, width: 92, height: 130),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book['title'].toString(),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(book['author'].toString()),
                          StatusTag(book['status'].toString()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final (key, field) in [
              ('book_code', 'book_code'),
              ('category', 'category_name'),
              ('publisher', 'publisher'),
              ('published_year', 'published_year'),
              ('isbn', 'isbn'),
              ('description', 'description'),
              ('total_copies', 'total_copies'),
              ('available_copies', 'available_copies'),
            ])
              ListTile(
                title: Text(context.tr(key)),
                subtitle: Text(book[field]?.toString() ?? '—'),
              ),
            if (!session.librarian && countOf(book['available_copies']) > 0)
              ActionButton(
                label: 'borrowAction',
                icon: Icons.bookmark_add_outlined,
                success: null,
                requiresConfirmation: true,
                action: () async {
                  await api.send(
                    '/borrow-requests',
                    method: 'POST',
                    body: {'book_id': bookId},
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(context.tr('done'))));
                    Navigator.pop(context, true);
                  }
                },
              ),
            if (session.librarian)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(context.tr('editBook')),
                    onPressed: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BookForm(categories: categories, book: book),
                        ),
                      );
                      if (changed == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                  ),
                  ActionButton(
                    label: book['status'] == 'archived' ? 'restore' : 'archive',
                    icon: Icons.archive_outlined,
                    success: null,
                    requiresConfirmation: true,
                    action: () async {
                      final archived = book['status'] == 'archived';
                      await api.send(
                        archived ? '/books/$bookId/restore' : '/books/$bookId',
                        method: archived ? 'PATCH' : 'DELETE',
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class BookForm extends StatelessWidget {
  const BookForm({super.key, required this.categories, this.book});
  final List<Json> categories;
  final Json? book;

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return EditFields(
      title: book == null ? 'addBook' : 'editBook',
      initial: book ?? const {},
      categories: categories,
      fields: const [
        (key: 'book_code', optional: false, max: 32),
        (key: 'title', optional: false, max: 200),
        (key: 'author', optional: false, max: 160),
        (key: 'publisher', optional: false, max: 160),
        (key: 'published_year', optional: false, max: 4),
        (key: 'isbn', optional: true, max: 20),
        (key: 'description', optional: true, max: 5000),
        (key: 'cover_image', optional: true, max: 500),
        (key: 'total_copies', optional: false, max: 6),
      ],
      save: (data) async {
        await api.send(
          book == null ? '/books' : "/books/${book!['id']}",
          method: book == null ? 'POST' : 'PUT',
          body: data,
        );
      },
    );
  }
}
