import 'package:flutter/material.dart';

import '../core/formations.dart';
import '../core/standings.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';

/// Read-only pitch showing a line-up in formation.
class PitchView extends StatelessWidget {
  final Team? team;
  final Lineup lineup;
  final Set<String> suspended;
  final void Function(int slot)? onSlotTap;
  final int? selectedSlot;
  const PitchView({super.key, required this.team, required this.lineup, this.suspended = const {}, this.onSlotTap, this.selectedSlot});

  @override
  Widget build(BuildContext context) {
    final slots = formationSlots(lineup.formation);
    return AspectRatio(
      aspectRatio: 0.74,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          return Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: PitchPainter(grass1: const Color(0xFF1F7A3F), grass2: const Color(0xFF237F44), lines: Colors.white.withOpacity(0.55)),
              ),
            ),
            for (var i = 0; i < slots.length; i++)
              Positioned(
                left: slots[i].dx * w - 39,
                top: (1 - slots[i].dy) * h - 26,
                child: GestureDetector(
                  onTap: onSlotTap == null ? null : () => onSlotTap!(i),
                  child: AnimatedScale(
                    scale: selectedSlot == i ? 1.18 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: ShirtDot(
                      team: team,
                      player: i < lineup.starters.length ? team?.player(lineup.starters[i]) : null,
                      captain: i < lineup.starters.length && lineup.starters[i] == lineup.captainId,
                      suspended: i < lineup.starters.length && suspended.contains(lineup.starters[i]),
                    ),
                  ),
                ),
              ),
          ]);
        }),
      ),
    );
  }
}

class LineupEditor extends StatefulWidget {
  final Competition comp;
  final Fixture fixture;
  final bool home;
  const LineupEditor({super.key, required this.comp, required this.fixture, required this.home});

  @override
  State<LineupEditor> createState() => _LineupEditorState();
}

class _LineupEditorState extends State<LineupEditor> {
  late Lineup _lu;
  int? _slot;

  @override
  void initState() {
    super.initState();
    final src = widget.fixture.lineup(widget.home);
    _lu = Lineup(formation: src.formation, starters: [...src.starters], bench: [...src.bench], captainId: src.captainId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lu.isEmpty) {
      final app = AppScope.read(context);
      // Reuse the team's last line-up in this competition if there is one.
      final prev = widget.comp.matches.where((m) => m != widget.fixture && m.played && m.involves(widget.fixture.teamId(widget.home)!)).toList()
        ..sort((a, b) => (b.kickoff ?? DateTime(2000)).compareTo(a.kickoff ?? DateTime(2000)));
      if (prev.isNotEmpty) {
        final p = prev.first.lineup(prev.first.homeId == widget.fixture.teamId(widget.home));
        if (!p.isEmpty) _lu = Lineup(formation: p.formation, starters: [...p.starters], bench: [...p.bench], captainId: p.captainId);
      }
      if (_lu.isEmpty) _lu.formation = app.settings.defaultFormation;
    }
  }

  Team get _team => AppScope.read(context).team(widget.fixture.teamId(widget.home))!;

  void _pick(String playerId) {
    setState(() {
      final s = _slot;
      if (s == null) return;
      // Swap if the player is already placed elsewhere.
      final at = _lu.starters.indexOf(playerId);
      while (_lu.starters.length <= s) {
        _lu.starters.add('');
      }
      final prev = _lu.starters[s];
      if (at >= 0) _lu.starters[at] = prev;
      _lu.starters[s] = playerId;
      _lu.bench.remove(playerId);
      _slot = s + 1 < 11 ? s + 1 : null;
    });
  }

  void _save() {
    final app = AppScope.read(context);
    final starters = _lu.starters.where((id) => id.isNotEmpty).toList();
    app.update(() {
      final target = widget.home ? widget.fixture.homeLineup : widget.fixture.awayLineup;
      target
        ..formation = _lu.formation
        ..starters = starters
        ..bench = _lu.bench.where((id) => !starters.contains(id)).toList()
        ..captainId = _lu.captainId;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final team = app.team(widget.fixture.teamId(widget.home));
    if (team == null) return const Scaffold();
    final d = discipline(widget.comp, asOf: widget.fixture.played ? widget.fixture.kickoff : null);
    final suspended = d.active.keys.toSet();
    final placed = _lu.starters.where((id) => id.isNotEmpty).toSet();
    final squad = [...team.players]..sort((a, b) {
        final p = a.position.index.compareTo(b.position.index);
        return p != 0 ? p : (a.number ?? 99).compareTo(b.number ?? 99);
      });
    final wide = MediaQuery.sizeOf(context).width >= 760;

    final pitch = Column(children: [
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final f in formations)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(label: Text(f), selected: _lu.formation == f, onSelected: (_) => setState(() => _lu.formation = f)),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      PitchView(team: team, lineup: _lu, suspended: suspended, selectedSlot: _slot, onSlotTap: (i) => setState(() => _slot = _slot == i ? null : i)),
      const SizedBox(height: 8),
      Text(_slot == null ? 'Tap a position, then a player from the squad.' : 'Choose a player for position ${_slot! + 1} (${slotRole(_lu.formation, _slot!).label}).',
          style: TLText.body(_slot == null ? c.inkDim : c.accent, size: 12.5), textAlign: TextAlign.center),
    ]);

    final list = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('SQUAD · ${placed.length}/11 · ${_lu.bench.length} subs', style: TLText.label(c.inkDim))),
        TextButton.icon(
          onPressed: () => setState(() {
            final r = autoLineup(team, _lu.formation, unavailable: suspended);
            _lu.starters = r.$1;
            _lu.bench = r.$2;
            _lu.captainId ??= team.players.where((p) => p.captain).firstOrNull?.id;
          }),
          icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
          label: const Text('Auto-pick'),
        ),
      ]),
      for (final p in squad)
        () {
          final inXI = placed.contains(p.id);
          final onBench = _lu.bench.contains(p.id);
          final sus = suspended.contains(p.id);
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: inXI ? c.accent.withOpacity(0.12) : (onBench ? c.surface2 : c.surface),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: inXI ? c.accent.withOpacity(0.5) : c.line),
            ),
            child: ListTile(
              dense: true,
              onTap: sus
                  ? null
                  : () {
                      if (_slot != null) {
                        _pick(p.id);
                        return;
                      }
                      setState(() {
                        if (onBench) {
                          _lu.bench.remove(p.id);
                        } else if (!inXI) {
                          _lu.bench.add(p.id);
                        }
                      });
                    },
              leading: SizedBox(width: 30, child: Text('${p.number ?? ''}', style: TLText.score(18, c.inkDim))),
              title: Text(p.name, style: TLText.body(sus ? c.inkDim : c.ink, weight: FontWeight.w600)),
              subtitle: Text(
                [p.position.short, if (sus) 'SUSPENDED', if (inXI) 'starting', if (onBench) 'bench'].join(' · '),
                style: TLText.body(sus ? c.poor : c.inkDim, size: 11.5),
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (inXI)
                  IconButton(
                    tooltip: 'Captain',
                    icon: Icon(Icons.copyright_rounded, color: _lu.captainId == p.id ? TLColors.gold : c.inkDim, size: 20),
                    onPressed: () => setState(() => _lu.captainId = p.id),
                  ),
                if (inXI)
                  IconButton(
                    tooltip: 'Remove from XI',
                    icon: Icon(Icons.remove_circle_outline_rounded, color: c.inkDim, size: 20),
                    onPressed: () => setState(() {
                      final i = _lu.starters.indexOf(p.id);
                      if (i >= 0) _lu.starters[i] = '';
                    }),
                  ),
              ]),
            ),
          );
        }(),
      const SizedBox(height: 6),
      Text('Tap a player with no position selected to add or remove them from the bench.', style: TLText.body(c.inkDim, size: 11.5)),
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Text('${team.short} line-up'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [pitch])),
              Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [list])),
            ])
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
              pitch,
              const SizedBox(height: 16),
              if (team.players.isEmpty)
                const EmptyState(icon: Icons.person_add_alt_rounded, title: 'No players', body: 'Add players to this team first (Teams tab).')
              else
                list,
            ]),
    );
  }
}
