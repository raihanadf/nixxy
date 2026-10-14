// fork of fa8i/topbar-all-monitors (GPL-3.0-or-later, see LICENSE): a real
// gnome top bar on every external monitor. changes from upstream:
// - the right side mirrors the main bar instead of building its own
//   indicators, so icons other extensions add only to Main.panel (caffeine,
//   tray icons) show up too. clicking a mirror opens the original menu
//   under the mirror.
// - every bar except the one on the monitor holding the focused window (or
//   the pointer, when nothing is focused) is greyed out.
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Meta from 'gi://Meta';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Panel from 'resource:///org/gnome/shell/ui/panel.js';

const PANEL_BOX_NAME = 'panelBox';
const DIM_EFFECT = 'wyvern-panels-dim';

const SecondaryPanel = GObject.registerClass({
    Signals: {'allocated': {}},
}, class SecondaryPanel extends Panel.Panel {
    _init(monitorIndex, panelBox) {
        super._init();

        this._monitorIndex = monitorIndex;

        Main.layoutManager.panelBox.remove_child(this);
        panelBox.add_child(this);

        Main.panel.connectObject(
            'notify::style-class',
            () => this._syncStyleClass(),
            this
        );
        this._syncStyleClass();

        this._mirrors = new St.BoxLayout({y_expand: true});
        this._rightBox.add_child(this._mirrors);
        Main.panel._rightBox.connectObject(
            'child-added', () => this._syncMirrors(),
            'child-removed', () => this._syncMirrors(),
            this
        );
        this._syncMirrors();
    }

    _syncMirrors() {
        this._mirrors.destroy_all_children();

        for (const container of Main.panel._rightBox.get_children()) {
            const indicator = container.get_first_child();
            const mirror = new St.Widget({
                layout_manager: new Clutter.BinLayout(),
                reactive: true,
                y_expand: true,
            });
            mirror.add_child(new Clutter.Clone({
                source: container,
                y_align: Clutter.ActorAlign.CENTER,
                y_expand: true,
            }));
            container.bind_property('visible', mirror, 'visible',
                GObject.BindingFlags.SYNC_CREATE);
            mirror.connect('button-release-event', () => {
                this._openUnder(indicator?.menu, mirror);
                return Clutter.EVENT_STOP;
            });
            this._mirrors.add_child(mirror);
        }
    }

    // the original menu, anchored to the mirror while it is open
    _openUnder(menu, mirror) {
        if (!menu?.toggle)
            return;
        if (menu.isOpen) {
            menu.close();
            return;
        }

        const source = menu.sourceActor;
        menu.sourceActor = mirror;
        const id = menu.connect('open-state-changed', (_menu, open) => {
            if (open)
                return;
            menu.disconnect(id);
            menu.sourceActor = source;
        });
        menu.open();
    }

    // the right side is mirrored from the main bar, so never build this
    // panel's own right-side indicators (gnome rebuilds boxes on every
    // session mode change, e.g. after unlocking)
    _updateBox(elements, box) {
        if (box !== this._rightBox)
            super._updateBox(elements, box);
    }

    _syncStyleClass() {
        this.set_style_class_name(Main.panel.get_style_class_name());
    }

    vfunc_get_preferred_width(_forHeight) {
        const monitor = Main.layoutManager.monitors[this._monitorIndex];

        return [0, monitor?.width ?? 0];
    }

    vfunc_allocate(box) {
        super.vfunc_allocate(box);

        // notify::allocation only fires when the box changes; a relayout that
        // keeps the same geometry must still retry publication.
        this.emit('allocated');
    }

    destroy() {
        Main.panel.disconnectObject(this);
        Main.panel._rightBox.disconnectObject(this);
        Main.ctrlAltTabManager.removeGroup(this);

        super.destroy();
    }

    _getDraggableWindowForPosition(stageX) {
        const workspace = global.workspace_manager.get_active_workspace();
        const windows = workspace.list_windows();
        const monitor = Main.layoutManager.monitors[this._monitorIndex];

        if (!monitor)
            return null;

        const allWindowsByStacking =
            global.display.sort_windows_by_stacking(windows).reverse();

        return allWindowsByStacking.find(metaWindow => {
            const rect = metaWindow.get_frame_rect();

            return metaWindow.get_monitor() === this._monitorIndex &&
                metaWindow.showing_on_its_workspace() &&
                metaWindow.get_window_type() !== Meta.WindowType.DESKTOP &&
                metaWindow.maximized_vertically &&
                stageX > rect.x &&
                stageX < rect.x + rect.width;
        });
    }
});

class SecondaryPanelBox {
    constructor(monitorIndex, monitor) {
        this.monitorIndex = monitorIndex;
        this._publishIdleId = 0;

        this.actor = new St.BoxLayout({
            name: 'topbarAllMonitorsPanelBox',
            style_class: 'topbar-all-monitors-panel-box',
            orientation: Clutter.Orientation.VERTICAL,
            clip_to_allocation: true,
            reactive: true,
            x: monitor.x,
            y: monitor.y,
            width: monitor.width,
        });

        this.panel = new SecondaryPanel(monitorIndex, this.actor);
        this.panel.connectObject(
            'allocated',
            () => this._queuePublishPanel(),
            this.actor
        );

        Main.layoutManager.addChrome(this.actor);
    }

    _queuePublishPanel() {
        if (this._publishIdleId)
            return;

        // Wait for allocation and the previous panel's strut removal.
        this._publishIdleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._publishIdleId = 0;
            this._publishPanel();
            return GLib.SOURCE_REMOVE;
        });
    }

    _publishPanel() {
        if (!this.actor.has_allocation() || !this.panel.has_allocation())
            return;

        const monitor = Main.layoutManager.findMonitorForActor(this.panel);
        if (monitor?.index !== this.monitorIndex)
            return;

        // Allow styling extensions to discover the panel once its geometry is valid.
        this.panel.disconnectObject(this.actor);
        this.actor.set_name(PANEL_BOX_NAME);

        // Trigger work-area discovery after publishing the panel.
        Main.layoutManager.untrackChrome(this.actor);
        Main.layoutManager.trackChrome(this.actor, {
            affectsStruts: true,
            trackFullscreen: true,
        });
    }

    destroy() {
        if (this._publishIdleId) {
            GLib.Source.remove(this._publishIdleId);
            this._publishIdleId = 0;
        }

        this.panel.destroy();
        this.panel = null;

        Main.layoutManager.removeChrome(this.actor);
        this.actor.destroy();
        this.actor = null;
    }
}

export default class WyvernPanelsExtension extends Extension {
    enable() {
        this._panels = [];
        this._dimIdleId = 0;
        Main.layoutManager.connectObject(
            'startup-complete',
            () => this._rebuildPanels(),
            'monitors-changed',
            () => this._rebuildPanels(),
            this
        );
        global.display.connectObject(
            'notify::focus-window', () => this._queueDim(),
            'window-entered-monitor', () => this._queueDim(),
            this
        );

        this._rebuildPanels();
    }

    disable() {
        Main.layoutManager.disconnectObject(this);
        global.display.disconnectObject(this);
        if (this._dimIdleId) {
            GLib.Source.remove(this._dimIdleId);
            this._dimIdleId = 0;
        }

        this._destroyPanels();
        this._dim(Main.panel, false);
    }

    _rebuildPanels() {
        this._destroyPanels();

        // The startup animation temporarily transforms monitor coordinates.
        if (Main.layoutManager._startingUp)
            return;

        const primaryIndex = Main.layoutManager.primaryIndex;

        for (let i = 0; i < Main.layoutManager.monitors.length; i++) {
            if (i === primaryIndex)
                continue;

            const monitor = Main.layoutManager.monitors[i];
            this._panels.push(new SecondaryPanelBox(i, monitor));
        }
        this._queueDim();
    }

    _destroyPanels() {
        for (const panel of this._panels)
            panel.destroy();

        this._panels = [];
    }

    _queueDim() {
        if (this._dimIdleId)
            return;
        this._dimIdleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._dimIdleId = 0;
            this._syncDim();
            return GLib.SOURCE_REMOVE;
        });
    }

    _syncDim() {
        const window = global.display.focus_window;
        const focused = window ? window.get_monitor() : global.display.get_current_monitor();
        const panels = [
            [Main.panel, Main.layoutManager.primaryIndex],
            ...this._panels.map(box => [box.panel, box.monitorIndex]),
        ];

        // with a single bar there is nothing to tell apart
        for (const [panel, monitor] of panels)
            this._dim(panel, panels.length > 1 && monitor !== focused);
    }

    _dim(panel, dimmed) {
        const effect = panel.get_effect(DIM_EFFECT);
        if (!dimmed) {
            if (effect)
                panel.remove_effect(effect);
            panel.opacity = 255;
            return;
        }
        if (!effect)
            panel.add_effect_with_name(DIM_EFFECT, new Clutter.DesaturateEffect({factor: 1.0}));
        panel.opacity = 140;
    }
}
