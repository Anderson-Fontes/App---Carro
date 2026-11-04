import '../data/garagem_repository.dart';
import '../models/item_plano.dart';
import '../models/manutencao.dart';
import '../models/preferencias.dart';
import '../models/veiculo.dart';
import 'alerta_estado.dart';
import 'notificacao_ids.dart';
import 'notificacao_service.dart';
import 'status_calculator.dart';

/// Liga banco (nuvem) + regras + notificações (locais).
class GaragemService {
  GaragemService(this.repo, {AlertaEstado? estado})
    : _estado = estado ?? AlertaEstado.instance;

  final GaragemRepository repo;
  final AlertaEstado _estado;

  Future<List<SituacaoItem>> avaliar(Veiculo v, Preferencias prefs) async {
    final calc = StatusCalculator(
      avisoKm: prefs.avisoKm,
      avisoDias: prefs.avisoDias,
    );
    // Duas consultas em paralelo (itens do plano + últimas manutenções).
    final (itens, ultimas) = await (
      repo.listarItens(v.id!),
      repo.ultimasManutencoes(v.id!),
    ).wait;
    final hoje = DateTime.now();
    final saida = <SituacaoItem>[];
    for (final item in itens) {
      Manutencao? ultima;
      if (!item.chave.ehDocumento) {
        // Os nomes de ChaveItem e TipoServico coincidem para estes itens.
        ultima = ultimas[TipoServico.values.byName(item.chave.name)];
      }
      saida.add(
        calc.calcular(item: item, kmAtual: v.km, hoje: hoje, ultima: ultima),
      );
    }
    return saida;
  }

  /// Dispara avisos sem repetir: só notifica quando o status PIORA.
  /// Também agenda o aviso por data (antecedência configurada, às 9h).
  Future<void> alertar(
    Veiculo v,
    List<SituacaoItem> situacoes,
    NotificacaoService n,
    Preferencias prefs,
  ) async {
    final agora = DateTime.now();

    for (final s in situacoes) {
      final idAgendado = idNotificacao(v.id!, s.chave);
      final idImediato = idNotificacao(v.id!, s.chave, imediato: true);

      if (!prefs.notificacoes) {
        await n.cancelar(idAgendado);
        await n.cancelar(idImediato);
        continue;
      }

      final chaveEstado = '${AlertaEstado.prefixo}${v.id}_${s.chave.name}';
      final anterior = await _estado.ler(chaveEstado);
      final pendente =
          s.status == Status.venceLogo || s.status == Status.atrasado;
      if (pendente && anterior != s.status.name) {
        await n.mostrar(
          id: idImediato,
          titulo: 'Manutenção: ${s.chave.rotulo}',
          corpo: '${v.modelo}: ${s.detalhe}',
        );
      }
      await _estado.salvar(chaveEstado, s.status.name);

      final alvo = s.dataAlvo;
      if (alvo != null && s.status != Status.atrasado) {
        final quando = DateTime(
          alvo.year,
          alvo.month,
          alvo.day,
          9,
        ).subtract(Duration(days: prefs.avisoDias));
        if (quando.isAfter(agora)) {
          await n.agendar(
            id: idAgendado,
            titulo: 'Manutenção: ${s.chave.rotulo}',
            corpo: '${v.modelo}: vence em ${prefs.avisoDias} dias',
            quando: quando,
          );
        } else {
          await n.cancelar(idAgendado);
        }
      } else {
        await n.cancelar(idAgendado);
      }
    }
  }

  Future<void> cancelarAlertas(String veiculoId, NotificacaoService n) async {
    for (final c in ChaveItem.values) {
      await n.cancelar(idNotificacao(veiculoId, c));
      await n.cancelar(idNotificacao(veiculoId, c, imediato: true));
    }
  }

  // --------------------------------------------------------------- Resumos

  static SituacaoItem? pior(List<SituacaoItem> s) {
    SituacaoItem? p;
    for (final i in s) {
      if (p == null || i.status.index > p.status.index) p = i;
    }
    return p;
  }

  static bool temPendencia(List<SituacaoItem> s) =>
      s.any((i) => i.status == Status.venceLogo || i.status == Status.atrasado);

  static String resumo(List<SituacaoItem> s) {
    final p = pior(s);
    if (p == null) return 'Sem itens';
    if (p.status == Status.atrasado || p.status == Status.venceLogo) {
      return '${p.chave.rotulo}: ${p.detalhe}';
    }
    return s.any((i) => i.status == Status.semRegistro)
        ? 'Sem pendências'
        : 'Tudo em dia';
  }
}
