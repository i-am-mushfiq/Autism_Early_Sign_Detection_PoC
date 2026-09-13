import 'package:flutter_test/flutter_test.dart';
import 'package:sanket_mobile/core/activity_catalog.dart';
import 'package:sanket_mobile/core/interpretation.dart';
import 'package:sanket_mobile/core/measurement.dart';
import 'package:sanket_mobile/core/session.dart';
import 'package:sanket_mobile/l10n/locale_scope.dart';
import 'package:sanket_mobile/l10n/strings.dart';

final _bengali = RegExp(r'[ঀ-৿]');
final _latinWord = RegExp(r'[A-Za-z]{3,}');

void main() {
  const en = Strings(AppLanguage.en);
  const bn = Strings(AppLanguage.bn);

  test('every key has non-empty English and Bangla with identical placeholders', () {
    for (final key in T.values) {
      expect(key.en.trim(), isNotEmpty, reason: '${key.name} en');
      expect(key.bn.trim(), isNotEmpty, reason: '${key.name} bn');
      expect(Strings.placeholdersOf(key.bn), Strings.placeholdersOf(key.en), reason: key.name);
    }
  });

  test('Bangla strings are actually in Bangla script', () {
    // Language switch label intentionally shows the *other* language.
    const exceptions = {T.switchLanguage};
    for (final key in T.values.where((k) => !exceptions.contains(k))) {
      expect(_bengali.hasMatch(key.bn), isTrue, reason: '${key.name} has no Bangla text: ${key.bn}');
    }
  });

  test('Bangla copy does not leak untranslated English words', () {
    for (final key in T.values.where((k) => k != T.switchLanguage)) {
      expect(_latinWord.hasMatch(key.bn.replaceAll(RegExp(r'\{\w+\}'), '')), isFalse,
          reason: '${key.name}: ${key.bn}');
    }
  });

  test('placeholders are filled and numbers use Bangla digits', () {
    expect(bn(T.stageActivityOf, {'n': 3, 'total': 6}), 'কার্যক্রম ৩ / ৬');
    expect(en(T.stageActivityOf, {'n': 3, 'total': 6}), 'Activity 3 of 6');
    expect(bn(T.nameCallNow, {'name': 'টুকটুকি'}), contains('টুকটুকি'));
    expect(en(T.lookChild), 'Where is Mitu looking?');
    expect(bn(T.lookChild), 'মিতু কোথায় তাকাচ্ছে?');
    expect(bn.seconds(1250), '১.৩');
    expect(bn.dateTime(DateTime(2026, 9, 13, 8, 5)), '২০২৬-০৯-১৩ ০৮:০৫');
  });

  test('the entered child name flows into every name-bearing instruction', () {
    const name = 'Tuktuki';
    for (final key in T.values.where((k) => Strings.placeholdersOf(k.en).contains('name'))) {
      expect(en(key, {'name': name}), contains(name), reason: key.name);
      expect(en(key, {'name': name}), isNot(contains('{name}')));
    }
    for (final id in ActivityId.values) {
      final text = en.parentInstruction(id, name);
      expect(text, isNot(contains('Ayaan')));
    }
    expect(T.values.any((k) => k.en.contains('Ayaan') || k.bn.contains('Ayaan')), isFalse);
  });

  test('all domain enums have localized text in both languages', () {
    for (final s in [en, bn]) {
      for (final r in ReasonCode.values) {
        expect(s.reason(r, 'X'), isNot(contains('{')));
      }
      for (final id in ActivityId.values) {
        expect(s.activityName(id), isNotEmpty);
        expect(s.construct(id), isNotEmpty);
      }
      for (final st in ObservationState.values) {
        expect(s.stateTitle(st), isNotEmpty);
        expect(s.nextStep(st, 'X'), isNotEmpty);
      }
      for (final st in ActivityStatus.values) {
        expect(s.activityStatus(st), isNotEmpty);
      }
      for (final st in SessionStatus.values) {
        expect(s.sessionStatus(st), isNotEmpty);
      }
      for (final f in ContextFactor.values) {
        expect(s.factor(f), isNotEmpty);
      }
    }
  });

  test('result copy never contains diagnostic language', () {
    final banned = RegExp(r'\b(diagnosed|has autism|autistic|probability|risk score|percent chance)\b', caseSensitive: false);
    for (final st in ObservationState.values) {
      expect(banned.hasMatch(en.stateTitle(st)), isFalse);
      expect(banned.hasMatch(en.stateBody(st, 'X')), isFalse);
      expect(banned.hasMatch(en.nextStep(st, 'X')), isFalse);
    }
  });
}
