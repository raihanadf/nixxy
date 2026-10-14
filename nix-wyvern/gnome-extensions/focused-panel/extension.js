// greys out every top bar except the one on the monitor that holds the
// focused window (or the pointer, when nothing is focused). the secondary
// bars come from topbar-all-monitors, which adds them as chrome boxes named
// "topbarAllMonitorsPanelBox" holding a panel with _monitorIndex.
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const EFFECT = 'focused-panel-dim';

export default class FocusedPanelExtension extends Extension {
    enable() {
        const queue = () => this._queue();
        this._signals = [
            [global.display, global.display.connect('notify::focus-window', queue)],
            [Main.layoutManager, Main.layoutManager.connect('monitors-changed', queue)],
            [Main.layoutManager.uiGroup, Main.layoutManager.uiGroup.connect('child-added', queue)],
        ];
        this._queue();
    }

    disable() {
        for (const [object, id] of this._signals)
            object.disconnect(id);
        this._signals = null;
        if (this._idle) {
            GLib.source_remove(this._idle);
            this._idle = 0;
        }
        for (const [panel] of this._panels())
            this._dim(panel, false);
    }

    _queue() {
        if (this._idle)
            return;
        this._idle = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._idle = 0;
            this._update();
            return GLib.SOURCE_REMOVE;
        });
    }

    _panels() {
        const panels = [[Main.panel, Main.layoutManager.primaryIndex]];
        for (const box of Main.layoutManager.uiGroup.get_children()) {
            if (box.name !== 'topbarAllMonitorsPanelBox')
                continue;
            for (const panel of box.get_children()) {
                if (panel._monitorIndex !== undefined)
                    panels.push([panel, panel._monitorIndex]);
            }
        }
        return panels;
    }

    _update() {
        const window = global.display.focus_window;
        const focused = window ? window.get_monitor() : global.display.get_current_monitor();
        const panels = this._panels();
        // with a single bar there is nothing to tell apart
        for (const [panel, monitor] of panels)
            this._dim(panel, panels.length > 1 && monitor !== focused);
    }

    _dim(panel, dimmed) {
        const effect = panel.get_effect(EFFECT);
        if (!dimmed) {
            if (effect)
                panel.remove_effect(effect);
            panel.opacity = 255;
            return;
        }
        if (!effect)
            panel.add_effect_with_name(EFFECT, new Clutter.DesaturateEffect({factor: 1.0}));
        panel.opacity = 140;
    }
}
