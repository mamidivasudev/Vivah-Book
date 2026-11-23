import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets.dart';
import 'events.dart';
import 'gift_form.dart';

enum _Sort { latest, name, amount }

/// One function's register: summary, search, entries, add and export.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final int eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  String _query = '';
  _Sort _sort = _Sort.latest;

  Future<void> _delete(GiftEvent e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${e.name}"?'),
        content: const Text('All entries in this function will be deleted too. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nav = Navigator.of(context);
    await context.store.deleteEvent(e.id);
    nav.pop();
  }

  Future<void> _edit(GiftEvent e) async {
    final store = context.store;
    final updated = await showEventForm(context, newId: e.id, existing: e);
    if (updated != null) await store.saveEvent(updated);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final event = store.eventById(widget.eventId);
    if (event == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Function not found')));
    }
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final all = store.giftsFor(event.id);
    final total = store.totalFor(event.id);
    final q = _query.trim().toLowerCase();
    final shown = all
        .where((g) =>
            q.isEmpty ||
            g.name.toLowerCase().contains(q) ||
            g.place.toLowerCase().contains(q) ||
            g.note.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => switch (_sort) {
            _Sort.latest => b.at.compareTo(a.at),
            _Sort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            _Sort.amount => b.amount.compareTo(a.amount),
          });
    final cashCount = all.where((g) => g.amount > 0).length;
    final average = cashCount == 0 ? 0 : (total / cashCount).round();

    return Scaffold(
      appBar: AppBar(
        title: Text(event.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'text':
                  copyText(context, store.registerText(event), what: 'Register copied. Paste it anywhere.');
                case 'csv':
                  copyText(context, store.registerCsv(event), what: 'CSV copied. Paste it into a sheet.');
                case 'edit':
                  _edit(event);
                case 'delete':
                  _delete(event);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'text', child: Text('Copy register as text')),
              PopupMenuItem(value: 'csv', child: Text('Copy as CSV (for Excel)')),
              PopupMenuItem(value: 'edit', child: Text('Edit function')),
              PopupMenuItem(value: 'delete', child: Text('Delete function')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showGiftForm(context, event: event),
        icon: const Icon(Icons.add),
        label: Text(event.mine ? 'Add gift received' : 'Add gift given'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            SoftCard(
              color: cs.primaryContainer,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(event.mine ? 'Total received' : 'Total given',
                      style: tt.titleSmall?.copyWith(color: cs.onPrimaryContainer)),
                  const SizedBox(height: 4),
                  Text(inr(total),
                      style: tt.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800, color: cs.onPrimaryContainer)),
                  const SizedBox(height: 6),
                  Text(
                    '${all.length} ${all.length == 1 ? 'entry' : 'entries'}'
                    '${cashCount > 0 ? ' · average ${inr(average)}' : ''}',
                    style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
                  ),
                  Text('${event.type} · ${fmtDate(event.date)}',
                      style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search name, place or note',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<_Sort>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort),
                  initialValue: _sort,
                  onSelected: (s) => setState(() => _sort = s),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _Sort.latest, child: Text('Latest first')),
                    PopupMenuItem(value: _Sort.name, child: Text('Name A to Z')),
                    PopupMenuItem(value: _Sort.amount, child: Text('Highest amount')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  event.mine
                      ? 'No entries yet. Tap "Add gift received" when a guest gives you something.'
                      : 'No entries yet. Tap "Add gift given" to record what you gave.',
                  textAlign: TextAlign.center,
                  style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              )
            else if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No matching entries')),
              ),
            for (final g in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: () => showGiftForm(context, event: event, existing: g),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cs.secondaryContainer,
                        foregroundColor: cs.onSecondaryContainer,
                        child: Text(g.name.isEmpty ? '?' : g.name[0].toUpperCase()),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.name, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              [
                                if (g.place.isNotEmpty) g.place,
                                if (g.relation.isNotEmpty) g.relation,
                                if (g.note.isNotEmpty) g.note,
                              ].join(' · '),
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Text(g.amount > 0 ? inr(g.amount) : 'Gift',
                          style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800, color: cs.primary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
