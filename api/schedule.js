/**
 * GET /api/schedule
 *
 * Fetches IPL 2025 match schedule from CricAPI and transforms it
 * into the shape the frontend expects:
 *   [ { date: "Tue, Mar 18", matches: [ { id, num, t1, t2, time, venue, status, score1?, score2?, winner? } ] } ]
 *
 * ENV vars required:
 *   CRICKET_API_KEY  – your CricAPI key
 *   IPL_SERIES_ID    – IPL 2025 series UUID from CricAPI
 *
 * Caching: Stores response in memory for 1 hour to avoid hitting CricAPI rate limit
 */

import { getCached, setCached } from './cache.js';

const TEAM_MAP = {
  'Mumbai Indians':              'MI',
  'Chennai Super Kings':         'CSK',
  'Royal Challengers Bengaluru': 'RCB',
  'Royal Challengers Bangalore': 'RCB',
  'Delhi Capitals':              'DC',
  'Gujarat Titans':              'GT',
  'Kolkata Knight Riders':       'KKR',
  'Sunrisers Hyderabad':         'SRH',
  'Rajasthan Royals':            'RR',
  'Lucknow Super Giants':        'LSG',
  'Punjab Kings':                'PBKS',
};

function resolveTeam(name = '') {
  if (TEAM_MAP[name]) return TEAM_MAP[name];
  for (const [full, abbr] of Object.entries(TEAM_MAP)) {
    if (name.toLowerCase().includes(abbr.toLowerCase())) return abbr;
  }
  return name.toUpperCase().slice(0, 4);
}

function formatDateLabel(dateStr) {
  // dateStr from CricAPI is typically "2025-03-18"
  const d = new Date(dateStr);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const target = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const diff = (target - today) / 86400000;

  if (diff === 0) {
    return `Today · ${d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`;
  }
  if (diff === 1) return 'Tomorrow';
  return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
}

function matchStatus(match) {
  // CricAPI matchStarted / matchEnded booleans
  if (match.matchEnded)   return 'completed';
  if (match.matchStarted) return 'live';
  return 'upcoming';
}

function formatTime(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  return d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  const season = req.query.season;
  // 2025 historical — cache 24h. 2026 live — cache 1 min.
  const cacheAge = season === '2025' ? 86400 : 60;
  res.setHeader('Cache-Control', `s-maxage=${cacheAge}, stale-while-revalidate=30`);

  const { CRICKET_API_KEY, IPL_SERIES_ID, IPL_2025_SERIES_ID } = process.env;

  if (!CRICKET_API_KEY || !IPL_SERIES_ID) {
    return res.status(500).json({ error: 'Missing env vars: CRICKET_API_KEY, IPL_SERIES_ID' });
  }

  const seriesId = ((season === '2025' && IPL_2025_SERIES_ID) ? IPL_2025_SERIES_ID : IPL_SERIES_ID).trim();
  const cacheKey = `schedule_${season}_${seriesId}`;

  try {
    // Check if we have fresh cached data
    const cached = getCached(cacheKey);
    if (cached) {
      return res.status(200).json(cached);
    }

    // Using CricketData.org (100K calls/hour free tier)
    const url =
      `https://cricketdata.org/api/v1/series_info` +
      `?apikey=${CRICKET_API_KEY}&id=${seriesId}`;

    const upstream = await fetch(url, { headers: { Accept: 'application/json' } });
    if (!upstream.ok) throw new Error(`CricAPI responded ${upstream.status}`);

    const json = await upstream.json();

    if (json.status !== 'success' || !json.data || !Array.isArray(json.data.matchList)) {
      throw new Error(`Unexpected CricAPI shape: ${JSON.stringify(json).slice(0, 200)}`);
    }

    // Group matches by date
    const byDate = new Map();

    json.data.matchList.forEach((match, idx) => {
      const dateKey = (match.date || match.dateTimeGMT || '').slice(0, 10); // "YYYY-MM-DD"
      if (!dateKey) return;

      const t1raw = match.teams?.[0] || '';
      const t2raw = match.teams?.[1] || '';
      const t1 = resolveTeam(t1raw);
      const t2 = resolveTeam(t2raw);

      const status = matchStatus(match);

      // Scores
      let score1, score2, winner;
      if (status !== 'upcoming' && Array.isArray(match.score)) {
        score1 = match.score[0] ? `${match.score[0].r}/${match.score[0].w} (${match.score[0].o})` : undefined;
        score2 = match.score[1] ? `${match.score[1].r}/${match.score[1].w} (${match.score[1].o})` : undefined;
      }
      if (match.matchWinner) winner = resolveTeam(match.matchWinner);

      const entry = {
        id:     match.id || `m${idx + 1}`,
        num:    idx + 1,
        t1, t2,
        time:   formatTime(match.dateTimeGMT),
        venue:  match.venue || '',
        status,
        dateISO: dateKey,
        ...(score1 ? { score1 } : {}),
        ...(score2 ? { score2 } : {}),
        ...(winner ? { winner } : {}),
      };

      if (!byDate.has(dateKey)) byDate.set(dateKey, []);
      byDate.get(dateKey).push(entry);
    });

    // Sort dates chronologically and build response
    const sorted = [...byDate.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([dateKey, matches]) => ({
        date: formatDateLabel(dateKey),
        matches,
      }));

    // Cache the result for 1 hour
    setCached(cacheKey, sorted, 3600);

    return res.status(200).json(sorted);

  } catch (err) {
    console.error('[schedule]', err.message);
    return res.status(502).json({ error: 'Failed to fetch schedule', detail: err.message });
  }
}
