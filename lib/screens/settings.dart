import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../legal.dart';
import '../widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _restore(BuildContext context) async {
    final store = context.store;
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste the backup text you copied earlier. This REPLACES everything in the app.'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste here'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.paste),
                label: const Text('Paste from clipboard'),
                onPressed: () async {
                  final d = await Clipboard.getData(Clipboard.kTextPlain);
                  controller.text = d?.text ?? '';
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Restore')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    final err = await store.restoreJson(text);
    messenger.showSnackBar(SnackBar(content: Text(err ?? 'Backup restored.')));
  }

  Future<void> _deleteAll(BuildContext context) async {
    final store = context.store;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all my data?'),
        content: const Text(
            'All functions and entries will be removed from this phone. This cannot be undone. Make a backup first if you may need it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await store.deleteAll();
    messenger.showSnackBar(const SnackBar(content: Text('All data deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final scale = store.textScale;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const SectionTitle('Text size'),
            SoftCard(
              child: SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 1.0, label: Text('Normal')),
                  ButtonSegment(value: 1.15, label: Text('Large')),
                  ButtonSegment(value: 1.3, label: Text('Extra large')),
                ],
                selected: {scale},
                onSelectionChanged: (s) => store.setTextScale(s.first),
              ),
            ),
            const SectionTitle('Backup'),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.copy_all),
                    title: const Text('Copy backup'),
                    subtitle: const Text('Paste it into Notes or WhatsApp to keep it safe'),
                    onTap: () => copyText(context, store.backupJson(),
                        what: 'Backup copied. Paste it somewhere safe.'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore),
                    title: const Text('Restore from backup'),
                    onTap: () => _restore(context),
                  ),
                ],
              ),
            ),
            const SectionTitle('Privacy & data'),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: cs.error),
                    title: Text('Delete all my data', style: TextStyle(color: cs.error)),
                    onTap: () => _deleteAll(context),
                  ),
                ],
              ),
            ),
            const SectionTitle('About'),
            SoftCard(child: Text(disclaimerText, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
            const SizedBox(height: 12),
            Center(child: Text('VivahBook · version 1.0.0', style: tt.bodySmall?.copyWith(color: cs.outline))),
          ],
        ),
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(privacyPolicyText, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }
}
