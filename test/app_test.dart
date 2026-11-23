import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_register/main.dart';
import 'package:gift_register/models.dart';
import 'package:gift_register/screens/gift_form.dart';
import 'package:gift_register/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _store([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return AppStore.load();
}

Future<void> _bigScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Text fields inside the gift entry sheet (the register behind it has a search box too).
Finder _formFields() =>
    find.descendant(of: find.byType(GiftForm), matching: find.byType(TextField));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  test('Indian rupee grouping', () {
    expect(inr(0), '₹0');
    expect(inr(101), '₹101');
    expect(inr(1000), '₹1,000');
    expect(inr(12345), '₹12,345');
    expect(inr(100000), '₹1,00,000');
    expect(inr(1234567), '₹12,34,567');
    expect(inr(-2500), '-₹2,500');
  });

  test('csv cells are escaped', () {
    expect(csvCell('Ravi "Raja" Kumar'), '"Ravi ""Raja"" Kumar"');
  });

  group('AppStore', () {
    late AppStore s;
    late GiftEvent mine;
    late GiftEvent theirs;

    setUp(() async {
      s = await _store();
      mine = GiftEvent(id: s.newId(), name: 'Our wedding', type: 'Wedding', mine: true, date: DateTime(2026, 5, 1));
      await s.saveEvent(mine);
      theirs = GiftEvent(id: s.newId(), name: 'Suresh housewarming', type: 'Housewarming', mine: false, date: DateTime(2026, 9, 10));
      await s.saveEvent(theirs);
    });

    Gift gift(GiftEvent e, String name, int amount, {String place = '', String note = ''}) =>
        Gift(id: s.newId(), eventId: e.id, name: name, amount: amount, place: place, note: note, at: DateTime.now());

    test('totals, counts and ids', () async {
      await s.saveGift(gift(mine, 'Suresh Uncle', 2000, place: 'Guntur'));
      await s.saveGift(gift(mine, 'Ramesh', 501));
      await s.saveGift(gift(mine, 'Lakshmi', 0, note: 'Silver plate'));
      expect(s.totalFor(mine.id), 2501);
      expect(s.countFor(mine.id), 3);
      expect(s.totalFor(theirs.id), 0);
      expect(s.events.first.id, theirs.id); // newest function first
    });

    test('people lookup shows what they gave and what I gave', () async {
      await s.saveGift(gift(mine, 'Suresh Uncle', 2000, place: 'Guntur'));
      await s.saveGift(gift(theirs, 'suresh uncle', 1001));
      final p = s.personByName('  SURESH UNCLE ')!;
      expect(p.receivedTotal, 2000);
      expect(p.givenTotal, 1001);
      expect(p.lastReceived!.$2.name, 'Our wedding');
      expect(p.places, {'Guntur'});
      expect(s.people.length, 1);
      expect(s.personByName('nobody'), isNull);
    });

    test('deleting a function removes its entries', () async {
      await s.saveGift(gift(mine, 'A', 100));
      await s.saveGift(gift(theirs, 'B', 200));
      await s.deleteEvent(mine.id);
      expect(s.countFor(mine.id), 0);
      expect(s.countFor(theirs.id), 1);
      expect(s.people.map((p) => p.name), ['B']);
    });

    test('export text and csv', () async {
      await s.saveGift(gift(mine, 'Ramesh', 501, place: 'Tenali'));
      await s.saveGift(gift(mine, 'Lakshmi', 0, note: 'Silver plate'));
      final text = s.registerText(mine);
      expect(text, contains('Our wedding'));
      expect(text, contains('Received: ₹501'));
      expect(text, contains('1. Ramesh (Tenali) - ₹501'));
      expect(text, contains('2. Lakshmi (Silver plate) - gift'));
      final csv = s.registerCsv(mine);
      expect(csv.split('\n').first, 'Name,Place,Relation,Amount,Note,Date');
      expect(csv, contains('"Ramesh","Tenali"'));
    });

    test('backup and restore round trip, bad input rejected', () async {
      await s.saveGift(gift(mine, 'Ramesh', 501));
      final backup = s.backupJson();

      final other = await _store();
      expect(other.events, isEmpty);
      expect(await other.restoreJson(backup), isNull);
      expect(other.events.length, 2);
      expect(other.totalFor(mine.id), 501);

      expect(await other.restoreJson('hello'), isNotNull);
      expect(await other.restoreJson('{"app":"something_else"}'), isNotNull);
      expect(other.events.length, 2); // unchanged after bad restores
    });

    test('data persists across restarts; deleteAll wipes it', () async {
      await s.saveGift(gift(mine, 'Ramesh', 501));
      await s.setTextScale(1.3);
      final again = await AppStore.load();
      expect(again.totalFor(mine.id), 501);
      expect(again.textScale, 1.3);
      await again.deleteAll();
      expect(again.events, isEmpty);
      expect(again.textScale, 1.0);
    });
  });

  test('corrupt stored data does not crash', () async {
    final s = await _store({'events_v1': 'oops', 'gifts_v1': '[1,'});
    expect(s.events, isEmpty);
  });

  testWidgets('all tabs open without errors', (tester) async {
    await _bigScreen(tester);
    final store = await _store();
    await tester.pumpWidget(GiftRegisterApp(store: store));
    await _settle(tester);
    expect(find.text('Your function gift book'), findsOneWidget);
    for (final tab in ['People', 'Settings', 'Functions']) {
      await tester.tap(find.text(tab).last);
      await _settle(tester);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('create a function and add gifts with quick amounts', (tester) async {
    await _bigScreen(tester);
    final store = await _store();
    await tester.pumpWidget(GiftRegisterApp(store: store));
    await _settle(tester);

    await tester.tap(find.text('New function'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Our wedding');
    await tester.tap(find.text('Save'));
    await _settle(tester);
    expect(store.events.single.name, 'Our wedding');
    expect(find.text('Add gift received'), findsOneWidget);

    await tester.tap(find.text('Add gift received'));
    await _settle(tester);
    await tester.enterText(_formFields().at(0), 'Suresh Uncle');
    await tester.tap(find.text('₹501'));
    await tester.pump();
    await tester.tap(find.text('Save & add next'));
    await _settle(tester);
    expect(store.totalFor(store.events.single.id), 501);

    await tester.enterText(_formFields().at(0), 'Ramesh');
    await tester.enterText(_formFields().at(2), '1001');
    await tester.tap(find.text('Save').last);
    await _settle(tester);
    expect(store.totalFor(store.events.single.id), 1502);
    expect(find.text('₹1,502'), findsOneWidget);
    expect(find.text('Suresh Uncle'), findsOneWidget);
  });

  testWidgets('entry without amount or note is rejected', (tester) async {
    await _bigScreen(tester);
    final store = await _store();
    final e = GiftEvent(id: 1, name: 'Test', type: 'Other', mine: true, date: DateTime(2026, 1, 1));
    await store.saveEvent(e);
    await tester.pumpWidget(GiftRegisterApp(store: store));
    await _settle(tester);
    await tester.tap(find.text('Test'));
    await _settle(tester);
    await tester.tap(find.text('Add gift received'));
    await _settle(tester);
    await tester.enterText(_formFields().at(0), 'Someone');
    await tester.tap(find.text('Save').last);
    await _settle(tester);
    expect(find.text('Enter an amount, or write the gift in the note.'), findsOneWidget);
    expect(store.countFor(1), 0);
  });

  testWidgets('entry form: keyboard opens by itself and everything fits above it', (tester) async {
    // A normal phone: 360 x 800 dp, with a 300 dp keyboard on screen.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 900); // 300 dp
    tester.view.padding = const FakeViewPadding(top: 72, bottom: 144); // status bar + nav bar
    addTearDown(tester.view.reset);

    final store = await _store();
    await store.saveEvent(GiftEvent(id: 1, name: 'Test', type: 'Other', mine: true, date: DateTime(2026, 1, 1)));
    await tester.pumpWidget(GiftRegisterApp(store: store));
    await _settle(tester);
    await tester.tap(find.text('Test'));
    await _settle(tester);
    await tester.tap(find.text('Add gift received'));
    await _settle(tester);

    // The name field has focus without tapping it, so the keyboard opens.
    final nameField = tester.widget<TextField>(_formFields().at(0));
    expect(nameField.focusNode!.hasFocus, isTrue);

    // Every part of the form is on screen, above the keyboard (top 500 dp).
    const keyboardTop = 800 - 300.0;
    for (final finder in [
      _formFields().at(0), // name
      _formFields().at(1), // village
      find.text('Family'), // relation chips
      find.text('Other'),
      _formFields().at(2), // amount
      find.text('₹101'), // quick amounts, first and last
      find.text('₹5,001'),
      _formFields().at(3), // note
      find.text('Save & add next'),
      find.text('Save'),
    ]) {
      final rect = tester.getRect(finder);
      expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder is above the screen');
      expect(rect.bottom, lessThanOrEqualTo(keyboardTop), reason: '$finder is hidden by the keyboard (bottom ${rect.bottom})');
    }
    expect(tester.takeException(), isNull);
  });
}
