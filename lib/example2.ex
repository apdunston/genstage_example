# Upcase the string you start with, and then show a secret that only D knows.

defmodule Example2 do
  @moduledoc """
  Very similar to example 1. Here we add the ability to call the producer 
  outside the normal flow. 

  GenStage doesn't preclude GenServer-style calls, but there are some hitches.
  Note the use of `GenStage.reply(from, my_private_secret)`

  When you run this, note how the producer sends out :done and you get the
  "Breathe in. Breathe out." message output to the screen one or more times.
  That's because the cast from consumer to midstep and midstep to producer is
  happening while the regular GenStage flow is going. Producer module D is 
  happily handing out [:done] until it's flipped to [:stop]
  """
  use Experimental.GenStage
  alias Experimental.GenStage
  
  def go(input \\ "What is the secret of life?") do
    {:ok, producer} = GenStage.start_link(D, input)   
    {:ok, midstep} = GenStage.start_link(E, :ok)   # upcase
    {:ok, consumer} = GenStage.start_link(F, :ok) # state does not matter

    GenStage.sync_subscribe(consumer, to: midstep, max_demand: 1)
    GenStage.sync_subscribe(midstep, to: producer, max_demand: 1)
  end

end


defmodule D do
  use Experimental.GenStage
  alias Experimental.GenStage

  def init(string) do
    {:producer, string}
  end

  def handle_demand(demand, [:done]) when demand ==1 do
    {:noreply, [:done], [:done]}
  end

  @doc """
  Note that it doesn't matter what we set state to here. Returning fewer events
  than the demand stops the subscription. If midstep subscribed again, it would
  get the "Wait isn't there more?" string we're putting into state here.
  """
  def handle_demand(demand, [:stop]) when demand == 1 do
    IO.puts "Producer handling demand, but I'm at [:stop], so I'm giving []."
    {:noreply, [], ["Wait isn't there more?"]}
  end

  def handle_demand(demand, string) when demand == 1 and is_bitstring(string) do
    [events, string] = split_string(string, demand)
    string = string_or_done(string)
    {:noreply, events, string}
  end

  def handle_call(:give_me_the_secret, from, state) do
    GenStage.reply(from, my_private_secret)
    {:noreply, [], state}
  end

  def handle_cast(:stop, state) do
    IO.puts "Producer received stop. Setting state to [:stop]"
    {:noreply, [], [:stop]}
  end

  defp string_or_done(""), do: [:done]
  defp string_or_done(string), do: string

  defp split_string(string, position),
    do: [
      front(string, position), 
      back(string, position)
    ]

  defp front(string, position),
    do: string |> String.slice(0, position) |> String.to_charlist

  defp back(string, position),
    do: String.slice(string, position, String.length(string)) 

  defp my_private_secret, do: "Breathe in. Breathe out."
end







defmodule E do
  use Experimental.GenStage
  alias Experimental.GenStage

  def init(:ok) do
    {:producer_consumer, :ok}
  end
  
  def handle_events([:done], from, state) do 
    {:noreply, [:done], from}
  end
  
  def handle_events(events, from, state) do
    # IO.puts "E state: #{inspect state}"
    string = to_string(events)
    additional_uppercase = ~r/[A-Z]/ |> Regex.scan(string) |> length
    events = string |> String.upcase |> String.to_charlist
    {:noreply, events, from}
  end

  def handle_call(:give_me_the_secret, from, state) do
    {pid, reference} = state
    GenStage.reply(from, GenStage.call(pid, :give_me_the_secret))
    {:noreply, [], state}
  end

  def handle_cast(:stop_producer, state) do
    {pid, reference} = state
    GenStage.cast(pid, :stop)
    # GenStage.reply(:ok)
    {:noreply, [], state}
  end

end




defmodule F do
  use Experimental.GenStage
  alias Experimental.GenStage

  def init(:ok) do
    {:consumer, :ok}
  end

  def handle_events([:done], from, state) do
    {pid, reference} = from
    IO.puts "I GOT DONE! :) Time to get that secret..."
    IO.puts(GenStage.call(pid, :give_me_the_secret))
    GenStage.cast(pid, :stop_producer)
    {:noreply, [], state}
  end

  def handle_events(events, from, state) do
    # Wait for a second.
    :timer.sleep(50)

    IO.write(events)
    
    # We are a consumer, so we would never emit items.
    {:noreply, [], state}
  end

end



