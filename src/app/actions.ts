'use server'

import { createClient } from '@/lib/supabase/server'
import { getChapterText } from '@/lib/bible-api'
import { getChapterVerseCount } from '@/lib/bible-data'

export async function getChapterData(bookCode: string, chapters: number[]) {
    const supabase = await createClient()
    const chapterRefs = chapters.map(c => `${bookCode}.${c}`)

    // Fetch chapter branches
    const { data: chapterBranches } = await supabase
        .from('branches')
        .select('*, votes (vote_value)')
        .eq('level', 'chapter')
        .in('reference', chapterRefs)

    // Calculate scores
    const getScore = (branch: any) => branch.votes?.reduce((acc: number, v: any) => acc + (v.vote_value || 0), 0) || 0

    return chapterBranches?.map(b => ({
        ...b,
        score: getScore(b)
    })).sort((a, b) => {
        const numA = parseInt(a.reference.split('.').pop() || '0')
        const numB = parseInt(b.reference.split('.').pop() || '0')
        return numA - numB
    }) || []
}

export async function getVerseData(bookCode: string, chapterNum: number) {
    const supabase = await createClient()
    const chapterRef = `${bookCode}.${chapterNum}`
    const verseCount = getChapterVerseCount(bookCode, chapterNum)
    const verseRefs = Array.from({ length: verseCount }, (_, i) => `${chapterRef}.${i + 1}`)

    // Parallel fetch: Verse Mnemonics + Bible Text
    const [verseBranchesResult, bsbVerses] = await Promise.all([
        supabase
            .from('branches')
            .select('*, votes (vote_value)')
            .eq('level', 'verse')
            .in('reference', verseRefs),
        getChapterText(bookCode, chapterNum)
    ])

    const getScore = (branch: any) => branch.votes?.reduce((acc: number, v: any) => acc + (v.vote_value || 0), 0) || 0

    const verseBranches = verseBranchesResult.data?.map(b => ({
        ...b,
        score: getScore(b)
    })) || []

    return {
        verseBranches,
        bsbVerses
    }
}
