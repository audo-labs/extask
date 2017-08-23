defmodule ExtaskTest do
  use ExUnit.Case
  doctest Extask

  defmodule TestWorker do
    use Extask.Worker

    def run(_task, _meta) do
      {:error, "fail"}
    end

    def handle_status(:job_complete, state) do
      if state.meta[:pid], do: send state.meta[:pid], :job_complete
      {:noreply, state}
    end

    def handle_status(_a, state) do
      {:noreply, state}
    end

  end

  test "receive :job_complete" do
    Extask.start_child(TestWorker, [1], [pid: self()])

    assert_receive :job_complete
  end

  test "set non-generated id" do
    {:ok, pid} = Extask.start_child(TestWorker, [1], [id: 2])

    assert pid == Extask.Supervisor.find_child(2)
  end

  test "retrieve status using id" do
    Extask.start_child(TestWorker, [1], [id: 1, pid: self()])

    assert_receive :job_complete
    assert %{done: [], executing: [], failed: [{1, "fail"}], meta: [id: 1, pid: _], todo: [], total: 1} = Extask.child_status(1) 
  end

  test "error on the last item" do
    state = %{done: [3, 1], executing: [4], failed: [{2, "number is even"}], todo: [],
      total: 4}
    next_state = %{done: [3, 1], executing: [], failed: [{4, "fail"}, {2, "number is even"}], todo: [],
      total: 4}

    assert TestWorker.handle_cast({:error, 4, "fail"}, state) == {:noreply, next_state}
  end
end
