alias DragnCards.Repo
alias DragnCards.Users.User

user = Repo.insert!(%User{
  alias: "dev_user",
  email: "dev@example.com",
  password_hash: ""
})

IO.puts("Created user: #{user.id}")
