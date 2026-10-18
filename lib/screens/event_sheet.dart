import 'package:flutter/material.dart';

import '../core/standings.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/football.dart';
import '../widgets/inputs.dart';

/// Players available to a side in a match: line-up first, else whole squad.
List<Player> sidePlayers(AppState app, Fixture f, bool home, {bool benchOnly = false, bool onPitchOnly = false}) {
  final t = app.team(f.teamId(home));
  if (t == null) return const [];
  final lu = f.lineup(home);
  if (lu.isEmpty) return [...t.players]..sort((a, b) => (a.number ?? 99).compareTo(b.number ?? 99));
  final subsOn = f.events.where((e) => e.home == home && e.type == EventType.sub).map((e) => e.playerId).whereType<String>().toSet();
  final subsOff = f.events.where((e) => e.home == home && e.type == EventType.sub).map((e) => e.otherId).whereType<String>().toSet();
  List<String> ids;
  if (benchOnly) {
    ids = lu.bench.where((id) => !subsOn.contains(id)).toList();
  } else if (onPitchOnly) {
    ids = [...lu.starters.where((id) => !subsOff.contains(id)), ...subsOn.where((id) => !subsOff.contains(id))];
  } else {
    ids = [...lu.starters, ...lu.bench];
  }
  return ids.map(t.player).whereType<Player>().toList();
}

Future<void> showEventSheet(BuildContext context, Competition comp, Fixture f, {MatchEvent? existing, bool? home, EventType? type, int? minute}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EventSheet(comp: comp, fixture: f, existing: existing, home: home, type: type, minute: minute),
  );
}

class _EventSheet extends StatefulWidget {
  final Competition comp;
  final Fixture fixture;
  final MatchEvent? existing;
  final bool? home;
  final EventType? type;
  final int? minute;
  const _EventSheet({required this.comp, required this.fixture, this.existing, this.home, this.type, this.minute});

  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  late EventType _type;
  late bool _home;
  late int _minute;
  int _stoppage = 0;
  String? _player;
  String? _other;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.type ?? EventType.goal;
    _home = e?.home ?? widget.home ?? true;
    _minute = e?.minute ?? widget.minute ?? 1;
    _stoppage = e?.stoppage ?? 0;
    _player = e?.playerId;
    _other = e?.otherId;
    _note.text = e?.note ?? '';
    if (_minute > widget.comp.rules.matchMinutes && e == null && !widget.fixture.extraTime) {
      _stoppage = _minute - widget.comp.rules.matchMinutes;
      _minute = widget.comp.rules.matchMinutes;
    }
  }

  // Own goals are credited to [_home] but scored by the other side's player.
  bool get _playerSide => _type == EventType.ownGoal ? !_home : _home;

  void _save() {
    final app = AppScope.read(context);
    final f = widget.fixture;
    app.update(() {
      final e = widget.existing ?? MatchEvent(id: newId(), type: _type, home: _home, minute: _minute);
      e
        ..type = _type
        ..home = _home
        ..minute = _minute
        ..stoppage = _stoppage
        ..playerId = _player
        ..otherId = (_type == EventType.goal || _type == EventType.sub) ? _other : null
        ..note = _note.text.trim();
      if (widget.existing == null) f.events.add(e);
      // A second yellow implies the player is off: nothing else to store.
    });
    app.resultChanged(widget.comp, f);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final f = widget.fixture;
    final d = discipline(widget.comp);
    final isSub = _type == EventType.sub;
    final players = sidePlayers(app, f, _playerSide, benchOnly: isSub && f.lineup(_playerSide).bench.isNotEmpty);
    final others = isSub
        ? sidePlayers(app, f, _home, onPitchOnly: !f.lineup(_home).isEmpty)
        : sidePlayers(app, f, _home).where((p) => p.id != _player).toList();
    if (_player != null && !players.any((p) => p.id == _player)) {
      final p = app.findPlayer(_player)?.$2;
      if (p != null) players.insert(0, p);
    }
    if (_other != null && !others.any((p) => p.id == _other)) {
      final p = app.findPlayer(_other)?.$2;
      if (p != null) others.insert(0, p);
    }
    // Previous yellow in this match → suggest second yellow.
    final hadYellow = _player != null && f.events.any((e) => e.playerId == _player && e.type == EventType.yellow && e != widget.existing);

    String pLabel(Player p) => '${p.number ?? '–'}  ${p.name}${d.isSuspended(p.id) && !f.played ? '  (suspended)' : ''}';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Add event' : 'Edit event', style: TLText.title(c.ink)),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in EventType.values)
                ChoiceChip(
                  avatar: eventIcon(t, c, size: 16),
                  label: Text(t.label),
                  selected: _type == t,
                  onSelected: (_) => setState(() {
                    _type = t;
                    _player = null;
                    _other = null;
                  }),
                ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              for (final side in [true, false])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: side ? 6 : 0, left: side ? 0 : 6),
                    child: InkWell(
                      onTap: () => setState(() {
                        _home = side;
                        _player = null;
                        _other = null;
                      }),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _home == side ? c.accent.withOpacity(0.14) : c.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _home == side ? c.accent : c.line),
                        ),
                        child: Row(children: [
                          Crest(app.team(f.teamId(side)), size: 22),
                          const SizedBox(width: 8),
                          Expanded(child: Text(app.teamName(f.teamId(side)), style: TLText.body(c.ink, size: 13, weight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
            if (_type == EventType.ownGoal)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Own goal: pick the team the goal counts FOR, then the opposing player who scored it.', style: TLText.body(c.inkDim, size: 12)),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Stepper2(label: 'Minute', value: _minute, min: 1, max: 130, onChanged: (v) => setState(() => _minute = v))),
              const SizedBox(width: 10),
              Expanded(child: Stepper2(label: 'Added time (+)', value: _stoppage, min: 0, max: 20, onChanged: (v) => setState(() => _stoppage = v))),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _player,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: switch (_type) {
                  EventType.sub => 'Player coming ON',
                  EventType.ownGoal => 'Player who put it in his own net',
                  EventType.yellow || EventType.secondYellow || EventType.red => 'Player booked',
                  EventType.penaltyMiss => 'Penalty taker',
                  _ => 'Scorer',
                },
              ),
              items: [for (final p in players) DropdownMenuItem(value: p.id, child: Text(pLabel(p), overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _player = v),
            ),
            if (_type == EventType.goal || isSub) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                value: _other,
                isExpanded: true,
                decoration: InputDecoration(labelText: isSub ? 'Player going OFF' : 'Assist (optional)'),
                items: [
                  if (!isSub) const DropdownMenuItem<String?>(value: null, child: Text('No assist')),
                  for (final p in others) DropdownMenuItem<String?>(value: p.id, child: Text(pLabel(p), overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _other = v),
              ),
            ],
            if (_type == EventType.yellow && hadYellow)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () => setState(() => _type = EventType.secondYellow),
                  icon: eventIcon(EventType.secondYellow, c, size: 16),
                  label: const Text('Already booked in this match: make it a second yellow'),
                ),
              ),
            const SizedBox(height: 10),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)', isDense: true)),
            const SizedBox(height: 16),
            Row(children: [
              if (widget.existing != null)
                IconButton(
                  tooltip: 'Delete event',
                  onPressed: () {
                    final app = AppScope.read(context);
                    app.update(() => f.events.remove(widget.existing));
                    if (widget.existing!.type.isGoal) {
                      f.homeGoals = f.events.where((e) => e.type.isGoal && e.home).length;
                      f.awayGoals = f.events.where((e) => e.type.isGoal && !e.home).length;
                    }
                    app.resultChanged(widget.comp, f);
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.delete_outline_rounded, color: c.poor),
                ),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _player == null && _type != EventType.ownGoal && _type != EventType.goal ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save event'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Quick full-time result entry.
Future<void> showResultSheet(BuildContext context, Competition comp, Fixture f) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ResultSheet(comp: comp, fixture: f),
  );
}

class _ResultSheet extends StatefulWidget {
  final Competition comp;
  final Fixture fixture;
  const _ResultSheet({required this.comp, required this.fixture});

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  late int _h = widget.fixture.homeGoals, _a = widget.fixture.awayGoals;
  late bool _et = widget.fixture.extraTime;
  late bool _pens = widget.fixture.hasPens;
  late int _hp = widget.fixture.homePens ?? 0, _ap = widget.fixture.awayPens ?? 0;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final f = widget.fixture;
    final ko = f.stage == Stage.knockout;
    final goalsLogged = f.events.where((e) => e.type.isGoal).length;
    final mismatch = goalsLogged > 0 && (f.events.where((e) => e.type.isGoal && e.home).length != _h || f.events.where((e) => e.type.isGoal && !e.home).length != _a);
    // For a second leg the shoot-out depends on the aggregate, so always allow it.
    final canPens = ko && (f.leg == 2 || _h == _a);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Final score', style: TLText.title(c.ink)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Column(children: [
                Crest(app.team(f.homeId), size: 44),
                const SizedBox(height: 6),
                Text(app.teamName(f.homeId), textAlign: TextAlign.center, style: TLText.body(c.ink, size: 13, weight: FontWeight.w600)),
                ScoreStepper(value: _h, onChanged: (v) => setState(() => _h = v)),
              ]),
            ),
            Text('–', style: TLText.score(40, c.inkDim)),
            Expanded(
              child: Column(children: [
                Crest(app.team(f.awayId), size: 44),
                const SizedBox(height: 6),
                Text(app.teamName(f.awayId), textAlign: TextAlign.center, style: TLText.body(c.ink, size: 13, weight: FontWeight.w600)),
                ScoreStepper(value: _a, onChanged: (v) => setState(() => _a = v)),
              ]),
            ),
          ]),
          if (mismatch)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Note: $goalsLogged goal events are logged. The score you set here is what counts; '
                  'adding or removing goal events later will recount it.', style: TLText.body(c.fair, size: 12), textAlign: TextAlign.center),
            ),
          if (ko) ...[
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _et, onChanged: (v) => setState(() => _et = v), title: const Text('After extra time')),
            if (canPens)
              SwitchListTile(contentPadding: EdgeInsets.zero, value: _pens, onChanged: (v) => setState(() => _pens = v), title: const Text('Penalty shoot-out')),
            if (_pens && canPens)
              Row(children: [
                Expanded(child: Stepper2(label: 'Home pens', value: _hp, min: 0, max: 30, onChanged: (v) => setState(() => _hp = v))),
                const SizedBox(width: 10),
                Expanded(child: Stepper2(label: 'Away pens', value: _ap, min: 0, max: 30, onChanged: (v) => setState(() => _ap = v))),
              ]),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              app.update(() {
                f.homeGoals = _h;
                f.awayGoals = _a;
                f.extraTime = ko && _et;
                f.homePens = _pens && canPens ? _hp : null;
                f.awayPens = _pens && canPens ? _ap : null;
                f.status = MatchStatus.finished;
                f.period = 7;
                f.periodStart = null;
              });
              advanceKnockout(widget.comp);
              app.update(() {});
              Navigator.pop(context);
            },
            icon: const Icon(Icons.sports_score_rounded),
            label: const Text('Save as full time'),
          ),
        ]),
      ),
    );
  }
}
