import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import '../widgets/inputs.dart';
import 'competition_wizard.dart' show palette;

class CompetitionSettings extends StatefulWidget {
  final Competition comp;
  const CompetitionSettings({super.key, required this.comp});

  @override
  State<CompetitionSettings> createState() => _CompetitionSettingsState();
}

class _CompetitionSettingsState extends State<CompetitionSettings> {
  late final _name = TextEditingController(text: widget.comp.name);
  late final _season = TextEditingController(text: widget.comp.season);
  late final _org = TextEditingController(text: widget.comp.organizer);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final comp = widget.comp;
    final r = comp.rules;
    void set(VoidCallback f) => app.update(f);
    return Scaffold(
      appBar: AppBar(title: const Text('Competition settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
        children: [
          TextField(controller: _name, onChanged: (v) => set(() => comp.name = v.trim()), decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _season, onChanged: (v) => set(() => comp.season = v.trim()), decoration: const InputDecoration(labelText: 'Season'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _org, onChanged: (v) => set(() => comp.organizer = v.trim()), decoration: const InputDecoration(labelText: 'Organiser'))),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final col in palette)
              GestureDetector(
                onTap: () => set(() => comp.color = col),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: Color(col), shape: BoxShape.circle, border: Border.all(color: comp.color == col ? c.ink : c.line, width: comp.color == col ? 3 : 1)),
                ),
              ),
          ]),
          if (comp.format != Format.knockout) ...[
            const SectionHeader('Points'),
            Row(children: [
              Expanded(child: Stepper2(label: 'Win', value: r.win, min: 0, max: 5, onChanged: (v) => set(() => r.win = v))),
              const SizedBox(width: 8),
              Expanded(child: Stepper2(label: 'Draw', value: r.draw, min: 0, max: 3, onChanged: (v) => set(() => r.draw = v))),
              const SizedBox(width: 8),
              Expanded(child: Stepper2(label: 'Loss', value: r.loss, min: 0, max: 2, onChanged: (v) => set(() => r.loss = v))),
            ]),
            const SectionHeader('Tiebreakers (drag to reorder)'),
            Text('Applied in order after points. Head-to-head compares results among the tied teams only.', style: TLText.body(c.inkDim, size: 12)),
            const SizedBox(height: 8),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (a, b) => set(() {
                if (b > a) b--;
                r.tiebreaks.insert(b, r.tiebreaks.removeAt(a));
              }),
              children: [
                for (var i = 0; i < r.tiebreaks.length; i++)
                  Container(
                    key: ValueKey(r.tiebreaks[i]),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.line)),
                    child: ListTile(
                      dense: true,
                      leading: Text('${i + 1}', style: TLText.score(18, c.accent)),
                      title: Text(r.tiebreaks[i].label, style: TLText.body(c.ink, weight: FontWeight.w600)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: Icon(Icons.close_rounded, size: 18, color: c.inkDim), onPressed: () => set(() => r.tiebreaks.removeAt(i))),
                        ReorderableDragStartListener(index: i, child: Icon(Icons.drag_indicator_rounded, color: c.inkDim)),
                      ]),
                    ),
                  ),
              ],
            ),
            Wrap(spacing: 6, children: [
              for (final t in Tiebreak.values.where((t) => !r.tiebreaks.contains(t)))
                ActionChip(avatar: const Icon(Icons.add_rounded, size: 16), label: Text(t.label), onPressed: () => set(() => r.tiebreaks.add(t))),
            ]),
          ],
          if (comp.format == Format.league) ...[
            SectionHeader('Table zones', trailing: TextButton.icon(onPressed: () => _editZone(context, null), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add'))),
            if (comp.zones.isEmpty) Text('Colour bands for champions, promotion, continental places or relegation.', style: TLText.body(c.inkDim, size: 12.5)),
            for (final z in comp.zones)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(width: 14, height: 30, decoration: BoxDecoration(color: Color(z.color), borderRadius: BorderRadius.circular(4))),
                title: Text(z.label, style: TLText.body(c.ink, weight: FontWeight.w600)),
                subtitle: Text(z.from == z.to ? 'Position ${z.from}' : 'Positions ${z.from}–${z.to}', style: TLText.body(c.inkDim, size: 12)),
                trailing: Icon(Icons.edit_rounded, color: c.inkDim, size: 18),
                onTap: () => _editZone(context, z),
              ),
          ],
          if (comp.format != Format.knockout) ...[
            SectionHeader('Point adjustments', trailing: TextButton.icon(onPressed: () => _addAdjustment(context), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add'))),
            if (comp.adjustments.isEmpty) Text('Deduct (or award) points, e.g. for fielding an ineligible player.', style: TLText.body(c.inkDim, size: 12.5)),
            for (final a in comp.adjustments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Crest(app.team(a.teamId), size: 26),
                title: Text('${app.teamName(a.teamId)}  ${a.points > 0 ? '+' : ''}${a.points} pts', style: TLText.body(c.ink, weight: FontWeight.w600)),
                subtitle: Text(a.reason, style: TLText.body(c.inkDim, size: 12)),
                trailing: IconButton(icon: Icon(Icons.delete_outline_rounded, color: c.poor), onPressed: () => set(() => comp.adjustments.remove(a))),
              ),
          ],
          if (comp.format != Format.league) ...[
            const SectionHeader('Knockout'),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: r.extraTime, onChanged: (v) => set(() => r.extraTime = v), title: const Text('Extra time if level')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: r.penalties, onChanged: (v) => set(() => r.penalties = v), title: const Text('Penalty shoot-out')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: r.awayGoalsRule, onChanged: (v) => set(() => r.awayGoalsRule = v), title: const Text('Away goals rule (two-legged ties)')),
          ],
          const SectionHeader('Discipline'),
          Row(children: [
            Expanded(child: Stepper2(label: 'Yellows → ban', value: r.yellowLimit, min: 0, max: 10, onChanged: (v) => set(() => r.yellowLimit = v))),
            const SizedBox(width: 8),
            Expanded(child: Stepper2(label: 'Yellow ban', value: r.yellowBan, min: 1, max: 4, onChanged: (v) => set(() => r.yellowBan = v))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Stepper2(label: 'Second yellow ban', value: r.secondYellowBan, min: 0, max: 4, onChanged: (v) => set(() => r.secondYellowBan = v))),
            const SizedBox(width: 8),
            Expanded(child: Stepper2(label: 'Straight red ban', value: r.redBan, min: 0, max: 8, onChanged: (v) => set(() => r.redBan = v))),
          ]),
          const SectionHeader('Match'),
          Row(children: [
            Expanded(child: Stepper2(label: 'Match length (min)', value: r.matchMinutes, min: 20, max: 120, onChanged: (v) => set(() => r.matchMinutes = v))),
            const SizedBox(width: 8),
            Expanded(child: Stepper2(label: 'Forfeit score', value: r.forfeitGoals, min: 1, max: 5, onChanged: (v) => set(() => r.forfeitGoals = v))),
          ]),
          const SizedBox(height: 18),
          Text('Changing points or tiebreakers updates the table straight away. Changing teams, legs or groups needs "Regenerate fixtures" from the competition menu.',
              style: TLText.body(c.inkDim, size: 12)),
        ],
      ),
    );
  }

  Future<void> _editZone(BuildContext context, Zone? z) async {
    final app = AppScope.read(context);
    final comp = widget.comp;
    final label = TextEditingController(text: z?.label ?? '');
    var from = z?.from ?? 1, to = z?.to ?? 1, color = z?.color ?? 0xFF4DA3FF;
    final n = comp.teamIds.length;
    final res = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: Text(z == null ? 'Add zone' : 'Edit zone'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: label, decoration: const InputDecoration(labelText: 'Label', hintText: 'Promotion, Relegation…')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Stepper2(label: 'From', value: from, min: 1, max: n, onChanged: (v) => setS(() => from = v))),
              const SizedBox(width: 8),
              Expanded(child: Stepper2(label: 'To', value: to < from ? from : to, min: from, max: n, onChanged: (v) => setS(() => to = v))),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final col in [0xFFFFC23D, 0xFF3BE37F, 0xFF4DA3FF, 0xFFB07CFF, 0xFFFF8A3D, 0xFFFF4F5E])
                GestureDetector(
                  onTap: () => setS(() => color = col),
                  child: Container(width: 28, height: 28, decoration: BoxDecoration(color: Color(col), shape: BoxShape.circle, border: Border.all(color: color == col ? Colors.white : Colors.transparent, width: 3))),
                ),
            ]),
          ]),
          actions: [
            if (z != null) TextButton(onPressed: () => Navigator.pop(context, 'delete'), child: const Text('Delete')),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (res == 'delete') app.update(() => comp.zones.remove(z));
    if (res == 'save') {
      app.update(() {
        final zz = z ?? Zone(label: '', from: 1, to: 1, color: color);
        zz
          ..label = label.text.trim().isEmpty ? 'Zone' : label.text.trim()
          ..from = from
          ..to = to < from ? from : to
          ..color = color;
        if (z == null) comp.zones.add(zz);
      });
    }
  }

  Future<void> _addAdjustment(BuildContext context) async {
    final app = AppScope.read(context);
    final comp = widget.comp;
    String? team = comp.teamIds.isEmpty ? null : comp.teamIds.first;
    var pts = -3;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: const Text('Point adjustment'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: team,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Team'),
              items: [for (final id in comp.teamIds) DropdownMenuItem(value: id, child: Text(app.teamName(id), overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setS(() => team = v),
            ),
            const SizedBox(height: 10),
            Stepper2(label: 'Points (negative = deduction)', value: pts, min: -30, max: 30, onChanged: (v) => setS(() => pts = v)),
            const SizedBox(height: 10),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (ok == true && team != null && pts != 0) {
      app.update(() => comp.adjustments.add(PointAdjustment(id: newId(), teamId: team!, points: pts, reason: reason.text.trim())));
    }
  }
}
