{{flutter_js}}
{{flutter_build_config}}

window.addEventListener('load', async function(ev) {
  // Download Firebase SDKs from CDN 
  try {
    window.firebase_core = await import("https://www.gstatic.com/firebasejs/10.7.0/firebase-app.js");
    window.firebase_auth = await import("https://www.gstatic.com/firebasejs/10.7.0/firebase-auth.js");
    window.firebase_firestore = await import("https://www.gstatic.com/firebasejs/10.7.0/firebase-firestore.js");
    console.log('Firebase SDKs loaded successfully');
  } catch (error) {
    console.warn('Failed to load Firebase SDKs:', error);
  }
  
  // Initialize Flutter app
  _flutter.loader.load();
});