// Transitions menu functionality
window.TransitionsMenu = {
  submitTransition: function(selectElement, mediumId) {
    const selectedValue = selectElement.value;
    const selectedOption = selectElement.options[selectElement.selectedIndex];
    const selectedText = selectedOption.text;
    
    if (!selectedValue) {
      return; // No selection made
    }
    
    // Check if the option is disabled
    if (selectedOption.disabled) {
      // Reset to the first option (Move to...)
      selectElement.selectedIndex = 0;
      return;
    }
    
    if (confirm('Move to ' + selectedText + '?')) {
      // For GET requests, we can just redirect
      window.location.href = `/family/media/${mediumId}/execute_transition?transition=${encodeURIComponent(selectedValue)}`;
    } else {
      // Reset to default option
      selectElement.selectedIndex = 0;
    }
  }
};

// Also make it available as a global function for backward compatibility
window.submitTransition = function(selectElement, mediumId) {
  return window.TransitionsMenu.submitTransition(selectElement, mediumId);
};

// Ensure the function is available when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  console.log('DOM loaded, transitions menu functions available');
});

console.log('TransitionsMenu JavaScript loaded');
