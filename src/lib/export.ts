import { createClient } from '@/lib/supabase/server'
import { BIBLE_DATA } from '@/lib/bible-data'

export async function generateCanonicalExport() {
    const supabase = await createClient()

    // For MVP, we simply select all branches marked 'is_canonical = true'
    // In a real system, we might need a specific mapping if multiple are canonical (rare)
    // or use the `admin_settings` mapping. 
    // Here we optimistically fetch all canonical ones and structure them.

    const { data: canonicalBranches } = await supabase
        .from('branches')
        .select('*')
        .eq('is_canonical', true)

    if (!canonicalBranches) return { error: "No canonical data found" }

    const output: any = {
        meta: {
            version: "1.0",
            description: "Hierarchical mnemonics for Bible memorization",
            generated_at: new Date().toISOString()
        },
        testaments: {},
        books: {}
    }

    // Index by reference for O(1) lookup
    const map = new Map(canonicalBranches.map(b => [b.reference, b]))

    // Testaments
    for (const t of ['OT', 'NT']) {
        const b = map.get(t)
        if (b) {
            output.testaments[t] = { mnemonic: b.content }
        }

        const booksList = BIBLE_DATA[t].books as string[]
        for (const bookCode of booksList) {
            const bookBranch = map.get(bookCode)
            const bookData: any = {
                mnemonic: bookBranch?.content || null,
                chapters: {}
            }

            if (bookBranch) {
                const chapterCount = BIBLE_DATA[bookCode].chapterCount
                for (let c = 1; c <= chapterCount; c++) {
                    const chRef = `${bookCode}.${c}`
                    const chBranch = map.get(chRef)
                    const chData: any = {
                        mnemonic: chBranch?.content || null,
                        verses: {}
                    }

                    if (chBranch) {
                        const verseCount = BIBLE_DATA[bookCode].verses[c - 1] || 0
                        for (let v = 1; v <= verseCount; v++) {
                            const vRef = `${chRef}.${v}`
                            const vBranch = map.get(vRef)
                            if (vBranch) {
                                chData.verses[v] = { mnemonic: vBranch.content }
                            }
                        }
                    }
                    if (chBranch || Object.keys(chData.verses).length > 0) {
                        bookData.chapters[c] = chData
                    }
                }
            }

            if (bookBranch || Object.keys(bookData.chapters).length > 0) {
                output.books[bookCode] = bookData
            }
        }
    }

    return output
}
