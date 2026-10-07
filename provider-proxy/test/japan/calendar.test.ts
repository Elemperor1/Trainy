import { describe, expect, it } from "vitest";
import {
  addDays,
  currentServiceDate,
  dayClassOf,
  isSupportedServiceDate,
  nationalHolidays,
  parseClockMinutes,
  serviceDateOfInstant,
  timestampAt
} from "../../src/japan/calendar";

// Official lists published by the Cabinet Office (内閣府), including substitute
// holidays (振替休日) and citizens' holidays (国民の休日).
const OFFICIAL_HOLIDAYS: Record<number, string[]> = {
  2024: [
    "01-01", "01-08", "02-11", "02-12", "02-23", "03-20", "04-29", "05-03", "05-04", "05-05", "05-06",
    "07-15", "08-11", "08-12", "09-16", "09-22", "09-23", "10-14", "11-03", "11-04", "11-23"
  ],
  2025: [
    "01-01", "01-13", "02-11", "02-23", "02-24", "03-20", "04-29", "05-03", "05-04", "05-05", "05-06",
    "07-21", "08-11", "09-15", "09-23", "10-13", "11-03", "11-23", "11-24"
  ],
  2026: [
    "01-01", "01-12", "02-11", "02-23", "03-20", "04-29", "05-03", "05-04", "05-05", "05-06",
    "07-20", "08-11", "09-21", "09-22", "09-23", "10-12", "11-03", "11-23"
  ],
  2027: [
    "01-01", "01-11", "02-11", "02-23", "03-21", "03-22", "04-29", "05-03", "05-04", "05-05",
    "07-19", "08-11", "09-20", "09-23", "10-11", "11-03", "11-23"
  ],
  2028: [
    "01-01", "01-10", "02-11", "02-23", "03-20", "04-29", "05-03", "05-04", "05-05",
    "07-17", "08-11", "09-18", "09-22", "10-09", "11-03", "11-23"
  ]
};

describe("Japanese national holidays", () => {
  for (const [year, expected] of Object.entries(OFFICIAL_HOLIDAYS)) {
    it(`matches the official ${year} list`, () => {
      const computed = [...nationalHolidays(Number(year))].sort().map((date) => date.slice(5));
      expect(computed).toEqual(expected);
    });
  }

  it("refuses years the rules were not written for", () => {
    expect(() => nationalHolidays(2021)).toThrow(RangeError);
    expect(() => nationalHolidays(2100)).toThrow(RangeError);
  });
});

describe("day classes", () => {
  it("classifies weekdays, Saturdays, Sundays, and holidays", () => {
    expect(dayClassOf("2026-10-07")).toBe("weekday"); // Wednesday
    expect(dayClassOf("2026-10-10")).toBe("saturday");
    expect(dayClassOf("2026-10-11")).toBe("holiday"); // Sunday
    expect(dayClassOf("2026-10-12")).toBe("holiday"); // Sports Day, a Monday
    expect(dayClassOf("2026-09-22")).toBe("holiday"); // citizens' holiday between two holidays
    expect(dayClassOf("2026-05-06")).toBe("holiday"); // substitute holiday
  });

  it("treats a holiday that falls on a Saturday as a holiday", () => {
    expect(dayClassOf("2025-05-03")).toBe("holiday"); // Constitution Day on a Saturday
    expect(dayClassOf("2025-05-10")).toBe("saturday");
  });

  it("rejects dates it cannot classify", () => {
    expect(() => dayClassOf("2026-02-30")).toThrow(RangeError);
  });
});

describe("service dates", () => {
  it("rolls the service day at 04:00 Japan time", () => {
    expect(currentServiceDate(new Date("2026-10-07T18:59:00Z"))).toBe("2026-10-07"); // 03:59 JST on Oct 8
    expect(currentServiceDate(new Date("2026-10-07T19:00:00Z"))).toBe("2026-10-08"); // 04:00 JST
    expect(currentServiceDate(new Date("2026-10-08T00:00:00Z"))).toBe("2026-10-08");
  });

  it("validates calendar dates inside the supported years", () => {
    expect(isSupportedServiceDate("2026-10-07")).toBe(true);
    expect(isSupportedServiceDate("2024-02-29")).toBe(true);
    expect(isSupportedServiceDate("2026-02-30")).toBe(false);
    expect(isSupportedServiceDate("2026-13-01")).toBe(false);
    expect(isSupportedServiceDate("2021-12-31")).toBe(false);
    expect(isSupportedServiceDate("2100-01-01")).toBe(false);
    expect(isSupportedServiceDate("2026-1-1")).toBe(false);
    expect(isSupportedServiceDate("2026-10-07T00:00:00Z")).toBe(false);
  });

  it("adds days across month, year, and leap-day boundaries", () => {
    expect(addDays("2026-10-31", 1)).toBe("2026-11-01");
    expect(addDays("2026-12-31", 1)).toBe("2027-01-01");
    expect(addDays("2028-02-28", 1)).toBe("2028-02-29");
    expect(addDays("2026-03-01", -1)).toBe("2026-02-28");
  });

  it("reads the service date of an instant with an explicit offset", () => {
    expect(serviceDateOfInstant("2026-06-30T14:59:00Z")).toBe("2026-06-30");
    expect(serviceDateOfInstant("2026-07-01T00:00:00+09:00")).toBe("2026-06-30");
    expect(serviceDateOfInstant("2026-07-01T05:00:00+09:00")).toBe("2026-07-01");
    expect(serviceDateOfInstant("2026-06-30T14:59:00")).toBeNull();
    expect(serviceDateOfInstant("not a date")).toBeNull();
  });
});

describe("clock times", () => {
  it("parses service-day clock times", () => {
    expect(parseClockMinutes("08:30")).toBe(510);
    expect(parseClockMinutes("8:30")).toBe(510);
    expect(parseClockMinutes("24:10")).toBe(1_450);
    expect(parseClockMinutes("29:59")).toBe(1_799);
    expect(parseClockMinutes("30:00")).toBeNull();
    expect(parseClockMinutes("08:60")).toBeNull();
    expect(parseClockMinutes("0830")).toBeNull();
    expect(parseClockMinutes("")).toBeNull();
  });

  it("formats timestamps with the fixed +09:00 offset across midnight", () => {
    expect(timestampAt("2026-10-08", 0)).toBe("2026-10-08T00:00:00+09:00");
    expect(timestampAt("2026-10-08", 510)).toBe("2026-10-08T08:30:00+09:00");
    expect(timestampAt("2026-10-08", 1_450)).toBe("2026-10-09T00:10:00+09:00");
    expect(timestampAt("2026-12-31", 1_500)).toBe("2027-01-01T01:00:00+09:00");
  });
});
