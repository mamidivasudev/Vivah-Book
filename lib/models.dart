import 'dart:convert';

const eventTypes = <String>[
  'Wedding',
  'Engagement',
  'Housewarming',
  'Baby function',
  'Birthday',
  'Other',
];

const relations = <String>[
  'Family',
  'Relative',
  'Friend',
  'Neighbour',
  'Colleague',
  'Other',
];

/// Customary amounts (ending in 1) for one-tap entry.
const quickAmounts = <int>[101, 201, 501, 1001, 2001, 5001];

/// A function. [mine] true = it is MY function, so gifts are RECEIVED.
/// false = I attended someone else's function, so gifts are GIVEN by me.
class GiftEvent {
  GiftEvent({
    required this.id,
    required this.name,
    required this.type,
    required this.mine,
    required this.date,
    this.notes = '',
  });

  final int id;
  final String name;
  final String type;
  final bool mine;
  final DateTime date;
  final String notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'mine': mine,
        'date': DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
        'notes': notes,
      };

  static GiftEvent? fromJson(Map<String, dynamic> j) {
    try {
      return GiftEvent(
        id: j['id'] as int,
        name: j['name'] as String,
        type: (j['type'] as String?) ?? 'Other',
        mine: (j['mine'] as bool?) ?? true,
        date: DateTime.fromMillisecondsSinceEpoch(j['date'] as int),
        notes: (j['notes'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// One line in a register: a person and what they gave (or what I gave them).
class Gift {
  Gift({
    required this.id,
    required this.eventId,
    required this.name,
    this.place = '',
    this.relation = '',
    this.amount = 0,
    this.note = '',
    required this.at,
  });

  final int id;
  final int eventId;
  final String name;
  final String place;
  final String relation;

  /// Cash amount in rupees (0 if the gift is in kind).
  final int amount;

  /// Gift in kind or any remark, e.g. "Silver plate".
  final String note;
  final DateTime at;

  String get key => name.trim().toLowerCase();

  Map<String, dynamic> toJson() => {
        'id': id,
        'e': eventId,
        'name': name,
        'place': place,
        'rel': relation,
        'amt': amount,
        'note': note,
        'at': at.millisecondsSinceEpoch,
      };

  static Gift? fromJson(Map<String, dynamic> j) {
    try {
      return Gift(
        id: j['id'] as int,
        eventId: j['e'] as int,
        name: j['name'] as String,
        place: (j['place'] as String?) ?? '',
        relation: (j['rel'] as String?) ?? '',
        amount: (j['amt'] as int?) ?? 0,
        note: (j['note'] as String?) ?? '',
        at: DateTime.fromMillisecondsSinceEpoch((j['at'] as int?) ?? 0),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Everything known about one person across all functions.
class Person {
  Person(this.key, this.name);

  final String key;
  String name;
  final Set<String> places = {};

  /// Gifts this person gave ME (at my functions).
  final List<(Gift, GiftEvent)> received = [];

  /// Gifts I gave THEM (at their functions).
  final List<(Gift, GiftEvent)> given = [];

  int get receivedTotal => received.fold(0, (a, e) => a + e.$1.amount);
  int get givenTotal => given.fold(0, (a, e) => a + e.$1.amount);

  /// Their most recent gift to me, by function date.
  (Gift, GiftEvent)? get lastReceived {
    if (received.isEmpty) return null;
    final l = List.of(received)..sort((a, b) => b.$2.date.compareTo(a.$2.date));
    return l.first;
  }
}

List<T> decodeList<T>(dynamic raw, T? Function(Map<String, dynamic>) f) {
  try {
    final list = raw is String ? jsonDecode(raw) as List : raw as List;
    return list.map((e) => f(Map<String, dynamic>.from(e as Map))).whereType<T>().toList();
  } catch (_) {
    return [];
  }
}

// ── Formatting helpers ────────────────────────────────────────────────────────

/// Indian digit grouping: 1,00,000.
String inr(int n) {
  final neg = n < 0;
  var s = n.abs().toString();
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last3';
  }
  return '${neg ? '-' : ''}₹$s';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String csvCell(String s) => '"${s.replaceAll('"', '""')}"';
