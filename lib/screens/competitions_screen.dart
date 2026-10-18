import 'package:flutter/material.dart';

import '../core/standings.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import 'competition_wizard.dart';
import 'home_screen.dart';

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen> {
  bool _archived = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final list = app.competitions.where((x) => x.archived == _archived).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Competitions'),
        actions: [
          if (app.competitions.any((x) => x.archived))
            TextButton(onPressed: () => setState(() => _archived = !_archived), child: Text(_archived ? 'Active' : 'Archived')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompetitionWizard())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New competition'),
      ),
      body: list.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.emoji_events_outlined,
                title: _archived ? 'Nothing archived' : 'No competitions yet',
                body: 'Leagues, cups and tournaments you create appear here.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                for (final comp in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CompCard(comp: comp),
                  ),
              ],
            ),
    );
  }
}

class _CompCard extends StatelessWidget {
  final Competition comp;
  const _CompCard({required this.comp});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final champ = championOf(comp, () => app.table(comp));
    final next = comp.matches.where((m) => m.status == MatchStatus.scheduled && m.kickoff != null).toList()
      ..sort((a, b) => a.kickoff!.compareTo(b.kickoff!));
    final col = Color(comp.color);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openCompetition(context, comp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [col, col.withOpacity(0.1)])),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CompBadge(comp),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(comp.name, style: TLText.headline(c.ink, size: 21)),
                        Text('${comp.format.label} · ${comp.season.isEmpty ? '—' : comp.season}', style: TLText.body(c.inkDim, size: 12.5)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    _stat(context, '${comp.teamIds.length}', 'teams'),
                    _stat(context, '${comp.playedCount}', 'played'),
                    _stat(context, '${comp.matches.length - comp.playedCount}', 'to play'),
                    _stat(context, '${comp.matches.where((m) => m.played).fold<int>(0, (a, m) => a + m.homeGoals + m.awayGoals)}', 'goals'),
                  ]),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: comp.progress, minHeight: 6, backgroundColor: c.surface2, color: col),
                  ),
                  const SizedBox(height: 10),
                  if (champ != null)
                    Row(children: [
                      const Icon(Icons.emoji_events_rounded, color: TLColors.gold, size: 18),
                      const SizedBox(width: 6),
                      Crest(app.team(champ), size: 18),
                      const SizedBox(width: 6),
                      Text('Champion: ${app.teamName(champ)}', style: TLText.body(c.ink, size: 13, weight: FontWeight.w700)),
                    ])
                  else if (next.isNotEmpty)
                    Text('Next: ${app.teamName(next.first.homeId, next.first.homeLabel)} v ${app.teamName(next.first.awayId, next.first.awayLabel)} · ${dateTimeText(next.first.kickoff!)}',
                        style: TLText.body(c.inkDim, size: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String v, String l) {
    final c = context.tl;
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: TLText.score(22, c.ink)),
        Text(l.toUpperCase(), style: TLText.label(c.inkDim, size: 9.5)),
      ]),
    );
  }
}
