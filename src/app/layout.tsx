import type { Metadata } from "next";
import { Inter, Playfair_Display } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-sans" });
const playfair = Playfair_Display({ subsets: ["latin"], variable: "--font-serif" });

export const metadata: Metadata = {
  title: "The Shamar Project",
  description: "Scripture Hierarchical Acrostic for Memorization And Recall",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.variable} ${playfair.variable} font-sans antialiased bg-background text-foreground min-h-screen`}>
        <header className="border-b border-border/40 bg-white/80 backdrop-blur-md sticky top-0 z-50 supports-backdrop-filter:bg-white/60">
          <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
            <a href="/" className="font-serif font-bold text-2xl tracking-tight text-gray-900 flex items-center gap-2">
              <span className="text-primary">✦</span> SHAMAR
            </a>
            <nav className="flex items-center gap-6">
              <a href="/browse" className="text-sm font-medium text-gray-600 hover:text-primary transition-colors">Browse</a>
              <a href="/about" className="text-sm font-medium text-gray-600 hover:text-primary transition-colors">About</a>
              <a
                href="/login"
                className="text-sm bg-gray-900 text-white px-5 py-2 rounded-full font-medium hover:bg-gray-800 transition-all hover:shadow-lg hover:shadow-gray-900/20"
              >
                Login
              </a>
            </nav>
          </div>
        </header>
        <main>
          {children}
        </main>
      </body>
    </html>
  );
}
