# Minha garagem 2.0 — App de Manutenção de Veículos (Flutter + Supabase)

Projeto da disciplina Laboratório de Desenvolvimento Mobile.
Autores: Anderson Fontes e Gustavo Silva · Professor: Arley

Versão 2.0: **login por e-mail e senha** e **banco de dados na nuvem** (Supabase:
PostgreSQL + Auth + Storage, plano gratuito). Os dados acompanham a conta, então
trocar de celular não exige recadastrar nada.

## O que o app faz

- Criar conta, entrar, sair, **recuperar senha por código no e-mail**, alterar senha e **excluir a conta** (apaga todos os dados e fotos).
- Garagem com vários veículos (carro/moto), resumo de pendências e *pull-to-refresh*.
- Cadastrar e **editar** veículo; atualizar quilometragem (nunca diminui).
- Painel com semáforo por item: óleo e filtro, pneus, freios, bateria, IPVA e seguro.
- **Editar os intervalos** de manutenção (km e/ou meses, vale o que vencer primeiro).
- Registrar manutenção com **foto da nota fiscal** (bucket privado na nuvem).
- Histórico, total gasto e **exportação em CSV** (copia para a área de transferência).
- Alertas por data e por quilometragem (notificações locais, sem repetir).
- Configurações de alerta salvas na conta (valem em qualquer aparelho).

## Passo a passo

### 1. Criar o projeto no Supabase (grátis)

1. Acesse https://supabase.com, crie a conta e clique em **New project**.
   Escolha um nome, defina a senha do banco (guarde) e a região **South America (São Paulo)**.
2. No menu **SQL Editor** > **New query**, cole **todo** o conteúdo de `supabase/schema.sql` e clique em **Run**.
   Isso cria as tabelas, as regras de acesso por usuário (RLS), as funções e o bucket privado `notas`.
3. Confira a segurança: rode a consulta de verificação que está no final do `schema.sql`
   (comentada). Toda tabela deve aparecer com `rls_ativo = true` e ao menos 1 política.
4. Em **Authentication** (os nomes dos menus podem variar um pouco):
   - **Sign In / Providers > Email**: mantenha habilitado. Para testar rápido você pode
     desligar **Confirm email**; para a versão final, deixe ligado.
   - **Password settings**: coloque o tamanho mínimo da senha em **8**.
   - **Email Templates > Reset Password**: inclua `{{ .Token }}` no corpo do e-mail
     (ex.: `Seu código: {{ .Token }}`). O app usa esse código para redefinir a senha.
   - O e-mail padrão do Supabase tem limite baixo de envios por hora. Serve para a
     demonstração; para uso real configure um SMTP próprio.
5. Em **Project Settings > API** copie a **Project URL** e a chave **anon public**.
   **Nunca** use a chave `service_role` no app.

### 2. Preparar o projeto Flutter

Se ainda não tem o projeto base:

```bash
flutter create --org br.fatec --project-name manutencao_veiculos --platforms android manutencao_veiculos
```

1. Descompacte este zip em qualquer pasta.
2. **Apague** as pastas `lib` e `test` do projeto criado (para não sobrar arquivo da
   versão antiga, como `database_helper.dart`) e copie para dentro dele: `lib/`, `test/`,
   `pubspec.yaml`, `analysis_options.yaml`, `env.example.json` e a pasta `supabase/`.
3. Substitua `android/app/src/main/AndroidManifest.xml` por `android_patches/AndroidManifest.xml`
   (agora inclui a permissão `INTERNET`).
4. Se ainda não fez, ative o *core library desugaring* em `android/app/build.gradle(.kts)`
   (mesmo passo da versão 1: `isCoreLibraryDesugaringEnabled = true` e a dependência
   `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`).
5. Crie o arquivo `env.json` (copie de `env.example.json`) com a URL e a chave anon:

   ```json
   {
     "SUPABASE_URL": "https://SEU-PROJETO.supabase.co",
     "SUPABASE_ANON_KEY": "sua-chave-anon-public"
   }
   ```

   Adicione `env.json` ao `.gitignore` (uma linha com o nome do arquivo) para não subir ao GitHub.

### 3. Rodar, testar e gerar o APK

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=env.json
flutter build apk --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=env.json
```

O APK fica em `build/app/outputs/flutter-apk/app-release.apk`.
Sem o `--dart-define-from-file`, o app abre uma tela avisando que a nuvem não está configurada.

Observação: projetos gratuitos do Supabase costumam ser pausados após cerca de uma semana
sem uso. Se o app parar de conectar, reative o projeto no painel (antes da apresentação, abra o app uma vez).

## Segurança (onde está cada coisa)

| Risco | Como o app se protege | Onde |
|---|---|---|
| Acesso de outro usuário aos dados | RLS em todas as tabelas (`user_id = auth.uid()`); chave estrangeira composta impede ligar registro ao veículo de outra pessoa | `supabase/schema.sql` |
| SQL Injection | O app não monta SQL: usa a API PostgREST e funções SQL com parâmetros tipados; CHECK constraints e triggers no banco como segunda barreira | `data/garagem_repository.dart`, `schema.sql` |
| XSS / injeção de conteúdo | Lista de caracteres permitidos na entrada, CHECK no banco, exibição só com `Text()`; sem WebView | `core/validators.dart` |
| Senhas e login | Senha guardada (hash) pelo Supabase Auth; política de 8+ caracteres com letras e números; mensagens genéricas; bloqueio de 30 s após 5 falhas; trocar senha e excluir conta exigem a senha atual | `core/auth_service.dart`, `screens/login_screen.dart` |
| Descobrir quem tem conta | "Esqueci a senha" responde igual exista ou não o e-mail | `core/auth_service.dart` |
| Arquivos maliciosos / path traversal | Nome aleatório gerado pelo app; tipo checado pelos primeiros bytes; limite 5 MB (app e bucket); só JPEG/PNG; pasta por usuário com política no Storage | `core/foto_storage.dart`, `schema.sql` |
| Vazamento de fotos | Bucket privado; exibição por link assinado que expira em 60 s | `core/foto_storage.dart` |
| Vazamento local | `allowBackup=false`; notificações sem placa; sem permissão de armazenamento externo ou câmera | `AndroidManifest.xml`, `core/notificacao_service.dart` |
| Tráfego de rede | Somente HTTPS (`usesCleartextTraffic=false`) | `AndroidManifest.xml` |
| CSV injection | Células iniciadas por `= + - @` recebem apóstrofo | `core/csv_export.dart` |
| Erros que expõem detalhes | Mensagens genéricas; sem `print` | todas as telas, `core/erros.dart` |
| Dados do usuário após sair | Notificações e controle de alertas do aparelho são limpos | `core/auth_service.dart` |
| Código no APK | Build com `--obfuscate`; chaves via `--dart-define`, fora do código | passo 3 |

## Testes

- `test/validators_test.dart`: placa, números, sanitização, ataques (SQL injection, XSS), e-mail, senha, código e intervalos.
- `test/status_calculator_test.dart`: regras de status (óleo, IPVA, seguro, pneus, "o que ocorrer primeiro").
- `test/ids_e_csv_test.dart`: ids de notificação derivados do UUID e proteção contra CSV injection.

Demonstração do isolamento entre usuários: crie duas contas, cadastre um veículo na primeira
e entre na segunda; a garagem dela aparece vazia. No Supabase (Table Editor) você vê os dados
dos dois, mas o app só mostra os do usuário logado.

## Limitações e próximos passos

- O app agora precisa de internet para ler e gravar dados (os alertas já agendados continuam funcionando offline).
- A sessão do login é guardada pelo `supabase_flutter` no armazenamento do app. Para endurecer,
  é possível guardar em `flutter_secure_storage`.
- Fuso das notificações fixo em `America/Sao_Paulo`.
- Exportação é CSV na área de transferência; arquivo/PDF compartilhável seria o próximo passo.
- Login social (Google) e autenticação em dois fatores (MFA) ficam como evolução.
