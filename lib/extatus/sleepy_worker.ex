defmodule Extatus.SleepyWorker do
  use Extatus.Worker

  require Logger

  def run(task) do
    Logger.debug("Running #{inspect task}")
    :timer.sleep(10000)
    :ok
  end
end
