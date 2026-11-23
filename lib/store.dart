import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Everything is stored locally on the phone in SharedPreferences.
class AppStore extends ChangeNotifier {
  AppStore(this._prefs) {
    _events = decodeList(_prefs.getString(_kEvents), GiftEvent.fromJson);
    _gifts = decodeList(_prefs.getString(_kGifts), Gift.fromJson);
  }

  static const _kEvents = 'events_v1';
  static const _kGifts = 'gifts_v1';
  static const _kScale = 'text_scale';

  final SharedPreferences _prefs;
  late List<GiftEvent> _events;
  late List<Gift> _gifts;

  static Future<AppStore> load() async => AppStore(await SharedPreferences.getInstance());

  // ── Settings ──────────────────────────────────────────────────────────────
  /// 1.0 normal, 1.15 large, 1.3 extra large (helps elders read the register).
  double get textScale => _prefs.getDouble(_kScale) ?? 1.0;

  Future<void> setTextScale(double v) async {
    await _prefs.setDouble(_kScale, v);
    notifyListeners();
  }

  // ── Events ────────────────────────────────────────────────────────────────
  /// Newest function first.
  List<GiftEvent> get events =>
      List<GiftEvent>.of(_events)..sort((a, b) => b.date.compareTo(a.date));

  GiftEvent? eventById(int id) {
    for (final e in _events) {
      if (e.id == id) return e;
    }
    return null;
  }

  int newId() {
    var id = DateTime.now().microsecondsSinceEpoch;
    final used = {..._events.map((e) => e.id), ..._gifts.map((g) => g.id)};
    while (used.contains(id)) {
      id++;
    }
    return id;
  }

  Future<void> _saveEvents() async {
    await _prefs.setString(_kEvents, jsonEncode(_events.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> _saveGifts() async {
    await _prefs.setString(_kGifts, jsonEncode(_gifts.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> saveEvent(GiftEvent e) async {
    final i = _events.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      _events[i] = e;
    } else {
      _events.add(e);
    }
    await _saveEvents();
  }

  Future<void> deleteEvent(int id) async {
    _events.removeWhere((e) => e.id == id);
    _gifts.removeWhere((g) => g.eventId == id);
    await _saveEvents();
    await _saveGifts();
  }

  // ── Gifts ─────────────────────────────────────────────────────────────────
  List<Gift> giftsFor(int eventId) => _gifts.where((g) => g.eventId == eventId).toList();

  int totalFor(int eventId) =>
      _gifts.where((g) => g.eventId == eventId).fold(0, (a, g) => a + g.amount);

  int countFor(int eventId) => _gifts.where((g) => g.eventId == eventId).length;

  Future<void> saveGift(Gift g) async {
    final i = _gifts.indexWhere((x) => x.id == g.id);
    if (i >= 0) {
      _gifts[i] = g;
    } else {
      _gifts.add(g);
    }
    await _saveGifts();
  }

  Future<void> deleteGift(int id) async {
    _gifts.removeWhere((g) => g.id == id);
    await _saveGifts();
  }

  // ── People (grouped by name across all functions) ─────────────────────────
  List<Person> get people {
    final map = <String, Person>{};
    for (final g in _gifts) {
      final ev = eventById(g.eventId);
      if (ev == null || g.key.isEmpty) continue;
      final p = map.putIfAbsent(g.key, () => Person(g.key, g.name.trim()));
      if (g.place.trim().isNotEmpty) p.places.add(g.place.trim());
      (ev.mine ? p.received : p.given).add((g, ev));
    }
    final list = map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Person? personByName(String name) {
    final k = name.trim().toLowerCase();
    if (k.isEmpty) return null;
    for (final p in people) {
      if (p.key == k) return p;
    }
    return null;
  }

  // ── Export ────────────────────────────────────────────────────────────────
  String registerText(GiftEvent e) {
    final gifts = giftsFor(e.id)..sort((a, b) => a.at.compareTo(b.at));
    final b = StringBuffer()
      ..writeln('${e.name} (${e.type}, ${fmtDate(e.date)})')
      ..writeln('${e.mine ? 'Received' : 'Given'}: ${inr(totalFor(e.id))} · ${gifts.length} entries')
      ..writeln();
    for (var i = 0; i < gifts.length; i++) {
      final g = gifts[i];
      final extra = [if (g.place.isNotEmpty) g.place, if (g.note.isNotEmpty) g.note].join(', ');
      b.writeln('${i + 1}. ${g.name}${extra.isEmpty ? '' : ' ($extra)'} - ${g.amount > 0 ? inr(g.amount) : 'gift'}');
    }
    return b.toString().trimRight();
  }

  String registerCsv(GiftEvent e) {
    final gifts = giftsFor(e.id)..sort((a, b) => a.at.compareTo(b.at));
    final b = StringBuffer()..writeln('Name,Place,Relation,Amount,Note,Date');
    for (final g in gifts) {
      b.writeln([
        csvCell(g.name),
        csvCell(g.place),
        csvCell(g.relation),
        g.amount,
        csvCell(g.note),
        csvCell(fmtDate(g.at)),
      ].join(','));
    }
    return b.toString().trimRight();
  }

  // ── Backup / restore (copy and paste text, no files or permissions) ───────
  String backupJson() => jsonEncode({
        'app': 'gift_register',
        'v': 1,
        'events': _events.map((e) => e.toJson()).toList(),
        'gifts': _gifts.map((g) => g.toJson()).toList(),
      });

  /// Replaces all data with the backup. Returns an error message, or null on success.
  Future<String?> restoreJson(String text) async {
    try {
      final m = jsonDecode(text.trim());
      if (m is! Map || m['app'] != 'gift_register') return 'This is not a VivahBook backup.';
      final events = decodeList<GiftEvent>(m['events'], GiftEvent.fromJson);
      final gifts = decodeList<Gift>(m['gifts'], Gift.fromJson);
      _events = events;
      _gifts = gifts;
      await _saveEvents();
      await _saveGifts();
      return null;
    } catch (_) {
      return 'Could not read the backup. Paste the full text you copied.';
    }
  }

  /// Wipes everything (used by "Delete all my data").
  Future<void> deleteAll() async {
    _events = [];
    _gifts = [];
    await _prefs.clear();
    notifyListeners();
  }
}
