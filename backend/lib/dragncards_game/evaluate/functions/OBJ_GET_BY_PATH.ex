defmodule DragnCardsGame.Evaluate.Functions.OBJ_GET_BY_PATH do
  alias DragnCardsGame.Evaluate
  @moduledoc """
  *Arguments*:
  1. `object` (object)
  2. `keyList` (list of keys, like `["LIST", "tokens", "damage"]`)

  Returns the value at the given `keyList` path in the object. If the path is invalid, returns `null`.

  This function is not normally used due to the convenience of the dot syntax for accessing object properties.

  *Returns*:
  (any) The value at the given path in the object.

  *Examples*:

  Check if the number of damage tokens on the active card equals or exceeds its hitPoints
  ```
  ["GREATER_EQUAL",
    ["OBJ_GET_BY_PATH",  "$ACTIVE_CARD", ["LIST", "tokens", "damage"]],
    ["OBJ_GET_BY_PATH",  "$ACTIVE_CARD", ["LIST", "hitPoints"]]
  ]
  ```
  This is equivalent to the dot syntax:
  ```
  ["GREATER_EQUAL",
    "$ACTIVE_CARD.tokens.damage",
    "$ACTIVE_CARD.hitPoints"
  ]
  ```

  """

  @doc """
  Executes the 'OBJ_GET_BY_PATH' operation with the given arguments.

  ## Parameters

    - `args`: The arguments required for the 'OBJ_GET_BY_PATH' operation.

  ## Returns

  The result of the 'OBJ_GET_BY_PATH' operation.
  """
  def execute(game, code, trace) do
    map = Evaluate.evaluate(game, Enum.at(code,1), trace ++ ["map"])
    path = Evaluate.evaluate(game, Enum.at(code,2), trace ++ ["path"])
    Enum.reduce(Enum.with_index(path), map, fn({pathi, index}, acc) ->
      cond do
        pathi == nil ->
          raise "Tried to access nil in path #{inspect(path)}."
        String.starts_with?(pathi, "[") and String.ends_with?(pathi, "]") ->
          int_str = Evaluate.evaluate(game, String.slice(pathi,1..-2), trace ++ ["index #{index}"])
          int = Evaluate.convert_to_integer(int_str)
          if acc == nil do
            raise "Tried to access index #{int} on a null array."
          end
          if not is_list(acc) do
            raise "Tried to access index #{int} on a non-array object."
          end
          if Enum.count(acc) <= int do
            raise "Tried to access index #{int} on an array of length #{Enum.count(acc)}."
          end
          Enum.at(acc, int)
        pathi == "currentFace" ->
          current_side = if acc["currentSide"] == nil do
            raise "Tried to access currentFace on an object where currentSide is null."
          else
            acc["currentSide"]
          end

          # Handle both nested (sides.A) and flat (A) structures
          cond do
            # New structure: sides is a non-empty map with A and B keys
            is_map(acc["sides"]) and map_size(acc["sides"]) > 0 and Map.has_key?(acc["sides"], current_side) ->
              acc["sides"][current_side]

            # Old structure: A and B are at the root level
            Map.has_key?(acc, current_side) ->
              acc[current_side]

            # Error case - provide detailed debugging info
            true ->
              sides_info = cond do
                acc["sides"] == nil -> "sides is nil"
                is_list(acc["sides"]) -> "sides is a list: #{inspect(acc["sides"])}"
                is_map(acc["sides"]) and map_size(acc["sides"]) == 0 -> "sides is an empty map"
                is_map(acc["sides"]) -> "sides is a map but missing #{current_side}, has keys: #{inspect(Map.keys(acc["sides"]))}"
                true -> "sides is: #{inspect(acc["sides"])}"
              end
              raise "Cannot access currentFace. currentSide=#{current_side}, #{sides_info}, card keys=#{inspect(Map.keys(acc))}"
          end
        pathi == "stackParentCard" ->
          game["cardById"][acc["stackParentCardId"]]
        pathi == "parentCardIds" ->
          # Make sure there is a stackIds key
          if Map.has_key?(acc, "stackIds") do
            # Get the stackIds
            stack_ids = acc["stackIds"]
            # Return a list of the parent card ids
            Enum.map(stack_ids, fn(stack_id) ->
              # Get the stack
              stack = game["stackById"][stack_id]
              # Get the parent card id
              if stack == nil do
                raise "Tried to access parentCardIds but one of the stacks is null."
              end
              Enum.at(stack["cardIds"], 0)
            end)
          else
            raise "Tried to access parentCardIds on a non-group object."
          end
        pathi == "parentCards" ->
          # Make sure there is a stackIds key
          if Map.has_key?(acc, "stackIds") do
            # Get the stackIds
            stack_ids = acc["stackIds"]
            # Return a list of the parent card ids
            Enum.map(stack_ids, fn(stack_id) ->
              # Get the stack
              stack = game["stackById"][stack_id]
              # Get the parent card id
              card_id = Enum.at(stack["cardIds"], 0)
              game["cardById"][card_id]
            end)
          else
            raise "Tried to access parentCards on a non-group object."
          end
        pathi == "parentCard" ->
          # Make sure there is a parentCardId key
          if Map.has_key?(acc, "parentCardId") do
            game["cardById"][acc["parentCardId"]]
          else
            raise "Tried to access parentCard on a non-card object."
          end
        acc == nil ->
          nil
        not is_map(acc) or is_struct(acc, MapSet) ->
          raise "Tried to access key '#{pathi}' of a non-object: #{inspect(acc)}."
        Map.has_key?(acc, pathi) ->
          Map.get(acc, Evaluate.evaluate(game, pathi, trace ++ ["key #{index}"]))
        true ->
          nil
          #raise "Tried to access #{pathi} on an object that doesn't have that key. Only keys are #{Map.keys(acc)}. #{inspect(trace)}"
      end
    end)
  end




end
