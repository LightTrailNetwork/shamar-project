import { CreateBranchForm } from '@/components/CreateBranchForm'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

interface PageProps {
    searchParams: Promise<{ level?: string; ref?: string; parent?: string; constraint?: string }>
}

export default async function CreatePage({ searchParams }: PageProps) {
    const { level, ref, parent, constraint } = await searchParams
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()

    if (!user) {
        return (
            <div className="max-w-md mx-auto py-12 text-center">
                <h1 className="text-2xl font-bold mb-4">Login Required</h1>
                <p className="mb-4">You must be logged in to contribute.</p>
                {/* Simple login button for MVP */}
                <a href="/login" className="text-primary hover:underline">Go to Login</a>
            </div>
        )
    }

    if (!level || !ref) {
        return <div>Invalid parameters</div>
    }

    return (
        <div className="max-w-2xl mx-auto py-12 px-4">
            <h1 className="text-2xl font-bold mb-8">Contribute</h1>
            <CreateBranchForm
                level={level}
                reference={ref}
                parentBranchId={parent || null}
                letterConstraint={constraint || null}
            />
        </div>
    )
}
