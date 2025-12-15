import Link from 'next/link'
import { BIBLE_BOOKS, BIBLE_BOOK_ORDER } from '@/data/bibleBookConstants'

export default function BrowsePage() {
    // Split books into OT and NT
    // Genesis is index 0, Malachi is index 38 (39 books)
    // Matthew is index 39
    const otBooks = BIBLE_BOOK_ORDER.slice(0, 39);
    const ntBooks = BIBLE_BOOK_ORDER.slice(39);

    return (
        <div className="min-h-screen bg-gray-50/50 py-12 md:py-20">
            <div className="container max-w-6xl mx-auto px-4">
                <div className="text-center mb-16">
                    <h1 className="text-4xl md:text-5xl font-serif font-bold text-gray-900 mb-4 tracking-tight">
                        Browse the Library
                    </h1>
                    <p className="text-lg text-gray-600 max-w-2xl mx-auto">
                        Select a Testament to view its main acrostic, or jump directly to a specific book.
                    </p>
                </div>

                <div className="grid md:grid-cols-2 gap-12">
                    {/* Old Testament */}
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                        <div className="bg-gray-900 text-white p-6 flex justify-between items-center">
                            <h2 className="text-2xl font-serif font-bold">Old Testament</h2>
                            <Link
                                href="/browse/OT"
                                className="text-sm font-medium px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg transition-colors"
                            >
                                View Acrostic →
                            </Link>
                        </div>
                        <div className="p-6 md:p-8">
                            <div className="flex flex-wrap gap-2">
                                {otBooks.map(code => (
                                    <Link
                                        key={code}
                                        href={`/browse/OT/${code}`}
                                        className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-gray-50 hover:bg-primary hover:text-white rounded-md transition-colors border border-gray-100 hover:border-primary"
                                    >
                                        {BIBLE_BOOKS[code].name}
                                    </Link>
                                ))}
                            </div>
                        </div>
                    </div>

                    {/* New Testament */}
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                        <div className="bg-primary text-white p-6 flex justify-between items-center">
                            <h2 className="text-2xl font-serif font-bold">New Testament</h2>
                            <Link
                                href="/browse/NT"
                                className="text-sm font-medium px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg transition-colors"
                            >
                                View Acrostic →
                            </Link>
                        </div>
                        <div className="p-6 md:p-8">
                            <div className="flex flex-wrap gap-2">
                                {ntBooks.map(code => (
                                    <Link
                                        key={code}
                                        href={`/browse/NT/${code}`}
                                        className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-gray-50 hover:bg-primary hover:text-white rounded-md transition-colors border border-gray-100 hover:border-primary"
                                    >
                                        {BIBLE_BOOKS[code].name}
                                    </Link>
                                ))}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}
