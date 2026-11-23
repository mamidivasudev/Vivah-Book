import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets.dart';

Future<void> showGiftForm(BuildContext context, {required GiftEvent event, Gift? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => GiftForm(event: event, existing: existing),
  );
}

/// Fast entry sheet used at the function: name, place, relation, amount, note.
class GiftForm extends StatefulWidget {
  const GiftForm({super.key, required this.event, this.existing});

  final GiftEvent event;
  final Gift? existing;

  @override
  State<GiftForm> createState() => _GiftFormState();
}

class _GiftFormState extends State<GiftForm> {
  late final TextEditingController _name;
  late final TextEditingController _place;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  final _nameFocus = FocusNode();
  String _relation = '';
  String? _error;
  int _savedCount = 0;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _name = TextEditingController(text: g?.name ?? '');
    _place = TextEditingController(text: g?.place ?? '');
    _amount = TextEditingController(text: g == null || g.amount == 0 ? '' : '${g.amount}');
    _note = TextEditingController(text: g?.note ?? '');
    _relation = g?.relation ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    _amount.dispose();
    _note.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool another}) async {
    final name = _name.text.trim();
    final amount = int.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
    final note = _note.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter the name of the person.');
      return;
    }
    if (amount <= 0 && note.isEmpty) {
      setState(() => _error = 'Enter an amount, or write the gift in the note.');
      return;
    }
    final store = context.store;
    await store.saveGift(Gift(
      id: widget.existing?.id ?? store.newId(),
      eventId: widget.event.id,
      name: name,
      place: _place.text.trim(),
      relation: _relation,
      amount: amount,
      note: note,
      at: widget.existing?.at ?? DateTime.now(),
    ));
    if (!mounted) return;
    if (another && widget.existing == null) {
      setState(() {
        _name.clear();
        _place.clear();
        _amount.clear();
        _note.clear();
        _relation = '';
        _error = null;
        _savedCount++;
      });
      _nameFocus.requestFocus();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.store.deleteGift(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  /// What this person gave / received before, so you can match it.
  String? _hint(BuildContext context) {
    final p = context.store.personByName(_name.text);
    if (p == null) return null;
    if (widget.event.mine) {
      if (p.given.isEmpty) return null;
      final last = p.given.last;
      return 'You gave ${p.name} ${inr(p.givenTotal)} before (${last.$2.name}).';
    }
    final last = p.lastReceived;
    if (last == null) return null;
    return '${p.name} gave you ${inr(last.$1.amount)} at ${last.$2.name}. '
        'Total received ${inr(p.receivedTotal)}.';
  }

  /// One row of equal-width chips so the whole set is visible at once.
  Widget _chipRow(List<Widget> chips) => Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: chips[i]),
          ],
        ],
      );

  static const _dense = InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hint = _hint(context);
    final amountNow = int.tryParse(_amount.text.replaceAll(',', '').trim());
    final mine = widget.event.mine;
    final isNew = widget.existing == null;

    // Layout: title, then the fields in a scroll area, then Save buttons that
    // stay pinned. With the keyboard open everything fits on one screen on a
    // normal phone; with a very large text size the fields scroll and the
    // buttons stay visible.
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, sheetBottomPadding(context) + 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isNew ? (mine ? 'Add gift received' : 'Add gift given') : 'Edit entry',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (_savedCount > 0)
                Chip(
                  avatar: const Icon(Icons.check, size: 16),
                  label: Text('$_savedCount saved'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: _name,
                          focusNode: _nameFocus,
                          autofocus: isNew, // keyboard opens as soon as the form opens
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          decoration: _dense.copyWith(labelText: mine ? 'Who gave?' : 'Who is it for?'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: _place,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: _dense.copyWith(labelText: 'Village / area'),
                        ),
                      ),
                    ],
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.history, size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(child: Text(hint, style: tt.bodySmall?.copyWith(color: cs.primary))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  _chipRow([
                    for (final r in relations)
                      ChoiceChip(
                        label: FittedBox(fit: BoxFit.scaleDown, child: Text(r)),
                        labelPadding: EdgeInsets.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        selected: _relation == r,
                        onSelected: (v) => setState(() => _relation = v ? r : ''),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    decoration: _dense.copyWith(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      suffixText: amountNow != null && amountNow > 0 ? inr(amountNow) : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _chipRow([
                    for (final a in quickAmounts)
                      ActionChip(
                        label: FittedBox(fit: BoxFit.scaleDown, child: Text(inr(a))),
                        labelPadding: EdgeInsets.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: () => setState(() => _amount.text = '$a'),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: _dense.copyWith(
                      labelText: 'Gift / note (optional)',
                      hintText: 'e.g. Silver plate',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(_error!, style: TextStyle(color: cs.error)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!isNew)
                IconButton(
                  tooltip: 'Delete entry',
                  onPressed: _delete,
                  icon: Icon(Icons.delete_outline, color: cs.error),
                ),
              if (isNew)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _submit(another: true),
                    child: const Text('Save & add next'),
                  ),
                ),
              if (isNew) const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _submit(another: false),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
