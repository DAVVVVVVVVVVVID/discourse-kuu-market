// 截开发环境页面的电脑版和手机版各一张，可以先点击、填写几步（比如打开表单）。
// 在容器里运行（开发服务器要先启动）：
//   docker cp script/screenshot.mjs discourse_dev:/tmp/screenshot.mjs
//   docker exec -u discourse -e HOME=/home/discourse discourse_dev \
//     node /tmp/screenshot.mjs /c/market/7 /tmp/shot 用户名 密码 "click:#create-topic" "wait:.kuu-market-form"
//   docker cp discourse_dev:/tmp/shot-desktop.png . （手机版是 shot-mobile.png）
// 步骤：click:选择器、wait:选择器、fill:选择器::内容、upload:选择器::文件路径。用户名为 - 时不登录。
// 加 -e FULL_PAGE=1 截整页，-e ONLY=desktop 或 -e ONLY=mobile 只截一种（比如只能点一次的操作）。
// 只用于本地开发库里的测试账号。
import { chromium, devices } from "/src/node_modules/playwright/index.mjs";

const [path = "/", prefix = "/tmp/shot", username, password, ...steps] =
  process.argv.slice(2);
const base = "http://localhost:3000";
const xhr = { "X-Requested-With": "XMLHttpRequest" };

async function logIn(context) {
  const { csrf } = await (
    await context.request.get(`${base}/session/csrf`, { headers: xhr })
  ).json();
  const response = await context.request.post(`${base}/session.json`, {
    headers: { ...xhr, "X-CSRF-Token": csrf },
    form: { login: username, password },
  });
  const body = await response.json();
  if (!response.ok() || body.error || body.errors) {
    throw new Error(`login failed for ${username}: ${JSON.stringify(body)}`);
  }
}

async function runStep(page, step) {
  const [action, ...rest] = step.split(":");
  const argument = rest.join(":");
  const [selector, value] = argument.split("::");

  switch (action) {
    case "click":
      await page.click(argument);
      break;
    case "wait":
      await page.waitForSelector(argument, { timeout: 60000 });
      break;
    case "fill":
      await page.fill(selector, value);
      break;
    case "upload":
      await page.setInputFiles(selector, value);
      break;
    default:
      throw new Error(`unknown step ${step}`);
  }
  await page.waitForTimeout(500);
}

async function capture(context, file) {
  if (username && username !== "-") {
    await logIn(context);
  }

  const page = await context.newPage();
  // MessageBus 一直保持长连接，等不到 networkidle
  await page.goto(base + path, { waitUntil: "load", timeout: 120000 });
  await page.waitForSelector("#main-outlet", { timeout: 120000 });
  await page.waitForTimeout(1500);
  try {
    for (const step of steps) {
      await runStep(page, step);
    }
    await page.waitForTimeout(800);
  } finally {
    // 某一步失败时也截下当时的画面，方便排查
    await page.screenshot({ path: file, fullPage: !!process.env.FULL_PAGE });
  }
}

const only = process.env.ONLY;
const browser = await chromium.launch({ channel: "chromium" });
try {
  if (only !== "mobile") {
    await capture(
      await browser.newContext({ viewport: { width: 1366, height: 900 } }),
      `${prefix}-desktop.png`
    );
  }
  // 手机 User-Agent，Discourse 才会给手机版布局
  if (only !== "desktop") {
    await capture(
      await browser.newContext({ ...devices["iPhone 13"] }),
      `${prefix}-mobile.png`
    );
  }
} finally {
  await browser.close();
}
