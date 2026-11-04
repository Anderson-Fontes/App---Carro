import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../core/validators.dart';

/// Recuperação de senha em 2 etapas, tudo dentro do app:
///  1) informa o e-mail e recebe um CÓDIGO numérico;
///  2) digita o código e define a nova senha.
class RecuperarSenhaScreen extends StatefulWidget {
  const RecuperarSenhaScreen({super.key, this.emailInicial = ''});
  final String emailInicial;

  @override
  State<RecuperarSenhaScreen> createState() => _RecuperarSenhaScreenState();
}

class _RecuperarSenhaScreenState extends State<RecuperarSenhaScreen> {
  final _form1 = GlobalKey<FormState>();
  final _form2 = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _codigo = TextEditingController();
  final _senha = TextEditingController();
  final _confirma = TextEditingController();
  int _etapa = 1;
  bool _carregando = false;
  bool _ocultar = true;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.emailInicial);
  }

  @override
  void dispose() {
    _email.dispose();
    _codigo.dispose();
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

  Future<void> _enviarCodigo() async {
    if (!_form1.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await AuthService.instance.pedirCodigoRecuperacao(_email.text);
      if (!mounted) return;
      setState(() => _etapa = 2);
      _aviso('Se o e-mail estiver cadastrado, enviamos um código.');
    } on AuthFalha catch (e) {
      _aviso(e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _redefinir() async {
    if (!_form2.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await AuthService.instance.redefinirComCodigo(
        email: _email.text,
        codigo: _codigo.text,
        novaSenha: _senha.text,
      );
      if (!mounted) return;
      _aviso('Senha alterada com sucesso.');
      // O usuário já está autenticado: volta à raiz e o portão mostra a garagem.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthFalha catch (e) {
      _aviso(e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_etapa == 1)
              Form(
                key: _form1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Informe o e-mail da sua conta. Enviaremos um código '
                      'para você criar uma nova senha.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      maxLength: 254,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _carregando ? null : _enviarCodigo,
                      child: Text(
                        _carregando ? 'Enviando...' : 'Enviar código',
                      ),
                    ),
                  ],
                ),
              )
            else
              Form(
                key: _form2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Digite o código enviado para ${_email.text}.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _codigo,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Código',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: Validators.codigo,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _senha,
                      obscureText: _ocultar,
                      maxLength: 72,
                      decoration: InputDecoration(
                        labelText: 'Nova senha',
                        helperText: 'Mínimo 8 caracteres, com letras e números',
                        border: const OutlineInputBorder(),
                        counterText: '',
                        suffixIcon: IconButton(
                          tooltip: _ocultar ? 'Mostrar senha' : 'Ocultar senha',
                          icon: Icon(
                            _ocultar ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => _ocultar = !_ocultar),
                        ),
                      ),
                      validator: Validators.senhaNova,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirma,
                      obscureText: _ocultar,
                      maxLength: 72,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar nova senha',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: (v) =>
                          v == _senha.text ? null : 'As senhas não conferem.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _carregando ? null : _redefinir,
                      child: Text(
                        _carregando ? 'Salvando...' : 'Salvar nova senha',
                      ),
                    ),
                    TextButton(
                      onPressed: _carregando
                          ? null
                          : () => setState(() => _etapa = 1),
                      child: const Text('Reenviar código'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
