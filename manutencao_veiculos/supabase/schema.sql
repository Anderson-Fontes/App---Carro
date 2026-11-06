-- =====================================================================
-- Minha garagem — esquema do banco na nuvem (Supabase / PostgreSQL)
--
-- Como usar: Supabase > SQL Editor > New query > cole TUDO > Run.
--
-- Segurança (resumo):
--   * RLS (Row Level Security) em TODAS as tabelas: cada usuário só enxerga
--     e altera as linhas em que user_id = auth.uid().
--   * Chave estrangeira composta (veiculo_id, user_id): impossível pendurar
--     um registro seu no veículo de outra pessoa.
--   * CHECK constraints espelham as validações do app (defesa em profundidade).
--   * O app só usa a chave "anon" (pública por desenho); sem login e sem
--     política de RLS, ela não lê nada.
--   * Fotos em bucket PRIVADO, pasta por usuário, só JPEG/PNG, máx. 5 MB.
-- =====================================================================

-- --------------------------------------------------------------- Tabelas

create table if not exists public.veiculos (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid()
             references auth.users (id) on delete cascade,
  modelo     text not null
             check (char_length(modelo) between 2 and 40
                    and modelo !~ '[<>"`;\\{}]'),
  placa      text not null check (placa ~ '^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$'),
  ano        int  not null check (ano between 1950 and 2100),
  km         int  not null check (km between 0 and 3000000),
  tipo       text not null check (tipo in ('carro', 'moto')),
  criado_em  timestamptz not null default now(),
  unique (user_id, placa),
  unique (id, user_id)            -- alvo da chave estrangeira composta
);

create table if not exists public.itens_plano (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid()
                   references auth.users (id) on delete cascade,
  veiculo_id       uuid not null,
  chave            text not null
                   check (chave in ('oleo','pneus','freios','bateria','ipva','seguro')),
  intervalo_km     int  check (intervalo_km    is null or intervalo_km    between 500 and 300000),
  intervalo_meses  int  check (intervalo_meses is null or intervalo_meses between 1 and 120),
  vencimento       date,
  unique (veiculo_id, chave),
  -- itens de manutenção precisam de km e/ou meses; IPVA/seguro vencem por data
  check (chave in ('ipva','seguro')
         or intervalo_km is not null or intervalo_meses is not null),
  foreign key (veiculo_id, user_id)
    references public.veiculos (id, user_id) on delete cascade
);

create table if not exists public.manutencoes (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid()
                  references auth.users (id) on delete cascade,
  veiculo_id      uuid not null,
  tipo            text not null
                  check (tipo in ('oleo','pneus','freios','bateria','outro')),
  descricao       text check (descricao is null
                              or (char_length(descricao) <= 60
                                  and descricao !~ '[<>"`;\\{}]')),
  data            date not null
                  check (data >= date '1990-01-01'),
  km              int  not null check (km between 0 and 3000000),
  valor_centavos  int  not null check (valor_centavos between 0 and 99999999),
  oficina         text check (oficina is null
                              or (char_length(oficina) <= 60
                                  and oficina !~ '[<>"`;\\{}]')),
  -- só o NOME do arquivo (gerado pelo app); o caminho completo é <user_id>/<nome>
  foto            text check (foto is null or foto ~ '^[a-f0-9]{32}\.(jpg|png)$'),
  criado_em       timestamptz not null default now(),
  foreign key (veiculo_id, user_id)
    references public.veiculos (id, user_id) on delete cascade
);

create index if not exists idx_manut_veiculo
  on public.manutencoes (veiculo_id, data desc);

create table if not exists public.configuracoes (
  user_id       uuid primary key default auth.uid()
                references auth.users (id) on delete cascade,
  notificacoes  boolean not null default true,
  aviso_dias    int not null default 30   check (aviso_dias in (7, 15, 30, 60)),
  aviso_km      int not null default 1000 check (aviso_km  in (500, 1000, 2000, 5000))
);

-- Última manutenção de cada tipo (uma consulta em vez de várias).
-- security_invoker: a view obedece à RLS de quem consulta.
create or replace view public.ultimas_manutencoes
  with (security_invoker = true) as
select distinct on (veiculo_id, tipo)
       id, user_id, veiculo_id, tipo, descricao, data, km,
       valor_centavos, oficina, foto, criado_em
from public.manutencoes
order by veiculo_id, tipo, data desc, km desc, criado_em desc;

-- ------------------------------------------- Regra: km nunca diminui

create or replace function public.trg_km_nao_diminui()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.km < old.km then
    raise exception 'A quilometragem nao pode diminuir.';
  end if;
  return new;
end;
$$;

drop trigger if exists veiculos_km_nao_diminui on public.veiculos;
create trigger veiculos_km_nao_diminui
  before update of km on public.veiculos
  for each row execute function public.trg_km_nao_diminui();

-- ----------------------------------------------------------------- RLS

alter table public.veiculos       enable row level security;
alter table public.itens_plano    enable row level security;
alter table public.manutencoes    enable row level security;
alter table public.configuracoes  enable row level security;

drop policy if exists "veiculos_dono"      on public.veiculos;
drop policy if exists "itens_plano_dono"   on public.itens_plano;
drop policy if exists "manutencoes_dono"   on public.manutencoes;
drop policy if exists "configuracoes_dono" on public.configuracoes;

create policy "veiculos_dono" on public.veiculos
  for all to authenticated
  using      (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "itens_plano_dono" on public.itens_plano
  for all to authenticated
  using      (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "manutencoes_dono" on public.manutencoes
  for all to authenticated
  using      (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "configuracoes_dono" on public.configuracoes
  for all to authenticated
  using      (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Privilégios mínimos: visitante (anon) não tem acesso a nada.
revoke all on public.veiculos, public.itens_plano, public.manutencoes,
              public.configuracoes, public.ultimas_manutencoes from public, anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete
  on public.veiculos, public.itens_plano, public.manutencoes,
     public.configuracoes to authenticated;
grant select on public.ultimas_manutencoes to authenticated;

-- ------------------------------------------- Funções (operações atômicas)
-- security invoker: rodam com os direitos (e a RLS) de quem chama.

create or replace function public.criar_veiculo(
  p_modelo text, p_placa text, p_ano int, p_km int, p_tipo text,
  p_ipva date default null, p_seguro date default null
) returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id   uuid;
  v_moto boolean := (p_tipo = 'moto');
begin
  insert into veiculos (modelo, placa, ano, km, tipo)
  values (p_modelo, upper(p_placa), p_ano, p_km, p_tipo)
  returning id into v_id;

  insert into itens_plano (veiculo_id, chave, intervalo_km, intervalo_meses, vencimento)
  values
    (v_id, 'oleo',    case when v_moto then 3000  else 10000 end,
                      case when v_moto then 6     else 12    end, null),
    (v_id, 'pneus',   10000, null, null),
    (v_id, 'freios',  case when v_moto then 15000 else 30000 end, null, null),
    (v_id, 'bateria', null, 24, null),
    (v_id, 'ipva',    null, null, p_ipva),
    (v_id, 'seguro',  null, null, p_seguro);

  return v_id;
end;
$$;

create or replace function public.registrar_manutencao(
  p_veiculo_id uuid, p_tipo text, p_descricao text, p_data date,
  p_km int, p_valor_centavos int, p_oficina text, p_foto text
) returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into manutencoes
    (veiculo_id, tipo, descricao, data, km, valor_centavos, oficina, foto)
  values
    (p_veiculo_id, p_tipo, p_descricao, p_data, p_km, p_valor_centavos, p_oficina, p_foto)
  returning id into v_id;

  -- Se o serviço foi feito com km maior que o atual, o veículo "anda".
  update veiculos set km = p_km where id = p_veiculo_id and km < p_km;

  return v_id;
end;
$$;

-- Exclusão da própria conta (LGPD: direito de apagar os dados).
-- Os dados somem em cascata (on delete cascade). As fotos o app apaga antes.
create or replace function public.excluir_minha_conta()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Nao autenticado.';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function
  public.criar_veiculo(text, text, int, int, text, date, date),
  public.registrar_manutencao(uuid, text, text, date, int, int, text, text),
  public.excluir_minha_conta()
  from public, anon;
grant execute on function
  public.criar_veiculo(text, text, int, int, text, date, date),
  public.registrar_manutencao(uuid, text, text, date, int, int, text, text),
  public.excluir_minha_conta()
  to authenticated;

-- --------------------------------------------- Storage (fotos das notas)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('notas', 'notas', false, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do update
  set public = false,
      file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg', 'image/png'];

drop policy if exists "notas_ler_proprias"    on storage.objects;
drop policy if exists "notas_enviar_proprias" on storage.objects;
drop policy if exists "notas_apagar_proprias" on storage.objects;

-- O primeiro nível do caminho precisa ser o id do próprio usuário.
create policy "notas_ler_proprias" on storage.objects
  for select to authenticated
  using (bucket_id = 'notas'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "notas_enviar_proprias" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'notas'
              and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "notas_apagar_proprias" on storage.objects
  for delete to authenticated
  using (bucket_id = 'notas'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ---------------------------------------------------------------------
-- VERIFICAÇÃO (rode separado): toda tabela deve mostrar rls_ativo = true
-- e pelo menos 1 política.
--
--   select c.relname as tabela, c.relrowsecurity as rls_ativo,
--          count(p.policyname) as politicas
--   from pg_class c
--   join pg_namespace n on n.oid = c.relnamespace
--   left join pg_policies p
--          on p.schemaname = n.nspname and p.tablename = c.relname
--   where n.nspname = 'public' and c.relkind = 'r'
--   group by 1, 2 order by 1;
-- ---------------------------------------------------------------------
