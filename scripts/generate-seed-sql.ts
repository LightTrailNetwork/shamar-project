import * as fs from 'fs'
import * as path from 'path'

// Helper to escape SQL strings
const escape = (str: string) => str.replace(/'/g, "''")

function generate() {
    const jsonPath = path.join(process.cwd(), 'src', 'data', 'bibleMnemonics.json')
    const rawData = fs.readFileSync(jsonPath, 'utf8')
    const data = JSON.parse(rawData)

    let sql = `-- Full Seed Data generated from bibleMnemonics.json
-- Run this in Supabase SQL Editor

BEGIN;

-- 1. Testaments
`
    // We need UUIDs. Since we generated them in JS previously, here we can use `gen_random_uuid()` in SQL.
    // But we need to reference them later (Book -> Testament).
    // so we can use WITH queries or temporary tables, or just assume order?
    // SQL Variables (DO blocks) are robust.

    // Actually, simpler: Use a standardized UUID generation or just `uuid_generate_v5` based on reference?
    // Supabase has `uuid-ossp`. `uuid_generate_v5(uuid_ns_url(), 'OT')` is deterministic!
    // Let's use deterministic UUIDs based on the 'reference' column so we can link them easily without variables.
    // Namespace: Use a random UUID constant for "Shamar Project" namespace.
    // '6ba7b810-9dad-11d1-80b4-00c04fd430c8' is DNS namespace.
    // Let's just define our own constant NS.

    const NAMESPACE = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'; // Random

    sql += `
-- Function to generate deterministic IDs for seed data
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    `
    // Actually, we can just compute the UUIDs in Node.js!
    // NPM string-to-uuid? Or just use a hash?
    // `crypto` module.

    const crypto = require('crypto');
    const getUUID = (str: string) => {
        const hash = crypto.createHash('sha1').update(NAMESPACE + str).digest('hex');
        // Format as UUID: 8-4-4-4-12
        return `${hash.substr(0, 8)}-${hash.substr(8, 4)}-${hash.substr(12, 4)}-${hash.substr(16, 4)}-${hash.substr(20, 12)}`;
    }

    // Testaments
    const testaments = data.testaments;
    for (const [key, val] of Object.entries(testaments)) {
        const tVal = val as any;
        const id = getUUID(key);
        sql += `
INSERT INTO branches (id, level, reference, content, is_canonical, status)
VALUES ('${id}', 'testament', '${key}', '${escape(tVal.mnemonic)}', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
`
    }

    // Books
    // We map books to testaments manually or check list
    const OT_BOOKS = new Set(["GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI", "2KI", "1CH", "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER", "LAM", "EZK", "DAN", "HOS", "JOL", "AMO", "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL"]);

    sql += `\n-- Books\n`

    for (const [bookCode, bookData] of Object.entries(data.books)) {
        const bVal = bookData as any;
        const tRef = OT_BOOKS.has(bookCode) ? 'OT' : 'NT';
        const tId = getUUID(tRef);
        const bId = getUUID(bookCode);

        // Calculate constraint (first letter of this book in testament mnemonic)
        // Ignoring for SQL seed to keep it simple, or calculate in JS?
        // Let's skip letter_constraint for now or null.

        sql += `INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('${bId}', 'book', '${bookCode}', '${tId}', '${escape(bVal.mnemonic)}', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
`

        // Chapters
        if (bVal.chapters) {
            for (const [cNum, cVal] of Object.entries(bVal.chapters)) {
                const chapData = cVal as any;
                const cRef = `${bookCode}.${cNum}`;
                const cId = getUUID(cRef);

                sql += `INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('${cId}', 'chapter', '${cRef}', '${bId}', '${escape(chapData.mnemonic)}', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, parent_branch_id = EXCLUDED.parent_branch_id;
`
                // Verses - Skip if empty or handle?
                // The JSON has verses with empty mnemonic ""
                // If we want to seed structure, we can.
                // But mostly we want the mnemonic content.
                // If Verse mnemonic is empty string, maybe skip?
                // Or insert placeholder?
                // Let's skip empty verses to save space.
                if (chapData.verses) {
                    for (const [vNum, vVal] of Object.entries(chapData.verses)) {
                        const verseData = vVal as any;
                        if (verseData.mnemonic && verseData.mnemonic.trim().length > 0) {
                            const vRef = `${cRef}.${vNum}`;
                            const vId = getUUID(vRef);
                            sql += `INSERT INTO branches (id, level, reference, parent_branch_id, content, is_canonical, status)
VALUES ('${vId}', 'verse', '${vRef}', '${cId}', '${escape(verseData.mnemonic)}', true, 'active')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
`
                        }
                    }
                }
            }
        }
    }

    sql += `\nCOMMIT;`

    const outPath = path.join(process.cwd(), 'supabase', 'seed_full.sql')
    fs.writeFileSync(outPath, sql)
    console.log(`Generated SQL seed at ${outPath}`)
}

generate()
