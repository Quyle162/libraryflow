import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/session.dart';
import '../core/api.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';
import 'circulation.dart';
import 'management.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.notifications,
    required this.browse,
  });
  final VoidCallback notifications;
  final VoidCallback browse;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final scheme = Theme.of(context).colorScheme;
    final tr = context.tr;
    final librarian = session.librarian;
    final banner = Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(librarian ? 'dashboard' : 'tagline'),
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    session.user!['full_name'].toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.auto_stories_outlined,
              size: 46,
              color: scheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
    final links = <Widget>[
      if (librarian) ...[
        const PageLink(
          label: 'categories',
          icon: Icons.category_outlined,
          page: CategoriesPage(),
        ),
        const PageLink(
          label: 'readers',
          icon: Icons.people_outline,
          page: ReadersPage(),
        ),
        const PageLink(
          label: 'statistics',
          icon: Icons.bar_chart,
          page: StatisticsPage(),
        ),
        const PageLink(
          label: 'overdueList',
          icon: Icons.warning_amber_outlined,
          page: CirculationPage(view: CirculationView.overdue),
        ),
      ] else ...[
        Card(
          child: ListTile(
            leading: const Icon(Icons.search),
            title: Text(tr('searchBooks')),
            trailing: const Icon(Icons.chevron_right),
            onTap: browse,
          ),
        ),
        const PageLink(
          label: 'loans',
          icon: Icons.bookmark_outline,
          page: CirculationPage(view: CirculationView.active),
        ),
        const PageLink(
          label: 'myRequests',
          icon: Icons.assignment_outlined,
          page: CirculationPage(view: CirculationView.requests),
        ),
      ],
    ];

    return PageFrame(
      title: librarian ? 'dashboard' : 'home',
      actions: [
        IconButton(
          onPressed: notifications,
          tooltip: tr('notifications'),
          icon: Badge(
            isLabelVisible: session.unread > 0,
            label: Text(session.unread.toString()),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
      ],
      child: librarian
          ? StatisticsPanel(banner: banner, links: links)
          : Collection(children: [banner, ...links]),
    );
  }
}

class PageLink extends StatelessWidget {
  const PageLink({
    super.key,
    required this.label,
    required this.icon,
    required this.page,
  });
  final String label;
  final IconData icon;
  final Widget page;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(context.tr(label)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    ),
  );
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final librarian = context.watch<Session>().librarian;
    return PageFrame(
      title: 'activity',
      child: Collection(
        children: [
          PageLink(
            label: librarian ? 'requests' : 'myRequests',
            icon: Icons.pending_actions,
            page: const CirculationPage(view: CirculationView.requests),
          ),
          const PageLink(
            label: 'loans',
            icon: Icons.bookmark_outline,
            page: CirculationPage(view: CirculationView.active),
          ),
          const PageLink(
            label: 'renewals',
            icon: Icons.update,
            page: CirculationPage(view: CirculationView.renewals),
          ),
          const PageLink(
            label: 'history',
            icon: Icons.history,
            page: CirculationPage(view: CirculationView.history),
          ),
          if (librarian)
            const PageLink(
              label: 'overdueList',
              icon: Icons.warning_amber_outlined,
              page: CirculationPage(view: CirculationView.overdue),
            ),
        ],
      ),
    );
  }
}

class MetricTiles extends StatelessWidget {
  const MetricTiles({super.key, required this.data});
  final Json data;

  static const _metrics = [
    ('titles', 'titles', Icons.menu_book),
    ('copies', 'copies', Icons.library_books_outlined),
    ('borrowed', 'borrowedMetric', Icons.bookmark_outline),
    ('readers', 'readersMetric', Icons.people_outline),
    ('pending', 'pendingMetric', Icons.pending_actions),
    ('overdue', 'overdueMetric', Icons.warning_amber_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.colorScheme;
    return SizedBox(
      height: 144,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (key, title, icon) in _metrics)
            SizedBox(
              width: 145,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon,
                        color: key == 'overdue'
                            ? palette.error
                            : palette.primary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data[key].toString(),
                        style: theme.textTheme.headlineSmall,
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            context.tr(title),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const PageFrame(title: 'statistics', child: StatisticsPanel());
}

typedef StatisticsData = (Json, List<Json>, List<Json>, List<Json>);

class StatisticsPanel extends StatelessWidget {
  const StatisticsPanel({super.key, this.banner, this.links = const []});
  final Widget? banner;
  final List<Widget> links;

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return DataPanel<StatisticsData>(
      load: () => (
        api.object('/statistics/overview'),
        api.list('/statistics/borrow-by-month'),
        api.list('/statistics/books-by-category'),
        api.list('/statistics/popular-books'),
      ).wait,
      builder: (context, data, refresh) {
        final (overview, months, categories, popular) = data;
        return Collection(
          onRefresh: refresh,
          children: [
            ?banner,
            MetricTiles(data: overview),
            ...links,
            ChartCard(title: 'monthly', child: MonthlyChart(months)),
            ChartCard(title: 'distribution', child: CategoryChart(categories)),
            ChartCard(
              title: 'popular',
              child: Column(
                children: [
                  if (popular.isEmpty) Text(context.tr('empty')),
                  for (final book in popular)
                    ListTile(
                      title: Text(book['title'].toString()),
                      trailing: Text(book['total'].toString()),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(title),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    ),
  );
}

class MonthlyChart extends StatelessWidget {
  const MonthlyChart(this.months, {super.key});
  final List<Json> months;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return Text(context.tr('empty'));
    final palette = Theme.of(context).colorScheme;
    final max = months.fold<int>(
      0,
      (value, row) =>
          countOf(row['total']) > value ? countOf(row['total']) : value,
    );
    final step = ((max + 4) ~/ 5).clamp(1, max + 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('count')),
        const SizedBox(height: 8),
        SizedBox(
          height: 205,
          child: BarChart(
            BarChartData(
              maxY: (max == 0 ? 1 : max).toDouble(),
              barGroups: [
                for (var index = 0; index < months.length; index++)
                  BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: countOf(months[index]['total']).toDouble(),
                        color: palette.primary,
                        width: 12,
                      ),
                    ],
                  ),
              ],
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: step,
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 31,
                    interval: step,
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 25,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index.isOdd || index < 0 || index >= months.length) {
                        return const SizedBox.shrink();
                      }
                      final parts = months[index]['month'].toString().split(
                        '-',
                      );
                      return Text(
                        "${parts.last}/${parts.first.substring(2)}",
                        style: Theme.of(context).textTheme.labelSmall,
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    "${months[group.x]['month']} · ${rod.toY.toInt()}",
                    TextStyle(
                      color: palette.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  getTooltipColor: (_) => palette.inverseSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CategoryChart extends StatelessWidget {
  const CategoryChart(this.categories, {super.key});
  final List<Json> categories;

  @override
  Widget build(BuildContext context) {
    if (!categories.any((row) => countOf(row['total']) > 0)) {
      return Text(context.tr('empty'));
    }
    final palette = Theme.of(context).colorScheme;
    final colors = [
      palette.primary,
      palette.tertiary,
      palette.secondary,
      const Color(0xff22846f),
      const Color(0xffb06600),
      const Color(0xff99529a),
    ];
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 34,
              sectionsSpace: 3,
              sections: [
                for (var i = 0; i < categories.length; i++)
                  if (countOf(categories[i]['total']) > 0)
                    PieChartSectionData(
                      value: countOf(categories[i]['total']).toDouble(),
                      color: colors[i % colors.length],
                      showTitle: false,
                      radius: 44,
                    ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < categories.length; i++)
          ListTile(
            dense: true,
            leading: Icon(
              Icons.circle,
              size: 14,
              color: colors[i % colors.length],
            ),
            title: Text(categories[i]['name'].toString()),
            trailing: Text(categories[i]['total'].toString()),
          ),
      ],
    );
  }
}
