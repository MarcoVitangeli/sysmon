defmodule SysmonApiWeb.Router do
  use SysmonApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", SysmonApiWeb do
    pipe_through :api

    resources "/metrics", MetricController, only: [:index, :show, :create]
    post "/metrics/batch", MetricController, :create_batch
  end
end
