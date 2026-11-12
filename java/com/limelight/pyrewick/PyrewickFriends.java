package com.limelight.pyrewick;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.PorterDuff;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.util.Base64;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewOutlineProvider;
import android.view.Window;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.net.URLEncoder;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Pyrelink: your Pyrelark friends. Who's online and what they're playing, friend requests, your friend code,
 * and a friend's profile (with remove, block and report). The same friends as in Pyrelark on the PC and on
 * pyrelark.com. Built in code like PyrewickGate, in Pyrewick's colours, and works with a controller or TV remote.
 */
public class PyrewickFriends extends Activity {
    private static final int BG = 0xFF0E0C0D, CARD = 0xFF1C1513, LINE = 0xFF3A2C26, FG = 0xFFF3E9DF, SOFT = 0xFFD8C9BA, MUTED = 0xFF9C8B7E,
            EMBER = 0xFFFF8A3D, GOLD = 0xFFFFC46B, GREEN = 0xFF7BD69A, BAD = 0xFFFF8B7A, INK = 0xFF1A0E08;
    private static final Map<String, int[]> AVATARS = new HashMap<>();
    private static final Map<String, int[]> BANNERS = new HashMap<>();
    static {
        AVATARS.put("ember", new int[] { 0xFF2A1A12, 0xFFFF8A3D }); AVATARS.put("gold", new int[] { 0xFF2B2210, 0xFFFFC46B });
        AVATARS.put("ash", new int[] { 0xFF24201F, 0xFFCFC3BA }); AVATARS.put("forge", new int[] { 0xFF2A1010, 0xFFFF5A3D });
        AVATARS.put("night", new int[] { 0xFF121A2B, 0xFF8CB4FF }); AVATARS.put("moss", new int[] { 0xFF14211A, 0xFF7FD39A });
        AVATARS.put("ice", new int[] { 0xFF10222A, 0xFF7FE0F0 }); AVATARS.put("rose", new int[] { 0xFF2A1420, 0xFFFF8FB8 });
        BANNERS.put("embers", new int[] { 0xFF7A2E12, 0xFF0E0A09 }); BANNERS.put("dusk", new int[] { 0xFF3B1E3F, 0xFFE07A3A });
        BANNERS.put("forge", new int[] { 0xFF1A0E0A, 0xFFFF8A3D }); BANNERS.put("night", new int[] { 0xFF2A3A6A, 0xFF0A0C14 });
        BANNERS.put("gridline", new int[] { 0xFF0B1408, 0xFF1E3A10 }); BANNERS.put("ash", new int[] { 0xFF3A3431, 0xFF120F0E });
    }
    private static final Map<String, Bitmap> PICS = new HashMap<>();

    private final Handler ui = new Handler(Looper.getMainLooper());
    private FrameLayout root;
    private JSONObject data, titles = new JSONObject();
    private String profileId; // showing a friend's profile when set
    private String note = "";
    private boolean busy;

    @Override
    protected void onCreate(Bundle saved) {
        super.onCreate(saved);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setBackgroundDrawable(new android.graphics.drawable.ColorDrawable(BG));
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE | WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN);
        root = new FrameLayout(this);
        setContentView(root);
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (profileId != null) openProfile(profileId); else load();
    }

    @Override
    public void onBackPressed() {
        if (profileId != null) { profileId = null; load(); return; }
        super.onBackPressed();
    }

    // ---------------------------------------------------------------- the friends list
    private void load() {
        if (!PyrewickAccount.signedIn(this)) { showSignedOut(); return; }
        if (data == null) { LinearLayout box = page("Friends", null); box.addView(text("Loading…", 15, MUTED, false)); }
        new Thread(new Runnable() { @Override public void run() {
            JSONObject r = null; String err = null;
            try { r = PyrewickAccount.call(PyrewickFriends.this, "GET", "/v1/friends", null, true); }
            catch (PyrewickAccount.ApiException e) { err = e.getMessage(); if (e.status == 401) PyrewickAccount.refresh(PyrewickFriends.this); }
            final JSONObject fr = r; final String fe = err;
            ui.post(new Runnable() { @Override public void run() {
                if (isFinishing() || profileId != null) return;
                if (fe != null) {
                    if (!PyrewickAccount.signedIn(PyrewickFriends.this)) { showSignedOut(); return; }
                    LinearLayout box = page("Friends", null);
                    box.addView(text(fe, 15, BAD, false));
                    Button again = button("Try again", true);
                    again.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { load(); } });
                    box.addView(again, lp(0, 16, 0, 0));
                    return;
                }
                data = fr;
                if (fr.optJSONObject("titles") != null) titles = fr.optJSONObject("titles");
                showList();
            } });
        } }).start();
    }

    private void showSignedOut() {
        LinearLayout box = page("Friends", "Sign in to your Pyrelark account to see your friends.");
        Button in = button("Sign in", true);
        in.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) {
            startActivity(new Intent(PyrewickFriends.this, PyrewickGate.class).putExtra("mode", "account"));
        } });
        box.addView(in, lp(0, 8, 0, 0));
        in.requestFocus();
    }

    private void showList() {
        JSONArray list = data.optJSONArray("friends"), inc = data.optJSONArray("incoming"), out = data.optJSONArray("outgoing"), blk = data.optJSONArray("blocked");
        int n = list == null ? 0 : list.length(), on = 0;
        for (int i = 0; i < n; i++) if (!"offline".equals(list.optJSONObject(i).optString("status"))) on++;
        LinearLayout box = page("Friends", n == 0 ? "Play together, see who's on, and compare scores." : n + (n == 1 ? " friend" : " friends") + (on > 0 ? ", " + on + " online" : ""));

        // your code
        final String code = data.optString("code");
        LinearLayout codeBox = new LinearLayout(this);
        codeBox.setOrientation(LinearLayout.VERTICAL);
        codeBox.setPadding(dp(16), dp(14), dp(16), dp(14));
        GradientDrawable cb = round(0x14FF8A3D, 0x80FF8A3D, 14); cb.setStroke(dp(1), 0x80FF8A3D, dp(5), dp(4));
        codeBox.setBackground(cb);
        codeBox.addView(text("Your friend code. Send it to a friend so they can add you.", 13, SOFT, false));
        TextView c = text(code, 24, GOLD, true);
        c.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        c.setLetterSpacing(0.12f);
        codeBox.addView(c, lp(0, 4, 0, 10));
        LinearLayout codeBtns = new LinearLayout(this);
        Button copy = button("Copy", false), share = button("Share", false);
        copy.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) {
            ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            if (cm != null) cm.setPrimaryClip(ClipData.newPlainText("Pyrelark friend code", code));
            Toast.makeText(PyrewickFriends.this, "Copied " + code, Toast.LENGTH_SHORT).show();
        } });
        share.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) {
            Intent s = new Intent(Intent.ACTION_SEND).setType("text/plain")
                    .putExtra(Intent.EXTRA_TEXT, "Add me on Pyrelark! My friend code is " + code + ". Get Pyrelark free at https://pyrelark.com");
            try { startActivity(Intent.createChooser(s, "Share your friend code")); } catch (Exception ignored) { }
        } });
        codeBtns.addView(copy, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        View gap = new View(this); codeBtns.addView(gap, new LinearLayout.LayoutParams(dp(10), 1));
        codeBtns.addView(share, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        codeBox.addView(codeBtns);
        box.addView(codeBox, lp(0, 0, 0, 16));

        // add a friend
        box.addView(text("Add a friend: their code or email", 14, SOFT, true), lp(0, 0, 0, 6));
        final EditText add = new EditText(this);
        styleField(add);
        add.setHint("PYRE-7K2QX");
        add.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        add.setImeOptions(EditorInfo.IME_ACTION_SEND);
        box.addView(add, lp(0, 0, 0, 8));
        final Button addBtn = button("Send friend request", true);
        final Runnable doAdd = new Runnable() { @Override public void run() {
            String v = add.getText().toString().trim();
            if (v.isEmpty()) { add.requestFocus(); return; }
            post("/v1/friends/add", "code", v, "Request sent.");
        } };
        addBtn.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { doAdd.run(); } });
        add.setOnEditorActionListener(new TextView.OnEditorActionListener() { @Override public boolean onEditorAction(TextView v, int a, KeyEvent e) { doAdd.run(); return true; } });
        box.addView(addBtn);
        if (!note.isEmpty()) { box.addView(text(note, 14, SOFT, false), lp(0, 10, 0, 0)); note = ""; }

        // requests
        if (inc != null && inc.length() > 0) {
            heading(box, "Requests");
            for (int i = 0; i < inc.length(); i++) {
                final JSONObject x = inc.optJSONObject(i);
                LinearLayout r = row(null, x.optString("name"), "Wants to be friends", MUTED, null);
                LinearLayout btns = new LinearLayout(this);
                Button yes = button("Accept", true), no = button("Decline", false), bl = button("Block", false);
                yes.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { post("/v1/friends/accept", "id", x.optString("id"), "You're friends with " + x.optString("name") + " now."); } });
                no.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { post("/v1/friends/decline", "id", x.optString("id"), ""); } });
                bl.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { askBlock(x.optString("id"), x.optString("name")); } });
                btns.addView(yes, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
                btns.addView(new View(this), new LinearLayout.LayoutParams(dp(8), 1));
                btns.addView(no, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
                btns.addView(new View(this), new LinearLayout.LayoutParams(dp(8), 1));
                btns.addView(bl, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
                LinearLayout wrap = new LinearLayout(this);
                wrap.setOrientation(LinearLayout.VERTICAL);
                wrap.addView(r);
                wrap.addView(btns, lp(0, 0, 0, 8));
                box.addView(wrap);
            }
        }

        // friends
        heading(box, "Your friends");
        if (n == 0) box.addView(text("No friends yet. Share your code, or add someone else's.", 15, MUTED, false));
        for (int i = 0; i < n; i++) {
            final JSONObject f = list.optJSONObject(i);
            String st = f.optString("status");
            LinearLayout r = row(f.optJSONObject("avatar"), f.optString("name"), presence(f), "playing".equals(st) ? EMBER : "online".equals(st) ? GREEN : MUTED, f.optString("id"));
            r.addView(dot(st));
            r.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { openProfile(f.optString("id")); } });
            box.addView(r);
        }

        // sent, blocked
        if (out != null && out.length() > 0) {
            heading(box, "Sent");
            for (int i = 0; i < out.length(); i++) {
                final JSONObject x = out.optJSONObject(i);
                LinearLayout r = row(null, x.optString("name"), "Waiting for them to accept. Tap to cancel.", MUTED, null);
                r.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { post("/v1/friends/cancel", "id", x.optString("id"), "Request cancelled."); } });
                box.addView(r);
            }
        }
        if (blk != null && blk.length() > 0) {
            heading(box, "Blocked");
            for (int i = 0; i < blk.length(); i++) {
                final JSONObject x = blk.optJSONObject(i);
                LinearLayout r = row(null, x.optString("name"), "Blocked. Tap to unblock.", MUTED, null);
                r.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { post("/v1/friends/unblock", "id", x.optString("id"), "Unblocked " + x.optString("name") + "."); } });
                box.addView(r);
            }
        }
        box.addView(text("Your profile, picture and banner are set in Pyrelark on your PC or at pyrelark.com.", 13, MUTED, false), lp(0, 22, 0, 0));
    }

    private String presence(JSONObject f) {
        String st = f.optString("status");
        if ("playing".equals(st)) return "Playing " + title(f.optString("game"));
        if ("online".equals(st)) return "Online in Pyrelark";
        long seen = f.optLong("seen");
        return seen > 0 ? "Last seen " + ago(seen) : "Offline";
    }

    private String title(String id) {
        String t = titles.optString(id, "");
        if (!t.isEmpty()) return t;
        StringBuilder b = new StringBuilder();
        for (String w : id.split("-")) if (!w.isEmpty()) b.append(b.length() > 0 ? " " : "").append(Character.toUpperCase(w.charAt(0))).append(w.substring(1));
        return b.toString();
    }

    private static String ago(long t) {
        long m = Math.max(0, (System.currentTimeMillis() - t) / 60000);
        if (m < 2) return "just now";
        if (m < 60) return m + " minutes ago";
        long h = Math.round(m / 60.0);
        if (h < 24) return h + (h == 1 ? " hour ago" : " hours ago");
        long d = Math.round(h / 24.0);
        return d + (d == 1 ? " day ago" : " days ago");
    }

    private void post(final String path, final String key, final String value, final String ok) {
        if (busy) return;
        busy = true;
        new Thread(new Runnable() { @Override public void run() {
            String err = null, msgFromServer = null;
            try {
                JSONObject b = new JSONObject(); b.put(key, value);
                JSONObject r = PyrewickAccount.call(PyrewickFriends.this, "POST", path, b, true);
                msgFromServer = r.optString("msg", null);
            } catch (Exception e) { err = e.getMessage(); }
            final String fe = err, fm = msgFromServer;
            ui.post(new Runnable() { @Override public void run() {
                busy = false;
                String m = fe != null ? fe : fm != null && !fm.isEmpty() ? fm : ok;
                if (m != null && !m.isEmpty()) Toast.makeText(PyrewickFriends.this, m, Toast.LENGTH_LONG).show();
                if (fe == null) { profileId = null; load(); }
            } });
        } }).start();
    }

    private void askBlock(final String id, final String name) {
        new AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert)
                .setTitle("Block " + name + "?")
                .setMessage("They stop being your friend, can't send you friend requests or see your profile, and their scores are hidden from you. They aren't told. You can unblock them in Friends.")
                .setPositiveButton("Block", new DialogInterface.OnClickListener() { @Override public void onClick(DialogInterface d, int w) { post("/v1/friends/block", "id", id, "Blocked " + name + "."); } })
                .setNegativeButton("Cancel", null).show();
    }

    // ---------------------------------------------------------------- a friend's profile
    private void openProfile(final String id) {
        profileId = id;
        LinearLayout box = page("Profile", null);
        box.addView(text("Loading…", 15, MUTED, false));
        new Thread(new Runnable() { @Override public void run() {
            JSONObject r = null; String err = null;
            try { r = PyrewickAccount.call(PyrewickFriends.this, "GET", "/v1/profile?id=" + URLEncoder.encode(id, "UTF-8"), null, true); }
            catch (Exception e) { err = e.getMessage(); }
            final JSONObject fr = r; final String fe = err;
            ui.post(new Runnable() { @Override public void run() {
                if (isFinishing() || !id.equals(profileId)) return;
                if (fe != null) { Toast.makeText(PyrewickFriends.this, fe, Toast.LENGTH_LONG).show(); profileId = null; load(); return; }
                if (fr.optJSONObject("titles") != null) {
                    JSONObject t = fr.optJSONObject("titles");
                    for (java.util.Iterator<String> it = t.keys(); it.hasNext(); ) { String k = it.next(); try { titles.put(k, t.optString(k)); } catch (Exception ignored) { } }
                }
                showProfile(fr);
            } });
        } }).start();
    }

    private void showProfile(final JSONObject p) {
        final String id = p.optString("id"), name = p.optString("name");
        LinearLayout box = page(null, null);
        // banner with the avatar over its bottom edge
        FrameLayout top = new FrameLayout(this);
        final ImageView ban = new ImageView(this);
        ban.setScaleType(ImageView.ScaleType.CENTER_CROP);
        JSONObject bj = p.optJSONObject("banner");
        int[] bc = BANNERS.get(bj != null ? bj.optString("preset", "embers") : "embers");
        if (bc == null) bc = BANNERS.get("embers");
        GradientDrawable bg = new GradientDrawable(GradientDrawable.Orientation.TL_BR, bc);
        bg.setCornerRadius(dp(16));
        ban.setBackground(bg);
        ban.setOutlineProvider(ViewOutlineProvider.BACKGROUND);
        ban.setClipToOutline(true);
        if (bj != null && bj.optLong("image") > 0) loadPicture(id, "banner", bj.optLong("image"), ban);
        FrameLayout.LayoutParams bl = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(130));
        top.addView(ban, bl);
        ImageView av = avatar(p.optJSONObject("avatar"), id, 88);
        FrameLayout.LayoutParams al = new FrameLayout.LayoutParams(dp(88), dp(88), Gravity.START | Gravity.TOP);
        al.leftMargin = dp(14); al.topMargin = dp(84);
        top.addView(av, al);
        box.addView(top, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(176)));

        box.addView(text(name, 26, FG, true), lp(0, 6, 0, 2));
        JSONObject pres = p.optJSONObject("presence");
        String st = pres != null ? pres.optString("status") : "offline";
        box.addView(text(pres != null ? presence(pres) : "Offline", 15, "playing".equals(st) ? EMBER : "online".equals(st) ? GREEN : MUTED, false));
        String since = "Member since " + month(p.optLong("joined")) + (p.optLong("friendsSince") > 0 ? " · Friends since " + month(p.optLong("friendsSince")) : "");
        box.addView(text(since, 13, MUTED, false), lp(0, 2, 0, 0));
        if (!p.optString("bio").isEmpty()) {
            heading(box, "About");
            box.addView(text(p.optString("bio"), 15, SOFT, false));
        }
        JSONObject stats = p.optJSONObject("stats");
        if (stats != null) {
            heading(box, "Stats");
            int years = stats.optInt("years");
            box.addView(text(stats.optInt("owned") + " games  ·  " + fmt(stats.optDouble("hours")) + " hours  ·  " + stats.optInt("friends") + " friends  ·  " + (years > 0 ? years + (years == 1 ? " year" : " years") : "new this year"), 15, SOFT, false));
        }
        JSONArray badges = p.optJSONArray("badges");
        if (badges != null && badges.length() > 0) {
            heading(box, "Badges · " + badges.length());
            String show = p.optString("showcase");
            for (int i = 0; i < badges.length(); i++) {
                JSONObject b = badges.optJSONObject(i);
                LinearLayout r = new LinearLayout(this);
                r.setOrientation(LinearLayout.VERTICAL);
                r.setPadding(dp(12), dp(10), dp(12), dp(10));
                r.setBackground(round(b.optString("id").equals(show) ? 0x14FFC46B : 0xFF151010, b.optString("id").equals(show) ? 0x8CFFC46B : LINE, 12));
                r.addView(text(b.optString("name"), 15, b.optString("id").equals(show) ? GOLD : FG, true));
                r.addView(text(b.optString("desc"), 13, MUTED, false));
                box.addView(r, lp(0, 0, 0, 8));
            }
        }
        JSONArray most = p.optJSONArray("mostPlayed");
        if (most != null && most.length() > 0) {
            heading(box, "Most played");
            for (int i = 0; i < most.length(); i++) {
                JSONObject m = most.optJSONObject(i);
                box.addView(text(title(m.optString("game")) + "  ·  " + fmt(m.optDouble("hours")) + " h", 15, SOFT, false), lp(0, 0, 0, 4));
            }
        }
        JSONArray favs = p.optJSONArray("favorites");
        if (favs != null && favs.length() > 0) {
            heading(box, "Favourite games");
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < favs.length(); i++) sb.append(i > 0 ? "  ·  " : "").append(title(favs.optString(i)));
            box.addView(text(sb.toString(), 15, SOFT, false));
        }

        if (!p.optBoolean("me")) {
            heading(box, "");
            Button back = button("Back to friends", true);
            back.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { profileId = null; load(); } });
            box.addView(back, lp(0, 0, 0, 8));
            Button rm = button("Remove friend", false);
            rm.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) {
                new AlertDialog.Builder(PyrewickFriends.this, android.R.style.Theme_Material_Dialog_Alert).setTitle("Remove " + name + "?")
                        .setMessage("You can add each other again any time.")
                        .setPositiveButton("Remove", new DialogInterface.OnClickListener() { @Override public void onClick(DialogInterface d, int w) { post("/v1/friends/remove", "id", id, "Removed " + name + " from your friends."); } })
                        .setNegativeButton("Keep", null).show();
            } });
            box.addView(rm, lp(0, 0, 0, 8));
            LinearLayout two = new LinearLayout(this);
            Button rep = button("Report", false), blk = button("Block", false);
            rep.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { report(p); } });
            blk.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { askBlock(id, name); } });
            two.addView(rep, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
            two.addView(new View(this), new LinearLayout.LayoutParams(dp(8), 1));
            two.addView(blk, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
            box.addView(two);
            back.requestFocus();
        }
    }

    private void report(final JSONObject p) {
        final String name = p.optString("name");
        final java.util.List<String> whatKeys = new java.util.ArrayList<>(), whatLabels = new java.util.ArrayList<>();
        JSONObject a = p.optJSONObject("avatar"), b = p.optJSONObject("banner");
        if (a != null && a.optLong("image") > 0) { whatKeys.add("avatar"); whatLabels.add("Their picture"); }
        if (b != null && b.optLong("image") > 0) { whatKeys.add("banner"); whatLabels.add("Their banner"); }
        if (!p.optString("bio").isEmpty()) { whatKeys.add("bio"); whatLabels.add("Their about text"); }
        whatKeys.add("name"); whatLabels.add("Their name");
        final String[] reasons = { "offensive", "sexual", "hate", "spam", "impersonation", "other" };
        final String[] reasonLabels = { "Rude or offensive", "Sexual content", "Hate or harassment", "Spam or scam", "Pretending to be someone", "Something else" };
        new AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert).setTitle("Report " + name + ": what's wrong?")
                .setItems(whatLabels.toArray(new String[0]), new DialogInterface.OnClickListener() { @Override public void onClick(DialogInterface d, final int wi) {
                    new AlertDialog.Builder(PyrewickFriends.this, android.R.style.Theme_Material_Dialog_Alert).setTitle("Why?")
                            .setItems(reasonLabels, new DialogInterface.OnClickListener() { @Override public void onClick(DialogInterface d2, final int ri) {
                                new AlertDialog.Builder(PyrewickFriends.this, android.R.style.Theme_Material_Dialog_Alert).setTitle("Send the report?")
                                        .setMessage("Pyrewick reads every report. " + name + " isn't told who reported them. You can also block them, so they stop being your friend and can't add you or see your profile.")
                                        .setPositiveButton("Report and block", new DialogInterface.OnClickListener() { @Override public void onClick(DialogInterface d3, int w) { sendReport(p.optString("id"), whatKeys.get(wi), reasons[ri], true); } })
                                        .setNeutralButton("Report", new DialogInterface.OnClickListener() { @Override public void onClick(DialogInterface d3, int w) { sendReport(p.optString("id"), whatKeys.get(wi), reasons[ri], false); } })
                                        .setNegativeButton("Cancel", null).show();
                            } }).setNegativeButton("Cancel", null).show();
                } }).setNegativeButton("Cancel", null).show();
    }

    private void sendReport(final String id, final String what, final String reason, final boolean block) {
        new Thread(new Runnable() { @Override public void run() {
            String err = null;
            try {
                JSONObject b = new JSONObject();
                b.put("id", id); b.put("what", what); b.put("reason", reason); b.put("block", block);
                PyrewickAccount.call(PyrewickFriends.this, "POST", "/v1/report", b, true);
            } catch (Exception e) { err = e.getMessage(); }
            final String fe = err;
            ui.post(new Runnable() { @Override public void run() {
                Toast.makeText(PyrewickFriends.this, fe != null ? fe : block ? "Reported and blocked. Thanks for letting us know." : "Thanks. Pyrewick will take a look.", Toast.LENGTH_LONG).show();
                if (fe == null && block) { profileId = null; load(); }
            } });
        } }).start();
    }

    private static String month(long t) { return t > 0 ? new java.text.SimpleDateFormat("MMM yyyy", Locale.getDefault()).format(new java.util.Date(t)) : ""; }
    private static String fmt(double d) { return d == Math.rint(d) ? String.valueOf((long) d) : String.format(Locale.getDefault(), "%.1f", d); }

    // ---------------------------------------------------------------- pictures
    private ImageView avatar(JSONObject av, String id, int size) {
        ImageView v = new ImageView(this);
        String preset = av != null ? av.optString("preset", "ember") : "ember";
        int[] c = AVATARS.get(preset);
        if (c == null) c = AVATARS.get("ember");
        GradientDrawable o = new GradientDrawable();
        o.setShape(GradientDrawable.OVAL);
        o.setColor(c[0]);
        o.setStroke(dp(size > 60 ? 4 : 1), size > 60 ? BG : 0x1AF3E9DF);
        v.setBackground(o);
        v.setOutlineProvider(ViewOutlineProvider.BACKGROUND);
        v.setClipToOutline(true);
        v.setImageResource(getResources().getIdentifier("pyrewick_firebird", "drawable", getPackageName()));
        v.setColorFilter(c[1], PorterDuff.Mode.SRC_IN);
        int pad = Math.round(size * 0.18f);
        v.setPadding(dp(pad), dp(pad), dp(pad), dp(pad));
        if (av != null && av.optLong("image") > 0) loadPicture(id, "avatar", av.optLong("image"), v);
        return v;
    }

    private void loadPicture(final String id, final String kind, final long stamp, final ImageView into) {
        final String key = id + ":" + kind + ":" + stamp;
        Bitmap cached = PICS.get(key);
        if (cached != null) { showBitmap(into, cached); return; }
        new Thread(new Runnable() { @Override public void run() {
            try {
                JSONObject r = PyrewickAccount.call(PyrewickFriends.this, "GET", "/v1/profile/picture?kind=" + kind + "&id=" + URLEncoder.encode(id, "UTF-8"), null, true);
                byte[] bytes = Base64.decode(r.optString("data"), Base64.DEFAULT);
                final Bitmap bm = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
                if (bm == null) return;
                synchronized (PICS) { PICS.put(key, bm); }
                ui.post(new Runnable() { @Override public void run() { showBitmap(into, bm); } });
            } catch (Exception ignored) { } // the preset stays
        } }).start();
    }

    private static void showBitmap(ImageView v, Bitmap bm) {
        v.clearColorFilter();
        v.setPadding(0, 0, 0, 0);
        v.setScaleType(ImageView.ScaleType.CENTER_CROP);
        v.setImageBitmap(bm);
    }

    // ---------------------------------------------------------------- building blocks
    private LinearLayout page(String title, String sub) {
        root.removeAllViews();
        ScrollView sv = new ScrollView(this);
        sv.setFillViewport(true);
        FrameLayout center = new FrameLayout(this);
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(dp(20), dp(20), dp(20), dp(24));
        box.setBackground(round(CARD, LINE, 22));
        if (title != null) {
            LinearLayout head = new LinearLayout(this);
            head.setGravity(Gravity.CENTER_VERTICAL);
            ImageView logo = new ImageView(this);
            logo.setImageResource(getResources().getIdentifier("pyrewick_firebird", "drawable", getPackageName()));
            head.addView(logo, new LinearLayout.LayoutParams(dp(26), dp(26)));
            TextView w = text("PYRELARK", 13, FG, true);
            w.setLetterSpacing(0.16f);
            w.setPadding(dp(10), 0, 0, 0);
            head.addView(w);
            box.addView(head, lp(0, 0, 0, 14));
            box.addView(text(title, 26, FG, true));
            if (sub != null && !sub.isEmpty()) box.addView(text(sub, 15, SOFT, false), lp(0, 4, 0, 16));
            else box.addView(new View(this), lp(0, 0, 0, 12));
        }
        FrameLayout.LayoutParams p = new FrameLayout.LayoutParams(Math.min(dp(560), getResources().getDisplayMetrics().widthPixels - dp(24)), ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER_HORIZONTAL);
        p.topMargin = p.bottomMargin = dp(16);
        center.addView(box, p);
        sv.addView(center, new ScrollView.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        root.addView(sv, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        return box;
    }

    private LinearLayout row(JSONObject av, String name, String sub, int subColor, String id) {
        LinearLayout r = new LinearLayout(this);
        r.setGravity(Gravity.CENTER_VERTICAL);
        r.setPadding(dp(10), dp(10), dp(10), dp(10));
        r.setFocusable(true);
        r.setClickable(true);
        final GradientDrawable off = round(0x08FFFFFF, 0x00000000, 14), on = round(0x14FFFFFF, FG, 14);
        r.setBackground(off);
        r.setOnFocusChangeListener(new View.OnFocusChangeListener() { @Override public void onFocusChange(View v, boolean f) { v.setBackground(f ? on : off); } });
        if (id != null) {
            ImageView a = avatar(av, id, 46);
            LinearLayout.LayoutParams al = new LinearLayout.LayoutParams(dp(46), dp(46));
            al.rightMargin = dp(12);
            r.addView(a, al);
        }
        LinearLayout tx = new LinearLayout(this);
        tx.setOrientation(LinearLayout.VERTICAL);
        tx.addView(text(name, 16, FG, true));
        tx.addView(text(sub, 14, subColor, false));
        r.addView(tx, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        LinearLayout.LayoutParams p = lp(0, 0, 0, 8);
        r.setLayoutParams(p);
        return r;
    }

    private View dot(String status) {
        View d = new View(this);
        GradientDrawable g = new GradientDrawable();
        g.setShape(GradientDrawable.OVAL);
        g.setColor("playing".equals(status) ? EMBER : "online".equals(status) ? GREEN : 0xFF6E605A);
        d.setBackground(g);
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(dp(10), dp(10));
        p.leftMargin = dp(10);
        d.setLayoutParams(p);
        return d;
    }

    private void heading(LinearLayout box, String t) {
        TextView h = text(t.toUpperCase(Locale.ROOT), 12, MUTED, true);
        h.setLetterSpacing(0.14f);
        box.addView(h, lp(0, 22, 0, 8));
    }

    private void styleField(EditText e) {
        e.setTextColor(FG);
        e.setHintTextColor(MUTED);
        e.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        e.setSingleLine(true);
        e.setPadding(dp(14), dp(12), dp(14), dp(12));
        e.setBackground(round(0xFF120D0C, 0xFF4A3A3A, 12));
        e.setOnFocusChangeListener(new View.OnFocusChangeListener() { @Override public void onFocusChange(View v, boolean f) { v.setBackground(round(0xFF120D0C, f ? EMBER : 0xFF4A3A3A, 12)); } });
    }

    private Button button(String label, boolean primary) {
        final Button b = new Button(this);
        b.setText(label);
        b.setAllCaps(false);
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        b.setTypeface(Typeface.DEFAULT_BOLD);
        b.setTextColor(primary ? INK : FG);
        final int fill = primary ? EMBER : 0xFF261D1A;
        b.setBackground(round(fill, primary ? EMBER : 0xFF4A3A3A, 14));
        b.setMinHeight(dp(48));
        b.setStateListAnimator(null);
        b.setOnFocusChangeListener(new View.OnFocusChangeListener() { @Override public void onFocusChange(View v, boolean f) { v.setBackground(round(fill, f ? FG : (fill == EMBER ? EMBER : 0xFF4A3A3A), 14)); } });
        return b;
    }

    private TextView text(String s, int sp, int color, boolean bold) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextColor(color);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, sp);
        if (bold) t.setTypeface(Typeface.DEFAULT_BOLD);
        return t;
    }

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
