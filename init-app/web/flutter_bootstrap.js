{{flutter_js}}
{{flutter_build_config}}

const webAssetVersion = '1.1.0-4';

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
