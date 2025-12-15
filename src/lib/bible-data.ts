import { BIBLE_BOOKS, BIBLE_BOOK_ORDER } from '@/data/bibleBookConstants'

export type BibleBook = {
    name: string;
    testament: 'OT' | 'NT';
    chapterCount: number;
    verses: number[];
};

// Construct BIBLE_DATA dynamically from the constants
const BIBLE_DATA_CONSTRUCTED: Record<string, any> = {
    OT: {
        books: [] as string[],
        count: 0
    },
    NT: {
        books: [] as string[],
        count: 0
    }
};

// Constants for Testament split (standard Protestant canon)
const OT_BOOKS = new Set([
    "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA",
    "1KI", "2KI", "1CH", "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO",
    "ECC", "SNG", "ISA", "JER", "LAM", "EZK", "DAN", "HOS", "JOL", "AMO",
    "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL"
]);

export const TESTAMENT_SECTIONS = {
    OT: [
        { name: "THE LAW", count: 5 },
        { name: "HISTORY", count: 12 },
        { name: "POETRY & WISDOM", count: 5 },
        { name: "MAJOR PROPHETS", count: 5 },
        { name: "MINOR PROPHETS", count: 12 }
    ],
    NT: [
        { name: "THE GOSPELS", count: 4 },
        { name: "HISTORY", count: 1 },
        { name: "PAUL'S EPISTLES", count: 13 },
        { name: "GENERAL EPISTLES", count: 8 },
        { name: "PROPHECY", count: 1 }
    ]
}

BIBLE_BOOK_ORDER.forEach(code => {
    const bookData = BIBLE_BOOKS[code];
    if (!bookData) return;

    const testament = OT_BOOKS.has(code) ? 'OT' : 'NT';

    // Add to testament list
    BIBLE_DATA_CONSTRUCTED[testament].books.push(code);

    // Add book entry
    BIBLE_DATA_CONSTRUCTED[code] = {
        name: bookData.name,
        testament: testament,
        chapterCount: bookData.verses.length,
        verses: bookData.verses
    };
});

// Update counts
BIBLE_DATA_CONSTRUCTED.OT.count = BIBLE_DATA_CONSTRUCTED.OT.books.length;
BIBLE_DATA_CONSTRUCTED.NT.count = BIBLE_DATA_CONSTRUCTED.NT.books.length;

export const BIBLE_DATA = BIBLE_DATA_CONSTRUCTED as Record<string, any> & { OT: any; NT: any };

export function getBookInfo(bookCode: string) {
    return BIBLE_DATA[bookCode] as BibleBook;
}

export function getChapterVerseCount(bookCode: string, chapter: number) {
    const book = BIBLE_DATA[bookCode];
    if (!book) return 0;
    return book.verses[chapter - 1] || 0;
}

export function getRequiredWordCount(level: string, reference: string) {
    const parts = reference.split('.');

    switch (level) {
        case 'testament':
            return reference === 'OT' ? 39 : 27;
        case 'book':
            return BIBLE_DATA[reference]?.chapterCount || 0;
        case 'chapter':
            // reference is like GEN.1
            // book = GEN, chapter = 1
            if (parts.length >= 2) {
                return getChapterVerseCount(parts[0], parseInt(parts[1]));
            }
            return 0;
        default:
            return 0;
    }
}
