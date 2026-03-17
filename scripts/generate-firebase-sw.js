/**
 * يولّد web/firebase-messaging-sw.js من القالب اعتمادًا على lib/firebase_options.dart (بدون .env).
 * التشغيل من جذر المشروع: node scripts/generate-firebase-sw.js
 * يُنصح بتشغيله قبل: flutter build web
 */
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const templatePath = path.join(root, 'web', 'firebase-messaging-sw.example.js');
const outputPath = path.join(root, 'web', 'firebase-messaging-sw.js');
const firebaseOptionsPath = path.join(root, 'lib', 'firebase_options.dart');

function extractWebFirebaseConfig(dartContent) {
  const blockMatch = dartContent.match(/static const FirebaseOptions web = FirebaseOptions\\(([\\s\\S]*?)\\);/);
  if (!blockMatch) {
    throw new Error('Could not find "static const FirebaseOptions web" block in lib/firebase_options.dart');
  }
  const block = blockMatch[1];

  function readField(name) {
    const m = block.match(new RegExp(String.raw`${name}\\s*:\\s*'([^']*)'`));
    return m ? m[1] : '';
  }

  return {
    apiKey: readField('apiKey'),
    authDomain: readField('authDomain'),
    projectId: readField('projectId'),
    storageBucket: readField('storageBucket'),
    messagingSenderId: readField('messagingSenderId'),
    appId: readField('appId'),
    measurementId: readField('measurementId'),
  };
}

if (!fs.existsSync(firebaseOptionsPath)) {
  throw new Error('Missing lib/firebase_options.dart. Run: flutterfire configure');
}

const dartContent = fs.readFileSync(firebaseOptionsPath, 'utf8');
const webConfig = extractWebFirebaseConfig(dartContent);

const mapping = {
  __FIREBASE_WEB_API_KEY__: webConfig.apiKey || '',
  __FIREBASE_WEB_AUTH_DOMAIN__: webConfig.authDomain || '',
  __FIREBASE_WEB_PROJECT_ID__: webConfig.projectId || '',
  __FIREBASE_WEB_STORAGE_BUCKET__: webConfig.storageBucket || '',
  __FIREBASE_WEB_MESSAGING_SENDER_ID__: webConfig.messagingSenderId || '',
  __FIREBASE_WEB_APP_ID__: webConfig.appId || '',
  __FIREBASE_WEB_MEASUREMENT_ID__: webConfig.measurementId || '',
};

let template = fs.readFileSync(templatePath, 'utf8');
for (const [placeholder, value] of Object.entries(mapping)) {
  template = template.split(placeholder).join(value);
}

fs.writeFileSync(outputPath, template, 'utf8');
console.log('Generated', outputPath);
