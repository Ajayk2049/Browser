/**
 * DAB Media Sniffer - content script.
 *
 * GeckoView does not expose a JS-eval API on GeckoSession, so this script is
 * how the app reads the *page's own* media traffic. It runs in an isolated
 * world but shares the document's performance timeline, which lists every
 * googlevideo /videoplayback request the player made.
 */
(function () {
  "use strict";

  var APP = "dab.sniffer";

  // itags the native muxer can handle: AVC video + M4A audio.
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
      if (r && typeof r.then === "function") {
        r.then(function () {}, function () {});
      }
    } catch (e) {
      // No native bridge on this session; the background sniffer may still work.
    }
  }

  function norm(u) {
    try {
      var x = new URL(u);
      x.searchParams.delete("range");
      x.searchParams.delete("rn");
      x.searchParams.delete("rbuf");
      return x.toString();
    } catch (e) {
      return u;
    }
  }

  /// Forwards stream URLs whose itag we can identify. (YouTube's SABR player
  /// fetches untyped UMP blobs, so on those pages this finds nothing and the
  /// app falls back to resolving manifests itself.)
  function scan() {
    var fresh = 0;
    try {
      var res = performance.getEntriesByType("resource");
      for (var i = 0; i < res.length; i++) {
        var u = res[i].name;
        if (!u || u.indexOf("/videoplayback") < 0) continue;
        var m = u.match(/[?&]itag=(\d+)/);
        var itag = m ? m[1] : "";
        if (!KEEP[itag]) continue;
        var base = norm(u);
        if (sent[itag] === base) continue;
        sent[itag] = base;
        fresh++;
        send({ type: "media", url: base, pageUrl: location.href, itag: itag, mime: "" });
      }
    } catch (e) {}
    return fresh;
  }

  send({ type: "hello", from: "content", hasWebRequest: true, hasOnBeforeRequest: true });

  scan();

  // YouTube navigates between videos without reloading the document, so keep
  // watching for the lifetime of the page. Each pass is a tiny array walk and
  // only never-seen URLs are sent.
  setInterval(scan, 3000);
})();
