# Sysmon

This project is part of my journey getting started with Elixir. It contains two mix-based projects:

## Sysmon
<img width="1327" height="1109" alt="image" src="https://github.com/user-attachments/assets/41950590-7188-4e15-9dad-53909b42c4e4" />



**sysmon** contains the logic of the monitor. It will spawn a new elixir process per active docker container in the system. This process will send data to a buffer process (`Sysmon.Emit.EventEmitter`) and once the buffer is full, it will publish the gathered metrics and send them the **sysmon_api**. The metrics gathered by **sysmon** at the moment are CPU metrics (more to come).
In order to keep the state in sync, there is a process called `Sysmon.ProcessMonitor` which will keep track of:
- new container started, in that case a new process to monitor it will be spawn
- container no longer existing, in that case the process monitor will terminate the container associated process

Both the process monitor and the container monitor use the `:timer` module in erlang in order to periodically execute its checks.

## Sysmon API

**sysmon_api** contains the API that **sysmon** uses to publish metrics. It's a simple Elixir Phoenix API with basic CRUD capabilities, plus a `"/batch"` endpoint to publish multiple metrics at once. It serves as a layer between the monitor and the DB, but could be further expanded.
