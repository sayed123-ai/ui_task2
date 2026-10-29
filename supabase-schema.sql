-- ================================================================
-- M&M-Nitte: Mentorship OS - Database Schema
-- Run this in your Supabase SQL Editor to set up tables and policies
-- ================================================================

-- 1. Profiles Table
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text not null,
  role text not null check (role in ('mentee', 'mentor', 'hod')),
  department text,
  created_at timestamptz default now()
);

-- Enable RLS on profiles
alter table public.profiles enable row level security;

create policy "Public profiles are viewable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

create policy "Users can insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

-- 2. Mentee Details Table
create table if not exists public.mentee_details (
  id uuid references public.profiles(id) on delete cascade primary key,
  student_id text,
  cgpa numeric(3, 2),
  year text,
  semester text,
  skills text[] default '{}',
  career_goals text,
  achievements text,
  project_links text,
  bio text,
  updated_at timestamptz default now()
);

alter table public.mentee_details enable row level security;

create policy "Mentee details viewable by authenticated users"
  on public.mentee_details for select
  to authenticated
  using (true);

create policy "Mentees can upsert their own details"
  on public.mentee_details for all
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- 3. Mentorships (Relationships between Mentors and Mentees)
create table if not exists public.mentorships (
  id uuid default gen_random_uuid() primary key,
  mentee_id uuid references public.profiles(id) on delete cascade not null,
  mentor_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(mentee_id, mentor_id)
);

alter table public.mentorships enable row level security;

create policy "Mentorships viewable by authenticated users"
  on public.mentorships for select
  to authenticated
  using (true);

create policy "Mentors can adopt mentees"
  on public.mentorships for insert
  to authenticated
  with check (auth.uid() = mentor_id);

-- 4. Mentorship Notes
create table if not exists public.notes (
  id uuid default gen_random_uuid() primary key,
  mentorship_id uuid references public.mentorships(id) on delete cascade not null,
  mentee_id uuid references public.profiles(id) on delete cascade not null,
  author_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  content text not null,
  category text default 'general' check (category in ('general', 'strength', 'improvement', 'goal')),
  created_at timestamptz default now()
);

alter table public.notes enable row level security;

create policy "Notes viewable by involved parties"
  on public.notes for select
  to authenticated
  using (auth.uid() = mentee_id or auth.uid() = author_id or exists (
    select 1 from public.profiles where id = auth.uid() and role = 'hod'
  ));

create policy "Mentors can insert notes"
  on public.notes for insert
  to authenticated
  with check (auth.uid() = author_id);

-- 5. Recommendations
create table if not exists public.recommendations (
  id uuid default gen_random_uuid() primary key,
  mentorship_id uuid references public.mentorships(id) on delete cascade not null,
  mentee_id uuid references public.profiles(id) on delete cascade not null,
  mentor_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  body text not null,
  skill_tags text[] default '{}',
  status text default 'pending' check (status in ('pending', 'endorsed')),
  created_at timestamptz default now()
);

alter table public.recommendations enable row level security;

create policy "Recommendations viewable by authenticated users"
  on public.recommendations for select
  to authenticated
  using (true);

create policy "Mentors can create recommendations"
  on public.recommendations for insert
  to authenticated
  with check (auth.uid() = mentor_id);

create policy "Status updatable by HOD or author"
  on public.recommendations for update
  to authenticated
  using (auth.uid() = mentor_id or exists (
    select 1 from public.profiles where id = auth.uid() and role = 'hod'
  ));

-- 6. Endorsements (by HOD)
create table if not exists public.endorsements (
  id uuid default gen_random_uuid() primary key,
  recommendation_id uuid references public.recommendations(id) on delete cascade not null,
  hod_id uuid references public.profiles(id) on delete cascade not null,
  comment text not null,
  created_at timestamptz default now()
);

alter table public.endorsements enable row level security;

create policy "Endorsements viewable by authenticated users"
  on public.endorsements for select
  to authenticated
  using (true);

create policy "HOD can create endorsements"
  on public.endorsements for insert
  to authenticated
  with check (auth.uid() = hod_id);
