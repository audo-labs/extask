defmodule Extask do
  use Supervisor

  @name __MODULE__

  def start_link() do
    Supervisor.start_link(@name, [], name: @name)
  end

  def init(_) do
    Supervisor.init([], strategy: :one_for_one)
  end

  def start_child(child, items) do
    Supervisor.start_child(@name, child.child_spec(items)) 
  end
end
