import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { BIBLE_DATA, getBookInfo } from '@/lib/bible-data'
import { BranchCard } from '@/components/BranchCard'
import { PathBreadcrumb } from '@/components/PathBreadcrumb'
import { notFound } from 'next/navigation'

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
            count: variants.length
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

            {testamentBranch ? (
                <div className="mb-12">
                    <div className="flex justify-between items-end mb-2">
                        <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wider">Testament Acrostic</h2>
                        <Link href={`/create?level=testament&ref=${ref}`} className="text-sm font-medium text-primary hover:underline">
                            + Add Alternative
                        </Link>
                    </div>
                    <BranchCard
                        branch={testamentBranch}
                        votes={testamentBranch.score}
                        userVote={0}
                        alternativesCount={testamentAlternativesCount}
                    />
                </div>
            ) : (
                <div className="mb-12 p-8 border-2 border-dashed border-gray-200 rounded-lg text-center">
                    <p className="text-gray-500 mb-4">No acrostic found for this testament.</p>
                    <Link href={`/create?level=testament&ref=${ref}`} className="inline-flex items-center justify-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-primary hover:bg-primary/90">
                        Create the First One
                    </Link>
                </div>
            )}

            <h2 className="text-2xl font-bold mb-6">Books</h2>

            <div className="space-y-4">
                {books.map(book => (
                    <div key={book.code} className="border border-border rounded-lg p-4 hover:border-primary/50 transition-colors">
                        <div className="flex justify-between items-start mb-2">
                            <Link href={`/browse/${ref}/${book.code}`} className="text-xl font-bold hover:text-primary">
                                {book.name}
                            </Link>
                        </div>

                        {book.bestBranch ? (
                            <div className="text-muted-foreground font-serif">
                                {book.bestBranch.content}
                            </div>
                        ) : (
                            <div className="text-sm text-gray-400 italic flex items-center gap-2">
                                No acrostic yet.
                                {testamentBranch && (() => {
                                    // Calculate constraint letter
                                    const words = testamentBranch.content.trim().split(/\s+/)
                                    const index = booksList.indexOf(book.code)
                                    const letter = words[index]?.[0]?.toUpperCase()

                                    if (letter) {
                                        return (
                                            <Link
                                                href={`/create?level=book&ref=${book.code}&parent=${testamentBranch.id}&constraint=${letter}`}
                                                className="text-primary hover:underline not-italic"
                                            >
                                                Create (Start with {letter})
                                            </Link>
                                        )
                                    }
                                    return null
                                })()}
                            </div>
                        )}
                        <div className="mt-2 flex items-center gap-4 text-sm text-gray-500">
                            <span>{book.count} alternatives</span>
                            <Link href={`/browse/${ref}/${book.code}`} className="text-primary hover:underline">
                                View Chapters →
                            </Link>
                            {testamentBranch && (() => {
                                const words = testamentBranch.content.trim().split(/\s+/)
                                const index = booksList.indexOf(book.code)
                                const letter = words[index]?.[0]?.toUpperCase()
                                if (letter) {
                                    return (
                                        <Link
                                            href={`/create?level=book&ref=${book.code}&parent=${testamentBranch.id}&constraint=${letter}`}
                                            className="text-primary hover:underline"
                                        >
                                            + Add Alt
                                        </Link>
                                    )
                                }
                            })()}
                        </div>
                    </div>
                ))}
            </div>
        </div>
    )
}
