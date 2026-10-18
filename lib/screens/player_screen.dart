import 'package:flutter/material.dart';

import '../core/standings.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import 'home_screen.dart';
import 'team_screen.dart';

class PlayerScreen extends StatelessWidget {
  final Team team;
  final Player player;
  const PlayerScreen({super.key, required this.team, required this.player});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final p = player;
    final comps = app.competitions.where((x) => x.matches.any((m) => m.involves(team.id))).toList();
    final per = <(Competition, PlayerStats)>[];
    for (final comp in comps) {
      final s = playerStats(comp, app.team)[p.id];
      if (s != null) per.add((comp, s));
    }
    int sum(int Function(PlayerStats) f) => per.fold(0, (a, e) => a + f(e.$2));
    final bans = [for (final comp in comps) if (discipline(comp).active[p.id] != null) (comp, discipline(comp).active[p.id]!)];
    // Match log.
    final log = <(Competition, Fixture)>[];
    for (final comp in comps) {
      for (final m in comp.matches.where((m) => m.played)) {
        final inLu = m.homeLineup.starters.contains(p.id) || m.awayLineup.starters.contains(p.id);
        final subOn = m.events.any((e) => e.type == EventType.sub && e.playerId == p.id);
        if (inLu || subOn) log.add((comp, m));
      }
    }
    log.sort((a, b) => (b.$2.kickoff ?? DateTime(2000)).compareTo(a.$2.kickoff ?? DateTime(2000)));
    final col = teamColor(team);

    Widget big(String v, String l) => Expanded(
          child: Column(children: [
            Text(v, style: TLText.score(30, c.ink)),
            Text(l.toUpperCase(), style: TLText.label(c.inkDim, size: 9.5), textAlign: TextAlign.center),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [IconButton(tooltip: 'Edit player', icon: const Icon(Icons.edit_rounded), onPressed: () => showPlayerEditor(context, team, player: p))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(colors: [col.withOpacity(0.45), c.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: c.line),
            ),
            child: Row(children: [
              Text('${p.number ?? ''}', style: TLText.score(64, col.computeLuminance() > 0.6 ? c.ink : Colors.white)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: TLText.headline(c.ink, size: 24)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Crest(team, size: 18),
                    const SizedBox(width: 6),
                    Flexible(child: Text(team.name, style: TLText.body(c.ink, size: 13), overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 4),
                  Text([p.position.label, if (p.birth != null) 'born ${shortDate(p.birth!)}', if (p.nationality.isNotEmpty) p.nationality, if (p.captain) 'Captain'].join(' · '),
                      style: TLText.body(c.inkDim, size: 12)),
                ]),
              ),
            ]),
          ),
          for (final b in bans)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TLCard(
                borderColor: c.poor.withOpacity(0.5),
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Icon(Icons.block_rounded, color: c.poor),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Suspended in ${b.$1.name} for ${b.$2.remaining} more match${b.$2.remaining == 1 ? '' : 'es'} (${b.$2.reason}).', style: TLText.body(c.ink, size: 13))),
                ]),
              ),
            ),
          const SizedBox(height: 14),
          TLCard(
            child: Column(children: [
              Row(children: [big('${sum((s) => s.apps)}', 'Apps'), big('${sum((s) => s.goals)}', 'Goals'), big('${sum((s) => s.assists)}', 'Assists'), big('${sum((s) => s.minutes)}', 'Minutes')]),
              const SizedBox(height: 14),
              Row(children: [
                big('${sum((s) => s.yellows)}', 'Yellow'),
                big('${sum((s) => s.reds)}', 'Red'),
                big(p.position == Position.gk ? '${sum((s) => s.cleanSheets)}' : '${sum((s) => s.starts)}', p.position == Position.gk ? 'Clean sheets' : 'Starts'),
                big('${sum((s) => s.motm)}', 'POTM'),
              ]),
            ]),
          ),
          if (per.length > 1) ...[
            const SectionHeader('By competition'),
            TLCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final e in per)
                  ListTile(
                    dense: true,
                    leading: CompBadge(e.$1, size: 30),
                    title: Text(e.$1.name, style: TLText.body(c.ink, weight: FontWeight.w600)),
                    trailing: Text('${e.$2.apps} apps · ${e.$2.goals} G · ${e.$2.assists} A', style: TLText.reading(12, c.ink)),
                  ),
              ]),
            ),
          ],
          SectionHeader('Match log (${log.length})'),
          if (log.isEmpty)
            Text('Not in a recorded line-up yet.', style: TLText.body(c.inkDim, size: 13))
          else
            TLCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final (comp, m) in log)
                  () {
                    final mine = m.events.where((e) => e.playerId == p.id || (e.otherId == p.id && e.type == EventType.goal)).toList();
                    final home = m.homeId == team.id;
                    final o = outcome(m, team.id);
                    return ListTile(
                      dense: true,
                      onTap: () => openFixture(context, comp, m),
                      leading: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: o > 0 ? c.good : (o == 0 ? c.inkDim : c.poor), borderRadius: BorderRadius.circular(7)),
                        child: Text(o > 0 ? 'W' : (o == 0 ? 'D' : 'L'), style: TLText.score(14, o > 0 ? c.onAccent : Colors.white)),
                      ),
                      title: Text('${home ? 'vs' : 'at'} ${app.teamName(home ? m.awayId : m.homeId)}  ${m.homeGoals}–${m.awayGoals}',
                          style: TLText.body(c.ink, weight: FontWeight.w600)),
                      subtitle: Text('${comp.name}${m.kickoff == null ? '' : ' · ${shortDate(m.kickoff!)}'}', style: TLText.body(c.inkDim, size: 11.5)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        for (final e in mine)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: e.otherId == p.id && e.type == EventType.goal
                                ? Text('A', style: TLText.score(14, c.accent))
                                : (e.type == EventType.sub ? const SizedBox() : eventIcon(e.type, c, size: 16)),
                          ),
                        if (m.motmId == p.id) const Icon(Icons.star_rounded, color: TLColors.gold, size: 18),
                      ]),
                    );
                  }(),
              ]),
            ),
        ],
      ),
    );
  }
}
