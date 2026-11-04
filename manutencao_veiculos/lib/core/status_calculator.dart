import '../models/item_plano.dart';
import '../models/manutencao.dart';
import 'formatters.dart';

/// Ordem = gravidade (index maior = pior).
enum Status { semRegistro, emDia, venceLogo, atrasado }

class SituacaoItem {
  const SituacaoItem({
    required this.chave,
    required this.status,
    required this.detalhe,
    this.sub,
    this.dataAlvo,
    this.item,
  });

  final ChaveItem chave;
  final Status status;
  final String detalhe;
  final String? sub;

  /// Data limite do item (quando ele vence por data), usada no agendamento.
  final DateTime? dataAlvo;

  /// Item do plano que originou esta situação (usado para editar intervalos).
  final ItemPlano? item;
}

/// Regras de negócio puras (sem Flutter e sem banco) => fáceis de testar.
class StatusCalculator {
  const StatusCalculator({this.avisoKm = 1000, this.avisoDias = 30});

  final int avisoKm;
  final int avisoDias;

  SituacaoItem calcular({
    required ItemPlano item,
    required int kmAtual,
    required DateTime hoje,
    Manutencao? ultima,
  }) {
    return item.chave.ehDocumento
        ? _documento(item, hoje)
        : _manutencao(item, kmAtual, hoje, ultima);
  }

  SituacaoItem _documento(ItemPlano item, DateTime hoje) {
    final venc = item.vencimento;
    if (venc == null) {
      return SituacaoItem(
        chave: item.chave,
        item: item,
        status: Status.semRegistro,
        detalhe: 'Informe o vencimento',
      );
    }
    final dias = diasEntre(hoje, venc);
    final Status status;
    final String detalhe;
    if (dias < 0) {
      status = Status.atrasado;
      detalhe = 'venceu há ${-dias} dia${dias == -1 ? '' : 's'}';
    } else if (dias == 0) {
      status = Status.venceLogo;
      detalhe = 'vence hoje';
    } else if (dias <= avisoDias) {
      status = Status.venceLogo;
      detalhe = 'vence em $dias dia${dias == 1 ? '' : 's'}';
    } else {
      status = Status.emDia;
      detalhe = 'em dia';
    }
    return SituacaoItem(
      chave: item.chave,
      item: item,
      status: status,
      detalhe: detalhe,
      sub: 'Vencimento: ${formatData(venc)}',
      dataAlvo: venc,
    );
  }

  SituacaoItem _manutencao(
    ItemPlano item,
    int kmAtual,
    DateTime hoje,
    Manutencao? ultima,
  ) {
    if (ultima == null ||
        (item.intervaloKm == null && item.intervaloMeses == null)) {
      return SituacaoItem(
        chave: item.chave,
        item: item,
        status: Status.semRegistro,
        detalhe: 'sem registro',
        sub: 'Registre a última manutenção',
      );
    }

    final kmRest = item.intervaloKm == null
        ? null
        : ultima.km + item.intervaloKm! - kmAtual;
    final dataLimite = item.intervaloMeses == null
        ? null
        : somarMeses(ultima.data, item.intervaloMeses!);
    final diasRest = dataLimite == null ? null : diasEntre(hoje, dataLimite);

    Status status;
    String detalhe;
    if (kmRest != null && diasRest != null) {
      final sk = _statusKm(kmRest);
      final sd = _statusDias(diasRest);
      if (sd.index > sk.index) {
        status = sd;
        detalhe = _textoDias(diasRest);
      } else {
        status = sk;
        detalhe = _textoKm(kmRest);
      }
    } else if (kmRest != null) {
      status = _statusKm(kmRest);
      detalhe = _textoKm(kmRest);
    } else {
      status = _statusDias(diasRest!);
      detalhe = _textoDias(diasRest);
    }

    return SituacaoItem(
      chave: item.chave,
      item: item,
      status: status,
      detalhe: detalhe,
      sub: 'Última: ${formatKm(ultima.km)} · ${formatData(ultima.data)}',
      dataAlvo: dataLimite,
    );
  }

  Status _statusKm(int restante) => restante < 0
      ? Status.atrasado
      : (restante <= avisoKm ? Status.venceLogo : Status.emDia);

  Status _statusDias(int restante) => restante < 0
      ? Status.atrasado
      : (restante <= avisoDias ? Status.venceLogo : Status.emDia);

  String _textoKm(int r) =>
      r >= 0 ? 'faltam ${formatKm(r)}' : 'passou ${formatKm(-r)}';

  String _textoDias(int d) {
    if (d == 0) return 'vence hoje';
    if (d > 0) return 'faltam $d dia${d == 1 ? '' : 's'}';
    return 'atrasado há ${-d} dia${d == -1 ? '' : 's'}';
  }
}
