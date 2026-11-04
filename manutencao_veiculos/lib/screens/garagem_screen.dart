import 'package:flutter/material.dart';

import '../core/erros.dart';
import '../core/formatters.dart';
import '../core/garagem_service.dart';
import '../core/notificacao_service.dart';
import '../core/status_calculator.dart';
import '../core/status_ui.dart';
import '../data/garagem_repository.dart';
import '../models/veiculo.dart';
import 'configuracoes_screen.dart';
import 'painel_screen.dart';
import 'veiculo_form_screen.dart';

class _Linha {
  const _Linha(this.veiculo, this.situacoes);
  final Veiculo veiculo;
  final List<SituacaoItem> situacoes;
}

class GaragemScreen extends StatefulWidget {
  const GaragemScreen({super.key});

  @override
  State<GaragemScreen> createState() => _GaragemScreenState();
}

class _GaragemScreenState extends State<GaragemScreen> {
  late Future<List<_Linha>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
  }

  Future<List<_Linha>> _carregar() async {
    final repo = GaragemRepository.padrao();
    final servico = GaragemService(repo);
    final (veiculos, prefs) = await (
      repo.listarVeiculos(),
      repo.lerPreferencias(),
    ).wait;
    // Cada veículo é avaliado em paralelo; alertas são "melhor esforço".
    return Future.wait(
      veiculos.map((v) async {
        final s = await servico.avaliar(v, prefs);
        try {
          await servico.alertar(v, s, NotificacaoService.instance, prefs);
        } catch (_) {}
        return _Linha(v, s);
      }),
    );
  }

  void _recarregar() => setState(() => _futuro = _carregar());

  Future<void> _atualizar() async {
    final f = _carregar();
    setState(() => _futuro = f);
    try {
      await f;
    } catch (_) {}
  }

  Future<void> _abrir(Widget tela) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => tela));
    if (mounted) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha garagem'),
        actions: [
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings),
            onPressed: () => _abrir(const ConfiguracoesScreen()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(const VeiculoFormScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar veículo'),
      ),
      body: FutureBuilder<List<_Linha>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mensagemErro(
                        snap.error!,
                        'Não foi possível carregar a garagem.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _recarregar,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          final linhas = snap.data!;
          if (linhas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum veículo ainda.\nToque em "Adicionar veículo" para começar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final pendencias = linhas
              .where((l) => GaragemService.temPendencia(l.situacoes))
              .length;
          return RefreshIndicator(
            onRefresh: _atualizar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${linhas.length} veículo${linhas.length == 1 ? '' : 's'} · '
                    '$pendencias pendência${pendencias == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                for (final l in linhas) _cartao(l),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cartao(_Linha l) {
    final v = l.veiculo;
    final pior = GaragemService.pior(l.situacoes);
    final cor = pior?.status.cor ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _abrir(PainelScreen(veiculoId: v.id!)),
        leading: Icon(
          v.tipo == TipoVeiculo.moto ? Icons.two_wheeler : Icons.directions_car,
        ),
        title: Text(
          '${v.modelo} ${v.ano}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${v.placa} · ${formatKm(v.km)}'),
            Text(
              GaragemService.resumo(l.situacoes),
              style: TextStyle(color: cor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
