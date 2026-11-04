import '../core/formatters.dart';
import 'item_plano.dart';

enum TipoServico { oleo, pneus, freios, bateria, outro }

extension TipoServicoX on TipoServico {
  String get rotulo {
    switch (this) {
      case TipoServico.oleo:
        return 'Óleo e filtro';
      case TipoServico.pneus:
        return 'Pneus';
      case TipoServico.freios:
        return 'Freios';
      case TipoServico.bateria:
        return 'Bateria';
      case TipoServico.outro:
        return 'Outro';
    }
  }

  /// Item do painel que este serviço "zera" (null para "Outro").
  ChaveItem? get chave {
    switch (this) {
      case TipoServico.oleo:
        return ChaveItem.oleo;
      case TipoServico.pneus:
        return ChaveItem.pneus;
      case TipoServico.freios:
        return ChaveItem.freios;
      case TipoServico.bateria:
        return ChaveItem.bateria;
      case TipoServico.outro:
        return null;
    }
  }
}

class Manutencao {
  const Manutencao({
    this.id,
    required this.veiculoId,
    required this.tipo,
    this.descricao,
    required this.data,
    required this.km,
    required this.valorCentavos,
    this.oficina,
    this.foto,
  });

  final String? id;
  final String veiculoId;
  final TipoServico tipo;
  final String? descricao;
  final DateTime data;
  final int km;
  final int valorCentavos;
  final String? oficina;

  /// Apenas o NOME do arquivo (validado), nunca um caminho completo.
  /// No Storage a foto fica em "<id do usuário>/<nome>".
  final String? foto;

  String get titulo =>
      tipo == TipoServico.outro && descricao != null ? descricao! : tipo.rotulo;

  factory Manutencao.fromMap(Map<String, Object?> m) => Manutencao(
    id: m['id'] as String?,
    veiculoId: m['veiculo_id'] as String,
    tipo: TipoServico.values.byName(m['tipo'] as String),
    descricao: m['descricao'] as String?,
    data: isoParaData(m['data'] as String?) ?? DateTime(1970),
    km: (m['km'] as num).toInt(),
    valorCentavos: (m['valor_centavos'] as num).toInt(),
    oficina: m['oficina'] as String?,
    foto: m['foto'] as String?,
  );
}
