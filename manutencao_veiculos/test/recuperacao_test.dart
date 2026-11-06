import 'package:flutter_test/flutter_test.dart';
import 'package:manutencao_veiculos/core/validators.dart';

void main() {
  const projeto = 'https://garagem.supabase.co';
  const token = '0123456789abcdef0123456789abcdef';
  const link = '$projeto/auth/v1/verify?token=$token&type=recovery';

  test('aceita link original do projeto e código numérico', () {
    expect(Validators.tokenRecuperacao(link, projeto), token);
    expect(Validators.codigoOuLink(link, projeto), isNull);
    expect(Validators.codigoOuLink('12345678', projeto), isNull);
  });
  test('rejeita outro projeto, HTTP, outro tipo de token e link falso', () {
    for (final invalido in [
      link.replaceFirst('garagem.supabase.co', 'outro.supabase.co'),
      link.replaceFirst('https:', 'http:'),
      link.replaceFirst('type=recovery', 'type=signup'),
      link.replaceFirst('/auth/v1/verify', '/outro'),
      link.replaceFirst('garagem.supabase.co', 'garagem.supabase.co.evil.test'),
      link.replaceFirst(token, 'curto'),
      'javascript:alert(1)',
    ]) {
      expect(Validators.codigoOuLink(invalido, projeto), isNotNull);
    }
  });
}
