/**
 * DAB Media Sniffer - background script.
 *
 * 1) YouTube path (preserved): observes googlevideo /videoplayback requests
 *    and forwards attested session URLs to the native YouTube pipeline.
 * 2) Universal path (1DM+-style): inspects onBeforeSendHeaders +
 *    onHeadersReceived across <all_urls> to capture any-site video, audio,
 *    and HLS/DASH streams along with their session headers, while keeping
 *    hover-preview trailers tagged for background handling and rejecting
 *    non-media files (JSON, TXT, subtitles, docs, scripts).
 */
(function () {
  "use strict";

  const NATIVE_APP = "dab.sniffer";
  const ytSeen = new Set();
  const genericSeen = new Set();
  const reqHeaders = new Map();
  const playlistPages = new Set();

  const IGNORE_TYPES = new Set([
    "stylesheet", "script", "font", "image", "imageset", "beacon", "ping", "csp_report", "websocket"
  ]);
  const AD_HOST_RE = /(doubleclick\.net|googlesyndication\.com|google-analytics\.com|googletagmanager\.com|scorecardresearch\.com|adservice\.google\.|adnxs\.com|outbrain\.com|taboola\.com)/i;
  const UI_AUDIO_HOST_RE = /(gstatic\.com|translate\.google\.|google\.com\/speech-api)/i;
  const SEARCH_PAGE_RE = /^https?:\/\/([^/]+\.)?(google\.[^/]+\/search|bing\.com\/search|duckduckgo\.com\/|search\.brave\.com\/|startpage\.com\/)/i;
  const VIDEO_EXT_RE = /\.(mp4|mkv|webm|mov|flv|avi|wmv|m4v|3gp|3g2)$/i;
  const AUDIO_EXT_RE = /\.(mp3|m4a|aac|flac|ogg|opus|wav|weba)$/i;
  const SEGMENT_EXT_RE = /\.(ts|m4s|cmf|cmfv|cmfa)$/i;
  const NON_MEDIA_EXT_RE = /\.(json|jsonp|txt|text|vtt|srt|ass|ssa|sub|sbv|ttml|dfxp|xml|csv|tsv|log|ini|conf|cfg|yaml|yml|toml|md|js|mjs|cjs|css|html|htm|xhtml|svg|png|jpe?g|gif|webp|avif|bmp|ico|woff2?|ttf|otf|eot|map|wasm|pdf|zip|rar|7z|tar|gz|apk|xapk|exe|msi|dmg|iso|bin|dat|key)$/i;
  const PREVIEW_URL_RE = /(\/previews?\/|\/thumbs?\/|\/thumbnails?\/|\/trailers?\/|\/teasers?\/|\/mediabook\/|[?&_/](?:preview|trailer|teaser|mediabook|thumb)=|[_.-](?:preview|trailer|teaser|thumb|hover|mediabook)\.(?:mp4|webm|m4v)$)/i;

  function log() {
    try { console.log.apply(console, ["[SNIFF]"].concat(Array.prototype.slice.call(arguments))); } catch (e) {}
  }

  function send(payload) {
    try {
      const p = browser.runtime.sendNativeMessage(NATIVE_APP, payload);
      if (p && typeof p.then === "function") p.then(function () {}, function (e) { log("sendNativeMessage rejected:", String(e)); });
    } catch (e) { log("sendNativeMessage threw:", String(e)); }
  }

  send({
    type: "hello",
    hasWebRequest: !!(browser && browser.webRequest),
    hasOnBeforeRequest: !!(browser && browser.webRequest && browser.webRequest.onBeforeRequest),
  });

  // --- YouTube attested URL sniffer (kept isolated) ---
  function normalizeYt(url) {
    try {
      const u = new URL(url);
      u.searchParams.delete("range");
      u.searchParams.delete("rn");
      u.searchParams.delete("rbuf");
      return u.toString();
    } catch (e) { return url; }
  }

  function onYtRequest(details) {
    try {
      const raw = details.url || "";
      if (raw.indexOf("googlevideo.com/videoplayback") === -1 && raw.indexOf("/videoplayback") === -1) return {};
      const base = normalizeYt(raw);
      if (ytSeen.has(base)) return {};
      ytSeen.add(base);
      if (ytSeen.size > 300) ytSeen.clear();
      send({
        type: "media",
        url: base,
        pageUrl: details.originUrl || details.documentUrl || "",
        itag: (base.match(/[?&]itag=(\d+)/) || [])[1] || "",
        mime: decodeURIComponent((base.match(/[?&]mime=([^&]+)/) || [])[1] || ""),
      });
    } catch (e) {}
    return {};
  }

  // --- Universal 1DM+-style request header + response sniffer ---
  function headerMap(list) {
    const out = {};
    if (!Array.isArray(list)) return out;
    for (let i = 0; i < list.length; i++) {
      const h = list[i];
      if (h && h.name && typeof h.value === "string") out[h.name.toLowerCase()] = h.value;
    }
    return out;
  }

  function parseFilename(cd, url) {
    if (cd) {
      const mStar = /filename\*\s*=\s*(?:UTF-8''|utf-8'')([^;]+)/i.exec(cd);
      if (mStar && mStar[1]) {
        try { return decodeURIComponent(mStar[1].trim().replace(/^"|"$/g, "")); } catch (e) {}
      }
      const mPlain = /filename\s*=\s*"([^"]+)"|filename\s*=\s*([^;\s]+)/i.exec(cd);
      if (mPlain && (mPlain[1] || mPlain[2])) {
        const raw = (mPlain[1] || mPlain[2]).trim().replace(/^"|"$/g, "");
        try { return decodeURIComponent(raw); } catch (e) { return raw; }
      }
    }
    try {
      const seg = new URL(url).pathname.split("/").filter(Boolean).pop() || "";
      if (seg.indexOf(".") !== -1 && seg.length <= 120) return decodeURIComponent(seg);
    } catch (e) {}
    return "";
  }

  function parseTotalSize(status, cr, cl) {
    if (status === 206 && cr) {
      const idx = cr.lastIndexOf("/");
      if (idx !== -1) {
        const tot = Number(cr.slice(idx + 1).trim());
        if (Number.isFinite(tot) && tot > 0) return tot;
      }
    }
    if (cl) {
      const len = Number(cl.trim());
      if (Number.isFinite(len) && len > 0) return len;
    }
    return -1;
  }

  function cleanPath(url) {
    try { return new URL(url).pathname.toLowerCase(); } catch (e) { return url.split("?")[0].split("#")[0].toLowerCase(); }
  }

  function stripQuery(url) {
    const i = url.indexOf("?");
    const h = url.indexOf("#");
    const cut = (i >= 0 && h >= 0) ? Math.min(i, h) : (i >= 0 ? i : h);
    return cut === -1 ? url : url.slice(0, cut);
  }

  function stripFragment(url) {
    const h = url.indexOf("#");
    return h === -1 ? url : url.slice(0, h);
  }

  function isIgnoredMime(mime) {
    if (!mime) return false;
    if (mime === "application/vnd.apple.mpegurl" || mime === "application/x-mpegurl" ||
        mime === "audio/mpegurl" || mime === "application/dash+xml") {
      return false;
    }
    if (mime.startsWith("text/") || mime.startsWith("image/") || mime.startsWith("font/")) return true;
    if (mime === "application/json" || mime.endsWith("+json") || mime === "application/xml" ||
        mime === "application/xhtml+xml" || mime.indexOf("javascript") !== -1 ||
        mime === "application/ecmascript" || mime === "application/x-subrip" ||
        mime === "application/ttml+xml" || mime === "application/wasm") {
      return true;
    }
    return false;
  }

  function onBeforeSendHeaders(details) {
    try {
      const url = details.url || "";
      if (!url.startsWith("http") || url.indexOf("googlevideo.com") !== -1) return {};
      const hm = headerMap(details.requestHeaders);
      const captured = {};
      if (hm["cookie"]) captured["Cookie"] = hm["cookie"];
      if (hm["referer"]) captured["Referer"] = hm["referer"];
      if (hm["origin"]) captured["Origin"] = hm["origin"];
      if (hm["user-agent"]) captured["User-Agent"] = hm["user-agent"];
      if (hm["authorization"]) captured["Authorization"] = hm["authorization"];
      if (Object.keys(captured).length > 0) {
        if (reqHeaders.size > 500) reqHeaders.clear();
        reqHeaders.set(details.requestId, captured);
      }
    } catch (e) {}
    return {};
  }

  function cleanupReq(details) {
    if (details && details.requestId) reqHeaders.delete(details.requestId);
  }

  async function onHeadersReceived(details) {
    const hdrs = details && details.requestId ? (reqHeaders.get(details.requestId) || {}) : {};
    if (details && details.requestId) reqHeaders.delete(details.requestId);

    try {
      const url = details.url || "";
      if (!url.startsWith("http")) return;
      if (url.indexOf("googlevideo.com") !== -1 || url.indexOf("/videoplayback") !== -1) return;
      if (details.statusCode < 200 || details.statusCode >= 400) return;
      if (AD_HOST_RE.test(url)) return;

      const rType = (details.type || "").toLowerCase();
      if (IGNORE_TYPES.has(rType)) return;

      const hm = headerMap(details.responseHeaders);
      const mimeFull = (hm["content-type"] || "").toLowerCase();
      const mime = mimeFull.split(";")[0].trim();
      const cd = hm["content-disposition"] || "";

      if (isIgnoredMime(mime)) return;

      if ((rType === "main_frame" || rType === "sub_frame") &&
          !mime.startsWith("video/") && !mime.startsWith("audio/") &&
          mime !== "application/vnd.apple.mpegurl" && mime !== "application/x-mpegurl" &&
          mime !== "application/dash+xml") {
        return;
      }

      const path = cleanPath(url);
      const filename = parseFilename(cd, url);
      const lowerName = filename.toLowerCase();
      if (NON_MEDIA_EXT_RE.test(path) || NON_MEDIA_EXT_RE.test(lowerName)) return;

      const totalBytes = parseTotalSize(details.statusCode, hm["content-range"] || "", hm["content-length"] || "");
      const topAncestorUrl = (Array.isArray(details.frameAncestors) && details.frameAncestors.length > 0)
        ? (details.frameAncestors[details.frameAncestors.length - 1].url || "")
        : "";
      const pageUrl = topAncestorUrl || details.documentUrl || details.originUrl || hdrs["Referer"] || "";
      const pageKey = stripFragment(pageUrl);

      // Record headers for exact 16-byte AES-128 key fetches (1DM+ onPotentialM3u8AesKey pattern).
      if (details.statusCode === 200 && totalBytes === 16 && Object.keys(hdrs).length > 0) {
        send({ type: "aes_key", url: url, headers: hdrs });
      }

      // Classify strictly as media: HLS/DASH -> Video -> Audio (no non-media JSON/TXT/docs).
      const isOctetOrBlank = (mime === "" || mime === "application/octet-stream" || mime === "binary/octet-stream");
      let mediaType = "";
      let format = "";
      if (mime === "application/vnd.apple.mpegurl" || mime === "application/x-mpegurl" || mime === "audio/mpegurl" || path.endsWith(".m3u8")) {
        mediaType = "stream"; format = "HLS";
        if (pageKey) playlistPages.add(pageKey);
      } else if (mime === "application/dash+xml" || path.endsWith(".mpd")) {
        mediaType = "stream"; format = "DASH";
        if (pageKey) playlistPages.add(pageKey);
      } else if (mime.startsWith("video/") || (isOctetOrBlank && (VIDEO_EXT_RE.test(path) || VIDEO_EXT_RE.test(lowerName)))) {
        if (SEGMENT_EXT_RE.test(path) && (playlistPages.has(pageKey) || (totalBytes > 0 && totalBytes < 5242880))) return;
        if (totalBytes > 0 && totalBytes < 65536) return;
        mediaType = "video";
      } else if (mime.startsWith("audio/") || (isOctetOrBlank && (AUDIO_EXT_RE.test(path) || AUDIO_EXT_RE.test(lowerName)))) {
        const isAttachment = cd.toLowerCase().indexOf("attachment") !== -1;
        if (!isAttachment && (UI_AUDIO_HOST_RE.test(url) || SEARCH_PAGE_RE.test(pageKey))) return;
        if (!isAttachment && totalBytes > 0 && totalBytes < 102400) return;
        mediaType = "audio";
      } else {
        return;
      }

      if (!format && filename.indexOf(".") !== -1) {
        format = filename.split(".").pop().toUpperCase();
      }

      const isPreview = mediaType === "video" && (
        PREVIEW_URL_RE.test(url) ||
        (totalBytes > 0 && totalBytes < 2097152 && (playlistPages.has(pageKey) || path.endsWith(".webm")))
      );

      const dedupKey = pageKey + "::" + stripQuery(url) + "::" + mediaType + "::" + totalBytes + "::" + (isPreview ? "1" : "0");
      if (genericSeen.has(dedupKey)) return;
      genericSeen.add(dedupKey);
      if (genericSeen.size > 500) genericSeen.clear();

      if (!hdrs["Cookie"] && browser.cookies && browser.cookies.getAll) {
        try {
          const cookies = await browser.cookies.getAll({ url: url });
          if (cookies && cookies.length) {
            hdrs["Cookie"] = cookies.map(function (c) { return c.name + "=" + c.value; }).join("; ");
          }
        } catch (e) {}
      }

      send({
        type: "generic",
        url: url,
        pageUrl: pageUrl,
        originUrl: details.originUrl || "",
        mime: mime,
        mediaType: mediaType,
        format: format,
        filename: filename,
        size: totalBytes,
        headers: hdrs,
        isPreview: isPreview,
      });
    } catch (e) {
      log("onHeadersReceived err:", String(e));
    }
  }

  try {
    browser.webRequest.onBeforeRequest.addListener(
      onYtRequest,
      { urls: ["*://*.googlevideo.com/videoplayback*", "*://*/videoplayback*"] },
      []
    );
    browser.webRequest.onBeforeSendHeaders.addListener(
      onBeforeSendHeaders,
      { urls: ["<all_urls>"] },
      ["requestHeaders"]
    );
    browser.webRequest.onHeadersReceived.addListener(
      onHeadersReceived,
      { urls: ["<all_urls>"] },
      ["responseHeaders"]
    );
    browser.webRequest.onCompleted.addListener(cleanupReq, { urls: ["<all_urls>"] });
    browser.webRequest.onErrorOccurred.addListener(cleanupReq, { urls: ["<all_urls>"] });
    log("all-site + YT listeners registered");
  } catch (e) {
    log("addListener failed:", String(e));
    send({ type: "error", message: String(e) });
  }
})();
