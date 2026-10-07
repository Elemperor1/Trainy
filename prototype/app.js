const trips = [
  {
    id: "nozomi-231",
    train: "Nozomi 231",
    operator: "JR Central",
    service: "Tokaido Shinkansen",
    from: "Tokyo",
    fromCode: "TYO",
    to: "Shin-Osaka",
    toCode: "OSA",
    depart: "09:21",
    arrive: "11:48",
    duration: "2h 27m",
    status: "On time",
    statusTone: "good",
    filter: "departing",
    platform: "18",
    nextStop: "Nagoya",
    eta: "10:58",
    speed: "258 km/h",
    progress: 36,
    bestCar: 7,
    cars: 16,
    seat: "Car 7, Seat 12A",
    updated: "starter feed",
    signal: 86,
    call: "Stand by car marker 7 on platform 18. This starter feed is ready for the Tokaido Shinkansen flow.",
    confidence: "Route, stop order, platform, and map context are from Trainy's Shinkansen starter data. Live JR delay feeds are not connected yet.",
    stops: [
      { name: "Tokyo", time: "09:21", platform: "18", note: "Departed", state: "done" },
      { name: "Shin-Yokohama", time: "09:39", platform: "3", note: "Departed", state: "done" },
      { name: "Nagoya", time: "10:58", platform: "16", note: "Next stop", state: "current" },
      { name: "Kyoto", time: "11:34", platform: "14", note: "Expected", state: "pending" },
      { name: "Shin-Osaka", time: "11:48", platform: "25", note: "Final stop", state: "pending" }
    ],
    alerts: [
      { title: "Shinkansen starter feed", detail: "Tokaido route data is loaded for Japan-first validation.", tone: "good" },
      { title: "Reserved seat cue", detail: "Car 7 keeps this trip aligned with the selected reserved seat.", tone: "good" }
    ],
    pulse: "Tokaido starter corridor loaded"
  },
  {
    id: "sakura-555",
    train: "Sakura 555",
    operator: "JR West / JR Kyushu",
    service: "Sanyo-Kyushu Shinkansen",
    from: "Shin-Osaka",
    fromCode: "OSA",
    to: "Kagoshima-Chuo",
    toCode: "KOJ",
    depart: "10:06",
    arrive: "14:13",
    duration: "4h 07m",
    status: "Boarding",
    statusTone: "good",
    filter: "departing",
    platform: "20",
    nextStop: "Okayama",
    eta: "10:54",
    speed: "0 km/h",
    progress: 5,
    bestCar: 5,
    cars: 8,
    seat: "Car 5, Seat 9D",
    updated: "starter feed",
    signal: 82,
    call: "Board the 8-car set from marker 5. This through-service is the first cross-operator Shinkansen case.",
    confidence: "Trainy knows the through route and major stops, with live operator handoff data still pending.",
    stops: [
      { name: "Shin-Osaka", time: "10:06", platform: "20", note: "Boarding", state: "current" },
      { name: "Okayama", time: "10:54", platform: "22", note: "Expected", state: "pending" },
      { name: "Hiroshima", time: "11:35", platform: "12", note: "Expected", state: "pending" },
      { name: "Hakata", time: "12:38", platform: "15", note: "JR Kyushu handoff", state: "pending" },
      { name: "Kumamoto", time: "13:17", platform: "13", note: "Expected", state: "pending" },
      { name: "Kagoshima-Chuo", time: "14:13", platform: "12", note: "Final stop", state: "pending" }
    ],
    alerts: [
      { title: "Through-service check", detail: "This trip validates JR West to JR Kyushu handoff behavior.", tone: "good" },
      { title: "Short trainset", detail: "Sakura services usually use fewer cars than Tokaido Nozomi sets.", tone: "watch" }
    ],
    pulse: "Sanyo-Kyushu starter corridor loaded"
  },
  {
    id: "hayabusa-17",
    train: "Hayabusa 17",
    operator: "JR East",
    service: "Tohoku Shinkansen",
    from: "Tokyo",
    fromCode: "TYO",
    to: "Shin-Aomori",
    toCode: "AOJ",
    depart: "09:36",
    arrive: "12:49",
    duration: "3h 13m",
    status: "On time",
    statusTone: "good",
    filter: "departing",
    platform: "21",
    nextStop: "Sendai",
    eta: "11:07",
    speed: "286 km/h",
    progress: 31,
    bestCar: 6,
    cars: 10,
    seat: "Car 6, Seat 6A",
    updated: "starter feed",
    signal: 84,
    call: "Use the north Shinkansen concourse and board near car 6 for balanced exits at Sendai and Morioka.",
    confidence: "Major Tohoku Shinkansen stops are loaded; live train location is simulated for now.",
    stops: [
      { name: "Tokyo", time: "09:36", platform: "21", note: "Departed", state: "done" },
      { name: "Omiya", time: "10:01", platform: "17", note: "Departed", state: "done" },
      { name: "Sendai", time: "11:07", platform: "12", note: "Next stop", state: "current" },
      { name: "Morioka", time: "11:48", platform: "14", note: "Expected", state: "pending" },
      { name: "Shin-Aomori", time: "12:49", platform: "13", note: "Final stop", state: "pending" }
    ],
    alerts: [
      { title: "Tohoku route ready", detail: "Hayabusa coverage validates long-distance JR East Shinkansen trips.", tone: "good" },
      { title: "Seat position", detail: "Car 6 keeps transfers balanced at the large intermediate stations.", tone: "good" }
    ],
    pulse: "Tohoku starter corridor loaded"
  },
  {
    id: "kagayaki-509",
    train: "Kagayaki 509",
    operator: "JR East / JR West",
    service: "Hokuriku Shinkansen",
    from: "Tokyo",
    fromCode: "TYO",
    to: "Tsuruga",
    toCode: "TSU",
    depart: "10:24",
    arrive: "13:32",
    duration: "3h 08m",
    status: "Scheduled",
    statusTone: "good",
    filter: "departing",
    platform: "22",
    nextStop: "Nagano",
    eta: "11:45",
    speed: "0 km/h",
    progress: 0,
    bestCar: 8,
    cars: 12,
    seat: "Car 8, Seat 3E",
    updated: "starter feed",
    signal: 80,
    call: "Track this route to validate the new Kanazawa-Tsuruga extension shape in the app.",
    confidence: "The Hokuriku route includes the Tsuruga terminus, with live JR West status data planned for a later provider.",
    stops: [
      { name: "Tokyo", time: "10:24", platform: "22", note: "Gate pending", state: "current" },
      { name: "Nagano", time: "11:45", platform: "12", note: "Expected", state: "pending" },
      { name: "Toyama", time: "12:30", platform: "13", note: "Expected", state: "pending" },
      { name: "Kanazawa", time: "12:53", platform: "14", note: "Expected", state: "pending" },
      { name: "Tsuruga", time: "13:32", platform: "12", note: "Final stop", state: "pending" }
    ],
    alerts: [
      { title: "Hokuriku extension", detail: "Tsuruga is included so the starter dataset reflects the current endpoint shape.", tone: "good" },
      { title: "Platform watch", detail: "Tokyo platform is representative starter data until a live station feed is wired.", tone: "watch" }
    ],
    pulse: "Hokuriku starter corridor loaded"
  },
  {
    id: "toki-327",
    train: "Toki 327",
    operator: "JR East",
    service: "Joetsu Shinkansen",
    from: "Tokyo",
    fromCode: "TYO",
    to: "Niigata",
    toCode: "KIJ",
    depart: "13:40",
    arrive: "15:48",
    duration: "2h 08m",
    status: "Scheduled",
    statusTone: "good",
    filter: "departing",
    platform: "20",
    nextStop: "Takasaki",
    eta: "14:29",
    speed: "0 km/h",
    progress: 0,
    bestCar: 4,
    cars: 10,
    seat: "Car 4, Seat 10C",
    updated: "starter feed",
    signal: 79,
    call: "Use this Joetsu trip to validate shorter regional Shinkansen tracking and snow-country stops.",
    confidence: "Trainy has the Joetsu corridor station order; real delay and snow disruption feeds are future work.",
    stops: [
      { name: "Tokyo", time: "13:40", platform: "20", note: "Gate pending", state: "current" },
      { name: "Takasaki", time: "14:29", platform: "12", note: "Expected", state: "pending" },
      { name: "Echigo-Yuzawa", time: "14:56", platform: "11", note: "Expected", state: "pending" },
      { name: "Niigata", time: "15:48", platform: "13", note: "Final stop", state: "pending" }
    ],
    alerts: [
      { title: "Joetsu route ready", detail: "Niigata-bound service is available in search and tracking.", tone: "good" },
      { title: "Weather-aware future", detail: "This route is a good candidate for later disruption data.", tone: "watch" }
    ],
    pulse: "Joetsu starter corridor loaded"
  },
  {
    id: "hayabusa-13",
    train: "Hayabusa 13",
    operator: "JR East / JR Hokkaido",
    service: "Tohoku-Hokkaido Shinkansen",
    from: "Tokyo",
    fromCode: "TYO",
    to: "Shin-Hakodate-Hokuto",
    toCode: "HKD",
    depart: "08:20",
    arrive: "12:17",
    duration: "3h 57m",
    status: "Tunnel watch",
    statusTone: "watch",
    filter: "attention",
    platform: "21",
    nextStop: "Shin-Aomori",
    eta: "11:29",
    speed: "260 km/h",
    progress: 71,
    bestCar: 5,
    cars: 10,
    seat: "Car 5, Seat 8B",
    updated: "starter feed",
    signal: 76,
    call: "Watch the Shin-Aomori handoff and Seikan Tunnel segment. This validates cross-island trip presentation.",
    confidence: "Route geometry reaches Hokkaido, but tunnel-specific operational notices are not connected yet.",
    stops: [
      { name: "Tokyo", time: "08:20", platform: "21", note: "Departed", state: "done" },
      { name: "Sendai", time: "09:52", platform: "12", note: "Departed", state: "done" },
      { name: "Morioka", time: "10:32", platform: "14", note: "Departed", state: "done" },
      { name: "Shin-Aomori", time: "11:29", platform: "13", note: "Next stop", state: "current" },
      { name: "Shin-Hakodate-Hokuto", time: "12:17", platform: "11", note: "Final stop", state: "pending" }
    ],
    alerts: [
      { title: "Hokkaido handoff", detail: "Cross-operator service is represented for later live provider wiring.", tone: "watch" },
      { title: "Long-distance buffer", detail: "Keep onward limited-express connections visible at Shin-Hakodate-Hokuto.", tone: "good" }
    ],
    pulse: "Hokkaido starter corridor loaded"
  }
];

const state = {
  selectedId: localStorage.getItem("trainy:selected") || trips[0].id,
  filter: "all",
  query: "",
  notified: new Set(JSON.parse(localStorage.getItem("trainy:notified") || "[]")),
  pinned: new Set(JSON.parse(localStorage.getItem("trainy:pinned") || "[]"))
};

if (!trips.some((trip) => trip.id === state.selectedId)) {
  state.selectedId = trips[0].id;
  localStorage.setItem("trainy:selected", state.selectedId);
}

const els = {
  tripList: document.querySelector("#trip-list"),
  tripSearch: document.querySelector("#trip-search"),
  segments: document.querySelectorAll(".segment"),
  selectedService: document.querySelector("#selected-service"),
  selectedTitle: document.querySelector("#selected-title"),
  selectedStatus: document.querySelector("#selected-status"),
  fromCode: document.querySelector("#from-code"),
  fromName: document.querySelector("#from-name"),
  departTime: document.querySelector("#depart-time"),
  toCode: document.querySelector("#to-code"),
  toName: document.querySelector("#to-name"),
  arriveTime: document.querySelector("#arrive-time"),
  railProgress: document.querySelector("#rail-progress"),
  trainMarker: document.querySelector("#train-marker"),
  durationLabel: document.querySelector("#duration-label"),
  progressLabel: document.querySelector("#progress-label"),
  platformValue: document.querySelector("#platform-value"),
  nextStopValue: document.querySelector("#next-stop-value"),
  etaValue: document.querySelector("#eta-value"),
  speedValue: document.querySelector("#speed-value"),
  updatedLabel: document.querySelector("#updated-label"),
  stationTimeline: document.querySelector("#station-timeline"),
  platformMap: document.querySelector("#platform-map"),
  carLabel: document.querySelector("#car-label"),
  actionTitle: document.querySelector("#action-title"),
  actionCopy: document.querySelector("#action-copy"),
  notifyButton: document.querySelector("#notify-button"),
  pinButton: document.querySelector("#pin-button"),
  signalScore: document.querySelector("#signal-score"),
  signalFill: document.querySelector("#signal-fill"),
  signalCopy: document.querySelector("#signal-copy"),
  alertCount: document.querySelector("#alert-count"),
  alertList: document.querySelector("#alert-list"),
  networkList: document.querySelector("#network-list"),
  platformCount: document.querySelector("#platform-count"),
  riskCount: document.querySelector("#risk-count"),
  refreshButton: document.querySelector("#refresh-button"),
  shareButton: document.querySelector("#share-button"),
  compactToggle: document.querySelector("#compact-toggle"),
  toast: document.querySelector("#toast")
};

function getSelectedTrip() {
  return trips.find((trip) => trip.id === state.selectedId) || trips[0];
}

function matchesFilter(trip) {
  if (state.filter === "all") return true;
  if (state.filter === "departing") return trip.filter === "departing";
  return trip.filter === "attention";
}

function matchesQuery(trip) {
  if (!state.query) return true;
  const haystack = [
    trip.train,
    trip.operator,
    trip.service,
    trip.from,
    trip.to,
    trip.nextStop,
    trip.status
  ]
    .join(" ")
    .toLowerCase();
  return haystack.includes(state.query.toLowerCase());
}

function renderTripList() {
  const visibleTrips = trips.filter((trip) => matchesFilter(trip) && matchesQuery(trip));

  if (!visibleTrips.length) {
    els.tripList.innerHTML = TrainyUI.emptyState("No tracked trains match this view.");
    return;
  }

  els.tripList.innerHTML = visibleTrips
    .map((trip) =>
      TrainyUI.tripCard(trip, {
        active: trip.id === state.selectedId,
        pinned: state.pinned.has(trip.id),
      })
    )
    .join("");

  els.tripList.querySelectorAll("[data-trip-id]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedId = button.dataset.tripId;
      localStorage.setItem("trainy:selected", state.selectedId);
      render();
      revealLivePanelOnSmallScreens();
    });
  });
}

function revealLivePanelOnSmallScreens() {
  if (!window.matchMedia("(max-width: 860px)").matches) return;
  const behavior = window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth";
  window.requestAnimationFrame(() => {
    document.querySelector(".live-panel")?.scrollIntoView({ behavior, block: "start" });
  });
}

function renderSelectedTrip() {
  const trip = getSelectedTrip();
  const progress = Math.min(Math.max(trip.progress, 0), 100);

  els.selectedService.textContent = `${trip.operator} - ${trip.service}`;
  els.selectedTitle.textContent = trip.train;
  els.selectedStatus.textContent = trip.status;
  els.selectedStatus.className = `status-pill ${TrainyUI.toneClass(trip)}`;
  els.fromCode.textContent = trip.fromCode;
  els.fromName.textContent = trip.from;
  els.departTime.textContent = trip.depart;
  els.toCode.textContent = trip.toCode;
  els.toName.textContent = trip.to;
  els.arriveTime.textContent = trip.arrive;
  els.railProgress.style.width = `${progress}%`;
  els.trainMarker.style.left = `${progress}%`;
  els.durationLabel.textContent = trip.duration;
  els.progressLabel.textContent = `${progress}% complete`;
  els.platformValue.textContent = trip.platform;
  els.nextStopValue.textContent = trip.nextStop;
  els.etaValue.textContent = trip.eta;
  els.speedValue.textContent = trip.speed;
  els.updatedLabel.textContent = `Updated ${trip.updated}`;
  els.carLabel.textContent = `${trip.seat} - ${trip.cars} cars`;
  els.actionTitle.textContent = trip.statusTone === "late" ? "Protect the connection" : "Best next move";
  els.actionCopy.textContent = trip.call;
  els.signalScore.textContent = `${trip.signal}%`;
  els.signalFill.style.width = `${trip.signal}%`;
  els.signalCopy.textContent = trip.confidence;
  els.notifyButton.textContent = state.notified.has(trip.id) ? "Notifications On" : "Notify Me";
  els.pinButton.textContent = state.pinned.has(trip.id) ? "Pinned" : "Pin Train";
}

function renderTimeline() {
  const trip = getSelectedTrip();
  els.stationTimeline.innerHTML = trip.stops.map((stop) => TrainyUI.timelineRow(stop)).join("");
}

function renderPlatformMap() {
  const trip = getSelectedTrip();
  const cars = Array.from({ length: trip.cars }, (_, index) => index + 1);
  els.platformMap.innerHTML = cars.map((n) => TrainyUI.car(n, { best: n === trip.bestCar })).join("");
}

function renderAlerts() {
  const trip = getSelectedTrip();
  els.alertCount.textContent = trip.alerts.length;
  els.alertList.innerHTML = trip.alerts.map((alert) => TrainyUI.alertItem(alert)).join("");
}

function renderNetworkBoard() {
  els.networkList.innerHTML = trips.map((trip) => TrainyUI.networkRow(trip)).join("");
}

function renderBrief() {
  const watchedPlatforms = new Set(trips.map((trip) => trip.platform)).size;
  const risks = trips.filter((trip) => trip.statusTone !== "good").length;
  els.platformCount.textContent = watchedPlatforms;
  els.riskCount.textContent = risks;
}

function render() {
  renderTripList();
  renderSelectedTrip();
  renderTimeline();
  renderPlatformMap();
  renderAlerts();
  renderNetworkBoard();
  renderBrief();
}

function showToast(message) {
  els.toast.textContent = message;
  els.toast.classList.add("show");
  window.clearTimeout(showToast.timeout);
  showToast.timeout = window.setTimeout(() => {
    els.toast.classList.remove("show");
  }, 2400);
}

function persistSet(key, set) {
  localStorage.setItem(key, JSON.stringify(Array.from(set)));
}

els.tripSearch.addEventListener("input", (event) => {
  state.query = event.target.value.trim();
  renderTripList();
});

els.segments.forEach((segment) => {
  segment.addEventListener("click", () => {
    state.filter = segment.dataset.filter;
    els.segments.forEach((item) => {
      const active = item === segment;
      item.classList.toggle("active", active);
      item.setAttribute("aria-selected", String(active));
    });
    renderTripList();
  });
});

els.notifyButton.addEventListener("click", () => {
  const trip = getSelectedTrip();
  if (state.notified.has(trip.id)) {
    state.notified.delete(trip.id);
    showToast(`Notifications paused for ${trip.train}.`);
  } else {
    state.notified.add(trip.id);
    showToast(`Notifications enabled for ${trip.train}.`);
  }
  persistSet("trainy:notified", state.notified);
  renderSelectedTrip();
});

els.pinButton.addEventListener("click", () => {
  const trip = getSelectedTrip();
  if (state.pinned.has(trip.id)) {
    state.pinned.delete(trip.id);
    showToast(`${trip.train} removed from pinned trains.`);
  } else {
    state.pinned.add(trip.id);
    showToast(`${trip.train} pinned.`);
  }
  persistSet("trainy:pinned", state.pinned);
  render();
});

els.refreshButton.addEventListener("click", () => {
  const trip = getSelectedTrip();
  trip.updated = "just now";
  trip.progress = Math.min(trip.progress + 1, 99);
  showToast("Live train data refreshed.");
  render();
});

els.shareButton.addEventListener("click", async () => {
  const trip = getSelectedTrip();
  const summary = `${trip.train}: ${trip.from} to ${trip.to}, ${trip.status}, platform ${trip.platform}, ETA ${trip.eta}.`;
  try {
    await navigator.clipboard.writeText(summary);
    showToast("Trip summary copied.");
  } catch {
    showToast(summary);
  }
});

els.compactToggle.addEventListener("click", () => {
  document.body.classList.toggle("compact");
  showToast(document.body.classList.contains("compact") ? "Compact mode on." : "Compact mode off.");
});

render();
