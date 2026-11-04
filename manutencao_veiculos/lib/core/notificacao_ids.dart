import '../models/item_plano.dart';

/// Hash FNV-1a de 32 bits (estável entre execuções, ao contrário de hashCode).
int _fnv1a(String s) {
  var h = 0x811C9DC5;
  for (final u in s.codeUnits) {
    h ^= u;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// Os veículos agora têm UUID (texto), mas o Android exige id de notificação
/// inteiro de 32 bits. Derivamos um id estável a partir do UUID + item.
/// Resultado máximo ~805 milhões, abaixo do limite de 2.147.483.647.
int idNotificacao(String veiculoId, ChaveItem chave, {bool imediato = false}) {
  final base =
      (_fnv1a(veiculoId) & 0x3FFFFFF) * ChaveItem.values.length + chave.index;
  return base * 2 + (imediato ? 1 : 0);
}
