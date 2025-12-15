import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getBookInfo, getChapterVerseCount } from '@/lib/bible-data'
import { BranchCard } from '@/components/BranchCard'
import { PathBreadcrumb } from '@/components/PathBreadcrumb'
import { notFound } from 'next/navigation'

interface PageProps {
    params: Promise<{ testament: string; book: string; chapter: string }>
}

export default async function ChapterPage({ params }: PageProps) {
    const { testament, book, chapter } = await params
    const ref = testament.toUpperCase()
    const bookCode = book.toUpperCase()
    const chapterNum = parseInt(chapter)

    const bookInfo = getBookInfo(bookCode)
    if (!bookInfo || bookInfo.testament !== ref || isNaN(chapterNum) || chapterNum > bookInfo.chapterCount) {
        notFound()
    }

    const verseCount = getChapterVerseCount(bookCode, chapterNum)
    const supabase = await createClient()
    const chapterRef = `${bookCode}.${chapterNum}`

    // Fetch verse mnemonics
    const verses = Array.from({ length: verseCount }, (_, i) => i + 1)
    const verseRefs = verses.map(v => `${chapterRef}.${v}`)

    // Fetch verse branches
    const { data: verseBranches } = await supabase
        .from('branches')
        .select('*, votes (vote_value)')
        .eq('level', 'verse')
        .in('reference', verseRefs)

    // Fetch chapter acrostic
    const { data: chapterBranchData } = await supabase
        .from('branches')
        .select('*, votes (vote_value)')
        .eq('level', 'chapter')
        .eq('reference', chapterRef)

    const getScore = (branch: any) => branch.votes?.reduce((acc: number, v: any) => acc + (v.vote_value || 0), 0) || 0

    const chapterBranch = chapterBranchData?.[0] ? {
        ...chapterBranchData[0],
        score: getScore(chapterBranchData[0])
    } : null

    return (
        <div className="max-w-4xl mx-auto py-8 px-4">
            <PathBreadcrumb path={[
                { label: ref === 'OT' ? 'Old Testament' : 'New Testament', href: `/browse/${ref}` },
                { label: bookInfo.name, href: `/browse/${ref}/${bookCode}` },
                { label: `Chapter ${chapter}`, href: `/browse/${ref}/${bookCode}/${chapter}` }
            ]} />

            <h1 className="text-3xl font-bold mb-6">{bookInfo.name} {chapter}</h1>

            {chapterBranch && (
                <div className="mb-12">
                    <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wider mb-2">Chapter Acrostic</h2>
                    <BranchCard
                        branch={chapterBranch}
                        votes={chapterBranch.score}
                        userVote={0}
                    />
                </div>
            )}

            <h2 className="text-2xl font-bold mb-6">Verses</h2>

            <div className="space-y-4">
                {verses.map(verse => {
                    const ref = `${chapterRef}.${verse}`
                    const variants = (verseBranches || [])
                        .filter(b => b.reference === ref)
                        .map(b => ({ ...b, score: getScore(b) }))
                        .sort((a, b) => b.score - a.score)

                    const best = variants[0]

                    return (
                        <div key={verse} className="flex gap-4 p-4 border-b border-border last:border-0 hover:bg-gray-50/50 transition-colors">
                            <div className="w-8 pt-1 font-mono text-sm text-muted-foreground font-bold">{verse}</div>
                            <div className="flex-1">
                                {best ? (
                                    <div className="text-foreground">
                                        {best.content}
                                    </div>
                                ) : (
                                    <div className="text-sm text-gray-400 italic flex items-center gap-2">
                                        {chapterBranch && (
                                            <Link
                                                href={`/create?level=verse&ref=${ref}&parent=${chapterBranch.id}`}
                                                className="text-primary hover:underline not-italic"
                                            >
                                                Add Mnemonic
                                            </Link>
                                        )}
                                        {!chapterBranch && "No chapter acrostic (cannot link)"}
                                    </div>
                                )}
                                {/* Alt link for verses */}
                                {chapterBranch && best && (
                                    <div className="mt-1">
                                        <Link
                                            href={`/create?level=verse&ref=${ref}&parent=${chapterBranch.id}`}
                                            className="text-xs text-primary hover:underline"
                                        >
                                            + Add Alt
                                        </Link>
                                    </div>
                                )}
                            </div>
                        </div>
                    )
                })}
            </div>
        </div>
    )
}
