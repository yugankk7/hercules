/* @ds-bundle: {"format":3,"namespace":"HerculesDesignSystem_3f35fc","components":[{"name":"LogoMark","sourcePath":"components/brand/LogoMark.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"OversizedScore","sourcePath":"components/core/OversizedScore.jsx"},{"name":"StatusPill","sourcePath":"components/core/StatusPill.jsx"},{"name":"DataDomainItem","sourcePath":"components/data/DataDomainItem.jsx"},{"name":"StatRow","sourcePath":"components/data/StatRow.jsx"},{"name":"ProgressReadout","sourcePath":"components/feedback/ProgressReadout.jsx"},{"name":"ScreenHeader","sourcePath":"components/navigation/ScreenHeader.jsx"},{"name":"SegmentedToggle","sourcePath":"components/navigation/SegmentedToggle.jsx"},{"name":"BarStrip","sourcePath":"components/viz/BarStrip.jsx"},{"name":"TrendChart","sourcePath":"components/viz/TrendChart.jsx"}],"sourceHashes":{"components/brand/LogoMark.jsx":"1c9a77ca058b","components/core/Button.jsx":"b1820c9d3da5","components/core/Card.jsx":"f5ac766d65d3","components/core/OversizedScore.jsx":"73c3f33b2771","components/core/StatusPill.jsx":"248da81350ed","components/data/DataDomainItem.jsx":"7cf6b1657f3c","components/data/StatRow.jsx":"4568f653ffd0","components/feedback/ProgressReadout.jsx":"d95cc0c35c9e","components/navigation/ScreenHeader.jsx":"1af1ceb13127","components/navigation/SegmentedToggle.jsx":"94ceacae1e61","components/viz/BarStrip.jsx":"e1371bfbf276","components/viz/TrendChart.jsx":"d4ebffe8ce48","ui_kits/hercules-app/DashboardScreen.jsx":"6ecb268d1e26","ui_kits/hercules-app/OnboardingScreen.jsx":"b3520ac32c08","ui_kits/hercules-app/PhoneFrame.jsx":"b5a7beff52b3","ui_kits/hercules-app/SleepDetailScreen.jsx":"6f22ba598399","ui_kits/hercules-app/SyncScreen.jsx":"59b8e8b81a0f"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.HerculesDesignSystem_3f35fc = window.HerculesDesignSystem_3f35fc || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/brand/LogoMark.jsx
try { (() => {
/**
 * LogoMark — the Hercules instrument mark: a rounded square holding four
 * encoding bars (two orange peaks) with a live orange node at the corner.
 * Pure CSS/inline; scales by `size`.
 */
function LogoMark({
  size = 104,
  style = {}
}) {
  const s = size / 104; // scale factor from the canonical 104px mark
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: size + "px",
      height: size + "px",
      border: `${2.5 * s}px solid var(--hc-accent)`,
      borderRadius: 26 * s + "px",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      position: "relative",
      flexShrink: 0,
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "flex-end",
      gap: 5 * s + "px",
      height: 46 * s + "px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 9 * s + "px",
      height: "42%",
      background: "var(--hc-muted)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 9 * s + "px",
      height: "70%",
      background: "var(--hc-accent)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 9 * s + "px",
      height: "100%",
      background: "var(--hc-accent)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 9 * s + "px",
      height: "56%",
      background: "var(--hc-muted)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: -8 * s + "px",
      right: -8 * s + "px",
      width: 20 * s + "px",
      height: 20 * s + "px",
      borderRadius: "999px",
      background: "var(--hc-accent)",
      border: `${3 * s}px solid #000`
    }
  }));
}
Object.assign(__ds_scope, { LogoMark });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/brand/LogoMark.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Button — Hercules primary pill CTA & secondary outline.
 * Orange fill / black label for primary; slate outline for secondary;
 * bare text for ghost. Full-width by default (stacks in onboarding).
 */
function Button({
  children,
  variant = "primary",
  size = "lg",
  fullWidth = true,
  trailingIcon = false,
  disabled = false,
  style = {},
  ...rest
}) {
  const heights = {
    lg: "var(--hc-cta-height)",
    md: "48px",
    sm: "38px"
  };
  const pads = {
    lg: "0 26px",
    md: "0 22px",
    sm: "0 16px"
  };
  const fonts = {
    lg: "14px",
    md: "13px",
    sm: "12px"
  };
  const base = {
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    gap: "10px",
    height: heights[size],
    padding: pads[size],
    width: fullWidth ? "100%" : "auto",
    border: "none",
    borderRadius: "var(--hc-radius-pill)",
    fontFamily: "var(--hc-font-mono)",
    fontSize: fonts[size],
    fontWeight: "var(--hc-w-black)",
    letterSpacing: "var(--hc-ls-title)",
    textTransform: "uppercase",
    cursor: disabled ? "not-allowed" : "pointer",
    transition: "transform .12s var(--hc-ease-snap), opacity .12s ease, background .15s ease",
    opacity: disabled ? 0.4 : 1
  };
  const variants = {
    primary: {
      background: "var(--hc-accent)",
      color: "#000"
    },
    secondary: {
      background: "transparent",
      color: "var(--hc-text)",
      border: "1px solid var(--hc-secondary)",
      fontWeight: "var(--hc-w-bold)"
    },
    ghost: {
      background: "transparent",
      color: "var(--hc-accent)",
      fontWeight: "var(--hc-w-bold)",
      letterSpacing: "var(--hc-ls-label)"
    }
  };
  const onDown = e => {
    if (!disabled) e.currentTarget.style.transform = "scale(0.97)";
  };
  const onUp = e => {
    e.currentTarget.style.transform = "scale(1)";
  };
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    disabled: disabled,
    onMouseDown: onDown,
    onMouseUp: onUp,
    onMouseLeave: onUp,
    style: {
      ...base,
      ...variants[variant],
      ...style
    }
  }, rest), children, trailingIcon && /*#__PURE__*/React.createElement("svg", {
    width: "16",
    height: "13",
    viewBox: "0 0 16 13",
    fill: "none",
    "aria-hidden": "true"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M1 6.5h13M9 1.5l5 5-5 5",
    stroke: "currentColor",
    strokeWidth: "2",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  })));
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Card — Hercules raised panel. Near-black fill, 1px slate-ish border,
 * 16px soft-square corners. Optional eyebrow label (orange) + sublabel.
 * Depth comes from the border + darker fill, never a drop shadow.
 */
function Card({
  children,
  eyebrow,
  sublabel,
  tone = "deep",
  padding,
  style = {},
  ...rest
}) {
  const fills = {
    deep: "var(--hc-surface-deep)",
    card: "var(--hc-surface-card)",
    flat: "transparent"
  };
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      background: fills[tone],
      border: "1px solid var(--hc-hairline)",
      borderRadius: "var(--hc-radius-card)",
      padding: padding || "28px 30px",
      fontFamily: "var(--hc-font-mono)",
      color: "var(--hc-text)",
      ...style
    }
  }, rest), eyebrow && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: "11px",
      fontWeight: "var(--hc-w-bold)",
      letterSpacing: "var(--hc-ls-eyebrow)",
      color: "var(--hc-accent)",
      marginBottom: sublabel ? "6px" : "20px"
    }
  }, eyebrow), sublabel && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: "11px",
      fontWeight: "var(--hc-w-medium)",
      color: "var(--hc-text-40)",
      marginBottom: "22px",
      lineHeight: 1.5
    }
  }, sublabel), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/OversizedScore.jsx
try { (() => {
/**
 * OversizedScore — the focal numeral on any detail screen.
 * Huge orange figure with a muted unit suffix and an optional
 * classification pill aligned to the baseline.
 */
function OversizedScore({
  value = "8.1",
  unit = "/10",
  classification,
  classTone = "accent",
  size = 96,
  style = {}
}) {
  const cls = classTone === "muted" ? "var(--hc-muted)" : "var(--hc-accent)";
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "flex-end",
      justifyContent: "space-between",
      fontFamily: "var(--hc-font-mono)",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "flex-start"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: size + "px",
      fontWeight: "var(--hc-w-black)",
      color: "var(--hc-accent)",
      lineHeight: 0.78,
      letterSpacing: "-5px",
      fontVariantNumeric: "tabular-nums"
    }
  }, value), unit && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: Math.round(size * 0.25) + "px",
      fontWeight: "var(--hc-w-semibold)",
      color: "var(--hc-muted)",
      marginTop: "7px",
      marginLeft: "5px"
    }
  }, unit)), classification && /*#__PURE__*/React.createElement("span", {
    style: {
      border: `1.5px solid ${cls}`,
      color: cls,
      borderRadius: "var(--hc-radius-pill)",
      padding: "6px 16px",
      fontSize: "12px",
      fontWeight: "var(--hc-w-bold)",
      letterSpacing: "2.5px",
      marginBottom: "10px",
      textTransform: "uppercase"
    }
  }, classification));
}
Object.assign(__ds_scope, { OversizedScore });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/OversizedScore.jsx", error: String((e && e.message) || e) }); }

// components/core/StatusPill.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * StatusPill — classification / status chip.
 * Outlined for class (good/fair/low), filled for the primary/active state,
 * and a "live" variant with a leading dot for syncing/active telemetry.
 */
function StatusPill({
  children,
  variant = "class",
  tone = "accent",
  live = false,
  style = {},
  ...rest
}) {
  const toneColor = tone === "muted" ? "var(--hc-muted)" : "var(--hc-accent)";
  const base = {
    display: "inline-flex",
    alignItems: "center",
    gap: "6px",
    fontFamily: "var(--hc-font-mono)",
    fontWeight: "var(--hc-w-bold)",
    letterSpacing: "var(--hc-ls-label)",
    textTransform: "uppercase",
    whiteSpace: "nowrap"
  };
  let look;
  if (variant === "filled") {
    look = {
      background: "var(--hc-accent)",
      color: "#000",
      borderRadius: "var(--hc-radius-pill)",
      padding: "7px 18px",
      fontSize: "12px",
      fontWeight: "var(--hc-w-black)",
      letterSpacing: "var(--hc-ls-eyebrow)"
    };
  } else if (variant === "live") {
    look = {
      color: toneColor,
      fontSize: "11px",
      letterSpacing: "var(--hc-ls-label)"
    };
  } else {
    look = {
      border: `1.5px solid ${toneColor}`,
      color: toneColor,
      borderRadius: "var(--hc-radius-pill)",
      padding: "6px 16px",
      fontSize: "12px",
      letterSpacing: "var(--hc-ls-eyebrow)"
    };
  }
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      ...base,
      ...look,
      ...style
    }
  }, rest), (live || variant === "live") && /*#__PURE__*/React.createElement("span", {
    style: {
      width: "6px",
      height: "6px",
      borderRadius: "999px",
      background: toneColor,
      display: "inline-block"
    }
  }), children);
}
Object.assign(__ds_scope, { StatusPill });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/StatusPill.jsx", error: String((e && e.message) || e) }); }

// components/data/DataDomainItem.jsx
try { (() => {
/**
 * DataDomainItem — slate list row: glyph tile + label/sublabel + state.
 * The connect/check node on the right shows connected (filled orange
 * check) or a chevron to drill in.
 */
function DataDomainItem({
  glyph = "Z",
  label,
  sublabel,
  state = "connected",
  onClick,
  style = {}
}) {
  return /*#__PURE__*/React.createElement("button", {
    type: "button",
    onClick: onClick,
    style: {
      display: "flex",
      alignItems: "center",
      gap: "13px",
      width: "100%",
      textAlign: "left",
      background: "var(--hc-surface-card)",
      border: "1px solid var(--hc-border)",
      borderRadius: "var(--hc-radius-row)",
      padding: "13px 15px",
      fontFamily: "var(--hc-font-mono)",
      color: "var(--hc-text)",
      cursor: "pointer",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: "34px",
      height: "34px",
      borderRadius: "var(--hc-radius-tile)",
      background: "var(--hc-secondary)",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize: "14px",
      fontWeight: "var(--hc-w-black)",
      color: "var(--hc-accent)",
      flexShrink: 0
    }
  }, glyph), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: "13px",
      fontWeight: "var(--hc-w-bold)"
    }
  }, label), sublabel && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: "9.5px",
      fontWeight: "var(--hc-w-medium)",
      color: "var(--hc-text-40)",
      marginTop: "2px"
    }
  }, sublabel)), state === "connected" ? /*#__PURE__*/React.createElement("span", {
    style: {
      width: "20px",
      height: "20px",
      borderRadius: "999px",
      background: "var(--hc-accent)",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: "11",
    height: "9",
    viewBox: "0 0 11 9",
    fill: "none"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M1 4.5 4 7.5 10 1",
    stroke: "#000",
    strokeWidth: "1.8",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }))) : /*#__PURE__*/React.createElement("svg", {
    width: "8",
    height: "14",
    viewBox: "0 0 8 14",
    fill: "none",
    style: {
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M1 1l6 6-6 6",
    stroke: "var(--hc-muted)",
    strokeWidth: "1.8",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  })));
}
Object.assign(__ds_scope, { DataDomainItem });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/DataDomainItem.jsx", error: String((e && e.message) || e) }); }

// components/data/StatRow.jsx
try { (() => {
/**
 * StatRow — divided stat cells. First value accents orange; subsequent
 * cells are off-white with muted units. Cells are separated by 1px rules.
 */
function StatRow({
  stats = [],
  style = {}
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      fontFamily: "var(--hc-font-mono)",
      ...style
    }
  }, stats.map((s, i) => {
    const first = i === 0;
    const last = i === stats.length - 1;
    return /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        flex: s.flex || 1,
        borderRight: last ? "none" : "1px solid var(--hc-hairline)",
        paddingRight: last ? 0 : "10px",
        paddingLeft: first ? 0 : "10px"
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: "9px",
        fontWeight: "var(--hc-w-semibold)",
        letterSpacing: "var(--hc-ls-label)",
        color: "var(--hc-text-40)"
      }
    }, s.label), /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: (s.size || 19) + "px",
        fontWeight: "var(--hc-w-bold)",
        marginTop: "6px",
        color: first ? "var(--hc-accent)" : "var(--hc-text)",
        fontVariantNumeric: "tabular-nums"
      }
    }, s.value, s.unit && /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: "12px",
        color: "var(--hc-muted)"
      }
    }, s.unit)));
  }));
}
Object.assign(__ds_scope, { StatRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/StatRow.jsx", error: String((e && e.message) || e) }); }

// components/feedback/ProgressReadout.jsx
try { (() => {
/**
 * ProgressReadout — the terminal progress pattern. The ONLY loading
 * treatment Hercules allows (no spinners). Big orange percent, a thin
 * fill bar, and domain rows that light up top-down with tick meters.
 */
function ProgressReadout({
  percent = 68,
  rows = [],
  style = {}
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--hc-font-mono)",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "flex-end",
      gap: "5px",
      marginBottom: "10px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: "46px",
      fontWeight: "var(--hc-w-black)",
      color: "var(--hc-accent)",
      lineHeight: 0.8,
      letterSpacing: "-2px",
      fontVariantNumeric: "tabular-nums"
    }
  }, percent), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: "18px",
      fontWeight: "var(--hc-w-bold)",
      color: "var(--hc-muted)",
      marginBottom: "5px"
    }
  }, "%")), /*#__PURE__*/React.createElement("div", {
    style: {
      height: "7px",
      borderRadius: "999px",
      background: "var(--hc-hairline)",
      overflow: "hidden",
      marginBottom: "18px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: percent + "%",
      height: "100%",
      background: "var(--hc-accent)",
      borderRadius: "999px",
      transition: "width .3s var(--hc-ease-out)"
    }
  })), rows.map((r, i) => {
    const done = r.state === "done";
    const idle = r.state === "idle";
    const dot = done ? "var(--hc-accent)" : idle ? "var(--hc-secondary)" : "var(--hc-accent-med)";
    const nameColor = idle ? "var(--hc-faint)" : "var(--hc-text)";
    const statColor = done ? "var(--hc-text)" : idle ? "var(--hc-faint)" : "var(--hc-accent)";
    return /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        display: "flex",
        alignItems: "center",
        gap: "11px",
        padding: "7px 0",
        borderBottom: "1px solid var(--hc-hairline-faint)"
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        width: "8px",
        height: "8px",
        borderRadius: "2px",
        background: dot
      }
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        width: "90px",
        fontSize: "11px",
        fontWeight: "var(--hc-w-bold)",
        letterSpacing: "1px",
        color: nameColor
      }
    }, r.name), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        fontSize: "10px",
        fontWeight: "var(--hc-w-semibold)",
        letterSpacing: "1px",
        color: "var(--hc-faint)"
      }
    }, r.ticks), /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: "11px",
        fontWeight: "var(--hc-w-bold)",
        color: statColor
      }
    }, r.stat));
  }));
}
Object.assign(__ds_scope, { ProgressReadout });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/ProgressReadout.jsx", error: String((e && e.message) || e) }); }

// components/navigation/SegmentedToggle.jsx
try { (() => {
/**
 * SegmentedToggle — day/week style range switch. Active segment fills
 * orange with black label; inactive segments are muted text.
 */
function SegmentedToggle({
  options = ["DAY", "WK"],
  value,
  onChange,
  style = {}
}) {
  const active = value ?? options[0];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "inline-flex",
      flexShrink: 0,
      border: "1px solid var(--hc-secondary)",
      borderRadius: "var(--hc-radius-pill)",
      overflow: "hidden",
      fontFamily: "var(--hc-font-mono)",
      fontSize: "10px",
      fontWeight: "var(--hc-w-bold)",
      letterSpacing: "1px",
      ...style
    }
  }, options.map(opt => {
    const on = opt === active;
    return /*#__PURE__*/React.createElement("button", {
      key: opt,
      type: "button",
      onClick: () => onChange && onChange(opt),
      style: {
        padding: "7px 11px",
        border: "none",
        cursor: "pointer",
        fontFamily: "inherit",
        fontSize: "inherit",
        fontWeight: "inherit",
        letterSpacing: "inherit",
        textTransform: "uppercase",
        background: on ? "var(--hc-accent)" : "transparent",
        color: on ? "#000" : "var(--hc-text-50)",
        transition: "background .15s ease, color .15s ease"
      }
    }, opt);
  }));
}
Object.assign(__ds_scope, { SegmentedToggle });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/SegmentedToggle.jsx", error: String((e && e.message) || e) }); }

// components/navigation/ScreenHeader.jsx
try { (() => {
/**
 * ScreenHeader — back chevron · centered spaced title + date · optional
 * segmented range toggle. The standard top bar for a detail screen.
 */
function ScreenHeader({
  title,
  subtitle,
  onBack,
  toggle,
  style = {}
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: "10px",
      fontFamily: "var(--hc-font-mono)",
      ...style
    }
  }, /*#__PURE__*/React.createElement("button", {
    type: "button",
    onClick: onBack,
    style: {
      width: "34px",
      height: "34px",
      flexShrink: 0,
      padding: 0,
      cursor: "pointer",
      border: "1px solid var(--hc-secondary)",
      borderRadius: "999px",
      background: "transparent",
      display: "flex",
      alignItems: "center",
      justifyContent: "center"
    },
    "aria-label": "Back"
  }, /*#__PURE__*/React.createElement("svg", {
    width: "9",
    height: "15",
    viewBox: "0 0 9 15",
    fill: "none"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M7.5 1.5 1.5 7.5l6 6",
    stroke: "var(--hc-text)",
    strokeWidth: "1.8",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      textAlign: "center",
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: "13px",
      fontWeight: "var(--hc-w-bold)",
      letterSpacing: "var(--hc-ls-title)",
      textTransform: "uppercase",
      color: "var(--hc-text)"
    }
  }, title), subtitle && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: "10px",
      fontWeight: "var(--hc-w-medium)",
      letterSpacing: "var(--hc-ls-label)",
      color: "var(--hc-text-42, rgba(234,236,240,0.42))",
      marginTop: "4px"
    }
  }, subtitle)), toggle ? /*#__PURE__*/React.createElement(__ds_scope.SegmentedToggle, {
    options: toggle.options,
    value: toggle.value,
    onChange: toggle.onChange
  }) : /*#__PURE__*/React.createElement("div", {
    style: {
      width: "34px",
      flexShrink: 0
    }
  }));
}
Object.assign(__ds_scope, { ScreenHeader });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/ScreenHeader.jsx", error: String((e && e.message) || e) }); }

// components/viz/BarStrip.jsx
try { (() => {
const LEVELS = {
  HIGH: "var(--hc-level-high)",
  MED: "var(--hc-level-med)",
  LOW: "var(--hc-level-low)",
  VERY_LOW: "var(--hc-level-very-low)",
  MINIMAL: "var(--hc-level-minimal)"
};

/**
 * BarStrip — the signature Hercules viz. Height + color encode level;
 * bars draw in left-to-right with a staggered grow animation. Optional
 * gate band, marker tail and timeline node ride over the strip.
 *
 * `bars` is an array of { level, h } or numbers 0–100 (auto-binned).
 */
function BarStrip({
  bars = [],
  height = 120,
  gateStart = null,
  // 0–1 fraction
  gateWidth = 0.06,
  marker = null,
  // 0–1 fraction → marker tail + node
  animate = true,
  footer,
  style = {}
}) {
  const resolved = bars.map(b => {
    if (typeof b === "number") {
      const lvl = b >= 80 ? "HIGH" : b >= 60 ? "MED" : b >= 40 ? "LOW" : b >= 22 ? "VERY_LOW" : "MINIMAL";
      return {
        color: LEVELS[lvl],
        h: b
      };
    }
    return {
      color: LEVELS[b.level] || LEVELS.LOW,
      h: b.h ?? 50
    };
  });
  return /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--hc-font-mono)",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      height: height + "px"
    }
  }, gateStart != null && /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: "-5px",
      bottom: 0,
      left: gateStart * 100 + "%",
      width: gateWidth * 100 + "%",
      background: "var(--hc-gate-band)",
      borderLeft: "1px dashed var(--hc-accent-line)",
      borderRight: "1px dashed var(--hc-accent-line)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "flex-end",
      gap: "4px",
      height: "100%",
      position: "relative",
      zIndex: 1
    }
  }, resolved.map((b, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      flex: 1,
      height: b.h + "%",
      background: b.color,
      borderRadius: "2px 2px 0 0",
      transformOrigin: "bottom",
      animation: animate ? `hc-grow 0.5s var(--hc-ease-snap) both` : "none",
      animationDelay: animate ? (i * 0.04).toFixed(3) + "s" : "0s"
    }
  }))), marker != null && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: marker * 100 + "%",
      right: 0,
      bottom: "-1px",
      height: "2px",
      background: "var(--hc-marker-fade)",
      borderRadius: "2px",
      zIndex: 2
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: `calc(${marker * 100}% - 5px)`,
      bottom: "-4px",
      width: "10px",
      height: "10px",
      borderRadius: "999px",
      background: "var(--hc-accent)",
      border: "2px solid #000",
      zIndex: 3
    }
  }))), footer && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      marginTop: "12px",
      fontSize: "9px",
      fontWeight: "var(--hc-w-semibold)",
      letterSpacing: "1px",
      color: "var(--hc-text-35)"
    }
  }, footer));
}
Object.assign(__ds_scope, { BarStrip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/viz/BarStrip.jsx", error: String((e && e.message) || e) }); }

// components/viz/TrendChart.jsx
try { (() => {
/**
 * TrendChart — sparkline of bars in an inset well. Peaks at/above
 * `target` turn orange; the rest sit in muted track-blue.
 */
function TrendChart({
  data = [],
  target = 8,
  max = 10,
  label = "28-DAY",
  avg,
  height = 46,
  style = {}
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--hc-surface-card)",
      border: "1px solid var(--hc-hairline)",
      borderRadius: "12px",
      padding: "14px 16px",
      fontFamily: "var(--hc-font-mono)",
      ...style
    }
  }, (label || avg != null) && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      marginBottom: "12px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: "10px",
      fontWeight: "var(--hc-w-semibold)",
      letterSpacing: "var(--hc-ls-eyebrow)",
      color: "var(--hc-text-45)"
    }
  }, label), avg != null && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: "10px",
      fontWeight: "var(--hc-w-bold)",
      color: "var(--hc-muted)"
    }
  }, "AVG ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--hc-text)"
    }
  }, avg))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "flex-end",
      gap: "3px",
      height: height + "px"
    }
  }, data.map((v, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      flex: 1,
      height: Math.round(v / max * 100) + "%",
      background: v >= target ? "var(--hc-accent)" : "var(--hc-level-track)",
      borderRadius: "1px"
    }
  }))));
}
Object.assign(__ds_scope, { TrendChart });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/viz/TrendChart.jsx", error: String((e && e.message) || e) }); }

// ui_kits/hercules-app/DashboardScreen.jsx
try { (() => {
// DashboardScreen — Hercules home: today's readiness score + domain cards.
function DashboardScreen({
  onOpenSleep
}) {
  const {
    OversizedScore,
    StatusPill,
    Card,
    BarStrip,
    StatRow,
    LogoMark
  } = window.HerculesDesignSystem_3f35fc;
  const L = ["LOW", "MED", "HIGH", "HIGH", "MED", "MED", "LOW", "MED", "HIGH", "HIGH", "MED", "LOW", "VERY_LOW", "MINIMAL"];
  const map = {
    HIGH: 92,
    MED: 64,
    LOW: 46,
    VERY_LOW: 32,
    MINIMAL: 20
  };
  const bars = L.map(level => ({
    level,
    h: map[level]
  }));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: "100%",
      overflowY: "auto",
      padding: "16px 20px 30px",
      color: "var(--hc-text)",
      fontFamily: "var(--hc-font-mono)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      marginBottom: 22
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(LogoMark, {
    size: 30
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      fontWeight: 700,
      letterSpacing: 2
    }
  }, "TODAY \xB7 WED 23")), /*#__PURE__*/React.createElement(StatusPill, {
    variant: "live"
  }, "Synced 6:02")), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10,
      fontWeight: 700,
      letterSpacing: 2,
      color: "var(--hc-accent)",
      marginBottom: 4
    }
  }, "READINESS"), /*#__PURE__*/React.createElement(OversizedScore, {
    value: "8.1",
    unit: "/10",
    classification: "Fair",
    size: 84
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12.5,
      fontWeight: 500,
      color: "var(--hc-text-50)",
      marginTop: 14,
      lineHeight: 1.5
    }
  }, "Decent rest, steady day ahead. Sleep carried the score; activity load is light."), /*#__PURE__*/React.createElement("div", {
    onClick: onOpenSleep,
    style: {
      marginTop: 22,
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement(Card, {
    tone: "card",
    eyebrow: "BOOST FROM SLEEP",
    sublabel: "7H 19M \xB7 tap for the full breakdown",
    padding: "22px 22px"
  }, /*#__PURE__*/React.createElement(BarStrip, {
    bars: bars,
    height: 84,
    marker: 0.9
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 18
    }
  }, /*#__PURE__*/React.createElement(StatRow, {
    stats: [{
      label: "INERTIA",
      value: "MILD"
    }, {
      label: "DURATION",
      value: /*#__PURE__*/React.createElement(React.Fragment, null, "7", /*#__PURE__*/React.createElement("span", {
        style: {
          fontSize: 12,
          color: "var(--hc-muted)"
        }
      }, "H"), "19", /*#__PURE__*/React.createElement("span", {
        style: {
          fontSize: 12,
          color: "var(--hc-muted)"
        }
      }, "M"))
    }, {
      label: "EFFICIENCY",
      value: "92%",
      flex: 1.1
    }]
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: 12,
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement(Card, {
    tone: "card",
    eyebrow: "RESTING HR",
    padding: "18px 20px"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 36,
      fontWeight: 800,
      color: "var(--hc-text)",
      letterSpacing: -1,
      lineHeight: 1
    }
  }, "48", /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 14,
      color: "var(--hc-muted)",
      marginLeft: 4
    }
  }, "BPM")), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10,
      fontWeight: 600,
      color: "var(--hc-accent)",
      marginTop: 8,
      letterSpacing: 1
    }
  }, "\u25BC 2 vs 7-DAY")), /*#__PURE__*/React.createElement(Card, {
    tone: "card",
    eyebrow: "ACTIVITY",
    padding: "18px 20px"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 36,
      fontWeight: 800,
      color: "var(--hc-text)",
      letterSpacing: -1,
      lineHeight: 1
    }
  }, "17", /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 14,
      color: "var(--hc-muted)",
      marginLeft: 4
    }
  }, "MIN")), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10,
      fontWeight: 600,
      color: "var(--hc-muted)",
      marginTop: 8,
      letterSpacing: 1
    }
  }, "LIGHT LOAD"))));
}
window.DashboardScreen = DashboardScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/hercules-app/DashboardScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/hercules-app/OnboardingScreen.jsx
try { (() => {
// OnboardingScreen — "Grant Access": connect data sources, then commit.
function OnboardingScreen({
  onConnect
}) {
  const {
    Button,
    StatusPill,
    DataDomainItem,
    LogoMark
  } = window.HerculesDesignSystem_3f35fc;
  const [sources, setSources] = React.useState({
    sleep: true,
    hr: true,
    activity: false,
    workouts: false
  });
  const toggle = k => setSources(s => ({
    ...s,
    [k]: !s[k]
  }));
  const domains = [{
    k: "sleep",
    glyph: "Z",
    label: "SLEEP",
    sub: "Stages, duration, SleepWise"
  }, {
    k: "hr",
    glyph: "H",
    label: "HEART RATE",
    sub: "Continuous + resting HR"
  }, {
    k: "activity",
    glyph: "A",
    label: "ACTIVITY",
    sub: "Steps, move minutes, load"
  }, {
    k: "workouts",
    glyph: "W",
    label: "WORKOUTS",
    sub: "Sessions, strain, recovery"
  }];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: "100%",
      display: "flex",
      flexDirection: "column",
      padding: "20px 22px 26px",
      color: "var(--hc-text)",
      fontFamily: "var(--hc-font-mono)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      marginBottom: 30,
      animation: "hc-snap-in .4s var(--hc-ease-snap) both"
    }
  }, /*#__PURE__*/React.createElement(LogoMark, {
    size: 44
  }), /*#__PURE__*/React.createElement(StatusPill, {
    variant: "live"
  }, "Secure OAuth")), /*#__PURE__*/React.createElement("div", {
    style: {
      animation: "hc-snap-in .4s var(--hc-ease-snap) .05s both"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 30,
      fontWeight: 800,
      letterSpacing: -1,
      lineHeight: 0.95
    }
  }, "GRANT", /*#__PURE__*/React.createElement("br", null), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--hc-accent)"
    }
  }, "ACCESS")), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12.5,
      fontWeight: 500,
      color: "var(--hc-text-50)",
      marginTop: 16,
      lineHeight: 1.6,
      maxWidth: 300
    }
  }, "Choose the telemetry Hercules reads. Connect once \u2014 the sync happens in the background, every morning.")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 10,
      marginTop: 28
    }
  }, domains.map((d, i) => /*#__PURE__*/React.createElement("div", {
    key: d.k,
    style: {
      animation: `hc-snap-in .4s var(--hc-ease-snap) ${0.1 + i * 0.05}s both`
    }
  }, /*#__PURE__*/React.createElement(DataDomainItem, {
    glyph: d.glyph,
    label: d.label,
    sublabel: d.sub,
    state: sources[d.k] ? "connected" : "drill",
    onClick: () => toggle(d.k)
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      animation: "hc-snap-in .4s var(--hc-ease-snap) .35s both"
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    trailingIcon: true,
    onClick: onConnect
  }, "Connect Polar"), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "center",
      marginTop: 14,
      fontSize: 10,
      fontWeight: 600,
      letterSpacing: 1.5,
      color: "var(--hc-muted)"
    }
  }, "SECURE OAUTH \xB7 ~30S")));
}
window.OnboardingScreen = OnboardingScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/hercules-app/OnboardingScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/hercules-app/PhoneFrame.jsx
try { (() => {
// PhoneFrame — minimal iOS bezel + status bar for the Hercules app kit.
function PhoneFrame({
  children,
  dark = true
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: 390,
      height: 844,
      borderRadius: 52,
      padding: 0,
      background: "#000",
      border: "1px solid #1B2D38",
      boxShadow: "0 30px 80px rgba(0,0,0,0.6)",
      position: "relative",
      overflow: "hidden",
      fontFamily: "var(--hc-font-mono)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: 0,
      left: 0,
      right: 0,
      height: 54,
      zIndex: 20,
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      padding: "0 30px",
      color: "var(--hc-text)",
      fontSize: 13,
      fontWeight: 700,
      letterSpacing: 0.5,
      pointerEvents: "none"
    }
  }, /*#__PURE__*/React.createElement("span", null, "9:41"), /*#__PURE__*/React.createElement("span", {
    style: {
      display: "flex",
      gap: 6,
      alignItems: "center",
      fontSize: 11,
      letterSpacing: 1
    }
  }, /*#__PURE__*/React.createElement("span", null, "5G"), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 22,
      height: 11,
      border: "1px solid var(--hc-muted)",
      borderRadius: 3,
      display: "inline-flex",
      padding: 1.5
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      background: "var(--hc-accent)",
      borderRadius: 1
    }
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: 12,
      left: "50%",
      transform: "translateX(-50%)",
      width: 120,
      height: 30,
      background: "#000",
      borderRadius: 18,
      zIndex: 21
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      paddingTop: 54,
      overflow: "hidden",
      background: "var(--hc-background)"
    }
  }, children));
}
window.PhoneFrame = PhoneFrame;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/hercules-app/PhoneFrame.jsx", error: String((e && e.message) || e) }); }

// ui_kits/hercules-app/SleepDetailScreen.jsx
try { (() => {
// SleepDetailScreen — full "Boost From Sleep" breakdown with the signature strip.
function SleepDetailScreen({
  onBack
}) {
  const {
    ScreenHeader,
    OversizedScore,
    BarStrip,
    StatRow,
    TrendChart,
    Card
  } = window.HerculesDesignSystem_3f35fc;
  const [range, setRange] = React.useState("DAY");
  const pat = ["LOW", "MED", "HIGH", "HIGH", "HIGH", "MED", "MED", "LOW", "MED", "MED", "HIGH", "HIGH", "HIGH", "MED", "LOW", "VERY_LOW", "MINIMAL", "MINIMAL", "MINIMAL"];
  const map = {
    HIGH: 92,
    MED: 64,
    LOW: 46,
    VERY_LOW: 32,
    MINIMAL: 20
  };
  const bars = pat.map(level => ({
    level,
    h: map[level]
  }));
  const trend = [7.2, 6.8, 7.5, 8.0, 7.1, 6.5, 7.8, 8.2, 7.9, 7.0, 6.6, 7.3, 8.1, 7.7, 7.4, 6.9, 7.6, 8.3, 7.2, 6.8, 7.0, 7.9, 8.1, 7.5, 7.1, 6.7, 7.8, 8.1];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: "100%",
      overflowY: "auto",
      padding: "14px 20px 30px",
      color: "var(--hc-text)",
      fontFamily: "var(--hc-font-mono)"
    }
  }, /*#__PURE__*/React.createElement(ScreenHeader, {
    title: "Boost From Sleep",
    subtitle: "Yesterday \xB7 Wed 23",
    onBack: onBack,
    toggle: {
      options: ["DAY", "WK"],
      value: range,
      onChange: setRange
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 26,
      fontSize: 10,
      fontWeight: 700,
      letterSpacing: 2,
      color: "var(--hc-accent)",
      marginBottom: 4
    }
  }, "SLEEP SCORE"), /*#__PURE__*/React.createElement(OversizedScore, {
    value: "8.1",
    unit: "/10",
    classification: "Fair",
    size: 92
  }), /*#__PURE__*/React.createElement(Card, {
    tone: "deep",
    padding: "24px 24px",
    style: {
      marginTop: 24
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      fontWeight: 700,
      letterSpacing: 2,
      color: "var(--hc-accent)",
      marginBottom: 6
    }
  }, "HYPNOGRAM"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      fontWeight: 500,
      color: "var(--hc-text-40)",
      marginBottom: 22
    }
  }, "Height + color encode sleep depth across the night."), /*#__PURE__*/React.createElement(BarStrip, {
    bars: bars,
    height: 120,
    gateStart: 0.84,
    marker: 0.825,
    footer: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("span", null, "WAKE 10:12"), /*#__PURE__*/React.createElement("span", null, "GATE 02:00\u201302:30 \u25B8"))
  })), /*#__PURE__*/React.createElement(Card, {
    tone: "deep",
    padding: "22px 24px",
    style: {
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement(StatRow, {
    stats: [{
      label: "INERTIA",
      value: "MILD"
    }, {
      label: "DURATION",
      value: /*#__PURE__*/React.createElement(React.Fragment, null, "7", /*#__PURE__*/React.createElement("span", {
        style: {
          fontSize: 12,
          color: "var(--hc-muted)"
        }
      }, "H"), "19", /*#__PURE__*/React.createElement("span", {
        style: {
          fontSize: 12,
          color: "var(--hc-muted)"
        }
      }, "M"))
    }, {
      label: "BLOCK",
      value: "02:53–10:12",
      size: 15,
      flex: 1.2
    }]
  })), /*#__PURE__*/React.createElement(Card, {
    tone: "deep",
    eyebrow: "28-DAY TREND",
    sublabel: "Peaks at or above target turn orange.",
    padding: "22px 24px",
    style: {
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement(TrendChart, {
    label: "28-DAY",
    avg: 7.4,
    target: 8,
    data: trend
  })));
}
window.SleepDetailScreen = SleepDetailScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/hercules-app/SleepDetailScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/hercules-app/SyncScreen.jsx
try { (() => {
// SyncScreen — terminal progress readout that races to 100%, then advances.
function SyncScreen({
  onDone
}) {
  const {
    ProgressReadout,
    LogoMark
  } = window.HerculesDesignSystem_3f35fc;
  const [pct, setPct] = React.useState(0);
  React.useEffect(() => {
    let raf, start;
    const dur = 2600;
    const tick = t => {
      if (!start) start = t;
      const e = Math.min(1, (t - start) / dur);
      const eased = 1 - Math.pow(1 - e, 3);
      setPct(Math.round(eased * 100));
      if (e < 1) raf = requestAnimationFrame(tick);else setTimeout(onDone, 450);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, []);
  const rowState = threshold => pct >= threshold ? "done" : pct >= threshold - 34 ? "active" : "idle";
  const ticks = threshold => {
    const filled = Math.max(0, Math.min(10, Math.round((pct - (threshold - 34)) / 34 * 10)));
    return "[" + "|".repeat(filled) + " ".repeat(10 - filled) + "]";
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: "100%",
      display: "flex",
      flexDirection: "column",
      justifyContent: "center",
      padding: "20px 26px",
      color: "var(--hc-text)",
      fontFamily: "var(--hc-font-mono)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12,
      marginBottom: 28
    }
  }, /*#__PURE__*/React.createElement(LogoMark, {
    size: 40
  }), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      fontWeight: 700,
      letterSpacing: 2.5
    }
  }, "SYNCING TELEMETRY"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10,
      fontWeight: 600,
      letterSpacing: 1.5,
      color: "var(--hc-muted)",
      marginTop: 4
    }
  }, "PROJECT HERCULES \xB7 POLAR"))), /*#__PURE__*/React.createElement(ProgressReadout, {
    percent: pct,
    rows: [{
      name: "SLEEP",
      ticks: ticks(34),
      stat: pct >= 34 ? "28" : "··",
      state: rowState(34)
    }, {
      name: "HEART RATE",
      ticks: ticks(68),
      stat: pct >= 68 ? "41k" : "··",
      state: rowState(68)
    }, {
      name: "ACTIVITY",
      ticks: ticks(100),
      stat: pct >= 100 ? "17" : "··",
      state: rowState(100)
    }]
  }));
}
window.SyncScreen = SyncScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/hercules-app/SyncScreen.jsx", error: String((e && e.message) || e) }); }

__ds_ns.LogoMark = __ds_scope.LogoMark;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.OversizedScore = __ds_scope.OversizedScore;

__ds_ns.StatusPill = __ds_scope.StatusPill;

__ds_ns.DataDomainItem = __ds_scope.DataDomainItem;

__ds_ns.StatRow = __ds_scope.StatRow;

__ds_ns.ProgressReadout = __ds_scope.ProgressReadout;

__ds_ns.ScreenHeader = __ds_scope.ScreenHeader;

__ds_ns.SegmentedToggle = __ds_scope.SegmentedToggle;

__ds_ns.BarStrip = __ds_scope.BarStrip;

__ds_ns.TrendChart = __ds_scope.TrendChart;

})();
