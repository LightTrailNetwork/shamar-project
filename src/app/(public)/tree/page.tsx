import { createClient } from '@/lib/supabase/server'
import { BibleTreeDashboard } from '@/components/BibleTreeDashboard'
import { BIBLE_DATA } from '@/lib/bible-data'

export default async function TreePage() {
    const supabase = await createClient()

    // 1. Fetch Testament Branches (OT & NT)
    const { data: testamentBranches } = await supabase
        .from('branches')
        .select('*, votes (vote_value)')
        .eq('level', 'testament')
        .in('reference', ['OT', 'NT'])

    // 2. Fetch All Book Branches (for initial view)
    // We only need the canonical/best ones really, but let's fetch 'book' level
    // This might be large, but for now we fetch all to find the best ones. 
    // Optimization: Filter by "is_canonical" or sort by votes.
    const { data: bookBranches } = await supabase
        .from('branches')
        .select('*, votes (vote_value)')
        .eq('level', 'book')

    const getScore = (branch: any) => branch.votes?.reduce((acc: number, v: any) => acc + (v.vote_value || 0), 0) || 0

    // Process Testaments
    const processedTestaments = ['OT', 'NT'].map(ref => {
        const branches = (testamentBranches || [])
            .filter(b => b.reference === ref)
            .map(b => ({ ...b, score: getScore(b) }))
            .sort((a, b) => b.score - a.score)

        return {
            ref,
            bestBranch: branches[0] || null,
            count: branches.length
        }
    })

    // Process Books Map: { GEN: { best: ..., count: ... }, EXO: ... }
    const bookMap: Record<string, any> = {}

    // We need the list of all books to ensure we have entries for them
    const allBooks = [...(BIBLE_DATA.OT.books as string[]), ...(BIBLE_DATA.NT.books as string[])]

    allBooks.forEach(code => {
        const branches = (bookBranches || [])
            .filter(b => b.reference === code)
            .map(b => ({ ...b, score: getScore(b) }))
            .sort((a, b) => b.score - a.score)

        bookMap[code] = {
            bestBranch: branches[0] || null,
            count: branches.length
        }
    })

    return (
        <div className="max-w-7xl mx-auto py-8 px-4">
            <div className="mb-8">
                <h1 className="text-3xl font-bold text-gray-900">Bible Acrostic Dashboard</h1>
                <p className="text-muted-foreground mt-2">Manage and visualize the entire Bible memory hierarchy in one place.</p>
            </div>

            <BibleTreeDashboard
                testaments={processedTestaments}
                bookMap={bookMap}
            />
        </div>
    )
}
