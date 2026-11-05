/// Odstráni citovanú históriu z textu správy, aby konverzácia pôsobila čisto.
String stripQuoted(String text) {
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final marker = RegExp(
    r'^(On .+wrote:|Dňa .+napísal.*|Dne .+napsal.*|-{2,}\s*Original Message\s*-{2,}|-{2,}\s*Pôvodná správa\s*-{2,}|_{5,}|From:\s.+)$',
    caseSensitive: false,
  );
  final out = <String>[];
  for (final line in lines) {
    final t = line.trim();
    if (marker.hasMatch(t) || t.startsWith('>')) break;
    out.add(line);
  }
  final result = out.join('\n').trim();
  return result.isEmpty ? text.trim() : result;
}
