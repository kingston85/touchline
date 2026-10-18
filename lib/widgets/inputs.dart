import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Pill selector that scrolls sideways when it doesn't fit.
class Segmented<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  const Segmented({super.key, required this.values, required this.selected, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.tl;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(v);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == selected ? c.accent : c.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: v == selected ? c.accent : c.line),
                  ),
                  child: Text(
                    label(v),
                    style: TextStyle(
                      fontFamily: TLText.sans,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: v == selected ? c.onAccent : c.ink,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact integer stepper: label above, − value + below.
class Stepper2 extends StatelessWidget {
  final String label;
  final int value;
  final int min, max;
  final ValueChanged<int> onChanged;
  const Stepper2({super.key, required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.tl;
    Widget btn(IconData i, VoidCallback? f) => InkWell(
          onTap: f == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  f();
                },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(10)),
            child: Icon(i, size: 18, color: f == null ? c.line : c.ink),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TLText.body(c.inkDim, size: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(
            children: [
              btn(Icons.remove_rounded, value > min ? () => onChanged(value - 1) : null),
              Expanded(child: Text('$value', textAlign: TextAlign.center, style: TLText.score(22, c.ink))),
              btn(Icons.add_rounded, value < max ? () => onChanged(value + 1) : null),
            ],
          ),
        ],
      ),
    );
  }
}

/// Big +/− score setter used for quick result entry.
class ScoreStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  const ScoreStepper({super.key, required this.value, required this.onChanged, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final c = context.tl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(onPressed: () => onChanged(value + 1), icon: const Icon(Icons.keyboard_arrow_up_rounded)),
        Text('$value', style: TLText.score(size, c.ink)),
        IconButton.filledTonal(onPressed: value > 0 ? () => onChanged(value - 1) : null, icon: const Icon(Icons.keyboard_arrow_down_rounded)),
      ],
    );
  }
}
