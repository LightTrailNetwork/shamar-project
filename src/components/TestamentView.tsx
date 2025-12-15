"use client"

import { useState } from 'react'
import Link from 'next/link'
import { TESTAMENT_SECTIONS } from '@/lib/bible-data'
import { BranchCard } from '@/components/BranchCard'
import { ChevronDown, ChevronRight, List, Layers, Plus, Minus } from 'lucide-react'
import { getChapterData, getVerseData } from '@/app/actions'

interface TestamentViewProps {
    testamentRef: string
    books: {
        code: string
        name: string
        bestBranch: any
        count: number
        chapterCount: number // Added prop
    }[]
    testamentBranch: any
    testamentAlternativesCount: number
    booksList: string[]
}

export function TestamentView({
    testamentRef,
    books,
    testamentBranch,
    testamentAlternativesCount,
    booksList
}: TestamentViewProps) {
    const [viewMode, setViewMode] = useState<'flat' | 'hierarchical'>('flat')
    const [expandedSections, setExpandedSections] = useState<Record<string, boolean>>({})

    // Deep Expansion State
    const [expandedBooks, setExpandedBooks] = useState<Set<string>>(new Set())
    const [expandedChapters, setExpandedChapters] = useState<Set<string>>(new Set())

    // Data Cache
    const [chaptersData, setChaptersData] = useState<Record<string, any[]>>({})
    const [versesData, setVersesData] = useState<Record<string, { verseBranches: any[], bsbVerses: Record<string, string> }>>({})
    const [loading, setLoading] = useState<Record<string, boolean>>({})

    const handleExpandBook = async (bookCode: string, chapterCount: number) => {
        const isExpanded = expandedBooks.has(bookCode)
        const newSet = new Set(expandedBooks)

        if (isExpanded) {
            newSet.delete(bookCode)
            setExpandedBooks(newSet)
        } else {
            newSet.add(bookCode)
            setExpandedBooks(newSet)

            // Load chapters if not present
            if (!chaptersData[bookCode]) {
                setLoading(prev => ({ ...prev, [bookCode]: true }))
                try {
                    // Use exact chapter count range
                    const range = Array.from({ length: chapterCount }, (_, i) => i + 1)
                    const data = await getChapterData(bookCode, range)
                    setChaptersData(prev => ({ ...prev, [bookCode]: data }))

                } catch (e) {
                    console.error(e)
                } finally {
                    setLoading(prev => ({ ...prev, [bookCode]: false }))
                }
            }
        }
    }

    const handleExpandChapter = async (bookCode: string, chapterNum: number) => {
        const key = `${bookCode}.${chapterNum}`
        const isExpanded = expandedChapters.has(key)
        const newSet = new Set(expandedChapters)

        if (isExpanded) {
            newSet.delete(key)
            setExpandedChapters(newSet)
        } else {
            newSet.add(key)
            setExpandedChapters(newSet)

            if (!versesData[key]) {
                setLoading(prev => ({ ...prev, [key]: true }))
                try {
                    const data = await getVerseData(bookCode, chapterNum)
                    setVersesData(prev => ({ ...prev, [key]: data }))
                } catch (e) {
                    console.error(e)
                } finally {
                    setLoading(prev => ({ ...prev, [key]: false }))
                }
            }
        }
    }

    const toggleSection = (idx: number) => {
        setExpandedSections(prev => ({
            ...prev,
            [idx]: !prev[idx]
        }))
    }

    // Toggle All Logic (Top Level)
    const allExpanded = Object.keys(expandedSections).length === (TESTAMENT_SECTIONS[testamentRef as 'OT' | 'NT'] || []).length && Object.values(expandedSections).every(Boolean)

    const toggleAllSections = () => {
        const expand = !allExpanded
        const newState: Record<string, boolean> = {}
        const sections = TESTAMENT_SECTIONS[testamentRef as 'OT' | 'NT'] || []
        sections.forEach((section, idx) => {
            newState[idx] = expand
        })
        setExpandedSections(newState)
    }

    const renderHierarchical = () => {
        if (!testamentBranch) return <div className="text-gray-500 italic">No testament acrostic to organize.</div>

        const allWords = testamentBranch.content.trim().split(/\s+/)
        let bookCursor = 0
        let wordCursor = 0
        const sections = TESTAMENT_SECTIONS[testamentRef as 'OT' | 'NT'] || []

        return (
            <div className="space-y-4">
                <div className="flex justify-end mb-2">
                    <button
                        onClick={toggleAllSections}
                        className="text-xs font-semibold text-primary hover:text-primary/80 transition-colors flex items-center gap-1 cursor-pointer bg-secondary/10 px-3 py-1.5 rounded-full"
                    >
                        {allExpanded ? (
                            <> <Minus className="w-3 h-3" /> Collapse All Sections </>
                        ) : (
                            <> <Plus className="w-3 h-3" /> Expand All Sections </>
                        )}
                    </button>
                </div>

                {sections.map((section, idx) => {
                    const sectionBooksCount = section.count
                    const sectionBooks = books.slice(bookCursor, bookCursor + sectionBooksCount)

                    const sectionWords: string[] = []
                    let currentCount = 0

                    while (currentCount < sectionBooksCount && wordCursor < allWords.length) {
                        const w = allWords[wordCursor]
                        const len = w.replace(/[^a-zA-Z]/g, '').length
                        sectionWords.push(w)
                        currentCount += len
                        wordCursor++
                    }

                    const headerText = sectionWords.join(' ')
                    const isExpanded = expandedSections[idx] ?? false

                    bookCursor += sectionBooksCount

                    return (
                        <div key={idx} className="border border-border rounded-lg overflow-hidden bg-card">
                            <div className="flex items-center gap-4 w-full pr-4 bg-secondary/5 hover:bg-secondary/10 transition-colors">
                                <button
                                    onClick={() => toggleSection(idx)}
                                    className="flex-1 flex items-center justify-between p-4 cursor-pointer"
                                >
                                    <div className="flex items-center gap-3">
                                        {isExpanded ? <ChevronDown className="w-5 h-5 text-primary" /> : <ChevronRight className="w-5 h-5 text-muted-foreground" />}
                                        <h3 className="text-lg font-bold text-primary text-left">{headerText}</h3>
                                    </div>
                                    <span className="text-xs font-bold text-muted-foreground uppercase tracking-wider">{section.name}</span>
                                </button>

                                {/* Expand All Books Logic (Section Level - Keep this) */}
                                {isExpanded && (
                                    <button
                                        onClick={() => {
                                            const allBooksExpanded = sectionBooks.every(b => expandedBooks.has(b.code))
                                            if (allBooksExpanded) {
                                                const newSet = new Set(expandedBooks)
                                                sectionBooks.forEach(b => newSet.delete(b.code))
                                                setExpandedBooks(newSet)
                                            } else {
                                                sectionBooks.forEach(b => {
                                                    if (!expandedBooks.has(b.code)) handleExpandBook(b.code, b.chapterCount)
                                                })
                                            }
                                        }}
                                        className="text-[10px] font-bold text-primary/60 hover:text-primary uppercase tracking-wider cursor-pointer whitespace-nowrap"
                                    >
                                        {sectionBooks.every(b => expandedBooks.has(b.code)) ? "Collapse Books" : "Expand Books"}
                                    </button>
                                )}
                            </div>

                            {isExpanded && (
                                <div className="divide-y divide-border border-t border-border">
                                    {sectionBooks.map(book => {
                                        const bookExpanded = expandedBooks.has(book.code)
                                        const chaptersLoaded = chaptersData[book.code] || []
                                        const isLoading = loading[book.code]

                                        return (
                                            <div key={book.code} className="p-4 pl-8 hover:bg-secondary/5 transition-colors">
                                                <div className="flex flex-col gap-2">
                                                    <div className="flex justify-between items-start">
                                                        <div className="flex items-center gap-2">
                                                            <button
                                                                onClick={(e) => {
                                                                    e.stopPropagation()
                                                                    handleExpandBook(book.code, book.chapterCount)
                                                                }}
                                                                className="p-1 hover:bg-secondary/20 rounded cursor-pointer transition-colors"
                                                            >
                                                                {bookExpanded ? <ChevronDown className="w-4 h-4 text-primary" /> : <ChevronRight className="w-4 h-4 text-muted-foreground" />}
                                                            </button>

                                                            <Link href={`/browse/${testamentRef}/${book.code}`} className="font-bold hover:text-primary">
                                                                {book.name}
                                                            </Link>
                                                        </div>

                                                        <div className="text-xs text-muted-foreground flex gap-2 items-center">
                                                            <span>{book.count} alts</span>
                                                            <Link href={`/browse/${testamentRef}/${book.code}`} className="text-primary hover:underline">
                                                                Go to Page →
                                                            </Link>
                                                        </div>
                                                    </div>

                                                    <div className="pl-7">
                                                        {book.bestBranch ? (
                                                            <div className="text-muted-foreground font-serif text-sm">
                                                                <span className="text-primary font-bold">{book.bestBranch.content.charAt(0)}</span>
                                                                {book.bestBranch.content.slice(1)}
                                                            </div>
                                                        ) : (
                                                            <div className="text-xs text-gray-400 italic">No acrostic.</div>
                                                        )}
                                                    </div>

                                                    {/* Chapters Expansion */}
                                                    {bookExpanded && (
                                                        <div className="mt-4 pl-7 space-y-3 border-l-2 border-primary/10 ml-2">
                                                            <div className="flex justify-between items-center pr-2 mb-2">
                                                                {isLoading && <div className="text-sm text-gray-400 animate-pulse pl-4">Loading chapters...</div>}
                                                                {/* No expand all chapters button as per request */}
                                                            </div>

                                                            {/* Render ALL chapters 1 to chapterCount */}
                                                            {Array.from({ length: book.chapterCount }, (_, i) => i + 1).map(chapterNum => {
                                                                const chapter = chaptersLoaded.find((c: any) => c.reference === `${book.code}.${chapterNum}`)
                                                                const chapterKey = `${book.code}.${chapterNum}`
                                                                const chapterExpanded = expandedChapters.has(chapterKey)
                                                                const verseInfo = versesData[chapterKey]
                                                                const isVerseLoading = loading[chapterKey]

                                                                return (
                                                                    <div key={chapterNum} className="pl-4">
                                                                        <div className="flex items-start gap-2">
                                                                            <button
                                                                                onClick={() => handleExpandChapter(book.code, chapterNum)}
                                                                                className="mt-1 p-0.5 hover:bg-secondary/20 rounded cursor-pointer transition-colors"
                                                                            >
                                                                                {chapterExpanded ? <ChevronDown className="w-3 h-3 text-primary" /> : <ChevronRight className="w-3 h-3 text-muted-foreground" />}
                                                                            </button>
                                                                            <div>
                                                                                <div className="flex items-baseline gap-2">
                                                                                    <span className="text-sm font-semibold text-gray-700">Chapter {chapterNum}</span>
                                                                                    {chapter && <span className="text-xs text-gray-400">{chapter.score} votes</span>}
                                                                                </div>
                                                                                {chapter ? (
                                                                                    <div className="text-sm text-gray-600 font-serif">
                                                                                        <span className="text-primary font-bold">{chapter.content.charAt(0)}</span>
                                                                                        {chapter.content.slice(1)}
                                                                                    </div>
                                                                                ) : (
                                                                                    <div className="text-sm text-gray-400 italic">No acrostic.</div>
                                                                                )}
                                                                            </div>
                                                                        </div>

                                                                        {/* Verses Expansion */}
                                                                        {chapterExpanded && (
                                                                            <div className="mt-2 pl-6 space-y-2 border-l border-border ml-1.5">
                                                                                {isVerseLoading && <div className="text-xs text-gray-400 animate-pulse">Loading verses...</div>}

                                                                                {/* If we have verses loaded, show them. If no mnemonic but BSB text exists, show that too. */}
                                                                                {verseInfo && verseInfo.bsbVerses && Object.keys(verseInfo.bsbVerses).length > 0 ? (
                                                                                    Object.entries(verseInfo.bsbVerses).sort((a, b) => parseInt(a[0]) - parseInt(b[0])).map(([vNum, text]) => {
                                                                                        const verseBranch = verseInfo.verseBranches.find((vb: any) => vb.reference === `${book.code}.${chapterNum}.${vNum}`)

                                                                                        return (
                                                                                            <div key={vNum} className="text-sm py-1">
                                                                                                <div className="flex gap-2">
                                                                                                    <span className="font-mono text-xs text-primary/70 pt-1 shrink-0 w-6 text-right">{vNum}</span>
                                                                                                    <div>
                                                                                                        {verseBranch && (
                                                                                                            <div className="font-serif text-gray-800">
                                                                                                                <span className="text-primary font-bold">{verseBranch.content.charAt(0)}</span>
                                                                                                                {verseBranch.content.slice(1)}
                                                                                                            </div>
                                                                                                        )}
                                                                                                        <div className={`text-xs text-gray-500 pl-2 border-l-2 border-gray-100 italic leading-relaxed ${verseBranch ? 'mt-1' : ''}`}>
                                                                                                            {text}
                                                                                                        </div>
                                                                                                    </div>
                                                                                                </div>
                                                                                            </div>
                                                                                        )
                                                                                    })
                                                                                ) : (
                                                                                    !isVerseLoading && <div className="text-xs text-gray-400 italic">No verses found.</div>
                                                                                )}
                                                                            </div>
                                                                        )}
                                                                    </div>
                                                                )
                                                            })}
                                                        </div>
                                                    )}
                                                </div>
                                            </div>
                                        )
                                    })}
                                </div>
                            )}
                        </div>
                    )
                })}
            </div>
        )
    }

    return (
        <div className="space-y-6">
            {/* View Toggle */}
            <div className="flex justify-center mb-6">
                <div className="inline-flex items-center p-1 rounded-xl bg-secondary/10 border border-border">
                    <button
                        onClick={() => setViewMode('flat')}
                        className={`px-4 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2 cursor-pointer ${viewMode === 'flat'
                            ? 'bg-white shadow-sm text-foreground ring-1 ring-border'
                            : 'text-muted-foreground hover:text-foreground'
                            }`}
                    >
                        <List className="w-4 h-4" />
                        List View
                    </button>
                    <button
                        onClick={() => setViewMode('hierarchical')}
                        className={`px-4 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2 cursor-pointer ${viewMode === 'hierarchical'
                            ? 'bg-white shadow-sm text-foreground ring-1 ring-border'
                            : 'text-muted-foreground hover:text-foreground'
                            }`}
                    >
                        <Layers className="w-4 h-4" />
                        Hierarchy
                    </button>
                </div>
            </div>

            {testamentBranch && (
                <div className="mb-8">
                    <div className="flex justify-between items-end mb-2">
                        <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wider">Testament Acrostic</h2>
                        <Link href={`/create?level=testament&ref=${testamentRef}`} className="text-sm font-medium text-primary hover:underline">
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
            )}

            {viewMode === 'hierarchical' ? renderHierarchical() : (
                <div className="space-y-4">
                    {books.map(book => (
                        <div key={book.code} className="border border-border rounded-lg p-4 hover:border-primary/50 transition-colors">
                            <div className="flex justify-between items-start mb-2">
                                <Link href={`/browse/${testamentRef}/${book.code}`} className="text-xl font-bold hover:text-primary">
                                    {book.name}
                                </Link>
                            </div>

                            {book.bestBranch ? (
                                <div className="text-muted-foreground font-serif">
                                    <span className="text-primary font-bold text-lg">{book.bestBranch.content.charAt(0)}</span>
                                    {book.bestBranch.content.slice(1)}
                                </div>
                            ) : (
                                <div className="text-sm text-gray-400 italic flex items-center gap-2">
                                    No acrostic yet.
                                    {testamentBranch && (() => {
                                        const fullString = testamentBranch.content.replace(/[^a-zA-Z]/g, '')
                                        const index = booksList.indexOf(book.code)
                                        const letter = fullString[index]

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
                                <Link href={`/browse/${testamentRef}/${book.code}`} className="text-primary hover:underline">
                                    View Chapters →
                                </Link>
                                {testamentBranch && (() => {
                                    const fullString = testamentBranch.content.replace(/[^a-zA-Z]/g, '')
                                    const index = booksList.indexOf(book.code)
                                    const letter = fullString[index]
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
            )}
        </div>
    )
}
