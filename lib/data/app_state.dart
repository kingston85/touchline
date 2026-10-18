import 'dart:async';

import 'package:flutter/material.dart';

import '../core/demo.dart';
import '../core/standings.dart';
import 'models.dart';
import 'storage.dart';

class Settings {
  String organizer = '';
  bool daylight = false;
  String defaultFormation = '4-4-2';

  Map<String, dynamic> toJson() => {'organizer': organizer, 'daylight': daylight, 'defaultFormation': defaultFormation};

  void load(Map<String, dynamic> j) {
    organizer = j['organizer'] as String? ?? organizer;
    daylight = j['daylight'] as bool? ?? daylight;
    defaultFormation = j['defaultFormation'] as String? ?? defaultFormation;
  }
}

class AppState extends ChangeNotifier {
  final Settings settings = Settings();
  final List<Team> teams = [];
  final List<Competition> competitions = [];
  bool hasDemo = false;

  bool _loaded = false;
  Timer? _timer;

  Future<void> init() async {
    final data = await Storage.load();
    if (data == null) {
      loadDemo();
    } else {
      _fromJson(data);
    }
    _loaded = true;
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_loaded) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), saveNow);
  }

  Future<void> saveNow() async {
    _timer?.cancel();
    try {
      await Storage.save(toJson());
    } catch (_) {}
  }

  void update(VoidCallback f) {
    f();
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'app': 'touchline',
        'version': 1,
        'settings': settings.toJson(),
        'hasDemo': hasDemo,
        'teams': [for (final t in teams) t.toJson()],
        'competitions': [for (final c in competitions) c.toJson()],
      };

  void _fromJson(Map<String, dynamic> j) {
    settings.load((j['settings'] as Map?)?.cast<String, dynamic>() ?? const {});
    hasDemo = j['hasDemo'] as bool? ?? false;
    List<Map<String, dynamic>> list(String k) => [for (final e in (j[k] as List? ?? const [])) (e as Map).cast<String, dynamic>()];
    teams
      ..clear()
      ..addAll(list('teams').map(Team.fromJson));
    competitions
      ..clear()
      ..addAll(list('competitions').map(Competition.fromJson));
  }

  void restore(Map<String, dynamic> data) {
    _fromJson(data);
    notifyListeners();
  }

  // ---------------- Lookups ----------------

  Team? team(String? id) {
    if (id == null) return null;
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  String teamName(String? id, [String fallback = 'TBD']) => team(id)?.name ?? fallback;

  Map<String, String> get names => {for (final t in teams) t.id: t.name};

  Competition? competition(String id) {
    for (final c in competitions) {
      if (c.id == id) return c;
    }
    return null;
  }

  (Team, Player)? findPlayer(String? playerId) {
    if (playerId == null) return null;
    for (final t in teams) {
      final p = t.player(playerId);
      if (p != null) return (t, p);
    }
    return null;
  }

  String playerName(String? id, {bool short = false}) {
    final f = findPlayer(id);
    if (f == null) return 'Unknown';
    return short ? f.$2.shortName : f.$2.name;
  }

  /// Every fixture across competitions, with its competition.
  Iterable<(Competition, Fixture)> get allFixtures sync* {
    for (final c in competitions.where((c) => !c.archived)) {
      for (final f in c.matches) {
        yield (c, f);
      }
    }
  }

  List<Standing> table(Competition c, {String? group, TableView view = TableView.overall}) {
    if (group != null) {
      return buildTable(c, c.groups[group] ?? const [], c.matches.where((m) => m.stage == Stage.group && m.group == group),
          view: view, names: names);
    }
    return buildTable(c, c.teamIds, c.matches.where((m) => m.stage == Stage.league), view: view, names: names);
  }

  /// Call after any result is entered or edited.
  void resultChanged(Competition c, Fixture f) {
    f.syncScoreFromEvents();
    advanceKnockout(c);
    notifyListeners();
  }

  void deleteTeam(Team t) {
    teams.remove(t);
    for (final c in competitions) {
      c.teamIds.remove(t.id);
    }
    notifyListeners();
  }

  void clearDemo() {
    competitions.removeWhere((c) => c.organizer == demoOrganizer);
    teams.removeWhere((t) => t.contact == demoContact);
    hasDemo = false;
    notifyListeners();
  }

  void loadDemo() {
    final d = buildDemo();
    teams.addAll(d.$1);
    competitions.addAll(d.$2);
    hasDemo = true;
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget as AppScope).notifier!;
}
