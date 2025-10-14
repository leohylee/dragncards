#{:ok, _} = Application.ensure_all_started(:dragncards)

alias DragnCards.{Repo, Plugins, Plugins.Plugin}
alias DragnCards.Users.User
alias DragnCardsUtil.{Merger, TsvProcess}
import Ecto.Query

# Get the dev_user
user = Repo.get_by!(User, alias: "dev_user")

# Set up paths to the plugin repository
plugin_json_path = "/app/priv/dragncards-mc-plugin/jsons"
plugin_tsv_path = "/app/priv/dragncards-mc-plugin/tsvs"

IO.puts("Loading JSON files from: #{plugin_json_path}")
filenames = Path.wildcard(Path.join(plugin_json_path, "*.json"))
IO.puts("Found #{length(filenames)} JSON files")

# Merge all JSON files into game_def
game_def = Merger.merge_json_files(filenames)

IO.puts("Loading TSV files from: #{plugin_tsv_path}")
filenames_tsv = Path.wildcard(Path.join(plugin_tsv_path, "*.tsv"))
IO.puts("Found #{length(filenames_tsv)} TSV files")

# Process TSV files into card_db
card_db = Enum.reduce(filenames_tsv, %{}, fn(filename, acc) ->
  rows = File.stream!(filename)
  |> Stream.map(&String.split(&1, "\t"))
  |> Enum.to_list()

  temp_db = TsvProcess.process_rows(game_def, rows)
  Merger.deep_merge([acc, temp_db])
end)

IO.puts("Found #{length(Map.keys(card_db))} cards")

# Update or create the plugin
existing_plugin = Repo.one(from p in Plugin, where: p.name == "Marvel Champions")

plugin_params = %{
  name: "Marvel Champions",
  version: 1,
  game_def: game_def,
  card_db: card_db,
  num_favorites: 0,
  public: true,
  author_id: user.id
}

result = if existing_plugin do
  IO.puts("Updating existing plugin (ID: #{existing_plugin.id})...")
  Plugins.update_plugin(existing_plugin, plugin_params)
else
  IO.puts("Creating new plugin...")
  Plugins.create_plugin(plugin_params)
end

case result do
  {:ok, plugin} ->
    IO.puts("✅ Successfully saved plugin: #{plugin.name} (ID: #{plugin.id})")
  {:error, changeset} ->
    IO.puts("❌ Failed to save plugin:")
    IO.inspect(changeset.errors)
end
