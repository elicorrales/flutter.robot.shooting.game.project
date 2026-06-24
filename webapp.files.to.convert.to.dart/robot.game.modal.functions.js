// This flag resets on every page load as requested
let resizeWarningAccepted = false;

(function() {
    const modal = document.getElementById('resizeModal');
    const okBtn = document.getElementById('modalOk');
    const cancelBtn = document.getElementById('modalCancel');
    const canvas = gameState.ui.canvas;
    const wInput = gameState.ui.widthInput;
    const hInput = gameState.ui.heightInput;

    let isResizing = false;
    let resizeType = null; // 'width', 'height', or 'both'

    // --- Modal Logic ---
    okBtn.onclick = () => {
        resizeWarningAccepted = true;
        modal.style.display = 'none';
        // User has to click again to start the drag after accepting
    };

    cancelBtn.onclick = () => {
        modal.style.display = 'none';
        isResizing = false;
    };

    // --- Mouse Movement (Cursor Cues) ---
    canvas.addEventListener('mousemove', (e) => {
        if (isResizing) return;

        const rect = canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        const margin = 15; // sensitivity area at the edge

        const atRight = x > canvas.width - margin;
        const atBottom = y > canvas.height - margin;

        if (atRight && atBottom) canvas.style.cursor = 'nwse-resize';
        else if (atRight) canvas.style.cursor = 'ew-resize';
        else if (atBottom) canvas.style.cursor = 'ns-resize';
        else canvas.style.cursor = 'default';
    });

    // --- Mouse Down (Trigger Modal or Drag) ---
    canvas.addEventListener('mousedown', (e) => {
        const rect = canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        const margin = 15;

        const atRight = x > canvas.width - margin;
        const atBottom = y > canvas.height - margin;

        if (atRight || atBottom) {
            // Check permission
            if (!resizeWarningAccepted) {
                modal.style.display = 'flex';
                return;
            }

            // If allowed, start resizing
            isResizing = true;
            if (atRight && atBottom) resizeType = 'both';
            else if (atRight) resizeType = 'width';
            else resizeType = 'height';

            window.addEventListener('mousemove', performResize);
            window.addEventListener('mouseup', stopResizing);
        }
    });

    function performResize(e) {
        if (!isResizing) return;
        const rect = canvas.getBoundingClientRect();

        if (resizeType === 'width' || resizeType === 'both') {
            const newW = Math.max(50, Math.round(e.clientX - rect.left));
            wInput.value = newW;
            // Dispatch input event to trigger existing resetCanvas() logic
            wInput.dispatchEvent(new Event('input')); 
        }

        if (resizeType === 'height' || resizeType === 'both') {
            const newH = Math.max(50, Math.round(e.clientY - rect.top));
            hInput.value = newH;
            // Dispatch input event to trigger existing resetCanvas() logic
            hInput.dispatchEvent(new Event('input'));
        }
    }

    function stopResizing() {
        isResizing = false;
        window.removeEventListener('mousemove', performResize);
        window.removeEventListener('mouseup', stopResizing);
    }
})();
