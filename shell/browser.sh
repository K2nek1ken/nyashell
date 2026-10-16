#!/bin/sh
# браузер для борда: Firefox с отдельным профилем, приватным окном и почти без интерфейса —
# только строка адреса/поиска и сама страница. Цвета берутся из палитры шелла.
# dashboard browser: Firefox with a separate profile, a private window and almost no UI,
# just the address/search bar and the page itself. Colours come from the shell palette.
P="$HOME/.cache/nyashell/firefox"
C=nyash-browser
mkdir -p "$P/chrome"
pal="$HOME/.config/quickshell/nyashell/palette.json"
get() { sed -n "s/.*\"$1\":\"\(#[0-9a-fA-F]\{6\}\)[0-9a-fA-F]*\".*/\1/p" "$pal" 2>/dev/null | head -1; }
BG=$(get frame);  BG=${BG:-#191616}
SF=$(get surface); SF=${SF:-#271e1e}
TX=$(get text);    TX=${TX:-#f2ebea}
AC=$(get accent);  AC=${AC:-#dfbfbe}
DM=$(get textDim); DM=${DM:-#b0a1a0}

cat > "$P/user.js" <<PREFS
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_welcome_url", "");
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("browser.uidensity", 1);
user_pref("browser.tabs.inTitlebar", 0);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.privatebrowsing.enable-new-indicator", false);
user_pref("ui.systemUsesDarkTheme", 1);
user_pref("layout.css.devPixelsPerPx", "0.85");   // чуть мельче — страницы влезают в борд без наложений
PREFS

cat > "$P/chrome/userChrome.css" <<CSS
/* nyashell: оставляем только строку адреса */
#TabsToolbar, #PersonalToolbar, #sidebar-box, #sidebar-main, #sidebar-splitter,
.titlebar-buttonbox-container, .titlebar-spacer, #private-browsing-indicator-with-label,
#nav-bar-customization-target > :not(#urlbar-container),
#nav-bar > toolbarbutton, #PanelUI-button, #unified-extensions-button,
#identity-box, #tracking-protection-icon-container, #page-action-buttons > :not(#star-button-box) { display: none !important; }
:root {
  --toolbar-bgcolor: $BG !important; --toolbar-color: $TX !important;
  --toolbar-field-background-color: $SF !important; --toolbar-field-focus-background-color: $SF !important;
  --toolbar-field-color: $TX !important; --toolbar-field-focus-color: $TX !important;
  --toolbar-field-border-color: transparent !important; --focus-outline-color: $AC !important;
  --lwt-accent-color: $BG !important; --urlbarView-highlight-background: $AC !important;
  --arrowpanel-background: $BG !important; --arrowpanel-color: $TX !important;
}
#navigator-toolbox { background: $BG !important; border: none !important; }
#nav-bar { background: $BG !important; padding: 6px 10px !important; box-shadow: none !important; }
#urlbar-background { border-radius: 999px !important; background: $SF !important; border: none !important; }
#urlbar[focused] #urlbar-background { outline: 1.5px solid $AC !important; }
#urlbar-input { font-family: "Nyaspace", "Monaspace Neon Var", "Monaspace Neon NF", monospace !important; color: $TX !important; }
#urlbar-input::placeholder { color: $DM !important; }
CSS

# фон страниц — как у борда (для пустой страницы и DuckDuckGo)
# page background like the dashboard's (for the empty page and DuckDuckGo)
cat > "$P/chrome/userContent.css" <<CSS
@-moz-document url(about:blank), url(about:newtab), url(about:home) { html, body { background: $BG !important; } }
@-moz-document domain(duckduckgo.com) {
  html, body, .site-wrapper, .body--home, .header-wrap, #header_wrapper { background: $BG !important; }
  .searchbox_searchbox__eaWKL, input[type="text"] { background: $SF !important; }
}
CSS

exec firefox --no-remote --profile "$P" --name "$C" --class "$C" --private-window "${1:-https://duckduckgo.com}"
