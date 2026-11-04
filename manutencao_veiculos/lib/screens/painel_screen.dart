import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formatters.dart';
import '../core/foto_storage.dart';
import '../core/garagem_service.dart';
import '../core/notificacao_service.dart';
import '../core/status_calculator.dart';
import '../core/status_ui.dart';
import '../core/validators.dart';
import '../core/erros.dart';
import '../data/garagem_repository.dart';
import '../models/item_plano.dart';
import '../models/veiculo.dart';
import '../widgets/item_card.dart';
import 'historico_screen.dart';
import 'registrar_manutencao_screen.dart';
import 'veiculo_form_screen.dart';

class PainelScreen extends StatefulWidget {
  const PainelScreen({super.key, required this.veiculoId});
  final String veiculoId;

  @override
  State<PainelScreen> createState() => _PainelScreenState();
}

class _PainelScreenState extends State<PainelScreen> {
  Veiculo? _veiculo;
  List<SituacaoItem> _situacoes = const [];
  bool _carregando = true;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final repo = GaragemRepository.padrao();
      final v = await repo.buscarVeiculo(widget.veiculoId);
      if (v == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final servico = GaragemService(repo);
      final prefs = await repo.lerPreferencias();
      final s = await servico.avaliar(v, prefs);
      try {
        await servico.alertar(v, s, NotificacaoService.instance, prefs);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _veiculo = v;
        _situacoes = s;
        _carregando = false;
        _erro = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = true;
          _carregando = false;
        });
      }
    }
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _atualizarKm() async {
    final v = _veiculo!;
    final novo = await showDialog<int>(
      context: context,
      builder: (_) => _KmDialog(kmAtual: v.km),
    );
    if (novo == null) return;
    try {
      final repo = GaragemRepository.padrao();
      final ok = await repo.atualizarKm(v.id!, novo);
      if (!ok) _aviso('A quilometragem não pode diminuir.');
    } catch (e) {
      _aviso(mensagemErro(e, 'Não foi possível atualizar a quilometragem.'));
    }
    await _carregar();
  }

  Future<void> _editarVencimento(SituacaoItem s) async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: hoje,
      firstDate: DateTime(hoje.year - 1),
      lastDate: DateTime(hoje.year + 5),
      helpText: 'Vencimento: ${s.chave.rotulo}',
    );
    if (d == null) return;
    try {
      final repo = GaragemRepository.padrao();
      await repo.definirVencimento(widget.veiculoId, s.chave, d);
    } catch (e) {
      _aviso(mensagemErro(e, 'Não foi possível salvar a data.'));
    }
    await _carregar();
  }

  Future<void> _editarVeiculo() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VeiculoFormScreen(veiculo: _veiculo),
      ),
    );
    if (mounted) await _carregar();
  }

  Future<void> _editarIntervalo(SituacaoItem s) async {
    final item = s.item;
    if (item == null) return;
    final r = await showDialog<_Intervalo>(
      context: context,
      builder: (_) => _IntervaloDialog(titulo: s.chave.rotulo, item: item),
    );
    if (r == null) return;
    try {
      await GaragemRepository.padrao().atualizarIntervalo(
        widget.veiculoId,
        s.chave,
        km: r.km,
        meses: r.meses,
      );
    } catch (e) {
      _aviso(mensagemErro(e, 'Não foi possível salvar o intervalo.'));
    }
    await _carregar();
  }

  Future<void> _registrar() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegistrarManutencaoScreen(veiculo: _veiculo!),
      ),
    );
    if (mounted) await _carregar();
  }

  Future<void> _historico() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoricoScreen(veiculo: _veiculo!),
      ),
    );
    if (mounted) await _carregar();
  }

  Future<void> _excluir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir veículo?'),
        content: const Text(
          'O histórico e as fotos das notas deste veículo também serão apagados.',
        ),
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
      final fotos = await repo.excluirVeiculo(widget.veiculoId);
      await FotoStorage.instance.removerVarios(fotos);
      await GaragemService(repo)
          .cancelarAlertas(widget.veiculoId, NotificacaoService.instance);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _aviso(mensagemErro(e, 'Não foi possível excluir o veículo.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _veiculo;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          v == null ? 'Veículo' : '${v.modelo} ${v.ano}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (v != null) ...[
            IconButton(
              tooltip: 'Histórico',
              icon: const Icon(Icons.history),
              onPressed: _historico,
            ),
            IconButton(
              tooltip: 'Editar veículo',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editarVeiculo,
            ),
            IconButton(
              tooltip: 'Excluir veículo',
              icon: const Icon(Icons.delete_outline),
              onPressed: _excluir,
            ),
          ],
        ],
      ),
      floatingActionButton: v == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _registrar,
              icon: const Icon(Icons.build),
              label: const Text('Registrar manutenção'),
            ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : (_erro || v == null)
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar o veículo.'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () {
                      setState(() => _carregando = true);
                      _carregar();
                    },
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            )
          : _conteudo(v),
    );
  }

  Widget _conteudo(Veiculo v) {
    int conta(Status s) => _situacoes.where((i) => i.status == s).length;
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(v.placa, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quilometragem atual'),
                        Text(
                          formatKm(v.km),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _atualizarKm,
                    child: const Text('Atualizar km'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _contador(conta(Status.atrasado), 'atrasado', Status.atrasado),
              _contador(
                conta(Status.venceLogo),
                'vence logo',
                Status.venceLogo,
              ),
              _contador(conta(Status.emDia), 'em dia', Status.emDia),
            ],
          ),
          const SizedBox(height: 8),
          for (final s in _situacoes)
            ItemCard(
              situacao: s,
              iconeAcao: s.chave.ehDocumento ? Icons.edit_calendar : Icons.tune,
              onTap: () => s.chave.ehDocumento
                  ? _editarVencimento(s)
                  : _editarIntervalo(s),
            ),
        ],
      ),
    );
  }

  Widget _contador(int n, String rotulo, Status status) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                '$n',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: status.cor,
                ),
              ),
              Text(rotulo),
            ],
          ),
        ),
      ),
    );
  }
}

class _KmDialog extends StatefulWidget {
  const _KmDialog({required this.kmAtual});
  final int kmAtual;

  @override
  State<_KmDialog> createState() => _KmDialogState();
}

class _KmDialogState extends State<_KmDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.kmAtual.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Atualizar quilometragem'),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Quilometragem atual',
            suffixText: 'km',
          ),
          validator: (t) {
            final n = Validators.parseKm(t);
            if (n == null) return 'Valor inválido.';
            if (n < widget.kmAtual) {
              return 'Não pode ser menor que ${formatKm(widget.kmAtual)}.';
            }
            return null;
          },
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
              Navigator.pop(context, Validators.parseKm(_ctrl.text));
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _Intervalo {
  const _Intervalo(this.km, this.meses);
  final int? km;
  final int? meses;
}

/// Edita o intervalo de manutenção (km e/ou meses; vale o que vencer primeiro).
class _IntervaloDialog extends StatefulWidget {
  const _IntervaloDialog({required this.titulo, required this.item});
  final String titulo;
  final ItemPlano item;

  @override
  State<_IntervaloDialog> createState() => _IntervaloDialogState();
}

class _IntervaloDialogState extends State<_IntervaloDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _km;
  late final TextEditingController _meses;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _km = TextEditingController(
      text: widget.item.intervaloKm?.toString() ?? '',
    );
    _meses = TextEditingController(
      text: widget.item.intervaloMeses?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _km.dispose();
    _meses.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Intervalo: ${widget.titulo}'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vale o que vencer primeiro. Preencha um ou os dois.'),
            TextFormField(
              controller: _km,
              keyboardType: TextInputType.number,
              maxLength: 7,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'A cada (km)',
                counterText: '',
              ),
              validator: Validators.intervaloKm,
            ),
            TextFormField(
              controller: _meses,
              keyboardType: TextInputType.number,
              maxLength: 3,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'A cada (meses)',
                counterText: '',
              ),
              validator: Validators.intervaloMeses,
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final km = Validators.lerIntervaloKm(_km.text);
            final meses = Validators.lerIntervaloMeses(_meses.text);
            if (km == null && meses == null) {
              setState(() => _erro = 'Informe km, meses ou os dois.');
              return;
            }
            Navigator.pop(context, _Intervalo(km, meses));
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
