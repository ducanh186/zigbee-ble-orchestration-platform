const DEFAULT_GATEWAY_ID = "gw-ubuntu-01";
const DEFAULT_TARGET = {
  endpoint: 1,
  cluster_id: "0x0006",
  command: "on",
};

const state = {
  apiBase: loadSetting("apiBase", defaultApiBase()),
  gatewayId: loadSetting("gatewayId", DEFAULT_GATEWAY_ID),
  token: loadSetting("authToken", ""),
  devices: [],
  deviceStates: new Map(),
  selectedDeviceId: null,
  events: [],
  commands: [],
  selectedCommand: null,
  deviceFilter: "all",
  refreshTimer: null,
  automations: [],
  automationForm: {
    template: "motion_occupied",
    triggerDeviceId: "",
    actionDeviceIds: new Set(),
  },
};

const AUTOMATION_TEMPLATES = {
  motion_occupied: {
    triggerType: "motion",
    triggerLabel: "Motion sensor",
    actionCommand: "on",
    buildTrigger: (deviceId) => ({
      event: "occupancy_changed",
      device_id: deviceId,
      device_type: "motion",
      state: { occupancy: "occupied" },
    }),
  },
  motion_unoccupied: {
    triggerType: "motion",
    triggerLabel: "Motion sensor",
    actionCommand: "off",
    buildTrigger: (deviceId) => ({
      event: "occupancy_changed",
      device_id: deviceId,
      device_type: "motion",
      state: { occupancy: "unoccupied" },
    }),
  },
  switch_toggle: {
    triggerType: "switch",
    triggerLabel: "Switch",
    actionCommand: "toggle",
    buildTrigger: (deviceId) => ({
      event: "toggle",
      device_id: deviceId,
      device_type: "switch",
    }),
  },
};

const els = {
  apiBaseInput: byId("apiBaseInput"),
  gatewayIdInput: byId("gatewayIdInput"),
  joinDurationInput: byId("joinDurationInput"),
  saveSettingsBtn: byId("saveSettingsBtn"),
  refreshBtn: byId("refreshBtn"),
  apiStatus: byId("apiStatus"),
  deviceCount: byId("deviceCount"),
  onlineCount: byId("onlineCount"),
  eventCount: byId("eventCount"),
  lastSync: byId("lastSync"),
  runtimeSummary: byId("runtimeSummary"),
  deviceSummary: byId("deviceSummary"),
  deviceList: byId("deviceList"),
  detailTitle: byId("detailTitle"),
  detailMeta: byId("detailMeta"),
  detailStatus: byId("detailStatus"),
  statePayload: byId("statePayload"),
  rawTargetInput: byId("rawTargetInput"),
  levelSlider: byId("levelSlider"),
  levelOutput: byId("levelOutput"),
  lightOnBtn: byId("lightOnBtn"),
  lightOffBtn: byId("lightOffBtn"),
  sendLevelBtn: byId("sendLevelBtn"),
  sendRawBtn: byId("sendRawBtn"),
  deleteDeviceBtn: byId("deleteDeviceBtn"),
  gatewayMeta: byId("gatewayMeta"),
  openJoinBtn: byId("openJoinBtn"),
  closeJoinBtn: byId("closeJoinBtn"),
  labelEui64Input: byId("labelEui64Input"),
  labelDeviceType: byId("labelDeviceType"),
  labelModelInput: byId("labelModelInput"),
  labelInstallCodeInput: byId("labelInstallCodeInput"),
  generateLabelBtn: byId("generateLabelBtn"),
  labelQrPreview: byId("labelQrPreview"),
  labelPayload: byId("labelPayload"),
  activitySummary: byId("activitySummary"),
  eventTypeFilter: byId("eventTypeFilter"),
  deviceFilterInput: byId("deviceFilterInput"),
  autoRefreshToggle: byId("autoRefreshToggle"),
  eventTableBody: byId("eventTableBody"),
  commandSummary: byId("commandSummary"),
  commandList: byId("commandList"),
  commandPayload: byId("commandPayload"),
  toast: byId("toast"),
  autoName: byId("autoName"),
  autoTemplate: byId("autoTemplate"),
  autoTriggerLabel: byId("autoTriggerLabel"),
  autoTriggerDevice: byId("autoTriggerDevice"),
  autoActionList: byId("autoActionList"),
  autoEnabled: byId("autoEnabled"),
  autoSaveBtn: byId("autoSaveBtn"),
  automationList: byId("automationList"),
  automationSummary: byId("automationSummary"),
  loginOverlay: byId("loginOverlay"),
  loginForm: byId("loginForm"),
  loginUser: byId("loginUser"),
  loginPass: byId("loginPass"),
  loginError: byId("loginError"),
  logoutBtn: byId("logoutBtn"),
};

init();

function init() {
  els.apiBaseInput.value = state.apiBase;
  els.gatewayIdInput.value = state.gatewayId;
  els.rawTargetInput.value = JSON.stringify(DEFAULT_TARGET, null, 2);
  els.gatewayMeta.textContent = state.gatewayId;
  bindEvents();
  if (state.token) {
    startSession();
  } else {
    requireLogin();
  }
}

// Begin the authenticated dashboard session: hide login, load data, poll.
function startSession() {
  showApp();
  refreshAll();
  scheduleRefresh();
}

async function handleLogin(event) {
  event.preventDefault();
  const username = els.loginUser.value.trim();
  const password = els.loginPass.value;
  els.loginError.textContent = "";
  try {
    const response = await fetch(`${state.apiBase}/auth/login`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ username, password }),
    });
    const data = await response.json().catch(() => null);
    if (!response.ok || !data || !data.access_token) {
      throw new Error((data && data.detail) || `Login failed (${response.status})`);
    }
    state.token = data.access_token;
    localStorage.setItem("cloudOps.authToken", state.token);
    els.loginPass.value = "";
    startSession();
    toast(`Signed in as ${data.username || username}`);
  } catch (error) {
    els.loginError.textContent = cleanError(error);
  }
}

function logout() {
  state.token = "";
  localStorage.removeItem("cloudOps.authToken");
  requireLogin();
}

// Stop polling and show the login overlay (called on logout or any 401).
function requireLogin() {
  if (state.refreshTimer) {
    clearInterval(state.refreshTimer);
    state.refreshTimer = null;
  }
  if (els.loginOverlay) els.loginOverlay.hidden = false;
  if (els.loginUser) els.loginUser.focus();
}

function showApp() {
  if (els.loginOverlay) els.loginOverlay.hidden = true;
}

function bindEvents() {
  if (els.loginForm) els.loginForm.addEventListener("submit", handleLogin);
  if (els.logoutBtn) els.logoutBtn.addEventListener("click", logout);
  els.saveSettingsBtn.addEventListener("click", saveSettings);
  els.refreshBtn.addEventListener("click", refreshAll);
  els.levelSlider.addEventListener("input", () => {
    els.levelOutput.value = els.levelSlider.value;
  });
  els.lightOnBtn.addEventListener("click", () => sendLightPower("on"));
  els.lightOffBtn.addEventListener("click", () => sendLightPower("off"));
  els.sendLevelBtn.addEventListener("click", sendLightLevel);
  els.sendRawBtn.addEventListener("click", sendRawTarget);
  els.deleteDeviceBtn.addEventListener("click", deleteSelectedDevice);
  els.openJoinBtn.addEventListener("click", openJoin);
  els.closeJoinBtn.addEventListener("click", closeJoin);
  els.generateLabelBtn.addEventListener("click", generateProvisioningLabel);
  els.autoTemplate.addEventListener("change", () => {
    state.automationForm.template = els.autoTemplate.value;
    state.automationForm.triggerDeviceId = "";
    renderAutomationForm();
  });
  els.autoTriggerDevice.addEventListener("change", () => {
    state.automationForm.triggerDeviceId = els.autoTriggerDevice.value;
  });
  els.autoSaveBtn.addEventListener("click", saveAutomation);
  els.eventTypeFilter.addEventListener("change", refreshEvents);
  els.deviceFilterInput.addEventListener("input", debounce(refreshEvents, 250));
  els.autoRefreshToggle.addEventListener("change", scheduleRefresh);

  document.querySelectorAll("[data-device-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      document
        .querySelectorAll("[data-device-filter]")
        .forEach((item) => item.classList.remove("active"));
      button.classList.add("active");
      state.deviceFilter = button.dataset.deviceFilter;
      renderDevices();
    });
  });
}

function saveSettings() {
  state.apiBase = normalizeApiBase(els.apiBaseInput.value);
  state.gatewayId = els.gatewayIdInput.value.trim() || DEFAULT_GATEWAY_ID;
  localStorage.setItem("cloudOps.apiBase", state.apiBase);
  localStorage.setItem("cloudOps.gatewayId", state.gatewayId);
  els.apiBaseInput.value = state.apiBase;
  els.gatewayMeta.textContent = state.gatewayId;
  toast("Settings saved");
  refreshAll();
}

async function refreshAll() {
  setBusy(true);
  try {
    const [health, devices, events, automations] = await Promise.all([
      fetchJson("/health").catch((error) => ({ error })),
      fetchJson("/api/devices/").catch((error) => ({ error })),
      loadEvents().catch((error) => ({ error })),
      fetchJson("/api/automations").catch((error) => ({ error })),
    ]);

    if (health.error) {
      markApi("Down", "danger");
      els.runtimeSummary.textContent = cleanError(health.error);
    } else {
      markApi("OK", "ok");
      els.runtimeSummary.textContent = `${health.status} v${health.version}`;
    }

    if (!devices.error) {
      state.devices = devices;
      if (!state.selectedDeviceId && devices.length > 0) {
        state.selectedDeviceId = devices[0].id;
      }
      await loadStatesForDevices(devices);
      renderDevices();
      renderDetail();
      renderAutomationForm();
    }

    if (!events.error) {
      state.events = events;
      renderEvents();
      updateEventTypeFilter(events);
    }

    if (!automations.error) {
      state.automations = automations;
      renderAutomations();
    }

    updateMetrics();
    els.lastSync.textContent = formatClock(new Date());
  } catch (error) {
    toast(cleanError(error));
  } finally {
    setBusy(false);
  }
}

async function loadStatesForDevices(devices) {
  const results = await Promise.all(
    devices.map(async (device) => {
      try {
        const payload = await fetchJson(`/api/devices/${encodeURIComponent(device.id)}/state`);
        return [device.id, payload];
      } catch (error) {
        return [device.id, { error: cleanError(error) }];
      }
    }),
  );
  state.deviceStates = new Map(results);
}

async function refreshEvents() {
  try {
    state.events = await loadEvents();
    updateEventTypeFilter(state.events);
    renderEvents();
    updateMetrics();
  } catch (error) {
    toast(cleanError(error));
  }
}

async function loadEvents() {
  const params = new URLSearchParams({ limit: "120" });
  const eventType = els.eventTypeFilter.value;
  const deviceId = els.deviceFilterInput.value.trim();
  if (eventType) params.set("event_type", eventType);
  if (deviceId) params.set("device_id", deviceId);
  return fetchJson(`/api/events/?${params.toString()}`);
}

function renderDevices() {
  const filtered = state.devices.filter((device) => {
    return state.deviceFilter === "all" || device.device_type === state.deviceFilter;
  });

  els.deviceSummary.textContent = `${filtered.length} shown, ${state.devices.length} total`;
  if (filtered.length === 0) {
    els.deviceList.innerHTML = `<div class="empty">No devices</div>`;
    return;
  }

  els.deviceList.innerHTML = "";
  filtered.forEach((device) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `device-row${device.id === state.selectedDeviceId ? " selected" : ""}`;
    button.addEventListener("click", () => {
      state.selectedDeviceId = device.id;
      renderDevices();
      renderDetail();
      refreshEventsForSelected();
    });

    const main = document.createElement("div");
    const stateInfo = state.deviceStates.get(device.id);
    const lightHtml = buildDeviceStateHint(device, stateInfo);
    main.innerHTML = `
      <div class="device-name">${escapeHtml(device.name || device.id)}</div>
      <div class="device-id">${escapeHtml(device.id)}</div>
      ${lightHtml}
    `;

    const tags = document.createElement("div");
    tags.className = "device-tags";
    tags.append(tag(device.device_type));
    tags.append(tag(device.is_online ? "online" : "offline", device.is_online ? "online" : "offline"));
    if (device.room_id) tags.append(tag(device.room_id));

    button.append(main, tags);
    els.deviceList.append(button);
  });
}

function renderDetail() {
  const device = selectedDevice();
  if (!device) {
    els.detailTitle.textContent = "Device Detail";
    els.detailMeta.textContent = "Select a device";
    els.statePayload.textContent = "No state loaded";
    setDetailStatus("Idle", "muted");
    setCommandControls(false);
    els.deleteDeviceBtn.disabled = true;
    return;
  }

  const currentState = state.deviceStates.get(device.id);
  els.detailTitle.textContent = device.name || device.id;
  els.detailMeta.textContent = `${device.device_type} / ${device.id}`;
  els.deleteDeviceBtn.disabled = false;

  if (device.device_type === "light" && currentState && !currentState.error) {
    els.statePayload.innerHTML = buildLightStateVisual(currentState);
  } else if (device.device_type === "motion" && currentState && !currentState.error) {
    els.statePayload.innerHTML = buildMotionStateVisual(currentState);
  } else {
    els.statePayload.textContent = prettyJson(currentState || {});
  }

  setDetailStatus(device.is_online ? "Online" : "Offline", device.is_online ? "ok" : "danger");
  setCommandControls(device.device_type === "light");

  // Sync On/Off button active states with current light state
  if (device.device_type === "light" && currentState && !currentState.error) {
    const s = currentState.state || currentState;
    const power = s.power;
    els.lightOnBtn.classList.toggle("active-on", power === "on");
    els.lightOffBtn.classList.toggle("active-off", power === "off");
  } else {
    els.lightOnBtn.classList.remove("active-on");
    els.lightOffBtn.classList.remove("active-off");
  }
}

function renderEvents() {
  els.eventTableBody.innerHTML = "";
  els.activitySummary.textContent = `${state.events.length} rows`;

  if (state.events.length === 0) {
    const row = document.createElement("tr");
    row.innerHTML = `<td colspan="4">No events</td>`;
    els.eventTableBody.append(row);
    return;
  }

  state.events.forEach((event) => {
    const row = document.createElement("tr");
    row.innerHTML = `
      <td>${escapeHtml(event.occurred_at || "")}</td>
      <td>${escapeHtml(event.event_type || "")}</td>
      <td class="mono">${escapeHtml(event.device_id || "gateway")}</td>
      <td class="payload-cell">${escapeHtml(compactJson(event.payload))}</td>
    `;
    els.eventTableBody.append(row);
  });
}

function renderCommands() {
  els.commandList.innerHTML = "";
  els.commandSummary.textContent = `${state.commands.length} recent`;
  if (state.commands.length === 0) {
    els.commandList.innerHTML = `<div class="empty">No commands</div>`;
    els.commandPayload.textContent = "No command payload";
    return;
  }

  state.commands.forEach((command) => {
    const item = document.createElement("button");
    item.type = "button";
    item.className = "command-item";
    item.addEventListener("click", async () => {
      await refreshCommand(command.id, true);
    });
    item.innerHTML = `
      <div>
        <div class="command-title">${escapeHtml(command.id)}</div>
        <div class="command-meta">${escapeHtml(command.op)} / ${escapeHtml(command.device_id || "gateway")}</div>
      </div>
      ${statusBadge(command.status)}
    `;
    els.commandList.append(item);
  });
}

async function refreshEventsForSelected() {
  const device = selectedDevice();
  if (!device) return;
  els.deviceFilterInput.value = device.id;
  await refreshEvents();
}

async function sendLightPower(power) {
  const device = selectedDevice();
  if (!device) return toast("Select a light device");
  await createDeviceCommand(device.id, {
    op: "set",
    target: { power },
    timeout_ms: 5000,
  });
}

async function sendLightLevel() {
  const device = selectedDevice();
  if (!device) return toast("Select a light device");
  await createDeviceCommand(device.id, {
    op: "set",
    target: { level: Number(els.levelSlider.value) },
    timeout_ms: 5000,
  });
}

async function sendRawTarget() {
  const device = selectedDevice();
  if (!device) return toast("Select a device");
  let target;
  try {
    target = JSON.parse(els.rawTargetInput.value);
  } catch {
    return toast("Raw target JSON is invalid");
  }
  await createDeviceCommand(device.id, {
    op: "device.command",
    target,
    timeout_ms: 5000,
  });
}

async function deleteSelectedDevice() {
  const device = selectedDevice();
  if (!device) return toast("Select a device first");
  const label = device.name || device.id;
  const confirmed = window.confirm(
    `Delete device "${label}" (${device.device_type})?\n\n` +
    `This removes the cloud row, its states, events, and commands. ` +
    `On the next attribute report the gateway will auto-pair it as a fresh device.\n\n` +
    `Type OK to confirm.`
  );
  if (!confirmed) return;
  try {
    await fetchJson(`/api/devices/${encodeURIComponent(device.id)}`, { method: "DELETE" });
    state.deviceStates.delete(device.id);
    state.selectedDeviceId = null;
    toast(`Deleted ${label}`);
    await refreshAll();
  } catch (error) {
    toast(cleanError(error));
  }
}

function renderAutomationForm() {
  const tpl = AUTOMATION_TEMPLATES[state.automationForm.template];
  if (!tpl) return;
  els.autoTriggerLabel.textContent = tpl.triggerLabel;

  const triggerDevices = state.devices.filter((d) => d.device_type === tpl.triggerType);
  const previous = state.automationForm.triggerDeviceId;
  els.autoTriggerDevice.innerHTML = "";
  if (triggerDevices.length === 0) {
    const opt = document.createElement("option");
    opt.value = "";
    opt.textContent = `No ${tpl.triggerType} devices`;
    opt.disabled = true;
    els.autoTriggerDevice.append(opt);
  } else {
    triggerDevices.forEach((device) => {
      const opt = document.createElement("option");
      opt.value = device.id;
      opt.textContent = device.name ? `${device.name} (${device.id})` : device.id;
      els.autoTriggerDevice.append(opt);
    });
    if (previous && triggerDevices.some((d) => d.id === previous)) {
      els.autoTriggerDevice.value = previous;
    } else {
      els.autoTriggerDevice.value = triggerDevices[0].id;
      state.automationForm.triggerDeviceId = triggerDevices[0].id;
    }
  }

  const lights = state.devices.filter((d) => d.device_type === "light");
  els.autoActionList.innerHTML = "";
  if (lights.length === 0) {
    els.autoActionList.innerHTML = `<div class="empty">No light devices</div>`;
  } else {
    lights.forEach((light) => {
      const id = `autoAct_${light.id}`;
      const row = document.createElement("label");
      row.className = "toggle-row";
      row.htmlFor = id;
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.id = id;
      checkbox.checked = state.automationForm.actionDeviceIds.has(light.id);
      checkbox.addEventListener("change", () => {
        if (checkbox.checked) state.automationForm.actionDeviceIds.add(light.id);
        else state.automationForm.actionDeviceIds.delete(light.id);
      });
      const span = document.createElement("span");
      span.textContent = light.name ? `${light.name} (${light.id})` : light.id;
      row.append(checkbox, span);
      els.autoActionList.append(row);
    });
  }
}

function renderAutomations() {
  const rules = state.automations;
  els.automationSummary.textContent = `${rules.length} rule${rules.length === 1 ? "" : "s"}`;
  els.automationList.innerHTML = "";
  if (rules.length === 0) {
    els.automationList.innerHTML = `<div class="empty">No automations defined</div>`;
    return;
  }
  rules.forEach((rule) => {
    const card = document.createElement("div");
    card.className = "automation-row";

    const head = document.createElement("div");
    head.className = "automation-head";
    const title = document.createElement("div");
    title.className = "automation-title";
    title.textContent = rule.name || rule.id;
    const meta = document.createElement("div");
    meta.className = "automation-meta";
    meta.append(automationStatusTag(rule.sync_status, "sync"));
    meta.append(automationStatusTag(rule.last_run_status, "run"));
    head.append(title, meta);

    const summary = document.createElement("div");
    summary.className = "automation-summary";
    summary.textContent = summarizeRule(rule);

    const actions = document.createElement("div");
    actions.className = "automation-actions";

    const toggleLabel = document.createElement("label");
    toggleLabel.className = "toggle-row";
    const toggle = document.createElement("input");
    toggle.type = "checkbox";
    toggle.checked = !!rule.enabled;
    toggle.addEventListener("change", () => toggleAutomation(rule, toggle.checked));
    const toggleSpan = document.createElement("span");
    toggleSpan.textContent = rule.enabled ? "Enabled" : "Disabled";
    toggleLabel.append(toggle, toggleSpan);

    const deleteBtn = document.createElement("button");
    deleteBtn.type = "button";
    deleteBtn.className = "icon-button danger";
    deleteBtn.textContent = "Delete";
    deleteBtn.addEventListener("click", () => deleteAutomation(rule));

    actions.append(toggleLabel, deleteBtn);
    card.append(head, summary, actions);
    els.automationList.append(card);
  });
}

function automationStatusTag(value, kind) {
  const text = value || (kind === "sync" ? "pending" : "never_run");
  const tone = (() => {
    if (kind === "sync") {
      if (text === "synced") return "ok";
      if (text === "failed") return "danger";
      return "warning";
    }
    if (text === "executed") return "ok";
    if (text === "failed" || text === "timeout") return "danger";
    return "muted";
  })();
  return tag(text.replace(/_/g, " "), tone);
}

function summarizeRule(rule) {
  const trig = rule.trigger || {};
  const acts = rule.actions || [];
  const triggerStr = trig.device_type === "switch"
    ? `Switch ${shortId(trig.device_id)} toggles`
    : `Motion ${shortId(trig.device_id)} ${(trig.state || {}).occupancy || ""}`.trim();
  const actsStr = acts
    .map((a) => `${a.command} ${shortId(a.device_id)}`)
    .join(", ");
  return `When ${triggerStr} → ${actsStr || "no actions"}`;
}

function shortId(value) {
  if (!value) return "?";
  return value.length > 8 ? `…${value.slice(-6)}` : value;
}

async function saveAutomation() {
  const tpl = AUTOMATION_TEMPLATES[state.automationForm.template];
  if (!tpl) return toast("Pick a template");
  const name = els.autoName.value.trim();
  if (!name) return toast("Rule name is required");
  const triggerDeviceId = state.automationForm.triggerDeviceId;
  if (!triggerDeviceId) return toast(`Pick a ${tpl.triggerType} device`);
  const lights = [...state.automationForm.actionDeviceIds];
  if (lights.length === 0) return toast("Pick at least one light");

  const body = {
    name,
    enabled: !!els.autoEnabled.checked,
    trigger: tpl.buildTrigger(triggerDeviceId),
    actions: lights.map((id) => ({
      device_id: id,
      device_type: "light",
      command: tpl.actionCommand,
    })),
  };

  try {
    const rule = await fetchJson("/api/automations", {
      method: "POST",
      body: JSON.stringify(body),
    });
    toast(`Rule created: ${rule.name}`);
    els.autoName.value = "";
    state.automationForm.actionDeviceIds.clear();
    await refreshAutomations();
    renderAutomationForm();
  } catch (error) {
    toast(cleanError(error));
  }
}

async function toggleAutomation(rule, enabled) {
  const action = enabled ? "enable" : "disable";
  try {
    const updated = await fetchJson(`/api/automations/${encodeURIComponent(rule.id)}/${action}`, {
      method: "POST",
    });
    toast(`Rule ${updated.enabled ? "enabled" : "disabled"}`);
    await refreshAutomations();
  } catch (error) {
    toast(cleanError(error));
    await refreshAutomations();
  }
}

async function deleteAutomation(rule) {
  const ok = window.confirm(`Delete automation "${rule.name}"?`);
  if (!ok) return;
  try {
    await fetchJson(`/api/automations/${encodeURIComponent(rule.id)}`, { method: "DELETE" });
    toast(`Rule deleted: ${rule.name}`);
    await refreshAutomations();
  } catch (error) {
    toast(cleanError(error));
  }
}

async function refreshAutomations() {
  try {
    state.automations = await fetchJson("/api/automations");
    renderAutomations();
  } catch (error) {
    toast(cleanError(error));
  }
}

async function createDeviceCommand(deviceId, body) {
  try {
    const command = await fetchJson(`/api/devices/${encodeURIComponent(deviceId)}/command`, {
      method: "POST",
      body: JSON.stringify(body),
    });
    await trackCommand(command);
    toast(`Command ${command.status}: ${command.id}`);
    // Refresh device state after a short delay to pick up changes
    setTimeout(async () => {
      try {
        const payload = await fetchJson(`/api/devices/${encodeURIComponent(deviceId)}/state`);
        state.deviceStates.set(deviceId, payload);
        renderDevices();
        renderDetail();
      } catch { /* state may not have updated yet */ }
    }, 2000);
  } catch (error) {
    toast(cleanError(error));
  }
}

async function openJoin() {
  const duration = Number(els.joinDurationInput.value || 180);
  await createGatewayCommand("open", {
    duration_sec: Math.max(1, Math.min(180, duration)),
    timeout_ms: 5000,
  });
}

async function closeJoin() {
  await createGatewayCommand("close", { timeout_ms: 5000 });
}

async function createGatewayCommand(action, body) {
  try {
    const gatewayId = encodeURIComponent(state.gatewayId);
    const command = await fetchJson(`/api/gateways/${gatewayId}/commissioning/${action}`, {
      method: "POST",
      body: JSON.stringify(body),
    });
    await trackCommand(command);
    toast(`Gateway command ${command.status}: ${command.id}`);
  } catch (error) {
    toast(cleanError(error));
  }
}

async function generateProvisioningLabel() {
  const body = {
    eui64: els.labelEui64Input.value.trim(),
    device_type: els.labelDeviceType.value,
  };
  const model = els.labelModelInput.value.trim();
  const installCode = els.labelInstallCodeInput.value.trim();
  if (model) body.model = model;
  if (installCode) body.install_code = installCode;

  try {
    const label = await fetchJson("/api/provisioning/labels", {
      method: "POST",
      body: JSON.stringify(body),
    });
    els.labelQrPreview.innerHTML = label.qr_svg;
    els.labelPayload.textContent = label.payload_json;
    els.labelInstallCodeInput.value = label.payload.install_code;
    toast("Provisioning QR label generated");
  } catch (error) {
    els.labelQrPreview.innerHTML = "";
    toast(cleanError(error));
  }
}

async function trackCommand(command) {
  state.selectedCommand = command;
  upsertCommand(command);
  renderCommands();
  els.commandPayload.textContent = prettyJson(command);
  if (!["executed", "failed", "timeout"].includes(command.status)) {
    setTimeout(() => refreshCommand(command.id, false), 1200);
  }
}

async function refreshCommand(commandId, notify) {
  try {
    const command = await fetchJson(`/api/commands/${encodeURIComponent(commandId)}`);
    state.selectedCommand = command;
    upsertCommand(command);
    renderCommands();
    els.commandPayload.textContent = prettyJson(command);
    if (notify) toast(`Command status: ${command.status}`);
    if (!["executed", "failed", "timeout"].includes(command.status)) {
      setTimeout(() => refreshCommand(command.id, false), 1600);
    }
  } catch (error) {
    if (notify) toast(cleanError(error));
  }
}

function upsertCommand(command) {
  const index = state.commands.findIndex((item) => item.id === command.id);
  if (index >= 0) state.commands[index] = command;
  else state.commands.unshift(command);
  state.commands = state.commands.slice(0, 12);
}

async function fetchJson(path, options = {}) {
  const headers = {
    "content-type": "application/json",
    ...(options.headers || {}),
  };
  if (state.token) {
    headers["authorization"] = `Bearer ${state.token}`;
  }
  const response = await fetch(`${state.apiBase}${path}`, {
    ...options,
    headers,
  });
  if (response.status === 401) {
    requireLogin();
    throw new Error("Unauthorized — please sign in again");
  }
  const text = await response.text();
  let payload = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = text;
    }
  }
  if (!response.ok) {
    const detail = payload && typeof payload === "object" ? payload.detail : payload;
    throw new Error(detail || `${response.status} ${response.statusText}`);
  }
  return payload;
}

function updateMetrics() {
  const online = state.devices.filter((device) => device.is_online).length;
  els.deviceCount.textContent = String(state.devices.length);
  els.onlineCount.textContent = String(online);
  els.eventCount.textContent = String(state.events.length);
}

function updateEventTypeFilter(events) {
  const current = els.eventTypeFilter.value;
  const types = [...new Set(events.map((event) => event.event_type).filter(Boolean))].sort();
  els.eventTypeFilter.innerHTML = `<option value="">All event types</option>`;
  types.forEach((type) => {
    const option = document.createElement("option");
    option.value = type;
    option.textContent = type;
    els.eventTypeFilter.append(option);
  });
  if (types.includes(current)) els.eventTypeFilter.value = current;
}

function setCommandControls(enabled) {
  [els.lightOnBtn, els.lightOffBtn, els.sendLevelBtn].forEach((button) => {
    button.disabled = !enabled;
  });
}

function setBusy(isBusy) {
  els.refreshBtn.disabled = isBusy;
  els.refreshBtn.textContent = isBusy ? "Loading" : "Refresh";
}

function markApi(label, type) {
  els.apiStatus.textContent = label;
  els.apiStatus.className = type;
}

function setDetailStatus(label, type) {
  els.detailStatus.textContent = label;
  els.detailStatus.className = `status-pill ${type}`;
}

function scheduleRefresh() {
  if (state.refreshTimer) clearInterval(state.refreshTimer);
  if (els.autoRefreshToggle.checked) {
    state.refreshTimer = setInterval(refreshAll, 5000);
  }
}

function selectedDevice() {
  return state.devices.find((device) => device.id === state.selectedDeviceId) || null;
}

function buildDeviceStateHint(device, stateInfo) {
  if (!stateInfo || stateInfo.error) return "";
  const s = stateInfo.state || stateInfo;
  if (device.device_type === "light") {
    const power = s.power === "on";
    const icon = power ? "&#9728;" : "&#9790;";
    const label = power ? "ON" : "OFF";
    const cls = power ? "state-hint on" : "state-hint off";
    return `<div class="${cls}">
      <span class="state-icon">${icon}</span>
      <span>${label}</span>
    </div>`;
  }
  if (device.device_type === "motion") {
    const occ = s.occupancy === "occupied";
    const icon = occ ? "&#9673;" : "&#9675;";
    const label = occ ? "Occupied" : "Unoccupied";
    const cls = occ ? "state-hint on" : "state-hint off";
    return `<div class="${cls}"><span class="state-icon">${icon}</span><span>${label}</span></div>`;
  }
  return "";
}

function buildLightStateVisual(stateData) {
  const s = stateData.state || stateData;
  const power = s.power === "on";
  const level = s.level != null ? s.level : 0;
  const pct = Math.round((level / 254) * 100);
  const reachable = s.reachable !== false;
  const reportedAt = stateData.reported_at || "";
  return `<div class="visual-state">
  <div class="visual-state-row">
    <div class="visual-power ${power ? "on" : "off"}">
      <span class="visual-power-icon">${power ? "&#9728;" : "&#9790;"}</span>
      <span class="visual-power-label">${power ? "ON" : "OFF"}</span>
    </div>
    <div class="visual-reachable ${reachable ? "" : "unreachable"}">
      ${reachable ? "Reachable" : "Unreachable"}
    </div>
  </div>
  ${reportedAt ? `<div class="visual-reported">Last reported: ${escapeHtml(reportedAt)}</div>` : ""}
  <details class="visual-raw"><summary>Raw JSON</summary><pre>${escapeHtml(prettyJson(stateData))}</pre></details>
</div>`;
}

function buildMotionStateVisual(stateData) {
  const s = stateData.state || stateData;
  const occ = s.occupancy === "occupied";
  const reachable = s.reachable !== false;
  const reportedAt = stateData.reported_at || "";
  return `<div class="visual-state">
  <div class="visual-state-row">
    <div class="visual-power ${occ ? "on" : "off"}">
      <span class="visual-power-icon">${occ ? "&#9673;" : "&#9675;"}</span>
      <span class="visual-power-label">${occ ? "Occupied" : "Unoccupied"}</span>
    </div>
    <div class="visual-reachable ${reachable ? "" : "unreachable"}">
      ${reachable ? "Reachable" : "Unreachable"}
    </div>
  </div>
  ${reportedAt ? `<div class="visual-reported">Last reported: ${escapeHtml(reportedAt)}</div>` : ""}
  <details class="visual-raw"><summary>Raw JSON</summary><pre>${escapeHtml(prettyJson(stateData))}</pre></details>
</div>`;
}

function tag(text, className = "") {
  const span = document.createElement("span");
  span.className = `tag ${className}`.trim();
  span.textContent = text;
  return span;
}

function statusBadge(status) {
  const type =
    status === "executed"
      ? "ok"
      : status === "failed" || status === "timeout"
        ? "danger"
        : "warning";
  return `<span class="status-pill ${type}">${escapeHtml(status || "unknown")}</span>`;
}

function prettyJson(value) {
  return JSON.stringify(value, null, 2);
}

function compactJson(value) {
  return JSON.stringify(value);
}

function formatClock(date) {
  return date.toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

function normalizeApiBase(value) {
  return value.trim().replace(/\/$/, "");
}

function defaultApiBase() {
  if (window.location.protocol === "file:") return "http://localhost:8000";
  return "";
}

function loadSetting(key, fallback) {
  return localStorage.getItem(`cloudOps.${key}`) ?? fallback;
}

function cleanError(error) {
  if (!error) return "Unknown error";
  return error.message || String(error);
}

function toast(message) {
  els.toast.textContent = message;
  els.toast.classList.add("show");
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => els.toast.classList.remove("show"), 3200);
}

function debounce(fn, ms) {
  let timer = null;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), ms);
  };
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function byId(id) {
  return document.getElementById(id);
}
