defmodule ExtaskTest do
  use ExUnit.Case
  doctest Extask

  defmodule TestWorker do
    use Extask.Worker

    def run(task, _meta) do
      case task do
        :error -> {:error, "fail"}
        :ok -> :ok
        :raise -> raise("bad things happen")
        _ -> :ok
      end
    end

    def handle_status(:job_complete, state) do
      if state.meta[:pid], do: send state.meta[:pid], :job_complete
      {:noreply, state}
    end

    def handle_status(_a, state) do
      {:noreply, state}
    end
  end

  test "return error instead exception" do
    Extask.start_child(TestWorker, [:raise], [id: :misbehave, pid: self()])

    assert_receive :job_complete
  end

  test "receive :job_complete" do
    Extask.start_child(TestWorker, [1], [pid: self()])

    assert_receive :job_complete
  end

  test "set non-generated id" do
    {:ok, pid} = Extask.start_child(TestWorker, [1], [id: 2])

    assert pid == Extask.find_child(2)
  end

  test "retrieve status using id" do
    Extask.start_child(TestWorker, [:error], [id: 1, pid: self()])

    assert_receive :job_complete
    assert %{done: [], executing: [], failed: [{:error, "fail"}], meta: [id: 1, pid: _], todo: [], total: 1} = Extask.child_status(1) 
  end

  test "return nil when asking status for inexistent child id" do
    assert Extask.child_status(:inexistent) == nil
  end

  test "stop child" do
    Extask.start_child(TestWorker, [1], [id: :i_dont_deserve_to_live])

    assert :ok == Extask.terminate_child(:i_dont_deserve_to_live)
  end

  test "stop and start child" do
    Extask.start_child(TestWorker, [1], [id: :highlander])
    assert :ok == Extask.terminate_child(:highlander)
    {:ok, pid} = Extask.start_child(TestWorker, [:task], id: :highlander)
    assert pid == Extask.find_child(:highlander)
  end

  test "stop non existing child" do
    assert {:error, :not_found} == Extask.terminate_child(:gost)
  end

  test "error on the last item" do
    state = %{done: [3, 1], executing: [4], failed: [{2, "number is even"}], todo: [],
      total: 4}
    next_state = %{done: [3, 1], executing: [], failed: [{4, "fail"}, {2, "number is even"}], todo: [],
      total: 4}

    assert TestWorker.handle_cast({:error, 4, "fail"}, state) == {:noreply, next_state}
  end
end
