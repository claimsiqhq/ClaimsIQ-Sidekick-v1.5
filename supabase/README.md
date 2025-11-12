# Supabase Setup Instructions

## Overview
This directory contains the SQL scripts needed to set up the Supabase backend for ClaimsIQ Sidekick.

## Setup Steps

1. **Create Supabase Project** (Already Done)
   - Project URL: https://oytebecxauudcmpfqjbl.supabase.co

2. **Execute Database Schema**
   - Go to Supabase Dashboard > SQL Editor
   - Copy and run the contents of `database_schema.sql`
   - This creates all the necessary tables and indexes

3. **Apply RLS Policies**
   - In the SQL Editor, run the contents of `rls_policies.sql`
   - This secures your data with Row Level Security

4. **Create Storage Buckets**
   - In the SQL Editor, run the contents of `storage_buckets.sql`
   - This creates buckets for photos and documents

## Database Structure

### Core Tables:
- **profiles**: User profile information
- **claims**: Insurance claim records
- **photos**: Photo metadata and storage references
- **documents**: Document metadata and storage references
- **inspections**: Inspection scheduling and tracking
- **inspection_checklist**: Dynamic checklist items
- **activity_timeline**: Activity log for claims
- **sync_queue**: Offline sync management

### Storage Buckets:
- **claim-photos**: Stores claim-related photos (50MB limit per file)
- **documents**: Stores PDFs and documents (100MB limit per file)

## Security
- All tables have Row Level Security (RLS) enabled
- Users can only access their own data
- Storage buckets follow the same security model

## Environment Variables
Add these to your iOS app:
```
SUPABASE_URL=https://oytebecxauudcmpfqjbl.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95dGViZWN4YXV1ZGNtcGZxamJsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI4OTg4NDEsImV4cCI6MjA3ODQ3NDg0MX0.Hu5MlNafpNpH9dpTbz0JylMru-nfWpKkBC7gWE4R7Fo
```
