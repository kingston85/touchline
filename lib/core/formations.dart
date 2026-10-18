import 'dart:ui' show Offset;

import '../data/models.dart';

const formations = ['4-4-2', '4-3-3', '4-2-3-1', '4-1-4-1', '4-5-1', '3-5-2', '3-4-3', '5-3-2', '5-4-1', '4-4-1-1'];

List<int> formationLines(String f) {
  final parts = f.split('-').map((p) => int.tryParse(p) ?? 0).where((n) => n > 0).toList();
  if (parts.fold<int>(0, (a, b) => a + b) != 10) return const [4, 4, 2];
  return parts;
}

/// Slot positions for a formation: x 0..1 across, y 0..1 from own goal to
/// opponent's goal. Slot 0 is the goalkeeper.
List<Offset> formationSlots(String f) {
  final lines = formationLines(f);
  final out = <Offset>[const Offset(0.5, 0.06)];
  for (var li = 0; li < lines.length; li++) {
    final y = lines.length == 1 ? 0.5 : 0.24 + li * (0.84 - 0.24) / (lines.length - 1);
    final n = lines[li];
    for (var k = 0; k < n; k++) {
      final x = n == 1 ? 0.5 : 0.12 + k * 0.76 / (n - 1);
      out.add(Offset(x, y));
    }
  }
  return out;
}

/// Role the slot plays (for auto-picking a lineup).
Position slotRole(String f, int slot) {
  if (slot == 0) return Position.gk;
  final lines = formationLines(f);
  var i = slot - 1;
  for (var li = 0; li < lines.length; li++) {
    if (i < lines[li]) {
      if (li == 0) return Position.df;
      if (li == lines.length - 1) return Position.fw;
      return Position.mf;
    }
    i -= lines[li];
  }
  return Position.mf;
}

/// Picks a sensible XI and bench from a squad for [formation], skipping
/// [unavailable] players. Returns (starters in slot order, bench).
(List<String>, List<String>) autoLineup(Team t, String formation, {Set<String> unavailable = const {}, int benchSize = 7}) {
  final pool = t.players.where((p) => !unavailable.contains(p.id)).toList()
    ..sort((a, b) => (a.number ?? 99).compareTo(b.number ?? 99));
  final used = <String>{};
  final starters = <String>[];
  for (var s = 0; s < 11; s++) {
    final role = slotRole(formation, s);
    Player? pick;
    for (final p in pool) {
      if (!used.contains(p.id) && p.position == role) {
        pick = p;
        break;
      }
    }
    if (pick == null && role != Position.gk) {
      for (final p in pool) {
        if (!used.contains(p.id) && p.position != Position.gk) {
          pick = p;
          break;
        }
      }
    }
    pick ??= pool.where((p) => !used.contains(p.id)).firstOrNull;
    if (pick == null) break;
    used.add(pick.id);
    starters.add(pick.id);
  }
  final bench = pool.where((p) => !used.contains(p.id)).take(benchSize).map((p) => p.id).toList();
  return (starters, bench);
}
