"use client"

import { createClient } from '@/lib/supabase/client'
import { useState } from 'react'

export default function LoginPage() {
    const [email, setEmail] = useState('')
    const [loading, setLoading] = useState(false)
    const [message, setMessage] = useState<string | null>(null)

    const supabase = createClient()

    const handleLogin = async (e: React.FormEvent) => {
        e.preventDefault()
        setLoading(true)
        const { error } = await supabase.auth.signInWithOtp({
            email,
            options: {
                emailRedirectTo: `${location.origin}/auth/callback`
            }
        })
        if (error) {
            setMessage(error.message)
        } else {
            setMessage("Check your email for the magic link!")
        }
        setLoading(false)
    }

    // OAuth handlers would go here

    return (
        <div className="max-w-md mx-auto py-12 px-4">
            <h1 className="text-2xl font-bold mb-6 text-center">Login to Shamar Project</h1>
            <form onSubmit={handleLogin} className="space-y-4">
                <div>
                    <label className="block text-sm font-medium mb-1">Email</label>
                    <input
                        type="email"
                        required
                        value={email}
                        onChange={e => setEmail(e.target.value)}
                        className="w-full p-2 border rounded"
                        placeholder="you@example.com"
                    />
                </div>
                <button
                    type="submit"
                    disabled={loading}
                    className="w-full bg-primary text-white py-2 rounded hover:bg-primary/90"
                >
                    {loading ? 'Sending Magic Link...' : 'Send Magic Link'}
                </button>
            </form>
            {message && (
                <div className="mt-4 p-4 bg-blue-50 text-blue-700 rounded text-center">
                    {message}
                </div>
            )}
        </div>
    )
}
