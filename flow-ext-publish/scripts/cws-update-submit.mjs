#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";

const DEFAULT_PORT = 9223;
const TMP_ROOT = "/tmp";
const DEFAULT_TMP_PROFILE = path.join(TMP_ROOT, "chrome-debug-profile-cws");
const CHROME_APP = "Google Chrome";
const CHROME_PROFILE_ROOT = path.join(
  os.homedir(),
  "Library",
  "Application Support",
  "Google",
  "Chrome",
);

function usage() {
  return `Usage:
  node scripts/cws-update-submit.mjs --publisher <publisher-id> --item <item-id> [options]

Purpose:
  Update an existing Chrome Web Store draft field and optionally submit it for review.
  This script does not build the extension, deploy a website, generate assets, or upload store media.

Required:
  --publisher <id>       Chrome Web Store publisher UUID from the devconsole URL
  --item <id>            Chrome Web Store extension item id

Options:
  --privacy-url <url>    Set the privacy policy URL on the Privacy page
  --save                 Save the draft after applying updates
  --submit               Submit the saved draft for review; requires --save
  --no-auto-publish      Uncheck auto-publish in the final submit dialog when present
  --profile <name>       Source Chrome profile name (default: Default)
  --port <number>        CDP port for the temporary Chrome (default: ${DEFAULT_PORT})
  --tmp-profile <path>   Temporary Chrome user-data-dir under ${TMP_ROOT} (default: ${DEFAULT_TMP_PROFILE})
  --reuse-cdp            Attach to an existing Chrome already listening on --port
  --keep-browser         Leave the temporary Chrome running after the script finishes
  --help                 Show this help

Examples:
  # Dry-run: open the CWS privacy page and print the current privacy URL/status.
  node scripts/cws-update-submit.mjs \\
    --publisher b94d7c34-ac9c-4853-80c7-a109eda5c998 \\
    --item ggofobggmeflfhplmmabcodbcgpaceee

  # Update privacy URL, save draft, and submit for review.
  node scripts/cws-update-submit.mjs \\
    --publisher b94d7c34-ac9c-4853-80c7-a109eda5c998 \\
    --item ggofobggmeflfhplmmabcodbcgpaceee \\
    --privacy-url https://hold-on.pages.dev/privacy/ \\
    --save --submit
`;
}

function parseArgs(argv) {
  const opts = {
    autoPublish: true,
    keepBrowser: false,
    port: DEFAULT_PORT,
    profile: "Default",
    reuseCdp: false,
    save: false,
    submit: false,
    tmpProfile: DEFAULT_TMP_PROFILE,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case "--help":
      case "-h":
        opts.help = true;
        break;
      case "--publisher":
        opts.publisher = nextValue(argv, ++i, arg);
        break;
      case "--item":
        opts.item = nextValue(argv, ++i, arg);
        break;
      case "--privacy-url":
        opts.privacyUrl = nextValue(argv, ++i, arg);
        break;
      case "--save":
        opts.save = true;
        break;
      case "--submit":
        opts.submit = true;
        break;
      case "--no-auto-publish":
        opts.autoPublish = false;
        break;
      case "--profile":
        opts.profile = nextValue(argv, ++i, arg);
        break;
      case "--port":
        opts.port = Number.parseInt(nextValue(argv, ++i, arg), 10);
        break;
      case "--tmp-profile":
        opts.tmpProfile = nextValue(argv, ++i, arg);
        break;
      case "--reuse-cdp":
        opts.reuseCdp = true;
        break;
      case "--keep-browser":
        opts.keepBrowser = true;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return opts;
}

function nextValue(argv, index, flag) {
  const value = argv[index];
  if (!value || value.startsWith("--")) {
    throw new Error(`${flag} requires a value`);
  }
  return value;
}

function validateOpts(opts) {
  if (opts.help) return;

  if (!opts.publisher) throw new Error("--publisher is required");
  if (!opts.item) throw new Error("--item is required");
  if (!Number.isInteger(opts.port) || opts.port <= 0 || opts.port > 65535) {
    throw new Error("--port must be a valid TCP port");
  }
  if (opts.submit && !opts.save) {
    throw new Error("--submit requires --save so the submitted draft matches the requested update");
  }
  if ((opts.save || opts.submit) && !opts.privacyUrl) {
    throw new Error("No update was provided; pass --privacy-url with --save/--submit");
  }
  if (opts.privacyUrl) {
    const parsed = new URL(opts.privacyUrl);
    if (!["http:", "https:"].includes(parsed.protocol)) {
      throw new Error("--privacy-url must be an http(s) URL");
    }
  }

  const tmpRoot = path.resolve(TMP_ROOT);
  const tmpProfile = path.resolve(opts.tmpProfile);
  if (!tmpProfile.startsWith(`${tmpRoot}${path.sep}`)) {
    throw new Error(`--tmp-profile must be under ${tmpRoot}`);
  }
  opts.tmpProfile = tmpProfile;
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    stdio: options.stdio ?? "pipe",
    ...options,
  });

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0 && !options.allowFailure) {
    const stderr = result.stderr ? `\n${result.stderr.trim()}` : "";
    const stdout = result.stdout ? `\n${result.stdout.trim()}` : "";
    throw new Error(`${command} ${args.join(" ")} failed with exit ${result.status}${stderr}${stdout}`);
  }
  return result;
}

function copyIfExists(src, dst) {
  if (!fs.existsSync(src)) return false;
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  fs.cpSync(src, dst, { recursive: true, force: true });
  return true;
}

function resetTempProfile(tmpProfile) {
  fs.rmSync(tmpProfile, { recursive: true, force: true });
  fs.mkdirSync(tmpProfile, { recursive: true });
}

function copyChromeProfile(opts) {
  const sourceProfile = path.join(CHROME_PROFILE_ROOT, opts.profile);
  if (!fs.existsSync(sourceProfile)) {
    throw new Error(`Chrome profile not found: ${sourceProfile}`);
  }

  resetTempProfile(opts.tmpProfile);

  const targetProfile = path.join(opts.tmpProfile, opts.profile);
  const copied = [];
  const profileFiles = [
    "Cookies",
    "Network/Cookies",
    "Login Data",
    "Preferences",
    "Secure Preferences",
    "Web Data",
  ];

  for (const relative of profileFiles) {
    const src = path.join(sourceProfile, relative);
    const dst = path.join(targetProfile, relative);
    if (copyIfExists(src, dst)) copied.push(relative);
  }

  if (copyIfExists(path.join(CHROME_PROFILE_ROOT, "Local State"), path.join(opts.tmpProfile, "Local State"))) {
    copied.push("Local State");
  }

  if (!copied.includes("Network/Cookies") && !copied.includes("Cookies")) {
    throw new Error(`No Chrome cookies were copied from ${sourceProfile}`);
  }

  console.log(`Copied Chrome profile data: ${copied.join(", ")}`);
}

function getJson(url) {
  return new Promise((resolve, reject) => {
    const req = http.get(url, (res) => {
      let data = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        data += chunk;
      });
      res.on("end", () => {
        if (res.statusCode < 200 || res.statusCode >= 300) {
          reject(new Error(`${url} returned HTTP ${res.statusCode}`));
          return;
        }
        try {
          resolve(JSON.parse(data));
        } catch (error) {
          reject(error);
        }
      });
    });
    req.on("error", reject);
    req.setTimeout(1500, () => {
      req.destroy(new Error(`${url} timed out`));
    });
  });
}

async function waitForCdp(port, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    try {
      return await getJson(`http://127.0.0.1:${port}/json/version`);
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, 500));
    }
  }
  throw new Error(`Chrome did not expose CDP on port ${port}: ${lastError?.message ?? "timeout"}`);
}

async function currentCdp(port) {
  try {
    return await getJson(`http://127.0.0.1:${port}/json/version`);
  } catch {
    return null;
  }
}

function openChrome(opts, url) {
  run(
    "open",
    [
      "-na",
      CHROME_APP,
      "--args",
      `--remote-debugging-port=${opts.port}`,
      `--user-data-dir=${opts.tmpProfile}`,
      `--profile-directory=${opts.profile}`,
      "--no-first-run",
      "--no-default-browser-check",
      "--new-window",
      url,
    ],
    { stdio: "ignore" },
  );
}

function getTempChromePids(tmpProfile) {
  const pattern = `user-data-dir=${tmpProfile}`;
  const result = run("pgrep", ["-f", pattern], { allowFailure: true });
  return result.stdout
    .split(/\s+/)
    .map((value) => value.trim())
    .filter(Boolean);
}

function killTempChrome(tmpProfile) {
  for (const pid of getTempChromePids(tmpProfile)) {
    run("kill", [pid], { allowFailure: true });
  }
}

function createPlaywriterSession(wsEndpoint) {
  const result = run("pnpm", ["dlx", "playwriter@latest", "session", "new", "--direct", wsEndpoint]);
  const output = `${result.stdout}\n${result.stderr}`;
  const match = output.match(/Session\s+([^\s]+)\s+created/i);
  if (!match) {
    throw new Error(`Could not parse playwriter session id from:\n${output}`);
  }
  return match[1];
}

function deletePlaywriterSession(sessionId) {
  run("pnpm", ["dlx", "playwriter@latest", "session", "delete", sessionId], { allowFailure: true });
}

function playwriterEval(sessionId, code, timeoutMs = 45000) {
  const result = run("pnpm", [
    "dlx",
    "playwriter@latest",
    "-s",
    sessionId,
    "--timeout",
    String(timeoutMs),
    "-e",
    code,
  ]);
  return result.stdout.trim();
}

function buildPrivacyUrl(opts) {
  return `https://chrome.google.com/webstore/devconsole/${opts.publisher}/${opts.item}/edit/privacy`;
}

function browserAutomationCode(opts, editUrl) {
  const payload = {
    autoPublish: opts.autoPublish,
    editUrl,
    dryRun: !opts.save && !opts.submit,
    privacyUrl: opts.privacyUrl ?? null,
    save: opts.save,
    submit: opts.submit,
  };

  return `
const input = ${JSON.stringify(payload)};

function compactText(value) {
  return String(value || "").replace(/\\s+/g, " ").trim();
}

async function visibleCount(locator) {
  try {
    const count = await locator.count();
    for (let index = 0; index < count; index += 1) {
      const current = locator.nth(index);
      if (await current.isVisible().catch(() => false)) return index + 1;
    }
    return 0;
  } catch {
    return 0;
  }
}

async function findPrivacyField(page) {
  const handle = await page.evaluateHandle(() => {
    const fieldValue = (element) => {
      if ('value' in element) return element.value || "";
      return element.innerText || element.textContent || "";
    };

    const isEditable = (element) => {
      const tagName = element.tagName.toLowerCase();
      const type = String(element.getAttribute('type') || 'text').toLowerCase();
      const acceptedType = ['text', 'url', 'search', 'email', ''].includes(type);
      return (
        (tagName === 'input' && acceptedType)
        || tagName === 'textarea'
        || element.isContentEditable
        || element.getAttribute('role') === 'textbox'
      );
    };

    const textFor = (element) => {
      const pieces = [
        element.getAttribute('aria-label') || "",
        element.getAttribute('placeholder') || "",
        element.getAttribute('name') || "",
        element.getAttribute('id') || "",
      ];

      if (element.id) {
        const label = document.querySelector('label[for="' + CSS.escape(element.id) + '"]');
        if (label) pieces.push(label.innerText || label.textContent || "");
      }

      let node = element;
      for (let depth = 0; node && depth < 6; depth += 1) {
        pieces.push(node.innerText || node.textContent || "");
        node = node.parentElement;
      }
      return pieces.join(" ");
    };

    const fields = Array.from(document.querySelectorAll('input, textarea, [contenteditable="true"], [role="textbox"]'))
      .filter((element) => isEditable(element));

    const candidates = fields.map((element) => ({
      element,
      text: textFor(element),
      value: fieldValue(element),
    }));

    return candidates.find((candidate) => /Privacy policy URL|隐私权政策网址/i.test(candidate.text))?.element
      || candidates.find((candidate) => /privacy|隐私/i.test(candidate.text) && /^https?:\\/\\//i.test(candidate.value))?.element
      || candidates.find((candidate) => /^https?:\\/\\//i.test(candidate.value))?.element
      || null;
  });

  const element = handle.asElement();
  if (!element) {
    throw new Error("Could not find the privacy policy URL field on the CWS privacy page");
  }
  return element;
}

async function clickFirstButton(page, matcher, label) {
  const byRole = page.getByRole('button', { name: matcher }).first();
  if ((await visibleCount(byRole)) > 0) {
    await byRole.click({ timeout: 15000 });
    return;
  }

  const textButton = page.locator('button').filter({ hasText: matcher }).first();
  if ((await visibleCount(textButton)) > 0) {
    await textButton.click({ timeout: 15000 });
    return;
  }

  throw new Error("Could not find button: " + label);
}

async function setAutoPublish(page, desired) {
  const checkbox = page
    .getByLabel(/auto.?publish|automatically publish|通过审核后自动发布|自动发布/i)
    .first();
  if ((await visibleCount(checkbox)) === 0) return "not-present";

  const checked = await checkbox.isChecked().catch(() => null);
  if (checked === null) return "unknown";
  if (checked !== desired) {
    if (desired) await checkbox.check({ timeout: 10000 });
    else await checkbox.uncheck({ timeout: 10000 });
  }
  return desired ? "checked" : "unchecked";
}

const pages = context.pages();
let page = state.page || pages.find((candidate) => candidate.url().includes('/webstore/devconsole/')) || pages[0];
if (!page) page = await context.newPage();
state.page = page;

await page.goto(input.editUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});

if (/accounts\\.google\\.com/.test(page.url())) {
  throw new Error("Chrome Web Store redirected to Google login. Log in with the source Chrome profile, then rerun.");
}

const result = {
  dryRun: input.dryRun,
  editUrl: input.editUrl,
  finalUrl: page.url(),
  privacyUrlBefore: null,
  privacyUrlAfter: null,
  saved: false,
  submitted: false,
  autoPublish: "not-requested",
  status: null,
};

const privacyField = await findPrivacyField(page);
result.privacyUrlBefore = await privacyField.evaluate((element) => element.value || element.textContent || "");

if (input.privacyUrl) {
  await privacyField.fill(input.privacyUrl);
  await page.keyboard.press('Tab').catch(() => {});
  result.privacyUrlAfter = await privacyField.evaluate((element) => element.value || element.textContent || "");
} else {
  result.privacyUrlAfter = result.privacyUrlBefore;
}

if (input.save) {
  await clickFirstButton(page, /保存草稿|Save draft/i, "Save draft");
  result.saved = true;
  await page.waitForTimeout(1200);
  await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {});
}

if (input.submit) {
  await clickFirstButton(page, /提请审核|提交审核|Submit for review/i, "Submit for review");
  await page.waitForTimeout(1200);
  result.autoPublish = await setAutoPublish(page, Boolean(input.autoPublish));
  await clickFirstButton(page, /提交审核|Submit for review|Submit/i, "Confirm submit");
  result.submitted = true;
  await page.waitForTimeout(2000);
  await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
}

const bodyText = await page.locator('body').innerText({ timeout: 10000 }).catch(() => "");
const statusMatch = bodyText.match(/(?:状态|Status)[:：]?\\s*([^\\n]+)/i);
result.status = statusMatch ? compactText(statusMatch[1]).slice(0, 160) : null;
result.finalUrl = page.url();

console.log(JSON.stringify(result, null, 2));
`;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    console.log(usage());
    return;
  }
  validateOpts(opts);

  const editUrl = buildPrivacyUrl(opts);
  let startedChrome = false;
  let sessionId = null;

  try {
    const existing = await currentCdp(opts.port);
    if (existing && !opts.reuseCdp) {
      throw new Error(`Port ${opts.port} already has a CDP browser. Rerun with --reuse-cdp or choose another --port.`);
    }

    if (!existing) {
      copyChromeProfile(opts);
      openChrome(opts, editUrl);
      startedChrome = true;
    }

    const version = existing ?? (await waitForCdp(opts.port));
    if (!version.webSocketDebuggerUrl) {
      throw new Error(`CDP endpoint on port ${opts.port} did not expose webSocketDebuggerUrl`);
    }

    sessionId = createPlaywriterSession(version.webSocketDebuggerUrl);
    console.log(`Playwriter session: ${sessionId}`);

    const output = playwriterEval(sessionId, browserAutomationCode(opts, editUrl));
    console.log(output);
  } finally {
    if (sessionId) deletePlaywriterSession(sessionId);
    if (startedChrome && !opts.keepBrowser) {
      killTempChrome(opts.tmpProfile);
    }
  }
}

main().catch((error) => {
  console.error(`ERROR: ${error.message}`);
  process.exitCode = 1;
});
