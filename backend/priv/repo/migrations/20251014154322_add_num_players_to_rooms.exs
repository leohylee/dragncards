defmodule DragnCards.Repo.Migrations.AddNumPlayersToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :num_players, :integer, default: 0
    end
  end
end
