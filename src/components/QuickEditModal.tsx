"use client"

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { X } from 'lucide-react'

interface QuickEditModalProps {
    isOpen: boolean
    onClose: () => void
    level: 'testament' | 'book' | 'chapter' | 'verse'
    reference: string
    currentContent?: string
    parentBranchId?: string
    letterConstraint?: string
    onSuccess: () => void
}

export function QuickEditModal({
    isOpen,
    onClose,
    level,
    reference,
    currentContent,
    parentBranchId,
    letterConstraint,
    onSuccess
}: QuickEditModalProps) {
    const [content, setContent] = useState(currentContent || '')
    const [isSubmitting, setIsSubmitting] = useState(false)
    const [error, setError] = useState<string | null>(null)

    if (!isOpen) return null

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setIsSubmitting(true)
        setError(null)

        const supabase = createClient()

        try {
            // Validation
            if (letterConstraint) {
                const firstLetter = content.trim().charAt(0).toUpperCase()
                if (firstLetter !== letterConstraint.toUpperCase()) {
                    throw new Error(`Must start with letter "${letterConstraint}"`)
                }
            }

            // Get current user
            const { data: { user }, error: authError } = await supabase.auth.getUser()

            if (authError || !user) {
                throw new Error("You must be logged in to contribute.")
            }

            // Create new branch
            const { error: insertError } = await supabase
                .from('branches')
                .insert({
                    level,
                    reference,
                    content,
                    parent_branch_id: parentBranchId,
                    letter_constraint: letterConstraint,
                    created_by: user.id,
                    // For now, auto-create as non-canonical unless admin
                    is_canonical: false
                })

            if (insertError) throw insertError

            onSuccess()
            onClose()
        } catch (err: any) {
            setError(err.message || 'Failed to save')
        } finally {
            setIsSubmitting(false)
        }
    }

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
            <div className="bg-white rounded-xl shadow-2xl w-full max-w-lg overflow-hidden animate-in fade-in zoom-in-95 duration-200">
                <div className="bg-gray-50 px-6 py-4 border-b border-border flex justify-between items-center">
                    <h3 className="font-bold text-lg text-gray-900">
                        {currentContent ? 'Edit Alternative' : 'Add Alternative'}
                    </h3>
                    <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
                        <X className="w-5 h-5" />
                    </button>
                </div>

                <form onSubmit={handleSubmit} className="p-6">
                    <div className="mb-6">
                        <label className="block text-sm font-medium text-gray-700 mb-2">
                            {level === 'verse' ? 'Mnemonic Phrase' : 'Acrostic Content'}
                        </label>
                        <div className="text-xs text-muted-foreground mb-2">
                            {level === 'book' && "Write a sentence where each word starts with a letter corresponding to a chapter."}
                            {level === 'chapter' && "Write a sentence where each word starts with a letter corresponding to a verse."}
                            {level === 'verse' && "Write a short phrase to help recall the verse content."}
                        </div>

                        {letterConstraint && (
                            <div className="mb-2 p-2 bg-yellow-50 text-yellow-800 text-xs font-bold rounded border border-yellow-200">
                                Constraint: Must start with the letter "{letterConstraint}"
                            </div>
                        )}

                        <textarea
                            value={content}
                            onChange={(e) => setContent(e.target.value)}
                            className="w-full h-32 p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-primary resize-none font-serif text-lg leading-relaxed"
                            placeholder="Type here..."
                            autoFocus
                        />
                    </div>

                    {error && (
                        <div className="mb-4 p-3 bg-red-50 text-red-600 text-sm rounded-lg border border-red-100">
                            {error}
                        </div>
                    )}

                    <div className="flex justify-end gap-3">
                        <button
                            type="button"
                            onClick={onClose}
                            className="px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
                        >
                            Cancel
                        </button>
                        <button
                            type="submit"
                            disabled={isSubmitting || !content.trim()}
                            className="px-6 py-2 text-sm font-bold text-white bg-primary hover:bg-primary/90 rounded-lg shadow-sm transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                            {isSubmitting ? 'Saving...' : 'Save Alternative'}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    )
}
