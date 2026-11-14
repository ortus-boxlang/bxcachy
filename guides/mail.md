---
title: Mail catcher
summary: A local inbox for the mail your apps send while you develop, in one command.
---

# Mail catcher

When you build an app that sends email, you want to see the mail without sending it to anyone. `bxcachy mail` runs a catcher in a container ([Mailpit](https://mailpit.axllent.org)): your app sends to `127.0.0.1:1025` and the mail shows up in an inbox. Nothing leaves your machine.

```bash
bxcachy mail start --yes        # plan first without --yes
bxcachy mail env                # the settings to put in your app
bxcachy mail test               # send one sample message
bxcachy mail list               # what arrived
bxcachy mail show ID            # headers, text body and attachments
bxcachy mail open               # the web inbox in your browser
bxcachy mail clear --yes        # delete every message
bxcachy mail stop
```

The catcher listens on `127.0.0.1` only: SMTP on port 1025 (no TLS, any login is accepted) and the web inbox on port 8025. Change the ports with `--smtp-port=2525` and `--ui-port=9025`.

## Mail is thrown away when it stops

Without `--keep`, stopping the catcher deletes it and its mail. That is what you want while developing: every run starts with an empty inbox. If you want the mail to survive, start it with `bxcachy mail start --keep --yes`; it is then stored in `~/.local/share/bxcachy/mail`. `bxcachy mail remove --yes` deletes the container and any stored mail (`--keep-data` keeps the folder).

## Settings for your app

`bxcachy mail env` prints them for BoxLang and ColdBox apps, Laravel, Spring Boot, Node and plain environment variables. In short: host `127.0.0.1`, port `1025`, no encryption, no username or password.

## In the Control Center

`bxcachy tui` has a Mail page. It lists the messages (newest first), shows the headers and text of the highlighted one, and refreshes itself every few seconds so you can watch mail arrive. `d` deletes a message, `c` clears the inbox, `o` opens it rendered in your browser and `t` sends a test message. Deleting and clearing show a plan first.

## In the wizard and the menu

The setup wizard has a yes or no question for the mail catcher (off by default). The task menu has Develop > Mail catcher.

It needs a container engine: Podman by default, or Docker (`bxcachy db engine docker`).
