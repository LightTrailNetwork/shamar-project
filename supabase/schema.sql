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
