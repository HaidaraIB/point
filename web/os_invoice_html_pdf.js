/**
 * Renders Os invoice print HTML to a single A4 PDF in the browser.
 * Uses the same DOM/CSS as window.print — Arabic shaping matches on-screen print.
 */
(function () {
  const JSPDF_URL =
    'https://cdn.jsdelivr.net/npm/jspdf@2.5.2/dist/jspdf.umd.min.js';
  const HTML_TO_IMAGE_URL =
    'https://cdn.jsdelivr.net/npm/html-to-image@1.11.13/dist/html-to-image.js';

  let libsPromise = null;

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      const existing = document.querySelector(`script[data-point-src="${src}"]`);
      if (existing) {
        if (existing.dataset.loaded === '1') {
          resolve();
          return;
        }
        existing.addEventListener('load', () => resolve(), { once: true });
        existing.addEventListener('error', () => reject(new Error('script_load')), {
          once: true,
        });
        return;
      }
      const s = document.createElement('script');
      s.src = src;
      s.async = true;
      s.dataset.pointSrc = src;
      s.addEventListener(
        'load',
        () => {
          s.dataset.loaded = '1';
          resolve();
        },
        { once: true },
      );
      s.addEventListener('error', () => reject(new Error('script_load')), {
        once: true,
      });
      document.head.appendChild(s);
    });
  }

  function ensureLibs() {
    if (!libsPromise) {
      libsPromise = Promise.all([
        loadScript(JSPDF_URL),
        loadScript(HTML_TO_IMAGE_URL),
      ]);
    }
    return libsPromise;
  }

  async function waitForAlmarai(doc) {
    const family = 'Almarai';
    const loads = [];
    for (const weight of ['300', '400', '700', '800']) {
      for (const size of ['11px', '12px', '14px', '16px', '28px']) {
        loads.push(doc.fonts.load(`${weight} ${size} ${family}`));
      }
    }
    await Promise.allSettled(loads);
    if (doc.fonts?.ready) {
      await doc.fonts.ready;
    }
    await new Promise((r) => setTimeout(r, 400));
  }

  function waitForIframeReady(iframe) {
    return new Promise((resolve, reject) => {
      const deadline = Date.now() + 45000;
      const tick = () => {
        if (Date.now() > deadline) {
          reject(new Error('iframe_timeout'));
          return;
        }
        try {
          const doc = iframe.contentDocument;
          if (!doc) {
            requestAnimationFrame(tick);
            return;
          }
          const ready =
            doc.readyState === 'complete' || doc.readyState === 'interactive';
          const sheet = doc.querySelector('.a4');
          if (!ready || !sheet) {
            requestAnimationFrame(tick);
            return;
          }
          waitForAlmarai(doc).then(resolve).catch(reject);
        } catch (e) {
          reject(e);
        }
      };
      tick();
    });
  }

  /**
   * @param {string} html Full invoice print document
   * @returns {Promise<ArrayBuffer>}
   */
  async function pointOsInvoiceHtmlToPdf(html) {
    await ensureLibs();
    const htmlToImage = window.htmlToImage;
    const jsPDF = window.jspdf?.jsPDF;
    if (!htmlToImage?.toJpeg || !jsPDF) {
      throw new Error('pdf_libs_missing');
    }

    const iframe = document.createElement('iframe');
    iframe.setAttribute('aria-hidden', 'true');
    iframe.style.cssText =
      'position:fixed;left:-12000px;top:0;width:210mm;height:297mm;border:0;opacity:0;pointer-events:none';
    document.body.appendChild(iframe);

    try {
      const doc = iframe.contentDocument;
      doc.open();
      doc.write(html);
      doc.close();
      await waitForIframeReady(iframe);

      const sheet = doc.querySelector('.a4');
      if (!sheet) {
        throw new Error('no_sheet');
      }

      const dataUrl = await htmlToImage.toJpeg(sheet, {
        quality: 0.94,
        pixelRatio: 2,
        cacheBust: true,
        backgroundColor: '#ffffff',
        skipFonts: false,
      });

      const pdf = new jsPDF({
        unit: 'mm',
        format: 'a4',
        orientation: 'portrait',
        compress: true,
      });
      pdf.addImage(dataUrl, 'JPEG', 0, 0, 210, 297);
      return pdf.output('arraybuffer');
    } finally {
      iframe.remove();
    }
  }

  window.pointOsInvoiceHtmlToPdf = pointOsInvoiceHtmlToPdf;
})();
