defmodule Extask.Worker do
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
  :retry |
  {:retry, millis :: integer} |
  {:error, reason :: term}

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

        schedule(:execute, task)

        {:ok, state}
      end

      def handle_call(:status, _from, state = %{todo: _, failed: _, executing: _, done: done, total: total}) do
        {:reply, state, state}
      end

      def handle_cast({:execute, task}, state) do
        todo = List.delete(state.todo, task)
        executing = [task | state.executing]

        Task.start(__MODULE__, :process, [task, self()])

        {:noreply, Map.merge(state, %{todo: todo, executing: executing})}
      end

      def handle_info({:execute, task}, state) do
        GenServer.cast(self(), {:execute, task})
        {:noreply, state}
      end

      def handle_info({:retry, task}, state) do
        GenServer.cast(self(), {:retry, task})
        {:noreply, state}
      end

      def handle_info(msg, state) do
        super(msg, state)
      end

      def handle_cast({:complete, task}, state) do
        case state.todo do
          [next| _] -> schedule(:execute, next)
          [] -> nil
        end

        {:noreply, Map.merge(state, %{executing: state.executing |> List.delete(task), done: [task | state.done]})}
      end

      def handle_cast({:error, task, reason}, state) do
        new_state =
          case state.todo do
            [] -> 
              state
            [next| _] ->
              schedule(:execute, next)
              Map.merge(state, %{executing: state.executing |> List.delete(task), failed: [{task, reason} | state.failed]})
          end
        {:noreply, new_state}
      end

      def handle_cast({:retry, task}, state) do
        Task.start(__MODULE__, :process, [task, self()])
        {:noreply, state}
      end

      def handle_cast({:retry, task, millis}, state) do
        schedule(:retry, task, millis)
        {:noreply, state}
      end

      def process(task, pid) do
        case run(task) do
          :ok -> 
            GenServer.cast(pid, {:complete, task})
          {:ok, info} ->
            GenServer.cast(pid, {:complete, task})
          :retry ->
            GenServer.cast(pid, {:retry, task})
          {:retry, millis} ->
            GenServer.cast(pid, {:retry, task, millis})
          {:error, reason} ->
            GenServer.cast(pid, {:error, task, reason})
        end
      end

      defp schedule(method, task, millis \\ 0) do
        Process.send_after self(), {method, task}, millis
      end
    end
  end
end
