alias DragnCards.Repo
alias DragnCards.Plugins.Plugin

plugins = Repo.all(Plugin)
IO.puts("Total plugins: #{length(plugins)}")
Enum.each(plugins, fn p ->
  IO.puts("- #{p.name}: version #{p.version}")
end)
