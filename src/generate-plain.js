#!/usr/bin/env node
/**
 * generate-plain.js
 *
 * Runs at deploy time (Node.js, no deps) to produce plain.txt.
 * This file is what terminal clients (curl/wget) receive — a fresh
 * cryptographically secure password, one per request at deploy time.
 *
 * For true per-request generation in a pure S3/CloudFront stack we
 * generate a batch of passwords and serve one randomly at response time
 * via the CloudFront Function. The plain.txt contains a single strong
 * default password; query-param customisation is handled by the CF Function
 * redirecting to pre-generated variant files.
 *
 * Usage: node generate-plain.js  (outputs plain.txt to stdout)
 */

const { randomBytes } = require('crypto');
const fs = require('fs');
const path = require('path');

const UPPER   = 'ABCDEFGHJKLMNPQRSTUVWXYZ';   // no I,O
const LOWER   = 'abcdefghijkmnpqrstuvwxyz';    // no l,o
const DIGITS  = '23456789';                     // no 0,1
const SYMBOLS = '!@#$%^&*-_=+?';

const CHARSET = UPPER + LOWER + DIGITS + SYMBOLS;

function securePassword(len = 24) {
  // Rejection sampling — no modulo bias
  const limit = Math.floor(256 / CHARSET.length) * CHARSET.length;
  const result = [];
  while (result.length < len) {
    const byte = randomBytes(1)[0];
    if (byte < limit) result.push(CHARSET[byte % CHARSET.length]);
  }
  // Guarantee at least one of each class
  const req = [
    UPPER[randomBytes(1)[0] % UPPER.length],
    LOWER[randomBytes(1)[0] % LOWER.length],
    DIGITS[randomBytes(1)[0] % DIGITS.length],
    SYMBOLS[randomBytes(1)[0] % SYMBOLS.length],
  ];
  // Splice required chars into random positions
  req.forEach(c => {
    const pos = randomBytes(1)[0] % result.length;
    result[pos] = c;
  });
  return result.join('');
}

// Generate a small pool — CloudFront Function picks one at request time
// by using the viewer's request timestamp % pool size as an index.
const POOL_SIZE = 50;
const passwords = Array.from({ length: POOL_SIZE }, () => securePassword(24));

const content = passwords.join('\n') + '\n';

const outPath = path.join(__dirname, 'plain.txt');
fs.writeFileSync(outPath, content, 'utf8');

// Also write a JSON manifest for the CF function to index into
const jsonPath = path.join(__dirname, 'plain.json');
fs.writeFileSync(jsonPath, JSON.stringify({ passwords }, null, 0), 'utf8');

console.log(`Generated ${POOL_SIZE} passwords → plain.txt + plain.json`);
