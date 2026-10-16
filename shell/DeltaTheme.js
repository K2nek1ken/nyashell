.pragma library
// тема DeltaChat Desktop в цветах палитры шелла: DeltaTheme.build(палитра) → текст CSS
// DeltaChat берёт свои темы (custom:<имя>) из ~/.config/DeltaChat/custom-themes — пересобирать его не нужно.
// Список переменных и формулы — из packages/frontend/themes/_themebase.scss (DeltaChat Desktop, GPL-3.0),
// здесь они пересчитываются по тем же правилам, что и в SCSS (changeContrast, rgba, colorToRGB)
// a DeltaChat Desktop theme in the shell palette's colours: DeltaTheme.build(palette) → CSS text
// DeltaChat takes its themes (custom:<name>) from ~/.config/DeltaChat/custom-themes, no rebuild needed.
// The variables and formulas come from packages/frontend/themes/_themebase.scss (DeltaChat Desktop, GPL-3.0),
// recomputed here by the same rules as in SCSS (changeContrast, rgba, colorToRGB)
const VARS = [["--themeDarkOrLight", "#{$themeDarkOrLight}"], ["--colorPrimary", "#{$colorPrimary}"], ["--colorDanger", "#{$colorDanger}"], ["--colorNone", "#{$colorNone}"], ["--bgPrimary", "#{$bgPrimary}"], ["--buttonPrimaryBackground", "#{$colorPrimary}"], ["--buttonPrimaryText", "#{$btnPrimaryText}"], ["--buttonPrimaryHover", "#{changeContrast($colorPrimary, 10%)}"], ["--buttonSecondaryBackground", "#{$bgSecondary}"], ["--buttonSecondaryText", "#{$textSecondary}"], ["--buttonSecondaryHover", "#{changeContrast($bgSecondary, 10%)}"], ["--buttonDangerText", "#{$btnDangerText}"], ["--buttonDangerBackground", "#{$btnDangerBackground}"], ["--buttonDangerHover", "#{changeContrast($btnDangerBackground, 10%)}"], ["--buttonDisabledBackground", "#{changeContrast($bgSecondary, 10%)}"], ["--buttonDisabledText", "#{changeContrast($textSecondary, 25%)}"], ["--accountSidebarBg", "#2c2c2c"], ["--accountSidebarInnerBorderColor", "#404040"], ["--accountSidebarIconColor", "#bcbcbc"], ["--accountSidebarIconColorHover", "#efefef"], ["--navBarBackground", "#{$bgNavBar}"], ["--navBarHeight", "50px"], ["--navBarText", "#{$textNavBar}"], ["--navBarButtonHover", "rgba(143, 153, 168, 0.15)"], ["--navBarButtonActive", "rgba(143, 153, 168, 0.3)"], ["--navBarSearchPlaceholder", "#{changeContrast($textNavBar, 27%)}"], ["--navBarGroupSubtitle", "#{changeContrast($textNavBar, 27%)}"], ["--chatViewBg", "#{$bgChatView}"], ["--chatViewBgImgPath", "#{$bgImage}"], ["--composerBg", "#{$bgPrimary}"], ["--composerText", "#{$textPrimary}"], ["--composerPlaceholderText", "#{rgba($textPrimary, 0.5)}"], ["--composerBtnColor", "#{rgba($textPrimary, 0.9)}"], ["--composerSendButton", "#415e6b"], ["--emojiSelectorSelectionColor", "#{$accentColor}"], ["--chatListItemSelectedBg", "#{$chatListItemSelectedBg}"], ["--chatListItemSelectedBgHover", "#{changeContrast( $chatListItemSelectedBg, 1% + $hover-contrast-change )}"], ["--chatListItemSelectedText", "#{$bgPrimary}"], ["--chatListItemBgHover", "#{changeContrast($bgPrimary, $hover-contrast-change)}"], ["--chatListItemBgPinned", "#{changeContrast($bgPrimary, 7%)}"], ["--chatListItemBgPinnedHover", "#{changeContrast( $bgPrimary, 7% + $hover-contrast-change )}"], ["--chat-list-item-summary-text", "#{changeContrast($textPrimary, 33%)}"], ["--chat-list-item-archived-label", "#{changeContrast($textPrimary, 20%)}"], ["--chat-list-item-archived-label-border", "#{changeContrast($textPrimary, 33%)}"], ["--cli-search-result-divider", "#{changeContrast($bgSecondary, 5%)}"], ["--cli-search-result-divider-border", "#{changeContrast($bgSecondary, 10%)}"], ["--cli-search-result-divider-border-width", "2px"], ["--contactListItemBgHover", "#{changeContrast( $bgPrimary, $hover-contrast-change )}"], ["--contactListItemBgFocus", "#{changeContrast($bgPrimary, 12%)}"], ["--keybindingSectionHeaderBackground", "#{$keybindingSectionHeaderBackground}"], ["--keybindingKeyBorder", "#{$keybindingKeyBorder}"], ["--keybindingActionBackground", "#{$keybindingActionBackground}"], ["--newChatButtonBg", "#{$newChatButtonBg}"], ["--messageText", "#{$textPrimary}"], ["--messageQuotedText", "#{changeContrast($textPrimary, 45%)}"], ["--infoMessageBubbleBg", "#0000008c"], ["--infoMessageBubbleText", "white"], ["--messageIncomingBg", "#{$bgMessageBubbleIncoming}"], ["--messageOutgoingBg", "#{$bgMessageBubbleOutgoing}"], ["--messageOutgoingStatusColor", "#{$messageOutgoingStatusColor}"], ["--messageStatusIcon", "#4caf50"], ["--messageStatusIconSending", "#62656a"], ["--messageMetadataIconColorOutgoing", "#4caf50"], ["--messageMetadataIconColorIncoming", "#a4a6a9"], ["--messageMetadataDate", "#62656a"], ["--messageMetadataIncoming", "rgba(#ffffff, 0.7)"], ["--messageAttachmentIconExtentionColor", "#070c14"], ["--messageAttachmentIconBg", "transparent"], ["--messageAttachmentFileInfo", "#{$textPrimary}"], ["--showInChatButtonBg", "#{$colorNone}"], ["--loginInputFocusColor", "#{$colorPrimary}"], ["--deltaChatPrimaryFgLight", "#{$textSecondary}"], ["--contextMenuBg", "#{$bgPrimary}"], ["--contextMenuBorder", "#{changeContrast($bgSecondary, 10%)}"], ["--contextMenuText", "#{$textSecondary}"], ["--separatorColor", "#{$bgSecondary}"], ["--bp4DialogHeaderBg", "#{$bgPrimary}"], ["--bp4DialogBgSecondary", "#{$bgSecondary}"], ["--bp4DialogBgPrimary", "#{$bgPrimary}"], ["--bp4Heading", "#{$textPrimary}"], ["--bp4InputText", "#{$textPrimary}"], ["--bp4InputPlaceholder", "lightgray"], ["--bp4MenuText", "#{$textPrimary}"], ["--bp4MenuBg", "#{$bgPrimary}"], ["--bp4Switch", "#7a8084"], ["--bp4SwitchShadow", "unset"], ["--bp4SwitchChecked", "#acd4e8"], ["--bp4SwitchShadowChecked", "unset"], ["--bp4SwitchKnob", "#f5f5f5"], ["--bp4SwitchKnobShadow", "0px 2px 0 0px #d2cfcfad"], ["--bp4SwitchKnobChecked", "#42a5f5"], ["--bp4SwitchKnobShadowChecked", "0px 1px 0 0px #c9d4d2d1"], ["--dialogBackdropBackground", "rgba(17, 20, 24, 0.7)"], ["--outlineProperties", "1px solid transparent"], ["--delta-dialog-separator", "#{$bgSecondary}"], ["--delta-dialog-separator-text", "#{changeContrast($bgSecondary, 24%)}"], ["--progressBarBg", "#{changeContrast($bgPrimary, 10%)}"], ["--progressBarSuccess", "green"], ["--progressBarPrimary", "var(--colorPrimary)"], ["--progressBarDanger", "var(--colorDanger)"], ["--galleryBg", "#{$bgPrimary}"], ["--avatarLabelColor", "#ffffff"], ["--avatarGradientMixFactor", "80%"], ["--avatarGradientAngle", "-45deg"], ["--brokenMediaText", "#070c14"], ["--brokenMediaBg", "#ffffff"], ["--unreadCountBg", "#{$accentColor}"], ["--unreadCountLabel", "#ffffff"], ["--contactEmailColor", "#{$textSecondary}"], ["--errorColor", "#f44336"], ["--globalLinkColor", "#2090ea"], ["--globalBackground", "#{$bgPrimary}"], ["--globalText", "#{$textPrimary}"], ["--globalHoverBg", "#{changeContrast($bgPrimary, 3%)}"], ["--textLessContrast", "#{$colorLessContrast}"], ["--videoPlayBtnIcon", "#{$accentColor}"], ["--videoPlayBtnBg", "#ffffff"], ["--videoPlayBtnBorder", "#eaeaea"], ["--videoPlayBtnBgHover", "#eeeeee"], ["--fullScreenMediaButtons", "#44444455"], ["--fullScreenMediaButtonsText", "#ffffff"], ["--messageHightlightColor", "rgba(66, 165, 245, 0.8)"], ["--addMemberChipBackgroundColor", "#{$bgSecondary}"], ["--galleryWebxdcItem", "#{changeContrast($bgPrimary, 10%)}"], ["--galleryFileRowHover", "#{changeContrast($bgPrimary, 7%)}"], ["--recently-seen-indicator-color", "#34c759"], ["--picker-Background", "#{$bgPrimary}"], ["--picker-BorderRadius", "5px"], ["--picker-background-rgb", "#{colorToRGB($bgPrimary)}"], ["--picker-text-rgb", "#{colorToRGB($textPrimary)}"], ["--picker-accent-rgb", "#{colorToRGB($colorPrimary)}"], ["--picker-selected-input-bg-rgb", "#{colorToRGB($bgSecondary)}"], ["--picker-border-and-hover-color", "rgb( #{colorToRGB(changeContrast($bgSecondary, 8%))} )"], ["--htmlEmail-themeDarkOrLight", "#{$themeDarkOrLight}"], ["--htmlEmail-background", "#{$bgPrimary}"], ["--htmlEmail-color", "#{$textPrimary}"], ["--htmlEmail-border-color", "#{changeContrast($bgPrimary, 20%)}"], ["--summary-text-color", "#{changeContrast($textPrimary, 33%)}"], ["--textPrimary", "#{$textPrimary}"], ["--textSecondary", "#{$textSecondary}"], ["--iconColorPrimary", "#{changeContrast($textPrimary, 20%)}"], ["--scrollbarThumb", "#{rgba(white, $scrollbarTransparency)}"], ["--scrollbarThumbHover", "#{rgba(white, $scrollbarTransparency + 0.14)}"], ["--unreadCountBgMuted", "grey"], ["--SPECIAL-emoji-picker-category-icon-style", "solid"], ["--scrollbarThumbHover", "#{rgba(grey, $scrollbarTransparency + 0.14)}"], ["--jumpDownButtonBackgroundColor", "white"], ["--jumpDownButtonIconColor", "#808080"], ["--unreadCountBgMuted", "#b6b6bb"], ["--SPECIAL-emoji-picker-category-icon-style", "outline"]];

function hex2rgb(h) {
    h = String(h).trim().replace("#", "");
    if (h.length === 3) h = h.split("").map(c => c + c).join("");
    return [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16));
}
const NAMED = { white: [255, 255, 255], black: [0, 0, 0], grey: [128, 128, 128], gray: [128, 128, 128] };
function rgbOf(c) { return NAMED[c] || hex2rgb(c); }
function rgb2hsl([r, g, b]) {
    r /= 255; g /= 255; b /= 255;
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2;
    if (mx === mn) return [0, 0, l * 100];
    const d = mx - mn, s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    let h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return [h * 60, s * 100, l * 100];
}
function hsl2rgb([h, s, l]) {
    s /= 100; l /= 100; h /= 360;
    if (!s) return [l, l, l].map(v => Math.round(v * 255));
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
    const f = t => { t = (t + 1) % 1; return t < 1 / 6 ? p + (q - p) * 6 * t : t < 1 / 2 ? q : t < 2 / 3 ? p + (q - p) * (2 / 3 - t) * 6 : p; };
    return [f(h + 1 / 3), f(h), f(h - 1 / 3)].map(v => Math.round(v * 255));
}
const hex = c => "#" + c.map(v => Math.max(0, Math.min(255, v)).toString(16).padStart(2, "0")).join("");
// changeContrast: тёмный цвет светлее, светлый — темнее (как в _themebase.scss)
// changeContrast: a dark colour gets lighter, a light one darker (as in _themebase.scss)
function changeContrast(c, pct) {
    const hsl = rgb2hsl(rgbOf(c));
    hsl[2] = Math.max(0, Math.min(100, hsl[2] < 50 ? hsl[2] + pct : hsl[2] - pct));
    return hex(hsl2rgb(hsl));
}
function rgba(c, a) { const [r, g, b] = rgbOf(c); return `rgba(${r}, ${g}, ${b}, ${+a.toFixed(3)})`; }

function evalExpr(e, P) {
    e = e.trim();
    const num = x => { x = x.trim().replace(/\$hover-contrast-change/g, "2%").replace(/\$scrollbarTransparency/g, String(P.scrollbarTransparency));
                       return x.split("+").reduce((s, t) => s + parseFloat(t), 0); };
    const val = x => { x = x.trim(); return x.includes("(") ? evalExpr(x, P) : x.startsWith("$") ? P[x.slice(1)] : x; };
    let m;
    if ((m = e.match(/^changeContrast\(\s*([^,]+),\s*([^()]+)\)$/))) return changeContrast(val(m[1]), num(m[2]));
    if ((m = e.match(/^colorToRGB\(\s*(.+)\)$/))) return rgbOf(val(m[1])).join(", ");
    if ((m = e.match(/^rgba\(\s*([^,]+),\s*(.+)\)$/))) return rgba(val(m[1]), num(m[2]));
    return val(e);
}
function render(P) {
    const lines = VARS.map(([k, v]) => {
        let out = v.replace(/#\{([^}]*)\}/g, (_, e) => evalExpr(e, P));
        out = out.replace(/rgba\((#[0-9a-fA-F]{3,6}),\s*([0-9.]+)\)/g, (_, c, a) => rgba(c, parseFloat(a)));
        return `  ${k}: ${out};`;
    });
    return `.theme-meta {\n  --name: 'nyashell';\n  --description: 'Colors of the nyashell palette (generated automatically).';\n}\n\n:root {\n${lines.join("\n")}\n}\n`;
}

function build(pal) {
const h = c => String(c || "").slice(0, 7);
const P = {
    themeDarkOrLight: "dark",
    colorPrimary: h(pal.accent), accentColor: h(pal.accent), colorDanger: h(pal.danger || "#ff5c5a"),
    colorNone: h(pal.textDim), colorLessContrast: h(pal.textDim),
    textPrimary: h(pal.text), textSecondary: h(pal.textDim), textNavBar: h(pal.text),
    bgPrimary: h(pal.frame), bgSecondary: h(pal.surface), bgNavBar: h(pal.frame), bgChatView: h(pal.frame),
    bgImage: "none",
    bgMessageBubbleIncoming: h(pal.surfaceHi || pal.surface), bgMessageBubbleOutgoing: h(pal.tonalHi || pal.surfaceHi),
    messageOutgoingStatusColor: h(pal.accent),
    btnPrimaryText: h(pal.onAccent), btnDangerText: "#ffffff", btnDangerBackground: h(pal.danger || "#ee0103"),
    keybindingSectionHeaderBackground: h(pal.surfaceHi || pal.surface), keybindingActionBackground: h(pal.surface),
    keybindingKeyBorder: "rgba(0, 0, 0, 0.6)",
    newChatButtonBg: h(pal.accent), chatListItemSelectedBg: h(pal.tonalHi || pal.surfaceHi),
    scrollbarTransparency: 0.34
};
    return render(P);
}
