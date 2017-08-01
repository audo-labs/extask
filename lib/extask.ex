defmodule Extask do
  use Application

  def start(_type, _args) do
    Extask.Supervisor.start_link()
  end

  def start_child(child, items) do
    Extask.Supervisor.start_child(child, items)
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

  def child_id(child, items) do
    "#{child}/#{:erlang.phash2(MapSet.new(items))}"
  end

end
