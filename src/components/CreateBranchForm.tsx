"use client"

import { useState, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import { validateAcrostic } from '@/lib/validation'
import { useRouter } from 'next/navigation'
import { getBookInfo } from '@/lib/bible-data'

interface CreateBranchFormProps {
    level: string
    reference: string
    parentBranchId: string | null
    letterConstraint: string | null
}

export function CreateBranchForm({ level, reference, parentBranchId, letterConstraint }: CreateBranchFormProps) {
    const [content, setContent] = useState('')
    const [error, setError] = useState<string | null>(null)
    const [isValid, setIsValid] = useState(false)
    const [loading, setLoading] = useState(false)
    const [displayTitle, setDisplayTitle] = useState(reference)

    const router = useRouter()
    const supabase = createClient()

    // Format reference for display
    useEffect(() => {
        try {
            const parts = reference.split('.')
            if (parts.length > 0) {
                const bookInfo = getBookInfo(parts[0])
                if (bookInfo) {
                    if (parts.length === 1) {
                        setDisplayTitle(bookInfo.name)
                    } else if (parts.length === 2) {
                        setDisplayTitle(`${bookInfo.name} ${parts[1]}`)
                    } else if (parts.length >= 3) {
                        setDisplayTitle(`${bookInfo.name} ${parts[1]}:${parts[2]}`)
                    }
                }
            }
        } catch (e) {
            console.error("Error formatting title", e)
        }
    }, [reference])

    // Validate on change
    useEffect(() => {
        const result = validateAcrostic(content, level, reference, letterConstraint)
        setIsValid(result.valid || false)
    }, [content, level, reference, letterConstraint])

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()

        const validation = validateAcrostic(content, level, reference, letterConstraint)
        if (!validation.valid) {
            setError(validation.error || "Invalid acrostic")
            return
        }

        setLoading(true)
        setError(null)

        try {
            const { data: { user } } = await supabase.auth.getUser()
            if (!user) {
                setError("You must be logged in to contribute.")
                setLoading(false)
                return
            }

            const { error: dbError } = await supabase.from('branches').insert({
                level: level as any, // Cast to match enum if needed
                reference,
                parent_branch_id: parentBranchId,
                content,
                letter_constraint: letterConstraint,
                created_by: user.id
            })

            if (dbError) throw dbError

            // Redirect
            router.push(`/browse/${reference.replace(/\./g, '/')}`)
            router.refresh()
        } catch (err: any) {
            setError(err.message)
        } finally {
            setLoading(false)
        }
    }

    return (
        <form onSubmit={handleSubmit} className="space-y-6 bg-white p-6 rounded-lg shadow border border-border">
            <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                    New Mnemonics for {displayTitle} ({level})
                </label>
                {letterConstraint && (
                    <p className="text-sm text-amber-600 mb-2 font-medium">
                        Must start with letter: <span className="text-lg font-bold">{letterConstraint}</span>
                    </p>
                )}

                <textarea
                    className="w-full h-32 p-3 border border-gray-300 rounded-md focus:ring-primary focus:border-primary font-serif text-lg"
                    placeholder={level === 'verse' ? "Enter short phrase..." : "Type your acrostic..."}
                    value={content}
                    onChange={(e) => setContent(e.target.value)}
                />
            </div>

            {error && (
                <div className="text-red-500 text-sm">{error}</div>
            )}

            {!isValid && content.length > 0 && !error && (
                <div className="text-amber-500 text-sm">
                    Typing... {validateAcrostic(content, level, reference, letterConstraint).error}
                </div>
            )}

            <button
                type="submit"
                disabled={!isValid || loading}
                className="w-full bg-primary text-white py-2 px-4 rounded hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-medium"
            >
                {loading ? 'Submitting...' : 'Create Contribution'}
            </button>
        </form>
    )
}
