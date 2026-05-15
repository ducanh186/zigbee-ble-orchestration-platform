// AutomationMock.jsx — sample rules + the 4 MVP templates.
// Mirrors the API shape in AUTOMATION_APP_DESIGN_BRIEF.md.

const TEMPLATES = [
  {
    id: 'motion_on',
    title: 'Motion becomes occupied',
    action: 'Turn selected lights on',
    triggerType: 'motion',
    triggerEvent: 'occupancy changes: occupied',
    targetType: 'light',
    targetAction: 'on',
    icon: 'radar',
    accent: 'success',
  },
  {
    id: 'motion_off',
    title: 'Motion becomes unoccupied',
    action: 'Turn selected lights off',
    triggerType: 'motion',
    triggerEvent: 'occupancy changes: unoccupied',
    targetType: 'light',
    targetAction: 'off',
    icon: 'radar',
    accent: 'neutral',
  },
  {
    id: 'switch_one',
    title: 'Switch toggles one light',
    action: 'Toggle the selected light',
    triggerType: 'switch',
    triggerEvent: 'toggles',
    targetType: 'light',
    targetAction: 'toggle',
    icon: 'toggle-left',
    accent: 'primary',
    targetLimit: 1,
  },
  {
    id: 'switch_many',
    title: 'Switch toggles selected lights',
    action: 'Toggle the selected lights',
    triggerType: 'switch',
    triggerEvent: 'toggles',
    targetType: 'light',
    targetAction: 'toggle',
    icon: 'toggle-left',
    accent: 'primary',
  },
];

const MOCK_RULES = [
  {
    id: 'aut-01',
    name: 'Motion turns on lab lights',
    enabled: true,
    template: 'motion_on',
    triggerDeviceId: '0000000000000053',
    triggerDeviceLabel: 'motion-01',
    triggerEvent: 'occupancy changes: occupied',
    targets: [
      { id: '000000000000004F', label: 'light-01' },
      { id: '0000000000000055', label: 'light-02' },
    ],
    targetAction: 'on',
    sync_status: 'synced',
    last_run_status: 'executed',
    last_run_at: '07:12:41',
    created_at: '07:01:08',
  },
  {
    id: 'aut-02',
    name: 'Reception spot off when empty',
    enabled: true,
    template: 'motion_off',
    triggerDeviceId: '0000000000000053',
    triggerDeviceLabel: 'motion-01',
    triggerEvent: 'occupancy changes: unoccupied',
    targets: [
      { id: '0000000000000061', label: 'light-04' },
    ],
    targetAction: 'off',
    sync_status: 'pending',
    last_run_status: 'never_run',
    last_run_at: null,
    created_at: '07:14:55',
  },
  {
    id: 'aut-03',
    name: 'Wall switch · lobby cluster',
    enabled: false,
    template: 'switch_many',
    triggerDeviceId: '00000000000000A2',
    triggerDeviceLabel: 'switch-01',
    triggerEvent: 'toggles',
    targets: [
      { id: '000000000000004F', label: 'light-01' },
      { id: '0000000000000061', label: 'light-04' },
      { id: '00000000000000B7', label: 'light-05' },
    ],
    targetAction: 'toggle',
    sync_status: 'failed',
    last_run_status: 'failed',
    last_run_at: '06:58:02',
    created_at: '06:45:00',
  },
];

// device list used by the create form
const AUTO_DEVICES = [
  { id: '0000000000000053', label: 'motion-01', name: 'Lab Motion', room: 'Lab 01', type: 'motion' },
  { id: '00000000000000A2', label: 'switch-01', name: 'Lobby Switch', room: 'Lobby', type: 'switch' },
  { id: '000000000000004F', label: 'light-01', name: 'Lab Light 01', room: 'Lab 01', type: 'light' },
  { id: '0000000000000055', label: 'light-02', name: 'Hallway Light', room: 'Lobby', type: 'light' },
  { id: '0000000000000061', label: 'light-04', name: 'Reception Spot', room: 'Lobby', type: 'light' },
  { id: '00000000000000B7', label: 'light-05', name: 'Server Rack', room: 'Lab 01', type: 'light' },
];

// status chip mappings
const SYNC_TONE = {
  pending: 'warning',
  synced: 'success',
  failed: 'error',
};
const SYNC_ICON = {
  pending: 'loader-circle',
  synced: 'circle-check',
  failed: 'circle-x',
};
const RUN_TONE = {
  never_run: 'neutral',
  executed: 'success',
  failed: 'error',
  timeout: 'error',
};
const RUN_ICON = {
  never_run: 'minus',
  executed: 'circle-check',
  failed: 'circle-x',
  timeout: 'clock-alert',
};

const tmpl = (id) => TEMPLATES.find(t => t.id === id);

Object.assign(window, {
  TEMPLATES, MOCK_RULES, AUTO_DEVICES,
  SYNC_TONE, SYNC_ICON, RUN_TONE, RUN_ICON, tmpl,
});
