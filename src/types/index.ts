export type Json =
    | string
    | number
    | boolean
    | null
    | { [key: string]: Json | undefined }
    | Json[]

export interface Database {
    public: {
        Tables: {
            branches: {
                Row: {
                    id: string
                    level: 'testament' | 'book' | 'chapter' | 'verse'
                    reference: string
                    parent_branch_id: string | null
                    content: string
                    letter_constraint: string | null
                    created_by: string | null
                    created_at: string
                    updated_at: string
                    is_canonical: boolean
                    status: 'active' | 'archived' | 'flagged' | null
                }
                Insert: {
                    id?: string
                    level: 'testament' | 'book' | 'chapter' | 'verse'
                    reference: string
                    parent_branch_id?: string | null
                    content: string
                    letter_constraint?: string | null
                    created_by?: string | null
                    created_at?: string
                    updated_at?: string
                    is_canonical?: boolean
                    status?: 'active' | 'archived' | 'flagged' | null
                }
                Update: {
                    id?: string
                    level?: 'testament' | 'book' | 'chapter' | 'verse'
                    reference?: string
                    parent_branch_id?: string | null
                    content?: string
                    letter_constraint?: string | null
                    created_by?: string | null
                    created_at?: string
                    updated_at?: string
                    is_canonical?: boolean
                    status?: 'active' | 'archived' | 'flagged' | null
                }
                Relationships: [
                    {
                        foreignKeyName: "branches_created_by_fkey"
                        columns: ["created_by"]
                        isOneToOne: false
                        referencedRelation: "users"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "branches_parent_branch_id_fkey"
                        columns: ["parent_branch_id"]
                        isOneToOne: false
                        referencedRelation: "branches"
                        referencedColumns: ["id"]
                    }
                ]
            }
            votes: {
                Row: {
                    user_id: string
                    branch_id: string
                    vote_value: number
                    voted_at: string
                }
                Insert: {
                    user_id: string
                    branch_id: string
                    vote_value: number
                    voted_at?: string
                }
                Update: {
                    user_id?: string
                    branch_id?: string
                    vote_value?: number
                    voted_at?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "votes_branch_id_fkey"
                        columns: ["branch_id"]
                        isOneToOne: false
                        referencedRelation: "branches"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "votes_user_id_fkey"
                        columns: ["user_id"]
                        isOneToOne: false
                        referencedRelation: "users"
                        referencedColumns: ["id"]
                    }
                ]
            }
        }
        Views: {
            [_ in never]: never
        }
        Functions: {
            [_ in never]: never
        }
        Enums: {
            [_ in never]: never
        }
        CompositeTypes: {
            [_ in never]: never
        }
    }
}
