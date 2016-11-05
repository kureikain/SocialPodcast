defmodule SuperTiger.Crawler.Itunes.Episode do
  use Mix.Task
  import Ecto.Query

  defmodule ItunePodcast do
    @derive [Poison.Encoder]
    defstruct [:resultCount, :results]
  end

  def prepare do
    HTTPoison.start
  end

  # Crawl podcast
  def get_feed(repo) do
    prepare

    Mix.shell.info "Start crawl podcast's feed"

    total = SuperTiger.Repo.one(from p in SuperTiger.Podcast, where: is_nil(p.feed_uri), select: count("*"))
    doc_per_batch = round(Float.ceil(total / 60))
    IO.puts "Found #{total} podcast. Will run 60 batch. Doc per batch: #{doc_per_batch}"
    for batch <- 1..60, do: get_feed_batch(repo, batch, doc_per_batch)
  end

  def get_feed_batch(repo, batch, doc_per_batch) do
    #repo.all(from p in SuperTiger.Podcast,
    #          where: is_nil(p.feed_uri),
    #          select: p)
    IO.puts "Get batch #{batch}"
    query =
      SuperTiger.Podcast
      |> where([p], is_nil(p.feed_uri))
      |> order_by(:id)
      |> limit(^doc_per_batch)
      |> offset(^(doc_per_batch * batch))
    repo.all(query)
      |> Enum.each(fn(podcast) -> process_podcast_feed(repo, podcast) end)
  end

  def get_url(url, attempt \\ 1) do
    case HTTPoison.get url do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}
      error ->
        if attempt == 3 do
          {:error, "Fail to get url. Ignore #{attempt}"}
        else
          IO.puts "Fail to get url. Retry: Attempt #{attempt+1}"
          get_url(url, attempt + 1)
        end
    end
  end

  # Download podcast for category
  def process_podcast_feed(repo, podcast) do
    case String.split(podcast.url, "/id") do
      [_, itune_id] ->
        IO.puts "Start finding feedurl for #{itune_id}"

        case get_url("https://itunes.apple.com/lookup?id=#{itune_id}") do
          {:error, m} ->
            IO.inspect m
          {:ok, itune_data} ->
            itune_podcast = Poison.Parser.parse!(itune_data)
            feed_url = List.first(itune_podcast["results"])["feedUrl"]
            IO.puts feed_url
            spawn(__MODULE__, :update_podcast, [podcast, feed_url])
        end
      _ ->
        IO.puts "Invalid #{podcast.url}"
    end
  end

  # Update feedurl for a given podcast
  def update_podcast(podcast, feed_url) do
    changeset = SuperTiger.Podcast.changeset(podcast, %{"feed_uri" => feed_url})
    case SuperTiger.Repo.update(changeset) do
      {:ok, p} ->
        IO.puts "Update feed_uri for #{podcast.id}. URL= #{feed_url}"
      {:error, p } ->
        IO.puts "Error"
    end
  end
end
