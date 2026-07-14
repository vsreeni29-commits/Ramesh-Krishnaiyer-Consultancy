import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const html = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const css = await readFile(new URL('../styles.css', import.meta.url), 'utf8');
const script = await readFile(new URL('../script.js', import.meta.url), 'utf8');

test('publishes the supplied contact details', () => {
  assert.match(html, /Ramesh Krishnaiyer/);
  assert.match(html, /tel:\+916383310997/g);
  assert.match(html, /rameshkishnaiyer1962@gmail\.com/g);
  assert.match(html, /Chennai, Tamil Nadu/);
});

test('contains all twelve service cards and working filters', () => {
  const cards = html.match(/class="service-card(?: reveal)?(?: featured)?"/g) ?? [];
  assert.equal(cards.length, 12);
  assert.match(html, /data-filter="personal"/);
  assert.match(html, /data-filter="business"/);
  assert.match(html, /data-filter="organisation"/);
  assert.match(script, /card\.hidden = !isVisible/);
});

test('keeps internal navigation targets valid', () => {
  const ids = new Set([...html.matchAll(/\sid="([^"]+)"/g)].map((match) => match[1]));
  const internalLinks = [...html.matchAll(/href="#([^"]+)"/g)].map((match) => match[1]);
  for (const target of internalLinks) assert.ok(ids.has(target), `Missing section #${target}`);
});

test('provides accessibility and reduced-motion safeguards', () => {
  assert.match(html, /class="skip-link"/);
  assert.match(html, /aria-live="polite"/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(script, /prefers-reduced-motion: reduce/);
});

test('enquiry data stays client-side and prepares an email', () => {
  assert.match(script, /new FormData\(inquiryForm\)/);
  assert.match(script, /mailto:rameshkishnaiyer1962@gmail\.com/);
  assert.doesNotMatch(script, /fetch\(/);
});
