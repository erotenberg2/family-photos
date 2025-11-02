this is a Rails + ActiveAdmin (AA) project to manage media --medium is a generic object related to a media file, with polymorphic association to various media objects such as photos, videos, audios.  the generic file information is stored in the medium object and media specific information is stored in the child photo, video, audio child objects. 

Medium class includes a state machine engine powered by AASM.  Media are initially in an "unsorted" state but can be moved to a "daily" state for day-to-day snapshots best organized chronologically or to an "event" state (with subevent states) for events that cross over date lines such as "africa trip" which is broken up by subevents like "day 1" further broken into subevents like "morning safari", "dinner" etc.  There are Event and Subevent models that define this "event" hierarchy.

one of the main goals is to manage the file storage in a human readable way so that beyond the lifetime of this project the photos will be accessible and finable with human-readable filenames and organizational scheme. 

currently, intake of  new media is through a job-based file upload that can take multiple files and directory hiearchy. 

files are moved from state to state and these moves are accompanied by callbacks in AASM to move from file location to file location. 

files are associated with multiple datetime records. the default trusted dateteim is from internal file metadata such as exif.  but when exif or other metadata is missing, other versions of the datetime (such as the file stamp or user override) can be assigned. user override takes precedence over other forms of datetime.

the medium's filename is a combination of the datetime stamp + a descriptive name such as "tony dancing".  the user can change the descriptive name but the full filename will always include the timestamp, to ensure files are identifiable and displayed in the correct order. 

there is a mediumsorter custom AA page that presents lists of files in the different states and is used for browsing and dragging files from column to column -- which changes the state -- and other basic managmeent like renaming the medium.  When the medium is renamed, it's new name is stored as a column in the model and AR callbacks ensure the filename on disk is modified
- - -
here's what i want to change. the basic model for media should be expanded to include "auxiliary" files.  each medium file and its mediable child can have optional attachments that go in an ausiliary folder of attachments. Generic attachments (that can go onto any mediable type) are attached to medium instance while attachments that are mediable-type specific as well as general.  

examples of "general" attachments could be: voice annotation file. (This is distinguished from audio children of the medium class).  example of media-specfic attachments that can go onto the mediable object would be: RAW file for an image. or images stored at various processing steps.
