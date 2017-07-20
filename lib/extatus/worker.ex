defmodule Extatus.Worker do
  use GenServer

  #
  # Client API
  #
  def start_link(module, tasks, opts \\ []) do
    GenServer.start_link(module, tasks, opts) 
  end

  def status(pid) do
    GenServer.call(pid, :status)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  @callback run(task:: term) ::
  :ok | {:ok, data :: term} |
  {:error, reason :: term} |
  {:pause, millis :: integer}

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use GenServer

      #
      # Server API
      #
      def init(tasks = [task | _]) do
        state = %{
          todo: tasks,
          failed: [],
          executing: [],
          done: [],
          total: Enum.count(tasks)
        }

        send self(), :started

        schedule(task)

        {:ok, state}
      end

      def handle_call(:status, _from, state = %{todo: _, failed: _, executing: _, done: done, total: total}) do
        {:reply, {Enum.count(done), total}, state}
      end

      def handle_info({:execute, task}, state) do
        todo = List.delete(state.todo, task)
        executing = [task | state.executing]

        Task.start(__MODULE__, :process, [task, self()])

        {:noreply, Map.merge(state, %{todo: todo, executing: executing})}
      end
      
      def handle_info(msg, state) do
        super(msg, state)
      end

      def handle_cast({:complete, task}, state = %{todo: [next | todo], failed: _, executing: _, done: _, total: _}) do
        send self(), {:complete, task}
        schedule(next)

        {:noreply, Map.merge(state, %{executing: state.executing |> List.delete(task), done: [task | state.done]})}
      end

      def handle_cast({:complete, task}, state = %{todo: [], failed: _, executing: _, done: _, total: _}) do
        send self(), {:complete, task}
        #exit(:normal)
        {:noreply, Map.merge(state, %{executing: state.executing |> List.delete(task), done: [task | state.done]})}
      end

      def handle_cast({:error, task, reason}, state = %{todo: [next | todo], failed: _, executing: _, done: _, total: _}) do
        send self(), {:failed, task}
        schedule(next)
        {:noreply, Map.merge(state, %{executing: state.executing |> List.delete(task), failed: [{task, reason} | state.failed]})}
      end

      def handle_cast({:error, task, reason}, state = %{todo: [], failed: _, executing: _, done: _, total: _}) do
        send self(), {:failed, task}
        exit(:normal)
        {:noreply, Map.merge(state, %{executing: state.executing |> List.delete(task), failed: [{task, reason} | state.failed]})}
      end

      def handle_cast({:pause, task, millis, reason}, state) do
        send self(), {:paused, task, millis, reason}
        schedule(task, millis)
        {:noreply, state}
      end

      def terminate(reason, state) do
        send self(), {:after, state.done, state.failed}
        super(reason, state)
      end

      def process(task, pid) do
        send self(), {:stated, task}
        case run(task) do
          :ok -> GenServer.cast(pid, {:complete, task})
          {:ok, info} -> GenServer.cast(pid, {:complete, task})
          {:pause, millis, reason} -> GenServer.cast(pid, {:pause, task, millis, reason})
          {:error, reason} -> GenServer.cast(pid, {:error, task, reason})
          _ -> raise("run(task) must return :ok | {:ok, data} | {:error, reason}")
        end
      end

      defp schedule(task, millis \\ 0) do
        Process.send_after self(), {:execute, task}, millis
      end
    end
  end
end
