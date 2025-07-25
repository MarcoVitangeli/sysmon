defmodule SysmonApi.Repo do
  use Ecto.Repo,
    otp_app: :sysmon_api,
    adapter: Ecto.Adapters.Postgres
end
