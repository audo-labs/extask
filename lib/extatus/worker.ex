defmodule Extatus.Worker do
  use GenServer


  @callback run(task:: term) ::
  :ok | {:ok, data :: term} |
  {:error, reason :: term}

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      require Logger

      #
      # Client API
      #
      def start_link(tasks, opts \\ []) do
        GenServer.start_link(__MODULE__, tasks, opts) 
      end

      def status(pid) do
        GenServer.call(pid, :status)
      end

      def stop(pid) do
        GenServer.stop(pid)
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

        Logger.info("Starting #{task}")
        Task.start(__MODULE__, :process, [task, self()])

        {:noreply, Map.merge(state, %{todo: todo, executing: executing})}
      end

      def handle_info(:execute, state = %{todo: [], failed: _, executing: _, done: _, total: _}) do
        Logger.info("Finished: #{inspect state}")
        {:noreply, state}
      end

      def handle_cast({:complete, task}, state) do
        Logger.info("Completed #{inspect task}")
        schedule()
        {:noreply, Map.merge(state, %{executing: state.executing |> List.delete(task), done: [task | state.done]})}
      end

      def handle_cast({:error, task, reason}, state) do
        Logger.info("Task #{inspect task} failed: #{inspect reason}")
        schedule()
        {:noreply, Map.merge(state, %{executing: state.executing |> List.delete(task), failed: [{task, reason} | state.failed]})}
      end

      def process(task, pid) do
        Logger.info("Processing #{task}")
        case run(task) do
          :ok -> GenServer.cast(pid, {:complete, task})
          {:ok, info} -> GenServer.cast(pid, {:complete, task})
          {:error, reason} -> GenServer.cast(pid, {:error, task, reason})
          _ -> Logger.error("run(task) must return :ok | {:ok, data} | {:error, reason}")
        end
      end

      defp schedule do
        Process.send_after self(), :execute, 0
      end
    end
  end
end
