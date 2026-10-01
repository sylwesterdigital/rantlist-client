package fun.workwork.rantlist;

import android.Manifest;
import android.app.Activity;
import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.ClipData;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.os.Bundle;
import android.os.Build;
import android.os.Environment;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import android.view.Gravity;
import android.view.View;
import android.webkit.CookieManager;
import android.webkit.DownloadListener;
import android.webkit.PermissionRequest;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebMessage;
import android.webkit.WebMessagePort;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

import org.json.JSONArray;
import org.json.JSONObject;

public final class MainActivity extends Activity {
    private static final String APP_URL = "https://rantlist.me/";
    private static final int MEDIA_REQUEST = 2001;
    private static final int FILE_REQUEST = 2002;
    private WebView webView;
    private FrameLayout root;
    private LinearLayout nativeOverlay;
    private TextView overlayTitle;
    private TextView overlayMessage;
    private ProgressBar overlayProgress;
    private Button retryButton;
    private PermissionRequest pendingMediaRequest;
    private ValueCallback<Uri[]> pendingFileCallback;
    private ConnectivityManager connectivityManager;
    private ConnectivityManager.NetworkCallback networkCallback;
    private boolean uiLoaded = false;
    private boolean mainFrameLoadFailed = false;
    private WebMessagePort secretPort;
    private WebMessagePort sharePort;
    private SecureOpenAiStore secureOpenAiStore;
    private DownloadManager downloadManager;
    private final Set<Long> pendingPdfDownloads = new HashSet<>();
    private BroadcastReceiver downloadReceiver;
    private final ExecutorService nativeShareExecutor = Executors.newSingleThreadExecutor();
    private final Map<String, NativeShareGroup> nativeShareGroups = new LinkedHashMap<>();


    private boolean isLikelyXrHeadset() {
        PackageManager pm = getPackageManager();
        boolean vrFeature = pm != null && (
            pm.hasSystemFeature("android.hardware.vr.high_performance") ||
            pm.hasSystemFeature("android.hardware.vr.headtracking")
        );
        String manufacturer = String.valueOf(Build.MANUFACTURER).toLowerCase(java.util.Locale.ROOT);
        String model = String.valueOf(Build.MODEL).toLowerCase(java.util.Locale.ROOT);
        return vrFeature || manufacturer.contains("oculus") || manufacturer.contains("meta") || model.contains("quest");
    }

    private boolean isTrusted(Uri uri) {
        if (uri == null || !"https".equalsIgnoreCase(uri.getScheme())) return false;
        String host = uri.getHost();
        return host != null && (host.equalsIgnoreCase("rantlist.me") || host.equalsIgnoreCase("www.rantlist.me"));
    }

    private boolean hasInternet() {
        if (connectivityManager == null) return false;
        Network network = connectivityManager.getActiveNetwork();
        if (network == null) return false;
        NetworkCapabilities caps = connectivityManager.getNetworkCapabilities(network);
        return caps != null
            && caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            && caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED);
    }

    private int dp(float value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        connectivityManager = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        secureOpenAiStore = new SecureOpenAiStore(this);
        downloadManager = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
        uiLoaded = state != null && state.getBoolean("rantlistUiLoaded", false);

        root = new FrameLayout(this);
        root.setBackgroundColor(Color.rgb(6, 9, 13));
        webView = new WebView(this);
        root.addView(webView, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        installNativeOverlay();
        setContentView(root);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        String nativeUserAgent = settings.getUserAgentString();
        if (nativeUserAgent == null) nativeUserAgent = "";
        StringBuilder rantlistUserAgent = new StringBuilder(nativeUserAgent);
        if (!nativeUserAgent.contains("Rantlist-Android")) rantlistUserAgent.append(" Rantlist-Android");
        if (isLikelyXrHeadset() && !nativeUserAgent.contains("Rantlist-XR-Headset")) rantlistUserAgent.append(" Rantlist-XR-Headset");
        settings.setUserAgentString(rantlistUserAgent.toString().trim());

        CookieManager.getInstance().setAcceptCookie(true);
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if (isPdfPreviewUri(uri)) {
                    openPdf(uri, view.getSettings().getUserAgentString());
                    return true;
                }
                if (isTrusted(uri) || "about".equals(uri.getScheme()) || "blob".equals(uri.getScheme()) || "data".equals(uri.getScheme())) {
                    return false;
                }
                try { startActivity(new Intent(Intent.ACTION_VIEW, uri)); } catch (Exception ignored) {}
                return true;
            }

            @Override
            public void onPageStarted(WebView view, String url, android.graphics.Bitmap favicon) {
                if (isTrusted(Uri.parse(url))) {
                    mainFrameLoadFailed = false;
                    if (!uiLoaded) showLoading("Loading Rantlist…");
                }
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                if (!isTrusted(Uri.parse(url)) || mainFrameLoadFailed) return;
                uiLoaded = true;
                installSecretChannel(view);
                installShareChannel(view);
                showReady();
            }

            @Override
            public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (!request.isForMainFrame()) return;
                mainFrameLoadFailed = true;
                if (!uiLoaded) {
                    if (!hasInternet()) showOffline();
                    else showFailure("The Rantlist interface could not be downloaded. Check your connection and try again.");
                }
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onPermissionRequest(PermissionRequest request) {
                Uri origin = request.getOrigin();
                if (!isTrusted(origin)) {
                    request.deny();
                    return;
                }
                pendingMediaRequest = request;
                List<String> needed = new ArrayList<>();
                for (String resource : request.getResources()) {
                    if (PermissionRequest.RESOURCE_VIDEO_CAPTURE.equals(resource) && checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                        needed.add(Manifest.permission.CAMERA);
                    }
                    if (PermissionRequest.RESOURCE_AUDIO_CAPTURE.equals(resource) && checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                        needed.add(Manifest.permission.RECORD_AUDIO);
                    }
                }
                if (needed.isEmpty()) request.grant(request.getResources());
                else requestPermissions(needed.toArray(new String[0]), MEDIA_REQUEST);
            }

            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (pendingFileCallback != null) pendingFileCallback.onReceiveValue(null);
                pendingFileCallback = callback;
                Intent intent = params.createIntent();
                try {
                    startActivityForResult(intent, FILE_REQUEST);
                    return true;
                } catch (Exception error) {
                    pendingFileCallback = null;
                    return false;
                }
            }
        });

        webView.setDownloadListener((url, userAgent, contentDisposition, mimetype, contentLength) -> {
            try {
                DownloadManager.Request request = authenticatedDownloadRequest(Uri.parse(url), userAgent, mimetype);
                request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
                request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, android.webkit.URLUtil.guessFileName(url, contentDisposition, mimetype));
                downloadManager.enqueue(request);
            } catch (Exception error) {
                Toast.makeText(this, "Download could not be started.", Toast.LENGTH_SHORT).show();
            }
        });

        registerDownloadReceiver();
        captureIncomingShareIntent(getIntent());
        registerConnectivityWatcher();

        if (state != null && uiLoaded && webView.restoreState(state) != null) {
            showReady();
        } else if (hasInternet()) {
            uiLoaded = false;
            showLoading("Connecting to rantlist.me…");
            loadFresh();
        } else {
            showOffline();
        }
    }


    private boolean isPdfPreviewUri(Uri uri) {
        if (!isTrusted(uri)) return false;
        String preview = uri.getQueryParameter("preview");
        if (preview != null && "pdf".equalsIgnoreCase(preview)) return true;
        String path = uri.getPath();
        return path != null && path.toLowerCase(java.util.Locale.ROOT).endsWith(".pdf");
    }

    private DownloadManager.Request authenticatedDownloadRequest(Uri uri, String userAgent, String mime) {
        DownloadManager.Request request = new DownloadManager.Request(uri);
        if (mime != null && !mime.isEmpty()) request.setMimeType(mime);
        if (userAgent != null && !userAgent.isEmpty()) request.addRequestHeader("User-Agent", userAgent);
        String cookies = CookieManager.getInstance().getCookie(uri.toString());
        if (cookies != null && !cookies.isEmpty()) request.addRequestHeader("Cookie", cookies);
        request.addRequestHeader("Accept", mime != null && !mime.isEmpty() ? mime : "*/*");
        return request;
    }

    private void openPdf(Uri uri, String userAgent) {
        try {
            DownloadManager.Request request = authenticatedDownloadRequest(uri, userAgent, "application/pdf");
            request.setTitle("Rantlist PDF");
            request.setDescription("Opening PDF…");
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            long id = downloadManager.enqueue(request);
            pendingPdfDownloads.add(id);
        } catch (Exception error) {
            Toast.makeText(this, "PDF could not be opened.", Toast.LENGTH_SHORT).show();
        }
    }

    private void registerDownloadReceiver() {
        downloadReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (!DownloadManager.ACTION_DOWNLOAD_COMPLETE.equals(intent.getAction())) return;
                long id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L);
                if (!pendingPdfDownloads.remove(id)) return;
                Uri local = downloadManager.getUriForDownloadedFile(id);
                if (local == null) {
                    Toast.makeText(MainActivity.this, "PDF download failed.", Toast.LENGTH_SHORT).show();
                    return;
                }
                Intent open = new Intent(Intent.ACTION_VIEW)
                    .setDataAndType(local, "application/pdf")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                try {
                    startActivity(Intent.createChooser(open, "Open PDF"));
                } catch (Exception error) {
                    Toast.makeText(MainActivity.this, "No PDF viewer is available on this device.", Toast.LENGTH_LONG).show();
                }
            }
        };
        IntentFilter filter = new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE);
        if (android.os.Build.VERSION.SDK_INT >= 33) registerReceiver(downloadReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        else registerReceiver(downloadReceiver, filter);
    }

    private static final class NativeShareItem {
        final String id = UUID.randomUUID().toString();
        String kind;
        String name;
        String mime;
        Uri uri;
        String text;
        String url;
    }

    private static final class NativeShareGroup {
        final String id = UUID.randomUUID().toString();
        final double createdAt = System.currentTimeMillis() / 1000.0;
        final List<NativeShareItem> items = new ArrayList<>();
    }

    private NativeShareItem nativeFileItem(Uri uri, String fallbackMime) {
        if (uri == null) return null;
        NativeShareItem item = new NativeShareItem();
        item.kind = "file";
        item.uri = uri;
        item.mime = getContentResolver().getType(uri);
        if (item.mime == null || item.mime.isEmpty()) item.mime = fallbackMime == null || fallbackMime.isEmpty() ? "application/octet-stream" : fallbackMime;
        item.name = "Shared file";
        try (android.database.Cursor cursor = getContentResolver().query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (index >= 0) {
                    String value = cursor.getString(index);
                    if (value != null && !value.trim().isEmpty()) item.name = value.trim();
                }
            }
        } catch (Exception ignored) {}
        return item;
    }

    private void captureIncomingShareIntent(Intent intent) {
        if (intent == null) return;
        String action = intent.getAction();
        if (!(Intent.ACTION_SEND.equals(action) || Intent.ACTION_SEND_MULTIPLE.equals(action))) return;
        NativeShareGroup group = new NativeShareGroup();
        String type = intent.getType();
        CharSequence textValue = intent.getCharSequenceExtra(Intent.EXTRA_TEXT);
        if (textValue != null) {
            String text = textValue.toString().trim();
            if (!text.isEmpty()) {
                NativeShareItem item = new NativeShareItem();
                Uri parsed = null;
                try { parsed = Uri.parse(text); } catch (Exception ignored) {}
                boolean url = parsed != null && ("http".equalsIgnoreCase(parsed.getScheme()) || "https".equalsIgnoreCase(parsed.getScheme())) && !text.matches(".*\\s+.*");
                item.kind = url ? "url" : "text";
                item.name = url ? "Shared link" : "Shared text";
                item.mime = "text/plain";
                if (url) item.url = text; else item.text = text;
                group.items.add(item);
            }
        }
        Set<String> seen = new HashSet<>();
        ArrayList<Uri> streams = new ArrayList<>();
        if (Intent.ACTION_SEND_MULTIPLE.equals(action)) {
            ArrayList<Uri> values = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);
            if (values != null) streams.addAll(values);
        } else {
            Uri stream = intent.getParcelableExtra(Intent.EXTRA_STREAM);
            if (stream != null) streams.add(stream);
        }
        ClipData clip = intent.getClipData();
        if (clip != null) {
            for (int i = 0; i < clip.getItemCount(); i++) {
                Uri stream = clip.getItemAt(i).getUri();
                if (stream != null) streams.add(stream);
            }
        }
        for (Uri stream : streams) {
            if (stream == null || !seen.add(stream.toString())) continue;
            NativeShareItem item = nativeFileItem(stream, type);
            if (item != null) group.items.add(item);
        }
        if (!group.items.isEmpty()) {
            nativeShareGroups.put(group.id, group);
            deliverPendingShares();
        }
        intent.setAction(null);
    }

    private JSONObject shareItemPayload(String shareId, NativeShareItem item) throws Exception {
        JSONObject payload = new JSONObject();
        payload.put("id", item.id);
        payload.put("kind", item.kind);
        payload.put("name", item.name == null ? "Shared item" : item.name);
        payload.put("mime", item.mime == null ? "application/octet-stream" : item.mime);
        if ("file".equals(item.kind)) payload.put("nativeRead", true);
        if (item.text != null) payload.put("text", item.text);
        if (item.url != null) payload.put("url", item.url);
        return payload;
    }

    private void deliverPendingShares() {
        WebMessagePort port = sharePort;
        if (port == null || nativeShareGroups.isEmpty()) return;
        try {
            JSONArray groups = new JSONArray();
            for (NativeShareGroup group : nativeShareGroups.values()) {
                JSONObject body = new JSONObject();
                body.put("id", group.id);
                body.put("createdAt", group.createdAt);
                JSONArray items = new JSONArray();
                for (NativeShareItem item : group.items) items.put(shareItemPayload(group.id, item));
                body.put("items", items);
                groups.put(body);
            }
            JSONObject payload = new JSONObject();
            payload.put("type", "groups");
            payload.put("groups", groups);
            port.postMessage(new WebMessage(payload.toString()));
        } catch (Exception ignored) {}
    }

    private NativeShareItem findNativeShareItem(String shareId, String itemId) {
        NativeShareGroup group = nativeShareGroups.get(shareId);
        if (group == null) return null;
        for (NativeShareItem item : group.items) if (item.id.equals(itemId)) return item;
        return null;
    }

    private void postShareMessage(JSONObject payload) {
        final String raw = payload.toString();
        webView.post(() -> {
            try { if (sharePort != null) sharePort.postMessage(new WebMessage(raw)); } catch (Exception ignored) {}
        });
    }

    private void postShareFileError(String requestId, String message) {
        try {
            JSONObject payload = new JSONObject();
            payload.put("type", "fileError");
            payload.put("requestId", requestId);
            payload.put("message", message);
            postShareMessage(payload);
        } catch (Exception ignored) {}
    }

    private void deliverNativeShareFile(String requestId, String shareId, String itemId) {
        if (requestId == null || !requestId.matches("^[A-Za-z0-9._-]{8,128}$")) return;
        NativeShareItem item = findNativeShareItem(shareId, itemId);
        if (item == null || item.uri == null) {
            postShareFileError(requestId, "The shared file is no longer available on this Android device.");
            return;
        }
        nativeShareExecutor.execute(() -> {
            final int chunkSize = 192 * 1024;
            try {
                long length = -1L;
                try (android.content.res.AssetFileDescriptor afd = getContentResolver().openAssetFileDescriptor(item.uri, "r")) {
                    if (afd != null) length = afd.getLength();
                } catch (Exception ignored) {}
                java.io.File temp = null;
                if (length < 0) {
                    temp = java.io.File.createTempFile("rantlist-share-", ".bin", getCacheDir());
                    try (InputStream input = getContentResolver().openInputStream(item.uri); java.io.FileOutputStream output = new java.io.FileOutputStream(temp)) {
                        if (input == null) throw new IllegalStateException("Shared file could not be opened.");
                        byte[] buffer = new byte[64 * 1024];
                        long copied = 0;
                        int read;
                        while ((read = input.read(buffer)) >= 0) {
                            if (read == 0) continue;
                            copied += read;
                            if (copied > 512L * 1024L * 1024L) throw new IllegalStateException("Shared file is too large for the native handoff.");
                            output.write(buffer, 0, read);
                        }
                    }
                    length = temp.length();
                }
                if (length < 0 || length > 512L * 1024L * 1024L) throw new IllegalStateException("Shared file is too large for the native handoff.");
                int total = Math.max(1, (int) ((length + chunkSize - 1) / chunkSize));
                InputStream input = temp != null ? new java.io.FileInputStream(temp) : getContentResolver().openInputStream(item.uri);
                if (input == null) throw new IllegalStateException("Shared file could not be opened.");
                try (InputStream stream = input) {
                    byte[] buffer = new byte[chunkSize];
                    for (int index = 0; index < total; index++) {
                        int offset = 0;
                        while (offset < buffer.length) {
                            int read = stream.read(buffer, offset, buffer.length - offset);
                            if (read < 0) break;
                            if (read == 0) continue;
                            offset += read;
                        }
                        byte[] chunk = offset == buffer.length ? buffer : java.util.Arrays.copyOf(buffer, offset);
                        JSONObject payload = new JSONObject();
                        payload.put("type", "fileChunk");
                        payload.put("requestId", requestId);
                        payload.put("index", index);
                        payload.put("total", total);
                        payload.put("base64", Base64.encodeToString(chunk, Base64.NO_WRAP));
                        payload.put("mime", item.mime == null ? "application/octet-stream" : item.mime);
                        payload.put("name", item.name == null ? "Shared file" : item.name);
                        postShareMessage(payload);
                    }
                } finally {
                    if (temp != null) temp.delete();
                }
            } catch (Exception error) {
                postShareFileError(requestId, "The shared file could not be read by Rantlist.");
            }
        });
    }

    private void installShareChannel(WebView view) {
        if (view == null) return;
        try { if (sharePort != null) sharePort.close(); } catch (Exception ignored) {}
        try {
            WebMessagePort[] ports = view.createWebMessageChannel();
            sharePort = ports[0];
            sharePort.setWebMessageCallback(new WebMessagePort.WebMessageCallback() {
                @Override
                public void onMessage(WebMessagePort port, WebMessage message) {
                    String raw = message == null ? null : message.getData();
                    try {
                        JSONObject body = new JSONObject(raw == null ? "{}" : raw);
                        String action = body.optString("action", "");
                        if ("ready".equals(action)) {
                            deliverPendingShares();
                        } else if ("consume".equals(action)) {
                            JSONArray ids = body.optJSONArray("ids");
                            if (ids != null) for (int i = 0; i < ids.length(); i++) nativeShareGroups.remove(ids.optString(i, ""));
                        } else if ("read".equals(action)) {
                            deliverNativeShareFile(body.optString("requestId", ""), body.optString("shareId", ""), body.optString("itemId", ""));
                        }
                    } catch (Exception ignored) {}
                }
            });
            Uri current = Uri.parse(view.getUrl() == null ? APP_URL : view.getUrl());
            if (!isTrusted(current)) throw new IllegalStateException("Untrusted WebView origin.");
            Uri origin = Uri.parse(current.getScheme() + "://" + current.getHost());
            view.postWebMessage(new WebMessage("rantlist-native-share-channel-v1", new WebMessagePort[]{ports[1]}), origin);
        } catch (Exception ignored) {
            sharePort = null;
        }
    }



    private void installSecretChannel(WebView view) {
        if (view == null) return;
        try { if (secretPort != null) secretPort.close(); } catch (Exception ignored) {}
        try {
            WebMessagePort[] ports = view.createWebMessageChannel();
            secretPort = ports[0];
            secretPort.setWebMessageCallback(new WebMessagePort.WebMessageCallback() {
                @Override
                public void onMessage(WebMessagePort port, WebMessage message) {
                    handleSecretMessage(port, message == null ? null : message.getData());
                }
            });
            Uri current = Uri.parse(view.getUrl() == null ? APP_URL : view.getUrl());
            if (!isTrusted(current)) throw new IllegalStateException("Untrusted WebView origin.");
            Uri origin = Uri.parse(current.getScheme() + "://" + current.getHost());
            view.postWebMessage(
                new WebMessage("rantlist-native-secret-channel-v1", new WebMessagePort[]{ports[1]}),
                origin
            );
        } catch (Exception ignored) {
            secretPort = null;
        }
    }

    private void handleSecretMessage(WebMessagePort port, String raw) {
        JSONObject response = new JSONObject();
        String requestId = "";
        try {
            JSONObject body = new JSONObject(raw == null ? "{}" : raw);
            requestId = body.optString("requestId", "");
            if (!requestId.matches("^[A-Za-z0-9._-]{8,128}$")) return;
            String action = body.optString("action", "");
            String provider = body.optString("provider", "openai").toLowerCase(java.util.Locale.ROOT);
            if (!("openai".equals(provider) || "tripo".equals(provider) || "xai".equals(provider))) provider = "openai";
            response.put("requestId", requestId);
            response.put("provider", provider);
            response.put("ok", true);
            if ("status".equals(action)) {
                response.put("configured", secureOpenAiStore.isConfigured(provider));
            } else if ("get".equals(action)) {
                String key = secureOpenAiStore.read(provider);
                response.put("configured", key != null && !key.isEmpty());
                response.put("key", key == null ? "" : key);
            } else if ("set".equals(action)) {
                String key = body.optString("key", "").trim();
                if (!validApiKey(key)) throw new IllegalArgumentException("Invalid API key.");
                secureOpenAiStore.save(provider, key);
                response.put("configured", true);
            } else if ("clear".equals(action)) {
                secureOpenAiStore.clear(provider);
                response.put("configured", false);
            } else {
                throw new IllegalArgumentException("Unsupported secure credential operation.");
            }
        } catch (Exception error) {
            try {
                response = new JSONObject();
                response.put("requestId", requestId);
                response.put("ok", false);
                response.put("error", "Android Keystore credential operation failed.");
            } catch (Exception ignored) {}
        }
        try { port.postMessage(new WebMessage(response.toString())); } catch (Exception ignored) {}
    }

    private boolean validApiKey(String key) {
        if (key == null || key.length() < 20 || key.length() > 512) return false;
        for (int i = 0; i < key.length(); i++) if (Character.isWhitespace(key.charAt(i)) || Character.isISOControl(key.charAt(i))) return false;
        return true;
    }

    private static final class SecureOpenAiStore {
        private static final String KEYSTORE = "AndroidKeyStore";
        private static final String OPENAI_ALIAS = "fun.workwork.rantlist.openai.user-api-key.v1";
        private static final String PREFS = "rantlist_secure_secrets";
        private static final String OPENAI_VALUE = "openai_api_key_v1";
        private static String alias(String provider) { return "openai".equals(provider) ? OPENAI_ALIAS : "fun.workwork.rantlist." + provider + ".user-api-key.v1"; }
        private static String valueName(String provider) { return "openai".equals(provider) ? OPENAI_VALUE : provider + "_api_key_v1"; }
        private final android.content.SharedPreferences prefs;

        SecureOpenAiStore(Context context) {
            prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        }

        boolean isConfigured(String provider) {
            String name = valueName(provider);
            return prefs.contains(name) && !prefs.getString(name, "").isEmpty();
        }

        void save(String provider, String value) throws Exception {
            SecretKey key = getOrCreateKey(provider);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key);
            byte[] encrypted = cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));
            String packed = Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP)
                + "." + Base64.encodeToString(encrypted, Base64.NO_WRAP);
            if (!prefs.edit().putString(valueName(provider), packed).commit()) throw new IllegalStateException("Credential ciphertext could not be stored.");
        }

        String read(String provider) throws Exception {
            String packed = prefs.getString(valueName(provider), "");
            if (packed == null || packed.isEmpty()) return "";
            String[] parts = packed.split("\\.", 2);
            if (parts.length != 2) throw new IllegalStateException("Credential ciphertext is invalid.");
            byte[] iv = Base64.decode(parts[0], Base64.NO_WRAP);
            byte[] encrypted = Base64.decode(parts[1], Base64.NO_WRAP);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(provider), new GCMParameterSpec(128, iv));
            return new String(cipher.doFinal(encrypted), StandardCharsets.UTF_8);
        }

        void clear(String provider) {
            prefs.edit().remove(valueName(provider)).commit();
        }

        private SecretKey getOrCreateKey(String provider) throws Exception {
            KeyStore store = KeyStore.getInstance(KEYSTORE);
            store.load(null);
            java.security.Key existing = store.getKey(alias(provider), null);
            if (existing instanceof SecretKey) return (SecretKey) existing;
            KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE);
            generator.init(new KeyGenParameterSpec.Builder(
                alias(provider),
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT
            ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
             .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
             .setRandomizedEncryptionRequired(true)
             .build());
            return generator.generateKey();
        }
    }

    private void installNativeOverlay() {
        nativeOverlay = new LinearLayout(this);
        nativeOverlay.setOrientation(LinearLayout.VERTICAL);
        nativeOverlay.setGravity(Gravity.CENTER);
        nativeOverlay.setPadding(dp(28), dp(32), dp(28), dp(32));
        nativeOverlay.setBackgroundColor(Color.rgb(6, 9, 13));

        ImageView logo = new ImageView(this);
        logo.setImageResource(R.mipmap.ic_launcher);
        logo.setContentDescription(null);
        LinearLayout.LayoutParams logoParams = new LinearLayout.LayoutParams(dp(92), dp(92));
        logoParams.bottomMargin = dp(18);
        nativeOverlay.addView(logo, logoParams);

        overlayTitle = new TextView(this);
        overlayTitle.setText("Rantlist");
        overlayTitle.setTextColor(Color.WHITE);
        overlayTitle.setTextSize(25);
        overlayTitle.setGravity(Gravity.CENTER);
        overlayTitle.setTypeface(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD);
        nativeOverlay.addView(overlayTitle, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        overlayMessage = new TextView(this);
        overlayMessage.setText("Connecting to rantlist.me…");
        overlayMessage.setTextColor(Color.argb(184, 255, 255, 255));
        overlayMessage.setTextSize(15);
        overlayMessage.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams messageParams = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        messageParams.topMargin = dp(12);
        messageParams.leftMargin = dp(18);
        messageParams.rightMargin = dp(18);
        nativeOverlay.addView(overlayMessage, messageParams);

        overlayProgress = new ProgressBar(this);
        LinearLayout.LayoutParams progressParams = new LinearLayout.LayoutParams(dp(42), dp(42));
        progressParams.topMargin = dp(18);
        nativeOverlay.addView(overlayProgress, progressParams);

        retryButton = new Button(this);
        retryButton.setText("Try again");
        retryButton.setOnClickListener(v -> retryInitialLoad());
        LinearLayout.LayoutParams retryParams = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        retryParams.topMargin = dp(18);
        nativeOverlay.addView(retryButton, retryParams);
        retryButton.setVisibility(View.GONE);

        root.addView(nativeOverlay, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
    }

    private void showLoading(String message) {
        overlayTitle.setText("Rantlist");
        overlayMessage.setText(message);
        overlayProgress.setVisibility(View.VISIBLE);
        retryButton.setVisibility(View.GONE);
        nativeOverlay.setVisibility(View.VISIBLE);
        if (!uiLoaded) webView.setVisibility(View.INVISIBLE);
    }

    private void showOffline() {
        overlayTitle.setText("No internet connection");
        overlayMessage.setText("Connect to Wi‑Fi or mobile data. Rantlist will retry automatically when you’re online.");
        overlayProgress.setVisibility(View.GONE);
        retryButton.setVisibility(View.VISIBLE);
        nativeOverlay.setVisibility(View.VISIBLE);
    }

    private void showFailure(String message) {
        overlayTitle.setText("Rantlist couldn’t load");
        overlayMessage.setText(message);
        overlayProgress.setVisibility(View.GONE);
        retryButton.setVisibility(View.VISIBLE);
        nativeOverlay.setVisibility(View.VISIBLE);
        if (!uiLoaded) webView.setVisibility(View.INVISIBLE);
    }

    private void showReady() {
        webView.setVisibility(View.VISIBLE);
        nativeOverlay.setVisibility(View.GONE);
    }

    private void loadFresh() {
        mainFrameLoadFailed = false;
        webView.stopLoading();
        webView.clearCache(false);
        webView.loadUrl(APP_URL);
    }

    private void retryInitialLoad() {
        if (uiLoaded) {
            showReady();
            return;
        }
        if (!hasInternet()) {
            showOffline();
            return;
        }
        showLoading("Connecting to rantlist.me…");
        loadFresh();
    }

    private void registerConnectivityWatcher() {
        networkCallback = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onAvailable(Network network) {
                runOnUiThread(() -> {
                    if (uiLoaded) showReady();
                    else retryInitialLoad();
                });
            }

            @Override
            public void onLost(Network network) {
                runOnUiThread(() -> {
                    if (!hasInternet()) showOffline();
                });
            }

            @Override
            public void onCapabilitiesChanged(Network network, NetworkCapabilities caps) {
                runOnUiThread(() -> {
                    if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) {
                        if (!uiLoaded) retryInitialLoad();
                    } else if (!hasInternet()) {
                        showOffline();
                    }
                });
            }
        };
        connectivityManager.registerDefaultNetworkCallback(networkCallback);
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (!uiLoaded) retryInitialLoad();
        else deliverPendingShares();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        captureIncomingShareIntent(intent);
    }

    @Override
    protected void onDestroy() {
        if (connectivityManager != null && networkCallback != null) {
            try { connectivityManager.unregisterNetworkCallback(networkCallback); } catch (Exception ignored) {}
        }
        try { if (secretPort != null) secretPort.close(); } catch (Exception ignored) {}
        try { if (sharePort != null) sharePort.close(); } catch (Exception ignored) {}
        if (downloadReceiver != null) { try { unregisterReceiver(downloadReceiver); } catch (Exception ignored) {} }
        nativeShareExecutor.shutdownNow();
        super.onDestroy();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode != MEDIA_REQUEST || pendingMediaRequest == null) return;
        boolean granted = true;
        for (int result : grantResults) granted &= result == PackageManager.PERMISSION_GRANTED;
        if (granted) pendingMediaRequest.grant(pendingMediaRequest.getResources());
        else pendingMediaRequest.deny();
        pendingMediaRequest = null;
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != FILE_REQUEST || pendingFileCallback == null) return;
        Uri[] result = WebChromeClient.FileChooserParams.parseResult(resultCode, data);
        pendingFileCallback.onReceiveValue(result);
        pendingFileCallback = null;
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        outState.putBoolean("rantlistUiLoaded", uiLoaded);
        webView.saveState(outState);
        super.onSaveInstanceState(outState);
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }
}
