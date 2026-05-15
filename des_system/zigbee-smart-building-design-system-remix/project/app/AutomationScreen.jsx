// AutomationScreen.jsx — list-first rule management with rule cards.
// Shows existing rules; a prominent "+ New rule" CTA opens the create flow.

const { useState } = React;

// ── Status chip pair used on every rule card ─────────────────
const StatusRow = ({ syncStatus, runStatus, lastRunAt }) => (
  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
    <Badge tone={SYNC_TONE[syncStatus]} dot>
      {syncStatus.toUpperCase()}
    </Badge>
    <Badge tone={RUN_TONE[runStatus]}>
      <i data-lucide={RUN_ICON[runStatus]} style={{ width: 11, height: 11 }}></i>
      {runStatus.toUpperCase().replace('_', ' ')}
    </Badge>
    {lastRunAt && (
      <span style={{
        fontSize: 11, color: 'var(--text-secondary)',
        fontFamily: "'JetBrains Mono', monospace", marginLeft: 'auto',
      }}>{lastRunAt}</span>
    )}
  </div>
);

// ── A monospace block describing WHEN / THEN ─────────────────
const RuleBody = ({ rule }) => {
  const actionVerb = rule.targetAction === 'toggle' ? 'toggle'
                   : rule.targetAction === 'on'     ? 'on'
                   :                                  'off';
  return (
    <div style={{
      background: 'var(--bg)', borderRadius: 12,
      border: '1px solid var(--border)',
      padding: '10px 12px', display: 'grid',
      gridTemplateColumns: 'auto 1fr', columnGap: 10, rowGap: 4,
      fontFamily: "'JetBrains Mono', monospace", fontSize: 12, lineHeight: 1.45,
    }}>
      <span style={{
        fontWeight: 600, color: 'var(--primary)', letterSpacing: '0.04em',
      }}>WHEN</span>
      <div style={{ color: 'var(--text-primary)', minWidth: 0, wordBreak: 'break-all' }}>
        <span style={{ color: 'var(--text-secondary)' }}>{rule.triggerDeviceId}</span>
        <br/>
        <span>{rule.triggerEvent}</span>
      </div>
      <span style={{
        fontWeight: 600, color: 'var(--success)', letterSpacing: '0.04em',
      }}>THEN</span>
      <div style={{ color: 'var(--text-primary)', minWidth: 0, wordBreak: 'break-all' }}>
        {rule.targets.map(t => (
          <div key={t.id}>
            <span style={{ color: 'var(--text-secondary)' }}>{t.id}</span>
            {' '}
            <span style={{ fontWeight: 600 }}>{actionVerb}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

// ── Toggle switch (compact, used on rule cards) ──────────────
const Switch = ({ on, onChange }) => (
  <button onClick={e => { e.stopPropagation(); onChange?.(!on); }} aria-pressed={on} style={{
    width: 38, height: 22, borderRadius: 999,
    background: on ? 'var(--primary)' : 'rgb(107 114 128 / 0.28)',
    border: 'none', padding: 0, position: 'relative', cursor: 'pointer',
    transition: 'background var(--dur-fast) var(--ease-standard)',
    flexShrink: 0,
  }}>
    <span style={{
      position: 'absolute', top: 2, left: on ? 18 : 2,
      width: 18, height: 18, borderRadius: 999, background: '#fff',
      transition: 'left var(--dur-fast) var(--ease-standard)',
      boxShadow: '0 1px 2px rgb(0 0 0 / 0.2)',
    }}/>
  </button>
);

// ── A single rule card ───────────────────────────────────────
const RuleCard = ({ rule, highlight }) => {
  const t = tmpl(rule.template);
  return (
    <Card padding={14} style={{
      display: 'flex', flexDirection: 'column', gap: 10,
      opacity: rule.enabled ? 1 : 0.72,
      outline: highlight ? '2px solid var(--primary)' : 'none',
      outlineOffset: highlight ? 2 : 0,
    }}>
      {/* header row */}
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
        <div style={{
          width: 34, height: 34, borderRadius: 10, flexShrink: 0,
          background: 'var(--primary-tint)', color: 'var(--primary)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <i data-lucide={t.icon} style={{ width: 18, height: 18 }}></i>
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 14, fontWeight: 600, lineHeight: 1.3 }}>{rule.name}</div>
          <div style={{
            fontSize: 11, color: 'var(--text-secondary)', marginTop: 2,
            display: 'flex', alignItems: 'center', gap: 6,
          }}>
            <span>{t.title}</span>
          </div>
        </div>
        <Switch on={rule.enabled} />
      </div>
      {/* status row */}
      <StatusRow
        syncStatus={rule.sync_status}
        runStatus={rule.last_run_status}
        lastRunAt={rule.last_run_at}
      />
      {/* WHEN / THEN block */}
      <RuleBody rule={rule} />
    </Card>
  );
};

// ── Top "Create rule" CTA (collapsed) ────────────────────────
const CreateCTA = ({ onClick }) => (
  <button onClick={onClick} style={{
    display: 'flex', alignItems: 'center', gap: 12, width: '100%',
    background: 'var(--surface)', border: '1px dashed var(--border-strong, var(--border))',
    borderRadius: 20, padding: 14, cursor: 'pointer',
    fontFamily: 'inherit', textAlign: 'left',
    color: 'var(--text-primary)',
  }}>
    <div style={{
      width: 40, height: 40, borderRadius: 12,
      background: 'var(--primary-tint)', color: 'var(--primary)',
      display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
    }}>
      <i data-lucide="plus" style={{ width: 22, height: 22 }}></i>
    </div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 14, fontWeight: 600 }}>New rule</div>
      <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 2 }}>
        When something happens, do something
      </div>
    </div>
    <i data-lucide="chevron-right" style={{ width: 18, height: 18, color: 'var(--text-secondary)' }}></i>
  </button>
);

// ── Empty state for when there are no rules yet ──────────────
const EmptyRules = ({ onCreate }) => (
  <div style={{
    flex: 1, display: 'flex', flexDirection: 'column',
    alignItems: 'center', justifyContent: 'center', gap: 12,
    padding: '32px 24px', textAlign: 'center',
  }}>
    <div style={{
      width: 72, height: 72, borderRadius: 20,
      background: 'var(--surface)', border: '1px solid var(--border)',
      color: 'var(--text-secondary)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <i data-lucide="workflow" style={{ width: 32, height: 32 }}></i>
    </div>
    <div style={{ fontSize: 16, fontWeight: 600 }}>No automation rules yet</div>
    <div style={{
      fontSize: 13, color: 'var(--text-secondary)', maxWidth: 240, lineHeight: 1.45,
    }}>
      Create a rule to react when a motion sensor or switch fires.
      Cloud will save it and sync to the gateway.
    </div>
    <button onClick={onCreate} style={{
      marginTop: 4, display: 'inline-flex', alignItems: 'center', gap: 6,
      background: 'var(--primary)', color: 'var(--primary-on)',
      border: 'none', borderRadius: 12, padding: '10px 16px',
      fontFamily: 'inherit', fontSize: 14, fontWeight: 600, cursor: 'pointer',
    }}>
      <i data-lucide="plus" style={{ width: 16, height: 16 }}></i>
      New rule
    </button>
  </div>
);

// ── The screen ──────────────────────────────────────────────
const AutomationScreen = ({ variant = 'list', onOpenCreate }) => {
  const rules = variant === 'empty' ? [] : MOCK_RULES;
  const justCreatedId = variant === 'saved' ? 'aut-02' : null;

  return (
    <>
      <AppBar
        title="Automation"
        trailing={
          <div style={{ display: 'flex' }}>
            <IconBtn icon="refresh-cw" />
          </div>
        }
      />
      {rules.length === 0 ? (
        <Body padded={false}>
          <EmptyRules onCreate={onOpenCreate} />
        </Body>
      ) : (
        <Body>
          {variant === 'saved' && (
            <div style={{
              display: 'flex', alignItems: 'center', gap: 10,
              background: 'var(--success-tint)', color: 'var(--success)',
              border: '1px solid color-mix(in oklab, var(--success) 25%, transparent)',
              borderRadius: 12, padding: '10px 12px',
              fontSize: 13, fontWeight: 500,
            }}>
              <i data-lucide="circle-check" style={{ width: 16, height: 16 }}></i>
              <span style={{ flex: 1 }}>Rule created. Waiting for gateway sync.</span>
            </div>
          )}

          <CreateCTA onClick={onOpenCreate} />

          <SectionTitle action={
            <span style={{
              fontSize: 11, color: 'var(--text-secondary)',
              fontFamily: "'JetBrains Mono', monospace",
            }}>{rules.length} rule{rules.length === 1 ? '' : 's'}</span>
          }>Rules</SectionTitle>

          {rules.map(r => (
            <RuleCard key={r.id} rule={r} highlight={r.id === justCreatedId} />
          ))}
          <div style={{ height: 4 }} />
        </Body>
      )}
    </>
  );
};

Object.assign(window, { AutomationScreen, RuleCard, CreateCTA, Switch, StatusRow });
