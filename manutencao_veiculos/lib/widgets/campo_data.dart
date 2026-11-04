import 'package:flutter/material.dart';

import '../core/formatters.dart';

class CampoData extends StatelessWidget {
  const CampoData({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.onChanged,
    required this.primeira,
    required this.ultima,
    this.permiteLimpar = false,
  });

  final String rotulo;
  final DateTime? valor;
  final ValueChanged<DateTime?> onChanged;
  final DateTime primeira;
  final DateTime ultima;
  final bool permiteLimpar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(rotulo),
      subtitle: Text(valor == null ? 'Não informado' : formatData(valor!)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (permiteLimpar && valor != null)
            IconButton(
              tooltip: 'Limpar',
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(null),
            ),
          const Icon(Icons.calendar_today),
        ],
      ),
      onTap: () async {
        final base = valor ?? DateTime.now();
        final inicial = base.isBefore(primeira)
            ? primeira
            : (base.isAfter(ultima) ? ultima : base);
        final d = await showDatePicker(
          context: context,
          initialDate: inicial,
          firstDate: primeira,
          lastDate: ultima,
        );
        if (d != null) onChanged(d);
      },
    );
  }
}
