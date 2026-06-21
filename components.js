/* ============================================================================
   Trainy UI — Web component library
   Single source of truth for rendered markup. app.js routes ALL dynamic UI
   through these factories; do not construct component HTML inline in app.js
   (enforced by scripts/check-design-system-bypass.sh and the
   review-design-system review skill).
   ============================================================================ */
(function (global) {
  "use strict";

  const TONES = new Set(["good", "watch", "late"]);

  const ESCAPE_MAP = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  };

  /** Escape untrusted strings before injecting into HTML strings. */
  function escapeHtml(value) {
    return String(value == null ? "" : value).replace(/[&<>"']/g, (ch) => ESCAPE_MAP[ch]);
  }

  /** Map a trip/alert tone to a valid CSS status class. */
  function toneClass(tone) {
    return TONES.has(tone) ? tone : "good";
  }

  /** Small status chip used on cards, alerts, and the network board. */
  function miniPill(label, tone) {
    return `<span class="mini-pill ${toneClass(tone)}">${escapeHtml(label)}</span>`;
  }

  /** Large status pill used in the live panel header. */
  function statusPill(label, tone) {
    return `<span class="status-pill ${toneClass(tone)}">${escapeHtml(label)}</span>`;
  }

  /** Tracked-trip list card. */
  function tripCard(trip, options) {
    const opts = options || {};
    const active = opts.active ? " active" : "";
    const metaRight = opts.pinned ? "Pinned" : trip.platform;
    return `
        <button class="trip-card${active}" type="button" data-trip-id="${escapeHtml(trip.id)}">
          <span class="trip-main">
            <span>
              <strong>${escapeHtml(trip.train)}</strong>
              <span class="trip-route">${escapeHtml(trip.from)} to ${escapeHtml(trip.to)}</span>
            </span>
            ${miniPill(trip.status, trip.statusTone)}
          </span>
          <span class="trip-meta">
            <span>${escapeHtml(trip.depart)} - ${escapeHtml(trip.arrive)}</span>
            <span>${escapeHtml(metaRight)}</span>
          </span>
        </button>
      `;
  }

  /** Empty-state placeholder for the trip list. */
  function emptyState(message) {
    return `<div class="empty-state">${escapeHtml(message)}</div>`;
  }

  /** Station timeline row. */
  function timelineRow(stop) {
    return `
        <li class="timeline-row ${toneClass(stop.state === "done" ? "good" : stop.state === "current" ? "late" : "watch")} ${escapeHtml(stop.state)}">
          <span>
            <strong>${escapeHtml(stop.name)}</strong>
            <small>${escapeHtml(stop.note)}</small>
          </span>
          <span>
            <strong>${escapeHtml(stop.time)}</strong>
            <small>${escapeHtml(stop.platform)}</small>
          </span>
        </li>
      `;
  }

  /** Alert list item. */
  function alertItem(alert) {
    return `
        <article class="alert-item">
          <span>
            <strong>${escapeHtml(alert.title)}</strong>
            <small>${escapeHtml(alert.detail)}</small>
          </span>
          ${miniPill(alert.tone, alert.tone)}
        </article>
      `;
  }

  /** Network board row. */
  function networkRow(trip) {
    return `
        <article class="network-row">
          <span>
            <strong>${escapeHtml(trip.service)}</strong>
            <small>${escapeHtml(trip.pulse)}</small>
          </span>
          ${miniPill(trip.status, trip.statusTone)}
        </article>
      `;
  }

  /** Platform-map car cell. */
  function car(number, options) {
    const best = options && options.best ? " best" : "";
    return `<span class="car${best}">${escapeHtml(number)}</span>`;
  }

  global.TrainyUI = {
    escapeHtml,
    toneClass,
    miniPill,
    statusPill,
    tripCard,
    emptyState,
    timelineRow,
    alertItem,
    networkRow,
    car,
  };
})(window);
