// Phone.jsx — minimal phone bezel scaled to fit the screens.
// Outputs a 360x780 inner viewport — matches Material 3 mobile spec.

const Phone = ({ children, theme = 'light', label }) => (
  <div data-screen-label={label} style={{
    width: 380, padding: 10, borderRadius: 44,
    background: theme === 'dark' ? '#000' : '#1a1a1a',
    boxShadow: '0 30px 60px -20px rgb(0 0 0 / 0.35), 0 1px 0 rgb(255 255 255 / 0.05) inset',
  }}>
    <div data-theme={theme} style={{
      width: 360, height: 780, borderRadius: 36, overflow: 'hidden',
      background: 'var(--bg)', position: 'relative',
      fontFamily: "'Inter', -apple-system, sans-serif",
      color: 'var(--text-primary)',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* status bar */}
      <div style={{
        height: 32, padding: '0 22px', display: 'flex',
        alignItems: 'center', justifyContent: 'space-between',
        fontSize: 13, fontWeight: 600, color: 'var(--text-primary)',
        flexShrink: 0,
      }}>
        <span>9:41</span>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center', opacity: 0.85 }}>
          <i data-lucide="signal" style={{ width: 14, height: 14 }}></i>
          <i data-lucide="wifi" style={{ width: 14, height: 14 }}></i>
          <i data-lucide="battery-full" style={{ width: 18, height: 14 }}></i>
        </div>
      </div>
      {children}
    </div>
  </div>
);

window.Phone = Phone;
