alias DragnCards.Repo
alias DragnCards.Users.User

# Get all users
users = Repo.all(User)
IO.puts("All users in database:")
Enum.each(users, fn user ->
  admin_flag = if user.admin, do: " [ADMIN]", else: ""
  IO.puts("  - #{user.alias} (#{user.email})#{admin_flag}")
end)
