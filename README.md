# ClaimsIQ Sidekick - iOS App

## Project Setup

### Adding Swift Package Dependencies in Xcode

Open the project in Xcode and add these packages:

1. **File → Add Package Dependencies...**

2. Add these packages one by one:
   - **Supabase Swift SDK**
     - URL: `https://github.com/supabase/supabase-swift`
     - Version: Up to Next Major Version → 2.0.0
     - Add to Target: Claims IQ Sidekick 1.5

   - **Nuke (Image Loading)**
     - URL: `https://github.com/kean/Nuke`
     - Version: Up to Next Major Version → 12.0.0
     - Add to Target: Claims IQ Sidekick 1.5
     - Products to Add: Nuke, NukeUI

   - **KeychainAccess (Secure Storage)**
     - URL: `https://github.com/kishikawakatsumi/KeychainAccess`
     - Version: Up to Next Major Version → 4.2.2
     - Add to Target: Claims IQ Sidekick 1.5

### Project Configuration

1. **Minimum iOS Version**: iOS 17.0
2. **Device Support**: iPhone only
3. **Interface**: SwiftUI
4. **Data Persistence**: SwiftData (local) + Supabase (cloud)

### Required Permissions (Already Added)
- Camera Access
- Photo Library Access
- Location Services (When In Use & Always)
- Background Modes (fetch, processing, remote notifications)
- Document Browser Support

### Environment Setup

The Supabase credentials are stored in `Configuration.swift`:
- URL: https://oytebecxauudcmpfqjbl.supabase.co
- Anon Key: Configured in the app

### Database Setup

Run the SQL scripts in the `supabase/` directory in your Supabase project:
1. `database_schema.sql` - Creates all tables
2. `rls_policies.sql` - Sets up Row Level Security
3. `storage_buckets.sql` - Creates storage buckets

### Architecture

- **MVVM Pattern**: ViewModels handle business logic
- **Offline-First**: SwiftData for local storage, sync to Supabase
- **Dependency Injection**: Environment objects for shared state
- **Async/Await**: Modern concurrency for network calls

## Development Workflow

1. All UI is built in SwiftUI
2. Use SwiftData for local data persistence
3. Sync to Supabase when online
4. Handle offline mode gracefully
5. Real-time updates via Supabase Realtime

## Key Features

1. **Tab Navigation**: 5 main tabs (Home, Today, Capture, Claims, Map)
2. **Photo Capture**: With GPS, timestamp, and metadata
3. **Offline Sync**: Queue system for offline operations
4. **Claim Management**: Full CRUD operations
5. **Document Scanning**: PDF and image support
