import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { BIBLE_DATA, getBookInfo } from '@/lib/bible-data'
import { BranchCard } from '@/components/BranchCard'
import { PathBreadcrumb } from '@/components/PathBreadcrumb'
import { notFound } from 'next/navigation'
import { TestamentView } from '@/components/TestamentView'

interface PageProps {
    params: Promise<{ testament: string }>
}

export default async function TestamentPage({ params }: PageProps) {
    const { testament } = await params
    const ref = testament.toUpperCase()

    if (ref !== 'OT' && ref !== 'NT') {
        notFound()
    }

    const supabase = await createClient()

    // Get books list from static data
    const booksList = BIBLE_DATA[ref].books as string[]

    // Fetch all book branches for this testament
    const { data: bookBranches } = await supabase
        .from('branches')
        .select('*, votes (vote_value)')
        .eq('level', 'book')
        .in('reference', booksList)

    // Fetch the testament mnemonic itself
    const { data: testamentBranchData } = await supabase
        .from('branches')
        .select('*, votes (vote_value)')
        .eq('level', 'testament')
        .eq('reference', ref)

    const getScore = (branch: any) => branch.votes?.reduce((acc: number, v: any) => acc + (v.vote_value || 0), 0) || 0

    const sortedTestamentBranches = (testamentBranchData || [])
        .map(b => ({ ...b, score: getScore(b) }))
        .sort((a, b) => {
            if (a.is_canonical !== b.is_canonical) return a.is_canonical ? -1 : 1;
            return b.score - a.score;
        })

    const testamentBranch = sortedTestamentBranches[0] || null
    const testamentAlternativesCount = Math.max(0, sortedTestamentBranches.length - 1)

    // Map each book to its best branch
    const books = booksList.map(bookCode => {
        const bookInfo = getBookInfo(bookCode)
        const variants = (bookBranches || [])
            .filter(b => b.reference === bookCode)
            .map(b => ({ ...b, score: getScore(b) }))
            .sort((a, b) => b.score - a.score)

        return {
            code: bookCode,
            name: bookInfo.name,
            bestBranch: variants[0] || null,
            count: variants.length,
            chapterCount: bookInfo.chapterCount // Added this
        }
    })

    return (
        <div className="max-w-4xl mx-auto py-8 px-4">
            <PathBreadcrumb path={[
                { label: ref === 'OT' ? 'Old Testament' : 'New Testament', href: `/browse/${ref}` }
            ]} />

            <h1 className="text-3xl font-bold mb-6">
                {ref === 'OT' ? 'Old Testament' : 'New Testament'}
            </h1>

            <TestamentView
                testamentRef={ref}
                books={books}
                testamentBranch={testamentBranch}
                testamentAlternativesCount={testamentAlternativesCount}
                booksList={booksList}
            />
        </div>
    )
}
