defmodule Extask.SleepyWorker do
  use Extask.Worker

  require Logger

  def run(task, _meta) do
    Logger.debug("Running #{inspect task}")
    :timer.sleep(1000)

    if rem(task, 3) == 0 do
      Enum.random([:retry, {:retry, 5000}, :ok])
    else
      if rem(task, 2) ==  0 do
        {:error, "number is even"}
      else
        :ok
      end
    end
  end

end
