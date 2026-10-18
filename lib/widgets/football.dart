import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

Color teamColor(Team? t) => Color(t?.color1 ?? 0xFF5A6B60);

/// Generated club crest: shield in the club colours with a diagonal sash and
/// the three-letter code.
class Crest extends StatelessWidget {
  final Team? team;
  final double size;
  final String? placeholder;
  const Crest(this.team, {super.key, this.size = 32, this.placeholder});

  @override
  Widget build(BuildContext context) {
    final c = context.tl;
    if (team == null) {
      return Container(
        width: size,
        height: size * 1.12,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(size * 0.22),
          border: Border.all(color: c.line),
        ),
        child: Text(placeholder ?? '?',
            style: TLText.score(size * 0.32, c.inkDim), maxLines: 1, overflow: TextOverflow.clip),
      );
    }
    return SizedBox(
      width: size,
      height: size * 1.12,
      child: CustomPaint(painter: _CrestPainter(Color(team!.color1), Color(team!.color2), team!.short, c.bg)),
    );
  }
}

class _CrestPainter extends CustomPainter {
  final Color a, b, outline;
  final String text;
  _CrestPainter(this.a, this.b, this.text, this.outline);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final path = Path()
      ..moveTo(w * 0.08, h * 0.06)
      ..quadraticBezierTo(w * 0.5, -h * 0.02, w * 0.92, h * 0.06)
      ..lineTo(w * 0.92, h * 0.52)
      ..quadraticBezierTo(w * 0.9, h * 0.84, w * 0.5, h * 0.98)
      ..quadraticBezierTo(w * 0.1, h * 0.84, w * 0.08, h * 0.52)
      ..close();
    canvas.drawPath(path, Paint()..color = a);
    canvas.save();
    canvas.clipPath(path);
    final sash = Path()
      ..moveTo(w * 0.62, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.18)
      ..lineTo(w * 0.18, h)
      ..lineTo(0, h)
      ..lineTo(0, h * 0.86)
      ..close();
    canvas.drawPath(sash, Paint()..color = b.withOpacity(0.92));
    canvas.restore();
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, w * 0.045)
          ..color = Colors.black.withOpacity(0.35));
    final lum = a.computeLuminance();
    final tp = TextPainter(
      text: TextSpan(
        text: text.length > 3 ? text.substring(0, 3) : text,
        style: TextStyle(
          fontFamily: TLText.display,
          fontWeight: FontWeight.w700,
          fontSize: w * 0.36,
          color: lum > 0.55 ? const Color(0xFF0B0F0D) : Colors.white,
          shadows: [Shadow(color: Colors.black.withOpacity(lum > 0.55 ? 0 : 0.45), blurRadius: 2)],
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w);
    tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.47 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_CrestPainter o) => o.a != a || o.b != b || o.text != text;
}

/// W / D / L chips for recent form.
class FormGuide extends StatelessWidget {
  final List<String> form;
  final double size;
  const FormGuide(this.form, {super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final c = context.tl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in form)
          Container(
            width: size,
            height: size,
            margin: const EdgeInsets.only(left: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: r == 'W' ? c.good : (r == 'D' ? c.inkDim.withOpacity(0.55) : c.poor),
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            child: Text(r, style: TLText.score(size * 0.62, r == 'W' ? c.onAccent : Colors.white)),
          ),
      ],
    );
  }
}

/// Pulsing red dot for live matches.
class LiveDot extends StatefulWidget {
  final double size;
  const LiveDot({super.key, this.size = 8});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tl;
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_a),
      child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(color: c.poor, shape: BoxShape.circle)),
    );
  }
}

String fixtureLabel(Competition c, Fixture f) {
  switch (f.stage) {
    case Stage.league:
      return 'Matchday ${f.round}';
    case Stage.group:
      return 'Group ${f.group} · MD ${f.round}';
    case Stage.knockout:
      final maxRound = c.knockoutMatches.map((m) => m.round).fold(0, math.max);
      final teams = 2 << (maxRound - f.round);
      final third = f.round == maxRound && f.slot == 1;
      final name = third ? 'Third place' : _round(teams);
      return f.leg > 0 ? '$name · Leg ${f.leg}' : name;
  }
}

String _round(int teams) => switch (teams) { 2 => 'Final', 4 => 'Semi-final', 8 => 'Quarter-final', _ => 'Round of $teams' };

/// One fixture as a compact row: crest/name — score or time — name/crest.
class FixtureTile extends StatelessWidget {
  final Competition comp;
  final Fixture fixture;
  final VoidCallback? onTap;
  final bool showComp;
  final bool showRound;
  final String? highlightTeam;
  const FixtureTile({
    super.key,
    required this.comp,
    required this.fixture,
    this.onTap,
    this.showComp = false,
    this.showRound = false,
    this.highlightTeam,
  });

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    final f = fixture;
    final home = app.team(f.homeId), away = app.team(f.awayId);
    final live = f.status == MatchStatus.live;
    final done = f.played;
    final hw = done && f.homeGoals > f.awayGoals || (done && f.homeGoals == f.awayGoals && (f.homePens ?? 0) > (f.awayPens ?? 0));
    final aw = done && f.awayGoals > f.homeGoals || (done && f.homeGoals == f.awayGoals && (f.awayPens ?? 0) > (f.homePens ?? 0));

    Widget name(Team? t, String label, bool win, TextAlign align) => Text(
          t?.name ?? (label.isEmpty ? 'TBD' : label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TLText.body(t == null ? c.inkDim : (done && !win ? c.inkDim : c.ink),
              size: 13.5, weight: win || highlightTeam != null && t?.id == highlightTeam ? FontWeight.w700 : FontWeight.w500),
        );

    Widget middle;
    if (done || live) {
      middle = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: live ? c.poor.withOpacity(0.16) : c.surface2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${f.homeGoals}  –  ${f.awayGoals}', style: TLText.score(19, live ? c.poor : c.ink)),
          ),
          if (f.hasPens) Text('pens ${f.homePens}–${f.awayPens}', style: TLText.body(c.inkDim, size: 10)),
          if (live)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const LiveDot(size: 6),
              const SizedBox(width: 4),
              Text(f.period == 2 ? 'HT' : "${f.liveMinute()}'", style: TLText.reading(10.5, c.poor, weight: FontWeight.w700)),
            ]),
        ],
      );
    } else {
      middle = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(f.kickoff == null ? 'vs' : hhmm(f.kickoff!), style: TLText.score(17, f.kickoff == null ? c.inkDim : c.ink)),
          if (f.status == MatchStatus.postponed || f.status == MatchStatus.cancelled)
            Text(f.status.label.toUpperCase(), style: TLText.label(c.fair, size: 9))
          else if (f.kickoff != null)
            Text(dayDate(f.kickoff!), style: TLText.body(c.inkDim, size: 10.5)),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          children: [
            if (showComp || showRound)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    if (showComp) ...[
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: Color(comp.color), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Flexible(child: Text(comp.name, style: TLText.label(c.inkDim, size: 9.5), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                    ],
                    if (showRound) Text(fixtureLabel(comp, f).toUpperCase(), style: TLText.label(c.inkDim, size: 9.5)),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(child: name(home, f.homeLabel, hw, TextAlign.right)),
                      const SizedBox(width: 8),
                      Crest(home, size: 24, placeholder: f.homeLabel.isEmpty ? '?' : f.homeLabel.split(' ').last),
                    ],
                  ),
                ),
                SizedBox(width: 92, child: Center(child: middle)),
                Expanded(
                  child: Row(
                    children: [
                      Crest(away, size: 24, placeholder: f.awayLabel.isEmpty ? '?' : f.awayLabel.split(' ').last),
                      const SizedBox(width: 8),
                      Flexible(child: name(away, f.awayLabel, aw, TextAlign.left)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Coloured square for competition identity.
class CompBadge extends StatelessWidget {
  final Competition comp;
  final double size;
  const CompBadge(this.comp, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final col = Color(comp.color);
    final icon = switch (comp.format) {
      Format.league => Icons.format_list_numbered_rounded,
      Format.knockout => Icons.account_tree_rounded,
      Format.groupsKnockout => Icons.emoji_events_rounded,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [col, Color.lerp(col, Colors.black, 0.45)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: col.computeLuminance() > 0.5 ? Colors.black87 : Colors.white, size: size * 0.5),
    );
  }
}

/// Event icon for timelines.
Widget eventIcon(EventType t, TLColors c, {double size = 18}) {
  switch (t) {
    case EventType.goal:
    case EventType.penaltyGoal:
      return Icon(Icons.sports_soccer_rounded, size: size, color: c.ink);
    case EventType.ownGoal:
      return Icon(Icons.sports_soccer_rounded, size: size, color: c.poor);
    case EventType.penaltyMiss:
      return Icon(Icons.block_rounded, size: size, color: c.poor);
    case EventType.yellow:
      return _card(const Color(0xFFFFD400), size);
    case EventType.secondYellow:
      return SizedBox(
        width: size,
        height: size,
        child: Stack(children: [
          Positioned(left: 0, top: 0, child: _card(const Color(0xFFFFD400), size * 0.85)),
          Positioned(right: 0, bottom: 0, child: _card(const Color(0xFFE53935), size * 0.85)),
        ]),
      );
    case EventType.red:
      return _card(const Color(0xFFE53935), size);
    case EventType.sub:
      return Icon(Icons.swap_vert_rounded, size: size, color: c.accent);
  }
}

Widget _card(Color col, double size) => Container(
      width: size * 0.62,
      height: size * 0.86,
      margin: EdgeInsets.symmetric(horizontal: size * 0.19, vertical: size * 0.07),
      decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2)),
    );

/// Grass-stripe pitch background with markings (vertical, own goal at bottom).
class PitchPainter extends CustomPainter {
  final Color grass1, grass2, lines;
  PitchPainter({required this.grass1, required this.grass2, required this.lines});

  @override
  void paint(Canvas canvas, Size s) {
    const stripes = 10;
    for (var i = 0; i < stripes; i++) {
      canvas.drawRect(Rect.fromLTWH(0, s.height * i / stripes, s.width, s.height / stripes + 1),
          Paint()..color = i.isEven ? grass1 : grass2);
    }
    final p = Paint()
      ..color = lines
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const m = 10.0;
    final r = Rect.fromLTWH(m, m, s.width - 2 * m, s.height - 2 * m);
    canvas.drawRect(r, p);
    canvas.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), p);
    canvas.drawCircle(r.center, r.width * 0.13, p);
    canvas.drawCircle(r.center, 2.5, p..style = PaintingStyle.fill);
    p.style = PaintingStyle.stroke;
    for (final top in [true, false]) {
      final bw = r.width * 0.56, bh = r.height * 0.15;
      final sw = r.width * 0.26, sh = r.height * 0.055;
      final y = top ? r.top : r.bottom - bh;
      canvas.drawRect(Rect.fromLTWH(r.center.dx - bw / 2, y, bw, bh), p);
      final y2 = top ? r.top : r.bottom - sh;
      canvas.drawRect(Rect.fromLTWH(r.center.dx - sw / 2, y2, sw, sh), p);
      final arcC = Offset(r.center.dx, top ? r.top + bh : r.bottom - bh);
      canvas.drawArc(Rect.fromCircle(center: arcC, radius: r.width * 0.11), top ? 0.25 * math.pi : 1.25 * math.pi, 0.5 * math.pi, false, p);
    }
  }

  @override
  bool shouldRepaint(PitchPainter o) => o.grass1 != grass1 || o.lines != lines;
}

/// Shirt-number disc used on the pitch view.
class ShirtDot extends StatelessWidget {
  final Team? team;
  final Player? player;
  final bool suspended;
  final bool captain;
  final double size;
  const ShirtDot({super.key, required this.team, required this.player, this.suspended = false, this.captain = false, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final col = teamColor(team);
    final fg = col.computeLuminance() > 0.55 ? Colors.black : Colors.white;
    return SizedBox(
      width: 78,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: player == null ? Colors.black26 : col,
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(team?.color2 ?? 0xFFFFFFFF), width: 2.2),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: player == null
                    ? const Icon(Icons.add_rounded, color: Colors.white70, size: 18)
                    : Text('${player!.number ?? ''}', style: TLText.score(size * 0.48, fg)),
              ),
              if (captain)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 15,
                    height: 15,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Color(0xFFFFC23D), shape: BoxShape.circle),
                    child: Text('C', style: TLText.score(10, Colors.black)),
                  ),
                ),
              if (suspended)
                const Positioned(left: -4, top: -4, child: Icon(Icons.block_rounded, color: Color(0xFFFF4F5E), size: 16)),
            ],
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(5)),
            child: Text(
              player?.shortName ?? 'Empty',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: TLText.sans, fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
