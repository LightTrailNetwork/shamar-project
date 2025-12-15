import Link from 'next/link'
import { ChevronRight, Home } from 'lucide-react'

interface PathBreadcrumbProps {
    path: {
        label: string
        href: string
    }[]
}

export function PathBreadcrumb({ path }: PathBreadcrumbProps) {
    return (
        <nav className="flex items-center gap-2 text-sm text-muted-foreground mb-8 overflow-x-auto pb-2">
            <Link href="/" className="hover:text-primary flex items-center">
                <Home className="w-4 h-4" />
            </Link>

            {path.map((item, i) => (
                <div key={item.href} className="flex items-center gap-2 whitespace-nowrap">
                    <ChevronRight className="w-4 h-4 text-gray-300" />
                    {i === path.length - 1 ? (
                        <span className="font-medium text-foreground">{item.label}</span>
                    ) : (
                        <Link href={item.href} className="hover:text-primary transition-colors">
                            {item.label}
                        </Link>
                    )}
                </div>
            ))}
        </nav>
    )
}
