import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class FotoInvalidaException implements Exception {
  const FotoInvalidaException(this.mensagem);
  final String mensagem;
}

/// Fotos das notas fiscais no Supabase Storage (bucket PRIVADO "notas").
///
/// Segurança:
///  - nome do arquivo gerado por nós (aleatório), nunca o nome vindo do
///    usuário (evita path traversal, ex.: "../../outra-pessoa/nota.jpg");
///  - caminho no bucket = "<id do usuário>/<nome>"; a política do Storage só
///    deixa cada um mexer na PRÓPRIA pasta;
///  - tipo verificado pelo conteúdo (bytes iniciais), não pela extensão;
///  - limite de 5 MB (no app e no bucket);
///  - bucket privado: a foto só é exibida por link assinado que expira em
///    60 segundos;
///  - no banco vai só o nome do arquivo, revalidado antes de usar.
class FotoStorage {
  FotoStorage._();
  static final FotoStorage instance = FotoStorage._();

  static const String bucket = 'notas';
  static const int tamanhoMaximo = 5 * 1024 * 1024;
  static final RegExp _nomeValido = RegExp(r'^[a-f0-9]{32}\.(jpg|png)$');

  StorageFileApi get _api => Supabase.instance.client.storage.from(bucket);

  String _uid() {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) {
      throw const FotoInvalidaException('Sessão expirada. Entre novamente.');
    }
    return u.id;
  }

  /// Envia a imagem escolhida e devolve o NOME do arquivo.
  Future<String> salvar(String origem) async {
    final arquivo = File(origem);
    if (!await arquivo.exists()) {
      throw const FotoInvalidaException('Imagem não encontrada.');
    }
    if (await arquivo.length() > tamanhoMaximo) {
      throw const FotoInvalidaException('A imagem deve ter no máximo 5 MB.');
    }
    final bytes = await arquivo.readAsBytes();
    final ext = _extensaoPeloConteudo(bytes);
    if (ext == null) {
      throw const FotoInvalidaException('Use uma imagem JPEG ou PNG.');
    }
    final nome = '${_nomeAleatorio()}.$ext';
    await _api.uploadBinary(
      '${_uid()}/$nome',
      bytes,
      fileOptions: FileOptions(
        contentType: ext == 'jpg' ? 'image/jpeg' : 'image/png',
        upsert: false,
      ),
    );
    return nome;
  }

  /// Link temporário (60 s) para exibir a foto, ou null se não existir.
  Future<String?> urlAssinada(String? nome) async {
    if (nome == null || !_nomeValido.hasMatch(nome)) return null;
    try {
      return await _api.createSignedUrl('${_uid()}/$nome', 60);
    } catch (_) {
      return null;
    }
  }

  Future<void> remover(String? nome) =>
      removerVarios(nome == null ? const <String>[] : [nome]);

  Future<void> removerVarios(Iterable<String> nomes) async {
    try {
      final uid = _uid();
      final caminhos = nomes
          .where(_nomeValido.hasMatch)
          .map((n) => '$uid/$n')
          .toList();
      if (caminhos.isNotEmpty) await _api.remove(caminhos);
    } catch (_) {
      // Melhor esforço: sobra de arquivo não deve travar a tela.
    }
  }

  /// Apaga todas as fotos do usuário (usado ao excluir a conta).
  Future<void> removerTodas() async {
    final uid = _uid();
    // Sempre lê a primeira página: os arquivos removidos saem da listagem.
    // Uma falha deve interromper a exclusão da conta, permitindo tentar de novo.
    while (true) {
      final itens = await _api.list(path: uid);
      if (itens.isEmpty) return;
      await _api.remove(itens.map((f) => '$uid/${f.name}').toList());
    }
  }

  String? _extensaoPeloConteudo(List<int> b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return 'jpg';
    }
    if (b.length >= 4 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47) {
      return 'png';
    }
    return null;
  }

  String _nomeAleatorio() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
