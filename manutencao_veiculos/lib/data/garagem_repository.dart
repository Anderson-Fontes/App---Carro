import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/formatters.dart';
import '../models/item_plano.dart';
import '../models/manutencao.dart';
import '../models/preferencias.dart';
import '../models/veiculo.dart';

class PlacaDuplicadaException implements Exception {
  const PlacaDuplicadaException();
  @override
  String toString() => 'Você já cadastrou um veículo com esta placa.';
}

/// ÚNICA porta de acesso aos dados (Supabase / PostgreSQL na nuvem).
///
/// SEGURANÇA:
///  - SQL injection: o app NÃO monta SQL. O supabase_flutter fala com a API
///    PostgREST, que envia os valores como parâmetros; as funções SQL
///    (rpc) também recebem parâmetros tipados. Nenhum texto do usuário é
///    concatenado em consulta.
///  - Isolamento entre usuários: a RLS do banco filtra tudo por
///    user_id = auth.uid(). Mesmo que o app tivesse um bug, o banco recusaria.
///  - Integridade: CHECK constraints e triggers no banco (supabase/schema.sql).
class GaragemRepository {
  GaragemRepository(this._c);
  factory GaragemRepository.padrao() =>
      GaragemRepository(Supabase.instance.client);

  final SupabaseClient _c;

  static const String _codigoDuplicado = '23505';

  String get _uid {
    final u = _c.auth.currentUser;
    if (u == null) throw StateError('Sessão expirada.');
    return u.id;
  }

  // ---------------------------------------------------------------- Veículos

  /// Cria o veículo e o plano padrão de manutenção numa única operação atômica.
  Future<String> inserirVeiculo(
    Veiculo v, {
    DateTime? ipva,
    DateTime? seguro,
  }) async {
    try {
      final id = await _c.rpc(
        'criar_veiculo',
        params: {
          'p_modelo': v.modelo,
          'p_placa': v.placa,
          'p_ano': v.ano,
          'p_km': v.km,
          'p_tipo': v.tipo.name,
          'p_ipva': ipva == null ? null : dataParaIso(ipva),
          'p_seguro': seguro == null ? null : dataParaIso(seguro),
        },
      );
      return id as String;
    } on PostgrestException catch (e) {
      if (e.code == _codigoDuplicado) throw const PlacaDuplicadaException();
      rethrow;
    }
  }

  Future<List<Veiculo>> listarVeiculos() async {
    final rows = await _c.from('veiculos').select();
    final lista = rows.map<Veiculo>(Veiculo.fromMap).toList();
    lista.sort(
      (a, b) => a.modelo.toLowerCase().compareTo(b.modelo.toLowerCase()),
    );
    return lista;
  }

  Future<Veiculo?> buscarVeiculo(String id) async {
    final r = await _c.from('veiculos').select().eq('id', id).maybeSingle();
    return r == null ? null : Veiculo.fromMap(r);
  }

  /// Edita modelo, placa e ano (tipo e km têm regras próprias).
  Future<void> atualizarVeiculo(Veiculo v) async {
    try {
      await _c
          .from('veiculos')
          .update({'modelo': v.modelo, 'placa': v.placa, 'ano': v.ano})
          .eq('id', v.id!);
    } on PostgrestException catch (e) {
      if (e.code == _codigoDuplicado) throw const PlacaDuplicadaException();
      rethrow;
    }
  }

  /// A quilometragem nunca diminui: o filtro .lte e o trigger do banco recusam.
  Future<bool> atualizarKm(String id, int km) async {
    final rows = await _c
        .from('veiculos')
        .update({'km': km})
        .eq('id', id)
        .lte('km', km)
        .select('id');
    return rows.isNotEmpty;
  }

  /// Exclui o veículo (e, em cascata, itens e manutenções).
  /// Devolve os nomes das fotos para o chamador apagar do Storage.
  Future<List<String>> excluirVeiculo(String id) async {
    final fotos = await _c
        .from('manutencoes')
        .select('foto')
        .eq('veiculo_id', id)
        .not('foto', 'is', null);
    await _c.from('veiculos').delete().eq('id', id);
    return fotos.map((r) => r['foto'] as String).toList();
  }

  // ------------------------------------------------------------------- Plano

  Future<List<ItemPlano>> listarItens(String veiculoId) async {
    final rows = await _c
        .from('itens_plano')
        .select()
        .eq('veiculo_id', veiculoId)
        .order('chave');
    final itens = rows.map<ItemPlano>(ItemPlano.fromMap).toList();
    // Mantém a ordem do painel (óleo, pneus, freios, bateria, IPVA, seguro).
    itens.sort((a, b) => a.chave.index.compareTo(b.chave.index));
    return itens;
  }

  Future<void> definirVencimento(
    String veiculoId,
    ChaveItem chave,
    DateTime? data,
  ) async {
    await _c
        .from('itens_plano')
        .update({'vencimento': data == null ? null : dataParaIso(data)})
        .eq('veiculo_id', veiculoId)
        .eq('chave', chave.name);
  }

  Future<void> atualizarIntervalo(
    String veiculoId,
    ChaveItem chave, {
    int? km,
    int? meses,
  }) async {
    await _c
        .from('itens_plano')
        .update({'intervalo_km': km, 'intervalo_meses': meses})
        .eq('veiculo_id', veiculoId)
        .eq('chave', chave.name);
  }

  // ------------------------------------------------------------- Manutenções

  /// Registra o serviço e, se o km for maior que o atual, atualiza o veículo
  /// (tudo na mesma operação atômica do banco).
  Future<String> inserirManutencao(Manutencao m) async {
    final id = await _c.rpc(
      'registrar_manutencao',
      params: {
        'p_veiculo_id': m.veiculoId,
        'p_tipo': m.tipo.name,
        'p_descricao': m.descricao,
        'p_data': dataParaIso(m.data),
        'p_km': m.km,
        'p_valor_centavos': m.valorCentavos,
        'p_oficina': m.oficina,
        'p_foto': m.foto,
      },
    );
    return id as String;
  }

  /// Última manutenção de cada tipo (view "ultimas_manutencoes").
  Future<Map<TipoServico, Manutencao>> ultimasManutencoes(
    String veiculoId,
  ) async {
    final rows = await _c
        .from('ultimas_manutencoes')
        .select()
        .eq('veiculo_id', veiculoId);
    final mapa = <TipoServico, Manutencao>{};
    for (final r in rows) {
      final m = Manutencao.fromMap(r);
      mapa[m.tipo] = m;
    }
    return mapa;
  }

  Future<List<Manutencao>> listarManutencoes(String veiculoId) async {
    final rows = await _c
        .from('manutencoes')
        .select()
        .eq('veiculo_id', veiculoId)
        .order('data', ascending: false)
        .order('criado_em', ascending: false);
    return rows.map<Manutencao>(Manutencao.fromMap).toList();
  }

  /// Devolve o nome da foto (se houver) para o chamador apagar do Storage.
  Future<String?> excluirManutencao(String id) async {
    final r = await _c
        .from('manutencoes')
        .select('foto')
        .eq('id', id)
        .maybeSingle();
    await _c.from('manutencoes').delete().eq('id', id);
    return r?['foto'] as String?;
  }

  // ----------------------------------------------------------- Preferências

  Future<Preferencias> lerPreferencias() async {
    final r = await _c
        .from('configuracoes')
        .select()
        .eq('user_id', _uid)
        .maybeSingle();
    return r == null ? const Preferencias() : Preferencias.fromMap(r);
  }

  Future<void> salvarPreferencias(Preferencias p) async {
    await _c.from('configuracoes').upsert({
      'user_id': _uid,
      'notificacoes': p.notificacoes,
      'aviso_dias': p.avisoDias,
      'aviso_km': p.avisoKm,
    });
  }
}
