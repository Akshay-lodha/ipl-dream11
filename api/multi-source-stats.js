/**
 * GET /api/multi-source-stats
 *
 * Fetches IPL 2026 points table from multiple sources with fallback strategy.
 * Implements a priority-based cascade ensuring data reliability.
 *
 * SOURCES (in priority order):
 * 1. Primary: CricketData.org (requires API_KEY env var)
 *    - Rate: 100K calls/hour
 *    - Data: Live scores, standings, schedules
 *    - Setup: Get key from https://cricketdata.org/, set CRICKETDATA_API_KEY env var
 *
 * 2. Fallback 1: Roanuz Cricket API (free tier, requires API_KEY)
 *    - Rate: Varies, free tier available
 *    - Data: Live scores, standings, player stats
 *    - Setup: Get key from https://www.cricketapi.com/, set ROANUZ_API_KEY env var
 *
 * 3. Fallback 2: IPL 2025 API (GitHub)
 *    - Rate: No limits (community project, be respectful)
 *    - Status: CURRENTLY SUSPENDED (service owner has disabled it)
 *    - Alternative: Could be replaced with other open-source cricket APIs
 *
 * 4. Final Fallback: Hardcoded historical data
 *    - Used when all APIs fail
 *    - Manual update required: Update FALLBACK_DATA with latest match results
 *    - Edit MATCH_DATA_2026 array to add new match scores
 *
 * USAGE:
 * - Endpoint returns { teams, source, timestamp } showing which source was used
 * - Data is cached for 5 minutes to reduce API calls
 * - All team names are normalized to IPL abbreviations (MI, RCB, DC, etc)
 */

import { getCached, setCached } from './cache.js';

const TEAM_MAP = {
  'Mumbai Indians': 'MI',
  'Chennai Super Kings': 'CSK',
  'Royal Challengers Bengaluru': 'RCB',
  'Royal Challengers Bangalore': 'RCB',
  'Delhi Capitals': 'DC',
  'Gujarat Titans': 'GT',
  'Kolkata Knight Riders': 'KKR',
  'Sunrisers Hyderabad': 'SRH',
  'Rajasthan Royals': 'RR',
  'Lucknow Super Giants': 'LSG',
  'Punjab Kings': 'PBKS',
};

function resolveTeam(name = '') {
  if (TEAM_MAP[name]) return TEAM_MAP[name];
  for (const [full, abbr] of Object.entries(TEAM_MAP)) {
    if (name.toLowerCase().includes(abbr.toLowerCase())) return abbr;
  }
  return name.toUpperCase().slice(0, 4);
}

// Hardcoded fallback data (last resort)
const FALLBACK_DATA = {
  teams: [
    { team: 'RCB', m: 1, w: 1, l: 0, nrr: 0.13, pts: 2, form: ['W'] },
    { team: 'DC', m: 1, w: 1, l: 0, nrr: 0, pts: 2, form: ['W'] },
    { team: 'MI', m: 1, w: 1, l: 0, nrr: 0, pts: 2, form: ['W'] },
    { team: 'PBKS', m: 1, w: 1, l: 0, nrr: 0, pts: 2, form: ['W'] },
    { team: 'RR', m: 1, w: 1, l: 0, nrr: 0, pts: 2, form: ['W'] },
    { team: 'CSK', m: 1, w: 0, l: 1, nrr: 0, pts: 0, form: ['L'] },
    { team: 'GT', m: 1, w: 0, l: 1, nrr: 0, pts: 0, form: ['L'] },
    { team: 'KKR', m: 1, w: 0, l: 1, nrr: 0, pts: 0, form: ['L'] },
    { team: 'LSG', m: 1, w: 0, l: 1, nrr: 0, pts: 0, form: ['L'] },
    { team: 'SRH', m: 1, w: 0, l: 1, nrr: -0.1, pts: 0, form: ['L'] },
  ]
};

// API Source 1: Self-Hosted Scraper (Primary - zero rate limits)
async function fetchFromCricketData(seriesId) {
  try {
    // CricketData.org free tier: 100,000 calls/hour
    // Get key from: https://cricketdata.org/ (sign up, then get API key from dashboard)
    const apiKey = process.env.CRICKET_API_KEY || process.env.CRICKETDATA_API_KEY;
    if (!apiKey) return null;

    const url = `https://cricketdata.org/api/v1/series_points?apikey=${apiKey}&id=${seriesId}`;
    const res = await fetch(url, { timeout: 5000 });
    if (!res.ok) return null;

    const json = await res.json();
    if (json.status !== 'success' || !Array.isArray(json.data)) return null;

    // Transform to standard format
    const teams = json.data.map(row => ({
      team: resolveTeam(row.teamname || row.shortname || ''),
      m: row.matches || 0,
      w: row.wins || 0,
      l: row.loss || 0,
      nrr: parseFloat(row.nrr || 0),
      pts: (row.wins * 2) + (row.ties || 0),
      form: [],
    }));

    return { teams, source: 'CricketData.org (100K calls/hour)' };
  } catch (err) {
    console.warn('[multi-source] CricketData fetch failed:', err.message);
    return null;
  }
}

// API Source 2: Roanuz Cricket API (Fallback 1 - free tier)
async function fetchFromRoanuz(seriesId) {
  try {
    // Roanuz uses different endpoint structure, attempt basic fetch
    const url = `https://api.cricapi.com/v1/series_points?apikey=free&id=${seriesId}`;
    const res = await fetch(url, { timeout: 5000 });
    if (!res.ok) return null;

    const json = await res.json();
    if (json.status !== 'success' || !Array.isArray(json.data)) return null;

    const teams = json.data.map(row => ({
      team: resolveTeam(row.teamname || row.shortname || ''),
      m: row.matches || 0,
      w: row.wins || 0,
      l: row.loss || 0,
      nrr: parseFloat(row.nrr || 0),
      pts: (row.wins * 2) + (row.ties || 0),
      form: [],
    }));

    return { teams, source: 'Roanuz Cricket API' };
  } catch (err) {
    console.warn('[multi-source] Roanuz fetch failed:', err.message);
    return null;
  }
}

// API Source 3: IPL 2025 API from GitHub (Fallback 2 - no limits)
async function fetchFromIPLAPI() {
  try {
    const url = 'https://ipl-okn0.onrender.com/ipl-2025-points-table';
    const res = await fetch(url, { timeout: 5000 });
    if (!res.ok) return null;

    const data = await res.json();
    if (!data || typeof data !== 'object') return null;

    // Transform from IPL API format to standard format
    const teams = Object.entries(data).map(([team, stats]) => ({
      team: team.toUpperCase(),
      m: stats.matches || 0,
      w: stats.wins || 0,
      l: stats.losses || 0,
      nrr: parseFloat(stats.nrr || 0),
      pts: stats.points || 0,
      form: [],
    }));

    if (teams.length < 5) return null; // Sanity check
    return { teams, source: 'IPL 2025 API (GitHub)' };
  } catch (err) {
    console.warn('[multi-source] IPL API fetch failed:', err.message);
    return null;
  }
}

// Validate data quality
function isValidResponse(data) {
  if (!data || !data.teams || !Array.isArray(data.teams)) return false;
  if (data.teams.length < 8) return false; // Should have at least 8+ teams

  // Check for meaningful data (at least some teams with match data)
  const hasMatchData = data.teams.some(t => t.m > 0);
  return hasMatchData;
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  const season = req.query.season || '2026';
  const cacheAge = 60; // 1 min cache (fast updates from manual admin dashboard)
  res.setHeader('Cache-Control', `s-maxage=${cacheAge}, stale-while-revalidate=30`);

  const cacheKey = `multi-source-stats_${season}`;

  try {
    // Check cache first
    const cached = getCached(cacheKey);
    if (cached) {
      return res.status(200).json(cached);
    }

    // Series IDs - adjust based on season
    const seriesId = '87c62aac-bc3c-4738-ab93-19da0690488f'; // IPL 2026 ID

    let result = null;
    let source = null;

    // Try sources in priority order
    console.log(`[multi-source] Attempting to fetch 2026 IPL data...`);

    // 1. Try Primary: Self-Hosted Scraper (no rate limits)
    console.log('[multi-source] Trying source 0: Self-Hosted Scraper');
    try {
      const scraperUrl = process.env.SCRAPER_URL || 'https://web-production-c548f.up.railway.app';
      const scraperRes = await fetch(`${scraperUrl}/api/teams`);
      if (scraperRes.ok) {
        const scraperData = await scraperRes.json();
        if (scraperData.teams && scraperData.teams.length > 0) {
          console.log(`[multi-source] ✓ Using Self-Hosted Scraper`);
          return res.status(200).json({
            teams: scraperData.teams,
            source: scraperData.source || 'Self-Hosted Scraper (Cricbuzz)',
            timestamp: new Date().toISOString(),
          });
        }
      }
    } catch (e) {
      console.warn('[multi-source] Scraper fetch failed:', e.message);
    }

    // 2. Try: CricketData.org
    console.log('[multi-source] Trying source 1: CricketData.org');
    result = await fetchFromCricketData(seriesId);
    if (isValidResponse(result)) {
      source = result.source;
      console.log(`[multi-source] ✓ Using ${source}`);
    }

    // 3. Try Fallback: Roanuz
    if (!result) {
      console.log('[multi-source] Trying source 2: Roanuz Cricket API');
      result = await fetchFromRoanuz(seriesId);
      if (isValidResponse(result)) {
        source = result.source;
        console.log(`[multi-source] ✓ Using ${source}`);
      }
    }

    // 4. Try Fallback: IPL 2025 API
    if (!result) {
      console.log('[multi-source] Trying source 3: IPL 2025 API (GitHub)');
      result = await fetchFromIPLAPI();
      if (isValidResponse(result)) {
        source = result.source;
        console.log(`[multi-source] ✓ Using ${source}`);
      }
    }

    // 5. Fall back to hardcoded data
    if (!result) {
      console.log('[multi-source] All sources failed, using hardcoded fallback');
      result = FALLBACK_DATA;
      source = 'Hardcoded Data (Fallback)';
    }

    // Sort by points desc, then nrr desc
    result.teams.sort((a, b) => b.pts - a.pts || b.nrr - a.nrr);

    const response = {
      teams: result.teams,
      source: source,
      timestamp: new Date().toISOString(),
    };

    setCached(cacheKey, response, 3600);
    return res.status(200).json(response);

  } catch (err) {
    console.error('[multi-source] Error:', err.message);
    return res.status(502).json({
      error: 'Failed to fetch team stats',
      detail: err.message,
      fallback: FALLBACK_DATA.teams,
    });
  }
}
