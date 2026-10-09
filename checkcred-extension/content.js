// content.js

function scrapeCart() {
  // 1. Scrape Amount
  let amount = 0;
  const allElements = Array.from(document.querySelectorAll('*'));

  // Strategy A: Look for "Total", "Amount Payable", etc.
  const totalKeywords = ['total', 'subtotal', 'cart total', 'amount payable', 'final', 'total amount'];
  let keywordAmount = 0;

  for (let el of allElements) {
    if (el.children.length > 2) continue;

    const text = (el.textContent || '').toLowerCase().trim();
    // Exclude saving/discount totals
    if (totalKeywords.some(kw => text.includes(kw)) && !text.includes('saving') && !text.includes('discount')) {
      // The price might be in this element or the next one
      let lookupText = text;
      let nextEl = el.nextElementSibling || (el.parentElement && el.parentElement.nextElementSibling);
      if (nextEl) {
        lookupText += " " + nextEl.textContent;
      }

      const match = lookupText.match(/(?:\$|₹|rs\.?|inr)\s*([\d,]+(?:\.\d{2})?)/i);
      if (match) {
        const parsed = parseFloat(match[1].replace(/,/g, ''));
        if (parsed > keywordAmount) {
          keywordAmount = parsed;
        }
      }
    }
  }

  // Strategy B: Fallback to highest numeric value found
  let maxPrice = 0;
  const priceElements = allElements.filter(el =>
    el.children.length === 0 && (el.textContent.includes('$') || el.textContent.includes('₹'))
  );

  priceElements.forEach(el => {
    const text = el.textContent.trim();
    const match = text.match(/(?:\$|₹)\s*([\d,]+(?:\.\d{2})?)/);
    if (match) {
      const val = parseFloat(match[1].replace(/,/g, ''));
      if (val > maxPrice) maxPrice = val;
    }
  });

  amount = keywordAmount > 0 ? keywordAmount : maxPrice;

  // 2. Infer Category based on URL
  const hostname = window.location.hostname;
  const fullUrl = window.location.href.toLowerCase();

  // Extract the main domain part as the category (e.g., 'makemytrip' from www.makemytrip.com)
  let siteName = hostname;
  const parts = hostname.split('.');
  if (parts.length >= 2) {
    siteName = parts[parts.length - 2]; // gets 'makemytrip' from 'www.makemytrip.com'
  }

  let category = siteName;

  // Append specific purchase categories based on URL keywords
  if (fullUrl.includes("flight")) {
    category += " flights";
  } else if (fullUrl.includes("hotel")) {
    category += " hotels";
  } else if (fullUrl.includes("bus")) {
    category += " bus";
  } else if (fullUrl.includes("train") || fullUrl.includes("rail")) {
    category += " train";
  } else if (fullUrl.includes("food") || fullUrl.includes("dining") || siteName === "zomato" || siteName === "swiggy") {
    category += " dining delivery";
  } else if (fullUrl.includes("grocery") || fullUrl.includes("mart") || siteName === "blinkit" || siteName === "zepto" || siteName === "instamart") {
    category += " groceries";
  }

  // 3. Scrape for Coupons (Heuristic: Look for text matching typical coupon labels)
  const couponCodes = [];
  const couponKeywords = /code:?\s*([A-Z0-9]{4,15})/i;
  const appliedKeywords = /(?:applied|promo):\s*([A-Z0-9]{4,15})/i;
  const ignoreWords = ['APPLY', 'REMOVE', 'DISCOUNT', 'OFFERS', 'COUPON', 'PROMO', 'SUBMIT', 'CANCEL', 'CONTINUE', 'CHECKOUT', 'TOTAL', 'DELIVERY', 'FREE', 'CASHBACK', 'DETAILS', 'TERMS'];

  const allTextElements = Array.from(document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, span, div, strong, b, li'));

  allTextElements.forEach(el => {
    if (el.children.length > 2) return; // Ignore large container divs

    const text = el.textContent.trim();
    if (!text) return;

    // Check for "Code: SAVE20" pattern
    let match = text.match(couponKeywords);
    if (match && match[1] && !ignoreWords.includes(match[1].toUpperCase())) {
      couponCodes.push(match[1].toUpperCase());
    }

    // Check for "Promo applied: FALL50" pattern
    match = text.match(appliedKeywords);
    if (match && match[1] && !ignoreWords.includes(match[1].toUpperCase())) {
      couponCodes.push(match[1].toUpperCase());
    }

    // Check for Makemytrip style coupons: Standalone ALL CAPS strings that are likely coupons
    // usually presented in a list of "Coupons and Offers"
    if (text.match(/^[A-Z0-9]{5,15}$/) && !ignoreWords.includes(text)) {
      // Verify the element is inside a container that suggests it's an offer/coupon area
      let isCouponArea = false;
      let current = el;
      for (let i = 0; i < 6; i++) { // check up to 6 levels up
        if (!current) break;
        // Check element classes and ids
        const className = typeof current.className === 'string' ? current.className : '';
        const attrs = (className + ' ' + (current.id || '')).toLowerCase();
        if (attrs.includes('offer') || attrs.includes('coupon') || attrs.includes('deal') || attrs.includes('promo')) {
          isCouponArea = true;
          break;
        }

        // Also check if any header sibling or the container itself explicitly mentions coupons
        const nodeText = current.textContent.toLowerCase();
        if (nodeText.includes("coupon") || nodeText.includes("promo code") || nodeText.includes("promocode")) {
          isCouponArea = true;
          break;
        }
        current = current.parentElement;
      }

      if (isCouponArea) {
        const parentText = el.parentElement ? el.parentElement.textContent.toLowerCase() : "";
        if (parentText.includes("off") || parentText.includes("discount") || parentText.includes("apply") || parentText.includes("cashback") || parentText.includes("save")) {
          // Try to find the discount amount (e.g., '₹ 947 off' or '947 discount')
          const discountMatch = parentText.match(/(?:₹|\$|rs\.?|inr)?\s*([\d,]+(?:\.\d{2})?)\s*(?:off|discount|cashback|save)/i);

          let ruleContext = parentText.substring(0, 150).replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();

          if (discountMatch) {
            couponCodes.push(`${text} (₹${discountMatch[1]} off - rule: "${ruleContext}")`);
          } else {
            couponCodes.push(`${text} (rule: "${ruleContext}")`);
          }
        }
      }
    }
  });

  // Unique coupons
  const uniqueCoupons = [...new Set(couponCodes)];

  return { amount, category, coupons: uniqueCoupons, url: hostname };
}

// Listen for messages from popup
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === "getCartData") {
    const data = scrapeCart();
    sendResponse(data);
  }
});
