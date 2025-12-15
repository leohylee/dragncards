#{:ok, _} = Application.ensure_all_started(:dragncards)

alias DragnCards.{Repo, Plugins, Plugins.Plugin}
alias DragnCards.Users.User
import Ecto.Query

# Get the dev_user
user = Repo.get_by!(User, alias: "dev_user")

# Set up paths to the cloned plugin repository
plugin_json_path = "/Users/leo/Projects/dragncards-mc-plugin/json"

IO.puts("Loading JSON files from: #{plugin_json_path}")
filenames = Path.wildcard(Path.join(plugin_json_path, "*.json"))
  |> Enum.filter(&(!String.contains?(&1, [".swp"])))
IO.puts("Found #{length(filenames)} JSON files")

# Load and merge all JSON files
game_def = filenames
  |> Enum.reduce(%{}, fn(filename, acc) ->
    {:ok, content} = File.read(filename)
    {:ok, json} = Jason.decode(content)
    Map.merge(acc, json)
  end)

IO.puts("✅ Loaded game definition with #{length(Map.keys(game_def))} keys")

# For Marvel Champions, we don't have a separate TSV card_db
# We'll use an empty card_db since the game_def contains the card definitions
card_db = %{}

IO.puts("Card database ready (using game_def for card data)")

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
    IO.puts("✅ Successfully saved plugin: #{plugin.name} (ID: #{plugin.id}, Version: #{plugin.version})")
  {:error, changeset} ->
    IO.puts("❌ Failed to save plugin:")
    IO.inspect(changeset.errors)
end
