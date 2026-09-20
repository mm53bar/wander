// Drives public/service-worker.js in a vm sandbox with a hand-driven clock, so
// the 4s navigation timeout is exercised without the suite waiting 4s for it.
//
// Run with: node --test 'test/javascript/*.mjs'
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const SOURCE = readFileSync(
  fileURLToPath(new URL("../../public/service-worker.js", import.meta.url)),
  "utf8"
);

const PAGE = "https://travel.example/trips/6";

function html(body, etag) {
  return new Response(body, {
    status: 200,
    headers: { "content-type": "text/html", etag, vary: "Accept" }
  });
}

function navigation(url = PAGE, accept = "text/html,application/xhtml+xml") {
  return new Request(url, { headers: { accept } });
}

// A promise the test resolves by hand, so network timing is explicit.
function deferred() {
  let settle, fail;
  const promise = new Promise((resolve, reject) => { settle = resolve; fail = reject; });
  return { promise, settle, fail };
}

// Minimal Cache API over a Map. ignoreVary is the only match option the worker
// uses; entries are keyed by URL, which is what ignoreVary: true means here.
function cacheStore() {
  const boxes = new Map();
  const box = (name) => {
    if (!boxes.has(name)) boxes.set(name, new Map());
    return boxes.get(name);
  };
  const cache = (name) => ({
    put: async (request, response) => { box(name).set(new URL(request.url).href, response); },
    match: async (request) => {
      const url = typeof request === "string" ? new URL(request, PAGE).href : new URL(request.url).href;
      return box(name).get(url);
    }
  });
  return {
    boxes,
    api: {
      open: async (name) => cache(name),
      match: async (request, _opts) => {
        for (const name of boxes.keys()) {
          const hit = await cache(name).match(request);
          if (hit) return hit;
        }
        return undefined;
      },
      keys: async () => [...boxes.keys()],
      delete: async (name) => boxes.delete(name)
    }
  };
}

function load({ fetchImpl }) {
  const listeners = {};
  const timers = new Map();
  const posted = [];
  let nextTimer = 1;
  const store = cacheStore();

  const self = {
    addEventListener: (type, fn) => { (listeners[type] ||= []).push(fn); },
    skipWaiting: () => {},
    clients: {
      claim: () => {},
      matchAll: async () => [{ postMessage: (msg) => posted.push(msg) }]
    }
  };

  const sandbox = {
    self,
    caches: store.api,
    fetch: fetchImpl,
    Request,
    Response,
    URL,
    Promise,
    Symbol,
    console,
    setTimeout: (fn, ms) => { const id = nextTimer++; timers.set(id, { fn, ms }); return id; },
    clearTimeout: (id) => timers.delete(id)
  };
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  vm.runInContext(SOURCE, sandbox);

  // Fires every pending timer, standing in for the wall clock reaching them.
  const advance = () => {
    const due = [...timers.entries()];
    timers.clear();
    for (const [, t] of due) t.fn();
  };

  // Dispatches a fetch event and returns what the worker chose to respond with.
  const dispatch = (request) => {
    let responded;
    const waits = [];
    const event = {
      request,
      respondWith: (p) => { responded = p; },
      waitUntil: (p) => { waits.push(p); }
    };
    for (const fn of listeners.fetch) fn(event);
    return { responded, settled: () => Promise.allSettled(waits) };
  };

  return { dispatch, advance, posted, store, timers };
}

// Lets the worker's pending microtasks run before the test looks at state.
const drain = () => new Promise((resolve) => setImmediate(resolve));

test("a fast response is served and cached", async () => {
  const sw = load({ fetchImpl: async () => html("<p>fresh</p>", 'W/"a"') });

  const { responded, settled } = sw.dispatch(navigation());
  const response = await responded;

  assert.equal(await response.text(), "<p>fresh</p>");
  await settled();
  const cached = await sw.store.api.match(navigation());
  assert.equal(await cached.text(), "<p>fresh</p>");
});

test("a response slower than the timeout serves the cached page", async () => {
  const network = deferred();
  const sw = load({ fetchImpl: () => network.promise });

  const box = await sw.store.api.open("travel-v2");
  await box.put(navigation(), html("<p>stale</p>", 'W/"a"'));

  const { responded } = sw.dispatch(navigation());
  await drain();
  sw.advance();

  const response = await responded;
  assert.equal(await response.text(), "<p>stale</p>");
});

test("a response slower than the timeout still refreshes the cache", async () => {
  const network = deferred();
  const sw = load({ fetchImpl: () => network.promise });

  const box = await sw.store.api.open("travel-v2");
  await box.put(navigation(), html("<p>stale</p>", 'W/"a"'));

  const { responded, settled } = sw.dispatch(navigation());
  await drain();
  sw.advance();
  assert.equal(await (await responded).text(), "<p>stale</p>");

  network.settle(html("<p>fresh</p>", 'W/"b"'));
  await settled();

  const cached = await sw.store.api.match(navigation());
  assert.equal(await cached.text(), "<p>fresh</p>");
});

test("the page is told when the late response differs", async () => {
  const network = deferred();
  const sw = load({ fetchImpl: () => network.promise });

  const box = await sw.store.api.open("travel-v2");
  await box.put(navigation(), html("<p>stale</p>", 'W/"a"'));

  const { responded, settled } = sw.dispatch(navigation());
  await drain();
  sw.advance();
  await responded;

  network.settle(html("<p>fresh</p>", 'W/"b"'));
  await settled();

  // Field-wise: the message is built inside the sandbox, so it does not share a
  // prototype with objects made out here.
  assert.equal(sw.posted.length, 1);
  assert.equal(sw.posted[0].type, "content-updated");
  assert.equal(sw.posted[0].url, PAGE);
});

test("a matching ETag raises no notice, so a slow link cannot reload-loop", async () => {
  const network = deferred();
  const sw = load({ fetchImpl: () => network.promise });

  const box = await sw.store.api.open("travel-v2");
  await box.put(navigation(), html("<p>same</p>", 'W/"a"'));

  const { responded, settled } = sw.dispatch(navigation());
  await drain();
  sw.advance();
  await responded;

  network.settle(html("<p>same</p>", 'W/"a"'));
  await settled();

  assert.equal(sw.posted.length, 0);
});

test("a failed request with nothing cached falls back to the root page", async () => {
  const sw = load({ fetchImpl: async () => { throw new TypeError("offline"); } });

  const box = await sw.store.api.open("travel-v2");
  await box.put(new Request("https://travel.example/"), html("<p>home</p>", 'W/"a"'));

  const { responded } = sw.dispatch(navigation());
  const response = await responded;

  assert.equal(await response.text(), "<p>home</p>");
});

test("non-HTML GETs are left to the browser", async () => {
  const sw = load({ fetchImpl: async () => html("{}", 'W/"a"') });

  const { responded } = sw.dispatch(navigation(`${PAGE}.json`, "application/json"));

  assert.equal(responded, undefined);
});
