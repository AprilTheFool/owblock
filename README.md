# owblock

A simple terminal-based server selector for Overwatch on Linux, uses firewall rules to block servers you don't want to play on.

Concept and ip ranges yoinked from this project: [stowmyy/dropship](https://github.com/stowmyy/dropship).

## Requirements

- Linux with nftables 0.9 or newer (`nft`)
- Python 3.6 or newer (standard library only)
- `sudo` or `doas`, or run it as root
- `ping`

It doesn't matter which firewall you already use. `owblock` keeps its rules in
its own table, so it works alongside ufw, firewalld, or no firewall at all.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/AprilTheFool/owblock/main/install.sh | sh
```

To update, just run the installer again.

### Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/AprilTheFool/owblock/main/install.sh | sh -s -- --uninstall
```

## Usage

```sh
owblock list                 # servers, your ping to each, and what's blocked
owblock allow syd2           # block every server except syd2
owblock allow ord1 las1      # block everything except these two
owblock block gsg1 gtk1      # block only these
owblock status               # show what's currently blocked
owblock off                  # remove all blocks
owblock update               # re-download the server list
```

Make sure Overwatch is closed while using commands.

Rules will reset when the system reboots, run the command again to re-add them.

Don't use the practice range to test if the blocks worked!!!
The practice range is weird and doesnt use the same servers afaik, instead either play a qp match or create a custom game.

## How it works

`owblock` creates one nftables table, `inet owblock`, that drops **outbound
UDP to ports 1024–65535** for the blocked servers' IP ranges. The game uses
UDP for its traffic, so it can't reach those servers. Websites hosted in the
same cloud regions keep working, because they use TCP and aren't affected.

Every change replaces the whole table, and the rules are never saved to disk.
A reboot or `owblock off` removes them completely. You can inspect them at any
time:

```sh
sudo nft list table inet owblock
```

The server list is cached at `~/.cache/owblock/ips.json`, so `owblock` still
works if the download fails.

## Credits

- Server IP ranges come from [stowmyy/dropship](https://github.com/stowmyy/dropship).
- This project is not affiliated with or endorsed by Blizzard Entertainment.
  Overwatch is a trademark of Blizzard Entertainment, Inc.

## License

[MIT](LICENSE)
