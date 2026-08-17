{{flutter_js}}
{{flutter_build_config}}

const webAssetVersion = '1.1.0-6';
const compressedCacheName = `gbou-compressed-assets-${webAssetVersion}`;

for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath = `${build.mainJsPath}?v=${webAssetVersion}`;
  }
}

async function enableCompressedAssets() {
  if (!('serviceWorker' in navigator) || !('DecompressionStream' in window)) {
    return;
  }

  const workerUrl = `compression_service_worker.js?v=${webAssetVersion}`;
  const expectedUrl = new URL(workerUrl, window.location.href).href;
  const registration = await navigator.serviceWorker.register(workerUrl, {
    scope: '/',
  });

  if (
    navigator.serviceWorker.controller &&
    registration.active?.scriptURL === expectedUrl
  ) {
    return;
  }

  await Promise.race([
    new Promise((resolve) => {
      navigator.serviceWorker.addEventListener('controllerchange', resolve, {
        once: true,
      });
    }),
    new Promise((resolve) => setTimeout(resolve, 5000)),
  ]);

  const cache = await caches.open(compressedCacheName);
  const canvasKitBase =
    navigator.vendor === 'Google Inc.' || navigator.userAgent.includes('Edg/')
      ? 'canvaskit/chromium'
      : 'canvaskit';
  const assets = [
    {
      path: `main.dart.js?v=${webAssetVersion}`,
      type: 'text/javascript; charset=utf-8',
    },
    {
      path: `${canvasKitBase}/canvaskit.js`,
      type: 'text/javascript; charset=utf-8',
    },
    {
      path: `${canvasKitBase}/canvaskit.wasm`,
      type: 'application/wasm',
    },
  ];

  await Promise.all(
    assets.map(async ({ path, type }) => {
      const assetUrl = new URL(path, document.baseURI);
      if (await cache.match(assetUrl.href)) return;

      const compressedUrl = new URL(assetUrl.href);
      compressedUrl.pathname = `${compressedUrl.pathname}.gz`;
      const compressed = await fetch(compressedUrl.href, { cache: 'no-cache' });
      if (!compressed.ok || !compressed.body) {
        throw new Error(`Unable to preload ${assetUrl.pathname}`);
      }

      const body = await new Response(
        compressed.body.pipeThrough(new DecompressionStream('gzip')),
      ).arrayBuffer();
      await cache.put(
        assetUrl.href,
        new Response(body, {
          headers: {
            'Content-Type': type,
            'Cache-Control': 'public, max-age=31536000, immutable',
            'X-Content-Type-Options': 'nosniff',
          },
        }),
      );
    }),
  );
}

async function startFlutter() {
  try {
    await enableCompressedAssets();
  } catch (error) {
    console.warn('Compressed web assets are unavailable, using originals.', error);
  }

  _flutter.loader.load({
    onEntrypointLoaded: async function(engineInitializer) {
      const appRunner = await engineInitializer.initializeEngine();
      appRunner.runApp();
      const removeLoading = () =>
        document.getElementById('app-loading')?.remove();
      requestAnimationFrame(() => requestAnimationFrame(removeLoading));
      setTimeout(removeLoading, 4000);
    },
  });
}

startFlutter();
