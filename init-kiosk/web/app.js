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
  poll: null,
  activeInput: null,
  language: "ru",
  shift: false,
};

const reasonLabels = {
  parent_note: "По заявлению родителя",
  health: "По состоянию здоровья",
  other: "Другая причина",
};

async function request(path, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  const headers = { Accept: "application/json", ...(options.headers || {}) };
  if (options.body) headers["Content-Type"] = "application/json";
  if (state.token) headers.Authorization = `Bearer ${state.token}`;
  try {
    const response = await fetch(path, { ...options, headers, signal: controller.signal });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.message || data.detail || "Не удалось выполнить действие");
    return data;
  } catch (error) {
    if (error.name === "AbortError") throw new Error("Сервер отвечает слишком долго");
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

function showLogin() {
  clearTimeout(state.poll);
  state.poll = null;
  $("#guard-view").classList.add("hidden");
  $("#login-view").classList.remove("hidden");
}

function showGuard() {
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
    state.requests = queue.data || [];
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
    release.addEventListener("click", () => releaseRequest(item.id, release));
    article.append(release);
  } else {
    const released = document.createElement("strong");
    released.textContent = `Выпущен ${formatTime(item.released_at)}`;
    article.append(released);
  }
  return article;
}

async function releaseRequest(id, button) {
  if (!confirm("Подтвердить выход ученика?")) return;
  button.disabled = true;
  button.textContent = "Сохраняю…";
  try {
    await request(`/api/requests/${id}/release`, { method: "POST", body: "{}" });
    await refreshRequests();
  } catch (failure) {
    $("#connection-state").textContent = failure.message;
    $("#connection-state").className = "message error";
  } finally {
    button.disabled = false;
    button.textContent = "Отпустить";
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

const layouts = {
  ru: ["1234567890", "йцукенгшщзхъ", "фывапролджэ", "ячсмитьбю"],
  en: ["1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm"],
};

function showKeyboard(input) {
  state.activeInput = input;
  $("#keyboard").classList.remove("hidden");
  document.body.classList.add("keyboard-open");
  renderKeyboard();
}

function hideKeyboard() {
  $("#keyboard").classList.add("hidden");
  document.body.classList.remove("keyboard-open");
  state.activeInput = null;
}

function renderKeyboard() {
  const container = $("#keyboard-keys");
  container.replaceChildren();
  for (const rowText of layouts[state.language]) {
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

$$('[data-keyboard]').forEach((input) => input.addEventListener("focus", () => showKeyboard(input)));
$("#keyboard").addEventListener("pointerdown", (event) => {
  event.preventDefault();
  const action = event.target.dataset.action;
  if (!action) return;
  if (action === "lang") { state.language = state.language === "ru" ? "en" : "ru"; renderKeyboard(); }
  if (action === "shift") { state.shift = !state.shift; renderKeyboard(); }
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
