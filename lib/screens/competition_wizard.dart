import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/setup.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import '../widgets/inputs.dart';
import 'home_screen.dart';

const palette = [
  0xFF3BE37F, 0xFFFFC23D, 0xFF4DA3FF, 0xFFFF4F5E, 0xFFB07CFF, 0xFF00C2C7, 0xFFFF8A3D, 0xFFE91E63, 0xFF8BC34A, 0xFFFFFFFF, 0xFF1E88E5, 0xFF6D4C41,
];

class CompetitionWizard extends StatefulWidget {
  const CompetitionWizard({super.key});

  @override
  State<CompetitionWizard> createState() => _CompetitionWizardState();
}

class _CompetitionWizardState extends State<CompetitionWizard> {
  int _step = 0;
  final _name = TextEditingController();
  final _season = TextEditingController(text: '${DateTime.now().year}');
  final _quick = TextEditingController();
  Format _format = Format.league;
  int _color = palette.first;
  final List<String> _teams = [];
  final Rules _rules = Rules();
  DateTime _start = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 7, 15, 0);
  int _days = 7;
  bool _random = true;
  bool _homeVenues = true;

  static const _titles = ['Competition', 'Teams', 'Rules', 'Schedule'];

  bool get _canNext {
    switch (_step) {
      case 0:
        return _name.text.trim().isNotEmpty;
      case 1:
        if (_format == Format.groupsKnockout) return _teams.length >= _rules.groups * 2;
        return _teams.length >= 2;
      default:
        return true;
    }
  }

  void _create() {
    final app = AppScope.read(context);
    final comp = Competition(
      id: newId(),
      name: _name.text.trim(),
      season: _season.text.trim(),
      format: _format,
      rules: _rules,
      color: _color,
      teamIds: [..._teams],
      organizer: app.settings.organizer,
    );
    if (_format == Format.league && _teams.length >= 6) {
      comp.zones.addAll([
        Zone(label: 'Champion', from: 1, to: 1, color: 0xFFFFC23D),
        Zone(label: 'Relegation', from: _teams.length - 1, to: _teams.length, color: 0xFFFF4F5E),
      ]);
    }
    buildFixtures(comp, start: _start, daysBetween: _days, randomDraw: _random, homeVenues: _homeVenues, team: app.team);
    app.update(() => app.competitions.insert(0, comp));
    Navigator.of(context).pop();
    openCompetition(context, comp);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tl;
    return Scaffold(
      appBar: AppBar(title: Text('New competition · ${_titles[_step]}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Row(children: [
              for (var i = 0; i < 4; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 5,
                    decoration: BoxDecoration(color: i <= _step ? c.accent : c.surface2, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                if (i < 3) const SizedBox(width: 6),
              ],
            ]),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: switch (_step) {
                0 => _basics(context),
                1 => _teamsStep(context),
                2 => _rulesStep(context),
                _ => _scheduleStep(context),
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: Row(children: [
                if (_step > 0)
                  Expanded(child: OutlinedButton(onPressed: () => setState(() => _step--), child: const Text('Back'))),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: !_canNext ? null : () => _step == 3 ? _create() : setState(() => _step++),
                    child: Text(_step == 3 ? 'Create & generate fixtures' : 'Next'),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Step 1 ----------------
  Widget _basics(BuildContext context) {
    final c = context.tl;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        TextField(
          controller: _name,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.words,
          style: TLText.headline(c.ink, size: 22),
          decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. County Meet 2026'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _season, decoration: const InputDecoration(labelText: 'Season / edition')),
        const SectionHeader('Format'),
        for (final f in Format.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TLCard(
              onTap: () => setState(() => _format = f),
              borderColor: _format == f ? c.accent : null,
              child: Row(children: [
                Icon(
                  switch (f) {
                    Format.league => Icons.format_list_numbered_rounded,
                    Format.knockout => Icons.account_tree_rounded,
                    Format.groupsKnockout => Icons.emoji_events_rounded,
                  },
                  color: _format == f ? c.accent : c.inkDim,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.label, style: TLText.body(c.ink, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(f.blurb, style: TLText.body(c.inkDim, size: 12.5)),
                  ]),
                ),
                Radio<Format>(value: f, groupValue: _format, onChanged: (v) => setState(() => _format = v!)),
              ]),
            ),
          ),
        const SectionHeader('Colour'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final col in palette)
              GestureDetector(
                onTap: () => setState(() => _color = col),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Color(col),
                    shape: BoxShape.circle,
                    border: Border.all(color: _color == col ? c.ink : c.line, width: _color == col ? 3 : 1),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---------------- Step 2 ----------------
  Widget _teamsStep(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final others = app.teams.where((t) => !_teams.contains(t.id)).toList()..sort((a, b) => a.name.compareTo(b.name));
    void quickAdd() {
      final names = _quick.text.split(RegExp(r'[,\n]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (names.isEmpty) return;
      final rnd = math.Random();
      app.update(() {
        for (final n in names) {
          final t = Team(id: newId(), name: n, color1: palette[rnd.nextInt(palette.length)], color2: rnd.nextBool() ? 0xFFFFFFFF : 0xFF101010);
          app.teams.add(t);
          _teams.add(t.id);
        }
      });
      _quick.clear();
    }

    String hint() {
      final n = _teams.length;
      if (_format == Format.groupsKnockout) {
        final need = _rules.groups * 2;
        if (n < need) return 'Need at least $need teams for ${_rules.groups} groups (change groups in the next step).';
      }
      if (_format == Format.knockout && n >= 2) {
        var p = 1;
        while (p < n) {
          p *= 2;
        }
        if (p != n) return '${p - n} bye${p - n == 1 ? '' : 's'} will go to the top seeds.';
      }
      return _format == Format.league ? 'Order doesn\'t matter for a league.' : 'Order = seeding (drag to reorder). Top seeds are kept apart.';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _quick,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Quick add teams', hintText: 'Names, separated by commas', isDense: true),
              onSubmitted: (_) => quickAdd(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: quickAdd, icon: const Icon(Icons.add_rounded)),
        ]),
        const SizedBox(height: 8),
        Text(hint(), style: TLText.body(c.inkDim, size: 12.5)),
        SectionHeader('Selected (${_teams.length})',
            trailing: _teams.isEmpty ? null : TextButton(onPressed: () => setState(_teams.clear), child: const Text('Clear'))),
        if (_teams.isEmpty)
          Text('Tick teams below or quick-add new ones.', style: TLText.body(c.inkDim, size: 13))
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (a, b) => setState(() {
              if (b > a) b--;
              _teams.insert(b, _teams.removeAt(a));
            }),
            children: [
              for (var i = 0; i < _teams.length; i++)
                Container(
                  key: ValueKey(_teams[i]),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.line)),
                  child: ListTile(
                    dense: true,
                    leading: Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 24, child: Text('${i + 1}', style: TLText.score(16, c.inkDim))),
                      Crest(app.team(_teams[i]), size: 24),
                    ]),
                    title: Text(app.teamName(_teams[i]), style: TLText.body(c.ink, weight: FontWeight.w600)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: Icon(Icons.close_rounded, color: c.inkDim, size: 18), onPressed: () => setState(() => _teams.removeAt(i))),
                      ReorderableDragStartListener(index: i, child: Icon(Icons.drag_indicator_rounded, color: c.inkDim)),
                    ]),
                  ),
                ),
            ],
          ),
        if (others.isNotEmpty) ...[
          SectionHeader('Team library',
              trailing: TextButton(onPressed: () => setState(() => _teams.addAll(others.map((t) => t.id))), child: const Text('Add all'))),
          for (final t in others)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Crest(t, size: 26),
              title: Text(t.name, style: TLText.body(c.ink)),
              subtitle: Text('${t.players.length} players${t.city.isEmpty ? '' : ' · ${t.city}'}', style: TLText.body(c.inkDim, size: 12)),
              trailing: Icon(Icons.add_circle_outline_rounded, color: c.accent),
              onTap: () => setState(() => _teams.add(t.id)),
            ),
        ],
      ],
    );
  }

  // ---------------- Step 3 ----------------
  Widget _rulesStep(BuildContext context) {
    final c = context.tl;
    final r = _rules;
    final groupFormat = _format == Format.groupsKnockout;
    final hasKo = _format != Format.league;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        if (_format != Format.knockout) ...[
          const SectionHeader('Points'),
          Row(children: [
            Expanded(child: Stepper2(label: 'Win', value: r.win, min: 0, max: 5, onChanged: (v) => setState(() => r.win = v))),
            const SizedBox(width: 8),
            Expanded(child: Stepper2(label: 'Draw', value: r.draw, min: 0, max: 3, onChanged: (v) => setState(() => r.draw = v))),
            const SizedBox(width: 8),
            Expanded(child: Stepper2(label: 'Loss', value: r.loss, min: 0, max: 2, onChanged: (v) => setState(() => r.loss = v))),
          ]),
          const SizedBox(height: 10),
          Segmented<int>(
            values: const [1, 2],
            selected: r.legs,
            label: (v) => v == 1 ? 'Play each team once' : 'Home and away',
            onChanged: (v) => setState(() => r.legs = v),
          ),
        ],
        if (groupFormat) ...[
          const SectionHeader('Groups'),
          Row(children: [
            Expanded(
              child: Stepper2(
                label: 'Groups',
                value: r.groups,
                min: 1,
                max: math.max(1, _teams.length ~/ 2),
                onChanged: (v) => setState(() => r.groups = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Stepper2(label: 'Advance per group', value: r.advance, min: 1, max: 4, onChanged: (v) => setState(() => r.advance = v))),
          ]),
          const SizedBox(height: 6),
          Text('${_teams.length} teams → groups of ${(_teams.length / r.groups).toStringAsFixed(_teams.length % r.groups == 0 ? 0 : 1)}, '
              '${r.groups * r.advance} teams reach the knockout.', style: TLText.body(c.inkDim, size: 12.5)),
        ],
        if (hasKo) ...[
          const SectionHeader('Knockout'),
          Segmented<int>(
            values: const [1, 2],
            selected: r.koLegs,
            label: (v) => v == 1 ? 'Single match' : 'Two legs',
            onChanged: (v) => setState(() => r.koLegs = v),
          ),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: r.extraTime, onChanged: (v) => setState(() => r.extraTime = v), title: const Text('Extra time if level')),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: r.penalties, onChanged: (v) => setState(() => r.penalties = v), title: const Text('Penalty shoot-out')),
          if (r.koLegs == 2)
            SwitchListTile(contentPadding: EdgeInsets.zero, value: r.awayGoalsRule, onChanged: (v) => setState(() => r.awayGoalsRule = v), title: const Text('Away goals rule')),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: r.thirdPlace, onChanged: (v) => setState(() => r.thirdPlace = v), title: const Text('Third-place match')),
        ],
        const SectionHeader('Discipline'),
        Row(children: [
          Expanded(child: Stepper2(label: 'Yellows for a ban', value: r.yellowLimit, min: 0, max: 10, onChanged: (v) => setState(() => r.yellowLimit = v))),
          const SizedBox(width: 8),
          Expanded(child: Stepper2(label: 'Red card ban', value: r.redBan, min: 0, max: 6, onChanged: (v) => setState(() => r.redBan = v))),
        ]),
        const SizedBox(height: 6),
        Text(r.yellowLimit == 0 ? 'Yellow-card accumulation is off.' : 'Every ${r.yellowLimit} yellow cards = ${r.yellowBan}-match ban. Two yellows in a match = ${r.secondYellowBan}-match ban.',
            style: TLText.body(c.inkDim, size: 12.5)),
        const SectionHeader('Match length'),
        Segmented<int>(
          values: const [90, 80, 70, 60, 40],
          selected: r.matchMinutes,
          label: (v) => '$v min',
          onChanged: (v) => setState(() => r.matchMinutes = v),
        ),
      ],
    );
  }

  // ---------------- Step 4 ----------------
  Widget _scheduleStep(BuildContext context) {
    final c = context.tl;
    final count = previewMatchCount(_format, _teams.length, _rules);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        const SectionHeader('First matches'),
        TLCard(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (d == null || !context.mounted) return;
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
            setState(() => _start = DateTime(d.year, d.month, d.day, t?.hour ?? _start.hour, t?.minute ?? _start.minute));
          },
          child: Row(children: [
            Icon(Icons.event_rounded, color: c.accent),
            const SizedBox(width: 12),
            Expanded(child: Text(dateTimeText(_start), style: TLText.body(c.ink, weight: FontWeight.w600))),
            Icon(Icons.edit_calendar_rounded, color: c.inkDim, size: 18),
          ]),
        ),
        const SizedBox(height: 12),
        Stepper2(label: 'Days between rounds', value: _days, min: 1, max: 28, onChanged: (v) => setState(() => _days = v)),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _random,
          onChanged: (v) => setState(() => _random = v),
          title: Text(_format == Format.groupsKnockout ? 'Random draw within pots' : 'Random draw'),
          subtitle: Text(_format == Format.league ? 'Shuffles the fixture order' : 'Off = use your seeding order exactly'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _homeVenues,
          onChanged: (v) => setState(() => _homeVenues = v),
          title: const Text('Play at the home team\'s ground'),
          subtitle: const Text('Uses each team\'s ground when set; edit any venue later'),
        ),
        const SizedBox(height: 14),
        TLCard(
          borderColor: c.accent.withOpacity(0.5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_name.text.trim(), style: TLText.headline(c.ink, size: 22)),
            const SizedBox(height: 4),
            Text('${_format.label} · ${_teams.length} teams', style: TLText.body(c.inkDim, size: 13)),
            const SizedBox(height: 12),
            Row(children: [
              Text('$count', style: TLText.score(36, c.accent)),
              const SizedBox(width: 8),
              Text('matches will be\ngenerated', style: TLText.body(c.inkDim, size: 12.5)),
            ]),
          ]),
        ),
      ],
    );
  }
}
