#{:ok, _} = Application.ensure_all_started(:dragncards)

alias DragnCards.{Repo, Plugins, Plugins.Plugin}
alias DragnCards.Users.User
alias DragnCardsUtil.{Merger}
import Ecto.Query

# Get the dev_user
user = Repo.get_by!(User, alias: "dev_user")

# Set up paths
plugin_json_path = "/app/priv/dragncards-lotrlcg-plugin/jsons"
frontend_card_db_path = "/app/priv/cardDb.json"

IO.puts("Loading JSON files from: #{plugin_json_path}")
filenames = Path.wildcard(Path.join(plugin_json_path, "*.json"))
IO.puts("Found #{length(filenames)} JSON files")

# Merge all JSON files into game_def
game_def = Merger.merge_json_files(filenames)

IO.puts("Loading card database from: #{frontend_card_db_path}")

# Load and transform the cardDb.json
{:ok, card_db_json} = File.read(frontend_card_db_path)
{:ok, card_db_nested} = Jason.decode(card_db_json)

# Keep nested structure (sides.A and sides.B) as frontend expects it
card_db = Enum.reduce(card_db_nested, %{}, fn {card_id, card}, acc ->
  transformed_card = if Map.has_key?(card, "sides") do
    # Extract sides and add imageUrl to each side
    sides = Map.get(card, "sides")

    # Add imageUrl and packName to each side (A and B) using the card's database ID
    sides_with_images = Enum.reduce(sides, %{}, fn {side_key, side_data}, sides_acc ->
      # Only add imageUrl to side A (front face)
      # Side B should NOT have imageUrl so it falls back to card backs
      side_with_image = if side_key == "A" and not Map.has_key?(side_data, "imageUrl") do
        Map.put(side_data, "imageUrl", "#{card_id}.jpg")
      else
        side_data
      end

      # Add packName and numberInPack to each side so they're accessible in the spawn modal
      side_with_pack = side_with_image
      |> Map.put("packName", Map.get(card, "cardpackname"))
      |> Map.put("numberInPack", Map.get(card, "cardnumber"))

      Map.put(sides_acc, side_key, side_with_pack)
    end)

    # Keep sides nested, add packName and numberInPack to root for compatibility
    card
    |> Map.put("sides", sides_with_images)
    |> Map.put("packName", Map.get(card, "cardpackname"))
    |> Map.put("numberInPack", Map.get(card, "cardnumber"))
  else
    # Already has A/B at root - wrap them in sides structure
    side_a = Map.get(card, "A", %{})
    side_b = Map.get(card, "B", %{})

    sides = %{
      "A" => side_a
        |> (fn side -> if Map.has_key?(side, "imageUrl"), do: side, else: Map.put(side, "imageUrl", "#{card_id}.jpg") end).()
        |> Map.put("packName", Map.get(card, "cardpackname"))
        |> Map.put("numberInPack", Map.get(card, "cardnumber")),
      "B" => side_b
        # Don't add imageUrl to side B - it should use card backs
        |> Map.put("packName", Map.get(card, "cardpackname"))
        |> Map.put("numberInPack", Map.get(card, "cardnumber"))
    }

    # Remove A and B from root, add sides
    card
    |> Map.delete("A")
    |> Map.delete("B")
    |> Map.put("sides", sides)
    |> Map.put("packName", Map.get(card, "cardpackname"))
    |> Map.put("numberInPack", Map.get(card, "cardnumber"))
  end

  Map.put(acc, card_id, transformed_card)
end)

IO.puts("Checking sample transformation...")
sample_id = "18a1afb6-7d29-40bf-8580-7089f2c1eec1"
if Map.has_key?(card_db, sample_id) do
  sample = card_db[sample_id]
  IO.puts("Sample card has 'sides': #{Map.has_key?(sample, "sides")}")
  IO.puts("Sample card has 'packName': #{Map.has_key?(sample, "packName")}")
  IO.puts("Sample card packName: #{sample["packName"]}")
  IO.puts("Sample card numberInPack: #{sample["numberInPack"]}")
  if Map.has_key?(sample, "sides") do
    IO.puts("Side A name: #{sample["sides"]["A"]["name"]}")
    IO.puts("Side A has imageUrl: #{Map.has_key?(sample["sides"]["A"], "imageUrl")}")
    IO.puts("Side A has packName: #{Map.has_key?(sample["sides"]["A"], "packName")}")
    if Map.has_key?(sample["sides"]["A"], "imageUrl") do
      IO.puts("Side A imageUrl: #{sample["sides"]["A"]["imageUrl"]}")
    end
    if Map.has_key?(sample["sides"]["A"], "packName") do
      IO.puts("Side A packName: #{sample["sides"]["A"]["packName"]}")
    end
    IO.puts("Side B name: #{sample["sides"]["B"]["name"]}")
  end
end

IO.puts("Found #{length(Map.keys(card_db))} cards")

# Update or create the plugin
existing_plugin = Repo.one(from p in Plugin, where: p.name == "Lord of the Rings LCG")

plugin_params = %{
  name: "Lord of the Rings LCG",
  version: existing_plugin.version + 1,  # Increment version to trigger client reload
  game_def: game_def,
  card_db: card_db,
  num_favorites: existing_plugin.num_favorites || 0,
  public: true,
  author_id: user.id,
  repo_url: existing_plugin.repo_url
}

result = if existing_plugin do
  IO.puts("Updating existing plugin (ID: #{existing_plugin.id})...")
  IO.puts("Version: #{existing_plugin.version} -> #{existing_plugin.version + 1}")
  Plugins.update_plugin(existing_plugin, plugin_params)
else
  IO.puts("Creating new plugin...")
  Plugins.create_plugin(plugin_params)
end

case result do
  {:ok, plugin} ->
    IO.puts("✅ Successfully saved plugin: #{plugin.name} (ID: #{plugin.id})")
    IO.puts("   Card count: #{length(Map.keys(plugin.card_db))}")
    IO.puts("   Version: #{plugin.version}")
  {:error, changeset} ->
    IO.puts("❌ Failed to save plugin:")
    IO.inspect(changeset.errors)
end
