import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getBookInfo } from '@/lib/bible-data'
import { BranchCard } from '@/components/BranchCard'
import { PathBreadcrumb } from '@/components/PathBreadcrumb'
import { notFound } from 'next/navigation'

interface PageProps {
    params: Promise<{ testament: string; book: string }>
}

export default async function BookPage({ params }: PageProps) {
    const { testament, book } = await params
    const ref = testament.toUpperCase()
    const bookCode = book.toUpperCase()

    const bookInfo = getBookInfo(bookCode)
    if (!bookInfo || bookInfo.testament !== ref) {
        notFound()
    }

    const supabase = await createClient()

    // Prepare list of chapters
    const chapters = Array.from({ length: bookInfo.chapterCount }, (_, i) => i + 1)
    const chapterRefs = chapters.map(c => `${bookCode}.${c}`)

    // Fetch chapter branches
    const { data: chapterBranches } = await supabase
        .from('branches')
        .select('*, votes (vote_value)')
        .eq('level', 'chapter')
        .in('reference', chapterRefs)

    // Fetch book mnemonic
    const { data: bookBranchData } = await supabase
        .from('branches')
        .select('*, votes (vote_value)')
        .eq('level', 'book')
        .eq('reference', bookCode)

    const getScore = (branch: any) => branch.votes?.reduce((acc: number, v: any) => acc + (v.vote_value || 0), 0) || 0

    const bookBranch = bookBranchData?.[0] ? {
        ...bookBranchData[0],
        score: getScore(bookBranchData[0])
    } : null

    return (
        <div className="max-w-4xl mx-auto py-8 px-4">
            <PathBreadcrumb path={[
                { label: ref === 'OT' ? 'Old Testament' : 'New Testament', href: `/browse/${ref}` },
                { label: bookInfo.name, href: `/browse/${ref}/${bookCode}` }
            ]} />

            <h1 className="text-3xl font-bold mb-6">{bookInfo.name}</h1>

            {bookBranch && (
                <div className="mb-12">
                    <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wider mb-2">Book Acrostic</h2>
                    <BranchCard
                        branch={bookBranch}
                        votes={bookBranch.score}
                        userVote={0}
                    />
                </div>
            )}

            <h2 className="text-2xl font-bold mb-6">Chapters</h2>

            <div className="grid gap-4">
                {chapters.map(chapter => {
                    const ref = `${bookCode}.${chapter}`
                    const variants = (chapterBranches || [])
                        .filter(b => b.reference === ref)
                        .map(b => ({ ...b, score: getScore(b) }))
                        .sort((a, b) => b.score - a.score)

                    const best = variants[0]

                    return (
                        <div key={chapter} className="border border-border rounded-lg p-4 hover:border-primary/50 transition-colors">
                            <div className="flex justify-between items-center mb-2">
                                <Link href={`/browse/${testament}/${bookCode}/${chapter}`} className="text-lg font-bold hover:text-primary">
                                    Chapter {chapter}
                                </Link>
                                <span className="text-xs text-muted-foreground">{variants.length} options</span>
                            </div>

                            {best ? (
                                <div className="text-muted-foreground font-serif">
                                    <span className="text-primary font-bold text-lg">{best.content.charAt(0)}</span>
                                    {best.content.slice(1)}
                                </div>
                            ) : (
                                <div className="text-sm text-gray-400 italic flex items-center gap-2">
                                    No acrostic yet.
                                    {bookBranch && (() => {
                                        const words = bookBranch.content.trim().split(/\s+/)
                                        const index = chapter - 1
                                        const letter = words[index]?.[0]?.toUpperCase()

                                        if (letter) {
                                            return (
                                                <Link
                                                    href={`/create?level=chapter&ref=${ref}&parent=${bookBranch.id}&constraint=${letter}`}
                                                    className="text-primary hover:underline not-italic"
                                                >
                                                    Create (Start with {letter})
                                                </Link>
                                            )
                                        }
                                    })()}
                                </div>
                            )}
                            {bookBranch && best && (() => {
                                const words = bookBranch.content.trim().split(/\s+/)
                                const index = chapter - 1
                                const letter = words[index]?.[0]?.toUpperCase()
                                if (letter) {
                                    return (
                                        <div className="mt-2">
                                            <Link
                                                href={`/create?level=chapter&ref=${ref}&parent=${bookBranch.id}&constraint=${letter}`}
                                                className="text-xs text-primary hover:underline"
                                            >
                                                + Add Alternative
                                            </Link>
                                        </div>
                                    )
                                }
                            })()}
                        </div>
                    )
                })}
            </div>
        </div>
    )
}
