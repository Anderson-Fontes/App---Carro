import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manutencao_veiculos/core/sessao_segura.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sessão persiste entre instâncias e é removida no logout', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final primeira = SessaoSegura();
    await primeira.initialize();
    expect(await primeira.hasAccessToken(), isFalse);
    await primeira.persistSession('{"access_token":"token-de-teste"}');

    final segunda = SessaoSegura();
    expect(await segunda.hasAccessToken(), isTrue);
    expect(await segunda.accessToken(), '{"access_token":"token-de-teste"}');

    await segunda.removePersistedSession();
    expect(await primeira.accessToken(), isNull);
    expect(await primeira.hasAccessToken(), isFalse);
  });
}
