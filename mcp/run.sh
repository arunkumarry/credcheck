#!/usr/bin/env bash
# Launcher for the CredCheck MCP server. Point your MCP client at this script.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# MCP clients launch with a minimal, non-login shell, so activate the project's
# Ruby (see .ruby-version) via whichever version manager is installed.
RUBY_WANTED="$(cat .ruby-version 2>/dev/null || echo ruby-3.4.7)"
for cs in /opt/homebrew/share/chruby/chruby.sh /usr/local/share/chruby/chruby.sh; do
  if [ -f "$cs" ]; then . "$cs"; chruby "$RUBY_WANTED" 2>/dev/null || true; break; fi
done
command -v rbenv >/dev/null 2>&1 && eval "$(rbenv init - bash)" || true

exec bundle exec ruby mcp/credcheck_mcp_server.rb
