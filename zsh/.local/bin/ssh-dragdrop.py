#!/usr/bin/env python3
"""Make local file and folder drops usable in an interactive SSH session.

The program is a tiny PTY proxy.  Normal terminal input/output passes through
unchanged.  When Ghostty pastes one or more existing absolute local paths, the
items are copied over a separate SSH connection and the remote paths are sent
to the interactive session instead.
"""

from __future__ import annotations

import argparse
import errno
import fcntl
import os
import posixpath
import pty
import queue
import re
import select
import shlex
import signal
import subprocess
import sys
import termios
import tempfile
import threading
import time
import tty
import unicodedata
import urllib.parse
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, List, Optional, Sequence, Tuple


BRACKETED_PASTE_START = b"\x1b[200~"
BRACKETED_PASTE_END = b"\x1b[201~"
MAX_PASTE_BYTES = 1024 * 1024
UPLOAD_TIMEOUT_SECONDS = 2 * 60 * 60
TRANSFER_CHUNK_BYTES = 256 * 1024
PROGRESS_REPORT_INTERVAL = 0.25

# A full-screen remote application cannot clean up terminal modes when its SSH
# connection disappears abruptly. Ghostty may then report mouse movement as
# text at the local shell prompt. Restore the modes a full-screen terminal app
# normally resets during an orderly exit.
TERMINAL_DISPLAY_RESET = (
    b"\x1b[?1000;1002;1003;1004;1006;1015;1016l"
    b"\x1b[?2004l"
    b"\x1b[?2026l"
    b"\x1b[?1049l"
    b"\x1b[?1l\x1b>"
    b"\x1b[?25h\x1b[0m"
)


@dataclass
class UploadResult:
    remote_paths: Optional[List[str]]
    error: str = ""


@dataclass(frozen=True)
class ProgressUpdate:
    phase: str
    item_index: int
    item_count: int
    bytes_done: int = 0
    bytes_total: int = 0


ProgressCallback = Optional[Callable[[ProgressUpdate], None]]


def _report_progress(
    callback: ProgressCallback,
    phase: str,
    item_index: int,
    item_count: int,
    bytes_done: int = 0,
    bytes_total: int = 0,
) -> None:
    if callback is None:
        return
    callback(
        ProgressUpdate(
            phase,
            item_index,
            item_count,
            bytes_done,
            bytes_total,
        )
    )


def _decode_drop_path(word: str) -> Optional[str]:
    """Return a local absolute path from Ghostty's pasted representation."""
    if word.startswith("file://"):
        parsed = urllib.parse.urlparse(word)
        if parsed.netloc not in ("", "localhost"):
            return None
        word = urllib.parse.unquote(parsed.path)
    else:
        word = os.path.expanduser(word)

    if not os.path.isabs(word):
        return None
    return os.path.realpath(word)


def local_items_from_paste(payload: bytes) -> Optional[List[str]]:
    """Recognize a paste containing only existing local files or folders."""
    try:
        text = payload.decode("utf-8").strip()
    except UnicodeDecodeError:
        return None

    if not text or "\n" in text or "\r" in text:
        return None

    try:
        words = shlex.split(text, posix=True)
    except ValueError:
        return None

    if not words or len(words) > 30:
        return None

    items: List[str] = []
    for word in words:
        path = _decode_drop_path(word)
        if (
            path is None
            or path == os.path.abspath(os.sep)
            or not (os.path.isfile(path) or os.path.isdir(path))
        ):
            return None
        items.append(path)
    return items


def _safe_remote_name(local_path: str) -> str:
    path = Path(local_path)
    stem = unicodedata.normalize("NFKD", path.stem).encode("ascii", "ignore").decode()
    stem = re.sub(r"[^A-Za-z0-9_-]+", "-", stem).strip("-_")[:48] or "file"
    suffix = re.sub(r"[^A-Za-z0-9.]", "", path.suffix.lower())[:16]
    stamp = time.strftime("%Y%m%d-%H%M%S")
    return f"{stamp}-{stem}-{uuid.uuid4().hex[:8]}{suffix}"


def _ssh_upload_command(
    host: str,
    remote_command: str,
    ssh_bin: str,
    control_path: Optional[str],
) -> List[str]:
    command = [ssh_bin]
    if control_path:
        command.extend(
            [
                "-o",
                "ControlMaster=auto",
                "-o",
                f"ControlPath={control_path}",
                "-o",
                "ControlPersist=no",
            ]
        )
    command.extend(
        [
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=10",
            "--",
            host,
            remote_command,
        ]
    )
    return command


def _stream_file_to_ssh(
    source_path: str,
    ssh_command: Sequence[str],
    progress_callback: ProgressCallback,
    item_index: int,
    item_count: int,
    finishing_phase: str,
) -> str:
    """Send one local file to SSH while reporting byte-level progress."""
    total_bytes = os.path.getsize(source_path)
    bytes_done = 0
    process: Optional[subprocess.Popen[bytes]] = None
    write_error = ""
    deadline = time.monotonic() + UPLOAD_TIMEOUT_SECONDS

    _report_progress(
        progress_callback,
        "uploading",
        item_index,
        item_count,
        0,
        total_bytes,
    )

    try:
        with tempfile.TemporaryFile() as ssh_errors, open(source_path, "rb") as source:
            process = subprocess.Popen(
                list(ssh_command),
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=ssh_errors,
            )
            if process.stdin is None:
                raise OSError("could not open the upload stream")

            last_report = time.monotonic()
            try:
                while True:
                    chunk = source.read(TRANSFER_CHUNK_BYTES)
                    if not chunk:
                        break
                    process.stdin.write(chunk)
                    bytes_done += len(chunk)
                    now = time.monotonic()
                    if (
                        now - last_report >= PROGRESS_REPORT_INTERVAL
                        or bytes_done == total_bytes
                    ):
                        _report_progress(
                            progress_callback,
                            "uploading",
                            item_index,
                            item_count,
                            bytes_done,
                            total_bytes,
                        )
                        last_report = now
            except (BrokenPipeError, OSError) as exc:
                write_error = str(exc)
            finally:
                try:
                    process.stdin.close()
                except OSError:
                    pass

            _report_progress(
                progress_callback,
                finishing_phase,
                item_index,
                item_count,
                bytes_done,
                total_bytes,
            )
            remaining = max(0.1, deadline - time.monotonic())
            try:
                return_code = process.wait(timeout=remaining)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                return "upload timed out"

            ssh_errors.seek(0)
            ssh_detail = ssh_errors.read().decode("utf-8", "replace").strip()
    except OSError as exc:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait()
        return str(exc)

    if return_code != 0:
        return ssh_detail or f"ssh exited with status {return_code}"
    if write_error:
        return write_error
    return ""


def _create_directory_archive(
    local_path: str,
    archive_path: str,
    progress_callback: ProgressCallback,
    item_index: int,
    item_count: int,
) -> str:
    """Create a temporary gzip archive on the MacBook."""
    archived_name = os.path.basename(local_path)
    tar_command = [
        "tar",
        "-czf",
        archive_path,
        "-C",
        os.path.dirname(local_path),
        "--",
        archived_name,
    ]
    process: Optional[subprocess.Popen[bytes]] = None
    deadline = time.monotonic() + UPLOAD_TIMEOUT_SECONDS
    _report_progress(progress_callback, "preparing", item_index, item_count)

    try:
        with tempfile.TemporaryFile() as tar_errors:
            process = subprocess.Popen(
                tar_command,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=tar_errors,
            )
            while process.poll() is None:
                if time.monotonic() >= deadline:
                    process.kill()
                    process.wait()
                    return "creating the folder archive timed out"
                _report_progress(
                    progress_callback,
                    "preparing",
                    item_index,
                    item_count,
                )
                time.sleep(0.5)

            tar_errors.seek(0)
            tar_detail = tar_errors.read().decode("utf-8", "replace").strip()
    except OSError as exc:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait()
        return str(exc)

    if process.returncode != 0:
        return tar_detail or f"tar exited with status {process.returncode}"
    return ""


def _upload_file(
    local_path: str,
    host: str,
    remote_dir: str,
    ssh_bin: str,
    control_path: Optional[str],
    progress_callback: ProgressCallback,
    item_index: int,
    item_count: int,
) -> Tuple[Optional[str], str]:
    remote_path = posixpath.join(remote_dir, _safe_remote_name(local_path))
    temporary_path = f"{remote_path}.part-{uuid.uuid4().hex[:8]}"

    q_dir = shlex.quote(remote_dir)
    q_tmp = shlex.quote(temporary_path)
    q_final = shlex.quote(remote_path)
    cleanup_command = shlex.quote(f"rm -f -- {q_tmp}")
    remote_command = (
        "umask 077; "
        f"mkdir -p -- {q_dir} && "
        f"trap {cleanup_command} EXIT HUP INT TERM; "
        f"cat > {q_tmp} && mv -- {q_tmp} {q_final}; "
        "result=$?; trap - EXIT HUP INT TERM; exit $result"
    )
    ssh_command = _ssh_upload_command(host, remote_command, ssh_bin, control_path)
    error = _stream_file_to_ssh(
        local_path,
        ssh_command,
        progress_callback,
        item_index,
        item_count,
        "finishing",
    )
    if error:
        return None, error
    return remote_path, ""


def _upload_directory(
    local_path: str,
    host: str,
    remote_dir: str,
    ssh_bin: str,
    control_path: Optional[str],
    progress_callback: ProgressCallback,
    item_index: int,
    item_count: int,
) -> Tuple[Optional[str], str]:
    remote_path = posixpath.join(remote_dir, _safe_remote_name(local_path))
    temporary_path = f"{remote_path}.part-{uuid.uuid4().hex[:8]}"
    archived_name = os.path.basename(local_path)

    q_dir = shlex.quote(remote_dir)
    q_tmp = shlex.quote(temporary_path)
    q_payload = shlex.quote(posixpath.join(temporary_path, archived_name))
    q_final = shlex.quote(remote_path)
    cleanup_command = shlex.quote(f"rm -rf -- {q_tmp}")
    remote_command = (
        "umask 077; "
        f"mkdir -p -- {q_dir} || exit $?; "
        f"[ ! -e {q_final} ] || exit 1; "
        f"mkdir -- {q_tmp} || exit $?; "
        f"trap {cleanup_command} EXIT HUP INT TERM; "
        f"tar -xzf - -C {q_tmp} && "
        f"[ -d {q_payload} ] && chmod -R go-rwx {q_payload} && "
        f"mv -- {q_payload} {q_final}; "
        "result=$?; trap - EXIT HUP INT TERM; "
        f"rm -rf -- {q_tmp}; exit $result"
    )
    ssh_command = _ssh_upload_command(host, remote_command, ssh_bin, control_path)

    with tempfile.TemporaryDirectory(prefix="friendly-folder-upload-") as temp_dir:
        archive_path = os.path.join(temp_dir, "folder.tar.gz")
        error = _create_directory_archive(
            local_path,
            archive_path,
            progress_callback,
            item_index,
            item_count,
        )
        if error:
            return None, error
        error = _stream_file_to_ssh(
            archive_path,
            ssh_command,
            progress_callback,
            item_index,
            item_count,
            "extracting",
        )

    if error:
        return None, error
    return remote_path, ""


def upload_items(
    local_paths: Sequence[str],
    host: str,
    remote_dir: str,
    ssh_bin: str,
    control_path: Optional[str] = None,
    progress_callback: ProgressCallback = None,
) -> UploadResult:
    remote_paths: List[str] = []
    item_count = len(local_paths)
    for item_index, local_path in enumerate(local_paths):
        if os.path.isdir(local_path):
            remote_path, error = _upload_directory(
                local_path,
                host,
                remote_dir,
                ssh_bin,
                control_path,
                progress_callback,
                item_index,
                item_count,
            )
        else:
            remote_path, error = _upload_file(
                local_path,
                host,
                remote_dir,
                ssh_bin,
                control_path,
                progress_callback,
                item_index,
                item_count,
            )
        if remote_path is None:
            return UploadResult(None, error)
        remote_paths.append(remote_path)
    return UploadResult(remote_paths)


def _write_all(fd: int, data: bytes) -> None:
    view = memoryview(data)
    while view:
        try:
            written = os.write(fd, view)
        except InterruptedError:
            continue
        view = view[written:]


def _copy_window_size(source_fd: int, target_fd: int) -> None:
    try:
        size = fcntl.ioctl(source_fd, termios.TIOCGWINSZ, b"\0" * 8)
        fcntl.ioctl(target_fd, termios.TIOCSWINSZ, size)
    except OSError:
        pass


def _notify_failure(message: str) -> None:
    short = message.replace("\n", " ").replace("\r", " ").strip()
    if len(short) > 160:
        short = short[:157] + "..."
    title = "Drag & drop: файл не загрузился"
    if short:
        title += f" ({short})"
    # OSC 9 is understood by Ghostty as a desktop notification.  The bell is
    # a fallback for notification-disabled setups and does not alter the TUI.
    payload = f"\x1b]9;{title}\x07\x07".encode("utf-8", "replace")
    _write_all(sys.stdout.fileno(), payload)


def _terminal_progress_payload(state: int, value: Optional[int] = None) -> bytes:
    """Build Ghostty's native progress-report sequence without visible text."""
    sequence = f"\x1b]9;4;{state}"
    if value is not None:
        sequence += f";{max(0, min(100, value))}"
    return f"{sequence}\x1b\\".encode("ascii")


def _show_terminal_progress(state: int, value: Optional[int] = None) -> None:
    _write_all(sys.stdout.fileno(), _terminal_progress_payload(state, value))


def _restore_terminal_display(fd: int) -> None:
    """Undo full-screen terminal modes after an abrupt remote disconnect."""
    try:
        _write_all(fd, TERMINAL_DISPLAY_RESET)
    except OSError:
        pass


class Proxy:
    def __init__(
        self,
        master_fd: int,
        host: str,
        remote_dir: str,
        ssh_bin: str,
        control_path: Optional[str],
    ) -> None:
        self.master_fd = master_fd
        self.host = host
        self.remote_dir = remote_dir
        self.ssh_bin = ssh_bin
        self.control_path = control_path
        self.paste_payload: Optional[bytearray] = None
        self.deferred_input = bytearray()
        self.uploading = False
        self.upload_was_bracketed = False
        self.events: "queue.Queue[object]" = queue.Queue()
        self.current_progress: Optional[ProgressUpdate] = None
        self.last_progress_render = 0.0
        self.notify_read, self.notify_write = os.pipe()

    def close(self) -> None:
        if self.current_progress is not None:
            _show_terminal_progress(0)
            self.current_progress = None
        for fd in (self.notify_read, self.notify_write):
            try:
                os.close(fd)
            except OSError:
                pass

    def _queue_event(self, event: object) -> None:
        self.events.put(event)
        try:
            os.write(self.notify_write, b"1")
        except OSError:
            pass

    def _render_progress(self, force: bool = False) -> None:
        progress = self.current_progress
        if progress is None:
            return
        now = time.monotonic()
        if not force and now - self.last_progress_render < 1.0:
            return
        if progress.phase == "uploading":
            if progress.bytes_total == 0:
                percent = 100
            else:
                percent = round(100 * progress.bytes_done / progress.bytes_total)
            _show_terminal_progress(1, percent)
        else:
            _show_terminal_progress(3)
        self.last_progress_render = now

    def refresh_progress(self) -> None:
        self._render_progress()

    def _begin_upload(self, items: Sequence[str], bracketed: bool) -> None:
        self.uploading = True
        self.upload_was_bracketed = bracketed
        first_phase = "preparing" if os.path.isdir(items[0]) else "starting"
        self.current_progress = ProgressUpdate(first_phase, 0, len(items))
        self._render_progress(force=True)

        def worker() -> None:
            result = upload_items(
                items,
                self.host,
                self.remote_dir,
                self.ssh_bin,
                self.control_path,
                self._queue_event,
            )
            self._queue_event(result)

        threading.Thread(target=worker, name="friendly-file-upload", daemon=True).start()

    def _send_replacement(self, remote_paths: Sequence[str]) -> None:
        text = " ".join(shlex.quote(path) for path in remote_paths).encode("utf-8")
        if self.upload_was_bracketed:
            text = BRACKETED_PASTE_START + text + BRACKETED_PASTE_END
        _write_all(self.master_fd, text)

    def process_events(self) -> None:
        try:
            os.read(self.notify_read, 4096)
        except OSError:
            pass
        while True:
            try:
                event = self.events.get_nowait()
            except queue.Empty:
                return

            if isinstance(event, ProgressUpdate):
                phase_changed = (
                    self.current_progress is None
                    or self.current_progress.phase != event.phase
                )
                self.current_progress = event
                self._render_progress(force=phase_changed)
                continue

            if not isinstance(event, UploadResult):
                continue

            self.uploading = False
            self.current_progress = None
            if event.remote_paths is not None:
                _show_terminal_progress(0)
                self._send_replacement(event.remote_paths)
            else:
                _show_terminal_progress(2)
                _notify_failure(event.error)

            if self.deferred_input:
                waiting = bytes(self.deferred_input)
                self.deferred_input.clear()
                self.feed_input(waiting)

    def feed_input(self, data: bytes) -> None:
        if self.uploading:
            self.deferred_input.extend(data)
            return

        # Ghostty normally uses bracketed paste while the remote application
        # asks for it. Also recognize a plain one-shot path for applications
        # that do not enable bracketed paste.
        if self.paste_payload is None and BRACKETED_PASTE_START not in data:
            items = local_items_from_paste(data)
            if items is not None:
                self._begin_upload(items, bracketed=False)
                return

        pending = data
        while pending and not self.uploading:
            if self.paste_payload is None:
                start = pending.find(BRACKETED_PASTE_START)
                if start < 0:
                    _write_all(self.master_fd, pending)
                    return
                if start:
                    _write_all(self.master_fd, pending[:start])
                self.paste_payload = bytearray()
                pending = pending[start + len(BRACKETED_PASTE_START) :]
                continue

            end = pending.find(BRACKETED_PASTE_END)
            if end < 0:
                self.paste_payload.extend(pending)
                if len(self.paste_payload) > MAX_PASTE_BYTES:
                    original = BRACKETED_PASTE_START + bytes(self.paste_payload)
                    self.paste_payload = None
                    _write_all(self.master_fd, original)
                return

            self.paste_payload.extend(pending[:end])
            payload = bytes(self.paste_payload)
            self.paste_payload = None
            remainder = pending[end + len(BRACKETED_PASTE_END) :]
            items = local_items_from_paste(payload)
            if items is None:
                original = BRACKETED_PASTE_START + payload + BRACKETED_PASTE_END
                _write_all(self.master_fd, original)
                pending = remainder
                continue

            if remainder:
                self.deferred_input.extend(remainder)
            self._begin_upload(items, bracketed=True)
            return


def run_proxy(
    command: Sequence[str],
    host: str,
    remote_dir: str,
    ssh_bin: str,
    control_path: Optional[str] = None,
) -> int:
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        os.execvp(command[0], list(command))

    child_pid, master_fd = pty.fork()
    if child_pid == 0:
        os.execvp(command[0], list(command))
        raise AssertionError("execvp returned")

    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()
    saved_terminal = termios.tcgetattr(stdin_fd)
    proxy = Proxy(master_fd, host, remote_dir, ssh_bin, control_path)

    def resize(_signum: int = 0, _frame: object = None) -> None:
        _copy_window_size(stdin_fd, master_fd)

    def terminate(signum: int, _frame: object) -> None:
        try:
            os.kill(child_pid, signum)
        finally:
            raise SystemExit(128 + signum)

    previous_winch = signal.signal(signal.SIGWINCH, resize)
    previous_term = signal.signal(signal.SIGTERM, terminate)
    previous_hup = signal.signal(signal.SIGHUP, terminate)
    resize()
    tty.setraw(stdin_fd)

    try:
        child_open = True
        while child_open:
            readers = [master_fd, proxy.notify_read]
            if not proxy.uploading:
                readers.append(stdin_fd)
            timeout = 1.0 if proxy.uploading else None
            ready, _, _ = select.select(readers, [], [], timeout)

            if proxy.uploading:
                proxy.refresh_progress()

            if master_fd in ready:
                try:
                    output = os.read(master_fd, 65536)
                except OSError as exc:
                    if exc.errno == errno.EIO:
                        output = b""
                    else:
                        raise
                if output:
                    _write_all(stdout_fd, output)
                else:
                    child_open = False

            if proxy.notify_read in ready:
                proxy.process_events()

            if stdin_fd in ready and child_open:
                incoming = os.read(stdin_fd, 65536)
                if not incoming:
                    child_open = False
                else:
                    proxy.feed_input(incoming)
    finally:
        termios.tcsetattr(stdin_fd, termios.TCSADRAIN, saved_terminal)
        signal.signal(signal.SIGWINCH, previous_winch)
        signal.signal(signal.SIGTERM, previous_term)
        signal.signal(signal.SIGHUP, previous_hup)
        proxy.close()
        _restore_terminal_display(stdout_fd)
        try:
            os.close(master_fd)
        except OSError:
            pass

    _, status = os.waitpid(child_pid, 0)
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    if os.WIFSIGNALED(status):
        return 128 + os.WTERMSIG(status)
    return 1


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="SSH drag-and-drop file and folder uploader"
    )
    parser.add_argument("--host", required=True)
    parser.add_argument("--remote-dir", required=True)
    parser.add_argument("--ssh-bin", default="/usr/bin/ssh")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if args.command and args.command[0] == "--":
        args.command = args.command[1:]
    if not args.command:
        parser.error("a command is required after --")
    return args


def configured_control_path(ssh_bin: str, host: str) -> Optional[str]:
    """Ask OpenSSH for the shared connection socket configured for a host."""
    try:
        completed = subprocess.run(
            [ssh_bin, "-G", host],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if completed.returncode != 0:
        return None
    for raw_line in completed.stdout.decode("utf-8", "replace").splitlines():
        key, _, value = raw_line.partition(" ")
        if key.lower() == "controlpath" and value and value.lower() != "none":
            return os.path.expanduser(value)
    return None


def main(argv: Sequence[str]) -> int:
    args = parse_args(argv)
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        os.execvp(args.command[0], list(args.command))

    # Prefer the host's normal OpenSSH multiplexing socket. This lets the
    # interactive session, drag-and-drop uploads, and later SSH commands all
    # reuse one TCP connection. Fall back to a private socket for hosts that do
    # not configure ControlMaster.
    shared_control_path = configured_control_path(args.ssh_bin, args.host)
    if shared_control_path:
        return run_proxy(
            args.command,
            args.host,
            args.remote_dir,
            args.ssh_bin,
            shared_control_path,
        )

    mux_dir = tempfile.mkdtemp(prefix="friendly-ssh-")
    control_path = os.path.join(mux_dir, "mux")
    command = [
        args.command[0],
        "-o",
        "ControlMaster=auto",
        "-o",
        f"ControlPath={control_path}",
        "-o",
        "ControlPersist=no",
        *args.command[1:],
    ]
    try:
        return run_proxy(
            command,
            args.host,
            args.remote_dir,
            args.ssh_bin,
            control_path,
        )
    finally:
        try:
            if os.path.lexists(control_path):
                os.unlink(control_path)
            os.rmdir(mux_dir)
        except OSError:
            pass


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
