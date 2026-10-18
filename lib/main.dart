import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_state.dart';
import 'screens/competitions_screen.dart';
import 'screens/home_screen.dart';
import 'screens/more_screen.dart';
import 'screens/teams_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();
  runApp(TouchlineApp(state: state));
}

class TouchlineApp extends StatelessWidget {
  final AppState state;
  const TouchlineApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: Builder(builder: (context) {
        final app = AppScope.of(context);
        final light = app.settings.daylight;
        SystemChrome.setSystemUIOverlayStyle(light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light);
        return MaterialApp(
          title: 'Touchline',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(light ? TLColors.daylight : TLColors.night),
          home: const Shell(),
        );
      }),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> with WidgetsBindingObserver {
  int tab = 0;
  Timer? _tick;

  static const _pages = <Widget>[HomeScreen(), CompetitionsScreen(), TeamsScreen(), MoreScreen()];

  static const _dest = [
    (Icons.stadium_outlined, Icons.stadium_rounded, 'Match day'),
    (Icons.emoji_events_outlined, Icons.emoji_events_rounded, 'Competitions'),
    (Icons.shield_outlined, Icons.shield_rounded, 'Teams'),
    (Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'More'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keeps live clocks moving on every screen.
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      final app = AppScope.read(context);
      if (app.allFixtures.any((e) => e.$2.status.name == 'live')) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) AppScope.read(context).saveNow();
  }

  void go(int i) => setState(() => tab = i);

  void _select(int i) {
    HapticFeedback.selectionClick();
    go(i);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tl;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final pages = IndexedStack(index: tab, children: _pages);
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: tab,
              onDestinationSelected: _select,
              backgroundColor: c.surface,
              indicatorColor: c.accent.withOpacity(0.18),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Icon(Icons.sports_soccer_rounded, color: c.accent, size: 30),
              ),
              destinations: [
                for (final d in _dest) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
              ],
            ),
            VerticalDivider(width: 1, color: c.line),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200), child: pages),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: pages,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: c.surface,
        indicatorColor: c.accent.withOpacity(0.18),
        onDestinationSelected: _select,
        destinations: [for (final d in _dest) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3)],
      ),
    );
  }
}
