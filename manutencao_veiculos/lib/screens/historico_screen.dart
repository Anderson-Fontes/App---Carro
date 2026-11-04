import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formatters.dart';
import '../core/foto_storage.dart';
import '../core/csv_export.dart';
import '../core/erros.dart';
import '../data/garagem_repository.dart';
import '../models/manutencao.dart';
import '../models/veiculo.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key, required this.veiculo});
  final Veiculo veiculo;

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  late Future<List<Manutencao>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
  }

  Future<List<Manutencao>> _carregar() async {
    final repo = GaragemRepository.padrao();
    return repo.listarManutencoes(widget.veiculo.id!);
  }

  void _recarregar() => setState(() => _futuro = _carregar());

  Future<void> _detalhes(Manutencao m) async {
    final url = await FotoStorage.instance.urlAssinada(m.foto);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.titulo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Data: ${formatData(m.data)}'),
              Text('Quilometragem: ${formatKm(m.km)}'),
              Text('Valor: ${formatReais(m.valorCentavos)}'),
              if (m.oficina != null) Text('Oficina: ${m.oficina}'),
              if (url != null) ...[
                const SizedBox(height: 12),
                Image.network(
                  url,
                  errorBuilder: (_, __, ___) =>
                      const Text('Não foi possível abrir a foto.'),
                  loadingBuilder: (c, child, p) => p == null
                      ? child
                      : const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _excluir(m);
            },
            child: const Text('Excluir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _excluir(Manutencao m) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir registro?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      final repo = GaragemRepository.padrao();
      final foto = await repo.excluirManutencao(m.id!);
      await FotoStorage.instance.remover(foto);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mensagemErro(e, 'Não foi possível excluir o registro.'),
            ),
          ),
        );
      }
    }
    if (mounted) _recarregar();
  }

  /// Copia o histórico em CSV (células protegidas contra CSV injection).
  Future<void> _exportar() async {
    try {
      final itens = await _futuro;
      await Clipboard.setData(ClipboardData(text: gerarCsv(itens)));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Histórico copiado em CSV. Cole em uma planilha.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível exportar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de serviços'),
        actions: [
          IconButton(
            tooltip: 'Copiar histórico (CSV)',
            icon: const Icon(Icons.ios_share),
            onPressed: _exportar,
          ),
        ],
      ),
      body: FutureBuilder<List<Manutencao>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                mensagemErro(
                  snap.error!,
                  'Não foi possível carregar o histórico.',
                ),
              ),
            );
          }
          final itens = snap.data!;
          if (itens.isEmpty) {
            return const Center(
              child: Text('Nenhum serviço registrado ainda.'),
            );
          }
          final total = itens.fold<int>(0, (soma, m) => soma + m.valorCentavos);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Total gasto: ${formatReais(total)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final m in itens)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _detalhes(m),
                    leading: Icon(
                      m.foto != null ? Icons.receipt_long : Icons.build,
                    ),
                    title: Text(
                      m.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${formatData(m.data)} · ${formatKm(m.km)}'
                      '${m.oficina != null ? '\n${m.oficina}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(formatReais(m.valorCentavos)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
