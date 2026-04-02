/**
 * CricketData.org API Integration
 *
 * Fetches IPL 2026 points table with NRR and form data.
 *
 * API budget (S Tier: 2000 hits/day):
 *   - series_points (standings):  1 call / 5 min = 288/day
 *   - series_info   (form):       1 call / 5 min = 288/day
 *   - match_scorecard (NRR):      ~2-3/day (only new completed matches)
 *   Total: ~578 hits/day = 29% of limit
 */

import { getCached, setCached } from './cache.js';

const API_KEY = 'b50985a1-9c95-4adb-806c-94e3dde48fc9';
const API_BASE = 'https://api.cricapi.com/v1';
const SERIES_ID = '87c62aac-bc3c-4738-ab93-19da0690488f';

const CACHE_TTL = 300; // 5 minutes
const SCORECARD_TTL = 86400 * 30; // 30 days (completed matches never change)

// Permanent scorecard cache (persists across 5-min refreshes)
const scorecardCache = new Map();

const TEAM_NAME_MAP = {
  'Mumbai Indians': 'MI',
  'Chennai Super Kings': 'CSK',
  'Royal Challengers Bengaluru': 'RCB',
  'Royal Challengers Bangalore': 'RCB',
  'RCBW': 'RCB',
  'Delhi Capitals': 'DC',
  'Gujarat Titans': 'GT',
  'Kolkata Knight Riders': 'KKR',
  'Sunrisers Hyderabad': 'SRH',
  'Rajasthan Royals': 'RR',
  'Lucknow Super Giants': 'LSG',
  'Punjab Kings': 'PBKS',
};

function norm(name) {
  return TEAM_NAME_MAP[name] || name;
}

/**
 * Main entry point: fetch full points table with NRR and form
 */
async function fetchFromCricketData() {
  try {
    const cached = getCached('cricketdata_full');
    if (cached) {
      console.log('[CricketData] Returning cached data');
      return cached;
    }

    console.log('[CricketData] Fetching fresh data...');

    // Fetch standings and match list in parallel (2 API hits)
    const [standingsRes, seriesRes] = await Promise.all([
      fetch(`${API_BASE}/series_points?apikey=${API_KEY}&id=${SERIES_ID}`),
      fetch(`${API_BASE}/series_info?apikey=${API_KEY}&id=${SERIES_ID}`),
    ]);

    if (!standingsRes.ok || !seriesRes.ok) {
      console.error('[CricketData] API error:', standingsRes.status, seriesRes.status);
      return null;
    }

    const [standings, seriesInfo] = await Promise.all([
      standingsRes.json(),
      seriesRes.json(),
    ]);

    if (!standings.data || !Array.isArray(standings.data)) {
      console.warn('[CricketData] Invalid standings format');
      return null;
    }

    // Extract completed matches and derive form
    const matchList = seriesInfo?.data?.matchList || [];
    const completedMatches = matchList.filter(m =>
      m.matchEnded && m.status && m.status.toLowerCase().includes('won')
    );

    // Build form per team (last 5 results, most recent first)
    const formMap = buildFormMap(completedMatches);

    // Fetch scorecards for NRR (only uncached completed matches)
    const nrrMap = await buildNrrMap(completedMatches);

    // Assemble final team data
    const teams = standings.data.map(team => {
      const abbr = norm(team.shortname || team.teamname || '');
      const wins = parseInt(team.wins) || 0;
      return {
        team: abbr,
        m: parseInt(team.matches) || 0,
        w: wins,
        l: parseInt(team.loss) || 0,
        nrr: nrrMap[abbr] || 0,
        pts: wins * 2,
        form: formMap[abbr] || [],
      };
    });

    teams.sort((a, b) => b.pts - a.pts || b.nrr - a.nrr);

    const result = {
      teams,
      source: 'CricketData.org API',
      timestamp: new Date().toISOString(),
      cached: false,
    };

    setCached('cricketdata_full', result, CACHE_TTL);
    console.log(`[CricketData] Fetched ${teams.length} teams, ${completedMatches.length} completed matches`);
    return result;
  } catch (err) {
    console.error('[CricketData] Error:', err.message);
    return null;
  }
}

/**
 * Build form map: { "MI": ["W", "L"], "CSK": ["L"], ... }
 * Derives W/L from match status text, most recent first
 */
function buildFormMap(completedMatches) {
  const formMap = {};

  // Sort by date descending (most recent first)
  const sorted = [...completedMatches].sort((a, b) =>
    new Date(b.dateTimeGMT || b.date) - new Date(a.dateTimeGMT || a.date)
  );

  for (const match of sorted) {
    const status = match.status || '';
    const teams = (match.teams || []).map(t => norm(t));
    if (teams.length !== 2) continue;

    // Parse winner from status: "Mumbai Indians won by 6 wkts"
    let winner = null;
    for (const [fullName, abbr] of Object.entries(TEAM_NAME_MAP)) {
      if (status.includes(fullName)) {
        winner = abbr;
        break;
      }
    }

    if (!winner) continue;

    for (const team of teams) {
      if (!formMap[team]) formMap[team] = [];
      if (formMap[team].length < 5) {
        formMap[team].push(team === winner ? 'W' : 'L');
      }
    }
  }

  return formMap;
}

/**
 * Convert cricket overs notation to decimal overs.
 * In cricket, 15.4 means 15 overs and 4 balls (not 15.4 overs).
 * 1 over = 6 balls, so 15.4 = 15 + 4/6 = 15.6667
 */
function cricketOvers(o) {
  const val = parseFloat(o) || 0;
  const whole = Math.floor(val);
  const balls = Math.round((val - whole) * 10);
  return whole + balls / 6;
}

/**
 * Build NRR map from match scorecards.
 * Only fetches scorecards that aren't already cached (completed matches never change).
 *
 * NRR = (total runs scored / total overs faced) - (total runs conceded / total overs bowled)
 */
async function buildNrrMap(completedMatches) {
  // Fetch scorecards for uncached matches only
  const uncached = completedMatches.filter(m => !scorecardCache.has(m.id));

  if (uncached.length > 0) {
    console.log(`[CricketData] Fetching ${uncached.length} new scorecards for NRR...`);
    // Fetch in batches of 5 to avoid overwhelming the API
    for (let i = 0; i < uncached.length; i += 5) {
      const batch = uncached.slice(i, i + 5);
      const results = await Promise.all(
        batch.map(m =>
          fetch(`${API_BASE}/match_scorecard?apikey=${API_KEY}&id=${m.id}`)
            .then(r => r.ok ? r.json() : null)
            .catch(() => null)
        )
      );
      for (let j = 0; j < batch.length; j++) {
        if (results[j]?.data?.score) {
          scorecardCache.set(batch[j].id, results[j].data.score);
        }
      }
    }
  }

  // Calculate NRR per team from all cached scorecards
  const teamStats = {}; // { "MI": { runsFor, oversFor, runsAgainst, oversAgainst } }

  for (const match of completedMatches) {
    const scores = scorecardCache.get(match.id);
    if (!scores || scores.length < 2) continue;

    const teams = (match.teams || []).map(t => norm(t));
    if (teams.length !== 2) continue;

    // scores[0] = first innings (team batting first)
    // scores[1] = second innings (team batting second)
    // Match name format: "Team1 vs Team2, ..."
    // First team in match.teams batted first (usually)
    const inning1 = scores[0];
    const inning2 = scores[1];

    // Determine which team batted in which innings from inning names
    let team1 = null, team2 = null;
    for (const [fullName, abbr] of Object.entries(TEAM_NAME_MAP)) {
      if (inning1.inning && inning1.inning.includes(fullName)) team1 = abbr;
      if (inning2.inning && inning2.inning.includes(fullName)) team2 = abbr;
    }

    if (!team1 || !team2) continue;

    // Initialize stats
    if (!teamStats[team1]) teamStats[team1] = { runsFor: 0, oversFor: 0, runsAgainst: 0, oversAgainst: 0 };
    if (!teamStats[team2]) teamStats[team2] = { runsFor: 0, oversFor: 0, runsAgainst: 0, oversAgainst: 0 };

    const runs1 = parseInt(inning1.r) || 0;
    const runs2 = parseInt(inning2.r) || 0;
    const wkts1 = parseInt(inning1.w) || 0;
    const wkts2 = parseInt(inning2.w) || 0;
    // ICC NRR rule: if a team is all out (10 wkts), count full 20 overs
    const overs1 = wkts1 >= 10 ? 20 : cricketOvers(inning1.o);
    const overs2 = wkts2 >= 10 ? 20 : cricketOvers(inning2.o);

    // Team1 batted first: their runs scored = runs1, overs faced = overs1
    teamStats[team1].runsFor += runs1;
    teamStats[team1].oversFor += overs1;
    teamStats[team1].runsAgainst += runs2;
    teamStats[team1].oversAgainst += overs2;

    // Team2 batted second: their runs scored = runs2, overs faced = overs2
    teamStats[team2].runsFor += runs2;
    teamStats[team2].oversFor += overs2;
    teamStats[team2].runsAgainst += runs1;
    teamStats[team2].oversAgainst += overs1;
  }

  // Calculate NRR
  const nrrMap = {};
  for (const [team, s] of Object.entries(teamStats)) {
    if (s.oversFor > 0 && s.oversAgainst > 0) {
      const runRateFor = s.runsFor / s.oversFor;
      const runRateAgainst = s.runsAgainst / s.oversAgainst;
      nrrMap[team] = Math.round((runRateFor - runRateAgainst) * 1000) / 1000;
    }
  }

  return nrrMap;
}

function clearCache() {
  setCached('cricketdata_full', null, 0);
  scorecardCache.clear();
  console.log('[CricketData] All caches cleared');
}

export { fetchFromCricketData, clearCache };
