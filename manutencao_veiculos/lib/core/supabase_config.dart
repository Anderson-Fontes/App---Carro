/// Dados de conexão com o Supabase, injetados na hora de rodar/compilar:
///
///   flutter run --dart-define-from-file=env.json
///
/// A chave "anon" é pública por desenho (o que protege os dados é o login +
/// RLS no banco), mas mantemos fora do código-fonte e do GitHub (env.json
/// está no .gitignore). NUNCA coloque a chave "service_role" no app.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get configurado =>
      url.startsWith('https://') && anonKey.isNotEmpty;
}
