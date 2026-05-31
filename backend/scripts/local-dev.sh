#!/bin/bash

# Make sure hex/rebar are installed, but only fetch them if missing so a cold
# boot works fully offline when deps are already vendored in backend/deps.
mix local.hex --if-missing --force  || echo "WARN: could not install hex (offline?); continuing with what's available"
mix local.rebar --if-missing --force || echo "WARN: could not install rebar (offline?); continuing with what's available"

# Get deps (no-op when already vendored). Tolerate no network so we fall back
# to the committed backend/deps instead of aborting the boot.
mix deps.get || echo "WARN: mix deps.get failed (offline?); using vendored deps in backend/deps"

# Do any DB migration
mix ecto.setup

# Start the server
mix phx.server