-- BANCO DE DADOS — PAINEL GERENCIAL DE OBRAS
-- Execute no SQL Editor do Supabase.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  role text not null default 'viewer' check (role in ('admin','editor','viewer')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.works (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phase text not null default 'Execução',
  status_color text not null default 'green' check (status_color in ('green','yellow','red')),
  progress numeric(5,2) not null default 0 check (progress >= 0 and progress <= 100),
  budget numeric(15,2) not null default 0,
  financial_projection numeric(15,2) not null default 0,
  contract_date date,
  delivery_forecast date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.actions (
  id uuid primary key default gen_random_uuid(),
  work_id uuid references public.works(id) on delete cascade,
  area text not null check (area in ('Gestão','Suprimentos','Projetos','PCP','Produto','Documentação','Acompanhamento OBRA')),
  description text not null,
  responsible text,
  due_date date,
  priority text not null default 'Média' check (priority in ('Alta','Média','Baixa')),
  status text not null default 'Pendente' check (status in ('Pendente','Em andamento','Concluída')),
  completed_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.accompaniments (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references public.works(id) on delete cascade,
  activity_date date not null default current_date,
  text text not null,
  responsible text,
  status text not null default 'Pendente' check (status in ('Pendente','Em andamento','Concluída')),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_history (
  id bigint generated always as identity primary key,
  table_name text not null,
  record_id uuid not null,
  action_type text not null check (action_type in ('INSERT','UPDATE','DELETE')),
  old_data jsonb,
  new_data jsonb,
  changed_by uuid references auth.users(id),
  changed_at timestamptz not null default now()
);

create or replace function public.is_editor_or_admin() returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.profiles where id=auth.uid() and role in ('editor','admin'));
$$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.profiles where id=auth.uid() and role='admin');
$$;

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;

drop trigger if exists works_updated_at on public.works;
create trigger works_updated_at before update on public.works for each row execute function public.set_updated_at();
drop trigger if exists actions_updated_at on public.actions;
create trigger actions_updated_at before update on public.actions for each row execute function public.set_updated_at();
drop trigger if exists accomp_updated_at on public.accompaniments;
create trigger accomp_updated_at before update on public.accompaniments for each row execute function public.set_updated_at();

create or replace function public.set_action_completion() returns trigger language plpgsql as $$ begin
  if new.status='Concluída' and (old.status is distinct from new.status) then new.completed_at=coalesce(new.completed_at,now());
  elsif new.status<>'Concluída' then new.completed_at=null;
  end if;
  return new;
end; $$;
drop trigger if exists action_completion on public.actions;
create trigger action_completion before update on public.actions for each row execute function public.set_action_completion();

create or replace function public.audit_row() returns trigger language plpgsql security definer set search_path=public as $$ begin
  if tg_op='INSERT' then insert into public.audit_history(table_name,record_id,action_type,new_data,changed_by) values(tg_table_name,new.id,'INSERT',to_jsonb(new),auth.uid()); return new;
  elsif tg_op='UPDATE' then insert into public.audit_history(table_name,record_id,action_type,old_data,new_data,changed_by) values(tg_table_name,new.id,'UPDATE',to_jsonb(old),to_jsonb(new),auth.uid()); return new;
  else insert into public.audit_history(table_name,record_id,action_type,old_data,changed_by) values(tg_table_name,old.id,'DELETE',to_jsonb(old),auth.uid()); return old; end if;
end; $$;

drop trigger if exists works_audit on public.works; create trigger works_audit after insert or update or delete on public.works for each row execute function public.audit_row();
drop trigger if exists actions_audit on public.actions; create trigger actions_audit after insert or update or delete on public.actions for each row execute function public.audit_row();
drop trigger if exists accomp_audit on public.accompaniments; create trigger accomp_audit after insert or update or delete on public.accompaniments for each row execute function public.audit_row();

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id,email,full_name,role) values(new.id,new.email,coalesce(new.raw_user_meta_data->>'full_name',''),'viewer') on conflict(id) do nothing; return new; end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.works enable row level security;
alter table public.actions enable row level security;
alter table public.accompaniments enable row level security;
alter table public.audit_history enable row level security;

drop policy if exists profiles_self_or_admin on public.profiles; create policy profiles_self_or_admin on public.profiles for select to authenticated using (id=auth.uid() or public.is_admin());
drop policy if exists profiles_admin_update on public.profiles; create policy profiles_admin_update on public.profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists works_read on public.works; create policy works_read on public.works for select to authenticated using (true);
drop policy if exists works_write on public.works; create policy works_write on public.works for insert to authenticated with check (public.is_editor_or_admin());
drop policy if exists works_update on public.works; create policy works_update on public.works for update to authenticated using (public.is_editor_or_admin()) with check (public.is_editor_or_admin());
drop policy if exists works_delete on public.works; create policy works_delete on public.works for delete to authenticated using (public.is_admin());

drop policy if exists actions_read on public.actions; create policy actions_read on public.actions for select to authenticated using (true);
drop policy if exists actions_write on public.actions; create policy actions_write on public.actions for insert to authenticated with check (public.is_editor_or_admin());
drop policy if exists actions_update on public.actions; create policy actions_update on public.actions for update to authenticated using (public.is_editor_or_admin()) with check (public.is_editor_or_admin());
drop policy if exists actions_delete on public.actions; create policy actions_delete on public.actions for delete to authenticated using (public.is_admin());

drop policy if exists accomp_read on public.accompaniments; create policy accomp_read on public.accompaniments for select to authenticated using (true);
drop policy if exists accomp_write on public.accompaniments; create policy accomp_write on public.accompaniments for insert to authenticated with check (public.is_editor_or_admin());
drop policy if exists accomp_update on public.accompaniments; create policy accomp_update on public.accompaniments for update to authenticated using (public.is_editor_or_admin()) with check (public.is_editor_or_admin());
drop policy if exists accomp_delete on public.accompaniments; create policy accomp_delete on public.accompaniments for delete to authenticated using (public.is_admin());

drop policy if exists audit_read on public.audit_history; create policy audit_read on public.audit_history for select to authenticated using (true);

grant select on public.profiles,public.works,public.actions,public.accompaniments,public.audit_history to authenticated;
grant insert,update,delete on public.works,public.actions,public.accompaniments to authenticated;
grant update on public.profiles to authenticated;

-- Realtime: execute uma única vez se ainda não estiverem na publicação.
do $$ begin if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='works') then alter publication supabase_realtime add table public.works; end if; if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='actions') then alter publication supabase_realtime add table public.actions; end if; if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='accompaniments') then alter publication supabase_realtime add table public.accompaniments; end if; end $$;

-- Após criar seu primeiro usuário, transforme-o em administrador substituindo o e-mail:
-- update public.profiles set role='admin' where email='seu.email@empresa.com';
