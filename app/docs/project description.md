this is a Rails + ActiveAdmin (AA) project to manage media --medium is a generic object related to a media file, with polymorphic association to various media objects such as photos, videos, audios.  the generic file information is stored in the medium object and media specific information is stored in the child photo, video, audio child objects. 

Medium class includes a state machine engine powered by AASM.  Media are initially in an "unsorted" state but can be moved to a "daily" state for day-to-day snapshots best organized chronologically or to an "event" state (with subevent states) for events that cross over date lines such as "africa trip" which is broken up by subevents like "day 1" further broken into subevents like "morning safari", "dinner" etc.  There are Event and Subevent models that define this "event" hierarchy.

one of the main goals is to manage the file storage in a human readable way so that beyond the lifetime of this project the photos will be accessible and finable with human-readable filenames and organizational scheme. 

currently, intake of  new media is through a job-based file upload that can take multiple files and directory hiearchy. 

files are moved from state to state and these moves are accompanied by callbacks in AASM to move from file location to file location. 

files are associated with multiple datetime records. the default trusted dateteim is from internal file metadata such as exif.  but when exif or other metadata is missing, other versions of the datetime (such as the file stamp or user override) can be assigned. user override takes precedence over other forms of datetime.

the medium's filename is a combination of the datetime stamp + a descriptive name such as "tony dancing".  the user can change the descriptive name but the full filename will always include the timestamp, to ensure files are identifiable and displayed in the correct order. 

there is a mediumsorter custom AA page that presents lists of files in the different states and is used for browsing and dragging files from column to column -- which changes the state -- and other basic managmeent like renaming the medium.  When the medium is renamed, it's new name is stored as a column in the model and AR callbacks ensure the filename on disk is modified

### Auxiliary Files
Each medium file can have an auxiliary folder (`filename_base_aux/`) for related files:
- **Attachments**: User-uploaded files stored in `_aux/attachments/` subfolder. These can be generic (voice annotations, notes) or media-specific (RAW files for photos).
- **Versions**: Edited versions of media files stored in `_aux/versions/` subfolder (see Versions section below).
- The auxiliary folder automatically moves and renames with the main file during state transitions.
- Managed through ActiveAdmin UI with upload/download/delete functionality.

### Media Versioning System
Media files can have multiple versions with a tree-like history structure:
- **Version creation**: Users can create new versions by copying the current primary file or uploading a new file.
- **Version hierarchy**: Versions form a tree structure where each version can have a parent (branching history).
- **Primary version**: One version is designated as "primary" and used for thumbnails, previews, and display.
- **Photo editing**: Photos can be edited with cropping, brightness, and contrast adjustments. Changes are saved to the version file.
- **Version management**: Versions can be deleted (with automatic child re-parenting), made primary, or downloaded.
- **Human-readable history**: A `versions.json` file in the versions folder maintains version metadata for persistence beyond the application.
- **Root file protection**: The original uploaded file is never editable or deletable through the UI.

The version system allows for non-destructive editing while preserving the original and maintaining a clear history of changes.
