#!/usr/bin/env node
/**
 * @followin/skills CLI
 *
 * Commands:
 *   setup      One-stop install: copy skill files + configure MCP servers
 *   install    Copy skill files only
 *   configure  Configure MCP servers only (writes to client config file)
 *   uninstall  Remove bundled skills from a target dir
 *   list       Show bundled skills
 *   path       Print the source dir of bundled skill files
 *   clients    Show available --client presets
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const https = require('https');

const PKG_ROOT = path.resolve(__dirname, '..');
const SOURCE_DIR = path.join(PKG_ROOT, '.claude', 'commands');

const FOLLOWIN_MCP_URL = 'https://mcp.followin.io/sse';
const PREMIUM_MCP_URL = 'https://premium-mcp.followin.io/sse';

// ---------- Client registry ----------
//
// Each client may support skill-file install, MCP-config injection, or both.
// Fields:
//   description  human-readable label
//   skillsDir    where to copy *.md skill files (null = client doesn't read .md)
//   mcpConfig    path to JSON config that holds mcpServers (null = unsupported)
//   mcpFormat    'standard' = top-level mcpServers key, JSON

function claudeDesktopConfigPath() {
  if (process.platform === 'darwin') {
    return path.join(os.homedir(), 'Library', 'Application Support', 'Claude', 'claude_desktop_config.json');
  }
  if (process.platform === 'win32') {
    return path.join(process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming'), 'Claude', 'claude_desktop_config.json');
  }
  return path.join(os.homedir(), '.config', 'Claude', 'claude_desktop_config.json');
}

const CLIENTS = {
  'claude-code': {
    description: 'Claude Code CLI (global)',
    skillsDir: path.join(os.homedir(), '.claude', 'commands'),
    mcpConfig: path.join(os.homedir(), '.claude', 'settings.json'),
    mcpFormat: 'standard',
  },
  'claude-code-project': {
    description: 'Claude Code (project-local)',
    skillsDir: path.join(process.cwd(), '.claude', 'commands'),
    mcpConfig: path.join(process.cwd(), '.mcp.json'),
    mcpFormat: 'standard',
  },
  'claude-desktop': {
    description: 'Claude Desktop',
    skillsDir: null,
    mcpConfig: claudeDesktopConfigPath(),
    mcpFormat: 'standard',
  },
  'cursor': {
    description: 'Cursor',
    skillsDir: null,
    mcpConfig: path.join(os.homedir(), '.cursor', 'mcp.json'),
    mcpFormat: 'standard',
  },
  'windsurf': {
    description: 'Windsurf',
    skillsDir: null,
    mcpConfig: path.join(os.homedir(), '.codeium', 'windsurf', 'mcp_config.json'),
    mcpFormat: 'standard',
  },
  'opencode': {
    description: 'OpenCode / OpenClaw',
    skillsDir: path.join(os.homedir(), '.config', 'opencode', 'command'),
    mcpConfig: null,
    mcpFormat: null,
  },
};

const DEFAULT_CLIENT = 'claude-code';

// ---------- Args ----------
function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--target' || a === '-t') {
      args.target = argv[++i];
    } else if (a === '--client' || a === '-c') {
      args.client = argv[++i];
    } else if (a === '--api-key' || a === '-k') {
      args.apiKey = argv[++i];
    } else if (a === '--no-validate') {
      args.noValidate = true;
    } else if (a === '--no-skills') {
      args.noSkills = true;
    } else if (a === '--no-mcp') {
      args.noMcp = true;
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

function resolveClient(args) {
  const name = args.client || DEFAULT_CLIENT;
  const client = CLIENTS[name];
  if (!client) {
    console.error(`Error: unknown client "${name}".`);
    console.error('Run `followin-skills clients` to see available presets.');
    process.exit(2);
  }
  return { name, client };
}

// ---------- Skill files ----------
function listSkillFiles() {
  if (!fs.existsSync(SOURCE_DIR)) {
    console.error(`Source directory not found: ${SOURCE_DIR}`);
    process.exit(1);
  }
  return fs.readdirSync(SOURCE_DIR).filter((f) => f.endsWith('.md')).sort();
}

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function copySkills(targetDir) {
  if (path.resolve(targetDir) === path.resolve(SOURCE_DIR)) {
    console.error('Error: target dir is the same as the source dir. Aborting.');
    process.exit(1);
  }
  ensureDir(targetDir);
  const files = listSkillFiles();
  let added = 0;
  let updated = 0;
  for (const f of files) {
    const dest = path.join(targetDir, f);
    const existed = fs.existsSync(dest);
    fs.copyFileSync(path.join(SOURCE_DIR, f), dest);
    console.log(`  [${existed ? 'updated' : 'added  '}] ${f}`);
    if (existed) updated++;
    else added++;
  }
  return { total: files.length, added, updated };
}

// ---------- MCP config ----------
function readJsonOrEmpty(file) {
  if (!fs.existsSync(file)) return {};
  const raw = fs.readFileSync(file, 'utf8').trim();
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch (err) {
    console.error(`Error: ${file} is not valid JSON.`);
    console.error(`  ${err.message}`);
    console.error('Fix the file or remove it, then re-run.');
    process.exit(1);
  }
}

function buildMcpEntry(url, apiKey) {
  return {
    type: 'sse',
    url: `${url}?api_key=${encodeURIComponent(apiKey)}`,
    headers: {
      'X-API-Key': apiKey,
    },
  };
}

function writeMcpConfig(client, apiKey) {
  if (!client.mcpConfig) {
    return { skipped: true, reason: 'client does not support automatic MCP config' };
  }
  const file = client.mcpConfig;
  ensureDir(path.dirname(file));
  const config = readJsonOrEmpty(file);
  if (!config.mcpServers || typeof config.mcpServers !== 'object') {
    config.mcpServers = {};
  }
  const hadFollowin = !!config.mcpServers['followin-mcp'];
  const hadPremium = !!config.mcpServers['premium-mcp'];
  config.mcpServers['followin-mcp'] = buildMcpEntry(FOLLOWIN_MCP_URL, apiKey);
  config.mcpServers['premium-mcp'] = buildMcpEntry(PREMIUM_MCP_URL, apiKey);
  fs.writeFileSync(file, JSON.stringify(config, null, 2) + '\n', { mode: 0o600 });
  try {
    fs.chmodSync(file, 0o600);
  } catch (_) {
    // best-effort on Windows / odd FS
  }
  return {
    skipped: false,
    file,
    followin: hadFollowin ? 'updated' : 'added',
    premium: hadPremium ? 'updated' : 'added',
  };
}

// ---------- API key resolution ----------
async function resolveApiKey(args) {
  if (args.apiKey) return args.apiKey;
  if (process.env.FOLLOWIN_API_KEY) return process.env.FOLLOWIN_API_KEY;
  if (!process.stdin.isTTY) {
    console.error('Error: no API key provided.');
    console.error('Pass --api-key <key> or set FOLLOWIN_API_KEY environment variable.');
    process.exit(2);
  }
  return await promptHidden('Enter your Followin API key (input hidden): ');
}

function promptHidden(question) {
  return new Promise((resolve) => {
    const stdin = process.stdin;
    process.stdout.write(question);
    stdin.setEncoding('utf8');
    if (stdin.isTTY) stdin.setRawMode(true);
    let input = '';
    const onData = (char) => {
      const c = char.toString('utf8');
      if (c === '\r' || c === '\n' || c === '\u0004') {
        if (stdin.isTTY) stdin.setRawMode(false);
        stdin.removeListener('data', onData);
        stdin.pause();
        process.stdout.write('\n');
        resolve(input.trim());
      } else if (c === '\u0003') {
        // Ctrl-C
        if (stdin.isTTY) stdin.setRawMode(false);
        process.stdout.write('\n');
        process.exit(130);
      } else if (c === '\u007f' || c === '\b') {
        if (input.length > 0) {
          input = input.slice(0, -1);
          process.stdout.write('\b \b');
        }
      } else {
        input += c;
        process.stdout.write('*');
      }
    };
    stdin.on('data', onData);
    stdin.resume();
  });
}

// ---------- Connection validation ----------
function validateMcpConnection(url, apiKey) {
  return new Promise((resolve) => {
    const u = new URL(url);
    u.searchParams.set('api_key', apiKey);
    const req = https.get(
      u.toString(),
      {
        headers: { 'X-API-Key': apiKey, Accept: 'text/event-stream' },
        timeout: 6000,
      },
      (res) => {
        const status = res.statusCode || 0;
        // SSE returns a long-lived 200 stream. We just need the headers.
        res.destroy();
        resolve({ ok: status >= 200 && status < 400, status });
      }
    );
    req.on('error', (err) => resolve({ ok: false, error: err.message }));
    req.on('timeout', () => {
      req.destroy();
      resolve({ ok: false, error: 'timeout' });
    });
  });
}

async function validateBoth(apiKey) {
  const [followin, premium] = await Promise.all([
    validateMcpConnection(FOLLOWIN_MCP_URL, apiKey),
    validateMcpConnection(PREMIUM_MCP_URL, apiKey),
  ]);
  return { followin, premium };
}

function formatValidationResult(name, result) {
  if (result.ok) return `  [ok    ] ${name} (HTTP ${result.status})`;
  if (result.status) return `  [fail  ] ${name} (HTTP ${result.status})`;
  return `  [fail  ] ${name} (${result.error})`;
}

// ---------- Commands ----------
async function setup(args) {
  const { name, client } = resolveClient(args);
  console.log(`Setting up @followin/skills for: ${client.description}`);
  console.log('');

  // 1. Skill files
  if (!args.noSkills && client.skillsDir) {
    console.log(`Step 1/3 — installing skill files to ${client.skillsDir}`);
    const targetDir = args.target ? path.resolve(args.target) : client.skillsDir;
    const result = copySkills(targetDir);
    console.log(`  ${result.total} skills (${result.added} new, ${result.updated} updated)`);
    console.log('');
  } else if (!args.noSkills && !client.skillsDir) {
    console.log(`Step 1/3 — skill files: skipped (${name} does not read .md skill files directly)`);
    console.log('  See README "(b) Use as on-demand system prompt" section.');
    console.log('');
  }

  // 2. MCP config
  if (args.noMcp || !client.mcpConfig) {
    if (!client.mcpConfig) {
      console.log(`Step 2/3 — MCP config: skipped (${name} not yet supported for auto-config)`);
      console.log('  See README Step 2 to configure manually.');
      console.log('');
    }
  } else {
    const apiKey = await resolveApiKey(args);
    if (!apiKey) {
      console.error('Error: empty API key.');
      process.exit(2);
    }
    console.log(`Step 2/3 — writing MCP config to ${client.mcpConfig}`);
    const r = writeMcpConfig(client, apiKey);
    console.log(`  followin-mcp: ${r.followin}`);
    console.log(`  premium-mcp:  ${r.premium}`);
    console.log('');

    // 3. Validate
    if (!args.noValidate) {
      console.log('Step 3/3 — validating MCP connections');
      const v = await validateBoth(apiKey);
      console.log(formatValidationResult('followin-mcp', v.followin));
      console.log(formatValidationResult('premium-mcp ', v.premium));
      console.log('');
      if (!v.followin.ok || !v.premium.ok) {
        console.error('Warning: one or both MCPs failed to validate.');
        console.error('Common causes: invalid API key (HTTP 401/403), network restrictions, or temporary server issue.');
        console.error('Config has been written — fix the API key and re-run `followin-skills configure` if needed.');
        console.log('');
      }
    } else {
      console.log('Step 3/3 — validation skipped (--no-validate)');
      console.log('');
    }
  }

  console.log('Done. Restart your client to pick up the new skills and MCPs.');
  if (client.mcpConfig) {
    console.log('');
    console.log(`Note: your API key is stored in plaintext in ${client.mcpConfig}`);
    console.log('That file has been chmod 600 (owner-only). Do not commit it to git.');
  }
}

function install(args) {
  const { client } = resolveClient(args);
  if (!client.skillsDir && !args.target) {
    console.error(`Error: client "${args.client}" does not support skill-file install.`);
    console.error('Use --target DIR to specify a custom destination, or use a different client.');
    process.exit(2);
  }
  const targetDir = args.target ? path.resolve(args.target) : client.skillsDir;
  const label = args.target ? args.target : (args.client || DEFAULT_CLIENT);
  const result = copySkills(targetDir);
  console.log('');
  console.log(`Installed ${result.total} skills (${result.added} new, ${result.updated} updated)`);
  console.log(`  target : ${targetDir}`);
  console.log(`  client : ${label}`);
  console.log('');
  console.log('Next: configure the MCP servers');
  console.log('  npx @followin/skills configure');
  console.log('Or do both at once:');
  console.log('  npx @followin/skills setup');
}

async function configure(args) {
  const { name, client } = resolveClient(args);
  if (!client.mcpConfig) {
    console.error(`Error: client "${name}" does not support automatic MCP config.`);
    console.error('See README Step 2 to configure manually.');
    process.exit(2);
  }
  const apiKey = await resolveApiKey(args);
  if (!apiKey) {
    console.error('Error: empty API key.');
    process.exit(2);
  }
  console.log(`Writing MCP config to ${client.mcpConfig}`);
  const r = writeMcpConfig(client, apiKey);
  console.log(`  followin-mcp: ${r.followin}`);
  console.log(`  premium-mcp:  ${r.premium}`);
  console.log('');
  if (!args.noValidate) {
    console.log('Validating MCP connections...');
    const v = await validateBoth(apiKey);
    console.log(formatValidationResult('followin-mcp', v.followin));
    console.log(formatValidationResult('premium-mcp ', v.premium));
    console.log('');
    if (!v.followin.ok || !v.premium.ok) {
      console.error('Warning: one or both MCPs failed to validate. Check your API key.');
      console.log('');
    }
  }
  console.log('Done. Restart your client.');
  console.log('');
  console.log(`Note: your API key is stored in plaintext in ${client.mcpConfig}`);
  console.log('That file has been chmod 600 (owner-only). Do not commit it to git.');
}

function uninstall(args) {
  const { name, client } = resolveClient(args);
  const targetDir = args.target ? path.resolve(args.target) : client.skillsDir;
  if (!targetDir) {
    console.error(`Error: client "${name}" does not have a default skills dir. Pass --target DIR.`);
    process.exit(2);
  }
  if (!fs.existsSync(targetDir)) {
    console.log(`Target dir does not exist: ${targetDir}`);
    return;
  }
  const files = listSkillFiles();
  let removed = 0;
  for (const f of files) {
    const dest = path.join(targetDir, f);
    if (fs.existsSync(dest)) {
      fs.unlinkSync(dest);
      console.log(`  [removed] ${f}`);
      removed++;
    }
  }
  console.log('');
  console.log(`Removed ${removed} skills from ${targetDir}`);
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
  console.log('Available clients:');
  console.log('');
  const maxName = Math.max(...Object.keys(CLIENTS).map((k) => k.length));
  for (const [name, c] of Object.entries(CLIENTS)) {
    const isDefault = name === DEFAULT_CLIENT ? ' (default)' : '';
    const skills = c.skillsDir ? 'skills' : '     ';
    const mcp = c.mcpConfig ? 'mcp' : '   ';
    console.log(`  ${name.padEnd(maxName)}  [${skills} ${mcp}]  ${c.description}${isDefault}`);
    if (c.skillsDir) console.log(`  ${' '.repeat(maxName)}    skills -> ${c.skillsDir}`);
    if (c.mcpConfig) console.log(`  ${' '.repeat(maxName)}    mcp    -> ${c.mcpConfig}`);
  }
  console.log('');
  console.log('Legend: [skills mcp] = supported features for `setup`, `install`, `configure`');
  console.log('');
  console.log('Other clients (Cline, Continue.dev, ...): use `path` + manual config.');
}

function postinstall() {
  console.log('');
  console.log('@followin/skills installed.');
  console.log('');
  console.log('To set up everything in one command (skill files + MCP config):');
  console.log('  npx @followin/skills setup');
  console.log('');
  console.log('Or step by step:');
  console.log('  npx @followin/skills install      # skill files only');
  console.log('  npx @followin/skills configure    # MCP config only');
  console.log('');
  console.log('Run `npx @followin/skills clients` to see all supported clients.');
  console.log('');
}

function usage(exitCode = 0) {
  console.log('Usage: followin-skills <command> [options]');
  console.log('');
  console.log('Commands:');
  console.log('  setup       One-stop install: copy skill files + configure MCP servers');
  console.log('  install     Copy skill files only');
  console.log('  configure   Configure MCP servers only (writes to client config file)');
  console.log('  uninstall   Remove bundled skills from target dir');
  console.log('  list        Show bundled skills');
  console.log('  path        Print source dir of bundled skill files');
  console.log('  clients     Show available clients and what they support');
  console.log('');
  console.log('Options:');
  console.log('  --client, -c NAME    Target client (default: claude-code)');
  console.log('  --target, -t DIR     Override skill install dir');
  console.log('  --api-key, -k KEY    Followin API key (also: $FOLLOWIN_API_KEY)');
  console.log('  --no-validate        Skip MCP connection check after configure');
  console.log('  --no-skills          setup: skip skill-file install');
  console.log('  --no-mcp             setup: skip MCP config');
  console.log('');
  console.log('Examples:');
  console.log('  npx @followin/skills setup');
  console.log('  npx @followin/skills setup --client cursor --api-key sk_xxx');
  console.log('  npx @followin/skills install --client opencode');
  console.log('  npx @followin/skills configure --client claude-desktop');
  console.log('  cp $(npx @followin/skills path)/*.md ~/wherever/');
  process.exit(exitCode);
}

// ---------- Entry ----------
async function main() {
  const args = parseArgs(process.argv.slice(2));
  const cmd = args._[0];
  if (args.help && !cmd) usage(0);

  switch (cmd) {
    case 'setup':
      await setup(args);
      break;
    case 'install':
      install(args);
      break;
    case 'configure':
      await configure(args);
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
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
