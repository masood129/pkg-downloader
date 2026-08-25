// Bilingual Dictionary
const I18N = {
  fa: {
    app_title: "دانلود پکیج‌های لینوکس (با وابستگی‌های کامل)",
    app_subtitle: "دانلود تمام وابستگی‌های تو در تو برای نصب کاملاً آفلاین در قالب ZIP",
    open_folder: "پوشه خروجی",
    section_system: "سیستم عامل و توزیع هدف",
    lbl_distro: "توزیع لینوکس",
    lbl_release: "نسخه توزیع",
    lbl_arch: "معماری پردازنده",
    lbl_format: "فرمت فایل خروجی",
    section_package: "مشخصات پکیج",
    lbl_pkg_name: "نام پکیج مورد نظر",
    help_pkg_name: "نام پکیجی که می‌خواهید با تمام نیازمندی‌هایش دانلود شود.",
    btn_check_ver: "بررسی نسخه‌ها",
    lbl_pkg_version: "نسخه پکیج (انتخاب نسخه)",
    opt_latest_ver: "آخرین نسخه موجود (پیش‌فرض)",
    lbl_dep_options: "گزینه‌های دانلود وابستگی",
    chk_recommends: "شامل Recommends",
    chk_suggests: "شامل Suggests",
    section_repos: "مخازن و میرورها (Repositories)",
    lbl_mirror: "انتخاب سرور دانلود (Mirror)",
    lbl_custom_mirror: "آدرس میرور دلخواه",
    lbl_components: "شاخه‌ها و بخش‌های مخزن (Components)",
    lbl_extra_repo: "مخزن یا PPA اضافی (اختیاری)",
    btn_start_download: "شروع دانلود و ساخت بسته آفلاین",
    btn_cancel: "لغو فرآیند",
    status_idle: "آماده به کار",
    status_running: "در حال دانلود و پردازش...",
    status_completed: "تکمیل شد",
    status_failed: "خطا در عملیات",
    status_cancelled: "لغو شد",
    title_success: "بسته آفلاین با موفقیت ساخته شد!",
    btn_save_file: "دانلود فایل فشرده",
    btn_show_folder: "مشاهده در پوشه سیستم",
    section_files: "بسته‌های دانلود شده",
    th_file: "نام فایل",
    th_size: "حجم",
    th_date: "تاریخ",
    th_actions: "عملیات",
    btn_download: "دانلود",
    btn_delete: "حذف",
    toast_copied: "مسیر در کلیپ‌بورد کپی شد",
    toast_deleted: "فایل با موفقیت حذف شد",
    no_files: "هنوز هیچ بسته‌ای دانلود نشده است.",
    querying_versions: "در حال استعلام نسخه‌ها از مخازن...",
    versions_found: "نسخه در مخازن یافت شد. می‌توانید انتخاب کنید.",
    versions_not_found: "پکیج در این مخزن یافت نشد.",
    enter_pkg_name: "لطفاً ابتدا نام پکیج را وارد کنید.",
    version_hint_tpl: "تعداد {n} نسخه موجود است. نسخه مورد نظر خود را انتخاب کنید."
  },
  en: {
    app_title: "Offline Linux Package Downloader",
    app_subtitle: "Download packages with all recursive dependencies as offline ZIP bundles",
    open_folder: "Open Folder",
    section_system: "Target Operating System",
    lbl_distro: "Linux Distribution",
    lbl_release: "Distribution Release",
    lbl_arch: "Architecture",
    lbl_format: "Output Archive Format",
    section_package: "Package Configuration",
    lbl_pkg_name: "Package Name",
    help_pkg_name: "The package to download with all its recursive dependencies.",
    btn_check_ver: "Check Versions",
    lbl_pkg_version: "Package Version (Select Version)",
    opt_latest_ver: "Latest Available (Default)",
    lbl_dep_options: "Dependency Options",
    chk_recommends: "Include Recommends",
    chk_suggests: "Include Suggests",
    section_repos: "Repositories & Mirrors",
    lbl_mirror: "Download Mirror",
    lbl_custom_mirror: "Custom Mirror URL",
    lbl_components: "Repository Components",
    lbl_extra_repo: "Extra Repository / PPA (Optional)",
    btn_start_download: "Start Download & Build Bundle",
    btn_cancel: "Cancel",
    status_idle: "Idle",
    status_running: "Downloading and resolving...",
    status_completed: "Completed",
    status_failed: "Failed",
    status_cancelled: "Cancelled",
    title_success: "Offline Bundle Ready!",
    btn_save_file: "Download File",
    btn_show_folder: "Show in System Folder",
    section_files: "Downloaded Bundles",
    th_file: "File Name",
    th_size: "Size",
    th_date: "Date",
    th_actions: "Actions",
    btn_download: "Download",
    btn_delete: "Delete",
    toast_copied: "Path copied to clipboard",
    toast_deleted: "File deleted successfully",
    no_files: "No offline bundles downloaded yet.",
    querying_versions: "Querying available versions from repos...",
    versions_found: "versions found. You can pick your desired version.",
    versions_not_found: "Package not found in repositories.",
    enter_pkg_name: "Please enter a package name first.",
    version_hint_tpl: "{n} versions available. Select your desired version below."
  }
};

let currentLang = 'fa';
let distrosData = {};
let activeJobId = null;
let eventSource = null;

// DOM Elements
const distroSelect = document.getElementById('distroSelect');
const releaseSelect = document.getElementById('releaseSelect');
const archSelect = document.getElementById('archSelect');
const formatSelect = document.getElementById('formatSelect');
const pkgInput = document.getElementById('pkgInput');
const checkVersionBtn = document.getElementById('checkVersionBtn');
const versionSelect = document.getElementById('versionSelect');
const versionBadge = document.getElementById('versionBadge');
const versionHint = document.getElementById('versionHint');
const chkRecommends = document.getElementById('chkRecommends');
const chkSuggests = document.getElementById('chkSuggests');
const mirrorSelect = document.getElementById('mirrorSelect');
const customMirrorGroup = document.getElementById('customMirrorGroup');
const customMirrorInput = document.getElementById('customMirrorInput');
const componentsGrid = document.getElementById('componentsGrid');
const extraRepoInput = document.getElementById('extraRepoInput');
const startDownloadBtn = document.getElementById('startDownloadBtn');
const cancelBtn = document.getElementById('cancelBtn');
const terminalBody = document.getElementById('terminalBody');
const statusIndicator = document.getElementById('statusIndicator');
const statusText = document.getElementById('statusText');
const resultCard = document.getElementById('resultCard');
const resultDetails = document.getElementById('resultDetails');
const downloadResultBtn = document.getElementById('downloadResultBtn');
const showInFolderBtn = document.getElementById('showInFolderBtn');
const filesTableBody = document.getElementById('filesTableBody');
const refreshFilesBtn = document.getElementById('refreshFilesBtn');
const openFolderBtn = document.getElementById('openFolderBtn');
const langToggle = document.getElementById('langToggle');
const themeToggle = document.getElementById('themeToggle');

// Initialize
document.addEventListener('DOMContentLoaded', async () => {
  setupLanguage(currentLang);
  setupTheme();
  await loadDistros();
  await loadFiles();
  setupEventListeners();
});

// Setup Language
function setupLanguage(lang) {
  currentLang = lang;
  document.documentElement.lang = lang;
  document.body.dir = lang === 'fa' ? 'rtl' : 'ltr';
  document.getElementById('langText').textContent = lang === 'fa' ? 'English' : 'فارسی';

  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (I18N[lang][key]) {
      el.textContent = I18N[lang][key];
    }
  });

  document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
    const key = el.getAttribute('data-i18n-placeholder');
    if (I18N[lang][key]) {
      el.placeholder = I18N[lang][key];
    }
  });
}

// Setup Theme
function setupTheme() {
  const saved = localStorage.getItem('theme') || 'dark';
  document.body.setAttribute('data-theme', saved);
  document.getElementById('themeText').textContent = saved === 'dark' ? '☀️' : '🌙';
}

function toggleTheme() {
  const current = document.body.getAttribute('data-theme');
  const next = current === 'dark' ? 'light' : 'dark';
  document.body.setAttribute('data-theme', next);
  localStorage.setItem('theme', next);
  document.getElementById('themeText').textContent = next === 'dark' ? '☀️' : '🌙';
}

// Load Distros Metadata from API
async function loadDistros() {
  try {
    const res = await fetch('/api/distros');
    distrosData = await res.json();
    updateDistroUI();
  } catch (err) {
    showToast('Failed to load distro data: ' + err.message, 'error');
  }
}

// Update Distro UI based on selected distro
function updateDistroUI() {
  const selectedDistro = distroSelect.value;
  const data = distrosData[selectedDistro];
  if (!data) return;

  // 1. Populate Releases
  releaseSelect.innerHTML = '';
  data.releases.forEach(r => {
    const opt = document.createElement('option');
    opt.value = r.id;
    opt.textContent = r.name;
    if (r.id === data.default_release) opt.selected = true;
    releaseSelect.appendChild(opt);
  });

  // 2. Populate Mirrors
  mirrorSelect.innerHTML = '';
  data.mirrors.forEach(m => {
    const opt = document.createElement('option');
    opt.value = m.url;
    opt.dataset.id = m.id;
    opt.textContent = m.name;
    if (m.url === data.default_mirror) opt.selected = true;
    mirrorSelect.appendChild(opt);
  });
  handleMirrorChange();

  // 3. Populate Components
  componentsGrid.innerHTML = '';
  data.components.forEach(c => {
    const lbl = document.createElement('label');
    lbl.className = `checkbox-label ${c.default ? 'checked' : ''}`;
    
    const input = document.createElement('input');
    input.type = 'checkbox';
    input.value = c.id;
    input.checked = c.default;
    input.addEventListener('change', () => {
      lbl.classList.toggle('checked', input.checked);
    });

    const span = document.createElement('span');
    span.textContent = c.name;

    lbl.appendChild(input);
    lbl.appendChild(span);
    componentsGrid.appendChild(lbl);
  });

  // Reset versions
  resetVersionSelect();
}

function handleMirrorChange() {
  const selectedOpt = mirrorSelect.options[mirrorSelect.selectedIndex];
  if (selectedOpt && selectedOpt.dataset.id === 'custom') {
    customMirrorGroup.style.display = 'block';
  } else {
    customMirrorGroup.style.display = 'none';
  }
}

function resetVersionSelect() {
  versionSelect.innerHTML = `<option value="">${I18N[currentLang].opt_latest_ver}</option>`;
  if (versionBadge) versionBadge.style.display = 'none';
  if (versionHint) versionHint.style.display = 'none';
}

// Check Versions
async function checkPackageVersions() {
  const pkg = pkgInput.value.trim();
  if (!pkg) {
    showToast(I18N[currentLang].enter_pkg_name, 'warn');
    pkgInput.focus();
    return;
  }

  checkVersionBtn.disabled = true;
  checkVersionBtn.innerHTML = `⏳ <span data-i18n="querying_versions">${I18N[currentLang].querying_versions}</span>`;
  showToast(I18N[currentLang].querying_versions, 'info');

  const payload = {
    package: pkg,
    distro: distroSelect.value,
    release: releaseSelect.value,
    mirror: getEffectiveMirror(),
    components: getSelectedComponents()
  };

  try {
    const res = await fetch('/api/check-package', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await res.json();

    versionSelect.innerHTML = '';

    if (data.found && data.versions && data.versions.length > 0) {
      // Add default latest option
      const defaultOpt = document.createElement('option');
      defaultOpt.value = '';
      defaultOpt.textContent = `🌟 ${I18N[currentLang].opt_latest_ver} (${data.versions[0].version})`;
      versionSelect.appendChild(defaultOpt);

      // Add each version
      data.versions.forEach(v => {
        const opt = document.createElement('option');
        opt.value = v.version;
        opt.textContent = `📦 ${v.version} — [${v.source || 'repository'}]`;
        versionSelect.appendChild(opt);
      });

      // Update badge and hint
      if (versionBadge) {
        versionBadge.textContent = `${data.versions.length} ${currentLang === 'fa' ? 'نسخه' : 'versions'}`;
        versionBadge.style.display = 'inline-block';
      }

      if (versionHint) {
        const msg = I18N[currentLang].version_hint_tpl.replace('{n}', data.versions.length);
        versionHint.textContent = `✅ ${msg}`;
        versionHint.style.display = 'block';
      }

      showToast(`✅ ${data.versions.length} ${I18N[currentLang].versions_found}`, 'success');
    } else {
      resetVersionSelect();
      showToast(I18N[currentLang].versions_not_found, 'warn');
      if (versionHint) {
        versionHint.textContent = `⚠️ ${I18N[currentLang].versions_not_found}`;
        versionHint.style.display = 'block';
      }
    }
  } catch (err) {
    showToast('Error checking versions: ' + err.message, 'error');
    resetVersionSelect();
  } finally {
    checkVersionBtn.disabled = false;
    checkVersionBtn.innerHTML = `🔍 <span data-i18n="btn_check_ver">${I18N[currentLang].btn_check_ver}</span>`;
  }
}

function getEffectiveMirror() {
  const selectedOpt = mirrorSelect.options[mirrorSelect.selectedIndex];
  if (selectedOpt && selectedOpt.dataset.id === 'custom') {
    return customMirrorInput.value.trim();
  }
  return mirrorSelect.value;
}

function getSelectedComponents() {
  const checked = Array.from(componentsGrid.querySelectorAll('input[type="checkbox"]:checked'));
  return checked.map(c => c.value).join(',');
}

// Start Download Job
async function startDownload() {
  const pkg = pkgInput.value.trim();
  if (!pkg) {
    showToast(I18N[currentLang].enter_pkg_name, 'warn');
    pkgInput.focus();
    return;
  }

  const selectedVersion = versionSelect.value.trim();

  const payload = {
    package: pkg,
    distro: distroSelect.value,
    release: releaseSelect.value,
    version: selectedVersion,
    arch: archSelect.value,
    mirror: getEffectiveMirror(),
    components: getSelectedComponents(),
    format: formatSelect.value,
    include_recommends: chkRecommends.checked,
    include_suggests: chkSuggests.checked,
    extra_repo: extraRepoInput.value.trim()
  };

  startDownloadBtn.disabled = true;
  cancelBtn.style.display = 'inline-flex';
  resultCard.style.display = 'none';

  terminalBody.innerHTML = '';
  appendLog('🚀 Starting download task...', 'log-info');
  if (selectedVersion) {
    appendLog(`📌 Target version selected: ${selectedVersion}`, 'log-info');
  }
  updateStatus('running', I18N[currentLang].status_running);

  try {
    const res = await fetch('/api/download', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await res.json();
    activeJobId = data.job_id;

    // Connect SSE for live streaming logs
    connectSSE(activeJobId);
  } catch (err) {
    showToast('Error starting download: ' + err.message, 'error');
    updateStatus('failed', I18N[currentLang].status_failed);
    startDownloadBtn.disabled = false;
    cancelBtn.style.display = 'none';
  }
}

// SSE Log Stream
function connectSSE(jobId) {
  if (eventSource) {
    eventSource.close();
  }

  eventSource = new EventSource(`/api/logs/${jobId}`);

  eventSource.onmessage = (e) => {
    const data = JSON.parse(e.data);
    if (data.text) {
      let className = 'log-line';
      if (data.text.includes('[OK]') || data.text.includes('✔') || data.text.includes('Complete') || data.text.includes('Success')) {
        className += ' log-ok';
      } else if (data.text.includes('[INFO]') || data.text.includes('🚀') || data.text.includes('📦')) {
        className += ' log-info';
      } else if (data.text.includes('[WARN]') || data.text.includes('⚠️')) {
        className += ' log-warn';
      } else if (data.text.includes('[ERROR]') || data.text.includes('❌') || data.text.includes('failed')) {
        className += ' log-err';
      }

      appendLog(data.text, className, data.time);
    }

    if (data.done) {
      eventSource.close();
      startDownloadBtn.disabled = false;
      cancelBtn.style.display = 'none';

      if (data.text && data.text.includes('[STATUS:completed]')) {
        updateStatus('completed', I18N[currentLang].status_completed);
        showResultCard(data.result_file);
        loadFiles();
      } else if (data.text && data.text.includes('[STATUS:cancelled]')) {
        updateStatus('idle', I18N[currentLang].status_cancelled);
      } else {
        updateStatus('failed', I18N[currentLang].status_failed);
      }
    }
  };

  eventSource.onerror = () => {
    eventSource.close();
    startDownloadBtn.disabled = false;
    cancelBtn.style.display = 'none';
  };
}

function appendLog(text, className = 'log-line', time = '') {
  const line = document.createElement('div');
  line.className = className;

  if (time) {
    const timeSpan = document.createElement('span');
    timeSpan.className = 'log-time';
    timeSpan.textContent = `[${time}] `;
    line.appendChild(timeSpan);
  }

  const textNode = document.createTextNode(text);
  line.appendChild(textNode);

  terminalBody.appendChild(line);
  terminalBody.scrollTop = terminalBody.scrollHeight;
}

function updateStatus(state, text) {
  statusIndicator.className = 'status-indicator ' + state;
  statusText.textContent = text;
}

function showResultCard(filename) {
  if (!filename) return;
  resultDetails.textContent = `${filename}`;
  downloadResultBtn.href = `/download/${encodeURIComponent(filename)}`;
  downloadResultBtn.download = filename;
  resultCard.style.display = 'block';
  resultCard.scrollIntoView({ behavior: 'smooth' });
}

// Cancel Job
async function cancelJob() {
  if (!activeJobId) return;
  cancelBtn.disabled = true;
  cancelBtn.textContent = '⏳ ...';
  appendLog('🛑 Cancelling download process...', 'log-warn');

  try {
    await fetch(`/api/cancel/${activeJobId}`, { method: 'POST' });
    appendLog('🛑 Download cancelled by user.', 'log-err');
    updateStatus('idle', I18N[currentLang].status_cancelled);
    startDownloadBtn.disabled = false;
    cancelBtn.style.display = 'none';
    cancelBtn.disabled = false;
    cancelBtn.innerHTML = `✖ <span data-i18n="btn_cancel">${I18N[currentLang].btn_cancel}</span>`;
    if (eventSource) {
      eventSource.close();
    }
  } catch (err) {
    showToast('Failed to cancel job: ' + err.message, 'error');
    cancelBtn.disabled = false;
  }
}

// Load Files List
async function loadFiles() {
  try {
    const res = await fetch('/api/files');
    const files = await res.json();

    filesTableBody.innerHTML = '';
    if (!files || files.length === 0) {
      filesTableBody.innerHTML = `<tr><td colspan="4" style="text-align: center; color: var(--text-muted); padding: 24px;">${I18N[currentLang].no_files}</td></tr>`;
      return;
    }

    files.forEach(f => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><span class="file-icon">📦</span> <strong>${f.name}</strong></td>
        <td>${f.size_human}</td>
        <td>${f.date}</td>
        <td>
          <div class="action-btns">
            <a href="${f.download_url}" class="btn btn-primary btn-sm" download="${f.name}">
              ⬇️ ${I18N[currentLang].btn_download}
            </a>
            <button class="btn btn-secondary btn-sm btn-del" data-name="${f.name}">
              🗑️ ${I18N[currentLang].btn_delete}
            </button>
          </div>
        </td>
      `;

      tr.querySelector('.btn-del').addEventListener('click', () => deleteFile(f.name));
      filesTableBody.appendChild(tr);
    });
  } catch (err) {
    console.error('Error loading files:', err);
  }
}

// Delete File
async function deleteFile(filename) {
  if (!confirm(`Are you sure you want to delete ${filename}?`)) return;
  try {
    const res = await fetch(`/api/delete-file/${encodeURIComponent(filename)}`, { method: 'POST' });
    const data = await res.json();
    if (data.success) {
      showToast(I18N[currentLang].toast_deleted, 'success');
      loadFiles();
    }
  } catch (err) {
    showToast('Failed to delete file: ' + err.message, 'error');
  }
}

// Open Folder in System File Manager
async function openSystemFolder() {
  try {
    const res = await fetch('/api/open-folder', { method: 'POST' });
    const data = await res.json();
    if (data.success) {
      showToast('Opened output directory in file manager', 'info');
    }
  } catch (err) {
    showToast('Could not open folder: ' + err.message, 'error');
  }
}

// Show Toast
function showToast(message, type = 'info') {
  const container = document.getElementById('toastContainer');
  const toast = document.createElement('div');
  toast.className = 'toast';
  
  let icon = 'ℹ️';
  if (type === 'success') icon = '✅';
  if (type === 'warn') icon = '⚠️';
  if (type === 'error') icon = '❌';

  toast.innerHTML = `<span>${icon}</span> <span>${message}</span>`;
  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(10px)';
    toast.style.transition = 'all 0.3s';
    setTimeout(() => toast.remove(), 300);
  }, 4000);
}

// Event Listeners
function setupEventListeners() {
  distroSelect.addEventListener('change', updateDistroUI);
  releaseSelect.addEventListener('change', resetVersionSelect);
  mirrorSelect.addEventListener('change', handleMirrorChange);
  pkgInput.addEventListener('input', resetVersionSelect);
  checkVersionBtn.addEventListener('click', checkPackageVersions);
  startDownloadBtn.addEventListener('click', startDownload);
  cancelBtn.addEventListener('click', cancelJob);
  refreshFilesBtn.addEventListener('click', loadFiles);
  openFolderBtn.addEventListener('click', openSystemFolder);
  showInFolderBtn.addEventListener('click', openSystemFolder);

  pkgInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
      startDownload();
    }
  });

  langToggle.addEventListener('click', () => {
    const nextLang = currentLang === 'fa' ? 'en' : 'fa';
    setupLanguage(nextLang);
  });

  themeToggle.addEventListener('click', toggleTheme);
}
