import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getBookInfo, getChapterVerseCount } from '@/lib/bible-data'
import { BranchCard } from '@/components/BranchCard'
import { PathBreadcrumb } from '@/components/PathBreadcrumb'
import { notFound } from 'next/navigation'
import { getChapterText } from '@/lib/bible-api'

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

    // Parallel data fetching
    const [verseBranchesResult, chapterBranchResult, bsbVerses] = await Promise.all([
        // Fetch verse mnemonics
        supabase
            .from('branches')
            .select('*, votes (vote_value)')
            .eq('level', 'verse')
            .in('reference', Array.from({ length: verseCount }, (_, i) => `${chapterRef}.${i + 1}`)),

        // Fetch chapter acrostic
        supabase
            .from('branches')
            .select('*, votes (vote_value)')
            .eq('level', 'chapter')
            .eq('reference', chapterRef),

        // Fetch Bible text
        getChapterText(bookCode, chapterNum)
    ])

    const verses = Array.from({ length: verseCount }, (_, i) => i + 1)
    const verseBranches = verseBranchesResult.data
    const chapterBranchData = chapterBranchResult.data

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

            <h1 className="text-3xl font-bold mb-6 font-serif">{bookInfo.name} {chapter}</h1>

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

            <h2 className="text-2xl font-bold mb-6 font-serif">Verses</h2>

            <div className="space-y-6">
                {verses.map(verse => {
                    const ref = `${chapterRef}.${verse}`
                    const variants = (verseBranches || [])
                        .filter(b => b.reference === ref)
                        .map(b => ({ ...b, score: getScore(b) }))
                        .sort((a, b) => b.score - a.score)

                    const best = variants[0]

                    return (
                        <div key={verse} className="flex gap-4 p-6 bg-white rounded-xl shadow-sm border border-gray-100 hover:border-gray-200 transition-all">
                            <div className="pt-1 font-serif text-lg text-primary/60 font-medium w-8 text-center">{verse}</div>
                            <div className="flex-1 space-y-3">
                                {best ? (
                                    <div className="text-xl font-medium text-gray-900 leading-relaxed font-serif">
                                        <span className="text-primary font-bold">{best.content.charAt(0)}</span>
                                        {best.content.slice(1)}
                                    </div>
                                ) : (
                                    <div className="text-sm text-gray-400 italic flex items-center gap-2 py-1">
                                        {chapterBranch && (
                                            <Link
                                                href={`/create?level=verse&ref=${ref}&parent=${chapterBranch.id}`}
                                                className="text-primary hover:underline not-italic font-medium"
                                            >
                                                Add Mnemonic
                                            </Link>
                                        )}
                                        {!chapterBranch && "No chapter acrostic (cannot link)"}
                                    </div>
                                )}

                                {/* Bible Text */}
                                {bsbVerses[verse] && (
                                    <div className="text-gray-600 font-serif leading-relaxed pt-2 border-t border-gray-100">
                                        {bsbVerses[verse]}
                                        <span className="text-[10px] text-gray-300 ml-2 select-none">BSB</span>
                                    </div>
                                )}

                                {/* Alt link for verses */}
                                {chapterBranch && best && (
                                    <div className="pt-2">
                                        <Link
                                            href={`/create?level=verse&ref=${ref}&parent=${chapterBranch.id}`}
                                            className="text-xs text-primary/70 hover:text-primary hover:underline transition-colors"
                                        >
                                            + Add Alternative
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
