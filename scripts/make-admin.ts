import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'
import * as path from 'path'

// Load environment variables
dotenv.config({ path: '.env.local' })
dotenv.config({ path: '.env' })
dotenv.config({ path: '.ENV' })

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY!

if (!supabaseUrl || !serviceRoleKey) {
    console.error("Error: Missing SUPABASE_SERVICE_ROLE_KEY or NEXT_PUBLIC_SUPABASE_URL")
    console.error("Please ensure your .env file contains these keys.")
    process.exit(1)
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
        autoRefreshToken: false,
        persistSession: false
    }
})

async function makeAdmin(email: string) {
    console.log(`Looking up user with email: ${email}...`)

    // 1. Find user by email (Admin API)
    // Note: listUsers is the standard way to search, getUserById requires ID.
    // There isn't a direct "getUserByEmail" in all versions, checking listUsers.
    const { data: { users }, error } = await supabase.auth.admin.listUsers()

    if (error) {
        console.error("Error fetching users:", error)
        return
    }

    const user = users.find(u => u.email?.toLowerCase() === email.toLowerCase())

    if (!user) {
        console.error(`User not found: ${email}`)
        console.log("Make sure you have logged in at least once!")
        return
    }

    console.log(`Found user: ${user.id}`)

    // 2. Update or Create user_profiles
    const { error: updateError } = await supabase
        .from('user_profiles')
        .upsert({
            id: user.id,
            is_admin: true,
            display_name: user.email?.split('@')[0] || 'Admin'
        })
        .select()

    if (updateError) {
        console.error("Error updating profile:", updateError)
    } else {
        console.log(`Success! ${email} is now an admin.`)
        console.log(`(Profile verified/created for ID: ${user.id})`)
        console.log(`Please verify at: http://localhost:3000/admin`)
    }
}

// Get email from command line arg
const emailArg = process.argv[2]
if (!emailArg) {
    console.log("Usage: npx tsx scripts/make-admin.ts <email>")
    process.exit(1)
}

makeAdmin(emailArg)
