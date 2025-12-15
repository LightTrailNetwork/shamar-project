"use client"

import { useState } from 'react'
import { TESTAMENT_SECTIONS, BIBLE_DATA, getBookInfo } from '@/lib/bible-data'
import { ChevronDown, ChevronRight, Edit3 } from 'lucide-react'
import { getChapterData, getVerseData } from '@/app/actions'
import { QuickEditModal } from './QuickEditModal'

interface BibleTreeDashboardProps {
    testaments: {
        ref: string
        bestBranch: any
        count: number
    }[]
    bookMap: Record<string, { bestBranch: any, count: number }>
}

export function BibleTreeDashboard({ testaments, bookMap }: BibleTreeDashboardProps) {
    const [selectedTestament, setSelectedTestament] = useState<'OT' | 'NT'>('OT')

    // Expansion State
    const [expandedSections, setExpandedSections] = useState<Record<string, boolean>>({})
    const [expandedBooks, setExpandedBooks] = useState<Set<string>>(new Set())
    const [expandedChapters, setExpandedChapters] = useState<Set<string>>(new Set())

    // Data Cache
    const [chaptersData, setChaptersData] = useState<Record<string, any[]>>({})
    const [versesData, setVersesData] = useState<Record<string, { verseBranches: any[], bsbVerses: Record<string, string> }>>({})
    const [loading, setLoading] = useState<Record<string, boolean>>({})

    // Modal State
    const [modalState, setModalState] = useState<{
        isOpen: boolean
        level: 'testament' | 'book' | 'chapter' | 'verse'
        reference: string
        currentContent?: string
        letterConstraint?: string
        parentBranchId?: string
    }>({
        isOpen: false,
        level: 'testament',
        reference: ''
    })

    const currentTestament = testaments.find(t => t.ref === selectedTestament)
    const sections = TESTAMENT_SECTIONS[selectedTestament]

    // Visual Mapping Logic
    let bookCursor = 0
    let letterCursor = 0
    const fullAcrosticString = currentTestament?.bestBranch?.content || ""
    const cleanLetters = fullAcrosticString.replace(/[^a-zA-Z]/g, '')

    const renderedSections = sections.map((section) => {
        const sectionBookCount = section.count
        const sectionBooks = (BIBLE_DATA[selectedTestament].books as string[]).slice(bookCursor, bookCursor + sectionBookCount)

        const sectionData = sectionBooks.map((code, i) => {
            const letterChar = cleanLetters[letterCursor + i] || '?'
            return {
                code,
                letter: letterChar,
                ...bookMap[code],
                info: getBookInfo(code)
            }
        })

        bookCursor += sectionBookCount
        letterCursor += sectionBookCount

        return {
            ...section,
            books: sectionData
        }
    })

    // Handlers
    const toggleSection = (name: string) => {
        setExpandedSections(prev => ({ ...prev, [name]: !prev[name] }))
    }

    const handleExpandBook = async (bookCode: string, chapterCount: number) => {
        if (expandedBooks.has(bookCode)) {
            const newSet = new Set(expandedBooks); newSet.delete(bookCode); setExpandedBooks(newSet)
            return
        }

        const newSet = new Set(expandedBooks); newSet.add(bookCode); setExpandedBooks(newSet)

        if (!chaptersData[bookCode]) {
            setLoading(prev => ({ ...prev, [bookCode]: true }))
            try {
                const range = Array.from({ length: chapterCount }, (_, i) => i + 1)
                const data = await getChapterData(bookCode, range)
                setChaptersData(prev => ({ ...prev, [bookCode]: data }))
            } finally {
                setLoading(prev => ({ ...prev, [bookCode]: false }))
            }
        }
    }

    const handleExpandChapter = async (bookCode: string, chapterNum: number) => {
        const key = `${bookCode}.${chapterNum}`
        if (expandedChapters.has(key)) {
            const newSet = new Set(expandedChapters); newSet.delete(key); setExpandedChapters(newSet)
            return
        }

        const newSet = new Set(expandedChapters); newSet.add(key); setExpandedChapters(newSet)

        if (!versesData[key]) {
            setLoading(prev => ({ ...prev, [key]: true }))
            try {
                const data = await getVerseData(bookCode, chapterNum)
                setVersesData(prev => ({ ...prev, [key]: data }))
            } finally {
                setLoading(prev => ({ ...prev, [key]: false }))
            }
        }
    }

    const openModal = (
        level: 'testament' | 'book' | 'chapter' | 'verse',
        reference: string,
        currentContent?: string,
        letterConstraint?: string,
        parentBranchId?: string
    ) => {
        setModalState({
            isOpen: true,
            level,
            reference,
            currentContent,
            letterConstraint,
            parentBranchId
        })
    }

    const closeModal = () => {
        setModalState(prev => ({ ...prev, isOpen: false }))
    }

    const handleSuccess = () => {
        window.location.reload()
    }

    return (
        <div className="space-y-8">
            {/* Testament Toggle */}
            <div className="flex gap-4">
                <button
                    onClick={() => setSelectedTestament('OT')}
                    className={`px-6 py-3 rounded-xl font-bold text-lg transition-all ${selectedTestament === 'OT' ? 'bg-primary text-white shadow-lg scale-105' : 'bg-gray-100 text-gray-500 hover:bg-gray-200'}`}
                >
                    Old Testament
                </button>
                <button
                    onClick={() => setSelectedTestament('NT')}
                    className={`px-6 py-3 rounded-xl font-bold text-lg transition-all ${selectedTestament === 'NT' ? 'bg-primary text-white shadow-lg scale-105' : 'bg-gray-100 text-gray-500 hover:bg-gray-200'}`}
                >
                    New Testament
                </button>
            </div>

            {/* Main Dashboard Area */}
            <div className="grid grid-cols-1 lg:grid-cols-4 gap-8">

                {/* Visualizer Sidebar / Summary */}
                <div className="lg:col-span-1 space-y-6">
                    <div className="bg-white p-6 rounded-2xl shadow-sm border border-border">
                        <h2 className="text-sm font-bold text-muted-foreground uppercase tracking-widest mb-4">Testament Acrostic</h2>
                        {currentTestament?.bestBranch ? (
                            <div className="text-xl font-serif text-primary leading-relaxed">
                                {currentTestament.bestBranch.content}
                            </div>
                        ) : (
                            <div className="text-gray-400 italic">No acrostic defined.</div>
                        )}
                        <button
                            onClick={() => openModal('testament', selectedTestament, currentTestament?.bestBranch?.content)}
                            className="mt-4 w-full py-2 flex items-center justify-center gap-2 text-sm font-medium text-primary bg-primary/5 rounded-lg hover:bg-primary/10 transition-colors"
                        >
                            <Edit3 className="w-4 h-4" />
                            {currentTestament?.bestBranch ? 'Edit Testament Acrostic' : 'Create Testament Acrostic'}
                        </button>
                    </div>

                    <div className="bg-blue-50/50 p-6 rounded-2xl border border-blue-100">
                        <h3 className="text-sm font-bold text-blue-800 uppercase tracking-widest mb-4">Structure</h3>
                        <div className="space-y-3">
                            {renderedSections.map((s, i) => (
                                <div key={i} className="flex justify-between items-center text-sm">
                                    <span className="font-medium text-blue-900">{s.name}</span>
                                    <span className="bg-blue-200 text-blue-800 px-2 py-0.5 rounded-full text-xs font-bold whitespace-nowrap shrink-0">{s.books.length} Books</span>
                                </div>
                            ))}
                        </div>
                    </div>
                </div>

                {/* Tree Editor */}
                <div className="lg:col-span-3 space-y-6">
                    {renderedSections.map((section) => (
                        <div key={section.name} className="bg-white border border-border rounded-xl overflow-hidden shadow-sm">
                            <div
                                onClick={() => toggleSection(section.name)}
                                className="bg-gray-50/80 p-4 flex items-center justify-between cursor-pointer hover:bg-gray-100 transition-colors border-b border-border"
                            >
                                <div className="flex items-center gap-3">
                                    <div className={`p-1 rounded bg-white border border-gray-200 shadow-sm transition-transform ${expandedSections[section.name] ? 'rotate-180' : ''}`}>
                                        <ChevronDown className="w-4 h-4 text-gray-500" />
                                    </div>
                                    <h3 className="font-bold text-lg text-gray-800">{section.name}</h3>
                                </div>
                                <div className="text-xs font-mono bg-gray-200 px-2 py-1 rounded text-gray-600">
                                    {section.books.length} BOOKS
                                </div>
                            </div>

                            {/* Books List */}
                            <div className={`divide-y divide-border transition-all ${expandedSections[section.name] ? 'block' : 'hidden'}`}>
                                {section.books.map((book) => {
                                    const isExpanded = expandedBooks.has(book.code)
                                    const isLoading = loading[book.code]
                                    const chapters = chaptersData[book.code] || []

                                    return (
                                        <div key={book.code} className="p-4 bg-white relative">
                                            {/* Visual Connector Line */}
                                            <div className="absolute left-6 top-0 bottom-0 w-px bg-gray-100 -z-10" />

                                            <div className="flex items-start gap-4">
                                                {/* Acrostic Letter Indicator */}
                                                <div className="flex flex-col items-center gap-1 min-w-12">
                                                    <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center text-xl font-black text-primary border-2 border-white shadow-sm font-serif">
                                                        {book.letter}
                                                    </div>
                                                    <div className="text-[10px] font-bold text-gray-400 uppercase tracking-wider">{book.code}</div>
                                                </div>

                                                <div className="flex-1">
                                                    <div className="flex items-center justify-between">
                                                        <h4
                                                            onClick={() => handleExpandBook(book.code, book.info.chapterCount)}
                                                            className="font-bold text-lg text-gray-900 cursor-pointer hover:text-primary transition-colors flex items-center gap-2"
                                                        >
                                                            {book.info.name}
                                                            <ChevronRight className={`w-4 h-4 text-gray-400 transition-transform ${isExpanded ? 'rotate-90' : ''}`} />
                                                        </h4>
                                                        <div className="flex items-center gap-2">
                                                            <button
                                                                onClick={(e) => {
                                                                    e.stopPropagation()
                                                                    openModal('book', book.code, book.bestBranch?.content, book.letter, currentTestament?.bestBranch?.id)
                                                                }}
                                                                className="p-1.5 hover:bg-gray-100 rounded text-gray-400 hover:text-primary transition-colors"
                                                            >
                                                                <Edit3 className="w-3.5 h-3.5" />
                                                            </button>
                                                        </div>
                                                    </div>

                                                    {/* Book Acrostic Preview */}
                                                    <div className="mt-1 mb-2">
                                                        {book.bestBranch ? (
                                                            <div className="text-gray-600 font-serif leading-relaxed border-l-2 border-primary/20 pl-3">
                                                                <span className="text-primary font-bold">{book.bestBranch.content.charAt(0)}</span>
                                                                {book.bestBranch.content.slice(1)}
                                                            </div>
                                                        ) : (
                                                            <div className="text-gray-400 text-sm italic pl-3 border-l-2 border-transparent">No acrostic set.</div>
                                                        )}
                                                    </div>

                                                    {/* Expanded Chapters */}
                                                    {isExpanded && (
                                                        <div className="mt-4 pl-4 space-y-1">
                                                            {isLoading && <div className="text-sm text-gray-400 animate-pulse">Loading chapters...</div>}

                                                            {/* Render all chapters */}
                                                            {Array.from({ length: book.info.chapterCount }, (_, i) => i + 1).map(cNum => {
                                                                const chapter = chapters.find(c => c.reference === `${book.code}.${cNum}`)
                                                                const chExpanded = expandedChapters.has(`${book.code}.${cNum}`)
                                                                const verseData = versesData[`${book.code}.${cNum}`]
                                                                const chLoading = loading[`${book.code}.${cNum}`]

                                                                return (
                                                                    <div key={cNum} className="border-l border-gray-200 pl-4 py-2 hover:bg-gray-50 rounded-r-lg transition-colors group">
                                                                        <div className="flex items-start justify-between">
                                                                            <div
                                                                                className="cursor-pointer"
                                                                                onClick={() => handleExpandChapter(book.code, cNum)}
                                                                            >
                                                                                <div className="flex items-baseline gap-2">
                                                                                    <span className="font-mono text-xs font-bold text-gray-400 min-w-14 shrink-0">Ch.{cNum}</span>
                                                                                    {chapter ? (
                                                                                        <span className="font-serif text-gray-700 text-sm">
                                                                                            <span className="text-primary font-bold">{chapter.content.charAt(0)}</span>
                                                                                            {chapter.content.slice(1)}
                                                                                        </span>
                                                                                    ) : (
                                                                                        <span className="text-sm text-gray-400 italic">No acrostic</span>
                                                                                    )}
                                                                                </div>
                                                                            </div>
                                                                            <button
                                                                                onClick={() => openModal('chapter', `${book.code}.${cNum}`, chapter?.content, chapter?.content ? undefined : book.bestBranch?.content?.replace(/[^a-zA-Z]/g, '')[cNum - 1], book.bestBranch?.id)}
                                                                                className="opacity-0 group-hover:opacity-100 p-1 hover:bg-gray-200 rounded text-gray-400 hover:text-primary/70 transition-all"
                                                                            >
                                                                                <Edit3 className="w-3 h-3" />
                                                                            </button>
                                                                        </div>

                                                                        {/* Verses */}
                                                                        {chExpanded && (
                                                                            <div className="mt-2 pl-8 space-y-1">
                                                                                {chLoading && <div className="text-xs text-gray-400">Loading verses...</div>}
                                                                                {verseData?.bsbVerses && Object.entries(verseData.bsbVerses).sort((a, b) => parseInt(a[0]) - parseInt(b[0])).map(([vNum, text]) => {
                                                                                    const vBranch = verseData.verseBranches.find(vb => vb.reference === `${book.code}.${cNum}.${vNum}`)
                                                                                    return (
                                                                                        <div key={vNum} className="flex gap-3 py-1 group/verse">
                                                                                            <span className="text-[10px] font-bold text-gray-300 w-4 text-right pt-0.5">{vNum}</span>
                                                                                            <div className="flex-1">
                                                                                                {vBranch && (
                                                                                                    <div className="text-xs font-bold text-gray-700 mb-0.5">{vBranch.content}</div>
                                                                                                )}
                                                                                                <div className="text-[11px] text-gray-500 leading-relaxed italic">{text}</div>
                                                                                            </div>
                                                                                            <button
                                                                                                onClick={() => openModal('verse', `${book.code}.${cNum}.${vNum}`, vBranch?.content, undefined, chapter?.id)}
                                                                                                className="opacity-0 group-hover/verse:opacity-100 p-0.5 hover:bg-gray-200 rounded text-gray-400 hover:text-primary/70 transition-all h-fit"
                                                                                            >
                                                                                                <Edit3 className="w-2.5 h-2.5" />
                                                                                            </button>
                                                                                        </div>
                                                                                    )
                                                                                })}
                                                                            </div>
                                                                        )}
                                                                    </div>
                                                                )
                                                            })}
                                                        </div>
                                                    )}
                                                </div>
                                            </div>
                                        </div>
                                    )
                                })}
                            </div>
                        </div>
                    ))}
                </div>
            </div>

            <QuickEditModal
                isOpen={modalState.isOpen}
                onClose={closeModal}
                level={modalState.level}
                reference={modalState.reference}
                currentContent={modalState.currentContent}
                letterConstraint={modalState.letterConstraint}
                parentBranchId={modalState.parentBranchId}
                onSuccess={handleSuccess}
            />
        </div>
    )
}
