class SoftSymbols {
  const SoftSymbols._();

  static const String blossom = '\u2740';
  static const String thread = '\u27E2';
  static const String heart = '\u2661';
  static const String star = '\u2729';
  static const String ribbon = '\uD835\uDF17\u09CE';
  static const String pairedWaves = '\u2AA9\u2AA8';

  static const String anonymous = 'Anonymous $blossom';

  static String prefixed(String symbol, String text) => '$symbol $text';
}
