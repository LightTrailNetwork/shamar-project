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
