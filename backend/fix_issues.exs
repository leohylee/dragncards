alias DragnCards.Repo
alias DragnCards.Users.User

# Fix dev_user password - use a valid bcrypt hash
# This is a bcrypt hash for password "password"
dev_user = Repo.get_by!(User, alias: "dev_user")
Repo.update!(User.changeset(dev_user, %{password_hash: "$2b$12$IQvJy0Pl4fL8LtIUKxqyJO9nIJYBH0l5zj0U8p/yQcP9zH7gTjLoy"}))
IO.puts("✅ Updated dev_user password")

# Verify update
updated_user = Repo.get!(User, dev_user.id)
IO.puts("User: #{updated_user.alias}, Email: #{updated_user.email}, Has password: #{String.length(updated_user.password_hash) > 0}")
