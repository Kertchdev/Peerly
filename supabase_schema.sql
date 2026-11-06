-- ==========================================================================
-- PEERLY — Schéma SQL Supabase Production
-- Projet : epzlruthepowahtihulo
-- "Learn from peers. Grow together."
-- ==========================================================================

-- 1. Table des Campus / Établissements
create table if not exists public.campuses (
  id uuid default gen_random_uuid() primary key,
  name text not null unique,
  city text not null,
  domain text,
  students_count int default 0,
  created_at timestamp with time zone default now()
);

-- Insertion des campus initiaux
insert into public.campuses (name, city, domain, students_count) values
  ('EFREI Paris', 'Villejuif', 'efrei.net', 42),
  ('Sorbonne Université', 'Paris', 'sorbonne-universite.fr', 68),
  ('Université Paris-Dauphine', 'Paris', 'dauphine.psl.eu', 35),
  ('INSA Lyon', 'Villeurbanne', 'insa-lyon.fr', 51),
  ('CentraleSupélec', 'Gif-sur-Yvette', 'centralesupelec.fr', 29)
on conflict (name) do nothing;

-- 2. Table des profils utilisateurs
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text not null,
  email text,
  avatar_url text default 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop&crop=face',
  school text default 'EFREI Paris',
  campus_id uuid references public.campuses(id) on delete set null,
  level text default 'Ingé 2',
  bio text,
  tickets_balance int default 3 check (tickets_balance >= 0),
  tickets_reset_date timestamp with time zone default (now() + interval '7 days'),
  is_premium boolean default false,
  is_admin boolean default false,
  is_banned boolean default false,
  rating numeric(3,2) default 4.90,
  sessions_count int default 0,
  created_at timestamp with time zone default now()
);

-- 3. Table des compétences (ce que l'étudiant maîtrise ou cherche à apprendre)
create table if not exists public.skills (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  subject text not null,
  topic text,
  skill_type text not null check (skill_type in ('teach', 'learn')),
  level int default 3 check (level between 1 and 5),
  created_at timestamp with time zone default now()
);

-- 4. Table des disponibilités récurrentes des aidants
create table if not exists public.availabilities (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  day_of_week text not null check (day_of_week in ('Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche')),
  start_time time not null,
  end_time time not null,
  created_at timestamp with time zone default now()
);

-- 5. Table des sessions d'entraide
create table if not exists public.sessions (
  id uuid default gen_random_uuid() primary key,
  student_id uuid references public.profiles(id) on delete set null,
  tutor_id uuid references public.profiles(id) on delete set null,
  subject text not null,
  topic text,
  session_date date not null default current_date,
  start_time time not null default '10:30',
  duration_minutes int default 30 check (duration_minutes in (30, 45, 60, 90)),
  format text default 'visio' check (format in ('visio', 'message', 'presentiel')),
  status text default 'accepted' check (status in ('pending', 'accepted', 'in_progress', 'completed', 'cancelled', 'refused')),
  tickets_cost int default 1,
  room_id text default ('peerly-room-' || substring(gen_random_uuid()::text from 1 for 8)),
  notes text,
  review_rating int check (review_rating between 1 and 5),
  review_comment text,
  created_at timestamp with time zone default now()
);

-- 6. Table des messages (Chat communautaire libre & échanges de session)
create table if not exists public.messages (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  is_free_chat boolean default true,
  created_at timestamp with time zone default now()
);

-- 7. Table des questions & réponses de la communauté (Forum d'entraide ouvert)
create table if not exists public.community_questions (
  id uuid default gen_random_uuid() primary key,
  author_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  content text not null,
  subject text not null,
  is_solved boolean default false,
  answers_count int default 0,
  created_at timestamp with time zone default now()
);

create table if not exists public.community_answers (
  id uuid default gen_random_uuid() primary key,
  question_id uuid references public.community_questions(id) on delete cascade not null,
  author_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  is_accepted boolean default false,
  created_at timestamp with time zone default now()
);

-- 8. Table des transactions de tickets
create table if not exists public.ticket_transactions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  amount int not null,
  transaction_type text not null check (transaction_type in ('weekly_grant', 'session_spent', 'purchase', 'bonus_teaching', 'admin_adjustment')),
  description text not null,
  created_at timestamp with time zone default now()
);

-- 9. Table des signalements pour modération admin
create table if not exists public.reports (
  id uuid default gen_random_uuid() primary key,
  reporter_id uuid references public.profiles(id) on delete set null,
  reported_user_id uuid references public.profiles(id) on delete cascade not null,
  session_id uuid references public.sessions(id) on delete set null,
  reason text not null,
  status text default 'pending' check (status in ('pending', 'resolved', 'dismissed')),
  created_at timestamp with time zone default now()
);

-- ==========================================================================
-- SÉCURITÉ & ROW LEVEL SECURITY (RLS)
-- ==========================================================================
alter table public.campuses enable row level security;
alter table public.profiles enable row level security;
alter table public.skills enable row level security;
alter table public.availabilities enable row level security;
alter table public.sessions enable row level security;
alter table public.messages enable row level security;
alter table public.community_questions enable row level security;
alter table public.community_answers enable row level security;
alter table public.ticket_transactions enable row level security;
alter table public.reports enable row level security;

-- Politiques RLS permissives et sécurisées
create policy "Campuses visibles par tous" on public.campuses for select using (true);
create policy "Profils visibles par tous" on public.profiles for select using (true);
create policy "Modification de son propre profil" on public.profiles for update using (auth.uid() = id);
create policy "Suppression de son propre compte" on public.profiles for delete using (auth.uid() = id);

create policy "Compétences visibles par tous" on public.skills for select using (true);
create policy "Gestion de ses compétences" on public.skills for all using (auth.uid() = user_id);

create policy "Disponibilités visibles par tous" on public.availabilities for select using (true);
create policy "Gestion de ses disponibilités" on public.availabilities for all using (auth.uid() = user_id);

create policy "Voir ses sessions" on public.sessions for select using (auth.uid() = student_id or auth.uid() = tutor_id or exists(select 1 from public.profiles where id = auth.uid() and is_admin = true));
create policy "Créer une session" on public.sessions for insert with check (auth.uid() = student_id or auth.uid() = tutor_id);
create policy "Modifier une session" on public.sessions for update using (auth.uid() = student_id or auth.uid() = tutor_id or exists(select 1 from public.profiles where id = auth.uid() and is_admin = true));

create policy "Voir ses messages" on public.messages for select using (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "Envoyer un message" on public.messages for insert with check (auth.uid() = sender_id);

create policy "Questions communautaires visibles" on public.community_questions for select using (true);
create policy "Créer une question communautaire" on public.community_questions for insert with check (auth.uid() = author_id);

create policy "Réponses communautaires visibles" on public.community_answers for select using (true);
create policy "Créer une réponse communautaire" on public.community_answers for insert with check (auth.uid() = author_id);

create policy "Voir ses transactions de tickets" on public.ticket_transactions for select using (auth.uid() = user_id or exists(select 1 from public.profiles where id = auth.uid() and is_admin = true));

create policy "Admin modération" on public.reports for all using (exists(select 1 from public.profiles where id = auth.uid() and is_admin = true) or auth.uid() = reporter_id);

-- Publications Realtime
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.sessions;
alter publication supabase_realtime add table public.community_questions;
alter publication supabase_realtime add table public.profiles;
