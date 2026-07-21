# Design fidelity ledger

Concept: `landing-concept.png`

| Comparison point | Concept evidence | Render evidence | Disposition |
| --- | --- | --- | --- |
| Hero composition | Left-aligned launch copy over a dark station image, with the train entering from the right | Production render keeps the same copy/image split and edge treatment at 1440px and 390px | Matched; mobile stacks the image above the copy to preserve legibility |
| Type hierarchy | Large, tight grotesk headline; compact supporting copy and UI labels | H1 scales from 92px desktop to 57px mobile with matching weight and line rhythm | Matched without loading a third-party font |
| Journey structure | Open three-stop rail with numbered stops, circular line icons, and hairline separators | Implemented as a semantic ordered list with one continuous rail and responsive two-column rows | Matched; mobile hides redundant numbers but preserves order and icons |
| Data-truth section | Three horizontal provenance/status rows using restrained blue, green, and orange signals | Implemented with the same three tiers, status dots, source descriptions, and dark radial field | Matched; copy was tightened to reflect the product’s actual provider contracts |
| Closing section | Large coming-soon close beside a minimal track/signal drawing | Implemented with CSS rail geometry and a direct GitHub development link | Matched without adding a fake launch date, waitlist, or download badge |
| Responsive behavior | Desktop concept implies a calm vertical continuation | Browser checks at 1440x900 and 390x844 show no horizontal overflow; navigation simplifies to GitHub on mobile | Intentional responsive adaptation |
| Accessibility | Concept uses strong contrast and obvious actions | Semantic regions/headings, visible focus rings, reduced-motion handling, descriptive link names, and decorative graphics hidden from assistive technology | Improved beyond the static concept |

Agency sign-off: the implementation is faithful to the accepted concept’s
composition, spacing, color, typography, imagery, and component geometry. The
only meaningful deviations are responsive adaptations and truth-preserving copy
refinements. The result is ready for public launch-preview use.
