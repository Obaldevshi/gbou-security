{{flutter_js}}
{{flutter_build_config}}

for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) build.mainJsPath = `${build.mainJsPath}?v=1.1.0-3`;
}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    appRunner.runApp();
    const removeLoading = () => document.getElementById('app-loading')?.remove();
    requestAnimationFrame(() => requestAnimationFrame(removeLoading));
    setTimeout(removeLoading, 4000);
  }
});
