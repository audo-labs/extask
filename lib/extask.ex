defmodule Extask do
  use Application

  def start(_type, _args) do
    Extask.Supervisor.start_link()
  end

  def start_child(child, items, meta \\ []) do
    Extask.Supervisor.start_child(child, items, meta)
  end

  def child_status(pid_or_id) when is_pid(pid_or_id) do
    Extask.Worker.status(pid_or_id)
  end

  def child_status(pid_or_id) when is_binary(pid_or_id) do
    case Extask.Supervisor.find_child(pid_or_id) do
      nil -> nil
      pid -> Extask.Worker.status(pid)
    end
  end

  def child_id(child, items, meta) do
    "#{child}/#{:erlang.phash2(%{items: MapSet.new(items), meta: meta})}"
  end

end
