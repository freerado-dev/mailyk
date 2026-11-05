import 'package:flutter_test/flutter_test.dart';
import 'package:konverzo_mail/util.dart';

void main() {
  test('stripQuoted odstráni citovanú históriu', () {
    const text = 'Ahoj, ďakujem.\n\nOn Mon, 3 Nov 2026, Jan wrote:\n> pôvodná správa';
    expect(stripQuoted(text), 'Ahoj, ďakujem.');
  });

  test('stripQuoted ponechá celý text, ak je všetko citácia', () {
    const text = '> len citácia';
    expect(stripQuoted(text), '> len citácia');
  });

  test('stripQuoted podporuje slovenské označenie', () {
    const text = 'Super.\nDňa 3. 11. 2026 Jana napísal:\n> staré';
    expect(stripQuoted(text), 'Super.');
  });
}
