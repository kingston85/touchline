import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/standings.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/football.dart';
import '../widgets/inputs.dart';
import 'team_screen.dart';

class TableTab extends StatefulWidget {
  final Competition comp;
  const TableTab({super.key, required this.comp});

  @override
  State<TableTab> createState() => _TableTabState();
}

class _TableTabState extends State<TableTab> {
  TableView _view = TableView.overall;
  final Set<String> _chartTeams = {};

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final comp = widget.comp;
    final isLeague = comp.format == Format.league;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
      children: [
        Segmented<TableView>(
          values: TableView.values,
          selected: _view,
          label: (v) => switch (v) { TableView.overall => 'Overall', TableView.home => 'Home', TableView.away => 'Away' },
          onChanged: (v) => setState(() => _view = v),
        ),
        const SizedBox(height: 12),
        if (isLeague)
          StandingsTable(comp: comp, rows: app.table(comp, view: _view), zones: _view == TableView.overall ? comp.zones : const [])
        else
          for (final g in comp.groups.keys) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              child: Text('GROUP $g', style: TLText.headline(c.ink, size: 20)),
            ),
            StandingsTable(
              comp: comp,
              rows: app.table(comp, group: g, view: _view),
              zones: [Zone(label: 'Qualify for knockout', from: 1, to: comp.rules.advance, color: c.accent.value)],
            ),
            const SizedBox(height: 14),
          ],
        if (isLeague && comp.zones.isNotEmpty && _view == TableView.overall) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (final z in comp.zones)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(z.color), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text(z.label, style: TLText.body(c.inkDim, size: 12)),
              ]),
          ]),
        ],
        if (comp.adjustments.isNotEmpty && _view == TableView.overall) ...[
          const SizedBox(height: 10),
          for (final a in comp.adjustments)
            Text('${app.teamName(a.teamId)}: ${a.points > 0 ? '+' : ''}${a.points} pts${a.reason.isEmpty ? '' : ' (${a.reason})'}',
                style: TLText.body(c.fair, size: 12)),
        ],
        const SizedBox(height: 6),
        Text('Tiebreakers: points, then ${comp.rules.tiebreaks.map((t) => t.label.toLowerCase()).join(', ')}.',
            style: TLText.body(c.inkDim, size: 11.5)),
        if (isLeague && comp.matches.any((m) => m.played)) ...[
          const SectionHeader('Position through the season'),
          _PositionChart(comp: comp, selected: _chartTeams, onToggle: (id) => setState(() => _chartTeams.contains(id) ? _chartTeams.remove(id) : _chartTeams.add(id))),
        ],
      ],
    );
  }
}

class StandingsTable extends StatelessWidget {
  final Competition comp;
  final List<Standing> rows;
  final List<Zone> zones;
  const StandingsTable({super.key, required this.comp, required this.rows, this.zones = const []});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 560;
      final cols = wide ? ['P', 'W', 'D', 'L', 'GF', 'GA', 'GD', 'Pts'] : ['P', 'W', 'D', 'L', 'GD', 'Pts'];
      const cw = 30.0;
      Widget num(String s, {bool bold = false, Color? color}) =>
          SizedBox(width: cw, child: Text(s, textAlign: TextAlign.center, style: TLText.reading(12.5, color ?? (bold ? c.ink : c.inkDim), weight: bold ? FontWeight.w700 : FontWeight.w500)));
      Color? zoneColor(int pos) {
        for (final z in zones) {
          if (pos >= z.from && pos <= z.to) return Color(z.color);
        }
        return null;
      }

      return TLCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
            child: Row(children: [
              SizedBox(width: 26, child: Text('#', style: TLText.label(c.inkDim, size: 10))),
              Expanded(child: Text('TEAM', style: TLText.label(c.inkDim, size: 10))),
              for (final h in cols) SizedBox(width: cw, child: Text(h, textAlign: TextAlign.center, style: TLText.label(c.inkDim, size: 10))),
              if (wide) SizedBox(width: 112, child: Text('FORM', textAlign: TextAlign.center, style: TLText.label(c.inkDim, size: 10))),
            ]),
          ),
          for (var i = 0; i < rows.length; i++)
            InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamScreen(team: app.team(rows[i].teamId)!, comp: comp))),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: zoneColor(i + 1) ?? Colors.transparent, width: 4),
                    top: BorderSide(color: c.line.withOpacity(0.6), width: 0.6),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                child: Row(children: [
                  SizedBox(width: 26, child: Text('${i + 1}', style: TLText.score(16, zoneColor(i + 1) ?? c.inkDim))),
                  Crest(app.team(rows[i].teamId), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      wide ? app.teamName(rows[i].teamId) : (app.team(rows[i].teamId)?.name ?? ''),
                      style: TLText.body(c.ink, size: 13.5, weight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  num('${rows[i].played}'),
                  num('${rows[i].won}'),
                  num('${rows[i].drawn}'),
                  num('${rows[i].lost}'),
                  if (wide) num('${rows[i].gf}'),
                  if (wide) num('${rows[i].ga}'),
                  num(rows[i].gd > 0 ? '+${rows[i].gd}' : '${rows[i].gd}', color: rows[i].gd > 0 ? c.good : (rows[i].gd < 0 ? c.poor : null)),
                  SizedBox(
                    width: cw,
                    child: Text('${rows[i].points}',
                        textAlign: TextAlign.center, style: TLText.score(17, rows[i].adjust != 0 ? c.fair : c.ink)),
                  ),
                  if (wide) SizedBox(width: 112, child: Center(child: FormGuide(rows[i].last5, size: 16))),
                ]),
              ),
            ),
        ]),
      );
    });
  }
}

class _PositionChart extends StatelessWidget {
  final Competition comp;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _PositionChart({required this.comp, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final hist = positionHistory(comp, names: app.names);
    final table = app.table(comp);
    final show = selected.isEmpty ? table.take(3).map((r) => r.teamId).toSet() : selected;
    final n = comp.teamIds.length;
    return TLCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 220,
          child: CustomPaint(
            size: Size.infinite,
            painter: _PosPainter(
              series: [
                for (final id in show)
                  if (hist[id] != null && hist[id]!.isNotEmpty) (hist[id]!, teamColor(app.team(id))),
              ],
              teams: n,
              grid: c.line,
              label: c.inkDim,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final r in table)
            FilterChip(
              selected: show.contains(r.teamId),
              onSelected: (_) => onToggle(r.teamId),
              avatar: Crest(app.team(r.teamId), size: 16),
              label: Text(app.team(r.teamId)?.short ?? ''),
              visualDensity: VisualDensity.compact,
            ),
        ]),
      ]),
    );
  }
}

class _PosPainter extends CustomPainter {
  final List<(List<int>, Color)> series;
  final int teams;
  final Color grid, label;
  _PosPainter({required this.series, required this.teams, required this.grid, required this.label});

  @override
  void paint(Canvas canvas, Size s) {
    const left = 24.0, bottom = 18.0, top = 6.0, right = 8.0;
    final w = s.width - left - right, h = s.height - top - bottom;
    final rounds = series.fold<int>(1, (a, e) => math.max(a, e.$1.length));
    double x(int i) => left + (rounds <= 1 ? w / 2 : i * w / (rounds - 1));
    double y(int pos) => top + (teams <= 1 ? h / 2 : (pos - 1) * h / (teams - 1));
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 0.6;
    for (var p = 1; p <= teams; p++) {
      if (p == 1 || p == teams || p % 5 == 0) {
        canvas.drawLine(Offset(left, y(p)), Offset(left + w, y(p)), gp);
        final tp = TextPainter(text: TextSpan(text: '$p', style: TextStyle(fontSize: 10, color: label, fontFamily: TLText.mono)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(0, y(p) - tp.height / 2));
      }
    }
    final tp = TextPainter(text: TextSpan(text: 'matchday →', style: TextStyle(fontSize: 10, color: label)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(left + w - tp.width, s.height - tp.height));
    for (final (pts, col) in series) {
      final path = Path();
      for (var i = 0; i < pts.length; i++) {
        final o = Offset(x(i), y(pts[i]));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeJoin = StrokeJoin.round);
      canvas.drawCircle(Offset(x(pts.length - 1), y(pts.last)), 4, Paint()..color = col);
    }
  }

  @override
  bool shouldRepaint(_PosPainter o) => true;
}
