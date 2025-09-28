// Media Import Popup functionality
window.MediaImportPopup = {
  // Media type definitions
  mediaTypes: {
    photo: {
      extensions: ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.tif', '.webp', '.heic', '.heif'],
      mimeTypes: ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/bmp', 'image/tiff', 'image/heic', 'image/heif', 'image/webp'],
      emoji: '📸'
    },
    audio: {
      extensions: ['.mp3', '.wav', '.aac', '.ogg', '.flac', '.m4a'],
      mimeTypes: ['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/aac', 'audio/ogg', 'audio/flac'],
      emoji: '🎵'
    },
    video: {
      extensions: ['.mp4', '.mov', '.avi', '.mkv', '.webm'],
      mimeTypes: ['video/mp4', 'video/mov', 'video/avi', 'video/mkv', 'video/webm'],
      emoji: '🎬'
    }
  },

  currentFiles: [],
  uploadInProgress: false,
  uploadStartTime: null,
  currentUploadController: null,

  init: function() {
    console.log('MediaImportPopup initialized');
    
    const directoryInput = document.getElementById('directory-input');
    const filePreview = document.getElementById('file-preview');
    const fileList = document.getElementById('file-list');
    const fileCount = document.getElementById('file-count');
    const importButton = document.getElementById('import-button');
    const mediaTypeInputs = document.querySelectorAll('input[name="media_type"]');
    
    console.log('Found elements:', {
      directoryInput: !!directoryInput,
      filePreview: !!filePreview,
      fileList: !!fileList,
      fileCount: !!fileCount,
      importButton: !!importButton,
      mediaTypeInputs: mediaTypeInputs.length
    });
    
    if (!directoryInput) {
      console.log('Directory input not found, popup not on this page');
      return;
    }

    // Store reference to this object for event handlers
    const self = this;

    // Bind event listeners
    directoryInput.addEventListener('change', function(e) {
      console.log('Directory input changed, files:', e.target.files.length);
      self.handleDirectorySelect(e);
    });
    
    if (importButton) {
      importButton.addEventListener('click', function(e) {
        console.log('Import button clicked');
        self.handleImport(e);
      });
    }
    
    if (mediaTypeInputs.length > 0) {
      mediaTypeInputs.forEach(input => {
        input.addEventListener('change', function() {
          console.log('Media type changed');
          self.updateFilePreview();
        });
      });
    }
    
    console.log('Event listeners bound successfully');
  },

  getFileType: function(file) {
    const extension = '.' + file.name.split('.').pop().toLowerCase();
    const mimeType = file.type.toLowerCase();
    
    for (const [type, config] of Object.entries(this.mediaTypes)) {
      if (config.extensions.includes(extension) || config.mimeTypes.includes(mimeType)) {
        return type;
      }
    }
    return 'unknown';
  },

  getSelectedMediaTypes: function() {
    const selectedRadio = document.querySelector('input[name="media_type"]:checked');
    const selectedType = selectedRadio ? selectedRadio.value : 'all';
    return [selectedType]; // Return as array for compatibility
  },

  filterFilesByType: function(files, allowedTypes) {
    if (allowedTypes.includes('all')) {
      return files.filter(file => this.getFileType(file) !== 'unknown');
    }
    
    return files.filter(file => {
      const fileType = this.getFileType(file);
      return allowedTypes.includes(fileType);
    });
  },

  handleDirectorySelect: function(event) {
    const files = Array.from(event.target.files);
    console.log(`Selected ${files.length} files from directory`);
    console.log('First few files:', files.slice(0, 3).map(f => f.name));
    
    this.currentFiles = files;
    console.log('Stored files in currentFiles:', this.currentFiles.length);
    this.updateFilePreview();
  },

  updateFilePreview: function() {
    console.log('updateFilePreview called');
    const filePreview = document.getElementById('file-preview');
    const fileList = document.getElementById('file-list');
    const fileCount = document.getElementById('file-count');
    const importButton = document.getElementById('import-button');
    
    console.log('Preview elements found:', {
      filePreview: !!filePreview,
      fileList: !!fileList,
      fileCount: !!fileCount,
      importButton: !!importButton
    });
    
    if (!filePreview || !fileList || !fileCount) {
      console.error('Missing required elements for file preview');
      return;
    }

    const selectedTypes = this.getSelectedMediaTypes();
    console.log('Selected media types:', selectedTypes);
    console.log('Current files count:', this.currentFiles.length);
    
    const filteredFiles = this.filterFilesByType(this.currentFiles, selectedTypes);
    console.log('Filtered files count:', filteredFiles.length);
    
    fileCount.textContent = `${filteredFiles.length} files selected`;
    
    if (filteredFiles.length === 0) {
      fileList.innerHTML = '<p style="color: #666; font-style: italic;">No compatible files found.</p>';
      if (importButton) importButton.disabled = true;
      return;
    }
    
    if (importButton) importButton.disabled = false;
    
    // Group files by type
    const filesByType = {};
    filteredFiles.forEach(file => {
      const type = this.getFileType(file);
      if (!filesByType[type]) filesByType[type] = [];
      filesByType[type].push(file);
    });
    
    let html = '';
    for (const [type, files] of Object.entries(filesByType)) {
      const config = this.mediaTypes[type];
      const emoji = config ? config.emoji : '📄';
      
      html += `<div style="margin-bottom: 15px;">`;
      html += `<h4 style="margin: 0 0 8px 0; color: #333;">${emoji} ${type.charAt(0).toUpperCase() + type.slice(1)} (${files.length})</h4>`;
      html += `<ul style="margin: 0; padding-left: 20px; max-height: 150px; overflow-y: auto;">`;
      
      files.slice(0, 10).forEach(file => {
        const sizeKB = (file.size / 1024).toFixed(1);
        html += `<li style="margin-bottom: 4px; font-size: 13px;">${file.name} <span style="color: #666;">(${sizeKB} KB)</span></li>`;
      });
      
      if (files.length > 10) {
        html += `<li style="color: #666; font-style: italic;">... and ${files.length - 10} more files</li>`;
      }
      
      html += `</ul></div>`;
    }
    
    fileList.innerHTML = html;
    filePreview.style.display = 'block';
  },

  handleImport: function(event) {
    event.preventDefault();
    
    if (this.uploadInProgress) {
      console.log('Upload already in progress');
      return;
    }
    
    const selectedTypes = this.getSelectedMediaTypes();
    const filteredFiles = this.filterFilesByType(this.currentFiles, selectedTypes);
    
    if (filteredFiles.length === 0) {
      alert('No files selected for import.');
      return;
    }
    
    this.uploadInProgress = true;
    this.uploadStartTime = Date.now();
    
    const importButton = document.getElementById('import-button');
    const uploadFeedback = document.getElementById('upload-feedback');
    
    if (importButton) {
      importButton.disabled = true;
      importButton.textContent = 'Importing...';
    }
    
    if (uploadFeedback) {
      uploadFeedback.innerHTML = '<div style="color: #007cba; font-weight: bold;">Starting import...</div>';
    }
    
    this.uploadFiles(filteredFiles, selectedTypes);
  },

  uploadFiles: function(files, selectedTypes) {
    const chunkSize = 10; // Upload in chunks of 10 files
    const totalFiles = files.length;
    let processedFiles = 0;
    let importedCount = 0;
    let errorCount = 0;
    
    const uploadFeedback = document.getElementById('upload-feedback');
    
    const uploadChunk = (startIndex) => {
      const endIndex = Math.min(startIndex + chunkSize, totalFiles);
      const chunk = files.slice(startIndex, endIndex);
      const isLastChunk = endIndex >= totalFiles;
      
      console.log(`Uploading chunk ${Math.floor(startIndex/chunkSize) + 1}: files ${startIndex + 1}-${endIndex} of ${totalFiles}`);
      
      const formData = new FormData();
      
      // Add files to form data
      chunk.forEach(file => {
        formData.append('media_files[]', file);
      });
      
      // Add client file paths
      chunk.forEach(file => {
        formData.append('client_file_paths[]', file.webkitRelativePath || file.name);
      });
      
      // Add media types
      selectedTypes.forEach(type => {
        formData.append('media_types[]', type);
      });
      
      // Mark if this is the final batch
      if (isLastChunk) {
        formData.append('is_final_batch', 'true');
      }
      
      // Add CSRF token
      const csrfToken = document.querySelector('meta[name="csrf-token"]');
      if (csrfToken) {
        formData.append('authenticity_token', csrfToken.getAttribute('content'));
      }
      
      // Create abort controller for this request
      this.currentUploadController = new AbortController();
      
      fetch(window.location.href, {
        method: 'POST',
        body: formData,
        signal: this.currentUploadController.signal,
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      .then(response => response.json())
      .then(data => {
        processedFiles += chunk.length;
        
        if (data.status === 'success') {
          importedCount += data.imported_count || 0;
          errorCount += data.error_count || 0;
          
          const progress = Math.round((processedFiles / totalFiles) * 100);
          
          if (uploadFeedback) {
            uploadFeedback.innerHTML = `
              <div style="color: #28a745; font-weight: bold;">
                Progress: ${progress}% (${processedFiles}/${totalFiles} files processed)
                <br>Imported: ${importedCount}, Errors: ${errorCount}
              </div>
            `;
          }
          
          if (processedFiles < totalFiles) {
            // Upload next chunk
            setTimeout(() => uploadChunk(endIndex), 100);
          } else {
            // All chunks completed
            this.handleUploadComplete(importedCount, errorCount, totalFiles);
          }
        } else {
          throw new Error(data.message || 'Upload failed');
        }
      })
      .catch(error => {
        if (error.name === 'AbortError') {
          console.log('Upload cancelled by user');
          return;
        }
        
        console.error('Upload error:', error);
        errorCount += chunk.length;
        
        if (uploadFeedback) {
          uploadFeedback.innerHTML = `<div style="color: #dc3545; font-weight: bold;">Error: ${error.message}</div>`;
        }
        
        this.resetUploadState();
      });
    };
    
    // Start uploading from the first chunk
    uploadChunk(0);
  },

  handleUploadComplete: function(importedCount, errorCount, totalFiles) {
    const uploadDuration = ((Date.now() - this.uploadStartTime) / 1000).toFixed(1);
    const uploadFeedback = document.getElementById('upload-feedback');
    
    if (uploadFeedback) {
      uploadFeedback.innerHTML = `
        <div style="color: #28a745; font-weight: bold; padding: 15px; background: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px; margin: 10px 0;">
          ✅ Upload Complete! 
          <br>Duration: ${uploadDuration} seconds
          <br>Imported: ${importedCount}/${totalFiles} files
          ${errorCount > 0 ? `<br><span style="color: #856404;">Errors: ${errorCount}</span>` : ''}
        </div>
      `;
    }
    
    this.resetUploadState();
    
    console.log(`Upload completed in ${uploadDuration}s: ${importedCount} imported, ${errorCount} errors`);
  },

  resetUploadState: function() {
    this.uploadInProgress = false;
    this.uploadStartTime = null;
    this.currentUploadController = null;
    
    const importButton = document.getElementById('import-button');
    if (importButton) {
      importButton.disabled = false;
      importButton.textContent = 'Import Selected Files';
    }
  },

  closePopupWindow: function() {
    if (window.opener) {
      window.close();
    } else {
      console.log('Not in a popup window');
    }
  },

  closeAndRefreshParent: function() {
    if (window.opener) {
      try {
        window.opener.location.reload();
      } catch (e) {
        console.log('Could not refresh parent window:', e);
      }
      window.close();
    } else {
      console.log('Not in a popup window');
      window.location.reload();
    }
  }
};

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  window.MediaImportPopup.init();
});

// Make functions available globally for onclick handlers
window.closePopupWindow = function() {
  return window.MediaImportPopup.closePopupWindow();
};

window.closeAndRefreshParent = function() {
  return window.MediaImportPopup.closeAndRefreshParent();
};

console.log('MediaImportPopup JavaScript loaded');
