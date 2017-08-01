defmodule Extask.Supervisor do
  use Supervisor

  @name __MODULE__

  def start_link() do
    Supervisor.start_link(@name, [], name: @name)
  end

  def init(_) do
    Supervisor.init([], strategy: :one_for_one)
  end

  def find_child(id) do
    case Supervisor.which_children(@name) |> List.keyfind(id, 0) do
      nil -> nil
      {^id, pid, _, _} -> pid
    end
  end

  def start_child(child, items) do
    spec = 
      Supervisor.child_spec(
        child,
        start: {child, :start_link, [items]},
        id: Extask.child_id(child, items)
      )

    Supervisor.start_child(@name, spec) 
  end
end
