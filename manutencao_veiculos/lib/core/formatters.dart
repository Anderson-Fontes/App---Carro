/// Funções puras de formatação e datas (sem dependências externas).
library;

String _milhar(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}

String formatKm(int km) => '${_milhar(km)} km';

String formatData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String formatReais(int centavos) {
  final reais = centavos ~/ 100;
  final cents = centavos % 100;
  return 'R\$ ${_milhar(reais)},${cents.toString().padLeft(2, '0')}';
}

/// Data no formato ISO (yyyy-MM-dd), usado para gravar no SQLite.
String dataParaIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Converte o ISO de volta para data. Retorna null se o texto for inválido.
DateTime? isoParaData(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

DateTime soData(DateTime d) => DateTime(d.year, d.month, d.day);

/// Dias entre duas datas (ignora horário). Positivo se [fim] é depois de [inicio].
int diasEntre(DateTime inicio, DateTime fim) => DateTime.utc(
  fim.year,
  fim.month,
  fim.day,
).difference(DateTime.utc(inicio.year, inicio.month, inicio.day)).inDays;

/// Soma meses sem estourar o último dia do mês (31/01 + 1 mês = 28/02).
DateTime somarMeses(DateTime d, int meses) {
  final mesAlvo = d.month + meses;
  final ultimoDia = DateTime(d.year, mesAlvo + 1, 0).day;
  return DateTime(d.year, mesAlvo, d.day > ultimoDia ? ultimoDia : d.day);
}
