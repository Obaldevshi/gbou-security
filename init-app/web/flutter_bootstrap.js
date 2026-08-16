{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    appRunner.runApp();
    const removeLoading = () => document.getElementById('app-loading')?.remove();
    requestAnimationFrame(() => requestAnimationFrame(removeLoading));
    setTimeout(removeLoading, 4000);
  }
});
