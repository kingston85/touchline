import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/app_state.dart';
import '../data/models.dart';
import 'standings.dart';

const _ink = PdfColor.fromInt(0xFF0B130E);
const _dim = PdfColor.fromInt(0xFF5B6B61);
const _line = PdfColor.fromInt(0xFFD3DDD6);
const _panel = PdfColor.fromInt(0xFFF1F5F2);
const _accent = PdfColor.fromInt(0xFF0E8A45);
const _gold = PdfColor.fromInt(0xFFC98B00);

class _Fonts {
  final pw.Font regular, bold, display;
  _Fonts(this.regular, this.bold, this.display);
  static Future<_Fonts> load() async => _Fonts(
        pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf')),
        pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf')),
        pw.Font.ttf(await rootBundle.load('assets/fonts/BarlowCondensed-Bold.ttf')),
      );
}

String _label(Competition c, Fixture f) {
  switch (f.stage) {
    case Stage.league:
      return 'Matchday ${f.round}';
    case Stage.group:
      return 'Group ${f.group}, MD ${f.round}';
    case Stage.knockout:
      final maxRound = c.knockoutMatches.map((m) => m.round).fold(0, (a, b) => a > b ? a : b);
      final teams = 2 << (maxRound - f.round);
      if (f.round == maxRound && f.slot == 1) return 'Third place';
      final n = switch (teams) { 2 => 'Final', 4 => 'Semi-final', 8 => 'Quarter-final', _ => 'Round of $teams' };
      return f.leg > 0 ? '$n, leg ${f.leg}' : n;
  }
}

class Reports {
  Reports._();

  static pw.Widget _header(_Fonts ft, String org, String title, String sub, PdfColor col) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: col, width: 2.5))),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (org.isNotEmpty) pw.Text(org.toUpperCase(), style: pw.TextStyle(font: ft.bold, fontSize: 8, letterSpacing: 1.2, color: _dim)),
              pw.Text(title, style: pw.TextStyle(font: ft.display, fontSize: 22, color: _ink)),
              pw.Text(sub, style: const pw.TextStyle(fontSize: 9, color: _dim)),
            ]),
          ),
          pw.Text('TOUCHLINE', style: pw.TextStyle(font: ft.display, fontSize: 12, color: col, letterSpacing: 1)),
        ]),
      );

  static pw.Widget _footer(pw.Context ctx) => pw.Row(children: [
        pw.Expanded(child: pw.Text('Generated ${shortDate(DateTime.now())} with Touchline', style: const pw.TextStyle(fontSize: 7, color: _dim))),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: _dim)),
      ]);

  static pw.Widget _section(_Fonts ft, String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 5),
        child: pw.Text(t.toUpperCase(), style: pw.TextStyle(font: ft.display, fontSize: 13, color: _accent, letterSpacing: 0.6)),
      );

  static pw.Widget _table(_Fonts ft, List<String> headers, List<List<String>> rows,
      {Map<int, pw.TableColumnWidth>? widths, PdfColor? Function(int row)? rowColor, Set<int> center = const {}}) {
    return pw.Table(
      columnWidths: widths,
      border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.4), bottom: pw.BorderSide(color: _line, width: 0.4)),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(decoration: const pw.BoxDecoration(color: _panel), children: [
          for (var i = 0; i < headers.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(headers[i], textAlign: center.contains(i) ? pw.TextAlign.center : pw.TextAlign.left, style: pw.TextStyle(font: ft.bold, fontSize: 8, color: _ink)),
            ),
        ]),
        for (var r = 0; r < rows.length; r++)
          pw.TableRow(children: [
            for (var i = 0; i < rows[r].length; i++)
              pw.Container(
                color: i == 0 ? rowColor?.call(r) : null,
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                child: pw.Text(rows[r][i], textAlign: center.contains(i) ? pw.TextAlign.center : pw.TextAlign.left, style: const pw.TextStyle(fontSize: 8.5, color: _ink)),
              ),
          ]),
      ],
    );
  }

  static List<pw.Widget> _standings(AppState app, Competition c, _Fonts ft) {
    final out = <pw.Widget>[];
    List<String> heads = ['#', 'Team', 'P', 'W', 'D', 'L', 'GF', 'GA', 'GD', 'Pts', 'Form'];
    pw.Widget tbl(List<Standing> rows, List<Zone> zones) {
      PdfColor? zc(int pos) {
        for (final z in zones) {
          if (pos >= z.from && pos <= z.to) return PdfColor.fromInt((z.color & 0x00FFFFFF) | 0x55000000);
        }
        return null;
      }

      return _table(
        ft,
        heads,
        [
          for (var i = 0; i < rows.length; i++)
            [
              '${i + 1}',
              app.teamName(rows[i].teamId),
              '${rows[i].played}',
              '${rows[i].won}',
              '${rows[i].drawn}',
              '${rows[i].lost}',
              '${rows[i].gf}',
              '${rows[i].ga}',
              rows[i].gd > 0 ? '+${rows[i].gd}' : '${rows[i].gd}',
              '${rows[i].points}${rows[i].adjust != 0 ? '*' : ''}',
              rows[i].last5.join(' '),
            ]
        ],
        widths: {0: const pw.FixedColumnWidth(20), 1: const pw.FlexColumnWidth(4), 10: const pw.FixedColumnWidth(58)},
        rowColor: (r) => zc(r + 1),
        center: {0, 2, 3, 4, 5, 6, 7, 8, 9, 10},
      );
    }

    if (c.format == Format.league) {
      out.add(_section(ft, 'Standings'));
      out.add(tbl(app.table(c), c.zones));
      if (c.zones.isNotEmpty) {
        out.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(c.zones.map((z) => '${z.label}: ${z.from == z.to ? z.from : '${z.from}–${z.to}'}').join('   ·   '), style: const pw.TextStyle(fontSize: 7.5, color: _dim)),
        ));
      }
    } else if (c.format == Format.groupsKnockout) {
      for (final g in c.groups.keys) {
        out.add(_section(ft, 'Group $g'));
        out.add(tbl(app.table(c, group: g), [Zone(label: 'Qualify', from: 1, to: c.rules.advance, color: 0xFF3BE37F)]));
      }
    }
    if (c.adjustments.isNotEmpty) {
      out.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Text('* ${c.adjustments.map((a) => '${app.teamName(a.teamId)} ${a.points > 0 ? '+' : ''}${a.points} pts${a.reason.isEmpty ? '' : ' (${a.reason})'}').join('; ')}',
            style: const pw.TextStyle(fontSize: 7.5, color: _dim)),
      ));
    }
    if (c.format != Format.knockout) {
      out.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 3),
        child: pw.Text('Points: win ${c.rules.win}, draw ${c.rules.draw}, loss ${c.rules.loss}. Tiebreakers: ${c.rules.tiebreaks.map((t) => t.label.toLowerCase()).join(', ')}.',
            style: const pw.TextStyle(fontSize: 7.5, color: _dim)),
      ));
    }
    if (c.format != Format.league) {
      out.add(_section(ft, 'Knockout'));
      final ko = c.knockoutMatches.toList()
        ..sort((a, b) {
          final r = a.round.compareTo(b.round);
          return r != 0 ? r : a.slot.compareTo(b.slot);
        });
      out.add(_table(
        ft,
        ['Round', 'Home', 'Score', 'Away', 'Outcome'],
        [
          for (final f in ko)
            [
              _label(c, f),
              app.teamName(f.homeId, f.homeLabel.isEmpty ? 'TBD' : f.homeLabel),
              f.played ? '${f.homeGoals}–${f.awayGoals}${f.hasPens ? ' (${f.homePens}–${f.awayPens}p)' : ''}' : (f.kickoff == null ? '' : shortDate(f.kickoff!)),
              app.teamName(f.awayId, f.awayLabel.isEmpty ? 'TBD' : f.awayLabel),
              () {
                if (f.leg == 1) return '';
                final r = resolveTie(c, f);
                return r.winner == null ? '' : '${app.teamName(r.winner)}${r.summary.isEmpty ? '' : ' (${r.summary})'}';
              }(),
            ]
        ],
        widths: {0: const pw.FixedColumnWidth(80), 2: const pw.FixedColumnWidth(70)},
        center: {2},
      ));
    }
    return out;
  }

  static List<pw.Widget> _fixtures(AppState app, Competition c, _Fonts ft) {
    final out = <pw.Widget>[];
    final list = [...c.matches]..sort((a, b) {
        final s = a.stage.index.compareTo(b.stage.index);
        if (s != 0) return s;
        final r = a.round.compareTo(b.round);
        if (r != 0) return r;
        final l = a.leg.compareTo(b.leg);
        if (l != 0) return l;
        return (a.kickoff ?? DateTime(2100)).compareTo(b.kickoff ?? DateTime(2100));
      });
    String key(Fixture f) => f.stage == Stage.group ? 'Group stage, matchday ${f.round}' : _label(c, f).replaceAll(RegExp(r', leg \d'), '') + (f.leg > 0 ? ', leg ${f.leg}' : '');
    String? last;
    final rows = <List<String>>[];
    void flush() {
      if (last == null || rows.isEmpty) return;
      out.add(_section(ft, last!));
      out.add(_table(ft, ['Date', 'Home', 'Score', 'Away', 'Venue'], [...rows],
          widths: {0: const pw.FixedColumnWidth(70), 1: const pw.FlexColumnWidth(3), 2: const pw.FixedColumnWidth(54), 3: const pw.FlexColumnWidth(3), 4: const pw.FlexColumnWidth(2.4)},
          center: {2}));
      rows.clear();
    }

    for (final f in list) {
      final k = key(f);
      if (k != last) {
        flush();
        last = k;
      }
      rows.add([
        f.kickoff == null ? 'TBC' : '${dayDate(f.kickoff!)} ${hhmm(f.kickoff!)}',
        app.teamName(f.homeId, f.homeLabel.isEmpty ? 'TBD' : f.homeLabel),
        f.played ? '${f.homeGoals}–${f.awayGoals}${f.hasPens ? ' p' : ''}' : (f.status == MatchStatus.scheduled ? 'v' : f.status.label),
        app.teamName(f.awayId, f.awayLabel.isEmpty ? 'TBD' : f.awayLabel),
        f.venue,
      ]);
    }
    flush();
    return out;
  }

  static List<pw.Widget> _stats(AppState app, Competition c, _Fonts ft) {
    final out = <pw.Widget>[];
    final all = playerStats(c, app.team).values.toList();
    void board(String title, int Function(PlayerStats) v, {int top = 15}) {
      final l = all.where((s) => v(s) > 0).toList()..sort((a, b) => v(b).compareTo(v(a)));
      if (l.isEmpty) return;
      out.add(_section(ft, title));
      out.add(_table(
        ft,
        ['#', 'Player', 'Team', 'Apps', title.split(' ').first],
        [for (var i = 0; i < l.length && i < top; i++) ['${i + 1}', app.playerName(l[i].playerId), app.teamName(l[i].teamId), '${l[i].apps}', '${v(l[i])}']],
        widths: {0: const pw.FixedColumnWidth(20), 3: const pw.FixedColumnWidth(36), 4: const pw.FixedColumnWidth(46)},
        center: {0, 3, 4},
      ));
    }

    board('Goals (top scorers)', (s) => s.goals);
    board('Assists', (s) => s.assists);
    board('Clean sheets', (s) => s.cleanSheets, top: 10);
    board('Player of the match awards', (s) => s.motm, top: 10);
    if (out.isEmpty) out.add(pw.Text('No player statistics recorded yet.', style: const pw.TextStyle(fontSize: 9, color: _dim)));
    return out;
  }

  static List<pw.Widget> _discipline(AppState app, Competition c, _Fonts ft) {
    final out = <pw.Widget>[];
    final d = discipline(c);
    final all = playerStats(c, app.team).values.where((s) => s.yellows + s.reds > 0).toList()
      ..sort((a, b) => (b.reds * 3 + b.yellows).compareTo(a.reds * 3 + a.yellows));
    out.add(_section(ft, 'Discipline'));
    if (all.isEmpty) {
      out.add(pw.Text('No cards recorded.', style: const pw.TextStyle(fontSize: 9, color: _dim)));
    } else {
      out.add(_table(
        ft,
        ['Player', 'Team', 'Yellow', 'Red', 'Status'],
        [
          for (final s in all.take(30))
            [
              app.playerName(s.playerId),
              app.teamName(s.teamId),
              '${s.yellows}',
              '${s.reds}',
              d.active[s.playerId] == null ? '' : 'Suspended ${d.active[s.playerId]!.remaining}',
            ]
        ],
        center: {2, 3},
      ));
    }
    if (d.violations.isNotEmpty) {
      out.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Text(
          'Ineligible players fielded: ${d.violations.map((v) => '${app.playerName(v.playerId)} (${app.teamName(v.teamId)})').join('; ')}',
          style: pw.TextStyle(font: ft.bold, fontSize: 8.5, color: PdfColors.red800),
        ),
      ));
    }
    return out;
  }

  /// Competition PDF. [kind]: standings | fixtures | stats | full.
  static Future<Uint8List> competition(AppState app, Competition c, String kind) async {
    final ft = await _Fonts.load();
    final doc = pw.Document(title: c.name, author: c.organizer, creator: 'Touchline');
    final col = PdfColor.fromInt(c.color == 0xFFFFFFFF ? 0xFF0E8A45 : c.color);
    final champ = championOf(c, () => app.table(c));
    final title = switch (kind) { 'standings' => 'Standings', 'fixtures' => 'Fixtures & results', 'stats' => 'Player statistics', _ => 'Competition report' };
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 26),
      theme: pw.ThemeData.withFont(base: ft.regular, bold: ft.bold),
      header: (ctx) => _header(ft, c.organizer.isNotEmpty ? c.organizer : app.settings.organizer, '${c.name} ${c.season}', '$title · ${c.format.label} · ${c.teamIds.length} teams', col),
      footer: _footer,
      build: (ctx) => [
        if (champ != null && (kind == 'standings' || kind == 'full'))
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _gold, width: 1.2), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Text('CHAMPIONS: ${app.teamName(champ).toUpperCase()}', style: pw.TextStyle(font: ft.display, fontSize: 16, color: _gold)),
          ),
        if (kind == 'standings' || kind == 'full') ..._standings(app, c, ft),
        if (kind == 'stats' || kind == 'full') ..._stats(app, c, ft),
        if (kind == 'full') ..._discipline(app, c, ft),
        if (kind == 'fixtures' || kind == 'full') ..._fixtures(app, c, ft),
      ],
    ));
    return doc.save();
  }

  /// Official-style match report: score, scorers, line-ups, events, officials.
  static Future<Uint8List> matchReport(AppState app, Competition c, Fixture f) async {
    final ft = await _Fonts.load();
    final doc = pw.Document(title: 'Match report', creator: 'Touchline');
    final home = app.team(f.homeId), away = app.team(f.awayId);
    final col = PdfColor.fromInt(c.color == 0xFFFFFFFF ? 0xFF0E8A45 : c.color);

    pw.Widget lineup(Team? t, Lineup lu, bool side) {
      final subs = f.events.where((e) => e.home == side && e.type == EventType.sub).toList();
      String line(String id) {
        final p = t?.player(id);
        final tags = <String>[];
        for (final e in f.sortedEvents.where((e) => e.playerId == id || (e.type == EventType.sub && e.otherId == id))) {
          switch (e.type) {
            case EventType.goal:
            case EventType.penaltyGoal:
              tags.add('goal ${e.clock}${e.type == EventType.penaltyGoal ? ' pen' : ''}');
              break;
            case EventType.ownGoal:
              tags.add('og ${e.clock}');
              break;
            case EventType.yellow:
              tags.add('YC ${e.clock}');
              break;
            case EventType.secondYellow:
              tags.add('2YC ${e.clock}');
              break;
            case EventType.red:
              tags.add('RC ${e.clock}');
              break;
            case EventType.sub:
              tags.add(e.otherId == id ? 'off ${e.clock}' : 'on ${e.clock}');
              break;
            case EventType.penaltyMiss:
              tags.add('pen missed ${e.clock}');
              break;
          }
        }
        return '${p?.number ?? ''}  ${p?.name ?? '?'}${lu.captainId == id ? ' (C)' : ''}${tags.isEmpty ? '' : '   [${tags.join(', ')}]'}';
      }

      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('${t?.name ?? ''}${lu.isEmpty ? '' : '  (${lu.formation})'}', style: pw.TextStyle(font: ft.bold, fontSize: 10)),
        pw.SizedBox(height: 4),
        if (lu.isEmpty) pw.Text('Line-up not recorded', style: const pw.TextStyle(fontSize: 8.5, color: _dim)),
        for (final id in lu.starters) pw.Text(line(id), style: const pw.TextStyle(fontSize: 8.5)),
        if (lu.bench.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text('Substitutes', style: pw.TextStyle(font: ft.bold, fontSize: 8.5, color: _dim)),
          for (final id in lu.bench) pw.Text(line(id), style: pw.TextStyle(fontSize: 8.5, color: subs.any((s) => s.playerId == id) ? _ink : _dim)),
        ],
        if ((t?.coach ?? '').isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text('Coach: ${t!.coach}', style: const pw.TextStyle(fontSize: 8.5, color: _dim))),
      ]);
    }

    final tie = f.stage == Stage.knockout && f.played && f.leg != 1 ? resolveTie(c, f) : null;
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(34, 28, 34, 26),
      theme: pw.ThemeData.withFont(base: ft.regular, bold: ft.bold),
      header: (ctx) => _header(ft, c.organizer.isNotEmpty ? c.organizer : app.settings.organizer, 'Match report', '${c.name} ${c.season} · ${_label(c, f)}', col),
      footer: _footer,
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 14),
          decoration: const pw.BoxDecoration(color: _panel, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Column(children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
              pw.Expanded(child: pw.Text(home?.name ?? 'TBD', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: ft.display, fontSize: 20))),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 18),
                child: pw.Text(f.played || f.status == MatchStatus.live ? '${f.homeGoals} – ${f.awayGoals}' : 'v', style: pw.TextStyle(font: ft.display, fontSize: 34)),
              ),
              pw.Expanded(child: pw.Text(away?.name ?? 'TBD', style: pw.TextStyle(font: ft.display, fontSize: 20))),
            ]),
            if (f.hasPens) pw.Text('${f.homePens} – ${f.awayPens} on penalties', style: const pw.TextStyle(fontSize: 9, color: _dim)),
            if (f.extraTime && !f.hasPens) pw.Text('after extra time', style: const pw.TextStyle(fontSize: 9, color: _dim)),
            if (f.forfeit) pw.Text('Result awarded (forfeit)', style: const pw.TextStyle(fontSize: 9, color: _dim)),
            if (tie != null && tie.winner != null && f.leg == 2) pw.Text('${app.teamName(tie.winner)} go through (${tie.summary})', style: const pw.TextStyle(fontSize: 9, color: _dim)),
            pw.SizedBox(height: 6),
            pw.Text(
              [
                if (f.kickoff != null) '${shortDate(f.kickoff!)} ${hhmm(f.kickoff!)}',
                if (f.venue.isNotEmpty) f.venue,
                if (f.attendance != null) 'Attendance ${f.attendance}',
              ].join('  ·  '),
              style: const pw.TextStyle(fontSize: 9, color: _dim),
            ),
          ]),
        ),
        _section(ft, 'Match events'),
        if (f.events.isEmpty)
          pw.Text('No events recorded.', style: const pw.TextStyle(fontSize: 9, color: _dim))
        else
          _table(
            ft,
            ['Min', app.team(f.homeId)?.short ?? 'Home', 'Event', app.team(f.awayId)?.short ?? 'Away'],
            [
              for (final e in f.sortedEvents)
                () {
                  final who = e.type == EventType.sub
                      ? '${app.playerName(e.playerId)} for ${app.playerName(e.otherId)}'
                      : '${app.playerName(e.playerId)}${e.type == EventType.goal && e.otherId != null ? ' (assist ${app.playerName(e.otherId)})' : ''}';
                  return [e.clock, e.home ? who : '', e.type.label, e.home ? '' : who];
                }(),
            ],
            widths: {0: const pw.FixedColumnWidth(34), 2: const pw.FixedColumnWidth(80)},
            center: {0, 2},
          ),
        _section(ft, 'Line-ups'),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: lineup(home, f.homeLineup, true)),
          pw.SizedBox(width: 16),
          pw.Expanded(child: lineup(away, f.awayLineup, false)),
        ]),
        _section(ft, 'Officials & notes'),
        pw.Text('Referee: ${f.referee.isEmpty ? '—' : f.referee}', style: const pw.TextStyle(fontSize: 9)),
        if (f.assistants.isNotEmpty) pw.Text('Assistants / 4th official: ${f.assistants}', style: const pw.TextStyle(fontSize: 9)),
        if (f.motmId != null) pw.Text('Player of the match: ${app.playerName(f.motmId)}', style: const pw.TextStyle(fontSize: 9)),
        if (f.notes.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text(f.notes, style: const pw.TextStyle(fontSize: 9))),
        pw.SizedBox(height: 34),
        pw.Row(children: [
          for (final s in ['Referee', 'Home team official', 'Away team official', 'Match commissioner'])
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(right: 14),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Container(height: 0.8, color: _ink),
                  pw.SizedBox(height: 3),
                  pw.Text(s, style: const pw.TextStyle(fontSize: 7.5, color: _dim)),
                ]),
              ),
            ),
        ]),
      ],
    ));
    return doc.save();
  }

  static String _csv(String s) => (s.contains(',') || s.contains('"') || s.contains('\n')) ? '"${s.replaceAll('"', '""')}"' : s;

  static String resultsCsv(AppState app, Competition c) {
    final b = StringBuffer('stage,round,group,date,time,home,home_goals,away_goals,away,pens_home,pens_away,extra_time,status,venue,referee,attendance\n');
    for (final f in c.matches) {
      b.writeln([
        _csv(_label(c, f)),
        f.round,
        f.group ?? '',
        f.kickoff == null ? '' : '${f.kickoff!.year}-${f.kickoff!.month.toString().padLeft(2, '0')}-${f.kickoff!.day.toString().padLeft(2, '0')}',
        f.kickoff == null ? '' : hhmm(f.kickoff!),
        _csv(app.teamName(f.homeId, f.homeLabel)),
        f.played ? f.homeGoals : '',
        f.played ? f.awayGoals : '',
        _csv(app.teamName(f.awayId, f.awayLabel)),
        f.homePens ?? '',
        f.awayPens ?? '',
        f.extraTime ? 'yes' : 'no',
        f.status.label,
        _csv(f.venue),
        _csv(f.referee),
        f.attendance ?? '',
      ].join(','));
    }
    return b.toString();
  }
}
