// Lightweight QR decoder bridge using jsQR for Flutter Web
// Requires jsQR to be loaded before this script:
// <script src="https://cdn.jsdelivr.net/npm/jsqr@1.4.0/dist/jsQR.js"></script>

(function () {
  async function loadImageFromBase64(base64) {
    return new Promise((resolve, reject) => {
      try {
        const img = new Image();
        img.onload = () => resolve(img);
        img.onerror = (e) => reject(e);
        img.src = 'data:image/*;base64,' + base64;
      } catch (e) {
        reject(e);
      }
    });
  }

  function getImageData(img, rotate90 = false, maxSide = 1600) {
    const w = img.naturalWidth || img.width;
    const h = img.naturalHeight || img.height;
    const scale = Math.min(1, maxSide / Math.max(w, h));
    const cw = Math.max(1, Math.round(w * scale));
    const ch = Math.max(1, Math.round(h * scale));
    const canvas = document.createElement('canvas');
    if (rotate90) {
      canvas.width = ch;
      canvas.height = cw;
    } else {
      canvas.width = cw;
      canvas.height = ch;
    }
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    ctx.imageSmoothingEnabled = false;
    if (rotate90) {
      ctx.translate(ch / 2, cw / 2);
      ctx.rotate(Math.PI / 2);
      ctx.drawImage(img, -cw / 2, -ch / 2, cw, ch);
    } else {
      ctx.drawImage(img, 0, 0, cw, ch);
    }
    return ctx.getImageData(0, 0, canvas.width, canvas.height);
  }

  async function decodeWithJsQR(base64) {
    if (typeof jsQR === 'undefined') {
      throw new Error('jsQR not loaded');
    }
    const img = await loadImageFromBase64(base64);
    const attempts = [
      { rotate: false },
      { rotate: true }
    ];
    for (const a of attempts) {
      const imageData = getImageData(img, a.rotate);
      // Try a couple of inversion attempts to be robust
      const options = { inversionAttempts: 'attemptBoth' };
      const result = jsQR(imageData.data, imageData.width, imageData.height, options);
      if (result && result.data) {
        return result.data;
      }
    }
    return null;
  }

  // Expose a Promise-returning function for Dart interop
  window.qrDecodeFromBase64 = function (base64) {
    return decodeWithJsQR(base64);
  };
})();
