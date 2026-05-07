// SettingsScreen.jsx — theme picker + endpoint info.

const SettingsScreen = ({ theme, onTheme }) => {
  const ROW = ({ icon, label, value, onClick }) => (
    <div onClick={onClick} style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px',
      borderTop: '1px solid var(--border)',
      cursor: onClick ? 'pointer' : 'default',
    }}>
      <i data-lucide={icon} style={{ width: 18, height: 18, color: 'var(--text-secondary)' }}></i>
      <div style={{ flex: 1, fontSize: 14 }}>{label}</div>
      <div style={{
        fontSize: 12, color: 'var(--text-secondary)',
        fontFamily: "'JetBrains Mono', monospace",
      }}>{value}</div>
      {onClick && <i data-lucide="chevron-right" style={{ width: 14, height: 14, color: 'var(--text-secondary)' }}></i>}
    </div>
  );

  const themes = [
    { id: 'light', label: 'Light', swatch: '#F7F8FA', ring: '#4F7DFF' },
    { id: 'dark', label: 'Dark', swatch: '#0F1115', ring: '#7AA2FF' },
    { id: 'grey', label: 'Grey', swatch: '#E7E9EC', ring: '#4B5563' },
  ];

  return (
    <>
      <AppBar title="Settings" />
      <Body>
        <SectionTitle>Appearance</SectionTitle>
        <Card padding={14}>
          <div style={{ display: 'flex', gap: 10 }}>
            {themes.map(t => {
              const active = theme === t.id;
              return (
                <button key={t.id} onClick={() => onTheme(t.id)} style={{
                  flex: 1, padding: 12, borderRadius: 14,
                  border: '2px solid ' + (active ? t.ring : 'var(--border)'),
                  background: 'var(--surface)', cursor: 'pointer',
                  display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8,
                  fontFamily: 'inherit',
                }}>
                  <div style={{
                    width: 44, height: 44, borderRadius: 12,
                    background: t.swatch,
                    border: '1px solid var(--border)',
                  }}></div>
                  <div style={{
                    fontSize: 13,
                    fontWeight: active ? 600 : 500,
                    color: active ? t.ring : 'var(--text-primary)',
                  }}>{t.label}</div>
                </button>
              );
            })}
          </div>
        </Card>

        <SectionTitle>Cloud</SectionTitle>
        <Card padding={0}>
          <ROW icon="globe" label="API base URL" value="cloud.local:8000" />
          <ROW icon="activity" label="Health" value="OK" />
          <ROW icon="timer" label="Poll interval" value="2000ms" />
        </Card>

        <SectionTitle>About</SectionTitle>
        <Card padding={0}>
          <ROW icon="info" label="App version" value="0.1.0 · MVP" />
          <ROW icon="git-branch" label="Build" value="main · a1b2c3d" />
          <ROW icon="bug" label="Debug logs" value="On" />
        </Card>

        <div style={{ height: 4 }} />
      </Body>
    </>
  );
};

window.SettingsScreen = SettingsScreen;
