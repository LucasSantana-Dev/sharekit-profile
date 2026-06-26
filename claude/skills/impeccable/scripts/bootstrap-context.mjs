#!/usr/bin/env node

/**
 * bootstrap-context.mjs
 *
 * Auto-infer PRODUCT.md fields from README.md, package.json, and component analysis.
 * Used when PRODUCT.md is missing or sparse to seed the design brief with real data.
 *
 * Usage:
 *   node bootstrap-context.mjs [cwd]
 *
 * Output:
 *   JSON object with inferred PRODUCT.md fields, or null if insufficient data.
 *
 * Exit codes:
 *   0 = success (inferred some fields)
 *   1 = insufficient data (couldn't infer meaningful fields)
 *   2 = error (file read failed, invalid JSON, etc.)
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const cwd = process.argv[2] || process.cwd();

/**
 * Read file safely, return empty string if not found.
 */
function safeRead(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return '';
  }
}

/**
 * Parse package.json safely.
 */
function readPackageJson() {
  const pkgPath = path.join(cwd, 'package.json');
  const content = safeRead(pkgPath);
  if (!content) return {};
  try {
    return JSON.parse(content);
  } catch {
    return {};
  }
}

/**
 * Infer product type from package.json and component names.
 * Returns one of: 'app', 'design-system', 'website', 'library', 'unknown'.
 */
function inferProductType(pkg, components) {
  // Check keywords in package.json
  const keywords = pkg.keywords || [];
  if (keywords.includes('design-system') || keywords.includes('ui-library')) {
    return 'design-system';
  }
  if (keywords.includes('website') || keywords.includes('landing')) {
    return 'website';
  }
  if (keywords.includes('app') || keywords.includes('dashboard')) {
    return 'app';
  }

  // Check package name
  const name = pkg.name || '';
  if (name.includes('system') || name.includes('ui')) {
    return 'design-system';
  }
  if (name.includes('app') || name.includes('dashboard') || name.includes('tool')) {
    return 'app';
  }
  if (name.includes('web') || name.includes('site')) {
    return 'website';
  }

  // Check component names
  const componentNames = components.join(' ').toLowerCase();
  if (
    componentNames.includes('button') &&
    componentNames.includes('input') &&
    componentNames.includes('modal')
  ) {
    return 'design-system';
  }
  if (
    componentNames.includes('dashboard') ||
    componentNames.includes('chart') ||
    componentNames.includes('table')
  ) {
    return 'app';
  }

  return 'unknown';
}

/**
 * Scan src/components or similar for component names.
 * Returns array of component names.
 */
function inferComponents() {
  const componentDirs = [
    path.join(cwd, 'src/components'),
    path.join(cwd, 'components'),
    path.join(cwd, 'src/ui'),
    path.join(cwd, 'ui'),
  ];

  for (const dir of componentDirs) {
    if (!fs.existsSync(dir)) continue;

    const items = safeReaddir(dir);
    if (items.length > 0) {
      return items
        .filter((name) => !name.startsWith('.') && name !== 'index.js' && name !== 'index.ts')
        .slice(0, 10); // First 10 component names
    }
  }

  return [];
}

/**
 * Safe readdir.
 */
function safeReaddir(dirPath) {
  try {
    return fs.readdirSync(dirPath);
  } catch {
    return [];
  }
}

/**
 * Extract a short description from README.md.
 */
function inferFromReadme() {
  const readmePath = path.join(cwd, 'README.md');
  const content = safeRead(readmePath);
  if (!content) return '';

  // Extract first paragraph (before first ## or ###)
  const lines = content.split('\n');
  const description = [];
  for (const line of lines) {
    if (line.startsWith('#')) break;
    if (line.trim()) description.push(line.trim());
  }
  return description.join(' ').slice(0, 200);
}

/**
 * Extract product purpose and users from package.json description and context.
 */
function inferFromPackageJson(pkg) {
  return {
    description: pkg.description || '',
    author: pkg.author || '',
    license: pkg.license || '',
  };
}

/**
 * Synthesize a complete PRODUCT.md inference.
 */
function synthesizeProductMd(pkg, components, readme) {
  const productType = inferProductType(pkg, components);
  const description = readme || pkg.description || '';

  let userRole = 'User';
  let productPurpose = description;

  // Refine based on product type
  if (productType === 'design-system') {
    userRole = 'Designer or Developer';
    productPurpose = productPurpose || 'A reusable component library and design system.';
  } else if (productType === 'app') {
    userRole = 'End user';
    productPurpose = productPurpose || 'A web application for managing tasks, data, or workflows.';
  } else if (productType === 'website') {
    userRole = 'Visitor';
    productPurpose = productPurpose || 'A website to inform, educate, or market a product or service.';
  }

  return {
    register: productType === 'website' || productType === 'design-system' ? 'brand' : 'product',
    productType,
    users: userRole,
    productPurpose: productPurpose.slice(0, 300),
    brand: pkg.name || 'Project',
    tone: productType === 'website' ? 'Clear, engaging' : 'Clear, professional',
    antiReferences: [],
    strategicPrinciples: [],
  };
}

/**
 * Main entrypoint.
 */
async function main() {
  try {
    // Read package.json and README
    const pkg = readPackageJson();
    const readme = inferFromReadme();
    const components = inferComponents();

    // If neither package.json nor README exists, fail gracefully
    if (!pkg.name && !readme) {
      console.error('Unable to infer PRODUCT.md: no package.json or README.md found.');
      process.exit(1);
    }

    // Synthesize the inference
    const inference = synthesizeProductMd(pkg, components, readme);

    // Output as JSON (machine-readable for auto mode and /impeccable teach)
    console.log(JSON.stringify(inference, null, 2));
    process.exit(0);
  } catch (error) {
    console.error(`bootstrap-context error: ${error.message}`);
    process.exit(2);
  }
}

main();
