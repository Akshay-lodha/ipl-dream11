// IPL 2026 Points Table Endpoint - CricketData.org API
// This endpoint fetches live IPL standings from CricketData.org S Tier (2000 hits/day)
// 5-minute internal caching keeps us at ~288 calls/day = 14% of limit

import { fetchFromCricketData } from './cricket-data-api.js';

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

  // Set cache headers: 60 seconds max-age for browser, 300 seconds server-side
  res.setHeader('Cache-Control', 'public, s-maxage=60, stale-while-revalidate=30');

  try {
    const season = req.query.season || '2026';

    // Fetch from CricketData.org (cached internally for 5 minutes)
    const data = await fetchFromCricketData();

    if (!data || !data.teams || data.teams.length === 0) {
      return res.status(503).json({
        error: 'Unable to fetch cricket data',
        message: 'CricketData.org API is currently unavailable',
        timestamp: new Date().toISOString(),
      });
    }

    // Return response with rate limit info
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
