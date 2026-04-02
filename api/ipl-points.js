// IPL 2026 Live Points Table
// Powered by CricketData.org S Tier API (2000 hits/day limit)
// Internal 5-minute cache keeps daily usage at ~288 calls (14% of limit)

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
    const data = await fetchFromCricketData();

    if (!data || !data.teams || data.teams.length === 0) {
      return res.status(503).json({
        error: 'Unable to fetch cricket data',
        message: 'CricketData.org API unavailable',
        timestamp: new Date().toISOString(),
      });
    }

    return res.status(200).json({
      teams: data.teams,
      source: data.source,
      timestamp: data.timestamp,
      season: '2026',
      cacheAge: data.cached ? 'cached' : 'fresh',
      rateLimit: {
        limit: 2000,
        period: 'day',
        estimated_daily_usage: '288 calls (14%)',
        cache_duration: '5 minutes',
      },
    });
  } catch (err) {
    console.error('[ipl-points] Error:', err.message);
    return res.status(500).json({
      error: 'Server error',
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
}
