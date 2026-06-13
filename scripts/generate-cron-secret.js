/**
 * Generate a cryptographically strong CRON_SECRET for Supabase scheduled-notifications.
 *
 * Usage (from repo root):
 *   node scripts/generate-cron-secret.js
 *   node scripts/generate-cron-secret.js --bytes 48
 *   node scripts/generate-cron-secret.js --copy   # Windows: copy secret to clipboard
 *
 * Then set it in Supabase:
 *   supabase secrets set CRON_SECRET="<secret>"
 *
 * Use the same value in Dashboard → Integrations → Cron → HTTP Headers:
 *   x-cron-secret: <secret>
 */
const crypto = require('crypto');
const { execSync } = require('child_process');

const args = process.argv.slice(2);

function readBytesFlag() {
  const i = args.indexOf('--bytes');
  if (i === -1) return 32;
  const n = Number.parseInt(args[i + 1], 10);
  if (!Number.isFinite(n) || n < 16 || n > 128) {
    console.error('Error: --bytes must be an integer between 16 and 128.');
    process.exit(1);
  }
  return n;
}

const bytes = readBytesFlag();
const secret = crypto.randomBytes(bytes).toString('base64url');

console.log('');
console.log('CRON_SECRET (base64url, %d bytes / %d bits):', bytes, bytes * 8);
console.log('');
console.log(secret);
console.log('');
console.log('Set in Supabase:');
console.log('  supabase secrets set CRON_SECRET="' + secret + '"');
console.log('');
console.log('Cron header (must match exactly):');
console.log('  x-cron-secret: ' + secret);
console.log('');

if (args.includes('--copy')) {
  if (process.platform === 'win32') {
    execSync('clip', { input: secret, stdio: ['pipe', 'ignore', 'ignore'] });
    console.log('Copied to clipboard.');
  } else if (process.platform === 'darwin') {
    execSync('pbcopy', { input: secret, stdio: ['pipe', 'ignore', 'ignore'] });
    console.log('Copied to clipboard.');
  } else {
    try {
      execSync('xclip -selection clipboard', {
        input: secret,
        stdio: ['pipe', 'ignore', 'ignore'],
      });
      console.log('Copied to clipboard.');
    } catch {
      console.log('Install xclip to use --copy on Linux, or copy the line above.');
    }
  }
}
