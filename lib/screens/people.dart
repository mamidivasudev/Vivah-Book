import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets.dart';

/// Look up a person across all functions: what they gave you and what you gave them.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final q = _query.trim().toLowerCase();
    final all = store.people;
    final list = all
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.places.any((pl) => pl.toLowerCase().contains(q)))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: SafeArea(
        child: all.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Text(
                    'Everyone you add to a function appears here. Search a name to see '
                    'what they gave you and what you gave them, so you know what to give back.',
                    textAlign: TextAlign.center,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search a name or place',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No one found')),
                    ),
                  for (final p in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => PersonScreen(personKey: p.key)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              foregroundColor: cs.onPrimaryContainer,
                              child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase()),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                  if (p.places.isNotEmpty)
                                    Text(p.places.join(', '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Gave you ${inr(p.receivedTotal)} · You gave ${inr(p.givenTotal)}',
                                    style: tt.bodySmall?.copyWith(color: cs.primary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
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

class PersonScreen extends StatelessWidget {
  const PersonScreen({super.key, required this.personKey});

  final String personKey;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final p = store.people.where((x) => x.key == personKey).firstOrNull;
    if (p == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Not found')));
    }
    final last = p.lastReceived;
    final diff = p.receivedTotal - p.givenTotal;

    Widget history(String title, List<(Gift, GiftEvent)> items) {
      final sorted = List.of(items)..sort((a, b) => b.$2.date.compareTo(a.$2.date));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          if (sorted.isEmpty)
            SoftCard(child: Text('Nothing recorded', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
          for (final e in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.$2.name, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            [fmtDate(e.$2.date), if (e.$1.note.isNotEmpty) e.$1.note].join(' · '),
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(e.$1.amount > 0 ? inr(e.$1.amount) : 'Gift',
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: cs.primary)),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            SoftCard(
              color: cs.primaryContainer,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Gave you', style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
                            Text(inr(p.receivedTotal),
                                style: tt.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800, color: cs.onPrimaryContainer)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('You gave', style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
                            Text(inr(p.givenTotal),
                                style: tt.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800, color: cs.onPrimaryContainer)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    last == null
                        ? 'They have not given you anything yet.'
                        : 'Last gift to you: ${inr(last.$1.amount)} at ${last.$2.name}. '
                            'When you give at their function, ${inr(last.$1.amount)} or a little more is the usual way to return it.',
                    style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
                  ),
                  if (diff != 0 && p.received.isNotEmpty && p.given.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      diff > 0
                          ? 'They have given you ${inr(diff)} more than you gave them.'
                          : 'You have given ${inr(-diff)} more than they gave you.',
                      style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer),
                    ),
                  ],
                ],
              ),
            ),
            history('What they gave you', p.received),
            history('What you gave them', p.given),
          ],
        ),
      ),
    );
  }
}
