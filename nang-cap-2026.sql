-- Ông Già Noel 2026: bổ sung quản lý ảnh quà, mã đơn, tra cứu trạng thái,
-- khung giờ vàng và Storage policies.
-- Migration này đã được chạy trên Supabase project hiện tại.

alter table public.gifts add column if not exists image_url text;
alter table public.orders add column if not exists booking_code text;
alter table public.orders add column if not exists surcharge_amount numeric(12,0) not null default 0;
alter table public.orders add column if not exists archived_at timestamptz;
update public.orders set booking_code='NOEL-'||upper(substr(replace(id::text,'-',''),1,8)) where booking_code is null;
create unique index if not exists orders_booking_code_uidx on public.orders(booking_code);

create table if not exists public.booking_settings (
  id boolean primary key default true check (id=true),
  golden_enabled boolean not null default false,
  golden_start time not null default '19:00',
  golden_end time not null default '21:00',
  golden_surcharge numeric(12,0) not null default 0,
  zalo_url text,
  updated_at timestamptz not null default now()
);
insert into public.booking_settings(id) values(true) on conflict(id) do nothing;
alter table public.booking_settings enable row level security;
drop policy if exists "public read booking settings" on public.booking_settings;
create policy "public read booking settings" on public.booking_settings for select to anon, authenticated using (true);
drop policy if exists "admin manage booking settings" on public.booking_settings;
create policy "admin manage booking settings" on public.booking_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());
grant select on public.booking_settings to anon, authenticated;
grant insert,update,delete on public.booking_settings to authenticated;

create or replace function public.apply_golden_surcharge()
returns trigger language plpgsql set search_path=public as $$
declare cfg public.booking_settings%rowtype; local_time time;
begin
  if new.id is not null then
    new.booking_code := 'NOEL-' || upper(substr(replace(new.id::text,'-',''),1,8));
  end if;
  select * into cfg from public.booking_settings where id=true;
  local_time := (new.visit_at at time zone 'Asia/Ho_Chi_Minh')::time;
  new.surcharge_amount := 0;
  if coalesce(cfg.golden_enabled,false) and cfg.golden_surcharge>0 then
    if (cfg.golden_start<=cfg.golden_end and local_time>=cfg.golden_start and local_time<cfg.golden_end)
       or (cfg.golden_start>cfg.golden_end and (local_time>=cfg.golden_start or local_time<cfg.golden_end)) then
      new.surcharge_amount := cfg.golden_surcharge;
    end if;
  end if;
  new.total_amount := coalesce(new.service_price,0)+coalesce(new.gifts_price,0)+new.surcharge_amount;
  return new;
end $$;
drop trigger if exists trg_apply_golden_surcharge on public.orders;
create trigger trg_apply_golden_surcharge before insert or update of visit_at,service_price,gifts_price on public.orders
for each row execute function public.apply_golden_surcharge();
update public.orders set booking_code='NOEL-'||upper(substr(replace(id::text,'-',''),1,8));

create or replace function public.lookup_booking_status(p_booking_code text,p_phone text)
returns table(booking_code text,status text,visit_at timestamptz,service_name text,gifts_price numeric,surcharge_amount numeric,total_amount numeric)
language sql stable security definer set search_path=public as $$
  select o.booking_code,o.status,o.visit_at,o.service_name,o.gifts_price,o.surcharge_amount,o.total_amount
  from public.orders o
  where upper(o.booking_code)=upper(trim(p_booking_code))
    and regexp_replace(o.phone,'[^0-9]','','g')=regexp_replace(coalesce(p_phone,''),'[^0-9]','','g')
    and o.archived_at is null
  limit 1;
$$;
revoke all on function public.lookup_booking_status(text,text) from public;
grant execute on function public.lookup_booking_status(text,text) to anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('gifts','gifts',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists "public read gift images" on storage.objects;
create policy "public read gift images" on storage.objects for select to anon,authenticated using (bucket_id='gifts');
drop policy if exists "admin upload gift images" on storage.objects;
create policy "admin upload gift images" on storage.objects for insert to authenticated with check (bucket_id='gifts' and public.is_admin());
drop policy if exists "admin update gift images" on storage.objects;
create policy "admin update gift images" on storage.objects for update to authenticated using (bucket_id='gifts' and public.is_admin()) with check (bucket_id='gifts' and public.is_admin());
drop policy if exists "admin delete gift images" on storage.objects;
create policy "admin delete gift images" on storage.objects for delete to authenticated using (bucket_id='gifts' and public.is_admin());


-- Cho phép xóa món quà khỏi danh mục mà vẫn giữ lịch sử quà trong đơn cũ.
-- Khi xóa gifts.id, order_gifts.gift_id được đặt NULL; gift_name và unit_price vẫn còn.
alter table public.order_gifts drop constraint if exists order_gifts_gift_id_fkey;
alter table public.order_gifts
  add constraint order_gifts_gift_id_fkey
  foreign key (gift_id) references public.gifts(id)
  on delete set null;
