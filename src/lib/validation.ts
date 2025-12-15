import { getRequiredWordCount } from './bible-data'

export function validateAcrostic(
    text: string,
    level: string,
    reference: string,
    requiredFirstLetter?: string | null
) {
    if (!text || !text.trim()) {
        return { valid: false, error: "Content cannot be empty" }
    }

    // Verses are just mnemonics, no constraints usually (except maybe length?)
    // Prompt says: "Verse Level: Short mnemonic phrase (NOT an acrostic)"
    if (level === 'verse') {
        return { valid: true }
    }

    // Strict letter counting: ignore spaces, numbers, punctuation
    // "JUST" -> 4 letters. "J U S T" -> 4 letters. "J.U.S.T" -> 4 letters.
    const cleanText = text.replace(/[^a-zA-Z]/g, '')
    const count = cleanText.length

    const requiredCount = getRequiredWordCount(level, reference)

    if (requiredCount > 0 && count !== requiredCount) {
        return {
            valid: false,
            error: `Must have exactly ${requiredCount} letters (currently ${count})`
        }
    }

    if (requiredFirstLetter) {
        if (cleanText.length > 0) {
            const firstLetter = cleanText[0].toUpperCase()
            if (firstLetter !== requiredFirstLetter.toUpperCase()) {
                return {
                    valid: false,
                    error: `Must start with letter "${requiredFirstLetter}" (currently starts with "${firstLetter}")`
                }
            }
        }
    }

    return { valid: true }
}
