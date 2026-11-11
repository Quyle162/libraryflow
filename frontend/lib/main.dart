import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/session.dart';
import 'core/api.dart';
import 'l10n/strings.dart';
import 'screens/account.dart';
import 'screens/books.dart';
import 'screens/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(Api(), await SharedPreferences.getInstance());
  runApp(
    ChangeNotifierProvider(create: (_) => session, child: const LibraryFlow()),
  );
  unawaited(session.restore());
}

class LibraryFlow extends StatelessWidget {
  const LibraryFlow({super.key});

  ThemeData _theme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xff174fb0),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return MaterialApp(
      // Thay Navigator khi đổi phiên để xóa toàn bộ route cần xác thực.
      key: ValueKey(session.user?['id']),
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.tr('app'),
      locale: session.locale,
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      themeMode: session.theme,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: session.starting || session.startupError != null
          ? const SplashPage()
          : session.user == null
          ? const LoginPage()
          : const LibraryShell(),
    );
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 62,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr('app'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                if (session.starting)
                  const CircularProgressIndicator()
                else ...[
                  Text(
                    context.tr(session.startupError ?? 'server_error'),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: session.restore,
                    child: Text(context.tr('retryAction')),
                  ),
                  TextButton(
                    onPressed: session.signOut,
                    child: Text(context.tr('logout')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LibraryShell extends StatefulWidget {
  const LibraryShell({super.key});
  @override
  State<LibraryShell> createState() => _LibraryShellState();
}

class _LibraryShellState extends State<LibraryShell>
    with WidgetsBindingObserver {
  int selected = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<Session>().refreshUnread());
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final librarian = context.watch<Session>().librarian;
    final destinations = <(IconData, String)>[
      (Icons.home_outlined, librarian ? 'dashboard' : 'home'),
      (Icons.menu_book_outlined, 'booksNav'),
      (Icons.swap_horiz, 'activity'),
      (Icons.person_outline, 'account'),
    ];
    final pages = [
      HomePage(
        browse: () => setState(() => selected = 1),
        notifications: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        ),
      ),
      const BooksPage(),
      const ActivityPage(),
      const AccountPage(),
    ];

    void select(int index) {
      setState(() => selected = index);
      unawaited(context.read<Session>().refreshUnread());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: selected,
                    onDestinationSelected: select,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final (icon, label) in destinations)
                        NavigationRailDestination(
                          icon: Icon(icon),
                          label: Text(tr(label)),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[selected]),
              ],
            ),
          );
        }
        return Scaffold(
          body: pages[selected],
          bottomNavigationBar: NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: select,
            destinations: [
              for (final (icon, label) in destinations)
                NavigationDestination(icon: Icon(icon), label: tr(label)),
            ],
          ),
        );
      },
    );
  }
}
