defmodule Mix.Tasks.ResetSoirees do
  use Mix.Task

  @shortdoc "Resets soirees by removing all existing entries and generating new ones"
  
  def run(_) do
    # Ensure all dependencies are started
    [:postgrex, :ecto, :ash] |> Enum.each(&Application.ensure_all_started/1)
    # Start the repo
    Huddlz.Repo.start_link()
    
    # Get all soirees
    {:ok, all_soirees} = Ash.read(Huddlz.Soirees.Soiree)
    IO.puts("Found #{length(all_soirees)} existing soirées")
    
    # Delete each soiree
    Enum.each(all_soirees, fn soiree ->
      case Ash.destroy(soiree) do
        :ok -> IO.puts("Deleted soirée: #{soiree.title}")
        _ -> IO.puts("Failed to delete soirée: #{soiree.title}")
      end
    end)
    
    IO.puts("All soirées deleted. Running seed file to create new ones...")
    
    # Run the seeds file
    Code.eval_file("priv/repo/seeds/soirees/sample_soirees.exs")
    
    IO.puts("Soirée reset complete!")
  end
end