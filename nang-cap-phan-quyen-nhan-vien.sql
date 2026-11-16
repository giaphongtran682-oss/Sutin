-- Phân quyền nhân viên bằng mã riêng, mã hóa bcrypt, phiên có thời hạn 12 giờ.
-- Đã áp dụng trực tiếp trên Supabase project yvqoypzlafrscuxkesao ngày 16/11/2026.
-- Không cần chạy lại khi thay file admin.html.

create extension if not exists pgcrypto with schema extensions;
alter table public.staff add column if not exists access_code_hash text, add column if not exists access_code_fingerprint text;
create unique index if not exists staff_access_code_fingerprint_uidx on public.staff(access_code_fingerprint) where access_code_fingerprint is not null;
create table if not exists public.staff_code_sessions (id uuid primary key default gen_random_uuid(), staff_id uuid not null references public.staff(id) on delete cascade, token_hash text not null unique, expires_at timestamptz not null, created_at timestamptz not null default now());
alter table public.staff_code_sessions enable row level security;
revoke all on public.staff_code_sessions from anon, authenticated;

create or replace function public.admin_set_staff_code(p_staff_id uuid,p_code text) returns void language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare v_code text:=trim(coalesce(p_code,'')); begin
 if not public.is_admin() then raise exception 'Chỉ quản trị viên mới được cấp mã nhân viên'; end if;
 if length(v_code)<8 or length(v_code)>32 then raise exception 'Mã đăng nhập phải từ 8 đến 32 ký tự'; end if;
 if v_code !~ '^[A-Za-z0-9_-]+$' then raise exception 'Mã chỉ được gồm chữ, số, dấu gạch ngang hoặc gạch dưới'; end if;
 update public.staff set access_code_hash=extensions.crypt(v_code,extensions.gen_salt('bf',12)),access_code_fingerprint=encode(extensions.digest(lower(v_code),'sha256'),'hex') where id=p_staff_id;
 if not found then raise exception 'Không tìm thấy nhân viên'; end if;
 delete from public.staff_code_sessions where staff_id=p_staff_id; end $$;

create or replace function public.staff_code_login(p_code text) returns jsonb language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare v_staff public.staff%rowtype;v_token text;begin
 select * into v_staff from public.staff where active=true and access_code_fingerprint=encode(extensions.digest(lower(trim(coalesce(p_code,''))),'sha256'),'hex') limit 1;
 if v_staff.id is null or v_staff.access_code_hash is null or extensions.crypt(trim(coalesce(p_code,'')),v_staff.access_code_hash)<>v_staff.access_code_hash then raise exception 'Mã nhân viên không đúng hoặc đã bị thu hồi'; end if;
 v_token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
 insert into public.staff_code_sessions(staff_id,token_hash,expires_at) values(v_staff.id,encode(extensions.digest(v_token,'sha256'),'hex'),now()+interval '12 hours');
 return jsonb_build_object('token',v_token,'staff_id',v_staff.id,'staff_name',v_staff.name,'expires_in',43200);end $$;

create or replace function public.staff_get_orders(p_token text) returns jsonb language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare v_staff public.staff%rowtype;v_result jsonb;begin
 select s.* into v_staff from public.staff_code_sessions cs join public.staff s on s.id=cs.staff_id where cs.token_hash=encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex') and cs.expires_at>now() and s.active=true limit 1;
 if v_staff.id is null then raise exception 'Phiên đăng nhập hết hạn hoặc mã đã bị đổi';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'booking_code',o.booking_code,'customer_name',o.customer_name,'phone',o.phone,'child_name',o.child_name,'address',o.address,'visit_at',o.visit_at,'service_name',o.service_name,'service_price',o.service_price,'gifts_price',o.gifts_price,'total_amount',o.total_amount,'status',o.status,'note',o.note,'staff_id',o.staff_id,'created_at',o.created_at,'gift_items',coalesce((select jsonb_agg(jsonb_build_object('gift_name',og.gift_name,'unit_price',og.unit_price,'quantity',og.quantity)) from public.order_gifts og where og.order_id=o.id),'[]'::jsonb)) order by o.visit_at asc),'[]'::jsonb) into v_result from public.orders o where o.archived_at is null and o.status not in ('cancelled','completed') and (o.staff_id is null or o.staff_id=v_staff.id);
 return jsonb_build_object('staff_name',v_staff.name,'staff_id',v_staff.id,'orders',v_result);end $$;

create or replace function public.staff_claim_order(p_token text,p_order_id uuid) returns jsonb language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare v_staff public.staff%rowtype;v_order public.orders%rowtype;begin
 select s.* into v_staff from public.staff_code_sessions cs join public.staff s on s.id=cs.staff_id where cs.token_hash=encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex') and cs.expires_at>now() and s.active=true limit 1;
 if v_staff.id is null then raise exception 'Phiên đăng nhập hết hạn hoặc mã đã bị đổi';end if;
 update public.orders set staff_id=v_staff.id,status='assigned' where id=p_order_id and staff_id is null and status in ('pending','confirmed') and archived_at is null returning * into v_order;
 if v_order.id is null then raise exception 'Đơn này đã được nhân viên khác nhận hoặc không còn khả dụng';end if;
 return jsonb_build_object('success',true,'booking_code',v_order.booking_code);end $$;

create or replace function public.revoke_staff_sessions_when_disabled() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$ begin if old.active is distinct from new.active and new.active=false then delete from public.staff_code_sessions where staff_id=new.id;end if;return new;end $$;
drop trigger if exists trg_revoke_staff_sessions_when_disabled on public.staff;
create trigger trg_revoke_staff_sessions_when_disabled after update of active on public.staff for each row execute function public.revoke_staff_sessions_when_disabled();
revoke all on function public.admin_set_staff_code(uuid,text) from public,anon;grant execute on function public.admin_set_staff_code(uuid,text) to authenticated;
revoke all on function public.staff_code_login(text) from public;grant execute on function public.staff_code_login(text) to anon,authenticated;
revoke all on function public.staff_get_orders(text) from public;grant execute on function public.staff_get_orders(text) to anon,authenticated;
revoke all on function public.staff_claim_order(text,uuid) from public;grant execute on function public.staff_claim_order(text,uuid) to anon,authenticated;
