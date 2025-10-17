defmodule DragnCardsGame.Card do
  @moduledoc """
  Represents a playing card.
  """
  require Logger
  alias DragnCardsGame.{CardFace,Tokens}

  @type t :: Map.t()

  @spec convert_to_integer(String.t()) :: number
  def convert_to_integer(my_string) do
    result = Integer.parse("#{my_string}")
    case result do
      {number, _} -> number
      :error -> 0
    end
  end

  @spec card_from_card_details(Map.t(), Map.t(), String.t(), String.t()) :: Map.t()
  def card_from_card_details(card_details, game_def, card_db_id, group_id) do
    Logger.debug("card_from_card_details 1")
    group = game_def["groups"][group_id]
    controller = group["controller"]
    base = %{
      "id" => Ecto.UUID.generate,
      "databaseId" => card_db_id,
      "currentSide" => group["defaultSideUp"] || "A",
      "rotation" => 0,
      "owner" => controller,
      "peeking" => %{},
      "targeting" => %{},
      "arrows" => %{},
      "tokens" => Tokens.new(game_def),
      "ruleIds" => [],
    }
    Logger.debug("card_from_card_details 2")
    # Handle both nested (card_details.sides.A) and flat (card_details.A) structures
    card_details_sides = cond do
      # New structure: sides is nested
      is_map(card_details["sides"]) and map_size(card_details["sides"]) > 0 ->
        card_details["sides"]
      # Old structure: sides are at root level
      true ->
        card_details
    end

    # loop over the sides in card_details and add them to the card
    sides = Enum.reduce(["A", "B", "C", "D", "E", "F", "G", "H"], %{}, fn(side, acc) ->
      Logger.debug("Adding side #{side} to card")
      case Map.has_key?(card_details_sides, side) do
        true ->
          val = card_details_sides[side]
          put_in(acc[side], CardFace.card_face_from_card_face_details(val, game_def, side, card_db_id))
        false ->
          acc
      end
    end)
    Logger.debug("card_from_card_details 3")

    # Add the sides to the card
    card = put_in(base["sides"], sides)

    # loop over the cardProperties in game_def
    card = Enum.reduce(game_def["cardProperties"], card, fn({key,val}, acc) ->
      put_in(acc[key], val["default"])
    end)

    card
  end
end
