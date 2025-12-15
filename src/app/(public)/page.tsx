import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { BranchCard } from '@/components/BranchCard'

export default async function Home() {
    const supabase = await createClient()

    // Fetch testaments (canonical preferred)
    // We fetch all testaments, then group/filter in JS for this MVP
    const { data: branches } = await supabase
        .from('branches')
        .select('id, content, reference, is_canonical, votes (vote_value)')
        .eq('level', 'testament')

    // Process branches to calculate scores and group by reference
    const processedBranches = (branches || []).map(branch => ({
        ...branch,
        score: branch.votes && Array.isArray(branch.votes)
            ? branch.votes.reduce((acc, v) => acc + (v.vote_value || 0), 0)
            : 0
    }));

    // Group by reference (OT/NT) and pick the winner (canonical or highest voted)
    const testaments = ['OT', 'NT'].map(ref => {
        const variants = processedBranches.filter(b => b.reference === ref);
        // Sort: Canonical first, then by score desc
        variants.sort((a, b) => {
            if (a.is_canonical !== b.is_canonical) return a.is_canonical ? -1 : 1;
            return b.score - a.score;
        });
        return {
            ref,
            name: ref === 'OT' ? 'Old Testament' : 'New Testament',
            bestBranch: variants[0] || null,
            count: variants.length
        };
    });

    return (
        <div className="min-h-screen bg-gray-50/50">
            {/* Hero Section */}
            <div className="bg-white border-b border-gray-100 pb-16 pt-12 md:pb-24 md:pt-20">
                <div className="max-w-4xl mx-auto px-4 text-center">
                    <h1 className="text-5xl md:text-6xl font-serif font-bold text-gray-900 mb-6 tracking-tight">
                        The <span className="text-transparent bg-clip-text bg-linear-to-r from-primary to-blue-600">Shamar</span> Project
                    </h1>
                    <p className="text-xl text-gray-600 max-w-2xl mx-auto leading-relaxed">
                        Scripture Hierarchical Acrostic for Memorization And Recall.
                        <br />
                        <span className="text-gray-500 text-lg mt-2 block">Crowd-sourced mnemonics to help you memorize the entire Bible.</span>
                    </p>
                </div>
            </div>

            <div className="max-w-5xl mx-auto px-4 py-16 space-y-12">
                {testaments.map(t => (
                    <div key={t.ref} className="group">
                        <div className="flex items-end justify-between mb-4 px-2">
                            <Link href={`/browse/${t.ref}`} className="text-2xl font-serif font-bold text-gray-900 group-hover:text-primary transition-colors flex items-center gap-2">
                                {t.name}
                                <span className="opacity-0 -translate-x-2 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-300 text-lg text-gray-400 font-sans">→</span>
                            </Link>
                            <div className="flex gap-4 text-sm font-medium">
                                <Link href={`/create?level=testament&ref=${t.ref}`} className="text-gray-500 hover:text-primary transition-colors">
                                    + Add Alternative
                                </Link>
                                <Link href={`/browse/${t.ref}`} className="text-primary hover:underline">
                                    Browse Books
                                </Link>
                            </div>
                        </div>

                        <div className="bg-white rounded-2xl shadow-sm border border-gray-100/50 p-1 hover:shadow-md transition-shadow duration-300">
                            <div className="p-6 md:p-8">
                                {t.bestBranch ? (
                                    <BranchCard
                                        branch={{
                                            id: t.bestBranch.id,
                                            content: t.bestBranch.content,
                                            is_canonical: t.bestBranch.is_canonical
                                        }}
                                        votes={t.bestBranch.score}
                                        userVote={0}
                                        alternativesCount={t.count - 1}
                                        viewAlternativesHref={`/browse/${t.ref}`}
                                    />
                                ) : (
                                    <div className="text-center py-12 bg-gray-50 rounded-xl border border-dashed border-gray-200">
                                        <p className="text-gray-500 mb-4">No mnemonics yet for this testament.</p>
                                        <Link
                                            href={`/create?level=testament&ref=${t.ref}`}
                                            className="px-6 py-2 bg-white border border-gray-200 text-primary font-medium rounded-lg hover:border-primary/30 hover:shadow-sm transition-all"
                                        >
                                            Create the first one
                                        </Link>
                                    </div>
                                )}
                            </div>

                            {t.count > 1 && (
                                <div className="bg-gray-50/50 px-6 py-3 border-t border-gray-100 rounded-b-xl flex justify-between items-center text-xs font-medium text-gray-500 uppercase tracking-wide">
                                    <span>{t.count} Variations Available</span>
                                    <Link href={`/browse/${t.ref}`} className="hover:text-primary transition-colors">
                                        View all
                                    </Link>
                                </div>
                            )}
                        </div>
                    </div>
                ))}
            </div>
        </div>
    )
}
