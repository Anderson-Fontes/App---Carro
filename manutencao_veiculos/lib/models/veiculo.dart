enum TipoVeiculo { carro, moto }

class Veiculo {
  const Veiculo({
    this.id,
    required this.modelo,
    required this.placa,
    required this.ano,
    required this.km,
    required this.tipo,
  });

  /// UUID gerado pelo banco na nuvem (null enquanto não foi salvo).
  final String? id;
  final String modelo;
  final String placa;
  final int ano;
  final int km;
  final TipoVeiculo tipo;

  factory Veiculo.fromMap(Map<String, Object?> m) => Veiculo(
    id: m['id'] as String?,
    modelo: m['modelo'] as String,
    placa: m['placa'] as String,
    ano: (m['ano'] as num).toInt(),
    km: (m['km'] as num).toInt(),
    tipo: TipoVeiculo.values.byName(m['tipo'] as String),
  );
}
