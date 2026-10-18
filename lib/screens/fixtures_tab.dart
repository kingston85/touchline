import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import '../widgets/inputs.dart';
import 'home_screen.dart';

enum _Filter { all, upcoming, results }

class FixturesTab extends StatefulWidget {
  final Competition comp;
  const FixturesTab({super.key, required this.comp});

  @override
  State<FixturesTab> createState() => _FixturesTabState();
}

class _FixturesTabState extends State<FixturesTab> {
  _Filter _filter = _Filter.all;
  String? _team;

  String _roundKey(Fixture f) => '${f.stage.index}-${f.stage == Stage.knockout ? f.round : f.round}-${f.stage == Stage.knockout ? f.leg : 0}';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final comp = widget.comp;
    var list = comp.matches.where((m) {
      if (_team != null && !m.involves(_team!)) return false;
      if (_filter == _Filter.upcoming && (m.played || m.status == MatchStatus.cancelled)) return false;
      if (_filter == _Filter.results && !m.played) return false;
      return true;
    }).toList();
    list.sort((a, b) {
      final s = a.stage.index.compareTo(b.stage.index);
      if (s != 0) return s;
      final r = a.round.compareTo(b.round);
      if (r != 0) return r;
      final l = a.leg.compareTo(b.leg);
      if (l != 0) return l;
      final t = (a.kickoff ?? DateTime(2100)).compareTo(b.kickoff ?? DateTime(2100));
      if (t != 0) return t;
      return a.slot.compareTo(b.slot);
    });
    if (_filter == _Filter.results) list = list.reversed.toList();

    final groups = <String, List<Fixture>>{};
    for (final f in list) {
      (groups[_roundKey(f)] ??= []).add(f);
    }

    // Jump to the first round that still has unplayed matches.
    final teams = comp.teamIds.map(app.team).whereType<Team>().toList()..sort((a, b) => a.name.compareTo(b.name));

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
      children: [
        Segmented<_Filter>(
          values: _Filter.values,
          selected: _filter,
          label: (f) => switch (f) { _Filter.all => 'All', _Filter.upcoming => 'To play', _Filter.results => 'Results' },
          onChanged: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          value: _team,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Team', isDense: true),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All teams')),
            for (final t in teams)
              DropdownMenuItem<String?>(
                value: t.id,
                child: Row(children: [Crest(t, size: 18), const SizedBox(width: 8), Flexible(child: Text(t.name, overflow: TextOverflow.ellipsis))]),
              ),
          ],
          onChanged: (v) => setState(() => _team = v),
        ),
        if (list.isEmpty)
          const EmptyState(icon: Icons.calendar_month_outlined, title: 'No matches', body: 'Nothing matches this filter.'),
        for (final e in groups.entries) ...[
          _RoundHeader(comp: comp, fixtures: e.value),
          TLCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (var i = 0; i < e.value.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: c.line),
                FixtureTile(
                  comp: comp,
                  fixture: e.value[i],
                  highlightTeam: _team,
                  onTap: () => openFixture(context, comp, e.value[i]),
                ),
              ],
            ]),
          ),
        ],
      ],
    );
  }
}

class _RoundHeader extends StatelessWidget {
  final Competition comp;
  final List<Fixture> fixtures;
  const _RoundHeader({required this.comp, required this.fixtures});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final f = fixtures.first;
    var title = fixtureLabel(comp, f);
    if (f.stage == Stage.group) title = 'Matchday ${f.round}';
    if (f.stage == Stage.knockout && f.slot == 1 && fixtures.length == 1 && title == 'Third place') title = 'Third place';
    final dates = fixtures.map((m) => m.kickoff).whereType<DateTime>().toList()..sort();
    final done = fixtures.where((m) => m.played).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 20, 0, 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(), style: TLText.label(c.ink, size: 12)),
            if (dates.isNotEmpty)
              Text(sameDay(dates.first, dates.last) ? dayDate(dates.first) : '${dayDate(dates.first)} – ${dayDate(dates.last)}',
                  style: TLText.body(c.inkDim, size: 12)),
          ]),
        ),
        Tag('$done/${fixtures.length}', color: done == fixtures.length ? c.good : c.inkDim),
        IconButton(
          tooltip: 'Reschedule this round',
          icon: Icon(Icons.edit_calendar_rounded, color: c.inkDim, size: 20),
          onPressed: () async {
            final first = dates.isEmpty ? DateTime.now() : dates.first;
            final d = await showDatePicker(context: context, initialDate: first, firstDate: DateTime(2000), lastDate: DateTime(2100), helpText: 'Move this round to');
            if (d == null || !context.mounted) return;
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(first));
            final target = DateTime(d.year, d.month, d.day, t?.hour ?? first.hour, t?.minute ?? first.minute);
            final shift = target.difference(first);
            app.update(() {
              for (final m in fixtures.where((m) => !m.played)) {
                m.kickoff = (m.kickoff ?? first).add(shift);
                if (m.status == MatchStatus.postponed) m.status = MatchStatus.scheduled;
              }
            });
          },
        ),
      ]),
    );
  }
}
