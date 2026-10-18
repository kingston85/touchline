// Touchline data model. Everything serialises to JSON for on-device storage.

int _seq = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}';

int _i(Object? v, [int d = 0]) => v == null ? d : (v as num).toInt();
int? _in(Object? v) => v == null ? null : (v as num).toInt();
DateTime? _tn(Object? v) => v == null ? null : DateTime.tryParse(v as String);
T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((e) => e.name == name, orElse: () => fallback);
List<Map<String, dynamic>> _list(Object? v) => [for (final e in (v as List? ?? const [])) (e as Map).cast<String, dynamic>()];
List<String> _strs(Object? v) => [for (final e in (v as List? ?? const [])) e as String];

// ---------------------------------------------------------------------------
// Teams and players
// ---------------------------------------------------------------------------

enum Position { gk, df, mf, fw }

extension PositionX on Position {
  String get short => const ['GK', 'DF', 'MF', 'FW'][index];
  String get label => const ['Goalkeeper', 'Defender', 'Midfielder', 'Forward'][index];
}

class Player {
  final String id;
  String name;
  int? number;
  Position position;
  DateTime? birth;
  String nationality;
  bool captain;

  Player({
    required this.id,
    required this.name,
    this.number,
    this.position = Position.mf,
    this.birth,
    this.nationality = '',
    this.captain = false,
  });

  String get shortName {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return name;
    return '${parts.first[0]}. ${parts.sublist(1).join(' ')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'number': number,
        'position': position.name,
        'birth': birth?.toIso8601String(),
        'nationality': nationality,
        'captain': captain,
      };

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        number: _in(j['number']),
        position: _enum(Position.values, j['position'], Position.mf),
        birth: _tn(j['birth']),
        nationality: j['nationality'] as String? ?? '',
        captain: j['captain'] as bool? ?? false,
      );
}

class Team {
  final String id;
  String name;
  String short; // 3 letters for scoreboards
  int color1; // ARGB
  int color2;
  String ground;
  String city;
  String coach;
  String contact;
  int? founded;
  final List<Player> players;

  Team({
    required this.id,
    required this.name,
    String? short,
    this.color1 = 0xFF3BE37F,
    this.color2 = 0xFFFFFFFF,
    this.ground = '',
    this.city = '',
    this.coach = '',
    this.contact = '',
    this.founded,
    List<Player>? players,
  })  : short = short ?? defaultShort(name),
        players = players ?? [];

  static String defaultShort(String name) {
    final words = name.trim().toUpperCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'TBD';
    if (words.length == 1) return words.first.padRight(3, 'X').substring(0, 3);
    if (words.length == 2) return (words[0].substring(0, words[0].length >= 2 ? 2 : 1) + words[1][0]).padRight(3, 'X').substring(0, 3);
    return words.take(3).map((w) => w[0]).join();
  }

  Player? player(String? id) {
    if (id == null) return null;
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'short': short,
        'color1': color1,
        'color2': color2,
        'ground': ground,
        'city': city,
        'coach': coach,
        'contact': contact,
        'founded': founded,
        'players': [for (final p in players) p.toJson()],
      };

  factory Team.fromJson(Map<String, dynamic> j) => Team(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        short: j['short'] as String?,
        color1: _i(j['color1'], 0xFF3BE37F),
        color2: _i(j['color2'], 0xFFFFFFFF),
        ground: j['ground'] as String? ?? '',
        city: j['city'] as String? ?? '',
        coach: j['coach'] as String? ?? '',
        contact: j['contact'] as String? ?? '',
        founded: _in(j['founded']),
        players: _list(j['players']).map(Player.fromJson).toList(),
      );
}

// ---------------------------------------------------------------------------
// Matches
// ---------------------------------------------------------------------------

enum MatchStatus { scheduled, live, finished, postponed, cancelled }

extension MatchStatusX on MatchStatus {
  String get label => const ['Scheduled', 'Live', 'Full time', 'Postponed', 'Cancelled'][index];
}

enum EventType { goal, penaltyGoal, ownGoal, penaltyMiss, yellow, secondYellow, red, sub }

extension EventTypeX on EventType {
  String get label => const ['Goal', 'Penalty goal', 'Own goal', 'Missed penalty', 'Yellow card', 'Second yellow', 'Red card', 'Substitution'][index];
  bool get isGoal => this == EventType.goal || this == EventType.penaltyGoal || this == EventType.ownGoal;
  bool get isCard => this == EventType.yellow || this == EventType.secondYellow || this == EventType.red;
}

class MatchEvent {
  final String id;
  EventType type;
  bool home; // side the event belongs to (for own goals: the side credited with the goal)
  int minute;
  int stoppage; // e.g. 45+2 → minute 45, stoppage 2
  String? playerId; // scorer / booked player / player coming ON
  String? otherId; // assist / player going OFF
  String note;

  MatchEvent({
    required this.id,
    required this.type,
    required this.home,
    required this.minute,
    this.stoppage = 0,
    this.playerId,
    this.otherId,
    this.note = '',
  });

  String get clock => stoppage > 0 ? "$minute+$stoppage'" : "$minute'";
  int get sortKey => minute * 100 + stoppage;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'home': home,
        'minute': minute,
        'stoppage': stoppage,
        'playerId': playerId,
        'otherId': otherId,
        'note': note,
      };

  factory MatchEvent.fromJson(Map<String, dynamic> j) => MatchEvent(
        id: j['id'] as String,
        type: _enum(EventType.values, j['type'], EventType.goal),
        home: j['home'] as bool? ?? true,
        minute: _i(j['minute']),
        stoppage: _i(j['stoppage']),
        playerId: j['playerId'] as String?,
        otherId: j['otherId'] as String?,
        note: j['note'] as String? ?? '',
      );
}

class Lineup {
  String formation;
  List<String> starters; // ordered to match formation slots (GK first)
  List<String> bench;
  String? captainId;

  Lineup({this.formation = '4-4-2', List<String>? starters, List<String>? bench, this.captainId})
      : starters = starters ?? [],
        bench = bench ?? [];

  bool get isEmpty => starters.isEmpty;

  Map<String, dynamic> toJson() => {'formation': formation, 'starters': starters, 'bench': bench, 'captainId': captainId};
  factory Lineup.fromJson(Map<String, dynamic>? j) => j == null
      ? Lineup()
      : Lineup(
          formation: j['formation'] as String? ?? '4-4-2',
          starters: _strs(j['starters']),
          bench: _strs(j['bench']),
          captainId: j['captainId'] as String?,
        );
}

/// Stage of a competition a match belongs to.
enum Stage { league, group, knockout }

class Fixture {
  final String id;
  Stage stage;
  int round; // matchday for league/group; knockout round index (0 = first round)
  String? group; // 'A', 'B' … for group stage
  String? homeId; // null = to be decided (knockout)
  String? awayId;
  String homeLabel; // placeholder text when team unknown, e.g. "Winner QF1" / "A1"
  String awayLabel;
  DateTime? kickoff;
  String venue;
  String referee;
  String assistants;
  int? attendance;
  MatchStatus status;
  int homeGoals;
  int awayGoals;
  bool extraTime;
  int? homePens;
  int? awayPens;
  bool forfeit;
  final List<MatchEvent> events;
  Lineup homeLineup;
  Lineup awayLineup;
  String? motmId;
  String notes;
  // Knockout plumbing.
  int slot; // position within its knockout round
  int leg; // 1 or 2 for two-legged ties, 0 = single match
  String? tieId; // shared by both legs of a tie
  String? nextId; // match the winner goes to
  bool nextHome; // winner takes the home slot of nextId
  String? loserNextId; // third-place playoff
  bool loserNextHome;
  // Live clock: period start (wall-clock) and the match minute it started at.
  DateTime? periodStart;
  int periodBase; // 0, 45, 90, 105
  int period; // 0 not started, 1 first half, 2 HT, 3 second half, 4 ET1, 5 ET2, 6 penalties, 7 ended

  Fixture({
    required this.id,
    this.stage = Stage.league,
    this.round = 0,
    this.group,
    this.homeId,
    this.awayId,
    this.homeLabel = '',
    this.awayLabel = '',
    this.kickoff,
    this.venue = '',
    this.referee = '',
    this.assistants = '',
    this.attendance,
    this.status = MatchStatus.scheduled,
    this.homeGoals = 0,
    this.awayGoals = 0,
    this.extraTime = false,
    this.homePens,
    this.awayPens,
    this.forfeit = false,
    List<MatchEvent>? events,
    Lineup? homeLineup,
    Lineup? awayLineup,
    this.motmId,
    this.notes = '',
    this.slot = 0,
    this.leg = 0,
    this.tieId,
    this.nextId,
    this.nextHome = true,
    this.loserNextId,
    this.loserNextHome = true,
    this.periodStart,
    this.periodBase = 0,
    this.period = 0,
  })  : events = events ?? [],
        homeLineup = homeLineup ?? Lineup(),
        awayLineup = awayLineup ?? Lineup();

  bool get played => status == MatchStatus.finished;
  bool get hasTeams => homeId != null && awayId != null;
  bool get hasPens => homePens != null && awayPens != null;
  bool involves(String teamId) => homeId == teamId || awayId == teamId;
  Lineup lineup(bool home) => home ? homeLineup : awayLineup;
  String? teamId(bool home) => home ? homeId : awayId;
  int goals(bool home) => home ? homeGoals : awayGoals;

  List<MatchEvent> get sortedEvents => [...events]..sort((a, b) => a.sortKey.compareTo(b.sortKey));

  /// Recomputes the score from goal events (if any goals are recorded).
  void syncScoreFromEvents() {
    final g = events.where((e) => e.type.isGoal).toList();
    if (g.isEmpty) return;
    homeGoals = g.where((e) => e.home).length;
    awayGoals = g.where((e) => !e.home).length;
  }

  /// Current match minute while live, from the stored period start.
  int liveMinute([DateTime? now]) {
    if (periodStart == null) return periodBase;
    final s = (now ?? DateTime.now()).difference(periodStart!).inSeconds;
    return periodBase + s ~/ 60 + 1;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'stage': stage.name,
        'round': round,
        'group': group,
        'homeId': homeId,
        'awayId': awayId,
        'homeLabel': homeLabel,
        'awayLabel': awayLabel,
        'kickoff': kickoff?.toIso8601String(),
        'venue': venue,
        'referee': referee,
        'assistants': assistants,
        'attendance': attendance,
        'status': status.name,
        'homeGoals': homeGoals,
        'awayGoals': awayGoals,
        'extraTime': extraTime,
        'homePens': homePens,
        'awayPens': awayPens,
        'forfeit': forfeit,
        'events': [for (final e in events) e.toJson()],
        'homeLineup': homeLineup.toJson(),
        'awayLineup': awayLineup.toJson(),
        'motmId': motmId,
        'notes': notes,
        'slot': slot,
        'leg': leg,
        'tieId': tieId,
        'nextId': nextId,
        'nextHome': nextHome,
        'loserNextId': loserNextId,
        'loserNextHome': loserNextHome,
        'periodStart': periodStart?.toIso8601String(),
        'periodBase': periodBase,
        'period': period,
      };

  factory Fixture.fromJson(Map<String, dynamic> j) => Fixture(
        id: j['id'] as String,
        stage: _enum(Stage.values, j['stage'], Stage.league),
        round: _i(j['round']),
        group: j['group'] as String?,
        homeId: j['homeId'] as String?,
        awayId: j['awayId'] as String?,
        homeLabel: j['homeLabel'] as String? ?? '',
        awayLabel: j['awayLabel'] as String? ?? '',
        kickoff: _tn(j['kickoff']),
        venue: j['venue'] as String? ?? '',
        referee: j['referee'] as String? ?? '',
        assistants: j['assistants'] as String? ?? '',
        attendance: _in(j['attendance']),
        status: _enum(MatchStatus.values, j['status'], MatchStatus.scheduled),
        homeGoals: _i(j['homeGoals']),
        awayGoals: _i(j['awayGoals']),
        extraTime: j['extraTime'] as bool? ?? false,
        homePens: _in(j['homePens']),
        awayPens: _in(j['awayPens']),
        forfeit: j['forfeit'] as bool? ?? false,
        events: _list(j['events']).map(MatchEvent.fromJson).toList(),
        homeLineup: Lineup.fromJson((j['homeLineup'] as Map?)?.cast<String, dynamic>()),
        awayLineup: Lineup.fromJson((j['awayLineup'] as Map?)?.cast<String, dynamic>()),
        motmId: j['motmId'] as String?,
        notes: j['notes'] as String? ?? '',
        slot: _i(j['slot']),
        leg: _i(j['leg']),
        tieId: j['tieId'] as String?,
        nextId: j['nextId'] as String?,
        nextHome: j['nextHome'] as bool? ?? true,
        loserNextId: j['loserNextId'] as String?,
        loserNextHome: j['loserNextHome'] as bool? ?? true,
        periodStart: _tn(j['periodStart']),
        periodBase: _i(j['periodBase']),
        period: _i(j['period']),
      );
}

// ---------------------------------------------------------------------------
// Competitions
// ---------------------------------------------------------------------------

enum Format { league, knockout, groupsKnockout }

extension FormatX on Format {
  String get label => const ['League', 'Knockout cup', 'Groups + knockout'][index];
  String get blurb => const [
        'Everyone plays everyone, home and away if you like. The table decides the champion.',
        'Single elimination bracket with byes, extra time and penalties. One- or two-legged ties.',
        'World-Cup style: round-robin groups, then the top teams go into a knockout bracket.',
      ][index];
}

enum Tiebreak { goalDifference, goalsFor, headToHead, wins, awayGoals, fairPlay, drawLots }

extension TiebreakX on Tiebreak {
  String get label => const [
        'Goal difference',
        'Goals scored',
        'Head-to-head',
        'Most wins',
        'Away goals scored',
        'Fair play (fewest card points)',
        'Drawing of lots',
      ][index];
}

/// A coloured band in the league table (champion, promotion, relegation…).
class Zone {
  String label;
  int from; // 1-based position
  int to;
  int color;
  Zone({required this.label, required this.from, required this.to, required this.color});
  Map<String, dynamic> toJson() => {'label': label, 'from': from, 'to': to, 'color': color};
  factory Zone.fromJson(Map<String, dynamic> j) =>
      Zone(label: j['label'] as String? ?? '', from: _i(j['from'], 1), to: _i(j['to'], 1), color: _i(j['color'], 0xFF3BE37F));
}

class PointAdjustment {
  final String id;
  String teamId;
  int points; // negative = deduction
  String reason;
  PointAdjustment({required this.id, required this.teamId, required this.points, this.reason = ''});
  Map<String, dynamic> toJson() => {'id': id, 'teamId': teamId, 'points': points, 'reason': reason};
  factory PointAdjustment.fromJson(Map<String, dynamic> j) =>
      PointAdjustment(id: j['id'] as String, teamId: j['teamId'] as String, points: _i(j['points']), reason: j['reason'] as String? ?? '');
}

class Rules {
  int win;
  int draw;
  int loss;
  int legs; // league / group: 1 or 2 meetings
  int koLegs; // knockout ties: 1 or 2 (final always single)
  bool awayGoalsRule;
  bool extraTime;
  bool penalties;
  bool thirdPlace;
  int groups;
  int advance; // teams per group into knockout
  int yellowLimit; // yellows that trigger a ban (0 = off)
  int yellowBan;
  int redBan;
  int secondYellowBan;
  int matchMinutes; // 90, or shorter for youth
  int forfeitGoals; // awarded score for forfeits, e.g. 3
  List<Tiebreak> tiebreaks;

  Rules({
    this.win = 3,
    this.draw = 1,
    this.loss = 0,
    this.legs = 2,
    this.koLegs = 1,
    this.awayGoalsRule = false,
    this.extraTime = true,
    this.penalties = true,
    this.thirdPlace = false,
    this.groups = 4,
    this.advance = 2,
    this.yellowLimit = 5,
    this.yellowBan = 1,
    this.redBan = 1,
    this.secondYellowBan = 1,
    this.matchMinutes = 90,
    this.forfeitGoals = 3,
    List<Tiebreak>? tiebreaks,
  }) : tiebreaks = tiebreaks ?? [Tiebreak.goalDifference, Tiebreak.goalsFor, Tiebreak.headToHead, Tiebreak.wins, Tiebreak.fairPlay, Tiebreak.drawLots];

  Map<String, dynamic> toJson() => {
        'win': win,
        'draw': draw,
        'loss': loss,
        'legs': legs,
        'koLegs': koLegs,
        'awayGoalsRule': awayGoalsRule,
        'extraTime': extraTime,
        'penalties': penalties,
        'thirdPlace': thirdPlace,
        'groups': groups,
        'advance': advance,
        'yellowLimit': yellowLimit,
        'yellowBan': yellowBan,
        'redBan': redBan,
        'secondYellowBan': secondYellowBan,
        'matchMinutes': matchMinutes,
        'forfeitGoals': forfeitGoals,
        'tiebreaks': [for (final t in tiebreaks) t.name],
      };

  factory Rules.fromJson(Map<String, dynamic>? j) {
    if (j == null) return Rules();
    return Rules(
      win: _i(j['win'], 3),
      draw: _i(j['draw'], 1),
      loss: _i(j['loss'], 0),
      legs: _i(j['legs'], 2),
      koLegs: _i(j['koLegs'], 1),
      awayGoalsRule: j['awayGoalsRule'] as bool? ?? false,
      extraTime: j['extraTime'] as bool? ?? true,
      penalties: j['penalties'] as bool? ?? true,
      thirdPlace: j['thirdPlace'] as bool? ?? false,
      groups: _i(j['groups'], 4),
      advance: _i(j['advance'], 2),
      yellowLimit: _i(j['yellowLimit'], 5),
      yellowBan: _i(j['yellowBan'], 1),
      redBan: _i(j['redBan'], 1),
      secondYellowBan: _i(j['secondYellowBan'], 1),
      matchMinutes: _i(j['matchMinutes'], 90),
      forfeitGoals: _i(j['forfeitGoals'], 3),
      tiebreaks: [for (final t in _strs(j['tiebreaks'])) _enum(Tiebreak.values, t, Tiebreak.goalDifference)].toSet().toList(),
    );
  }
}

class Competition {
  final String id;
  String name;
  String season;
  Format format;
  Rules rules;
  int color;
  final List<String> teamIds;
  final Map<String, List<String>> groups; // 'A' → team ids
  final List<Fixture> matches;
  final List<Zone> zones;
  final List<PointAdjustment> adjustments;
  String organizer;
  bool archived;
  DateTime created;

  Competition({
    required this.id,
    required this.name,
    this.season = '',
    this.format = Format.league,
    Rules? rules,
    this.color = 0xFF3BE37F,
    List<String>? teamIds,
    Map<String, List<String>>? groups,
    List<Fixture>? matches,
    List<Zone>? zones,
    List<PointAdjustment>? adjustments,
    this.organizer = '',
    this.archived = false,
    DateTime? created,
  })  : rules = rules ?? Rules(),
        teamIds = teamIds ?? [],
        groups = groups ?? {},
        matches = matches ?? [],
        zones = zones ?? [],
        adjustments = adjustments ?? [],
        created = created ?? DateTime.now();

  bool get started => matches.isNotEmpty;
  Iterable<Fixture> get leagueMatches => matches.where((m) => m.stage != Stage.knockout);
  Iterable<Fixture> get knockoutMatches => matches.where((m) => m.stage == Stage.knockout);

  Fixture? match(String? id) {
    if (id == null) return null;
    for (final m in matches) {
      if (m.id == id) return m;
    }
    return null;
  }

  int get playedCount => matches.where((m) => m.played).length;
  double get progress => matches.isEmpty ? 0 : playedCount / matches.where((m) => m.status != MatchStatus.cancelled).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'season': season,
        'format': format.name,
        'rules': rules.toJson(),
        'color': color,
        'teamIds': teamIds,
        'groups': groups,
        'matches': [for (final m in matches) m.toJson()],
        'zones': [for (final z in zones) z.toJson()],
        'adjustments': [for (final a in adjustments) a.toJson()],
        'organizer': organizer,
        'archived': archived,
        'created': created.toIso8601String(),
      };

  factory Competition.fromJson(Map<String, dynamic> j) => Competition(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        season: j['season'] as String? ?? '',
        format: _enum(Format.values, j['format'], Format.league),
        rules: Rules.fromJson((j['rules'] as Map?)?.cast<String, dynamic>()),
        color: _i(j['color'], 0xFF3BE37F),
        teamIds: _strs(j['teamIds']),
        groups: {for (final e in ((j['groups'] as Map?) ?? const {}).entries) e.key as String: _strs(e.value)},
        matches: _list(j['matches']).map(Fixture.fromJson).toList(),
        zones: _list(j['zones']).map(Zone.fromJson).toList(),
        adjustments: _list(j['adjustments']).map(PointAdjustment.fromJson).toList(),
        organizer: j['organizer'] as String? ?? '',
        archived: j['archived'] as bool? ?? false,
        created: _tn(j['created']) ?? DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String dayDate(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String dateTimeText(DateTime d) => '${dayDate(d)} · ${hhmm(d)}';
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
