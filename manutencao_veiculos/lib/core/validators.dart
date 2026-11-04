import 'dart:convert';

/// Validação e sanitização de toda entrada do usuário.
///
/// Estratégia: lista de permissão (whitelist) de caracteres + limites de
/// tamanho. A entrada é validada na tela E novamente antes de gravar.
class Validators {
  Validators._();

  static const int kmMax = 3000000;

  static final RegExp _placa = RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$');
  static final RegExp _modelo = RegExp(
    r'^[\p{L}\p{N} .\-/+]{2,40}$',
    unicode: true,
  );
  static final RegExp _textoLivre = RegExp(
    r"^[\p{L}\p{N} .,\-/&'()#]{2,60}$",
    unicode: true,
  );
  static final RegExp _controle = RegExp(r'[\u0000-\u001F\u007F]');
  static final RegExp _espacos = RegExp(r'\s+');

  /// Remove caracteres de controle, junta espaços repetidos e apara as pontas.
  static String sanitizar(String? entrada) => (entrada ?? '')
      .replaceAll(_controle, ' ')
      .replaceAll(_espacos, ' ')
      .trim();

  static String normalizarPlaca(String? entrada) =>
      sanitizar(entrada).replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  static String? placa(String? v) {
    final p = normalizarPlaca(v);
    if (p.isEmpty) return 'Informe a placa.';
    if (!_placa.hasMatch(p)) return 'Placa inválida (ex.: ABC1D23 ou ABC1234).';
    return null;
  }

  static String? modelo(String? v) {
    final s = sanitizar(v);
    if (s.isEmpty) return 'Informe o modelo.';
    if (!_modelo.hasMatch(s)) {
      return 'Use de 2 a 40 caracteres: letras, números, espaço e . - / +';
    }
    return null;
  }

  static String? ano(String? v) {
    final n = int.tryParse(sanitizar(v));
    final max = DateTime.now().year + 1;
    if (n == null) return 'Informe o ano.';
    if (n < 1950 || n > max) return 'Ano entre 1950 e $max.';
    return null;
  }

  /// Converte "48.230", "48230" ou "48.230 km" em inteiro. Null se inválido.
  static int? parseKm(String? v) {
    final s = sanitizar(v)
        .replaceAll('.', '')
        .replaceAll(' ', '')
        .toLowerCase()
        .replaceAll('km', '');
    if (!RegExp(r'^\d{1,7}$').hasMatch(s)) return null;
    final n = int.parse(s);
    return n <= kmMax ? n : null;
  }

  static String? km(String? v) =>
      parseKm(v) == null ? 'Quilometragem inválida (0 a 3.000.000).' : null;

  /// Converte "1.234,56" em centavos (123456). Vazio vira 0. Null se inválido.
  static int? parseValorCentavos(String? v) {
    var s = sanitizar(v).replaceAll('R\$', '').replaceAll(' ', '');
    if (s.isEmpty) return 0;
    s = s.replaceAll('.', '').replaceAll(',', '.');
    final m = RegExp(r'^(\d{1,6})(?:\.(\d{1,2}))?$').firstMatch(s);
    if (m == null) return null;
    final reais = int.parse(m[1]!);
    final cents = m[2] == null ? 0 : int.parse(m[2]!.padRight(2, '0'));
    return reais * 100 + cents;
  }

  static String? valor(String? v) =>
      parseValorCentavos(v) == null ? 'Valor inválido (ex.: 189,90).' : null;

  /// Oficina é opcional; se preenchida, segue a lista de caracteres permitidos.
  static String? oficina(String? v) {
    final s = sanitizar(v);
    if (s.isEmpty) return null;
    return _textoLivre.hasMatch(s)
        ? null
        : "Use de 2 a 60 caracteres: letras, números e . , - / & ' ( ) #";
  }

  static String? descricaoOutro(String? v) {
    final s = sanitizar(v);
    if (s.isEmpty) return 'Descreva o serviço.';
    return _textoLivre.hasMatch(s)
        ? null
        : 'Descrição inválida (2 a 60 caracteres, sem símbolos especiais).';
  }

  // ------------------------------------------------------- Conta (login)

  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9._%+\-]{1,64}@[A-Za-z0-9.\-]{1,200}\.[A-Za-z]{2,24}$',
  );

  static String normalizarEmail(String? v) => sanitizar(v).toLowerCase();

  static String? email(String? v) {
    final s = normalizarEmail(v);
    if (s.isEmpty) return 'Informe o e-mail.';
    if (s.length > 254 || s.contains('..') || !_email.hasMatch(s)) {
      return 'E-mail inválido.';
    }
    return null;
  }

  /// Política para CRIAR/TROCAR senha: 8 a 72 bytes, com letras e números.
  /// (72 bytes é o limite do bcrypt usado pelo Supabase.)
  static String? senhaNova(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Informe a senha.';
    if (s.length < 8) return 'A senha deve ter pelo menos 8 caracteres.';
    if (utf8.encode(s).length > 72) {
      return 'A senha deve ter no máximo 72 caracteres.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(s) || !RegExp(r'\d').hasMatch(s)) {
      return 'Use letras e números na senha.';
    }
    return null;
  }

  /// No login só exigimos preenchimento (não revelamos a política).
  static String? senhaLogin(String? v) =>
      (v == null || v.isEmpty) ? 'Informe a senha.' : null;

  /// Código de 6 a 10 dígitos enviado por e-mail na recuperação de senha.
  static String? codigo(String? v) =>
      RegExp(r'^\d{6,10}$').hasMatch(sanitizar(v))
      ? null
      : 'Informe o código numérico recebido por e-mail.';

  // ------------------------------------------------ Intervalos do plano

  /// Vazio = sem intervalo por km.
  static String? intervaloKm(String? v) {
    if (sanitizar(v).isEmpty) return null;
    final n = parseKm(v);
    return (n == null || n < 500 || n > 300000)
        ? 'Use de 500 a 300.000 km (ou deixe vazio).'
        : null;
  }

  /// Vazio = sem intervalo por tempo.
  static String? intervaloMeses(String? v) {
    final s = sanitizar(v);
    if (s.isEmpty) return null;
    final n = RegExp(r'^\d{1,3}$').hasMatch(s) ? int.parse(s) : null;
    return (n == null || n < 1 || n > 120)
        ? 'Use de 1 a 120 meses (ou deixe vazio).'
        : null;
  }

  static int? lerIntervaloKm(String? v) =>
      sanitizar(v).isEmpty ? null : parseKm(v);

  static int? lerIntervaloMeses(String? v) =>
      sanitizar(v).isEmpty ? null : int.tryParse(sanitizar(v));
}
