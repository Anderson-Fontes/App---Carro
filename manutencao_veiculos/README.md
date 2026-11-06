# Minha garagem 2.0 — App de Manutenção de Veículos (Flutter + Supabase)

Projeto da disciplina Laboratório de Desenvolvimento Mobile.
Autores: Anderson Fontes e Gustavo Silva · Professor: Arley

Versão 2.0: **login por e-mail e senha** e **banco de dados na nuvem** (Supabase:
PostgreSQL + Auth + Storage, plano gratuito). Os dados acompanham a conta, então
trocar de celular não exige recadastrar nada.

## O que o app faz

- Criar conta, entrar, sair, **recuperar senha pelo link ou código do e-mail**, alterar senha e **excluir a conta** (apaga todos os dados e fotos).
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
   - **Sign In / Providers > Email**: mantenha habilitado. Para os testes, recomendamos
     manter **Confirm email** ligado e confirmar as contas antes da apresentação.
   - **Password settings**: mínimo **8**, **Letters and digits** e **Secure password change** ativo.
   - Recuperação: o email padrão envia um **link**. No celular, mantenha o botão
     "Reset password" pressionado, copie seu endereço **sem abri-lo** e cole no app.
     O app valida o domínio do projeto e usa `verifyOTP(tokenHash: ..., type: recovery)`.
     O servidor valida expiração e uso único; o aplicativo não abre o URL colado.
     Se configurar SMTP próprio, também pode incluir `{{ .Token }}` no template;
     o código numérico continua aceito. O painel gratuito atualmente restringe
     a edição de templates sem SMTP próprio ou plano Pro.
   - O serviço padrão de email tem restrições de destinatários e limite baixo
     de envio. Para contas fora da equipe do Supabase, configure SMTP próprio.
     Não desative a confirmação de email como solução de produção.
5. Em **Project Settings > API** copie a **Project URL** e a chave **anon public**.
   **Nunca** use a chave `service_role` no app.

### 2. Preparar o projeto Flutter

A estrutura Android já está incluída, com HTTPS obrigatório, backups desativados
 e desugaring configurado. Use Flutter **3.38.5** e Java **17**.

Na pasta `manutencao_veiculos`, copie `env.public.json` para `env.json` para usar
o projeto da dupla. Para outro projeto, use `env.example.json` e informe
`SUPABASE_URL` e `SUPABASE_ANON_KEY`. A segunda aceita a chave **publishable**
ou a chave legada **anon**. Nunca use senha do banco, `service_role` ou `sb_secret_`.
O `.gitignore` já exclui `env.json` e arquivos de assinatura.
`env.public.json` contém somente URL e chave publicável, projetada para ser
distribuída com o aplicativo. Nenhuma senha ou chave administrativa está nele.
A proteção dos dados é feita pelo login e pelas políticas RLS no servidor.

O `pubspec.lock` fixa as dependências testadas. Não o apague.

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
| Sessão no aparelho | Tokens em armazenamento criptografado (`flutter_secure_storage`) | `core/sessao_segura.dart` |
| Código no APK | Obfuscação dificulta a leitura; a chave pública continua extraível e a proteção dos dados depende de Auth + RLS | passo 3 |

## Testes

- `test/validators_test.dart`: placa, números, sanitização, ataques (SQL injection, XSS), e-mail, senha, código e intervalos.
- `test/status_calculator_test.dart`: regras de status (óleo, IPVA, seguro, pneus, "o que ocorrer primeiro").
- `test/ids_e_csv_test.dart`: ids de notificação derivados do UUID e proteção contra CSV injection.

Demonstração do isolamento entre usuários: crie duas contas, cadastre um veículo na primeira
e entre na segunda; a garagem dela aparece vazia. No Supabase (Table Editor) você vê os dados
dos dois, mas o app só mostra os do usuário logado.

## Limitações e próximos passos

- O app agora precisa de internet para ler e gravar dados (os alertas já agendados continuam funcionando offline).
- A sessão usa `flutter_secure_storage` com armazenamento criptografado no Android; a senha não é persistida pelo app.
- Fuso das notificações fixo em `America/Sao_Paulo`.
- Exportação é CSV na área de transferência; arquivo/PDF compartilhável seria o próximo passo.
- Login social (Google) e autenticação em dois fatores (MFA) ficam como evolução.


## Gerar APK no GitHub

O workflow `.github/workflows/android.yml` analisa o código e executa os testes.
Em pushes para `main` ou `feat/nuvem-seguranca-apk`, e em execução manual,
compila o APK após os testes passarem. Pull requests executam somente os testes.

1. O workflow usa `env.public.json` da dupla. Para mudar o destino sem editar
   o arquivo, um administrador pode configurar em
   **Settings > Secrets and variables > Actions > Variables**:
   - `SUPABASE_URL`: URL do projeto.
   - `SUPABASE_ANON_KEY`: chave **publishable** (ou **anon**), nunca chave administrativa.
2. Em **Actions > Testes e APK Android**, abra a execução (ou **Run workflow**).
3. Ao terminar, baixe **Artifacts > minha-garagem-apk**, extraia e instale o APK.

Este APK é para demonstração acadêmica: compilação release, mas assinatura de
**debug** do ambiente de build. Não é uma assinatura de publicação na Play Store.
Entre builds a assinatura pode mudar; nesse caso é necessário desinstalar a versão
anterior. Os registros ficam na nuvem e voltam após o login.
Para distribuição contínua, configure uma chave de assinatura estável em Secrets.

## Verificação da segurança no banco

Execute `supabase/testar_seguranca.sql` inteiro no SQL Editor. Ele cria dois
usuários temporários, simula suas permissões e testa leitura/escrita entre contas,
acesso anônimo, vínculo de manutenção e regra de quilometragem. Também verifica
RLS nas quatro tabelas e o bucket privado de 5 MB. Ao final usa `ROLLBACK`, sem
manter usuários ou dados de teste. O resultado esperado começa com `PASSOU`.

O teste de sessão usa um armazenamento simulado: verifica persistência e remoção,
mas a criptografia e os fluxos de câmera/notificações precisam de teste no Android.
O bloqueio de 30 segundos no cliente é apenas complementar; os limites efetivos
contra abuso ficam no Supabase Auth. Pedir senha atual na interface para excluir
conta não é uma verificação adicional na RPC: ela autoriza pelo JWT do próprio usuário.
