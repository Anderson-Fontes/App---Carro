import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/erros.dart';
import '../core/notificacao_service.dart';
import '../core/validators.dart';
import '../data/garagem_repository.dart';
import '../models/veiculo.dart';
import '../widgets/campo_data.dart';

/// Cadastro de veículo. Se [veiculo] vier preenchido, vira edição
/// (modelo, placa e ano; o tipo não muda e o km é atualizado no painel).
class VeiculoFormScreen extends StatefulWidget {
  const VeiculoFormScreen({super.key, this.veiculo});
  final Veiculo? veiculo;

  @override
  State<VeiculoFormScreen> createState() => _VeiculoFormScreenState();
}

class _VeiculoFormScreenState extends State<VeiculoFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _modelo;
  late final TextEditingController _placa;
  late final TextEditingController _ano;
  final _km = TextEditingController();
  late TipoVeiculo _tipo;
  DateTime? _ipva;
  DateTime? _seguro;
  bool _salvando = false;

  bool get _edicao => widget.veiculo != null;

  @override
  void initState() {
    super.initState();
    final v = widget.veiculo;
    _modelo = TextEditingController(text: v?.modelo ?? '');
    _placa = TextEditingController(text: v?.placa ?? '');
    _ano = TextEditingController(text: v?.ano.toString() ?? '');
    _tipo = v?.tipo ?? TipoVeiculo.carro;
  }

  @override
  void dispose() {
    _modelo.dispose();
    _placa.dispose();
    _ano.dispose();
    _km.dispose();
    super.dispose();
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final repo = GaragemRepository.padrao();
      final veiculo = Veiculo(
        id: widget.veiculo?.id,
        modelo: Validators.sanitizar(_modelo.text),
        placa: Validators.normalizarPlaca(_placa.text),
        ano: int.parse(Validators.sanitizar(_ano.text)),
        km: _edicao ? widget.veiculo!.km : Validators.parseKm(_km.text)!,
        tipo: _tipo,
      );
      if (_edicao) {
        await repo.atualizarVeiculo(veiculo);
      } else {
        await repo.inserirVeiculo(veiculo, ipva: _ipva, seguro: _seguro);
        await NotificacaoService.instance.pedirPermissao();
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on PlacaDuplicadaException catch (e) {
      _aviso(e.toString());
    } catch (e) {
      // Mensagem genérica: não expõe detalhes internos ao usuário.
      _aviso(mensagemErro(e, 'Não foi possível salvar o veículo.'));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Text(_edicao ? 'Editar veículo' : 'Adicionar veículo'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<TipoVeiculo>(
              segments: const [
                ButtonSegment(
                  value: TipoVeiculo.carro,
                  label: Text('Carro'),
                  icon: Icon(Icons.directions_car),
                ),
                ButtonSegment(
                  value: TipoVeiculo.moto,
                  label: Text('Moto'),
                  icon: Icon(Icons.two_wheeler),
                ),
              ],
              selected: {_tipo},
              // O tipo define o plano padrão; por isso não muda na edição.
              onSelectionChanged: _edicao
                  ? null
                  : (s) => setState(() => _tipo = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _modelo,
              decoration: const InputDecoration(
                labelText: 'Modelo',
                border: OutlineInputBorder(),
              ),
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              validator: Validators.modelo,
            ),
            TextFormField(
              controller: _placa,
              decoration: const InputDecoration(
                labelText: 'Placa',
                border: OutlineInputBorder(),
              ),
              maxLength: 8,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
              ],
              validator: Validators.placa,
            ),
            TextFormField(
              controller: _ano,
              decoration: const InputDecoration(
                labelText: 'Ano',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: Validators.ano,
            ),
            if (!_edicao) ...[
              TextFormField(
                controller: _km,
                decoration: const InputDecoration(
                  labelText: 'Quilometragem atual',
                  suffixText: 'km',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 9,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                validator: Validators.km,
              ),
              const SizedBox(height: 8),
              CampoData(
                rotulo: 'Vencimento do IPVA (opcional)',
                valor: _ipva,
                primeira: DateTime(hoje.year - 1),
                ultima: DateTime(hoje.year + 5),
                permiteLimpar: true,
                onChanged: (d) => setState(() => _ipva = d),
              ),
              CampoData(
                rotulo: 'Renovação do seguro (opcional)',
                valor: _seguro,
                primeira: DateTime(hoje.year - 1),
                ultima: DateTime(hoje.year + 5),
                permiteLimpar: true,
                onChanged: (d) => setState(() => _seguro = d),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(
                _salvando
                    ? 'Salvando...'
                    : (_edicao ? 'Salvar alterações' : 'Salvar veículo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
