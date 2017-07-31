defmodule Extask do
  use Supervisor

  @name __MODULE__

  def start_link() do
    Supervisor.start_link(@name, [], name: @name)
  end

  def init(_) do
    supervise([], strategy: :one_for_one)
  end

  def start_child(child, itens) do
    Supervisor.start_child(@name, child.child_spec(itens)) 
  end
end
