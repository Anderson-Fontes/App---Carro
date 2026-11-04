import 'package:flutter/material.dart';

import '../core/status_calculator.dart';
import '../core/status_ui.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.situacao,
    this.onTap,
    this.iconeAcao = Icons.edit_calendar,
  });

  final SituacaoItem situacao;
  final VoidCallback? onTap;
  final IconData iconeAcao;

  @override
  Widget build(BuildContext context) {
    final cor = situacao.status.cor;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(situacao.status.icone, color: cor),
        title: Text(
          situacao.chave.rotulo,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              situacao.detalhe,
              style: TextStyle(color: cor, fontWeight: FontWeight.w500),
            ),
            if (situacao.sub != null)
              Text(situacao.sub!, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: onTap == null ? null : Icon(iconeAcao, size: 20),
      ),
    );
  }
}
