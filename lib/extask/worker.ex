defmodule Extask.Worker do
  use GenServer

  def status(pid) do
    GenServer.call(pid, :status)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  @callback before_run(state :: map) ::
  :ok | {:ok, {:tasks, tasks :: term, meta :: term}} | {:error, reason :: term}

  @callback run(task:: term, meta :: term) ::
  :ok | {:ok, data :: term} |
  :retry |
  {:retry, millis :: integer} |
  {:error, reason :: term}

  @callback after_run(state:: map) ::
  :ok | :error | {:error, reason :: term}

  @callback handle_status(status :: term, state :: term) :: {:noreply, state :: term}

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Extask.Worker
      use GenServer

      @retry_timeout Application.get_env(:extask, Extask) |> Keyword.get(:retry_timeout) || 30000

      #
      # Server API
      #
      def start_link(tasks, meta \\ []) do
        GenServer.start_link(__MODULE__, [tasks: tasks, meta: meta])
      end

      def init([tasks: tasks, meta: meta]) do
        state = %{
          todo: tasks,
          failed: [],
          executing: [],
          done: [],
          total: Enum.count(tasks),
          meta: meta |> Keyword.put(:worker_pid, self())
        }

        schedule(:execute, {:call, :before_run, :run})

        {:ok, state}
      end

      def before_run(state) do
        :ok
      end

      def after_run(state) do
        :ok
      end

      def handle_status(m, state) do
        {:noreply, state}
      end


      def handle_call(:status, _from, state = %{todo: _, failed: _, executing: _, done: done, total: total}) do
        {:reply, state, state}
      end

      # TODO: this task tuple can conflict with tasks of overriding modules
      def handle_cast({:execute, {:call, _, _} = task}, state) do
        Task.start(__MODULE__, :process, [task, state, self()])
        {:noreply, state}
      end

      def handle_cast({:execute, task}, state) do
        todo = List.delete(state.todo, task)
        executing = [task | state.executing]

        # TODO: check task fail
        Task.start(__MODULE__, :process, [task, state, self()])

        {:noreply, Map.merge(state, %{todo: todo, executing: executing})}
      end

      def handle_info({:update_state, update_map, retry_call}, state) do
        new_state =
          Map.merge(state, %{
            todo: state.todo ++ update_map.todo,
            total: length(state.todo) + length(update_map.todo),
            meta: update_map.meta
          })
        [task|_] = update_map.todo
        GenServer.cast(self(), {:execute, task})
        {:noreply, new_state}
      end

      def handle_info({:execute, task}, state) do
        GenServer.cast(self(), {:execute, task})
        {:noreply, state}
      end

      def handle_info({:retry, task}, state) do
        GenServer.cast(self(), {:retry, task})
        {:noreply, state}
      end

      def handle_info(:run, %{todo: []} = state) do
        GenServer.cast(self(), {:execute, {:call, :after_run, :complete}})
        {:noreply, state}
      end

      def handle_info(:run, state) do
        %{todo: [task| _]} = state
        GenServer.cast(self(), {:execute, task})
        {:noreply, state}
      end

      def handle_info(:after, state) do
        GenServer.cast(self(), {:execute, {:call, :after_run, :complete}})
        {:noreply, state}
      end

      def handle_info(:complete, state) do
        handle_status(:job_complete, state)
        {:noreply, state}
      end

      def handle_info({:status, msg}, state) do
        if length(state.todo ++ state.executing) == 0 do
          schedule(:execute, {:call, :after_run, :complete})
        end

        handle_status(msg, state)
      end

      def handle_cast({:complete, {task, info}}, state) do
        case state.todo do
          [next| _] -> schedule(:execute, next)
          [] -> send self(), :complete
        end

        send self(), {:status, {:task_complete, task}}

        {:noreply, Map.merge(state, %{executing: state.executing |> List.delete(task),
                                      done: [{task, info} | state.done]})}
      end

      def handle_cast({:error, task, reason}, state) do
        if length(state.todo) > 0 do
          schedule(:execute, hd(state.todo))
        end

        send self(), {:status, {:task_failed, task, reason}}

        {:noreply, Map.merge(state, %{executing: state.executing |> List.delete(task), failed: [{task, reason} | state.failed]})}
      end

      def handle_cast({:retry, task}, state) do
        Task.start(__MODULE__, :process, [task, state, self()])
        send self(), {:status, {:task_started, task}}
        {:noreply, state}
      end

      def handle_cast({:retry, task, millis}, state) do
        schedule(:retry, task, millis)
        {:noreply, state}
      end

      def process({:call, function, next_stage}, state, pid) do
        try do
          case apply(__MODULE__, function, [state]) do
            :error -> Process.send_after pid, {:execute, {:call, function, next_stage}}, @retry_timeout
            {:error, _} -> Process.send_after pid, {:execute, {:call, function, next_stage}}, @retry_timeout
            {:ok, {:done, [], meta}} -> send pid, next_stage
            {:ok, {:tasks, [], meta}} -> GenServer.cast(pid, {:execute, {:call, :after_run, :complete}})
            {:ok, {:tasks, tasks, meta}} -> send pid, {:update_state, %{todo: tasks, meta: meta}, {:call, function, next_stage}}
          end
        rescue
          e -> Process.send_after pid, {:execute, {:call, function, next_stage}}, @retry_timeout
        end
      end

      def process(task, state, pid) do
        try do
          case run(task, state.meta) do
            {:ok, info} ->
              GenServer.cast(pid, {:complete, {task, info}})
            :retry ->
              GenServer.cast(pid, {:retry, task})
            {:retry, millis} ->
              GenServer.cast(pid, {:retry, task, millis})
            {:error, reason} ->
              GenServer.cast(pid, {:error, task, reason})
          end
        rescue
          e ->
            GenServer.cast(pid, {:error, task, e})
        end
      end

      defp schedule(method, task, millis \\ 0) do
        Process.send_after self(), {method, task}, millis
      end

      defoverridable Extask.Worker

    end
  end
end
