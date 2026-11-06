-- Execute TODO este arquivo no SQL Editor depois de schema.sql.
-- Tudo ocorre numa transação desfeita ao final: nenhum dado de teste permanece.
begin;
create temporary table teste_ids (a uuid, b uuid, veiculo uuid);
insert into teste_ids values (gen_random_uuid(), gen_random_uuid(), null);
grant select, update on teste_ids to authenticated;
insert into auth.users (id) select a from teste_ids union all select b from teste_ids;

select set_config('request.jwt.claim.sub', (select a::text from teste_ids), true);
set local role authenticated;
update teste_ids set veiculo = public.criar_veiculo('Carro teste', 'TST1A23', 2020, 1000, 'carro');
select public.registrar_manutencao(veiculo, 'oleo', null, current_date, 1200, 10000, null, null) from teste_ids;
do $$
begin
  if (select count(*) from public.veiculos where id = (select veiculo from teste_ids)) <> 1 then
    raise exception 'FALHOU: proprietário não consegue ler seu veículo';
  end if;
  if (select km from public.veiculos where id = (select veiculo from teste_ids)) <> 1200 then
    raise exception 'FALHOU: manutenção não atualizou km';
  end if;
  begin
    update public.veiculos set km = 500 where id = (select veiculo from teste_ids);
    raise exception 'FALHOU: km diminuiu';
  exception when raise_exception then
    if sqlerrm <> 'A quilometragem nao pode diminuir.' then raise; end if;
  end;
end $$;

select set_config('request.jwt.claim.sub', (select b::text from teste_ids), true);
do $$
declare alterados int;
begin
  if exists(select 1 from public.veiculos where id = (select veiculo from teste_ids))
     or exists(select 1 from public.itens_plano where veiculo_id = (select veiculo from teste_ids))
     or exists(select 1 from public.manutencoes where veiculo_id = (select veiculo from teste_ids))
     or exists(select 1 from public.ultimas_manutencoes where veiculo_id = (select veiculo from teste_ids)) then
    raise exception 'FALHOU: usuário B consegue ler dados de A';
  end if;
  update public.veiculos set km = 5000 where id = (select veiculo from teste_ids);
  get diagnostics alterados = row_count;
  if alterados <> 0 then raise exception 'FALHOU: B alterou veículo de A'; end if;
  delete from public.veiculos where id = (select veiculo from teste_ids);
  get diagnostics alterados = row_count;
  if alterados <> 0 then raise exception 'FALHOU: B apagou veículo de A'; end if;
  begin
    insert into public.veiculos(user_id, modelo, placa, ano, km, tipo)
      select a, 'Forjado', 'TST2B34', 2020, 0, 'carro' from teste_ids;
    raise exception 'FALHOU: B inseriu dados em nome de A';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.registrar_manutencao((select veiculo from teste_ids), 'oleo', null, current_date, 1300, 100, null, null);
    raise exception 'FALHOU: B vinculou manutenção ao veículo de A';
  exception when foreign_key_violation then null;
  end;
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform 1 from public.veiculos;
    raise exception 'FALHOU: visitante leu tabela de veículos';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.criar_veiculo('Visitante', 'TST3C45', 2020, 0, 'carro');
    raise exception 'FALHOU: visitante executou função de cadastro';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

do $$
begin
  if not exists(select 1 from storage.buckets where id = 'notas' and public = false and file_size_limit = 5242880) then
    raise exception 'FALHOU: bucket não está privado com limite de 5 MB';
  end if;
  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname in ('veiculos','itens_plano','manutencoes','configuracoes')
      and c.relrowsecurity) <> 4 then
    raise exception 'FALHOU: alguma tabela está sem RLS';
  end if;
end $$;
rollback;
select 'PASSOU: isolamento de usuários, permissões, integridade e bucket privado' as resultado;
