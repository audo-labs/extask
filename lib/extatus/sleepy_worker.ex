defmodule Extatus.SleepyWorker do
  use Extatus.Worker

  require Logger

  def run(task) do
    Logger.debug("Running #{inspect task}")
    :timer.sleep(10000)

    if rem(task, 3) == 0 do
      Enum.random([{:pause, 10000, "multiple of 3!"}, :ok])
    else
      if rem(task, 2) ==  0 do
        {:error, "number is even"}
      else
        :ok
      end
    end
  end
end
