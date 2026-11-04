import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../core/validators.dart';

/// Dados da conta: e-mail, trocar senha, sair e excluir conta.
class ContaScreen extends StatefulWidget {
  const ContaScreen({super.key});

  @override
  State<ContaScreen> createState() => _ContaScreenState();
}

class _ContaScreenState extends State<ContaScreen> {
  bool _ocupado = false;

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _alterarSenha() async {
    final r = await showDialog<({String atual, String nova})>(
      context: context,
      builder: (_) => const _AlterarSenhaDialog(),
    );
    if (r == null) return;
    setState(() => _ocupado = true);
    try {
      await AuthService.instance.alterarSenha(atual: r.atual, nova: r.nova);
      _aviso('Senha alterada com sucesso.');
    } on AuthFalha catch (e) {
      _aviso(e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _sair() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você precisará entrar novamente. Seus dados continuam salvos na nuvem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _ocupado = true);
    try {
      await AuthService.instance.sair();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (_) {
      _aviso('Não foi possível sair. Tente novamente.');
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _excluirConta() async {
    final senha = await showDialog<String>(
      context: context,
      builder: (_) => const _ExcluirContaDialog(),
    );
    if (senha == null) return;
    setState(() => _ocupado = true);
    try {
      await AuthService.instance.excluirConta(senha: senha);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthFalha catch (e) {
      _aviso(e.mensagem);
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.usuario?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Minha conta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person),
            title: const Text('E-mail'),
            subtitle: Text(email),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_reset),
            title: const Text('Alterar senha'),
            enabled: !_ocupado,
            onTap: _alterarSenha,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            enabled: !_ocupado,
            onTap: _sair,
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_forever,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Excluir minha conta',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Apaga veículos, histórico e fotos'),
            enabled: !_ocupado,
            onTap: _excluirConta,
          ),
          if (_ocupado)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _AlterarSenhaDialog extends StatefulWidget {
  const _AlterarSenhaDialog();

  @override
  State<_AlterarSenhaDialog> createState() => _AlterarSenhaDialogState();
}

class _AlterarSenhaDialogState extends State<_AlterarSenhaDialog> {
  final _form = GlobalKey<FormState>();
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirma = TextEditingController();

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    _confirma.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alterar senha'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _atual,
                obscureText: true,
                maxLength: 72,
                decoration: const InputDecoration(
                  labelText: 'Senha atual',
                  counterText: '',
                ),
                validator: Validators.senhaLogin,
              ),
              TextFormField(
                controller: _nova,
                obscureText: true,
                maxLength: 72,
                decoration: const InputDecoration(
                  labelText: 'Nova senha',
                  counterText: '',
                ),
                validator: Validators.senhaNova,
              ),
              TextFormField(
                controller: _confirma,
                obscureText: true,
                maxLength: 72,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nova senha',
                  counterText: '',
                ),
                validator: (v) =>
                    v == _nova.text ? null : 'As senhas não conferem.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, (atual: _atual.text, nova: _nova.text));
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ExcluirContaDialog extends StatefulWidget {
  const _ExcluirContaDialog();

  @override
  State<_ExcluirContaDialog> createState() => _ExcluirContaDialogState();
}

class _ExcluirContaDialogState extends State<_ExcluirContaDialog> {
  final _form = GlobalKey<FormState>();
  final _senha = TextEditingController();

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Excluir conta?'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Todos os seus veículos, o histórico e as fotos das notas serão '
              'apagados para sempre. Esta ação não pode ser desfeita.',
            ),
            TextFormField(
              controller: _senha,
              obscureText: true,
              maxLength: 72,
              decoration: const InputDecoration(
                labelText: 'Digite sua senha para confirmar',
                counterText: '',
              ),
              validator: Validators.senhaLogin,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, _senha.text);
            }
          },
          child: const Text('Excluir tudo'),
        ),
      ],
    );
  }
}
