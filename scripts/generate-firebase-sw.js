/**
 * يقرأ .env ويولّد web/firebase-messaging-sw.js من القالب.
 * التشغيل من جذر المشروع: node scripts/generate-firebase-sw.js
 * يُنصح بتشغيله قبل: flutter build web
 */
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const envPath = path.join(root, '.env');
const templatePath = path.join(root, 'web', 'firebase-messaging-sw.example.js');
const outputPath = path.join(root, 'web', 'firebase-messaging-sw.js');

function parseEnv(content) {
  const env = {};
  const lines = content.split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    let key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    env[key] = value;
  }
  return env;
}

const envContent = fs.existsSync(envPath)
  ? fs.readFileSync(envPath, 'utf8')
  : '';
const env = parseEnv(envContent);

const mapping = {
  __FIREBASE_WEB_API_KEY__: env.FIREBASE_WEB_API_KEY || '',
  __FIREBASE_WEB_AUTH_DOMAIN__: env.FIREBASE_WEB_AUTH_DOMAIN || '',
  __FIREBASE_WEB_PROJECT_ID__: env.FIREBASE_WEB_PROJECT_ID || '',
  __FIREBASE_WEB_STORAGE_BUCKET__: env.FIREBASE_WEB_STORAGE_BUCKET || '',
  __FIREBASE_WEB_MESSAGING_SENDER_ID__: env.FIREBASE_WEB_MESSAGING_SENDER_ID || '',
  __FIREBASE_WEB_APP_ID__: env.FIREBASE_WEB_APP_ID || '',
  __FIREBASE_WEB_MEASUREMENT_ID__: env.FIREBASE_WEB_MEASUREMENT_ID || '',
};

let template = fs.readFileSync(templatePath, 'utf8');
for (const [placeholder, value] of Object.entries(mapping)) {
  template = template.split(placeholder).join(value);
}

fs.writeFileSync(outputPath, template, 'utf8');
console.log('Generated', outputPath);
