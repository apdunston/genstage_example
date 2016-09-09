# # Upcase the string you start with, and then show a secret that only D knows.

defmodule Example4 do
  @moduledoc """
  This is example 3 again, but with an extra GenServer thrown in to hold the
  subscription pid and ref. This is too complicated and for no reason other than
  experimenting.
  """

  use Experimental.GenStage
  alias Experimental.GenStage
  
  def go do
    IO.puts "\n\nYou should run this as\n\n{producer, consumer, glue} = Example4.go"
    IO.puts "\nThen you can run\n\nExample4.ask(consumer)\n\nto do a manual request up the GenStage chain\n\n"
    {:ok, glue} = Glue.start_link

    {:ok, producer} = GenStage.start_link(G, :ok)   
    {:ok, consumer} = GenStage.start_link(H, glue) 

    GenStage.sync_subscribe(consumer, to: producer, max_demand: 100, min_demand: 1)
    {producer, consumer, glue}
  end

  def pop(consumer), do: GenStage.call(consumer, :ask)

end

defmodule Glue do
  @moduledoc "Holds a pid and reference tuple with set and get calls."
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def handle_call({:set, pid_ref}, _from, state) do
    {:reply, pid_ref, pid_ref}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

end





defmodule G do
  use Experimental.GenStage
  alias Experimental.GenStage

  def init(_) do
    {:producer, 1}
  end

  def handle_demand(demand, 1) when demand > 0 do
    IO.puts "state 1, demand is #{demand}"
    {:noreply, List.duplicate("alpha", demand), 2}
  end

  def handle_demand(demand, 2) when demand > 0 do
    IO.puts "state 2, demand is #{demand}"
    {:noreply, ["bravo"], 3}
  end
  def handle_demand(demand, 3) when demand > 0 do
    IO.puts "state 3, demand is #{demand}"
    {:noreply, [], 4}
  end
  def handle_demand(demand, 4) when demand > 0 do
    IO.puts "state 4, demand is #{demand}"
    {:noreply, ["You win! You've seen all the states. I'm looping back around"], 1}
  end
end







defmodule H do
  use Experimental.GenStage
  alias Experimental.GenStage
  use GenServer

  def init(glue) do
    {:consumer, glue}
  end

  def handle_events(events, from, glue) do
    # Wait for a second.
    :timer.sleep(50)

    IO.puts(events)
    
    # We are a consumer, so we would never emit items.
    {:noreply, [], glue}
  end

  def handle_cancel(reason, from, glue) do
    IO.puts "I was cancelled. Stuff below"
    IO.inspect {reason, from, glue}
  end

  def handle_subscribe(:consumer, opts, from, glue) do
    GenServer.call(glue, {:set, from})
    {:manual, glue}
  end

  def handle_subscribe(:producer, opts, from, glue) do
    GenServer.call(glue, {:set, from})
    {:manual, glue}
  end

  def handle_call(:ask, from, glue) do
    answer = glue
    |> GenServer.call(:get)
    |> GenStage.ask(1)
    GenStage.reply(from, answer)
    {:noreply, [], glue}  
  end

end



