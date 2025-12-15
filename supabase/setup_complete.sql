-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Branches table (stores all acrostics/mnemonics)
CREATE TABLE branches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  level TEXT NOT NULL CHECK (level IN ('testament', 'book', 'chapter', 'verse')),
  reference TEXT NOT NULL, -- 'OT' | 'NT' | 'GEN' | 'EXO' | 'GEN.1' | 'GEN.2' | 'GEN.1.1' | 'GEN.1.2'
  parent_branch_id UUID REFERENCES branches(id),
  content TEXT NOT NULL, -- the actual mnemonic/acrostic text
  letter_constraint CHAR(1), -- the required first letter from parent acrostic
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  is_canonical BOOLEAN DEFAULT FALSE, -- admin marks which branches are in official export
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'archived', 'flagged'))
);

-- Votes table
CREATE TABLE votes (
  user_id UUID REFERENCES auth.users(id),
  branch_id UUID REFERENCES branches(id),
  vote_value INTEGER CHECK (vote_value IN (-1, 1)),
  voted_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (user_id, branch_id)
);

-- User profiles extension (extends Supabase auth.users)
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  display_name TEXT,
  is_admin BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Admin settings
CREATE TABLE admin_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL
);

-- Insert default admin settings
INSERT INTO admin_settings (key, value) VALUES 
  ('editable_levels', '{"testament": true, "book": true, "chapter": false, "verse": false}'::jsonb),
  ('require_approval', 'false'::jsonb),
  ('canonical_branches', '{}'::jsonb); -- Stores selected branch IDs for canonical export

-- Export versions tracking
CREATE TABLE export_versions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  version TEXT NOT NULL, -- e.g., "1.0", "1.1"
  type TEXT CHECK (type IN ('canonical', 'community')),
  created_by UUID REFERENCES auth.users(id),
  branch_selections JSONB NOT NULL, -- Maps references to branch IDs
  json_content JSONB NOT NULL, -- The actual compiled export
  created_at TIMESTAMP DEFAULT NOW(),
  download_count INTEGER DEFAULT 0
);

-- Create indexes for performance
CREATE INDEX idx_branches_reference ON branches(reference);
CREATE INDEX idx_branches_level ON branches(level);
CREATE INDEX idx_branches_parent ON branches(parent_branch_id);
CREATE INDEX idx_branches_canonical ON branches(is_canonical);
CREATE INDEX idx_votes_branch ON votes(branch_id);
CREATE INDEX idx_votes_user ON votes(user_id);

-- Row Level Security (RLS) Policies
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE export_versions ENABLE ROW LEVEL SECURITY;

-- Branches: Everyone can read
CREATE POLICY "Branches are viewable by everyone" 
  ON branches FOR SELECT 
  USING (true);

-- Branches: Authenticated users can create
CREATE POLICY "Authenticated users can create branches" 
  ON branches FOR INSERT 
  WITH CHECK (auth.uid() = created_by);

-- Branches: Users can update their own, admins can update any
CREATE POLICY "Users can update own branches, admins update any" 
  ON branches FOR UPDATE 
  USING (
    auth.uid() = created_by OR 
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- Votes: Everyone can read
CREATE POLICY "Votes are viewable by everyone" 
  ON votes FOR SELECT 
  USING (true);

-- Votes: Users can insert/update their own votes
CREATE POLICY "Users can manage their votes" 
  ON votes FOR ALL 
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- User profiles: Everyone can read
CREATE POLICY "Profiles are viewable by everyone" 
  ON user_profiles FOR SELECT 
  USING (true);

-- User profiles: Users can update their own
CREATE POLICY "Users can update own profile" 
  ON user_profiles FOR UPDATE 
  USING (auth.uid() = id);

-- Admin settings: Everyone can read, only admins can write
CREATE POLICY "Admin settings readable by all" 
  ON admin_settings FOR SELECT 
  USING (true);

CREATE POLICY "Only admins can modify settings" 
  ON admin_settings FOR ALL 
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true));

-- Export versions: Everyone can read
CREATE POLICY "Export versions are viewable by everyone" 
  ON export_versions FOR SELECT 
  USING (true);

-- Export versions: Only admins can create canonical, users can create community
CREATE POLICY "Users can create exports" 
  ON export_versions FOR INSERT 
  WITH CHECK (
    (type = 'community' AND auth.uid() = created_by) OR
    (type = 'canonical' AND EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true))
  );
-- Full Seed Data generated from bibleMnemonics.json
-- Run this in Supabase SQL Editor

BEGIN;

-- 1. Testaments

-- Function to generate deterministic IDs for seed data
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    
INSERT INTO branches (id, level, reference, content, is_canonical, status)
VALUES ('fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'testament', 'OT', 'FIRST IS THE STORY OF TRUTH ABOUT EVERYONE''S SIN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;

INSERT INTO branches (id, level, reference, content, is_canonical, status)
VALUES ('5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'testament', 'NT', 'JESUS SENT HIS SPIRIT TO ALL OF US', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;

-- Books
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'book', 'GEN', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'FIRST GOD CREATES ADAM THEN CHOOSES ABRAHAM ISAAC AND JACOB', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f497f1b2-03c2-9285-87b2-933979e489d4', 'chapter', 'GEN.1', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'FIRST GOD MADE HEAVENS AND EARTH GOOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f2215e60-26bc-c7b3-aaaa-33e295122aef', 'chapter', 'GEN.2', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'IN EDEN GOD MADE A WOMAN FOR HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('24b7d0d1-5302-2e6b-b80e-48a6a4a39a7d', 'chapter', 'GEN.3', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'REBELLION BROUGHT SIN TO ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3008056d-8653-e405-a8b0-3bb1654a7ffc', 'chapter', 'GEN.4', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'SIN OF CAIN KILLED BROTHER ABEL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8de91763-621c-338f-979e-9c2c56203b3b', 'chapter', 'GEN.5', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'THE GENERATIONS OF ADAM ARE TOLD FULLY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('24a2993a-acf8-049c-56ba-f10e738e4be7', 'chapter', 'GEN.6', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'GREAT FLOOD IS COMING SOON', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a6eec0dc-e802-d096-2e67-b70b19b67e66', 'chapter', 'GEN.7', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'ON ARK NOAH SAVED WITH FAMILY ', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a84fc218-ebe6-cabd-1f1e-dfa575bd9500', 'chapter', 'GEN.8', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'DRY LAND APPEARS ON EARTHS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('828cab37-61ef-4c57-b745-fea0cc1bd031', 'chapter', 'GEN.9', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'CREATOR MAKES A COVENANT WITH MANS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('53af8da0-ff5c-7197-3ffa-11f8ecc72c46', 'chapter', 'GEN.10', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'RECORD OF THE NATIONS FROM NOAHS SEEDS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('db5c69ff-5753-9f2f-0b72-21383175c5ca', 'chapter', 'GEN.11', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'EVERYONE HAD ONE LANGUAGE AT THE BABEL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7d19164c-e19e-117e-7e99-ef58886eb467', 'chapter', 'GEN.12', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'ABRAM CALLED BY GOD IN UR', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9ea534e7-93f1-7215-1c6d-8c42d79c1428', 'chapter', 'GEN.13', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'TO ABRAM LAND IS GIVEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1ac3f3f2-f66d-a8aa-0d97-9497db483e15', 'chapter', 'GEN.14', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'ENEMIES CAPTURE LOT IN FIGHT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('536a6929-3a30-bbb1-8eb5-2d91fea26a1e', 'chapter', 'GEN.15', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'SIGNS OF COVENANT ARE CUT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d5feef94-e5ba-9c78-203e-d9f8d43fbfd3', 'chapter', 'GEN.16', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'AGAR BEARS A SON SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f1317d81-496d-4618-dbb3-58f8917d46e3', 'chapter', 'GEN.17', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'DIVINE PACT OF CIRCUMCISION HIS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('14c5d973-dfa6-1f1d-68a9-a3271a9b7a91', 'chapter', 'GEN.18', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'ABRAHAM PLEADS FOR SINFUL SODOM CITIES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('545ee19b-48d4-1308-90ea-a87b746db0c8', 'chapter', 'GEN.19', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'MY GOD DESTROYS SODOM AND GOMORRAH WITH FIRES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('601f864a-6218-857e-4161-199a7003515f', 'chapter', 'GEN.20', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'THEN ABRAHAM PRAYERS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d5f9d79b-b3cd-6a71-a8e7-d2980c50d58b', 'chapter', 'GEN.21', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'HAGAR AND ISHMAEL SENT TO THE WILDERNESS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('82701524-5bb5-0b5c-a475-c844f50f6c58', 'chapter', 'GEN.22', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'ELOHIM TESTS ABRAHAMS FAITH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('98abb0a3-eae2-a89a-d516-9fbf3a074446', 'chapter', 'GEN.23', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'NOW SARAH DIES IN HEBRON', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a9577cc5-3e92-1076-2c77-13b8b7c34789', 'chapter', 'GEN.24', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'CHOSEN REBEKAH WATERS CAMELS AND GOES TO MARRY ISAAC THE SON OF ABRAHAM TODAY SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('462e321e-611f-94bd-e623-41cdb27ec675', 'chapter', 'GEN.25', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'HUNGRY ESAU SOLD HIS BIRTHRIGHT TO JACOB', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e0f5f1a8-05d3-d444-64e1-f1f7f3c700e1', 'chapter', 'GEN.26', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'OATH BETWEEN ISAAC AND KING ABIMELECH HIS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9c2ff617-3676-773d-3696-be7ce158743e', 'chapter', 'GEN.27', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'ON ISAAC A TRICK IS PLAYED BY JACOB HE GETS THE BLESSINGS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1032eb3c-07a9-5799-9e88-88d82f180bd4', 'chapter', 'GEN.28', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'STAIRWAY TO HEAVEN IS SEEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c2bf3dd2-8983-c0be-f6f1-0ee8260ba758', 'chapter', 'GEN.29', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'ENDED UP WITH LEAH INSTEAD OF RACHEL THERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('34523b56-f8dd-0940-d07a-6f836127f417', 'chapter', 'GEN.30', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'SONS ARE BORN TO JACOB AND HE GETS FLOCKS OF MY CATTLE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('030620db-60d3-c96a-c5ef-9b6424a3043d', 'chapter', 'GEN.31', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'AND JACOB FLEES FROM LABAN WITH HIS WIVES AND CHILDREN AND FLOCKS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3116e8a6-e9d3-5338-51d3-3abd76856949', 'chapter', 'GEN.32', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'BY JABBOK JACOB WRESTLES WITH AN ANGEL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1d4fa94f-95b1-f23c-a237-6c9c3a892e4b', 'chapter', 'GEN.33', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'RECONCILED WITH FAMILY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('332a48a8-185c-c6b0-064c-e33ad95b2721', 'chapter', 'GEN.34', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'ATTACK ON SHECHEM FOR A SISTER DINAHS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3c8bff61-8150-e46f-07b3-16b280a6de54', 'chapter', 'GEN.35', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'HOUSEHOLD GODS BURIED UNDER AN OAK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('18112356-8015-3ba5-3ae1-26d5e512573c', 'chapter', 'GEN.36', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'ALL THE KINGS AND CHIEFS OF EDOM ARE LISTED TODAY SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c77d91ed-346c-55f5-9e5a-c9c6556ffe2b', 'chapter', 'GEN.37', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'MANY COLORS COAT GIVEN TO JOSEPH BY ISRAELS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('552cd61b-9614-e902-2cbf-83706b0c84e5', 'chapter', 'GEN.38', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'INTRIGUE OF TAMAR AND FATHER JUDAHS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('74a29c89-5f1f-6475-9b00-21802e52d4e8', 'chapter', 'GEN.39', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'SERVANT JOSEPH IS FAITHFUL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eccee190-8ec7-3ee6-1306-c5be67e2224d', 'chapter', 'GEN.40', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'A DREAM OF BUTLER AND BAKERS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fe0da3ef-414a-6957-6b0a-1541e8236e65', 'chapter', 'GEN.41', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'A DREAM OF COWS MEANS JOSEPH IS MADE RULER OVER ALL THE LAND EGYPT THEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4cb98143-7ac8-715d-b6f5-36ea2de29a11', 'chapter', 'GEN.42', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'COME TO EGYPT TO BUY FOOD BROTHERS BOWING DOWN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cb38b216-46a6-215b-94fc-335a52765d13', 'chapter', 'GEN.43', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'AND THEY EAT A FEAST WITH JOSEPH AT MIDDAY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bbdec50a-6ac3-3db8-c8dd-07bd3df1fb80', 'chapter', 'GEN.44', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'NOW THE CUP IS FOUND IN THE YOUNGEST BAG LO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('48189f91-17ea-eb3c-1dd8-49a45309b20b', 'chapter', 'GEN.45', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'DISCLOSED HIMSELF TO HIS KINSMEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('39e0d2a4-c15a-9bd9-b360-3cf338266608', 'chapter', 'GEN.46', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'JACOB SEES JOSEPH AND CAN DIE IN PEACE SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8c82df47-7cf5-372e-5919-83159c4ae359', 'chapter', 'GEN.47', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'AND JACOB BLESSES PHARAOH OF EGYPT LO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c2fb60fb-6a7c-ee67-f821-6fb2602a88e2', 'chapter', 'GEN.48', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'CROSS HANDS TO BLESS A SONS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b499f900-f38d-33f7-6a12-4fe38114d67b', 'chapter', 'GEN.49', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'JACOB BLESSES TWELVE SONS AND DIED WELL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e1a8ffb6-b040-91c0-1960-a1a48aca771c', 'chapter', 'GEN.50', '54ad3fc4-8d21-12ed-e01f-9f93006f57f7', 'BODY OF JACOB IS EMBALMED THERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('704d2fcb-55f3-9e75-8caa-88318c42f44a', 'book', 'EXO', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'ISRAEL IS RESCUED FROM EGYPT AND GIVEN GOD''S LAWS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b8c3ffca-9b4a-a503-9994-2a7d9ce03099', 'chapter', 'EXO.1', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'INCREASED ISRAEL IN EGYPT!', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bae539ea-379a-6ce6-8750-b58d2230e58d', 'chapter', 'EXO.2', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'SON MOSES SAVED FROM THE RIVER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8d40ccab-b455-59ce-b801-c39b790b7105', 'chapter', 'EXO.3', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'RAISED UP AT A BURNING BUSH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7ccd4396-1055-a37b-557b-e566b803a6e2', 'chapter', 'EXO.4', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'AND AARON MEETS A MOSES IN WILDERNESS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a3d1efc8-807d-2cf6-a6b8-17d9415d53da', 'chapter', 'EXO.5', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'EGYPT MAKES THE WORK HARDER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2fd49688-478c-9043-6896-bd7f3bea7b1b', 'chapter', 'EXO.6', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'LEADERS OF LEVITES ARE LISTED THERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fd219d75-e53a-f928-f6d3-21a9d6ec4758', 'chapter', 'EXO.7', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'I WILL MULTIPLY SIGNS AND MIRACLES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5dd4adb6-8c91-5299-3fa0-fcba8f170829', 'chapter', 'EXO.8', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'STORY OF PLAGUES A FROGS LICE AND FLIES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6b9014e6-48c9-2bc0-a6d3-a748803c7e6f', 'chapter', 'EXO.9', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'RECORD OF PLAGUES PESTILENCE BOILS HAILS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9c767656-b184-16b1-0391-50ee06bdf5d6', 'chapter', 'EXO.10', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'EGYPT IS COVERED BY THICK DARKNESS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c3109b8b-b12a-cfae-195a-cb3f9d1c5960', 'chapter', 'EXO.11', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'SAY TO JACOB', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('78417c2a-d44e-bb45-d557-23fb2b84dd8f', 'chapter', 'EXO.12', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'CENTURIES OF SLAVERY END AS ALL ISRAEL LEAVES EGYPT LAND FAST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4da91699-0231-d566-7619-44e5669a643a', 'chapter', 'EXO.13', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'USE UNLEAVENED BREAD HERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1d86e4b7-3184-e18b-716f-6e529db68e06', 'chapter', 'EXO.14', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'ESCAPE THRU THE RED SEA ON DRY LAND SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6ded9aac-dea8-cacd-a71c-f2fbb8914983', 'chapter', 'EXO.15', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'DANCE OF MIRIAM AND THE SONG SUNG', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c7449b8b-e4f7-3328-0d58-df28d7fd3050', 'chapter', 'EXO.16', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'FEEDING ON MANNA AND QUAIL IN THE DESERT AIR', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('35bb4a8c-ca51-2b95-62ba-124e2504b65d', 'chapter', 'EXO.17', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'ROCK IS STRUCK HERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3358cf0d-d6e8-5b1a-02ad-59062cd3c3ab', 'chapter', 'EXO.18', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'OVERSEERS OF ISRAEL CHOSEN HERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a1c08fd7-28a4-bea6-36c2-6ebe3a3564c4', 'chapter', 'EXO.19', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'MOSES MEETS GOD ON MOUNT SINAI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('77319652-39af-ffbc-e980-b4dd94e0cc06', 'chapter', 'EXO.20', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'ENTIRE TEN COMMANDMENTS GIVEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8a686f44-3938-3fb1-c671-8c97a617358b', 'chapter', 'EXO.21', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'GODS LAWS ON SERVANTS AND INJURIES GIVEN OUT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('24ccb51f-2e33-e280-adc8-b92fac0bfcc1', 'chapter', 'EXO.22', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'YOU SHALL NOT OPPRESS POOR STRANGERS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8dbeefd0-f5b8-833d-dcc8-6c2b4d987381', 'chapter', 'EXO.23', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'PILGRIM FEASTS AND ANGEL OF THE LORD GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f8906056-46cd-7906-3d2a-635ac70f9761', 'chapter', 'EXO.24', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'THE BLOOD OF COVENANT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('932a4f69-9d00-5e3f-75dd-5b8c1dae1c0d', 'chapter', 'EXO.25', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'THE ARK OF COVENANT AND TABLE AND LAMPSTAND MADE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('16e15796-f233-d5c4-aa7a-ce68db7881b4', 'chapter', 'EXO.26', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'NUMEROUS CURTAINS BOARDS FOR THE TENTS SETS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ed45e947-f83b-744b-78ec-5e2e4657e288', 'chapter', 'EXO.27', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'DIMENSIONS OF THE ALTARS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('915a18ff-36e2-d294-9f7b-85153e5e9cf9', 'chapter', 'EXO.28', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'GARMENTS FOR AARON AND SONS THE HOLY PRIESTHOOD SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('357dd87f-ae9a-fcc7-5677-7530fec8a08e', 'chapter', 'EXO.29', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'INSTALLATION OF AARON AND SONS AS PRIESTS RITUALS HERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1fcb87bf-d5a7-9b82-799f-c98b07735833', 'chapter', 'EXO.30', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'VARIOUS ITEMS ALTAR INCENSE AND HOLY OIL MADE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ba0d1c54-2443-d789-07bb-8c4b2a858cdd', 'chapter', 'EXO.31', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'EMPLOY BEZALEL SKILL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3d84f7fc-4e25-c8be-cb2b-7188eec264ac', 'chapter', 'EXO.32', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'NOW ISRAEL SINS WITH A GOLDEN CALF AND IDOL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('69d4b2c5-5417-e044-b7f4-663bc1a94065', 'chapter', 'EXO.33', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'GO LEAD THE PEOPLE UP HIGHER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4d705e4f-3b06-5361-f020-91751f14ca12', 'chapter', 'EXO.34', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'OBSERVE FEAST OF WEEKS AND FIRST FRUIT DUE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('21cf5ad9-18fc-7692-3281-97ec00f90a50', 'chapter', 'EXO.35', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'DONATIONS FOR THE TABERNACLE GIVEN IN JOY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('869f5e3b-5758-9b96-e395-c76c7906bff5', 'chapter', 'EXO.36', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'SKILLED WORKMEN MAKE THE TABERNACLE TENT TOP', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dc60148d-4b49-23fa-e64e-aea8e6862da6', 'chapter', 'EXO.37', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'LOOK BEZALEL MAKES THE ARK OF GOD LO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4df0c520-3563-1928-2d77-cf94367d49fd', 'chapter', 'EXO.38', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'ALTAR OF BURNT OFFERING IS BUILT HERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('24672f5c-8449-2adc-81cd-72b539d09dfd', 'chapter', 'EXO.39', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'WELL DONE WORK ON THE TABERNACLE AND THE ROBES TODAY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9f187437-2db9-d187-076b-48cbe2224f7c', 'chapter', 'EXO.40', '704d2fcb-55f3-9e75-8caa-88318c42f44a', 'SO MOSES FINISHED THE WORK GLORY FILLED IT ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bffd8f45-1e5e-40fc-9dec-b063714982b4', 'book', 'LEV', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'RITUALS AND LAWS FOR THE PRIESTS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3fd6d976-aae8-0fed-4d23-d096fb1677d8', 'chapter', 'LEV.1', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'RULES FOR OFFERINGS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c4c5c91c-bf61-3b7c-2152-7338e9ebcedb', 'chapter', 'LEV.2', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'ITEM OF GRAIN OFFER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4ab605f9-78ef-4768-3be5-794d5652963c', 'chapter', 'LEV.3', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'THE PEACE OFFERINGS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6846cc90-504e-41d6-49a0-607a08d83ccb', 'chapter', 'LEV.4', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'UNINTENTIONAL SINS AND THE SIN OFFERINGS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5e750832-a3ad-979e-1077-d50d643d0a45', 'chapter', 'LEV.5', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'ANY GUILT OFFERING FOR THE SINS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('02da8968-e3d2-c16a-63d6-fd2ab5bb2169', 'chapter', 'LEV.6', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'LAWS FOR THE BURNT OFFERING RITUALS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0074e56a-7758-1ea5-0864-d5a5b604b9ad', 'chapter', 'LEV.7', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'SHARE OF AARON AND SONS IN PEACE OFFERINGS SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('51ffe1a9-3d2a-0002-221b-75545eb23f94', 'chapter', 'LEV.8', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'AARON AND HIS SONS CONSECRATED AS PRIESTS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6353228e-60aa-a6b0-e5cc-e20239a2600e', 'chapter', 'LEV.9', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'NOW AARON OFFERS SACRIFICES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e24184a1-398a-3f6e-c33a-67e9b2618b65', 'chapter', 'LEV.10', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'DEATH OF NADAB AND ABIHU', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d6ae30ce-ccc5-c456-00de-67418117a688', 'chapter', 'LEV.11', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'LAWS ON CLEAN AND UNCLEAN ANIMALS FOR FOOD FOR ISRAEL HIS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('24eee22a-c428-8ab2-ea26-d49001286cfa', 'chapter', 'LEV.12', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'A SON BORN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c6413125-8fa6-1c79-b7a9-a7455968cf2c', 'chapter', 'LEV.13', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'WHEN A MAN HAS LEPROSY ON HIS SKIN HE IS DECLARED UNCLEAN BY PRIESTS SEEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('787dde56-152c-4731-b66c-26135e50928b', 'chapter', 'LEV.14', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'SHOW THE PRIEST THE PLAGUE OF LEPROSY IN A HOUSE AND HE SHALL LOOK WELL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('31b8db92-9d2b-17b7-838b-26c69a27186e', 'chapter', 'LEV.15', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'FOR FLUID DISCHARGES FROM A MALE BODIES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('38ab37c1-af35-606a-5faf-06ed0ebc2f40', 'chapter', 'LEV.16', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'ONE GOAT FOR SIN OFFERING ONE SCAPEGOATS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7784d283-f300-e99e-0338-21600bcd4277', 'chapter', 'LEV.17', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'RESPECT BLOOD LAWS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('aa7c0add-f6b0-dc99-3d33-b02111dc6689', 'chapter', 'LEV.18', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'LAWS SEXUAL MORALITY LISTED IN FULL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e7a3ae12-1586-5fb1-1f50-71b564b95721', 'chapter', 'LEV.19', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'HAVE RESPECT AND LOVE MOTHER AND FATHER GODS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('27dc539c-054b-6518-554b-a21ea57f0290', 'chapter', 'LEV.20', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'EXECUTION FOR CHILD SACRIFICES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5a629443-3bda-5291-c0b4-1d8316699642', 'chapter', 'LEV.21', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'PRIESTS MUST BE HOLY TO GOD HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('09e87465-545d-5c75-7490-9f7a12707e9e', 'chapter', 'LEV.22', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'REGULATIONS FOR EATING HOLY OFFERINGS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9e66ade7-8ca9-b6c0-f2e0-c672fa3b41e6', 'chapter', 'LEV.23', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'INSTRUCTIONS FOR ALL HOLY FEASTS OF LORD TO KEEP TRUE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('958cb462-e7e3-5104-3875-1b5e6e6305a4', 'chapter', 'LEV.24', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'EYE FOR EYE TOOTH FOR A TOOTH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('319ec6c6-c6b9-bf3d-351c-918235f77345', 'chapter', 'LEV.25', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'SABBATH YEAR AND YEAR OF JUBILEE RETURN TO YOUR PROPERTY THEN SEEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d7fdc419-440c-ffb3-0f99-458c6a6254f7', 'chapter', 'LEV.26', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'THE BLESSINGS FOR OBEDIENCE OR CURSES FOR SINNINGS DAY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('224a7e24-8963-7dc1-ed1a-e40051aa87eb', 'chapter', 'LEV.27', 'bffd8f45-1e5e-40fc-9dec-b063714982b4', 'STATUTES ON VOWS AND TITHES THE LAND ACTS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b1db263f-b43f-74b7-534d-3b8d7412cece', 'book', 'NUM', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'STORY FROM MOUNT SINAI TO THE PROMISED LAND', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('717e95ba-df61-f5f5-8900-fb9bf7efa957', 'chapter', 'NUM.1', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'SEE THE NUMBER OF THE PEOPLE OF ISRAEL AS THEY ARE COUNTED BY CLANS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('34d862b1-b076-a377-8cd0-c94dc9515f8f', 'chapter', 'NUM.2', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'THE TRIBES CAMP AROUND A TENT OF MEETINGS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e7119b7e-10ca-c358-2c6a-722a4ea4eeb5', 'chapter', 'NUM.3', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'OFFERING OF THE LEVITES INSTEAD OF ALL THE FIRSTBORN ISRAELS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('11a9225c-8b42-0027-5a38-e92c3b149f9e', 'chapter', 'NUM.4', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'RESPONSIBILITIES OF THE CLANS OF LEVI ARE LISTED BY A MOSES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cf58f7ba-d7ba-74d4-a75e-d7d8252348f5', 'chapter', 'NUM.5', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'YE SHALL PUT OUT CAMP EVERY LEPER SORE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a75ba058-512c-3b38-9195-1d4a91755417', 'chapter', 'NUM.6', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'FOR A VOW OF A NAZARITE IS HOLY SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('107bdcf5-c1ce-a6e2-6537-6515f3414254', 'chapter', 'NUM.7', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'REPORT OF THE OFFERINGS OF THE LEADERS OF ISRAEL AT THE DEDICATION OF THE ALTAR INCLUDING SILVER DISHES SET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3895f612-67f6-a5df-bbe9-7d0d5e8ee3a3', 'chapter', 'NUM.8', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'OBSERVE THE LAMPSTAND A LIGHTS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('edf0c379-cfaf-2d06-8d29-91d3f6c636e2', 'chapter', 'NUM.9', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'MAKE THE PASSOVER OBSERVED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c2b7b506-659f-6ce9-a780-3fa824e25763', 'chapter', 'NUM.10', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'MARCHING ORDERS FOR THE TRIBES ISRAEL SETS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1b21f3b7-5ea9-c7e6-3558-0c27c8f55b15', 'chapter', 'NUM.11', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'ONE SEVENTY ELDERS CHOSEN AND HELP MOSESS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cb8c013c-43a8-c18a-b0ca-34e70cc83030', 'chapter', 'NUM.12', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'UPON MIRIAMS SKINS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e5f79eea-ca81-c1ad-4b39-c06f9157378b', 'chapter', 'NUM.13', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'NOW SEND MEN TO SEARCH THE LAND OF CANAAN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e6d7a292-d289-6c43-bd59-f0ab8ada14ad', 'chapter', 'NUM.14', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'THE PEOPLE TRIED TO ENTER LAND AND ARE DEFEATED THERES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b7f60d3a-d343-9cd0-c135-ebc12ee45b68', 'chapter', 'NUM.15', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'SACRIFICES FOR SINS OF IGNORANCE OR PRESUMPTION', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f184f86e-92f5-1a6b-e9de-fdf5b21f3797', 'chapter', 'NUM.16', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'IN REBELLION KORAH DATHAN AND ABIRAM ARE SWALLOWED BY EARTH!', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('043b4886-f9cb-d270-324b-fd47cd7c2c37', 'chapter', 'NUM.17', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'NOW A ROD BLOOMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3181755f-f088-09b8-99fa-71affffd3d4b', 'chapter', 'NUM.18', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'AARON AND SONS HAVE PRIESTLY DUTY SETS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e2d3f8e7-0b74-45d0-f796-4c9724d35e27', 'chapter', 'NUM.19', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'ISRAEL PURIFIED BY RED ASH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b17ad8b2-dea9-e33a-3667-370688adc502', 'chapter', 'NUM.20', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'TWENTY AND MIRIAM DIES IN A DESERTS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d42b1233-3838-28cc-4e66-ff83bd953f3e', 'chapter', 'NUM.21', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'ON POLE A BRONZE SERPENT SAVES THE LIFE SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c353dab0-e6cc-c6b9-be35-ae2a6f8a38a8', 'chapter', 'NUM.22', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'THE DONKEY SPEAKS TO BALAAM AND ANGEL APPEARS SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bdfd330e-bc4c-66d9-d3c7-986408b6c4a7', 'chapter', 'NUM.23', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'HE CANNOT CURSE ISRAEL ONLY BLESS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c5f653d7-5321-16d3-c3a1-87f9b8735a2e', 'chapter', 'NUM.24', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'EYES OF BALAAM OPENED TO SEE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b1caba45-dc89-0857-3a70-9fdc4729d225', 'chapter', 'NUM.25', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'PHINEHAS ENDS PLAGUE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('881da7d0-fc2d-1195-6591-30dab62a7433', 'chapter', 'NUM.26', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'RECOUNT THE PEOPLE OF ISRAEL FAMILIES FOR THE INHERITANCE IN LAND OF PROMISES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5d7f6de9-5853-8bb2-76af-fe128d935a0d', 'chapter', 'NUM.27', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'ON MOUNT ABARIM MOSES SEES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('da45068a-4883-f0a6-c5e9-c2ef692de7b3', 'chapter', 'NUM.28', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'MONTHLY OFFERINGS AND FEASTS LISTED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1ad8a563-63ed-7c9f-07b7-423c80b5f2bf', 'chapter', 'NUM.29', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'IT IS A TIME OF MANY SACRIFICES AND OFFERINGS SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9decd3c2-3f55-bd86-a564-ac9d021fdac3', 'chapter', 'NUM.30', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'STATUTES VOWS MADE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('be64ef53-c1c4-b3aa-9f2b-789f10587ecb', 'chapter', 'NUM.31', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'EXECUTE VENGEANCE ON THE MIDIANITES FOR THE CHILDREN ISRAEL SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dc44a287-2ed4-e8a0-57b4-2e10ddf213a4', 'chapter', 'NUM.32', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'DO NOT SIN AGAINST THE LORD YOUR SIN WILL FIND OUT LO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('73398ff0-3905-a17f-ed1b-2fa5b10d1448', 'chapter', 'NUM.33', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'LIST OF THE JOURNEYS OF THE CHILDREN OF ISRAEL FROM EGYPT TO MOAB SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0d8c12c5-55a8-334f-e348-fa704cacd083', 'chapter', 'NUM.34', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'ASSIGN THE LAND BY LOT TO TRIBES ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0d7de151-f0d9-e19f-a5e8-ae3df4525d99', 'chapter', 'NUM.35', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'NOW SIX CITIES OF REFUGE ARE ASSIGNED LOT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('48a2f151-18f6-bbdf-71bd-6aca686c8f3a', 'chapter', 'NUM.36', 'b1db263f-b43f-74b7-534d-3b8d7412cece', 'DAUGHTERS LAND', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('76c53b52-c083-7035-80d6-c58b80dd3473', 'book', 'DEU', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'THE SECOND READING OF GOD''S LAWS VIA MOSES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3dba1340-963c-5f24-82e2-825b71fed47a', 'chapter', 'DEU.1', '76c53b52-c083-7035-80d6-c58b80dd3473', 'THE HISTORY OF ISRAEL IN THE WILDERNESS IS RECALLED ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6f2552c1-fe0b-744e-34fa-928953ec55ba', 'chapter', 'DEU.2', '76c53b52-c083-7035-80d6-c58b80dd3473', 'HESHBON AND BASHAN ARE DEFEATED BY GODS TASK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('afedc032-5356-f0e1-674d-bc0fb51a04c8', 'chapter', 'DEU.3', '76c53b52-c083-7035-80d6-c58b80dd3473', 'EAST OF JORDAN LAND GIVEN TO TRIBES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f2590ced-7485-da3e-e44f-3d3f9b692032', 'chapter', 'DEU.4', '76c53b52-c083-7035-80d6-c58b80dd3473', 'SUBMIT TO GODS LAWS AGAINST IDOLATRY AND LIVE LONG IN LANDS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cf111fa6-d0f6-8bc0-d5be-f3c6d66833ef', 'chapter', 'DEU.5', '76c53b52-c083-7035-80d6-c58b80dd3473', 'EXODUS TEN COMMANDMENTS ARE SAID AGAIN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fa660bde-b302-6f41-9bbe-2bbd7b8ec01a', 'chapter', 'DEU.6', '76c53b52-c083-7035-80d6-c58b80dd3473', 'COMMANDS TO LOVE LORD GOD AMEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6f532640-4a45-90c8-8658-b5e5f1c76825', 'chapter', 'DEU.7', '76c53b52-c083-7035-80d6-c58b80dd3473', 'OBEY LORD AND DESTROY NATION HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('be7cf001-765c-884c-65f4-c623f935dc05', 'chapter', 'DEU.8', '76c53b52-c083-7035-80d6-c58b80dd3473', 'NOT BY BREAD ALONE LIVES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('17dce383-d894-1b6b-61fa-4135ec3b1436', 'chapter', 'DEU.9', '76c53b52-c083-7035-80d6-c58b80dd3473', 'DONT FORGET REBELLION AND GOLD COW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e2057a0b-4595-5bbb-a346-ce83c19e8fab', 'chapter', 'DEU.10', '76c53b52-c083-7035-80d6-c58b80dd3473', 'REMEMBER NEW TABLETS AMEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6e927192-4b3c-5b45-b087-c6b23565a0d1', 'chapter', 'DEU.11', '76c53b52-c083-7035-80d6-c58b80dd3473', 'EYES OF THE LORD ARE ALWAYS ON THE LANDS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('23eabcf7-b8f8-ba1b-672c-f26aeb095852', 'chapter', 'DEU.12', '76c53b52-c083-7035-80d6-c58b80dd3473', 'AS DESTROY IDOLS PLACE FOR LORD CHOSEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eb79c118-cebf-4ae5-599d-5f9a37f0bfe4', 'chapter', 'DEU.13', '76c53b52-c083-7035-80d6-c58b80dd3473', 'DEAL WITH THE PROPHET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7a174b85-b753-8850-ffc6-64356be37f0d', 'chapter', 'DEU.14', '76c53b52-c083-7035-80d6-c58b80dd3473', 'IDENTIFY CLEAN AND UNCLEAN MEATS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b6128c77-baa7-d48f-2aad-98ef34625c57', 'chapter', 'DEU.15', '76c53b52-c083-7035-80d6-c58b80dd3473', 'NO POOR AMONG YOU IF YOU GIVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3f4092d1-e8c8-c951-5827-ef7184f8d328', 'chapter', 'DEU.16', '76c53b52-c083-7035-80d6-c58b80dd3473', 'GIVE FREEWILL OFFERINGS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f651fe0e-c276-43ae-a864-f100c6ea1a09', 'chapter', 'DEU.17', '76c53b52-c083-7035-80d6-c58b80dd3473', 'OBSERVE JUSTICE FOR ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b9670b40-0fc1-45f4-fc66-927b427cbe1a', 'chapter', 'DEU.18', '76c53b52-c083-7035-80d6-c58b80dd3473', 'PRIESTS PORTION PROPHET S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dab63982-2ef1-5c22-6876-ebf220abe5a8', 'chapter', 'DEU.19', '76c53b52-c083-7035-80d6-c58b80dd3473', 'GO TO CITIES OF REFUGE SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c813c6d0-2ccd-6a5c-cd49-387753f6f518', 'chapter', 'DEU.20', '76c53b52-c083-7035-80d6-c58b80dd3473', 'OFFER PEACE BEFORE WARS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4eda744d-7088-005f-a06e-9bd74954c738', 'chapter', 'DEU.21', '76c53b52-c083-7035-80d6-c58b80dd3473', 'DEAL WITH AN UNSOLVED DEATH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('78b3d76f-c317-30ae-cda8-09b9dc5b7c9c', 'chapter', 'DEU.22', '76c53b52-c083-7035-80d6-c58b80dd3473', 'SEXUAL PURITY LAWS GIVEN TO THE JEWS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ba52188a-4454-55e8-44c8-625066652494', 'chapter', 'DEU.23', '76c53b52-c083-7035-80d6-c58b80dd3473', 'LAWS OF EXCLUSION FROM CAMP HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2f95b031-9730-d6d4-0854-7e5d8311beb2', 'chapter', 'DEU.24', '76c53b52-c083-7035-80d6-c58b80dd3473', 'A DIVORCE AND MARRIAGE LAW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e91208cc-ccb5-b379-ba55-fb2d1d03ec72', 'chapter', 'DEU.25', '76c53b52-c083-7035-80d6-c58b80dd3473', 'WEIGHTS MUST BE SO JUST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e769974f-7b97-fe92-6beb-624e2143db89', 'chapter', 'DEU.26', '76c53b52-c083-7035-80d6-c58b80dd3473', 'SAY PRAYER FIRSTFRUIT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('54981a9d-6495-5e95-18fe-9a24c7f5b776', 'chapter', 'DEU.27', '76c53b52-c083-7035-80d6-c58b80dd3473', 'VILLAGE ON MOUNT EBAL IS CURSED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d9010bf8-4f6e-6491-0d4a-f363b353b1ea', 'chapter', 'DEU.28', '76c53b52-c083-7035-80d6-c58b80dd3473', 'IF YOU OBEY BLESSINGS IF NOT OBEY CURSES AND PLAGUE AND DISEASES AND DROUGHT NOW LO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('61b216c3-17f5-a0c7-7d01-c25fa30ee4d9', 'chapter', 'DEU.29', '76c53b52-c083-7035-80d6-c58b80dd3473', 'AND MOSES RENEWS THE COVENANT HERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cf8b3ffd-f6b7-1155-e266-5c090e547a08', 'chapter', 'DEU.30', '76c53b52-c083-7035-80d6-c58b80dd3473', 'MERCY FOR THE REPENTANT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('01e2d06d-fff5-a3aa-7c6e-1758b9870622', 'chapter', 'DEU.31', '76c53b52-c083-7035-80d6-c58b80dd3473', 'OBSERVE LAW AND BE STRONG IN THE LORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5eb480e3-cf58-a1a4-b3e6-c414683a747f', 'chapter', 'DEU.32', '76c53b52-c083-7035-80d6-c58b80dd3473', 'SONG OF MOSES IS RECITED TO THE WHOLE ASSEMBLY OF ISRAEL BY A MAN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ad01b71f-4779-92b7-8383-82bf11fe1e32', 'chapter', 'DEU.33', '76c53b52-c083-7035-80d6-c58b80dd3473', 'EACH TRIBE IS BLESSED BY MOSES SEEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5fe8e33b-cc32-c1ce-e94a-a73e41a73761', 'chapter', 'DEU.34', '76c53b52-c083-7035-80d6-c58b80dd3473', 'SO A MOSES DIES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'book', 'JOS', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'ISRAEL ENTERS PROMISED LAND', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('872d020e-bc57-b3cf-11a6-cb1d80d8c22b', 'chapter', 'JOS.1', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'INTO LAND YOU GO TO WIN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('81b44b02-6a30-60b3-4a70-006a0d57f9d3', 'chapter', 'JOS.2', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'SPIES ESCAPED BY RAHABS CORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c77d2473-e77b-0abb-1d95-4a195a346fdd', 'chapter', 'JOS.3', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'RIVER JORDAN HALTED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ce6d0d93-cbf3-fee1-5165-4317ef62dc3d', 'chapter', 'JOS.4', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'A MEMORIAL OF TWELVE STONE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3f0d6be1-b900-f928-2758-ad42f4e3cac3', 'chapter', 'JOS.5', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'EAT PASSOVER HERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4d90453e-24f8-b009-2c83-b2958e66adde', 'chapter', 'JOS.6', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'LOUD SHOUT MAKES WALL FALL DOWNS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7215eb54-935a-1797-7354-cd4fb1725439', 'chapter', 'JOS.7', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'ACHAN SIN AI DEFEAT AND STONEDS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f0c7e225-f0d0-6877-cf38-6a5553edf2f8', 'chapter', 'JOS.8', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'NOW AI IS DESTROYED AND BURNED WITH FLAMES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2cb2ae63-acd9-30f9-5ae0-39908dd74525', 'chapter', 'JOS.9', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'TRICKED BY GIBEONITE TREATY MAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c6b7c11d-82e2-e585-76c8-396216b9c2bc', 'chapter', 'JOS.10', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'ENEMIES DEFEATED AS THE SUN STOOD STILL IN THE SKIES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('54183f02-b1f4-2d52-5b2f-b683aa957689', 'chapter', 'JOS.11', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'RULERS OF NORTH CONQUEREDS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ba51baa0-9d33-496e-ab1c-9fbb158ab8f5', 'chapter', 'JOS.12', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'THIRTY ONE KINGS STRUCK DEAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2cd7fe9a-ee34-6d9d-eb54-4b9cebcea985', 'chapter', 'JOS.13', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'PORTIONS OF THE LAND YET TO BE CONQUERED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5ccb7668-4534-b3f5-d5a5-66de9dcac24c', 'chapter', 'JOS.14', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'REQUEST OF A CALEB', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7c1ae6ed-5a12-1412-95e3-f3dfaa63b22b', 'chapter', 'JOS.15', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'ON JUDAH BORDER LAND IS GIVEN TO THE TRIBE OF JUDAH ACCORDING TO FAMILY CLANS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5ce0e8ad-c193-3754-54a3-b7de2a1e6eee', 'chapter', 'JOS.16', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'MANASSEH HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('96bff0a1-33c4-d98e-614d-03521cd12145', 'chapter', 'JOS.17', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'INHERITANCE OF RESTS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('80914784-40bb-01db-072a-8ef55b16194d', 'chapter', 'JOS.18', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'REST OF LAND DIVIDED SHILOH TENTS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ff2cae7c-b850-bf0b-14ca-8fe3f6cb6b95', 'chapter', 'JOS.19', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'END OF A DIVISION OF LAND AMONG THE TRIBES OF ISRAELS CLANS ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f85b2253-74ee-2686-d1e1-e310843b7047', 'chapter', 'JOS.20', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'DESIGNATE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('72f83acf-4d15-50d2-da31-47493d8d82e7', 'chapter', 'JOS.21', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'LEVITES GIVEN CITIES AND PASTURE LANDS TO LIVE IN CITY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1e43fe6c-59df-a6d4-3024-8a714ba86396', 'chapter', 'JOS.22', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'ALTAR OF WITNESS BUILT BY THE JORDAN SIDE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9fb0bfe6-0f1b-8b82-3914-de437c6623c0', 'chapter', 'JOS.23', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'NO MIXING WITH FOES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dc9dae87-586e-d903-790f-0f4fcfd0348d', 'chapter', 'JOS.24', '112b5c09-4a93-2c94-bdf2-15fd2b5f38ca', 'DEPARTING JOSHUA REVIEWS HISTORY PAST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'book', 'JDG', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'SIN CYCLE THROUGH JUDGES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5e9627ed-48af-01af-166a-597ff1af4edd', 'chapter', 'JDG.1', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'SOME TRIBES FAILED TO DRIVE OUT NATIONS ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('45840198-8703-262b-4732-0cc995a155a3', 'chapter', 'JDG.2', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'ISRAEL FORSAKES THE LORD HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('17d9c594-8c9c-5c20-12dd-1ab5e3ea61d0', 'chapter', 'JDG.3', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'NATIONS LEFT TO TEST ISRAELITES A WAR', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c7071f4b-cba0-a492-ea81-4b901cb88fec', 'chapter', 'JDG.4', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'CANAANITE KING JABIN SLAINS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('89e2931b-648b-ba94-49c0-3f65dd1d450e', 'chapter', 'JDG.5', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'YES JAEL KILLS SISERA DEBORAH WON WAR', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('18e40d83-57e5-0ca4-a1f4-69c2fcc4a882', 'chapter', 'JDG.6', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'CALL OF GIDEON TO SAVE ISRAEL FROM MIDIAN FOES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2821d484-3baf-100e-5954-fb732031618d', 'chapter', 'JDG.7', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'LAP DOGS DRINK WATER GIDEON HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6f4bba3b-1dac-3469-68cd-4b873811bc14', 'chapter', 'JDG.8', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'EPHOD MADE BY GIDEON BECOMES A SNARE A SINS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e21a9b6d-a3ed-5b74-7cb7-883fb353c4ea', 'chapter', 'JDG.9', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'THE TREACHERY OF ABIMELECH AND HIS DEATH BY WOMAN MILLSTONE CRUSHED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('53503b49-09cb-3bcc-2ea0-ed91ba74b79b', 'chapter', 'JDG.10', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'HISTORY OF TOLA JAIRS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('86841fc2-7c6e-cea6-23f8-e0e61d8635ff', 'chapter', 'JDG.11', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'JEPHTHAH VOW AND SACRIFICE HIS DAUGHTER DEAD HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0c52a5ae-efd8-cd42-e6ef-b4eb5a2cd733', 'chapter', 'JDG.12', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'ON SHIBBOLETH SAY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9d35513e-9398-b367-0470-038fc6f30357', 'chapter', 'JDG.13', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'UNKNOWN ANGEL VISITS MANOAHS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2af9310e-b3fc-125a-39e0-cb124875517b', 'chapter', 'JDG.14', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'GET HONEY FROM LION SONS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6adc220a-8e9d-4c97-5f89-51398d7efa3f', 'chapter', 'JDG.15', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'HE KILLS A THOUSAND MENS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f87f1acd-b687-f1db-a540-19706b1dbbe2', 'chapter', 'JDG.16', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'JAIL FOR SAMSON BLINDED AND IS DEAD HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6f2a545c-aa91-fefc-a528-5b670e23e297', 'chapter', 'JDG.17', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'USE IDOL MICAHS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('059428bd-962d-7b2d-d53c-30c0a7b7aea8', 'chapter', 'JDG.18', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'DANITES TAKE MICAHS IDOL AND LAND SET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3e8636f2-8e7a-31fe-3414-fc1faad6d892', 'chapter', 'JDG.19', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'GIBEAH CRIME LEVITES CONCUBINE CUT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('77069bc9-a070-b167-b8b9-2ef6be78f5c7', 'chapter', 'JDG.20', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'ELEVEN TRIBES WAR AGAINST BENJAMIN AND DEFEAT THEM ALL HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('609c639c-e2f8-1829-79b4-275963f27c16', 'chapter', 'JDG.21', 'f78e18bf-280d-32f7-e4ff-0354c97d17d6', 'SO WIVES FOR BENJAMIN FOUND HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6be49b40-4e46-8e76-05f3-390bb10c346a', 'book', 'RUT', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'TRUE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ee3ff67e-904f-654b-4eab-ae5fc8ba71e1', 'chapter', 'RUT.1', '6be49b40-4e46-8e76-05f3-390bb10c346a', 'TO MOAB AND BACK IN TEAR SAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4fb19ec6-87bd-9855-6c2f-c017b211ef0f', 'chapter', 'RUT.2', '6be49b40-4e46-8e76-05f3-390bb10c346a', 'RUTH GLEANS IN BOAZ FIELDS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('be33deee-e67a-934d-ae0d-2b2958faa25d', 'chapter', 'RUT.3', '6be49b40-4e46-8e76-05f3-390bb10c346a', 'UNDER BOAZ FEET LAID S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('303c27e0-2d08-96b5-43a4-808cd9c0a239', 'chapter', 'RUT.4', '6be49b40-4e46-8e76-05f3-390bb10c346a', 'END IS DAVID GRANDFATHER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('25fb39ba-a06a-5ef9-074e-8f318a28d967', 'book', '1SA', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'HOW GOD CHOSE ISRAEL''S FIRST TWO KINGS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('910a7018-dde3-77dc-0a7b-cd881c1eff21', 'chapter', '1SA.1', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'HANNAH PRAYS FOR A SON SAMUEL VOWS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a36c0ecb-8ec9-cc4a-adee-7241c57bc1e0', 'chapter', '1SA.2', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'ONE SONG OF HANNAH AND SINS OF ELI SON BAD ASK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('961efa09-a7aa-b436-ab41-795d3e5974da', 'chapter', '1SA.3', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'WORD OF LORD CALLS BOY SAM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9690fb5c-10c0-ae52-0177-68c0481a0500', 'chapter', '1SA.4', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'SOLDIERS ARK TAKEN BY FOES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f66edd7a-6486-00a7-35d6-c77e513d0406', 'chapter', '1SA.5', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'ON DAGON FALLS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5f7d8d9d-c88d-8ba0-e03a-70892aaae580', 'chapter', '1SA.6', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'DRIVE ARK BACK WITH COWS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('58b898e3-a86b-d957-35d5-d7c43a1c4682', 'chapter', '1SA.7', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'CALL FOR REPENTANCE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('48c00086-b6ee-9c89-9409-ef7883cda10c', 'chapter', '1SA.8', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'HEAR PEOPLE ASK FOR KINGS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('06b7e123-60a8-98e2-813d-4624520a4f17', 'chapter', '1SA.9', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'ON DONKEY HUNT SAUL SEES SEER SAM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ce3f2b24-5cc9-0846-923d-0ef62b8c1932', 'chapter', '1SA.10', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'SAUL ANOINTED KING BY SAMUEL OIL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f961baaf-16a4-45f5-c9c7-450f93528bb8', 'chapter', '1SA.11', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'EYE GOUGED JABESH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0a39ed53-33e0-824b-8afe-25b156dfc9ee', 'chapter', '1SA.12', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'IT IS SAMUEL FAREWELL SPEECHS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('18fb4138-42a0-c3c9-9170-d4c6f2d9ed57', 'chapter', '1SA.13', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'SAUL OFFERS SACRIFICE SINS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b8820236-331c-2bbc-63e8-4946a1490c44', 'chapter', '1SA.14', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'JONATHAN FIGHT EATS HONEY SAUL RASH OATH AND PEOPLE SAVE HIM HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3f541912-2034-10b0-3670-d2ab1e3ce242', 'chapter', '1SA.15', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'AMALEKITES SPARED BY SAUL REJECTED GODS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b9b6926c-b8d0-d98c-85e2-000014ee9072', 'chapter', '1SA.16', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'EVIL SPIRIT AND DAVID HARPS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3c528b94-e09a-5bdc-374a-fbdbeee57d60', 'chapter', '1SA.17', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'LITTLE DAVID KILLS GOLIATH WITH A SLING AND STONE GIANT FALLS DOWN ASK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2de1f57e-f8dc-31aa-a8ec-00ddee422a7b', 'chapter', '1SA.18', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'SOUL OF JONATHAN KNIT TO DAVID BROS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1aca8054-b44d-d74e-dc09-b1039c611856', 'chapter', '1SA.19', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'FLEES DAVID FROM SAUL RAGES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3396e37a-8c26-6e96-d1cf-155810f43e97', 'chapter', '1SA.20', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'IONATHAN AND DAVID COVENANT AND ARROW SIGNALS SET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('308cf73c-73f9-9291-6223-05730f51fb5c', 'chapter', '1SA.21', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'RUN TO NOB PRIEST S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8a236576-6898-4e68-1a08-02ff45daa1e5', 'chapter', '1SA.22', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'SLAUGHTER OF PRIESTS DONES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c9c95efc-a526-a233-c41d-9b67af80f728', 'chapter', '1SA.23', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'THEN DAVID SAVES KEILAH HIDES OUTS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('205f2be4-24df-39f2-b69a-688dfe892892', 'chapter', '1SA.24', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'TAKES SAUL ROBE IN CAVES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('01e31be0-ac91-1831-667e-8f6b3f662058', 'chapter', '1SA.25', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'WORD CAME SAMUEL DIED NABAL FOOL AND ABIGAIL WEDS HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4baf199a-8eaf-f697-899c-42681b7eb0d4', 'chapter', '1SA.26', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'ON ZIPH SAUL SPEAR IS TAKEN OFF', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c6a4e9f0-2ae5-5d03-35e0-d4c7c28b710a', 'chapter', '1SA.27', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'KING WITH FOES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('01a5b88c-f64a-a3ca-4f42-fa41fd1fa27b', 'chapter', '1SA.28', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'IN ENDOR SAUL CONSULTS WITCH S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('221db387-f011-cb3b-1731-6786c0619849', 'chapter', '1SA.29', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'NOT GO TO WARS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fd246e05-7e12-141c-4439-5b82545fdcb5', 'chapter', '1SA.30', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'GET ZIKLAG BACK SPOIL RECOVERED ALL S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('04c903f5-588c-fcc4-3699-560cb071713f', 'chapter', '1SA.31', '25fb39ba-a06a-5ef9-074e-8f318a28d967', 'SAUL DIES THERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0ab1321f-e208-ef8c-c14e-e0c802b65967', 'book', '2SA', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'ETERNAL RULE OF DAVID BEGINS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3fea7ca1-70a1-2d28-568b-13aa6cbc58a6', 'chapter', '2SA.1', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'EULOGY FOR SAUL AND JONATHAN SAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f6181d6c-c051-53b0-a02a-03fb1301becb', 'chapter', '2SA.2', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'TWO KINGS FIGHT ISHBOSHETH DAVID WARS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d69196a2-7c6a-7ce3-ab86-cfdb13baddc3', 'chapter', '2SA.3', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'END OF ABNER MURDERED BY JOAB FOR REVENGE SADLY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1b67868f-96f1-3804-45f1-adc1b5df21fe', 'chapter', '2SA.4', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'RULE OVER LAND', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4287f571-bd50-21be-f6ec-626baa54086d', 'chapter', '2SA.5', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'NOW DAVID KING ALL ISRAELITES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('51ce550f-f8c7-17aa-4f97-c1fc1ccf87d1', 'chapter', '2SA.6', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'ARK BROUGHT TO JERUSALEM HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('28d2b5fa-d149-1928-28a2-3336947fd348', 'chapter', '2SA.7', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'LORD PROMISES DAVID A KINGDOM NEWS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bf4a5e70-38de-78b6-3b14-49104c011d6a', 'chapter', '2SA.8', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'REIGNS OVER ENEMIES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('24736ca4-f058-9855-04b6-3c53d09927c1', 'chapter', '2SA.9', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'SAW MEPHIBOSHE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2ff2f58d-40d8-6acf-a3d3-1856a1b75600', 'chapter', '2SA.10', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'LOSS OF AMMON AND SYRIA', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e9d11aff-e7e6-7794-21e9-f7b3d8a082d8', 'chapter', '2SA.11', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'EVIL SIN WITH BATHSHEBA DONE ILL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0ca1862c-3112-aefc-b1ab-c582218582a3', 'chapter', '2SA.12', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'OLD NATHAN REBUKES DAVID FOR SINS BAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3cd60bdb-d952-d4e0-9d57-9ac3f78f3a0e', 'chapter', '2SA.13', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'FAMILY TROUBLE AMNON RAPES TAMAR ABSALOM S MAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('43305b27-24c6-3860-fcd1-df192b5a0b24', 'chapter', '2SA.14', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'DAVID FORGIVES ABSALOM RETURNS HOME LO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('200f6385-bb46-4693-0f9f-d759ed1ad425', 'chapter', '2SA.15', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'ABSALOM REBELS AND DAVID FLEES THE CITY OUTS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('956d5f32-8c5f-b6e8-5282-670dd2edf4c4', 'chapter', '2SA.16', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'VILE SHIMEI CURSES DAVID HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c306f23c-ba78-8dfb-62e8-6ff76a1a2f7b', 'chapter', '2SA.17', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'INTRIGUE OF AHITHOPHEL DEFEATED S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6d950c63-ffe5-e9bb-10c8-9ac7d72ccac2', 'chapter', '2SA.18', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'DEATH OF ABSALOM IN THE OAK FOREST SADLY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d6ab8f97-14fc-119d-58ec-8a48c1331bb1', 'chapter', '2SA.19', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'BACK TO JERUSALEM DAVID COMES WITH THE TRIBES ALL LO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('94848826-4584-d0c2-5143-4ca5180a3b89', 'chapter', '2SA.20', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'END OF SHEBA REBELLION HERES LO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2d48fe17-902d-5244-3d5e-5206c5f03841', 'chapter', '2SA.21', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'GIBEONITES AVENGE SAUL HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9c667355-625e-6a34-925c-ba579a6cb025', 'chapter', '2SA.22', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'DAVIDS SONG OF PRAISE FOR DELIVERANCE FROM SAUL SAVED HIM LOW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9d74f93f-f234-d4c3-1d50-4e9a2c04f219', 'chapter', '2SA.23', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'NAMES OF DAVIDS MIGHTY MEN LISTED AND HEROES LO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('010df047-cfda-bb8a-f1e3-57c67f11e594', 'chapter', '2SA.24', '0ab1321f-e208-ef8c-c14e-e0c802b65967', 'SIN OF CENSUS BRINGS PLAGUE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'book', '1KI', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'SOLOMON BUILDS THE TEMPLE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cc637fd6-5aac-169b-0818-aeec2223387a', 'chapter', '1KI.1', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'SOLOMON ANOINTED KING WHILE ADONIJAH FEASTS UNKNOWINGLY EATS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('18cf8959-75d3-9ce8-143e-6e1cfec7d66d', 'chapter', '1KI.2', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'ORDERS OF DAVID TO SOLOMON BEFORE HE DIES IN PEACES ENDS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a9545acc-62b4-931c-e9eb-444f954f3199', 'chapter', '1KI.3', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'LORD GIVES WISDOM TO A SOLOMON ASK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f19a6a0d-2a37-9fdd-e538-a79cfd12df17', 'chapter', '1KI.4', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'OFFICIALS OF SOLOMON AND HIS WEALTH SETS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8f3f365e-9e75-6ee3-6931-1d030f7d7488', 'chapter', '1KI.5', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'MATERIALS FOR TEMPLE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('da9e1f31-aee3-edc4-12f6-ff964ea47171', 'chapter', '1KI.6', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'SOLOMON BUILDS THE TEMPLE AND PALACE COMPLEX', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('770b8173-3978-a725-3577-a19664b9b021', 'chapter', '1KI.7', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'SOLOMON BUILDS HIS PALACE AND MAKES TEMPLE FURNISHINGS SETS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('713ec2d8-3ed6-50f3-4ccd-ad66744516d6', 'chapter', '1KI.8', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'ARK BROUGHT TO TEMPLE AND SOLOMON PRAYS AND DEDICATES IT WITH A FIRE FLAMES TASK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c3b7ef59-e3cf-ebfe-089e-d1513b9a79df', 'chapter', '1KI.9', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'UPON OBEDIENCE BLESSING GIVENS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a558ed0f-2924-4a54-679d-78a479a90822', 'chapter', '1KI.10', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'IN COMES QUEEN OF SHEBA TO TEST HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('024aef02-dc2a-bfb8-7910-39f8d7bbd488', 'chapter', '1KI.11', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'LOVES FOREIGN WOMEN AND TURNS FROM GOD TO IDOLS BADS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4c7813a4-0e51-e966-209f-07445318f098', 'chapter', '1KI.12', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'DIVISION OF KINGDOM REHOBOAM FOLLY BAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e48898bd-4b1f-7ed2-830a-f47771244117', 'chapter', '1KI.13', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'SIN OF JEROBOAM AND PROPHET JUDAH SADS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fe30d934-b59c-f9f7-1372-a92cf51ac65e', 'chapter', '1KI.14', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'THE PROPHECY AGAINST JEROBOAM AS BAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('40241541-11e6-d8ed-d65c-bbc007fba28f', 'chapter', '1KI.15', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'HISTORY OF KINGS ASA AND BAASHA WARS BADS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ebc46125-cbbd-febd-918e-353a07aac2f0', 'chapter', '1KI.16', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'ELAH ZIMRI OMRI AHAB KINGS OF ISRAEL BADS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4b4ee507-253d-c4d7-0d30-0e134815c0eb', 'chapter', '1KI.17', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'THE ELIJAH FED BY RAVENS EATS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('79ed2b14-660d-ec19-905b-3fc5f2c771aa', 'chapter', '1KI.18', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'ELIJAH CONFRONTS PROPHETS OF BAAL ON MOUNT CARMEL GODS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('89ea533d-44a8-af3b-916f-9f486313075a', 'chapter', '1KI.19', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'MEETS GOD IN A WHISPER LOW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5a563096-24ca-ef83-30d0-4d7ac1ce9df1', 'chapter', '1KI.20', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'PROPHET CONDEMNS AHAB FOR SPARING BEN HADAD BAD ASK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9c107c64-9dd7-9ec8-e0ed-80804078c94c', 'chapter', '1KI.21', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'LAND OF NABOTH STOLEN BY JEZEBELS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d547f819-2cdc-d0bc-b420-2b1af658d70d', 'chapter', '1KI.22', '8332ebbd-1ca1-b7a1-3414-a217d1e3e84b', 'END OF AHAB PROPHECY FULFILLED AS HE DIES IN BATTLE HERE DIES ASK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'book', '2KI', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'TAKEN INTO EXILE BY ATTACKERS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3c7dd7bd-b1fd-3959-b49a-ad6d93a32d1a', 'chapter', '2KI.1', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'TWO FIFTIES BURNED HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('736b32f3-335d-79de-56fe-957a01188b24', 'chapter', '2KI.2', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'ASCENSION OF ELIJAH TO SKY SAW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f0869356-5f95-75cb-a5f9-a2fa931f660c', 'chapter', '2KI.3', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'KINGS ATTACK MOAB AND DEFEAT WAR', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3a32fa27-a427-d167-ed1d-ec6866694eef', 'chapter', '2KI.4', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'ELISHA MIRACLES OIL SHUNAMMITE BOY AND POT STEWS EAT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ecc8da84-9108-a624-3bdb-c0ba7f2c7379', 'chapter', '2KI.5', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'NAAMAN HEALED OF LEPROSY DIPPED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('db04c3e9-849e-20a6-f52b-36c468f40ee5', 'chapter', '2KI.6', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'IRON AXE HEAD FLOATS AND SYRIAN WAR ENDS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('463fc0ba-97cc-96c4-81c8-46ffb137c79a', 'chapter', '2KI.7', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'NEWS OF SYRIAN FLIGHTS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('983a500a-003c-d667-a2a2-fddfe16dee54', 'chapter', '2KI.8', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'THE SHUNAMMITE LAND RESTOREDS NEW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4bb794a9-1eeb-cd8f-1fd0-e5c5a7e74452', 'chapter', '2KI.9', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'ORDAINED JEHU KILLS JORAM AND JEZEBEL DIES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('594f107a-3dae-fa00-d02e-1c482982183d', 'chapter', '2KI.10', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'EXECUTION OF AHAB FAMILY AND BAALISTS DIES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d1affafc-e44f-0317-d4ad-da903d1238c2', 'chapter', '2KI.11', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'X OUT BAD QUEEN ATHALIAH S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('122e3729-93d2-8f94-b0c4-643aeabbd4bd', 'chapter', '2KI.12', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'IOASH REPAIRS TEMPLE NEW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a1216451-7ecc-357a-23a5-e673bb66c790', 'chapter', '2KI.13', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'LAST DAYS OF ELISHA AND DIED LO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5f56c7c2-69d8-3a92-32d0-a50c3b6f92e5', 'chapter', '2KI.14', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'E AMAZIAH WAR WITH ISRAEL LOST WARS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e89bd953-dce2-9cfd-f7dc-3715471e5426', 'chapter', '2KI.15', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'BAD KINGS OF ISRAEL ZECHARIAH SHALLUM BAD ASK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('35ee8dce-1737-1ce4-88b0-e17ef9e6bdbe', 'chapter', '2KI.16', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'Y AHAZ WICKED REIGNS BAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9ce82844-99e3-88dd-65ef-4603ebbd594c', 'chapter', '2KI.17', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'ASSYRIA CAPTURES ISRAEL AND EXILES THE PEOPLE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5fa1868f-e72c-e48e-f045-84c9ddac41bb', 'chapter', '2KI.18', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'THE HEZEKIAH GOOD KING REBELS ASSYRIA WARS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6dd49d23-afa0-6f1d-1091-1d38968f6475', 'chapter', '2KI.19', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'THE ASSYRIAN ARMY DESTROYED BY AN ANGEL GODS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('394da0a6-1d98-6131-a6a6-459fa17b95ce', 'chapter', '2KI.20', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'ADDED YEARS TO HEZEKIAH S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1b01206d-3f11-c711-2f28-e3e9f238962b', 'chapter', '2KI.21', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'CHIEF SINNER MANASSEH VILE SIN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8f63dea7-60a5-f551-48d2-4bf9337b6336', 'chapter', '2KI.22', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'KING JOSIAH FINDS BOOK S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5a1a0750-e8cb-346b-0731-ab814432f3d6', 'chapter', '2KI.23', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'ENDS IDOLATRY AND KEEPS PASSOVER JOSIAH ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b99aeb44-b4d7-ade3-88e1-835ef8cbe3d9', 'chapter', '2KI.24', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'REBELLION OF JEHOIAKIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b6dbe2bc-2775-f9cd-d107-d4612af9e5f7', 'chapter', '2KI.25', '0598c34c-05e1-b7fe-9a2b-5ea2a2c3bea4', 'SIEGE OF JERUSALEM AND FALL NOW SADS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f685fbff-0669-5179-55b7-4badefc29329', 'book', '1CH', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'OVERVIEW OF ISRAEL AND DAVID''S RULE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dff9c9a7-35a9-c88d-da5c-88f75e08e917', 'chapter', '1CH.1', 'f685fbff-0669-5179-55b7-4badefc29329', 'ORIGIN LIST FROM ADAM TO ABRAHAM AND SONS OF ISRAEL LISTED ALL MEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('010cae6e-daae-0a34-a0c5-2b1d03091828', 'chapter', '1CH.2', 'f685fbff-0669-5179-55b7-4badefc29329', 'VARIOUS SONS OF ISRAEL AND JUDAH CALEB AND JERAHMEEL LISTED ALL HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8614ecaf-5f12-5365-b33f-d689669df3af', 'chapter', '1CH.3', 'f685fbff-0669-5179-55b7-4badefc29329', 'EVERY SON OF DAVID IS LISTED S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('343435d2-4085-86f7-2df3-8285b673bea0', 'chapter', '1CH.4', 'f685fbff-0669-5179-55b7-4badefc29329', 'RECORD OF JUDAH AND SIMEON FAMILIES LISTED HERE ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f62dd0d4-1348-4097-d980-cde420034c8a', 'chapter', '1CH.5', 'f685fbff-0669-5179-55b7-4badefc29329', 'VARIOUS TRIBES EAST JORDAN REUBEN GAD MANASSEH S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4da0fa5b-9173-c694-a24d-1dc736d6dcd2', 'chapter', '1CH.6', 'f685fbff-0669-5179-55b7-4badefc29329', 'INFORMATION ON LEVITES FAMILIES AND MUSICIANS AND SETTLEMENTS LISTED IN FULL DETAIL ALL HERE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5b111aa3-dd99-eede-81ab-571df1fd0e23', 'chapter', '1CH.7', 'f685fbff-0669-5179-55b7-4badefc29329', 'EXTRA TRIBES GENEALOGIES ISSACHAR BENJAMIN HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4ad6928f-b843-abb1-89c1-e3ea83781c5c', 'chapter', '1CH.8', 'f685fbff-0669-5179-55b7-4badefc29329', 'WHOLE BENJAMIN FAMILY TREE CHARTED NOW HERE ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c6a70749-7494-0b0a-ea90-b25b9c5ceff6', 'chapter', '1CH.9', 'f685fbff-0669-5179-55b7-4badefc29329', 'ON RETURNING EXILES AND SAUL FAMILY TREE HERE SETS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c6bb564e-1c38-07d7-820c-1baa77612c96', 'chapter', '1CH.10', 'f685fbff-0669-5179-55b7-4badefc29329', 'FALL OF KING SAUL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('321f7d23-eba7-15c6-145b-2e425f6a0627', 'chapter', '1CH.11', 'f685fbff-0669-5179-55b7-4badefc29329', 'ISRAEL ANOINTS DAVID KING AND MIGHTY MEN LISTED ALSO ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('757e4326-8a2f-c37c-c653-83d17e5ac522', 'chapter', '1CH.12', 'f685fbff-0669-5179-55b7-4badefc29329', 'SOLDIERS JOIN DAVID AT ZIKLAG AND HEBRON HERES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dc24a5c7-4235-6a9b-2dc5-696882c4efb4', 'chapter', '1CH.13', 'f685fbff-0669-5179-55b7-4badefc29329', 'RETURN ARK FAILS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('acfad95f-7041-120c-169b-06c53d8f95ff', 'chapter', '1CH.14', 'f685fbff-0669-5179-55b7-4badefc29329', 'AND DAVID DEFEATS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('92f383d9-c0fd-435b-1392-14beddc36a7b', 'chapter', '1CH.15', 'f685fbff-0669-5179-55b7-4badefc29329', 'ESTABLISH ARK IN JERUSALEM HERES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eee13959-22a1-f10d-407b-45db5bf0dcc0', 'chapter', '1CH.16', 'f685fbff-0669-5179-55b7-4badefc29329', 'LORD PRAISED AS ARK SET IN TENT DAVID SONG TO GODS ASK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4f6cc900-cebe-8d6e-5ee8-6c2f56c0f154', 'chapter', '1CH.17', 'f685fbff-0669-5179-55b7-4badefc29329', 'A PROMISE OF DAVIDIC LINE HERES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cf31b827-6ded-0094-f258-7297d80fa49f', 'chapter', '1CH.18', 'f685fbff-0669-5179-55b7-4badefc29329', 'NATION DEFEATED DAY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a6f7819e-a664-027d-40d7-b79f3942dc15', 'chapter', '1CH.19', 'f685fbff-0669-5179-55b7-4badefc29329', 'DAVID DEFEATS AMMON HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0723d609-6979-c546-b893-0dbb2f213f9e', 'chapter', '1CH.20', 'f685fbff-0669-5179-55b7-4badefc29329', 'DESTROYS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d3bda447-5047-2c94-9873-4436cfaf8760', 'chapter', '1CH.21', 'f685fbff-0669-5179-55b7-4badefc29329', 'A CENSUS BRINGS PLAGUE ON LANDS BADS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e2f2ad1c-ed99-0d41-408e-49f929f93af9', 'chapter', '1CH.22', 'f685fbff-0669-5179-55b7-4badefc29329', 'VALUE PREPARES TEMPLE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bcf1d490-bb50-0db0-db3b-3401522a65d7', 'chapter', '1CH.23', 'f685fbff-0669-5179-55b7-4badefc29329', 'INSTRUCTS LEVITES AND PRIESTS HERES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('97e5ed7e-8524-f785-5a30-33797680cf43', 'chapter', '1CH.24', 'f685fbff-0669-5179-55b7-4badefc29329', 'DIVISIONS OF PRIESTS ARE SORTED SETS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('58b54da2-fa17-1f26-f84c-96f902749e76', 'chapter', '1CH.25', 'f685fbff-0669-5179-55b7-4badefc29329', 'SINGERS AND MUSICIANS APPOINTED NEW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('da31d068-323c-bc9a-23e2-f450d90cacac', 'chapter', '1CH.26', 'f685fbff-0669-5179-55b7-4badefc29329', 'ROLES OF GATEKEEPERS AND TREASURES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('af8268e8-0845-24b8-12fe-cfc705458287', 'chapter', '1CH.27', 'f685fbff-0669-5179-55b7-4badefc29329', 'UNITS OF MILITARY AND OFFICIALS LIST SET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('351f580c-8760-688b-1093-11c95ebd449a', 'chapter', '1CH.28', 'f685fbff-0669-5179-55b7-4badefc29329', 'LAST PLANS GIVEN TO HIM HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1a01602e-57a9-0a42-8a0a-ff5f84ec88b3', 'chapter', '1CH.29', 'f685fbff-0669-5179-55b7-4badefc29329', 'END OF DAVID REIGN AND OFFERING GAVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0521ef7c-7a30-0626-22e3-a15393b8de52', 'book', '2CH', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'RULE OF SOLOMON FROM THE TEMPLE TO THE EXILE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('98038b17-324b-4583-57a9-43d534bcff99', 'chapter', '2CH.1', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'REIGN OF SOLOMON ASK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a88062e4-bd99-ae0f-61c9-653a07bd3a32', 'chapter', '2CH.2', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'USE HURAM TO BUILD NEW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d1c958ad-06f5-eb68-7bb5-4dfa8ba4644d', 'chapter', '2CH.3', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'LOCATION OF TEMPLES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8acbeada-3cd8-28bc-7c31-1f66fff4cb23', 'chapter', '2CH.4', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'EQUIPMENT FOR TEMPLE NEWS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('71d7ab6e-3d9d-25b2-cd67-5b2bf8446dad', 'chapter', '2CH.5', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'OPEN ARK TEMPLE S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f316cf79-22a4-591d-8436-d3fb4437e26d', 'chapter', '2CH.6', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'FOR SOLOMON PRAYER OF DEDICATION AND FIRE HERE SET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('012b4050-a9b3-3af0-e277-be2731cdd2eb', 'chapter', '2CH.7', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'SOLOMON DEDICATES TEMPLE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5f06285e-24e4-091e-98bc-8e382296315c', 'chapter', '2CH.8', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'OTHER ACTS OF SOLOMON', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9d275c32-9abc-245e-1ff6-e1095fe460b4', 'chapter', '2CH.9', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'LOOK QUEEN OF SHEBA VISITS SOLOMON HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('78d3a5e0-f0d2-4686-1d76-92753ac35b0c', 'chapter', '2CH.10', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'OFFEND REHOBOAM RULES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e28e7592-9a34-3db3-539a-9d4eb03ee1bb', 'chapter', '2CH.11', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'MEAN REHOBOAM SECURES LAND', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3247f63a-907f-933f-f1f1-b1cc4f2c19a6', 'chapter', '2CH.12', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'OLD SHISHAK ATTACK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5773e34f-959e-d702-522e-438945da9dc2', 'chapter', '2CH.13', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'NEW KING ABIJAH DEFEATS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eefc7ef8-22d7-bf01-7772-46edec9d260d', 'chapter', '2CH.14', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'FOR ASA DESTROYED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('de6b8c9b-027f-9c7b-0f79-59a873ae54a4', 'chapter', '2CH.15', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'REFORM UNDER ASA HERE S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('584bbf65-75bc-ad15-10d1-b6e031eea786', 'chapter', '2CH.16', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'OFFER HANANI BAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9e20a85b-0244-af5e-81ac-e3d19e9500a8', 'chapter', '2CH.17', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'MORE REFORM JEHOSHAPH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9100f084-5cc6-3032-93f7-a72ee10e4ecc', 'chapter', '2CH.18', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'TRUE PROPHET MICAIAH WARNS AHAB HERE SAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('15e0c457-1fb0-614b-aa34-bd1e69bd5a41', 'chapter', '2CH.19', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'HE JEHU WARNS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2885ec3f-1e1e-7f56-bb27-a695fbe14f30', 'chapter', '2CH.20', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'ENEMIES DESTROY THEMSELVES BY SINGING GODS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4b0cb97b-68bd-58a8-e198-f5039cd36161', 'chapter', '2CH.21', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'THE JEHORAM GUT DISEASE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ccc3d66f-4573-a278-4676-6ee989aea5ed', 'chapter', '2CH.22', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'EVIL AHAZIAH S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('673812fc-dbe6-3fae-e738-bb1d50a986b7', 'chapter', '2CH.23', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'MAKE JOASH KING JEHOIADA', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7609a3c3-3591-d463-4858-caad7e6492c4', 'chapter', '2CH.24', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'PRIEST JEHOIADA REPAIRS HOUSE S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('13ceadbf-7702-3022-74d8-cf875716a88b', 'chapter', '2CH.25', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'LOSE BATTLE AMAZIAH IDOLATER BAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d79556d1-8856-3e1f-1220-57f5037939e2', 'chapter', '2CH.26', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'END UZZIAH LEPROSY PRIDE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4d4eae12-fb66-71fd-6354-9265d775df9e', 'chapter', '2CH.27', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'THE JOTHAM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5a9a6620-e05c-cd6e-d20e-cb122598970d', 'chapter', '2CH.28', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'OF PECKAH ISRAEL DEFEATS AHAZ HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('31c70e06-914f-1fde-d160-41c548e5dc4a', 'chapter', '2CH.29', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'TEMPLE CLEANSED BY HEZEKIAH AND LEVITES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c6371b94-1852-24ae-5cec-c8dd53f9d0f6', 'chapter', '2CH.30', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'HEZEKIAH PASSOVER KEPT AGAIN HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('67b5c7b3-fdfb-993f-0dca-67c9a5821411', 'chapter', '2CH.31', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'END IDOLS TITHES GIVEN HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e4957ce4-5deb-46bb-ceda-b77edba13e93', 'chapter', '2CH.32', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'ENTIRE ASSYRIAN ARMY KILLED BY ANGELS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6ee857bc-e3de-b31e-6f73-a5445035362c', 'chapter', '2CH.33', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'X MANASSEH REPENTS IN CHAINS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('895ebece-a990-e889-de46-4fa98fbf740a', 'chapter', '2CH.34', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'IDOLATER MANASSEH AND JOSIAH REIGN TWO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e2b577c7-bd2a-1d3a-dde1-060305945d7b', 'chapter', '2CH.35', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'LAST PASSOVER OF JOSIAH KEPT SET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('538d8c78-4948-1cde-5156-630d1a197aee', 'chapter', '2CH.36', '0521ef7c-7a30-0626-22e3-a15393b8de52', 'END OF KINGDOM EXILE HERES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('69cce1b5-3c5b-0cbe-ca64-87ac047ad7e0', 'book', 'EZR', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'YEARS LATER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ab10184c-20f7-d669-237a-668d6fbc5c0a', 'chapter', 'EZR.1', '69cce1b5-3c5b-0cbe-ca64-87ac047ad7e0', 'YEAR OF CYRUS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('050e5c2e-76d1-bbdb-5b6e-be1e0ab3320e', 'chapter', 'EZR.2', '69cce1b5-3c5b-0cbe-ca64-87ac047ad7e0', 'EXILES RETURN WITH ZERUBBABEL LISTED BY FAMILIES CLANS NUMBER LIVESTOCKS LISTED S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eec73e47-fadf-7e04-b675-65ce63fb0a62', 'chapter', 'EZR.3', '69cce1b5-3c5b-0cbe-ca64-87ac047ad7e0', 'ALTAR REBUILTS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e82440f1-73fa-5ad0-45ee-1faa934fbfd8', 'chapter', 'EZR.4', '69cce1b5-3c5b-0cbe-ca64-87ac047ad7e0', 'REBUILDING STOPPED BY FOES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('69b05268-44c4-f080-9979-aa1407f6787b', 'chapter', 'EZR.5', '69cce1b5-3c5b-0cbe-ca64-87ac047ad7e0', 'START WORK ON TEMPLE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('296039c5-8416-d892-2e49-cff0068a4719', 'chapter', 'EZR.6', '69cce1b5-3c5b-0cbe-ca64-87ac047ad7e0', 'LAW OF DARIUS ALLOWS IT ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a52b0dbb-f5e7-86a8-37fb-d408846a069d', 'chapter', 'EZR.7', '69cce1b5-3c5b-0cbe-ca64-87ac047ad7e0', 'ARRIVAL OF EZRA TO TEACH LAWS SETS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5ef0fbd4-1ae8-0c78-f62d-b7c349c96c3d', 'chapter', 'EZR.8', '69cce1b5-3c5b-0cbe-ca64-87ac047ad7e0', 'THE COMPANIONS OF EZRA LISTED BY NAMES SETS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('656dc46b-99d6-9f05-32e8-8fa06360d19d', 'chapter', 'EZR.9', '69cce1b5-3c5b-0cbe-ca64-87ac047ad7e0', 'EZRA PRAYS FOR SIN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2ff0804e-fb37-6dc8-b61b-b8a6bc44604a', 'chapter', 'EZR.10', '69cce1b5-3c5b-0cbe-ca64-87ac047ad7e0', 'REPENTANCE OF THE PEOPLE PUT AWAY FOREIGN WIVES SADS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('16071e9c-e8c5-cbe9-2714-959dd527c18a', 'book', 'NEH', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'ORGANIZES WORK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f5afb3d5-00a3-9549-7bb6-c6c3fa4ee047', 'chapter', 'NEH.1', '16071e9c-e8c5-cbe9-2714-959dd527c18a', 'OF JERUSALEM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9d0eb6c9-008e-a93c-26cb-2cb43d0cd51c', 'chapter', 'NEH.2', '16071e9c-e8c5-cbe9-2714-959dd527c18a', 'RETURN TO BUILD WALL SET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b4af354f-efcc-9b0c-c3c6-3f285189c1d5', 'chapter', 'NEH.3', '16071e9c-e8c5-cbe9-2714-959dd527c18a', 'GATES AND WALLS REPAIRED BY GROUPS SET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('155f5b24-74d1-202b-a7bb-bce9c40d3ac2', 'chapter', 'NEH.4', '16071e9c-e8c5-cbe9-2714-959dd527c18a', 'ARMED WORKERS BUILD WALL HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4529d84f-87e0-ff2e-a411-869ae8d210de', 'chapter', 'NEH.5', '16071e9c-e8c5-cbe9-2714-959dd527c18a', 'NO USURY FOR BROTHERS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ea2ede15-bd95-ce89-9ebe-951376f6d5f4', 'chapter', 'NEH.6', '16071e9c-e8c5-cbe9-2714-959dd527c18a', 'INTIMIDATION FAILEDS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e4f81423-2c38-eb7f-21c7-3fceefd5d841', 'chapter', 'NEH.7', '16071e9c-e8c5-cbe9-2714-959dd527c18a', 'ZERUBBABEL LIST REPEATED OF ALL THE EXILES WHO RETURNED TO JERUSALEM AND JUDAH WITH HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8c0199e5-13ba-d60b-8bb7-8193e439d64b', 'chapter', 'NEH.8', '16071e9c-e8c5-cbe9-2714-959dd527c18a', 'EZRA READS THE LAW DAY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9d9ec477-100b-51e3-9dbc-1da2c3e6076f', 'chapter', 'NEH.9', '16071e9c-e8c5-cbe9-2714-959dd527c18a', 'SINFUL HISTORY CONFESSED BY LEVITES HERE SAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('11de1990-7f06-6c67-e9ce-cfcca5cbbe2d', 'chapter', 'NEH.10', '16071e9c-e8c5-cbe9-2714-959dd527c18a', 'WE FIRMLY COVENANT TO KEEP LAW SEALED AT LAST HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('44fc5a44-7891-2288-107e-45db6edcb6f9', 'chapter', 'NEH.11', '16071e9c-e8c5-cbe9-2714-959dd527c18a', 'ONE IN TEN TO LIVE IN JERUSALEM CHOSEN LOT HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cc3806a7-053b-0c8f-5cb8-ab0b8c20f511', 'chapter', 'NEH.12', '16071e9c-e8c5-cbe9-2714-959dd527c18a', 'REGISTER OF PRIESTS AND LEVITES DEDICATION OF WALL SETS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('78c1deb1-f607-15e4-f9dc-5aad45c6df7c', 'chapter', 'NEH.13', '16071e9c-e8c5-cbe9-2714-959dd527c18a', 'KEEP SABBATH AND SEPARATE PEOPLE OUT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('49bb65fc-27bd-2cee-254f-7c663f4bd943', 'book', 'EST', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'FINDS FAVOR', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7dc9bcf1-3343-d321-b8de-26903df7e9e3', 'chapter', 'EST.1', '49bb65fc-27bd-2cee-254f-7c663f4bd943', 'FEAST OF XERXES AND QUEEN S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('28006953-0e8c-c454-753f-ad6d1e2922be', 'chapter', 'EST.2', '49bb65fc-27bd-2cee-254f-7c663f4bd943', 'INTRODUCE ESTHER TO KING HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f47180ca-d9bb-a990-a0c9-a5afb5f257e6', 'chapter', 'EST.3', '49bb65fc-27bd-2cee-254f-7c663f4bd943', 'NO BOWING TO HAMAN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f865a818-74c9-a2d8-dd0b-b4debc21ad0f', 'chapter', 'EST.4', '49bb65fc-27bd-2cee-254f-7c663f4bd943', 'DECREE TO KILL JEWS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5ca37fcf-7770-0b88-23f6-19de4e9e735b', 'chapter', 'EST.5', '49bb65fc-27bd-2cee-254f-7c663f4bd943', 'SCEPTRE EXTENDS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('76f3da95-8cc8-2d67-3f83-c7f6b36a00cb', 'chapter', 'EST.6', '49bb65fc-27bd-2cee-254f-7c663f4bd943', 'FORCED TO HONORS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e13e342e-e601-4dd9-c12d-e234b5546ecd', 'chapter', 'EST.7', '49bb65fc-27bd-2cee-254f-7c663f4bd943', 'A HAMAN DIES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('18eab6d5-02a4-4f89-5938-3494ae0cd5d0', 'chapter', 'EST.8', '49bb65fc-27bd-2cee-254f-7c663f4bd943', 'VOID EDICT BY NEW ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fd9cb78b-7365-d8a3-48cd-42c550daa58f', 'chapter', 'EST.9', '49bb65fc-27bd-2cee-254f-7c663f4bd943', 'ON PURIM JEWS DEFEND THEMSELVES WARS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2ff376c6-84c5-2fb8-e7e8-c6bf60dc73ba', 'chapter', 'EST.10', '49bb65fc-27bd-2cee-254f-7c663f4bd943', 'RAY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('76b46ddc-af11-3398-998c-84ec56d4cd94', 'book', 'JOB', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'THE STORY OF A RIGHTEOUS MAN WHO LOST ALL HE EVER HAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5665b69b-9786-aa4a-9cda-45b6aac6cd9a', 'chapter', 'JOB.1', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'THIS MAN JOB PERFECT ONE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('26d9f097-4ac2-9f8c-7bf3-f9a82b60d378', 'chapter', 'JOB.2', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'HEALTH GONE HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e71b0c9d-6164-52f8-5b7f-889e2c67102e', 'chapter', 'JOB.3', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'ELIPHAZ CURSES DAY ITSELF HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('16656bb9-44d2-e49a-f79e-a9ff6f53cd29', 'chapter', 'JOB.4', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'SEE MY VISION SPIRIT HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cf6516eb-37f6-d48e-a47d-2de8db352b6f', 'chapter', 'JOB.5', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'TROUBLE COMES TO SPARKS FLYINGS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cdbcdca1-27f7-d410-e566-9f4eefbc851f', 'chapter', 'JOB.6', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'OH THAT MY GRIEF WERE WEIGHED SEES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('146ac50f-a608-ad67-6563-b43d45a16e6f', 'chapter', 'JOB.7', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'REMEMBER MY LIFE WIND HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('57dc2b34-87bf-a014-a4ae-0838b2bd2776', 'chapter', 'JOB.8', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'YOUR WORDS WIND STORM HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ee198116-653b-2fe9-f44f-c3f8b1c3a32e', 'chapter', 'JOB.9', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'ONE CANNOT ANSWER GOD ONE THOUSAND SEES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('594dfa42-8da3-4340-af09-768b6a681108', 'chapter', 'JOB.10', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'FAVOR GRANT ME LIFE SEES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6fb6ee2b-323b-0dec-e74e-1d74592a25af', 'chapter', 'JOB.11', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'ASK ZOPHAR CAN YOU SEES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b433df80-2d08-29b9-f106-af6287c297a4', 'chapter', 'JOB.12', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'ROBBERS TENTS PROSPER SEES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4afaf7a2-f9fe-6e6c-6571-15199a83feb0', 'chapter', 'JOB.13', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'I WILL SPEAK TO THE ALMIGHTY SEES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('23d5957c-6548-2cff-9e2d-fdf7ea780180', 'chapter', 'JOB.14', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'GOD DETERMINES MAN DAYS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fdf6aa89-a2ba-88eb-55a8-334278b153e4', 'chapter', 'JOB.15', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'HE TEARS HIMSELF IN ANGER WICKED PAIN SEES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e0d77f2e-0c53-d6ec-e2e7-6a8c28bdb65d', 'chapter', 'JOB.16', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'THOU HAST MADE ME WEARY HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dd23cd97-c87d-9120-cfe9-da6231b8fa9e', 'chapter', 'JOB.17', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'EYE DIM SORROW HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('baa4f8f1-5be9-66f6-0726-4fd408f0c88c', 'chapter', 'JOB.18', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'OWN NET CAST HIM DOWN SEES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5e9c11d3-8317-b96d-34a1-e6a29d9e1e45', 'chapter', 'JOB.19', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'UNDERSTAND REDEEMER LIVES SEES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e501f9b2-bc42-eae4-3446-db28175f577a', 'chapter', 'JOB.20', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'SEE WICKED JOY IS SHORT MOMENTS ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('178cb7de-ad76-40c1-3712-91cb8fe7ed57', 'chapter', 'JOB.21', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'MEN WICKED PROSPER IN LIFE DEATH SEES HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7d855857-6e5c-405c-62b6-c09adbb9fdc5', 'chapter', 'JOB.22', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'ACQUAINT NOW THYSELF WITH HIM SEES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('10727528-5902-422c-e5d6-936f39ab3448', 'chapter', 'JOB.23', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'NOT FIND HIM THERE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8ef8e23e-d6de-8fef-0643-b7b374ce5596', 'chapter', 'JOB.24', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'WHY IS LIGHT GIVEN MISERY HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b53e7635-6f40-917a-75e3-ea21394c8a59', 'chapter', 'JOB.25', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'HOW MAN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d251f7a7-3fa3-97ef-dd55-d4390ed2c572', 'chapter', 'JOB.26', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'OUT OF NORTH HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9a0adf05-5b17-fac1-ee71-88450c453f1e', 'chapter', 'JOB.27', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'LET MY LIPS NOT SPEAK SINS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bc1dbaed-0293-c7b5-026e-73a104a1f74f', 'chapter', 'JOB.28', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'O WHERE SHALL WISDOM BE FOUND HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('90237888-eb1d-f212-ba12-410b3fd2890d', 'chapter', 'JOB.29', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'SEARCHED OUT CAUSED IT SEES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c2c3f6c7-a5ba-ef3e-c2a4-8fe354c4701b', 'chapter', 'JOB.30', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'THEY WERE DRIVEN FORTH FROM MEN SEES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f1f336d1-a3db-e9b9-9c08-f0646202c823', 'chapter', 'JOB.31', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'A COVENANT WITH MINE EYES NOT LOOK ON MAID SEES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ad50930e-aacc-9318-5ce3-6548bb69bacf', 'chapter', 'JOB.32', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'LET DAYS SPEAK MULTITUDES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('753959db-baf9-15c4-10c2-023a1d007b27', 'chapter', 'JOB.33', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'LO GOD SPEAKETH ONCE YEA TWICE SEES HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d77075ce-cfde-4c7f-5610-8339cc4116cc', 'chapter', 'JOB.34', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'HEAR WORDS O YE WISE MEN GOD JUST SEES HIMS ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('34f4a678-4973-361b-bca0-593aa86546fc', 'chapter', 'JOB.35', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'EYES SEE CLOUDS HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e7b73f2e-d93b-9901-ff7f-30b33d1a08ab', 'chapter', 'JOB.36', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'ELIHU PROCEEDED SHOW GOD IS JUST SEES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f8a5c570-bdc5-b828-d6bd-e77ce5184f34', 'chapter', 'JOB.37', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'VOICE ROAR THUNDER SEES HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('97ba58d3-8ed9-bc29-dcb7-4ded6928cc79', 'chapter', 'JOB.38', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'EARTH FOUNDATIONS WHERE WAST THOU MORNING SEES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('90051c24-36cf-969f-e893-be64c952e27a', 'chapter', 'JOB.39', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'ROCK GOATS CALVE WILD ASS FREE HIMS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('66ba3f26-b417-5ba0-469a-688336e23433', 'chapter', 'JOB.40', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'HE THAT REPROVETH GOD SEES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('818491db-2ade-ddc4-b156-6009eee04d73', 'chapter', 'JOB.41', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'ALL UNDER HEAVEN MINE LEVIATHAN SEES HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('54d3bf12-b99f-5de5-93f4-bf37a0066017', 'chapter', 'JOB.42', '76b46ddc-af11-3398-998c-84ec56d4cd94', 'DUST ASHES REPENT HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'book', 'PSA', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'RESPONDING TO GODS GOODNESS WITH PRAISE AND WORSHIP WHILE ALSO PLEADING WITH GOD TO RESCUE US FROM OUR ENEMIES THE MESSIANIC PSALMS PREDICT THE COMING OF JESUS CHRIST AND HIS DEATH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('296751b9-05bb-002c-545f-6932a1305d91', 'chapter', 'PSA.1', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ROOTS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('80503e0c-cb08-49fe-63e6-5059a7260afd', 'chapter', 'PSA.2', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ENTER SON SEES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('580e32c0-8fe4-a051-b28f-4b2dcf7ea490', 'chapter', 'PSA.3', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SAVES ME S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('27a039a8-f7c4-3bfc-4bc8-6420031e1358', 'chapter', 'PSA.4', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'PRAY JOYS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2f02b9a2-1a0b-9a10-bd43-bf4d55caf54e', 'chapter', 'PSA.5', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ONE LORD HEAR S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c2438f37-7223-3fd5-8649-a9f5293d3946', 'chapter', 'PSA.6', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'NO TEARS ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('658473ab-4370-0080-9b86-d563302a637f', 'chapter', 'PSA.7', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'DEFEND ME LORD GOD HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f1b37004-38b9-e4b5-b1c0-a31cadc191af', 'chapter', 'PSA.8', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'I SEE MOONS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d62cf47d-a261-ba2e-fed6-67441483155e', 'chapter', 'PSA.9', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'NATIONS FALL BACK SEES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('80f380c7-364c-de56-943f-f7f6f5d9c6ff', 'chapter', 'PSA.10', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'GOD SEES WICKED ONE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ec10d44d-b731-efe3-f769-27beed8ebce9', 'chapter', 'PSA.11', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'TEST HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('add7b0e9-9189-f8d9-11f4-63979a12a066', 'chapter', 'PSA.12', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ONE HELPS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('de85d424-64fa-1e0c-7256-bf7485aa4a12', 'chapter', 'PSA.13', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'GIVE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('02a7bb09-4f0d-d3c1-15cf-9627cb56dc69', 'chapter', 'PSA.14', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ONE WAYS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5a120f3f-9097-fc21-56cc-dc6243e2cd1b', 'chapter', 'PSA.15', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'DWELL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('892354cf-6271-74ba-5dcb-d147b3de713c', 'chapter', 'PSA.16', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SAFE PATH ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('80edf6ae-14e8-78bf-e70d-0b12843c301b', 'chapter', 'PSA.17', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'GUARD ME AS APPLES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2c4cc47e-db2f-f903-65ab-af95e4f68129', 'chapter', 'PSA.18', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'O LORD MY ROCK AND FORTRESS AND DELIVERER SAVES ALL HI SEES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4084319c-3fc8-84ef-c499-7997f2d74b85', 'chapter', 'PSA.19', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'OH LAW OF LORD HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f7f7d51e-b3bf-d979-4cb9-9282f164e2de', 'chapter', 'PSA.20', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'DUE HELP HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cb2fd555-13fc-ebef-fcbb-9496a203d740', 'chapter', 'PSA.21', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'NOW KING JOY SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a0b36a78-0e08-2c9d-d67c-b7d8cac58f45', 'chapter', 'PSA.22', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'EVER MY GOD WHY HAST THOU FORSAKEN HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2872f2c6-21e4-16be-dc7c-b5dddd7bfe31', 'chapter', 'PSA.23', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SEARCH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5e41b159-bf59-7f24-8dc3-63dbdb7ba054', 'chapter', 'PSA.24', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SOUL CLEAN S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4faf5331-7b1c-17c0-5c64-0440ab753fb6', 'chapter', 'PSA.25', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'WAIT ON THE LORD MY GOD SEES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e332bdbb-fe39-7dfd-54ea-0b566e118b7e', 'chapter', 'PSA.26', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'I WALK IN TRUTH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3f6c6ecc-c475-221d-b57e-d1bd6f42811a', 'chapter', 'PSA.27', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'TEACH ME LORD WAY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3fa8c402-7cb4-1bda-a191-682f9a5f669c', 'chapter', 'PSA.28', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'HANDS UP HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d898b5d3-a8c9-f6c5-3af5-34e5da5098e0', 'chapter', 'PSA.29', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'PEACE AND JOY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6ea7afba-0cd8-aa98-9d05-254562f7e53a', 'chapter', 'PSA.30', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'RAISED UP SOUL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7b30ec60-f8f2-7662-4327-182defc6b512', 'chapter', 'PSA.31', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ALL TRUST IN THE LORD GOD SEES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6af35a92-92f0-5b3f-1528-20ea9f2b170c', 'chapter', 'PSA.32', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'I CONFESS SIN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('110129c7-5a0e-1ba5-1bde-50c4d5c52751', 'chapter', 'PSA.33', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SING UNTO HIM A NEW SONG HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('035ca33d-26f3-eb69-1e17-978bd0335ca6', 'chapter', 'PSA.34', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'EYES OF THE LORD SEE GOOD HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('06451b3d-8736-61bf-e635-c421e86aa094', 'chapter', 'PSA.35', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'AND STOP THEM THAT FIGHT ME HIMS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5177f7be-f809-1e72-c4c8-d38fc74c4abb', 'chapter', 'PSA.36', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'NO FEAR OF GODS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0b785952-bba7-84f8-b27a-a47dc7ed3a08', 'chapter', 'PSA.37', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'DO NOT FRET BECAUSE OF EVIL DOERS TRUSTS IN GOD HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9d93f573-fd1e-1e1e-3b0c-54194d821606', 'chapter', 'PSA.38', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'WRATH OF GOD ARROWS FAST HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4bbae387-9a78-4b2e-864b-b5eca8b565f3', 'chapter', 'PSA.39', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'O LORD HEAR ME HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3de8d048-337a-a6c2-f611-0587dc2e0240', 'chapter', 'PSA.40', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'RESCUE ME CLAY HIMS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('975db5fb-eead-b2c9-49aa-2f39bcb76523', 'chapter', 'PSA.41', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SICK BED HELPS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('26311991-5548-d422-ae7b-37fd130d060c', 'chapter', 'PSA.42', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'HOPE IN GOD HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4759039a-9dba-bc27-318e-30eb7953acbb', 'chapter', 'PSA.43', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'I WALK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e54b179a-0505-39b1-c86b-2ade6a52f79a', 'chapter', 'PSA.44', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'PROUD BOAST IN GOD ALL DAY LONG S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0b44970c-c8e2-53c0-2097-5aaa2bddeb39', 'chapter', 'PSA.45', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'WEDDING SONG SEES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c83ed06a-1332-a3fc-22a8-a3859e3fa56c', 'chapter', 'PSA.46', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'HELP TROUBLE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('99c7fa26-a4d5-19e3-d184-83330143d59a', 'chapter', 'PSA.47', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'I SING GODS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a3ac3935-0d5d-6787-5fbf-16872e1fb0e3', 'chapter', 'PSA.48', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'LIFT UP ZION ONES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f9f5c7d8-a620-563f-cf83-6b3463a523f3', 'chapter', 'PSA.49', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'EACH MAN DIES SEES ONES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c716b634-3ccd-034c-0071-bf4adba600c8', 'chapter', 'PSA.50', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ANIMALS ALL MINE SAYS GOD HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4dc570dd-026a-a81e-c9ec-2540f069df30', 'chapter', 'PSA.51', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'LAVISH MERCY ON ME GOD S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bc12816b-5161-502d-d3b1-9b5bfff9698a', 'chapter', 'PSA.52', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SEE THE MAN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('23601703-eb85-52bf-8634-519461a773b0', 'chapter', 'PSA.53', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'O FOOLS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bf1d6380-d1d9-999f-2746-64215dd31d03', 'chapter', 'PSA.54', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'PRAY GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6abfa908-3bc2-d277-d72c-4965fc738843', 'chapter', 'PSA.55', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'LISTEN TO MY PRAYER O GOD HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8efa75f7-4eae-f0ed-320f-dfc917fb583c', 'chapter', 'PSA.56', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'EVERY DAY WREST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('41ca2aff-f5f7-d059-22b4-23772fb0e701', 'chapter', 'PSA.57', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ABOVE GLORY S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('05495a94-df2b-c0f2-d163-5373f9439a43', 'chapter', 'PSA.58', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'DO YE JUDGE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6e623df7-40ba-3fea-083e-79d9fab1b95b', 'chapter', 'PSA.59', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'I SING OF THY POWER HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8edef33e-7a33-e687-97f9-25cc8fceda33', 'chapter', 'PSA.60', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'NO HELP MAN ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3e927e13-ff21-7141-be02-9fb81b194450', 'chapter', 'PSA.61', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'GIVE EARS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f144e7ea-cc04-ac22-586a-33ecf8e93939', 'chapter', 'PSA.62', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'WAIT UPON GOD S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5d7cccba-3b79-6a53-f472-6a999dbe3dbf', 'chapter', 'PSA.63', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'I SEEK THEE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d354093d-82c1-e44d-1e8e-f36edfddd31b', 'chapter', 'PSA.64', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'TONGUES HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('aaf936ee-2f2d-c494-28a7-d5593fbe5474', 'chapter', 'PSA.65', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'HILL OF GOD HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dbfd1633-ec0e-5317-77a9-511958e11e7a', 'chapter', 'PSA.66', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'GOD RULES BY HIS POWER HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4fa8f3a8-c29b-adc3-8630-2a89e4223b83', 'chapter', 'PSA.67', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'OUR GOD S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('06ff30ad-dd99-846b-a2fa-72c592bbf53e', 'chapter', 'PSA.68', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'DRIVE THEM AWAY AS SMOKE IS DRIVEN HIMS HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('25879991-ed2d-3096-f01d-f51134100307', 'chapter', 'PSA.69', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'THE WATERS ARE COME IN UNTO MY SOUL HIMS SEES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c0bf6205-47eb-1082-f6a6-15479de33f44', 'chapter', 'PSA.70', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'O LORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('351664ab-04e7-5dc3-d30f-ab08040fe59e', 'chapter', 'PSA.71', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'RESORT HI THOU ART MY ROCK ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('97dc9532-27f2-c4b3-1327-5f4c4ab0dfcc', 'chapter', 'PSA.72', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ENTIRE EARTH SEE GLORY S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a74733bc-51c2-6c05-67eb-e757992fc605', 'chapter', 'PSA.73', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SURELY GOD IS GOOD TO ISRAEL HIMS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f437937b-ff4a-f134-f016-7734a57cefe9', 'chapter', 'PSA.74', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'CONGREGATION PURCHASED HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a0fd44f4-863a-4e77-a51f-95f61b587864', 'chapter', 'PSA.75', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'UNTO THEE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4b81a019-96c1-6940-d89f-115755cead0d', 'chapter', 'PSA.76', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'EARTH FEARED S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7798ab09-6d2a-46d8-4813-4d196d878983', 'chapter', 'PSA.77', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'USE VOICE CRY UNTO GOD HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bdf8bd9e-65a2-06eb-92b8-fa980730c97e', 'chapter', 'PSA.78', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SO HE FED THEM ACCORDING TO THE INTEGRITY OF HIS HEART AND GUIDED BY HANDS SKILLFULLY HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b6100f0d-2098-19aa-d1f2-ef17f7ea9652', 'chapter', 'PSA.79', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'FORGIVE SINS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('61b8cc12-50ca-f47b-b9f4-9108f4a06130', 'chapter', 'PSA.80', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'RETURN WE BESEECH THEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('925e9ecc-b6e7-b19a-5231-b6ba50958ade', 'chapter', 'PSA.81', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'O SING UNTO GOD HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('07ab819d-55b1-a70a-80bd-a4acb3d3a948', 'chapter', 'PSA.82', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'MIGHTY HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fc6c33b7-8759-c734-8eb4-04627869e20a', 'chapter', 'PSA.83', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'O GOD KEEP NOT SILENCE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b7654628-a6ff-3cd8-05fd-a362144ebfc1', 'chapter', 'PSA.84', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'USED SWALLOW S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('daac4764-1aaa-76bf-0b8a-031c4966ccfb', 'chapter', 'PSA.85', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'REVIVE US AGAIN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e22cee40-ee13-40b2-8b06-062e8e2dbb59', 'chapter', 'PSA.86', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ENTREAT THEE LORD HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('689c4a65-526b-0364-d330-58900e5f9583', 'chapter', 'PSA.87', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'NEVER HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bd0c1e12-bae4-2f6f-c47f-c8a00929b789', 'chapter', 'PSA.88', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ELECT CRY LORD SOUL HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('afd44735-a60c-f7dc-5fb6-93e0feabda62', 'chapter', 'PSA.89', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'MAKE KNOWN THY FAITHFULNESS TO ALL GENERATIONS SAID MERCY HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('30aa3f70-4e06-d393-2758-c209a672d7f8', 'chapter', 'PSA.90', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'IN MORNING FLOURISH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d833e583-2be8-0ba0-bfc9-2f57400637ac', 'chapter', 'PSA.91', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ETERNAL ASSURANCE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c2e1512f-b4e2-fcca-c772-0e734b70f746', 'verse', 'PSA.91.1', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Entering shelter above', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4c93a80b-49cd-a2a7-a646-f94cfd0e177a', 'verse', 'PSA.91.2', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Trusting my refuge', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('20c089f9-d6d6-316b-d908-f38da6d7c85d', 'verse', 'PSA.91.3', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Escaping deadly pestilence', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6e8d95c4-7998-4383-ab80-39f9b9025c41', 'verse', 'PSA.91.4', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Remaining under wings', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('975820da-3d85-84ec-9295-25fd55bcb146', 'verse', 'PSA.91.5', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'No terror feared', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('23096839-4499-242b-bf58-bf5b106f50b0', 'verse', 'PSA.91.6', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Avoiding darkness plague', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('23409234-0bc2-37dd-53d1-c42c5e1314a1', 'verse', 'PSA.91.7', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Letting thousands fall', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6ca605d6-bc38-4854-c19d-b3a2a7a459bd', 'verse', 'PSA.91.8', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Alone you observe', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('899adc75-d511-de45-0564-e069ae99cb32', 'verse', 'PSA.91.9', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Sheltered by Lord', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('59d42a68-3040-61a4-9536-1baf98d55995', 'verse', 'PSA.91.10', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Safe from harm', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9033ef0e-84c8-a680-74ab-ae66f31ef61b', 'verse', 'PSA.91.11', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Upheld by angels', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1ee78d93-344c-b8fc-39fb-8fc2c72f3529', 'verse', 'PSA.91.12', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Raised above stones', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b585472c-176b-fcd6-a5a4-5945a4c58daa', 'verse', 'PSA.91.13', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Ascending over beasts', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d0086061-1a2c-7ccc-4688-7e390af3cc39', 'verse', 'PSA.91.14', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Not abandoned, rescued', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f213d541-f925-9460-0136-b0b76bcd7f5c', 'verse', 'PSA.91.15', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Calling, I answer', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6eed467e-d346-ffc8-d3dc-f08996ecbd3c', 'verse', 'PSA.91.16', 'd833e583-2be8-0ba0-bfc9-2f57400637ac', 'Exhibiting My salvation', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3d410efa-3395-9dcc-e9d5-72544f1bcd9f', 'chapter', 'PSA.92', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SHOW FORTH LOVE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a411ff34-fed9-607d-d4eb-e15c7561e645', 'chapter', 'PSA.93', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'TESTS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c0aaae81-a5cb-5cce-d96d-2e1c2b4c39f5', 'chapter', 'PSA.94', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'HAPPY IS THE MAN WHOM THOU HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('aad49523-fa10-fa19-205f-2afafb8a56be', 'chapter', 'PSA.95', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ENTER HI REST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b55cb96b-1cb9-3129-a4f1-a07cea1fe817', 'chapter', 'PSA.96', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'MADE HEAVENS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ddc044eb-886c-10cc-8a7a-b65e15c73e70', 'chapter', 'PSA.97', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'EARTH REJOICE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('13004d06-8b9a-9060-c047-db5fe3914b61', 'chapter', 'PSA.98', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SING NEWS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d99fb64c-1d1d-a7c6-3c9f-b43adccffc71', 'chapter', 'PSA.99', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SIT HIGH HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c369e516-01cb-2c64-992f-205c36d6b7ac', 'chapter', 'PSA.100', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'I AM HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c69da0b8-4051-18ac-f779-0d56a769d9de', 'chapter', 'PSA.101', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'A PURE HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fa34d847-2e5c-12b4-9f92-ffdfc5417488', 'chapter', 'PSA.102', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'NATIONS FEAR THE NAME OF THE LORD S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5d7b4583-13fa-949c-fb63-d9d39a01fed5', 'chapter', 'PSA.103', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'I BLESS LORD MY SOUL FORGET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d4f1b404-a1cf-a408-dc21-f9a0763d43cd', 'chapter', 'PSA.104', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'CIVILIZED MAN GOETH FORTH UNTO HIS WORK HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('714b86ac-fa03-d2bb-7df7-05f3dff44b31', 'chapter', 'PSA.105', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'PUBLISH HIS DEEDS AMONG THE PEOPLE HE IS THE LORD GOD HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('883d27d1-b973-80b0-7e7b-2780ad9da279', 'chapter', 'PSA.106', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SAVED THEM FROM THE HAND OF HIM THAT HATED THEM AMEN HI SEES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a1fee90e-effc-8b47-b8da-971efad691fb', 'chapter', 'PSA.107', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ADVISE MEN TO PRAISE THE LORD FOR HIS GOODNESS WORKS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b23a18e4-e505-44c2-aa6f-591ec1746d12', 'chapter', 'PSA.108', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'LAWGIVER MINE S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ec928742-696c-0941-0839-a6e3928266b6', 'chapter', 'PSA.109', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'MOUTH OF THE WICKED OPENED AGAINST HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('de4384f4-c610-6de5-e4a2-e29b5e23fc86', 'chapter', 'PSA.110', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SMITETH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0e117b03-a205-522a-c2e9-520aa37b713c', 'chapter', 'PSA.111', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'PRAISE WORK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f3309774-c692-6ceb-8523-5f1227b09bcd', 'chapter', 'PSA.112', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'RIGHT MAN HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('839951eb-e354-8813-a287-95e95708037d', 'chapter', 'PSA.113', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'EXALT HIM S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e1a03271-abdb-094d-2cf9-d643a1d2945a', 'chapter', 'PSA.114', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'DID FLEE S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f5305f8b-ceb0-757f-76b4-afd79fa52a22', 'chapter', 'PSA.115', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'IDOLS ARE SILVER GOLD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d2057257-7aa2-cb82-c0a3-fdcde35b66dd', 'chapter', 'PSA.116', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'CALL UPON HIM AS I LIVE S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e6df6d76-ded1-0cbe-a380-3644d15b012b', 'chapter', 'PSA.117', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'TO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6e1a63d1-cbe2-335d-9516-266a81fca3c6', 'chapter', 'PSA.118', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'THE LORD IS ON MY SIDE I WILL NOT FEAR', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('47b4b605-1e6f-bd49-01bf-0d2fc64ce984', 'chapter', 'PSA.119', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'HAVE RESPECT UNTO THY WAYS DELIGHT IN STATUTES FORGET NOT WORD OPEN THOU MINE EYES MAKE ME UNDERSTAND WAY OF PRECEPTS INCLINE HEART UNTO TESTIMONIES QUICKEN ME IN THY RIGHTEOUSNESS ORDER STEPS AND KEEP LAWS HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ddc47acd-1a9d-34bf-0124-790adf52f6aa', 'chapter', 'PSA.120', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'EVIL ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('368e93b2-e5a2-f5a6-213f-6c431a3fcb90', 'chapter', 'PSA.121', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'COMING HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0fea7e27-7d39-4836-34dd-c3ca50e99928', 'chapter', 'PSA.122', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'OUR FEET HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d04c8c5a-1d8c-0ba3-52b7-899483f4ce1a', 'chapter', 'PSA.123', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'MAID', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2527b977-a060-3ae5-8c87-351fc99b7acd', 'chapter', 'PSA.124', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ISRAEL HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('76a26638-a29a-6090-4a0e-c7e82d5a0f01', 'chapter', 'PSA.125', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'NO ROD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('55857323-4f1c-5c69-3b71-ef424d1595d5', 'chapter', 'PSA.126', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'GREAT S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9053a9f4-d788-47a2-c222-2391b40f642d', 'chapter', 'PSA.127', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'OF HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cea06384-69df-ff18-5f02-cb122bf4a83d', 'chapter', 'PSA.128', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'FRUITS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('126912f4-ee18-7392-eb07-c1caff4d69cc', 'chapter', 'PSA.129', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'JESUS HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('35007cff-85f7-4769-aa80-60b04463956f', 'chapter', 'PSA.130', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ENTER HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('28499dd5-037e-b8ef-e25f-d56add4582e8', 'chapter', 'PSA.131', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('21934bd8-9512-a947-9925-ee74a89c2c93', 'chapter', 'PSA.132', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'UNTIL I FIND A PLACE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d8ebb3d0-25dc-4042-09a8-0b9942d0082b', 'chapter', 'PSA.133', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SIT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f96a7cbc-e058-bccc-25cd-e20dd83fbf4e', 'chapter', 'PSA.134', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'CRY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6b7f6d0c-eb30-7fa5-e2f3-04a3cb6e65ea', 'chapter', 'PSA.135', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'HOUSE OF LORD PRAISE HIM S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4b15f799-e9d9-7e8c-b01d-4494cb018124', 'chapter', 'PSA.136', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'REDEEMED US FROM OUR ENEMIES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('af3c3014-1032-abf6-e6ce-d40fa9dfab43', 'chapter', 'PSA.137', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'IF I FORGET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5b8458b8-00cc-08d0-aac2-94b5f77559c8', 'chapter', 'PSA.138', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SING HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b412e104-bc6e-8a00-743f-336975266209', 'chapter', 'PSA.139', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'THOUGHTS ARE PRECIOUS ONES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1d3cca65-fb48-b3d4-3cf0-4f96dc93a8e2', 'chapter', 'PSA.140', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ADDER POISON HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ed32cddd-06ed-2fc2-4186-fdde1fa228aa', 'chapter', 'PSA.141', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'NOT EAT HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c3466761-4efe-d26f-4322-1c2cbbb69bda', 'chapter', 'PSA.142', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'DID LOOK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c7604e51-e916-a5ba-cb4a-a11cc19d19d5', 'chapter', 'PSA.143', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'HAY SPIRIT ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c4d22b2a-7f29-66f8-172f-87e0974661f1', 'chapter', 'PSA.144', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'I SING NEW SONG HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('907244a8-fb59-ac67-e3aa-751e4b7108fe', 'chapter', 'PSA.145', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'SPEAK OF GLORY OF KINGDOM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('befd7695-aaa0-975b-64b5-ef6698a90ee9', 'chapter', 'PSA.146', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'DO JUDGMENT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('98d8f2dd-58bb-bed5-c907-0f08b8dee9cf', 'chapter', 'PSA.147', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'EAT FINEST OF THE WHEAT S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b8858257-46ae-fd2d-09d3-8334eb7cb21c', 'chapter', 'PSA.148', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'ANGELS PRAISES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cf9d7dff-5811-8b34-48d7-65fd58986bf2', 'chapter', 'PSA.149', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'TWO EDGED S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b784a5d5-ec02-4c15-3c0e-8b0c8cfc2636', 'chapter', 'PSA.150', '90b62e93-3ca6-3e0e-843d-4177dbf34b48', 'HIGH HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2880b9cf-994b-59d6-e93a-334103e2475e', 'book', 'PRO', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'UNDERSTANDING GODLY WISDOM FOR LIFE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d67a985a-01af-b031-b161-465d64a20383', 'chapter', 'PRO.1', '2880b9cf-994b-59d6-e93a-334103e2475e', 'USE FEAR LORD BEGINNING KNOWLEDGE HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6c7364db-c023-25c5-43ac-6104abc5aef4', 'chapter', 'PRO.2', '2880b9cf-994b-59d6-e93a-334103e2475e', 'NOW WISDOM SAVES MEN SEES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dad807f9-441e-3b10-536f-ff0eb0138edf', 'chapter', 'PRO.3', '2880b9cf-994b-59d6-e93a-334103e2475e', 'DO TRUST IN THE LORD WITH ALL YOUR HEART HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d32f9568-7fec-290b-859a-3b8ac29e8b69', 'chapter', 'PRO.4', '2880b9cf-994b-59d6-e93a-334103e2475e', 'EVERY MAN GET WISDOM GUARD HEART', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('54bd83bc-48ae-d930-6c56-c3f10a4d2df1', 'chapter', 'PRO.5', '2880b9cf-994b-59d6-e93a-334103e2475e', 'RUN WARNING AGAINST SINS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8578b01c-8bad-f8b6-6e14-db5d31e5fd5a', 'chapter', 'PRO.6', '2880b9cf-994b-59d6-e93a-334103e2475e', 'SEE SIX SEVEN THINGS GOD HATES SO MUCH ONES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('99a91b55-59ff-1005-c92d-adb39bcc5189', 'chapter', 'PRO.7', '2880b9cf-994b-59d6-e93a-334103e2475e', 'TELL SAY BEWARE WILES HARLOT HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('926fd536-d000-1e2c-f479-db86a32c2ee9', 'chapter', 'PRO.8', '2880b9cf-994b-59d6-e93a-334103e2475e', 'ALL WISDOM CALLS OUT TO MEN CREATION SEES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b7b1c096-19ef-e7bc-ce37-09251f6f0826', 'chapter', 'PRO.9', '2880b9cf-994b-59d6-e93a-334103e2475e', 'NO WISDOM FOLLY CALLS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9e5ce0d8-853d-61c7-e742-7988b9521fb8', 'chapter', 'PRO.10', '2880b9cf-994b-59d6-e93a-334103e2475e', 'DO PROVERBS WISE SON GLADS FATHER HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('426395a2-1bb5-3d14-cba7-3e5e8386ea5a', 'chapter', 'PRO.11', '2880b9cf-994b-59d6-e93a-334103e2475e', 'IN SCALE WEIGHTS CITY EXALTED HIMS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('207bd8bd-3e04-a570-ca19-dc23dbc1a6f2', 'chapter', 'PRO.12', '2880b9cf-994b-59d6-e93a-334103e2475e', 'NO LOVES DISCIPLINE KNOWLEDGE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b4977594-7113-8859-7da1-676a7fda6478', 'chapter', 'PRO.13', '2880b9cf-994b-59d6-e93a-334103e2475e', 'GET WISE SON HEEDS FATHERS LAW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6b5e2c3f-4979-2c18-b929-8f6c2d1b41e9', 'chapter', 'PRO.14', '2880b9cf-994b-59d6-e93a-334103e2475e', 'GREAT WISE WOMAN BUILDS HOUSE TEARS HIMS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3e5c343a-edc1-edf4-79ed-722e08fe44bb', 'chapter', 'PRO.15', '2880b9cf-994b-59d6-e93a-334103e2475e', 'OH SOFT ANSWER TURNS AWAY WRATH BADLY HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('466290ce-e6f9-eab7-cbb4-144987663e9e', 'chapter', 'PRO.16', '2880b9cf-994b-59d6-e93a-334103e2475e', 'DO PRIDE GOES BEFORE DESTRUCTION HIMS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('07cf83bb-f9b1-62f6-21b7-0b3e4b9d5dc5', 'chapter', 'PRO.17', '2880b9cf-994b-59d6-e93a-334103e2475e', 'LOOK BETTER DRY MORSEL QUIETS HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9890f6b1-003e-b054-7c4b-63e59e1b9f0e', 'chapter', 'PRO.18', '2880b9cf-994b-59d6-e93a-334103e2475e', 'YEA FOOL TAKES NO PLEASURE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('277dede7-9b90-b918-5e5e-d31c4dd437b1', 'chapter', 'PRO.19', '2880b9cf-994b-59d6-e93a-334103e2475e', 'WALK BETTER POOR WALK INTEGRITY HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ccc3885a-b6dd-be11-0734-e8be9d6d335e', 'chapter', 'PRO.20', '2880b9cf-994b-59d6-e93a-334103e2475e', 'IS WINE MOCKER STRONG DRINK SEES HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d8f84275-9523-37d9-88c0-c5a26b3f1f6a', 'chapter', 'PRO.21', '2880b9cf-994b-59d6-e93a-334103e2475e', 'SEE KINGS HEART LORDS HAND TURNED HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a8759fd9-abed-64a9-62ba-ee1f376ea357', 'chapter', 'PRO.22', '2880b9cf-994b-59d6-e93a-334103e2475e', 'DO GOOD NAME CHOSEN OVER RICHES HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0a35fa8c-423c-a3cb-44e3-ddeea234abf4', 'chapter', 'PRO.23', '2880b9cf-994b-59d6-e93a-334103e2475e', 'OH EAT WITH RULER KNIFE TO THROAT SEES HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2f5dd8e8-68df-a97b-3b71-2f6da0a5c9c1', 'chapter', 'PRO.24', '2880b9cf-994b-59d6-e93a-334103e2475e', 'MEN ENVY EVIL MEN DESIRE THEM HIMS SEES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('41206c93-9a21-2d52-e874-375955aab5c6', 'chapter', 'PRO.25', '2880b9cf-994b-59d6-e93a-334103e2475e', 'FIT WORDS FITLY SPOKEN APPLES HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1129afd0-165b-6e0b-a9de-4848397361b6', 'chapter', 'PRO.26', '2880b9cf-994b-59d6-e93a-334103e2475e', 'OH LIKE SNOW SUMMER FOOL HONOR HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('15c5f2f4-7453-4aa8-3d5f-1c9d0f239b3b', 'chapter', 'PRO.27', '2880b9cf-994b-59d6-e93a-334103e2475e', 'RUN BOAST NOT TOMORROW DAY KNOWS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5cce5fa3-7100-3940-64d2-722b03d2b08e', 'chapter', 'PRO.28', '2880b9cf-994b-59d6-e93a-334103e2475e', 'LOOK WICKED FLEE NO ONE PURSUES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('722b6955-883f-0b0e-e852-ba2a5e54e26e', 'chapter', 'PRO.29', '2880b9cf-994b-59d6-e93a-334103e2475e', 'IS ONE WHO HARDENS NECK DIES HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f605bddb-6157-3d41-8929-0162dd3a1bc1', 'chapter', 'PRO.30', '2880b9cf-994b-59d6-e93a-334103e2475e', 'FOR EVERY WORD GOD PROVE TRUE SEES HIMS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9fe761e0-71e6-c36f-cad4-38fe262b0b64', 'chapter', 'PRO.31', '2880b9cf-994b-59d6-e93a-334103e2475e', 'EXCELLENT WIFE WHO CAN FIND HER ONES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('17697122-0803-c01f-7ae0-fed5fb113d62', 'book', 'ECC', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'TRUTHFULNESS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e5e5761f-0339-14af-d289-f3ab7f8d8e23', 'chapter', 'ECC.1', '17697122-0803-c01f-7ae0-fed5fb113d62', 'THE SUN ALSO RISES SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fc11ff65-5370-073d-8e87-bd0f8994178d', 'chapter', 'ECC.2', '17697122-0803-c01f-7ae0-fed5fb113d62', 'RICHES PLEASURE VANITY HERE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1ec38519-a3ab-fb03-f462-3c7682bf0638', 'chapter', 'ECC.3', '17697122-0803-c01f-7ae0-fed5fb113d62', 'UNDER HEAVEN TIME SEES HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b850185e-b8fd-8bd3-4b62-aee67031c85f', 'chapter', 'ECC.4', '17697122-0803-c01f-7ae0-fed5fb113d62', 'TWO BETTER THAN ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ccfd25cb-2e66-41cb-522f-9f114f73b68c', 'chapter', 'ECC.5', '17697122-0803-c01f-7ae0-fed5fb113d62', 'HEAR GOD IN HOUSE OF GOD S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e8a7fe15-b283-539b-91dc-87645dab2ea4', 'chapter', 'ECC.6', '17697122-0803-c01f-7ae0-fed5fb113d62', 'FOOL WALKS HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6976afad-ff16-0f7b-6efa-b3b3d133396b', 'chapter', 'ECC.7', '17697122-0803-c01f-7ae0-fed5fb113d62', 'USE WISDOM FOR GOOD NAME BETTER HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6abf68a2-bcc1-219c-ff0a-b33ffdc0b6d2', 'chapter', 'ECC.8', '17697122-0803-c01f-7ae0-fed5fb113d62', 'LORD KEEPS COMMAND S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a8050537-355a-dc6d-08c8-8e4128ee9c60', 'chapter', 'ECC.9', '17697122-0803-c01f-7ae0-fed5fb113d62', 'NO WORK IN GRAVE SEES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e062c706-74bc-3223-cd8d-3cd258326e58', 'chapter', 'ECC.10', '17697122-0803-c01f-7ae0-fed5fb113d62', 'EXCELLENT WISDOM SAVES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('50758780-42b0-bfe1-b5ca-f79417db92da', 'chapter', 'ECC.11', '17697122-0803-c01f-7ae0-fed5fb113d62', 'SOW SEED HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9dd9870d-cd87-e4f8-11f5-dbd3890754bc', 'chapter', 'ECC.12', '17697122-0803-c01f-7ae0-fed5fb113d62', 'SPIRIT RETURNS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9d0c1dc7-69f8-e333-dec7-db0389149d8f', 'book', 'SNG', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'HOLY LOVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('653b2845-9e27-b72b-b073-ee2b79de75a9', 'chapter', 'SNG.1', '9d0c1dc7-69f8-e333-dec7-db0389149d8f', 'HOW BEAUTIFUL LOVE S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b345a29e-7be9-0521-d486-e2adbf207d15', 'chapter', 'SNG.2', '9d0c1dc7-69f8-e333-dec7-db0389149d8f', 'O MY DOVE IN CLEFTS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c350206d-549f-33d8-6f41-cf51c25ef29f', 'chapter', 'SNG.3', '9d0c1dc7-69f8-e333-dec7-db0389149d8f', 'LOST HIM BED S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9447ef22-3839-be22-f760-498da87d3527', 'chapter', 'SNG.4', '9d0c1dc7-69f8-e333-dec7-db0389149d8f', 'YOUR LIPS DRIP LOVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('31de2d12-8a40-1039-7d0d-207e66856333', 'chapter', 'SNG.5', '9d0c1dc7-69f8-e333-dec7-db0389149d8f', 'LOVE SICK I AM OPEN S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b12dc64e-c7a9-cf37-7f22-3c6cf23250f4', 'chapter', 'SNG.6', '9d0c1dc7-69f8-e333-dec7-db0389149d8f', 'O MY LOVE GONE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c96eb954-31f5-fe6a-c492-bda4749decad', 'chapter', 'SNG.7', '9d0c1dc7-69f8-e333-dec7-db0389149d8f', 'VINEYARDS SEE S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('60d48d71-36a6-ae3a-8264-ad048870ea65', 'chapter', 'SNG.8', '9d0c1dc7-69f8-e333-dec7-db0389149d8f', 'EIGHT SEAL ARM HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e8030fe6-e3c4-15de-0d60-987473246b20', 'book', 'ISA', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'ANNOUNCES GODS JUDGMENT AND SALVATION THROUGH THE SUFFERING SERVANT MESSIAH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a2077833-717b-0149-451d-0527c242d2b5', 'chapter', 'ISA.1', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'AH SINFUL ZION REDEEMED BY JUDGE ME HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('36ac329d-aa4c-8870-e4b6-ccc74eee99d8', 'chapter', 'ISA.2', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'NATIONS FLOW MOUNTAIN ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('082a1c55-f6d6-4c97-edac-2ff6f059f4f1', 'chapter', 'ISA.3', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'NOW JUDGE JUDAH JERUSALEM SINS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('494e7af5-51eb-a2d4-2eac-a64f5e095634', 'chapter', 'ISA.4', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'ONLY HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('636b1f0f-e78a-b18a-c643-342df39aaacb', 'chapter', 'ISA.5', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'UNDONE WOES ON VINEYARD WILD GRAPES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ea7fb1ae-ccd2-5a00-f904-e294f3ca7d52', 'chapter', 'ISA.6', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'NO HOLY LORD SAW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('45719836-6dda-a8c9-ab6f-607eb32ab023', 'chapter', 'ISA.7', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'CHRIST BORN TO VIRGIN SAYS HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fc6d27ae-1ec8-89f6-1f9f-2485d51b748c', 'chapter', 'ISA.8', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'EMMANUEL WITH US FEAR GOD HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('98a691ba-13d6-1af9-c673-b086b518cb1c', 'chapter', 'ISA.9', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'SON GIVEN PRINCE PEACE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1e59b139-a1a3-79d5-ec6c-293574b679e3', 'chapter', 'ISA.10', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'GOD PUNISH ASSYRIAN PRIDE REMNANT ONE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f0b3a05c-427b-19c2-3b42-252bcc861228', 'chapter', 'ISA.11', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'OFFSHOOT JESSE SON', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('486cd7f4-ff2d-8ef3-db7c-8812e787d640', 'chapter', 'ISA.12', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'DO WELL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('76257f57-6901-3e4b-6dcd-620dd3fa8af7', 'chapter', 'ISA.13', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'SAD DAY LORD BABYLON FALLS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5060f321-5595-6f99-020f-0053d1a30ab8', 'chapter', 'ISA.14', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'JACOB ISRAEL RESTORED KING BABYLON HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('56874e5c-9fca-bc96-e78e-a9b6199bf4ca', 'chapter', 'ISA.15', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'USE MOAB HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5193595f-b658-2431-d37a-f4ed778f4678', 'chapter', 'ISA.16', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'DO WAIL MOAB SEES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7fe1c332-64ed-60bc-c1ea-0614d6fdbe5c', 'chapter', 'ISA.17', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'GLORY JACOB FADE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a25a69ac-d403-4b82-33a1-f7ef8f264fb3', 'chapter', 'ISA.18', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'MEN LAND', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a8123ab4-124f-509b-c4a9-02e9efb61c94', 'chapter', 'ISA.19', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'EGYPT IDOLS MOVED AT PRESENCE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('45f229d5-c59b-5038-60e1-7b438de1897c', 'chapter', 'ISA.20', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'NO CLAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b05fe37a-c4c4-420b-af2d-a7db50070f19', 'chapter', 'ISA.21', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'THE BABYLON FALLS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e7041bf0-2b96-b6e6-7aa1-c48055ec56ab', 'chapter', 'ISA.22', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'ALL VISION VALLEY JERUSALEM S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ee6b2474-18a1-efee-763a-a8c92c5ab872', 'chapter', 'ISA.23', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'NO TYRE SHIPS WAIL HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('54f0583b-aa95-c33c-e52f-96134acb8896', 'chapter', 'ISA.24', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'DO EARTH MOURN FADE AWAY SON', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('35d37612-9c26-d835-b2a4-a8b2bbde5870', 'chapter', 'ISA.25', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'SONGS WINES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d4c4a464-6bee-827b-1b6e-35c54e243440', 'chapter', 'ISA.26', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'A SONG IN LAND JUDAH TRUST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d1e345e2-0e86-909b-0b53-0a7f86f7d2e4', 'chapter', 'ISA.27', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'LEVIATHAN DEAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1ce9429a-34f8-cdc5-3c5f-2b712adee6c3', 'chapter', 'ISA.28', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'VAIN CROWN PRIDE DRUNKARD EPHRAIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('56316c2a-e304-4007-878a-64a9bc53af29', 'chapter', 'ISA.29', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'ARIEL SLEEP BOOK SEALED HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1f194785-68e0-759d-3ceb-7056f9528735', 'chapter', 'ISA.30', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'THE REBELLIOUS CHILDREN EGYPT HELP HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ed6dcc25-b671-2191-e04b-e05a89834e74', 'chapter', 'ISA.31', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'ISRAEL KEY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3fbb5859-42a3-c232-f9ba-e5c6e5a817e1', 'chapter', 'ISA.32', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'OF KING REIGN RIGHT ONES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cc96bb22-640b-97de-fab2-f8c3b7f2583a', 'chapter', 'ISA.33', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'NOW SPOILER CEASE PRAYER ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5374da02-8120-194a-259d-c83b9a80045c', 'chapter', 'ISA.34', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'THE SWORD BATH EDOMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('17ecad77-36b2-b9c2-635d-fb6dce4799d5', 'chapter', 'ISA.35', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'HOLINESS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c3617144-097b-1f4b-06b2-fe30fcae4fd8', 'chapter', 'ISA.36', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'RABSHAKEH MOCKS GOD JUDAH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2bdd61d0-c1b6-e1c3-f099-b78bd7152303', 'chapter', 'ISA.37', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'O LORD GOD ISRAEL HEAR SENNACHERIB SLAIN HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ceea2eef-0bc6-edf1-332f-e72eb6912b16', 'chapter', 'ISA.38', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'USE DIAL SUN HEZEKIAH ONES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f16ee4c9-7e4a-0b7e-d1ec-96a5f3cd8b0a', 'chapter', 'ISA.39', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'GLAD SHOW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('820d040d-b0c0-5445-c948-496ec07c3b70', 'chapter', 'ISA.40', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'HE COMFORT PEOPLE VOICE CRY WORD HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('65707477-019a-c38f-cd65-98c281bb5c7d', 'chapter', 'ISA.41', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'THE ISLES SAW FEAR ENDS EARTH ONES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('adf6272a-8fdd-cbcb-2c7c-66bf80518cfa', 'chapter', 'ISA.42', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'HE SHALL NOT CRY BREAK REED HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a201ce48-a9cf-37cd-b3d2-ee0db7fa15f9', 'chapter', 'ISA.43', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'EGYPT RANSOM ETHIOPIA SEBA LOVES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c079c0f6-46ab-8ed2-d477-272c79e1d913', 'chapter', 'ISA.44', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'SERVANT CHOSEN JACOB ISRAEL ONE S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('27d8078d-3bdc-1baf-b2aa-65a8b4272702', 'chapter', 'ISA.45', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'USE CYRUS ORDAINED BUILD CITY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2cdf1749-5d06-5569-da4b-c2db22298a48', 'chapter', 'ISA.46', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'FALL BEL BOWETH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('595852ab-45f1-8664-a916-1a2c413cb39a', 'chapter', 'ISA.47', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'FOR DUST SIT THOU S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fa978beb-373c-f0fa-0728-c67e59f4fa50', 'chapter', 'ISA.48', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'ELECT CHOSEN FURNACE JOY S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a6c8dfe7-5975-32b0-0f2e-8eb74e1ef5b1', 'chapter', 'ISA.49', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'RESTORED ISRAEL GENTILES ZION', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2e92ade0-6730-42fa-c858-f312cc8ebcd9', 'chapter', 'ISA.50', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'I GAVE BACK HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cddc036d-5a57-fc68-549f-c711e4da12f3', 'chapter', 'ISA.51', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'NOW HEARKEN YE FOLLOW ZION S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e0b24ffd-6fa9-a0da-6c2b-13e05b29dad3', 'chapter', 'ISA.52', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'GOOD TIDINGS O HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bc11115a-464a-ec5e-1f2f-fc2a5ae9c6d3', 'chapter', 'ISA.53', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'SORROW GRIEF S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bb3ada85-c6f0-d947-68a8-c87772d23f7e', 'chapter', 'ISA.54', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'ENLARGE TENT SING HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ecf1e501-de8d-1a3f-1fed-f5077a8a2799', 'chapter', 'ISA.55', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'RETURN LORD JOY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ee5606ed-b532-6466-b174-802694534b21', 'chapter', 'ISA.56', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'VOICE PRAYER S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('566c17f5-5880-fb6d-39de-1b2ae592e556', 'chapter', 'ISA.57', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'ALL RIGHTEOUS TAKEN REST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('83defc48-fe62-1b01-b096-628812220b52', 'chapter', 'ISA.58', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'NO FAST CRY ALOUD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('641da8d4-9c8a-d387-021f-ba6922be0c60', 'chapter', 'ISA.59', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'THE REDEEMER COME ZION HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7ec14bed-35bb-f4f5-a434-353ab95e2485', 'chapter', 'ISA.60', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'MULTITUDE CAMELS ZION HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('79c4f868-c8e0-b185-e373-92ed187163d9', 'chapter', 'ISA.61', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'EAT GENTILES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6bb690ea-fa82-0a41-f566-c2e20328751c', 'chapter', 'ISA.62', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'SALVATION ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('35966f22-a093-97d9-0da6-ab8b939b6866', 'chapter', 'ISA.63', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'SAVIOUR ALL ANGUISH HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('31c802f0-dea9-4df0-78bf-9ab9c7ad2fec', 'chapter', 'ISA.64', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'I SAW GOD DO HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('271c7956-a721-d17e-37fc-b485dbeb8e8d', 'chapter', 'ISA.65', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'AMEN NEW HEAVENS EARTH WOLF HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('399aad24-9e16-1da0-1160-9a50985dce75', 'chapter', 'ISA.66', 'e8030fe6-e3c4-15de-0d60-987473246b20', 'HEAR WORD TREMBLE JOY PEACE S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f8d0179a-3050-b441-b758-b86be6d7ca24', 'book', 'JER', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'BOLDLY WARNS OF BABYLON CAPTIVITY BUT FORETELLS NEW COVENANT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cd592fdb-0f1b-5d4c-739c-352ee3cac273', 'chapter', 'JER.1', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'BE NOT AFRAID OF FACE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('36ac20fe-4c26-9f5d-ffef-0bcafb8cac24', 'chapter', 'JER.2', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'OUR FATHERS SINNED FORSAKEN ME LORD ONE HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bb7b5278-e29b-266c-6cdc-7a6077760718', 'chapter', 'JER.3', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'LOOK NOW BACKSLIDING ISRAEL S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f6e4af7b-4cf1-5dfd-ac32-0bd98d31d945', 'chapter', 'JER.4', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'DESTRUCTION LION THICKET COMETH UP S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eb9e59ac-9cec-5178-a23c-78088ad1d03f', 'chapter', 'JER.5', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'LORDS ANGER NOT PARDONED SINS ONE HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('43008716-764f-47df-0e9b-464362ae260d', 'chapter', 'JER.6', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'YOUR SACRIFICES NOT ACCEPTED SWEET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1ab9e82f-acbf-db5a-c818-04292dbe9083', 'chapter', 'JER.7', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'WORSHIP IN TEMPLE DEN ROBBERS STEAL HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9db87ac8-ff7d-67fa-f508-2fb157c2b320', 'chapter', 'JER.8', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'ALL BACKSLIDDEN PEOPLE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9bdb7b36-6bd0-98a4-a0df-160207f9713e', 'chapter', 'JER.9', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'RUN FROM DECEIT WEEPING WAIL HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('64717335-914e-ecd9-e1c5-d03016414a52', 'chapter', 'JER.10', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'NO IDOLS ISRAEL GOD TRUE KING S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9be1e5cd-81a0-b1ef-845c-5e8ae85d7a3d', 'chapter', 'JER.11', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'SACKCLOTH COVENANT BROKEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8a00f46f-dfb9-517f-229e-7b22f536bd08', 'chapter', 'JER.12', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'OUR HERITAGE GIVEN S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ec08cab0-854f-9d00-e422-acbd92e5470f', 'chapter', 'JER.13', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'FORGET THEE JERUSALEM GIRDLE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4bedd2b5-627b-f3f4-73ef-5426319ae80b', 'chapter', 'JER.14', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'BARREN LAND DROUGHT PRAY S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('db5e996e-b392-cd07-8969-bf3ee8c1494d', 'chapter', 'JER.15', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'AM AMAZING GRIEF CAST OUT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fa55360b-4767-6cea-c3e7-1bcb8614a3b6', 'chapter', 'JER.16', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'BURY DEAD NOT LAMENT WIFE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b3783470-ba0a-86e1-c6e6-4652c963470e', 'chapter', 'JER.17', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'YOUR HEART DECEITFUL SIN JUDAH S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cf2c308c-b2d8-6f44-e46c-5a9101f030bd', 'chapter', 'JER.18', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'LOOK POTTER CLAY VESSEL ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('691413e6-2349-15d3-8dfa-8dd3f83a993f', 'chapter', 'JER.19', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'OLD BOTTLE BREAK S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4a2ddbc2-c2d3-2098-cd24-bae5942b5aa8', 'chapter', 'JER.20', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'NIGHT TERROR PASHUR S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('75d828fc-68e5-bf6c-1ec4-23185ae634b1', 'chapter', 'JER.21', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'CITY BURN FIRE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6be941e2-c13a-27cd-4a04-270ebccf1472', 'chapter', 'JER.22', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'A KING SHALL REIGN JUDGMENT JUST HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('daf784ca-059e-d397-d7e7-d80dc0548e91', 'chapter', 'JER.23', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'PASTORS SCATTER SHEEP I WILL GATHER REMNANT HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b8e9d77f-f906-b751-61e0-d33eeb0078f0', 'chapter', 'JER.24', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'THE FIGS GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('18f4ca59-92e3-2d30-e895-bddb8a0336a8', 'chapter', 'JER.25', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'I WILL BRING NEBUCHADREZZAR KING BABYLON ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c464f156-d3cc-e6b5-8cb9-72ef5042de83', 'chapter', 'JER.26', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'VOICE PRIESTS PROPHETS DIE S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c2c4d947-4163-f40c-ef9f-b2fb1cfcba00', 'chapter', 'JER.27', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'I GIVE LANDS TO WHOM PLEASE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f970a4d2-0cbc-ac54-b5c4-5954f6fb9df9', 'chapter', 'JER.28', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'THE YOKE HANANIAH HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0978fc55-c869-130c-d713-be0cf4e9ff4f', 'chapter', 'JER.29', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'YOKE OF BABYLON SEVENTY YEARS RETURN S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2adfd648-e47a-e662-17b8-e20c464e5556', 'chapter', 'JER.30', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'BOOK WRITE WORDS ISRAEL ZION', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('946a9050-8f3c-dccd-e1f9-882fef2efa55', 'chapter', 'JER.31', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'UP AGAIN BUILD THEE VIRGIN ISRAEL NEW COVENANT S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('23ae9663-cfe9-45b6-4276-eb79599fa92d', 'chapter', 'JER.32', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'THE RIGHT OF REDEMPTION BUY FIELD ANATHOTH EVIDENCE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d49086a7-f9d1-4114-c1fa-6dbb3645076c', 'chapter', 'JER.33', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'FOR I WILL CAUSE CAPTIVITY HIMS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2e22f8ca-07bc-c2e9-81ac-9fde0f52760a', 'chapter', 'JER.34', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'O ZEDEKIAH BURN CITY SLAVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0c44b9fb-ed9d-baa4-29e7-2570ed3584ed', 'chapter', 'JER.35', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'RECHABITES DRINK NO HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('482b3721-37be-f2bb-03c6-a74240206494', 'chapter', 'JER.36', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'EVERY WORD ROLL BARUCH WROTE FIRES HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ff0e7486-790f-4dc2-f5de-09fe2eedcb96', 'chapter', 'JER.37', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'THE CHALDEANS DEPART NOT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a117a5b8-a47f-3a6f-81c2-862c301cf06a', 'chapter', 'JER.38', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'EUNUCH TOOK UP JEREMIAH DUNGEON S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e9d3c994-b8e2-0709-292b-db41355d5c34', 'chapter', 'JER.39', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'LO ZEDEKIAH EYES DARK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('589788e6-06dd-858d-38a7-f8e7f75d5471', 'chapter', 'JER.40', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'LOOK CAPTAIN GUARD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('492ca59f-4051-51b3-a143-c68c077191f2', 'chapter', 'JER.41', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'SLAY ISHMAEL MIZPAH S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dfae7366-f8b4-bb26-6e69-a5d6e3f076fa', 'chapter', 'JER.42', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'NOT GO INTO EGYPT REMNANT S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('37cfd1b2-abb1-76df-b117-4c5779c629ea', 'chapter', 'JER.43', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'EGYPT STONES HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f95af492-cb76-3e38-8f4f-7eaca5abe881', 'chapter', 'JER.44', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'WOMEN BURN INCENSE QUEEN HEAVEN HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('16e7e67d-bf4b-eabb-fa04-1a7cfea96bd3', 'chapter', 'JER.45', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'CHEER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1899da6d-d33b-304c-e479-e5935ff96ab1', 'chapter', 'JER.46', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'OVERTHROW PHARAOH NECHO ARMY HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9dee1f73-e884-d313-58a6-93c040fa8d33', 'chapter', 'JER.47', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'VERY SAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d1781392-301a-fe25-6928-63c3376dc4ad', 'chapter', 'JER.48', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'EVERY HEAD BALD MOAB WEEPING CRYING HOWLING DESTROYED S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('53e35029-a15a-ed5c-77ed-ea441c5b1084', 'chapter', 'JER.49', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'NATIONS JUDGED AMMON EDOM DAMASCUS KEDAR ELAM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('01f1716a-a82c-fa47-1b3a-d65b570367ed', 'chapter', 'JER.50', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'AGAINST BABYLON CHALDEANS RECOMPENSE INIQUITY PROUD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9b238937-9ed5-7f0a-4430-b71580a71bcc', 'chapter', 'JER.51', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'NOW DESTROY BABYLON STONE SINK EUPHRATES GOLDEN CUP BREAK WALLS BROAD ONE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d7e75328-3ae6-f447-7e5a-525afccdd31b', 'chapter', 'JER.52', 'f8d0179a-3050-b441-b758-b86be6d7ca24', 'THE TEMPLE BURNT CITY SPOILED CAPTIVE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d4f624ef-2f29-b27c-2607-1ee78ea4d7de', 'book', 'LAM', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'O LORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7997e8f1-b0bd-8b6a-ad3d-a2d31d560489', 'chapter', 'LAM.1', 'd4f624ef-2f29-b27c-2607-1ee78ea4d7de', 'O HOW SITS CITY SOLITARY HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('45a5abfd-15c7-d633-800e-8cefd8d78473', 'chapter', 'LAM.2', 'd4f624ef-2f29-b27c-2607-1ee78ea4d7de', 'LORD SWALLOWED UP ISRAEL S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0fead2a8-8172-d952-4871-46473d14129d', 'chapter', 'LAM.3', 'd4f624ef-2f29-b27c-2607-1ee78ea4d7de', 'O I AM THE MAN SEEN AFFLICTION MERCY NEW EVERY MORNING GREAT THY FAITHFULNESS HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c1f36fa5-3fb3-e6e5-3024-a145cba20c81', 'chapter', 'LAM.4', 'd4f624ef-2f29-b27c-2607-1ee78ea4d7de', 'REMEMBER PRECIOUS ZION HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('39f60890-b6b9-5eca-c145-847bed6ac580', 'chapter', 'LAM.5', 'd4f624ef-2f29-b27c-2607-1ee78ea4d7de', 'DO REMEMBER US O LORD TURN S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4da8de32-5c11-dc95-b796-d0a9104c5559', 'book', 'EZK', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'USES VISIONS OF JUDGMENT, RESTORATION, AND ANOTHER TEMPLE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eab6c6bf-7c4f-adbd-2b56-91f385679318', 'chapter', 'EZK.1', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1be4adcb-7385-c887-9e47-c2c114a102ab', 'chapter', 'EZK.2', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6d56799f-8aa6-1d11-118f-8743570e38ae', 'chapter', 'EZK.3', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('33675512-08f5-1e68-c102-f4a2409ebab2', 'chapter', 'EZK.4', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('aadd86c4-59e6-0378-c719-aab42651891c', 'chapter', 'EZK.5', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cd6482c1-fd2d-c228-f4d9-23ed7efa3eec', 'chapter', 'EZK.6', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ab68956c-34a3-60d8-6cbc-477ca18a0a4a', 'chapter', 'EZK.7', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ea574559-e6e2-136e-ac14-567232921e44', 'chapter', 'EZK.8', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4b728435-d460-9315-d251-a0c9c4616b72', 'chapter', 'EZK.9', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('375a9570-f4f7-5925-a41f-c692d3d55db4', 'chapter', 'EZK.10', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f6333260-a2e8-e5cd-d2cd-720faf587fe9', 'chapter', 'EZK.11', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0c15a210-ccfa-1f17-d6d0-109cd47536ee', 'chapter', 'EZK.12', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f3d5d442-c43c-5445-53b8-23468fe85ca3', 'chapter', 'EZK.13', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('102eda8d-c771-ce60-17c7-0d56dcba75e2', 'chapter', 'EZK.14', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d90528e5-5f58-a3a8-2592-940fc2d4de7a', 'chapter', 'EZK.15', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f97f26eb-1bed-b80e-a4c6-c9af70f284d0', 'chapter', 'EZK.16', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('737c54aa-5736-dca2-2d9a-5a48580f659e', 'chapter', 'EZK.17', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dc9d518e-d539-b47a-914a-1c35869f11d1', 'chapter', 'EZK.18', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('85131e80-939f-97c0-1f57-1ad51d66746a', 'chapter', 'EZK.19', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2c151d05-fb5e-6259-6f41-bee0dce5df42', 'chapter', 'EZK.20', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('538f65bb-9950-23b9-92d2-5ed86f18971d', 'chapter', 'EZK.21', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('481a5c0a-4773-44cd-6241-94b160204e0e', 'chapter', 'EZK.22', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('05c12d28-bb22-2174-02eb-a89fd496bcdc', 'chapter', 'EZK.23', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4bcd4afe-94d6-859e-e356-3c7bb9f1dcaa', 'chapter', 'EZK.24', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('80e3b72d-0615-919a-2702-184b8f535505', 'chapter', 'EZK.25', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('afb2607a-5762-499e-0160-5c765962fe3c', 'chapter', 'EZK.26', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ce2e6453-4b4b-22f6-c905-828fdcf844cb', 'chapter', 'EZK.27', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('32dbdf51-1c08-f2cb-2bbf-7f71460b06bb', 'chapter', 'EZK.28', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f80d53bc-2f52-c8c4-b558-c010f294a335', 'chapter', 'EZK.29', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('943beba0-de12-d5b6-31c4-0151a16d61e6', 'chapter', 'EZK.30', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('10de4605-9a6f-e728-678b-f479417b1413', 'chapter', 'EZK.31', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4accd06a-7434-7f60-1ff9-b73175c4688a', 'chapter', 'EZK.32', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('69a9b5e7-ba64-5160-4ae9-ad10512ed9f1', 'chapter', 'EZK.33', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2b79d17d-6ace-8a21-aa1c-cc1a3f6a298a', 'chapter', 'EZK.34', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('77b7b6c7-f5c2-63e8-badd-6bad4af1ff40', 'chapter', 'EZK.35', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('33066f9a-671a-f6a6-b19c-8fda2f086f85', 'chapter', 'EZK.36', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('007f6d72-e5c9-e8a7-c7be-f71ce87fa4ed', 'chapter', 'EZK.37', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('74d6ca6e-1a3e-3041-757d-cc972e80a29a', 'chapter', 'EZK.38', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ca4301d3-3be2-2d28-f714-b21a5b6929c4', 'chapter', 'EZK.39', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1cb3bafd-ab4a-2ca0-382b-f84bad13134a', 'chapter', 'EZK.40', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e49ad84c-357f-8e39-4651-af25733426c4', 'chapter', 'EZK.41', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c2b4639e-b60b-4906-4a6d-78d2f7d1e635', 'chapter', 'EZK.42', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('978da9e4-948d-9d19-689d-cc892158b564', 'chapter', 'EZK.43', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('efb23d1b-0761-4183-4448-41bab602a669', 'chapter', 'EZK.44', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('07b3d474-08c8-3af7-772f-ad4718756621', 'chapter', 'EZK.45', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bbcd42ee-2b73-1781-d030-a590e1da4efd', 'chapter', 'EZK.46', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ff1e2cc4-7964-3f0d-e216-6902d01a06b4', 'chapter', 'EZK.47', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8edf000c-d3a9-524d-c455-869e1da0f3e6', 'chapter', 'EZK.48', '4da8de32-5c11-dc95-b796-d0a9104c5559', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a240d03c-7c52-41fb-3088-21af5d990acc', 'book', 'DAN', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'TRIBULATIONS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('55c1d7f4-d82e-577f-53db-e1e0f26e5484', 'chapter', 'DAN.1', 'a240d03c-7c52-41fb-3088-21af5d990acc', 'THE PULSE FAIRER FATTER S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c3f5793f-2f17-95cc-50a7-3d9538b5300f', 'chapter', 'DAN.2', 'a240d03c-7c52-41fb-3088-21af5d990acc', 'REVEAL SECRET DREAM IMAGE HEAD GOLD FEET IRON CLAY STONES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f55fb685-c121-503d-ae38-ddd6fda7536b', 'chapter', 'DAN.3', 'a240d03c-7c52-41fb-3088-21af5d990acc', 'IMAGE GOLD FURNACE FOURTH FORM ONES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e44d3e25-460f-62ac-fcc5-afeb162bed5e', 'chapter', 'DAN.4', 'a240d03c-7c52-41fb-3088-21af5d990acc', 'BEHOLD A TREE WATCHER HEW DOWN STUMP WET ONES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('62d6c018-afa5-a981-7d8f-8d74d7f4e7a5', 'chapter', 'DAN.5', 'a240d03c-7c52-41fb-3088-21af5d990acc', 'UPON PLASTER FINGERS OF HAND WROTE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ebd7f48f-b5eb-149c-587f-2893f9552589', 'chapter', 'DAN.6', 'a240d03c-7c52-41fb-3088-21af5d990acc', 'LIONS DEN DARIUS SEALED STONE ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b0c01406-5588-52ea-9390-a3603af7a8f6', 'chapter', 'DAN.7', 'a240d03c-7c52-41fb-3088-21af5d990acc', 'ANCIENT OF DAYS FOUR BEASTS SEAS S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bbef11dc-e20c-ffd7-a49a-ec8781e4508d', 'chapter', 'DAN.8', 'a240d03c-7c52-41fb-3088-21af5d990acc', 'TWO THOUSAND THREE HUNDRED DAYS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f2d8001b-8638-0ccf-20be-f21c0749d7a8', 'chapter', 'DAN.9', 'a240d03c-7c52-41fb-3088-21af5d990acc', 'I PRAY CONFESSION SEVENTY WEEKS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('047d1adf-4d56-9a70-51c9-18ce2eb604b2', 'chapter', 'DAN.10', 'a240d03c-7c52-41fb-3088-21af5d990acc', 'ONE MAN CLOTHED LINEN HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('41f28dee-786c-16a7-de86-0b2f5689cb96', 'chapter', 'DAN.11', 'a240d03c-7c52-41fb-3088-21af5d990acc', 'NORTH KING SOUTH RAISER TAXES VILE PERSON SHIPS ONE HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('734f6f24-5592-4397-3e1d-e1b9842daaac', 'chapter', 'DAN.12', 'a240d03c-7c52-41fb-3088-21af5d990acc', 'SEAL BOOK END HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'book', 'HOS', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'EXAMPLE OF GRACE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3e38e17b-8c9b-7c0a-7859-0b440d4d9aa8', 'chapter', 'HOS.1', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'EPHRAIM SONS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ff12eba3-26bb-6472-a226-ff1536059717', 'chapter', 'HOS.2', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'X HUSBAND WILL ALLURE AMMIS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('41c89ce7-9710-b758-4071-7022041c3b30', 'chapter', 'HOS.3', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'A LOVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('40c8eff7-c763-7bc2-9d7e-d451e7b85367', 'chapter', 'HOS.4', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'MY PEOPLE DESTROYED NO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('212515f2-0844-fa90-cb68-aac4d8d8574f', 'chapter', 'HOS.5', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'PRIESTS HEARKEN O', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e2378eba-0d07-8900-bb1d-159616aab3bf', 'chapter', 'HOS.6', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'LORD RAISE UP', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('20e58c01-93b5-9542-0630-5e3d6ceb5b7b', 'chapter', 'HOS.7', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'EPHRAIM GRAY HAIRS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3bd187fe-4eff-6bdd-ea4c-d15c3479455a', 'chapter', 'HOS.8', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'OF IDOL ISRAEL SO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f67d209c-baa4-5497-2364-968326a28316', 'chapter', 'HOS.9', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'FOR EPHRAIM WANDERS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('be71496f-2d5d-414b-41c3-efe14855d2ac', 'chapter', 'HOS.10', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'GIBEAH SIN CALVES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3988fb76-2065-8eaa-1e42-3ab54c6729e3', 'chapter', 'HOS.11', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'ROAR LION SONS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a88270c6-c0d1-f223-1465-431b36ce9864', 'chapter', 'HOS.12', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'ASSYRIA OIL HOME', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2c46e235-3c5a-9d50-1cf8-dc110235e591', 'chapter', 'HOS.13', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'CALVES KISS SMOKES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d694b105-f533-1832-da8b-6b5896355966', 'chapter', 'HOS.14', '2aa77c27-e4f9-6d9e-fd43-1c5762976e05', 'EAT FRUITS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7e19f8f4-413e-a618-443f-f9732cb018ae', 'book', 'JOL', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'VOW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('75894700-6ca6-3107-6399-f32619a57083', 'chapter', 'JOL.1', '7e19f8f4-413e-a618-443f-f9732cb018ae', 'VINE DRIED UP FIG TREE SO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('92679571-cc3f-22c5-8361-56ad1abdd869', 'chapter', 'JOL.2', '7e19f8f4-413e-a618-443f-f9732cb018ae', 'ON SERVANTS HANDMAIDS POUR SPIRIT UP A', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('876fac9b-1e8b-6cb1-f30f-576823c969b0', 'chapter', 'JOL.3', '7e19f8f4-413e-a618-443f-f9732cb018ae', 'WAKE UP MIGHTY MEN WAR UP A', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1d46c992-f2b3-9cf2-fe8f-d27838c3ed77', 'book', 'AMO', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'EQUAL CARE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('01182ba9-8d1b-039c-589c-a2e284f2c437', 'chapter', 'AMO.1', '1d46c992-f2b3-9cf2-fe8f-d27838c3ed77', 'EDOM FIRE PALACES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dc796644-4b54-426c-279f-588d7a773f49', 'chapter', 'AMO.2', '1d46c992-f2b3-9cf2-fe8f-d27838c3ed77', 'QUIET POOR DUST MAN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eb47f9ba-4519-bc84-382d-06e6cf84b28d', 'chapter', 'AMO.3', '1d46c992-f2b3-9cf2-fe8f-d27838c3ed77', 'USE LIONS ROAR MAN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('765bdcef-a8a7-addf-3d7d-2fab295e11ab', 'chapter', 'AMO.4', '1d46c992-f2b3-9cf2-fe8f-d27838c3ed77', 'AT EASE KINE SON', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7241ef4a-f1aa-d08e-e145-5a31fd0da01e', 'chapter', 'AMO.5', '1d46c992-f2b3-9cf2-fe8f-d27838c3ed77', 'LET JUDGMENT RUN DOWN WATER SOS A', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4abb08e7-2c62-c497-2881-63a71971484f', 'chapter', 'AMO.6', '1d46c992-f2b3-9cf2-fe8f-d27838c3ed77', 'CHIEF NATIONS GO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('27c18d2c-f332-6b1f-490b-10d69e7ae6fa', 'chapter', 'AMO.7', '1d46c992-f2b3-9cf2-fe8f-d27838c3ed77', 'AMOS PLUMBLINE WALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8cd4f5b0-23b3-7990-acf7-8328d6be6c99', 'chapter', 'AMO.8', '1d46c992-f2b3-9cf2-fe8f-d27838c3ed77', 'RUN TO AND FRO MEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('18bb93df-c26b-3b8b-ccac-5dc96d872746', 'chapter', 'AMO.9', '1d46c992-f2b3-9cf2-fe8f-d27838c3ed77', 'ESCAPE CORN WINES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b3596f09-1d20-e5ab-88bd-c22b784b6875', 'book', 'OBA', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('25dff628-28f0-5744-05cf-98c2fca55f72', 'chapter', 'OBA.1', 'b3596f09-1d20-e5ab-88bd-c22b784b6875', 'RETRIBUTION PROPHESIED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6a0216c7-57b5-91ca-0276-c6a542c7dce3', 'book', 'JON', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'YE GO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4d6d329a-1378-2ff5-cbd1-8d78067cbf0f', 'chapter', 'JON.1', '6a0216c7-57b5-91ca-0276-c6a542c7dce3', 'YONAH FLEE TARSHISH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('22ab5071-a659-8d7e-c8dd-5f26085c6261', 'chapter', 'JON.2', '6a0216c7-57b5-91ca-0276-c6a542c7dce3', 'EAT WEEDS NO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5a32a838-84a8-b0d8-aa57-d95638539fcd', 'chapter', 'JON.3', '6a0216c7-57b5-91ca-0276-c6a542c7dce3', 'GOT REPENTS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('65c9ee2f-68d3-d0a5-b5f4-c997bebacae9', 'chapter', 'JON.4', '6a0216c7-57b5-91ca-0276-c6a542c7dce3', 'O GOURD ANGRY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8e48ed5e-98ee-f018-37aa-1a46cc031784', 'book', 'MIC', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'OBEY GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1f5eceb3-7381-309f-a512-3032f2a36e3e', 'chapter', 'MIC.1', '8e48ed5e-98ee-f018-37aa-1a46cc031784', 'O SAMARIA WOUND NOW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b32faafc-b9bb-20d4-2bf6-0580c24a8d5d', 'chapter', 'MIC.2', '8e48ed5e-98ee-f018-37aa-1a46cc031784', 'BEDS COVET LAND', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eb498ce1-917f-53a3-a280-5d37c4900726', 'chapter', 'MIC.3', '8e48ed5e-98ee-f018-37aa-1a46cc031784', 'EAT FLESH MENS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3183b899-7477-6789-7536-bef55fa9428e', 'chapter', 'MIC.4', '8e48ed5e-98ee-f018-37aa-1a46cc031784', 'YE SWORDS PLOWS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('819e0a4b-72e8-4dcf-0421-04ca66b3b6b5', 'chapter', 'MIC.5', '8e48ed5e-98ee-f018-37aa-1a46cc031784', 'GIVE BETHLEHEM GO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fa23dfcd-6885-2753-cdd0-5d6168c9226c', 'chapter', 'MIC.6', '8e48ed5e-98ee-f018-37aa-1a46cc031784', 'ONE MAN DO JUSTLY GO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f307aea7-74af-a136-df54-9ed5ec2c625c', 'chapter', 'MIC.7', '8e48ed5e-98ee-f018-37aa-1a46cc031784', 'DO SIRE PARDON SIN OCEAN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('40921f9d-ac16-969b-9383-e4db25260dfe', 'book', 'NAM', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'WOE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f1f8594c-f86b-ec4f-cbe3-a7ae79dd8e2e', 'chapter', 'NAM.1', '40921f9d-ac16-969b-9383-e4db25260dfe', 'WITH FLOOD END NOW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('74c73876-5786-7a02-0202-9fea719311fd', 'chapter', 'NAM.2', '40921f9d-ac16-969b-9383-e4db25260dfe', 'OPEN GATES LION', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8a3ebab9-ee31-2881-9520-2a37e75f71a9', 'chapter', 'NAM.3', '40921f9d-ac16-969b-9383-e4db25260dfe', 'EAT FIG FORTRESS FIRES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6c27e930-c476-4c10-746d-717fafbb57b7', 'book', 'HAB', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'EAR', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('aecb4d92-e7ef-3192-7dbd-01ed2aa10549', 'chapter', 'HAB.1', '6c27e930-c476-4c10-746d-717fafbb57b7', 'EXECUTE JUDGMENT GO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('afc297e7-9a38-274c-6a53-91a1f47e1684', 'chapter', 'HAB.2', '6c27e930-c476-4c10-746d-717fafbb57b7', 'ALL VISION APPOINTED GO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e273c19a-2e36-9a99-29bc-6780bfda14df', 'chapter', 'HAB.3', '6c27e930-c476-4c10-746d-717fafbb57b7', 'REVIVE THY WORK WRATHS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9b57a3e3-daa1-27ed-35aa-a6c731e4004e', 'book', 'ZEP', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'SIN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('02ac0d4b-e45c-cfe1-0dfc-2173e25c101d', 'chapter', 'ZEP.1', '9b57a3e3-daa1-27ed-35aa-a6c731e4004e', 'SEARCH JERUSALEM MEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3855cbb4-27f2-2379-9479-eb7ae3e345d8', 'chapter', 'ZEP.2', '9b57a3e3-daa1-27ed-35aa-a6c731e4004e', 'I SEEK MEEK JUDGE A', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b439beb1-dd2d-2661-7faf-72fa087acedd', 'chapter', 'ZEP.3', '9b57a3e3-daa1-27ed-35aa-a6c731e4004e', 'NEW SONG ISRAEL GATHERS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ea04347a-5459-198b-4f0b-5b5f795d9e53', 'book', 'HAG', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'SO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('702f999c-5080-8206-566f-bfa7ebb285b0', 'chapter', 'HAG.1', 'ea04347a-5459-198b-4f0b-5b5f795d9e53', 'START REBUILDING', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2d795be0-9f45-a458-3a0e-0ba4abd17a44', 'chapter', 'HAG.2', 'ea04347a-5459-198b-4f0b-5b5f795d9e53', 'OLD GLORY WILL BE SURPASSED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'book', 'ZEC', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'INCOMING CHRIST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0d3c791a-c27e-c20b-3e7f-174bbad13df1', 'chapter', 'ZEC.1', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'I SAW BY NIGHT RED HORSE SO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('385b3f04-90f8-ae80-8c85-387e21d5bd23', 'chapter', 'ZEC.2', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'NO WALLS ZION GO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bd88f1db-a77a-ef89-2c86-3439133eeb42', 'chapter', 'ZEC.3', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'CLEAN MITRE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d7a2ec4b-351d-68f2-46aa-a3130065e0a1', 'chapter', 'ZEC.4', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'OLIVE TREES GOLD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f9f630c7-300f-9289-cc55-d8575d7ca39c', 'chapter', 'ZEC.5', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'M FLYING ROLL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('af4ddea7-514b-5881-8576-b68694987820', 'chapter', 'ZEC.6', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'I SAW CHARIOTS MAN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7259051c-b383-db86-e9f6-5ea68951f59c', 'chapter', 'ZEC.7', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'NO FAST EAT SELFS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('889a76b1-dabd-4df7-e64e-58841be033ed', 'chapter', 'ZEC.8', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'GOOD OLD MEN STREETS JEWS HE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('056af7a5-cb37-10a3-92fc-1f8522514b11', 'chapter', 'ZEC.9', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'COMING ON THE DONKEY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('64463a9f-d689-406a-97f1-bd52a49201b9', 'chapter', 'ZEC.10', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'HE CORNER NAIL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6fd3c39e-4c39-2e57-0fe8-b750b18ff6f7', 'chapter', 'ZEC.11', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'READ BEAUTY BANDS GO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bb610a71-7982-e232-13a5-eb5f2b7404ab', 'chapter', 'ZEC.12', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'I MAKE CUP TWO NOW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('401228ce-90af-32bf-0e42-f402cf0144c6', 'chapter', 'ZEC.13', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'SMITE KINS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('62676373-c7fd-4bab-917d-75d404a5c644', 'chapter', 'ZEC.14', 'af5cd5dd-773b-d7ad-4d86-da9c33c38652', 'THE LORD SHALL BE KING NOW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1a82e571-3fc8-33d9-463e-e710002d2840', 'book', 'MAL', 'fe075fa4-9959-ca4b-be41-06ee0b2ed5e7', 'NEXT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2f796c1f-f2e9-00ac-783b-6a936e88ab85', 'chapter', 'MAL.1', '1a82e571-3fc8-33d9-463e-e710002d2840', 'NO PLEASURE MENS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('78999134-58fa-9778-6d60-b809fff47c8f', 'chapter', 'MAL.2', '1a82e571-3fc8-33d9-463e-e710002d2840', 'EL COVENANT LEVI NOW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f52b3304-99c4-2c20-5313-931795dd07a2', 'chapter', 'MAL.3', '1a82e571-3fc8-33d9-463e-e710002d2840', 'X BOOK REMEMBRANCE GO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a200ff3b-4bb1-7c6f-db42-80f5c05fa499', 'chapter', 'MAL.4', '1a82e571-3fc8-33d9-463e-e710002d2840', 'THE DAY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9b15a833-3540-08ec-643d-0996adda91de', 'book', 'MAT', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'JESUS THE ANOINTED KING OF ISRAEL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('be9eceda-9c0d-a8f9-782c-e8e551638674', 'chapter', 'MAT.1', '9b15a833-3540-08ec-643d-0996adda91de', 'JESUS BORN SON OF MARY, A VIRGIN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('42249ca6-c814-fbb3-bad2-63396f14c074', 'chapter', 'MAT.2', '9b15a833-3540-08ec-643d-0996adda91de', 'EGYPTIAN ESCAPE; WISE KINGS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f1cac38c-6d85-5534-6753-5a319acf358d', 'chapter', 'MAT.3', '9b15a833-3540-08ec-643d-0996adda91de', 'SEE JOHN BAPTIZE HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('42c69144-9ae8-1090-79d2-7c1518cb0263', 'chapter', 'MAT.4', '9b15a833-3540-08ec-643d-0996adda91de', 'UNDERGOES SATAN TESTS HE CALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3276b5a3-8ba1-9c71-7cb3-1ab6189b5ed3', 'chapter', 'MAT.5', '9b15a833-3540-08ec-643d-0996adda91de', 'SERMON ON THE MOUNT BLESSINGS AND TEACHING THE LAWS OF GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a43fc258-6a76-cbe9-1297-a9c4f152bcbf', 'chapter', 'MAT.6', '9b15a833-3540-08ec-643d-0996adda91de', 'ON GIVING PRAYERS AND FASTINGS TEACHING', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6b0fcb01-225c-c338-9549-4c26d0726b75', 'chapter', 'MAT.7', '9b15a833-3540-08ec-643d-0996adda91de', 'HEAR THEN JUDGE NOT OR ASK TO SEE GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9ec76bcf-f245-f86e-14b5-932420a09e63', 'chapter', 'MAT.8', '9b15a833-3540-08ec-643d-0996adda91de', 'EVERY DISEASE HEALED SEA AND DEMONS GONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cbf7b2b7-2fba-a264-f409-f69ec602e23c', 'chapter', 'MAT.9', '9b15a833-3540-08ec-643d-0996adda91de', 'A MATTHEW CALL AND GIRL RAISED GIVE SIGHT SEES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3b2f315f-7934-7bda-7bde-c55556d71f8c', 'chapter', 'MAT.10', '9b15a833-3540-08ec-643d-0996adda91de', 'NAMING TWELVE APOSTLES SENDING TO PREACH THE WORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7aeb04f2-762c-4db4-997b-79351e336882', 'chapter', 'MAT.11', '9b15a833-3540-08ec-643d-0996adda91de', 'OFFER OF REST TO WEARY JOHN ASKS THEM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('844682aa-5b8c-6327-fac3-6b21cc86071d', 'chapter', 'MAT.12', '9b15a833-3540-08ec-643d-0996adda91de', 'THE LORD OF SABBATH JONAH SIGNS AND SPIRIT NOT A HUMAN PERSON', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c45d3c82-2270-2f27-1392-b40aa4d61406', 'chapter', 'MAT.13', '9b15a833-3540-08ec-643d-0996adda91de', 'NUMEROUS PARABLES OF THE KINGDOM LIKE SOWER SEED HIDDEN NETS ARE TOLD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b30e47e5-d769-48d2-91f4-f9ea340c88f0', 'chapter', 'MAT.14', '9b15a833-3540-08ec-643d-0996adda91de', 'THOUSANDS ARE FED PETER WALKS ON THE SEA SON', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6c66335c-93e3-33f7-21a0-1ff308641fdb', 'chapter', 'MAT.15', '9b15a833-3540-08ec-643d-0996adda91de', 'EATING BREAD AND CANAANITE FAITH FED MANY MORE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fc729af5-18b9-3712-325b-330fafae5453', 'chapter', 'MAT.16', '9b15a833-3540-08ec-643d-0996adda91de', 'DECLARES HE IS MESSIAH SUFFER ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2813c63b-22ee-faf2-45a9-4b77c42e8fac', 'chapter', 'MAT.17', '9b15a833-3540-08ec-643d-0996adda91de', 'KNOW TRANSFIGURATION TAX PAIDS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('da11505d-978f-da1d-4059-9fbe5f263d3f', 'chapter', 'MAT.18', '9b15a833-3540-08ec-643d-0996adda91de', 'IF BROTHER SINS FORGIVE HIM FROM THE HEART', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ab7151a6-bcaf-629f-0313-a749cbedec41', 'chapter', 'MAT.19', '9b15a833-3540-08ec-643d-0996adda91de', 'NO DIVORCE RICH RULER ASKS ENTER ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dd36ce8d-0340-e6f3-7a6a-c7001228080c', 'chapter', 'MAT.20', '9b15a833-3540-08ec-643d-0996adda91de', 'GODS VINEYARD WORKERS TWO BLIND EYES SEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ea608cec-b397-10fb-e448-f751a01f677a', 'chapter', 'MAT.21', '9b15a833-3540-08ec-643d-0996adda91de', 'ON A DONKEY RIDES CLEANSES TEMPLE AND FIG TREE WITHERED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d2075a3c-7d80-9920-d2c3-6a7ab311d9b7', 'chapter', 'MAT.22', '9b15a833-3540-08ec-643d-0996adda91de', 'FEAST BANQUET AND TAXES TO CAESAR THE GREATEST COMMAND', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a1d0cf23-a4e7-018b-9ff8-d7f38ca5951a', 'chapter', 'MAT.23', '9b15a833-3540-08ec-643d-0996adda91de', 'I WOE TO SCRIBES AND PHARISEES HYPOCRITES HERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0d2c2be8-9cba-0d76-f3ac-33bdccf35627', 'chapter', 'MAT.24', '9b15a833-3540-08ec-643d-0996adda91de', 'SIGNS OF END TIMES TEMPLE FALL AND DAY UNKNOWN TO ANYONE THERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f08b7a39-79dd-f72b-86aa-d8a7db868bda', 'chapter', 'MAT.25', '9b15a833-3540-08ec-643d-0996adda91de', 'READY VIRGINS AND TALENTS AND SHEEP OR THE GOATS OF LORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7e9c1be6-48d9-cfe8-c6d0-3dce35023712', 'chapter', 'MAT.26', '9b15a833-3540-08ec-643d-0996adda91de', 'ANOINTED AT BETHANY THEN SUPPER THEN PRAYER THEN ARREST TRIAL BEFORE THE HIGH COUNCIL MET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b4485a64-f399-61ad-37fe-852e8581f5f2', 'chapter', 'MAT.27', '9b15a833-3540-08ec-643d-0996adda91de', 'EXECUTED ON CROSS AFTER JUDAS DIES PILATE JUDGES HIM THEN HE IS IN THE TOMB ALONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c06746f1-9eb0-7f9f-114e-09263e5a86d8', 'chapter', 'MAT.28', '9b15a833-3540-08ec-643d-0996adda91de', 'JESUS RISEN FROM DEATHS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'book', 'MRK', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'ESSENTIAL ACCOUNT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('90e58e4b-97ba-d986-a986-75579695c43c', 'chapter', 'MRK.1', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'EVERYONE IS HEALED A LEPER AND MAN WITH DEMON AND SORES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c01ab49a-e86b-4ecc-6c0c-bacce8eb2525', 'chapter', 'MRK.2', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'SINS ARE FORGIVEN PARALYTIC LIFE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5bc42daa-4fd1-af97-d486-9daedcfa4522', 'chapter', 'MRK.3', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'SEE MAN WITH WITHERED HAND HEALED BY MY GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('aacb7daf-2543-2342-e073-def0ff919999', 'chapter', 'MRK.4', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'EXPLAINS SOWER SOILS CALMS A GREAT STORM DEEP SEA', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c8b7eec7-abfe-6a0d-9014-699cf0230996', 'chapter', 'MRK.5', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'NOW DEMONS IN PIGS JAIRUS DAUGHTER IS RAISED UP HIGH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f0d4b218-4c07-4da1-94ca-b97566d367fe', 'chapter', 'MRK.6', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'THOUSANDS FED AND HE WALKS ON WATER HEALS AT GENNESARET AND GALILEE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('76479495-7b4b-cd70-b65c-78f02cb830a4', 'chapter', 'MRK.7', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'IS EATING WITH HANDS UNWASHED A SIN OR AN EVIL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cea52f00-0d25-298f-7cfd-6e49046e16b4', 'chapter', 'MRK.8', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'A FEEDING OF FOUR THOUSAND PETER CONFESS LORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e7281f56-460a-34c1-af41-26fe3cfbb682', 'chapter', 'MRK.9', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'LOOK AT TRANSFIGURATION DISCIPLES ARGUE AS TO WHO GREATEST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e918df64-6f08-2c48-3cc4-a770f2b2ffe7', 'chapter', 'MRK.10', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'A RICH YOUNG RULER ASKS BLIND BARTIMAEUS RECEIVES SIGHT AGAIN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8bb1f856-1f5a-bb94-06ce-13b4b3129085', 'chapter', 'MRK.11', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'COLT RIDDEN AND FIG TREE WITHER AWAY ROT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a60444c0-ba9a-dc00-8ab4-71f5819c4638', 'chapter', 'MRK.12', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'CAESAR TAXES SADDUCEES ASK OF THE RESURRECTION TRUE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ebe2457c-03e5-eddc-21d3-cce0866788f3', 'chapter', 'MRK.13', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'THE TEMPLE STONES NOT ONE LEFT STANDING HERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ac19bc45-795f-374a-f8f3-54cabda795d8', 'chapter', 'MRK.14', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'UNLEAVENED BREAD AND LAST SUPPER GETHSEMANE PRAYER AND A TRIAL OF JESUS CHRIST IS SENT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1c408d3a-0a2a-94b2-5528-22faf3ea248b', 'chapter', 'MRK.15', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'NOW PILATE JUDGES HIM AND HE DIES FOR SINS OF THE WORLD ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fc7c9a51-434e-bd70-8de4-dae1be4822cc', 'chapter', 'MRK.16', '5fcca5d8-5e14-aaa7-ce6b-ba36561a33da', 'THE LORD HAS RISEN ALIVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'book', 'LUK', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'SYSTEMATIC ACCOUNT OF JESUS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('44d4b253-89aa-4957-1b58-18d5d9053552', 'chapter', 'LUK.1', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'SON OF GOD ANNOUNCED TO PRIEST ZECHARIAH AND VIRGIN MARY THEN JOHN AND HOLY JESUS ARE BORN TO THEM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('715c9d8b-29d7-699b-7814-1623eea08f60', 'chapter', 'LUK.2', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'YOUR SAVIOR IS BORN IN BETHLEHEM THEN LATER FOUND IN THE TEMPLE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2dadc8af-d2e8-13aa-ae31-e6d29d9a3829', 'chapter', 'LUK.3', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'SPIRIT OF GOD DESCENDS ON JESUS AT HIS BAPTISM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1b6e62df-94f4-de22-71be-aaadeaf56067', 'chapter', 'LUK.4', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'TEMPTATIONS IN WILDERNESS AND A NAZARETH REJECTION', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7f0bd377-5354-4655-8b93-4b94fcc60f95', 'chapter', 'LUK.5', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'EATING WITH SINNERS AND CALLING THE DISCIPLES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5e46b9f8-cfba-e3f9-6af5-924d2b91f1cd', 'chapter', 'LUK.6', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'MASTER OF THE SABBATH CHOOSES TWELVE AND PREACHES ON PLAIN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4f1f6f46-2f29-d773-70d2-372c2bb3dd8f', 'chapter', 'LUK.7', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'A CENTURION HAS GREAT FAITH AND THE SINFUL WOMAN IS FORGIVEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('28dcbc39-cb9b-f618-659c-6473f4bc85b2', 'chapter', 'LUK.8', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'TEACHING OF THE SOWER THEN CALMING A STORM AND RAISING THE DEAD GIRL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a63b1862-a97d-27ab-c689-54f96d3f0744', 'chapter', 'LUK.9', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'IDENTIFYING THE CHRIST THEN FEEDING FIVE THOUSAND AND A TRANSFIGURATION', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4a9e91b2-9755-6cbd-400f-30b4b0b48636', 'chapter', 'LUK.10', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'COMMISSION OF THE SEVENTY AND THE GOOD SAMARITANS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e5535aad-618e-51bc-ad5e-7a94b9630346', 'chapter', 'LUK.11', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'ASK IN PRAYER AND EXPOSING EVIL SPIRITS AND THE WOES ON PHARISEES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('23fd41c5-d0be-03c9-4b5c-f44e729a5b90', 'chapter', 'LUK.12', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'CONSIDER THE RAVENS THEN DO NOT WORRY BUT ALWAYS WATCH FOR THE SON OF GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('08948299-6f64-d85d-c150-ecb2a14c65da', 'chapter', 'LUK.13', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'CURE OF THE CRIPPLED WOMAN AND NARROW DOOR', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('48fd46f3-dea0-eccc-70ec-110a8a86c8cc', 'chapter', 'LUK.14', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'ONE PARABLE OF A BANQUET AND DISCIPLESHIP', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8f9334dd-1a2f-1d14-353e-f8bfcd985af9', 'chapter', 'LUK.15', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'UNCOVERING THE LOST SHEEP COIN AND SON', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6a75a023-6a62-fcef-0f5f-fdc51cbf17cd', 'chapter', 'LUK.16', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'NO MASTER BUT GOD AND RICH MAN LAZARUS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cd4099c8-038f-33d3-cba7-6dcf4b974236', 'chapter', 'LUK.17', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'TEN LEPERS ARE CLEANSED AND A KINGDOM COMING', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ab13ed6c-eef9-458e-7599-2d04f454e737', 'chapter', 'LUK.18', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'OFFERING PRAYERS THEN THE RICH RULER AND A BLIND ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('84c61c69-ef00-c5cb-ce7f-57edc02f38b0', 'chapter', 'LUK.19', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'FINDING ZACCHAEUS THEN THE PARABLE OF MINAS AND THE ENTRY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('194ad95d-65cf-2eee-4d06-3ed928183579', 'chapter', 'LUK.20', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'JESUS HAS AUTHORITY AND PARABLE OF THE TENANTS AND TAXES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('52b2daff-48ab-dfa6-f894-a6e40fad018e', 'chapter', 'LUK.21', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'END TIMES SIGNS AND THE DESTRUCTION FORETOLD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a729d4d0-ed97-9a69-f1db-ca790571364b', 'chapter', 'LUK.22', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'SATAN ENTERS JUDAS THEN THE LAST SUPPER THEN AGONY IN THE GARDEN AND ARREST AND DENIAL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('60fbe287-5fc9-8176-d801-44c096575f86', 'chapter', 'LUK.23', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'UNJUST TRIAL BEFORE PILATE THEN CRUCIFIXION AND A DEATH AND BURIAL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('10e795cd-3a4c-9373-91ff-b1749477d779', 'chapter', 'LUK.24', '5f5ac268-9864-4498-8aa6-887b6ccdcfcf', 'STUNNING RESURRECTION AND ON THE EMMAUS ROAD AND THE ASCENSION', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('765bd535-49b0-a431-237d-83ff458e288f', 'book', 'JHN', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'UNIQUE GOSPEL ABOUT LOVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('684eb6fb-a70c-e595-e809-474c5852e795', 'chapter', 'JHN.1', '765bd535-49b0-a431-237d-83ff458e288f', 'UNDERSTAND THE WORD BECAME FLESH JOHN BAPTIZES CHRIST JESUS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4e789265-bad9-ec62-6301-2b377d11f690', 'chapter', 'JHN.2', '765bd535-49b0-a431-237d-83ff458e288f', 'NEW WINE IS MADE AND TEMPLE RID', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b567d950-1994-5129-4537-580eeef01a33', 'chapter', 'JHN.3', '765bd535-49b0-a431-237d-83ff458e288f', 'ISRAEL TEACHER HEARS YOU MUST BE BORN AGAIN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('664cf7b5-4260-c645-069e-14d365668044', 'chapter', 'JHN.4', '765bd535-49b0-a431-237d-83ff458e288f', 'QUESTIONS OF SAMARITAN WOMAN AT WELL AND AN OFFICIALS SON HEALED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5507bb9d-57f9-65bd-d3cc-3569d4845164', 'chapter', 'JHN.5', '765bd535-49b0-a431-237d-83ff458e288f', 'UNDER POOL PORCHES MAN HEALED HEAR THE SON AND AUTHORITY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ca8617ac-485c-90ee-ad36-fd9e85dcb833', 'chapter', 'JHN.6', '765bd535-49b0-a431-237d-83ff458e288f', 'EAT PROMISED BREAD OF LIFE AFTER FIVE THOUSAND FED AND JESUS WALKING ON WATER TO LEAVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('edf81e39-b836-71f8-a02b-c6e874fe58ee', 'chapter', 'JHN.7', '765bd535-49b0-a431-237d-83ff458e288f', 'GO TO FEAST OF BOOTHS DRINK LIVING WATER AND A GUARD IS SENT TO MEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f3380fbf-2a49-f9f5-e5d1-ffd674b36b20', 'chapter', 'JHN.8', '765bd535-49b0-a431-237d-83ff458e288f', 'OF ADULTEROUS WOMAN AND THE LIGHT OF THE WORLD AND TRUTH BEFORE ABRAHAM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a516df65-5173-077d-f89c-1cb2afb5cebe', 'chapter', 'JHN.9', '765bd535-49b0-a431-237d-83ff458e288f', 'SEE A BLIND MAN HEALED PHARISEES ARE BLIND INDEED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0f632fe6-476d-4a15-32dc-9b371849765e', 'chapter', 'JHN.10', '765bd535-49b0-a431-237d-83ff458e288f', 'PASTOR IS THE GOOD SHEPHERD IS ONE WITH A FATHER GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('20ccdadc-52ed-3ee6-caa5-2b21a0a46e67', 'chapter', 'JHN.11', '765bd535-49b0-a431-237d-83ff458e288f', 'EVERYONE WEEPS LAZARUS IS RAISED AND HIGH PRIESTS PLOT TO KILL JESUS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4b9fb92b-240f-4e21-655e-c10b73d80d50', 'chapter', 'JHN.12', '765bd535-49b0-a431-237d-83ff458e288f', 'LOOK AT MARY ANOINTING AND KINGS ENTRY GREEKS SEEK A LORD GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('60203ddc-a11a-a59c-9cd6-6095e93a9f9f', 'chapter', 'JHN.13', '765bd535-49b0-a431-237d-83ff458e288f', 'A FOOT WASHING AND TRAITORS AND NEW COMMANDER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('db679d03-3382-76b8-aa8a-56e738059468', 'chapter', 'JHN.14', '765bd535-49b0-a431-237d-83ff458e288f', 'BELIEVE WAY TRUTH LIFE SPIRIT COMING', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ba02260a-f4e9-7493-1fc6-909fd4f20b2a', 'chapter', 'JHN.15', '765bd535-49b0-a431-237d-83ff458e288f', 'OF VINE AND BRANCHES WORLD HATES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e0123be5-3996-df1a-3d64-3449eb4fe030', 'chapter', 'JHN.16', '765bd535-49b0-a431-237d-83ff458e288f', 'UNDERSTAND SPIRIT WORK OUR JOY COME ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('69761bc2-26e3-3ebc-4bed-541e8b363da9', 'chapter', 'JHN.17', '765bd535-49b0-a431-237d-83ff458e288f', 'THE HIGH PRIESTLY PRAYER ASKED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('82daf2f6-8b44-1e3f-622d-8c558ae7ddfd', 'chapter', 'JHN.18', '765bd535-49b0-a431-237d-83ff458e288f', 'LOOK AT ARREST IN GARDEN PETER DENIES LORD JESUS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c99228d4-171f-533b-5f72-e09dcd412f47', 'chapter', 'JHN.19', '765bd535-49b0-a431-237d-83ff458e288f', 'OF BEATING AND CRUCIFIXION DEATH AND THE TOMB SITE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9e60bbb8-b3f8-7f50-11dd-51f4c04de19f', 'chapter', 'JHN.20', '765bd535-49b0-a431-237d-83ff458e288f', 'VACANT TOMB AND MARY THOMAS SEES LORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('27e59328-3033-2fa2-3ec1-83a535930190', 'chapter', 'JHN.21', '765bd535-49b0-a431-237d-83ff458e288f', 'EATING BY SEA PETER LOVES LORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ca3ca70c-7b58-2926-a452-8df312ea984b', 'book', 'ACT', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'SPIRIT BORN CHURCH BEARS WITNESS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9a614453-4655-1038-7fcc-bccf778236a4', 'chapter', 'ACT.1', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'SON ASCENDS; NEW DISCIPLE NAMED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7e477357-f8dc-cd0f-0bab-ed5f48f34d2d', 'verse', 'ACT.1.1', '9a614453-4655-1038-7fcc-bccf778236a4', 'Stated former book about Jesus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9520cf67-3233-beb3-65ad-a0414a0b72b7', 'verse', 'ACT.1.2', '9a614453-4655-1038-7fcc-bccf778236a4', 'Orders given to apostles', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5c7e45a2-5fd7-8faa-eb24-6f691d888351', 'verse', 'ACT.1.3', '9a614453-4655-1038-7fcc-bccf778236a4', 'New proofs of resurrection life', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('12fb962d-9cd8-832f-96ea-d0657d041db7', 'verse', 'ACT.1.4', '9a614453-4655-1038-7fcc-bccf778236a4', 'Await the Father''s promise', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5876782b-cc95-99e2-876b-b6f6bb0ecde5', 'verse', 'ACT.1.5', '9a614453-4655-1038-7fcc-bccf778236a4', 'Spirit baptism coming soon', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5db8bf63-2571-6654-c7c5-c2e3dfe562e9', 'verse', 'ACT.1.6', '9a614453-4655-1038-7fcc-bccf778236a4', 'Christ''s kingdom question asked', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c519983c-315d-24c6-6f2f-f7ee125fb49d', 'verse', 'ACT.1.7', '9a614453-4655-1038-7fcc-bccf778236a4', 'Exact times known only by Father', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('54d21337-f9b7-faa4-d10e-29f7e7380213', 'verse', 'ACT.1.8', '9a614453-4655-1038-7fcc-bccf778236a4', 'Nations to witness power', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ba74df02-7ee0-899b-5b7c-9faee1985708', 'verse', 'ACT.1.9', '9a614453-4655-1038-7fcc-bccf778236a4', 'Disciples watch Him ascend', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f5e58dca-d58b-61b0-c488-887d971733ba', 'verse', 'ACT.1.10', '9a614453-4655-1038-7fcc-bccf778236a4', 'Sky gazers warned by angels', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('93764dcc-93c7-725a-72e8-398574dd4c52', 'verse', 'ACT.1.11', '9a614453-4655-1038-7fcc-bccf778236a4', 'Next He returns same way', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2b142d30-93f8-42e9-a726-ca99f59e964c', 'verse', 'ACT.1.12', '9a614453-4655-1038-7fcc-bccf778236a4', 'Entered Jerusalem from Olivet', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8064b5c9-b385-d0d3-42cd-aa97682103ae', 'verse', 'ACT.1.13', '9a614453-4655-1038-7fcc-bccf778236a4', 'Waiting in upper room', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a149e421-cc3b-d54f-4ec8-c045d5978bad', 'verse', 'ACT.1.14', '9a614453-4655-1038-7fcc-bccf778236a4', 'Devoted in prayer with women', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('01c8db8a-4326-8b26-1fdf-ff278ecaa6c4', 'verse', 'ACT.1.15', '9a614453-4655-1038-7fcc-bccf778236a4', 'In those days Peter stood', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5e4139dc-e6de-92a7-6094-3d311f949066', 'verse', 'ACT.1.16', '9a614453-4655-1038-7fcc-bccf778236a4', 'Scripture fulfilled concerning Judas', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('24c12f32-1bb4-3087-f2b7-c2f6c2af50e8', 'verse', 'ACT.1.17', '9a614453-4655-1038-7fcc-bccf778236a4', 'Counted among us in ministry', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ab36b421-3512-82f1-9952-cc541759d93c', 'verse', 'ACT.1.18', '9a614453-4655-1038-7fcc-bccf778236a4', 'Iniquity''s wage bought field', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4fbd3a96-d416-e1f1-8ea3-ca067b642f88', 'verse', 'ACT.1.19', '9a614453-4655-1038-7fcc-bccf778236a4', 'Place called Akeldama known', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('21ee7dfb-0d5f-0b20-5664-662ce01b46af', 'verse', 'ACT.1.20', '9a614453-4655-1038-7fcc-bccf778236a4', 'Let habitation be desolate', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('de2a8213-c438-998a-4f30-d53fc686af97', 'verse', 'ACT.1.21', '9a614453-4655-1038-7fcc-bccf778236a4', 'Experienced disciple required', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c0236265-03ea-df48-0386-81c12be5f043', 'verse', 'ACT.1.22', '9a614453-4655-1038-7fcc-bccf778236a4', 'Named as witness of resurrection', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a5f43909-7c47-41f8-a6f4-be9d98ddc4dc', 'verse', 'ACT.1.23', '9a614453-4655-1038-7fcc-bccf778236a4', 'Appointed two candidates', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8887527a-de07-0401-8ed4-9388dff8e1af', 'verse', 'ACT.1.24', '9a614453-4655-1038-7fcc-bccf778236a4', 'Master chosen revealed by prayer', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b8d9b2f8-ce82-6f13-b9cf-81bd602d7782', 'verse', 'ACT.1.25', '9a614453-4655-1038-7fcc-bccf778236a4', 'Enforce apostolic ministry', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eb2e9d3f-c528-3099-3e13-6d27f4aa34e3', 'verse', 'ACT.1.26', '9a614453-4655-1038-7fcc-bccf778236a4', 'Dice/Lots cast for Matthias', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6a33a579-80a5-3e4f-cba6-5235803af110', 'chapter', 'ACT.2', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'PENTECOST TONGUES FALL AS PETER PREACHES CHRIST AS LORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('54e32534-a0cb-7720-e977-619b757bba55', 'verse', 'ACT.2.1', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Pentecost day arrived', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cb001e10-e90f-7272-46eb-4abe87fcc085', 'verse', 'ACT.2.2', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Entire house filled with sound', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('053f970c-4e64-ab74-7163-0807ae81ce61', 'verse', 'ACT.2.3', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Noises of wind and fire', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ce5f0e41-7b91-02de-e5aa-efbc0e7fbaed', 'verse', 'ACT.2.4', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Tongues of Spirit utterance', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e24c89ed-ee74-f843-c0f5-25a6e35f2aaa', 'verse', 'ACT.2.5', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Each nation represented there', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7ac65a37-a4a0-69ec-aacd-8c7dddbcace3', 'verse', 'ACT.2.6', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Crowd heard own languages', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c8dbf761-b425-5cb8-12cc-6f364305507d', 'verse', 'ACT.2.7', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Observers were amazed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0de27209-650f-0000-f1f1-fc9f066855a6', 'verse', 'ACT.2.8', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Some asked how this is', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4900d91a-09a7-f443-b96c-d9e307c4a7b3', 'verse', 'ACT.2.9', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Tribes from everywhere hear', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d6692ed3-e69f-4213-6d96-0c72c7a36f50', 'verse', 'ACT.2.10', '6a33a579-80a5-3e4f-cba6-5235803af110', 'They hear God''s works', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('77095208-521a-a5ae-3926-8461886a3e95', 'verse', 'ACT.2.11', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Others mocked new wine', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b7a8976a-e671-2806-e12c-3698df6168d8', 'verse', 'ACT.2.12', '6a33a579-80a5-3e4f-cba6-5235803af110', 'No, Peter stands to speak', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('60620b85-102c-f3a9-f5ea-c49ce180a628', 'verse', 'ACT.2.13', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Give ear to my words', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c112f076-8b81-5b13-18de-2cf649b4544b', 'verse', 'ACT.2.14', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Understood not to be drunk', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('063e3d82-bdfe-8d94-3655-cb59e57a55f9', 'verse', 'ACT.2.15', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Explained by prophet Joel', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f2d74994-5f57-074a-d82e-0a29f578bd81', 'verse', 'ACT.2.16', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Spirit poured on all flesh', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('231fdecb-f126-eb95-f22c-370310701a6e', 'verse', 'ACT.2.17', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Flesh will prophesy', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dec193b3-4bab-98e5-0311-81930f6df7f0', 'verse', 'ACT.2.18', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Also on servants poured', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eb73e603-62cf-af25-b223-f6d2784dae42', 'verse', 'ACT.2.19', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Lord''s signs in heaven/earth', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('37fce502-858f-c6c6-88da-1d28055f4581', 'verse', 'ACT.2.20', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Lord''s day coming soon', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('21081aee-3282-a4ea-b8ed-861794fe1b54', 'verse', 'ACT.2.21', '6a33a579-80a5-3e4f-cba6-5235803af110', 'All calling on Lord saved', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4cb3c866-b5b9-c025-3ddb-f0927991b2da', 'verse', 'ACT.2.22', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Signs attested Jesus to you', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('20fd5090-7016-b561-cda6-01c2069bbc14', 'verse', 'ACT.2.23', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Plan of God delivered Him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a31f40d2-64ab-93ba-32d7-ec13cd4f17b0', 'verse', 'ACT.2.24', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Ended death''s agony', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('82facb35-b841-9173-833d-c3ca29705d67', 'verse', 'ACT.2.25', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Tongue rejoices (David saw)', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d2cfe0ce-32d9-a396-a910-e775c1e2fd2b', 'verse', 'ACT.2.26', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Exalted One saw no decay', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2111f362-e6d8-22d8-a6f1-bbb660ea7724', 'verse', 'ACT.2.27', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Resurrection spoken by David', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('292706ce-cc19-e0ef-e5e2-4dedd5ff0b50', 'verse', 'ACT.2.28', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Peter interprets the psalm', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6c1cca6f-c685-45c0-ff95-47f9091ade04', 'verse', 'ACT.2.29', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Remains of David in tomb', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e69fd537-f3ff-cdce-9f81-d7a4601de783', 'verse', 'ACT.2.30', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Enthroned descendant promised', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4ec04255-915e-5b71-ec92-2e1b3e907acd', 'verse', 'ACT.2.31', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Anticipated Christ''s rising', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('51eaa69f-2cbd-b834-8edf-ba9f0eef9c68', 'verse', 'ACT.2.32', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Christ raised; we witnessed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3cbc7ffc-a3ef-9315-61e4-3314262a9d6e', 'verse', 'ACT.2.33', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Holy Spirit poured out now', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('74b54a26-e660-fc75-30dd-ca477ba90d1b', 'verse', 'ACT.2.34', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Exalted Lord at right hand', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8513fd5a-6be4-3b62-4583-47181ce9b7ca', 'verse', 'ACT.2.35', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Sit until enemies footstool', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('29332827-bdb0-06ac-7356-5f331ecc58e1', 'verse', 'ACT.2.36', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Crucified Jesus is Lord', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b590e46f-fa22-24e8-e12a-3a0478cce3e1', 'verse', 'ACT.2.37', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Hearts cut; what do we do?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ff80b056-9801-b453-ea42-60735c6380fb', 'verse', 'ACT.2.38', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Repent and be baptized all', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('887f2bfd-eef7-873a-158c-3701dc0346c3', 'verse', 'ACT.2.39', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Inherit promise for children', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dceeb782-c810-f13e-13d2-74924f28ce9b', 'verse', 'ACT.2.40', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Save yourselves from generation', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8ce5e6b7-dcfb-6c3b-aa64-9e5e2e4ba150', 'verse', 'ACT.2.41', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Three thousand accepted word', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('92be4c32-394c-6b03-5953-9fd5181eb427', 'verse', 'ACT.2.42', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Apostles'' teaching devoted', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3980ebba-b5e8-8039-1ba3-a0d6e499eee8', 'verse', 'ACT.2.43', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Signs and wonders done', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1b2a6ba0-39cc-4241-62a7-7bd5f6e08dfb', 'verse', 'ACT.2.44', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Life shared in common', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d4f07075-b62c-37ee-4127-4e4acd5564ce', 'verse', 'ACT.2.45', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Offerings given to needy', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e5218a23-9128-ea69-c40c-3b7fb2323a9a', 'verse', 'ACT.2.46', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Rallied daily in temple', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1f2764fe-777b-8e34-361d-98057cfe693a', 'verse', 'ACT.2.47', '6a33a579-80a5-3e4f-cba6-5235803af110', 'Daily Lord added saved', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1edfed2b-ff51-9857-ea5d-b02af88f8295', 'chapter', 'ACT.3', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'INVALID HEALED; PETER PREACHES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('737a81bd-a375-e307-40b1-3eed8898f310', 'verse', 'ACT.3.1', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Into temple Peter/John go', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('50b825cf-8d0d-dfa4-c80d-8b4a49ceea8d', 'verse', 'ACT.3.2', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Needy lame man carried', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('813984f3-dd9a-a389-89b4-78ff837310ef', 'verse', 'ACT.3.3', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Veteran beggar asks alms', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5dae3354-1c18-b9d5-829c-3680ad5eed5b', 'verse', 'ACT.3.4', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Apostles look at him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0ea50d31-39f7-44a0-d572-05d6a2235766', 'verse', 'ACT.3.5', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Lame man expects gift', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c769c4e3-d71d-48ba-4431-f78d90db3b0f', 'verse', 'ACT.3.6', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'In Jesus name walk', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7e225d52-f348-49f1-94ec-c1366776f3cb', 'verse', 'ACT.3.7', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Disabled feet made strong', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0eef84a8-2ae3-3955-3f4d-a5ea5815839e', 'verse', 'ACT.3.8', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'He leaps and praises', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d71806a3-faf1-4a9d-4e61-8683950a7fd0', 'verse', 'ACT.3.9', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Everyone sees him walking', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('61040c5a-1fa8-72a5-3d67-25c53abac734', 'verse', 'ACT.3.10', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Awerstruck people recognize him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b256d9cf-72dd-a2c6-30f3-381279fbdbcc', 'verse', 'ACT.3.11', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Links to Peter/John porch', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f3f64b7d-0bc7-f55c-cda3-c48f193885d2', 'verse', 'ACT.3.12', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Explanation: Why marvel at us?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5f968628-7938-4736-c124-a6307aa37f85', 'verse', 'ACT.3.13', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Delivered Jesus glorified', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('07615913-fc9f-6fe3-1959-c4c86a4ff749', 'verse', 'ACT.3.14', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'People denied Holy One', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('297b257f-4b29-8fda-4785-72dd07479937', 'verse', 'ACT.3.15', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Executed Author of life', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('68506ed9-cb6c-5517-8ece-2aace1481e87', 'verse', 'ACT.3.16', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Through faith name heals', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b269f2bc-f8ca-130d-184f-b285a316ef91', 'verse', 'ACT.3.17', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Errors done in ignorance', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('19247058-b814-33e7-bafe-3b1e41eeff48', 'verse', 'ACT.3.18', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Required suffering fulfilled', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('188f1ee9-0655-0e61-ef8f-3e0aa479e891', 'verse', 'ACT.3.19', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Penitent hearts turn back', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9a189443-675d-b821-4a4f-f6f8f6f69b8c', 'verse', 'ACT.3.20', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Refreshing times from Lord', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5ace1002-39d6-94c1-6f2b-98c3adbaff93', 'verse', 'ACT.3.21', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Earth restores all things', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8202e9a3-1681-1301-1510-f98c7fc87065', 'verse', 'ACT.3.22', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'All heed Moses'' prophet', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d73779b7-8e8f-aa84-6089-5f582a3c57d1', 'verse', 'ACT.3.23', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Cut off if not hear', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('53c6158e-7fcf-7e55-00d3-e0dd073d51b5', 'verse', 'ACT.3.24', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Hebrew prophets foretold', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('34bb4069-07b6-02e3-a0d5-7404f0d1d99e', 'verse', 'ACT.3.25', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'Earth''s families blessed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('609a7ffc-4c7e-22cc-3f87-a861672d5f05', 'verse', 'ACT.3.26', '1edfed2b-ff51-9857-ea5d-b02af88f8295', 'SENT Servant to bless you', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'chapter', 'ACT.4', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'RESURRECTION TALK SPARKS TRIAL; SHARING ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4f46d867-26d5-53bd-6a3e-81e786a8da27', 'verse', 'ACT.4.1', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Religious leaders came', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('453a3288-9be1-7f8a-94a9-f56618713620', 'verse', 'ACT.4.2', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Exasperated by teaching', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('abc9c678-1657-dbf6-2733-dcd88329524a', 'verse', 'ACT.4.3', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Seized them until morning', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('38f876a4-b132-4a23-98b9-a8882f8365d9', 'verse', 'ACT.4.4', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Uncounted thousands believed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ae74a0a8-a56b-f5d2-06e3-5e7df137e33b', 'verse', 'ACT.4.5', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Rulers met next day', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('99d6e930-b3fd-b69f-4d6d-92fb8af94052', 'verse', 'ACT.4.6', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Relatives of high priest', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('aebd1c13-e313-a1f5-090c-c0be393912b3', 'verse', 'ACT.4.7', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Examine: By what power?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7dd36622-f4b5-6967-3726-e340299864dd', 'verse', 'ACT.4.8', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Courageous Peter answers', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b73b5250-2841-3ccf-7659-c88835a01788', 'verse', 'ACT.4.9', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Trial for good deed?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ea7b7f4b-7326-a551-4d40-7850660bd5a8', 'verse', 'ACT.4.10', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'In Jesus name he stands', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('db29dac3-2237-ba21-b751-aa5b21a63ec0', 'verse', 'ACT.4.11', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Old stone builders rejected', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ef0e2948-3093-ea91-1a8f-66e7abcc569c', 'verse', 'ACT.4.12', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'No other name saves', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cb44200d-9170-e146-d9bd-8267db6e6abe', 'verse', 'ACT.4.13', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'They marvel at boldness', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bb3e0ce5-2354-180c-24fd-8a590bee5c2a', 'verse', 'ACT.4.14', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Astonished seeing healed man', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a5c320cb-4543-9747-e591-67294926bbd2', 'verse', 'ACT.4.15', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Leaders confer privately', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('090d02f9-0da4-a497-35cb-e240c8f2c1ea', 'verse', 'ACT.4.16', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Keep miracle secret?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8e11e8be-932e-357a-7762-b0f216be146d', 'verse', 'ACT.4.17', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Stop the name spreading', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('60fad4fb-6706-fa43-77fc-92791391a196', 'verse', 'ACT.4.18', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Prohibit speaking Jesus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8865c8d8-a409-58b9-630f-07fb84a2558a', 'verse', 'ACT.4.19', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Apostles judge God right', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b5a9a604-95f5-7b9f-9863-18a66359925b', 'verse', 'ACT.4.20', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Report what we saw', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8fe219d5-15a7-5bd8-6329-bf4c4caa794b', 'verse', 'ACT.4.21', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Keep threatening then release', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b0c427d1-0c43-ee7d-06a6-456e35714cd7', 'verse', 'ACT.4.22', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Sign on man forty years', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6e5ff47d-d2d8-2a4c-e863-cc59d4585092', 'verse', 'ACT.4.23', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Told friends what happened', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('196d5776-1c8d-5a54-7555-4b77e04417d9', 'verse', 'ACT.4.24', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Raised voices to Creator', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('da8aa458-919e-666a-e53b-38a4a4d3ccff', 'verse', 'ACT.4.25', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Inspired David spoke', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('362db433-3111-4d8b-c40c-881a3500d262', 'verse', 'ACT.4.26', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Against Lord and Anointed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1de41306-843c-0bca-689a-02e6bbf27f23', 'verse', 'ACT.4.27', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Leaders gathered against Jesus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9dbc37e1-8e4a-6f8a-a92e-914e635d0152', 'verse', 'ACT.4.28', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Sovereign will done', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f54d04f9-e1c4-2ddb-7cef-05ee6f665af6', 'verse', 'ACT.4.29', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Hear threats, give boldness', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ef51912f-21c7-ed91-0e22-71d9cf8fa8a4', 'verse', 'ACT.4.30', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Allow signs and wonders', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('450f8a59-3ba5-330c-4158-eec69fc7c677', 'verse', 'ACT.4.31', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Room shook, Spirit filled', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8110011c-511b-b260-670f-2c7c16a99137', 'verse', 'ACT.4.32', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'In one heart shared', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('406f9d42-6007-5328-435e-49402fd79f5d', 'verse', 'ACT.4.33', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'New power testified', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('91e076a6-1457-ce1b-6106-fe441a82b69a', 'verse', 'ACT.4.34', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Gifts removed need', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6afe24e7-e392-0228-7772-6fc4edcbc34e', 'verse', 'ACT.4.35', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Apostles distributed funds', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6df72423-f7d6-39e5-74f1-84c93d622f5b', 'verse', 'ACT.4.36', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Levite Barnabas encouraged', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a49896bb-0426-06bb-7a69-ce63fa872956', 'verse', 'ACT.4.37', 'cf63c225-fd13-6f25-d5ba-b0b88ccc9b53', 'Land sold, money brought', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d7d47157-3111-3471-47d0-ad59424466dd', 'chapter', 'ACT.5', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'INSTANT DEATH FOR LIARS; APOSTLES FLOGGED, REJOICE!', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('97a5a338-3846-a0b4-e20c-76a633fbe72a', 'verse', 'ACT.5.1', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Inwardly deceitful Ananias', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e44a513f-b771-195b-716c-613db4fc60a7', 'verse', 'ACT.5.2', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Not all price kept', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('05334a1a-4221-be43-466c-98f2685fc533', 'verse', 'ACT.5.3', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Satan filled heart', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('13a1f8bf-439e-d76e-7c92-70198efc56cf', 'verse', 'ACT.5.4', 'd7d47157-3111-3471-47d0-ad59424466dd', 'To God you lied', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('88bd8524-fb81-1d4f-e18d-80a82e68da40', 'verse', 'ACT.5.5', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Ananias fell down dead', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ecc0a0f9-c95c-dd46-61cb-e5da9220d404', 'verse', 'ACT.5.6', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Now young men buried', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4153ec7e-6cea-784d-ec7a-ccc8d8dd0775', 'verse', 'ACT.5.7', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Three hours later wife', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4179fd83-0ad5-e98f-329f-ce41f9805c79', 'verse', 'ACT.5.8', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Did you sell for this?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8c068741-c272-65b7-6737-40efc66881dd', 'verse', 'ACT.5.9', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Exposed conspiracy against Spirit', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('33fb6027-de5c-c298-7e6f-7fb547b5d490', 'verse', 'ACT.5.10', 'd7d47157-3111-3471-47d0-ad59424466dd', 'At once she died', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1c276577-980a-e647-df67-ca1fdff4fcde', 'verse', 'ACT.5.11', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Terror on whole church', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1b3b4e15-e24b-8f87-a162-f726fd4b45a3', 'verse', 'ACT.5.12', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Hands of apostles healed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4b59c75e-6536-9a16-2390-4e5bc791fea9', 'verse', 'ACT.5.13', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Fearing, none joined loosely', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('17c014e8-d769-987a-2772-48a6cd01fe0b', 'verse', 'ACT.5.14', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Ongoing multitudes added', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9e651541-b800-c05b-c821-e94bafc5ea73', 'verse', 'ACT.5.15', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Roads had sick on beds', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d5ed242f-68ed-82ee-8ec5-f42305527b1d', 'verse', 'ACT.5.16', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Local towns brought sick', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3f17695d-d267-8e5a-9942-0353d97ef714', 'verse', 'ACT.5.17', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Incensed Sadducees rose up', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('86c9594f-e611-ae97-4ca4-c1ff59f5506f', 'verse', 'ACT.5.18', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Apostles put in prison', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c2ccd69d-d102-64e5-b744-8d1709bb760b', 'verse', 'ACT.5.19', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Released by angel night', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('df7e8bde-022a-0097-5c78-af03b217b811', 'verse', 'ACT.5.20', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Stand speak life words', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('00a01806-5925-7592-4ccd-8c6d20f41be5', 'verse', 'ACT.5.21', 'd7d47157-3111-3471-47d0-ad59424466dd', 'At dawn taught in temple', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bbb1b577-b2ec-0cb4-6343-9a1ae3e72521', 'verse', 'ACT.5.22', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Prison found empty', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('283e0c99-a824-48a9-4e40-2049222d8298', 'verse', 'ACT.5.23', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Officers saw locked doors', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('49612886-ad73-4f5a-207e-30cec7fb8be1', 'verse', 'ACT.5.24', 'd7d47157-3111-3471-47d0-ad59424466dd', 'S puzzled where they were', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bba42935-27b2-4df6-a5ef-9a86fd02557b', 'verse', 'ACT.5.25', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Teaching people in temple', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c4f850bc-18ec-b3d9-8f35-b705aca9fd37', 'verse', 'ACT.5.26', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Led without force', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4f132b34-fece-0cd7-229c-ebe250869ec2', 'verse', 'ACT.5.27', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Examined by high priest', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('84e406ba-d8bd-d080-112d-ad6b6d1c7c4e', 'verse', 'ACT.5.28', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Strict orders ignored', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('34cb439f-147f-90bc-87a4-941ba5fc2cae', 'verse', 'ACT.5.29', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Follow God not men', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('04951711-28c4-fa85-d919-cbdc5982c098', 'verse', 'ACT.5.30', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Lifted up Jesus you killed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('890b4343-6553-bc32-54de-c36c6c293577', 'verse', 'ACT.5.31', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Offer repentance as Prince', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('65623a39-cb93-4a19-58fa-f36b46e251c4', 'verse', 'ACT.5.32', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Given Spirit witnesses', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('82d7c5bb-3a16-b1e0-52ad-71f34258c17b', 'verse', 'ACT.5.33', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Gashed hearts, wanted death', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a3f4a3ad-65e7-64c7-de34-484d10d219b4', 'verse', 'ACT.5.34', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Esteemed Gamaliel stood', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ef3f2c77-60ba-fdfc-c50b-8b473605007f', 'verse', 'ACT.5.35', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Do nothing rashly', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f1078bb8-8e23-ce0b-4050-f53970295754', 'verse', 'ACT.5.36', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Remember Theudas failed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ddac8eaf-5695-517b-2d9f-6bf58dd57152', 'verse', 'ACT.5.37', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Example of Judas failed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2f29426d-1e62-a12f-e781-63fce2fed6e6', 'verse', 'ACT.5.38', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Just leave them alone', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('95ba48ed-4b09-486f-260e-225a0aa41a3f', 'verse', 'ACT.5.39', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Or fight against God', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('79519006-3ed7-050e-7e2f-5c1c07e57972', 'verse', 'ACT.5.40', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Inquisition beat them', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('26cb090f-13cf-7a47-ea23-e2e1b77567ab', 'verse', 'ACT.5.41', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Counted worthy of shame', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('27f19ac6-5382-2790-3933-68f5dc138712', 'verse', 'ACT.5.42', 'd7d47157-3111-3471-47d0-ad59424466dd', 'Every day preached Christ', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'chapter', 'ACT.6', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'THEY GRAB STEPHEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7e0c769e-0752-fa0b-3753-ed615237c37b', 'verse', 'ACT.6.1', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'Table dispute Hellenists', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c4a1fec1-700b-5af5-edd0-bb19c9721cf5', 'verse', 'ACT.6.2', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'Helpers needed for serving', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('56c7d089-dbf5-323a-727d-df0dd925ea69', 'verse', 'ACT.6.3', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'Elders select seven men', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c118cc2c-db19-361d-e760-ea5b03a97911', 'verse', 'ACT.6.4', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'Yield to prayer/word', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('04275f38-a394-7dfe-ba24-f30fd38276b2', 'verse', 'ACT.6.5', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'Group chose Stephen et al', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('539d2469-e4d5-3d80-bf08-91adc4da9ad3', 'verse', 'ACT.6.6', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'Ritual laying on hands', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f71fa913-6372-d8f0-6622-b8b0fb3d9f67', 'verse', 'ACT.6.7', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'Apostolic word spread', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b69f9c17-e5cb-4a11-91f7-8b12a31d1ce7', 'verse', 'ACT.6.8', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'Brilliant wonders Stephen', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ff42de08-1133-0ebf-7486-1f1e4bb1ea94', 'verse', 'ACT.6.9', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'Synagogue Freedmen argued', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0aa6fb5e-5b17-acfa-0ad1-50f7751699d3', 'verse', 'ACT.6.10', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'They couldn''t resist Spirit', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('94ff20df-a31b-bfa7-49d2-bce6e44b3afc', 'verse', 'ACT.6.11', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'Evidence suborned blasphemy', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('983f5018-7272-b495-d912-2b2d885b9ff8', 'verse', 'ACT.6.12', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'People stirred, seized him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a3a0408d-652b-cf1f-499b-4dcdaff2a914', 'verse', 'ACT.6.13', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'Hostile witnesses lying', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8c38b047-86e8-05a4-2a44-a389fe80691d', 'verse', 'ACT.6.14', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'Explain he changes customs', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fefe0da6-6b33-a83d-4f8d-876103e50d83', 'verse', 'ACT.6.15', '0817b3f7-a5ae-0b21-8eb2-4212c69634cf', 'Noticed face like angel', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'chapter', 'ACT.7', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'BOLDLY RECOUNTING ISRAEL''S HISTORY, STEPHEN IS STONED TO DEATH NEAR SAUL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('98c0b48f-e77c-5dad-5caf-7a9addc11bdb', 'verse', 'ACT.7.1', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Bringing case: Are these things so?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('937f04b1-701b-c0de-02a3-7d84b6070e3a', 'verse', 'ACT.7.2', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Opening: Glory God appeared Abraham', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('932c1f18-8bf2-1fc2-1d1c-ce7929cf3d81', 'verse', 'ACT.7.3', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Leave your country', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0f337cad-f017-c052-0f71-e06f8e46cad8', 'verse', 'ACT.7.4', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Dwelt in Haran then here', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6884a0ed-2b0e-496c-b6b4-5cf6efc042c9', 'verse', 'ACT.7.5', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Landed no inheritance yet', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ac5c45df-6e60-0ff0-bc0e-d55c2124eece', 'verse', 'ACT.7.6', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Years of bondage four hundred', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a1e66758-9d9e-00d1-468b-487f97c27871', 'verse', 'ACT.7.7', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Rescue nation they serve', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bbc7f22b-3c81-6e8a-bca0-9b5722ddb619', 'verse', 'ACT.7.8', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Entered covenant circumcision', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a4e1ef64-9384-6470-8878-04ce41b22b04', 'verse', 'ACT.7.9', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Children patriarchs envied Joseph', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('683cddbd-8135-9e89-b90a-91e3c6b80861', 'verse', 'ACT.7.10', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Overcame troubles in Egypt', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dd24168e-9919-b63c-9db4-9462a5db7385', 'verse', 'ACT.7.11', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Unrelenting famine came', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3039f2aa-ece0-02b1-dedf-94b6ae310cd4', 'verse', 'ACT.7.12', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'News of grain Jacob heard', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('937e6cb6-34b1-e7ee-2f79-a4ce3f052f16', 'verse', 'ACT.7.13', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'True identity shown second time', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ecf95904-4a33-37cc-78ad-1fe5fbd8be56', 'verse', 'ACT.7.14', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Invited seventy-five souls', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2b87bdfa-11cb-33b6-f684-d77dae26fb18', 'verse', 'ACT.7.15', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Numbered Jacob died Egypt', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c258fa02-62d1-9c7f-b7d5-abacca040753', 'verse', 'ACT.7.16', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Grandfathers buried Shechem', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ff2732f9-7bac-3ad9-4065-bb3430118983', 'verse', 'ACT.7.17', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'In time promise drew near', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bad7ca7b-f692-2e17-0a3b-da4dd34b5176', 'verse', 'ACT.7.18', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Sovereign king knew not Joseph', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dd322cc9-cbe0-3967-1d72-ed7eea6f1607', 'verse', 'ACT.7.19', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Race dealt authentically ill', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7a7d6365-ebeb-c549-3646-cd7069c2891c', 'verse', 'ACT.7.20', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Apostle Moses born fair', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('04fd01a9-850a-f08d-8f42-01285c6004fb', 'verse', 'ACT.7.21', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Egyptian daughter took him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('879750d2-31d4-c5d7-6dcd-492764282dc2', 'verse', 'ACT.7.22', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Learned Egyptian wisdom', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bb7eadce-19c3-dbca-34cd-a608588d5189', 'verse', 'ACT.7.23', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Sets heart visit brothers', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('19b9bef6-792c-d934-7d8d-0182f55933ce', 'verse', 'ACT.7.24', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Helped oppressed struck Egyptian', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7d05ca1f-80d7-0857-2727-b30546a42184', 'verse', 'ACT.7.25', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Israelites didn''t understand', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b3a6a824-7b1c-8e12-a8a0-f9488138de18', 'verse', 'ACT.7.26', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Strove to make peace', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('86086abb-f9ee-a297-fd62-0236fabba10e', 'verse', 'ACT.7.27', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Terrified man pushed him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('42d401f4-0350-c6a5-5090-0d326936f126', 'verse', 'ACT.7.28', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Order: Will you kill me?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('08097a25-45c8-af2b-ae7c-d730b6d97d73', 'verse', 'ACT.7.29', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Runaway Moses Midian', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('501ed06d-f237-1e4b-d8f7-0fb3a5ebdee3', 'verse', 'ACT.7.30', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Year forty angel bush', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f18f85e9-1d57-9eea-e6a7-6e4daf4f6d43', 'verse', 'ACT.7.31', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Sight amazed Moses', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('013f5b66-5e3c-19a7-4453-5af8447ceb6f', 'verse', 'ACT.7.32', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Trembling at God''s voice', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('08136f56-8cfa-c389-eb6f-1108ff2e85e2', 'verse', 'ACT.7.33', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Eject sandals holy ground', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1a364ed3-9817-884c-f181-7d0cc315c8b5', 'verse', 'ACT.7.34', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'People''s groans heard', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('45c657b1-0e91-815e-062a-c7a63632d250', 'verse', 'ACT.7.35', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Hand of angel sent deliverer', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e04bcdc4-6bd4-a548-1f6e-98e998aef531', 'verse', 'ACT.7.36', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Exodus signs Red Sea', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('afb4ac86-d1fe-55e4-f2af-7605b5c226c9', 'verse', 'ACT.7.37', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Named Prophet like me', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('40443df0-51ab-6bd3-0883-1d942a939562', 'verse', 'ACT.7.38', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'In congregation Sinai', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f0bf3dcd-47f8-e811-f629-0b93726d3f2d', 'verse', 'ACT.7.39', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Sires refused to obey', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e3881618-6e7c-8cbb-77fb-519aaa23b23c', 'verse', 'ACT.7.40', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Shape us gods to go', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b25b868d-c1db-a598-44b9-e10c655f80a2', 'verse', 'ACT.7.41', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Turned calf sacrifice', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('11d1a6a4-5abb-b06b-41af-1fdcd7e51509', 'verse', 'ACT.7.42', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Offerings to host heaven?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b6c04040-df4c-791f-1456-450bfce46acf', 'verse', 'ACT.7.43', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Nations beyond Babylon', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('98f949b6-6dad-fea7-68ff-4f57b7669005', 'verse', 'ACT.7.44', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Evidence tent witness', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b91e529e-263f-fb9e-5eaf-6312f37281af', 'verse', 'ACT.7.45', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'David brought it in', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('81d7eb0b-e472-fd68-32ac-4020a1972dcb', 'verse', 'ACT.7.46', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Tabernacle for Jacob''s God', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('63f278b3-c8d3-b5a7-ef56-33bca37a6e71', 'verse', 'ACT.7.47', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Only Solomon built house', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c4222563-df19-16f4-1b8c-368394c64e13', 'verse', 'ACT.7.48', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Does empty temples contain?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('65285c41-180f-760a-057b-ae5882d1ee42', 'verse', 'ACT.7.49', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'EARTH IS FOOTSTOOL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('16acb6f1-7eaf-f005-d958-9ed3f72eb274', 'verse', 'ACT.7.50', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'All these hands made?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('612674d6-a2ca-0acc-b9f5-290e18aa0d55', 'verse', 'ACT.7.51', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Torpid stiff-necked people', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('536a2a4f-30c3-bcc1-b64b-32c9a44180e8', 'verse', 'ACT.7.52', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Hounded prophets betrayed Just One', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4c36b39d-d599-25ce-5788-d2b56f6fb9db', 'verse', 'ACT.7.53', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Not kept law received', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('31d8c5cb-f73b-1502-f31b-a9601c886446', 'verse', 'ACT.7.54', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Enraged gnashed teeth', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d8938527-5f2e-d58c-31f5-d6225faed68c', 'verse', 'ACT.7.55', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Approved Jesus standing right hand', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c6f5e4a0-1fcd-118d-66f1-bc594e7a2e2f', 'verse', 'ACT.7.56', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Running heavens opened seen', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('03e7a617-831b-7f69-ed53-b992b89d504f', 'verse', 'ACT.7.57', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Stopped ears rushed him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5d221311-a3e5-4153-93c0-d4e749a0fd6b', 'verse', 'ACT.7.58', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Acting witnesses coats Saul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('063d5381-9b41-bec6-5078-b08829893cd6', 'verse', 'ACT.7.59', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Under stones Stephen prayed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b3b6e825-0168-2601-86b5-aa6853321ead', 'verse', 'ACT.7.60', 'cceb5ce0-7a2f-32c5-ff78-1b6ad25d8492', 'Lord forgive, fell asleep', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f74b1c37-66f3-a740-7081-6e878074aff0', 'chapter', 'ACT.8', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'OUTWARD PRESSURE; PHILIP BAPTIZES AN ETHIOPIAN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('07135fd5-f391-1ddf-4d0d-91de22e7a2d8', 'verse', 'ACT.8.1', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Ongoing persecution scattered church', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f4d181d8-1319-390d-1c68-606d52f67db0', 'verse', 'ACT.8.2', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Upright men buried Stephen', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('001f7e39-bcc8-084d-ae25-12cee7b8c67b', 'verse', 'ACT.8.3', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Tearing church Saul destroyed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('538cb2d2-2a21-89c9-04aa-000312bd12a6', 'verse', 'ACT.8.4', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Word preached everywhere', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('230d4230-71b6-ab48-d76a-0da0c89845f0', 'verse', 'ACT.8.5', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Arriving Philip Samaria', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('01a0314d-352e-c57b-1706-3897a3f9a1fe', 'verse', 'ACT.8.6', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Responsive crowds heeded', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f9182034-c2cc-7163-675b-315a82c2fa35', 'verse', 'ACT.8.7', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Demons fled, lame healed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6a021e08-175f-8f27-848a-6bd9b2330fa9', 'verse', 'ACT.8.8', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Place rejoiced greatly', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6d9225bc-373f-4e55-42b9-70c9a1d50d82', 'verse', 'ACT.8.9', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Renowned Simon sorcerer', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e37d2fc1-2f97-a88b-00e9-90ea75b51f6b', 'verse', 'ACT.8.10', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Esteemed Great Power', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5577a333-66ee-579b-ca46-b0c9d45abbcd', 'verse', 'ACT.8.11', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Sorceries amazed long time', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('66225826-81d1-b305-81b2-294dc2524e6f', 'verse', 'ACT.8.12', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Samaritans believed Philip', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9f528dd5-b39a-35c5-9bf9-95b2d75a5bf2', 'verse', 'ACT.8.13', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Upon believing Simon baptized', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0a42c3c2-c13c-8659-5a06-857aae344e17', 'verse', 'ACT.8.14', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Report apostles sent Peter/John', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e3d72228-0c90-1a3f-b222-4dbb82c95d75', 'verse', 'ACT.8.15', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Elders prayed for Spirit', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('97ed9ec0-4336-72d8-db6a-212250bef7ff', 'verse', 'ACT.8.16', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Previously only baptized Jesus name', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7a9ea194-cca6-425f-1c63-730cda2cd390', 'verse', 'ACT.8.17', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Hands laid received Spirit', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('72884ca6-432a-2335-5252-4d6e4686131d', 'verse', 'ACT.8.18', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Impressed Simon offered money', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dfee2d96-25b8-7e71-e51c-a47dd51e90fe', 'verse', 'ACT.8.19', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Let me have power', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('28ef15f0-88cb-93a1-f5e5-b01744c2fc2b', 'verse', 'ACT.8.20', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Incur perishing with money', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('37d4b7c0-4673-310e-cc59-56813317f3d7', 'verse', 'ACT.8.21', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Part nor lot in matter', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e31b4227-9826-1df2-5694-1d57a693f0b4', 'verse', 'ACT.8.22', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Beseech God forgiveness', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('253d4819-5970-aac4-cfdc-5490accae937', 'verse', 'ACT.8.23', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Also gall bitterness seen', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('31450ce1-8511-20dc-3980-0f695572919e', 'verse', 'ACT.8.24', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Pray for me Simon said', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('34da3b0d-5378-bdc3-7938-65782b1faade', 'verse', 'ACT.8.25', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Testified and returned Jerusalem', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ed295e48-4aba-a5e2-500b-3d13bbc18f7e', 'verse', 'ACT.8.26', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Instruction angel go south', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e70b552c-145b-d5e7-d7e9-f5775c2d64f0', 'verse', 'ACT.8.27', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Zealous Ethiopian eunuch', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('abc13cac-85fc-ac9e-a560-351b9c8c540c', 'verse', 'ACT.8.28', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Esaias reading in chariot', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('66dbe14c-dfc2-14c2-b04e-8d7421d339b8', 'verse', 'ACT.8.29', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Spirit said join chariot', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a0dea5f5-94c2-1fa0-0f8f-13874a2febaa', 'verse', 'ACT.8.30', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Asked understand reading?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('df6b5bd2-efa9-da8d-da97-156c173ddc11', 'verse', 'ACT.8.31', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Need guide he said', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b7f74ae4-2b95-bf67-0b5d-2f27e7a4ece5', 'verse', 'ACT.8.32', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Excerpt: sheep to slaughter', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('73c1c0c1-e5f1-40bf-c6e0-a3e3b0b67406', 'verse', 'ACT.8.33', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Taken judgment humiliation', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8b4fb15b-fad2-ff33-576f-6c691c7c3067', 'verse', 'ACT.8.34', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Humbly asked of whom?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f26be971-23dd-c270-cb56-915b45855db6', 'verse', 'ACT.8.35', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Initiated Jesus from scripture', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b359a07c-c46f-b350-b9d9-b438523fd5b3', 'verse', 'ACT.8.36', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'O look water baptism?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4993dc05-fbac-e527-eea5-907a03b75280', 'verse', 'ACT.8.37', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Profess belief Son of God', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2e2ea50e-6b53-5d9c-f444-12fbd863c4f6', 'verse', 'ACT.8.38', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Immersed both in water', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6f4c8683-426b-45ef-c778-0bb7fd31a33f', 'verse', 'ACT.8.39', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Away Spirit caught Philip', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fd126289-d164-ffb1-0f14-2ab982b03a59', 'verse', 'ACT.8.40', 'f74b1c37-66f3-a740-7081-6e878074aff0', 'Now Azotus to Caesarea', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bb69ff71-02b4-899b-de5c-66b0b5d12365', 'chapter', 'ACT.9', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'ROAD TO DAMASCUS; PETER RAISES TABITHA FROM THE DEAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ade91b7e-818d-5397-f367-c844372e1787', 'verse', 'ACT.9.1', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Raging threats against disciples', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d99d3e72-39ec-3d1d-f4a8-43da0963dcd8', 'verse', 'ACT.9.2', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Orders letters Damascus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d27fab65-a7c2-b71e-4669-f3586b93e0b1', 'verse', 'ACT.9.3', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Approached light flashed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e2d74468-f64c-3bd2-d245-41890303ddb6', 'verse', 'ACT.9.4', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Down fell voice heard', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a6ab1a77-8f58-48c7-d1fb-aa92e549193b', 'verse', 'ACT.9.5', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'The Lord spoke: I am Jesus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a85ac92f-c54a-74e7-eeb4-54197500755b', 'verse', 'ACT.9.6', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Order: Go into city', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1b4d8db1-6aa0-45ff-8c73-c75562201885', 'verse', 'ACT.9.7', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Dumbfounded men stood speechless', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e2cd3059-4217-0545-ad91-f41bbc6e6842', 'verse', 'ACT.9.8', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Arose blind led Damascus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5d22582e-ff78-27ae-dd48-fec14b917692', 'verse', 'ACT.9.9', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Mused three days fasting', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('104f1b5f-9592-768b-22c3-d2c24208d6a5', 'verse', 'ACT.9.10', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Ananias vision of Lord', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('062dd6f5-7cc6-aa44-63ac-6b3f7291aacf', 'verse', 'ACT.9.11', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Street Straight seek Saul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5265fe0e-7c45-6b26-eba5-17ab5e5ae0f4', 'verse', 'ACT.9.12', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Coming Ananias vision seen', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('93b017bf-72f5-6306-1b9a-b8f095d6d806', 'verse', 'ACT.9.13', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Unsure Lord he persecutes', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1aa9eda0-0988-106a-49d1-8f1c457bbefd', 'verse', 'ACT.9.14', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Sanctioned to bind saints', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d4ca541b-743d-983f-a4c9-8a43517c29ae', 'verse', 'ACT.9.15', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Prepared chosen vessel unto me', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3e14e1fd-8d8f-3a58-1ca4-bbed5d292760', 'verse', 'ACT.9.16', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Explain how great things he must suffer', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('52c65ae1-7213-d4a9-5a98-91a5e55a3852', 'verse', 'ACT.9.17', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'There Ananias entered and healed him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('41646a84-5b6f-6465-aec3-86ad95c288ee', 'verse', 'ACT.9.18', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Eyescales fell immediately baptized', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('94bdea44-9363-ac93-f50f-7f1baccb88fb', 'verse', 'ACT.9.19', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Received meat and strengthened', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b9ac2671-ccfd-1112-0cd9-cf559eda477f', 'verse', 'ACT.9.20', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Right away preached Christ', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('99f9a6e8-0821-fd6f-abd2-afb8c520a816', 'verse', 'ACT.9.21', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Amazement among all who heard', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('73fb72f3-74f9-a30a-f926-016f83f21291', 'verse', 'ACT.9.22', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Increased in strength proving Christ', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3d77ac61-dbe8-4859-231f-82162f42008c', 'verse', 'ACT.9.23', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Sought by Jews to kill him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('63e66a05-1daa-90ef-4072-48159c3e28be', 'verse', 'ACT.9.24', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Escape plan known to Saul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ae5d195a-89d4-352c-9ea3-725098ce8de5', 'verse', 'ACT.9.25', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Saved by basket down the wall', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f776652c-fd7d-f83c-912d-1fc2c10d279a', 'verse', 'ACT.9.26', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Tried to join disciples in Jerusalem', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bfc0190e-7cfd-ab36-6dbe-413a926e5d12', 'verse', 'ACT.9.27', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Apostles receive him via Barnabas', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0c3fdb57-2652-623b-dcdf-1f1c76096f5f', 'verse', 'ACT.9.28', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Boldly going in and out with them', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('53034235-e6fd-1433-7313-ed2f79c5876f', 'verse', 'ACT.9.29', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'In dispute with Grecians who sought to kill', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4ebe361e-d7d8-2fb6-b2d9-4ee526e6f2b0', 'verse', 'ACT.9.30', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'To Tarsus sent via Caesarea', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d652efbb-efe6-c6af-74fd-0521df047a34', 'verse', 'ACT.9.31', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Holy Ghost comfort multiplies churches', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('88823299-e19c-b0a1-9fb5-b50cf6cc46dc', 'verse', 'ACT.9.32', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Also Peter visits Lydda saints', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('456ed33f-789b-c106-c7fd-ce3d451582cf', 'verse', 'ACT.9.33', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Found Aeneas paralyzed eight years', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a477fa48-82e8-15d9-9f24-5864da864ebe', 'verse', 'ACT.9.34', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Rise Aeneas Jesus heals thee', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c7d96098-dcdd-1932-9227-aafbd129d402', 'verse', 'ACT.9.35', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Observed him whole and turned to Lord', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6c775b3c-e653-9d62-c10e-dce1741bfa02', 'verse', 'ACT.9.36', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Multiple good works by Dorcas', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fe35dfbe-3bfa-e7d0-af0c-3e9212875385', 'verse', 'ACT.9.37', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Then she died and was washed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a1679771-f0a8-2fc4-7101-4fd1af327ae9', 'verse', 'ACT.9.38', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Heard Peter was near sent two men', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f4b41b55-2af0-1a42-ab33-eab34af0a7e8', 'verse', 'ACT.9.39', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Entered upper room seeing widows weeping', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c71e730e-2b8a-510e-5cef-14c907ac81e5', 'verse', 'ACT.9.40', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Dorcas arise Peter commanded', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5ce93ffc-5597-ecef-e1f6-6d0a403df5bf', 'verse', 'ACT.9.41', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Extended hand and presented her alive', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c921d86c-ce8e-8d99-3181-e68db48bfdcb', 'verse', 'ACT.9.42', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'All Joppa knew and many believed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e3f92627-515b-2313-7676-adc5c73b2803', 'verse', 'ACT.9.43', 'bb69ff71-02b4-899b-de5c-66b0b5d12365', 'Days tarried with Simon tanner', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'chapter', 'ACT.10', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'NON-JEWS RECEIVE THE HOLY SPIRIT WHILE PETER IS PREACHING', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f0c0536d-ec6a-ea70-c2b6-b41bc87f3039', 'verse', 'ACT.10.1', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Non-Jewish Centurion Cornelius', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('726b4a1c-f2a8-476b-7ede-0ec898e85f5e', 'verse', 'ACT.10.2', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Observed God with house', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('faf2ccfd-260a-de77-60f2-a2ac733c8621', 'verse', 'ACT.10.3', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Ninth hour vision angel', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('21b68fdc-480c-ae63-77a3-d7ec2cba7f92', 'verse', 'ACT.10.4', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Just then prayers heard', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2e54a98b-a9ee-605e-b837-90fbf097a490', 'verse', 'ACT.10.5', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Entreat Peter from Joppa', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0e01d291-5993-3d23-89ec-3b8b83cc59bb', 'verse', 'ACT.10.6', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'With Simon tanner seaside', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('db710d40-e5e3-9cd8-e5f9-846333c101f4', 'verse', 'ACT.10.7', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Servants sent to Joppa', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9d88bfd3-9ae1-ffe6-3a5f-21581ad39471', 'verse', 'ACT.10.8', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Rehearsed matter sent them', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f5834bb8-4e1d-c274-9e71-927f0d3c903c', 'verse', 'ACT.10.9', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Entered housetop to pray', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ecf2906d-3984-43fe-3e2a-465c36d38aae', 'verse', 'ACT.10.10', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Cooked food trance fell', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('952576e3-5b3d-71c3-ae98-f2df8ef89266', 'verse', 'ACT.10.11', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Earth saw vessel sheet', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f01597bf-cccf-b8cf-4d71-6d871950d5c4', 'verse', 'ACT.10.12', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'In it all beasts', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b0265036-6aa2-c53f-129c-77b4e0b42f44', 'verse', 'ACT.10.13', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Voice: Rise Peter kill', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('46751433-c4ca-0a24-1d86-e97361604087', 'verse', 'ACT.10.14', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Eat not unclean Lord', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('46d15eb0-b98f-2588-33dc-353c04d0cfe2', 'verse', 'ACT.10.15', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'The cleansed call not common', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('46c33b7c-9bf7-3d3d-1d93-5e02a2e2a1ca', 'verse', 'ACT.10.16', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Happened thrice vessel up', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ce78be29-da7d-b91e-8af9-d63acce3b165', 'verse', 'ACT.10.17', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Enquiry men arrived gate', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4bcc6f3d-d81a-bcc2-a597-7dfa3be77b3a', 'verse', 'ACT.10.18', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'HOuse called for Peter', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('709d9295-860d-132f-1d28-56ef3df14e11', 'verse', 'ACT.10.19', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'On vision Spirit speaks', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dda52680-467a-e79d-0876-d053eb8087d2', 'verse', 'ACT.10.20', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Look three men seek', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cf90b5c9-018c-adbf-56c7-6d2881560274', 'verse', 'ACT.10.21', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'You seek me why?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('903f0015-7e3e-85db-3d11-e82b8c9ed88a', 'verse', 'ACT.10.22', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Sent from just Cornelius', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('262378fa-36df-8a08-cc37-7ccb33146435', 'verse', 'ACT.10.23', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Peter lodged them went', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4041caa9-b169-3a91-c2ec-7347012a8e39', 'verse', 'ACT.10.24', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Into Caesarea kinsmen wait', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d45e6898-d7d3-e15f-2f4b-f6aa102359f2', 'verse', 'ACT.10.25', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Reverence Cornelius fell down', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('318e09c7-b3b7-cdab-ed3b-5c785202862b', 'verse', 'ACT.10.26', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'I am man stand up', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6426b7c0-b045-6f11-2cd8-e269bd506b2c', 'verse', 'ACT.10.27', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Talked with him entered', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6f08e58a-a8fa-00de-021a-a360d6cb3b08', 'verse', 'ACT.10.28', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'With unlawful men associate', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4d4dd0f4-584a-d7e6-3ee6-f334fd4d0fbc', 'verse', 'ACT.10.29', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Here I came asking', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5133aa75-7599-5c99-7ed2-7b0c150f06df', 'verse', 'ACT.10.30', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'I fasted four days', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3c35987e-5d85-ff36-2af0-3f3601058c91', 'verse', 'ACT.10.31', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Looked on prayer heard', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e30725f1-87b6-d0a9-15a4-f6e5b06a9bcb', 'verse', 'ACT.10.32', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Entreat Simon to come', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6f6d8ac4-1eda-a7aa-1a12-a57d0639f861', 'verse', 'ACT.10.33', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Present before God hear', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('54f75263-c2d7-0976-1254-795ab5adac1e', 'verse', 'ACT.10.34', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Equal: God no respecter', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3c4bba92-5973-1a88-1e39-ff22e3a08a71', 'verse', 'ACT.10.35', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'That fears Him accepted', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5a170b2e-b2fe-0881-5b0e-f5f34075b8b2', 'verse', 'ACT.10.36', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Endeavoring peace by Jesus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d796e580-0cdd-a8ff-d137-1e587f88457a', 'verse', 'ACT.10.37', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Report published in Judea', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b36c5a11-f2f7-6c9c-fa68-818d04b7c121', 'verse', 'ACT.10.38', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'In power Jesus healed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ccf0f595-7885-ef4e-9ee4-462783706245', 'verse', 'ACT.10.39', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Slew on tree witnesses', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4c8bce5d-7b13-569e-2a58-75579e4ee4c7', 'verse', 'ACT.10.40', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Power raised Him third day', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('23efd117-a56d-3926-7396-93b5e5d4a93e', 'verse', 'ACT.10.41', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Resurrected ate with us', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3189e8ae-fce6-ef31-31cf-129745639fb9', 'verse', 'ACT.10.42', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Every soul judged by Him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('56a7596b-3824-3519-b315-14e4920c6c2e', 'verse', 'ACT.10.43', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'All prophets witness remission', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d7eace2d-5d62-9a99-bf41-30df1d6f5d8b', 'verse', 'ACT.10.44', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Came Holy Ghost fell', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('45213a9f-e635-d170-5621-519bb345721f', 'verse', 'ACT.10.45', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Holy Ghost on Gentiles', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('651ede9f-7e48-a09e-b172-0c5b753bb69c', 'verse', 'ACT.10.46', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'In tongues magnified God', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cd7ac154-5a71-1e9d-fcac-b095330f3e3f', 'verse', 'ACT.10.47', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'No water forbid baptism?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('26a22ac5-23a0-ea1d-dbb4-b9a69cd125d1', 'verse', 'ACT.10.48', 'e6b0cfc8-ad68-e000-5ac8-6701e1021df5', 'Gave command baptize Lord', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'chapter', 'ACT.11', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'CHRISTIAN CHURCH BEGINS AT ANTIOCH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('52f652fd-5d72-7052-d894-a063e58b773c', 'verse', 'ACT.11.1', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Christ received by Gentiles', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('97069c93-6e73-af83-d231-4d6e0fbd3428', 'verse', 'ACT.11.2', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Here contention circumcision party', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d0156234-0168-a5eb-01fa-f40ade08d5c4', 'verse', 'ACT.11.3', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Reproached eating with uncircumcised', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('42cd27ca-2d0c-f515-9001-fb5688e7eb77', 'verse', 'ACT.11.4', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'In order Peter explained', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('208923f2-fc61-3ff8-f926-b4b2ea6b3ec3', 'verse', 'ACT.11.5', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Saw vision Joppa sheet', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bcadf7c7-88b9-5177-bf4d-5fe4ea78d40f', 'verse', 'ACT.11.6', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Thought on beasts saw', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ecb67c3d-45e5-09d2-b9ae-609bd79bc5de', 'verse', 'ACT.11.7', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'I heard voice kill', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a0d7b7ad-3615-f5e3-b4a8-02afd30ba208', 'verse', 'ACT.11.8', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Answered nothing common Lord', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f6258117-2a6b-dcd4-f37a-d086ff5850cf', 'verse', 'ACT.11.9', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Not call common cleansed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3b64a8fd-a2f6-23ca-4e47-18faf86254fa', 'verse', 'ACT.11.10', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Came three times drawn', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('809955c7-9174-e24d-341f-7d8ee39b158a', 'verse', 'ACT.11.11', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Here three men arrived', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3ce83dfd-dc89-c540-9cf9-764015927255', 'verse', 'ACT.11.12', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Upper room six brethren', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cd6c0544-c29b-8bf3-e6d4-fd772b4625fb', 'verse', 'ACT.11.13', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Report angel send Joppa', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ec46e7a6-6454-bb14-cea4-683ed7a2160b', 'verse', 'ACT.11.14', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Call Simon save house', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('43e15908-ca72-abad-650c-1aef3d273d65', 'verse', 'ACT.11.15', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Holy Ghost fell beginning', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0d0f2a0b-2c97-4779-7e7a-3a183c27f4a6', 'verse', 'ACT.11.16', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Baptized with Holy Ghost', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('de2d1bae-fece-dfcc-bb03-1ec08173b474', 'verse', 'ACT.11.17', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Equal gift God gave', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ebae5486-266a-7e3d-b1c9-3ef232e72698', 'verse', 'ACT.11.18', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Glorified God Gentiles life', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('731ec0e2-50ad-94e3-45e3-6e45df4972d9', 'verse', 'ACT.11.19', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'In Phenice preaching Jews', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c0fb8dfb-661b-a269-3dce-a1c4a2bbf96c', 'verse', 'ACT.11.20', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Native Cyrenians spake Greeks', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('adc91a21-14ec-b833-f5ee-a6fae2c3fbdb', 'verse', 'ACT.11.21', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Signs hand Lord believed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ff77504f-c358-78e8-f5ef-6ce6e9475225', 'verse', 'ACT.11.22', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'All ears church Barnabas', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0f3c4680-4136-3d99-1819-2c86f51410bb', 'verse', 'ACT.11.23', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'There gladness cleave Lord', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e5dc9109-d4af-b1c2-e6ee-66998bcbd272', 'verse', 'ACT.11.24', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'A good man Spirit', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6638d769-b634-beb8-10c6-a113ad111523', 'verse', 'ACT.11.25', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Now Tarsus seek Saul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4cfccbb5-3c92-5b8f-8e37-8945366c59e9', 'verse', 'ACT.11.26', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Taught people called Christians', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('806245b1-90d6-a289-c45f-acea8fddc65e', 'verse', 'ACT.11.27', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'In these days prophets', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cba08e58-9d5c-6a2c-222f-c09b04be03ee', 'verse', 'ACT.11.28', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'One Agabus signified famine', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a6648c2f-9faf-90ae-8698-24ddcbf72aeb', 'verse', 'ACT.11.29', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Contribution send brethren Judea', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('11584a3d-a935-5fe0-489c-192c34b8b392', 'verse', 'ACT.11.30', 'fc6b9fb6-44c8-a280-51ef-d8345c5f3c3e', 'Hands Barnabas Saul elders', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'chapter', 'ACT.12', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'HEROD KILLS JAMES; PETER SAVED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('247f3ada-6c52-7284-a390-08cecf5fd676', 'verse', 'ACT.12.1', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Herod stretched hands vex', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7a729189-fed1-8b10-ba82-72e954409c28', 'verse', 'ACT.12.2', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Executed James sword brother', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3aa4f0ef-02b9-64b5-4fc7-07eef4fac4f2', 'verse', 'ACT.12.3', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Reasoned pleased Jews Peter', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('485aa388-f922-8bf1-b97a-bbdcc7fd1c58', 'verse', 'ACT.12.4', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Observe Passover quarteruions prison', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4fe8b732-667b-8a87-c352-8bfe1d65358d', 'verse', 'ACT.12.5', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Detained Peter church prays', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e2d15b54-003c-1abb-3401-0c2c7ef4b9ca', 'verse', 'ACT.12.6', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Keeping soldiers sleeping chains', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fe112c80-53f5-29d3-8d24-7aaf381d7646', 'verse', 'ACT.12.7', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'In light angel smote', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eeaac647-dd33-cd13-622c-22813fd3d982', 'verse', 'ACT.12.8', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Lock sandals cast garment', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fc76131f-8b50-6001-1f21-1b54b4e7736c', 'verse', 'ACT.12.9', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Led out thought vision', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a18fb40c-c867-ba1b-e403-5f410975fef2', 'verse', 'ACT.12.10', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Street reached iron gate', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cad22738-6aed-311c-dddd-4cbdb8c3ae85', 'verse', 'ACT.12.11', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Just Lord delivered me', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c7215116-785e-036c-54b3-2694e7800316', 'verse', 'ACT.12.12', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'At house Mary knocking', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0aa78396-21b9-3327-934c-72ec061e28f8', 'verse', 'ACT.12.13', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Maiden Rhoda hearkened gate', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ebd41586-3a70-500f-5656-35b836e430ad', 'verse', 'ACT.12.14', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Ecstatic opened not gate', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a5686f15-7a83-79c7-46bb-f0a3cc7c112f', 'verse', 'ACT.12.15', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Said mad his angel', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('02c7b965-7392-0577-5759-1d843916db50', 'verse', 'ACT.12.16', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Peter continued knocking opened', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5661bbd3-0bbe-05d6-bbc4-1ca8e019bd6a', 'verse', 'ACT.12.17', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Explained escape went place', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ad7741bd-ad14-993f-8874-7bd4d88b6e70', 'verse', 'ACT.12.18', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Turmoil soldiers where Peter', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('aa801733-d7e3-59e9-6e8d-904bf7bac848', 'verse', 'ACT.12.19', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Examined keepers killed them', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('38dce848-d0da-4656-37c9-7a10600cb6a1', 'verse', 'ACT.12.20', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Reconciled Tyre Sidon Blastus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a6004243-d27a-d6bc-a396-d8e47c3a9998', 'verse', 'ACT.12.21', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Set day Herod oration', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9d7f1eda-f575-4d57-7a1b-9c7d29c2bd25', 'verse', 'ACT.12.22', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Acclaimed god not man', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('06570574-1f4a-1e99-807d-3eccc98e57b7', 'verse', 'ACT.12.23', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Visited worms angel smote', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9e62eda3-6183-5eed-906c-98e198b628c3', 'verse', 'ACT.12.24', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Extra word God grew', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4444aaf5-db3d-976e-d40d-f82fadc8daa5', 'verse', 'ACT.12.25', '2c9dcae5-7fd9-ccc9-04f8-e00a233c05f3', 'Done ministry returned John', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'chapter', 'ACT.13', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'UPSETTING TOP JEWS, PAUL AND BARNABAS PREACH IN THE SYNAGOGUES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4f67a73d-7bca-bc71-e054-7185a11e259a', 'verse', 'ACT.13.1', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'United prophets teachers Antioch', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0e1d8b6f-0aa6-789d-067c-7fdb9813cf15', 'verse', 'ACT.13.2', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Praying Spirit Separate Me', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c4244926-b3b3-9883-3c59-6e8623fe8c8c', 'verse', 'ACT.13.3', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Sent them laid hands', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('124711a8-df0d-1fe0-9952-7f10526a5cdc', 'verse', 'ACT.13.4', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Entering Seleucia sailed Cyprus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4011ef16-7cb3-ee52-35e4-e95fc2a91d91', 'verse', 'ACT.13.5', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Town Salamis John minister', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9b4f270d-4418-3b89-f0d1-c65879e546c9', 'verse', 'ACT.13.6', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Through isle Paphos sorcerer', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bbfe2e50-566f-3367-2534-fbc41ef33ea9', 'verse', 'ACT.13.7', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'In deputy Sergius Paulus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f69bf729-6852-8369-2c14-d99ec7667316', 'verse', 'ACT.13.8', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Name Elymas withstood them', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0358195c-30f5-f0c6-2972-587214e5b21a', 'verse', 'ACT.13.9', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Glared Paul filled Spirit', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('57c415b5-6a2f-f9be-bada-da46a8a2ed6c', 'verse', 'ACT.13.10', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Then said Enemy righteousness', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b7cac7b1-20a6-81da-4adc-78b464428ccb', 'verse', 'ACT.13.11', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'O blind mist fell', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9efb0282-dfa8-d32f-3d2c-77492527cdad', 'verse', 'ACT.13.12', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Proconsul believed doctrine Lord', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d19e0089-c31a-a662-571a-ee63841604f4', 'verse', 'ACT.13.13', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'John departed Perga Pamphyla', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9a24a2a3-dd70-2498-78c4-26b7dfacf097', 'verse', 'ACT.13.14', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Entered synagogue Pisidia sat', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5da26494-c65b-d1a9-6cf9-510b5ada15f1', 'verse', 'ACT.13.15', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Word exhortation rulers sent', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f48920e1-23a1-05af-acf6-97c53697204f', 'verse', 'ACT.13.16', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Signaled hand Men Israel', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d22665d5-3d8b-d7e3-a4c7-180875147695', 'verse', 'ACT.13.17', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'People chosen Egypt arm', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e30ac41b-c0f2-7df4-94eb-f10aee7a3491', 'verse', 'ACT.13.18', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'About forty years wilderness', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d2d836d3-e540-0d87-4937-07b2a98df68d', 'verse', 'ACT.13.19', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Under destroy nations divided', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('523931a3-5e43-da7a-8e90-0ac00bf62008', 'verse', 'ACT.13.20', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Length judges Samuel prophet', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('12279d74-2ca7-bff0-31ba-ce5f38b56634', 'verse', 'ACT.13.21', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Asked king Saul given', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f24085ea-25ac-4b8a-34e6-002009ec0d34', 'verse', 'ACT.13.22', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Named David heart king', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('916af1e9-8124-193c-4a0a-1757befa0171', 'verse', 'ACT.13.23', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Descendant Jesus Savior raised', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('754de5c4-e509-1a51-f986-b095de74a689', 'verse', 'ACT.13.24', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Before coming John baptism', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('06971f56-33df-2c47-61e5-c691e8044c85', 'verse', 'ACT.13.25', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Am not he shoes', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('749b2bff-fb28-ea8a-0e7e-0f26f4331454', 'verse', 'ACT.13.26', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Reason salvation sent you', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0743c0b8-a79d-fdd2-3fe2-fb7aac6ee813', 'verse', 'ACT.13.27', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Not knew voices prophets', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fcb965a1-7786-c8bb-f498-7c8e9c91dfc0', 'verse', 'ACT.13.28', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Asked Pilate slay him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('94ddcfce-0cc7-76cd-6101-44ae72d976bd', 'verse', 'ACT.13.29', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Buried in sepulchre tree', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0caec400-cf4e-2c2b-f0b5-136dfc189440', 'verse', 'ACT.13.30', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Almighty God raised dead', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4a6e15a7-0f7e-e460-a3ad-fff2137201c2', 'verse', 'ACT.13.31', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Seen many days witnesses', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('17705f61-ee42-3c81-7497-ebd9c5bd4c00', 'verse', 'ACT.13.32', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Promise fathers glad tidings', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('82547ee0-deb6-be66-588b-5c6a8990f8de', 'verse', 'ACT.13.33', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Resurrected Jesus Psalm Two', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e95dfda1-29e0-f65e-5140-46e3e5fcbe1c', 'verse', 'ACT.13.34', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Evermore no corruption mercies', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2536ea60-5a8d-adba-3c2f-0c073f5a1f63', 'verse', 'ACT.13.35', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Another psalm no corruption', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d87b8d15-eb38-065a-e7e7-ae4513b225b9', 'verse', 'ACT.13.36', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Corruption saw David slept', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('538fdade-5188-7ac0-a628-b781564a2bc8', 'verse', 'ACT.13.37', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Him God raised no', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3f039836-b824-bf5c-1678-2b1e22102ece', 'verse', 'ACT.13.38', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'In this man forgiveness', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('75138cf6-87de-363c-29c4-16208376fff0', 'verse', 'ACT.13.39', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Now justified law could', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('20c526fe-9c71-d0e4-e04f-f2883f85ec2b', 'verse', 'ACT.13.40', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Take heed prophets come', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d7ee9f46-5b72-c438-5dbe-bfe9322c06b5', 'verse', 'ACT.13.41', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Heed despisers wonder perish', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3c57cb26-7f40-e621-a72f-7cb1f0dcf58f', 'verse', 'ACT.13.42', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Entreated preach next sabbath', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b4dcf6e3-cc1a-d338-2c28-4418749c6577', 'verse', 'ACT.13.43', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Synagogue broken grace God', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4aa24dd7-be98-c08f-eabd-6ec0657d315e', 'verse', 'ACT.13.44', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Yielded city hear word', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e6a25a6d-87ed-ecd7-565e-f3edfc574d70', 'verse', 'ACT.13.45', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Nasty envy contradicted Paul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a427c2b0-492a-3dae-308d-f1430eac73b2', 'verse', 'ACT.13.46', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Announced turn Gentiles lo', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('81b613e5-2f8e-973e-c850-7ac18c58d7d9', 'verse', 'ACT.13.47', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Gave light Gentiles salvation', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('70b33c8d-617b-265c-313a-fa469ba8a49a', 'verse', 'ACT.13.48', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Ordained eternal life believed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('511f7065-4be3-3253-72db-9f4638ae5160', 'verse', 'ACT.13.49', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Greatly region word published', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d934a087-2356-1202-a926-1fba98932ccc', 'verse', 'ACT.13.50', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Urged women raised persecution', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6682ad92-a61f-3d56-89a9-424a60c83f99', 'verse', 'ACT.13.51', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Exited shook dust Iconium', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6700799d-48eb-4705-9d0d-70a870de77ba', 'verse', 'ACT.13.52', '334e0fae-69ec-baac-99da-e1d0c9ce2a9a', 'Spirit filled disciples joy', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('53a4fe24-9759-9162-6132-5edfd83c202f', 'chapter', 'ACT.14', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'RAISING A CRIPPLED MAN TO HIS FEET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('427b5786-efd1-d2a3-490c-180b30ab1564', 'verse', 'ACT.14.1', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Reaching Iconium synagogue believed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f8553a75-5962-0128-14dc-67f9c6013db8', 'verse', 'ACT.14.2', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Agitated Gentiles against brethren', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7bbb7d21-17a9-1fc8-0b7b-02f17fa32026', 'verse', 'ACT.14.3', '53a4fe24-9759-9162-6132-5edfd83c202f', 'In Lord speaking boldly', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7f352a00-01d4-97d4-9922-826eb891584f', 'verse', 'ACT.14.4', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Sidings multitude divided apostles', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8ffb1c4b-71fc-ad0c-486d-0fc9e95e8c95', 'verse', 'ACT.14.5', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Intending stone abuse them', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9a50bcfa-1098-1033-3beb-2a3a3b98e1b3', 'verse', 'ACT.14.6', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Noticed fled Lystra Derbe', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a2ac4c92-d6b0-9e98-22a0-ed37840b112b', 'verse', 'ACT.14.7', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Gospel preached there region', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bc12fffe-6e5b-4a9f-26e8-8132b77187e0', 'verse', 'ACT.14.8', '53a4fe24-9759-9162-6132-5edfd83c202f', 'A cripple Lystra feet', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('08399926-68c4-ca38-ecc7-754d1c7ee955', 'verse', 'ACT.14.9', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Crippled heard Paul faith', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('591022bd-388d-20da-55c8-cf03113c381d', 'verse', 'ACT.14.10', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Right up stand leapt', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2f2ac158-cda5-b38d-0e9d-4d7341ac237e', 'verse', 'ACT.14.11', '53a4fe24-9759-9162-6132-5edfd83c202f', 'In Lycaonian gods down', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1bdb19bd-692a-80d2-fe85-a4a410ef6620', 'verse', 'ACT.14.12', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Paul Mercurius Barnabas Jupiter', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('62a3310b-cfc2-7ced-f856-d45592ebff7a', 'verse', 'ACT.14.13', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Priest oxen garlands gates', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2010806a-8011-8b4b-5066-7fe555c9d669', 'verse', 'ACT.14.14', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Listen rent clothes ran', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bd4e11b8-ff8a-d90b-8806-8ec64423702c', 'verse', 'ACT.14.15', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Error men passions God', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cb01caee-689d-b1ba-6038-4893d7262d40', 'verse', 'ACT.14.16', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Dealing nations own ways', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('143cc3bf-61aa-6c4c-7af9-f619d062d2f0', 'verse', 'ACT.14.17', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Merciful rain fruitful seasons', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('55ed4443-378f-b073-8541-39b10ed8ea37', 'verse', 'ACT.14.18', '53a4fe24-9759-9162-6132-5edfd83c202f', 'All scarce restrained sacrifice', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7f229c78-09c5-8801-922c-08df3eafb114', 'verse', 'ACT.14.19', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Now Jews stoned Paul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d590f066-e6a6-3a7b-d214-01805e28d9f1', 'verse', 'ACT.14.20', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Then rose up Derbe', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1a55d8c6-0e6b-5ac5-82fd-483c9b5c678e', 'verse', 'ACT.14.21', '53a4fe24-9759-9162-6132-5edfd83c202f', 'On returned Lystra Antioch', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('747a15a7-629c-3ab2-7e2a-16ec6316ad60', 'verse', 'ACT.14.22', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Hardships kingdom God souls', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e6744482-b65e-3f57-5775-5a1c5b39f189', 'verse', 'ACT.14.23', '53a4fe24-9759-9162-6132-5edfd83c202f', 'In every church elders', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('18e22bbf-1794-15af-0975-f22b6e391764', 'verse', 'ACT.14.24', '53a4fe24-9759-9162-6132-5edfd83c202f', 'South Pisidia to Pamphylia', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('78036412-4bd3-251c-ed19-29659d1d14eb', 'verse', 'ACT.14.25', '53a4fe24-9759-9162-6132-5edfd83c202f', 'First Perga then Attalia', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('73b4302b-43a0-a18e-c674-2ef8e49f4307', 'verse', 'ACT.14.26', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Ended Antioch work fulfilled', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('707c0048-14d0-b05e-eb0b-7c191c0f94b3', 'verse', 'ACT.14.27', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Explaining door faith Gentiles', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e8d4f554-fa3c-2a52-ac41-669d96855f1a', 'verse', 'ACT.14.28', '53a4fe24-9759-9162-6132-5edfd83c202f', 'Time long abode disciples', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'chapter', 'ACT.15', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'CIRCUMCISION DEBATE INVOLVES PAUL AND BARNABAS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4dd20d55-2e4c-e42d-259d-bd5bf45852ff', 'verse', 'ACT.15.1', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Certain men came from Judea', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8c8bc320-d8f0-f05e-bf81-29f64d9bc06f', 'verse', 'ACT.15.2', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'In dispute Paul and Barnabas engaged', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1fc11b43-5913-cdd9-a04c-95e7c5f6c44f', 'verse', 'ACT.15.3', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Reported conversion of Gentiles', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('655167bc-a79d-7c82-9f0b-29d69dc42795', 'verse', 'ACT.15.4', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Came to Jerusalem elders', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('135883a6-218f-0a3c-a5d9-153aa61814dc', 'verse', 'ACT.15.5', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Uprising of believing Pharisees', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7719a17d-053f-c118-0b9e-19b6b6d3013e', 'verse', 'ACT.15.6', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Met to consider this matter', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('630aed90-60ef-b494-fedc-fe51a334db92', 'verse', 'ACT.15.7', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Chose Peter to speak first', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b3e1f261-5b4e-daa5-96d8-fd445099163e', 'verse', 'ACT.15.8', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'In hearts God testified', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9f1177e9-e9e8-5f83-f0ac-2d13099714b0', 'verse', 'ACT.15.9', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Same faith purifies their hearts', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2405a110-5462-467c-92fa-6a877bed588a', 'verse', 'ACT.15.10', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Impose no yoke on disciples', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bb3305f7-eba8-e2f6-e6a2-574db80518b8', 'verse', 'ACT.15.11', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Only through grace are we saved', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('54dff5e4-88ce-7def-ee54-dcfbc54ab8d1', 'verse', 'ACT.15.12', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Narrated signs and wonders', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5fa2f014-357a-5c0f-2f48-3f367978bab0', 'verse', 'ACT.15.13', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Declared by James: Brothers listen', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bc47ea88-480f-652c-c4ca-33a028c9c34a', 'verse', 'ACT.15.14', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Explained how God chose a people', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0ee1c5a4-9c34-1fe3-3817-1367855724ef', 'verse', 'ACT.15.15', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Books of prophets agree', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6037f633-5d7c-643f-896b-ffa0f5ce2ce2', 'verse', 'ACT.15.16', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'After this I will return', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9d52d921-2286-5c86-ed9b-74759587ca97', 'verse', 'ACT.15.17', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'That the rest of mankind may seek', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fdff61fa-2754-877c-b589-2139c1b50d52', 'verse', 'ACT.15.18', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Eternally known are his works', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9146a535-a279-dcb3-15ea-14d934e93251', 'verse', 'ACT.15.19', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'I judge we shouldn''t trouble them', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1930c690-5eae-74f7-0093-9d037d3cece8', 'verse', 'ACT.15.20', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Note to them: abstain from idols', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('93d029d8-f231-b624-e95d-ad87881a9c0f', 'verse', 'ACT.15.21', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Verses of Moses read in every city', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8e1dbf29-926b-089b-f540-28ad5137ff46', 'verse', 'ACT.15.22', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Officials chosen to send letter', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('730d0f85-61e1-376e-27d8-7d0b6a956f78', 'verse', 'ACT.15.23', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Letter written to Gentile believers', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('32962af0-7ed5-aae2-33a1-a1014ce6ab34', 'verse', 'ACT.15.24', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Verbal disturbance by unauthorized men', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5e04a2b7-361b-769c-6411-29746108170b', 'verse', 'ACT.15.25', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Elected men sent with beloved Barnabas', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('64a97533-510f-f207-b9b3-704771289a75', 'verse', 'ACT.15.26', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Staked their lives for Jesus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8d04f7da-1a9b-d2ba-4691-5eee2c78a608', 'verse', 'ACT.15.27', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Personally confirmed by Judas and Silas', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('18c8d4f4-2f72-f656-0ae1-d7b5f2115205', 'verse', 'ACT.15.28', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Agreed by Holy Spirit and us', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2329f1bf-5c54-c084-f50d-10640fa80b7c', 'verse', 'ACT.15.29', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Use nothing sacrificed to idols', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a953c145-cd57-24ae-409d-5876dfbf57e7', 'verse', 'ACT.15.30', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Letter delivered to Antioch', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c6506d54-5a58-daab-a36c-23968041be15', 'verse', 'ACT.15.31', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'All rejoiced for the encouraging message', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6db1f550-da33-a04b-85ac-741e82b2e102', 'verse', 'ACT.15.32', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Numerous words from Judas and Silas', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9cb484c7-1063-98c0-bc9d-44a11c8b2a68', 'verse', 'ACT.15.33', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Departed for Jerusalem in peace', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8025639f-91bc-b897-8798-cc13a75679d6', 'verse', 'ACT.15.34', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'But Silas decided to remain', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f5b74c67-788d-47b7-6729-faf0190454f0', 'verse', 'ACT.15.35', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Antioch teaching continued', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e15b2ed0-f8a8-4cff-dfb2-a338117d56f3', 'verse', 'ACT.15.36', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Revisit the brothers', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d0782779-77ac-e1f7-76df-ced2652f8c6c', 'verse', 'ACT.15.37', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Needed Mark with them', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4df161b6-d9e2-75b6-3e68-71feffad04e0', 'verse', 'ACT.15.38', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Against taking him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cb9ee59e-264d-3ae6-4c09-7676dea881ac', 'verse', 'ACT.15.39', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Bitter disagreement separated them', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c1dde4bc-309b-78a1-a50b-d0d800c8ed0d', 'verse', 'ACT.15.40', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Accompanied by Silas, Paul left', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5bc85495-a1a2-607a-0076-0ffc17dee649', 'verse', 'ACT.15.41', '9a567f8f-ff9f-b7c6-b6ea-cbb4ebe226e4', 'Strengthened churches through Syria', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5853ff21-567b-5f44-6e1f-06ac2199fc21', 'chapter', 'ACT.16', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'HOUSEHOLDS OF LYDIA AND JAILER REJOICE IN FAITH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d09e6200-6e00-523c-9a15-ed38ad5e3bac', 'verse', 'ACT.16.1', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'He meets Timothy at Lystra', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e0fcfafd-5a04-d000-1426-57e01b4ae70f', 'verse', 'ACT.16.2', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Opinion of believers favors Timothy', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('de583d39-39bc-2629-4a04-1b734af4745c', 'verse', 'ACT.16.3', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Undergoes circumcision because of Jews', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('23c2328d-107a-89e9-c0a1-955e58fed251', 'verse', 'ACT.16.4', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'So they deliver Jerusalem decrees', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8d8719b1-bd90-8c6b-261c-7c08f8b9f5ee', 'verse', 'ACT.16.5', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Ecclesias grow strengthened in faith', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a82dbda0-316e-585a-652c-44c48fd032c0', 'verse', 'ACT.16.6', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Holy Spirit forbids word in Asia', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e01a155d-0f73-0b99-205f-1d5517b6c736', 'verse', 'ACT.16.7', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Onward toward Bithynia yet Spirit stops', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('94fd82dc-c41a-df31-cacb-cf31aebd2f5e', 'verse', 'ACT.16.8', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Landed at Troas', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1eb45366-8ae8-07d1-a8d8-5bf3970643e6', 'verse', 'ACT.16.9', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Dream of Macedonian man', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b7774f21-2e19-2c2f-4542-18b783de29ee', 'verse', 'ACT.16.10', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Sought to go immediately', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('500481ec-67a1-4c95-0dac-32a35868ec44', 'verse', 'ACT.16.11', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Out from Troas they sail', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d29fdb36-7df8-5ce6-62f2-94082f551580', 'verse', 'ACT.16.12', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'First city Philippi reached', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cb709a4f-5717-b95d-2ba7-1598024f5f6d', 'verse', 'ACT.16.13', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Looking for prayer riverside', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7eead785-7031-4d8b-3fb8-128a95b5389f', 'verse', 'ACT.16.14', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Yonder Lydia purple dealer', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('97766a7d-3bc8-f9ea-5f05-09dabe3e8bb3', 'verse', 'ACT.16.15', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Drenched in baptism with house', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ee27c205-263b-47bd-c520-87b425914d53', 'verse', 'ACT.16.16', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Ingoing to prayer slave girl', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e20ae7d7-a96d-eeea-d5c3-3ecbe5bd5d7c', 'verse', 'ACT.16.17', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Announcing them servants of God', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('79675929-3ac8-e5f8-63a4-54c1bb73c181', 'verse', 'ACT.16.18', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Annoyed Paul commands spirit', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6a8c189d-1c9c-c181-2bf7-dd281016ad3b', 'verse', 'ACT.16.19', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'No profit left owners seize', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('379a1b32-d4fb-6967-403d-719f802d70cc', 'verse', 'ACT.16.20', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Dragged before magistrates', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cffba5f1-f1e4-0381-8034-8f2c15590c8a', 'verse', 'ACT.16.21', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Jewish customs accused', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fc0b085e-50ed-2cb8-ab1d-06659422ee14', 'verse', 'ACT.16.22', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Attacked and beaten rods', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('882a3262-c9ed-357d-b80c-579ec70dde04', 'verse', 'ACT.16.23', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Imprisoned under strict guard', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d8535a12-ced0-ae9c-8b9a-07b7ee31b554', 'verse', 'ACT.16.24', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Locked in inner cell stocks', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d43a13ad-9055-5856-f86f-5aad32d5c266', 'verse', 'ACT.16.25', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Even at midnight they sing', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0b533189-3628-06da-17f0-579cddaa8f6f', 'verse', 'ACT.16.26', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Rumbling earthquake opens all', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cb31c1ec-b97b-2dc9-c4c9-92aa6894e00a', 'verse', 'ACT.16.27', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Realizing doors open jailer', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('62cc0b5e-8a64-7673-e768-7ff8326ba521', 'verse', 'ACT.16.28', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Eagerly Paul shouts Stop', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e9155924-425d-bc8f-fae0-03cdd8ff5d93', 'verse', 'ACT.16.29', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Jailer trembling falls down', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ae2aa8cc-97a5-2407-f847-89f2422707ae', 'verse', 'ACT.16.30', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Out he asks What must I do', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('67722d05-5056-63f0-fe55-7c1ff176746f', 'verse', 'ACT.16.31', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'In believing on Jesus saved', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d29ff437-5259-6b35-b23e-8ec38b1ec0fa', 'verse', 'ACT.16.32', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Christ''s word spoken to all', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('027f4506-f5ac-7fd8-ab6b-7786c5c4c004', 'verse', 'ACT.16.33', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Eager jailer washes wounds', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('171ec1aa-2e18-0bd3-6204-4d5c72c22efe', 'verse', 'ACT.16.34', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Invites them home rejoicing', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('25dddf35-341f-6579-50e8-4e24a9ba8ba7', 'verse', 'ACT.16.35', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Next morning magistrates release', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5935bf1f-4841-05be-7d97-a0832dcc1c55', 'verse', 'ACT.16.36', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'From the jailer comes news', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1713fa62-639b-9d66-7dd5-9fe522438e3e', 'verse', 'ACT.16.37', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'As Romans they demand apology', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('55403282-8dbb-5d51-6834-98eacbc2ff3c', 'verse', 'ACT.16.38', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Informed magistrates grow afraid', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1ecfe757-47f1-3b26-95e4-eb2263612ead', 'verse', 'ACT.16.39', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'They try to appease and urge', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e072e607-1d98-2b65-1dde-c6ed881526b2', 'verse', 'ACT.16.40', '5853ff21-567b-5f44-6e1f-06ac2199fc21', 'Home with Lydia encouraged', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'chapter', 'ACT.17', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'BEREANS BELIEVE AND PAUL TALKS IN ATHENS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ec073204-ff79-3833-e1cb-994d3b1a7769', 'verse', 'ACT.17.1', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Beside Amphipolis/Apollonia reached', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d6e2db99-69bc-c5b7-e56d-86eee12e1cbf', 'verse', 'ACT.17.2', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Each Sabbath Paul reasoned', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6d89888d-a4b1-1fef-fcd5-78f5d53c8bc4', 'verse', 'ACT.17.3', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Revealing Christ must suffer', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('65d57681-0180-2dcd-8bcd-52377e45ab5c', 'verse', 'ACT.17.4', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Elect Jews and Greeks believed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0bdc113e-e35c-104a-3023-52384f42356e', 'verse', 'ACT.17.5', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Angry Jews stir up mob', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e4e8e1ba-073b-b138-2469-6a11e62eeb1f', 'verse', 'ACT.17.6', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Not finding them drag Jason', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b569aade-6740-1818-ddbf-ff76c7850d46', 'verse', 'ACT.17.7', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Saying they preach Jesus King', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('57f9cb38-91dc-c3df-31a3-af3e1a67578a', 'verse', 'ACT.17.8', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Both people and rulers troubled', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9c97ad5d-e5c2-132d-1efd-22353f675457', 'verse', 'ACT.17.9', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Enforced security taken Jason', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('14242e15-881f-0b22-ec87-132d31690a16', 'verse', 'ACT.17.10', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Led away by night to Berea', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c7ff6b90-5864-823c-8b28-3ba3520a91b9', 'verse', 'ACT.17.11', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'In Berea noble hearers search', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f3696c14-a0c4-2754-c7c8-676000a28e4b', 'verse', 'ACT.17.12', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Eager examination leads belief', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cf6f4a98-7b96-9d1c-cf1e-1cdc6143c1eb', 'verse', 'ACT.17.13', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Vengeful Thessalonians arrive', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b2a60c1a-42a5-3fbf-bb68-0419adc197ba', 'verse', 'ACT.17.14', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Escorted away Paul departs', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4712e24d-02a3-80de-7d25-54a6bcaec273', 'verse', 'ACT.17.15', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Athens becomes next stop', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cc27659e-34a6-d36e-0255-56bb1d3775c4', 'verse', 'ACT.17.16', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Noticing city full of idols', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b344001b-2bd3-d367-84c8-c5167c03054a', 'verse', 'ACT.17.17', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Daily he reasons in market', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('be8b92be-51ae-59df-301b-ec9d4a65702a', 'verse', 'ACT.17.18', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Philosophers debate him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('65bbd4d4-7a4d-8698-3bd5-284f312be53c', 'verse', 'ACT.17.19', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Arrested attention Areopagus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b673840f-6f91-0562-771c-d8d018398a68', 'verse', 'ACT.17.20', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Unfamiliar teaching asked', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6d282d06-b92f-4875-aed5-b31bd6517f85', 'verse', 'ACT.17.21', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Lovers of novelty hear new', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('308eefd5-12ac-9e58-aa64-1bb1702bb3c0', 'verse', 'ACT.17.22', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Taking stand Mars Hill', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0e70a03a-1752-b246-108e-613810dfbb71', 'verse', 'ACT.17.23', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Altar to Unknown God', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5632e85e-af27-707f-f8ef-a61610a56773', 'verse', 'ACT.17.24', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Lord made all needs nothing', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('52505438-33a5-9978-c73f-dec325115654', 'verse', 'ACT.17.25', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Keeper of life and breath', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('76e95b65-f69e-4343-b2d2-f73a8d85095b', 'verse', 'ACT.17.26', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Single origin of nations', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('24314904-bd29-b119-d52c-79656bf3396c', 'verse', 'ACT.17.27', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'In hope they seek God', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('516c2a03-e785-8cb6-4aae-468f447dee42', 'verse', 'ACT.17.28', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Noting poets: His offspring', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('58f4b7ec-3f6e-83a2-a4cc-b1ee118ad139', 'verse', 'ACT.17.29', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'As offspring no idols', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6e26d440-0c45-12bc-bf61-f7b9a815862b', 'verse', 'ACT.17.30', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Times ignorance overlooked', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a0621dfa-2e36-de49-07e4-b38b335d3829', 'verse', 'ACT.17.31', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'He set day to judge', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d4cd384f-d153-4f49-3012-d740a62cab45', 'verse', 'ACT.17.32', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Encountering resurrection mock', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('af713ce9-a325-a6af-d563-addc10b3f626', 'verse', 'ACT.17.33', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'No longer speaking departed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9427af8b-559c-4202-2e80-859ed106b539', 'verse', 'ACT.17.34', '862c55a2-b840-fa3e-cb1a-6d5ab8eab8f3', 'Some join him and believe', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'chapter', 'ACT.18', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'EPHESUS AND CORINTH RECEIVE PAUL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e9ac4f15-a81c-8594-eb1d-093fc37a0bbc', 'verse', 'ACT.18.1', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Exits Athens to Corinth', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('735d3cc5-525a-6047-0209-1c0509f170ef', 'verse', 'ACT.18.2', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Partners with Aquila/Priscilla', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0c91cc8b-3e01-28db-a134-cca736bf1243', 'verse', 'ACT.18.3', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'He lives and works tents', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('57dd63f1-714e-9b89-2a04-d098848dc6b6', 'verse', 'ACT.18.4', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Each Sabbath reasoned', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0dd732a9-2b84-9a08-40d9-7ee4c273b901', 'verse', 'ACT.18.5', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Silas/Timothy arrive testified', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0df94445-4f6c-f0be-0ee8-87635cebb6e3', 'verse', 'ACT.18.6', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Under opposition goes Gentiles', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6aff2478-999d-b422-c90c-ed47f3f23577', 'verse', 'ACT.18.7', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Steps into Justus house', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c5306960-f86e-f815-6b06-3497aea11aea', 'verse', 'ACT.18.8', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Authority Crispus believes', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bd9ee862-914b-61f2-0502-2d0643e099fd', 'verse', 'ACT.18.9', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Night vision: Fear not', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('173d7150-2048-7b47-bb80-f3a4468b0097', 'verse', 'ACT.18.10', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Divine protection promised', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('aa0ca689-ffda-6133-49f8-8bc9a24e2f19', 'verse', 'ACT.18.11', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Continues teaching 18 months', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b01d537c-666d-906b-f3c8-d07a7d7bdd58', 'verse', 'ACT.18.12', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Opposed by Jews Gallio', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('87ee2b91-7fcd-52a2-8ec0-97b98f1830a3', 'verse', 'ACT.18.13', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Religious charge law', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('86fff3e8-e222-a549-2569-7053d1fb7952', 'verse', 'ACT.18.14', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Intentionally Gallio refuses', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9daa3283-0945-b536-b75f-3c9feb1f12c0', 'verse', 'ACT.18.15', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Names words law yours', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e29f4978-8e7c-fc19-80fa-2457c9274364', 'verse', 'ACT.18.16', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Throws them out tribunal', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('328053e2-e6b0-540a-1a06-4305dbe1ddb3', 'verse', 'ACT.18.17', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Hostile crowd beats Sosthenes', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('29cdbd17-4e8c-20c8-e214-7c3547eb8322', 'verse', 'ACT.18.18', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Remains then sails Syria', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d31ebff9-11ee-afb5-1e09-68d62d255781', 'verse', 'ACT.18.19', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Enters Ephesus synagogue', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d5d172df-bd59-13fa-03c4-9f9974f73f99', 'verse', 'ACT.18.20', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Crowd asks stay longer', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1861d381-7023-bf47-6b9b-febaee2de5a3', 'verse', 'ACT.18.21', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Entrusts return God''s will', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('385d4780-3feb-79a4-78c6-9f050bb90c79', 'verse', 'ACT.18.22', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'In Caesarea greets church', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('64ae41c5-d560-7345-81c2-a656379bb846', 'verse', 'ACT.18.23', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Visits Galatia strengthening', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6d4ec160-6785-743e-ed01-cee22f8d4267', 'verse', 'ACT.18.24', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Eloquent Apollos Ephesus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('01c33f5d-71ef-7887-5409-a1235a35ff8c', 'verse', 'ACT.18.25', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Passionately teaches Jesus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('27c0d85b-df72-4d92-08a8-b6e034fb4868', 'verse', 'ACT.18.26', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Aquila/Priscilla explain way', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8ab66946-8d39-7c8f-f5c9-cdb85ce5bbf8', 'verse', 'ACT.18.27', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Urged go Achaia helps', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('483dee12-b062-5417-6dca-97d26ecae190', 'verse', 'ACT.18.28', 'b4ae99b1-94e1-4bdc-c9b5-e70565a28776', 'Loudly refutes Jews Christ', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'chapter', 'ACT.19', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'ARTEMIS ARTISANS ANGRY ASSEMBLY AGAINST THE WAY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ec5a3ceb-d866-cdf1-17c3-2dd78e5f5ee7', 'verse', 'ACT.19.1', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Arriving Ephesus found certain disciples', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8da4cbe5-97d5-2165-a39f-f6ce7921b0a0', 'verse', 'ACT.19.2', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Received the Holy Spirit?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('436f4cc3-76a7-ece0-a26c-0261d6539bad', 'verse', 'ACT.19.3', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'To what were you baptized?', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e84159ab-5499-5095-2d4c-27e31bbf1837', 'verse', 'ACT.19.4', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Explained John''s baptism of repentance', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2bd942dd-ae40-824e-c30b-e2e02ee5c2ba', 'verse', 'ACT.19.5', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Men were baptized in Jesus'' name', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fa1211a6-4b03-139e-c783-27ace3a4299a', 'verse', 'ACT.19.6', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Imposed hands and Spirit came', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c2dffb5a-0960-be81-abf2-c227514b2f0d', 'verse', 'ACT.19.7', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Sum of men were about twelve', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('724413c2-115d-ecbc-a93d-7174997a3a70', 'verse', 'ACT.19.8', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Arose and spoke boldly in synagogue', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7b95624f-bee2-6c2e-8704-742e2e8846ed', 'verse', 'ACT.19.9', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Reasoned daily in Tyrannus school', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fe53ce3f-3a9b-22ed-b6a2-c8f96016847c', 'verse', 'ACT.19.10', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Two years continued so all heard', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6113492e-bc59-dee3-9102-546f7ae44391', 'verse', 'ACT.19.11', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'In special miracles God worked', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a1e6d102-4b3c-2fb4-acb2-08258b32ceba', 'verse', 'ACT.19.12', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Sent handkerchiefs cured diseases', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d38ef1af-8f79-e25a-50c9-fa8cc4b179a4', 'verse', 'ACT.19.13', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Attempted exorcism by traveling Jews', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('11927325-428a-cbdc-29e6-387f274ec2d7', 'verse', 'ACT.19.14', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Number seven sons of Sceva did so', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('272a4ef7-917d-4794-17e5-fce089acb2ef', 'verse', 'ACT.19.15', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Said the evil spirit: Jesus I know', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('99d8a409-3ccc-892e-e891-45a0dd1c44eb', 'verse', 'ACT.19.16', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Attacked by man with evil spirit', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a670475e-a353-1443-2fea-a531ed1b709f', 'verse', 'ACT.19.17', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Name of Lord Jesus magnified', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1fd7bce6-d0d7-e050-cdf4-027cb43ac008', 'verse', 'ACT.19.18', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Great number confessed their deeds', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fb69abff-1b77-0590-ebf8-a5782673d5e5', 'verse', 'ACT.19.19', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Rich books burned before all men', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e6bcc12f-ee44-2968-ded8-8b5335da4aa4', 'verse', 'ACT.19.20', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Yet word of God grew mightily', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('98ccd312-4b4c-7d0f-4ad4-35b243101af6', 'verse', 'ACT.19.21', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'After these things Paul purposed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9f4bb6b1-0390-d48e-da1b-9575e7f62397', 'verse', 'ACT.19.22', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Sent Timothy and Erastus to Macedonia', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3cc12596-4990-a9b0-72b4-3eac6902539a', 'verse', 'ACT.19.23', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Stir about that way arose', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3335f71f-28a9-5ded-1630-8606ca073111', 'verse', 'ACT.19.24', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Ephesian silversmith made shiny shrines', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('19e35830-4ac3-6181-61db-b6b5123cd04f', 'verse', 'ACT.19.25', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Men of like occupation gathered', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('385d7cde-908e-9f1f-9c59-fe6634f49175', 'verse', 'ACT.19.26', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'But Paul has turned away many', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0af72469-6ce4-24da-0135-e2b93fb45259', 'verse', 'ACT.19.27', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Loss of wealth and Artemis'' magnificence', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('46360af4-69d9-f885-6b98-2b10b91e23e3', 'verse', 'ACT.19.28', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Yelled: Great is Artemis of Ephesians', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f2409fb7-b4c9-aad0-287f-b2aea69a227f', 'verse', 'ACT.19.29', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Aristarchus and Gaius caught in confusion', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('67e5f25d-d6b0-d237-1593-01dfc0efbe4e', 'verse', 'ACT.19.30', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Going in was Paul''s desire', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('941697db-7523-6e22-c03b-e34c3f0b94ef', 'verse', 'ACT.19.31', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Asiarchs urged him not to enter', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7d39fdb9-b1be-5df6-d9f0-1cb66236c953', 'verse', 'ACT.19.32', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'In confusion some cried one thing', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('74bc1e36-1194-6f95-c16a-fa3d6940c43a', 'verse', 'ACT.19.33', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Next Alexander beckoned with hand', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('951d140e-f0a3-3a4e-0204-68a673fda69a', 'verse', 'ACT.19.34', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Shouted two hours Great is Artemis', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d8705727-1e48-c7f1-bbe8-42d0972a56de', 'verse', 'ACT.19.35', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Townclerk appeased people and spoke', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c5d359fa-6199-99e2-c5b8-de24c437e38a', 'verse', 'ACT.19.36', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'These things are undeniable so quiet', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('08668364-d279-b6ec-95b2-47bf517cd67c', 'verse', 'ACT.19.37', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Have brought these men not blasphemers', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7ffba659-9127-23b6-1219-9b49301ede6b', 'verse', 'ACT.19.38', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Enter legal suit if Demetrius has matter', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0bb858ee-2365-ed29-511f-6ac50f3f8da2', 'verse', 'ACT.19.39', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Whatever else determined in lawful assembly', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8001c766-0052-5f07-aaa6-e9712c6a5f37', 'verse', 'ACT.19.40', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Accused of uproar without cause', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c354b7be-5fd3-1092-c9fb-2850c94e90d1', 'verse', 'ACT.19.41', '2882a1a7-3833-27bd-9fb1-1c333c63ce5b', 'Yielded and dismissed the assembly', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'chapter', 'ACT.20', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'REVIVAL OF YOUNG MAN AND PAUL''S FINAL FAREWELL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7fd64289-0a6a-5658-d6d7-9bb1642d07c8', 'verse', 'ACT.20.1', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Riot subsides Paul departs', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f7ca1b50-2bec-66d1-d380-193d1aa9f6e8', 'verse', 'ACT.20.2', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Encouraging believers Macedonia', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('75a521c2-f05c-2845-d3e4-67a20e095d7b', 'verse', 'ACT.20.3', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Vicious plot Greece changes', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b4eacd8e-7d47-ec7b-1f28-24f6bb780c28', 'verse', 'ACT.20.4', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Included companions cities', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a4124fbe-024d-7a14-bba9-322912543860', 'verse', 'ACT.20.5', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Vanguard group Troas', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eed07818-ddc6-13f8-8b75-8cc28656a34b', 'verse', 'ACT.20.6', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'After Passover sail Troas', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('01347336-7d70-b908-4510-bc706df73088', 'verse', 'ACT.20.7', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Lord''s Day lengthy preaching', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f8d51321-ef99-559b-5104-2e6372afd75d', 'verse', 'ACT.20.8', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Oil lamps upper room', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0dc0ff1d-bd4c-07e2-7bc7-baf67ff361c5', 'verse', 'ACT.20.9', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Fatigued Eutychus falls', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5e73f3b3-74dd-1a85-a7a6-38ddd4af03bb', 'verse', 'ACT.20.10', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Yet Paul embraces him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('051f0f21-f9ff-b3f4-438f-bc76e2b73ad6', 'verse', 'ACT.20.11', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Once returned broke bread', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d96e0c9e-e226-a900-e557-dea2e0523715', 'verse', 'ACT.20.12', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Uplifted young man alive', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1be756f1-5150-32da-9068-53c3d724c4b4', 'verse', 'ACT.20.13', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Navigating ship Assos', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8465b104-76db-d796-5799-220e6aba7cf1', 'verse', 'ACT.20.14', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Going aboard Mitylene', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('667b789f-f899-46eb-f6dc-c96f78593fd5', 'verse', 'ACT.20.15', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Moving past Chios Samos', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bde11e84-086e-8843-eb93-1396ee3b3941', 'verse', 'ACT.20.16', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Avoiding Ephesus hasten', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('95a2ed48-5137-f81c-fb53-6e237b05edc0', 'verse', 'ACT.20.17', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'News summons elders', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('84bf0a20-9f78-42eb-89a8-102cb59c8210', 'verse', 'ACT.20.18', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Always knew humble service', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fabf7236-a16f-657a-2175-cd84e535018a', 'verse', 'ACT.20.19', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Needing tears trials', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('310e75b1-e863-0302-62f3-15072eb4ca60', 'verse', 'ACT.20.20', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Declaring profitable thing', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('085cf622-7519-892c-d9f8-de4554dfb434', 'verse', 'ACT.20.21', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Preaching repentance faith', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('570b7752-27ea-d037-bd8d-034da6a5426d', 'verse', 'ACT.20.22', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Already bound Jerusalem', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('858622d6-61ef-5e2c-1c58-66d454b423f4', 'verse', 'ACT.20.23', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Uncertain except chains', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4b28da1c-a111-eafa-9a79-250e91bba09f', 'verse', 'ACT.20.24', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Life not precious mission', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('48b02045-0e52-bdf9-fc35-3c2f51850d3f', 'verse', 'ACT.20.25', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Solemnly see no more', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('12748c1a-fefd-38bb-6cbb-6acfb06d7689', 'verse', 'ACT.20.26', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Free from blood all', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('757b4ba4-87b9-cbc6-bb0f-0f4909774a26', 'verse', 'ACT.20.27', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'In full declared God', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8792b415-ff05-5470-69f8-2d20db5d16dd', 'verse', 'ACT.20.28', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Nurture flock overseers', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bd7efac3-d7b3-a11d-8a4b-80c7d53335ae', 'verse', 'ACT.20.29', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'After departure wolves', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0676600a-20d8-ab09-bae2-8fd375131da1', 'verse', 'ACT.20.30', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Leaders speak perverse', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6c870f52-4c7e-4826-0da2-1669f33c63c5', 'verse', 'ACT.20.31', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'For three years warned', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9f688f7e-de11-b746-7591-c1ddf93144b4', 'verse', 'ACT.20.32', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'And now commend God', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fa6b1582-c68d-9219-b2e6-a959d29fde18', 'verse', 'ACT.20.33', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Refusing silver gold', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a82e2060-3b51-39fc-fdb8-f65b493b9d79', 'verse', 'ACT.20.34', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Evidence hands supplied', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6f1c2949-3826-edfd-da1b-c4081b858f52', 'verse', 'ACT.20.35', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Working hard taught giving', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8e964b1b-3c02-8bea-799f-71ed04c1d6ea', 'verse', 'ACT.20.36', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Entering prayer kneels', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('09503e44-4c8a-60e0-a691-5e55496471dd', 'verse', 'ACT.20.37', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Loud weeping embraces', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5bf19f95-6ba0-d078-cea7-10c751d6a27c', 'verse', 'ACT.20.38', '5e7cdf2b-ae47-60d6-9ff5-057301b21d12', 'Led ship grieve face', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f3cefe8c-f183-c368-801e-26a9f3837bf3', 'chapter', 'ACT.21', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'SOLDIERS ARREST PAUL DURING A RIOT IN JERUSALEM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e251cdfa-fb50-7cc1-cc49-efd8d007ba19', 'verse', 'ACT.21.1', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Sailing Miletus Cos', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9f9db798-6a9d-3ed4-ddf8-4c86643d13c1', 'verse', 'ACT.21.2', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Onward ship Phoenicia', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d9a7139b-a53d-8417-39ce-12fa889db89b', 'verse', 'ACT.21.3', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Leaving Cyprus Tyre', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0b1db92b-9ee1-9fa9-c9dd-5feef0a0db11', 'verse', 'ACT.21.4', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Disciples warn Paul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6e50e44c-1789-6fe4-124a-066e49f8ec11', 'verse', 'ACT.21.5', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Including families pray', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b5021d64-8a5c-5ca1-ed0b-933e991cbebc', 'verse', 'ACT.21.6', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Embarking again part', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('65f76494-1483-c7a9-9936-2f5f3481e9a0', 'verse', 'ACT.21.7', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Reaching Ptolemais greet', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f6c03d8b-f2d7-0983-485b-d051be557c87', 'verse', 'ACT.21.8', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Staying Caesarea Philip', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0860a57b-e50b-f6c1-8d09-3adb90877bdc', 'verse', 'ACT.21.9', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Apostle''s daughters prophesy', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f3e87b2d-a286-52d6-3c3f-cc82a9360517', 'verse', 'ACT.21.10', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Revelation Agabus comes', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3e6e620c-caa2-3c5f-f4e3-f30e89090153', 'verse', 'ACT.21.11', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Ropes bind Agabus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('904cbf09-b959-a417-d123-7dd6c024e256', 'verse', 'ACT.21.12', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Earnestly beg not go', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4017b03a-a83a-0646-64c1-3008a6f231ba', 'verse', 'ACT.21.13', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Steadfast Paul ready die', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('caed5ce6-8a3f-0d2d-e713-b2a5f0feed96', 'verse', 'ACT.21.14', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Trusting Lord will done', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c51f4e97-c739-7ee5-d54b-12774bc2e3a1', 'verse', 'ACT.21.15', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Packing baggage set out', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bd8c1a28-4d9a-c9f4-138b-844a099890f0', 'verse', 'ACT.21.16', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Accompanied by Mnason', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('babe1be7-3761-6c0e-4083-7be5660b6e9f', 'verse', 'ACT.21.17', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Upon arrival welcome', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('19b05b91-3c53-3754-0bd5-b63e2cd4e0ae', 'verse', 'ACT.21.18', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Leaders James receive', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('76279362-b74f-6c41-0036-b5e0f36ba67a', 'verse', 'ACT.21.19', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Detailed report God did', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('37f17bd5-bb63-3627-4919-0d2655f2e9d8', 'verse', 'ACT.21.20', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Uncounted Jews zealous', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c5cf1cb5-8c15-ffcd-644b-7f9e83adbc58', 'verse', 'ACT.21.21', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Rumors forsake Moses', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3bc62246-f990-0de7-a90f-309c3d2b9d7e', 'verse', 'ACT.21.22', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Inevitable gathering hear', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5ef86d02-c4dd-d10d-c91d-d0d92a188459', 'verse', 'ACT.21.23', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Now advised four men', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('763c8d28-75bf-960e-ec7e-299823acc88f', 'verse', 'ACT.21.24', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Guided purify pay expenses', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a4b76946-c130-fd4f-0792-920d85868821', 'verse', 'ACT.21.25', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Again affirm Gentile decree', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a4b32820-7950-9e10-446a-dee84eb8a63e', 'verse', 'ACT.21.26', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Ritual purification temple', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('70946977-8368-5cf0-daca-e62fe456655a', 'verse', 'ACT.21.27', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Inciting Jews seize Paul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('efdc4c0e-1534-fe8b-b427-be2d461ad67a', 'verse', 'ACT.21.28', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Outcry accuses attacking', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('77a230a9-05d0-d361-b9cd-fa83a8e947a4', 'verse', 'ACT.21.29', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Trophimus assumed temple', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6ec692f0-1ebc-1c84-efba-a731761c863e', 'verse', 'ACT.21.30', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'In uproar drag Paul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('df87b9da-b9d4-5810-3b82-e762ca3b45ef', 'verse', 'ACT.21.31', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'News riot commander', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('274e9122-86b3-6c9b-28d7-79991e7e8aba', 'verse', 'ACT.21.32', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Joined soldiers stops beating', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('10624113-12f2-c8b4-456a-491730aa45ca', 'verse', 'ACT.21.33', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Enchained two chains', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0db346e2-c69e-8dc5-7357-40caa3591a63', 'verse', 'ACT.21.34', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Roaring crowd conflicting', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('71cb660d-cc56-cf27-aa17-3beec2a9f941', 'verse', 'ACT.21.35', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Up stairs carried soldiers', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1cecde5f-698e-5de4-8abe-47330b0fc898', 'verse', 'ACT.21.36', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Shouting Away with him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('41cab1bc-782b-628d-6ec1-81f0f301fb4b', 'verse', 'ACT.21.37', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'As nears barracks asks', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('978af8bb-91b2-897c-eea4-e753f1ad3552', 'verse', 'ACT.21.38', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Leader supposes Egyptian', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2e033a46-b69e-5c79-5d3c-f2225b56dcc8', 'verse', 'ACT.21.39', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Explaining Jew Tarsus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('229b169d-3d41-2b89-abdd-40e3c89c4f63', 'verse', 'ACT.21.40', 'f3cefe8c-f183-c368-801e-26a9f3837bf3', 'Motioning speaks Hebrew', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'chapter', 'ACT.22', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'WITNESSING BEFORE THE TEMPLE CROWD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8c5640a5-d39b-a97f-023b-42872c765637', 'verse', 'ACT.22.1', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Words of defense to brothers and fathers', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2c327646-10b6-3224-0ec8-4525b453c422', 'verse', 'ACT.22.2', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'In Hebrew speech he quiets the crowd', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1f81b59e-8328-c948-9b1f-6aba4d3dddd3', 'verse', 'ACT.22.3', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Trained under Gamaliel, truly zealous for law', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e4291ba3-0052-04e9-4b46-1257b6cc384b', 'verse', 'ACT.22.4', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'No mercy shown as he persecuted the Way', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4a68e9d8-21e7-a97f-34a0-8f59fc5d2b90', 'verse', 'ACT.22.5', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Endorsed by priests with letters to Damascus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5df8511a-7a2f-21ba-dc03-01b5ad0fc9c0', 'verse', 'ACT.22.6', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Suddenly a bright light surrounds him at noon', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('85936c08-4da5-f7bd-f8ad-aad850cbb4e0', 'verse', 'ACT.22.7', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Struck to the ground by a heavenly voice', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('165d28c5-e3f1-a089-ce55-a03d246297e9', 'verse', 'ACT.22.8', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Identifies Himself as Jesus of Nazareth', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('30cf5eb3-41ca-1079-be25-5918cd2ad934', 'verse', 'ACT.22.9', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Near companions see light but miss the voice', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d5e17fe6-19d4-c946-52cd-924e7e1ea079', 'verse', 'ACT.22.10', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Guided to Damascus to learn God''s will', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b40350a5-1b3e-b43e-a9e3-526c43dbdb93', 'verse', 'ACT.22.11', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Blinded by glory he is led by hand', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0922aadb-50e4-b859-9b14-3edeeec578c6', 'verse', 'ACT.22.12', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Esteemed Jew Ananias comes and stands beside him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ebe2c2be-d25a-5b05-c403-e36b441ef201', 'verse', 'ACT.22.13', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'From God he receives sight and calling', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('83e7c78e-5687-0d4f-dc7a-970484e5801f', 'verse', 'ACT.22.14', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Ordered to know His will and see the Righteous One', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('547e6248-e9ff-daff-321b-2b727d715f97', 'verse', 'ACT.22.15', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Raised up as witness of what he saw and heard', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5c5c36b2-a2fa-ce93-1ca4-eff959aa3e0c', 'verse', 'ACT.22.16', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Exhorted to arise be baptized and washed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2ecc087c-f0ee-e525-43a4-b804db2820db', 'verse', 'ACT.22.17', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Temple vision later falls on him in Jerusalem', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0d51a4a8-cf7a-7091-7dc1-aa5c74944b48', 'verse', 'ACT.22.18', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Hastened away by word that they will not receive him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('885f0a94-40d3-7445-3bd6-4ac0c2fb7fd2', 'verse', 'ACT.22.19', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Explains his former violence against believers', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('782b2a7c-f7a9-d39f-4c31-fb5ca5be075a', 'verse', 'ACT.22.20', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Taking part when Stephen''s blood was shed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('faec04f1-b89b-c184-d7d3-4434064746c7', 'verse', 'ACT.22.21', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Entrusted now to be sent far to Gentiles', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d6eaa7ab-9cc6-f49f-cc0a-5153c1b6c910', 'verse', 'ACT.22.22', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Mention of Gentiles enrages the listening crowd', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c2456c4e-bc1d-3f64-f411-aa1638482a42', 'verse', 'ACT.22.23', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'People shout he is not fit to live', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8697a33b-dd8a-b5f2-204b-f0a006e78cf9', 'verse', 'ACT.22.24', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Led into the barracks for scourging examination', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5710295d-3da3-ea9f-cb9c-8ba4421535f1', 'verse', 'ACT.22.25', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Exposes his Roman citizenship before the centurion', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7fc3fb8e-566a-d9be-82b9-a983e3d96561', 'verse', 'ACT.22.26', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Commander grows concerned that he is a Roman', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('976937b2-457b-2074-c850-9f1ca2a914de', 'verse', 'ACT.22.27', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Reminds him that Paul is freeborn', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e7c2e23c-c07d-5e1e-d831-3555298d5c1a', 'verse', 'ACT.22.28', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'On hearing this the examiners withdraw in fear', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9bec53c9-62a5-7fed-b3cb-816bab1d8947', 'verse', 'ACT.22.29', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Worried commander releases his bonds the next day', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a04aabf6-59a2-ab64-8f94-8dc7d9505873', 'verse', 'ACT.22.30', '5d86f00e-313a-60c8-1c4f-8b2f1130c89b', 'Delivered before the council to learn the charge', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'chapter', 'ACT.23', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'IN THE MIDDLE OF THE NIGHT PAUL IS ESCORTED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3ffb9684-f7bb-9545-5c49-02080da365ad', 'verse', 'ACT.23.1', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Innocent conscience claimed before council', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c1f79116-d46e-a9bc-ef19-dc41ffae93d8', 'verse', 'ACT.23.2', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'New insult strikes him on the mouth', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('95eecd3b-4665-bf22-0d40-9a3e1499d1bd', 'verse', 'ACT.23.3', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Then Paul rebukes the whitewashed wall', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ba70e108-c99a-c346-7ee9-1aad6e392484', 'verse', 'ACT.23.4', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Humbles himself when he learns high priest', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ca23c08c-0072-5fa9-fa7d-5390fdcb11d6', 'verse', 'ACT.23.5', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Explains he did not recognize him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0bda018e-f17f-6a04-0b93-d50bb50a351e', 'verse', 'ACT.23.6', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Makes division using Pharisee hope', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1a86eac9-3cab-4e90-dfb6-d80ae2ba87c2', 'verse', 'ACT.23.7', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Insists on resurrection of the dead', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c1b29c50-8853-c5d9-414e-ad5b2bf2b48b', 'verse', 'ACT.23.8', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Dispute erupts between Sadducees and Pharisees', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bb10d601-ee60-fd4f-379d-cc50926cccb8', 'verse', 'ACT.23.9', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Divided council becomes violently agitated', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3abfa856-c415-a26b-7514-1cf17dde0eed', 'verse', 'ACT.23.10', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Lysias rescues Paul from their violence', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a8401940-0924-e4c3-d549-b4a00fa1bef5', 'verse', 'ACT.23.11', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Encouraged that night by the Lord', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3804c5bf-0269-6e57-30e2-b8e137b1793d', 'verse', 'ACT.23.12', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Oath taken by Jews to kill Paul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b3bd0f99-6a88-1b72-01eb-160639884684', 'verse', 'ACT.23.13', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Forty men in conspiracy', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cd15bde3-9d3b-fc89-1fa6-d5c1e0ba7a52', 'verse', 'ACT.23.14', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'They inform chief priests of curse', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2ab9c023-c9fb-953a-a52e-8c249be5b077', 'verse', 'ACT.23.15', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Have council ask captain to bring him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('48cdca2d-eb38-5ff8-0d08-8b34559ae5fa', 'verse', 'ACT.23.16', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Entered castle to tell Paul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a1c0401f-0f75-efc6-20e8-1aa2402a8866', 'verse', 'ACT.23.17', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Nephew sent to chief captain', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0e21db30-9b3a-83d7-f7de-7b2412a93749', 'verse', 'ACT.23.18', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Introduced to captain by centurion', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a69f5a7d-f71f-4715-9df4-8b8647c080e4', 'verse', 'ACT.23.19', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Goes aside privately with captain', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('40c581b7-bab9-9dd5-8477-574bb4d009dd', 'verse', 'ACT.23.20', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Hear the plot to kill tomorrow', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('460fab4a-bc0f-b2ed-b0f7-d871bc698a6f', 'verse', 'ACT.23.21', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'They lie in wait with oath', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f70a3b47-1219-0d87-5659-71ce476f3f80', 'verse', 'ACT.23.22', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Privately dismisses the young man', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('08c4e306-f440-5fd1-eb01-befab784c9d5', 'verse', 'ACT.23.23', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Army of two hundred soldiers prepared', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e1d722d1-6b14-476c-9fb5-a383844c5aed', 'verse', 'ACT.23.24', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Unto Felix safe conduct provided', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7b849a71-2cdc-165c-27d3-5ce2108481b4', 'verse', 'ACT.23.25', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Letter written by Lysias', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4e5a6e63-ffb4-5e5b-921e-b520b26534c8', 'verse', 'ACT.23.26', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Introduces himself to Felix', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2876ac92-d3da-1a4f-7645-f0928ecf76de', 'verse', 'ACT.23.27', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Saved this Roman from Jews', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0aee571e-1796-d569-2a01-e73531c531e1', 'verse', 'ACT.23.28', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Examined him in their council', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2e26a051-db75-4312-f60c-48d0a0e42de9', 'verse', 'ACT.23.29', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Saw no cause for death', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f0265c96-ab8d-df62-945e-f116f005c6e9', 'verse', 'ACT.23.30', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Conspiracy known so sent to thee', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6e420a55-6188-32e9-5af6-65b8e33227b7', 'verse', 'ACT.23.31', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Overnight journey to Antipatris', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9337e723-1815-9d75-384c-99d49f13fc8f', 'verse', 'ACT.23.32', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Riders continue to Caesarea', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9e79f939-1e16-7a8f-c67c-5e5209cddc57', 'verse', 'ACT.23.33', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'They delivery epistle and Paul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7085808c-a51d-50b1-1336-878d724b782a', 'verse', 'ACT.23.34', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Enquires of his province', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('58b5bcb4-fbbf-1cca-c4d4-93e48927fdcd', 'verse', 'ACT.23.35', 'cd6a2b58-0cdd-21f9-de7a-8bef53d29f18', 'Detained in Herod''s judgment hall', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('37d96dde-f598-055b-e8b1-c374acbdeec9', 'chapter', 'ACT.24', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'TRIAL BEFORE THE GOVERNOR FELIX', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bc421b2d-2260-9721-d2da-ee4b10a22365', 'verse', 'ACT.24.1', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Then high priest Ananias arrives with elders and lawyer', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('04c44d75-a48f-5860-f923-0613453bd8b9', 'verse', 'ACT.24.2', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Requested by Felix, Tertullus begins accusation', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('13a2bdf7-07e4-19d3-aca2-b01f89fe2607', 'verse', 'ACT.24.3', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'In flattery he praises Felix for peace and reforms', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('92c9089c-30e7-85d3-37b5-0b0d857f3a18', 'verse', 'ACT.24.4', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Appeals for a brief hearing of their case', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ff8b8d9c-84a7-9a22-249f-8b529095d882', 'verse', 'ACT.24.5', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Labels Paul a plague stirring riots among Jews', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('98bdd7bd-43f7-e6d5-b9f1-f06d89e68b75', 'verse', 'ACT.24.6', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Blames him for profaning the temple before they seized him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0f5b2c43-6e9d-9bfe-5192-fa2662b09d54', 'verse', 'ACT.24.7', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Extracted from them by commander Lysias, they complain', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5f973d71-8fb4-9da7-326b-8967b78590a9', 'verse', 'ACT.24.8', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'From your examination you can verify these accusations', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0dea586b-ea14-0153-9322-faf4aceae7ba', 'verse', 'ACT.24.9', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Others, the Jews, join in affirming the charges', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9beae5e4-dcb5-a1ea-2b57-8db5051a01c5', 'verse', 'ACT.24.10', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Responding, Paul gladly offers his defense before Felix', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1205ce03-eff6-27f2-8c1d-a93941161b51', 'verse', 'ACT.24.11', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Easily they can verify he came to worship twelve days ago', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e11c9f2c-4d7b-9627-c330-b1e3b1e27cd3', 'verse', 'ACT.24.12', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'They never saw him disputing or stirring up a crowd', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('16b64bec-f1a7-803a-b8a1-bba1a328eae2', 'verse', 'ACT.24.13', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Hence they cannot prove the things they accuse him of', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1c07a0c9-516c-99cf-d3fa-26513ca30605', 'verse', 'ACT.24.14', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Emphatically he confesses he worships God in the Way', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cd27de1e-94c5-d476-0561-c22b966d2b01', 'verse', 'ACT.24.15', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Grounded in hope of resurrection of just and unjust', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cb68be5e-7d9d-81c4-3354-188ec82b74c0', 'verse', 'ACT.24.16', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Ongoing aim is to keep a clear conscience before God and men', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cdb7808e-e486-8b7e-6ea4-c123eadc00c6', 'verse', 'ACT.24.17', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Visited Jerusalem to bring alms and offerings to his nation', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4ff5a23c-e013-d350-6773-247766b3b12f', 'verse', 'ACT.24.18', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Entered the temple purified, without crowd or disturbance', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4d8b091f-5391-bece-683d-94e6dfe26942', 'verse', 'ACT.24.19', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Required witnesses from Asia are not present to accuse', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3724f4c2-22dc-4cb7-fd65-404bd2138712', 'verse', 'ACT.24.20', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'None here can state what wrongdoing they found in him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('63595106-efdb-8bb9-b197-3de634fb6fe5', 'verse', 'ACT.24.21', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Only his cry about resurrection is reason for this trial', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c1de6d40-b5ba-82f5-8ff6-f15b24adc2ad', 'verse', 'ACT.24.22', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Resolving to wait for Lysias, Felix adjourns the hearing', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('67e79b0d-007c-0456-f6c2-ea89f04330d8', 'verse', 'ACT.24.23', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Freedom under guard is granted, with friends allowed to serve him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0aa2540a-c485-f17d-2d60-67aac7c6d518', 'verse', 'ACT.24.24', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Entering later with Drusilla, Felix hears of faith in Christ', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a02de37a-d720-eb03-6be0-42b32a766220', 'verse', 'ACT.24.25', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Listening on righteousness, self-control, judgment he becomes afraid', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8770cbaf-e952-2168-f3f0-82d8b105a625', 'verse', 'ACT.24.26', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Intending to gain money, he often summons Paul to talk', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('93b3c6f2-bdbd-af7e-3e50-88bb72022f99', 'verse', 'ACT.24.27', '37d96dde-f598-055b-e8b1-c374acbdeec9', 'Xenial favor to Jews leads Felix to leave Paul imprisoned', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b96cf260-db10-3b82-05ec-53c55a282eee', 'chapter', 'ACT.25', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'NEW GOVERNOR HEARS PAUL''S APPEAL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b17f64cb-0730-fdb7-f9c6-05531ee359c1', 'verse', 'ACT.25.1', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'New governor Festus arrives in province', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b199263f-e089-aa32-f772-de8fb387d958', 'verse', 'ACT.25.2', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Early he travels from Caesarea up to Jerusalem', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2b177082-0dbc-5613-4dd1-4934a5951352', 'verse', 'ACT.25.3', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Whole Jewish leadership states its case against Paul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6bc9502e-0a78-f1aa-1ace-d7bb73a6bdd4', 'verse', 'ACT.25.4', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Grant us a favor they ask planning an ambush', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5cbdce06-95b2-4de0-a569-e98c61deec63', 'verse', 'ACT.25.5', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Objects that Paul must stay guarded in Caesarea', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('72428882-1379-da60-1b51-9d0e5d003ea5', 'verse', 'ACT.25.6', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Visits there soon and summons Jewish accusers down', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1426fcc1-a155-f918-dd0b-dca5bc389036', 'verse', 'ACT.25.7', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Entering the tribunal Festus has Paul brought in', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('21151217-3be9-5b02-766d-71c1eb80db87', 'verse', 'ACT.25.8', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Raging Jews hurl many serious yet unproved charges', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f02a22b1-05bb-d50c-58d0-bfdd7fc1d5f2', 'verse', 'ACT.25.9', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Not guilty Paul claims to law temple or Caesar', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('75ee8cf1-6afd-4b6e-5df3-98accfe233ff', 'verse', 'ACT.25.10', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Offering to please Jews Festus asks about Jerusalem trial', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('02d4fea2-3324-e9e8-f30a-a8c896a287b7', 'verse', 'ACT.25.11', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Refuses; Paul insists on Caesar''s court alone', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b297ede0-6a27-34d6-b4d1-0bc5dc671c0f', 'verse', 'ACT.25.12', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Holding to his appeal Festus consults his council', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a571c4fb-64ff-29ec-1535-7df236fbab86', 'verse', 'ACT.25.13', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'End decision is to send Paul to Caesar', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8452ba5b-ea4f-5105-f493-ca6b6a890a15', 'verse', 'ACT.25.14', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'After some days Agrippa and Bernice visit Festus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e52fffc8-7767-3a1e-9db1-5a37f0d5b361', 'verse', 'ACT.25.15', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Report of Paul''s case is laid before the king', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('68268182-e0d2-de6a-56a0-ca15fa994c6b', 'verse', 'ACT.25.16', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Says Jerusalem Jews demanded he should not live', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ded79aec-ab42-a6da-10a7-a835cf943768', 'verse', 'ACT.25.17', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Proclaims Roman custom requires a fair hearing first', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0dd89fdd-7667-c10e-e6e1-edeeea2b001b', 'verse', 'ACT.25.18', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'At once when they came he convened the court', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ecc20a0b-586e-65da-6b83-dc2ea452081b', 'verse', 'ACT.25.19', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Unexpectedly they raised only religious disputes about Jesus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('88c6d100-d1c3-e807-cbad-73a4707d521f', 'verse', 'ACT.25.20', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Living again is what Paul keeps asserting', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ead9cd33-b2b6-06f6-d6fa-22cdf2b75128', 'verse', 'ACT.25.21', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Still perplexed he had asked about Jerusalem judgment', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fbe85df2-83b4-908a-fa1d-c78781fde503', 'verse', 'ACT.25.22', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Appeal to the emperor means Paul remains in custody', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e73a87d0-c7f9-9fca-0235-68f52c3516eb', 'verse', 'ACT.25.23', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Pleased, Agrippa says he also wants to hear Paul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5ab78e3f-0b47-3848-4d1d-33f18db4dbda', 'verse', 'ACT.25.24', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Procession with great pomp brings Agrippa and Bernice', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('59dd838e-c018-705d-08a1-a63accb6d9bc', 'verse', 'ACT.25.25', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Emphasizing Jewish outcry Festus explains the prisoner''s case', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fd6d8da1-e269-349d-e0c1-7373ec56c14f', 'verse', 'ACT.25.26', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Admits he finds nothing worthy of death yet must send him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b808d449-8cfd-b109-6ea2-238da15fa7c4', 'verse', 'ACT.25.27', 'b96cf260-db10-3b82-05ec-53c55a282eee', 'Lacking clear charges he hopes Agrippa will help him write', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2fe566be-8938-4944-9394-efafaf63a48b', 'chapter', 'ACT.26', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'EXTENDED WITNESS BEFORE KING AGRIPPA', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3fdfadc3-ce04-b072-1946-566d40369e05', 'verse', 'ACT.26.1', '2fe566be-8938-4944-9394-efafaf63a48b', 'Extended hand, Paul begins his defense', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a21fa6a8-6ad7-fcc6-e9bc-438ac8c1e88c', 'verse', 'ACT.26.2', '2fe566be-8938-4944-9394-efafaf63a48b', 'Xultant, he says he is happy to answer', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9aaece76-279d-4d5b-0f98-40653dbf97c1', 'verse', 'ACT.26.3', '2fe566be-8938-4944-9394-efafaf63a48b', 'Thorough knowledge of Jewish customs in Agrippa', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8162945b-a890-beb9-b904-06e95143787c', 'verse', 'ACT.26.4', '2fe566be-8938-4944-9394-efafaf63a48b', 'Early life among Jews in Jerusalem recounted', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f42a245b-bd33-21f0-288f-4c7703cd591a', 'verse', 'ACT.26.5', '2fe566be-8938-4944-9394-efafaf63a48b', 'Noted as strict Pharisee from the beginning', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('81c7fc98-f705-3e92-4ee5-6632dd633ef5', 'verse', 'ACT.26.6', '2fe566be-8938-4944-9394-efafaf63a48b', 'Defending hope of God''s promise to the fathers', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('99033b2b-d74c-b3b6-5f33-749728fc1eb6', 'verse', 'ACT.26.7', '2fe566be-8938-4944-9394-efafaf63a48b', 'Entire twelve tribes hope to attain this promise', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('11f77d59-522f-2670-cfc8-5ffb949cea4a', 'verse', 'ACT.26.8', '2fe566be-8938-4944-9394-efafaf63a48b', 'Doubt why God raising the dead seems incredible', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('922b458d-21f3-f8f0-9146-5f6943bed983', 'verse', 'ACT.26.9', '2fe566be-8938-4944-9394-efafaf63a48b', 'Was once convinced he must oppose Jesus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b9562888-fc79-ddfc-9846-e99d6bd8c48f', 'verse', 'ACT.26.10', '2fe566be-8938-4944-9394-efafaf63a48b', 'Imprisoned many saints and cast votes against them', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('72fa8c0d-397a-2328-96d1-a92548f0a030', 'verse', 'ACT.26.11', '2fe566be-8938-4944-9394-efafaf63a48b', 'Tortured believers, forcing blasphemy, persecuting afar', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fb6ddd02-ca20-4849-e194-8a2875c8a52d', 'verse', 'ACT.26.12', '2fe566be-8938-4944-9394-efafaf63a48b', 'Near Damascus he traveled with authority to arrest', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('87d7644e-2feb-2dc1-4a08-0943f41a13d7', 'verse', 'ACT.26.13', '2fe566be-8938-4944-9394-efafaf63a48b', 'Extra-bright heavenly light surrounds them at midday', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('355aa9ca-e57a-70fd-772a-7bc67145d97b', 'verse', 'ACT.26.14', '2fe566be-8938-4944-9394-efafaf63a48b', 'Spoken voice asks why Saul persecutes and resists goads', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b46c7b52-e295-a0a9-72f1-18492558ca4e', 'verse', 'ACT.26.15', '2fe566be-8938-4944-9394-efafaf63a48b', 'Saul hears, I am Jesus whom you are persecuting', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d3fa854f-0394-4f44-f535-46b79c2f8a19', 'verse', 'ACT.26.16', '2fe566be-8938-4944-9394-efafaf63a48b', 'Bidden to rise as servant and witness of vision', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('92bd2f7f-5723-baaf-1184-0e2c0a73bdee', 'verse', 'ACT.26.17', '2fe566be-8938-4944-9394-efafaf63a48b', 'Escorted by God, sent to Jews and Gentiles', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('57011bd9-7bb0-ec96-d179-0361f7f01bba', 'verse', 'ACT.26.18', '2fe566be-8938-4944-9394-efafaf63a48b', 'From darkness to light their eyes must be opened', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d2cc7b11-a445-4cfd-ed9d-165f3fa91905', 'verse', 'ACT.26.19', '2fe566be-8938-4944-9394-efafaf63a48b', 'Obedient to vision, he preached first in Damascus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('55cfe7b6-129d-a241-e344-682ce3496c43', 'verse', 'ACT.26.20', '2fe566be-8938-4944-9394-efafaf63a48b', 'Repentance and deeds befitting repentance proclaimed everywhere', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9ca851f8-c1d6-bc7c-1d60-bc3e20110dbe', 'verse', 'ACT.26.21', '2fe566be-8938-4944-9394-efafaf63a48b', 'Enraged Jews seized him in the temple to kill', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c0000f0f-4e29-370b-065b-837223aa8c52', 'verse', 'ACT.26.22', '2fe566be-8938-4944-9394-efafaf63a48b', 'Kept alive by God to testify to small and great', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d37658fb-5d5f-5022-acfa-4784e80b5e96', 'verse', 'ACT.26.23', '2fe566be-8938-4944-9394-efafaf63a48b', 'In line with Moses and prophets that Christ would suffer and rise', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b5657ac6-109f-f279-b36e-48218124305f', 'verse', 'ACT.26.24', '2fe566be-8938-4944-9394-efafaf63a48b', 'Noisy interruption as Festus cries Paul is mad', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6d7fdca9-8b65-5ad5-9809-484110d7c0d9', 'verse', 'ACT.26.25', '2fe566be-8938-4944-9394-efafaf63a48b', 'Gently Paul insists his words are true and reasonable', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('04d0bed6-f0e8-2953-0fce-0a261bf224f9', 'verse', 'ACT.26.26', '2fe566be-8938-4944-9394-efafaf63a48b', 'Agrippa knows these events were not done in a corner', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f9048ec8-8552-cf26-90ce-ba882325cc12', 'verse', 'ACT.26.27', '2fe566be-8938-4944-9394-efafaf63a48b', 'Gospel-believing question pressed, Paul says he knows Agrippa believes prophets', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('753b9c82-5b40-dae3-9cc8-4c31d2b08bf2', 'verse', 'ACT.26.28', '2fe566be-8938-4944-9394-efafaf63a48b', 'Reply from Agrippa, Almost you persuade me to be Christian', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c94ec47f-fce1-7b5c-704a-bd1486ec4d12', 'verse', 'ACT.26.29', '2fe566be-8938-4944-9394-efafaf63a48b', 'If only all hearers might become as I am except these chains', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('83c8ee3f-a97a-52a3-da3c-eb95becce397', 'verse', 'ACT.26.30', '2fe566be-8938-4944-9394-efafaf63a48b', 'Persons present-the king, governor, Bernice-rise and withdraw', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b1f2b123-358f-9a75-f5ec-fd94a5a738fa', 'verse', 'ACT.26.31', '2fe566be-8938-4944-9394-efafaf63a48b', 'Privately they agree he has done nothing worthy of death or bonds', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('59a80080-8aca-84d5-a072-c99ee1620e60', 'verse', 'ACT.26.32', '2fe566be-8938-4944-9394-efafaf63a48b', 'Appeal to Caesar alone has kept him from release', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e2e9fafa-9df6-63ae-c909-faff6151bfde', 'chapter', 'ACT.27', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'STRANDED ON MALTA AFTER SHIPWRECK ON THE WAY TO ITALY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4c002f78-1c7d-30c6-6aa3-65be7715003a', 'verse', 'ACT.27.1', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Sailing for Italy under centurion Julius', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3e036054-524b-7538-806b-8c1424e3b35d', 'verse', 'ACT.27.2', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Taken with other prisoners aboard an Adramyttium ship', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2a7c1c2e-cd73-0a6a-9fab-bc5d05709410', 'verse', 'ACT.27.3', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Reaching Sidon where Julius allows Paul to visit friends', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b669ca5d-c973-a7e7-9848-8a6b67322264', 'verse', 'ACT.27.4', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Against the wind they pass under the lee of Cyprus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5b954b52-7ec3-07ec-0756-e0f7ac2028bf', 'verse', 'ACT.27.5', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Navigating off Cilicia and Pamphylia they arrive at Myra', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c656ae32-9b11-7f57-1cf9-82fbd5b19a1a', 'verse', 'ACT.27.6', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Directed onto an Alexandrian grain ship bound for Italy', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('54348e1f-6786-d2cc-fc71-2eb40884fb36', 'verse', 'ACT.27.7', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Enduring many slow days they scarcely reach Cnidus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6f4cd94b-e105-8725-a72f-fd095613dd67', 'verse', 'ACT.27.8', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Driven along under Crete they come with difficulty to Fair Havens', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('421092a7-0d7c-42b7-ec37-f72fb352e3e1', 'verse', 'ACT.27.9', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Over time sailing becomes dangerous since the Fast is already past', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('77a937f2-5538-6b21-d282-5fb6f1c48c52', 'verse', 'ACT.27.10', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Now Paul warns of impending damage and great loss', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f4a9627c-cfe9-141a-9feb-e475fe254ab5', 'verse', 'ACT.27.11', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Master and shipowner persuade the centurion instead of Paul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e7fe3d06-b701-6736-4781-c46c76b292b1', 'verse', 'ACT.27.12', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Agreed that they should try to reach Phoenix to winter there', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('364a9721-93cf-7138-1ab5-0506e73afe70', 'verse', 'ACT.27.13', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Light south wind convinces them to sail close along Crete', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fe3de146-013c-be3c-55e9-98c8fe4e8202', 'verse', 'ACT.27.14', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Tempestuous northeaster suddenly rushes down from the island', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('06d422cd-eefb-80e3-6a84-4de922092529', 'verse', 'ACT.27.15', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'All control lost they let the ship be driven before the gale', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b5d3c287-6779-c20f-cfe7-cc7b1ee550ba', 'verse', 'ACT.27.16', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Around the little island Cauda they barely secure the lifeboat', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('609e4970-bb5f-f012-484b-681f34aef48c', 'verse', 'ACT.27.17', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Fastening cables under the hull they fear running aground on Syrtis', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7c7a8d4a-8e64-b451-4bdd-6b37669da2e3', 'verse', 'ACT.27.18', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Tossed violently they lower the gear and are driven along', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d32ac6aa-3701-377f-e644-89fdefc9d34d', 'verse', 'ACT.27.19', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Exhausted, they throw the ship''s tackle overboard with their hands', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('420fbdef-95e1-ef1c-12a0-4b8ace13b70c', 'verse', 'ACT.27.20', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Repeated days without sun or stars rob them of hope of rescue', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4cfbf4c8-8a6b-630b-c97a-9d9dab9d31b5', 'verse', 'ACT.27.21', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Starving for long, they hear Paul say they should have listened', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0a909f7a-52f3-94de-e59d-035c8336ff5e', 'verse', 'ACT.27.22', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'However he now urges courage for no life will be lost', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9078b589-76c5-12bf-35be-ec53a847919e', 'verse', 'ACT.27.23', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'In the night an angel of the God he serves stands beside him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('687cf19c-2dae-b701-a009-eb46236e43a0', 'verse', 'ACT.27.24', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Promised that he must stand before Caesar and all with him be spared', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('660ba43d-78e2-b4a0-cb65-7a35c93861a1', 'verse', 'ACT.27.25', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'With firm faith he declares it will happen just as God told him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e53bd6f0-28ef-ba3a-4358-6092e6226760', 'verse', 'ACT.27.26', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Required still is that they run aground on some island', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f844719f-97db-6f11-7655-388a4ea5a178', 'verse', 'ACT.27.27', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Exactly fourteen nights later sailors sense land as they are driven', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b95ea46e-ec8c-5f25-7d7c-9bc945c433ac', 'verse', 'ACT.27.28', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Casting the lead they find the water growing shallower', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('25744684-beae-b342-f8dd-635498799d94', 'verse', 'ACT.27.29', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Keenly afraid of reefs they drop four anchors and pray for day', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('960c6126-3a50-262c-946a-67b4ea9aa3bf', 'verse', 'ACT.27.30', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Operating deceitfully sailors lower the boat pretending to set anchors', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('64dee0f9-12e9-37d7-6bcc-1bb04057d509', 'verse', 'ACT.27.31', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Not saved unless these men stay in the ship Paul warns the centurion', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4b3a5ced-7fb2-dba9-e257-2c66efe4adda', 'verse', 'ACT.27.32', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Then soldiers cut away the ropes of the boat and let it fall', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('69130e68-cb69-910d-c0df-afd2c499fc1b', 'verse', 'ACT.27.33', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Hungry crew are urged by Paul to take food for their survival', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0b71deee-df4b-a44c-acff-b94042d3e7ed', 'verse', 'ACT.27.34', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Encouraging them he says not a hair from any head will perish', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8c8ad478-5cfa-f257-13d7-d602ee92dc2e', 'verse', 'ACT.27.35', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'With thanks to God he breaks bread and begins to eat', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('79906b25-0a3d-3d79-956b-4d3ac6ee9753', 'verse', 'ACT.27.36', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'All become encouraged and themselves also take food', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('506622dd-9531-ce13-3f19-ba72d6e0d9b1', 'verse', 'ACT.27.37', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Yielding the count they number in all two hundred seventy six souls', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('627b5861-122f-7b58-d7ab-8266c1bafdbc', 'verse', 'ACT.27.38', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Then when filled they lighten the ship by throwing wheat into the sea', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f775bb1f-3ef4-31ba-48be-60fa78c0204e', 'verse', 'ACT.27.39', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'On daybreak they do not recognize the land but notice a bay with a beach', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('add025bf-bf54-fbff-f497-a35526dc4d77', 'verse', 'ACT.27.40', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Intending if possible they plan to run the ship ashore there', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a31a2875-6a3c-e950-866e-706e2445d95f', 'verse', 'ACT.27.41', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Though they loose anchors and rudders and hoist foresail, they strike a sandbar', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6ee790bf-7d83-6972-71e5-0701ab02673e', 'verse', 'ACT.27.42', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'All at once the bow sticks fast while the stern is broken by surf', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b7d1da84-295c-4db9-b195-f12a80807931', 'verse', 'ACT.27.43', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Looking to prevent escape the soldiers plan to kill the prisoners', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1ebc9acf-e9bf-4ab1-1d5e-7c3fe26b94e5', 'verse', 'ACT.27.44', 'e2e9fafa-9df6-63ae-c909-faff6151bfde', 'Yet wanting to spare Paul the centurion stops them and all reach land safely on boards and pieces of ship', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'chapter', 'ACT.28', 'ca3ca70c-7b58-2926-a452-8df312ea984b', 'SICK HEALED AND PAUL PREACHES IN ROME', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('fdc54a7c-6b31-88f6-8992-876f5125bf33', 'verse', 'ACT.28.1', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Shipwreck survivors learn the island is Malta', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('99bedad6-88b2-a561-cee5-f234b4f8d122', 'verse', 'ACT.28.2', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Islanders show unusual kindness and light a fire', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dbfde116-e3d4-e504-8710-7f6a7bc76969', 'verse', 'ACT.28.3', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Collecting sticks Paul is bitten by a viper', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('42eff321-14fc-6567-9706-0a6ccbac347c', 'verse', 'ACT.28.4', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Knowing justice they expect him to die', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0a68ad3d-b6b0-ce71-f725-52aae30edbc6', 'verse', 'ACT.28.5', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'He simply shakes the snake into the fire', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c132313c-9341-9d67-c246-859564711a64', 'verse', 'ACT.28.6', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Expecting swelling they watch but see no harm', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('82e8456c-f0e2-e9ec-3f70-ecdd4c456655', 'verse', 'ACT.28.7', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'At the estate of Publius they are welcomed', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c419ec07-727b-ffa6-9500-55a6da33ce3f', 'verse', 'ACT.28.8', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Laid-up father of Publius is healed by Paul', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1ad16bf1-e234-8b9a-3749-019eb38f616b', 'verse', 'ACT.28.9', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Everyone sick on the island comes and is cured', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e806c917-a558-8774-a2a1-430ad40ba22e', 'verse', 'ACT.28.10', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Departing they receive many honors and supplies', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('90942b0e-a487-99ae-8685-0ee94c767f1b', 'verse', 'ACT.28.11', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Alexandrian ship with Twin Gods carries them on', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('91050e35-b28c-112d-3437-defbaec8ccca', 'verse', 'ACT.28.12', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Navigating to Syracuse they stay three days', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('88f04c99-5b4d-5ffe-4c21-3910f63bb9d9', 'verse', 'ACT.28.13', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Driven by fair south wind they reach Rhegium then Puteoli', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('51730038-3aa7-2b2b-e045-7b2a47c19818', 'verse', 'ACT.28.14', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Paul finds brothers and stays with them seven days', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b664771f-6a94-54fd-9be4-35b4af18d1fe', 'verse', 'ACT.28.15', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'At the Forum of Appius and Three Taverns friends meet him', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('90250201-2c3a-f11d-cbb0-ab3db2e5fc3f', 'verse', 'ACT.28.16', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Under guard Paul is allowed to live by himself in Rome', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9a7904ef-806a-e87a-f25b-f549667a2c22', 'verse', 'ACT.28.17', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Leaders of the Jews are summoned after three days', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('311be33b-912f-69bd-920f-67b646105a47', 'verse', 'ACT.28.18', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Paul explains charges and his hope in Israel''s promise', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3caf5f38-1808-19cd-e597-cbc5931d3b66', 'verse', 'ACT.28.19', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Reports from Judea about him have not been received', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('eb505512-9dc8-bcc1-523d-31d95b313ebb', 'verse', 'ACT.28.20', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Eager to hear, they arrange a day to listen fully', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7136ecab-1a14-5ffd-4d08-a2ec337b4454', 'verse', 'ACT.28.21', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'All day he argues from Law and Prophets about Jesus', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('664fb087-e320-1a1b-7f37-2d7720a0cedc', 'verse', 'ACT.28.22', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Conflicting responses arise; some believe and some refuse', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('24e21659-c069-641f-67af-e17d220a963a', 'verse', 'ACT.28.23', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Hard-hearted text from Isaiah is quoted about dull hearing', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('77b7b379-9943-85d0-4f91-c1549d4bf734', 'verse', 'ACT.28.24', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Ending his message he declares God''s salvation is sent to Gentiles', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e8c68160-71bb-4053-ccb0-a3f20cbbeb83', 'verse', 'ACT.28.25', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Spoken word concludes that they will listen', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2d4557c8-0bdd-b696-a915-a23c073ce7c5', 'verse', 'ACT.28.26', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'In his own rented house he stays two full years', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d3df0280-b07d-82ed-40be-a259004bc085', 'verse', 'ACT.28.27', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'No one forbidding him he preaches the kingdom of God', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('74d974d6-432e-95e2-622f-95c9601f4beb', 'verse', 'ACT.28.28', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Rome hears the things which concern the Lord Jesus Christ', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('df314480-7153-9cc8-7e57-8953eda9310c', 'verse', 'ACT.28.29', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Onwards the gospel goes unhindered', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ba33a00f-0adf-c184-0bd4-20abbdbecae9', 'verse', 'ACT.28.30', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'Mission accomplished Paul teaches with all confidence', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('60cad19f-1e63-fe22-a133-db04e7ac8f4f', 'verse', 'ACT.28.31', '54e0641a-1760-33e5-0bb9-6b691c1fbfa2', 'End of the book of Acts', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'book', 'ROM', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'SINNERS JUSTIFIED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5fe5b5d1-39ec-f573-9af2-4fccdd73a921', 'chapter', 'ROM.1', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'SINFUL HUMANITY EXCHANGE GOD IDOL BAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3649d7cd-7c0c-64d4-3622-3bf20ed3846b', 'chapter', 'ROM.2', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'IMPARTIAL JUDGMENT ON HYPOCRITES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b1bad101-85d4-a512-4b29-70b28f123ed9', 'chapter', 'ROM.3', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'NO ONE IS RIGHTEOUS AS ALL HAVE SINNED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('10a92cc2-5c46-202a-eb14-75215eef3bb6', 'chapter', 'ROM.4', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'NOT BY WORKS BUT BY FAITH ALONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8016b8a7-4a3a-4962-3af6-ccf98ef9cfea', 'chapter', 'ROM.5', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'ENTER PEACE HOPE GOD GAVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9d22cf9d-fc8f-567c-68c3-ebdae37115be', 'chapter', 'ROM.6', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'REALLY DEAD TO SIN AND ALIVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ec61e4a2-311c-35fa-b7ec-c4b52167e3c5', 'chapter', 'ROM.7', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'STRUGGLE WITH SIN IN THE FLESH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5b09a94d-a753-08c2-4d7c-8648a1bdaaa6', 'chapter', 'ROM.8', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'JESUS SPIRIT LIFE GIVES FREEDOM AND LOVE OF GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3b017553-ed25-1b65-2b9b-311d91de1948', 'chapter', 'ROM.9', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'UNDERSTAND GODS SOVEREIGN CHOICE PLAN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a8ed983d-8b6e-f2c5-233b-45c5ef460eaa', 'chapter', 'ROM.10', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'SALVATION IS NEAR YOU ALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ed443ff2-e01c-f7f7-2d59-1c4532230496', 'chapter', 'ROM.11', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'THE REMNANT CHOSEN AND GENTILES IN GRAFTED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('84b6a2ae-cc60-36c8-62a4-23bad195a8e8', 'chapter', 'ROM.12', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'LIVING SACRIFICE HOLY HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('557d1bfb-c832-2c4a-0d43-cfa71a134f5d', 'chapter', 'ROM.13', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'FILL A LAW OF LOVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('102df3ae-d1a9-80ec-1b58-fa98ce7c05af', 'chapter', 'ROM.14', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'I DO NOT JUDGE A WEAK BROTHER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('236b785d-7314-f2df-4b6f-e57d785d1aa2', 'chapter', 'ROM.15', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'EVERY GENTILE AND JEW PRAISE LORD ALOUD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('12101845-5c3b-0914-7438-37c7d7904b20', 'chapter', 'ROM.16', '20cd24f9-93b9-49a9-2f7a-e2d3a2e37fe5', 'DOXOLOGY GREETINGS SAINTS AMEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b18dae4b-0e42-0609-a2cb-67eb107d2848', 'book', '1CO', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'EVERYTHING IN LOVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c172a800-4cce-86af-0828-cf7d575f12d2', 'chapter', '1CO.1', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'APPEAL FOR UNITY IN THE NAME OF CHRIST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e5a91695-c95e-0a08-2ac8-e92e3b324b1f', 'chapter', '1CO.2', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'WISDOM FROM SPIRIT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('77f56c2e-33dc-b9bb-5802-f63f45a43fb3', 'chapter', '1CO.3', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'EXACT FOUNDATION IS CHRIST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d0eb4ba1-91ac-763f-5b15-2a5f56a59bb4', 'chapter', '1CO.4', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'COURSE OF APOSTLE HERESY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('69a2f797-4a9b-2d51-2400-ffccd66bb2c4', 'chapter', '1CO.5', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'YOU PURGE YEAST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e9f3abeb-1a7b-4f15-a5d0-5905b6c8a945', 'chapter', '1CO.6', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'THE BODY IS GODS TEMPLES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0e3d2752-14ee-9af2-46e2-871966138919', 'chapter', '1CO.7', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'HOLY UNMARRIED WOMAN CARES FOR THE LORDS THINGS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4f4a854e-194e-b7f5-6650-980dd7c2edb9', 'chapter', '1CO.8', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'IDOL MEAT IS BAD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a4264bb1-cf65-4606-fa12-a0117e1854b1', 'chapter', '1CO.9', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'NEED SELF CONTROL TO WIN THE RACE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e2ab3924-2be7-d0a5-8e15-3d46e652d0f8', 'chapter', '1CO.10', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'WARNING AGAINST IDOLATRY HISTORY FACT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0a183495-61c8-fcdd-0a61-c03c29404381', 'chapter', '1CO.11', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'HEAD COVERINGS AND LORDS SUPPER ORDERED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6ee96c65-0e8b-8b64-bf16-457f96daf658', 'chapter', '1CO.12', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'NEED ONE BODY WITH MANY MEMBERS PARTS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a96a694a-95e8-ca00-bb33-611a2dc736a2', 'chapter', '1CO.13', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'LOVE IS PATIENT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('38bb1ef8-2bdc-fcfd-73a9-a58b1222d79c', 'chapter', '1CO.14', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'PROPHECY TONGUES AND ORDER IN WORSHIP HERE DONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f4892a3c-7c0a-e6a0-43ed-dd13643257c4', 'chapter', '1CO.15', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'RESURRECTION OF CHRIST AND THE DEAD AND THE BODY AND VICTORY WON GREAT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5212064a-e49a-06dc-81b0-1f43ccd3d715', 'chapter', '1CO.16', 'b18dae4b-0e42-0609-a2cb-67eb107d2848', 'EVERYTHING TO BE DONE IN LOVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('80f7e7c8-1493-116b-125e-7f47576b3976', 'book', '2CO', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'NOTHING TO GAIN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d10bf133-1a9f-f66e-50fb-b45c34a07d16', 'chapter', '2CO.1', '80f7e7c8-1493-116b-125e-7f47576b3976', 'COMFORT IN TROUBLE AND PAINS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e76bb1fc-d676-23bd-c303-0d41387f0b61', 'chapter', '2CO.2', '80f7e7c8-1493-116b-125e-7f47576b3976', 'OFFENDERS FORGIVEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('98fac60e-6397-798a-5a09-6e7d35705582', 'chapter', '2CO.3', '80f7e7c8-1493-116b-125e-7f47576b3976', 'MINISTER COVENANT HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c215715d-a40f-bff5-8782-1ecf5bff865d', 'chapter', '2CO.4', '80f7e7c8-1493-116b-125e-7f47576b3976', 'TREASURE IN JARS CLAY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d1ef11c6-260a-0b85-43cd-b9f5a2351a3e', 'chapter', '2CO.5', '80f7e7c8-1493-116b-125e-7f47576b3976', 'OUR HEAVENLY DWELLING LO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5c2f7541-618b-c73f-8391-988575761eef', 'chapter', '2CO.6', '80f7e7c8-1493-116b-125e-7f47576b3976', 'SERVANTS OF GOD HARDS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3243a78b-ffea-1e56-39b8-dd0f09f96687', 'chapter', '2CO.7', '80f7e7c8-1493-116b-125e-7f47576b3976', 'GODLY SORROW SAVES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b4d157f4-0d2b-cb0a-13fc-82ca2c2fac2b', 'chapter', '2CO.8', '80f7e7c8-1493-116b-125e-7f47576b3976', 'THE GRACE OF GIVING IS TESTED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6febf70c-2b90-6313-0334-219aa37db44d', 'chapter', '2CO.9', '80f7e7c8-1493-116b-125e-7f47576b3976', 'OFFER GIFT FREELY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8519fcfc-d9fe-6a4d-fa0a-3bea253ade94', 'chapter', '2CO.10', '80f7e7c8-1493-116b-125e-7f47576b3976', 'PAUL DEFEND MINISTRY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b43ad6ca-bed3-b3c9-7ea8-6cc613d7d5b8', 'chapter', '2CO.11', '80f7e7c8-1493-116b-125e-7f47576b3976', 'PAUL AND FALSE APOSTLES SUFFERINGS ASK', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b9453659-90b8-b31b-df5d-c381921a968b', 'chapter', '2CO.12', '80f7e7c8-1493-116b-125e-7f47576b3976', 'VISIONS AND THORN FLESHY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6d6ea901-5801-5f7a-81ac-617cd91d5ab2', 'chapter', '2CO.13', '80f7e7c8-1493-116b-125e-7f47576b3976', 'NOW EXAMINE SELF', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c6d794c8-dc85-dd6d-2461-d2d37bfa2996', 'book', 'GAL', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'THE LAW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('59943c6c-3bf6-0fdc-bc88-e792d9a0b711', 'chapter', 'GAL.1', 'c6d794c8-dc85-dd6d-2461-d2d37bfa2996', 'NO OTHER GOSPEL CALLED GRACE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f201bf28-d40d-27b1-f3b2-f0e1bb9e9805', 'chapter', 'GAL.2', 'c6d794c8-dc85-dd6d-2461-d2d37bfa2996', 'PAUL ACCEPTED APOSTLES S', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e7c44d16-c785-d5f0-0ca5-a5b51aff4c4c', 'chapter', 'GAL.3', 'c6d794c8-dc85-dd6d-2461-d2d37bfa2996', 'FAITH OR OBSERVANCE OF LAWS PASSED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1229bc65-3630-6e0c-5b86-85516b426e76', 'chapter', 'GAL.4', 'c6d794c8-dc85-dd6d-2461-d2d37bfa2996', 'LOOK WE ARE CHILDREN OF THE FREE WOMAN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a7c1864e-fcc5-2019-8203-1ab07d686f4c', 'chapter', 'GAL.5', 'c6d794c8-dc85-dd6d-2461-d2d37bfa2996', 'A FRUIT OF THE SPIRIT IS JOY LOVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9fea9c30-e420-0bd8-1f5d-a2208436ecb7', 'chapter', 'GAL.6', 'c6d794c8-dc85-dd6d-2461-d2d37bfa2996', 'DO GOOD TO ALL PEOPLES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8789443a-ff93-42d9-4f3d-1e3a1a46fe8b', 'book', 'EPH', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'HELMET', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('78310c0c-4985-fcc0-6041-4e7768912dc5', 'chapter', 'EPH.1', '8789443a-ff93-42d9-4f3d-1e3a1a46fe8b', 'HEAD OF THE CHURCH IS CHRIST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('233f5e89-8b0c-709c-a7e4-44b18d974621', 'chapter', 'EPH.2', '8789443a-ff93-42d9-4f3d-1e3a1a46fe8b', 'EPHESIANS SAVED BY A GRACE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('817586f0-17c9-cb9d-4867-5a162a5e30b7', 'chapter', 'EPH.3', '8789443a-ff93-42d9-4f3d-1e3a1a46fe8b', 'LOVE OF CHRIST SURPASSES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e7711878-1bfd-8e78-ed93-5476e6b8ea72', 'chapter', 'EPH.4', '8789443a-ff93-42d9-4f3d-1e3a1a46fe8b', 'MAKE PRAYERS TO GOD AND PUT OFF OLD SELF', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c825ad41-3cb5-0542-781c-25c516655ad1', 'chapter', 'EPH.5', '8789443a-ff93-42d9-4f3d-1e3a1a46fe8b', 'IMITATE GOD AND WALK IN LOVE AS CHILDREN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('44878c0b-de7f-61b0-2ea8-7a64816b1827', 'chapter', 'EPH.6', '8789443a-ff93-42d9-4f3d-1e3a1a46fe8b', 'TRUE ARMOR OF GOD STANDS FIRM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bd299bb4-442e-9773-6058-daa0c2346882', 'book', 'PHP', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'I CAN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('42977e2c-503f-73ca-1601-d4a37f3ee303', 'chapter', 'PHP.1', 'bd299bb4-442e-9773-6058-daa0c2346882', 'I PRAY THAT YOUR LOVE MAY ABOUND MORE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('588aabde-1b64-d01d-6b82-e971c2556fa6', 'chapter', 'PHP.2', 'bd299bb4-442e-9773-6058-daa0c2346882', 'CONTINUE TO WORK OUT YOUR SALVATION', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f30a548f-c9f7-9163-fa62-678b39321888', 'chapter', 'PHP.3', 'bd299bb4-442e-9773-6058-daa0c2346882', 'ALL IS LOSS FOR THE CHRIST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('227dded1-c2d3-0db2-ef12-25656e3c1c81', 'chapter', 'PHP.4', 'bd299bb4-442e-9773-6058-daa0c2346882', 'NOW I CAN DO ALL THINGS IN HIM', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('35373cff-f24a-ad78-387a-01047f97e551', 'book', 'COL', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'SELF', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('42d80b33-96e7-a4ed-71aa-1fe1b6f901a4', 'chapter', 'COL.1', '35373cff-f24a-ad78-387a-01047f97e551', 'SUPREMACY OF CHRIST IS THE GOSPELS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('8974774c-62f4-272d-17a9-c488882f186c', 'chapter', 'COL.2', '35373cff-f24a-ad78-387a-01047f97e551', 'EMPTY PHILOSOPHY IS NOT GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('09b88729-fecd-e4a6-77a1-b211eb61bcec', 'chapter', 'COL.3', '35373cff-f24a-ad78-387a-01047f97e551', 'LOOK AT HEAVENLY THINGS ABOVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b3dbec30-2d17-17df-4109-cbd4d72da91b', 'chapter', 'COL.4', '35373cff-f24a-ad78-387a-01047f97e551', 'FINAL GREETINGS PAUL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6a3c5a86-350d-f383-6dbc-4d7cbe5329c3', 'book', '1TH', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'STAND', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f6f8bfbf-ed88-f57c-7e98-42f45edc34f9', 'chapter', '1TH.1', '6a3c5a86-350d-f383-6dbc-4d7cbe5329c3', 'SAVED TO GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ccfe6eb9-ac94-6d84-8031-4783499ebe80', 'chapter', '1TH.2', '6a3c5a86-350d-f383-6dbc-4d7cbe5329c3', 'PAUL MINISTRY TO THEM LO', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('095e640a-aaec-53d0-042e-002e4855fadf', 'chapter', '1TH.3', '6a3c5a86-350d-f383-6dbc-4d7cbe5329c3', 'AND STAND IN GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4e821446-15c9-4faf-f6cb-c5fe9fd6c4a0', 'chapter', '1TH.4', '6a3c5a86-350d-f383-6dbc-4d7cbe5329c3', 'NOW LIVE TO PLEASE GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1b80813e-a372-908d-7ddc-ce607d0daf97', 'chapter', '1TH.5', '6a3c5a86-350d-f383-6dbc-4d7cbe5329c3', 'DAY OF THE LORD COMES LIKE THIEVES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e3e98dda-5528-5e7e-acd2-e01b1ed61ab6', 'book', '2TH', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'PAY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('47371a80-2304-60c6-4680-19dab0b84c4e', 'chapter', '2TH.1', 'e3e98dda-5528-5e7e-acd2-e01b1ed61ab6', 'PERSEVERANCE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('aeacec25-bd89-1aaa-4fc6-c85c573272da', 'chapter', '2TH.2', 'e3e98dda-5528-5e7e-acd2-e01b1ed61ab6', 'A MAN OF LAWLESSNESS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('65cbeb5f-1f3a-6861-27e5-ba779db689f9', 'chapter', '2TH.3', 'e3e98dda-5528-5e7e-acd2-e01b1ed61ab6', 'YOU WORK OR NO EATINGS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2583702a-66f5-e041-74e5-4d2407b6f6dc', 'book', '1TI', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'IN LOVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0cdc31fd-da5d-1f2f-6a46-f48646b3c929', 'chapter', '1TI.1', '2583702a-66f5-e041-74e5-4d2407b6f6dc', 'I AM THE WORST OF SINNERS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('47f389ee-cf67-930e-af5c-13259750cca6', 'chapter', '1TI.2', '2583702a-66f5-e041-74e5-4d2407b6f6dc', 'NOW PRAY FOR KINGS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('bf314e6b-d93d-b22e-f089-cf72c7a3e9d1', 'chapter', '1TI.3', '2583702a-66f5-e041-74e5-4d2407b6f6dc', 'LIST FOR OVERSEERS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d4e8940c-a8ff-211b-4eaf-c38d9d7aaa1a', 'chapter', '1TI.4', '2583702a-66f5-e041-74e5-4d2407b6f6dc', 'ORDER IN GODLINESS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('70ad95e2-84c9-f154-8974-732b38e4e162', 'chapter', '1TI.5', '2583702a-66f5-e041-74e5-4d2407b6f6dc', 'VALUE WIDOWS AND ELDERS WELLS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3aa4a383-3908-d040-c437-802948317a13', 'chapter', '1TI.6', '2583702a-66f5-e041-74e5-4d2407b6f6dc', 'EXHORT MEN TO A GODLINESS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a20bf6a2-814f-9a07-d291-2d2e3d8ce2c4', 'book', '2TI', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'RACE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('13243198-3602-e396-afcf-52e08e7a2a3e', 'chapter', '2TI.1', 'a20bf6a2-814f-9a07-d291-2d2e3d8ce2c4', 'REKINDLE A GIFT OF GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('69753951-cf32-c8ff-84d8-787fb134fbe0', 'chapter', '2TI.2', 'a20bf6a2-814f-9a07-d291-2d2e3d8ce2c4', 'A GOOD SOLDIER FOR JESUS CHRIST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3778c4ec-d4ae-7b8c-d045-b403470559d3', 'chapter', '2TI.3', 'a20bf6a2-814f-9a07-d291-2d2e3d8ce2c4', 'CONTINUE IN THE WORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0044f4b1-ca06-2e70-a3eb-972b4bf26b81', 'chapter', '2TI.4', 'a20bf6a2-814f-9a07-d291-2d2e3d8ce2c4', 'ENDURE AND PREACH THE WORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('884ee770-aa88-d563-9077-65215423b9cb', 'book', 'TIT', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'IGW', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('6f822aeb-8de6-4e4f-55bd-c2f26827f97c', 'chapter', 'TIT.1', '884ee770-aa88-d563-9077-65215423b9cb', 'INSTRUCT THE ELDER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('817be446-e44b-2981-37e1-e4af14b188b4', 'chapter', 'TIT.2', '884ee770-aa88-d563-9077-65215423b9cb', 'GO TEACH OLDER ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7558e46b-54f6-5f57-6f83-6fa90147b1ba', 'chapter', 'TIT.3', '884ee770-aa88-d563-9077-65215423b9cb', 'WARN DIVISIVE ONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('822bd899-fbb2-6f9b-8f30-9d14dc5cc413', 'book', 'PHM', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e2ebf673-9bb2-ab24-8ff7-03c16a24fdf7', 'chapter', 'PHM.1', '822bd899-fbb2-6f9b-8f30-9d14dc5cc413', 'TAKE BACK ONESIMUS AS BROTHER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'book', 'HEB', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'THE HIGH PRIEST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f11efdb5-2704-41e9-c39f-450d6c45ac2b', 'chapter', 'HEB.1', 'f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'THE SON RADIANCE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('29db21f1-b47a-c4ad-b763-bcc4da27ee81', 'chapter', 'HEB.2', 'f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'HE TASTED DEATH OF MEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4b2384fd-9fcd-1837-4245-d939ab8dece9', 'chapter', 'HEB.3', 'f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'ENCOURAGE ONE ANOTHER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d24c30c0-aad1-3f34-f55d-9c985be430fa', 'chapter', 'HEB.4', 'f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'HEAR HIS VOICE THEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ddd5a25f-a444-f4f2-703b-3c681b558be6', 'chapter', 'HEB.5', 'f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'IMMATURE IN WORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a97a3a75-6468-12c4-d566-7b90514f5969', 'chapter', 'HEB.6', 'f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'GO ON TO MATURITY IN LORD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ed3a4dc6-94c1-cb22-f9d2-546ceb699c61', 'chapter', 'HEB.7', 'f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'HE IS GUARANTEE OF BETTER PROMISE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cd07a598-0c13-b362-7ca7-39516da2f4c8', 'chapter', 'HEB.8', 'f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'PUT LAWS IN MIND', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e0425444-5214-afa3-70a5-123a2387015b', 'chapter', 'HEB.9', 'f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'REDEMPTION BY THE BLOOD OF CHRIST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f2d01497-4134-9f4f-64b5-35bcccd6e5cf', 'chapter', 'HEB.10', 'f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'IF WE SIN WILLFULLY THERE IS NO MORE SACRIFICES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d854c3c1-ffb5-2337-7909-a280d22b2164', 'chapter', 'HEB.11', 'f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'EXAMPLES OF THOSE WHO LIVED BY FAITH IN GOD ALONE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b857ecec-de48-4fc0-2af1-a4cb2e50fcba', 'chapter', 'HEB.12', 'f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'SURROUNDED BY A CLOUD OF WITNESSES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5ef6fb6c-62c5-8173-56f5-1cef290bd204', 'chapter', 'HEB.13', 'f30fae18-fc47-7fc5-d59f-25c063ec4d26', 'THE SAME YESTERDAY AND ALWAYS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d712c584-9f92-fb51-e1cf-5bee660eb3b9', 'book', 'JAS', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'OUGHT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('11dcd1bf-f136-d56f-03b0-f9dcf616c7e8', 'chapter', 'JAS.1', 'd712c584-9f92-fb51-e1cf-5bee660eb3b9', 'OUR TRIALS CREATE PERSEVERANCE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ccefd1be-4adb-6e0d-d01f-67b8818356f3', 'chapter', 'JAS.2', 'd712c584-9f92-fb51-e1cf-5bee660eb3b9', 'UNDERSTAND FAITH WITHOUT WORKS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e1b52767-d447-af11-775c-8bec71dca7b8', 'chapter', 'JAS.3', 'd712c584-9f92-fb51-e1cf-5bee660eb3b9', 'GET WISDOM FROM ABOVE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d1ac90c1-da91-c850-fd5e-65a69c866def', 'chapter', 'JAS.4', 'd712c584-9f92-fb51-e1cf-5bee660eb3b9', 'HUMBLING OURSELVES', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5fa7d626-67f9-8525-530f-b4701d4250b6', 'chapter', 'JAS.5', 'd712c584-9f92-fb51-e1cf-5bee660eb3b9', 'THE LORD''S COMING IS NEAR', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('042844ad-7f4e-17c3-ff63-7f7611b5c642', 'book', '1PE', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'A CALL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3a7ac9c6-150d-083e-69ce-844aa371a756', 'chapter', '1PE.1', '042844ad-7f4e-17c3-ff63-7f7611b5c642', 'PRAISE FOR LIVING HOPE HOLY HI', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('608397e6-cc20-c0df-4160-b3e7738cfeee', 'chapter', '1PE.2', '042844ad-7f4e-17c3-ff63-7f7611b5c642', 'CORNERSTONE AND A HOLY NATION', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0acc4790-b920-76f5-c2f1-a54d80cce827', 'chapter', '1PE.3', '042844ad-7f4e-17c3-ff63-7f7611b5c642', 'ALWAYS PREPARED TO DEFEND', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('9933340c-5af2-6a1c-e6f9-24578bc8f22b', 'chapter', '1PE.4', '042844ad-7f4e-17c3-ff63-7f7611b5c642', 'LOVE COVERS MULTITUDE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ca391e5f-703f-9a1f-20e0-9d360352335f', 'chapter', '1PE.5', '042844ad-7f4e-17c3-ff63-7f7611b5c642', 'LORD OF ALL GRACE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('14eee025-b600-a58f-7d16-8b83b10f8c39', 'book', '2PE', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'LOT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('e9a2016a-ffd7-75c0-87b4-f0705321c7f7', 'chapter', '2PE.1', '14eee025-b600-a58f-7d16-8b83b10f8c39', 'LIVE GODLY AND ADD VIRTUE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('cb50d3f7-0ca8-0a32-bf18-89dc91e07060', 'chapter', '2PE.2', '14eee025-b600-a58f-7d16-8b83b10f8c39', 'OF FALSE PROPHETS AND SINS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('0cd22315-ea49-9047-a0fb-366e0bbde34b', 'chapter', '2PE.3', '14eee025-b600-a58f-7d16-8b83b10f8c39', 'THIS IS SECOND LETTER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('f989d5db-f32f-107b-2b53-99939dac763e', 'book', '1JN', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'LOVED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('40c660ec-4741-72cf-fda4-14bf60521d48', 'chapter', '1JN.1', 'f989d5db-f32f-107b-2b53-99939dac763e', 'LIGHT IS GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a9133a88-ac44-be11-84c5-56cef6938ca6', 'chapter', '1JN.2', 'f989d5db-f32f-107b-2b53-99939dac763e', 'ONE WHO LOVES BROTHER ABIDES THERE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dc911724-c233-bae3-96eb-821d2771f264', 'chapter', '1JN.3', 'f989d5db-f32f-107b-2b53-99939dac763e', 'VICTORY IN LOVING IN THE DEED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('68178881-fe2d-33f4-dbb3-c04985975252', 'chapter', '1JN.4', 'f989d5db-f32f-107b-2b53-99939dac763e', 'EVERYONE THAT LOVES GOOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3c9ab468-51a1-44b3-9753-07c33bad2ef9', 'chapter', '1JN.5', 'f989d5db-f32f-107b-2b53-99939dac763e', 'DIVINE WITNESS IS TRUTHS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5eb7d8c8-5e8b-8c55-2ce7-e65bc723b68b', 'book', '2JN', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b140e906-d88d-acf6-fb52-a81d4f6a0ff6', 'chapter', '2JN.1', '5eb7d8c8-5e8b-8c55-2ce7-e65bc723b68b', 'OVERJOYED BY IT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('71329215-c979-4112-f101-79ed82f6c183', 'book', '3JN', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('53fa87cc-2275-6086-f3f6-2b5922d7aa61', 'chapter', '3JN.1', '71329215-c979-4112-f101-79ed82f6c183', 'FAITHFUL WORKER', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('394aeacd-4565-61b0-6a81-164c168c227e', 'book', 'JUD', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', '', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4c441516-8f31-37ec-e60b-3ca087faf1ce', 'chapter', 'JUD.1', '394aeacd-4565-61b0-6a81-164c168c227e', 'UNGODLY ARE TO BE JUDGED BY GOD', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'book', 'REV', '5f1bdcb2-1e05-0070-b1f7-1bc0713b406d', 'SECOND COMING IN JUDGMENT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5aa9b9e7-57f6-7668-8afa-290355883510', 'chapter', 'REV.1', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'SEE HIM COMING IN CLOUDS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('87204509-ca72-193d-6307-ae4b85315f13', 'chapter', 'REV.2', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'EPHESUS SMYRNA PERGAMUM THYATIRA', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('72a9d8b0-a763-0d06-fe41-7652133c3306', 'chapter', 'REV.3', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'CALL TO SARDIS AND LAODICE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('82977e72-7f0a-6799-d2b9-4406b856d93e', 'chapter', 'REV.4', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'ONE IS SEATED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('b51015ee-fb1a-cb02-420d-04206c5e50b8', 'chapter', 'REV.5', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'NOT ONE IS WORTHY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3debf0f0-b485-0d6f-d8a5-272d2074c03d', 'chapter', 'REV.6', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'DEATH ON A PALE HORSE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('847ef086-303f-d3b0-8f76-b775629700c8', 'chapter', 'REV.7', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'COUNTLESS STANDING', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('1cc8e13e-e0e0-48b0-9f0a-e3cd94c45738', 'chapter', 'REV.8', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'OPENED SEVENTH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('dfa42214-0a1c-4df8-7954-05e98490913b', 'chapter', 'REV.9', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'MOUNTED TROOPS RELEASED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('17737e38-ccfe-4f12-d98b-61a8ae27eefd', 'chapter', 'REV.10', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'I ATE A SCROLL', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('d9ba0fba-0056-d854-b0f7-5822b50312a8', 'chapter', 'REV.11', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'NATIONS WATCH TWO RISE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('4f4d1226-88ec-dfdc-471e-d833fcfd79b6', 'chapter', 'REV.12', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'GREAT RED DRAGON WAR', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('884d1ae1-5591-69a9-77d3-41f863b82c86', 'chapter', 'REV.13', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'IMAGE OF A FIRST BEAST', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('c5080b17-57df-4af9-ebf7-366d8f9c00bf', 'chapter', 'REV.14', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'NATION, TRIBE, AND TONGUE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ce879fa3-6248-a8da-5547-5975e941dee5', 'chapter', 'REV.15', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'JUDGMENT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('ee8652ef-15f5-65c9-8263-e7214c88fd57', 'chapter', 'REV.16', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'ULTIMATE BOWL POURED OUT', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('377fef48-57ba-2f72-4f2e-c7ced44bffec', 'chapter', 'REV.17', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'DESCRIPTION OF SIGNS', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('3b474607-d51f-74b8-dcba-bfc470a369a0', 'chapter', 'REV.18', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'GREAT BABYLON HAS NOW FALLEN', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('a7ffd506-d4e5-c4ea-2a0f-07d48821750d', 'chapter', 'REV.19', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'MARRIAGE SUPPER; VICTORY', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('7c8f9722-d013-5b0f-d606-abb636f3aafc', 'chapter', 'REV.20', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'EVERYONE''S JUDGED', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('5a7fbf39-2c9a-ac49-e741-82233b22c64a', 'chapter', 'REV.21', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'NEW JERUSALEM PREPARED AS BRIDE', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('923d14cb-6776-939e-ca0b-e958aa8c14dc', 'chapter', 'REV.22', '2160c6bf-f3d8-cb09-fffa-ee613dbba2f8', 'TESTIMONY FOR THE CHURCH', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;

COMMIT;
