export default function AdminPage() {
    return (
        <div className="max-w-4xl mx-auto py-12 px-4">
            <h1 className="text-3xl font-bold mb-8">Admin Dashboard</h1>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="border p-6 rounded-lg shadow-sm">
                    <h2 className="text-xl font-bold mb-4">Export</h2>
                    <p className="mb-4 text-muted-foreground">Download the canonical export JSON.</p>
                    <a href="/api/export/canonical" target="_blank" className="text-primary hover:underline font-medium">
                        Download Latest Canonical Export
                    </a>
                </div>
                <div className="border p-6 rounded-lg shadow-sm">
                    <h2 className="text-xl font-bold mb-4">Settings</h2>
                    <p className="text-muted-foreground">Manage editable levels and canonical branches.</p>
                    <div className="mt-4 p-2 bg-yellow-50 text-yellow-800 text-sm rounded">
                        Coming soon
                    </div>
                </div>
            </div>
        </div>
    )
}
