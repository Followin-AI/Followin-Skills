#!/usr/bin/env node
/**
 * @followin/skills CLI
 *
 * Commands:
 *   install [--client NAME | --target DIR]   Copy skill files to a target dir
 *   uninstall [--client NAME | --target DIR] Remove bundled skills from a target dir
 *   list                                     Show bundled skills
 *   path                                     Print the source dir of bundled skills
 *   clients                                  Show available --client presets
 *   postinstall                              Internal hint after `npm install`
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const PKG_ROOT = path.resolve(__dirname, '..');
const SOURCE_DIR = path.join(PKG_ROOT, '.claude', 'commands');

// Preset target directories per AI client.
//
// Only clients that read Claude Code-style markdown skill files
// (frontmatter: name/description/trigger/...) are listed here.
// Clients with incompatible formats (Cursor, Windsurf, Cline,
// Continue.dev) should use `path` and adapt manually.
const CLIENT_PRESETS = {
  'claude-code': {
    dir: path.join(os.homedir(), '.claude', 'commands'),
    description: 'Claude Code (global ~/.claude/commands)',
  },
  'claude-code-project': {
    dir: path.join(process.cwd(), '.claude', 'commands'),
    description: 'Claude Code (project-local ./.claude/commands)',
  },
  'opencode': {
    dir: path.join(os.homedir(), '.config', 'opencode', 'command'),
    description: 'OpenCode / OpenClaw (~/.config/opencode/command)',
  },
};

const DEFAULT_CLIENT = 'claude-code';

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--target' || a === '-t') {
      args.target = argv[++i];
    } else if (a === '--client' || a === '-c') {
      args.client = argv[++i];
    } else if (a === '--help' || a === '-h') {
      args.help = true;
    } else if (a.startsWith('--')) {
      args[a.slice(2)] = true;
    } else {
      args._.push(a);
    }
  }
  return args;
}

function resolveTarget(args) {
  if (args.target && args.client) {
    console.error('Error: pass either --target or --client, not both.');
    process.exit(2);
  }
  if (args.target) {
    return { dir: path.resolve(args.target), label: args.target };
  }
  const clientName = args.client || DEFAULT_CLIENT;
  const preset = CLIENT_PRESETS[clientName];
  if (!preset) {
    console.error(`Error: unknown client "${clientName}".`);
    console.error('Run `followin-skills clients` to see available presets.');
    process.exit(2);
  }
  return { dir: preset.dir, label: clientName };
}

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

function install(args) {
  const { dir, label } = resolveTarget(args);
  if (path.resolve(dir) === path.resolve(SOURCE_DIR)) {
    console.error('Error: target dir is the same as the source dir. Aborting.');
    process.exit(1);
  }
  ensureDir(dir);
  const files = listSkillFiles();
  let added = 0;
  let updated = 0;
  for (const f of files) {
    const dest = path.join(dir, f);
    const existed = fs.existsSync(dest);
    fs.copyFileSync(path.join(SOURCE_DIR, f), dest);
    console.log(`  [${existed ? 'updated' : 'added  '}] ${f}`);
    if (existed) updated++;
    else added++;
  }
  console.log('');
  console.log(`Installed ${files.length} skills (${added} new, ${updated} updated)`);
  console.log(`  target : ${dir}`);
  console.log(`  client : ${label}`);
  console.log('');
  console.log('These skills depend on two MCP servers:');
  console.log('  - Followin MCP      (news / intel center)');
  console.log('  - Premium MCP       (FMP + FRED + Twitter + TG)');
  console.log('See README for MCP setup instructions for your client.');
  console.log('');
  console.log('Restart your client to pick up the new skills.');
}

function uninstall(args) {
  const { dir, label } = resolveTarget(args);
  if (!fs.existsSync(dir)) {
    console.log(`Target dir does not exist: ${dir}`);
    return;
  }
  const files = listSkillFiles();
  let removed = 0;
  for (const f of files) {
    const dest = path.join(dir, f);
    if (fs.existsSync(dest)) {
      fs.unlinkSync(dest);
      console.log(`  [removed] ${f}`);
      removed++;
    }
  }
  console.log('');
  console.log(`Removed ${removed} skills from ${dir} (${label})`);
}

function list() {
  const files = listSkillFiles();
  console.log(`Bundled skills (${files.length}):`);
  for (const f of files) console.log(`  - ${f}`);
}

function printPath() {
  console.log(SOURCE_DIR);
}

function clients() {
  console.log('Available --client presets:');
  console.log('');
  const maxName = Math.max(...Object.keys(CLIENT_PRESETS).map((k) => k.length));
  for (const [name, preset] of Object.entries(CLIENT_PRESETS)) {
    const isDefault = name === DEFAULT_CLIENT ? ' (default)' : '';
    console.log(`  ${name.padEnd(maxName)}  ${preset.description}${isDefault}`);
    console.log(`  ${' '.repeat(maxName)}  -> ${preset.dir}`);
  }
  console.log('');
  console.log('For other clients (Cursor, Windsurf, Cline, Continue.dev, etc.),');
  console.log('use `followin-skills path` to get the source dir and adapt the');
  console.log('skill files to your client\'s native format.');
}

function postinstall() {
  // Do not auto-copy: user must opt in via `followin-skills install`.
  // This avoids surprising global-state changes on `npm install`.
  console.log('');
  console.log('@followin/skills installed.');
  console.log('');
  console.log('To activate the skills, run:');
  console.log('  npx @followin/skills install                  # Claude Code (default)');
  console.log('  npx @followin/skills install --client opencode');
  console.log('  npx @followin/skills install --target /any/dir');
  console.log('');
  console.log('Run `npx @followin/skills clients` to see all presets.');
  console.log('');
}

function usage(exitCode = 0) {
  console.log('Usage: followin-skills <command> [options]');
  console.log('');
  console.log('Commands:');
  console.log('  install [opts]    Copy skill files to a target dir');
  console.log('  uninstall [opts]  Remove bundled skills from a target dir');
  console.log('  list              Show bundled skills');
  console.log('  path              Print the source dir of bundled skill files');
  console.log('  clients           Show available --client presets');
  console.log('');
  console.log('Options for install / uninstall:');
  console.log('  --client, -c NAME  Use a preset target dir (default: claude-code)');
  console.log('  --target, -t DIR   Use an explicit target directory');
  console.log('');
  console.log('Examples:');
  console.log('  npx @followin/skills install');
  console.log('  npx @followin/skills install --client claude-code-project');
  console.log('  npx @followin/skills install --client opencode');
  console.log('  npx @followin/skills install --target ~/my-prompts/');
  console.log('  cp $(npx @followin/skills path)/*.md ~/wherever/');
  process.exit(exitCode);
}

const args = parseArgs(process.argv.slice(2));
const cmd = args._[0];

if (args.help && !cmd) usage(0);

switch (cmd) {
  case 'install':
    install(args);
    break;
  case 'uninstall':
    uninstall(args);
    break;
  case 'list':
    list();
    break;
  case 'path':
    printPath();
    break;
  case 'clients':
    clients();
    break;
  case 'postinstall':
    postinstall();
    break;
  case undefined:
    usage(0);
    break;
  default:
    console.error(`Unknown command: ${cmd}`);
    console.error('');
    usage(1);
}
