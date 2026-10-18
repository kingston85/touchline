import 'package:flutter/material.dart';

import '../core/standings.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import '../widgets/inputs.dart';
import 'home_screen.dart';
import 'player_screen.dart';
import 'teams_screen.dart';

enum _TeamTab { squad, matches, stats }

class TeamScreen extends StatefulWidget {
  final Team team;
  final Competition? comp; // when opened from a competition, focus it
  const TeamScreen({super.key, required this.team, this.comp});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  _TeamTab _tab = _TeamTab.squad;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final t = widget.team;
    final comps = app.competitions.where((x) => x.teamIds.contains(t.id) || x.matches.any((m) => m.involves(t.id))).toList();
    final matches = [
      for (final comp in comps)
        for (final m in comp.matches.where((m) => m.involves(t.id))) (comp, m),
    ]..sort((a, b) => (a.$2.kickoff ?? DateTime(2100)).compareTo(b.$2.kickoff ?? DateTime(2100)));
    final played = matches.where((e) => e.$2.played).toList();
    final w = played.where((e) => outcome(e.$2, t.id) > 0).length;
    final d = played.where((e) => outcome(e.$2, t.id) == 0).length;
    final l = played.length - w - d;
    final form = played.reversed.take(5).toList().reversed.map((e) => switch (outcome(e.$2, t.id)) { 1 => 'W', 0 => 'D', _ => 'L' }).toList();

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 210,
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          title: Text(t.name),
          actions: [
            IconButton(
              tooltip: 'Edit team',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => showTeamEditor(context, team: t),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Delete ${t.name}?'),
                      content: const Text('The team and its squad are removed from the library and from competitions that haven\'t generated fixtures with it. Past fixtures keep their scores but show "TBD".'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    app.deleteTeam(t);
                    Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete team'))],
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(t.color1).withOpacity(0.45), c.bg], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
              padding: const EdgeInsets.fromLTRB(20, 92, 20, 12),
              child: Row(children: [
                Crest(t, size: 76),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(t.name, style: TLText.headline(c.ink, size: 26), maxLines: 2),
                    Text([if (t.city.isNotEmpty) t.city, if (t.founded != null) 'est. ${t.founded}', if (t.ground.isNotEmpty) t.ground].join(' · '),
                        style: TLText.body(c.inkDim, size: 12.5), maxLines: 2),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text('$w-$d-$l', style: TLText.score(18, c.ink)),
                      const SizedBox(width: 10),
                      if (form.isNotEmpty) FormGuide(form, size: 16),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Segmented<_TeamTab>(
                values: _TeamTab.values,
                selected: _tab,
                label: (v) => switch (v) { _TeamTab.squad => 'Squad (${t.players.length})', _TeamTab.matches => 'Matches', _TeamTab.stats => 'Stats' },
                onChanged: (v) => setState(() => _tab = v),
              ),
              const SizedBox(height: 12),
              switch (_tab) {
                _TeamTab.squad => _Squad(team: t),
                _TeamTab.matches => matches.isEmpty
                    ? const EmptyState(icon: Icons.calendar_month_outlined, title: 'No matches', body: 'Add this team to a competition to schedule matches.')
                    : TLCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(children: [
                          for (final e in matches) FixtureTile(comp: e.$1, fixture: e.$2, showComp: true, highlightTeam: t.id, onTap: () => openFixture(context, e.$1, e.$2)),
                        ]),
                      ),
                _TeamTab.stats => _TeamStatsView(team: t, comps: comps, focus: widget.comp),
              },
              if (t.coach.isNotEmpty || t.contact.isNotEmpty) ...[
                const SectionHeader('Staff & contact'),
                TLCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (t.coach.isNotEmpty) Text('Head coach: ${t.coach}', style: TLText.body(c.ink)),
                    if (t.contact.isNotEmpty && t.contact != 'demo') Text('Contact: ${t.contact}', style: TLText.body(c.inkDim)),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Squad extends StatelessWidget {
  final Team team;
  const _Squad({required this.team});

  @override
  Widget build(BuildContext context) {
    final c = context.tl;
    final t = team;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: FilledButton.icon(onPressed: () => showPlayerEditor(context, t), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add player')),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(onPressed: () => _bulkAdd(context, t), icon: const Icon(Icons.playlist_add_rounded), label: const Text('Paste list')),
        ),
      ]),
      if (t.players.isEmpty)
        const EmptyState(icon: Icons.groups_outlined, title: 'No players yet', body: 'Add players one by one, or paste a list like "1 John Doe GK".'),
      for (final pos in Position.values)
        if (t.players.any((p) => p.position == pos)) ...[
          SectionHeader('${pos.label}s'),
          TLCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final p in (t.players.where((p) => p.position == pos).toList()..sort((a, b) => (a.number ?? 99).compareTo(b.number ?? 99))))
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: teamColor(t), shape: BoxShape.circle, border: Border.all(color: Color(t.color2), width: 2)),
                    child: Text('${p.number ?? ''}', style: TLText.score(16, teamColor(t).computeLuminance() > 0.55 ? Colors.black : Colors.white)),
                  ),
                  title: Row(children: [
                    Flexible(child: Text(p.name, style: TLText.body(c.ink, weight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    if (p.captain) ...[const SizedBox(width: 6), const Tag('C', color: TLColors.gold)],
                  ]),
                  subtitle: Text(
                    [if (p.birth != null) '${_age(p.birth!)} yrs', if (p.nationality.isNotEmpty) p.nationality].join(' · '),
                    style: TLText.body(c.inkDim, size: 12),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: c.inkDim),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(team: t, player: p))),
                ),
            ]),
          ),
        ],
    ]);
  }

  static int _age(DateTime b) {
    final n = DateTime.now();
    var a = n.year - b.year;
    if (n.month < b.month || (n.month == b.month && n.day < b.day)) a--;
    return a;
  }

  Future<void> _bulkAdd(BuildContext context, Team t) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste squad list'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('One player per line: number, name, position (GK/DF/MF/FW). Number and position are optional.'),
          const SizedBox(height: 10),
          TextField(controller: ctrl, maxLines: 8, decoration: const InputDecoration(hintText: '1 Prince Kollie GK\n4 Amos Flomo DF\n10 Sekou Kamara MF')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final app = AppScope.read(context);
    var n = 0;
    app.update(() {
      for (final line in ctrl.text.split('\n')) {
        var s = line.trim();
        if (s.isEmpty) continue;
        int? num;
        final m = RegExp(r'^(\d{1,2})[\s.,)\-]+').firstMatch(s);
        if (m != null) {
          num = int.parse(m.group(1)!);
          s = s.substring(m.end);
        }
        var pos = Position.mf;
        final pm = RegExp(r'[\s,(\-]+(GK|DF|MF|FW|GOALKEEPER|DEFENDER|MIDFIELDER|FORWARD|STRIKER)\)?$', caseSensitive: false).firstMatch(s);
        if (pm != null) {
          final k = pm.group(1)!.toUpperCase();
          pos = k.startsWith('G') ? Position.gk : (k.startsWith('D') ? Position.df : (k.startsWith('F') || k.startsWith('S') ? Position.fw : Position.mf));
          s = s.substring(0, pm.start);
        }
        s = s.trim();
        if (s.isEmpty) continue;
        t.players.add(Player(id: newId(), name: s, number: num, position: pos));
        n++;
      }
    });
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $n players.')));
  }
}

class _TeamStatsView extends StatelessWidget {
  final Team team;
  final List<Competition> comps;
  final Competition? focus;
  const _TeamStatsView({required this.team, required this.comps, this.focus});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    if (comps.isEmpty) return const EmptyState(icon: Icons.insights_outlined, title: 'No stats yet', body: 'Stats appear once the team plays.');
    final ordered = [if (focus != null) focus!, ...comps.where((x) => x != focus)];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final comp in ordered) ...[
        SectionHeader(comp.name),
        () {
          final ps = playerStats(comp, app.team).values.where((s) => s.teamId == team.id).toList()..sort((a, b) => b.goals.compareTo(a.goals));
          if (ps.isEmpty) return Text('No player data yet.', style: TLText.body(c.inkDim, size: 13));
          return TLCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                child: Row(children: [
                  Expanded(child: Text('PLAYER', style: TLText.label(c.inkDim, size: 10))),
                  for (final h in ['APP', 'G', 'A', 'YC', 'RC'])
                    SizedBox(width: 34, child: Text(h, textAlign: TextAlign.center, style: TLText.label(c.inkDim, size: 10))),
                ]),
              ),
              for (final s in ps)
                InkWell(
                  onTap: () {
                    final p = team.player(s.playerId);
                    if (p != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(team: team, player: p)));
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                    child: Row(children: [
                      Expanded(child: Text(team.player(s.playerId)?.name ?? '?', style: TLText.body(c.ink, size: 13), overflow: TextOverflow.ellipsis)),
                      for (final v in [s.apps, s.goals, s.assists, s.yellows, s.reds])
                        SizedBox(width: 34, child: Text('$v', textAlign: TextAlign.center, style: TLText.reading(12.5, v == 0 ? c.inkDim : c.ink))),
                    ]),
                  ),
                ),
            ]),
          );
        }(),
      ],
    ]);
  }
}

Future<void> showPlayerEditor(BuildContext context, Team team, {Player? player}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlayerEditor(team: team, player: player),
  );
}

class _PlayerEditor extends StatefulWidget {
  final Team team;
  final Player? player;
  const _PlayerEditor({required this.team, this.player});

  @override
  State<_PlayerEditor> createState() => _PlayerEditorState();
}

class _PlayerEditorState extends State<_PlayerEditor> {
  late final _name = TextEditingController(text: widget.player?.name ?? '');
  late final _num = TextEditingController(text: widget.player?.number?.toString() ?? '');
  late final _nat = TextEditingController(text: widget.player?.nationality ?? '');
  late Position _pos = widget.player?.position ?? Position.mf;
  late DateTime? _birth = widget.player?.birth;
  late bool _captain = widget.player?.captain ?? false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final clash = int.tryParse(_num.text) != null && widget.team.players.any((p) => p != widget.player && p.number == int.tryParse(_num.text));
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.player == null ? 'Add player · ${widget.team.short}' : 'Edit player', style: TLText.title(c.ink)),
          const SizedBox(height: 14),
          Row(children: [
            SizedBox(
              width: 84,
              child: TextField(
                controller: _num,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: TLText.score(22, c.ink),
                decoration: InputDecoration(labelText: 'No.', errorText: clash ? 'taken' : null),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _name, autofocus: widget.player == null, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name'))),
          ]),
          const SizedBox(height: 12),
          Segmented<Position>(values: Position.values, selected: _pos, label: (p) => p.label, onChanged: (p) => setState(() => _pos = p)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: _birth ?? DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now());
                  if (d != null) setState(() => _birth = d);
                },
                icon: const Icon(Icons.cake_outlined),
                label: Text(_birth == null ? 'Date of birth' : shortDate(_birth!)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _nat, decoration: const InputDecoration(labelText: 'Nationality'))),
          ]),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: _captain, onChanged: (v) => setState(() => _captain = v), title: const Text('Club captain')),
          const SizedBox(height: 8),
          Row(children: [
            if (widget.player != null)
              IconButton(
                tooltip: 'Remove player',
                onPressed: () {
                  app.update(() => widget.team.players.remove(widget.player));
                  Navigator.pop(context);
                },
                icon: Icon(Icons.delete_outline_rounded, color: c.poor),
              ),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  if (_name.text.trim().isEmpty) return;
                  app.update(() {
                    final p = widget.player ?? Player(id: newId(), name: _name.text.trim());
                    p
                      ..name = _name.text.trim()
                      ..number = int.tryParse(_num.text.trim())
                      ..position = _pos
                      ..birth = _birth
                      ..nationality = _nat.text.trim()
                      ..captain = _captain;
                    if (_captain) {
                      for (final o in widget.team.players) {
                        if (o != p) o.captain = false;
                      }
                    }
                    if (widget.player == null) widget.team.players.add(p);
                  });
                  if (widget.player == null) {
                    // Keep the sheet open for fast squad entry.
                    _name.clear();
                    final n = int.tryParse(_num.text.trim());
                    _num.text = n == null ? '' : '${n + 1}';
                    _captain = false;
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player added. Add the next one or close.'), duration: Duration(milliseconds: 1200)));
                  } else {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.check_rounded),
                label: Text(widget.player == null ? 'Add & next' : 'Save'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
