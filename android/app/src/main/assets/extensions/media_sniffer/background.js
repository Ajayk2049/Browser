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

  const NATIVE_APP = "dab-media-sniffer";
  const seen = new Set();

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
    return url.indexOf("googlevideo.com/videoplayback") !== -1;
  }

  browser.webRequest.onBeforeRequest.addListener(
    function (details) {
      try {
        const raw = details.url || "";
        if (!isUseful(raw)) return {};
        const base = normalize(raw);
        if (seen.has(base)) return {};
        seen.add(base);
        if (seen.size > 300) seen.clear();

        const payload = {
          url: base,
          pageUrl: details.originUrl || details.documentUrl || "",
          itag: (base.match(/[?&]itag=(\d+)/) || [])[1] || "",
          mime: decodeURIComponent((base.match(/[?&]mime=([^&]+)/) || [])[1] || ""),
        };
        try {
          browser.runtime.sendNativeMessage(NATIVE_APP, payload).then(
            function (resp) { void resp; },
            function () {}
          );
        } catch (e) {}
      } catch (e) {}
      return {};
    },
    { urls: ["*://*.googlevideo.com/videoplayback*"] },
    []
  );
})();
