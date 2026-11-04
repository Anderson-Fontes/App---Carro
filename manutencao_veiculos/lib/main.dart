import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_service.dart';
import 'core/notificacao_service.dart';
import 'core/supabase_config.dart';
import 'screens/garagem_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.configurado) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }
  await NotificacaoService.instance.init();
  runApp(const MinhaGaragemApp());
}

class MinhaGaragemApp extends StatelessWidget {
  const MinhaGaragemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minha garagem',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
      ),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SupabaseConfig.configurado
          ? const PortaoAutenticacao()
          : const _ConfiguracaoAusente(),
    );
  }
}

/// Decide a tela inicial: sem sessão => login; com sessão => garagem.
/// Reage sozinho a entrar, sair, sessão expirada e conta excluída.
class PortaoAutenticacao extends StatelessWidget {
  const PortaoAutenticacao({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.instance.mudancas,
      builder: (context, _) {
        final usuario = AuthService.instance.usuario;
        if (usuario == null) return const LoginScreen();
        // A key recria a tela quando troca o usuário (nunca mistura dados).
        return GaragemScreen(key: ValueKey(usuario.id));
      },
    );
  }
}

class _ConfiguracaoAusente extends StatelessWidget {
  const _ConfiguracaoAusente();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Conexão com a nuvem não configurada.\n\n'
              'Rode o app com:\n'
              'flutter run --dart-define-from-file=env.json\n\n'
              '(veja o passo a passo no README).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
