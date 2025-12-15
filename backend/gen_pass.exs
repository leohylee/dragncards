#{:ok, _} = Application.ensure_all_started(:dragncards)

# Generate Argon2 hash for password "password"
password_hash = Pow.Ecto.Schema.Password.pbkdf2_hash("password")
IO.puts("Argon2 hash: #{password_hash}")
