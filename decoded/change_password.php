<?php
session_start();
require_once __DIR__ . '/includes/config.php';

if (!isset($_SESSION['user_id'])) {
    header('Location: admin/'); exit;
}

$msg = ''; $msg_type = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $old_pass = $_POST['old_password'] ?? '';
    $new_pass = $_POST['new_password'] ?? '';
    $confirm  = $_POST['confirm_password'] ?? '';
    
    if (empty($old_pass) || empty($new_pass) || empty($confirm)) {
        $msg = 'Semua field harus diisi!';
        $msg_type = 'error';
    } elseif ($new_pass !== $confirm) {
        $msg = 'Password baru tidak cocok!';
        $msg_type = 'error';
    } elseif (strlen($new_pass) < 6) {
        $msg = 'Password minimal 6 karakter!';
        $msg_type = 'error';
    } else {
        $db = getDB();
        $stmt = $db->prepare('SELECT password FROM users WHERE id = ?');
        $stmt->execute([$_SESSION['user_id']]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($user && password_verify($old_pass, $user['password'])) {
            $new_hash = password_hash($new_pass, PASSWORD_BCRYPT);
            $stmt = $db->prepare('UPDATE users SET password = ? WHERE id = ?');
            $stmt->execute([$new_hash, $_SESSION['user_id']]);
            $msg = 'Password berhasil diubah!';
            $msg_type = 'success';
        } else {
            $msg = 'Password lama salah!';
            $msg_type = 'error';
        }
    }
}

$db = getDB();
$stmt = $db->prepare('SELECT username, email, role FROM users WHERE id = ?');
$stmt->execute([$_SESSION['user_id']]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);
$appName = getSetting('app_name','OrderVPN');
?>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ganti Password &mdash; <?=$appName?></title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <style>
:root {
  --bg-deep: #03050a;
  --bg-surface: #080b15;
  --bg-elevated: #0e1321;
  --bg-card: rgba(14, 19, 33, 0.75);
  --border: rgba(30, 50, 80, 0.35);
  --border-hover: rgba(5, 150, 105, 0.3);
  --text: #e8edf5;
  --text-dim: #8b97b5;
  --text-muted: #4a5678;
  --accent: #059669;
  --accent-light: #34d399;
  --accent-dark: #047857;
  --accent-glow: rgba(5, 150, 105, 0.3);
  --danger: #ef4444;
  --danger-bg: rgba(239, 68, 68, 0.08);
  --success: #10b981;
  --success-bg: rgba(16, 185, 129, 0.1);
  --radius: 16px;
  --radius-sm: 10px;
  --radius-xs: 6px;
  --shadow: 0 24px 80px rgba(0, 0, 0, 0.6);
  --transition: 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  font-family: 'Inter', 'Segoe UI', system-ui, -apple-system, sans-serif;
  background: var(--bg-deep);
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  -webkit-font-smoothing: antialiased;
  position: relative;
  overflow-x: hidden;
}
/* Ambient background layers */
body::before {
  content: '';
  position: fixed;
  inset: 0;
  pointer-events: none;
  z-index: 0;
  background-image:
    radial-gradient(ellipse 60% 50% at 20% 30%, rgba(5, 150, 105, 0.04) 0%, transparent 60%),
    radial-gradient(ellipse 40% 40% at 80% 70%, rgba(16, 185, 129, 0.03) 0%, transparent 50%);
}
.bg-grid {
  position: fixed;
  inset: 0;
  pointer-events: none;
  z-index: 0;
  background-image:
    linear-gradient(rgba(30, 50, 80, 0.06) 1px, transparent 1px),
    linear-gradient(90deg, rgba(30, 50, 80, 0.06) 1px, transparent 1px);
  background-size: 64px 64px;
  mask-image: radial-gradient(ellipse 70% 60% at 50% 50%, black 20%, transparent 70%);
  -webkit-mask-image: radial-gradient(ellipse 70% 60% at 50% 50%, black 20%, transparent 70%);
}
/* Grain overlay */
.grain {
  position: fixed;
  inset: 0;
  pointer-events: none;
  z-index: 1;
  opacity: 0.035;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E");
  background-repeat: repeat;
  background-size: 256px 256px;
}
.card {
  position: relative;
  z-index: 2;
  width: 100%;
  max-width: 420px;
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 40px 36px;
  backdrop-filter: blur(24px) saturate(180%);
  -webkit-backdrop-filter: blur(24px) saturate(180%);
  box-shadow: var(--shadow), inset 0 1px 0 rgba(255, 255, 255, 0.04);
  animation: cardIn 0.5s ease;
}
@keyframes cardIn {
  from { opacity: 0; transform: translateY(20px) scale(0.98); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}
.logo-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  margin-bottom: 24px;
}
.logo-icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  background: linear-gradient(135deg, var(--accent), var(--accent-dark));
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8px 24px var(--accent-glow);
  flex-shrink: 0;
}
.logo-text {
  font-family: 'Space Grotesk', sans-serif;
  font-size: 1.15em;
  font-weight: 700;
  color: var(--text);
  letter-spacing: -0.3px;
}
.logo-text span {
  color: var(--accent-light);
}
.card h2 {
  font-family: 'Space Grotesk', sans-serif;
  font-size: 1.35em;
  font-weight: 700;
  text-align: center;
  color: var(--text);
  letter-spacing: -0.3px;
  margin-bottom: 4px;
}
.card .subtitle {
  text-align: center;
  color: var(--text-muted);
  font-size: 0.85em;
  margin-bottom: 28px;
}
.user-info {
  background: rgba(5, 150, 105, 0.06);
  border-radius: var(--radius-sm);
  padding: 14px 16px;
  margin-bottom: 24px;
  color: var(--text-dim);
  font-size: 0.84em;
  text-align: center;
  border: 1px solid rgba(5, 150, 105, 0.1);
}
.user-info strong {
  color: var(--accent-light);
  font-weight: 600;
}
.form-group {
  margin-bottom: 18px;
}
.form-group label {
  display: block;
  margin-bottom: 6px;
  font-size: 0.72em;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-dim);
}
.form-group input {
  width: 100%;
  padding: 12px 16px;
  background: rgba(3, 5, 10, 0.5);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  color: var(--text);
  font-size: 0.9em;
  font-family: inherit;
  transition: var(--transition);
  outline: none;
}
.form-group input:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px rgba(5, 150, 105, 0.1), inset 0 1px 0 rgba(5, 150, 105, 0.05);
}
.form-group input::placeholder {
  color: #2a3660;
}
.form-group input:hover:not(:focus) {
  border-color: rgba(30, 50, 80, 0.6);
}
.btn {
  width: 100%;
  padding: 13px;
  border: none;
  border-radius: var(--radius-sm);
  background: linear-gradient(135deg, var(--accent), var(--accent-dark));
  color: #fff;
  font-size: 0.9em;
  font-weight: 600;
  font-family: inherit;
  cursor: pointer;
  transition: var(--transition);
  letter-spacing: 0.02em;
}
.btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 30px var(--accent-glow);
}
.btn:active {
  transform: translateY(0);
}
.alert {
  padding: 12px 16px;
  border-radius: var(--radius-sm);
  margin-bottom: 20px;
  font-size: 0.84em;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 8px;
  animation: fadeSlideIn 0.3s ease;
}
@keyframes fadeSlideIn {
  from { opacity: 0; transform: translateY(-8px); }
  to { opacity: 1; transform: translateY(0); }
}
.alert-success {
  background: rgba(16, 185, 129, 0.1);
  color: var(--success);
  border: 1px solid rgba(16, 185, 129, 0.2);
}
.alert-error {
  background: rgba(239, 68, 68, 0.08);
  color: var(--danger);
  border: 1px solid rgba(239, 68, 68, 0.15);
}
.back-link {
  display: block;
  text-align: center;
  margin-top: 18px;
  color: var(--text-muted);
  text-decoration: none;
  font-size: 0.82em;
  transition: var(--transition);
}
.back-link:hover {
  color: var(--accent-light);
}
@media (max-width: 480px) {
  .card { padding: 28px 20px; border-radius: 12px; }
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { transition-duration: 0.01ms !important; animation-duration: 0.01ms !important; }
}
</style>
</head>
<body>
<div class="grain"></div>
<div class="bg-grid"></div>
<div class="card">
  <div class="logo-wrap">
    <div class="logo-icon">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="1" y="3" width="22" height="18" rx="2" ry="2"/><line x1="9" y1="3" x2="9" y2="21"/><line x1="15" y1="3" x2="15" y2="21"/></svg>
    </div>
    <div class="logo-text"><?=$appName?> <span>Panel</span></div>
  </div>
  <h2>Ganti Password</h2>
  <p class="subtitle">Kelola keamanan akun Anda</p>
  
  <div class="user-info">
    Login sebagai: <strong><?= htmlspecialchars($user['username']) ?></strong> &middot; <?= htmlspecialchars($user['role']) ?>
  </div>
  
  <?php if ($msg): ?>
  <div class="alert alert-<?= $msg_type === 'success' ? 'success' : 'error' ?>">
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="flex-shrink:0"><?= $msg_type === 'success' ? '<polyline points="20 6 9 17 4 12"/>' : '<circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>' ?></svg>
    <span><?= htmlspecialchars($msg) ?></span>
  </div>
  <?php endif; ?>
  
  <form method="POST">
    <div class="form-group">
      <label>Password Lama</label>
      <input type="password" name="old_password" placeholder="Masukkan password saat ini" required>
    </div>
    <div class="form-group">
      <label>Password Baru</label>
      <input type="password" name="new_password" placeholder="Minimal 6 karakter" required minlength="6">
    </div>
    <div class="form-group">
      <label>Konfirmasi Password Baru</label>
      <input type="password" name="confirm_password" placeholder="Ulangi password baru" required minlength="6">
    </div>
    <button type="submit" class="btn">Simpan Password Baru</button>
  </form>
  
  <a href="admin/" class="back-link">
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align:middle;margin-right:4px"><polyline points="15 18 9 12 15 6"/></svg>
    Kembali ke Dashboard
  </a>
</div>
</body>
</html>