const _basicGermanNumbers = <int, String>{
  0: 'null',
  1: 'eins',
  2: 'zwei',
  3: 'drei',
  4: 'vier',
  5: 'fünf',
  6: 'sechs',
  7: 'sieben',
  8: 'acht',
  9: 'neun',
  10: 'zehn',
  11: 'elf',
  12: 'zwölf',
};

const _germanTeens = <int, String>{
  13: 'dreizehn',
  14: 'vierzehn',
  15: 'fünfzehn',
  16: 'sechzehn',
  17: 'siebzehn',
  18: 'achtzehn',
  19: 'neunzehn',
};

const _germanTens = <int, String>{
  20: 'zwanzig',
  30: 'dreißig',
  40: 'vierzig',
  50: 'fünfzig',
  60: 'sechzig',
  70: 'siebzig',
  80: 'achtzig',
  90: 'neunzig',
};

String germanNumberWord(int value) {
  if (value < 0 || value > 100) {
    throw RangeError.range(value, 0, 100, 'value');
  }
  if (value == 100) return 'hundert';
  if (_basicGermanNumbers[value] case final word?) return word;
  if (_germanTeens[value] case final word?) return word;
  if (_germanTens[value] case final word?) return word;
  final ones = value % 10;
  final tens = value - ones;
  final onesWord = ones == 1 ? 'ein' : _basicGermanNumbers[ones]!;
  return '${onesWord}und${_germanTens[tens]}';
}
