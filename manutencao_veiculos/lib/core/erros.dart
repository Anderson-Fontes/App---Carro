/// Converte falhas técnicas em mensagens amigáveis e genéricas.
/// Detalhes internos (SQL, stack trace, URLs) nunca chegam ao usuário.
String mensagemErro(Object erro, String padrao) {
  final t = erro.toString();
  if (t.contains('SocketException') ||
      t.contains('ClientException') ||
      t.contains('Failed host lookup') ||
      t.contains('TimeoutException') ||
      t.contains('Connection')) {
    return 'Sem conexão com a internet. Tente novamente.';
  }
  return padrao;
}
