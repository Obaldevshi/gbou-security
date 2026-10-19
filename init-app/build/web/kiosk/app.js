"use strict";

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const POLL_INTERVAL_MS = 3000;
const UPDATE_CHECK_INTERVAL_MS = 60000;
const KIOSK_UI_VERSION = globalThis.GBOU_KIOSK_UI_VERSION || "unknown";
const state = {
  token: sessionStorage.getItem("guard_token") || "",
  userName: sessionStorage.getItem("guard_name") || "",
  tab: "queue",
  requests: [],
  history: [],
  releasing: new Set(),
  poll: null,
  activeInput: null,
  language: "ru",
  shift: false,
  symbols: false,
};

const reasonLabels = {
  parent_note: "По заявлению родителя",
  health: "По состоянию здоровья",
  other: "Другая причина",
};

async function request(path, options = {}) {
  const { timeoutMs = 10000, ...fetchOptions } = options;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  const headers = { Accept: "application/json", ...(options.headers || {}) };
  if (options.body) headers["Content-Type"] = "application/json";
  if (state.token) headers.Authorization = `Bearer ${state.token}`;
  try {
    const response = await fetch(path, { ...fetchOptions, headers, signal: controller.signal });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      const failure = new Error(data.message || data.detail || "Не удалось выполнить действие");
      failure.status = response.status;
      throw failure;
    }
    return data;
  } catch (error) {
    if (error.name === "AbortError") {
      const failure = new Error("Сервер отвечает слишком долго");
      failure.isTimeout = true;
      throw failure;
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

function showLogin() {
  clearTimeout(state.poll);
  state.poll = null;
  hideKeyboard();
  document.body.classList.add("login-mode");
  $("#guard-view").classList.add("hidden");
  $("#login-view").classList.remove("hidden");
}

function showGuard() {
  document.body.classList.remove("login-mode");
  $("#login-view").classList.add("hidden");
  $("#guard-view").classList.remove("hidden");
  $("#guard-name").textContent = state.userName || "Очередь выхода";
  clearTimeout(state.poll);
  state.poll = null;
  refreshRequests().finally(scheduleRefresh);
}

function scheduleRefresh() {
  clearTimeout(state.poll);
  state.poll = null;
  if (!state.token) return;
  state.poll = setTimeout(async () => {
    state.poll = null;
    await refreshRequests();
    scheduleRefresh();
  }, POLL_INTERVAL_MS);
}

async function checkUiUpdate() {
  try {
    const response = await fetch("/local/version", { cache: "no-store" });
    if (!response.ok) return;
    const data = await response.json();
    if (data.version && data.version !== "unknown" && data.version !== KIOSK_UI_VERSION) {
      window.location.reload();
    }
  } catch (_) {
    // The cached local interface remains usable while update checks are offline.
  }
}

$("#login-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const button = $("#login-button");
  const error = $("#login-error");
  error.textContent = "";
  button.disabled = true;
  button.textContent = "Вход…";
  try {
    const response = await request("/api/login", {
      method: "POST",
      body: JSON.stringify({ login: $("#login").value.trim(), password: $("#password").value }),
    });
    const session = response.data || {};
    if (session.user?.role !== "guard") throw new Error("На этом устройстве разрешён только вход охранника");
    state.token = session.access_token;
    state.userName = session.user.full_name || "Пост охраны";
    sessionStorage.setItem("guard_token", state.token);
    sessionStorage.setItem("guard_name", state.userName);
    $("#password").value = "";
    hideKeyboard();
    showGuard();
  } catch (failure) {
    error.textContent = failure.message;
  } finally {
    button.disabled = false;
    button.textContent = "Войти";
  }
});

$("#toggle-password").addEventListener("click", () => {
  const field = $("#password");
  field.type = field.type === "password" ? "text" : "password";
  $("#toggle-password").setAttribute("aria-label", field.type === "password" ? "Показать пароль" : "Скрыть пароль");
});

$("#logout").addEventListener("click", () => {
  state.token = "";
  state.userName = "";
  sessionStorage.clear();
  showLogin();
});

async function refreshRequests() {
  if (!state.token) return;
  const status = $("#connection-state");
  try {
    const [queue, history] = await Promise.all([
      request("/api/queue"),
      state.tab === "history" ? request("/api/history") : Promise.resolve(null),
    ]);
    state.requests = (queue.data || []).filter(
      (item) => !state.releasing.has(String(item.id)),
    );
    if (history) state.history = history.data || [];
    $("#queue-count").textContent = String(state.requests.length);
    status.textContent = `Обновлено ${new Date().toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit", second: "2-digit" })}`;
    status.className = "message success";
    renderRequests();
  } catch (failure) {
    status.textContent = failure.message;
    status.className = "message error";
    if (/сесс|вход|авториз/i.test(failure.message)) {
      state.token = "";
      sessionStorage.clear();
      showLogin();
    }
  }
}

function renderRequests() {
  const query = $("#search").value.trim().toLocaleLowerCase("ru-RU");
  const source = state.tab === "queue" ? state.requests : state.history;
  const items = source.filter((item) =>
    `${item.student_full_name} ${item.class_name} ${item.teacher_full_name}`.toLocaleLowerCase("ru-RU").includes(query),
  );
  const list = $("#request-list");
  list.replaceChildren();
  if (!items.length) {
    const empty = document.createElement("div");
    empty.className = "empty";
    empty.textContent = query ? "Ничего не найдено" : state.tab === "queue" ? "Сейчас никто не ожидает выхода" : "История пока пуста";
    list.append(empty);
    return;
  }
  for (const item of items) list.append(requestCard(item));
}

function requestCard(item) {
  const article = document.createElement("article");
  article.className = "request-card";
  const info = document.createElement("div");
  const title = document.createElement("h2");
  title.textContent = item.student_full_name;
  const meta = document.createElement("p");
  meta.textContent = `${item.class_name} · ${formatTime(item.scheduled_at)}`;
  const reason = document.createElement("p");
  reason.textContent = `Причина: ${item.custom_reason || reasonLabels[item.reason_type] || "Не указана"}`;
  const teacher = document.createElement("p");
  teacher.textContent = `Учитель: ${item.teacher_full_name}`;
  info.append(title, meta, reason, teacher);
  article.append(info);
  if (state.tab === "queue") {
    const release = document.createElement("button");
    release.className = "primary release";
    release.type = "button";
    release.textContent = "Отпустить";
    release.addEventListener("click", () => releaseRequest(item.id));
    article.append(release);
  } else {
    const released = document.createElement("strong");
    released.textContent = `Выпущен ${formatTime(item.released_at)}`;
    article.append(released);
  }
  return article;
}

async function releaseRequest(id) {
  const releaseId = String(id);
  if (state.releasing.has(releaseId)) return;
  const previousRequests = state.requests;
  state.releasing.add(releaseId);
  state.requests = state.requests.filter((item) => String(item.id) !== releaseId);
  $("#queue-count").textContent = String(state.requests.length);
  renderRequests();
  try {
    await request(`/api/requests/${id}/release`, { method: "POST", body: "{}" });
    await refreshRequests();
  } catch (failure) {
    state.requests = previousRequests;
    $("#queue-count").textContent = String(state.requests.length);
    renderRequests();
    $("#connection-state").textContent = failure.message;
    $("#connection-state").className = "message error";
  } finally {
    state.releasing.delete(releaseId);
  }
}

function formatTime(value) {
  if (!value) return "—";
  return new Date(value).toLocaleString("ru-RU", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });
}

$$('[data-tab]').forEach((button) => button.addEventListener("click", async () => {
  state.tab = button.dataset.tab;
  $$('[data-tab]').forEach((item) => item.classList.toggle("active", item === button));
  if (state.tab === "history") await refreshRequests();
  else renderRequests();
}));
$("#search").addEventListener("input", renderRequests);
$("#refresh").addEventListener("click", refreshRequests);

const guardView = $("#guard-view");
const dragScroll = { pointerId: null, startY: 0, lastY: 0, moved: false };

guardView.addEventListener("pointerdown", (event) => {
  if (!event.isPrimary || (event.pointerType === "mouse" && event.button !== 0)) return;
  if (event.target.closest("button, input, select, textarea, a, label")) return;
  dragScroll.pointerId = event.pointerId;
  dragScroll.startY = event.clientY;
  dragScroll.lastY = event.clientY;
  dragScroll.moved = false;
  guardView.setPointerCapture?.(event.pointerId);
  event.preventDefault();
});

guardView.addEventListener("pointermove", (event) => {
  if (event.pointerId !== dragScroll.pointerId) return;
  const delta = event.clientY - dragScroll.lastY;
  if (Math.abs(event.clientY - dragScroll.startY) > 4) {
    dragScroll.moved = true;
    guardView.classList.add("dragging");
    globalThis.getSelection?.()?.removeAllRanges();
  }
  if (dragScroll.moved) {
    guardView.scrollTop -= delta;
    event.preventDefault();
  }
  dragScroll.lastY = event.clientY;
}, { passive: false });

function finishDragScroll(event) {
  if (event.pointerId !== dragScroll.pointerId) return;
  if (guardView.hasPointerCapture?.(event.pointerId)) {
    guardView.releasePointerCapture(event.pointerId);
  }
  dragScroll.pointerId = null;
  dragScroll.moved = false;
  guardView.classList.remove("dragging");
}

guardView.addEventListener("pointerup", finishDragScroll);
guardView.addEventListener("pointercancel", finishDragScroll);

const layouts = {
  ru: ["1234567890", "йцукенгшщзхъ", "фывапролджэ", "ячсмитьбю"],
  en: ["1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm"],
  symbols: ["1234567890", "!@#$%^&*()_+", "-=[]{};:'\"", ",.<>/?\\|`~="],
};

function showKeyboard(input) {
  if (!input) return;
  state.activeInput = input;
  $("#keyboard").classList.remove("hidden");
  document.body.classList.add("keyboard-open");
  $("#keyboard-toggle").setAttribute("aria-expanded", "true");
  renderKeyboard();
  input.focus({ preventScroll: true });
  input.scrollIntoView({ block: "nearest" });
}

function hideKeyboard() {
  $("#keyboard").classList.add("hidden");
  document.body.classList.remove("keyboard-open");
  $("#keyboard-toggle").setAttribute("aria-expanded", "false");
}

function renderKeyboard() {
  const container = $("#keyboard-keys");
  container.replaceChildren();
  for (const rowText of layouts[state.symbols ? "symbols" : state.language]) {
    const row = document.createElement("div");
    row.className = "keyboard-row";
    for (const original of rowText) {
      const key = document.createElement("button");
      const value = state.shift ? original.toLocaleUpperCase(state.language === "ru" ? "ru-RU" : "en-US") : original;
      key.type = "button";
      key.textContent = value;
      key.addEventListener("pointerdown", (event) => {
        event.preventDefault();
        insertAtCursor(value);
      });
      row.append(key);
    }
    container.append(row);
  }
}

function insertAtCursor(text) {
  const input = state.activeInput;
  if (!input) return;
  const start = input.selectionStart ?? input.value.length;
  const end = input.selectionEnd ?? start;
  input.setRangeText(text, start, end, "end");
  input.dispatchEvent(new Event("input", { bubbles: true }));
  input.focus();
}

// Focus selects the input; only the explicit toolbar button opens the keyboard.
// inputmode=none prevents a second OS keyboard on touch browsers. Physical
// keyboards still work, and no browser/desktop accessibility setting is changed.
$$('[data-keyboard]').forEach((input) => {
  input.setAttribute("inputmode", "none");
  input.addEventListener("focus", () => { state.activeInput = input; });
});
$("#keyboard-toggle").addEventListener("pointerdown", (event) => event.preventDefault());
$("#keyboard-toggle").addEventListener("click", () => {
  if (!$("#keyboard").classList.contains("hidden")) { hideKeyboard(); return; }
  const dialog = $$(".modal").find((item) => !item.classList.contains("hidden"));
  const scope = dialog || $(state.token ? "#guard-view" : "#login-view");
  const available = [...scope.querySelectorAll("[data-keyboard]")].filter(
    (input) => !input.disabled && input.getClientRects().length > 0,
  );
  showKeyboard(available.includes(state.activeInput) ? state.activeInput : available[0]);
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") hideKeyboard();
});
$("#keyboard").addEventListener("pointerdown", (event) => {
  event.preventDefault();
  const action = event.target.dataset.action;
  if (!action) return;
  if (action === "lang") { state.language = state.language === "ru" ? "en" : "ru"; state.symbols = false; renderKeyboard(); }
  if (action === "shift") { state.shift = !state.shift; renderKeyboard(); }
  if (action === "symbols") { state.symbols = !state.symbols; renderKeyboard(); }
  if (action === "space") insertAtCursor(" ");
  if (action === "backspace" && state.activeInput) {
    const input = state.activeInput;
    const start = input.selectionStart ?? input.value.length;
    const end = input.selectionEnd ?? start;
    if (start !== end) input.setRangeText("", start, end, "end");
    else if (start > 0) input.setRangeText("", start - 1, start, "end");
    input.dispatchEvent(new Event("input", { bubbles: true }));
    input.focus();
  }
  if (action === "hide") hideKeyboard();
});

async function openWifi() {
  hideKeyboard();
  $("#wifi-dialog").classList.remove("hidden");
  await loadWifi();
}

async function loadWifi() {
  const status = $("#wifi-status");
  status.textContent = "Поиск сетей…";
  status.className = "message";
  try {
    const data = await request("/local/wifi/networks");
    const list = $("#wifi-list");
    list.replaceChildren();
    for (const network of data.networks || []) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `wifi-network${network.active ? " active" : ""}`;
      button.innerHTML = `<span></span><strong>${network.signal}% ${network.secure ? "🔒" : ""}</strong>`;
      button.querySelector("span").textContent = network.ssid;
      button.addEventListener("click", () => { $("#wifi-ssid").value = network.ssid; });
      list.append(button);
    }
    const active = (data.networks || []).find((item) => item.active);
    status.textContent = active ? `Подключено: ${active.ssid}` : "Выберите доступную сеть";
    status.className = `message ${active ? "success" : ""}`;
  } catch (failure) {
    status.textContent = failure.message;
    status.className = "message error";
  }
}

$("#wifi-open").addEventListener("click", openWifi);
$("#wifi-open-guard").addEventListener("click", openWifi);
$("#wifi-dialog form").addEventListener("submit", (event) => event.preventDefault());
$("#wifi-close").addEventListener("click", () => {
  hideKeyboard();
  $("#wifi-password").value = "";
  $("#wifi-dialog").classList.add("hidden");
});
$("#wifi-rescan").addEventListener("click", loadWifi);
$("#wifi-connect").addEventListener("click", async () => {
  const status = $("#wifi-status");
  status.textContent = "Подключение…";
  try {
    const data = await request("/local/wifi/connect", {
      method: "POST",
      body: JSON.stringify({ ssid: $("#wifi-ssid").value, password: $("#wifi-password").value }),
    });
    $("#wifi-password").value = "";
    status.textContent = data.message;
    status.className = "message success";
    setTimeout(loadWifi, 1500);
  } catch (failure) {
    status.textContent = failure.message;
    status.className = "message error";
  }
});

setInterval(() => { $("#clock").textContent = new Date().toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit" }); }, 1000);
setTimeout(checkUiUpdate, 5000);
setInterval(checkUiUpdate, UPDATE_CHECK_INTERVAL_MS);
window.addEventListener("online", () => state.token && refreshRequests());
document.addEventListener("visibilitychange", () => !document.hidden && state.token && refreshRequests());
if (state.token) showGuard(); else showLogin();

let deviceTimer = null;
let deviceSubmitting = false;
const deviceBusyPhases = new Set(["preparing", "qr", "restoring", "ready_for_activation", "starting"]);

async function loadDeviceSettings(autoOpen = false) {
  clearTimeout(deviceTimer);
  deviceTimer = null;
  try {
    const data = await request("/local/device");
    if (deviceBusyPhases.has(data.phase)) {
      // A reboot or a UI update must not lose the current QR/status dialog.
      state.token = "";
      sessionStorage.removeItem("guard_token");
      sessionStorage.removeItem("guard_name");
      showLogin();
      if (autoOpen) $("#device-dialog").classList.remove("hidden");
    }
    $("#device-address").textContent = data.hostname ? `Школьный адрес: https://${data.hostname}` : "";
    $("#device-status").textContent = data.message || "";
    $("#device-status").className = `message ${data.phase === "error" ? "error" : ""}`;
    $("#device-form").classList.toggle("hidden", !["idle", "completed"].includes(data.phase));
    const hasQr = data.phase === "qr" && /^[A-Za-z0-9+/=]+$/.test(data.qr || "") && /^[0-9]{6}$/.test(data.code || "");
    $("#device-qr").classList.toggle("hidden", !hasQr);
    if (hasQr) {
      $("#device-qr-image").src = `data:image/svg+xml;base64,${data.qr}`;
      $("#device-code").textContent = data.code;
    } else {
      $("#device-qr-image").removeAttribute("src");
      $("#device-code").textContent = "";
    }
    if (!$("#device-dialog").classList.contains("hidden") && deviceBusyPhases.has(data.phase)) {
      deviceTimer = setTimeout(() => loadDeviceSettings(), 3000);
    }
  } catch (error) {
    $("#device-status").textContent = error.status === 404
      ? "Для этой функции нужно однократно обновить локальную службу киоска. Данные и привязка не изменены."
      : error.message;
    $("#device-status").className = "message error";
    $("#device-form").classList.add("hidden");
    if (!$("#device-dialog").classList.contains("hidden")) deviceTimer = setTimeout(() => loadDeviceSettings(), 5000);
  }
}

$("#device-open").addEventListener("click", () => {
  hideKeyboard();
  // The toolbar remains accessible above dialogs. Never stack two modal forms.
  $("#wifi-dialog").classList.add("hidden");
  $("#wifi-password").value = "";
  $("#device-dialog").classList.remove("hidden");
  loadDeviceSettings();
});
$("#device-close").addEventListener("click", () => {
  if (deviceSubmitting) return;
  clearTimeout(deviceTimer);
  hideKeyboard();
  $("#device-password").value = "";
  $("#device-confirmation").value = "";
  $("#device-dialog").classList.add("hidden");
});
$("#device-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  if (deviceSubmitting) return;
  deviceSubmitting = true;
  $("#device-submit").disabled = true;
  $("#device-close").disabled = true;
  try {
    $("#device-status").textContent = "Проверяем полномочия администратора…";
    await request("/local/device/rebind", {
      method: "POST", timeoutMs: 65000,
      headers: { "X-GBOU-Local-Action": "device-rebind" },
      body: JSON.stringify({login: $("#device-login").value.trim(), password: $("#device-password").value, confirmation: $("#device-confirmation").value.trim()}),
    });
    // Machine rebind must not carry the guard's browser session into a new one.
    state.token = "";
    state.userName = "";
    sessionStorage.removeItem("guard_token");
    sessionStorage.removeItem("guard_name");
    showLogin();
    await loadDeviceSettings();
  } catch (error) {
    $("#device-status").textContent = error.message;
    $("#device-status").className = "message error";
    if (error.isTimeout) deviceTimer = setTimeout(() => loadDeviceSettings(), 3000);
  } finally {
    $("#device-password").value = "";
    $("#device-confirmation").value = "";
    deviceSubmitting = false;
    $("#device-submit").disabled = false;
    $("#device-close").disabled = false;
  }
});
loadDeviceSettings(true);
// Optional setup package: never expose setup on an existing school writer.
request('/local/pairing').then((data) => {
  if (data.available) document.querySelector('#pairing-open')?.classList.remove('hidden');
}).catch(() => {});
