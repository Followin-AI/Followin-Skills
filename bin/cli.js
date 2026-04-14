#!/usr/bin/env node
/**
 * followin-skills CLI
 *
 * Commands:
 *   install     Copy skill files to ~/.claude/commands/
 *   uninstall   Remove bundled skills from ~/.claude/commands/
 *   list        Show bundled skills
 *   postinstall Internal hint after `npm install`
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const PKG_ROOT = path.resolve(__dirname, '..');
const SOURCE_DIR = path.join(PKG_ROOT, '.claude', 'commands');
const TARGET_DIR = path.join(os.homedir(), '.claude', 'commands');

function listSkillFiles() {
  if (!fs.existsSync(SOURCE_DIR)) {
    console.error(`Source directory not found: ${SOURCE_DIR}`);
    process.exit(1);
  }
  return fs
    .readdirSync(SOURCE_DIR)
    .filter((f) => f.endsWith('.md'))
    .sort();
}

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function install() {
  ensureDir(TARGET_DIR);
  const files = listSkillFiles();
  let copied = 0;
  let overwritten = 0;
  for (const f of files) {
    const dest = path.join(TARGET_DIR, f);
    const existed = fs.existsSync(dest);
    fs.copyFileSync(path.join(SOURCE_DIR, f), dest);
    console.log(`  [${existed ? 'updated' : 'added  '}] ${f}`);
    if (existed) overwritten++;
    else copied++;
  }
  console.log('');
  console.log(`Installed ${files.length} skills to ${TARGET_DIR}`);
  console.log(`  ${copied} new, ${overwritten} updated`);
  console.log('');
  console.log('These skills require the following MCP servers:');
  console.log('  - Followin MCP      (news / intel center)');
  console.log('  - Premium MCP       (FMP + FRED + Twitter + TG)');
  console.log('See README for MCP setup instructions.');
  console.log('');
  console.log('Restart Claude Code to pick up the new skills.');
}

function uninstall() {
  const files = listSkillFiles();
  let removed = 0;
  for (const f of files) {
    const dest = path.join(TARGET_DIR, f);
    if (fs.existsSync(dest)) {
      fs.unlinkSync(dest);
      console.log(`  [removed] ${f}`);
      removed++;
    }
  }
  console.log('');
  console.log(`Removed ${removed} skills from ${TARGET_DIR}`);
}

function list() {
  const files = listSkillFiles();
  console.log(`Bundled skills (${files.length}):`);
  for (const f of files) console.log(`  - ${f}`);
}

function postinstall() {
  // Do not auto-copy: user must opt in via `followin-skills install`.
  // This avoids surprising global-state changes on `npm install`.
  console.log('');
  console.log('followin-skills installed.');
  console.log('');
  console.log('To activate the skills, run:');
  console.log('  npx followin-skills install');
  console.log('');
}

const cmd = process.argv[2];
switch (cmd) {
  case 'install':
    install();
    break;
  case 'uninstall':
    uninstall();
    break;
  case 'list':
    list();
    break;
  case 'postinstall':
    postinstall();
    break;
  default:
    console.log('Usage: followin-skills <install|uninstall|list>');
    console.log('');
    console.log('Commands:');
    console.log('  install     Copy skills to ~/.claude/commands/');
    console.log('  uninstall   Remove bundled skills from ~/.claude/commands/');
    console.log('  list        Show bundled skills');
    process.exit(cmd ? 1 : 0);
}
