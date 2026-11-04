import 'package:flutter_test/flutter_test.dart';
import 'package:manutencao_veiculos/core/status_calculator.dart';
import 'package:manutencao_veiculos/models/item_plano.dart';
import 'package:manutencao_veiculos/models/manutencao.dart';

void main() {
  final hoje = DateTime(2026, 10, 14);
  const calc = StatusCalculator();

  Manutencao troca(TipoServico t, DateTime data, int km) => Manutencao(
    veiculoId: 'v1',
    tipo: t,
    data: data,
    km: km,
    valorCentavos: 0,
  );

  const oleo = ItemPlano(
    veiculoId: 'v1',
    chave: ChaveItem.oleo,
    intervaloKm: 10000,
    intervaloMeses: 12,
  );
  final ultOleo = troca(TipoServico.oleo, DateTime(2026, 3, 1), 39030);

  test('óleo vence logo quando faltam 800 km', () {
    final s = calc.calcular(
      item: oleo,
      kmAtual: 48230,
      hoje: hoje,
      ultima: ultOleo,
    );
    expect(s.status, Status.venceLogo);
    expect(s.detalhe, 'faltam 800 km');
  });

  test('óleo atrasado ao passar do intervalo', () {
    final s = calc.calcular(
      item: oleo,
      kmAtual: 50000,
      hoje: hoje,
      ultima: ultOleo,
    );
    expect(s.status, Status.atrasado);
  });

  test('óleo em dia', () {
    final s = calc.calcular(
      item: oleo,
      kmAtual: 40000,
      hoje: hoje,
      ultima: ultOleo,
    );
    expect(s.status, Status.emDia);
  });

  test('sem registro quando nunca foi feito', () {
    final s = calc.calcular(item: oleo, kmAtual: 40000, hoje: hoje);
    expect(s.status, Status.semRegistro);
  });

  test('vale o que ocorrer primeiro: data vence antes do km', () {
    final antigo = troca(TipoServico.oleo, DateTime(2025, 9, 1), 47000);
    final s = calc.calcular(
      item: oleo,
      kmAtual: 48000,
      hoje: hoje,
      ultima: antigo,
    );
    expect(s.status, Status.atrasado); // 12 meses já passaram
  });

  test('IPVA atrasado há 5 dias', () {
    final ipva = ItemPlano(
      veiculoId: 'v1',
      chave: ChaveItem.ipva,
      vencimento: DateTime(2026, 10, 9),
    );
    final s = calc.calcular(item: ipva, kmAtual: 0, hoje: hoje);
    expect(s.status, Status.atrasado);
    expect(s.detalhe, 'venceu há 5 dias');
  });

  test('seguro em dia', () {
    final seguro = ItemPlano(
      veiculoId: 'v1',
      chave: ChaveItem.seguro,
      vencimento: DateTime(2027, 3, 14),
    );
    expect(
      calc.calcular(item: seguro, kmAtual: 0, hoje: hoje).status,
      Status.emDia,
    );
  });

  test('pneus: faltam 9.000 km', () {
    const pneus = ItemPlano(
      veiculoId: 'v1',
      chave: ChaveItem.pneus,
      intervaloKm: 10000,
    );
    final ult = troca(TipoServico.pneus, DateTime(2026, 9, 1), 47230);
    final s = calc.calcular(
      item: pneus,
      kmAtual: 48230,
      hoje: hoje,
      ultima: ult,
    );
    expect(s.status, Status.emDia);
    expect(s.detalhe, 'faltam 9.000 km');
  });
}
