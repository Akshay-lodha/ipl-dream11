# Self-Hosted Cricket Data Scraper Setup

This guide helps you set up a self-hosted scraper for unlimited free IPL data with zero rate limits.

## Overview

Three deployment options for the scraper:

### Option 1: Standalone Node.js Scraper (Recommended)
Run on your own server/VPS - complete control, no limits.

### Option 2: Docker Container
Deploy as a containerized service - easy scaling.

### Option 3: GitHub Actions
Automatic daily scraping - free with GitHub.

---

## Option 1: Standalone Node.js Server

### Requirements
- Node.js 16+
- npm/yarn
- Server/VPS with static IP (optional, for webhooks)

### Setup

**Step 1: Create scraper directory**
```bash
mkdir ~/ipl-scraper && cd ~/ipl-scraper
npm init -y
```

**Step 2: Install dependencies**
```bash
npm install cheerio axios express cors dotenv
npm install -D nodemon
```

**Step 3: Create `scraper.js`**
```javascript
const axios = require('axios');
const cheerio = require('cheerio');
const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());

let cachedData = null;
let lastUpdate = null;

async function scrapeIPLTable() {
  try {
    console.log('[Scraper] Fetching Cricbuzz points table...');

    const { data } = await axios.get(
      'https://www.cricbuzz.com/cricket-series/5969/indian-premier-league-2026/points-table',
      {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        timeout: 10000
      }
    );

    const $ = cheerio.load(data);
    const teams = [];

    // Parse Cricbuzz table structure
    $('tbody tr').each((i, row) => {
      const cells = $(row).find('td');
      if (cells.length < 6) return;

      const team = $(cells[0]).text().trim();
      const m = parseInt($(cells[1]).text()) || 0;
      const w = parseInt($(cells[2]).text()) || 0;
      const l = parseInt($(cells[3]).text()) || 0;
      const nrr = parseFloat($(cells[4]).text()) || 0;
      const pts = parseInt($(cells[5]).text()) || 0;

      if (team && m > 0) {
        teams.push({ team: team.substring(0, 4).toUpperCase(), m, w, l, nrr, pts, form: [] });
      }
    });

    if (teams.length >= 8) {
      cachedData = teams;
      lastUpdate = new Date();
      console.log('[Scraper] ✓ Scraped', teams.length, 'teams');
      return teams;
    }

    console.warn('[Scraper] Failed to parse teams from HTML');
    return null;

  } catch (err) {
    console.error('[Scraper] Error:', err.message);
    return null;
  }
}

// API endpoint
app.get('/api/teams', async (req, res) => {
  // If cache is fresh (< 1 hour), return it
  if (cachedData && lastUpdate && Date.now() - lastUpdate < 3600000) {
    return res.json({
      teams: cachedData,
      source: 'Self-Hosted Scraper (Cached)',
      timestamp: lastUpdate,
      cached: true
    });
  }

  // Otherwise, scrape fresh data
  const teams = await scrapeIPLTable();

  if (teams && teams.length > 0) {
    return res.json({
      teams,
      source: 'Self-Hosted Scraper (Live)',
      timestamp: new Date(),
      cached: false
    });
  }

  // Fallback
  return res.status(503).json({
    error: 'Scraper unavailable',
    lastKnownTeams: cachedData,
    lastUpdate
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    lastScrape: lastUpdate,
    cached: !!cachedData,
    cacheSize: cachedData?.length || 0
  });
});

// Scrape on startup and every 30 minutes
scrapeIPLTable();
setInterval(scrapeIPLTable, 1800000);

app.listen(3000, () => {
  console.log('[Scraper] Server running on http://localhost:3000');
  console.log('[Scraper] API: http://localhost:3000/api/teams');
});
```

**Step 4: Update `package.json`**
```json
{
  "scripts": {
    "start": "node scraper.js",
    "dev": "nodemon scraper.js"
  }
}
```

**Step 5: Run**
```bash
npm start
# Server runs on http://localhost:3000
```

**Step 6: Test**
```bash
curl http://localhost:3000/api/teams | jq '.teams[0:3]'
```

---

## Option 2: Docker Container

**Dockerfile:**
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY scraper.js .

EXPOSE 3000
CMD ["node", "scraper.js"]
```

**Build & Run:**
```bash
docker build -t ipl-scraper .
docker run -p 3000:3000 ipl-scraper
```

**Docker Compose:**
```yaml
version: '3'
services:
  scraper:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    restart: always
```

---

## Option 3: GitHub Actions (Auto-Scraping)

**.github/workflows/scrape.yml:**
```yaml
name: Scrape IPL Data

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  scrape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: actions/setup-node@v3
        with:
          node-version: 18

      - run: npm install cheerio axios

      - run: |
          node -e "
          const axios = require('axios');
          const cheerio = require('cheerio');

          (async () => {
            const res = await axios.get('https://www.cricbuzz.com/...');
            const $ = cheerio.load(res.data);
            // Parse data...
            console.log('Scraped');
          })()
          "

      - uses: actions/upload-artifact@v3
        with:
          name: ipl-data
          path: data.json
```

---

## Integration with Your App

Once scraper is running, update your backend:

**In `multi-source-stats.js`:**
```javascript
async function fetchFromSelfHostedScraper() {
  try {
    const url = process.env.SCRAPER_URL || 'http://localhost:3000/api/teams';
    const res = await fetch(url);
    if (!res.ok) return null;

    const data = await res.json();
    return {
      teams: data.teams,
      source: 'Self-Hosted Scraper'
    };
  } catch (err) {
    console.warn('Scraper unavailable:', err.message);
    return null;
  }
}

// Then in the cascade, try this FIRST before other APIs
```

---

## Deployment Options

### On Your VPS/Server
```bash
# SSH to server
ssh user@your-server.com

# Clone/setup scraper
git clone your-repo
cd ipl-scraper
npm install
npm start &  # Run in background

# Verify
curl http://localhost:3000/health
```

### On Heroku (Free)
```bash
git init
git add .
git commit -m "Initial scraper"
heroku create
git push heroku main
heroku open /health
```

### On Railway/Render (Free)
Connect your GitHub repo, set startup command to `npm start`, done!

### On AWS Lambda
Wrap scraper as serverless function - more complex but scalable.

---

## Monitoring & Maintenance

**Health Check:**
```bash
curl http://your-scraper-url/health
```

**Expected Response:**
```json
{
  "status": "ok",
  "lastScrape": "2026-04-02T10:30:00.000Z",
  "cached": true,
  "cacheSize": 10
}
```

**Troubleshooting:**

| Problem | Solution |
|---------|----------|
| No data scraped | Cricbuzz HTML structure changed - update selectors |
| Server down | Set up monitoring (UptimeRobot, Pingdom) |
| Rate limited by Cricbuzz | Add delays between requests, rotate IPs |
| Memory leak | Add cache expiration, restart daily |

---

## Advanced: Robust Scraper with Fallbacks

For production reliability, add:

1. **Multiple HTML parsing strategies** - if one fails, try another
2. **Proxy rotation** - avoid IP blocking
3. **Exponential backoff** - retry on failure
4. **Data validation** - ensure 10 teams, valid stats
5. **Alerts** - notify if scraper fails 3 times in a row

---

## Cost Analysis

| Option | Monthly Cost | Ease | Reliability |
|--------|------------|------|------------|
| Standalone VPS | $5-20 | Medium | High |
| Docker on VPS | $5-20 | Medium | High |
| Heroku free | $0 (free tier) | Easy | Medium |
| Railway/Render | $0-10 | Easy | High |
| AWS Lambda | $0-5 | Hard | Very High |
| GitHub Actions | $0 | Easy | Medium |

**Recommendation:** Start with Render or Railway (free tier), graduate to VPS if you need 99.9% uptime.

---

## Next Steps

1. ✅ Set up scraper locally using Option 1
2. ✅ Test it: `npm start` and curl `/api/teams`
3. ✅ Deploy to Railway or Render (easiest)
4. ✅ Update your `.env` with `SCRAPER_URL=https://your-scraper.com`
5. ✅ Redeploy your main app

Want help with any of these steps?
