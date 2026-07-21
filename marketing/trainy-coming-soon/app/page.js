const Arrow = ({ external = false }) => (
  <svg viewBox="0 0 24 24" aria-hidden="true">
    {external ? (
      <>
        <path d="M14 5h5v5" />
        <path d="m19 5-9 9" />
        <path d="M17 13v5a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1h5" />
      </>
    ) : (
      <>
        <path d="M5 12h14" />
        <path d="m14 7 5 5-5 5" />
      </>
    )}
  </svg>
);

const FeatureIcon = ({ type }) => {
  const paths = {
    train: <><path d="M7 16h10l2-3V6c0-3-3-4-7-4S5 3 5 6v7l2 3Z"/><path d="M8 7h8M9 12h.01M15 12h.01M8 19l2-3M16 19l-2-3"/></>,
    clock: <><circle cx="12" cy="12" r="8"/><path d="M12 7v5l3 2"/></>,
    sign: <><path d="M12 3v18M5 6h11l3 3-3 3H5V6Zm2 8h10l-3 3H7v-3Z"/></>,
    database: <><ellipse cx="12" cy="5" rx="7" ry="3"/><path d="M5 5v6c0 1.7 3.1 3 7 3s7-1.3 7-3V5M5 11v6c0 1.7 3.1 3 7 3s7-1.3 7-3v-6"/></>,
    building: <><path d="M4 19h16M6 17V9l6-4 6 4v8M9 11v4M12 11v4M15 11v4"/></>,
    signal: <><circle cx="12" cy="12" r="2"/><path d="M8.5 8.5a5 5 0 0 0 0 7M15.5 8.5a5 5 0 0 1 0 7M5.5 5.5a9 9 0 0 0 0 13M18.5 5.5a9 9 0 0 1 0 13"/></>,
  };
  return <svg viewBox="0 0 24 24" aria-hidden="true">{paths[type]}</svg>;
};

const journey = [
  ["01", "train", "Find the right service", "Search, compare, and choose the train that fits your journey."],
  ["02", "clock", "Understand the moment", "See schedules and provider status with labels you can trust."],
  ["03", "sign", "Travel with confidence", "Keep the next step clear, from departure through arrival."],
];

const sources = [
  ["starter", "database", "Starter catalog", "Curated service data that helps you get started.", "Foundational"],
  ["scheduled", "building", "Scheduled official data", "Timetables and station information from official sources.", "Official"],
  ["realtime", "signal", "Realtime provider status", "Live updates only when a provider supports them.", "Live"],
];

export default function Home() {
  return (
    <main>
      <header className="site-header">
        <a className="brand" href="#top" aria-label="Trainy home">
          <img src="/trainy-icon.png" alt="" />
          <span>Trainy</span>
        </a>
        <nav aria-label="Primary navigation">
          <a href="#product">Product</a>
          <a href="#coverage">Coverage</a>
          <a href="#principles">Principles</a>
          <a href="https://github.com/Elemperor1/Trainy" target="_blank" rel="noreferrer">GitHub</a>
        </nav>
      </header>

      <section className="hero" id="top" aria-labelledby="hero-title">
        <div className="hero-image" aria-hidden="true" />
        <div className="hero-content page-shell">
          <h1 id="hero-title">Every train journey,<br />made clearer.</h1>
          <p>Trainy helps you find the right service, understand what&apos;s happening, and move from A to B with confidence.</p>
          <div className="hero-actions">
            <a className="button button-light" href="#product">See what&apos;s coming <Arrow /></a>
            <a className="text-link" href="https://github.com/Elemperor1/Trainy" target="_blank" rel="noreferrer">View on GitHub <Arrow external /></a>
          </div>
          <div className="coming-soon"><span aria-hidden="true" />Coming soon to iPhone</div>
        </div>
      </section>

      <section className="journey page-shell" id="product" aria-labelledby="journey-title">
        <div className="rail" aria-hidden="true" />
        <div className="journey-content">
          <h2 id="journey-title">Your guide through the station.</h2>
          <ol>
            {journey.map(([number, icon, title, body]) => (
              <li key={number}>
                <span className="number">{number}</span>
                <span className="icon-circle"><FeatureIcon type={icon} /></span>
                <span className="feature-copy"><strong>{title}</strong><span>{body}</span></span>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="truth" id="principles" aria-labelledby="truth-title">
        <div className="page-shell truth-inner">
          <div className="section-heading">
            <h2 id="truth-title">Know what the data knows.</h2>
            <p>Trainy labels where information comes from—so you always know how current and complete it is.</p>
          </div>
          <div className="source-list">
            {sources.map(([tone, icon, title, body, status]) => (
              <div className={`source-row ${tone}`} key={tone}>
                <span className="signal-line" aria-hidden="true"><i /></span>
                <span className="icon-circle"><FeatureIcon type={icon} /></span>
                <span className="source-copy"><strong>{title}</strong><span>{body}</span></span>
                <span className="status"><i aria-hidden="true" />{status}</span>
              </div>
            ))}
          </div>
          <div className="coverage" id="coverage">
            <span className="globe" aria-hidden="true">◎</span>
            <strong>Coverage</strong>
            <span>Japan · Shinkansen</span>
            <i aria-hidden="true" />
            <span>Netherlands · station boards</span>
          </div>
        </div>
      </section>

      <section className="closing" aria-labelledby="closing-title">
        <div className="page-shell closing-inner">
          <div>
            <h2 id="closing-title">The platform is<br />taking shape.</h2>
            <p>Trainy is coming soon. Follow the build while we prepare for departure.</p>
            <a className="button button-light" href="https://github.com/Elemperor1/Trainy" target="_blank" rel="noreferrer">Follow development <Arrow /></a>
          </div>
          <div className="track-art" aria-hidden="true">
            <span className="signal-post"><i /><i /></span>
            <span className="vanishing-point" />
          </div>
        </div>
      </section>

      <footer className="page-shell">
        <span>© 2026 Trainy</span>
        <div>
          <a href="#principles">Privacy</a>
          <a href="#product">Accessibility</a>
          <span>Built with Codex</span>
        </div>
      </footer>
    </main>
  );
}
