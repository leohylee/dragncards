alias DragnCards.Repo
alias DragnCards.Users.User

# Get dev_user
user = Repo.get_by(User, alias: "dev_user")
IO.puts("User found: #{user != nil}")
IO.puts("Alias: #{user.alias}")
IO.puts("Email: #{user.email}")
IO.puts("Password hash: #{user.password_hash}")
IO.puts("Password hash length: #{String.length(user.password_hash)}")

# Try to verify password
case Argon2.check_pass(user, "password") do
  {:ok, _user} -> IO.puts("✅ Password 'password' matches!")
  {:error, _} -> IO.puts("❌ Password 'password' does NOT match")
end
