import 'package:flutter/material.dart';

import '../core/reports.dart';
import '../core/standings.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import '../widgets/inputs.dart';
import '../widgets/share.dart';
import 'event_sheet.dart';
import 'lineup_editor.dart';
import 'live_screen.dart';

enum _Tab { timeline, lineups, info, h2h }

class FixtureScreen extends StatefulWidget {
  final Competition comp;
  final Fixture fixture;
  const FixtureScreen({super.key, required this.comp, required this.fixture});

  @override
  State<FixtureScreen> createState() => _FixtureScreenState();
}

class _FixtureScreenState extends State<FixtureScreen> {
  _Tab _tab = _Tab.timeline;
  bool _homeLineup = true;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final comp = widget.comp;
    final f = widget.fixture;
    return Scaffold(
      appBar: AppBar(
        title: Text(fixtureLabel(comp, f)),
        actions: [
          IconButton(
            tooltip: 'Match report (PDF)',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: !f.hasTeams
                ? null
                : () async {
                    final bytes = await Reports.matchReport(app, comp, f);
                    if (context.mounted) {
                      await shareBytes(context, '${safeName('${app.team(f.homeId)?.short}_v_${app.team(f.awayId)?.short}')}_report.pdf', bytes, 'application/pdf');
                    }
                  },
          ),
        ],
      ),
      floatingActionButton: f.hasTeams && _tab == _Tab.timeline && (f.played || f.status == MatchStatus.live)
          ? FloatingActionButton.extended(
              onPressed: () => showEventSheet(context, comp, f, minute: f.status == MatchStatus.live ? f.liveMinute() : null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Event'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
        children: [
          _Scoreboard(comp: comp, fixture: f),
          const SizedBox(height: 12),
          if (f.hasTeams) _actions(context, app, comp, f),
          if (!f.hasTeams)
            TLCard(
              child: Text('Teams for this match are decided by earlier results. It fills in automatically.', style: TLText.body(c.inkDim, size: 13)),
            ),
          const SizedBox(height: 14),
          Segmented<_Tab>(
            values: _Tab.values,
            selected: _tab,
            label: (t) => switch (t) { _Tab.timeline => 'Timeline', _Tab.lineups => 'Line-ups', _Tab.info => 'Match info', _Tab.h2h => 'Head-to-head' },
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 12),
          switch (_tab) {
            _Tab.timeline => _Timeline(comp: comp, fixture: f),
            _Tab.lineups => _lineups(context, app, f),
            _Tab.info => _Info(comp: comp, fixture: f),
            _Tab.h2h => _HeadToHead(fixture: f),
          },
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, AppState app, Competition comp, Fixture f) {
    final c = context.tl;
    final live = f.status == MatchStatus.live;
    return Row(children: [
      if (!f.played)
        Expanded(
          child: FilledButton.icon(
            style: live ? FilledButton.styleFrom(backgroundColor: c.poor, foregroundColor: Colors.white) : null,
            onPressed: () {
              if (!live) {
                app.update(() {
                  f.status = MatchStatus.live;
                  if (f.period == 0) {
                    f.period = 1;
                    f.periodBase = 0;
                    f.periodStart = DateTime.now();
                    f.homeGoals = 0;
                    f.awayGoals = 0;
                  }
                });
              }
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveScreen(comp: comp, fixture: f)));
            },
            icon: Icon(live ? Icons.sensors_rounded : Icons.play_arrow_rounded),
            label: Text(live ? 'Live console' : 'Kick off live'),
          ),
        ),
      if (!f.played) const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => showResultSheet(context, comp, f),
          icon: const Icon(Icons.scoreboard_outlined),
          label: Text(f.played ? 'Edit score' : 'Enter result'),
        ),
      ),
    ]);
  }

  Widget _lineups(BuildContext context, AppState app, Fixture f) {
    final c = context.tl;
    if (!f.hasTeams) return const SizedBox();
    final side = _homeLineup;
    final lu = f.lineup(side);
    final team = app.team(f.teamId(side));
    final d = discipline(widget.comp);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        for (final s in [true, false])
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: s ? 6 : 0, left: s ? 0 : 6),
              child: ChoiceChip(
                avatar: Crest(app.team(f.teamId(s)), size: 18),
                label: Text(app.team(f.teamId(s))?.short ?? ''),
                selected: _homeLineup == s,
                onSelected: (_) => setState(() => _homeLineup = s),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 10),
      if (lu.isEmpty)
        TLCard(
          child: Column(children: [
            Text('No line-up yet for ${team?.name ?? ''}.', style: TLText.body(c.inkDim)),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LineupEditor(comp: widget.comp, fixture: f, home: side))),
              icon: const Icon(Icons.groups_rounded),
              label: const Text('Pick line-up'),
            ),
          ]),
        )
      else ...[
        Row(children: [
          Text(lu.formation, style: TLText.headline(c.ink, size: 20)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LineupEditor(comp: widget.comp, fixture: f, home: side))),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit'),
          ),
        ]),
        PitchView(team: team, lineup: lu, suspended: f.played ? const {} : d.active.keys.toSet()),
        const SectionHeader('Substitutes'),
        TLCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (final id in lu.bench)
              () {
                final p = team?.player(id);
                final on = f.events.where((e) => e.type == EventType.sub && e.playerId == id).firstOrNull;
                return ListTile(
                  dense: true,
                  leading: SizedBox(width: 28, child: Text('${p?.number ?? ''}', style: TLText.score(17, c.inkDim))),
                  title: Text(p?.name ?? 'Unknown', style: TLText.body(c.ink, weight: FontWeight.w600)),
                  subtitle: Text(p?.position.label ?? '', style: TLText.body(c.inkDim, size: 11.5)),
                  trailing: on == null ? null : Row(mainAxisSize: MainAxisSize.min, children: [eventIcon(EventType.sub, c, size: 16), Text(on.clock, style: TLText.reading(12, c.accent))]),
                );
              }(),
          ]),
        ),
        if (team != null && team.coach.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Coach: ${team.coach}', style: TLText.body(c.inkDim, size: 12.5))),
      ],
    ]);
  }
}

class _Scoreboard extends StatelessWidget {
  final Competition comp;
  final Fixture fixture;
  const _Scoreboard({required this.comp, required this.fixture});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final f = fixture;
    final home = app.team(f.homeId), away = app.team(f.awayId);
    final live = f.status == MatchStatus.live;
    final showScore = f.played || live;
    final tie = f.stage == Stage.knockout && f.played ? resolveTie(comp, f) : null;
    String status;
    if (live) {
      status = f.period == 2 ? 'HALF TIME' : (f.period == 6 ? 'PENALTIES' : "${f.liveMinute()}'");
    } else if (f.played) {
      status = f.forfeit ? 'AWARDED' : (f.hasPens ? 'FT · PENS' : (f.extraTime ? 'AET' : 'FULL TIME'));
    } else {
      status = f.status == MatchStatus.scheduled ? (f.kickoff == null ? 'DATE TBC' : dateTimeText(f.kickoff!).toUpperCase()) : f.status.label.toUpperCase();
    }
    final goals = f.sortedEvents.where((e) => e.type.isGoal).toList();
    String scorers(bool home) => goals
        .where((e) => e.home == home)
        .map((e) => "${app.playerName(e.playerId, short: true)} ${e.clock}${e.type == EventType.penaltyGoal ? ' (P)' : (e.type == EventType.ownGoal ? ' (OG)' : '')}")
        .join('\n');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [teamColor(home).withOpacity(0.30), c.surface, teamColor(away).withOpacity(0.30)],
          stops: const [0, 0.5, 1],
        ),
        border: Border.all(color: live ? c.poor.withOpacity(0.6) : c.line),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (live) ...[const LiveDot(), const SizedBox(width: 6)],
          Text(status, style: TLText.label(live ? c.poor : c.inkDim, size: 11)),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _side(context, home, f.homeLabel)),
          SizedBox(
            width: 120,
            child: Column(children: [
              const SizedBox(height: 8),
              showScore
                  ? Text('${f.homeGoals} – ${f.awayGoals}', style: TLText.score(48, c.ink))
                  : Text('VS', style: TLText.score(40, c.inkDim)),
              if (f.hasPens) Text('(${f.homePens} – ${f.awayPens} pens)', style: TLText.reading(12, c.inkDim)),
            ]),
          ),
          Expanded(child: _side(context, away, f.awayLabel)),
        ]),
        if (goals.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(scorers(true), textAlign: TextAlign.center, style: TLText.body(c.inkDim, size: 11.5))),
            const SizedBox(width: 24, child: Icon(Icons.sports_soccer_rounded, size: 14)),
            Expanded(child: Text(scorers(false), textAlign: TextAlign.center, style: TLText.body(c.inkDim, size: 11.5))),
          ]),
        ],
        if (tie != null && tie.summary.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(tie.winner != null ? '${app.teamName(tie.winner)} ${tie.summary.isEmpty ? 'go through' : 'go through · ${tie.summary}'}' : tie.summary,
              textAlign: TextAlign.center, style: TLText.body(tie.winner != null ? c.accent : c.fair, size: 12.5, weight: FontWeight.w600)),
        ],
        if (f.venue.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(f.venue, style: TLText.body(c.inkDim, size: 12)),
        ],
      ]),
    );
  }

  Widget _side(BuildContext context, Team? t, String label) {
    final c = context.tl;
    return Column(children: [
      Crest(t, size: 58, placeholder: label.isEmpty ? '?' : label.split(' ').last),
      const SizedBox(height: 8),
      Text(t?.name ?? (label.isEmpty ? 'TBD' : label),
          textAlign: TextAlign.center, maxLines: 2, style: TLText.headline(t == null ? c.inkDim : c.ink, size: 17)),
    ]);
  }
}

class _Timeline extends StatelessWidget {
  final Competition comp;
  final Fixture fixture;
  const _Timeline({required this.comp, required this.fixture});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final f = fixture;
    final ev = f.sortedEvents;
    if (ev.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          f.played || f.status == MatchStatus.live
              ? 'No events recorded. Tap "Event" to add goals, cards and substitutions.'
              : 'Events appear here once the match kicks off.',
          textAlign: TextAlign.center,
          style: TLText.body(c.inkDim),
        ),
      );
    }
    final half = comp.rules.matchMinutes ~/ 2;
    var h = 0, a = 0;
    final rows = <Widget>[];
    var shownHt = false;
    for (final e in ev) {
      if (!shownHt && e.minute > half) {
        rows.add(_divider(context, 'HALF TIME  $h – $a'));
        shownHt = true;
      }
      if (e.type.isGoal) {
        e.home ? h++ : a++;
      }
      final main = e.type == EventType.sub ? app.playerName(e.playerId, short: true) : app.playerName(e.playerId, short: true);
      final sub = switch (e.type) {
        EventType.sub => 'off: ${app.playerName(e.otherId, short: true)}',
        EventType.goal => e.otherId == null ? 'Goal · $h–$a' : 'assist ${app.playerName(e.otherId, short: true)} · $h–$a',
        EventType.penaltyGoal => 'Penalty · $h–$a',
        EventType.ownGoal => 'Own goal · $h–$a',
        _ => e.type.label,
      };
      final content = Column(
        crossAxisAlignment: e.home ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(e.playerId == null ? e.type.label : main, style: TLText.body(c.ink, size: 13.5, weight: e.type.isGoal ? FontWeight.w800 : FontWeight.w600)),
          Text(sub, style: TLText.body(c.inkDim, size: 11.5)),
          if (e.note.isNotEmpty) Text(e.note, style: TLText.body(c.inkDim, size: 11)),
        ],
      );
      rows.add(InkWell(
        onTap: () => showEventSheet(context, comp, f, existing: e),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(child: e.home ? Row(mainAxisAlignment: MainAxisAlignment.end, children: [Flexible(child: content), const SizedBox(width: 8), eventIcon(e.type, c)]) : const SizedBox()),
            Container(
              width: 52,
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: e.type.isGoal ? c.accent.withOpacity(0.18) : c.surface2, borderRadius: BorderRadius.circular(8)),
                child: Text(e.clock, style: TLText.reading(11.5, e.type.isGoal ? c.accent : c.ink, weight: FontWeight.w700)),
              ),
            ),
            Expanded(child: !e.home ? Row(children: [eventIcon(e.type, c), const SizedBox(width: 8), Flexible(child: content)]) : const SizedBox()),
          ]),
        ),
      ));
    }
    if (f.played) rows.add(_divider(context, 'FULL TIME  ${f.homeGoals} – ${f.awayGoals}'));
    return TLCard(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Column(children: rows));
  }

  Widget _divider(BuildContext context, String t) {
    final c = context.tl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Divider(color: c.line)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(t, style: TLText.label(c.inkDim, size: 10.5))),
        Expanded(child: Divider(color: c.line)),
      ]),
    );
  }
}

class _Info extends StatefulWidget {
  final Competition comp;
  final Fixture fixture;
  const _Info({required this.comp, required this.fixture});

  @override
  State<_Info> createState() => _InfoState();
}

class _InfoState extends State<_Info> {
  late final _venue = TextEditingController(text: widget.fixture.venue);
  late final _ref = TextEditingController(text: widget.fixture.referee);
  late final _ast = TextEditingController(text: widget.fixture.assistants);
  late final _att = TextEditingController(text: widget.fixture.attendance?.toString() ?? '');
  late final _notes = TextEditingController(text: widget.fixture.notes);

  void _commit() {
    final app = AppScope.read(context);
    final f = widget.fixture;
    app.update(() {
      f.venue = _venue.text.trim();
      f.referee = _ref.text.trim();
      f.assistants = _ast.text.trim();
      f.attendance = int.tryParse(_att.text.trim());
      f.notes = _notes.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final f = widget.fixture;
    final starters = [...f.homeLineup.starters, ...f.homeLineup.bench, ...f.awayLineup.starters, ...f.awayLineup.bench];
    final motmOptions = starters.isNotEmpty
        ? starters
        : [...?app.team(f.homeId)?.players.map((p) => p.id), ...?app.team(f.awayId)?.players.map((p) => p.id)];
    Widget gap() => const SizedBox(height: 10);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TLCard(
        onTap: () async {
          final init = f.kickoff ?? DateTime.now();
          final d = await showDatePicker(context: context, initialDate: init, firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (d == null || !context.mounted) return;
          final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(init));
          app.update(() {
            f.kickoff = DateTime(d.year, d.month, d.day, t?.hour ?? init.hour, t?.minute ?? init.minute);
            if (f.status == MatchStatus.postponed) f.status = MatchStatus.scheduled;
          });
        },
        child: Row(children: [
          Icon(Icons.event_rounded, color: c.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(f.kickoff == null ? 'Set date & kick-off time' : dateTimeText(f.kickoff!), style: TLText.body(c.ink, weight: FontWeight.w600))),
          Icon(Icons.edit_calendar_rounded, color: c.inkDim, size: 18),
        ]),
      ),
      gap(),
      TextField(controller: _venue, onEditingComplete: _commit, onTapOutside: (_) => _commit(), decoration: const InputDecoration(labelText: 'Venue', prefixIcon: Icon(Icons.stadium_outlined))),
      gap(),
      TextField(controller: _ref, onTapOutside: (_) => _commit(), decoration: const InputDecoration(labelText: 'Referee', prefixIcon: Icon(Icons.sports_rounded))),
      gap(),
      TextField(controller: _ast, onTapOutside: (_) => _commit(), decoration: const InputDecoration(labelText: 'Assistant referees / 4th official')),
      gap(),
      TextField(controller: _att, onTapOutside: (_) => _commit(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Attendance', prefixIcon: Icon(Icons.groups_outlined))),
      gap(),
      if (f.hasTeams && motmOptions.isNotEmpty)
        DropdownButtonFormField<String?>(
          value: motmOptions.contains(f.motmId) ? f.motmId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Player of the match', prefixIcon: Icon(Icons.star_rounded, color: TLColors.gold)),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Not chosen')),
            for (final id in motmOptions)
              DropdownMenuItem<String?>(value: id, child: Text('${app.playerName(id)} · ${app.findPlayer(id)?.$1.short ?? ''}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => app.update(() => f.motmId = v),
        ),
      gap(),
      TextField(controller: _notes, maxLines: 3, onTapOutside: (_) => _commit(), decoration: const InputDecoration(labelText: 'Match notes / incidents')),
      const SectionHeader('Status'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (!f.played)
          ActionChip(
            avatar: const Icon(Icons.schedule_rounded, size: 18),
            label: Text(f.status == MatchStatus.postponed ? 'Reinstate' : 'Postpone'),
            onPressed: () => app.update(() => f.status = f.status == MatchStatus.postponed ? MatchStatus.scheduled : MatchStatus.postponed),
          ),
        if (!f.played)
          ActionChip(
            avatar: const Icon(Icons.cancel_outlined, size: 18),
            label: Text(f.status == MatchStatus.cancelled ? 'Un-cancel' : 'Cancel match'),
            onPressed: () => app.update(() => f.status = f.status == MatchStatus.cancelled ? MatchStatus.scheduled : MatchStatus.cancelled),
          ),
        if (f.hasTeams)
          for (final side in [true, false])
            ActionChip(
              avatar: const Icon(Icons.gavel_rounded, size: 18),
              label: Text('Award to ${app.team(f.teamId(side))?.short ?? ''} (${widget.comp.rules.forfeitGoals}–0)'),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Award the match?'),
                    content: Text('Records a ${widget.comp.rules.forfeitGoals}–0 win for ${app.teamName(f.teamId(side))} (forfeit / walkover). Existing events are kept.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Award')),
                    ],
                  ),
                );
                if (ok != true) return;
                app.update(() {
                  f.homeGoals = side ? widget.comp.rules.forfeitGoals : 0;
                  f.awayGoals = side ? 0 : widget.comp.rules.forfeitGoals;
                  f.forfeit = true;
                  f.status = MatchStatus.finished;
                  f.period = 7;
                  f.periodStart = null;
                });
                advanceKnockout(widget.comp);
                app.update(() {});
              },
            ),
        if (f.played)
          ActionChip(
            avatar: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset to not played'),
            onPressed: () => app.update(() {
              f.status = MatchStatus.scheduled;
              f.homeGoals = 0;
              f.awayGoals = 0;
              f.homePens = null;
              f.awayPens = null;
              f.extraTime = false;
              f.forfeit = false;
              f.period = 0;
              f.periodStart = null;
            }),
          ),
      ]),
    ]);
  }
}

class _HeadToHead extends StatelessWidget {
  final Fixture fixture;
  const _HeadToHead({required this.fixture});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final f = fixture;
    if (!f.hasTeams) return const SizedBox();
    final a = f.homeId!, b = f.awayId!;
    final meetings = app.allFixtures.where((e) => e.$2 != f && e.$2.played && e.$2.involves(a) && e.$2.involves(b)).toList()
      ..sort((x, y) => (y.$2.kickoff ?? DateTime(2000)).compareTo(x.$2.kickoff ?? DateTime(2000)));
    var aw = 0, d = 0, bw = 0;
    for (final (_, m) in meetings) {
      final o = outcome(m, a);
      if (o > 0) {
        aw++;
      } else if (o == 0) {
        d++;
      } else {
        bw++;
      }
    }
    if (meetings.isEmpty) {
      return Padding(padding: const EdgeInsets.all(20), child: Text('These teams have not met yet.', textAlign: TextAlign.center, style: TLText.body(c.inkDim)));
    }
    final total = meetings.length;
    return Column(children: [
      TLCard(
        child: Column(children: [
          Row(children: [
            Expanded(child: Column(children: [Text('$aw', style: TLText.score(34, teamColor(app.team(a)))), Text('${app.team(a)?.short} wins', style: TLText.body(c.inkDim, size: 12))])),
            Expanded(child: Column(children: [Text('$d', style: TLText.score(34, c.inkDim)), Text('draws', style: TLText.body(c.inkDim, size: 12))])),
            Expanded(child: Column(children: [Text('$bw', style: TLText.score(34, teamColor(app.team(b)))), Text('${app.team(b)?.short} wins', style: TLText.body(c.inkDim, size: 12))])),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(children: [
              if (aw > 0) Expanded(flex: aw, child: Container(height: 8, color: teamColor(app.team(a)))),
              if (d > 0) Expanded(flex: d, child: Container(height: 8, color: c.inkDim)),
              if (bw > 0) Expanded(flex: bw, child: Container(height: 8, color: teamColor(app.team(b)))),
            ]),
          ),
          const SizedBox(height: 6),
          Text('$total previous meeting${total == 1 ? '' : 's'}', style: TLText.body(c.inkDim, size: 12)),
        ]),
      ),
      const SizedBox(height: 10),
      TLCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (final (comp, m) in meetings.take(10)) FixtureTile(comp: comp, fixture: m, showComp: true),
        ]),
      ),
    ]);
  }
}
