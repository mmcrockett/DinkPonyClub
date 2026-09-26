import { leagueFetch } from "./request";
("use client");
import { useEffect, useState, FormEvent } from "react";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from "@/components/ui/table";
import { Checkbox } from "@/components/ui/checkbox";
import { Toaster, toast } from "sonner";
import {
  CalendarDays,
  Trophy,
  Users,
  Megaphone,
  BookOpen,
  Wallet,
  ArrowUpRight,
  Check,
  Minus,
  Plus,
  Upload,
  BarChart3,
  Clock,
  MapPin,
} from "lucide-react";
import {
  Season,
  Match,
  Player,
  standings,
  stats,
  matchResult,
  bill,
  money,
} from "@/lib/model";
import Photos from "./photos";
import { importWorkbook } from "@/lib/import-workbook";
const sections = [
  ["Schedule", CalendarDays],
  ["Standings", Trophy],
  ["Season stats", BarChart3],
  ["Players", Users],
  ["Photos", Users],
  ["Announcements", Megaphone],
  ["Fees", Wallet],
  ["Rules & format", BookOpen],
] as const;
const availLabels: Record<string, string> = {
  yes: "I’m in",
  no: "I’m out",
  maybe: "Maybe",
  unknown: "Not set",
};
function Picker({
  value,
  onChange,
  options,
  label,
  disabled = false,
}: {
  disabled?: boolean;
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
  label: string;
}) {
  return (
    <Select
      disabled={disabled}
      value={value || "_none"}
      onValueChange={(v) => onChange(v === "_none" ? "" : v)}
    >
      <SelectTrigger aria-label={label}>
        <SelectValue placeholder={label} />
      </SelectTrigger>
      <SelectContent>
        {options.map((o) => (
          <SelectItem key={o.value || "_none"} value={o.value || "_none"}>
            {o.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
function CheckField({
  label,
  value,
  change,
}: {
  label: string;
  value: boolean;
  change: (v: boolean) => void;
}) {
  return (
    <label className="check-field">
      <Checkbox checked={value} onCheckedChange={(v) => change(v === true)} />
      {label}
    </label>
  );
}
function statsRank(rank?: string) {
  const value = (rank || "").trim().toUpperCase();
  if (/^[A-D]$/.test(value)) return String(value.charCodeAt(0) - 64);
  return /^[1-5][A-C]?$/.test(value) ? value[0] : "";
}
function teamInitials(name: string) {
  return name === "TBD"
    ? "?"
    : name
        .split(/[ ,]+/)
        .map((x) => x[0])
        .slice(0, 3)
        .join("");
}
const teamLogos: Record<string, string> = {
  "Net Gainz": "net-gainz",
  "Soft Serves": "soft-serves",
  "Big Dink Energy": "big-dink-energy",
  "Old Balls, New Flicks": "old-balls-new-flicks",
};
function TeamBadge({ team }: { team: string }) {
  const logo = teamLogos[team];
  return logo ? (
    <img
      className="schedule-team-logo"
      src={"/clubhouse-images/team-logos/" + logo + ".png"}
      alt={team + " logo"}
      loading="lazy"
    />
  ) : (
    <span className="team-badge">{teamInitials(team)}</span>
  );
}
export default function League() {
  const [tab, setTab] = useState("Schedule"),
    [lifetimeView, setLifetimeView] = useState(false),
    [lifetimePlayers, setLifetimePlayers] = useState<Player[]>([]),
    [s, setS] = useState<Season | null>(null),
    [seasonId, setSeasonId] = useState("fall-2026"),
    [seasons, setSeasons] = useState<{ id: string; name: string }[]>([]),
    [admin, setAdmin] = useState(false),
    [captain, setCaptain] = useState(false),
    [privateAccess, setPrivateAccess] = useState(false),
    [local, setLocal] = useState(false),
    [playerId, setPlayerId] = useState(""),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false),
    [modal, setModal] = useState(""),
    [draft, setDraft] = useState<any>({}),
    [search, setSearch] = useState(""),
    [team, setTeam] = useState("all"),
    [playerSort, setPlayerSort] = useState("name"),
    [hideSubs, setHideSubs] = useState(false),
    [draftRank, setDraftRank] = useState("all"),
    [availabilityView, setAvailabilityView] = useState(false),
    [summaryWeek, setSummaryWeek] = useState(""),
    [formError, setFormError] = useState(""),
    [upload, setUpload] = useState<Season | null>(null);
  async function load(id = seasonId) {
    try {
      const r = await leagueFetch(
        "/clubhouse/api/league?season=" + encodeURIComponent(id),
      );
      const data: any = await r.json();
      if (!r.ok) throw new Error(data.error);
      setS(data.season);
      setLifetimePlayers(data.lifetimePlayers || []);
      setSeasons(data.seasons);
      setAdmin(data.admin);
      setCaptain(data.captain);
      setPrivateAccess(data.privateAccess);
      setLocal(data.local);
      setPlayerId(data.playerId || "");
      setError("");
    } catch (e) {
      setError((e as Error).message);
    }
  }
  useEffect(() => {
    setSummaryWeek("");
    setDraftRank("all");
    setTeam("all");
    load(seasonId);
  }, [seasonId]);
  async function save(action: string, data: any, close = true) {
    if (!s) return false;
    setBusy(true);
    setFormError("");
    try {
      const r = await leagueFetch("/clubhouse/api/league", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action,
          seasonId,
          revision: s.revision,
          ...data,
        }),
      });
      const res: any = await r.json();
      if (!r.ok) {
        if (r.status === 409) await load();
        throw new Error(res.error);
      }
      if (res.seasonId) {
        setSeasonId(res.seasonId);
        await load(res.seasonId);
      } else await load();
      if (close) setModal("");
      toast.success(
        action === "result"
          ? "Results posted. Standings and stats updated."
          : "Saved to the league.",
      );
      return true;
    } catch (e) {
      setFormError((e as Error).message);
      toast.error((e as Error).message);
      return false;
    } finally {
      setBusy(false);
    }
  }
  function open(kind: string, data: any = {}) {
    if (kind === "result" && !captain) return;
    setDraft(structuredClone(data));
    setFormError("");
    setModal(kind);
    setUpload(null);
  }
  useEffect(() => {
    const context = (navigator as any).modelContext;
    if (!context || !s) return;
    context.registerTool({
      name: "get_league_schedule",
      description:
        "Read the signed-in league season schedule and match results.",
      inputSchema: { type: "object", properties: {} },
      annotations: { readOnlyHint: true },
      execute: async () => ({
        content: [
          {
            type: "text",
            text: JSON.stringify({
              season: s.name,
              weeks: s.weeks,
              matches: s.matches,
            }),
          },
        ],
      }),
    });
    context.registerTool({
      name: "set_my_availability",
      description:
        "Save availability for the signed-in player and a scheduled week. Status is yes, no, or maybe.",
      inputSchema: {
        type: "object",
        properties: {
          week: { type: "integer" },
          status: { type: "string", enum: ["yes", "no", "maybe"] },
        },
        required: ["week", "status"],
      },
      execute: async ({ week, status }: { week: number; status: string }) => ({
        content: [
          {
            type: "text",
            text: (await save(
              "availability",
              { playerId, week, value: status },
              false,
            ))
              ? "Availability saved."
              : "Availability was not saved.",
          },
        ],
      }),
    });
    return () => {
      context.unregisterTool("get_league_schedule");
      context.unregisterTool("set_my_availability");
    };
  }, [s, playerId]);
  const selected = s?.players.find((p) => p.id === playerId),
    table = s ? standings(s) : [],
    leaderboard =
      tab === "Season stats" && lifetimeView
        ? lifetimePlayers.map((p) => ({
            ...p,
            games: p.lifetime?.games || 0,
            wins: p.lifetime?.wins || 0,
            losses: p.lifetime?.losses || 0,
            winPct: p.lifetime?.winRate || 0,
            bonus: 0,
            points: 0,
          }))
        : s
          ? stats(s)
          : [],
    completed = s?.matches.filter((m) => matchResult(m).complete).length || 0;
  const filtered = leaderboard.filter(
    (p) =>
      (!["Players", "Season stats"].includes(tab) ||
        ((!hideSubs || p.team !== "SUBS") &&
          (!privateAccess ||
            draftRank === "all" ||
            ((tab === "Season stats" ? statsRank(p.rank) : p.rank) ||
              "_unranked") === draftRank))) &&
      (tab !== "Season stats" || !p.excludeFromRankings) &&
      (team === "all" || p.team === team) &&
      p.name.toLowerCase().includes(search.toLowerCase()),
  );
  const sortedPlayers = [...filtered].sort((a, b) => {
    const byName = a.name.localeCompare(b.name, undefined, {
      sensitivity: "base",
    });
    if (playerSort === "elo" && privateAccess) {
      const aElo = a.excludeFromRankings
          ? Number.NEGATIVE_INFINITY
          : (a.elo ?? 1500),
        bElo = b.excludeFromRankings
          ? Number.NEGATIVE_INFINITY
          : (b.elo ?? 1500);
      return bElo - aElo || byName;
    }
    if (playerSort === "win-desc" || playerSort === "win-asc") {
      if (!a.games || !b.games)
        return Number(!!b.games) - Number(!!a.games) || byName;
      return (
        (playerSort === "win-desc"
          ? b.winPct - a.winPct
          : a.winPct - b.winPct) ||
        b.games - a.games ||
        byName
      );
    }
    if (playerSort === "team") return a.team.localeCompare(b.team) || byName;
    return byName;
  });
  const upcoming =
    s?.weeks.find((w) => w.date >= new Date().toLocaleDateString("en-CA")) ||
    s?.weeks.find((w) =>
      s.matches.some((m) => m.week === w.id && !matchResult(m).complete),
    );
  const shownWeek =
    s?.weeks.find((w) => String(w.id) === summaryWeek) ||
    upcoming ||
    s?.weeks[0];
  const weeksCompleted = s
    ? [
        ...new Set(
          s.weeks
            .map((w) => w.date)
            .filter((date) => date && !s.canceledDates?.includes(date)),
        ),
      ].filter((date) => {
        const ids = new Set(
          s.weeks.filter((w) => w.date === date).map((w) => w.id),
        );
        const matches = s.matches.filter((m) => ids.has(m.week));
        return (
          matches.length > 0 && matches.every((m) => matchResult(m).complete)
        );
      }).length
    : 0;
  const playerOptions =
    s?.players.map((p) => ({ value: p.id, label: p.name })) || [];
  const activePlayers = s?.players.filter((p) => p.team !== "SUBS") || [];
  return (
    <div>
      <Toaster position="bottom-right" richColors />
      <header>
        <a className="brand" href="/">
          <img
            src="/clubhouse-images/logo.png"
            alt="Dink Pony Club logo"
            className="club-logo"
          />
          <span>
            DINK PONY
            <br />
            CLUB
          </span>
        </a>
        <div className="season-tag">
          THE CLUBHOUSE<span>Pickleball draft league</span>
        </div>
        <div className="header-actions">
          {s && (
            <Picker
              label="Season"
              value={seasonId}
              onChange={(v) => {
                setLifetimeView(false);
                setSeasonId(v);
                if (tab !== "Season stats") setTab("Schedule");
              }}
              options={seasons.map((s) => ({ value: s.id, label: s.name }))}
            />
          )}
          <button
            className="profile-button"
            onClick={() => s && open("profile", selected)}
            disabled={!s || s.archived || !selected}
          >
            My profile <ArrowUpRight size={16} />
          </button>
        </div>
      </header>
      <main>
        <figure className="lineup-poster club-banner">
          <a
            href="/clubhouse-images/fall-2026-lineups.png"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="Open the Fall 2026 team lineups at full size"
          >
            <img
              src="/clubhouse-images/fall-2026-lineups.png"
              alt="Dink Pony Club Fall 2026 drafted teams: Old Balls, New Flicks; Soft Serves; Net Gainz; and Big Dink Energy."
              fetchPriority="high"
            />
          </a>
          <figcaption>
            Fall 2026 · Four teams. 48 players. One champion.{" "}
            <a
              href="/clubhouse-images/fall-2026-lineups.png"
              target="_blank"
              rel="noopener noreferrer"
            >
              View full-size lineups ↗
            </a>
          </figcaption>
        </figure>
        {local && (
          <div className="preview-note">
            Organizer preview · Changes are saved on this computer. Player
            sign-in will be available after launch.
          </div>
        )}
        {error && (
          <div className="error-banner" role="alert">
            {error} <button onClick={() => load()}>Try again</button>
            {!s && (
              <a href="/" target="_top">
                Return to Google sign-in
              </a>
            )}
          </div>
        )}
        {!s ? (
          <div className="loading">
            {error
              ? "The league could not be loaded."
              : "Loading the clubhouse…"}
          </div>
        ) : (
          <Tabs
            value={tab}
            onValueChange={(v) => {
              setTab(v);
              setSearch("");
              setTeam("all");
              setDraftRank("all");
            }}
          >
            <TabsList className="main-tabs">
              {sections
                .filter(
                  ([name]) =>
                    !s.archived || !["Fees", "Announcements"].includes(name),
                )
                .map(([name, Icon]) => (
                  <TabsTrigger value={name} key={name}>
                    <Icon size={17} />
                    {name}
                  </TabsTrigger>
                ))}
            </TabsList>
            {s.archived && (
              <div className="info-panel archive-note">
                <h3>{s.name} archive</h3>
                {s.importWarnings?.map((note, i) => (
                  <p key={i}>{note}</p>
                ))}
              </div>
            )}
            <TabsContent value="Schedule">
              <div className="section-heading">
                <div>
                  <h2>The season schedule</h2>
                  <p>
                    {s.archived
                      ? "Preserved scorecards and reported results from this season."
                      : "Set your availability now. Update it whenever plans change."}
                  </p>
                </div>
                {!s.archived && (
                  <button
                    className="secondary"
                    onClick={() => setAvailabilityView(!availabilityView)}
                  >
                    {availabilityView ? "Show matchups" : "Team availability"}
                  </button>
                )}
              </div>
              {!s.archived && (
                <div className="availability-toolbar">
                  <span>Availability for</span>
                  <strong>
                    {selected?.name || "No roster profile for this sign-in"}
                  </strong>
                  <span className="muted">
                    Set availability for the full season.
                  </span>
                </div>
              )}
              <div className="schedule-layout">
                <section>
                  {s.canceledDates?.map((date) => (
                    <div className="calendar-notice" key={date}>
                      <CalendarDays size={17} />
                      <span>
                        <strong>
                          {new Date(date + "T12:00:00").toLocaleDateString(
                            "en-US",
                            { month: "long", day: "numeric" },
                          )}{" "}
                          · Canceled
                        </strong>{" "}
                        No league play on this date.
                      </span>
                    </div>
                  ))}
                  {s.weeks.map((w) => {
                    const matches = s.matches.filter((m) => m.week === w.id),
                      done = matches.every((m) => matchResult(m).complete),
                      status = selected?.availability?.[w.id] || "unknown";
                    return (
                      <article
                        className={`week-card ${upcoming?.id === w.id ? "next-week" : ""}`}
                        key={w.id}
                      >
                        <div className="week-title">
                          <div className="date-block">
                            <small>
                              {w.date
                                ? new Date(
                                    w.date + "T12:00:00",
                                  ).toLocaleDateString("en-US", {
                                    month: "short",
                                  })
                                : "TBD"}
                            </small>
                            <strong>{w.date.slice(-2) || "—"}</strong>
                          </div>
                          <div>
                            <h3>
                              {w.label}{" "}
                              {upcoming?.id === w.id && (
                                <span className="next-label">UP NEXT</span>
                              )}
                            </h3>
                            <span className="muted">
                              {w.time || "Time to be confirmed"}
                              {w.venue ? " · " + w.venue : ""}
                            </span>
                          </div>
                          {admin && !s.archived && (
                            <button
                              className="text-button"
                              onClick={() =>
                                open("schedule", { ...w, matches })
                              }
                            >
                              Edit
                            </button>
                          )}
                          <span className={`pill ${done ? "success" : ""}`}>
                            {done
                              ? "Final"
                              : /semi|final/i.test(w.label)
                                ? "Playoffs"
                                : "Scheduled"}
                          </span>
                        </div>
                        {availabilityView ? (
                          <div className="availability-grid">
                            {[
                              ...s.teams,
                              ...(s.players.some((p) => p.team === "SUBS")
                                ? ["SUBS"]
                                : []),
                            ].map((t) => {
                              const players = s.players.filter(
                                (p) => p.team === t,
                              );
                              return (
                                <div key={t}>
                                  <h4>{t}</h4>
                                  <p>
                                    {
                                      players.filter(
                                        (p) => p.availability?.[w.id] === "yes",
                                      ).length
                                    }{" "}
                                    in ·{" "}
                                    {
                                      players.filter(
                                        (p) =>
                                          p.availability?.[w.id] === "maybe",
                                      ).length
                                    }{" "}
                                    maybe
                                  </p>
                                  {players.map((p) => (
                                    <div
                                      className="availability-person"
                                      key={p.id}
                                    >
                                      <span>{p.name}</span>
                                      {captain && !s.archived ? (
                                        <Picker
                                          label={`${p.name} availability for ${w.label}`}
                                          disabled={busy}
                                          value={
                                            p.availability?.[w.id] || "unknown"
                                          }
                                          onChange={(value) =>
                                            save(
                                              "teamAvailability",
                                              {
                                                playerId: p.id,
                                                week: w.id,
                                                value,
                                              },
                                              false,
                                            )
                                          }
                                          options={[
                                            {
                                              value: "unknown",
                                              label: "Not set",
                                            },
                                            { value: "yes", label: "In" },
                                            { value: "maybe", label: "Maybe" },
                                            { value: "no", label: "Out" },
                                          ]}
                                        />
                                      ) : (
                                        <span
                                          className={
                                            "status-text " +
                                            (p.availability?.[w.id] ||
                                              "unknown")
                                          }
                                        >
                                          {
                                            (
                                              {
                                                yes: "In",
                                                no: "Out",
                                                maybe: "Maybe",
                                                unknown: "Not set",
                                              } as any
                                            )[
                                              p.availability?.[w.id] ||
                                                "unknown"
                                            ]
                                          }
                                        </span>
                                      )}
                                    </div>
                                  ))}
                                </div>
                              );
                            })}
                          </div>
                        ) : (
                          matches.map((m) => {
                            const result = matchResult(m);
                            return (
                              <div className="match-row" key={m.id}>
                                <div className="match-team">
                                  <TeamBadge team={m.a} />
                                  <span>{m.a}</span>
                                </div>
                                <div className="match-score">
                                  <div className="score-pair">
                                    {result.complete ? (
                                      <>
                                        <strong>{result.a}</strong>
                                        <span>–</span>
                                        <strong>{result.b}</strong>
                                      </>
                                    ) : (
                                      <span className="versus">vs</span>
                                    )}
                                  </div>
                                  {captain &&
                                    (result.complete || !s.archived) && (
                                      <button
                                        className="text-button result-button"
                                        onClick={() => open("result", m)}
                                      >
                                        {result.complete
                                          ? "Scorecard"
                                          : "Enter results"}
                                      </button>
                                    )}
                                </div>
                                <div className="match-team">
                                  <span>{m.b}</span>
                                  <TeamBadge team={m.b} />
                                </div>
                              </div>
                            );
                          })
                        )}
                        {!s.archived && (
                          <div className="availability-row">
                            <span>Are you playing?</span>
                            <div className="segmented">
                              {["yes", "maybe", "no"].map((v) => (
                                <button
                                  key={v}
                                  disabled={busy || !selected}
                                  aria-pressed={status === v}
                                  className={
                                    status === v ? "selected " + v : ""
                                  }
                                  onClick={() =>
                                    save(
                                      "availability",
                                      { playerId, week: w.id, value: v },
                                      false,
                                    )
                                  }
                                >
                                  {status === v && <Check size={13} />}{" "}
                                  {availLabels[v]}
                                </button>
                              ))}
                            </div>
                          </div>
                        )}
                      </article>
                    );
                  })}
                </section>
                <aside>
                  <div className="dark-card">
                    <div className="eyebrow">
                      {shownWeek?.label.toUpperCase() || "THE SEASON"}
                    </div>
                    <h2>
                      {s.archived ? (
                        <>
                          A season to
                          <br />
                          remember.
                        </>
                      ) : (
                        <>
                          Ready for
                          <br />
                          the next rally?
                        </>
                      )}
                    </h2>
                    {shownWeek && (
                      <>
                        <div className="week-picker">
                          <Picker
                            label="Week to show matchups"
                            value={String(shownWeek.id)}
                            onChange={setSummaryWeek}
                            options={s.weeks.map((w) => ({
                              value: String(w.id),
                              label: w.label,
                            }))}
                          />
                        </div>
                        <p>
                          {new Date(
                            shownWeek.date + "T12:00:00",
                          ).toLocaleDateString("en-US", {
                            weekday: "long",
                            month: "long",
                            day: "numeric",
                          })}
                        </p>
                      </>
                    )}
                    <div className="card-divider" />
                    <div className="sidebar-matchups">
                      <h3>Matchups</h3>
                      {s.matches
                        .filter((m) => m.week === shownWeek?.id)
                        .map((m) => (
                          <div className="sidebar-matchup" key={m.id}>
                            <div className="sidebar-team">
                              <TeamBadge team={m.a} />
                              <strong>{m.a}</strong>
                            </div>
                            <span>vs</span>
                            <div className="sidebar-team">
                              <TeamBadge team={m.b} />
                              <strong>{m.b}</strong>
                            </div>
                          </div>
                        ))}
                      {!s.matches.some((m) => m.week === shownWeek?.id) && (
                        <p>No matchups scheduled.</p>
                      )}
                    </div>
                    <div className="side-fact">
                      <span>Weeks completed</span>
                      <strong>{weeksCompleted}</strong>
                    </div>
                    <button onClick={() => setTab("Standings")}>
                      See the standings <ArrowUpRight size={16} />
                    </button>
                  </div>
                  {!s.archived && (
                    <div className="note-card">
                      <h3>From the captain’s corner</h3>
                      <p>
                        Keep your availability current so captains can set their
                        lines and find subs.
                      </p>
                      <div className="small-divider" />
                      <h3>Playoff night</h3>
                      <p>
                        Semifinals and finals share November 13. One
                        availability response applies to both rounds. Play is at
                        Sean O’Brien’s courts. Playoff start times will be
                        confirmed.
                      </p>
                    </div>
                  )}
                </aside>
              </div>
            </TabsContent>
            <TabsContent value="Standings">
              <div className="section-heading">
                <div>
                  <h2>The race for first.</h2>
                  <p>
                    {s.archived
                      ? "Imported standings · Includes playoffs · Original workbook values"
                      : "Regular season · Ranked by wins, then point differential."}
                  </p>
                </div>
                <span className="pill">
                  {
                    s.matches.filter(
                      (m) => m.week <= 6 && matchResult(m).complete,
                    ).length
                  }{" "}
                  results posted
                </span>
              </div>
              <div className="podium-cards">
                {table.slice(0, 3).map((t, i) => (
                  <div className={"podium podium-" + i} key={t.team}>
                    <span className="eyebrow">
                      {i === 0
                        ? "LEADING THE PACK"
                        : i === 1
                          ? "IN THE CHASE"
                          : "STILL IN THE MIX"}
                    </span>
                    <span className="podium-rank">0{i + 1}</span>
                    <h3>{t.team}</h3>
                    <div>
                      <strong>
                        {t.wins}–{t.losses}
                        {t.ties ? "–" + t.ties : ""}
                      </strong>
                      <span>
                        {t.diff > 0 ? "+" : ""}
                        {t.diff} point differential
                      </span>
                    </div>
                  </div>
                ))}
              </div>
              <div className="table-card">
                <Table>
                  <TableHeader>
                    <TableRow>
                      {[
                        "Rank",
                        "Team",
                        "Played",
                        "W",
                        "L",
                        "T",
                        "Points for",
                        "Points against",
                        "Diff",
                      ].map((h) => (
                        <TableHead key={h}>{h}</TableHead>
                      ))}
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {table.map((t, i) => (
                      <TableRow key={t.team}>
                        <TableCell>{i + 1}</TableCell>
                        <TableCell>
                          <strong>{t.team}</strong>
                        </TableCell>
                        <TableCell>{t.wins + t.losses + t.ties}</TableCell>
                        <TableCell>{t.wins}</TableCell>
                        <TableCell>{t.losses}</TableCell>
                        <TableCell>{t.ties}</TableCell>
                        <TableCell>{t.pf}</TableCell>
                        <TableCell>{t.pa}</TableCell>
                        <TableCell>
                          {t.diff > 0 ? "+" : ""}
                          {t.diff}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
              <p className="footnote">
                {s.archived
                  ? "Historical standings preserve the source totals. See import notes for scoring differences."
                  : "Every game win is one point; a three-game line sweep adds 0.5. Official tiebreakers and playoff seeding still need organizer confirmation."}
              </p>
            </TabsContent>
            <TabsContent value="Season stats">
              <div className="section-heading">
                <div>
                  <h2>Every game counts.</h2>
                  <p>
                    {lifetimeView
                      ? "Lifetime · All imported seasons, including playoffs. Team and draft rank use the latest roster entry."
                      : `${s.name} · Player records, including substitutes${s.archived ? " · Archived season" : ""}.`}
                  </p>
                </div>
                {admin && (
                  <button
                    className="secondary"
                    onClick={() => open("import", { name: "" })}
                  >
                    <Upload size={16} /> Import a season
                  </button>
                )}
              </div>
              <div className="filters">
                <Picker
                  label="Stats season"
                  value={lifetimeView ? "lifetime" : seasonId}
                  onChange={(v) => {
                    setSearch("");
                    setTeam("all");
                    setDraftRank("all");
                    setLifetimeView(v === "lifetime");
                    if (v !== "lifetime") setSeasonId(v);
                  }}
                  options={[
                    { value: "lifetime", label: "Lifetime" },
                    ...seasons.map((season) => ({
                      value: season.id,
                      label: season.name,
                    })),
                  ]}
                />
                <input
                  aria-label="Search player stats"
                  placeholder="Find a player…"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
                <Picker
                  label="Filter stats by team"
                  value={team}
                  onChange={setTeam}
                  options={[
                    { value: "all", label: "All teams" },
                    ...(lifetimeView
                      ? [
                          ...new Set(
                            lifetimePlayers
                              .map((p) => p.team)
                              .filter((t) => t !== "SUBS"),
                          ),
                        ].sort()
                      : s.teams
                    ).map((t) => ({ value: t, label: t })),
                    { value: "SUBS", label: "Substitutes" },
                  ]}
                />
                {privateAccess && (
                  <Picker
                    label="Filter stats by draft rank"
                    value={draftRank}
                    onChange={setDraftRank}
                    options={[
                      { value: "all", label: "All draft ranks" },
                      ...[
                        ...new Set(
                          (lifetimeView ? lifetimePlayers : s.players)
                            .map((p) => statsRank(p.rank))
                            .filter(Boolean),
                        ),
                      ]
                        .sort((a, b) =>
                          a.localeCompare(b, undefined, { numeric: true }),
                        )
                        .map((rank) => ({ value: rank, label: rank })),
                      { value: "_unranked", label: "Unranked" },
                    ]}
                  />
                )}
                <CheckField
                  label="Hide substitutes"
                  value={hideSubs}
                  change={setHideSubs}
                />
                <Picker
                  label="Sort stats"
                  value={
                    playerSort === "elo" && !privateAccess ? "name" : playerSort
                  }
                  onChange={setPlayerSort}
                  options={[
                    { value: "name", label: "Name · A–Z" },
                    { value: "win-desc", label: "Win % · Highest first" },
                    { value: "win-asc", label: "Win % · Lowest first" },
                    ...(privateAccess
                      ? [{ value: "elo", label: "Elo · Highest first" }]
                      : []),
                    { value: "team", label: "Team · A–Z" },
                  ]}
                />
              </div>
              {lifetimeView && (
                <p className="footnote">
                  Lifetime records use individual game scorecards and linked
                  identities. Win rate is wins divided by games, including ties.
                  Players with no games sort last.
                </p>
              )}
              <div className="table-card">
                <Table>
                  <TableHeader>
                    <TableRow>
                      {[
                        "Player",
                        "Team",
                        "Games",
                        "Wins",
                        "Losses",
                        "Win %",
                        ...(lifetimeView
                          ? ["Ties"]
                          : ["Sweep bonus", "Points"]),
                        ...(privateAccess
                          ? [
                              "League Elo",
                              s.archived && !lifetimeView
                                ? "Base line"
                                : "Draft rank",
                            ]
                          : []),
                      ].map((h) => (
                        <TableHead key={h}>{h}</TableHead>
                      ))}
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {sortedPlayers.map((p) => (
                      <TableRow key={p.id}>
                        <TableCell>
                          <strong>{p.name}</strong>
                        </TableCell>
                        <TableCell>{p.team}</TableCell>
                        <TableCell>{p.games}</TableCell>
                        <TableCell>{p.wins}</TableCell>
                        <TableCell>{p.losses}</TableCell>
                        <TableCell>
                          {p.games ? Math.round(p.winPct * 100) + "%" : "—"}
                        </TableCell>
                        {lifetimeView ? (
                          <TableCell>{p.lifetime?.ties || 0}</TableCell>
                        ) : (
                          <>
                            <TableCell>{p.bonus}</TableCell>
                            <TableCell>
                              <strong>{p.points}</strong>
                            </TableCell>
                          </>
                        )}
                        {privateAccess && (
                          <>
                            <TableCell>
                              <strong>{Math.round(p.elo ?? 1500)}</strong>
                              {(p.ratedGames || 0) < 12 && (
                                <div className="muted">Provisional</div>
                              )}
                            </TableCell>
                            <TableCell>{statsRank(p.rank) || "—"}</TableCell>
                          </>
                        )}
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
                {!filtered.length && (
                  <div className="empty">No players match this search.</div>
                )}
              </div>
              <div className="info-panel">
                <h3>About player ratings</h3>
                <p>
                  Draft ranks are imported from your sheet and visible only to
                  captains and the organizer. League Elo is separate from draft
                  rank and is also captain-only. Starting ratings use each
                  player’s earliest season tier, spaced 100 points apart.
                  Four-line seasons start at 1650 / 1550 / 1450 / 1350;
                  five-line seasons at 1700 / 1600 / 1500 / 1400 / 1300.
                  Historical A–D tiers correspond to Lines 1–4. The first
                  recorded line is used when that season has no draft tier;
                  without either, the starting rating is 1500. This starting
                  adjustment happens once. Ratings carry forward through Spring,
                  Summer, and Fall, using each pair’s average rating for each
                  completed game. Season views include results through that
                  season; Lifetime includes all imported results. Later seasons
                  never change an earlier season’s rating. The adjustment factor
                  is 24; sweep bonuses do not count toward Elo. Ratings marked
                  provisional have fewer than 12 linked career games. This is a
                  club rating, not DUPR.
                </p>
                {privateAccess && !!s.eloNotes?.length && (
                  <p>
                    <strong>History awaiting name confirmation:</strong>{" "}
                    {s.eloNotes.join("; ")}. These records remain separate until
                    their player identities are confirmed.
                  </p>
                )}
              </div>
            </TabsContent>
            <TabsContent value="Players">
              <div className="section-heading">
                <div>
                  <h2>Good people. Great games.</h2>
                  <p>
                    {activePlayers.length} drafted players ·{" "}
                    {s.players.length - activePlayers.length} substitutes in
                    this import.
                  </p>
                </div>
              </div>
              <div className="filters">
                <input
                  aria-label="Search players"
                  placeholder="Find a teammate…"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
                <Picker
                  label="Filter players by team"
                  value={team}
                  onChange={setTeam}
                  options={[
                    { value: "all", label: "All teams" },
                    ...s.teams.map((t) => ({ value: t, label: t })),
                    { value: "SUBS", label: "Substitutes" },
                  ]}
                />
                {privateAccess && (
                  <Picker
                    label="Filter players by draft rank"
                    value={draftRank}
                    onChange={setDraftRank}
                    options={[
                      { value: "all", label: "All draft ranks" },
                      ...[
                        ...new Set(
                          s.players.map((p) => p.rank).filter(Boolean),
                        ),
                      ]
                        .sort((a, b) =>
                          a.localeCompare(b, undefined, { numeric: true }),
                        )
                        .map((rank) => ({ value: rank, label: rank })),
                      { value: "_unranked", label: "Unranked" },
                    ]}
                  />
                )}
                <CheckField
                  label="Hide substitutes"
                  value={hideSubs}
                  change={setHideSubs}
                />
                <Picker
                  label="Sort players"
                  value={
                    playerSort === "elo" && !privateAccess ? "name" : playerSort
                  }
                  onChange={setPlayerSort}
                  options={[
                    { value: "name", label: "Name · A–Z" },
                    { value: "win-desc", label: "Win % · Highest first" },
                    { value: "win-asc", label: "Win % · Lowest first" },
                    ...(privateAccess
                      ? [{ value: "elo", label: "Elo · Highest first" }]
                      : []),
                    { value: "team", label: "Team · A–Z" },
                  ]}
                />
              </div>
              <div className="player-grid">
                {sortedPlayers.map((p) => (
                  <article className="player-card" key={p.id}>
                    <div className="player-top">
                      <div className="avatar">
                        {p.name
                          .split(" ")
                          .map((n) => n[0])
                          .slice(0, 2)
                          .join("")}
                      </div>
                      <div>
                        <h3>{p.name}</h3>
                        <p>{p.team}</p>
                      </div>
                      {p.captain && <span className="pill">Captain</span>}
                    </div>
                    <div className="player-stats">
                      {privateAccess && !p.excludeFromRankings && (
                        <>
                          <span>
                            <strong>{Math.round(p.elo ?? 1500)}</strong>League
                            Elo{(p.ratedGames || 0) < 12 ? " *" : ""}
                          </span>
                          <span>
                            <strong>{p.rank || "—"}</strong>
                            {s.archived ? "Base line" : "Draft rank"}
                          </span>
                        </>
                      )}
                      <span>
                        <strong>
                          {p.games ? Math.round(p.winPct * 100) + "%" : "—"}
                        </strong>
                        Win rate
                      </span>
                      <span>
                        <strong>{p.games}</strong>Games
                      </span>
                    </div>
                    {p.contactEmail || p.phone ? (
                      <div className="contacts">
                        {p.contactEmail && (
                          <a href={"mailto:" + p.contactEmail}>
                            {p.contactEmail}
                          </a>
                        )}
                        {p.phone && <a href={"tel:" + p.phone}>{p.phone}</a>}
                      </div>
                    ) : (
                      <p className="muted">
                        Contact details are available to captains.
                      </p>
                    )}
                    <button
                      className="text-button"
                      onClick={() => open("player", p)}
                    >
                      View profile
                    </button>
                    {!s.archived && (admin || p.id === playerId) && (
                      <button
                        className="text-button"
                        onClick={() => open("profile", p)}
                      >
                        Edit profile
                      </button>
                    )}
                  </article>
                ))}
              </div>
              {!filtered.length && (
                <div className="empty">No players match this search.</div>
              )}
            </TabsContent>
            <TabsContent value="Photos">
              <Photos />
            </TabsContent>
            <TabsContent value="Announcements">
              <div className="section-heading">
                <div>
                  <h2>Around the club.</h2>
                  <p>
                    League news, upcoming events, and notes from the organizer.
                  </p>
                </div>
                {admin && (
                  <button
                    className="primary"
                    onClick={() =>
                      open("announcement", { title: "", body: "" })
                    }
                  >
                    <Plus size={16} /> Post an announcement
                  </button>
                )}
              </div>
              {s.announcements.length ? (
                s.announcements.map((a) => (
                  <article className="announcement-card" key={a.id}>
                    <span className="eyebrow">
                      {new Date(a.date).toLocaleDateString("en-US", {
                        month: "long",
                        day: "numeric",
                        year: "numeric",
                      })}
                    </span>
                    <h2>{a.title}</h2>
                    <p className="preserve-text">{a.body}</p>
                  </article>
                ))
              ) : (
                <div className="empty large">
                  <Megaphone size={34} />
                  <h3>Quiet in the clubhouse.</h3>
                  <p>
                    Announcements will appear here when the organizer posts one.
                  </p>
                </div>
              )}
            </TabsContent>
            <TabsContent value="Fees">
              <div className="section-heading">
                <div>
                  <h2>Square up for the season.</h2>
                  <p>League fee $50 · Shirt $30 · Hat $35</p>
                </div>
                <a
                  className="primary"
                  href="https://venmo.com/u/hudson2508"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Pay @hudson2508 <ArrowUpRight size={16} />
                </a>
              </div>
              <div className="info-panel payment-info">
                <Wallet size={22} />
                <div>
                  <h3>Pay with Venmo</h3>
                  <p>
                    Include your name, season, and what you’re paying for. The
                    organizer confirms each payment after receiving it. Opening
                    Venmo does not mark your balance as paid.
                  </p>
                </div>
              </div>
              {admin && (
                <div className="metrics">
                  <div>
                    <span>League fees confirmed</span>
                    <strong>
                      {activePlayers.filter((p) => p.paid).length} /{" "}
                      {activePlayers.length}
                    </strong>
                  </div>
                  <div>
                    <span>Total confirmed</span>
                    <strong>
                      {money(
                        activePlayers.reduce((n, p) => n + bill(p).paid, 0),
                      )}
                    </strong>
                  </div>
                  <div>
                    <span>Outstanding, incl. orders</span>
                    <strong>
                      {money(
                        activePlayers.reduce((n, p) => n + bill(p).balance, 0),
                      )}
                    </strong>
                  </div>
                </div>
              )}
              <div className="table-card">
                <Table>
                  <TableHeader>
                    <TableRow>
                      {[
                        "Player",
                        "League · $50",
                        "Shirt · $30",
                        "Hat · $35",
                        "Balance",
                        ...(admin ? [""] : []),
                      ].map((h, i) => (
                        <TableHead key={i}>{h}</TableHead>
                      ))}
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {(admin ? activePlayers : selected ? [selected] : []).map(
                      (p) => (
                        <TableRow key={p.id}>
                          <TableCell>
                            <strong>{p.name}</strong>
                            <div className="muted">{p.team}</div>
                          </TableCell>
                          <TableCell>
                            <span
                              className={
                                "pill " + (p.paid ? "success" : "unpaid")
                              }
                            >
                              {p.paid ? "Confirmed" : "Unpaid"}
                            </span>
                          </TableCell>
                          <TableCell>
                            {p.shirt ? (
                              <span
                                className={
                                  "pill " + (p.shirtPaid ? "success" : "unpaid")
                                }
                              >
                                {p.shirtPaid ? "Confirmed" : "Unpaid"}
                              </span>
                            ) : (
                              "No order"
                            )}
                          </TableCell>
                          <TableCell>
                            {p.hat ? (
                              <span
                                className={
                                  "pill " + (p.hatPaid ? "success" : "unpaid")
                                }
                              >
                                {p.hatPaid ? "Confirmed" : "Unpaid"}
                              </span>
                            ) : (
                              "No order"
                            )}
                          </TableCell>
                          <TableCell>
                            <strong>{money(bill(p).balance)}</strong>
                          </TableCell>
                          {admin && (
                            <TableCell>
                              <button
                                className="text-button"
                                onClick={() => open("payment", p)}
                              >
                                Update
                              </button>
                            </TableCell>
                          )}
                        </TableRow>
                      ),
                    )}
                  </TableBody>
                </Table>
              </div>
            </TabsContent>
            <TabsContent value="Rules & format">
              <div className="section-heading">
                <div>
                  <h2>How we play.</h2>
                  <p>The format, scoring, and club rules in one place.</p>
                </div>
                {admin && !s.archived && (
                  <button
                    className="secondary"
                    onClick={() => open("rules", { rules: s.rules })}
                  >
                    Edit rules
                  </button>
                )}
              </div>
              <div className="format-grid">
                <div>
                  <strong>4</strong>
                  <span>Drafted teams</span>
                </div>
                <div>
                  <strong>{s.matches[0]?.lines.length || 5}</strong>
                  <span>Lines per matchup</span>
                </div>
                <div>
                  <strong>3</strong>
                  <span>Games per line</span>
                </div>
                <div>
                  <strong>{s.archived ? "+1" : "+0.5"}</strong>
                  <span>Sweep bonus</span>
                </div>
              </div>
              <article className="rules-card preserve-text">{s.rules}</article>
              {s.id === "fall-2026" && (
                <div className="info-panel">
                  <h3>Sean O’Brien’s courts</h3>
                  <p>
                    Parking beside and behind the courts, plus the Mama Bettie’s
                    parking garage. Bring plenty of water; drinks will be
                    available in coolers. Eat before arriving or order Mama
                    Bettie’s for pickup.
                  </p>
                  <a
                    className="secondary"
                    href="https://maps.app.goo.gl/HEHt2a5zAPH1XdvD9"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    Get directions <ArrowUpRight size={16} />
                  </a>
                </div>
              )}
              <div className="info-panel">
                <h3>Your account and contact details</h3>
                <p>
                  Player access uses a sign-in email on the league roster.
                  Players can manage their own contact email and phone number.
                  Only the organizer and current captains can see other players’
                  contact details and draft rankings. A contact email change
                  does not change the account used to sign in.
                </p>
              </div>
            </TabsContent>
          </Tabs>
        )}
      </main>
      <footer>
        DINK PONY CLUB{" "}
        <span>{s?.name || "Fall 2026"} · For the love of the game.</span>
      </footer>
      <Dialog
        open={!!modal}
        onOpenChange={(v) => {
          if (!v && !busy) setModal("");
        }}
      >
        <DialogContent
          className={
            "league-dialog " + (modal === "result" ? "wide-dialog" : "")
          }
        >
          <DialogHeader>
            <DialogTitle>
              {(
                {
                  result: "Match scorecard",
                  profile: "Player profile",
                  player: "Player profile",
                  payment: "Confirm a payment",
                  schedule: "Edit the schedule",
                  announcement: "Club announcement",
                  rules: "Rules & format",
                  import: "Import a previous season",
                } as any
              )[modal] || ""}
            </DialogTitle>
            <DialogDescription>
              {modal === "result"
                ? `${draft.a} vs ${draft.b}`
                : modal === "player"
                  ? "Lifetime game record across all imported seasons."
                  : modal === "profile"
                    ? "Manage your contact details. Captains and the organizer may view them."
                    : modal === "import"
                      ? "Upload an Excel export using the DPC workbook format. Existing seasons will stay unchanged."
                      : "Changes are saved to the selected season."}
            </DialogDescription>
          </DialogHeader>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              if (modal === "player") return;
              if (modal === "import") {
                if (upload) save("import", { data: upload });
              } else
                save(modal, {
                  ...draft,
                  playerId: draft.id || playerId,
                  matchId: draft.id,
                  week: draft.id,
                });
            }}
          >
            {modal === "result" &&
              draft.lines?.map((l: any, i: number) => (
                <div className="line-editor" key={i}>
                  <h3>Line {i + 1}</h3>
                  <div className="line-teams">
                    {(["a", "b"] as const).map((side) => (
                      <div key={side}>
                        <h4>{draft[side]}</h4>
                        {[0, 1, 2].map((j) => (
                          <Picker
                            key={j}
                            disabled={!captain || s?.archived}
                            label={`${side === "a" ? "Home" : "Away"} line ${i + 1} player ${j + 1}`}
                            value={l[side][j]}
                            onChange={(v) => {
                              const d = structuredClone(draft);
                              d.lines[i][side][j] = v;
                              setDraft(d);
                            }}
                            options={[
                              {
                                value: "",
                                label:
                                  j === 2 ? "No third player" : "Select player",
                              },
                              ...(s?.players || []).map((p) => ({
                                value: p.name,
                                label: p.name + " · " + p.team,
                              })),
                            ]}
                          />
                        ))}
                      </div>
                    ))}
                  </div>
                  <div className="game-inputs">
                    {l.scores.map((pair: (number | null)[], g: number) => (
                      <label key={g}>
                        <span>Game {g + 1}</span>
                        <div>
                          {pair.map((score, k) => (
                            <input
                              key={k}
                              aria-label={`Line ${i + 1}, game ${g + 1}, ${k === 0 ? draft.a : draft.b} score`}
                              type="number"
                              min="0"
                              max="99"
                              required
                              disabled={!captain || s?.archived}
                              value={score ?? ""}
                              onChange={(e) => {
                                const d = structuredClone(draft);
                                d.lines[i].scores[g][k] =
                                  e.target.value === ""
                                    ? null
                                    : Number(e.target.value);
                                setDraft(d);
                              }}
                            />
                          ))}
                        </div>
                      </label>
                    ))}
                  </div>
                  <p className="muted">
                    Three players rotate P1/P2, P1/P3, P2/P3. Two players play
                    all three games.
                  </p>
                </div>
              ))}
            {(modal === "profile" || modal === "player") && (
              <div className="info-panel">
                <h3>Lifetime record</h3>
                <div className="player-stats">
                  <span>
                    <strong>
                      {draft.lifetime?.wins ?? 0}–{draft.lifetime?.losses ?? 0}
                      {draft.lifetime?.ties ? `–${draft.lifetime.ties}` : ""}
                    </strong>
                    {draft.lifetime?.ties ? "Wins–losses–ties" : "Wins–losses"}
                  </span>
                  <span>
                    <strong>
                      {draft.lifetime?.games
                        ? Math.round(draft.lifetime.winRate * 100) + "%"
                        : "—"}
                    </strong>
                    Lifetime win rate
                  </span>
                  <span>
                    <strong>{draft.lifetime?.games ?? 0}</strong>Games played
                  </span>
                </div>
                <p>
                  All imported seasons, including playoffs. Calculated from
                  recorded individual games and linked player identities. Win
                  rate is wins divided by all games; tied games count in the
                  total.
                </p>
              </div>
            )}
            {modal === "player" && (
              <>
                <h3>{draft.name}</h3>
                <p>{draft.team}</p>
                {privateAccess && !draft.excludeFromRankings && (
                  <p>
                    League Elo: {Math.round(draft.elo ?? 1500)} · Draft rank:{" "}
                    {draft.rank || "Unranked"}
                  </p>
                )}
                {draft.contactEmail && (
                  <p>
                    <a href={"mailto:" + draft.contactEmail}>
                      {draft.contactEmail}
                    </a>
                  </p>
                )}
                {draft.phone && (
                  <p>
                    <a href={"tel:" + draft.phone}>{draft.phone}</a>
                  </p>
                )}
                {!s?.archived && (admin || draft.id === playerId) && (
                  <button
                    type="button"
                    className="secondary"
                    onClick={() => open("profile", draft)}
                  >
                    Edit profile
                  </button>
                )}
              </>
            )}
            {modal === "profile" && (
              <>
                <h3>{draft.name}</h3>
                <p className="muted">
                  {draft.team}
                  {privateAccess && (
                    <> · Draft rank {draft.rank || "not set"}</>
                  )}
                </p>
                <label className="field">
                  Contact email
                  <input
                    type="email"
                    value={draft.contactEmail ?? draft.email ?? ""}
                    onChange={(e) =>
                      setDraft({ ...draft, contactEmail: e.target.value })
                    }
                  />
                </label>
                {admin && (
                  <label className="field">
                    Account sign-in email
                    <input
                      type="email"
                      value={draft.email || ""}
                      onChange={(e) =>
                        setDraft({ ...draft, email: e.target.value })
                      }
                    />
                    <span className="muted">
                      This email must match the player's ChatGPT sign-in
                      account.
                    </span>
                  </label>
                )}
                <label className="field">
                  Phone number
                  <input
                    type="tel"
                    value={draft.phone || ""}
                    onChange={(e) =>
                      setDraft({ ...draft, phone: e.target.value })
                    }
                  />
                </label>
                {admin && (
                  <p className="muted">
                    Captain access:{" "}
                    {draft.captain
                      ? "Confirmed season captain"
                      : "Not a captain"}
                  </p>
                )}
                <p className="muted">
                  Contact details are visible to the organizer and current
                  captains.
                </p>
              </>
            )}
            {modal === "payment" && (
              <>
                <h3>{draft.name}</h3>
                <div className="check-list">
                  <CheckField
                    label="League fee received · $50"
                    value={!!draft.paid}
                    change={(v) => setDraft({ ...draft, paid: v })}
                  />
                  <CheckField
                    label="Shirt ordered · $30"
                    value={!!draft.shirt}
                    change={(v) => setDraft({ ...draft, shirt: v })}
                  />
                  {draft.shirt && (
                    <CheckField
                      label="Shirt payment received"
                      value={!!draft.shirtPaid}
                      change={(v) => setDraft({ ...draft, shirtPaid: v })}
                    />
                  )}
                  <CheckField
                    label="Hat ordered · $35"
                    value={!!draft.hat}
                    change={(v) => setDraft({ ...draft, hat: v })}
                  />
                  {draft.hat && (
                    <CheckField
                      label="Hat payment received"
                      value={!!draft.hatPaid}
                      change={(v) => setDraft({ ...draft, hatPaid: v })}
                    />
                  )}
                </div>
                <div className="balance-summary">
                  Remaining balance{" "}
                  <strong>{money(bill(draft).balance)}</strong>
                </div>
                <p className="muted">
                  Only confirm payments you have received in Venmo.
                </p>
              </>
            )}
            {modal === "schedule" && (
              <>
                <label className="field">
                  Date
                  <input
                    type="date"
                    required
                    value={draft.date || ""}
                    onChange={(e) =>
                      setDraft({ ...draft, date: e.target.value })
                    }
                  />
                </label>
                <label className="field">
                  Start time / line times
                  <input
                    value={draft.time || ""}
                    placeholder="e.g. Lines 2 & 4 at 7:15 PM"
                    onChange={(e) =>
                      setDraft({ ...draft, time: e.target.value })
                    }
                  />
                </label>
                <label className="field">
                  Venue
                  <input
                    value={draft.venue || ""}
                    onChange={(e) =>
                      setDraft({ ...draft, venue: e.target.value })
                    }
                  />
                </label>
                {draft.matches?.map((m: Match, i: number) => (
                  <div key={m.id} className="field">
                    <strong>Matchup {i + 1}</strong>
                    {(["a", "b"] as const).map((side) => (
                      <Picker
                        key={side}
                        label={`Matchup ${i + 1} team ${side}`}
                        value={m[side]}
                        options={[
                          { value: "TBD", label: "To be decided" },
                          ...(s?.teams || []).map((t) => ({
                            value: t,
                            label: t,
                          })),
                        ]}
                        onChange={(v) => {
                          const d = structuredClone(draft);
                          d.matches[i][side] = v;
                          setDraft(d);
                        }}
                      />
                    ))}
                  </div>
                ))}
              </>
            )}
            {modal === "announcement" && (
              <>
                <label className="field">
                  Title
                  <input
                    required
                    maxLength={150}
                    value={draft.title || ""}
                    onChange={(e) =>
                      setDraft({ ...draft, title: e.target.value })
                    }
                  />
                </label>
                <label className="field">
                  Announcement
                  <textarea
                    required
                    rows={7}
                    maxLength={6000}
                    value={draft.body || ""}
                    onChange={(e) =>
                      setDraft({ ...draft, body: e.target.value })
                    }
                  />
                </label>
              </>
            )}
            {modal === "rules" && (
              <label className="field">
                League rules
                <textarea
                  required
                  rows={14}
                  maxLength={15000}
                  value={draft.rules || ""}
                  onChange={(e) =>
                    setDraft({ ...draft, rules: e.target.value })
                  }
                />
              </label>
            )}
            {modal === "import" && (
              <>
                <label className="field">
                  Season name
                  <input
                    required
                    placeholder="e.g. Spring 2026"
                    value={draft.name || ""}
                    maxLength={100}
                    onChange={(e) => {
                      setDraft({ ...draft, name: e.target.value });
                      setUpload(null);
                    }}
                  />
                </label>
                <label className="field">
                  DPC Excel workbook
                  <input
                    key={draft.name}
                    type="file"
                    accept=".xlsx"
                    disabled={!draft.name?.trim()}
                    onChange={async (e) => {
                      const f = e.target.files?.[0];
                      if (!f) return;
                      setFormError("");
                      setBusy(true);
                      try {
                        const n = await importWorkbook(f, draft.name.trim());
                        setUpload(n);
                      } catch (e) {
                        setUpload(null);
                        setFormError((e as Error).message);
                      } finally {
                        setBusy(false);
                      }
                    }}
                  />
                </label>
                {upload && (
                  <div className="info-panel">
                    <h3>Ready to import {upload.name}</h3>
                    <p>
                      {upload.teams.length} teams · {upload.players.length}{" "}
                      players · {upload.weeks.length} weeks ·{" "}
                      {
                        upload.matches.filter((m) => matchResult(m).complete)
                          .length
                      }{" "}
                      completed matchups
                    </p>
                    <p>
                      Includes availability, contacts, and fee records. Contacts
                      are restricted to the organizer and captains.
                    </p>
                  </div>
                )}
              </>
            )}
            {formError && (
              <p className="form-error" role="alert">
                {formError}
              </p>
            )}
            <div className="dialog-actions">
              <button
                type="button"
                className="secondary"
                disabled={busy}
                onClick={() => setModal("")}
              >
                Close
              </button>
              {modal !== "player" &&
                (modal !== "result" || (captain && !s?.archived)) && (
                  <button
                    type="submit"
                    className="primary"
                    disabled={busy || (modal === "import" && !upload)}
                  >
                    {busy
                      ? "Saving…"
                      : modal === "result"
                        ? "Post results"
                        : modal === "import"
                          ? "Import season"
                          : "Save changes"}
                  </button>
                )}
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
