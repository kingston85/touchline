// Demo league and cup with simulated results, so every screen has data.
// Clubs and players are fictional.

import 'dart:math' as math;

import '../data/models.dart';
import 'formations.dart';
import 'scheduler.dart';
import 'standings.dart';

const demoOrganizer = 'Touchline demo';
const demoContact = 'demo';

const _clubs = [
  ('Mamba Point Rovers', 'MPR', 0xFF1E88E5, 0xFFFFFFFF, 'Mamba Point', 'ATS Field'),
  ('Sinkor United', 'SKU', 0xFFE53935, 0xFFFFFFFF, 'Sinkor', 'Sinkor Park'),
  ('Paynesville Eagles', 'PAY', 0xFFFFC23D, 0xFF101010, 'Paynesville', 'Eagles Nest'),
  ('Gardnersville Stars', 'GAR', 0xFF8E24AA, 0xFFFFC23D, 'Gardnersville', 'Star Park'),
  ('Kakata Lions', 'KAK', 0xFF43A047, 0xFFFFFFFF, 'Kakata', 'Kakata Stadium'),
  ('Buchanan Mariners', 'BUC', 0xFF00ACC1, 0xFF0D1B2A, 'Buchanan', 'Harbour Field'),
  ('Gbarnga Warriors', 'GBA', 0xFFF4511E, 0xFF101010, 'Gbarnga', 'Gbarnga Sports Pitch'),
  ('Bushrod Island FC', 'BIF', 0xFF3949AB, 0xFFFFC23D, 'Bushrod Island', 'Freeport Ground'),
  ('Ganta City', 'GAN', 0xFF6D4C41, 0xFFFFFFFF, 'Ganta', 'Ganta Park'),
  ('Harper Seagulls', 'HAR', 0xFFFFFFFF, 0xFF1565C0, 'Harper', 'Cape Palmas Field'),
];

const _first = [
  'Joseph', 'Emmanuel', 'Prince', 'Abraham', 'Moses', 'Samuel', 'Christopher', 'Isaac', 'Varney', 'Momo', 'Sekou',
  'Mohammed', 'Kpakolo', 'Tamba', 'Sahr', 'Boakai', 'Jallah', 'Morris', 'Augustine', 'Dominic', 'Peter', 'Daniel',
  'Alvin', 'Marvin', 'Oscar', 'Amos', 'Musa', 'Kelvin', 'Jerome', 'Benedict', 'Patrick', 'George', 'Wilmot',
];
const _last = [
  'Kollie', 'Flomo', 'Kamara', 'Sirleaf', 'Weah', 'Doe', 'Toe', 'Kpoto', 'Sackor', 'Johnson', 'Kromah', 'Zubah',
  'Dolo', 'Mulbah', 'Gaye', 'Tarr', 'Wesseh', 'Sumo', 'Barclay', 'Cooper', 'Massaquoi', 'Kiazolu', 'Boima',
  'Nyumah', 'Saydee', 'Gbelee', 'Tamba', 'Kanneh', 'Freeman', 'Sengbeh', 'Yarkpawolo', 'Kpadeh', 'Wolo',
];

int _poisson(math.Random r, double lambda) {
  final l = math.exp(-lambda);
  var k = 0;
  var p = 1.0;
  do {
    k++;
    p *= r.nextDouble();
  } while (p > l);
  return k - 1;
}

List<Team> _makeTeams(math.Random rnd) {
  final out = <Team>[];
  final used = <String>{};
  for (final c in _clubs) {
    final t = Team(
      id: newId(),
      name: c.$1,
      short: c.$2,
      color1: c.$3,
      color2: c.$4,
      city: c.$5,
      ground: c.$6,
      coach: '${_first[rnd.nextInt(_first.length)]} ${_last[rnd.nextInt(_last.length)]}',
      contact: demoContact,
      founded: 1960 + rnd.nextInt(55),
    );
    final layout = [Position.gk, Position.gk, ...List.filled(6, Position.df), ...List.filled(6, Position.mf), ...List.filled(5, Position.fw)];
    final numbers = [1, 22, 2, 3, 4, 5, 12, 15, 6, 8, 10, 14, 16, 18, 7, 9, 11, 17, 19];
    for (var i = 0; i < layout.length; i++) {
      String name;
      do {
        name = '${_first[rnd.nextInt(_first.length)]} ${_last[rnd.nextInt(_last.length)]}';
      } while (!used.add(name));
      t.players.add(Player(
        id: newId(),
        name: name,
        number: numbers[i],
        position: layout[i],
        birth: DateTime(1995 + rnd.nextInt(11), 1 + rnd.nextInt(12), 1 + rnd.nextInt(28)),
        nationality: 'Liberia',
        captain: i == 10,
      ));
    }
    out.add(t);
  }
  return out;
}

/// Fills in a plausible result with lineups, goals, cards and subs.
void simulate(Fixture f, Team home, Team away, math.Random rnd, {bool knockout = false, Set<String> unavailable = const {}}) {
  final forms = ['4-4-2', '4-3-3', '4-2-3-1', '3-5-2'];
  for (final side in [true, false]) {
    final t = side ? home : away;
    final form = forms[rnd.nextInt(forms.length)];
    final lu = autoLineup(t, form, unavailable: unavailable);
    final l = Lineup(formation: form, starters: lu.$1, bench: lu.$2, captainId: t.players.firstWhere((p) => p.captain, orElse: () => t.players.first).id);
    if (side) {
      f.homeLineup = l;
    } else {
      f.awayLineup = l;
    }
  }
  f.events.clear();
  final hg = _poisson(rnd, 1.55), ag = _poisson(rnd, 1.15);
  String pickScorer(Lineup l, Team t) {
    final weights = <String, int>{};
    for (final id in l.starters) {
      final p = t.player(id)!;
      weights[id] = switch (p.position) { Position.fw => 8, Position.mf => 4, Position.df => 1, Position.gk => 0 };
    }
    final total = weights.values.fold(0, (a, b) => a + b);
    var x = rnd.nextInt(total);
    for (final e in weights.entries) {
      x -= e.value;
      if (x < 0) return e.key;
    }
    return l.starters.last;
  }

  for (final side in [true, false]) {
    final t = side ? home : away;
    final l = f.lineup(side);
    final n = side ? hg : ag;
    for (var g = 0; g < n; g++) {
      final roll = rnd.nextDouble();
      final minute = 1 + rnd.nextInt(90);
      if (roll < 0.05) {
        final ol = f.lineup(!side);
        f.events.add(MatchEvent(id: newId(), type: EventType.ownGoal, home: side, minute: minute, playerId: ol.starters[1 + rnd.nextInt(4)]));
        continue;
      }
      final scorer = pickScorer(l, t);
      String? assist;
      if (rnd.nextDouble() < 0.7) {
        final others = l.starters.where((id) => id != scorer && id != l.starters.first).toList();
        assist = others[rnd.nextInt(others.length)];
      }
      final pen = roll < 0.13;
      f.events.add(MatchEvent(
        id: newId(),
        type: pen ? EventType.penaltyGoal : EventType.goal,
        home: side,
        minute: minute,
        stoppage: minute == 90 ? 1 + rnd.nextInt(4) : 0,
        playerId: scorer,
        otherId: pen ? null : assist,
      ));
    }
    // Cards.
    final yc = _poisson(rnd, 1.7);
    for (var k = 0; k < yc; k++) {
      f.events.add(MatchEvent(id: newId(), type: EventType.yellow, home: side, minute: 10 + rnd.nextInt(80), playerId: l.starters[1 + rnd.nextInt(10)]));
    }
    if (rnd.nextDouble() < 0.06) {
      f.events.add(MatchEvent(id: newId(), type: EventType.red, home: side, minute: 30 + rnd.nextInt(60), playerId: l.starters[1 + rnd.nextInt(10)]));
    }
    // Substitutions.
    final subs = 2 + rnd.nextInt(3);
    final bench = [...l.bench.where((id) => t.player(id)!.position != Position.gk)]..shuffle(rnd);
    final outs = [...l.starters.sublist(5)]..shuffle(rnd);
    for (var k = 0; k < subs && k < bench.length && k < outs.length; k++) {
      f.events.add(MatchEvent(id: newId(), type: EventType.sub, home: side, minute: 55 + rnd.nextInt(33), playerId: bench[k], otherId: outs[k]));
    }
  }
  // Avoid duplicate yellows on the same player in one match.
  final seen = <String>{};
  f.events.removeWhere((e) => e.type == EventType.yellow && !seen.add('${e.playerId}'));
  f.syncScoreFromEvents();
  if (f.events.where((e) => e.type.isGoal).isEmpty) {
    f.homeGoals = 0;
    f.awayGoals = 0;
  }
  if (knockout && f.homeGoals == f.awayGoals) {
    f.extraTime = true;
    f.homePens = 3 + rnd.nextInt(3);
    f.awayPens = f.homePens! + (rnd.nextBool() ? 1 : -1);
    if (f.awayPens! < 0) f.awayPens = 0;
  }
  final starters = [...f.homeLineup.starters, ...f.awayLineup.starters];
  f.motmId = starters[rnd.nextInt(starters.length)];
  f.attendance = 400 + rnd.nextInt(4200);
  f.referee = '${_first[rnd.nextInt(_first.length)]} ${_last[rnd.nextInt(_last.length)]}';
  f.status = MatchStatus.finished;
  f.period = 7;
}

(List<Team>, List<Competition>) buildDemo() {
  final rnd = math.Random(2026);
  final teams = _makeTeams(rnd);
  Team byId(String id) => teams.firstWhere((t) => t.id == id);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 16);

  // League: double round robin, about two thirds played.
  final league = Competition(
    id: newId(),
    name: 'Monrovia Premier League',
    season: '${now.year}/${(now.year + 1) % 100}',
    format: Format.league,
    color: 0xFF3BE37F,
    teamIds: [for (final t in teams) t.id],
    organizer: demoOrganizer,
    zones: [
      Zone(label: 'Champion', from: 1, to: 1, color: 0xFFFFC23D),
      Zone(label: 'CAF qualification', from: 2, to: 2, color: 0xFF4DA3FF),
      Zone(label: 'Relegation', from: 9, to: 10, color: 0xFFFF4F5E),
    ],
  );
  final rounds = (league.teamIds.length - 1) * 2;
  final played = (rounds * 0.66).round();
  generateLeague(league, start: today.subtract(Duration(days: 7 * played - 3)), daysBetween: 7);
  for (final f in league.matches) {
    f.venue = byId(f.homeId!).ground;
    f.kickoff = f.kickoff!.add(Duration(hours: f.round.isEven ? 0 : -2));
  }
  final ordered = [...league.matches]..sort((a, b) => a.round.compareTo(b.round));
  for (final f in ordered) {
    if (f.round <= played) {
      final d = discipline(league);
      simulate(f, byId(f.homeId!), byId(f.awayId!), rnd, unavailable: d.active.keys.toSet());
    }
  }
  league.adjustments.add(PointAdjustment(id: newId(), teamId: teams[8].id, points: -3, reason: 'Fielded an ineligible player'));

  // Cup: 8 teams, two groups of four, semi-finals, third place, final.
  final cupTeams = [teams[0], teams[1], teams[2], teams[3], teams[4], teams[5], teams[6], teams[7]];
  final cup = Competition(
    id: newId(),
    name: 'Independence Cup',
    season: '${now.year}',
    format: Format.groupsKnockout,
    color: 0xFFFFC23D,
    teamIds: [for (final t in cupTeams) t.id],
    organizer: demoOrganizer,
    rules: Rules(legs: 1, groups: 2, advance: 2, thirdPlace: true, yellowLimit: 2),
  );
  cup.groups.addAll(drawGroups(cup.teamIds, 2, shuffleSeed: 7));
  final cupStart = today.subtract(const Duration(days: 20));
  generateGroupStage(cup, start: cupStart, daysBetween: 3);
  for (final f in cup.matches) {
    f.venue = 'Antoinette Tubman Stadium';
    simulate(f, byId(f.homeId!), byId(f.awayId!), rnd);
  }
  final standings = {
    for (final g in cup.groups.keys)
      g: buildTable(cup, cup.groups[g]!, cup.matches.where((m) => m.group == g)).map((r) => r.teamId).toList(),
  };
  generateKnockout(cup, groupQualifiers(standings, 2), start: today.subtract(const Duration(days: 4)), daysBetween: 6);
  for (final f in cup.knockoutMatches) {
    f.venue = 'Samuel Kanyon Doe Sports Complex';
  }
  // Play the semi-finals; the final and third-place match are still to come.
  for (final f in cup.knockoutMatches.where((m) => m.round == 0).toList()) {
    simulate(f, byId(f.homeId!), byId(f.awayId!), rnd, knockout: true);
  }
  advanceKnockout(cup);
  return (teams, [league, cup]);
}
