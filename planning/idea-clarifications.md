Answers to the clarification questions below will help to refine the design and implementation of Diligent.

Concurrent projects

It should be possible to have multiple projects running at the same time. Each project should have its own tag and clients. I feel this would usually be used when working on one primary project but a quick fix for another project is needed or a idea pops up that needs to be implemented in another project.
This would also come handy when working on multiple projects that are related to each other, like a frontend and backend project.

Spawn vs attach

It should be configurable per resource in the DSL, whether to reuse an existing window or always open a new one.
. For example, I would like to always open a new terminal, but reuse an existing Obsidian window if it matches the project folder.
Or a functionality like "open these 3 urls in a new browser window on tag 3", or "open this file in a new tab in the already open Obsidian window", "open this directory in an exisiting file manager window or open a new one if none exists".


Re-entry after restart

The state of the projects started by Diligent should probably be persistent. This would make it easier to re-enter a project or open missing clients when they got closed. Also changing layouts would need a persistent state to be able to restore the clients. Auto-restart after a crash would also be nice, but not necessary. 

Graceful shutdown (workoff)

Diligent should play very nicely with standard linux workflows, so I would suggest sending SIGTERM or SIGINT to terminals running programs, which allows them to gracefully shut down. For example, if a terminal is running a dev server, it can clean up resources and exit properly.

Any need to run custom “stop” hooks (e.g. docker compose down) before killing?

There should be probably an option for start/stop hooks in the DSL. Possibly simple bash commands/scripts that are executed before the clients are started or stopped. This would allow for custom cleanup or setup tasks, like stopping a dev server or running a database migration.
This could come in a future version, but it would be nice to have it in mind for the DSL design.


Dev-server output
Running services or starting servers is not the core functionality of Diligent, more specialized tools like systemd, docker-compose, or Procfiles should be used for that. They could be used in the start/stop hooks to start or stop services. Diligent should focus on managing the workspace and clients, not on running services.

Dynamic vs static tag indices

This is still a bit open for discussion. In the first version of Diligent using the standard AwesomeWM numeric tags should be fine. Those are reachable by keyboard shortcuts and are easy to use. However, I can see the need for more flexibility in the future. The DSL could allow for named tags and possibly rename existing tags at runtime. The tags should always be in the 1-9 scope that are usually mapped by to keyboard shortcuts in AwesomeWM. 


Layouts (future feature)
For the office/laptop variants: is it enough to switch which tags get used, or do you envision tiling-geometry rules (master/stack, column counts, gaps) living in Diligent too?

The layout variants should in their simplest form be a mapping of diligent resources to tags. For example, the office layout could use tags 1 for the editor and 2 terminal, and browser, and 3 for logs, while the laptop layout could use tags 1-2 for the editor and terminal.
Since Diligent and Awesome are both Lua-based, it feel should be possible to optionally pass rules through the DSL to awesome/awful

Client tracking mechanism
I’m leaning toward setting an X11 property (e.g. _DILIGENT_PROJECT="myproject") on each new client. That survives restarts and lets Awesome rule-matching pick them up. Sound good?
I'm not an expert on X11 but AwesomeWM is based on it, so setting an X11 property sounds like a good idea if that is realiable and works well with AwesomeWM's rules system. 
. Could you elaborate on how this would work in practice? Would it be possible to use this property to find and reattach to existing clients when starting a project?

Search path for project files
– ~/.config/diligent/projects/<name>.lua only?
– Or also relative paths so cd project && workon . works?

In the start i think it should be enough to have a single search path for project files, like `~/.config/diligent/projects/<name>.lua`. This keeps it simple and easy to find the project files. Later on, we could add support for relative paths, this would allow to have the project file in the project directory itself, making it easier to manage projects in version control systems like git. 

Error handling / interactivity
I think it would be best to continue launching the other resources when resources/clients fail to start and report a summary at the end. This way, the user can still work on the project even if one resource fails to start. The summary should include the errors encountered and possibly suggestions for how to fix them. This would make Diligent more robust and user-friendly, allowing users to quickly get back to work without having to manually start each resource.
