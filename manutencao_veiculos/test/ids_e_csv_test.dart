import 'package:flutter_test/flutter_test.dart';
import 'package:manutencao_veiculos/core/csv_export.dart';
import 'package:manutencao_veiculos/core/notificacao_ids.dart';
import 'package:manutencao_veiculos/models/item_plano.dart';
import 'package:manutencao_veiculos/models/manutencao.dart';

void main() {
  group('id de notificação (UUID -> inteiro de 32 bits)', () {
    const uuid = '3f2b8c1e-9a4d-4c11-8f3e-0a1b2c3d4e5f';

    test('é estável e cabe em 32 bits', () {
      final a = idNotificacao(uuid, ChaveItem.oleo);
      expect(a, idNotificacao(uuid, ChaveItem.oleo));
      expect(a, lessThan(2147483647));
      expect(a, greaterThanOrEqualTo(0));
    });

    test('muda por item e entre agendado/imediato', () {
      final ids = <int>{
        for (final c in ChaveItem.values) ...[
          idNotificacao(uuid, c),
          idNotificacao(uuid, c, imediato: true),
        ],
      };
      expect(ids.length, ChaveItem.values.length * 2);
    });
  });

  group('exportação CSV', () {
    test('neutraliza fórmulas (CSV injection) e aspas', () {
      expect(
        celulaCsv('=HYPERLINK("http://x")'),
        '"\'=HYPERLINK(""http://x"")"',
      );
      expect(celulaCsv('+1+1'), '"\'+1+1"');
      expect(celulaCsv('@SUM(A1)'), '"\'@SUM(A1)"');
      expect(celulaCsv('Oficina "Boa"'), '"Oficina ""Boa"""');
      expect(celulaCsv(null), '""');
    });

    test('gera cabeçalho e linhas', () {
      final csv = gerarCsv([
        Manutencao(
          veiculoId: 'v1',
          tipo: TipoServico.oleo,
          data: DateTime(2026, 3, 1),
          km: 39030,
          valorCentavos: 18990,
          oficina: 'Auto Center',
        ),
      ]);
      final linhas = csv.trim().split('\n');
      expect(linhas.first, 'data,servico,km,valor_reais,oficina');
      expect(
        linhas[1],
        '"2026-03-01","Óleo e filtro","39030","189.90","Auto Center"',
      );
    });
  });
}
