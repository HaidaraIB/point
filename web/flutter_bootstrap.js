{{flutter_js}}
{{flutter_build_config}}

// Use onEntrypointLoaded so hot restart re-runs the engine app runner (Flutter docs).
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  },
});
