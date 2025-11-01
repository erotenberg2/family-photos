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
          <div class="medium-sorter-listbox" id="daily-listbox" data-column="daily">
            ${renderHierarchicalTree(mediaData.daily, 'daily')}
          </div>
        </div>

        <!-- Events Column -->
        <div class="medium-sorter-column">
          <div class="medium-sorter-header">
            <h3>Events</h3>
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

  // Get metadata string for item
  function getItemMeta(item) {
    if (!item.data) return '';
    
    const parts = [];
    if (item.data.medium_type) {
      parts.push(item.data.medium_type);
    }
    if (item.data.file_size_human) {
      parts.push(item.data.file_size_human);
    }
    return parts.join(' • ');
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

    // Multi-select functionality (basic - will be enhanced for drag and drop)
    const treeItems = document.querySelectorAll('.tree-item');
    console.log('[MediumSorter] Found', treeItems.length, 'tree items');
    treeItems.forEach(item => {
      item.addEventListener('click', function(e) {
        if (e.target.closest('.tree-toggle')) return;
        
        this.classList.toggle('selected');
        e.stopPropagation();
      });
    });
    
    console.log('[MediumSorter] Event listeners attached successfully');
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
    attachEventListeners();
  }

  // Clear filters
  function clearFilters(column) {
    const originalData = mediaData[column] || [];
    const listbox = document.getElementById(`${column}-listbox`);
    listbox.innerHTML = renderHierarchicalTree(originalData, column);
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

