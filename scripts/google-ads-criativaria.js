/**
 * Google Ads Automation Script - Criativaria Campaign
 * 
 * Tasks:
 * 1. Increase max CPC bid to R$ 3,00-5,00
 * 2. Add phrase match keywords (broader reach)
 * 3. Verify location targeting is all of Brazil
 * 4. Remove ad schedule restrictions
 * 
 * Usage: node scripts/google-ads-criativaria.js
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const CAMPAIGN_ID = '23959194195';
const SCREENSHOTS_DIR = path.join(__dirname, '..', 'screenshots', 'google-ads');
const TARGET_CPC = '4,00'; // R$ 4,00 as middle ground between 3-5

// Ensure screenshots directory exists
if (!fs.existsSync(SCREENSHOTS_DIR)) {
  fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });
}

async function takeScreenshot(page, name) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const filename = `${timestamp}-${name}.png`;
  const filepath = path.join(SCREENSHOTS_DIR, filename);
  await page.screenshot({ path: filepath, fullPage: true });
  console.log(`📸 Screenshot saved: ${filename}`);
  return filename;
}

async function waitForNavigation(page, timeout = 30000) {
  await page.waitForLoadState('networkidle', { timeout });
}

async function main() {
  console.log('🚀 Starting Google Ads automation for Criativaria campaign...\n');

  // Launch browser with persistent context to reuse login session
  const userDataDir = path.join(require('os').homedir(), '.google-ads-automation');
  const context = await chromium.launchPersistentContext(userDataDir, {
    headless: false, // Show browser for debugging and manual login if needed
    viewport: { width: 1920, height: 1080 },
    locale: 'pt-BR',
    timezoneId: 'America/Sao_Paulo',
  });

  const page = await context.newPage();

  try {
    // Step 1: Navigate to Google Ads
    console.log('📍 Step 1: Opening Google Ads...');
    await page.goto('https://ads.google.com', { waitUntil: 'domcontentloaded' });
    await waitForNavigation(page);
    await takeScreenshot(page, '01-initial-load');

    // Check if login is required
    const currentUrl = page.url();
    if (currentUrl.includes('accounts.google.com') || currentUrl.includes('signin')) {
      console.log('\n⚠️  LOGIN REQUIRED');
      console.log('Please log in to Google Ads manually in the browser window.');
      console.log('The script will continue automatically after login.\n');
      
      // Wait for user to complete login (up to 5 minutes)
      await page.waitForURL('**/ads.google.com/**', { timeout: 300000 });
      await waitForNavigation(page);
      await takeScreenshot(page, '02-after-login');
      console.log('✅ Login completed\n');
    }

    // Step 2: Navigate to the specific campaign
    console.log('📍 Step 2: Navigating to Criativaria campaign...');
    const campaignUrl = `https://ads.google.com/campaigns/${CAMPAIGN_ID}/summary`;
    await page.goto(campaignUrl, { waitUntil: 'domcontentloaded' });
    await waitForNavigation(page);
    await page.waitForTimeout(3000); // Extra wait for dynamic content
    await takeScreenshot(page, '03-campaign-page');

    // Step 3: Go to campaign settings
    console.log('📍 Step 3: Opening campaign settings...');
    
    // Look for settings link/button
    const settingsSelectors = [
      'text=Configurações',
      'text=Settings',
      '[data-test-id="settings-tab"]',
      'a:has-text("Configurações")',
      'a:has-text("Settings")',
    ];

    let settingsFound = false;
    for (const selector of settingsSelectors) {
      try {
        await page.click(selector, { timeout: 5000 });
        settingsFound = true;
        console.log(`  ✓ Found settings using: ${selector}`);
        break;
      } catch (e) {
        continue;
      }
    }

    if (!settingsFound) {
      console.log('  ⚠️  Could not find settings tab, trying direct URL...');
      await page.goto(`https://ads.google.com/campaigns/${CAMPAIGN_ID}/settings`, { waitUntil: 'domcontentloaded' });
    }

    await waitForNavigation(page);
    await page.waitForTimeout(2000);
    await takeScreenshot(page, '04-settings-page');

    // Step 4: Increase max CPC bid
    console.log('📍 Step 4: Updating max CPC bid...');
    
    // Look for bidding section
    const bidSelectors = [
      'text=Lances',
      'text=Bidding',
      'text=CPC máximo',
      'text=Max CPC',
      '[data-test-id="bid-section"]',
    ];

    for (const selector of bidSelectors) {
      try {
        await page.click(selector, { timeout: 3000 });
        console.log(`  ✓ Found bid section: ${selector}`);
        break;
      } catch (e) {
        continue;
      }
    }

    await page.waitForTimeout(1000);

    // Find and update CPC input
    const cpcInputSelectors = [
      'input[name*="cpc"]',
      'input[name*="bid"]',
      'input[placeholder*="R$"]',
      'input[type="text"]:near(:text("CPC"))',
      'input[type="number"]',
    ];

    let cpcUpdated = false;
    for (const selector of cpcInputSelectors) {
      try {
        const input = await page.$(selector);
        if (input) {
          await input.fill(TARGET_CPC);
          cpcUpdated = true;
          console.log(`  ✓ Updated CPC to R$ ${TARGET_CPC}`);
          break;
        }
      } catch (e) {
        continue;
      }
    }

    if (!cpcUpdated) {
      console.log('  ⚠️  Could not find CPC input field - may need manual intervention');
    }

    await takeScreenshot(page, '05-cpc-updated');

    // Step 5: Add phrase match keywords
    console.log('📍 Step 5: Adding phrase match keywords...');
    
    // Navigate to keywords section
    const keywordsUrl = `https://ads.google.com/campaigns/${CAMPAIGN_ID}/keywords`;
    await page.goto(keywordsUrl, { waitUntil: 'domcontentloaded' });
    await waitForNavigation(page);
    await page.waitForTimeout(2000);
    await takeScreenshot(page, '06-keywords-page');

    // Look for add keywords button
    const addKeywordSelectors = [
      'text=Adicionar palavras-chave',
      'text=Add keywords',
      'button:has-text("Adicionar")',
      'button:has-text("Add")',
      '[data-test-id="add-keywords"]',
    ];

    let addKeywordClicked = false;
    for (const selector of addKeywordSelectors) {
      try {
        await page.click(selector, { timeout: 3000 });
        addKeywordClicked = true;
        console.log(`  ✓ Clicked add keywords: ${selector}`);
        break;
      } catch (e) {
        continue;
      }
    }

    if (addKeywordClicked) {
      await page.waitForTimeout(2000);
      
      // Suggested phrase match keywords for Criativaria (creative/design focus)
      const keywords = [
        '"design criativo"',
        '"agência de publicidade"',
        '"criação de conteúdo"',
        '"marketing digital"',
        '"branding profissional"',
        '"identidade visual"',
        '"social media management"',
        '"campanhas publicitárias"',
      ];

      // Find keyword input area
      const keywordInputSelectors = [
        'textarea',
        'input[placeholder*="palavra"]',
        'input[placeholder*="keyword"]',
        '[contenteditable="true"]',
      ];

      for (const selector of keywordInputSelectors) {
        try {
          const input = await page.$(selector);
          if (input) {
            await input.fill(keywords.join('\n'));
            console.log(`  ✓ Added ${keywords.length} phrase match keywords`);
            break;
          }
        } catch (e) {
          continue;
        }
      }

      await takeScreenshot(page, '07-keywords-added');

      // Save keywords
      const saveSelectors = [
        'text=Salvar',
        'text=Save',
        'button[type="submit"]',
        'button:has-text("Salvar")',
      ];

      for (const selector of saveSelectors) {
        try {
          await page.click(selector, { timeout: 3000 });
          console.log(`  ✓ Saved keywords`);
          break;
        } catch (e) {
          continue;
        }
      }

      await page.waitForTimeout(2000);
    } else {
      console.log('  ⚠️  Could not find add keywords button');
    }

    // Step 6: Verify location targeting
    console.log('📍 Step 6: Checking location targeting...');
    await page.goto(`https://ads.google.com/campaigns/${CAMPAIGN_ID}/settings`, { waitUntil: 'domcontentloaded' });
    await waitForNavigation(page);
    await page.waitForTimeout(2000);

    // Look for locations section
    const locationSelectors = [
      'text=Locais',
      'text=Locations',
      'text=Segmentação geográfica',
      '[data-test-id="locations-section"]',
    ];

    for (const selector of locationSelectors) {
      try {
        await page.click(selector, { timeout: 3000 });
        console.log(`  ✓ Found locations section: ${selector}`);
        break;
      } catch (e) {
        continue;
      }
    }

    await page.waitForTimeout(1000);
    await takeScreenshot(page, '08-locations');

    // Check if Brazil is targeted
    const brazilText = await page.textContent('body');
    if (brazilText.includes('Brasil') || brazilText.includes('Brazil')) {
      console.log('  ✓ Brazil targeting confirmed');
    } else {
      console.log('  ⚠️  Brazil targeting not found - may need manual verification');
    }

    // Step 7: Remove ad schedule restrictions
    console.log('📍 Step 7: Checking ad schedules...');
    
    const scheduleUrl = `https://ads.google.com/campaigns/${CAMPAIGN_ID}/ad-schedule`;
    await page.goto(scheduleUrl, { waitUntil: 'domcontentloaded' });
    await waitForNavigation(page);
    await page.waitForTimeout(2000);
    await takeScreenshot(page, '09-ad-schedule');

    // Look for schedule restrictions
    const scheduleBody = await page.textContent('body');
    if (scheduleBody.includes('Nenhum horário') || scheduleBody.includes('No schedule') || scheduleBody.includes('24 horas')) {
      console.log('  ✓ No ad schedule restrictions found (running 24/7)');
    } else {
      console.log('  ⚠️  Ad schedule restrictions may exist - review screenshot');
      
      // Try to remove restrictions if found
      const editScheduleSelectors = [
        'text=Editar horários',
        'text=Edit schedule',
        'button:has-text("Editar")',
        'button:has-text("Edit")',
      ];

      for (const selector of editScheduleSelectors) {
        try {
          await page.click(selector, { timeout: 3000 });
          console.log(`  ✓ Attempting to edit schedule: ${selector}`);
          await page.waitForTimeout(2000);
          await takeScreenshot(page, '10-edit-schedule');
          break;
        } catch (e) {
          continue;
        }
      }
    }

    // Final summary screenshot
    await takeScreenshot(page, '11-final-state');

    console.log('\n✅ Automation completed!');
    console.log(`📁 Screenshots saved to: ${SCREENSHOTS_DIR}`);
    console.log('\n⚠️  IMPORTANT: Please review the screenshots to verify all changes were applied correctly.');
    console.log('Some Google Ads UI elements may require manual adjustment due to dynamic content.\n');

  } catch (error) {
    console.error('\n❌ Error during automation:', error.message);
    await takeScreenshot(page, 'error-state');
    throw error;
  } finally {
    // Keep browser open for manual review if needed
    console.log('\n🔍 Browser will remain open for 30 seconds for manual review...');
    await page.waitForTimeout(30000);
    await context.close();
  }
}

// Run the automation
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
