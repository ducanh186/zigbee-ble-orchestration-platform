// Mock data — used by all screens. Mirrors systemdes.md models.
const MOCK_DEVICES = [
  { id: 'light-01', deviceType: 'light', name: 'Lab Light 01', roomName: 'Lab 01',
    isOnline: true, power: 'on', reportedAt: '07:16:03' },
  { id: 'light-02', deviceType: 'light', name: 'Hallway Light', roomName: 'Lobby',
    isOnline: true, power: 'off', reportedAt: '07:14:12' },
  { id: 'light-03', deviceType: 'light', name: 'Stairwell B', roomName: 'Floor 2',
    isOnline: false, power: 'unreachable', reportedAt: '06:52:00' },
  { id: 'light-04', deviceType: 'light', name: 'Reception Spot', roomName: 'Lobby',
    isOnline: true, power: 'on', reportedAt: '07:15:48' },
  { id: 'light-05', deviceType: 'light', name: 'Server Rack', roomName: 'Lab 01',
    isOnline: true, power: 'off', reportedAt: '07:09:31' },
  { id: 'pir-01', deviceType: 'motion', name: 'Lab Motion', roomName: 'Lab 01',
    isOnline: true, power: null, reportedAt: '07:16:00' },
];

const MOCK_LOGS = [
  { id: 'l1', t: '07:16:03', deviceId: 'light-01', type: 'LIGHT', sev: 'info',
    icon: 'circle-check', msg: 'Command executed: off',
    meta: 'source=gateway · command_id=cmd-01' },
  { id: 'l2', t: '07:15:48', deviceId: 'light-04', type: 'LIGHT', sev: 'info',
    icon: 'circle-check', msg: 'State reported: on',
    meta: 'source=gateway · level=180' },
  { id: 'l3', t: '07:15:41', deviceId: 'gw-1',    type: 'GATEWAY', sev: 'warning',
    icon: 'triangle-alert', msg: 'Command timeout',
    meta: 'source=cloud · command_id=cmd-00' },
  { id: 'l4', t: '07:15:09', deviceId: 'light-02', type: 'LIGHT', sev: 'error',
    icon: 'circle-x', msg: 'Command failed: cluster busy',
    meta: 'source=gateway · command_id=cmd-99' },
  { id: 'l5', t: '07:14:12', deviceId: 'light-02', type: 'LIGHT', sev: 'info',
    icon: 'circle-check', msg: 'State reported: off',
    meta: 'source=gateway' },
  { id: 'l6', t: '07:13:00', deviceId: 'pir-01',   type: 'MOTION', sev: 'info',
    icon: 'radar', msg: 'Motion detected',
    meta: 'source=gateway · zone=lab' },
  { id: 'l7', t: '07:11:42', deviceId: 'light-03', type: 'LIGHT', sev: 'warning',
    icon: 'wifi-off', msg: 'Device unreachable',
    meta: 'source=cloud · last_seen=06:52:00' },
  { id: 'l8', t: '07:09:31', deviceId: 'light-05', type: 'LIGHT', sev: 'info',
    icon: 'circle-check', msg: 'Command executed: off',
    meta: 'source=gateway · command_id=cmd-72' },
];

const POWER_TONE = { on: 'success', off: 'neutral', unreachable: 'warning' };
const POWER_LABEL = { on: 'ON', off: 'OFF', unreachable: 'UNREACHABLE' };
const SEV_TONE = { info: 'primary', warning: 'warning', error: 'error' };
const TYPE_ICON = { light: 'lightbulb', motion: 'radar', switch: 'toggle-left',
                    lock: 'lock', gateway: 'router', unknown: 'circle-help' };

Object.assign(window, { MOCK_DEVICES, MOCK_LOGS, POWER_TONE, POWER_LABEL, SEV_TONE, TYPE_ICON });
