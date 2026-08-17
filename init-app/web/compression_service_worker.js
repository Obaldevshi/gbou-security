const CACHE_NAME = 'gbou-compressed-assets-1.1.0-7';

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    Promise.all([
      caches
        .keys()
        .then((keys) =>
          Promise.all(
            keys
              .filter(
                (key) =>
                  key.startsWith('gbou-compressed-assets-') &&
                  key !== CACHE_NAME,
              )
              .map((key) => caches.delete(key)),
          ),
        ),
      self.clients.claim(),
    ]),
  );
});

function shouldUseCompressedAsset(url) {
  if (url.origin !== self.location.origin) return false;
  if (url.pathname === '/main.dart.js') return true;
  if (url.pathname.endsWith('.part.js')) return true;
  return (
    url.pathname.startsWith('/canvaskit/') &&
    (url.pathname.endsWith('.wasm') ||
      url.pathname.endsWith('.js') ||
      url.pathname.endsWith('.mjs'))
  );
}

function contentType(pathname) {
  if (pathname.endsWith('.wasm')) return 'application/wasm';
  return 'text/javascript; charset=utf-8';
}

async function compressedResponse(request, event) {
  const originalUrl = new URL(request.url);
  const compressedUrl = new URL(request.url);
  compressedUrl.pathname = `${compressedUrl.pathname}.gz`;

  const cache = await caches.open(CACHE_NAME);
  const ready = await cache.match(request);
  if (ready) return ready;

  const compressed = await fetch(compressedUrl.href, { cache: 'no-cache' });
  if (!compressed.ok || !compressed.body) return fetch(request);

  const headers = new Headers({
    'Content-Type': contentType(originalUrl.pathname),
    'Cache-Control': 'public, max-age=31536000, immutable',
    'X-Content-Type-Options': 'nosniff',
  });
  const body = await new Response(
    compressed.body.pipeThrough(new DecompressionStream('gzip')),
  ).arrayBuffer();
  const response = new Response(body, { status: 200, headers });
  event.waitUntil(cache.put(request, response.clone()));
  return response;
}

self.addEventListener('fetch', (event) => {
  if (
    event.request.method !== 'GET' ||
    !('DecompressionStream' in self) ||
    !shouldUseCompressedAsset(new URL(event.request.url))
  ) {
    return;
  }
  event.respondWith(compressedResponse(event.request, event));
});
