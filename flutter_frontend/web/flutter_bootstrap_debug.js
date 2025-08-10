{{flutter_js}}
{{flutter_build_config}}

console.log('DEBUG: Bootstrap script loaded');

window.addEventListener('load', async function(ev) {
  console.log('DEBUG: Window load event fired');
  
  // Download Firebase SDKs from CDN 
  try {
    console.log('DEBUG: Loading Firebase SDKs...');
    window.firebase_core = await import("https://www.gstatic.com/firebasejs/10.7.0/firebase-app.js");
    window.firebase_auth = await import("https://www.gstatic.com/firebasejs/10.7.0/firebase-auth.js");
    window.firebase_firestore = await import("https://www.gstatic.com/firebasejs/10.7.0/firebase-firestore.js");
    console.log('DEBUG: Firebase SDKs loaded successfully');
  } catch (error) {
    console.warn('DEBUG: Failed to load Firebase SDKs:', error);
  }
  
  console.log('DEBUG: Initializing Flutter app...');
  
  // Initialize Flutter app
  _flutter.loader.load({
    onEntrypointLoaded: async function(engineInitializer) {
      console.log('DEBUG: Entrypoint loaded, initializing engine...');
      const appRunner = await engineInitializer.initializeEngine();
      console.log('DEBUG: Engine initialized, running app...');
      await appRunner.runApp();
      console.log('DEBUG: App is running!');
    }
  });
});