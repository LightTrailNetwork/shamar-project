import { NextResponse } from 'next/server'
import { generateCanonicalExport } from '@/lib/export'

export async function GET() {
    try {
        const data = await generateCanonicalExport()
        return NextResponse.json(data)
    } catch (error) {
        console.error('Export failed', error)
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 })
    }
}
