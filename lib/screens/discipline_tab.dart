import 'package:flutter/material.dart';

import '../core/standings.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import 'home_screen.dart';

class DisciplineTab extends StatelessWidget {
  final Competition comp;
  const DisciplineTab({super.key, required this.comp});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final d = discipline(comp);
    final r = comp.rules;
    final watch = <(String, int)>[];
    if (r.yellowLimit > 1) {
      for (final e in d.yellowCount.entries) {
        if (e.value % r.yellowLimit == r.yellowLimit - 1 && !d.isSuspended(e.key)) watch.add((e.key, e.value));
      }
    }
    final fair = <String, int>{for (final id in comp.teamIds) id: 0};
    for (final f in comp.matches.where((m) => m.played && m.hasTeams)) {
      fair[f.homeId!] = (fair[f.homeId!] ?? 0) + cardPointsFor(f, true);
      fair[f.awayId!] = (fair[f.awayId!] ?? 0) + cardPointsFor(f, false);
    }
    final fairList = fair.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    Widget playerRow(String pid, String trailing, String sub, Color col) {
      final f = app.findPlayer(pid);
      return ListTile(
        leading: Crest(f?.$1, size: 26),
        title: Text(f?.$2.name ?? 'Unknown', style: TLText.body(c.ink, weight: FontWeight.w700)),
        subtitle: Text(sub, style: TLText.body(c.inkDim, size: 12)),
        trailing: Text(trailing, style: TLText.score(16, col)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
      children: [
        TLCard(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${r.yellowLimit == 0 ? 'Yellow-card accumulation off' : 'Every ${r.yellowLimit} yellows → ${r.yellowBan}-match ban'} · '
            'second yellow → ${r.secondYellowBan} · straight red → ${r.redBan}. Bans are served in the team\'s next matches in this competition.',
            style: TLText.body(c.inkDim, size: 12.5),
          ),
        ),
        if (d.violations.isNotEmpty) ...[
          SectionHeader('Ineligible players fielded', trailing: Icon(Icons.gavel_rounded, color: c.poor, size: 18)),
          TLCard(
            borderColor: c.poor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final v in d.violations)
                ListTile(
                  leading: Icon(Icons.warning_amber_rounded, color: c.poor),
                  title: Text('${app.playerName(v.playerId)} (${app.teamName(v.teamId)})', style: TLText.body(c.ink, weight: FontWeight.w600)),
                  subtitle: Text('Played while suspended: ${app.teamName(v.fixture.homeId)} v ${app.teamName(v.fixture.awayId)}'
                      '${v.fixture.kickoff == null ? '' : ', ${shortDate(v.fixture.kickoff!)}'}', style: TLText.body(c.inkDim, size: 12)),
                  onTap: () => openFixture(context, comp, v.fixture),
                ),
            ]),
          ),
        ],
        SectionHeader('Suspended now (${d.active.length})'),
        if (d.active.isEmpty)
          Text('No one is suspended.', style: TLText.body(c.inkDim, size: 13))
        else
          TLCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final s in d.active.values)
                playerRow(s.playerId, '${s.remaining} match${s.remaining == 1 ? '' : 'es'}', '${app.teamName(s.teamId)} · ${s.reason}', c.poor),
            ]),
          ),
        if (watch.isNotEmpty) ...[
          SectionHeader('One yellow from a ban (${watch.length})'),
          TLCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final w in watch) playerRow(w.$1, '${w.$2} YC', app.findPlayer(w.$1)?.$1.name ?? '', c.fair),
            ]),
          ),
        ],
        const SectionHeader('Fair play table'),
        TLCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (var i = 0; i < fairList.length; i++)
              ListTile(
                dense: true,
                leading: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 22, child: Text('${i + 1}', style: TLText.score(16, c.inkDim))),
                  Crest(app.team(fairList[i].key), size: 22),
                ]),
                title: Text(app.teamName(fairList[i].key), style: TLText.body(c.ink, weight: FontWeight.w600)),
                trailing: Text('${fairList[i].value} pts', style: TLText.reading(13, i == 0 ? c.good : c.ink, weight: FontWeight.w700)),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Text('Fair-play points: yellow 1, second yellow 3, red 3. Lower is better.', style: TLText.body(c.inkDim, size: 11.5)),
      ],
    );
  }
}
