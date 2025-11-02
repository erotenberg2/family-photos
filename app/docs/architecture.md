# Family Photos - Architecture Overview

## Project Summary

This is a Rails + ActiveAdmin project for managing family media (photos, videos, audio) with a state-based file organization system. The primary goal is to create human-readable, findable file storage that persists beyond the application's lifetime.

## Core Architecture

### Data Model

#### Polymorphic Media System
- **Medium**: Generic container for all media types
  - Stores: file metadata, timestamps, storage state, MD5 hash
  - Polymorphically belongs to: `Photo`, `Audio`, `Video`
  - Has polymorphic association: `mediable`

- **Photo**: Media-specific record
  - Stores: EXIF data, dimensions, thumbnail/preview paths
  - Extracts GPS coordinates and camera metadata
  - Generates thumbnails (128px) and previews (400px)

- **Audio/Video**: Currently stubbed (future support)

#### State Machine (AASM)
Medium records use a state machine for organization:
- **unsorted**: Initial state, default upload location
- **daily**: Chronological organization by date (requires valid datetime)
- **event_root**: Media associated with event as a whole
- **subevent_level1**: First-level subevents (e.g., "Zimbabwe")
- **subevent_level2**: Second-level subevents (e.g., "morning safari")

State transitions automatically move files on disk via before/after callbacks.

#### Event Hierarchy
- **Event**: Multi-day collections with date ranges
  - Auto-updates date range from media
  - Generates folder names: `YYYY-MM-DD_to_YYYY-MM-DD_Event_Name`
  - Supports unlimited subevents
  
- **Subevent**: Nested organization within events
  - Two levels: parent -> child
  - Creates subdirectories for organized storage
  - Recursively traversed for media aggregation

### Storage System

#### Physical Organization
```
~/Desktop/Family Album/
  ├── unsorted/          # Initial uploads
  ├── daily/
  │   ├── YYYY/
  │   │   ├── MM/
  │   │   │   └── DD/
  │   └── ...
  └── events/
      └── YYYY-MM-DD_to_YYYY-MM-DD_Event_Name/
          ├── (event media)
          ├── Subevent_Name/
          │   ├── (subevent media)
          │   └── Child_Subevent/
          └── ...

~/Desktop/Family Album Internals/
  ├── thumbs/           # 128px thumbnails
  └── previews/         # 400px previews
```

#### Path Computation
File paths are **computed at runtime** from state, not stored in database:
- `Medium#computed_directory_path` determines location based on storage_state
- `Medium#full_file_path` combines directory + current_filename
- Enables automatic file moves when state changes

### Datetime Priority System

Three datetime sources (priority order):
1. **datetime_user**: Manual override (highest priority)
2. **datetime_intrinsic**: Extracted from EXIF/metadata
3. **datetime_inferred**: Upload timestamp (fallback)

Access via: `Medium#effective_datetime`

Filename format: `YYYYMMDD_HHMMSS-descriptive_name.extension`

### Upload & Processing Pipeline

#### Upload Phase
1. Files received via web upload popup
2. Filtered by acceptable types (photo/video/audio)
3. MD5 duplicate detection
4. Saved to `unsorted/` with temporary timestamp
5. UploadLog records batch statistics

#### Post-Processing Phase (Async Job)
1. Extract EXIF metadata (for photos)
2. Generate datetime_intrinsic from EXIF
3. Rename file to use proper datetime-based filename
4. Generate thumbnails and previews (for photos)
5. Extract GPS coordinates (for photos)
6. Update processing timestamps

Jobs:
- `MediumImportJob`: Legacy upload job
- `BatchPostProcessJob`: Enqueues post-processing
- `MediumPostProcessJob`: Individual file processing
- `MediumEnqueueJob`: Queues individual processing

#### Progress Tracking
- Redis-based progress via `ProgressTrackerService`
- Tracks: upload progress, post-processing progress, batch completion
- Accessible via `/family/progress` routes

### File State Management

#### Transition Workflow
1. User triggers transition (drag/drop or action)
2. AASM guard validates transition eligibility
3. Before callback: Captures source path, performs file move
4. State updates: `storage_state` changes
5. After callbacks:
   - Verify file location
   - Update associations (event_id, subevent_id)
   - Refresh event date ranges

#### Automatic File Moves
- `perform_file_move` handles all state transitions
- Resolves filename conflicts via `-(N)` suffix
- Cleans up empty directories
- Updates database to match file system

#### Guard Conditions
- `can_move_to_daily?`: Requires valid datetime
- `can_move_to_event?`: Event must exist
- `can_move_to_subevent?`: Validates level/depth

### User Interface

#### ActiveAdmin Namespaces
- `/admin`: Technical/system admin (AdminUser)
- `/family`: Family management (User with Devise)

#### MediumSorter Page
Custom drag-and-drop interface for state management:
- Three columns: Unsorted, Daily, Events
- Real-time drag-and-drop
- Batch validation before moves
- Hierarchical event display
- Photo thumbnails for visual browsing

#### Media CRUD
- Index: Thumbnails, processing status, storage state
- Show: Full details, preview, EXIF data
- Edit: Filename editing (descriptive name only)
- Batch actions: Move multiple files, create events

### Services

#### FileOrganizationService
Handles batch file operations:
- `move_to_unsorted_storage`: Batch unsorted moves
- `move_to_daily_storage`: Batch daily moves
- `move_to_event_storage`: Batch event moves
- Conflict resolution for duplicate filenames

#### ProgressTrackerService
Redis-based progress tracking:
- Upload sessions
- Post-processing batches
- Real-time updates via polling

#### JsonFormatterService
Pretty-formats JSON for display (EXIF data)

### Authentication & Authorization

#### Devise Integration
- AdminUser: ActiveAdmin authentication
- User: Family access with roles

#### User Roles (Config::FAMILY_ROLES)
- `family_member`: Basic viewing/uploading
- `photo_admin`: Photo management
- `family_admin`: Full access

#### Permission Methods
- Upload, edit, delete permissions by role
- Album visibility by privacy settings
- Active status enforcement

## Key Features

### Human-Readable Storage
- Organized by date or event
- Descriptive filenames preserved
- Timestamps always included for chronological sorting
- No opaque IDs in file paths

### Duplicate Prevention
- MD5 hash uniqueness enforced
- Automatic skipping of duplicate files
- Filename conflict resolution

### Batch Operations
- Drag-and-drop in MediumSorter
- Batch validation before execution
- Progress tracking for large batches
- Atomic transaction-like behavior

### Event Management
- Auto-calculated date ranges
- Renamable folders with auto-cleanup
- Hierarchical subevents
- Media aggregation across entire tree

### Metadata Extraction
- EXIF for photos (via exifr gem)
- GPS coordinates
- Camera make/model
- Thumbnails and previews via MiniMagick

## Technical Stack

- Ruby 3.4.1
- Rails 8.x
- PostgreSQL
- ActiveAdmin
- Devise
- Sidekiq (background jobs)
- Redis (progress tracking)
- MiniMagick (image processing)
- exifr (EXIF extraction)

## State Flow Example

1. Upload photo → `unsorted/` state
2. Post-process → Extract EXIF, rename file, generate thumbs
3. User drags to "Daily 2024" → State: `daily`, path: `daily/2024/12/25/`
4. User creates event "Christmas 2024" → Event folder created
5. User drags to event → State: `event_root`, path: `events/2024-12-25_to_2024-12-25_Christmas_2024/`
6. User creates subevent "Morning Presents" → Level 1 subevent
7. User drags to subevent → State: `subevent_level1`, path: `events/.../Morning_Presents/`

## Notes

- Filenames use `-` as separator between timestamp and descriptive name
- All file moves are logged extensively
- Empty directories are automatically cleaned up
- Orphaned files can be detected and fixed
- Console can be used for manual operations and testing

