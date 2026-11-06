-- ==========================================================================
-- PEERLY — Schéma SQL Supabase Complet
-- Projet : epzlruthepowahtihulo
-- "Learn from peers. Grow together."
-- ==========================================================================

-- 1. Table des profils utilisateurs
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text not null,
  email text,
  avatar_url text,
  school text default 'Université / École',
  level text default 'Étudiant',
  bio text,
  tickets_balance int default 3 check (tickets_balance >= 0),
  tickets_reset_date timestamp with time zone default (now() + interval '7 days'),
  is_premium boolean default false,
  rating numeric(3,2) default 4.90,
  sessions_count int default 0,
  created_at timestamp with time zone default now()
);

-- 2. Table des compétences (ce que l'étudiant maîtrise ou cherche à apprendre)
create table if not exists public.skills (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  subject text not null,
  topic text,
  skill_type text not null check (skill_type in ('teach', 'learn')),
  level int default 3 check (level between 1 and 5),
  created_at timestamp with time zone default now()
);

-- 3. Table des sessions d'entraide
create table if not exists public.sessions (
  id uuid default gen_random_uuid() primary key,
  student_id uuid references public.profiles(id) on delete set null not null,
  tutor_id uuid references public.profiles(id) on delete set null not null,
  subject text not null,
  topic text,
  session_date date not null default current_date,
  start_time time not null default '10:30',
  duration_minutes int default 30 check (duration_minutes in (30, 45, 60, 90)),
  format text default 'visio' check (format in ('visio', 'message', 'presentiel')),
  status text default 'accepted' check (status in ('pending', 'accepted', 'in_progress', 'completed', 'cancelled')),
  tickets_cost int default 1,
  room_id text default ('peerly-room-' || substring(gen_random_uuid()::text from 1 for 8)),
  notes text,
  created_at timestamp with time zone default now()
);

-- 4. Table des messages (Chat communautaire 100% gratuit & messagerie de session)
create table if not exists public.messages (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  is_free_chat boolean default true,
  created_at timestamp with time zone default now()
);

-- 5. Table de l'historique des tickets
create table if not exists public.ticket_transactions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  amount int not null,
  transaction_type text not null check (transaction_type in ('weekly_grant', 'session_spent', 'purchase', 'bonus_teaching')),
  description text not null,
  created_at timestamp with time zone default now()
);

-- ==========================================================================
-- SÉCURITÉ & ROW LEVEL SECURITY (RLS)
-- ==========================================================================
alter table public.profiles enable row level security;
alter table public.skills enable row level security;
alter table public.sessions enable row level security;
alter table public.messages enable row level security;
alter table public.ticket_transactions enable row level security;

-- Politiques RLS simples et permissives pour le démarrage
create policy "Les profils sont visibles par tous les membres connectés"
  on public.profiles for select using (true);

create policy "Les utilisateurs peuvent modifier leur propre profil"
  on public.profiles for update using (auth.uid() = id);

create policy "Les compétences sont visibles par tous"
  on public.skills for select using (true);

create policy "Gestion de ses propres compétences"
  on public.skills for all using (auth.uid() = user_id);

create policy "Voir les sessions auxquelles on participe"
  on public.sessions for select using (auth.uid() = student_id or auth.uid() = tutor_id);

create policy "Créer une session"
  on public.sessions for insert with check (auth.uid() = student_id);

create policy "Modifier sa session"
  on public.sessions for update using (auth.uid() = student_id or auth.uid() = tutor_id);

create policy "Voir ses messages reçus ou envoyés"
  on public.messages for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "Envoyer un message"
  on public.messages for insert with check (auth.uid() = sender_id);

create policy "Voir son historique de tickets"
  on public.ticket_transactions for select using (auth.uid() = user_id);

-- ==========================================================================
-- REALTIME
-- ==========================================================================
-- Activation du temps réel pour les messages et les sessions
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.sessions;
alter publication supabase_realtime add table public.profiles;
