import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import 'competition_wizard.dart' show palette;
import 'team_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final list = app.teams.where((t) => _q.isEmpty || t.name.toLowerCase().contains(_q) || t.city.toLowerCase().contains(_q)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: const Text('Teams')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final t = await showTeamEditor(context);
          if (t != null && context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamScreen(team: t)));
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New team'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          TextField(
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: const InputDecoration(hintText: 'Search teams', prefixIcon: Icon(Icons.search_rounded), isDense: true),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const EmptyState(icon: Icons.shield_outlined, title: 'No teams', body: 'Add clubs with their colours, ground and squad. Teams can play in many competitions.'),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 560 ? 2 : 1);
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in list)
                  SizedBox(
                    width: (box.maxWidth - (cols - 1) * 10) / cols,
                    child: TLCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamScreen(team: t))),
                      child: Row(children: [
                        Crest(t, size: 42),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.name, style: TLText.body(c.ink, weight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                            Text(
                              [
                                '${t.players.length} players',
                                if (t.city.isNotEmpty) t.city,
                                '${app.competitions.where((x) => x.teamIds.contains(t.id)).length} comps',
                              ].join(' · '),
                              style: TLText.body(c.inkDim, size: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ]),
                        ),
                        Icon(Icons.chevron_right_rounded, color: c.inkDim),
                      ]),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// Create or edit a team. Returns the team (new or edited) or null.
Future<Team?> showTeamEditor(BuildContext context, {Team? team}) {
  return Navigator.of(context).push<Team>(MaterialPageRoute(builder: (_) => _TeamEditor(team: team)));
}

class _TeamEditor extends StatefulWidget {
  final Team? team;
  const _TeamEditor({this.team});

  @override
  State<_TeamEditor> createState() => _TeamEditorState();
}

class _TeamEditorState extends State<_TeamEditor> {
  late final _name = TextEditingController(text: widget.team?.name ?? '');
  late final _short = TextEditingController(text: widget.team?.short ?? '');
  late final _ground = TextEditingController(text: widget.team?.ground ?? '');
  late final _city = TextEditingController(text: widget.team?.city ?? '');
  late final _coach = TextEditingController(text: widget.team?.coach ?? '');
  late final _contact = TextEditingController(text: widget.team?.contact ?? '');
  late final _founded = TextEditingController(text: widget.team?.founded?.toString() ?? '');
  late int _c1 = widget.team?.color1 ?? palette[2];
  late int _c2 = widget.team?.color2 ?? 0xFFFFFFFF;
  bool _shortEdited = false;

  static const _kit = [...palette, 0xFF101010, 0xFF9E9E9E, 0xFF0D47A1, 0xFF1B5E20, 0xFF880E4F, 0xFFFFEB3B];

  Team get _preview => Team(id: 'p', name: _name.text.isEmpty ? 'Team' : _name.text, short: _short.text.isEmpty ? null : _short.text.toUpperCase(), color1: _c1, color2: _c2);

  void _save() {
    final app = AppScope.read(context);
    if (_name.text.trim().isEmpty) return;
    final short = (_short.text.trim().isEmpty ? Team.defaultShort(_name.text) : _short.text.trim().toUpperCase());
    Team t;
    if (widget.team == null) {
      t = Team(id: newId(), name: _name.text.trim(), short: short);
      app.teams.add(t);
    } else {
      t = widget.team!;
    }
    app.update(() {
      t
        ..name = _name.text.trim()
        ..short = short.length > 4 ? short.substring(0, 4) : short
        ..color1 = _c1
        ..color2 = _c2
        ..ground = _ground.text.trim()
        ..city = _city.text.trim()
        ..coach = _coach.text.trim()
        ..contact = _contact.text.trim()
        ..founded = int.tryParse(_founded.text.trim());
    });
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tl;
    Widget swatches(int sel, ValueChanged<int> on) => Wrap(spacing: 8, runSpacing: 8, children: [
          for (final col in _kit)
            GestureDetector(
              onTap: () => setState(() => on(col)),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: Color(col), shape: BoxShape.circle, border: Border.all(color: sel == col ? c.ink : c.line, width: sel == col ? 3 : 1)),
              ),
            ),
        ]);
    return Scaffold(
      appBar: AppBar(title: Text(widget.team == null ? 'New team' : 'Edit team'), actions: [TextButton(onPressed: _save, child: const Text('Save'))]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
        children: [
          Center(child: Crest(_preview, size: 84)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => setState(() {
              if (!_shortEdited) _short.text = Team.defaultShort(v);
            }),
            decoration: const InputDecoration(labelText: 'Team name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _short,
            textCapitalization: TextCapitalization.characters,
            maxLength: 4,
            onChanged: (_) => setState(() => _shortEdited = true),
            decoration: const InputDecoration(labelText: 'Short code (scoreboards)', counterText: ''),
          ),
          const SectionHeader('Main colour'),
          swatches(_c1, (v) => _c1 = v),
          const SectionHeader('Second colour'),
          swatches(_c2, (v) => _c2 = v),
          const SectionHeader('Club details'),
          TextField(controller: _ground, decoration: const InputDecoration(labelText: 'Home ground', prefixIcon: Icon(Icons.stadium_outlined))),
          const SizedBox(height: 10),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'Town / city')),
          const SizedBox(height: 10),
          TextField(controller: _coach, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Head coach')),
          const SizedBox(height: 10),
          TextField(controller: _contact, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contact (manager phone / email)')),
          const SizedBox(height: 10),
          TextField(controller: _founded, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Founded (year)')),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const Text('Save team')),
        ],
      ),
    );
  }
}
