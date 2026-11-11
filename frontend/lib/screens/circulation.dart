import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/session.dart';
import '../core/api.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';

enum CirculationView { requests, active, history, renewals, overdue }

class CirculationPage extends StatelessWidget {
  const CirculationPage({super.key, required this.view});
  final CirculationView view;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final librarian = session.librarian;
    final records = librarian ? '/borrow-records' : '/borrow-records/my';
    final (title, path) = switch (view) {
      CirculationView.requests => (
        librarian ? 'requests' : 'myRequests',
        '/borrow-requests',
      ),
      CirculationView.active => ('loans', records),
      CirculationView.history => ('history', records),
      CirculationView.renewals => ('renewals', '/renewal-requests'),
      CirculationView.overdue => ('overdueList', records),
    };
    return PageFrame(
      title: title,
      child: DataPanel<List<Json>>(
        load: () async {
          final list = await session.api.list(path);
          return list
              .where(
                (item) => switch (view) {
                  CirculationView.active => item['status'] == 'active',
                  CirculationView.history => true,
                  CirculationView.overdue => item['loan_state'] == 'overdue',
                  _ => true,
                },
              )
              .toList();
        },
        builder: (context, items, refresh) => Collection(
          onRefresh: refresh,
          children: [
            for (final item in items)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text(item['title'].toString()),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (librarian) Text(item['full_name'].toString()),
                      Text(
                        dateOf(context, item['due_at'] ?? item['requested_at']),
                      ),
                      StatusTag(displayStatus(item)),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CirculationDetails(
                          title: title,
                          item: item,
                          view: view,
                          path: path,
                        ),
                      ),
                    );
                    if (context.mounted && changed == true) {
                      refresh();
                      await session.refreshUnread();
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String displayStatus(Json item) {
  final status = (item['loan_state'] ?? item['status']).toString();
  return status == 'active' ? 'borrowed' : status;
}

class CirculationDetails extends StatelessWidget {
  const CirculationDetails({
    super.key,
    required this.title,
    required this.item,
    required this.view,
    required this.path,
  });
  final String title;
  final Json item;
  final CirculationView view;
  final String path;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final request =
        view == CirculationView.requests || view == CirculationView.renewals;
    final canReview =
        session.librarian && request && item['status'] == 'pending';
    final canReturn =
        session.librarian && !request && item['status'] == 'active';
    final canRenew =
        !session.librarian &&
        !request &&
        item['status'] == 'active' &&
        item['loan_state'] != 'overdue' &&
        countOf(item['renewal_count']) == 0 &&
        countOf(item['renewal_pending']) == 0;

    Future<void> update(
      String endpoint, {
      String method = 'PATCH',
      Json? body,
    }) async {
      await session.api.send(endpoint, method: method, body: body);
      if (context.mounted) Navigator.pop(context, true);
    }

    return PageFrame(
      title: title,
      child: Collection(
        children: [
          Card(
            child: ListTile(
              title: Text(
                item['title'].toString(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Align(
                alignment: Alignment.centerLeft,
                child: StatusTag(displayStatus(item)),
              ),
            ),
          ),
          if (session.librarian)
            for (final field in ['full_name', 'student_code', 'email'])
              if (item[field] != null)
                ListTile(
                  title: Text(context.tr(field)),
                  subtitle: Text(item[field].toString()),
                ),
          for (final field in [
            'requested_at',
            'reviewed_at',
            'borrowed_at',
            'due_at',
            'returned_at',
          ])
            if (item[field] != null)
              ListTile(
                title: Text(context.tr(field)),
                subtitle: Text(dateOf(context, item[field])),
              ),
          if (item['rejection_reason'] case final String reason)
            ListTile(
              title: Text(context.tr('reason')),
              subtitle: Text(
                reason == 'Phiếu đã trả'
                    ? context.tr('systemReturnReason')
                    : reason,
              ),
            ),
          if (item['overdue_days'] != null && countOf(item['overdue_days']) > 0)
            ListTile(
              title: Text(context.tr('overdue_days')),
              subtitle: Text(item['overdue_days'].toString()),
            ),
          if (item['renewal_count'] != null)
            ListTile(
              title: Text(context.tr('renewal_count')),
              subtitle: Text("${item['renewal_count']}/1"),
            ),
          if (canReview)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionButton(
                  label: 'approve',
                  requiresConfirmation: true,
                  success: null,
                  action: () => update("$path/${item['id']}/approve"),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.close),
                  label: Text(context.tr('reject')),
                  onPressed: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditFields(
                          title: 'reject',
                          fields: const [
                            (key: 'reason', optional: true, max: 500),
                          ],
                          save: (data) async {
                            await session.api.send(
                              "$path/${item['id']}/reject",
                              method: 'PATCH',
                              body: data,
                            );
                          },
                        ),
                      ),
                    );
                    if (changed == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                ),
              ],
            ),
          if (canReturn)
            ActionButton(
              label: 'returnAction',
              requiresConfirmation: true,
              icon: Icons.assignment_return_outlined,
              success: null,
              action: () => update("$path/${item['id']}/return"),
            ),
          if (canRenew)
            ActionButton(
              label: 'renewAction',
              requiresConfirmation: true,
              icon: Icons.update,
              success: null,
              action: () => update(
                '/renewal-requests',
                method: 'POST',
                body: {'borrow_record_id': item['id']},
              ),
            ),
        ],
      ),
    );
  }
}
