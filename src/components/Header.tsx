"use client"

import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { User } from '@supabase/supabase-js'
import { useState } from 'react'
import { useRouter } from 'next/navigation'

interface HeaderProps {
    user: User | null
}

export function Header({ user }: HeaderProps) {
    const supabase = createClient()
    const router = useRouter()
    const [isLoading, setIsLoading] = useState(false)
    const [isMenuOpen, setIsMenuOpen] = useState(false)

    const handleLogout = async () => {
        setIsLoading(true)
        await supabase.auth.signOut()
        router.refresh()
        setIsLoading(false)
        setIsMenuOpen(false)
    }

    return (
        <header className="border-b border-border/40 bg-white/80 backdrop-blur-md sticky top-0 z-50 supports-backdrop-filter:bg-white/60">
            <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
                <Link href="/" className="font-serif font-bold text-xl md:text-2xl tracking-tight text-gray-900 flex items-center gap-2">
                    <span className="text-primary">✦</span> SHAMAR
                </Link>

                {/* Mobile Menu Button */}
                <button
                    className="md:hidden text-gray-600"
                    onClick={() => setIsMenuOpen(!isMenuOpen)}
                >
                    {isMenuOpen ? '✕' : '☰'}
                </button>

                {/* Desktop Nav */}
                <nav className="hidden md:flex items-center gap-6">
                    <Link href="/browse" className="text-sm font-medium text-gray-600 hover:text-primary transition-colors">Browse</Link>
                    <Link href="/about" className="text-sm font-medium text-gray-600 hover:text-primary transition-colors">About</Link>

                    {user ? (
                        <div className="flex items-center gap-4">
                            <span className="text-xs text-gray-500 font-medium">
                                {user.email?.split('@')[0]}
                            </span>
                            <button
                                onClick={handleLogout}
                                disabled={isLoading}
                                className="text-sm border border-gray-200 bg-white text-gray-700 px-4 py-2 rounded-full font-medium hover:bg-gray-50 hover:border-gray-300 transition-all"
                            >
                                {isLoading ? '...' : 'Logout'}
                            </button>
                            <Link href="/admin" className="text-sm bg-gray-900 text-white px-4 py-2 rounded-full font-medium hover:bg-gray-800 transition-all hover:shadow-lg hover:shadow-gray-900/20">
                                My Dashboard
                            </Link>
                        </div>
                    ) : (
                        <Link
                            href="/login"
                            className="text-sm bg-gray-900 text-white px-5 py-2 rounded-full font-medium hover:bg-gray-800 transition-all hover:shadow-lg hover:shadow-gray-900/20"
                        >
                            Login
                        </Link>
                    )}
                </nav>

                {/* Mobile Nav Dropdown */}
                {isMenuOpen && (
                    <div className="absolute top-16 left-0 right-0 bg-white border-b border-gray-100 p-4 md:hidden flex flex-col gap-4 shadow-lg animate-in slide-in-from-top-2">
                        <Link href="/browse" className="text-sm font-medium text-gray-600" onClick={() => setIsMenuOpen(false)}>Browse</Link>
                        <Link href="/about" className="text-sm font-medium text-gray-600" onClick={() => setIsMenuOpen(false)}>About</Link>
                        {user ? (
                            <>
                                <Link href="/admin" className="text-sm font-medium text-primary" onClick={() => setIsMenuOpen(false)}>My Dashboard</Link>
                                <button onClick={handleLogout} className="text-sm font-medium text-left text-red-600">Logout</button>
                            </>
                        ) : (
                            <Link href="/login" className="text-sm font-medium text-primary" onClick={() => setIsMenuOpen(false)}>Login</Link>
                        )}
                    </div>
                )}
            </div>
        </header>
    )
}
