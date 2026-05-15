// CreateRuleSheet.jsx — bottom-sheet form for creating a new rule.
// Two preview variants: 'template' (early state) and 'fields' (filled-in).

// ── Field label / wrapper ────────────────────────────────────
const Field = ({ label, hint, children, required }) => (
  <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
      <span style={{
        fontSize: 11, fontWeight: 600, letterSpacing: '0.06em',
        textTransform: 'uppercase', color: 'var(--text-secondary)',
      }}>{label}</span>
      {required && <span style={{ fontSize: 11, color: 'var(--error)' }}>•</span>}
      {hint && <span style={{
        fontSize: 11, color: 'var(--text-secondary)', marginLeft: 'auto',
        fontFamily: "'JetBrains Mono', monospace",
      }}>{hint}</span>}
    </div>
    {children}
  </div>
);

// ── Text input ───────────────────────────────────────────────
const TextField = ({ value, placeholder, mono }) => (
  <div style={{
    background: 'var(--surface)', border: '1px solid var(--border)',
    borderRadius: 12, padding: '10px 12px',
    display: 'flex', alignItems: 'center', gap: 8,
  }}>
    <span style={{
      flex: 1, fontFamily: mono ? "'JetBrains Mono', monospace" : 'inherit',
      fontSize: 14, color: value ? 'var(--text-primary)' : 'var(--text-secondary)',
    }}>{value || placeholder}</span>
  </div>
);

// ── Template card — visual chooser for the 4 MVP templates ───
const TemplateCard = ({ tpl, selected }) => (
  <button style={{
    display: 'flex', flexDirection: 'column', gap: 8,
    background: selected ? 'var(--primary-tint)' : 'var(--surface)',
    border: '1px solid ' + (selected ? 'var(--primary)' : 'var(--border)'),
    borderRadius: 14, padding: 12,
    textAlign: 'left', cursor: 'pointer', fontFamily: 'inherit',
    color: 'var(--text-primary)',
  }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <div style={{
        width: 26, height: 26, borderRadius: 8,
        background: selected ? 'var(--primary)' : 'var(--primary-tint)',
        color: selected ? 'var(--primary-on)' : 'var(--primary)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
      }}>
        <i data-lucide={tpl.icon} style={{ width: 14, height: 14 }}></i>
      </div>
      <span style={{ fontSize: 12, fontWeight: 600, lineHeight: 1.25 }}>{tpl.title}</span>
      {selected && (
        <i data-lucide="check" style={{
          width: 14, height: 14, color: 'var(--primary)', marginLeft: 'auto',
        }}></i>
      )}
    </div>
    <div style={{
      fontSize: 11, color: 'var(--text-secondary)', lineHeight: 1.4,
      fontFamily: "'JetBrains Mono', monospace",
    }}>{tpl.action}</div>
  </button>
);

// ── Device row (selectable) ──────────────────────────────────
const DeviceRow = ({ dev, selected, kind = 'radio' }) => (
  <div style={{
    display: 'flex', alignItems: 'center', gap: 10,
    background: selected ? 'var(--primary-tint)' : 'var(--surface)',
    border: '1px solid ' + (selected ? 'var(--primary)' : 'var(--border)'),
    borderRadius: 12, padding: '10px 12px',
  }}>
    <div style={{
      width: 30, height: 30, borderRadius: 9,
      background: selected ? 'var(--primary)' : 'var(--primary-tint)',
      color: selected ? 'var(--primary-on)' : 'var(--primary)',
      display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
    }}>
      <i data-lucide={TYPE_ICON[dev.type]} style={{ width: 15, height: 15 }}></i>
    </div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 13, fontWeight: 600 }}>{dev.name}</div>
      <div style={{
        fontSize: 11, color: 'var(--text-secondary)',
        fontFamily: "'JetBrains Mono', monospace", marginTop: 2,
      }}>{dev.label} · {dev.room}</div>
    </div>
    {/* selection indicator */}
    {kind === 'check' ? (
      <div style={{
        width: 20, height: 20, borderRadius: 6,
        background: selected ? 'var(--primary)' : 'transparent',
        border: '1.5px solid ' + (selected ? 'var(--primary)' : 'var(--border)'),
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
      }}>
        {selected && <i data-lucide="check" style={{ width: 12, height: 12, color: 'var(--primary-on)' }}></i>}
      </div>
    ) : (
      <div style={{
        width: 18, height: 18, borderRadius: 999,
        border: '1.5px solid ' + (selected ? 'var(--primary)' : 'var(--border)'),
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        background: 'transparent',
      }}>
        {selected && <div style={{
          width: 9, height: 9, borderRadius: 999, background: 'var(--primary)',
        }}/>}
      </div>
    )}
  </div>
);

// ── Plain-language preview that mirrors the user guide tone ──
const RulePreview = ({ tpl, triggerLabel, targets }) => {
  if (!tpl) return null;
  const verb = tpl.targetAction === 'toggle' ? 'Toggle'
             : tpl.targetAction === 'on'     ? 'Turn'
             :                                  'Turn';
  const tail = tpl.targetAction === 'toggle' ? ''
             : tpl.targetAction === 'on'     ? ' on'
             :                                  ' off';
  return (
    <div style={{
      background: 'var(--bg)', border: '1px solid var(--border)',
      borderRadius: 12, padding: 12, display: 'flex', flexDirection: 'column', gap: 6,
      fontFamily: "'JetBrains Mono', monospace", fontSize: 12, lineHeight: 1.5,
    }}>
      <div>
        <span style={{ color: 'var(--primary)', fontWeight: 600 }}>When </span>
        <span style={{ fontWeight: 600 }}>{triggerLabel || '—'}</span>
        <span style={{ color: 'var(--text-secondary)' }}> {tpl.triggerEvent}</span>
      </div>
      <div>
        <span style={{ color: 'var(--success)', fontWeight: 600 }}>Then </span>
        <span>{verb} </span>
        {targets && targets.length > 0 ? (
          <span style={{ fontWeight: 600 }}>
            {targets.map(t => t.label).join(', ')}
          </span>
        ) : (
          <span style={{ color: 'var(--text-secondary)' }}>selected lights</span>
        )}
        <span>{tail}</span>
      </div>
    </div>
  );
};

// ── The sheet itself ─────────────────────────────────────────
const CreateRuleSheet = ({ variant = 'template', onClose }) => {
  // two scripted variants for preview
  const data = variant === 'fields'
    ? {
        ruleName: 'Motion turns on lab lights',
        templateId: 'motion_on',
        triggerId: '0000000000000053',
        targetIds: ['000000000000004F', '0000000000000055'],
        enabled: true,
      }
    : {
        ruleName: '',
        templateId: null,
        triggerId: null,
        targetIds: [],
        enabled: true,
      };

  const selectedTpl = data.templateId ? tmpl(data.templateId) : null;
  const triggers = selectedTpl
    ? AUTO_DEVICES.filter(d => d.type === selectedTpl.triggerType)
    : [];
  const lights = AUTO_DEVICES.filter(d => d.type === 'light');
  const selectedTargets = lights.filter(l => data.targetIds.includes(l.id));
  const triggerLabel = data.triggerId
    ? AUTO_DEVICES.find(d => d.id === data.triggerId)?.label
    : null;

  const canSave = data.ruleName && data.templateId && data.triggerId && data.targetIds.length > 0;

  return (
    <div style={{
      position: 'absolute', inset: 0,
      display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
      pointerEvents: 'auto',
    }}>
      {/* scrim */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'var(--scrim)', backdropFilter: 'blur(6px)',
        WebkitBackdropFilter: 'blur(6px)',
      }} onClick={onClose}/>

      {/* sheet */}
      <div style={{
        position: 'relative',
        background: 'var(--surface-elevated)',
        borderTopLeftRadius: 24, borderTopRightRadius: 24,
        boxShadow: 'var(--elev-2)',
        maxHeight: '88%', display: 'flex', flexDirection: 'column',
        animation: 'sheetUp 240ms var(--ease-standard)',
      }}>
        {/* grabber */}
        <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0 0' }}>
          <div style={{
            width: 38, height: 4, borderRadius: 999, background: 'var(--border)',
          }}/>
        </div>

        {/* sheet header */}
        <div style={{
          padding: '8px 16px 12px', display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 17, fontWeight: 600 }}>New rule</div>
            <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 2 }}>
              When something happens, do something.
            </div>
          </div>
          <IconBtn icon="x" onClick={onClose} />
        </div>

        {/* form body — scrollable */}
        <div style={{
          flex: 1, overflowY: 'auto', overflowX: 'hidden',
          padding: '4px 16px 16px',
          display: 'flex', flexDirection: 'column', gap: 16,
        }}>
          {/* rule name */}
          <Field label="Rule name" required>
            <TextField value={data.ruleName} placeholder="e.g. Motion turns on lab lights" />
          </Field>

          {/* template picker */}
          <Field label="Template" required hint={selectedTpl ? selectedTpl.title : '1 of 4'}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
              {TEMPLATES.map(t => (
                <TemplateCard key={t.id} tpl={t} selected={data.templateId === t.id} />
              ))}
            </div>
          </Field>

          {/* trigger device — only meaningful once template chosen */}
          <Field
            label="Trigger device"
            required
            hint={selectedTpl ? `${triggers.length} ${selectedTpl.triggerType} available` : 'pick a template first'}
          >
            {selectedTpl ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {triggers.map(d => (
                  <DeviceRow key={d.id} dev={d} selected={data.triggerId === d.id} kind="radio" />
                ))}
                {triggers.length === 0 && (
                  <div style={{
                    background: 'var(--warning-tint)', color: 'var(--warning)',
                    border: '1px solid color-mix(in oklab, var(--warning) 25%, transparent)',
                    borderRadius: 12, padding: '10px 12px',
                    fontSize: 12, display: 'flex', alignItems: 'center', gap: 8,
                  }}>
                    <i data-lucide="triangle-alert" style={{ width: 14, height: 14 }}></i>
                    No {selectedTpl.triggerType} devices available
                  </div>
                )}
              </div>
            ) : (
              <div style={{
                background: 'var(--surface)', border: '1px dashed var(--border)',
                borderRadius: 12, padding: '14px 12px', textAlign: 'center',
                fontSize: 12, color: 'var(--text-secondary)',
              }}>
                Choose a template above
              </div>
            )}
          </Field>

          {/* target lights — only meaningful once template chosen */}
          <Field
            label="Target lights"
            required
            hint={selectedTpl
              ? `${data.targetIds.length} selected${selectedTpl.targetLimit ? ` / ${selectedTpl.targetLimit}` : ''}`
              : 'pick a template first'}
          >
            {selectedTpl ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {lights.map(d => (
                  <DeviceRow
                    key={d.id} dev={d}
                    selected={data.targetIds.includes(d.id)}
                    kind={selectedTpl.targetLimit === 1 ? 'radio' : 'check'}
                  />
                ))}
              </div>
            ) : (
              <div style={{
                background: 'var(--surface)', border: '1px dashed var(--border)',
                borderRadius: 12, padding: '14px 12px', textAlign: 'center',
                fontSize: 12, color: 'var(--text-secondary)',
              }}>
                Choose a template above
              </div>
            )}
          </Field>

          {/* enabled toggle */}
          <Field label="Enabled" hint="active immediately after save">
            <div style={{
              display: 'flex', alignItems: 'center',
              background: 'var(--surface)', border: '1px solid var(--border)',
              borderRadius: 12, padding: '10px 12px', gap: 10,
            }}>
              <Switch on={data.enabled} />
              <span style={{ fontSize: 13, color: 'var(--text-primary)' }}>
                {data.enabled ? 'On — rule is active' : 'Off — rule saved but not running'}
              </span>
            </div>
          </Field>

          {/* plain-language preview */}
          {selectedTpl && (
            <Field label="Preview">
              <RulePreview
                tpl={selectedTpl}
                triggerLabel={triggerLabel}
                targets={selectedTargets}
              />
            </Field>
          )}
        </div>

        {/* sticky footer */}
        <div style={{
          borderTop: '1px solid var(--border)',
          padding: 12, display: 'flex', gap: 10,
          background: 'var(--surface-elevated)',
        }}>
          <button onClick={onClose} style={{
            flex: '0 0 auto', padding: '12px 16px', borderRadius: 12,
            background: 'transparent', border: '1px solid var(--border)',
            fontFamily: 'inherit', fontSize: 14, fontWeight: 600,
            color: 'var(--text-primary)', cursor: 'pointer',
          }}>Cancel</button>
          <button disabled={!canSave} style={{
            flex: 1, padding: '12px 16px', borderRadius: 12,
            background: canSave ? 'var(--primary)' : 'rgb(107 114 128 / 0.22)',
            color: canSave ? 'var(--primary-on)' : 'var(--text-secondary)',
            border: 'none', fontFamily: 'inherit', fontSize: 14, fontWeight: 600,
            cursor: canSave ? 'pointer' : 'not-allowed',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          }}>
            <i data-lucide="check" style={{ width: 16, height: 16 }}></i>
            Save rule
          </button>
        </div>
      </div>
    </div>
  );
};

window.CreateRuleSheet = CreateRuleSheet;
