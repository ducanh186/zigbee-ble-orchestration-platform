const DEFAULT_GATEWAY_ID = "gw-ubuntu-01";
const DEFAULT_TARGET = {
  endpoint: 1,
  cluster_id: "0x0006",
  command: "on",
};

const state = {
  apiBase: loadSetting("apiBase", defaultApiBase()),
  gatewayId: loadSetting("gatewayId", DEFAULT_GATEWAY_ID),
  devices: [],
  deviceStates: new Map(),
  selectedDeviceId: null,
  events: [],
  commands: [],
  selectedCommand: null,
  deviceFilter: "all",
  refreshTimer: null,
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
  gatewayMeta: byId("gatewayMeta"),
  openJoinBtn: byId("openJoinBtn"),
  closeJoinBtn: byId("closeJoinBtn"),
  activitySummary: byId("activitySummary"),
  eventTypeFilter: byId("eventTypeFilter"),
  deviceFilterInput: byId("deviceFilterInput"),
  autoRefreshToggle: byId("autoRefreshToggle"),
  eventTableBody: byId("eventTableBody"),
  commandSummary: byId("commandSummary"),
  commandList: byId("commandList"),
  commandPayload: byId("commandPayload"),
  toast: byId("toast"),
};

init();

function init() {
  els.apiBaseInput.value = state.apiBase;
  els.gatewayIdInput.value = state.gatewayId;
  els.rawTargetInput.value = JSON.stringify(DEFAULT_TARGET, null, 2);
  els.gatewayMeta.textContent = state.gatewayId;
  bindEvents();
  refreshAll();
  scheduleRefresh();
}

function bindEvents() {
  els.saveSettingsBtn.addEventListener("click", saveSettings);
  els.refreshBtn.addEventListener("click", refreshAll);
  els.levelSlider.addEventListener("input", () => {
    els.levelOutput.value = els.levelSlider.value;
  });
  els.lightOnBtn.addEventListener("click", () => sendLightPower("on"));
  els.lightOffBtn.addEventListener("click", () => sendLightPower("off"));
  els.sendLevelBtn.addEventListener("click", sendLightLevel);
  els.sendRawBtn.addEventListener("click", sendRawTarget);
  els.openJoinBtn.addEventListener("click", openJoin);
  els.closeJoinBtn.addEventListener("click", closeJoin);
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
    const [health, devices, events] = await Promise.all([
      fetchJson("/health").catch((error) => ({ error })),
      fetchJson("/api/devices/").catch((error) => ({ error })),
      loadEvents().catch((error) => ({ error })),
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
    }

    if (!events.error) {
      state.events = events;
      renderEvents();
      updateEventTypeFilter(events);
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
    main.innerHTML = `
      <div class="device-name">${escapeHtml(device.name || device.id)}</div>
      <div class="device-id">${escapeHtml(device.id)}</div>
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
    return;
  }

  const currentState = state.deviceStates.get(device.id);
  els.detailTitle.textContent = device.name || device.id;
  els.detailMeta.textContent = `${device.device_type} / ${device.id}`;
  els.statePayload.textContent = prettyJson(currentState || {});
  setDetailStatus(device.is_online ? "Online" : "Offline", device.is_online ? "ok" : "danger");
  setCommandControls(device.device_type === "light");
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

async function createDeviceCommand(deviceId, body) {
  try {
    const command = await fetchJson(`/api/devices/${encodeURIComponent(deviceId)}/command`, {
      method: "POST",
      body: JSON.stringify(body),
    });
    await trackCommand(command);
    toast(`Command ${command.status}: ${command.id}`);
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
  const response = await fetch(`${state.apiBase}${path}`, {
    ...options,
    headers: {
      "content-type": "application/json",
      ...(options.headers || {}),
    },
  });
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
