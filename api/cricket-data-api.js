/**
 * CricketData.org API Integration
 *
 * Fetches IPL 2026 points table directly from CricketData.org
 * 5-minute caching keeps us well within 2000 hits/day limit
 *
 * API Docs: https://cricketdata.org/docs
 */

import { getCached, setCached } from './cache.js';

const API_KEY = process.env.CRICKETDATA_API_KEY;
const CACHE_TTL = 300; // 5 minutes in seconds
const CACHE_KEY = 'cricketdata_ipl_2026_points';

// IPL 2026 Series ID from CricketData
const IPL_2026_SERIES_ID = '5969'; // IPL 2026

/**
 * Fetch points table from CricketData.org
 * Returns normalized team data with caching
 */
async function fetchFromCricketData() {
  try {
    // Check cache first
    const cached = getCached(CACHE_KEY);
    if (cached) {
      console.log('[CricketData] Returning cached data');
      return cached;
    }

    console.log('[CricketData] Fetching fresh data from API...');

    // Call CricketData API for points table
    const response = await fetch(
      `https://api.cricapi.com/v1/series_points?apikey=${API_KEY}&id=${IPL_2026_SERIES_ID}`
    );

    if (!response.ok) {
      console.error(`[CricketData] API Error: ${response.status}`);
      return null;
    }

    const data = await response.json();

    // Normalize CricketData response to our format
    if (!data.data || !Array.isArray(data.data)) {
      console.warn('[CricketData] Invalid response format');
      return null;
    }

    const teams = data.data.map(team => ({
      team: normalizeTeamName(team.short_name || team.name || ''),
      m: parseInt(team.matches) || 0,
      w: parseInt(team.wins) || 0,
      l: parseInt(team.losses) || 0,
      nrr: parseFloat(team.nrr) || 0,
      pts: parseInt(team.points) || 0,
      form: parseForm(team.recent_form || ''),
    }));

    // Sort by points and NRR
    teams.sort((a, b) => b.pts - a.pts || b.nrr - a.nrr);

    const result = {
      teams,
      source: 'CricketData.org API',
      timestamp: new Date().toISOString(),
      cached: false,
    };

    // Cache for 5 minutes
    setCached(CACHE_KEY, result, CACHE_TTL);
    console.log(`[CricketData] ✓ Fetched and cached ${teams.length} teams`);

    return result;
  } catch (err) {
    console.error('[CricketData] Fetch error:', err.message);
    return null;
  }
}

/**
 * Normalize team names to IPL abbreviations
 */
function normalizeTeamName(name) {
  const teamMap = {
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

  return teamMap[name] || name.substring(0, 4).toUpperCase();
}

/**
 * Parse recent form string (e.g., "WLWWL") to array
 */
function parseForm(formStr) {
  if (!formStr) return [];
  return formStr.split('').slice(0, 5); // Last 5 matches
}

/**
 * Clear cache (useful for manual updates)
 */
function clearCache() {
  setCached(CACHE_KEY, null, 0);
  console.log('[CricketData] Cache cleared');
}

export { fetchFromCricketData, clearCache };
