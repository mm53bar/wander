// Offline support for the Travel PWA. Served from the site root so its scope is
// the whole app.
//
// - Static assets (digest-stamped /assets, icons) are cache-first.
// - Page navigations are network-first but race a short timeout: a DNS record
//   can resolve while the TCP connect hangs (e.g. a name that only routes on a
//   home network), and fetch() alone won't reject quickly then, so we fall back
//   to the cached page fast instead of spinning.
const CACHE = "travel-v1";
const NETWORK_TIMEOUT_MS = 4000;

function fetchWithTimeout(request, ms) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  return fetch(request, { signal: controller.signal }).finally(() => clearTimeout(timer));
}

self.addEventListener("install", () => self.skipWaiting());

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);
  if (event.request.method !== "GET") return;

  if (url.pathname.startsWith("/assets/") || url.pathname.startsWith("/icons/")) {
    event.respondWith(caches.match(event.request).then((hit) => hit || fetch(event.request)));
    return;
  }

  event.respondWith(
    fetchWithTimeout(event.request, NETWORK_TIMEOUT_MS)
      .then((res) => {
        if (res.ok && event.request.headers.get("accept")?.includes("text/html")) {
          const clone = res.clone();
          caches.open(CACHE).then((c) => c.put(event.request, clone));
        }
        return res;
      })
      .catch(() => caches.match(event.request).then((hit) => hit || caches.match("/")))
  );
});
