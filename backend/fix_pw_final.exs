alias DragnCards.Repo

# Update dev_user password with proper PBKDF2-SHA512 hash
hash = "$pbkdf2-sha512$100000$GShVG3fjLaNsgqVr92XdBg==$If41g/q/zoqlZ1sS1ijkKAdVzkUVrEO/vLaNIBsRKv1DCyHFgi3WZy9n1L/ZygWrDFyvqK+1FToNdbpEEeetAg=="

Repo.query!("UPDATE users SET password_hash = $1 WHERE alias = $2", [hash, "dev_user"])
IO.puts("✅ Updated dev_user password with PBKDF2-SHA512 hash")
