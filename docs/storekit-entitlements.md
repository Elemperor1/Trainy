# Trainy Plus: entitlements and feature gating

Plan items 5.1 and 5.2 in [`engineering-plan.md`](engineering-plan.md#phase-5--monetization-plus).
This is the scaffold only. Nothing in the app asks the gate yet, there is no
paywall (5.3), and `PlusConfiguration.current.enforcesFeatureGates` is `false`, so
1.0 behaves exactly as it did before this code existed.

## Where things live

All under `Sources/TrainyCore/Entitlements/`.

| File | Role |
| --- | --- |
| `PlusConfiguration.swift` | The one place that names the product identifier, the free trip limit, and the switch that turns gating on |
| `EntitlementModels.swift` | `PlusOffer`, `EntitlementState`, `EntitlementGrant`, `PurchaseOutcome`, `EntitlementError`, and the pure rule that turns grants into a state |
| `EntitlementService.swift` | The protocol the store talks to |
| `StoreKitEntitlementService.swift` | The StoreKit 2 implementation, and the only file that imports StoreKit |
| `EntitlementStore.swift` | `@MainActor` `ObservableObject` with entitlement, offers, purchase, and restore state, and `isUnlocked(_:)` |
| `Feature.swift` | The `Feature` enum and `FeatureGate`, the single place that decides what Plus unlocks |
| `FakeEntitlementService.swift` | Debug-only in-memory service for tests, previews, and UI automation |

```
screens ──► EntitlementStore ──► EntitlementService
              │                    ├─ StoreKitEntitlementService  (production)
              │                    └─ FakeEntitlementService      (Debug only)
              └─► FeatureGate.isUnlocked(_:)
```

## Rules the code keeps

- **Verified only.** An unverified transaction is never reported as a grant and
  never finished.
- **StoreKit is the source of truth.** The entitlement is recomputed from
  `Transaction.currentEntitlements` after every launch, purchase, restore, and
  `Transaction.updates` event. Nothing is cached or stored by the app.
- **Expiry is StoreKit's call.** The expiration date is for display. It is not
  compared with the clock, because StoreKit keeps a subscription in its current
  set during a billing grace period. StoreKit sends no event when a subscription
  just runs out, so call `refresh()` whenever the app returns to the foreground.
- **Lapsing never costs data.** `FeatureGate` only answers "may the rider use or
  add this". It has no way to remove trips, so a rider over the free limit keeps
  what they have and cannot add more.
- **Locked until known.** Until the first read finishes (`.unknown`), Plus
  features are locked once gating is on. Check `entitlement.isResolved` before
  showing an upsell.
- **Latest read wins.** Each read is numbered when it starts and a slower, older
  read is dropped, so it cannot undo a purchase or refund that landed meanwhile.

## The free and Plus split

From the plan's decisions table: free riders track a few trips and keep the
schedule view and NS boards; Plus adds unlimited trips, reminders, widgets and
Live Activities, and history. In code every `Feature` case needs Plus, and
anything not listed is free. The free limit is `freeTrackedTripLimit` (placeholder
**3**).

One conflict to settle before gating goes on: the release train ships local
reminders (3.1) in the free 1.0, but the decisions table lists reminders as Plus.
If reminders are free in 1.0, taking them away in 1.1 costs trust; the simplest
fix is to drop `tripReminders` from `Feature`.

## Turning Plus on (the 1.1 checklist)

1. Decide the price and shape: an annual subscription, a monthly one, a lifetime
   unlock, or both annual and lifetime (the launch plan's recommendation).
   `productIDs` takes several; a grant that never expires outranks a subscription.
2. Create the products in App Store Connect (below), then replace the placeholder
   in `PlusConfiguration.current` and in `TrainyIOS/StoreKit/Trainy.storekit`.
   A test fails if the two drift apart.
3. Create the store once with `EntitlementStore.live()`, hold it in
   `TrainyRootDependencies`, call `start()` at launch, and call `refresh()` when
   `scenePhase` becomes active. `start()` must run before any UI so that
   `Transaction.updates` is observed from launch.
4. Ask the store at each call site: `store.isUnlocked(.tripReminders)` and
   `store.featureGate.canTrackAnotherTrip(currentCount:)`.
5. Build the paywall (5.3), then set `enforcesFeatureGates` to `true` and update
   `testShippedConfigurationStaysDormantUntilPlusIsOnSale`, which exists so gating
   cannot ship by accident.
6. Re-run the privacy manifest, App Privacy label, and archive audit (5.5).

## What to create in App Store Connect

Needs the paid Apple Developer team, so it comes after enrollment.

- Accept the Paid Applications Agreement and finish the banking and tax forms. No
  product can sell before that.
- For a subscription: a subscription group (placeholder name "Trainy Plus") and an
  auto-renewable subscription in it. For a lifetime unlock: a non-consumable. Do
  not use a non-renewing subscription: StoreKit never drops those from the current
  entitlements, so Plus would never lapse.
- **Product ID.** The placeholder is `com.jacobcyber.Trainy.plus`. A product ID is
  permanent once created, so settle the name first, for example `.plus.annual`
  and `.plus.lifetime`. The Swift code does not care which product types are used.
- Price, duration, and a display name and description per language. The paywall
  shows the App Store's own price, so there is no price to keep in sync in code.
- Review screenshot and review notes for the in-app purchase, then attach it to the
  app version that ships the paywall.
- Sandbox tester accounts for on-device testing.

## Testing

- `Tests/TrainyCoreTests/EntitlementTests.swift` drives the store, the gate, and the
  grant rule with `FakeEntitlementService`. Time and StoreKit are never touched.
- `TrainyIOS/StoreKit/Trainy.storekit` is a local StoreKit configuration for
  running the app in the simulator without App Store Connect. Select it under
  Edit Scheme, Run, Options, StoreKit Configuration. The price in it is a
  placeholder. It is not attached to a shared scheme yet.
- Not covered yet: `StoreKitTest` cases that run the real adapter against that
  file (purchase, renewal, refund, restore). They need a Mac and the file attached
  to a test plan, so they belong with the paywall work.
