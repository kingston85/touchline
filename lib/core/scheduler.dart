// Fixture generation: round robin (circle method), group draws and
// knockout brackets with byes, two-legged ties and third-place playoffs.

import 'dart:math' as math;

import '../data/models.dart';

/// Round-robin rounds for [teams] using the circle (Berger) method.
/// Every pair meets once per leg; each team plays at most once per round,
/// and home/away is balanced greedily (no long home or away runs). Odd team counts
/// get a rest ("bye") each round.
List<List<(String, String)>> roundRobin(List<String> teams, {int legs = 1}) {
  final list = <String?>[...teams];
  if (list.length < 2) return [];
  if (list.length.isOdd) list.add(null); // bye
  final n = list.length;
  final rounds = <List<(String, String)>>[];
  var arr = [...list];
  final homes = {for (final t in teams) t: 0};
  final last = <String, bool>{}; // true = was at home last time
  int pref(String t) => last[t] == false ? 0 : (last[t] == null ? 1 : 2);
  for (var r = 0; r < n - 1; r++) {
    final pairs = <(String, String)>[];
    for (var i = 0; i < n ~/ 2; i++) {
      final a = arr[i], b = arr[n - 1 - i];
      if (a == null || b == null) continue;
      // Give home to whoever was away last time, then to fewer home games.
      final ka = pref(a) * 1000 + homes[a]!, kb = pref(b) * 1000 + homes[b]!;
      final h = ka <= kb ? a : b, w = ka <= kb ? b : a;
      homes[h] = homes[h]! + 1;
      last[h] = true;
      last[w] = false;
      pairs.add((h, w));
    }
    rounds.add(pairs);
    // Rotate all but the first element clockwise.
    arr = [arr.first, arr.last, ...arr.sublist(1, n - 1)];
  }
  if (legs >= 2) {
    final second = [for (final r in rounds) [for (final p in r) (p.$2, p.$1)]];
    rounds.addAll(second);
  }
  return rounds;
}

/// Standard bracket seed positions: seeds 1 and 2 can only meet in the final.
/// For size 8 → [1, 8, 4, 5, 2, 7, 3, 6].
List<int> seedPositions(int size) {
  var order = [1];
  while (order.length < size) {
    final m = order.length * 2 + 1;
    order = [for (final s in order) ...[s, m - s]];
  }
  return order;
}

int nextPow2(int n) {
  var p = 1;
  while (p < n) {
    p *= 2;
  }
  return p;
}

String roundName(int teamsInRound) {
  switch (teamsInRound) {
    case 2:
      return 'Final';
    case 4:
      return 'Semi-finals';
    case 8:
      return 'Quarter-finals';
    default:
      return 'Round of $teamsInRound';
  }
}

String roundShort(int teamsInRound) {
  switch (teamsInRound) {
    case 2:
      return 'F';
    case 4:
      return 'SF';
    case 8:
      return 'QF';
    default:
      return 'R$teamsInRound';
  }
}

/// Builds league fixtures for [c] (all its teams), replacing any existing ones.
void generateLeague(Competition c, {DateTime? start, int daysBetween = 7, String venueMode = 'home'}) {
  c.matches.removeWhere((m) => m.stage == Stage.league);
  final rounds = roundRobin(c.teamIds, legs: c.rules.legs);
  for (var r = 0; r < rounds.length; r++) {
    for (final (h, a) in rounds[r]) {
      c.matches.add(Fixture(id: newId(), stage: Stage.league, round: r + 1, homeId: h, awayId: a));
    }
  }
  if (start != null) scheduleRounds(c.matches.where((m) => m.stage == Stage.league).toList(), start, daysBetween);
}

/// Draws teams into groups by "snake" seeding: the list order is the seeding
/// (pot 1 first). Returns group letter → team ids.
Map<String, List<String>> drawGroups(List<String> seeded, int groups, {int? shuffleSeed}) {
  final g = math.max(1, groups);
  final out = {for (var i = 0; i < g; i++) String.fromCharCode(65 + i): <String>[]};
  final keys = out.keys.toList();
  // Shuffle within each pot so the draw isn't purely mechanical.
  final rnd = shuffleSeed == null ? null : math.Random(shuffleSeed);
  for (var pot = 0; pot * g < seeded.length; pot++) {
    final chunk = seeded.sublist(pot * g, math.min(seeded.length, pot * g + g));
    if (rnd != null) chunk.shuffle(rnd);
    for (var i = 0; i < chunk.length; i++) {
      out[keys[i]]!.add(chunk[i]);
    }
  }
  return out;
}

/// Creates group-stage fixtures from [c.groups].
void generateGroupStage(Competition c, {DateTime? start, int daysBetween = 3}) {
  c.matches.removeWhere((m) => m.stage == Stage.group);
  final all = <Fixture>[];
  for (final e in c.groups.entries) {
    final rounds = roundRobin(e.value, legs: c.rules.legs);
    for (var r = 0; r < rounds.length; r++) {
      for (final (h, a) in rounds[r]) {
        all.add(Fixture(id: newId(), stage: Stage.group, group: e.key, round: r + 1, homeId: h, awayId: a));
      }
    }
  }
  c.matches.addAll(all);
  if (start != null) scheduleRounds(all, start, daysBetween);
}

/// One knockout entrant: a known team, or a placeholder label (e.g. "A1").
class Entrant {
  final String? teamId;
  final String label;
  const Entrant(this.teamId, [this.label = '']);
}

/// Builds a full bracket from entrants in seed order (best first).
/// Missing places become byes, given to the top seeds. Returns the fixtures
/// created (also added to [c]).
List<Fixture> generateKnockout(Competition c, List<Entrant> seeded, {DateTime? start, int daysBetween = 7}) {
  c.matches.removeWhere((m) => m.stage == Stage.knockout);
  final n = seeded.length;
  if (n < 2) return [];
  final size = nextPow2(n);
  final pos = seedPositions(size);
  final entrants = [for (final s in pos) s <= n ? seeded[s - 1] : null];
  final totalRounds = (math.log(size) / math.ln2).round();
  final created = <Fixture>[];
  // rounds[r][slot] = list of fixtures (1 or 2 legs) for that tie.
  final rounds = <List<List<Fixture>>>[];
  for (var r = 0; r < totalRounds; r++) {
    final ties = size >> (r + 1);
    final isFinal = ties == 1;
    final legs = isFinal ? 1 : math.max(1, math.min(2, c.rules.koLegs));
    final list = <List<Fixture>>[];
    for (var s = 0; s < ties; s++) {
      final tieId = newId();
      final legsList = [
        for (var l = 1; l <= legs; l++)
          Fixture(id: newId(), stage: Stage.knockout, round: r, slot: s, leg: legs == 1 ? 0 : l, tieId: tieId),
      ];
      list.add(legsList);
    }
    rounds.add(list);
  }
  // Link winners forward.
  for (var r = 0; r < totalRounds - 1; r++) {
    for (var s = 0; s < rounds[r].length; s++) {
      final target = rounds[r + 1][s ~/ 2].first; // leg 1 of the next tie
      for (final f in rounds[r][s]) {
        f.nextId = target.id;
        f.nextHome = s.isEven;
      }
    }
  }
  // Third-place playoff for semi-final losers.
  Fixture? third;
  if (c.rules.thirdPlace && totalRounds >= 2) {
    third = Fixture(id: newId(), stage: Stage.knockout, round: totalRounds - 1, slot: 1, leg: 0, tieId: newId(), homeLabel: 'Loser SF1', awayLabel: 'Loser SF2');
    final semis = rounds[totalRounds - 2];
    for (var s = 0; s < semis.length; s++) {
      for (final f in semis[s]) {
        f.loserNextId = third.id;
        f.loserNextHome = s.isEven;
      }
    }
  }
  // Placeholder labels for later rounds.
  for (var r = 1; r < totalRounds; r++) {
    final prevShort = roundShort(size >> (r - 1));
    for (var s = 0; s < rounds[r].length; s++) {
      for (final f in rounds[r][s]) {
        final a = 'Winner $prevShort${2 * s + 1}', b = 'Winner $prevShort${2 * s + 2}';
        f.homeLabel = f.leg == 2 ? b : a;
        f.awayLabel = f.leg == 2 ? a : b;
      }
    }
  }
  // Fill the first round; byes send the team straight through.
  final first = rounds[0];
  final removed = <Fixture>{};
  for (var s = 0; s < first.length; s++) {
    final a = entrants[2 * s], b = entrants[2 * s + 1];
    if (a == null || b == null) {
      final through = a ?? b;
      removed.addAll(first[s]);
      if (through != null && totalRounds > 1) {
        for (final f in rounds[1][s ~/ 2]) {
          final homeSide = (f.leg == 2) ? !s.isEven : s.isEven;
          if (homeSide) {
            f.homeId = through.teamId;
            f.homeLabel = through.label;
          } else {
            f.awayId = through.teamId;
            f.awayLabel = through.label;
          }
        }
      }
      continue;
    }
    for (final f in first[s]) {
      final swap = f.leg == 2;
      final h = swap ? b : a, w = swap ? a : b;
      f.homeId = h.teamId;
      f.homeLabel = h.label;
      f.awayId = w.teamId;
      f.awayLabel = w.label;
    }
  }
  for (final r in rounds) {
    for (final t in r) {
      for (final f in t) {
        if (!removed.contains(f)) created.add(f);
      }
    }
  }
  if (third != null) created.add(third);
  c.matches.addAll(created);
  if (start != null) {
    // Each knockout round (and each leg) gets its own date.
    var d = start;
    for (var r = 0; r < totalRounds; r++) {
      for (var leg = 0; leg <= 2; leg++) {
        final batch = created.where((f) => f.round == r && f.leg == leg && f != third).toList();
        if (batch.isEmpty) continue;
        for (final f in batch) {
          f.kickoff = d;
        }
        d = d.add(Duration(days: daysBetween));
      }
    }
    third?.kickoff = created.firstWhere((f) => f.round == totalRounds - 1 && f != third).kickoff?.subtract(const Duration(days: 1));
  }
  return created;
}

/// Seeds group qualifiers so teams from the same group are kept apart in the
/// first knockout round: all winners (A1, B1 …) are the top seeds, then the
/// runners-up in group order. With bracket seeding (1 v N, 2 v N-1 …) the
/// winner of A meets the runner-up of the last group, and so on.
List<Entrant> groupQualifiers(Map<String, List<String>> standingsByGroup, int advance) {
  final groups = standingsByGroup.keys.toList()..sort();
  final out = <Entrant>[];
  for (var p = 0; p < advance; p++) {
    for (final g in groups) {
      final list = standingsByGroup[g]!;
      out.add(Entrant(p < list.length ? list[p] : null, '$g${p + 1}'));
    }
  }
  return out;
}

/// Spreads rounds over dates: round 1 on [start], then every [daysBetween] days.
/// Keeps each fixture's time of day from [start].
void scheduleRounds(List<Fixture> fixtures, DateTime start, int daysBetween) {
  final rounds = fixtures.map((f) => f.round).toSet().toList()..sort();
  for (var i = 0; i < rounds.length; i++) {
    final d = start.add(Duration(days: i * daysBetween));
    for (final f in fixtures.where((f) => f.round == rounds[i])) {
      f.kickoff = d;
    }
  }
}
