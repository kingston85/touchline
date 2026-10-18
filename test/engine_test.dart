import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/core/demo.dart';
import 'package:touchline/core/formations.dart';
import 'package:touchline/core/scheduler.dart';
import 'package:touchline/core/setup.dart';
import 'package:touchline/core/standings.dart';
import 'package:touchline/data/models.dart';

Fixture played(String h, String a, int hg, int ag, {int round = 1, DateTime? at, Stage stage = Stage.league}) => Fixture(
      id: newId(),
      stage: stage,
      round: round,
      homeId: h,
      awayId: a,
      homeGoals: hg,
      awayGoals: ag,
      status: MatchStatus.finished,
      kickoff: at ?? DateTime(2026, 1, round),
    );

void main() {
  group('Round robin', () {
    for (final n in [4, 5, 6, 7, 8, 12]) {
      test('$n teams: every pair once, one match per team per round', () {
        final teams = [for (var i = 0; i < n; i++) 'T$i'];
        final rounds = roundRobin(teams);
        expect(rounds.length, n.isEven ? n - 1 : n);
        final pairs = <String>{};
        for (final r in rounds) {
          final seen = <String>{};
          for (final (h, a) in r) {
            expect(seen.add(h), isTrue);
            expect(seen.add(a), isTrue);
            final k = ([h, a]..sort()).join('-');
            expect(pairs.add(k), isTrue, reason: 'duplicate $k');
          }
        }
        expect(pairs.length, n * (n - 1) ~/ 2);
      });
    }
    test('home games are balanced', () {
      final teams = [for (var i = 0; i < 8; i++) 'T$i'];
      final homes = <String, int>{};
      for (final r in roundRobin(teams)) {
        for (final (h, _) in r) {
          homes[h] = (homes[h] ?? 0) + 1;
        }
      }
      final v = homes.values.toList()..sort();
      expect(v.last - v.first, lessThanOrEqualTo(1));
    });
    test('double round robin reverses venues', () {
      final teams = ['A', 'B', 'C', 'D'];
      final all = roundRobin(teams, legs: 2).expand((r) => r).map((p) => '${p.$1}>${p.$2}').toSet();
      expect(all.length, 12);
    });
  });

  group('Knockout', () {
    test('seed positions keep top seeds apart', () {
      expect(seedPositions(8), [1, 8, 4, 5, 2, 7, 3, 6]);
    });
    test('byes go to the top seeds', () {
      final c = Competition(id: 'c', name: 'Cup', format: Format.knockout, teamIds: [for (var i = 1; i <= 6; i++) 'S$i']);
      generateKnockout(c, [for (final t in c.teamIds) Entrant(t)]);
      final r0 = c.knockoutMatches.where((m) => m.round == 0).toList();
      expect(r0.length, 2);
      final r1 = c.knockoutMatches.where((m) => m.round == 1).toList();
      final placed = {...r1.map((m) => m.homeId), ...r1.map((m) => m.awayId)}..remove(null);
      expect(placed, containsAll(['S1', 'S2']));
      expect(c.knockoutMatches.where((m) => m.round == 2).length, 1);
    });
    test('winners advance and the final gets both teams', () {
      final c = Competition(id: 'c', name: 'Cup', format: Format.knockout, teamIds: ['A', 'B', 'C', 'D'], rules: Rules(thirdPlace: true));
      generateKnockout(c, [for (final t in c.teamIds) Entrant(t)]);
      for (final m in c.knockoutMatches.where((m) => m.round == 0)) {
        m
          ..homeGoals = 2
          ..awayGoals = 1
          ..status = MatchStatus.finished;
      }
      advanceKnockout(c);
      final fin = c.knockoutMatches.firstWhere((m) => m.round == 1 && m.slot == 0);
      final third = c.knockoutMatches.firstWhere((m) => m.round == 1 && m.slot == 1);
      expect({fin.homeId, fin.awayId}, {'A', 'B'});
      expect({third.homeId, third.awayId}, {'D', 'C'});
      expect(championOf(c, () => []), isNull);
      fin
        ..homeGoals = 1
        ..awayGoals = 1
        ..homePens = 4
        ..awayPens = 5
        ..status = MatchStatus.finished;
      expect(championOf(c, () => []), fin.awayId);
    });
    test('two legs: aggregate, away goals, penalties', () {
      final c = Competition(id: 'c', name: 'Cup', format: Format.knockout, rules: Rules(koLegs: 2, awayGoalsRule: true));
      final l1 = Fixture(id: 'l1', stage: Stage.knockout, leg: 1, tieId: 't', homeId: 'A', awayId: 'B', homeGoals: 2, awayGoals: 1, status: MatchStatus.finished);
      final l2 = Fixture(id: 'l2', stage: Stage.knockout, leg: 2, tieId: 't', homeId: 'B', awayId: 'A', homeGoals: 2, awayGoals: 1, status: MatchStatus.finished);
      c.matches.addAll([l1, l2]);
      // 3-3 on aggregate, one away goal each → still level → needs penalties.
      expect(resolveTie(c, l2).winner, isNull);
      l2.awayGoals = 2; // A 4-3 on aggregate
      expect(resolveTie(c, l2).winner, 'A');
      l2
        ..homeGoals = 3
        ..awayGoals = 2; // 4-4, A two away goals vs B one
      expect(resolveTie(c, l2).winner, 'A');
      c.rules.awayGoalsRule = false;
      expect(resolveTie(c, l2).winner, isNull);
      l2
        ..homePens = 5
        ..awayPens = 3;
      expect(resolveTie(c, l2).winner, 'B');
    });
  });

  group('Standings', () {
    test('points, goal difference and head-to-head', () {
      final c = Competition(id: 'c', name: 'L', teamIds: ['A', 'B', 'C', 'D'], rules: Rules(tiebreaks: [Tiebreak.headToHead, Tiebreak.goalDifference]));
      // A and B both finish on 4 points; B has the better goal difference, A won the meeting.
      final ms = [
        played('A', 'B', 1, 0, round: 1),
        played('B', 'C', 4, 0, round: 2),
        played('B', 'D', 0, 0, round: 3),
        played('A', 'C', 0, 0, round: 4),
        played('D', 'A', 1, 0, round: 5),
        played('D', 'C', 1, 0, round: 6),
      ];
      final t = buildTable(c, c.teamIds, ms);
      expect(t.map((r) => r.teamId).toList(), ['D', 'A', 'B', 'C']);
      expect(t[0].points, 7);
      expect(t[1].points, 4);
      expect(t[2].gd, 3);
      c.rules.tiebreaks = [Tiebreak.goalDifference, Tiebreak.headToHead];
      expect(buildTable(c, c.teamIds, ms)[1].teamId, 'B');
    });
    test('point deductions apply', () {
      final c = Competition(id: 'c', name: 'L', teamIds: ['A', 'B']);
      c.adjustments.add(PointAdjustment(id: 'x', teamId: 'A', points: -4));
      final t = buildTable(c, c.teamIds, [played('A', 'B', 2, 0)]);
      expect(t.first.teamId, 'B');
      expect(t.last.points, -1);
    });
    test('form guide', () {
      final c = Competition(id: 'c', name: 'L', teamIds: ['A', 'B']);
      final t = buildTable(c, c.teamIds, [played('A', 'B', 2, 0, round: 1), played('B', 'A', 1, 1, round: 2), played('A', 'B', 0, 3, round: 3)]);
      expect(t.firstWhere((r) => r.teamId == 'A').form, ['W', 'D', 'L']);
    });
  });

  group('Discipline', () {
    test('yellow accumulation bans the next match and flags an ineligible player', () {
      final c = Competition(id: 'c', name: 'L', teamIds: ['A', 'B'], rules: Rules(yellowLimit: 2, yellowBan: 1));
      final m1 = played('A', 'B', 0, 0, round: 1)..events.add(MatchEvent(id: 'e1', type: EventType.yellow, home: true, minute: 10, playerId: 'p'));
      final m2 = played('B', 'A', 0, 0, round: 2)..events.add(MatchEvent(id: 'e2', type: EventType.yellow, home: false, minute: 20, playerId: 'p'));
      c.matches.addAll([m1, m2]);
      var d = discipline(c);
      expect(d.isSuspended('p'), isTrue);
      expect(d.active['p']!.remaining, 1);
      final m3 = played('A', 'B', 1, 0, round: 3)..homeLineup = Lineup(starters: ['p']);
      c.matches.add(m3);
      d = discipline(c);
      expect(d.isSuspended('p'), isFalse);
      expect(d.violations.single.playerId, 'p');
    });
    test('straight red uses the red-card ban length', () {
      final c = Competition(id: 'c', name: 'L', teamIds: ['A', 'B'], rules: Rules(redBan: 3));
      c.matches.add(played('A', 'B', 0, 0)..events.add(MatchEvent(id: 'e', type: EventType.red, home: true, minute: 50, playerId: 'q')));
      expect(discipline(c).active['q']!.remaining, 3);
    });
  });

  group('Setup', () {
    test('fixture counts match the preview', () {
      for (final f in Format.values) {
        for (final n in [6, 8, 11, 16]) {
          final c = Competition(id: 'c', name: 'X', format: f, teamIds: [for (var i = 0; i < n; i++) 'T$i'], rules: Rules(groups: 2, advance: 2, legs: 1, thirdPlace: true));
          buildFixtures(c, start: DateTime(2026, 1, 1), seed: 1);
          expect(c.matches.length, previewMatchCount(f, n, c.rules), reason: '${f.name} $n');
        }
      }
    });
    test('groups fill the bracket from the tables', () {
      final c = Competition(id: 'c', name: 'X', format: Format.groupsKnockout, teamIds: [for (var i = 0; i < 8; i++) 'T$i'], rules: Rules(groups: 2, advance: 2, legs: 1));
      buildFixtures(c, start: DateTime(2026, 1, 1), randomDraw: false);
      expect(c.groups['A'], ['T0', 'T2', 'T4', 'T6']);
      for (final m in c.matches.where((m) => m.stage == Stage.group)) {
        m
          ..homeGoals = m.homeId!.compareTo(m.awayId!) < 0 ? 1 : 0
          ..status = MatchStatus.finished;
      }
      expect(fillKnockoutFromGroups(c), 4);
      final semis = c.knockoutMatches.where((m) => m.round == 0).toList();
      expect(semis.every((m) => m.hasTeams), isTrue);
      // Group winners never meet their own runner-up in the first round.
      for (final m in semis) {
        expect(m.homeLabel[0] == m.awayLabel[0], isFalse);
      }
    });
  });

  group('Line-ups', () {
    test('formation slots and auto pick', () {
      expect(formationSlots('4-3-3').length, 11);
      expect(slotRole('4-3-3', 0), Position.gk);
      expect(slotRole('4-3-3', 1), Position.df);
      expect(slotRole('4-3-3', 10), Position.fw);
      final t = Team(id: 't', name: 'T', players: [
        for (var i = 0; i < 18; i++)
          Player(id: 'p$i', name: 'P$i', number: i + 1, position: i < 2 ? Position.gk : (i < 8 ? Position.df : (i < 14 ? Position.mf : Position.fw))),
      ]);
      final (xi, bench) = autoLineup(t, '4-4-2', unavailable: {'p0'});
      expect(xi.length, 11);
      expect(xi.first, 'p1');
      expect(xi.contains('p0'), isFalse);
      expect(bench.length, 6);
    });
  });

  group('Demo & storage', () {
    test('demo builds and survives a JSON round trip', () {
      final (teams, comps) = buildDemo();
      expect(teams.length, 10);
      final league = comps.first;
      expect(league.matches.length, 90);
      expect(league.matches.where((m) => m.played).length, greaterThan(40));
      final cup = comps.last;
      expect(cup.knockoutMatches.where((m) => m.round == 1 && m.slot == 0).single.hasTeams, isTrue);
      final back = Competition.fromJson(jsonDecode(jsonEncode(league.toJson())) as Map<String, dynamic>);
      expect(back.matches.length, league.matches.length);
      expect(back.matches.first.events.length, league.matches.first.events.length);
      final t = Team.fromJson(jsonDecode(jsonEncode(teams.first.toJson())) as Map<String, dynamic>);
      expect(t.players.length, teams.first.players.length);
      Team? find(String id) => teams.where((x) => x.id == id).firstOrNull;
      final stats = playerStats(league, find);
      final goals = stats.values.fold<int>(0, (a, s) => a + s.goals + s.ownGoals);
      final total = league.matches.where((m) => m.played).fold<int>(0, (a, m) => a + m.homeGoals + m.awayGoals);
      expect(goals, total);
    });
  });
}
