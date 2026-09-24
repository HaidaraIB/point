/**
 * Shared config and UI helpers for pay.html and payment-result.html.
 */
(function (global) {
  var SUPABASE_FUNCTIONS_BASE =
    "https://nbyhcxhdkxrathjaacvj.supabase.co/functions/v1";

  var LANG_KEY = "point_payment_pages_lang";
  var THEME_KEY = "point_payment_pages_theme";

  function detectLang() {
    var stored = localStorage.getItem(LANG_KEY);
    if (stored === "ar" || stored === "en") return stored;
    return "ar";
  }

  function detectTheme() {
    var stored = localStorage.getItem(THEME_KEY);
    if (stored === "light" || stored === "dark") return stored;
    return "dark";
  }

  function setDocumentLocale(lang) {
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";
  }

  function setDocumentTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme);
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function spinnerHtml(extraClass) {
    var cls = "spinner" + (extraClass ? " " + extraClass : "");
    return '<div class="' + cls + '" aria-hidden="true"></div>';
  }

  function payLinkBackUrl(params) {
    var p = (
      params.get("p") ||
      params.get("firebaseProjectId") ||
      params.get("firebase_project_id") ||
      ""
    ).trim();
    var t = (params.get("t") || "").trim();
    if (!p || !t) return "";
    return (
      location.origin +
      "/pay.html?p=" +
      encodeURIComponent(p) +
      "&t=" +
      encodeURIComponent(t)
    );
  }

  /**
   * Wires #lang-ar, #lang-en, #theme-light, #theme-dark (payment-result toolbar).
   * callbacks: { onLangChange(lang), onThemeChange(theme) }
   * Returns { lang, theme, setLang, setTheme }.
   */
  function initToolbar(callbacks) {
    var lang = detectLang();
    var theme = detectTheme();
    var cb = callbacks || {};

    function updateLangButtons() {
      var ar = document.getElementById("lang-ar");
      var en = document.getElementById("lang-en");
      if (ar) ar.classList.toggle("active", lang === "ar");
      if (en) en.classList.toggle("active", lang === "en");
    }

    function updateThemeButtons() {
      var light = document.getElementById("theme-light");
      var dark = document.getElementById("theme-dark");
      if (light) light.classList.toggle("active", theme === "light");
      if (dark) dark.classList.toggle("active", theme === "dark");
    }

    function setLang(next) {
      if (next !== "ar" && next !== "en") return;
      lang = next;
      localStorage.setItem(LANG_KEY, next);
      setDocumentLocale(lang);
      updateLangButtons();
      if (cb.onLangChange) cb.onLangChange(lang);
    }

    function setTheme(next) {
      if (next !== "light" && next !== "dark") return;
      theme = next;
      localStorage.setItem(THEME_KEY, next);
      setDocumentTheme(theme);
      updateThemeButtons();
      if (cb.onThemeChange) cb.onThemeChange(theme);
    }

    setDocumentTheme(theme);
    setDocumentLocale(lang);
    updateLangButtons();
    updateThemeButtons();

    var langAr = document.getElementById("lang-ar");
    var langEn = document.getElementById("lang-en");
    var themeLight = document.getElementById("theme-light");
    var themeDark = document.getElementById("theme-dark");
    if (langAr) langAr.addEventListener("click", function () { setLang("ar"); });
    if (langEn) langEn.addEventListener("click", function () { setLang("en"); });
    if (themeLight) themeLight.addEventListener("click", function () { setTheme("light"); });
    if (themeDark) themeDark.addEventListener("click", function () { setTheme("dark"); });

    return {
      getLang: function () { return lang; },
      getTheme: function () { return theme; },
      setLang: setLang,
      setTheme: setTheme,
    };
  }

  global.PointPaymentPages = {
    SUPABASE_FUNCTIONS_BASE: SUPABASE_FUNCTIONS_BASE,
    LANG_KEY: LANG_KEY,
    THEME_KEY: THEME_KEY,
    detectLang: detectLang,
    detectTheme: detectTheme,
    setDocumentLocale: setDocumentLocale,
    setDocumentTheme: setDocumentTheme,
    escapeHtml: escapeHtml,
    spinnerHtml: spinnerHtml,
    initToolbar: initToolbar,
    payLinkBackUrl: payLinkBackUrl,
    statusEndpoint: SUPABASE_FUNCTIONS_BASE + "/card-payment-status",
    payLinkEndpoint: SUPABASE_FUNCTIONS_BASE + "/pay-link",
  };
})(window);
