/**
 * Self-hosted Cricket Data Scraper
 * Scrapes Cricbuzz for IPL 2026 data
 * Zero rate limits - runs on your own infrastructure
 *
 * GET /api/scraper-service?season=2026
 * Returns: { teams, source, timestamp }
 */

import { getCached, setCached } from './cache.js';

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

// Scrape Cricbuzz for live IPL data
async function scrapeCricbuzz() {
  try {
    // Cricbuzz points table URL (may need updating if structure changes)
    const url = 'https://www.cricbuzz.com/cricket-series/5969/indian-premier-league-2026/points-table';

    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
      timeout: 10000,
    });

    if (!response.ok) {
      console.warn('[scraper] Cricbuzz returned status:', response.status);
      return null;
    }

    const html = await response.text();

    // Parse HTML to extract standings
    // Note: Cricbuzz HTML structure can change, this is a basic parser
    const teams = [];

    // Look for team rows in the table
    // Pattern: team name, matches, wins, losses, NRR, points
    const teamRowRegex = /(?:<tr|class="cb-srs-item">)(.*?)(?:<\/tr|<\/div>)/gs;
    const rows = html.match(teamRowRegex) || [];

    if (rows.length === 0) {
      console.warn('[scraper] No team rows found in Cricbuzz HTML');
      return null;
    }

    // Extract data from each row
    const teamCodeMap = {
      'Mumbai Indians': 'MI',
      'Chennai Super Kings': 'CSK',
      'Royal Challengers': 'RCB',
      'Rajasthan Royals': 'RR',
      'Delhi Capitals': 'DC',
      'Kolkata Knight Riders': 'KKR',
      'Sunrisers Hyderabad': 'SRH',
      'Punjab Kings': 'PBKS',
      'Gujarat Titans': 'GT',
      'Lucknow Super Giants': 'LSG',
    };

    for (const row of rows) {
      // Extract team name
      const nameMatch = row.match(/>(.*?)<\/a>/);
      if (!nameMatch) continue;

      const fullName = nameMatch[1].trim();
      const team = Object.entries(teamCodeMap).find(([key]) =>
        fullName.includes(key)
      )?.[1];

      if (!team) continue;

      // Extract matches, wins, losses
      const numbers = row.match(/\d+/g) || [];
      if (numbers.length < 3) continue;

      const m = parseInt(numbers[0], 10);
      const w = parseInt(numbers[1], 10);
      const l = parseInt(numbers[2], 10);
      const pts = parseInt(numbers[numbers.length - 1], 10);

      // Extract NRR
      const nrrMatch = row.match(/([+-]?\d+\.\d+)/);
      const nrr = nrrMatch ? parseFloat(nrrMatch[1]) : 0;

      teams.push({
        team,
        m,
        w,
        l,
        nrr,
        pts,
        form: [],
      });
    }

    if (teams.length < 5) {
      console.warn('[scraper] Found only', teams.length, 'teams, expected 10');
      return null;
    }

    teams.sort((a, b) => b.pts - a.pts || b.nrr - a.nrr);
    return { teams, source: 'Cricbuzz (Self-Hosted Scraper)' };

  } catch (err) {
    console.warn('[scraper] Cricbuzz scraping failed:', err.message);
    return null;
  }
}

// Alternative: Scrape from JSON API endpoint if available
async function scrapeFromAlternativeSource() {
  try {
    // Try multiple cricket data sources
    const sources = [
      'https://api.cricapi.com/v1/series_points?apikey=free&id=87c62aac-bc3c-4738-ab93-19da0690488f',
      'https://www.cricket-data.com/api/ipl-standings', // hypothetical
    ];

    for (const url of sources) {
      try {
        const res = await fetch(url, { timeout: 5000 });
        if (res.ok) {
          const data = await res.json();
          if (data && data.data && Array.isArray(data.data)) {
            const teams = data.data.slice(0, 10).map(row => ({
              team: row.teamname?.toUpperCase().slice(0, 4) || 'UNKNOWN',
              m: row.matches || 0,
              w: row.wins || 0,
              l: row.loss || 0,
              nrr: parseFloat(row.nrr || 0),
              pts: (row.wins * 2) + (row.ties || 0),
              form: [],
            }));
            return { teams, source: 'Cricket Data API (Fallback)' };
          }
        }
      } catch (e) {
        // Continue to next source
      }
    }

    return null;
  } catch (err) {
    console.warn('[scraper] Alternative source failed:', err.message);
    return null;
  }
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  const season = req.query.season || '2026';

  // Cache for 30 minutes (self-hosted scraper is slow)
  const cacheAge = 1800;
  res.setHeader('Cache-Control', `s-maxage=${cacheAge}, stale-while-revalidate=60`);

  const cacheKey = `scraper-service_${season}`;

  try {
    // Check cache first
    const cached = getCached(cacheKey);
    if (cached) {
      return res.status(200).json(cached);
    }

    console.log('[scraper] Cache miss, fetching fresh data...');

    let result = null;

    // Try Cricbuzz scraper
    console.log('[scraper] Attempting Cricbuzz scrape...');
    result = await scrapeCricbuzz();
    if (result) {
      console.log('[scraper] ✓ Cricbuzz scrape successful');
      setCached(cacheKey, result, 3600);
      return res.status(200).json(result);
    }

    // Try alternative sources
    console.log('[scraper] Cricbuzz failed, trying alternative sources...');
    result = await scrapeFromAlternativeSource();
    if (result) {
      console.log('[scraper] ✓ Alternative source successful');
      setCached(cacheKey, result, 3600);
      return res.status(200).json(result);
    }

    // Fall back to hardcoded data
    console.log('[scraper] All sources failed, using fallback');
    const response = {
      teams: FALLBACK_DATA.teams,
      source: 'Hardcoded Fallback (Scraper unavailable)',
      timestamp: new Date().toISOString(),
    };

    setCached(cacheKey, response, 300); // Cache fallback for 5 min
    return res.status(200).json(response);

  } catch (err) {
    console.error('[scraper] Error:', err.message);
    return res.status(502).json({
      error: 'Scraper service error',
      detail: err.message,
      fallback: FALLBACK_DATA.teams,
      source: 'Hardcoded Fallback',
    });
  }
}
