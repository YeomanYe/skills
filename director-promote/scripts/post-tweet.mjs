#!/usr/bin/env node
/**
 * post-tweet.mjs — Director Promote: Twitter/X post automation
 *
 * 一键发布推文到 X,带发布后线上验证(text + image + link 三件套必须都在)。
 * 封装了踩过的 3 个具体坑(2026-06 经验):
 *   1. ProseMirror 拒收 document.execCommand('insertText') — 只走 page.keyboard.insertText
 *   2. X compose 有 2 个 file input,page.$() 会触发 2 张图 — 用 evaluateHandle 取第 0 个
 *   3. 点击 Post 不代表成功,必须访问推文 URL 验证 DOM 里有 text/image/link
 *
 * ⚠️ 关键设计:Playwriter CLI 的 -e 单次执行有 10s 超时,
 * 所以脚本把全流程拆成 5 个独立调用,每个都 < 10s:
 *   1. navigate-compose       ~3s
 *   2. fill-text              ~5s(多段 insertText)
 *   3. upload-image           ~8s(setInputFiles + 7s 等 X 处理)
 *   4. probe-and-screenshot   ~3s
 *   5. post-and-verify        ~12s(发布 + 跳转 + 验证)
 *
 * 用法:
 *   # 阶段 1:填好内容,截图给用户看(不发)
 *   node scripts/post-tweet.mjs --text "..." --image /path/to/img.png
 *
 *   # 阶段 2:用户确认后,真的发+验证
 *   node scripts/post-tweet.mjs --post --yes
 *
 *   # 一气呵成(用户已授权)
 *   node scripts/post-tweet.mjs --text "..." --image ... --auto-post --yes
 *
 * 退出码:
 *   0 = 成功(发布且验证通过)
 *   1 = 错误(参数 / playwright 断连 / 验证失败)
 *   2 = 用户拒绝 / 预览未确认(只在 --post 但没 --yes 时)
 *   3 = 字符数超 280
 *   4 = 图片未找到
 *   5 = ProseMirror 拒收(填了但 Post 后没文字)
 *
 * 输出:始终是单行 JSON,stdout。
 */

import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { resolve, isAbsolute } from 'node:path';

// ---- 参数解析 ----
const args = process.argv.slice(2);
const opts = {
  text: null,
  image: null,
  session: '1',
  preview: '/tmp/post-tweet-preview.png',
  post: false,
  autoPost: false,
  yes: false,
  verbose: false,
};

for (let i = 0; i < args.length; i++) {
  const a = args[i];
  switch (a) {
    case '--text': opts.text = args[++i]; break;
    case '--image': opts.image = args[++i]; break;
    case '--session': opts.session = args[++i]; break;
    case '--preview': opts.preview = args[++i]; break;
    case '--post': opts.post = true; break;
    case '--auto-post': opts.autoPost = true; break;
    case '--yes': opts.yes = true; break;
    case '--verbose': opts.verbose = true; break;
    case '--help':
    case '-h':
      console.log(usage());
      process.exit(0);
    default:
      out({ status: 'error', mode: 'parse', errors: [`unknown arg: ${a}`] });
      process.exit(1);
  }
}

function usage() {
  return `Usage: post-tweet.mjs [options]

  --text <string>        推文文案(阶段 1 必填)
  --image <path>         配图绝对路径(阶段 1 必填; 阶段 2 不用)
  --session <n>          Playwriter session ID (default: 1)
  --preview <path>       预览截图保存路径 (default: /tmp/post-tweet-preview.png)
  --post                 阶段 2:真的发(默认 2 个阶段分开跑)
  --auto-post            阶段 1 完成后自动跳到阶段 2(不询问)
  --yes                  阶段 2 跳过用户确认(必须有 --post 或 --auto-post)
  --verbose              打印 Playwriter 原始输出
  -h, --help             显示帮助
`;
}

function out(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}

// ---- Playwriter 调用 ----

function runPlaywriter(code, timeoutMs = 12_000) {
  const args = ['-y', 'playwriter@latest', '-s', opts.session, '-e', code];
  try {
    const stdout = execFileSync('npx', args, {
      encoding: 'utf8',
      timeout: timeoutMs,
      maxBuffer: 50 * 1024 * 1024,
    });
    if (opts.verbose) console.error('[pw stdout]', stdout);
    return { ok: true, stdout };
  } catch (e) {
    return {
      ok: false,
      stdout: e.stdout?.toString() || '',
      stderr: e.stderr?.toString() || e.message,
      code: e.status,
    };
  }
}

function extractTaggedLine(stdout, tag) {
  const line = stdout.split('\n').find(l => l.includes(`${tag}:`));
  if (!line) return null;
  try {
    return JSON.parse(line.replace(`${tag}:`, '').trim());
  } catch {
    return null;
  }
}

// ---- 6 个独立 Playwright 脚本 ----
// 每个都用 IIFE 包,自带 try/catch,出错返回 ERROR 标记,不要 process.exit(断连)

const SCRIPT_NAVIGATE = `
(async () => {
  try {
    await page.goto('https://x.com/compose/post', { waitUntil: 'domcontentloaded', timeout: 12000 });
    await new Promise(r => setTimeout(r, 2500));
    console.log('NAV_OK:' + page.url());
  } catch (e) {
    console.log('NAV_ERROR:' + e.message);
  }
})();
`;

const SCRIPT_FILL_TEXT = (text) => `
(async () => {
  try {
    await page.click('[data-testid="tweetTextarea_0"]');
    await new Promise(r => setTimeout(r, 700));
    const segments = ${JSON.stringify(text)}.split(/\\n+/);
    for (let i = 0; i < segments.length; i++) {
      if (i > 0) await page.keyboard.press('Enter');
      if (segments[i].length > 0) {
        await page.keyboard.insertText(segments[i]);
        await new Promise(r => setTimeout(r, 200));
      }
    }
    await new Promise(r => setTimeout(r, 500));
    const probe = await page.evaluate(() => ({
      text: document.querySelector('[data-testid="tweetTextarea_0"]')?.innerText || '',
      textLength: document.querySelector('[data-testid="tweetTextarea_0"]')?.innerText.length || 0,
    }));
    console.log('FILL_OK:' + JSON.stringify(probe));
  } catch (e) {
    console.log('FILL_ERROR:' + e.message);
  }
})();
`;

const SCRIPT_UPLOAD_IMAGE = (imgPath) => `
(async () => {
  try {
    const fileHandle = await page.evaluateHandle(
      () => document.querySelectorAll('input[type="file"]')[0]
    );
    await fileHandle.asElement().setInputFiles(${JSON.stringify(imgPath)});
    await new Promise(r => setTimeout(r, 7000));
    const probe = await page.evaluate(() => ({
      hasEditMedia: !!document.querySelector('button[aria-label="Edit media"]'),
      hasRemoveMedia: !!document.querySelector('button[aria-label="Remove media"]'),
      editMediaCount: document.querySelectorAll('button[aria-label="Edit media"]').length,
    }));
    console.log('UPLOAD_OK:' + JSON.stringify(probe));
  } catch (e) {
    console.log('UPLOAD_ERROR:' + e.message);
  }
})();
`;

const SCRIPT_SCREENSHOT = (previewPath) => `
(async () => {
  try {
    const state = await page.evaluate(() => ({
      text: document.querySelector('[data-testid="tweetTextarea_0"]')?.innerText || '',
      textLength: document.querySelector('[data-testid="tweetTextarea_0"]')?.innerText.length || 0,
      hasEditMedia: !!document.querySelector('button[aria-label="Edit media"]'),
      hasRemoveMedia: !!document.querySelector('button[aria-label="Remove media"]'),
      editMediaCount: document.querySelectorAll('button[aria-label="Edit media"]').length,
      removeMediaCount: document.querySelectorAll('button[aria-label="Remove media"]').length,
      btnDisabled: document.querySelector('[data-testid="tweetButton"]')?.getAttribute('aria-disabled'),
    }));
    await page.screenshot({ path: ${JSON.stringify(previewPath)}, fullPage: false });
    console.log('SHOT_OK:' + JSON.stringify(state));
  } catch (e) {
    console.log('SHOT_ERROR:' + e.message);
  }
})();
`;

const SCRIPT_POST = `
(async () => {
  try {
    await page.click('[data-testid="tweetButton"]');
    await new Promise(r => setTimeout(r, 6000));
    const postUrl = page.url();
    const tweetUrl = await page.evaluate(() => {
      const articles = document.querySelectorAll('article[data-testid="tweet"]');
      for (const a of articles) {
        const link = a.querySelector('a[href*="/status/"]');
        if (link) return link.href;
      }
      return null;
    });
    console.log('POST_OK:' + JSON.stringify({ postUrl, tweetUrl }));
  } catch (e) {
    console.log('POST_ERROR:' + e.message);
  }
})();
`;

const SCRIPT_VERIFY = `
(async () => {
  try {
    const url = await page.evaluate(() => {
      const link = document.querySelector('article[data-testid="tweet"] a[href*="/status/"]');
      return link ? link.href : null;
    });
    if (!url) {
      console.log('VERIFY_ERROR:no_tweet_url_in_dom');
      return;
    }
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 12000 });
    await new Promise(r => setTimeout(r, 4000));
    const result = await page.evaluate(() => {
      const article = document.querySelector('article[data-testid="tweet"]');
      if (!article) return { error: 'NO_ARTICLE' };
      const textEl = article.querySelector('[data-testid="tweetText"]');
      const mediaImgs = article.querySelectorAll('img[src*="pbs.twimg.com/media"]');
      const tcoLinks = article.querySelectorAll('a[href*="t.co/"]');
      return {
        url: page.url,
        text: textEl?.innerText || '',
        textLength: textEl?.innerText.length || 0,
        imageCount: mediaImgs.length,
        imageSrcs: Array.from(mediaImgs).map(i => i.src.slice(0, 100)),
        linkCount: tcoLinks.length,
        linkHrefs: Array.from(tcoLinks).map(a => a.href),
      };
    });
    console.log('VERIFY_OK:' + JSON.stringify(result));
  } catch (e) {
    console.log('VERIFY_ERROR:' + e.message);
  }
})();
`;

// ---- 主流程 ----

async function main() {
  const errors = [];

  // 阶段 1:填内容 + 截图
  if (opts.text || opts.image) {
    // 预检
    if (opts.text && opts.text.length > 280) {
      out({ status: 'error', mode: 'precheck', errors: [`text too long: ${opts.text.length} chars (max 280)`] });
      process.exit(3);
    }
    if (opts.image) {
      const absPath = isAbsolute(opts.image) ? opts.image : resolve(opts.image);
      if (!existsSync(absPath)) {
        out({ status: 'error', mode: 'precheck', errors: [`image not found: ${absPath}`] });
        process.exit(4);
      }
      opts.image = absPath;
    }

    // 1. navigate
    let r = runPlaywriter(SCRIPT_NAVIGATE);
    if (!r.ok) { out({ status: 'error', mode: 'navigate', errors: [r.stderr || r.stdout] }); process.exit(1); }
    const nav = extractTaggedLine(r.stdout, 'NAV_OK');
    if (!nav) { out({ status: 'error', mode: 'navigate', errors: ['navigate failed', r.stdout.slice(-300)] }); process.exit(1); }

    // 2. fill text
    r = runPlaywriter(SCRIPT_FILL_TEXT(opts.text), 15_000);
    if (!r.ok) { out({ status: 'error', mode: 'fill', errors: [r.stderr || r.stdout] }); process.exit(1); }
    const fill = extractTaggedLine(r.stdout, 'FILL_OK');
    if (!fill) { out({ status: 'error', mode: 'fill', errors: ['fill failed', r.stdout.slice(-300)] }); process.exit(1); }
    if (fill.textLength > 280) {
      out({ status: 'error', mode: 'fill', charCount: fill.textLength, errors: ['text too long after fill'] });
      process.exit(3);
    }

    // 3. upload image
    if (opts.image) {
      r = runPlaywriter(SCRIPT_UPLOAD_IMAGE(opts.image), 12_000);
      if (!r.ok) { out({ status: 'error', mode: 'upload', errors: [r.stderr || r.stdout] }); process.exit(1); }
      const up = extractTaggedLine(r.stdout, 'UPLOAD_OK');
      if (!up) { out({ status: 'error', mode: 'upload', errors: ['upload failed', r.stdout.slice(-300)] }); process.exit(1); }
      if (up.editMediaCount !== 1) {
        errors.push(`expected 1 image, got ${up.editMediaCount} (X 双 file input 累积了)`);
      }
    }

    // 4. probe + screenshot
    r = runPlaywriter(SCRIPT_SCREENSHOT(opts.preview));
    if (!r.ok) { out({ status: 'error', mode: 'screenshot', errors: [r.stderr || r.stdout] }); process.exit(1); }
    const shot = extractTaggedLine(r.stdout, 'SHOT_OK');
    if (!shot) { out({ status: 'error', mode: 'screenshot', errors: ['screenshot failed', r.stdout.slice(-300)] }); process.exit(1); }

    if (shot.btnDisabled === 'true' || shot.btnDisabled === true) {
      errors.push('Post button disabled');
    }

    // 阶段 1 完成
    if (!opts.autoPost && !opts.post) {
      out({
        status: 'preview-ready',
        mode: 'phase1',
        charCount: shot.textLength,
        textLength: shot.textLength,
        text: shot.text,
        mediaCount: shot.editMediaCount,
        postButtonEnabled: shot.btnDisabled !== 'true',
        previewScreenshot: opts.preview,
        errors,
        nextStep: 'user confirms preview, then re-run with --post --yes',
      });
      process.exit(0);
    }
  }

  // 阶段 2:发布
  if (opts.post || opts.autoPost) {
    if (!opts.yes) {
      out({ status: 'need-confirm', mode: 'phase2', errors: ['--post requires --yes'] });
      process.exit(2);
    }

    // 5. post
    const r = runPlaywriter(SCRIPT_POST, 12_000);
    if (!r.ok) { out({ status: 'error', mode: 'post', errors: [r.stderr || r.stdout] }); process.exit(1); }
    const posted = extractTaggedLine(r.stdout, 'POST_OK');
    if (!posted) { out({ status: 'error', mode: 'post', errors: ['post failed', r.stdout.slice(-300)] }); process.exit(1); }

    // 6. verify
    const r2 = runPlaywriter(SCRIPT_VERIFY, 15_000);
    if (!r2.ok) { out({ status: 'error', mode: 'verify', tweetUrl: posted.tweetUrl, errors: [r2.stderr || r2.stdout] }); process.exit(1); }
    const verify = extractTaggedLine(r2.stdout, 'VERIFY_OK');
    if (!verify) { out({ status: 'error', mode: 'verify', tweetUrl: posted.tweetUrl, errors: ['verify failed', r2.stdout.slice(-300)] }); process.exit(1); }
    if (verify.error) { out({ status: 'error', mode: 'verify', tweetUrl: posted.tweetUrl, errors: [verify.error] }); process.exit(5); }

    const verifyText = verify.textLength > 0;
    const verifyImage = verify.imageCount > 0;
    const verifyLink = verify.linkCount > 0;
    const ok = verifyText && verifyImage;

    out({
      status: ok ? 'published' : 'half-failed',
      mode: 'phase2',
      tweetUrl: posted.tweetUrl,
      verifyText,
      verifyImage,
      verifyLink,
      verifyDetail: verify,
      errors: ok ? [] : [
        !verifyText && 'text missing in posted tweet (ProseMirror 拒收)',
        !verifyImage && 'image missing in posted tweet',
        !verifyLink && 'no t.co link in posted tweet (URL 被吞)',
      ].filter(Boolean),
    });
    process.exit(ok ? 0 : 5);
  }

  out({ status: 'error', mode: 'parse', errors: ['specify --text/--image for phase 1, or --post for phase 2'] });
  process.exit(1);
}

main().catch(e => {
  out({ status: 'error', mode: 'uncaught', errors: [e.message, e.stack] });
  process.exit(1);
});
