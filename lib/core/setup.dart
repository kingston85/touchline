// Builds a competition's fixtures from its format and rules.

import 'dart:math' as math;

import '../data/models.dart';
import 'scheduler.dart';
import 'standings.dart';

/// (Re)generates all fixtures for [c]. Teams are taken in their list order
/// as the seeding; [randomDraw] shuffles (within pots for groups).
void buildFixtures(
  Competition c, {
  required DateTime start,
  int daysBetween = 7,
  bool randomDraw = true,
  bool homeVenues = true,
  Team? Function(String id)? team,
  int? seed,
}) {
  c.matches.clear();
  final rnd = math.Random(seed ?? DateTime.now().millisecondsSinceEpoch);
  switch (c.format) {
    case Format.league:
      final ids = [...c.teamIds];
      if (randomDraw) ids.shuffle(rnd);
      final saved = [...c.teamIds];
      c.teamIds
        ..clear()
        ..addAll(ids);
      generateLeague(c, start: start, daysBetween: daysBetween);
      c.teamIds
        ..clear()
        ..addAll(saved);
      break;
    case Format.knockout:
      final ids = [...c.teamIds];
      if (randomDraw) ids.shuffle(rnd);
      generateKnockout(c, [for (final id in ids) Entrant(id)], start: start, daysBetween: daysBetween);
      break;
    case Format.groupsKnockout:
      c.groups
        ..clear()
        ..addAll(drawGroups(c.teamIds, c.rules.groups, shuffleSeed: randomDraw ? rnd.nextInt(1 << 30) : null));
      generateGroupStage(c, start: start, daysBetween: daysBetween);
      final groupDates = c.matches.map((m) => m.kickoff).whereType<DateTime>().toList()..sort();
      final koStart = groupDates.isEmpty ? start : groupDates.last.add(Duration(days: daysBetween));
      final placeholders = {for (final g in c.groups.keys) g: <String>[]};
      final entrants = groupQualifiers(placeholders, c.rules.advance);
      generateKnockout(c, entrants, start: koStart, daysBetween: daysBetween);
      break;
  }
  if (homeVenues && team != null) {
    for (final f in c.matches) {
      final g = team(f.homeId)?.ground ?? '';
      if (g.isNotEmpty) f.venue = g;
    }
  }
}

/// Puts group finishers into knockout slots labelled "A1", "B2" …
/// Only fills groups whose matches are all played unless [force].
int fillKnockoutFromGroups(Competition c, {Map<String, String>? names, bool force = false}) {
  final pos = <String, String>{};
  for (final g in c.groups.keys) {
    final ms = c.matches.where((m) => m.stage == Stage.group && m.group == g).toList();
    if (!force && ms.any((m) => !m.played && m.status != MatchStatus.cancelled)) continue;
    final t = buildTable(c, c.groups[g]!, ms, names: names);
    for (var i = 0; i < t.length; i++) {
      pos['$g${i + 1}'] = t[i].teamId;
    }
  }
  var n = 0;
  final label = RegExp(r'^[A-Z]\d+$');
  for (final f in c.knockoutMatches) {
    if (f.played) continue;
    if (label.hasMatch(f.homeLabel) && pos.containsKey(f.homeLabel) && f.homeId != pos[f.homeLabel]) {
      f.homeId = pos[f.homeLabel];
      n++;
    }
    if (label.hasMatch(f.awayLabel) && pos.containsKey(f.awayLabel) && f.awayId != pos[f.awayLabel]) {
      f.awayId = pos[f.awayLabel];
      n++;
    }
  }
  return n;
}

/// Fixture count preview for the wizard.
int previewMatchCount(Format f, int teams, Rules r) {
  if (teams < 2) return 0;
  int rr(int n) => n * (n - 1) ~/ 2 * r.legs;
  int ko(int n) {
    if (n < 2) return 0;
    final size = nextPow2(n);
    var total = 0;
    var ties = size ~/ 2;
    final byes = size - n;
    var first = true;
    while (ties >= 1) {
      final real = first ? ties - byes : ties;
      total += real * (ties == 1 ? 1 : r.koLegs);
      first = false;
      ties ~/= 2;
    }
    return total + (r.thirdPlace && size >= 4 ? 1 : 0);
  }

  switch (f) {
    case Format.league:
      return rr(teams);
    case Format.knockout:
      return ko(teams);
    case Format.groupsKnockout:
      final g = math.max(1, r.groups);
      var total = 0;
      for (var i = 0; i < g; i++) {
        final n = teams ~/ g + (i < teams % g ? 1 : 0);
        total += rr(n);
      }
      return total + ko(g * r.advance);
  }
}
