export interface BibleVerse {
    number: number
    content: string
}

export async function getChapterText(book: string, chapter: number): Promise<Record<number, string>> {
    try {
        const response = await fetch(`https://bible.helloao.org/api/BSB/${book.toUpperCase()}/${chapter}.json`, {
            next: { revalidate: 3600 } // Cache for 1 hour
        })

        if (!response.ok) {
            console.error(`Failed to fetch Bible text: ${response.statusText}`)
            return {}
        }

        const data = await response.json()
        const verses: Record<number, string> = {}

        if (data && data.chapter && Array.isArray(data.chapter.content)) {
            data.chapter.content.forEach((item: any) => {
                if (item.type === 'verse' && item.number) {
                    // Extract text from content array which might contain objects or strings
                    // Use join(' ') to ensure spaces between segments (fixes "angelsministering" issue)
                    const text = Array.isArray(item.content)
                        ? item.content.map((c: any) => {
                            if (typeof c === 'string') return c;
                            if (c && typeof c === 'object') {
                                if ('text' in c) return c.text;
                                return '';
                            }
                            return '';
                        })
                            .filter((s: string) => s.length > 0) // Remove empty strings to avoid excess spaces
                            .join(' ')
                        : '';

                    if (text) {
                        if (verses[item.number]) {
                            verses[item.number] += ' ' + text;
                        } else {
                            verses[item.number] = text;
                        }
                    }
                }
            })
        }

        return verses
    } catch (error) {
        console.error("Error fetching Bible text:", error)
        return {}
    }
}
