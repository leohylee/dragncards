#{:ok, _} = Application.ensure_all_started(:dragncards)

alias DragnCards.{Repo, Plugins, Plugins.Plugin}
alias DragnCards.Users.User
alias DragnCardsUtil.{Merger, TsvProcess}
import Ecto.Query

# Get the dev_user
user = Repo.get_by!(User, alias: "dev_user")

# Set up paths to the cloned plugin repository
plugin_json_path = "/app/priv/dragncards-lotrlcg-plugin/jsons"
plugin_tsv_path = "/app/priv/dragncards-lotrlcg-plugin/tsvs"

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

IO.puts("Found #{length(Map.keys(card_db))} cards from TSV files")

# Load official cards from cardDb.json and merge them
cardDb_path = "/app/priv/cardDb.json"
card_db = if File.exists?(cardDb_path) do
  IO.puts("Loading official cards from: #{cardDb_path}")
  {:ok, cardDb_content} = File.read(cardDb_path)
  official_cards = Jason.decode!(cardDb_content)

  # Convert official cards format (which has side data) to match TSV format
  official_card_db = Map.new(official_cards, fn {card_id, card_data} ->
    # official cards already have the sides format, so just use them directly
    {card_id, card_data}
  end)

  IO.puts("Loaded #{length(Map.keys(official_card_db))} official cards")

  # Merge official cards with ALeP cards (ALeP cards take precedence if there's a conflict)
  Merger.deep_merge([official_card_db, card_db])
else
  IO.puts("⚠️  Official cardDb.json not found at #{cardDb_path}, using only TSV cards")
  card_db
end

IO.puts("Total cards in database: #{length(Map.keys(card_db))} (Official + ALeP)")

# Update or create the plugin
existing_plugin = Repo.one(from p in Plugin, where: p.name == "Lord of the Rings LCG")

plugin_params = %{
  name: "Lord of the Rings LCG",
  version: 4,
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
