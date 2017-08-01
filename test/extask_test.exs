defmodule ExtaskTest do
  use ExUnit.Case
  doctest Extask

  defmodule TestWorker do
    use Extask.Worker

    def run(_task) do
      {:error, "fail"}
    end

  end

  test "error on the last item" do
    state = %{done: [3, 1], executing: [4], failed: [{2, "number is even"}], todo: [],
      total: 4}
    next_state = %{done: [3, 1], executing: [], failed: [{4, "fail"}, {2, "number is even"}], todo: [],
      total: 4}

    assert TestWorker.handle_cast({:error, 4, "fail"}, state) == {:noreply, next_state}
  end
end
