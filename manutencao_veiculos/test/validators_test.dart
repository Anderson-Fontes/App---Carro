import 'package:flutter_test/flutter_test.dart';
import 'package:manutencao_veiculos/core/formatters.dart';
import 'package:manutencao_veiculos/core/validators.dart';

void main() {
  group('Placa', () {
    test('aceita padrão antigo e Mercosul', () {
      expect(Validators.placa('abc-1234'), isNull);
      expect(Validators.placa('ABC1D23'), isNull);
    });
    test('rejeita formato inválido', () {
      expect(Validators.placa('AB12'), isNotNull);
      expect(Validators.placa("ABC1'D23"), isNotNull);
    });
  });

  group('Entradas maliciosas (SQL injection / XSS)', () {
    const ataques = [
      "x'); DROP TABLE veiculos;--",
      "' OR '1'='1",
      '<script>alert(1)</script>',
      '<img src=x onerror=alert(1)>',
      '"; DELETE FROM manutencoes; --',
    ];
    test('modelo rejeita todos', () {
      for (final a in ataques) {
        expect(Validators.modelo(a), isNotNull, reason: a);
      }
    });
    test('oficina rejeita todos', () {
      for (final a in ataques) {
        expect(Validators.oficina(a), isNotNull, reason: a);
      }
    });
    test('descrição de "Outro" rejeita todos', () {
      for (final a in ataques) {
        expect(Validators.descricaoOutro(a), isNotNull, reason: a);
      }
    });
    test('nome legítimo com acento, & e apóstrofo passa', () {
      expect(Validators.oficina("Auto Center D'Ávila & Cia"), isNull);
    });
  });

  group('Números', () {
    test('quilometragem', () {
      expect(Validators.parseKm('48.230'), 48230);
      expect(Validators.parseKm('48.230 km'), 48230);
      expect(Validators.parseKm('-1'), isNull);
      expect(Validators.parseKm('9999999'), isNull);
      expect(Validators.parseKm('12a'), isNull);
    });
    test('valor em centavos', () {
      expect(Validators.parseValorCentavos('1.234,56'), 123456);
      expect(Validators.parseValorCentavos('189,9'), 18990);
      expect(Validators.parseValorCentavos(''), 0);
      expect(Validators.parseValorCentavos('abc'), isNull);
    });
  });

  test('sanitizar remove caracteres de controle e espaços extras', () {
    expect(Validators.sanitizar('a\u0000b\n  c '), 'a b c');
  });

  test('formatadores', () {
    expect(formatKm(48230), '48.230 km');
    expect(formatReais(123456), 'R\$ 1.234,56');
    expect(somarMeses(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(isoParaData("2026-10-09'; DROP"), isNull);
  });

  group('Conta (e-mail e senha)', () {
    test('e-mail válido e normalização', () {
      expect(Validators.email('  Ana.Souza+garagem@Exemplo.com.br '), isNull);
      expect(
        Validators.normalizarEmail(' ANA@Exemplo.COM '),
        'ana@exemplo.com',
      );
    });
    test('e-mail inválido ou malicioso é rejeitado', () {
      for (final e in [
        '',
        'sem-arroba',
        'a@b',
        'a..b@exemplo.com',
        "x'); DROP TABLE veiculos;--@a.com",
        '<script>@a.com',
        'a b@exemplo.com',
      ]) {
        expect(Validators.email(e), isNotNull, reason: e);
      }
    });
    test('política de senha nova', () {
      expect(Validators.senhaNova('Garagem2026'), isNull);
      expect(Validators.senhaNova('curta1'), isNotNull); // < 8
      expect(Validators.senhaNova('somenteletras'), isNotNull);
      expect(Validators.senhaNova('12345678'), isNotNull);
      expect(Validators.senhaNova('a1' * 40), isNotNull); // > 72 bytes
    });
    test('login só exige preenchimento', () {
      expect(Validators.senhaLogin(''), isNotNull);
      expect(Validators.senhaLogin('qualquer'), isNull);
    });
    test('código de recuperação', () {
      expect(Validators.codigo('123456'), isNull);
      expect(Validators.codigo('12ab56'), isNotNull);
      expect(Validators.codigo('123'), isNotNull);
    });
  });

  group('Intervalos do plano', () {
    test('km', () {
      expect(Validators.intervaloKm(''), isNull);
      expect(Validators.intervaloKm('10.000'), isNull);
      expect(Validators.intervaloKm('100'), isNotNull);
      expect(Validators.intervaloKm('999999'), isNotNull);
      expect(Validators.lerIntervaloKm('10.000'), 10000);
      expect(Validators.lerIntervaloKm(''), isNull);
    });
    test('meses', () {
      expect(Validators.intervaloMeses(''), isNull);
      expect(Validators.intervaloMeses('12'), isNull);
      expect(Validators.intervaloMeses('0'), isNotNull);
      expect(Validators.intervaloMeses('121'), isNotNull);
      expect(Validators.intervaloMeses('1a'), isNotNull);
      expect(Validators.lerIntervaloMeses('24'), 24);
    });
  });
}
