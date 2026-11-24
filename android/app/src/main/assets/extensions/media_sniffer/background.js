/**
 * DAB Media Sniffer - background script.
 *
 * Observes googlevideo /videoplayback requests made by pages (YouTube's own
 * player traffic) and forwards one normalized URL per stream to the native
 * app. These URLs are minted by the page's real player session (attested),
 * so they are guaranteed-downloadable from the same device session - unlike
 * URLs re-derived from third-party API clients, which YouTube now 403s.
 */
(function () {
  "use strict";

  const NATIVE_APP = "dab.sniffer";
  const seen = new Set();

  function log() {
    try {
      console.log.apply(console, ["[SNIFF]"].concat(Array.prototype.slice.call(arguments)));
    } catch (e) {}
  }

  function send(payload) {
    try {
      const p = browser.runtime.sendNativeMessage(NATIVE_APP, payload);
      if (p && typeof p.then === "function") {
        p.then(
          function () {},
          function (e) { log("sendNativeMessage rejected:", String(e)); }
        );
      } else {
        log("sendNativeMessage returned no promise");
      }
    } catch (e) {
      log("sendNativeMessage threw:", String(e));
    }
  }

  log("startup; webRequest=", !!(browser && browser.webRequest));

  // Startup diagnostic: tells the native side whether webRequest exists at all.
  send({
    type: "hello",
    hasWebRequest: !!(browser && browser.webRequest),
    hasOnBeforeRequest: !!(browser && browser.webRequest && browser.webRequest.onBeforeRequest),
  });

  function normalize(url) {
    try {
      const u = new URL(url);
      // Strip the per-request slice params; the downloader re-adds its own.
      u.searchParams.delete("range");
      u.searchParams.delete("rn");
      u.searchParams.delete("rbuf");
      return u.toString();
    } catch (e) {
      return url;
    }
  }

  function isUseful(url) {
    return url.indexOf("googlevideo.com/videoplayback") !== -1 ||
      url.indexOf("/videoplayback") !== -1;
  }

  function onRequest(details) {
    try {
      const raw = details.url || "";
      if (!isUseful(raw)) return {};
      const base = normalize(raw);
      if (seen.has(base)) return {};
      seen.add(base);
      if (seen.size > 300) seen.clear();

      log("media itag=", (base.match(/[?&]itag=(\d+)/) || [])[1] || "?");
      send({
        type: "media",
        url: base,
        pageUrl: details.originUrl || details.documentUrl || "",
        itag: (base.match(/[?&]itag=(\d+)/) || [])[1] || "",
        mime: decodeURIComponent((base.match(/[?&]mime=([^&]+)/) || [])[1] || ""),
      });
    } catch (e) {
      log("onRequest error:", String(e));
    }
    return {};
  }

  try {
    browser.webRequest.onBeforeRequest.addListener(
      onRequest,
      { urls: ["*://*.googlevideo.com/videoplayback*", "*://*/videoplayback*"] },
      []
    );
    log("listener registered");
  } catch (e) {
    log("addListener failed:", String(e));
    send({ type: "error", message: String(e) });
  }
})();
