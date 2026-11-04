import '../models/manutencao.dart';
import 'formatters.dart';

/// Protege contra "CSV injection": células que começam com = + - @ podem ser
/// executadas como fórmula no Excel/Sheets. Prefixamos com apóstrofo.
String celulaCsv(String? valor) {
  var s = valor ?? '';
  if (s.isNotEmpty && '=+-@\t\r'.contains(s[0])) s = "'$s";
  return '"${s.replaceAll('"', '""')}"';
}

String gerarCsv(List<Manutencao> itens) {
  final b = StringBuffer('data,servico,km,valor_reais,oficina\n');
  for (final m in itens) {
    final reais =
        '${m.valorCentavos ~/ 100}.${(m.valorCentavos % 100).toString().padLeft(2, '0')}';
    b.writeln(
      [
        dataParaIso(m.data),
        m.titulo,
        '${m.km}',
        reais,
        m.oficina ?? '',
      ].map(celulaCsv).join(','),
    );
  }
  return b.toString();
}
