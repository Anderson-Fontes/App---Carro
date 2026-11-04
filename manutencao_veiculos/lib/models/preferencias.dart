/// Preferências do usuário (ficam na nuvem, valem em qualquer aparelho).
class Preferencias {
  const Preferencias({
    this.notificacoes = true,
    this.avisoDias = 30,
    this.avisoKm = 1000,
  });

  final bool notificacoes;
  final int avisoDias;
  final int avisoKm;

  static const diasPermitidos = [7, 15, 30, 60];
  static const kmPermitidos = [500, 1000, 2000, 5000];

  Preferencias copiarCom({bool? notificacoes, int? avisoDias, int? avisoKm}) =>
      Preferencias(
        notificacoes: notificacoes ?? this.notificacoes,
        avisoDias: avisoDias ?? this.avisoDias,
        avisoKm: avisoKm ?? this.avisoKm,
      );

  factory Preferencias.fromMap(Map<String, Object?> m) {
    final d = (m['aviso_dias'] as num?)?.toInt() ?? 30;
    final k = (m['aviso_km'] as num?)?.toInt() ?? 1000;
    return Preferencias(
      notificacoes: (m['notificacoes'] as bool?) ?? true,
      avisoDias: diasPermitidos.contains(d) ? d : 30,
      avisoKm: kmPermitidos.contains(k) ? k : 1000,
    );
  }
}
