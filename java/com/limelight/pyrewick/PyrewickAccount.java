package com.limelight.pyrewick;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/**
 * Pyrelink: the player's Pyrelark account (the same one as in Pyrelark on the PC and on pyrelark.com).
 *
 * The session token from Pyrelark's server is kept in the app's private storage, encrypted with a key that
 * lives in the Android Keystore (on Android 6 and newer), so it can't be copied off the phone and reused.
 * All network calls here block: call them off the main thread.
 */
public final class PyrewickAccount {
    private static final String PREFS = "pyrewick_account";
    private static final String KEY_ALIAS = "pyrewick_session";

    public static final class ApiException extends Exception {
        public final int status;
        ApiException(int status, String message) { super(message); this.status = status; }
    }

    private PyrewickAccount() { }

    private static SharedPreferences prefs(Context c) { return c.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE); }

    public static boolean signedIn(Context c) { return token(c) != null; }
    public static String name(Context c) { return prefs(c).getString("name", ""); }
    public static String email(Context c) { return prefs(c).getString("email", ""); }
    public static boolean verified(Context c) { return prefs(c).getBoolean("verified", false); }

    // ---------------------------------------------------------------- the server
    public static JSONObject call(Context c, String method, String path, JSONObject body, boolean withToken) throws ApiException {
        HttpURLConnection h = null;
        try {
            h = (HttpURLConnection) new URL(PyrewickConfig.SERVER_URL.replaceAll("/+$", "") + path).openConnection();
            h.setRequestMethod(method);
            h.setConnectTimeout(12000);
            h.setReadTimeout(20000);
            h.setRequestProperty("User-Agent", "Pyrelink");
            h.setRequestProperty("Accept", "application/json");
            if (withToken) { String t = token(c); if (t != null) h.setRequestProperty("Authorization", "Bearer " + t); }
            if (body != null || "POST".equals(method)) {
                byte[] b = (body != null ? body.toString() : "{}").getBytes(StandardCharsets.UTF_8);
                h.setDoOutput(true);
                h.setRequestProperty("Content-Type", "application/json");
                h.setFixedLengthStreamingMode(b.length);
                OutputStream o = h.getOutputStream();
                o.write(b);
                o.close();
            }
            int status = h.getResponseCode();
            InputStream in = status >= 400 ? h.getErrorStream() : h.getInputStream();
            String text = "";
            if (in != null) {
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                byte[] buf = new byte[8192];
                int n;
                while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
                in.close();
                text = new String(out.toByteArray(), StandardCharsets.UTF_8);
            }
            JSONObject j;
            try { j = new JSONObject(text.isEmpty() ? "{}" : text); } catch (Exception e) { j = new JSONObject(); }
            if (status >= 400) throw new ApiException(status, j.optString("error", "Pyrelark's server said " + status + "."));
            return j;
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            throw new ApiException(0, "Couldn't reach Pyrelark's server. Check your connection and try again.");
        } finally {
            if (h != null) h.disconnect();
        }
    }

    /** True when the server answers at all (so "Continue offline" is only offered when it really can't be reached). */
    public static boolean serverReachable(Context c) {
        try { call(c, "GET", "/v1", null, false); return true; }
        catch (ApiException e) { return e.status != 0; }
    }

    public static void signIn(Context c, String email, String password) throws Exception {
        JSONObject b = new JSONObject();
        b.put("email", email); b.put("password", password); b.put("device", deviceName());
        saveSession(c, call(c, "POST", "/v1/login", b, false));
    }

    public static void signUp(Context c, String name, String email, String password) throws Exception {
        JSONObject b = new JSONObject();
        b.put("name", name); b.put("email", email); b.put("password", password); b.put("device", deviceName());
        saveSession(c, call(c, "POST", "/v1/signup", b, false));
    }

    public static void forgot(Context c, String email) throws Exception {
        JSONObject b = new JSONObject(); b.put("email", email);
        call(c, "POST", "/v1/forgot", b, false);
    }

    public static void reset(Context c, String email, String code, String password) throws Exception {
        JSONObject b = new JSONObject(); b.put("email", email); b.put("code", code); b.put("password", password);
        call(c, "POST", "/v1/reset", b, false);
        signIn(c, email, password);
    }

    /** Checks the session is still good and updates the name and email. A signed-out session is forgotten. */
    public static void refresh(Context c) {
        if (!signedIn(c)) return;
        try {
            JSONObject u = call(c, "GET", "/v1/me", null, true).optJSONObject("user");
            if (u != null) prefs(c).edit().putString("name", u.optString("name")).putString("email", u.optString("email")).putBoolean("verified", u.optBoolean("verified")).apply();
        } catch (ApiException e) {
            if (e.status == 401) clear(c);
        }
    }

    public static void signOut(final Context c) {
        final String t = token(c);
        clear(c);
        if (t == null) return;
        new Thread(new Runnable() {
            @Override public void run() {
                try {
                    HttpURLConnection h = (HttpURLConnection) new URL(PyrewickConfig.SERVER_URL.replaceAll("/+$", "") + "/v1/logout").openConnection();
                    h.setRequestMethod("POST"); h.setDoOutput(true); h.setFixedLengthStreamingMode(0);
                    h.setRequestProperty("Authorization", "Bearer " + t);
                    h.getResponseCode(); h.disconnect();
                } catch (Exception ignored) { }
            }
        }).start();
    }

    /** Deletes the account on the server (Google Play requires this be possible inside the app). */
    public static void deleteAccount(Context c, String password) throws Exception {
        JSONObject b = new JSONObject(); b.put("password", password);
        call(c, "POST", "/v1/account/delete", b, true);
        clear(c);
    }

    private static void saveSession(Context c, JSONObject r) {
        JSONObject u = r.optJSONObject("user");
        prefs(c).edit()
                .putString("token", encrypt(r.optString("token")))
                .putString("name", u != null ? u.optString("name") : "")
                .putString("email", u != null ? u.optString("email") : "")
                .putBoolean("verified", u != null && u.optBoolean("verified"))
                .apply();
    }

    private static void clear(Context c) { prefs(c).edit().clear().apply(); }

    private static String deviceName() {
        String m = (Build.MANUFACTURER + " " + Build.MODEL).trim();
        return ("Pyrelink · " + m).substring(0, Math.min(60, ("Pyrelink · " + m).length()));
    }

    // ---------------------------------------------------------------- keeping the token safe
    private static String token(Context c) {
        String s = prefs(c).getString("token", null);
        if (s == null || s.isEmpty()) return null;
        return decrypt(s);
    }

    @android.annotation.TargetApi(23) // only called on Android 6+ (see encrypt and decrypt)
    private static SecretKey key() throws Exception {
        KeyStore ks = KeyStore.getInstance("AndroidKeyStore");
        ks.load(null);
        if (ks.containsAlias(KEY_ALIAS)) return ((KeyStore.SecretKeyEntry) ks.getEntry(KEY_ALIAS, null)).getSecretKey();
        KeyGenerator g = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        g.init(new KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256).build());
        return g.generateKey();
    }

    private static String encrypt(String plain) {
        if (Build.VERSION.SDK_INT < 23) return "p:" + plain; // private app storage only, on very old Android
        try {
            Cipher ci = Cipher.getInstance("AES/GCM/NoPadding");
            ci.init(Cipher.ENCRYPT_MODE, key());
            byte[] iv = ci.getIV(), data = ci.doFinal(plain.getBytes(StandardCharsets.UTF_8));
            return "k:" + Base64.encodeToString(iv, Base64.NO_WRAP) + ":" + Base64.encodeToString(data, Base64.NO_WRAP);
        } catch (Exception e) {
            return "p:" + plain;
        }
    }

    private static String decrypt(String s) {
        try {
            if (s.startsWith("p:")) return s.substring(2);
            if (!s.startsWith("k:")) return null;
            String[] parts = s.substring(2).split(":");
            Cipher ci = Cipher.getInstance("AES/GCM/NoPadding");
            ci.init(Cipher.DECRYPT_MODE, key(), new GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)));
            return new String(ci.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), StandardCharsets.UTF_8);
        } catch (Exception e) {
            return null; // e.g. the phone's keys were reset: sign in again
        }
    }
}
