import eloAliases from "./elo-aliases.json";
export type Line = {
  line: number;
  a: string[];
  b: string[];
  scores: (number | null)[][];
};
export type Match = {
  reported?: { a: number; b: number } | null;
  sweepBonus?: number;
  id: string;
  week: number;
  a: string;
  b: string;
  lines: Line[];
};
export type CareerRecord = {
  wins: number;
  losses: number;
  ties: number;
  games: number;
  winRate: number;
};
export type Player = {
  lifetime?: CareerRecord;
  excludeFromRankings?: boolean;
  elo?: number;
  ratedGames?: number;
  id: string;
  name: string;
  email?: string;
  contactEmail?: string;
  phone?: string;
  team: string;
  rank: string;
  captain: boolean;
  paid?: boolean;
  shirt?: boolean;
  hat?: boolean;
  shirtPaid?: boolean;
  hatPaid?: boolean;
  shareContact?: boolean;
  availability?: Record<string, string>;
};
export type Season = {
  eloNotes?: string[];
  archived?: boolean;
  importWarnings?: string[];
  snapshotStandings?: {
    team: string;
    wins: number;
    losses: number;
    ties: number;
    pf: number;
    pa: number;
    diff: number;
  }[];
  snapshotStats?: {
    id: string;
    games: number;
    wins: number;
    losses: number;
    winPct: number;
    bonus: number;
    points: number;
  }[];
  id: string;
  name: string;
  teams: string[];
  weeks: {
    id: number;
    label: string;
    date: string;
    time: string;
    venue: string;
  }[];
  matches: Match[];
  players: Player[];
  announcements: { id: string; title: string; body: string; date: string }[];
  rules: string;
  fee: number | null;
  paymentUrl: string;
  canceledDates?: string[];
  revision?: number;
};
export function matchResult(m: Match) {
  let a = 0,
    b = 0,
    games = 0;
  for (const line of m.lines) {
    let aw = 0,
      bw = 0;
    for (const [x, y] of line.scores) {
      if (x == null || y == null || (x === 0 && y === 0)) continue;
      if (x === y) {
        if (m.sweepBonus === undefined) continue;
        aw += 0.5;
        bw += 0.5;
      } else if (x > y) aw++;
      else bw++;
      games++;
    }
    a += aw + (aw === 3 ? (m.sweepBonus ?? 0.5) : 0);
    b += bw + (bw === 3 ? (m.sweepBonus ?? 0.5) : 0);
  }
  if (m.reported)
    return { a: m.reported.a, b: m.reported.b, games, complete: true };
  return {
    a,
    b,
    games,
    complete:
      games === m.lines.reduce((n, l) => n + l.scores.length, 0) && games > 0,
  };
}
export function standings(s: Season) {
  if (s.snapshotStandings)
    return [...s.snapshotStandings].sort(
      (a, b) => b.wins - a.wins || b.diff - a.diff,
    );
  return s.teams
    .map((team) => {
      let wins = 0,
        losses = 0,
        ties = 0,
        pf = 0,
        pa = 0;
      for (const m of s.matches.filter(
        (m) => m.week <= 6 && (m.a === team || m.b === team),
      )) {
        const r = matchResult(m);
        if (!r.complete) continue;
        const x = m.a === team ? r.a : r.b,
          y = m.a === team ? r.b : r.a;
        pf += x;
        pa += y;
        if (x > y) wins++;
        else if (x < y) losses++;
        else ties++;
      }
      return { team, wins, losses, ties, pf, pa, diff: pf - pa };
    })
    .sort(
      (a, b) =>
        b.wins - a.wins || b.diff - a.diff || a.team.localeCompare(b.team),
    );
}
export function stats(s: Season) {
  if (s.snapshotStats)
    return s.players
      .map((p) => ({
        ...p,
        games: 0,
        wins: 0,
        losses: 0,
        bonus: 0,
        points: 0,
        winPct: 0,
        ...s.snapshotStats!.find((x) => x.id === p.id),
      }))
      .sort(
        (a, b) =>
          b.points - a.points ||
          b.winPct - a.winPct ||
          a.name.localeCompare(b.name),
      );
  const players = new Map(
    s.players.map((p) => [
      p.name,
      { ...p, games: 0, wins: 0, losses: 0, bonus: 0, points: 0, winPct: 0 },
    ]),
  );
  for (const m of s.matches) {
    if (!matchResult(m).complete) continue;
    for (const l of m.lines) {
      const aw = l.scores.filter(([a, b]) => a! > b!).length;
      for (let g = 0; g < 3; g++) {
        for (const side of ["a", "b"] as const) {
          const names = l[side],
            three = !!names[2],
            idx = three
              ? [
                  [0, 1],
                  [0, 2],
                  [1, 2],
                ][g]
              : [0, 1];
          for (const i of idx) {
            const p = players.get(names[i]);
            if (!p) continue;
            const won =
              side === "a"
                ? l.scores[g][0]! > l.scores[g][1]!
                : l.scores[g][1]! > l.scores[g][0]!;
            p.games++;
            if (won) p.wins++;
            else p.losses++;
            if (
              g === 2 &&
              ((side === "a" && aw === 3) || (side === "b" && aw === 0))
            )
              p.bonus += 0.5;
          }
        }
      }
    }
  }
  return [...players.values()]
    .map((p) => ({
      ...p,
      points: p.wins + p.bonus,
      winPct: p.games ? p.wins / p.games : 0,
    }))
    .sort(
      (a, b) =>
        b.points - a.points ||
        b.winPct - a.winPct ||
        a.name.localeCompare(b.name),
    );
}
export const money = (n: number) =>
  new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0,
  }).format(n);
export function bill(p: Player) {
  const due = 50 + (p.shirt ? 30 : 0) + (p.hat ? 35 : 0);
  const paid =
    (p.paid ? 50 : 0) +
    (p.shirt && p.shirtPaid ? 30 : 0) +
    (p.hat && p.hatPaid ? 35 : 0);
  return { due, paid, balance: due - paid };
}

/** Ratings carry between seasons; historical views stop at the selected season's end.
 * Abbreviations are linked only through an audited alias map. Ambiguous names stay separate. */
function eloName(name: string) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, "")
    .trim()
    .replace(/\s+/g, " ")
    .replace(/^matthew /, "matt ")
    .replace("ryan mcclagan", "ryan mclagan")
    .replace("stepehen walsh", "stephen walsh");
}
export function eloIdentity(s: Season, name: string) {
  const n = eloName(name);
  const alias = (eloAliases as Record<string, string>)[s.id + "|" + n];
  if (alias) return alias;
  const parts = n.split(" ");
  return parts.length < 2 || parts.at(-1)!.length < 2 ? s.id + "|" + n : n;
}
export function eloHistory(s: Season, history: Season[] = [s], asOf?: string) {
  const all = [...new Map([...history, s].map((x) => [x.id, x])).values()];
  const dates = (season: Season) =>
    season.weeks
      .map((w) => w.date)
      .filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d))
      .sort();
  const cutoff = asOf ?? (dates(s).at(-1) || "");
  const ratings = new Map<string, { elo: number; ratedGames: number }>();
  const notes = new Set<string>();
  const eligible = all
    .filter((season) => dates(season)[0] && dates(season)[0] <= cutoff)
    .sort(
      (a, b) =>
        dates(a)[0].localeCompare(dates(b)[0]) || a.id.localeCompare(b.id),
    );
  const events = eligible
    .flatMap((season) =>
      season.matches.map((m) => ({
        season,
        m,
        date: season.weeks.find((w) => w.id === m.week)?.date || "",
      })),
    )
    .filter((e) => e.date && e.date <= cutoff)
    .sort(
      (a, b) =>
        a.date.localeCompare(b.date) ||
        a.season.id.localeCompare(b.season.id) ||
        a.m.week - b.m.week ||
        a.m.id.localeCompare(b.m.id),
    );
  // Seed once from the earliest roster. Never use a later season's draft to rewrite history.
  for (const season of eligible) {
    const lineCount = Math.max(1, ...season.matches.map((m) => m.lines.length));
    for (const player of season.players) {
      const key = eloIdentity(season, player.name);
      if (ratings.has(key)) continue;
      const rank = String(player.rank || "")
        .trim()
        .toUpperCase();
      let tier = /^[A-D]$/.test(rank)
        ? rank.charCodeAt(0) - 64
        : /^[1-5][A-C]?$/.test(rank)
          ? Number(rank[0])
          : 0;
      if (tier < 1 || tier > lineCount) tier = 0;
      if (!tier) {
        for (const event of events.filter(
          (e) => e.season.id === season.id && matchResult(e.m).complete,
        )) {
          const line = [...event.m.lines]
            .sort((a, b) => a.line - b.line)
            .find((l) =>
              [...l.a, ...l.b].some((n) => n && eloIdentity(season, n) === key),
            );
          if (line) {
            tier = line.line;
            break;
          }
        }
      }
      ratings.set(key, {
        elo: tier ? 1500 + 100 * ((lineCount + 1) / 2 - tier) : 1500,
        ratedGames: 0,
      });
    }
  }
  for (const { season, m } of events) {
    if (!matchResult(m).complete) continue;
    for (const l of [...m.lines].sort((a, b) => a.line - b.line))
      for (let game = 0; game < l.scores.length; game++) {
        const [scoreA, scoreB] = l.scores[game];
        if (
          scoreA == null ||
          scoreB == null ||
          !Number.isFinite(scoreA) ||
          !Number.isFinite(scoreB) ||
          scoreA < 0 ||
          scoreB < 0 ||
          (scoreA === 0 && scoreB === 0)
        )
          continue;
        const pair = (names: string[]) => {
          const slots = names[2]
            ? [
                [0, 1],
                [0, 2],
                [1, 2],
              ][game]
            : [0, 1];
          return (slots || []).map((i) => eloIdentity(season, names[i] || ""));
        };
        const aKeys = pair(l.a),
          bKeys = pair(l.b),
          keys = [...aKeys, ...bKeys];
        if (
          aKeys.length !== 2 ||
          bKeys.length !== 2 ||
          new Set(keys).size !== 4 ||
          keys.some((k) => !ratings.has(k))
        )
          continue;
        for (const key of keys)
          if (key.includes("|"))
            notes.add(season.name + ": " + key.split("|")[1]);
        const a = aKeys.map((k) => ratings.get(k)!),
          b = bKeys.map((k) => ratings.get(k)!);
        const expected =
          1 /
          (1 + 10 ** ((b[0].elo + b[1].elo - a[0].elo - a[1].elo) / 2 / 400));
        const delta =
          24 * ((scoreA === scoreB ? 0.5 : scoreA > scoreB ? 1 : 0) - expected);
        for (const p of a) {
          p.elo += delta;
          p.ratedGames++;
        }
        for (const p of b) {
          p.elo -= delta;
          p.ratedGames++;
        }
      }
  }
  return {
    ratings: Object.fromEntries(
      s.players.map((p) => [
        p.id,
        {
          ...(ratings.get(eloIdentity(s, p.name)) || {
            elo: 1500,
            ratedGames: 0,
          }),
        },
      ]),
    ),
    notes: [...notes].sort(),
  };
}
export function eloRatings(s: Season, history: Season[] = [s]) {
  return eloHistory(s, history).ratings;
}

/** Career records use actual completed game scorecards, not inconsistent workbook summaries. */
export function lifetimeRecords(
  selected: Season,
  history: Season[] = [selected],
) {
  const seasons = [
    ...new Map([...history, selected].map((s) => [s.id, s])).values(),
  ];
  const records = new Map<string, CareerRecord>();
  for (const season of seasons)
    for (const m of season.matches) {
      if (!matchResult(m).complete) continue;
      for (const line of m.lines)
        for (let game = 0; game < line.scores.length; game++) {
          const [a, b] = line.scores[game];
          if (
            a == null ||
            b == null ||
            !Number.isFinite(a) ||
            !Number.isFinite(b) ||
            a < 0 ||
            b < 0 ||
            (a === 0 && b === 0)
          )
            continue;
          const pairs = (["a", "b"] as const).map((side) => {
            const names = line[side],
              slots = names[2]
                ? [
                    [0, 1],
                    [0, 2],
                    [1, 2],
                  ][game]
                : [0, 1];
            return (slots || []).map((i) =>
              names[i] ? eloIdentity(season, names[i]) : "",
            );
          });
          const keys = pairs.flat();
          if (
            keys.length !== 4 ||
            keys.some((k) => !k) ||
            new Set(keys).size !== 4
          )
            continue;
          for (let side = 0; side < 2; side++)
            for (const key of pairs[side]) {
              const record = records.get(key) || {
                wins: 0,
                losses: 0,
                ties: 0,
                games: 0,
                winRate: 0,
              };
              record.games++;
              if (a === b) record.ties++;
              else if (side === 0 ? a > b : b > a) record.wins++;
              else record.losses++;
              record.winRate = record.wins / record.games;
              records.set(key, record);
            }
        }
    }
  return Object.fromEntries(
    selected.players.map((p) => [
      p.id,
      records.get(eloIdentity(selected, p.name)) || {
        wins: 0,
        losses: 0,
        ties: 0,
        games: 0,
        winRate: 0,
      },
    ]),
  );
}
