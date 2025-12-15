alias DragnCards.Repo

# Fix dev_user password using raw SQL to bypass validation
# This is a bcrypt hash for password "password"
Repo.query!("UPDATE users SET password_hash = $1 WHERE alias = $2", [
  "$2b$12$IQvJy0Pl4fL8LtIUKxqyJO9nIJYBH0l5zj0U8p/yQcP9zH7gTjLoy",
  "dev_user"
])
IO.puts("✅ Updated dev_user password")

# Check all plugins
alias DragnCards.Plugins.Plugin
plugins = Repo.all(Plugin)
IO.puts("\n📦 Current plugins:")
Enum.each(plugins, fn p ->
  IO.puts("   - #{p.name}: v#{p.version}")
end)
