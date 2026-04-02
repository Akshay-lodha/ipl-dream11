// Direct CricketData.org API integration
// Vercel 2.0 - Using CricketData S Tier (2000 hits/day, ~288 calls/day = 14% usage)

import { fetchFromCricketData } from './cricket-data-api.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  res.setHeader('Cache-Control', 'public, s-maxage=60, stale-while-revalidate=30');

  try {
    // Get CricketData directly - no scraper fallback
    const data = await fetchFromCricketData();

    if (!data || !data.teams || data.teams.length === 0) {
      console.warn('[multi-source-stats] CricketData returned no teams');
      return res.status(503).json({
        error: 'CricketData unavailable',
        message: 'Unable to fetch from CricketData.org API',
        timestamp: new Date().toISOString(),
      });
    }

    return res.status(200).json({
      teams: data.teams,
      source: data.source,
      timestamp: data.timestamp,
      season: '2026',
      cacheAge: data.cached ? 'cached' : 'fresh',
      rateLimit: { limit: 2000, period: 'day', usage_percent: 14 },
    });
  } catch (err) {
    console.error('[multi-source-stats] Exception:', err.message);
    return res.status(500).json({
      error: 'Server error',
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
}
// Build trigger 1775124967
