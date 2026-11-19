# owblock

Terminal-based server selector for Overwatch on Linux, uses firewall rules to block servers you don't want to play on.

Concept and ip ranges yoinked from this awseome project: [stowmyy/dropship](https://github.com/stowmyy/dropship).

<img width="1099" height="728" alt="screenshot" src="https://github.com/user-attachments/assets/d72689fb-b608-4349-bea3-d5aabc5b57f4" />


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

***Make sure Overwatch is closed while using the tool!***

Rules will reset when the system reboots, run the command again to re-add them, or create an autoexec on your system.

Don't use the practice range to test it,
the practice range is weird and doesnt use the same servers afaik, instead either play a qp match or create a custom game.

## Credits

- Server IP ranges come from [stowmyy/dropship](https://github.com/stowmyy/dropship).
- This project is not affiliated with or endorsed by Blizzard Entertainment.
  Overwatch is a trademark of Blizzard Entertainment, Inc.

## License

[MIT](LICENSE)
