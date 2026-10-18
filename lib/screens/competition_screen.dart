import 'package:flutter/material.dart';

import '../core/reports.dart';
import '../core/setup.dart';
import '../core/standings.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import '../widgets/share.dart';
import 'bracket_tab.dart';
import 'competition_settings.dart';
import 'discipline_tab.dart';
import 'fixtures_tab.dart';
import 'home_screen.dart';
import 'stats_tab.dart';
import 'table_tab.dart';

class CompetitionScreen extends StatelessWidget {
  final Competition comp;
  const CompetitionScreen({super.key, required this.comp});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final hasKo = comp.format != Format.league;
    final hasTable = comp.format != Format.knockout;
    final tabs = <(String, Widget)>[
      ('Overview', _Overview(comp: comp)),
      ('Fixtures', FixturesTab(comp: comp)),
      if (hasTable) (comp.format == Format.league ? 'Table' : 'Groups', TableTab(comp: comp)),
      if (hasKo) ('Bracket', BracketTab(comp: comp)),
      ('Stats', StatsTab(comp: comp)),
      ('Discipline', DisciplineTab(comp: comp)),
    ];
    final col = Color(comp.color);
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, inner) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 150,
              backgroundColor: c.bg,
              surfaceTintColor: Colors.transparent,
              title: Text(comp.name, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(
                  tooltip: 'Export PDF',
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  onPressed: () => _exportMenu(context, app),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => _menu(context, app, v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'settings', child: Text('Settings, rules & zones')),
                    const PopupMenuItem(value: 'csv', child: Text('Export results (CSV)')),
                    const PopupMenuItem(value: 'regen', child: Text('Regenerate fixtures')),
                    PopupMenuItem(value: 'archive', child: Text(comp.archived ? 'Restore from archive' : 'Archive')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete competition')),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [col.withOpacity(0.32), c.bg],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 96, 20, 0),
                  alignment: Alignment.topLeft,
                  child: Row(children: [
                    CompBadge(comp, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${comp.format.label} · ${comp.season} · ${comp.teamIds.length} teams',
                          style: TLText.body(c.inkDim, size: 12.5), overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
              ),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: col,
                labelColor: c.ink,
                unselectedLabelColor: c.inkDim,
                labelStyle: const TextStyle(fontFamily: TLText.sans, fontWeight: FontWeight.w700, fontSize: 13.5),
                dividerColor: c.line,
                tabs: [for (final t in tabs) Tab(text: t.$1)],
              ),
            ),
          ],
          body: TabBarView(children: [for (final t in tabs) t.$2]),
        ),
      ),
    );
  }

  Future<void> _exportMenu(BuildContext context, AppState app) async {
    final c = context.tl;
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final e in [
            ('standings', Icons.leaderboard_rounded, 'Standings', 'Table(s) with zones and form'),
            ('fixtures', Icons.calendar_month_rounded, 'Fixtures & results', 'Every match by round'),
            ('stats', Icons.insights_rounded, 'Player statistics', 'Scorers, assists, clean sheets, cards'),
            ('full', Icons.menu_book_rounded, 'Full competition report', 'All of the above plus discipline'),
          ])
            ListTile(
              leading: Icon(e.$2, color: c.accent),
              title: Text(e.$3, style: TLText.body(c.ink, weight: FontWeight.w600)),
              subtitle: Text(e.$4, style: TLText.body(c.inkDim, size: 12)),
              onTap: () => Navigator.pop(context, e.$1),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (v == null || !context.mounted) return;
    final bytes = await Reports.competition(app, comp, v);
    if (context.mounted) {
      await shareBytes(context, '${safeName(comp.name)}_$v.pdf', bytes, 'application/pdf', subject: comp.name);
    }
  }

  Future<void> _menu(BuildContext context, AppState app, String v) async {
    switch (v) {
      case 'settings':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompetitionSettings(comp: comp)));
        break;
      case 'csv':
        shareText(context, '${safeName(comp.name)}_results.csv', Reports.resultsCsv(app, comp), 'text/csv');
        break;
      case 'archive':
        app.update(() => comp.archived = !comp.archived);
        break;
      case 'regen':
        final ok = await _confirm(context, 'Regenerate fixtures?',
            'All ${comp.matches.length} fixtures, results and events in ${comp.name} will be replaced by a fresh schedule.');
        if (ok && context.mounted) {
          final first = comp.matches.map((m) => m.kickoff).whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
          app.update(() => buildFixtures(comp, start: first ?? DateTime.now().add(const Duration(days: 7)), team: app.team));
        }
        break;
      case 'delete':
        final ok = await _confirm(context, 'Delete ${comp.name}?', 'This removes the competition and all its results. Teams stay in your library.');
        if (ok && context.mounted) {
          app.update(() => app.competitions.remove(comp));
          Navigator.pop(context);
        }
        break;
    }
  }
}

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
      ],
    ),
  );
  return r == true;
}

class _Overview extends StatelessWidget {
  final Competition comp;
  const _Overview({required this.comp});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final champ = championOf(comp, () => app.table(comp));
    final played = comp.matches.where((m) => m.played).toList();
    final goals = played.fold<int>(0, (a, m) => a + m.homeGoals + m.awayGoals);
    final stats = playerStats(comp, app.team).values.toList();
    final scorers = [...stats]..sort((a, b) => b.goals != a.goals ? b.goals.compareTo(a.goals) : a.apps.compareTo(b.apps));
    final next = comp.matches.where((m) => m.status == MatchStatus.scheduled || m.status == MatchStatus.live).toList()
      ..sort((a, b) => (a.kickoff ?? DateTime(2100)).compareTo(b.kickoff ?? DateTime(2100)));
    final recent = [...played]..sort((a, b) => (b.kickoff ?? DateTime(2000)).compareTo(a.kickoff ?? DateTime(2000)));
    final groupsDone = comp.format == Format.groupsKnockout &&
        comp.matches.where((m) => m.stage == Stage.group).every((m) => m.played) &&
        comp.knockoutMatches.any((m) => m.round == 0 && !m.played && (m.homeId == null || m.awayId == null));
    Fixture? biggest;
    for (final m in played) {
      if (biggest == null || (m.homeGoals - m.awayGoals).abs() > (biggest.homeGoals - biggest.awayGoals).abs()) biggest = m;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        if (champ != null) _ChampionBanner(team: app.team(champ), comp: comp),
        if (groupsDone || comp.format == Format.groupsKnockout && comp.knockoutMatches.any((m) => !m.hasTeams && !m.played))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TLCard(
              borderColor: c.accent.withOpacity(0.5),
              child: Row(children: [
                Icon(Icons.account_tree_rounded, color: c.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(groupsDone ? 'Group stage complete. Put the qualifiers into the bracket.' : 'Knockout slots fill from the group tables when each group finishes.',
                      style: TLText.body(c.ink, size: 13)),
                ),
                TextButton(
                  onPressed: () {
                    final n = fillKnockoutFromGroups(comp, names: app.names, force: !groupsDone);
                    app.update(() {});
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(n == 0 ? 'Nothing to fill yet.' : 'Bracket updated ($n places).')));
                  },
                  child: Text(groupsDone ? 'Fill bracket' : 'Fill now'),
                ),
              ]),
            ),
          ),
        Row(children: [
          _kpi(context, '${played.length}', 'Played', '${comp.matches.length - played.length} to play'),
          const SizedBox(width: 8),
          _kpi(context, '$goals', 'Goals', played.isEmpty ? '—' : '${(goals / played.length).toStringAsFixed(2)} per match'),
          const SizedBox(width: 8),
          _kpi(context, '${played.fold<int>(0, (a, m) => a + m.events.where((e) => e.type.isCard).length)}', 'Cards',
              '${played.fold<int>(0, (a, m) => a + m.events.where((e) => e.type == EventType.red || e.type == EventType.secondYellow).length)} red'),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: comp.progress, minHeight: 8, backgroundColor: c.surface2, color: Color(comp.color)),
        ),
        const SizedBox(height: 4),
        Text('${(comp.progress * 100).toStringAsFixed(0)}% of the schedule complete', style: TLText.body(c.inkDim, size: 12)),
        if (next.isNotEmpty) ...[
          const SectionHeader('Next up'),
          TLCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final f in next.take(4)) FixtureTile(comp: comp, fixture: f, showRound: true, onTap: () => openFixture(context, comp, f)),
            ]),
          ),
        ],
        if (comp.format == Format.league && played.isNotEmpty) ...[
          const SectionHeader('Top of the table'),
          _MiniTable(comp: comp),
        ],
        if (scorers.isNotEmpty && scorers.first.goals > 0) ...[
          const SectionHeader('Golden boot'),
          TLCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              for (var i = 0; i < scorers.length && i < 5 && scorers[i].goals > 0; i++)
                ListTile(
                  dense: true,
                  leading: SizedBox(width: 22, child: Text('${i + 1}', style: TLText.score(17, i == 0 ? TLColors.gold : c.inkDim))),
                  title: Text(app.playerName(scorers[i].playerId), style: TLText.body(c.ink, weight: FontWeight.w600)),
                  subtitle: Row(children: [
                    Crest(app.team(scorers[i].teamId), size: 14),
                    const SizedBox(width: 6),
                    Text(app.teamName(scorers[i].teamId), style: TLText.body(c.inkDim, size: 12)),
                  ]),
                  trailing: Text('${scorers[i].goals}', style: TLText.score(22, c.ink)),
                ),
            ]),
          ),
        ],
        if (recent.isNotEmpty) ...[
          const SectionHeader('Latest results'),
          TLCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final f in recent.take(5)) FixtureTile(comp: comp, fixture: f, showRound: true, onTap: () => openFixture(context, comp, f)),
            ]),
          ),
        ],
        if (biggest != null) ...[
          const SectionHeader('Records'),
          TLCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _record(context, 'Biggest win', '${app.teamName(biggest.homeId)} ${biggest.homeGoals}–${biggest.awayGoals} ${app.teamName(biggest.awayId)}'),
              () {
                final m = played.reduce((a, b) => a.homeGoals + a.awayGoals >= b.homeGoals + b.awayGoals ? a : b);
                return _record(context, 'Most goals in a match', '${app.teamName(m.homeId)} ${m.homeGoals}–${m.awayGoals} ${app.teamName(m.awayId)}');
              }(),
              _record(context, 'Home wins / draws / away wins',
                  '${played.where((m) => m.homeGoals > m.awayGoals).length} / ${played.where((m) => m.homeGoals == m.awayGoals).length} / ${played.where((m) => m.homeGoals < m.awayGoals).length}'),
              if (played.any((m) => m.attendance != null))
                _record(context, 'Total attendance', '${played.fold<int>(0, (a, m) => a + (m.attendance ?? 0))}'),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _record(BuildContext context, String k, String v) {
    final c = context.tl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PanelLabel(k),
        const SizedBox(height: 2),
        Text(v, style: TLText.body(c.ink, weight: FontWeight.w600)),
      ]),
    );
  }

  Widget _kpi(BuildContext context, String v, String l, String sub) {
    final c = context.tl;
    return Expanded(
      child: TLCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PanelLabel(l),
          const SizedBox(height: 4),
          Text(v, style: TLText.score(28, c.ink)),
          Text(sub, style: TLText.body(c.inkDim, size: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _ChampionBanner extends StatelessWidget {
  final Team? team;
  final Competition comp;
  const _ChampionBanner({required this.team, required this.comp});

  @override
  Widget build(BuildContext context) {
    final c = context.tl;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [TLColors.gold.withOpacity(0.35), teamColor(team).withOpacity(0.25)]),
        border: Border.all(color: TLColors.gold.withOpacity(0.6)),
      ),
      child: Row(children: [
        Crest(team, size: 54),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CHAMPIONS', style: TLText.label(TLColors.gold, size: 12)),
            Text(team?.name ?? '', style: TLText.headline(c.ink, size: 26)),
            Text('${comp.name} ${comp.season}', style: TLText.body(c.inkDim, size: 12.5)),
          ]),
        ),
        const Icon(Icons.emoji_events_rounded, color: TLColors.gold, size: 42),
      ]),
    );
  }
}

class _MiniTable extends StatelessWidget {
  final Competition comp;
  const _MiniTable({required this.comp});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final t = app.table(comp);
    return TLCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        for (var i = 0; i < t.length && i < 5; i++)
          ListTile(
            dense: true,
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 22, child: Text('${i + 1}', style: TLText.score(17, c.inkDim))),
              Crest(app.team(t[i].teamId), size: 22),
            ]),
            title: Text(app.teamName(t[i].teamId), style: TLText.body(c.ink, weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            subtitle: FormGuide(t[i].last5, size: 14),
            trailing: Text('${t[i].points}', style: TLText.score(22, c.ink)),
          ),
      ]),
    );
  }
}
