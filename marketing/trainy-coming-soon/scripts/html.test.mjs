import assert from "node:assert/strict";
import test from "node:test";
import { stripElementsByTagName } from "./html.mjs";

test("removes lowercase and uppercase script elements", () => {
  const markup = "<p>before</p><script>one()</script><SCRIPT type='module'>two()</SCRIPT><p>after</p>";
  assert.equal(stripElementsByTagName(markup, "script"), "<p>before</p><p>after</p>");
});

test("preserves similarly named custom elements", () => {
  const markup = "<scripture-note>safe</scripture-note>";
  assert.equal(stripElementsByTagName(markup, "script"), markup);
});

test("rejects an unterminated executable element", () => {
  assert.throws(
    () => stripElementsByTagName("<script>unfinished", "script"),
    /Unterminated <script> element/,
  );
});
