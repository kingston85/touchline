import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/standings.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import '../widgets/inputs.dart';
import 'player_screen.dart';

enum StatKind { goals, assists, contributions, cleanSheets, yellows, reds, motm, minutes }

extension StatKindX on StatKind {
  String get label => const ['Goals', 'Assists', 'Goals + assists', 'Clean sheets', 'Yellow cards', 'Red cards', 'Player of the match', 'Minutes'][index];
  int of(PlayerStats s) => switch (this) {
        StatKind.goals => s.goals,
        StatKind.assists => s.assists,
        StatKind.contributions => s.contributions,
        StatKind.cleanSheets => s.cleanSheets,
        StatKind.yellows => s.yellows,
        StatKind.reds => s.reds,
        StatKind.motm => s.motm,
        StatKind.minutes => s.minutes,
      };
}

class StatsTab extends StatefulWidget {
  final Competition comp;
  const StatsTab({super.key, required this.comp});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  StatKind _kind = StatKind.goals;
  bool _teams = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final comp = widget.comp;
    final stats = playerStats(comp, app.team).values.where((s) => _kind.of(s) > 0).toList()
      ..sort((a, b) {
        final d = _kind.of(b).compareTo(_kind.of(a));
        if (d != 0) return d;
        return a.minutes.compareTo(b.minutes); // fewer minutes ranks higher on ties
      });
    final hasEvents = comp.matches.any((m) => m.played && m.events.isNotEmpty);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
      children: [
        Segmented<bool>(values: const [false, true], selected: _teams, label: (v) => v ? 'Teams' : 'Players', onChanged: (v) => setState(() => _teams = v)),
        const SizedBox(height: 10),
        if (_teams)
          _TeamStats(comp: comp)
        else ...[
          Segmented<StatKind>(values: StatKind.values, selected: _kind, label: (k) => k.label, onChanged: (k) => setState(() => _kind = k)),
          const SizedBox(height: 12),
          if (!hasEvents)
            const EmptyState(
              icon: Icons.insights_outlined,
              title: 'No player data yet',
              body: 'Record goals, cards and line-ups in the match centre and the leaderboards fill in automatically.',
            )
          else if (stats.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text('Nobody yet.', style: TLText.body(c.inkDim), textAlign: TextAlign.center))
          else
            TLCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                for (var i = 0; i < stats.length && i < 30; i++)
                  _LeaderRow(rank: i + 1, s: stats[i], value: _kind.of(stats[i]), max: _kind.of(stats.first), comp: comp, kind: _kind),
              ]),
            ),
        ],
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final int rank;
  final PlayerStats s;
  final int value;
  final int max;
  final Competition comp;
  final StatKind kind;
  const _LeaderRow({required this.rank, required this.s, required this.value, required this.max, required this.comp, required this.kind});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final team = app.team(s.teamId);
    final p = team?.player(s.playerId);
    final sub = switch (kind) {
      StatKind.goals => '${s.apps} apps${s.pens > 0 ? ' · ${s.pens} pen' : ''}${s.minutes > 0 && s.goals > 0 ? ' · ${(s.minutes / s.goals).round()} min/goal' : ''}',
      StatKind.cleanSheets => '${s.starts} starts',
      _ => '${s.apps} apps',
    };
    return InkWell(
      onTap: p == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(team: team!, player: p))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(children: [
          SizedBox(width: 26, child: Text('$rank', style: TLText.score(18, rank == 1 ? TLColors.gold : c.inkDim))),
          Crest(team, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p?.name ?? 'Unknown', style: TLText.body(c.ink, size: 13.5, weight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              Text('${team?.name ?? ''} · $sub', style: TLText.body(c.inkDim, size: 11.5), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: max == 0 ? 0 : value / max,
                  minHeight: 4,
                  backgroundColor: c.surface2,
                  color: rank == 1 ? TLColors.gold : teamColor(team),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Text('$value', style: TLText.score(24, c.ink)),
        ]),
      ),
    );
  }
}

class _TeamStats extends StatelessWidget {
  final Competition comp;
  const _TeamStats({required this.comp});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final rows = buildTable(comp, comp.teamIds, comp.matches, names: app.names, applyAdjustments: false)
      ..sort((a, b) => b.gf.compareTo(a.gf));
    final maxG = rows.fold<int>(1, (a, r) => math.max(a, math.max(r.gf, r.ga)));
    final cards = <String, (int, int)>{};
    for (final f in comp.matches.where((m) => m.played && m.hasTeams)) {
      for (final home in [true, false]) {
        final id = f.teamId(home)!;
        final y = f.events.where((e) => e.home == home && e.type == EventType.yellow).length;
        final r = f.events.where((e) => e.home == home && (e.type == EventType.red || e.type == EventType.secondYellow)).length;
        final cur = cards[id] ?? (0, 0);
        cards[id] = (cur.$1 + y, cur.$2 + r);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Attack & defence'),
      TLCard(
        child: Column(children: [
          Row(children: [
            const Spacer(),
            Container(width: 10, height: 10, color: c.good),
            const SizedBox(width: 4),
            Text('scored', style: TLText.body(c.inkDim, size: 11)),
            const SizedBox(width: 12),
            Container(width: 10, height: 10, color: c.poor),
            const SizedBox(width: 4),
            Text('conceded', style: TLText.body(c.inkDim, size: 11)),
          ]),
          const SizedBox(height: 8),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Crest(app.team(r.teamId), size: 20),
                const SizedBox(width: 8),
                SizedBox(width: 92, child: Text(app.team(r.teamId)?.name ?? '', style: TLText.body(c.ink, size: 12), overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: Column(children: [
                    _bar(c.good, r.gf / maxG, '${r.gf}', c),
                    const SizedBox(height: 3),
                    _bar(c.poor, r.ga / maxG, '${r.ga}', c),
                  ]),
                ),
              ]),
            ),
        ]),
      ),
      const SectionHeader('Per team'),
      TLCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: Row(children: [
              Expanded(child: Text('TEAM', style: TLText.label(c.inkDim, size: 10))),
              for (final h in ['GF/M', 'GA/M', 'CS', 'YC', 'RC'])
                SizedBox(width: 44, child: Text(h, textAlign: TextAlign.center, style: TLText.label(c.inkDim, size: 10))),
            ]),
          ),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
              child: Row(children: [
                Expanded(child: Text(app.team(r.teamId)?.name ?? '', style: TLText.body(c.ink, size: 12.5), overflow: TextOverflow.ellipsis)),
                for (final v in [
                  r.played == 0 ? '—' : (r.gf / r.played).toStringAsFixed(2),
                  r.played == 0 ? '—' : (r.ga / r.played).toStringAsFixed(2),
                  '${comp.matches.where((m) => m.played && m.involves(r.teamId) && m.goals(m.awayId == r.teamId) == 0).length}',
                  '${cards[r.teamId]?.$1 ?? 0}',
                  '${cards[r.teamId]?.$2 ?? 0}',
                ])
                  SizedBox(width: 44, child: Text(v, textAlign: TextAlign.center, style: TLText.reading(12, c.ink))),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 6),
      Text('CS = clean sheets (matches without conceding). Includes all stages.', style: TLText.body(c.inkDim, size: 11.5)),
    ]);
  }

  Widget _bar(Color col, double f, String label, TLColors c) => Row(children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Align(
              alignment: Alignment.centerLeft,
              child: Container(height: 8, width: math.max(2, box.maxWidth * f), decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4))),
            ),
          ),
        ),
        SizedBox(width: 26, child: Text(label, textAlign: TextAlign.right, style: TLText.reading(11, c.ink))),
      ]);
}
