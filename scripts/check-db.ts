import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

dotenv.config({ path: '.env.local' })
dotenv.config({ path: '.env' })
dotenv.config({ path: '.ENV' })

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

console.log("URL Loaded:", !!supabaseUrl)
console.log("Anon Key Loaded:", !!supabaseKey)
console.log("Service Role Key Loaded:", !!serviceRoleKey)

const supabase = createClient(supabaseUrl, serviceRoleKey || supabaseKey)

async function check() {
    // Try simple select
    const { data, error } = await supabase.from('branches').select('id, content').limit(5)

    if (error) {
        console.error("Error checking rows:", error)
        return
    }

    console.log("Rows found:", data?.length)
    if (data?.length && data.length > 0) {
        console.log("Sample:", data[0])
    }

    // Count
    const { count, error: countError } = await supabase.from('branches').select('*', { count: 'exact', head: true })
    if (countError) {
        console.error("Count Error:", countError)
    } else {
        console.log("Branches Total Count:", count)
    }
}

check()
