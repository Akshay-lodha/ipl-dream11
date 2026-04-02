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
 * Scrape IPL points table from Cricbuzz
 */
async function scrapeIPLTable() {
  try {
    console.log('[Scraper] Fetching Cricbuzz points table...');

    const response = await axios.get(
      'https://www.cricbuzz.com/cricket-series/5969/indian-premier-league-2026/points-table',
      {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
        timeout: 15000,
      }
    );

    const $ = load(response.data);
    const teams = [];

    // Parse Cricbuzz points table
    // Try multiple selectors as Cricbuzz structure may vary
    const rows = $('table tbody tr, .cb-srs-item, div[class*="points"]');

    if (rows.length === 0) {
      console.log('[Scraper] No rows found, trying alternative selectors...');
      // Try alternative approach
      const teamElements = $('.cskip-4, [class*="team"]');
      console.log('[Scraper] Found', teamElements.length, 'elements with alternative selector');
    }

    rows.each((index, element) => {
      try {
        const cells = $(element).find('td, div[class*="cell"]');
        if (cells.length < 4) return; // Need at least team, matches, wins, losses

        const teamName = $(cells[0]).text().trim();
        const matches = parseInt($(cells[1]).text()) || 0;
        const wins = parseInt($(cells[2]).text()) || 0;
        const losses = parseInt($(cells[3]).text()) || 0;

        // NRR might be in different position
        let nrr = 0;
        for (let i = 0; i < cells.length; i++) {
          const text = $(cells[i]).text().trim();
          if (text.includes('.') && !isNaN(parseFloat(text))) {
            nrr = parseFloat(text);
            break;
          }
        }

        // Points is usually last
        const pts = parseInt($(cells[cells.length - 1]).text()) || 0;

        if (teamName && matches > 0) {
          // Normalize team name to abbreviation
          const abbr = teamName
            .substring(0, 4)
            .toUpperCase()
            .replace(/\s/g, '');

          teams.push({
            team: abbr,
            m: matches,
            w: wins,
            l: losses,
            nrr: Math.round(nrr * 1000) / 1000, // Round to 3 decimals
            pts,
            form: [],
          });
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

    console.warn(`[Scraper] Parsed ${teams.length} teams, expected 10. HTML structure may have changed.`);
    return null;

  } catch (err) {
    console.error('[Scraper] Error scraping Cricbuzz:', err.message);
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
    },
    cache: {
      enabled: true,
      duration: '30 minutes',
      currentTeams: cachedTeams?.length || 0,
      lastUpdate: lastScrapedAt,
    },
  });
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
