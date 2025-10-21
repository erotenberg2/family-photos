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
      // Create a form dynamically to submit the transition
      const form = document.createElement('form');
      form.method = 'POST';
      form.action = `/family/media/${mediumId}/execute_transition`;
      
      // Add CSRF token
      const csrfToken = document.querySelector('meta[name="csrf-token"]');
      if (csrfToken) {
        const tokenInput = document.createElement('input');
        tokenInput.type = 'hidden';
        tokenInput.name = 'authenticity_token';
        tokenInput.value = csrfToken.getAttribute('content');
        form.appendChild(tokenInput);
      }
      
      // Add method override for PATCH
      const methodInput = document.createElement('input');
      methodInput.type = 'hidden';
      methodInput.name = '_method';
      methodInput.value = 'patch';
      form.appendChild(methodInput);
      
      // Add transition parameter
      const transitionInput = document.createElement('input');
      transitionInput.type = 'hidden';
      transitionInput.name = 'transition';
      transitionInput.value = selectedValue;
      form.appendChild(transitionInput);
      
      // Submit the form
      document.body.appendChild(form);
      form.submit();
      document.body.removeChild(form);
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
