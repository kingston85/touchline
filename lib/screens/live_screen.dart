import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/standings.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/football.dart';
import '../widgets/inputs.dart';
import 'event_sheet.dart';

/// Touchline console: running clock, period control and one-tap events.
class LiveScreen extends StatefulWidget {
  final Competition comp;
  final Fixture fixture;
  const LiveScreen({super.key, required this.comp, required this.fixture});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Fixture get f => widget.fixture;
  int get _half => widget.comp.rules.matchMinutes ~/ 2;
  int get _full => widget.comp.rules.matchMinutes;
  int get _etHalf => (_full / 6).round(); // 15 for 90-minute games

  String _clock() {
    if (f.periodStart == null) {
      return switch (f.period) { 2 => 'HT', 6 => 'PENS', 7 => 'FT', _ => '00:00' };
    }
    final s = DateTime.now().difference(f.periodStart!).inSeconds + f.periodBase * 60;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  String get _periodName => switch (f.period) {
        0 => 'Not started',
        1 => 'First half',
        2 => 'Half time',
        3 => 'Second half',
        4 => 'Extra time · 1st',
        5 => 'Extra time · 2nd',
        6 => 'Penalty shoot-out',
        _ => 'Full time',
      };

  bool get _level => f.homeGoals == f.awayGoals;
  bool get _ko => f.stage == Stage.knockout;

  // In a two-legged tie the aggregate decides whether extra time is needed.
  bool get _tieLevel {
    if (!_ko || f.leg != 2) return _level;
    final other = widget.comp.matches.where((m) => m.tieId == f.tieId && m != f).firstOrNull;
    if (other == null) return _level;
    final a = f.awayId;
    final aggA = f.awayGoals + (other.homeId == a ? other.homeGoals : other.awayGoals);
    final aggB = f.homeGoals + (other.homeId == a ? other.awayGoals : other.homeGoals);
    return aggA == aggB;
  }

  void _set(int period, {int? base}) {
    final app = AppScope.read(context);
    HapticFeedback.mediumImpact();
    app.update(() {
      f.period = period;
      if (base != null) {
        f.periodBase = base;
        f.periodStart = DateTime.now();
      } else {
        f.periodStart = null;
      }
      if (period >= 4 && period <= 5) f.extraTime = true;
    });
  }

  void _finish() {
    final app = AppScope.read(context);
    app.update(() {
      f.period = 7;
      f.periodStart = null;
      f.status = MatchStatus.finished;
    });
    advanceKnockout(widget.comp);
    app.update(() {});
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Full time: ${app.teamName(f.homeId)} ${f.homeGoals}–${f.awayGoals} ${app.teamName(f.awayId)}')));
  }

  List<(String, VoidCallback, bool)> _controls() {
    final r = widget.comp.rules;
    switch (f.period) {
      case 0:
        return [('Kick off', () => _set(1, base: 0), true)];
      case 1:
        return [('Half time', () => _set(2), true)];
      case 2:
        return [('Start second half', () => _set(3, base: _half), true)];
      case 3:
        return [
          if (_ko && _tieLevel && r.extraTime) ('Extra time', () => _set(4, base: _full), false),
          if (_ko && _tieLevel && r.penalties) ('Straight to penalties', () => _set(6), false),
          ('Full time', _finish, true),
        ];
      case 4:
        return [('Start ET second half', () => _set(5, base: _full + _etHalf), true)];
      case 5:
        return [
          if (_tieLevel && r.penalties) ('Penalties', () => _set(6), false),
          ('End of extra time', _finish, true),
        ];
      case 6:
        return [('Finish shoot-out', _finish, true)];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final home = app.team(f.homeId), away = app.team(f.awayId);
    final minute = f.periodStart == null ? null : f.liveMinute();
    final recent = f.sortedEvents.reversed.take(6).toList();

    Widget sideButtons(bool side) {
      Widget b(IconData i, String label, Color col, EventType t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: col.withOpacity(0.18), foregroundColor: col, minimumSize: const Size.fromHeight(56)),
                onPressed: f.period == 0 || f.period == 7 ? null : () => showEventSheet(context, widget.comp, f, home: side, type: t, minute: minute ?? _half),
                icon: Icon(i),
                label: Text(label),
              ),
            ),
          );
      return Column(children: [
        b(Icons.sports_soccer_rounded, 'Goal', c.accent, EventType.goal),
        b(Icons.style_rounded, 'Card', c.fair, EventType.yellow),
        b(Icons.swap_vert_rounded, 'Sub', TLColors.blue, EventType.sub),
      ]);
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(fixtureLabel(widget.comp, f)), actions: [
        IconButton(
          tooltip: 'Undo last event',
          onPressed: f.events.isEmpty
              ? null
              : () {
                  final last = f.sortedEvents.last;
                  app.update(() => f.events.remove(last));
                  f.homeGoals = f.events.where((e) => e.type.isGoal && e.home).length;
                  f.awayGoals = f.events.where((e) => e.type.isGoal && !e.home).length;
                  app.resultChanged(widget.comp, f);
                },
          icon: const Icon(Icons.undo_rounded),
        ),
      ]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF050807),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: c.poor.withOpacity(f.period == 7 ? 0 : 0.5)),
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (f.periodStart != null) ...[const LiveDot(), const SizedBox(width: 8)],
                  Text(_periodName.toUpperCase(), style: TLText.label(const Color(0xFF9FB3A6), size: 11)),
                ]),
                const SizedBox(height: 6),
                Text(_clock(), style: TLText.score(64, const Color(0xFFFFC23D))),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Column(children: [Crest(home, size: 46), const SizedBox(height: 6), Text(home?.short ?? '', style: TLText.headline(Colors.white, size: 18))])),
                  Text('${f.homeGoals}', style: TLText.score(72, Colors.white)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(':', style: TLText.score(56, const Color(0xFF6E8577)))),
                  Text('${f.awayGoals}', style: TLText.score(72, Colors.white)),
                  Expanded(child: Column(children: [Crest(away, size: 46), const SizedBox(height: 6), Text(away?.short ?? '', style: TLText.headline(Colors.white, size: 18))])),
                ]),
                if (f.period == 6 || f.hasPens) Text('Penalties ${f.homePens ?? 0} – ${f.awayPens ?? 0}', style: TLText.reading(13, const Color(0xFFFFC23D))),
              ]),
            ),
            const SizedBox(height: 14),
            for (final ctl in _controls())
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ctl.$3
                    ? FilledButton(onPressed: ctl.$2, child: Text(ctl.$1))
                    : OutlinedButton(onPressed: ctl.$2, child: Text(ctl.$1)),
              ),
            if (f.period == 6) ...[
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: Stepper2(label: '${home?.short ?? 'Home'} scored', value: f.homePens ?? 0, min: 0, max: 30, onChanged: (v) => app.update(() => f.homePens = v))),
                const SizedBox(width: 10),
                Expanded(child: Stepper2(label: '${away?.short ?? 'Away'} scored', value: f.awayPens ?? 0, min: 0, max: 30, onChanged: (v) => app.update(() => f.awayPens = v))),
              ]),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: sideButtons(true)),
              const SizedBox(width: 12),
              Expanded(child: sideButtons(false)),
            ]),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('LATEST', style: TLText.label(c.inkDim)),
              for (final e in recent)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: eventIcon(e.type, c),
                  title: Text('${e.clock}  ${app.playerName(e.playerId, short: true)}', style: TLText.body(c.ink, weight: FontWeight.w600)),
                  subtitle: Text('${e.type.label} · ${app.team(f.teamId(e.home))?.short ?? ''}', style: TLText.body(c.inkDim, size: 12)),
                  onTap: () => showEventSheet(context, widget.comp, f, existing: e),
                ),
            ],
            const SizedBox(height: 8),
            Text('The clock keeps running if you leave this screen or close the app.', textAlign: TextAlign.center, style: TLText.body(c.inkDim, size: 11.5)),
          ],
        ),
      ),
    );
  }
}
