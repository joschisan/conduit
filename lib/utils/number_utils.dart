const _spelledNumbers = [
  'One',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Eleven',
  'Twelve',
  'Thirteen',
  'Fourteen',
  'Fifteen',
  'Sixteen',
  'Seventeen',
  'Eighteen',
  'Nineteen',
  'Twenty',
];

/// Spells out [n] in words (e.g. 1 -> 'One', 23 -> 'Twenty-Three'). Covers the
/// 1..24 range used for recovery phrase positions; falls back to the digits for
/// anything outside it.
String spellOutNumber(int n) {
  if (n >= 1 && n <= 20) return _spelledNumbers[n - 1];
  if (n >= 21 && n <= 29) return 'Twenty-${_spelledNumbers[n - 21]}';
  return '$n';
}
