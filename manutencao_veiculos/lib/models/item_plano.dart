import '../core/formatters.dart';

/// Itens acompanhados no painel do veículo.
enum ChaveItem { oleo, pneus, freios, bateria, ipva, seguro }

extension ChaveItemX on ChaveItem {
  String get rotulo {
    switch (this) {
      case ChaveItem.oleo:
        return 'Óleo e filtro';
      case ChaveItem.pneus:
        return 'Pneus';
      case ChaveItem.freios:
        return 'Pastilhas de freio';
      case ChaveItem.bateria:
        return 'Bateria';
      case ChaveItem.ipva:
        return 'IPVA';
      case ChaveItem.seguro:
        return 'Seguro';
    }
  }

  /// IPVA e seguro vencem por data; os demais por km e/ou meses.
  bool get ehDocumento => this == ChaveItem.ipva || this == ChaveItem.seguro;
}

class ItemPlano {
  const ItemPlano({
    this.id,
    required this.veiculoId,
    required this.chave,
    this.intervaloKm,
    this.intervaloMeses,
    this.vencimento,
  });

  final String? id;
  final String veiculoId;
  final ChaveItem chave;
  final int? intervaloKm;
  final int? intervaloMeses;
  final DateTime? vencimento;

  factory ItemPlano.fromMap(Map<String, Object?> m) => ItemPlano(
    id: m['id'] as String?,
    veiculoId: m['veiculo_id'] as String,
    chave: ChaveItem.values.byName(m['chave'] as String),
    intervaloKm: (m['intervalo_km'] as num?)?.toInt(),
    intervaloMeses: (m['intervalo_meses'] as num?)?.toInt(),
    vencimento: isoParaData(m['vencimento'] as String?),
  );
}
