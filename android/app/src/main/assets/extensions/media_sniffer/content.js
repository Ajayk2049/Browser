/**
 * DAB Media Sniffer - content script.
 *
 * 1) On YouTube pages: keeps scanning performance timeline for /videoplayback URLs.
 * 2) On all other pages (including iframes): inspects DOM <video>/<audio>/<source>
 *    tags so direct media URLs on pages without XHR traffic are also captured,
 *    while tagging hover/glide sneak-peek preview videos with isPreview=true so
 *    they stay handled in the background.
 */
(function () {
  "use strict";

  var APP = "dab.sniffer";
  var isYtHost = /(^|\.)youtube\.com$/i.test(location.hostname) || /(^|\.)youtu\.be$/i.test(location.hostname);
  var isSearchPage = /^https?:\/\/([^/]+\.)?(google\.[^/]+\/search|bing\.com\/search|duckduckgo\.com\/|search\.brave\.com\/|startpage\.com\/)/i.test(location.href);
  var NON_MEDIA_EXT_RE = /\.(json|jsonp|txt|text|vtt|srt|ass|ssa|sub|sbv|ttml|xml|csv|log|js|mjs|css|html?|svg|png|jpe?g|gif|webp|avif|ico|woff2?|ttf|otf|pdf|zip|rar|7z|apk)$/i;
  var PREVIEW_URL_RE = /(\/previews?\/|\/thumbs?\/|\/thumbnails?\/|\/trailers?\/|\/teasers?\/|\/mediabook\/|[?&_/](?:preview|trailer|teaser|mediabook|thumb)=|[_.-](?:preview|trailer|teaser|thumb|hover|mediabook)\.(?:mp4|webm|m4v)$)/i;
  var PREVIEW_ATTR_RE = /(^|[-_.\s])(preview|trailer|teaser|hover|thumb|thumbnail|mediabook|sneak|teaser)([-_.\s]|$)/i;

  // YouTube AVC video + M4A audio itags for native muxing.
  var KEEP = {
    "17": 1, "18": 1, "22": 1,
    "133": 1, "134": 1, "135": 1, "136": 1, "137": 1,
    "264": 1, "298": 1, "299": 1,
    "139": 1, "140": 1, "141": 1, "256": 1, "258": 1
  };
  var sent = {};

  function send(payload) {
    try {
      var r = browser.runtime.sendNativeMessage(APP, payload);
      if (r && typeof r.then === "function") r.then(function () {}, function () {});
    } catch (e) {}
  }

  function normYt(u) {
    try {
      var x = new URL(u);
      x.searchParams.delete("range");
      x.searchParams.delete("rn");
      x.searchParams.delete("rbuf");
      return x.toString();
    } catch (e) { return u; }
  }

  function scanYouTube() {
    try {
      var res = performance.getEntriesByType("resource");
      for (var i = 0; i < res.length; i++) {
        var u = res[i].name;
        if (!u || u.indexOf("/videoplayback") < 0) continue;
        var m = u.match(/[?&]itag=(\d+)/);
        var itag = m ? m[1] : "";
        if (!KEEP[itag]) continue;
        var base = normYt(u);
        if (sent[itag] === base) continue;
        sent[itag] = base;
        send({ type: "media", url: base, pageUrl: location.href, itag: itag, mime: "" });
      }
    } catch (e) {}
  }

  function resolveHttpUrl(raw) {
    if (!raw || typeof raw !== "string") return "";
    var s = raw.trim();
    if (!s || s.indexOf("blob:") === 0 || s.indexOf("data:") === 0) return "";
    try {
      var abs = new URL(s, location.href).href;
      if (abs.indexOf("http://") !== 0 && abs.indexOf("https://") !== 0) return "";
      var cleanPath = abs.split("?")[0].split("#")[0].toLowerCase();
      if (NON_MEDIA_EXT_RE.test(cleanPath)) return "";
      return abs;
    } catch (e) { return ""; }
  }

  function hasPreviewMarkers(el) {
    var cur = el;
    for (var depth = 0; cur && depth < 4 && cur !== document.body; depth++) {
      try {
        if (cur.hasAttribute) {
          if (cur.hasAttribute("data-preview") || cur.hasAttribute("data-mediabook") ||
              cur.hasAttribute("data-trailer") || cur.hasAttribute("data-thumb")) return true;
        }
        var cls = (typeof cur.className === "string" ? cur.className : "") + " " + (cur.id || "");
        if (cls.trim() && PREVIEW_ATTR_RE.test(cls)) return true;
      } catch (e) {}
      cur = cur.parentElement;
    }
    return false;
  }

  function isPreviewMedia(el, url, isAudio, totalVideos) {
    if (isAudio) return false;
    var mediaEl = el;
    if ((el.tagName || "").toUpperCase() === "SOURCE" && el.parentElement) {
      mediaEl = el.parentElement;
    }
    try {
      if (PREVIEW_URL_RE.test(url)) return true;
      if (mediaEl.closest && mediaEl.closest("a[href]")) return true;
      if (hasPreviewMarkers(mediaEl)) return true;

      var noControls = !mediaEl.controls && (!mediaEl.hasAttribute || !mediaEl.hasAttribute("controls"));
      var isMuted = !!(mediaEl.muted || (mediaEl.hasAttribute && mediaEl.hasAttribute("muted")));
      var isLoop = !!(mediaEl.loop || (mediaEl.hasAttribute && mediaEl.hasAttribute("loop")));
      if (noControls && isMuted && isLoop) {
        var dur = Number(mediaEl.duration || 0);
        if (isFinite(dur) && dur > 0 && dur <= 25) return true;
        var rect = mediaEl.getBoundingClientRect ? mediaEl.getBoundingClientRect() : null;
        if (rect && rect.width > 0 && rect.height > 0 && rect.width <= 420 && rect.height <= 280) {
          if (totalVideos > 1 || rect.width < (window.innerWidth || 400) * 0.72) return true;
        }
      }
    } catch (e) {}
    return false;
  }

  function emitGeneric(url, mediaType, mime, isPreview) {
    var state = isPreview ? "preview" : "full";
    if (!url || sent[url] === state || sent[url] === "preview") return;
    sent[url] = state;
    var path = url.split("?")[0].split("#")[0].toLowerCase();
    var fmt = "";
    if (path.slice(-5) === ".m3u8") { mediaType = "stream"; fmt = "HLS"; isPreview = false; }
    else if (path.slice(-4) === ".mpd") { mediaType = "stream"; fmt = "DASH"; isPreview = false; }
    var topUrl = "";
    try { topUrl = window.top === window ? location.href : (document.referrer || location.href); } catch (e) { topUrl = location.href; }
    send({
      type: "generic",
      url: url,
      pageUrl: topUrl,
      originUrl: location.origin || "",
      mime: mime || "",
      mediaType: mediaType,
      format: fmt,
      filename: "",
      size: -1,
      isPreview: !!isPreview,
      headers: { "Referer": location.href }
    });
  }

  function scanDomMedia() {
    if (isSearchPage) return;
    try {
      var totalVideos = document.querySelectorAll("video").length;
      var nodes = document.querySelectorAll("video, audio, source");
      for (var i = 0; i < nodes.length; i++) {
        var el = nodes[i];
        var tag = (el.tagName || "").toUpperCase();
        var parentTag = el.parentElement ? (el.parentElement.tagName || "").toUpperCase() : "";
        var isAudio = tag === "AUDIO" || parentTag === "AUDIO";
        var mime = el.getAttribute("type") || "";
        var candidates = [el.currentSrc, el.src, el.getAttribute("src")];
        for (var j = 0; j < candidates.length; j++) {
          var u = resolveHttpUrl(candidates[j]);
          if (u) emitGeneric(u, isAudio ? "audio" : "video", mime, isPreviewMedia(el, u, isAudio, totalVideos));
        }
      }
      var meta = document.querySelector('meta[property="og:video"], meta[property="og:video:url"], meta[property="og:video:secure_url"]');
      if (meta) {
        var mu = resolveHttpUrl(meta.getAttribute("content"));
        if (mu) emitGeneric(mu, "video", "", false);
      }
    } catch (e) {}
  }

  send({ type: "hello", from: "content", hasWebRequest: true, hasOnBeforeRequest: true });

  if (isYtHost) {
    scanYouTube();
    setInterval(scanYouTube, 3000);
  } else {
    scanDomMedia();
    var timer = null;
    try {
      var obs = new MutationObserver(function () {
        if (timer) return;
        timer = setTimeout(function () { timer = null; scanDomMedia(); }, 350);
      });
      obs.observe(document.documentElement || document, { childList: true, subtree: true, attributes: true, attributeFilter: ["src"] });
    } catch (e) {}
    setInterval(scanDomMedia, 4000);
  }
})();
