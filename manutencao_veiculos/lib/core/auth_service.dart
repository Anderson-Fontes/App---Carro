import 'package:supabase_flutter/supabase_flutter.dart';

import 'alerta_estado.dart';
import 'erros.dart';
import 'foto_storage.dart';
import 'notificacao_service.dart';
import 'validators.dart';

/// Falha de autenticação com mensagem JÁ pronta para mostrar ao usuário.
class AuthFalha implements Exception {
  const AuthFalha(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

/// Único ponto de contato do app com o login (Supabase Auth).
///
/// Segurança:
///  - mensagens genéricas: "e-mail ou senha incorretos" (não diz qual errou);
///  - recuperação de senha responde igual exista ou não o e-mail
///    (evita descobrir quem tem conta);
///  - trocar a senha e excluir a conta exigem a senha atual;
///  - ao sair, notificações e controle de alertas do aparelho são limpos.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  GoTrueClient get _auth => Supabase.instance.client.auth;

  Stream<AuthState> get mudancas => _auth.onAuthStateChange;
  User? get usuario => _auth.currentUser;

  Future<void> entrar({required String email, required String senha}) async {
    try {
      await _auth.signInWithPassword(
        email: Validators.normalizarEmail(email),
        password: senha,
      );
    } on AuthException catch (e) {
      throw AuthFalha(
        _traduzir(e, 'Não foi possível entrar. Tente novamente.'),
      );
    } catch (e) {
      throw AuthFalha(
        mensagemErro(e, 'Não foi possível entrar. Tente novamente.'),
      );
    }
  }

  /// Devolve true se já entrou (confirmação de e-mail desligada) ou false se
  /// o usuário precisa confirmar o e-mail antes de entrar.
  Future<bool> cadastrar({required String email, required String senha}) async {
    try {
      final r = await _auth.signUp(
        email: Validators.normalizarEmail(email),
        password: senha,
      );
      return r.session != null;
    } on AuthException catch (e) {
      throw AuthFalha(
        _traduzir(
          e,
          'Não foi possível criar a conta. Se você já tem cadastro, entre ou recupere a senha.',
        ),
      );
    } catch (e) {
      throw AuthFalha(mensagemErro(e, 'Não foi possível criar a conta.'));
    }
  }

  /// Envia o código de recuperação por e-mail. Não revela se o e-mail existe.
  Future<void> pedirCodigoRecuperacao(String email) async {
    try {
      await _auth.resetPasswordForEmail(Validators.normalizarEmail(email));
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('rate limit') || e.statusCode == '429') {
        throw const AuthFalha('Muitas tentativas. Aguarde alguns minutos.');
      }
      // Qualquer outro erro: mesma resposta de sucesso (não revela a conta).
    } catch (e) {
      throw AuthFalha(mensagemErro(e, 'Não foi possível enviar o código.'));
    }
  }

  Future<void> redefinirComCodigo({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    try {
      await _auth.verifyOTP(
        email: Validators.normalizarEmail(email),
        token: Validators.sanitizar(codigo),
        type: OtpType.recovery,
      );
      await _auth.updateUser(UserAttributes(password: novaSenha));
    } on AuthException catch (e) {
      throw AuthFalha(_traduzir(e, 'Não foi possível redefinir a senha.'));
    } catch (e) {
      throw AuthFalha(mensagemErro(e, 'Não foi possível redefinir a senha.'));
    }
  }

  Future<void> alterarSenha({
    required String atual,
    required String nova,
  }) async {
    final email = usuario?.email;
    if (email == null)
      throw const AuthFalha('Sessão expirada. Entre novamente.');
    try {
      await _auth.signInWithPassword(email: email, password: atual);
      await _auth.updateUser(UserAttributes(password: nova));
    } on AuthException catch (e) {
      throw AuthFalha(_traduzir(e, 'Não foi possível alterar a senha.'));
    } catch (e) {
      throw AuthFalha(mensagemErro(e, 'Não foi possível alterar a senha.'));
    }
  }

  Future<void> sair() async {
    await _limparLocal();
    await _auth.signOut();
  }

  /// Apaga TODOS os dados do usuário (fotos, registros e a própria conta).
  Future<void> excluirConta({required String senha}) async {
    final email = usuario?.email;
    if (email == null)
      throw const AuthFalha('Sessão expirada. Entre novamente.');
    try {
      await _auth.signInWithPassword(email: email, password: senha);
      await FotoStorage.instance.removerTodas();
      await Supabase.instance.client.rpc('excluir_minha_conta');
    } on AuthException catch (e) {
      throw AuthFalha(_traduzir(e, 'Não foi possível excluir a conta.'));
    } catch (e) {
      throw AuthFalha(mensagemErro(e, 'Não foi possível excluir a conta.'));
    }
    await _limparLocal();
    try {
      await _auth.signOut();
    } catch (_) {
      // A conta já não existe; o logout remoto pode falhar sem problema.
    }
  }

  Future<void> _limparLocal() async {
    try {
      await NotificacaoService.instance.cancelarTodas();
      await AlertaEstado.instance.limpar();
    } catch (_) {}
  }

  String _traduzir(AuthException e, String padrao) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (m.contains('not confirmed')) {
      return 'Confirme seu e-mail pelo link que enviamos antes de entrar.';
    }
    if (m.contains('rate limit') || e.statusCode == '429') {
      return 'Muitas tentativas. Aguarde alguns minutos.';
    }
    if (m.contains('token') || m.contains('expired') || m.contains('otp')) {
      return 'Código inválido ou expirado.';
    }
    if (m.contains('weak') || m.contains('password')) {
      return 'Senha fraca. Use 8 ou mais caracteres, com letras e números.';
    }
    return padrao;
  }
}
