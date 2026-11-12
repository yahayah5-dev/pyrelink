package com.limelight.pyrewick;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

/**
 * Pyrelink: the Pyrewick boot screen, then the Pyrelark sign-in, the first time Pyrelink opens each run.
 * Opened with mode=account (from Settings > Pyrelark account) it shows the account: friends, sign out or delete it.
 *
 * Signed in already: the boot screen shows for a moment and goes. Not signed in: sign in, make an account or
 * reset a password. If Pyrelark's server can't be reached at all, "Continue offline" lets streaming work anyway.
 * The UI is built in code (no layouts), in Pyrewick's colours, and works with a controller or a TV remote.
 */
public class PyrewickGate extends Activity {
    private static boolean bootDone;

    /** PcView asks this once per app start. */
    public static boolean needed() { return !bootDone; }

    private static final int BG = 0xFF0E0C0D, CARD = 0xFF1C1513, LINE = 0xFF3A2C26, FG = 0xFFF3E9DF, SOFT = 0xFFD8C9BA, MUTED = 0xFF9C8B7E,
            EMBER = 0xFFFF8A3D, GOLD = 0xFFFFC46B, BAD = 0xFFFF8B7A, INK = 0xFF1A0E08;

    private final Handler ui = new Handler(Looper.getMainLooper());
    private FrameLayout root;
    private boolean account, busy, offlineOk;
    private String view = "in"; // in, up, forgot, reset

    @Override
    protected void onCreate(Bundle saved) {
        super.onCreate(saved);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setBackgroundDrawable(new android.graphics.drawable.ColorDrawable(BG));
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        account = "account".equals(getIntent().getStringExtra("mode"));
        root = new FrameLayout(this);
        setContentView(root);
        if (account) { showAccount(); return; }
        showBoot();
        final boolean wasIn = PyrewickAccount.signedIn(this);
        new Thread(new Runnable() { @Override public void run() {
            if (wasIn) PyrewickAccount.refresh(PyrewickGate.this);
            else offlineOk = !PyrewickAccount.serverReachable(PyrewickGate.this);
        } }).start();
        ui.postDelayed(new Runnable() { @Override public void run() { afterBoot(); } }, 2200);
    }

    private void afterBoot() {
        if (isFinishing() || !"boot".equals(root.getTag())) return;
        if (PyrewickAccount.signedIn(this)) done(); else showForm();
    }

    private void done() {
        bootDone = true;
        finish();
        overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out);
    }

    @Override
    public void onBackPressed() {
        if (account) { finish(); return; }
        if ("reset".equals(view) || "forgot".equals(view)) { view = "in"; showForm(); return; }
        finishAffinity(); // no way past the sign-in except signing in (or offline)
    }

    // ---------------------------------------------------------------- the boot screen
    private void showBoot() {
        root.removeAllViews();
        root.setTag("boot");
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setGravity(Gravity.CENTER);
        ImageView logo = new ImageView(this);
        logo.setImageResource(getResources().getIdentifier("pyrewick_mark", "drawable", getPackageName()));
        col.addView(logo, new LinearLayout.LayoutParams(dp(120), dp(120)));
        TextView word = text("PYREWICK", 30, FG, true);
        word.setLetterSpacing(0.18f);
        word.setPadding(0, dp(18), 0, 0);
        col.addView(word);
        root.addView(col, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        col.setAlpha(0f);
        col.animate().alpha(1f).setDuration(600).start();
        root.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { afterBoot(); } }); // tap to skip
    }

    // ---------------------------------------------------------------- sign in, create account, forgot password
    private EditText fName, fEmail, fPass, fCode;
    private TextView msg;

    private void showForm() {
        root.setTag("form");
        root.setOnClickListener(null);
        LinearLayout box = page(view.equals("up") ? "Join Pyrelark" : view.equals("in") ? "Sign in" : "Reset your password",
                view.equals("in") || view.equals("up") ? "Your Pyrelark account: the same one as on your PC and pyrelark.com." : view.equals("forgot") ? "We'll email you a 6-digit code." : "Type the code from the email and choose a new password.");
        if (view.equals("in") || view.equals("up")) {
            LinearLayout tabs = new LinearLayout(this);
            tabs.setOrientation(LinearLayout.HORIZONTAL);
            tabs.addView(tab("Sign in", view.equals("in"), "in"), new LinearLayout.LayoutParams(0, dp(46), 1));
            tabs.addView(tab("Create account", view.equals("up"), "up"), new LinearLayout.LayoutParams(0, dp(46), 1));
            box.addView(tabs, lp(0, 0, 0, 14));
        }
        fName = fEmail = fPass = fCode = null;
        if (view.equals("up")) fName = field(box, "Player name (others see it)", InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PERSON_NAME);
        fEmail = field(box, "Email", InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS);
        if (view.equals("reset")) fCode = field(box, "Code", InputType.TYPE_CLASS_NUMBER);
        if (!view.equals("forgot")) fPass = field(box, view.equals("up") || view.equals("reset") ? "Password (8 characters or more)" : "Password", InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        if (fEmail != null) fEmail.setText(getPreferences(MODE_PRIVATE).getString("lastEmail", ""));
        final EditText last = fPass != null ? fPass : fCode != null ? fCode : fEmail;
        last.setImeOptions(EditorInfo.IME_ACTION_DONE);
        last.setOnEditorActionListener(new TextView.OnEditorActionListener() { @Override public boolean onEditorAction(TextView v, int a, KeyEvent e) { submit(); return true; } });
        Button go = button(view.equals("up") ? "Create account" : view.equals("in") ? "Sign in" : view.equals("forgot") ? "Email me a code" : "Save and sign in", true);
        go.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { submit(); } });
        box.addView(go, lp(0, 8, 0, 0));
        msg = text("", 14, SOFT, false);
        box.addView(msg, lp(0, 10, 0, 0));
        if (view.equals("in")) box.addView(link("Forgot your password?", "forgot"), lp(0, 8, 0, 0));
        if (view.equals("up")) {
            TextView t = text("By creating an account you agree to the Terms (pyrewick.com/terms).", 12, MUTED, false);
            box.addView(t, lp(0, 8, 0, 0));
        }
        if (view.equals("forgot") || view.equals("reset")) box.addView(link(view.equals("reset") ? "Send a new code" : "Back to sign in", view.equals("reset") ? "forgot" : "in"), lp(0, 8, 0, 0));
        if (offlineOk && !account) {
            Button off = button("Continue offline", false);
            off.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { done(); } });
            box.addView(text("Pyrelark's server can't be reached right now. You can still stream your PC.", 13, MUTED, false), lp(0, 18, 0, 6));
            box.addView(off);
        }
        (fName != null ? fName : fEmail).requestFocus();
    }

    private void submit() {
        if (busy) return;
        final String name = fName != null ? fName.getText().toString().trim() : "", email = fEmail != null ? fEmail.getText().toString().trim() : "",
                pass = fPass != null ? fPass.getText().toString() : "", code = fCode != null ? fCode.getText().toString().replaceAll("\\D", "") : "";
        if (email.isEmpty()) { say("Type your email address.", true); return; }
        if (fPass != null && pass.isEmpty()) { say("Type your password.", true); return; }
        getPreferences(MODE_PRIVATE).edit().putString("lastEmail", email).apply();
        busy = true;
        say(view.equals("forgot") ? "Sending…" : "Checking…", false);
        final String v = view;
        new Thread(new Runnable() { @Override public void run() {
            String err = null;
            try {
                if (v.equals("in")) PyrewickAccount.signIn(PyrewickGate.this, email, pass);
                else if (v.equals("up")) PyrewickAccount.signUp(PyrewickGate.this, name, email, pass);
                else if (v.equals("forgot")) PyrewickAccount.forgot(PyrewickGate.this, email);
                else PyrewickAccount.reset(PyrewickGate.this, email, code, pass);
            } catch (Exception e) { err = e.getMessage(); }
            final String fe = err;
            ui.post(new Runnable() { @Override public void run() {
                busy = false;
                if (fe != null) { say(fe, true); return; }
                if (v.equals("forgot")) { view = "reset"; showForm(); if (fEmail != null) fEmail.setText(email); say("If there's an account for that email, a code is on its way.", false); return; }
                if (v.equals("up")) android.widget.Toast.makeText(PyrewickGate.this, "Welcome to Pyrelark! We emailed you a code to confirm your address.", android.widget.Toast.LENGTH_LONG).show();
                if (account) showAccount(); else done();
            } });
        } }).start();
    }

    // ---------------------------------------------------------------- the account: sign out, delete
    private void showAccount() {
        root.setTag("account");
        if (!PyrewickAccount.signedIn(this)) { view = "in"; showForm(); return; }
        LinearLayout box = page(PyrewickAccount.name(this), PyrewickAccount.email(this));
        Button out = button("Sign out", false);
        out.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) {
            PyrewickAccount.signOut(PyrewickGate.this);
            view = "in"; showForm();
        } });
        box.addView(out, lp(0, 6, 0, 0));
        Button friends = button("Friends", false);
        friends.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) {
            startActivity(new Intent(PyrewickGate.this, PyrewickFriends.class));
        } });
        box.addView(friends, lp(0, 10, 0, 0));
        Button done = button("Done", true);
        done.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { finish(); } });
        box.addView(done, lp(0, 10, 0, 0));
        box.addView(text("Delete your account", 18, FG, true), lp(0, 34, 0, 6));
        box.addView(text("Removes your sign-in, email, the games on your account, reviews and cloud saves, for good. A subscription that still renews has to be cancelled first. You can also do this at pyrelark.com/delete-account.", 14, MUTED, false));
        final EditText pw = field(box, "Your password, to confirm", InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        final CheckBox sure = new CheckBox(this);
        sure.setText("I understand my account and my games are deleted for good.");
        sure.setTextColor(SOFT);
        box.addView(sure, lp(0, 6, 0, 6));
        Button del = button("Delete my account", false);
        del.setTextColor(BAD);
        msg = text("", 14, SOFT, false);
        del.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) {
            if (busy) return;
            if (!sure.isChecked()) { say("Tick the box to confirm.", true); return; }
            final String p = pw.getText().toString();
            busy = true; say("Deleting…", false);
            new Thread(new Runnable() { @Override public void run() {
                String err = null;
                try { PyrewickAccount.deleteAccount(PyrewickGate.this, p); } catch (Exception e) { err = e.getMessage(); }
                final String fe = err;
                ui.post(new Runnable() { @Override public void run() {
                    busy = false;
                    if (fe != null) { say(fe, true); return; }
                    android.widget.Toast.makeText(PyrewickGate.this, "Your account has been deleted.", android.widget.Toast.LENGTH_LONG).show();
                    view = "in"; showForm();
                } });
            } }).start();
        } });
        box.addView(del);
        box.addView(msg, lp(0, 10, 0, 0));
        TextView web = text("Open pyrelark.com/delete-account", 14, GOLD, false);
        web.setFocusable(true);
        web.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) {
            try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://pyrelark.com/delete-account"))); } catch (Exception ignored) { }
        } });
        box.addView(web, lp(0, 8, 0, 0));
    }

    // ---------------------------------------------------------------- building blocks
    private LinearLayout page(String title, String sub) {
        root.removeAllViews();
        ScrollView sv = new ScrollView(this);
        sv.setFillViewport(true);
        FrameLayout center = new FrameLayout(this);
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(dp(24), dp(24), dp(24), dp(24));
        box.setBackground(round(CARD, LINE, 22));
        LinearLayout head = new LinearLayout(this);
        head.setOrientation(LinearLayout.HORIZONTAL);
        head.setGravity(Gravity.CENTER_VERTICAL);
        ImageView logo = new ImageView(this);
        logo.setImageResource(getResources().getIdentifier("pyrewick_mark", "drawable", getPackageName()));
        head.addView(logo, new LinearLayout.LayoutParams(dp(30), dp(30)));
        TextView w = text("PYREWICK", 14, FG, true);
        w.setLetterSpacing(0.16f);
        w.setPadding(dp(10), 0, 0, 0);
        head.addView(w);
        box.addView(head, lp(0, 0, 0, 18));
        box.addView(text(title, 26, FG, true));
        if (sub != null && !sub.isEmpty()) box.addView(text(sub, 15, SOFT, false), lp(0, 6, 0, 18));
        FrameLayout.LayoutParams p = new FrameLayout.LayoutParams(Math.min(dp(460), getResources().getDisplayMetrics().widthPixels - dp(32)), ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER);
        p.topMargin = p.bottomMargin = dp(24);
        center.addView(box, p);
        sv.addView(center, new ScrollView.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        root.addView(sv, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        return box;
    }

    private EditText field(LinearLayout box, String label, int type) {
        box.addView(text(label, 14, SOFT, true), lp(0, 6, 0, 6));
        EditText e = new EditText(this);
        e.setInputType(type);
        e.setTextColor(FG);
        e.setHintTextColor(MUTED);
        e.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        e.setSingleLine(true);
        e.setPadding(dp(14), dp(12), dp(14), dp(12));
        e.setBackground(round(0xFF120D0C, 0xFF4A3A3A, 12));
        e.setOnFocusChangeListener(new View.OnFocusChangeListener() { @Override public void onFocusChange(View v, boolean f) { v.setBackground(round(0xFF120D0C, f ? EMBER : 0xFF4A3A3A, 12)); } });
        box.addView(e, lp(0, 0, 0, 6));
        return e;
    }

    private Button button(String label, boolean primary) {
        final Button b = new Button(this);
        b.setText(label);
        b.setAllCaps(false);
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        b.setTypeface(Typeface.DEFAULT_BOLD);
        b.setTextColor(primary ? INK : FG);
        final int fill = primary ? EMBER : 0xFF261D1A;
        b.setBackground(round(fill, primary ? EMBER : 0xFF4A3A3A, 14));
        b.setMinHeight(dp(50));
        b.setOnFocusChangeListener(new View.OnFocusChangeListener() { @Override public void onFocusChange(View v, boolean f) { v.setBackground(round(fill, f ? FG : (fill == EMBER ? EMBER : 0xFF4A3A3A), 14)); } });
        return b;
    }

    private View tab(String label, boolean on, final String to) {
        Button b = button(label, false);
        b.setBackground(round(on ? 0xFF2E2420 : CARD, on ? 0xFF4A3A3A : CARD, 10));
        b.setTextColor(on ? FG : MUTED);
        b.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { if (!busy) { view = to; showForm(); } } });
        return b;
    }

    private TextView link(String label, final String to) {
        TextView t = text(label, 14, GOLD, false);
        t.setFocusable(true);
        t.setPadding(0, dp(6), 0, dp(6));
        t.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { if (!busy) { view = to; showForm(); } } });
        return t;
    }

    private TextView text(String s, int sp, int color, boolean bold) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextColor(color);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, sp);
        if (bold) t.setTypeface(Typeface.DEFAULT_BOLD);
        return t;
    }

    private void say(String s, boolean bad) { if (msg != null) { msg.setText(s); msg.setTextColor(bad ? BAD : SOFT); } }

    private GradientDrawable round(int fill, int stroke, int radius) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(fill);
        g.setCornerRadius(dp(radius));
        g.setStroke(dp(1), stroke);
        return g;
    }

    private LinearLayout.LayoutParams lp(int l, int t, int r, int b) {
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        p.setMargins(dp(l), dp(t), dp(r), dp(b));
        return p;
    }

    private int dp(int v) { return Math.round(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, getResources().getDisplayMetrics())); }

}
