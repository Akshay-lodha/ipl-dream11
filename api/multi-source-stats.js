/**
 * GET /api/multi-source-stats
 *
 * Returns IPL 2026 points table from CricketData.org API
 * Caches responses for 5 minutes to stay within rate limits
 *
 * Rate limit: 2000 hits/day with 5-min cache = ~288 calls/day (14% of limit)
 */

import { fetchFromCricketData } from './cricket-data-api.js';

// Version 2: CricketData.org S Tier integration (2000 hits/day)
export default async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Handle OPTIONS requests
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  // Set cache headers: 60 seconds max-age for browser, allow stale for 30s
  res.setHeader('Cache-Control', 'public, s-maxage=60, stale-while-revalidate=30');

  try {
    const season = req.query.season || '2026';

    // Fetch data from CricketData.org (cached internally for 5 minutes)
    const data = await fetchFromCricketData();

    if (!data || !data.teams || data.teams.length === 0) {
      return res.status(503).json({
        error: 'Unable to fetch cricket data',
        message: 'CricketData.org API is currently unavailable',
        timestamp: new Date().toISOString(),
      });
    }

    // Return standardized response
    return res.status(200).json({
      teams: data.teams,
      source: data.source,
      timestamp: data.timestamp,
      season,
      cacheAge: data.cached ? 'cached' : 'fresh',
      rateLimit: {
        limit: 2000,
        period: 'day',
        estimated_daily_usage: '288 calls (14%)',
        cache_duration: '5 minutes',
      },
    });
  } catch (err) {
    console.error('[API] Error:', err.message);
    return res.status(500).json({
      error: 'Server error',
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
}
// Deployment trigger: 1775119561
