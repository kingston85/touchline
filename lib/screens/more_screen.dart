import 'package:flutter/material.dart';

import '../core/formations.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/share.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  TextEditingController? _org;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tl;
    _org ??= TextEditingController(text: app.settings.organizer);
    Widget tile(IconData icon, String title, String sub, VoidCallback onTap, {Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TLCard(
            padding: EdgeInsets.zero,
            onTap: onTap,
            child: ListTile(
              leading: Icon(icon, color: color ?? c.accent),
              title: Text(title, style: TLText.body(c.ink, weight: FontWeight.w700)),
              subtitle: Text(sub, style: TLText.body(c.inkDim, size: 12.5)),
              trailing: Icon(Icons.chevron_right_rounded, color: c.inkDim),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const SectionHeader('Organiser'),
          TextField(
            controller: _org,
            onChanged: (v) => app.update(() => app.settings.organizer = v.trim()),
            decoration: const InputDecoration(labelText: 'Association / league / school name', helperText: 'Printed on PDF reports'),
          ),
          const SectionHeader('Display'),
          TLCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              value: app.settings.daylight,
              onChanged: (v) => app.update(() => app.settings.daylight = v),
              title: const Text('Daylight mode'),
              subtitle: const Text('High-contrast light theme for bright sun at the pitch'),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: app.settings.defaultFormation,
            decoration: const InputDecoration(labelText: 'Default formation for new line-ups'),
            items: [for (final f in formations) DropdownMenuItem(value: f, child: Text(f))],
            onChanged: (v) => app.update(() => app.settings.defaultFormation = v ?? '4-4-2'),
          ),
          const SectionHeader('Data'),
          tile(Icons.backup_outlined, 'Back up all data', 'One file with every team, player, competition and result', () => shareBackupFile(context, app.saveNow)),
          tile(Icons.settings_backup_restore_rounded, 'Restore from backup', 'Load a backup from another phone or PC (replaces current data)', () async {
            final data = await pickBackup(context);
            if (data == null || !context.mounted) return;
            final n = (data['competitions'] as List?)?.length ?? 0;
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Restore backup?'),
                content: Text('The backup has ${(data['teams'] as List).length} teams and $n competitions. Everything on this device will be replaced.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              app.restore(data);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored.')));
            }
          }),
          if (app.hasDemo)
            tile(Icons.cleaning_services_outlined, 'Remove demo data', 'Clear the demo league, cup and their 10 clubs', () {
              app.clearDemo();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo data removed.')));
            }, color: c.fair)
          else
            tile(Icons.science_outlined, 'Load demo data', 'Adds a sample league and cup to explore', () => app.update(app.loadDemo), color: c.inkDim),
          const SectionHeader('How it works'),
          TLCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final line in const [
                'Create teams (with squads) once, then use them in any number of competitions.',
                'New competition → pick a format; fixtures, groups and brackets are generated for you.',
                'Open a match to go live: run the clock and log goals, cards and substitutions as they happen.',
                'Tables, brackets, top scorers, suspensions and fair-play update automatically.',
                'Export standings, fixtures, statistics and match reports as PDF to share with clubs and media.',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 6, right: 10), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle))),
                    Expanded(child: Text(line, style: TLText.body(c.ink, size: 13))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Center(child: Text('Touchline 1.0 · works offline · data stays on this device', style: TLText.body(c.inkDim, size: 12))),
        ],
      ),
    );
  }
}
