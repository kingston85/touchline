// League tables with configurable tiebreakers, knockout resolution,
// player statistics and disciplinary suspensions.

import '../data/models.dart';

enum TableView { overall, home, away }

class Standing {
  final String teamId;
  int played = 0, won = 0, drawn = 0, lost = 0, gf = 0, ga = 0, awayGf = 0;
  int adjust = 0;
  int cardPoints = 0;
  final int winPts, drawPts, lossPts;
  final List<String> form = []; // 'W', 'D', 'L' oldest → newest
  Standing(this.teamId, this.winPts, this.drawPts, this.lossPts);

  int get gd => gf - ga;
  int get points => won * winPts + drawn * drawPts + lost * lossPts + adjust;
  List<String> get last5 => form.length <= 5 ? form : form.sublist(form.length - 5);
}

/// Result of [f] for one team: 1 win, 0 draw, -1 loss.
int outcome(Fixture f, String teamId) {
  final home = f.homeId == teamId;
  final d = f.homeGoals - f.awayGoals;
  if (d == 0) return 0;
  return (d > 0) == home ? 1 : -1;
}

int cardPointsFor(Fixture f, bool home) {
  var p = 0;
  for (final e in f.events.where((e) => e.home == home)) {
    if (e.type == EventType.yellow) p += 1;
    if (e.type == EventType.secondYellow) p += 3;
    if (e.type == EventType.red) p += 3;
  }
  return p;
}

DateTime _when(Fixture f) => f.kickoff ?? DateTime(2000 + f.round);

/// Builds a sorted table for [teamIds] from [fixtures] (only finished ones count).
List<Standing> buildTable(
  Competition c,
  List<String> teamIds,
  Iterable<Fixture> fixtures, {
  TableView view = TableView.overall,
  bool applyAdjustments = true,
  Map<String, String>? names,
}) {
  final rows = {for (final t in teamIds) t: Standing(t, c.rules.win, c.rules.draw, c.rules.loss)};
  final played = fixtures.where((f) => f.played && f.hasTeams && rows.containsKey(f.homeId) && rows.containsKey(f.awayId)).toList()
    ..sort((a, b) {
      final t = _when(a).compareTo(_when(b));
      return t != 0 ? t : a.round.compareTo(b.round);
    });
  for (final f in played) {
    for (final home in [true, false]) {
      if (view == TableView.home && !home) continue;
      if (view == TableView.away && home) continue;
      final r = rows[f.teamId(home)]!;
      final o = outcome(f, r.teamId);
      r.played++;
      r.gf += f.goals(home);
      r.ga += f.goals(!home);
      if (!home) r.awayGf += f.goals(false);
      r.cardPoints += cardPointsFor(f, home);
      if (o > 0) {
        r.won++;
        r.form.add('W');
      } else if (o == 0) {
        r.drawn++;
        r.form.add('D');
      } else {
        r.lost++;
        r.form.add('L');
      }
    }
  }
  if (applyAdjustments && view == TableView.overall) {
    for (final a in c.adjustments) {
      rows[a.teamId]?.adjust += a.points;
    }
  }
  final list = rows.values.toList();
  return rankRows(c, list, played, names: names);
}

/// Sorts rows by points then the competition's tiebreakers, applied in order
/// to each block of teams that are still level.
List<Standing> rankRows(Competition c, List<Standing> rows, List<Fixture> played, {Map<String, String>? names}) {
  String nm(String id) => names?[id] ?? id;

  num key(Tiebreak t, Standing r, Set<String> block) {
    switch (t) {
      case Tiebreak.goalDifference:
        return r.gd;
      case Tiebreak.goalsFor:
        return r.gf;
      case Tiebreak.wins:
        return r.won;
      case Tiebreak.awayGoals:
        return r.awayGf;
      case Tiebreak.fairPlay:
        return -r.cardPoints;
      case Tiebreak.drawLots:
        return 0;
      case Tiebreak.headToHead:
        var pts = 0, gf = 0, ga = 0;
        for (final f in played) {
          if (!block.contains(f.homeId) || !block.contains(f.awayId)) continue;
          if (!f.involves(r.teamId)) continue;
          final home = f.homeId == r.teamId;
          gf += f.goals(home);
          ga += f.goals(!home);
          final o = outcome(f, r.teamId);
          pts += o > 0 ? c.rules.win : (o == 0 ? c.rules.draw : c.rules.loss);
        }
        return pts * 1000000 + (gf - ga + 1000) * 1000 + gf;
    }
  }

  List<Standing> rank(List<Standing> block, int ci) {
    if (block.length <= 1) return block;
    if (ci >= c.rules.tiebreaks.length) {
      return block..sort((a, b) => nm(a.teamId).toLowerCase().compareTo(nm(b.teamId).toLowerCase()));
    }
    final t = c.rules.tiebreaks[ci];
    final ids = block.map((r) => r.teamId).toSet();
    final keys = {for (final r in block) r.teamId: key(t, r, ids)};
    block.sort((a, b) => keys[b.teamId]!.compareTo(keys[a.teamId]!));
    final out = <Standing>[];
    var i = 0;
    while (i < block.length) {
      var j = i;
      while (j + 1 < block.length && keys[block[j + 1].teamId] == keys[block[i].teamId]) {
        j++;
      }
      out.addAll(rank(block.sublist(i, j + 1), ci + 1));
      i = j + 1;
    }
    return out;
  }

  rows.sort((a, b) => b.points.compareTo(a.points));
  final out = <Standing>[];
  var i = 0;
  while (i < rows.length) {
    var j = i;
    while (j + 1 < rows.length && rows[j + 1].points == rows[i].points) {
      j++;
    }
    out.addAll(rank(rows.sublist(i, j + 1), 0));
    i = j + 1;
  }
  return out;
}

/// Position of every team after each league round (for the season chart).
Map<String, List<int>> positionHistory(Competition c, {Map<String, String>? names}) {
  final league = c.matches.where((m) => m.stage == Stage.league).toList();
  final rounds = league.map((m) => m.round).toSet().toList()..sort();
  final out = {for (final t in c.teamIds) t: <int>[]};
  for (final r in rounds) {
    final upto = league.where((m) => m.round <= r).toList();
    if (!upto.any((m) => m.round == r && m.played)) continue;
    final t = buildTable(c, c.teamIds, upto, names: names, applyAdjustments: false);
    for (var i = 0; i < t.length; i++) {
      out[t[i].teamId]!.add(i + 1);
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Knockout
// ---------------------------------------------------------------------------

class TieResult {
  final String? winner;
  final String? loser;
  final String summary; // e.g. "3–2 on aggregate", "won 4–3 on penalties"
  const TieResult(this.winner, this.loser, this.summary);
}

/// Decides a knockout tie (one or two legs). Winner is null while undecided.
TieResult resolveTie(Competition c, Fixture f) {
  final legs = c.matches.where((m) => m.tieId != null && m.tieId == f.tieId).toList()..sort((a, b) => a.leg.compareTo(b.leg));
  final last = legs.isEmpty ? f : legs.last;
  if (legs.isEmpty || legs.any((m) => !m.played) || !last.hasTeams) return const TieResult(null, null, '');
  if (legs.length == 1) {
    final m = legs.first;
    if (m.homeGoals != m.awayGoals) {
      final w = m.homeGoals > m.awayGoals ? m.homeId : m.awayId;
      return TieResult(w, w == m.homeId ? m.awayId : m.homeId, m.extraTime ? 'after extra time' : '');
    }
    if (m.hasPens && m.homePens != m.awayPens) {
      final w = m.homePens! > m.awayPens! ? m.homeId : m.awayId;
      final hi = m.homePens! > m.awayPens! ? m.homePens : m.awayPens, lo = m.homePens! > m.awayPens! ? m.awayPens : m.homePens;
      return TieResult(w, w == m.homeId ? m.awayId : m.homeId, 'won $hi–$lo on penalties');
    }
    return const TieResult(null, null, 'level: enter extra time or penalties');
  }
  // Two legs: the team at home in leg 2 is "b".
  final l1 = legs[0], l2 = legs[1];
  final b = l2.homeId!, a = l2.awayId!;
  int agg(String t) => [l1, l2].fold(0, (s, m) => s + (m.homeId == t ? m.homeGoals : (m.awayId == t ? m.awayGoals : 0)));
  int away(String t) => [l1, l2].fold(0, (s, m) => s + (m.awayId == t ? m.awayGoals : 0));
  final ga = agg(a), gb = agg(b);
  if (ga != gb) {
    final w = ga > gb ? a : b;
    return TieResult(w, w == a ? b : a, '${ga > gb ? ga : gb}–${ga > gb ? gb : ga} on aggregate');
  }
  if (c.rules.awayGoalsRule && away(a) != away(b)) {
    final w = away(a) > away(b) ? a : b;
    return TieResult(w, w == a ? b : a, '$ga–$gb on aggregate, away goals');
  }
  if (l2.hasPens && l2.homePens != l2.awayPens) {
    final w = l2.homePens! > l2.awayPens! ? b : a;
    final hi = l2.homePens! > l2.awayPens! ? l2.homePens : l2.awayPens, lo = l2.homePens! > l2.awayPens! ? l2.awayPens : l2.homePens;
    return TieResult(w, w == a ? b : a, '$ga–$gb on aggregate, won $hi–$lo on penalties');
  }
  return TieResult(null, null, '$ga–$gb on aggregate: needs extra time or penalties');
}

/// Pushes every decided tie's winner (and semi-final losers) into the next
/// fixtures. Safe to call after any result changes.
void advanceKnockout(Competition c) {
  for (final f in c.knockoutMatches.toList()) {
    if (f.leg == 1) continue; // decided on the second leg
    final r = resolveTie(c, f);
    void put(String? targetId, bool home, String? team) {
      final t = c.match(targetId);
      if (t == null) return;
      final legs = c.matches.where((m) => m.tieId != null && m.tieId == t.tieId).toList();
      for (final m in legs.isEmpty ? [t] : legs) {
        final h = m.leg == 2 ? !home : home;
        if (h) {
          if (m.homeId != team && !m.played) m.homeId = team;
        } else {
          if (m.awayId != team && !m.played) m.awayId = team;
        }
      }
    }

    if (r.winner != null) {
      put(f.nextId, f.nextHome, r.winner);
      put(f.loserNextId, f.loserNextHome, r.loser);
    }
  }
}

/// The champion, if the final has been decided.
String? championOf(Competition c, List<Standing> Function() leagueTable) {
  if (c.format == Format.league) {
    if (c.matches.isEmpty || c.matches.any((m) => !m.played && m.status != MatchStatus.cancelled)) return null;
    final t = leagueTable();
    return t.isEmpty ? null : t.first.teamId;
  }
  final ko = c.knockoutMatches.toList();
  if (ko.isEmpty) return null;
  final maxRound = ko.map((m) => m.round).reduce((a, b) => a > b ? a : b);
  final finals = ko.where((m) => m.round == maxRound && m.slot == 0).toList();
  if (finals.isEmpty) return null;
  return resolveTie(c, finals.first).winner;
}

// ---------------------------------------------------------------------------
// Player statistics and discipline
// ---------------------------------------------------------------------------

class PlayerStats {
  final String playerId;
  final String teamId;
  int apps = 0, starts = 0, subOn = 0, goals = 0, pens = 0, assists = 0, ownGoals = 0, yellows = 0, reds = 0, cleanSheets = 0, motm = 0;
  int minutes = 0;
  PlayerStats(this.playerId, this.teamId);
  int get contributions => goals + assists;
}

/// Aggregates per-player statistics across a competition's finished matches.
Map<String, PlayerStats> playerStats(Competition c, Team? Function(String id) team) {
  final out = <String, PlayerStats>{};
  PlayerStats get(String pid, String tid) => out.putIfAbsent(pid, () => PlayerStats(pid, tid));
  final len = c.rules.matchMinutes;
  for (final f in c.matches.where((m) => m.played && m.hasTeams)) {
    for (final home in [true, false]) {
      final tid = f.teamId(home)!;
      final lu = f.lineup(home);
      final subs = f.events.where((e) => e.home == home && e.type == EventType.sub).toList();
      final reds = f.events.where((e) => e.home == home && (e.type == EventType.red || e.type == EventType.secondYellow));
      int offAt(String pid) {
        var m = len + (f.extraTime ? 30 : 0);
        for (final s in subs) {
          if (s.otherId == pid) m = s.minute;
        }
        for (final r in reds) {
          if (r.playerId == pid && r.minute < m) m = r.minute;
        }
        return m;
      }

      for (final pid in lu.starters) {
        final s = get(pid, tid);
        s.apps++;
        s.starts++;
        s.minutes += offAt(pid);
      }
      for (final e in subs) {
        if (e.playerId == null) continue;
        final s = get(e.playerId!, tid);
        s.apps++;
        s.subOn++;
        s.minutes += (offAt(e.playerId!) - e.minute).clamp(0, 200).toInt();
      }
      // Clean sheet for the starting goalkeeper (first starter).
      if (lu.starters.isNotEmpty && f.goals(!home) == 0) {
        final gk = team(tid)?.player(lu.starters.first);
        if (gk != null && gk.position == Position.gk) get(gk.id, tid).cleanSheets++;
      }
    }
    for (final e in f.events) {
      final tid = f.teamId(e.home)!;
      if (e.playerId == null) continue;
      switch (e.type) {
        case EventType.goal:
          get(e.playerId!, tid).goals++;
          break;
        case EventType.penaltyGoal:
          get(e.playerId!, tid)
            ..goals++
            ..pens++;
          break;
        case EventType.ownGoal:
          // Own goal: the player belongs to the other side.
          get(e.playerId!, f.teamId(!e.home)!).ownGoals++;
          break;
        case EventType.yellow:
          get(e.playerId!, tid).yellows++;
          break;
        case EventType.secondYellow:
        case EventType.red:
          get(e.playerId!, tid).reds++;
          break;
        default:
          break;
      }
      if ((e.type == EventType.goal || e.type == EventType.penaltyGoal) && e.otherId != null) {
        get(e.otherId!, tid).assists++;
      }
    }
    if (f.motmId != null) {
      final side = f.homeLineup.starters.contains(f.motmId) || f.homeLineup.bench.contains(f.motmId) ? f.homeId! : f.awayId!;
      get(f.motmId!, side).motm++;
    }
  }
  return out;
}

class Suspension {
  final String playerId;
  final String teamId;
  int remaining; // matches still to serve
  final String reason;
  Suspension(this.playerId, this.teamId, this.remaining, this.reason);
}

class Violation {
  final Fixture fixture;
  final String playerId;
  final String teamId;
  const Violation(this.fixture, this.playerId, this.teamId);
}

class Discipline {
  final Map<String, Suspension> active; // playerId → current ban
  final Map<String, int> yellowCount; // running yellows toward the next ban
  final List<Violation> violations; // suspended players fielded
  const Discipline(this.active, this.yellowCount, this.violations);

  bool isSuspended(String playerId) => (active[playerId]?.remaining ?? 0) > 0;
}

/// Replays cards in match order: yellow accumulation, straight reds and
/// second yellows create bans served in the team's next matches.
Discipline discipline(Competition c, {DateTime? asOf}) {
  final r = c.rules;
  final bans = <String, Suspension>{};
  final yellows = <String, int>{};
  final violations = <Violation>[];
  final list = c.matches.where((m) => m.played && m.hasTeams).toList()
    ..sort((a, b) {
      final t = _when(a).compareTo(_when(b));
      if (t != 0) return t;
      final s = a.stage.index.compareTo(b.stage.index);
      return s != 0 ? s : a.round.compareTo(b.round);
    });
  for (final f in list) {
    if (asOf != null && f.kickoff != null && !f.kickoff!.isBefore(asOf)) break;
    // Serve existing bans for both teams.
    for (final home in [true, false]) {
      final tid = f.teamId(home)!;
      final lu = f.lineup(home);
      final onPitch = {...lu.starters, ...f.events.where((e) => e.home == home && e.type == EventType.sub).map((e) => e.playerId).whereType<String>()};
      for (final b in bans.values.where((b) => b.teamId == tid && b.remaining > 0)) {
        if (onPitch.contains(b.playerId)) violations.add(Violation(f, b.playerId, tid));
        b.remaining--;
      }
    }
    // New cards.
    for (final e in f.sortedEvents) {
      if (e.playerId == null || !e.type.isCard) continue;
      final tid = f.teamId(e.home)!;
      final pid = e.playerId!;
      void ban(int n, String why) {
        if (n <= 0) return;
        final cur = bans[pid];
        final rem = (cur?.remaining ?? 0) + n;
        bans[pid] = Suspension(pid, tid, rem, cur != null && cur.remaining > 0 ? '${cur.reason}; $why' : why);
      }

      if (e.type == EventType.yellow) {
        final n = (yellows[pid] ?? 0) + 1;
        yellows[pid] = n;
        if (r.yellowLimit > 0 && n % r.yellowLimit == 0) ban(r.yellowBan, '$n yellow cards');
      } else if (e.type == EventType.secondYellow) {
        ban(r.secondYellowBan, 'sent off (two yellows)');
      } else if (e.type == EventType.red) {
        ban(r.redBan, 'straight red card');
      }
    }
  }
  bans.removeWhere((_, b) => b.remaining <= 0);
  return Discipline(bans, yellows, violations);
}
