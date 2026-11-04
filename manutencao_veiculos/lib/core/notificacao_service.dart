import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notificações locais (nada sai do aparelho).
///
/// Os textos NUNCA incluem a placa: notificações aparecem na tela bloqueada.
/// Falhas aqui não podem derrubar o app, por isso tudo é "melhor esforço".
class NotificacaoService {
  NotificacaoService._();
  static final NotificacaoService instance = NotificacaoService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _pronto = false;

  static const NotificationDetails _detalhes = NotificationDetails(
    android: AndroidNotificationDetails(
      'manutencao',
      'Alertas de manutenção',
      channelDescription: 'Avisos de manutenção, IPVA e seguro',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      // App voltado ao Brasil; se quiser suportar outros fusos, use o pacote
      // flutter_timezone para descobrir o fuso do aparelho.
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      const config = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(config);
      _pronto = true;
    } catch (_) {
      _pronto = false;
    }
  }

  Future<bool> pedirPermissao() async {
    if (!_pronto) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> mostrar({
    required int id,
    required String titulo,
    required String corpo,
  }) async {
    if (!_pronto) return;
    try {
      await _plugin.show(id, titulo, corpo, _detalhes);
    } catch (_) {}
  }

  Future<void> agendar({
    required int id,
    required String titulo,
    required String corpo,
    required DateTime quando,
  }) async {
    if (!_pronto) return;
    try {
      await _plugin.zonedSchedule(
        id,
        titulo,
        corpo,
        tz.TZDateTime.from(quando, tz.local),
        _detalhes,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  Future<void> cancelar(int id) async {
    if (!_pronto) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  /// Cancela tudo (usado ao sair da conta, para não sobrar alerta de outro usuário).
  Future<void> cancelarTodas() async {
    if (!_pronto) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
