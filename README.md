# CredCheck

**"Which credit card should I use for this purchase — right now?"**

CredCheck is an AI agent that picks the best credit card in your wallet for a
specific purchase, grounded in **live search data from SerpApi**. Instead of
relying on stale, hand-maintained offer lists, the agent fetches the current
price and today's bank offers at the moment you ask.

Built for the **SerpApi India Hackathon 2026** (AI Agents / Commerce tracks).

---

## How it works — the agent loop

When you enter a purchase, `Agents::PurchaseCopilot` runs a genuine
**plan → search → compare → act** loop. The LLM (Claude Haiku 4.5 via RubyLLM)
decides which searches to run and calls SerpApi **tools** itself:

| Step | What happens | SerpApi engine |
|------|--------------|----------------|
| Plan | Reads your wallet + the purchase, decides what to look up | — |
| Search | Live product price across merchants (if a product is named) | `google_shopping` |
| Search | Current card offers — one query per bank in your wallet | `google` |
| Search | Freshly announced sale events (optional) | `google_news` |
| Compare | Each card's base rewards + the applicable live offer | — |
| Act | Ranks every card, cites the exact SerpApi results used | — |

You don't even need to type a price — if you name a product, the agent
discovers the live price from Google Shopping itself. Every figure in the
recommendation traces back to a `[S#]` citation, and the UI shows the agent's
search trace so you can see exactly what it looked up.

**SerpApi is the core dependency** — remove the live searches and there is no
recommendation.

---

## Tech stack

- **Ruby on Rails 8** (Ruby 3.4.7), **PostgreSQL + pgvector**
- **RubyLLM** → **Anthropic Claude Haiku 4.5** (agent + tool calling)
- **SerpApi** (live search), **Vite + Tailwind** (frontend), **Hotwire/Turbo** (streaming results)

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Ruby | **3.4.7** | see `.ruby-version` (use rbenv / chruby / asdf) |
| Node.js | 18+ | for the Vite asset pipeline |
| PostgreSQL | 14+ | with the **pgvector** extension |
| API keys | — | a **SerpApi** key and an **Anthropic** key |

---

## Setup

### 1. Clone and enter the project

```bash
git clone <your-repo-url> credcheck
cd credcheck
```

### 2. Configure environment variables

```bash
cp .env.example .env
```

Then edit `.env` and set at least:

```
SERP_API_KEY=your_serpapi_key
ANTHROPIC_API_KEY=your_anthropic_key
```

### 3. Set up PostgreSQL + pgvector

Install and start PostgreSQL with the pgvector extension.

**macOS (Homebrew):**
```bash
brew install postgresql@16 pgvector
brew services start postgresql@16
```

**Ubuntu/Debian:**
```bash
sudo apt-get install -y postgresql postgresql-16-pgvector
sudo service postgresql start
```

The app connects as role `postgres` / password `password` on `localhost:5432`
(see `config/database.yml`). Create that role if you don't have it:

```bash
psql -d postgres -c "CREATE ROLE postgres WITH LOGIN SUPERUSER PASSWORD 'password';"
```

> Prefer your own DB user? Edit the `default:` block in `config/database.yml`
> instead of creating the `postgres` role.

### 4. Install dependencies

```bash
bundle install
npm install
```

### 5. Create, migrate, and seed the database

```bash
bin/rails db:prepare
```

This creates the database, loads the schema (enabling pgvector), and seeds:

- 5 banks and a demo card catalogue (with reward structures),
- a **demo user** with a ready-made 3-card wallet.

**Demo login**

| | |
|---|---|
| Email | `demo@credcheck.in` |
| Password | `password123` |
| Wallet | Amazon Pay ICICI · HDFC Regalia Gold · Axis Ace |

### 6. Run the app

CredCheck needs both the Vite dev server and the Rails server. In two terminals:

```bash
# terminal 1 — asset pipeline
bin/vite dev
```

```bash
# terminal 2 — web server
bin/rails server
```

> One terminal instead? `gem install foreman && foreman start -f Procfile.dev`
> runs both at once.

Now open **http://localhost:3000**, sign in as the demo user, and go to
**Get a Recommendation**.

---

## Try it

1. Sign in at http://localhost:3000 with the demo credentials above.
2. Open **Get a Recommendation** (it's also the dashboard home).
3. Enter a purchase, e.g.
   - **Category:** `Electronics`
   - **Merchant:** `Amazon`
   - **Product:** `iPhone 17 256GB`
   - **Amount:** *(leave blank — the agent detects the live price)*
4. Watch the agent run its live searches (~30–90s the first time), then get a
   ranked recommendation with the search trace and SerpApi citations.

Same-day repeat lookups are cached, so re-asking the same purchase is instant.

---

## Use it from AI clients (MCP)

CredCheck ships an **MCP server** so you can use it directly inside Claude
Desktop / Claude Code and other MCP clients — ask "which card should I use for
an iPhone 17 on Amazon?" and it answers with the best card, the rupee value, and
the live SerpApi sources. Tools: `recommend_card`, `live_product_price`,
`list_wallet`. See **[mcp/README.md](mcp/README.md)** for setup.

```bash
# sanity check
bundle exec ruby mcp/credcheck_mcp_server.rb
```

## Project structure (key files)

```
app/services/live_search/
  serp_api_client.rb        # SerpApi REST wrapper (google / shopping / news)
  offer_finder.rb           # (legacy) hardcoded live-offer pipeline
app/services/agents/
  purchase_copilot.rb       # the tool-calling agent (plan → search → compare → act)
  search_trace.rb           # captures the agent's plan + citations
  tools/                    # ShoppingSearch / OfferSearch / NewsSearch (RubyLLM tools)
app/services/rag_agent.rb   # caches the agent result; legacy fallback; normalizes output
db/seeds.rb                 # banks, demo cards, demo user + wallet
db/seeds_card_rewards.rb    # card reward structures the agent folds into each result
```

---

## Troubleshooting

- **`extension "vector" is not available`** — pgvector isn't installed for your
  PostgreSQL. Install it (step 3) and restart PostgreSQL.
- **`password authentication failed for user "postgres"`** — create the role
  (step 3) or point `config/database.yml` at your own DB user.
- **Wrong Ruby version** — ensure `ruby -v` shows 3.4.7 (e.g. `rbenv local 3.4.7`
  or `chruby 3.4.7`).
- **The agent is slow on the first lookup** — expected; each live SerpApi call
  is sequential. Results are cached per day.
- **`Could not find <gem>`** — run `bundle install` again.

---

## Disclosures

- **AI tools:** developed with AI coding assistance (Claude). The product itself
  uses Anthropic Claude (via RubyLLM) as its recommendation engine.
