import { mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { extname, join } from "node:path";
import { stripElementsByTagName } from "./html.mjs";

/** Returns every file beneath a directory in deterministic traversal order. */
async function filesBelow(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await filesBelow(path));
    else files.push(path);
  }
  return files;
}

/** Encodes a binary asset as a MIME-qualified data URL. */
function dataUrl(path, bytes) {
  const mime = extname(path) === ".png" ? "image/png" : "application/octet-stream";
  return `data:${mime};base64,${bytes.toString("base64")}`;
}

const [rawHtml, icon, hero, hosting] = await Promise.all([
  readFile("out/index.html", "utf8"),
  readFile("public/trainy-icon.png"),
  readFile("public/hero-train.png"),
  readFile(".openai/hosting.json", "utf8"),
]);

const cssFiles = (await filesBelow("out/_next/static")).filter((path) => path.endsWith(".css"));
let css = (await Promise.all(cssFiles.map((path) => readFile(path, "utf8")))).join("\n");
const iconUrl = dataUrl("trainy-icon.png", icon);
const heroUrl = dataUrl("hero-train.png", hero);
css = css.replaceAll("/hero-train.png", heroUrl).replaceAll("/trainy-icon.png", iconUrl);

const html = stripElementsByTagName(rawHtml, "script")
  .replace(/<link[^>]+rel="stylesheet"[^>]*>/g, "")
  .replace(/<link[^>]+rel="preload"[^>]*>/g, "")
  .replaceAll('src="/trainy-icon.png"', `src="${iconUrl}"`)
  .replace("</head>", `<style>${css}</style></head>`);

const worker = `"use strict";

const INDEX_HTML = ${JSON.stringify(html)};
const ICON_BASE64 = ${JSON.stringify(icon.toString("base64"))};
const SECURITY_HEADERS = {
  "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; img-src data:; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
  "referrer-policy": "strict-origin-when-cross-origin",
  "x-content-type-options": "nosniff",
};

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method not allowed", { status: 405, headers: { allow: "GET, HEAD", ...SECURITY_HEADERS } });
    }
    if (url.pathname === "/trainy-icon.png") {
      const icon = Uint8Array.from(atob(ICON_BASE64), (character) => character.charCodeAt(0));
      return new Response(request.method === "HEAD" ? null : icon, {
        headers: {
          "content-type": "image/png",
          "cache-control": "public, max-age=31536000, immutable",
          ...SECURITY_HEADERS,
        },
      });
    }
    if (url.pathname !== "/" && url.pathname !== "/index.html") {
      return new Response("Not found", { status: 404, headers: SECURITY_HEADERS });
    }
    return new Response(request.method === "HEAD" ? null : INDEX_HTML, {
      headers: {
        "content-type": "text/html; charset=utf-8",
        "cache-control": "public, max-age=300",
        ...SECURITY_HEADERS,
      },
    });
  },
};
`;

await rm("dist", { recursive: true, force: true });
await mkdir("dist/server", { recursive: true });
await mkdir("dist/client", { recursive: true });
await mkdir("dist/.openai", { recursive: true });
await Promise.all([
  writeFile("dist/server/index.js", worker),
  writeFile("dist/client/index.html", html),
  writeFile("dist/.openai/hosting.json", hosting),
]);
