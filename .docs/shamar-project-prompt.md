# The Shamar Project - Complete Development Prompt for Gemini AI IDE

## Project Overview

You are building **The Shamar Project** - a crowd-sourced, hierarchical Bible memorization system using acrostics and mnemonics. "Shamar" is Hebrew meaning "to keep, guard, observe, give heed" and serves as an acronym: **Scripture Hierarchical Acrostic for Memorization And Recall**.

### Core Concept

The project creates a 4-level hierarchical mnemonic system:

1. **Testament Level**: One acrostic per testament (OT/NT) where each letter represents a book
   - Old Testament: 39 letters (39 books)
   - New Testament: 27 letters (27 books)

2. **Book Level**: One acrostic per book where each letter represents a chapter
   - Number of letters = number of chapters in that book
   - First letter must match the corresponding letter from the Testament acrostic

3. **Chapter Level**: One acrostic per chapter where each letter represents a verse
   - Number of letters = number of verses in that chapter
   - First letter must match the corresponding letter from the Book acrostic

4. **Verse Level**: Short mnemonic phrase (NOT an acrostic) describing the verse content
   - Each phrase helps recall what that specific verse is about

### Example Structure

```
Testament (OT): "FIRST IS THE STORY OF TRUTH ABOUT EVERYONE'S SIN"
  ↓ (Letter F)
Book (Genesis): "FIRST GOD CREATES ADAM THEN CHOOSES ABRAHAM ISAAC AND JACOB"
  ↓ (Letter F)
Chapter (Gen 1): "FIRST GOD MADE HEAVENS AND EARTH GOOD"
  ↓ (Letter F)
Verse (Gen 1:1): "God creates everything at the beginning"
```

### Key Innovation: Branching System

The project allows **multiple alternative acrostics** at every level, creating a tree structure. Users can:
- Vote on different options
- Create new alternatives at any level
- Mix and match from different branches
- Export their preferred combination

Think of it like Git branching but for Bible memorization content.

---

## Technical Architecture

### Tech Stack (All Free Tier)

- **Framework**: Next.js 14+ (App Router, TypeScript)
- **Hosting**: Vercel (free tier)
- **Database**: Supabase (PostgreSQL with free tier)
- **Authentication**: Supabase Auth (OAuth providers: Google, Facebook, GitHub)
- **Styling**: Tailwind CSS
- **State Management**: React Context or Zustand (lightweight)

### Database Schema

```sql
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
```

### Initial Seed Data

```sql
-- Seed initial testament and book acrostics (from provided JSON)
INSERT INTO branches (level, reference, parent_branch_id, content, letter_constraint, is_canonical) VALUES
  ('testament', 'OT', NULL, 'FIRST IS THE STORY OF TRUTH ABOUT EVERYONE''S SIN', NULL, true),
  ('testament', 'NT', NULL, 'JESUS SENT HIS SPIRIT TO ALL OF US', NULL, true);

-- Store the IDs for reference
DO $$
DECLARE
  ot_id UUID;
  nt_id UUID;
  gen_id UUID;
BEGIN
  -- Get testament IDs
  SELECT id INTO ot_id FROM branches WHERE reference = 'OT';
  SELECT id INTO nt_id FROM branches WHERE reference = 'NT';
  
  -- Genesis book acrostic
  INSERT INTO branches (level, reference, parent_branch_id, content, letter_constraint, is_canonical)
  VALUES ('book', 'GEN', ot_id, 'FIRST GOD CREATES ADAM THEN CHOOSES ABRAHAM ISAAC AND JACOB', 'F', true)
  RETURNING id INTO gen_id;
  
  -- Genesis Chapter 1 acrostic
  INSERT INTO branches (level, reference, parent_branch_id, content, letter_constraint, is_canonical)
  VALUES ('chapter', 'GEN.1', gen_id, 'FIRST GOD MADE HEAVENS AND EARTH GOOD', 'F', true);
  
  -- Genesis Chapter 2 acrostic
  INSERT INTO branches (level, reference, parent_branch_id, content, letter_constraint, is_canonical)
  VALUES ('chapter', 'GEN.2', gen_id, 'IN EDEN GOD MADE A WOMAN FOR HIM', 'I', true);
  
  -- Add placeholder verse entries for Gen 1 (31 verses) and Gen 2 (25 verses)
  -- These will be empty strings initially, to be filled by the community
END $$;
```

---

## Application Structure

### Directory Structure

```
shamar-project/
├── app/
│   ├── (auth)/
│   │   ├── login/
│   │   │   └── page.tsx
│   │   └── callback/
│   │       └── route.ts
│   ├── (public)/
│   │   ├── page.tsx                 # Home page
│   │   ├── browse/
│   │   │   ├── page.tsx             # Browse all testaments
│   │   │   ├── [testament]/
│   │   │   │   ├── page.tsx         # Testament view with books
│   │   │   │   └── [book]/
│   │   │   │       ├── page.tsx     # Book view with chapters
│   │   │   │       └── [chapter]/
│   │   │   │           └── page.tsx # Chapter view with verses
│   │   └── about/
│   │       └── page.tsx
│   ├── admin/
│   │   ├── layout.tsx               # Admin-only layout with auth check
│   │   ├── page.tsx                 # Admin dashboard
│   │   ├── settings/
│   │   │   └── page.tsx             # Level settings, feature flags
│   │   ├── branches/
│   │   │   └── page.tsx             # Manage all branches
│   │   ├── export/
│   │   │   └── page.tsx             # Canonical export builder
│   │   └── users/
│   │       └── page.tsx             # User management
│   ├── profile/
│   │   └── page.tsx                 # User profile, contributions, votes
│   ├── api/
│   │   ├── branches/
│   │   │   ├── route.ts             # GET list, POST create
│   │   │   └── [id]/
│   │   │       └── route.ts         # GET, PATCH, DELETE specific branch
│   │   ├── votes/
│   │   │   └── route.ts             # POST vote, DELETE remove vote
│   │   ├── export/
│   │   │   ├── canonical/
│   │   │   │   └── route.ts         # GET canonical export JSON
│   │   │   └── generate/
│   │   │       └── route.ts         # POST generate custom export
│   │   └── admin/
│   │       ├── settings/
│   │       │   └── route.ts         # GET/PATCH admin settings
│   │       └── canonical/
│   │           └── route.ts         # POST set canonical branches
│   ├── layout.tsx                   # Root layout
│   └── globals.css
├── components/
│   ├── ui/                          # shadcn/ui components
│   ├── BranchCard.tsx               # Display branch with voting
│   ├── BranchList.tsx               # List of alternative branches
│   ├── BranchSelector.tsx           # Switch between branches
│   ├── CreateBranchForm.tsx         # Form to create new branch
│   ├── VoteButton.tsx               # Upvote/downvote button
│   ├── PathBreadcrumb.tsx           # Show current branch path
│   ├── ProgressIndicator.tsx        # Show completion percentage
│   ├── ExportButton.tsx             # Download JSON export
│   └── AdminNav.tsx                 # Admin sidebar navigation
├── lib/
│   ├── supabase/
│   │   ├── client.ts                # Client-side Supabase client
│   │   ├── server.ts                # Server-side Supabase client
│   │   └── middleware.ts            # Auth middleware
│   ├── utils.ts                     # Utility functions
│   ├── bible-data.ts                # Bible reference data (book names, chapter counts)
│   ├── validation.ts                # Validation logic for acrostics
│   └── export.ts                    # JSON export generation logic
├── types/
│   └── index.ts                     # TypeScript types
├── public/
│   └── exports/                     # Static canonical exports
├── .env.local
├── .env.example
├── next.config.js
├── tailwind.config.ts
└── package.json
```

---

## Core Features & User Flows

### 1. Public Browse Experience

**User Story**: Anyone can view the hierarchical mnemonics without logging in.

**Implementation**:
- Home page shows testament acrostics with vote counts
- Click testament → shows book list with their acrostics
- Click book → shows chapter list with their acrostics  
- Click chapter → shows verse mnemonics list
- Each level shows:
  - Current "highest voted" option (default view)
  - "See X alternatives" button to view other branches
  - Vote counts displayed as badges
  - Visual indicator if branch is in "Canonical Export"

**UI Elements**:
```tsx
<PathBreadcrumb path={['OT', 'Genesis', 'Chapter 1']} />
<BranchCard 
  content="FIRST GOD MADE HEAVENS AND EARTH GOOD"
  votes={245}
  isCanonical={true}
  onVote={(value) => handleVote(value)}
  userVote={currentUserVote}
/>
<BranchList alternatives={otherBranches} />
```

### 2. Authentication Flow

**User Story**: Users log in to vote and contribute.

**Implementation**:
- "Login" button in header
- Modal or redirect to `/login`
- Show OAuth buttons (Google, Facebook, GitHub)
- Supabase handles OAuth flow
- Redirect to `/auth/callback` then back to previous page
- Create `user_profiles` entry on first login

**UI States**:
- Logged out: "Login to vote or contribute"
- Logged in: Show user avatar/name in header, "Logout" option

### 3. Voting System

**User Story**: Logged-in users vote on branches they prefer.

**Implementation**:
- Each branch card shows upvote/downvote buttons
- Clicking vote:
  1. Check if user is authenticated
  2. Insert or update vote in `votes` table
  3. Update UI optimistically
  4. Show vote count change
- Users can change their vote or remove it
- Vote counts aggregate in real-time (or cache with periodic refresh)

**Logic**:
```typescript
async function handleVote(branchId: string, value: 1 | -1) {
  const { data: existingVote } = await supabase
    .from('votes')
    .select()
    .eq('user_id', userId)
    .eq('branch_id', branchId)
    .single();
  
  if (existingVote?.vote_value === value) {
    // Remove vote if clicking same button
    await supabase.from('votes').delete()
      .eq('user_id', userId)
      .eq('branch_id', branchId);
  } else {
    // Upsert new vote
    await supabase.from('votes').upsert({
      user_id: userId,
      branch_id: branchId,
      vote_value: value
    });
  }
}
```

### 4. Creating New Branches

**User Story**: Users contribute alternative acrostics at any open level.

**Implementation**:
- Check `admin_settings.editable_levels` to show/hide "Create Alternative" button
- Form appears with:
  - Text input for mnemonic
  - Auto-validation:
    - Check first letter matches parent constraint
    - Check word count matches required length (chapters/verses)
    - Show live feedback as user types
  - Submit button (disabled until valid)
- On submit:
  1. Insert into `branches` table with `parent_branch_id`
  2. Redirect to new branch view
  3. Show success message

**Validation Example**:
```typescript
function validateBookAcrostic(text: string, bookCode: string, requiredFirstLetter: string) {
  const words = text.trim().split(/\s+/);
  const chapterCount = BIBLE_DATA[bookCode].chapters;
  
  if (words.length !== chapterCount) {
    return { valid: false, error: `Must have ${chapterCount} words (one per chapter)` };
  }
  
  if (words[0][0].toUpperCase() !== requiredFirstLetter.toUpperCase()) {
    return { valid: false, error: `Must start with letter "${requiredFirstLetter}"` };
  }
  
  return { valid: true };
}
```

### 5. Branch Navigation & Switching

**User Story**: Users explore different branch combinations.

**Implementation**:
- Breadcrumb at top shows current path
- Each breadcrumb level is clickable
- Clicking shows dropdown with alternatives
- Selecting alternative re-renders entire subtree with that branch's children
- URL updates to reflect selection: `/browse/OT/branch-123/GEN/branch-456/1`
- URL is shareable (others see same branch combination)

**State Management**:
```typescript
// Store current branch selections in URL or Context
type BranchPath = {
  testament: string;      // branch ID or 'default'
  book: string;           // branch ID or 'default'
  chapter: string;        // branch ID or 'default'
};

// Fetch appropriate children based on parent branch ID
async function fetchChildBranches(parentId: string, level: string) {
  return await supabase
    .from('branches')
    .select('*, votes(vote_value)')
    .eq('parent_branch_id', parentId)
    .eq('level', level);
}
```

### 6. Admin Dashboard

**User Story**: Admin configures which levels are editable and curates canonical export.

**Implementation**:

**Settings Page** (`/admin/settings`):
- Toggle switches for each level:
  - ☑ Testament Acrostics (editable)
  - ☑ Book Acrostics (editable)
  - ☐ Chapter Acrostics (locked)
  - ☐ Verse Mnemonics (locked)
- Changes save to `admin_settings.editable_levels`

**Branch Management** (`/admin/branches`):
- Table view of all branches
- Filter by level, status
- Actions: Archive, Flag, Delete
- Mark branches as canonical

**Export Builder** (`/admin/export`):
- Visual tree for selecting canonical branches
- For each book:
  - Dropdown to select which branch to use
  - Preview selected acrostic
  - Show completion percentage
- "Generate Canonical Export" button
- Creates new entry in `export_versions` table
- Downloads JSON file

**Export Generation Logic**:
```typescript
async function generateCanonicalExport(branchSelections: BranchSelections) {
  const output = {
    meta: {
      version: "1.0",
      description: "Hierarchical mnemonics for Bible memorization",
      generated_at: new Date().toISOString()
    },
    testaments: {},
    books: {}
  };
  
  // For OT and NT
  for (const testament of ['OT', 'NT']) {
    const testamentBranch = await fetchBranch(branchSelections.testaments[testament]);
    output.testaments[testament] = {
      mnemonic: testamentBranch.content
    };
    
    // For each book in testament
    const books = BIBLE_DATA[testament].books;
    for (const bookCode of books) {
      const bookBranch = await fetchBranch(branchSelections.books[bookCode]);
      output.books[bookCode] = {
        mnemonic: bookBranch.content,
        chapters: {}
      };
      
      // For each chapter in book
      for (let i = 1; i <= BIBLE_DATA[bookCode].chapterCount; i++) {
        const chapterRef = `${bookCode}.${i}`;
        const chapterBranch = await fetchBranch(branchSelections.chapters[chapterRef]);
        output.books[bookCode].chapters[i] = {
          mnemonic: chapterBranch.content,
          verses: {}
        };
        
        // For each verse in chapter
        for (let v = 1; v <= BIBLE_DATA[bookCode].verses[i]; v++) {
          const verseRef = `${chapterRef}.${v}`;
          const verseBranch = await fetchBranch(branchSelections.verses[verseRef]);
          output.books[bookCode].chapters[i].verses[v] = {
            mnemonic: verseBranch.content
          };
        }
      }
    }
  }
  
  return output;
}
```

### 7. User Profile & Contributions

**User Story**: Users see their contributions and voting history.

**Implementation** (`/profile`):
- Display name (editable)
- Stats:
  - Contributions count
  - Upvotes received
  - Current voting activity
- Lists:
  - "My Contributions" (branches created by user)
  - "My Votes" (branches user has voted on)
  - Each item links to the branch in context

### 8. Export API

**User Story**: Developers can fetch the canonical JSON via API.

**Implementation**:
- Public API endpoint: `GET /api/export/canonical/latest`
- Returns the most recent canonical export JSON
- Optional: `GET /api/export/canonical/v1.2` for specific versions
- Add CORS headers for external use
- Track download counts

**Example Response**:
```json
{
  "meta": {
    "version": "1.0",
    "description": "Hierarchical mnemonics for Bible memorization",
    "generated_at": "2024-12-15T10:30:00Z"
  },
  "testaments": {
    "OT": {
      "mnemonic": "FIRST IS THE STORY OF TRUTH ABOUT EVERYONE'S SIN"
    },
    "NT": {
      "mnemonic": "JESUS SENT HIS SPIRIT TO ALL OF US"
    }
  },
  "books": {
    "GEN": {
      "mnemonic": "FIRST GOD CREATES ADAM THEN CHOOSES ABRAHAM ISAAC AND JACOB",
      "chapters": {
        "1": {
          "mnemonic": "FIRST GOD MADE HEAVENS AND EARTH GOOD",
          "verses": {
            "1": { "mnemonic": "God creates everything at the beginning" },
            ...
          }
        }
      }
    }
  }
}
```

---

## Bible Reference Data

Create a comprehensive reference file with all Bible books, chapter counts, and verse counts:

```typescript
// lib/bible-data.ts

export const BIBLE_DATA = {
  OT: {
    books: ['GEN', 'EXO', 'LEV', 'NUM', 'DEU', 'JOS', 'JDG', 'RUT', 'SA1', 'SA2', 
            'KI1', 'KI2', 'CH1', 'CH2', 'EZR', 'NEH', 'EST', 'JOB', 'PSA', 'PRO',
            'ECC', 'SNG', 'ISA', 'JER', 'LAM', 'EZK', 'DAN', 'HOS', 'JOL', 'AMO',
            'OBA', 'JON', 'MIC', 'NAM', 'HAB', 'ZEP', 'HAG', 'ZEC', 'MAL'],
    count: 39
  },
  NT: {
    books: ['MAT', 'MRK', 'LUK', 'JHN', 'ACT', 'ROM', 'CO1', 'CO2', 'GAL', 'EPH',
            'PHP', 'COL', 'TH1', 'TH2', 'TI1', 'TI2', 'TIT', 'PHM', 'HEB', 'JAS',
            'PE1', 'PE2', 'JN1', 'JN2', 'JN3', 'JDE', 'REV'],
    count: 27
  },
  GEN: {
    name: 'Genesis',
    testament: 'OT',
    chapterCount: 50,
    verses: [31, 25, 24, 26, 32, 22, 24, 22, 29, 32, 32, 20, 18, 24, 21, 16, 27, 33, 38, 18,
             34, 24, 20, 67, 34, 35, 46, 22, 35, 43, 55, 32, 20, 31, 29, 43, 36, 30, 23, 23,
             57, 38, 34, 34, 28, 34, 31, 22, 33, 26]
  },
  // ... (include all 66 books with their chapter counts and verse counts per chapter)
  // This data is available in standard Bible databases
};

export function getBookInfo(bookCode: string) {
  return BIBLE_DATA[bookCode];
}

export function getChapterVerseCount(bookCode: string, chapter: number) {
  return BIBLE_DATA[bookCode].verses[chapter - 1];
}

export function getRequiredWordCount(level: string, reference: string) {
  const [book, chapter] = reference.split('.');
  
  switch(level) {
    case 'testament':
      return reference === 'OT' ? 39 : 27;
    case 'book':
      return BIBLE_DATA[reference].chapterCount;
    case 'chapter':
      return getChapterVerseCount(book, parseInt(chapter));
    default:
      return 0;
  }
}
```

---

## UI/UX Design Guidelines

### Color Scheme
- Primary: Deep blue (#2563eb) - represents wisdom/scripture
- Secondary: Gold/amber (#f59e0b) - represents value/treasure
- Success: Green (#10b981) - for canonical badges
- Background: Light gray (#f9fafb)
- Text: Dark gray (#111827)

### Key UI Patterns

**Branch Card Component**:
```tsx
┌─────────────────────────────────────────────────┐
│ 📜 Genesis Chapter 1                            │
│ ★ Canonical ⭐ 245 votes                        │
├─────────────────────────────────────────────────┤
│                                                 │
│  FIRST GOD MADE HEAVENS AND EARTH GOOD         │
│                                                 │
├─────────────────────────────────────────────────┤
│  👍 Upvote (123)    👎 Downvote (8)            │
│  See 4 alternatives →                           │
└─────────────────────────────────────────────────┘
```

**Breadcrumb Navigation**:
```
Home > [OT ▼] > [Genesis ▼] > [Chapter 1 ▼]
         ^          ^            ^
      Click to    Click to    Click to
      see other   see other   see other
      testaments  book opts   chapter opts
```

**Validation Feedback (Live)**:
```
┌─────────────────────────────────────────────────┐
│ Create New Book Acrostic for Genesis           │
├─────────────────────────────────────────────────┤
│ Must start with "F" (from Testament acrostic)   │
│ Must have 50 words (one per chapter)            │
│                                                 │
│ [FIRST GOD CREATES ADAM THEN CHOOSES...      ] │
│                                                 │
│ ✅ Starts with F                                │
│ ✅ Has 50 words                                 │
│ ✅ Valid acrostic!                              │
│                                                 │
│ [Cancel]  [Create Alternative]                  │
└─────────────────────────────────────────────────┘
```

### Responsive Design
- Mobile-first approach
- Breadcrumb collapses to dropdown on mobile
- Branch cards stack vertically
- Admin dashboard uses collapsible sidebar

---

## Environment Variables

Create `.env.example`:
```bash
# Supabase
NEXT_PUBLIC_SUPABASE_URL=your-project-url.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key

# Admin (your email for admin access)
ADMIN_EMAIL=your-email@gmail.com

# Optional: Analytics, monitoring
# NEXT_PUBLIC_GA_ID=G-XXXXXXXXXX
```

---

## Deployment Checklist

1. **Create Supabase Project**
   - Sign up at supabase.com
   - Create new project
   - Run schema SQL in SQL Editor
   - Configure OAuth providers in Authentication settings
   - Add your email to `user_profiles` table with `is_admin = true`

2. **Configure Vercel**
   - Connect GitHub repo
   - Add environment variables
   - Deploy

3. **Post-Deployment**
   - Test OAuth login flow
   - Verify admin access
   - Create initial canonical branches
   - Test voting system
   - Generate first export

---

## Testing Requirements

Implement tests for:
1. **Validation logic** - acrostic constraints
2. **Vote aggregation** - correct counts
3. **Branch hierarchy** - parent-child relationships
4. **Export generation** - valid JSON output
5. **Auth middleware** - admin-only routes protected

---

## Future Enhancements (Post-MVP)

- Real-time collaboration (Supabase Realtime)
- Comment threads on branches
- "Suggest edit" workflow
- Gamification (badges, leaderboards)
- Mobile app (React Native)
- AI-assisted mnemonic generation
- Printable PDF exports
- Audio pronunciation guides
- Integration with Bible reading plans

---

## Key Implementation Notes

1. **Always validate acrostic constraints** before allowing branch creation
2. **Use optimistic UI updates** for voting to feel responsive
3. **Cache vote counts** (update every 5 minutes) to reduce database load
4. **Use URL-based state** for branch selections to enable sharing
5. **Lazy load verse mnemonics** (only fetch when chapter is expanded)
6. **Implement rate limiting** on API routes (use Vercel's middleware)
7. **Add analytics** to track which branches are most viewed
8. **Monitor database size** and set alerts in Supabase dashboard

---

## Success Metrics

Track these metrics in admin dashboard:
- Total users registered
- Total contributions (branches created)
- Total votes cast
- Completion percentage (how many verses have mnemonics)
- Most active contributors
- Most popular branches (by votes)
- Export download counts

---

## Accessibility Requirements

- All buttons have aria-labels
- Keyboard navigation works throughout
- Color contrast meets WCAG AA standards
- Form validation errors announced to screen readers
- Focus management in modals/dropdowns

---

## Error Handling

- Network errors: Show retry button
- Auth errors: Redirect to login with return URL
- Validation errors: Inline, specific messages
- 404s: Friendly page with navigation back
- 500s: Log to monitoring service, show generic message

---

## Performance Optimization

- Use Next.js Image component for any images
- Implement pagination for long lists (100+ items)
- Use React.memo for BranchCard components
- Debounce search/filter inputs
- Use Supabase indexes for common queries
- Enable Next.js static generation for public pages
- Use incremental static regeneration for browse pages

---

## Security Considerations

- All API routes check authentication where needed
- Admin routes verify `is_admin` flag
- User input sanitized before database insertion
- Use Supabase RLS policies (already defined in schema)
- Rate limit contribution endpoints
- Validate branch content length (max 500 chars)
- Prevent SQL injection via parameterized queries (Supabase handles this)

---

## Getting Started Command Sequence

Once you've created the Next.js app, run:

```bash
npm install @supabase/supabase-js @supabase/auth-helpers-nextjs
npm install zustand # or your preferred state management
npm install lucide-react # for icons
npm install @radix-ui/react-dropdown-menu @radix-ui/react-dialog # for UI components
npm install tailwindcss-animate class-variance-authority clsx tailwind-merge
```

Then follow the Supabase setup in the Database Schema section above.

---

## Final Notes for Implementation

This is a comprehensive specification. Break it down into phases:

**Phase 1 (Week 1-2)**: Core browsing, auth, voting
**Phase 2 (Week 3)**: Branch creation, validation
**Phase 3 (Week 4)**: Admin dashboard, settings
**Phase 4 (Week 5)**: Export system, API
**Phase 5 (Week 6)**: Polish, testing, deployment

Focus on getting a working prototype deployed quickly, then iterate based on user feedback. The free tiers will support you for a long time as you grow.

Build this with clean, maintainable code. Use TypeScript strictly. Comment complex logic. Make it easy for others to contribute to the codebase later.

Good luck building The Shamar Project! 🙏
