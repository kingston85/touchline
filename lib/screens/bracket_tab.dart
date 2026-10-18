import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/scheduler.dart';
import '../core/standings.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import 'home_screen.dart';

class BracketTab extends StatelessWidget {
  final Competition comp;
  const BracketTab({super.key, required this.comp});

  @override
  Widget build(BuildContext context) {
    final c = context.tl;
    final ko = comp.knockoutMatches.toList();
    if (ko.isEmpty) {
      return const Center(child: EmptyState(icon: Icons.account_tree_outlined, title: 'No bracket yet', body: 'Regenerate fixtures from the menu to build one.'));
    }
    final maxRound = ko.map((m) => m.round).reduce(math.max);
    final rounds = maxRound + 1;
    final size = 1 << rounds;
    // Ties keyed by (round, slot); third place handled separately.
    final ties = <(int, int), List<Fixture>>{};
    Fixture? third;
    for (final f in ko) {
      if (f.round == maxRound && f.slot == 1) {
        third = f;
        continue;
      }
      (ties[(f.round, f.slot)] ??= []).add(f);
    }
    for (final l in ties.values) {
      l.sort((a, b) => a.leg.compareTo(b.leg));
    }
    const cardW = 210.0, cardH = 78.0, gapY = 18.0, colGap = 46.0, headH = 34.0;
    final unit = cardH + gapY;
    final firstTies = size ~/ 2;
    final height = headH + firstTies * unit + (third != null ? cardH + 60 : 0);
    final width = rounds * (cardW + colGap);
    double cy(int r, int slot) => headH + (slot + 0.5) * (1 << r) * unit;
    double cx(int r) => r * (cardW + colGap);

    final children = <Widget>[];
    for (var r = 0; r < rounds; r++) {
      final teamsInRound = size >> r;
      children.add(Positioned(
        left: cx(r),
        top: 0,
        width: cardW,
        child: Text(roundName(teamsInRound).toUpperCase(), textAlign: TextAlign.center, style: TLText.label(r == rounds - 1 ? TLColors.gold : c.inkDim, size: 11)),
      ));
      for (var s = 0; s < (size >> (r + 1)); s++) {
        final t = ties[(r, s)];
        children.add(Positioned(
          left: cx(r),
          top: cy(r, s) - cardH / 2,
          width: cardW,
          height: cardH,
          child: t == null ? _ByeCard(height: cardH) : _TieCard(comp: comp, legs: t, isFinal: r == rounds - 1),
        ));
      }
    }
    if (third != null) {
      final tf = third;
      children.add(Positioned(
        left: cx(rounds - 1),
        top: cy(rounds - 1, 0) + cardH / 2 + 40,
        width: cardW,
        child: Text('THIRD PLACE', textAlign: TextAlign.center, style: TLText.label(c.inkDim, size: 11)),
      ));
      children.add(Positioned(
        left: cx(rounds - 1),
        top: cy(rounds - 1, 0) + cardH / 2 + 58,
        width: cardW,
        height: cardH,
        child: _TieCard(comp: comp, legs: [tf], isFinal: false),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          height: math.max(height, headH + 2 * unit),
          child: CustomPaint(
            painter: _Connectors(rounds: rounds, size: size, cy: cy, cx: cx, cardW: cardW, color: c.line),
            child: Stack(children: children),
          ),
        ),
      ),
    );
  }
}

class _Connectors extends CustomPainter {
  final int rounds, size;
  final double Function(int, int) cy;
  final double Function(int) cx;
  final double cardW;
  final Color color;
  _Connectors({required this.rounds, required this.size, required this.cy, required this.cx, required this.cardW, required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (var r = 0; r < rounds - 1; r++) {
      for (var slot = 0; slot < (size >> (r + 1)); slot++) {
        final x0 = cx(r) + cardW, x1 = cx(r + 1);
        final mid = (x0 + x1) / 2;
        final y0 = cy(r, slot), y1 = cy(r + 1, slot ~/ 2);
        final path = Path()
          ..moveTo(x0, y0)
          ..lineTo(mid, y0)
          ..lineTo(mid, y1)
          ..lineTo(x1, y1);
        canvas.drawPath(path, p);
      }
    }
  }

  @override
  bool shouldRepaint(_Connectors o) => o.color != color || o.rounds != rounds;
}

class _ByeCard extends StatelessWidget {
  final double height;
  const _ByeCard({required this.height});

  @override
  Widget build(BuildContext context) {
    final c = context.tl;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: c.line.withOpacity(0.5))),
      child: Text('bye', style: TLText.body(c.inkDim, size: 12)),
    );
  }
}

class _TieCard extends StatelessWidget {
  final Competition comp;
  final List<Fixture> legs;
  final bool isFinal;
  const _TieCard({required this.comp, required this.legs, required this.isFinal});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final first = legs.first;
    final res = resolveTie(comp, legs.last);
    // Team A is leg-1 home side.
    final a = first.homeId, b = first.awayId;
    final aLabel = first.homeLabel, bLabel = first.awayLabel;
    int? goalsFor(String? t) {
      if (t == null || !legs.any((m) => m.played)) return null;
      var g = 0;
      for (final m in legs.where((m) => m.played)) {
        g += m.homeId == t ? m.homeGoals : (m.awayId == t ? m.awayGoals : 0);
      }
      return g;
    }

    final live = legs.any((m) => m.status == MatchStatus.live);
    Widget row(String? id, String label, int? goals) {
      final won = res.winner != null && res.winner == id;
      final lost = res.winner != null && res.winner != id;
      return Row(children: [
        Crest(app.team(id), size: 18, placeholder: label.isEmpty ? '?' : label.split(' ').last),
        const SizedBox(width: 8),
        Expanded(
          child: Text(app.team(id)?.name ?? (label.isEmpty ? 'TBD' : label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TLText.body(lost || id == null ? c.inkDim : c.ink, size: 12.5, weight: won ? FontWeight.w800 : FontWeight.w500)),
        ),
        if (goals != null) Text('$goals', style: TLText.score(17, won ? c.accent : (lost ? c.inkDim : c.ink))),
      ]);
    }

    final target = legs.firstWhere((m) => !m.played, orElse: () => legs.last);
    final when = first.kickoff;
    return Material(
      color: isFinal ? Color.lerp(c.surface, TLColors.gold, 0.08) : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: live ? c.poor : (isFinal ? TLColors.gold.withOpacity(0.6) : c.line)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openFixture(context, comp, target),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              row(a, aLabel, goalsFor(a)),
              row(b, bLabel, goalsFor(b)),
              Text(
                res.summary.isNotEmpty && res.winner != null
                    ? res.summary
                    : (live ? 'LIVE' : (when == null ? (legs.length > 1 ? '2 legs' : '') : '${dayDate(when)}${legs.length > 1 ? ' · 2 legs' : ''}')),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TLText.body(live ? c.poor : c.inkDim, size: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
