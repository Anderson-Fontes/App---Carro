import 'package:flutter/material.dart';

import '../core/erros.dart';
import '../core/notificacao_service.dart';
import '../data/garagem_repository.dart';
import '../models/preferencias.dart';
import 'conta_screen.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  bool _carregando = true;
  Preferencias _prefs = const Preferencias();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final p = await GaragemRepository.padrao().lerPreferencias();
      if (!mounted) return;
      setState(() {
        _prefs = p;
        _carregando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvar(Preferencias novas) async {
    final anterior = _prefs;
    setState(() => _prefs = novas);
    try {
      await GaragemRepository.padrao().salvarPreferencias(novas);
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = anterior);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensagemErro(e, 'Não foi possível salvar a configuração.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_circle),
                  title: const Text('Minha conta'),
                  subtitle: const Text('E-mail, senha, sair e excluir conta'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ContaScreen(),
                    ),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alertas de manutenção'),
                  subtitle: const Text('Avisos por data e por quilometragem'),
                  value: _prefs.notificacoes,
                  onChanged: (v) => _salvar(_prefs.copiarCom(notificacoes: v)),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await NotificacaoService.instance
                        .pedirPermissao();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok ? 'Notificações permitidas.' : 'Permissão não concedida. Ative nas configurações do Android.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Permitir notificações do sistema'),
                ),
                const SizedBox(height: 24),
                const Text('Avisar com antecedência de (dias)'),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: [
                    for (final d in Preferencias.diasPermitidos)
                      ButtonSegment(value: d, label: Text('$d')),
                  ],
                  selected: {_prefs.avisoDias},
                  onSelectionChanged: (s) =>
                      _salvar(_prefs.copiarCom(avisoDias: s.first)),
                ),
                const SizedBox(height: 24),
                const Text('Avisar com antecedência de (km)'),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 500, label: Text('500')),
                    ButtonSegment(value: 1000, label: Text('1.000')),
                    ButtonSegment(value: 2000, label: Text('2.000')),
                    ButtonSegment(value: 5000, label: Text('5.000')),
                  ],
                  selected: {_prefs.avisoKm},
                  onSelectionChanged: (s) =>
                      _salvar(_prefs.copiarCom(avisoKm: s.first)),
                ),
                const SizedBox(height: 32),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Privacidade: seus dados ficam na sua conta na nuvem, '
                      'protegidos por login e por regras que impedem outros '
                      'usuários de acessá-los. As fotos das notas ficam em '
                      'área privada e só aparecem por link temporário. '
                      'Os alertas são gerados neste aparelho.',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
