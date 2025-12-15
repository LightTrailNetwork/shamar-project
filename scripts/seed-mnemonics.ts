import { createClient } from '@supabase/supabase-js'
import * as fs from 'fs'
import * as path from 'path'
import dotenv from 'dotenv'

// Load environment variables
dotenv.config({ path: '.env.local' })
dotenv.config({ path: '.env' })
dotenv.config({ path: '.ENV' })

// Supabase Admin Client (needed to bypass RLS if strict, or just use service role)
// Since we are running locally, we might need SERVICE_ROLE_KEY if RLS blocks inserts.
// However, the current schema allows inserts for authenticated users.
// For a seed script, it's best to use the SERVICE_ROLE_KEY if available, or just the ANON key if we have a user.
// But we want to insert 'is_canonical' which usually requires admin.
// Let's assume user provides SERVICE_ROLE_KEY or I have it. 
// Wait, I don't have SERVICE_ROLE_KEY in the context. I only saw `client.ts` using ANON.
// BUT, I can see `.env` file via `view_file`? No, I can't read secrets.
// I'll try to use the ANON key and hope RLS allows it or I can sign in.
// Actually, `branches` table policy: `create policy "Enable insert for authenticated users only"`.
// And `is_canonical` might be protected.
// Schema: "is_canonical BOOLEAN DEFAULT FALSE".
// If I want to set is_canonical=true, I might need admin privileges if RLS protects that column?
// RLS protects ROWS. Columns are not protected individually by standard RLS unless triggers are used.
// Checking schema... I only viewed partial schema overviews.
// FOR NOW: I will try to insert using the provided ANON key. If it fails due to auth, I'll ask user for help
// OR I will create a function in Supabase.
// BETTER: I'll use the already configured `src/lib/supabase/client` or `server`? No, those use Next.js constructs.
// I'll use `supabase-js` directly.

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY // Hopefully this exists in .env.local

// If no service role, we can't bypass RLS easily for "canonical" if RLS restricts it.
// But let's look at schema again. User didn't restrict 'is_canonical' specifically, just 'insert' requires auth.
// Wait, if I run this script, I am NOT authenticated as a user.
// So I NEED the Service Role Key.
// I will check if `.env.local` has it.

if (!supabaseUrl || !supabaseKey) {
    console.error("Missing Supabase credentials")
    process.exit(1)
}

// Fallback to anon key if service role missing, but it might fail RLS
const supabase = createClient(supabaseUrl, serviceRoleKey || supabaseKey)

async function seed() {
    console.log("Starting seed...")

    const jsonPath = path.join(process.cwd(), 'src', 'data', 'bibleMnemonics.json')
    const rawData = fs.readFileSync(jsonPath, 'utf8')
    const data = JSON.parse(rawData)

    // 1. Testaments
    for (const [key, value] of Object.entries(data.testaments)) {
        const tVal = value as any
        console.log(`Processing Testament: ${key}`)

        let { data: existing, error } = await supabase
            .from('branches')
            .select('id')
            .eq('level', 'testament')
            .eq('reference', key)
            .eq('is_canonical', true)
            .single()

        let parentId = existing?.id

        if (!existing) {
            const { data: inserted, error: insertError } = await supabase
                .from('branches')
                .insert({
                    level: 'testament',
                    reference: key,
                    content: tVal.mnemonic,
                    is_canonical: true,
                    status: 'active'
                })
                .select('id')
                .single()

            if (insertError) {
                console.error(`Error inserting testament ${key}:`, insertError)
                continue
            }
            parentId = inserted.id
        } else {
            // Update content?
            await supabase.from('branches').update({
                content: tVal.mnemonic
            }).eq('id', parentId)
        }

        // 2. Books
        // Iterate BIBLE_BOOKS to map JSON keys? 
        // The JSON has "books" key.
        const booksData = data.books as Record<string, any>

        // Filter books belonging to this testament
        // We can check BIBLE_BOOK_ORDER but JSON object has all.
        // We need to know which book belongs to which testament.
        // Or we just try to find the book in the JSON.
        // BIBLE_DATA can help.
        // Importing BIBLE_DATA inside script might be tricky due to aliases/module resolution.
        // I'll just iterate all books in the JSON and check if they match the current Testament (simple check).

        // Actually, easiest way: Just iterate ALL books in JSON and link to the correct Testament Parent.
        // So let's handle Testaments first, store their IDs.
        // Then iterate Books.
    }

    // Store Testament IDs
    const testamentIds: Record<string, string> = {}

    for (const t of ['OT', 'NT']) {
        const { data } = await supabase.from('branches').select('id').eq('level', 'testament').eq('reference', t).eq('is_canonical', true).single()
        if (data) testamentIds[t] = data.id
    }

    if (!testamentIds.OT || !testamentIds.NT) {
        console.error("Could not verify Testaments")
        // return
    }

    // Process Books
    const books = data.books as Record<string, any>
    for (const [bookCode, bookData] of Object.entries(books)) {
        console.log(`Processing Book: ${bookCode}`)

        // Determine Testament
        // Simple heuristic or hardcoded set
        const isOT = ["GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI", "2KI", "1CH", "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER", "LAM", "EZK", "DAN", "HOS", "JOL", "AMO", "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL"].includes(bookCode)
        const parentId = isOT ? testamentIds.OT : testamentIds.NT

        if (!parentId) continue

        // Book Branch
        let bookBranchId: string;
        let { data: existingBook } = await supabase
            .from('branches')
            .select('id')
            .eq('level', 'book')
            .eq('reference', bookCode)
            .eq('is_canonical', true)
            .single()

        if (!existingBook) {
            const { data: inserted } = await supabase.from('branches').insert({
                level: 'book',
                reference: bookCode,
                parent_branch_id: parentId,
                content: bookData.mnemonic,
                is_canonical: true,
                // letter_constraint: Calculate from parent mnemonic?
                // Parent Mnemonic: "FIRST IS THE STORY..."
                // Split words, find index.
                // Too complex for MVP seed script to calc dynamically perfectly? 
                // Actually, let's try.
                status: 'active'
            }).select('id').single()
            if (!inserted) {
                console.error("Failed to insert book", bookCode)
                continue
            }
            bookBranchId = inserted.id
        } else {
            bookBranchId = existingBook.id
            await supabase.from('branches').update({ content: bookData.mnemonic, parent_branch_id: parentId }).eq('id', bookBranchId)
        }

        // Chapters
        if (bookData.chapters) {
            for (const [chapNum, chapData] of Object.entries(bookData.chapters)) {
                const cData = chapData as any
                const chapRef = `${bookCode}.${chapNum}`

                let { data: exChap } = await supabase.from('branches').select('id').eq('level', 'chapter').eq('reference', chapRef).eq('is_canonical', true).single()

                let chapId = exChap?.id
                if (!exChap) {
                    const { data: ins } = await supabase.from('branches').insert({
                        level: 'chapter',
                        reference: chapRef,
                        parent_branch_id: bookBranchId,
                        content: cData.mnemonic,
                        is_canonical: true,
                        status: 'active'
                    }).select('id').single()
                    chapId = ins?.id
                } else {
                    await supabase.from('branches').update({ content: cData.mnemonic, parent_branch_id: bookBranchId }).eq('id', chapId)
                }

                // Verses
                // (Skipping for now unless requested, as JSON has empty strings mostly)
            }
        }
    }

    console.log("Seeding complete.")
}

seed()
