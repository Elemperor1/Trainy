/**
 * Removes complete elements by tag name without treating HTML as a regular
 * language. The exported Next.js document is trusted build output, but this
 * scanner still rejects an unterminated element instead of emitting executable
 * markup into the static Worker response.
 */
export function stripElementsByTagName(markup, tagName) {
  const lowerMarkup = markup.toLowerCase();
  const opening = `<${tagName.toLowerCase()}`;
  const closing = `</${tagName.toLowerCase()}>`;
  let cursor = 0;
  let sanitized = "";

  while (cursor < markup.length) {
    const start = lowerMarkup.indexOf(opening, cursor);
    if (start === -1) return sanitized + markup.slice(cursor);

    const boundary = lowerMarkup[start + opening.length];
    const opensElement =
      boundary === undefined ||
      boundary === ">" ||
      boundary === "/" ||
      boundary === " " ||
      boundary === "\t" ||
      boundary === "\n" ||
      boundary === "\r" ||
      boundary === "\f";
    if (!opensElement) {
      sanitized += markup.slice(cursor, start + opening.length);
      cursor = start + opening.length;
      continue;
    }

    const end = lowerMarkup.indexOf(closing, start + opening.length);
    if (end === -1) {
      throw new Error(`Unterminated <${tagName}> element in exported HTML`);
    }

    sanitized += markup.slice(cursor, start);
    cursor = end + closing.length;
  }

  return sanitized;
}
