import 'package:deutsch_review/domain/german_numbers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forms all German cardinal numbers from zero through one hundred', () {
    expect(germanNumberWord(0), 'null');
    expect(germanNumberWord(11), 'elf');
    expect(germanNumberWord(12), 'zwölf');
    expect(germanNumberWord(16), 'sechzehn');
    expect(germanNumberWord(17), 'siebzehn');
    expect(germanNumberWord(20), 'zwanzig');
    expect(germanNumberWord(21), 'einundzwanzig');
    expect(germanNumberWord(30), 'dreißig');
    expect(germanNumberWord(46), 'sechsundvierzig');
    expect(germanNumberWord(71), 'einundsiebzig');
    expect(germanNumberWord(99), 'neunundneunzig');
    expect(germanNumberWord(100), 'hundert');
    expect(
      List.generate(101, germanNumberWord).toSet(),
      hasLength(101),
    );
  });

  test('rejects values outside the taught range', () {
    expect(() => germanNumberWord(-1), throwsRangeError);
    expect(() => germanNumberWord(101), throwsRangeError);
  });
}
