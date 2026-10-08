// Japan service-day arithmetic: dates, national holidays, and day classes.
//
// A "service date" is a Japan Standard Time calendar date (YYYY-MM-DD). The
// service day starts at 04:00, so a train that leaves at 00:20 belongs to the
// previous service date and its stop times run past 24:00. Japan has no daylight
// saving time, so every timestamp is a fixed +09:00 offset.

export type DayClass = "weekday" | "saturday" | "holiday";

export const FIRST_SUPPORTED_YEAR = 2022;
export const LAST_SUPPORTED_YEAR = 2099;
export const SERVICE_DAY_START_MINUTE = 240;
export const MINUTES_PER_DAY = 1_440;

const JST_OFFSET_MINUTES = 540;
const MILLISECONDS_PER_DAY = 86_400_000;
const SERVICE_DATE = /^(\d{4})-(\d{2})-(\d{2})$/u;
const holidayCache = new Map<number, ReadonlySet<string>>();

interface DateParts {
  year: number;
  month: number;
  day: number;
}

function parseServiceDate(value: string): DateParts | null {
  const match = SERVICE_DATE.exec(value);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const check = new Date(Date.UTC(year, month - 1, day));
  if (
    check.getUTCFullYear() !== year
    || check.getUTCMonth() !== month - 1
    || check.getUTCDate() !== day
  ) return null;
  return { year, month, day };
}

function pad(value: number, width = 2): string {
  return String(value).padStart(width, "0");
}

function formatEpochDay(epochMilliseconds: number): string {
  const date = new Date(epochMilliseconds);
  return `${pad(date.getUTCFullYear(), 4)}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}`;
}

function epochDay(serviceDate: string): number {
  const parts = parseServiceDate(serviceDate);
  if (!parts) throw new RangeError("Invalid service date.");
  return Date.UTC(parts.year, parts.month - 1, parts.day);
}

/** True for a calendar-valid date inside the years whose holidays are computed. */
export function isSupportedServiceDate(value: string): boolean {
  const parts = parseServiceDate(value);
  return parts !== null && parts.year >= FIRST_SUPPORTED_YEAR && parts.year <= LAST_SUPPORTED_YEAR;
}

export function addDays(serviceDate: string, days: number): string {
  return formatEpochDay(epochDay(serviceDate) + days * MILLISECONDS_PER_DAY);
}

/** 0 is Sunday through 6 for Saturday. */
export function dayOfWeek(serviceDate: string): number {
  return new Date(epochDay(serviceDate)).getUTCDay();
}

/** The service date in effect at an instant: JST minus the 04:00 service-day start. */
export function currentServiceDate(instant: Date): string {
  return formatEpochDay(instant.getTime() + (JST_OFFSET_MINUTES - SERVICE_DAY_START_MINUTE) * 60_000);
}

/** The service date of an ISO-8601 instant with an explicit offset, or null. */
export function serviceDateOfInstant(value: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,9})?)?(?:Z|[+-]\d{2}:?\d{2})$/u.test(value)) return null;
  const milliseconds = Date.parse(value);
  return Number.isFinite(milliseconds) ? currentServiceDate(new Date(milliseconds)) : null;
}

function nthMonday(year: number, month: number, nth: number): number {
  const firstWeekday = new Date(Date.UTC(year, month - 1, 1)).getUTCDay();
  return 1 + ((8 - firstWeekday) % 7) + 7 * (nth - 1);
}

// Standard approximations of the vernal and autumnal equinox days, valid 1980-2099.
function springEquinoxDay(year: number): number {
  return Math.floor(20.8431 + 0.242194 * (year - 1980) - Math.floor((year - 1980) / 4));
}

function autumnEquinoxDay(year: number): number {
  return Math.floor(23.2488 + 0.242194 * (year - 1980) - Math.floor((year - 1980) / 4));
}

/**
 * National holidays for a year, as YYYY-MM-DD strings.
 *
 * Computed from the rules in the Act on National Holidays as amended for 2022
 * and later (fixed dates, "Happy Monday" Mondays, equinoxes, substitute holidays
 * when a holiday falls on Sunday, and single days between two holidays). The
 * Cabinet Office publishes each year's official list in February: compare it
 * with this output once a year, and do not extend the supported range without
 * checking the law again.
 */
export function nationalHolidays(year: number): ReadonlySet<string> {
  if (!Number.isInteger(year) || year < FIRST_SUPPORTED_YEAR || year > LAST_SUPPORTED_YEAR) {
    throw new RangeError("Holiday rules are only implemented for 2022 through 2099.");
  }
  const cached = holidayCache.get(year);
  if (cached) return cached;

  const named = new Set<string>();
  const add = (month: number, day: number) => named.add(`${pad(year, 4)}-${pad(month)}-${pad(day)}`);
  add(1, 1);
  add(1, nthMonday(year, 1, 2));
  add(2, 11);
  add(2, 23);
  add(3, springEquinoxDay(year));
  add(4, 29);
  add(5, 3);
  add(5, 4);
  add(5, 5);
  add(7, nthMonday(year, 7, 3));
  add(8, 11);
  add(9, nthMonday(year, 9, 3));
  add(9, autumnEquinoxDay(year));
  add(10, nthMonday(year, 10, 2));
  add(11, 3);
  add(11, 23);

  const all = new Set(named);
  for (const date of [...named].sort()) {
    if (dayOfWeek(date) !== 0) continue;
    let substitute = addDays(date, 1);
    while (all.has(substitute)) substitute = addDays(substitute, 1);
    all.add(substitute);
  }
  for (const date of [...named].sort()) {
    const between = addDays(date, 1);
    if (named.has(addDays(date, 2)) && !all.has(between) && dayOfWeek(between) !== 0) all.add(between);
  }

  holidayCache.set(year, all);
  return all;
}

/**
 * Sunday and national holidays are "holiday"; other Saturdays are "saturday";
 * the rest are "weekday". Operator-declared special days (year-end, extra
 * trains) are not part of this and only apply through explicit calendars.
 */
export function dayClassOf(serviceDate: string): DayClass {
  const parts = parseServiceDate(serviceDate);
  if (!parts) throw new RangeError("Invalid service date.");
  const weekday = dayOfWeek(serviceDate);
  if (weekday === 0 || nationalHolidays(parts.year).has(serviceDate)) return "holiday";
  return weekday === 6 ? "saturday" : "weekday";
}

/** "HH:MM" with hours 0-29 (service-day style) as minutes since the service date began, or null. */
export function parseClockMinutes(value: string): number | null {
  const match = /^(\d{1,2}):([0-5]\d)$/u.exec(value);
  if (!match) return null;
  const hours = Number(match[1]);
  return hours > 29 ? null : hours * 60 + Number(match[2]);
}

/** ISO-8601 timestamp (+09:00) for minutes after the start of a service date. */
export function timestampAt(serviceDate: string, minutes: number): string {
  const days = Math.floor(minutes / MINUTES_PER_DAY);
  const remainder = minutes - days * MINUTES_PER_DAY;
  const date = days === 0 ? serviceDate : addDays(serviceDate, days);
  return `${date}T${pad(Math.floor(remainder / 60))}:${pad(remainder % 60)}:00+09:00`;
}
