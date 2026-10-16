# Память Немо для nyashell: запоминает все окна и вкладки (по порядку) и где каждая из них стоит.
# Немо вызывает LocationWidgetProvider.get_widget() для каждой вкладки при каждой смене папки — мы отдаём
# ему невидимый «маячок», который живёт внутри вкладки. По маячкам видно, какие вкладки в каких окнах открыты.
# Состояние пишется в ~/.local/state/nyashell/nemo-tabs.json, открывает его files/nemo-open.sh.
# Nemo memory for nyashell: remembers every window and tab (in order) and where each of them is.
# Nemo calls LocationWidgetProvider.get_widget() for every tab on every folder change; we hand it an invisible
# "beacon" that lives inside the tab. The beacons show which tabs are open in which windows.
# State goes to ~/.local/state/nyashell/nemo-tabs.json; files/nemo-open.sh reopens it.
import json
import os

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Nemo", "3.0")
from gi.repository import GLib, GObject, Gtk, Nemo  # noqa: E402

STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
                     "nyashell", "nemo-tabs.json")


class NyashMemory(GObject.GObject, Nemo.LocationWidgetProvider):
    def __init__(self):
        GObject.GObject.__init__(self)
        self.beacons = []      # живые маячки / live beacons: (widget, uri)
        self.timer = 0

    # ─── маячок во вкладке / a beacon in the tab ───
    def get_widget(self, uri, window):
        w = Gtk.Box()
        w.set_size_request(0, 0)       # не показываем: занимать место ему незачем / never shown, takes no space
        entry = [w, uri]
        self.beacons.append(entry)
        # вкладка ушла в другую папку или закрылась — маячок вынимают из неё
        # the tab moved to another folder or closed: the beacon gets taken out of it
        w.connect("parent-set", self.on_parent, entry)
        self.schedule()
        return w

    def on_parent(self, w, old_parent, entry):
        if w.get_parent() is None and old_parent is not None:
            if entry in self.beacons:
                self.beacons.remove(entry)
            self.schedule()

    # ─── сохранение / saving ───
    # с задержкой: при закрытии окна (или выходе из Немо) все вкладки пропадают за миллисекунды, и к моменту
    # записи окон уже нет — тогда файл не трогаем и в нём остаётся то, что было до закрытия
    # with a delay: when a window closes (or Nemo quits) all tabs vanish within milliseconds, and by the time we'd
    # write there are no windows left, so the file is left alone and keeps what was there before closing
    def schedule(self):
        if self.timer:
            GLib.source_remove(self.timer)
        self.timer = GLib.timeout_add(700, self.save)

    def save(self):
        self.timer = 0
        wins = {}
        order = []
        for w, uri in list(self.beacons):
            top = w.get_toplevel()
            if not isinstance(top, Gtk.Window) or not top.get_visible():
                continue
            # страница блокнота с вкладками, в которой лежит маячок / the notebook page holding the beacon
            child, nb = w, None
            while child is not None:
                p = child.get_parent()
                if isinstance(p, Gtk.Notebook):
                    nb = p
                    break
                child = p
            idx = nb.page_num(child) if nb is not None else 0
            active = nb is None or nb.get_current_page() == idx
            if top not in wins:
                wins[top] = []
                order.append(top)
            wins[top].append((id(nb), idx, uri, active))
        if not order:
            return False
        out = []
        for top in order:
            tabs = sorted(wins[top], key=lambda t: (t[0], t[1]))
            out.append({"tabs": [t[2] for t in tabs],
                        "active": next((i for i, t in enumerate(tabs) if t[3]), 0)})
        try:
            os.makedirs(os.path.dirname(STATE), exist_ok=True)
            tmp = STATE + ".tmp"
            with open(tmp, "w") as f:
                json.dump({"windows": out}, f)
            os.replace(tmp, STATE)
        except OSError:
            pass
        return False
