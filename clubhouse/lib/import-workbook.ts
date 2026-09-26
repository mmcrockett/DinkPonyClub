import { unzipSync, strFromU8 } from "fflate";
import { Season, Player } from "./model";
export async function importWorkbook(
  file: File,
  name: string,
): Promise<Season> {
  if (file.size > 10_000_000)
    throw new Error("Choose a workbook smaller than 10 MB.");
  let expanded = 0;
  const files = unzipSync(new Uint8Array(await file.arrayBuffer()), {
    filter: (f) => {
      expanded += f.originalSize;
      if (expanded > 25_000_000)
        throw new Error("The workbook expands beyond the 25 MB limit.");
      return (
        f.name.startsWith("xl/") &&
        (f.name.endsWith(".xml") || f.name.endsWith(".rels"))
      );
    },
  });
  const xml = (path: string) => {
    if (!files[path])
      throw new Error("This file is not a supported Excel workbook.");
    return new DOMParser().parseFromString(
      strFromU8(files[path]),
      "application/xml",
    );
  };
  const texts = files["xl/sharedStrings.xml"]
    ? [...xml("xl/sharedStrings.xml").getElementsByTagName("si")].map(
        (n) => n.textContent || "",
      )
    : [];
  const relations = xml("xl/_rels/workbook.xml.rels"); // Relationship XML is included separately below when extension is .rels.
  return parseWorkbook(xml, texts, relations, name);
}
function parseWorkbook(
  xml: (p: string) => Document,
  texts: string[],
  relations: Document,
  name: string,
): Season {
  const rels = Object.fromEntries(
    [...relations.getElementsByTagName("Relationship")].map((r) => [
      r.getAttribute("Id"),
      r.getAttribute("Target"),
    ]),
  );
  const sheets: Record<string, Record<string, Record<string, string>>> = {};
  for (const sh of xml("xl/workbook.xml").getElementsByTagName("sheet")) {
    const target = rels[sh.getAttribute("r:id") || ""] || "";
    const path = target.startsWith("/") ? target.slice(1) : "xl/" + target;
    const rows: Record<string, Record<string, string>> = {};
    for (const r of xml(path).getElementsByTagName("row")) {
      const row: Record<string, string> = {};
      for (const c of r.getElementsByTagName("c")) {
        let v =
          c.getElementsByTagName("v")[0]?.textContent ||
          c.getElementsByTagName("is")[0]?.textContent ||
          "";
        if (c.getAttribute("t") === "s") v = texts[Number(v)] || "";
        if (v) row[(c.getAttribute("r") || "").replace(/\d/g, "")] = v.trim();
      }
      rows[r.getAttribute("r") || ""] = row;
    }
    sheets[sh.getAttribute("name") || ""] = rows;
  }
  if (!sheets["League Roster"]) return historicalWorkbook(sheets, name);
  if (!sheets["League Roster"] || !sheets.Schedule || !sheets.Config)
    throw new Error(
      "Use a DPC workbook containing League Roster, Schedule, Config, and weekly entry tabs.",
    );
  const roster = sheets["League Roster"],
    players: Player[] = [];
  const clean = (n: string) => n.trim().replace(/\s*\(aka.*\)$/i, "");
  const rosterTeam = (name: string) =>
    Object.values(sheets.Roster || {}).find(
      (r) => clean(r.A || "") === clean(name),
    )?.B;
  for (const [key, r] of Object.entries(roster)) {
    if (Number(key) < 3 || !r.A || !(r.I || rosterTeam(r.A))) continue;
    players.push({
      id: "p" + key,
      name: clean(r.A),
      email: (r.B || "").toLowerCase(),
      contactEmail: r.B || "",
      phone: r.D || "",
      team: r.I || rosterTeam(r.A) || "SUBS",
      rank: r.J || "",
      captain: r.G === "Y",
      paid: r.U === "1",
      shirt: r.S === "Y",
      hat: r.T === "Y",
      shirtPaid: r.V === "1",
      hatPaid: r.W === "1",
      shareContact: false,
      availability: Object.fromEntries(
        [..."KLMNOPQR"].map((c, i) => [
          String(i + 1),
          ({ Y: "yes", N: "no", M: "maybe" } as Record<string, string>)[
            r[c]?.toUpperCase()
          ] || "unknown",
        ]),
      ),
    });
  }
  const date = (v: string) =>
    v && Number.isFinite(Number(v))
      ? new Date(Date.UTC(1899, 11, 30) + Number(v) * 86400000)
          .toISOString()
          .slice(0, 10)
      : "";
  const teams = Object.entries(sheets.Config)
    .filter(([k, r]) => k !== "1" && r.A && r.A !== "SUBS")
    .map(([, r]) => r.A);
  const weeks: Season["weeks"] = [],
    matches: Season["matches"] = [];
  for (let i = 0; i < 8; i++) {
    const key =
        i < 6
          ? `Week ${i + 1} Entry`
          : i === 6
            ? "Semis Entry"
            : "Finals Entry",
      rows = sheets[key];
    if (!rows) throw new Error(`Missing tab: ${key}`);
    weeks.push({
      id: i + 1,
      label: i < 6 ? `Week ${i + 1}` : i === 6 ? "Semifinals" : "Finals",
      date: date(roster["2"]?.["KLMNOPQR"[i]] || rows["2"]?.B || ""),
      time: "",
      venue: "",
    });
    for (let j = 0; j < 2; j++) {
      const sched =
        Object.values(sheets.Schedule).find(
          (r) => Number(r.A) === i + 1 && Number(r.B) === j + 1,
        ) || {};
      const lines = Array.from({ length: 5 }, (_, l) => {
        const r = rows[String((j === 0 ? 6 : 15) + l)] || {};
        const score = (c: string) =>
          r[c] !== undefined && Number.isFinite(Number(r[c]))
            ? Number(r[c])
            : null;
        return {
          line: l + 1,
          a: [r.B || "", r.C || "", r.D || ""].map(clean),
          b: [r.E || "", r.F || "", r.G || ""].map(clean),
          scores: [
            ["H", "I"],
            ["J", "K"],
            ["L", "M"],
          ].map(([a, b]) => [score(a), score(b)]),
        };
      });
      matches.push({
        id: `w${i + 1}-m${j + 1}`,
        week: i + 1,
        a: sched.C || "TBD",
        b: sched.D || "TBD",
        lines,
      });
    }
  }
  for (const [k, r] of Object.entries(sheets.Roster || {})) {
    if (k === "1" || !r.A || players.some((p) => p.name === clean(r.A)))
      continue;
    players.push({
      id: "r" + k,
      name: clean(r.A),
      team: r.B || "SUBS",
      rank: "",
      captain: false,
      availability: {},
    });
  }
  for (const m of matches)
    for (const l of m.lines)
      for (const n of [...l.a, ...l.b])
        if (n && !players.some((p) => p.name === n))
          players.push({
            id: "s" + players.length,
            name: n,
            team: "SUBS",
            rank: "",
            captain: false,
            availability: {},
          });
  if (!players.length || teams.length !== 4)
    throw new Error(
      "Expected a four-team DPC workbook with a populated roster.",
    );
  return {
    id: name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "")
      .slice(0, 60),
    name,
    teams,
    weeks,
    matches,
    players,
    announcements: [],
    rules:
      "Imported season. The organizer can add the rules and format for this season.",
    fee: 50,
    paymentUrl: "",
  };
}

function historicalWorkbook(
  sheets: Record<string, Record<string, Record<string, string>>>,
  name: string,
): Season {
  const standingsRows = sheets["SEASON STANDINGS"],
    roster = sheets.Roster;
  if (!standingsRows || !roster)
    throw new Error("The workbook needs Roster and SEASON STANDINGS tabs.");
  const clean = (v: string) => v.trim(),
    num = (v: string | undefined) =>
      v !== undefined && v !== "" && Number.isFinite(Number(v))
        ? Number(v)
        : null;
  const teams = Object.entries(standingsRows)
    .filter(([k, r]) => k !== "1" && r.A)
    .map(([, r]) => r.A.trim());
  const players: Player[] = [],
    weeks: Season["weeks"] = [],
    matches: Season["matches"] = [];
  for (const [k, r] of Object.entries(roster)) {
    if (
      k === "1" ||
      !r.A ||
      ![...teams, "SUBS"].includes(r.B) ||
      players.some((p) => p.name === clean(r.A))
    )
      continue;
    players.push({
      id: "p" + k,
      name: clean(r.A),
      team: r.B,
      rank: (r.C || "").replace(".0", ""),
      captain: false,
      availability: {},
    });
  }
  const warnings = [
    "Standings and player statistics preserve reported workbook values, including playoffs. Elo is calculated separately from valid game scores. Player names are kept as written.",
  ];
  let week = 0;
  for (const [tab, rows] of Object.entries(sheets)) {
    if (!tab.endsWith("Entry")) continue;
    week++;
    const serial = num(rows["2"]?.B);
    if (serial == null) throw new Error(`No valid date on ${tab}.`);
    weeks.push({
      id: week,
      label: tab
        .replace(" Entry", "")
        .replace("Semi-Finals", "Semifinals")
        .replace("Semis", "Semifinals"),
      date: new Date(Date.UTC(1899, 11, 30) + serial * 86400000)
        .toISOString()
        .slice(0, 10),
      time: "",
      venue: "",
    });
    let mi = 0;
    for (const [key, header] of Object.entries(rows)) {
      if (header.A !== "Line") continue;
      const h = Number(key),
        cols = Object.fromEntries(
          Object.entries(header).map(([k, v]) => [v, k]),
        ),
        teamRow = rows[String(h - 1)];
      if (!teamRow?.B || !teamRow?.E) continue;
      mi++;
      const lines: Season["matches"][number]["lines"] = [];
      let r = h + 1;
      while (
        [
          "A",
          "B",
          "C",
          "D",
          "1.0",
          "2.0",
          "3.0",
          "4.0",
          "5.0",
          "1",
          "2",
          "3",
          "4",
          "5",
        ].includes(rows[String(r)]?.A)
      ) {
        const row = rows[String(r)],
          side = (keys: string[]) => keys.map((k) => clean(row[cols[k]] || ""));
        const a = side(["A P1", "A P2", "A P3/Sub"]),
          b = side(["B P1", "B P2", "B P3/Sub"]);
        const scores = [1, 2, 3]
          .filter((g) => cols[`G${g} A`])
          .map((g) => [num(row[cols[`G${g} A`]]), num(row[cols[`G${g} B`]])]);
        if (!scores.length)
          throw new Error(`Score columns could not be read on ${tab}.`);
        lines.push({ line: lines.length + 1, a, b, scores });
        for (const n of [...a, ...b])
          if (n && !players.some((p) => p.name === n))
            players.push({
              id: "extra" + players.length,
              name: n,
              team: "SUBS",
              rank: "",
              captain: false,
              availability: {},
            });
        r++;
      }
      const total = rows[String(r)] || {},
        a = num(total[cols["A Line Pts"]]),
        b = num(total[cols["B Line Pts"]]);
      if (!lines.length) continue;
      matches.push({
        id: `w${week}-m${mi}`,
        week,
        a: teamRow.B.trim(),
        b: teamRow.E.trim(),
        lines,
        reported: a != null && b != null ? { a, b } : null,
        sweepBonus: lines[0].scores.length === 3 ? 1 : 0,
      });
    }
  }
  const snapshotStandings = Object.entries(standingsRows)
    .filter(([k, r]) => k !== "1" && r.A)
    .map(([, r]) => ({
      team: r.A.trim(),
      wins: num(r.C) || 0,
      losses: num(r.D) || 0,
      ties: num(r.E) || 0,
      pf: num(r.F) || 0,
      pa: num(r.G) || 0,
      diff: num(r.H) || 0,
    }));
  const leaderboard = sheets["Player Leaderboard"];
  if (!leaderboard) throw new Error("Player Leaderboard is missing.");
  const cols = Object.fromEntries(
    Object.entries(leaderboard["1"]).map(([k, v]) => [v, k]),
  );
  const snapshotStats = Object.entries(leaderboard)
    .filter(
      ([k, r]) => k !== "1" && players.some((p) => p.name === clean(r.A || "")),
    )
    .map(([, r]) => {
      const id = players.find((p) => p.name === clean(r.A))!.id;
      const wins = num(r[cols["Games Won"]]) || 0,
        losses = num(r[cols["Games Lost"]]) || 0;
      return {
        id,
        wins,
        losses,
        games: cols["Games Played"]
          ? num(r[cols["Games Played"]]) || 0
          : wins + losses,
        winPct: num(r[cols["Win %"]]) || 0,
        bonus: num(r[cols.Sweeps]) || 0,
        points: num(r[cols.Points]) || 0,
      };
    });
  if (!matches.length || !players.length)
    throw new Error("No completed league data was found.");
  if (snapshotStats.some((p) => p.games !== p.wins + p.losses))
    warnings.push(
      "Some games-played values do not equal wins plus losses. Original values are preserved.",
    );
  return {
    id: name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "")
      .slice(0, 60),
    name,
    archived: true,
    teams,
    weeks,
    matches,
    players,
    snapshotStandings,
    snapshotStats,
    importWarnings: warnings,
    announcements: [],
    rules:
      "Archived season: four lines per matchup, with a one-point bonus for three-game sweeps. Original reported standings and statistics are preserved. Individual scorecards retain the original game count.",
    fee: null,
    paymentUrl: "",
  };
}
