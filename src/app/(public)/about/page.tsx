import Link from 'next/link'

export default function AboutPage() {
    return (
        <div className="min-h-screen bg-linear-to-b from-white to-gray-50">
            {/* Hero Section */}
            <div className="relative overflow-hidden pt-20 pb-24 md:pt-32 md:pb-40">
                <div className="container max-w-6xl mx-auto px-4 text-center relative z-10">
                    <div className="inline-block mb-6 px-4 py-1.5 rounded-full bg-blue-50 border border-blue-100 text-primary text-sm font-semibold tracking-wide uppercase">
                        Scripture Memorization Reimagined
                    </div>
                    <h1 className="text-5xl md:text-7xl font-bold text-gray-900 mb-8 tracking-tight font-serif">
                        Guard Your Heart <br className="hidden md:block" />
                        With <span className="text-transparent bg-clip-text bg-linear-to-r from-primary to-blue-600">The Shamar Project</span>
                    </h1>
                    <p className="text-xl md:text-2xl text-gray-600 max-w-3xl mx-auto leading-relaxed mb-10 font-light">
                        A crowd-sourced, hierarchical mnemonic system designed to help you organize, memorize, and recall the entire Bible.
                    </p>
                    <div className="flex flex-col sm:flex-row justify-center gap-4">
                        <Link
                            href="/"
                            className="px-8 py-4 bg-primary text-white text-lg font-medium rounded-xl shadow-lg shadow-blue-500/20 hover:bg-blue-600 hover:shadow-blue-500/30 hover:-translate-y-0.5 transition-all duration-200"
                        >
                            Start Browsing
                        </Link>
                        <Link
                            href="/create"
                            className="px-8 py-4 bg-white text-gray-700 text-lg font-medium rounded-xl border border-gray-200 shadow-sm hover:bg-gray-50 hover:text-primary hover:border-blue-100 transition-all duration-200"
                        >
                            Start Contributing
                        </Link>
                    </div>
                </div>

                {/* Background decoration */}
                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[1000px] h-[1000px] bg-blue-50/50 rounded-full blur-3xl -z-10" />
            </div>

            {/* Meaning Section */}
            <div className="py-20 bg-white border-y border-gray-100">
                <div className="container max-w-5xl mx-auto px-4">
                    <div className="grid md:grid-cols-2 gap-16 items-center">
                        <div className="order-2 md:order-1">
                            <h2 className="text-3xl md:text-4xl font-bold mb-6 font-serif text-gray-900">
                                What is "Shamar"?
                            </h2>
                            <p className="text-lg text-gray-600 leading-relaxed mb-6">
                                In Hebrew, <strong>Shamar (שָׁמַר)</strong> means "to keep, guard, observe, give heed." It is the word used when Adam is told to "keep" the garden, and when we are told to "keep" God's commandments.
                            </p>
                            <div className="bg-gray-50 p-6 rounded-2xl border border-gray-100">
                                <p className="font-mono text-sm text-gray-500 mb-2 uppercase tracking-wider">Our Acronym</p>
                                <ul className="space-y-2">
                                    <li className="flex items-baseline gap-2">
                                        <span className="font-bold text-primary text-xl w-6">S</span>
                                        <span className="text-gray-800 font-medium">cripture</span>
                                    </li>
                                    <li className="flex items-baseline gap-2">
                                        <span className="font-bold text-primary text-xl w-6">H</span>
                                        <span className="text-gray-800 font-medium">ierarchical</span>
                                    </li>
                                    <li className="flex items-baseline gap-2">
                                        <span className="font-bold text-primary text-xl w-6">A</span>
                                        <span className="text-gray-800 font-medium">crostic for</span>
                                    </li>
                                    <li className="flex items-baseline gap-2">
                                        <span className="font-bold text-primary text-xl w-6">M</span>
                                        <span className="text-gray-800 font-medium">emorization</span>
                                    </li>
                                    <li className="flex items-baseline gap-2">
                                        <span className="font-bold text-primary text-xl w-6">A</span>
                                        <span className="text-gray-800 font-medium">nd</span>
                                    </li>
                                    <li className="flex items-baseline gap-2">
                                        <span className="font-bold text-primary text-xl w-6">R</span>
                                        <span className="text-gray-800 font-medium">ecall</span>
                                    </li>
                                </ul>
                            </div>
                        </div>
                        <div className="order-1 md:order-2 flex justify-center">
                            <div className="relative">
                                <div className="absolute inset-0 bg-gradient-to-tr from-blue-100 to-amber-100 rounded-full blur-2xl opacity-60" />
                                <div className="relative bg-white text-9xl font-serif font-black text-gray-900 w-64 h-64 flex items-center justify-center rounded-3xl shadow-2xl border border-gray-100">
                                    שָׁ
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            {/* How It Works - Steps */}
            <div className="py-24 bg-gray-50/50">
                <div className="container max-w-6xl mx-auto px-4">
                    <div className="text-center mb-16">
                        <h2 className="text-3xl md:text-4xl font-bold font-serif mb-4">The MEMORIZATION Stack</h2>
                        <p className="text-gray-600 max-w-2xl mx-auto">
                            A nested system where every letter is a key to unlocking the next layer of scripture.
                        </p>
                    </div>

                    <div className="grid md:grid-cols-4 gap-6">
                        {[
                            { step: 1, title: "Testament", desc: "1 Acrostic per Testament", detail: "Each Letter = 1 Book" },
                            { step: 2, title: "Book", desc: "1 Acrostic per Book", detail: "Each Letter = 1 Chapter" },
                            { step: 3, title: "Chapter", desc: "1 Acrostic per Chapter", detail: "Each Letter = 1 Verse" },
                            { step: 4, title: "Verse", desc: "1 Mnemonic per Verse", detail: "Recall the Content" },
                        ].map((item, i) => (
                            <div key={item.step} className="relative group">
                                <div className="bg-white p-8 rounded-2xl shadow-sm border border-gray-100 h-full hover:shadow-md transition-shadow relative z-10">
                                    <div className="w-12 h-12 bg-primary/10 text-primary rounded-xl flex items-center justify-center font-bold text-xl mb-6 group-hover:bg-primary group-hover:text-white transition-colors">
                                        {item.step}
                                    </div>
                                    <h3 className="text-xl font-bold text-gray-900 mb-2">{item.title}</h3>
                                    <p className="font-medium text-gray-700 mb-1">{item.desc}</p>
                                    <p className="text-sm text-gray-500">{item.detail}</p>
                                </div>
                                {i < 3 && (
                                    <div className="hidden md:block absolute top-1/2 -right-3 w-6 h-0.5 bg-gray-300 z-0" />
                                )}
                            </div>
                        ))}
                    </div>

                    {/* Code Example */}
                    <div className="mt-20 max-w-4xl mx-auto">
                        <div className="bg-[#1e1e1e] rounded-xl shadow-2xl overflow-hidden border border-gray-800">
                            <div className="flex items-center gap-2 px-4 py-3 bg-[#252526] border-b border-gray-800">
                                <div className="w-3 h-3 rounded-full bg-red-500/80" />
                                <div className="w-3 h-3 rounded-full bg-amber-500/80" />
                                <div className="w-3 h-3 rounded-full bg-green-500/80" />
                                <span className="ml-2 text-xs text-gray-500 font-mono">example_flow.txt</span>
                            </div>
                            <div className="p-8 font-mono text-sm md:text-base leading-loose">
                                <div className="opacity-50 mb-2">// 1. The Testament Acrostic (F = First book)</div>
                                <div className="text-emerald-400 font-bold mb-6">
                                    "<span className="text-white border-b-2 border-white/30">F</span>IRST IS THE STORY OF TRUTH..."
                                </div>

                                <div className="opacity-50 mb-2 pl-4 md:pl-8">// 2. The Book (Genesis) Acrostic (F = First chapter)</div>
                                <div className="text-blue-400 font-bold mb-6 pl-4 md:pl-8">
                                    ↳ "<span className="text-white border-b-2 border-white/30">F</span>IRST GOD CREATES ADAM..."
                                </div>

                                <div className="opacity-50 mb-2 pl-8 md:pl-16">// 3. The Chapter (Gen 1) Acrostic (F = First verse)</div>
                                <div className="text-amber-400 font-bold mb-6 pl-8 md:pl-16">
                                    ↳ "<span className="text-white border-b-2 border-white/30">F</span>IRST GOD MADE HEAVENS..."
                                </div>

                                <div className="opacity-50 mb-2 pl-12 md:pl-24">// 4. The Verse (Gen 1:1) Content</div>
                                <div className="text-gray-300 italic pl-12 md:pl-24">
                                    ↳ "God creates everything in the beginning"
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            {/* Community Section */}
            <div className="py-24 bg-white">
                <div className="container max-w-5xl mx-auto px-4 text-center">
                    <h2 className="text-3xl md:text-4xl font-bold font-serif mb-6">Like Git for your Brain</h2>
                    <p className="text-xl text-gray-600 max-w-2xl mx-auto mb-16">
                        Memory works differently for everyone. Shamar is built on the concept of <strong>Branching</strong>.
                        Don't like an acrostic? Create a new branch.
                    </p>

                    <div className="grid md:grid-cols-3 gap-8">
                        <div className="p-8 rounded-2xl bg-gray-50 border border-gray-100 hover:border-primary/20 hover:bg-blue-50/30 transition-colors">
                            <div className="text-4xl mb-4">🗳️</div>
                            <h3 className="text-xl font-bold mb-2">Vote</h3>
                            <p className="text-gray-600">Upvote the mnemonics that stick with you to help others find the best ones.</p>
                        </div>
                        <div className="p-8 rounded-2xl bg-gray-50 border border-gray-100 hover:border-primary/20 hover:bg-blue-50/30 transition-colors">
                            <div className="text-4xl mb-4">🌿</div>
                            <h3 className="text-xl font-bold mb-2">Branch</h3>
                            <p className="text-gray-600">Submit your own alternative acrostics for any book or chapter.</p>
                        </div>
                        <div className="p-8 rounded-2xl bg-gray-50 border border-gray-100 hover:border-primary/20 hover:bg-blue-50/30 transition-colors">
                            <div className="text-4xl mb-4">💎</div>
                            <h3 className="text-xl font-bold mb-2">Export</h3>
                            <p className="text-gray-600">Select your favorite branches and download a personalized memorization pack.</p>
                        </div>
                    </div>

                    <div className="mt-16">
                        <Link
                            href="/create"
                            className="inline-flex items-center px-8 py-4 bg-gray-900 text-white text-lg font-medium rounded-xl hover:bg-gray-800 transition-colors shadow-lg shadow-gray-900/20"
                        >
                            Start Contributing Now
                        </Link>
                    </div>
                </div>
            </div>
        </div>
    )
}
