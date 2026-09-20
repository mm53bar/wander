// Offline support for the Travel PWA. Served from the site root so its scope is
// the whole app.
//
// - Static assets (digest-stamped /assets, icons) are cache-first.
// - HTML navigations are network-first, but only for deciding what to *show*:
//   a DNS record can resolve while the TCP connect crawls (a phone bringing up
//   a VPN tunnel on cellular), and fetch() alone won't settle quickly then, so
//   a cached page is shown once NETWORK_TIMEOUT_MS passes.
// - Everything else (JSON, .ics) is left to the browser.
const CACHE = "travel-v2";
const NETWORK_TIMEOUT_MS = 4000;

// Distinguishes "the timer won the race" from a network result of null, so a
// failed request and an expired timer don't take the same branch by accident.
const TIMED_OUT = Symbol("timed-out");

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
  if (event.request.method !== "GET") return;

  const url = new URL(event.request.url);
  if (url.pathname.startsWith("/assets/") || url.pathname.startsWith("/icons/")) {
    event.respondWith(caches.match(event.request).then((hit) => hit || fetch(event.request)));
    return;
  }

  if (!wantsHtml(event.request)) return;

  event.respondWith(respondToNavigation(event));
});

async function respondToNavigation(event) {
  const request = event.request;

  // The request runs to completion whatever the timer does. A link too slow to
  // render from still refreshes the cache, so the next load is current instead
  // of serving one stale page for as long as the link stays slow.
  const network = fetch(request).then(async (response) => {
    if (response.ok) await putInCache(request, response.clone());
    return response;
  });
  event.waitUntil(network.catch(() => {}));

  const cached = await matchCache(request);

  // Nothing to fall back to, so the timer would buy nothing — wait it out.
  if (!cached) return network.catch(() => fallback(request));

  const timer = startTimer(NETWORK_TIMEOUT_MS);
  const first = await Promise.race([network.catch(() => null), timer.expiry]);
  timer.cancel();
  if (first && first !== TIMED_OUT) return first;

  // Serving a copy that may predate what the server holds: tell the page once
  // the real response lands so it can pick up what this copy is missing.
  event.waitUntil(notifyIfChanged(request, cached, network));
  return cached;
}

// Only an ETag change triggers the notice. Matching tags mean the cached copy
// was already current, and reloading on those would spin any link slower than
// NETWORK_TIMEOUT_MS in a reload loop.
async function notifyIfChanged(request, cached, network) {
  let fresh;
  try {
    fresh = await network;
  } catch {
    return;
  }
  if (!fresh.ok) return;

  const before = cached.headers.get("etag");
  const after = fresh.headers.get("etag");
  if (!before || !after || before === after) return;

  const clients = await self.clients.matchAll({ type: "window" });
  for (const client of clients) {
    client.postMessage({ type: "content-updated", url: request.url });
  }
}

function startTimer(ms) {
  let id;
  const expiry = new Promise((resolve) => {
    id = setTimeout(() => resolve(TIMED_OUT), ms);
  });
  return { expiry, cancel: () => clearTimeout(id) };
}

function wantsHtml(request) {
  return request.headers.get("accept")?.includes("text/html") ?? false;
}

// Responses carry Vary: Accept, and a Turbo visit sends a narrower Accept than
// a browser navigation does. Only HTML reaches this cache, so matching on the
// URL alone is what keeps the two kinds of visit sharing one entry.
function matchCache(request) {
  return caches.match(request, { ignoreVary: true });
}

async function putInCache(request, response) {
  const cache = await caches.open(CACHE);
  await cache.put(request, response);
}

async function fallback(request) {
  return (await matchCache(request)) || (await caches.match("/", { ignoreVary: true }));
}
