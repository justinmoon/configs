#!/usr/bin/env python3
import base64
import json
import os
import pty
import select
import struct
import sys
import termios
import fcntl


def send(message):
    sys.stdout.write(json.dumps(message) + "\n")
    sys.stdout.flush()


def set_winsize(fd, rows, cols):
    try:
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    except Exception as exc:  # noqa: BLE001
        send({"type": "error", "error": f"failed to set window size: {exc}"})


def main():
    shell = os.environ.get("PTY_SHELL", "/bin/bash")
    shell_args = json.loads(os.environ.get("PTY_SHELL_ARGS", "[]"))
    cols = int(os.environ.get("PTY_COLS", "80"))
    rows = int(os.environ.get("PTY_ROWS", "24"))
    extra_env = json.loads(os.environ.get("PTY_ENV", "{}"))

    env = os.environ.copy()
    env.update({k: str(v) for k, v in extra_env.items()})
    env.setdefault("TERM", "xterm-256color")

    pid, master_fd = pty.fork()
    if pid == 0:
        try:
            os.execvpe(shell, [shell, *shell_args], env)
        except Exception as exc:  # noqa: BLE001
            send({"type": "exit", "exitCode": 126, "error": str(exc)})
            os._exit(126)  # noqa: SLF001
    else:
        set_winsize(master_fd, rows, cols)
        buffer = ""
        while True:
            read_fds = [master_fd, sys.stdin]
            rlist, _, _ = select.select(read_fds, [], [])

            if master_fd in rlist:
                try:
                    data = os.read(master_fd, 4096)
                except OSError:
                    data = b""

                if not data:
                    break

                send({
                    "type": "data",
                    "data": base64.b64encode(data).decode("ascii"),
                })

            if sys.stdin in rlist:
                line = sys.stdin.readline()
                if not line:
                    break
                line = line.strip()
                if not line:
                    continue
                try:
                    message = json.loads(line)
                except json.JSONDecodeError:
                    continue

                msg_type = message.get("type")
                if msg_type == "write":
                    payload = base64.b64decode(message.get("data", ""))
                    os.write(master_fd, payload)
                elif msg_type == "resize":
                    cols = int(message.get("cols", cols))
                    rows = int(message.get("rows", rows))
                    set_winsize(master_fd, rows, cols)
                elif msg_type == "close":
                    os.close(master_fd)
                    break

        _, status = os.waitpid(pid, 0)
        exit_code = None
        signal = None
        if os.WIFEXITED(status):
            exit_code = os.WEXITSTATUS(status)
        if os.WIFSIGNALED(status):
            signal = os.WTERMSIG(status)
        send({"type": "exit", "exitCode": exit_code, "signal": signal})


if __name__ == "__main__":
    main()
