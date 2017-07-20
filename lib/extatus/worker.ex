defmodule Extatus.Worker do
  use GenServer

  require Logger

  #
  # Client API
  #
  def start_link(tasks) do
    GenServer.start_link(__MODULE__, tasks, name: __MODULE__) 
  end

  def status() do
    GenServer.call(__MODULE__, :status)
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  #
  # Server API
  #
  def init(tasks) do
    state = %{
      todo: tasks,
      failed: [],
      executing: [],
      done: [],
      total: Enum.count(tasks)
    }

    schedule()

    {:ok, state}
  end

  def handle_call(:status, _from, state = %{todo: _, failed: _, executing: _, done: done, total: total}) do
    {:reply, {Enum.count(done), total}, state}
  end

  def handle_info(:execute, state = %{todo: [task | todo], failed: _, executing: _, done: _, total: _}) do
    executing = [task | state.executing]

    Task.start(__MODULE__, :process, [task, self()])

    {:noreply, Map.merge(state, %{todo: todo, executing: executing})}
  end

  def handle_info(:execute, state = %{todo: [], failed: _, executing: _, done: _, total: _}) do
    Logger.info("Completed: #{inspect state}")
    {:noreply, state}
  end

  def handle_cast({:complete, task}, state) do
    Logger.info("Completed #{inspect task}")
    schedule()
    {:noreply, Map.merge(state, %{executing: state.executing |> List.delete(task), done: [task | state.done]})}
  end

  def process(task, pid) do
    Logger.info("Processing #{task} started")
    :timer.sleep(10000)

    
    GenServer.cast(pid, {:complete, task})
  end

  defp schedule do
    Process.send_after self(), :execute, 0
  end

end
