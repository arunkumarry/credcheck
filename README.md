# CredCheck

**"Which card should I use for this purchase — right now?"**

CredCheck is an AI agent that picks the best credit card in your wallet for a
specific purchase, grounded in **live search data from SerpApi**. Instead of
relying on stale, hand-maintained offer lists, the agent fetches current prices
and today's bank offers at the moment you ask.

Built for the **SerpApi India Hackathon 2026** (AI Agents / Commerce tracks).

> Prior work disclosure: CredCheck is built on an earlier personal project,
> *checkcred* (a credit-card RAG app). The live SerpApi agent layer described
> below — `LiveSearch::*` and `Agents::*` — is new for this hackathon.

## How it works — the agent loop

When you enter a purchase, `Agents::PurchaseCopilot` runs a genuine
**plan → search → compare → act** loop. The LLM (Claude Haiku 4.5 via RubyLLM)
decides which searches to run and calls SerpApi **tools** itself:

| Step | What the agent does | SerpApi engine |
|------|--------------------|----------------|
| Plan | Reads your wallet + purchase, decides what to look up | — |
| Search | Live product price across merchants | `google_shopping` |
| Search | Current card offers, one query per bank in your wallet | `google` |
| Search | Freshly announced sale events (optional) | `google_news` |
| Compare | Folds live offers + prices over baseline reward rules | — |
| Act | Ranks every card, cites the exact SerpApi results used | — |

Every figure in the recommendation traces back to a `[S#]` citation, and the UI
shows the agent's search trace so you can see exactly what it looked up.

**SerpApi is the core dependency** — remove the live searches and there is no
recommendation.

### Key code

- `app/services/live_search/serp_api_client.rb` — SerpApi REST wrapper
  (`google` / `google_shopping` / `google_news`), with timeout retries.
- `app/services/agents/purchase_copilot.rb` — the tool-calling agent.
- `app/services/agents/tools/` — the three SerpApi tools the agent can call.
- `app/services/agents/search_trace.rb` — captures the agent's plan + citations.
- `app/services/rag_agent.rb` — caches the agent result (keyed by day so offers
  refresh daily); keeps a legacy single-prompt pipeline as a fallback.

## Tech stack

- Ruby on Rails 8.0 (Ruby 3.4.7), PostgreSQL + pgvector
- RubyLLM → Anthropic Claude Haiku 4.5 (agent + tool calling)
- SerpApi (live search), Vite + Tailwind (frontend), Turbo (streaming results)

## Running it locally

### Prerequisites

- Ruby 3.4.7, Node 18+, PostgreSQL 16+ with the **pgvector** extension
- A SerpApi API key and an Anthropic API key

### 1. Environment variables

Create a `.env` in the project root:

```bash
SERP_API_KEY=your_serpapi_key
ANTHROPIC_API_KEY=your_anthropic_key
```

### 2. Database (one-time, with pgvector)

```bash
# macOS / Homebrew example
brew install pgvector
brew services start postgresql@18
```

`config/database.yml` connects as role `postgres` / password `password` on
`localhost`. Create that role if you don't have it:

```bash
psql -d postgres -c "CREATE ROLE postgres WITH LOGIN SUPERUSER PASSWORD 'password';"
```

### 3. Install dependencies

```bash
bundle install
npm install
```

### 4. Create and seed the database

```bash
bin/rails db:prepare
```

This creates the DB, loads the schema, and seeds 5 banks, a demo card
catalogue, and a demo user with a 3-card wallet:

- **Email:** `demo@credcheck.in`
- **Password:** `password123`
- **Wallet:** Amazon Pay ICICI, HDFC Regalia Gold, Axis Ace

### 5. Run the app

CredCheck needs both the Vite dev server and the Rails server. In two terminals:

```bash
# terminal 1
bin/vite dev
```

```bash
# terminal 2
bin/rails server
```

(Or `gem install foreman && foreman start -f Procfile.dev` to run both at once.)

> If `ruby -v` is not 3.4.7, activate it first (e.g. `chruby 3.4.7`).

### 6. Try it

1. Open http://localhost:3000 and sign in as the demo user above.
2. Go to **Get a Recommendation**.
3. Enter a purchase, e.g.
   - Category: `Electronics`
   - Merchant: `Amazon`
   - Product: `iPhone 15 128GB`
   - Amount: `60000`
4. The agent runs its live searches (~1–2 minutes the first time; same-day
   repeat lookups are cached and instant) and returns a ranked recommendation
   with its search trace and SerpApi citations.

## Notes

- First lookups are slow because each live SerpApi call is sequential; results
  are cached per day, so re-asking the same purchase is instant.
- The demo wallet is capped at 3 cards (free tier). Add cards from the UI to
  change the wallet.
