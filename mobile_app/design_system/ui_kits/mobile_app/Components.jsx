// Common UI primitives used across all screens.

const cx = (...xs) => xs.filter(Boolean).join(' ');

// ── App bar ──────────────────────────────────────────────────
const AppBar = ({ title, leading, trailing }) => (
  <div style={{
    height: 56, padding: '0 8px 0 16px', display: 'flex',
    alignItems: 'center', gap: 8, flexShrink: 0,
  }}>
    {leading}
    <div style={{ fontSize: 18, fontWeight: 600, flex: 1, letterSpacing: '-0.005em' }}>{title}</div>
    {trailing}
  </div>
);

const IconBtn = ({ icon, onClick, color }) => (
  <button onClick={onClick} style={{
    width: 40, height: 40, borderRadius: 999, border: 'none',
    background: 'transparent', color: color || 'var(--text-primary)',
    display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
  }}>
    <i data-lucide={icon} style={{ width: 20, height: 20 }}></i>
  </button>
);

// ── Bottom nav ───────────────────────────────────────────────
const BottomNav = ({ active, onChange }) => {
  const tabs = [
    { id: 'home', label: 'Home', icon: 'house' },
    { id: 'devices', label: 'Devices', icon: 'lightbulb' },
    { id: 'logs', label: 'Logs', icon: 'terminal' },
    { id: 'settings', label: 'Settings', icon: 'settings' },
  ];
  return (
    <div style={{
      height: 64, borderTop: '1px solid var(--border)',
      display: 'flex', background: 'var(--surface)', flexShrink: 0,
    }}>
      {tabs.map(t => {
        const isActive = active === t.id;
        return (
          <button key={t.id} onClick={() => onChange(t.id)} style={{
            flex: 1, border: 'none', background: 'transparent', cursor: 'pointer',
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            justifyContent: 'center', gap: 3,
            color: isActive ? 'var(--primary)' : 'var(--text-secondary)',
            fontFamily: 'inherit',
          }}>
            <div style={{
              padding: '4px 16px', borderRadius: 999,
              background: isActive ? 'var(--primary-tint)' : 'transparent',
            }}>
              <i data-lucide={t.icon} style={{ width: 20, height: 20 }}></i>
            </div>
            <span style={{ fontSize: 11, fontWeight: isActive ? 600 : 500 }}>{t.label}</span>
          </button>
        );
      })}
    </div>
  );
};

// ── Status badge ─────────────────────────────────────────────
const Badge = ({ tone = 'neutral', children, dot }) => {
  const tones = {
    success: { bg: 'var(--success-tint)', fg: 'var(--success)' },
    warning: { bg: 'var(--warning-tint)', fg: 'var(--warning)' },
    error:   { bg: 'var(--error-tint)',   fg: 'var(--error)'   },
    primary: { bg: 'var(--primary-tint)', fg: 'var(--primary)' },
    neutral: { bg: 'rgb(107 114 128 / 0.14)', fg: 'var(--text-secondary)' },
  };
  const t = tones[tone];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '4px 10px', borderRadius: 999,
      background: t.bg, color: t.fg,
      fontFamily: "'JetBrains Mono', monospace", fontSize: 11, fontWeight: 500,
      letterSpacing: '0.02em',
    }}>
      {dot && <span style={{ width: 6, height: 6, borderRadius: 999, background: t.fg }}></span>}
      {children}
    </span>
  );
};

// ── Card ─────────────────────────────────────────────────────
const Card = ({ children, padding = 16, style = {}, onClick }) => (
  <div onClick={onClick} style={{
    background: 'var(--surface)', border: '1px solid var(--border)',
    borderRadius: 20, padding, boxShadow: 'var(--elev-1)',
    cursor: onClick ? 'pointer' : 'default',
    ...style,
  }}>
    {children}
  </div>
);

// ── Section title ────────────────────────────────────────────
const SectionTitle = ({ children, action }) => (
  <div style={{
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    padding: '0 4px', marginBottom: 8,
  }}>
    <span style={{
      fontSize: 11, fontWeight: 600, letterSpacing: '0.06em',
      textTransform: 'uppercase', color: 'var(--text-secondary)',
    }}>{children}</span>
    {action}
  </div>
);

// ── Filter chip ──────────────────────────────────────────────
const Chip = ({ active, onClick, icon, children }) => (
  <button onClick={onClick} style={{
    display: 'inline-flex', alignItems: 'center', gap: 6,
    padding: '7px 12px', borderRadius: 999,
    border: '1px solid ' + (active ? 'transparent' : 'var(--border)'),
    background: active ? 'var(--primary)' : 'var(--surface)',
    color: active ? 'var(--primary-on)' : 'var(--text-primary)',
    fontFamily: 'inherit', fontSize: 13, fontWeight: 500, cursor: 'pointer',
    whiteSpace: 'nowrap', flexShrink: 0,
  }}>
    {icon && <i data-lucide={icon} style={{ width: 14, height: 14 }}></i>}
    {children}
  </button>
);

// ── Scroll body ──────────────────────────────────────────────
const Body = ({ children, padded = true }) => (
  <div style={{
    flex: 1, overflowY: 'auto', overflowX: 'hidden',
    background: 'var(--bg)',
    padding: padded ? '8px 16px 16px' : 0,
    display: 'flex', flexDirection: 'column', gap: 12,
  }}>
    {children}
  </div>
);

Object.assign(window, { cx, AppBar, IconBtn, BottomNav, Badge, Card, SectionTitle, Chip, Body });
