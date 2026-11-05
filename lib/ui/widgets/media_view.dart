/// مسار وسائط من أصول التطبيق (يبدأ بـ asset:).
bool isAssetMedia(String? path) => path != null && path.startsWith('asset:');

/// مسار وسائط على الإنترنت.
bool isNetworkMedia(String? path) =>
    path != null && (path.startsWith('http://') || path.startsWith('https://'));
