# CredCheck MCP server

Expose CredCheck's live, SerpApi-grounded card recommendation to any MCP client
(Claude Desktop, Claude Code, Cursor, …) as tools.

## Tools

| Tool | What it does |
|------|--------------|
| `recommend_card` | The full agent: live price (Google Shopping) + this month's bank offers (Google) → every card ranked by rupee value, with reasoning and the live sources. Give a `product` and it auto-detects the price. |
| `live_product_price` | Live price of a product across Indian merchants (SerpApi Google Shopping). |
| `list_wallet` | The cards in the configured CredCheck wallet. |

The wallet it reasons over belongs to the user in `CREDCHECK_MCP_USER_EMAIL`
(default `demo@credcheck.in`). It reuses the app's `.env` keys
(`SERP_API_KEY`, `ANTHROPIC_API_KEY`) and database, so **set the app up first**
(see the main [README](../README.md)) — the MCP server boots the same Rails app.

## Run it directly (sanity check)

```bash
bundle exec ruby mcp/credcheck_mcp_server.rb
```

It speaks MCP over stdio. You can pipe JSON-RPC in to test, e.g. list the tools:

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | bundle exec ruby mcp/credcheck_mcp_server.rb
```

## Add to Claude Desktop

Edit `claude_desktop_config.json`
(macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`) and add:

```json
{
  "mcpServers": {
    "credcheck": {
      "command": "/ABSOLUTE/PATH/TO/credcheck/mcp/run.sh",
      "env": {
        "CREDCHECK_MCP_USER_EMAIL": "demo@credcheck.in"
      }
    }
  }
}
```

Replace `/ABSOLUTE/PATH/TO/credcheck` with the project's absolute path, then
restart Claude Desktop. `mcp/run.sh` activates the project's Ruby (chruby/rbenv)
before launching, because MCP clients start with a minimal shell.

Now ask Claude things like:

> I'm buying an iPhone 17 256GB on Amazon — which of my cards should I use?

Claude will call `recommend_card` and answer with the best card, the rupee
value, and the live SerpApi sources.

## Add to Claude Code

```bash
claude mcp add credcheck -- /ABSOLUTE/PATH/TO/credcheck/mcp/run.sh
```

## Notes

- The first `recommend_card` call runs live SerpApi searches and can take
  ~30–90s; same-day repeat lookups are cached and fast.
- To reason over a different wallet, point `CREDCHECK_MCP_USER_EMAIL` at another
  user (create one and add cards in the web app first).
