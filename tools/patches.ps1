# Pyrelink's changes to Moonlight, as exact find-and-replace patches.
# Each one is applied once (its Marker shows it's already in). If Moonlight's code moved on and a
# Find no longer matches, the build stops and says which change needs updating.

$Patches = @(

# ---------------------------------------------------------------- DeX: open full screen on the monitor
@{ File = 'app\src\main\AndroidManifest.xml'; Marker = 'com.samsung.android.dex.launchwidth'
   Find = @'
        android:theme="@style/AppTheme">

'@
   Replace = @'
        android:theme="@style/AppTheme">

        <!-- Pyrelink: open full screen in Samsung DeX -->
        <meta-data android:name="com.samsung.android.dex.launchwidth" android:value="0" />
        <meta-data android:name="com.samsung.android.dex.launchheight" android:value="0" />

'@ },

# ---------------------------------------------------------------- PC screen: go straight in when the PC is ready
@{ File = 'app\src\main\java\com\limelight\PcView.java'; Marker = 'emberAutoTried'
   Find = @'
    private boolean freezeUpdates, runningPolling, inForeground, completeOnCreateCalled;
'@
   Replace = @'
    private boolean freezeUpdates, runningPolling, inForeground, completeOnCreateCalled;
    private boolean emberAutoTried; // Pyrelink: auto-connect happens once each time the app opens
'@ },

@{ File = 'app\src\main\java\com\limelight\PcView.java'; Marker = 'emberAutoConnect(details);'
   Find = @'
        // Notify the view that the data has changed
        pcGridAdapter.notifyDataSetChanged();
    }
'@
   Replace = @'
        // Notify the view that the data has changed
        pcGridAdapter.notifyDataSetChanged();

        emberAutoConnect(details);
    }

    // Pyrelink: like Steam Link, open straight into the stream. When a paired PC comes online,
    // go to its app list, which then starts Pyrelark (or resumes whatever is already running).
    private void emberAutoConnect(ComputerDetails details) {
        if (emberAutoTried || !inForeground || managerBinder == null) {
            return;
        }
        if (details.state != ComputerDetails.State.ONLINE || details.pairState != PairState.PAIRED) {
            return;
        }
        if (!PreferenceManager.getDefaultSharedPreferences(this).getBoolean("checkbox_ember_auto", true)) {
            return;
        }
        emberAutoTried = true;
        Intent i = new Intent(this, AppView.class);
        i.putExtra(AppView.NAME_EXTRA, details.name);
        i.putExtra(AppView.UUID_EXTRA, details.uuid);
        i.putExtra(AppView.EMBER_AUTO_EXTRA, true);
        startActivity(i);
    }
'@ },

# ---------------------------------------------------------------- app screen: start Pyrelark, hide Sunshine's extras
@{ File = 'app\src\main\java\com\limelight\AppView.java'; Marker = 'EMBER_AUTO_EXTRA'
   Find = @'
    public final static String SHOW_HIDDEN_APPS_EXTRA = "ShowHiddenApps";
'@
   Replace = @'
    public final static String SHOW_HIDDEN_APPS_EXTRA = "ShowHiddenApps";
    public final static String EMBER_AUTO_EXTRA = "EmberAuto";
'@ },

@{ File = 'app\src\main\java\com\limelight\AppView.java'; Marker = 'emberAuto, emberStarted'
   Find = @'
    private HashSet<Integer> hiddenAppIds = new HashSet<>();
'@
   Replace = @'
    private HashSet<Integer> hiddenAppIds = new HashSet<>();
    private boolean emberAuto, emberStarted;
'@ },

@{ File = 'app\src\main\java\com\limelight\AppView.java'; Marker = 'emberAuto = getIntent()'
   Find = @'
        showHiddenApps = getIntent().getBooleanExtra(SHOW_HIDDEN_APPS_EXTRA, false);
'@
   Replace = @'
        showHiddenApps = getIntent().getBooleanExtra(SHOW_HIDDEN_APPS_EXTRA, false);
        emberAuto = getIntent().getBooleanExtra(EMBER_AUTO_EXTRA, false);
'@ },

@{ File = 'app\src\main\java\com\limelight\AppView.java'; Marker = 'emberAutoStart(details, emberList);'
   Find = @'
                    updateUiWithAppList(NvHTTP.getAppListByReader(new StringReader(details.rawAppList)));
                    updateUiWithServerinfo(details);
'@
   Replace = @'
                    List<NvApp> emberList = NvHTTP.getAppListByReader(new StringReader(details.rawAppList));
                    updateUiWithAppList(emberList);
                    updateUiWithServerinfo(details);
                    emberAutoStart(details, emberList);
'@ },

@{ File = 'app\src\main\java\com\limelight\AppView.java'; Marker = 'private void emberAutoStart('
   Find = @'
    private void updateUiWithAppList(final List<NvApp> appList) {
'@
   Replace = @'
    // Pyrelink: resume whatever is already streaming, otherwise start Pyrelark. Runs once per screen.
    private void emberAutoStart(ComputerDetails details, List<NvApp> list) {
        if (!emberAuto || emberStarted || computer == null) {
            return;
        }
        NvApp pick = null;
        if (details.runningGameId != 0) {
            for (NvApp a : list) {
                if (a.getAppId() == details.runningGameId) {
                    pick = a;
                }
            }
        }
        if (pick == null) {
            for (NvApp a : list) {
                if (a.getAppName() != null && a.getAppName().trim().equalsIgnoreCase("Pyrelark")) {
                    pick = a;
                }
            }
        }
        if (pick == null) {
            return;
        }
        emberStarted = true;
        final NvApp app = pick;
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (!isFinishing()) {
                    ServerHelper.doStart(AppView.this, app, computer, managerBinder);
                }
            }
        });
    }

    // Pyrelink: Sunshine's own Desktop and Steam entries stay out of the grid
    // (they still show under the PC's "View all apps").
    private static boolean emberSkip(NvApp app) {
        String n = app.getAppName() == null ? "" : app.getAppName().trim();
        return n.equalsIgnoreCase("Desktop") || n.equalsIgnoreCase("Steam Big Picture") || n.equalsIgnoreCase("Steam");
    }

    private void updateUiWithAppList(final List<NvApp> appList) {
'@ },

@{ File = 'app\src\main\java\com\limelight\AppView.java'; Marker = 'if (!showHiddenApps && emberSkip(app))'
   Find = @'
                for (NvApp app : appList) {
                    boolean foundExistingApp = false;
'@
   Replace = @'
                for (NvApp app : appList) {
                    if (!showHiddenApps && emberSkip(app)) {
                        continue;
                    }
                    boolean foundExistingApp = false;
'@ },

# ---------------------------------------------------------------- settings: switch auto-connect off
@{ File = 'app\src\main\res\xml\preferences.xml'; Marker = 'checkbox_ember_auto'
   Find = @'
        android:key="category_basic_settings">
'@
   Replace = @'
        android:key="category_basic_settings">
        <CheckBoxPreference
            android:key="checkbox_ember_auto"
            android:title="Open straight into Pyrelark"
            android:summary="When your PC is online, skip the lists and start streaming Pyrelark, or resume what is already running"
            android:defaultValue="true" />
'@ },

# ---------------------------------------------------------------- bigger game covers (sizes in overlay\values*\ember_link_dimens.xml)
@{ File = 'app\src\main\res\layout\app_grid_item.xml'; Marker = '@dimen/ember_card_w'
   Find = @'
    android:layout_width="150dp"
    android:layout_height="200dp"
'@
   Replace = @'
    android:layout_width="@dimen/ember_card_w"
    android:layout_height="@dimen/ember_card_h"
'@ },

@{ File = 'app\src\main\res\layout\app_grid_view.xml'; Marker = '@dimen/ember_card_w'
   Find = @'
    android:columnWidth="150dp"
'@
   Replace = @'
    android:columnWidth="@dimen/ember_card_w"
'@ },

# ---------------------------------------------------------------- look: forge-style headings and labels
@{ File = 'app\src\main\res\layout\activity_app_view.xml'; Marker = 'Pyrelink heading'
   Find = @'
        android:paddingTop="5dp"
        android:paddingBottom="5dp"
        android:preferKeepClear="true"
        android:textSize="28sp"/>
'@
   Replace = @'
        android:paddingTop="14dp"
        android:paddingBottom="8dp"
        android:preferKeepClear="true"
        android:contentDescription="Pyrelink heading"
        android:fontFamily="sans-serif-condensed"
        android:textStyle="bold"
        android:textAllCaps="true"
        android:letterSpacing="0.06"
        android:textColor="#FFF3E9DF"
        android:textSize="30sp"/>
'@ },

@{ File = 'app\src\main\res\layout\app_grid_item.xml'; Marker = '#FFF3E9DF'
   Find = @'
        android:gravity="center"
        android:textSize="18sp">
'@
   Replace = @'
        android:gravity="center"
        android:textColor="#FFF3E9DF"
        android:fontFamily="sans-serif-condensed"
        android:textStyle="bold"
        android:textSize="18sp">
'@ },

@{ File = 'app\src\main\res\layout\pc_grid_item.xml'; Marker = '#FFF3E9DF'
   Find = @'
        android:gravity="center"
        android:textSize="18sp" >
'@
   Replace = @'
        android:gravity="center"
        android:textColor="#FFF3E9DF"
        android:fontFamily="sans-serif-condensed"
        android:textStyle="bold"
        android:textSize="18sp" >
'@ },

# ---------------------------------------------------------------- full restyle: forge background, title, rounded covers, focus frame
@{ File = 'app\src\main\res\layout\activity_pc_view.xml'; Marker = 'ember_link_bg'
   Find = @'
    tools:context=".PcView" >
'@
   Replace = @'
    android:background="@drawable/ember_link_bg"
    tools:context=".PcView" >
'@ },

@{ File = 'app\src\main\res\layout\activity_pc_view.xml'; Marker = 'emberTitle'
   Find = @'
    <ImageButton
        android:id="@+id/settingsButton"
'@
   Replace = @'
    <TextView
        android:id="@+id/emberTitle"
        android:layout_width="match_parent"
        android:layout_alignParentTop="true"
        android:layout_toRightOf="@+id/helpButton"
        android:layout_toEndOf="@+id/helpButton"
        android:layout_toLeftOf="@+id/manuallyAddPc"
        android:layout_toStartOf="@+id/manuallyAddPc"
        android:layout_height="65dp"
        android:gravity="center"
        android:text="PYRELINK"
        android:fontFamily="sans-serif-condensed"
        android:textStyle="bold"
        android:letterSpacing="0.18"
        android:textColor="#FFFF8A3D"
        android:shadowColor="#AAFF5A1F"
        android:shadowRadius="12"
        android:textSize="24sp"
        android:maxLines="1"
        android:ellipsize="end"
        android:importantForAccessibility="no" />

    <ImageButton
        android:id="@+id/settingsButton"
'@ },

@{ File = 'app\src\main\res\layout-land\activity_pc_view.xml'; Marker = 'ember_link_bg'
   Find = @'
    tools:context=".PcView" >
'@
   Replace = @'
    android:background="@drawable/ember_link_bg"
    tools:context=".PcView" >
'@ },

@{ File = 'app\src\main\res\layout-land\activity_pc_view.xml'; Marker = 'emberTitle'
   Find = @'
    <ImageButton
        android:id="@+id/settingsButton"
'@
   Replace = @'
    <TextView
        android:id="@+id/emberTitle"
        android:layout_width="match_parent"
        android:layout_alignParentTop="true"
        android:layout_toRightOf="@+id/settingsButton"
        android:layout_toEndOf="@+id/settingsButton"
        android:layout_height="65dp"
        android:gravity="center"
        android:text="PYRELINK"
        android:fontFamily="sans-serif-condensed"
        android:textStyle="bold"
        android:letterSpacing="0.18"
        android:textColor="#FFFF8A3D"
        android:shadowColor="#AAFF5A1F"
        android:shadowRadius="12"
        android:textSize="24sp"
        android:maxLines="1"
        android:ellipsize="end"
        android:importantForAccessibility="no" />

    <ImageButton
        android:id="@+id/settingsButton"
'@ },

@{ File = 'app\src\main\res\layout-land\activity_pc_view.xml'; Marker = 'android:layout_below="@id/emberTitle"'
   Find = @'
        android:layout_alignParentBottom="true"
        android:layout_alignParentTop="true"
        android:layout_toRightOf="@+id/settingsButton"
'@
   Replace = @'
        android:layout_alignParentBottom="true"
        android:layout_below="@id/emberTitle"
        android:layout_toRightOf="@+id/settingsButton"
'@ },

@{ File = 'app\src\main\res\layout\activity_app_view.xml'; Marker = 'ember_link_bg'
   Find = @'
    tools:context=".AppView" >
'@
   Replace = @'
    android:background="@drawable/ember_link_bg"
    tools:context=".AppView" >
'@ },

@{ File = 'app\src\main\res\layout\app_grid_item.xml'; Marker = '@drawable/ember_card'
   Find = @'
        android:id="@+id/grid_image"
        android:cropToPadding="false"
'@
   Replace = @'
        android:id="@+id/grid_image"
        android:background="@drawable/ember_card"
        android:clipToOutline="true"
        android:cropToPadding="false"
'@ },

@{ File = 'app\src\main\res\layout\app_grid_view.xml'; Marker = 'ember_selector'
   Find = @'
    android:clipToPadding="false"
'@
   Replace = @'
    android:clipToPadding="false"
    android:listSelector="@drawable/ember_selector"
    android:drawSelectorOnTop="true"
    android:verticalSpacing="6dp"
    android:paddingBottom="24dp"
'@ },

@{ File = 'app\src\main\res\layout\pc_grid_view.xml'; Marker = 'ember_selector'
   Find = @'
    android:clipToPadding="false"
'@
   Replace = @'
    android:clipToPadding="false"
    android:listSelector="@drawable/ember_selector"
    android:drawSelectorOnTop="true"
'@ },

@{ File = 'app\src\main\res\layout\pc_grid_item.xml'; Marker = 'ember_pc_card'
   Find = @'
    android:padding="20dp">
'@
   Replace = @'
    android:background="@drawable/ember_pc_card"
    android:padding="20dp">
'@ },

# ---------------------------------------------------------------- touch controls: forge look, and a layout per game

@{ File = 'app\src\main\java\com\limelight\binding\input\virtual_controller\VirtualControllerElement.java'; Marker = 'emberBackdrop('
   Find = @'
    private int normalColor = 0xF0888888;
    protected int pressedColor = 0xF00000FF;
'@
   Replace = @'
    private int normalColor = 0xF0F3D2B4;   // Pyrelink: warm outline
    protected int pressedColor = 0xF0FF8A3D;  // Pyrelink: ember orange when pressed

    // Pyrelink: forge-style fill behind each control. Dark glass that follows the opacity setting,
    // with an ember glow while it's held.
    private final Paint emberFill = new Paint(Paint.ANTI_ALIAS_FLAG);
    protected void emberBackdrop(Canvas canvas, float cx, float cy, float rx, float ry, boolean pressed) {
        if (rx <= 0 || ry <= 0) {
            return;
        }
        int a = Math.max(36, ((normalColor >>> 24) & 0xFF) * 170 / 255);
        android.graphics.RectF r = new android.graphics.RectF(cx - rx, cy - ry, cx + rx, cy + ry);
        emberFill.setShader(null);
        emberFill.setStyle(Paint.Style.FILL);
        emberFill.setColor((a << 24) | 0x1A1517);
        canvas.drawOval(r, emberFill);
        if (pressed) {
            emberFill.setShader(new android.graphics.RadialGradient(cx, cy, Math.max(rx, ry),
                    new int[] { 0xD9FFC488, 0x99FF7A2A, 0x00FF6A1F }, new float[] { 0f, 0.55f, 1f },
                    android.graphics.Shader.TileMode.CLAMP));
            canvas.drawOval(r, emberFill);
            emberFill.setShader(null);
        }
    }
'@ },

@{ File = 'app\src\main\java\com\limelight\binding\input\virtual_controller\DigitalButton.java'; Marker = 'emberBackdrop('
   Find = @'
        canvas.drawOval(rect, paint);

        if (icon != -1) {
'@
   Replace = @'
        emberBackdrop(canvas, getWidth() / 2f, getHeight() / 2f, rect.width() / 2f, rect.height() / 2f, isPressed());
        paint.setAntiAlias(true);
        paint.setFakeBoldText(true);
        canvas.drawOval(rect, paint);
        if (isPressed()) {
            paint.setColor(0xFFFFF3E0); // label glows white-hot while held
        }

        if (icon != -1) {
'@ },

@{ File = 'app\src\main\java\com\limelight\binding\input\virtual_controller\AnalogStick.java'; Marker = 'emberBackdrop(canvas, getWidth()'
   Find = @'
        canvas.drawCircle(getWidth() / 2, getHeight() / 2, radius_complete, paint);
'@
   Replace = @'
        emberBackdrop(canvas, getWidth() / 2f, getHeight() / 2f, radius_complete, radius_complete, false);
        paint.setAntiAlias(true);
        canvas.drawCircle(getWidth() / 2, getHeight() / 2, radius_complete, paint);
'@ },

@{ File = 'app\src\main\java\com\limelight\binding\input\virtual_controller\AnalogStick.java'; Marker = 'emberBackdrop(canvas, position_stick_x'
   Find = @'
                paint.setColor(pressedColor);
                canvas.drawCircle(position_stick_x, position_stick_y, radius_analog_stick, paint);
'@
   Replace = @'
                paint.setColor(pressedColor);
                emberBackdrop(canvas, position_stick_x, position_stick_y, radius_analog_stick * 1.6f, radius_analog_stick * 1.6f, true);
                canvas.drawCircle(position_stick_x, position_stick_y, radius_analog_stick, paint);
'@ },

@{ File = 'app\src\main\java\com\limelight\binding\input\virtual_controller\DigitalPad.java'; Marker = 'emberBackdrop('
   Find = @'
        paint.setTextSize(getPercent(getCorrectWidth(), 20));
'@
   Replace = @'
        emberBackdrop(canvas, getWidth() / 2f, getHeight() / 2f, getWidth() * 0.48f, getHeight() * 0.48f, direction != DIGITAL_PAD_DIRECTION_NO_DIRECTION);
        paint.setAntiAlias(true);
        paint.setTextSize(getPercent(getCorrectWidth(), 20));
'@ },

@{ File = 'app\src\main\java\com\limelight\binding\input\virtual_controller\VirtualControllerConfigurationLoader.java'; Marker = 'emberProfile'
   Find = @'
    public static final String OSC_PREFERENCE = "OSC";
'@
   Replace = @'
    public static final String OSC_PREFERENCE = "OSC";

    // Pyrelink: each game keeps its own layout (by its name in Sunshine). A game you haven't
    // arranged yet starts from your usual layout.
    public static String emberProfile = null;

    private static String prefName() {
        if (emberProfile == null || emberProfile.trim().isEmpty()) {
            return OSC_PREFERENCE;
        }
        return OSC_PREFERENCE + "." + emberProfile.trim().replaceAll("[^A-Za-z0-9_.-]", "_");
    }

    public static void emberResetProfile(Context context) {
        context.getSharedPreferences(prefName(), Activity.MODE_PRIVATE).edit().clear().apply();
    }
'@ },

@{ File = 'app\src\main\java\com\limelight\binding\input\virtual_controller\VirtualControllerConfigurationLoader.java'; Marker = 'getSharedPreferences(prefName(), Activity.MODE_PRIVATE).edit();'
   Find = @'
        SharedPreferences.Editor prefEditor = context.getSharedPreferences(OSC_PREFERENCE, Activity.MODE_PRIVATE).edit();
'@
   Replace = @'
        SharedPreferences.Editor prefEditor = context.getSharedPreferences(prefName(), Activity.MODE_PRIVATE).edit();
'@ },

@{ File = 'app\src\main\java\com\limelight\binding\input\virtual_controller\VirtualControllerConfigurationLoader.java'; Marker = 'pref.getAll().isEmpty()'
   Find = @'
        SharedPreferences pref = context.getSharedPreferences(OSC_PREFERENCE, Activity.MODE_PRIVATE);
'@
   Replace = @'
        SharedPreferences pref = context.getSharedPreferences(prefName(), Activity.MODE_PRIVATE);
        if (pref.getAll().isEmpty()) {
            pref = context.getSharedPreferences(OSC_PREFERENCE, Activity.MODE_PRIVATE);
        }
'@ },

@{ File = 'app\src\main\java\com\limelight\binding\input\virtual_controller\VirtualController.java'; Marker = 'emberResetProfile'
   Find = @'
                for (VirtualControllerElement element : elements) {
                    element.invalidate();
                }
            }
        });

'@
   Replace = @'
                for (VirtualControllerElement element : elements) {
                    element.invalidate();
                }
            }
        });

        // Pyrelink: hold the gear to put this game's controls back to your usual layout.
        buttonConfigure.setOnLongClickListener(new View.OnLongClickListener() {
            @Override
            public boolean onLongClick(View v) {
                VirtualControllerConfigurationLoader.emberResetProfile(context);
                currentMode = ControllerMode.Active;
                refreshLayout();
                Toast.makeText(context, "Controls reset to your usual layout", Toast.LENGTH_SHORT).show();
                return true;
            }
        });

'@ },

@{ File = 'app\src\main\java\com\limelight\binding\input\virtual_controller\VirtualController.java'; Marker = 'Saved these controls for'
   Find = @'
                    message = "Exiting configuration mode";
'@
   Replace = @'
                    message = VirtualControllerConfigurationLoader.emberProfile != null
                            ? "Saved these controls for " + VirtualControllerConfigurationLoader.emberProfile
                            : "Exiting configuration mode";
'@ },

@{ File = 'app\src\main\java\com\limelight\Game.java'; Marker = 'emberProfile = appName'
   Find = @'
            // create virtual onscreen controller
            virtualController = new VirtualController(controllerHandler,
'@
   Replace = @'
            // create virtual onscreen controller (Pyrelink: with this game's own layout)
            com.limelight.binding.input.virtual_controller.VirtualControllerConfigurationLoader.emberProfile = appName;
            virtualController = new VirtualController(controllerHandler,
'@ }

# ---------------------------------------------------------------- pairing without a PIN, quality when away, first-run tips, credits,

@{ File = 'app\src\main\java\com\limelight\PcView.java'; Marker = 'private void emberSendPin('
   Find = @'
    private void doPair(final ComputerDetails computer) {
'@
   Replace = @'
    // Pyrelink: also hand the PIN to Pyrelark on the PC. If someone pressed "Pair a phone" there, it gives the
    // PIN to Sunshine and pairing finishes with nothing typed. Otherwise Pyrelark ignores it and the PIN shows as usual.
    private void emberSendPin(final ComputerDetails computer, final String pin) {
        final String host = emberHost(computer.activeAddress);
        if (host == null || host.isEmpty()) {
            return;
        }
        new Thread(new Runnable() {
            @Override
            public void run() {
                java.net.HttpURLConnection c = null;
                try {
                    Thread.sleep(700); // let Moonlight's pairing request reach Sunshine first
                    String h = host.contains(":") ? "[" + host + "]" : host;
                    String name = Build.MODEL != null ? Build.MODEL : "Pyrelink";
                    java.net.URL u = new java.net.URL("http://" + h + ":47997/pair?pin=" + pin + "&name=" + java.net.URLEncoder.encode(name, "UTF-8"));
                    c = (java.net.HttpURLConnection) u.openConnection();
                    c.setConnectTimeout(2500);
                    c.setReadTimeout(4000);
                    c.getResponseCode();
                } catch (Exception ignored) {
                } finally {
                    if (c != null) {
                        c.disconnect();
                    }
                }
            }
        }).start();
    }

    // The PC's address as plain text, whether Moonlight keeps it as text or as "host:port" / "[v6]:port".
    static String emberHost(Object a) {
        if (a == null) {
            return null;
        }
        String s = a.toString().trim();
        if (s.startsWith("[")) {
            int e = s.indexOf(']');
            return e > 0 ? s.substring(1, e) : s;
        }
        int colon = s.indexOf(':');
        if (colon > 0 && colon == s.lastIndexOf(':')) {
            return s.substring(0, colon);
        }
        return s;
    }

    private void doPair(final ComputerDetails computer) {
'@ },

@{ File = 'app\src\main\java\com\limelight\PcView.java'; Marker = 'emberSendPin(computer, pinStr);'
   Find = @'
                                getResources().getString(R.string.pair_pairing_help), false);

'@
   Replace = @'
                                getResources().getString(R.string.pair_pairing_help), false);
                        emberSendPin(computer, pinStr);

'@ },

@{ File = 'app\src\main\java\com\limelight\PcView.java'; Marker = 'emberWelcome();'
   Find = @'
    protected void onResume() {
        super.onResume();

'@
   Replace = @'
    protected void onResume() {
        super.onResume();
        emberWelcome();

'@ },

@{ File = 'app\src\main\java\com\limelight\PcView.java'; Marker = 'private void emberWelcome()'
   Find = @'
    private void doPair(final ComputerDetails computer) {
'@
   Replace = @'
    // Pyrelink: a short first-run walkthrough, shown once.
    private void emberWelcome() {
        final android.content.SharedPreferences p = PreferenceManager.getDefaultSharedPreferences(this);
        if (p.getBoolean("ember_welcomed", false)) {
            return;
        }
        p.edit().putBoolean("ember_welcomed", true).apply();
        new android.app.AlertDialog.Builder(this)
                .setTitle("Welcome to Pyrelink")
                .setMessage("Play the games on your PC from this phone or tablet.\n\n"
                        + "1. On the PC, open Pyrelark: Settings > Stream to your phone > Pair a phone.\n"
                        + "2. Tap your PC here. It pairs by itself, no PIN to type.\n"
                        + "3. From then on Pyrelink opens straight into Pyrelark.\n\n"
                        + "Touch controls: turn them on in Settings. While playing, tap the faint gear to move or resize buttons, "
                        + "and hold it to reset a game's layout. A Bluetooth or USB controller works too.\n\n"
                        + "Away from home, Pyrelink lowers the stream quality on its own so it stays smooth.")
                .setPositiveButton("Got it", null)
                .show();
    }

    private void doPair(final ComputerDetails computer) {
'@ },

@{ File = 'app\src\main\java\com\limelight\Game.java'; Marker = 'emberBitrate(host'
   Find = @'
                .setBitrate(prefConfig.bitrate)
'@
   Replace = @'
                .setBitrate(emberBitrate(host, prefConfig.bitrate))
'@ },

@{ File = 'app\src\main\java\com\limelight\Game.java'; Marker = 'private int emberBitrate('
   Find = @'
    @Override
    public void connectionStatusUpdate(final int connectionStatus) {
'@
   Replace = @'
    // Pyrelink: away from home (Tailscale or any address that isn't on the home network) the stream drops to
    // a gentler bitrate so it stays smooth on mobile data or hotel Wi-Fi. Settings > "Lower quality away from home".
    private int emberBitrate(String host, int wanted) {
        android.content.SharedPreferences p = android.preference.PreferenceManager.getDefaultSharedPreferences(this);
        if (!p.getBoolean("checkbox_ember_away_auto", true) || host == null || !emberAway(host.trim())) {
            return wanted;
        }
        int cap;
        try {
            cap = Integer.parseInt(p.getString("list_ember_away_kbps", "10000"));
        } catch (NumberFormatException e) {
            cap = 10000;
        }
        if (wanted <= cap) {
            return wanted;
        }
        final int mbps = cap / 1000;
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Toast.makeText(Game.this, "Away from home: streaming at " + mbps + " Mbps", Toast.LENGTH_LONG).show();
            }
        });
        return cap;
    }

    // True for Tailscale and internet addresses; false for home-network ones and for names we can't judge.
    static boolean emberAway(String h) {
        if (h.startsWith("[")) {
            h = h.substring(1, Math.max(1, h.indexOf(']')));
        }
        String l = h.toLowerCase(java.util.Locale.US);
        if (l.contains(":")) { // IPv6
            if (l.startsWith("fd7a:115c:a1e0")) return true; // Tailscale
            return !(l.startsWith("fe80") || l.startsWith("fc") || l.startsWith("fd") || l.equals("::1"));
        }
        String[] o = h.split("\\.");
        if (o.length != 4) {
            return false; // a name, not an address
        }
        int a, b;
        try {
            a = Integer.parseInt(o[0]);
            b = Integer.parseInt(o[1]);
        } catch (NumberFormatException e) {
            return false;
        }
        if (a == 10 || a == 127 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168) || (a == 169 && b == 254)) {
            return false;
        }
        return true; // includes Tailscale's 100.64.0.0/10
    }

    @Override
    public void connectionStatusUpdate(final int connectionStatus) {
'@ },

@{ File = 'app\src\main\res\xml\preferences.xml'; Marker = 'checkbox_ember_away_auto'
   Find = @'
            android:summary="When your PC is online, skip the lists and start streaming Pyrelark, or resume what is already running"
            android:defaultValue="true" />
'@
   Replace = @'
            android:summary="When your PC is online, skip the lists and start streaming Pyrelark, or resume what is already running"
            android:defaultValue="true" />
        <CheckBoxPreference
            android:key="checkbox_ember_away_auto"
            android:title="Lower quality away from home"
            android:summary="On Tailscale or mobile data, stream at a gentler bitrate so it stays smooth"
            android:defaultValue="true" />
        <ListPreference
            android:key="list_ember_away_kbps"
            android:dependency="checkbox_ember_away_auto"
            android:title="Bitrate away from home"
            android:summary="%s"
            android:entries="@array/ember_away_names"
            android:entryValues="@array/ember_away_values"
            android:defaultValue="10000" />
'@ },

@{ File = 'app\src\main\res\xml\preferences.xml'; Marker = 'category_ember_about'
   Find = @'
    <!--PreferenceCategory android:title="@string/category_help"
'@
   Replace = @'
    <PreferenceCategory android:title="About Pyrelink"
        android:key="category_ember_about">
        <com.limelight.preferences.WebLauncherPreference
            android:title="Built on Moonlight"
            android:summary="Pyrelink is a modified version of Moonlight for Android, free software under the GNU GPL v3. Tap for Moonlight's source code."
            url="https://github.com/moonlight-stream/moonlight-android"/>
        <com.limelight.preferences.WebLauncherPreference
            android:title="Licence"
            android:summary="GNU General Public License v3. Pyrelink's own changes are published under the same licence."
            url="https://www.gnu.org/licenses/gpl-3.0.html"/>
    </PreferenceCategory>
    <!--PreferenceCategory android:title="@string/category_help"
'@ },

# ---------------------------------------------------------------- tapping a PC goes straight into Pyrelark too
@{ File = 'app\src\main\java\com\limelight\PcView.java'; Marker = 'EMBER_AUTO_EXTRA, !showHiddenGames'
   Find = @'
        i.putExtra(AppView.SHOW_HIDDEN_APPS_EXTRA, showHiddenGames);
'@
   Replace = @'
        i.putExtra(AppView.SHOW_HIDDEN_APPS_EXTRA, showHiddenGames);
        // Pyrelink: a tap on the PC opens Pyrelark's big screen; backing out of the stream shows the app list
        i.putExtra(AppView.EMBER_AUTO_EXTRA, !showHiddenGames && PreferenceManager.getDefaultSharedPreferences(this).getBoolean("checkbox_ember_auto", true));
'@ },

# ---------------------------------------------------------------- start Pyrelark even when the app list came from the cache
@{ File = 'app\src\main\java\com\limelight\AppView.java'; Marker = 'the list may have come from the cache'
   Find = @'
                // App list is the same or empty
'@
   Replace = @'
                // Pyrelink: the list may have come from the cache (then it never "changes"), so start Pyrelark here too
                if (emberAuto && !emberStarted && (details.rawAppList != null || lastRawApplist != null)) {
                    try {
                        emberAutoStart(details, NvHTTP.getAppListByReader(new StringReader(details.rawAppList != null ? details.rawAppList : lastRawApplist)));
                    } catch (XmlPullParserException | IOException e) {
                        e.printStackTrace();
                    }
                }

                // App list is the same or empty
'@ },

# ---------------------------------------------------------------- leaving a stream ends it on the PC too
# Moonlight normally leaves the PC "in game" when you back out, so you can resume. For Pyrelark that left the PC
# at the phone's resolution and Pyrelark in Big Picture. Now leaving quits the session: Sunshine puts the
# display back and Pyrelark returns to a window. Games you started keep running on the PC.
@{ File = 'app\src\main\java\com\limelight\Game.java'; Marker = 'emberQuitAddr;'
   Find = @'
    private String appName;
'@
   Replace = @'
    private String appName;
    // Pyrelink: what's needed to end the session on the PC after the stream stops
    private ComputerDetails.AddressTuple emberQuitAddr;
    private int emberQuitHttpsPort;
    private String emberQuitUniqueId;
    private X509Certificate emberQuitCert;
'@ },

@{ File = 'app\src\main\java\com\limelight\Game.java'; Marker = 'emberQuitAddr = new'
   Find = @'
        controllerHandler = new ControllerHandler(this, conn, this, prefConfig);
'@
   Replace = @'
        emberQuitAddr = new ComputerDetails.AddressTuple(host, port);
        emberQuitHttpsPort = httpsPort;
        emberQuitUniqueId = uniqueId;
        emberQuitCert = serverCert;
        controllerHandler = new ControllerHandler(this, conn, this, prefConfig);
'@ },

@{ File = 'app\src\main\java\com\limelight\Game.java'; Marker = 'emberQuitAfterStop();'
   Find = @'
                public void run() {
                    conn.stop();
                }
'@
   Replace = @'
                public void run() {
                    conn.stop();
                    emberQuitAfterStop();
                }
'@ },

@{ File = 'app\src\main\java\com\limelight\Game.java'; Marker = 'private void emberQuitAfterStop()'
   Find = @'
    @Override
    public void stageFailed(
'@
   Replace = @'
    // Pyrelink: runs on the stop thread, after the stream is closed (Sunshine won't quit while a stream is open).
    private void emberQuitAfterStop() {
        if (emberQuitAddr == null || !android.preference.PreferenceManager.getDefaultSharedPreferences(this)
                .getBoolean("checkbox_ember_quit_on_leave", true)) {
            return;
        }
        for (int i = 0; i < 4; i++) {
            try {
                Thread.sleep(i == 0 ? 400 : 1200);
                NvHTTP http = new NvHTTP(emberQuitAddr, emberQuitHttpsPort, emberQuitUniqueId, emberQuitCert,
                        PlatformBinding.getCryptoProvider(this));
                if (http.quitApp()) {
                    return;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    @Override
    public void stageFailed(
'@ },

@{ File = 'app\src\main\res\xml\preferences.xml'; Marker = 'checkbox_ember_quit_on_leave'
   Find = @'
            android:key="checkbox_ember_auto"
'@
   Replace = @'
            android:key="checkbox_ember_quit_on_leave"
            android:title="Leaving a stream ends it on the PC"
            android:summary="Puts the PC's screen back the way it was and returns Pyrelark to a window. Turn off to leave things running so you can resume"
            android:defaultValue="true" />
        <CheckBoxPreference
            android:key="checkbox_ember_auto"
'@ },

# ---------------------------------------------------------------- the Pyrewick boot screen and sign-in (java\com\limelight\pyrewick)
@{ File = 'app\src\main\java\com\limelight\PcView.java'; Marker = 'PyrewickGate.needed()'
   Find = @'
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
'@
   Replace = @'
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Pyrelink: the Pyrewick boot screen, then the Pyrelark sign-in (once each time the app starts)
        if (com.limelight.pyrewick.PyrewickGate.needed()) {
            startActivity(new Intent(this, com.limelight.pyrewick.PyrewickGate.class));
        }
'@ },

@{ File = 'app\src\main\AndroidManifest.xml'; Marker = '.pyrewick.PyrewickGate'
   Find = @'
        <!-- Small hack to support launcher shortcuts
'@
   Replace = @'
        <!-- Pyrelink: the Pyrewick boot screen and the Pyrelark sign-in -->
        <activity
            android:name=".pyrewick.PyrewickGate"
            android:exported="false"
            android:resizeableActivity="true"
            android:theme="@android:style/Theme.Material.NoActionBar"
            android:windowSoftInputMode="adjustResize"
            android:configChanges="keyboard|keyboardHidden|navigation|screenLayout|uiMode|orientation|screenSize|smallestScreenSize" />

        <!-- Small hack to support launcher shortcuts
'@ },

@{ File = 'app\src\main\res\xml\preferences.xml'; Marker = 'ember_account'
   Find = @'
        android:key="category_basic_settings">
'@
   Replace = @'
        android:key="category_basic_settings">
        <Preference
            android:key="ember_account"
            android:title="Pyrelark account"
            android:summary="Signed-in account: sign out or delete it">
            <intent
                android:targetPackage="com.pyrewick.pyrelink"
                android:targetClass="com.limelight.pyrewick.PyrewickGate">
                <extra android:name="mode" android:value="account" />
            </intent>
        </Preference>
'@ },

# ---------------------------------------------------------------- Friends (java\com\limelight\pyrewick\PyrewickFriends.java)
@{ File = 'app\src\main\AndroidManifest.xml'; Marker = '.pyrewick.PyrewickFriends'
   Find = @'
        <!-- Small hack to support launcher shortcuts
'@
   Replace = @'
        <!-- Pyrelink: your Pyrelark friends -->
        <activity
            android:name=".pyrewick.PyrewickFriends"
            android:exported="false"
            android:resizeableActivity="true"
            android:theme="@android:style/Theme.Material.NoActionBar"
            android:configChanges="keyboard|keyboardHidden|navigation|screenLayout|uiMode|orientation|screenSize|smallestScreenSize" />

        <!-- Small hack to support launcher shortcuts
'@ },

@{ File = 'app\src\main\res\layout\activity_pc_view.xml'; Marker = 'android:id="@+id/pyrewickFriends"'
   Find = @'
    <ImageButton
        android:id="@+id/manuallyAddPc"
'@
   Replace = @'
    <ImageButton
        android:id="@+id/pyrewickFriends"
        android:layout_width="70dp"
        android:layout_height="65dp"
        android:padding="19dp"
        android:scaleType="fitCenter"
        android:layout_alignParentTop="true"
        android:layout_toLeftOf="@+id/manuallyAddPc"
        android:layout_toStartOf="@+id/manuallyAddPc"
        android:src="@drawable/pyrewick_friends"
        android:contentDescription="Friends"
        android:preferKeepClear="true"
        style="?android:attr/borderlessButtonStyle"/>

    <ImageButton
        android:id="@+id/manuallyAddPc"
'@ },

@{ File = 'app\src\main\res\layout\activity_pc_view.xml'; Marker = 'android:layout_toStartOf="@+id/pyrewickFriends"'
   Find = @'
        android:layout_toLeftOf="@+id/manuallyAddPc"
        android:layout_toStartOf="@+id/manuallyAddPc"
        android:layout_height="65dp"
'@
   Replace = @'
        android:layout_toLeftOf="@+id/pyrewickFriends"
        android:layout_toStartOf="@+id/pyrewickFriends"
        android:layout_height="65dp"
'@ },

@{ File = 'app\src\main\res\layout-land\activity_pc_view.xml'; Marker = 'android:id="@+id/pyrewickFriends"'
   Find = @'
        android:src="@drawable/ic_add"
        style="?android:attr/borderlessButtonStyle"/>
'@
   Replace = @'
        android:src="@drawable/ic_add"
        style="?android:attr/borderlessButtonStyle"/>

    <ImageButton
        android:id="@+id/pyrewickFriends"
        android:layout_width="70dp"
        android:layout_height="65dp"
        android:padding="19dp"
        android:scaleType="fitCenter"
        android:layout_alignParentStart="true"
        android:layout_alignParentLeft="true"
        android:layout_below="@id/manuallyAddPc"
        android:src="@drawable/pyrewick_friends"
        android:contentDescription="Friends"
        style="?android:attr/borderlessButtonStyle"/>
'@ },

@{ File = 'app\src\main\java\com\limelight\PcView.java'; Marker = 'PyrewickFriends.class'
   Find = @'
        ImageButton helpButton = findViewById(R.id.helpButton);
'@
   Replace = @'
        ImageButton helpButton = findViewById(R.id.helpButton);

        // Pyrelink: Friends (your Pyrelark friends: who's online and what they're playing)
        findViewById(R.id.pyrewickFriends).setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                startActivity(new Intent(PcView.this, com.limelight.pyrewick.PyrewickFriends.class));
            }
        });
'@ },

@{ File = 'app\src\main\res\xml\preferences.xml'; Marker = 'pyrewick_friends'
   Find = @'
        <Preference
            android:key="ember_account"
'@
   Replace = @'
        <Preference
            android:key="pyrewick_friends"
            android:title="Friends"
            android:summary="Your Pyrelark friends: who's online, requests and your friend code">
            <intent
                android:targetPackage="com.pyrewick.pyrelink"
                android:targetClass="com.limelight.pyrewick.PyrewickFriends" />
        </Preference>
        <Preference
            android:key="ember_account"
'@ },

# ---------------------------------------------------------------- About: Pyrelink's own source code (GPL-3.0)
@{ File = 'app\src\main\res\xml\preferences.xml'; Marker = 'github.com/yahayah5-dev/pyrelink'
   Find = @'
            url="https://www.gnu.org/licenses/gpl-3.0.html"/>
'@
   Replace = @'
            url="https://www.gnu.org/licenses/gpl-3.0.html"/>
        <com.limelight.preferences.WebLauncherPreference
            android:title="Pyrelink's source code"
            android:summary="Pyrelink's changes to Moonlight, published under the GPL v3. Tap to open them on GitHub."
            url="https://github.com/yahayah5-dev/pyrelink"/>
'@ }
)
