defmodule ExtaskTest do
  use ExUnit.Case
  doctest Extask

  defmodule TestWorker do
    use Extask.Worker

    def before_run(state) do
      case state.meta[:before_run] do
        nil ->
          {:ok, {:done, [], state.meta}}
        :empty_tasks ->
          {:ok, {:tasks, [], state.meta}}
        :gen_tasks ->
          {:ok, {:tasks, [:todo], state.meta}}
        :new_meta ->
          {:ok, {:tasks, [:todo], :meta_info}}
        :error ->
          send state.meta[:pid], :before_run_error
          case state.meta[:worker_pid] do
            nil -> nil
            _ -> send state.meta[:worker_pid], {:change_exit_status, :before_run, :ok}
          end
          :error
        :ok ->
          {:ok, {:done, [], state.meta}}
      end
    end

    def run(task, _meta) do
      case task do
        :error -> {:error, "fail"}
        :ok -> {:ok, nil}
        :raise -> raise("bad things happen")
        _ -> {:ok, nil}
      end
    end

    def after_run(state) do
      case state.meta[:after_run] do
        nil ->
          {:ok, {:done, [], state.meta}}
        :error ->
          send state.meta[:pid], :after_run_error
          case state.meta[:worker_pid] do
            nil -> nil
            _ -> send state.meta[:worker_pid], {:change_exit_status, :after_run, :ok}
          end
          :error
        :ok ->
          {:ok, {:done, [], state.meta}}
      end
    end

    def handle_info({:change_exit_status, function, status}, state) do
      {:noreply, Map.put(state, :meta, state.meta |> Keyword.put(function, status))}
    end

    def handle_status(:job_complete, state) do
      if state.meta[:pid], do: send state.meta[:pid], :job_complete
      {:noreply, state}
    end

    def handle_status(_a, state) do
      {:noreply, state}
    end

  end

  test "generate task list on before_run" do
    Extask.start_child(TestWorker, [], [id: :gen_tasks, pid: self(), before_run: :gen_tasks])

    assert_receive :job_complete
    assert %{done: [{:todo, _}], executing: [], failed: [], meta: _, todo: [], total: 1} = Extask.child_status(:gen_tasks)
  end

  test "generate empty task list on before_run" do
    Extask.start_child(TestWorker, [], [id: :empty_tasks, pid: self(), before_run: :empty_tasks])

    assert_receive :job_complete
    assert %{done: [], executing: [], failed: [], meta: _, todo: [], total: 0} = Extask.child_status(:empty_tasks)
  end

  test "run after_run start until success" do
    Extask.start_child(TestWorker, [:raise], [pid: self(), after_run: :error])

    assert_receive :after_run_error
    assert_receive :job_complete, 10000
  end

  test "run before_run start until success" do
    Extask.start_child(TestWorker, [:raise], [pid: self(), before_run: :error])

    assert_receive :before_run_error
    assert_receive :job_complete, 10000
  end

  test "return error instead exception" do
    Extask.start_child(TestWorker, [:raise], [id: :misbehave, pid: self()])

    assert_receive :job_complete
  end

  test "receive :job_complete" do
    Extask.start_child(TestWorker, [1], [pid: self()])

    assert_receive :job_complete
  end

  test "complete empty task list" do
    {:ok, pid} = Extask.start_child(TestWorker, [], [pid: self()])

    assert_receive :job_complete
    assert %{done: [], executing: [], failed: [], meta: _, todo: [], total: 0} = Extask.child_status(pid)
  end

  test "set non-generated id" do
    {:ok, pid} = Extask.start_child(TestWorker, [1], [id: 2])

    assert pid == Extask.find_child(2)
  end

  test "retrieve status using id" do
    Extask.start_child(TestWorker, [:error], [id: 1, pid: self()])

    assert_receive :job_complete
    assert %{done: [], executing: [], failed: [{:error, "fail"}], meta: _, todo: [], total: 1} = Extask.child_status(1)
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

  test "retrieve info after task done" do
    state = %{done: [], executing: [1], failed: [], todo: [], total: 1}
    next_state = %{done: [{1, 1}], executing: [], failed: [], todo: [], total: 1}

    assert TestWorker.handle_cast({:complete, {1, 1}}, state) == {:noreply, next_state}
  end
end
