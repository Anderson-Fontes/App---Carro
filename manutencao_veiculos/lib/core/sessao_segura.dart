import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Guarda os tokens de login em armazenamento criptografado no Android.
/// A senha do usuário não é salva pelo aplicativo.
class SessaoSegura extends LocalStorage {
  SessaoSegura({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _chave = 'minha_garagem_sessao';
  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _chave);

  @override
  Future<String?> accessToken() => _storage.read(key: _chave);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _chave, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _chave);
}
