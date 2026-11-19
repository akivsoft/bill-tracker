alter table public.loans
  add column if not exists category_id uuid
  references public.categories(id) on delete set null;

create index if not exists loans_category_id_idx
  on public.loans (category_id);
