
# Diligent - A Project Workspace Management Tool for AwesomeWM

## Role Prompt

You are an experienced software developer with a deep understanding of AwesomeWM, Lua, and project management. You are tasked with designing a tool called "Diligent" that helps manage project workspaces in AwesomeWM using a simple Lua DSL (Domain Specific Language).
Your characteristics are that you are a excited and enthusiastic software developer who loves to create tools that improve productivity and workflow.
You are also detail-oriented, ensuring that the tool is robust and user-friendly.
You believe in the unix philosophy of small, composable tools that do one thing well. You are also open to feedback and iterative design, ensuring that the tool meets the needs of its users. It's impotant to you to create an elegant design and efficient implementation that leverages the power of AwesomeWM and Lua. You are aware of the dangers of over-engineering and strive to keep the design simple and focused on the core requirements.

## First Idea

I'm using awesomewm on a arch Linux installation.

I'm a software developer working on a lot of different projects. 

I want a tool that lets me write a file for each project im a simple lua dsl that defines the applications.and files I want to open for the project and which (awesomewm) tags they should be spawned on.

Lets call the tool "diligent". This keeps with the theme of using adjectives for awesomewm project.

It could define that I want the editor Zed with the project directory on tag 1, a terminal with the README.md in nvim and a terminal with the project directory im bash on tag 2, the folder for the project should be opened in a new tab in the already open obsidian, there should be a browser with the jira page of the project and the output of the dev server on tag 3.


There should be a command available on the system that finds the lua file, executes it and uses awesome APIs or awesome-client to set up the workspace as described in the DSL.

The command should be called 'workon'. This makes it possible to type 'workon myproject'  to start working on myproject.

Another command should be available to tear down the workspace and close all clients that where opened.

When a project is started an additional tag is created with the project name and all clients of that project get assigned to this tag in addition to the ones described by DSL. This makes it easy to see which projects are running, see all clients of a project togehter and perform actions on them.

Since this assignement might get lost during work, diligent should probably track the open clients in a more persistent way as well. It should also notice when a client gets closed. This would make it possible to recreate closed clients without having duplicates.

A future feature would be to have different layouts for a project for example for an office setup, a simpler home-office or a very simple laptop layout.

This means the DSL should probably separate resource (cllient) definition and layout definition.

Think about this idea and how it could be implemented. Use your deep knowledge of awesomewm, lua, and project management. Ask questions if you need more information and i will provide documentation or examples. Ask questions to clarity the idea and the requirements.

First we will clarify the high level idea and requirements. Then we will talk about the architecture of the tool and how it could be implemented. Finally we will talk about the DSL and how it could look like. We will do it step by step and iterate on the design. 

So let's start with the high level idea and requirements. What are your thoughts, ideas, and questions about the Diligent tool and its requirements? 




## Clarification Questions

[idea-clarifications.md](idea-clarifications.md)


My comments to the early ideas:

CLI (workon, workoff)
Writing the cli in LUA or a very simple bash wrapper script around the lua implementation probably makes sense.

We can try to use awesome-client to send commands to AwesomeWM but in my experience it was a little tricky to get
error messages back from awesome-client. Lets keep an eye on it and be open to reusing the awesome-client code in the CLI if it makes sense.

It should probalby be one command with subcommands like workon start myproject and workon stop myproject.

DSL

I think its probalby a good idea to separate the DSL into two parts from the start: one for defining resources (clients) and one for defining layouts. This would allow for more flexibility and reusability of the resources across different layouts.

Optional daemon

If a deamon is required to keep track of the clients and their state so be it. Can awesome/lua listen to signals in the background?


When opening multiple projects at the same time at some point tag indices will collide.
I think we should consider numeric tags as 'relative' to the tag that is active when the project is started.
So a user could start project A on tag 1, which will for example use tags 1-3 for its resources, and then start project B on tag 4, which will use tags 4 and 5.
This way the user has the oportunity to start multiple projects and avoid tag collisions.
The DSL could accept string tags like "editor", "logs" or even "3" and treat these as 'absolute' tags, meaning they will always use the same tag index regardless of the active tag when the project is started and regardless of other projects.

In the beginning Diligent should just use the current screen for everything. So the project tag will be created on the current screen and all resources will be placed on the current screen.
Managing multiple screens and placing resources on different screens could be a future feature.


Wrapping the tags around to 1 again is probably confusing for the user. I think in that case tag 9 should be used as a catch-all. Most likely the user will use workon stop and then start again on a smaller tag. Maybe we popup an info.

We should cleary use exising lua libraries as much as we can. A good way would probably be to set up luarocks and use luarocks to install the libraries we need. Would that be possible?

Before we start with the actual implementation i think we should generate some documents that describe our project, a design document for the architecture and the requirements we have now agreed on. This will help us to keep track of the design decisions and the requirements we have for Diligent.





