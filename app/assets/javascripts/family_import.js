// Family namespace import functionality
window.FamilyImport = {
  openImportPopup: function() {
    console.log('Opening import popup from FamilyImport...');
    try {
      // Get the popup URL from a data attribute or use the hardcoded path
      const popupUrl = document.querySelector('[data-import-popup-url]')?.getAttribute('data-import-popup-url') || '/family/media/import_media_popup';
      const popup = window.open(
        popupUrl,
        'importMedia',
        'width=800,height=600,scrollbars=yes,resizable=yes,toolbar=no,menubar=no,location=no,status=no,directories=no,alwaysOnTop=yes'
      );
      
      if (!popup) {
        console.error('Popup was blocked by browser');
        alert('Popup was blocked. Please allow popups for this site and try again.');
        return;
      }
      
      console.log('Popup opened successfully from FamilyImport');
    
      // Keep popup on top and focused
      if (popup) {
        popup.focus();
        
        // Try to keep window floating on top (browser security may limit this)
        const keepOnTop = setInterval(function() {
          if (popup.closed) {
            clearInterval(keepOnTop);
            clearInterval(checkClosed);
            return;
          }
          try {
            popup.focus();
          } catch(e) {
            // Ignore focus errors
          }
        }, 2000);
        
        // Check if popup is closed
        const checkClosed = setInterval(function() {
          if (popup.closed) {
            clearInterval(checkClosed);
            clearInterval(keepOnTop);
            // Only refresh if not already refreshed by popup buttons
            console.log('Import popup closed from FamilyImport');
          }
        }, 1000);
      }
    } catch (error) {
      console.error('Error opening import popup from FamilyImport:', error);
      alert('Error opening import window. Please try again.');
    }
  }
};

// Also make it available as a global function for backward compatibility
window.openImportPopup = function() {
  return window.FamilyImport.openImportPopup();
};

console.log('FamilyImport JavaScript loaded');
