---
name: dev-browser
description: Browser automation with persistent page state. Use when users ask to navigate websites, fill forms, take screenshots, extract web data, test web apps, or automate browser workflows. Triggers on "go to [url]", "click on", "fill out", "take a screenshot", "scrape", "test the website", "log into".
allowed-tools: [Bash, Read, Write, Glob, Grep]
user-invocable: true
argument-hint: "describe the browser task (e.g., 'go to example.com and screenshot the homepage')"
---

# Dev Browser — Playwright Automation with Persistent State

Browser automation that maintains page state across script executions. Write small, focused scripts. Once a workflow is proven, combine steps into a single script.

## Prerequisites

Requires Playwright. Install if not present:
```bash
npm install -g playwright
npx playwright install chromium
```

## Choosing Your Approach

| Situation | Approach |
|---|---|
| Local/source-available sites | Read the source code first to write selectors directly |
| Unknown page layouts | Use accessibility snapshots to discover elements |
| Visual feedback needed | Take screenshots to see current state |
| Data extraction | Intercept network requests rather than scraping DOM |

## Writing Scripts

Execute scripts inline using heredocs:

```bash
npx playwright test --config=/dev/null <<'SCRIPT'
import { chromium } from 'playwright';

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();

await page.goto('https://example.com');
await page.waitForLoadState('networkidle');

// Take screenshot
await page.screenshot({ path: '/tmp/screenshot.png' });

// Get page info
console.log(JSON.stringify({
  title: await page.title(),
  url: page.url()
}));

await browser.close();
SCRIPT
```

Or for persistent state across multiple interactions, use a script file:

```bash
cat > /tmp/browser-task.mjs << 'EOF'
import { chromium } from 'playwright';

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });

await page.goto(process.argv[2] || 'https://example.com');
await page.waitForLoadState('networkidle');

// Your automation here
await page.screenshot({ path: '/tmp/result.png', fullPage: true });
console.log('Done:', await page.title());

await browser.close();
EOF
node /tmp/browser-task.mjs "https://example.com"
```

## Workflow Loop

For complex tasks, work incrementally:

1. **Navigate**: Go to the target URL, wait for load
2. **Observe**: Screenshot + accessibility snapshot to understand the page
3. **Interact**: Click, fill, select one element at a time
4. **Verify**: Screenshot after each interaction to confirm state
5. **Repeat**: Until the task is complete

## Key Operations

### Navigation
```javascript
await page.goto('https://example.com');
await page.waitForLoadState('networkidle');
await page.goBack();
await page.goForward();
await page.reload();
```

### Finding Elements
```javascript
// By CSS selector
await page.click('.submit-button');
await page.fill('#email', 'test@example.com');

// By text content
await page.click('text=Sign In');
await page.getByRole('button', { name: 'Submit' }).click();

// By accessibility role
await page.getByLabel('Email address').fill('test@example.com');
await page.getByPlaceholder('Search...').fill('query');
```

### Screenshots
```javascript
await page.screenshot({ path: '/tmp/screenshot.png' });
await page.screenshot({ path: '/tmp/full.png', fullPage: true });
await page.locator('.specific-element').screenshot({ path: '/tmp/element.png' });
```

### Extracting Data
```javascript
// Text content
const text = await page.textContent('.result');
const allItems = await page.locator('.item').allTextContents();

// Structured data
const data = await page.evaluate(() => {
  return Array.from(document.querySelectorAll('.row')).map(row => ({
    name: row.querySelector('.name')?.textContent,
    value: row.querySelector('.value')?.textContent,
  }));
});
console.log(JSON.stringify(data, null, 2));
```

### Forms
```javascript
await page.fill('#username', 'user@example.com');
await page.fill('#password', 'password123');
await page.selectOption('#country', 'US');
await page.check('#agree-terms');
await page.click('button[type="submit"]');
await page.waitForURL('**/dashboard');
```

### Waiting
```javascript
await page.waitForLoadState('networkidle');
await page.waitForSelector('.results');
await page.waitForURL('**/success');
await page.waitForTimeout(1000); // Last resort
```

## Error Recovery

If something goes wrong:
1. Take a screenshot to see current state: `await page.screenshot({ path: '/tmp/debug.png' })`
2. Log current URL and page title
3. Check if the page loaded correctly
4. Try alternative selectors (text-based, role-based, xpath)

## Data Scraping Strategy

For large datasets, intercept API calls instead of scraping DOM:

```javascript
// Capture network requests
page.on('response', async (response) => {
  if (response.url().includes('/api/data')) {
    const data = await response.json();
    console.log(JSON.stringify(data));
  }
});

await page.goto('https://example.com/data');
// Scroll or paginate to trigger more API calls
```

This is faster, more reliable, and captures structured data that the DOM may not expose.

## Rules

- **Read source first**: If the site's code is available locally, read it for selectors instead of guessing
- **Screenshot after every major step**: Visual confirmation prevents debugging blind
- **One action per script**: Navigate, OR click, OR fill. Verify between each.
- **No TypeScript in evaluate()**: `page.evaluate()` runs in the browser which is plain JS only
- **Clean up**: `await browser.close()` at the end of every script

Task: $ARGUMENTS
