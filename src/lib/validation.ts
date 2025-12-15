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

    const words = text.trim().split(/\s+/)
    const requiredCount = getRequiredWordCount(level, reference)

    if (requiredCount > 0 && words.length !== requiredCount) {
        return {
            valid: false,
            error: `Must have exactly ${requiredCount} words (currently ${words.length})`
        }
    }

    if (requiredFirstLetter) {
        const firstLetter = words[0][0].toUpperCase()
        if (firstLetter !== requiredFirstLetter.toUpperCase()) {
            return {
                valid: false,
                error: `Must start with letter "${requiredFirstLetter}" (currently starts with "${firstLetter}")`
            }
        }
    }

    return { valid: true }
}
