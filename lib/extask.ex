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
    spec = 
      Supervisor.child_spec(
        child,
        start: {child, :start_link, [items]},
        id: "#{child}/#{:erlang.phash2(MapSet.new(items))}"
      )

    Supervisor.start_child(@name, spec) 
  end
end
