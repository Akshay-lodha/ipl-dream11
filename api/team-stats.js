/**
 * GET /api/team-stats
 *
 * Returns IPL 2026 points table with calculated NRR and Form.
 * For now, uses hardcoded match data from early season to avoid API rate limits.
 */

import { getCached, setCached } from './cache.js';

// Hardcoded 2026 early season match results (matches played so far)
const MATCH_DATA_2026 = [
  { t1: 'RCB', t2: 'SRH', winner: 'RCB', t1_runs: 203, t2_runs: 201, t1_overs: 15.4, t2_overs: 20 },
  { t1: 'MI', t2: 'KKR', winner: 'MI', t1_runs: 0, t2_runs: 0, t1_overs: 0, t2_overs: 0 }, // data not available yet
  { t1: 'RR', t2: 'CSK', winner: 'RR', t1_runs: 0, t2_runs: 0, t1_overs: 0, t2_overs: 0 }, // data not available yet
  { t1: 'PBKS', t2: 'GT', winner: 'PBKS', t1_runs: 0, t2_runs: 0, t1_overs: 0, t2_overs: 0 }, // data not available yet
  { t1: 'LSG', t2: 'DC', winner: 'DC', t1_runs: 0, t2_runs: 0, t1_overs: 0, t2_overs: 0 }, // data not available yet
];

// Initial standings based on matches played
const STANDINGS_2026 = {
  'DC':   { m: 1, w: 1, l: 0, pts: 2 },
  'MI':   { m: 1, w: 1, l: 0, pts: 2 },
  'PBKS': { m: 1, w: 1, l: 0, pts: 2 },
  'RR':   { m: 1, w: 1, l: 0, pts: 2 },
  'RCB':  { m: 1, w: 1, l: 0, pts: 2 },
  'CSK':  { m: 1, w: 0, l: 1, pts: 0 },
  'GT':   { m: 1, w: 0, l: 1, pts: 0 },
  'KKR':  { m: 1, w: 0, l: 1, pts: 0 },
  'LSG':  { m: 1, w: 0, l: 1, pts: 0 },
  'SRH':  { m: 1, w: 0, l: 1, pts: 0 },
};

const TEAMS = ['DC', 'MI', 'PBKS', 'RR', 'RCB', 'CSK', 'GT', 'KKR', 'LSG', 'SRH'];

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  const season = req.query.season || '2026';
  const cacheAge = 300; // 5 min cache for developing season
  res.setHeader('Cache-Control', `s-maxage=${cacheAge}, stale-while-revalidate=60`);

  const cacheKey = `team-stats_${season}`;

  try {
    const cached = getCached(cacheKey);
    if (cached) {
      return res.status(200).json(cached);
    }

    // Calculate NRR and Form from hardcoded match data
    const teamStats = {};

    // Initialize all teams
    TEAMS.forEach(team => {
      const standing = STANDINGS_2026[team] || { m: 0, w: 0, l: 0, pts: 0 };
      teamStats[team] = {
        team,
        m: standing.m,
        w: standing.w,
        l: standing.l,
        pts: standing.pts,
        nrr: 0,
        form: [],
        runsFor: 0,
        runsAgainst: 0,
        oversPlayed: 0,
      };
    });

    // Process matches
    MATCH_DATA_2026.forEach(match => {
      const { t1, t2, winner, t1_runs, t2_runs, t1_overs, t2_overs } = match;

      if (teamStats[t1] && teamStats[t2]) {
        // Update NRR data if scores available
        if (t1_runs > 0 && t2_runs > 0) {
          teamStats[t1].runsFor += t1_runs;
          teamStats[t1].runsAgainst += t2_runs;
          teamStats[t1].oversPlayed += t1_overs;

          teamStats[t2].runsFor += t2_runs;
          teamStats[t2].runsAgainst += t1_runs;
          teamStats[t2].oversPlayed += t2_overs;
        }

        // Update form
        teamStats[t1].form.push(winner === t1 ? 'W' : 'L');
        teamStats[t2].form.push(winner === t2 ? 'W' : 'L');
      }
    });

    // Calculate NRR
    const teams = TEAMS.map(team => {
      const stats = teamStats[team];
      let nrr = 0;
      if (stats.oversPlayed > 0) {
        nrr = parseFloat(((stats.runsFor - stats.runsAgainst) / stats.oversPlayed).toFixed(3));
      }
      return {
        team: stats.team,
        m: stats.m,
        w: stats.w,
        l: stats.l,
        nrr,
        pts: stats.pts,
        form: stats.form,
      };
    });

    // Sort by points desc, then nrr desc
    teams.sort((a, b) => b.pts - a.pts || b.nrr - a.nrr);

    const response = { teams };
    setCached(cacheKey, response, 3600);

    return res.status(200).json(response);
  } catch (err) {
    console.error('[team-stats]', err.message);
    return res.status(502).json({ error: 'Failed to fetch team stats', detail: err.message });
  }
}
