import 'package:flutter/material.dart';

import '../core/standings.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import 'competition_screen.dart';
import 'competition_wizard.dart';
import 'fixture_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final now = DateTime.now();
    final all = app.allFixtures.where((e) => e.$2.hasTeams || e.$2.homeLabel.isNotEmpty).toList();
    final live = all.where((e) => e.$2.status == MatchStatus.live).toList();
    final upcoming = all.where((e) => e.$2.status == MatchStatus.scheduled && e.$2.kickoff != null && !e.$2.kickoff!.isBefore(DateTime(now.year, now.month, now.day))).toList()
      ..sort((a, b) => a.$2.kickoff!.compareTo(b.$2.kickoff!));
    final results = all.where((e) => e.$2.played).toList()
      ..sort((a, b) => (b.$2.kickoff ?? DateTime(2000)).compareTo(a.$2.kickoff ?? DateTime(2000)));
    final overdue = all.where((e) => e.$2.status == MatchStatus.scheduled && e.$2.hasTeams && e.$2.kickoff != null && e.$2.kickoff!.isBefore(now.subtract(const Duration(hours: 3)))).length;

    Widget group(String title, List<(Competition, Fixture)> list, {bool showDay = false}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title),
          TLCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: c.line),
                  FixtureTile(
                    comp: list[i].$1,
                    fixture: list[i].$2,
                    showComp: true,
                    showRound: true,
                    onTap: () => openFixture(context, list[i].$1, list[i].$2),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    // Upcoming grouped by day.
    final byDay = <DateTime, List<(Competition, Fixture)>>{};
    for (final e in upcoming.take(14)) {
      final d = DateTime(e.$2.kickoff!.year, e.$2.kickoff!.month, e.$2.kickoff!.day);
      (byDay[d] ??= []).add(e);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 132,
            backgroundColor: c.bg,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('TOUCH', style: TLText.headline(c.ink, size: 24)),
                  Text('LINE', style: TLText.headline(c.accent, size: 24)),
                ],
              ),
              background: CustomPaint(painter: _HeroLines(c.accent.withOpacity(0.07))),
            ),
            actions: [
              IconButton(
                tooltip: 'New competition',
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompetitionWizard())),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(dayDate(now).toUpperCase(), style: TLText.label(c.inkDim)),
                if (app.hasDemo) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.accent.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, color: c.accent),
                      const SizedBox(width: 10),
                      Expanded(child: Text('A demo league and cup are loaded so you can explore. Remove them any time under More.', style: TLText.body(c.ink, size: 13))),
                    ]),
                  ),
                ],
                if (app.competitions.isEmpty)
                  EmptyState(
                    icon: Icons.emoji_events_rounded,
                    title: 'Start your first competition',
                    body: 'Create a league, a knockout cup or a groups + knockout tournament. Fixtures are generated for you.',
                    action: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompetitionWizard())),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New competition'),
                    ),
                  ),
                if (overdue > 0) ...[
                  const SizedBox(height: 12),
                  TLCard(
                    borderColor: c.fair.withOpacity(0.5),
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Icon(Icons.pending_actions_rounded, color: c.fair),
                      const SizedBox(width: 10),
                      Expanded(child: Text('$overdue past match${overdue == 1 ? '' : 'es'} still need a result.', style: TLText.body(c.ink, size: 13))),
                    ]),
                  ),
                ],
                if (live.isNotEmpty) ...[
                  SectionHeader('Live now', trailing: const LiveDot()),
                  for (final e in live)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TLCard(
                        borderColor: c.poor.withOpacity(0.45),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: FixtureTile(comp: e.$1, fixture: e.$2, showComp: true, onTap: () => openFixture(context, e.$1, e.$2)),
                      ),
                    ),
                ],
                for (final d in byDay.entries)
                  group(sameDay(d.key, now) ? 'Today' : (sameDay(d.key, now.add(const Duration(days: 1))) ? 'Tomorrow' : dayDate(d.key)), d.value),
                if (results.isNotEmpty) group('Latest results', results.take(6).toList()),
                if (app.competitions.isNotEmpty) ...[
                  const SectionHeader('Competitions'),
                  for (final comp in app.competitions.where((x) => !x.archived)) _CompSummary(comp: comp),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompSummary extends StatelessWidget {
  final Competition comp;
  const _CompSummary({required this.comp});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    String leader = '';
    if (comp.format == Format.league && comp.matches.any((m) => m.played)) {
      final t = app.table(comp);
      if (t.isNotEmpty) leader = '${app.teamName(t.first.teamId)} lead on ${t.first.points} pts';
    }
    final champ = championOf(comp, () => app.table(comp));
    final stats = playerStats(comp, app.team).values.toList()..sort((a, b) => b.goals.compareTo(a.goals));
    final top = stats.isNotEmpty && stats.first.goals > 0 ? stats.first : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TLCard(
        onTap: () => openCompetition(context, comp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CompBadge(comp, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(comp.name, style: TLText.body(c.ink, weight: FontWeight.w700)),
                  Text('${comp.format.label} · ${comp.season} · ${comp.teamIds.length} teams', style: TLText.body(c.inkDim, size: 12)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: c.inkDim),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: comp.progress,
                minHeight: 6,
                backgroundColor: c.surface2,
                color: Color(comp.color),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text('${comp.playedCount}/${comp.matches.length} played', style: TLText.reading(11.5, c.inkDim)),
              const Spacer(),
              if (champ != null)
                Tag('🏆 ${app.teamName(champ)}', color: TLColors.gold)
              else if (leader.isNotEmpty)
                Flexible(child: Text(leader, style: TLText.body(c.ink, size: 12, weight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ]),
            if (top != null) ...[
              const SizedBox(height: 4),
              Text('Top scorer: ${app.playerName(top.playerId)} (${top.goals})', style: TLText.body(c.inkDim, size: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroLines extends CustomPainter {
  final Color color;
  _HeroLines(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(s.width * 0.85, s.height * 0.55), s.height * 0.55, p);
    canvas.drawLine(Offset(s.width * 0.85, 0), Offset(s.width * 0.85, s.height), p);
    canvas.drawCircle(Offset(s.width * 0.85, s.height * 0.55), 4, p..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_HeroLines o) => o.color != color;
}

void openFixture(BuildContext context, Competition c, Fixture f) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FixtureScreen(comp: c, fixture: f)));

void openCompetition(BuildContext context, Competition c) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompetitionScreen(comp: c)));

void goTab(BuildContext context, int i) => context.findAncestorStateOfType<ShellState>()?.go(i);
