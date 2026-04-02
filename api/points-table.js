/**
 * GET /api/points-table
 *
 * Fetches IPL 2025 points table from CricAPI and transforms it
 * into the shape the frontend expects: { groupA: [...], groupB: [...] }
 *
 * Each entry: { team, m, w, l, nrr, pts, form }
 *
 * ENV vars required (set in Vercel dashboard or .env):
 *   CRICKET_API_KEY  – your CricAPI key
 *   IPL_SERIES_ID    – IPL 2025 series UUID from CricAPI
 *
 * Caching: Stores response in memory for 1 hour to avoid hitting CricAPI rate limit
 */

import { getCached, setCached } from './cache.js';

// CricAPI team name → our short code
const TEAM_MAP = {
  'Mumbai Indians':            'MI',
  'Chennai Super Kings':       'CSK',
  'Royal Challengers Bengaluru': 'RCB',
  'Royal Challengers Bangalore': 'RCB',
  'Delhi Capitals':            'DC',
  'Gujarat Titans':            'GT',
  'Kolkata Knight Riders':     'KKR',
  'Sunrisers Hyderabad':       'SRH',
  'Rajasthan Royals':          'RR',
  'Lucknow Super Giants':      'LSG',
  'Punjab Kings':              'PBKS',
};

function resolveTeam(name = '') {
  if (TEAM_MAP[name]) return TEAM_MAP[name];
  // Fuzzy fallback: check if any key is contained in the name
  for (const [full, abbr] of Object.entries(TEAM_MAP)) {
    if (name.toLowerCase().includes(abbr.toLowerCase())) return abbr;
  }
  return name.toUpperCase().slice(0, 4); // last-resort abbreviation
}

export default async function handler(req, res) {
  // ── CORS (needed if called from a WebView on a different origin) ──
  res.setHeader('Access-Control-Allow-Origin', '*');
  const season = req.query.season;
  // 2025 is historical — cache for 24h. 2026 live — cache for 2 min.
  const cacheAge = season === '2025' ? 86400 : 120;
  res.setHeader('Cache-Control', `s-maxage=${cacheAge}, stale-while-revalidate=60`);

  const { CRICKET_API_KEY, IPL_SERIES_ID, IPL_2025_SERIES_ID } = process.env;

  if (!CRICKET_API_KEY || !IPL_SERIES_ID) {
    return res.status(500).json({ error: 'Missing env vars: CRICKET_API_KEY, IPL_SERIES_ID' });
  }

  const seriesId = ((season === '2025' && IPL_2025_SERIES_ID) ? IPL_2025_SERIES_ID : IPL_SERIES_ID).trim();
  const cacheKey = `points-table_${season}_${seriesId}`;

  try {
    // Check if we have fresh cached data
    const cached = getCached(cacheKey);
    if (cached) {
      return res.status(200).json(cached);
    }

    // Using CricketData.org (100K calls/hour free tier)
    const url =
      `https://cricketdata.org/api/v1/series_points` +
      `?apikey=${CRICKET_API_KEY}&id=${seriesId}`;

    const upstream = await fetch(url, { headers: { Accept: 'application/json' } });
    if (!upstream.ok) throw new Error(`CricAPI responded ${upstream.status}`);

    const json = await upstream.json();

    if (json.status !== 'success' || !Array.isArray(json.data)) {
      throw new Error(`Unexpected CricAPI shape: ${JSON.stringify(json).slice(0, 200)}`);
    }

    // CricAPI returns two different shapes depending on the series:
    // Format A (2026+): data is array of group objects { title, rows: [...] }
    // Format B (2025):  data is a flat array of team objects { teamname, shortname, matches, wins, loss, ties, nr }
    const allEntries = [];

    const firstItem = json.data[0] || {};
    const isFlatFormat = 'teamname' in firstItem || 'shortname' in firstItem;

    if (isFlatFormat) {
      // Format B — flat team list. Used for 2025 (hardcoded) and 2026+ live data

      // For 2025: use hardcoded final standings since season is complete
      const teamDataMap = season === '2025' ? {
        'PBKS': { m: 14, w: 9, l: 4,  nrr:  0.372, form: ['W', 'W', 'W', 'D', 'W'] },
        'RCB':  { m: 14, w: 9, l: 4,  nrr:  0.301, form: ['W', 'W', 'L', 'W', 'D'] },
        'GT':   { m: 14, w: 9, l: 5,  nrr:  0.254, form: ['W', 'W', 'L', 'W', 'W'] },
        'MI':   { m: 14, w: 8, l: 6,  nrr:  1.142, form: ['W', 'L', 'W', 'W', 'L'] },
        'DC':   { m: 14, w: 7, l: 6,  nrr:  0.011, form: ['W', 'L', 'D', 'W', 'L'] },
        'SRH':  { m: 14, w: 6, l: 7,  nrr: -0.241, form: ['L', 'W', 'L', 'D', 'L'] },
        'LSG':  { m: 14, w: 6, l: 8,  nrr: -0.376, form: ['L', 'L', 'W', 'L', 'W'] },
        'KKR':  { m: 14, w: 5, l: 7,  nrr: -0.305, form: ['W', 'L', 'D', 'L', 'D'] },
        'RR':   { m: 14, w: 4, l: 10, nrr: -0.456, form: ['L', 'L', 'L', 'W', 'L'] },
        'CSK':  { m: 14, w: 4, l: 10, nrr: -0.567, form: ['L', 'L', 'W', 'L', 'L'] },
      } : {};

      for (const row of json.data) {
        const team = resolveTeam(row.teamname || row.shortname || '');
        const teamData = teamDataMap[team];

        // For 2025: use hardcoded data. For 2026+: use live CricAPI data
        const m = teamData?.m || row.matches || 0;
        const w = teamData?.w || row.wins || 0;
        const l = teamData?.l || row.loss || 0;
        const nrr = teamData?.nrr || row.nrr || 0;
        const form = teamData?.form || [];

        allEntries.push({
          team,
          m,
          w,
          l,
          nrr,
          pts: (w * 2) + (m - w - l), // 2 pts per win + 1 pt per draw (losses in m - w - l)
          form,
        });
      }
    } else {
      // Format A — grouped table with rows
      for (const table of json.data) {
        for (const row of (table.rows || [])) {
          const team = resolveTeam(row.name || row.teamName || '');

          let form = [];
          if (Array.isArray(row.recentMatchResults)) {
            form = row.recentMatchResults.map(r =>
              r === 'W' || r === 'w' ? 'W' : r === 'L' || r === 'l' ? 'L' : 'D'
            ).slice(-5);
          } else if (typeof row.recentMatchResults === 'string') {
            form = row.recentMatchResults.trim().split(/\s+/).map(r =>
              r.toUpperCase() === 'W' ? 'W' : r.toUpperCase() === 'L' ? 'L' : 'D'
            ).slice(-5);
          }

          allEntries.push({
            team,
            m:   Number(row.matchesPlayed ?? row.m ?? 0),
            w:   Number(row.won          ?? row.w ?? 0),
            l:   Number(row.lost         ?? row.l ?? 0),
            nrr: parseFloat(row.netRunRate ?? row.nrr ?? 0),
            pts: Number(row.points       ?? row.pts ?? 0),
            form,
          });
        }
      }
    }

    // Sort by pts desc, then nrr desc
    const teams = allEntries.sort((a, b) => b.pts - a.pts || b.nrr - a.nrr);

    const response = { teams };

    // Cache the result for 1 hour
    setCached(cacheKey, response, 3600);

    return res.status(200).json(response);

  } catch (err) {
    console.error('[points-table]', err.message);
    return res.status(502).json({ error: 'Failed to fetch points table', detail: err.message });
  }
}
