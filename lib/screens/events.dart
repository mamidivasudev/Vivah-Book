import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets.dart';
import 'event_detail.dart';

/// Opens the function form. Returns the saved event, or null if cancelled.
Future<GiftEvent?> showEventForm(BuildContext context, {required int newId, GiftEvent? existing}) {
  return showModalBottomSheet<GiftEvent>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EventForm(newId: newId, existing: existing),
  );
}

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  Future<void> _new(BuildContext context) async {
    final store = context.store;
    final nav = Navigator.of(context);
    final e = await showEventForm(context, newId: store.newId());
    if (e == null) return;
    await store.saveEvent(e);
    nav.push(MaterialPageRoute<void>(builder: (_) => EventDetailScreen(eventId: e.id)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final events = store.events;

    return Scaffold(
      appBar: AppBar(title: const Text('VivahBook')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _new(context),
        icon: const Icon(Icons.add),
        label: const Text('New function'),
      ),
      body: SafeArea(
        child: events.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(28),
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.card_giftcard, size: 76, color: cs.primary),
                  const SizedBox(height: 20),
                  Text('Your function gift book',
                      textAlign: TextAlign.center,
                      style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(
                    'Write down who gave what at your wedding or function, and who you '
                    'gave to. Later, look up a name to see what to give back.',
                    textAlign: TextAlign.center,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  SoftCard(
                    child: Text(
                      'Private and offline. Everything stays on this phone and nothing is uploaded.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                children: [
                  for (final e in events)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SoftCard(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => EventDetailScreen(eventId: e.id)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: e.mine ? cs.primaryContainer : cs.tertiaryContainer,
                              foregroundColor: e.mine ? cs.onPrimaryContainer : cs.onTertiaryContainer,
                              child: Icon(e.mine ? Icons.south_west : Icons.north_east),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  Text('${e.type} · ${fmtDate(e.date)}',
                                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${e.mine ? 'Received' : 'Given'} ${inr(store.totalFor(e.id))}'
                                    ' · ${store.countFor(e.id)} ${store.countFor(e.id) == 1 ? 'entry' : 'entries'}',
                                    style: tt.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600, color: cs.primary),
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

class _EventForm extends StatefulWidget {
  const _EventForm({required this.newId, this.existing});

  final int newId;
  final GiftEvent? existing;

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  late final TextEditingController _name;
  late String _type;
  late bool _mine;
  late DateTime _date;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _type = e?.type ?? eventTypes.first;
    _mine = e?.mine ?? true;
    _date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name for the function, for example Priya wedding.');
      return;
    }
    Navigator.of(context).pop(GiftEvent(
      id: widget.existing?.id ?? widget.newId,
      name: name,
      type: _type,
      mine: _mine,
      date: DateTime(_date.year, _date.month, _date.day),
      notes: widget.existing?.notes ?? '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, sheetBottomPadding(context) + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'New function' : 'Edit function',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('My function'), icon: Icon(Icons.south_west)),
                ButtonSegment(value: false, label: Text("Someone's"), icon: Icon(Icons.north_east)),
              ],
              selected: {_mine},
              onSelectionChanged: (s) => setState(() => _mine = s.first),
            ),
            const SizedBox(height: 6),
            Text(
              _mine
                  ? 'Guests give gifts to you. You record what you receive.'
                  : 'You attended and gave a gift. You record what you gave.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Function name',
                hintText: _mine ? "e.g. Our wedding" : "e.g. Suresh's housewarming",
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              items: [for (final t in eventTypes) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(fmtDate(_date)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
