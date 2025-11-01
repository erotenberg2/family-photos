// Medium Sorter - Three column hierarchical listbox interface
console.log('[MediumSorter] medium_sorter.js file loaded');

(function() {
  'use strict';

  console.log('[MediumSorter] IIFE executing...');
  console.log('[MediumSorter] Document ready state:', document.readyState);

  let mediaData = {
    unsorted: [],
    daily: [],
    events: []
  };

  // Store tree data by key for quick lookup
  let treeDataByKey = {};
  
  // Store last clicked item per column for range selection
  let lastClickedItemByColumn = {};
  
  // Get multi_photos.png path from Rails data attribute
  function getMultiPhotosPath() {
    const container = document.getElementById('medium-sorter-container');
    if (container && container.dataset.multiPhotosPath) {
      return container.dataset.multiPhotosPath;
    }
    // Fallback to /assets/ if data attribute not available
    return '/assets/multi_photos.png';
  }

  // Wait for the container element to appear (ActiveAdmin may render it after DOMContentLoaded)
  function waitForContainer(callback, maxAttempts = 50) {
    const container = document.getElementById('medium-sorter-container');
    if (container) {
      console.log('[MediumSorter] Container element found!');
      callback();
      return;
    }
    
    if (maxAttempts <= 0) {
      console.error('[MediumSorter] Container element not found after multiple attempts');
      return;
    }
    
    // Check again after a short delay
    setTimeout(() => waitForContainer(callback, maxAttempts - 1), 100);
  }

  // Initialize on page load
  if (document.readyState === 'loading') {
    console.log('[MediumSorter] Document still loading, waiting for DOMContentLoaded...');
    document.addEventListener('DOMContentLoaded', function() {
      console.log('[MediumSorter] DOMContentLoaded fired, waiting for container...');
      waitForContainer(loadMediaData);
    });
  } else {
    console.log('[MediumSorter] Document already loaded, waiting for container...');
    waitForContainer(loadMediaData);
  }

  // Load media data from server
  function loadMediaData() {
    console.log('[MediumSorter] loadMediaData() called');
    
    // Get base path and construct data URL
    const basePath = window.location.pathname;
    const dataUrl = basePath + '/data';
    
    console.log('[MediumSorter] Current pathname:', basePath);
    console.log('[MediumSorter] Constructed data URL:', dataUrl);
    console.log('[MediumSorter] Making fetch request...');
    
    fetch(dataUrl, {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
      .then(response => {
        console.log('[MediumSorter] Fetch response received');
        console.log('[MediumSorter] Response status:', response.status);
        console.log('[MediumSorter] Response ok:', response.ok);
        console.log('[MediumSorter] Response headers:', response.headers);
        
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        return response.json();
      })
      .then(data => {
        console.log('[MediumSorter] JSON data received:', data);
        console.log('[MediumSorter] Unsorted items:', data.unsorted?.length || 0);
        console.log('[MediumSorter] Daily items:', data.daily?.length || 0);
        console.log('[MediumSorter] Events items:', data.events?.length || 0);
        
        mediaData = data;
        // Build lookup map for quick access
        buildTreeDataMap(data);
        console.log('[MediumSorter] Calling renderInterface()...');
        renderInterface();
      })
      .catch(error => {
        console.error('[MediumSorter] Error loading media data:', error);
        console.error('[MediumSorter] Error stack:', error.stack);
        
        const contentElement = document.getElementById('medium-sorter-content');
        if (contentElement) {
          contentElement.innerHTML = 
            '<p style="color: red;">Error loading media data. Please refresh the page.</p>' +
            '<p style="color: red; font-size: 12px;">Error: ' + error.message + '</p>' +
            '<p style="color: red; font-size: 12px;">Check console for details.</p>';
        } else {
          console.error('[MediumSorter] Could not find medium-sorter-content element to display error');
        }
      });
  }

  // Render the three-column interface
  function renderInterface() {
    console.log('[MediumSorter] renderInterface() called');
    
    const container = document.getElementById('medium-sorter-content');
    if (!container) {
      console.error('[MediumSorter] Could not find medium-sorter-content element!');
      return;
    }
    
    console.log('[MediumSorter] Container found, rendering interface...');
    console.log('[MediumSorter] Media data to render:', {
      unsorted: mediaData.unsorted?.length || 0,
      daily: mediaData.daily?.length || 0,
      events: mediaData.events?.length || 0
    });
    
    container.innerHTML = `
      <div class="medium-sorter-wrapper">
        <!-- Unsorted Column -->
        <div class="medium-sorter-column">
          <div class="medium-sorter-header">
            <h3>Unsorted</h3>
            <div class="medium-sorter-filters">
              <button class="filter-btn" data-filter="daterange">Date Range</button>
              <button class="filter-btn" data-filter="date">Date (Y/M/D)</button>
              <button class="filter-btn" data-filter="month">Month (Y/M)</button>
              <button class="filter-btn" data-filter="year">Year (Y)</button>
              <button class="filter-btn filter-clear" data-column="unsorted">Clear</button>
            </div>
          </div>
          <div class="medium-sorter-info" id="unsorted-info">
            <div class="info-placeholder">Click on an item to see details</div>
          </div>
          <div class="medium-sorter-listbox" id="unsorted-listbox" data-column="unsorted">
            ${renderHierarchicalTree(mediaData.unsorted, 'unsorted')}
          </div>
        </div>

        <!-- Daily Column -->
        <div class="medium-sorter-column">
          <div class="medium-sorter-header">
            <h3>Daily</h3>
            <div class="medium-sorter-filters">
              <button class="filter-btn" data-filter="daterange">Date Range</button>
              <button class="filter-btn" data-filter="date">Date (Y/M/D)</button>
              <button class="filter-btn" data-filter="month">Month (Y/M)</button>
              <button class="filter-btn" data-filter="year">Year (Y)</button>
              <button class="filter-btn filter-clear" data-column="daily">Clear</button>
            </div>
          </div>
          <div class="medium-sorter-info" id="daily-info">
            <div class="info-placeholder">Click on an item to see details</div>
          </div>
          <div class="medium-sorter-listbox" id="daily-listbox" data-column="daily">
            ${renderHierarchicalTree(mediaData.daily, 'daily')}
          </div>
        </div>

        <!-- Events Column -->
        <div class="medium-sorter-column">
          <div class="medium-sorter-header">
            <h3>Events</h3>
          </div>
          <div class="medium-sorter-info" id="events-info">
            <div class="info-placeholder">Click on an item to see details</div>
          </div>
          <div class="medium-sorter-listbox" id="events-listbox" data-column="events">
            ${renderHierarchicalTree(mediaData.events, 'events')}
          </div>
        </div>
      </div>
    `;

    console.log('[MediumSorter] Interface HTML rendered');
    
    // Attach event listeners
    console.log('[MediumSorter] Attaching event listeners...');
    attachEventListeners();
    console.log('[MediumSorter] Interface rendering complete');
  }

  // Render hierarchical tree structure
  function renderHierarchicalTree(items, columnType) {
    console.log(`[MediumSorter] renderHierarchicalTree called for ${columnType}:`, items);
    
    if (!items || items.length === 0) {
      console.log(`[MediumSorter] No items for ${columnType}`);
      return '<div class="tree-empty">No items found</div>';
    }

    const result = '<ul class="tree-root">' + items.map(item => renderTreeItem(item, columnType, 0)).join('') + '</ul>';
    console.log(`[MediumSorter] Rendered tree for ${columnType}, length:`, result.length);
    return result;
  }

  // Render a single tree item (recursive)
  function renderTreeItem(item, columnType, depth) {
    const indent = depth * 20;
    const hasChildren = item.children && item.children.length > 0;
    const itemId = `tree-item-${item.key}-${columnType}`;
    // Start collapsed (collapsed icon) - user can expand by clicking
    const iconClass = hasChildren ? 'tree-icon tree-icon-collapsed' : 'tree-icon tree-icon-leaf';
    const itemClass = `tree-item tree-item-${item.type}`;
    
    // For media items, show the icon instead of tree toggle/leaf dot
    let iconHtml = '';
    if (item.type === 'medium' && item.data && item.data.icon) {
      iconHtml = `<span class="tree-media-icon">${item.data.icon}</span>`;
    } else {
      iconHtml = `<span class="tree-toggle" data-item-id="${itemId}"><span class="${iconClass}"></span></span>`;
    }
    
    let html = `
      <li class="${itemClass}" style="padding-left: ${indent}px;" data-key="${item.key}" data-type="${item.type}">
        ${iconHtml}
        <span class="tree-label">${escapeHtml(item.label)}</span>
        ${item.data ? `<span class="tree-meta">${getItemMeta(item)}</span>` : ''}
      </li>
    `;

    if (hasChildren) {
      // Start collapsed (display: none)
      html += `<ul class="tree-children" id="${itemId}" style="display: none;">`;
      html += item.children.map(child => renderTreeItem(child, columnType, depth + 1)).join('');
      html += '</ul>';
    }

    return html;
  }

  // Get metadata HTML for item (thumbnail for photos, empty for others)
  function getItemMeta(item) {
    if (!item.data) return '';
    
    // For photos, show thumbnail
    if (item.data.medium_type === 'photo') {
      let thumbnailHtml = '';
      if (item.data.thumbnail_url) {
        thumbnailHtml = `<img src="${item.data.thumbnail_url}" alt="Thumb" class="tree-thumbnail" onerror="this.style.display='none';">`;
      } else if (item.data.preview_url) {
        thumbnailHtml = `<img src="${item.data.preview_url}" alt="Thumb" class="tree-thumbnail" onerror="this.style.display='none';">`;
      } else if (item.data.medium_id) {
        thumbnailHtml = `<img src="/thumbnails/${item.data.medium_id}" alt="Thumb" class="tree-thumbnail" onerror="this.style.display='none';">`;
      }
      return thumbnailHtml;
    }
    
    // For non-photos, return empty (no metadata shown)
    return '';
  }

  // Escape HTML to prevent XSS
  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // Attach event listeners for tree expansion/collapse and filtering
  function attachEventListeners() {
    console.log('[MediumSorter] attachEventListeners() called');
    
    // Tree toggle functionality
    const toggles = document.querySelectorAll('.tree-toggle');
    console.log('[MediumSorter] Found', toggles.length, 'tree toggles');
    toggles.forEach(toggle => {
      toggle.addEventListener('click', function(e) {
        e.stopPropagation();
        const itemId = this.getAttribute('data-item-id');
        const children = document.getElementById(itemId);
        const icon = this.querySelector('.tree-icon');
        
        if (children) {
          if (children.style.display === 'none') {
            children.style.display = 'block';
            icon.classList.remove('tree-icon-collapsed');
            icon.classList.add('tree-icon-expanded');
          } else {
            children.style.display = 'none';
            icon.classList.remove('tree-icon-expanded');
            icon.classList.add('tree-icon-collapsed');
          }
        }
      });
    });

    // Filter buttons
    const filterButtons = document.querySelectorAll('.filter-btn');
    console.log('[MediumSorter] Found', filterButtons.length, 'filter buttons');
    filterButtons.forEach(btn => {
      btn.addEventListener('click', function(e) {
        e.preventDefault();
        
        if (this.classList.contains('filter-clear')) {
          const column = this.getAttribute('data-column');
          clearFilters(column);
          return;
        }

        const filterType = this.getAttribute('data-filter');
        const column = this.closest('.medium-sorter-column').querySelector('.medium-sorter-listbox').getAttribute('data-column');
        
        showFilterDialog(filterType, column);
      });
    });

    // Multi-select functionality with CMD+Click and Shift+Click
    const treeItems = document.querySelectorAll('.tree-item');
    console.log('[MediumSorter] Found', treeItems.length, 'tree items');
    treeItems.forEach(item => {
      // Prevent text selection using selectstart event (IE/Safari)
      item.addEventListener('selectstart', function(e) {
        // Don't interfere with tree toggle
        if (e.target.closest('.tree-toggle')) return;
        e.preventDefault();
        return false;
      });
      
      item.addEventListener('click', function(e) {
        // Don't interfere with tree toggle
        if (e.target.closest('.tree-toggle')) return;
        
        // Prevent default text selection behavior
        e.preventDefault();
        
        // Clear any existing text selection
        if (window.getSelection) {
          window.getSelection().removeAllRanges();
        } else if (document.selection) {
          document.selection.empty();
        }
        
        // Get the column this item belongs to
        const listbox = this.closest('.medium-sorter-listbox');
        const column = listbox ? listbox.getAttribute('data-column') : null;
        
        if (!column) return;
        
        const isMetaKey = e.metaKey || e.ctrlKey; // CMD on Mac, Ctrl on Windows/Linux
        const isShiftKey = e.shiftKey;
        
        if (isShiftKey && lastClickedItemByColumn[column]) {
          // Range selection: select all items between last clicked and current
          handleRangeSelection(listbox, lastClickedItemByColumn[column], this);
        } else if (isMetaKey) {
          // Toggle selection with CMD/Ctrl
          if (this.classList.contains('selected')) {
            this.classList.remove('selected');
          } else {
            this.classList.add('selected');
          }
          lastClickedItemByColumn[column] = this;
        } else {
          // Regular click: deselect all and select this one
          listbox.querySelectorAll('.tree-item.selected').forEach(selected => {
            selected.classList.remove('selected');
          });
          this.classList.add('selected');
          lastClickedItemByColumn[column] = this;
        }
        
        // Update info panel
        updateInfoPanel(column, listbox);
        
        e.stopPropagation();
      });
    });
    
    console.log('[MediumSorter] Event listeners attached successfully');
  }

  // Build a map of tree data by key for quick lookup
  function buildTreeDataMap(data) {
    treeDataByKey = {};
    
    ['unsorted', 'daily', 'events'].forEach(column => {
      if (data[column]) {
        data[column].forEach(item => {
          indexTreeItem(item, column);
        });
      }
    });
  }

  // Recursively index tree items
  function indexTreeItem(item, column) {
    const key = `${item.key}_${column}`;
    treeDataByKey[key] = item;
    
    if (item.children) {
      item.children.forEach(child => {
        indexTreeItem(child, column);
      });
    }
  }

  // Handle range selection (Shift+Click)
  function handleRangeSelection(listbox, startElement, endElement) {
    // Clear any existing text selection first
    if (window.getSelection) {
      window.getSelection().removeAllRanges();
    } else if (document.selection) {
      document.selection.empty();
    }
    
    // Get all visible tree items in order
    const allItems = Array.from(listbox.querySelectorAll('.tree-item'));
    
    // Filter to only visible items (not hidden by collapsed parents)
    const visibleItems = allItems.filter(item => {
      let parent = item.parentElement;
      while (parent && parent !== listbox) {
        if (parent.classList.contains('tree-children') && parent.style.display === 'none') {
          return false;
        }
        parent = parent.parentElement;
      }
      return true;
    });
    
    const startIndex = visibleItems.indexOf(startElement);
    const endIndex = visibleItems.indexOf(endElement);
    
    if (startIndex === -1 || endIndex === -1) return;
    
    const minIndex = Math.min(startIndex, endIndex);
    const maxIndex = Math.max(startIndex, endIndex);
    
    // Select all items in range
    for (let i = minIndex; i <= maxIndex; i++) {
      visibleItems[i].classList.add('selected');
    }
    
    // Clear text selection again after selecting range (in case browser still tried to select)
    setTimeout(() => {
      if (window.getSelection) {
        window.getSelection().removeAllRanges();
      } else if (document.selection) {
        document.selection.empty();
      }
    }, 0);
  }
  
  // Update info panel based on selected items
  function updateInfoPanel(column, listboxOrElement) {
    const infoPanel = document.getElementById(`${column}-info`);
    if (!infoPanel) return;
    
    // Get listbox element
    const listbox = listboxOrElement.classList && listboxOrElement.classList.contains('medium-sorter-listbox')
      ? listboxOrElement
      : listboxOrElement.closest('.medium-sorter-listbox');
    
    if (!listbox) return;
    
    // Get all selected items in this column
    const selectedItems = Array.from(listbox.querySelectorAll('.tree-item.selected'));
    
    if (selectedItems.length === 0) {
      infoPanel.innerHTML = '<div class="info-placeholder">No item selected</div>';
      return;
    }
    
    if (selectedItems.length === 1) {
      // Single selection - use existing logic
      const itemElement = selectedItems[0];
      const itemKey = itemElement.getAttribute('data-key');
      const itemType = itemElement.getAttribute('data-type');
      const lookupKey = `${itemKey}_${column}`;
      const item = treeDataByKey[lookupKey];
      
      if (!item) {
        infoPanel.innerHTML = '<div class="info-placeholder">Item not found</div>';
        return;
      }
      
      let html = '';
      if (itemType === 'medium') {
        html = renderMediumInfo(item.data);
      } else if (itemType === 'year') {
        html = renderYearContainerInfo(item, column);
      } else if (itemType === 'month') {
        html = renderMonthContainerInfo(item, column);
      } else if (itemType === 'day') {
        html = renderDayContainerInfo(item, column);
      } else if (itemType === 'event') {
        html = renderEventContainerInfo(item, column);
      } else if (itemType === 'subevent_l1') {
        html = renderSL1ContainerInfo(item, column);
      } else if (itemType === 'subevent_l2') {
        html = renderSL2ContainerInfo(item, column);
      } else {
        html = '<div class="info-placeholder">Unknown item type</div>';
      }
      
      infoPanel.innerHTML = html;
    } else {
      // Multiple selection - analyze and render
      const html = renderMultipleSelectionInfo(selectedItems, column);
      infoPanel.innerHTML = html;
    }
  }
  
  // Render info for multiple selections
  function renderMultipleSelectionInfo(selectedItems, column) {
    // Analyze selected items
    const itemsByType = {
      medium: [],
      containers: []
    };
    
    let photoCount = 0;
    let audioCount = 0;
    let videoCount = 0;
    let fileCount = 0;
    
    selectedItems.forEach(itemElement => {
      const itemKey = itemElement.getAttribute('data-key');
      const itemType = itemElement.getAttribute('data-type');
      const lookupKey = `${itemKey}_${column}`;
      const item = treeDataByKey[lookupKey];
      
      if (!item) return;
      
      if (itemType === 'medium' && item.data) {
        itemsByType.medium.push(item);
        if (item.data.medium_type === 'photo') photoCount++;
        else if (item.data.medium_type === 'audio') audioCount++;
        else if (item.data.medium_type === 'video') videoCount++;
        else fileCount++;
      } else {
        itemsByType.containers.push(item);
      }
    });
    
    const totalMedia = itemsByType.medium.length;
    const totalContainers = itemsByType.containers.length;
    const isHybrid = totalMedia > 0 && totalContainers > 0;
    const isAllPhotos = totalMedia > 0 && totalContainers === 0 && audioCount === 0 && videoCount === 0 && fileCount === 0;
    
    let previewHtml = '';
    let titleHtml = '';
    let metaHtml = '';
    
    if (isHybrid) {
      // Hybrid selection: mix of media and containers
      titleHtml = '<div class="info-title">Multiple Items</div>';
      metaHtml = `
        <div class="info-meta">
          ${totalMedia > 0 ? `<div><strong>Media:</strong> ${totalMedia} item${totalMedia !== 1 ? 's' : ''}</div>` : ''}
          ${photoCount > 0 ? `<div>• Photos: ${photoCount}</div>` : ''}
          ${audioCount > 0 ? `<div>• Audio: ${audioCount}</div>` : ''}
          ${videoCount > 0 ? `<div>• Video: ${videoCount}</div>` : ''}
          ${fileCount > 0 ? `<div>• Files: ${fileCount}</div>` : ''}
          ${totalContainers > 0 ? `<div><strong>Containers:</strong> ${totalContainers}</div>` : ''}
        </div>
      `;
      previewHtml = '<div class="info-placeholder-icon">📦</div>';
    } else if (isAllPhotos) {
      // All photos: show multi_photos.png icon
      titleHtml = `<div class="info-title">${photoCount} Photo${photoCount !== 1 ? 's' : ''}</div>`;
      metaHtml = `<div class="info-meta"><div><strong>Selected:</strong> ${photoCount} photo${photoCount !== 1 ? 's' : ''}</div></div>`;
      previewHtml = `<img src="${getMultiPhotosPath()}" alt="Multiple Photos" class="info-preview-image" onerror="this.style.display='none'; this.parentElement.innerHTML='<div class=\\'info-placeholder-icon\\'>📷</div>';" style="width: 150px; height: auto; object-fit: contain;">`;
    } else {
      // Multiple media but not all photos
      titleHtml = '<div class="info-title">Multiple Items</div>';
      metaHtml = `
        <div class="info-meta">
          <div><strong>Selected:</strong> ${totalMedia} item${totalMedia !== 1 ? 's' : ''}</div>
          ${photoCount > 0 ? `<div>• Photos: ${photoCount}</div>` : ''}
          ${audioCount > 0 ? `<div>• Audio: ${audioCount}</div>` : ''}
          ${videoCount > 0 ? `<div>• Video: ${videoCount}</div>` : ''}
          ${fileCount > 0 ? `<div>• Files: ${fileCount}</div>` : ''}
        </div>
      `;
      previewHtml = '<div class="info-placeholder-icon">📦</div>';
    }
    
    return `
      <div class="info-content">
        <div class="info-preview">${previewHtml}</div>
        <div class="info-details">
          ${titleHtml}
          ${metaHtml}
        </div>
      </div>
    `;
  }

  // Render info for medium instance
  function renderMediumInfo(data) {
    if (!data) return '<div class="info-placeholder">No data available</div>';
    
    if (data.medium_type === 'photo') {
      let imageHtml = '';
      // Prefer thumbnail for info panel (smaller), fallback to preview/full image
      if (data.thumbnail_url) {
        imageHtml = `<img src="${data.thumbnail_url}" alt="Thumbnail" class="info-preview-image" data-width="${data.width || ''}" data-height="${data.height || ''}" onerror="this.onerror=null; this.style.display='none'; this.parentElement.innerHTML='<div class=\\'info-placeholder-icon\\'>${data.icon || '📷'}</div>';">`;
      } else if (data.preview_url) {
        imageHtml = `<img src="${data.preview_url}" alt="Preview" class="info-preview-image" data-width="${data.width || ''}" data-height="${data.height || ''}" onerror="this.onerror=null; this.style.display='none'; this.parentElement.innerHTML='<div class=\\'info-placeholder-icon\\'>${data.icon || '📷'}</div>';">`;
      } else if (data.medium_id) {
        // Fallback to full image if no thumbnail/preview
        imageHtml = `<img src="/images/${data.medium_id}" alt="Image" class="info-preview-image" data-width="${data.width || ''}" data-height="${data.height || ''}" onerror="this.onerror=null; this.style.display='none'; this.parentElement.innerHTML='<div class=\\'info-placeholder-icon\\'>${data.icon || '📷'}</div>';">`;
      } else {
        imageHtml = `<div class="info-placeholder-icon">${data.icon || '📷'}</div>`;
      }
      
      // Make preview image clickable to navigate to AA resource page
      const mediumUrl = data.medium_id ? `/family/media/${data.medium_id}` : '#';
      const clickableImageHtml = data.medium_id 
        ? `<a href="${mediumUrl}" class="info-preview-link">${imageHtml}</a>`
        : imageHtml;
      
      return `
        <div class="info-content">
          <div class="info-preview">${clickableImageHtml}</div>
          <div class="info-details">
            <div class="info-title">${escapeHtml(data.filename || data.original_filename)}</div>
            <div class="info-meta">
              <div><strong>Type:</strong> Photo</div>
              ${data.width && data.height ? `<div><strong>Dimensions:</strong> ${data.width} × ${data.height}</div>` : ''}
              ${data.camera_make || data.camera_model ? `<div><strong>Camera:</strong> ${data.camera_make || ''} ${data.camera_model || ''}</div>` : ''}
              ${data.file_size_human ? `<div><strong>Size:</strong> ${data.file_size_human}</div>` : ''}
              ${data.effective_datetime ? `<div><strong>Date:</strong> ${new Date(data.effective_datetime).toLocaleString()}</div>` : ''}
            </div>
          </div>
        </div>
      `;
    } else if (data.medium_type === 'audio') {
      return `
        <div class="info-content">
          <div class="info-preview"><div class="info-placeholder-icon">${data.icon || '🎵'}</div></div>
          <div class="info-details">
            <div class="info-title">Audio</div>
            <div class="info-meta">
              <div><strong>Filename:</strong> ${escapeHtml(data.filename || data.original_filename)}</div>
              ${data.file_size_human ? `<div><strong>Size:</strong> ${data.file_size_human}</div>` : ''}
            </div>
          </div>
        </div>
      `;
    } else if (data.medium_type === 'video') {
      return `
        <div class="info-content">
          <div class="info-preview"><div class="info-placeholder-icon">${data.icon || '🎬'}</div></div>
          <div class="info-details">
            <div class="info-title">Video</div>
            <div class="info-meta">
              <div><strong>Filename:</strong> ${escapeHtml(data.filename || data.original_filename)}</div>
              ${data.file_size_human ? `<div><strong>Size:</strong> ${data.file_size_human}</div>` : ''}
            </div>
          </div>
        </div>
      `;
    }
    
    return '<div class="info-placeholder">Unknown media type</div>';
  }

  // Calculate stats for a container (count media by type)
  function calculateContainerStats(item) {
    const stats = { photo: 0, audio: 0, video: 0, total: 0 };
    
    function countItems(node) {
      if (node.type === 'medium' && node.data) {
        stats.total++;
        const type = node.data.medium_type || 'unknown';
        if (type === 'photo') stats.photo++;
        else if (type === 'audio') stats.audio++;
        else if (type === 'video') stats.video++;
      }
      
      if (node.children) {
        node.children.forEach(child => countItems(child));
      }
    }
    
    countItems(item);
    return stats;
  }

  // Render info for year-container
  function renderYearContainerInfo(item, column) {
    const stats = calculateContainerStats(item);
    return `
      <div class="info-content">
        <div class="info-title">Year: ${escapeHtml(item.label)}</div>
        <div class="info-stats">
          <div><strong>Total Files:</strong> ${stats.total}</div>
          <div><strong>Photos:</strong> ${stats.photo}</div>
          <div><strong>Audio:</strong> ${stats.audio}</div>
          <div><strong>Video:</strong> ${stats.video}</div>
          ${item.children ? `<div><strong>Months:</strong> ${item.children.length}</div>` : ''}
        </div>
      </div>
    `;
  }

  // Render info for month-container
  function renderMonthContainerInfo(item, column) {
    const stats = calculateContainerStats(item);
    const year = item.key.split('/')[0];
    const month = item.key.split('/')[1];
    return `
      <div class="info-content">
        <div class="info-title">Month: ${year}-${month}</div>
        <div class="info-stats">
          <div><strong>Total Files:</strong> ${stats.total}</div>
          <div><strong>Photos:</strong> ${stats.photo}</div>
          <div><strong>Audio:</strong> ${stats.audio}</div>
          <div><strong>Video:</strong> ${stats.video}</div>
          ${item.children ? `<div><strong>Days:</strong> ${item.children.length}</div>` : ''}
        </div>
      </div>
    `;
  }

  // Render info for day-container
  function renderDayContainerInfo(item, column) {
    const stats = calculateContainerStats(item);
    const parts = item.key.split('/');
    return `
      <div class="info-content">
        <div class="info-title">Date: ${parts[0]}-${parts[1]}-${parts[2]}</div>
        <div class="info-stats">
          <div><strong>Total Files:</strong> ${stats.total}</div>
          <div><strong>Photos:</strong> ${stats.photo}</div>
          <div><strong>Audio:</strong> ${stats.audio}</div>
          <div><strong>Video:</strong> ${stats.video}</div>
        </div>
      </div>
    `;
  }

  // Render info for event-container
  function renderEventContainerInfo(item, column) {
    const stats = calculateContainerStats(item);
    const eventData = item.data || {};
    let dateRangeHtml = '';
    if (eventData.start_date && eventData.end_date) {
      const startDate = new Date(eventData.start_date);
      const endDate = new Date(eventData.end_date);
      const startStr = startDate.toLocaleDateString();
      const endStr = endDate.toLocaleDateString();
      dateRangeHtml = `
        <div><strong>Date Range:</strong> ${startStr} to ${endStr}</div>
        ${eventData.duration_days ? `<div><strong>Duration:</strong> ${eventData.duration_days} day${eventData.duration_days !== 1 ? 's' : ''}</div>` : ''}
      `;
    }
    
    return `
      <div class="info-content">
        <div class="info-title">Event: ${escapeHtml(item.label)}</div>
        <div class="info-stats">
          ${dateRangeHtml}
          <div><strong>Total Files:</strong> ${stats.total}</div>
          <div><strong>Photos:</strong> ${stats.photo}</div>
          <div><strong>Audio:</strong> ${stats.audio}</div>
          <div><strong>Video:</strong> ${stats.video}</div>
          ${item.children ? `<div><strong>Subevents:</strong> ${item.children.filter(c => c.type === 'subevent_l1').length}</div>` : ''}
        </div>
      </div>
    `;
  }

  // Render info for SL1-container
  function renderSL1ContainerInfo(item, column) {
    const stats = calculateContainerStats(item);
    return `
      <div class="info-content">
        <div class="info-title">Subevent: ${escapeHtml(item.label)}</div>
        <div class="info-stats">
          <div><strong>Total Files:</strong> ${stats.total}</div>
          <div><strong>Photos:</strong> ${stats.photo}</div>
          <div><strong>Audio:</strong> ${stats.audio}</div>
          <div><strong>Video:</strong> ${stats.video}</div>
        </div>
      </div>
    `;
  }

  // Render info for SL2-container
  function renderSL2ContainerInfo(item, column) {
    const stats = calculateContainerStats(item);
    return `
      <div class="info-content">
        <div class="info-title">Subevent: ${escapeHtml(item.label)}</div>
        <div class="info-stats">
          <div><strong>Total Files:</strong> ${stats.total}</div>
          <div><strong>Photos:</strong> ${stats.photo}</div>
          <div><strong>Audio:</strong> ${stats.audio}</div>
          <div><strong>Video:</strong> ${stats.video}</div>
        </div>
      </div>
    `;
  }

  // Show filter dialog
  function showFilterDialog(filterType, column) {
    let promptText = '';
    let placeholder = '';
    
    switch(filterType) {
      case 'daterange':
        promptText = 'Enter date range (YYYY-MM-DD to YYYY-MM-DD):';
        placeholder = '2024-01-01 to 2024-12-31';
        break;
      case 'date':
        promptText = 'Enter date (YYYY-MM-DD):';
        placeholder = '2024-01-15';
        break;
      case 'month':
        promptText = 'Enter month (YYYY-MM):';
        placeholder = '2024-01';
        break;
      case 'year':
        promptText = 'Enter year (YYYY):';
        placeholder = '2024';
        break;
    }

    const value = prompt(promptText + '\n' + placeholder);
    if (value) {
      applyFilter(filterType, value, column);
    }
  }

  // Apply filter to column
  function applyFilter(filterType, value, column) {
    let filteredData = mediaData[column] || [];
    
    if (filterType === 'daterange') {
      const [start, end] = value.split(' to ').map(d => new Date(d.trim()));
      filteredData = filterByDateRange(filteredData, start, end);
    } else if (filterType === 'date') {
      const date = new Date(value);
      filteredData = filterByDate(filteredData, date);
    } else if (filterType === 'month') {
      const [year, month] = value.split('-').map(Number);
      filteredData = filterByMonth(filteredData, year, month);
    } else if (filterType === 'year') {
      const year = parseInt(value);
      filteredData = filterByYear(filteredData, year);
    }

    // Re-render the listbox
    const listbox = document.getElementById(`${column}-listbox`);
    listbox.innerHTML = renderHierarchicalTree(filteredData, column);
    
    // Clear existing keys for this column and rebuild with filtered data
    Object.keys(treeDataByKey).forEach(key => {
      if (key.endsWith(`_${column}`)) {
        delete treeDataByKey[key];
      }
    });
    
    if (filteredData) {
      filteredData.forEach(item => {
        indexTreeItem(item, column);
      });
    }
    
    // Clear last clicked item for this column (DOM elements are new)
    delete lastClickedItemByColumn[column];
    
    attachEventListeners();
  }

  // Clear filters
  function clearFilters(column) {
    const originalData = mediaData[column] || [];
    const listbox = document.getElementById(`${column}-listbox`);
    listbox.innerHTML = renderHierarchicalTree(originalData, column);
    
    // Rebuild tree data map with original data
    buildTreeDataMap(mediaData);
    
    // Clear last clicked item for this column (DOM elements are new)
    delete lastClickedItemByColumn[column];
    
    attachEventListeners();
  }

  // Filter functions
  function filterByDateRange(items, startDate, endDate) {
    return items.map(item => filterItemTreeByDateRange(item, startDate, endDate)).filter(Boolean);
  }

  function filterItemTreeByDateRange(item, startDate, endDate) {
    const filteredItem = Object.assign({}, item);
    
    if (item.children) {
      filteredItem.children = item.children
        .map(child => filterItemTreeByDateRange(child, startDate, endDate))
        .filter(Boolean);
      
      if (filteredItem.children.length === 0 && item.type !== 'year' && item.type !== 'month' && item.type !== 'day') {
        return null;
      }
    }
    
    // For leaf items (media), check date
    if (item.type === 'medium' && item.data && item.data.effective_datetime) {
      const itemDate = new Date(item.data.effective_datetime);
      if (itemDate < startDate || itemDate > endDate) {
        return null;
      }
    }
    
    // For date nodes, check if they fall within range
    if (item.type === 'year' || item.type === 'month' || item.type === 'day') {
      if (item.key) {
        const dateParts = item.key.split('/').map(Number);
        if (dateParts.length === 3) {
          const itemDate = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
          if (itemDate < startDate || itemDate > endDate) {
            return null;
          }
        } else if (dateParts.length === 2) {
          const itemDate = new Date(dateParts[0], dateParts[1] - 1, 1);
          const lastDay = new Date(dateParts[0], dateParts[1], 0);
          if (lastDay < startDate || itemDate > endDate) {
            return null;
          }
        } else if (dateParts.length === 1) {
          const yearStart = new Date(dateParts[0], 0, 1);
          const yearEnd = new Date(dateParts[0], 11, 31);
          if (yearEnd < startDate || yearStart > endDate) {
            return null;
          }
        }
      }
    }
    
    return filteredItem;
  }

  function filterByDate(items, date) {
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    
    return filterByDateRange(items, new Date(year, month - 1, day), new Date(year, month - 1, day, 23, 59, 59));
  }

  function filterByMonth(items, year, month) {
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59);
    
    return filterByDateRange(items, startDate, endDate);
  }

  function filterByYear(items, year) {
    const startDate = new Date(year, 0, 1);
    const endDate = new Date(year, 11, 31, 23, 59, 59);
    
    return filterByDateRange(items, startDate, endDate);
  }
})();

