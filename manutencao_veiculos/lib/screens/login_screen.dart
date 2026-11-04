import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../core/validators.dart';
import 'recuperar_senha_screen.dart';

/// Entrar / Criar conta.
///
/// Segurança no cliente: validação de e-mail e política de senha, mensagens
/// genéricas de erro e bloqueio temporário após várias tentativas seguidas
/// (o Supabase também limita tentativas no servidor).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _maxFalhas = 5;
  static const Duration _bloqueio = Duration(seconds: 30);

  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirma = TextEditingController();

  bool _criando = false;
  bool _ocultar = true;
  bool _carregando = false;
  int _falhas = 0;
  DateTime? _bloqueadoAte;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    _confirma.dispose();
    super.dispose();
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _enviar() async {
    final ate = _bloqueadoAte;
    if (ate != null && DateTime.now().isBefore(ate)) {
      final s = ate.difference(DateTime.now()).inSeconds + 1;
      _aviso('Muitas tentativas. Aguarde $s s.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      if (_criando) {
        final entrou = await AuthService.instance.cadastrar(
          email: _email.text,
          senha: _senha.text,
        );
        if (!entrou && mounted) {
          setState(() {
            _criando = false;
            _senha.clear();
            _confirma.clear();
          });
          _aviso(
            'Conta criada! Enviamos um e-mail de confirmação. '
            'Confirme e depois entre.',
          );
        }
      } else {
        await AuthService.instance.entrar(
          email: _email.text,
          senha: _senha.text,
        );
        _falhas = 0;
      }
      // Ao entrar, o PortaoAutenticacao troca a tela sozinho.
    } on AuthFalha catch (e) {
      if (!_criando) {
        _falhas++;
        if (_falhas >= _maxFalhas) {
          _bloqueadoAte = DateTime.now().add(_bloqueio);
          _falhas = 0;
        }
      }
      _aviso(e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.directions_car,
                        size: 56,
                        color: tema.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Minha garagem',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _criando ? 'Crie sua conta' : 'Entre na sua conta',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLength: 254,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _senha,
                        obscureText: _ocultar,
                        autofillHints: [
                          _criando
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        maxLength: 72,
                        textInputAction: _criando
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_criando && !_carregando) _enviar();
                        },
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          border: const OutlineInputBorder(),
                          counterText: '',
                          helperText: _criando
                              ? 'Mínimo 8 caracteres, com letras e números'
                              : null,
                          suffixIcon: IconButton(
                            tooltip: _ocultar
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            icon: Icon(
                              _ocultar
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _ocultar = !_ocultar),
                          ),
                        ),
                        validator: _criando
                            ? Validators.senhaNova
                            : Validators.senhaLogin,
                      ),
                      if (_criando) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirma,
                          obscureText: _ocultar,
                          maxLength: 72,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar senha',
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                          validator: (v) => v == _senha.text
                              ? null
                              : 'As senhas não conferem.',
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _carregando ? null : _enviar,
                        child: Text(
                          _carregando
                              ? 'Aguarde...'
                              : (_criando ? 'Criar conta' : 'Entrar'),
                        ),
                      ),
                      if (!_criando)
                        TextButton(
                          onPressed: _carregando
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => RecuperarSenhaScreen(
                                      emailInicial: _email.text,
                                    ),
                                  ),
                                ),
                          child: const Text('Esqueci minha senha'),
                        ),
                      TextButton(
                        onPressed: _carregando
                            ? null
                            : () => setState(() {
                                _criando = !_criando;
                                _confirma.clear();
                              }),
                        child: Text(
                          _criando
                              ? 'Já tenho conta. Entrar'
                              : 'Não tenho conta. Criar agora',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
