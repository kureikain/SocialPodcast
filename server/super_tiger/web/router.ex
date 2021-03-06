defmodule SuperTiger.Router do
  use SuperTiger.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SuperTiger do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  scope "/api", SuperTiger do
    pipe_through :api

    resources "/devices", DeviceController, except: [:new, :edit]
    resources "/users", UserController, except: [:new, :edit]
    resources "/categories", CategoryController, except: [:new, :edit]
    resources "/podcasts", PodcastController, except: [:new, :edit] do
      resources "/eposides", EpisodeController
    end
    resources "/fail_refreshes", FailedRefreshController, except: [:new, :edit]
  end

  use ExAdmin.Router
  # your app's routes
  scope "/admin", ExAdmin do
    pipe_through :browser
    admin_routes
  end
end
