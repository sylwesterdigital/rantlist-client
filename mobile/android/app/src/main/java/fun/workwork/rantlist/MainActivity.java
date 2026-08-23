package fun.workwork.rantlist;

import android.Manifest;
import android.app.Activity;
import android.app.DownloadManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
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
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

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

        CookieManager.getInstance().setAcceptCookie(true);
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
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
                DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
                request.setMimeType(mimetype);
                request.addRequestHeader("User-Agent", userAgent);
                String cookies = CookieManager.getInstance().getCookie(url);
                if (cookies != null) request.addRequestHeader("Cookie", cookies);
                request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
                request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, android.webkit.URLUtil.guessFileName(url, contentDisposition, mimetype));
                ((DownloadManager) getSystemService(DOWNLOAD_SERVICE)).enqueue(request);
            } catch (Exception ignored) {}
        });

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
    }

    @Override
    protected void onDestroy() {
        if (connectivityManager != null && networkCallback != null) {
            try { connectivityManager.unregisterNetworkCallback(networkCallback); } catch (Exception ignored) {}
        }
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
