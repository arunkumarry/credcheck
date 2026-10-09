// popup.js

const AMOUNT_INPUT = document.getElementById("amount-input");
const CATEGORY_INPUT = document.getElementById("category-input");
const COUPONS_INPUT = document.getElementById("coupons-input");
const BUTTON = document.getElementById("get-recommendation-btn");
const LOADING = document.getElementById("loading");
const RESULT_SECTION = document.getElementById("result-section");
const CART_DATA_SECTION = document.getElementById("cart-data-section");
const ERROR_MSG = document.getElementById("error-message");

document.addEventListener("DOMContentLoaded", async () => {
  // Query active tab
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  
  if (!tab) return;
  
  try {
    console.log("Injecting content script into tab:", tab.id);
    // Inject content.js directly (this ensures it runs even if the page wasn't refreshed)
    await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      files: ["content.js"]
    });

    console.log("Sending getCartData message...");
    // Send the message to the injected content script
    chrome.tabs.sendMessage(tab.id, { action: "getCartData" }, (response) => {
      if (chrome.runtime.lastError || !response) {
        console.warn("Messaging error or null response:", chrome.runtime.lastError);
        AMOUNT_INPUT.value = "0";
        CATEGORY_INPUT.value = "shopping";
        return;
      }
      
      console.log("Received data from content script:", response);
      AMOUNT_INPUT.value = response.amount || 0;
      CATEGORY_INPUT.value = response.category || "";
      if (response.coupons && response.coupons.length > 0) {
        COUPONS_INPUT.value = response.coupons.join(", ");
      }
    });

  } catch(e) {
    console.error("Could not inject or communicate:", e);
    AMOUNT_INPUT.value = "0";
    CATEGORY_INPUT.value = "shopping";
  }
});

const API_TOKEN_INPUT = document.getElementById("api-token-input");
const SAVE_TOKEN_BTN = document.getElementById("save-token-btn");
const TOKEN_STATUS = document.getElementById("token-status");

// Load token on startup
chrome.storage.local.get(["checkcredApiToken"], (result) => {
  if (result.checkcredApiToken) {
    API_TOKEN_INPUT.value = result.checkcredApiToken;
  }
});

SAVE_TOKEN_BTN.addEventListener("click", () => {
  const token = API_TOKEN_INPUT.value.trim();
  chrome.storage.local.set({ checkcredApiToken: token }, () => {
    TOKEN_STATUS.style.display = "inline";
    setTimeout(() => { TOKEN_STATUS.style.display = "none"; }, 2000);
  });
});

BUTTON.addEventListener("click", async () => {
  const amount = parseFloat(AMOUNT_INPUT.value);
  const category = CATEGORY_INPUT.value;
  const coupons = COUPONS_INPUT.value.split(",").map(c => c.trim()).filter(c => c !== "");

  if (!amount || amount <= 0) {
    showError("Please enter a valid amount.");
    return;
  }
  
  if (!category) {
    showError("Please enter a category.");
    return;
  }

  hideError();
  CART_DATA_SECTION.classList.add("hidden");
  LOADING.classList.remove("hidden");

  try {
    const apiBaseUrl = (typeof import.meta !== 'undefined' && import.meta.env) ? import.meta.env.VITE_API_BASE_URL : "http://localhost:3000";
    const url = `${apiBaseUrl}/api/v1/recommendations`;
    const storageResult = await chrome.storage.local.get("checkcredApiToken");
    const token = storageResult.checkcredApiToken || API_TOKEN_INPUT.value.trim();
    
    const headers = {
      "Content-Type": "application/json",
      "Accept": "application/json"
    };

    if (token) {
      headers["Authorization"] = `Bearer ${token}`;
    }
    
    // We send credentials: 'include' as a fallback if they don't have a token yet
    const response = await fetch(url, {
      method: "POST",
      headers: headers,
      credentials: "include", 
      body: JSON.stringify({
        amount: amount,
        category: category,
        coupon_codes: coupons
      })
    });

    if (!response.ok) {
      if (response.status === 401) {
        throw new Error("You must be logged into CheckCred to use this extension. Please log in first.");
      }
      throw new Error(`Server returned ${response.status}`);
    }

    const data = await response.json();
    displayResult(data);
  } catch (error) {
    console.error("API Error", error);
    showError(error.message || "Failed to fetch recommendation. Are you logged in?");
    LOADING.classList.add("hidden");
    CART_DATA_SECTION.classList.remove("hidden");
  }
});

document.getElementById("reset-btn").addEventListener("click", () => {
  RESULT_SECTION.classList.add("hidden");
  CART_DATA_SECTION.classList.remove("hidden");
});

function displayResult(data) {
  LOADING.classList.add("hidden");
  RESULT_SECTION.classList.remove("hidden");
  
  // We assume the API returns the best card directly or an array of cards
  const bestCard = Array.isArray(data) ? data.find(c => c.recommended) || data[0] : data;

  if (bestCard) {
    document.getElementById("best-card-name").innerText = bestCard.card_name || "Unknown Card";

    const amount = bestCard.reward_amount ? `₹${parseFloat(bestCard.reward_amount).toLocaleString('en-IN')}` : "₹0";
    document.getElementById("best-card-amount").innerText = amount;

    let rewardsText = (bestCard.rewards || "").toString();
    if (bestCard.coupon_code && bestCard.coupon_savings && bestCard.coupon_code !== "null" && bestCard.coupon_savings !== "null") {
      rewardsText += ` + ${bestCard.coupon_savings} (${bestCard.coupon_code})`;
    }
    
    document.getElementById("best-card-rewards").innerText = rewardsText;
    document.getElementById("best-card-rewards").style.fontSize = "11px";
    document.getElementById("best-card-rewards").style.marginTop = "2px";
    document.getElementById("best-card-reasoning").innerText = bestCard.reasoning || "";
  } else {
    showError("No recommendation received.");
  }
}

function showError(msg) {
  ERROR_MSG.innerText = msg;
  ERROR_MSG.classList.remove("hidden");
}

function hideError() {
  ERROR_MSG.innerText = "";
  ERROR_MSG.classList.add("hidden");
}
