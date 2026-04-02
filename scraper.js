#!/usr/bin/env node

/**
 * Self-Hosted IPL Data Scraper
 * Runs as standalone service - no rate limits
 * Deploy to Railway, Render, or any Node.js host
 */

import axios from 'axios';
import { load } from 'cheerio';
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

// In-memory cache
let cachedTeams = null;
let lastScrapedAt = null;
const CACHE_DURATION_MS = 30 * 60 * 1000; // 30 minutes

// Fallback data
const FALLBACK_TEAMS = [
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
];

/**
 * Scrape IPL points table from ESPN Cricinfo
 */
async function scrapeFromESPNCricinfo() {
  try {
    console.log('[Scraper] Trying ESPN Cricinfo...');
    const response = await axios.get(
      'https://www.espncricinfo.com/cricket/series/indian-premier-league-2026-1410320/points-table',
      {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        timeout: 15000,
      }
    );

    const $ = load(response.data);
    const teams = [];
    const rows = $('table tbody tr, tr[class*="row"]');

    if (rows.length < 8) {
      console.log('[Scraper] ESPN Cricinfo: Not enough rows found');
      return null;
    }

    rows.each((index, element) => {
      try {
        const cells = $(element).find('td');
        if (cells.length < 5) return;

        const teamCell = $(cells[0]).text().trim();
        const mText = $(cells[1]).text().trim();
        const wText = $(cells[2]).text().trim();
        const lText = $(cells[3]).text().trim();

        const matches = parseInt(mText) || 0;
        const wins = parseInt(wText) || 0;
        const losses = parseInt(lText) || 0;

        // Extract NRR
        let nrr = 0;
        for (let i = 4; i < cells.length; i++) {
          const cellText = $(cells[i]).text().trim();
          if (cellText.includes('.') || cellText === '-') {
            nrr = parseFloat(cellText) || 0;
            break;
          }
        }

        // Points is usually last
        const pts = parseInt($(cells[cells.length - 1]).text()) || 0;

        if (teamCell && matches > 0) {
          const abbr = teamCell.substring(0, 4).toUpperCase().replace(/\s/g, '');
          if (abbr.length >= 2) {
            teams.push({
              team: abbr,
              m: matches,
              w: wins,
              l: losses,
              nrr: Math.round(nrr * 1000) / 1000,
              pts,
              form: [],
            });
          }
        }
      } catch (e) {
        // Silently continue
      }
    });

    if (teams.length >= 8) {
      console.log(`[Scraper] ✓ ESPN Cricinfo: Scraped ${teams.length} teams`);
      return teams.sort((a, b) => b.pts - a.pts || b.nrr - a.nrr);
    }
    return null;
  } catch (err) {
    console.log('[Scraper] ESPN Cricinfo failed:', err.message);
    return null;
  }
}

/**
 * Scrape IPL points table from Cricbuzz
 */
async function scrapeIPLTable() {
  try {
    console.log('[Scraper] Fetching Cricbuzz points table...');

    const response = await axios.get(
      'https://www.cricbuzz.com/cricket-series/5969/indian-premier-league-2026/points-table',
      {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        timeout: 15000,
      }
    );

    const $ = load(response.data);
    const teams = [];

    // Try to find the points table - Cricbuzz uses various table structures
    let rows = $('table tbody tr');

    if (rows.length === 0) {
      console.log('[Scraper] Standard table not found, trying alternative selectors...');
      rows = $('tr[class*="row"]');
    }

    if (rows.length === 0) {
      console.log('[Scraper] No table rows found at all');
      return null;
    }

    console.log(`[Scraper] Found ${rows.length} rows, attempting to parse...`);

    rows.each((index, element) => {
      try {
        const $row = $(element);
        const cells = $row.find('td');

        if (cells.length < 5) return; // Need minimum columns

        // Extract text from each cell, handling nested elements
        const teamCell = $(cells[0]).text().trim();
        const mText = $(cells[1]).text().trim();
        const wText = $(cells[2]).text().trim();
        const lText = $(cells[3]).text().trim();

        // Find NRR (usually has decimal point)
        let nrr = 0;
        let nrrCell = -1;
        for (let i = 3; i < cells.length; i++) {
          const cellText = $(cells[i]).text().trim();
          if ((cellText.includes('.') || cellText === '-') && !isNaN(parseFloat(cellText || '0'))) {
            nrr = parseFloat(cellText) || 0;
            nrrCell = i;
            break;
          }
        }

        // Points is usually after NRR
        let pts = 0;
        if (nrrCell >= 0) {
          const ptsText = $(cells[nrrCell + 1]).text().trim();
          pts = parseInt(ptsText) || 0;
        } else {
          pts = parseInt($(cells[cells.length - 1]).text()) || 0;
        }

        const matches = parseInt(mText) || 0;
        const wins = parseInt(wText) || 0;
        const losses = parseInt(lText) || 0;

        // Only add if we have a team name and valid match data
        if (teamCell && matches > 0) {
          // Extract team abbreviation from full name
          const abbr = teamCell
            .split(/\s+/)[0] // Get first word
            .substring(0, 4)
            .toUpperCase()
            .replace(/\W/g, '');

          if (abbr.length >= 2) {
            teams.push({
              team: abbr,
              m: matches,
              w: wins,
              l: losses,
              nrr: Math.round(nrr * 1000) / 1000,
              pts,
              form: [],
            });
            console.log(`[Scraper] Parsed: ${abbr} - ${matches}M ${wins}W ${losses}L ${pts}pts NRR:${nrr}`);
          }
        }
      } catch (err) {
        console.warn('[Scraper] Error parsing row:', err.message);
      }
    });

    // Validate results
    if (teams.length >= 8) {
      console.log(`[Scraper] ✓ Successfully scraped ${teams.length} teams`);
      cachedTeams = teams.sort((a, b) => b.pts - a.pts || b.nrr - a.nrr);
      lastScrapedAt = new Date();
      return cachedTeams;
    }

    // If Cricbuzz fails, try ESPN Cricinfo
    console.warn(`[Scraper] Cricbuzz failed (${teams.length} teams). Trying ESPN Cricinfo...`);
    const espnTeams = await scrapeFromESPNCricinfo();
    if (espnTeams && espnTeams.length >= 8) {
      cachedTeams = espnTeams;
      lastScrapedAt = new Date();
      return espnTeams;
    }

    console.warn(`[Scraper] Both sources failed. Using fallback data.`);
    return null;

  } catch (err) {
    console.error('[Scraper] Error scraping Cricbuzz:', err.message);
    // Try ESPN Cricinfo as fallback
    const espnTeams = await scrapeFromESPNCricinfo();
    if (espnTeams && espnTeams.length >= 8) {
      cachedTeams = espnTeams;
      lastScrapedAt = new Date();
      return espnTeams;
    }
    return null;
  }
}

/**
 * API Endpoints
 */

// Get teams data
app.get('/api/teams', async (req, res) => {
  try {
    // Check if cache is still fresh
    if (cachedTeams && lastScrapedAt) {
      const cacheAge = Date.now() - lastScrapedAt.getTime();
      if (cacheAge < CACHE_DURATION_MS) {
        return res.json({
          teams: cachedTeams,
          source: 'Self-Hosted Scraper (Cached)',
          lastScraped: lastScrapedAt,
          cacheAgeMs: cacheAge,
          cached: true,
        });
      }
    }

    // Cache expired or doesn't exist - scrape fresh data
    const teams = await scrapeIPLTable();

    if (teams && teams.length > 0) {
      return res.json({
        teams,
        source: 'Self-Hosted Scraper (Live)',
        lastScraped: lastScrapedAt,
        cached: false,
      });
    }

    // Fallback to hardcoded data
    console.warn('[Scraper] Returning fallback data');
    return res.status(206).json({
      teams: FALLBACK_TEAMS,
      source: 'Fallback Data',
      lastScraped: lastScrapedAt,
      warning: 'Live scraping failed, using cached fallback',
    });

  } catch (err) {
    console.error('[Scraper] API error:', err.message);
    return res.status(503).json({
      error: 'Service unavailable',
      message: err.message,
      teams: cachedTeams || FALLBACK_TEAMS,
      source: 'Fallback',
    });
  }
});

// Health check
app.get('/health', (req, res) => {
  const cacheAgeMs = lastScrapedAt ? Date.now() - lastScrapedAt.getTime() : null;
  const cacheStatus = !lastScrapedAt ? 'empty' : cacheAgeMs < CACHE_DURATION_MS ? 'fresh' : 'stale';

  res.json({
    status: 'ok',
    uptime: process.uptime(),
    lastScrape: lastScrapedAt,
    cacheStatus,
    cachedTeams: cachedTeams?.length || 0,
    memory: process.memoryUsage(),
  });
});

// Status endpoint
app.get('/status', (req, res) => {
  res.json({
    service: 'IPL Data Scraper',
    version: '1.0.0',
    status: 'running',
    endpoints: {
      teams: '/api/teams',
      health: '/health',
      status: '/status',
      update: '/api/update (POST)',
    },
    cache: {
      enabled: true,
      duration: '30 minutes',
      currentTeams: cachedTeams?.length || 0,
      lastUpdate: lastScrapedAt,
    },
  });
});

// Manual update endpoint - POST new teams data
app.post('/api/update', (req, res) => {
  try {
    const { teams, secret } = req.body;

    // Simple auth check
    const UPDATE_SECRET = process.env.UPDATE_SECRET || 'manual-update-2026';
    if (secret !== UPDATE_SECRET) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (!Array.isArray(teams) || teams.length < 8) {
      return res.status(400).json({
        error: 'Invalid data',
        message: 'Expected array of teams with at least 8 entries',
      });
    }

    // Validate team structure
    const validTeams = teams.map(t => ({
      team: String(t.team).toUpperCase(),
      m: parseInt(t.m) || 0,
      w: parseInt(t.w) || 0,
      l: parseInt(t.l) || 0,
      nrr: parseFloat(t.nrr) || 0,
      pts: parseInt(t.pts) || 0,
      form: Array.isArray(t.form) ? t.form : [],
    }));

    // Sort by points and NRR
    cachedTeams = validTeams.sort((a, b) => b.pts - a.pts || b.nrr - a.nrr);
    lastScrapedAt = new Date();

    console.log(`[Manual Update] Updated ${cachedTeams.length} teams at ${lastScrapedAt.toISOString()}`);

    res.json({
      success: true,
      message: `Updated ${cachedTeams.length} teams`,
      lastUpdate: lastScrapedAt,
      teams: cachedTeams,
    });
  } catch (err) {
    console.error('[Manual Update] Error:', err.message);
    res.status(500).json({ error: 'Update failed', message: err.message });
  }
});

/**
 * Start server
 */
const PORT = process.env.PORT || 3000;

// Initial scrape on startup
console.log('[Scraper] Starting IPL data scraper...');
await scrapeIPLTable();

// Periodic scraping every 30 minutes
setInterval(() => {
  console.log('[Scraper] Running scheduled scrape...');
  scrapeIPLTable();
}, CACHE_DURATION_MS);

app.listen(PORT, () => {
  console.log(`[Scraper] ✓ Server running on http://localhost:${PORT}`);
  console.log(`[Scraper] API: http://localhost:${PORT}/api/teams`);
  console.log(`[Scraper] Health: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[Scraper] SIGTERM received, shutting down gracefully...');
  process.exit(0);
});
