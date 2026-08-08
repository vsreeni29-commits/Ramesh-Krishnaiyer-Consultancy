import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const html = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const css = await readFile(new URL('../styles.css', import.meta.url), 'utf8');
const script = await readFile(new URL('../script.js', import.meta.url), 'utf8');

const catalogMatch = script.match(/const serviceCatalog = Object\.freeze\((\{[\s\S]*?\n\})\);/);
assert.ok(catalogMatch, 'The service catalogue must be present in script.js');
const serviceCatalog = JSON.parse(catalogMatch[1]);

const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const escapeHtml = (value) => value.replaceAll('&', '&amp;');

test('publishes the supplied contact details', () => {
  assert.match(html, /Ramesh Krishnaiyer/);
  assert.match(html, /tel:\+916383310997/g);
  assert.match(html, /rameshkrishnaiyertx@gmail\.com/g);
  assert.match(html, /Chennai, Tamil Nadu/);
});

test('publishes the custom domain as the canonical URL', () => {
  assert.match(html, /<link rel="canonical" href="https:\/\/www\.rameshkrishnaiyertx\.com\/">/);
  assert.match(html, /<meta property="og:url" content="https:\/\/www\.rameshkrishnaiyertx\.com\/">/);
  assert.match(html, /"url": "https:\/\/www\.rameshkrishnaiyertx\.com\/"/);
});

test('publishes the six document-backed service areas without audience filters', () => {
  const cards = html.match(/class="service-card reveal"/g) ?? [];
  assert.equal(cards.length, 6);
  assert.deepEqual(Object.keys(serviceCatalog), [
    'Income Tax',
    'GST',
    'Professional Tax',
    'EPF & ESIC',
    'Book Keeping & Finalisation of Accounts',
    'Other Workings & Process'
  ]);

  for (const serviceArea of Object.keys(serviceCatalog)) {
    const encodedArea = escapeHtml(serviceArea);
    assert.match(html, new RegExp(`data-service-area="${escapeRegex(encodedArea)}"`));
  }

  assert.doesNotMatch(html, /data-filter=/);
  assert.doesNotMatch(script, /filterButtons|filterStatus|card\.hidden/);
});

test('catalogues all 43 document services and scopes the enquiry dropdown', () => {
  const counts = Object.values(serviceCatalog).map((items) => items.length);
  assert.deepEqual(counts, [10, 13, 4, 6, 6, 4]);
  assert.equal(counts.reduce((total, count) => total + count, 0), 43);
  assert.equal(serviceCatalog['Income Tax'][0], 'General Consultation');
  assert.match(serviceCatalog.GST.at(-1), /^ITC04/);
  assert.equal(serviceCatalog['Other Workings & Process'].at(-1), 'PAN/TAN Application Process');
  assert.match(html, /data-service-area-label/);
  assert.match(html, /name="serviceItem"/);
  assert.match(script, /function renderServiceOptions\(serviceArea\)/);
  assert.match(script, /option\.dataset\.serviceArea = area/);
  assert.match(script, /openInquiry\(button\.dataset\.serviceArea\)/);
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
  assert.match(script, /Service area: \$\{serviceArea\}/);
  assert.match(script, /Selected service: \$\{serviceItem\}/);
  assert.match(script, /mailto:rameshkrishnaiyertx@gmail\.com/);
  assert.doesNotMatch(script, /fetch\(/);
});
