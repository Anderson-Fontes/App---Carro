import 'package:shared_preferences/shared_preferences.dart';

/// Guarda, NESTE aparelho, o último status avisado de cada item
/// (para não repetir a mesma notificação). Notificações são locais,
/// então esse controle também é local e não precisa ir para a nuvem.
class AlertaEstado {
  AlertaEstado._();
  static final AlertaEstado instance = AlertaEstado._();

  static const String prefixo = 'alerta_';

  Future<String?> ler(String chave) async =>
      (await SharedPreferences.getInstance()).getString(chave);

  Future<void> salvar(String chave, String valor) async {
    await (await SharedPreferences.getInstance()).setString(chave, valor);
  }

  /// Apaga o controle de alertas (usado ao sair da conta).
  Future<void> limpar() async {
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith(prefixo)).toList()) {
      await p.remove(k);
    }
  }
}
