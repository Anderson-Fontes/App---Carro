import 'package:flutter/material.dart';

import 'status_calculator.dart';

extension StatusUi on Status {
  Color get cor {
    switch (this) {
      case Status.emDia:
        return const Color(0xFF2E7D32);
      case Status.venceLogo:
        return const Color(0xFFEF6C00);
      case Status.atrasado:
        return const Color(0xFFC62828);
      case Status.semRegistro:
        return const Color(0xFF757575);
    }
  }

  IconData get icone {
    switch (this) {
      case Status.emDia:
        return Icons.check_circle;
      case Status.venceLogo:
        return Icons.schedule;
      case Status.atrasado:
        return Icons.error;
      case Status.semRegistro:
        return Icons.help_outline;
    }
  }
}
