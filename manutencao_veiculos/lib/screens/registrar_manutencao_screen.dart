import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/formatters.dart';
import '../core/foto_storage.dart';
import '../core/validators.dart';
import '../core/erros.dart';
import '../data/garagem_repository.dart';
import '../models/manutencao.dart';
import '../models/veiculo.dart';
import '../widgets/campo_data.dart';

class RegistrarManutencaoScreen extends StatefulWidget {
  const RegistrarManutencaoScreen({super.key, required this.veiculo});
  final Veiculo veiculo;

  @override
  State<RegistrarManutencaoScreen> createState() =>
      _RegistrarManutencaoScreenState();
}

class _RegistrarManutencaoScreenState extends State<RegistrarManutencaoScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _km;
  final _valor = TextEditingController();
  final _oficina = TextEditingController();
  final _descricao = TextEditingController();
  TipoServico _tipo = TipoServico.oleo;
  DateTime _data = DateTime.now();
  String? _fotoTemp;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _km = TextEditingController(text: widget.veiculo.km.toString());
  }

  @override
  void dispose() {
    _km.dispose();
    _valor.dispose();
    _oficina.dispose();
    _descricao.dispose();
    super.dispose();
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _escolherFoto(ImageSource origem) async {
    try {
      final x = await ImagePicker().pickImage(
        source: origem,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (x != null && mounted) setState(() => _fotoTemp = x.path);
    } catch (_) {
      _aviso('Não foi possível acessar a imagem.');
    }
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    String? nomeFoto;
    try {
      if (_fotoTemp != null) {
        nomeFoto = await FotoStorage.instance.salvar(_fotoTemp!);
      }
      final oficina = Validators.sanitizar(_oficina.text);
      final m = Manutencao(
        veiculoId: widget.veiculo.id!,
        tipo: _tipo,
        descricao: _tipo == TipoServico.outro
            ? Validators.sanitizar(_descricao.text)
            : null,
        data: soData(_data),
        km: Validators.parseKm(_km.text)!,
        valorCentavos: Validators.parseValorCentavos(_valor.text) ?? 0,
        oficina: oficina.isEmpty ? null : oficina,
        foto: nomeFoto,
      );
      final repo = GaragemRepository.padrao();
      await repo.inserirManutencao(m);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FotoInvalidaException catch (e) {
      _aviso(e.mensagem);
    } catch (e) {
      await FotoStorage.instance.remover(nomeFoto);
      _aviso(mensagemErro(e, 'Não foi possível salvar o registro.'));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar manutenção')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Tipo de serviço'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in TipoServico.values)
                  ChoiceChip(
                    label: Text(t.rotulo),
                    selected: _tipo == t,
                    onSelected: (_) => setState(() => _tipo = t),
                  ),
              ],
            ),
            if (_tipo == TipoServico.outro) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _descricao,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Descrição do serviço',
                  border: OutlineInputBorder(),
                ),
                validator: Validators.descricaoOutro,
              ),
            ],
            const SizedBox(height: 12),
            CampoData(
              rotulo: 'Data',
              valor: _data,
              primeira: DateTime(1990),
              ultima: DateTime.now(),
              onChanged: (d) {
                if (d != null) setState(() => _data = d);
              },
            ),
            TextFormField(
              controller: _km,
              keyboardType: TextInputType.number,
              maxLength: 9,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Quilometragem',
                suffixText: 'km',
                border: OutlineInputBorder(),
              ),
              validator: Validators.km,
            ),
            TextFormField(
              controller: _valor,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              maxLength: 12,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Valor',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
              ),
              validator: Validators.valor,
            ),
            TextFormField(
              controller: _oficina,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Oficina',
                border: OutlineInputBorder(),
              ),
              validator: Validators.oficina,
            ),
            const SizedBox(height: 8),
            const Text('Foto da nota fiscal'),
            const SizedBox(height: 8),
            if (_fotoTemp != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_fotoTemp!),
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Text('Prévia indisponível.'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _escolherFoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Câmera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _escolherFoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeria'),
                  ),
                ),
                if (_fotoTemp != null)
                  IconButton(
                    tooltip: 'Remover foto',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _fotoTemp = null),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Salvando...' : 'Salvar registro'),
            ),
          ],
        ),
      ),
    );
  }
}
