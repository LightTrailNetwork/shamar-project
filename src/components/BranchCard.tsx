"use client"

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import Link from 'next/link'

interface BranchCardProps {
    branch: {
        id: string
        content: string
        is_canonical: boolean
    }
    votes: number
    userVote: number // 1, -1, or 0
    onVoteChange?: (newVote: number) => void
    alternativesCount?: number
    onViewAlternatives?: () => void
    viewAlternativesHref?: string
}

export function BranchCard({
    branch,
    votes: initialVotes,
    userVote: initialUserVote,
    alternativesCount = 0,
    onViewAlternatives,
    viewAlternativesHref
}: BranchCardProps) {
    const [votes, setVotes] = useState<number>(initialVotes)
    const [userVote, setUserVote] = useState<number>(initialUserVote)
    const [loading, setLoading] = useState(false)

    const supabase = createClient()

    const handleVote = async (value: 1 | -1) => {
        // Optimistic update
        const previousUserVote = userVote
        const previousVotes = votes

        let newVotes = votes
        let newUserVote: number = value

        // Explicit check against current state
        if (userVote === value) {
            // Toggle off
            newVotes -= value
            newUserVote = 0
        } else {
            // Switch or new vote
            newVotes += value - userVote
        }

        setVotes(newVotes)
        setUserVote(newUserVote)
        setLoading(true)

        try {
            const { data: { user } } = await supabase.auth.getUser()
            if (!user) {
                // Revert (handled by auth check in real app, maybe redirect)
                alert("Please login to vote")
                setVotes(previousVotes)
                setUserVote(previousUserVote)
                return
            }

            if (newUserVote === 0) {
                await supabase.from('votes').delete().match({ branch_id: branch.id, user_id: user.id })
            } else {
                // TS narrowing for 1 | -1 is tricky if variable is number. 
                // We know it is 1 or -1 here because if it was 0, it went to if block.
                await supabase.from('votes').upsert({
                    branch_id: branch.id,
                    user_id: user.id,
                    vote_value: newUserVote as 1 | -1
                })
            }
        } catch (error) {
            console.error("Vote failed", error)
            setVotes(previousVotes)
            setUserVote(previousUserVote)
        } finally {
            setLoading(false)
        }
    }

    return (
        <div className="bg-white rounded-lg shadow-sm border border-border p-4 mb-4">
            <div className="flex justify-between items-start mb-3">
                <div className="flex items-center gap-2">
                    {branch.is_canonical && (
                        <span className="bg-success/10 text-success text-xs px-2 py-0.5 rounded-full font-medium flex items-center gap-1">
                            ★ Canonical
                        </span>
                    )}
                    <span className="text-sm text-muted-foreground flex items-center gap-1">
                        ⭐ {votes} votes
                    </span>
                </div>
            </div>

            <div className="text-lg font-medium text-foreground mb-4 p-4 bg-muted/5 rounded-md leading-relaxed font-serif uppercase tracking-wide">
                {branch.content}
            </div>

            <div className="flex justify-between items-center">
                <div className="flex items-center gap-2">
                    <button
                        onClick={() => handleVote(1)}
                        disabled={loading}
                        className={cn(
                            "px-3 py-1.5 rounded text-sm font-medium transition-colors border",
                            userVote === 1
                                ? "bg-primary/10 text-primary border-primary/20"
                                : "bg-transparent text-muted-foreground border-transparent hover:bg-muted"
                        )}
                    >
                        👍 Upvote
                    </button>
                    <button
                        onClick={() => handleVote(-1)}
                        disabled={loading}
                        className={cn(
                            "px-3 py-1.5 rounded text-sm font-medium transition-colors border",
                            userVote === -1
                                ? "bg-red-50 text-red-600 border-red-100"
                                : "bg-transparent text-muted-foreground border-transparent hover:bg-muted"
                        )}
                    >
                        👎 Downvote
                    </button>
                </div>

                {alternativesCount > 0 && (
                    viewAlternativesHref ? (
                        <Link
                            href={viewAlternativesHref}
                            className="text-sm text-primary hover:underline flex items-center gap-1"
                        >
                            See {alternativesCount} alternatives →
                        </Link>
                    ) : onViewAlternatives ? (
                        <button
                            onClick={onViewAlternatives}
                            className="text-sm text-primary hover:underline flex items-center gap-1"
                        >
                            See {alternativesCount} alternatives →
                        </button>
                    ) : null
                )}
            </div>
        </div>
    )
}
